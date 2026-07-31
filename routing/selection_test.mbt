///|
fn candidate(
  id : String,
  priority : Int,
  weight? : Int = 1,
  inflight? : Int = 0,
  limit? : Int = 0,
  healthy? : Bool = true,
) -> ProviderCandidateV1 {
  {
    provider_id: id,
    priority,
    weight,
    inflight,
    concurrency_limit: limit,
    enabled: true,
    compatible: true,
    healthy,
    circuit_open: false,
    quota_exhausted: false,
    health_evidence_supported: true,
    health_observed_at_ms: Some(1L),
    health_fresh: true,
    credential_evidence_supported: true,
    credentials_available: true,
    model_evidence_supported: true,
    model_supported: true,
    protocol_evidence_supported: true,
    protocol_supported: true,
    budget_evidence_supported: false,
    budget_available: true,
    capacity_evidence_supported: true,
    capacity_available: limit == 0 || inflight < limit,
  }
}

///|
test "smooth weighted round robin is deterministic and smooth" {
  let policy = policy(
    policy_id="codex.balance",
    app_type="codex",
    revision=1,
    mode=SmoothWeightedRoundRobin,
    configured_at_ms=1,
  )
  let candidates = [candidate("a", 0, weight=3), candidate("b", 1, weight=1)]
  let selected : Array[String] = []
  let mut state = empty_smooth_state()
  for _ in 0..<8 {
    let (decision, next) = select(
      policy,
      candidates,
      state,
      shadow=false,
      decided_at_ms=1L,
    )
    selected.push(decision.selected_provider_id.unwrap())
    state = next
  }
  assert_eq(selected.filter(fn(provider_id) { provider_id == "a" }).length(), 6)
  assert_eq(selected.filter(fn(provider_id) { provider_id == "b" }).length(), 2)
  let replayed : Array[String] = []
  let mut replay_state = empty_smooth_state()
  for _ in 0..<8 {
    let (decision, next) = select(
      policy,
      candidates,
      replay_state,
      shadow=false,
      decided_at_ms=1L,
    )
    replayed.push(decision.selected_provider_id.unwrap())
    replay_state = next
  }
  assert_eq(replayed, selected)
}

///|
test "least inflight rejects saturated and unhealthy candidates" {
  let policy = policy(
    policy_id="codex.capacity",
    app_type="codex",
    revision=1,
    mode=LeastInflight,
    configured_at_ms=1,
  )
  let (decision, _) = select(
    policy,
    [
      candidate("busy", 0, inflight=2, limit=2),
      candidate("unhealthy", 1, healthy=false),
      candidate("ready", 2, inflight=1, limit=4),
    ],
    empty_smooth_state(),
    shadow=false,
    decided_at_ms=1L,
  )
  assert_eq(decision.selected_provider_id, Some("ready"))
  assert_true(decision.reviews[0].reasons.contains("concurrency-limit"))
  assert_true(decision.reviews[1].reasons.contains("provider-unhealthy"))
}

///|
test "session sticky preserves an eligible binding and replaces an exhausted one" {
  let policy = policy(
    policy_id="codex.session",
    app_type="codex",
    revision=1,
    mode=SessionSticky,
    configured_at_ms=1,
  )
  let candidates = [candidate("a", 0), candidate("b", 1)]
  let (sticky, _) = select(
    policy,
    candidates,
    empty_smooth_state(),
    shadow=false,
    decided_at_ms=1L,
    sticky_provider_id=Some("b"),
    session_key_present=true,
  )
  assert_eq(sticky.selected_provider_id, Some("b"))
  let saturated = [candidate("a", 0), candidate("b", 1, inflight=1, limit=1)]
  let (replaced, _) = select(
    policy,
    saturated,
    empty_smooth_state(),
    shadow=false,
    decided_at_ms=1L,
    sticky_provider_id=Some("b"),
    session_key_present=true,
  )
  assert_eq(replaced.selected_provider_id, Some("a"))
}

///|
test "routing decision vocabularies are canonical and fail closed" {
  json_inspect(RoutingMode::SessionSticky, content="session-sticky")
  json_inspect(
    RoutingActivationScopeV1::BoundedCanary,
    content="bounded-canary",
  )
  json_inspect(RoutingActivationActionV1::Activate, content="activate")
  let unknown_mode : Result[RoutingMode, @json.JsonDecodeError] = try? @json.from_json(
    Json::string("random"),
  )
  let unknown_action : Result[RoutingActivationActionV1, @json.JsonDecodeError] = try? @json.from_json(
    Json::string("replace"),
  )
  let unknown_scope : Result[RoutingActivationScopeV1, @json.JsonDecodeError] = try? @json.from_json(
    Json::string("all-traffic"),
  )
  assert_true(unknown_mode is Err(_))
  assert_true(unknown_action is Err(_))
  assert_true(unknown_scope is Err(_))
}
