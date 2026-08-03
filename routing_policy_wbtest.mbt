///|
fn routing_test_actor_and_authority() -> (
  @capability.PrincipalRefV1,
  @capability.AuthorityDecisionRefV1,
) raise {
  let actor = @capability.principal_ref_v1(
    "operator-1",
    @capability.Human,
    "moondesk",
    "operator-1",
  )
  let authority = @capability.authority_decision_ref_v1(
    "route-change-1", actor, "sha256:0000000000000000000000000000000000000000000000000000000000000000",
    "2026-07-31T00:00:00Z", "2026-08-01T00:00:00Z",
  )
  (actor, authority)
}

///|
fn routing_test_router() -> ProviderRouter {
  let router = ProviderRouter::new()
  for id in ["provider-a", "provider-b"] {
    router.upsert_provider(
      ProviderRouteTarget::new(
        app_type="codex",
        provider_id=id,
        provider_name=id,
        provider_type=Some("openai"),
        api_format=Some("openai"),
        base_url=Some("https://\{id}.example.com/v1"),
        api_key=Some("test-only-secret"),
      ),
    )
    router.record_provider_health_success(id, "codex", "fixture")
    router.set_provider_quota_exhausted("codex", id, false)
  }
  router.set_current_provider("codex", "provider-a")
  router.set_failover_queue("codex", ["provider-a", "provider-b"])
  router.set_auto_failover("codex", true)
  router
}

///|
test "routing policy requires shadow evidence and binds typed authority" {
  let router = routing_test_router()
  let policy = router
    .configure_routing_policy(
      app_type="codex",
      policy_id="codex.balance",
      mode=@routing.LeastInflight,
      weights=Map([], capacity=0),
      concurrency_limits={ "provider-a": 1, "provider-b": 2 },
      minimum_shadow_decisions=2,
      minimum_shadow_window_ms=0L,
      canary_traffic_basis_points=2500,
      configured_at_ms=1L,
    )
    .unwrap()
  let (actor, authority) = routing_test_actor_and_authority()
  let early = router.activate_routing_policy(
    app_type="codex",
    expected_revision=policy.revision,
    actor_principal=actor,
    authority_decision=authority,
    authority_checked_at="2026-07-31T12:00:00Z",
    receipt_id="receipt-early",
    recorded_at_ms=moongate_epoch_ms(),
  )
  assert_true(early is Err(_))
  router.observe_shadow_routing("codex", 1)
  router.observe_shadow_routing("codex", 2)
  let receipt = router
    .activate_routing_policy(
      app_type="codex",
      expected_revision=policy.revision,
      actor_principal=actor,
      authority_decision=authority,
      authority_checked_at="2026-07-31T12:00:00Z",
      receipt_id="receipt-activate",
      recorded_at_ms=moongate_epoch_ms(),
    )
    .unwrap()
  assert_eq(receipt.action, @routing.Activate)
  assert_eq(receipt.activation_scope, @routing.BoundedCanary)
  assert_eq(receipt.actor_principal, "human|operator-1|moondesk|operator-1")
  assert_eq(receipt.authority_decision_id, "route-change-1")
  assert_eq(
    receipt.authority_decision_digest,
    "sha256:0000000000000000000000000000000000000000000000000000000000000000",
  )
}

///|
test "routing canary fraction and session digests are deterministic" {
  let router = ProviderRouter::new()
  let policy = @routing.policy(
    policy_id="codex.canary",
    app_type="codex",
    revision=1,
    mode=@routing.Priority,
    canary_traffic_basis_points=2500,
    configured_at_ms=1L,
  )
  let mut selected = 0
  for _ in 0..<10_000 {
    if router.routing_policy_uses_canary(policy) {
      selected += 1
    }
  }
  assert_eq(selected, 2500)
  let digest = routing_session_key_digest("private-session")
  assert_eq(digest.length(), 64)
  assert_false(digest.contains("private-session"))
  assert_eq(digest, routing_session_key_digest("private-session"))
}
