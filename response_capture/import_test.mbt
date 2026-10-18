///|
fn field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn imported(captures : Array[(String, String)]) -> Json raise {
  match @response_capture.import_response_captures_json(captures) {
    Ok(result) => result
    Err(error) => fail(error)
  }
}

///|
fn response(id : String, status : String, usage : String) -> String {
  "{\"object\":\"response\",\"id\":\"" +
  id +
  "\",\"model\":\"fixture-model\",\"status\":\"" +
  status +
  "\",\"created_at\":1791504000,\"output\":[{\"text\":\"PRIVATE_OUTPUT\"}],\"instructions\":\"PRIVATE_PROMPT\",\"error\":{\"message\":\"PRIVATE_ERROR\"},\"usage\":" +
  usage +
  "}"
}

///|
fn event(kind : String, body : String) -> String {
  "event: " +
  kind +
  "\ndata: {\"type\":\"" +
  kind +
  "\",\"response\":" +
  body +
  "}\n\n"
}

///|
fn outcomes(result : Json) -> Array[Json] raise {
  guard field(field(result, "responseCaptureImport"), "outcomes")
    is Array(values) else {
    fail("outcomes")
  }
  values
}

///|
test "JSON and framed HTTP SSE yield standard usage artifacts and reopen" {
  let result = imported([
    (
      "one.json",
      response(
        "resp-1", "completed", "{\"input_tokens\":3,\"output_tokens\":2,\"total_tokens\":5,\"input_tokens_details\":{\"cached_tokens\":3},\"output_tokens_details\":{\"reasoning_tokens\":2}}",
      ),
    ),
    (
      "two.sse",
      event("response.created", response("resp-2", "in_progress", "null")) +
      "data: {\"type\":\"response.output_text.delta\",\"delta\":\"PRIVATE_DELTA\"}\n\n" +
      event(
        "response.completed",
        response(
          "resp-2", "completed", "{\"input_tokens\":10,\"output_tokens\":2,\"total_tokens\":12}",
        ),
      ),
    ),
  ])
  assert_eq(field(result, "schema"), Json("moongate.usage-file.v1"))
  assert_eq(field(field(result, "summary"), "tokens"), Json(17))
  assert_eq(field(field(result, "summary"), "missingCostCount"), Json(2))
  assert_eq(field(result, "sourceCoverageUnknown"), Json(true))
  guard field(result, "data") is Array(rows) else { fail("rows") }
  assert_eq(rows.length(), 2)
  assert_eq(field(rows[0], "requestId"), Json("resp-1"))
  assert_eq(field(rows[0], "captureIndex"), Json(1))
  assert_eq(field(rows[0], "date"), Json("2026-10-09"))
  assert_eq(field(rows[0], "totalCostUsd"), Json::null())
  assert_false(result.stringify().contains("PRIVATE_"))
  assert_false(result.stringify().contains("cached_tokens"))
  assert_false(result.stringify().contains("reasoning_tokens"))
  guard @usage_preview.moongate_preview_usage_file_json(
      result.stringify(),
      model="fixture-model",
      start_day="2026-10-09",
      end_day="2026-10-09",
    )
    is Ok(reopened) else {
    fail("reopen")
  }
  assert_eq(field(reopened, "total"), Json(2))
  assert_eq(field(field(reopened, "summary"), "tokens"), Json(17))
}

///|
test "terminal incomplete failed and cancelled consumption is separate from answer outcome" {
  let usage = "{\"input_tokens\":3,\"output_tokens\":2,\"total_tokens\":5}"
  let result = imported([
    (
      "incomplete",
      event(
        "response.incomplete",
        response("i", "incomplete", usage).replace(
          old="\"output\":",
          new="\"incomplete_details\":{\"reason\":\"max_output_tokens\"},\"output\":",
        ),
      ),
    ),
    ("failed", event("response.failed", response("f", "failed", usage))),
    ("cancelled", response("c", "cancelled", usage)),
  ])
  assert_eq(field(result, "total"), Json(3))
  assert_eq(field(field(result, "summary"), "tokens"), Json(15))
  let values = outcomes(result)
  assert_eq(field(values[0], "state"), Json("incomplete"))
  assert_eq(field(values[0], "terminal"), Json(true))
  assert_eq(field(values[0], "incompleteReason"), Json("max_output_tokens"))
  assert_eq(field(values[1], "state"), Json("failed"))
  assert_eq(field(values[2], "state"), Json("cancelled"))
}

///|
test "unknown interrupted missing partial zero and empty remain distinct" {
  let usage = "{\"input_tokens\":1,\"output_tokens\":2,\"total_tokens\":3}"
  let result = imported([
    ("missing", response("m", "completed", "null")),
    ("partial", response("p", "incomplete", "{\"input_tokens\":1}")),
    (
      "interrupted",
      event("response.created", response("i", "in_progress", usage)),
    ),
    ("unknown", response("u", "PRIVATE_STATUS", usage)),
    ("empty", ": keepalive\n\n"),
    (
      "zero",
      response(
        "z", "completed", "{\"input_tokens\":0,\"output_tokens\":0,\"total_tokens\":0}",
      ),
    ),
    ("queued", response("q", "queued", usage)),
    ("error", "data: {\"type\":\"error\",\"message\":\"PRIVATE_ERROR\"}\n\n"),
  ])
  assert_eq(field(result, "total"), Json(1))
  assert_eq(field(result, "sourceTotal"), Json(8))
  let values = outcomes(result)
  assert_eq(field(values[0], "usageState"), Json("missing"))
  assert_eq(field(values[1], "usageState"), Json("incomplete"))
  assert_eq(field(values[2], "state"), Json("interrupted"))
  assert_eq(field(values[2], "usageState"), Json("unavailable"))
  assert_eq(field(field(values[2], "observedUsage"), "total_tokens"), Json(3))
  assert_eq(field(values[3], "state"), Json("unknown"))
  assert_eq(field(values[4], "state"), Json("empty"))
  assert_eq(field(values[6], "responseStatus"), Json("queued"))
  assert_eq(field(values[7], "state"), Json("errored"))
  assert_eq(field(values[7], "terminal"), Json(false))
  assert_false(result.stringify().contains("PRIVATE_"))
}

///|
test "earlier usage never fills in missing final usage" {
  let result = imported([
    (
      "s",
      event(
        "response.created",
        response(
          "r", "in_progress", "{\"input_tokens\":1,\"output_tokens\":2,\"total_tokens\":3}",
        ),
      ) +
      event("response.completed", response("r", "completed", "null")),
    ),
  ])
  assert_eq(field(result, "total"), Json(0))
  assert_eq(field(outcomes(result)[0], "usageState"), Json("missing"))
}

///|
test "CRLF multiline metadata and unframed terminal handling" {
  let body = response(
    "r", "completed", "{\"input_tokens\":1,\"output_tokens\":2,\"total_tokens\":3}",
  )
  let framed = "id: ignored\nretry: 1000\n: ping\n" +
    event("response.completed", body)
  let result = imported([("s", framed.split("\n").collect().join("\r\n"))])
  assert_eq(field(result, "total"), Json(1))
  let partial = imported([
    (
      "s",
      event("response.completed", body).strip_suffix("\n").unwrap().to_owned(),
    ),
  ])
  assert_eq(field(partial, "total"), Json(0))
  assert_eq(field(outcomes(partial)[0], "state"), Json("interrupted"))
  let multiline = "data: {\"type\":\"response.completed\",\n" +
    "data: \"response\":" +
    body +
    "}\n\n"
  assert_eq(field(imported([("s", multiline)]), "total"), Json(1))
}

///|
test "mixed identities statuses formats and late events reject atomically" {
  let body = response("one", "completed", "null")
  let start = event("response.created", response("one", "in_progress", "null"))
  let end = event("response.completed", body)
  let delta = "data: {\"type\":\"response.output_text.delta\",\"delta\":\"PRIVATE_DELTA\"}\n\n"
  for
    bad in [
      "[]",
      "{bad PRIVATE_BAD",
      "data: {bad PRIVATE_BAD\n\n",
      "data: [DONE]\n\n",
      body + body,
      event("response.completed", response("one", "failed", "null")),
      end.replace(old="event: response.completed", new="event: response.failed"),
      start + event("response.completed", response("two", "completed", "null")),
      start + end.replace(old="fixture-model", new="different"),
      start + end.replace(old="1791504000", new="1791504001"),
      end + delta,
      end + end,
      end + "data: [DONE]\n\n",
      delta,
      start +
      "data: {\"type\":\"response.output_text.delta\",\"response_id\":\"other\"}\n\n",
      "data: {\"object\":\"chat.completion.chunk\"}\n\n",
      start + "data: {\"type\":\"response.unknown\"}\n\n",
      body.replace(old="\"model\":\"fixture-model\"", new="\"model\":\"\""),
      body.replace(
        old="\"object\":\"response\"",
        new="\"object\":\"chat.completion\"",
      ),
      body.replace(
        old="\"id\":\"one\"",
        new="\"id\":\"other\",\"i\\u0064\":\"one\"",
      ),
      body.replace(
        old="\"usage\":null",
        new="\"usage\":{\"input_tokens\":1,\"input_tokens\":2}",
      ),
    ] {
    guard @response_capture.import_response_captures_json([
        ("good", response("good", "completed", "null")),
        ("bad", bad),
      ])
      is Err(error) else {
      fail("Expected rejection: " + bad)
    }
    assert_false(error.contains("PRIVATE_"))
  }
  assert_true(
    @response_capture.import_response_captures_json([("a", body), ("b", body)])
    is Err(_),
  )
}

///|
test "optional sequence numbers must increase without requiring contiguous coverage" {
  let start = event("response.created", response("r", "in_progress", "null")).replace(
    old="\"type\":",
    new="\"sequence_number\":1,\"type\":",
  )
  let end = event("response.completed", response("r", "completed", "null")).replace(
    old="\"type\":",
    new="\"sequence_number\":3,\"type\":",
  )
  assert_eq(
    field(outcomes(imported([("s", start + end)]))[0], "state"),
    Json("completed"),
  )
  for
    bad in [
      end.replace(old="number\":3", new="number\":1"),
      end.replace(old="number\":3", new="number\":1.00000000000001"),
    ] {
    assert_true(
      @response_capture.import_response_captures_json([("s", start + bad)])
      is Err(_),
    )
  }
}

///|
test "exact counts reject unsafe fractions strings mismatches and combined overflow" {
  for
    usage in [
      "{\"input_tokens\":-1}", "{\"input_tokens\":1.00000000000000001}", "{\"input_tokens\":\"3\"}",
      "{\"input_tokens\":9007199254740992}", "{\"input_tokens\":1,\"output_tokens\":2,\"total_tokens\":4}",
      "{\"input_tokens\":9007199254740991,\"output_tokens\":1,\"total_tokens\":9007199254740991}",
    ] {
    assert_true(
      @response_capture.import_response_captures_json([
        ("a", response("a", "completed", usage)),
      ])
      is Err(_),
    )
  }
  let exact = imported([
    (
      "a",
      response(
        "a", "completed", "{\"input_tokens\":1e1,\"output_tokens\":2.0,\"total_tokens\":12}",
      ),
    ),
  ])
  assert_eq(field(field(exact, "summary"), "tokens"), Json(12))
  let maximum = "{\"input_tokens\":9007199254740991,\"output_tokens\":0,\"total_tokens\":9007199254740991}"
  assert_true(
    @response_capture.import_response_captures_json([
      ("a", response("a", "completed", maximum)),
      ("b", response("b", "completed", maximum)),
    ])
    is Err(_),
  )
}

///|
test "dates are captured only and labels bounds are enforced" {
  let body = response(
    "a", "completed", "{\"input_tokens\":1,\"output_tokens\":2,\"total_tokens\":3}",
  )
  let absent = imported([
    ("2026-10-09.json", body.replace(old="1791504000", new="null")),
  ])
  assert_eq(field(outcomes(absent)[0], "date"), Json::null())
  assert_true(@response_capture.import_response_captures_json([]) is Err(_))
  assert_true(
    @response_capture.import_response_captures_json([("a", "")], app=" ")
    is Err(_),
  )
  assert_true(
    @response_capture.import_response_captures_json([("a", "")], provider=" ")
    is Err(_),
  )
  assert_true(
    @response_capture.import_response_captures_json([("a", ""), ("a", "")])
    is Err(_),
  )
  assert_true(
    @response_capture.import_response_captures_json(Array::make(101, ("a", "")))
    is Err(_),
  )
  assert_true(
    @response_capture.import_response_captures_json([
      ("a", " ".repeat(4 * 1024 * 1024 + 1)),
    ])
    is Err(_),
  )
  let start = event("response.created", response("r", "in_progress", "null"))
  let delta = "data: {\"type\":\"response.output_text.delta\"}\n\n"
  assert_true(
    @response_capture.import_response_captures_json([
      ("a", start + delta.repeat(10000)),
    ])
    is Err(_),
  )
  assert_true(
    @response_capture.import_response_captures_json([
      ("a", start + delta.repeat(5000)),
      ("b", start.replace(old="\"r\"", new="\"s\"") + delta.repeat(5000)),
    ])
    is Err(_),
  )
}
