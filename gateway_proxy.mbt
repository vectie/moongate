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
fn ProxyService::all_provider_circuits_open(
  self : ProxyService,
  app_type : String,
) -> Bool {
  provider_selection_is_all_circuits_open(
    self.provider_router.select_providers(app_type),
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
    if value.contains(MOONSTAT_PROXY_MANAGED_PLACEHOLDER) {
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
fn ProxyService::provider_cost_multiplier(
  self : ProxyService,
  provider : ProviderRouteTarget,
) -> String {
  provider_cost_multiplier_from_default(
    provider,
    self.default_cost_multiplier_for_app(provider.app_type),
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
      match json_string_from_map(obj, "costMultiplier") {
        Some(value) if usage_non_negative_decimal(value) =>
          return value.trim().to_owned()
        _ => ()
      }
      match obj.get("meta") {
        Some(Object(meta)) =>
          match json_string_from_map(meta, "costMultiplier") {
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
  let global_keys = ["MOONSTAT_DEFAULT_COST_MULTIPLIER"]
  let app_keys = match app_type {
    "claude" | "claude-desktop" => ["MOONSTAT_CLAUDE_DEFAULT_COST_MULTIPLIER"]
    "codex" => ["MOONSTAT_CODEX_DEFAULT_COST_MULTIPLIER"]
    "gemini" => ["MOONSTAT_GEMINI_DEFAULT_COST_MULTIPLIER"]
    "opencode" => ["MOONSTAT_OPENCODE_DEFAULT_COST_MULTIPLIER"]
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
fn ProxyService::provider_pricing_model_source(
  self : ProxyService,
  provider : ProviderRouteTarget,
) -> String {
  provider_pricing_model_source_from_default(
    provider,
    self.pricing_model_source_for_app(provider.app_type),
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
      match json_string_from_map(obj, "pricingModelSource") {
        Some(value) if pricing_model_source_is_valid(value) =>
          return value.trim().to_owned()
        _ => ()
      }
      match obj.get("meta") {
        Some(Object(meta)) =>
          match json_string_from_map(meta, "pricingModelSource") {
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
  let global_keys = ["MOONSTAT_PRICING_MODEL_SOURCE"]
  let app_keys = match app_type {
    "claude" | "claude-desktop" => ["MOONSTAT_CLAUDE_PRICING_MODEL_SOURCE"]
    "codex" => ["MOONSTAT_CODEX_PRICING_MODEL_SOURCE"]
    "gemini" => ["MOONSTAT_GEMINI_PRICING_MODEL_SOURCE"]
    "opencode" => ["MOONSTAT_OPENCODE_PRICING_MODEL_SOURCE"]
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
fn ProxyService::status_json(
  self : ProxyService,
  usage : UsageService,
  host : String,
  port : Int,
  uptime_seconds : Int,
) -> Json {
  usage.status_json(host, port, uptime_seconds, running=self.proxy_enabled)
}

///|
async fn ProxyService::handle_proxy_status(
  self : ProxyService,
  w : @httpx.ResponseWriter,
  usage : UsageService,
  host : String,
  port : Int,
  uptime_seconds : Int,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(
    self.status_json(usage, host, port, uptime_seconds).stringify(indent=2),
  )
  w.flush()
}

///|
async fn ProxyService::handle_proxy_start_server(
  self : ProxyService,
  w : @httpx.ResponseWriter,
  started_at_ms : Int,
) -> Unit {
  self.proxy_enabled = true
  write_usage_json(w, self.server_info_json(started_at_ms))
}

///|
async fn ProxyService::handle_proxy_stop_server(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  if self.takeover_active() {
    write_usage_bad_request(w, moon_stop_proxy_takeover_error())
    return
  }
  self.proxy_enabled = false
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn ProxyService::handle_proxy_stop_with_restore(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.proxy_enabled = false
  self.clear_takeover()
  self.clear_enabled_apps_for_manual_stop()
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn ProxyService::handle_proxy_running(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(Json::boolean(self.proxy_enabled).stringify())
  w.flush()
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
  let config = body
  let url = proxy_string_request(r.path, config, "url").unwrap_or("")
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
  let config = body
  let url = proxy_string_request(r.path, config, "url").unwrap_or("")
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
) -> Bool {
  let body = proxy_json_body(r)
  let config = body
  let proxy_enabled = proxy_bool_request(r.path, config, "proxyEnabled")
  let listen_address = proxy_string_request(r.path, config, "listenAddress")
  let listen_port = proxy_int_request(r.path, config, "listenPort")
  let enable_logging = proxy_bool_request(r.path, config, "enableLogging")
  if proxy_enabled is Some(enabled) {
    self.proxy_enabled = enabled
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
fn moon_stop_proxy_takeover_error() -> String {
  "仍有应用处于代理接管状态，请先在设置中关闭对应应用接管后再停止本地路由。"
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
async fn ProxyService::handle_proxy_app_config(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_app_type_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(w, self.app_config_json(app_type))
}

///|
fn ProxyService::app_config_json(
  self : ProxyService,
  app_type : String,
) -> Json {
  let circuit = self.provider_router.circuit_config_for_app(app_type)
  let enabled = self.app_enabled_for_app(app_type)
  let auto_failover_enabled = self.provider_router.auto_failover_enabled_for_app(
    app_type,
  )
  let max_retries = self.provider_router.max_retries_for_app(app_type)
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
    "appType": Json::string(app_type),
    "enabled": Json::boolean(enabled),
    "autoFailoverEnabled": Json::boolean(auto_failover_enabled),
    "maxRetries": Json::number(max_retries.to_double()),
    "streamingFirstByteTimeout": Json::number(
      streaming_first_byte_timeout.to_double(),
    ),
    "streamingIdleTimeout": Json::number(streaming_idle_timeout.to_double()),
    "nonStreamingTimeout": Json::number(non_streaming_timeout.to_double()),
    "circuitFailureThreshold": Json::number(
      circuit.failure_threshold.to_double(),
    ),
    "circuitSuccessThreshold": Json::number(
      circuit.success_threshold.to_double(),
    ),
    "circuitTimeoutSeconds": Json::number(circuit.timeout_seconds.to_double()),
    "circuitErrorRateThreshold": Json::number(circuit.error_rate_threshold),
    "circuitMinRequests": Json::number(circuit.min_requests.to_double()),
  }.to_json()
}

///|
async fn ProxyService::handle_proxy_update_app_config(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.apply_app_config_request(r) {
    Some(_) => write_usage_json(w, moon_unit_success_json())
    None => write_usage_bad_request(w, "invalid_app_proxy_config")
  }
}

///|
async fn ProxyService::handle_proxy_default_cost_multiplier(
  self : ProxyService,
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
    Json::string(self.default_cost_multiplier_for_app(app_type)),
  )
}

///|
async fn ProxyService::handle_proxy_set_default_cost_multiplier(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = body
  guard proxy_app_type_from_request(r.path, config) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_string_request(r.path, config, "value") is Some(value) else {
    write_usage_bad_request(w, "missing_value")
    return
  }
  if !usage_non_negative_decimal(value) {
    write_usage_bad_request(w, "invalid_default_cost_multiplier")
    return
  }
  let trimmed = value.trim().to_owned()
  self.proxy_default_cost_multipliers.set(app_type, trimmed)
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn ProxyService::handle_proxy_pricing_model_source(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_app_type_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(w, Json::string(self.pricing_model_source_for_app(app_type)))
}

///|
async fn ProxyService::handle_proxy_set_pricing_model_source(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = body
  guard proxy_app_type_from_request(r.path, config) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_string_request(r.path, config, "value") is Some(value) else {
    write_usage_bad_request(w, "missing_value")
    return
  }
  if !pricing_model_source_is_valid(value) {
    write_usage_bad_request(w, "invalid_pricing_model_source")
    return
  }
  let trimmed = value.trim().to_owned()
  self.proxy_pricing_model_sources.set(app_type, trimmed)
  write_usage_json(w, moon_unit_success_json())
}

///|
fn ProxyService::default_cost_multiplier_for_app(
  self : ProxyService,
  app_type : String,
) -> String {
  let default_app_type = proxy_pricing_default_app_type(app_type)
  self.proxy_default_cost_multipliers
  .get(default_app_type)
  .unwrap_or(default_cost_multiplier_for_app(app_type))
}

///|
fn ProxyService::pricing_model_source_for_app(
  self : ProxyService,
  app_type : String,
) -> String {
  let default_app_type = proxy_pricing_default_app_type(app_type)
  self.proxy_pricing_model_sources
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
async fn ProxyService::apply_app_config_request(
  self : ProxyService,
  r : @httpx.RequestReader,
) -> String? {
  let body = proxy_json_body(r)
  let config = body
  let app_type = match proxy_app_type_from_request(r.path, config) {
    Some(app_type) if !app_type.trim().is_empty() => app_type.trim().to_owned()
    _ => return None
  }
  match proxy_bool_request(r.path, config, "enabled") {
    Some(enabled) => self.proxy_app_enabled.set(app_type, enabled)
    None => ()
  }
  match proxy_bool_request(r.path, config, "autoFailoverEnabled") {
    Some(enabled) =>
      if !self.provider_router.set_auto_failover_checked(app_type, enabled) {
        return None
      }
    None => ()
  }
  match proxy_int_request(r.path, config, "maxRetries") {
    Some(max_retries) if max_retries >= 0 =>
      self.provider_router.set_max_retries(app_type, max_retries)
    Some(_) => return None
    None => ()
  }
  if !self.apply_app_timeout_config(app_type, r.path, config) {
    return None
  }
  match
    proxy_circuit_config_from_request(
      r.path,
      config,
      self.provider_router.circuit_config_for_app(app_type),
    ) {
    Some(config) => self.provider_router.update_app_configs(app_type, config)
    None => ()
  }
  Some(app_type)
}

///|
fn ProxyService::apply_app_timeout_config(
  self : ProxyService,
  app_type : String,
  path : StringView,
  config : Json?,
) -> Bool {
  match proxy_int_request(path, config, "streamingFirstByteTimeout") {
    Some(timeout) if timeout > 0 =>
      self.proxy_streaming_first_byte_timeout.set(app_type, timeout)
    Some(_) => return false
    None => ()
  }
  match proxy_int_request(path, config, "streamingIdleTimeout") {
    Some(timeout) if timeout > 0 =>
      self.proxy_streaming_idle_timeout.set(app_type, timeout)
    Some(_) => return false
    None => ()
  }
  match proxy_int_request(path, config, "nonStreamingTimeout") {
    Some(timeout) if timeout > 0 =>
      self.proxy_non_streaming_timeout.set(app_type, timeout)
    Some(_) => return false
    None => ()
  }
  true
}

///|
fn ProxyService::app_enabled_for_app(
  self : ProxyService,
  app_type : String,
) -> Bool {
  self.proxy_app_enabled
  .get(app_type)
  .unwrap_or(self.provider_router.has_configured_app(app_type))
}

///|
fn ProxyService::can_set_auto_failover(
  self : ProxyService,
  app_type : String,
  enabled : Bool,
) -> Bool {
  !enabled || self.app_enabled_for_app(app_type)
}

///|
async fn ProxyService::handle_proxy_provider_health(
  self : ProxyService,
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
    self.provider_router.provider_health_json(
      query.provider_id,
      query.app_type,
      @async.now().to_string(),
    ),
  )
}

///|
async fn ProxyService::handle_proxy_circuit_breaker_config(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.provider_router.circuit_config.to_json())
}

///|
async fn ProxyService::handle_proxy_update_circuit_breaker_config(
  self : ProxyService,
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
  self.provider_router.update_all_configs(config)
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn ProxyService::handle_proxy_circuit_breaker_stats(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_provider_query_from_request(r.path, body) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  let body = match
    self.provider_router.get_circuit_breaker_stats(
      query.provider_id,
      query.app_type,
    ) {
    Some(stats) => stats.to_json()
    None => Json::null()
  }
  write_usage_json(w, body)
}

///|
async fn ProxyService::handle_proxy_reset_circuit_breaker(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_provider_query_from_request(r.path, body) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  let app_enabled = self.app_enabled_for_app(query.app_type)
  let _switched = self.provider_router.reset_provider_breaker_and_restore(
    query.provider_id,
    query.app_type,
    app_enabled~,
    proxy_running=self.proxy_enabled,
  )
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn ProxyService::handle_proxy_failover_queue(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_app_type_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(w, self.provider_router.failover_queue_json(app_type))
}

///|
async fn ProxyService::handle_proxy_available_failover_providers(
  self : ProxyService,
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
    self.provider_router.available_failover_providers_json(app_type),
  )
}

///|
async fn ProxyService::handle_proxy_add_failover_queue(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_provider_query_from_request(r.path, body) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  self.provider_router.add_to_failover_queue(query.app_type, query.provider_id)
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn ProxyService::handle_proxy_remove_failover_queue(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_provider_query_from_request(r.path, body) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  self.provider_router.remove_from_failover_queue(
    query.app_type,
    query.provider_id,
  )
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn ProxyService::handle_proxy_auto_failover_enabled(
  self : ProxyService,
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
    Json::boolean(self.provider_router.auto_failover_enabled_for_app(app_type)),
  )
}

///|
async fn ProxyService::handle_proxy_set_auto_failover_enabled(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_app_type_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_bool_request(r.path, body, "enabled") is Some(enabled) else {
    write_usage_bad_request(w, "missing_enabled")
    return
  }
  if !self.can_set_auto_failover(app_type, enabled) {
    write_usage_bad_request(w, "auto_failover_requires_proxy_takeover")
    return
  }
  if !self.provider_router.set_auto_failover_from_command(app_type, enabled) {
    write_usage_bad_request(w, "auto_failover_unavailable")
    return
  }
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn ProxyService::handle_proxy_takeover_status(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(self.takeover_status_json().stringify(indent=2))
  w.flush()
}

///|
async fn ProxyService::handle_proxy_set_takeover_for_app(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = body
  guard proxy_app_type_from_request(r.path, config) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_bool_request(r.path, config, "enabled") is Some(enabled) else {
    write_usage_bad_request(w, "missing_enabled")
    return
  }
  self.proxy_takeover_enabled.set(app_type, enabled)
  write_usage_json(w, moon_unit_success_json())
}

///|
async fn ProxyService::switch_provider_from_request(
  self : ProxyService,
  r : @httpx.RequestReader,
) -> Result[ProviderRouteTarget, String] {
  let body = proxy_json_body(r)
  let config = body
  guard proxy_app_type_from_request(r.path, config) is Some(app_type) else {
    return Err("missing_app_type")
  }
  guard proxy_string_request(r.path, config, "providerId") is Some(provider_id) else {
    return Err("missing_provider_id")
  }
  guard self.provider_router.provider_by_id(app_type, provider_id)
    is Some(provider) else {
    return Err("provider_not_found")
  }
  if provider.provider_type == Some("official") {
    return Err("official_provider_blocked_during_takeover")
  }
  self.provider_router.set_current_provider(app_type, provider_id)
  Ok(provider)
}

///|
async fn ProxyService::handle_proxy_switch_provider(
  self : ProxyService,
  usage : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let provider = match self.switch_provider_from_request(r) {
    Ok(provider) => provider
    Err(error) => {
      write_usage_bad_request(w, error)
      return
    }
  }
  usage.set_active_target(
    provider.app_type,
    provider.provider_id,
    provider.provider_name,
  )
  write_usage_json(w, moon_unit_success_json())
}

///|
fn ProxyService::takeover_status_json(self : ProxyService) -> Json {
  {
    "claude": Json::boolean(self.takeover_for_app("claude")),
    "codex": Json::boolean(self.takeover_for_app("codex")),
    "gemini": Json::boolean(self.takeover_for_app("gemini")),
    "opencode": Json::boolean(self.takeover_for_app("opencode")),
    "openclaw": Json::boolean(self.takeover_for_app("openclaw")),
  }.to_json()
}

///|
fn ProxyService::takeover_for_app(
  self : ProxyService,
  app_type : String,
) -> Bool {
  self.proxy_takeover_enabled.get(app_type).unwrap_or(false)
}

///|
fn ProxyService::takeover_active(self : ProxyService) -> Bool {
  for app_type in ["claude", "codex", "gemini", "opencode", "openclaw"] {
    if self.takeover_for_app(app_type) {
      return true
    }
  }
  false
}

///|
fn ProxyService::clear_takeover(self : ProxyService) -> Unit {
  for app_type in ["claude", "codex", "gemini", "opencode", "openclaw"] {
    self.proxy_takeover_enabled.set(app_type, false)
  }
}

///|
fn ProxyService::clear_enabled_apps_for_manual_stop(
  self : ProxyService,
) -> Unit {
  for app_type in ["claude", "codex", "gemini"] {
    self.proxy_app_enabled.set(app_type, false)
  }
}

///|
fn proxy_provider_query_from_request(
  path : StringView,
  body : Json?,
) -> ProxyProviderQuery? {
  guard proxy_string_request(path, body, "providerId") is Some(provider_id) else {
    return None
  }
  guard proxy_app_type_from_request(path, body) is Some(app_type) else {
    return None
  }
  Some({ provider_id, app_type })
}

///|
fn proxy_app_type_from_request(path : StringView, body : Json?) -> String? {
  match proxy_string_request(path, body, "appType") {
    Some(app_type) if !app_type.trim().is_empty() =>
      Some(app_type.trim().to_owned())
    _ => None
  }
}

///|
fn proxy_circuit_config_from_query(path : StringView) -> CircuitBreakerConfig? {
  guard proxy_int_request(path, None, "failureThreshold")
    is Some(failure_threshold) else {
    return None
  }
  guard proxy_int_request(path, None, "successThreshold")
    is Some(success_threshold) else {
    return None
  }
  guard proxy_int_request(path, None, "timeoutSeconds") is Some(timeout_seconds) else {
    return None
  }
  guard proxy_double_request(path, None, "errorRateThreshold")
    is Some(error_rate_threshold) else {
    return None
  }
  guard proxy_int_request(path, None, "minRequests") is Some(min_requests) else {
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
fn provider_endpoint_sanitize_timeout_secs(timeout_secs : Int?) -> Int {
  let secs = timeout_secs.unwrap_or(MOONSTAT_ENDPOINT_DEFAULT_TIMEOUT_SECS)
  if secs < MOONSTAT_ENDPOINT_MIN_TIMEOUT_SECS {
    MOONSTAT_ENDPOINT_MIN_TIMEOUT_SECS
  } else if secs > MOONSTAT_ENDPOINT_MAX_TIMEOUT_SECS {
    MOONSTAT_ENDPOINT_MAX_TIMEOUT_SECS
  } else {
    secs
  }
}

///|
fn proxy_bool_request(path : StringView, config : Json?, key : String) -> Bool? {
  match usage_query_value(path, key) {
    Some(value) =>
      match parse_bool_value(value) {
        Some(parsed) => return Some(parsed)
        None => ()
      }
    None => ()
  }
  match config {
    Some(Object(obj)) => proxy_json_bool(obj, key)
    _ => None
  }
}

///|
fn proxy_string_request(
  path : StringView,
  config : Json?,
  key : String,
) -> String? {
  match usage_query_value(path, key) {
    Some(value) => return Some(value)
    None => ()
  }
  match config {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn proxy_int_request(path : StringView, config : Json?, key : String) -> Int? {
  match usage_query_value(path, key) {
    Some(value) =>
      try @string.parse_int(value, base=10) catch {
        _ => ()
      } noraise {
        parsed => return Some(parsed)
      }
    None => ()
  }
  match config {
    Some(Object(obj)) => proxy_json_int(obj, key)
    _ => None
  }
}

///|
fn proxy_double_request(
  path : StringView,
  config : Json?,
  key : String,
) -> Double? {
  match usage_query_value(path, key) {
    Some(value) =>
      match parse_non_negative_decimal_to_double(value) {
        Some(parsed) => return Some(parsed)
        None => ()
      }
    None => ()
  }
  match config {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Number(value, ..)) => Some(value)
        Some(String(value)) => parse_non_negative_decimal_to_double(value)
        _ => None
      }
    _ => None
  }
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
  let failure_threshold = proxy_int_request(path, config, "failureThreshold")
  let success_threshold = proxy_int_request(path, config, "successThreshold")
  let timeout_seconds = proxy_int_request(path, config, "timeoutSeconds")
  let error_rate_threshold = proxy_double_request(
    path, config, "errorRateThreshold",
  )
  let min_requests = proxy_int_request(path, config, "minRequests")
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
  guard usage_string_from_request(path, body, "modelId") is Some(model_id) else {
    return None
  }
  guard usage_string_from_request(path, body, "displayName")
    is Some(display_name) else {
    return None
  }
  guard usage_string_from_request(path, body, "inputCost") is Some(input_cost) else {
    return None
  }
  guard usage_string_from_request(path, body, "outputCost") is Some(output_cost) else {
    return None
  }
  guard usage_string_from_request(path, body, "cacheReadCost")
    is Some(cache_read_cost) else {
    return None
  }
  guard usage_string_from_request(path, body, "cacheCreationCost")
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
  guard usage_string_from_request(path, body, "modelId") is Some(model_id) else {
    return Some("Model ID is required")
  }
  if model_id.trim().is_empty() {
    return Some("Model ID is required")
  }
  guard usage_string_from_request(path, body, "displayName")
    is Some(display_name) else {
    return Some("Display name is required")
  }
  if display_name.trim().is_empty() {
    return Some("Display name is required")
  }
  match
    usage_decimal_validation_error_from_request(
      path, body, "inputCost", "inputCost",
    ) {
    Some(error) => return Some(error)
    None => ()
  }
  match
    usage_decimal_validation_error_from_request(
      path, body, "outputCost", "outputCost",
    ) {
    Some(error) => return Some(error)
    None => ()
  }
  match
    usage_decimal_validation_error_from_request(
      path, body, "cacheReadCost", "cacheReadCost",
    ) {
    Some(error) => return Some(error)
    None => ()
  }
  usage_decimal_validation_error_from_request(
    path, body, "cacheCreationCost", "cacheCreationCost",
  )
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
