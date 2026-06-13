///|
test "claude desktop model list matches ccs response shape" {
  json_inspect(claude_desktop_model_list_json(), content={
    "data": [
      {
        "type": "model",
        "id": "claude-sonnet-4-6",
        "created_at": "2024-01-01T00:00:00Z",
        "supports1m": true,
      },
      {
        "type": "model",
        "id": "claude-opus-4-8",
        "created_at": "2024-01-01T00:00:00Z",
        "supports1m": true,
      },
      {
        "type": "model",
        "id": "claude-haiku-4-5",
        "created_at": "2024-01-01T00:00:00Z",
        "supports1m": true,
      },
    ],
    "has_more": false,
    "first_id": "claude-sonnet-4-6",
    "last_id": "claude-haiku-4-5",
  })
}

///|
test "codex compact responses keep compact backend endpoint" {
  assert_eq(
    codex_backend_responses_endpoint(false),
    "/backend-api/codex/responses",
  )
  assert_eq(
    codex_backend_responses_endpoint(true),
    "/backend-api/codex/responses/compact",
  )
}

///|
test "gemini model extraction trims ccs query and action suffixes" {
  assert_eq(
    gemini_model_from_endpoint(
      "/v1beta/models/gemini-pro:generateContent?key=abc",
    ),
    "gemini-pro",
  )
  assert_eq(
    gemini_model_from_endpoint("/gemini/v1beta/models/gemini-2.0-flash?key=abc"),
    "gemini-2.0-flash",
  )
  assert_eq(
    gemini_model_from_endpoint(
      "/gemini/v1beta/models/gemini-2.0-flash:countTokens",
    ),
    "gemini-2.0-flash",
  )
  assert_eq(gemini_model_from_endpoint("/v1beta/models"), "unknown")
  assert_eq(gemini_model_from_endpoint("/v1beta/operations"), "unknown")
}

///|
test "usage request detail route extracts ccs request id" {
  assert_eq(usage_request_detail_id("/usage/request-detail/req_123"), "req_123")
  assert_eq(usage_request_detail_id("req_123"), "req_123")
  assert_eq(
    usage_request_detail_id("/usage/request-detail/session%3Amsg_1?ignored=1"),
    "session:msg_1",
  )
}

///|
test "usage query helpers parse ccs trend parameters" {
  let path = "/usage/trends?start_date=10&endDate=20&app_type=codex"
  assert_eq(usage_query_int_any(path, "start_date", "startDate"), Some(10))
  assert_eq(usage_query_int_any(path, "end_date", "endDate"), Some(20))
  assert_eq(usage_query_value_any(path, "app_type", "appType"), Some("codex"))
  assert_eq(usage_query_value(path, "missing"), None)
  assert_eq(
    usage_query_int_any(
      "/usage/trends?start_date=bad", "start_date", "startDate",
    ),
    None,
  )
}

///|
test "usage query helpers parse ccs provider limit parameters" {
  let path = "/usage/provider-limits?providerId=codex-oauth&appType=codex&dailyLimitUsd=0.10&monthly_limit_usd=1.25"
  assert_eq(
    usage_query_value_any(path, "provider_id", "providerId"),
    Some("codex-oauth"),
  )
  assert_eq(usage_query_value_any(path, "app_type", "appType"), Some("codex"))
  assert_eq(
    usage_query_value_any(path, "daily_limit_usd", "dailyLimitUsd"),
    Some("0.10"),
  )
  assert_eq(
    usage_query_value_any(path, "monthly_limit_usd", "monthlyLimitUsd"),
    Some("1.25"),
  )
}

///|
test "usage query helpers parse ccs auto failover boolean parameters" {
  assert_eq(
    usage_query_bool_any(
      "/proxy/auto-failover-enabled?appType=codex&enabled=true", "enabled", "enabled",
    ),
    Some(true),
  )
  assert_eq(
    usage_query_bool_any(
      "/proxy/auto-failover-enabled?app_type=codex&enabled=0", "enabled", "enabled",
    ),
    Some(false),
  )
  assert_eq(
    usage_query_bool_any(
      "/proxy/auto-failover-enabled?enabled=maybe", "enabled", "enabled",
    ),
    None,
  )
}

///|
test "ccs settings defaults mirror desktop command payloads" {
  guard ccs_default_app_settings_json() is Object(settings) else {
    fail("expected settings object")
  }
  assert_eq(proxy_json_bool(settings, "showInTray"), Some(true))
  assert_eq(proxy_json_bool(settings, "launchOnStartup"), Some(false))
  assert_eq(json_string_from_map(settings, "skillSyncMethod"), Some("auto"))

  guard ccs_default_rectifier_config_json() is Object(rectifier) else {
    fail("expected rectifier object")
  }
  assert_eq(proxy_json_bool(rectifier, "enabled"), Some(true))
  assert_eq(proxy_json_bool(rectifier, "requestThinkingBudget"), Some(true))

  guard ccs_default_optimizer_config_json() is Object(optimizer) else {
    fail("expected optimizer object")
  }
  assert_eq(proxy_json_bool(optimizer, "enabled"), Some(false))
  assert_eq(json_string_from_map(optimizer, "cacheTtl"), Some("1h"))

  guard ccs_default_copilot_optimizer_config_json() is Object(copilot) else {
    fail("expected copilot object")
  }
  assert_eq(proxy_json_bool(copilot, "warmupDowngrade"), Some(true))
  assert_eq(json_string_from_map(copilot, "warmupModel"), Some("gpt-5-mini"))
}

///|
test "ccs save settings merge preserves omitted sync secrets" {
  let existing = {
    "webdavSync": {
      "baseUrl": Json::string("https://dav.example.com"),
      "username": Json::string("alice"),
      "password": Json::string("secret"),
    }.to_json(),
    "s3Sync": {
      "bucket": Json::string("bucket"),
      "secretAccessKey": Json::string("s3-secret"),
    }.to_json(),
    "localMigrations": {
      "codexProviderTemplateV1": {
        "completedAt": Json::string("2026-01-01T00:00:00Z"),
      }.to_json(),
    }.to_json(),
  }.to_json()
  let incoming = {
    "webdavSync": {
      "baseUrl": Json::string("https://dav.example.com"),
      "username": Json::string("alice"),
      "password": Json::string(""),
    }.to_json(),
    "s3Sync": {
      "bucket": Json::string("bucket"),
      "secretAccessKey": Json::string(""),
    }.to_json(),
  }.to_json()
  guard ccs_merge_settings_for_save(incoming, existing) is Object(merged) else {
    fail("expected merged settings")
  }
  guard merged.get("webdavSync") is Some(Object(webdav)) else {
    fail("expected webdav sync")
  }
  assert_eq(json_string_from_map(webdav, "password"), Some("secret"))
  guard merged.get("s3Sync") is Some(Object(s3)) else {
    fail("expected s3 sync")
  }
  assert_eq(json_string_from_map(s3, "secretAccessKey"), Some("s3-secret"))
  assert_true(merged.get("localMigrations") is Some(_))
}

///|
test "ccs settings config query builders update defaults" {
  guard ccs_rectifier_config_from_request(
      "/set_rectifier_config?requestThinkingSignature=false",
      None,
      ccs_default_rectifier_config_json(),
    )
    is Object(rectifier) else {
    fail("expected rectifier")
  }
  assert_eq(proxy_json_bool(rectifier, "requestThinkingSignature"), Some(false))

  let optimizer = ccs_optimizer_config_from_request(
    "/set_optimizer_config?enabled=true&cacheTtl=5m",
    None,
    ccs_default_optimizer_config_json(),
  )
  assert_true(ccs_optimizer_cache_ttl_valid(optimizer))
  let invalid = ccs_optimizer_config_from_request(
    "/set_optimizer_config?cacheTtl=30m",
    None,
    ccs_default_optimizer_config_json(),
  )
  assert_false(ccs_optimizer_cache_ttl_valid(invalid))
}

///|
test "ccs claude plugin detection matches managed primary api key" {
  assert_true(ccs_json_primary_api_key_any("{\"primaryApiKey\":\"any\"}"))
  assert_false(ccs_json_primary_api_key_any("{\"primaryApiKey\":\"real\"}"))
  assert_false(ccs_json_primary_api_key_any("not-json"))
}

///|
test "ccs workspace filename validators mirror OpenClaw whitelist" {
  assert_true(ccs_validate_workspace_filename("AGENTS.md"))
  assert_true(ccs_validate_workspace_filename("BOOTSTRAP.md"))
  assert_false(ccs_validate_workspace_filename("../AGENTS.md"))
  assert_false(ccs_validate_workspace_filename("notes.md"))

  assert_true(ccs_validate_daily_memory_filename("2026-06-14.md"))
  assert_false(ccs_validate_daily_memory_filename("2026-6-14.md"))
  assert_false(ccs_validate_daily_memory_filename("../2026-06-14.md"))
  assert_eq(ccs_daily_memory_date("2026-06-14.md"), "2026-06-14")
}

///|
test "ccs daily memory search helpers count and snippet matches" {
  let (count, first) = ccs_count_case_insensitive_matches(
    "Plan today. plan tomorrow. PLAN later.", "plan",
  )
  assert_eq(count, 3)
  assert_eq(first, Some(0))
  assert_eq(
    ccs_search_snippet("abcdefghijklmnopqrstuvwxyz", 10),
    "abcdefghijklmnopqrstuvwxyz",
  )
}

///|
test "provider command helpers parse ccs sort and endpoint test payloads" {
  let updates = provider_sort_updates_from_request(
    "/update_providers_sort_order?app=codex&id=custom&sortIndex=2",
    None,
  )
  assert_eq(updates.length(), 1)
  assert_eq(updates[0].id, "custom")
  assert_eq(updates[0].sort_index, 2)

  let body_updates = provider_sort_updates_from_request(
    "/update_providers_sort_order",
    Some(
      {
        "updates": Json::array([
          { "id": Json::string("b"), "sortIndex": Json::number(0.0) }.to_json(),
          { "id": Json::string("a"), "sort_index": Json::number(1.0) }.to_json(),
        ]),
      }.to_json(),
    ),
  )
  assert_eq(body_updates.length(), 2)
  assert_eq(body_updates[0].id, "b")
  assert_eq(body_updates[1].sort_index, 1)

  json_inspect(
    provider_endpoint_latency_results_json(
      provider_endpoint_urls_from_request(
        "/test_api_endpoints?urls=https%3A%2F%2Fapi.example.com%2Fv1,not-a-url",
        None,
      ),
      8,
    ),
    content=[
      {
        "url": "https://api.example.com/v1",
        "latency": 0,
        "status": 200,
        "error": null,
      },
      {
        "url": "not-a-url",
        "latency": null,
        "status": null,
        "error": "URL 无效",
      },
    ],
  )
}

///|
test "universal provider helper builds ccs provider shape from query args" {
  guard universal_provider_from_request(
      "/upsert_universal_provider?id=u%201&name=Universal+One&providerType=openai-compatible&apps=claude,codex&baseUrl=https%3A%2F%2Fapi.example.com%2Fv1&apiKey=sk-test&codexModel=gpt-5&reasoningEffort=medium",
      None,
    )
    is Some(provider) else {
    fail("expected provider")
  }
  json_inspect(provider, content={
    "id": "u 1",
    "name": "Universal One",
    "providerType": "openai-compatible",
    "apps": { "claude": true, "codex": true, "gemini": false },
    "models": { "codex": { "model": "gpt-5", "reasoningEffort": "medium" } },
    "baseUrl": "https://api.example.com/v1",
    "apiKey": "sk-test",
  })
  guard universal_provider_from_request(
      "/upsert_universal_provider",
      Some(
        {
          "provider": {
            "id": Json::string("wrapped"),
            "name": Json::string("Wrapped"),
          }.to_json(),
        }.to_json(),
      ),
    )
    is Some(wrapped_provider) else {
    fail("expected wrapped provider")
  }
  json_inspect(wrapped_provider, content={ "id": "wrapped", "name": "Wrapped" })
}

///|
test "usage query helpers parse ccs request log parameters" {
  let path = "/usage/logs?page=2&pageSize=25&appType=codex&providerName=Codex+OAuth&model=anthropic%2Fclaude-sonnet-4.5&statusCode=200&startDate=10&end_date=20"
  assert_eq(usage_query_int(path, "page"), Some(2))
  assert_eq(usage_query_int_any(path, "page_size", "pageSize"), Some(25))
  assert_eq(usage_query_value_any(path, "app_type", "appType"), Some("codex"))
  assert_eq(
    usage_query_value_any(path, "provider_name", "providerName"),
    Some("Codex OAuth"),
  )
  assert_eq(
    usage_query_value(path, "model"),
    Some("anthropic/claude-sonnet-4.5"),
  )
  assert_eq(usage_query_int_any(path, "status_code", "statusCode"), Some(200))
  assert_eq(usage_query_int_any(path, "start_date", "startDate"), Some(10))
  assert_eq(usage_query_int_any(path, "end_date", "endDate"), Some(20))
}

///|
test "provider selection errors use ccs proxy error codes" {
  assert_eq(
    provider_selection_error_status(AllProvidersCircuitOpen),
    @status.ServiceUnavailable,
  )
  assert_eq(
    provider_selection_error_code(AllProvidersCircuitOpen),
    "cc_switch_all_providers_circuit_open",
  )
  guard provider_selection_error_json(AllProvidersCircuitOpen, "codex")
    is Object(body) else {
    fail("expected provider selection error body")
  }
  guard body["error"] is Object(error) else { fail("expected error object") }
  assert_eq(error["code"], Json::string("cc_switch_all_providers_circuit_open"))
  assert_eq(error["type"], Json::string("proxy_error"))
  assert_eq(error["param"], Json::null())
  assert_eq(error["app_type"], Json::string("codex"))
  assert_eq(
    error["selection_error"],
    Json::string("all_providers_circuit_open"),
  )
  assert_true(
    provider_selection_error_message(AllProvidersCircuitOpen, "codex").contains(
      "all provider circuits are open",
    ),
  )
}

///|
test "proxy config alias matches ccs default shape" {
  let gateway = Gateway::new(port=17001, host="127.0.0.2", model="gpt-5")
  guard gateway.proxy_config_json() is Object(config) else {
    fail("expected proxy config object")
  }
  assert_eq(config["listen_address"], Json::string("127.0.0.2"))
  assert_eq(config["listen_port"], Json::number(17001.0))
  assert_eq(config["max_retries"], Json::number(3.0))
  assert_eq(config["request_timeout"], Json::number(600.0))
  assert_eq(config["enable_logging"], Json::boolean(true))
  assert_eq(config["live_takeover_active"], Json::boolean(false))
  assert_eq(config["streaming_first_byte_timeout"], Json::number(60.0))
  assert_eq(config["streaming_idle_timeout"], Json::number(120.0))
  assert_eq(config["non_streaming_timeout"], Json::number(600.0))
}

///|
test "proxy global config alias matches ccs v3 shape" {
  let gateway = Gateway::new(port=17004, host="127.0.0.5", model="gpt-5")
  guard gateway.proxy_global_config_json() is Object(config) else {
    fail("expected proxy global config object")
  }
  assert_eq(config["proxyEnabled"], Json::boolean(true))
  assert_eq(config["listenAddress"], Json::string("127.0.0.5"))
  assert_eq(config["listenPort"], Json::number(17004.0))
  assert_eq(config["enableLogging"], Json::boolean(true))
}

///|
test "global proxy url helpers use ccs response shapes" {
  assert_true(upstream_proxy_url_is_valid("http://127.0.0.1:7890"))
  assert_true(upstream_proxy_url_is_valid("socks5://127.0.0.1:1080"))
  assert_false(upstream_proxy_url_is_valid("ftp://127.0.0.1:21"))
  json_inspect(proxy_test_result_json(""), content={
    "success": false,
    "latencyMs": 0,
    "error": "Proxy URL is empty",
  })
  json_inspect(proxy_test_result_json("ftp://127.0.0.1:21"), content={
    "success": false,
    "latencyMs": 0,
    "error": "Invalid proxy URL",
  })
  json_inspect(proxy_test_result_json("http://127.0.0.1:7890"), content={
    "success": true,
    "latencyMs": 0,
    "error": null,
  })
}

///|
test "suite config helpers mirror ccs openclaw hermes shapes" {
  json_inspect(openclaw_default_tools_json(), content={
    "allow": [],
    "deny": [],
  })
  json_inspect(
    openclaw_default_model_from_request(
      "/set_openclaw_default_model?primary=gpt-5&fallbacks=sonnet%2Copus",
      None,
    ).unwrap(),
    content={ "primary": "gpt-5", "fallbacks": ["sonnet", "opus"] },
  )
  json_inspect(
    suite_object_request(
      "/set_openclaw_model_catalog?catalog=%7B%22fast%22%3A%7B%22alias%22%3A%22f%22%7D%7D",
      None,
      "catalog",
    ).unwrap(),
    content={ "fast": { "alias": "f" } },
  )
  json_inspect(
    hermes_memory_limits_json(Map([("memory", false), ("user", true)])),
    content={
      "memory": 2200,
      "user": 1375,
      "memoryEnabled": false,
      "userEnabled": true,
    },
  )
  assert_eq(
    hermes_memory_kind_from_request("/get_hermes_memory?kind=user", None),
    Some("user"),
  )
  assert_eq(
    hermes_memory_kind_from_request("/get_hermes_memory?kind=bad", None),
    None,
  )
}

///|
test "proxy app config alias matches ccs app config shape" {
  let gateway = Gateway::new(port=17005, host="127.0.0.6", model="gpt-5")
  guard gateway.proxy_app_config_json("claude") is Object(config) else {
    fail("expected proxy app config object")
  }
  assert_eq(config["appType"], Json::string("claude"))
  assert_eq(config["enabled"], Json::boolean(true))
  assert_eq(config["autoFailoverEnabled"], Json::boolean(false))
  assert_eq(config["maxRetries"], Json::number(3.0))
  assert_eq(config["streamingFirstByteTimeout"], Json::number(60.0))
  assert_eq(config["streamingIdleTimeout"], Json::number(120.0))
  assert_eq(config["nonStreamingTimeout"], Json::number(600.0))
  assert_eq(config["circuitFailureThreshold"], Json::number(4.0))
  assert_eq(config["circuitSuccessThreshold"], Json::number(2.0))
  assert_eq(config["circuitTimeoutSeconds"], Json::number(60.0))
  assert_eq(config["circuitErrorRateThreshold"], Json::number(0.6))
  assert_eq(config["circuitMinRequests"], Json::number(10.0))
  guard gateway.proxy_app_config_json("unknown") is Object(unknown) else {
    fail("expected unknown proxy app config object")
  }
  assert_eq(unknown["enabled"], Json::boolean(false))
}

///|
test "proxy global config state updates ccs config shapes" {
  let gateway = Gateway::new(port=17006, host="127.0.0.7", model="gpt-5")
  gateway.proxy_enabled = false
  gateway.proxy_listen_address = "127.0.0.8"
  gateway.proxy_listen_port = 17007
  gateway.proxy_enable_logging = false
  gateway.proxy_takeover_enabled.set("codex", true)
  guard gateway.proxy_global_config_json() is Object(global_config) else {
    fail("expected global config object")
  }
  assert_eq(global_config["proxyEnabled"], Json::boolean(false))
  assert_eq(global_config["listenAddress"], Json::string("127.0.0.8"))
  assert_eq(global_config["listenPort"], Json::number(17007.0))
  assert_eq(global_config["enableLogging"], Json::boolean(false))
  guard gateway.proxy_config_json() is Object(legacy_config) else {
    fail("expected legacy config object")
  }
  assert_eq(legacy_config["listen_address"], Json::string("127.0.0.8"))
  assert_eq(legacy_config["listen_port"], Json::number(17007.0))
  assert_eq(legacy_config["enable_logging"], Json::boolean(false))
  assert_eq(legacy_config["live_takeover_active"], Json::boolean(true))
  guard gateway.proxy_takeover_status_json() is Object(takeover) else {
    fail("expected takeover object")
  }
  assert_eq(takeover["codex"], Json::boolean(true))
  assert_eq(takeover["claude"], Json::boolean(false))
}

///|
test "proxy lifecycle state matches ccs command aliases" {
  let gateway = Gateway::new(port=17016, host="127.0.0.16", model="gpt-5")
  gateway.proxy_enabled = false
  guard gateway.proxy_server_info_json() is Object(server_info) else {
    fail("expected server info")
  }
  assert_eq(server_info["address"], Json::string("127.0.0.16"))
  assert_eq(server_info["port"], Json::number(17016.0))
  gateway.proxy_takeover_enabled.set("codex", true)
  assert_true(gateway.proxy_takeover_active())
  gateway.proxy_clear_takeover()
  assert_false(gateway.proxy_takeover_active())
}

///|
test "proxy app config state updates ccs app fields" {
  let gateway = Gateway::new(port=17008, host="127.0.0.9", model="gpt-5")
  gateway.proxy_app_enabled.set("codex", false)
  gateway.provider_router.set_max_retries("codex", 5)
  gateway.proxy_streaming_first_byte_timeout.set("codex", 11)
  gateway.proxy_streaming_idle_timeout.set("codex", 22)
  gateway.proxy_non_streaming_timeout.set("codex", 33)
  gateway.provider_router.update_all_configs({
    failure_threshold: 7,
    success_threshold: 3,
    timeout_seconds: 44,
    error_rate_threshold: 0.4,
    min_requests: 12,
  })
  guard gateway.proxy_app_config_json("codex") is Object(config) else {
    fail("expected app config object")
  }
  assert_eq(config["enabled"], Json::boolean(false))
  assert_eq(config["maxRetries"], Json::number(5.0))
  assert_eq(config["streamingFirstByteTimeout"], Json::number(11.0))
  assert_eq(config["streamingIdleTimeout"], Json::number(22.0))
  assert_eq(config["nonStreamingTimeout"], Json::number(33.0))
  assert_eq(config["circuitFailureThreshold"], Json::number(7.0))
  assert_eq(config["circuitSuccessThreshold"], Json::number(3.0))
  assert_eq(config["circuitTimeoutSeconds"], Json::number(44.0))
  assert_eq(config["circuitErrorRateThreshold"], Json::number(0.4))
  assert_eq(config["circuitMinRequests"], Json::number(12.0))
}

///|
test "stream check config accepts ccs camelCase body and query fields" {
  let config = stream_check_config_from_request(
    "/save_stream_check_config?geminiModel=gemini-test&testPrompt=Ping",
    (
      #|{"config":{"timeoutSecs":30,"maxRetries":1,"degradedThresholdMs":5000,"claudeModel":"claude-test","codexModel":"codex-test"}}
    ),
    StreamCheckConfig::default(),
  )
  guard config is Some(config) else { fail("expected stream check config") }
  assert_eq(config.timeout_secs, 30)
  assert_eq(config.max_retries, 1)
  assert_eq(config.degraded_threshold_ms, 5000)
  assert_eq(config.claude_model, "claude-test")
  assert_eq(config.codex_model, "codex-test")
  assert_eq(config.gemini_model, "gemini-test")
  assert_eq(config.test_prompt, "Ping")
  assert_true(
    stream_check_config_from_request(
      "/save_stream_check_config?timeoutSecs=0",
      "",
      StreamCheckConfig::default(),
    )
    is None,
  )
}

///|
test "stream check result uses ccs camelCase shape" {
  let gateway = Gateway::new(port=17017, host="127.0.0.17", model="gpt-5")
  gateway.stream_check_config = {
    ..gateway.stream_check_config,
    codex_model: "codex-check-model",
  }
  guard gateway.stream_check_provider_result_json("codex", "codex-oauth")
    is Some(Object(result)) else {
    fail("expected stream check result")
  }
  assert_eq(result["status"], Json::string("operational"))
  assert_eq(result["success"], Json::boolean(true))
  assert_eq(result["message"], Json::string("Check succeeded"))
  assert_eq(result["modelUsed"], Json::string("codex-check-model"))
  assert_eq(result["retryCount"], Json::number(0.0))
  assert_eq(result["httpStatus"], Json::number(200.0))
  guard result.get("testedAt") is Some(Number(_)) else {
    fail("expected testedAt")
  }
}

///|
test "stream check all provider ids follow ccs proxy target filter" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="b",
      provider_name="B",
      base_url=Some("https://b.example.com"),
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="a",
      provider_name="A",
      base_url=Some("https://a.example.com"),
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="c",
      provider_name="C",
      base_url=Some("https://c.example.com"),
    ),
  )
  router.set_current_provider("codex", "b")
  router.set_failover_queue("codex", ["c", "b"])
  assert_eq(router.stream_check_provider_ids("codex", false), ["a", "b", "c"])
  assert_eq(router.stream_check_provider_ids("codex", true), ["b", "c"])
}

///|
test "proxy config request parsers accept ccs camelCase and query aliases" {
  let config = Some(
    {
      "proxyEnabled": Json::boolean(false),
      "listenAddress": Json::string("127.0.0.10"),
      "listenPort": Json::number(17010.0),
      "enableLogging": Json::string("off"),
      "maxRetries": Json::string("6"),
      "errorRateThreshold": Json::number(0.35),
    }.to_json(),
  )
  assert_eq(
    proxy_bool_request("/proxy/global-config", config, ["proxyEnabled"]),
    Some(false),
  )
  assert_eq(
    proxy_string_request("/proxy/global-config", config, ["listenAddress"]),
    Some("127.0.0.10"),
  )
  assert_eq(
    proxy_int_request("/proxy/global-config", config, ["listenPort"]),
    Some(17010),
  )
  assert_eq(
    proxy_bool_request("/proxy/global-config", config, ["enableLogging"]),
    Some(false),
  )
  assert_eq(
    proxy_int_request("/proxy/app-config", config, ["maxRetries"]),
    Some(6),
  )
  assert_eq(
    proxy_double_request("/proxy/app-config", config, ["errorRateThreshold"]),
    Some(0.35),
  )
  assert_eq(
    proxy_bool_request("/proxy/takeover-status?enabled=yes", None, ["enabled"]),
    Some(true),
  )
}

///|
test "proxy circuit config request parser merges partial app config" {
  let current = CircuitBreakerConfig::default()
  let next = proxy_circuit_config_from_request(
    "/proxy/app-config?failureThreshold=9&errorRateThreshold=0.25",
    None,
    current,
  ).unwrap()
  assert_eq(next.failure_threshold, 9)
  assert_eq(next.success_threshold, current.success_threshold)
  assert_eq(next.error_rate_threshold, 0.25)
}

///|
test "proxy pricing config aliases use ccs env-backed defaults" {
  let cost_key = "MOONSTAT_CODEX_DEFAULT_COST_MULTIPLIER"
  let source_key = "MOONSTAT_CODEX_PRICING_MODEL_SOURCE"
  @os.unsetenv(cost_key) catch {
    _ => ()
  }
  @os.unsetenv(source_key) catch {
    _ => ()
  }
  @os.setenv(cost_key, "1.25", overwrite=true)
  @os.setenv(source_key, "request", overwrite=true)
  assert_eq(default_cost_multiplier_for_app("codex"), "1.25")
  assert_eq(default_pricing_model_source_for_app("codex"), "request")
  @os.unsetenv(cost_key) catch {
    _ => ()
  }
  @os.unsetenv(source_key) catch {
    _ => ()
  }
}

///|
test "proxy pricing config runtime overrides feed provider activation defaults" {
  let gateway = Gateway::new(port=17017, host="127.0.0.17", model="gpt-5")
  gateway.proxy_default_cost_multipliers.set("codex", "1.75")
  gateway.proxy_pricing_model_sources.set("codex", "request")
  let provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="codex-oauth",
    provider_name="Codex OAuth",
  )
  assert_eq(gateway.proxy_default_cost_multiplier_for_app("codex"), "1.75")
  assert_eq(gateway.proxy_pricing_model_source_for_app("codex"), "request")
  assert_eq(gateway.provider_cost_multiplier(provider), "1.75")
  assert_eq(gateway.provider_pricing_model_source(provider), "request")
}

///|
test "proxy circuit breaker config alias matches ccs shape" {
  let gateway = Gateway::new(port=17006, host="127.0.0.7", model="gpt-5")
  guard gateway.provider_router.circuit_config.to_json() is Object(config) else {
    fail("expected circuit config object")
  }
  assert_eq(config["failureThreshold"], Json::number(4.0))
  assert_eq(config["successThreshold"], Json::number(2.0))
  assert_eq(config["timeoutSeconds"], Json::number(60.0))
  assert_eq(config["errorRateThreshold"], Json::number(0.6))
  assert_eq(config["minRequests"], Json::number(10.0))
}

///|
test "proxy circuit breaker config update accepts ccs body and query shapes" {
  let direct = @json.parse(
    "{\"failureThreshold\":5,\"successThreshold\":3,\"timeoutSeconds\":30,\"errorRateThreshold\":0.4,\"minRequests\":12}",
  )
  guard circuit_breaker_config_from_json(direct) is Some(config) else {
    fail("expected direct ccs circuit config")
  }
  assert_eq(config.failure_threshold, 5)
  assert_eq(config.success_threshold, 3)
  assert_eq(config.timeout_seconds, 30)
  assert_eq(config.error_rate_threshold, 0.4)
  assert_eq(config.min_requests, 12)

  let wrapped = @json.parse(
    "{\"config\":{\"failureThreshold\":6,\"successThreshold\":2,\"timeoutSeconds\":0,\"errorRateThreshold\":0.75,\"minRequests\":20}}",
  )
  guard circuit_breaker_config_from_json(wrapped) is Some(wrapped_config) else {
    fail("expected wrapped ccs circuit config")
  }
  assert_eq(wrapped_config.failure_threshold, 6)
  assert_eq(wrapped_config.timeout_seconds, 0)
  assert_eq(wrapped_config.error_rate_threshold, 0.75)

  let path = "/proxy/circuit-breaker-config?failureThreshold=7&successThreshold=4&timeoutSeconds=45&errorRateThreshold=0.25&minRequests=15"
  guard proxy_circuit_config_from_query(path) is Some(query_config) else {
    fail("expected query circuit config")
  }
  assert_eq(query_config.failure_threshold, 7)
  assert_eq(query_config.success_threshold, 4)
  assert_eq(query_config.timeout_seconds, 45)
  assert_eq(query_config.error_rate_threshold, 0.25)
  assert_eq(query_config.min_requests, 15)

  assert_true(
    circuit_breaker_config_from_json(
      @json.parse(
        "{\"failureThreshold\":0,\"successThreshold\":3,\"timeoutSeconds\":30,\"errorRateThreshold\":0.4,\"minRequests\":12}",
      ),
    )
    is None,
  )
}

///|
test "proxy circuit breaker config update hot applies to existing breakers" {
  let router = ProviderRouter::new()
  for _ in 0..<3 {
    router.record_result("codex-oauth", "claude", false, false, now_ms=1000)
  }
  router.update_all_configs({
    failure_threshold: 5,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 1.0,
    min_requests: 10,
  })
  router.record_result("codex-oauth", "claude", false, false, now_ms=1000)
  guard router.get_circuit_breaker_stats("codex-oauth", "claude")
    is Some(after_four) else {
    fail("expected stats after four failures")
  }
  assert_true(after_four.state == Closed)
  assert_eq(after_four.consecutive_failures, 4)

  router.record_result("codex-oauth", "claude", false, false, now_ms=1000)
  guard router.get_circuit_breaker_stats("codex-oauth", "claude")
    is Some(after_five) else {
    fail("expected stats after five failures")
  }
  assert_true(after_five.state == Open)
}

///|
test "proxy provider health alias mirrors circuit breaker state" {
  let gateway = Gateway::new(port=17007, host="127.0.0.8", model="gpt-5")
  guard gateway.provider_router.provider_health_json(
      "codex-oauth", "claude", "test-time",
    )
    is Object(healthy) else {
    fail("expected default provider health object")
  }
  assert_eq(healthy["provider_id"], Json::string("codex-oauth"))
  assert_eq(healthy["app_type"], Json::string("claude"))
  assert_eq(healthy["is_healthy"], Json::boolean(true))
  assert_eq(healthy["consecutive_failures"], Json::number(0.0))
  assert_eq(healthy["last_error"], Json::null())
  assert_eq(healthy["updated_at"], Json::string("test-time"))

  for _ in 0..<4 {
    gateway.provider_router.record_result(
      "codex-oauth",
      "claude",
      false,
      false,
      now_ms=1000,
    )
  }
  guard gateway.provider_router.provider_health_json(
      "codex-oauth", "claude", "test-time",
    )
    is Object(open) else {
    fail("expected open provider health object")
  }
  assert_eq(open["is_healthy"], Json::boolean(false))
  assert_eq(open["last_error"], Json::string("circuit_open"))
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "claude",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Open)
  assert_eq(stats.total_requests, 4)
  assert_eq(stats.failed_requests, 4)
  gateway.provider_router.reset_provider_breaker("codex-oauth", "claude")
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "claude",
    )
    is Some(reset_stats) else {
    fail("expected reset circuit stats")
  }
  assert_true(reset_stats.state == Closed)
  assert_eq(reset_stats.total_requests, 0)
  assert_eq(reset_stats.failed_requests, 0)
}

///|
test "proxy status alias matches ccs proxy status shape" {
  let gateway = Gateway::new(port=17002, host="127.0.0.3", model="gpt-5")
  gateway.stats.record_inbound(16)
  gateway.stats.record_bad_request()
  gateway.stats.set_active_target("codex", "codex-oauth", "Codex OAuth")
  gateway.stats.last_request_at = Some("test-timestamp")
  guard gateway.proxy_status_json() is Object(status) else {
    fail("expected proxy status object")
  }
  assert_eq(status["running"], Json::boolean(true))
  assert_eq(status["address"], Json::string("127.0.0.3"))
  assert_eq(status["port"], Json::number(17002.0))
  assert_eq(status["active_connections"], Json::number(0.0))
  assert_eq(status["total_requests"], Json::number(1.0))
  assert_eq(status["success_requests"], Json::number(0.0))
  assert_eq(status["failed_requests"], Json::number(1.0))
  assert_eq(status["success_rate"], Json::number(0.0))
  assert_eq(status["current_provider"], Json::string("Codex OAuth"))
  assert_eq(status["current_provider_id"], Json::string("codex-oauth"))
  assert_eq(status["last_request_at"], Json::string("test-timestamp"))
  assert_eq(status["last_error"], Json::string("bad_request"))
  assert_eq(status["failover_count"], Json::number(0.0))
  assert_true(status.get("active_targets") is Some(_))
  assert_true(status.get("provider_routes") is None)
}

///|
test "proxy takeover status alias is ccs-compatible standalone false state" {
  let gateway = Gateway::new(port=17003, host="127.0.0.4", model="gpt-5")
  json_inspect(gateway.proxy_takeover_status_json(), content={
    "claude": false,
    "claude-desktop": false,
    "codex": false,
    "gemini": false,
    "opencode": false,
    "openclaw": false,
    "hermes": false,
  })
}

///|
test "codex provider forward failures use ccs proxy error shape" {
  let provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="deepseek",
    provider_name="DeepSeek",
    provider_type=Some("codex"),
  )
  guard codex_forward_failed_error_json(
      provider, "deepseek-chat", "/responses?beta=true", "connection refused",
    )
    is Object(body) else {
    fail("expected error body")
  }
  guard body["error"] is Object(error) else { fail("expected error object") }
  assert_eq(error["type"], Json::string("proxy_error"))
  assert_eq(error["code"], Json::string("cc_switch_forward_failed"))
  assert_eq(error["param"], Json::null())
  assert_eq(error["provider"], Json::string("DeepSeek"))
  assert_eq(error["model"], Json::string("deepseek-chat"))
  assert_eq(error["endpoint"], Json::string("/responses?beta=true"))
  guard error["message"] is String(message) else { fail("expected message") }
  assert_true(message.contains("Moonstat local proxy failed"))
  assert_true(message.contains("Provider: DeepSeek"))
  assert_true(message.contains("model: deepseek-chat"))
  assert_true(message.contains("cause: Codex upstream request failed"))
}

///|
test "usage pricing query helpers parse and validate ccs pricing update" {
  let path = "/usage/model-pricing?modelId=test-model&displayName=Test%20Model&inputCost=1.25&outputCost=2&cacheReadCost=0.10&cacheCreationCost=0"
  guard usage_pricing_from_query(path) is Some(pricing) else {
    fail("expected pricing")
  }
  assert_eq(pricing.model_id, "test-model")
  assert_eq(pricing.display_name, "Test Model")
  assert_eq(pricing.input_cost_per_million, "1.25")
  assert_eq(pricing.output_cost_per_million, "2")
  assert_eq(pricing.cache_read_cost_per_million, "0.10")
  assert_eq(pricing.cache_creation_cost_per_million, "0")
  assert_true(
    usage_pricing_from_query(
      "/usage/model-pricing?modelId=test&displayName=Test&inputCost=-1&outputCost=2&cacheReadCost=0&cacheCreationCost=0",
    )
    is None,
  )
  assert_true(
    usage_pricing_from_query(
      "/usage/model-pricing?modelId=test&displayName=Test&inputCost=abc&outputCost=2&cacheReadCost=0&cacheCreationCost=0",
    )
    is None,
  )
}

///|
test "usage request detail id accepts ccs get_request_detail query" {
  assert_eq(
    usage_request_detail_id("/get_request_detail?requestId=session%3Amsg%2F1"),
    "session:msg/1",
  )
  assert_eq(
    usage_request_detail_id("/get_request_detail?request_id=req_123"),
    "req_123",
  )
}

///|
test "usage pricing store rows use ccs field names" {
  let row = model_pricing_store_json(
    mp("test-model", "Test Model", "1", "2", "0.1", "0"),
    deleted=false,
  )
  guard row is Object(obj) else { fail("expected pricing row") }
  assert_eq(obj["modelId"], Json::string("test-model"))
  assert_eq(obj["displayName"], Json::string("Test Model"))
  assert_eq(obj["inputCostPerMillion"], Json::string("1"))
  assert_eq(obj["deleted"], Json::boolean(false))
  guard model_pricing_from_store_json(obj) is Some(parsed) else {
    fail("expected parsed pricing row")
  }
  assert_eq(parsed.model_id, "test-model")
  assert_eq(parsed.cache_read_cost_per_million, "0.1")
}

///|
test "codex responses endpoints preserve request query" {
  assert_eq(
    codex_backend_responses_endpoint(
      false,
      request_path="/v1/responses?beta=true&conversation=abc",
    ),
    "/backend-api/codex/responses?beta=true&conversation=abc",
  )
  assert_eq(
    codex_backend_responses_endpoint(
      true,
      request_path="/codex/v1/responses/compact?beta=true",
    ),
    "/backend-api/codex/responses/compact?beta=true",
  )
}

///|
test "claude desktop gateway bearer token validation" {
  assert_eq(bearer_token("Bearer moon-token"), Some("moon-token"))
  assert_eq(bearer_token("bearer moon-token  "), Some("moon-token"))
  assert_eq(bearer_token("Token moon-token"), None)
  assert_true(
    claude_desktop_authorization_valid(
      { "authorization": "Bearer moon-token" },
      "moon-token",
    ),
  )
  assert_false(
    claude_desktop_authorization_valid(
      { "authorization": "Bearer wrong-token" },
      "moon-token",
    ),
  )
  assert_false(claude_desktop_authorization_valid({}, "moon-token"))
}

///|
test "claude desktop model normalization matches ccs aliases" {
  assert_eq(
    normalize_claude_desktop_model_id("claude-opus-4-7"),
    "claude-opus-4-8",
  )
  assert_eq(
    normalize_claude_desktop_model_id("claude-opus-4-8[1m]"),
    "claude-opus-4-8",
  )
  assert_eq(
    normalize_claude_desktop_model_id("claude-sonnet-4-6 [1M]"),
    "claude-sonnet-4-6",
  )
  assert_eq(
    normalize_claude_desktop_model_id("claude-haiku-4-5-20251001"),
    "claude-haiku-4-5",
  )
  assert_eq(
    normalize_claude_desktop_model_id("anthropic/claude-opus-4-8"),
    "claude-opus-4-8",
  )
  assert_eq(normalize_claude_desktop_model_id("gpt-5[1m]"), "gpt-5[1m]")
}

///|
test "claude safe model id rejects ccs unsafe ids" {
  assert_false(is_claude_safe_model_id("claude-sonnet-4-6 [1m]"))
  assert_false(is_claude_safe_model_id("claude-old"))
  assert_false(is_claude_safe_model_id("claude-3-5-sonnet-20241022"))
  assert_false(is_claude_safe_model_id("claude-deepseek-v4-pro"))
  assert_false(is_claude_safe_model_id("claude-gpt-5-4"))
  assert_false(is_claude_safe_model_id("claude-sonnet-"))
  assert_true(is_claude_safe_model_id("  claude-sonnet-4-6  "))
  assert_true(is_claude_safe_model_id("anthropic/claude-opus-4-8"))
}

///|
test "ccs session extraction uses claude metadata and headers" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "messages": [],
      #|  "metadata": {
      #|    "user_id": "user_jane_session_claude-session-1",
      #|    "session_id": "metadata-session"
      #|  }
      #|}
    ),
  )
  assert_eq(
    extract_client_session_id({}, body, "claude"),
    Some("claude-session-1"),
  )
  assert_eq(
    extract_client_session_id(
      { "x-claude-code-session-id": "header-session" },
      body,
      "claude",
    ),
    Some("header-session"),
  )
}

///|
test "ccs session extraction prefixes codex client ids" {
  let body = @json.parse(
    (
      #|{
      #|  "input": "hello",
      #|  "metadata": {
      #|    "session_id": "metadata-session-123456789"
      #|  },
      #|  "previous_response_id": "resp_should_not_be_session"
      #|}
    ),
  )
  assert_eq(
    extract_client_session_id(
      { "session_id": "12345678-1234-1234-1234-123456789012" },
      body,
      "codex",
    ),
    Some("codex_12345678-1234-1234-1234-123456789012"),
  )
  assert_eq(
    extract_client_session_id({}, body, "codex"),
    Some("codex_metadata-session-123456789"),
  )
  assert_eq(
    extract_client_session_id(
      {},
      @json.parse("{\"previous_response_id\":\"resp_only\"}"),
      "codex",
    ),
    None,
  )
}

///|
test "codex oauth headers propagate ccs session headers" {
  let creds = @codex.Credentials::{
    idToken: "id",
    accessToken: "access",
    refreshToken: "refresh",
    accountId: "account",
  }
  let headers = codex_oauth_headers(
    creds,
    "text/event-stream",
    Some("codex_session-1"),
  )
  assert_eq(headers["Authorization"], "Bearer access")
  assert_eq(headers["ChatGPT-Account-ID"], "account")
  assert_eq(headers["Accept"], "text/event-stream")
  assert_eq(headers["session_id"], "codex_session-1")
  assert_eq(headers["x-client-request-id"], "codex_session-1")
  assert_eq(headers["x-codex-window-id"], "codex_session-1")
}

///|
test "codex to anthropic response emits ccs cache usage buckets" {
  let body = @json.parse(
    (
      #|{
      #|  "id": "resp_1",
      #|  "model": "gpt-5",
      #|  "output": [
      #|    {
      #|      "type": "message",
      #|      "content": [
      #|        { "type": "output_text", "text": "done" }
      #|      ]
      #|    }
      #|  ],
      #|  "usage": {
      #|    "input_tokens": 100,
      #|    "output_tokens": 7,
      #|    "input_tokens_details": { "cached_tokens": 31 },
      #|    "cache_creation_input_tokens": 5
      #|  }
      #|}
    ),
  )
  let response = convert_codex_to_anthropic(body, "claude-sonnet-4-6")
  json_inspect(response.usage.to_json(), content={
    "input_tokens": 64,
    "output_tokens": 7,
    "cache_read_input_tokens": 31,
    "cache_creation_input_tokens": 5,
  })
}

///|
test "moonstat default provider router selects suite app targets" {
  let router = moonstat_default_provider_router()
  let codex = router.select_providers("codex", now_ms=1000)
  assert_true(codex.is_ok())
  match codex_provider_from_env() {
    Some(provider) => {
      assert_true(codex.providers.length() == 2)
      assert_true(codex.providers[0].provider_id == provider.provider_id)
      assert_true(codex.providers[0].can_use_codex_compatible_upstream())
      assert_true(codex.providers[1].provider_id == "codex-oauth")
    }
    None => {
      assert_true(codex.providers.length() == 1)
      assert_true(codex.providers[0].provider_id == "codex-oauth")
      assert_true(codex.providers[0].provider_type == Some("codex_oauth"))
    }
  }
  let gemini = router.select_providers("gemini", now_ms=1000)
  assert_true(gemini.is_ok())
  assert_eq(gemini.providers.length(), 1)
  assert_eq(gemini.providers[0].provider_id, "gemini-api-key")
  let claude = router.select_providers("claude-desktop", now_ms=1000)
  assert_true(claude.is_ok())
  assert_eq(claude.providers.length(), 1)
  assert_eq(claude.providers[0].provider_name, "Codex OAuth")
  assert_eq(claude.providers[0].provider_type, Some("codex_oauth"))
}

///|
test "claude provider env carries ccs settings config" {
  let keys = [
    "MOONSTAT_CLAUDE_BASE_URL", "MOONSTAT_CLAUDE_API_KEY", "MOONSTAT_CLAUDE_SETTINGS_CONFIG",
  ]
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
  @os.setenv("MOONSTAT_CLAUDE_BASE_URL", "https://example.test", overwrite=true)
  @os.setenv("MOONSTAT_CLAUDE_API_KEY", "secret", overwrite=true)
  @os.setenv(
    "MOONSTAT_CLAUDE_SETTINGS_CONFIG",
    (
      #|{
      #|  "modelCatalog": {
      #|    "models": [
      #|      { "model": "gpt-4o", "input": ["text"] }
      #|    ]
      #|  }
      #|}
    ),
    overwrite=true,
  )
  guard claude_provider_from_env("claude") is Some(provider) else {
    fail("expected provider")
  }
  guard provider.settings_config is Some(Object(settings)) else {
    fail("expected settings config")
  }
  assert_true(settings.get("modelCatalog") is Some(_))
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
}

///|
test "ccs default cost multiplier env falls back per app" {
  let keys = [
    "MOONSTAT_CLAUDE_DEFAULT_COST_MULTIPLIER", "MOONSTAT_DEFAULT_COST_MULTIPLIER",
  ]
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
  @os.setenv("MOONSTAT_CLAUDE_DEFAULT_COST_MULTIPLIER", "1.75", overwrite=true)
  @os.setenv("MOONSTAT_DEFAULT_COST_MULTIPLIER", "2.0", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="default-cost",
    provider_name="Default Cost",
  )
  assert_eq(
    provider_cost_multiplier_from_default(
      provider,
      default_cost_multiplier_for_app(provider.app_type),
    ),
    "1.75",
  )
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
}

///|
test "ccs provider cost multiplier overrides default env" {
  let key = "MOONSTAT_CLAUDE_DEFAULT_COST_MULTIPLIER"
  @os.unsetenv(key) catch {
    _ => ()
  }
  @os.setenv(key, "1.75", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="provider-cost",
    provider_name="Provider Cost",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "costMultiplier": "2.5" }
          #|}
        ),
      ),
    ),
  )
  assert_eq(
    provider_cost_multiplier_from_default(
      provider,
      default_cost_multiplier_for_app(provider.app_type),
    ),
    "2.5",
  )
  @os.unsetenv(key) catch {
    _ => ()
  }
}

///|
test "invalid ccs provider cost multiplier falls back to default env" {
  let key = "MOONSTAT_CLAUDE_DEFAULT_COST_MULTIPLIER"
  @os.unsetenv(key) catch {
    _ => ()
  }
  @os.setenv(key, "1.75", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="invalid-provider-cost",
    provider_name="Invalid Provider Cost",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "costMultiplier": "bad" }
          #|}
        ),
      ),
    ),
  )
  assert_eq(
    provider_cost_multiplier_from_default(
      provider,
      default_cost_multiplier_for_app(provider.app_type),
    ),
    "1.75",
  )
  @os.unsetenv(key) catch {
    _ => ()
  }
}

///|
test "ccs default pricing model source env falls back per app" {
  let keys = [
    "MOONSTAT_CLAUDE_PRICING_MODEL_SOURCE", "MOONSTAT_PRICING_MODEL_SOURCE",
  ]
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
  @os.setenv("MOONSTAT_CLAUDE_PRICING_MODEL_SOURCE", "request", overwrite=true)
  @os.setenv("MOONSTAT_PRICING_MODEL_SOURCE", "response", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="default-pricing-source",
    provider_name="Default Pricing Source",
  )
  assert_eq(
    provider_pricing_model_source_from_default(
      provider,
      default_pricing_model_source_for_app(provider.app_type),
    ),
    "request",
  )
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
}

///|
test "ccs provider pricing model source overrides default env" {
  let key = "MOONSTAT_CLAUDE_PRICING_MODEL_SOURCE"
  @os.unsetenv(key) catch {
    _ => ()
  }
  @os.setenv(key, "response", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="provider-pricing-source",
    provider_name="Provider Pricing Source",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "pricingModelSource": "request" }
          #|}
        ),
      ),
    ),
  )
  assert_eq(
    provider_pricing_model_source_from_default(
      provider,
      default_pricing_model_source_for_app(provider.app_type),
    ),
    "request",
  )
  @os.unsetenv(key) catch {
    _ => ()
  }
}

///|
test "invalid ccs provider pricing model source falls back to default env" {
  let key = "MOONSTAT_CLAUDE_PRICING_MODEL_SOURCE"
  @os.unsetenv(key) catch {
    _ => ()
  }
  @os.setenv(key, "request", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="invalid-provider-pricing-source",
    provider_name="Invalid Provider Pricing Source",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "pricingModelSource": "bad" }
          #|}
        ),
      ),
    ),
  )
  assert_eq(
    provider_pricing_model_source_from_default(
      provider,
      default_pricing_model_source_for_app(provider.app_type),
    ),
    "request",
  )
  @os.unsetenv(key) catch {
    _ => ()
  }
}

///|
test "gateway records upstream failures into provider router before finish" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.stats.record_inbound(10)
  let _ = gateway.activate_provider("codex")
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.record_provider_result(false)
  gateway.stats.record_upstream_error_status(0, 502)
  assert_eq(gateway.stats.current_request_app_type, None)
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Open)
  assert_eq(stats.total_requests, 1)
  assert_eq(stats.failed_requests, 1)
}

///|
test "ccs upstream status retryability matches client error bucket" {
  assert_false(ccs_upstream_status_retryable(400))
  assert_false(ccs_upstream_status_retryable(422))
  assert_false(ccs_upstream_status_retryable(501))
  assert_true(ccs_upstream_status_retryable(401))
  assert_true(ccs_upstream_status_retryable(429))
  assert_true(ccs_upstream_status_retryable(502))
}

///|
test "gateway uses ccs model mapping for upstream claude model" {
  let gateway = Gateway::new(port=0, model="gpt-default")
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="mapped",
    provider_name="Mapped",
    model_mapping=Some(
      ModelMapping::new(sonnet_model=Some("deepseek-v4-pro [1M]")),
    ),
  )
  assert_eq(
    gateway.upstream_claude_model("claude-sonnet-4-6", Some(provider)),
    "deepseek-v4-pro",
  )
  let unmapped = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="plain",
    provider_name="Plain",
  )
  assert_eq(
    gateway.upstream_claude_model("claude-sonnet-4-6", Some(unmapped)),
    "claude-sonnet-4-6",
  )
  assert_eq(
    gateway.upstream_claude_model("deepseek-v4-pro [1M]", Some(unmapped)),
    "deepseek-v4-pro",
  )
}

///|
async test "gateway applies ccs provider cost multiplier to request log" {
  let gateway = Gateway::new(port=0)
  gateway.pricing_overrides.set("test-model", ModelPricing::{
    model_id: "test-model",
    display_name: "Test Model",
    input_cost_per_million: "1.0",
    output_cost_per_million: "0",
    cache_read_cost_per_million: "0",
    cache_creation_cost_per_million: "0",
  })
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="costed",
    provider_name="Costed Provider",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "costMultiplier": "2.5" }
          #|}
        ),
      ),
    ),
  )
  gateway.stats.record_inbound(10)
  assert_true(
    gateway.activate_provider_target(
      "claude",
      provider,
      bypass_circuit_breaker=true,
    ),
  )
  gateway.stats.record_request_context("claude", "test-model")
  gateway.record_success_usage(
    TokenUsage::new(
      input_tokens=1000,
      output_tokens=0,
      model=Some("test-model"),
    ),
    64,
  )
  assert_eq(gateway.stats.request_logs.length(), 1)
  let log = gateway.stats.request_logs[0]
  assert_eq(log.cost_multiplier, "2.5")
  assert_eq(log.input_cost_usd, "0.001")
  assert_eq(log.total_cost_usd, "0.0025")
  let ccs_log = log.to_ccs_request_log_detail_json()
  guard ccs_log is Object(obj) else { fail("expected object") }
  assert_eq(obj["costMultiplier"], Json::string("2.5"))
}

///|
async test "gateway ignores invalid ccs provider cost multiplier" {
  let gateway = Gateway::new(port=0)
  gateway.pricing_overrides.set("test-model", ModelPricing::{
    model_id: "test-model",
    display_name: "Test Model",
    input_cost_per_million: "1.0",
    output_cost_per_million: "0",
    cache_read_cost_per_million: "0",
    cache_creation_cost_per_million: "0",
  })
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="invalid-cost",
    provider_name="Invalid Cost Provider",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "costMultiplier": "not-a-number" }
          #|}
        ),
      ),
    ),
  )
  gateway.stats.record_inbound(10)
  assert_true(
    gateway.activate_provider_target(
      "claude",
      provider,
      bypass_circuit_breaker=true,
    ),
  )
  gateway.stats.record_request_context("claude", "test-model")
  gateway.record_success_usage(
    TokenUsage::new(
      input_tokens=1000,
      output_tokens=0,
      model=Some("test-model"),
    ),
    64,
  )
  assert_eq(gateway.stats.request_logs.length(), 1)
  let log = gateway.stats.request_logs[0]
  assert_eq(log.cost_multiplier, "1.0")
  assert_eq(log.total_cost_usd, "0.001")
}

///|
async test "gateway applies ccs request pricing model source" {
  let gateway = Gateway::new(port=0)
  gateway.pricing_overrides.set("request-model", ModelPricing::{
    model_id: "request-model",
    display_name: "Request Model",
    input_cost_per_million: "1.0",
    output_cost_per_million: "0",
    cache_read_cost_per_million: "0",
    cache_creation_cost_per_million: "0",
  })
  gateway.pricing_overrides.set("response-model", ModelPricing::{
    model_id: "response-model",
    display_name: "Response Model",
    input_cost_per_million: "9.0",
    output_cost_per_million: "0",
    cache_read_cost_per_million: "0",
    cache_creation_cost_per_million: "0",
  })
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="request-priced",
    provider_name="Request Priced Provider",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "pricingModelSource": "request" }
          #|}
        ),
      ),
    ),
  )
  gateway.stats.record_inbound(10)
  assert_true(
    gateway.activate_provider_target(
      "claude",
      provider,
      bypass_circuit_breaker=true,
    ),
  )
  gateway.stats.record_request_context("claude", "request-model")
  gateway.record_success_usage(
    TokenUsage::new(
      input_tokens=1000,
      output_tokens=0,
      model=Some("response-model"),
    ),
    64,
  )
  assert_eq(gateway.stats.request_logs.length(), 1)
  let log = gateway.stats.request_logs[0]
  assert_eq(log.model, "response-model")
  assert_eq(log.request_model, Some("request-model"))
  assert_eq(log.pricing_model, Some("request-model"))
  assert_eq(log.total_cost_usd, "0.001")
}

///|
async test "gateway records billable ccs stream usage once" {
  let gateway = Gateway::new(port=0)
  gateway.stats.record_inbound(10)
  let _ = gateway.activate_provider("codex")
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.stats.record_stream_mode(true)
  gateway.record_success_stream_usage(
    Some(
      TokenUsage::new(
        input_tokens=10,
        output_tokens=2,
        cache_read_tokens=4,
        model=Some("gpt-5"),
      ),
    ),
    42,
  )
  assert_eq(gateway.stats.successful_responses, 1)
  assert_eq(gateway.stats.input_tokens, 10)
  assert_eq(gateway.stats.cache_read_tokens, 4)
  assert_eq(gateway.stats.request_logs.length(), 1)
  let log = gateway.stats.request_logs[0]
  assert_true(log.is_streaming)
  assert_eq(log.model, "gpt-5")
  assert_eq(log.input_tokens, 10)
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_eq(stats.total_requests, 1)
}

///|
async test "gateway skips all zero ccs stream usage request log" {
  let gateway = Gateway::new(port=0)
  gateway.stats.record_inbound(10)
  let _ = gateway.activate_provider("codex")
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.stats.record_stream_mode(true)
  gateway.record_success_stream_usage(Some(TokenUsage::empty()), 42)
  assert_eq(gateway.stats.successful_responses, 1)
  assert_eq(gateway.stats.response_bytes, 42)
  assert_eq(gateway.stats.request_logs.length(), 0)
}

///|
async test "gateway skips all zero ccs nonstream usage request log" {
  let gateway = Gateway::new(port=0)
  gateway.stats.record_inbound(10)
  let _ = gateway.activate_provider("codex")
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.stats.record_stream_mode(false)
  gateway.record_success_usage(TokenUsage::empty(), 42)
  assert_eq(gateway.stats.successful_responses, 1)
  assert_eq(gateway.stats.response_bytes, 42)
  assert_eq(gateway.stats.request_logs.length(), 0)
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_eq(stats.total_requests, 1)
}

///|
async test "gateway nonretryable upstream errors release half open permit" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 0,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  gateway.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.provider_router.set_auto_failover("codex", true)

  gateway.stats.record_inbound(10)
  let _ = gateway.activate_provider("codex")
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.record_provider_result(false)
  gateway.stats.record_upstream_error_status(0, 502)

  gateway.stats.record_inbound(10)
  let _ = gateway.activate_provider("codex")
  assert_true(gateway.stats.current_request_used_half_open_permit)
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.record_upstream_error_status(0, 400)

  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == HalfOpen)
  assert_eq(stats.total_requests, 1)
  assert_eq(stats.failed_requests, 1)

  gateway.stats.record_inbound(10)
  let third = gateway.activate_provider("codex")
  assert_true(third is Some(_))
  assert_true(gateway.stats.current_request_used_half_open_permit)
}

///|
async test "gateway streaming success records provider health before request completion" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.stats.record_inbound(16)
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.stats.record_stream_mode(true)
  let selected = gateway.activate_provider("codex")
  guard selected is Some(provider) else { fail("expected provider") }
  assert_true(provider.provider_id == "codex-oauth")

  gateway.record_provider_result(true)
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats_after_first_chunk) else {
    fail("expected circuit stats")
  }
  assert_true(stats_after_first_chunk.total_requests == 1)
  assert_true(stats_after_first_chunk.failed_requests == 0)
  assert_true(gateway.stats.successful_responses == 0)
  guard gateway.stats.current_request_id is Some(_) else {
    fail("request should remain open until stream end")
  }

  gateway.record_success_stream_usage(None, 24, record_provider=false)
  assert_true(gateway.stats.successful_responses == 1)
  assert_true(gateway.stats.response_bytes == 24)
  assert_true(gateway.stats.current_request_id is None)
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats_after_stream_end) else {
    fail("expected circuit stats")
  }
  assert_true(stats_after_stream_end.total_requests == 1)
  assert_true(stats_after_stream_end.failed_requests == 0)
}

///|
test "gateway activation skips occupied half open provider in failover chain" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 0,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  gateway.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.provider_router.set_auto_failover("codex", true)
  gateway.provider_router.record_result(
    "codex-oauth",
    "codex",
    false,
    false,
    now_ms=1000,
  )
  let occupied = gateway.provider_router.allow_provider_request(
    "codex-oauth",
    "codex",
    now_ms=1000,
  )
  assert_true(occupied.allowed)
  assert_true(occupied.used_half_open_permit)

  let selected = gateway.activate_provider("codex")
  guard selected is Some(provider) else { fail("expected fallback provider") }
  assert_eq(provider.provider_id, "codex-alt")
  assert_eq(gateway.stats.current_provider_id, Some("codex-alt"))
  assert_false(gateway.stats.current_request_used_half_open_permit)
}

///|
test "gateway activation can exclude already attempted failover providers" {
  let gateway = Gateway::new(port=0)
  let providers = [
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="primary",
      provider_name="Primary",
    ),
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="fallback",
      provider_name="Fallback",
    ),
  ]
  for provider in providers {
    gateway.provider_router.upsert_provider(provider)
  }
  gateway.provider_router.set_auto_failover("codex", true)
  let selected = gateway.activate_first_available_provider_excluding(
    "codex",
    providers,
    ["primary"],
  )
  guard selected is Some(provider) else {
    fail("expected unattempted fallback provider")
  }
  assert_eq(provider.provider_id, "fallback")
  assert_eq(gateway.stats.current_provider_id, Some("fallback"))
}

///|
test "gateway retryable upstream status activates next failover provider" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  gateway.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.provider_router.set_auto_failover("codex", true)
  let selection = gateway.provider_router.select_providers("codex", now_ms=1000)
  assert_true(selection.is_ok())
  assert_true(selection.providers.length() == 2)

  gateway.stats.record_inbound(10)
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  let first = gateway.activate_first_available_provider(
    "codex",
    selection.providers,
  )
  guard first is Some(primary) else { fail("expected primary provider") }
  assert_true(primary.provider_id == "codex-oauth")

  let attempted : Array[String] = []
  let next = gateway.activate_next_provider_after_upstream_status(
    "codex",
    selection.providers,
    attempted,
    502,
  )
  guard next is Some(fallback) else { fail("expected fallback provider") }
  assert_true(attempted.length() == 1)
  assert_true(attempted[0] == "codex-oauth")
  assert_true(fallback.provider_id == "codex-alt")
  guard gateway.stats.current_provider_id is Some(current_provider_id) else {
    fail("expected current provider id")
  }
  assert_true(current_provider_id == "codex-alt")
  guard gateway.stats.current_request_app_type is Some(current_app_type) else {
    fail("expected current request app type")
  }
  assert_true(current_app_type == "codex")
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected primary circuit stats")
  }
  assert_true(stats.state == Open)
  assert_true(stats.total_requests == 1)
  assert_true(stats.failed_requests == 1)
}

///|
test "gateway retryable upstream status respects ccs max retries cap before permits" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 0,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  gateway.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.provider_router.set_auto_failover("codex", true)
  gateway.provider_router.set_max_retries("codex", 0)
  gateway.provider_router.record_result(
    "codex-alt",
    "codex",
    false,
    false,
    now_ms=1000,
  )
  let selection = gateway.provider_router.select_providers("codex", now_ms=1000)
  assert_true(selection.is_ok())
  assert_eq(selection.providers.length(), 2)

  gateway.stats.record_inbound(10)
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  let first = gateway.activate_first_available_provider(
    "codex",
    selection.providers,
  )
  guard first is Some(primary) else { fail("expected primary provider") }
  assert_eq(primary.provider_id, "codex-oauth")

  let attempted : Array[String] = []
  let next = gateway.activate_next_provider_after_upstream_status(
    "codex",
    selection.providers,
    attempted,
    502,
  )
  assert_true(next is None)
  assert_eq(attempted.length(), 1)
  assert_eq(attempted[0], "codex-oauth")
  assert_eq(gateway.stats.current_provider_id, Some("codex-oauth"))

  let fallback_permit = gateway.provider_router.allow_provider_request(
    "codex-alt",
    "codex",
    now_ms=1000,
  )
  assert_true(fallback_permit.allowed)
  assert_true(fallback_permit.used_half_open_permit)
}

///|
test "gateway retryable final provider remains active for final upstream error" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  let selection = gateway.provider_router.select_providers("codex", now_ms=1000)
  assert_true(selection.is_ok())
  assert_true(selection.providers.length() == 1)

  gateway.stats.record_inbound(10)
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  let selected = gateway.activate_first_available_provider(
    "codex",
    selection.providers,
  )
  guard selected is Some(provider) else { fail("expected provider") }
  assert_true(provider.provider_id == "codex-oauth")

  let attempted : Array[String] = []
  let next = gateway.activate_next_provider_after_upstream_status(
    "codex",
    selection.providers,
    attempted,
    502,
  )
  assert_true(next is None)
  assert_true(attempted.length() == 1)
  assert_true(attempted[0] == "codex-oauth")
  guard gateway.stats.current_provider_id is Some(current_provider_id) else {
    fail("expected current provider id")
  }
  assert_true(current_provider_id == "codex-oauth")
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Open)
  assert_true(stats.total_requests == 1)
  assert_true(stats.failed_requests == 1)
}

///|
test "gateway nonretryable upstream status does not activate failover provider" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  gateway.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.provider_router.set_auto_failover("codex", true)
  let selection = gateway.provider_router.select_providers("codex", now_ms=1000)
  assert_true(selection.is_ok())
  assert_true(selection.providers.length() == 2)

  gateway.stats.record_inbound(10)
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  let selected = gateway.activate_first_available_provider(
    "codex",
    selection.providers,
  )
  guard selected is Some(provider) else { fail("expected provider") }
  assert_true(provider.provider_id == "codex-oauth")

  let attempted : Array[String] = []
  let next = gateway.activate_next_provider_after_upstream_status(
    "codex",
    selection.providers,
    attempted,
    400,
  )
  assert_true(next is None)
  assert_true(attempted.length() == 1)
  assert_true(attempted[0] == "codex-oauth")
  guard gateway.stats.current_provider_id is Some(current_provider_id) else {
    fail("expected current provider id")
  }
  assert_true(current_provider_id == "codex-oauth")
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Closed)
  assert_true(stats.total_requests == 0)
  assert_true(stats.failed_requests == 0)
}

///|
test "gateway activation bypasses circuit breaker for single provider" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.provider_router.record_result(
    "codex-oauth",
    "codex",
    false,
    false,
    now_ms=1000,
  )
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Open)

  let selected = gateway.activate_provider("codex")
  guard selected is Some(provider) else {
    fail("single provider should bypass circuit gating")
  }
  assert_eq(provider.provider_id, "codex-oauth")
  assert_eq(gateway.stats.current_provider_id, Some("codex-oauth"))
  assert_false(gateway.stats.current_request_used_half_open_permit)
}

///|
test "codex compatible provider url follows ccs base url rules" {
  assert_true(
    codex_compatible_provider_url("https://api.openai.com", "/responses") ==
    "https://api.openai.com/v1/responses",
  )
  assert_true(
    codex_compatible_provider_url(
      "https://api.openai.com/v1", "/v1/responses?conversation=abc",
    ) ==
    "https://api.openai.com/v1/responses?conversation=abc",
  )
  assert_true(
    codex_compatible_provider_url(
      "https://proxy.example.com/openai", "/responses",
    ) ==
    "https://proxy.example.com/openai/responses",
  )
  assert_true(
    codex_compatible_provider_url(
      "https://proxy.example.com/v1/responses", "/responses?conversation=abc",
    ) ==
    "https://proxy.example.com/v1/responses?conversation=abc",
  )
}

///|
test "claude compatible provider api format follows ccs endpoints" {
  let chat_provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="openai-chat",
    provider_name="OpenAI Chat",
    provider_type=Some("openai"),
    api_format=Some("openai_chat"),
    base_url=Some("https://api.openai.com/v1"),
    api_key=Some("sk-test"),
  )
  assert_eq(chat_provider.claude_api_format(), "openai_chat")
  assert_true(chat_provider.can_use_claude_compatible_upstream())
  assert_eq(
    claude_transform_endpoint(chat_provider.claude_api_format(), false),
    "/v1/chat/completions",
  )
  assert_eq(
    codex_compatible_provider_url(
      "https://api.openai.com/v1",
      claude_transform_endpoint(chat_provider.claude_api_format(), false),
    ),
    "https://api.openai.com/v1/chat/completions",
  )

  let responses_provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="openai-responses",
    provider_name="OpenAI Responses",
    api_format=Some("openai_responses"),
    base_url=Some("https://api.openai.com"),
    api_key=Some("sk-test"),
  )
  assert_eq(
    claude_transform_endpoint(responses_provider.claude_api_format(), false),
    "/v1/responses",
  )
  assert_eq(
    codex_compatible_provider_url(
      "https://api.openai.com",
      claude_transform_endpoint(responses_provider.claude_api_format(), false),
    ),
    "https://api.openai.com/v1/responses",
  )
}

///|
test "claude compatible provider endpoints preserve ccs query semantics" {
  assert_eq(
    claude_transform_endpoint(
      "openai_chat",
      false,
      request_path="/v1/messages?beta=true&conversation=abc",
    ),
    "/v1/chat/completions?conversation=abc",
  )
  assert_eq(
    claude_transform_endpoint(
      "openai_responses",
      false,
      request_path="/claude/v1/messages?conversation=abc&beta=true",
    ),
    "/v1/responses?conversation=abc",
  )
  assert_eq(
    claude_transform_endpoint(
      "anthropic",
      false,
      request_path="/v1/messages?beta=true",
    ),
    "/v1/messages",
  )
  assert_eq(
    claude_transform_endpoint(
      "gemini_native",
      true,
      request_path="/v1/messages?alt=json&beta=true&key=abc",
    ),
    "/v1beta/models/__MODEL__:streamGenerateContent?key=abc&alt=sse",
  )
}

///|
test "codex compatible provider detects chat completions bridge" {
  let format_provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="chat-format",
    provider_name="Chat Format",
    api_format=Some("openai_chat"),
    base_url=Some("https://api.example.com/v1"),
    api_key=Some("sk-test"),
  )
  assert_true(format_provider.codex_uses_chat_completions())
  assert_eq(
    codex_compatible_provider_url(
      "https://api.example.com/v1",
      codex_compatible_chat_completions_endpoint(
        "/backend-api/codex/responses?x=1",
      ),
    ),
    "https://api.example.com/v1/chat/completions?x=1",
  )
  let full_url_provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="chat-url",
    provider_name="Chat URL",
    base_url=Some("https://api.example.com/v1/chat/completions"),
    api_key=Some("sk-test"),
  )
  assert_true(full_url_provider.codex_uses_chat_completions())
}

///|
test "claude upstream request json rewrites mapped model" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "max_tokens": 128,
      #|  "messages": [
      #|    { "role": "user", "content": "hello" }
      #|  ]
      #|}
    ),
  )
  let upstream = claude_request_json_for_upstream(body, "gpt-5.4")
  guard upstream is Object(obj) else { fail("expected object") }
  assert_eq(obj["model"], Json::string("gpt-5.4"))
  assert_true(obj.get("messages") is Some(_))
}

///|
test "claude stream upstream request forces stream true" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "max_tokens": 128,
      #|  "stream": false,
      #|  "messages": [
      #|    { "role": "user", "content": "hello" }
      #|  ]
      #|}
    ),
  )
  let upstream = claude_stream_request_json_for_upstream(body, "gpt-5.4")
  guard upstream is Object(obj) else { fail("expected object") }
  assert_eq(obj["model"], Json::string("gpt-5.4"))
  assert_eq(obj["stream"], Json::boolean(true))
}

///|
test "ccs responses sse parser handles missing trailing blank line" {
  let sse =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_tail","status":"completed","model":"gpt-5.4","output":[],"usage":{"input_tokens":3,"output_tokens":1}}}
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_responses",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed response")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  assert_eq(obj["id"], Json::string("resp_tail"))
  assert_eq(obj["model"], Json::string("gpt-5.4"))
  guard obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(3.0))
  assert_eq(usage["output_tokens"], Json::number(1.0))
}

///|
test "ccs responses sse parser strips bom before parsing" {
  let sse = "\u{feff}event: response.completed\n" +
    "data: {\"type\":\"response.completed\",\"response\":{\"id\":\"resp_bom\",\"status\":\"completed\",\"model\":\"gpt-5.4\",\"output\":[],\"usage\":{\"input_tokens\":3,\"output_tokens\":1}}}"
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_responses",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed response")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  assert_eq(obj["id"], Json::string("resp_bom"))
}

///|
test "ccs responses stream parser accepts data field without space" {
  let block = "event:response.output_text.delta\n" +
    "data:{\"type\":\"response.output_text.delta\",\"delta\":\"hi\"}\n\n"
  let (done, parsed, event) = codex_stream_event_from_sse_block(
    block, "gpt-5.4",
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  guard event is Some(event) else { fail("expected stream event") }
  assert_eq(event.event_type, "content_block_delta")
  let data = @json.parse(event.data) catch {
    _ => fail("expected json event data")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["text"], Json::string("hi"))
}

///|
test "ccs responses stream parser skips non emitting lifecycle blocks" {
  let block =
    #|event: response.in_progress
    #|data: {"type":"response.in_progress"}
    #|
  let (done, parsed, event) = codex_stream_event_from_sse_block(
    block, "gpt-5.4",
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  assert_true(event is None)
}

///|
test "ccs responses stream parser converts response created to message start" {
  let block =
    #|event: response.created
    #|data: {"type":"response.created","response":{"id":"resp_start","status":"in_progress","model":"gpt-5.4","usage":{"input_tokens":12,"output_tokens":0,"input_tokens_details":{"cached_tokens":4}}}}
    #|
  let (done, parsed, event) = codex_stream_event_from_sse_block(
    block, "fallback-model",
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  guard event is Some(event) else { fail("expected stream event") }
  assert_eq(event.event_type, "message_start")
  let data = @json.parse(event.data) catch {
    _ => fail("expected json event data")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["message"] is Object(message) else { fail("expected message") }
  assert_eq(message["id"], Json::string("resp_start"))
  assert_eq(message["model"], Json::string("gpt-5.4"))
  guard message["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(8.0))
  assert_eq(usage["output_tokens"], Json::number(0.0))
  assert_eq(usage["cache_read_input_tokens"], Json::number(4.0))
}

///|
test "ccs responses stream parser preserves completed usage" {
  let block =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_done","status":"completed","model":"gpt-5.4","output":[],"usage":{"prompt_tokens":11,"completion_tokens":5,"prompt_tokens_details":{"cached_tokens":3}}}}
    #|
  let (done, parsed, event) = codex_stream_event_from_sse_block(
    block, "gpt-5.4",
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  guard event is Some(event) else { fail("expected stream event") }
  assert_eq(event.event_type, "message_delta")
  let data = @json.parse(event.data) catch {
    _ => fail("expected json event data")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["stop_reason"], Json::string("end_turn"))
  assert_eq(delta["stop_sequence"], Json::null())
  guard obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(8.0))
  assert_eq(usage["output_tokens"], Json::number(5.0))
  assert_eq(usage["cache_read_input_tokens"], Json::number(3.0))
}

///|
test "ccs responses stream parser maps incomplete max output to max tokens" {
  let block =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_max","status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"model":"gpt-5.4","output":[],"usage":{"input_tokens":6,"output_tokens":2}}}
    #|
  let (done, parsed, event) = codex_stream_event_from_sse_block(
    block, "gpt-5.4",
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  guard event is Some(event) else { fail("expected stream event") }
  let data = @json.parse(event.data) catch {
    _ => fail("expected json event data")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["stop_reason"], Json::string("max_tokens"))
}

///|
test "ccs responses stream parser maps completed function output to tool use" {
  let block =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_tool","status":"completed","model":"gpt-5.4","output":[{"type":"function_call","call_id":"call_1","name":"lookup","arguments":"{}"}],"usage":{"input_tokens":6,"output_tokens":2}}}
    #|
  let (done, parsed, event) = codex_stream_event_from_sse_block(
    block, "gpt-5.4",
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  guard event is Some(event) else { fail("expected stream event") }
  let data = @json.parse(event.data) catch {
    _ => fail("expected json event data")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["stop_reason"], Json::string("tool_use"))
}

///|
test "ccs responses stream state starts text block before text delta" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let block =
    #|event: response.output_text.delta
    #|data: {"type":"response.output_text.delta","delta":"hello"}
    #|
  let (done, parsed, events) = codex_stream_events_from_sse_block(block, state)
  assert_false(done)
  assert_true(parsed is Some(_))
  assert_eq(events.length(), 3)
  assert_eq(events[0].event_type, "message_start")
  assert_eq(events[1].event_type, "content_block_start")
  assert_eq(events[2].event_type, "content_block_delta")
  let start_data = @json.parse(events[1].data) catch {
    _ => fail("expected start json")
  }
  guard start_data is Object(start_obj) else { fail("expected object") }
  assert_eq(start_obj["index"], Json::number(0.0))
  guard start_obj["content_block"] is Object(block_obj) else {
    fail("expected content block")
  }
  assert_eq(block_obj["type"], Json::string("text"))
  let delta_data = @json.parse(events[2].data) catch {
    _ => fail("expected delta json")
  }
  guard delta_data is Object(delta_obj) else { fail("expected object") }
  guard delta_obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["text"], Json::string("hello"))
}

///|
test "ccs responses stream state closes dangling text on completed" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let text_block =
    #|event: response.output_text.delta
    #|data: {"type":"response.output_text.delta","delta":"hello"}
    #|
  let (_, _, first_events) = codex_stream_events_from_sse_block(
    text_block, state,
  )
  assert_eq(first_events.length(), 3)
  let completed_block =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_done","status":"completed","model":"gpt-5.4","output":[],"usage":{"input_tokens":6,"output_tokens":2}}}
    #|
  let (done, parsed, finish_events) = codex_stream_events_from_sse_block(
    completed_block, state,
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  assert_eq(finish_events.length(), 2)
  assert_eq(finish_events[0].event_type, "content_block_stop")
  assert_eq(finish_events[1].event_type, "message_delta")
  let stop_data = @json.parse(finish_events[0].data) catch {
    _ => fail("expected stop json")
  }
  guard stop_data is Object(stop_obj) else { fail("expected object") }
  assert_eq(stop_obj["index"], Json::number(0.0))
}

///|
test "ccs responses stream state merges keyed text parts" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let first_added =
    #|event: response.content_part.added
    #|data: {"type":"response.content_part.added","part":{"type":"output_text","text":""},"output_index":0,"content_index":0}
    #|
  let (_, _, first_added_events) = codex_stream_events_from_sse_block(
    first_added, state,
  )
  assert_eq(first_added_events.length(), 2)
  assert_eq(first_added_events[0].event_type, "message_start")
  assert_eq(first_added_events[1].event_type, "content_block_start")

  let first_delta =
    #|event: response.output_text.delta
    #|data: {"type":"response.output_text.delta","delta":"你","output_index":0,"content_index":0}
    #|
  let (_, _, first_delta_events) = codex_stream_events_from_sse_block(
    first_delta, state,
  )
  assert_eq(first_delta_events.length(), 1)

  let first_done =
    #|event: response.content_part.done
    #|data: {"type":"response.content_part.done","output_index":0,"content_index":0}
    #|
  let (_, _, first_done_events) = codex_stream_events_from_sse_block(
    first_done, state,
  )
  assert_eq(first_done_events.length(), 0)

  let second_added =
    #|event: response.content_part.added
    #|data: {"type":"response.content_part.added","part":{"type":"output_text","text":""},"output_index":0,"content_index":1}
    #|
  let (_, _, second_added_events) = codex_stream_events_from_sse_block(
    second_added, state,
  )
  assert_eq(second_added_events.length(), 0)

  let second_delta =
    #|event: response.output_text.delta
    #|data: {"type":"response.output_text.delta","delta":"好","output_index":0,"content_index":1}
    #|
  let (_, _, second_delta_events) = codex_stream_events_from_sse_block(
    second_delta, state,
  )
  assert_eq(second_delta_events.length(), 1)

  let text_done =
    #|event: response.output_text.done
    #|data: {"type":"response.output_text.done","output_index":0,"content_index":1}
    #|
  let (_, _, text_done_events) = codex_stream_events_from_sse_block(
    text_done, state,
  )
  assert_eq(text_done_events.length(), 1)
  assert_eq(text_done_events[0].event_type, "content_block_stop")
}

///|
test "ccs responses stream state closes keyed text without current index" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let added =
    #|event: response.content_part.added
    #|data: {"type":"response.content_part.added","part":{"type":"refusal","text":""},"item_id":"msg_1","content_index":0}
    #|
  let (_, _, added_events) = codex_stream_events_from_sse_block(added, state)
  assert_eq(added_events.length(), 2)
  state.current_text_index = None
  let done =
    #|event: response.refusal.done
    #|data: {"type":"response.refusal.done","item_id":"msg_1","content_index":0}
    #|
  let (_, _, done_events) = codex_stream_events_from_sse_block(done, state)
  assert_eq(done_events.length(), 1)
  assert_eq(done_events[0].event_type, "content_block_stop")
  let stop_data = @json.parse(done_events[0].data) catch {
    _ => fail("expected stop json")
  }
  guard stop_data is Object(stop_obj) else { fail("expected object") }
  assert_eq(stop_obj["index"], Json::number(0.0))
}

///|
test "ccs responses stream state emits reasoning thinking blocks" {
  let state = ResponsesStreamState::new("o3")
  let reasoning_block =
    #|event: response.reasoning.delta
    #|data: {"type":"response.reasoning.delta","delta":"Let me think..."}
    #|
  let (done, parsed, events) = codex_stream_events_from_sse_block(
    reasoning_block, state,
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  assert_eq(events.length(), 3)
  assert_eq(events[0].event_type, "message_start")
  assert_eq(events[1].event_type, "content_block_start")
  assert_eq(events[2].event_type, "content_block_delta")
  let start_data = @json.parse(events[1].data) catch {
    _ => fail("expected start json")
  }
  guard start_data is Object(start_obj) else { fail("expected object") }
  assert_eq(start_obj["index"], Json::number(0.0))
  guard start_obj["content_block"] is Object(content_block) else {
    fail("expected content block")
  }
  assert_eq(content_block["type"], Json::string("thinking"))
  assert_eq(content_block["thinking"], Json::string(""))
  let delta_data = @json.parse(events[2].data) catch {
    _ => fail("expected delta json")
  }
  guard delta_data is Object(delta_obj) else { fail("expected object") }
  guard delta_obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["type"], Json::string("thinking_delta"))
  assert_eq(delta["thinking"], Json::string("Let me think..."))

  let done_block =
    #|event: response.reasoning.done
    #|data: {"type":"response.reasoning.done"}
    #|
  let (_, _, done_events) = codex_stream_events_from_sse_block(
    done_block, state,
  )
  assert_eq(done_events.length(), 1)
  assert_eq(done_events[0].event_type, "content_block_stop")
  let stop_data = @json.parse(done_events[0].data) catch {
    _ => fail("expected stop json")
  }
  guard stop_data is Object(stop_obj) else { fail("expected object") }
  assert_eq(stop_obj["index"], Json::number(0.0))
}

///|
test "ccs responses stream state closes reasoning before text on completed" {
  let state = ResponsesStreamState::new("o3")
  let reasoning_block =
    #|event: response.reasoning.delta
    #|data: {"type":"response.reasoning.delta","text":"thinking without done"}
    #|
  let (_, _, reasoning_events) = codex_stream_events_from_sse_block(
    reasoning_block, state,
  )
  assert_eq(reasoning_events.length(), 3)
  let completed_block =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_done","status":"completed","model":"o3","output":[],"usage":{"input_tokens":6,"output_tokens":2}}}
    #|
  let (_, _, completed_events) = codex_stream_events_from_sse_block(
    completed_block, state,
  )
  assert_eq(completed_events.length(), 2)
  assert_eq(completed_events[0].event_type, "content_block_stop")
  assert_eq(completed_events[1].event_type, "message_delta")
  let stop_data = @json.parse(completed_events[0].data) catch {
    _ => fail("expected stop json")
  }
  guard stop_data is Object(stop_obj) else { fail("expected object") }
  assert_eq(stop_obj["index"], Json::number(0.0))
}

///|
test "ccs responses stream state emits function call argument deltas" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let added_block =
    #|event: response.output_item.added
    #|data: {"type":"response.output_item.added","item_id":"fc_1","output_index":0,"item":{"id":"fc_1","type":"function_call","call_id":"call_1","name":"lookup"}}
    #|
  let (_, _, added_events) = codex_stream_events_from_sse_block(
    added_block, state,
  )
  assert_eq(added_events.length(), 2)
  assert_eq(added_events[0].event_type, "message_start")
  assert_eq(added_events[1].event_type, "content_block_start")
  let start_data = @json.parse(added_events[1].data) catch {
    _ => fail("expected start json")
  }
  guard start_data is Object(start_obj) else { fail("expected object") }
  assert_eq(start_obj["index"], Json::number(0.0))
  guard start_obj["content_block"] is Object(block_obj) else {
    fail("expected content block")
  }
  assert_eq(block_obj["type"], Json::string("tool_use"))
  assert_eq(block_obj["id"], Json::string("call_1"))
  assert_eq(block_obj["name"], Json::string("lookup"))

  let delta_block =
    #|event: response.function_call_arguments.delta
    #|data: {"type":"response.function_call_arguments.delta","item_id":"fc_1","delta":"{\"q\":\"moon\""}
    #|
  let (_, _, delta_events) = codex_stream_events_from_sse_block(
    delta_block, state,
  )
  assert_eq(delta_events.length(), 1)
  assert_eq(delta_events[0].event_type, "content_block_delta")
  let delta_data = @json.parse(delta_events[0].data) catch {
    _ => fail("expected delta json")
  }
  guard delta_data is Object(delta_obj) else { fail("expected object") }
  guard delta_obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["type"], Json::string("input_json_delta"))
  assert_eq(delta["partial_json"], Json::string("{\"q\":\"moon\""))

  let done_block =
    #|event: response.function_call_arguments.done
    #|data: {"type":"response.function_call_arguments.done","item_id":"fc_1","arguments":"{\"q\":\"moon\"}"}
    #|
  let (_, _, done_events) = codex_stream_events_from_sse_block(
    done_block, state,
  )
  assert_eq(done_events.length(), 1)
  assert_eq(done_events[0].event_type, "content_block_stop")

  let completed_block =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_tool","status":"completed","model":"gpt-5.4","output":[],"usage":{"input_tokens":6,"output_tokens":2}}}
    #|
  let (_, _, finish_events) = codex_stream_events_from_sse_block(
    completed_block, state,
  )
  assert_eq(finish_events.length(), 1)
  let finish_data = @json.parse(finish_events[0].data) catch {
    _ => fail("expected finish json")
  }
  guard finish_data is Object(finish_obj) else { fail("expected object") }
  guard finish_obj["delta"] is Object(finish_delta) else {
    fail("expected delta")
  }
  assert_eq(finish_delta["stop_reason"], Json::string("tool_use"))
}

///|
test "ccs responses stream state sanitizes read tool empty pages" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let added_block =
    #|event: response.output_item.added
    #|data: {"type":"response.output_item.added","item":{"id":"fc_read","type":"function_call","call_id":"call_read","name":"Read"}}
    #|
  let (_, _, added_events) = codex_stream_events_from_sse_block(
    added_block, state,
  )
  assert_eq(added_events.length(), 2)

  let delta_block =
    #|event: response.function_call_arguments.delta
    #|data: {"type":"response.function_call_arguments.delta","item_id":"fc_read","delta":"{\"file_path\":\"/tmp/demo.py\",\"limit\":2000,\"offset\":0,\"pages\":\"\"}"}
    #|
  let (_, _, delta_events) = codex_stream_events_from_sse_block(
    delta_block, state,
  )
  assert_eq(delta_events.length(), 0)

  let done_block =
    #|event: response.function_call_arguments.done
    #|data: {"type":"response.function_call_arguments.done","item_id":"fc_read","arguments":"{\"file_path\":\"/tmp/demo.py\",\"limit\":2000,\"offset\":0,\"pages\":\"\"}"}
    #|
  let (_, _, done_events) = codex_stream_events_from_sse_block(
    done_block, state,
  )
  assert_eq(done_events.length(), 2)
  assert_eq(done_events[0].event_type, "content_block_delta")
  assert_eq(done_events[1].event_type, "content_block_stop")
  let data = @json.parse(done_events[0].data) catch {
    _ => fail("expected delta json")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  guard delta["partial_json"] is String(partial) else {
    fail("expected partial json")
  }
  let partial_json = @json.parse(partial) catch {
    _ => fail("expected sanitized partial json")
  }
  guard partial_json is Object(input) else { fail("expected input object") }
  assert_eq(input["file_path"], Json::string("/tmp/demo.py"))
  assert_eq(input["limit"], Json::number(2000.0))
  assert_eq(input["offset"], Json::number(0.0))
  assert_true(input.get("pages") is None)
}

///|
test "ccs responses stream state read duplicate start preserves buffered args" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let added_block =
    #|event: response.output_item.added
    #|data: {"type":"response.output_item.added","item":{"id":"fc_read","type":"function_call","call_id":"call_read","name":"Read"}}
    #|
  let (_, _, first_added) = codex_stream_events_from_sse_block(
    added_block, state,
  )
  assert_eq(first_added.length(), 2)
  let delta_block =
    #|event: response.function_call_arguments.delta
    #|data: {"type":"response.function_call_arguments.delta","item_id":"fc_read","delta":"{\"file_path\":\"/tmp/demo.py\",\"limit\":2000,\"offset\":0,\"pages\":\"\"}"}
    #|
  let (_, _, delta_events) = codex_stream_events_from_sse_block(
    delta_block, state,
  )
  assert_eq(delta_events.length(), 0)
  let (_, _, duplicate_added) = codex_stream_events_from_sse_block(
    added_block, state,
  )
  assert_eq(duplicate_added.length(), 0)
  let done_block =
    #|event: response.function_call_arguments.done
    #|data: {"type":"response.function_call_arguments.done","item_id":"fc_read"}
    #|
  let (_, _, done_events) = codex_stream_events_from_sse_block(
    done_block, state,
  )
  assert_eq(done_events.length(), 2)
  let data = @json.parse(done_events[0].data) catch {
    _ => fail("expected delta json")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  guard delta["partial_json"] is String(partial) else {
    fail("expected partial json")
  }
  let partial_json = @json.parse(partial) catch {
    _ => fail("expected sanitized partial json")
  }
  guard partial_json is Object(input) else { fail("expected input object") }
  assert_true(input.get("pages") is None)
}

///|
test "ccs responses sse parser ignores truncated trailing block" {
  let sse =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_ok","status":"completed","model":"gpt-5.4","output":[],"usage":{"input_tokens":3,"output_tokens":1}}}
    #|
    #|event: response.output_text.delta
    #|data: {"type":"response.output_text.delta","delta":"unterminated
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_responses",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed response")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  assert_eq(obj["id"], Json::string("resp_ok"))
}

///|
test "ccs responses sse parser collects output items" {
  let sse =
    #|event: response.output_item.done
    #|data: {"type":"response.output_item.done","item":{"type":"function_call","call_id":"call_1","name":"lookup","arguments":"{\"q\":\"moon\"}"}}
    #|
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_1","status":"completed","model":"gpt-5.4","output":[],"usage":{"input_tokens":10,"output_tokens":2}}}
    #|
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_responses",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed response")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  guard obj["output"] is Array(output) else { fail("expected output") }
  assert_eq(output.length(), 1)
  guard output[0] is Object(item) else { fail("expected item") }
  assert_eq(item["type"], Json::string("function_call"))
  assert_eq(item["call_id"], Json::string("call_1"))
}

///|
test "ccs sse body sniffing accepts bom and indented fields" {
  assert_true(body_looks_like_sse("\u{feff}\n  data: {}\n\n"))
  assert_true(body_looks_like_sse(": PROCESSING\n\ndata: {}\n\n"))
  assert_false(body_looks_like_sse("<html><body>blocked</body></html>"))
}

///|
test "ccs upstream parse diagnostics include headers and body snippet" {
  let headers = { "content-type": "text/html", "content-encoding": "gzip" }
  let suffix = body_diagnostics_suffix(headers, "<html>\r\nblocked\u{0}</html>")
  assert_true(suffix.contains("content-type: text/html"))
  assert_true(suffix.contains("content-encoding: gzip"))
  assert_true(suffix.contains("<html>\\nblocked\u{FFFD}</html>"))
}

///|
test "ccs upstream parse diagnostics mark missing headers" {
  let result = parse_claude_compatible_non_stream_body_with_diagnostics(
    "anthropic",
    "data: oops",
    {},
  )
  guard result is Err(message) else { fail("expected parse error") }
  assert_true(message.contains("Failed to parse upstream response"))
  assert_true(message.contains("content-type: <none>"))
  assert_true(message.contains("content-encoding: <none>"))
  assert_true(message.contains("body[..120]: 'data: oops'"))
}

///|
test "ccs upstream parse diagnostics truncate long body snippets" {
  let body = "abcdefghijklmnopqrstuvwxyz"
  assert_eq(body_snippet(body, 5), "abcde\u{2026}")
}

///|
test "ccs chat sse parser aggregates text and usage" {
  let sse =
    #|data: {"id":"chatcmpl_1","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"Hel"},"finish_reason":null}]}
    #|
    #|data: {"choices":[{"index":0,"delta":{"content":"lo"},"finish_reason":"stop"}],"usage":{"prompt_tokens":10,"completion_tokens":5,"prompt_tokens_details":{"cached_tokens":2}}}
    #|
    #|data: [DONE]
    #|
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed chat")
  }
  let response = openai_chat_completion_to_anthropic(
    parsed, "claude-sonnet-4-6",
  )
  assert_eq(response.id, "chatcmpl_1")
  assert_eq(response.content.length(), 1)
  assert_eq(response.content[0].text, Some("Hello"))
  assert_eq(response.usage.input_tokens, 8)
  assert_eq(response.usage.output_tokens, 5)
  assert_eq(response.usage.cache_read_input_tokens, Some(2))
}

///|
test "ccs chat sse parser merges tool call argument fragments" {
  let sse =
    #|data: {"id":"chatcmpl_tool","model":"gpt-4o","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"lookup","arguments":"{\"q\""}}]},"finish_reason":null}]}
    #|
    #|data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":":\"moon\"}"}}]},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":4,"completion_tokens":2}}
    #|
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed chat")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  guard obj["choices"] is Array(choices) else { fail("expected choices") }
  guard choices[0] is Object(choice) else { fail("expected choice") }
  guard choice["message"] is Object(message) else { fail("expected message") }
  guard message["tool_calls"] is Array(tool_calls) else {
    fail("expected tool calls")
  }
  guard tool_calls[0] is Object(call) else { fail("expected call") }
  guard call["function"] is Object(function) else { fail("expected function") }
  assert_eq(function["name"], Json::string("lookup"))
  assert_eq(function["arguments"], Json::string("{\"q\":\"moon\"}"))
  let response = openai_chat_completion_to_anthropic(
    parsed, "claude-sonnet-4-6",
  )
  assert_eq(response.stop_reason, Some("tool_use"))
  assert_eq(response.content.length(), 1)
  assert_eq(response.content[0].id, Some("call_1"))
}

///|
test "ccs chat sse parser ignores truncated trailing block after done" {
  let sse =
    #|data: {"id":"chatcmpl_ok","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"done"},"finish_reason":"stop"}]}
    #|
    #|data: {"choices":[{"index":0,"delta":{"content":"unterminated
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed chat")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  assert_eq(obj["id"], Json::string("chatcmpl_ok"))
  guard obj["choices"] is Array(choices) else { fail("expected choices") }
  guard choices[0] is Object(choice) else { fail("expected choice") }
  guard choice["message"] is Object(message) else { fail("expected message") }
  assert_eq(message["content"], Json::string("done"))
}

///|
test "ccs chat sse parser rejects stream without choices" {
  let sse =
    #|: keepalive
    #|
    #|data: [DONE]
    #|
  assert_true(
    parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Err(_),
  )
}

///|
test "ccs chat sse parser rejects event error" {
  let sse =
    #|data: {"id":"chatcmpl_ok","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"done"},"finish_reason":"stop"}]}
    #|
    #|event: error
    #|data: {"error":{"message":"quota exceeded"}}
    #|
  assert_true(
    parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Err(_),
  )
}

///|
test "ccs upstream body filter removes private fields" {
  let body = @json.parse(
    (
      #|{
      #|  "z": 1,
      #|  "_internal": "drop",
      #|  "tools": [
      #|    {
      #|      "name": "lookup",
      #|      "parameters": {
      #|        "type": "object",
      #|        "properties": {
      #|          "_id": {
      #|            "_private_note": "drop",
      #|            "type": "string"
      #|          },
      #|          "b": { "type": "number" },
      #|          "a": { "type": "string" }
      #|        }
      #|      }
      #|    }
      #|  ],
      #|  "a": 2
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body)
  guard prepared is Object(obj) else { fail("expected object") }
  assert_true(obj.get("_internal") is None)
  guard obj["tools"] is Array(tools) else { fail("expected tools") }
  guard tools[0] is Object(tool) else { fail("expected tool") }
  guard tool["parameters"] is Object(parameters) else {
    fail("expected parameters")
  }
  guard parameters["properties"] is Object(properties) else {
    fail("expected properties")
  }
  assert_true(properties.get("_id") is Some(_))
  guard properties["_id"] is Object(id_property) else {
    fail("expected _id property")
  }
  assert_true(id_property.get("_private_note") is None)
  assert_eq(id_property["type"], Json::string("string"))
}

///|
test "ccs json canonical string sorts nested object keys" {
  let left = @json.parse(
    (
      #|{
      #|  "b": 2,
      #|  "a": {
      #|    "d": true,
      #|    "c": [3, { "z": 1, "y": 2 }]
      #|  }
      #|}
    ),
  )
  let right = @json.parse(
    (
      #|{
      #|  "a": {
      #|    "c": [3, { "y": 2, "z": 1 }],
      #|    "d": true
      #|  },
      #|  "b": 2
      #|}
    ),
  )
  assert_eq(canonical_json_string(left), canonical_json_string(right))
  assert_eq(
    canonical_json_string(right),
    "{\"a\":{\"c\":[3,{\"y\":2,\"z\":1}],\"d\":true},\"b\":2}",
  )
}

///|
test "ccs upstream body filter supports private whitelist" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-3",
      #|  "_metadata": { "key": "value" },
      #|  "_internal_id": "drop",
      #|  "data": {
      #|    "_metadata": { "nested": true },
      #|    "_internal": "drop"
      #|  }
      #|}
    ),
  )
  let filtered = filter_private_params_for_upstream(body, None, ["_metadata"])
  guard filtered is Object(obj) else { fail("expected object") }
  assert_true(obj.get("_metadata") is Some(_))
  assert_true(obj.get("_internal_id") is None)
  guard obj["data"] is Object(data) else { fail("expected data") }
  assert_true(data.get("_metadata") is Some(_))
  assert_true(data.get("_internal") is None)
}

///|
test "ccs upstream body preparation canonicalizes object order" {
  let body = @json.parse(
    (
      #|{
      #|  "z": 1,
      #|  "_internal": "drop",
      #|  "tools": [{
      #|    "name": "lookup",
      #|    "parameters": {
      #|      "type": "object",
      #|      "properties": {
      #|        "_id": { "_private_note": "drop", "type": "string" },
      #|        "b": { "type": "number" },
      #|        "a": { "type": "string" }
      #|      }
      #|    }
      #|  }],
      #|  "a": 2
      #|}
    ),
  )
  assert_eq(
    prepare_upstream_request_body(body).stringify(),
    "{\"a\":2,\"tools\":[{\"name\":\"lookup\",\"parameters\":{\"properties\":{\"_id\":{\"type\":\"string\"},\"a\":{\"type\":\"string\"},\"b\":{\"type\":\"number\"}},\"type\":\"object\"}}],\"z\":1}",
  )
}

///|
test "ccs upstream body filter preserves all schema name maps" {
  let body = @json.parse(
    (
      #|{
      #|  "_top": "drop",
      #|  "schema": {
      #|    "patternProperties": {
      #|      "^_x": { "_private_note": "drop", "type": "string" }
      #|    },
      #|    "definitions": {
      #|      "_legacy": { "_private_note": "drop", "type": "number" }
      #|    },
      #|    "$defs": {
      #|      "_modern": { "_private_note": "drop", "type": "boolean" }
      #|    }
      #|  }
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body)
  guard prepared is Object(obj) else { fail("expected object") }
  assert_true(obj.get("_top") is None)
  guard obj["schema"] is Object(schema) else { fail("expected schema") }
  guard schema["patternProperties"] is Object(pattern_properties) else {
    fail("expected patternProperties")
  }
  guard pattern_properties["^_x"] is Object(pattern) else {
    fail("expected pattern property")
  }
  assert_true(pattern.get("_private_note") is None)
  assert_eq(pattern["type"], Json::string("string"))
  guard schema["definitions"] is Object(definitions) else {
    fail("expected definitions")
  }
  guard definitions["_legacy"] is Object(legacy) else {
    fail("expected definition")
  }
  assert_true(legacy.get("_private_note") is None)
  assert_eq(legacy["type"], Json::string("number"))
  guard schema["$defs"] is Object(defs) else { fail("expected $defs") }
  guard defs["_modern"] is Object(modern) else { fail("expected $defs entry") }
  assert_true(modern.get("_private_note") is None)
  assert_eq(modern["type"], Json::string("boolean"))
}

///|
test "ccs thinking signature rectifier detects ccs error phrases" {
  let config = default_rectifier_config()
  assert_true(config.request_media_fallback)
  assert_true(config.request_media_heuristic)
  assert_true(
    should_rectify_thinking_signature(
      Some("messages.1.content.0: Invalid `signature` in `thinking` block"),
      config,
    ),
  )
  assert_true(
    should_rectify_thinking_signature(
      Some("Unable to submit request because Thought signature is not valid"),
      config,
    ),
  )
  assert_true(
    should_rectify_thinking_signature(
      Some(
        "messages.69.content.0.type: Expected `thinking` or `redacted_thinking`, but found `tool_use`.",
      ),
      config,
    ),
  )
  assert_true(
    should_rectify_thinking_signature(
      Some("xxx.signature: Extra inputs are not permitted"),
      config,
    ),
  )
  assert_false(
    should_rectify_thinking_signature(
      Some(
        "Input tag 'adaptive' found using 'type' does not match expected tags",
      ),
      config,
    ),
  )
  assert_false(
    should_rectify_thinking_signature(
      Some("Invalid `signature` in `thinking` block"),
      {
        enabled: false,
        request_thinking_signature: true,
        request_thinking_budget: true,
        request_media_fallback: true,
        request_media_heuristic: true,
      },
    ),
  )
}

///|
test "ccs thinking signature rectifier removes legacy blocks and signatures" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-test",
      #|  "messages": [{
      #|    "role": "assistant",
      #|    "content": [
      #|      { "type": "thinking", "thinking": "t", "signature": "sig" },
      #|      { "type": "text", "text": "hello", "signature": "sig_text" },
      #|      { "type": "tool_use", "id": "toolu_1", "name": "WebSearch", "input": {}, "signature": "sig_tool" },
      #|      { "type": "redacted_thinking", "data": "r", "signature": "sig_redacted" }
      #|    ]
      #|  }]
      #|}
    ),
  )
  let rectified = rectify_anthropic_request(body)
  assert_true(rectified.applied)
  assert_eq(rectified.removed_thinking_blocks, 1)
  assert_eq(rectified.removed_redacted_thinking_blocks, 1)
  assert_eq(rectified.removed_signature_fields, 2)
  guard rectified.body is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  assert_eq(content.length(), 2)
  guard content[0] is Object(text) else { fail("expected text") }
  guard content[1] is Object(tool) else { fail("expected tool") }
  assert_eq(text["type"], Json::string("text"))
  assert_true(text.get("signature") is None)
  assert_eq(tool["type"], Json::string("tool_use"))
  assert_true(tool.get("signature") is None)
}

///|
test "ccs thinking signature rectifier removes top level thinking for tool chain" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-test",
      #|  "thinking": { "type": "enabled", "budget_tokens": 1024 },
      #|  "messages": [{
      #|    "role": "assistant",
      #|    "content": [
      #|      { "type": "tool_use", "id": "toolu_1", "name": "WebSearch", "input": {} }
      #|    ]
      #|  }, {
      #|    "role": "user",
      #|    "content": [{ "type": "tool_result", "tool_use_id": "toolu_1", "content": "ok" }]
      #|  }]
      #|}
    ),
  )
  let rectified = rectify_anthropic_request(body)
  assert_true(rectified.applied)
  guard rectified.body is Object(obj) else { fail("expected object") }
  assert_true(obj.get("thinking") is None)
}

///|
test "ccs thinking budget rectifier detects and normalizes budget errors" {
  let config = default_rectifier_config()
  assert_true(
    should_rectify_thinking_budget(
      Some(
        "thinking.budget_tokens: Input should be greater than or equal to 1024",
      ),
      config,
    ),
  )
  assert_true(
    should_rectify_thinking_budget(
      Some("thinking budget_tokens must be >= 1024"),
      config,
    ),
  )
  assert_false(
    should_rectify_thinking_budget(
      Some("budget_tokens must be less than max_tokens"),
      config,
    ),
  )
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-test",
      #|  "thinking": { "type": "enabled", "budget_tokens": 512 },
      #|  "max_tokens": 1024
      #|}
    ),
  )
  let rectified = rectify_thinking_budget(body)
  assert_true(rectified.applied)
  assert_eq(rectified.before.thinking_budget_tokens, Some(512))
  assert_eq(rectified.after.thinking_budget_tokens, Some(32000))
  assert_eq(rectified.before.max_tokens, Some(1024))
  assert_eq(rectified.after.max_tokens, Some(64000))
  guard rectified.body is Object(obj) else { fail("expected object") }
  guard obj["thinking"] is Object(thinking) else { fail("expected thinking") }
  assert_eq(thinking["type"], Json::string("enabled"))
  assert_eq(thinking["budget_tokens"], Json::number(32000.0))
  assert_eq(obj["max_tokens"], Json::number(64000.0))
}

///|
test "ccs thinking budget rectifier skips adaptive requests" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-test",
      #|  "thinking": { "type": "adaptive", "budget_tokens": 512 },
      #|  "max_tokens": 1024
      #|}
    ),
  )
  let rectified = rectify_thinking_budget(body)
  assert_false(rectified.applied)
  assert_eq(rectified.before.thinking_type, Some("adaptive"))
  assert_eq(rectified.after.thinking_type, Some("adaptive"))
  guard rectified.body is Object(obj) else { fail("expected object") }
  guard obj["thinking"] is Object(thinking) else { fail("expected thinking") }
  assert_eq(thinking["type"], Json::string("adaptive"))
  assert_eq(thinking["budget_tokens"], Json::number(512.0))
  assert_eq(obj["max_tokens"], Json::number(1024.0))
}

///|
test "ccs rectifier retry body selects signature before budget" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-test",
      #|  "thinking": { "type": "enabled", "budget_tokens": 512 },
      #|  "max_tokens": 1024,
      #|  "messages": [{
      #|    "role": "assistant",
      #|    "content": [
      #|      { "type": "thinking", "thinking": "t", "signature": "sig" },
      #|      { "type": "tool_use", "id": "toolu_1", "name": "WebSearch", "input": {} }
      #|    ]
      #|  }]
      #|}
    ),
  )
  let retry = ccs_rectifier_retry_body(
    "Invalid `signature` in `thinking` block and thinking.budget_tokens: Input should be greater than or equal to 1024",
    body,
  )
  guard retry is Some(retry) else { fail("expected retry") }
  assert_eq(retry.kind, "thinking_signature")
  guard retry.body is Object(obj) else { fail("expected object") }
  assert_true(obj.get("thinking") is None)
}

///|
test "ccs thinking optimizer uses adaptive mode for newer opus and sonnet" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "anthropic.claude-opus-4-6-20250514-v1:0",
      #|  "max_tokens": 16384,
      #|  "thinking": { "type": "enabled", "budget_tokens": 8000 },
      #|  "messages": [{ "role": "user", "content": "hello" }]
      #|}
    ),
  )
  let optimized = optimize_ccs_thinking(body)
  guard optimized is Object(obj) else { fail("expected object") }
  guard obj["thinking"] is Object(thinking) else { fail("expected thinking") }
  assert_eq(thinking["type"], Json::string("adaptive"))
  assert_true(thinking.get("budget_tokens") is None)
  guard obj["output_config"] is Object(output_config) else {
    fail("expected output_config")
  }
  assert_eq(output_config["effort"], Json::string("max"))
  guard obj["anthropic_beta"] is Array(betas) else {
    fail("expected anthropic_beta")
  }
  assert_true(betas.contains(Json::string("context-1m-2025-08-07")))
}

///|
test "ccs thinking optimizer injects legacy budget and beta" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "anthropic.claude-sonnet-4-5-20250514-v1:0",
      #|  "max_tokens": 8192,
      #|  "thinking": { "type": "disabled" },
      #|  "messages": [{ "role": "user", "content": "hello" }]
      #|}
    ),
  )
  let optimized = optimize_ccs_thinking(body)
  guard optimized is Object(obj) else { fail("expected object") }
  guard obj["thinking"] is Object(thinking) else { fail("expected thinking") }
  assert_eq(thinking["type"], Json::string("enabled"))
  assert_eq(thinking["budget_tokens"], Json::number(8191.0))
  guard obj["anthropic_beta"] is Array(betas) else {
    fail("expected anthropic_beta")
  }
  assert_true(betas.contains(Json::string("interleaved-thinking-2025-05-14")))
}

///|
test "ccs thinking optimizer upgrades small enabled legacy budget" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "anthropic.claude-sonnet-4-5-20250514-v1:0",
      #|  "max_tokens": 4096,
      #|  "thinking": { "type": "enabled", "budget_tokens": 1024 },
      #|  "anthropic_beta": ["interleaved-thinking-2025-05-14"],
      #|  "messages": [{ "role": "user", "content": "hello" }]
      #|}
    ),
  )
  let optimized = optimize_ccs_thinking(body)
  guard optimized is Object(obj) else { fail("expected object") }
  guard obj["thinking"] is Object(thinking) else { fail("expected thinking") }
  assert_eq(thinking["budget_tokens"], Json::number(4095.0))
  guard obj["anthropic_beta"] is Array(betas) else {
    fail("expected anthropic_beta")
  }
  assert_eq(betas.length(), 1)
}

///|
test "ccs thinking optimizer skips haiku models" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "anthropic.claude-haiku-4-5-20250514-v1:0",
      #|  "max_tokens": 8192,
      #|  "messages": [{ "role": "user", "content": "hello" }]
      #|}
    ),
  )
  assert_eq(optimize_ccs_thinking(body), body)
}

///|
test "ccs thinking optimizer can be disabled for bedrock provider" {
  let keys = [
    "MOONSTAT_OPTIMIZER_ENABLED", "MOONSTAT_THINKING_OPTIMIZER", "MOONSTAT_CACHE_INJECTION",
  ]
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
  @os.setenv("MOONSTAT_OPTIMIZER_ENABLED", "true", overwrite=true)
  @os.setenv("MOONSTAT_THINKING_OPTIMIZER", "false", overwrite=true)
  @os.setenv("MOONSTAT_CACHE_INJECTION", "false", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="bedrock-thinking-off",
    provider_name="Bedrock Thinking Off",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "env": { "CLAUDE_CODE_USE_BEDROCK": "1" }
          #|}
        ),
      ),
    ),
  )
  let body = @json.parse(
    (
      #|{
      #|  "model": "anthropic.claude-sonnet-4-5-20250514-v1:0",
      #|  "max_tokens": 8192,
      #|  "messages": [{ "role": "user", "content": "hello" }]
      #|}
    ),
  )
  let optimized = prepare_upstream_request_body(body, provider=Some(provider))
  guard optimized is Object(obj) else { fail("expected object") }
  assert_true(obj.get("thinking") is None)
  assert_true(obj.get("anthropic_beta") is None)
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
}

///|
test "ccs cache injector adds cache breakpoints at provider send sites" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "anthropic.claude-sonnet-4-5-20250514-v1:0",
      #|  "tools": [
      #|    { "name": "read" },
      #|    { "name": "write" }
      #|  ],
      #|  "system": "sys prompt",
      #|  "messages": [
      #|    { "role": "user", "content": [{ "type": "text", "text": "hi" }] },
      #|    { "role": "assistant", "content": [
      #|      { "type": "thinking", "thinking": "skip" },
      #|      { "type": "text", "text": "hello" }
      #|    ] }
      #|  ]
      #|}
    ),
  )
  let optimized = inject_ccs_cache_breakpoints(body, "1h")
  guard optimized is Object(obj) else { fail("expected object") }
  guard obj["tools"] is Array(tools) else { fail("expected tools") }
  guard tools[0] is Object(first_tool) else { fail("expected first tool") }
  guard tools[1] is Object(last_tool) else { fail("expected last tool") }
  assert_true(first_tool.get("cache_control") is None)
  assert_eq(
    last_tool["cache_control"],
    Json::object({
      "type": Json::string("ephemeral"),
      "ttl": Json::string("1h"),
    }),
  )
  guard obj["system"] is Array(system) else { fail("expected system array") }
  guard system[0] is Object(system_block) else { fail("expected system block") }
  assert_eq(system_block["text"], Json::string("sys prompt"))
  assert_true(system_block.get("cache_control") is Some(_))
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[1] is Object(assistant) else { fail("expected assistant") }
  guard assistant["content"] is Array(content) else {
    fail("expected assistant content")
  }
  guard content[0] is Object(thinking) else { fail("expected thinking") }
  guard content[1] is Object(text) else { fail("expected text") }
  assert_true(thinking.get("cache_control") is None)
  assert_true(text.get("cache_control") is Some(_))
  assert_eq(count_ccs_cache_breakpoints(optimized), 3)
}

///|
test "ccs cache injector only upgrades ttl after four existing breakpoints" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "test",
      #|  "tools": [
      #|    { "name": "t1", "cache_control": { "type": "ephemeral" } },
      #|    { "name": "t2", "cache_control": { "type": "ephemeral", "ttl": "5m" } }
      #|  ],
      #|  "system": [
      #|    { "type": "text", "text": "sys", "cache_control": { "type": "ephemeral" } }
      #|  ],
      #|  "messages": [
      #|    { "role": "assistant", "content": [
      #|      { "type": "text", "text": "ok", "cache_control": { "type": "ephemeral" } }
      #|    ] }
      #|  ],
      #|  "metadata": {
      #|    "cache_control": { "type": "ephemeral", "ttl": "old" }
      #|  }
      #|}
    ),
  )
  let optimized = inject_ccs_cache_breakpoints(body, "5m")
  guard optimized is Object(obj) else { fail("expected object") }
  guard obj["tools"] is Array(tools) else { fail("expected tools") }
  guard tools[0] is Object(first_tool) else { fail("expected first tool") }
  guard first_tool["cache_control"] is Object(first_cache) else {
    fail("expected cache control")
  }
  assert_true(first_cache.get("ttl") is None)
  guard obj["metadata"] is Object(metadata) else { fail("expected metadata") }
  guard metadata["cache_control"] is Object(metadata_cache) else {
    fail("expected metadata cache")
  }
  assert_eq(metadata_cache["ttl"], Json::string("old"))
  assert_eq(count_ccs_cache_breakpoints(optimized), 4)
}

///|
test "ccs optimizer runs only for enabled bedrock providers" {
  let keys = ["MOONSTAT_OPTIMIZER_ENABLED", "MOONSTAT_CACHE_TTL"]
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="bedrock",
    provider_name="Bedrock",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "env": { "CLAUDE_CODE_USE_BEDROCK": "1" }
          #|}
        ),
      ),
    ),
  )
  let body = @json.parse(
    (
      #|{
      #|  "model": "test",
      #|  "tools": [{ "name": "lookup" }],
      #|  "messages": [{ "role": "user", "content": "hi" }]
      #|}
    ),
  )
  let disabled = prepare_upstream_request_body(body, provider=Some(provider))
  assert_eq(count_ccs_cache_breakpoints(disabled), 0)
  @os.setenv("MOONSTAT_OPTIMIZER_ENABLED", "true", overwrite=true)
  @os.setenv("MOONSTAT_CACHE_TTL", "1h", overwrite=true)
  let enabled = prepare_upstream_request_body(body, provider=Some(provider))
  assert_eq(count_ccs_cache_breakpoints(enabled), 1)
  guard enabled is Object(enabled_obj) else { fail("expected enabled object") }
  guard enabled_obj["thinking"] is Object(thinking) else {
    fail("expected thinking")
  }
  assert_eq(thinking["type"], Json::string("enabled"))
  let non_bedrock = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="plain",
    provider_name="Plain",
  )
  let skipped = prepare_upstream_request_body(body, provider=Some(non_bedrock))
  assert_eq(count_ccs_cache_breakpoints(skipped), 0)
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
}

///|
test "ccs media sanitizer replaces images for known text-only models" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "deepseek/deepseek-v4-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          },
      #|          "cache_control": { "type": "ephemeral" }
      #|        },
      #|        { "type": "text", "text": "caption" }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body)
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(marker) else { fail("expected marker") }
  assert_eq(marker["type"], Json::string("text"))
  assert_eq(marker["text"], Json::string("[Unsupported Image]"))
  assert_true(marker.get("source") is None)
  assert_eq(
    marker["cache_control"],
    Json::object({ "type": Json::string("ephemeral") }),
  )
  assert_eq(
    content[1],
    Json::object({
      "type": Json::string("text"),
      "text": Json::string("caption"),
    }),
  )
}

///|
test "ccs media sanitizer preserves images for unknown models" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "kimi/kimi-k2.6",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image_url",
      #|          "image_url": { "url": "data:image/png;base64,AAAA" }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body)
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(image) else { fail("expected image") }
  assert_eq(image["type"], Json::string("image_url"))
  assert_true(image.get("image_url") is Some(_))
}

///|
test "ccs media sanitizer can disable curated text-only heuristic" {
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="heuristic-off",
    provider_name="Heuristic Off",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "requestMediaHeuristic": false
          #|}
        ),
      ),
    ),
  )
  let body = @json.parse(
    (
      #|{
      #|  "model": "deepseek/deepseek-v4-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body, provider=Some(provider))
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(image) else { fail("expected image") }
  assert_eq(image["type"], Json::string("image"))
  assert_true(image.get("source") is Some(_))
}

///|
test "ccs media sanitizer honors global heuristic toggle" {
  let keys = [
    "MOONSTAT_RECTIFIER_ENABLED", "MOONSTAT_RECTIFIER_MEDIA_HEURISTIC", "MOONSTAT_CCS_RECTIFIER_MEDIA_HEURISTIC",
    "CCS_RECTIFIER_MEDIA_HEURISTIC",
  ]
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
  @os.setenv("MOONSTAT_RECTIFIER_MEDIA_HEURISTIC", "false", overwrite=true)
  let body = @json.parse(
    (
      #|{
      #|  "model": "deepseek/deepseek-v4-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body)
  @os.unsetenv("MOONSTAT_RECTIFIER_MEDIA_HEURISTIC") catch {
    _ => ()
  }
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(image) else { fail("expected image") }
  assert_eq(image["type"], Json::string("image"))
  assert_true(image.get("source") is Some(_))
}

///|
test "ccs media sanitizer honors explicit provider text-only capability" {
  let settings = @json.parse(
    (
      #|{
      #|  "requestMediaHeuristic": false,
      #|  "models": [
      #|    { "id": "gpt-4o", "input": ["text"] }
      #|  ]
      #|}
    ),
  )
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="explicit-text",
    provider_name="Explicit Text",
    settings_config=Some(settings),
  )
  let body = @json.parse(
    (
      #|{
      #|  "model": "gpt-4o",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body, provider=Some(provider))
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(marker) else { fail("expected marker") }
  assert_eq(marker["type"], Json::string("text"))
  assert_eq(marker["text"], Json::string("[Unsupported Image]"))
}

///|
test "ccs media sanitizer honors explicit provider image capability" {
  let settings = @json.parse(
    (
      #|{
      #|  "modelCatalog": {
      #|    "models": [
      #|      {
      #|        "model": "deepseek-v4-pro",
      #|        "modalities": { "input": ["text", "image"] }
      #|      }
      #|    ]
      #|  }
      #|}
    ),
  )
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="explicit-image",
    provider_name="Explicit Image",
    settings_config=Some(settings),
  )
  let body = @json.parse(
    (
      #|{
      #|  "model": "router/deepseek-v4-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body, provider=Some(provider))
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(image) else { fail("expected image") }
  assert_eq(image["type"], Json::string("image"))
  assert_true(image.get("source") is Some(_))
}

///|
test "ccs media sanitizer replaces nested and responses image blocks" {
  let nested_body = @json.parse(
    (
      #|{
      #|  "model": "therouter/qwen/qwen3-coder-480b",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "tool_result",
      #|          "tool_use_id": "tool_1",
      #|          "content": [
      #|            {
      #|              "type": "image_url",
      #|              "image_url": { "url": "data:image/png;base64,AAAA" }
      #|            }
      #|          ]
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let nested_prepared = prepare_upstream_request_body(nested_body)
  guard nested_prepared is Object(nested_obj) else { fail("expected object") }
  guard nested_obj["messages"] is Array(messages) else {
    fail("expected messages")
  }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(tool_result) else { fail("expected tool result") }
  guard tool_result["content"] is Array(tool_content) else {
    fail("expected tool content")
  }
  guard tool_content[0] is Object(nested_marker) else {
    fail("expected marker")
  }
  assert_eq(nested_marker["type"], Json::string("text"))
  assert_eq(nested_marker["text"], Json::string("[Unsupported Image]"))

  let responses_body = @json.parse(
    (
      #|{
      #|  "model": "deepseek-v4-flash",
      #|  "input": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "input_image",
      #|          "image_url": "data:image/png;base64,AAAA"
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let responses_prepared = prepare_upstream_request_body(responses_body)
  guard responses_prepared is Object(responses_obj) else {
    fail("expected object")
  }
  guard responses_obj["input"] is Array(input) else { fail("expected input") }
  guard input[0] is Object(input_item) else { fail("expected input item") }
  guard input_item["content"] is Array(input_content) else {
    fail("expected input content")
  }
  guard input_content[0] is Object(input_marker) else {
    fail("expected input marker")
  }
  assert_eq(input_marker["type"], Json::string("input_text"))
  assert_eq(input_marker["text"], Json::string("[Unsupported Image]"))
  assert_true(input_marker.get("image_url") is None)
}

///|
test "ccs media retry detects unsupported image upstream errors" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "xiaomi-mimo-token-plan/mimo-v2.5-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  assert_true(contains_image_blocks(body))
  assert_true(
    ccs_media_retry_should_trigger(
      400, "{\"error\":{\"message\":\"This model does not support image input\"}}",
      body,
    ),
  )
  assert_true(
    ccs_media_retry_should_trigger(
      415, "{\"error\":{\"message\":\"This model cannot process media inputs\"}}",
      body,
    ),
  )
  assert_true(
    ccs_media_retry_should_trigger(
      422, "{\"message\":\"attachments are not supported by this model\"}", body,
    ),
  )
  assert_true(
    ccs_media_retry_should_trigger(
      400,
      (
        #|{
        #|  "error": {
        #|    "message": "Failed to deserialize the JSON body: unknown variant image_url, expected text"
        #|  }
        #|}
      ),
      body,
    ),
  )
  assert_false(
    ccs_media_retry_should_trigger_with_config(
      400,
      "{\"error\":{\"message\":\"This model does not support image input\"}}",
      body,
      {
        enabled: true,
        request_thinking_signature: true,
        request_thinking_budget: true,
        request_media_fallback: false,
        request_media_heuristic: true,
      },
    ),
  )
  assert_false(
    ccs_media_retry_should_trigger_with_config(
      400,
      "{\"error\":{\"message\":\"This model does not support image input\"}}",
      body,
      {
        enabled: false,
        request_thinking_signature: true,
        request_thinking_budget: true,
        request_media_fallback: true,
        request_media_heuristic: true,
      },
    ),
  )
}

///|
test "ccs media retry ignores non media errors and bodies without images" {
  let image_body = @json.parse(
    (
      #|{
      #|  "model": "any-model",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image_url",
      #|          "image_url": { "url": "data:image/png;base64,AAAA" }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  assert_false(
    ccs_media_retry_should_trigger(
      400, "{\"error\":{\"message\":\"Invalid API key\"}}", image_body,
    ),
  )
  assert_false(
    ccs_media_retry_should_trigger(
      429, "{\"error\":{\"message\":\"This model does not support image input\"}}",
      image_body,
    ),
  )

  let text_body = @json.parse(
    (
      #|{
      #|  "model": "any-model",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [{ "type": "text", "text": "hello" }]
      #|    }
      #|  ]
      #|}
    ),
  )
  assert_false(contains_image_blocks(text_body))
  assert_false(
    ccs_media_retry_should_trigger(
      400, "{\"error\":{\"message\":\"This model does not support image input\"}}",
      text_body,
    ),
  )
}

///|
test "ccs media retry replacement is unconditional" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "xiaomi-mimo-token-plan/mimo-v2.5-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let result = replace_image_blocks_with_marker(body)
  assert_eq(result.count, 1)
  guard result.body is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(marker) else { fail("expected marker") }
  assert_eq(marker["type"], Json::string("text"))
  assert_eq(marker["text"], Json::string("[Unsupported Image]"))
}

///|
test "ccs media retry handles streaming upstream bodies" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "max_tokens": 128,
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image_url",
      #|          "image_url": { "url": "data:image/png;base64,AAAA" }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let upstream = prepare_upstream_request_body(
    claude_stream_request_json_for_upstream(body, "kimi/kimi-k2.6"),
  )
  guard upstream is Object(obj) else { fail("expected object") }
  assert_eq(obj["stream"], Json::boolean(true))
  assert_true(contains_image_blocks(upstream))
  assert_true(
    ccs_media_retry_should_trigger(
      400, "{\"error\":{\"message\":\"This model does not support image input\"}}",
      upstream,
    ),
  )

  let retry_body = replace_image_blocks_with_marker(upstream)
  guard retry_body.body is Object(retry_obj) else { fail("expected retry") }
  assert_eq(retry_obj["stream"], Json::boolean(true))
  guard retry_obj["messages"] is Array(messages) else {
    fail("expected messages")
  }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(marker) else { fail("expected marker") }
  assert_eq(marker["type"], Json::string("text"))
  assert_eq(marker["text"], Json::string("[Unsupported Image]"))
}

///|
test "openai chat completion converts to anthropic response" {
  let body = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    {
      #|      "message": {
      #|        "role": "assistant",
      #|        "content": "done",
      #|        "tool_calls": [
      #|          {
      #|            "id": "call_1",
      #|            "type": "function",
      #|            "function": {
      #|              "name": "lookup",
      #|              "arguments": "{\"query\":\"moon\"}"
      #|            }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ],
      #|  "usage": {
      #|    "prompt_tokens": 10,
      #|    "completion_tokens": 2,
      #|    "prompt_tokens_details": { "cached_tokens": 3 }
      #|  }
      #|}
    ),
  )
  let response = openai_chat_completion_to_anthropic(body, "claude-sonnet-4-6")
  assert_eq(response.id, "chatcmpl_1")
  assert_eq(response.model, "claude-sonnet-4-6")
  assert_eq(response.stop_reason, Some("tool_use"))
  assert_eq(response.usage.input_tokens, 7)
  assert_eq(response.usage.output_tokens, 2)
  assert_eq(response.usage.cache_read_input_tokens, Some(3))
  assert_eq(response.content.length(), 2)
  assert_eq(response.content[0].type_, "text")
  assert_eq(response.content[0].text, Some("done"))
  assert_eq(response.content[1].type_, "tool_use")
  assert_eq(response.content[1].name, Some("lookup"))
  assert_eq(response.content[1].id, Some("call_1"))
}

///|
test "openai chat stream chunk converts to anthropic events" {
  let chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": { "content": "hi" },
      #|      "finish_reason": null
      #|    }
      #|  ]
      #|}
    ),
  )
  let events = openai_chat_stream_chunk_to_anthropic_events(chunk)
  assert_eq(events.length(), 3)
  assert_eq(events[0].event_type, "message_start")
  let start_data = @json.parse(events[0].data)
  guard start_data is Object(start_obj) else { fail("expected object") }
  guard start_obj["message"] is Object(message) else {
    fail("expected message")
  }
  assert_eq(message["id"], Json::string("chatcmpl_1"))
  assert_eq(message["model"], Json::string("gpt-4o"))
  assert_eq(events[1].event_type, "content_block_start")
  assert_eq(events[2].event_type, "content_block_delta")
  let event_data = @json.parse(events[2].data)
  guard event_data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["text"], Json::string("hi"))
}

///|
test "openai chat stream finalizes usage after done" {
  let state = OpenAIChatAnthropicStreamState::new()
  let chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": { "content": "hi" },
      #|      "finish_reason": null
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(chunk)
  let done = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": {},
      #|      "finish_reason": "tool_calls"
      #|    }
      #|  ],
      #|  "usage": {
      #|    "prompt_tokens": 9,
      #|    "completion_tokens": 3,
      #|    "prompt_tokens_details": { "cached_tokens": 2 }
      #|  }
      #|}
    ),
  )
  let prepared = state.push_chunk(done)
  assert_eq(prepared.length(), 1)
  assert_eq(prepared[0].event_type, "content_block_stop")
  let done_events = state.finish()
  assert_eq(done_events.length(), 2)
  assert_eq(done_events[0].event_type, "message_delta")
  assert_eq(done_events[1].event_type, "message_stop")
  let done_data = @json.parse(done_events[0].data)
  guard done_data is Object(done_obj) else { fail("expected object") }
  guard done_obj["delta"] is Object(done_delta) else { fail("expected delta") }
  assert_eq(done_delta["stop_reason"], Json::string("tool_use"))
  guard done_obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(7.0))
  assert_eq(usage["output_tokens"], Json::number(3.0))
  assert_eq(usage["cache_read_input_tokens"], Json::number(2.0))
}

///|
test "openai chat stream subtracts cache creation from prompt usage like ccs" {
  let state = OpenAIChatAnthropicStreamState::new()
  let chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_cache_create",
      #|  "model": "glm-5.1",
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": {
      #|        "tool_calls": [
      #|          {
      #|            "index": 0,
      #|            "id": "tool-1",
      #|            "function": { "name": "Bash", "arguments": "{\"command\":\"pwd\"}" }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(chunk)
  let done = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": {},
      #|      "finish_reason": "tool_calls"
      #|    }
      #|  ],
      #|  "usage": {
      #|    "prompt_tokens": 1000,
      #|    "completion_tokens": 50,
      #|    "prompt_tokens_details": { "cached_tokens": 600 },
      #|    "cache_creation_input_tokens": 300
      #|  }
      #|}
    ),
  )
  let _ = state.push_chunk(done)
  let done_events = state.finish()
  let done_data = @json.parse(done_events[0].data)
  guard done_data is Object(done_obj) else { fail("expected message delta") }
  guard done_obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(100.0))
  assert_eq(usage["output_tokens"], Json::number(50.0))
  assert_eq(usage["cache_read_input_tokens"], Json::number(600.0))
  assert_eq(usage["cache_creation_input_tokens"], Json::number(300.0))
}

///|
test "openai chat stream clamps fresh input when cache exceeds prompt" {
  let state = OpenAIChatAnthropicStreamState::new()
  let chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_cache_clamp",
      #|  "model": "glm-5.1",
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": { "content": "hi" }
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(chunk)
  let done = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": {},
      #|      "finish_reason": "stop"
      #|    }
      #|  ],
      #|  "usage": {
      #|    "prompt_tokens": 100,
      #|    "completion_tokens": 50,
      #|    "prompt_tokens_details": { "cached_tokens": 80 },
      #|    "cache_creation_input_tokens": 50
      #|  }
      #|}
    ),
  )
  let _ = state.push_chunk(done)
  let done_events = state.finish()
  let done_data = @json.parse(done_events[0].data)
  guard done_data is Object(done_obj) else { fail("expected message delta") }
  guard done_obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(0.0))
  assert_eq(usage["output_tokens"], Json::number(50.0))
  assert_eq(usage["cache_read_input_tokens"], Json::number(80.0))
  assert_eq(usage["cache_creation_input_tokens"], Json::number(50.0))
}

///|
test "openai chat stream tool calls keep distinct indexes" {
  let state = OpenAIChatAnthropicStreamState::new()
  let first = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_2",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    {
      #|      "delta": {
      #|        "tool_calls": [
      #|          {
      #|            "index": 0,
      #|            "id": "call_0",
      #|            "function": { "name": "first_tool" }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let second = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "delta": {
      #|        "tool_calls": [
      #|          {
      #|            "index": 1,
      #|            "id": "call_1",
      #|            "function": { "name": "second_tool" }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let args = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "delta": {
      #|        "tool_calls": [
      #|          { "index": 1, "function": { "arguments": "{\"b\":2}" } },
      #|          { "index": 0, "function": { "arguments": "{\"a\":1}" } }
      #|        ]
      #|      },
      #|      "finish_reason": "tool_calls"
      #|    }
      #|  ]
      #|}
    ),
  )
  let first_events = state.push_chunk(first)
  let second_events = state.push_chunk(second)
  let arg_events = state.push_chunk(args)
  assert_eq(first_events[1].event_type, "content_block_start")
  assert_eq(second_events[0].event_type, "content_block_start")
  let first_start = @json.parse(first_events[1].data)
  let second_start = @json.parse(second_events[0].data)
  guard first_start is Object(first_obj) else { fail("expected object") }
  guard second_start is Object(second_obj) else { fail("expected object") }
  assert_true(first_obj["index"] != second_obj["index"])
  let deltas = arg_events.filter(event => {
    event.event_type == "content_block_delta"
  })
  assert_eq(deltas.length(), 2)
  let delta_a = @json.parse(deltas[1].data)
  let delta_b = @json.parse(deltas[0].data)
  guard delta_a is Object(delta_a_obj) else { fail("expected delta") }
  guard delta_b is Object(delta_b_obj) else { fail("expected delta") }
  guard delta_a_obj["delta"] is Object(delta_a_payload) else {
    fail("expected payload")
  }
  guard delta_b_obj["delta"] is Object(delta_b_payload) else {
    fail("expected payload")
  }
  assert_eq(delta_a_payload["partial_json"], Json::string("{\"a\":1}"))
  assert_eq(delta_b_payload["partial_json"], Json::string("{\"b\":2}"))
}

///|
test "gateway detects active direct codex compatible provider" {
  let gateway = Gateway::new(port=0)
  let providers = [
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-openai",
      provider_name="OpenAI",
      provider_type=Some("codex"),
      base_url=Some("https://api.openai.com/v1"),
      api_key=Some("sk-test"),
    ),
  ]
  guard gateway.active_provider_target(providers) is Some(active) else {
    fail("expected active provider")
  }
  assert_true(active.provider_id == "codex-openai")
  assert_true(active.can_use_codex_compatible_upstream())
}

///|
test "gemini native stream emits cumulative text deltas" {
  let state = GeminiNativeAnthropicStreamState::new()
  let first = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_1",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    { "content": { "parts": [ { "text": "Hel" } ] } }
      #|  ],
      #|  "usageMetadata": { "promptTokenCount": 10, "totalTokenCount": 13 }
      #|}
    ),
  )
  let second = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_1",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": { "parts": [ { "text": "Hello" } ] }
      #|    }
      #|  ],
      #|  "usageMetadata": { "promptTokenCount": 10, "totalTokenCount": 15 }
      #|}
    ),
  )
  let first_events = state.push_chunk(first)
  let second_events = state.push_chunk(second)
  let finish_events = state.finish()
  assert_eq(first_events[0].event_type, "message_start")
  assert_eq(first_events[1].event_type, "content_block_start")
  let first_delta = @json.parse(first_events[2].data)
  let second_delta = @json.parse(second_events[0].data)
  guard first_delta is Object(first_obj) else { fail("expected first delta") }
  guard second_delta is Object(second_obj) else {
    fail("expected second delta")
  }
  guard first_obj["delta"] is Object(first_payload) else {
    fail("expected first payload")
  }
  guard second_obj["delta"] is Object(second_payload) else {
    fail("expected second payload")
  }
  assert_eq(first_payload["text"], Json::string("Hel"))
  assert_eq(second_payload["text"], Json::string("lo"))
  let message_delta = @json.parse(finish_events[1].data)
  guard message_delta is Object(done_obj) else { fail("expected done") }
  guard done_obj["delta"] is Object(done_delta) else {
    fail("expected done delta")
  }
  assert_eq(done_delta["stop_reason"], Json::string("end_turn"))
  guard done_obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(10.0))
  assert_eq(usage["output_tokens"], Json::number(5.0))
}

///|
test "gemini native stream keeps parallel no id tool calls distinct" {
  let state = GeminiNativeAnthropicStreamState::new()
  let chunk = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_tools",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          { "functionCall": { "name": "lookup", "args": { "city": "Tokyo" } } },
      #|          { "functionCall": { "name": "lookup", "args": { "city": "Osaka" } } }
      #|        ]
      #|      }
      #|    }
      #|  ],
      #|  "usageMetadata": { "promptTokenCount": 5, "totalTokenCount": 8 }
      #|}
    ),
  )
  let _ = state.push_chunk(chunk)
  let events = state.finish()
  let starts = events.filter(event => event.event_type == "content_block_start")
  assert_eq(starts.length(), 2)
  let first = @json.parse(starts[0].data)
  let second = @json.parse(starts[1].data)
  guard first is Object(first_obj) else { fail("expected first") }
  guard second is Object(second_obj) else { fail("expected second") }
  guard first_obj["content_block"] is Object(first_block) else {
    fail("expected first block")
  }
  guard second_obj["content_block"] is Object(second_block) else {
    fail("expected second block")
  }
  assert_eq(first_block["type"], Json::string("tool_use"))
  assert_eq(second_block["type"], Json::string("tool_use"))
  assert_true(first_block["id"] != second_block["id"])
  guard first_block["id"] is String(first_id) else { fail("expected first id") }
  guard second_block["id"] is String(second_id) else {
    fail("expected second id")
  }
  assert_true(first_id.has_prefix("gemini_synth_"))
  assert_true(second_id.has_prefix("gemini_synth_"))
  assert_eq(first_block["name"], Json::string("lookup"))
  assert_eq(second_block["name"], Json::string("lookup"))
  let deltas = events.filter(event => event.event_type == "content_block_delta")
  assert_eq(deltas.length(), 2)
  let delta_a = @json.parse(deltas[0].data)
  let delta_b = @json.parse(deltas[1].data)
  guard delta_a is Object(delta_a_obj) else { fail("expected delta") }
  guard delta_b is Object(delta_b_obj) else { fail("expected delta") }
  guard delta_a_obj["delta"] is Object(delta_a_payload) else {
    fail("expected payload")
  }
  guard delta_b_obj["delta"] is Object(delta_b_payload) else {
    fail("expected payload")
  }
  assert_eq(
    delta_a_payload["partial_json"],
    Json::string("{\"city\":\"Tokyo\"}"),
  )
  assert_eq(
    delta_b_payload["partial_json"],
    Json::string("{\"city\":\"Osaka\"}"),
  )
  let message_delta = @json.parse(events[6].data)
  guard message_delta is Object(done_obj) else { fail("expected done") }
  guard done_obj["delta"] is Object(done_delta) else {
    fail("expected done delta")
  }
  assert_eq(done_delta["stop_reason"], Json::string("tool_use"))
}

///|
test "gemini native stream shadow turn stores accumulated text signature" {
  let state = GeminiNativeAnthropicStreamState::new()
  let first = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_text_shadow",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    { "content": { "parts": [ { "text": "Hel" } ] } }
      #|  ]
      #|}
    ),
  )
  let second = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_text_shadow",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          { "text": "Hello" },
      #|          { "text": "", "thoughtSignature": "sig-text" }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(first)
  let _ = state.push_chunk(second)
  let _ = state.finish()
  guard state.shadow_turn() is Some(turn) else { fail("expected shadow turn") }
  guard turn.assistant_content is Object(content) else {
    fail("expected content")
  }
  guard content["parts"] is Array(parts) else { fail("expected parts") }
  guard parts[0] is Object(text_part) else { fail("expected text part") }
  assert_eq(text_part["text"], Json::string("Hello"))
  assert_eq(text_part["thoughtSignature"], Json::string("sig-text"))
}

///|
test "gemini native stream shadow turn preserves tool signature" {
  let state = GeminiNativeAnthropicStreamState::new()
  let first = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_tool_shadow",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "content": {
      #|        "parts": [
      #|          {
      #|            "functionCall": {
      #|              "id": "call_1",
      #|              "name": "lookup",
      #|              "args": { "city": "Tokyo" }
      #|            },
      #|            "thoughtSignature": "sig-tool"
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let second = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_tool_shadow",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          {
      #|            "functionCall": {
      #|              "id": "call_1",
      #|              "name": "lookup",
      #|              "args": { "city": "Tokyo", "units": "c" }
      #|            }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(first)
  let _ = state.push_chunk(second)
  let _ = state.finish()
  guard state.shadow_turn() is Some(turn) else { fail("expected shadow turn") }
  guard turn.assistant_content is Object(content) else {
    fail("expected content")
  }
  guard content["parts"] is Array(parts) else { fail("expected parts") }
  guard parts[0] is Object(tool_part) else { fail("expected tool part") }
  guard tool_part["functionCall"] is Object(function_call) else {
    fail("expected function call")
  }
  assert_eq(function_call["id"], Json::string("call_1"))
  assert_eq(function_call["name"], Json::string("lookup"))
  guard function_call["args"] is Object(args) else { fail("expected args") }
  assert_eq(args["city"], Json::string("Tokyo"))
  assert_eq(args["units"], Json::string("c"))
  assert_eq(tool_part["thoughtSignature"], Json::string("sig-tool"))
  assert_eq(turn.tool_calls.length(), 1)
  assert_eq(turn.tool_calls[0].thought_signature, Some("sig-tool"))
}

///|
test "gemini native stream prompt feedback becomes refusal" {
  let state = GeminiNativeAnthropicStreamState::new()
  let events = state.push_chunk(
    @json.parse(
      (
        #|{
        #|  "responseId": "resp_block",
        #|  "modelVersion": "gemini-2.5-pro",
        #|  "promptFeedback": { "blockReason": "SAFETY" },
        #|  "usageMetadata": { "promptTokenCount": 5, "totalTokenCount": 5 }
        #|}
      ),
    ),
  )
  assert_eq(events[0].event_type, "message_start")
  let finish_events = state.finish()
  let text_delta = @json.parse(finish_events[1].data)
  guard text_delta is Object(text_obj) else { fail("expected text delta") }
  guard text_obj["delta"] is Object(text_payload) else {
    fail("expected text payload")
  }
  guard text_payload["text"] is String(text) else { fail("expected text") }
  assert_true(text.contains("SAFETY"))
  let message_delta = @json.parse(finish_events[3].data)
  guard message_delta is Object(done_obj) else { fail("expected done") }
  guard done_obj["delta"] is Object(done_delta) else {
    fail("expected done delta")
  }
  assert_eq(done_delta["stop_reason"], Json::string("refusal"))
}

///|
test "gemini native claude compatible provider uses gemini url and headers" {
  assert_eq(
    claude_compatible_provider_url(
      "https://generativelanguage.googleapis.com", "/v1beta/models/gemini-2.5-pro:generateContent",
      "gemini_native", false,
    ),
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent",
  )
  let headers = claude_compatible_provider_headers(
    "gemini-key", "gemini_native",
  )
  assert_eq(headers["x-goog-api-key"], "gemini-key")
  assert_eq(headers["x-goog-api-client"], "GeminiCLI/1.0")
  assert_true(headers.get("Authorization") is None)
  assert_true(headers.get("anthropic-beta") is None)
}

///|
test "anthropic claude compatible provider sends ccs claude code beta headers" {
  let headers = claude_compatible_provider_headers("anthropic-key", "anthropic")
  assert_eq(headers["x-api-key"], "anthropic-key")
  assert_eq(headers["anthropic-version"], "2023-06-01")
  assert_eq(headers["anthropic-beta"], "claude-code-20250219")
  assert_true(headers.get("Authorization") is None)
}

///|
test "anthropic claude compatible provider preserves existing beta headers" {
  let headers = claude_compatible_provider_headers(
    "anthropic-key",
    "anthropic",
    anthropic_beta=Some("interleaved-thinking-2025-05-14"),
  )
  assert_eq(
    headers["anthropic-beta"],
    "claude-code-20250219,interleaved-thinking-2025-05-14",
  )
  let existing = claude_compatible_provider_headers(
    "anthropic-key",
    "anthropic",
    anthropic_beta=Some("claude-code-20250219,interleaved-thinking-2025-05-14"),
  )
  assert_eq(
    existing["anthropic-beta"],
    "claude-code-20250219,interleaved-thinking-2025-05-14",
  )
}

///|
test "gemini native response converts to anthropic message with usage" {
  let body = @json.parse(
    (
      #|{
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          { "text": "done" },
      #|          {
      #|            "functionCall": {
      #|              "id": "gem_call_1",
      #|              "name": "lookup",
      #|              "args": { "q": "moon" }
      #|            }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ],
      #|  "usageMetadata": {
      #|    "promptTokenCount": 10,
      #|    "totalTokenCount": 17,
      #|    "cachedContentTokenCount": 4
      #|  }
      #|}
    ),
  )
  let response = gemini_native_response_to_anthropic(body, "claude-sonnet-4-6")
  assert_eq(response.model, "claude-sonnet-4-6")
  assert_eq(response.stop_reason, Some("tool_use"))
  assert_eq(response.content.length(), 2)
  assert_eq(response.content[0].type_, "text")
  assert_eq(response.content[0].text, Some("done"))
  assert_eq(response.content[1].type_, "tool_use")
  assert_eq(response.content[1].name, Some("lookup"))
  assert_eq(response.content[1].id, Some("gem_call_1"))
  assert_eq(
    response.content[1].input,
    Some(Json::object({ "q": Json::string("moon") })),
  )
  assert_eq(response.usage.input_tokens, 6)
  assert_eq(response.usage.output_tokens, 7)
  assert_eq(response.usage.cache_read_input_tokens, Some(4))
}

///|
test "ccs config helpers normalize suite app paths" {
  assert_eq(ccs_normalize_app_type("claude_desktop"), "claude-desktop")
  assert_eq(ccs_normalize_app_type("open-code"), "opencode")
  assert_eq(ccs_normalize_app_type("omo_slim"), "omo-slim")
  assert_eq(ccs_normalize_app_type("unknown"), "claude")
  assert_eq(ccs_config_dir("codex"), @pathx.join(ccs_home_dir(), ".codex"))
  assert_eq(
    ccs_config_file_path("openclaw"),
    @pathx.join(ccs_config_dir("openclaw"), "openclaw.json"),
  )
  assert_eq(
    ccs_config_file_path("hermes"),
    @pathx.join(ccs_config_dir("hermes"), "config.yaml"),
  )
}

///|
async test "ccs config status keeps ccs object shape" {
  guard ccs_config_status_json("hermes") is Object(status) else {
    fail("expected status object")
  }
  assert_eq(status["path"], Json::string(ccs_config_dir("hermes")))
  assert_true(
    status["exists"] == Json::boolean(true) ||
    status["exists"] == Json::boolean(false),
  )
}

///|
test "ccs env helpers preserve conflicts and known keys" {
  assert_eq(ccs_env_conflict_keys("codex")[0], "OPENAI_API_KEY")
  assert_eq(ccs_env_conflict_keys("hermes")[1], "HERMES_WEB_PORT")
  assert_eq(ccs_env_conflict_keys("unknown")[0], "ANTHROPIC_API_KEY")
  let conflict = {
    "varName": Json::string("ANTHROPIC_API_KEY"),
    "varValue": Json::string("sk-test"),
  }.to_json()
  let body = { "conflicts": Json::array([conflict]) }.to_json()
  let conflicts = ccs_env_conflicts_from_body(Some(body))
  assert_eq(conflicts.length(), 1)
  assert_eq(conflicts[0], conflict)
  guard ccs_env_backup_json(Some(body)) is Object(backup) else {
    fail("expected backup object")
  }
  guard backup["backupPath"] is String(path) else {
    fail("expected backup path")
  }
  assert_true(path.contains(".cc-switch"))
  guard backup["timestamp"] is String(timestamp) else {
    fail("expected timestamp")
  }
  assert_true(!timestamp.is_empty())
  guard backup["conflicts"] is Array(backup_conflicts) else {
    fail("expected conflicts")
  }
  assert_eq(backup_conflicts.length(), 1)
  assert_eq(backup_conflicts[0], conflict)
}

///|
test "ccs mcp helpers preserve server apps and config shape" {
  let spec = {
    "name": Json::string("Filesystem"),
    "command": Json::string("npx"),
  }.to_json()
  let server = ccs_mcp_server_from_spec("filesystem", spec, "codex")
  guard server is Object(obj) else { fail("expected server object") }
  assert_eq(obj["id"], Json::string("filesystem"))
  assert_eq(obj["name"], Json::string("Filesystem"))
  assert_true(ccs_mcp_app_enabled(server, "codex"))
  assert_false(ccs_mcp_app_enabled(server, "claude"))
  let enabled = ccs_mcp_server_with_app(server, "claude", true)
  assert_true(ccs_mcp_app_enabled(enabled, "claude"))
  let servers : Map[String, Json] = { "filesystem": enabled }
  guard ccs_mcp_servers_object_for_app(servers, Some("codex")) is Object(codex) else {
    fail("expected codex mcp servers")
  }
  assert_true(codex.get("filesystem") is Some(_))
  guard ccs_mcp_config_text(servers) is Some(config_text) else {
    fail("expected mcp config")
  }
  assert_true(config_text.contains("\"mcpServers\""))
  assert_true(config_text.contains("\"filesystem\""))
}

///|
test "ccs mcp request parser accepts encoded server JSON" {
  let body = {
    "server": {
      "id": Json::string("shell"),
      "name": Json::string("Shell"),
      "server": { "command": Json::string("sh") }.to_json(),
    }.to_json(),
  }.to_json()
  guard ccs_mcp_server_from_request(
      "/upsert_mcp_server?app=codex",
      Some(body),
      "codex",
    )
    is Some((id, server)) else {
    fail("expected parsed server")
  }
  assert_eq(id, "shell")
  guard server is Object(obj) else { fail("expected normalized server") }
  assert_eq(obj["name"], Json::string("Shell"))
  assert_true(ccs_mcp_app_enabled(server, "codex"))
}

///|
test "ccs prompt helpers keep app-scoped prompt records" {
  guard ccs_prompt_from_request(
      "/upsert_prompt?app=codex&id=review&name=Review&content=Check%20this&description=Code%20review",
      None,
    )
    is Some((app, id, prompt)) else {
    fail("expected prompt")
  }
  assert_eq(app, "codex")
  assert_eq(id, "review")
  guard prompt is Object(obj) else { fail("expected prompt object") }
  assert_eq(obj["name"], Json::string("Review"))
  assert_eq(obj["content"], Json::string("Check this"))
  assert_eq(obj["enabled"], Json::boolean(true))
  let prompts : Map[String, Json] = {}
  prompts[ccs_prompt_store_key(app, id)] = prompt
  prompts[ccs_prompt_store_key("claude", "review")] = ccs_normalize_prompt(
    "review",
    { "content": Json::string("Claude") }.to_json(),
  )
  guard ccs_prompts_object_for_app(prompts, "codex") is Object(codex) else {
    fail("expected codex prompts")
  }
  assert_true(codex.get("review") is Some(_))
  guard ccs_prompts_object_for_app(prompts, "claude") is Object(claude) else {
    fail("expected claude prompts")
  }
  assert_true(claude.get("review") is Some(_))
}

///|
test "gemini native response synthesizes ccs marked missing tool id" {
  let body = @json.parse(
    (
      #|{
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          {
      #|            "functionCall": {
      #|              "name": "lookup",
      #|              "args": { "q": "moon" }
      #|            }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ],
      #|  "usageMetadata": {
      #|    "promptTokenCount": 10,
      #|    "totalTokenCount": 17
      #|  }
      #|}
    ),
  )
  let response = gemini_native_response_to_anthropic(body, "claude-sonnet-4-6")
  assert_eq(response.stop_reason, Some("tool_use"))
  assert_eq(response.content.length(), 1)
  assert_eq(response.content[0].type_, "tool_use")
  guard response.content[0].id is Some(id) else {
    fail("expected synthesized id")
  }
  assert_true(id.has_prefix("gemini_synth_"))
}

///|
test "gemini native prompt block converts to anthropic refusal" {
  let response = gemini_native_response_to_anthropic(
    @json.parse(
      (
        #|{
        #|  "promptFeedback": { "blockReason": "SAFETY" },
        #|  "usageMetadata": { "promptTokenCount": 5, "totalTokenCount": 5 }
        #|}
      ),
    ),
    "claude-sonnet-4-6",
  )
  assert_eq(response.stop_reason, Some("refusal"))
  assert_eq(response.content.length(), 1)
  assert_eq(response.content[0].type_, "text")
}
