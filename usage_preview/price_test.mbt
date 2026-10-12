///|
fn price_fixture_card() -> String {
  (
    #|{"schema":"moongate.usage-rate-card.v1","name":"Hypothetical fixture","currency":"USD","rates":[{"providerId":"p","model":"m","inputUsdPerMillion":2,"outputUsdPerMillion":4}]}
  )
}

///|
test "pricing estimates directional usage preserves original costs and pairs only known values" {
  let input =
    #|[{"requestId":"a","providerId":"p","model":"m","inputTokens":1000000,"outputTokens":500000,"totalCostUsd":5},{"requestId":"b","providerId":"p","model":"m","inputTokens":0,"outputTokens":0},{"requestId":"c","providerId":"p","model":"m","totalTokens":20,"totalCostUsd":7},{"requestId":"d","providerId":"q","model":"m","inputTokens":4,"outputTokens":5,"totalCostUsd":3}]
  guard @usage_preview.price_usage_file_json(input, price_fixture_card())
    is Ok(Object(result)) &&
    result["data"] is Array(rows) &&
    result["usagePricing"] is Object(pricing) &&
    result["summary"] is Object(summary) else {
    fail("pricing")
  }
  assert_eq(summary["knownEstimatedUsd"], Json::number(4))
  assert_eq(summary["missingCostCount"], Json::number(2))
  assert_eq(pricing["pricedCount"], Json::number(2))
  assert_eq(pricing["missingRateCount"], Json::number(1))
  assert_eq(pricing["missingTokenCount"], Json::number(1))
  assert_eq(pricing["originalKnownEstimatedUsd"], Json::number(15))
  assert_eq(pricing["originalMissingCostCount"], Json::number(1))
  assert_eq(pricing["pairedCount"], Json::number(1))
  assert_eq(pricing["pairedDeltaUsd"], Json::number(-1))
  guard rows[2] is Object(unknown) &&
    pricing["observations"] is Array(observations) &&
    observations[2] is Object(observation) else {
    fail("unknown")
  }
  assert_eq(unknown["inputTokens"], Json::null())
  assert_eq(unknown["totalCostUsd"], Json::null())
  assert_eq(observation["originalEstimatedUsd"], Json::number(7))
  assert_eq(observation["sourceRow"], Json::number(3))
}

///|
test "priced CSV reopens in existing explorer with partial coverage and source identity scope" {
  let csv = "id,model,provider,inputTokens,outputTokens,costUsd,date\na,m,p,1000000,500000,5,2026-10-10\nb,m,p,0,0,,2026-10-11\n"
  guard @usage_preview.price_usage_file_json(
      csv,
      price_fixture_card(),
      source_name="example.csv",
    )
    is Ok(result) else {
    fail("CSV")
  }
  guard @usage_preview.moongate_preview_usage_file_json(
      result.stringify(),
      model="m",
      start_day="2026-10-10",
      end_day="2026-10-10",
    )
    is Ok(Object(reopened)) &&
    reopened["summary"] is Object(summary) else {
    fail("reopen")
  }
  assert_eq(summary["requests"], Json::number(1))
  assert_eq(summary["knownEstimatedUsd"], Json::number(4))
  let partial =
    #|{"sourceTotal":9,"sourceCoverageUnknown":true,"usageMergeScope":"fixture","data":[{"model":"m","provider":"p","inputTokens":0,"outputTokens":0}]}
  guard @usage_preview.price_usage_file_json(partial, price_fixture_card())
    is Ok(priced) &&
    @usage_preview.moongate_preview_usage_file_json(priced.stringify())
    is Ok(Object(again)) else {
    fail("partial")
  }
  assert_eq(again["partial"], true.to_json())
  assert_eq(again["sourceTotal"], Json::number(9))
  assert_eq(again["sourceCoverageUnknown"], true.to_json())
  assert_eq(again["usageMergeScope"], "fixture".to_json())
}

///|
test "pricing JSONL missing provider never matches a synthetic Unknown label" {
  let input = "{\"model\":\"m\",\"inputTokens\":0,\"outputTokens\":0}\n{\"providerId\":\"P\",\"model\":\"m\",\"inputTokens\":0,\"outputTokens\":0}\n"
  let card = price_fixture_card().replace(old="\"p\"", new="\"Unknown\"")
  guard @usage_preview.price_usage_file_json(input, card) is Ok(Object(result)) &&
    result["usagePricing"] is Object(pricing) else {
    fail("JSONL")
  }
  assert_eq(pricing["pricedCount"], Json::number(0))
  assert_eq(pricing["missingProviderCount"], Json::number(1))
  assert_eq(pricing["missingRateCount"], Json::number(1))
  assert_eq(pricing["pairedDeltaUsd"], Json::null())
}

///|
test "pricing does not copy payloads headers or secret extra fields" {
  let input =
    #|[{"model":"m","provider":"p","inputTokens":0,"outputTokens":0,"prompt":"SECRET_PROMPT","headers":{"authorization":"SECRET_TOKEN"},"apiKey":"SECRET_KEY"}]
  guard @usage_preview.price_usage_file_json(input, price_fixture_card())
    is Ok(result) else {
    fail("redaction")
  }
  assert_true(!result.stringify().contains("SECRET_"))
}

///|
test "pricing refuses unsupported card shapes duplicate pairs and nonnumeric rates" {
  let card = price_fixture_card()
  for
    invalid in [
      "broken",
      "[]",
      "{}",
      card.replace(old="USD", new="EUR"),
      card.replace(old="usage-rate-card.v1", new="usage-rate-card.v2"),
      card.replace(old="Hypothetical fixture", new=""),
      card.replace(
        old="\"inputUsdPerMillion\":2",
        new="\"inputUsdPerMillion\":-1",
      ),
      card.replace(
        old="\"inputUsdPerMillion\":2",
        new="\"inputUsdPerMillion\":\"2\"",
      ),
      card.replace(
        old="\"inputUsdPerMillion\":2",
        new="\"inputUsdPerMillion\":1e400",
      ),
      card.replace(
        old="\"inputUsdPerMillion\":2",
        new="\"inputUsdPerMillion\":9007199254740992",
      ),
      card.replace(
        old="\"inputUsdPerMillion\":2",
        new="\"cachedUsdPerMillion\":2",
      ),
      card.replace(
        old="\"currency\":\"USD\"",
        new="\"currency\":\"USD\",\"tax\":0",
      ),
    ] {
    assert_true(@usage_preview.price_usage_file_json("[]", invalid) is Err(_))
  }
  let duplicate = card.replace(old="}]", new=",\"extra\":1}]")
  assert_true(@usage_preview.price_usage_file_json("[]", duplicate) is Err(_))
  let pair = "{\"providerId\":\"p\",\"model\":\"m\",\"inputUsdPerMillion\":2,\"outputUsdPerMillion\":4}"
  assert_true(
    @usage_preview.price_usage_file_json(
      "[]",
      card.replace(old=pair, new=pair + "," + pair),
    )
    is Err(_),
  )
}

///|
test "pricing empty input keeps estimates and paired comparison honest" {
  guard @usage_preview.price_usage_file_json("[]", price_fixture_card())
    is Ok(Object(result)) &&
    result["usagePricing"] is Object(pricing) &&
    result["summary"] is Object(summary) else {
    fail("empty")
  }
  assert_eq(pricing["pricedCount"], Json::number(0))
  assert_eq(pricing["pairedOriginalEstimatedUsd"], Json::null())
  assert_eq(pricing["pairedScenarioEstimatedUsd"], Json::null())
  assert_eq(summary["requests"], Json::number(0))
}

///|
test "pricing refuses invalid usage and unsafe totals without partial estimates" {
  for
    input in [
      "broken", "[{\"model\":\"m\",\"inputTokens\":-1}]", "[{\"model\":\"m\",\"inputTokens\":9007199254740991,\"outputTokens\":9007199254740991}]",
      "[{\"model\":\"m\",\"totalTokens\":9007199254740991},{\"model\":\"m\",\"totalTokens\":1}]",
    ] {
    assert_true(
      @usage_preview.price_usage_file_json(input, price_fixture_card())
      is Err(_),
    )
  }
  let huge = price_fixture_card().replace(
    old="\"inputUsdPerMillion\":2",
    new="\"inputUsdPerMillion\":9007199254740991",
  )
  assert_true(
    @usage_preview.price_usage_file_json(
      "[{\"provider\":\"p\",\"model\":\"m\",\"inputTokens\":2000000,\"outputTokens\":0}]",
      huge,
    )
    is Err(_),
  )
}
