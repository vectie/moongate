///|
test "draft provider test leaves saved configuration and health unchanged" {
  // In-memory fixtures only. Do not start a gateway or contact any provider.
  let proxy = ProxyService::new("dummy.invalid", 0)
  let saved = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="dummy-provider",
    provider_name="Saved A",
    base_url=Some("https://a.invalid"),
  )
  let draft = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="dummy-provider",
    provider_name="Draft B",
    base_url=Some("https://b.invalid"),
  )
  proxy.provider_router.upsert_provider(saved)
  let success : Json = { "networkRequestPerformed": true, "success": true }
  let failure : Json = {
    "networkRequestPerformed": true,
    "success": false,
    "message": "Dummy rejection",
  }
  let initial_health = proxy.provider_router.provider_health_json(
    saved.provider_id,
    saved.app_type,
    "dummy-time",
  )
  proxy.record_stream_check_provider_health(draft, success, draft=true)
  assert_eq(
    proxy.provider_router.provider_health_json(
      saved.provider_id,
      saved.app_type,
      "dummy-time",
    ),
    initial_health,
  )
  guard proxy.provider_router.provider_by_id(saved.app_type, saved.provider_id)
    is Some(unchanged) else {
    fail("saved provider disappeared")
  }
  assert_eq(unchanged.provider_name, "Saved A")
  assert_eq(unchanged.base_url, Some("https://a.invalid"))
  proxy.record_stream_check_provider_health(saved, failure)
  assert_eq(
    proxy.provider_router.provider_health_status(
      saved.provider_id,
      saved.app_type,
    ),
    "unhealthy",
  )
  let failed_health = proxy.provider_router.provider_health_json(
    saved.provider_id,
    saved.app_type,
    "dummy-time",
  )
  proxy.record_stream_check_provider_health(draft, success, draft=true)
  assert_eq(
    proxy.provider_router.provider_health_json(
      saved.provider_id,
      saved.app_type,
      "dummy-time",
    ),
    failed_health,
  )
  proxy.record_stream_check_provider_health(saved, success)
  assert_eq(
    proxy.provider_router.provider_health_status(
      saved.provider_id,
      saved.app_type,
    ),
    "healthy",
  )
  let passed_health = proxy.provider_router.provider_health_json(
    saved.provider_id,
    saved.app_type,
    "dummy-time",
  )
  proxy.record_stream_check_provider_health(draft, failure, draft=true)
  assert_eq(
    proxy.provider_router.provider_health_json(
      saved.provider_id,
      saved.app_type,
      "dummy-time",
    ),
    passed_health,
  )
}

///|
test "non-live provider results cannot certify saved provider health" {
  let proxy = ProxyService::new("dummy.invalid", 0)
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="dummy-uncontacted",
    provider_name="Dummy uncontacted provider",
    base_url=Some("https://uncontacted.invalid"),
  )
  proxy.provider_router.upsert_provider(provider)
  let initial = proxy.provider_router.provider_health_json(
    provider.provider_id,
    provider.app_type,
    "dummy-time",
  )
  proxy.record_stream_check_provider_health(provider, {
    "networkRequestPerformed": false,
    "success": true,
  })
  assert_eq(
    proxy.provider_router.provider_health_json(
      provider.provider_id,
      provider.app_type,
      "dummy-time",
    ),
    initial,
  )
}
