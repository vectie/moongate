///|
test "usage service exposes stats and metrics without gateway" {
  let usage = UsageService::new()
  let request = usage.begin_request(120)
  usage.stats.record_success(request.context, 11, 17, 240)
  usage.stats.last_request_at = Some("test-timestamp")
  let json = usage.stats_json()
  json_inspect(json, content={
    "active_connections": 0,
    "total_requests": 1,
    "message_requests": 1,
    "streaming_requests": 0,
    "non_streaming_requests": 0,
    "successful_responses": 1,
    "failed_responses": 0,
    "success_requests": 1,
    "failed_requests": 0,
    "success_rate": 100,
    "unauthorized_responses": 0,
    "bad_requests": 0,
    "upstream_errors": 0,
    "input_tokens": 11,
    "output_tokens": 17,
    "cache_read_tokens": 0,
    "cache_creation_tokens": 0,
    "request_bytes": 120,
    "response_bytes": 240,
    "last_request_at": "test-timestamp",
    "last_error": null,
    "recent_request_log_count": 1,
  })
  let metrics = usage.metrics_text()
  assert_true(metrics.contains("moonstat_requests_total 1"))
  assert_true(metrics.contains("moonstat_successful_responses_total 1"))
  let combined = usage.metrics_text(
    provider_metrics="moonstat_provider_configured{app_type=\"codex\",provider_id=\"codex-oauth\"} 1\n",
  )
  assert_true(combined.contains("moonstat_requests_total 1"))
  assert_true(
    combined.contains(
      "moonstat_provider_configured{app_type=\"codex\",provider_id=\"codex-oauth\"} 1",
    ),
  )
}

///|
test "usage service owns health response shape" {
  let usage = UsageService::new()
  let request = usage.begin_request(24)
  request.finish()
  guard usage.health_json(true) is Object(health) else {
    fail("expected health object")
  }
  assert_eq(health["status"], Json::string("healthy"))
  assert_eq(health["credentials_loaded"], Json::boolean(true))
  guard health["stats"] is Object(stats) else { fail("expected stats object") }
  assert_eq(stats["total_requests"], Json::number(1.0))
  assert_true(health["timestamp"] is String(_))
}

///|
async test "usage service owns proxy status target and pricing state" {
  let usage = UsageService::new()
  usage.set_active_target("codex", "codex-oauth", "Codex OAuth")
  guard usage.status_json(
      "127.0.0.1",
      4199,
      12,
      provider_routes=Some({ "codex": Json::string("codex-oauth") }.to_json()),
    )
    is Object(status) else {
    fail("expected status object")
  }
  assert_true(status["running"] is true)
  assert_true(status["address"] is String("127.0.0.1"))
  assert_true(status["port"] is Number(4199.0, ..))
  assert_true(status["uptime_seconds"] is Number(12.0, ..))
  assert_true(status["current_provider_id"] is String("codex-oauth"))
  assert_true(status.get("provider_routes") is Some(Object(_)))

  usage.delete_model_pricing("moonstat-test-model")
  assert_true(
    !usage.model_pricing_json().stringify().contains("moonstat-test-model"),
  )
  let pricing = mp("moonstat-test-model", "Moonstat Test", "2", "4", "0", "0")
  let _backfilled = usage.upsert_model_pricing(pricing)
  assert_eq(usage.pricing_override_rows().length(), 1)
  assert_true(usage.model_pricing_json().stringify().contains("Moonstat Test"))
}

///|
test "usage service owns stream first-event timing" {
  let usage = UsageService::new()
  let request = usage.begin_request(4)
  assert_true(request.first_stream_event_ms(Some(12)) is Some(12))
  guard request.first_stream_event_ms(None) is Some(elapsed) else {
    fail("expected first event timing")
  }
  assert_true(elapsed >= 0)
}

///|
test "usage service owns provider bookkeeping context" {
  let usage = UsageService::new()
  let request = usage.begin_request(0)
  assert_true(request.provider_request_context() is None)
  request.activate_provider_target(
    "codex",
    "codex-oauth",
    "Codex OAuth",
    used_half_open_permit=true,
    cost_multiplier="1.5",
    pricing_model_source="request",
  )
  assert_true(request.current_provider_id() is Some("codex-oauth"))
  assert_eq(request.context.cost_multiplier, "1.5")
  assert_eq(request.context.pricing_model_source, "request")

  request.record_request_context("codex", "gpt-5")
  guard request.provider_request_context() is Some(context) else {
    fail("expected provider context")
  }
  assert_eq(context.app_type, "codex")
  assert_eq(context.provider_id, "codex-oauth")
  assert_true(context.used_half_open_permit)

  request.set_last_error("upstream_error")
  assert_true(usage.stats.last_error is Some("upstream_error"))
  usage.set_provider_limits(
    "codex-oauth",
    "codex",
    daily_limit_usd=Some("1.25"),
    monthly_limit_usd=Some("9.50"),
  )
  let limit_status = usage.provider_limit_status_json("codex-oauth", "codex")
  assert_true(limit_status.stringify().contains("1.25"))
  assert_true(limit_status.stringify().contains("9.50"))
}

///|
async test "usage service owns usage report json without gateway" {
  let usage = UsageService::new()
  let request = usage.begin_request(64)
  request.record_request_context(
    "codex",
    "gpt-5",
    outbound_model=Some("gpt-5-upstream"),
    session_id=Some("session-1"),
    provider_type=Some("openai_chat"),
  )
  request.record_stream_mode(false)
  usage.stats.record_success_usage(
    request.context,
    TokenUsage::new(
      input_tokens=5,
      output_tokens=7,
      cache_read_tokens=3,
      cache_creation_tokens=2,
      model=Some("gpt-5-upstream"),
    ),
    128,
  )
  let request_id = usage.stats.request_logs[0].request_id
  json_inspect(usage.summary_json(app_type=Some("codex")), content={
    "totalRequests": 1,
    "totalCost": "0.000000",
    "totalInputTokens": 2,
    "totalOutputTokens": 7,
    "totalCacheCreationTokens": 2,
    "totalCacheReadTokens": 3,
    "successRate": 100,
    "realTotalTokens": 14,
    "cacheHitRate": 0.42857142857142855,
  })
  guard usage.usage_logs_json(
      RequestLogFilters::new(app_type=Some("codex")),
      0,
      10,
      [],
    )
    is Object(logs) else {
    fail("expected logs object")
  }
  assert_eq(logs.get("total"), Some(Json::number(1)))
  guard usage.request_detail_json(request_id, []) is Object(detail) else {
    fail("expected request detail object")
  }
  assert_eq(detail.get("requestId"), Some(Json::string(request_id)))
  assert_true(
    usage
    .provider_stats_json(app_type=Some("codex"))
    .stringify()
    .contains("unknown"),
  )
  assert_true(
    usage
    .model_stats_json(app_type=Some("codex"))
    .stringify()
    .contains("gpt-5-upstream"),
  )
  assert_true(
    usage
    .trends_json(app_type=Some("codex"))
    .stringify()
    .contains("totalTokens"),
  )
  assert_true(usage.data_sources_json().stringify().contains("proxy"))
}

///|
async test "usage service owns completion and error accounting without gateway" {
  let usage = UsageService::new()
  let request = usage.begin_request(32)
  usage.set_active_target("codex", "openai", "OpenAI")
  request.activate_provider_target("codex", "openai", "OpenAI")
  request.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("openai_chat"),
  )
  request.record_stream_mode(false)
  request.record_success_usage(
    TokenUsage::new(input_tokens=3, output_tokens=5, model=Some("gpt-5")),
    64,
    [],
  )
  assert_eq(usage.stats.total_requests, 1)
  assert_eq(usage.stats.successful_responses, 1)
  assert_eq(usage.stats.input_tokens, 3)
  assert_eq(usage.stats.output_tokens, 5)
  assert_eq(usage.stats.request_logs.length(), 1)

  let request = usage.begin_request(16)
  request.record_request_context("codex", "gpt-5")
  request.record_stream_mode(true)
  request.record_success_stream_usage(None, 24, [], skip_empty_usage=true)
  assert_eq(usage.stats.total_requests, 2)
  assert_eq(usage.stats.successful_responses, 2)
  assert_eq(usage.stats.request_logs.length(), 1)

  usage.begin_request(8).record_bad_request()
  usage.begin_request(8).record_unauthorized()
  usage.begin_request(8).record_upstream_error_status(19, 502)
  usage.begin_request(8).record_internal_error()
  assert_eq(usage.stats.total_requests, 6)
  assert_eq(usage.stats.failed_responses, 4)
  assert_eq(usage.stats.bad_requests, 1)
  assert_eq(usage.stats.unauthorized_responses, 1)
  assert_eq(usage.stats.upstream_errors, 1)
  assert_eq(usage.stats.last_error, Some("internal_error"))
}

///|
async test "usage service owns startup persistent store reconciliation" {
  let dir = @pathx.join(
    "/tmp",
    "moonstat-usage-service-startup-\{@async.now().to_int()}",
  )
  let seed = TrafficStats::new()
  seed.enable_persistent_store(storage_dir=dir)
  seed.record_request_log(
    RequestLog::new(
      request_id="req-startup-rollup",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5",
      request_model=Some("gpt-5"),
      pricing_model=Some("gpt-5"),
      usage=TokenUsage::new(
        input_tokens=2,
        output_tokens=3,
        model=Some("gpt-5"),
      ),
      status_code=200,
      latency_ms=7,
      created_at=1,
      data_source="proxy",
    ),
  )
  seed.save_persistent_store()

  let usage = UsageService::new()
  let (backfilled, pruned) = usage.load_and_reconcile_persistent_store(
    [],
    storage_dir=dir,
  )
  assert_eq(backfilled, 1)
  assert_eq(pruned, 1)
  assert_eq(usage.stats.request_logs.length(), 0)
  assert_eq(usage.stats.daily_rollups.length(), 1)

  let loaded = TrafficStats::new()
  loaded.load_persistent_store(storage_dir=dir)
  assert_eq(loaded.request_logs.length(), 0)
  assert_eq(loaded.daily_rollups.length(), 1)
  assert_eq(loaded.daily_rollups[0].request_count, 1)
}

///|
async test "usage service owns session sync persistence" {
  let dir = @pathx.join(
    "/tmp",
    "moonstat-usage-service-sync-\{@async.now().to_int()}",
  )
  let claude_dir = @pathx.join(dir, "claude-projects")
  let codex_dir = @pathx.join(dir, "codex")
  let gemini_dir = @pathx.join(dir, "gemini")
  @fsx.make_directory(claude_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(codex_dir, recursive=true, exists_ok=true)
  @fsx.make_directory(gemini_dir, recursive=true, exists_ok=true)

  let usage = UsageService::new()
  usage.stats.enable_persistent_store(storage_dir=dir)
  usage.stats.session_sync_state.set(
    "/tmp/moonstat-sync-service/source.jsonl",
    SessionFileSyncState::new(last_modified=7L, last_line_offset=9),
  )
  let result = usage.sync_session_logs(
    claude_dir,
    codex_dir,
    gemini_dir,
    @pathx.join(dir, "opencode.db"),
    @pathx.join(dir, "opencode.jsonl"),
  )
  assert_eq(result.imported, 0)

  let loaded = TrafficStats::new()
  loaded.load_persistent_store(storage_dir=dir)
  guard loaded.session_sync_state.get("/tmp/moonstat-sync-service/source.jsonl")
    is Some(state) else {
    fail("expected sync state to be persisted")
  }
  assert_eq(state.last_modified, 7L)
  assert_eq(state.last_line_offset, 9)
}

///|
async test "usage service owns model pricing backfill persistence" {
  let dir = @pathx.join(
    "/tmp",
    "moonstat-usage-service-pricing-\{@async.now().to_int()}",
  )
  let usage = UsageService::new()
  usage.stats.enable_persistent_store(storage_dir=dir)
  usage.stats.record_request_log(
    RequestLog::new(
      request_id="req-service-pricing",
      provider_id="codex-oauth",
      app_type="codex",
      model="moonstat-service-priced",
      usage=TokenUsage::new(input_tokens=10, output_tokens=5),
      total_cost_usd="0",
      status_code=200,
      created_at=1,
    ),
  )
  let backfilled = usage.upsert_model_pricing(
    mp("moonstat-service-priced", "Moonstat Service Priced", "2", "4", "0", "0"),
  )
  assert_eq(backfilled, 1)
  assert_eq(usage.stats.request_logs[0].total_cost_usd, "0.00004")

  let loaded = TrafficStats::new()
  loaded.load_persistent_store(storage_dir=dir)
  assert_eq(loaded.request_logs.length(), 1)
  assert_eq(loaded.request_logs[0].total_cost_usd, "0.00004")
}
