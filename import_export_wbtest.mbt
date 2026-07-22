///|
test "moongate backup filenames are filesystem safe" {
  assert_eq(moon_backup_filename("nested/name:one"), "nested-name-one.db")
  assert_eq(moon_backup_filename("ready.db"), "ready.db")
  assert_eq(moon_backup_filename("snapshot.json"), "snapshot.json")
}

///|
test "moongate database backup filenames reject invalid restore targets" {
  assert_true(moon_valid_db_backup_filename("db_backup_20260614_010203.db"))
  assert_false(moon_valid_db_backup_filename("nested/name.db"))
  assert_false(moon_valid_db_backup_filename("nested\\name.db"))
  assert_false(moon_valid_db_backup_filename("../escape.db"))
  assert_false(moon_valid_db_backup_filename("snapshot.json"))
  assert_eq(
    moon_db_backup_filename_error("../escape.db"),
    Some("Invalid backup filename"),
  )
  assert_eq(moon_db_backup_filename_error("safe.db"), None)
}

///|
test "moongate database backup rename normalizes new name like desktop" {
  assert_eq(moon_db_backup_new_filename("renamed"), Ok("renamed.db"))
  assert_eq(moon_db_backup_new_filename("renamed.db"), Ok("renamed.db"))
  assert_eq(moon_db_backup_new_filename("  "), Err("New name cannot be empty"))
  assert_eq(
    moon_db_backup_new_filename("../escape"),
    Err("Invalid characters in new name"),
  )
  assert_eq(
    moon_db_backup_new_filename("nested/name"),
    Err("Invalid characters in new name"),
  )
}

///|
test "moongate database backup entries sort newest first" {
  let rows = [
    MoonDbBackupEntry::{ filename: "old.db", size_bytes: 1, created_at: 1L },
    { filename: "new.db", size_bytes: 2, created_at: 3L },
    { filename: "mid.db", size_bytes: 3, created_at: 2L },
  ]
  moon_sort_db_backup_entries(rows)
  assert_eq(rows[0].filename, "new.db")
  assert_eq(rows[1].filename, "mid.db")
  assert_eq(rows[2].filename, "old.db")
}

///|
async test "provider store round trips credentials identity and routing state" {
  @fsx.with_temporary_directory("moongate-provider-store-XXXXXX", async fn(
    tmpdir,
  ) {
    let path = @pathx.join(tmpdir, "providers.json")
    let saved = ProxyService::new("127.0.0.1", 15721)
    saved.provider_router.upsert_provider(
      ProviderRouteTarget::new(
        app_type="codex",
        provider_id="ark-plan",
        provider_name="Ark Agent Plan",
        provider_type=Some("openai"),
        api_format=Some("openai"),
        base_url=Some("https://ark.example.com/api/plan/v3"),
        api_key=Some("secret-test-key"),
        origin="user",
        model_mapping=Some(ModelMapping::new(default_model=Some("kimi-k3"))),
      ),
    )
    saved.provider_router.set_current_provider("codex", "ark-plan")
    saved.provider_router.record_provider_health_success(
      "ark-plan", "codex", "123456",
    )
    saved.provider_router.add_to_failover_queue("codex", "ark-plan")
    saved.provider_router.set_auto_failover("codex", true)
    assert_true(
      saved.provider_router.add_custom_endpoint(
        "codex",
        "ark-plan",
        "https://ark.example.com/api/plan/v3",
        now_ms=1234,
      ),
    )
    saved.provider_router.update_endpoint_last_used(
      "codex",
      "ark-plan",
      "https://ark.example.com/api/plan/v3",
      now_ms=5678,
    )
    saved.save_provider_store(path~)

    let loaded = ProxyService::new("127.0.0.1", 15721)
    loaded.load_provider_store(path~)
    guard loaded.provider_router.provider_by_id("codex", "ark-plan")
      is Some(provider) else {
      fail("expected persisted provider")
    }
    assert_eq(provider.api_key, Some("secret-test-key"))
    assert_eq(provider.origin, "user")
    guard provider.model_mapping is Some(mapping) else {
      fail("expected persisted model mapping")
    }
    assert_eq(mapping.default_model, Some("kimi-k3"))
    assert_eq(
      loaded.provider_router.current_provider_id("codex"),
      Some("ark-plan"),
    )
    assert_eq(
      loaded.provider_router.provider_health_status("ark-plan", "codex"),
      "healthy",
    )
    assert_true(
      loaded.provider_router.failover_queues
      .get("codex")
      .unwrap_or([])
      .contains("ark-plan"),
    )
    assert_true(loaded.provider_router.auto_failover_enabled_for_app("codex"))
    json_inspect(
      loaded.provider_router.custom_endpoints_json("codex", "ark-plan"),
      content=[
        {
          "url": "https://ark.example.com/api/plan/v3",
          "addedAt": 1234,
          "lastUsed": 5678,
        },
      ],
    )
    let public_json = loaded.provider_router
      .providers_moon_json("codex")
      .stringify()
    assert_true(public_json.contains("\"credentialState\":\"stored\""))
    assert_false(public_json.contains("secret-test-key"))
  })
}

///|
async test "proxy store round trips global and app configuration" {
  @fsx.with_temporary_directory("moongate-proxy-store-XXXXXX", async fn(
    tmpdir,
  ) {
    let path = @pathx.join(tmpdir, "proxy.json")
    let saved = ProxyService::new("127.0.0.1", 15721)
    saved.proxy_enabled = false
    saved.proxy_listen_address = "127.0.0.9"
    saved.proxy_listen_port = 18888
    saved.proxy_app_enabled.set("codex", false)
    saved.proxy_default_cost_multipliers.set("codex", "1.25")
    saved.proxy_pricing_model_sources.set("codex", "request")
    saved.upstream_proxy_url = Some("http://127.0.0.1:9000")
    saved.save_proxy_store(path~)

    let loaded = ProxyService::new("127.0.0.1", 15721)
    loaded.load_proxy_store(path~)
    assert_false(loaded.proxy_enabled)
    assert_eq(loaded.proxy_listen_address, "127.0.0.9")
    assert_eq(loaded.proxy_listen_port, 18888)
    assert_eq(loaded.proxy_app_enabled.get("codex"), Some(false))
    assert_eq(loaded.proxy_default_cost_multipliers.get("codex"), Some("1.25"))
    assert_eq(loaded.proxy_pricing_model_sources.get("codex"), Some("request"))
    assert_eq(loaded.upstream_proxy_url, Some("http://127.0.0.1:9000"))
  })
}

///|
test "invalid provider import does not clear live provider state" {
  let proxy = ProxyService::new("127.0.0.1", 15721)
  assert_true(
    proxy.provider_router.provider_by_id("codex", "codex-oauth") is Some(_),
  )
  let invalid = {
    "codex": { "broken": Json::string("not-an-object") }.to_json(),
  }.to_json()
  assert_true(proxy.moon_apply_import_providers(invalid) is Err(_))
  assert_true(
    proxy.provider_router.provider_by_id("codex", "codex-oauth") is Some(_),
  )
}
