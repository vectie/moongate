///|
test "traffic stats records proxy counters" {
  let stats = TrafficStats::new()
  stats.record_inbound(120)
  stats.record_stream_mode(false)
  stats.record_unauthorized()
  stats.record_inbound(80)
  stats.record_stream_mode(true)
  stats.record_success(11, 17, 240)
  stats.last_request_at = Some("test-timestamp")
  let json = stats.to_json()
  json_inspect(json, content={
    "active_connections": 0,
    "total_requests": 2,
    "message_requests": 2,
    "streaming_requests": 1,
    "non_streaming_requests": 1,
    "successful_responses": 1,
    "failed_responses": 1,
    "success_requests": 1,
    "failed_requests": 1,
    "success_rate": 50,
    "unauthorized_responses": 1,
    "bad_requests": 0,
    "upstream_errors": 0,
    "input_tokens": 11,
    "output_tokens": 17,
    "cache_read_tokens": 0,
    "cache_creation_tokens": 0,
    "request_bytes": 200,
    "response_bytes": 240,
    "last_request_at": "test-timestamp",
    "last_error": null,
    "recent_request_log_count": 2,
  })
}

///|
test "traffic status json matches ccs proxy status shape" {
  let stats = TrafficStats::new()
  stats.record_inbound(10)
  stats.record_bad_request()
  stats.set_active_target("codex", "codex-oauth", "Codex OAuth")
  stats.last_request_at = Some("test-timestamp")
  let status = stats.status_json("127.0.0.1", 15721, 3)
  json_inspect(status, content={
    "running": true,
    "address": "127.0.0.1",
    "port": 15721,
    "active_connections": 0,
    "total_requests": 1,
    "success_requests": 0,
    "failed_requests": 1,
    "success_rate": 0,
    "uptime_seconds": 3,
    "current_provider": "Codex OAuth",
    "current_provider_id": "codex-oauth",
    "last_request_at": "test-timestamp",
    "last_error": "bad_request",
    "failover_count": 0,
    "active_targets": [
      {
        "app_type": "codex",
        "provider_id": "codex-oauth",
        "provider_name": "Codex OAuth",
      },
    ],
  })
}

///|
test "traffic status tracks ccs active targets by app type" {
  let stats = TrafficStats::new()
  stats.set_active_target("claude", "codex-oauth", "Codex OAuth")
  stats.set_active_target("gemini", "gemini-api-key", "Gemini API Key")
  stats.set_active_target("gemini", "gemini-api-key-2", "Gemini API Key 2")
  guard stats.active_targets.get("claude") is Some(claude) else {
    fail("expected claude active target")
  }
  guard stats.active_targets.get("gemini") is Some(gemini) else {
    fail("expected gemini active target")
  }
  json_inspect(active_target_json(claude), content={
    "app_type": "claude",
    "provider_id": "codex-oauth",
    "provider_name": "Codex OAuth",
  })
  json_inspect(active_target_json(gemini), content={
    "app_type": "gemini",
    "provider_id": "gemini-api-key-2",
    "provider_name": "Gemini API Key 2",
  })
  assert_eq(stats.failover_count, 1)
}

///|
test "request log json matches ccs proxy_request_logs shape" {
  let usage = TokenUsage::new(
    input_tokens=13,
    output_tokens=21,
    cache_read_tokens=5,
    cache_creation_tokens=2,
  )
  let log = RequestLog::new(
    request_id="req-test",
    provider_id="provider-1",
    provider_name=Some("Provider One"),
    app_type="claude",
    model="claude-sonnet-4-6",
    request_model=Some("claude-sonnet-4-6"),
    pricing_model=Some("claude-sonnet-4-6"),
    usage~,
    input_cost_usd="0.000001",
    output_cost_usd="0.000002",
    cache_read_cost_usd="0.000003",
    cache_creation_cost_usd="0.000004",
    total_cost_usd="0.000010",
    status_code=200,
    latency_ms=37,
    first_token_ms=Some(12),
    duration_ms=Some(41),
    session_id=Some("session-1"),
    provider_type=Some("claude"),
    is_streaming=true,
    cost_multiplier="1.0",
    created_at=123456,
    data_source="proxy",
  )
  json_inspect(log.to_json(), content={
    "request_id": "req-test",
    "provider_id": "provider-1",
    "provider_name": "Provider One",
    "app_type": "claude",
    "model": "claude-sonnet-4-6",
    "request_model": "claude-sonnet-4-6",
    "pricing_model": "claude-sonnet-4-6",
    "cost_multiplier": "1.0",
    "input_tokens": 13,
    "output_tokens": 21,
    "cache_read_tokens": 5,
    "cache_creation_tokens": 2,
    "input_cost_usd": "0.000001",
    "output_cost_usd": "0.000002",
    "cache_read_cost_usd": "0.000003",
    "cache_creation_cost_usd": "0.000004",
    "total_cost_usd": "0.000010",
    "is_streaming": true,
    "latency_ms": 37,
    "first_token_ms": 12,
    "duration_ms": 41,
    "status_code": 200,
    "error_message": null,
    "session_id": "session-1",
    "provider_type": "claude",
    "created_at": 123456,
    "data_source": "proxy",
  })
}

///|
test "traffic stats writes request logs from request context" {
  let stats = TrafficStats::new()
  stats.record_inbound(64)
  stats.set_active_target("codex", "codex-oauth", "Codex OAuth")
  stats.record_request_context(
    "codex",
    "gpt-5",
    session_id=Some("session-2"),
    provider_type=Some("codex"),
  )
  stats.record_stream_mode(false)
  stats.record_success_usage(
    TokenUsage::new(input_tokens=3, output_tokens=4, model=Some("gpt-5")),
    128,
  )
  assert_eq(stats.request_logs.length(), 1)
  let log = stats.request_logs[0]
  assert_true(log.request_id.has_prefix("req_"))
  assert_eq(log.provider_id, "codex-oauth")
  assert_eq(log.provider_name, Some("Codex OAuth"))
  assert_eq(log.app_type, "codex")
  assert_eq(log.model, "gpt-5")
  assert_eq(log.request_model, Some("gpt-5"))
  assert_eq(log.pricing_model, Some("gpt-5"))
  assert_eq(log.input_tokens, 3)
  assert_eq(log.output_tokens, 4)
  assert_eq(log.status_code, 200)
  assert_eq(log.error_message, None)
  assert_eq(log.session_id, Some("session-2"))
  assert_eq(log.provider_type, Some("codex"))
  assert_false(log.is_streaming)
  json_inspect(stats.usage_logs_json(limit=1), content={
    "data": [log.to_json()],
    "total": 1,
    "limit": 1,
    "source": "memory",
    "table": "proxy_request_logs",
  })
}

///|
test "traffic stats keeps request log retention bounded" {
  let stats = TrafficStats::new()
  for i in 0..<505 {
    stats.record_request_log(
      RequestLog::new(
        request_id="req-\{i}",
        provider_id="provider",
        app_type="codex",
        model="gpt-5",
        usage=TokenUsage::empty(),
        status_code=200,
        created_at=i,
      ),
    )
  }
  assert_eq(stats.request_logs.length(), 500)
  assert_eq(stats.request_logs[0].request_id, "req-5")
  assert_eq(stats.request_logs[499].request_id, "req-504")
}
