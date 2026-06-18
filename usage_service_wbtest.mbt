///|
test "usage service exposes stats and metrics without gateway" {
  let usage = UsageService::new()
  usage.stats.record_inbound(120)
  usage.stats.record_success(11, 17, 240)
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
}

///|
async test "usage service owns usage report json without gateway" {
  let usage = UsageService::new()
  usage.stats.record_inbound(64)
  usage.stats.record_request_context(
    "codex",
    "gpt-5",
    outbound_model=Some("gpt-5-upstream"),
    session_id=Some("session-1"),
    provider_type=Some("openai_chat"),
  )
  usage.stats.record_stream_mode(false)
  usage.stats.record_success_usage(
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
