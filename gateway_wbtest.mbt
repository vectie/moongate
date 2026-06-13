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
test "usage pricing store rows use ccs field names" {
  let row = model_pricing_store_json(
    mp("test-model", "Test Model", "1", "2", "0.1", "0"),
    deleted=false,
  )
  guard row is Object(obj) else { fail("expected pricing row") }
  assert_eq(obj["modelId"], Json::string("test-model"))
  assert_eq(obj["displayName"], Json::string("Test Model"))
  assert_eq(obj["inputCostPerMillion"], Json::string("1"))
  assert_eq(obj["deleted"], Json::boolean(false))
  guard model_pricing_from_store_json(obj) is Some(parsed) else {
    fail("expected parsed pricing row")
  }
  assert_eq(parsed.model_id, "test-model")
  assert_eq(parsed.cache_read_cost_per_million, "0.1")
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
test "gateway uses ccs model mapping for upstream claude model" {
  let gateway = Gateway::new(port=0, model="gpt-default")
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="mapped",
    provider_name="Mapped",
    model_mapping=Some(
      ModelMapping::new(sonnet_model=Some("deepseek-v4-pro [1M]")),
    ),
  )
  assert_eq(
    gateway.upstream_claude_model("claude-sonnet-4-6", Some(provider)),
    "deepseek-v4-pro",
  )
  let unmapped = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="plain",
    provider_name="Plain",
  )
  assert_eq(
    gateway.upstream_claude_model("claude-sonnet-4-6", Some(unmapped)),
    "gpt-default",
  )
}

///|
async test "gateway records billable ccs stream usage once" {
  let gateway = Gateway::new(port=0)
  gateway.stats.record_inbound(10)
  let _ = gateway.activate_provider("codex")
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.stats.record_stream_mode(true)
  gateway.record_success_stream_usage(
    Some(
      TokenUsage::new(
        input_tokens=10,
        output_tokens=2,
        cache_read_tokens=4,
        model=Some("gpt-5"),
      ),
    ),
    42,
  )
  assert_eq(gateway.stats.successful_responses, 1)
  assert_eq(gateway.stats.input_tokens, 10)
  assert_eq(gateway.stats.cache_read_tokens, 4)
  assert_eq(gateway.stats.request_logs.length(), 1)
  let log = gateway.stats.request_logs[0]
  assert_true(log.is_streaming)
  assert_eq(log.model, "gpt-5")
  assert_eq(log.input_tokens, 10)
  guard gateway.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_eq(stats.total_requests, 1)
}

///|
async test "gateway skips all zero ccs stream usage request log" {
  let gateway = Gateway::new(port=0)
  gateway.stats.record_inbound(10)
  let _ = gateway.activate_provider("codex")
  gateway.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.stats.record_stream_mode(true)
  gateway.record_success_stream_usage(Some(TokenUsage::empty()), 42)
  assert_eq(gateway.stats.successful_responses, 1)
  assert_eq(gateway.stats.response_bytes, 42)
  assert_eq(gateway.stats.request_logs.length(), 0)
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

  gateway.record_success_stream_usage(None, 24, record_provider=false)
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
test "claude compatible provider api format follows ccs endpoints" {
  let chat_provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="openai-chat",
    provider_name="OpenAI Chat",
    provider_type=Some("openai"),
    api_format=Some("openai_chat"),
    base_url=Some("https://api.openai.com/v1"),
    api_key=Some("sk-test"),
  )
  assert_eq(chat_provider.claude_api_format(), "openai_chat")
  assert_true(chat_provider.can_use_claude_compatible_upstream())
  assert_eq(
    claude_transform_endpoint(chat_provider.claude_api_format(), false),
    "/v1/chat/completions",
  )
  assert_eq(
    codex_compatible_provider_url(
      "https://api.openai.com/v1",
      claude_transform_endpoint(chat_provider.claude_api_format(), false),
    ),
    "https://api.openai.com/v1/chat/completions",
  )

  let responses_provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="openai-responses",
    provider_name="OpenAI Responses",
    api_format=Some("openai_responses"),
    base_url=Some("https://api.openai.com"),
    api_key=Some("sk-test"),
  )
  assert_eq(
    claude_transform_endpoint(responses_provider.claude_api_format(), false),
    "/v1/responses",
  )
  assert_eq(
    codex_compatible_provider_url(
      "https://api.openai.com",
      claude_transform_endpoint(responses_provider.claude_api_format(), false),
    ),
    "https://api.openai.com/v1/responses",
  )
}

///|
test "claude upstream request json rewrites mapped model" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "max_tokens": 128,
      #|  "messages": [
      #|    { "role": "user", "content": "hello" }
      #|  ]
      #|}
    ),
  )
  let upstream = claude_request_json_for_upstream(body, "gpt-5.4")
  guard upstream is Object(obj) else { fail("expected object") }
  assert_eq(obj["model"], Json::string("gpt-5.4"))
  assert_true(obj.get("messages") is Some(_))
}

///|
test "claude stream upstream request forces stream true" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "max_tokens": 128,
      #|  "stream": false,
      #|  "messages": [
      #|    { "role": "user", "content": "hello" }
      #|  ]
      #|}
    ),
  )
  let upstream = claude_stream_request_json_for_upstream(body, "gpt-5.4")
  guard upstream is Object(obj) else { fail("expected object") }
  assert_eq(obj["model"], Json::string("gpt-5.4"))
  assert_eq(obj["stream"], Json::boolean(true))
}

///|
test "ccs upstream body filter removes private fields" {
  let body = @json.parse(
    (
      #|{
      #|  "z": 1,
      #|  "_internal": "drop",
      #|  "tools": [
      #|    {
      #|      "name": "lookup",
      #|      "parameters": {
      #|        "type": "object",
      #|        "properties": {
      #|          "_id": {
      #|            "_private_note": "drop",
      #|            "type": "string"
      #|          },
      #|          "b": { "type": "number" },
      #|          "a": { "type": "string" }
      #|        }
      #|      }
      #|    }
      #|  ],
      #|  "a": 2
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body)
  guard prepared is Object(obj) else { fail("expected object") }
  assert_true(obj.get("_internal") is None)
  guard obj["tools"] is Array(tools) else { fail("expected tools") }
  guard tools[0] is Object(tool) else { fail("expected tool") }
  guard tool["parameters"] is Object(parameters) else {
    fail("expected parameters")
  }
  guard parameters["properties"] is Object(properties) else {
    fail("expected properties")
  }
  assert_true(properties.get("_id") is Some(_))
  guard properties["_id"] is Object(id_property) else {
    fail("expected _id property")
  }
  assert_true(id_property.get("_private_note") is None)
  assert_eq(id_property["type"], Json::string("string"))
}

///|
test "ccs media sanitizer replaces images for known text-only models" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "deepseek/deepseek-v4-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          },
      #|          "cache_control": { "type": "ephemeral" }
      #|        },
      #|        { "type": "text", "text": "caption" }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body)
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(marker) else { fail("expected marker") }
  assert_eq(marker["type"], Json::string("text"))
  assert_eq(marker["text"], Json::string("[Unsupported Image]"))
  assert_true(marker.get("source") is None)
  assert_eq(
    marker["cache_control"],
    Json::object({ "type": Json::string("ephemeral") }),
  )
  assert_eq(
    content[1],
    Json::object({
      "type": Json::string("text"),
      "text": Json::string("caption"),
    }),
  )
}

///|
test "ccs media sanitizer preserves images for unknown models" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "kimi/kimi-k2.6",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image_url",
      #|          "image_url": { "url": "data:image/png;base64,AAAA" }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body)
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(image) else { fail("expected image") }
  assert_eq(image["type"], Json::string("image_url"))
  assert_true(image.get("image_url") is Some(_))
}

///|
test "ccs media sanitizer replaces nested and responses image blocks" {
  let nested_body = @json.parse(
    (
      #|{
      #|  "model": "therouter/qwen/qwen3-coder-480b",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "tool_result",
      #|          "tool_use_id": "tool_1",
      #|          "content": [
      #|            {
      #|              "type": "image_url",
      #|              "image_url": { "url": "data:image/png;base64,AAAA" }
      #|            }
      #|          ]
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let nested_prepared = prepare_upstream_request_body(nested_body)
  guard nested_prepared is Object(nested_obj) else { fail("expected object") }
  guard nested_obj["messages"] is Array(messages) else {
    fail("expected messages")
  }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(tool_result) else { fail("expected tool result") }
  guard tool_result["content"] is Array(tool_content) else {
    fail("expected tool content")
  }
  guard tool_content[0] is Object(nested_marker) else {
    fail("expected marker")
  }
  assert_eq(nested_marker["type"], Json::string("text"))
  assert_eq(nested_marker["text"], Json::string("[Unsupported Image]"))

  let responses_body = @json.parse(
    (
      #|{
      #|  "model": "deepseek-v4-flash",
      #|  "input": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "input_image",
      #|          "image_url": "data:image/png;base64,AAAA"
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let responses_prepared = prepare_upstream_request_body(responses_body)
  guard responses_prepared is Object(responses_obj) else {
    fail("expected object")
  }
  guard responses_obj["input"] is Array(input) else { fail("expected input") }
  guard input[0] is Object(input_item) else { fail("expected input item") }
  guard input_item["content"] is Array(input_content) else {
    fail("expected input content")
  }
  guard input_content[0] is Object(input_marker) else {
    fail("expected input marker")
  }
  assert_eq(input_marker["type"], Json::string("input_text"))
  assert_eq(input_marker["text"], Json::string("[Unsupported Image]"))
  assert_true(input_marker.get("image_url") is None)
}

///|
test "ccs media retry detects unsupported image upstream errors" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "xiaomi-mimo-token-plan/mimo-v2.5-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  assert_true(contains_image_blocks(body))
  assert_true(
    ccs_media_retry_should_trigger(
      400, "{\"error\":{\"message\":\"This model does not support image input\"}}",
      body,
    ),
  )
  assert_true(
    ccs_media_retry_should_trigger(
      415, "{\"error\":{\"message\":\"This model cannot process media inputs\"}}",
      body,
    ),
  )
  assert_true(
    ccs_media_retry_should_trigger(
      422, "{\"message\":\"attachments are not supported by this model\"}", body,
    ),
  )
  assert_true(
    ccs_media_retry_should_trigger(
      400,
      (
        #|{
        #|  "error": {
        #|    "message": "Failed to deserialize the JSON body: unknown variant image_url, expected text"
        #|  }
        #|}
      ),
      body,
    ),
  )
}

///|
test "ccs media retry ignores non media errors and bodies without images" {
  let image_body = @json.parse(
    (
      #|{
      #|  "model": "any-model",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image_url",
      #|          "image_url": { "url": "data:image/png;base64,AAAA" }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  assert_false(
    ccs_media_retry_should_trigger(
      400, "{\"error\":{\"message\":\"Invalid API key\"}}", image_body,
    ),
  )
  assert_false(
    ccs_media_retry_should_trigger(
      429, "{\"error\":{\"message\":\"This model does not support image input\"}}",
      image_body,
    ),
  )

  let text_body = @json.parse(
    (
      #|{
      #|  "model": "any-model",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [{ "type": "text", "text": "hello" }]
      #|    }
      #|  ]
      #|}
    ),
  )
  assert_false(contains_image_blocks(text_body))
  assert_false(
    ccs_media_retry_should_trigger(
      400, "{\"error\":{\"message\":\"This model does not support image input\"}}",
      text_body,
    ),
  )
}

///|
test "ccs media retry replacement is unconditional" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "xiaomi-mimo-token-plan/mimo-v2.5-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let result = replace_image_blocks_with_marker(body)
  assert_eq(result.count, 1)
  guard result.body is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(marker) else { fail("expected marker") }
  assert_eq(marker["type"], Json::string("text"))
  assert_eq(marker["text"], Json::string("[Unsupported Image]"))
}

///|
test "ccs media retry handles streaming upstream bodies" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "max_tokens": 128,
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image_url",
      #|          "image_url": { "url": "data:image/png;base64,AAAA" }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let upstream = prepare_upstream_request_body(
    claude_stream_request_json_for_upstream(body, "kimi/kimi-k2.6"),
  )
  guard upstream is Object(obj) else { fail("expected object") }
  assert_eq(obj["stream"], Json::boolean(true))
  assert_true(contains_image_blocks(upstream))
  assert_true(
    ccs_media_retry_should_trigger(
      400, "{\"error\":{\"message\":\"This model does not support image input\"}}",
      upstream,
    ),
  )

  let retry_body = replace_image_blocks_with_marker(upstream)
  guard retry_body.body is Object(retry_obj) else { fail("expected retry") }
  assert_eq(retry_obj["stream"], Json::boolean(true))
  guard retry_obj["messages"] is Array(messages) else {
    fail("expected messages")
  }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(marker) else { fail("expected marker") }
  assert_eq(marker["type"], Json::string("text"))
  assert_eq(marker["text"], Json::string("[Unsupported Image]"))
}

///|
test "openai chat completion converts to anthropic response" {
  let body = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    {
      #|      "message": {
      #|        "role": "assistant",
      #|        "content": "done",
      #|        "tool_calls": [
      #|          {
      #|            "id": "call_1",
      #|            "type": "function",
      #|            "function": {
      #|              "name": "lookup",
      #|              "arguments": "{\"query\":\"moon\"}"
      #|            }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ],
      #|  "usage": {
      #|    "prompt_tokens": 10,
      #|    "completion_tokens": 2,
      #|    "prompt_tokens_details": { "cached_tokens": 3 }
      #|  }
      #|}
    ),
  )
  let response = openai_chat_completion_to_anthropic(body, "claude-sonnet-4-6")
  assert_eq(response.id, "chatcmpl_1")
  assert_eq(response.model, "claude-sonnet-4-6")
  assert_eq(response.stop_reason, Some("tool_use"))
  assert_eq(response.usage.input_tokens, 7)
  assert_eq(response.usage.output_tokens, 2)
  assert_eq(response.usage.cache_read_input_tokens, Some(3))
  assert_eq(response.content.length(), 2)
  assert_eq(response.content[0].type_, "text")
  assert_eq(response.content[0].text, Some("done"))
  assert_eq(response.content[1].type_, "tool_use")
  assert_eq(response.content[1].name, Some("lookup"))
  assert_eq(response.content[1].id, Some("call_1"))
}

///|
test "openai chat stream chunk converts to anthropic events" {
  let chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": { "content": "hi" },
      #|      "finish_reason": null
      #|    }
      #|  ]
      #|}
    ),
  )
  let events = openai_chat_stream_chunk_to_anthropic_events(chunk)
  assert_eq(events.length(), 3)
  assert_eq(events[0].event_type, "message_start")
  let start_data = @json.parse(events[0].data)
  guard start_data is Object(start_obj) else { fail("expected object") }
  guard start_obj["message"] is Object(message) else {
    fail("expected message")
  }
  assert_eq(message["id"], Json::string("chatcmpl_1"))
  assert_eq(message["model"], Json::string("gpt-4o"))
  assert_eq(events[1].event_type, "content_block_start")
  assert_eq(events[2].event_type, "content_block_delta")
  let event_data = @json.parse(events[2].data)
  guard event_data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["text"], Json::string("hi"))
}

///|
test "openai chat stream finalizes usage after done" {
  let state = OpenAIChatAnthropicStreamState::new()
  let chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": { "content": "hi" },
      #|      "finish_reason": null
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(chunk)
  let done = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": {},
      #|      "finish_reason": "tool_calls"
      #|    }
      #|  ],
      #|  "usage": {
      #|    "prompt_tokens": 9,
      #|    "completion_tokens": 3,
      #|    "prompt_tokens_details": { "cached_tokens": 2 }
      #|  }
      #|}
    ),
  )
  let prepared = state.push_chunk(done)
  assert_eq(prepared.length(), 1)
  assert_eq(prepared[0].event_type, "content_block_stop")
  let done_events = state.finish()
  assert_eq(done_events.length(), 2)
  assert_eq(done_events[0].event_type, "message_delta")
  assert_eq(done_events[1].event_type, "message_stop")
  let done_data = @json.parse(done_events[0].data)
  guard done_data is Object(done_obj) else { fail("expected object") }
  guard done_obj["delta"] is Object(done_delta) else { fail("expected delta") }
  assert_eq(done_delta["stop_reason"], Json::string("tool_use"))
  guard done_obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(7.0))
  assert_eq(usage["output_tokens"], Json::number(3.0))
  assert_eq(usage["cache_read_input_tokens"], Json::number(2.0))
}

///|
test "openai chat stream tool calls keep distinct indexes" {
  let state = OpenAIChatAnthropicStreamState::new()
  let first = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_2",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    {
      #|      "delta": {
      #|        "tool_calls": [
      #|          {
      #|            "index": 0,
      #|            "id": "call_0",
      #|            "function": { "name": "first_tool" }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let second = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "delta": {
      #|        "tool_calls": [
      #|          {
      #|            "index": 1,
      #|            "id": "call_1",
      #|            "function": { "name": "second_tool" }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let args = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "delta": {
      #|        "tool_calls": [
      #|          { "index": 1, "function": { "arguments": "{\"b\":2}" } },
      #|          { "index": 0, "function": { "arguments": "{\"a\":1}" } }
      #|        ]
      #|      },
      #|      "finish_reason": "tool_calls"
      #|    }
      #|  ]
      #|}
    ),
  )
  let first_events = state.push_chunk(first)
  let second_events = state.push_chunk(second)
  let arg_events = state.push_chunk(args)
  assert_eq(first_events[1].event_type, "content_block_start")
  assert_eq(second_events[0].event_type, "content_block_start")
  let first_start = @json.parse(first_events[1].data)
  let second_start = @json.parse(second_events[0].data)
  guard first_start is Object(first_obj) else { fail("expected object") }
  guard second_start is Object(second_obj) else { fail("expected object") }
  assert_true(first_obj["index"] != second_obj["index"])
  let deltas = arg_events.filter(event => {
    event.event_type == "content_block_delta"
  })
  assert_eq(deltas.length(), 2)
  let delta_a = @json.parse(deltas[1].data)
  let delta_b = @json.parse(deltas[0].data)
  guard delta_a is Object(delta_a_obj) else { fail("expected delta") }
  guard delta_b is Object(delta_b_obj) else { fail("expected delta") }
  guard delta_a_obj["delta"] is Object(delta_a_payload) else {
    fail("expected payload")
  }
  guard delta_b_obj["delta"] is Object(delta_b_payload) else {
    fail("expected payload")
  }
  assert_eq(delta_a_payload["partial_json"], Json::string("{\"a\":1}"))
  assert_eq(delta_b_payload["partial_json"], Json::string("{\"b\":2}"))
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

///|
test "gemini native stream emits cumulative text deltas" {
  let state = GeminiNativeAnthropicStreamState::new()
  let first = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_1",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    { "content": { "parts": [ { "text": "Hel" } ] } }
      #|  ],
      #|  "usageMetadata": { "promptTokenCount": 10, "totalTokenCount": 13 }
      #|}
    ),
  )
  let second = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_1",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": { "parts": [ { "text": "Hello" } ] }
      #|    }
      #|  ],
      #|  "usageMetadata": { "promptTokenCount": 10, "totalTokenCount": 15 }
      #|}
    ),
  )
  let first_events = state.push_chunk(first)
  let second_events = state.push_chunk(second)
  let finish_events = state.finish()
  assert_eq(first_events[0].event_type, "message_start")
  assert_eq(first_events[1].event_type, "content_block_start")
  let first_delta = @json.parse(first_events[2].data)
  let second_delta = @json.parse(second_events[0].data)
  guard first_delta is Object(first_obj) else { fail("expected first delta") }
  guard second_delta is Object(second_obj) else {
    fail("expected second delta")
  }
  guard first_obj["delta"] is Object(first_payload) else {
    fail("expected first payload")
  }
  guard second_obj["delta"] is Object(second_payload) else {
    fail("expected second payload")
  }
  assert_eq(first_payload["text"], Json::string("Hel"))
  assert_eq(second_payload["text"], Json::string("lo"))
  let message_delta = @json.parse(finish_events[1].data)
  guard message_delta is Object(done_obj) else { fail("expected done") }
  guard done_obj["delta"] is Object(done_delta) else {
    fail("expected done delta")
  }
  assert_eq(done_delta["stop_reason"], Json::string("end_turn"))
  guard done_obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(10.0))
  assert_eq(usage["output_tokens"], Json::number(5.0))
}

///|
test "gemini native stream keeps parallel no id tool calls distinct" {
  let state = GeminiNativeAnthropicStreamState::new()
  let chunk = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_tools",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          { "functionCall": { "name": "lookup", "args": { "city": "Tokyo" } } },
      #|          { "functionCall": { "name": "lookup", "args": { "city": "Osaka" } } }
      #|        ]
      #|      }
      #|    }
      #|  ],
      #|  "usageMetadata": { "promptTokenCount": 5, "totalTokenCount": 8 }
      #|}
    ),
  )
  let _ = state.push_chunk(chunk)
  let events = state.finish()
  let starts = events.filter(event => event.event_type == "content_block_start")
  assert_eq(starts.length(), 2)
  let first = @json.parse(starts[0].data)
  let second = @json.parse(starts[1].data)
  guard first is Object(first_obj) else { fail("expected first") }
  guard second is Object(second_obj) else { fail("expected second") }
  guard first_obj["content_block"] is Object(first_block) else {
    fail("expected first block")
  }
  guard second_obj["content_block"] is Object(second_block) else {
    fail("expected second block")
  }
  assert_eq(first_block["type"], Json::string("tool_use"))
  assert_eq(second_block["type"], Json::string("tool_use"))
  assert_true(first_block["id"] != second_block["id"])
  guard first_block["id"] is String(first_id) else { fail("expected first id") }
  guard second_block["id"] is String(second_id) else {
    fail("expected second id")
  }
  assert_true(first_id.has_prefix("gemini_synth_"))
  assert_true(second_id.has_prefix("gemini_synth_"))
  assert_eq(first_block["name"], Json::string("lookup"))
  assert_eq(second_block["name"], Json::string("lookup"))
  let deltas = events.filter(event => event.event_type == "content_block_delta")
  assert_eq(deltas.length(), 2)
  let delta_a = @json.parse(deltas[0].data)
  let delta_b = @json.parse(deltas[1].data)
  guard delta_a is Object(delta_a_obj) else { fail("expected delta") }
  guard delta_b is Object(delta_b_obj) else { fail("expected delta") }
  guard delta_a_obj["delta"] is Object(delta_a_payload) else {
    fail("expected payload")
  }
  guard delta_b_obj["delta"] is Object(delta_b_payload) else {
    fail("expected payload")
  }
  assert_eq(
    delta_a_payload["partial_json"],
    Json::string("{\"city\":\"Tokyo\"}"),
  )
  assert_eq(
    delta_b_payload["partial_json"],
    Json::string("{\"city\":\"Osaka\"}"),
  )
  let message_delta = @json.parse(events[6].data)
  guard message_delta is Object(done_obj) else { fail("expected done") }
  guard done_obj["delta"] is Object(done_delta) else {
    fail("expected done delta")
  }
  assert_eq(done_delta["stop_reason"], Json::string("tool_use"))
}

///|
test "gemini native stream shadow turn stores accumulated text signature" {
  let state = GeminiNativeAnthropicStreamState::new()
  let first = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_text_shadow",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    { "content": { "parts": [ { "text": "Hel" } ] } }
      #|  ]
      #|}
    ),
  )
  let second = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_text_shadow",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          { "text": "Hello" },
      #|          { "text": "", "thoughtSignature": "sig-text" }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(first)
  let _ = state.push_chunk(second)
  let _ = state.finish()
  guard state.shadow_turn() is Some(turn) else { fail("expected shadow turn") }
  guard turn.assistant_content is Object(content) else {
    fail("expected content")
  }
  guard content["parts"] is Array(parts) else { fail("expected parts") }
  guard parts[0] is Object(text_part) else { fail("expected text part") }
  assert_eq(text_part["text"], Json::string("Hello"))
  assert_eq(text_part["thoughtSignature"], Json::string("sig-text"))
}

///|
test "gemini native stream shadow turn preserves tool signature" {
  let state = GeminiNativeAnthropicStreamState::new()
  let first = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_tool_shadow",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "content": {
      #|        "parts": [
      #|          {
      #|            "functionCall": {
      #|              "id": "call_1",
      #|              "name": "lookup",
      #|              "args": { "city": "Tokyo" }
      #|            },
      #|            "thoughtSignature": "sig-tool"
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let second = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_tool_shadow",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          {
      #|            "functionCall": {
      #|              "id": "call_1",
      #|              "name": "lookup",
      #|              "args": { "city": "Tokyo", "units": "c" }
      #|            }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(first)
  let _ = state.push_chunk(second)
  let _ = state.finish()
  guard state.shadow_turn() is Some(turn) else { fail("expected shadow turn") }
  guard turn.assistant_content is Object(content) else {
    fail("expected content")
  }
  guard content["parts"] is Array(parts) else { fail("expected parts") }
  guard parts[0] is Object(tool_part) else { fail("expected tool part") }
  guard tool_part["functionCall"] is Object(function_call) else {
    fail("expected function call")
  }
  assert_eq(function_call["id"], Json::string("call_1"))
  assert_eq(function_call["name"], Json::string("lookup"))
  guard function_call["args"] is Object(args) else { fail("expected args") }
  assert_eq(args["city"], Json::string("Tokyo"))
  assert_eq(args["units"], Json::string("c"))
  assert_eq(tool_part["thoughtSignature"], Json::string("sig-tool"))
  assert_eq(turn.tool_calls.length(), 1)
  assert_eq(turn.tool_calls[0].thought_signature, Some("sig-tool"))
}

///|
test "gemini native stream prompt feedback becomes refusal" {
  let state = GeminiNativeAnthropicStreamState::new()
  let events = state.push_chunk(
    @json.parse(
      (
        #|{
        #|  "responseId": "resp_block",
        #|  "modelVersion": "gemini-2.5-pro",
        #|  "promptFeedback": { "blockReason": "SAFETY" },
        #|  "usageMetadata": { "promptTokenCount": 5, "totalTokenCount": 5 }
        #|}
      ),
    ),
  )
  assert_eq(events[0].event_type, "message_start")
  let finish_events = state.finish()
  let text_delta = @json.parse(finish_events[1].data)
  guard text_delta is Object(text_obj) else { fail("expected text delta") }
  guard text_obj["delta"] is Object(text_payload) else {
    fail("expected text payload")
  }
  guard text_payload["text"] is String(text) else { fail("expected text") }
  assert_true(text.contains("SAFETY"))
  let message_delta = @json.parse(finish_events[3].data)
  guard message_delta is Object(done_obj) else { fail("expected done") }
  guard done_obj["delta"] is Object(done_delta) else {
    fail("expected done delta")
  }
  assert_eq(done_delta["stop_reason"], Json::string("refusal"))
}

///|
test "gemini native claude compatible provider uses gemini url and headers" {
  assert_eq(
    claude_compatible_provider_url(
      "https://generativelanguage.googleapis.com", "/v1beta/models/gemini-2.5-pro:generateContent",
      "gemini_native", false,
    ),
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent",
  )
  let headers = claude_compatible_provider_headers(
    "gemini-key", "gemini_native",
  )
  assert_eq(headers["x-goog-api-key"], "gemini-key")
  assert_eq(headers["x-goog-api-client"], "GeminiCLI/1.0")
  assert_true(headers.get("Authorization") is None)
}

///|
test "gemini native response converts to anthropic message with usage" {
  let body = @json.parse(
    (
      #|{
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          { "text": "done" },
      #|          {
      #|            "functionCall": {
      #|              "id": "gem_call_1",
      #|              "name": "lookup",
      #|              "args": { "q": "moon" }
      #|            }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ],
      #|  "usageMetadata": {
      #|    "promptTokenCount": 10,
      #|    "totalTokenCount": 17,
      #|    "cachedContentTokenCount": 4
      #|  }
      #|}
    ),
  )
  let response = gemini_native_response_to_anthropic(body, "claude-sonnet-4-6")
  assert_eq(response.model, "claude-sonnet-4-6")
  assert_eq(response.stop_reason, Some("tool_use"))
  assert_eq(response.content.length(), 2)
  assert_eq(response.content[0].type_, "text")
  assert_eq(response.content[0].text, Some("done"))
  assert_eq(response.content[1].type_, "tool_use")
  assert_eq(response.content[1].name, Some("lookup"))
  assert_eq(response.content[1].id, Some("gem_call_1"))
  assert_eq(
    response.content[1].input,
    Some(Json::object({ "q": Json::string("moon") })),
  )
  assert_eq(response.usage.input_tokens, 6)
  assert_eq(response.usage.output_tokens, 7)
  assert_eq(response.usage.cache_read_input_tokens, Some(4))
}

///|
test "gemini native response synthesizes ccs marked missing tool id" {
  let body = @json.parse(
    (
      #|{
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          {
      #|            "functionCall": {
      #|              "name": "lookup",
      #|              "args": { "q": "moon" }
      #|            }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ],
      #|  "usageMetadata": {
      #|    "promptTokenCount": 10,
      #|    "totalTokenCount": 17
      #|  }
      #|}
    ),
  )
  let response = gemini_native_response_to_anthropic(body, "claude-sonnet-4-6")
  assert_eq(response.stop_reason, Some("tool_use"))
  assert_eq(response.content.length(), 1)
  assert_eq(response.content[0].type_, "tool_use")
  guard response.content[0].id is Some(id) else {
    fail("expected synthesized id")
  }
  assert_true(id.has_prefix("gemini_synth_"))
}

///|
test "gemini native prompt block converts to anthropic refusal" {
  let response = gemini_native_response_to_anthropic(
    @json.parse(
      (
        #|{
        #|  "promptFeedback": { "blockReason": "SAFETY" },
        #|  "usageMetadata": { "promptTokenCount": 5, "totalTokenCount": 5 }
        #|}
      ),
    ),
    "claude-sonnet-4-6",
  )
  assert_eq(response.stop_reason, Some("refusal"))
  assert_eq(response.content.length(), 1)
  assert_eq(response.content[0].type_, "text")
}
