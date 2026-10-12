///|
fn anthropic_result(
  id : String,
  usage : Json,
  stop? : String = "end_turn",
) -> Json {
  {
    "custom_id": id.to_json(),
    "headers": { "x-api-key": "PRIVATE_HEADER" },
    "result": {
      "type": "succeeded",
      "message": {
        "id": "PRIVATE_MESSAGE_ID",
        "type": "message",
        "role": "assistant",
        "model": "fixture-small",
        "stop_reason": stop.to_json(),
        "content": [{ "type": "text", "text": "PRIVATE_BODY" }],
        "created_at": 1234567890,
        "totalCostUsd": 999,
        "usage": usage,
      },
    },
  }
}

///|
fn anthropic_ok(text : String) -> Json raise {
  match @batch_usage.import_anthropic_batch_usage_json(text) {
    Ok(json) => json
    Err(error) => fail(error)
  }
}

///|
fn anthropic_reject(text : String, fragment : String) -> Unit raise {
  match @batch_usage.import_anthropic_batch_usage_json(text) {
    Err(error) => assert_true(error.contains(fragment), msg=error)
    Ok(_) => fail("Invalid Anthropic input accepted")
  }
}

///|
test "Anthropic cache components form input once and reopen with unknown date and cost" {
  let source = anthropic_result(
    "job-2",
    {
      "input_tokens": 10,
      "cache_creation_input_tokens": 20,
      "cache_read_input_tokens": 70,
      "output_tokens": 5,
      "cache_creation": {
        "ephemeral_5m_input_tokens": 5,
        "ephemeral_1h_input_tokens": 15,
      },
      "server_tool_use": { "web_search_requests": 2 },
    },
    stop="tool_use",
  )
  let result = anthropic_ok(source.stringify())
  guard get(result, "data") is [row] else { fail("Expected one row") }
  assert_eq(get(row, "inputTokens"), Json::number(100))
  assert_eq(get(row, "outputTokens"), Json::number(5))
  assert_eq(get(row, "totalTokens"), Json::number(105))
  assert_eq(get(row, "totalCostUsd"), Json::null())
  assert_eq(get(row, "date"), Json::string(""))
  assert_eq(get(row, "requestId"), Json::string("job-2"))
  let meta = get(result, "anthropicBatchImport")
  guard get(meta, "outcomes") is [outcome] else { fail("Expected outcome") }
  assert_eq(get(outcome, "stopReason"), Json::string("tool_use"))
  assert_eq(
    get(get(meta, "completeRowComponents"), "cacheReadInputTokens"),
    Json::number(70),
  )
  assert_eq(get(get(result, "summary"), "tokens"), Json::number(105))
  assert_false(result.stringify().contains("PRIVATE_"))
  let reopened = match
    @usage_preview.moongate_preview_usage_file_json(
      result.stringify(),
      model="fixture-small",
    ) {
    Ok(json) => json
    Err(error) => fail(error)
  }
  assert_eq(get(reopened, "data"), get(result, "data"))
  assert_eq(get(reopened, "summary"), get(result, "summary"))
}

///|
test "Anthropic mixed outcomes preserve coverage order and partial component observations" {
  let lines = [
    anthropic_result("complete", {
      "input_tokens": 1,
      "cache_creation_input_tokens": 0,
      "cache_read_input_tokens": 0,
      "output_tokens": 2,
    }).stringify(),
    "{\"custom_id\":\"error\",\"result\":{\"type\":\"errored\",\"error\":{\"error\":{\"type\":\"PRIVATE_ERROR\",\"message\":\"PRIVATE_DETAIL\"}}}}",
    "{\"custom_id\":\"cancel\",\"result\":{\"type\":\"canceled\"}}",
    "{\"custom_id\":\"expire\",\"result\":{\"type\":\"expired\"}}",
    anthropic_result("missing", Json::null()).stringify(),
    anthropic_result("partial", { "input_tokens": 7, "output_tokens": 8 }).stringify(),
  ]
  let result = anthropic_ok("\n" + lines.join("\r\n") + "\r\n")
  assert_eq(get(result, "sourceTotal"), Json::number(6))
  assert_eq(get(result, "total"), Json::number(1))
  assert_eq(get(result, "partial"), Json::boolean(true))
  assert_eq(get(get(result, "summary"), "tokens"), Json::number(3))
  let meta = get(result, "anthropicBatchImport")
  assert_eq(get(meta, "resultCounts"), {
    "succeeded": 3,
    "errored": 1,
    "canceled": 1,
    "expired": 1,
  })
  assert_eq(get(meta, "missingUsageCount"), Json::number(1))
  assert_eq(get(meta, "incompleteUsageCount"), Json::number(1))
  assert_eq(get(meta, "batchCompleteness"), Json::string("unverified"))
  guard get(meta, "outcomes") is Array(outcomes) else {
    fail("Missing outcomes")
  }
  assert_eq(get(outcomes[0], "line"), Json::number(2))
  assert_eq(get(outcomes[5], "customId"), Json::string("partial"))
  assert_eq(get(outcomes[5], "totalTokens"), Json::null())
  assert_eq(
    get(get(outcomes[5], "components"), "uncachedInputTokens"),
    Json::number(7),
  )
  assert_eq(
    get(get(outcomes[5], "components"), "cacheReadInputTokens"),
    Json::null(),
  )
  assert_false(result.stringify().contains("PRIVATE_"))
  let reopened = match
    @usage_preview.moongate_preview_usage_file_json(
      result.stringify(),
      model="no-match",
    ) {
    Ok(json) => json
    Err(error) => fail(error)
  }
  assert_eq(get(reopened, "sourceTotal"), Json::number(6))
  assert_eq(get(reopened, "total"), Json::number(0))
  assert_eq(get(reopened, "partial"), Json::boolean(true))
}

///|
test "Anthropic numeric observations require exact whole counts including cache categories" {
  let template = anthropic_result("number", {
    "input_tokens": 1,
    "cache_creation_input_tokens": 0,
    "cache_read_input_tokens": 0,
    "output_tokens": 0,
  }).stringify()
  for
    token in [
      "-1", "0.5", "1e-400", "9007199254740990.5", "9007199254740992", "\"1\"", "true",
    ] {
    anthropic_reject(
      template.replace(
        old="\"input_tokens\":1",
        new="\"input_tokens\":" + token,
      ),
      "whole nonnegative",
    )
    anthropic_reject(
      template.replace(
        old="\"cache_read_input_tokens\":0",
        new="\"cache_read_input_tokens\":" + token,
      ),
      "whole nonnegative",
    )
  }
  let exact = anthropic_ok(
    template.replace(old="\"input_tokens\":1", new="\"input_tokens\":1.20e2"),
  )
  assert_eq(get(get(exact, "summary"), "tokens"), Json::number(120))
  let large = template.replace(
    old="\"input_tokens\":1",
    new="\"input_tokens\":9007199254740991",
  )
  anthropic_reject(
    large.replace(old="\"output_tokens\":0", new="\"output_tokens\":1"),
    "Combined token",
  )
  anthropic_reject(
    large + "\n" + template.replace(old="number", new="another"),
    "Aggregate tokens",
  )
}

///|
test "Anthropic missing components remain unknown while explicit zero is an observation" {
  let result = anthropic_ok(
    anthropic_result("zero", {
      "input_tokens": 0,
      "cache_creation_input_tokens": 0,
      "cache_read_input_tokens": 0,
      "output_tokens": 0,
    }).stringify(),
  )
  assert_eq(get(result, "total"), Json::number(1))
  assert_eq(get(get(result, "summary"), "tokens"), Json::number(0))
  let incomplete = anthropic_ok(
    anthropic_result(
      "null",
      {
        "input_tokens": 1,
        "cache_creation_input_tokens": 0,
        "cache_read_input_tokens": Json::null(),
        "output_tokens": 2,
      },
      stop="PRIVATE_UNKNOWN_STOP",
    ).stringify(),
  )
  assert_eq(get(incomplete, "total"), Json::number(0))
  assert_eq(get(incomplete, "partial"), Json::boolean(true))
  assert_false(incomplete.stringify().contains("PRIVATE_"))
  let empty = anthropic_ok("\r\n\n")
  assert_eq(get(empty, "sourceTotal"), Json::number(0))
  assert_eq(get(empty, "total"), Json::number(0))
}

///|
test "Anthropic invalid records fail whole input with line diagnostics and no payload echo" {
  let valid = anthropic_result("id", {
    "input_tokens": 1,
    "cache_creation_input_tokens": 0,
    "cache_read_input_tokens": 0,
    "output_tokens": 0,
  }).stringify()
  anthropic_reject(valid + "\n" + valid, "Line 2: duplicate custom_id")
  anthropic_reject(valid + "\n{PRIVATE_BAD", "Line 2: invalid JSON")
  for
    bad in [
      "[]", "{}", "{\"custom_id\":\"x\",\"result\":{\"type\":\"queued\"}}", "{\"custom_id\":\"x\",\"result\":{\"type\":\"errored\"}}",
    ] {
    anthropic_reject(bad, "Line 1:")
  }
  anthropic_reject(
    valid.replace(old="\"role\":\"assistant\"", new="\"role\":\"user\""),
    "assistant message",
  )
  anthropic_reject(
    valid.replace(old="\"type\":\"succeeded\"", new="\"type\":\"canceled\""),
    "cannot contain a message",
  )
  anthropic_reject("x".repeat(4 * 1024 * 1024 + 1), "4 MiB")
  let rows = Array::makei(10001, i => {
    "{\"custom_id\":\"\{i}\",\"result\":{\"type\":\"expired\"}}"
  })
  anthropic_reject(rows.join("\n"), "10,000")
}
