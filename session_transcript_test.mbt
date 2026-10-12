///|
test "transcript opens Codex log with tool messages and skipped metadata" {
  let source =
    #|{"type":"session_meta","payload":{"cwd":"/sample"}}
    #|{"timestamp":"2026-10-08T10:00:00Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Find 月 notes"}]}}
    #|{"type":"response_item","payload":{"type":"function_call","name":"read_file"}}
    #|{"type":"response_item","payload":{"type":"function_call_output","output":"Notes found"}}
    #|{"type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"The notes are ready."}]}}
  guard @moongate.moongate_preview_transcript_json(
      source,
      source_name="sample.jsonl",
    )
    is Ok(Object(result)) else {
    fail("Expected preview")
  }
  assert_eq(result["format"], Json::string("codex"))
  assert_eq(result["messageCount"], Json::number(4))
  assert_eq(result["skippedRecords"], Json::number(1))
  guard result["messages"] is Array(messages) else { fail("Expected messages") }
  guard messages[0] is Object(first) else { fail("Expected message") }
  assert_eq(first["content"], Json::string("Find 月 notes"))
  assert_true(first.get("ts") is Some(Number(_)))
  guard messages[2] is Object(tool) else { fail("Expected tool") }
  assert_eq(tool["role"], Json::string("tool"))
  assert_eq(tool["content"], Json::string("Notes found"))
}

///|
test "transcript opens Claude messages and explicit source format" {
  let source =
    #|{"type":"user","message":{"role":"user","content":"Hello 🌙"}}
    #|{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Hello back"},{"type":"tool_use","name":"Read"}]}}
    #|{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"File text"}]}}
  guard @moongate.moongate_preview_transcript_json(source, format="claude")
    is Ok(Object(result)) else {
    fail("Expected preview")
  }
  assert_eq(result["format"], Json::string("claude"))
  assert_eq(result["messageCount"], Json::number(3))
  guard result["messages"] is Array(messages) && messages[2] is Object(tool) else {
    fail("Expected messages")
  }
  assert_eq(tool["role"], Json::string("tool"))
  assert_eq(tool["content"], Json::string("File text"))
}

///|
test "transcript reopens normalized JSON and role content arrays" {
  let source =
    #|[
    #|  {"role":"user","content":"Keep my notes","ts":1791453600000},
    #|  {"role":"assistant","content":[{"type":"text","text":"Saved as Markdown"}]}
    #|]
  guard @moongate.moongate_preview_transcript_json(source) is Ok(Object(first)) else {
    fail("Expected preview")
  }
  assert_eq(first["format"], Json::string("json"))
  assert_eq(first["messageCount"], Json::number(2))
  guard @moongate.moongate_preview_transcript_json(
      Json::object(first).stringify(),
    )
    is Ok(Object(reopened)) else {
    fail("Expected reopened preview")
  }
  assert_eq(reopened["messages"], first["messages"])
  let jsonl = "{\"role\":\"user\",\"content\":\"one\"}\n{\"role\":\"assistant\",\"content\":\"two\"}"
  guard @moongate.moongate_preview_transcript_json(jsonl) is Ok(Object(lines)) else {
    fail("Expected JSONL")
  }
  assert_eq(lines["messageCount"], Json::number(2))
}

///|
test "transcript gives actionable empty and malformed input errors" {
  assert_true(
    @moongate.moongate_preview_transcript_json("") is Err(message) &&
    message.contains("paste"),
  )
  assert_true(
    @moongate.moongate_preview_transcript_json(
      "{\"role\":\"user\",\"content\":\"ok\"}\nnot json",
    )
    is Err(message) &&
    message.contains("line 2"),
  )
  assert_true(
    @moongate.moongate_preview_transcript_json("{\"metadata\":true}")
    is Err(message) &&
    message.contains("No readable messages"),
  )
  assert_true(
    @moongate.moongate_preview_transcript_json("[]", format="unknown")
    is Err(message) &&
    message.contains("Choose auto"),
  )
}
