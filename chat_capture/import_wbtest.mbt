///|
fn field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn imported(captures : Array[(String, String)]) -> Json raise {
  match import_chat_captures_json(captures) {
    Ok(result) => result
    Err(error) => fail(error)
  }
}

///|
fn chat_json(id : String, usage : String) -> String {
  "{\"id\":\"" +
  id +
  "\",\"object\":\"chat.completion\",\"model\":\"fixture-model\",\"created\":1791504000,\"choices\":[{\"index\":0,\"message\":{\"content\":\"PRIVATE_PAYLOAD\",\"tool_calls\":[\"PRIVATE_TOOL\"]},\"finish_reason\":\"length\"}],\"usage\":" +
  usage +
  "}"
}

///|
fn chat_sse(id : String, tail : String) -> String {
  "data: {\"id\":\"" +
  id +
  "\",\"object\":\"chat.completion.chunk\",\"model\":\"fixture-model\",\"choices\":[{\"index\":0,\"delta\":{\"content\":\"PRIVATE_STREAM\"},\"finish_reason\":null}],\"usage\":null}\n\ndata: {\"id\":\"" +
  id +
  "\",\"object\":\"chat.completion.chunk\",\"model\":\"fixture-model\",\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}],\"usage\":null}\n\n" +
  tail
}

///|
fn usage_event(id : String) -> String {
  "data: {\"id\":\"" +
  id +
  "\",\"object\":\"chat.completion.chunk\",\"model\":\"fixture-model\",\"choices\":[],\"usage\":{\"prompt_tokens\":10,\"completion_tokens\":2,\"total_tokens\":12}}\n\n"
}

///|
test "JSON and SSE import as requests with unknown costs and reopen filters" {
  let result = imported([
    (
      "one.json",
      chat_json(
        "chat-1", "{\"prompt_tokens\":3,\"completion_tokens\":2,\"total_tokens\":5,\"prompt_tokens_details\":{\"cached_tokens\":3}}",
      ),
    ),
    ("two.sse", chat_sse("chat-2", usage_event("chat-2") + "data: [DONE]\n\n")),
  ])
  assert_eq(field(field(result, "summary"), "tokens"), (17).to_json())
  assert_eq(field(field(result, "summary"), "missingCostCount"), (2).to_json())
  assert_eq(field(result, "sourceCoverageUnknown"), true.to_json())
  guard field(result, "data") is Array(rows) else { fail("rows") }
  assert_eq(rows.length(), 2)
  assert_eq(field(rows[0], "requestId"), "chat-1".to_json())
  assert_eq(field(rows[0], "captureIndex"), (1).to_json())
  assert_eq(field(rows[0], "date"), "2026-10-09".to_json())
  assert_eq(field(rows[0], "totalCostUsd"), Json::null())
  assert_true(!result.stringify().contains("PRIVATE_"))
  assert_true(!result.stringify().contains("cached_tokens"))
  guard @usage_preview.moongate_preview_usage_file_json(
      result.stringify(),
      start_day="2026-10-09",
      end_day="2026-10-09",
    )
    is Ok(reopened) else {
    fail("reopen")
  }
  assert_eq(field(reopened, "total"), (1).to_json())
  assert_eq(field(field(reopened, "summary"), "tokens"), (5).to_json())
  assert_eq(field(reopened, "sourceTotal"), (2).to_json())
  assert_eq(field(reopened, "sourceCoverageUnknown"), true.to_json())
}

///|
test "missing partial interrupted error and empty captures remain explicit" {
  let result = imported([
    ("missing.json", chat_json("missing", "null")),
    ("partial.json", chat_json("partial", "{\"prompt_tokens\":3}")),
    ("cut.sse", chat_sse("cut", usage_event("cut"))),
    (
      "error.sse",
      chat_sse(
        "err", "data: {\"error\":{\"message\":\"PRIVATE_ERROR\"}}\n\ndata: [DONE]\n\n",
      ),
    ),
    ("empty", ""),
    (
      "zero.json",
      chat_json(
        "zero", "{\"prompt_tokens\":0,\"completion_tokens\":0,\"total_tokens\":0}",
      ),
    ),
  ])
  assert_eq(field(result, "total"), (1).to_json())
  assert_eq(field(result, "sourceTotal"), (6).to_json())
  let details = field(result, "chatCaptureImport")
  assert_eq(field(field(details, "stateCounts"), "completed"), (3).to_json())
  guard field(details, "outcomes") is Array(outcomes) else { fail("outcomes") }
  assert_eq(field(outcomes[0], "usageState"), "missing".to_json())
  assert_eq(field(outcomes[1], "usageState"), "incomplete".to_json())
  assert_eq(field(outcomes[2], "state"), "incomplete".to_json())
  assert_eq(field(outcomes[2], "usageState"), "unavailable".to_json())
  assert_eq(
    field(field(outcomes[2], "observedUsage"), "total_tokens"),
    (12).to_json(),
  )
  assert_eq(field(outcomes[3], "state"), "errored".to_json())
  assert_eq(field(outcomes[4], "state"), "empty".to_json())
  assert_true(!result.stringify().contains("PRIVATE_"))
}

///|
test "SSE framing comments multiline CRLF and missing DONE" {
  let complete = chat_sse("s", "data: [DONE]\n\n")
  let crlf = complete.split("\n").collect().join("\r\n")
  let parsed = parse_chat_capture(
    ": keepalive\r\nevent: message\r\nid: ignored\r\nretry: 1000\r\n" + crlf,
  )
  assert_eq(parsed.state, "completed")
  assert_eq(parsed.objects, 2)
  assert_eq(
    parse_chat_capture(chat_sse("s", "data: [DONE]\n")).state,
    "incomplete",
  )
  assert_eq(parse_chat_capture(chat_sse("s", "")).state, "incomplete")
  let multiline = "data: {\n" +
    "data: \"id\":\"multi\",\"object\":\"chat.completion.chunk\",\"model\":\"m\",\n" +
    "data: \"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"tool_calls\"}]}\n\ndata: [DONE]\n\n"
  assert_eq(parse_chat_capture(multiline).state, "completed")
  assert_eq(parse_chat_capture("data: [DONE]\n\n").state, "incomplete")
}

///|
test "all observed choices must finish and reasons do not leak arbitrary text" {
  let content = "{\"object\":\"chat.completion\",\"id\":\"n\",\"model\":\"m\",\"choices\":[{\"index\":1,\"message\":{},\"finish_reason\":null},{\"index\":0,\"message\":{},\"finish_reason\":\"PRIVATE_REASON\"}]}"
  let parsed = parse_chat_capture(content)
  assert_eq(parsed.state, "incomplete")
  assert_eq(field(parsed.finishes[0], "finishReason"), "unrecognized".to_json())
  assert_eq(field(parsed.finishes[1], "finishReason"), Json::null())
}

///|
test "conflicting identity malformed source and repeated request reject atomically" {
  let valid = chat_json(
    "one", "{\"prompt_tokens\":1,\"completion_tokens\":1,\"total_tokens\":2}",
  )
  assert_true(import_chat_captures_json([("a", valid), ("b", valid)]) is Err(_))
  for
    bad in [
      "[]",
      "{bad PRIVATE_BAD",
      "data: {bad PRIVATE_BAD\n\n",
      chat_sse("one", usage_event("two") + "data: [DONE]\n\n"),
      chat_sse("one", usage_event("one") + usage_event("one")),
      chat_sse("one", "data: [DONE]\n\ndata: [DONE]\n\n"),
      valid.replace(old="chat.completion", new="response"),
      valid.replace(old="\"index\":0", new="\"index\":-1"),
      valid.replace(old="\"model\":\"fixture-model\"", new="\"model\":\"\""),
    ] {
    guard import_chat_captures_json([("good", valid), ("bad", bad)])
      is Err(error) else {
      fail("expected rejection")
    }
    assert_true(!error.contains("PRIVATE_BAD"))
  }
}

///|
test "usage count validation does not round fabricate or double count subsets" {
  for
    metrics in [
      "{\"prompt_tokens\":-1}", "{\"prompt_tokens\":1.00000000000000001}", "{\"prompt_tokens\":\"3\"}",
      "{\"prompt_tokens\":9007199254740992}", "{\"prompt_tokens\":1,\"completion_tokens\":2,\"total_tokens\":4}",
      "{\"prompt_tokens\":9007199254740991,\"completion_tokens\":1,\"total_tokens\":9007199254740991}",
    ] {
    assert_true(
      import_chat_captures_json([("a", chat_json("a", metrics))]) is Err(_),
    )
  }
  let exact = imported([
    (
      "a",
      chat_json(
        "a", "{\"prompt_tokens\":1e1,\"completion_tokens\":2.0,\"total_tokens\":12}",
      ),
    ),
  ])
  assert_eq(field(field(exact, "summary"), "tokens"), (12).to_json())
}

///|
test "combined bounds and empty labels reject without output" {
  assert_true(import_chat_captures_json([]) is Err(_))
  assert_true(import_chat_captures_json([("a", "")], app=" ") is Err(_))
  assert_true(import_chat_captures_json([("a", ""), ("a", "")]) is Err(_))
  assert_true(import_chat_captures_json(Array::make(101, ("a", ""))) is Err(_))
}
