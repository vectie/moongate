///|
test "nearest-rank percentiles are deterministic" {
  let result = percentile_snapshot([100, 10, 70, 40, 20, 30, 60, 50, 80, 90])
  assert_eq(result.sample_count, 10)
  assert_eq(result.p50_ms, Some(50))
  assert_eq(result.p95_ms, Some(100))
  assert_eq(result.p99_ms, Some(100))
}

///|
test "empty percentiles remain explicitly unavailable" {
  let result = percentile_snapshot([])
  assert_eq(result.sample_count, 0)
  assert_eq(result.p50_ms, None)
  assert_eq(result.p95_ms, None)
  assert_eq(result.p99_ms, None)
}

///|
test "telemetry decision vocabularies reject unknown wire values" {
  let outcome : Result[TerminalOutcomeV1, @json.JsonDecodeError] = try? @json.from_json(
    Json::string("invented-outcome"),
  )
  let circuit : Result[CircuitStateV1, @json.JsonDecodeError] = try? @json.from_json(
    Json::string("mostly-open"),
  )
  assert_true(outcome is Err(_))
  assert_true(circuit is Err(_))
  json_inspect(TerminalOutcomeV1::RateLimited, content="rate-limit")
  json_inspect(CircuitStateV1::HalfOpen, content="half-open")
}
