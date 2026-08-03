///|
fn provider_routing_key(app_type : String, provider_id : String) -> String {
  "\{app_type}:\{provider_id}"
}

///|
fn provider_routing_session_key(
  app_type : String,
  session_key : String,
) -> String {
  "\{app_type}:\{session_key}"
}

///|
fn routing_session_key_digest(raw_session_key : String) -> String {
  @crypto.bytes_to_hex_string(
    @crypto.sha256(
      @encoding/utf8.encode("moongate.routing-session.v1:\{raw_session_key}"),
    ),
  )
}

///|
fn routing_session_canary_slot(session_key : String) -> Int {
  let digest = @crypto.sha256(@encoding/utf8.encode(session_key))
  (digest[0].to_int() * 256 + digest[1].to_int()) % 10_000
}

///|
fn ProviderRouter::routing_policy_uses_canary(
  self : ProviderRouter,
  policy : @routing.RoutingPolicyV1,
  session_key? : String? = None,
) -> Bool {
  let slot = match session_key {
    Some(value) => routing_session_canary_slot(value)
    None => {
      let counter = self.routing_canary_counters
        .get(policy.app_type)
        .unwrap_or(0)
      self.routing_canary_counters.set(policy.app_type, counter + 1)
      (counter * 7919 + policy.revision * 1049) % 10_000
    }
  }
  slot < policy.canary_traffic_basis_points
}

///|
fn ProviderRouter::provider_inflight_count(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Int {
  self.provider_inflight
  .get(provider_routing_key(app_type, provider_id))
  .unwrap_or(0)
}

///|
fn ProviderRouter::total_inflight(self : ProviderRouter) -> Int {
  let mut total = 0
  for count in self.provider_inflight.values() {
    total += count
  }
  total
}

///|
fn ProviderRouter::increment_provider_inflight(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Unit {
  let key = provider_routing_key(app_type, provider_id)
  self.provider_inflight.set(
    key,
    self.provider_inflight.get(key).unwrap_or(0) + 1,
  )
}

///|
fn ProviderRouter::decrement_provider_inflight(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Unit {
  let key = provider_routing_key(app_type, provider_id)
  let next = self.provider_inflight.get(key).unwrap_or(0) - 1
  if next > 0 {
    self.provider_inflight.set(key, next)
  } else {
    self.provider_inflight.remove(key)
  }
}

///|
fn ProviderRouter::set_provider_quota_exhausted(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
  exhausted : Bool,
) -> Unit {
  let key = provider_routing_key(app_type, provider_id)
  self.provider_quota_exhausted.set(key, exhausted)
  self.provider_quota_evidence_supported.set(key, true)
}

///|
fn ProviderRouter::provider_concurrency_limit(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Int {
  match self.active_routing_policies.get(app_type) {
    Some(policy) => policy.concurrency_limits.get(provider_id).unwrap_or(0)
    None => 0
  }
}

///|
fn ProviderRouter::provider_at_capacity(
  self : ProviderRouter,
  app_type : String,
  provider_id : String,
) -> Bool {
  let limit = self.provider_concurrency_limit(app_type, provider_id)
  limit > 0 && self.provider_inflight_count(app_type, provider_id) >= limit
}

///|
fn ProviderRouter::routing_pool_ids(
  self : ProviderRouter,
  app_type : String,
) -> Array[String] {
  let queued = self.ordered_failover_queue(app_type)
  if !queued.is_empty() {
    return queued
  }
  match self.current_provider_ids.get(app_type) {
    Some(provider_id) => [provider_id]
    None => []
  }
}

///|
fn ProviderRouter::routing_candidates(
  self : ProviderRouter,
  policy : @routing.RoutingPolicyV1,
  now_ms : Int,
) -> Array[@routing.ProviderCandidateV1] {
  let candidates : Array[@routing.ProviderCandidateV1] = []
  let provider_ids = self.routing_pool_ids(policy.app_type)
  for index, provider_id in provider_ids {
    guard self.provider_by_id(policy.app_type, provider_id) is Some(provider) else {
      continue
    }
    let key = provider_routing_key(policy.app_type, provider_id)
    let healthy = match self.provider_health.get(key) {
      Some(state) => state.is_healthy
      None => true
    }
    let health_observed_at_ms = self.provider_health_observed_at_ms.get(key)
    let health_fresh = match health_observed_at_ms {
      Some(observed) => {
        let age = moongate_epoch_ms() - observed
        age >= 0L && age <= 300_000L
      }
      None => false
    }
    let circuit_open = !self
      .breaker_for(policy.app_type, provider_id)
      .is_available(now_ms~)
    candidates.push({
      provider_id,
      priority: self
      .provider_sort_index(policy.app_type, provider_id)
      .unwrap_or(index),
      weight: policy.weights.get(provider_id).unwrap_or(1),
      inflight: self.provider_inflight_count(policy.app_type, provider_id),
      concurrency_limit: policy.concurrency_limits.get(provider_id).unwrap_or(0),
      enabled: provider.enabled,
      compatible: provider.app_type == policy.app_type,
      healthy,
      circuit_open,
      quota_exhausted: self.provider_quota_exhausted.get(key).unwrap_or(false),
      health_evidence_supported: health_observed_at_ms is Some(_),
      health_observed_at_ms,
      health_fresh,
      credential_evidence_supported: true,
      credentials_available: provider.credential_state() != "missing",
      model_evidence_supported: true,
      model_supported: true,
      protocol_evidence_supported: true,
      protocol_supported: provider.app_type == policy.app_type,
      budget_evidence_supported: self.provider_quota_evidence_supported
      .get(key)
      .unwrap_or(false),
      budget_available: !self.provider_quota_exhausted.get(key).unwrap_or(false),
      capacity_evidence_supported: true,
      capacity_available: policy.concurrency_limits
      .get(provider_id)
      .unwrap_or(0) ==
      0 ||
      self.provider_inflight_count(policy.app_type, provider_id) <
      policy.concurrency_limits.get(provider_id).unwrap_or(0),
    })
  }
  candidates
}

///|
fn ProviderRouter::routing_error_for_decision(
  _self : ProviderRouter,
  decision : @routing.RoutingDecisionV1,
) -> ProviderSelectionError {
  let mut saw_circuit = false
  let mut saw_capacity = false
  let mut saw_quota = false
  for review in decision.reviews {
    saw_circuit = saw_circuit || review.reasons.contains("circuit-open")
    saw_capacity = saw_capacity || review.reasons.contains("concurrency-limit")
    saw_quota = saw_quota || review.reasons.contains("quota-exhausted")
  }
  if saw_capacity {
    NoProviderCapacity
  } else if saw_quota {
    ProviderQuotaExhausted
  } else if saw_circuit {
    AllProvidersCircuitOpen
  } else {
    NoProvidersConfigured
  }
}

///|
fn ProviderRouter::ordered_providers_for_decision(
  self : ProviderRouter,
  app_type : String,
  selected_provider_id : String,
  decision : @routing.RoutingDecisionV1,
) -> Array[ProviderRouteTarget] {
  let ordered : Array[ProviderRouteTarget] = []
  match self.provider_by_id(app_type, selected_provider_id) {
    Some(provider) => ordered.push(provider)
    None => ()
  }
  for provider_id in self.routing_pool_ids(app_type) {
    if provider_id == selected_provider_id {
      continue
    }
    let mut eligible = false
    for review in decision.reviews {
      if review.provider_id == provider_id {
        eligible = review.eligible
        break
      }
    }
    if !eligible {
      continue
    }
    match self.provider_by_id(app_type, provider_id) {
      Some(provider) => ordered.push(provider)
      None => ()
    }
  }
  ordered
}

///|
fn ProviderRouter::select_with_routing_policy(
  self : ProviderRouter,
  policy : @routing.RoutingPolicyV1,
  now_ms : Int,
  session_key? : String? = None,
) -> ProviderSelection {
  let state = self.routing_smooth_states
    .get(policy.app_type)
    .unwrap_or(@routing.empty_smooth_state())
  let binding_key = session_key.map(fn(value) {
    provider_routing_session_key(policy.app_type, value)
  })
  let sticky_provider_id = match binding_key {
    Some(key) => self.routing_session_bindings.get(key)
    None => None
  }
  let (decision, next_state) = @routing.select(
    policy,
    self.routing_candidates(policy, now_ms),
    state,
    shadow=false,
    sticky_provider_id~,
    session_key_present=session_key is Some(_),
    decided_at_ms=moongate_epoch_ms(),
  ) catch {
    _ => return ProviderSelection::err(NoProvidersConfigured)
  }
  self.routing_smooth_states.set(policy.app_type, next_state)
  self.routing_last_active_decisions.set(policy.app_type, decision)
  guard decision.selected_provider_id is Some(provider_id) else {
    return ProviderSelection::err(self.routing_error_for_decision(decision))
  }
  match binding_key {
    Some(key) => {
      if self.routing_session_bindings.length() >= 2048 &&
        self.routing_session_bindings.get(key) is None {
        self.routing_session_bindings.clear()
      }
      self.routing_session_bindings.set(key, provider_id)
    }
    None => ()
  }
  ProviderSelection::ok(
    self.ordered_providers_for_decision(policy.app_type, provider_id, decision),
  )
}

///|
fn ProviderRouter::active_routing_requires_session(
  self : ProviderRouter,
  app_type : String,
) -> Bool {
  match self.active_routing_policies.get(app_type) {
    Some(policy) => policy.mode == @routing.SessionSticky
    None => false
  }
}

///|
fn ProviderRouter::provider_chain_after_activation(
  self : ProviderRouter,
  app_type : String,
  active_provider_id : String?,
  now_ms? : Int = @async.now().to_int(),
) -> ProviderSelection {
  guard active_provider_id is Some(active_provider_id) else {
    return self.select_providers(app_type, now_ms~)
  }
  let policy = self.active_routing_policies
    .get(app_type)
    .unwrap_or(@routing.default_priority_policy(app_type, moongate_epoch_ms()))
  let candidates = self.routing_candidates(policy, now_ms)
  let ordered : Array[ProviderRouteTarget] = []
  match self.provider_by_id(app_type, active_provider_id) {
    Some(provider) => ordered.push(provider)
    None => ()
  }
  for candidate in candidates {
    if candidate.provider_id == active_provider_id ||
      !@routing.candidate_review(candidate).eligible {
      continue
    }
    match self.provider_by_id(app_type, candidate.provider_id) {
      Some(provider) => ordered.push(provider)
      None => ()
    }
  }
  if ordered.is_empty() {
    ProviderSelection::err(NoProvidersConfigured)
  } else {
    ProviderSelection::ok(ordered)
  }
}

///|
fn ProviderRouter::observe_shadow_routing(
  self : ProviderRouter,
  app_type : String,
  now_ms : Int,
  session_key? : String? = None,
) -> Unit {
  guard self.routing_policy_drafts.get(app_type) is Some(policy) else { return }
  if self.active_routing_policies.get(app_type) == Some(policy) {
    return
  }
  let state = self.routing_shadow_smooth_states
    .get(app_type)
    .unwrap_or(@routing.empty_smooth_state())
  let (decision, next_state) = @routing.select(
    policy,
    self.routing_candidates(policy, now_ms),
    state,
    shadow=true,
    session_key_present=session_key is Some(_),
    decided_at_ms=moongate_epoch_ms(),
  ) catch {
    _ => return
  }
  self.routing_shadow_smooth_states.set(app_type, next_state)
  self.routing_last_shadow_decisions.set(app_type, decision)
  self.routing_shadow_counts.set(
    app_type,
    self.routing_shadow_counts.get(app_type).unwrap_or(0) + 1,
  )
  if self.routing_shadow_first_observed_at_ms.get(app_type) is None {
    self.routing_shadow_first_observed_at_ms.set(
      app_type,
      decision.decided_at_ms,
    )
  }
}

///|
fn ProviderRouter::configure_routing_policy(
  self : ProviderRouter,
  app_type~ : String,
  policy_id~ : String,
  mode~ : @routing.RoutingMode,
  weights~ : Map[String, Int],
  concurrency_limits~ : Map[String, Int],
  minimum_shadow_decisions? : Int = 20,
  minimum_shadow_window_ms? : Int64 = 300_000L,
  canary_traffic_basis_points? : Int = 500,
  rollback_error_rate_milli? : Int = 100,
  rollback_p95_latency_ms? : Int = 30_000,
  rollback_minimum_requests? : Int = 20,
  configured_at_ms~ : Int64,
) -> Result[@routing.RoutingPolicyV1, String] {
  let revision = self.routing_policy_drafts
    .get(app_type)
    .map(fn(policy) { policy.revision + 1 })
    .unwrap_or(
      self.active_routing_policies
      .get(app_type)
      .map(fn(policy) { policy.revision + 1 })
      .unwrap_or(1),
    )
  let result : Result[@routing.RoutingPolicyV1, Error] = moon_result(() => {
    @routing.policy(
      policy_id~,
      app_type~,
      revision~,
      mode~,
      weights~,
      concurrency_limits~,
      minimum_shadow_decisions~,
      minimum_shadow_window_ms~,
      canary_traffic_basis_points~,
      rollback_error_rate_milli~,
      rollback_p95_latency_ms~,
      rollback_minimum_requests~,
      configured_at_ms~,
    )
  })
  match result {
    Err(error) => Err(error.to_string())
    Ok(policy) => {
      self.routing_policy_drafts.set(app_type, policy)
      self.routing_shadow_counts.set(app_type, 0)
      self.routing_shadow_first_observed_at_ms.remove(app_type)
      self.routing_shadow_smooth_states.remove(app_type)
      self.routing_last_shadow_decisions.remove(app_type)
      Ok(policy)
    }
  }
}

///|
fn ProviderRouter::activate_routing_policy(
  self : ProviderRouter,
  app_type~ : String,
  expected_revision~ : Int,
  actor_principal~ : @capability.PrincipalRefV1,
  authority_decision~ : @capability.AuthorityDecisionRefV1,
  authority_checked_at~ : String,
  receipt_id~ : String,
  recorded_at_ms~ : Int64,
) -> Result[@routing.RoutingPolicyActivationReceiptV1, String] {
  guard authority_decision.is_fresh_for(actor_principal, authority_checked_at) else {
    return Err("a fresh authority decision for the actor principal is required")
  }
  guard self.routing_policy_drafts.get(app_type) is Some(policy) else {
    return Err("no shadow routing policy is configured")
  }
  if policy.revision != expected_revision {
    return Err("routing policy revision conflict")
  }
  if self.routing_shadow_counts.get(app_type).unwrap_or(0) <
    policy.minimum_shadow_decisions {
    return Err(
      "the routing policy minimum shadow decision count has not been met",
    )
  }
  guard self.routing_last_shadow_decisions.get(app_type) is Some(decision) &&
    decision.selected_provider_id is Some(_) else {
    return Err("the latest shadow decision has no eligible provider")
  }
  guard self.routing_shadow_first_observed_at_ms.get(app_type)
    is Some(first_observed_at_ms) else {
    return Err("the routing policy shadow evidence window is unavailable")
  }
  if recorded_at_ms - first_observed_at_ms < policy.minimum_shadow_window_ms {
    return Err(
      "the routing policy minimum shadow evidence window has not elapsed",
    )
  }
  let previous = self.active_routing_policies.get(app_type)
  match previous {
    Some(value) => self.previous_routing_policies.set(app_type, value)
    None =>
      self.previous_routing_policies.set(
        app_type,
        @routing.default_priority_policy(app_type, recorded_at_ms),
      )
  }
  self.active_routing_policies.set(app_type, policy)
  self.routing_smooth_states.remove(app_type)
  let receipt : @routing.RoutingPolicyActivationReceiptV1 = {
    contract_id: @routing.routing_activation_receipt_contract_v1(),
    receipt_id,
    action: @routing.Activate,
    app_type,
    actor_principal: actor_principal.canonical_text(),
    authority_decision_id: authority_decision.decision_id(),
    authority_decision_digest: authority_decision.digest().text(),
    policy_id: policy.policy_id,
    policy_revision: policy.revision,
    previous_policy_id: previous.map(fn(value) { value.policy_id }),
    previous_policy_revision: previous.map(fn(value) { value.revision }),
    activation_scope: @routing.BoundedCanary,
    canary_traffic_basis_points: policy.canary_traffic_basis_points,
    minimum_shadow_decisions: policy.minimum_shadow_decisions,
    minimum_shadow_window_ms: policy.minimum_shadow_window_ms,
    rollback_error_rate_milli: policy.rollback_error_rate_milli,
    rollback_p95_latency_ms: policy.rollback_p95_latency_ms,
    rollback_minimum_requests: policy.rollback_minimum_requests,
    recorded_at_ms,
  }
  self.append_routing_receipt(receipt)
  Ok(receipt)
}

///|
fn ProviderRouter::rollback_routing_policy(
  self : ProviderRouter,
  app_type~ : String,
  actor_principal~ : @capability.PrincipalRefV1,
  authority_decision~ : @capability.AuthorityDecisionRefV1,
  authority_checked_at~ : String,
  receipt_id~ : String,
  recorded_at_ms~ : Int64,
) -> Result[@routing.RoutingPolicyActivationReceiptV1, String] {
  guard authority_decision.is_fresh_for(actor_principal, authority_checked_at) else {
    return Err("a fresh authority decision for the actor principal is required")
  }
  guard self.active_routing_policies.get(app_type) is Some(current) else {
    return Err("no active routing policy is configured")
  }
  guard self.previous_routing_policies.get(app_type) is Some(previous) else {
    return Err("no previous routing policy is available")
  }
  self.active_routing_policies.set(app_type, previous)
  self.previous_routing_policies.set(app_type, current)
  self.routing_smooth_states.remove(app_type)
  let receipt : @routing.RoutingPolicyActivationReceiptV1 = {
    contract_id: @routing.routing_activation_receipt_contract_v1(),
    receipt_id,
    action: @routing.Rollback,
    app_type,
    actor_principal: actor_principal.canonical_text(),
    authority_decision_id: authority_decision.decision_id(),
    authority_decision_digest: authority_decision.digest().text(),
    policy_id: previous.policy_id,
    policy_revision: previous.revision,
    previous_policy_id: Some(current.policy_id),
    previous_policy_revision: Some(current.revision),
    activation_scope: @routing.RollbackScope,
    canary_traffic_basis_points: previous.canary_traffic_basis_points,
    minimum_shadow_decisions: previous.minimum_shadow_decisions,
    minimum_shadow_window_ms: previous.minimum_shadow_window_ms,
    rollback_error_rate_milli: previous.rollback_error_rate_milli,
    rollback_p95_latency_ms: previous.rollback_p95_latency_ms,
    rollback_minimum_requests: previous.rollback_minimum_requests,
    recorded_at_ms,
  }
  self.append_routing_receipt(receipt)
  Ok(receipt)
}

///|
fn ProviderRouter::append_routing_receipt(
  self : ProviderRouter,
  receipt : @routing.RoutingPolicyActivationReceiptV1,
) -> Unit {
  self.routing_activation_receipts.push(receipt)
  if self.routing_activation_receipts.length() > 100 {
    ignore(self.routing_activation_receipts.remove(0))
  }
}

///|
fn routing_optional_policy_json(policy : @routing.RoutingPolicyV1?) -> Json {
  match policy {
    Some(value) => value.to_json()
    None => Json::null()
  }
}

///|
fn routing_optional_decision_json(
  decision : @routing.RoutingDecisionV1?,
) -> Json {
  match decision {
    Some(value) => value.to_json()
    None => Json::null()
  }
}

///|
fn ProviderRouter::routing_policy_state_json(
  self : ProviderRouter,
  app_type : String,
) -> Json {
  let receipts : Array[Json] = []
  for receipt in self.routing_activation_receipts {
    if receipt.app_type == app_type {
      receipts.push(receipt.to_json())
    }
  }
  {
    "contractId": Json::string(@routing.routing_policy_contract_v1()),
    "appType": Json::string(app_type),
    "draft": routing_optional_policy_json(
      self.routing_policy_drafts.get(app_type),
    ),
    "active": routing_optional_policy_json(
      self.active_routing_policies.get(app_type),
    ),
    "previous": routing_optional_policy_json(
      self.previous_routing_policies.get(app_type),
    ),
    "shadowDecisionCount": Json::number(
      self.routing_shadow_counts.get(app_type).unwrap_or(0).to_double(),
    ),
    "lastShadowDecision": routing_optional_decision_json(
      self.routing_last_shadow_decisions.get(app_type),
    ),
    "lastActiveDecision": routing_optional_decision_json(
      self.routing_last_active_decisions.get(app_type),
    ),
    "activationReceipts": Json::array(receipts),
  }.to_json()
}

///|
fn ProviderRouter::circuit_state_counts(self : ProviderRouter) -> (Int, Int) {
  let mut open_count = 0
  let mut half_open_count = 0
  for breaker in self.circuit_breakers.values() {
    match breaker.get_stats().state {
      Open => open_count += 1
      HalfOpen => half_open_count += 1
      Closed => ()
    }
  }
  (open_count, half_open_count)
}

///|
fn ProviderRouter::active_policy_observations(
  self : ProviderRouter,
) -> Array[@telemetry.ActivePolicyObservationV1] {
  let observations : Array[@telemetry.ActivePolicyObservationV1] = []
  let app_types = self.active_routing_policies.keys().to_array()
  app_types.sort()
  for app_type in app_types {
    guard self.active_routing_policies.get(app_type) is Some(policy) else {
      continue
    }
    observations.push({
      app_type,
      policy_id: policy.policy_id,
      policy_revision: policy.revision,
    })
  }
  observations
}
