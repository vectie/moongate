///|
fn request(
  id : String,
  model? : String = "requested-alias",
  endpoint? : String = "/v1/chat/completions",
) -> Json {
  {
    "custom_id": id.to_json(),
    "method": "POST",
    "url": endpoint.to_json(),
    "body": {
      "model": model.to_json(),
      "messages": [
        { "role": "user", "content": "REQUEST_PRIVATE_MARKER\n你好" },
      ],
      "metadata": { "secret": "REQUEST_METADATA_PRIVATE_MARKER" },
    },
    "headers": { "Authorization": "HEADER_PRIVATE_MARKER" },
  }
}

///|
fn joined_ok(results : String, requests : String) -> Json raise {
  match @batch_usage.import_batch_usage_json(results, requests~) {
    Ok(json) => json
    Err(error) => fail(error)
  }
}

///|
fn joined_rejected(
  results : String,
  requests : String,
  fragment : String,
) -> Unit raise {
  match @batch_usage.import_batch_usage_json(results, requests~) {
    Err(error) => {
      assert_true(error.contains(fragment), msg=error)
      assert_false(error.contains("PRIVATE_MARKER"))
    }
    Ok(_) => fail("Invalid request join accepted")
  }
}

///|
test "Request join uses exact IDs with shuffled mixed results and request order" {
  let results = [
      chat_result("b", { "prompt_tokens": 4, "completion_tokens": 1 }),
      { "custom_id": "a", "error": { "message": "ERROR_PRIVATE_MARKER" } },
      chat_result("extra", { "prompt_tokens": 10, "completion_tokens": 2 }),
    ]
    .map(value => value.stringify())
    .join("\n")
  let requests = [request("a"), request("missing"), request("b")]
    .map(value => value.stringify())
    .join("\r\n\r\n")
  let result = joined_ok(results, requests)
  let join = get(get(result, "batchImport"), "requestJoin")
  assert_eq(get(join, "requestCount"), Json::number(3))
  assert_eq(get(join, "matchedResultCount"), Json::number(2))
  assert_eq(get(join, "missingResultCount"), Json::number(1))
  assert_eq(get(join, "unexpectedResultCount"), Json::number(1))
  assert_eq(get(join, "requestIdCoverage"), Json::string("missing-results"))
  assert_eq(get(result, "sourceTotal"), Json::number(4))
  assert_eq(get(result, "partial"), Json::boolean(true))
  assert_eq(get(get(result, "summary"), "tokens"), Json::number(17))
  guard get(join, "outcomes") is [a, missing, b, extra] else {
    fail("Expected joined outcomes")
  }
  assert_eq(get(a, "customId"), Json::string("a"))
  assert_eq(get(a, "outcome"), Json::string("batch_error"))
  assert_eq(get(a, "resultLine"), Json::number(2))
  assert_eq(get(missing, "outcome"), Json::string("missing_result"))
  assert_eq(get(missing, "resultLine"), Json::null())
  assert_eq(get(b, "resultLine"), Json::number(1))
  assert_eq(get(b, "requestLine"), Json::number(5))
  assert_eq(get(extra, "match"), Json::string("unexpected_result"))
  assert_eq(get(extra, "requestedModel"), Json::null())
  assert_false(result.stringify().contains("PRIVATE_MARKER"))
}

///|
test "Absent all results yields missing requests with no fabricated usage and reopens" {
  let result = joined_ok(
    "\r\n",
    request("one").stringify() + "\n" + request("two").stringify(),
  )
  let join = get(get(result, "batchImport"), "requestJoin")
  assert_eq(get(join, "missingResultCount"), Json::number(2))
  assert_eq(get(result, "sourceTotal"), Json::number(2))
  assert_eq(get(result, "data"), Json::array([]))
  assert_eq(get(result, "partial"), Json::boolean(true))
  let reopened = match
    @usage_preview.moongate_preview_usage_file_json(result.stringify()) {
    Ok(json) => json
    Err(error) => fail(error)
  }
  assert_eq(get(reopened, "sourceTotal"), Json::number(2))
  assert_eq(get(reopened, "partial"), Json::boolean(true))
}

///|
test "All observed includes missing usage and does not claim successful completion" {
  let result = joined_ok(
    chat_result("x", Json::null()).stringify(),
    request("x").stringify(),
  )
  let batch = get(result, "batchImport")
  assert_eq(get(batch, "batchCompleteness"), Json::string("unverified"))
  let join = get(batch, "requestJoin")
  assert_eq(get(join, "requestIdCoverage"), Json::string("all-observed"))
  assert_eq(get(result, "partial"), Json::boolean(true))
  guard get(join, "outcomes") is [row] else { fail("Expected row") }
  assert_eq(get(row, "outcome"), Json::string("missing_usage"))
  assert_eq(get(row, "responseModel"), Json::string("moon-small"))
}

///|
test "Requested and returned model and endpoint context remain separate with Unicode" {
  let result = joined_ok(
    chat_result("任务\nα", { "prompt_tokens": 2, "completion_tokens": 1 }).stringify(),
    request("任务\nα", model="请求模型\nβ", endpoint="/v1/responses").stringify(),
  )
  let join = get(get(result, "batchImport"), "requestJoin")
  guard get(join, "outcomes") is [row] else { fail("Expected row") }
  assert_eq(get(row, "requestedModel"), Json::string("请求模型\nβ"))
  assert_eq(get(row, "responseModel"), Json::string("moon-small"))
  assert_eq(get(row, "requestEndpoint"), Json::string("/v1/responses"))
  assert_eq(get(row, "responseObject"), Json::string("chat.completion"))
  assert_false(result.stringify().contains("PRIVATE_MARKER"))
}

///|
test "Empty manifests and exact whitespace-sensitive identities do not invent matches" {
  let results = chat_result("x", { "prompt_tokens": 1, "completion_tokens": 0 }).stringify()
  let empty = get(get(joined_ok(results, ""), "batchImport"), "requestJoin")
  assert_eq(get(empty, "requestCount"), Json::number(0))
  assert_eq(get(empty, "unexpectedResultCount"), Json::number(1))
  let distinct = get(
    get(joined_ok(results, request(" x ").stringify()), "batchImport"),
    "requestJoin",
  )
  assert_eq(get(distinct, "missingResultCount"), Json::number(1))
  assert_eq(get(distinct, "unexpectedResultCount"), Json::number(1))
}

///|
test "Duplicate request and result identities reject the entire join" {
  let manifest = request("x").stringify()
  joined_rejected(
    "",
    manifest + "\n" + manifest,
    "Request line 2: duplicate custom_id",
  )
  let results = chat_result("x", Json::null()).stringify()
  joined_rejected(
    results + "\n" + results,
    manifest,
    "Line 2: duplicate custom_id",
  )
}

///|
test "Malformed unsupported and incomplete requests fail without source content" {
  for
    text in [
      "{PRIVATE_MARKER", "[]", "{}", "{\"custom_id\":\"PRIVATE_MARKER\",\"method\":\"GET\",\"url\":\"/v1/chat/completions\"}",
      "{\"custom_id\":\"x\",\"method\":\"POST\",\"url\":\"/v1/embeddings\",\"body\":{\"model\":\"m\"}}",
      "{\"custom_id\":\"x\",\"method\":\"POST\",\"url\":\"/v1/responses\",\"body\":{\"model\":\" \"}}",
    ] {
    joined_rejected("", "\n" + text, "Request line 2:")
  }
}

///|
test "Combined input bytes and request count remain bounded" {
  joined_rejected(" ", " ".repeat(4 * 1024 * 1024), "combined 4 MiB")
  let requests = Array::makei(10001, i => request(i.to_string()).stringify()).join(
    "\n",
  )
  joined_rejected("", requests, "10,000")
}
