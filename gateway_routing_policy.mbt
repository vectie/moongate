///|
fn routing_int_map_from_body(body : Json?, key : String) -> Map[String, Int]? {
  let values : Map[String, Int] = {}
  guard body is Some(Object(obj)) else { return Some(values) }
  guard obj.get(key) is Some(value) else { return Some(values) }
  guard value is Object(entries) else { return None }
  for provider_id, entry in entries {
    guard !provider_id.trim().is_empty() else { return None }
    match entry {
      Number(number, ..) => values[provider_id] = number.trunc().to_int()
      _ => return None
    }
  }
  Some(values)
}

///|
fn routing_actor_and_authority_from_body(
  body_obj : Map[String, Json],
) -> Result[
  (@capability.PrincipalRefV1, @capability.AuthorityDecisionRefV1),
  String,
] {
  guard body_obj.get("actorPrincipal") is Some(actor_json) else {
    return Err("missing_actor_principal")
  }
  guard body_obj.get("authorityDecision") is Some(authority_json) else {
    return Err("missing_authority_decision")
  }
  let actor_result : Result[@capability.PrincipalRefV1, Error] = moon_result(
    () => @capability.decode_principal_ref_v1(actor_json),
  )
  guard actor_result is Ok(actor) else {
    return Err("invalid_actor_principal")
  }
  let authority_result : Result[@capability.AuthorityDecisionRefV1, Error] = moon_result(
    () => @capability.decode_authority_decision_ref_v1(authority_json),
  )
  guard authority_result is Ok(authority) else {
    return Err("invalid_authority_decision")
  }
  Ok((actor, authority))
}

///|
async fn ProxyService::handle_get_routing_policy(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  write_usage_json(w, self.provider_router.routing_policy_state_json(app_type))
}

///|
async fn ProxyService::handle_configure_routing_policy(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard proxy_string_request(r.path, body, "mode") is Some(mode_text) &&
    @routing.parse_routing_mode(mode_text) is Some(mode) else {
    write_usage_bad_request(w, "invalid_routing_mode")
    return
  }
  guard routing_int_map_from_body(body, "weights") is Some(weights) else {
    write_usage_bad_request(w, "invalid_routing_weights")
    return
  }
  guard routing_int_map_from_body(body, "concurrencyLimits")
    is Some(concurrency_limits) else {
    write_usage_bad_request(w, "invalid_concurrency_limits")
    return
  }
  let policy_id = proxy_string_request(r.path, body, "policyId")
    .unwrap_or("\{app_type}.routing")
  let minimum_shadow_decisions = proxy_int_request(
    r.path,
    body,
    "minimumShadowDecisions",
  ).unwrap_or(20)
  let minimum_shadow_window_ms = proxy_int_request(
    r.path,
    body,
    "minimumShadowWindowMs",
  ).unwrap_or(300_000).to_int64()
  let canary_traffic_basis_points = proxy_int_request(
    r.path,
    body,
    "canaryTrafficBasisPoints",
  ).unwrap_or(500)
  let rollback_error_rate_milli = proxy_int_request(
    r.path,
    body,
    "rollbackErrorRateMilli",
  ).unwrap_or(100)
  let rollback_p95_latency_ms = proxy_int_request(
    r.path,
    body,
    "rollbackP95LatencyMs",
  ).unwrap_or(30_000)
  let rollback_minimum_requests = proxy_int_request(
    r.path,
    body,
    "rollbackMinimumRequests",
  ).unwrap_or(20)
  match self.provider_router.configure_routing_policy(
    app_type~,
    policy_id~,
    mode~,
    weights~,
    concurrency_limits~,
    minimum_shadow_decisions~,
    minimum_shadow_window_ms~,
    canary_traffic_basis_points~,
    rollback_error_rate_milli~,
    rollback_p95_latency_ms~,
    rollback_minimum_requests~,
    configured_at_ms=moongate_epoch_ms(),
  ) {
    Err(error) => write_usage_bad_request(w, error)
    Ok(policy) => {
      if !self.persist_provider_store_or_error(w) {
        return
      }
      write_usage_json(w, {
        "status": Json::string("shadow-only"),
        "policy": policy.to_json(),
        "activationAllowed": Json::boolean(false),
      }.to_json())
    }
  }
}

///|
async fn ProxyService::handle_observe_routing_shadow(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard self.provider_router.routing_policy_drafts.get(app_type) is Some(_) else {
    write_usage_bad_request(w, "no_shadow_routing_policy")
    return
  }
  self.provider_router.observe_shadow_routing(
    app_type,
    @async.now().to_int(),
    session_key=proxy_string_request(r.path, body, "sessionKey"),
  )
  if !self.persist_provider_store_or_error(w) {
    return
  }
  write_usage_json(w, self.provider_router.routing_policy_state_json(app_type))
}

///|
async fn ProxyService::handle_activate_routing_policy(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard proxy_int_request(r.path, body, "expectedRevision")
    is Some(expected_revision) else {
    write_usage_bad_request(w, "missing_expected_revision")
    return
  }
  guard body is Some(Object(body_obj)) else {
    write_usage_bad_request(w, "missing_activation_body")
    return
  }
  let actor_and_authority = routing_actor_and_authority_from_body(body_obj)
  guard actor_and_authority is Ok((actor_principal, authority_decision)) else {
    guard actor_and_authority is Err(error) else { return }
    write_usage_bad_request(w, error)
    return
  }
  let authority_checked_at = moongate_canonical_utc_now()
  match self.provider_router.activate_routing_policy(
    app_type~,
    expected_revision~,
    actor_principal~,
    authority_decision~,
    authority_checked_at~,
    receipt_id="routing-\{moongate_random_id()}",
    recorded_at_ms=moongate_epoch_ms(),
  ) {
    Err(error) => write_usage_bad_request(w, error)
    Ok(receipt) => {
      if !self.persist_provider_store_or_error(w) {
        return
      }
      write_usage_json(w, receipt.to_json())
    }
  }
}

///|
async fn ProxyService::handle_rollback_routing_policy(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard body is Some(Object(body_obj)) else {
    write_usage_bad_request(w, "missing_rollback_body")
    return
  }
  let actor_and_authority = routing_actor_and_authority_from_body(body_obj)
  guard actor_and_authority is Ok((actor_principal, authority_decision)) else {
    guard actor_and_authority is Err(error) else { return }
    write_usage_bad_request(w, error)
    return
  }
  let authority_checked_at = moongate_canonical_utc_now()
  match self.provider_router.rollback_routing_policy(
    app_type~,
    actor_principal~,
    authority_decision~,
    authority_checked_at~,
    receipt_id="routing-\{moongate_random_id()}",
    recorded_at_ms=moongate_epoch_ms(),
  ) {
    Err(error) => write_usage_bad_request(w, error)
    Ok(receipt) => {
      if !self.persist_provider_store_or_error(w) {
        return
      }
      write_usage_json(w, receipt.to_json())
    }
  }
}
