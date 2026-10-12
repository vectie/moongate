///|
test "usage CSV integrates normalization filters report and reopen" {
  let csv = "model,total_tokens,cost_usd,date,app\nsmall,5,,2026-10-09,codex\nlarge,8,0,2026-10-08,claude\n"
  guard moongate_preview_usage_file_json(csv, source_name="requests.csv", app="codex") is Ok(value) else { fail("CSV preview failed") }
  guard value is Object(obj) else { fail("Expected object") }
  guard obj.get("data") is Some(Array(rows)) else { fail("Expected data") }
  assert_eq(rows.length(), 1)
  guard rows[0] is Object(row) else { fail("Expected row") }
  assert_eq(row.get("totalTokens"), Some(Json::number(5)))
  assert_eq(row.get("totalCostUsd"), Some(Json::null()))
  guard moongate_preview_usage_file_json(value.stringify()) is Ok(Object(reopened)) else { fail("Reopen failed") }
  assert_eq(reopened["data"], obj["data"])
  assert_eq(reopened["summary"], obj["summary"])
}
