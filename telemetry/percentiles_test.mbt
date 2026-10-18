///|
test "nearest-rank percentiles are deterministic" {
  let result = @telemetry.percentile_snapshot([
    100, 10, 70, 40, 20, 30, 60, 50, 80, 90,
  ])
  assert_eq(result.sample_count, 10)
  assert_eq(result.p50_ms, Some(50))
  assert_eq(result.p95_ms, Some(100))
  assert_eq(result.p99_ms, Some(100))
}

///|
test "empty percentiles remain explicitly unavailable" {
  let result = @telemetry.percentile_snapshot([])
  assert_eq(result.sample_count, 0)
  assert_eq(result.p50_ms, None)
  assert_eq(result.p95_ms, None)
  assert_eq(result.p99_ms, None)
}

///|
test "telemetry decision vocabularies reject unknown wire values" {
  try {
    let _ : @telemetry.TerminalOutcomeV1 = @json.from_json(
      Json::string("invented-outcome"),
    )
  } catch {
    _ => ()
  } noraise {
    _ => fail("expected an unknown terminal outcome to fail decoding")
  }
  try {
    let _ : @telemetry.CircuitStateV1 = @json.from_json(
      Json::string("mostly-open"),
    )
  } catch {
    _ => ()
  } noraise {
    _ => fail("expected an unknown circuit state to fail decoding")
  }
  json_inspect(@telemetry.TerminalOutcomeV1::RateLimited, content="rate-limit")
  json_inspect(@telemetry.CircuitStateV1::HalfOpen, content="half-open")
}
