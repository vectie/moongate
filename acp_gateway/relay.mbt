///|
/// Private-process MCP stdio relay. The bearer token is supplied via the
/// subprocess environment, never command-line arguments or stdout diagnostics.
pub async fn run_tool_relay(url : String) -> Unit {
  guard url.strip_prefix("http://127.0.0.1:") is Some(rest) &&
    rest.has_suffix("/mcp") else {
    raise invalid_config("Tool relay requires a loopback MCP endpoint")
  }
  let port = rest[:rest.length() - 4]
  if port.is_empty() || !port.iter().all(c => c is ('0'..<='9')) {
    raise invalid_config("Invalid relay port")
  }
  let token = @os.getenv("MOONGATE_MCP_TOKEN").unwrap_or("")
  guard !token.is_empty() else {
    raise invalid_config("Missing relay credential")
  }
  let frames : Frames = { reader: @stdio.stdin, pending: b"", offset: 0, }
  for ;; {
    let rpc = frames.next()
    let client = @http.Client::Client("http://127.0.0.1:\{port}", headers={
      "authorization": "Bearer \{token}",
      "content-type": "application/json",
      "accept": "application/json, text/event-stream",
    })
    defer client.close()
    let response = client.post("/mcp", rpc.stringify())
    if response.code == 202 {
      continue
    }
    if response.code != 200 {
      raise protocol_error(
        "Caller tool relay disconnected or rejected the request",
      )
    }
    let result = read_body(client)
    @stdio.stdout.write("\{result.stringify()}\n")
  }
}
