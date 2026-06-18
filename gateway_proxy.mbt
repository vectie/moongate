///|
fn moon_upstream_status_retryable(status_code : Int) -> Bool {
  match status_code {
    400 | 405 | 406 | 413 | 414 | 415 | 422 | 501 => false
    _ => true
  }
}

///|
fn provider_selection_is_all_circuits_open(
  selection : ProviderSelection,
) -> Bool {
  selection.error == Some(AllProvidersCircuitOpen)
}

///|
fn Gateway::all_provider_circuits_open(
  self : Gateway,
  app_type : String,
) -> Bool {
  provider_selection_is_all_circuits_open(
    self.proxy.provider_router.select_providers(app_type),
  )
}

///|
fn moon_reject_proxy_managed_placeholder_for_upstream(
  url : String,
  headers : Map[String, String],
) -> Result[Unit, String] {
  if !moon_is_managed_account_upstream_url(url) ||
    !moon_headers_contain_proxy_managed_placeholder(headers) {
    return Ok(())
  }
  Err(
    "Managed account proxy auth was not resolved; PROXY_MANAGED must not be sent upstream",
  )
}

///|
fn moon_headers_contain_proxy_managed_placeholder(
  headers : Map[String, String],
) -> Bool {
  for _, value in headers {
    if value.contains(CCS_PROXY_MANAGED_PLACEHOLDER) {
      return true
    }
  }
  false
}

///|
fn gemini_proxy_url(endpoint : String) -> String? {
  let url = resolve_gemini_native_url(
    gemini_base_url(),
    endpoint,
    gemini_base_is_full_url(),
  )
  if url_contains_query_key(url) {
    Some(url)
  } else {
    match gemini_api_key() {
      Some(key) =>
        if url.contains("?") {
          Some("\{url}&key=\{key}")
        } else {
          Some("\{url}?key=\{key}")
        }
      None => None
    }
  }
}

///|
fn Gateway::provider_cost_multiplier(
  self : Gateway,
  provider : ProviderRouteTarget,
) -> String {
  provider_cost_multiplier_from_default(
    provider,
    self.proxy_default_cost_multiplier_for_app(provider.app_type),
  )
}

///|
fn provider_cost_multiplier_from_default(
  provider : ProviderRouteTarget,
  default_multiplier : String,
) -> String {
  guard provider.settings_config is Some(settings) else {
    return default_multiplier
  }
  match settings {
    Object(obj) => {
      match
        json_string_from_map_any(obj, ["costMultiplier", "cost_multiplier"]) {
        Some(value) if usage_non_negative_decimal(value) =>
          return value.trim().to_owned()
        _ => ()
      }
      match obj.get("meta") {
        Some(Object(meta)) =>
          match
            json_string_from_map_any(meta, ["costMultiplier", "cost_multiplier"]) {
            Some(value) if usage_non_negative_decimal(value) =>
              value.trim().to_owned()
            _ => default_multiplier
          }
        _ => default_multiplier
      }
    }
    _ => default_multiplier
  }
}

///|
fn default_cost_multiplier_for_app(app_type : String) -> String {
  let global_keys = [
    "MOONSTAT_DEFAULT_COST_MULTIPLIER", "MOONSTAT_COST_MULTIPLIER",
  ]
  let app_keys = match app_type {
    "claude" | "claude-desktop" =>
      [
        "MOONSTAT_CLAUDE_DEFAULT_COST_MULTIPLIER", "MOONSTAT_CLAUDE_COST_MULTIPLIER",
        "ANTHROPIC_DEFAULT_COST_MULTIPLIER", "ANTHROPIC_COST_MULTIPLIER",
      ]
    "codex" =>
      [
        "MOONSTAT_CODEX_DEFAULT_COST_MULTIPLIER", "MOONSTAT_CODEX_COST_MULTIPLIER",
        "CODEX_DEFAULT_COST_MULTIPLIER", "CODEX_COST_MULTIPLIER",
      ]
    "gemini" =>
      [
        "MOONSTAT_GEMINI_DEFAULT_COST_MULTIPLIER", "MOONSTAT_GEMINI_COST_MULTIPLIER",
        "GEMINI_DEFAULT_COST_MULTIPLIER", "GEMINI_COST_MULTIPLIER",
      ]
    "opencode" =>
      [
        "MOONSTAT_OPENCODE_DEFAULT_COST_MULTIPLIER", "MOONSTAT_OPENCODE_COST_MULTIPLIER",
        "OPENCODE_DEFAULT_COST_MULTIPLIER", "OPENCODE_COST_MULTIPLIER",
      ]
    _ => []
  }
  match env_first_non_negative_decimal(app_keys) {
    Some(value) => value
    None =>
      match env_first_non_negative_decimal(global_keys) {
        Some(value) => value
        None => "1.0"
      }
  }
}

///|
fn Gateway::provider_pricing_model_source(
  self : Gateway,
  provider : ProviderRouteTarget,
) -> String {
  provider_pricing_model_source_from_default(
    provider,
    self.proxy_pricing_model_source_for_app(provider.app_type),
  )
}

///|
fn provider_pricing_model_source_from_default(
  provider : ProviderRouteTarget,
  default_source : String,
) -> String {
  guard provider.settings_config is Some(settings) else {
    return default_source
  }
  match settings {
    Object(obj) => {
      match
        json_string_from_map_any(obj, [
          "pricingModelSource", "pricing_model_source",
        ]) {
        Some(value) if pricing_model_source_is_valid(value) =>
          return value.trim().to_owned()
        _ => ()
      }
      match obj.get("meta") {
        Some(Object(meta)) =>
          match
            json_string_from_map_any(meta, [
              "pricingModelSource", "pricing_model_source",
            ]) {
            Some(value) if pricing_model_source_is_valid(value) =>
              value.trim().to_owned()
            _ => default_source
          }
        _ => default_source
      }
    }
    _ => default_source
  }
}

///|
fn default_pricing_model_source_for_app(app_type : String) -> String {
  let global_keys = [
    "MOONSTAT_PRICING_MODEL_SOURCE", "MOONSTAT_DEFAULT_PRICING_MODEL_SOURCE",
  ]
  let app_keys = match app_type {
    "claude" | "claude-desktop" =>
      [
        "MOONSTAT_CLAUDE_PRICING_MODEL_SOURCE", "MOONSTAT_CLAUDE_DEFAULT_PRICING_MODEL_SOURCE",
        "ANTHROPIC_PRICING_MODEL_SOURCE", "ANTHROPIC_DEFAULT_PRICING_MODEL_SOURCE",
      ]
    "codex" =>
      [
        "MOONSTAT_CODEX_PRICING_MODEL_SOURCE", "MOONSTAT_CODEX_DEFAULT_PRICING_MODEL_SOURCE",
        "CODEX_PRICING_MODEL_SOURCE", "CODEX_DEFAULT_PRICING_MODEL_SOURCE",
      ]
    "gemini" =>
      [
        "MOONSTAT_GEMINI_PRICING_MODEL_SOURCE", "MOONSTAT_GEMINI_DEFAULT_PRICING_MODEL_SOURCE",
        "GEMINI_PRICING_MODEL_SOURCE", "GEMINI_DEFAULT_PRICING_MODEL_SOURCE",
      ]
    "opencode" =>
      [
        "MOONSTAT_OPENCODE_PRICING_MODEL_SOURCE", "MOONSTAT_OPENCODE_DEFAULT_PRICING_MODEL_SOURCE",
        "OPENCODE_PRICING_MODEL_SOURCE", "OPENCODE_DEFAULT_PRICING_MODEL_SOURCE",
      ]
    _ => []
  }
  match env_first_pricing_model_source(app_keys) {
    Some(value) => value
    None =>
      match env_first_pricing_model_source(global_keys) {
        Some(value) => value
        None => "response"
      }
  }
}

///|
fn env_first_pricing_model_source(keys : Array[String]) -> String? {
  for key in keys {
    match getenv_or_none(key) {
      Some(value) if pricing_model_source_is_valid(value) =>
        return Some(value.trim().to_owned())
      _ => continue
    }
  }
  None
}

///|
fn pricing_model_source_is_valid(value : String) -> Bool {
  let trimmed = value.trim()
  trimmed == "response" || trimmed == "request"
}

///|
fn ProxyService::server_info_json(
  self : ProxyService,
  started_at_ms : Int,
) -> Json {
  {
    "address": Json::string(self.proxy_listen_address),
    "port": Json::number(self.proxy_listen_port.to_double()),
    "started_at": Json::string(started_at_ms.to_string()),
  }.to_json()
}

///|
fn ProxyService::config_json(
  self : ProxyService,
  live_takeover_active? : Bool = false,
) -> Json {
  let app_type = "claude"
  let streaming_first_byte_timeout = self.proxy_streaming_first_byte_timeout
    .get(app_type)
    .unwrap_or(moon_proxy_streaming_first_byte_timeout_default(app_type))
  let streaming_idle_timeout = self.proxy_streaming_idle_timeout
    .get(app_type)
    .unwrap_or(moon_proxy_streaming_idle_timeout_default(app_type))
  let non_streaming_timeout = self.proxy_non_streaming_timeout
    .get(app_type)
    .unwrap_or(moon_proxy_non_streaming_timeout_default(app_type))
  {
    "listen_address": Json::string(self.proxy_listen_address),
    "listen_port": Json::number(self.proxy_listen_port.to_double()),
    "max_retries": Json::number(
      self.provider_router.max_retries_for_app(app_type).to_double(),
    ),
    "request_timeout": Json::number(600.0),
    "enable_logging": Json::boolean(self.proxy_enable_logging),
    "live_takeover_active": Json::boolean(live_takeover_active),
    "streaming_first_byte_timeout": Json::number(
      streaming_first_byte_timeout.to_double(),
    ),
    "streaming_idle_timeout": Json::number(streaming_idle_timeout.to_double()),
    "non_streaming_timeout": Json::number(non_streaming_timeout.to_double()),
  }.to_json()
}

///|
fn ProxyService::global_config_json(self : ProxyService) -> Json {
  {
    "proxyEnabled": Json::boolean(self.proxy_enabled),
    "listenAddress": Json::string(self.proxy_listen_address),
    "listenPort": Json::number(self.proxy_listen_port.to_double()),
    "enableLogging": Json::boolean(self.proxy_enable_logging),
  }.to_json()
}

///|
async fn ProxyService::handle_proxy_config(
  self : ProxyService,
  w : @httpx.ResponseWriter,
  live_takeover_active? : Bool = false,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(self.config_json(live_takeover_active~).stringify(indent=2))
  w.flush()
}

///|
async fn ProxyService::handle_proxy_update_config(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.apply_global_config_request(r, legacy=true) {
    true => write_usage_json(w, moon_unit_success_json())
    false => write_usage_bad_request(w, "invalid_proxy_config")
  }
}

///|
async fn ProxyService::handle_proxy_global_config(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.global_config_json())
}

///|
async fn ProxyService::handle_proxy_update_global_config(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.apply_global_config_request(r) {
    true => write_usage_json(w, moon_unit_success_json())
    false => write_usage_bad_request(w, "invalid_global_proxy_config")
  }
}

///|
async fn ProxyService::handle_get_global_proxy_url(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.upstream_proxy_url {
    Some(url) => write_usage_json(w, Json::string(url))
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn ProxyService::handle_set_global_proxy_url(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  let url = proxy_string_request(r.path, config, ["url"]).unwrap_or("")
  let trimmed = url.trim().to_owned()
  if trimmed.is_empty() {
    self.upstream_proxy_url = None
    write_usage_json(w, Json::null())
    return
  }
  if !upstream_proxy_url_is_valid(trimmed) {
    write_usage_bad_request(w, "invalid_proxy_url")
    return
  }
  self.upstream_proxy_url = Some(trimmed)
  write_usage_json(w, Json::null())
}

///|
async fn ProxyService::handle_test_proxy_url(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  let url = proxy_string_request(r.path, config, ["url"]).unwrap_or("")
  write_usage_json(w, proxy_test_result_json(url))
}

///|
async fn ProxyService::handle_get_upstream_proxy_status(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    {
      "enabled": Json::boolean(self.upstream_proxy_url is Some(_)),
      "proxyUrl": match self.upstream_proxy_url {
        Some(url) => Json::string(url)
        None => Json::null()
      },
    }.to_json(),
  )
}

///|
async fn ProxyService::apply_global_config_request(
  self : ProxyService,
  r : @httpx.RequestReader,
  legacy? : Bool = false,
) -> Bool {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  let proxy_enabled = proxy_bool_request(r.path, config, [
    "proxy_enabled", "proxyEnabled", "enabled",
  ])
  let listen_address = proxy_string_request(r.path, config, [
    "listen_address", "listenAddress",
  ])
  let listen_port = proxy_int_request(r.path, config, [
    "listen_port", "listenPort",
  ])
  let enable_logging = proxy_bool_request(r.path, config, [
    "enable_logging", "enableLogging",
  ])
  if proxy_enabled is Some(enabled) {
    self.proxy_enabled = enabled
  } else if legacy {
    match proxy_bool_request(r.path, config, ["proxyEnabled"]) {
      Some(enabled) => self.proxy_enabled = enabled
      None => ()
    }
  }
  if listen_address is Some(address) {
    if address.trim().is_empty() {
      return false
    }
    self.proxy_listen_address = address.trim().to_owned()
  }
  if listen_port is Some(port) {
    if port <= 0 || port > 65535 {
      return false
    }
    self.proxy_listen_port = port
  }
  if enable_logging is Some(enabled) {
    self.proxy_enable_logging = enabled
  }
  true
}

///|
async fn Gateway::handle_proxy_status(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(self.proxy_status_json().stringify(indent=2))
  w.flush()
}

///|
fn Gateway::proxy_status_json(self : Gateway) -> Json {
  self.usage.status_json(
    self.host,
    self.port,
    self.uptime_seconds(),
    running=self.proxy.proxy_enabled,
  )
}

///|
async fn Gateway::handle_proxy_start_server(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.proxy.proxy_enabled = true
  write_usage_json(w, self.proxy_server_info_json())
}

///|
fn Gateway::proxy_server_info_json(self : Gateway) -> Json {
  self.proxy.server_info_json(self.started_at_ms)
}

///|
async fn Gateway::handle_proxy_stop_server(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  if self.proxy_takeover_active() {
    write_usage_bad_request(w, moon_stop_proxy_takeover_error())
    return
  }
  self.proxy.proxy_enabled = false
  write_usage_json(w, moon_unit_success_json())
}

///|
fn moon_stop_proxy_takeover_error() -> String {
  "仍有应用处于代理接管状态，请先在设置中关闭对应应用接管后再停止本地路由。"
}

///|
async fn Gateway::handle_proxy_stop_with_restore(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.proxy.proxy_enabled = false
  self.proxy_clear_takeover()
  self.proxy_clear_enabled_apps_for_manual_stop()
  write_usage_json(w, moon_unit_success_json())
}

///|
fn Gateway::proxy_config_json(self : Gateway) -> Json {
  self.proxy.config_json(live_takeover_active=self.proxy_takeover_active())
}

///|
fn moon_proxy_streaming_first_byte_timeout_default(app_type : String) -> Int {
  match app_type {
    "claude" => 90
    _ => 60
  }
}

///|
fn moon_proxy_streaming_idle_timeout_default(app_type : String) -> Int {
  match app_type {
    "claude" => 180
    _ => 120
  }
}

///|
fn moon_proxy_non_streaming_timeout_default(_app_type : String) -> Int {
  600
}

///|
fn Gateway::proxy_global_config_json(self : Gateway) -> Json {
  self.proxy.global_config_json()
}

///|
fn upstream_proxy_url_is_valid(url : String) -> Bool {
  url.has_prefix("http://") ||
  url.has_prefix("https://") ||
  url.has_prefix("socks5://") ||
  url.has_prefix("socks5h://")
}

///|
fn moon_local_proxy_ports() -> Array[(Int, String, Bool)] {
  [
    (7890, "http", true),
    (7891, "socks5", false),
    (1080, "socks5", false),
    (8080, "http", false),
    (8888, "http", false),
    (3128, "http", false),
    (10808, "socks5", false),
    (10809, "http", false),
  ]
}

///|
fn moon_detected_proxy_json(port : Int, proxy_type : String) -> Json {
  {
    "url": Json::string("\{proxy_type}://127.0.0.1:\{port}"),
    "proxyType": Json::string(proxy_type),
    "port": Json::number(port.to_double()),
  }.to_json()
}

///|
fn moon_detected_proxy_entries_json(
  port : Int,
  primary_type : String,
  is_mixed : Bool,
) -> Array[Json] {
  let entries = [moon_detected_proxy_json(port, primary_type)]
  if is_mixed {
    let alt_type = if primary_type == "http" { "socks5" } else { "http" }
    entries.push(moon_detected_proxy_json(port, alt_type))
  }
  entries
}

///|
fn proxy_test_result_json(url : String) -> Json {
  let trimmed = url.trim().to_owned()
  if trimmed.is_empty() {
    return {
      "success": Json::boolean(false),
      "latencyMs": Json::number(0.0),
      "error": Json::string("Proxy URL is empty"),
    }.to_json()
  }
  if !upstream_proxy_url_is_valid(trimmed) {
    return {
      "success": Json::boolean(false),
      "latencyMs": Json::number(0.0),
      "error": Json::string("Invalid proxy URL"),
    }.to_json()
  }
  {
    "success": Json::boolean(true),
    "latencyMs": Json::number(0.0),
    "error": Json::null(),
  }.to_json()
}

///|
async fn Gateway::handle_proxy_app_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_app_type_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(w, self.proxy_app_config_json(app_type))
}

///|
fn Gateway::proxy_app_config_json(self : Gateway, app_type : String) -> Json {
  let circuit = self.proxy.provider_router.circuit_config_for_app(app_type)
  let enabled = self.proxy_app_enabled_for_app(app_type)
  let auto_failover_enabled = self.proxy.provider_router.auto_failover_enabled_for_app(
    app_type,
  )
  let max_retries = self.proxy.provider_router.max_retries_for_app(app_type)
  let streaming_first_byte_timeout = self.proxy.proxy_streaming_first_byte_timeout
    .get(app_type)
    .unwrap_or(moon_proxy_streaming_first_byte_timeout_default(app_type))
  let streaming_idle_timeout = self.proxy.proxy_streaming_idle_timeout
    .get(app_type)
    .unwrap_or(moon_proxy_streaming_idle_timeout_default(app_type))
  let non_streaming_timeout = self.proxy.proxy_non_streaming_timeout
    .get(app_type)
    .unwrap_or(moon_proxy_non_streaming_timeout_default(app_type))
  {
    "appType": Json::string(app_type),
    "app_type": Json::string(app_type),
    "enabled": Json::boolean(enabled),
    "autoFailoverEnabled": Json::boolean(auto_failover_enabled),
    "auto_failover_enabled": Json::boolean(auto_failover_enabled),
    "maxRetries": Json::number(max_retries.to_double()),
    "max_retries": Json::number(max_retries.to_double()),
    "streamingFirstByteTimeout": Json::number(
      streaming_first_byte_timeout.to_double(),
    ),
    "streaming_first_byte_timeout": Json::number(
      streaming_first_byte_timeout.to_double(),
    ),
    "streamingIdleTimeout": Json::number(streaming_idle_timeout.to_double()),
    "streaming_idle_timeout": Json::number(streaming_idle_timeout.to_double()),
    "nonStreamingTimeout": Json::number(non_streaming_timeout.to_double()),
    "non_streaming_timeout": Json::number(non_streaming_timeout.to_double()),
    "circuitFailureThreshold": Json::number(
      circuit.failure_threshold.to_double(),
    ),
    "circuit_failure_threshold": Json::number(
      circuit.failure_threshold.to_double(),
    ),
    "circuitSuccessThreshold": Json::number(
      circuit.success_threshold.to_double(),
    ),
    "circuit_success_threshold": Json::number(
      circuit.success_threshold.to_double(),
    ),
    "circuitTimeoutSeconds": Json::number(circuit.timeout_seconds.to_double()),
    "circuit_timeout_seconds": Json::number(circuit.timeout_seconds.to_double()),
    "circuitErrorRateThreshold": Json::number(circuit.error_rate_threshold),
    "circuit_error_rate_threshold": Json::number(circuit.error_rate_threshold),
    "circuitMinRequests": Json::number(circuit.min_requests.to_double()),
    "circuit_min_requests": Json::number(circuit.min_requests.to_double()),
  }.to_json()
}

///|
async fn Gateway::handle_proxy_update_app_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.apply_proxy_app_config_request(r) {
    Some(_) => write_usage_json(w, moon_unit_success_json())
    None => write_usage_bad_request(w, "invalid_app_proxy_config")
  }
}

///|
async fn Gateway::handle_proxy_default_cost_multiplier(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_app_type_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(
    w,
    Json::string(self.proxy_default_cost_multiplier_for_app(app_type)),
  )
}

///|
async fn Gateway::handle_proxy_set_default_cost_multiplier(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_app_type_from_request(r.path, config) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_string_request(r.path, config, ["value"]) is Some(value) else {
    write_usage_bad_request(w, "missing_value")
    return
  }
  if !usage_non_negative_decimal(value) {
    write_usage_bad_request(w, "invalid_default_cost_multiplier")
    return
  }
  let trimmed = value.trim().to_owned()
  self.proxy.proxy_default_cost_multipliers.set(app_type, trimmed)
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn Gateway::handle_proxy_set_default_cost_multiplier_unit(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_app_type_from_request(r.path, config) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_string_request(r.path, config, ["value"]) is Some(value) else {
    write_usage_bad_request(w, "missing_value")
    return
  }
  if !usage_non_negative_decimal(value) {
    write_usage_bad_request(w, "invalid_default_cost_multiplier")
    return
  }
  self.proxy.proxy_default_cost_multipliers.set(
    app_type,
    value.trim().to_owned(),
  )
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_proxy_pricing_model_source(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_app_type_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(
    w,
    Json::string(self.proxy_pricing_model_source_for_app(app_type)),
  )
}

///|
async fn Gateway::handle_proxy_set_pricing_model_source(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_app_type_from_request(r.path, config) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_string_request(r.path, config, ["value"]) is Some(value) else {
    write_usage_bad_request(w, "missing_value")
    return
  }
  if !pricing_model_source_is_valid(value) {
    write_usage_bad_request(w, "invalid_pricing_model_source")
    return
  }
  let trimmed = value.trim().to_owned()
  self.proxy.proxy_pricing_model_sources.set(app_type, trimmed)
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn Gateway::handle_proxy_set_pricing_model_source_unit(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_app_type_from_request(r.path, config) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_string_request(r.path, config, ["value"]) is Some(value) else {
    write_usage_bad_request(w, "missing_value")
    return
  }
  if !pricing_model_source_is_valid(value) {
    write_usage_bad_request(w, "invalid_pricing_model_source")
    return
  }
  self.proxy.proxy_pricing_model_sources.set(app_type, value.trim().to_owned())
  write_usage_json(w, Json::null())
}

///|
fn Gateway::proxy_default_cost_multiplier_for_app(
  self : Gateway,
  app_type : String,
) -> String {
  let default_app_type = proxy_pricing_default_app_type(app_type)
  self.proxy.proxy_default_cost_multipliers
  .get(default_app_type)
  .unwrap_or(default_cost_multiplier_for_app(app_type))
}

///|
fn Gateway::proxy_pricing_model_source_for_app(
  self : Gateway,
  app_type : String,
) -> String {
  let default_app_type = proxy_pricing_default_app_type(app_type)
  self.proxy.proxy_pricing_model_sources
  .get(default_app_type)
  .unwrap_or(default_pricing_model_source_for_app(app_type))
}

///|
fn proxy_pricing_default_app_type(app_type : String) -> String {
  if app_type == "claude-desktop" {
    "claude"
  } else {
    app_type
  }
}

///|
async fn Gateway::apply_proxy_app_config_request(
  self : Gateway,
  r : @httpx.RequestReader,
) -> String? {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  let app_type = match proxy_app_type_from_request(r.path, config) {
    Some(app_type) if !app_type.trim().is_empty() => app_type.trim().to_owned()
    _ => return None
  }
  match proxy_bool_request(r.path, config, ["enabled"]) {
    Some(enabled) => self.proxy.proxy_app_enabled.set(app_type, enabled)
    None => ()
  }
  match
    proxy_bool_request(r.path, config, [
      "auto_failover_enabled", "autoFailoverEnabled",
    ]) {
    Some(enabled) =>
      if !self.proxy.provider_router.set_auto_failover_ccs(app_type, enabled) {
        return None
      }
    None => ()
  }
  match proxy_int_request(r.path, config, ["max_retries", "maxRetries"]) {
    Some(max_retries) if max_retries >= 0 =>
      self.proxy.provider_router.set_max_retries(app_type, max_retries)
    Some(_) => return None
    None => ()
  }
  if !self.apply_proxy_app_timeout_config(app_type, r.path, config) {
    return None
  }
  match
    proxy_circuit_config_from_request(
      r.path,
      config,
      self.proxy.provider_router.circuit_config_for_app(app_type),
    ) {
    Some(config) =>
      self.proxy.provider_router.update_app_configs(app_type, config)
    None => ()
  }
  Some(app_type)
}

///|
fn Gateway::apply_proxy_app_timeout_config(
  self : Gateway,
  app_type : String,
  path : StringView,
  config : Json?,
) -> Bool {
  match
    proxy_int_request(path, config, [
      "streaming_first_byte_timeout", "streamingFirstByteTimeout",
    ]) {
    Some(timeout) if timeout > 0 =>
      self.proxy.proxy_streaming_first_byte_timeout.set(app_type, timeout)
    Some(_) => return false
    None => ()
  }
  match
    proxy_int_request(path, config, [
      "streaming_idle_timeout", "streamingIdleTimeout",
    ]) {
    Some(timeout) if timeout > 0 =>
      self.proxy.proxy_streaming_idle_timeout.set(app_type, timeout)
    Some(_) => return false
    None => ()
  }
  match
    proxy_int_request(path, config, [
      "non_streaming_timeout", "nonStreamingTimeout",
    ]) {
    Some(timeout) if timeout > 0 =>
      self.proxy.proxy_non_streaming_timeout.set(app_type, timeout)
    Some(_) => return false
    None => ()
  }
  true
}

///|
fn Gateway::proxy_app_enabled_for_app(
  self : Gateway,
  app_type : String,
) -> Bool {
  self.proxy.proxy_app_enabled
  .get(app_type)
  .unwrap_or(self.proxy.provider_router.has_configured_app(app_type))
}

///|
fn Gateway::can_set_auto_failover_ccs(
  self : Gateway,
  app_type : String,
  enabled : Bool,
) -> Bool {
  !enabled || self.proxy_app_enabled_for_app(app_type)
}

///|
async fn Gateway::handle_proxy_provider_health(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_provider_query_from_request(r.path, body) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  write_usage_json(
    w,
    self.proxy.provider_router.provider_health_json(
      query.provider_id,
      query.app_type,
      @async.now().to_string(),
    ),
  )
}

///|
async fn Gateway::handle_proxy_circuit_breaker_config(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.proxy.provider_router.circuit_config.to_json())
}

///|
async fn Gateway::handle_proxy_update_circuit_breaker_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = r.body.read_all().text()
  let config = if body.trim().is_empty() {
    proxy_circuit_config_from_query(r.path)
  } else {
    let parsed = @json.parse(body) catch {
      _ => {
        write_usage_bad_request(w, "invalid_circuit_breaker_config")
        return
      }
    }
    match circuit_breaker_config_from_json(parsed) {
      Some(config) => Some(config)
      None => proxy_circuit_config_from_query(r.path)
    }
  }
  guard config is Some(config) else {
    write_usage_bad_request(w, "invalid_circuit_breaker_config")
    return
  }
  self.proxy.provider_router.update_all_configs(config)
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn Gateway::handle_proxy_circuit_breaker_stats(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_provider_query_from_request(r.path, body) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  let body = match
    self.proxy.provider_router.get_circuit_breaker_stats(
      query.provider_id,
      query.app_type,
    ) {
    Some(stats) => stats.to_json()
    None => Json::null()
  }
  write_usage_json(w, body)
}

///|
async fn Gateway::handle_proxy_circuit_breaker_stats_moon_alias(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_circuit_breaker_stats_command_json())
}

///|
fn moon_circuit_breaker_stats_command_json() -> Json {
  Json::null()
}

///|
async fn Gateway::handle_proxy_reset_circuit_breaker(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_provider_query_from_request(r.path, body) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  let app_enabled = self.proxy_app_enabled_for_app(query.app_type)
  let _switched = self.proxy.provider_router.reset_provider_breaker_ccs(
    query.provider_id,
    query.app_type,
    app_enabled~,
    proxy_running=self.proxy.proxy_enabled,
  )
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn Gateway::handle_proxy_failover_queue(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_app_type_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(w, self.proxy.provider_router.failover_queue_json(app_type))
}

///|
async fn Gateway::handle_proxy_available_failover_providers(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_app_type_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(
    w,
    self.proxy.provider_router.available_failover_providers_json(app_type),
  )
}

///|
async fn Gateway::handle_proxy_add_failover_queue(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_provider_query_from_request(r.path, body) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  self.proxy.provider_router.add_to_failover_queue(
    query.app_type,
    query.provider_id,
  )
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn Gateway::handle_proxy_remove_failover_queue(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_provider_query_from_request(r.path, body) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  self.proxy.provider_router.remove_from_failover_queue(
    query.app_type,
    query.provider_id,
  )
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn Gateway::handle_proxy_auto_failover_enabled(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_app_type_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(
    w,
    Json::boolean(
      self.proxy.provider_router.auto_failover_enabled_for_app(app_type),
    ),
  )
}

///|
async fn Gateway::handle_proxy_set_auto_failover_enabled(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_app_type_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_bool_request(r.path, body, ["enabled"]) is Some(enabled) else {
    write_usage_bad_request(w, "missing_enabled")
    return
  }
  if !self.can_set_auto_failover_ccs(app_type, enabled) {
    write_usage_bad_request(w, "auto_failover_requires_proxy_takeover")
    return
  }
  if !self.proxy.provider_router.set_auto_failover_command_ccs(
      app_type, enabled,
    ) {
    write_usage_bad_request(w, "auto_failover_unavailable")
    return
  }
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn Gateway::handle_proxy_takeover_status(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(self.proxy_takeover_status_json().stringify(indent=2))
  w.flush()
}

///|
async fn Gateway::handle_proxy_set_takeover_for_app(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_app_type_from_request(r.path, config) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_bool_request(r.path, config, ["enabled"]) is Some(enabled) else {
    write_usage_bad_request(w, "missing_enabled")
    return
  }
  self.proxy.proxy_takeover_enabled.set(app_type, enabled)
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn Gateway::handle_proxy_live_takeover_active(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, Json::boolean(self.proxy_takeover_active()))
}

///|
async fn Gateway::handle_proxy_switch_provider(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_app_type_from_request(r.path, config) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_string_request(r.path, config, ["provider_id", "providerId"])
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard self.proxy.provider_router.provider_by_id(app_type, provider_id)
    is Some(provider) else {
    write_usage_bad_request(w, "provider_not_found")
    return
  }
  if provider.provider_type == Some("official") {
    write_usage_bad_request(w, "official_provider_blocked_during_takeover")
    return
  }
  self.proxy.provider_router.set_current_provider(app_type, provider_id)
  self.usage.set_active_target(
    app_type,
    provider.provider_id,
    provider.provider_name,
  )
  write_usage_json(w, moon_unit_success_json())
}

///|
fn Gateway::proxy_takeover_status_json(self : Gateway) -> Json {
  {
    "claude": Json::boolean(self.proxy_takeover_for_app("claude")),
    "codex": Json::boolean(self.proxy_takeover_for_app("codex")),
    "gemini": Json::boolean(self.proxy_takeover_for_app("gemini")),
    "opencode": Json::boolean(self.proxy_takeover_for_app("opencode")),
    "openclaw": Json::boolean(self.proxy_takeover_for_app("openclaw")),
  }.to_json()
}

///|
fn Gateway::proxy_takeover_for_app(self : Gateway, app_type : String) -> Bool {
  self.proxy.proxy_takeover_enabled.get(app_type).unwrap_or(false)
}

///|
fn Gateway::proxy_takeover_active(self : Gateway) -> Bool {
  for app_type in ["claude", "codex", "gemini", "opencode", "openclaw"] {
    if self.proxy_takeover_for_app(app_type) {
      return true
    }
  }
  false
}

///|
fn Gateway::proxy_clear_takeover(self : Gateway) -> Unit {
  for app_type in ["claude", "codex", "gemini", "opencode", "openclaw"] {
    self.proxy.proxy_takeover_enabled.set(app_type, false)
  }
}

///|
fn Gateway::proxy_clear_enabled_apps_for_manual_stop(self : Gateway) -> Unit {
  for app_type in ["claude", "codex", "gemini"] {
    self.proxy.proxy_app_enabled.set(app_type, false)
  }
}

///|
async fn Gateway::handle_proxy_running(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(Json::boolean(self.proxy.proxy_enabled).stringify())
  w.flush()
}

///|
async fn Gateway::handle_usage_model_pricing(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.usage.model_pricing_json())
}

///|
async fn Gateway::handle_usage_update_model_pricing(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  match usage_pricing_validation_error_from_request(r.path, body) {
    Some(error) => {
      write_usage_bad_request(w, error)
      return
    }
    None => ()
  }
  guard usage_pricing_from_request(r.path, body) is Some(pricing) else {
    write_usage_bad_request(w, "invalid_model_pricing")
    return
  }
  let _backfilled = self.usage.upsert_model_pricing(pricing)
  self.save_model_pricing_store()
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_usage_delete_model_pricing(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard usage_string_from_request(r.path, body, ["model_id", "modelId"])
    is Some(model_id) else {
    write_usage_bad_request(w, "missing_model_id")
    return
  }
  let trimmed = model_id.trim().to_owned()
  if trimmed.is_empty() {
    write_usage_bad_request(w, "missing_model_id")
    return
  }
  self.usage.delete_model_pricing(trimmed)
  self.save_model_pricing_store()
  write_usage_json(w, Json::null())
}

///|
fn proxy_provider_query_from_request(
  path : StringView,
  body : Json?,
) -> ProxyProviderQuery? {
  guard proxy_string_request(path, body, ["provider_id", "providerId"])
    is Some(provider_id) else {
    return None
  }
  guard proxy_app_type_from_request(path, body) is Some(app_type) else {
    return None
  }
  Some({ provider_id, app_type })
}

///|
fn proxy_app_type_from_request(path : StringView, body : Json?) -> String? {
  match proxy_string_request(path, body, ["app_type", "appType", "app"]) {
    Some(app_type) if !app_type.trim().is_empty() =>
      Some(app_type.trim().to_owned())
    _ => None
  }
}

///|
fn proxy_circuit_config_from_query(path : StringView) -> CircuitBreakerConfig? {
  guard usage_query_int_any(path, "failure_threshold", "failureThreshold")
    is Some(failure_threshold) else {
    return None
  }
  guard usage_query_int_any(path, "success_threshold", "successThreshold")
    is Some(success_threshold) else {
    return None
  }
  guard usage_query_int_any(path, "timeout_seconds", "timeoutSeconds")
    is Some(timeout_seconds) else {
    return None
  }
  guard usage_query_double_any(
      path, "error_rate_threshold", "errorRateThreshold",
    )
    is Some(error_rate_threshold) else {
    return None
  }
  guard usage_query_int_any(path, "min_requests", "minRequests")
    is Some(min_requests) else {
    return None
  }
  let config = {
    failure_threshold,
    success_threshold,
    timeout_seconds,
    error_rate_threshold,
    min_requests,
  }
  if circuit_breaker_config_is_valid(config) {
    Some(config)
  } else {
    None
  }
}

///|
async fn proxy_json_body(r : @httpx.RequestReader) -> Json? {
  let body = r.body.read_all().text()
  if body.trim().is_empty() {
    return None
  }
  Some(@json.parse(body) catch { _ => return None })
}

///|
fn proxy_embedded_config(body : Json?) -> Json? {
  match body {
    Some(Object(obj)) =>
      match obj.get("config") {
        Some(Object(config)) => Some(Json::object(config))
        _ => body
      }
    _ => body
  }
}

///|
fn provider_endpoint_sanitize_timeout_secs(timeout_secs : Int?) -> Int {
  let secs = timeout_secs.unwrap_or(CCS_ENDPOINT_DEFAULT_TIMEOUT_SECS)
  if secs < CCS_ENDPOINT_MIN_TIMEOUT_SECS {
    CCS_ENDPOINT_MIN_TIMEOUT_SECS
  } else if secs > CCS_ENDPOINT_MAX_TIMEOUT_SECS {
    CCS_ENDPOINT_MAX_TIMEOUT_SECS
  } else {
    secs
  }
}

///|
fn proxy_bool_request(
  path : StringView,
  config : Json?,
  keys : Array[String],
) -> Bool? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) =>
        match parse_bool_value(value) {
          Some(parsed) => return Some(parsed)
          None => ()
        }
      None => ()
    }
  }
  match config {
    Some(Object(obj)) =>
      for key in keys {
        match proxy_json_bool(obj, key) {
          Some(parsed) => return Some(parsed)
          None => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn proxy_string_request(
  path : StringView,
  config : Json?,
  keys : Array[String],
) -> String? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  match config {
    Some(Object(obj)) =>
      for key in keys {
        match obj.get(key) {
          Some(String(value)) => return Some(value)
          _ => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn proxy_int_request(
  path : StringView,
  config : Json?,
  keys : Array[String],
) -> Int? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) =>
        try @string.parse_int(value, base=10) catch {
          _ => ()
        } noraise {
          parsed => return Some(parsed)
        }
      None => ()
    }
  }
  match config {
    Some(Object(obj)) =>
      for key in keys {
        match proxy_json_int(obj, key) {
          Some(parsed) => return Some(parsed)
          None => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn proxy_double_request(
  path : StringView,
  config : Json?,
  keys : Array[String],
) -> Double? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) =>
        match parse_non_negative_decimal_to_double(value) {
          Some(parsed) => return Some(parsed)
          None => ()
        }
      None => ()
    }
  }
  match config {
    Some(Object(obj)) =>
      for key in keys {
        match obj.get(key) {
          Some(Number(value, ..)) => return Some(value)
          Some(String(value)) =>
            match parse_non_negative_decimal_to_double(value) {
              Some(parsed) => return Some(parsed)
              None => ()
            }
          _ => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn proxy_json_bool(obj : Map[String, Json], key : String) -> Bool? {
  match obj.get(key) {
    Some(true) => Some(true)
    Some(false) => Some(false)
    Some(String(value)) => parse_bool_value(value)
    _ => None
  }
}

///|
fn proxy_json_int(obj : Map[String, Json], key : String) -> Int? {
  match obj.get(key) {
    Some(Number(value, ..)) => Some(value.trunc().to_int())
    Some(String(value)) =>
      try @string.parse_int(value, base=10) catch {
        _ => None
      } noraise {
        parsed => Some(parsed)
      }
    _ => None
  }
}

///|
fn proxy_circuit_config_from_request(
  path : StringView,
  config : Json?,
  current : CircuitBreakerConfig,
) -> CircuitBreakerConfig? {
  let failure_threshold = proxy_int_request(path, config, [
    "failure_threshold", "failureThreshold",
  ])
  let success_threshold = proxy_int_request(path, config, [
    "success_threshold", "successThreshold",
  ])
  let timeout_seconds = proxy_int_request(path, config, [
    "timeout_seconds", "timeoutSeconds",
  ])
  let error_rate_threshold = proxy_double_request(path, config, [
    "error_rate_threshold", "errorRateThreshold",
  ])
  let min_requests = proxy_int_request(path, config, [
    "min_requests", "minRequests",
  ])
  if failure_threshold is None &&
    success_threshold is None &&
    timeout_seconds is None &&
    error_rate_threshold is None &&
    min_requests is None {
    return None
  }
  let next = {
    failure_threshold: failure_threshold.unwrap_or(current.failure_threshold),
    success_threshold: success_threshold.unwrap_or(current.success_threshold),
    timeout_seconds: timeout_seconds.unwrap_or(current.timeout_seconds),
    error_rate_threshold: error_rate_threshold.unwrap_or(
      current.error_rate_threshold,
    ),
    min_requests: min_requests.unwrap_or(current.min_requests),
  }
  if circuit_breaker_config_is_valid(next) {
    Some(next)
  } else {
    None
  }
}

///|
fn usage_pricing_from_request(path : StringView, body : Json?) -> ModelPricing? {
  guard usage_string_from_request(path, body, ["model_id", "modelId"])
    is Some(model_id) else {
    return None
  }
  guard usage_string_from_request(path, body, ["display_name", "displayName"])
    is Some(display_name) else {
    return None
  }
  guard usage_string_from_request(path, body, ["input_cost", "inputCost"])
    is Some(input_cost) else {
    return None
  }
  guard usage_string_from_request(path, body, ["output_cost", "outputCost"])
    is Some(output_cost) else {
    return None
  }
  guard usage_string_from_request(path, body, [
      "cache_read_cost", "cacheReadCost",
    ])
    is Some(cache_read_cost) else {
    return None
  }
  guard usage_string_from_request(path, body, [
      "cache_creation_cost", "cacheCreationCost",
    ])
    is Some(cache_creation_cost) else {
    return None
  }
  let model_id = model_id.trim().to_owned()
  let display_name = display_name.trim().to_owned()
  if model_id.is_empty() || display_name.is_empty() {
    return None
  }
  for value in [input_cost, output_cost, cache_read_cost, cache_creation_cost] {
    if !usage_non_negative_decimal(value) {
      return None
    }
  }
  Some(
    mp(
      model_id,
      display_name,
      input_cost.trim().to_owned(),
      output_cost.trim().to_owned(),
      cache_read_cost.trim().to_owned(),
      cache_creation_cost.trim().to_owned(),
    ),
  )
}

///|
fn usage_pricing_validation_error_from_request(
  path : StringView,
  body : Json?,
) -> String? {
  guard usage_string_from_request(path, body, ["model_id", "modelId"])
    is Some(model_id) else {
    return Some("Model ID is required")
  }
  if model_id.trim().is_empty() {
    return Some("Model ID is required")
  }
  guard usage_string_from_request(path, body, ["display_name", "displayName"])
    is Some(display_name) else {
    return Some("Display name is required")
  }
  if display_name.trim().is_empty() {
    return Some("Display name is required")
  }
  match
    usage_decimal_validation_error_from_request(path, body, "input_cost", [
      "input_cost", "inputCost",
    ]) {
    Some(error) => return Some(error)
    None => ()
  }
  match
    usage_decimal_validation_error_from_request(path, body, "output_cost", [
      "output_cost", "outputCost",
    ]) {
    Some(error) => return Some(error)
    None => ()
  }
  match
    usage_decimal_validation_error_from_request(path, body, "cache_read_cost", [
      "cache_read_cost", "cacheReadCost",
    ]) {
    Some(error) => return Some(error)
    None => ()
  }
  usage_decimal_validation_error_from_request(
    path,
    body,
    "cache_creation_cost",
    ["cache_creation_cost", "cacheCreationCost"],
  )
}

///|
fn Gateway::pricing_override_rows(self : Gateway) -> Array[ModelPricing] {
  self.usage.pricing_override_rows()
}

///|
async fn Gateway::load_model_pricing_store(self : Gateway) -> Unit {
  let path = @pathx.join(
    default_moonstat_stats_dir(),
    MOONSTAT_MODEL_PRICING_FILE,
  )
  if !@fsx.exists_as_file(path) {
    return
  }
  let content = @fsx.read_file(path) catch { _ => return }
  for line_view in content.split("\n") {
    let line = line_view.to_owned().trim()
    if line.is_empty() {
      continue
    }
    let parsed = @json.parse(line) catch { _ => continue }
    guard parsed is Object(obj) else { continue }
    guard store_json_string(obj, "modelId") is Some(model_id) else { continue }
    if store_json_bool_or_false(obj, "deleted") {
      self.usage.pricing_deleted_model_ids.set(model_id, true)
    } else {
      match model_pricing_from_store_json(obj) {
        Some(pricing) => {
          self.usage.pricing_overrides.set(pricing.model_id, pricing)
          self.usage.pricing_deleted_model_ids.set(model_id, false)
        }
        None => ()
      }
    }
  }
}

///|
async fn Gateway::save_model_pricing_store(self : Gateway) -> Unit {
  let storage_dir = default_moonstat_stats_dir()
  @fsx.make_directory(storage_dir, recursive=true, exists_ok=true) catch {
    _ => return
  }
  let lines : Array[String] = []
  for pricing in self.pricing_override_rows() {
    if model_pricing_is_deleted(
        pricing.model_id,
        self.usage.pricing_deleted_model_ids,
      ) {
      continue
    }
    lines.push(model_pricing_store_json(pricing, deleted=false).stringify())
  }
  for model_id in self.usage.pricing_deleted_model_ids.keys() {
    if !self.usage.pricing_deleted_model_ids.get(model_id).unwrap_or(false) {
      continue
    }
    lines.push(
      { "modelId": Json::string(model_id), "deleted": Json::boolean(true) }
      .to_json()
      .stringify(),
    )
  }
  @fsx.write_to_file(
    @pathx.join(storage_dir, MOONSTAT_MODEL_PRICING_FILE),
    lines.join("\n"),
  ) catch {
    _ => ()
  }
}

///|
fn model_pricing_from_store_json(obj : Map[String, Json]) -> ModelPricing? {
  guard store_json_string(obj, "modelId") is Some(model_id) else { return None }
  guard store_json_string(obj, "displayName") is Some(display_name) else {
    return None
  }
  guard store_json_string(obj, "inputCostPerMillion") is Some(input_cost) else {
    return None
  }
  guard store_json_string(obj, "outputCostPerMillion") is Some(output_cost) else {
    return None
  }
  guard store_json_string(obj, "cacheReadCostPerMillion")
    is Some(cache_read_cost) else {
    return None
  }
  guard store_json_string(obj, "cacheCreationCostPerMillion")
    is Some(cache_creation_cost) else {
    return None
  }
  if model_id.trim().is_empty() || display_name.trim().is_empty() {
    return None
  }
  for value in [input_cost, output_cost, cache_read_cost, cache_creation_cost] {
    if !usage_non_negative_decimal(value) {
      return None
    }
  }
  Some(
    mp(
      model_id.trim().to_owned(),
      display_name.trim().to_owned(),
      input_cost.trim().to_owned(),
      output_cost.trim().to_owned(),
      cache_read_cost.trim().to_owned(),
      cache_creation_cost.trim().to_owned(),
    ),
  )
}

///|
fn model_pricing_store_json(pricing : ModelPricing, deleted~ : Bool) -> Json {
  {
    "modelId": Json::string(pricing.model_id),
    "displayName": Json::string(pricing.display_name),
    "inputCostPerMillion": Json::string(pricing.input_cost_per_million),
    "outputCostPerMillion": Json::string(pricing.output_cost_per_million),
    "cacheReadCostPerMillion": Json::string(pricing.cache_read_cost_per_million),
    "cacheCreationCostPerMillion": Json::string(
      pricing.cache_creation_cost_per_million,
    ),
    "deleted": Json::boolean(deleted),
  }.to_json()
}

///|
fn claude_desktop_default_proxy_route_ids() -> Array[String] {
  ["claude-sonnet-4-6", "claude-opus-4-8", "claude-haiku-4-5"]
}

///|
fn claude_desktop_proxy_request_json_for_upstream(
  body : Json,
  provider : ProviderRouteTarget,
  upstream_model : String,
  app_type : String,
) -> Json {
  guard app_type == "claude-desktop" else { return body }
  guard provider.should_normalize_mimo_anthropic_thinking_history(
    upstream_model,
  ) else {
    return body
  }
  normalize_mimo_anthropic_thinking_history(body)
}

///|
fn moon_media_retry_should_trigger(
  status_code : Int,
  response_body : String,
  request_body : Json,
) -> Bool {
  moon_media_retry_should_trigger_with_config(
    status_code,
    response_body,
    request_body,
    moonstat_rectifier_config_from_env(),
  )
}

///|
fn moon_media_retry_should_trigger_with_config(
  status_code : Int,
  response_body : String,
  request_body : Json,
  config : RectifierConfig,
) -> Bool {
  config.enabled &&
  config.request_media_fallback &&
  contains_image_blocks(request_body) &&
  is_unsupported_image_error_status(status_code, response_body)
}
