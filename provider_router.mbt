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
}

///|
pub fn ProviderRouteTarget::new(
  app_type~ : String,
  provider_id~ : String,
  provider_name~ : String,
  enabled? : Bool = true,
) -> ProviderRouteTarget {
  { app_type, provider_id, provider_name, enabled }
}

///|
pub fn ProviderRouteTarget::to_json(self : ProviderRouteTarget) -> Json {
  {
    "appType": Json::string(self.app_type),
    "providerId": Json::string(self.provider_id),
    "providerName": Json::string(self.provider_name),
    "enabled": Json::boolean(self.enabled),
  }.to_json()
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
  failover_queues : Map[String, Array[String]]
  auto_failover_enabled : Map[String, Bool]
  circuit_breakers : Map[String, CircuitBreaker]
  mut circuit_config : CircuitBreakerConfig
}

///|
pub fn ProviderRouter::new(
  circuit_config? : CircuitBreakerConfig = CircuitBreakerConfig::default(),
) -> ProviderRouter {
  {
    providers: Map([], capacity=0),
    current_provider_ids: Map([], capacity=0),
    failover_queues: Map([], capacity=0),
    auto_failover_enabled: Map([], capacity=0),
    circuit_breakers: Map([], capacity=0),
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
    Some(provider) if provider.enabled => ProviderSelection::ok([provider])
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
    if !provider.enabled {
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
      let breaker = CircuitBreaker::new(config=self.circuit_config)
      self.circuit_breakers.set(key, breaker)
      breaker
    }
  }
}

///|
fn circuit_key(app_type : String, provider_id : String) -> String {
  "\{app_type}:\{provider_id}"
}
