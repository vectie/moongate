///|
const MOONGATE_PROVIDER_STORE_FILE = "providers.json"

///|
fn moon_provider_store_path() -> String {
  @pathx.join(moon_app_config_dir(), MOONGATE_PROVIDER_STORE_FILE)
}

///|
async fn ProxyService::save_provider_store(
  self : ProxyService,
  path? : String = moon_provider_store_path(),
) -> Unit raise Error {
  let parent = @pathx.dirname(path)
  if !parent.is_empty() && parent != "." {
    @fsx.make_directory(parent, recursive=true, exists_ok=true)
  }
  atomic_write_store_file(
    path,
    self.moon_export_providers_json(include_secrets=true).stringify(indent=2) +
    "\n",
  )
}

///|
async fn ProxyService::load_provider_store(
  self : ProxyService,
  path? : String = moon_provider_store_path(),
) -> Unit raise Error {
  if !@fsx.exists_as_file(path) {
    return
  }
  let parsed = @json.parse(@fsx.read_file(path))
  match self.moon_apply_import_providers(parsed) {
    Ok(_) => ()
    Err(message) =>
      raise Failure::Failure("Invalid MoonGate provider store: \{message}")
  }
}

///|
async fn ProxyService::persist_provider_store_or_error(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Bool {
  self.save_provider_store() catch {
    error => {
      moongate_write_json_error(
        w,
        @status.InternalServerError,
        "moongate_provider_store_write_failed",
        "Failed to persist MoonGate providers: \{error}",
      )
      return false
    }
  }
  true
}

///|
fn provider_store_origin(row : Map[String, Json]) -> String {
  json_string_from_map(row, "origin").unwrap_or("user")
}

///|
fn ProviderRouter::all_custom_endpoints_json(self : ProviderRouter) -> Json {
  let apps : Map[String, Json] = {}
  for app_type, app_endpoints in self.custom_endpoints {
    let providers : Map[String, Json] = {}
    for provider_id in app_endpoints.keys() {
      providers[provider_id] = self.custom_endpoints_json(app_type, provider_id)
    }
    apps[app_type] = Json::object(providers)
  }
  Json::object(apps)
}

///|
fn ProviderHealthState::store_json(self : ProviderHealthState) -> Json {
  {
    "isHealthy": Json::boolean(self.is_healthy),
    "consecutiveFailures": Json::number(self.consecutive_failures.to_double()),
    "lastSuccessAt": provider_health_optional_string_json(self.last_success_at),
    "lastFailureAt": provider_health_optional_string_json(self.last_failure_at),
    "lastError": provider_health_optional_string_json(self.last_error),
    "updatedAt": Json::string(self.updated_at),
  }.to_json()
}

///|
fn ProviderRouter::provider_health_store_json(self : ProviderRouter) -> Json {
  let apps : Map[String, Json] = {}
  for app_type in moon_suite_app_types() {
    let providers : Map[String, Json] = {}
    match self.providers.get(app_type) {
      Some(app_providers) =>
        for provider_id in app_providers.keys() {
          let key = provider_health_key(app_type, provider_id)
          match self.provider_health.get(key) {
            Some(state) => providers[provider_id] = state.store_json()
            None => ()
          }
        }
      None => ()
    }
    if !providers.is_empty() {
      apps[app_type] = Json::object(providers)
    }
  }
  Json::object(apps)
}

///|
fn routing_policy_map_store_json(
  policies : Map[String, @routing.RoutingPolicyV1],
) -> Json {
  let obj : Map[String, Json] = {}
  for app_type, policy in policies {
    obj[app_type] = policy.to_json()
  }
  Json::object(obj)
}

///|
fn routing_decision_map_store_json(
  decisions : Map[String, @routing.RoutingDecisionV1],
) -> Json {
  let obj : Map[String, Json] = {}
  for app_type, decision in decisions {
    obj[app_type] = decision.to_json()
  }
  Json::object(obj)
}

///|
fn routing_smooth_map_store_json(
  states : Map[String, @routing.SmoothStateV1],
) -> Json {
  let obj : Map[String, Json] = {}
  for app_type, state in states {
    obj[app_type] = state.to_json()
  }
  Json::object(obj)
}

///|
fn routing_int_map_store_json(values : Map[String, Int]) -> Json {
  let obj : Map[String, Json] = {}
  for key, value in values {
    obj[key] = Json::number(value.to_double())
  }
  Json::object(obj)
}

///|
fn routing_int64_map_store_json(values : Map[String, Int64]) -> Json {
  let obj : Map[String, Json] = {}
  for key, value in values {
    obj[key] = Json::number(value.to_double())
  }
  Json::object(obj)
}

///|
fn ProviderRouter::routing_policy_store_json(self : ProviderRouter) -> Json {
  {
    "contractId": Json::string("moongate.routing-policy-store.v1"),
    "drafts": routing_policy_map_store_json(self.routing_policy_drafts),
    "active": routing_policy_map_store_json(self.active_routing_policies),
    "previous": routing_policy_map_store_json(self.previous_routing_policies),
    "activeSmoothState": routing_smooth_map_store_json(
      self.routing_smooth_states,
    ),
    "shadowSmoothState": routing_smooth_map_store_json(
      self.routing_shadow_smooth_states,
    ),
    "shadowCounts": routing_int_map_store_json(self.routing_shadow_counts),
    "shadowFirstObservedAtMs": routing_int64_map_store_json(
      self.routing_shadow_first_observed_at_ms,
    ),
    "lastShadowDecisions": routing_decision_map_store_json(
      self.routing_last_shadow_decisions,
    ),
    "lastActiveDecisions": routing_decision_map_store_json(
      self.routing_last_active_decisions,
    ),
    "activationReceipts": Json::array(
      self.routing_activation_receipts.map(fn(receipt) { receipt.to_json() }),
    ),
  }.to_json()
}

///|
fn routing_policy_from_store(value : Json) -> @routing.RoutingPolicyV1? {
  Some(@json.from_json(value)) catch {
    _ => None
  }
}

///|
fn routing_decision_from_store(value : Json) -> @routing.RoutingDecisionV1? {
  Some(@json.from_json(value)) catch {
    _ => None
  }
}

///|
fn routing_smooth_state_from_store(value : Json) -> @routing.SmoothStateV1? {
  Some(@json.from_json(value)) catch {
    _ => None
  }
}

///|
fn routing_receipt_from_store(
  value : Json,
) -> @routing.RoutingPolicyActivationReceiptV1? {
  Some(@json.from_json(value)) catch {
    _ => None
  }
}

///|
fn apply_import_routing_policy_map(
  target : Map[String, @routing.RoutingPolicyV1],
  value : Json,
) -> Unit {
  guard value is Object(rows) else { return }
  for app_type, policy_json in rows {
    match routing_policy_from_store(policy_json) {
      Some(policy) if policy.contract_id ==
        @routing.routing_policy_contract_v1() &&
        policy.app_type == app_type => target[app_type] = policy
      _ => ()
    }
  }
}

///|
fn apply_import_routing_decision_map(
  target : Map[String, @routing.RoutingDecisionV1],
  value : Json,
) -> Unit {
  guard value is Object(rows) else { return }
  for app_type, decision_json in rows {
    match routing_decision_from_store(decision_json) {
      Some(decision) if decision.app_type == app_type =>
        target[app_type] = decision
      _ => ()
    }
  }
}

///|
fn apply_import_routing_smooth_map(
  target : Map[String, @routing.SmoothStateV1],
  value : Json,
) -> Unit {
  guard value is Object(rows) else { return }
  for app_type, state_json in rows {
    match routing_smooth_state_from_store(state_json) {
      Some(state) => target[app_type] = state
      None => ()
    }
  }
}

///|
fn ProviderRouter::apply_import_routing_policy_store(
  self : ProviderRouter,
  value : Json,
) -> Unit {
  guard value is Object(store) else { return }
  match store.get("contractId") {
    Some(String("moongate.routing-policy-store.v1")) => ()
    _ => return
  }
  match store.get("drafts") {
    Some(value) =>
      apply_import_routing_policy_map(self.routing_policy_drafts, value)
    None => ()
  }
  match store.get("active") {
    Some(value) =>
      apply_import_routing_policy_map(self.active_routing_policies, value)
    None => ()
  }
  match store.get("previous") {
    Some(value) =>
      apply_import_routing_policy_map(self.previous_routing_policies, value)
    None => ()
  }
  match store.get("activeSmoothState") {
    Some(value) =>
      apply_import_routing_smooth_map(self.routing_smooth_states, value)
    None => ()
  }
  match store.get("shadowSmoothState") {
    Some(value) =>
      apply_import_routing_smooth_map(self.routing_shadow_smooth_states, value)
    None => ()
  }
  match store.get("shadowCounts") {
    Some(Object(counts)) =>
      for app_type, count_json in counts {
        if count_json is Number(count, ..) {
          self.routing_shadow_counts[app_type] = max_int(
            count.trunc().to_int(),
            0,
          )
        }
      }
    _ => ()
  }
  match store.get("shadowFirstObservedAtMs") {
    Some(Object(values)) =>
      for app_type, value_json in values {
        if value_json is Number(value, ..) {
          self.routing_shadow_first_observed_at_ms[app_type] = value
            .trunc()
            .to_int64()
        }
      }
    _ => ()
  }
  match store.get("lastShadowDecisions") {
    Some(value) =>
      apply_import_routing_decision_map(
        self.routing_last_shadow_decisions,
        value,
      )
    None => ()
  }
  match store.get("lastActiveDecisions") {
    Some(value) =>
      apply_import_routing_decision_map(
        self.routing_last_active_decisions,
        value,
      )
    None => ()
  }
  match store.get("activationReceipts") {
    Some(Array(receipts)) =>
      for receipt_json in receipts {
        match routing_receipt_from_store(receipt_json) {
          Some(receipt) => self.append_routing_receipt(receipt)
          None => ()
        }
      }
    _ => ()
  }
}

///|
fn provider_health_state_from_store(
  row : Map[String, Json],
) -> ProviderHealthState? {
  guard json_string_from_map(row, "updatedAt") is Some(updated_at) else {
    return None
  }
  Some({
    is_healthy: json_bool_from_map(row, "isHealthy").unwrap_or(false),
    consecutive_failures: proxy_json_int(row, "consecutiveFailures").unwrap_or(
      0,
    ),
    last_success_at: json_string_from_map(row, "lastSuccessAt"),
    last_failure_at: json_string_from_map(row, "lastFailureAt"),
    last_error: json_string_from_map(row, "lastError"),
    updated_at,
  })
}

///|
fn ProviderRouter::apply_import_provider_health(
  self : ProviderRouter,
  value : Json,
) -> Unit {
  guard value is Object(apps) else { return }
  for app_type, providers_json in apps {
    guard providers_json is Object(providers) else { continue }
    for provider_id, state_json in providers {
      guard self.provider_by_id(app_type, provider_id) is Some(_) else {
        continue
      }
      guard state_json is Object(row) else { continue }
      guard provider_health_state_from_store(row) is Some(state) else {
        continue
      }
      self.provider_health.set(
        provider_health_key(app_type, provider_id),
        state,
      )
    }
  }
}

///|
fn ProviderRouter::apply_import_custom_endpoints(
  self : ProviderRouter,
  value : Json,
) -> Unit {
  guard value is Object(apps) else { return }
  for app_type, providers_json in apps {
    guard providers_json is Object(providers) else { continue }
    for provider_id, endpoints_json in providers {
      guard self.provider_by_id(app_type, provider_id) is Some(_) else {
        continue
      }
      guard endpoints_json is Array(endpoints) else { continue }
      for endpoint in endpoints {
        guard endpoint is Object(row) else { continue }
        guard json_string_from_map(row, "url") is Some(url) else { continue }
        let added_at = proxy_json_int(row, "addedAt").unwrap_or(0)
        if !self.add_custom_endpoint(
            app_type,
            provider_id,
            url,
            now_ms=added_at,
          ) {
          continue
        }
        match proxy_json_int(row, "lastUsed") {
          Some(last_used) =>
            self.update_endpoint_last_used(
              app_type,
              provider_id,
              url,
              now_ms=last_used,
            )
          None => ()
        }
      }
    }
  }
}

///|
fn ProviderRouter::clear_imported_state(self : ProviderRouter) -> Unit {
  self.providers.clear()
  self.current_provider_ids.clear()
  self.universal_providers.clear()
  self.provider_sort_indices.clear()
  self.custom_endpoints.clear()
  self.failover_queues.clear()
  self.auto_failover_enabled.clear()
  self.max_retries.clear()
  self.circuit_breakers.clear()
  self.provider_health.clear()
  self.provider_health_observed_at_ms.clear()
  self.app_circuit_configs.clear()
  self.routing_policy_drafts.clear()
  self.active_routing_policies.clear()
  self.previous_routing_policies.clear()
  self.routing_smooth_states.clear()
  self.routing_shadow_smooth_states.clear()
  self.routing_session_bindings.clear()
  self.routing_shadow_counts.clear()
  self.routing_shadow_first_observed_at_ms.clear()
  self.routing_canary_counters.clear()
  self.routing_last_shadow_decisions.clear()
  self.routing_last_active_decisions.clear()
  self.routing_activation_receipts.clear()
  self.provider_inflight.clear()
  self.provider_quota_exhausted.clear()
  self.provider_quota_evidence_supported.clear()
}

///|
fn ProxyService::moon_apply_import_providers(
  self : ProxyService,
  providers_json : Json,
  validate_only? : Bool = false,
) -> Result[Int, String] {
  guard providers_json is Object(root) else {
    return Err("providers must be an object")
  }
  let mut has_app_data = false
  for app_type in moon_suite_app_types() {
    if root.get(app_type) is Some(Object(_)) {
      has_app_data = true
      break
    }
  }
  if !has_app_data {
    return Err("providers object contains no framework data")
  }
  for app_type in moon_suite_app_types() {
    guard root.get(app_type) is Some(Object(app_providers)) else { continue }
    for provider_id, provider_json in app_providers {
      guard provider_json is Object(_) else {
        return Err(
          "provider '\{provider_id}' in '\{app_type}' must be an object",
        )
      }
      if provider_target_from_request("", Some(provider_json), app_type) is None {
        return Err("provider '\{provider_id}' in '\{app_type}' is invalid")
      }
    }
  }
  if validate_only {
    return Ok(0)
  }
  self.provider_router.clear_imported_state()
  let mut imported = 0
  for app_type in moon_suite_app_types() {
    guard root.get(app_type) is Some(Object(app_providers)) else { continue }
    for provider_id, provider_json in app_providers {
      guard provider_json is Object(provider_obj) else { continue }
      guard provider_target_from_request("", Some(provider_json), app_type)
        is Some(parsed_target) else {
        continue
      }
      let target = {
        ..parsed_target,
        provider_id: if parsed_target.provider_id.is_empty() {
          provider_id
        } else {
          parsed_target.provider_id
        },
        origin: provider_store_origin(provider_obj),
      }
      self.provider_router.upsert_provider(target)
      imported += 1
      if json_bool_from_map(provider_obj, "isCurrent").unwrap_or(false) {
        self.provider_router.set_current_provider(app_type, target.provider_id)
      }
      if json_bool_from_map(provider_obj, "inFailoverQueue").unwrap_or(false) {
        self.provider_router.add_to_failover_queue(app_type, target.provider_id)
      }
      match proxy_json_int(provider_obj, "sortIndex") {
        Some(sort_index) =>
          ignore(
            self.provider_router.update_providers_sort_order(app_type, [
              { id: target.provider_id, sort_index },
            ]),
          )
        None => ()
      }
    }
  }
  match root.get("universalProviders") {
    Some(Object(universal)) =>
      for id, provider in universal {
        self.provider_router.universal_providers.set(id, provider)
      }
    _ => ()
  }
  match root.get("circuitBreakerConfig") {
    Some(config) =>
      match circuit_breaker_config_from_json(config) {
        Some(parsed) => self.provider_router.update_all_configs(parsed)
        None => ()
      }
    None => ()
  }
  match root.get("customEndpoints") {
    Some(endpoints) =>
      self.provider_router.apply_import_custom_endpoints(endpoints)
    None => ()
  }
  match root.get("providerHealth") {
    Some(health) => self.provider_router.apply_import_provider_health(health)
    None => ()
  }
  match root.get("autoFailover") {
    Some(Object(states)) =>
      for app_type in moon_suite_app_types() {
        match json_bool_from_map(states, app_type) {
          Some(enabled) =>
            self.provider_router.set_auto_failover(app_type, enabled)
          None => ()
        }
      }
    _ => ()
  }
  match root.get("routingPolicies") {
    Some(value) => self.provider_router.apply_import_routing_policy_store(value)
    None => ()
  }
  Ok(imported)
}
