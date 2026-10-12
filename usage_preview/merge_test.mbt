///|
fn merged(
  files : Array[(String, String)],
  scope? : String = "fixture-gateway",
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
fn merge_row(id : String, tokens? : Int = 10) -> Json {
  {
    "requestId": id.to_json(),
    "model": "small",
    "app": "codex",
    "provider": "local",
    "totalTokens": tokens.to_json(),
  }
}

///|
fn merge_refuses(
  files : Array[(String, String)],
  expected : String,
  scope? : String = "fixture-gateway",
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
    ("one.json", [a, b, a].to_json().stringify()),
    ("two.jsonl", a.stringify() + "\n" + merge_row("c").stringify()),
  ])
  let meta = merge_get(result, "usageMerge")
  assert_eq(merge_get(meta, "inputRows"), (5).to_json())
  assert_eq(merge_get(meta, "uniqueRows"), (3).to_json())
  assert_eq(merge_get(meta, "duplicateRows"), (2).to_json())
  assert_eq(merge_get(merge_get(result, "summary"), "tokens"), (40).to_json())
  assert_eq(
    merge_get(merge_get(result, "summary"), "missingCostCount"),
    (3).to_json(),
  )
  guard merge_get(result, "data") is Array(rows) else { fail("rows") }
  assert_eq(rows.map(row => merge_get(row, "requestId")), [
    "a".to_json(),
    "b".to_json(),
    "c".to_json(),
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
    (1).to_json(),
  )
  assert_eq(
    merge_get(merge_get(result, "summary"), "missingCostCount"),
    (0).to_json(),
  )
  assert_true(!result.stringify().contains("PRIVATE_SENTINEL"))
}

///|
test "merge refuses each differing normalized field without silent enrichment" {
  let base = merge_row("same")
  for
    (field, value) in [
      ("model", "other".to_json()),
      ("app", "other".to_json()),
      ("provider", "other".to_json()),
      ("totalTokens", (11).to_json()),
      ("inputTokens", (0).to_json()),
      ("outputTokens", (0).to_json()),
      ("date", "2026-10-01".to_json()),
      ("totalCostUsd", (0).to_json()),
    ] {
    guard @json.parse(base.stringify()) is Object(changed) else {
      fail("object")
    }
    changed[field] = value
    merge_refuses(
      [
        ("one", [base].to_json().stringify()),
        ("two", [Json::object(changed)].to_json().stringify()),
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
      [("one", [row].to_json().stringify()), ("two", "[]")],
      "explicit nonempty requestId",
    )
  }
  merge_refuses(
    [("one", [merge_row("row-1")].to_json().stringify()), ("two", "[]")],
    "may be synthetic",
  )
  let accepted = merged([
    ("one", [merge_row("row-x")].to_json().stringify()),
    ("two", "[]"),
  ])
  assert_eq(merge_get(accepted, "total"), (1).to_json())
}

///|
test "merge preserves incomplete source evidence without adding unknown totals" {
  let a = merge_row("a")
  let result = merged([
    ("one", Json::object({ "data": [a].to_json(), "total": 100 }).stringify()),
    ("two", [a, merge_row("b")].to_json().stringify()),
  ])
  assert_eq(merge_get(result, "sourceTotal"), (2).to_json())
  assert_eq(merge_get(result, "partial"), true.to_json())
  assert_eq(merge_get(result, "sourceCoverageUnknown"), true.to_json())
  let reopened = @usage_preview.moongate_preview_usage_file_json(
    result.stringify(),
    model="absent",
  )
  guard reopened is Ok(reopened) else { fail("reopen") }
  assert_eq(merge_get(reopened, "partial"), true.to_json())
  assert_eq(merge_get(reopened, "sourceCoverageUnknown"), true.to_json())
  assert_eq(merge_get(reopened, "usageMergeScope"), "fixture-gateway".to_json())
  assert_eq(merge_get(reopened, "total"), (0).to_json())
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
  let one = [merge_row("id")].to_json().stringify()
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
    ("two", [merge_row(" 任务 ")].to_json().stringify()),
  ])
  assert_eq(merge_get(result, "total"), (2).to_json())
  guard merge_get(result, "report") is String(report) else { fail("report") }
  assert_true(report.contains(source.to_json().stringify()))
}

///|
test "merge accepts two empty exports as observed zero without fabricated coverage" {
  let result = merged([("one", "[]"), ("two.csv", "id,model,totalTokens\n")])
  assert_eq(merge_get(result, "total"), (0).to_json())
  assert_eq(merge_get(result, "partial"), false.to_json())
  assert_eq(
    merge_get(merge_get(result, "summary"), "knownEstimatedUsd"),
    (0).to_json(),
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
        [Json::object({ "requestId": "x", "model": "m", "totalTokens": -1 })]
        .to_json()
        .stringify(),
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
    ("one", [large].to_json().stringify()),
    ("two", [large].to_json().stringify()),
  ])
  assert_eq(
    merge_get(merge_get(dup, "summary"), "tokens"),
    9007199254740991.0.to_json(),
  )
  merge_refuses(
    [
      ("one", [large].to_json().stringify()),
      ("two", [merge_row("b")].to_json().stringify()),
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
    [("one", [derived].to_json().stringify()), ("two", "[]")],
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
    [
      ("one", [money].to_json().stringify()),
      ("two", [cent].to_json().stringify()),
    ],
    "known estimate exceeds",
  )
}

///|
test "merge enforces file scope combined row and byte bounds" {
  merge_refuses([("one", "[]")], "2 to 20")
  merge_refuses(Array::make(21, ("one", "[]")), "2 to 20")
  merge_refuses([("one", "[]"), ("two", "[]")], "nonempty", scope=" ")
  let many = Array::make(5001, merge_row("same")).to_json().stringify()
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
    [("one", [row].to_json().stringify()), ("two", "[]")],
    "reopen limit",
  )
}
