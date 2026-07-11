///|
fn parse_json_for_test(body : String) -> Json {
  let parsed : Result[Json, Error] = try @json.parse(body) catch {
    error => Err(error)
  } noraise {
    value => Ok(value)
  }
  match parsed {
    Ok(json) => json
    Err(_) => Json::null()
  }
}

///|
test "claude usage preserves cache-only billable tokens" {
  let body =
    #|{
    #|  "id": "msg_1",
    #|  "model": "claude-sonnet",
    #|  "usage": {
    #|    "input_tokens": 0,
    #|    "output_tokens": 0,
    #|    "cache_read_input_tokens": 42,
    #|    "cache_creation_input_tokens": 0
    #|  }
    #|}
  let usage = token_usage_from_claude_response(parse_json_for_test(body)).unwrap()
  assert_eq(usage.input_tokens, 0)
  assert_eq(usage.output_tokens, 0)
  assert_eq(usage.cache_read_tokens, 42)
  assert_eq(usage.message_id, Some("msg_1"))
  assert_true(usage.has_billable_tokens())
}

///|
test "codex usage reads cached tokens from details" {
  let body =
    #|{
    #|  "model": "gpt-5",
    #|  "usage": {
    #|    "input_tokens": 100,
    #|    "output_tokens": 7,
    #|    "input_tokens_details": { "cached_tokens": 31 },
    #|    "cache_creation_input_tokens": 5
    #|  }
    #|}
  let usage = token_usage_from_codex_response_auto(parse_json_for_test(body)).unwrap()
  assert_eq(usage.input_tokens, 100)
  assert_eq(usage.output_tokens, 7)
  assert_eq(usage.cache_read_tokens, 31)
  assert_eq(usage.cache_creation_tokens, 5)
  assert_eq(usage.anthropic_input_tokens(), 64)
  assert_eq(usage.model, Some("gpt-5"))
}

///|
test "openai usage maps prompt and completion tokens" {
  let body =
    #|{
    #|  "model": "gpt-4.1",
    #|  "usage": {
    #|    "prompt_tokens": 12,
    #|    "completion_tokens": 8,
    #|    "prompt_tokens_details": { "cached_tokens": 4 }
    #|  }
    #|}
  let usage = token_usage_from_codex_response_auto(parse_json_for_test(body)).unwrap()
  assert_eq(usage.input_tokens, 12)
  assert_eq(usage.output_tokens, 8)
  assert_eq(usage.cache_read_tokens, 4)
  assert_eq(usage.anthropic_input_tokens(), 8)
}

///|
test "usage parser rejects negative required token counts like moongate" {
  let claude =
    #|{
    #|  "usage": {
    #|    "input_tokens": -1,
    #|    "output_tokens": 5
    #|  }
    #|}
  assert_true(
    token_usage_from_claude_response(parse_json_for_test(claude)) is None,
  )
  let openai =
    #|{
    #|  "usage": {
    #|    "prompt_tokens": 10,
    #|    "completion_tokens": -2
    #|  }
    #|}
  assert_true(
    token_usage_from_openai_response(parse_json_for_test(openai)) is None,
  )
  let gemini =
    #|{
    #|  "usageMetadata": {
    #|    "promptTokenCount": -3,
    #|    "totalTokenCount": 12
    #|  }
    #|}
  assert_true(
    token_usage_from_gemini_response(parse_json_for_test(gemini)) is None,
  )
}

///|
test "usage parser rejects fractional required token counts like moongate" {
  let codex =
    #|{
    #|  "usage": {
    #|    "input_tokens": 10.5,
    #|    "output_tokens": 2
    #|  }
    #|}
  assert_true(
    token_usage_from_codex_response(parse_json_for_test(codex)) is None,
  )
  let openai =
    #|{
    #|  "usage": {
    #|    "prompt_tokens": 10,
    #|    "completion_tokens": 2.25
    #|  }
    #|}
  assert_true(
    token_usage_from_openai_response(parse_json_for_test(openai)) is None,
  )
}

///|
test "usage parser treats invalid optional cache fields as absent like moongate" {
  let body =
    #|{
    #|  "usage": {
    #|    "input_tokens": 10,
    #|    "output_tokens": 2,
    #|    "cache_read_input_tokens": -7,
    #|    "cache_creation_input_tokens": 1.5
    #|  }
    #|}
  let usage = token_usage_from_codex_response(parse_json_for_test(body)).unwrap()
  assert_eq(usage.input_tokens, 10)
  assert_eq(usage.output_tokens, 2)
  assert_eq(usage.cache_read_tokens, 0)
  assert_eq(usage.cache_creation_tokens, 0)
}

///|
test "anthropic usage input clamps when cache exceeds input" {
  let usage = TokenUsage::new(
    input_tokens=100,
    output_tokens=50,
    cache_read_tokens=80,
    cache_creation_tokens=50,
  )
  assert_eq(usage.anthropic_input_tokens(), 0)
}

///|
test "gemini usage derives output from total minus prompt" {
  let body =
    #|{
    #|  "modelVersion": "gemini-2.5-pro",
    #|  "usageMetadata": {
    #|    "promptTokenCount": 20,
    #|    "totalTokenCount": 55,
    #|    "cachedContentTokenCount": 9
    #|  }
    #|}
  let usage = token_usage_from_gemini_response(parse_json_for_test(body)).unwrap()
  assert_eq(usage.input_tokens, 20)
  assert_eq(usage.output_tokens, 35)
  assert_eq(usage.cache_read_tokens, 9)
  assert_eq(usage.model, Some("gemini-2.5-pro"))
}

///|
test "claude stream usage uses smaller positive delta input like moongate" {
  let events = [
    parse_json_for_test(
      (
        #|{
        #|  "type": "message_start",
        #|  "message": {
        #|    "id": "msg_stream",
        #|    "model": "qwen-max",
        #|    "usage": {
        #|      "input_tokens": 200000,
        #|      "cache_read_input_tokens": 120000,
        #|      "cache_creation_input_tokens": 500
        #|    }
        #|  }
        #|}
      ),
    ),
    parse_json_for_test(
      (
        #|{
        #|  "type": "message_delta",
        #|  "usage": {
        #|    "input_tokens": 80000,
        #|    "output_tokens": 1000,
        #|    "cache_read_input_tokens": 120000,
        #|    "cache_creation_input_tokens": 500
        #|  }
        #|}
      ),
    ),
  ]
  let usage = token_usage_from_claude_stream_events(events).unwrap()
  assert_eq(usage.input_tokens, 80000)
  assert_eq(usage.output_tokens, 1000)
  assert_eq(usage.cache_read_tokens, 120000)
  assert_eq(usage.cache_creation_tokens, 500)
  assert_eq(usage.model, Some("qwen-max"))
  assert_eq(usage.message_id, Some("msg_stream"))
}

///|
test "claude stream usage keeps cache-only billable usage" {
  let events = [
    parse_json_for_test(
      (
        #|{
        #|  "type": "message_start",
        #|  "message": {
        #|    "usage": {
        #|      "input_tokens": 0,
        #|      "output_tokens": 0,
        #|      "cache_read_input_tokens": 50000
        #|    }
        #|  }
        #|}
      ),
    ),
  ]
  let usage = token_usage_from_claude_stream_events(events).unwrap()
  assert_eq(usage.input_tokens, 0)
  assert_eq(usage.output_tokens, 0)
  assert_eq(usage.cache_read_tokens, 50000)
}

///|
test "claude stream usage skips all zero synthetic usage" {
  let events = [
    parse_json_for_test(
      (
        #|{
        #|  "type": "message_delta",
        #|  "usage": { "output_tokens": 0 }
        #|}
      ),
    ),
  ]
  assert_true(token_usage_from_claude_stream_events(events) is None)
}

///|
test "codex stream auto parses response completed usage" {
  let events = [
    parse_json_for_test(
      (
        #|{
        #|  "type": "response.output_text.delta",
        #|  "delta": "hello"
        #|}
      ),
    ),
    parse_json_for_test(
      (
        #|{
        #|  "type": "response.completed",
        #|  "response": {
        #|    "id": "resp_1",
        #|    "model": "gpt-5",
        #|    "usage": {
        #|      "input_tokens": 10,
        #|      "output_tokens": 2,
        #|      "input_tokens_details": { "cached_tokens": 4 }
        #|    }
        #|  }
        #|}
      ),
    ),
  ]
  let usage = token_usage_from_codex_stream_events_auto(events).unwrap()
  assert_eq(usage.input_tokens, 10)
  assert_eq(usage.output_tokens, 2)
  assert_eq(usage.cache_read_tokens, 4)
  assert_eq(usage.model, Some("gpt-5"))
}

///|
test "codex auto parser returns synthetic all-zero usage like moongate" {
  let body =
    #|{
    #|  "usage": {
    #|    "input_tokens": 0,
    #|    "output_tokens": 0,
    #|    "total_tokens": 0
    #|  }
    #|}
  let usage = token_usage_from_codex_response_auto(parse_json_for_test(body)).unwrap()
  assert_eq(usage.input_tokens, 0)
  assert_eq(usage.output_tokens, 0)
  assert_false(usage.has_billable_tokens())
}

///|
test "codex stream auto falls back to openai usage chunk" {
  let events = [
    parse_json_for_test(
      (
        #|{
        #|  "id": "chatcmpl-1",
        #|  "choices": [],
        #|  "usage": null
        #|}
      ),
    ),
    parse_json_for_test(
      (
        #|{
        #|  "id": "chatcmpl-1",
        #|  "model": "gpt-4o",
        #|  "choices": [],
        #|  "usage": {
        #|    "prompt_tokens": 5,
        #|    "completion_tokens": 3,
        #|    "prompt_tokens_details": { "cached_tokens": 2 }
        #|  }
        #|}
      ),
    ),
  ]
  let usage = token_usage_from_codex_stream_events_auto(events).unwrap()
  assert_eq(usage.input_tokens, 5)
  assert_eq(usage.output_tokens, 3)
  assert_eq(usage.cache_read_tokens, 2)
  assert_eq(usage.model, Some("gpt-4o"))
}

///|
test "gemini stream usage derives output from latest usage chunk" {
  let chunks = [
    parse_json_for_test(
      (
        #|{
        #|  "modelVersion": "gemini-3-pro",
        #|  "candidates": []
        #|}
      ),
    ),
    parse_json_for_test(
      (
        #|{
        #|  "usageMetadata": {
        #|    "promptTokenCount": 20,
        #|    "totalTokenCount": 44,
        #|    "cachedContentTokenCount": 7
        #|  }
        #|}
      ),
    ),
  ]
  let usage = token_usage_from_gemini_stream_chunks(chunks).unwrap()
  assert_eq(usage.input_tokens, 20)
  assert_eq(usage.output_tokens, 24)
  assert_eq(usage.cache_read_tokens, 7)
  assert_eq(usage.model, Some("gemini-3-pro"))
}

///|
test "gemini stream usage skips cache-only chunks like moongate" {
  let chunks = [
    parse_json_for_test(
      (
        #|{
        #|  "modelVersion": "gemini-3-pro",
        #|  "usageMetadata": {
        #|    "promptTokenCount": 0,
        #|    "totalTokenCount": 0,
        #|    "cachedContentTokenCount": 99
        #|  }
        #|}
      ),
    ),
  ]
  assert_true(token_usage_from_gemini_stream_chunks(chunks) is None)
}
