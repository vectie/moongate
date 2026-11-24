///|
test "provider tests require model output rather than HTTP success" {
  assert_false(
    provider_test_completed_response("<html>OK</html>", "openai_chat"),
  )
  assert_false(provider_test_completed_response("{}", "openai_chat"))
  assert_false(
    provider_test_completed_response(
      "{\"error\":{\"message\":\"denied\"}}", "openai_chat",
    ),
  )
  assert_false(
    provider_test_completed_response(
      "{\"choices\":[{\"message\":{\"content\":\"\"}}]}", "openai_chat",
    ),
  )
  assert_true(
    provider_test_completed_response(
      "{\"choices\":[{\"message\":{\"content\":\"OK\"}}]}", "openai_chat",
    ),
  )
  assert_true(
    provider_test_completed_response(
      "{\"content\":[{\"type\":\"text\",\"text\":\"OK\"}]}", "anthropic",
    ),
  )
  assert_true(
    provider_test_completed_response(
      "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"OK\"}]}}]}", "gemini_native",
    ),
  )
  let completed = "{\"status\":\"completed\",\"output\":[{\"content\":[{\"type\":\"output_text\",\"text\":\"OK\"}]}]}"
  assert_true(provider_test_completed_response(completed, "openai_responses"))
  assert_true(
    provider_test_completed_response(
      "data: {\"type\":\"response.completed\",\"response\":" +
      completed +
      "}\n\n",
      "openai_responses",
    ),
  )
  assert_false(
    provider_test_completed_response(
      "data: {\"type\":\"response.output_text.delta\",\"delta\":\"OK\"}\n\n", "openai_responses",
    ),
  )
}

///|
test "partial output is not a completed provider check" {
  for
    (body, format) in [
      (
        "{\"choices\":[{\"message\":{\"content\":\"partial\"},\"finish_reason\":\"length\"}]}",
        "openai_chat",
      ),
      (
        "{\"content\":[{\"text\":\"partial\"}],\"stop_reason\":\"max_tokens\"}",
        "anthropic",
      ),
      (
        "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"partial\"}]},\"finishReason\":\"MAX_TOKENS\"}]}",
        "gemini_native",
      ),
      (
        "{\"status\":\"failed\",\"choices\":[{\"message\":{\"content\":\"partial\"}}]}",
        "openai_chat",
      ),
    ] {
    assert_false(provider_test_completed_response(body, format))
  }
}
