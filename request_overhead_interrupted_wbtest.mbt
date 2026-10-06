///|
test "stream buffering preserves partial Unicode and ignores repeated completion" {
  let state = ChatToCodexResponsesStreamState::new_with_context(
    "synthetic",
    codex_chat_empty_tool_context(),
  )
  let first = state.push_text_delta("你")
  let empty = state.push_text_delta("")
  let second = state.push_text_delta("🌙\n")
  assert_eq(first.length(), 3)
  assert_eq(empty.length(), 1)
  assert_eq(second.length(), 1)
  guard second[0] is Object(delta) else { fail("missing delta") }
  assert_eq(delta["delta"], Json::string("🌙\n"))
  // No upstream completion is needed to finalize a partial stream.
  let final_text = state.finish_text()
  guard final_text[0] is Object(done) else { fail("missing completion") }
  assert_eq(done["text"], Json::string("你🌙\n"))
  assert_eq(state.finish_text().length(), 0)
  let (_, invalid, invalid_events) = openai_chat_stream_data_to_codex_response_events(
    "{", state,
  )
  assert_eq(invalid, None)
  assert_eq(invalid_events.length(), 0)
  ignore(state.finish())
  assert_eq(state.finish().length(), 0)
}
