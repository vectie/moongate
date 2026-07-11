///|
test "moongate usage records proxy counters" {
  let stats = TrafficStats::new()
  let unauthorized = stats.begin_request(120)
  stats.record_stream_mode(unauthorized, false)
  stats.record_unauthorized(unauthorized)
  let success = stats.begin_request(80)
  stats.record_stream_mode(success, true)
  stats.record_success(success, 11, 17, 240)
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
test "traffic status json matches moongate proxy status shape" {
  let stats = TrafficStats::new()
  let request = stats.begin_request(10)
  stats.record_bad_request(request)
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
    "storage": {
      "enabled": false,
      "healthy": true,
      "failure_count": 0,
      "last_error": null,
      "last_success_at": null,
    },
  })
}

///|
test "traffic status tracks moongate active targets by app type" {
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
test "request log json matches moongate proxy_request_logs shape" {
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
test "moongate usage writes request logs from request context" {
  let stats = TrafficStats::new()
  let request = stats.begin_request(64)
  stats.set_active_target("codex", "codex-oauth", "Codex OAuth")
  request.set_active_target("codex", "codex-oauth", "Codex OAuth")
  request.set_request_context("codex", "gpt-5", session_id=Some("session-2"))
  stats.record_stream_mode(request, false)
  stats.record_success_usage(
    request,
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
  assert_eq(log.input_cost_usd, "0.00000375")
  assert_eq(log.output_cost_usd, "0.00004")
  assert_eq(log.cache_read_cost_usd, "0")
  assert_eq(log.cache_creation_cost_usd, "0")
  assert_eq(log.total_cost_usd, "0.00004375")
  assert_eq(log.status_code, 200)
  assert_eq(log.error_message, None)
  assert_eq(log.session_id, Some("session-2"))
  assert_eq(log.provider_type, None)
  assert_false(log.is_streaming)
  json_inspect(stats.usage_logs_json(limit=1), content={
    "data": [log.to_moon_request_log_detail_json()],
    "total": 1,
    "limit": 1,
    "source": "memory",
    "table": "proxy_request_logs",
  })
}

///|
test "moongate usage uses moongate session request id for message usage" {
  let stats = TrafficStats::new()
  let request = stats.begin_request(64)
  stats.set_active_target("claude", "anthropic", "Anthropic")
  request.set_active_target("claude", "anthropic", "Anthropic")
  request.set_request_context(
    "claude",
    "claude-sonnet-4-6",
    session_id=Some("session-2"),
  )
  stats.record_stream_mode(request, true)
  stats.record_success_usage(
    request,
    TokenUsage::new(
      input_tokens=3,
      output_tokens=4,
      model=Some("claude-sonnet-4-6"),
      message_id=Some("msg_1"),
    ),
    128,
  )
  assert_eq(stats.request_logs.length(), 1)
  let log = stats.request_logs[0]
  assert_eq(log.request_id, "session:msg_1")
  assert_eq(log.session_id, Some("session-2"))
  assert_true(log.is_streaming)
}

///|
test "moongate usage keeps interleaved request accounting isolated" {
  let stats = TrafficStats::new()
  let codex = stats.begin_request(31)
  codex.set_active_target("codex", "openai", "OpenAI")
  codex.set_request_context(
    "codex",
    "gpt-5",
    session_id=Some("codex-session"),
    provider_type=Some("openai_chat"),
  )
  stats.record_stream_mode(codex, false)

  let claude = stats.begin_request(47)
  assert_true(codex.request_id != claude.request_id)
  claude.set_active_target("claude", "anthropic", "Anthropic")
  claude.set_request_context(
    "claude",
    "claude-sonnet-4-6",
    session_id=Some("claude-session"),
    provider_type=Some("anthropic"),
  )
  stats.record_stream_mode(claude, true)
  assert_eq(stats.active_connections, 2)

  stats.record_success_usage(
    claude,
    TokenUsage::new(
      input_tokens=7,
      output_tokens=11,
      model=Some("claude-sonnet-4-6"),
    ),
    101,
  )
  assert_eq(stats.active_connections, 1)
  stats.record_success_usage(
    codex,
    TokenUsage::new(input_tokens=3, output_tokens=5, model=Some("gpt-5")),
    59,
  )

  assert_eq(stats.active_connections, 0)
  assert_eq(stats.request_logs.length(), 2)
  let claude_log = stats.request_logs[0]
  assert_eq(claude_log.app_type, "claude")
  assert_eq(claude_log.provider_id, "anthropic")
  assert_eq(claude_log.model, "claude-sonnet-4-6")
  assert_eq(claude_log.session_id, Some("claude-session"))
  assert_true(claude_log.is_streaming)
  let codex_log = stats.request_logs[1]
  assert_eq(codex_log.app_type, "codex")
  assert_eq(codex_log.provider_id, "openai")
  assert_eq(codex_log.model, "gpt-5")
  assert_eq(codex_log.session_id, Some("codex-session"))
  assert_false(codex_log.is_streaming)
}

///|
test "moongate usage request pricing uses moongate outbound model context" {
  let stats = TrafficStats::new()
  let request = stats.begin_request(64)
  stats.set_active_target("claude", "router", "Router")
  request.set_active_target(
    "claude",
    "router",
    "Router",
    pricing_model_source="request",
  )
  request.set_request_context(
    "claude",
    "client-alias",
    outbound_model=Some("gpt-5"),
  )
  stats.record_success_usage(
    request,
    TokenUsage::new(
      input_tokens=1000,
      output_tokens=0,
      model=Some("response-model"),
    ),
    128,
  )
  assert_eq(stats.request_logs.length(), 1)
  let log = stats.request_logs[0]
  assert_eq(log.model, "response-model")
  assert_eq(log.request_model, Some("client-alias"))
  assert_eq(log.pricing_model, Some("gpt-5"))
  assert_eq(log.total_cost_usd, "0.00125")
}

///|
test "moongate usage empty usage falls back to moongate outbound model context" {
  let stats = TrafficStats::new()
  let request = stats.begin_request(64)
  stats.set_active_target("claude", "router", "Router")
  request.set_active_target("claude", "router", "Router")
  request.set_request_context(
    "claude",
    "client-alias",
    outbound_model=Some("gpt-5"),
  )
  stats.record_success_usage(request, TokenUsage::empty(), 128)
  assert_eq(stats.request_logs.length(), 1)
  let log = stats.request_logs[0]
  assert_eq(log.model, "gpt-5")
  assert_eq(log.request_model, Some("client-alias"))
  assert_eq(log.pricing_model, Some("gpt-5"))
  assert_eq(log.input_tokens, 0)
  assert_eq(log.output_tokens, 0)
  assert_eq(log.total_cost_usd, "0")
}

///|
test "moongate usage leaves moongate error pricing model empty" {
  let stats = TrafficStats::new()
  let request = stats.begin_request(64)
  stats.set_active_target("claude", "router", "Router")
  request.set_active_target(
    "claude",
    "router",
    "Router",
    pricing_model_source="request",
    cost_multiplier="2.5",
  )
  request.set_request_context(
    "claude",
    "client-alias",
    outbound_model=Some("gpt-5"),
  )
  stats.record_stream_mode(request, true)
  stats.record_upstream_error_status(request, 25, 502)
  assert_eq(stats.request_logs.length(), 1)
  let log = stats.request_logs[0]
  assert_eq(log.model, "client-alias")
  assert_eq(log.request_model, Some("client-alias"))
  assert_eq(log.pricing_model, Some(""))
  assert_eq(log.cost_multiplier, "1.0")
  assert_eq(log.status_code, 502)
  assert_eq(log.error_message, Some("upstream_error"))
  assert_eq(log.total_cost_usd, "0")
  guard log.to_moon_request_log_detail_json() is Object(obj) else {
    fail("expected request detail object")
  }
  assert_eq(obj["model"], Json::string("client-alias"))
  assert_eq(obj["requestModel"], Json::string("client-alias"))
  assert_eq(obj["pricingModel"], Json::string(""))
  assert_eq(obj["costMultiplier"], Json::string("1.0"))
}

///|
test "moongate usage can price gateway requests with moongate model pricing overrides" {
  let stats = TrafficStats::new()
  let request = stats.begin_request(64)
  stats.set_active_target("codex", "codex-oauth", "Codex OAuth")
  request.set_active_target("codex", "codex-oauth", "Codex OAuth")
  request.set_request_context("codex", "custom-priced")
  stats.record_stream_mode(request, false)
  stats.record_success_usage_with_pricing(
    request,
    TokenUsage::new(
      input_tokens=10,
      output_tokens=5,
      model=Some("custom-priced"),
    ),
    128,
    [mp("custom-priced", "Custom Priced", "2", "4", "0", "0")],
    Map([], capacity=0),
  )
  assert_eq(stats.request_logs.length(), 1)
  let log = stats.request_logs[0]
  assert_eq(log.input_cost_usd, "0.00002")
  assert_eq(log.output_cost_usd, "0.00002")
  assert_eq(log.total_cost_usd, "0.00004")
}

///|
test "moongate usage honors moongate model pricing delete tombstones" {
  let stats = TrafficStats::new()
  let deleted : Map[String, Bool] = Map([], capacity=0)
  deleted.set("gpt-5", true)
  let request = stats.begin_request(64)
  stats.set_active_target("codex", "codex-oauth", "Codex OAuth")
  request.set_active_target("codex", "codex-oauth", "Codex OAuth")
  request.set_request_context("codex", "gpt-5")
  stats.record_stream_mode(request, false)
  stats.record_success_usage_with_pricing(
    request,
    TokenUsage::new(input_tokens=10, output_tokens=5, model=Some("gpt-5")),
    128,
    [],
    deleted,
  )
  assert_eq(stats.request_logs.length(), 1)
  assert_eq(stats.request_logs[0].total_cost_usd, "0")
}

///|
test "moongate usage keeps request log retention bounded" {
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
  assert_eq(stats.daily_rollups.length(), 1)
  assert_eq(stats.daily_rollups[0].request_count, 5)
  guard stats.usage_summary_json() is Object(summary) else {
    fail("expected usage summary")
  }
  assert_eq(summary["totalRequests"], Json::number(505.0))
}

///|
test "moongate usage preserves aggregates beyond detail retention" {
  let stats = TrafficStats::new()
  for i in 0..<10_000 {
    stats.record_request_log(
      RequestLog::new(
        request_id="req-volume-\{i}",
        provider_id="provider-volume",
        provider_name=Some("Provider Volume"),
        app_type="codex",
        model="gpt-volume",
        pricing_model=Some("gpt-volume"),
        usage=TokenUsage::new(input_tokens=1, output_tokens=2),
        total_cost_usd="0.000003",
        status_code=200,
        latency_ms=10,
        created_at=1_700_000_000,
        data_source="proxy",
      ),
    )
  }
  assert_eq(stats.request_logs.length(), REQUEST_LOG_LIMIT)
  assert_eq(stats.daily_rollups.length(), 1)
  assert_eq(stats.daily_rollups[0].request_count, 9_500)
  guard stats.usage_summary_json() is Object(summary) else {
    fail("expected usage summary")
  }
  assert_eq(summary["totalRequests"], Json::number(10_000.0))
  assert_eq(summary["totalInputTokens"], Json::number(10_000.0))
  assert_eq(summary["totalOutputTokens"], Json::number(20_000.0))
  assert_eq(summary["totalCost"], Json::string("0.030000"))
  guard stats.provider_stats_json() is Array([Object(provider)]) else {
    fail("expected provider stats")
  }
  assert_eq(provider["requestCount"], Json::number(10_000.0))
  assert_eq(provider["totalTokens"], Json::number(30_000.0))
  guard stats.model_stats_json() is Array([Object(model)]) else {
    fail("expected model stats")
  }
  assert_eq(model["requestCount"], Json::number(10_000.0))
  guard stats.usage_data_sources_json() is Array([Object(source)]) else {
    fail("expected data source stats")
  }
  assert_eq(source["dataSource"], Json::string("proxy"))
  assert_eq(source["requestCount"], Json::number(10_000.0))
}

///|
test "request log default created_at uses moongate unix seconds" {
  let before = @os.unix_seconds()
  let log = RequestLog::new(
    request_id="req-time",
    provider_id="provider",
    app_type="codex",
    model="gpt-5",
    usage=TokenUsage::empty(),
    status_code=200,
  )
  let after = @os.unix_seconds()
  assert_true(log.created_at >= before)
  assert_true(log.created_at <= after)
  assert_true(log.created_at > 1_700_000_000)
  guard log.to_moon_request_log_detail_json() is Object(obj) else {
    fail("expected request log object")
  }
  assert_eq(obj["createdAt"], Json::number(log.created_at.to_double()))
}

///|
test "usage logs paginated json matches moongate filters and ordering" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-older",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5",
      request_model=Some("gpt-5"),
      pricing_model=Some("gpt-5"),
      usage=TokenUsage::new(input_tokens=10, output_tokens=2),
      total_cost_usd="0.000010",
      status_code=200,
      latency_ms=11,
      created_at=100,
      data_source="proxy",
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-newer",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5-mini",
      request_model=Some("gpt-5-mini"),
      pricing_model=Some("gpt-5-mini"),
      usage=TokenUsage::new(input_tokens=20, output_tokens=3),
      total_cost_usd="0.000020",
      status_code=200,
      latency_ms=22,
      first_token_ms=Some(7),
      duration_ms=Some(30),
      created_at=300,
      data_source="proxy",
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-failed",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::new(input_tokens=30, output_tokens=4),
      total_cost_usd="0.000030",
      status_code=500,
      created_at=400,
      data_source="proxy",
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-claude",
      provider_id="anthropic",
      provider_name=Some("Anthropic"),
      app_type="claude",
      model="claude-sonnet-4-6",
      usage=TokenUsage::new(input_tokens=40, output_tokens=5),
      total_cost_usd="0.000040",
      status_code=200,
      created_at=500,
      data_source="proxy",
    ),
  )

  let filters = RequestLogFilters::new(
    app_type=Some("codex"),
    provider_name=Some("oauth"),
    model=Some("gpt-5"),
    status_code=Some(200),
    start_date=Some(50),
    end_date=Some(350),
  )
  guard stats.usage_logs_paginated_json(filters, page=0, page_size=1)
    is Object(first_page) else {
    fail("expected first page object")
  }
  assert_eq(first_page["total"], Json::number(2.0))
  assert_eq(first_page["page"], Json::number(0.0))
  assert_eq(first_page["pageSize"], Json::number(1.0))
  guard first_page["data"] is Array(first_rows) else {
    fail("expected first page data")
  }
  assert_eq(first_rows.length(), 1)
  guard first_rows[0] is Object(first) else { fail("expected first row") }
  assert_eq(first["requestId"], Json::string("req-newer"))
  assert_eq(first["providerId"], Json::string("codex-oauth"))
  assert_eq(first["providerName"], Json::string("Codex OAuth"))
  assert_eq(first["appType"], Json::string("codex"))
  assert_eq(first["model"], Json::string("gpt-5-mini"))
  assert_eq(first["requestModel"], Json::string("gpt-5-mini"))
  assert_eq(first["costMultiplier"], Json::string("1.0"))
  assert_eq(first["inputTokens"], Json::number(20.0))
  assert_eq(first["outputTokens"], Json::number(3.0))
  assert_eq(first["totalCostUsd"], Json::string("0.000020"))
  assert_eq(first["isStreaming"], Json::boolean(false))
  assert_eq(first["latencyMs"], Json::number(22.0))
  assert_eq(first["firstTokenMs"], Json::number(7.0))
  assert_eq(first["durationMs"], Json::number(30.0))
  assert_eq(first["statusCode"], Json::number(200.0))
  assert_eq(first["dataSource"], Json::string("proxy"))
  assert_eq(first["pricingModel"], Json::string("gpt-5-mini"))
  assert_true(first.get("sessionId") is None)
  assert_true(first.get("providerType") is None)
  guard stats.usage_logs_paginated_json(filters, page=1, page_size=1)
    is Object(second_page) else {
    fail("expected second page object")
  }
  guard second_page["data"] is Array(second_rows) else {
    fail("expected second page data")
  }
  assert_eq(second_rows.length(), 1)
  guard second_rows[0] is Object(second) else {
    fail("expected second page row")
  }
  assert_eq(second["requestId"], Json::string("req-older"))
}

///|
test "usage logs paginated json defaults to moongate page size" {
  let stats = TrafficStats::new()
  for i in 0..<25 {
    stats.record_request_log(
      RequestLog::new(
        request_id="req-\{i}",
        provider_id="codex-oauth",
        provider_name=Some("Codex OAuth"),
        app_type="codex",
        model="gpt-5",
        usage=TokenUsage::new(input_tokens=1, output_tokens=1),
        status_code=200,
        created_at=i,
        data_source="proxy",
      ),
    )
  }
  guard stats.usage_logs_paginated_json(RequestLogFilters::new())
    is Object(page) else {
    fail("expected page object")
  }
  assert_eq(page["total"], Json::number(25.0))
  assert_eq(page["page"], Json::number(0.0))
  assert_eq(page["pageSize"], Json::number(20.0))
  guard page["data"] is Array(rows) else { fail("expected page rows") }
  assert_eq(rows.length(), 20)
}

///|
test "usage logs provider name filter matches moongate joined provider name semantics" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-proxy",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::new(input_tokens=10, output_tokens=2),
      total_cost_usd="0.000010",
      status_code=200,
      created_at=100,
      data_source="proxy",
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-session",
      provider_id="_codex_session",
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::new(input_tokens=30, output_tokens=7),
      total_cost_usd="0.000010",
      status_code=200,
      created_at=10_000,
      data_source="codex_session",
    ),
  )
  guard stats.usage_logs_paginated_json(
      RequestLogFilters::new(),
      page=0,
      page_size=10,
    )
    is Object(all_logs) else {
    fail("expected all logs page")
  }
  guard all_logs["data"] is Array(all_rows) else {
    fail("expected all logs rows")
  }
  guard all_rows[0] is Object(session_row) else { fail("expected session row") }
  assert_eq(session_row["providerName"], Json::string("Codex (Session)"))
  guard stats.usage_logs_paginated_json(
      RequestLogFilters::new(provider_name=Some("Session")),
      page=0,
      page_size=10,
    )
    is Object(session_filtered) else {
    fail("expected filtered session page")
  }
  assert_eq(session_filtered["total"], Json::number(0.0))
  guard stats.usage_logs_paginated_json(
      RequestLogFilters::new(provider_name=Some("OAuth")),
      page=0,
      page_size=10,
    )
    is Object(provider_filtered) else {
    fail("expected filtered provider page")
  }
  assert_eq(provider_filtered["total"], Json::number(1.0))
}

///|
test "request detail lookup returns retained proxy request log" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-detail",
      provider_id="provider",
      provider_name=Some("Provider One"),
      app_type="codex",
      model="gpt-5",
      request_model=Some("gpt-5"),
      pricing_model=Some("gpt-5"),
      usage=TokenUsage::new(input_tokens=1, output_tokens=2),
      status_code=200,
      total_cost_usd="0.000010",
      latency_ms=37,
      created_at=123,
      data_source="proxy",
    ),
  )
  assert_true(stats.request_detail_json("missing") is None)
  guard stats.request_detail_json("req-detail") is Some(detail) else {
    fail("expected request detail")
  }
  guard detail is Object(obj) else { fail("expected detail object") }
  assert_eq(obj["requestId"], Json::string("req-detail"))
  assert_eq(obj["providerId"], Json::string("provider"))
  assert_eq(obj["providerName"], Json::string("Provider One"))
  assert_eq(obj["appType"], Json::string("codex"))
  assert_eq(obj["model"], Json::string("gpt-5"))
  assert_eq(obj["requestModel"], Json::string("gpt-5"))
  assert_eq(obj["pricingModel"], Json::string("gpt-5"))
  assert_eq(obj["inputTokens"], Json::number(1.0))
  assert_eq(obj["outputTokens"], Json::number(2.0))
  assert_eq(obj["totalCostUsd"], Json::string("0.000010"))
  assert_eq(obj["latencyMs"], Json::number(37.0))
  assert_eq(obj["statusCode"], Json::number(200.0))
  assert_eq(obj["createdAt"], Json::number(123.0))
  assert_eq(obj["dataSource"], Json::string("proxy"))
  assert_true(obj.get("request_id") is None)
  assert_true(obj.get("total_cost_usd") is None)
}

///|
test "usage summary aggregates moongate token and cost semantics" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-codex",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5",
      pricing_model=Some("gpt-5"),
      usage=TokenUsage::new(
        input_tokens=100,
        output_tokens=10,
        cache_read_tokens=40,
      ),
      total_cost_usd="0.000100",
      status_code=200,
      latency_ms=30,
      data_source="proxy",
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-claude",
      provider_id="anthropic",
      provider_name=Some("Anthropic"),
      app_type="claude",
      model="claude-sonnet-4-6",
      pricing_model=Some("claude-sonnet-4-6"),
      usage=TokenUsage::new(
        input_tokens=50,
        output_tokens=5,
        cache_read_tokens=20,
        cache_creation_tokens=10,
      ),
      total_cost_usd="0.000200",
      status_code=500,
      latency_ms=70,
      data_source="session",
    ),
  )
  let summary = stats.usage_summary_json()
  guard summary is Object(obj) else { fail("expected summary object") }
  assert_eq(obj["totalRequests"], Json::number(2.0))
  assert_eq(obj["totalCost"], Json::string("0.000300"))
  assert_eq(obj["totalInputTokens"], Json::number(110.0))
  assert_eq(obj["totalOutputTokens"], Json::number(15.0))
  assert_eq(obj["totalCacheCreationTokens"], Json::number(10.0))
  assert_eq(obj["totalCacheReadTokens"], Json::number(60.0))
  assert_eq(obj["successRate"], Json::number(50.0))
  assert_eq(obj["realTotalTokens"], Json::number(195.0))
  guard obj["cacheHitRate"] is Number(cache_hit_rate, ..) else {
    fail("expected cache hit rate")
  }
  assert_true(cache_hit_rate > 0.333 && cache_hit_rate < 0.334)

  json_inspect(stats.usage_summary_json(app_type=Some("codex")), content={
    "totalRequests": 1,
    "totalCost": "0.000100",
    "totalInputTokens": 60,
    "totalOutputTokens": 10,
    "totalCacheCreationTokens": 0,
    "totalCacheReadTokens": 40,
    "successRate": 100,
    "realTotalTokens": 110,
    "cacheHitRate": 0.4,
  })
}

///|
test "usage aggregate keeps malformed cache-inclusive input like moongate sql helper" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-codex-cache-overflow",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5",
      pricing_model=Some("gpt-5"),
      usage=TokenUsage::new(
        input_tokens=100,
        output_tokens=5,
        cache_read_tokens=999,
      ),
      total_cost_usd="0.000100",
      status_code=200,
      latency_ms=30,
      data_source="proxy",
    ),
  )
  let log = stats.request_logs[0]
  assert_eq(request_log_fresh_input_tokens(log), 100)
  let summary = stats.usage_summary_json()
  guard summary is Object(obj) else { fail("expected summary object") }
  assert_eq(obj["totalInputTokens"], Json::number(100.0))
  assert_eq(obj["totalOutputTokens"], Json::number(5.0))
  assert_eq(obj["totalCacheReadTokens"], Json::number(999.0))
  assert_eq(obj["realTotalTokens"], Json::number(1104.0))
  guard stats.provider_stats_json() is Array(provider_rows) else {
    fail("expected provider stats")
  }
  guard provider_rows[0] is Object(provider) else {
    fail("expected provider stat object")
  }
  assert_eq(provider["totalTokens"], Json::number(105.0))
  guard stats.model_stats_json() is Array(model_rows) else {
    fail("expected model stats")
  }
  guard model_rows[0] is Object(model) else {
    fail("expected model stat object")
  }
  assert_eq(model["totalTokens"], Json::number(105.0))
}

///|
test "usage summary excludes partial rollup boundary days like moongate" {
  with_test_timezone("UTC", fn() raise {
    let stats = TrafficStats::new()
    stats.daily_rollups.push(
      moon_test_rollup(
        "2024-01-01",
        request_count=10,
        success_count=10,
        input_tokens=1000,
        output_tokens=500,
        total_cost_nano=1_000_000_000L,
        avg_latency_ms=100,
      ),
    )
    stats.daily_rollups.push(
      moon_test_rollup(
        "2024-01-02",
        request_count=20,
        success_count=19,
        input_tokens=2000,
        output_tokens=1000,
        total_cost_nano=2_000_000_000L,
        avg_latency_ms=120,
      ),
    )
    stats.daily_rollups.push(
      moon_test_rollup(
        "2024-01-03",
        request_count=30,
        success_count=29,
        input_tokens=3000,
        output_tokens=1500,
        total_cost_nano=3_000_000_000L,
        avg_latency_ms=140,
      ),
    )

    let summary = stats.usage_summary_filtered_json(
      start_date=Some(1_704_110_400),
      end_date=Some(1_704_283_200),
      app_type=Some("claude"),
    )
    guard summary is Object(obj) else { fail("expected summary object") }
    assert_eq(obj["totalRequests"], Json::number(20.0))
    assert_eq(obj["totalInputTokens"], Json::number(2000.0))
    assert_eq(obj["totalOutputTokens"], Json::number(1000.0))
    assert_eq(obj["totalCost"], Json::string("2.000000"))
    assert_eq(obj["successRate"], Json::number(95.0))
  })
}

///|
test "usage summary includes end day rollup for minute precision end time like moongate" {
  with_test_timezone("UTC", fn() raise {
    let stats = TrafficStats::new()
    stats.daily_rollups.push(
      moon_test_rollup(
        "2024-01-01",
        request_count=10,
        success_count=10,
        input_tokens=1000,
        output_tokens=500,
        total_cost_nano=1_000_000_000L,
      ),
    )
    stats.daily_rollups.push(
      moon_test_rollup(
        "2024-01-02",
        request_count=20,
        success_count=19,
        input_tokens=2000,
        output_tokens=1000,
        total_cost_nano=2_000_000_000L,
      ),
    )

    let summary = stats.usage_summary_filtered_json(
      start_date=Some(1_704_067_200),
      end_date=Some(1_704_239_940),
      app_type=Some("claude"),
    )
    guard summary is Object(obj) else { fail("expected summary object") }
    assert_eq(obj["totalRequests"], Json::number(30.0))
    assert_eq(obj["totalInputTokens"], Json::number(3000.0))
    assert_eq(obj["totalOutputTokens"], Json::number(1500.0))
  })
}

///|
test "provider stats exclude partial rollup boundary days like moongate" {
  with_test_timezone("UTC", fn() raise {
    let stats = TrafficStats::new()
    stats.daily_rollups.push(
      moon_test_rollup(
        "2024-02-01",
        provider_id="p-rollup",
        request_count=5,
        success_count=5,
        input_tokens=500,
        output_tokens=250,
        total_cost_nano=500_000_000L,
        avg_latency_ms=100,
      ),
    )
    stats.daily_rollups.push(
      moon_test_rollup(
        "2024-02-02",
        provider_id="p-rollup",
        request_count=8,
        success_count=7,
        input_tokens=800,
        output_tokens=400,
        total_cost_nano=800_000_000L,
        avg_latency_ms=120,
      ),
    )
    stats.daily_rollups.push(
      moon_test_rollup(
        "2024-02-03",
        provider_id="p-rollup",
        request_count=12,
        success_count=11,
        input_tokens=1200,
        output_tokens=600,
        total_cost_nano=1_200_000_000L,
        avg_latency_ms=140,
      ),
    )

    guard stats.provider_stats_filtered_json(
        start_date=Some(1_706_788_800),
        end_date=Some(1_706_961_600),
        app_type=Some("claude"),
      )
      is Array(rows) else {
      fail("expected provider stats array")
    }
    assert_eq(rows.length(), 1)
    guard rows[0] is Object(row) else { fail("expected provider row") }
    assert_eq(row["providerId"], Json::string("p-rollup"))
    assert_eq(row["requestCount"], Json::number(8.0))
    assert_eq(row["totalTokens"], Json::number(1200.0))
  })
}

///|
test "usage trends combine boundary details with full-day rollups like moongate" {
  with_test_timezone("UTC", fn() raise {
    let stats = TrafficStats::new()
    stats.record_request_log(
      RequestLog::new(
        request_id="day-1-detail",
        provider_id="p1",
        app_type="claude",
        model="claude-3",
        usage=TokenUsage::new(input_tokens=100, output_tokens=50),
        total_cost_usd="0.010000",
        status_code=200,
        latency_ms=100,
        created_at=1_709_298_000,
      ),
    )
    stats.record_request_log(
      RequestLog::new(
        request_id="day-3-detail",
        provider_id="p1",
        app_type="claude",
        model="claude-3",
        usage=TokenUsage::new(input_tokens=200, output_tokens=75),
        total_cost_usd="0.020000",
        status_code=200,
        latency_ms=110,
        created_at=1_709_460_000,
      ),
    )
    stats.daily_rollups.push(
      moon_test_rollup(
        "2024-03-02",
        request_count=4,
        success_count=4,
        input_tokens=400,
        output_tokens=200,
        total_cost_nano=400_000_000L,
        avg_latency_ms=120,
      ),
    )

    guard stats.usage_trends_json(
        start_ts=Some(1_709_294_400),
        end_ts=Some(1_709_467_200),
        app_type=Some("claude"),
      )
      is Array(rows) else {
      fail("expected trend rows")
    }
    assert_eq(rows.length(), 3)
    guard rows[0] is Object(day_one) else { fail("expected day one row") }
    guard rows[1] is Object(day_two) else { fail("expected day two row") }
    guard rows[2] is Object(day_three) else { fail("expected day three row") }
    assert_eq(day_one["requestCount"], Json::number(1.0))
    assert_eq(day_one["totalTokens"], Json::number(150.0))
    assert_eq(day_two["requestCount"], Json::number(4.0))
    assert_eq(day_two["totalTokens"], Json::number(600.0))
    assert_eq(day_three["requestCount"], Json::number(1.0))
    assert_eq(day_three["totalTokens"], Json::number(275.0))
  })
}

///|
test "model stats exclude partial rollup boundary days like moongate" {
  with_test_timezone("UTC", fn() raise {
    let stats = TrafficStats::new()
    stats.daily_rollups.push(
      moon_test_rollup(
        "2024-04-01",
        model="claude-3",
        request_count=3,
        success_count=3,
        input_tokens=300,
        output_tokens=150,
        total_cost_nano=300_000_000L,
      ),
    )
    stats.daily_rollups.push(
      moon_test_rollup(
        "2024-04-02",
        model="claude-3",
        request_count=6,
        success_count=5,
        input_tokens=600,
        output_tokens=300,
        total_cost_nano=600_000_000L,
      ),
    )
    stats.daily_rollups.push(
      moon_test_rollup(
        "2024-04-03",
        model="claude-3",
        request_count=9,
        success_count=8,
        input_tokens=900,
        output_tokens=450,
        total_cost_nano=900_000_000L,
      ),
    )

    guard stats.model_stats_filtered_json(
        start_date=Some(1_711_972_800),
        end_date=Some(1_712_145_600),
        app_type=Some("claude"),
      )
      is Array(rows) else {
      fail("expected model stats array")
    }
    assert_eq(rows.length(), 1)
    guard rows[0] is Object(row) else { fail("expected model row") }
    assert_eq(row["model"], Json::string("claude-3"))
    assert_eq(row["requestCount"], Json::number(6.0))
    assert_eq(row["totalTokens"], Json::number(900.0))
  })
}

///|
test "usage aggregate lists match moongate route payloads" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-codex",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5",
      pricing_model=Some("gpt-5"),
      usage=TokenUsage::new(
        input_tokens=100,
        output_tokens=10,
        cache_read_tokens=40,
      ),
      total_cost_usd="0.000100",
      status_code=200,
      latency_ms=30,
      data_source="proxy",
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-claude",
      provider_id="anthropic",
      provider_name=Some("Anthropic"),
      app_type="claude",
      model="claude-sonnet-4-6",
      pricing_model=Some("claude-sonnet-4-6"),
      usage=TokenUsage::new(
        input_tokens=50,
        output_tokens=5,
        cache_read_tokens=20,
        cache_creation_tokens=10,
      ),
      total_cost_usd="0.000200",
      status_code=500,
      latency_ms=70,
      data_source="session",
    ),
  )
  json_inspect(stats.usage_summary_by_app_json(), content=[
    {
      "appType": "codex",
      "summary": {
        "totalRequests": 1,
        "totalCost": "0.000100",
        "totalInputTokens": 60,
        "totalOutputTokens": 10,
        "totalCacheCreationTokens": 0,
        "totalCacheReadTokens": 40,
        "successRate": 100,
        "realTotalTokens": 110,
        "cacheHitRate": 0.4,
      },
    },
    {
      "appType": "claude",
      "summary": {
        "totalRequests": 1,
        "totalCost": "0.000200",
        "totalInputTokens": 50,
        "totalOutputTokens": 5,
        "totalCacheCreationTokens": 10,
        "totalCacheReadTokens": 20,
        "successRate": 0,
        "realTotalTokens": 85,
        "cacheHitRate": 0.25,
      },
    },
  ])
  json_inspect(stats.provider_stats_json(), content=[
    {
      "providerId": "anthropic",
      "providerName": "Anthropic",
      "requestCount": 1,
      "totalTokens": 55,
      "totalCost": "0.000200",
      "successRate": 0,
      "avgLatencyMs": 70,
    },
    {
      "providerId": "codex-oauth",
      "providerName": "Codex OAuth",
      "requestCount": 1,
      "totalTokens": 70,
      "totalCost": "0.000100",
      "successRate": 100,
      "avgLatencyMs": 30,
    },
  ])
  json_inspect(stats.model_stats_json(), content=[
    {
      "model": "claude-sonnet-4-6",
      "requestCount": 1,
      "totalTokens": 55,
      "totalCost": "0.000200",
      "avgCostPerRequest": "0.000200",
    },
    {
      "model": "gpt-5",
      "requestCount": 1,
      "totalTokens": 70,
      "totalCost": "0.000100",
      "avgCostPerRequest": "0.000100",
    },
  ])
  json_inspect(stats.usage_data_sources_json(), content=[
    { "dataSource": "proxy", "requestCount": 1, "totalCostUsd": "0.000100" },
    { "dataSource": "session", "requestCount": 1, "totalCostUsd": "0.000200" },
  ])
}

///|
test "provider stats average latency truncates like moongate" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-a",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::new(input_tokens=1, output_tokens=1),
      total_cost_usd="0.000001",
      status_code=200,
      latency_ms=30,
      data_source="proxy",
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-b",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::new(input_tokens=1, output_tokens=1),
      total_cost_usd="0.000001",
      status_code=200,
      latency_ms=31,
      data_source="proxy",
    ),
  )
  guard stats.provider_stats_json() is Array(rows) else {
    fail("expected provider stats")
  }
  guard rows[0] is Object(row) else { fail("expected row") }
  assert_eq(row["avgLatencyMs"], Json::number(30.0))
}

///|
test "usage aggregate filters match moongate date and app semantics" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-codex-old",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5",
      pricing_model=Some("gpt-5"),
      usage=TokenUsage::new(input_tokens=10, output_tokens=2),
      total_cost_usd="0.000010",
      status_code=200,
      latency_ms=10,
      created_at=90,
      data_source="proxy",
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-codex-window",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5",
      pricing_model=Some("gpt-5"),
      usage=TokenUsage::new(input_tokens=100, output_tokens=20),
      total_cost_usd="0.000100",
      status_code=200,
      latency_ms=30,
      created_at=150,
      data_source="proxy",
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-claude-window",
      provider_id="anthropic",
      provider_name=Some("Anthropic"),
      app_type="claude",
      model="claude-sonnet-4-6",
      pricing_model=Some("claude-sonnet-4-6"),
      usage=TokenUsage::new(input_tokens=200, output_tokens=30),
      total_cost_usd="0.000200",
      status_code=500,
      latency_ms=70,
      created_at=180,
      data_source="proxy",
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-codex-new",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="gpt-5",
      pricing_model=Some("gpt-5"),
      usage=TokenUsage::new(input_tokens=300, output_tokens=40),
      total_cost_usd="0.000300",
      status_code=200,
      latency_ms=90,
      created_at=250,
      data_source="proxy",
    ),
  )

  json_inspect(
    stats.usage_summary_filtered_json(
      start_date=Some(100),
      end_date=Some(200),
      app_type=Some("codex"),
    ),
    content={
      "totalRequests": 1,
      "totalCost": "0.000100",
      "totalInputTokens": 100,
      "totalOutputTokens": 20,
      "totalCacheCreationTokens": 0,
      "totalCacheReadTokens": 0,
      "successRate": 100,
      "realTotalTokens": 120,
      "cacheHitRate": 0,
    },
  )
  json_inspect(
    stats.usage_summary_by_app_filtered_json(
      start_date=Some(100),
      end_date=Some(200),
    ),
    content=[
      {
        "appType": "claude",
        "summary": {
          "totalRequests": 1,
          "totalCost": "0.000200",
          "totalInputTokens": 200,
          "totalOutputTokens": 30,
          "totalCacheCreationTokens": 0,
          "totalCacheReadTokens": 0,
          "successRate": 0,
          "realTotalTokens": 230,
          "cacheHitRate": 0,
        },
      },
      {
        "appType": "codex",
        "summary": {
          "totalRequests": 1,
          "totalCost": "0.000100",
          "totalInputTokens": 100,
          "totalOutputTokens": 20,
          "totalCacheCreationTokens": 0,
          "totalCacheReadTokens": 0,
          "successRate": 100,
          "realTotalTokens": 120,
          "cacheHitRate": 0,
        },
      },
    ],
  )
  json_inspect(
    stats.provider_stats_filtered_json(
      start_date=Some(100),
      end_date=Some(200),
      app_type=Some("codex"),
    ),
    content=[
      {
        "providerId": "codex-oauth",
        "providerName": "Codex OAuth",
        "requestCount": 1,
        "totalTokens": 120,
        "totalCost": "0.000100",
        "successRate": 100,
        "avgLatencyMs": 30,
      },
    ],
  )
  json_inspect(
    stats.model_stats_filtered_json(
      start_date=Some(100),
      end_date=Some(200),
      app_type=Some("codex"),
    ),
    content=[
      {
        "model": "gpt-5",
        "requestCount": 1,
        "totalTokens": 120,
        "totalCost": "0.000100",
        "avgCostPerRequest": "0.000100",
      },
    ],
  )
}

///|
test "usage aggregates deduplicate moongate session imports against proxy logs" {
  let stats = TrafficStats::new()
  let session_log = RequestLog::new(
    request_id="codex_session:session-1:0",
    provider_id="_codex_session",
    app_type="codex",
    model="gpt-5",
    usage=TokenUsage::new(
      input_tokens=100,
      output_tokens=10,
      cache_read_tokens=40,
      cache_creation_tokens=0,
    ),
    total_cost_usd="0.009999",
    status_code=200,
    created_at=1000,
    data_source="codex_session",
  )
  let proxy_log = RequestLog::new(
    request_id="req-proxy",
    provider_id="codex-oauth",
    provider_name=Some("Codex OAuth"),
    app_type="codex",
    model="unknown",
    usage=TokenUsage::new(
      input_tokens=100,
      output_tokens=10,
      cache_read_tokens=40,
      cache_creation_tokens=5,
    ),
    total_cost_usd="0.000100",
    status_code=200,
    latency_ms=30,
    created_at=1300,
    data_source="proxy",
  )
  stats.record_request_log(session_log)
  stats.record_request_log(proxy_log)
  assert_eq(stats.request_logs.length(), 2)
  assert_false(stats.request_log_is_effective(session_log))
  assert_true(stats.request_log_is_effective(proxy_log))

  json_inspect(stats.usage_logs_json(limit=10), content={
    "data": [proxy_log.to_moon_request_log_detail_json()],
    "total": 1,
    "limit": 10,
    "source": "memory",
    "table": "proxy_request_logs",
  })

  let summary = stats.usage_summary_json()
  guard summary is Object(summary_obj) else { fail("expected summary object") }
  assert_eq(summary_obj["totalRequests"], Json::number(1.0))
  assert_eq(summary_obj["totalCost"], Json::string("0.000100"))
  assert_eq(summary_obj["totalInputTokens"], Json::number(60.0))
  assert_eq(summary_obj["totalOutputTokens"], Json::number(10.0))
  assert_eq(summary_obj["totalCacheCreationTokens"], Json::number(5.0))
  assert_eq(summary_obj["totalCacheReadTokens"], Json::number(40.0))
  assert_eq(summary_obj["successRate"], Json::number(100.0))
  assert_eq(summary_obj["realTotalTokens"], Json::number(115.0))
  guard summary_obj["cacheHitRate"] is Number(cache_hit_rate, ..) else {
    fail("expected cache hit rate")
  }
  assert_true(cache_hit_rate > 0.380 && cache_hit_rate < 0.382)

  json_inspect(stats.usage_data_sources_json(), content=[
    { "dataSource": "proxy", "requestCount": 1, "totalCostUsd": "0.000100" },
  ])
  json_inspect(stats.provider_stats_json(), content=[
    {
      "providerId": "codex-oauth",
      "providerName": "Codex OAuth",
      "requestCount": 1,
      "totalTokens": 70,
      "totalCost": "0.000100",
      "successRate": 100,
      "avgLatencyMs": 30,
    },
  ])
  json_inspect(stats.model_stats_json(), content=[
    {
      "model": "unknown",
      "requestCount": 1,
      "totalTokens": 70,
      "totalCost": "0.000100",
      "avgCostPerRequest": "0.000100",
    },
  ])

  let trends = stats.usage_trends_json(
    start_ts=Some(0),
    end_ts=Some(3600),
    app_type=Some("codex"),
  )
  guard trends is Array(trend_rows) else { fail("expected trends array") }
  assert_eq(trend_rows.length(), 1)
  guard trend_rows[0] is Object(trend) else { fail("expected trend bucket") }
  assert_eq(trend["requestCount"], Json::number(1.0))
  assert_eq(trend["totalCost"], Json::string("0.000100"))
  assert_eq(trend["totalTokens"], Json::number(70.0))

  json_inspect(
    stats.provider_limit_status_json(
      "_codex_session",
      "codex",
      now_ts=Some(1300),
    ),
    content={
      "providerId": "_codex_session",
      "dailyUsage": "0.009999",
      "dailyLimit": null,
      "dailyExceeded": false,
      "monthlyUsage": "0.009999",
      "monthlyLimit": null,
      "monthlyExceeded": false,
    },
  )
  json_inspect(
    stats.provider_limit_status_json("codex-oauth", "codex", now_ts=Some(1300)),
    content={
      "providerId": "codex-oauth",
      "dailyUsage": "0.000100",
      "dailyLimit": null,
      "dailyExceeded": false,
      "monthlyUsage": "0.000100",
      "monthlyLimit": null,
      "monthlyExceeded": false,
    },
  )
}

///|
test "moongate session proxy dedup only relaxes cache creation for supported sources" {
  let stats = TrafficStats::new()
  let claude_session = RequestLog::new(
    request_id="session:claude-cache-missing",
    provider_id="_session",
    app_type="claude",
    model="claude-sonnet-4-6",
    usage=TokenUsage::new(
      input_tokens=100,
      output_tokens=10,
      cache_read_tokens=40,
      cache_creation_tokens=0,
    ),
    status_code=200,
    created_at=1000,
    data_source="session_log",
  )
  let claude_proxy = RequestLog::new(
    request_id="proxy-claude-cache-write",
    provider_id="anthropic",
    provider_name=Some("Anthropic"),
    app_type="claude",
    model="unknown",
    usage=TokenUsage::new(
      input_tokens=100,
      output_tokens=10,
      cache_read_tokens=40,
      cache_creation_tokens=5,
    ),
    status_code=200,
    created_at=1300,
    data_source="proxy",
  )
  let opencode_session = RequestLog::new(
    request_id="opencode_session:open-cache:1",
    provider_id="_opencode_session",
    app_type="opencode",
    model="deepseek-v4-pro",
    usage=TokenUsage::new(
      input_tokens=300,
      output_tokens=20,
      cache_read_tokens=80,
      cache_creation_tokens=0,
    ),
    status_code=200,
    created_at=2000,
    data_source="opencode_session",
  )
  let opencode_proxy = RequestLog::new(
    request_id="proxy-open-cache-write",
    provider_id="opencode-provider",
    provider_name=Some("OpenCode Provider"),
    app_type="opencode",
    model="unknown",
    usage=TokenUsage::new(
      input_tokens=300,
      output_tokens=20,
      cache_read_tokens=80,
      cache_creation_tokens=7,
    ),
    status_code=200,
    created_at=2300,
    data_source="proxy",
  )
  stats.record_request_log(claude_session)
  stats.record_request_log(claude_proxy)
  stats.record_request_log(opencode_session)
  stats.record_request_log(opencode_proxy)

  assert_true(stats.request_log_is_effective(claude_session))
  assert_true(stats.request_log_is_effective(claude_proxy))
  assert_false(stats.request_log_is_effective(opencode_session))
  assert_true(stats.request_log_is_effective(opencode_proxy))
  json_inspect(stats.usage_data_sources_json(), content=[
    { "dataSource": "proxy", "requestCount": 2, "totalCostUsd": "0.000000" },
    {
      "dataSource": "session_log",
      "requestCount": 1,
      "totalCostUsd": "0.000000",
    },
  ])
}

///|
test "provider stats use moongate session provider fallback names" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="codex_session:session-1:0",
      provider_id="_codex_session",
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::new(
        input_tokens=100,
        output_tokens=10,
        cache_read_tokens=40,
      ),
      total_cost_usd="0.000100",
      status_code=200,
      latency_ms=30,
      created_at=1000,
      data_source="codex_session",
    ),
  )
  json_inspect(stats.provider_stats_json(), content=[
    {
      "providerId": "_codex_session",
      "providerName": "Codex (Session)",
      "requestCount": 1,
      "totalTokens": 70,
      "totalCost": "0.000100",
      "successRate": 100,
      "avgLatencyMs": 30,
    },
  ])
}

///|
fn[T] with_test_timezone(zone : String, f : () -> T raise) -> T raise {
  let old_tz = @os.getenv("TZ") catch { _ => None }
  @os.setenv("TZ", zone, overwrite=true)
  try f() catch {
    error => {
      restore_test_timezone(old_tz)
      raise error
    }
  } noraise {
    value => {
      restore_test_timezone(old_tz)
      value
    }
  }
}

///|
fn moon_test_rollup(
  date : String,
  provider_id? : String = "p1",
  provider_name? : String? = None,
  data_source? : String = "proxy",
  app_type? : String = "claude",
  model? : String = "claude-3",
  request_count~ : Int,
  success_count~ : Int,
  input_tokens~ : Int,
  output_tokens~ : Int,
  cache_read_tokens? : Int = 0,
  cache_creation_tokens? : Int = 0,
  total_cost_nano~ : Int64,
  avg_latency_ms? : Int = 100,
) -> UsageDailyRollup {
  {
    date,
    app_type,
    provider_id,
    provider_name,
    data_source,
    model,
    request_model: None,
    pricing_model: None,
    request_count,
    success_count,
    input_tokens,
    output_tokens,
    cache_read_tokens,
    cache_creation_tokens,
    total_cost_nano,
    avg_latency_ms,
  }
}

///|
fn restore_test_timezone(old_tz : String?) -> Unit {
  match old_tz {
    Some(value) => @os.setenv("TZ", value, overwrite=true) catch { _ => () }
    None => @os.unsetenv("TZ") catch { _ => () }
  }
}

///|
test "usage trends use moongate hourly buckets for short ranges" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-codex",
      provider_id="codex-oauth",
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::new(
        input_tokens=100,
        output_tokens=10,
        cache_read_tokens=40,
      ),
      total_cost_usd="0.000100",
      status_code=200,
      created_at=100,
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-claude",
      provider_id="anthropic",
      app_type="claude",
      model="claude-sonnet-4-6",
      usage=TokenUsage::new(
        input_tokens=50,
        output_tokens=5,
        cache_read_tokens=20,
        cache_creation_tokens=10,
      ),
      total_cost_usd="0.000200",
      status_code=200,
      created_at=3700,
    ),
  )
  let trends = stats.usage_trends_json(start_ts=Some(0), end_ts=Some(7200))
  guard trends is Array(rows) else { fail("expected trends array") }
  assert_eq(rows.length(), 2)
  guard rows[0] is Object(first) else { fail("expected first trend bucket") }
  assert_eq(first["date"], Json::string(trend_timestamp_rfc3339(0)))
  assert_eq(first["requestCount"], Json::number(1.0))
  assert_eq(first["totalCost"], Json::string("0.000100"))
  assert_eq(first["totalTokens"], Json::number(70.0))
  assert_eq(first["totalInputTokens"], Json::number(60.0))
  assert_eq(first["totalOutputTokens"], Json::number(10.0))
  assert_eq(first["totalCacheCreationTokens"], Json::number(0.0))
  assert_eq(first["totalCacheReadTokens"], Json::number(40.0))
  guard rows[1] is Object(second) else { fail("expected second trend bucket") }
  assert_eq(second["date"], Json::string(trend_timestamp_rfc3339(3600)))
  assert_eq(second["requestCount"], Json::number(1.0))
  assert_eq(second["totalCost"], Json::string("0.000200"))
  assert_eq(second["totalTokens"], Json::number(55.0))
  assert_eq(second["totalInputTokens"], Json::number(50.0))
  assert_eq(second["totalOutputTokens"], Json::number(5.0))
  assert_eq(second["totalCacheCreationTokens"], Json::number(10.0))
  assert_eq(second["totalCacheReadTokens"], Json::number(20.0))
}

///|
test "usage rollups aggregate old effective rows like moongate daily rollups" {
  with_test_timezone("UTC", fn() raise {
    let stats = TrafficStats::new()
    let session_log = RequestLog::new(
      request_id="codex_session:rollup:1",
      provider_id="_codex_session",
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::new(
        input_tokens=100,
        output_tokens=10,
        cache_read_tokens=40,
        cache_creation_tokens=0,
      ),
      total_cost_usd="9.000000",
      status_code=200,
      created_at=100,
      data_source="codex_session",
    )
    let proxy_log = RequestLog::new(
      request_id="proxy-rollup",
      provider_id="codex-oauth",
      provider_name=Some("Codex OAuth"),
      app_type="codex",
      model="unknown",
      usage=TokenUsage::new(
        input_tokens=100,
        output_tokens=10,
        cache_read_tokens=40,
        cache_creation_tokens=5,
      ),
      total_cost_usd="0.000100",
      status_code=200,
      latency_ms=30,
      created_at=200,
      data_source="proxy",
    )
    let retained_log = RequestLog::new(
      request_id="retained-detail",
      provider_id="anthropic",
      provider_name=Some("Anthropic"),
      app_type="claude",
      model="claude-sonnet-4-6",
      usage=TokenUsage::new(input_tokens=20, output_tokens=5),
      total_cost_usd="0.000200",
      status_code=200,
      latency_ms=60,
      created_at=TREND_DAY_SECONDS + 100,
      data_source="proxy",
    )
    stats.record_request_log(session_log)
    stats.record_request_log(proxy_log)
    stats.record_request_log(retained_log)

    assert_eq(stats.rollup_request_logs_before(1000), 2)
    assert_eq(stats.request_logs.length(), 1)
    assert_eq(stats.request_logs[0].request_id, "retained-detail")
    assert_eq(stats.daily_rollups.length(), 1)
    let rollup = stats.daily_rollups[0]
    assert_eq(rollup.date, "1970-01-01")
    assert_eq(rollup.provider_id, "codex-oauth")
    assert_eq(rollup.request_count, 1)
    assert_eq(rollup.input_tokens, 100)
    assert_eq(usage_daily_rollup_fresh_input_tokens(rollup), 60)

    json_inspect(stats.usage_summary_json(), content={
      "totalRequests": 2,
      "totalCost": "0.000300",
      "totalInputTokens": 80,
      "totalOutputTokens": 15,
      "totalCacheCreationTokens": 5,
      "totalCacheReadTokens": 40,
      "successRate": 100,
      "realTotalTokens": 140,
      "cacheHitRate": 0.32,
    })
    json_inspect(stats.provider_stats_json(app_type=Some("codex")), content=[
      {
        "providerId": "codex-oauth",
        "providerName": "Codex OAuth",
        "requestCount": 1,
        "totalTokens": 70,
        "totalCost": "0.000100",
        "successRate": 100,
        "avgLatencyMs": 30,
      },
    ])
    json_inspect(stats.model_stats_json(app_type=Some("codex")), content=[
      {
        "model": "unknown",
        "requestCount": 1,
        "totalTokens": 70,
        "totalCost": "0.000100",
        "avgCostPerRequest": "0.000100",
      },
    ])
    guard stats.usage_trends_json(
        start_ts=Some(0),
        end_ts=Some(TREND_DAY_SECONDS * 2),
      )
      is Array(rows) else {
      fail("expected daily trend rows")
    }
    assert_eq(rows.length(), 3)
    guard rows[0] is Object(day_zero) else { fail("expected day zero") }
    guard rows[1] is Object(day_one) else { fail("expected day one") }
    assert_eq(day_zero["requestCount"], Json::number(1.0))
    assert_eq(day_zero["totalTokens"], Json::number(70.0))
    assert_eq(day_one["requestCount"], Json::number(1.0))
    assert_eq(day_one["totalTokens"], Json::number(25.0))
  })
}

///|
test "usage rollup cutoff aligns to local midnight after retained target day" {
  with_test_timezone("UTC", fn() raise {
    let now = TREND_DAY_SECONDS * 100 + 14 * 60 * 60
    assert_eq(usage_rollup_cutoff_ts(now, 30), TREND_DAY_SECONDS * 71)
    let stats = TrafficStats::new()
    stats.record_request_log(
      RequestLog::new(
        request_id="old-complete-day",
        provider_id="codex-oauth",
        app_type="codex",
        model="gpt-5",
        usage=TokenUsage::new(input_tokens=1, output_tokens=1),
        status_code=200,
        created_at=TREND_DAY_SECONDS * 70 + 23 * 60 * 60,
      ),
    )
    stats.record_request_log(
      RequestLog::new(
        request_id="retained-midnight",
        provider_id="codex-oauth",
        app_type="codex",
        model="gpt-5",
        usage=TokenUsage::new(input_tokens=1, output_tokens=1),
        status_code=200,
        created_at=TREND_DAY_SECONDS * 71,
      ),
    )
    assert_eq(stats.rollup_and_prune(retain_days=30, now_ts=now), 1)
    assert_eq(stats.daily_rollups.length(), 1)
    assert_eq(stats.request_logs.length(), 1)
    assert_eq(stats.request_logs[0].request_id, "retained-midnight")
  })
}

///|
test "usage trends follow process local timezone like moongate" {
  with_test_timezone("UTC", fn() raise {
    assert_eq(trend_timestamp_rfc3339(0), "1970-01-01T00:00:00+00:00")
    assert_eq(trend_local_day_key(-1), "1969-12-31")
  })
  with_test_timezone("PST8PDT", fn() raise {
    assert_eq(trend_timestamp_rfc3339(0), "1969-12-31T16:00:00-08:00")
    assert_eq(trend_local_day_key(0), "1969-12-31")
  })
}

///|
test "usage trends use local daily buckets for long ranges" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-day-zero",
      provider_id="codex-oauth",
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::new(
        input_tokens=100,
        output_tokens=10,
        cache_read_tokens=40,
      ),
      total_cost_usd="0.000100",
      status_code=200,
      created_at=100,
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-day-one",
      provider_id="codex-oauth",
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::new(input_tokens=10, output_tokens=5),
      total_cost_usd="0.000300",
      status_code=200,
      created_at=TREND_DAY_SECONDS + 100,
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-ignored",
      provider_id="anthropic",
      app_type="claude",
      model="claude-sonnet-4-6",
      usage=TokenUsage::new(input_tokens=1000, output_tokens=1000),
      total_cost_usd="9.000000",
      status_code=200,
      created_at=100,
    ),
  )
  let trends = stats.usage_trends_json(
    start_ts=Some(0),
    end_ts=Some(TREND_DAY_SECONDS * 2),
    app_type=Some("codex"),
  )
  guard trends is Array(rows) else { fail("expected trends array") }
  assert_eq(rows.length(), 3)
  guard rows[0] is Object(day_zero) else { fail("expected day zero bucket") }
  assert_eq(
    day_zero["date"],
    Json::string(trend_timestamp_rfc3339(trend_local_day_start_ts(0))),
  )
  assert_eq(day_zero["requestCount"], Json::number(1.0))
  assert_eq(day_zero["totalCost"], Json::string("0.000100"))
  assert_eq(day_zero["totalTokens"], Json::number(70.0))
  guard rows[1] is Object(day_one) else { fail("expected day one bucket") }
  assert_eq(day_one["requestCount"], Json::number(1.0))
  assert_eq(day_one["totalCost"], Json::string("0.000300"))
  assert_eq(day_one["totalTokens"], Json::number(15.0))
  guard rows[2] is Object(day_two) else { fail("expected day two bucket") }
  assert_eq(day_two["requestCount"], Json::number(0.0))
  assert_eq(day_two["totalCost"], Json::string("0.000000"))
}

///|
test "provider limit status matches moongate daily and monthly semantics" {
  let stats = TrafficStats::new()
  let now = TREND_DAY_SECONDS * 10
  stats.set_provider_limits(
    "codex-oauth",
    "codex",
    daily_limit_usd=Some("0.10"),
    monthly_limit_usd=Some("0.30"),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-today",
      provider_id="codex-oauth",
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::new(input_tokens=1, output_tokens=1),
      total_cost_usd="0.100000",
      status_code=200,
      created_at=now - 100,
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-month",
      provider_id="codex-oauth",
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::new(input_tokens=1, output_tokens=1),
      total_cost_usd="0.150000",
      status_code=200,
      created_at=now - TREND_DAY_SECONDS * 2,
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-ignored",
      provider_id="anthropic",
      app_type="claude",
      model="claude-sonnet-4-6",
      usage=TokenUsage::new(input_tokens=1, output_tokens=1),
      total_cost_usd="9.000000",
      status_code=200,
      created_at=now,
    ),
  )
  json_inspect(
    stats.provider_limit_status_json("codex-oauth", "codex", now_ts=Some(now)),
    content={
      "providerId": "codex-oauth",
      "dailyUsage": "0.100000",
      "dailyLimit": "0.10",
      "dailyExceeded": true,
      "monthlyUsage": "0.250000",
      "monthlyLimit": "0.30",
      "monthlyExceeded": false,
    },
  )
}

///|
test "provider limit status allows standalone query limits" {
  let stats = TrafficStats::new()
  let now = TREND_DAY_SECONDS * 10
  stats.record_request_log(
    RequestLog::new(
      request_id="req-today",
      provider_id="gemini-api-key",
      app_type="gemini",
      model="gemini-2.5-pro",
      usage=TokenUsage::new(input_tokens=1, output_tokens=1),
      total_cost_usd="0.020000",
      status_code=200,
      created_at=now,
    ),
  )
  json_inspect(
    stats.provider_limit_status_json(
      "gemini-api-key",
      "gemini",
      daily_limit_usd=Some("0.50"),
      now_ts=Some(now),
    ),
    content={
      "providerId": "gemini-api-key",
      "dailyUsage": "0.020000",
      "dailyLimit": "0.50",
      "dailyExceeded": false,
      "monthlyUsage": "0.020000",
      "monthlyLimit": null,
      "monthlyExceeded": false,
    },
  )
}

///|
test "moongate usage backfills missing costs after moongate pricing update" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-zero",
      provider_id="codex-oauth",
      app_type="codex",
      model="custom-backfill",
      usage=TokenUsage::new(input_tokens=10, output_tokens=5),
      total_cost_usd="0",
      status_code=200,
      created_at=1,
    ),
  )
  stats.record_request_log(
    RequestLog::new(
      request_id="req-priced",
      provider_id="codex-oauth",
      app_type="codex",
      model="custom-backfill",
      usage=TokenUsage::new(input_tokens=10, output_tokens=5),
      total_cost_usd="9.000000",
      status_code=200,
      created_at=2,
    ),
  )
  let updated = stats.backfill_missing_usage_costs_for_model(
    "custom-backfill",
    [mp("custom-backfill", "Custom Backfill", "2", "4", "0", "0")],
    Map([], capacity=0),
  )
  assert_eq(updated, 1)
  assert_eq(stats.request_logs[0].input_cost_usd, "0.00002")
  assert_eq(stats.request_logs[0].output_cost_usd, "0.00002")
  assert_eq(stats.request_logs[0].total_cost_usd, "0.00004")
  assert_eq(stats.request_logs[1].total_cost_usd, "9.000000")
}

///|
test "moongate usage backfill keeps moongate claude fresh input with cache read" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="claude-cache-fresh-input",
      provider_id="_session",
      app_type="claude",
      model="claude-haiku-4-5",
      usage=TokenUsage::new(
        input_tokens=100,
        output_tokens=0,
        cache_read_tokens=200,
      ),
      total_cost_usd="0",
      status_code=200,
      data_source="session_log",
      created_at=1,
    ),
  )
  let updated = stats.backfill_missing_usage_costs([], Map([], capacity=0))
  assert_eq(updated, 1)
  assert_eq(stats.request_logs[0].input_cost_usd, "0.0001")
  assert_eq(stats.request_logs[0].cache_read_cost_usd, "0.00002")
  assert_eq(stats.request_logs[0].total_cost_usd, "0.00012")
}

///|
test "moongate usage backfill uses persisted moongate pricing model" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-pricing-model",
      provider_id="codex-oauth",
      app_type="codex",
      model="upstream-unpriced",
      request_model=Some("client-alias"),
      pricing_model=Some("custom-backfill"),
      usage=TokenUsage::new(input_tokens=10, output_tokens=5),
      total_cost_usd="0",
      status_code=200,
      created_at=1,
    ),
  )
  let updated = stats.backfill_missing_usage_costs_for_model(
    "custom-backfill",
    [mp("custom-backfill", "Custom Backfill", "2", "4", "0", "0")],
    Map([], capacity=0),
  )
  assert_eq(updated, 1)
  assert_eq(stats.request_logs[0].input_cost_usd, "0.00002")
  assert_eq(stats.request_logs[0].output_cost_usd, "0.00002")
  assert_eq(stats.request_logs[0].total_cost_usd, "0.00004")
}

///|
test "usage logs lazily backfill missing costs like moongate reads" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-read-backfill",
      provider_id="codex-oauth",
      app_type="codex",
      model="upstream-unpriced",
      request_model=Some("client-alias"),
      pricing_model=Some("custom-backfill"),
      usage=TokenUsage::new(input_tokens=10, output_tokens=5),
      total_cost_usd="0",
      status_code=200,
      created_at=1,
    ),
  )
  guard stats.usage_logs_paginated_json(
      RequestLogFilters::new(),
      page=0,
      page_size=10,
      pricing_overrides=[
        mp("custom-backfill", "Custom Backfill", "2", "4", "0", "0"),
      ],
      deleted_model_ids=Map([], capacity=0),
    )
    is Object(page) else {
    fail("expected usage logs page")
  }
  guard page["data"] is Array(rows) else { fail("expected rows") }
  guard rows[0] is Object(row) else { fail("expected row") }
  assert_eq(row["inputCostUsd"], Json::string("0.00002"))
  assert_eq(row["outputCostUsd"], Json::string("0.00002"))
  assert_eq(row["totalCostUsd"], Json::string("0.00004"))
  assert_eq(stats.request_logs[0].total_cost_usd, "0.00004")
}

///|
test "request detail lazily backfills missing costs like moongate reads" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-detail-backfill",
      provider_id="codex-oauth",
      app_type="codex",
      model="upstream-unpriced",
      pricing_model=Some("custom-backfill"),
      usage=TokenUsage::new(input_tokens=10, output_tokens=5),
      total_cost_usd="0",
      status_code=200,
      created_at=1,
    ),
  )
  guard stats.request_detail_json_with_pricing(
      "req-detail-backfill",
      [mp("custom-backfill", "Custom Backfill", "2", "4", "0", "0")],
      Map([], capacity=0),
    )
    is Some(Object(detail)) else {
    fail("expected backfilled detail")
  }
  assert_eq(detail["inputCostUsd"], Json::string("0.00002"))
  assert_eq(detail["outputCostUsd"], Json::string("0.00002"))
  assert_eq(detail["totalCostUsd"], Json::string("0.00004"))
  assert_eq(stats.request_logs[0].total_cost_usd, "0.00004")
}

///|
test "moongate usage backfill does not use request model for real unpriced model" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="req-real-unpriced",
      provider_id="codex-oauth",
      app_type="codex",
      model="real-upstream-unpriced",
      request_model=Some("custom-backfill"),
      usage=TokenUsage::new(input_tokens=10, output_tokens=5),
      total_cost_usd="0",
      status_code=200,
      created_at=1,
    ),
  )
  let updated = stats.backfill_missing_usage_costs_for_model(
    "custom-backfill",
    [mp("custom-backfill", "Custom Backfill", "2", "4", "0", "0")],
    Map([], capacity=0),
  )
  assert_eq(updated, 0)
  assert_eq(stats.request_logs[0].total_cost_usd, "0")
}

///|
test "moongate usage exports prometheus metrics" {
  let stats = TrafficStats::new()
  let request = stats.begin_request(128)
  stats.record_stream_mode(request, true)
  stats.record_success_usage(
    request,
    TokenUsage::new(input_tokens=11, output_tokens=7),
    256,
  )
  let metrics = stats.prometheus_metrics()
  assert_true(metrics.contains("# TYPE moongate_requests_total counter\n"))
  assert_true(metrics.contains("moongate_requests_total 1"))
  assert_true(metrics.contains("moongate_streaming_requests_total 1"))
  assert_true(metrics.contains("moongate_successful_responses_total 1"))
  assert_true(metrics.contains("moongate_input_tokens_total 11"))
  assert_true(metrics.contains("moongate_output_tokens_total 7"))
  assert_true(metrics.contains("moongate_request_bytes_total 128"))
  assert_true(metrics.contains("moongate_response_bytes_total 256"))
  assert_true(metrics.contains("# TYPE moongate_active_connections gauge\n"))
  assert_true(metrics.contains("moongate_active_connections 0"))
  assert_true(metrics.contains("moongate_recent_avg_latency_ms"))
  assert_true(metrics.contains("moongate_success_rate_percent 100"))
}
