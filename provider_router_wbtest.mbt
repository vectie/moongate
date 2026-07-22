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
test "provider router current selection rejects a disabled provider" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="a",
      provider_name="Provider A",
      enabled=false,
    ),
  )
  router.set_current_provider("claude", "a")
  let selected = router.select_providers("claude", now_ms=1000)
  assert_false(selected.is_ok())
  assert_true(selected.error is Some(NoProvidersConfigured))
}

///|
test "provider router can clear only the expected current provider" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="ark",
      provider_name="Ark",
    ),
  )
  router.set_current_provider("codex", "ark")
  assert_false(router.clear_current_provider("codex", provider_id="other"))
  assert_eq(router.current_provider_id("codex"), Some("ark"))
  assert_true(router.clear_current_provider("codex", provider_id="ark"))
  assert_eq(router.current_provider_id("codex"), None)
}

///|
test "provider router exports prometheus provider and circuit metrics" {
  let router = ProviderRouter::new(circuit_config={
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-oauth",
      provider_name="Codex OAuth",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="backup",
      provider_name="Backup",
      enabled=false,
    ),
  )
  router.set_current_provider("codex", "codex-oauth")
  router.set_auto_failover("codex", true)
  router.record_result("codex-oauth", "codex", false, false, now_ms=1000)
  let metrics = provider_router_prometheus_metrics(router)
  assert_true(metrics.contains("# TYPE moongate_provider_configured gauge\n"))
  assert_true(
    metrics.contains(
      "moongate_provider_configured{app_type=\"codex\",provider_id=\"codex-oauth\"} 1",
    ),
  )
  assert_true(
    metrics.contains(
      "moongate_provider_enabled{app_type=\"codex\",provider_id=\"backup\"} 0",
    ),
  )
  assert_true(
    metrics.contains(
      "moongate_provider_current{app_type=\"codex\",provider_id=\"codex-oauth\"} 1",
    ),
  )
  assert_true(
    metrics.contains(
      "moongate_provider_auto_failover_enabled{app_type=\"codex\"} 1",
    ),
  )
  assert_true(
    metrics.contains(
      "moongate_provider_healthy{app_type=\"codex\",provider_id=\"codex-oauth\"} 0",
    ),
  )
  assert_true(
    metrics.contains(
      "moongate_provider_circuit_open{app_type=\"codex\",provider_id=\"codex-oauth\"} 1",
    ),
  )
  assert_true(
    metrics.contains(
      "moongate_provider_circuit_failed_requests_total{app_type=\"codex\",provider_id=\"codex-oauth\"} 1",
    ),
  )
}

///|
test "provider router failover enabled uses moongate sorted queue ignoring current" {
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
  assert_eq(selected.providers[0].provider_id, "a")
  assert_eq(selected.providers[1].provider_id, "b")
}

///|
test "provider router failover queue skips disabled providers" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="a",
      provider_name="Provider A",
      enabled=false,
    ),
  )
  router.set_failover_queue("claude", ["a"])
  router.set_auto_failover("claude", true)
  let selected = router.select_providers("claude", now_ms=1000)
  assert_false(selected.is_ok())
  assert_true(selected.error is Some(NoProvidersConfigured))
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
test "provider router updates circuit configs per app like moongate" {
  let router = ProviderRouter::new(circuit_config={
    failure_threshold: 4,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="claude-a",
      provider_name="Claude A",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-a",
      provider_name="Codex A",
    ),
  )
  assert_true(router.allow_provider_request("claude-a", "claude").allowed)
  assert_true(router.allow_provider_request("codex-a", "codex").allowed)
  router.update_app_configs("claude", {
    failure_threshold: 1,
    success_threshold: 1,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  router.record_result("claude-a", "claude", false, false, now_ms=1000)
  router.record_result("codex-a", "codex", false, false, now_ms=1000)
  guard router.get_circuit_breaker_stats("claude-a", "claude")
    is Some(claude_stats) else {
    fail("expected claude stats")
  }
  guard router.get_circuit_breaker_stats("codex-a", "codex")
    is Some(codex_stats) else {
    fail("expected codex stats")
  }
  assert_true(claude_stats.state == Open)
  assert_true(codex_stats.state == Closed)

  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="claude-b",
      provider_name="Claude B",
    ),
  )
  router.record_result("claude-b", "claude", false, false, now_ms=1000)
  guard router.get_circuit_breaker_stats("claude-b", "claude")
    is Some(new_claude_stats) else {
    fail("expected new claude stats")
  }
  assert_true(new_claude_stats.state == Open)
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

///|
test "provider route target carries upstream config without serializing key" {
  let target = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="codex-openai",
    provider_name="OpenAI",
    provider_type=Some("codex"),
    base_url=Some("https://api.openai.com/v1"),
    api_key=Some("sk-test"),
    is_full_url=false,
  )
  assert_true(target.provider_type == Some("codex"))
  assert_true(target.base_url == Some("https://api.openai.com/v1"))
  assert_true(target.api_key == Some("sk-test"))
  assert_false(target.is_full_url)
  json_inspect(target.to_json(), content={
    "appType": "codex",
    "providerId": "codex-openai",
    "providerName": "OpenAI",
    "enabled": true,
    "providerType": "codex",
    "baseUrl": "https://api.openai.com/v1",
    "isFullUrl": false,
    "modelMapping": null,
    "origin": "user",
    "hasApiKey": true,
  })
  let serialized = target.to_json().stringify()
  assert_false(serialized.contains("apiKey"))
  assert_false(serialized.contains("sk-test"))
}

///|
test "public provider json redacts nested settings credentials" {
  let target = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="settings-key",
    provider_name="Settings Key",
    settings_config=Some(
      {
        "apiKey": Json::string("nested-secret"),
        "baseUrl": Json::string("https://example.com/v1"),
        "meta": { "token": Json::string("nested-token") }.to_json(),
      }.to_json(),
    ),
  )
  guard target.to_moon_provider_json(false) is Object(public) else {
    fail("expected public provider json")
  }
  assert_eq(public["hasApiKey"], Json::boolean(true))
  assert_eq(public["credentialState"], Json::string("stored"))
  let serialized = Json::object(public).stringify()
  assert_false(serialized.contains("nested-secret"))
  assert_false(serialized.contains("nested-token"))
  assert_true(serialized.contains("https://example.com/v1"))
  assert_true(
    target
    .to_moon_provider_json(false, include_secrets=true)
    .stringify()
    .contains("nested-secret"),
  )
}

///|
test "provider route target serializes moongate claude desktop model routes" {
  let routes : Map[String, ClaudeDesktopModelRoute] = {
    "claude-sonnet-4-6": ClaudeDesktopModelRoute::new(
      model="deepseek-v4-flash [1M]",
      label_override=Some("DeepSeek V4 Flash"),
      supports_1m=Some(true),
    ),
  }
  let target = ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="desktop-provider",
    provider_name="Desktop Provider",
    api_key=Some("sk-hidden"),
    claude_desktop_mode=Some("proxy"),
    claude_desktop_model_routes=routes,
    notes=Some("Desktop provider notes"),
  )
  guard target.to_json() is Object(json) else { fail("expected target object") }
  assert_eq(json["notes"], Json::string("Desktop provider notes"))
  assert_eq(json["claudeDesktopMode"], Json::string("proxy"))
  guard json["claudeDesktopModelRoutes"] is Object(route_json) else {
    fail("expected claude desktop routes")
  }
  guard route_json["claude-sonnet-4-6"] is Object(sonnet) else {
    fail("expected sonnet route")
  }
  assert_eq(sonnet["model"], Json::string("deepseek-v4-flash [1M]"))
  assert_eq(sonnet["labelOverride"], Json::string("DeepSeek V4 Flash"))
  assert_eq(sonnet["supports1m"], Json::boolean(true))
  let moon_provider = target.to_moon_provider_json(false)
  guard moon_provider is Object(moon_provider_obj) else {
    fail("expected moon provider object")
  }
  assert_eq(moon_provider_obj["builtIn"], Json::boolean(false))
  assert_eq(moon_provider_obj["enabled"], Json::boolean(true))
  guard moon_provider is Object(provider) else {
    fail("expected moongate provider object")
  }
  guard provider["meta"] is Object(meta) else { fail("expected provider meta") }
  assert_eq(provider["notes"], Json::string("Desktop provider notes"))
  assert_eq(meta["claudeDesktopMode"], Json::string("proxy"))
  guard meta["claudeDesktopModelRoutes"] is Object(meta_routes) else {
    fail("expected moongate route metadata")
  }
  assert_true(meta_routes.get("claude-sonnet-4-6") is Some(_))
  let serialized = moon_provider.stringify()
  assert_false(serialized.contains("apiKey"))
  assert_false(serialized.contains("sk-hidden"))
}

///|
test "provider router exposes moongate failover queue and available providers" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="a",
      provider_name="Provider A",
      provider_type=Some("codex"),
      settings_config=Some({ "model": Json::string("gpt-5") }.to_json()),
      notes=Some("Primary provider"),
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="b",
      provider_name="Provider B",
      notes=Some("Fallback provider"),
    ),
  )
  router.set_failover_queue("codex", ["b"])
  json_inspect(router.failover_queue_json("codex"), content=[
    {
      "providerId": "b",
      "providerName": "Provider B",
      "sortIndex": null,
      "providerNotes": "Fallback provider",
    },
  ])
  guard router.available_failover_providers_json("codex") is Array(available) else {
    fail("expected available providers array")
  }
  assert_eq(available.length(), 1)
  guard available[0] is Object(provider) else {
    fail("expected available provider object")
  }
  assert_eq(provider["id"], Json::string("a"))
  assert_eq(provider["name"], Json::string("Provider A"))
  assert_eq(provider["notes"], Json::string("Primary provider"))
  assert_eq(provider["inFailoverQueue"], Json::boolean(false))
  guard provider["settingsConfig"] is Object(settings) else {
    fail("expected settingsConfig")
  }
  assert_eq(settings["model"], Json::string("gpt-5"))
}

///|
test "provider router failover queue uses moongate stored provider sort index" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="a",
      provider_name="Provider A",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="b",
      provider_name="Provider B",
    ),
  )
  assert_true(
    router.update_providers_sort_order("codex", [
      { id: "a", sort_index: 3 },
      { id: "b", sort_index: 7 },
    ]),
  )
  router.set_failover_queue("codex", ["b", "a"])
  json_inspect(router.failover_queue_json("codex"), content=[
    { "providerId": "a", "providerName": "Provider A", "sortIndex": 3 },
    { "providerId": "b", "providerName": "Provider B", "sortIndex": 7 },
  ])
}

///|
test "provider router add remove failover queue mirrors moongate semantics" {
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
  router.add_to_failover_queue("claude", "a")
  router.add_to_failover_queue("claude", "a")
  json_inspect(router.failover_queue_json("claude"), content=[
    { "providerId": "a", "providerName": "Provider A", "sortIndex": null },
  ])
  router.record_result("a", "claude", false, false, now_ms=1000)
  guard router.get_circuit_breaker_stats("a", "claude") is Some(open_stats) else {
    fail("expected open stats")
  }
  assert_true(open_stats.state == Open)
  router.remove_from_failover_queue("claude", "a")
  json_inspect(router.failover_queue_json("claude"), content=[])
  guard router.get_circuit_breaker_stats("a", "claude") is Some(reset_stats) else {
    fail("expected reset stats")
  }
  assert_true(reset_stats.state == Closed)
}

///|
test "provider router moongate auto failover enable seeds empty queue" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="current",
      provider_name="Current Provider",
    ),
  )
  router.set_current_provider("codex", "current")
  assert_true(router.set_auto_failover_checked("codex", true))
  assert_true(router.auto_failover_enabled_for_app("codex"))
  json_inspect(router.failover_queue_json("codex"), content=[
    {
      "providerId": "current",
      "providerName": "Current Provider",
      "sortIndex": null,
    },
  ])
  assert_true(router.set_auto_failover_checked("codex", false))
  assert_false(router.auto_failover_enabled_for_app("codex"))
  assert_false(router.set_auto_failover_checked("unknown", true))
}

///|
test "provider router moongate auto failover command switches to p1" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="current",
      provider_name="Current Provider",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="p1",
      provider_name="P1 Provider",
    ),
  )
  router.set_current_provider("codex", "current")
  assert_true(
    router.update_providers_sort_order("codex", [
      { id: "p1", sort_index: 0 },
      { id: "current", sort_index: 1 },
    ]),
  )
  router.set_failover_queue("codex", ["current", "p1"])
  assert_true(router.set_auto_failover_from_command("codex", true))
  assert_true(router.auto_failover_enabled_for_app("codex"))
  assert_eq(router.current_provider_id("codex"), Some("p1"))
}

///|
test "provider router moongate auto failover command rolls back auto added official p1" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="official",
      provider_name="Official Provider",
      provider_type=Some("official"),
    ),
  )
  router.set_current_provider("codex", "official")
  assert_false(router.set_auto_failover_from_command("codex", true))
  assert_false(router.auto_failover_enabled_for_app("codex"))
  assert_eq(router.current_provider_id("codex"), Some("official"))
  json_inspect(router.failover_queue_json("codex"), content=[])
}

///|
test "provider router moongate reset switches back to recovered higher priority provider" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="p1",
      provider_name="Primary",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="p2",
      provider_name="Fallback",
    ),
  )
  router.set_failover_queue("claude", ["p1", "p2"])
  router.set_current_provider("claude", "p2")
  router.set_auto_failover("claude", true)
  router.record_result("p1", "claude", false, false, now_ms=1000)
  assert_true(
    router.reset_provider_breaker_and_restore(
      "p1",
      "claude",
      app_enabled=true,
      proxy_running=true,
    ),
  )
  assert_eq(router.current_provider_id("claude"), Some("p1"))
  guard router.get_circuit_breaker_stats("p1", "claude") is Some(stats) else {
    fail("expected reset breaker stats")
  }
  assert_true(stats.state == Closed)
}

///|
test "provider router moongate reset does not switch without takeover auto failover and priority" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="p1",
      provider_name="Primary",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="p2",
      provider_name="Fallback",
    ),
  )
  router.set_failover_queue("codex", ["p1", "p2"])
  router.set_current_provider("codex", "p2")
  assert_false(
    router.reset_provider_breaker_and_restore(
      "p1",
      "codex",
      app_enabled=true,
      proxy_running=true,
    ),
  )
  assert_eq(router.current_provider_id("codex"), Some("p2"))

  router.set_auto_failover("codex", true)
  assert_false(
    router.reset_provider_breaker_and_restore(
      "p1",
      "codex",
      app_enabled=false,
      proxy_running=true,
    ),
  )
  assert_eq(router.current_provider_id("codex"), Some("p2"))

  assert_false(
    router.reset_provider_breaker_and_restore(
      "p1",
      "codex",
      app_enabled=true,
      proxy_running=false,
    ),
  )
  assert_eq(router.current_provider_id("codex"), Some("p2"))

  assert_false(
    router.reset_provider_breaker_and_restore(
      "p2",
      "codex",
      app_enabled=true,
      proxy_running=true,
    ),
  )
  assert_eq(router.current_provider_id("codex"), Some("p2"))
}

///|
test "provider router exposes moongate provider map and current id" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="a",
      provider_name="Provider A",
      provider_type=Some("custom"),
      base_url=Some("https://api.example.com/v1"),
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="b",
      provider_name="Provider B",
    ),
  )
  router.set_current_provider("codex", "a")
  router.set_failover_queue("codex", ["b"])
  assert_eq(router.current_provider_id("codex"), Some("a"))
  guard router.providers_moon_json("codex") is Object(providers) else {
    fail("expected providers object")
  }
  guard providers["a"] is Object(provider_a) else {
    fail("expected provider a")
  }
  assert_eq(provider_a["id"], Json::string("a"))
  assert_eq(provider_a["name"], Json::string("Provider A"))
  assert_eq(provider_a["category"], Json::string("custom"))
  assert_eq(
    provider_a["websiteUrl"],
    Json::string("https://api.example.com/v1"),
  )
  assert_eq(provider_a["inFailoverQueue"], Json::boolean(false))
  guard providers["b"] is Object(provider_b) else {
    fail("expected provider b")
  }
  assert_eq(provider_b["inFailoverQueue"], Json::boolean(true))
}

///|
test "provider router delete active provider selects deterministic fallback" {
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
  router.set_failover_queue("claude", ["a", "b"])
  assert_true(router.delete_provider("claude", "a"))
  assert_eq(router.current_provider_id("claude"), Some("b"))
  json_inspect(router.failover_queue_json("claude"), content=[
    { "providerId": "b", "providerName": "Provider B", "sortIndex": null },
  ])
  assert_false(router.delete_provider("claude", "missing"))
}

///|
test "provider router refuses to delete built-in routes" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-oauth",
      provider_name="Codex OAuth",
      provider_type=Some("codex_oauth"),
      origin="builtin",
    ),
  )
  router.set_current_provider("codex", "codex-oauth")
  assert_false(router.delete_provider("codex", "codex-oauth"))
  assert_eq(router.current_provider_id("codex"), Some("codex-oauth"))
}

///|
test "provider router delete additive current provider follows moongate mode" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="opencode",
      provider_id="a",
      provider_name="Provider A",
    ),
  )
  router.set_current_provider("opencode", "a")
  assert_true(router.delete_provider("opencode", "a"))
  assert_eq(router.current_provider_id("opencode"), None)
  guard router.providers_moon_json("opencode") is Object(providers) else {
    fail("expected providers object")
  }
  assert_true(providers.get("a") is None)
}

///|
test "provider router current provider command mirrors moongate additive mode" {
  let router = ProviderRouter::new()
  router.set_current_provider("opencode", "a")
  router.set_current_provider("claude", "b")
  assert_eq(router.current_provider_for_moon_command("opencode"), "")
  assert_eq(router.current_provider_for_moon_command("openclaw"), "")
  assert_eq(router.current_provider_for_moon_command("hermes"), "")
  assert_eq(router.current_provider_for_moon_command("claude"), "b")
  assert_eq(router.current_provider_for_moon_command("codex"), "")
}

///|
test "provider router remove live config preserves stored additive provider" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="opencode",
      provider_id="a",
      provider_name="Provider A",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="opencode",
      provider_id="b",
      provider_name="Provider B",
    ),
  )
  router.set_current_provider("opencode", "a")
  router.set_failover_queue("opencode", ["a"])
  assert_true(router.remove_provider_from_live_config("opencode", "a"))
  assert_eq(router.current_provider_id("opencode"), Some("b"))
  guard router.providers_moon_json("opencode") is Object(providers) else {
    fail("expected providers object")
  }
  assert_true(providers.get("a") is Some(_))
  json_inspect(router.failover_queue_json("opencode"), content=[])
  assert_false(router.remove_provider_from_live_config("gemini", "a"))
}

///|
test "provider router custom endpoints mirror moongate metadata semantics" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="a",
      provider_name="Provider A",
    ),
  )
  assert_true(
    router.add_custom_endpoint(
      "codex",
      "a",
      " https://first.example.com/v1/// ",
      now_ms=1000,
    ),
  )
  assert_true(
    router.add_custom_endpoint(
      "codex",
      "a",
      "https://second.example.com/v1",
      now_ms=2000,
    ),
  )
  assert_false(router.add_custom_endpoint("codex", "a", " /// ", now_ms=3000))
  json_inspect(router.custom_endpoints_json("codex", "a"), content=[
    { "url": "https://second.example.com/v1", "addedAt": 2000 },
    { "url": "https://first.example.com/v1", "addedAt": 1000 },
  ])
  router.update_endpoint_last_used(
    "codex",
    "a",
    "https://first.example.com/v1/",
    now_ms=5000,
  )
  json_inspect(router.custom_endpoints_json("codex", "a"), content=[
    { "url": "https://second.example.com/v1", "addedAt": 2000 },
    { "url": "https://first.example.com/v1", "addedAt": 1000, "lastUsed": 5000 },
  ])
  router.remove_custom_endpoint("codex", "a", "https://second.example.com/v1/")
  json_inspect(router.custom_endpoints_json("codex", "a"), content=[
    { "url": "https://first.example.com/v1", "addedAt": 1000, "lastUsed": 5000 },
  ])
  json_inspect(router.custom_endpoints_json("codex", "missing"), content=[])
}

///|
test "provider router mirrors moongate live settings and sort updates" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="a",
      provider_name="Provider A",
      settings_config=Some(
        {
          "apiKey": Json::string("sk-a"),
          "baseUrl": Json::string("https://a.example.com/v1"),
        }.to_json(),
      ),
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="b",
      provider_name="Provider B",
    ),
  )
  router.set_current_provider("codex", "a")
  json_inspect(router.read_live_provider_settings("codex"), content={
    "apiKey": "sk-a",
    "baseUrl": "https://a.example.com/v1",
  })
  json_inspect(router.live_provider_json("codex", "a"), content={
    "apiKey": "sk-a",
    "baseUrl": "https://a.example.com/v1",
  })
  assert_eq(router.live_provider_json("codex", "missing"), Json::null())
  assert_true(
    router.update_providers_sort_order("codex", [
      { id: "b", sort_index: 0 },
      { id: "a", sort_index: 1 },
    ]),
  )
  guard router.providers_moon_json("codex") is Object(providers) else {
    fail("expected providers object")
  }
  guard providers["a"] is Object(provider_a) else {
    fail("expected provider a")
  }
  guard providers["b"] is Object(provider_b) else {
    fail("expected provider b")
  }
  assert_eq(provider_a["sortIndex"], Json::number(1.0))
  assert_eq(provider_b["sortIndex"], Json::number(0.0))
  json_inspect(router.read_live_provider_settings("missing"), content={})
}

///|
test "provider router syncs current live providers with moongate sort order" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="b",
      provider_name="Provider B",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="a",
      provider_name="Provider A",
    ),
  )
  router.set_current_provider("codex", "stale")
  assert_true(
    router.update_providers_sort_order("codex", [
      { id: "b", sort_index: 0 },
      { id: "a", sort_index: 1 },
    ]),
  )
  let targets = router.sync_current_provider_targets()
  assert_eq(targets.length(), 1)
  assert_eq(targets[0].provider_id, "b")
  assert_eq(router.current_provider_id("codex"), Some("b"))
  router.set_current_provider("codex", "a")
  let preserved = router.sync_current_provider_targets()
  assert_eq(preserved.length(), 1)
  assert_eq(preserved[0].provider_id, "a")
  assert_eq(router.current_provider_id("codex"), Some("a"))
}

///|
test "provider router live sync skips takeover-polluted current provider" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="polluted",
      provider_name="Polluted",
      settings_config=Some(
        {
          "env": Json::object({
            "ANTHROPIC_BASE_URL": Json::string("http://127.0.0.1:15721"),
            "ANTHROPIC_AUTH_TOKEN": Json::string("PROXY_MANAGED"),
          }),
        }.to_json(),
      ),
    ),
  )
  router.set_current_provider("claude", "polluted")
  let targets = router.sync_current_provider_targets()
  assert_eq(targets.length(), 0)
  assert_eq(router.current_provider_id("claude"), Some("polluted"))
}

///|
test "provider router syncs universal providers into app providers" {
  let router = ProviderRouter::new()
  assert_true(
    router.upsert_universal_provider(
      {
        "id": Json::string("u1"),
        "name": Json::string("Universal One"),
        "providerType": Json::string("openai-compatible"),
        "apps": {
          "claude": Json::boolean(true),
          "codex": Json::boolean(true),
          "gemini": Json::boolean(false),
        }.to_json(),
        "baseUrl": Json::string("https://api.example.com/v1"),
        "apiKey": Json::string("sk-u1"),
        "models": {
          "codex": {
            "model": Json::string("gpt-5"),
            "reasoningEffort": Json::string("medium"),
          }.to_json(),
        }.to_json(),
      }.to_json(),
    ),
  )
  guard router.universal_provider_json("u1") is Object(universal) else {
    fail("expected universal provider")
  }
  assert_eq(universal["name"], Json::string("Universal One"))
  assert_true(router.sync_universal_provider("u1"))
  json_inspect(router.live_provider_ids_json("codex"), content=[
    "universal-codex-u1",
  ])
  guard router.providers_moon_json("codex") is Object(codex_providers) else {
    fail("expected codex providers")
  }
  guard codex_providers["universal-codex-u1"] is Object(codex_provider) else {
    fail("expected synced codex provider")
  }
  assert_eq(codex_provider["name"], Json::string("Universal One"))
  guard codex_provider["settingsConfig"] is Object(settings) else {
    fail("expected settings config")
  }
  assert_true(settings.get("apiKey") is None)
  guard settings.get("models") is Some(Object(codex_models)) else {
    fail("expected codex models")
  }
  assert_eq(codex_models["model"], Json::string("gpt-5"))
  assert_true(
    router
    .providers_moon_json("codex", include_secrets=true)
    .stringify()
    .contains("sk-u1"),
  )
  assert_eq(router.import_live_providers("codex"), 1)
  assert_true(router.delete_universal_provider("u1"))
  json_inspect(router.universal_providers_json(), content={})
  json_inspect(router.live_provider_ids_json("codex"), content=[])
}
