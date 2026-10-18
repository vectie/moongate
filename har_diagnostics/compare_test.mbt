///|
fn compare_open(a : String, b : String) -> Json raise {
  match @har_diagnostics.compare_captures_json(a, b) {
    Ok(value) => value
    Err(message) => fail(message)
  }
}

///|
fn comparison_group(
  result : Json,
  origin : String,
  request_method : String,
) -> Json raise {
  guard get(result, "groups") is Array(groups) else { fail("groups") }
  guard groups
    .iter()
    .find_first(g => {
      get(g, "origin") == Json(origin) &&
      get(g, "method") == Json(request_method)
    })
    is Some(group) else {
    fail("group missing")
  }
  group
}

///|
test "HAR comparison groups only origin and method, preserves missing and zero" {
  let changed = fixture().replace_all(old="\"time\":105", new="\"time\":205")
  let report = compare_open(fixture(), changed)
  assert_eq(get(report, "matchedGroupCount"), Json(4))
  assert_eq(get(report, "baselineOnlyGroupCount"), Json(0))
  let group = comparison_group(report, "https://api.fixture.invalid", "POST")
  let a = get(group, "baseline")
  let b = get(group, "candidate")
  let d = get(group, "candidateMinusBaseline")
  assert_eq(get(a, "entries"), Json(2))
  assert_eq(get(a, "p50ElapsedMs"), Json(85))
  assert_eq(get(b, "p95ElapsedMs"), Json(205))
  assert_eq(get(d, "p95ElapsedMs"), Json(100))
  assert_eq(get(d, "p50ElapsedMs"), Json(0))
  assert_eq(get(a, "httpErrorPercent"), Json(50))
  assert_eq(get(d, "httpErrorPercentagePoints"), Json(0))
  let unknown = comparison_group(
    report, "https://unknown.fixture.invalid", "GET",
  )
  assert_eq(
    get(get(unknown, "candidateMinusBaseline"), "p95ElapsedMs"),
    Json::null(),
  )
  assert_eq(get(get(unknown, "baseline"), "httpErrorPercent"), Json::null())
  let zeros = comparison_group(report, "https://api.fixture.invalid", "GET")
  assert_eq(get(get(zeros, "baseline"), "p50ElapsedMs"), Json(0))
  assert_true(!report.stringify().contains("PRIVATE_"))
  assert_eq(report, compare_open(fixture(), changed))
}

///|
test "unmatched groups are absent observations with null summaries and deltas" {
  let changed = fixture().replace_all(
    old="backup.fixture.invalid",
    new="new.fixture.invalid",
  )
  let report = compare_open(fixture(), changed)
  assert_eq(get(report, "matchedGroupCount"), Json(3))
  assert_eq(get(report, "baselineOnlyGroupCount"), Json(1))
  assert_eq(get(report, "candidateOnlyGroupCount"), Json(1))
  let old = comparison_group(report, "https://backup.fixture.invalid", "POST")
  assert_eq(get(old, "presence"), Json("baseline_only"))
  assert_eq(get(old, "candidate"), Json::null())
  assert_eq(get(get(old, "candidateMinusBaseline"), "entries"), Json::null())
  assert_eq(get(get(old, "baseline"), "noHttpResponseCount"), Json(1))
  assert_eq(get(get(old, "baseline"), "httpErrorPercent"), Json(100))
  let new = comparison_group(report, "https://new.fixture.invalid", "POST")
  assert_eq(get(new, "presence"), Json("candidate_only"))
  assert_eq(get(new, "baseline"), Json::null())
}

///|
test "capture comparison common filters and empty captures remain explicit" {
  guard @har_diagnostics.compare_captures_json(
      fixture(),
      fixture(),
      request_method="post",
      origin="https://API.fixture.invalid:443",
    )
    is Ok(result) else {
    fail("filtered comparison")
  }
  assert_eq(get(result, "baselineCaptureEntries"), Json(7))
  assert_eq(get(result, "baselineSelectedEntries"), Json(2))
  assert_eq(get(result, "matchedGroupCount"), Json(1))
  let empty = "{\"log\":{\"version\":\"1.2\",\"entries\":[]}}"
  let nothing = compare_open(empty, empty)
  assert_eq(get(nothing, "groups"), Json(([] : Array[Json])))
  assert_eq(get(nothing, "matchedGroupCount"), Json(0))
  assert_eq(
    get(compare_open(empty, fixture()), "candidateOnlyGroupCount"),
    Json(4),
  )
}

///|
test "invalid capture on either side fails atomically even outside selected method" {
  assert_true(
    @har_diagnostics.compare_captures_json("broken", fixture()) is Err(_),
  )
  assert_true(
    @har_diagnostics.compare_captures_json(fixture(), "broken") is Err(_),
  )
  let bad = fixture().replace_all(old="\"time\":105", new="\"time\":-2")
  assert_true(
    @har_diagnostics.compare_captures_json(fixture(), bad, request_method="GET")
    is Err(_),
  )
}
