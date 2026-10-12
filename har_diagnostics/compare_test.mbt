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
      get(g, "origin") == origin.to_json() &&
      get(g, "method") == request_method.to_json()
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
  assert_eq(get(report, "matchedGroupCount"), (4).to_json())
  assert_eq(get(report, "baselineOnlyGroupCount"), (0).to_json())
  let group = comparison_group(report, "https://api.fixture.invalid", "POST")
  let a = get(group, "baseline")
  let b = get(group, "candidate")
  let d = get(group, "candidateMinusBaseline")
  assert_eq(get(a, "entries"), (2).to_json())
  assert_eq(get(a, "p50ElapsedMs"), (85).to_json())
  assert_eq(get(b, "p95ElapsedMs"), (205).to_json())
  assert_eq(get(d, "p95ElapsedMs"), (100).to_json())
  assert_eq(get(d, "p50ElapsedMs"), (0).to_json())
  assert_eq(get(a, "httpErrorPercent"), (50).to_json())
  assert_eq(get(d, "httpErrorPercentagePoints"), (0).to_json())
  let unknown = comparison_group(
    report, "https://unknown.fixture.invalid", "GET",
  )
  assert_eq(
    get(get(unknown, "candidateMinusBaseline"), "p95ElapsedMs"),
    Json::null(),
  )
  assert_eq(get(get(unknown, "baseline"), "httpErrorPercent"), Json::null())
  let zeros = comparison_group(report, "https://api.fixture.invalid", "GET")
  assert_eq(get(get(zeros, "baseline"), "p50ElapsedMs"), (0).to_json())
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
  assert_eq(get(report, "matchedGroupCount"), (3).to_json())
  assert_eq(get(report, "baselineOnlyGroupCount"), (1).to_json())
  assert_eq(get(report, "candidateOnlyGroupCount"), (1).to_json())
  let old = comparison_group(report, "https://backup.fixture.invalid", "POST")
  assert_eq(get(old, "presence"), "baseline_only".to_json())
  assert_eq(get(old, "candidate"), Json::null())
  assert_eq(get(get(old, "candidateMinusBaseline"), "entries"), Json::null())
  assert_eq(get(get(old, "baseline"), "noHttpResponseCount"), (1).to_json())
  assert_eq(get(get(old, "baseline"), "httpErrorPercent"), (100).to_json())
  let new = comparison_group(report, "https://new.fixture.invalid", "POST")
  assert_eq(get(new, "presence"), "candidate_only".to_json())
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
  assert_eq(get(result, "baselineCaptureEntries"), (7).to_json())
  assert_eq(get(result, "baselineSelectedEntries"), (2).to_json())
  assert_eq(get(result, "matchedGroupCount"), (1).to_json())
  let empty = "{\"log\":{\"version\":\"1.2\",\"entries\":[]}}"
  let nothing = compare_open(empty, empty)
  assert_eq(get(nothing, "groups"), ([] : Array[Json]).to_json())
  assert_eq(get(nothing, "matchedGroupCount"), (0).to_json())
  assert_eq(
    get(compare_open(empty, fixture()), "candidateOnlyGroupCount"),
    (4).to_json(),
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
