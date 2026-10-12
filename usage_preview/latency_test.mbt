///|
test "latency nearest rank unknown zero partial and redaction" {
  let input =
    #|{"sourceTotal":9,"data":[{"requestId":"a","model":"small","totalTokens":1,"latencyMs":0,"apiKey":"DO_NOT_EXPORT"},{"requestId":"b","model":"small","totalTokens":1,"latency_ms":"2.5"},{"requestId":"c","model":"large","totalTokens":1},{"requestId":"d","model":"small","totalTokens":1,"latencyMs":100}]}
  guard @usage_preview.profile_usage_latency_json(input) is Ok(Object(result)) else {
    fail("profile")
  }
  guard result["summary"] is Object(summary) else { fail("summary") }
  assert_eq(summary["sampleCount"], Json::number(3))
  assert_eq(summary["missingLatencyCount"], Json::number(1))
  assert_eq(summary["p50Ms"], Json::number(2.5))
  assert_eq(summary["p95Ms"], Json::number(100))
  assert_eq(summary["p99Ms"], Json::number(100))
  guard result["source"] is Object(source) else { fail("source") }
  assert_eq(source["partial"], true.to_json())
  assert_true(!Json::object(result).stringify().contains("DO_NOT_EXPORT"))
  guard result["slowest"] is Array(rows) && rows[0] is Object(first) else {
    fail("slowest")
  }
  assert_eq(first["requestId"], "d".to_json())
  assert_eq(first["sourceRow"], Json::number(4))
  guard result["byModel"] is Array(groups) && groups[0] is Object(large) else {
    fail("groups")
  }
  assert_eq(large["key"], "large".to_json())
  assert_eq(large["p50Ms"], Json::null())
}

///|
test "latency CSV and all exact filters with UTC boundaries" {
  let input = "id,model,provider,app,totalTokens,date,latency_ms\nx,m,p,a,1,2026-10-09T01:00:00+02:00,10\ny,m,p,a,1,2026-10-09,20\nz,m,p,a,1,,30\nw,m,q,a,1,2026-10-08,40\n"
  guard @usage_preview.profile_usage_latency_json(
      input,
      source_name="input.csv",
      app="a",
      provider="p",
      model="m",
      start_day="2026-10-08",
      end_day="2026-10-08",
    )
    is Ok(Object(result)) else {
    fail("CSV profile")
  }
  assert_eq(result["selectedRows"], Json::number(1))
  guard result["slowest"] is Array(rows) && rows[0] is Object(first) else {
    fail("rows")
  }
  assert_eq(first["requestId"], "x".to_json())
  assert_eq(first["latencyMs"], Json::number(10))
  guard @usage_preview.profile_usage_latency_json(input, app="A")
    is Ok(Object(empty)) else {
    fail("empty")
  }
  guard empty["summary"] is Object(summary) else { fail("summary") }
  assert_eq(summary["p99Ms"], Json::null())
  assert_eq(summary["sampleCount"], Json::number(0))
}

///|
test "latency stable ties retain original source row and cap slowest at twenty" {
  let rows : Array[Json] = []
  for i in 0..<25 {
    rows.push({
      "requestId": "same",
      "model": "m",
      "totalTokens": 1,
      "latencyMs": 10,
      "sourceRow": (99 - i).to_json(),
    })
  }
  guard @usage_preview.profile_usage_latency_json(rows.to_json().stringify())
    is Ok(Object(result)) else {
    fail("profile")
  }
  guard result["slowest"] is Array(slowest) else { fail("slowest") }
  assert_eq(slowest.length(), 20)
  for i, row in slowest {
    guard row is Object(obj) else { fail("object") }
    assert_eq(obj["sourceRow"], (i + 1).to_json())
  }
  guard result["summary"] is Object(summary) else { fail("summary") }
  assert_eq(summary["sampleCount"], Json::number(25))
}

///|
test "latency null blank and absent remain unknown while zero remains a sample" {
  let input =
    #|[{"model":"m","totalTokens":1,"latencyMs":null},{"model":"m","totalTokens":1,"latencyMs":""},{"model":"m","totalTokens":1},{"model":"m","totalTokens":1,"latencyMs":0}]
  guard @usage_preview.profile_usage_latency_json(input) is Ok(Object(result)) &&
    result["summary"] is Object(summary) else {
    fail("profile")
  }
  assert_eq(summary["missingLatencyCount"], Json::number(3))
  assert_eq(summary["p50Ms"], Json::number(0))
  guard @usage_preview.profile_usage_latency_json("[]") is Ok(Object(empty)) &&
    empty["summary"] is Object(empty_summary) else {
    fail("empty")
  }
  assert_eq(empty_summary["maxMs"], Json::null())
}

///|
test "latency invalid input rejected even outside selected filters" {
  for
    value in ["-1", "true", "\"NaN\"", "\"Infinity\"", "9007199254740992", "{}"] {
    let input = "[{\"model\":\"m\",\"totalTokens\":1,\"latencyMs\":" +
      value +
      "}]"
    assert_true(
      @usage_preview.profile_usage_latency_json(input, model="other") is Err(_),
    )
  }
  for
    input in [
      "[{\"model\":\"m\",\"totalTokens\":1,\"latencyMs\":1,\"latency_ms\":1}]", "model,totalTokens,latencyMs,latency_ms\nm,1,1,1\n",
      "broken",
    ] {
    assert_true(@usage_preview.profile_usage_latency_json(input) is Err(_))
  }
  assert_true(
    @usage_preview.profile_usage_latency_json("[]", start_day="2026-02-30")
    is Err(_),
  )
  assert_true(
    @usage_preview.profile_usage_latency_json(
      "[]",
      start_day="2026-10-10",
      end_day="2026-10-09",
    )
    is Err(_),
  )
}

///|
test "latency JSONL and reopened previews expose missing telemetry honestly" {
  let input = "{\"model\":\"m\",\"totalTokens\":1,\"latencyMs\":12}\n\n{\"model\":\"m\",\"totalTokens\":1,\"latency_ms\":8}\n"
  guard @usage_preview.profile_usage_latency_json(input) is Ok(Object(result)) &&
    result["summary"] is Object(summary) else {
    fail("jsonl")
  }
  assert_eq(summary["p50Ms"], Json::number(8))
  guard @usage_preview.moongate_preview_usage_file_json(input) is Ok(preview) else {
    fail("preview")
  }
  guard @usage_preview.profile_usage_latency_json(preview.stringify())
    is Ok(Object(reopened)) &&
    reopened["summary"] is Object(missing) else {
    fail("reopen")
  }
  assert_eq(missing["sampleCount"], Json::number(0))
  assert_eq(missing["missingLatencyCount"], Json::number(2))
}

///|
test "latency nearest rank over one hundred samples and bounded rows" {
  let rows : Array[Json] = []
  for i in 1..<101 {
    rows.push({ "model": "m", "totalTokens": 0, "latencyMs": i.to_json() })
  }
  guard @usage_preview.profile_usage_latency_json(rows.to_json().stringify())
    is Ok(Object(result)) &&
    result["summary"] is Object(summary) else {
    fail("profile")
  }
  assert_eq(summary["p50Ms"], Json::number(50))
  assert_eq(summary["p95Ms"], Json::number(95))
  assert_eq(summary["p99Ms"], Json::number(99))
  assert_eq(summary["maxMs"], Json::number(100))
  let oversized : Array[Json] = []
  for _ in 0..<10001 {
    oversized.push({ "model": "m", "totalTokens": 0 })
  }
  assert_true(
    @usage_preview.profile_usage_latency_json(oversized.to_json().stringify())
    is Err(_),
  )
}
