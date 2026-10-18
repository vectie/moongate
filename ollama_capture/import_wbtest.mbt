///|
fn field(value : Json, key : String) -> Json {
  guard value is Object(fields) else { abort("expected object") }
  fields.get(key).unwrap_or(Json::null())
}

///|
fn array(value : Json) -> Array[Json] {
  guard value is Array(values) else { abort("expected array") }
  values
}

///|
fn read(captures : Array[(String, String)]) -> Json raise {
  match import_ollama_captures_json(captures) {
    Ok(value) => value
    Err(error) => fail(error)
  }
}

///|
fn outcome(result : Json, index : Int32) -> Json {
  array(field(field(result, "ollamaCaptureImport"), "outcomes"))[index]
}

///|
fn completed(input : Json, output : Json) -> String {
  (
    {
      "model": "moon-local",
      "response": "PRIVATE_OUTPUT",
      "done": true,
      "prompt_eval_count": input,
      "eval_count": output,
    } : Json).stringify()
}

///|
test "stream chunks collapse into one observed terminal usage row" {
  let source = "\n" +
    (
      {
        "model": "moon-local",
        "response": "PRIVATE_CHUNK",
        "done": false,
        "prompt_eval_count": 999,
      } : Json).stringify() +
    "\r\n" +
    (
      {
        "model": "moon-local",
        "response": "PRIVATE_TERMINAL",
        "done": true,
        "done_reason": "stop",
        "created_at": "2026-10-10T00:30:00+02:00",
        "prompt_eval_count": 10,
        "eval_count": 4,
        "prompt_eval_cached_count": 7,
        "total_duration": 2000000000,
        "load_duration": 500000000,
        "prompt_eval_duration": 100000000,
        "eval_duration": 1400000000,
        "context": [123, 456],
        "thinking": "PRIVATE_THINKING",
      } : Json).stringify() +
    "\r\n"
  let result = read([("stream.ndjson", source)])
  assert_eq(field(result, "total"), Json(1))
  assert_eq(field(field(result, "summary"), "tokens"), Json(14))
  assert_eq(field(field(result, "summary"), "missingCostCount"), Json(1))
  let row = array(field(result, "data"))[0]
  assert_eq(field(row, "inputTokens"), Json(10))
  assert_eq(field(row, "date"), Json("2026-10-09"))
  assert_eq(field(row, "captureIndex"), Json(1))
  assert_eq(field(row, "requestId"), Json(""))
  let evidence = outcome(result, 0)
  assert_eq(field(evidence, "terminalLine"), Json(3))
  assert_eq(field(evidence, "responseObjectCount"), Json(2))
  assert_eq(field(evidence, "usageState"), Json("complete"))
  assert_eq(
    field(field(evidence, "terminalMetrics"), "total_duration"),
    Json(2000000000),
  )
  assert_eq(
    field(field(evidence, "terminalMetrics"), "prompt_eval_cached_count"),
    Json(7),
  )
  assert_true(!result.stringify().contains("PRIVATE_"))
}

///|
test "pretty chat captures and explicit zero are supported" {
  let source : Json = {
    "model": "moon-chat",
    "message": {
      "role": "assistant",
      "content": "SECRET_CHAT",
      "tool_calls": [{ "secret": "SECRET_TOOL" }],
    },
    "done": true,
    "prompt_eval_count": 0,
    "eval_count": 0,
    "totalCostUsd": 12,
    "created_at": "unparseable",
  }
  let result = read([("chat.json", source.stringify(indent=2))])
  assert_eq(field(outcome(result, 0), "apiShape"), Json("chat"))
  assert_eq(field(outcome(result, 0), "terminalLine"), Json(1))
  assert_eq(field(field(result, "summary"), "tokens"), Json(0))
  assert_eq(field(field(result, "summary"), "undatedCount"), Json(1))
  assert_eq(
    field(array(field(result, "data"))[0], "totalCostUsd"),
    Json::null(),
  )
  assert_true(!result.stringify().contains("SECRET_"))
}

///|
test "empty interrupted errored missing and incomplete usage stay distinct" {
  let result = read([
    ("empty", " \r\n"),
    (
      "interrupted",
      (
        {
          "model": "m",
          "response": "partial",
          "done": false,
          "prompt_eval_count": 8,
          "eval_count": 9,
        } : Json).stringify(),
    ),
    ("error", ({ "error": "SECRET_ERROR" } : Json).stringify()),
    ("missing", completed(Json::null(), Json::null())),
    ("partial", completed(Json(7), Json::null())),
    ("zero", completed(Json(0), Json(0))),
  ])
  assert_eq(field(result, "sourceTotal"), Json(6))
  assert_eq(field(result, "total"), Json(1))
  assert_eq(field(result, "partial"), Json(true))
  assert_eq(field(outcome(result, 0), "state"), Json("empty"))
  assert_eq(field(outcome(result, 1), "state"), Json("incomplete"))
  assert_eq(field(outcome(result, 1), "usageState"), Json("unavailable"))
  assert_eq(
    field(outcome(result, 1), "terminalMetrics"),
    Json(({} : Map[String, Json])),
  )
  assert_eq(field(outcome(result, 2), "state"), Json("errored"))
  assert_eq(field(outcome(result, 3), "usageState"), Json("missing"))
  assert_eq(field(outcome(result, 4), "usageState"), Json("incomplete"))
  assert_eq(
    field(field(outcome(result, 4), "terminalMetrics"), "prompt_eval_count"),
    Json(7),
  )
  assert_eq(field(array(field(result, "data"))[0], "captureIndex"), Json(6))
  assert_true(!result.stringify().contains("SECRET_ERROR"))
}

///|
test "post-terminal data and concatenated requests reject whole import" {
  let done = completed(Json(1), Json(2))
  let error = ({ "error": "bad" } : Json).stringify()
  for source in [done + "\n" + done, error + "\n" + done, done + "\n" + error] {
    assert_true(import_ollama_captures_json([("one", source)]) is Err(_))
  }
}

///|
test "stream model and API shape cannot change" {
  let first = ({ "model": "m", "response": "a", "done": false } : Json).stringify()
  for
    tail in [
      ({ "model": "other", "response": "", "done": true } : Json).stringify(),
      ({ "model": "m", "message": {}, "done": true } : Json).stringify(),
    ] {
    assert_true(
      import_ollama_captures_json([("one", first + "\n" + tail)]) is Err(_),
    )
  }
}

///|
test "invalid supported fields reject with no partial artifact" {
  for
    value in [
      ({ "model": "m", "response": "", "done": "true" } : Json),
      (
        { "model": "m", "response": "", "done": true, "prompt_eval_count": "1" } :
        Json),
      (
        { "model": "m", "response": "", "done": true, "total_duration": -1 } :
        Json),
      ({ "model": "m", "response": "", "done": true, "created_at": 123 } : Json),
      (
        { "model": "m", "response": "", "done": true, "done_reason": false } :
        Json),
      (
        {
          "model": "m",
          "response": "",
          "done": true,
          "prompt_eval_count": 1,
          "prompt_eval_cached_count": 2,
        } : Json),
      ({ "model": "m", "response": "", "message": {}, "done": true } : Json),
      ({ "model": "m", "done": true } : Json),
      ({ "error": {} } : Json),
    ] {
    assert_true(
      import_ollama_captures_json([("one", value.stringify())]) is Err(_),
    )
  }
}

///|
test "exact decimal metrics reject rounded fractions and underflow" {
  for
    number in [
      "1e-400", "9007199254740990.5", "0.0000000000000000001", "-1", "9007199254740992",
    ] {
    let source = "{\"model\":\"m\",\"response\":\"\",\"done\":true,\"prompt_eval_count\":\{number},\"eval_count\":0}"
    assert_true(import_ollama_captures_json([("one", source)]) is Err(_))
  }
  let result = read([
    (
      "one", "{\"model\":\"m\",\"response\":\"\",\"done\":true,\"prompt_eval_count\":1.20e2,\"eval_count\":0}",
    ),
  ])
  assert_eq(field(field(result, "summary"), "tokens"), Json(120))
}

///|
test "row and aggregate token sums remain exact safe integers" {
  assert_true(
    import_ollama_captures_json([
      ("one", completed(Json(9007199254740991.0), Json(1))),
    ])
    is Err(_),
  )
  assert_true(
    import_ollama_captures_json([
      ("one", completed(Json(9007199254740991.0), Json(0))),
      ("two", completed(Json(1), Json(0))),
    ])
    is Err(_),
  )
}

///|
test "unknown stop reasons do not echo arbitrary content" {
  let value : Json = {
    "model": "m",
    "response": "",
    "done": true,
    "done_reason": "SECRET_STOP",
  }
  let result = read([("one", value.stringify())])
  assert_eq(field(outcome(result, 0), "doneReason"), Json("unrecognized"))
  assert_true(!result.stringify().contains("SECRET_STOP"))
}

///|
test "reopen export keeps unknown coverage and exact filters" {
  let result = read([("one", completed(Json(2), Json(3)))])
  let reopen = match
    @usage_preview.moongate_preview_usage_file_json(
      result.stringify(),
      model="moon-local",
    ) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  assert_eq(field(reopen, "sourceCoverageUnknown"), Json(true))
  assert_eq(field(reopen, "total"), Json(1))
  assert_eq(field(field(reopen, "summary"), "tokens"), Json(5))
  let no_match = match
    @usage_preview.moongate_preview_usage_file_json(
      result.stringify(),
      model="other",
    ) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  assert_eq(field(no_match, "total"), Json(0))
  assert_eq(field(no_match, "sourceTotal"), Json(1))
}

///|
test "capture limits names malformed input and JSON arrays reject" {
  for
    captures in [
      [],
      [("", " ")],
      [("a", " "), ("a", " ")],
      [("a", "[]")],
      [("a", "{bad")],
      [("a", "{\"error\":\"x\"}\nnull")],
    ] {
    assert_true(import_ollama_captures_json(captures) is Err(_))
  }
  assert_true(
    import_ollama_captures_json(Array::makei(101, i => (i.to_string(), " ")))
    is Err(_),
  )
  assert_true(
    import_ollama_captures_json([("a", " ".repeat(4 * 1024 * 1024 + 1))])
    is Err(_),
  )
  let chunk = ({ "model": "m", "response": "", "done": false } : Json).stringify() +
    "\n"
  assert_true(
    import_ollama_captures_json([("a", chunk.repeat(10001))]) is Err(_),
  )
  assert_true(
    import_ollama_captures_json([
      ("a", chunk.repeat(6000)),
      ("b", chunk.repeat(4001)),
    ])
    is Err(_),
  )
}

///|
test "error after streamed output remains one errored capture" {
  let source = (
      { "model": "m", "response": "SECRET_PARTIAL", "done": false } : Json).stringify() +
    "\n" +
    ({ "error": "SECRET_UPSTREAM" } : Json).stringify()
  let result = read([("a", source)])
  assert_eq(field(outcome(result, 0), "state"), Json("errored"))
  assert_eq(field(outcome(result, 0), "terminalLine"), Json(2))
  assert_eq(field(result, "total"), Json(0))
  assert_true(!result.stringify().contains("SECRET_"))
}

///|
test "single terminal capture preserves leading blank line position" {
  let result = read([("a", " \n\n" + completed(Json(1), Json(2)))])
  assert_eq(field(outcome(result, 0), "terminalLine"), Json(3))
}
