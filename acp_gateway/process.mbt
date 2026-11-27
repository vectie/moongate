///|
priv struct Frames {
  reader : &@io.Reader
  mut pending : Bytes
  mut offset : Int32
}

///|
// ACP framing is newline-delimited UTF-8, not LSP Content-Length framing.
// Decode only after assembling a complete frame (UTF-8 can cross pipe reads).
async fn Frames::next(self : Frames) -> Json {
  let frame = Buffer()
  for ;; {
    if self.offset == self.pending.length() {
      guard self.reader.read_some(max_len=8192) is Some(bytes) else {
        raise protocol_error("Agent exited before completing the ACP response")
      }
      self.pending = bytes
      self.offset = 0
    }
    let start = self.offset
    while self.offset < self.pending.length() &&
          self.pending[self.offset] != b'\n' {
      self.offset += 1
    }
    frame.write_bytesview(self.pending[start:self.offset])
    if frame.length() > 1048576 {
      raise protocol_error("ACP frame exceeds 1 MiB")
    }
    if self.offset < self.pending.length() {
      self.offset += 1
      return @json.parse(@utf8.decode(frame.to_bytes())) catch {
        _ => raise protocol_error("Agent stdout contains invalid ACP JSON")
      }
    }
  }
}

///|
type ToolHandoff = async (Json) -> Json

///|
async fn Bridge::complete_once(
  self : Bridge,
  chat : ChatRequest,
  on_text : async (String) -> Unit,
  call_id : String,
  handoff? : ToolHandoff,
) -> (String, String, Array[Json]) {
  let tools_server = if chat.tools.is_empty() {
    None
  } else {
    Some(@httpx.Server::new("127.0.0.1", 0))
  }
  defer (if tools_server is Some(server) { server.close() })
  let relay_token = self.token + ":" + call_id
  let mcp_servers : Array[Json] = match tools_server {
    None => []
    Some(server) =>
      [
        {
          "name": "moongate_client",
          "command": self.relay_command,
          "args": [
            "acp",
            "tool-relay",
            "--url",
            "http://127.0.0.1:\{server.port()}/mcp",
          ],
          "env": [{ "name": "MOONGATE_MCP_TOKEN", "value": relay_token }],
        },
      ]
  }
  let (child_stdin, input) = @process.write_to_process()
  defer input.close()
  let (output, child_stdout) = @process.read_from_process()
  defer output.close()
  let (errors, child_stderr) = @process.read_from_process()
  defer errors.close()
  @async.with_task_group(group => {
    if tools_server is Some(server) {
      group.spawn_bg(() => {
        server.serve((r, w) => {
          serve_caller_tools(r, w, relay_token, chat.tools, "call_" + call_id, call => {
            match handoff {
              Some(callback) => callback(call)
              None => {
                group.return_immediately(("", "tool_calls", [call]))
                Json::null()
              }
            }
          })
        })
      })
    }
    group.spawn_bg(() => {
      let code = @process.run(
        self.command,
        self.args,
        stdin=child_stdin,
        stdout=child_stdout,
        stderr=child_stderr,
        cwd=self.cwd,
        cancel_handler=@process.hard_cancel(),
      )
      if code != 0 {
        raise protocol_error("ACP agent process exited unsuccessfully")
      }
    })
    // Drain without retaining or forwarding provider diagnostics/credentials.
    group.spawn_bg(() => {
      while errors.read_some(max_len=8192) is Some(_) {
        ()
      }
    })
    let frames : Frames = { reader: output, pending: b"", offset: 0, }
    let rpc : Rpc = {
      read: () => frames.next(),
      write: json => input.write("\{json.stringify()}\n"),
      next_id: 1,
      selected_model: None,
      caller_tools: chat.tools,
    }
    let (text, finish) = rpc.complete(self.cwd, chat, on_text, mcp_servers~)
    let result = (text, finish, [])
    // A request owns its child process. Success, timeout, client-write failure
    // and protocol failure all cancel and reap it; no pooled conversation state.
    group.return_immediately(result)
    result
  })
}
