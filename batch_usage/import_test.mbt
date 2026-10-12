///|
fn get(value : Json, key : String) -> Json raise {
  guard value is Object(obj) && obj.get(key) is Some(value) else {
    fail("Missing field: \{key}")
  }
  value
}

///|
fn chat_result(id : String, usage : Json) -> Json {
  {
    "custom_id": id.to_json(),
    "totalCostUsd": 42,
    "response": {
      "status_code": 200,
      "body": {
        "object": "chat.completion",
        "model": "moon-small",
        "created": 1711652795,
        "choices": [{ "message": { "content": "PRIVATE_PAYLOAD_MARKER" } }],
        "usage": usage,
      },
    },
    "error": Json::null(),
  }
}

///|
fn import_ok(text : String) -> Json raise {
  match @batch_usage.import_batch_usage_json(text) {
    Ok(json) => json
    Err(error) => fail(error)
  }
}

///|
fn assert_rejected(text : String, fragment : String) -> Unit raise {
  match @batch_usage.import_batch_usage_json(text) {
    Err(error) => assert_true(error.contains(fragment), msg=error)
    Ok(_) => fail("Invalid Batch result accepted")
  }
}

///|
test "Chat Completions usage imports with explicit labels and no payload or costs" {
  let source = chat_result("job-2", {
    "prompt_tokens": 20,
    "completion_tokens": 5,
    "total_tokens": 25,
  })
  let result = match
    @batch_usage.import_batch_usage_json(
      source.stringify(),
      app="evaluation",
      provider="team-export",
    ) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  assert_eq(get(get(result, "summary"), "tokens"), Json::number(25))
  assert_eq(get(get(result, "summary"), "missingCostCount"), Json::number(1))
  assert_eq(get(result, "partial"), Json::boolean(false))
  guard get(result, "data") is [row] else { fail("Expected one row") }
  assert_eq(get(row, "requestId"), Json::string("job-2"))
  assert_eq(get(row, "date"), Json::string("2024-03-28"))
  assert_eq(get(row, "appType"), Json::string("evaluation"))
  assert_eq(get(row, "providerId"), Json::string("team-export"))
  assert_eq(get(row, "totalCostUsd"), Json::null())
  assert_false(result.stringify().contains("PRIVATE_PAYLOAD_MARKER"))
}

///|
test "Responses incomplete output retains reported usage without claiming completion" {
  let source : Json = {
    "custom_id": "response-1",
    "response": {
      "status_code": 200,
      "body": {
        "object": "response",
        "model": "moon-reason",
        "status": "incomplete",
        "created_at": 1711652795,
        "output": [{ "content": "PRIVATE_RESPONSE_MARKER" }],
        "usage": {
          "input_tokens": 100,
          "output_tokens": 30,
          "total_tokens": 130,
          "output_tokens_details": { "reasoning_tokens": 25 },
        },
      },
    },
    "error": Json::null(),
  }
  let result = import_ok(source.stringify())
  assert_eq(get(get(result, "summary"), "tokens"), Json::number(130))
  assert_eq(
    get(get(result, "batchImport"), "nonCompletedResponseCount"),
    Json::number(1),
  )
  guard get(get(result, "batchImport"), "outcomes") is [outcome] else {
    fail("Expected one outcome")
  }
  assert_eq(get(outcome, "responseState"), Json::string("incomplete"))
  assert_eq(get(outcome, "outcome"), Json::string("imported"))
  assert_false(result.stringify().contains("PRIVATE_RESPONSE_MARKER"))
}

///|
test "Batch errors HTTP errors and absent usage remain explicit and partial" {
  let source = [
      chat_result("known", { "prompt_tokens": 2, "completion_tokens": 3 }),
      chat_result("missing", Json::null()),
      {
        "custom_id": "expired",
        "response": Json::null(),
        "error": { "code": "batch_expired", "message": "PRIVATE_ERROR_MARKER" },
      },
      {
        "custom_id": "http-failed",
        "response": {
          "status_code": 429,
          "body": { "error": "PRIVATE_HTTP_MARKER" },
        },
        "error": Json::null(),
      },
    ]
    .map(value => value.stringify())
    .join("\n")
  let result = import_ok(source)
  let meta = get(result, "batchImport")
  assert_eq(get(result, "sourceTotal"), Json::number(4))
  assert_eq(get(result, "total"), Json::number(1))
  assert_eq(get(result, "partial"), Json::boolean(true))
  assert_eq(get(meta, "batchErrorCount"), Json::number(1))
  assert_eq(get(meta, "httpErrorCount"), Json::number(1))
  assert_eq(get(meta, "missingUsageCount"), Json::number(1))
  assert_eq(get(meta, "batchCompleteness"), Json::string("unverified"))
  assert_eq(get(get(result, "summary"), "tokens"), Json::number(5))
  assert_false(result.stringify().contains("PRIVATE_"))
}

///|
test "Normalized Batch JSON reopens and compares with honest unknown costs and coverage" {
  let result = import_ok(
    [
      chat_result("a", { "prompt_tokens": 2, "completion_tokens": 3 }),
      chat_result("b", Json::null()),
    ]
    .map(value => value.stringify())
    .join("\n"),
  )
  let reopened = match
    @usage_preview.moongate_preview_usage_file_json(
      result.stringify(),
      model="moon-small",
    ) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  assert_eq(get(reopened, "data"), get(result, "data"))
  assert_eq(get(reopened, "summary"), get(result, "summary"))
  assert_eq(get(reopened, "sourceTotal"), Json::number(2))
  assert_eq(get(reopened, "partial"), Json::boolean(true))
  let comparison = match
    @usage_preview.compare_usage_files_json(
      result.stringify(),
      reopened.stringify(),
    ) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  let summary = get(comparison, "summary")
  assert_eq(get(get(summary, "delta"), "tokens"), Json::number(0))
  assert_eq(get(summary, "estimatedUsdDelta"), Json::null())
}

///|
test "Empty and errors-only files are usable without invented usage" {
  let empty = import_ok("\n\r\n ")
  assert_eq(get(empty, "total"), Json::number(0))
  assert_eq(
    get(get(empty, "batchImport"), "sourceResultCount"),
    Json::number(0),
  )
  let result = import_ok(
    "{\"custom_id\":\"failed\",\"response\":null,\"error\":{\"code\":\"batch_expired\"}}",
  )
  assert_eq(get(result, "data"), Json::array([]))
  assert_eq(get(result, "sourceTotal"), Json::number(1))
  assert_eq(get(result, "partial"), Json::boolean(true))
}

///|
test "Unordered custom IDs are preserved and repeated IDs reject rather than charge twice" {
  let line = chat_result("b", { "prompt_tokens": 0, "completion_tokens": 0 }).stringify()
  let other = chat_result("a", { "prompt_tokens": 1, "completion_tokens": 0 }).stringify()
  let result = import_ok(line + "\r\n\r\n" + other + "\n")
  guard get(result, "data") is [first, second] else {
    fail("Expected two rows")
  }
  assert_eq(get(first, "requestId"), Json::string("b"))
  assert_eq(get(second, "requestId"), Json::string("a"))
  assert_rejected(line + "\n" + line, "duplicate custom_id")
}

///|
test "Malformed JSON input requests unsupported shapes and ambiguous outcomes fail closed" {
  for
    text in [
      "{", "[]", "{\"custom_id\":\"x\",\"body\":{}}", "{\"response\":null,\"error\":{}}",
      "{\"custom_id\":\"x\",\"response\":{},\"error\":{}}", "{\"custom_id\":\"x\",\"response\":{\"status_code\":200,\"body\":{\"object\":\"list\"}}}",
    ] {
    assert_rejected(text, "Line 1:")
  }
  assert_rejected("\n{\n", "Line 2:")
}

///|
test "Bad HTTP status missing model and unknown Responses states reject the result" {
  let bodies : Array[Json] = [
    { "object": "chat.completion", "usage": Json::null() },
    {
      "object": "response",
      "model": "m",
      "status": "future-state",
      "usage": Json::null(),
    },
    { "object": "response", "model": "m", "usage": Json::null() },
    { "object": "chat.completion", "model": "m", "usage": [] },
  ]
  for body in bodies {
    let record : Json = {
      "custom_id": "x",
      "response": { "status_code": 200, "body": body },
    }
    assert_rejected(record.stringify(), "Line 1:")
  }
  for status in [0.0, 99.0, 200.5, 600.0] {
    let record : Json = {
      "custom_id": "x",
      "response": { "status_code": status.to_json() },
    }
    assert_rejected(record.stringify(), "HTTP status")
  }
}

///|
test "Invalid tokens incomplete usage and inconsistent totals are rejected" {
  let cases : Array[Json] = [
    { "prompt_tokens": -1, "completion_tokens": 0 },
    { "prompt_tokens": 1.5, "completion_tokens": 0 },
    { "prompt_tokens": "1", "completion_tokens": 0 },
    { "prompt_tokens": 1 },
    { "total_tokens": 3 },
    { "prompt_tokens": 1, "completion_tokens": 2, "total_tokens": 4 },
    { "prompt_tokens": 9007199254740991, "completion_tokens": 1 },
  ]
  for usage in cases {
    assert_rejected(chat_result("x", usage).stringify(), "Line 1:")
  }
  let maximum = chat_result("x", {
    "prompt_tokens": 9007199254740991,
    "completion_tokens": 0,
  }).stringify()
  assert_eq(
    get(get(import_ok(maximum), "summary"), "tokens"),
    Json::number(9007199254740991),
  )
  assert_rejected(
    maximum +
    "\n" +
    chat_result("y", { "prompt_tokens": 1, "completion_tokens": 0 }).stringify(),
    "aggregate tokens",
  )
}

///|
test "Content and row limits reject all results" {
  assert_rejected("x".repeat(4 * 1024 * 1024 + 1), "4 MiB")
  let rows = Array::makei(10001, i => {
    "{\"custom_id\":\"\{i}\",\"response\":null,\"error\":{}}"
  })
  assert_rejected(rows.join("\n"), "10,000")
  match @batch_usage.import_batch_usage_json("", app=" ") {
    Err(error) => assert_true(error.contains("labels"))
    Ok(_) => fail("Blank app accepted")
  }
}
