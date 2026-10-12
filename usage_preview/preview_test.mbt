///|
test "usage CSV integrates normalization filters report and reopen" {
  let csv = "model,total_tokens,cost_usd,date,app\nsmall,5,,2026-10-09,codex\nlarge,8,0,2026-10-08,claude\n"
  guard @usage_preview.moongate_preview_usage_file_json(
      csv,
      source_name="requests.csv",
      app="codex",
    )
    is Ok(value) else {
    fail("CSV preview failed")
  }
  guard value is Object(obj) else { fail("Expected object") }
  guard obj.get("data") is Some(Array(rows)) else { fail("Expected data") }
  assert_eq(rows.length(), 1)
  guard rows[0] is Object(row) else { fail("Expected row") }
  assert_eq(row.get("totalTokens"), Some(Json::number(5)))
  assert_eq(row.get("totalCostUsd"), Some(Json::null()))
  guard @usage_preview.moongate_preview_usage_file_json(value.stringify())
    is Ok(Object(reopened)) else {
    fail("Reopen failed")
  }
  assert_eq(reopened["data"], obj["data"])
  assert_eq(reopened["summary"], obj["summary"])
}

///|
test "existing JSON envelope behavior and partial provenance survive extraction" {
  let source =
    #|{"data":[{"requestId":"review-1","appType":"codex","providerId":"team-fixture","model":"moon-small","date":"2026-10-06","inputTokens":1200,"outputTokens":300,"totalCostUsd":"0.0045"},{"request_id":"review-2","app_type":"codex","provider_id":"team-fixture","model":"moon-small","created_at":1791331200,"input_tokens":200,"output_tokens":50,"total_cost_usd":"0"},{"requestId":"review-3","appType":"claude","providerId":"other-fixture","model":"moon-large","date":"2026-10-07","inputTokens":800,"outputTokens":400}],"total":12,"page":0,"pageSize":3}
  guard @usage_preview.moongate_preview_usage_file_json(source)
    is Ok(Object(result)) else {
    fail("JSON preview")
  }
  assert_eq(result["partial"], true.to_json())
  assert_eq(result["sourceTotal"], Json::number(12))
  guard result["summary"] is Object(summary) else { fail("summary") }
  assert_eq(summary["tokens"], Json::number(2950))
  assert_eq(summary["knownEstimatedUsd"], Json::number(0.0045))
  assert_eq(summary["missingCostCount"], Json::number(1))
  guard @usage_preview.moongate_preview_usage_file_json(source, app="codex")
    is Ok(Object(filtered)) else {
    fail("filter")
  }
  guard @usage_preview.moongate_preview_usage_file_json(
      Json::object(filtered).stringify(),
    )
    is Ok(Object(reopened)) else {
    fail("reopen")
  }
  assert_eq(reopened["data"], filtered["data"])
  assert_eq(reopened["summary"], filtered["summary"])
  assert_eq(reopened["sourceTotal"], Json::number(12))
}

///|
test "CSV blanks zero total tokens timezone filters and unknown dates" {
  let csv = "model,inputTokens,outputTokens,totalTokens,costUsd,date\na,,0,0,0,2026-10-09T01:00:00+02:00\nb,2,3,,,1791331200\n"
  guard @usage_preview.moongate_preview_usage_file_json(csv)
    is Ok(Object(result)) else {
    fail("preview")
  }
  guard result["data"] is Array(rows) &&
    rows[0] is Object(first) &&
    rows[1] is Object(second) else {
    fail("rows")
  }
  assert_eq(first["inputTokens"], Json::null())
  assert_eq(first["outputTokens"], Json::number(0))
  assert_eq(first["totalTokens"], Json::number(0))
  assert_eq(first["totalCostUsd"], Json::number(0))
  assert_eq(first["date"], "2026-10-08".to_json())
  assert_eq(second["totalTokens"], Json::number(5))
  assert_eq(second["totalCostUsd"], Json::null())
  assert_eq(second["date"], "".to_json())
  guard @usage_preview.moongate_preview_usage_file_json(
      csv,
      start_day="2026-10-08",
      end_day="2026-10-08",
    )
    is Ok(Object(filtered)) else {
    fail("dates")
  }
  assert_eq(filtered["total"], Json::number(1))
}

///|
test "CSV invalid row values reject before output" {
  for
    csv in [
      "model,totalTokens\n,1", "model,totalTokens\na,-1", "model,totalTokens\na,1.5",
      "model,totalTokens\na,", "model,totalTokens\na,9007199254740992",
    ] {
    assert_true(@usage_preview.moongate_preview_usage_file_json(csv) is Err(_))
  }
  assert_true(
    @usage_preview.moongate_preview_usage_file_json(
      "model,totalTokens\na,1",
      start_day="2026-02-30",
    )
    is Err(_),
  )
}

///|
test "JSONL aliases remain accepted and header-only CSV stays empty" {
  let jsonl = "{\"model\":\"a\",\"totalTokens\":1}\n{\"model\":\"b\",\"totalTokens\":2}"
  guard @usage_preview.moongate_preview_usage_file_json(jsonl)
    is Ok(Object(result)) else {
    fail("JSONL")
  }
  assert_eq(result["total"], Json::number(2))
  guard @usage_preview.moongate_preview_usage_file_json("model,totalTokens\n")
    is Ok(Object(empty)) else {
    fail("empty")
  }
  assert_eq(empty["total"], Json::number(0))
}
