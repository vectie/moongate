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
  })
}

///|
test "traffic status json matches ccs proxy status shape" {
  let stats = TrafficStats::new()
  stats.record_inbound(10)
  stats.record_bad_request()
  stats.last_request_at = Some("test-timestamp")
  let status = stats.status_json(
    "127.0.0.1", 15721, 3, "Codex OAuth", "codex-oauth", "Codex",
  )
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
        "app_type": "Codex",
        "provider_id": "codex-oauth",
        "provider_name": "Codex OAuth",
      },
    ],
  })
}
