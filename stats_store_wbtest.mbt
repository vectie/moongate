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
async test "gateway completion records are persisted automatically" {
  let dir = @pathx.join(
    "/tmp",
    "moonstat-store-gateway-live-\{@async.now().to_int()}",
  )
  let gateway = Gateway::new(port=0)
  gateway.stats.enable_persistent_store(storage_dir=dir)
  gateway.stats.record_inbound(32)
  gateway.stats.set_active_target("codex", "codex-oauth", "Codex OAuth")
  gateway.stats.record_request_context(
    "codex",
    "gpt-5.5",
    session_id=Some("live-session"),
    provider_type=Some("codex"),
  )
  gateway.record_success_usage(
    TokenUsage::new(
      input_tokens=11,
      output_tokens=7,
      cache_read_tokens=3,
      model=Some("gpt-5.5"),
    ),
    128,
  )

  gateway.stats.record_inbound(12)
  gateway.stats.set_active_target("gemini", "gemini-api-key", "Gemini API Key")
  gateway.stats.record_request_context(
    "gemini",
    "gemini-2.5-pro",
    provider_type=Some("gemini"),
  )
  gateway.record_upstream_error_status(64, 502)

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
