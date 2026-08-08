///|
pub let moon_fwd_provider_failed_retry : String = "FWD-001"

///|
pub let moon_fwd_all_providers_failed : String = "FWD-002"

///|
pub let moon_fwd_single_provider_failed : String = "FWD-003"

///|
pub enum MoonProxyError {
  AlreadyRunning
  NotRunning
  UpstreamError(status~ : Int, body~ : String?)
  Timeout(String)
  StreamIdleTimeout(Int)
  ForwardFailed(String)
  NoAvailableProvider
  AllProvidersCircuitOpenError
  NoProvidersConfiguredError
  MaxRetriesExceeded
  ProviderUnhealthy(String)
  ConfigError(String)
  InvalidRequest(String)
  AuthError(String)
  DatabaseError(String)
  TransformError(String)
  Unknown(String)
}

///|
/// Classifies provider failures without leaking domain or credential details.
/// The value is safe to expose as a local MoonGate diagnostic header.
fn moon_provider_error_class(status_code : Int, body : String) -> String {
  let normalized = body.to_lower()
  if normalized.contains("serveroverloaded") ||
    normalized.contains("server overloaded") {
    return "server_overloaded"
  }
  if normalized.contains("requestbursttoofast") ||
    normalized.contains("request burst too fast") {
    return "request_burst"
  }
  if normalized.contains("quotaexceeded") ||
    normalized.contains("quota exhausted") ||
    normalized.contains("insufficient_quota") ||
    normalized.contains("accountoverdue") ||
    normalized.contains("account overdue") {
    return "quota_exhausted"
  }
  if status_code == 429 {
    return "rate_limited"
  }
  if status_code == 408 ||
    status_code == 500 ||
    status_code == 502 ||
    status_code == 503 ||
    status_code == 504 {
    return "transient_http"
  }
  "permanent_http"
}

///|
/// Forwards only retry/rate-limit diagnostics. Hop-by-hop, authorization and
/// provider-specific secret headers are deliberately excluded.
fn moon_forward_upstream_failure_headers(
  upstream : Map[String, String],
  status_code : Int,
  body : String,
  w : @httpx.ResponseWriter,
) -> Unit {
  let class = moon_provider_error_class(status_code, body)
  w.header().set("X-MoonGate-Provider-Error-Class", class)
  let safe_names = [
    "retry-after", "ratelimit-limit", "ratelimit-remaining", "ratelimit-reset", "x-ratelimit-limit-requests",
    "x-ratelimit-remaining-requests", "x-ratelimit-reset-requests", "x-ratelimit-limit-tokens",
    "x-ratelimit-remaining-tokens", "x-ratelimit-reset-tokens", "x-request-id", "x-tt-logid",
  ]
  let mut has_retry_after = false
  for key, value in upstream {
    let normalized = key.to_lower()
    if safe_names.contains(normalized) {
      w.header().set(key, value)
      if normalized == "retry-after" {
        has_retry_after = true
      }
    }
  }
  if !has_retry_after && class != "quota_exhausted" {
    let fallback = match class {
      "server_overloaded" | "rate_limited" => Some("30")
      "request_burst" => Some("10")
      _ => None
    }
    match fallback {
      Some(seconds) => w.header().set("Retry-After", seconds)
      None => ()
    }
  }
}

///|
pub fn MoonProxyError::to_string(self : MoonProxyError) -> String {
  match self {
    AlreadyRunning => "proxy already running"
    NotRunning => "proxy not running"
    UpstreamError(status~, body~) =>
      match body {
        Some(body) => "upstream error \{status}: \{body}"
        None => "upstream error \{status}"
      }
    Timeout(message) => "timeout: \{message}"
    StreamIdleTimeout(seconds) => "stream idle timeout after \{seconds}s"
    ForwardFailed(message) => "forward failed: \{message}"
    NoAvailableProvider => "no available provider"
    AllProvidersCircuitOpenError => "all providers circuit open"
    NoProvidersConfiguredError => "no providers configured"
    MaxRetriesExceeded => "max retries exceeded"
    ProviderUnhealthy(message) => "provider unhealthy: \{message}"
    ConfigError(message) => "config error: \{message}"
    InvalidRequest(message) => "invalid request: \{message}"
    AuthError(message) => "auth error: \{message}"
    DatabaseError(message) => "database error: \{message}"
    TransformError(message) => "transform error: \{message}"
    Unknown(message) => message
  }
}

///|
pub fn moon_map_proxy_error_to_status(error : MoonProxyError) -> Int {
  match error {
    AlreadyRunning => @status.Conflict
    NotRunning => @status.ServiceUnavailable
    UpstreamError(status~, ..) => status
    Timeout(_) | StreamIdleTimeout(_) => @status.GatewayTimeout
    ForwardFailed(_) => @status.BadGateway
    NoAvailableProvider
    | AllProvidersCircuitOpenError
    | NoProvidersConfiguredError
    | MaxRetriesExceeded
    | ProviderUnhealthy(_) => @status.ServiceUnavailable
    ConfigError(_) | InvalidRequest(_) => @status.BadRequest
    AuthError(_) => @status.Unauthorized
    DatabaseError(_) => @status.InternalServerError
    TransformError(_) => @status.UnprocessableEntity
    Unknown(_) => @status.InternalServerError
  }
}

///|
pub fn moon_proxy_error_message(error : MoonProxyError) -> String {
  match error {
    UpstreamError(status~, body~) =>
      match body {
        Some(body) => "上游错误 (\{status}): \{body}"
        None => "上游错误 (\{status})"
      }
    Timeout(message) => "请求超时: \{message}"
    ForwardFailed(message) => "转发失败: \{message}"
    NoAvailableProvider => "无可用 Provider"
    AllProvidersCircuitOpenError => "所有供应商已熔断，无可用渠道"
    NoProvidersConfiguredError => "未配置供应商"
    MaxRetriesExceeded => "所有 Provider 都失败，重试耗尽"
    ProviderUnhealthy(message) => "Provider 不健康: \{message}"
    DatabaseError(message) => "数据库错误: \{message}"
    TransformError(message) => "请求/响应转换错误: \{message}"
    _ => error.to_string()
  }
}

///|
fn moon_proxy_error_diagnostic_variants() -> Array[MoonProxyError] {
  [
    AlreadyRunning,
    NotRunning,
    UpstreamError(status=502, body=Some("upstream")),
    Timeout("timeout"),
    StreamIdleTimeout(30),
    ForwardFailed("forward failed"),
    NoAvailableProvider,
    AllProvidersCircuitOpenError,
    NoProvidersConfiguredError,
    MaxRetriesExceeded,
    ProviderUnhealthy("provider"),
    ConfigError("config"),
    InvalidRequest("request"),
    AuthError("auth"),
    DatabaseError("database"),
    TransformError("transform"),
    Unknown("unknown"),
  ]
}

///|
fn moon_build_retryable_failure_log(
  provider_name : String,
  attempted_providers : Int,
  total_providers : Int,
  error : MoonProxyError,
) -> (String, String) {
  let error_summary = moon_summarize_proxy_error(error)
  if total_providers <= 1 {
    (
      moon_fwd_single_provider_failed,
      "Provider \{provider_name} 请求失败: \{error_summary}",
    )
  } else {
    (
      moon_fwd_provider_failed_retry,
      "Provider \{provider_name} 失败，继续尝试下一个 (\{attempted_providers}/\{total_providers}): \{error_summary}",
    )
  }
}

///|
fn moon_build_terminal_failure_log(
  attempted_providers : Int,
  total_providers : Int,
  last_error : MoonProxyError?,
) -> (String, String)? {
  if total_providers <= 1 {
    return None
  }
  let error_summary = match last_error {
    Some(error) => moon_summarize_proxy_error(error)
    None => "未知错误"
  }
  Some(
    (
      moon_fwd_all_providers_failed,
      "已尝试 \{attempted_providers}/\{total_providers} 个 Provider，均失败。最后错误: \{error_summary}",
    ),
  )
}

///|
fn init {
  ignore(moon_proxy_error_diagnostic_variants())
  ignore(
    moon_build_retryable_failure_log(
      "provider",
      1,
      2,
      ForwardFailed("forward failed"),
    ),
  )
  ignore(moon_build_terminal_failure_log(2, 2, Some(Timeout("timeout"))))
}

///|
fn moon_summarize_proxy_error(error : MoonProxyError) -> String {
  match error {
    UpstreamError(status~, body~) =>
      match body {
        Some(body) => {
          let summary = moon_summarize_upstream_body(body)
          if summary.is_empty() {
            "上游 HTTP \{status}"
          } else {
            "上游 HTTP \{status}: \{summary}"
          }
        }
        None => "上游 HTTP \{status}"
      }
    Timeout(message) =>
      "请求超时: \{moon_summarize_text_for_log(message, 180)}"
    ForwardFailed(message) =>
      "请求转发失败: \{moon_summarize_text_for_log(message, 180)}"
    TransformError(message) =>
      "响应转换失败: \{moon_summarize_text_for_log(message, 180)}"
    ConfigError(message) =>
      "配置错误: \{moon_summarize_text_for_log(message, 180)}"
    AuthError(message) =>
      "认证失败: \{moon_summarize_text_for_log(message, 180)}"
    _ => moon_summarize_text_for_log(error.to_string(), 180)
  }
}

///|
fn moon_summarize_upstream_body(body : String) -> String {
  let json_body = @json.parse(body) catch {
    _ => return moon_summarize_text_for_log(body, 180)
  }
  match moon_json_error_message(json_body) {
    Some(message) => moon_summarize_text_for_log(message, 180)
    None => moon_summarize_text_for_log(json_body.stringify(), 180)
  }
}

///|
fn moon_json_error_message(body : Json) -> String? {
  match body {
    Object(obj) => {
      match obj.get("error") {
        Some(Object(error_obj)) =>
          match json_string_from_map(error_obj, "message") {
            Some(message) => return Some(message)
            None => ()
          }
        Some(String(message)) => return Some(message)
        _ => ()
      }
      match json_string_from_map(obj, "message") {
        Some(message) => return Some(message)
        None => ()
      }
      match json_string_from_map(obj, "detail") {
        Some(message) => return Some(message)
        None => ()
      }
      None
    }
    _ => None
  }
}

///|
fn moon_summarize_text_for_log(text : String, max_chars : Int) -> String {
  let normalized = moon_collapse_ascii_whitespace(text).trim()
  if normalized.length() <= max_chars {
    normalized.to_owned()
  } else {
    normalized[:max_chars].trim().to_owned() + "..."
  }
}

///|
fn moon_collapse_ascii_whitespace(text : String) -> String {
  let buffer = StringBuilder::new()
  let mut in_whitespace = false
  let mut has_output = false
  for ch in text {
    if moon_is_ascii_whitespace(ch) {
      in_whitespace = true
    } else {
      if in_whitespace && has_output {
        buffer.write_char(' ')
      }
      buffer.write_char(ch)
      has_output = true
      in_whitespace = false
    }
  }
  buffer.to_string()
}

///|
fn moon_is_ascii_whitespace(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'
}
