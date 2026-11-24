///|
priv enum ToolSessionEvent {
  Text(String)
  Call(Json)
  Done(String)
  Failed(Error)
}

///|
// One agent prompt lives across caller tool round-trips. The existing tool-call
// ID is the continuation key; unrelated conversations never share a session.
priv struct ToolSession {
  model : String
  tools : Array[Json]
  events : @aqueue.Queue[ToolSessionEvent]
  results : @aqueue.Queue[String]
  mut task : @async.Task[Unit]?
  mut pending_id : String
  mut call_sequence : Int32
  mut instructions : Array[Json]
}

///|
async fn Bridge::complete(
  self : Bridge,
  chat : ChatRequest,
  on_text : async (String) -> Unit,
  call_id : String,
  workers : @async.TaskGroup[Unit],
) -> (String, String, Array[Json]) {
  if chat.tools.is_empty() {
    return self.complete_once(chat, on_text, call_id)
  }
  let reused = match chat.continuation {
    Some((id, content)) =>
      match self.pending_sessions.get(id) {
        Some(session) => {
          self.pending_sessions.remove(id)
          session.pending_id = ""
          if session.model != chat.model || session.tools != chat.tools {
            // A changed tool catalog/model needs a new ACP session. Preserve
            // the caller's full transcript, including already completed work.
            if session.task is Some(task) {
              task.cancel()
            }
            None
          } else {
            let content = if session.instructions == chat.instructions {
              content
            } else {
              content +
              "\n\nUpdated caller conversation context:\n" +
              chat.prompt
            }
            session.instructions = chat.instructions
            session.results.put(content)
            Some(session)
          }
        }
        None => None // An expired process can resume from the supplied transcript.
      }
    None => None
  }
  let session = match reused {
    Some(session) => session
    None => {
      guard self.live_sessions < self.max_concurrent else {
        raise BridgeError(
          code=429,
          kind="bridge_busy",
          message="ACP sessions are busy; wait for a running turn to finish",
        )
      }
      let session : ToolSession = {
        model: chat.model,
        tools: chat.tools,
        events: @aqueue.Queue(kind=Unbounded),
        results: @aqueue.Queue(kind=Unbounded),
        task: None,
        pending_id: "",
        call_sequence: 0,
        instructions: chat.instructions,
      }
      self.live_sessions += 1
      session.task = Some(
        workers.spawn(
          () => {
            defer {
              self.live_sessions -= 1
              if session.pending_id != "" {
                self.pending_sessions.remove(session.pending_id)
              }
            }
            try {
              let (_, finish, _) = self.complete_once(
                chat,
                text => session.events.put(Text(text)),
                call_id,
                handoff=call => {
                  guard call is Object(fields) else {
                    raise protocol_error("Invalid relay call")
                  }
                  session.call_sequence += 1
                  let id = "call_" +
                    call_id +
                    "_" +
                    session.call_sequence.to_string()
                  let fields = fields.copy()
                  fields["id"] = Json(id)
                  session.pending_id = id
                  self.pending_sessions[id] = session
                  session.events.put(Call(Json::object(fields)))
                  let content = @async.with_timeout(self.timeout_ms, () => {
                    session.results.get()
                  })
                  { "content": [{ "type": "text", "text": content }] }
                },
              )
              session.events.put(Done(finish))
            } catch {
              error => session.events.put(Failed(error))
            }
          },
          no_wait=true,
        ),
      )
      session
    }
  }
  let text = StringBuilder()
  errdefer (if session.task is Some(task) { task.cancel() })
  for ;; {
    match session.events.get() {
      Text(chunk) => {
        text.write_string(chunk)
        on_text(chunk)
      }
      Call(call) => return (text.to_string(), "tool_calls", [call])
      Done(finish) => return (text.to_string(), finish, [])
      Failed(error) => raise error
    }
  }
  abort("unreachable ACP event loop")
}
