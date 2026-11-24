///|
fn tool_request(stream~ : Bool = false) -> Json {
  {
    "model": "alpha",
    "stream": stream,
    "messages": [{ "role": "user", "content": "Use the write tool" }],
    "tools": [
      {
        "type": "function",
        "function": {
          "name": "write",
          "description": "Write a caller workspace file",
          "parameters": {
            "type": "object",
            "properties": {
              "path": { "type": "string" },
              "content": { "type": "string" },
            },
            "required": ["path", "content"],
          },
        },
      },
    ],
  }
}

///|
test "ACP only approves invocation of the declared no-execution relay once" {
  let options : Json = [
    { "kind": "allow_always", "optionId": "always" },
    { "kind": "allow_once", "optionId": "once" },
  ]
  let tools : Array[Json] = [{ "name": "write" }]
  let allowed = caller_relay_approval(
    {
      "sessionId": "s",
      "toolCall": { "name": "mcp_moongate_client_write" },
      "options": options,
    },
    "s",
    tools,
  )
  assert_true(
    allowed is Some({ "outcome": "selected", "optionId": "once", .. }),
  )
  for
    name in [
      "write_file", "terminal/create", "mcp_other_write", "mcp_moongate_client_shell",
    ] {
    assert_true(
      caller_relay_approval(
        { "sessionId": "s", "toolCall": { "name": name }, "options": options },
        "s",
        tools,
      )
      is None,
    )
  }
  assert_true(
    caller_relay_approval(
      {
        "sessionId": "other",
        "toolCall": { "name": "mcp_moongate_client_write" },
        "options": options,
      },
      "s",
      tools,
    )
    is None,
  )
}

///|
test "ACP caller tools retain tool history and refuse incomplete results" {
  let source = tool_request()
  let initial = parse_chat(source, ["alpha"], tools_enabled=true)
  assert_eq(initial.tools.length(), 1)
  guard source is Object(fields) else { fail("expected object") }
  let fields = fields.copy()
  let messages : Array[Json] = [
    { "role": "user", "content": "Write proof" },
    {
      "role": "assistant",
      "content": null,
      "tool_calls": [
        {
          "id": "call_1",
          "type": "function",
          "function": {
            "name": "write",
            "arguments": "{\"path\":\"proof.txt\",\"content\":\"ok\"}",
          },
        },
      ],
    },
    { "role": "tool", "tool_call_id": "call_1", "content": "File saved" },
  ]
  fields["messages"] = Json::array(messages)
  let continued = parse_chat(
    Json::object(fields),
    ["alpha"],
    tools_enabled=true,
  )
  assert_true(continued.prompt.contains("File saved"))
  fields["messages"] = Json([
    { "role": "tool", "tool_call_id": "unknown", "content": "Fake success" },
  ])
  try parse_chat(Json::object(fields), ["alpha"], tools_enabled=true) catch {
    BridgeError(kind="unsupported_chat_request", ..) => ()
    error => raise error
  } noraise {
    _ => fail("Unmatched tool result accepted")
  }
}

///|
async test "ACP real MCP handoff returns JSON and SSE calls without executing them" {
  let bridge = { ..fixture_bridge("caller-tools"), tools: true, }
  with_bridge(bridge, base => {
    for stream in [false, true] {
      let (response, data) = @http.post(
        "\{base}/v1/chat/completions",
        tool_request(stream~).stringify(),
        headers={
          "authorization": "Bearer local-fixture-token",
          "content-type": "application/json",
        },
      )
      assert_eq(response.code, 200)
      let body = data.text()
      assert_true(body.contains("tool_calls"))
      assert_true(body.contains("proof.txt"))
      assert_true(body.contains("write"))
      if stream {
        assert_true(body.has_suffix("data: [DONE]\n\n"))
      } else {
        assert_true(
          @json.parse(body)
          is {
            "choices": [
              {
                "finish_reason": "tool_calls",
                "message": {
                  "tool_calls": [{ "function": { "name": "write", .. }, .. }],
                  ..
                },
                ..
              },
            ],
            ..
          },
        )
      }
    }
  })
}

///|
async test "ACP caller tool result resumes the original live process and session" {
  let bridge = { ..fixture_bridge("caller-tools-reuse"), tools: true, }
  with_bridge(bridge, base => {
    let body = tool_request()
    let headers = {
      "authorization": "Bearer local-fixture-token",
      "content-type": "application/json",
    }
    let (first, data) = @http.post(
      "\{base}/v1/chat/completions",
      body.stringify(),
      headers~,
    )
    assert_eq(first.code, 200)
    guard @json.parse(data.text())
      is { "choices": [{ "message": message, .. }], .. } &&
      message is { "tool_calls": [{ "id": String(id), .. }], .. } else {
      fail("Missing handoff")
    }
    assert_eq(bridge.live_sessions, 1)
    assert_true(bridge.pending_sessions.contains(id))
    guard body is Object(fields) else { fail("Expected request") }
    let fields = fields.copy()
    fields["messages"] = [
      { "role": "user", "content": "Use the write tool" },
      message,
      { "role": "tool", "tool_call_id": id, "content": "saved by caller" },
    ]
    fields["stream"] = true
    let client = @http.Client(base, headers~)
    defer client.close()
    let response = client.post(
      "/v1/chat/completions",
      Json::object(fields).stringify(),
    )
    assert_eq(response.code, 200)
    // The first text is available while the same fixture is still generating.
    let early = StringBuilder()
    while !early.to_string().contains("resumed ") {
      guard client.read_some(max_len=8192) is Some(chunk) else {
        fail("Missing live text")
      }
      early.write_string(@utf8.decode(chunk))
    }
    assert_false(early.to_string().contains("[DONE]"))
    let rest = client.read_all().text()
    assert_true(rest.contains("same session"))
    assert_true(rest.has_suffix("data: [DONE]\n\n"))
    assert_eq(bridge.pending_sessions.length(), 0)
    @async.with_timeout(1000, () => {
      while bridge.live_sessions > 0 {
        @async.sleep(1)
      }
    })
  })
}
