///|
fn merged(
  files : Array[(String, String)],
  scope~ : String = "fixture-gateway",
) -> Json raise {
  match @usage_preview.merge_usage_files_json(files, scope~) {
    Ok(value) => value
    Err(error) => fail(error)
  }
}

///|
fn merge_get(value : Json, key : String) -> Json raise {
  guard value is Object(obj) && obj.get(key) is Some(field) else {
    fail("Missing field: \{key}")
  }
  field
}

///|
fn merge_row(id : String, tokens~ : Int32 = 10) -> Json {
  {
    "requestId": Json(id),
    "model": "small",
    "app": "codex",
    "provider": "local",
    "totalTokens": Json(tokens),
  }
}

///|
fn merge_refuses(
  files : Array[(String, String)],
  expected : String,
  scope~ : String = "fixture-gateway",
) -> Unit raise {
  match @usage_preview.merge_usage_files_json(files, scope~) {
    Ok(_) => fail("Unexpected successful merge")
    Err(error) => assert_true(error.contains(expected), msg=error)
  }
}

///|
test "merge collapses identical rows within and across files and preserves first occurrence order" {
  let a = merge_row("a")
  let b = merge_row("b", tokens=20)
  let result = merged([
    ("one.json", Json([a, b, a]).stringify()),
    ("two.jsonl", a.stringify() + "\n" + merge_row("c").stringify()),
  ])
  let meta = merge_get(result, "usageMerge")
  assert_eq(merge_get(meta, "inputRows"), Json(5))
  assert_eq(merge_get(meta, "uniqueRows"), Json(3))
  assert_eq(merge_get(meta, "duplicateRows"), Json(2))
  assert_eq(merge_get(merge_get(result, "summary"), "tokens"), Json(40))
  assert_eq(
    merge_get(merge_get(result, "summary"), "missingCostCount"),
    Json(3),
  )
  guard merge_get(result, "data") is Array(rows) else { fail("rows") }
  assert_eq(rows.map(row => merge_get(row, "requestId")), [
    Json("a"),
    Json("b"),
    Json("c"),
  ])
  guard merge_get(meta, "occurrences") is Array(refs) else { fail("refs") }
  assert_eq(refs.length(), 5)
  assert_eq(refs[3], { "requestId": "a", "sourceIndex": 2, "row": 1 })
}

///|
test "merge matches CSV aliases against JSON without retaining unsupported payloads" {
  let csv = "id,model,total_tokens,app,provider,costUsd,date,authorization\r\nx,small,10,codex,local,0,2026-10-01,PRIVATE_SENTINEL\r\n"
  let json : Json = [
    {
      "request_id": "x",
      "modelName": "small",
      "totalTokens": 10,
      "appType": "codex",
      "providerId": "local",
      "totalCostUsd": 0,
      "createdAt": "2026-10-01T00:00:00Z",
      "prompt": "PRIVATE_SENTINEL",
    },
  ]
  let result = merged([("one.csv", csv), ("two.json", json.stringify())])
  assert_eq(
    merge_get(merge_get(result, "usageMerge"), "duplicateRows"),
    Json(1),
  )
  assert_eq(
    merge_get(merge_get(result, "summary"), "missingCostCount"),
    Json(0),
  )
  assert_true(!result.stringify().contains("PRIVATE_SENTINEL"))
}

///|
test "merge refuses each differing normalized field without silent enrichment" {
  let base = merge_row("same")
  for
    (field, value) in [
      ("model", Json("other")),
      ("app", Json("other")),
      ("provider", Json("other")),
      ("totalTokens", Json(11)),
      ("inputTokens", Json(0)),
      ("outputTokens", Json(0)),
      ("date", Json("2026-10-01")),
      ("totalCostUsd", Json(0)),
    ] {
    guard @json.parse(base.stringify()) is Object(changed) else {
      fail("object")
    }
    changed[field] = value
    merge_refuses(
      [
        ("one", Json([base]).stringify()),
        ("two", Json([Json::object(changed)]).stringify()),
      ],
      "Conflicting requestId",
    )
  }
}

///|
test "merge refuses absent blank numeric and legacy synthesized request IDs" {
  let invalid : Array[Json] = [
    { "model": "m", "totalTokens": 1 },
    { "requestId": " ", "model": "m", "totalTokens": 1 },
    { "requestId": 42, "model": "m", "totalTokens": 1 },
  ]
  for row in invalid {
    merge_refuses(
      [("one", Json([row]).stringify()), ("two", "[]")],
      "explicit nonempty requestId",
    )
  }
  merge_refuses(
    [("one", Json([merge_row("row-1")]).stringify()), ("two", "[]")],
    "may be synthetic",
  )
  let accepted = merged([
    ("one", Json([merge_row("row-x")]).stringify()),
    ("two", "[]"),
  ])
  assert_eq(merge_get(accepted, "total"), Json(1))
}

///|
test "merge preserves incomplete source evidence without adding unknown totals" {
  let a = merge_row("a")
  let result = merged([
    ("one", Json::object({ "data": Json([a]), "total": 100 }).stringify()),
    ("two", Json([a, merge_row("b")]).stringify()),
  ])
  assert_eq(merge_get(result, "sourceTotal"), Json(2))
  assert_eq(merge_get(result, "partial"), Json(true))
  assert_eq(merge_get(result, "sourceCoverageUnknown"), Json(true))
  let reopened = @usage_preview.moongate_preview_usage_file_json(
    result.stringify(),
    model="absent",
  )
  guard reopened is Ok(reopened) else { fail("reopen") }
  assert_eq(merge_get(reopened, "partial"), Json(true))
  assert_eq(merge_get(reopened, "sourceCoverageUnknown"), Json(true))
  assert_eq(merge_get(reopened, "usageMergeScope"), Json("fixture-gateway"))
  assert_eq(merge_get(reopened, "total"), Json(0))
  let compared = @usage_preview.compare_usage_files_json(
    result.stringify(),
    result.stringify(),
  )
  guard compared is Ok(compared) else { fail("compare") }
  assert_eq(
    merge_get(merge_get(compared, "summary"), "estimatedUsdDelta"),
    Json::null(),
  )
}

///|
test "merge can reopen merge again without duplicate counts and refuses mismatched scope" {
  let one = Json([merge_row("id")]).stringify()
  let result = merged([("one", one), ("two", one)])
  let again = merged([("merged.json", result.stringify()), ("again", one)])
  assert_eq(merge_get(again, "data"), merge_get(result, "data"))
  merge_refuses(
    [("merged.json", result.stringify()), ("empty", "[]")],
    "scope differs",
    scope="another-gateway",
  )
}

///|
test "merge preserves exact Unicode identifiers and quoted source labels" {
  let source = "源\nlabel.csv"
  let result = merged([
    (source, "id,model,totalTokens\n任务,small,1"),
    ("two", Json([merge_row(" 任务 ")]).stringify()),
  ])
  assert_eq(merge_get(result, "total"), Json(2))
  guard merge_get(result, "report") is String(report) else { fail("report") }
  assert_true(report.contains(Json(source).stringify()))
}

///|
test "merge accepts two empty exports as observed zero without fabricated coverage" {
  let result = merged([("one", "[]"), ("two.csv", "id,model,totalTokens\n")])
  assert_eq(merge_get(result, "total"), Json(0))
  assert_eq(merge_get(result, "partial"), Json(false))
  assert_eq(
    merge_get(merge_get(result, "summary"), "knownEstimatedUsd"),
    Json(0),
  )
}

///|
test "merge rejects malformed row input and whole-file parse failures" {
  merge_refuses([("one", "[]"), ("two", "{PRIVATE_SENTINEL")], "Invalid JSON")
  merge_refuses(
    [
      ("one", "[]"),
      (
        "two",
        Json([
          Json::object({ "requestId": "x", "model": "m", "totalTokens": -1 }),
        ]).stringify(),
      ),
    ],
    "nonnegative",
  )
  merge_refuses(
    [("one.csv", "id,model,totalTokens\na,m,1,extra"), ("two", "[]")],
    "CSV",
  )
}

///|
test "merge rejects unsafe unique aggregates while duplicates do not consume totals twice" {
  let large : Json = {
    "requestId": "a",
    "model": "m",
    "totalTokens": 9007199254740991.0,
  }
  let dup = merged([
    ("one", Json([large]).stringify()),
    ("two", Json([large]).stringify()),
  ])
  assert_eq(
    merge_get(merge_get(dup, "summary"), "tokens"),
    Json(9007199254740991.0),
  )
  merge_refuses(
    [
      ("one", Json([large]).stringify()),
      ("two", Json([merge_row("b")]).stringify()),
    ],
    "token total exceeds",
  )
  let derived : Json = {
    "requestId": "a",
    "model": "m",
    "inputTokens": 9007199254740991.0,
    "outputTokens": 1,
  }
  merge_refuses(
    [("one", Json([derived]).stringify()), ("two", "[]")],
    "token total exceeds",
  )
  let money : Json = {
    "requestId": "a",
    "model": "m",
    "totalTokens": 1,
    "costUsd": 9007199254740991.0,
  }
  let cent : Json = {
    "requestId": "b",
    "model": "m",
    "totalTokens": 1,
    "costUsd": 1,
  }
  merge_refuses(
    [("one", Json([money]).stringify()), ("two", Json([cent]).stringify())],
    "known estimate exceeds",
  )
}

///|
test "merge enforces file scope combined row and byte bounds" {
  merge_refuses([("one", "[]")], "2 to 20")
  merge_refuses(Array::make(21, ("one", "[]")), "2 to 20")
  merge_refuses([("one", "[]"), ("two", "[]")], "nonempty", scope=" ")
  let many = Json(Array::make(5001, merge_row("same"))).stringify()
  merge_refuses([("one", many), ("two", many)], "10,000 combined")
  let spaces = " ".repeat(2 * 1024 * 1024)
  merge_refuses(
    [("one", spaces + "[]"), ("two", spaces + "[]")],
    "combined 4 MiB",
  )
}

///|
test "merge refuses expanded provenance output that cannot reopen" {
  let row : Json = {
    "requestId": "large-label",
    "model": "m".repeat(1600000),
    "totalTokens": 1,
  }
  merge_refuses(
    [("one", Json([row]).stringify()), ("two", "[]")],
    "reopen limit",
  )
}
