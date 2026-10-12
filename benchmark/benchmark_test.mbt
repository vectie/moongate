///|
test "deterministic benchmark is replayable and never claims a live provider" {
  let first = run_deterministic(default_deterministic_workload())
  let second = run_deterministic(default_deterministic_workload())
  assert_eq(first, second)
  assert_eq(first.mode, "deterministic-fixture")
  assert_eq(first.claim_ceiling, "gateway-contract-fixture")
  assert_false(first.live_provider)
  assert_eq(first.request_count, 8)
  assert_eq(first.latency.p95_ms, Some(60))
  assert_eq(first.first_token.p95_ms, Some(27))
}

///|
test "live benchmark control path fails closed without authority or adapter" {
  let request : LiveBenchmarkRequestV1 = {
    contract_id: live_benchmark_request_contract_v1(),
    request_id: "bench-1",
    provider_id: "provider-a",
    model: "model-a",
    workload_id: "bounded-smoke",
    max_requests: 2,
    max_concurrency: 1,
    max_input_tokens: 100,
    max_output_tokens: 100,
    max_cost_nano_usd: 1_000_000L,
    deadline_ms: 2000L,
    cancellation_id: "cancel-1",
    authority_decision_id: None,
  }
  let denied = fail_closed_live_result(request, 1000L)
  assert_eq(denied.status, Denied)
  assert_false(denied.network_request_performed)
  let unavailable = fail_closed_live_result(
    { ..request, authority_decision_id: Some("authority-1"), },
    1000L,
  )
  assert_eq(unavailable.status, Unavailable)
  assert_false(unavailable.network_request_performed)
}

///|
test "live benchmark limits and decision vocabularies fail closed" {
  let request : LiveBenchmarkRequestV1 = {
    contract_id: live_benchmark_request_contract_v1(),
    request_id: "bench-bounds",
    provider_id: "provider-a",
    model: "model-a",
    workload_id: "bounded-smoke",
    max_requests: 101,
    max_concurrency: 1,
    max_input_tokens: 100,
    max_output_tokens: 100,
    max_cost_nano_usd: 1_000_000L,
    deadline_ms: 2000L,
    cancellation_id: "cancel-bounds",
    authority_decision_id: None,
  }
  try validate_live_request(request, 1000L) catch {
    _ => ()
  } noraise {
    _ => fail("expected an out-of-bounds live request to fail validation")
  }
  try {
    let _ : LiveBenchmarkStatusV1 = @json.from_json(Json::string("running"))
  } catch {
    _ => ()
  } noraise {
    _ => fail("expected an unknown live benchmark status to fail decoding")
  }
  try {
    let _ : LiveBenchmarkReasonV1 = @json.from_json(
      Json::string("probably-safe"),
    )
  } catch {
    _ => ()
  } noraise {
    _ => fail("expected an unknown live benchmark reason to fail decoding")
  }
}
