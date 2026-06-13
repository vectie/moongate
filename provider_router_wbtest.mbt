///|
test "circuit breaker opens after consecutive failures" {
  let breaker = CircuitBreaker::new(config={
    failure_threshold: 3,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  assert_true(breaker.get_stats().state == Closed)
  assert_true(breaker.allow_request(now_ms=1000).allowed)
  for _ in 0..<3 {
    breaker.record_failure(false, now_ms=1000)
  }
  assert_true(breaker.get_stats().state == Open)
  assert_false(breaker.allow_request(now_ms=2000).allowed)
}

///|
test "circuit breaker half open closes after configured successes" {
  let breaker = CircuitBreaker::new(config={
    failure_threshold: 2,
    success_threshold: 2,
    timeout_seconds: 0,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  breaker.record_failure(false, now_ms=1000)
  breaker.record_failure(false, now_ms=1000)
  assert_true(breaker.get_stats().state == Open)
  let first = breaker.allow_request(now_ms=1000)
  assert_true(first.allowed)
  assert_true(first.used_half_open_permit)
  breaker.record_success(first.used_half_open_permit)
  let second = breaker.allow_request(now_ms=1000)
  assert_true(second.allowed)
  assert_true(second.used_half_open_permit)
  breaker.record_success(second.used_half_open_permit)
  assert_true(breaker.get_stats().state == Closed)
}

///|
test "circuit breaker half open permit is not reset by selection check" {
  let breaker = CircuitBreaker::new(config={
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 0,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  breaker.record_failure(false, now_ms=1000)
  let first = breaker.allow_request(now_ms=1000)
  assert_true(first.allowed)
  assert_true(first.used_half_open_permit)
  assert_true(breaker.get_stats().state == HalfOpen)
  assert_true(breaker.is_available(now_ms=1000))
  let second = breaker.allow_request(now_ms=1000)
  assert_false(second.allowed)
  assert_false(second.used_half_open_permit)
}

///|
test "provider router failover disabled uses current provider" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="a",
      provider_name="Provider A",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="b",
      provider_name="Provider B",
    ),
  )
  router.set_current_provider("claude", "a")
  router.set_failover_queue("claude", ["b"])
  let selected = router.select_providers("claude", now_ms=1000)
  assert_true(selected.is_ok())
  assert_eq(selected.providers.length(), 1)
  assert_eq(selected.providers[0].provider_id, "a")
}

///|
test "provider router failover enabled uses queue order ignoring current" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="a",
      provider_name="Provider A",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="b",
      provider_name="Provider B",
    ),
  )
  router.set_current_provider("claude", "a")
  router.set_failover_queue("claude", ["b", "a"])
  router.set_auto_failover("claude", true)
  let selected = router.select_providers("claude", now_ms=1000)
  assert_true(selected.is_ok())
  assert_eq(selected.providers.length(), 2)
  assert_eq(selected.providers[0].provider_id, "b")
  assert_eq(selected.providers[1].provider_id, "a")
}

///|
test "provider router failover enabled uses queue only even if current missing" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="a",
      provider_name="Provider A",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="b",
      provider_name="Provider B",
    ),
  )
  router.set_current_provider("claude", "a")
  router.set_failover_queue("claude", ["b"])
  router.set_auto_failover("claude", true)
  let selected = router.select_providers("claude", now_ms=1000)
  assert_true(selected.is_ok())
  assert_eq(selected.providers.length(), 1)
  assert_eq(selected.providers[0].provider_id, "b")
}

///|
test "provider router selection does not consume half open permit" {
  let router = ProviderRouter::new(circuit_config={
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 0,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="a",
      provider_name="Provider A",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="b",
      provider_name="Provider B",
    ),
  )
  router.set_failover_queue("claude", ["a", "b"])
  router.set_auto_failover("claude", true)
  router.record_result("b", "claude", false, false, now_ms=1000)
  let selected = router.select_providers("claude", now_ms=1000)
  assert_true(selected.is_ok())
  assert_eq(selected.providers.length(), 2)
  let allow = router.allow_provider_request("b", "claude", now_ms=1000)
  assert_true(allow.allowed)
  assert_true(allow.used_half_open_permit)
}

///|
test "provider router neutral permit release frees half open slot" {
  let router = ProviderRouter::new(circuit_config={
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 0,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="a",
      provider_name="Provider A",
    ),
  )
  router.set_failover_queue("claude", ["a"])
  router.set_auto_failover("claude", true)
  router.record_result("a", "claude", false, false, now_ms=1000)
  let first = router.allow_provider_request("a", "claude", now_ms=1000)
  assert_true(first.allowed)
  assert_true(first.used_half_open_permit)
  let second = router.allow_provider_request("a", "claude", now_ms=1000)
  assert_false(second.allowed)
  router.release_permit_neutral("a", "claude", first.used_half_open_permit)
  let third = router.allow_provider_request("a", "claude", now_ms=1000)
  assert_true(third.allowed)
  assert_true(third.used_half_open_permit)
}

///|
test "provider router reports all providers circuit open" {
  let router = ProviderRouter::new(circuit_config={
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="a",
      provider_name="Provider A",
    ),
  )
  router.set_failover_queue("claude", ["a"])
  router.set_auto_failover("claude", true)
  router.record_result("a", "claude", false, false, now_ms=1000)
  let selected = router.select_providers("claude", now_ms=2000)
  assert_false(selected.is_ok())
  assert_true(selected.error == Some(AllProvidersCircuitOpen))
  guard router.get_circuit_breaker_stats("a", "claude") is Some(stats) else {
    fail("expected circuit stats")
  }
  json_inspect(stats.to_json(), content={
    "state": "open",
    "consecutiveFailures": 0,
    "consecutiveSuccesses": 0,
    "totalRequests": 1,
    "failedRequests": 1,
  })
}
