///|
test "moonstat short value hash uses canonical json sha256 prefix" {
  let left = @json.parse(
    (
      #|{
      #|  "b": 2,
      #|  "a": 1
      #|}
    ),
  )
  let right = @json.parse("{\"a\":1,\"b\":2}")
  assert_eq(short_value_hash(Some(left)), "43258cff783fe703")
  assert_eq(short_value_hash(Some(left)), short_value_hash(Some(right)))
  assert_eq(short_value_hash(None), "absent")
}

///|
test "moonstat prompt cache trace message mirrors forwarder diagnostic" {
  let body = @json.parse(
    (
      #|{
      #|  "prompt_cache_key": "session-123",
      #|  "store": false,
      #|  "stream": true,
      #|  "instructions": "hello",
      #|  "tools": [{ "name": "lookup" }],
      #|  "input": [{ "role": "user", "content": "hi" }],
      #|  "include": ["message.output_text"]
      #|}
    ),
  )
  let message = prompt_cache_trace_message(
    "codex",
    "codex-oauth",
    "/v1/responses",
    Some("openai_responses"),
    body,
    true,
  )
  assert_true(
    message.has_prefix("[CacheTrace] app=codex, provider=codex-oauth"),
  )
  assert_true(message.contains("endpoint=/v1/responses"))
  assert_true(message.contains("api_format=openai_responses"))
  assert_true(message.contains("session_client_provided=true"))
  assert_true(message.contains("prompt_cache_key=present(len=11)"))
  assert_true(message.contains("store=false"))
  assert_true(message.contains("stream=true"))
  assert_true(message.contains("instructions_hash="))
  assert_true(message.contains("tools_hash="))
  assert_true(message.contains("input_hash="))
  assert_true(message.contains("include_hash="))
  assert_true(message.contains("body_hash="))
}
