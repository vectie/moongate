///|
priv enum CircuitState {
  Closed
  Open
  HalfOpen
} derive(Eq)

///|
fn CircuitState::to_string(self : CircuitState) -> String {
  match self {
    Closed => "closed"
    Open => "open"
    HalfOpen => "half_open"
  }
}

///|
priv struct CircuitBreakerConfig {
  failure_threshold : Int
  success_threshold : Int
  timeout_seconds : Int
  error_rate_threshold : Double
  min_requests : Int
}

///|
fn CircuitBreakerConfig::default() -> CircuitBreakerConfig {
  {
    failure_threshold: 4,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  }
}

///|
fn moon_proxy_max_retries_default(app_type : String) -> Int {
  match app_type {
    "claude" => 6
    "gemini" => 5
    _ => 3
  }
}

///|
fn moon_proxy_circuit_config_default(app_type : String) -> CircuitBreakerConfig {
  match app_type {
    "claude" =>
      {
        failure_threshold: 8,
        success_threshold: 3,
        timeout_seconds: 90,
        error_rate_threshold: 0.7,
        min_requests: 15,
      }
    _ => CircuitBreakerConfig::default()
  }
}

///|
priv struct AllowResult {
  allowed : Bool
  used_half_open_permit : Bool
}

///|
priv struct CircuitBreakerStats {
  state : CircuitState
  consecutive_failures : Int
  consecutive_successes : Int
  total_requests : Int
  failed_requests : Int
}

///|
fn CircuitBreakerStats::to_json(self : CircuitBreakerStats) -> Json {
  {
    "state": Json::string(self.state.to_string()),
    "consecutiveFailures": Json::number(self.consecutive_failures.to_double()),
    "consecutiveSuccesses": Json::number(self.consecutive_successes.to_double()),
    "totalRequests": Json::number(self.total_requests.to_double()),
    "failedRequests": Json::number(self.failed_requests.to_double()),
  }.to_json()
}

///|
fn CircuitBreakerConfig::to_json(self : CircuitBreakerConfig) -> Json {
  {
    "failureThreshold": Json::number(self.failure_threshold.to_double()),
    "successThreshold": Json::number(self.success_threshold.to_double()),
    "timeoutSeconds": Json::number(self.timeout_seconds.to_double()),
    "errorRateThreshold": Json::number(self.error_rate_threshold),
    "minRequests": Json::number(self.min_requests.to_double()),
  }.to_json()
}

///|
fn circuit_breaker_config_from_json(json : Json) -> CircuitBreakerConfig? {
  let config_json = match json {
    Object(obj) =>
      match obj.get("config") {
        Some(Object(config_obj)) => Json::object(config_obj)
        _ => json
      }
    _ => json
  }
  guard config_json is Object(obj) else { return None }
  guard circuit_config_int_json(obj, "failureThreshold")
    is Some(failure_threshold) else {
    return None
  }
  guard circuit_config_int_json(obj, "successThreshold")
    is Some(success_threshold) else {
    return None
  }
  guard circuit_config_int_json(obj, "timeoutSeconds") is Some(timeout_seconds) else {
    return None
  }
  guard circuit_config_double_json(obj, "errorRateThreshold")
    is Some(error_rate_threshold) else {
    return None
  }
  guard circuit_config_int_json(obj, "minRequests") is Some(min_requests) else {
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
fn circuit_config_int_json(obj : Map[String, Json], key : String) -> Int? {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n.trunc().to_int())
    _ => None
  }
}

///|
fn circuit_config_double_json(obj : Map[String, Json], key : String) -> Double? {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n)
    _ => None
  }
}

///|
fn circuit_breaker_config_is_valid(config : CircuitBreakerConfig) -> Bool {
  config.failure_threshold >= 1 &&
  config.failure_threshold <= 20 &&
  config.success_threshold >= 1 &&
  config.success_threshold <= 10 &&
  config.timeout_seconds >= 0 &&
  config.timeout_seconds <= 300 &&
  config.error_rate_threshold >= 0.0 &&
  config.error_rate_threshold <= 1.0 &&
  config.min_requests >= 5 &&
  config.min_requests <= 100
}

///|
priv struct CircuitBreaker {
  mut state : CircuitState
  mut consecutive_failures : Int
  mut consecutive_successes : Int
  mut total_requests : Int
  mut failed_requests : Int
  mut last_opened_at_ms : Int?
  mut config : CircuitBreakerConfig
  mut half_open_requests : Int
}

///|
fn CircuitBreaker::new(
  config? : CircuitBreakerConfig = CircuitBreakerConfig::default(),
) -> CircuitBreaker {
  {
    state: Closed,
    consecutive_failures: 0,
    consecutive_successes: 0,
    total_requests: 0,
    failed_requests: 0,
    last_opened_at_ms: None,
    config,
    half_open_requests: 0,
  }
}

///|
fn CircuitBreaker::update_config(
  self : CircuitBreaker,
  config : CircuitBreakerConfig,
) -> Unit {
  self.config = config
}

///|
fn CircuitBreaker::is_available(
  self : CircuitBreaker,
  now_ms? : Int = @async.now().to_int(),
) -> Bool {
  match self.state {
    Closed | HalfOpen => true
    Open =>
      if self.open_timeout_elapsed(now_ms) {
        self.transition_to_half_open()
        true
      } else {
        false
      }
  }
}

///|
fn CircuitBreaker::allow_request(
  self : CircuitBreaker,
  now_ms? : Int = @async.now().to_int(),
) -> AllowResult {
  match self.state {
    Closed => { allowed: true, used_half_open_permit: false }
    Open =>
      if self.open_timeout_elapsed(now_ms) {
        self.transition_to_half_open()
        match self.state {
          Closed => { allowed: true, used_half_open_permit: false }
          HalfOpen => self.allow_half_open_probe()
          Open => { allowed: false, used_half_open_permit: false }
        }
      } else {
        { allowed: false, used_half_open_permit: false }
      }
    HalfOpen => self.allow_half_open_probe()
  }
}

///|
fn CircuitBreaker::record_success(
  self : CircuitBreaker,
  used_half_open_permit : Bool,
) -> Unit {
  let state = self.state
  if used_half_open_permit {
    self.release_half_open_permit()
  }
  self.consecutive_failures = 0
  self.total_requests += 1
  if state == HalfOpen {
    self.consecutive_successes += 1
    if self.consecutive_successes >= self.config.success_threshold {
      self.transition_to_closed()
    }
  }
}

///|
fn CircuitBreaker::record_failure(
  self : CircuitBreaker,
  used_half_open_permit : Bool,
  now_ms? : Int = @async.now().to_int(),
) -> Unit {
  let state = self.state
  if used_half_open_permit {
    self.release_half_open_permit()
  }
  self.consecutive_failures += 1
  self.total_requests += 1
  self.failed_requests += 1
  self.consecutive_successes = 0
  match state {
    HalfOpen => self.transition_to_open(now_ms)
    Closed =>
      if self.consecutive_failures >= self.config.failure_threshold {
        self.transition_to_open(now_ms)
      } else if self.total_requests >= self.config.min_requests {
        let error_rate = self.failed_requests.to_double() /
          self.total_requests.to_double()
        if error_rate >= self.config.error_rate_threshold {
          self.transition_to_open(now_ms)
        }
      }
    Open => ()
  }
}

///|
fn CircuitBreaker::release_half_open_permit(self : CircuitBreaker) -> Unit {
  if self.half_open_requests > 0 {
    self.half_open_requests -= 1
  }
}

///|
fn CircuitBreaker::reset(self : CircuitBreaker) -> Unit {
  self.transition_to_closed()
}

///|
fn CircuitBreaker::get_stats(self : CircuitBreaker) -> CircuitBreakerStats {
  {
    state: self.state,
    consecutive_failures: self.consecutive_failures,
    consecutive_successes: self.consecutive_successes,
    total_requests: self.total_requests,
    failed_requests: self.failed_requests,
  }
}

///|
fn CircuitBreaker::open_timeout_elapsed(
  self : CircuitBreaker,
  now_ms : Int,
) -> Bool {
  match self.last_opened_at_ms {
    Some(opened_at_ms) =>
      now_ms - opened_at_ms >= self.config.timeout_seconds * 1000
    None => false
  }
}

///|
fn CircuitBreaker::allow_half_open_probe(self : CircuitBreaker) -> AllowResult {
  if self.half_open_requests < 1 {
    self.half_open_requests += 1
    { allowed: true, used_half_open_permit: true }
  } else {
    { allowed: false, used_half_open_permit: false }
  }
}

///|
fn CircuitBreaker::transition_to_open(
  self : CircuitBreaker,
  now_ms : Int,
) -> Unit {
  self.state = Open
  self.last_opened_at_ms = Some(now_ms)
  self.consecutive_failures = 0
  self.consecutive_successes = 0
}

///|
fn CircuitBreaker::transition_to_half_open(self : CircuitBreaker) -> Unit {
  if self.state != Open {
    return
  }
  self.state = HalfOpen
  self.consecutive_successes = 0
  self.half_open_requests = 0
}

///|
fn CircuitBreaker::transition_to_closed(self : CircuitBreaker) -> Unit {
  self.state = Closed
  self.consecutive_failures = 0
  self.consecutive_successes = 0
  self.total_requests = 0
  self.failed_requests = 0
  self.last_opened_at_ms = None
  self.half_open_requests = 0
}

///|
priv struct ProviderRouteTarget {
  app_type : String
  provider_id : String
  provider_name : String
  enabled : Bool
  provider_type : String?
  api_format : String?
  claude_desktop_mode : String?
  prompt_cache_key : String?
  codex_fast_mode : Bool
  base_url : String?
  api_key : String?
  is_full_url : Bool
  model_mapping : ModelMapping?
  claude_desktop_model_routes : Map[String, ClaudeDesktopModelRoute]
  settings_config : Json?
  notes : String?
}

///|
priv struct ClaudeDesktopModelRoute {
  model : String
  label_override : String?
  supports_1m : Bool?
}

///|
fn ClaudeDesktopModelRoute::new(
  model~ : String,
  label_override? : String? = None,
  supports_1m? : Bool? = None,
) -> ClaudeDesktopModelRoute {
  { model, label_override, supports_1m }
}

///|
fn ClaudeDesktopModelRoute::to_json(self : ClaudeDesktopModelRoute) -> Json {
  let obj : Map[String, Json] = { "model": Json::string(self.model) }
  match self.label_override {
    Some(label) => obj["labelOverride"] = Json::string(label)
    None => ()
  }
  match self.supports_1m {
    Some(value) => obj["supports1m"] = Json::boolean(value)
    None => ()
  }
  Json::object(obj)
}

///|
fn ProviderRouteTarget::new(
  app_type~ : String,
  provider_id~ : String,
  provider_name~ : String,
  enabled? : Bool = true,
  provider_type? : String? = None,
  api_format? : String? = None,
  claude_desktop_mode? : String? = None,
  prompt_cache_key? : String? = None,
  codex_fast_mode? : Bool = false,
  base_url? : String? = None,
  api_key? : String? = None,
  is_full_url? : Bool = false,
  model_mapping? : ModelMapping? = None,
  claude_desktop_model_routes? : Map[String, ClaudeDesktopModelRoute] = Map(
    [],
    capacity=0,
  ),
  settings_config? : Json? = None,
  notes? : String? = None,
) -> ProviderRouteTarget {
  {
    app_type,
    provider_id,
    provider_name,
    enabled,
    provider_type,
    api_format,
    claude_desktop_mode,
    prompt_cache_key,
    codex_fast_mode,
    base_url,
    api_key,
    is_full_url,
    model_mapping,
    claude_desktop_model_routes,
    settings_config,
    notes,
  }
}

///|
fn ProviderRouteTarget::to_json(self : ProviderRouteTarget) -> Json {
  let obj : Map[String, Json] = {
    "appType": Json::string(self.app_type),
    "providerId": Json::string(self.provider_id),
    "providerName": Json::string(self.provider_name),
    "enabled": Json::boolean(self.enabled),
    "providerType": provider_route_optional_string_json(self.provider_type),
    "baseUrl": provider_route_optional_string_json(self.base_url),
    "isFullUrl": Json::boolean(self.is_full_url),
    "modelMapping": provider_route_model_mapping_json(self.model_mapping),
  }
  if self.api_format is Some(api_format) {
    obj["apiFormat"] = Json::string(api_format)
  }
  if self.claude_desktop_mode is Some(mode) {
    obj["claudeDesktopMode"] = Json::string(mode)
  }
  if self.settings_config is Some(settings_config) {
    obj["settingsConfig"] = settings_config
  }
  if self.notes is Some(notes) {
    obj["notes"] = Json::string(notes)
  }
  if !self.claude_desktop_model_routes.is_empty() {
    obj["claudeDesktopModelRoutes"] = claude_desktop_model_routes_json(
      self.claude_desktop_model_routes,
    )
  }
  Json::object(obj)
}

///|
fn ProviderRouteTarget::to_moon_provider_json(
  self : ProviderRouteTarget,
  in_failover_queue : Bool,
  sort_index? : Int? = None,
) -> Json {
  let empty_settings : Map[String, Json] = {}
  let obj : Map[String, Json] = {
    "id": Json::string(self.provider_id),
    "name": Json::string(self.provider_name),
    "appType": Json::string(self.app_type),
    "enabled": Json::boolean(self.enabled),
    "builtIn": Json::boolean(self.is_builtin_route()),
    "isFullUrl": Json::boolean(self.is_full_url),
    "codexFastMode": Json::boolean(self.codex_fast_mode),
    "settingsConfig": self.settings_config.unwrap_or(empty_settings.to_json()),
    "inFailoverQueue": Json::boolean(in_failover_queue),
  }
  if self.base_url is Some(base_url) {
    obj["baseUrl"] = Json::string(base_url)
    obj["websiteUrl"] = Json::string(base_url)
  }
  if self.provider_type is Some(provider_type) {
    obj["providerType"] = Json::string(provider_type)
    obj["category"] = Json::string(provider_type)
  }
  if self.api_format is Some(api_format) {
    obj["apiFormat"] = Json::string(api_format)
  }
  if self.model_mapping is Some(model_mapping) {
    obj["modelMapping"] = model_mapping.to_json()
  }
  if self.notes is Some(notes) {
    obj["notes"] = Json::string(notes)
  }
  if sort_index is Some(sort_index) {
    obj["sortIndex"] = Json::number(sort_index.to_double())
  }
  if self.claude_desktop_mode is Some(_) ||
    !self.claude_desktop_model_routes.is_empty() {
    let meta : Map[String, Json] = {}
    match self.claude_desktop_mode {
      Some(mode) => meta["claudeDesktopMode"] = Json::string(mode)
      None => ()
    }
    if !self.claude_desktop_model_routes.is_empty() {
      meta["claudeDesktopModelRoutes"] = claude_desktop_model_routes_json(
        self.claude_desktop_model_routes,
      )
    }
    obj["meta"] = Json::object(meta)
  }
  Json::object(obj)
}

///|
fn ProviderRouteTarget::is_builtin_route(self : ProviderRouteTarget) -> Bool {
  (
    self.provider_id == "codex-oauth" &&
    (
      self.app_type == "claude" ||
      self.app_type == "claude-desktop" ||
      self.app_type == "codex"
    )
  ) ||
  (self.app_type == "gemini" && self.provider_id == "gemini-api-key")
}

///|
fn claude_desktop_model_routes_json(
  routes : Map[String, ClaudeDesktopModelRoute],
) -> Json {
  let obj : Map[String, Json] = {}
  for route_id in routes.keys() {
    match routes.get(route_id) {
      Some(route) => obj[route_id] = route.to_json()
      None => ()
    }
  }
  Json::object(obj)
}

///|
fn provider_route_optional_string_json(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn provider_route_model_mapping_json(value : ModelMapping?) -> Json {
  match value {
    Some(mapping) => mapping.to_json()
    None => Json::null()
  }
}

///|
priv enum ProviderSelectionError {
  NoProvidersConfigured
  AllProvidersCircuitOpen
} derive(Eq)

///|
fn ProviderSelectionError::to_string(self : ProviderSelectionError) -> String {
  match self {
    NoProvidersConfigured => "no_providers_configured"
    AllProvidersCircuitOpen => "all_providers_circuit_open"
  }
}

///|
priv struct ProviderSelection {
  providers : Array[ProviderRouteTarget]
  error : ProviderSelectionError?
}

///|
priv struct CustomEndpoint {
  url : String
  added_at : Int
  last_used : Int?
}

///|
priv struct ProviderSortUpdate {
  id : String
  sort_index : Int
}

///|
fn CustomEndpoint::new(url : String, added_at : Int) -> CustomEndpoint {
  { url, added_at, last_used: None }
}

///|
fn CustomEndpoint::to_json(self : CustomEndpoint) -> Json {
  let obj : Map[String, Json] = {
    "url": Json::string(self.url),
    "addedAt": Json::number(self.added_at.to_double()),
  }
  if self.last_used is Some(last_used) {
    obj["lastUsed"] = Json::number(last_used.to_double())
  }
  Json::object(obj)
}

///|
priv struct ProviderHealthState {
  is_healthy : Bool
  consecutive_failures : Int
  last_success_at : String?
  last_failure_at : String?
  last_error : String?
  updated_at : String
}

///|
fn ProviderHealthState::new_default(updated_at : String) -> ProviderHealthState {
  {
    is_healthy: true,
    consecutive_failures: 0,
    last_success_at: None,
    last_failure_at: None,
    last_error: None,
    updated_at,
  }
}

///|
fn ProviderHealthState::new_healthy(
  updated_at : String,
  last_failure_at? : String? = None,
) -> ProviderHealthState {
  {
    is_healthy: true,
    consecutive_failures: 0,
    last_success_at: Some(updated_at),
    last_failure_at,
    last_error: None,
    updated_at,
  }
}

///|
fn provider_health_key(app_type : String, provider_id : String) -> String {
  "\{app_type}:\{provider_id}"
}

///|
fn ProviderSelection::ok(
  providers : Array[ProviderRouteTarget],
) -> ProviderSelection {
  { providers, error: None }
}

///|
fn ProviderSelection::err(error : ProviderSelectionError) -> ProviderSelection {
  { providers: [], error: Some(error) }
}

///|
fn ProviderSelection::is_ok(self : ProviderSelection) -> Bool {
  self.error is None
}

///|
priv struct ProviderRouter {
  providers : Map[String, Map[String, ProviderRouteTarget]]
  current_provider_ids : Map[String, String]
  universal_providers : Map[String, Json]
  provider_sort_indices : Map[String, Map[String, Int]]
  custom_endpoints : Map[String, Map[String, Map[String, CustomEndpoint]]]
  failover_queues : Map[String, Array[String]]
  auto_failover_enabled : Map[String, Bool]
  max_retries : Map[String, Int]
  circuit_breakers : Map[String, CircuitBreaker]
  provider_health : Map[String, ProviderHealthState]
  app_circuit_configs : Map[String, CircuitBreakerConfig]
  mut circuit_config : CircuitBreakerConfig
}

///|
fn ProviderRouter::new(
  circuit_config? : CircuitBreakerConfig = CircuitBreakerConfig::default(),
) -> ProviderRouter {
  {
    providers: Map([], capacity=0),
    current_provider_ids: Map([], capacity=0),
    universal_providers: Map([], capacity=0),
    provider_sort_indices: Map([], capacity=0),
    custom_endpoints: Map([], capacity=0),
    failover_queues: Map([], capacity=0),
    auto_failover_enabled: Map([], capacity=0),
    max_retries: Map([], capacity=0),
    circuit_breakers: Map([], capacity=0),
    provider_health: Map([], capacity=0),
    app_circuit_configs: Map([], capacity=0),
    circuit_config,
  }
}

///|
fn ProviderRouter::upsert_provider(
  self : ProviderRouter,
  target : ProviderRouteTarget,
) -> Unit {
  let app_providers = self.providers
    .get(target.app_type)
    .unwrap_or(Map([], capacity=0))
  app_providers.set(target.provider_id, target)
  self.providers.set(target.app_type, app_providers)
}

///|
fn ProviderRouter::set_current_provider(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Unit {
  self.current_provider_ids.set(app_type, provider_id)
}

///|
fn ProviderRouter::set_auto_failover(
  self : ProviderRouter,
  app_type : String,
  enabled : Bool,
) -> Unit {
  self.auto_failover_enabled.set(app_type, enabled)
}

///|
fn ProviderRouter::set_auto_failover_checked(
  self : ProviderRouter,
  app_type : String,
  enabled : Bool,
) -> Bool {
  if !enabled {
    self.auto_failover_enabled.set(app_type, false)
    return true
  }
  guard self.has_configured_app(app_type) else { return false }
  let queue = self.failover_queues.get(app_type).unwrap_or([])
  if queue.is_empty() {
    guard self.current_provider_ids.get(app_type) is Some(provider_id) else {
      return false
    }
    self.add_to_failover_queue(app_type, provider_id)
  }
  self.auto_failover_enabled.set(app_type, true)
  true
}

///|
fn ProviderRouter::set_auto_failover_from_command(
  self : ProviderRouter,
  app_type : String,
  enabled : Bool,
) -> Bool {
  if !enabled {
    self.auto_failover_enabled.set(app_type, false)
    return true
  }
  guard self.has_configured_app(app_type) else { return false }
  let mut auto_added_provider_id : String? = None
  let mut queue = self.ordered_failover_queue(app_type)
  if queue.is_empty() {
    guard self.current_provider_ids.get(app_type) is Some(provider_id) else {
      return false
    }
    self.add_to_failover_queue(app_type, provider_id)
    auto_added_provider_id = Some(provider_id)
    queue = self.ordered_failover_queue(app_type)
  }
  guard queue.length() > 0 else { return false }
  let p1_provider_id = queue[0]
  guard self.provider_by_id(app_type, p1_provider_id) is Some(provider) else {
    if auto_added_provider_id is Some(provider_id) {
      self.remove_from_failover_queue(app_type, provider_id)
    }
    return false
  }
  if provider.provider_type == Some("official") {
    if auto_added_provider_id is Some(provider_id) {
      self.remove_from_failover_queue(app_type, provider_id)
    }
    return false
  }
  self.current_provider_ids.set(app_type, p1_provider_id)
  self.auto_failover_enabled.set(app_type, true)
  true
}

///|
fn ProviderRouter::set_max_retries(
  self : ProviderRouter,
  app_type : String,
  max_retries : Int,
) -> Unit {
  self.max_retries.set(app_type, max_int(max_retries, 0))
}

///|
fn ProviderRouter::max_attempts_for_app(
  self : ProviderRouter,
  app_type : String,
) -> Int {
  if self.auto_failover_enabled.get(app_type).unwrap_or(false) {
    self.max_retries_for_app(app_type) + 1
  } else {
    1
  }
}

///|
fn ProviderRouter::has_configured_app(
  self : ProviderRouter,
  app_type : String,
) -> Bool {
  match self.providers.get(app_type) {
    Some(providers) => !providers.is_empty()
    None => false
  }
}

///|
fn provider_app_is_additive(app_type : String) -> Bool {
  match app_type {
    "opencode" | "openclaw" | "hermes" => true
    _ => false
  }
}

///|
fn ProviderRouter::current_provider_id(
  self : ProviderRouter,
  app_type : String,
) -> String? {
  self.current_provider_ids.get(app_type)
}

///|
fn ProviderRouter::current_provider_for_moon_command(
  self : ProviderRouter,
  app_type : String,
) -> String {
  if provider_app_is_additive(app_type) {
    ""
  } else {
    self.current_provider_ids.get(app_type).unwrap_or("")
  }
}

///|
fn ProviderRouter::providers_moon_json(
  self : ProviderRouter,
  app_type : String,
) -> Json {
  let queue = self.failover_queues.get(app_type).unwrap_or([])
  let obj : Map[String, Json] = {}
  match self.providers.get(app_type) {
    Some(providers) => {
      let provider_ids : Array[String] = []
      for provider_id in providers.keys() {
        provider_ids.push(provider_id)
      }
      provider_ids.sort_by(fn(left, right) {
        guard providers.get(left) is Some(left_provider) else { return 1 }
        guard providers.get(right) is Some(right_provider) else { return -1 }
        provider_moon_sort_compare(
          left_provider,
          self.provider_sort_index(app_type, left),
          right_provider,
          self.provider_sort_index(app_type, right),
        )
      })
      for provider_id in provider_ids {
        guard providers.get(provider_id) is Some(provider) else { continue }
        obj[provider_id] = provider.to_moon_provider_json(
          queue.contains(provider.provider_id),
          sort_index=self.provider_sort_index(app_type, provider_id),
        )
      }
    }
    None => ()
  }
  Json::object(obj)
}

///|
fn provider_moon_sort_compare(
  left : ProviderRouteTarget,
  left_sort_index : Int?,
  right : ProviderRouteTarget,
  right_sort_index : Int?,
) -> Int {
  match (left_sort_index, right_sort_index) {
    (Some(left_index), Some(right_index)) if left_index != right_index =>
      left_index.compare(right_index)
    (Some(_), None) => -1
    (None, Some(_)) => 1
    _ => {
      let by_name = left.provider_name.compare(right.provider_name)
      if by_name != 0 {
        by_name
      } else {
        left.provider_id.compare(right.provider_id)
      }
    }
  }
}

///|
fn ProviderRouter::provider_sort_index(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Int? {
  guard self.provider_sort_indices.get(app_type) is Some(app_sort_indices) else {
    return None
  }
  app_sort_indices.get(provider_id)
}

///|
fn ProviderRouter::ordered_failover_queue(
  self : ProviderRouter,
  app_type : String,
) -> Array[String] {
  let queue : Array[String] = []
  for provider_id in self.failover_queues.get(app_type).unwrap_or([]) {
    queue.push(provider_id)
  }
  queue.sort_by(fn(left, right) {
    let left_index = self.provider_sort_index(app_type, left).unwrap_or(999999)
    let right_index = self
      .provider_sort_index(app_type, right)
      .unwrap_or(999999)
    if left_index != right_index {
      left_index.compare(right_index)
    } else {
      left.compare(right)
    }
  })
  queue
}

///|
fn ProviderRouter::read_live_provider_settings(
  self : ProviderRouter,
  app_type : String,
) -> Json {
  guard self.current_provider_id(app_type) is Some(provider_id) else {
    return Json::object({})
  }
  guard self.provider_by_id(app_type, provider_id) is Some(provider) else {
    return Json::object({})
  }
  provider.settings_config.unwrap_or(Json::object({}))
}

///|
fn ProviderRouter::sync_current_provider_targets(
  self : ProviderRouter,
) -> Array[ProviderRouteTarget] {
  let targets : Array[ProviderRouteTarget] = []
  let app_types : Array[String] = []
  for app_type in self.providers.keys() {
    app_types.push(app_type)
  }
  app_types.sort()
  for app_type in app_types {
    guard self.providers.get(app_type) is Some(app_providers) else { continue }
    if app_providers.is_empty() {
      self.current_provider_ids.remove(app_type)
      continue
    }
    let provider_id = match self.current_provider_ids.get(app_type) {
      Some(current) if app_providers.get(current) is Some(_) => current
      _ => {
        let fallback = self.default_current_provider_id(app_type, app_providers)
        match fallback {
          Some(id) => {
            self.current_provider_ids.set(app_type, id)
            id
          }
          None => {
            self.current_provider_ids.remove(app_type)
            continue
          }
        }
      }
    }
    match app_providers.get(provider_id) {
      Some(provider) => {
        if moon_provider_route_target_has_takeover_placeholder(provider) {
          continue
        }
        targets.push(provider)
      }
      None => ()
    }
  }
  targets
}

///|
fn moon_provider_route_target_has_takeover_placeholder(
  provider : ProviderRouteTarget,
) -> Bool {
  match provider.settings_config {
    Some(settings) => moon_settings_has_proxy_managed_placeholder(settings)
    None => false
  }
}

///|
fn ProviderRouter::default_current_provider_id(
  self : ProviderRouter,
  app_type : String,
  app_providers : Map[String, ProviderRouteTarget],
) -> String? {
  let ids : Array[String] = []
  for id in app_providers.keys() {
    ids.push(id)
  }
  if ids.is_empty() {
    return None
  }
  ids.sort_by(fn(left, right) {
    guard app_providers.get(left) is Some(left_provider) else { return 1 }
    guard app_providers.get(right) is Some(right_provider) else { return -1 }
    provider_moon_sort_compare(
      left_provider,
      self.provider_sort_index(app_type, left),
      right_provider,
      self.provider_sort_index(app_type, right),
    )
  })
  ids.get(0)
}

///|
fn ProviderRouter::live_provider_ids_json(
  self : ProviderRouter,
  app_type : String,
) -> Json {
  let ids = self.stream_check_provider_ids(app_type, false)
  Json::array(ids.map(fn(id) { Json::string(id) }))
}

///|
fn ProviderRouter::live_provider_json(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Json {
  match self.provider_by_id(app_type, provider_id) {
    Some(provider) => provider.settings_config.unwrap_or(provider.to_json())
    None => Json::null()
  }
}

///|
fn ProviderRouter::import_live_providers(
  self : ProviderRouter,
  app_type : String,
) -> Int {
  self.stream_check_provider_ids(app_type, false).length()
}

///|
fn ProviderRouter::universal_providers_json(self : ProviderRouter) -> Json {
  let obj : Map[String, Json] = {}
  let ids : Array[String] = []
  for id in self.universal_providers.keys() {
    ids.push(id)
  }
  ids.sort()
  for id in ids {
    guard self.universal_providers.get(id) is Some(provider) else { continue }
    obj[id] = provider
  }
  Json::object(obj)
}

///|
fn ProviderRouter::universal_provider_json(
  self : ProviderRouter,
  id : String,
) -> Json {
  self.universal_providers.get(id).unwrap_or(Json::null())
}

///|
fn ProviderRouter::upsert_universal_provider(
  self : ProviderRouter,
  provider : Json,
) -> Bool {
  guard provider is Object(obj) else { return false }
  guard json_string_from_map(obj, "id") is Some(id) && !id.trim().is_empty() else {
    return false
  }
  self.universal_providers.set(id.trim().to_owned(), provider)
  true
}

///|
fn ProviderRouter::delete_universal_provider(
  self : ProviderRouter,
  id : String,
) -> Bool {
  let existed = self.universal_providers.get(id) is Some(_)
  self.universal_providers.remove(id)
  for app_type in ["claude", "codex", "gemini"] {
    ignore(
      self.delete_provider(app_type, universal_app_provider_id(app_type, id)),
    )
  }
  existed
}

///|
fn ProviderRouter::sync_universal_provider(
  self : ProviderRouter,
  id : String,
) -> Bool {
  guard self.universal_providers.get(id) is Some(provider) else { return false }
  guard provider is Object(obj) else { return false }
  for app_type in ["claude", "codex", "gemini"] {
    if universal_provider_app_enabled(obj, app_type) {
      self.upsert_provider(universal_provider_route_target(obj, app_type, id))
    } else {
      ignore(
        self.delete_provider(app_type, universal_app_provider_id(app_type, id)),
      )
    }
  }
  true
}

///|
fn universal_provider_route_target(
  obj : Map[String, Json],
  app_type : String,
  id : String,
) -> ProviderRouteTarget {
  let provider_id = universal_app_provider_id(app_type, id)
  let provider_name = json_string_from_map(obj, "name").unwrap_or(id)
  let provider_type = json_string_from_map(obj, "providerType")
  let base_url = json_string_from_map(obj, "baseUrl")
  let api_key = json_string_from_map(obj, "apiKey")
  let settings_config = universal_provider_settings_config(obj, app_type)
  ProviderRouteTarget::new(
    app_type~,
    provider_id~,
    provider_name~,
    provider_type~,
    api_format=Some(universal_provider_api_format(app_type)),
    base_url~,
    api_key~,
    settings_config=Some(settings_config),
  )
}

///|
fn universal_app_provider_id(app_type : String, id : String) -> String {
  "\{universal_provider_app_slug(app_type)}-\{id}"
}

///|
fn universal_provider_app_slug(app_type : String) -> String {
  match app_type {
    "claude" => "universal-claude"
    "codex" => "universal-codex"
    "gemini" => "universal-gemini"
    _ => "universal-\{app_type}"
  }
}

///|
fn universal_provider_api_format(app_type : String) -> String {
  match app_type {
    "claude" => "anthropic"
    "codex" => "openai_responses"
    "gemini" => "gemini_native"
    _ => app_type
  }
}

///|
fn universal_provider_app_enabled(
  obj : Map[String, Json],
  app_type : String,
) -> Bool {
  guard obj.get("apps") is Some(Object(apps)) else { return false }
  match apps.get(app_type) {
    Some(true) => true
    Some(false) => false
    _ => false
  }
}

///|
fn universal_provider_settings_config(
  obj : Map[String, Json],
  app_type : String,
) -> Json {
  let settings : Map[String, Json] = {}
  match json_string_from_map(obj, "baseUrl") {
    Some(base_url) => settings["baseUrl"] = Json::string(base_url)
    None => ()
  }
  match json_string_from_map(obj, "apiKey") {
    Some(api_key) => settings["apiKey"] = Json::string(api_key)
    None => ()
  }
  match json_string_from_map(obj, "providerType") {
    Some(provider_type) =>
      settings["providerType"] = Json::string(provider_type)
    None => ()
  }
  match obj.get("models") {
    Some(Object(models)) =>
      match models.get(app_type) {
        Some(model_config) => settings["models"] = model_config
        None => ()
      }
    _ => ()
  }
  Json::object(settings)
}

///|
fn ProviderRouter::update_providers_sort_order(
  self : ProviderRouter,
  app_type : String,
  updates : Array[ProviderSortUpdate],
) -> Bool {
  guard self.providers.get(app_type) is Some(app_providers) else { return true }
  let app_sort_indices = self.provider_sort_indices
    .get(app_type)
    .unwrap_or(Map([], capacity=0))
  for update in updates {
    guard app_providers.get(update.id) is Some(_) else { continue }
    app_sort_indices.set(update.id, max_int(update.sort_index, 0))
  }
  self.providers.set(app_type, app_providers)
  self.provider_sort_indices.set(app_type, app_sort_indices)
  true
}

///|
fn ProviderRouter::delete_provider(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Bool {
  guard self.providers.get(app_type) is Some(app_providers) else {
    return false
  }
  guard app_providers.get(provider_id) is Some(_) else { return false }
  if !provider_app_is_additive(app_type) &&
    self.current_provider_ids.get(app_type) == Some(provider_id) {
    return false
  }
  app_providers.remove(provider_id)
  self.providers.set(app_type, app_providers)
  self.remove_from_failover_queue(app_type, provider_id)
  self.circuit_breakers.remove(circuit_key(app_type, provider_id))
  if self.provider_sort_indices.get(app_type) is Some(app_sort_indices) {
    app_sort_indices.remove(provider_id)
    self.provider_sort_indices.set(app_type, app_sort_indices)
  }
  if self.current_provider_ids.get(app_type) == Some(provider_id) {
    let mut next_provider_id : String? = None
    for candidate_id in app_providers.keys() {
      next_provider_id = Some(candidate_id)
      break
    }
    match next_provider_id {
      Some(next_provider_id) =>
        self.current_provider_ids.set(app_type, next_provider_id)
      None => self.current_provider_ids.remove(app_type)
    }
  }
  true
}

///|
fn ProviderRouter::remove_provider_from_live_config(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Bool {
  guard provider_app_is_additive(app_type) else { return false }
  guard self.provider_by_id(app_type, provider_id) is Some(_) else {
    return false
  }
  self.remove_from_failover_queue(app_type, provider_id)
  if self.current_provider_ids.get(app_type) == Some(provider_id) {
    match self.providers.get(app_type) {
      Some(app_providers) =>
        for candidate_id in app_providers.keys() {
          if candidate_id != provider_id {
            self.current_provider_ids.set(app_type, candidate_id)
            return true
          }
        }
      None => ()
    }
    self.current_provider_ids.remove(app_type)
  }
  true
}

///|
fn ProviderRouter::custom_endpoints_json(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Json {
  guard self.provider_by_id(app_type, provider_id) is Some(_) else {
    return Json::array([])
  }
  guard self.custom_endpoints.get(app_type) is Some(app_endpoints) else {
    return Json::array([])
  }
  guard app_endpoints.get(provider_id) is Some(provider_endpoints) else {
    return Json::array([])
  }
  let endpoints : Array[CustomEndpoint] = []
  for url in provider_endpoints.keys() {
    guard provider_endpoints.get(url) is Some(endpoint) else { continue }
    endpoints.push(endpoint)
  }
  endpoints.sort_by(fn(left, right) { right.added_at.compare(left.added_at) })
  Json::array(endpoints.map(fn(endpoint) { endpoint.to_json() }))
}

///|
fn ProviderRouter::add_custom_endpoint(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
  url : String,
  now_ms? : Int = @async.now().to_int(),
) -> Bool {
  guard normalize_custom_endpoint_url(url) is Some(normalized) else {
    return false
  }
  let app_endpoints = self.custom_endpoints
    .get(app_type)
    .unwrap_or(Map([], capacity=0))
  let provider_endpoints = app_endpoints
    .get(provider_id)
    .unwrap_or(Map([], capacity=0))
  provider_endpoints.set(normalized, CustomEndpoint::new(normalized, now_ms))
  app_endpoints.set(provider_id, provider_endpoints)
  self.custom_endpoints.set(app_type, app_endpoints)
  true
}

///|
fn ProviderRouter::remove_custom_endpoint(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
  url : String,
) -> Unit {
  guard normalize_custom_endpoint_url(url) is Some(normalized) else { return }
  guard self.custom_endpoints.get(app_type) is Some(app_endpoints) else {
    return
  }
  guard app_endpoints.get(provider_id) is Some(provider_endpoints) else {
    return
  }
  provider_endpoints.remove(normalized)
  app_endpoints.set(provider_id, provider_endpoints)
  self.custom_endpoints.set(app_type, app_endpoints)
}

///|
fn ProviderRouter::update_endpoint_last_used(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
  url : String,
  now_ms? : Int = @async.now().to_int(),
) -> Unit {
  guard normalize_custom_endpoint_url(url) is Some(normalized) else { return }
  guard self.custom_endpoints.get(app_type) is Some(app_endpoints) else {
    return
  }
  guard app_endpoints.get(provider_id) is Some(provider_endpoints) else {
    return
  }
  guard provider_endpoints.get(normalized) is Some(endpoint) else { return }
  provider_endpoints.set(normalized, { ..endpoint, last_used: Some(now_ms) })
  app_endpoints.set(provider_id, provider_endpoints)
  self.custom_endpoints.set(app_type, app_endpoints)
}

///|
fn normalize_custom_endpoint_url(url : String) -> String? {
  let mut normalized = url.trim().to_owned()
  while normalized.has_suffix("/") {
    normalized = normalized[:normalized.length() - 1].to_owned()
  }
  if normalized.is_empty() {
    None
  } else {
    Some(normalized)
  }
}

///|
fn ProviderRouter::auto_failover_enabled_for_app(
  self : ProviderRouter,
  app_type : String,
) -> Bool {
  self.auto_failover_enabled.get(app_type).unwrap_or(false)
}

///|
fn ProviderRouter::max_retries_for_app(
  self : ProviderRouter,
  app_type : String,
) -> Int {
  self.max_retries
  .get(app_type)
  .unwrap_or(moon_proxy_max_retries_default(app_type))
}

///|
fn ProviderRouter::set_failover_queue(
  self : ProviderRouter,
  app_type : String,
  provider_ids : Array[String],
) -> Unit {
  let deduped : Array[String] = []
  for provider_id in provider_ids {
    if !deduped.contains(provider_id) {
      deduped.push(provider_id)
    }
  }
  self.failover_queues.set(app_type, deduped)
}

///|
fn ProviderRouter::add_to_failover_queue(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Unit {
  let queue = self.failover_queues.get(app_type).unwrap_or([])
  if !queue.contains(provider_id) {
    queue.push(provider_id)
  }
  self.failover_queues.set(app_type, queue)
}

///|
fn ProviderRouter::remove_from_failover_queue(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Unit {
  let queue = self.failover_queues.get(app_type).unwrap_or([])
  let next : Array[String] = []
  for queued_provider_id in queue {
    if queued_provider_id != provider_id {
      next.push(queued_provider_id)
    }
  }
  self.failover_queues.set(app_type, next)
  self.reset_provider_breaker(provider_id, app_type)
}

///|
fn ProviderRouter::failover_queue_json(
  self : ProviderRouter,
  app_type : String,
) -> Json {
  let queue = self.ordered_failover_queue(app_type)
  let rows : Array[Json] = []
  for provider_id in queue {
    guard self.provider_by_id(app_type, provider_id) is Some(provider) else {
      continue
    }
    let sort_index = match self.provider_sort_index(app_type, provider_id) {
      Some(index) => Json::number(index.to_double())
      None => Json::null()
    }
    let row : Map[String, Json] = {
      "providerId": Json::string(provider.provider_id),
      "providerName": Json::string(provider.provider_name),
      "sortIndex": sort_index,
    }
    if provider.notes is Some(notes) {
      row["providerNotes"] = Json::string(notes)
    }
    rows.push(row.to_json())
  }
  Json::array(rows)
}

///|
fn ProviderRouter::available_failover_providers_json(
  self : ProviderRouter,
  app_type : String,
) -> Json {
  let queue = self.failover_queues.get(app_type).unwrap_or([])
  let rows : Array[Json] = []
  match self.providers.get(app_type) {
    Some(providers) =>
      for provider_id in providers.keys() {
        guard providers.get(provider_id) is Some(provider) else { continue }
        if !queue.contains(provider.provider_id) {
          rows.push(provider.to_moon_provider_json(false))
        }
      }
    None => ()
  }
  Json::array(rows)
}

///|
fn ProviderRouter::stream_check_provider_ids(
  self : ProviderRouter,
  app_type : String,
  proxy_targets_only : Bool,
) -> Array[String] {
  let ids : Array[String] = []
  if proxy_targets_only {
    match self.current_provider_ids.get(app_type) {
      Some(provider_id) if !ids.contains(provider_id) => ids.push(provider_id)
      _ => ()
    }
    for provider_id in self.ordered_failover_queue(app_type) {
      if !ids.contains(provider_id) {
        ids.push(provider_id)
      }
    }
  } else {
    match self.providers.get(app_type) {
      Some(providers) =>
        for provider_id in providers.keys() {
          ids.push(provider_id)
        }
      None => ()
    }
    ids.sort()
  }
  ids
}

///|
fn ProviderRouter::select_providers(
  self : ProviderRouter,
  app_type : String,
  now_ms? : Int = @async.now().to_int(),
) -> ProviderSelection {
  if self.auto_failover_enabled.get(app_type).unwrap_or(false) {
    self.select_failover_queue(app_type, now_ms)
  } else {
    self.select_current_provider(app_type)
  }
}

///|
fn ProviderRouter::allow_provider_request(
  self : ProviderRouter,
  provider_id : String,
  app_type : String,
  now_ms? : Int = @async.now().to_int(),
) -> AllowResult {
  self.breaker_for(app_type, provider_id).allow_request(now_ms~)
}

///|
fn ProviderRouter::record_result(
  self : ProviderRouter,
  provider_id : String,
  app_type : String,
  used_half_open_permit : Bool,
  success : Bool,
  now_ms? : Int = @async.now().to_int(),
) -> Unit {
  let breaker = self.breaker_for(app_type, provider_id)
  if success {
    breaker.record_success(used_half_open_permit)
    self.record_provider_health_success(
      provider_id,
      app_type,
      now_ms.to_string(),
    )
  } else {
    breaker.record_failure(used_half_open_permit, now_ms~)
    self.record_provider_health_failure(
      provider_id,
      app_type,
      "request_failed",
      now_ms.to_string(),
    )
  }
}

///|
fn ProviderRouter::release_permit_neutral(
  self : ProviderRouter,
  provider_id : String,
  app_type : String,
  used_half_open_permit : Bool,
) -> Unit {
  if used_half_open_permit {
    self.breaker_for(app_type, provider_id).release_half_open_permit()
  }
}

///|
fn ProviderRouter::reset_provider_breaker(
  self : ProviderRouter,
  provider_id : String,
  app_type : String,
) -> Unit {
  self.breaker_for(app_type, provider_id).reset()
  self.record_provider_health_success(
    provider_id,
    app_type,
    @async.now().to_int().to_string(),
  )
}

///|
fn ProviderRouter::reset_provider_breaker_and_restore(
  self : ProviderRouter,
  provider_id : String,
  app_type : String,
  app_enabled~ : Bool,
  proxy_running~ : Bool,
) -> Bool {
  self.reset_provider_breaker(provider_id, app_type)
  if !app_enabled ||
    !proxy_running ||
    !self.auto_failover_enabled_for_app(app_type) {
    return false
  }
  guard self.current_provider_ids.get(app_type) is Some(current_id) else {
    return false
  }
  let queue = self.ordered_failover_queue(app_type)
  guard failover_queue_index(Some(queue), provider_id) is Some(restored_order) else {
    return false
  }
  guard failover_queue_index(Some(queue), current_id) is Some(current_order) else {
    return false
  }
  if restored_order < current_order {
    self.current_provider_ids.set(app_type, provider_id)
    true
  } else {
    false
  }
}

///|
fn ProviderRouter::update_all_configs(
  self : ProviderRouter,
  config : CircuitBreakerConfig,
) -> Unit {
  self.circuit_config = config
  for app_type in ["claude", "codex", "gemini"] {
    self.app_circuit_configs.set(app_type, config)
  }
  for breaker in self.circuit_breakers.values() {
    breaker.update_config(config)
  }
}

///|
fn ProviderRouter::update_app_configs(
  self : ProviderRouter,
  app_type : String,
  config : CircuitBreakerConfig,
) -> Unit {
  self.app_circuit_configs.set(app_type, config)
  let prefix = "\{app_type}:"
  for key in self.circuit_breakers.keys() {
    if key.has_prefix(prefix) {
      guard self.circuit_breakers.get(key) is Some(breaker) else { continue }
      breaker.update_config(config)
    }
  }
}

///|
fn ProviderRouter::circuit_config_for_app(
  self : ProviderRouter,
  app_type : String,
) -> CircuitBreakerConfig {
  self.app_circuit_configs
  .get(app_type)
  .unwrap_or(moon_proxy_circuit_config_default(app_type))
}

///|
fn ProviderRouter::get_circuit_breaker_stats(
  self : ProviderRouter,
  provider_id : String,
  app_type : String,
) -> CircuitBreakerStats? {
  self.circuit_breakers
  .get(circuit_key(app_type, provider_id))
  .map(fn(breaker) { breaker.get_stats() })
}

///|
fn ProviderRouter::provider_health_json(
  self : ProviderRouter,
  provider_id : String,
  app_type : String,
  updated_at : String,
) -> Json {
  let stats = self.get_circuit_breaker_stats(provider_id, app_type)
  let health = self.provider_health_state(provider_id, app_type, updated_at)
  let is_circuit_open = match stats {
    Some(stats) => stats.state == Open
    None => false
  }
  let is_healthy = health.is_healthy && !is_circuit_open
  let last_error = match stats {
    Some(stats) if stats.state == Open => Json::string("circuit_open")
    _ => provider_health_optional_string_json(health.last_error)
  }
  {
    "provider_id": Json::string(provider_id),
    "app_type": Json::string(app_type),
    "is_healthy": Json::boolean(is_healthy),
    "consecutive_failures": Json::number(
      health.consecutive_failures.to_double(),
    ),
    "last_success_at": provider_health_optional_string_json(
      health.last_success_at,
    ),
    "last_failure_at": provider_health_optional_string_json(
      health.last_failure_at,
    ),
    "last_error": last_error,
    "updated_at": Json::string(health.updated_at),
  }.to_json()
}

///|
fn ProviderRouter::record_provider_health_success(
  self : ProviderRouter,
  provider_id : String,
  app_type : String,
  updated_at : String,
) -> Unit {
  let key = provider_health_key(app_type, provider_id)
  let last_failure_at = match self.provider_health.get(key) {
    Some(state) => state.last_failure_at
    None => None
  }
  self.provider_health.set(
    key,
    ProviderHealthState::new_healthy(updated_at, last_failure_at~),
  )
}

///|
fn ProviderRouter::record_provider_health_failure(
  self : ProviderRouter,
  provider_id : String,
  app_type : String,
  error : String,
  updated_at : String,
) -> Unit {
  let key = provider_health_key(app_type, provider_id)
  let previous = self.provider_health.get(key)
  let consecutive_failures = previous
    .map(fn(state) { state.consecutive_failures })
    .unwrap_or(0) +
    1
  let last_success_at = match previous {
    Some(state) => state.last_success_at
    None => None
  }
  self.provider_health.set(key, {
    is_healthy: consecutive_failures < self.failure_threshold_for_app(app_type),
    consecutive_failures,
    last_success_at,
    last_failure_at: Some(updated_at),
    last_error: Some(error),
    updated_at,
  })
}

///|
fn ProviderRouter::provider_health_state(
  self : ProviderRouter,
  provider_id : String,
  app_type : String,
  updated_at : String,
) -> ProviderHealthState {
  let key = provider_health_key(app_type, provider_id)
  match self.provider_health.get(key) {
    Some(state) => state
    None =>
      match self.get_circuit_breaker_stats(provider_id, app_type) {
        Some(stats) if stats.state == Open =>
          {
            is_healthy: false,
            consecutive_failures: stats.consecutive_failures,
            last_success_at: None,
            last_failure_at: None,
            last_error: Some("circuit_open"),
            updated_at,
          }
        _ => ProviderHealthState::new_default(updated_at)
      }
  }
}

///|
fn ProviderRouter::failure_threshold_for_app(
  self : ProviderRouter,
  app_type : String,
) -> Int {
  self.circuit_config_for_app(app_type).failure_threshold
}

///|
fn provider_health_optional_string_json(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn ProviderRouter::route_stats_json(self : ProviderRouter) -> Json {
  let rows : Array[Json] = []
  for key in self.circuit_breakers.keys() {
    guard self.circuit_breakers.get(key) is Some(breaker) else { continue }
    rows.push(
      { "key": Json::string(key), "circuit": breaker.get_stats().to_json() }.to_json(),
    )
  }
  Json::array(rows)
}

///|
fn provider_router_prometheus_metrics(router : ProviderRouter) -> String {
  let out = StringBuilder::new()
  provider_router_metric_header(
    out, "gauge", "moongate_provider_configured", "Configured provider route entries.",
  )
  provider_router_metric_header(
    out, "gauge", "moongate_provider_enabled", "Configured provider enabled flags.",
  )
  provider_router_metric_header(
    out, "gauge", "moongate_provider_current", "Current provider selection by app.",
  )
  provider_router_metric_header(
    out, "gauge", "moongate_provider_healthy", "Provider health including circuit breaker state.",
  )
  for app_type in router.providers.keys() {
    guard router.providers.get(app_type) is Some(providers) else { continue }
    let current_provider_id = router.current_provider_ids.get(app_type)
    for provider_id in providers.keys() {
      guard providers.get(provider_id) is Some(provider) else { continue }
      let labels = provider_router_labels(app_type, provider_id)
      provider_router_metric_sample(
        out, "moongate_provider_configured", labels, 1.0,
      )
      provider_router_metric_sample(
        out,
        "moongate_provider_enabled",
        labels,
        if provider.enabled {
          1.0
        } else {
          0.0
        },
      )
      provider_router_metric_sample(
        out,
        "moongate_provider_current",
        labels,
        match current_provider_id {
          Some(current) if current == provider_id => 1.0
          _ => 0.0
        },
      )
      let health = router.provider_health_state(
        provider_id, app_type, "metrics",
      )
      let stats = router.get_circuit_breaker_stats(provider_id, app_type)
      let is_circuit_open = match stats {
        Some(stats) => stats.state == Open
        None => false
      }
      provider_router_metric_sample(
        out,
        "moongate_provider_healthy",
        labels,
        if health.is_healthy && !is_circuit_open {
          1.0
        } else {
          0.0
        },
      )
    }
  }
  provider_router_metric_header(
    out, "gauge", "moongate_provider_auto_failover_enabled", "Auto-failover enabled state by app.",
  )
  for app_type in router.auto_failover_enabled.keys() {
    guard router.auto_failover_enabled.get(app_type) is Some(enabled) else {
      continue
    }
    provider_router_metric_sample(
      out,
      "moongate_provider_auto_failover_enabled",
      provider_router_app_labels(app_type),
      if enabled {
        1.0
      } else {
        0.0
      },
    )
  }
  provider_router_metric_header(
    out, "gauge", "moongate_provider_circuit_open", "Provider circuit breaker open state.",
  )
  provider_router_metric_header(
    out, "gauge", "moongate_provider_circuit_half_open", "Provider circuit breaker half-open state.",
  )
  provider_router_metric_header(
    out, "gauge", "moongate_provider_circuit_consecutive_failures", "Provider circuit breaker consecutive failures.",
  )
  provider_router_metric_header(
    out, "gauge", "moongate_provider_circuit_consecutive_successes", "Provider circuit breaker consecutive successes.",
  )
  provider_router_metric_header(
    out, "counter", "moongate_provider_circuit_requests_total", "Provider circuit breaker observed requests.",
  )
  provider_router_metric_header(
    out, "counter", "moongate_provider_circuit_failed_requests_total", "Provider circuit breaker observed failed requests.",
  )
  for key in router.circuit_breakers.keys() {
    guard router.circuit_breakers.get(key) is Some(breaker) else { continue }
    let labels = provider_router_key_labels(key)
    let stats = breaker.get_stats()
    provider_router_metric_sample(
      out,
      "moongate_provider_circuit_open",
      labels,
      if stats.state == Open {
        1.0
      } else {
        0.0
      },
    )
    provider_router_metric_sample(
      out,
      "moongate_provider_circuit_half_open",
      labels,
      if stats.state == HalfOpen {
        1.0
      } else {
        0.0
      },
    )
    provider_router_metric_sample(
      out,
      "moongate_provider_circuit_consecutive_failures",
      labels,
      stats.consecutive_failures.to_double(),
    )
    provider_router_metric_sample(
      out,
      "moongate_provider_circuit_consecutive_successes",
      labels,
      stats.consecutive_successes.to_double(),
    )
    provider_router_metric_sample(
      out,
      "moongate_provider_circuit_requests_total",
      labels,
      stats.total_requests.to_double(),
    )
    provider_router_metric_sample(
      out,
      "moongate_provider_circuit_failed_requests_total",
      labels,
      stats.failed_requests.to_double(),
    )
  }
  out.to_string()
}

///|
fn ProviderRouter::select_current_provider(
  self : ProviderRouter,
  app_type : String,
) -> ProviderSelection {
  guard self.current_provider_ids.get(app_type) is Some(provider_id) else {
    return ProviderSelection::err(NoProvidersConfigured)
  }
  match self.provider_by_id(app_type, provider_id) {
    Some(provider) => ProviderSelection::ok([provider])
    _ => ProviderSelection::err(NoProvidersConfigured)
  }
}

///|
fn ProviderRouter::select_failover_queue(
  self : ProviderRouter,
  app_type : String,
  now_ms : Int,
) -> ProviderSelection {
  let queue = self.ordered_failover_queue(app_type)
  let providers : Array[ProviderRouteTarget] = []
  let mut circuit_open_count = 0
  for provider_id in queue {
    guard self.provider_by_id(app_type, provider_id) is Some(provider) else {
      continue
    }
    let breaker = self.breaker_for(app_type, provider.provider_id)
    if breaker.is_available(now_ms~) {
      providers.push(provider)
    } else {
      circuit_open_count += 1
    }
  }
  if !providers.is_empty() {
    return ProviderSelection::ok(providers)
  }
  if !queue.is_empty() && circuit_open_count == queue.length() {
    ProviderSelection::err(AllProvidersCircuitOpen)
  } else {
    ProviderSelection::err(NoProvidersConfigured)
  }
}

///|
fn ProviderRouter::provider_by_id(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> ProviderRouteTarget? {
  match self.providers.get(app_type) {
    Some(app_providers) => app_providers.get(provider_id)
    None => None
  }
}

///|
fn ProviderRouter::breaker_for(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> CircuitBreaker {
  let key = circuit_key(app_type, provider_id)
  match self.circuit_breakers.get(key) {
    Some(breaker) => breaker
    None => {
      let config = self.app_circuit_configs
        .get(app_type)
        .unwrap_or(self.circuit_config)
      let breaker = CircuitBreaker::new(config~)
      self.circuit_breakers.set(key, breaker)
      breaker
    }
  }
}

///|
fn circuit_key(app_type : String, provider_id : String) -> String {
  "\{app_type}:\{provider_id}"
}

///|
fn provider_router_app_labels(app_type : String) -> String {
  "app_type=\"\{prometheus_label_escape(app_type)}\""
}

///|
fn provider_router_labels(app_type : String, provider_id : String) -> String {
  "\{provider_router_app_labels(app_type)},provider_id=\"\{prometheus_label_escape(provider_id)}\""
}

///|
fn provider_router_key_labels(key : String) -> String {
  let parts : Array[String] = []
  for part in key.split(":") {
    parts.push(part.to_owned())
  }
  if parts.length() >= 2 {
    let app_type = parts[0]
    let provider_id = parts[1:].join(":")
    provider_router_labels(app_type, provider_id)
  } else {
    provider_router_labels("", key)
  }
}

///|
fn prometheus_label_escape(value : String) -> String {
  let out = StringBuilder::new()
  for c in value {
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      _ => out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn provider_router_metric_header(
  out : StringBuilder,
  kind : String,
  name : String,
  help : String,
) -> Unit {
  out.write_string("# HELP \{name} \{help}\n")
  out.write_string("# TYPE \{name} \{kind}\n")
}

///|
fn provider_router_metric_sample(
  out : StringBuilder,
  name : String,
  labels : String,
  value : Double,
) -> Unit {
  out.write_string("\{name}{\{labels}} \{value}\n")
}

///|
fn failover_queue_index(queue : Array[String]?, provider_id : String) -> Int? {
  match queue {
    Some(queue) => {
      for i in 0..<queue.length() {
        if queue[i] == provider_id {
          return Some(i)
        }
      }
      None
    }
    None => None
  }
}
