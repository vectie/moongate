///|
pub enum CircuitState {
  Closed
  Open
  HalfOpen
} derive(Eq)

///|
pub fn CircuitState::to_string(self : CircuitState) -> String {
  match self {
    Closed => "closed"
    Open => "open"
    HalfOpen => "half_open"
  }
}

///|
pub struct CircuitBreakerConfig {
  failure_threshold : Int
  success_threshold : Int
  timeout_seconds : Int
  error_rate_threshold : Double
  min_requests : Int
}

///|
pub fn CircuitBreakerConfig::default() -> CircuitBreakerConfig {
  {
    failure_threshold: 4,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  }
}

///|
pub struct AllowResult {
  allowed : Bool
  used_half_open_permit : Bool
}

///|
pub struct CircuitBreakerStats {
  state : CircuitState
  consecutive_failures : Int
  consecutive_successes : Int
  total_requests : Int
  failed_requests : Int
}

///|
pub fn CircuitBreakerStats::to_json(self : CircuitBreakerStats) -> Json {
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
pub struct CircuitBreaker {
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
pub fn CircuitBreaker::new(
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
pub fn CircuitBreaker::update_config(
  self : CircuitBreaker,
  config : CircuitBreakerConfig,
) -> Unit {
  self.config = config
}

///|
pub fn CircuitBreaker::is_available(
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
pub fn CircuitBreaker::allow_request(
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
pub fn CircuitBreaker::record_success(
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
pub fn CircuitBreaker::record_failure(
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
pub fn CircuitBreaker::release_half_open_permit(self : CircuitBreaker) -> Unit {
  if self.half_open_requests > 0 {
    self.half_open_requests -= 1
  }
}

///|
pub fn CircuitBreaker::reset(self : CircuitBreaker) -> Unit {
  self.transition_to_closed()
}

///|
pub fn CircuitBreaker::get_stats(self : CircuitBreaker) -> CircuitBreakerStats {
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
pub struct ProviderRouteTarget {
  app_type : String
  provider_id : String
  provider_name : String
  enabled : Bool
  provider_type : String?
  api_format : String?
  prompt_cache_key : String?
  codex_fast_mode : Bool
  base_url : String?
  api_key : String?
  is_full_url : Bool
  model_mapping : ModelMapping?
  claude_desktop_model_routes : Map[String, ClaudeDesktopModelRoute]
  settings_config : Json?
}

///|
pub struct ClaudeDesktopModelRoute {
  model : String
  label_override : String?
  supports_1m : Bool?
}

///|
pub fn ClaudeDesktopModelRoute::new(
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
pub fn ProviderRouteTarget::new(
  app_type~ : String,
  provider_id~ : String,
  provider_name~ : String,
  enabled? : Bool = true,
  provider_type? : String? = None,
  api_format? : String? = None,
  prompt_cache_key? : String? = None,
  codex_fast_mode? : Bool = true,
  base_url? : String? = None,
  api_key? : String? = None,
  is_full_url? : Bool = false,
  model_mapping? : ModelMapping? = None,
  claude_desktop_model_routes? : Map[String, ClaudeDesktopModelRoute] = Map(
    [],
    capacity=0,
  ),
  settings_config? : Json? = None,
) -> ProviderRouteTarget {
  {
    app_type,
    provider_id,
    provider_name,
    enabled,
    provider_type,
    api_format,
    prompt_cache_key,
    codex_fast_mode,
    base_url,
    api_key,
    is_full_url,
    model_mapping,
    claude_desktop_model_routes,
    settings_config,
  }
}

///|
pub fn ProviderRouteTarget::to_json(self : ProviderRouteTarget) -> Json {
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
  if self.settings_config is Some(settings_config) {
    obj["settingsConfig"] = settings_config
  }
  if !self.claude_desktop_model_routes.is_empty() {
    obj["claudeDesktopModelRoutes"] = claude_desktop_model_routes_json(
      self.claude_desktop_model_routes,
    )
  }
  Json::object(obj)
}

///|
fn ProviderRouteTarget::to_ccs_provider_json(
  self : ProviderRouteTarget,
  in_failover_queue : Bool,
  sort_index? : Int? = None,
) -> Json {
  let empty_settings : Map[String, Json] = {}
  let obj : Map[String, Json] = {
    "id": Json::string(self.provider_id),
    "name": Json::string(self.provider_name),
    "settingsConfig": self.settings_config.unwrap_or(empty_settings.to_json()),
    "inFailoverQueue": Json::boolean(in_failover_queue),
  }
  if self.base_url is Some(base_url) {
    obj["websiteUrl"] = Json::string(base_url)
  }
  if self.provider_type is Some(provider_type) {
    obj["category"] = Json::string(provider_type)
  }
  if sort_index is Some(sort_index) {
    obj["sortIndex"] = Json::number(sort_index.to_double())
  }
  if !self.claude_desktop_model_routes.is_empty() {
    obj["meta"] = {
      "claudeDesktopModelRoutes": claude_desktop_model_routes_json(
        self.claude_desktop_model_routes,
      ),
    }.to_json()
  }
  Json::object(obj)
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
pub enum ProviderSelectionError {
  NoProvidersConfigured
  AllProvidersCircuitOpen
} derive(Eq)

///|
pub fn ProviderSelectionError::to_string(
  self : ProviderSelectionError,
) -> String {
  match self {
    NoProvidersConfigured => "no_providers_configured"
    AllProvidersCircuitOpen => "all_providers_circuit_open"
  }
}

///|
pub struct ProviderSelection {
  providers : Array[ProviderRouteTarget]
  error : ProviderSelectionError?
}

///|
struct CustomEndpoint {
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
pub fn ProviderSelection::ok(
  providers : Array[ProviderRouteTarget],
) -> ProviderSelection {
  { providers, error: None }
}

///|
pub fn ProviderSelection::err(
  error : ProviderSelectionError,
) -> ProviderSelection {
  { providers: [], error: Some(error) }
}

///|
pub fn ProviderSelection::is_ok(self : ProviderSelection) -> Bool {
  self.error is None
}

///|
pub struct ProviderRouter {
  providers : Map[String, Map[String, ProviderRouteTarget]]
  current_provider_ids : Map[String, String]
  priv universal_providers : Map[String, Json]
  priv provider_sort_indices : Map[String, Map[String, Int]]
  custom_endpoints : Map[String, Map[String, Map[String, CustomEndpoint]]]
  failover_queues : Map[String, Array[String]]
  auto_failover_enabled : Map[String, Bool]
  max_retries : Map[String, Int]
  circuit_breakers : Map[String, CircuitBreaker]
  priv app_circuit_configs : Map[String, CircuitBreakerConfig]
  mut circuit_config : CircuitBreakerConfig
}

///|
pub fn ProviderRouter::new(
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
    app_circuit_configs: Map([], capacity=0),
    circuit_config,
  }
}

///|
pub fn ProviderRouter::upsert_provider(
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
pub fn ProviderRouter::set_current_provider(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Unit {
  self.current_provider_ids.set(app_type, provider_id)
}

///|
pub fn ProviderRouter::set_auto_failover(
  self : ProviderRouter,
  app_type : String,
  enabled : Bool,
) -> Unit {
  self.auto_failover_enabled.set(app_type, enabled)
}

///|
fn ProviderRouter::set_auto_failover_ccs(
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
pub fn ProviderRouter::set_max_retries(
  self : ProviderRouter,
  app_type : String,
  max_retries : Int,
) -> Unit {
  self.max_retries.set(app_type, max_int(max_retries, 0))
}

///|
pub fn ProviderRouter::max_attempts_for_app(
  self : ProviderRouter,
  app_type : String,
) -> Int {
  if self.auto_failover_enabled.get(app_type).unwrap_or(false) {
    self.max_retries.get(app_type).unwrap_or(3) + 1
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
fn ProviderRouter::current_provider_id(
  self : ProviderRouter,
  app_type : String,
) -> String? {
  self.current_provider_ids.get(app_type)
}

///|
fn ProviderRouter::providers_ccs_json(
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
        provider_ccs_sort_compare(
          left_provider,
          self.provider_sort_index(app_type, left),
          right_provider,
          self.provider_sort_index(app_type, right),
        )
      })
      for provider_id in provider_ids {
        guard providers.get(provider_id) is Some(provider) else { continue }
        obj[provider_id] = provider.to_ccs_provider_json(
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
fn provider_ccs_sort_compare(
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
        if ccs_provider_route_target_has_takeover_placeholder(provider) {
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
fn ccs_provider_route_target_has_takeover_placeholder(
  provider : ProviderRouteTarget,
) -> Bool {
  match provider.settings_config {
    Some(settings) => ccs_settings_has_proxy_managed_placeholder(settings)
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
    provider_ccs_sort_compare(
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
  self.max_retries.get(app_type).unwrap_or(3)
}

///|
pub fn ProviderRouter::set_failover_queue(
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
  let queue = self.failover_queues.get(app_type).unwrap_or([])
  let rows : Array[Json] = []
  for index, provider_id in queue {
    guard self.provider_by_id(app_type, provider_id) is Some(provider) else {
      continue
    }
    rows.push(
      {
        "providerId": Json::string(provider.provider_id),
        "providerName": Json::string(provider.provider_name),
        "sortIndex": Json::number(index.to_double()),
      }.to_json(),
    )
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
          rows.push(provider.to_ccs_provider_json(false))
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
    for provider_id in self.failover_queues.get(app_type).unwrap_or([]) {
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
pub fn ProviderRouter::select_providers(
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
pub fn ProviderRouter::allow_provider_request(
  self : ProviderRouter,
  provider_id : String,
  app_type : String,
  now_ms? : Int = @async.now().to_int(),
) -> AllowResult {
  self.breaker_for(app_type, provider_id).allow_request(now_ms~)
}

///|
pub fn ProviderRouter::record_result(
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
  } else {
    breaker.record_failure(used_half_open_permit, now_ms~)
  }
}

///|
pub fn ProviderRouter::release_permit_neutral(
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
pub fn ProviderRouter::reset_provider_breaker(
  self : ProviderRouter,
  provider_id : String,
  app_type : String,
) -> Unit {
  self.breaker_for(app_type, provider_id).reset()
}

///|
pub fn ProviderRouter::update_all_configs(
  self : ProviderRouter,
  config : CircuitBreakerConfig,
) -> Unit {
  self.circuit_config = config
  for breaker in self.circuit_breakers.values() {
    breaker.update_config(config)
  }
}

///|
pub fn ProviderRouter::update_app_configs(
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
pub fn ProviderRouter::get_circuit_breaker_stats(
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
  let is_healthy = match stats {
    Some(stats) => stats.state != Open
    None => true
  }
  let consecutive_failures = match stats {
    Some(stats) => stats.consecutive_failures
    None => 0
  }
  let last_error = match stats {
    Some(stats) if stats.state == Open => Json::string("circuit_open")
    _ => Json::null()
  }
  {
    "provider_id": Json::string(provider_id),
    "app_type": Json::string(app_type),
    "is_healthy": Json::boolean(is_healthy),
    "consecutive_failures": Json::number(consecutive_failures.to_double()),
    "last_success_at": Json::null(),
    "last_failure_at": Json::null(),
    "last_error": last_error,
    "updated_at": Json::string(updated_at),
  }.to_json()
}

///|
pub fn ProviderRouter::route_stats_json(self : ProviderRouter) -> Json {
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
  let queue = self.failover_queues.get(app_type).unwrap_or([])
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
