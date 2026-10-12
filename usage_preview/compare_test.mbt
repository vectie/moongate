///|
fn comparison_get(value : Json, key : String) -> Json raise {
  guard value is Object(obj) && obj.get(key) is Some(field) else {
    fail("Missing comparison field: \{key}")
  }
  field
}

///|
fn comparison(before : String, after : String) -> Json raise {
  match @usage_preview.compare_usage_files_json(before, after) {
    Ok(value) => value
    Err(error) => fail(error)
  }
}

///|
fn comparison_group(value : Json, field : String, key : String) -> Json raise {
  guard comparison_get(value, field) is Array(rows) else {
    fail("Missing group array")
  }
  for row in rows {
    if comparison_get(row, "key") == key.to_json() {
      return row
    }
  }
  fail("Missing comparison group: \{key}")
}

///|
test "comparison CSV versus JSON computes observed deltas and added removed groups" {
  let before = "model,totalTokens,costUsd,app,provider,date\nold,100,1,codex,one,2026-10-01\nkeep,50,0,codex,one,2026-10-02\n"
  let after = "[{\"model\":\"keep\",\"totalTokens\":80,\"costUsd\":0.5,\"app\":\"codex\",\"provider\":\"one\",\"date\":\"2026-10-08\"},{\"model\":\"new\",\"totalTokens\":120,\"costUsd\":2,\"app\":\"claude\",\"provider\":\"two\",\"date\":\"2026-10-09\"}]"
  let result = comparison(before, after)
  let summary = comparison_get(result, "summary")
  let delta = comparison_get(summary, "delta")
  assert_eq(comparison_get(delta, "requests"), Json::number(0))
  assert_eq(comparison_get(delta, "tokens"), Json::number(50))
  assert_eq(comparison_get(summary, "estimatedUsdDelta"), Json::number(1.5))
  let removed = comparison_group(result, "byModel", "old")
  assert_eq(comparison_get(removed, "status"), "removed".to_json())
  assert_eq(
    comparison_get(comparison_get(removed, "delta"), "tokens"),
    Json::number(-100),
  )
  assert_eq(
    comparison_get(comparison_group(result, "byModel", "new"), "status"),
    "added".to_json(),
  )
  assert_eq(
    comparison_get(comparison_group(result, "byModel", "keep"), "status"),
    "present".to_json(),
  )
  assert_eq(
    comparison_get(comparison_group(result, "byProvider", "two"), "status"),
    "added".to_json(),
  )
  assert_eq(
    comparison_get(comparison_group(result, "byApp", "claude"), "status"),
    "added".to_json(),
  )
  guard comparison_get(result, "byModel") is Array(groups) else {
    fail("groups")
  }
  assert_eq(groups.map(group => comparison_get(group, "key")), [
    "keep".to_json(),
    "new".to_json(),
    "old".to_json(),
  ])
  assert_eq(
    comparison_get(comparison_get(result, "before"), "observedFirstDay"),
    "2026-10-01".to_json(),
  )
}

///|
test "comparison leaves unavailable cost delta null but preserves recorded difference" {
  let result = comparison(
    "model,totalTokens,costUsd\na,10,2\nb,20,", "model,totalTokens,costUsd\na,30,1\nb,10,0",
  )
  let summary = comparison_get(result, "summary")
  assert_eq(comparison_get(summary, "estimatedUsdDelta"), Json::null())
  assert_eq(
    comparison_get(summary, "estimatedUsdDeltaAvailable"),
    false.to_json(),
  )
  assert_eq(
    comparison_get(comparison_get(summary, "delta"), "knownEstimatedUsd"),
    Json::number(-1),
  )
  assert_eq(
    comparison_get(
      comparison_group(result, "byModel", "a"),
      "estimatedUsdDelta",
    ),
    Json::number(-1),
  )
  assert_eq(
    comparison_get(
      comparison_group(result, "byModel", "b"),
      "estimatedUsdDelta",
    ),
    Json::null(),
  )
  guard comparison_get(result, "report") is String(report) else {
    fail("report")
  }
  assert_true(report.contains("estimated USD delta unavailable"))
}

///|
test "comparison partial provenance prevents totals claiming complete cost differences" {
  let source = "{\"data\":[{\"model\":\"m\",\"totalTokens\":100,\"costUsd\":0}],\"total\":10}"
  let result = comparison(source, "model,totalTokens,costUsd\nm,200,0")
  assert_eq(
    comparison_get(comparison_get(result, "before"), "partial"),
    true.to_json(),
  )
  assert_eq(
    comparison_get(comparison_get(result, "before"), "sourceTotal"),
    Json::number(10),
  )
  assert_eq(
    comparison_get(comparison_get(result, "summary"), "estimatedUsdDelta"),
    Json::null(),
  )
  assert_eq(
    comparison_get(
      comparison_group(result, "byModel", "m"),
      "estimatedUsdDelta",
    ),
    Json::null(),
  )
  let reverse = comparison("[]", source)
  assert_eq(
    comparison_get(comparison_get(reverse, "summary"), "estimatedUsdDelta"),
    Json::null(),
  )
}

///|
test "comparison zero baselines and empty sides never divide by zero" {
  let result = comparison("[]", "model,totalTokens,costUsd\nm,0,0")
  let summary = comparison_get(result, "summary")
  assert_eq(comparison_get(summary, "estimatedUsdDelta"), Json::number(0))
  let percents = comparison_get(summary, "percentChange")
  assert_eq(comparison_get(percents, "tokens"), Json::null())
  assert_eq(comparison_get(percents, "requests"), Json::null())
  let empty = comparison("[]", "[]")
  assert_eq(comparison_get(empty, "byModel"), Json::array([]))
  assert_eq(
    comparison_get(comparison_get(empty, "before"), "observedFirstDay"),
    Json::null(),
  )
  let removed = comparison("model,totalTokens,costUsd\nm,100,1", "[]")
  assert_eq(
    comparison_get(
      comparison_get(comparison_get(removed, "summary"), "percentChange"),
      "tokens",
    ),
    Json::number(-100),
  )
}

///|
test "comparison independent UTC windows and shared filters expose selected coverage" {
  let source = "model,totalTokens,costUsd,app,provider,date\nm,10,1,codex,p,2026-10-01\nm,20,2,codex,p,2026-10-08\nm,90,,codex,p,\nn,90,9,claude,p,2026-10-08"
  guard @usage_preview.compare_usage_files_json(
      source,
      source,
      app="codex",
      provider="p",
      model="m",
      before_start_day="2026-10-01",
      before_end_day="2026-10-01",
      after_start_day="2026-10-08",
      after_end_day="2026-10-08",
    )
    is Ok(result) else {
    fail("filters")
  }
  assert_eq(
    comparison_get(
      comparison_get(comparison_get(result, "summary"), "delta"),
      "tokens",
    ),
    Json::number(10),
  )
  assert_eq(
    comparison_get(comparison_get(result, "before"), "selectedRows"),
    Json::number(1),
  )
  assert_eq(
    comparison_get(comparison_get(result, "after"), "importedRows"),
    Json::number(4),
  )
  assert_eq(
    comparison_get(comparison_get(result, "after"), "startDay"),
    "2026-10-08".to_json(),
  )
  let unfiltered = comparison(source, source)
  assert_eq(
    comparison_get(
      comparison_get(comparison_get(unfiltered, "before"), "summary"),
      "undatedCount",
    ),
    Json::number(1),
  )
  guard @usage_preview.compare_usage_files_json(source, source, model="absent")
    is Ok(no_match) else {
    fail("no match")
  }
  assert_eq(
    comparison_get(comparison_get(no_match, "before"), "selectedRows"),
    Json::number(0),
  )
}

///|
test "comparison rejects malformed side date and negative or unsafe token values" {
  for
    bad in [
      "model,totalTokens\nm,-1", "model,totalTokens\nm,1.5", "model,totalTokens\nm,9007199254740992",
      "model,totalTokens\nm,1e309", "model,totalTokens\n\"unfinished,1",
    ] {
    guard @usage_preview.compare_usage_files_json("[]", bad) is Err(error) else {
      fail("Invalid after accepted")
    }
    assert_true(error.has_prefix("After:"))
  }
  guard @usage_preview.compare_usage_files_json("broken", "[]") is Err(error) else {
    fail("Invalid before accepted")
  }
  assert_true(error.has_prefix("Before:"))
  assert_true(
    @usage_preview.compare_usage_files_json(
      "[]",
      "[]",
      before_start_day="2026-02-30",
    )
    is Err(_),
  )
  assert_true(
    @usage_preview.compare_usage_files_json(
      "[]",
      "[]",
      after_start_day="2026-10-09",
      after_end_day="2026-10-08",
    )
    is Err(_),
  )
  assert_true(
    @usage_preview.compare_usage_files_json(
      "model,totalTokens\na,9007199254740991\nb,1", "[]",
    )
    is Err(_),
  )
}

///|
test "comparison exponent counts accepted while invalid costs stay unknown" {
  let result = comparison(
    "model,totalTokens,costUsd\na,1e3,NaN\nb,2e2,-1\nc,0,1e309", "model,totalTokens,costUsd\na,1.2e3,0",
  )
  let summary = comparison_get(comparison_get(result, "before"), "summary")
  assert_eq(comparison_get(summary, "tokens"), Json::number(1200))
  assert_eq(comparison_get(summary, "missingCostCount"), Json::number(3))
  assert_eq(
    comparison_get(comparison_get(result, "summary"), "estimatedUsdDelta"),
    Json::null(),
  )
  let large = comparison(
    "model,totalTokens,costUsd\na,9007199254740991,0", "[]",
  )
  assert_eq(
    comparison_get(
      comparison_get(comparison_get(large, "summary"), "delta"),
      "tokens",
    ),
    Json::number(-9007199254740991.0),
  )
}

///|
test "comparison accepts reopened CSV previews and JSONL with matching totals" {
  let csv = "model,totalTokens,costUsd\na,10,0\nb,20,1"
  guard @usage_preview.moongate_preview_usage_file_json(csv) is Ok(preview) else {
    fail("CSV normalizer")
  }
  let after = "{\"model\":\"a\",\"total_tokens\":10,\"cost_usd\":0}\n{\"model\":\"b\",\"total_tokens\":20,\"cost_usd\":1}"
  let result = comparison(preview.stringify(), after)
  let delta = comparison_get(comparison_get(result, "summary"), "delta")
  assert_eq(comparison_get(delta, "tokens"), Json::number(0))
  assert_eq(comparison_get(delta, "knownEstimatedUsd"), Json::number(0))
}

///|
test "comparison group ordering independent of input row order and report quotes labels" {
  let first = "model,totalTokens,costUsd\nz,1,0\na,2,0"
  let second = "model,totalTokens,costUsd\na,2,0\nz,1,0"
  let one = comparison(first, second)
  let two = comparison(second, first)
  for field in ["summary", "byModel", "byApp", "byProvider"] {
    assert_eq(comparison_get(one, field), comparison_get(two, field))
  }
  let quoted = comparison(
    "[]", "model,totalTokens,costUsd\n\"line\nlabel\",1,0",
  )
  guard comparison_get(quoted, "report") is String(report) else {
    fail("report")
  }
  assert_true(report.contains("\"line\\nlabel\" [added]"))
  assert_true(!report.contains("requestId"))
}

///|
test "comparison null cost and sum limits apply independently to either side" {
  let unknown = "[{\"model\":\"a\",\"totalTokens\":0,\"costUsd\":null}]"
  let zero = "[{\"model\":\"a\",\"totalTokens\":0,\"costUsd\":0}]"
  let result = comparison(zero, unknown)
  assert_eq(
    comparison_get(comparison_get(result, "summary"), "estimatedUsdDelta"),
    Json::null(),
  )
  assert_eq(
    comparison_get(
      comparison_get(comparison_get(result, "summary"), "delta"),
      "missingCostCount",
    ),
    Json::number(1),
  )
  assert_true(
    @usage_preview.compare_usage_files_json(
      "[]", "model,totalTokens,costUsd\na,0,9007199254740991\nb,0,1",
    )
    is Err(_),
  )
  assert_true(
    @usage_preview.compare_usage_files_json(
      "[]", "model,totalTokens\na,9007199254740991\nb,1",
    )
    is Err(_),
  )
}

///|
test "comparison rejects selected derived total overflow before summary loses it" {
  let overflow = "[{\"model\":\"overflow\",\"inputTokens\":9007199254740991,\"outputTokens\":1,\"costUsd\":0}]"
  guard @usage_preview.compare_usage_files_json("[]", overflow)
    is Err(after_error) else {
    fail("Derived after overflow accepted")
  }
  assert_true(
    after_error.has_prefix("After: selected row 1 totalTokens exceeds"),
  )
  guard @usage_preview.compare_usage_files_json(overflow, "[]")
    is Err(before_error) else {
    fail("Derived before overflow accepted")
  }
  assert_true(
    before_error.has_prefix("Before: selected row 1 totalTokens exceeds"),
  )
  let null_total = "[{\"model\":\"overflow\",\"inputTokens\":9007199254740991,\"outputTokens\":1,\"totalTokens\":null}]"
  assert_true(
    @usage_preview.compare_usage_files_json("[]", null_total) is Err(_),
  )
  let csv = "model,inputTokens,outputTokens,costUsd\noverflow,9007199254740991,1,0"
  assert_true(@usage_preview.compare_usage_files_json("[]", csv) is Err(_))
}

///|
test "comparison preserves explicit total precedence and missing component semantics" {
  for total in ["0", "7", "9007199254740991"] {
    let source = "[{\"model\":\"explicit\",\"inputTokens\":9007199254740991,\"outputTokens\":1,\"totalTokens\":" +
      total +
      ",\"costUsd\":0}]"
    let result = comparison("[]", source)
    assert_eq(
      comparison_get(
        comparison_get(comparison_get(result, "summary"), "after"),
        "tokens",
      ).stringify(),
      total,
    )
  }
  for
    source in [
      "[{\"model\":\"missing\",\"inputTokens\":9007199254740991,\"costUsd\":0}]",
      "[{\"model\":\"null\",\"inputTokens\":null,\"outputTokens\":9007199254740991,\"costUsd\":0}]",
      "[{\"model\":\"derived\",\"inputTokens\":9007199254740990,\"outputTokens\":1,\"costUsd\":0}]",
    ] {
    let result = comparison("[]", source)
    assert_eq(
      comparison_get(
        comparison_get(comparison_get(result, "summary"), "after"),
        "tokens",
      ),
      Json::number(9007199254740991.0),
    )
  }
}

///|
test "comparison selected aggregate accepts exact ceiling and rejects next token" {
  let near = "{\"model\":\"near\",\"inputTokens\":9007199254740989,\"outputTokens\":1,\"costUsd\":0}"
  let one = "{\"model\":\"one\",\"totalTokens\":1,\"costUsd\":0}"
  let exact = "[" + near + "," + one + "]"
  let result = comparison("[]", exact)
  assert_eq(
    comparison_get(
      comparison_get(comparison_get(result, "summary"), "after"),
      "tokens",
    ),
    Json::number(9007199254740991.0),
  )
  let overflow = "[" + near + "," + one + "," + one + "]"
  assert_true(@usage_preview.compare_usage_files_json("[]", overflow) is Err(_))
  assert_true(@usage_preview.compare_usage_files_json(overflow, "[]") is Err(_))
  let filtered_source = "[{\"model\":\"overflow\",\"inputTokens\":9007199254740991,\"outputTokens\":1}," +
    one +
    "]"
  guard @usage_preview.compare_usage_files_json(
      "[]",
      filtered_source,
      model="one",
    )
    is Ok(filtered) else {
    fail("Unselected overflow changed filter semantics")
  }
  assert_eq(
    comparison_get(
      comparison_get(comparison_get(filtered, "summary"), "after"),
      "tokens",
    ),
    Json::number(1),
  )
}
