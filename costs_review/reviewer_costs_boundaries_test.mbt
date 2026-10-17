///|
fn reviewer_get(value : Json, key : String) -> Json raise {
  guard value is Object(fields) && fields.get(key) is Some(value) else {
    fail("Missing " + key)
  }
  value
}

///|
fn reviewer_costs() -> String {
  let page =
    #|{"object":"page","data":[{"object":"bucket","start_time":1730419200,"end_time":1730505600,"results":[{"object":"organization.costs.result","amount":{"value":2,"currency":"usd"}}]}],"has_more":false}
  page
}

///|
test "reviewer retained hypothetical marker in CSV is never recorded evidence" {
  let usage = "model,totalTokens,costUsd,provider,date,usageEvidenceKind,usageScenarioName\nm,1,1,fixture-route,2024-11-01,hypothetical-route-scenario,Synthetic\n"
  assert_true(
    @costs_review.review_openai_costs_json(
      usage,
      reviewer_costs(),
      provider="fixture-route",
      scope="Synthetic review",
    )
    is Err(_),
  )
}

///|
test "reviewer CSV explicit unknown coverage blocks difference" {
  let usage = "model,totalTokens,costUsd,provider,date,sourceCoverageUnknown\nm,1,1,fixture-route,2024-11-01,true\n"
  match
    @costs_review.review_openai_costs_json(
      usage,
      reviewer_costs(),
      provider="fixture-route",
      scope="Synthetic review",
    ) {
    Err(_) => ()
    Ok(result) => {
      assert_eq(reviewer_get(result, "localSourcePartial"), true.to_json())
      assert_eq(reviewer_get(result, "pairedDays"), Json::number(0))
    }
  }
}

///|
test "reviewer explicit partial envelope blocks difference" {
  let usage =
    #|{"schema":"moongate.usage-file.v1","partial":true,"data":[{"model":"m","totalTokens":1,"costUsd":1,"provider":"fixture-route","date":"2024-11-01"}]}
  match
    @costs_review.review_openai_costs_json(
      usage,
      reviewer_costs(),
      provider="fixture-route",
      scope="Synthetic review",
    ) {
    Err(_) => ()
    Ok(result) => {
      assert_eq(reviewer_get(result, "localSourcePartial"), true.to_json())
      assert_eq(reviewer_get(result, "pairedDays"), Json::number(0))
    }
  }
}

///|
test "reviewer per day difference range cannot be cancelled by preceding day" {
  let usage = "model,totalTokens,costUsd,provider,date\nm,1,0,fixture-route,2024-11-01\nm,1,1000000000000,fixture-route,2024-11-02\n"
  let costs =
    #|{"object":"page","data":[{"object":"bucket","start_time":1730419200,"end_time":1730505600,"results":[{"object":"organization.costs.result","amount":{"value":1000000000000,"currency":"usd"}}]},{"object":"bucket","start_time":1730505600,"end_time":1730592000,"results":[{"object":"organization.costs.result","amount":{"value":-1000000000000,"currency":"usd"}}]}],"has_more":false}
  assert_true(
    @costs_review.review_openai_costs_json(
      usage,
      costs,
      provider="fixture-route",
      scope="Synthetic range review",
    )
    is Err(_),
  )
}

///|
test "reviewer malformed timestamp does not become an observed UTC day" {
  let usage = "model,totalTokens,costUsd,provider,date\nm,1,1,fixture-route,2024-11-01T00:00:00INVALIDZ\n"
  match
    @costs_review.review_openai_costs_json(
      usage,
      reviewer_costs(),
      provider="fixture-route",
      scope="Synthetic review",
    ) {
    Err(_) => ()
    Ok(result) => {
      assert_eq(reviewer_get(result, "localUndatedRows"), Json::number(1))
      assert_eq(reviewer_get(result, "pairedDays"), Json::number(0))
    }
  }
}

///|
test "reviewer exact midnight belongs exclusively to following UTC day" {
  let usage = "model,totalTokens,costUsd,provider,date\nm,1,1,fixture-route,2024-11-02T00:00:00Z\n"
  guard @costs_review.review_openai_costs_json(
      usage,
      reviewer_costs(),
      provider="fixture-route",
      scope="Synthetic review",
    )
    is Ok(result) else {
    fail("Expected bounded review")
  }
  assert_eq(reviewer_get(result, "pairedDays"), Json::number(0))
  assert_eq(reviewer_get(result, "localUndatedRows"), Json::number(0))
  guard reviewer_get(result, "days") is Array(days) else { fail("days") }
  assert_eq(days.length(), 2)
  assert_eq(reviewer_get(days[0], "localRequests"), Json::number(0))
  assert_eq(reviewer_get(days[1], "providerBucketPresent"), false.to_json())
}

///|
test "reviewer negative provider total remains a signed reported amount" {
  let usage = "model,totalTokens,costUsd,provider,date\nm,1,1,fixture-route,2024-11-01\n"
  let costs = reviewer_costs().replace_all(
    old="\"value\":2",
    new="\"value\":-2.5",
  )
  guard @costs_review.review_openai_costs_json(
      usage,
      costs,
      provider="fixture-route",
      scope="Synthetic review",
    )
    is Ok(result) else {
    fail("Expected signed USD")
  }
  assert_eq(reviewer_get(result, "pairedProviderReportedUsd"), (-2.5).to_json())
  assert_eq(
    reviewer_get(result, "pairedReportedMinusEstimatedUsd"),
    (-3.5).to_json(),
  )
  assert_eq(reviewer_get(result, "scopeVerified"), false.to_json())
}

///|
test "reviewer CSV multiline formula scope stays a single quoted text cell" {
  let usage = "model,totalTokens,costUsd,provider,date\nm,1,1,fixture-route,2024-11-01\n"
  guard @costs_review.export_openai_costs_review_csv(
      usage,
      reviewer_costs(),
      provider="fixture-route",
      scope="\t=1+1,\"quoted\"\r\n@SUM(1)",
    )
    is Ok(csv) else {
    fail("Expected CSV")
  }
  assert_true(csv.contains("\"'\t=1+1,\"\"quoted\"\"\r\n@SUM(1)\""))
  assert_true(csv.contains("scopeVerified"))
}
