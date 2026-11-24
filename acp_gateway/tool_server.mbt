///|
fn caller_relay_approval(
  params : Json,
  session : String,
  tools : Array[Json],
) -> Json? {
  guard params
    is {
      "sessionId": String(actual),
      "toolCall": { "name": String(name), .. },
      "options": Array(options),
      ..
    } &&
    actual == session &&
    tools.any(tool => {
      tool is { "name": String(allowed), .. } &&
      name == "mcp_moongate_client_" + allowed
    }) else {
    return None
  }
  for option in options {
    if option is { "kind": "allow_once", "optionId": String(id), .. } {
      return Some({ "outcome": "selected", "optionId": id })
    }
  }
  None
}

///|
async fn serve_caller_tools(
  request : @httpx.RequestReader,
  writer : @httpx.ResponseWriter,
  token : String,
  tools : Array[Json],
  call_id : String,
  handoff : async (Json) -> Json,
) -> Unit {
  if request.headers.contains("origin") ||
    request.headers.get("authorization") != Some("Bearer \{token}") {
    return json_reply(writer, 403, { "error": "Unauthorized caller tool relay" })
  }
  if request.method_ != Post || request.path != "/mcp" {
    return json_reply(writer, 405, { "error": "Use MCP POST" })
  }
  let rpc = read_body(request.body)
  guard rpc is { "jsonrpc": "2.0", .. } else {
    return json_reply(writer, 400, { "error": "Expected JSON-RPC" })
  }
  guard rpc is { "id": id, "method": String(method_), .. } else {
    writer.write_header(202)
    writer.close()
    return
  }
  let result : Json = match method_ {
    "initialize" =>
      {
        "protocolVersion": "2025-03-26",
        "serverInfo": { "name": "moongate_client", "version": "0.1.4" },
        "capabilities": { "tools": {} },
        "instructions": "Tools are deferred to the caller. No operation runs in this server.",
      }
    "ping" => {}
    "tools/list" => { "tools": Json::array(tools) }
    "tools/call" => {
      guard rpc
        is {
          "params": { "name": String(name), "arguments": Object(arguments), .. },
          ..
        } &&
        tools.any(tool => {
          tool is { "name": String(allowed), .. } && allowed == name
        }) else {
        return json_reply(writer, 200, {
          "jsonrpc": "2.0",
          "id": id,
          "error": {
            "code": -32602,
            "message": "Unknown tool or invalid arguments",
          },
        })
      }
      // Wait for the caller's actual result; this server never executes tools.
      handoff({
        "id": call_id,
        "type": "function",
        "function": {
          "name": name,
          "arguments": Json::object(arguments).stringify(),
        },
      })
    }
    _ =>
      return json_reply(writer, 200, {
        "jsonrpc": "2.0",
        "id": id,
        "error": { "code": -32601, "message": "Method not supported" },
      })
  }
  json_reply(writer, 200, { "jsonrpc": "2.0", "id": id, "result": result })
}
