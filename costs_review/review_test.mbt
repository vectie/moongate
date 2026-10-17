///|
fn get(value : Json, key : String) -> Json raise {
  guard value is Object(fields) && fields.get(key) is Some(value) else {
    fail("Missing " + key)
  }
  value
}

///|
fn bucket(start : Int64, results : Array[Json]) -> Json {
  {
    "object": "bucket",
    "start_time": start.to_double().to_json(),
    "end_time": (start + 86400L).to_double().to_json(),
    "results": results.to_json(),
  }
}

///|
fn amount(
  value : Json,
  project? : Json = "fixture-project",
  line_item? : Json = "text",
) -> Json {
  {
    "object": "organization.costs.result",
    "project_id": project,
    "line_item": line_item,
    "amount": { "value": value, "currency": "usd" },
  }
}

///|
fn page(buckets : Array[Json], more? : Bool = false) -> String {
  Json::object({
    "object": "page",
    "data": buckets.to_json(),
    "has_more": more.to_json(),
    "next_page": Json::null(),
  }).stringify()
}

///|
fn review(usage : String, costs : String) -> Json raise {
  match
    @costs_review.review_openai_costs_json(
      usage,
      costs,
      provider="fixture-route",
      scope="Synthetic corresponding capture",
    ) {
    Ok(value) => value
    Err(error) => fail(error)
  }
}

///|
fn day(result : Json, date : String) -> Json raise {
  guard get(result, "days") is Array(days) else { fail("days") }
  for day in days {
    if get(day, "day") == date.to_json() {
      return day
    }
  }
  fail("Missing day")
}

///|
fn usage(cost : String, date? : String = "2024-11-01") -> String {
  "model,totalTokens,costUsd,provider,date\nm,10," +
  cost +
  ",fixture-route," +
  date
}

///|
test "corresponding daily review sums grouped costs and preserves credits and zero" {
  let capture = usage("1.5") + "\nm,0,0,fixture-route,2024-11-02"
  let costs = page([
    bucket(1730419200L, [amount(2.25), amount(-0.25)]),
    bucket(1730505600L, [amount(0)]),
  ])
  let result = review(capture, costs)
  assert_eq(get(result, "pairedDays"), Json::number(2))
  assert_eq(get(result, "pairedLocalEstimatedUsd"), 1.5.to_json())
  assert_eq(get(result, "pairedProviderReportedUsd"), Json::number(2))
  assert_eq(get(result, "pairedReportedMinusEstimatedUsd"), 0.5.to_json())
  assert_eq(
    get(day(result, "2024-11-02"), "reportedMinusEstimatedUsd"),
    Json::number(0),
  )
  assert_eq(get(result, "scopeVerified"), false.to_json())
}

///|
test "missing local estimate is not zero and prevents that day difference" {
  let result = review(usage(""), page([bucket(1730419200L, [amount(1)])]))
  assert_eq(
    get(day(result, "2024-11-01"), "localKnownEstimatedUsd"),
    Json::null(),
  )
  assert_eq(
    get(day(result, "2024-11-01"), "reportedMinusEstimatedUsd"),
    Json::null(),
  )
  assert_eq(get(result, "pairedDays"), Json::number(0))
}

///|
test "missing provider amount remains unknown alongside known subtotal" {
  let costs = page([
    bucket(1730419200L, [
      amount(2),
      amount(Json::null()),
      { "object": "organization.costs.result" },
    ]),
  ])
  let result = review(usage("1"), costs)
  let first = day(result, "2024-11-01")
  assert_eq(get(first, "providerKnownReportedUsd"), Json::number(2))
  assert_eq(get(first, "providerMissingAmountCount"), Json::number(2))
  assert_eq(get(first, "reportedMinusEstimatedUsd"), Json::null())
}

///|
test "empty provider bucket and absent local day are unavailable instead of zero" {
  let result = review(
    usage("1"),
    page([bucket(1730419200L, []), bucket(1730505600L, [amount(2)])]),
  )
  assert_eq(
    get(day(result, "2024-11-01"), "providerBucketPresent"),
    true.to_json(),
  )
  assert_eq(
    get(day(result, "2024-11-01"), "providerKnownReportedUsd"),
    Json::null(),
  )
  assert_eq(
    get(day(result, "2024-11-02"), "localKnownEstimatedUsd"),
    Json::null(),
  )
  assert_eq(get(result, "pairedDays"), Json::number(0))
}

///|
test "usage outside available provider buckets remains visible" {
  let result = review(
    usage("3", date="2024-11-02"),
    page([bucket(1730419200L, [amount(2)])]),
  )
  assert_eq(
    get(day(result, "2024-11-02"), "providerBucketPresent"),
    false.to_json(),
  )
  assert_eq(
    get(day(result, "2024-11-02"), "differenceBlockers"),
    ["no-provider-bucket"].to_json(),
  )
}

///|
test "partial local capture and unconsumed provider page suppress differences" {
  let capture = "{\"data\":[{\"model\":\"m\",\"totalTokens\":10,\"costUsd\":1,\"providerId\":\"fixture-route\",\"date\":\"2024-11-01\"}],\"sourceTotal\":2}"
  let result = review(
    capture,
    page([bucket(1730419200L, [amount(2)])], more=true),
  )
  assert_eq(get(result, "localSourcePartial"), true.to_json())
  assert_eq(get(result, "providerHasMore"), true.to_json())
  assert_eq(
    get(day(result, "2024-11-01"), "differenceBlockers"),
    ["partial-local-source", "provider-page-has-more"].to_json(),
  )
}

///|
test "unknown source coverage and undated rows cannot disappear from comparison" {
  let capture = "{\"data\":[{\"model\":\"m\",\"totalTokens\":10,\"costUsd\":1,\"providerId\":\"fixture-route\"}],\"sourceCoverageUnknown\":true}"
  let result = review(capture, page([bucket(1730419200L, [amount(2)])]))
  assert_eq(get(result, "localUndatedRows"), Json::number(1))
  assert_eq(get(result, "localSourcePartial"), true.to_json())
  assert_eq(get(result, "pairedDays"), Json::number(0))
}

///|
test "exact app provider project and line item filters compose and disclose counts" {
  let capture = "model,totalTokens,costUsd,provider,app,date\nm,10,1,fixture-route,editor,2024-11-01\nm,10,7,fixture-route,other,2024-11-01\nm,10,9,other,editor,2024-11-01"
  let costs = page([
    bucket(1730419200L, [
      amount(2),
      amount(20, project="other"),
      amount(40, line_item="images"),
    ]),
  ])
  guard @costs_review.review_openai_costs_json(
      capture,
      costs,
      provider="fixture-route",
      scope="Fixture project editor text",
      app="editor",
      project="fixture-project",
      line_item="text",
    )
    is Ok(result) else {
    fail("filter")
  }
  assert_eq(get(result, "localImportedRows"), Json::number(3))
  assert_eq(get(result, "localSelectedRows"), Json::number(1))
  assert_eq(get(result, "providerSourceResults"), Json::number(3))
  assert_eq(get(result, "providerSelectedResults"), Json::number(1))
  assert_eq(get(result, "pairedReportedMinusEstimatedUsd"), Json::number(1))
}

///|
test "missing grouping labels block requested filter rather than invent a project" {
  for label in [Json::null(), "".to_json(), Json::number(3)] {
    let costs = page([bucket(1730419200L, [amount(2, project=label)])])
    assert_true(
      @costs_review.review_openai_costs_json(
        usage("1"),
        costs,
        provider="fixture-route",
        scope="fixture",
        project="fixture-project",
      )
      is Err(_),
    )
  }
}

///|
test "no matched project yields unknown rather than apparent zero cost" {
  let costs = page([bucket(1730419200L, [amount(2)])])
  guard @costs_review.review_openai_costs_json(
      usage("1"),
      costs,
      provider="fixture-route",
      scope="fixture",
      project="absent",
    )
    is Ok(result) else {
    fail("empty filter")
  }
  assert_eq(
    get(day(result, "2024-11-01"), "providerKnownReportedUsd"),
    Json::null(),
  )
  assert_eq(get(result, "pairedDays"), Json::number(0))
}

///|
test "UTC day boundaries are exclusive and non aligned clipped buckets reject" {
  let costs = page([bucket(1730419200L, [amount(2)])])
  let capture = "[{\"model\":\"m\",\"totalTokens\":1,\"costUsd\":1,\"providerId\":\"fixture-route\",\"createdAt\":\"2024-11-02T00:30:00+01:00\"}]"
  assert_eq(get(review(capture, costs), "pairedDays"), Json::number(1))
  for
    bad in [
      bucket(1730419201L, []),
      {
        "object": "bucket",
        "start_time": 1730419200,
        "end_time": 1730505599,
        "results": [],
      },
      {
        "object": "bucket",
        "start_time": 1730419200.5,
        "end_time": 1730505600.5,
        "results": [],
      },
    ] {
    assert_true(
      @costs_review.review_openai_costs_json(
        capture,
        page([bad]),
        provider="fixture-route",
        scope="fixture",
      )
      is Err(_),
    )
  }
}

///|
test "duplicate days and malformed provider record schemas reject atomically" {
  let one = bucket(1730419200L, [amount(2)])
  for
    bad in [
      page([one, one]),
      "{}",
      "[]",
      "not json",
      page([
        bucket(1730419200L, [
          { "object": "organization.usage.completions.result" },
        ]),
      ]),
    ] {
    assert_true(
      @costs_review.review_openai_costs_json(
        usage("1"),
        bad,
        provider="fixture-route",
        scope="fixture",
      )
      is Err(_),
    )
  }
}

///|
test "unsupported currencies numeric strings and unsafe amounts reject" {
  for
    bad in [
      "2".to_json(),
      1000000000001.0.to_json(),
      (-1000000000001.0).to_json(),
    ] {
    assert_true(
      @costs_review.review_openai_costs_json(
        usage("1"),
        page([bucket(1730419200L, [amount(bad)])]),
        provider="fixture-route",
        scope="fixture",
      )
      is Err(_),
    )
  }
  let non_usd : Json = {
    "object": "organization.costs.result",
    "amount": { "value": 1, "currency": "eur" },
  }
  assert_true(
    @costs_review.review_openai_costs_json(
      usage("1"),
      page([bucket(1730419200L, [non_usd])]),
      provider="fixture-route",
      scope="fixture",
    )
    is Err(_),
  )
}

///|
test "explicit scope and provider required and hypothetical artifacts reject" {
  let costs = page([bucket(1730419200L, [amount(2)])])
  for provider in ["", " ", "Unknown"] {
    assert_true(
      @costs_review.review_openai_costs_json(
        usage("1"),
        costs,
        provider~,
        scope="fixture",
      )
      is Err(_),
    )
  }
  assert_true(
    @costs_review.review_openai_costs_json(
      usage("1"),
      costs,
      provider="fixture-route",
      scope=" ",
    )
    is Err(_),
  )
  for
    marker in [
      "\"usageEvidenceKind\":\"hypothetical-route-scenario\",\"usageScenarioName\":\"fiction\"",
      "\"usagePricing\":{}",
    ] {
    assert_true(
      @costs_review.review_openai_costs_json(
        "{\"data\":[]," + marker + "}",
        costs,
        provider="fixture-route",
        scope="fixture",
      )
      is Err(_),
    )
  }
}

///|
test "empty inputs produce no fabricated reconciliation totals" {
  let result = review("[]", page([]))
  assert_eq(get(result, "days"), Json::array([]))
  assert_eq(get(result, "pairedReportedMinusEstimatedUsd"), Json::null())
  assert_eq(get(result, "pairedDays"), Json::number(0))
}

///|
test "CSV carries provenance unknown blanks and inert caller text" {
  guard @costs_review.export_openai_costs_review_csv(
      usage(""),
      page([bucket(1730419200L, [amount(2)])]),
      provider="fixture-route",
      scope="=formula,\"quoted\"",
    )
    is Ok(csv) else {
    fail("csv")
  }
  assert_true(csv.contains("scopeVerified"))
  assert_true(csv.contains("\"'=formula,\"\"quoted\"\"\""))
  assert_true(csv.contains(",0,1,,true,"))
  assert_true(csv.contains("unknown-local-estimates"))
}

///|
test "review excludes payload credentials identifiers and arbitrary fields" {
  let capture = "[{\"model\":\"m\",\"totalTokens\":1,\"costUsd\":1,\"providerId\":\"fixture-route\",\"date\":\"2024-11-01\",\"requestId\":\"secret-id\",\"headers\":\"secret-header\",\"prompt\":\"private-text\"}]"
  let costs = page([
    bucket(1730419200L, [
      {
        "object": "organization.costs.result",
        "amount": { "value": 2, "currency": "usd" },
        "api_key_id": "private-key-id",
        "project_id": "private-project",
      },
    ]),
  ])
  let output = review(capture, costs).stringify()
  for
    hidden in [
      "secret-id", "secret-header", "private-text", "private-key-id", "private-project",
    ] {
    assert_true(!output.contains(hidden))
  }
}

///|
test "aggregation limits reject unsafe local and provider totals" {
  let costs = page([bucket(1730419200L, [amount(1000000000000.0), amount(1)])])
  assert_true(
    @costs_review.review_openai_costs_json(
      usage("1"),
      costs,
      provider="fixture-route",
      scope="fixture",
    )
    is Err(_),
  )
  assert_true(
    @costs_review.review_openai_costs_json(
      usage("1000000000001"),
      page([]),
      provider="fixture-route",
      scope="fixture",
    )
    is Err(_),
  )
}
