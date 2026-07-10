///|
async test "persistent store reloads request logs and session sync state" {
  let dir = @pathx.join(
    "/tmp",
    "moonstat-store-roundtrip-\{@async.now().to_int()}",
  )
  let stats = TrafficStats::new()
  stats.enable_persistent_store(storage_dir=dir)
  stats.record_request_log(
    RequestLog::new(
      request_id="req-store-1",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5.5",
      request_model=Some("gpt-5.5"),
      pricing_model=Some("gpt-5.5"),
      usage=TokenUsage::new(
        input_tokens=10,
        output_tokens=4,
        cache_read_tokens=2,
        model=Some("gpt-5.5"),
      ),
      status_code=200,
      latency_ms=12,
      first_token_ms=Some(3),
      duration_ms=Some(12),
      session_id=Some("session-store"),
      provider_type=Some("codex"),
      is_streaming=true,
      input_cost_usd="0.000001",
      output_cost_usd="0.000002",
      cache_read_cost_usd="0.000000",
      total_cost_usd="0.000003",
      created_at=42,
      data_source="proxy",
    ),
  )
  assert_eq(stats.rollup_request_logs_before(100), 1)
  assert_eq(stats.request_logs.length(), 0)
  assert_eq(stats.daily_rollups.length(), 1)
  stats.session_sync_state.set(
    "/tmp/source.jsonl",
    SessionFileSyncState::new(last_modified=7L, last_line_offset=9),
  )
  stats.save_persistent_store()
  assert_true(@fsx.exists_as_file(@pathx.join(dir, MOONSTAT_USAGE_STORE_FILE)))
  assert_false(
    @fsx.exists_as_file(@pathx.join(dir, MOONSTAT_REQUEST_LOGS_FILE)),
  )

  let loaded = TrafficStats::new()
  loaded.load_persistent_store(storage_dir=dir)
  assert_eq(loaded.request_logs.length(), 0)
  assert_eq(loaded.daily_rollups.length(), 1)
  let rollup = loaded.daily_rollups[0]
  assert_eq(rollup.provider_id, "codex-oauth")
  assert_eq(rollup.provider_name, Some("Codex OAuth"))
  assert_eq(rollup.app_type, "codex")
  assert_eq(rollup.input_tokens, 10)
  assert_eq(rollup.cache_read_tokens, 2)
  assert_eq(rollup.request_count, 1)
  guard loaded.usage_logs_json() is Object(usage_logs) else {
    fail("usage logs json should be an object")
  }
  assert_eq(usage_logs["source"], Json::string("file"))
  guard loaded.session_sync_state.get("/tmp/source.jsonl") is Some(state) else {
    fail("missing persisted session state")
  }
  assert_eq(state.last_modified, 7L)
  assert_eq(state.last_line_offset, 9)
}

///|
async test "persistent store migrates legacy jsonl into versioned snapshot" {
  let dir = @pathx.join(
    "/tmp",
    "moonstat-store-legacy-\{@async.now().to_int()}",
  )
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  let legacy_log = RequestLog::new(
    request_id="req-legacy",
    provider_id="openai",
    provider_name=Some("OpenAI"),
    app_type="codex",
    model="gpt-5",
    usage=TokenUsage::new(input_tokens=2, output_tokens=3),
    status_code=200,
    created_at=42,
  )
  @fsx.write_to_file(
    @pathx.join(dir, MOONSTAT_REQUEST_LOGS_FILE),
    legacy_log.to_json().stringify(),
  )
  @fsx.write_to_file(
    @pathx.join(dir, MOONSTAT_SESSION_SYNC_FILE),
    {
      "filePath": Json::string("/tmp/legacy.jsonl"),
      "lastModified": Json::number(9),
      "lastLineOffset": Json::number(4),
    }
    .to_json()
    .stringify(),
  )

  let loaded = TrafficStats::new()
  loaded.load_persistent_store(storage_dir=dir)
  assert_eq(loaded.request_logs.length(), 1)
  assert_eq(loaded.request_logs[0].request_id, "req-legacy")
  assert_true(loaded.storage_healthy)
  assert_true(@fsx.exists_as_file(@pathx.join(dir, MOONSTAT_USAGE_STORE_FILE)))
  let snapshot = @json.parse(
    @fsx.read_file(@pathx.join(dir, MOONSTAT_USAGE_STORE_FILE)),
  )
  guard snapshot is Object(obj) else { fail("expected snapshot object") }
  assert_eq(obj["schemaVersion"], Json::number(1))
}

///|
async test "persistent store reports truncated snapshot as degraded" {
  let dir = @pathx.join(
    "/tmp",
    "moonstat-store-truncated-\{@async.now().to_int()}",
  )
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  @fsx.write_to_file(@pathx.join(dir, MOONSTAT_USAGE_STORE_FILE), "{")
  let usage = UsageService::new()
  let stats = usage.stats
  stats.load_persistent_store(storage_dir=dir)
  assert_false(stats.storage_healthy)
  assert_eq(stats.storage_failure_count, 1)
  assert_true(stats.storage_last_error.unwrap_or("").contains("parse_snapshot"))
  guard stats.storage_health_json() is Object(storage) else {
    fail("expected storage health")
  }
  assert_eq(storage["healthy"], Json::boolean(false))
  assert_true(stats.prometheus_metrics().contains("moonstat_storage_healthy 0"))
  assert_true(
    stats.prometheus_metrics().contains("moonstat_storage_failures_total 1"),
  )
}

///|
async test "persistent store ignores interrupted temporary snapshot" {
  let dir = @pathx.join(
    "/tmp",
    "moonstat-store-interrupted-\{@async.now().to_int()}",
  )
  let stats = TrafficStats::new()
  stats.enable_persistent_store(storage_dir=dir)
  stats.record_request_log(
    RequestLog::new(
      request_id="req-committed",
      provider_id="openai",
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::empty(),
      status_code=200,
    ),
  )
  stats.save_persistent_store()
  @fsx.write_to_file(
    @pathx.join(dir, "\{MOONSTAT_USAGE_STORE_FILE}.tmp-crash"),
    "{\"schemaVersion\":1",
  )

  let loaded = TrafficStats::new()
  loaded.load_persistent_store(storage_dir=dir)
  assert_true(loaded.storage_healthy)
  assert_eq(loaded.request_logs.length(), 1)
  assert_eq(loaded.request_logs[0].request_id, "req-committed")
}

///|
async test "persistent store surfaces unavailable directory without losing memory state" {
  let blocked = @pathx.join(
    "/tmp",
    "moonstat-store-blocked-\{@async.now().to_int()}",
  )
  @fsx.write_to_file(blocked, "not a directory")
  let usage = UsageService::new()
  let stats = usage.stats
  stats.enable_persistent_store(storage_dir=blocked)
  stats.record_request_log(
    RequestLog::new(
      request_id="req-memory",
      provider_id="openai",
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::empty(),
      status_code=200,
    ),
  )
  stats.save_persistent_store()
  assert_false(stats.storage_healthy)
  assert_true(stats.storage_failure_count >= 1)
  assert_eq(stats.request_logs.length(), 1)
  guard usage.health_json(true) is Object(health) else {
    fail("expected health object")
  }
  assert_eq(health["status"], Json::string("degraded"))
}

///|
async test "persistent store reports failed atomic replacement and cleans temp file" {
  let dir = @pathx.join(
    "/tmp",
    "moonstat-store-rename-\{@async.now().to_int()}",
  )
  @fsx.make_directory(
    @pathx.join(dir, MOONSTAT_USAGE_STORE_FILE),
    recursive=true,
    exists_ok=true,
  )
  let stats = TrafficStats::new()
  stats.enable_persistent_store(storage_dir=dir)
  stats.save_persistent_store()
  assert_false(stats.storage_healthy)
  assert_true(stats.storage_last_error.unwrap_or("").contains("write_snapshot"))
  for name in @fs.readdir(dir) {
    assert_false(name.contains(".tmp-"))
  }
}

///|
async test "persistent store keeps session sync offsets across stats restart" {
  let dir = @pathx.join(
    "/tmp",
    "moonstat-store-session-offset-\{@async.now().to_int()}",
  )
  let file_path = "/tmp/moonstat-store-session-offset/source.jsonl"
  let content =
    #|{"type":"assistant","message":{"id":"msg_a","model":"unknown","usage":{"input_tokens":1,"output_tokens":2}},"timestamp":"1970-01-01T00:00:30Z"}
  let stats = TrafficStats::new()
  stats.enable_persistent_store(storage_dir=dir)
  let first_result = stats.ingest_claude_session_jsonl(
    file_path~,
    content~,
    last_modified=1L,
  )
  assert_eq(first_result.imported, 1)
  stats.save_persistent_store()

  let loaded = TrafficStats::new()
  loaded.load_persistent_store(storage_dir=dir)
  let skipped_result = loaded.ingest_claude_session_jsonl(
    file_path~,
    content~,
    last_modified=1L,
  )
  assert_eq(skipped_result.imported, 0)
  assert_eq(skipped_result.skipped, 0)
  assert_eq(loaded.request_logs.length(), 1)
}

///|
async test "persistent store preserves aggregates beyond detail retention" {
  let dir = @pathx.join(
    "/tmp",
    "moonstat-store-retention-\{@async.now().to_int()}",
  )
  let stats = TrafficStats::new()
  stats.enable_persistent_store(storage_dir=dir)
  for i in 0..<1_000 {
    stats.record_request_log(
      RequestLog::new(
        request_id="req-store-retention-\{i}",
        provider_id="provider-store",
        app_type="codex",
        model="gpt-store",
        usage=TokenUsage::new(input_tokens=2, output_tokens=3),
        total_cost_usd="0.000005",
        status_code=200,
        created_at=1_700_000_000,
        data_source="proxy",
      ),
    )
  }
  stats.save_persistent_store()

  let loaded = TrafficStats::new()
  loaded.load_persistent_store(storage_dir=dir)
  assert_eq(loaded.request_logs.length(), REQUEST_LOG_LIMIT)
  assert_eq(loaded.daily_rollups.length(), 1)
  assert_eq(loaded.daily_rollups[0].request_count, 500)
  guard loaded.usage_summary_json() is Object(summary) else {
    fail("expected reloaded usage summary")
  }
  assert_eq(summary["totalRequests"], Json::number(1_000.0))
  assert_eq(summary["totalInputTokens"], Json::number(2_000.0))
  assert_eq(summary["totalOutputTokens"], Json::number(3_000.0))
  assert_eq(summary["totalCost"], Json::string("0.005000"))
}

///|
async test "gateway completion records are persisted automatically" {
  let dir = @pathx.join(
    "/tmp",
    "moonstat-store-gateway-live-\{@async.now().to_int()}",
  )
  let gateway = Gateway::new(port=0)
  gateway.usage.stats.enable_persistent_store(storage_dir=dir)
  let success_request = gateway.usage.begin_request(32)
  gateway.usage.stats.set_active_target("codex", "codex-oauth", "Codex OAuth")
  success_request.activate_provider_target(
    "codex", "codex-oauth", "Codex OAuth",
  )
  success_request.record_request_context(
    "codex",
    "gpt-5.5",
    session_id=Some("live-session"),
    provider_type=Some("codex"),
  )
  success_request.record_success_usage_with_provider(
    gateway.proxy,
    TokenUsage::new(
      input_tokens=11,
      output_tokens=7,
      cache_read_tokens=3,
      model=Some("gpt-5.5"),
    ),
    128,
  )

  let failure_request = gateway.usage.begin_request(12)
  gateway.usage.stats.set_active_target(
    "gemini", "gemini-api-key", "Gemini API Key",
  )
  failure_request.activate_provider_target(
    "gemini", "gemini-api-key", "Gemini API Key",
  )
  failure_request.record_request_context(
    "gemini",
    "gemini-2.5-pro",
    provider_type=Some("gemini"),
  )
  failure_request.record_upstream_error_status_with_provider(
    gateway.proxy,
    64,
    502,
  )

  let loaded = TrafficStats::new()
  loaded.load_persistent_store(storage_dir=dir)
  assert_eq(loaded.request_logs.length(), 2)
  let success = loaded.request_logs[0]
  assert_eq(success.app_type, "codex")
  assert_eq(success.model, "gpt-5.5")
  assert_eq(success.input_tokens, 11)
  assert_eq(success.output_tokens, 7)
  assert_eq(success.cache_read_tokens, 3)
  assert_eq(success.status_code, 200)
  assert_eq(success.session_id, Some("live-session"))
  let failure = loaded.request_logs[1]
  assert_eq(failure.app_type, "gemini")
  assert_eq(failure.model, "gemini-2.5-pro")
  assert_eq(failure.status_code, 502)
  assert_eq(failure.error_message, Some("upstream_error"))
}
