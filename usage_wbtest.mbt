///|
fn parse_usage_wbtest_json(body : String) -> Json {
  @json.parse(body) catch {
    _ => Json::null()
  }
}

///|
test "moonstat empty usage keeps response model fallback" {
  let body = parse_usage_wbtest_json("{\"model\":\"gpt-5\"}")
  let usage = token_usage_or_response_model(None, body, ["model"])
  assert_eq(usage.input_tokens, 0)
  assert_eq(usage.output_tokens, 0)
  assert_eq(usage.model, Some("gpt-5"))
}

///|
test "moonstat empty usage keeps gemini response model fallback" {
  let body = parse_usage_wbtest_json("{\"modelVersion\":\"gemini-2.5-pro\"}")
  let usage = token_usage_or_response_model(None, body, ["modelVersion"])
  assert_eq(usage.model, Some("gemini-2.5-pro"))
}

///|
test "moonstat response model fallback does not replace parsed usage model" {
  let body = parse_usage_wbtest_json("{\"model\":\"fallback-model\"}")
  let parsed = TokenUsage::new(
    input_tokens=1,
    output_tokens=2,
    model=Some("usage-model"),
  )
  let usage = token_usage_or_response_model(Some(parsed), body, ["model"])
  assert_eq(usage.input_tokens, 1)
  assert_eq(usage.output_tokens, 2)
  assert_eq(usage.model, Some("usage-model"))
}
