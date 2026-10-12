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
fn outcome(result : Json, index : Int) -> Json {
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
  assert_eq(field(result, "total"), (1).to_json())
  assert_eq(field(field(result, "summary"), "tokens"), (14).to_json())
  assert_eq(field(field(result, "summary"), "missingCostCount"), (1).to_json())
  let row = array(field(result, "data"))[0]
  assert_eq(field(row, "inputTokens"), (10).to_json())
  assert_eq(field(row, "date"), "2026-10-09".to_json())
  assert_eq(field(row, "captureIndex"), (1).to_json())
  assert_eq(field(row, "requestId"), "".to_json())
  let evidence = outcome(result, 0)
  assert_eq(field(evidence, "terminalLine"), (3).to_json())
  assert_eq(field(evidence, "responseObjectCount"), (2).to_json())
  assert_eq(field(evidence, "usageState"), "complete".to_json())
  assert_eq(
    field(field(evidence, "terminalMetrics"), "total_duration"),
    (2000000000).to_json(),
  )
  assert_eq(
    field(field(evidence, "terminalMetrics"), "prompt_eval_cached_count"),
    (7).to_json(),
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
  assert_eq(field(outcome(result, 0), "apiShape"), "chat".to_json())
  assert_eq(field(outcome(result, 0), "terminalLine"), (1).to_json())
  assert_eq(field(field(result, "summary"), "tokens"), (0).to_json())
  assert_eq(field(field(result, "summary"), "undatedCount"), (1).to_json())
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
    ("partial", completed((7).to_json(), Json::null())),
    ("zero", completed((0).to_json(), (0).to_json())),
  ])
  assert_eq(field(result, "sourceTotal"), (6).to_json())
  assert_eq(field(result, "total"), (1).to_json())
  assert_eq(field(result, "partial"), true.to_json())
  assert_eq(field(outcome(result, 0), "state"), "empty".to_json())
  assert_eq(field(outcome(result, 1), "state"), "incomplete".to_json())
  assert_eq(field(outcome(result, 1), "usageState"), "unavailable".to_json())
  assert_eq(
    field(outcome(result, 1), "terminalMetrics"),
    ({} : Map[String, Json]).to_json(),
  )
  assert_eq(field(outcome(result, 2), "state"), "errored".to_json())
  assert_eq(field(outcome(result, 3), "usageState"), "missing".to_json())
  assert_eq(field(outcome(result, 4), "usageState"), "incomplete".to_json())
  assert_eq(
    field(field(outcome(result, 4), "terminalMetrics"), "prompt_eval_count"),
    (7).to_json(),
  )
  assert_eq(
    field(array(field(result, "data"))[0], "captureIndex"),
    (6).to_json(),
  )
  assert_true(!result.stringify().contains("SECRET_ERROR"))
}

///|
test "post-terminal data and concatenated requests reject whole import" {
  let done = completed((1).to_json(), (2).to_json())
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
  assert_eq(field(field(result, "summary"), "tokens"), (120).to_json())
}

///|
test "row and aggregate token sums remain exact safe integers" {
  assert_true(
    import_ollama_captures_json([
      ("one", completed(9007199254740991.0.to_json(), (1).to_json())),
    ])
    is Err(_),
  )
  assert_true(
    import_ollama_captures_json([
      ("one", completed(9007199254740991.0.to_json(), (0).to_json())),
      ("two", completed((1).to_json(), (0).to_json())),
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
  assert_eq(field(outcome(result, 0), "doneReason"), "unrecognized".to_json())
  assert_true(!result.stringify().contains("SECRET_STOP"))
}

///|
test "reopen export keeps unknown coverage and exact filters" {
  let result = read([("one", completed((2).to_json(), (3).to_json()))])
  let reopen = match
    @usage_preview.moongate_preview_usage_file_json(
      result.stringify(),
      model="moon-local",
    ) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  assert_eq(field(reopen, "sourceCoverageUnknown"), true.to_json())
  assert_eq(field(reopen, "total"), (1).to_json())
  assert_eq(field(field(reopen, "summary"), "tokens"), (5).to_json())
  let no_match = match
    @usage_preview.moongate_preview_usage_file_json(
      result.stringify(),
      model="other",
    ) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  assert_eq(field(no_match, "total"), (0).to_json())
  assert_eq(field(no_match, "sourceTotal"), (1).to_json())
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
  assert_eq(field(outcome(result, 0), "state"), "errored".to_json())
  assert_eq(field(outcome(result, 0), "terminalLine"), (2).to_json())
  assert_eq(field(result, "total"), (0).to_json())
  assert_true(!result.stringify().contains("SECRET_"))
}

///|
test "single terminal capture preserves leading blank line position" {
  let result = read([("a", " \n\n" + completed((1).to_json(), (2).to_json()))])
  assert_eq(field(outcome(result, 0), "terminalLine"), (3).to_json())
}
