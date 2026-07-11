///|
test "moongate client builds core endpoint URLs" {
  let client = MoonGateClient::new(base_url="http://127.0.0.1:4199/")
  assert_eq(client.base_url, "http://127.0.0.1:4199")
  assert_eq(client.health_url(), "http://127.0.0.1:4199/health")
  assert_eq(client.status_url(), "http://127.0.0.1:4199/status")
  assert_eq(client.stats_url(), "http://127.0.0.1:4199/stats")
  assert_eq(client.metrics_url(), "http://127.0.0.1:4199/metrics")
  assert_eq(client.models_url(), "http://127.0.0.1:4199/v1/models")
  assert_eq(
    client.route_chat_url(),
    "http://127.0.0.1:4199/v1/chat/completions",
  )
  assert_eq(
    client.route_openclaw_chat_url(),
    "http://127.0.0.1:4199/openclaw/v1/chat/completions",
  )
  assert_eq(client.route_response_url(), "http://127.0.0.1:4199/v1/responses")
  assert_eq(
    client.route_response_compact_url(),
    "http://127.0.0.1:4199/v1/responses/compact",
  )
  assert_eq(client.route_messages_url(), "http://127.0.0.1:4199/v1/messages")
  assert_eq(
    client.usage_data_sources_url(),
    "http://127.0.0.1:4199/usage/data-sources",
  )
  assert_eq(
    client.usage_model_pricing_url(),
    "http://127.0.0.1:4199/usage/model-pricing",
  )
}

///|
test "moongate host client maps wildcard host to loopback" {
  let client = MoonGateClient::from_host(host="0.0.0.0", port=15722)
  assert_eq(client.base_url, "http://127.0.0.1:15722")
}

///|
test "moongate client keeps inference and control credentials separate" {
  let client = MoonGateClient::new(
    api_key=Some("provider-key"),
    control_token=Some("control-key"),
  )
  let headers = client.headers(
    "GET",
    resolved_control_token=client.control_token,
  )
  assert_eq(headers["Authorization"], "Bearer provider-key")
  assert_eq(headers["x-moongate-control-token"], "control-key")
}

///|
test "moongate client builds usage query URLs" {
  let client = MoonGateClient::new(base_url="http://127.0.0.1:4199")
  let query = {
    start_date: Some("10"),
    end_date: Some("20"),
    app_type: Some("codex"),
    provider_id: Some("Codex OAuth"),
    provider_name: None,
    model: None,
    status_code: None,
    page: Some(2),
    page_size: Some(25),
  }
  assert_eq(
    client.usage_logs_url(query=Some(query)),
    "http://127.0.0.1:4199/usage/logs?startDate=10&endDate=20&appType=codex&providerId=Codex%20OAuth&page=2&pageSize=25",
  )
  assert_eq(
    client.usage_summary_url(query=Some(query)),
    "http://127.0.0.1:4199/usage/summary?startDate=10&endDate=20&appType=codex&providerId=Codex%20OAuth&page=2&pageSize=25",
  )
  assert_eq(
    client.usage_summary_by_app_url(query=Some(query)),
    "http://127.0.0.1:4199/usage/summary/by-app?startDate=10&endDate=20&appType=codex&providerId=Codex%20OAuth&page=2&pageSize=25",
  )
  assert_eq(
    client.usage_trends_url(query=Some(query)),
    "http://127.0.0.1:4199/usage/trends?startDate=10&endDate=20&appType=codex&providerId=Codex%20OAuth&page=2&pageSize=25",
  )
  assert_eq(
    client.usage_provider_stats_url(query=Some(query)),
    "http://127.0.0.1:4199/usage/provider-stats?startDate=10&endDate=20&appType=codex&providerId=Codex%20OAuth&page=2&pageSize=25",
  )
  assert_eq(
    client.usage_model_stats_url(query=Some(query)),
    "http://127.0.0.1:4199/usage/model-stats?startDate=10&endDate=20&appType=codex&providerId=Codex%20OAuth&page=2&pageSize=25",
  )
}

///|
test "moongate client builds required endpoint parameters" {
  let client = MoonGateClient::new(base_url="http://127.0.0.1:4199")
  assert_eq(
    client.usage_provider_limits_url("claude", "provider/a b"),
    "http://127.0.0.1:4199/usage/provider-limits?appType=claude&providerId=provider%2Fa%20b",
  )
  assert_eq(
    client.usage_provider_usage_url("claude", "provider/a b"),
    "http://127.0.0.1:4199/usage/provider-usage?appType=claude&providerId=provider%2Fa%20b",
  )
  assert_eq(
    client.usage_request_detail_url("req/a b"),
    "http://127.0.0.1:4199/usage/request-detail/req%2Fa%20b",
  )
  assert_eq(
    client.usage_delete_model_pricing_url("model/a b"),
    "http://127.0.0.1:4199/usage/model-pricing?modelId=model%2Fa%20b",
  )
  assert_eq(
    client.proxy_app_config_url("claude desktop"),
    "http://127.0.0.1:4199/proxy/app-config?appType=claude%20desktop",
  )
  assert_eq(
    client.proxy_default_cost_multiplier_url("codex"),
    "http://127.0.0.1:4199/proxy/default-cost-multiplier?appType=codex",
  )
  assert_eq(
    client.proxy_pricing_model_source_url("codex"),
    "http://127.0.0.1:4199/proxy/pricing-model-source?appType=codex",
  )
  assert_eq(
    client.proxy_provider_health_url("codex", "provider/a b"),
    "http://127.0.0.1:4199/proxy/provider-health?providerId=provider%2Fa%20b&appType=codex",
  )
  assert_eq(
    client.proxy_circuit_breaker_stats_url("codex", "provider/a b"),
    "http://127.0.0.1:4199/proxy/circuit-breaker-stats?providerId=provider%2Fa%20b&appType=codex",
  )
  assert_eq(
    client.proxy_failover_queue_url("openclaw"),
    "http://127.0.0.1:4199/proxy/failover-queue?appType=openclaw",
  )
  assert_eq(
    client.proxy_available_failover_providers_url("openclaw"),
    "http://127.0.0.1:4199/proxy/available-failover-providers?appType=openclaw",
  )
  assert_eq(
    client.proxy_auto_failover_enabled_url("openclaw"),
    "http://127.0.0.1:4199/proxy/auto-failover-enabled?appType=openclaw",
  )
}

///|
test "moongate client builds proxy mutation URLs" {
  let client = MoonGateClient::new(base_url="http://127.0.0.1:4199")
  assert_eq(client.proxy_start_url(), "http://127.0.0.1:4199/proxy/start")
  assert_eq(
    client.proxy_stop_with_restore_url(),
    "http://127.0.0.1:4199/proxy/stop-with-restore",
  )
  assert_eq(
    client.proxy_update_global_config_url(
      proxy_enabled=Some("false"),
      listen_address=Some("127.0.0.2"),
      listen_port=Some("17002"),
      enable_logging=Some("off"),
    ),
    "http://127.0.0.1:4199/proxy/global-config?proxyEnabled=false&listenAddress=127.0.0.2&listenPort=17002&enableLogging=off",
  )
  assert_eq(
    client.proxy_update_global_config_url(),
    "http://127.0.0.1:4199/proxy/global-config",
  )
  assert_eq(
    client.proxy_set_global_url_url("http://127.0.0.1:7890"),
    "http://127.0.0.1:4199/proxy/global-url?url=http%3A%2F%2F127.0.0.1%3A7890",
  )
  assert_eq(
    client.proxy_test_url_url("socks5://127.0.0.1:1080"),
    "http://127.0.0.1:4199/proxy/test-url?url=socks5%3A%2F%2F127.0.0.1%3A1080",
  )
  assert_eq(
    client.proxy_update_app_config_url(
      "codex",
      enabled=Some("true"),
      auto_failover_enabled=Some("false"),
      max_retries=Some("5"),
      streaming_first_byte_timeout=Some("11"),
      streaming_idle_timeout=Some("22"),
      non_streaming_timeout=Some("33"),
      failure_threshold=Some("7"),
      success_threshold=Some("3"),
      timeout_seconds=Some("44"),
      error_rate_threshold=Some("0.4"),
      min_requests=Some("12"),
    ),
    "http://127.0.0.1:4199/proxy/app-config?appType=codex&enabled=true&autoFailoverEnabled=false&maxRetries=5&streamingFirstByteTimeout=11&streamingIdleTimeout=22&nonStreamingTimeout=33&failureThreshold=7&successThreshold=3&timeoutSeconds=44&errorRateThreshold=0.4&minRequests=12",
  )
  assert_eq(
    client.proxy_set_default_cost_multiplier_url("codex", "1.25"),
    "http://127.0.0.1:4199/proxy/default-cost-multiplier?appType=codex&value=1.25",
  )
  assert_eq(
    client.proxy_set_pricing_model_source_url("codex", "request"),
    "http://127.0.0.1:4199/proxy/pricing-model-source?appType=codex&value=request",
  )
  assert_eq(
    client.proxy_update_circuit_breaker_config_url("7", "3", "44", "0.4", "12"),
    "http://127.0.0.1:4199/proxy/circuit-breaker-config?failureThreshold=7&successThreshold=3&timeoutSeconds=44&errorRateThreshold=0.4&minRequests=12",
  )
  assert_eq(
    client.proxy_reset_circuit_breaker_url("codex", "provider/a b"),
    "http://127.0.0.1:4199/proxy/reset-circuit-breaker?providerId=provider%2Fa%20b&appType=codex",
  )
  assert_eq(
    client.proxy_add_failover_queue_url("codex", "provider/a b"),
    "http://127.0.0.1:4199/proxy/failover-queue?providerId=provider%2Fa%20b&appType=codex",
  )
  assert_eq(
    client.proxy_remove_failover_queue_url("codex", "provider/a b"),
    "http://127.0.0.1:4199/proxy/failover-queue?providerId=provider%2Fa%20b&appType=codex",
  )
  assert_eq(
    client.proxy_set_auto_failover_enabled_url("codex", "true"),
    "http://127.0.0.1:4199/proxy/auto-failover-enabled?appType=codex&enabled=true",
  )
  assert_eq(
    client.proxy_set_takeover_status_url("codex", "true"),
    "http://127.0.0.1:4199/proxy/takeover-status?appType=codex&enabled=true",
  )
  assert_eq(
    client.proxy_switch_provider_url("codex", "codex oauth"),
    "http://127.0.0.1:4199/proxy/switch-provider?providerId=codex%20oauth&appType=codex",
  )
}

///|
test "moongate client omits empty usage query values" {
  let client = MoonGateClient::new(base_url="   ")
  assert_eq(client.base_url, "http://127.0.0.1:15721")
  let query = {
    start_date: Some(""),
    end_date: None,
    app_type: Some("  "),
    provider_id: None,
    provider_name: Some("Codex OAuth"),
    model: Some("anthropic/claude-sonnet"),
    status_code: Some("200"),
    page: None,
    page_size: Some(50),
  }
  assert_eq(
    client.usage_logs_url(query=Some(query)),
    "http://127.0.0.1:15721/usage/logs?providerName=Codex%20OAuth&model=anthropic%2Fclaude-sonnet&statusCode=200&pageSize=50",
  )
  assert_eq(
    client.usage_logs_url(query=Some(MoonGateUsageQuery::empty())),
    "http://127.0.0.1:15721/usage/logs",
  )
}

///|
test "moongate client builds session sync URLs" {
  let client = MoonGateClient::new(base_url="http://127.0.0.1:4199")
  let query = {
    projects_dir: Some("/tmp/Claude Projects"),
    codex_dir: Some(""),
    gemini_dir: Some("  "),
    opencode_export_path: Some("/tmp/open code.jsonl"),
    opencode_db_path: Some("/tmp/opencode.db"),
  }
  assert_eq(
    client.usage_sync_session_url(query=Some(query)),
    "http://127.0.0.1:4199/usage/sync-session?projectsDir=%2Ftmp%2FClaude%20Projects&opencodeExportPath=%2Ftmp%2Fopen%20code.jsonl&opencodeDbPath=%2Ftmp%2Fopencode.db",
  )
  assert_eq(
    client.usage_sync_session_url(query=Some(MoonGateSessionSyncQuery::empty())),
    "http://127.0.0.1:4199/usage/sync-session",
  )
}

///|
fn moongate_client_contract_path(url : String) -> String {
  let without_origin = match url.find("://") {
    Some(scheme_index) => {
      let after_scheme = url[scheme_index + 3:]
      match after_scheme.find("/") {
        Some(path_index) => after_scheme[path_index:].to_owned()
        None => "/"
      }
    }
    None => url
  }
  match without_origin.find("?") {
    Some(query_index) => without_origin[:query_index].to_owned()
    None => without_origin
  }
}

///|
fn moongate_manifest_advertises_client_path(
  routes : Array[Json],
  path : String,
) -> Bool {
  routes.any(route => {
    guard route is String(value) else { return false }
    value.contains(" \{path}") ||
    (value.has_suffix("/*path") && path.has_prefix(value[4:value.length() - 5]))
  })
}

///|
test "moongate client helper paths are advertised by suite manifest" {
  let client = MoonGateClient::new(base_url="http://127.0.0.1:4199")
  let manifest = moongate_suite_manifest_json(port=4199)
  guard manifest is Object(obj) else { fail("expected manifest object") }
  guard obj["routes"] is Array(routes) else { fail("expected routes") }
  let urls = [
    client.health_url(),
    client.status_url(),
    client.stats_url(),
    client.metrics_url(),
    client.models_url(),
    client.route_chat_url(),
    client.route_openclaw_chat_url(),
    client.route_response_url(),
    client.route_response_compact_url(),
    client.route_messages_url(),
    client.usage_logs_url(),
    client.usage_summary_url(),
    client.usage_summary_by_app_url(),
    client.usage_trends_url(),
    client.usage_provider_limits_url("claude", "provider/a b"),
    client.usage_provider_usage_url("claude", "provider/a b"),
    client.usage_provider_stats_url(),
    client.usage_model_stats_url(),
    client.usage_data_sources_url(),
    client.usage_model_pricing_url(),
    client.usage_delete_model_pricing_url("model/a b"),
    client.usage_sync_session_url(),
    client.usage_request_detail_url("req/a b"),
    client.proxy_status_url(),
    client.proxy_running_url(),
    client.proxy_global_config_url(),
    client.proxy_global_url_url(),
    client.proxy_upstream_status_url(),
    client.proxy_local_proxies_url(),
    client.proxy_app_config_url("codex"),
    client.proxy_default_cost_multiplier_url("codex"),
    client.proxy_pricing_model_source_url("codex"),
    client.proxy_circuit_breaker_config_url(),
    client.proxy_provider_health_url("codex", "provider/a b"),
    client.proxy_circuit_breaker_stats_url("codex", "provider/a b"),
    client.proxy_failover_queue_url("codex"),
    client.proxy_available_failover_providers_url("codex"),
    client.proxy_auto_failover_enabled_url("codex"),
    client.proxy_takeover_status_url(),
    client.proxy_start_url(),
    client.proxy_stop_url(),
    client.proxy_stop_with_restore_url(),
    client.proxy_update_global_config_url(),
    client.proxy_set_global_url_url("http://127.0.0.1:7890"),
    client.proxy_test_url_url("socks5://127.0.0.1:1080"),
    client.proxy_update_app_config_url("codex"),
    client.proxy_set_default_cost_multiplier_url("codex", "1.25"),
    client.proxy_set_pricing_model_source_url("codex", "request"),
    client.proxy_update_circuit_breaker_config_url("7", "3", "44", "0.4", "12"),
    client.proxy_reset_circuit_breaker_url("codex", "provider/a b"),
    client.proxy_add_failover_queue_url("codex", "provider/a b"),
    client.proxy_remove_failover_queue_url("codex", "provider/a b"),
    client.proxy_set_auto_failover_enabled_url("codex", "true"),
    client.proxy_set_takeover_status_url("codex", "true"),
    client.proxy_switch_provider_url("codex", "codex oauth"),
  ]
  assert_true(urls.length() > 50)
  for url in urls {
    let path = moongate_client_contract_path(url)
    assert_true(moongate_manifest_advertises_client_path(routes, path))
  }
}

///|
test "moongate client discovers from suite status manifest" {
  let status = moongate_suite_status_json(host="0.0.0.0", port=15722)
  let client = MoonGateClient::from_suite_status(status).unwrap()
  assert_eq(client.base_url, "http://127.0.0.1:15722")
  assert_eq(
    moongate_base_url_from_suite_status(status),
    Some("http://127.0.0.1:15722"),
  )
}

///|
test "moongate client requires suite status and manifest contracts" {
  let root_base = { "base_url": Json::string("http://127.0.0.1:4199/") }.to_json()
  assert_true(MoonGateClient::from_suite_status(root_base) is None)
  let health_only = {
    "health_url": Json::string("http://127.0.0.1:4299/health"),
  }.to_json()
  assert_true(MoonGateClient::from_suite_status(health_only) is None)
  let manifest_only = {
    "manifest": { "base_url": Json::string("http://127.0.0.1:4199") }.to_json(),
  }.to_json()
  assert_true(MoonGateClient::from_suite_status(manifest_only) is None)
  let snake_case_manifest = {
    "contract": Json::string(@suite.status_contract()),
    "service": Json::string("moongate"),
    "manifest": {
      "contract": Json::string(@suite.manifest_contract()),
      "service": Json::string("moongate"),
      "base_url": Json::string("http://127.0.0.1:4199"),
    }.to_json(),
  }.to_json()
  assert_true(MoonGateClient::from_suite_status(snake_case_manifest) is None)
  let wrong_status_contract = {
    "contract": Json::string("moon.suite.status.v1"),
    "service": Json::string("moongate"),
    "manifest": moongate_suite_manifest_json(port=4199),
  }.to_json()
  assert_true(MoonGateClient::from_suite_status(wrong_status_contract) is None)
  let wrong_manifest_contract = {
    "contract": Json::string(@suite.status_contract()),
    "service": Json::string("moongate"),
    "manifest": {
      "contract": Json::string("moon.suite.service.v0"),
      "service": Json::string("moongate"),
      "baseUrl": Json::string("http://127.0.0.1:4199"),
    }.to_json(),
  }.to_json()
  assert_true(
    MoonGateClient::from_suite_status(wrong_manifest_contract) is None,
  )
}

///|
test "moongate client parses typed agent clients from suite status" {
  let status = moongate_suite_status_json(
    host="127.0.0.1",
    port=18081,
    model="gpt-5",
  )
  guard moongate_agent_clients_from_suite_status(status) is Ok(clients) else {
    fail("expected parsed agent clients")
  }
  assert_eq(clients.length(), 8)
  guard moongate_client_agent_client_by_id(clients, "codex") is Some(codex) else {
    fail("expected codex agent client")
  }
  assert_eq(codex.app_type, "codex")
  assert_eq(codex.protocol, "openai-responses")
  assert_eq(codex.base_url, "http://127.0.0.1:18081/v1")
  assert_eq(codex.primary_route, "POST /v1/responses")
  assert_eq(
    codex.setup_command,
    Some("moongate codex install --port 18081 --model gpt-5"),
  )
  guard moongate_client_agent_client_by_id(clients, "openclaw")
    is Some(openclaw) else {
    fail("expected openclaw agent client")
  }
  assert_eq(openclaw.app_type, "openclaw")
  assert_eq(openclaw.base_url, "http://127.0.0.1:18081/openclaw/v1")
  assert_eq(openclaw.primary_route, "POST /openclaw/v1/chat/completions")
  guard moongate_client_agent_client_by_id(clients, "gemini") is Some(gemini) else {
    fail("expected gemini agent client")
  }
  assert_eq(gemini.protocol, "gemini-compatible")
  assert_eq(gemini.setup_command, None)
}

///|
test "moongate client rejects malformed agent client contracts" {
  assert_true(
    moongate_agent_clients_from_manifest(
      { "agentClients": Json::array([]) }.to_json(),
    )
    is Err(_),
  )
  let wrong_status_contract = {
    "contract": Json::string("moon.suite.status.v1"),
    "service": Json::string("moongate"),
    "manifest": moongate_suite_manifest_json(port=18081),
  }.to_json()
  assert_true(
    moongate_agent_clients_from_suite_status(wrong_status_contract) is Err(_),
  )
  let missing_id_manifest = moongate_suite_manifest_json(port=18081)
  guard missing_id_manifest is Object(manifest_obj) else {
    fail("expected manifest object")
  }
  manifest_obj["agentClients"] = Json::array([
    {
      "appType": Json::string("codex"),
      "protocol": Json::string("openai-compatible"),
      "baseUrl": Json::string("http://127.0.0.1:18081/v1"),
      "primaryRoute": Json::string("POST /v1/chat/completions"),
    }.to_json(),
  ])
  assert_true(
    moongate_agent_clients_from_manifest(Json::object(manifest_obj)) is Err(_),
  )
}

///|
fn moongate_client_agent_client_by_id(
  clients : Array[MoonGateAgentClient],
  id : String,
) -> MoonGateAgentClient? {
  for client in clients {
    if client.id == id {
      return Some(client)
    }
  }
  None
}

///|
test "moongate client parses typed models from suite response shapes" {
  let catalog = {
    "models": [
      {
        "slug": Json::string("gpt-5"),
        "owned_by": Json::string("openai"),
        "context_window": Json::number(128000.0),
      },
      { "id": Json::string("moon/local") },
    ],
  }.to_json()
  guard moongate_models_from_json(catalog) is Ok(models) else {
    fail("expected parsed models")
  }
  assert_eq(models.length(), 2)
  assert_eq(models[0].id, "gpt-5")
  assert_eq(models[0].owner, Some("openai"))
  assert_eq(models[0].context_window, Some(128000))
  assert_eq(models[1].id, "moon/local")
  assert_true(models[1].owner is None)
}

///|
test "moongate client rejects malformed typed model entries" {
  assert_true(
    moongate_models_from_json(Json::array([Json::object({})])) is Err(_),
  )
  assert_true(moongate_models_from_json(Json::object({})) is Err(_))
}

///|
test "moongate client parses typed usage summary" {
  let summary = {
    "totalRequests": Json::number(3.0),
    "totalCost": Json::string("0.000300"),
    "totalInputTokens": Json::number(100.0),
    "totalOutputTokens": Json::number(20.0),
    "totalCacheCreationTokens": Json::number(7.0),
    "totalCacheReadTokens": Json::number(11.0),
    "successRate": Json::number(66.7),
    "realTotalTokens": Json::number(127.0),
    "cacheHitRate": Json::number(12.5),
  }.to_json()
  guard MoonGateUsageSummary::from_json(summary) is Ok(parsed) else {
    fail("expected parsed usage summary")
  }
  assert_eq(parsed.total_requests, 3)
  assert_eq(parsed.total_cost, "0.000300")
  assert_eq(parsed.total_input_tokens, 100L)
  assert_eq(parsed.total_output_tokens, 20L)
  assert_eq(parsed.total_cache_creation_tokens, 7L)
  assert_eq(parsed.total_cache_read_tokens, 11L)
  assert_eq(parsed.real_total_tokens, 127L)
  assert_eq(parsed.success_rate, 66.7)
  assert_eq(parsed.cache_hit_rate, 12.5)
}

///|
async test "moongate client discover reads status file and falls back" {
  @fsx.with_temporary_directory("moongate-client-discover-XXXXXX", tmpdir => {
    let path = @pathx.join(tmpdir, "suite-status.json")
    @fsx.write_to_file(
      path,
      moongate_suite_status_json(host="127.0.0.1", port=4307).stringify(),
    )
    assert_eq(MoonGateClient::discover(path~).base_url, "http://127.0.0.1:4307")
    assert_eq(
      MoonGateClient::discover(path=@pathx.join(tmpdir, "missing.json")).base_url,
      "http://127.0.0.1:15721",
    )
  })
}
