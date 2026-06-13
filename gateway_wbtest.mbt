///|
test "claude desktop model list matches ccs response shape" {
  json_inspect(claude_desktop_model_list_json(), content={
    "data": [
      {
        "type": "model",
        "id": "claude-sonnet-4-6",
        "created_at": "2024-01-01T00:00:00Z",
        "supports1m": true,
      },
      {
        "type": "model",
        "id": "claude-opus-4-8",
        "created_at": "2024-01-01T00:00:00Z",
        "supports1m": true,
      },
      {
        "type": "model",
        "id": "claude-haiku-4-5",
        "created_at": "2024-01-01T00:00:00Z",
        "supports1m": true,
      },
    ],
    "has_more": false,
    "first_id": "claude-sonnet-4-6",
    "last_id": "claude-haiku-4-5",
  })
}

///|
test "codex compact responses keep compact backend endpoint" {
  assert_eq(
    codex_backend_responses_endpoint(false),
    "/backend-api/codex/responses",
  )
  assert_eq(
    codex_backend_responses_endpoint(true),
    "/backend-api/codex/responses/compact",
  )
}

///|
test "usage request detail route extracts ccs request id" {
  assert_eq(usage_request_detail_id("/usage/request-detail/req_123"), "req_123")
  assert_eq(usage_request_detail_id("req_123"), "req_123")
}

///|
test "usage query helpers parse ccs trend parameters" {
  let path = "/usage/trends?start_date=10&endDate=20&app_type=codex"
  assert_eq(usage_query_int_any(path, "start_date", "startDate"), Some(10))
  assert_eq(usage_query_int_any(path, "end_date", "endDate"), Some(20))
  assert_eq(usage_query_value_any(path, "app_type", "appType"), Some("codex"))
  assert_eq(usage_query_value(path, "missing"), None)
  assert_eq(
    usage_query_int_any(
      "/usage/trends?start_date=bad", "start_date", "startDate",
    ),
    None,
  )
}

///|
test "usage query helpers parse ccs provider limit parameters" {
  let path = "/usage/provider-limits?providerId=codex-oauth&appType=codex&dailyLimitUsd=0.10&monthly_limit_usd=1.25"
  assert_eq(
    usage_query_value_any(path, "provider_id", "providerId"),
    Some("codex-oauth"),
  )
  assert_eq(usage_query_value_any(path, "app_type", "appType"), Some("codex"))
  assert_eq(
    usage_query_value_any(path, "daily_limit_usd", "dailyLimitUsd"),
    Some("0.10"),
  )
  assert_eq(
    usage_query_value_any(path, "monthly_limit_usd", "monthlyLimitUsd"),
    Some("1.25"),
  )
}

///|
test "usage query helpers parse ccs request log parameters" {
  let path = "/usage/logs?page=2&pageSize=25&appType=codex&providerName=OAuth&model=gpt&statusCode=200&startDate=10&end_date=20"
  assert_eq(usage_query_int(path, "page"), Some(2))
  assert_eq(usage_query_int_any(path, "page_size", "pageSize"), Some(25))
  assert_eq(usage_query_value_any(path, "app_type", "appType"), Some("codex"))
  assert_eq(
    usage_query_value_any(path, "provider_name", "providerName"),
    Some("OAuth"),
  )
  assert_eq(usage_query_value(path, "model"), Some("gpt"))
  assert_eq(usage_query_int_any(path, "status_code", "statusCode"), Some(200))
  assert_eq(usage_query_int_any(path, "start_date", "startDate"), Some(10))
  assert_eq(usage_query_int_any(path, "end_date", "endDate"), Some(20))
}

///|
test "usage pricing query helpers parse and validate ccs pricing update" {
  let path = "/usage/model-pricing?modelId=test-model&displayName=Test%20Model&inputCost=1.25&outputCost=2&cacheReadCost=0.10&cacheCreationCost=0"
  guard usage_pricing_from_query(path) is Some(pricing) else {
    fail("expected pricing")
  }
  assert_eq(pricing.model_id, "test-model")
  assert_eq(pricing.display_name, "Test%20Model")
  assert_eq(pricing.input_cost_per_million, "1.25")
  assert_eq(pricing.output_cost_per_million, "2")
  assert_eq(pricing.cache_read_cost_per_million, "0.10")
  assert_eq(pricing.cache_creation_cost_per_million, "0")
  assert_true(
    usage_pricing_from_query(
      "/usage/model-pricing?modelId=test&displayName=Test&inputCost=-1&outputCost=2&cacheReadCost=0&cacheCreationCost=0",
    )
    is None,
  )
  assert_true(
    usage_pricing_from_query(
      "/usage/model-pricing?modelId=test&displayName=Test&inputCost=abc&outputCost=2&cacheReadCost=0&cacheCreationCost=0",
    )
    is None,
  )
}

///|
test "codex responses endpoints preserve request query" {
  assert_eq(
    codex_backend_responses_endpoint(
      false,
      request_path="/v1/responses?beta=true&conversation=abc",
    ),
    "/backend-api/codex/responses?beta=true&conversation=abc",
  )
  assert_eq(
    codex_backend_responses_endpoint(
      true,
      request_path="/codex/v1/responses/compact?beta=true",
    ),
    "/backend-api/codex/responses/compact?beta=true",
  )
}

///|
test "claude desktop gateway bearer token validation" {
  assert_eq(bearer_token("Bearer moon-token"), Some("moon-token"))
  assert_eq(bearer_token("bearer moon-token  "), Some("moon-token"))
  assert_eq(bearer_token("Token moon-token"), None)
  assert_true(
    claude_desktop_authorization_valid(
      { "authorization": "Bearer moon-token" },
      "moon-token",
    ),
  )
  assert_false(
    claude_desktop_authorization_valid(
      { "authorization": "Bearer wrong-token" },
      "moon-token",
    ),
  )
  assert_false(claude_desktop_authorization_valid({}, "moon-token"))
}

///|
test "claude desktop model normalization matches ccs aliases" {
  assert_eq(
    normalize_claude_desktop_model_id("claude-opus-4-7"),
    "claude-opus-4-8",
  )
  assert_eq(
    normalize_claude_desktop_model_id("claude-opus-4-8[1m]"),
    "claude-opus-4-8",
  )
  assert_eq(
    normalize_claude_desktop_model_id("claude-sonnet-4-6 [1M]"),
    "claude-sonnet-4-6",
  )
  assert_eq(
    normalize_claude_desktop_model_id("claude-haiku-4-5-20251001"),
    "claude-haiku-4-5",
  )
  assert_eq(
    normalize_claude_desktop_model_id("anthropic/claude-opus-4-8"),
    "claude-opus-4-8",
  )
  assert_eq(normalize_claude_desktop_model_id("gpt-5[1m]"), "gpt-5[1m]")
}

///|
test "claude safe model id rejects ccs unsafe ids" {
  assert_false(is_claude_safe_model_id("claude-sonnet-4-6 [1m]"))
  assert_false(is_claude_safe_model_id("claude-old"))
  assert_false(is_claude_safe_model_id("claude-3-5-sonnet-20241022"))
  assert_false(is_claude_safe_model_id("claude-deepseek-v4-pro"))
  assert_false(is_claude_safe_model_id("claude-gpt-5-4"))
  assert_false(is_claude_safe_model_id("claude-sonnet-"))
  assert_true(is_claude_safe_model_id("  claude-sonnet-4-6  "))
  assert_true(is_claude_safe_model_id("anthropic/claude-opus-4-8"))
}

///|
test "ccs session extraction uses claude metadata and headers" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "messages": [],
      #|  "metadata": {
      #|    "user_id": "user_jane_session_claude-session-1",
      #|    "session_id": "metadata-session"
      #|  }
      #|}
    ),
  )
  assert_eq(
    extract_client_session_id({}, body, "claude"),
    Some("claude-session-1"),
  )
  assert_eq(
    extract_client_session_id(
      { "x-claude-code-session-id": "header-session" },
      body,
      "claude",
    ),
    Some("header-session"),
  )
}

///|
test "ccs session extraction prefixes codex client ids" {
  let body = @json.parse(
    (
      #|{
      #|  "input": "hello",
      #|  "metadata": {
      #|    "session_id": "metadata-session-123456789"
      #|  },
      #|  "previous_response_id": "resp_should_not_be_session"
      #|}
    ),
  )
  assert_eq(
    extract_client_session_id(
      { "session_id": "12345678-1234-1234-1234-123456789012" },
      body,
      "codex",
    ),
    Some("codex_12345678-1234-1234-1234-123456789012"),
  )
  assert_eq(
    extract_client_session_id({}, body, "codex"),
    Some("codex_metadata-session-123456789"),
  )
  assert_eq(
    extract_client_session_id(
      {},
      @json.parse("{\"previous_response_id\":\"resp_only\"}"),
      "codex",
    ),
    None,
  )
}

///|
test "codex oauth headers propagate ccs session headers" {
  let creds = @codex.Credentials::{
    idToken: "id",
    accessToken: "access",
    refreshToken: "refresh",
    accountId: "account",
  }
  let headers = codex_oauth_headers(
    creds,
    "text/event-stream",
    Some("codex_session-1"),
  )
  assert_eq(headers["Authorization"], "Bearer access")
  assert_eq(headers["ChatGPT-Account-ID"], "account")
  assert_eq(headers["Accept"], "text/event-stream")
  assert_eq(headers["session_id"], "codex_session-1")
  assert_eq(headers["x-client-request-id"], "codex_session-1")
  assert_eq(headers["x-codex-window-id"], "codex_session-1")
}

///|
test "codex to anthropic response emits ccs cache usage buckets" {
  let body = @json.parse(
    (
      #|{
      #|  "id": "resp_1",
      #|  "model": "gpt-5",
      #|  "output": [
      #|    {
      #|      "type": "message",
      #|      "content": [
      #|        { "type": "output_text", "text": "done" }
      #|      ]
      #|    }
      #|  ],
      #|  "usage": {
      #|    "input_tokens": 100,
      #|    "output_tokens": 7,
      #|    "input_tokens_details": { "cached_tokens": 31 },
      #|    "cache_creation_input_tokens": 5
      #|  }
      #|}
    ),
  )
  let response = convert_codex_to_anthropic(body, "claude-sonnet-4-6")
  json_inspect(response.usage.to_json(), content={
    "input_tokens": 64,
    "output_tokens": 7,
    "cache_read_input_tokens": 31,
    "cache_creation_input_tokens": 5,
  })
}

///|
test "moonstat default provider router selects suite app targets" {
  let router = moonstat_default_provider_router()
  let codex = router.select_providers("codex", now_ms=1000)
  assert_true(codex.is_ok())
  match codex_provider_from_env() {
    Some(provider) => {
      assert_true(codex.providers.length() == 2)
      assert_true(codex.providers[0].provider_id == provider.provider_id)
      assert_true(codex.providers[0].can_use_codex_compatible_upstream())
      assert_true(codex.providers[1].provider_id == "codex-oauth")
    }
    None => {
      assert_true(codex.providers.length() == 1)
      assert_true(codex.providers[0].provider_id == "codex-oauth")
      assert_true(codex.providers[0].provider_type == Some("codex_oauth"))
    }
  }
  let gemini = router.select_providers("gemini", now_ms=1000)
  assert_true(gemini.is_ok())
  assert_eq(gemini.providers.length(), 1)
  assert_eq(gemini.providers[0].provider_id, "gemini-api-key")
  let claude = router.select_providers("claude-desktop", now_ms=1000)
  assert_true(claude.is_ok())
  assert_eq(claude.providers.length(), 1)
  assert_eq(claude.providers[0].provider_name, "Codex OAuth")
  assert_eq(claude.providers[0].provider_type, Some("codex_oauth"))
}

///|
test "gateway records upstream failures into provider router before finish" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.stats.record_inbound(10)
  let _ = gateway.activate_provider("codex")
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.record_provider_result(false)
  gateway.stats.record_upstream_error_status(0, 502)
  assert_eq(gateway.stats.current_request_app_type, None)
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Open)
  assert_eq(stats.total_requests, 1)
  assert_eq(stats.failed_requests, 1)
}

///|
test "ccs upstream status retryability matches client error bucket" {
  assert_false(ccs_upstream_status_retryable(400))
  assert_false(ccs_upstream_status_retryable(422))
  assert_false(ccs_upstream_status_retryable(501))
  assert_true(ccs_upstream_status_retryable(401))
  assert_true(ccs_upstream_status_retryable(429))
  assert_true(ccs_upstream_status_retryable(502))
}

///|
async test "gateway nonretryable upstream errors release half open permit" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 0,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  gateway.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.provider_router.set_auto_failover("codex", true)

  gateway.stats.record_inbound(10)
  let _ = gateway.activate_provider("codex")
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.record_provider_result(false)
  gateway.stats.record_upstream_error_status(0, 502)

  gateway.stats.record_inbound(10)
  let _ = gateway.activate_provider("codex")
  assert_true(gateway.stats.current_request_used_half_open_permit)
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.record_upstream_error_status(0, 400)

  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == HalfOpen)
  assert_eq(stats.total_requests, 1)
  assert_eq(stats.failed_requests, 1)

  gateway.stats.record_inbound(10)
  let third = gateway.activate_provider("codex")
  assert_true(third is Some(_))
  assert_true(gateway.stats.current_request_used_half_open_permit)
}

///|
async test "gateway streaming success records provider health before request completion" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.stats.record_inbound(16)
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.stats.record_stream_mode(true)
  let selected = gateway.activate_provider("codex")
  guard selected is Some(provider) else { fail("expected provider") }
  assert_true(provider.provider_id == "codex-oauth")

  gateway.record_provider_result(true)
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats_after_first_chunk) else {
    fail("expected circuit stats")
  }
  assert_true(stats_after_first_chunk.total_requests == 1)
  assert_true(stats_after_first_chunk.failed_requests == 0)
  assert_true(gateway.stats.successful_responses == 0)
  guard gateway.stats.current_request_id is Some(_) else {
    fail("request should remain open until stream end")
  }

  gateway.record_success_stats_only(0, 0, 24)
  assert_true(gateway.stats.successful_responses == 1)
  assert_true(gateway.stats.response_bytes == 24)
  assert_true(gateway.stats.current_request_id is None)
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats_after_stream_end) else {
    fail("expected circuit stats")
  }
  assert_true(stats_after_stream_end.total_requests == 1)
  assert_true(stats_after_stream_end.failed_requests == 0)
}

///|
test "gateway activation skips occupied half open provider in failover chain" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 0,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  gateway.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.provider_router.set_auto_failover("codex", true)
  gateway.provider_router.record_result(
    "codex-oauth",
    "codex",
    false,
    false,
    now_ms=1000,
  )
  let occupied = gateway.provider_router.allow_provider_request(
    "codex-oauth",
    "codex",
    now_ms=1000,
  )
  assert_true(occupied.allowed)
  assert_true(occupied.used_half_open_permit)

  let selected = gateway.activate_provider("codex")
  guard selected is Some(provider) else { fail("expected fallback provider") }
  assert_eq(provider.provider_id, "codex-alt")
  assert_eq(gateway.stats.current_provider_id, Some("codex-alt"))
  assert_false(gateway.stats.current_request_used_half_open_permit)
}

///|
test "gateway activation can exclude already attempted failover providers" {
  let gateway = Gateway::new(port=0)
  let providers = [
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="primary",
      provider_name="Primary",
    ),
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="fallback",
      provider_name="Fallback",
    ),
  ]
  for provider in providers {
    gateway.provider_router.upsert_provider(provider)
  }
  let selected = gateway.activate_first_available_provider_excluding(
    "codex",
    providers,
    ["primary"],
  )
  guard selected is Some(provider) else {
    fail("expected unattempted fallback provider")
  }
  assert_eq(provider.provider_id, "fallback")
  assert_eq(gateway.stats.current_provider_id, Some("fallback"))
}

///|
test "gateway retryable upstream status activates next failover provider" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  gateway.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.provider_router.set_auto_failover("codex", true)
  let selection = gateway.provider_router.select_providers("codex", now_ms=1000)
  assert_true(selection.is_ok())
  assert_true(selection.providers.length() == 2)

  gateway.stats.record_inbound(10)
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  let first = gateway.activate_first_available_provider(
    "codex",
    selection.providers,
  )
  guard first is Some(primary) else { fail("expected primary provider") }
  assert_true(primary.provider_id == "codex-oauth")

  let attempted : Array[String] = []
  let next = gateway.activate_next_provider_after_upstream_status(
    "codex",
    selection.providers,
    attempted,
    502,
  )
  guard next is Some(fallback) else { fail("expected fallback provider") }
  assert_true(attempted.length() == 1)
  assert_true(attempted[0] == "codex-oauth")
  assert_true(fallback.provider_id == "codex-alt")
  guard gateway.stats.current_provider_id is Some(current_provider_id) else {
    fail("expected current provider id")
  }
  assert_true(current_provider_id == "codex-alt")
  guard gateway.stats.current_request_app_type is Some(current_app_type) else {
    fail("expected current request app type")
  }
  assert_true(current_app_type == "codex")
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected primary circuit stats")
  }
  assert_true(stats.state == Open)
  assert_true(stats.total_requests == 1)
  assert_true(stats.failed_requests == 1)
}

///|
test "gateway retryable final provider remains active for final upstream error" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  let selection = gateway.provider_router.select_providers("codex", now_ms=1000)
  assert_true(selection.is_ok())
  assert_true(selection.providers.length() == 1)

  gateway.stats.record_inbound(10)
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  let selected = gateway.activate_first_available_provider(
    "codex",
    selection.providers,
  )
  guard selected is Some(provider) else { fail("expected provider") }
  assert_true(provider.provider_id == "codex-oauth")

  let attempted : Array[String] = []
  let next = gateway.activate_next_provider_after_upstream_status(
    "codex",
    selection.providers,
    attempted,
    502,
  )
  assert_true(next is None)
  assert_true(attempted.length() == 1)
  assert_true(attempted[0] == "codex-oauth")
  guard gateway.stats.current_provider_id is Some(current_provider_id) else {
    fail("expected current provider id")
  }
  assert_true(current_provider_id == "codex-oauth")
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Open)
  assert_true(stats.total_requests == 1)
  assert_true(stats.failed_requests == 1)
}

///|
test "gateway nonretryable upstream status does not activate failover provider" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  gateway.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.provider_router.set_auto_failover("codex", true)
  let selection = gateway.provider_router.select_providers("codex", now_ms=1000)
  assert_true(selection.is_ok())
  assert_true(selection.providers.length() == 2)

  gateway.stats.record_inbound(10)
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  let selected = gateway.activate_first_available_provider(
    "codex",
    selection.providers,
  )
  guard selected is Some(provider) else { fail("expected provider") }
  assert_true(provider.provider_id == "codex-oauth")

  let attempted : Array[String] = []
  let next = gateway.activate_next_provider_after_upstream_status(
    "codex",
    selection.providers,
    attempted,
    400,
  )
  assert_true(next is None)
  assert_true(attempted.length() == 1)
  assert_true(attempted[0] == "codex-oauth")
  guard gateway.stats.current_provider_id is Some(current_provider_id) else {
    fail("expected current provider id")
  }
  assert_true(current_provider_id == "codex-oauth")
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Closed)
  assert_true(stats.total_requests == 0)
  assert_true(stats.failed_requests == 0)
}

///|
test "gateway activation bypasses circuit breaker for single provider" {
  let gateway = Gateway::new(port=0)
  gateway.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.provider_router.record_result(
    "codex-oauth",
    "codex",
    false,
    false,
    now_ms=1000,
  )
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Open)

  let selected = gateway.activate_provider("codex")
  guard selected is Some(provider) else {
    fail("single provider should bypass circuit gating")
  }
  assert_eq(provider.provider_id, "codex-oauth")
  assert_eq(gateway.stats.current_provider_id, Some("codex-oauth"))
  assert_false(gateway.stats.current_request_used_half_open_permit)
}

///|
test "codex compatible provider url follows ccs base url rules" {
  assert_true(
    codex_compatible_provider_url("https://api.openai.com", "/responses") ==
    "https://api.openai.com/v1/responses",
  )
  assert_true(
    codex_compatible_provider_url(
      "https://api.openai.com/v1", "/v1/responses?conversation=abc",
    ) ==
    "https://api.openai.com/v1/responses?conversation=abc",
  )
  assert_true(
    codex_compatible_provider_url(
      "https://proxy.example.com/openai", "/responses",
    ) ==
    "https://proxy.example.com/openai/responses",
  )
  assert_true(
    codex_compatible_provider_url(
      "https://proxy.example.com/v1/responses", "/responses?conversation=abc",
    ) ==
    "https://proxy.example.com/v1/responses?conversation=abc",
  )
}

///|
test "gateway detects active direct codex compatible provider" {
  let gateway = Gateway::new(port=0)
  let providers = [
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-openai",
      provider_name="OpenAI",
      provider_type=Some("codex"),
      base_url=Some("https://api.openai.com/v1"),
      api_key=Some("sk-test"),
    ),
  ]
  guard gateway.active_provider_target(providers) is Some(active) else {
    fail("expected active provider")
  }
  assert_true(active.provider_id == "codex-openai")
  assert_true(active.can_use_codex_compatible_upstream())
}
