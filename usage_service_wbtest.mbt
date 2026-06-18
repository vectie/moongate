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
