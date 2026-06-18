///|
test "ccs proxy error status mapping matches ccs" {
  assert_eq(
    moon_map_proxy_error_to_status(
      MoonProxyError::UpstreamError(status=401, body=Some("Unauthorized")),
    ),
    401,
  )
  assert_eq(moon_map_proxy_error_to_status(MoonProxyError::Timeout("x")), 504)
  assert_eq(
    moon_map_proxy_error_to_status(MoonProxyError::StreamIdleTimeout(30)),
    504,
  )
  assert_eq(
    moon_map_proxy_error_to_status(MoonProxyError::ForwardFailed("x")),
    502,
  )
  assert_eq(
    moon_map_proxy_error_to_status(MoonProxyError::NoAvailableProvider),
    503,
  )
  assert_eq(
    moon_map_proxy_error_to_status(MoonProxyError::AllProvidersCircuitOpenError),
    503,
  )
  assert_eq(
    moon_map_proxy_error_to_status(MoonProxyError::NoProvidersConfiguredError),
    503,
  )
  assert_eq(
    moon_map_proxy_error_to_status(MoonProxyError::MaxRetriesExceeded),
    503,
  )
  assert_eq(
    moon_map_proxy_error_to_status(MoonProxyError::ProviderUnhealthy("bad")),
    503,
  )
  assert_eq(
    moon_map_proxy_error_to_status(MoonProxyError::AuthError("bad token")),
    401,
  )
  assert_eq(
    moon_map_proxy_error_to_status(MoonProxyError::ConfigError("bad config")),
    400,
  )
  assert_eq(
    moon_map_proxy_error_to_status(
      MoonProxyError::InvalidRequest("bad request"),
    ),
    400,
  )
  assert_eq(
    moon_map_proxy_error_to_status(MoonProxyError::TransformError("bad")),
    422,
  )
  assert_eq(moon_map_proxy_error_to_status(MoonProxyError::AlreadyRunning), 409)
  assert_eq(moon_map_proxy_error_to_status(MoonProxyError::NotRunning), 503)
}

///|
test "ccs proxy error message matches ccs friendly text" {
  let message = moon_proxy_error_message(
    MoonProxyError::UpstreamError(
      status=500,
      body=Some("Internal Server Error"),
    ),
  )
  assert_true(message.contains("上游错误"))
  assert_true(message.contains("500"))
  assert_true(message.contains("Internal Server Error"))
  assert_eq(
    moon_proxy_error_message(MoonProxyError::NoProvidersConfiguredError),
    "未配置供应商",
  )
}

///|
test "ccs single provider retryable log uses single provider code" {
  let (code, message) = moon_build_retryable_failure_log(
    "PackyCode-response",
    1,
    1,
    MoonProxyError::UpstreamError(
      status=429,
      body=Some("{\"error\":{\"message\":\"rate limit exceeded\"}}"),
    ),
  )
  assert_eq(code, moon_fwd_single_provider_failed)
  assert_true(message.contains("Provider PackyCode-response 请求失败"))
  assert_true(message.contains("上游 HTTP 429"))
  assert_true(message.contains("rate limit exceeded"))
  assert_false(message.contains("继续尝试下一个"))
}

///|
test "ccs multi provider retryable log keeps failover wording" {
  let (code, message) = moon_build_retryable_failure_log(
    "primary",
    1,
    3,
    MoonProxyError::Timeout("upstream timed out after 30s"),
  )
  assert_eq(code, moon_fwd_provider_failed_retry)
  assert_true(message.contains("继续尝试下一个 (1/3)"))
  assert_true(message.contains("请求超时"))
}

///|
test "ccs single provider has no terminal all failed log" {
  assert_true(moon_build_terminal_failure_log(1, 1, None) is None)
}

///|
test "ccs multi provider terminal log contains last error summary" {
  guard moon_build_terminal_failure_log(
      2,
      2,
      Some(MoonProxyError::ForwardFailed("connection reset by peer")),
    )
    is Some((code, message)) else {
    fail("expected terminal log")
  }
  assert_eq(code, moon_fwd_all_providers_failed)
  assert_true(message.contains("已尝试 2/2 个 Provider，均失败"))
  assert_true(message.contains("connection reset by peer"))
}

///|
test "ccs summarize upstream body prefers json message" {
  let summary = moon_summarize_upstream_body(
    "{\"error\":{\"message\":\"invalid_request_error: unsupported field\"},\"request_id\":\"req_123\"}",
  )
  assert_eq(summary, "invalid_request_error: unsupported field")
}

///|
test "ccs summarize text for log collapses whitespace and truncates" {
  assert_eq(
    moon_summarize_text_for_log("line1\n\n line2   line3", 12),
    "line1 line2...",
  )
}
