///|
fn reroute_field(value : Json, key : String) -> Json raise {
  guard value is Object(fields) && fields.get(key) is Some(value) else {
    fail("Missing " + key)
  }
  value
}

///|
fn reroute_plan() -> String {
  let plan =
    #|{"schema":"moongate.usage-route-plan.v1","name":"Test plan","currency":"USD","routes":[{"sourceProviderId":"old","sourceModel":"big","targetProviderId":"new","targetModel":"small","inputUsdPerMillion":2,"outputUsdPerMillion":4}]}
  plan
}

///|
fn reroute_ok(content : String, plan~ : String = reroute_plan()) -> Json raise {
  match @usage_preview.reroute_usage_file_json(content, plan) {
    Ok(value) => value
    Err(error) => fail(error)
  }
}

///|
test "route rehearsal preserves workload pairs comparable costs and exposes missing coverage" {
  let content =
    #|{"data":[{"requestId":"a","providerId":"old","model":"big","inputTokens":1000000,"outputTokens":500000,"totalCostUsd":12,"body":"PRIVATE_FIXTURE"},{"requestId":"b","providerId":"old","model":"big","inputTokens":0,"outputTokens":0,"totalCostUsd":0},{"requestId":"c","providerId":"old","model":"big","totalTokens":50000,"totalCostUsd":3},{"requestId":"d","providerId":"other","model":"big","inputTokens":100,"outputTokens":50,"totalCostUsd":1},{"requestId":"e","providerId":"old","model":"big","inputTokens":1000000,"outputTokens":0}],"sourceTotal":9,"sourceCoverageUnknown":true}
  let output = reroute_ok(content)
  let review = reroute_field(output, "usageRouteScenario")
  for
    (key, expected) in [
      ("mappedCount", 4),
      ("pricedCount", 3),
      ("missingTokenCount", 1),
      ("unmappedCount", 1),
      ("originalMissingCostCount", 1),
      ("pairedCount", 2),
    ] {
    assert_eq(reroute_field(review, key), Json(expected))
  }
  assert_eq(
    reroute_field(review, "originalKnownEstimatedUsd"),
    Json::number(16),
  )
  assert_eq(
    reroute_field(review, "pairedOriginalEstimatedUsd"),
    Json::number(12),
  )
  assert_eq(
    reroute_field(review, "pairedScenarioEstimatedUsd"),
    Json::number(4),
  )
  assert_eq(reroute_field(review, "pairedDeltaUsd"), Json(-8))
  let summary = reroute_field(output, "summary")
  assert_eq(reroute_field(summary, "tokens"), Json::number(2550150))
  assert_eq(reroute_field(summary, "knownEstimatedUsd"), Json::number(6))
  assert_eq(reroute_field(summary, "missingCostCount"), Json::number(2))
  assert_eq(reroute_field(output, "sourceTotal"), Json::number(9))
  assert_eq(reroute_field(output, "partial"), Json(true))
  guard reroute_field(output, "data") is Array(rows) else { fail("data") }
  assert_eq(reroute_field(rows[0], "providerId"), Json("new"))
  assert_eq(reroute_field(rows[2], "model"), Json("small"))
  assert_eq(reroute_field(rows[3], "providerId"), Json("other"))
  assert_eq(reroute_field(rows[3], "totalCostUsd"), Json::null())
  assert_false(output.stringify().contains("PRIVATE_FIXTURE"))
  assert_eq(reroute_ok(content), output)
}

///|
test "scenario label survives filtered reopen CSV and repricing while recorded merge refuses it" {
  let output = reroute_ok(
    "[{\"requestId\":\"a\",\"providerId\":\"old\",\"model\":\"big\",\"inputTokens\":0,\"outputTokens\":0}]",
  ).stringify()
  guard @usage_preview.moongate_preview_usage_file_json(output, provider="new")
    is Ok(reopened) else {
    fail("reopen")
  }
  assert_eq(
    reroute_field(reopened, "usageEvidenceKind"),
    Json("hypothetical-route-scenario"),
  )
  assert_eq(reroute_field(reopened, "total"), Json::number(1))
  guard reroute_field(reopened, "report") is String(report) else {
    fail("report")
  }
  assert_true(report.contains("HYPOTHETICAL ROUTE SCENARIO"))
  guard @usage_preview.export_usage_csv(reopened.stringify(), view="model")
    is Ok(csv) else {
    fail("csv")
  }
  assert_true(csv.contains("usageEvidenceKind,usageScenarioName"))
  assert_true(csv.contains("hypothetical-route-scenario"))
  let rates = "{\"schema\":\"moongate.usage-rate-card.v1\",\"name\":\"Other rate\",\"currency\":\"USD\",\"rates\":[]}"
  guard @usage_preview.price_usage_file_json(output, rates) is Ok(priced) else {
    fail("reprice")
  }
  assert_eq(
    reroute_field(priced, "usageEvidenceKind"),
    Json("hypothetical-route-scenario"),
  )
  assert_true(
    @usage_preview.merge_usage_files_json(
      [("one", output), ("two", output)],
      scope="test",
    )
    is Err(_),
  )
  assert_true(
    @usage_preview.reroute_usage_file_json(output, reroute_plan()) is Err(_),
  )
}

///|
test "exact source pairs cannot match missing labels or altered case and model aliases work" {
  let content =
    #|[{"provider_id":"old","model_name":"big","inputTokens":0,"outputTokens":0},{"providerId":"OLD","model":"big","inputTokens":0,"outputTokens":0},{"model":"big","inputTokens":0,"outputTokens":0},{"providerId":"old","model":"Big","inputTokens":0,"outputTokens":0}]
  let review = reroute_field(reroute_ok(content), "usageRouteScenario")
  assert_eq(reroute_field(review, "mappedCount"), Json::number(1))
  assert_eq(reroute_field(review, "unmappedCount"), Json::number(3))
  assert_eq(reroute_field(review, "pairedDeltaUsd"), Json::null())
  let unknown_plan = reroute_plan().replace_all(
    old="\"old\"",
    new="\"Unknown\"",
  )
  assert_true(
    @usage_preview.reroute_usage_file_json(
      "[{\"providerId\":\"Unknown\",\"model\":\"big\",\"inputTokens\":0,\"outputTokens\":0}]",
      unknown_plan,
    )
    is Err(_),
  )
}

///|
test "CSV and JSONL reordering repeated request ids and source days remain observations" {
  let csv = "requestId,providerId,model,date,inputTokens,outputTokens,totalTokens,totalCostUsd\na,old,big,2026-10-10,1000000,0,1,0\na,old,big,2026-10-11,0,0,0,\n"
  let output = reroute_ok(csv)
  assert_eq(reroute_field(output, "total"), Json::number(2))
  assert_eq(
    reroute_field(reroute_field(output, "summary"), "tokens"),
    Json::number(1),
  )
  assert_eq(
    reroute_field(reroute_field(output, "usageRouteScenario"), "pairedDeltaUsd"),
    Json::number(2),
  )
  guard @usage_preview.moongate_preview_usage_file_json(
      output.stringify(),
      start_day="2026-10-11",
    )
    is Ok(filtered) else {
    fail("filter")
  }
  assert_eq(reroute_field(filtered, "total"), Json::number(1))
  let jsonl = "{\"provider\":\"old\",\"model\":\"big\",\"input_tokens\":0,\"output_tokens\":0}\n{\"provider\":\"old\",\"model\":\"big\",\"totalTokens\":9}"
  assert_eq(
    reroute_field(
      reroute_field(reroute_ok(jsonl), "usageRouteScenario"),
      "missingTokenCount",
    ),
    Json::number(1),
  )
}

///|
test "empty input unmapped plans and unused mappings are explicit" {
  let empty = reroute_ok("[]")
  assert_eq(reroute_field(empty, "total"), Json::number(0))
  let review = reroute_field(empty, "usageRouteScenario")
  assert_eq(reroute_field(review, "unusedMappingIndices"), Json([1]))
  assert_eq(reroute_field(review, "pairedOriginalEstimatedUsd"), Json::null())
  let no_routes = "{\"schema\":\"moongate.usage-route-plan.v1\",\"name\":\"No mappings\",\"currency\":\"USD\",\"routes\":[]}"
  let output = reroute_ok(
    "[{\"provider\":\"old\",\"model\":\"big\",\"totalTokens\":0,\"totalCostUsd\":7}]",
    plan=no_routes,
  )
  assert_eq(
    reroute_field(reroute_field(output, "summary"), "missingCostCount"),
    Json::number(1),
  )
}

///|
test "strict plan rejects ambiguous sources conflicting target rates unsupported rules and unsafe values" {
  let plan = reroute_plan()
  let invalid = [
    "{}",
    "[]",
    "not json",
    plan.replace_all(old="USD", new="EUR"),
    plan.replace_all(old="\"name\":\"Test plan\"", new="\"name\":\"\""),
    plan.replace_all(old="\"routes\":", new="\"live\":true,\"routes\":"),
    plan.replace_all(old="\"sourceModel\":\"big\"", new="\"sourceModel\":null"),
    plan.replace_all(
      old="\"inputUsdPerMillion\":2",
      new="\"inputUsdPerMillion\":\"2\"",
    ),
    plan.replace_all(
      old="\"inputUsdPerMillion\":2",
      new="\"inputUsdPerMillion\":-1",
    ),
    plan.replace_all(
      old="\"inputUsdPerMillion\":2",
      new="\"inputUsdPerMillion\":9007199254740992",
    ),
    plan.replace_all(
      old="\"inputUsdPerMillion\":2",
      new="\"cachedUsdPerMillion\":1,\"inputUsdPerMillion\":2",
    ),
    plan.replace_all(old="\"outputUsdPerMillion\":4", new="\"wrongRate\":4"),
  ]
  for plan in invalid {
    assert_true(
      @usage_preview.reroute_usage_file_json("[]", plan) is Err(_),
      msg=plan,
    )
  }
  guard @json.parse(plan) is Object(fields) && fields["routes"] is Array(routes) else {
    fail("plan")
  }
  routes.push(routes[0])
  assert_true(
    @usage_preview.reroute_usage_file_json(
      "[]",
      Json::object(fields).stringify(),
    )
    is Err(_),
  )
  guard @json.parse(plan) is Object(fields) && fields["routes"] is Array(routes) else {
    fail("plan")
  }
  let other = @json.parse(
    routes[0]
    .stringify()
    .replace_all(old="\"big\"", new="\"another\"")
    .replace_all(old="\"inputUsdPerMillion\":2", new="\"inputUsdPerMillion\":3"),
  )
  routes.push(other)
  assert_true(
    @usage_preview.reroute_usage_file_json(
      "[]",
      Json::object(fields).stringify(),
    )
    is Err(_),
  )
}

///|
test "aggregate overflow malformed usage and broken scenario markers reject without output" {
  for
    content in [
      "{", "[{\"model\":\"big\",\"totalTokens\":-1}]", "[{\"model\":\"big\",\"totalTokens\":9007199254740991},{\"model\":\"big\",\"totalTokens\":1}]",
      "{\"data\":[],\"usageEvidenceKind\":\"hypothetical-route-scenario\"}",
    ] {
    assert_true(
      @usage_preview.reroute_usage_file_json(content, reroute_plan()) is Err(_),
    )
  }
  let rates = reroute_plan().replace_all(
    old="\"inputUsdPerMillion\":2",
    new="\"inputUsdPerMillion\":9007199254740991",
  )
  assert_true(
    @usage_preview.reroute_usage_file_json(
      "[{\"provider\":\"old\",\"model\":\"big\",\"inputTokens\":2000000,\"outputTokens\":0}]",
      rates,
    )
    is Err(_),
  )
}

///|
test "many source routes may share one numeric target rate and size limits reject whole work" {
  guard @json.parse(reroute_plan()) is Object(plan) &&
    plan["routes"] is Array(routes) else {
    fail("plan")
  }
  let second = @json.parse(
    routes[0]
    .stringify()
    .replace_all(old="\"big\"", new="\"other\"")
    .replace_all(
      old="\"inputUsdPerMillion\":2",
      new="\"inputUsdPerMillion\":2.0",
    ),
  )
  routes.push(second)
  assert_true(
    @usage_preview.reroute_usage_file_json("[]", Json::object(plan).stringify())
    is Ok(_),
  )
  plan["routes"] = Json(Array::make(1001, routes[0]))
  assert_true(
    @usage_preview.reroute_usage_file_json("[]", Json::object(plan).stringify())
    is Err(_),
  )
  assert_true(
    @usage_preview.reroute_usage_file_json(
      " ".repeat(4 * 1024 * 1024),
      reroute_plan(),
    )
    is Err(_),
  )
  let large : Json = [
    {
      "requestId": "id",
      "providerId": "old",
      "model": "big",
      "inputTokens": 0,
      "outputTokens": 0,
      "appType": Json("x".repeat(1500000)),
    },
  ]
  assert_true(
    @usage_preview.reroute_usage_file_json(large.stringify(), reroute_plan())
    is Err(_),
  )
}
