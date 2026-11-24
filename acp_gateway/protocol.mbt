///|
priv struct Rpc {
  read : async () -> Json
  write : async (Json) -> Unit
  mut next_id : Int32
  mut selected_model : String?
  caller_tools : Array[Json]
}

///|
fn protocol_error(message : String) -> BridgeError {
  BridgeError(code=502, kind="acp_protocol_error", message~)
}

///|
async fn Rpc::call(
  self : Rpc,
  method_ : String,
  params : Json,
  session? : String,
  on_text~ : async (String) -> Unit = _ => (),
) -> Json {
  let id = self.next_id
  self.next_id += 1
  (self.write)({
    "jsonrpc": "2.0",
    "id": id,
    "method": method_,
    "params": params,
  })
  for ;; {
    let message = (self.read)()
    guard message is { "jsonrpc": "2.0", .. } else {
      raise protocol_error("Agent stdout is not ACP JSON-RPC")
    }
    match message {
      { "id": response_id, "method": String(client_method), .. } => {
        // Native actions still require an interactive ACP client. Only our
        // no-execution caller relay may be invoked without a separate UI.
        if client_method == "session/request_permission" {
          if message is { "params": params, .. } &&
            session is Some(session_id) &&
            caller_relay_approval(params, session_id, self.caller_tools)
            is Some(outcome) {
            // The only approved action is invoking our request-owned relay.
            // It cannot execute tools. The caller still authorizes execution.
            (self.write)({
              "jsonrpc": "2.0",
              "id": response_id,
              "result": { "outcome": outcome },
            })
            continue
          }
          (self.write)({
            "jsonrpc": "2.0",
            "id": response_id,
            "result": { "outcome": { "outcome": "cancelled" } },
          })
        } else {
          (self.write)({
            "jsonrpc": "2.0",
            "id": response_id,
            "error": {
              "code": -32601,
              "message": "Client method is not supported by the text bridge",
            },
          })
        }
        raise BridgeError(
          code=422,
          kind="acp_interaction_required",
          message="The agent requires interactive tools or permission; use an ACP client",
        )
      }
      {
        "method": "session/update",
        "params": { "sessionId": String(update_session), "update": update, .. },
        ..
      } => {
        guard session is Some(expected) && update_session == expected else {
          raise protocol_error("Agent sent an update for an unexpected session")
        }
        match update {
          {
            "sessionUpdate": "config_option_update",
            "configOptions": Array(options),
            ..
          } =>
            if self.selected_model is Some(expected) &&
              options.any(option => {
                is_model_option(option) &&
                option is { "currentValue": String(actual), .. } &&
                actual != expected
              }) {
              raise protocol_error(
                "Agent changed the selected model during the turn",
              )
            }
          {
            "sessionUpdate": "current_model_update",
            "currentModelId": String(actual),
            ..
          } =>
            if self.selected_model is Some(expected) && actual != expected {
              raise protocol_error(
                "Agent changed the selected model during the turn",
              )
            }
          {
            "sessionUpdate": "agent_message_chunk",
            "content": { "type": "text", "text": String(text), .. },
            ..
          } => on_text(text)
          { "sessionUpdate": "agent_message_chunk", .. } =>
            raise protocol_error("Agent returned non-text output")
          { "sessionUpdate": "tool_call" | "tool_call_update", .. } if self.caller_tools.is_empty() =>
            raise BridgeError(
              code=422,
              kind="acp_tools_unsupported",
              message="Agent tool execution is not an OpenAI tool call; use an interactive ACP client",
            )
          _ => () // Thoughts and status are not assistant answer text.
        }
      }
      { "id": Number(response_id, ..), "error": error, .. } if response_id ==
        id.to_double() => {
        if error is { "code": -32000, .. } {
          raise BridgeError(
            code=401,
            kind="acp_auth_required",
            message="Sign in using the agent's official interactive login, then retry",
          )
        }
        raise BridgeError(
          code=502,
          kind="acp_agent_error",
          message="The ACP agent rejected the request; inspect its own status and account limits",
        )
      }
      { "id": Number(response_id, ..), "result": result, .. } if response_id ==
        id.to_double() => return result
      { "id"? : Some(_), .. } =>
        raise protocol_error("Unexpected ACP response ID")
      _ => ()
    }
  }
}

///|
fn option_has_model(options : Json, model : String) -> Bool {
  guard options is Array(items) else { return false }
  items.any(item => {
    match item {
      { "value": String(value), .. } => value == model
      { "options": Array(nested), .. } =>
        nested.any(value => value is { "value": String(id), .. } && id == model)
      _ => false
    }
  })
}

///|
fn is_model_option(option : Json) -> Bool {
  match option {
    { "category": "model", .. } => true
    { "category"? : None, "id": "model", .. } => true
    _ => false
  }
}

///|
async fn Rpc::select_model(
  self : Rpc,
  session : Json,
  session_id : String,
  model : String,
) -> Unit {
  if session is { "configOptions": Array(options), .. } {
    for option in options {
      if option
        is { "id": String(config_id), "type": "select", "options": values, .. } &&
        is_model_option(option) {
        guard option_has_model(values, model) else {
          raise BridgeError(
            code=404,
            kind="model_unavailable",
            message="The selected model is not available in the ACP account/session",
          )
        }
        if option is { "currentValue": String(current), .. } && current == model {
          return
        }
        let result = self.call(
          "session/set_config_option",
          { "sessionId": session_id, "configId": config_id, "value": model },
          session=session_id,
        )
        guard result is { "configOptions": Array(updated), .. } &&
          updated.any(value => {
            value is { "id": String(id), "currentValue": String(current), .. } &&
            id == config_id &&
            current == model
          }) else {
          raise protocol_error("Agent did not confirm the requested model")
        }
        return
      }
    }
  }
  // ACP v1 agents may expose the older per-session model selector.
  if session
    is {
      "models": {
        "currentModelId": String(current),
        "availableModels": Array(models),
        ..
      },
      ..
    } {
    guard models.any(value => {
      value is { "modelId": String(id), .. } && id == model
    }) else {
      raise BridgeError(
        code=404,
        kind="model_unavailable",
        message="The selected model is not available in the ACP account/session",
      )
    }
    if current != model {
      ignore(
        self.call(
          "session/set_model",
          { "sessionId": session_id, "modelId": model },
          session=session_id,
        ),
      )
    }
    return
  }
  raise BridgeError(
    code=422,
    kind="acp_model_selection_unavailable",
    message="Agent does not expose a verifiable model selector",
  )
}

///|
async fn Rpc::complete(
  self : Rpc,
  cwd : String,
  chat : ChatRequest,
  on_text : async (String) -> Unit,
  mcp_servers~ : Array[Json] = [],
) -> (String, String) {
  let initialized = self.call("initialize", {
    "protocolVersion": 1,
    "clientCapabilities": {},
    "clientInfo": { "name": "moongate-text-bridge", "version": "0.1.4" },
  })
  guard initialized is { "protocolVersion": 1, .. } else {
    raise protocol_error("Agent does not support ACP protocol version 1")
  }
  let session = self.call("session/new", {
    "cwd": cwd,
    "mcpServers": Json::array(mcp_servers),
  })
  guard session is { "sessionId": String(session_id), .. } &&
    !session_id.is_empty() else {
    raise protocol_error("Agent did not create an ACP session")
  }
  self.select_model(session, session_id, chat.model)
  self.selected_model = Some(chat.model)
  let answer = StringBuilder()
  let mut answer_length = 0
  let result = self.call(
    "session/prompt",
    {
      "sessionId": session_id,
      "prompt": [{ "type": "text", "text": chat.prompt }],
    },
    session=session_id,
    on_text=text => {
      answer_length += text.length()
      if answer_length > 2097152 {
        raise protocol_error("Agent output exceeded the text bridge limit")
      }
      answer.write_string(text)
      on_text(text)
    },
  )
  let finish = match result {
    { "stopReason": "end_turn", .. } => "stop"
    { "stopReason": "max_tokens", .. } => "length"
    { "stopReason": "refusal", .. } => "content_filter"
    _ => raise protocol_error("Agent did not complete the turn")
  }
  if answer_length == 0 && finish != "content_filter" {
    raise protocol_error("Agent completed without text output")
  }
  (answer.to_string(), finish)
}
