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
test "provider router current selection ignores metadata enabled flag like ccs" {
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
  assert_true(selected.is_ok())
  assert_eq(selected.providers.length(), 1)
  assert_eq(selected.providers[0].provider_id, "a")
  assert_false(selected.providers[0].enabled)
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
test "provider router failover queue ignores metadata enabled flag like ccs" {
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
  assert_true(selected.is_ok())
  assert_eq(selected.providers.length(), 1)
  assert_eq(selected.providers[0].provider_id, "a")
  assert_false(selected.providers[0].enabled)
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
  })
  let serialized = target.to_json().stringify()
  assert_false(serialized.contains("apiKey"))
  assert_false(serialized.contains("sk-test"))
}

///|
test "provider route target serializes ccs claude desktop model routes" {
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
    claude_desktop_model_routes=routes,
  )
  guard target.to_json() is Object(json) else { fail("expected target object") }
  guard json["claudeDesktopModelRoutes"] is Object(route_json) else {
    fail("expected claude desktop routes")
  }
  guard route_json["claude-sonnet-4-6"] is Object(sonnet) else {
    fail("expected sonnet route")
  }
  assert_eq(sonnet["model"], Json::string("deepseek-v4-flash [1M]"))
  assert_eq(sonnet["labelOverride"], Json::string("DeepSeek V4 Flash"))
  assert_eq(sonnet["supports1m"], Json::boolean(true))
  let ccs_provider = target.to_ccs_provider_json(false)
  guard ccs_provider is Object(provider) else {
    fail("expected ccs provider object")
  }
  guard provider["meta"] is Object(meta) else { fail("expected provider meta") }
  guard meta["claudeDesktopModelRoutes"] is Object(meta_routes) else {
    fail("expected ccs route metadata")
  }
  assert_true(meta_routes.get("claude-sonnet-4-6") is Some(_))
  let serialized = ccs_provider.stringify()
  assert_false(serialized.contains("apiKey"))
  assert_false(serialized.contains("sk-hidden"))
}

///|
test "provider router exposes ccs failover queue and available providers" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="a",
      provider_name="Provider A",
      provider_type=Some("codex"),
      settings_config=Some({ "model": Json::string("gpt-5") }.to_json()),
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="b",
      provider_name="Provider B",
    ),
  )
  router.set_failover_queue("codex", ["b"])
  json_inspect(router.failover_queue_json("codex"), content=[
    { "providerId": "b", "providerName": "Provider B", "sortIndex": 0 },
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
  assert_eq(provider["inFailoverQueue"], Json::boolean(false))
  guard provider["settingsConfig"] is Object(settings) else {
    fail("expected settingsConfig")
  }
  assert_eq(settings["model"], Json::string("gpt-5"))
}

///|
test "provider router add remove failover queue mirrors ccs semantics" {
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
    { "providerId": "a", "providerName": "Provider A", "sortIndex": 0 },
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
test "provider router ccs auto failover enable seeds empty queue" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="current",
      provider_name="Current Provider",
    ),
  )
  router.set_current_provider("codex", "current")
  assert_true(router.set_auto_failover_ccs("codex", true))
  assert_true(router.auto_failover_enabled_for_app("codex"))
  json_inspect(router.failover_queue_json("codex"), content=[
    {
      "providerId": "current",
      "providerName": "Current Provider",
      "sortIndex": 0,
    },
  ])
  assert_true(router.set_auto_failover_ccs("codex", false))
  assert_false(router.auto_failover_enabled_for_app("codex"))
  assert_false(router.set_auto_failover_ccs("unknown", true))
}

///|
test "provider router exposes ccs provider map and current id" {
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
  guard router.providers_ccs_json("codex") is Object(providers) else {
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
test "provider router delete provider updates current and queue" {
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
    { "providerId": "b", "providerName": "Provider B", "sortIndex": 0 },
  ])
  assert_false(router.delete_provider("claude", "missing"))
}

///|
test "provider router remove live config preserves stored provider" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="gemini",
      provider_id="a",
      provider_name="Provider A",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="gemini",
      provider_id="b",
      provider_name="Provider B",
    ),
  )
  router.set_current_provider("gemini", "a")
  router.set_failover_queue("gemini", ["a"])
  assert_true(router.remove_provider_from_live_config("gemini", "a"))
  assert_eq(router.current_provider_id("gemini"), Some("b"))
  guard router.providers_ccs_json("gemini") is Object(providers) else {
    fail("expected providers object")
  }
  assert_true(providers.get("a") is Some(_))
  json_inspect(router.failover_queue_json("gemini"), content=[])
}

///|
test "provider router custom endpoints mirror ccs metadata semantics" {
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
test "provider router mirrors ccs live settings and sort updates" {
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
  guard router.providers_ccs_json("codex") is Object(providers) else {
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
test "provider router syncs current live providers with ccs sort order" {
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
  guard router.providers_ccs_json("codex") is Object(codex_providers) else {
    fail("expected codex providers")
  }
  guard codex_providers["universal-codex-u1"] is Object(codex_provider) else {
    fail("expected synced codex provider")
  }
  assert_eq(codex_provider["name"], Json::string("Universal One"))
  guard codex_provider["settingsConfig"] is Object(settings) else {
    fail("expected settings config")
  }
  assert_eq(settings["apiKey"], Json::string("sk-u1"))
  guard settings["models"] is Object(codex_models) else {
    fail("expected codex models")
  }
  assert_eq(codex_models["model"], Json::string("gpt-5"))
  assert_eq(router.import_live_providers("codex"), 1)
  assert_true(router.delete_universal_provider("u1"))
  json_inspect(router.universal_providers_json(), content={})
  json_inspect(router.live_provider_ids_json("codex"), content=[])
}
