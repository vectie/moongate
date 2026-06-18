///|
test "moonstat client builds core endpoint URLs" {
  let client = MoonstatClient::new(base_url="http://127.0.0.1:4199/")
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
test "moonstat host client maps wildcard host to loopback" {
  let client = MoonstatClient::from_host(host="0.0.0.0", port=15722)
  assert_eq(client.base_url, "http://127.0.0.1:15722")
}

///|
test "moonstat client builds usage query URLs" {
  let client = MoonstatClient::new(base_url="http://127.0.0.1:4199")
  let query = {
    start_date: Some("10"),
    end_date: Some("20"),
    app_type: Some("codex"),
    provider_id: Some("Codex OAuth"),
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
test "moonstat client builds required endpoint parameters" {
  let client = MoonstatClient::new(base_url="http://127.0.0.1:4199")
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
}

///|
test "moonstat client omits empty usage query values" {
  let client = MoonstatClient::new(base_url="   ")
  assert_eq(client.base_url, "http://127.0.0.1:15721")
  let query = {
    start_date: Some(""),
    end_date: None,
    app_type: Some("  "),
    provider_id: None,
    page: None,
    page_size: Some(50),
  }
  assert_eq(
    client.usage_logs_url(query=Some(query)),
    "http://127.0.0.1:15721/usage/logs?pageSize=50",
  )
  assert_eq(
    client.usage_logs_url(query=Some(MoonstatUsageQuery::empty())),
    "http://127.0.0.1:15721/usage/logs",
  )
}

///|
test "moonstat client builds session sync URLs" {
  let client = MoonstatClient::new(base_url="http://127.0.0.1:4199")
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
    client.usage_sync_session_url(query=Some(MoonstatSessionSyncQuery::empty())),
    "http://127.0.0.1:4199/usage/sync-session",
  )
}

///|
test "moonstat client discovers from suite status manifest" {
  let status = moonstat_suite_status_json(host="0.0.0.0", port=15722)
  let client = MoonstatClient::from_suite_status(status).unwrap()
  assert_eq(client.base_url, "http://127.0.0.1:15722")
  assert_eq(
    moonstat_base_url_from_suite_status(status),
    Some("http://127.0.0.1:15722"),
  )
}

///|
test "moonstat client discovers from root status urls" {
  let root_base = { "base_url": Json::string("http://127.0.0.1:4199/") }.to_json()
  assert_eq(
    MoonstatClient::from_suite_status(root_base).unwrap().base_url,
    "http://127.0.0.1:4199",
  )
  let health_only = {
    "health_url": Json::string("http://127.0.0.1:4299/health"),
  }.to_json()
  assert_eq(
    MoonstatClient::from_suite_status(health_only).unwrap().base_url,
    "http://127.0.0.1:4299",
  )
}

///|
test "moonstat client parses typed models from suite response shapes" {
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
  guard moonstat_models_from_json(catalog) is Ok(models) else {
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
test "moonstat client rejects malformed typed model entries" {
  assert_true(
    moonstat_models_from_json(Json::array([Json::object({})])) is Err(_),
  )
  assert_true(moonstat_models_from_json(Json::object({})) is Err(_))
}

///|
test "moonstat client parses typed usage summary" {
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
  guard MoonstatUsageSummary::from_json(summary) is Ok(parsed) else {
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
async test "moonstat client discover reads status file and falls back" {
  @fsx.with_temporary_directory("moonstat-client-discover-XXXXXX", tmpdir => {
    let path = @pathx.join(tmpdir, "suite-status.json")
    @fsx.write_to_file(
      path,
      moonstat_suite_status_json(host="127.0.0.1", port=4307).stringify(),
    )
    assert_eq(MoonstatClient::discover(path~).base_url, "http://127.0.0.1:4307")
    assert_eq(
      MoonstatClient::discover(path=@pathx.join(tmpdir, "missing.json")).base_url,
      "http://127.0.0.1:15721",
    )
  })
}
