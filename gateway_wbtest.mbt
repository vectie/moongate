///|
fn moon_wbtest_restore_env(key : String, value : String?) -> Unit {
  match value {
    Some(value) => @os.setenv(key, value, overwrite=true) catch { _ => () }
    None => @os.unsetenv(key) catch { _ => () }
  }
}

///|
test "claude desktop model list matches moonstat response shape" {
  json_inspect(claude_desktop_model_list_json(), content={
    "data": [
      {
        "type": "model",
        "id": "claude-sonnet-4-6",
        "created_at": "2024-01-01T00:00:00Z",
        "supports1m": true,
      },
      {
        "type": "model",
        "id": "claude-opus-4-8",
        "created_at": "2024-01-01T00:00:00Z",
        "supports1m": true,
      },
      {
        "type": "model",
        "id": "claude-haiku-4-5",
        "created_at": "2024-01-01T00:00:00Z",
        "supports1m": true,
      },
    ],
    "has_more": false,
    "first_id": "claude-sonnet-4-6",
    "last_id": "claude-haiku-4-5",
  })
}

///|
test "claude desktop model list uses moonstat provider route metadata" {
  let routes : Map[String, ClaudeDesktopModelRoute] = {
    "claude-haiku-4-5": ClaudeDesktopModelRoute::new(
      model="haiku-upstream",
      supports_1m=Some(true),
    ),
    "gpt-5": ClaudeDesktopModelRoute::new(model="gpt-5-upstream"),
  }
  let provider = ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="desktop-routes",
    provider_name="Desktop Routes",
    claude_desktop_model_routes=routes,
  )
  guard claude_desktop_model_list_json(provider=Some(provider)) is Object(obj) else {
    fail("expected model list object")
  }
  guard obj["data"] is Array(data) else { fail("expected data array") }
  assert_eq(data.length(), 2)
  guard data[0] is Object(first) else { fail("expected first model") }
  guard data[1] is Object(second) else { fail("expected second model") }
  assert_eq(first["id"], Json::string("claude-haiku-4-5"))
  assert_eq(first["supports1m"], Json::boolean(true))
  assert_true(first.get("labelOverride") is None)
  assert_eq(second["id"], Json::string("claude-sonnet-4-6"))
  assert_eq(second["labelOverride"], Json::string("gpt-5-upstream"))
  assert_true(second.get("supports1m") is None)
  assert_eq(obj["first_id"], Json::string("claude-haiku-4-5"))
  assert_eq(obj["last_id"], Json::string("claude-sonnet-4-6"))
}

///|
test "codex compact responses keep compact backend endpoint" {
  assert_eq(
    codex_backend_responses_endpoint(false),
    "/backend-api/codex/responses",
  )
  assert_eq(
    codex_backend_responses_endpoint(true),
    "/backend-api/codex/responses/compact",
  )
}

///|
test "gemini model extraction trims moonstat query and action suffixes" {
  assert_eq(
    gemini_model_from_endpoint(
      "/v1beta/models/gemini-pro:generateContent?key=abc",
    ),
    "gemini-pro",
  )
  assert_eq(
    gemini_model_from_endpoint("/gemini/v1beta/models/gemini-2.0-flash?key=abc"),
    "gemini-2.0-flash",
  )
  assert_eq(
    gemini_model_from_endpoint(
      "/gemini/v1beta/models/gemini-2.0-flash:countTokens",
    ),
    "gemini-2.0-flash",
  )
  assert_eq(gemini_model_from_endpoint("/v1beta/models"), "unknown")
  assert_eq(gemini_model_from_endpoint("/v1beta/operations"), "unknown")
}

///|
test "usage request detail route extracts moonstat request id" {
  assert_eq(usage_request_detail_id("/usage/request-detail/req_123"), "req_123")
  assert_eq(usage_request_detail_id("req_123"), "req_123")
  assert_eq(
    usage_request_detail_id("/usage/request-detail/session%3Amsg_1?ignored=1"),
    "session:msg_1",
  )
}

///|
test "usage query helpers parse moonstat trend parameters" {
  let path = "/usage/trends?startDate=10&endDate=20&appType=codex"
  assert_eq(usage_query_int(path, "startDate"), Some(10))
  assert_eq(usage_query_int(path, "endDate"), Some(20))
  assert_eq(usage_query_value(path, "appType"), Some("codex"))
  assert_eq(usage_query_value(path, "missing"), None)
  assert_eq(usage_query_int("/usage/trends?startDate=bad", "startDate"), None)
  assert_eq(usage_query_int("/usage/trends?start_date=10", "startDate"), None)
  assert_eq(usage_query_value("/usage/trends?app_type=codex", "appType"), None)
}

///|
test "usage query helpers parse moonstat provider limit parameters" {
  let path = "/usage/provider-limits?providerId=codex-oauth&appType=codex&dailyLimitUsd=0.10&monthlyLimitUsd=1.25"
  assert_eq(usage_query_value(path, "providerId"), Some("codex-oauth"))
  assert_eq(usage_query_value(path, "appType"), Some("codex"))
  assert_eq(usage_query_value(path, "dailyLimitUsd"), Some("0.10"))
  assert_eq(usage_query_value(path, "monthlyLimitUsd"), Some("1.25"))
  assert_eq(
    usage_query_value("/usage/provider-limits?provider_id=p1", "providerId"),
    None,
  )
}

///|
test "usage script request accepts raw moonstat script output" {
  let path = "/usage/test-script?providerId=p1&appType=codex&scriptCode=%5B%7B%22planName%22%3A%22Team%22%2C%22total%22%3A100%2C%22used%22%3A40%2C%22remaining%22%3A60%2C%22unit%22%3A%22%25%22%7D%5D"
  guard usage_result_from_request(path, None) is Some(result) else {
    fail("expected usage result")
  }
  assert_true(result.success)
  guard result.data is Some(rows) else { fail("expected data") }
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].plan_name, Some("Team"))
  assert_eq(rows[0].remaining, Some(60.0))
  assert_eq(rows[0].unit, Some("%"))
  assert_true(
    usage_result_from_request(
      "/usage/test-script?providerId=p1&appType=codex&script_code=%7B%22success%22%3Atrue%7D",
      None,
    )
    is None,
  )
  assert_true(
    usage_result_from_request(
      "/usage/test-script",
      Some({ "script_code": Json::string("{\"success\":true}") }.to_json()),
    )
    is None,
  )
}

///|
async test "gateway startup publishes the bound port for suite discovery" {
  let core_source = @fsx.read_file("gateway_core.mbt")
  assert_true(core_source.contains("let bound_port = server.port()"))
  assert_true(core_source.contains("port=bound_port"))
  assert_true(
    core_source.contains(
      "self.usage.register_status_routes(\n    router,\n    self.auth,\n    self.proxy.provider_router,\n    self.host,\n    bound_port,",
    ),
  )
  assert_false(core_source.contains("port=self.port"))
}

///|
async test "suite http endpoints are registered by gateway suite routes" {
  let core_source = @fsx.read_file("gateway_core.mbt")
  let route_source = @fsx.read_file("gateway_suite_routes.mbt")
  assert_true(
    core_source.contains("self.register_suite_routes(router, bound_port)"),
  )
  assert_true(route_source.contains("bound_port : Int"))
  for
    route in [
      "/suite/manifest", "/suite/status", "/suite/drift", "/suite/status/write",
      "/suite/moonclaw-providers", "/suite/moonclaw-providers/write",
    ] {
    assert_true(route_source.contains(route))
  }
  assert_true(route_source.contains("moonstat_suite_manifest_json("))
  assert_true(route_source.contains("moonstat_suite_drift_report_json("))
  assert_true(route_source.contains("write_moonstat_suite_status("))
  assert_true(route_source.contains("moonstat_moonclaw_providers_file_json("))
  assert_true(route_source.contains("write_moonstat_moonclaw_providers_file("))
  assert_true(route_source.contains("port=bound_port"))
  assert_false(route_source.contains("port=self.port"))
}

///|
async test "usage script github copilot template uses standalone native query" {
  let path = "/usage/test-script?providerId=p1&appType=claude&templateType=github_copilot&accountId=moonstat-missing-account"
  guard test_usage_script_template_result(path, None) is Some(result) else {
    fail("expected template result")
  }
  assert_false(result.success)
  assert_true(result.error is Some(_))
}

///|
test "github copilot usage conversion mirrors moonstat premium row" {
  let result = moon_copilot_usage_result_from_json(
    {
      "copilot_plan": Json::string("Individual"),
      "quota_reset_date": Json::string("2026-07-01"),
      "quota_snapshots": {
        "premium_interactions": {
          "entitlement": Json::number(300.0),
          "remaining": Json::number(125.0),
          "percent_remaining": Json::number(41.6),
          "unlimited": Json::boolean(false),
        }.to_json(),
      }.to_json(),
    }.to_json(),
  )
  assert_true(result.success)
  guard result.data is Some(rows) else { fail("expected rows") }
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].plan_name, Some("Individual"))
  assert_eq(rows[0].total, Some(300.0))
  assert_eq(rows[0].remaining, Some(125.0))
  assert_eq(rows[0].used, Some(175.0))
  assert_eq(rows[0].unit, Some("requests"))
  assert_eq(rows[0].is_valid, Some(true))
  assert_eq(rows[0].extra, Some("Reset: 2026-07-01"))
}

///|
test "github copilot usage conversion reports malformed response" {
  let empty : Map[String, Json] = {}
  assert_eq(
    moon_copilot_usage_result_from_json(empty.to_json()).to_json(),
    UsageResult::new(
      false,
      error=Some("Failed to parse Copilot usage response"),
    ).to_json(),
  )
}

///|
async test "usage script balance template uses standalone moonstat native query" {
  let path = "/usage/test-script?providerId=p1&appType=codex&templateType=balance&baseUrl=https%3A%2F%2Fopenrouter.ai%2Fapi%2Fv1&apiKey="
  guard test_usage_script_template_result(path, None) is Some(result) else {
    fail("expected template result")
  }
  assert_eq(
    result.to_json(),
    UsageResult::new(false, error=Some("API key is empty")).to_json(),
  )
  assert_true(
    test_usage_script_template_result(
      "/usage/test-script?providerId=p1&appType=codex&templateType=custom",
      None,
    )
    is None,
  )
}

///|
async test "usage script token plan template uses standalone moonstat native query" {
  let path = "/usage/test-script?providerId=p1&appType=codex&templateType=token_plan&baseUrl=https%3A%2F%2Fapi.kimi.com%2Fcoding&apiKey="
  guard test_usage_script_template_result(path, None) is Some(result) else {
    fail("expected template result")
  }
  assert_eq(UsageResult::new(false).to_json(), result.to_json())
}

///|
async test "usage script official subscription template uses standalone moonstat native query" {
  let path = "/usage/test-script?providerId=p1&tool=unknown&templateType=official_subscription"
  guard test_usage_script_template_result(path, None) is Some(result) else {
    fail("expected template result")
  }
  assert_eq(UsageResult::new(false).to_json(), result.to_json())
}

///|
test "official subscription quota usage conversion mirrors moonstat rows" {
  let result = moon_subscription_usage_result_from_quota(
    SubscriptionQuota::new("claude", tiers=[
      moon_quota_tier_json("five_hour", 12.5, resets_at=Some("five-reset")),
      moon_quota_tier_json("seven_day", 75.0),
    ]),
  )
  assert_true(result.success)
  guard result.data is Some(rows) else { fail("expected rows") }
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].plan_name, Some("five_hour"))
  assert_eq(rows[0].total, Some(100.0))
  assert_eq(rows[0].used, Some(12.5))
  assert_eq(rows[0].remaining, Some(87.5))
  assert_eq(rows[0].unit, Some("%"))
  assert_eq(rows[0].is_valid, Some(true))
  assert_eq(rows[0].extra, Some("five-reset"))
  assert_eq(rows[1].extra, None)
}

///|
test "official subscription quota usage conversion falls back to credential message" {
  assert_eq(
    moon_subscription_usage_result_from_quota(
      SubscriptionQuota::new(
        "claude",
        credential_message=Some("No OAuth entry found in credentials"),
        success=false,
      ),
    ).to_json(),
    UsageResult::new(false, error=Some("No OAuth entry found in credentials")).to_json(),
  )
}

///|
test "token plan quota usage conversion mirrors moonstat rows" {
  let result = moon_token_plan_usage_result_from_quota(
    SubscriptionQuota::new(
      "coding_plan",
      credential_message=Some("Pro (active)"),
      tiers=[
        moon_quota_tier_json(
          "five_hour",
          25.0,
          resets_at=Some("five-reset"),
          used_value_usd=Some(1.5),
          max_value_usd=Some(6.0),
        ),
        moon_quota_tier_json("weekly_limit", 75.0, resets_at=Some("week-reset")),
      ],
    ),
  )
  assert_true(result.success)
  guard result.data is Some(rows) else { fail("expected rows") }
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].plan_name, Some("five_hour"))
  assert_eq(rows[0].total, Some(100.0))
  assert_eq(rows[0].used, Some(25.0))
  assert_eq(rows[0].remaining, Some(75.0))
  assert_eq(rows[0].unit, Some("%"))
  assert_eq(rows[0].is_valid, Some(true))
  guard rows[0].extra is Some(extra) else { fail("expected extra json") }
  let parsed_extra = @json.parse(extra) catch { _ => Json::null() }
  guard parsed_extra is Object(extra_obj) else { fail("expected extra object") }
  assert_eq(extra_obj["resetsAt"], Json::string("five-reset"))
  assert_eq(extra_obj["usedValueUsd"], Json::number(1.5))
  assert_eq(extra_obj["maxValueUsd"], Json::number(6.0))
  assert_eq(extra_obj["planLabel"], Json::string("ZenMux·PRO"))
  assert_eq(
    rows[1].extra,
    Some({ "resetsAt": Json::string("week-reset") }.to_json().stringify()),
  )
}

///|
test "usage query helpers parse moonstat auto failover boolean parameters" {
  assert_eq(
    proxy_bool_request(
      "/proxy/auto-failover-enabled?appType=codex&enabled=true",
      None,
      "enabled",
    ),
    Some(true),
  )
  assert_eq(
    proxy_bool_request(
      "/proxy/auto-failover-enabled?appType=codex&enabled=0",
      None,
      "enabled",
    ),
    Some(false),
  )
  assert_eq(
    proxy_bool_request(
      "/proxy/auto-failover-enabled?enabled=maybe",
      None,
      "enabled",
    ),
    None,
  )
}

///|
test "pick directory parser accepts defaultPath payload key" {
  assert_eq(
    proxy_string_request(
      "/files/directories/pick",
      Some({ "defaultPath": Json::string("/tmp/moonstat") }.to_json()),
      "defaultPath",
    ),
    Some("/tmp/moonstat"),
  )
  assert_eq(
    proxy_string_request(
      "/files/directories/pick?defaultPath=/tmp/moonstat",
      None,
      "defaultPath",
    ),
    Some("/tmp/moonstat"),
  )
  assert_eq(
    proxy_string_request(
      "/files/directories/pick?default_path=/tmp/legacy",
      None,
      "defaultPath",
    ),
    None,
  )
}

///|
test "moonstat read command parsers accept canonical json payload keys" {
  let app_body = Some({ "appType": Json::string("codex") }.to_json())
  let app_type_body = Some({ "appType": Json::string("gemini") }.to_json())
  let provider_body = Some(
    {
      "appType": Json::string("codex"),
      "providerId": Json::string("codex-oauth"),
    }.to_json(),
  )
  assert_eq(
    moon_config_app_from_request("/config/dir", app_body),
    Some("codex"),
  )
  assert_eq(
    moon_config_app_from_request("/config/snippets", app_type_body),
    Some("gemini"),
  )
  assert_eq(
    provider_app_from_request("/providers", provider_body),
    Some("codex"),
  )
  assert_eq(
    provider_route_provider_id_from_request(
      "/providers/endpoints/list", provider_body,
    ),
    Some("codex-oauth"),
  )
  assert_eq(provider_id_from_request("/providers", provider_body), None)
  assert_eq(
    provider_route_provider_id_from_request(
      "/providers/endpoints/list?id=codex-oauth",
      None,
    ),
    None,
  )
  assert_eq(
    provider_app_from_request(
      "/providers",
      Some({ "app": Json::string("codex") }.to_json()),
    ),
    None,
  )
  assert_eq(
    provider_route_provider_id_from_request(
      "/providers/endpoints/list",
      Some({ "provider_id": Json::string("codex-oauth") }.to_json()),
    ),
    None,
  )
  assert_eq(
    proxy_string_request(
      "/mcp/validate",
      Some({ "command": Json::string("node") }.to_json()),
      "command",
    ),
    Some("node"),
  )
  assert_eq(
    hermes_memory_kind_from_request(
      "/hermes/memory",
      Some({ "kind": Json::string("user") }.to_json()),
    ),
    Some("user"),
  )
  assert_eq(
    hermes_memory_kind_from_request(
      "/hermes/memory",
      Some({ "memory_kind": Json::string("user") }.to_json()),
    ),
    None,
  )
}

///|
test "proxy failover command parsers accept canonical json payload keys" {
  let body = Some(
    {
      "appType": Json::string(" codex "),
      "providerId": Json::string("codex-oauth"),
      "enabled": Json::boolean(true),
    }.to_json(),
  )
  guard proxy_provider_query_from_request("/proxy/reset-circuit-breaker", body)
    is Some(query) else {
    fail("expected provider query")
  }
  assert_eq(query.app_type, "codex")
  assert_eq(query.provider_id, "codex-oauth")
  assert_eq(
    proxy_app_type_from_request("/proxy/failover-queue", body),
    Some("codex"),
  )
  assert_eq(
    proxy_app_type_from_request(
      "/proxy/failover-queue",
      Some({ "appType": Json::string(" gemini ") }.to_json()),
    ),
    Some("gemini"),
  )
  assert_eq(
    proxy_app_type_from_request(
      "/proxy/failover-queue",
      Some({ "app": Json::string("gemini") }.to_json()),
    ),
    None,
  )
  assert_true(
    proxy_provider_query_from_request(
      "/proxy/reset-circuit-breaker",
      Some(
        {
          "app_type": Json::string("codex"),
          "provider_id": Json::string("codex-oauth"),
        }.to_json(),
      ),
    )
    is None,
  )
  assert_eq(
    proxy_bool_request("/proxy/auto-failover-enabled", body, "enabled"),
    Some(true),
  )
  guard stream_check_provider_from_request("/proxy/stream-check/provider", body)
    is Some((stream_app, stream_provider)) else {
    fail("expected stream check provider query")
  }
  assert_eq(stream_app, " codex ")
  assert_eq(stream_provider, "codex-oauth")
  assert_eq(
    proxy_bool_request(
      "/proxy/stream-check/all",
      Some(
        {
          "appType": Json::string("claude"),
          "proxyTargetsOnly": Json::boolean(true),
        }.to_json(),
      ),
      "proxyTargetsOnly",
    ),
    Some(true),
  )
}

///|
test "moonstat settings defaults mirror desktop command payloads" {
  guard moon_default_app_settings_json() is Object(settings) else {
    fail("expected settings object")
  }
  assert_eq(proxy_json_bool(settings, "showInTray"), Some(true))
  assert_eq(proxy_json_bool(settings, "launchOnStartup"), Some(false))
  assert_eq(json_string_from_map(settings, "skillSyncMethod"), Some("auto"))
  assert_eq(
    json_string_from_map(settings, "skillStorageLocation"),
    Some("unified"),
  )

  guard moon_default_rectifier_config_json() is Object(rectifier) else {
    fail("expected rectifier object")
  }
  assert_eq(proxy_json_bool(rectifier, "enabled"), Some(true))
  assert_eq(proxy_json_bool(rectifier, "requestThinkingBudget"), Some(true))

  guard moon_default_optimizer_config_json() is Object(optimizer) else {
    fail("expected optimizer object")
  }
  assert_eq(proxy_json_bool(optimizer, "enabled"), Some(false))
  assert_eq(json_string_from_map(optimizer, "cacheTtl"), Some("1h"))

  guard moon_default_copilot_optimizer_config_json() is Object(copilot) else {
    fail("expected copilot object")
  }
  assert_eq(proxy_json_bool(copilot, "warmupDowngrade"), Some(true))
  assert_eq(json_string_from_map(copilot, "warmupModel"), Some("gpt-5-mini"))
}

///|
test "auth and copilot request helpers accept only moonstat canonical keys" {
  let canonical = Some(
    {
      "accountId": Json::string("ghe:42"),
      "authProvider": Json::string("github_copilot"),
      "githubDomain": Json::string("ghe.example.com"),
      "deviceCode": Json::string("dev-1"),
      "userCode": Json::string("user-1"),
      "warmupModel": Json::string("gpt-5-mini"),
      "stripThinking": Json::boolean(false),
    }.to_json(),
  )
  assert_eq(
    copilot_account_id_request("/copilot/token", canonical),
    Some("ghe:42"),
  )
  assert_eq(
    copilot_github_domain_request("/copilot/device-flow", canonical),
    Some("ghe.example.com"),
  )
  assert_eq(
    managed_auth_provider_request("/auth/login", canonical),
    "github_copilot",
  )
  let configured = moon_copilot_optimizer_config_from_request(
    "/settings/copilot-optimizer",
    canonical,
    moon_default_copilot_optimizer_config_json(),
  )
  guard configured is Object(configured_obj) else {
    fail("expected configured copilot optimizer")
  }
  assert_eq(
    json_string_from_map(configured_obj, "warmupModel"),
    Some("gpt-5-mini"),
  )
  assert_eq(proxy_json_bool(configured_obj, "stripThinking"), Some(false))

  let legacy = Some(
    {
      "account_id": Json::string("legacy-account"),
      "auth_provider": Json::string("github_copilot"),
      "github_domain": Json::string("legacy.example.com"),
      "device_code": Json::string("legacy-dev"),
      "user_code": Json::string("legacy-user"),
      "warmup_model": Json::string("legacy-model"),
      "strip_thinking": Json::boolean(false),
    }.to_json(),
  )
  assert_eq(copilot_account_id_request("/copilot/token", legacy), None)
  assert_eq(copilot_github_domain_request("/copilot/device-flow", legacy), None)
  assert_eq(
    managed_auth_provider_request("/auth/login", legacy),
    managed_auth_default_provider(),
  )
  let unchanged = moon_copilot_optimizer_config_from_request(
    "/settings/copilot-optimizer",
    legacy,
    moon_default_copilot_optimizer_config_json(),
  )
  guard unchanged is Object(unchanged_obj) else {
    fail("expected unchanged copilot optimizer")
  }
  assert_eq(
    json_string_from_map(unchanged_obj, "warmupModel"),
    Some("gpt-5-mini"),
  )
  assert_eq(proxy_json_bool(unchanged_obj, "stripThinking"), Some(true))
}

///|
test "moonstat save settings merge preserves omitted sync secrets" {
  let existing = {
    "webdavSync": {
      "baseUrl": Json::string("https://dav.example.com"),
      "username": Json::string("alice"),
      "password": Json::string("secret"),
    }.to_json(),
    "s3Sync": {
      "bucket": Json::string("bucket"),
      "secretAccessKey": Json::string("s3-secret"),
    }.to_json(),
    "localMigrations": {
      "codexProviderTemplateV1": {
        "completedAt": Json::string("2026-01-01T00:00:00Z"),
      }.to_json(),
    }.to_json(),
  }.to_json()
  let incoming = {
    "webdavSync": {
      "baseUrl": Json::string("https://dav.example.com"),
      "username": Json::string("alice"),
      "password": Json::string(""),
    }.to_json(),
    "s3Sync": {
      "bucket": Json::string("bucket"),
      "secretAccessKey": Json::string(""),
    }.to_json(),
  }.to_json()
  guard moon_merge_settings_for_save(incoming, existing) is Object(merged) else {
    fail("expected merged settings")
  }
  guard merged.get("webdavSync") is Some(Object(webdav)) else {
    fail("expected webdav sync")
  }
  assert_eq(json_string_from_map(webdav, "password"), Some("secret"))
  guard merged.get("s3Sync") is Some(Object(s3)) else {
    fail("expected s3 sync")
  }
  assert_eq(json_string_from_map(s3, "secretAccessKey"), Some("s3-secret"))
  assert_true(merged.get("localMigrations") is Some(_))
}

///|
test "moonstat settings config query builders update defaults" {
  let default_rectifier = moon_default_rectifier_config_json()
  guard moon_rectifier_config_from_request(
      "/settings/rectifier?requestThinkingSignature=false",
      None,
      default_rectifier,
    )
    is Object(rectifier) else {
    fail("expected rectifier")
  }
  assert_eq(proxy_json_bool(rectifier, "requestThinkingSignature"), Some(false))
  guard moon_rectifier_config_from_request(
      "/settings/rectifier?request_thinking_signature=false",
      None,
      default_rectifier,
    )
    is Object(legacy_rectifier) else {
    fail("expected legacy rectifier")
  }
  assert_eq(
    proxy_json_bool(legacy_rectifier, "requestThinkingSignature"),
    Some(true),
  )

  let optimizer = moon_optimizer_config_from_request(
    "/settings/optimizer?enabled=true&cacheTtl=5m",
    None,
    moon_default_optimizer_config_json(),
  )
  assert_true(moon_optimizer_cache_ttl_valid(optimizer))
  let legacy_optimizer_json = moon_optimizer_config_from_request(
    "/settings/optimizer?cache_ttl=30m&thinking_optimizer=false",
    None,
    moon_default_optimizer_config_json(),
  )
  guard legacy_optimizer_json is Object(legacy_optimizer) else {
    fail("expected legacy optimizer")
  }
  assert_true(moon_optimizer_cache_ttl_valid(legacy_optimizer_json))
  assert_eq(json_string_from_map(legacy_optimizer, "cacheTtl"), Some("1h"))
  assert_eq(proxy_json_bool(legacy_optimizer, "thinkingOptimizer"), Some(true))
  let invalid = moon_optimizer_config_from_request(
    "/settings/optimizer?cacheTtl=30m",
    None,
    moon_default_optimizer_config_json(),
  )
  assert_false(moon_optimizer_cache_ttl_valid(invalid))
}

///|
test "moonstat claude plugin detection matches managed primary api key" {
  assert_true(moon_json_primary_api_key_any("{\"primaryApiKey\":\"any\"}"))
  assert_false(moon_json_primary_api_key_any("{\"primaryApiKey\":\"real\"}"))
  assert_false(moon_json_primary_api_key_any("not-json"))
}

///|
test "moonstat workspace filename validators mirror OpenClaw whitelist" {
  assert_true(moon_validate_workspace_filename("AGENTS.md"))
  assert_true(moon_validate_workspace_filename("BOOTSTRAP.md"))
  assert_false(moon_validate_workspace_filename("../AGENTS.md"))
  assert_false(moon_validate_workspace_filename("notes.md"))

  assert_true(moon_validate_daily_memory_filename("2026-06-14.md"))
  assert_false(moon_validate_daily_memory_filename("2026-6-14.md"))
  assert_false(moon_validate_daily_memory_filename("../2026-06-14.md"))
  assert_false(moon_validate_daily_memory_filename("2026-06-14xmd"))
  assert_false(moon_validate_daily_memory_filename("2026-06-140md"))
  assert_eq(moon_daily_memory_date("2026-06-14.md"), "2026-06-14")
  assert_true(moon_daily_memory_list_filename("notes.md"))
  assert_false(moon_validate_daily_memory_filename("notes.md"))
  assert_eq(moon_daily_memory_date("notes.md"), "notes")
}

///|
test "moonstat daily memory search helpers count and snippet matches" {
  let (count, first) = moon_count_case_insensitive_matches(
    "Plan today. plan tomorrow. PLAN later.", "plan",
  )
  assert_eq(count, 3)
  assert_eq(first, Some(0))
  assert_eq(
    moon_search_snippet("abcdefghijklmnopqrstuvwxyz", 10),
    "abcdefghijklmnopqrstuvwxyz",
  )
}

///|
test "provider command helpers parse moonstat sort and endpoint test payloads" {
  let updates = provider_sort_updates_from_request(
    "/providers/sort-order?appType=codex&id=custom&sortIndex=2",
    None,
  )
  assert_eq(updates.length(), 1)
  assert_eq(updates[0].id, "custom")
  assert_eq(updates[0].sort_index, 2)

  let body_updates = provider_sort_updates_from_request(
    "/providers/sort-order",
    Some(
      {
        "updates": Json::array([
          { "id": Json::string("b"), "sortIndex": Json::number(0.0) }.to_json(),
          { "id": Json::string("a"), "sortIndex": Json::number(1.0) }.to_json(),
        ]),
      }.to_json(),
    ),
  )
  assert_eq(body_updates.length(), 2)
  assert_eq(body_updates[0].id, "b")
  assert_eq(body_updates[1].sort_index, 1)

  json_inspect(
    provider_endpoint_latency_results_json(
      provider_endpoint_urls_from_request(
        "/providers/test-endpoints?urls=https%3A%2F%2Fapi.example.com%2Fv1,not-a-url",
        None,
      ),
      8,
    ),
    content=[
      {
        "url": "https://api.example.com/v1",
        "latency": 0,
        "status": 200,
        "error": null,
      },
      {
        "url": "not-a-url",
        "latency": null,
        "status": null,
        "error": "URL 无效: relative URL without a base",
      },
    ],
  )

  json_inspect(provider_endpoint_latency_result_json("http://"), content={
    "url": "http://",
    "latency": null,
    "status": null,
    "error": "URL 无效: empty host",
  })

  assert_eq(provider_endpoint_sanitize_timeout_secs(Some(1)), 2)
  assert_eq(provider_endpoint_sanitize_timeout_secs(Some(999)), 30)
  assert_eq(provider_endpoint_sanitize_timeout_secs(Some(10)), 10)
  assert_eq(provider_endpoint_sanitize_timeout_secs(None), 8)
}

///|
test "provider mutation helpers reject retired snake case aliases" {
  assert_eq(
    provider_bool_from_request("/providers?addToLive=false", None, "addToLive"),
    Some(false),
  )
  assert_eq(
    provider_bool_from_request(
      "/providers?add_to_live=false",
      None,
      "addToLive",
    ),
    None,
  )
  assert_eq(
    provider_string_from_request(
      "/providers/update?originalId=old",
      None,
      "originalId",
    ),
    Some("old"),
  )
  assert_eq(
    provider_string_from_request(
      "/providers/update?original_id=old",
      None,
      "originalId",
    ),
    None,
  )
}

///|
test "universal provider helper builds moonstat provider shape from query args" {
  guard universal_provider_from_request(
      "/providers/universal?id=u%201&name=Universal+One&providerType=openai-compatible&apps=claude,codex&baseUrl=https%3A%2F%2Fapi.example.com%2Fv1&apiKey=sk-test&codexModel=gpt-5&reasoningEffort=medium",
      None,
    )
    is Some(provider) else {
    fail("expected provider")
  }
  json_inspect(provider, content={
    "id": "u 1",
    "name": "Universal One",
    "providerType": "openai-compatible",
    "apps": { "claude": true, "codex": true, "gemini": false },
    "models": { "codex": { "model": "gpt-5", "reasoningEffort": "medium" } },
    "baseUrl": "https://api.example.com/v1",
    "apiKey": "sk-test",
  })
  assert_true(
    universal_provider_from_request(
      "/providers/universal?id=legacy&provider_type=openai-compatible&base_url=https%3A%2F%2Fapi.example.com&api_key=sk-test&codex_model=gpt-5",
      None,
    )
    is Some(provider) &&
    provider is Object(obj) &&
    obj.get("baseUrl") is None &&
    obj.get("apiKey") is None &&
    obj["providerType"] == Json::string("custom"),
  )
  guard universal_provider_from_request(
      "/providers/universal",
      Some(
        { "id": Json::string("direct"), "name": Json::string("Direct") }.to_json(),
      ),
    )
    is Some(direct_provider) else {
    fail("expected direct provider")
  }
  json_inspect(direct_provider, content={ "id": "direct", "name": "Direct" })
  assert_true(
    universal_provider_from_request(
      "/providers/universal",
      Some(
        { "provider": { "id": Json::string("wrapped") }.to_json() }.to_json(),
      ),
    )
    is None,
  )
}

///|
test "provider target parses moonstat claude desktop route metadata" {
  guard provider_target_from_request(
      "/providers",
      Some(
        {
          "id": Json::string("desktop-provider"),
          "name": Json::string("Desktop Provider"),
          "notes": Json::string("Pinned fallback"),
          "modelMapping": { "sonnetModel": Json::string("mapping-fallback") }.to_json(),
          "claudeDesktopMode": Json::string("proxy"),
          "claudeDesktopModelRoutes": {
            "claude-sonnet-4-6": {
              "model": Json::string("deepseek-v4-flash [1M]"),
              "labelOverride": Json::string("DeepSeek V4 Flash"),
              "supports1m": Json::boolean(true),
            }.to_json(),
            "claude-opus-4-8": Json::string("upstream-opus"),
          }.to_json(),
        }.to_json(),
      ),
      "claude-desktop",
    )
    is Some(provider) else {
    fail("expected provider target")
  }
  assert_eq(provider.provider_id, "desktop-provider")
  assert_eq(provider.notes, Some("Pinned fallback"))
  assert_eq(provider.claude_desktop_mode, Some("proxy"))
  guard provider.model_mapping is Some(mapping) else {
    fail("expected model mapping")
  }
  assert_eq(mapping.sonnet_model, Some("mapping-fallback"))
  guard provider.claude_desktop_model_routes.get("claude-sonnet-4-6")
    is Some(route) else {
    fail("expected sonnet route")
  }
  assert_eq(route.model, "deepseek-v4-flash [1M]")
  assert_eq(route.label_override, Some("DeepSeek V4 Flash"))
  assert_eq(route.supports_1m, Some(true))
  guard provider.claude_desktop_model_routes.get("claude-opus-4-8")
    is Some(opus_route) else {
    fail("expected opus route")
  }
  assert_eq(opus_route.model, "upstream-opus")
}

///|
test "provider target ignores retired provider request aliases" {
  guard provider_target_from_request(
      "/providers?id=legacy&category=official&websiteUrl=https%3A%2F%2Flegacy.example&is_full_url=true&fullUrl=true",
      Some(
        {
          "settings_config": {
            "apiKey": Json::string("sk-legacy"),
            "baseUrl": Json::string("https://legacy.example/v1"),
          }.to_json(),
          "model_mapping": { "sonnetModel": Json::string("legacy-sonnet") }.to_json(),
          "claude_desktop_mode": Json::string("direct"),
          "limit_daily_usd": Json::string("1.00"),
        }.to_json(),
      ),
      "codex",
    )
    is Some(provider) else {
    fail("expected provider target")
  }
  assert_eq(provider.provider_id, "legacy")
  assert_eq(provider.provider_type, None)
  assert_eq(provider.base_url, None)
  assert_eq(provider.api_key, None)
  assert_false(provider.is_full_url)
  assert_true(provider.model_mapping is None)
  assert_eq(provider.claude_desktop_mode, None)
  assert_true(
    provider_limit_config_from_settings(provider.settings_config) is None,
  )
}

///|
test "provider target preserves provider limit metadata" {
  guard provider_target_from_request(
      "/providers",
      Some(
        {
          "id": Json::string("limited-provider"),
          "name": Json::string("Limited Provider"),
          "limitDailyUsd": Json::string("0.10"),
          "limitMonthlyUsd": Json::string("3.5"),
        }.to_json(),
      ),
      "codex",
    )
    is Some(provider) else {
    fail("expected limited provider")
  }
  guard provider_limit_config_from_settings(provider.settings_config)
    is Some(limits) else {
    fail("expected provider limits")
  }
  assert_eq(limits.daily_limit_usd, Some("0.10"))
  assert_eq(limits.monthly_limit_usd, Some("3.5"))
}

///|
test "gateway syncs provider limit metadata into usage limits" {
  let gateway = Gateway::new(port=0)
  let provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="limited-provider",
    provider_name="Limited Provider",
    settings_config=Some(
      {
        "limitDailyUsd": Json::string("0.10"),
        "limitMonthlyUsd": Json::string("0.30"),
      }.to_json(),
    ),
  )
  gateway.proxy.provider_router.upsert_provider(provider)
  gateway.usage.sync_provider_limits_from_target(provider)
  let now = TREND_DAY_SECONDS * 10
  gateway.usage.stats.record_request_log(
    RequestLog::new(
      request_id="req-provider-limit",
      provider_id="limited-provider",
      app_type="codex",
      model="gpt-5",
      usage=TokenUsage::new(input_tokens=1, output_tokens=1),
      total_cost_usd="0.100000",
      status_code=200,
      created_at=now,
    ),
  )
  json_inspect(
    gateway.usage.stats.provider_limit_status_json(
      "limited-provider",
      "codex",
      now_ts=Some(now),
    ),
    content={
      "providerId": "limited-provider",
      "dailyUsage": "0.100000",
      "dailyLimit": "0.10",
      "dailyExceeded": true,
      "monthlyUsage": "0.100000",
      "monthlyLimit": "0.30",
      "monthlyExceeded": false,
    },
  )
}

///|
test "gateway add provider follows moonstat current provider semantics" {
  let gateway = Gateway::new(port=0)
  gateway.proxy.add_provider_target(
    gateway.usage,
    "codex",
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
    true,
  )
  assert_eq(
    gateway.proxy.provider_router.current_provider_id("codex"),
    Some("codex-oauth"),
  )
  gateway.proxy.provider_router.current_provider_ids.remove("gemini")
  gateway.proxy.add_provider_target(
    gateway.usage,
    "gemini",
    ProviderRouteTarget::new(
      app_type="gemini",
      provider_id="gemini-alt",
      provider_name="Gemini Alt",
    ),
    true,
  )
  assert_eq(
    gateway.proxy.provider_router.current_provider_id("gemini"),
    Some("gemini-alt"),
  )
  gateway.proxy.add_provider_target(
    gateway.usage,
    "opencode",
    ProviderRouteTarget::new(
      app_type="opencode",
      provider_id="opencode-alt",
      provider_name="OpenCode Alt",
    ),
    true,
  )
  assert_eq(gateway.proxy.provider_router.current_provider_id("opencode"), None)
  assert_eq(
    gateway.proxy.provider_router.current_provider_for_moon_command("opencode"),
    "",
  )
}

///|
test "gateway update provider follows moonstat rename guards" {
  let gateway = Gateway::new(port=0)
  let missing_result = gateway.proxy.update_provider_target(
    gateway.usage,
    "opencode",
    ProviderRouteTarget::new(
      app_type="opencode",
      provider_id="opencode-next",
      provider_name="OpenCode Next",
    ),
    Some("missing-original"),
  )
  assert_eq(
    missing_result,
    Err("Original provider 'missing-original' does not exist in app 'opencode'"),
  )
  assert_true(
    gateway.proxy.provider_router.provider_by_id("opencode", "opencode-next")
    is None,
  )
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="opencode",
      provider_id="opencode-a",
      provider_name="OpenCode A",
    ),
  )
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="opencode",
      provider_id="opencode-b",
      provider_name="OpenCode B",
    ),
  )
  let duplicate_result = gateway.proxy.update_provider_target(
    gateway.usage,
    "opencode",
    ProviderRouteTarget::new(
      app_type="opencode",
      provider_id="opencode-b",
      provider_name="OpenCode B Updated",
    ),
    Some("opencode-a"),
  )
  assert_eq(
    duplicate_result,
    Err("Provider 'opencode-b' already exists in app 'opencode'"),
  )
  assert_true(
    gateway.proxy.provider_router.provider_by_id("opencode", "opencode-a")
    is Some(_),
  )
  let non_additive_result = gateway.proxy.update_provider_target(
    gateway.usage,
    "codex",
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-renamed",
      provider_name="Codex Renamed",
    ),
    Some("codex-oauth"),
  )
  assert_eq(
    non_additive_result,
    Err("Only additive-mode providers support changing provider key"),
  )
  assert_true(
    gateway.proxy.provider_router.provider_by_id("codex", "codex-renamed")
    is None,
  )
  let rename_result = gateway.proxy.update_provider_target(
    gateway.usage,
    "opencode",
    ProviderRouteTarget::new(
      app_type="opencode",
      provider_id="opencode-renamed",
      provider_name="OpenCode Renamed",
    ),
    Some("opencode-a"),
  )
  assert_eq(rename_result, Ok(()))
  assert_true(
    gateway.proxy.provider_router.provider_by_id("opencode", "opencode-a")
    is None,
  )
  assert_true(
    gateway.proxy.provider_router.provider_by_id("opencode", "opencode-renamed")
    is Some(_),
  )
}

///|
test "provider target does not derive runtime fields from stored settings" {
  guard provider_target_from_request(
      "/providers",
      Some(
        {
          "id": Json::string("stored-settings"),
          "settingsConfig": {
            "apiFormat": Json::string("openai_chat"),
            "baseUrl": Json::string("https://settings.example/v1"),
            "apiKey": Json::string("sk-settings"),
            "options": {
              "baseURL": Json::string("https://opencode.example/v1"),
              "apiKey": Json::string("sk-opencode"),
            }.to_json(),
          }.to_json(),
        }.to_json(),
      ),
      "opencode",
    )
    is Some(stored) else {
    fail("expected provider")
  }
  assert_eq(stored.api_format, None)
  assert_eq(stored.base_url, None)
  assert_eq(stored.api_key, None)
  assert_eq(stored.provider_type, None)
  guard stored.settings_config is Some(Object(settings)) else {
    fail("expected settings")
  }
  assert_eq(settings["apiFormat"], Json::string("openai_chat"))
  assert_eq(settings["baseUrl"], Json::string("https://settings.example/v1"))
  assert_eq(settings["apiKey"], Json::string("sk-settings"))
  guard provider_target_from_request(
      "/providers?baseUrl=https%3A%2F%2Fexplicit.example%2Fv1&apiKey=sk-explicit&apiFormat=openai_chat",
      Some(
        {
          "id": Json::string("explicit-provider"),
          "settingsConfig": {
            "baseUrl": Json::string("https://settings.example/v1"),
            "apiKey": Json::string("sk-settings"),
          }.to_json(),
        }.to_json(),
      ),
      "codex",
    )
    is Some(explicit) else {
    fail("expected explicit provider")
  }
  assert_eq(explicit.api_format, Some("openai_chat"))
  assert_eq(explicit.base_url, Some("https://explicit.example/v1"))
  assert_eq(explicit.api_key, Some("sk-explicit"))
}

///|
test "provider target resolves provider type from explicit fields" {
  guard provider_target_from_request(
      "/providers?baseUrl=https%3A%2F%2Fopenrouter.ai%2Fapi%2Fv1&apiKey=sk-or",
      Some({ "id": Json::string("openrouter-explicit") }.to_json()),
      "claude",
    )
    is Some(openrouter) else {
    fail("expected openrouter provider")
  }
  assert_eq(openrouter.provider_type, Some("openrouter"))
  assert_eq(openrouter.api_key, Some("sk-or"))
  guard provider_target_from_request(
      "/providers?baseUrl=https%3A%2F%2Fproxy.example&apiKey=bearer-token",
      Some(
        {
          "id": Json::string("bearer-settings"),
          "settingsConfig": { "authMode": Json::string("bearer_only") }.to_json(),
        }.to_json(),
      ),
      "claude",
    )
    is Some(bearer) else {
    fail("expected bearer provider")
  }
  assert_eq(bearer.provider_type, None)
  guard provider_target_from_request(
      "/providers?apiKey=ya29.access-token",
      Some({ "id": Json::string("gemini-oauth") }.to_json()),
      "gemini",
    )
    is Some(gemini) else {
    fail("expected gemini provider")
  }
  assert_eq(gemini.provider_type, Some("gemini_cli"))
  guard provider_target_from_request(
      "/providers?apiFormat=gemini_native&apiKey=ya29.claude-gemini",
      Some(
        {
          "id": Json::string("claude-gemini"),
          "settingsConfig": {
            "env": {
              "ANTHROPIC_BASE_URL": Json::string(
                "https://generativelanguage.googleapis.com",
              ),
              "GEMINI_API_KEY": Json::string("ya29.claude-gemini"),
            }.to_json(),
          }.to_json(),
        }.to_json(),
      ),
      "claude",
    )
    is Some(claude_gemini) else {
    fail("expected claude gemini provider")
  }
  assert_eq(claude_gemini.api_format, Some("gemini_native"))
  assert_eq(claude_gemini.api_key, Some("ya29.claude-gemini"))
  assert_eq(claude_gemini.provider_type, Some("gemini_cli"))
  guard provider_target_from_request(
      "/providers",
      Some(
        {
          "id": Json::string("claude-gemini-legacy-format"),
          "settingsConfig": {
            "api_format": Json::string("gemini_native"),
            "env": {
              "ANTHROPIC_BASE_URL": Json::string(
                "https://generativelanguage.googleapis.com",
              ),
              "GEMINI_API_KEY": Json::string("ya29.legacy"),
            }.to_json(),
          }.to_json(),
        }.to_json(),
      ),
      "claude",
    )
    is Some(legacy_format) else {
    fail("expected legacy format provider without api format")
  }
  assert_eq(legacy_format.api_format, None)
  assert_eq(legacy_format.provider_type, None)
  guard provider_target_from_request(
      "/providers",
      Some(
        {
          "id": Json::string("managed-meta"),
          "settingsConfig": {
            "meta": {
              "authBinding": {
                "source": Json::string("managedAccount"),
                "authProvider": Json::string("github-copilot"),
              }.to_json(),
            }.to_json(),
          }.to_json(),
        }.to_json(),
      ),
      "claude",
    )
    is Some(managed) else {
    fail("expected managed provider")
  }
  assert_eq(managed.provider_type, None)
}

///|
test "provider target requires explicit moonstat api format" {
  guard provider_target_from_request(
      "/providers?apiFormat=openai_chat",
      Some(
        {
          "id": Json::string("openrouter-explicit-format"),
          "settingsConfig": {
            "apiFormat": Json::string("openai_chat"),
            "env": {
              "ANTHROPIC_BASE_URL": Json::string("https://proxy.example"),
            }.to_json(),
          }.to_json(),
        }.to_json(),
      ),
      "claude",
    )
    is Some(explicit_provider) else {
    fail("expected explicit provider")
  }
  assert_eq(explicit_provider.api_format, Some("openai_chat"))

  guard provider_target_from_request(
      "/providers",
      Some(
        {
          "id": Json::string("openrouter-missing-format"),
          "settingsConfig": {
            "env": {
              "ANTHROPIC_BASE_URL": Json::string("https://proxy.example"),
            }.to_json(),
          }.to_json(),
        }.to_json(),
      ),
      "claude",
    )
    is Some(missing_provider) else {
    fail("expected provider without explicit api format")
  }
  assert_eq(missing_provider.api_format, None)
}

///|
test "provider target stores sibling meta without deriving runtime fields" {
  guard provider_target_from_request(
      "/providers",
      Some(
        {
          "id": Json::string("codex-oauth-meta"),
          "name": Json::string("Codex OAuth Meta"),
          "settingsConfig": {
            "env": {
              "ANTHROPIC_BASE_URL": Json::string(
                "https://chatgpt.com/backend-api/codex",
              ),
              "ANTHROPIC_AUTH_TOKEN": Json::string("PROXY_MANAGED"),
            }.to_json(),
          }.to_json(),
          "meta": {
            "providerType": Json::string("codex-oauth"),
            "apiFormat": Json::string("openai_responses"),
            "promptCacheKey": Json::string("stable-cache-key"),
            "codexFastMode": Json::boolean(false),
            "customUserAgent": Json::string("  codex_cli_rs/1.2.3  "),
          }.to_json(),
        }.to_json(),
      ),
      "claude",
    )
    is Some(provider) else {
    fail("expected provider")
  }
  assert_eq(provider.provider_id, "codex-oauth-meta")
  assert_eq(provider.provider_type, None)
  assert_eq(provider.api_format, None)
  assert_eq(provider.prompt_cache_key, None)
  assert_false(provider.codex_fast_mode)
  assert_eq(provider.base_url, None)
  assert_eq(provider.api_key, None)
  assert_eq(provider_custom_user_agent(provider), Some("codex_cli_rs/1.2.3"))
}

///|
test "provider target defaults missing moonstat codex fast mode to false" {
  guard provider_target_from_request(
      "/providers?providerType=codex-oauth&apiFormat=openai_responses",
      Some(
        {
          "id": Json::string("codex-oauth-default"),
          "name": Json::string("Codex OAuth Default"),
          "settingsConfig": {
            "env": {
              "ANTHROPIC_BASE_URL": Json::string(
                "https://chatgpt.com/backend-api/codex",
              ),
              "ANTHROPIC_AUTH_TOKEN": Json::string("PROXY_MANAGED"),
            }.to_json(),
          }.to_json(),
          "meta": {
            "providerType": Json::string("codex-oauth"),
            "apiFormat": Json::string("openai_responses"),
          }.to_json(),
        }.to_json(),
      ),
      "claude",
    )
    is Some(provider) else {
    fail("expected provider")
  }
  assert_eq(provider.provider_type, Some("codex_oauth"))
  assert_eq(provider.api_format, Some("openai_responses"))
  assert_false(provider.codex_fast_mode)
}

///|
test "provider target keeps moonstat custom user agent metadata" {
  guard provider_target_from_request(
      "/providers",
      Some(
        {
          "id": Json::string("ua-provider"),
          "name": Json::string("UA Provider"),
          "meta": { "customUserAgent": Json::string("  claude-cli/2.1.161  ") }.to_json(),
        }.to_json(),
      ),
      "claude",
    )
    is Some(provider) else {
    fail("expected provider target")
  }
  assert_eq(provider_custom_user_agent(provider), Some("claude-cli/2.1.161"))
  let headers = claude_compatible_provider_headers(
    "anthropic-key",
    "anthropic",
    custom_user_agent=provider_custom_user_agent(provider),
  )
  assert_eq(headers["User-Agent"], "claude-cli/2.1.161")
}

///|
test "official provider ignores moonstat custom user agent metadata" {
  guard provider_target_from_request(
      "/providers",
      Some(
        {
          "id": Json::string("official-ua-provider"),
          "name": Json::string("Official UA Provider"),
          "providerType": Json::string("official"),
          "customUserAgent": Json::string("claude-cli/2.1.161"),
          "meta": { "customUserAgent": Json::string("codex_cli_rs/0.99") }.to_json(),
        }.to_json(),
      ),
      "codex",
    )
    is Some(provider) else {
    fail("expected provider target")
  }
  assert_eq(provider.provider_type, Some("official"))
  assert_true(provider_custom_user_agent(provider) is None)
}

///|
test "moonstat custom user agent parser matches header value validation" {
  assert_eq(
    parse_custom_user_agent(Some("  CodexBot/1.0  ")),
    Some("CodexBot/1.0"),
  )
  assert_eq(
    parse_custom_user_agent(Some("claude-cli/2.1.161 \t Kimi")),
    Some("claude-cli/2.1.161 \t Kimi"),
  )
  assert_eq(
    parse_custom_user_agent(Some("claude-cli/2.1.161 中文")),
    Some("claude-cli/2.1.161 中文"),
  )
  assert_true(parse_custom_user_agent(Some("   ")) is None)
  assert_true(
    parse_custom_user_agent(Some("CodexBot/1.0\nX-Other: bad")) is None,
  )
  assert_true(parse_custom_user_agent(Some("CodexBot/1.0\rX")) is None)
  assert_true(parse_custom_user_agent(Some("CodexBot/1.0\u{0}X")) is None)
  assert_true(parse_custom_user_agent(Some("CodexBot/1.0\u{7f}X")) is None)
}

///|
test "codex compatible provider headers honor custom user agent" {
  let headers = codex_compatible_provider_headers(
    "sk-test",
    "text/event-stream",
    Some("codex_cli_rs/0.99"),
  )
  assert_eq(headers["Authorization"], "Bearer sk-test")
  assert_eq(headers["Accept"], "text/event-stream")
  assert_eq(headers["User-Agent"], "codex_cli_rs/0.99")
}

///|
test "usage query helpers parse moonstat request log parameters" {
  let path = "/usage/logs?page=2&pageSize=25&appType=codex&providerName=Codex+OAuth&model=anthropic%2Fclaude-sonnet-4.5&statusCode=200&startDate=10&endDate=20"
  assert_eq(usage_query_int(path, "page"), Some(2))
  assert_eq(usage_query_int(path, "pageSize"), Some(25))
  assert_eq(usage_query_value(path, "appType"), Some("codex"))
  assert_eq(usage_query_value(path, "providerName"), Some("Codex OAuth"))
  assert_eq(
    usage_query_value(path, "model"),
    Some("anthropic/claude-sonnet-4.5"),
  )
  assert_eq(usage_query_int(path, "statusCode"), Some(200))
  assert_eq(usage_query_int(path, "startDate"), Some(10))
  assert_eq(usage_query_int(path, "endDate"), Some(20))
  assert_eq(usage_query_int("/usage/logs?page_size=25", "pageSize"), None)
}

///|
test "usage request log helpers parse moonstat structured body filters" {
  let body = {
    "filters": {
      "appType": Json::string("codex"),
      "providerName": Json::string("Codex OAuth"),
      "model": Json::string("gpt-5"),
      "statusCode": Json::number(200.0),
      "startDate": Json::number(10.0),
      "endDate": Json::number(20.0),
    }.to_json(),
    "page": Json::number(2.0),
    "pageSize": Json::number(25.0),
  }.to_json()
  let filters = usage_request_log_filters_from_request(
    "/usage/logs",
    Some(body),
  )
  assert_eq(filters.app_type, Some("codex"))
  assert_eq(filters.provider_name, Some("Codex OAuth"))
  assert_eq(filters.model, Some("gpt-5"))
  assert_eq(filters.status_code, Some(200))
  assert_eq(filters.start_date, Some(10))
  assert_eq(filters.end_date, Some(20))
  assert_eq(usage_int_from_request("/usage/logs", Some(body), "page"), Some(2))
  assert_eq(
    usage_int_from_request("/usage/logs", Some(body), "pageSize"),
    Some(25),
  )
}

///|
test "usage request log helpers let query override moonstat body filters" {
  let body = {
    "filters": {
      "appType": Json::string("claude"),
      "providerName": Json::string("Anthropic"),
      "statusCode": Json::number(500.0),
    }.to_json(),
    "page": Json::number(9.0),
    "pageSize": Json::number(99.0),
  }.to_json()
  let path = "/usage/logs?appType=codex&providerName=OAuth&statusCode=200&page=1&pageSize=10"
  let filters = usage_request_log_filters_from_request(path, Some(body))
  assert_eq(filters.app_type, Some("codex"))
  assert_eq(filters.provider_name, Some("OAuth"))
  assert_eq(filters.status_code, Some(200))
  assert_eq(usage_int_from_request(path, Some(body), "page"), Some(1))
  assert_eq(usage_int_from_request(path, Some(body), "pageSize"), Some(10))
}

///|
test "usage aggregate helpers parse moonstat structured command args" {
  let body = {
    "startDate": Json::number(100.0),
    "endDate": Json::number(200.0),
    "appType": Json::string("codex"),
    "providerId": Json::string("codex-oauth"),
    "dailyLimitUsd": Json::string("1.25"),
    "monthlyLimitUsd": Json::number(9.5),
  }.to_json()
  let path = "/usage/summary"
  assert_eq(usage_int_from_request(path, Some(body), "startDate"), Some(100))
  assert_eq(usage_int_from_request(path, Some(body), "endDate"), Some(200))
  assert_eq(
    usage_string_from_request(path, Some(body), "appType"),
    Some("codex"),
  )
  assert_eq(
    usage_string_from_request(path, Some(body), "providerId"),
    Some("codex-oauth"),
  )
  assert_eq(
    usage_string_from_request(path, Some(body), "dailyLimitUsd"),
    Some("1.25"),
  )
  assert_eq(
    usage_string_from_request(path, Some(body), "monthlyLimitUsd"),
    Some("9.5"),
  )
  assert_eq(
    usage_string_from_request(
      path,
      Some({ "provider_id": Json::string("legacy") }.to_json()),
      "providerId",
    ),
    None,
  )
}

///|
test "usage aggregate helpers prefer query params over moonstat body args" {
  let body = {
    "startDate": Json::number(100.0),
    "endDate": Json::number(200.0),
    "appType": Json::string("claude"),
  }.to_json()
  let path = "/usage/provider-stats?startDate=10&endDate=20&appType=codex"
  assert_eq(usage_int_from_request(path, Some(body), "startDate"), Some(10))
  assert_eq(usage_int_from_request(path, Some(body), "endDate"), Some(20))
  assert_eq(
    usage_string_from_request(path, Some(body), "appType"),
    Some("codex"),
  )
}

///|
async test "provider usage query returns cached script result first" {
  let usage = UsageService::new()
  let router = ProviderRouter::new()
  let cached = UsageResult::new(
    true,
    data=Some([
      UsageData::new(
        plan_name=Some("Cached"),
        remaining=Some(42.0),
        unit=Some("USD"),
        is_valid=Some(true),
      ),
    ]),
  )
  usage.usage_cache.put_script("codex", "cached-provider", cached)
  assert_eq(
    usage
    .query_provider_usage_standalone("codex", "cached-provider", router)
    .to_json(),
    cached.to_json(),
  )
}

///|
async test "provider usage query falls back to native balance credentials" {
  let usage = UsageService::new()
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="openrouter-native",
      provider_name="OpenRouter",
      provider_type=Some("openrouter"),
      base_url=Some("https://openrouter.ai/api/v1"),
      api_key=Some(""),
    ),
  )
  assert_eq(
    usage
    .query_provider_usage_standalone("codex", "openrouter-native", router)
    .to_json(),
    UsageResult::new(false, error=Some("API key is empty")).to_json(),
  )
  assert_eq(
    usage
    .query_provider_usage_standalone("codex", "missing-provider", router)
    .to_json(),
    UsageResult::new(false, error=Some("Usage query is disabled")).to_json(),
  )
}

///|
async test "moonstat open folder helper creates directory and returns boolean success" {
  @fsx.with_temporary_directory("moonstat-open-folder-XXXXXX", async fn(
    tmpdir,
  ) {
    let target = @pathx.join(tmpdir, "nested/config")
    assert_false(@fsx.exists(target))
    guard moon_open_directory_result_json(target) is Ok(result) else {
      fail("expected open directory result")
    }
    assert_eq(result, Json::boolean(true))
    assert_true(@fsx.exists(target))
    assert_true(@fsx.kind(target) is Directory)
  })
}

///|
test "provider selection errors use moonstat proxy error codes" {
  assert_eq(
    provider_selection_error_status(AllProvidersCircuitOpen),
    @status.ServiceUnavailable,
  )
  assert_eq(
    provider_selection_error_code(AllProvidersCircuitOpen),
    "moonstat_all_providers_circuit_open",
  )
  guard provider_selection_error_json(AllProvidersCircuitOpen, "codex")
    is Object(body) else {
    fail("expected provider selection error body")
  }
  guard body["error"] is Object(error) else { fail("expected error object") }
  assert_eq(error["code"], Json::string("moonstat_all_providers_circuit_open"))
  assert_eq(error["type"], Json::string("proxy_error"))
  assert_eq(error["param"], Json::null())
  assert_eq(error["app_type"], Json::string("codex"))
  assert_eq(
    error["selection_error"],
    Json::string("all_providers_circuit_open"),
  )
  assert_true(
    provider_selection_error_message(AllProvidersCircuitOpen, "codex").contains(
      "all provider circuits are open",
    ),
  )
}

///|
test "proxy global config exposes standalone moonstat shape" {
  let gateway = Gateway::new(port=17004, host="127.0.0.5", model="gpt-5")
  guard gateway.proxy.global_config_json() is Object(config) else {
    fail("expected proxy global config object")
  }
  assert_eq(config["proxyEnabled"], Json::boolean(true))
  assert_eq(config["listenAddress"], Json::string("127.0.0.5"))
  assert_eq(config["listenPort"], Json::number(17004.0))
  assert_eq(config["enableLogging"], Json::boolean(true))
  assert_true(config.get("listen_address") is None)
  assert_true(config.get("listen_port") is None)
  assert_true(config.get("enable_logging") is None)
}

///|
test "global proxy url helpers use moonstat response shapes" {
  assert_true(upstream_proxy_url_is_valid("http://127.0.0.1:7890"))
  assert_true(upstream_proxy_url_is_valid("socks5://127.0.0.1:1080"))
  assert_false(upstream_proxy_url_is_valid("ftp://127.0.0.1:21"))
  json_inspect(proxy_test_result_json(""), content={
    "success": false,
    "latencyMs": 0,
    "error": "Proxy URL is empty",
  })
  json_inspect(proxy_test_result_json("ftp://127.0.0.1:21"), content={
    "success": false,
    "latencyMs": 0,
    "error": "Invalid proxy URL",
  })
  json_inspect(proxy_test_result_json("http://127.0.0.1:7890"), content={
    "success": true,
    "latencyMs": 0,
    "error": null,
  })
}

///|
test "moonstat local proxy scan catalog mirrors moonstat common ports" {
  let ports = moon_local_proxy_ports()
  assert_eq(ports.length(), 8)
  assert_eq(ports[0], (7890, "http", true))
  assert_eq(ports[1], (7891, "socks5", false))
  assert_eq(ports[2], (1080, "socks5", false))
  assert_eq(ports[3], (8080, "http", false))
  assert_eq(ports[4], (8888, "http", false))
  assert_eq(ports[5], (3128, "http", false))
  assert_eq(ports[6], (10808, "socks5", false))
  assert_eq(ports[7], (10809, "http", false))
}

///|
test "moonstat local proxy scan expands mixed ports into http and socks5 entries" {
  json_inspect(
    Json::array(moon_detected_proxy_entries_json(7890, "http", true)),
    content=[
      { "url": "http://127.0.0.1:7890", "proxyType": "http", "port": 7890 },
      { "url": "socks5://127.0.0.1:7890", "proxyType": "socks5", "port": 7890 },
    ],
  )
  json_inspect(
    Json::array(moon_detected_proxy_entries_json(1080, "socks5", false)),
    content=[
      { "url": "socks5://127.0.0.1:1080", "proxyType": "socks5", "port": 1080 },
    ],
  )
}

///|
test "suite config helpers mirror moonstat openclaw hermes shapes" {
  json_inspect(openclaw_default_tools_json(), content={
    "allow": [],
    "deny": [],
  })
  json_inspect(
    openclaw_default_model_from_request(
      "/openclaw/default-model?primary=gpt-5&fallbacks=sonnet%2Copus",
      None,
    ).unwrap(),
    content={ "primary": "gpt-5", "fallbacks": ["sonnet", "opus"] },
  )
  json_inspect(
    suite_object_request(
      "/openclaw/model-catalog?catalog=%7B%22fast%22%3A%7B%22alias%22%3A%22f%22%7D%7D",
      None,
      "catalog",
    ).unwrap(),
    content={ "fast": { "alias": "f" } },
  )
  json_inspect(
    suite_object_request(
      "/openclaw/model-catalog",
      Some({ "fast": { "alias": "f" } }.to_json()),
      "catalog",
    ).unwrap(),
    content={ "fast": { "alias": "f" } },
  )
  assert_true(
    suite_object_request(
      "/openclaw/model-catalog",
      Some({ "catalog": { "fast": { "alias": "f" } } }.to_json()),
      "catalog",
    )
    is None,
  )
  json_inspect(
    openclaw_default_model_from_request(
      "/openclaw/default-model",
      Some(
        {
          "primary": Json::string("gpt-5"),
          "fallbacks": Json::array([Json::string("sonnet")]),
        }.to_json(),
      ),
    ).unwrap(),
    content={ "primary": "gpt-5", "fallbacks": ["sonnet"] },
  )
  assert_true(
    openclaw_default_model_from_request(
      "/openclaw/default-model",
      Some({ "model": { "primary": "gpt-5" } }.to_json()),
    )
    is None,
  )
  json_inspect(
    openclaw_env_from_request(
      "/openclaw/env",
      Some({ "OPENAI_API_KEY": "sk-new" }.to_json()),
    ).unwrap(),
    content={ "OPENAI_API_KEY": "sk-new" },
  )
  assert_true(
    openclaw_env_from_request(
      "/openclaw/env",
      Some({ "env": { "OPENAI_API_KEY": "sk-old" } }.to_json()),
    )
    is None,
  )
  json_inspect(
    hermes_memory_limits_json(Map([("memory", false), ("user", true)])),
    content={
      "memory": 2200,
      "user": 1375,
      "memoryEnabled": false,
      "userEnabled": true,
    },
  )
  assert_eq(
    hermes_memory_kind_from_request("/hermes/memory?kind=user", None),
    Some("user"),
  )
  assert_eq(
    hermes_memory_kind_from_request("/hermes/memory?kind=bad", None),
    None,
  )
  assert_eq(
    hermes_memory_kind_from_request("/hermes/memory?memoryKind=user", None),
    None,
  )
  assert_true(
    openclaw_env_from_request(
      "/openclaw/env?name=OPENAI_API_KEY&value=sk-old",
      None,
    )
    is None,
  )
  assert_eq(hermes_web_port_from_request("/hermes/web-ui?port=9120"), 9120)
  assert_eq(
    proxy_string_request(
      "/hermes/web-ui",
      Some({ "path": Json::string("/config") }.to_json()),
      "path",
    ),
    Some("/config"),
  )
  assert_eq(hermes_web_ui_path(""), "/")
  assert_eq(hermes_web_ui_path("settings/models"), "/settings/models")
  assert_eq(hermes_web_ui_path("/settings/models"), "/settings/models")
  assert_eq(
    hermes_web_ui_target_url(9120, "settings/models"),
    "http://127.0.0.1:9120/settings/models",
  )
  assert_eq(hermes_web_ui_probe_url(9120), "http://127.0.0.1:9120/api/status")
  assert_eq(HERMES_DASHBOARD_COMMAND, "hermes dashboard")
  assert_eq(
    hermes_dashboard_background_shell_command(),
    "nohup hermes dashboard >/tmp/moonstat_hermes_dashboard.log 2>&1 &",
  )
}

///|
test "openclaw health scanner reports current moonstat warning rules" {
  let config = {
    "tools": { "profile": Json::string("dangerous") }.to_json(),
    "agents": {
      "defaults": {
        "timeout": Json::number(30.0),
        "timeoutSeconds": Json::number(30.0),
      }.to_json(),
    }.to_json(),
    "env": {
      "vars": Json::string("{\"OPENAI_API_KEY\":\"sk\"}"),
      "shellEnv": Json::array([]),
    }.to_json(),
  }.to_json()
  json_inspect(openclaw_config_health_from_json(config), content=[
    {
      "code": "invalid_tools_profile",
      "message": "tools.profile uses unsupported value 'dangerous'.",
      "path": "tools.profile",
    },
    {
      "code": "stringified_env_vars",
      "message": "env.vars should be an object. The current value looks stringified or malformed.",
      "path": "env.vars",
    },
    {
      "code": "stringified_env_shell_env",
      "message": "env.shellEnv should be an object. The current value looks stringified or malformed.",
      "path": "env.shellEnv",
    },
  ])
}

///|
test "openclaw health scanner accepts supported profiles and object env" {
  let config = {
    "tools": { "profile": Json::string("coding") }.to_json(),
    "agents": { "defaults": { "timeoutSeconds": Json::number(30.0) }.to_json() }.to_json(),
    "env": {
      "vars": { "OPENAI_API_KEY": Json::string("sk") }.to_json(),
      "shellEnv": { "PATH": Json::string("/usr/bin") }.to_json(),
    }.to_json(),
  }.to_json()
  assert_eq(openclaw_config_health_from_json(config), Json::array([]))
}

///|
test "proxy app config exposes standalone moonstat shape" {
  let gateway = Gateway::new(port=17005, host="127.0.0.6", model="gpt-5")
  guard gateway.proxy.app_config_json("claude") is Object(config) else {
    fail("expected proxy app config object")
  }
  assert_eq(config["appType"], Json::string("claude"))
  assert_eq(config["enabled"], Json::boolean(true))
  assert_eq(config["autoFailoverEnabled"], Json::boolean(false))
  assert_eq(config["maxRetries"], Json::number(6.0))
  assert_eq(config["streamingFirstByteTimeout"], Json::number(90.0))
  assert_eq(config["streamingIdleTimeout"], Json::number(180.0))
  assert_eq(config["nonStreamingTimeout"], Json::number(600.0))
  assert_eq(config["circuitFailureThreshold"], Json::number(8.0))
  assert_eq(config["circuitSuccessThreshold"], Json::number(3.0))
  assert_eq(config["circuitTimeoutSeconds"], Json::number(90.0))
  assert_eq(config["circuitErrorRateThreshold"], Json::number(0.7))
  assert_eq(config["circuitMinRequests"], Json::number(15.0))
  assert_true(config.get("app_type") is None)
  assert_true(config.get("auto_failover_enabled") is None)
  assert_true(config.get("max_retries") is None)
  assert_true(config.get("streaming_first_byte_timeout") is None)
  assert_true(config.get("streaming_idle_timeout") is None)
  assert_true(config.get("non_streaming_timeout") is None)
  assert_true(config.get("circuit_failure_threshold") is None)
  assert_true(config.get("circuit_success_threshold") is None)
  assert_true(config.get("circuit_timeout_seconds") is None)
  assert_true(config.get("circuit_error_rate_threshold") is None)
  assert_true(config.get("circuit_min_requests") is None)
  guard gateway.proxy.app_config_json("gemini") is Object(gemini) else {
    fail("expected gemini proxy app config object")
  }
  assert_eq(gemini["maxRetries"], Json::number(5.0))
  assert_eq(gemini["streamingFirstByteTimeout"], Json::number(60.0))
  assert_eq(gemini["circuitFailureThreshold"], Json::number(4.0))
  guard gateway.proxy.app_config_json("unknown") is Object(unknown) else {
    fail("expected unknown proxy app config object")
  }
  assert_eq(unknown["enabled"], Json::boolean(false))
}

///|
test "proxy global config state updates standalone config shape" {
  let gateway = Gateway::new(port=17006, host="127.0.0.7", model="gpt-5")
  gateway.proxy.proxy_enabled = false
  gateway.proxy.proxy_listen_address = "127.0.0.8"
  gateway.proxy.proxy_listen_port = 17007
  gateway.proxy.proxy_enable_logging = false
  gateway.proxy.proxy_takeover_enabled.set("codex", true)
  guard gateway.proxy.global_config_json() is Object(global_config) else {
    fail("expected global config object")
  }
  assert_eq(global_config["proxyEnabled"], Json::boolean(false))
  assert_eq(global_config["listenAddress"], Json::string("127.0.0.8"))
  assert_eq(global_config["listenPort"], Json::number(17007.0))
  assert_eq(global_config["enableLogging"], Json::boolean(false))
  guard gateway.proxy.takeover_status_json() is Object(takeover) else {
    fail("expected takeover object")
  }
  assert_eq(takeover["codex"], Json::boolean(true))
  assert_eq(takeover["claude"], Json::boolean(false))
}

///|
test "proxy lifecycle state matches moonstat command aliases" {
  let gateway = Gateway::new(port=17016, host="127.0.0.16", model="gpt-5")
  gateway.proxy.proxy_enabled = false
  guard gateway.proxy.server_info_json(gateway.started_at_ms)
    is Object(server_info) else {
    fail("expected server info")
  }
  assert_eq(server_info["address"], Json::string("127.0.0.16"))
  assert_eq(server_info["port"], Json::number(17016.0))
  gateway.proxy.proxy_takeover_enabled.set("codex", true)
  assert_true(gateway.proxy.takeover_active())
  assert_eq(
    moon_stop_proxy_takeover_error(),
    "仍有应用处于代理接管状态，请先在设置中关闭对应应用接管后再停止本地路由。",
  )
  gateway.proxy.clear_takeover()
  assert_false(gateway.proxy.takeover_active())
  gateway.proxy.proxy_enabled = true
  gateway.proxy.proxy_app_enabled.set("claude", true)
  gateway.proxy.proxy_app_enabled.set("codex", true)
  gateway.proxy.proxy_app_enabled.set("gemini", true)
  gateway.proxy.provider_router.set_failover_queue("codex", ["codex-oauth"])
  gateway.proxy.provider_router.set_auto_failover("codex", true)
  gateway.proxy.clear_enabled_apps_for_manual_stop()
  assert_false(gateway.proxy.app_enabled_for_app("claude"))
  assert_false(gateway.proxy.app_enabled_for_app("codex"))
  assert_false(gateway.proxy.app_enabled_for_app("gemini"))
  assert_true(
    gateway.proxy.provider_router.auto_failover_enabled_for_app("codex"),
  )
  json_inspect(gateway.proxy.provider_router.failover_queue_json("codex"), content=[
    {
      "providerId": "codex-oauth",
      "providerName": "Codex OAuth",
      "sortIndex": null,
    },
  ])
}

///|
test "moonstat auto failover enable requires proxy takeover" {
  let gateway = Gateway::new(port=17017, host="127.0.0.17", model="gpt-5")
  assert_true(gateway.proxy.can_set_auto_failover("codex", true))
  assert_true(gateway.proxy.can_set_auto_failover("codex", false))
  gateway.proxy.proxy_app_enabled.set("codex", false)
  assert_false(gateway.proxy.can_set_auto_failover("codex", true))
  assert_true(gateway.proxy.can_set_auto_failover("codex", false))
  gateway.proxy.proxy_app_enabled.set("codex", true)
  assert_true(gateway.proxy.can_set_auto_failover("codex", true))
}

///|
test "moonstat unit commands return null success body" {
  assert_eq(moon_unit_success_json(), Json::null())
}

///|
fn service_handler_uses_unit_success(
  source : String,
  owner : String,
  handler : String,
) -> Bool {
  let marker = "async fn \{owner}::\{handler}("
  let mut seen_marker = false
  for segment in source.split(marker) {
    if seen_marker {
      for block in segment.split("///|") {
        return block.contains("write_usage_json(w, moon_unit_success_json())")
      }
    }
    seen_marker = true
  }
  false
}

///|
async test "moonstat proxy mutation command handlers return unit success bodies" {
  let source = @fsx.read_file("gateway_proxy.mbt")
  for
    entry in [
      ("ProxyService", "handle_proxy_status"),
      ("ProxyService", "handle_proxy_start_server"),
      ("ProxyService", "handle_proxy_stop_server"),
      ("ProxyService", "handle_proxy_stop_with_restore"),
      ("ProxyService", "handle_proxy_running"),
      ("ProxyService", "handle_proxy_update_global_config"),
      ("ProxyService", "handle_proxy_update_app_config"),
      ("ProxyService", "handle_proxy_set_default_cost_multiplier"),
      ("ProxyService", "handle_proxy_set_pricing_model_source"),
      ("ProxyService", "handle_proxy_update_circuit_breaker_config"),
      ("ProxyService", "handle_proxy_set_takeover_for_app"),
      ("ProxyService", "handle_proxy_switch_provider"),
    ] {
    let (owner, handler) = entry
    if handler == "handle_proxy_status" ||
      handler == "handle_proxy_start_server" ||
      handler == "handle_proxy_running" {
      assert_true(source.contains("async fn \{owner}::\{handler}("))
    } else {
      assert_true(service_handler_uses_unit_success(source, owner, handler))
    }
  }
  for
    handler in [
      "handle_proxy_status", "handle_proxy_start_server", "handle_proxy_stop_server",
      "handle_proxy_stop_with_restore", "handle_proxy_running", "handle_proxy_switch_provider",
    ] {
    assert_false(source.contains("async fn Gateway::\{handler}("))
  }
  let route_source = @fsx.read_file("gateway_proxy_routes.mbt")
  assert_true(
    route_source.contains("self.handle_proxy_switch_provider(usage, r, w)"),
  )
}

///|
async test "auth endpoints are owned by auth service" {
  let auth_source = @fsx.read_file("gateway_auth.mbt")
  let copilot_source = @fsx.read_file("gateway_copilot.mbt")
  let route_source = @fsx.read_file("gateway_auth_routes.mbt")
  let auth_sources = auth_source + copilot_source
  let core_source = @fsx.read_file("gateway_core.mbt")
  for
    handler in [
      "handle_auth_start_login", "handle_auth_poll_for_account", "handle_auth_get_status",
      "handle_auth_logout", "handle_copilot_get_auth_status", "handle_copilot_get_token",
      "handle_copilot_poll_for_account", "handle_copilot_list_accounts", "handle_copilot_remove_account",
      "handle_copilot_set_default_account", "handle_copilot_get_models", "handle_copilot_get_usage",
      "validate_claude_desktop_gateway_auth",
    ] {
    assert_true(auth_sources.contains("async fn AuthService::\{handler}("))
    assert_false(auth_sources.contains("async fn Gateway::\{handler}("))
  }
  assert_true(core_source.contains("self.auth.register_routes(router)"))
  for
    handler in [
      "handle_auth_start_login", "handle_auth_get_status", "handle_copilot_get_token",
      "handle_copilot_poll_for_account", "handle_copilot_list_accounts", "handle_copilot_get_models",
      "handle_copilot_get_usage",
    ] {
    assert_true(route_source.contains("self.\{handler}("))
  }
  assert_true(route_source.contains("Delete, \"/auth/account\""))
  assert_false(route_source.contains("Post, \"/auth/account\""))
  assert_true(route_source.contains("Delete, \"/copilot/account\""))
  assert_false(route_source.contains("Post, \"/copilot/account\""))
  let claude_anthropic_source = @fsx.read_file("gateway_claude_anthropic.mbt")
  assert_true(
    claude_anthropic_source.contains(
      "auth.validate_claude_desktop_gateway_auth(self, usage, r, w)",
    ),
  )
}

///|
async test "usage accounting is owned by usage service" {
  let usage_source = @fsx.read_file("gateway_usage.mbt")
  let route_source = @fsx.read_file("gateway_usage_routes.mbt")
  let core_source = @fsx.read_file("gateway_core.mbt")
  let auth_source = @fsx.read_file("gateway_auth.mbt")
  let misc_source = @fsx.read_file("gateway_misc.mbt")
  let provider_source = @fsx.read_file("gateway_provider.mbt")
  let old_gateway_sources = auth_source + misc_source + provider_source
  for
    helper in [
      "record_success_usage_with_provider", "record_success_stream_usage_with_provider",
      "record_bad_request_with_provider", "record_unauthorized_with_provider", "record_upstream_error_status_with_provider",
      "record_internal_error_with_provider", "record_provider_result", "release_provider_permit_neutral",
    ] {
    assert_true(usage_source.contains("UsageService::\{helper}("))
    assert_false(old_gateway_sources.contains("Gateway::\{helper}("))
  }
  for
    helper in [
      "record_success_usage", "record_success_stream_usage", "record_bad_request",
      "record_unauthorized", "record_upstream_error_status", "record_internal_error",
      "record_provider_result", "release_provider_permit_neutral",
    ] {
    assert_false(old_gateway_sources.contains("Gateway::\{helper}("))
  }
  assert_true(
    core_source.contains(
      "self.usage.register_routes(router, self.auth, self.proxy.provider_router)",
    ),
  )
  assert_true(core_source.contains("self.usage.register_status_routes("))
  for
    handler in [
      "handle_health", "handle_status", "handle_stats", "handle_metrics", "handle_usage_logs",
      "handle_usage_summary", "handle_usage_summary_by_app", "handle_usage_trends",
      "handle_usage_provider_limits", "handle_usage_provider_stats", "handle_usage_model_stats",
      "handle_usage_data_sources", "handle_query_provider_usage", "handle_get_balance",
      "handle_get_subscription_quota", "handle_get_coding_plan_quota", "handle_test_usage_script",
      "handle_usage_sync_session", "handle_usage_model_pricing", "handle_usage_update_model_pricing",
      "handle_usage_delete_model_pricing", "handle_usage_request_detail",
    ] {
    assert_true(route_source.contains("self.\{handler}("))
  }
  assert_true(route_source.contains("auth.handle_get_codex_oauth_quota("))
  assert_true(route_source.contains("auth.handle_get_codex_oauth_models("))
}

///|
async test "copilot optimizer config endpoints are owned by config service" {
  let copilot_source = @fsx.read_file("gateway_copilot.mbt")
  let route_source = @fsx.read_file("gateway_config_routes.mbt")
  for
    handler in [
      "handle_get_copilot_optimizer_config", "handle_set_copilot_optimizer_config",
    ] {
    assert_true(copilot_source.contains("async fn ConfigService::\{handler}("))
    assert_false(copilot_source.contains("async fn Gateway::\{handler}("))
  }
  assert_true(
    route_source.contains("self.handle_get_copilot_optimizer_config(w)"),
  )
  assert_true(
    route_source.contains("self.handle_set_copilot_optimizer_config(r, w)"),
  )
}

///|
async test "settings mcp and prompt endpoints are owned by config service" {
  let misc_source = @fsx.read_file("gateway_misc.mbt")
  let config_source = @fsx.read_file("gateway_config.mbt")
  let config_runtime_source = @fsx.read_file("gateway_config_runtime.mbt")
  let mcp_prompt_source = @fsx.read_file("gateway_config_mcp_prompt.mbt")
  let deeplink_source = @fsx.read_file("gateway_deeplink.mbt")
  let deeplink_helpers_source = @fsx.read_file("deeplink.mbt")
  let import_export_source = @fsx.read_file("import_export.mbt")
  let sync_source = @fsx.read_file("sync.mbt")
  let route_source = @fsx.read_file("gateway_config_routes.mbt")
  let suite_root = "/tmp/moonstat-config-suite"
  let book_root = @pathx.join(suite_root, "books/research-demo")
  let app_config_dir = moon_app_config_dir_for_workspace_root(book_root)
  assert_eq(
    app_config_dir,
    @pathx.join(suite_root, ".moonsuite/products/moonstat"),
  )
  assert_false(app_config_dir.contains("books/research-demo/.moonsuite"))
  assert_false(
    config_source.contains("@moonsuite.product_dir(\"\", \"moonstat\")"),
  )
  let config_sources = misc_source +
    config_source +
    config_runtime_source +
    mcp_prompt_source +
    deeplink_source +
    deeplink_helpers_source +
    import_export_source +
    sync_source
  let core_source = @fsx.read_file("gateway_core.mbt")
  for
    handler in [
      "handle_set_window_theme", "handle_enter_lightweight_mode", "handle_exit_lightweight_mode",
      "handle_is_lightweight_mode", "handle_set_auto_launch", "handle_get_auto_launch_status",
      "handle_get_common_config_snippet", "handle_get_common_config_snippet_request",
      "handle_set_common_config_snippet", "handle_set_common_config_snippet_request",
      "handle_extract_common_config_snippet", "handle_check_env_conflicts", "handle_delete_env_vars",
      "handle_restore_env_backup", "handle_get_claude_mcp_status", "handle_read_claude_mcp_config",
      "handle_upsert_claude_mcp_server", "handle_delete_mcp_server", "handle_validate_mcp_command",
      "handle_get_mcp_config", "handle_upsert_mcp_server_in_config", "handle_set_mcp_enabled",
      "handle_get_mcp_servers", "handle_upsert_mcp_server", "handle_toggle_mcp_app",
      "handle_import_mcp_from_apps", "handle_get_prompts", "handle_upsert_prompt",
      "handle_delete_prompt", "handle_enable_prompt", "handle_parse_deeplink", "handle_webdav_sync_save_settings",
      "handle_import_from_deeplink", "handle_s3_sync_save_settings", "handle_get_stream_check_config",
      "handle_save_stream_check_config", "handle_get_claude_plugin_status", "handle_read_claude_plugin_config",
      "handle_apply_claude_plugin_config", "handle_is_claude_plugin_applied", "handle_apply_claude_onboarding_skip",
      "handle_clear_claude_onboarding_skip", "handle_fetch_models_for_config", "handle_export_config_to_file",
      "handle_import_config_from_file", "handle_create_db_backup", "handle_restore_db_backup",
      "handle_webdav_test_connection", "handle_webdav_sync_operation", "handle_webdav_sync_fetch_remote_info",
      "handle_s3_test_connection", "handle_s3_sync_operation", "handle_s3_sync_fetch_remote_info",
    ] {
    assert_true(config_sources.contains("async fn ConfigService::\{handler}("))
    assert_false(config_sources.contains("async fn Gateway::\{handler}("))
  }
  for
    handler in [
      "handle_set_window_theme", "handle_enter_lightweight_mode", "handle_exit_lightweight_mode",
      "handle_is_lightweight_mode", "handle_set_auto_launch", "handle_get_auto_launch_status",
      "handle_check_env_conflicts", "handle_delete_env_vars", "handle_get_claude_plugin_status",
      "handle_is_claude_plugin_applied", "handle_apply_claude_onboarding_skip", "handle_clear_claude_onboarding_skip",
      "handle_webdav_test_connection", "handle_webdav_sync_operation", "handle_webdav_sync_fetch_remote_info",
      "handle_s3_test_connection", "handle_s3_sync_operation", "handle_s3_sync_fetch_remote_info",
    ] {
    assert_true(
      config_runtime_source.contains("async fn ConfigService::\{handler}("),
    )
    assert_false(misc_source.contains("async fn ConfigService::\{handler}("))
  }
  for
    helper in [
      "moon_export_snapshot_json", "moon_export_config_to_file_json", "moon_import_config_from_file_json",
      "moon_apply_import_snapshot", "moon_create_db_backup_json", "moon_restore_db_backup_json",
      "moon_sync_build_local_snapshot", "moon_persist_webdav_sync_success", "moon_persist_s3_sync_success",
      "moon_webdav_sync_upload_json", "moon_s3_sync_upload_json", "moon_apply_webdav_snapshot",
      "moon_webdav_sync_download_json", "moon_s3_sync_download_json", "moon_import_from_deeplink_json",
      "moon_import_provider_deeplink", "moon_import_prompt_deeplink", "moon_import_mcp_deeplink",
      "moon_import_skill_deeplink",
    ] {
    assert_true(config_sources.contains("ConfigService::\{helper}("))
    assert_false(config_sources.contains("Gateway::\{helper}("))
  }
  for
    helper in [
      "moon_export_proxy_json", "moon_export_proxy_app_configs_json", "moon_export_providers_json",
      "moon_apply_import_proxy",
    ] {
    assert_true(import_export_source.contains("ProxyService::\{helper}("))
    assert_false(import_export_source.contains("Gateway::\{helper}("))
  }
  assert_true(
    core_source.contains(
      "self.config.register_routes(router, self.proxy, self.host, bound_port)",
    ),
  )
  assert_true(route_source.contains("self.handle_set_window_theme(r, w)"))
  assert_true(
    route_source.contains(
      "self.handle_get_common_config_snippet(w, \"claude\")",
    ),
  )
  assert_true(route_source.contains("self.handle_get_mcp_config(r, w)"))
  assert_true(route_source.contains("self.handle_upsert_prompt(r, w)"))
  for
    handler in [
      "handle_get_claude_mcp_status", "handle_upsert_claude_mcp_server", "handle_delete_mcp_server",
      "handle_validate_mcp_command", "handle_set_mcp_enabled", "handle_get_mcp_servers",
      "handle_upsert_mcp_server", "handle_toggle_mcp_app", "handle_import_mcp_from_apps",
      "handle_get_prompts", "handle_upsert_prompt", "handle_delete_prompt", "handle_enable_prompt",
    ] {
    assert_true(
      mcp_prompt_source.contains("async fn ConfigService::\{handler}("),
    )
    assert_false(misc_source.contains("async fn ConfigService::\{handler}("))
  }
  for
    helper in [
      "moon_mcp_apps_json", "moon_mcp_app_enabled", "moon_mcp_server_with_app", "moon_mcp_server_from_request",
      "moon_mcp_server_from_spec", "moon_mcp_normalize_server", "moon_mcp_servers_object_for_app",
      "moon_mcp_valid_server_spec", "moon_mcp_import_spec_for_app", "moon_import_mcp_servers_map",
      "moon_import_mcp_from_root_json", "moon_import_mcp_from_codex_toml_text", "moon_codex_raw_mcp_spec",
      "moon_codex_mcp_section", "moon_codex_mcp_unified_spec", "moon_codex_mcp_core_field",
      "moon_toml_strip_comment", "moon_toml_assignment", "moon_toml_value", "moon_toml_split_csv",
      "moon_clean_blank_lines", "moon_validate_mcp_command_name", "moon_prompt_store_key",
      "moon_prompt_from_request", "moon_normalize_prompt", "moon_prompts_object_for_app",
    ] {
    assert_true(mcp_prompt_source.contains("fn \{helper}("))
    assert_false(misc_source.contains("fn \{helper}("))
  }
  for helper in ["moon_import_mcp_from_apps_count", "moon_enable_prompt_json"] {
    assert_true(mcp_prompt_source.contains("async fn \{helper}("))
    assert_false(misc_source.contains("async fn \{helper}("))
  }
  assert_true(route_source.contains("self.handle_parse_deeplink(r, w)"))
  assert_true(
    route_source.contains("self.handle_import_from_deeplink(proxy, r, w)"),
  )
  assert_true(
    route_source.contains("self.handle_webdav_sync_save_settings(r, w)"),
  )
  assert_true(route_source.contains("self.handle_webdav_test_connection(r, w)"))
  assert_true(route_source.contains("self.handle_webdav_sync_operation("))
  assert_true(
    route_source.contains("self.handle_webdav_sync_fetch_remote_info(w)"),
  )
  assert_true(route_source.contains("self.handle_s3_sync_save_settings(r, w)"))
  assert_true(route_source.contains("self.handle_s3_test_connection(r, w)"))
  assert_true(route_source.contains("self.handle_s3_sync_operation("))
  assert_true(route_source.contains("self.handle_s3_sync_fetch_remote_info(w)"))
  assert_true(route_source.contains("self.handle_get_stream_check_config(w)"))
  assert_true(
    route_source.contains("self.handle_save_stream_check_config(r, w)"),
  )
  assert_true(route_source.contains("self.handle_get_claude_plugin_status(w)"))
  assert_true(route_source.contains("self.handle_read_claude_plugin_config(w)"))
  assert_true(
    route_source.contains("self.handle_apply_claude_plugin_config(r, w)"),
  )
  assert_true(route_source.contains("self.handle_is_claude_plugin_applied(w)"))
  assert_true(
    route_source.contains("self.handle_apply_claude_onboarding_skip(w)"),
  )
  assert_true(
    route_source.contains("self.handle_clear_claude_onboarding_skip(w)"),
  )
  assert_true(
    route_source.contains("self.handle_fetch_models_for_config(r, w)"),
  )
  assert_true(route_source.contains("self.handle_get_auto_launch_status(w)"))
  assert_true(route_source.contains("self.handle_export_config_to_file("))
  assert_true(route_source.contains("self.handle_import_config_from_file("))
  assert_true(route_source.contains("self.handle_create_db_backup("))
  assert_true(
    route_source.contains("self.handle_restore_db_backup(proxy, r, w)"),
  )
}

///|
async test "workspace endpoints are owned by workspace service" {
  let workspace_source = @fsx.read_file("gateway_workspace.mbt")
  let route_source = @fsx.read_file("gateway_workspace_routes.mbt")
  let core_source = @fsx.read_file("gateway_core.mbt")
  for
    handler in [
      "handle_save_file_dialog", "handle_read_omo_local_file", "handle_open_file_dialog",
      "handle_open_zip_file_dialog", "handle_list_daily_memory_files", "handle_read_daily_memory_file",
      "handle_write_daily_memory_file", "handle_search_daily_memory_files", "handle_delete_daily_memory_file",
      "handle_read_workspace_file", "handle_write_workspace_file", "handle_open_workspace_directory",
      "handle_import_prompt_from_file", "handle_get_current_prompt_file_content",
      "write_static_file", "handle_register_page", "handle_dashboard_page",
    ] {
    assert_true(
      workspace_source.contains("async fn WorkspaceService::\{handler}("),
    )
    assert_false(workspace_source.contains("async fn Gateway::\{handler}("))
  }
  assert_true(core_source.contains("self.workspace.register_routes("))
  assert_true(core_source.contains("bound_port"))
  assert_true(route_source.contains("self.handle_save_file_dialog(r, w)"))
  assert_true(route_source.contains("router.add_handler(Get, \"/\","))
  assert_true(route_source.contains("router.add_handler(Get, \"/ui/rabbita\""))
  assert_true(
    route_source.contains("self.handle_dashboard_page(w, host, port)"),
  )
  assert_true(
    route_source.contains("self.handle_read_omo_local_file(w, slim=false)"),
  )
  assert_false(
    route_source.contains("proxy.handle_get_current_omo_provider_id"),
  )
  assert_false(route_source.contains("proxy.handle_disable_current_omo"))
  assert_true(
    route_source.contains("self.handle_open_workspace_directory(r, w)"),
  )
  assert_true(
    route_source.contains("self.handle_import_prompt_from_file(config, r, w)"),
  )
  assert_true(
    route_source.contains("self.handle_get_current_prompt_file_content(r, w)"),
  )
  assert_true(route_source.contains("self.handle_register_page(logger, w)"))
}

///|
async test "runtime endpoints are owned by runtime service" {
  let runtime_source = @fsx.read_file("gateway_runtime.mbt")
  let misc_source = @fsx.read_file("gateway_misc.mbt")
  let route_source = @fsx.read_file("gateway_runtime_routes.mbt")
  let core_source = @fsx.read_file("gateway_core.mbt")
  for
    handler in [
      "handle_pick_directory", "handle_copy_text_to_clipboard", "handle_update_tray_menu",
      "handle_is_portable_mode", "handle_get_tool_versions", "handle_run_tool_lifecycle_action",
      "handle_probe_tool_installations", "handle_restart_app", "handle_install_update_and_restart",
    ] {
    assert_true(runtime_source.contains("async fn RuntimeService::\{handler}("))
    assert_false(runtime_source.contains("async fn Gateway::\{handler}("))
    assert_false(misc_source.contains("async fn RuntimeService::\{handler}("))
  }
  assert_true(core_source.contains("self.runtime.register_routes(router)"))
  for
    handler in [
      "handle_pick_directory", "handle_update_tray_menu", "handle_get_tool_versions",
      "handle_probe_tool_installations", "handle_restart_app",
    ] {
    assert_true(route_source.contains("self.\{handler}("))
  }
  assert_true(runtime_source.contains("fn RuntimeService::uptime_seconds("))
  assert_false(runtime_source.contains("fn Gateway::uptime_seconds("))
  assert_false(misc_source.contains("fn Gateway::uptime_seconds("))
  assert_true(
    core_source.contains("self.runtime.uptime_seconds(self.started_at_ms)"),
  )
}

///|
async test "external utility endpoints are owned by runtime service" {
  let source = @fsx.read_file("gateway_runtime.mbt")
  let misc_source = @fsx.read_file("gateway_misc.mbt")
  let route_source = @fsx.read_file("gateway_runtime_routes.mbt")
  for handler in ["handle_open_external", "handle_check_for_updates"] {
    assert_true(source.contains("async fn RuntimeService::\{handler}("))
    assert_false(source.contains("async fn Gateway::\{handler}("))
    assert_false(misc_source.contains("async fn RuntimeService::\{handler}("))
  }
  assert_true(source.contains("fn RuntimeService::record_external_open("))
  assert_false(source.contains("fn Gateway::record_external_open("))
  assert_false(misc_source.contains("fn RuntimeService::record_external_open("))
  assert_true(route_source.contains("self.handle_open_external(r, w)"))
  assert_true(route_source.contains("self.handle_check_for_updates(w)"))
}

///|
async test "provider config endpoints are owned by proxy service" {
  let codex_openai_source = @fsx.read_file("gateway_codex_openai.mbt")
  let claude_anthropic_source = @fsx.read_file("gateway_claude_anthropic.mbt")
  let claude_media_source = @fsx.read_file("gateway_claude_anthropic_media.mbt")
  let claude_stream_bridge_source = @fsx.read_file(
    "gateway_claude_anthropic_stream_bridge.mbt",
  )
  let claude_codex_stream_source = @fsx.read_file(
    "gateway_claude_anthropic_codex_stream.mbt",
  )
  let claude_protocol_source = claude_anthropic_source +
    claude_media_source +
    claude_stream_bridge_source +
    claude_codex_stream_source
  let provider_source = @fsx.read_file("gateway_provider.mbt")
  let auth_source = @fsx.read_file("gateway_auth.mbt")
  let claude_desktop_source = @fsx.read_file("gateway_claude_desktop.mbt")
  let endpoint_source = @fsx.read_file("gateway_provider_endpoints.mbt")
  let stream_check_source = @fsx.read_file("gateway_stream_check.mbt")
  let proxy_source = @fsx.read_file("gateway_proxy.mbt")
  let config_source = @fsx.read_file("gateway_config.mbt")
  let misc_source = @fsx.read_file("gateway_misc.mbt")
  let route_source = @fsx.read_file("gateway_proxy_routes.mbt")
  let workspace_route_source = @fsx.read_file("gateway_workspace_routes.mbt")
  let omo_source = @fsx.read_file("omo.mbt")
  let usage_source = @fsx.read_file("gateway_usage.mbt")
  let sources = codex_openai_source +
    claude_protocol_source +
    provider_source +
    auth_source +
    claude_desktop_source +
    endpoint_source +
    stream_check_source +
    proxy_source +
    config_source +
    misc_source +
    route_source +
    omo_source
  let core_source = @fsx.read_file("gateway_core.mbt")
  for
    handler in [
      "handle_import_default_config", "handle_claude_desktop_provider_import", "handle_claude_desktop_provider_official",
      "handle_scan_local_proxies", "handle_test_api_endpoints", "handle_get_custom_endpoints",
      "handle_add_custom_endpoint", "handle_remove_custom_endpoint", "handle_update_endpoint_last_used",
      "handle_claude_desktop_provider_status", "handle_claude_desktop_provider_default_routes",
      "handle_get_current_omo_provider_id", "handle_disable_current_omo", "handle_stream_check_provider",
      "handle_stream_check_all_providers", "handle_models", "handle_claude_desktop_models",
      "handle_gemini", "handle_chat_completions", "forward_non_streaming_chat_completion",
      "forward_streaming_chat_completion", "handle_codex_responses", "forward_non_streaming_codex_response",
      "forward_streaming_codex_response", "handle_messages", "forward_non_streaming_claude_compatible_request",
      "handle_non_streaming_request", "forward_streaming_claude_compatible_request",
      "forward_successful_claude_compatible_stream", "handle_streaming_request",
      "forward_openai_chat_sse_as_anthropic", "forward_anthropic_sse_passthrough",
      "forward_gemini_native_sse_as_anthropic",
    ] {
    assert_true(sources.contains("async fn ProxyService::\{handler}("))
    assert_false(sources.contains("async fn Gateway::\{handler}("))
  }
  for
    handler in [
      "handle_test_api_endpoints", "handle_get_custom_endpoints", "handle_add_custom_endpoint",
      "handle_remove_custom_endpoint", "handle_update_endpoint_last_used",
    ] {
    assert_true(endpoint_source.contains("async fn ProxyService::\{handler}("))
    assert_false(misc_source.contains("async fn ProxyService::\{handler}("))
  }
  for
    handler in [
      "handle_codex_responses", "handle_chat_completions", "forward_non_streaming_chat_completion",
      "forward_streaming_chat_completion", "forward_non_streaming_codex_response",
      "forward_streaming_codex_response",
    ] {
    assert_true(
      codex_openai_source.contains("async fn ProxyService::\{handler}("),
    )
    assert_false(misc_source.contains("async fn ProxyService::\{handler}("))
  }
  for
    helper in [
      "fn codex_forward_failed_error_message(", "fn codex_forward_failed_error_json(",
      "fn codex_forward_failed_error_body(", "fn codex_backend_responses_endpoint(",
      "fn endpoint_with_request_query(", "fn codex_request_model(",
    ] {
    assert_true(codex_openai_source.contains(helper))
    assert_false(misc_source.contains(helper))
  }
  for
    handler in [
      "handle_messages", "forward_non_streaming_claude_compatible_request", "handle_non_streaming_request",
      "forward_streaming_claude_compatible_request", "forward_successful_claude_compatible_stream",
      "handle_streaming_request", "forward_openai_chat_sse_as_anthropic", "forward_anthropic_sse_passthrough",
      "forward_gemini_native_sse_as_anthropic",
    ] {
    assert_true(
      claude_protocol_source.contains("async fn ProxyService::\{handler}("),
    )
    assert_false(misc_source.contains("async fn ProxyService::\{handler}("))
  }
  for
    handler in [
      "forward_openai_chat_sse_as_anthropic", "forward_anthropic_sse_passthrough",
      "forward_gemini_native_sse_as_anthropic",
    ] {
    assert_true(
      claude_stream_bridge_source.contains("async fn ProxyService::\{handler}("),
    )
    assert_false(
      claude_anthropic_source.contains("async fn ProxyService::\{handler}("),
    )
  }
  for
    helper in [
      "fn ProxyService::upstream_claude_model(", "fn claude_request_json_for_upstream(",
      "fn claude_compatible_response_to_anthropic(", "priv struct ResponsesStreamState",
      "fn ResponsesStreamState::new(",
    ] {
    assert_true(claude_protocol_source.contains(helper))
    assert_false(misc_source.contains(helper))
  }
  assert_true(claude_media_source.contains("fn prepare_upstream_request_body("))
  assert_true(
    claude_media_source.contains("fn replace_images_for_text_only_model("),
  )
  assert_true(
    claude_codex_stream_source.contains("priv struct ResponsesStreamState"),
  )
  for
    helper in [
      "struct StreamCheckConfig", "fn StreamCheckConfig::default(", "fn StreamCheckConfig::to_json(",
      "fn stream_check_int_request(", "fn stream_check_string_request(", "fn stream_check_model_for_app(",
      "fn stream_check_reported_model_for_app(", "fn stream_check_parse_model_with_effort(",
    ] {
    assert_true(stream_check_source.contains(helper))
    assert_false(misc_source.contains(helper))
  }
  for
    helper in [
      "post_codex_compatible_provider_json", "post_codex_compatible_provider_stream",
      "post_claude_compatible_provider_json", "activate_provider", "activate_first_available_provider",
      "activate_first_available_provider_excluding", "activate_provider_target",
      "activate_next_provider_after_upstream_status", "active_provider_target", "forward_gemini_get",
      "forward_gemini_post", "all_provider_circuits_open", "selected_provider_chain",
      "claude_provider_outbound_body", "upstream_claude_model",
    ] {
    assert_true(sources.contains("fn ProxyService::\{helper}("))
    assert_false(sources.contains("async fn Gateway::\{helper}("))
    assert_false(sources.contains("fn Gateway::\{helper}("))
  }
  assert_false(sources.contains("fn Gateway::pricing_override_rows("))
  assert_true(
    proxy_source.contains("fn ProxyService::provider_cost_multiplier("),
  )
  assert_true(
    proxy_source.contains("fn ProxyService::provider_pricing_model_source("),
  )
  assert_true(
    provider_source.contains(
      "fn SessionService::codex_provider_outbound_request(",
    ),
  )
  assert_false(sources.contains("fn Gateway::codex_provider_outbound_request("))
  assert_true(auth_source.contains("async fn AuthService::codex_client("))
  assert_false(misc_source.contains("async fn AuthService::codex_client("))
  assert_false(sources.contains("async fn Gateway::codex_client("))
  assert_true(
    auth_source.contains("async fn AuthService::load_startup_credentials("),
  )
  assert_true(core_source.contains("self.auth.load_startup_credentials("))
  assert_false(core_source.contains("@codex.load_credentials()"))
  assert_true(core_source.contains("self.proxy.register_inference_routes("))
  assert_true(route_source.contains("self.handle_models(w)"))
  assert_true(route_source.contains("self.handle_gemini(usage, r, w)"))
  assert_true(route_source.contains("self.handle_messages("))
  assert_true(route_source.contains("self.handle_chat_completions("))
  assert_true(route_source.contains("self.handle_codex_responses("))
  assert_true(
    route_source.contains(
      "self.handle_claude_desktop_models(auth, usage, r, w)",
    ),
  )
  assert_true(
    usage_source.contains(
      "async fn UsageService::write_provider_selection_error(",
    ),
  )
  assert_false(
    provider_source.contains(
      "async fn Gateway::write_provider_selection_error(",
    ),
  )
  assert_true(
    provider_source.contains(
      "fn ProxyService::stream_check_provider_result_json(",
    ),
  )
  assert_false(
    provider_source.contains("fn Gateway::stream_check_provider_result_json("),
  )
  assert_true(
    provider_source.contains(
      "fn ProxyService::current_claude_desktop_provider(",
    ),
  )
  assert_true(omo_source.contains("fn ProxyService::current_omo_provider_id("))
  assert_true(
    omo_source.contains("fn ProxyService::clear_current_omo_provider("),
  )
  assert_true(
    omo_source.contains("async fn ProxyService::handle_disable_current_omo("),
  )
  assert_false(
    misc_source.contains("async fn ProxyService::handle_disable_current_omo("),
  )
  assert_false(
    provider_source.contains("fn Gateway::current_claude_desktop_provider("),
  )
  assert_false(omo_source.contains("fn Gateway::current_omo_provider_id("))
  assert_false(omo_source.contains("fn Gateway::clear_current_omo_provider("))
  assert_true(route_source.contains("self.handle_import_default_config(r, w)"))
  assert_true(
    route_source.contains(
      "self.handle_get_current_omo_provider_id(w, slim=false)",
    ),
  )
  assert_true(
    route_source.contains("self.handle_disable_current_omo(w, slim=false)"),
  )
  assert_true(
    route_source.contains(
      "self.handle_get_current_omo_provider_id(w, slim=true)",
    ),
  )
  assert_true(
    route_source.contains("self.handle_disable_current_omo(w, slim=true)"),
  )
  assert_true(route_source.contains("self.handle_stream_check_provider("))
  assert_true(route_source.contains("self.handle_stream_check_all_providers("))
  assert_true(
    route_source.contains("self.handle_claude_desktop_provider_import(w)"),
  )
  assert_true(
    route_source.contains("self.handle_claude_desktop_provider_official(w)"),
  )
  assert_true(route_source.contains("self.handle_scan_local_proxies(w)"))
  assert_true(route_source.contains("self.handle_test_api_endpoints(r, w)"))
  assert_true(route_source.contains("self.handle_get_custom_endpoints(r, w)"))
  assert_true(route_source.contains("self.handle_add_custom_endpoint(r, w)"))
  assert_true(route_source.contains("self.handle_remove_custom_endpoint(r, w)"))
  assert_true(
    route_source.contains("self.handle_update_endpoint_last_used(r, w)"),
  )
  assert_true(
    route_source.contains(
      "self.handle_claude_desktop_provider_status(host, port, w)",
    ),
  )
  assert_true(
    route_source.contains(
      "self.handle_claude_desktop_provider_default_routes(w)",
    ),
  )
  for
    handler in [
      "handle_scan_local_proxies", "handle_claude_desktop_provider_status", "handle_claude_desktop_provider_default_routes",
    ] {
    assert_true(
      claude_desktop_source.contains("async fn ProxyService::\{handler}("),
    )
    assert_false(misc_source.contains("async fn ProxyService::\{handler}("))
  }
  for
    helper in ["claude_desktop_status_json", "claude_desktop_expected_base_url"] {
    assert_true(claude_desktop_source.contains("fn ProxyService::\{helper}("))
    assert_false(misc_source.contains("fn ProxyService::\{helper}("))
  }
  assert_false(
    workspace_route_source.contains("proxy.handle_get_current_omo_provider_id"),
  )
  assert_false(
    workspace_route_source.contains("proxy.handle_disable_current_omo"),
  )
}

///|
async test "skill endpoints are owned by skill service" {
  let skill_source = @fsx.read_file("gateway_skill.mbt")
  let misc_source = @fsx.read_file("gateway_misc.mbt")
  let route_source = @fsx.read_file("gateway_skill_routes.mbt")
  let core_source = @fsx.read_file("gateway_core.mbt")
  for
    handler in [
      "handle_get_installed_skills", "handle_install_skill_unified", "handle_uninstall_skill_unified",
      "handle_toggle_skill_app", "handle_scan_unmanaged_skills", "handle_import_skills_from_apps",
      "handle_discover_available_skills", "handle_check_skill_updates", "handle_update_skill",
      "handle_migrate_skill_storage", "handle_search_skills_sh", "handle_get_skills",
      "handle_get_skill_repos", "handle_add_skill_repo", "handle_remove_skill_repo",
      "handle_install_skills_from_zip", "handle_get_skill_backups", "handle_delete_skill_backup",
      "handle_restore_skill_backup",
    ] {
    assert_true(skill_source.contains("async fn SkillService::\{handler}("))
    assert_false(skill_source.contains("async fn Gateway::\{handler}("))
    assert_false(misc_source.contains("async fn SkillService::\{handler}("))
  }
  assert_true(core_source.contains("self.skills.register_routes(router)"))
  for
    handler in [
      "handle_get_installed_skills", "handle_install_skill_unified", "handle_add_skill_repo",
      "handle_get_skill_backups", "handle_delete_skill_backup", "handle_restore_skill_backup",
    ] {
    assert_true(route_source.contains("self.\{handler}("))
  }
}

///|
async test "session endpoints are owned by session service" {
  let session_source = @fsx.read_file("gateway_session.mbt")
  let route_source = @fsx.read_file("gateway_session_routes.mbt")
  let core_source = @fsx.read_file("gateway_core.mbt")
  for
    handler in [
      "handle_list_sessions", "handle_get_session_messages", "handle_launch_session_terminal",
      "handle_delete_session", "handle_delete_sessions",
    ] {
    assert_true(session_source.contains("async fn SessionService::\{handler}("))
    assert_false(session_source.contains("async fn Gateway::\{handler}("))
    assert_true(route_source.contains("self.\{handler}("))
  }
  assert_true(core_source.contains("self.session.register_routes("))
}

///|
async test "openclaw endpoints are owned by openclaw service" {
  let config_source = @fsx.read_file("gateway_config.mbt")
  let openclaw_source = @fsx.read_file("gateway_openclaw.mbt")
  let route_source = @fsx.read_file("gateway_openclaw_routes.mbt")
  let sources = config_source + openclaw_source
  let core_source = @fsx.read_file("gateway_core.mbt")
  for
    handler in [
      "handle_scan_openclaw_config_health", "handle_get_openclaw_default_model",
      "handle_set_openclaw_default_model", "handle_get_openclaw_model_catalog", "handle_set_openclaw_model_catalog",
      "handle_get_openclaw_agents_defaults", "handle_set_openclaw_agents_defaults",
      "handle_get_openclaw_env", "handle_set_openclaw_env", "handle_get_openclaw_tools",
      "handle_set_openclaw_tools", "handle_get_hermes_model_config", "handle_get_hermes_memory",
      "handle_set_hermes_memory", "handle_get_hermes_memory_limits", "handle_set_hermes_memory_enabled",
      "handle_open_hermes_web_ui", "handle_launch_hermes_dashboard",
    ] {
    assert_true(sources.contains("async fn OpenClawService::\{handler}("))
    assert_false(sources.contains("async fn Gateway::\{handler}("))
    assert_true(route_source.contains("self.\{handler}("))
  }
  assert_true(
    config_source.contains("fn OpenClawService::openclaw_config_health_json("),
  )
  assert_false(
    config_source.contains("fn Gateway::openclaw_config_health_json("),
  )
  assert_true(core_source.contains("self.openclaw.register_routes(router)"))
}

///|
test "standalone tray update mirrors moonstat no tray result" {
  assert_eq(moon_update_tray_menu_result(), Json::boolean(false))
}

///|
test "gateway defaults are owned by suite contract" {
  let gateway = Gateway::new(port=@suite.default_port())
  assert_eq(gateway.host, @suite.default_host())
  assert_eq(gateway.model, @suite.default_model())
}

///|
test "standalone external open records moonstat normalized target" {
  let runtime = RuntimeService::new()
  assert_eq(runtime.last_external_url, None)
  assert_eq(
    runtime.record_external_open("github.com/vectie/moonstat"),
    "https://github.com/vectie/moonstat",
  )
  assert_eq(
    runtime.last_external_url,
    Some("https://github.com/vectie/moonstat"),
  )
  assert_eq(
    runtime.record_external_open("HTTP://github.com/vectie/moonstat"),
    "https://HTTP://github.com/vectie/moonstat",
  )
  assert_eq(
    runtime.last_external_url,
    Some("https://HTTP://github.com/vectie/moonstat"),
  )
}

///|
test "standalone update check records moonstat release target" {
  let runtime = RuntimeService::new()
  assert_eq(runtime.record_external_open(moon_update_url()), moon_update_url())
  assert_eq(runtime.last_external_url, Some(moon_update_url()))
}

///|
test "proxy app config state updates moonstat app fields" {
  let gateway = Gateway::new(port=17008, host="127.0.0.9", model="gpt-5")
  gateway.proxy.proxy_app_enabled.set("codex", false)
  gateway.proxy.provider_router.set_max_retries("codex", 5)
  gateway.proxy.proxy_streaming_first_byte_timeout.set("codex", 11)
  gateway.proxy.proxy_streaming_idle_timeout.set("codex", 22)
  gateway.proxy.proxy_non_streaming_timeout.set("codex", 33)
  gateway.proxy.provider_router.update_all_configs({
    failure_threshold: 7,
    success_threshold: 3,
    timeout_seconds: 44,
    error_rate_threshold: 0.4,
    min_requests: 12,
  })
  guard gateway.proxy.app_config_json("codex") is Object(config) else {
    fail("expected app config object")
  }
  assert_eq(config["enabled"], Json::boolean(false))
  assert_eq(config["maxRetries"], Json::number(5.0))
  assert_eq(config["streamingFirstByteTimeout"], Json::number(11.0))
  assert_eq(config["streamingIdleTimeout"], Json::number(22.0))
  assert_eq(config["nonStreamingTimeout"], Json::number(33.0))
  assert_eq(config["circuitFailureThreshold"], Json::number(7.0))
  assert_eq(config["circuitSuccessThreshold"], Json::number(3.0))
  assert_eq(config["circuitTimeoutSeconds"], Json::number(44.0))
  assert_eq(config["circuitErrorRateThreshold"], Json::number(0.4))
  assert_eq(config["circuitMinRequests"], Json::number(12.0))
}

///|
test "proxy app config circuit updates are app scoped" {
  let gateway = Gateway::new(port=17009, host="127.0.0.10", model="gpt-5")
  gateway.proxy.provider_router.update_app_configs("claude", {
    failure_threshold: 9,
    success_threshold: 4,
    timeout_seconds: 77,
    error_rate_threshold: 0.5,
    min_requests: 13,
  })
  guard gateway.proxy.app_config_json("claude") is Object(claude) else {
    fail("expected claude app config object")
  }
  guard gateway.proxy.app_config_json("codex") is Object(codex) else {
    fail("expected codex app config object")
  }
  assert_eq(claude["circuitFailureThreshold"], Json::number(9.0))
  assert_eq(claude["circuitSuccessThreshold"], Json::number(4.0))
  assert_eq(claude["circuitTimeoutSeconds"], Json::number(77.0))
  assert_eq(claude["circuitErrorRateThreshold"], Json::number(0.5))
  assert_eq(claude["circuitMinRequests"], Json::number(13.0))
  assert_eq(codex["circuitFailureThreshold"], Json::number(4.0))
  assert_eq(codex["circuitSuccessThreshold"], Json::number(2.0))
  assert_eq(codex["circuitTimeoutSeconds"], Json::number(60.0))
}

///|
test "stream check config accepts moonstat canonical body and query fields" {
  let config = stream_check_config_from_request(
    "/proxy/stream-check/config?geminiModel=gemini-test&testPrompt=Ping",
    (
      #|{"timeoutSecs":30,"maxRetries":1,"degradedThresholdMs":5000,"claudeModel":"claude-test","codexModel":"codex-test"}
    ),
    StreamCheckConfig::default(),
  )
  guard config is Some(config) else { fail("expected stream check config") }
  assert_eq(config.timeout_secs, 30)
  assert_eq(config.max_retries, 1)
  assert_eq(config.degraded_threshold_ms, 5000)
  assert_eq(config.claude_model, "claude-test")
  assert_eq(config.codex_model, "codex-test")
  assert_eq(config.gemini_model, "gemini-test")
  assert_eq(config.test_prompt, "Ping")
  assert_true(
    stream_check_config_from_request(
      "/proxy/stream-check/config?timeoutSecs=0",
      "",
      StreamCheckConfig::default(),
    )
    is None,
  )
  assert_true(
    stream_check_config_from_request(
      "/proxy/stream-check/config",
      (
        #|{"config":{"timeoutSecs":30,"maxRetries":1,"claudeModel":"legacy"}}
      ),
      StreamCheckConfig::default(),
    )
    is None,
  )
}

///|
test "stream check result uses moonstat camelCase shape" {
  let gateway = Gateway::new(port=17017, host="127.0.0.17", model="gpt-5")
  gateway.config.stream_check_config = {
    ..gateway.config.stream_check_config,
    codex_model: "codex-check-model",
  }
  guard gateway.proxy.stream_check_provider_result_json(
      gateway.config.stream_check_config,
      "codex",
      "codex-oauth",
    )
    is Some(Object(result)) else {
    fail("expected stream check result")
  }
  assert_eq(result["status"], Json::string("operational"))
  assert_eq(result["success"], Json::boolean(true))
  assert_eq(result["message"], Json::string("Check succeeded"))
  assert_eq(result["modelUsed"], Json::string("codex-check-model"))
  assert_eq(result["retryCount"], Json::number(0.0))
  assert_eq(result["httpStatus"], Json::number(200.0))
  guard result.get("testedAt") is Some(Number(_)) else {
    fail("expected testedAt")
  }
}

///|
test "stream check strips moonstat codex effort suffix from result model" {
  let gateway = Gateway::new(port=17018, host="127.0.0.18", model="gpt-5")
  gateway.config.stream_check_config = {
    ..gateway.config.stream_check_config,
    codex_model: "gpt-5.5@low",
    claude_model: "claude-sonnet-4-5#high",
  }
  guard gateway.proxy.stream_check_provider_result_json(
      gateway.config.stream_check_config,
      "codex",
      "codex-oauth",
    )
    is Some(Object(result)) else {
    fail("expected stream check result")
  }
  assert_eq(result["modelUsed"], Json::string("gpt-5.5"))
  assert_eq(
    stream_check_reported_model_for_app(
      gateway.config.stream_check_config,
      "claude",
    ),
    "claude-sonnet-4-5#high",
  )
}

///|
test "stream check provider test config overrides global config like moonstat" {
  let gateway = Gateway::new(port=17019, host="127.0.0.19", model="gpt-5")
  gateway.config.stream_check_config = {
    ..gateway.config.stream_check_config,
    codex_model: "global-model@low",
    test_prompt: "global prompt",
  }
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-provider-test",
      provider_name="Codex Provider Test",
      settings_config=Some(
        {
          "meta": {
            "testConfig": {
              "enabled": Json::boolean(true),
              "testModel": Json::string("provider-model@medium"),
              "timeoutSecs": Json::number(12.0),
              "maxRetries": Json::number(5.0),
              "degradedThresholdMs": Json::number(1234.0),
              "testPrompt": Json::string("provider prompt"),
            }.to_json(),
          }.to_json(),
        }.to_json(),
      ),
    ),
  )
  guard gateway.proxy.provider_router.provider_by_id(
      "codex", "codex-provider-test",
    )
    is Some(provider) else {
    fail("expected provider")
  }
  let config = stream_check_effective_config_for_provider(
    gateway.config.stream_check_config,
    provider,
  )
  assert_eq(config.codex_model, "provider-model@medium")
  assert_eq(config.claude_model, "provider-model@medium")
  assert_eq(config.gemini_model, "provider-model@medium")
  assert_eq(config.timeout_secs, 12)
  assert_eq(config.max_retries, 5)
  assert_eq(config.degraded_threshold_ms, 1234)
  assert_eq(config.test_prompt, "provider prompt")
  guard gateway.proxy.stream_check_provider_result_json(
      gateway.config.stream_check_config,
      "codex",
      "codex-provider-test",
    )
    is Some(Object(result)) else {
    fail("expected stream check result")
  }
  assert_eq(result["modelUsed"], Json::string("provider-model"))
}

///|
test "stream check codex effort parser follows moonstat separators" {
  assert_eq(
    stream_check_parse_model_with_effort("gpt-5.1-codex@low").0,
    "gpt-5.1-codex",
  )
  assert_eq(
    stream_check_parse_model_with_effort("o1-preview#high").0,
    "o1-preview",
  )
  assert_eq(
    stream_check_parse_model_with_effort("gpt-4o-mini").0,
    "gpt-4o-mini",
  )
  assert_eq(
    stream_check_parse_model_with_effort("gpt-5.1-codex@").0,
    "gpt-5.1-codex@",
  )
}

///|
test "stream check all provider ids follow moonstat proxy target filter" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="b",
      provider_name="B",
      base_url=Some("https://b.example.com"),
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="a",
      provider_name="A",
      base_url=Some("https://a.example.com"),
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="c",
      provider_name="C",
      base_url=Some("https://c.example.com"),
    ),
  )
  router.set_current_provider("codex", "b")
  router.set_failover_queue("codex", ["c", "b"])
  assert_eq(router.stream_check_provider_ids("codex", false), ["a", "b", "c"])
  assert_eq(router.stream_check_provider_ids("codex", true), ["b", "c"])
}

///|
test "proxy config request parsers accept canonical moonstat fields" {
  let config = Some(
    {
      "proxyEnabled": Json::boolean(false),
      "listenAddress": Json::string("127.0.0.10"),
      "listenPort": Json::number(17010.0),
      "enableLogging": Json::string("off"),
      "maxRetries": Json::string("6"),
      "errorRateThreshold": Json::number(0.35),
    }.to_json(),
  )
  assert_eq(
    proxy_bool_request("/proxy/global-config", config, "proxyEnabled"),
    Some(false),
  )
  assert_eq(
    proxy_string_request("/proxy/global-config", config, "listenAddress"),
    Some("127.0.0.10"),
  )
  assert_eq(
    proxy_int_request("/proxy/global-config", config, "listenPort"),
    Some(17010),
  )
  assert_eq(
    proxy_bool_request("/proxy/global-config", config, "enableLogging"),
    Some(false),
  )
  assert_eq(
    proxy_int_request("/proxy/app-config", config, "maxRetries"),
    Some(6),
  )
  assert_eq(
    proxy_double_request("/proxy/app-config", config, "errorRateThreshold"),
    Some(0.35),
  )
  assert_eq(
    proxy_int_request("/proxy/app-config?max_retries=8", None, "maxRetries"),
    None,
  )
  assert_eq(
    proxy_bool_request("/proxy/takeover-status?enabled=yes", None, "enabled"),
    Some(true),
  )
  assert_eq(
    proxy_app_type_from_request(
      "/set_default_cost_multiplier?appType=codex&value=1.25",
      None,
    ),
    Some("codex"),
  )
  assert_eq(
    proxy_app_type_from_request(
      "/set_pricing_model_source_test_hook",
      Some(
        {
          "appType": Json::string(" claude "),
          "value": Json::string("request"),
        }.to_json(),
      ),
    ),
    Some("claude"),
  )
  assert_eq(
    proxy_app_type_from_request(
      "/proxy/app-config?appType=codex&enabled=true",
      None,
    ),
    Some("codex"),
  )
  assert_eq(
    proxy_app_type_from_request(
      "/proxy/takeover-status",
      Some(
        { "appType": Json::string(" gemini "), "enabled": Json::boolean(true) }.to_json(),
      ),
    ),
    Some("gemini"),
  )
  assert_eq(
    proxy_app_type_from_request(
      "/providers/switch?appType=codex&id=custom",
      None,
    ),
    Some("codex"),
  )
  assert_eq(
    proxy_app_type_from_request("/proxy/app-config?app_type=codex", None),
    None,
  )
}

///|
test "proxy circuit config request parser merges partial app config" {
  let current = CircuitBreakerConfig::default()
  let next = proxy_circuit_config_from_request(
    "/proxy/app-config?failureThreshold=9&errorRateThreshold=0.25",
    None,
    current,
  ).unwrap()
  assert_eq(next.failure_threshold, 9)
  assert_eq(next.success_threshold, current.success_threshold)
  assert_eq(next.error_rate_threshold, 0.25)
  assert_true(
    proxy_circuit_config_from_request(
      "/proxy/app-config?failure_threshold=9&error_rate_threshold=0.25",
      None,
      current,
    )
    is None,
  )
}

///|
test "proxy pricing config aliases use moonstat env-backed defaults" {
  let cost_key = "MOONSTAT_CODEX_DEFAULT_COST_MULTIPLIER"
  let source_key = "MOONSTAT_CODEX_PRICING_MODEL_SOURCE"
  @os.unsetenv(cost_key) catch {
    _ => ()
  }
  @os.unsetenv(source_key) catch {
    _ => ()
  }
  @os.setenv(cost_key, "1.25", overwrite=true)
  @os.setenv(source_key, "request", overwrite=true)
  assert_eq(default_cost_multiplier_for_app("codex"), "1.25")
  assert_eq(default_pricing_model_source_for_app("codex"), "request")
  @os.unsetenv(cost_key) catch {
    _ => ()
  }
  @os.unsetenv(source_key) catch {
    _ => ()
  }
}

///|
test "proxy pricing config runtime overrides feed provider activation defaults" {
  let gateway = Gateway::new(port=17017, host="127.0.0.17", model="gpt-5")
  gateway.proxy.proxy_default_cost_multipliers.set("codex", "1.75")
  gateway.proxy.proxy_pricing_model_sources.set("codex", "request")
  let provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="codex-oauth",
    provider_name="Codex OAuth",
  )
  assert_eq(gateway.proxy.default_cost_multiplier_for_app("codex"), "1.75")
  assert_eq(gateway.proxy.pricing_model_source_for_app("codex"), "request")
  assert_eq(gateway.proxy.provider_cost_multiplier(provider), "1.75")
  assert_eq(gateway.proxy.provider_pricing_model_source(provider), "request")
}

///|
test "proxy pricing config makes claude desktop inherit claude defaults like moonstat" {
  let gateway = Gateway::new(port=17017, host="127.0.0.17", model="gpt-5")
  gateway.proxy.proxy_default_cost_multipliers.set("claude", "1.5")
  gateway.proxy.proxy_pricing_model_sources.set("claude", "request")
  gateway.proxy.proxy_default_cost_multipliers.set("claude-desktop", "9.9")
  gateway.proxy.proxy_pricing_model_sources.set("claude-desktop", "response")
  let provider = ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="desktop",
    provider_name="Claude Desktop",
  )
  assert_eq(
    gateway.proxy.default_cost_multiplier_for_app("claude-desktop"),
    "1.5",
  )
  assert_eq(
    gateway.proxy.pricing_model_source_for_app("claude-desktop"),
    "request",
  )
  assert_eq(gateway.proxy.provider_cost_multiplier(provider), "1.5")
  assert_eq(gateway.proxy.provider_pricing_model_source(provider), "request")
}

///|
test "common config snippet validation mirrors moonstat formats" {
  assert_eq(
    moon_validate_common_config_snippet("codex", "# comment only\n"),
    None,
  )
  assert_true(
    moon_validate_common_config_snippet("codex", "[broken") is Some(_),
  )
  assert_true(
    moon_validate_common_config_snippet("claude", "{\"env\":") is Some(_),
  )
  assert_eq(
    moon_validate_common_config_snippet("gemini", "{\"EXTRA\":\"kept\"}"),
    None,
  )
}

///|
test "common config extraction strips moonstat provider-specific fields" {
  let claude = moon_extract_common_config_snippet_json(
    "claude",
    Json::object({
      "apiBaseUrl": Json::string("https://provider.example"),
      "primaryModel": Json::string("claude-sonnet"),
      "env": Json::object({
        "ANTHROPIC_API_KEY": Json::string("secret"),
        "ANTHROPIC_MODEL": Json::string("claude-sonnet"),
        "KEEP_ME": Json::string("1"),
      }),
      "custom": Json::boolean(true),
    }),
  )
  guard @json.parse(claude) is Object(claude_obj) else {
    fail("expected extracted claude JSON")
  }
  assert_true(claude_obj.get("apiBaseUrl") is None)
  assert_true(claude_obj.get("primaryModel") is None)
  guard claude_obj["env"] is Object(claude_env) else {
    fail("expected claude env")
  }
  assert_true(claude_env.get("ANTHROPIC_API_KEY") is None)
  assert_true(claude_env.get("ANTHROPIC_MODEL") is None)
  assert_eq(claude_env["KEEP_ME"], Json::string("1"))

  let gemini = moon_extract_common_config_snippet_json(
    "gemini",
    Json::object({
      "env": Json::object({
        "GEMINI_API_KEY": Json::string("secret"),
        "GOOGLE_GEMINI_BASE_URL": Json::string("https://provider.example"),
        "EXTRA": Json::string(" kept "),
      }),
    }),
  )
  guard @json.parse(gemini) is Object(gemini_obj) else {
    fail("expected extracted gemini JSON")
  }
  assert_true(gemini_obj.get("GEMINI_API_KEY") is None)
  assert_eq(gemini_obj["EXTRA"], Json::string("kept"))
}

///|
test "codex common config extraction removes provider toml tables" {
  let settings = Json::object({
    "config": Json::string(
      (
        #|model = "gpt-5"
        #|model_provider = "openai"
        #|base_url = "https://provider.example"
        #|approval_policy = "never"
        #|
        #|[model_providers.openai]
        #|base_url = "https://provider.example"
        #|api_key = "secret"
        #|
        #|[tools]
        #|web_search = true
      ),
    ),
  })
  let snippet = moon_extract_common_config_snippet_json("codex", settings)
  assert_true(!snippet.contains("model_provider"))
  assert_true(!snippet.contains("[model_providers.openai]"))
  assert_true(snippet.contains("approval_policy = \"never\""))
  assert_true(snippet.contains("[tools]"))
}

///|
test "proxy circuit breaker config exposes moonstat shape" {
  let gateway = Gateway::new(port=17006, host="127.0.0.7", model="gpt-5")
  guard gateway.proxy.provider_router.circuit_config.to_json() is Object(config) else {
    fail("expected circuit config object")
  }
  assert_eq(config["failureThreshold"], Json::number(4.0))
  assert_eq(config["successThreshold"], Json::number(2.0))
  assert_eq(config["timeoutSeconds"], Json::number(60.0))
  assert_eq(config["errorRateThreshold"], Json::number(0.6))
  assert_eq(config["minRequests"], Json::number(10.0))
}

///|
test "proxy circuit breaker config update accepts moonstat body and query shapes" {
  let direct = @json.parse(
    "{\"failureThreshold\":5,\"successThreshold\":3,\"timeoutSeconds\":30,\"errorRateThreshold\":0.4,\"minRequests\":12}",
  )
  guard circuit_breaker_config_from_json(direct) is Some(config) else {
    fail("expected direct moonstat circuit config")
  }
  assert_eq(config.failure_threshold, 5)
  assert_eq(config.success_threshold, 3)
  assert_eq(config.timeout_seconds, 30)
  assert_eq(config.error_rate_threshold, 0.4)
  assert_eq(config.min_requests, 12)

  let wrapped = @json.parse(
    "{\"config\":{\"failureThreshold\":6,\"successThreshold\":2,\"timeoutSeconds\":0,\"errorRateThreshold\":0.75,\"minRequests\":20}}",
  )
  guard circuit_breaker_config_from_json(wrapped) is Some(wrapped_config) else {
    fail("expected wrapped moonstat circuit config")
  }
  assert_eq(wrapped_config.failure_threshold, 6)
  assert_eq(wrapped_config.timeout_seconds, 0)
  assert_eq(wrapped_config.error_rate_threshold, 0.75)

  let path = "/proxy/circuit-breaker-config?failureThreshold=7&successThreshold=4&timeoutSeconds=45&errorRateThreshold=0.25&minRequests=15"
  guard proxy_circuit_config_from_query(path) is Some(query_config) else {
    fail("expected query circuit config")
  }
  assert_eq(query_config.failure_threshold, 7)
  assert_eq(query_config.success_threshold, 4)
  assert_eq(query_config.timeout_seconds, 45)
  assert_eq(query_config.error_rate_threshold, 0.25)
  assert_eq(query_config.min_requests, 15)
  assert_true(
    proxy_circuit_config_from_query(
      "/proxy/circuit-breaker-config?failure_threshold=7&success_threshold=4&timeout_seconds=45&error_rate_threshold=0.25&min_requests=15",
    )
    is None,
  )

  assert_true(
    circuit_breaker_config_from_json(
      @json.parse(
        "{\"failureThreshold\":0,\"successThreshold\":3,\"timeoutSeconds\":30,\"errorRateThreshold\":0.4,\"minRequests\":12}",
      ),
    )
    is None,
  )
}

///|
test "proxy circuit breaker config update hot applies to existing breakers" {
  let router = ProviderRouter::new()
  for _ in 0..<3 {
    router.record_result("codex-oauth", "claude", false, false, now_ms=1000)
  }
  router.update_all_configs({
    failure_threshold: 5,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 1.0,
    min_requests: 10,
  })
  router.record_result("codex-oauth", "claude", false, false, now_ms=1000)
  guard router.get_circuit_breaker_stats("codex-oauth", "claude")
    is Some(after_four) else {
    fail("expected stats after four failures")
  }
  assert_true(after_four.state == Closed)
  assert_eq(after_four.consecutive_failures, 4)

  router.record_result("codex-oauth", "claude", false, false, now_ms=1000)
  guard router.get_circuit_breaker_stats("codex-oauth", "claude")
    is Some(after_five) else {
    fail("expected stats after five failures")
  }
  assert_true(after_five.state == Open)
}

///|
test "proxy provider health alias mirrors circuit breaker state" {
  let gateway = Gateway::new(port=17007, host="127.0.0.8", model="gpt-5")
  guard gateway.proxy.provider_router.provider_health_json(
      "codex-oauth", "claude", "test-time",
    )
    is Object(healthy) else {
    fail("expected default provider health object")
  }
  assert_eq(healthy["provider_id"], Json::string("codex-oauth"))
  assert_eq(healthy["app_type"], Json::string("claude"))
  assert_eq(healthy["is_healthy"], Json::boolean(true))
  assert_eq(healthy["consecutive_failures"], Json::number(0.0))
  assert_eq(healthy["last_error"], Json::null())
  assert_eq(healthy["updated_at"], Json::string("test-time"))

  for _ in 0..<4 {
    gateway.proxy.provider_router.record_result(
      "codex-oauth",
      "claude",
      false,
      false,
      now_ms=1000,
    )
  }
  guard gateway.proxy.provider_router.provider_health_json(
      "codex-oauth", "claude", "test-time",
    )
    is Object(open) else {
    fail("expected open provider health object")
  }
  assert_eq(open["is_healthy"], Json::boolean(false))
  assert_eq(open["consecutive_failures"], Json::number(4.0))
  assert_eq(open["last_success_at"], Json::null())
  assert_eq(open["last_failure_at"], Json::string("1000"))
  assert_eq(open["last_error"], Json::string("circuit_open"))
  guard gateway.proxy.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "claude",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Open)
  assert_eq(stats.total_requests, 4)
  assert_eq(stats.failed_requests, 4)
  gateway.proxy.provider_router.reset_provider_breaker("codex-oauth", "claude")
  guard gateway.proxy.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "claude",
    )
    is Some(reset_stats) else {
    fail("expected reset circuit stats")
  }
  assert_true(reset_stats.state == Closed)
  assert_eq(reset_stats.total_requests, 0)
  assert_eq(reset_stats.failed_requests, 0)
  guard gateway.proxy.provider_router.provider_health_json(
      "codex-oauth", "claude", "test-time-after-reset",
    )
    is Object(reset_health) else {
    fail("expected reset provider health object")
  }
  assert_eq(reset_health["is_healthy"], Json::boolean(true))
  assert_eq(reset_health["consecutive_failures"], Json::number(0.0))
  assert_true(reset_health["last_success_at"] is String(_))
  assert_eq(reset_health["last_failure_at"], Json::string("1000"))
  assert_eq(reset_health["last_error"], Json::null())
}

///|
test "proxy status alias matches moonstat proxy status shape" {
  let gateway = Gateway::new(port=17002, host="127.0.0.3", model="gpt-5")
  gateway.usage.stats.record_inbound(16)
  gateway.usage.stats.record_bad_request()
  gateway.usage.stats.set_active_target("codex", "codex-oauth", "Codex OAuth")
  gateway.usage.stats.last_request_at = Some("test-timestamp")
  guard gateway.proxy.status_json(
      gateway.usage,
      gateway.host,
      gateway.port,
      gateway.runtime.uptime_seconds(gateway.started_at_ms),
    )
    is Object(status) else {
    fail("expected proxy status object")
  }
  assert_eq(status["running"], Json::boolean(true))
  assert_eq(status["address"], Json::string("127.0.0.3"))
  assert_eq(status["port"], Json::number(17002.0))
  assert_eq(status["active_connections"], Json::number(0.0))
  assert_eq(status["total_requests"], Json::number(1.0))
  assert_eq(status["success_requests"], Json::number(0.0))
  assert_eq(status["failed_requests"], Json::number(1.0))
  assert_eq(status["success_rate"], Json::number(0.0))
  assert_eq(status["current_provider"], Json::string("Codex OAuth"))
  assert_eq(status["current_provider_id"], Json::string("codex-oauth"))
  assert_eq(status["last_request_at"], Json::string("test-timestamp"))
  assert_eq(status["last_error"], Json::string("bad_request"))
  assert_eq(status["failover_count"], Json::number(0.0))
  assert_true(status.get("active_targets") is Some(_))
  assert_true(status.get("provider_routes") is None)
}

///|
test "proxy status running follows moonstat start stop state" {
  let gateway = Gateway::new(port=17004, host="127.0.0.5", model="gpt-5")
  gateway.proxy.proxy_enabled = false
  guard gateway.proxy.status_json(
      gateway.usage,
      gateway.host,
      gateway.port,
      gateway.runtime.uptime_seconds(gateway.started_at_ms),
    )
    is Object(stopped) else {
    fail("expected stopped proxy status")
  }
  assert_eq(stopped["running"], Json::boolean(false))
  gateway.proxy.proxy_enabled = true
  guard gateway.proxy.status_json(
      gateway.usage,
      gateway.host,
      gateway.port,
      gateway.runtime.uptime_seconds(gateway.started_at_ms),
    )
    is Object(started) else {
    fail("expected started proxy status")
  }
  assert_eq(started["running"], Json::boolean(true))
}

///|
test "proxy takeover status alias is moonstat-compatible standalone false state" {
  let gateway = Gateway::new(port=17003, host="127.0.0.4", model="gpt-5")
  guard gateway.proxy.takeover_status_json() is Object(status) else {
    fail("expected takeover status object")
  }
  assert_eq(status.length(), 5)
  assert_eq(status["claude"], Json::boolean(false))
  assert_eq(status["codex"], Json::boolean(false))
  assert_eq(status["gemini"], Json::boolean(false))
  assert_eq(status["opencode"], Json::boolean(false))
  assert_eq(status["openclaw"], Json::boolean(false))
}

///|
test "codex provider forward failures use moonstat proxy error shape" {
  let provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="deepseek",
    provider_name="DeepSeek",
    provider_type=Some("codex"),
  )
  guard codex_forward_failed_error_json(
      provider, "deepseek-chat", "/responses?beta=true", "connection refused",
    )
    is Object(body) else {
    fail("expected error body")
  }
  guard body["error"] is Object(error) else { fail("expected error object") }
  assert_eq(error["type"], Json::string("proxy_error"))
  assert_eq(error["code"], Json::string("moonstat_forward_failed"))
  assert_eq(error["param"], Json::null())
  assert_eq(error["provider"], Json::string("DeepSeek"))
  assert_eq(error["model"], Json::string("deepseek-chat"))
  assert_eq(error["endpoint"], Json::string("/responses?beta=true"))
  guard error["message"] is String(message) else { fail("expected message") }
  assert_true(message.contains("Moonstat local proxy failed"))
  assert_true(message.contains("Provider: DeepSeek"))
  assert_true(message.contains("model: deepseek-chat"))
  assert_true(message.contains("cause: Codex upstream request failed"))
}

///|
test "usage pricing helpers parse and validate moonstat pricing query" {
  let path = "/usage/model-pricing?modelId=test-model&displayName=Test%20Model&inputCost=1.25&outputCost=2&cacheReadCost=0.10&cacheCreationCost=0"
  guard usage_pricing_from_request(path, None) is Some(pricing) else {
    fail("expected pricing")
  }
  assert_eq(pricing.model_id, "test-model")
  assert_eq(pricing.display_name, "Test Model")
  assert_eq(pricing.input_cost_per_million, "1.25")
  assert_eq(pricing.output_cost_per_million, "2")
  assert_eq(pricing.cache_read_cost_per_million, "0.10")
  assert_eq(pricing.cache_creation_cost_per_million, "0")
  assert_true(
    usage_pricing_from_request(
      "/usage/model-pricing?modelId=test&displayName=Test&inputCost=-1&outputCost=2&cacheReadCost=0&cacheCreationCost=0",
      None,
    )
    is None,
  )
  assert_true(
    usage_pricing_from_request(
      "/usage/model-pricing?modelId=test&displayName=Test&inputCost=abc&outputCost=2&cacheReadCost=0&cacheCreationCost=0",
      None,
    )
    is None,
  )
}

///|
test "usage pricing helpers parse moonstat structured body update" {
  let body = {
    "modelId": Json::string("body-model"),
    "displayName": Json::string("Body Model"),
    "inputCost": Json::number(1.25),
    "outputCost": Json::string("2"),
    "cacheReadCost": Json::string("0.10"),
    "cacheCreationCost": Json::number(0.0),
  }.to_json()
  guard usage_pricing_from_request("/usage/model-pricing", Some(body))
    is Some(pricing) else {
    fail("expected body pricing")
  }
  assert_eq(pricing.model_id, "body-model")
  assert_eq(pricing.display_name, "Body Model")
  assert_eq(pricing.input_cost_per_million, "1.25")
  assert_eq(pricing.output_cost_per_million, "2")
  assert_eq(pricing.cache_read_cost_per_million, "0.10")
  assert_eq(pricing.cache_creation_cost_per_million, "0")
}

///|
test "usage pricing helpers prefer query over body args" {
  let body = {
    "modelId": Json::string("body-model"),
    "displayName": Json::string("Body Model"),
    "inputCost": Json::string("1"),
    "outputCost": Json::string("2"),
    "cacheReadCost": Json::string("3"),
    "cacheCreationCost": Json::string("4"),
  }.to_json()
  let path = "/usage/model-pricing?modelId=query-model&displayName=Query%20Model&inputCost=5&outputCost=6&cacheReadCost=7&cacheCreationCost=8"
  guard usage_pricing_from_request(path, Some(body)) is Some(pricing) else {
    fail("expected query pricing")
  }
  assert_eq(pricing.model_id, "query-model")
  assert_eq(pricing.display_name, "Query Model")
  assert_eq(pricing.input_cost_per_million, "5")
  assert_eq(pricing.output_cost_per_million, "6")
  assert_eq(pricing.cache_read_cost_per_million, "7")
  assert_eq(pricing.cache_creation_cost_per_million, "8")
}

///|
test "usage pricing validation mirrors moonstat required field messages" {
  let body = {
    "displayName": Json::string("Body Model"),
    "inputCost": Json::string("1"),
    "outputCost": Json::string("2"),
    "cacheReadCost": Json::string("3"),
    "cacheCreationCost": Json::string("4"),
  }.to_json()
  assert_eq(
    usage_pricing_validation_error_from_request(
      "/usage/model-pricing",
      Some(body),
    ),
    Some("Model ID is required"),
  )
  let missing_display = {
    "modelId": Json::string("body-model"),
    "inputCost": Json::string("1"),
    "outputCost": Json::string("2"),
    "cacheReadCost": Json::string("3"),
    "cacheCreationCost": Json::string("4"),
  }.to_json()
  assert_eq(
    usage_pricing_validation_error_from_request(
      "/usage/model-pricing",
      Some(missing_display),
    ),
    Some("Display name is required"),
  )
}

///|
test "usage pricing validation mirrors moonstat invalid price messages" {
  let negative = "/usage/model-pricing?modelId=m&displayName=M&inputCost=-1&outputCost=2&cacheReadCost=0&cacheCreationCost=0"
  assert_eq(
    usage_pricing_validation_error_from_request(negative, None),
    Some("inputCost price must be non-negative: -1"),
  )
  let invalid = "/usage/model-pricing?modelId=m&displayName=M&inputCost=abc&outputCost=2&cacheReadCost=0&cacheCreationCost=0"
  assert_eq(
    usage_pricing_validation_error_from_request(invalid, None),
    Some("inputCost price is invalid: abc"),
  )
}

///|
test "usage decimal validation mirrors moonstat frontend regex" {
  assert_true(usage_non_negative_decimal("0"))
  assert_true(usage_non_negative_decimal("1.25"))
  assert_true(usage_non_negative_decimal(" 10 "))
  assert_false(usage_non_negative_decimal(".5"))
  assert_false(usage_non_negative_decimal("1."))
  assert_false(usage_non_negative_decimal("-1"))
  assert_false(usage_non_negative_decimal("abc"))
}

///|
test "usage request detail id accepts moonstat request detail query" {
  assert_eq(
    usage_request_detail_id("/usage/request-detail?requestId=session%3Amsg%2F1"),
    "session:msg/1",
  )
  assert_true(
    usage_request_detail_id("/usage/request-detail?request_id=req_123") !=
    "req_123",
  )
}

///|
test "usage request detail id accepts moonstat structured body" {
  let body = { "requestId": Json::string("session:body/1") }.to_json()
  assert_eq(
    usage_request_detail_id_from_request("/usage/request-detail", Some(body)),
    "session:body/1",
  )
  assert_eq(
    usage_request_detail_id_from_request(
      "/usage/request-detail",
      Some({ "request_id": Json::string("req_body_2") }.to_json()),
    ),
    "/usage/request-detail",
  )
}

///|
test "usage model id helpers accept body and query precedence" {
  let body = { "modelId": Json::string("body-model") }.to_json()
  assert_eq(
    usage_string_from_request("/usage/model-pricing", Some(body), "modelId"),
    Some("body-model"),
  )
  assert_eq(
    usage_string_from_request(
      "/usage/model-pricing?modelId=query-model",
      Some(body),
      "modelId",
    ),
    Some("query-model"),
  )
  assert_eq(
    usage_string_from_request(
      "/usage/model-pricing?model_id=legacy-query",
      Some({ "model_id": Json::string("legacy-body") }.to_json()),
      "modelId",
    ),
    None,
  )
}

///|
test "usage pricing store rows use moonstat field names" {
  let row = model_pricing_store_json(
    mp("test-model", "Test Model", "1", "2", "0.1", "0"),
    deleted=false,
  )
  guard row is Object(obj) else { fail("expected pricing row") }
  assert_eq(obj["modelId"], Json::string("test-model"))
  assert_eq(obj["displayName"], Json::string("Test Model"))
  assert_eq(obj["inputCostPerMillion"], Json::string("1"))
  assert_eq(obj["deleted"], Json::boolean(false))
  guard model_pricing_from_store_json(obj) is Some(parsed) else {
    fail("expected parsed pricing row")
  }
  assert_eq(parsed.model_id, "test-model")
  assert_eq(parsed.cache_read_cost_per_million, "0.1")
}

///|
test "codex responses endpoints preserve request query" {
  assert_eq(
    codex_backend_responses_endpoint(
      false,
      request_path="/v1/responses?beta=true&conversation=abc",
    ),
    "/backend-api/codex/responses?beta=true&conversation=abc",
  )
  assert_eq(
    codex_backend_responses_endpoint(
      true,
      request_path="/v1/responses/compact?beta=true",
    ),
    "/backend-api/codex/responses/compact?beta=true",
  )
}

///|
test "claude desktop gateway bearer token validation" {
  assert_eq(bearer_token("Bearer moon-token"), Some("moon-token"))
  assert_eq(bearer_token("bearer moon-token  "), Some("moon-token"))
  assert_eq(bearer_token("Token moon-token"), None)
  assert_true(
    claude_desktop_authorization_valid(
      { "authorization": "Bearer moon-token" },
      "moon-token",
    ),
  )
  assert_false(
    claude_desktop_authorization_valid(
      { "authorization": "Bearer wrong-token" },
      "moon-token",
    ),
  )
  assert_false(claude_desktop_authorization_valid({}, "moon-token"))
}

///|
test "claude desktop model normalization keeps route ids strict" {
  assert_eq(
    normalize_claude_desktop_model_id("claude-opus-4-7"),
    "claude-opus-4-7",
  )
  assert_eq(
    normalize_claude_desktop_model_id("claude-opus-4-8[1m]"),
    "claude-opus-4-8",
  )
  assert_eq(
    normalize_claude_desktop_model_id("claude-sonnet-4-6 [1M]"),
    "claude-sonnet-4-6",
  )
  assert_eq(
    normalize_claude_desktop_model_id("claude-haiku-4-5-20251001"),
    "claude-haiku-4-5-20251001",
  )
  assert_eq(
    normalize_claude_desktop_model_id("anthropic/claude-opus-4-8"),
    "anthropic/claude-opus-4-8",
  )
  assert_eq(normalize_claude_desktop_model_id("gpt-5[1m]"), "gpt-5")
}

///|
test "claude safe model id rejects moonstat unsafe ids" {
  assert_false(is_claude_safe_model_id("claude-sonnet-4-6 [1m]"))
  assert_false(is_claude_safe_model_id("claude-old"))
  assert_false(is_claude_safe_model_id("claude-3-5-sonnet-20241022"))
  assert_false(is_claude_safe_model_id("claude-deepseek-v4-pro"))
  assert_false(is_claude_safe_model_id("claude-gpt-5-4"))
  assert_false(is_claude_safe_model_id("claude-sonnet-"))
  assert_true(is_claude_safe_model_id("  claude-sonnet-4-6  "))
  assert_true(is_claude_safe_model_id("anthropic/claude-opus-4-8"))
}

///|
test "moonstat session extraction uses claude metadata and headers" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "messages": [],
      #|  "metadata": {
      #|    "user_id": "user_jane_session_claude-session-1",
      #|    "session_id": "metadata-session"
      #|  }
      #|}
    ),
  )
  assert_eq(
    extract_client_session_id({}, body, "claude"),
    Some("claude-session-1"),
  )
  assert_eq(
    extract_client_session_id(
      { "x-claude-code-session-id": "header-session" },
      body,
      "claude",
    ),
    Some("header-session"),
  )
}

///|
test "moonstat session context generates log id without upstream session" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "messages": []
      #|}
    ),
  )
  let session = extract_client_session_context({}, body, "claude")
  assert_false(session.client_provided)
  assert_eq(session.upstream_session_id(), None)
  assert_eq(session.session_id.length(), 36)
  ignore(@uuid.parse(session.session_id))
}

///|
test "moonstat session context keeps client session for upstream" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "messages": [],
      #|  "metadata": { "session_id": "metadata-session" }
      #|}
    ),
  )
  let session = extract_client_session_context({}, body, "claude")
  assert_true(session.client_provided)
  assert_eq(session.session_id, "metadata-session")
  assert_eq(session.upstream_session_id(), Some("metadata-session"))
}

///|
test "moonstat client format detects proxy path shapes" {
  assert_true(moon_client_format_from_path("/v1/messages") == Claude)
  assert_true(moon_client_format_from_path("/api/v1/messages") == Claude)
  assert_true(moon_client_format_from_path("/v1/responses") == Codex)
  assert_true(moon_client_format_from_path("/v1/chat/completions") == OpenAI)
  assert_true(
    moon_client_format_from_path(
      "/v1internal/models/gemini-pro:generateContent",
    ) ==
    GeminiCli,
  )
  assert_true(
    moon_client_format_from_path("/v1beta/models/gemini-pro:generateContent") ==
    Gemini,
  )
  assert_true(
    moon_client_format_from_path("/custom/models/gemini:generateContent") ==
    Gemini,
  )
  assert_true(moon_client_format_from_path("/unknown") == Unknown)
  assert_eq(GeminiCli.to_string(), "gemini_cli")
}

///|
test "moonstat client format falls back to body shape" {
  let claude_body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "messages": [{ "role": "user", "content": "hi" }],
      #|  "max_tokens": 1024
      #|}
    ),
  )
  assert_true(moon_client_format_from_body(claude_body) == Claude)
  assert_true(
    moon_client_format_for_request("/unknown", Some(claude_body)) == Claude,
  )

  let openai_body = @json.parse(
    (
      #|{
      #|  "model": "gpt-5",
      #|  "messages": [{ "role": "user", "content": "hi" }]
      #|}
    ),
  )
  assert_true(moon_client_format_from_body(openai_body) == OpenAI)

  let codex_body = @json.parse(
    (
      #|{
      #|  "input": "Write a function"
      #|}
    ),
  )
  assert_true(moon_client_format_from_body(codex_body) == Codex)

  let gemini_body = @json.parse(
    (
      #|{
      #|  "contents": [{ "parts": [{ "text": "hi" }] }]
      #|}
    ),
  )
  assert_true(moon_client_format_from_body(gemini_body) == Gemini)
  assert_true(
    moon_client_format_for_request("/v1/responses", Some(gemini_body)) == Codex,
  )
  assert_true(moon_client_format_for_request("/unknown", None) == Unknown)
}

///|
test "moonstat session extraction prefixes codex client ids" {
  let body = @json.parse(
    (
      #|{
      #|  "input": "hello",
      #|  "metadata": {
      #|    "session_id": "metadata-session-123456789"
      #|  },
      #|  "previous_response_id": "resp_should_not_be_session"
      #|}
    ),
  )
  assert_eq(
    extract_client_session_id(
      { "session_id": "12345678-1234-1234-1234-123456789012" },
      body,
      "codex",
    ),
    Some("codex_12345678-1234-1234-1234-123456789012"),
  )
  assert_eq(
    extract_client_session_id({}, body, "codex"),
    Some("codex_metadata-session-123456789"),
  )
  assert_eq(
    extract_client_session_id(
      {},
      @json.parse("{\"previous_response_id\":\"resp_only\"}"),
      "codex",
    ),
    None,
  )
}

///|
test "codex oauth headers propagate moonstat session headers" {
  let creds = @codex.Credentials::{
    idToken: "id",
    accessToken: "access",
    refreshToken: "refresh",
    accountId: "account",
  }
  let headers = codex_oauth_headers(
    creds,
    "text/event-stream",
    Some("codex_session-1"),
  )
  assert_eq(headers["Authorization"], "Bearer access")
  assert_eq(headers["ChatGPT-Account-ID"], "account")
  assert_eq(headers["Accept"], "text/event-stream")
  assert_eq(headers["session_id"], "codex_session-1")
  assert_eq(headers["x-client-request-id"], "codex_session-1")
  assert_eq(headers["x-codex-window-id"], "codex_session-1:0")
}

///|
test "codex oauth headers trim empty moonstat session ids" {
  let creds = @codex.Credentials::{
    idToken: "id",
    accessToken: "access",
    refreshToken: "refresh",
    accountId: "account",
  }
  let headers = codex_oauth_headers(
    creds,
    "application/json",
    Some("  session-123  "),
  )
  assert_eq(headers["session_id"], "session-123")
  assert_eq(headers["x-client-request-id"], "session-123")
  assert_eq(headers["x-codex-window-id"], "session-123:0")
  let empty = codex_oauth_headers(creds, "application/json", Some("   "))
  assert_true(empty.get("session_id") is None)
  assert_true(empty.get("x-client-request-id") is None)
  assert_true(empty.get("x-codex-window-id") is None)
}

///|
test "moonstat managed account guard rejects copilot proxy placeholder" {
  let result = moon_reject_proxy_managed_placeholder_for_upstream(
    "https://api.githubcopilot.com/chat/completions",
    { "Authorization": "Bearer PROXY_MANAGED" },
  )
  assert_true(result is Err(_))
  match result {
    Err(message) => assert_true(message.contains("PROXY_MANAGED"))
    _ => fail("expected managed account guard error")
  }
}

///|
test "moonstat managed account guard rejects codex proxy placeholder" {
  let result = moon_reject_proxy_managed_placeholder_for_upstream(
    "https://chatgpt.com/backend-api/codex/responses",
    { "Authorization": "Bearer PROXY_MANAGED" },
  )
  assert_true(result is Err(_))
  match result {
    Err(message) => assert_true(message.contains("PROXY_MANAGED"))
    _ => fail("expected managed account guard error")
  }
}

///|
test "moonstat managed account guard is scoped to managed upstreams" {
  let result = moon_reject_proxy_managed_placeholder_for_upstream(
    "https://api.example.com/v1/messages",
    { "Authorization": "Bearer PROXY_MANAGED" },
  )
  assert_true(result is Ok(_))
}

///|
test "codex to anthropic response emits moonstat cache usage buckets" {
  let body = @json.parse(
    (
      #|{
      #|  "id": "resp_1",
      #|  "model": "gpt-5",
      #|  "output": [
      #|    {
      #|      "type": "message",
      #|      "content": [
      #|        { "type": "output_text", "text": "done" }
      #|      ]
      #|    }
      #|  ],
      #|  "usage": {
      #|    "input_tokens": 100,
      #|    "output_tokens": 7,
      #|    "input_tokens_details": { "cached_tokens": 31 },
      #|    "cache_creation_input_tokens": 5
      #|  }
      #|}
    ),
  )
  let response = convert_codex_to_anthropic(body, "claude-sonnet-4-6")
  json_inspect(response.usage.to_json(), content={
    "input_tokens": 64,
    "output_tokens": 7,
    "cache_read_input_tokens": 31,
    "cache_creation_input_tokens": 5,
  })
}

///|
test "moonstat default provider router selects suite app targets" {
  let router = moonstat_default_provider_router()
  let codex = router.select_providers("codex", now_ms=1000)
  assert_true(codex.is_ok())
  match codex_provider_from_env() {
    Some(provider) => {
      assert_true(codex.providers.length() == 2)
      assert_true(codex.providers[0].provider_id == provider.provider_id)
      assert_true(codex.providers[0].can_use_codex_compatible_upstream())
      assert_true(codex.providers[1].provider_id == "codex-oauth")
    }
    None => {
      assert_true(codex.providers.length() == 1)
      assert_true(codex.providers[0].provider_id == "codex-oauth")
      assert_true(codex.providers[0].provider_type == Some("codex_oauth"))
    }
  }
  let gemini = router.select_providers("gemini", now_ms=1000)
  assert_true(gemini.is_ok())
  assert_eq(gemini.providers.length(), 1)
  assert_eq(gemini.providers[0].provider_id, "gemini-api-key")
  let claude = router.select_providers("claude-desktop", now_ms=1000)
  assert_true(claude.is_ok())
  assert_eq(claude.providers.length(), 1)
  assert_eq(claude.providers[0].provider_name, "Codex OAuth")
  assert_eq(claude.providers[0].provider_type, Some("codex_oauth"))
}

///|
test "claude provider env carries moonstat settings config" {
  let keys = [
    "MOONSTAT_CLAUDE_BASE_URL", "MOONSTAT_CLAUDE_API_KEY", "MOONSTAT_CLAUDE_SETTINGS_CONFIG",
  ]
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
  @os.setenv("MOONSTAT_CLAUDE_BASE_URL", "https://example.test", overwrite=true)
  @os.setenv("MOONSTAT_CLAUDE_API_KEY", "secret", overwrite=true)
  @os.setenv(
    "MOONSTAT_CLAUDE_SETTINGS_CONFIG",
    (
      #|{
      #|  "modelCatalog": {
      #|    "models": [
      #|      { "model": "gpt-4o", "input": ["text"] }
      #|    ]
      #|  }
      #|}
    ),
    overwrite=true,
  )
  guard claude_provider_from_env("claude") is Some(provider) else {
    fail("expected provider")
  }
  guard provider.settings_config is Some(Object(settings)) else {
    fail("expected settings config")
  }
  assert_true(settings.get("modelCatalog") is Some(_))
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
}

///|
test "moonstat env providers ignore app native provider aliases" {
  let old_moon_codex_base = @os.getenv("MOONSTAT_CODEX_BASE_URL") catch {
    _ => None
  }
  let old_moon_codex_key = @os.getenv("MOONSTAT_CODEX_API_KEY") catch {
    _ => None
  }
  let old_code_base = @os.getenv("CODEX_BASE_URL") catch { _ => None }
  let old_code_key = @os.getenv("CODEX_API_KEY") catch { _ => None }
  let old_openai_base = @os.getenv("OPENAI_BASE_URL") catch { _ => None }
  let old_openai_key = @os.getenv("OPENAI_API_KEY") catch { _ => None }
  let old_moon_claude_base = @os.getenv("MOONSTAT_CLAUDE_BASE_URL") catch {
    _ => None
  }
  let old_moon_claude_key = @os.getenv("MOONSTAT_CLAUDE_API_KEY") catch {
    _ => None
  }
  let old_anthropic_base = @os.getenv("ANTHROPIC_BASE_URL") catch { _ => None }
  let old_anthropic_key = @os.getenv("ANTHROPIC_API_KEY") catch { _ => None }
  let old_anthropic_token = @os.getenv("ANTHROPIC_AUTH_TOKEN") catch {
    _ => None
  }
  @os.unsetenv("MOONSTAT_CODEX_BASE_URL") catch {
    _ => ()
  }
  @os.unsetenv("MOONSTAT_CODEX_API_KEY") catch {
    _ => ()
  }
  @os.unsetenv("MOONSTAT_CLAUDE_BASE_URL") catch {
    _ => ()
  }
  @os.unsetenv("MOONSTAT_CLAUDE_API_KEY") catch {
    _ => ()
  }
  @os.setenv("CODEX_BASE_URL", "https://codex.example/v1", overwrite=true)
  @os.setenv("CODEX_API_KEY", "codex-key", overwrite=true)
  @os.setenv("OPENAI_BASE_URL", "https://openai.example/v1", overwrite=true)
  @os.setenv("OPENAI_API_KEY", "openai-key", overwrite=true)
  @os.setenv("ANTHROPIC_BASE_URL", "https://anthropic.example", overwrite=true)
  @os.setenv("ANTHROPIC_API_KEY", "anthropic-key", overwrite=true)
  @os.setenv("ANTHROPIC_AUTH_TOKEN", "anthropic-token", overwrite=true)
  assert_true(codex_provider_from_env() is None)
  assert_true(claude_provider_from_env("claude") is None)
  moon_wbtest_restore_env("MOONSTAT_CODEX_BASE_URL", old_moon_codex_base)
  moon_wbtest_restore_env("MOONSTAT_CODEX_API_KEY", old_moon_codex_key)
  moon_wbtest_restore_env("CODEX_BASE_URL", old_code_base)
  moon_wbtest_restore_env("CODEX_API_KEY", old_code_key)
  moon_wbtest_restore_env("OPENAI_BASE_URL", old_openai_base)
  moon_wbtest_restore_env("OPENAI_API_KEY", old_openai_key)
  moon_wbtest_restore_env("MOONSTAT_CLAUDE_BASE_URL", old_moon_claude_base)
  moon_wbtest_restore_env("MOONSTAT_CLAUDE_API_KEY", old_moon_claude_key)
  moon_wbtest_restore_env("ANTHROPIC_BASE_URL", old_anthropic_base)
  moon_wbtest_restore_env("ANTHROPIC_API_KEY", old_anthropic_key)
  moon_wbtest_restore_env("ANTHROPIC_AUTH_TOKEN", old_anthropic_token)
}

///|
test "moonstat full url flags ignore app native aliases" {
  let old_moon_gemini = @os.getenv("MOONSTAT_GEMINI_FULL_URL") catch {
    _ => None
  }
  let old_gemini = @os.getenv("GEMINI_FULL_URL") catch { _ => None }
  let old_moon_codex = @os.getenv("MOONSTAT_CODEX_FULL_URL") catch { _ => None }
  let old_codex = @os.getenv("CODEX_FULL_URL") catch { _ => None }
  let old_moon_claude = @os.getenv("MOONSTAT_CLAUDE_FULL_URL") catch {
    _ => None
  }
  let old_anthropic = @os.getenv("ANTHROPIC_FULL_URL") catch { _ => None }
  @os.unsetenv("MOONSTAT_GEMINI_FULL_URL") catch {
    _ => ()
  }
  @os.unsetenv("MOONSTAT_CODEX_FULL_URL") catch {
    _ => ()
  }
  @os.unsetenv("MOONSTAT_CLAUDE_FULL_URL") catch {
    _ => ()
  }
  @os.setenv("GEMINI_FULL_URL", "1", overwrite=true)
  @os.setenv("CODEX_FULL_URL", "1", overwrite=true)
  @os.setenv("ANTHROPIC_FULL_URL", "1", overwrite=true)
  assert_false(gemini_base_is_full_url())
  assert_false(codex_base_is_full_url())
  assert_false(claude_base_is_full_url())
  @os.setenv("MOONSTAT_GEMINI_FULL_URL", "1", overwrite=true)
  @os.setenv("MOONSTAT_CODEX_FULL_URL", "1", overwrite=true)
  @os.setenv("MOONSTAT_CLAUDE_FULL_URL", "1", overwrite=true)
  assert_true(gemini_base_is_full_url())
  assert_true(codex_base_is_full_url())
  assert_true(claude_base_is_full_url())
  moon_wbtest_restore_env("MOONSTAT_GEMINI_FULL_URL", old_moon_gemini)
  moon_wbtest_restore_env("GEMINI_FULL_URL", old_gemini)
  moon_wbtest_restore_env("MOONSTAT_CODEX_FULL_URL", old_moon_codex)
  moon_wbtest_restore_env("CODEX_FULL_URL", old_codex)
  moon_wbtest_restore_env("MOONSTAT_CLAUDE_FULL_URL", old_moon_claude)
  moon_wbtest_restore_env("ANTHROPIC_FULL_URL", old_anthropic)
}

///|
test "moonstat default cost multiplier env falls back per app" {
  let keys = [
    "MOONSTAT_CLAUDE_DEFAULT_COST_MULTIPLIER", "MOONSTAT_DEFAULT_COST_MULTIPLIER",
  ]
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
  @os.setenv("MOONSTAT_CLAUDE_DEFAULT_COST_MULTIPLIER", "1.75", overwrite=true)
  @os.setenv("MOONSTAT_DEFAULT_COST_MULTIPLIER", "2.0", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="default-cost",
    provider_name="Default Cost",
  )
  assert_eq(
    provider_cost_multiplier_from_default(
      provider,
      default_cost_multiplier_for_app(provider.app_type),
    ),
    "1.75",
  )
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
}

///|
test "moonstat pricing defaults ignore short and app native aliases" {
  let old_moon_codex_cost = @os.getenv("MOONSTAT_CODEX_DEFAULT_COST_MULTIPLIER") catch {
    _ => None
  }
  let old_moon_default_cost = @os.getenv("MOONSTAT_DEFAULT_COST_MULTIPLIER") catch {
    _ => None
  }
  let old_short_codex_cost = @os.getenv("MOONSTAT_CODEX_COST_MULTIPLIER") catch {
    _ => None
  }
  let old_app_codex_cost = @os.getenv("CODEX_COST_MULTIPLIER") catch {
    _ => None
  }
  let old_moon_codex_source = @os.getenv("MOONSTAT_CODEX_PRICING_MODEL_SOURCE") catch {
    _ => None
  }
  let old_moon_default_source = @os.getenv("MOONSTAT_PRICING_MODEL_SOURCE") catch {
    _ => None
  }
  let old_short_codex_source = @os.getenv(
    "MOONSTAT_CODEX_DEFAULT_PRICING_MODEL_SOURCE",
  ) catch {
    _ => None
  }
  let old_app_codex_source = @os.getenv("CODEX_PRICING_MODEL_SOURCE") catch {
    _ => None
  }
  @os.unsetenv("MOONSTAT_CODEX_DEFAULT_COST_MULTIPLIER") catch {
    _ => ()
  }
  @os.unsetenv("MOONSTAT_DEFAULT_COST_MULTIPLIER") catch {
    _ => ()
  }
  @os.unsetenv("MOONSTAT_CODEX_PRICING_MODEL_SOURCE") catch {
    _ => ()
  }
  @os.unsetenv("MOONSTAT_PRICING_MODEL_SOURCE") catch {
    _ => ()
  }
  @os.setenv("MOONSTAT_CODEX_COST_MULTIPLIER", "7.5", overwrite=true)
  @os.setenv("CODEX_COST_MULTIPLIER", "8.5", overwrite=true)
  @os.setenv(
    "MOONSTAT_CODEX_DEFAULT_PRICING_MODEL_SOURCE",
    "request",
    overwrite=true,
  )
  @os.setenv("CODEX_PRICING_MODEL_SOURCE", "request", overwrite=true)
  assert_eq(default_cost_multiplier_for_app("codex"), "1.0")
  assert_eq(default_pricing_model_source_for_app("codex"), "response")
  @os.setenv("MOONSTAT_CODEX_DEFAULT_COST_MULTIPLIER", "1.25", overwrite=true)
  @os.setenv("MOONSTAT_CODEX_PRICING_MODEL_SOURCE", "request", overwrite=true)
  assert_eq(default_cost_multiplier_for_app("codex"), "1.25")
  assert_eq(default_pricing_model_source_for_app("codex"), "request")
  moon_wbtest_restore_env(
    "MOONSTAT_CODEX_DEFAULT_COST_MULTIPLIER", old_moon_codex_cost,
  )
  moon_wbtest_restore_env(
    "MOONSTAT_DEFAULT_COST_MULTIPLIER", old_moon_default_cost,
  )
  moon_wbtest_restore_env(
    "MOONSTAT_CODEX_COST_MULTIPLIER", old_short_codex_cost,
  )
  moon_wbtest_restore_env("CODEX_COST_MULTIPLIER", old_app_codex_cost)
  moon_wbtest_restore_env(
    "MOONSTAT_CODEX_PRICING_MODEL_SOURCE", old_moon_codex_source,
  )
  moon_wbtest_restore_env(
    "MOONSTAT_PRICING_MODEL_SOURCE", old_moon_default_source,
  )
  moon_wbtest_restore_env(
    "MOONSTAT_CODEX_DEFAULT_PRICING_MODEL_SOURCE", old_short_codex_source,
  )
  moon_wbtest_restore_env("CODEX_PRICING_MODEL_SOURCE", old_app_codex_source)
}

///|
test "moonstat provider cost multiplier overrides default env" {
  let key = "MOONSTAT_CLAUDE_DEFAULT_COST_MULTIPLIER"
  @os.unsetenv(key) catch {
    _ => ()
  }
  @os.setenv(key, "1.75", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="provider-cost",
    provider_name="Provider Cost",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "costMultiplier": "2.5" }
          #|}
        ),
      ),
    ),
  )
  assert_eq(
    provider_cost_multiplier_from_default(
      provider,
      default_cost_multiplier_for_app(provider.app_type),
    ),
    "2.5",
  )
  @os.unsetenv(key) catch {
    _ => ()
  }
}

///|
test "invalid moonstat provider cost multiplier falls back to default env" {
  let key = "MOONSTAT_CLAUDE_DEFAULT_COST_MULTIPLIER"
  @os.unsetenv(key) catch {
    _ => ()
  }
  @os.setenv(key, "1.75", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="invalid-provider-cost",
    provider_name="Invalid Provider Cost",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "costMultiplier": "bad" }
          #|}
        ),
      ),
    ),
  )
  assert_eq(
    provider_cost_multiplier_from_default(
      provider,
      default_cost_multiplier_for_app(provider.app_type),
    ),
    "1.75",
  )
  @os.unsetenv(key) catch {
    _ => ()
  }
}

///|
test "moonstat default pricing model source env falls back per app" {
  let keys = [
    "MOONSTAT_CLAUDE_PRICING_MODEL_SOURCE", "MOONSTAT_PRICING_MODEL_SOURCE",
  ]
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
  @os.setenv("MOONSTAT_CLAUDE_PRICING_MODEL_SOURCE", "request", overwrite=true)
  @os.setenv("MOONSTAT_PRICING_MODEL_SOURCE", "response", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="default-pricing-source",
    provider_name="Default Pricing Source",
  )
  assert_eq(
    provider_pricing_model_source_from_default(
      provider,
      default_pricing_model_source_for_app(provider.app_type),
    ),
    "request",
  )
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
}

///|
test "moonstat provider pricing model source overrides default env" {
  let key = "MOONSTAT_CLAUDE_PRICING_MODEL_SOURCE"
  @os.unsetenv(key) catch {
    _ => ()
  }
  @os.setenv(key, "response", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="provider-pricing-source",
    provider_name="Provider Pricing Source",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "pricingModelSource": "request" }
          #|}
        ),
      ),
    ),
  )
  assert_eq(
    provider_pricing_model_source_from_default(
      provider,
      default_pricing_model_source_for_app(provider.app_type),
    ),
    "request",
  )
  @os.unsetenv(key) catch {
    _ => ()
  }
}

///|
test "invalid moonstat provider pricing model source falls back to default env" {
  let key = "MOONSTAT_CLAUDE_PRICING_MODEL_SOURCE"
  @os.unsetenv(key) catch {
    _ => ()
  }
  @os.setenv(key, "request", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="invalid-provider-pricing-source",
    provider_name="Invalid Provider Pricing Source",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "pricingModelSource": "bad" }
          #|}
        ),
      ),
    ),
  )
  assert_eq(
    provider_pricing_model_source_from_default(
      provider,
      default_pricing_model_source_for_app(provider.app_type),
    ),
    "request",
  )
  @os.unsetenv(key) catch {
    _ => ()
  }
}

///|
test "gateway records upstream failures into provider router before finish" {
  let gateway = Gateway::new(port=0)
  gateway.proxy.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.usage.stats.record_inbound(10)
  let _ = gateway.proxy.activate_provider(gateway.usage, "codex")
  gateway.usage.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.usage.record_provider_result(gateway.proxy, false)
  gateway.usage.stats.record_upstream_error_status(0, 502)
  assert_eq(gateway.usage.stats.current_request_app_type, None)
  guard gateway.proxy.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Open)
  assert_eq(stats.total_requests, 1)
  assert_eq(stats.failed_requests, 1)
}

///|
test "moonstat upstream status retryability matches client error bucket" {
  assert_false(moon_upstream_status_retryable(400))
  assert_false(moon_upstream_status_retryable(405))
  assert_false(moon_upstream_status_retryable(406))
  assert_false(moon_upstream_status_retryable(413))
  assert_false(moon_upstream_status_retryable(414))
  assert_false(moon_upstream_status_retryable(415))
  assert_false(moon_upstream_status_retryable(422))
  assert_false(moon_upstream_status_retryable(501))
  assert_true(moon_upstream_status_retryable(401))
  assert_true(moon_upstream_status_retryable(429))
  assert_true(moon_upstream_status_retryable(502))
}

///|
test "proxy service uses moonstat model mapping for upstream claude model" {
  let gateway = Gateway::new(port=0, model="gpt-default")
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="mapped",
    provider_name="Mapped",
    model_mapping=Some(
      ModelMapping::new(sonnet_model=Some("deepseek-v4-pro [1M]")),
    ),
  )
  assert_eq(
    gateway.proxy.upstream_claude_model(
      "claude-sonnet-4-6",
      Some(provider),
      default_model=gateway.model,
    ),
    "deepseek-v4-pro",
  )
  let unmapped = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="plain",
    provider_name="Plain",
  )
  assert_eq(
    gateway.proxy.upstream_claude_model(
      "claude-sonnet-4-6",
      Some(unmapped),
      default_model=gateway.model,
    ),
    "claude-sonnet-4-6",
  )
  assert_eq(
    gateway.proxy.upstream_claude_model(
      "deepseek-v4-pro [1M]",
      Some(unmapped),
      default_model=gateway.model,
    ),
    "deepseek-v4-pro",
  )
  let copilot = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="copilot",
    provider_name="GitHub Copilot",
    provider_type=Some("github_copilot"),
  )
  assert_eq(
    gateway.proxy.upstream_claude_model(
      "claude-sonnet-4-6[1m]",
      Some(copilot),
      default_model=gateway.model,
    ),
    "claude-sonnet-4.6-1m",
  )
}

///|
test "proxy service uses moonstat claude desktop route metadata for upstream model" {
  let gateway = Gateway::new(port=0, model="gpt-default")
  let routes : Map[String, ClaudeDesktopModelRoute] = {
    "claude-sonnet-4-6": ClaudeDesktopModelRoute::new(
      model="deepseek-v4-flash [1M]",
    ),
    "claude-opus-4-8": ClaudeDesktopModelRoute::new(model="upstream-opus"),
  }
  let provider = ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="desktop",
    provider_name="Desktop",
    model_mapping=Some(
      ModelMapping::new(sonnet_model=Some("mapping-should-not-win")),
    ),
    claude_desktop_model_routes=routes,
  )
  assert_eq(
    gateway.proxy.upstream_claude_model(
      "claude-sonnet-4-6",
      Some(provider),
      default_model=gateway.model,
      app_type="claude-desktop",
    ),
    "deepseek-v4-flash",
  )
  assert_eq(
    gateway.proxy.upstream_claude_model(
      "claude-sonnet-4-6-20251001",
      Some(provider),
      default_model=gateway.model,
      app_type="claude-desktop",
    ),
    "claude-sonnet-4-6-20251001",
  )
  assert_eq(
    gateway.proxy.upstream_claude_model(
      "claude-opus-4-8",
      Some(provider),
      default_model=gateway.model,
      app_type="claude-desktop",
    ),
    "upstream-opus",
  )
  assert_eq(
    gateway.proxy.upstream_claude_model(
      "claude-opus-4-7",
      Some(provider),
      default_model=gateway.model,
      app_type="claude-desktop",
    ),
    "claude-opus-4-7",
  )
  assert_eq(
    gateway.proxy.upstream_claude_model(
      "claude-sonnet-4-6",
      Some(provider),
      default_model=gateway.model,
    ),
    "mapping-should-not-win",
  )
}

///|
test "proxy service repairs unsafe moonstat claude desktop route ids" {
  let gateway = Gateway::new(port=0, model="gpt-default")
  let routes : Map[String, ClaudeDesktopModelRoute] = {
    "gpt-5": ClaudeDesktopModelRoute::new(model="gpt-5-upstream [1M]"),
  }
  let provider = ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="unsafe-route",
    provider_name="Unsafe Route",
    claude_desktop_model_routes=routes,
  )
  assert_eq(
    gateway.proxy.upstream_claude_model(
      "claude-sonnet-4-6",
      Some(provider),
      default_model=gateway.model,
      app_type="claude-desktop",
    ),
    "gpt-5-upstream",
  )
  assert_eq(
    gateway.proxy.upstream_claude_model(
      "gpt-5",
      Some(provider),
      default_model=gateway.model,
      app_type="claude-desktop",
    ),
    "gpt-5",
  )
}

///|
fn mimo_anthropic_claude_desktop_provider(
  api_format? : String? = Some("anthropic"),
) -> ProviderRouteTarget {
  let routes : Map[String, ClaudeDesktopModelRoute] = {
    "claude-sonnet-4-6": ClaudeDesktopModelRoute::new(model="mimo-v2.5-pro"),
  }
  ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="mimo",
    provider_name="MiMo",
    api_format~,
    base_url=Some("https://api.xiaomimimo.com/anthropic"),
    claude_desktop_model_routes=routes,
  )
}

///|
test "claude desktop mimo anthropic rewrites redacted thinking for tool history" {
  let provider = mimo_anthropic_claude_desktop_provider()
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "messages": [
      #|    {
      #|      "role": "assistant",
      #|      "content": [
      #|        { "type": "redacted_thinking", "data": "opaque" },
      #|        { "type": "tool_use", "id": "call_1", "name": "read_file", "input": { "path": "README.md" } }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let mapped = claude_request_json_for_upstream(
    claude_desktop_proxy_request_json_for_upstream(
      body, provider, "mimo-v2.5-pro", "claude-desktop",
    ),
    "mimo-v2.5-pro",
  )
  guard mapped is Object(obj) else { fail("expected object") }
  assert_eq(obj["model"], Json::string("mimo-v2.5-pro"))
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(first) else { fail("expected first block") }
  assert_eq(json_string_from_map(first, "type"), Some("thinking"))
  assert_eq(
    json_string_from_map(first, "thinking"),
    Some("[redacted thinking]"),
  )
  guard content[1] is Object(second) else { fail("expected second block") }
  assert_eq(json_string_from_map(second, "type"), Some("tool_use"))
}

///|
test "claude desktop mimo anthropic injects thinking for tool history without one" {
  let provider = mimo_anthropic_claude_desktop_provider()
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "messages": [
      #|    {
      #|      "role": "assistant",
      #|      "content": [
      #|        { "type": "tool_use", "id": "call_1", "name": "read_file", "input": { "path": "README.md" } }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let mapped = claude_desktop_proxy_request_json_for_upstream(
    body, provider, "mimo-v2.5-pro", "claude-desktop",
  )
  guard mapped is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(first) else { fail("expected first block") }
  assert_eq(json_string_from_map(first, "type"), Some("thinking"))
  assert_eq(json_string_from_map(first, "thinking"), Some("tool call"))
  guard content[1] is Object(second) else { fail("expected second block") }
  assert_eq(json_string_from_map(second, "type"), Some("tool_use"))
}

///|
test "claude desktop mimo anthropic keeps thinking text but drops signature" {
  let provider = mimo_anthropic_claude_desktop_provider()
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "messages": [
      #|    {
      #|      "role": "assistant",
      #|      "content": [
      #|        { "type": "thinking", "thinking": "Need to inspect the file.", "signature": "anthropic-signature" },
      #|        { "type": "tool_use", "id": "call_1", "name": "read_file", "input": { "path": "README.md" } }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let mapped = claude_desktop_proxy_request_json_for_upstream(
    body, provider, "mimo-v2.5-pro", "claude-desktop",
  )
  guard mapped is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(first) else { fail("expected first block") }
  assert_eq(
    json_string_from_map(first, "thinking"),
    Some("Need to inspect the file."),
  )
  assert_true(first.get("signature") is None)
}

///|
test "claude desktop mimo normalization is scoped to anthropic mimo providers" {
  let openai_provider = mimo_anthropic_claude_desktop_provider(
    api_format=Some("openai_chat"),
  )
  let plain_provider = ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="plain",
    provider_name="Plain",
    api_format=Some("anthropic"),
  )
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "messages": [
      #|    {
      #|      "role": "assistant",
      #|      "content": [
      #|        { "type": "tool_use", "id": "call_1", "name": "read_file", "input": { "path": "README.md" } }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  assert_eq(
    claude_desktop_proxy_request_json_for_upstream(
      body, openai_provider, "mimo-v2.5-pro", "claude-desktop",
    ),
    body,
  )
  assert_eq(
    claude_desktop_proxy_request_json_for_upstream(
      body, plain_provider, "plain-model", "claude-desktop",
    ),
    body,
  )
}

///|
test "claude desktop status reports moonstat profile and proxy route health" {
  let gateway = Gateway::new(port=17111, host="127.0.0.11")
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude-desktop",
      provider_id="broken-proxy",
      provider_name="Broken Proxy",
      claude_desktop_mode=Some("proxy"),
    ),
  )
  gateway.proxy.provider_router.set_current_provider(
    "claude-desktop", "broken-proxy",
  )
  let status = @claude_desktop.ClaudeDesktopStatus::new(
    configured=true,
    profile_path="/tmp/profile.json",
    meta_path="/tmp/_meta.json",
    config_library_path="/tmp/configLibrary",
    applied_id=Some("00000000-0000-4000-8000-000000157210"),
    actual_base_url=Some("https://wrong.example"),
    stale_raw_models=true,
    token_configured=true,
  )
  json_inspect(
    gateway.proxy.claude_desktop_status_json(status, gateway.host, gateway.port),
    content={
      "supported": true,
      "configured": true,
      "appliedId": "00000000-0000-4000-8000-000000157210",
      "profilePath": "/tmp/profile.json",
      "configLibraryPath": "/tmp/configLibrary",
      "mode": "proxy",
      "expectedBaseUrl": "http://127.0.0.11:17111/claude-desktop",
      "actualBaseUrl": "https://wrong.example",
      "proxyRunning": true,
      "staleRawModels": true,
      "missingRouteMappings": true,
      "gatewayTokenConfigured": true,
    },
  )
}

///|
test "claude desktop status reports direct provider base url" {
  let gateway = Gateway::new(port=17112, host="127.0.0.12")
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude-desktop",
      provider_id="direct",
      provider_name="Direct",
      claude_desktop_mode=Some("direct"),
      settings_config=Some(
        {
          "env": {
            "ANTHROPIC_BASE_URL": Json::string("https://direct.example/v1"),
          }.to_json(),
        }.to_json(),
      ),
    ),
  )
  gateway.proxy.provider_router.set_current_provider("claude-desktop", "direct")
  let status = @claude_desktop.ClaudeDesktopStatus::new(
    configured=true,
    profile_path="/tmp/profile.json",
    meta_path="/tmp/_meta.json",
    config_library_path="/tmp/configLibrary",
    applied_id=None,
    actual_base_url=Some("https://direct.example/v1"),
    stale_raw_models=false,
    token_configured=false,
  )
  guard gateway.proxy.claude_desktop_status_json(
      status,
      gateway.host,
      gateway.port,
    )
    is Object(obj) else {
    fail("expected status object")
  }
  assert_eq(obj["mode"], Json::string("direct"))
  assert_eq(obj["expectedBaseUrl"], Json::string("https://direct.example/v1"))
  assert_eq(obj["actualBaseUrl"], Json::string("https://direct.example/v1"))
  assert_eq(obj["missingRouteMappings"], Json::boolean(false))
}

///|
async test "gateway applies moonstat provider cost multiplier to request log" {
  let gateway = Gateway::new(port=0)
  gateway.usage.pricing_overrides.set("test-model", {
    model_id: "test-model",
    display_name: "Test Model",
    input_cost_per_million: "1.0",
    output_cost_per_million: "0",
    cache_read_cost_per_million: "0",
    cache_creation_cost_per_million: "0",
  })
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="costed",
    provider_name="Costed Provider",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "costMultiplier": "2.5" }
          #|}
        ),
      ),
    ),
  )
  gateway.usage.stats.record_inbound(10)
  assert_true(
    gateway.proxy.activate_provider_target(
      gateway.usage,
      "claude",
      provider,
      bypass_circuit_breaker=true,
    ),
  )
  gateway.usage.stats.record_request_context("claude", "test-model")
  gateway.usage.record_success_usage_with_provider(
    gateway.proxy,
    TokenUsage::new(
      input_tokens=1000,
      output_tokens=0,
      model=Some("test-model"),
    ),
    64,
  )
  assert_eq(gateway.usage.stats.request_logs.length(), 1)
  let log = gateway.usage.stats.request_logs[0]
  assert_eq(log.cost_multiplier, "2.5")
  assert_eq(log.input_cost_usd, "0.001")
  assert_eq(log.total_cost_usd, "0.0025")
  let moon_log = log.to_moon_request_log_detail_json()
  guard moon_log is Object(obj) else { fail("expected object") }
  assert_eq(obj["costMultiplier"], Json::string("2.5"))
}

///|
async test "gateway ignores invalid moonstat provider cost multiplier" {
  let gateway = Gateway::new(port=0)
  gateway.usage.pricing_overrides.set("test-model", {
    model_id: "test-model",
    display_name: "Test Model",
    input_cost_per_million: "1.0",
    output_cost_per_million: "0",
    cache_read_cost_per_million: "0",
    cache_creation_cost_per_million: "0",
  })
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="invalid-cost",
    provider_name="Invalid Cost Provider",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "costMultiplier": "not-a-number" }
          #|}
        ),
      ),
    ),
  )
  gateway.usage.stats.record_inbound(10)
  assert_true(
    gateway.proxy.activate_provider_target(
      gateway.usage,
      "claude",
      provider,
      bypass_circuit_breaker=true,
    ),
  )
  gateway.usage.stats.record_request_context("claude", "test-model")
  gateway.usage.record_success_usage_with_provider(
    gateway.proxy,
    TokenUsage::new(
      input_tokens=1000,
      output_tokens=0,
      model=Some("test-model"),
    ),
    64,
  )
  assert_eq(gateway.usage.stats.request_logs.length(), 1)
  let log = gateway.usage.stats.request_logs[0]
  assert_eq(log.cost_multiplier, "1.0")
  assert_eq(log.total_cost_usd, "0.001")
}

///|
async test "gateway applies moonstat request pricing model source" {
  let gateway = Gateway::new(port=0)
  gateway.usage.pricing_overrides.set("request-model", {
    model_id: "request-model",
    display_name: "Request Model",
    input_cost_per_million: "1.0",
    output_cost_per_million: "0",
    cache_read_cost_per_million: "0",
    cache_creation_cost_per_million: "0",
  })
  gateway.usage.pricing_overrides.set("response-model", {
    model_id: "response-model",
    display_name: "Response Model",
    input_cost_per_million: "9.0",
    output_cost_per_million: "0",
    cache_read_cost_per_million: "0",
    cache_creation_cost_per_million: "0",
  })
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="request-priced",
    provider_name="Request Priced Provider",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "meta": { "pricingModelSource": "request" }
          #|}
        ),
      ),
    ),
  )
  gateway.usage.stats.record_inbound(10)
  assert_true(
    gateway.proxy.activate_provider_target(
      gateway.usage,
      "claude",
      provider,
      bypass_circuit_breaker=true,
    ),
  )
  gateway.usage.stats.record_request_context("claude", "request-model")
  gateway.usage.record_success_usage_with_provider(
    gateway.proxy,
    TokenUsage::new(
      input_tokens=1000,
      output_tokens=0,
      model=Some("response-model"),
    ),
    64,
  )
  assert_eq(gateway.usage.stats.request_logs.length(), 1)
  let log = gateway.usage.stats.request_logs[0]
  assert_eq(log.model, "response-model")
  assert_eq(log.request_model, Some("request-model"))
  assert_eq(log.pricing_model, Some("request-model"))
  assert_eq(log.total_cost_usd, "0.001")
}

///|
async test "gateway records billable moonstat stream usage once" {
  let gateway = Gateway::new(port=0)
  gateway.usage.stats.record_inbound(10)
  let _ = gateway.proxy.activate_provider(gateway.usage, "codex")
  gateway.usage.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.usage.stats.record_stream_mode(true)
  gateway.usage.record_success_stream_usage_with_provider(
    gateway.proxy,
    Some(
      TokenUsage::new(
        input_tokens=10,
        output_tokens=2,
        cache_read_tokens=4,
        model=Some("gpt-5"),
      ),
    ),
    42,
  )
  assert_eq(gateway.usage.stats.successful_responses, 1)
  assert_eq(gateway.usage.stats.input_tokens, 10)
  assert_eq(gateway.usage.stats.cache_read_tokens, 4)
  assert_eq(gateway.usage.stats.request_logs.length(), 1)
  let log = gateway.usage.stats.request_logs[0]
  assert_true(log.is_streaming)
  assert_eq(log.model, "gpt-5")
  assert_eq(log.input_tokens, 10)
  guard gateway.proxy.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_eq(stats.total_requests, 1)
}

///|
async test "gateway records all zero moonstat stream usage request log" {
  let gateway = Gateway::new(port=0)
  gateway.usage.stats.record_inbound(10)
  let _ = gateway.proxy.activate_provider(gateway.usage, "codex")
  gateway.usage.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.usage.stats.record_stream_mode(true)
  gateway.usage.record_success_stream_usage_with_provider(
    gateway.proxy,
    Some(TokenUsage::empty()),
    42,
  )
  assert_eq(gateway.usage.stats.successful_responses, 1)
  assert_eq(gateway.usage.stats.response_bytes, 42)
  assert_eq(gateway.usage.stats.request_logs.length(), 1)
  let log = gateway.usage.stats.request_logs[0]
  assert_true(log.is_streaming)
  assert_eq(log.model, "gpt-5")
  assert_eq(log.input_tokens, 0)
  assert_eq(log.output_tokens, 0)
  assert_eq(log.total_cost_usd, "0")
  assert_eq(log.status_code, 200)
}

///|
async test "gateway skips all zero moonstat transformed stream usage log" {
  let gateway = Gateway::new(port=0)
  gateway.usage.stats.record_inbound(10)
  let _ = gateway.proxy.activate_provider(gateway.usage, "codex")
  gateway.usage.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.usage.stats.record_stream_mode(true)
  gateway.usage.record_success_stream_usage_with_provider(
    gateway.proxy,
    Some(TokenUsage::empty()),
    42,
    skip_empty_usage=true,
  )
  assert_eq(gateway.usage.stats.successful_responses, 1)
  assert_eq(gateway.usage.stats.response_bytes, 42)
  assert_eq(gateway.usage.stats.request_logs.length(), 0)
  assert_true(gateway.usage.stats.current_request_id is None)
}

///|
async test "gateway records all zero moonstat nonstream usage request log" {
  let gateway = Gateway::new(port=0)
  gateway.usage.stats.record_inbound(10)
  let _ = gateway.proxy.activate_provider(gateway.usage, "codex")
  gateway.usage.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.usage.stats.record_stream_mode(false)
  gateway.usage.record_success_usage_with_provider(
    gateway.proxy,
    TokenUsage::empty(),
    42,
  )
  assert_eq(gateway.usage.stats.successful_responses, 1)
  assert_eq(gateway.usage.stats.response_bytes, 42)
  assert_eq(gateway.usage.stats.request_logs.length(), 1)
  let log = gateway.usage.stats.request_logs[0]
  assert_false(log.is_streaming)
  assert_eq(log.model, "gpt-5")
  assert_eq(log.input_tokens, 0)
  assert_eq(log.output_tokens, 0)
  assert_eq(log.total_cost_usd, "0")
  assert_eq(log.status_code, 200)
  guard gateway.proxy.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_eq(stats.total_requests, 1)
}

///|
async test "gateway nonretryable upstream errors release half open permit" {
  let gateway = Gateway::new(port=0)
  gateway.proxy.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 0,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  assert_true(
    gateway.proxy.provider_router.update_providers_sort_order("codex", [
      { id: "codex-oauth", sort_index: 0 },
      { id: "codex-alt", sort_index: 1 },
    ]),
  )
  gateway.proxy.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.proxy.provider_router.set_auto_failover("codex", true)

  gateway.usage.stats.record_inbound(10)
  let _ = gateway.proxy.activate_provider(gateway.usage, "codex")
  gateway.usage.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.usage.record_provider_result(gateway.proxy, false)
  gateway.usage.stats.record_upstream_error_status(0, 502)

  gateway.usage.stats.record_inbound(10)
  let _ = gateway.proxy.activate_provider(gateway.usage, "codex")
  assert_true(gateway.usage.stats.current_request_used_half_open_permit)
  gateway.usage.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.usage.record_upstream_error_status_with_provider(
    gateway.proxy,
    0,
    400,
  )

  guard gateway.proxy.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == HalfOpen)
  assert_eq(stats.total_requests, 1)
  assert_eq(stats.failed_requests, 1)

  gateway.usage.stats.record_inbound(10)
  let third = gateway.proxy.activate_provider(gateway.usage, "codex")
  assert_true(third is Some(_))
  assert_true(gateway.usage.stats.current_request_used_half_open_permit)
}

///|
async test "gateway streaming success records provider health before request completion" {
  let gateway = Gateway::new(port=0)
  gateway.proxy.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.usage.stats.record_inbound(16)
  gateway.usage.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  gateway.usage.stats.record_stream_mode(true)
  let selected = gateway.proxy.activate_provider(gateway.usage, "codex")
  guard selected is Some(provider) else { fail("expected provider") }
  assert_true(provider.provider_id == "codex-oauth")

  gateway.usage.record_provider_result(gateway.proxy, true)
  guard gateway.proxy.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats_after_first_chunk) else {
    fail("expected circuit stats")
  }
  assert_true(stats_after_first_chunk.total_requests == 1)
  assert_true(stats_after_first_chunk.failed_requests == 0)
  assert_true(gateway.usage.stats.successful_responses == 0)
  guard gateway.usage.stats.current_request_id is Some(_) else {
    fail("request should remain open until stream end")
  }

  gateway.usage.record_success_stream_usage_with_provider(
    gateway.proxy,
    None,
    24,
    record_provider=false,
    first_token_ms=Some(7),
  )
  assert_true(gateway.usage.stats.successful_responses == 1)
  assert_true(gateway.usage.stats.response_bytes == 24)
  assert_true(gateway.usage.stats.request_logs.length() == 1)
  assert_true(gateway.usage.stats.request_logs[0].is_streaming)
  assert_true(gateway.usage.stats.request_logs[0].model == "gpt-5")
  assert_true(gateway.usage.stats.request_logs[0].first_token_ms == Some(7))
  assert_true(gateway.usage.stats.current_request_id is None)
  guard gateway.proxy.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats_after_stream_end) else {
    fail("expected circuit stats")
  }
  assert_true(stats_after_stream_end.total_requests == 1)
  assert_true(stats_after_stream_end.failed_requests == 0)
}

///|
test "gateway activation skips occupied half open provider in failover chain" {
  let gateway = Gateway::new(port=0)
  gateway.proxy.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 0,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  assert_true(
    gateway.proxy.provider_router.update_providers_sort_order("codex", [
      { id: "codex-oauth", sort_index: 0 },
      { id: "codex-alt", sort_index: 1 },
    ]),
  )
  gateway.proxy.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.proxy.provider_router.set_auto_failover("codex", true)
  gateway.proxy.provider_router.record_result(
    "codex-oauth",
    "codex",
    false,
    false,
    now_ms=1000,
  )
  let occupied = gateway.proxy.provider_router.allow_provider_request(
    "codex-oauth",
    "codex",
    now_ms=1000,
  )
  assert_true(occupied.allowed)
  assert_true(occupied.used_half_open_permit)

  let selected = gateway.proxy.activate_provider(gateway.usage, "codex")
  guard selected is Some(provider) else { fail("expected fallback provider") }
  assert_eq(provider.provider_id, "codex-alt")
  assert_eq(gateway.usage.stats.current_provider_id, Some("codex-alt"))
  assert_false(gateway.usage.stats.current_request_used_half_open_permit)
}

///|
test "gateway activation can exclude already attempted failover providers" {
  let gateway = Gateway::new(port=0)
  let providers = [
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="primary",
      provider_name="Primary",
    ),
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="fallback",
      provider_name="Fallback",
    ),
  ]
  for provider in providers {
    gateway.proxy.provider_router.upsert_provider(provider)
  }
  gateway.proxy.provider_router.set_auto_failover("codex", true)
  let selected = gateway.proxy.activate_first_available_provider_excluding(
    gateway.usage,
    "codex",
    providers,
    ["primary"],
  )
  guard selected is Some(provider) else {
    fail("expected unattempted fallback provider")
  }
  assert_eq(provider.provider_id, "fallback")
  assert_eq(gateway.usage.stats.current_provider_id, Some("fallback"))
}

///|
test "gateway retryable upstream status activates next failover provider" {
  let gateway = Gateway::new(port=0)
  gateway.proxy.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  assert_true(
    gateway.proxy.provider_router.update_providers_sort_order("codex", [
      { id: "codex-oauth", sort_index: 0 },
      { id: "codex-alt", sort_index: 1 },
    ]),
  )
  gateway.proxy.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.proxy.provider_router.set_auto_failover("codex", true)
  let selection = gateway.proxy.provider_router.select_providers(
    "codex",
    now_ms=1000,
  )
  assert_true(selection.is_ok())
  assert_true(selection.providers.length() == 2)

  gateway.usage.stats.record_inbound(10)
  gateway.usage.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  let first = gateway.proxy.activate_first_available_provider(
    gateway.usage,
    "codex",
    selection.providers,
  )
  guard first is Some(primary) else { fail("expected primary provider") }
  assert_true(primary.provider_id == "codex-oauth")

  let attempted : Array[String] = []
  let next = gateway.proxy.activate_next_provider_after_upstream_status(
    gateway.usage,
    "codex",
    selection.providers,
    attempted,
    502,
  )
  guard next is Some(fallback) else { fail("expected fallback provider") }
  assert_true(attempted.length() == 1)
  assert_true(attempted[0] == "codex-oauth")
  assert_true(fallback.provider_id == "codex-alt")
  guard gateway.usage.stats.current_provider_id is Some(current_provider_id) else {
    fail("expected current provider id")
  }
  assert_true(current_provider_id == "codex-alt")
  guard gateway.usage.stats.current_request_app_type is Some(current_app_type) else {
    fail("expected current request app type")
  }
  assert_true(current_app_type == "codex")
  guard gateway.proxy.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected primary circuit stats")
  }
  assert_true(stats.state == Open)
  assert_true(stats.total_requests == 1)
  assert_true(stats.failed_requests == 1)
}

///|
test "gateway retryable upstream status respects moonstat max retries cap before permits" {
  let gateway = Gateway::new(port=0)
  gateway.proxy.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 0,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  assert_true(
    gateway.proxy.provider_router.update_providers_sort_order("codex", [
      { id: "codex-oauth", sort_index: 0 },
      { id: "codex-alt", sort_index: 1 },
    ]),
  )
  gateway.proxy.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.proxy.provider_router.set_auto_failover("codex", true)
  gateway.proxy.provider_router.set_max_retries("codex", 0)
  gateway.proxy.provider_router.record_result(
    "codex-alt",
    "codex",
    false,
    false,
    now_ms=1000,
  )
  let selection = gateway.proxy.provider_router.select_providers(
    "codex",
    now_ms=1000,
  )
  assert_true(selection.is_ok())
  assert_eq(selection.providers.length(), 2)

  gateway.usage.stats.record_inbound(10)
  gateway.usage.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  let first = gateway.proxy.activate_first_available_provider(
    gateway.usage,
    "codex",
    selection.providers,
  )
  guard first is Some(primary) else { fail("expected primary provider") }
  assert_eq(primary.provider_id, "codex-oauth")

  let attempted : Array[String] = []
  let next = gateway.proxy.activate_next_provider_after_upstream_status(
    gateway.usage,
    "codex",
    selection.providers,
    attempted,
    502,
  )
  assert_true(next is None)
  assert_eq(attempted.length(), 1)
  assert_eq(attempted[0], "codex-oauth")
  assert_eq(gateway.usage.stats.current_provider_id, Some("codex-oauth"))

  let fallback_permit = gateway.proxy.provider_router.allow_provider_request(
    "codex-alt",
    "codex",
    now_ms=1000,
  )
  assert_true(fallback_permit.allowed)
  assert_true(fallback_permit.used_half_open_permit)
}

///|
test "gateway retryable final provider remains active for final upstream error" {
  let gateway = Gateway::new(port=0)
  gateway.proxy.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  let selection = gateway.proxy.provider_router.select_providers(
    "codex",
    now_ms=1000,
  )
  assert_true(selection.is_ok())
  assert_true(selection.providers.length() == 1)

  gateway.usage.stats.record_inbound(10)
  gateway.usage.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  let selected = gateway.proxy.activate_first_available_provider(
    gateway.usage,
    "codex",
    selection.providers,
  )
  guard selected is Some(provider) else { fail("expected provider") }
  assert_true(provider.provider_id == "codex-oauth")

  let attempted : Array[String] = []
  let next = gateway.proxy.activate_next_provider_after_upstream_status(
    gateway.usage,
    "codex",
    selection.providers,
    attempted,
    502,
  )
  assert_true(next is None)
  assert_true(attempted.length() == 1)
  assert_true(attempted[0] == "codex-oauth")
  guard gateway.usage.stats.current_provider_id is Some(current_provider_id) else {
    fail("expected current provider id")
  }
  assert_true(current_provider_id == "codex-oauth")
  guard gateway.proxy.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Open)
  assert_true(stats.total_requests == 1)
  assert_true(stats.failed_requests == 1)
}

///|
test "gateway nonretryable upstream status does not activate failover provider" {
  let gateway = Gateway::new(port=0)
  gateway.proxy.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-alt",
      provider_name="Codex Alt",
    ),
  )
  assert_true(
    gateway.proxy.provider_router.update_providers_sort_order("codex", [
      { id: "codex-oauth", sort_index: 0 },
      { id: "codex-alt", sort_index: 1 },
    ]),
  )
  gateway.proxy.provider_router.set_failover_queue("codex", [
    "codex-oauth", "codex-alt",
  ])
  gateway.proxy.provider_router.set_auto_failover("codex", true)
  let selection = gateway.proxy.provider_router.select_providers(
    "codex",
    now_ms=1000,
  )
  assert_true(selection.is_ok())
  assert_true(selection.providers.length() == 2)

  gateway.usage.stats.record_inbound(10)
  gateway.usage.stats.record_request_context(
    "codex",
    "gpt-5",
    provider_type=Some("codex"),
  )
  let selected = gateway.proxy.activate_first_available_provider(
    gateway.usage,
    "codex",
    selection.providers,
  )
  guard selected is Some(provider) else { fail("expected provider") }
  assert_true(provider.provider_id == "codex-oauth")

  let attempted : Array[String] = []
  let next = gateway.proxy.activate_next_provider_after_upstream_status(
    gateway.usage,
    "codex",
    selection.providers,
    attempted,
    400,
  )
  assert_true(next is None)
  assert_true(attempted.length() == 1)
  assert_true(attempted[0] == "codex-oauth")
  guard gateway.usage.stats.current_provider_id is Some(current_provider_id) else {
    fail("expected current provider id")
  }
  assert_true(current_provider_id == "codex-oauth")
  guard gateway.proxy.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Closed)
  assert_true(stats.total_requests == 0)
  assert_true(stats.failed_requests == 0)
}

///|
test "gateway activation bypasses circuit breaker for single provider" {
  let gateway = Gateway::new(port=0)
  gateway.proxy.provider_router.update_all_configs({
    failure_threshold: 1,
    success_threshold: 2,
    timeout_seconds: 60,
    error_rate_threshold: 0.6,
    min_requests: 10,
  })
  gateway.proxy.provider_router.record_result(
    "codex-oauth",
    "codex",
    false,
    false,
    now_ms=1000,
  )
  guard gateway.proxy.provider_router.get_circuit_breaker_stats(
      "codex-oauth", "codex",
    )
    is Some(stats) else {
    fail("expected circuit stats")
  }
  assert_true(stats.state == Open)

  let selected = gateway.proxy.activate_provider(gateway.usage, "codex")
  guard selected is Some(provider) else {
    fail("single provider should bypass circuit gating")
  }
  assert_eq(provider.provider_id, "codex-oauth")
  assert_eq(gateway.usage.stats.current_provider_id, Some("codex-oauth"))
  assert_false(gateway.usage.stats.current_request_used_half_open_permit)
}

///|
test "codex compatible provider url follows moonstat base url rules" {
  assert_true(
    codex_compatible_provider_url("https://api.openai.com", "/responses") ==
    "https://api.openai.com/v1/responses",
  )
  assert_true(
    codex_compatible_provider_url(
      "https://api.openai.com/v1", "/v1/responses?conversation=abc",
    ) ==
    "https://api.openai.com/v1/responses?conversation=abc",
  )
  assert_true(
    codex_compatible_provider_url(
      "https://proxy.example.com/openai", "/responses",
    ) ==
    "https://proxy.example.com/openai/responses",
  )
  assert_true(
    codex_compatible_provider_url(
      "https://proxy.example.com/v1/responses", "/responses?conversation=abc",
    ) ==
    "https://proxy.example.com/v1/responses?conversation=abc",
  )
}

///|
test "claude compatible provider api format follows moonstat endpoints" {
  let chat_provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="openai-chat",
    provider_name="OpenAI Chat",
    provider_type=Some("openai"),
    api_format=Some("openai_chat"),
    base_url=Some("https://api.openai.com/v1"),
    api_key=Some("sk-test"),
  )
  assert_eq(chat_provider.claude_api_format(), "openai_chat")
  assert_true(chat_provider.can_use_claude_compatible_upstream())
  assert_eq(
    claude_transform_endpoint(chat_provider.claude_api_format(), false),
    "/v1/chat/completions",
  )
  assert_eq(
    codex_compatible_provider_url(
      "https://api.openai.com/v1",
      claude_transform_endpoint(chat_provider.claude_api_format(), false),
    ),
    "https://api.openai.com/v1/chat/completions",
  )

  let responses_provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="openai-responses",
    provider_name="OpenAI Responses",
    api_format=Some("openai_responses"),
    base_url=Some("https://api.openai.com"),
    api_key=Some("sk-test"),
  )
  assert_eq(
    claude_transform_endpoint(responses_provider.claude_api_format(), false),
    "/v1/responses",
  )
  assert_eq(
    codex_compatible_provider_url(
      "https://api.openai.com",
      claude_transform_endpoint(responses_provider.claude_api_format(), false),
    ),
    "https://api.openai.com/v1/responses",
  )
}

///|
test "github copilot provider api format follows moonstat model vendor" {
  let openai_copilot = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="copilot-openai",
    provider_name="GitHub Copilot OpenAI",
    provider_type=Some("github_copilot"),
    base_url=Some("https://api.githubcopilot.com"),
    api_key=Some("PROXY_MANAGED"),
    settings_config=Some(
      Json::object({
        "copilotModels": Json::object({
          "data": Json::array([
            Json::object({
              "id": Json::string("gpt-5.4"),
              "name": Json::string("GPT"),
              "vendor": Json::string("OpenAI"),
            }),
          ]),
        }),
      }),
    ),
  )
  assert_eq(
    openai_copilot.claude_api_format_for_model("gpt-5.4"),
    "openai_responses",
  )
  assert_eq(
    claude_transform_endpoint(
      openai_copilot.claude_api_format_for_model("gpt-5.4"),
      false,
      request_path="/v1/messages?beta=true&x-id=1",
    ),
    "/v1/responses?x-id=1",
  )

  let anthropic_copilot = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="copilot-anthropic",
    provider_name="GitHub Copilot Anthropic",
    provider_type=Some("github_copilot"),
    settings_config=Some(
      Json::object({
        "models": Json::array([
          Json::object({
            "id": Json::string("claude-sonnet-4.6"),
            "vendor": Json::string("Anthropic"),
          }),
        ]),
      }),
    ),
  )
  assert_eq(
    anthropic_copilot.claude_api_format_for_model("claude-sonnet-4.6"),
    "openai_chat",
  )
  let unknown_copilot = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="copilot-unknown",
    provider_name="GitHub Copilot Unknown",
    provider_type=Some("github_copilot"),
  )
  assert_eq(
    unknown_copilot.claude_api_format_for_model("gpt-5.4"),
    "openai_chat",
  )
}

///|
test "claude compatible provider endpoints preserve moonstat query semantics" {
  assert_eq(
    claude_transform_endpoint(
      "openai_chat",
      false,
      request_path="/v1/messages?beta=true&conversation=abc",
    ),
    "/v1/chat/completions?conversation=abc",
  )
  assert_eq(
    claude_transform_endpoint(
      "openai_responses",
      false,
      request_path="/v1/messages?conversation=abc&beta=true",
    ),
    "/v1/responses?conversation=abc",
  )
  assert_eq(
    claude_transform_endpoint(
      "anthropic",
      false,
      request_path="/v1/messages?beta=true",
    ),
    "/v1/messages",
  )
  assert_eq(
    claude_transform_endpoint(
      "gemini_native",
      true,
      request_path="/v1/messages?alt=json&beta=true&key=abc",
    ),
    "/v1beta/models/__MODEL__:streamGenerateContent?key=abc&alt=sse",
  )
  assert_eq(
    claude_transform_endpoint(
      "gemini_native",
      false,
      request_path="/v1/messages?alt=sse&beta=true&key=abc",
    ),
    "/v1beta/models/__MODEL__:generateContent?key=abc",
  )
  assert_eq(
    claude_transform_endpoint(
      "openai_chat",
      false,
      request_path="/v1/models?beta=true&conversation=abc",
    ),
    "/v1/models?beta=true&conversation=abc",
  )
  assert_eq(
    claude_transform_endpoint(
      "gemini_native",
      true,
      request_path="/v1/models?alt=json&key=abc",
    ),
    "/v1/models?alt=json&key=abc",
  )
}

///|
test "moonstat streaming request detection mirrors proxy forwarder" {
  assert_true(
    moon_streaming_request("/v1/responses", @json.parse("{\"stream\":true}"), {}),
  )
  assert_true(
    moon_streaming_request(
      "/v1beta/models/gemini-2.5-pro:streamGenerateContent?alt=sse",
      @json.parse("{\"model\":\"gemini-2.5-pro\"}"),
      {},
    ),
  )
  assert_true(
    moon_streaming_request(
      "/v1/responses",
      @json.parse("{\"model\":\"gpt-5\"}"),
      { "accept": "application/json, text/event-stream" },
    ),
  )
  assert_false(
    moon_streaming_request(
      "/v1/responses",
      @json.parse("{\"model\":\"gpt-5\"}"),
      {},
    ),
  )
}

///|
test "codex compatible provider detects chat completions bridge" {
  let format_provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="chat-format",
    provider_name="Chat Format",
    api_format=Some("openai_chat"),
    base_url=Some("https://api.example.com/v1"),
    api_key=Some("sk-test"),
  )
  assert_true(format_provider.codex_uses_chat_completions())
  assert_eq(
    codex_compatible_provider_url(
      "https://api.example.com/v1",
      codex_compatible_chat_completions_endpoint(
        "/backend-api/codex/responses?x=1",
      ),
    ),
    "https://api.example.com/v1/chat/completions?x=1",
  )
  assert_eq(
    codex_compatible_provider_url(
      "https://api.example.com/v1",
      codex_compatible_chat_completions_endpoint(
        "/backend-api/codex/responses/compact?foo=bar",
      ),
    ),
    "https://api.example.com/v1/chat/completions?foo=bar",
  )
  let full_url_provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="chat-url",
    provider_name="Chat URL",
    base_url=Some("https://api.example.com/v1/chat/completions"),
    api_key=Some("sk-test"),
  )
  assert_true(full_url_provider.codex_uses_chat_completions())
  assert_eq(
    codex_compatible_provider_url(
      "https://api.example.com/v1/chat/completions?fixed=1",
      codex_compatible_chat_completions_endpoint(
        "/backend-api/codex/responses/compact?foo=bar",
      ),
    ),
    "https://api.example.com/v1/chat/completions?fixed=1&foo=bar",
  )
}

///|
test "claude upstream request json rewrites mapped model" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "max_tokens": 128,
      #|  "messages": [
      #|    { "role": "user", "content": "hello" }
      #|  ]
      #|}
    ),
  )
  let upstream = claude_request_json_for_upstream(body, "gpt-5.4")
  guard upstream is Object(obj) else { fail("expected object") }
  assert_eq(obj["model"], Json::string("gpt-5.4"))
  assert_true(obj.get("messages") is Some(_))
}

///|
test "claude stream upstream request forces stream true" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "max_tokens": 128,
      #|  "stream": false,
      #|  "messages": [
      #|    { "role": "user", "content": "hello" }
      #|  ]
      #|}
    ),
  )
  let upstream = claude_stream_request_json_for_upstream(body, "gpt-5.4")
  guard upstream is Object(obj) else { fail("expected object") }
  assert_eq(obj["model"], Json::string("gpt-5.4"))
  assert_eq(obj["stream"], Json::boolean(true))
}

///|
test "moonstat responses sse parser handles missing trailing blank line" {
  let sse =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_tail","status":"completed","model":"gpt-5.4","output":[],"usage":{"input_tokens":3,"output_tokens":1}}}
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_responses",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed response")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  assert_eq(obj["id"], Json::string("resp_tail"))
  assert_eq(obj["model"], Json::string("gpt-5.4"))
  guard obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(3.0))
  assert_eq(usage["output_tokens"], Json::number(1.0))
}

///|
test "moonstat responses sse parser strips bom before parsing" {
  let sse = "\u{feff}event: response.completed\n" +
    "data: {\"type\":\"response.completed\",\"response\":{\"id\":\"resp_bom\",\"status\":\"completed\",\"model\":\"gpt-5.4\",\"output\":[],\"usage\":{\"input_tokens\":3,\"output_tokens\":1}}}"
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_responses",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed response")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  assert_eq(obj["id"], Json::string("resp_bom"))
}

///|
test "moonstat responses stream parser accepts data field without space" {
  let block = "event:response.output_text.delta\n" +
    "data:{\"type\":\"response.output_text.delta\",\"delta\":\"hi\"}\n\n"
  let (done, parsed, event) = codex_stream_event_from_sse_block(
    block, "gpt-5.4",
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  guard event is Some(event) else { fail("expected stream event") }
  assert_eq(event.event_type, "content_block_delta")
  let data = @json.parse(event.data) catch {
    _ => fail("expected json event data")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["text"], Json::string("hi"))
}

///|
test "moonstat responses stream parser skips non emitting lifecycle blocks" {
  let block =
    #|event: response.in_progress
    #|data: {"type":"response.in_progress"}
    #|
  let (done, parsed, event) = codex_stream_event_from_sse_block(
    block, "gpt-5.4",
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  assert_true(event is None)
}

///|
test "moonstat responses stream parser converts response created to message start" {
  let block =
    #|event: response.created
    #|data: {"type":"response.created","response":{"id":"resp_start","status":"in_progress","model":"gpt-5.4","usage":{"input_tokens":12,"output_tokens":0,"input_tokens_details":{"cached_tokens":4}}}}
    #|
  let (done, parsed, event) = codex_stream_event_from_sse_block(
    block, "fallback-model",
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  guard event is Some(event) else { fail("expected stream event") }
  assert_eq(event.event_type, "message_start")
  let data = @json.parse(event.data) catch {
    _ => fail("expected json event data")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["message"] is Object(message) else { fail("expected message") }
  assert_eq(message["id"], Json::string("resp_start"))
  assert_eq(message["model"], Json::string("gpt-5.4"))
  guard message["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(8.0))
  assert_eq(usage["output_tokens"], Json::number(0.0))
  assert_eq(usage["cache_read_input_tokens"], Json::number(4.0))
}

///|
test "moonstat responses stream parser preserves completed usage" {
  let block =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_done","status":"completed","model":"gpt-5.4","output":[],"usage":{"prompt_tokens":11,"completion_tokens":5,"prompt_tokens_details":{"cached_tokens":3}}}}
    #|
  let (done, parsed, event) = codex_stream_event_from_sse_block(
    block, "gpt-5.4",
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  guard event is Some(event) else { fail("expected stream event") }
  assert_eq(event.event_type, "message_delta")
  let data = @json.parse(event.data) catch {
    _ => fail("expected json event data")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["stop_reason"], Json::string("end_turn"))
  assert_eq(delta["stop_sequence"], Json::null())
  guard obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(8.0))
  assert_eq(usage["output_tokens"], Json::number(5.0))
  assert_eq(usage["cache_read_input_tokens"], Json::number(3.0))
}

///|
test "moonstat responses stream parser maps incomplete max output to max tokens" {
  let block =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_max","status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"model":"gpt-5.4","output":[],"usage":{"input_tokens":6,"output_tokens":2}}}
    #|
  let (done, parsed, event) = codex_stream_event_from_sse_block(
    block, "gpt-5.4",
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  guard event is Some(event) else { fail("expected stream event") }
  let data = @json.parse(event.data) catch {
    _ => fail("expected json event data")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["stop_reason"], Json::string("max_tokens"))
}

///|
test "moonstat responses stream parser maps completed function output to tool use" {
  let block =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_tool","status":"completed","model":"gpt-5.4","output":[{"type":"function_call","call_id":"call_1","name":"lookup","arguments":"{}"}],"usage":{"input_tokens":6,"output_tokens":2}}}
    #|
  let (done, parsed, event) = codex_stream_event_from_sse_block(
    block, "gpt-5.4",
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  guard event is Some(event) else { fail("expected stream event") }
  let data = @json.parse(event.data) catch {
    _ => fail("expected json event data")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["stop_reason"], Json::string("tool_use"))
}

///|
test "moonstat responses stream state starts text block before text delta" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let block =
    #|event: response.output_text.delta
    #|data: {"type":"response.output_text.delta","delta":"hello"}
    #|
  let (done, parsed, events) = codex_stream_events_from_sse_block(block, state)
  assert_false(done)
  assert_true(parsed is Some(_))
  assert_eq(events.length(), 3)
  assert_eq(events[0].event_type, "message_start")
  assert_eq(events[1].event_type, "content_block_start")
  assert_eq(events[2].event_type, "content_block_delta")
  let start_data = @json.parse(events[1].data) catch {
    _ => fail("expected start json")
  }
  guard start_data is Object(start_obj) else { fail("expected object") }
  assert_eq(start_obj["index"], Json::number(0.0))
  guard start_obj["content_block"] is Object(block_obj) else {
    fail("expected content block")
  }
  assert_eq(block_obj["type"], Json::string("text"))
  let delta_data = @json.parse(events[2].data) catch {
    _ => fail("expected delta json")
  }
  guard delta_data is Object(delta_obj) else { fail("expected object") }
  guard delta_obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["text"], Json::string("hello"))
}

///|
test "moonstat responses stream state closes dangling text on completed" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let text_block =
    #|event: response.output_text.delta
    #|data: {"type":"response.output_text.delta","delta":"hello"}
    #|
  let (_, _, first_events) = codex_stream_events_from_sse_block(
    text_block, state,
  )
  assert_eq(first_events.length(), 3)
  let completed_block =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_done","status":"completed","model":"gpt-5.4","output":[],"usage":{"input_tokens":6,"output_tokens":2}}}
    #|
  let (done, parsed, finish_events) = codex_stream_events_from_sse_block(
    completed_block, state,
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  assert_eq(finish_events.length(), 2)
  assert_eq(finish_events[0].event_type, "content_block_stop")
  assert_eq(finish_events[1].event_type, "message_delta")
  let stop_data = @json.parse(finish_events[0].data) catch {
    _ => fail("expected stop json")
  }
  guard stop_data is Object(stop_obj) else { fail("expected object") }
  assert_eq(stop_obj["index"], Json::number(0.0))
}

///|
test "moonstat responses stream state merges keyed text parts" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let first_added =
    #|event: response.content_part.added
    #|data: {"type":"response.content_part.added","part":{"type":"output_text","text":""},"output_index":0,"content_index":0}
    #|
  let (_, _, first_added_events) = codex_stream_events_from_sse_block(
    first_added, state,
  )
  assert_eq(first_added_events.length(), 2)
  assert_eq(first_added_events[0].event_type, "message_start")
  assert_eq(first_added_events[1].event_type, "content_block_start")

  let first_delta =
    #|event: response.output_text.delta
    #|data: {"type":"response.output_text.delta","delta":"你","output_index":0,"content_index":0}
    #|
  let (_, _, first_delta_events) = codex_stream_events_from_sse_block(
    first_delta, state,
  )
  assert_eq(first_delta_events.length(), 1)

  let first_done =
    #|event: response.content_part.done
    #|data: {"type":"response.content_part.done","output_index":0,"content_index":0}
    #|
  let (_, _, first_done_events) = codex_stream_events_from_sse_block(
    first_done, state,
  )
  assert_eq(first_done_events.length(), 0)

  let second_added =
    #|event: response.content_part.added
    #|data: {"type":"response.content_part.added","part":{"type":"output_text","text":""},"output_index":0,"content_index":1}
    #|
  let (_, _, second_added_events) = codex_stream_events_from_sse_block(
    second_added, state,
  )
  assert_eq(second_added_events.length(), 0)

  let second_delta =
    #|event: response.output_text.delta
    #|data: {"type":"response.output_text.delta","delta":"好","output_index":0,"content_index":1}
    #|
  let (_, _, second_delta_events) = codex_stream_events_from_sse_block(
    second_delta, state,
  )
  assert_eq(second_delta_events.length(), 1)

  let text_done =
    #|event: response.output_text.done
    #|data: {"type":"response.output_text.done","output_index":0,"content_index":1}
    #|
  let (_, _, text_done_events) = codex_stream_events_from_sse_block(
    text_done, state,
  )
  assert_eq(text_done_events.length(), 1)
  assert_eq(text_done_events[0].event_type, "content_block_stop")
}

///|
test "moonstat responses stream state closes keyed text without current index" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let added =
    #|event: response.content_part.added
    #|data: {"type":"response.content_part.added","part":{"type":"refusal","text":""},"item_id":"msg_1","content_index":0}
    #|
  let (_, _, added_events) = codex_stream_events_from_sse_block(added, state)
  assert_eq(added_events.length(), 2)
  state.current_text_index = None
  let done =
    #|event: response.refusal.done
    #|data: {"type":"response.refusal.done","item_id":"msg_1","content_index":0}
    #|
  let (_, _, done_events) = codex_stream_events_from_sse_block(done, state)
  assert_eq(done_events.length(), 1)
  assert_eq(done_events[0].event_type, "content_block_stop")
  let stop_data = @json.parse(done_events[0].data) catch {
    _ => fail("expected stop json")
  }
  guard stop_data is Object(stop_obj) else { fail("expected object") }
  assert_eq(stop_obj["index"], Json::number(0.0))
}

///|
test "moonstat responses stream state emits reasoning thinking blocks" {
  let state = ResponsesStreamState::new("o3")
  let reasoning_block =
    #|event: response.reasoning.delta
    #|data: {"type":"response.reasoning.delta","delta":"Let me think..."}
    #|
  let (done, parsed, events) = codex_stream_events_from_sse_block(
    reasoning_block, state,
  )
  assert_false(done)
  assert_true(parsed is Some(_))
  assert_eq(events.length(), 3)
  assert_eq(events[0].event_type, "message_start")
  assert_eq(events[1].event_type, "content_block_start")
  assert_eq(events[2].event_type, "content_block_delta")
  let start_data = @json.parse(events[1].data) catch {
    _ => fail("expected start json")
  }
  guard start_data is Object(start_obj) else { fail("expected object") }
  assert_eq(start_obj["index"], Json::number(0.0))
  guard start_obj["content_block"] is Object(content_block) else {
    fail("expected content block")
  }
  assert_eq(content_block["type"], Json::string("thinking"))
  assert_eq(content_block["thinking"], Json::string(""))
  let delta_data = @json.parse(events[2].data) catch {
    _ => fail("expected delta json")
  }
  guard delta_data is Object(delta_obj) else { fail("expected object") }
  guard delta_obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["type"], Json::string("thinking_delta"))
  assert_eq(delta["thinking"], Json::string("Let me think..."))

  let done_block =
    #|event: response.reasoning.done
    #|data: {"type":"response.reasoning.done"}
    #|
  let (_, _, done_events) = codex_stream_events_from_sse_block(
    done_block, state,
  )
  assert_eq(done_events.length(), 1)
  assert_eq(done_events[0].event_type, "content_block_stop")
  let stop_data = @json.parse(done_events[0].data) catch {
    _ => fail("expected stop json")
  }
  guard stop_data is Object(stop_obj) else { fail("expected object") }
  assert_eq(stop_obj["index"], Json::number(0.0))
}

///|
test "moonstat responses stream state closes reasoning before text on completed" {
  let state = ResponsesStreamState::new("o3")
  let reasoning_block =
    #|event: response.reasoning.delta
    #|data: {"type":"response.reasoning.delta","text":"thinking without done"}
    #|
  let (_, _, reasoning_events) = codex_stream_events_from_sse_block(
    reasoning_block, state,
  )
  assert_eq(reasoning_events.length(), 3)
  let completed_block =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_done","status":"completed","model":"o3","output":[],"usage":{"input_tokens":6,"output_tokens":2}}}
    #|
  let (_, _, completed_events) = codex_stream_events_from_sse_block(
    completed_block, state,
  )
  assert_eq(completed_events.length(), 2)
  assert_eq(completed_events[0].event_type, "content_block_stop")
  assert_eq(completed_events[1].event_type, "message_delta")
  let stop_data = @json.parse(completed_events[0].data) catch {
    _ => fail("expected stop json")
  }
  guard stop_data is Object(stop_obj) else { fail("expected object") }
  assert_eq(stop_obj["index"], Json::number(0.0))
}

///|
test "moonstat responses stream state emits function call argument deltas" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let added_block =
    #|event: response.output_item.added
    #|data: {"type":"response.output_item.added","item_id":"fc_1","output_index":0,"item":{"id":"fc_1","type":"function_call","call_id":"call_1","name":"lookup"}}
    #|
  let (_, _, added_events) = codex_stream_events_from_sse_block(
    added_block, state,
  )
  assert_eq(added_events.length(), 2)
  assert_eq(added_events[0].event_type, "message_start")
  assert_eq(added_events[1].event_type, "content_block_start")
  let start_data = @json.parse(added_events[1].data) catch {
    _ => fail("expected start json")
  }
  guard start_data is Object(start_obj) else { fail("expected object") }
  assert_eq(start_obj["index"], Json::number(0.0))
  guard start_obj["content_block"] is Object(block_obj) else {
    fail("expected content block")
  }
  assert_eq(block_obj["type"], Json::string("tool_use"))
  assert_eq(block_obj["id"], Json::string("call_1"))
  assert_eq(block_obj["name"], Json::string("lookup"))

  let delta_block =
    #|event: response.function_call_arguments.delta
    #|data: {"type":"response.function_call_arguments.delta","item_id":"fc_1","delta":"{\"q\":\"moon\""}
    #|
  let (_, _, delta_events) = codex_stream_events_from_sse_block(
    delta_block, state,
  )
  assert_eq(delta_events.length(), 1)
  assert_eq(delta_events[0].event_type, "content_block_delta")
  let delta_data = @json.parse(delta_events[0].data) catch {
    _ => fail("expected delta json")
  }
  guard delta_data is Object(delta_obj) else { fail("expected object") }
  guard delta_obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["type"], Json::string("input_json_delta"))
  assert_eq(delta["partial_json"], Json::string("{\"q\":\"moon\""))

  let done_block =
    #|event: response.function_call_arguments.done
    #|data: {"type":"response.function_call_arguments.done","item_id":"fc_1","arguments":"{\"q\":\"moon\"}"}
    #|
  let (_, _, done_events) = codex_stream_events_from_sse_block(
    done_block, state,
  )
  assert_eq(done_events.length(), 1)
  assert_eq(done_events[0].event_type, "content_block_stop")

  let completed_block =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_tool","status":"completed","model":"gpt-5.4","output":[],"usage":{"input_tokens":6,"output_tokens":2}}}
    #|
  let (_, _, finish_events) = codex_stream_events_from_sse_block(
    completed_block, state,
  )
  assert_eq(finish_events.length(), 1)
  let finish_data = @json.parse(finish_events[0].data) catch {
    _ => fail("expected finish json")
  }
  guard finish_data is Object(finish_obj) else { fail("expected object") }
  guard finish_obj["delta"] is Object(finish_delta) else {
    fail("expected delta")
  }
  assert_eq(finish_delta["stop_reason"], Json::string("tool_use"))
}

///|
test "moonstat responses stream state sanitizes read tool empty pages" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let added_block =
    #|event: response.output_item.added
    #|data: {"type":"response.output_item.added","item":{"id":"fc_read","type":"function_call","call_id":"call_read","name":"Read"}}
    #|
  let (_, _, added_events) = codex_stream_events_from_sse_block(
    added_block, state,
  )
  assert_eq(added_events.length(), 2)

  let delta_block =
    #|event: response.function_call_arguments.delta
    #|data: {"type":"response.function_call_arguments.delta","item_id":"fc_read","delta":"{\"file_path\":\"/tmp/demo.py\",\"limit\":2000,\"offset\":0,\"pages\":\"\"}"}
    #|
  let (_, _, delta_events) = codex_stream_events_from_sse_block(
    delta_block, state,
  )
  assert_eq(delta_events.length(), 0)

  let done_block =
    #|event: response.function_call_arguments.done
    #|data: {"type":"response.function_call_arguments.done","item_id":"fc_read","arguments":"{\"file_path\":\"/tmp/demo.py\",\"limit\":2000,\"offset\":0,\"pages\":\"\"}"}
    #|
  let (_, _, done_events) = codex_stream_events_from_sse_block(
    done_block, state,
  )
  assert_eq(done_events.length(), 2)
  assert_eq(done_events[0].event_type, "content_block_delta")
  assert_eq(done_events[1].event_type, "content_block_stop")
  let data = @json.parse(done_events[0].data) catch {
    _ => fail("expected delta json")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  guard delta["partial_json"] is String(partial) else {
    fail("expected partial json")
  }
  let partial_json = @json.parse(partial) catch {
    _ => fail("expected sanitized partial json")
  }
  guard partial_json is Object(input) else { fail("expected input object") }
  assert_eq(input["file_path"], Json::string("/tmp/demo.py"))
  assert_eq(input["limit"], Json::number(2000.0))
  assert_eq(input["offset"], Json::number(0.0))
  assert_true(input.get("pages") is None)
}

///|
test "moonstat responses stream state read duplicate start preserves buffered args" {
  let state = ResponsesStreamState::new("gpt-5.4")
  let added_block =
    #|event: response.output_item.added
    #|data: {"type":"response.output_item.added","item":{"id":"fc_read","type":"function_call","call_id":"call_read","name":"Read"}}
    #|
  let (_, _, first_added) = codex_stream_events_from_sse_block(
    added_block, state,
  )
  assert_eq(first_added.length(), 2)
  let delta_block =
    #|event: response.function_call_arguments.delta
    #|data: {"type":"response.function_call_arguments.delta","item_id":"fc_read","delta":"{\"file_path\":\"/tmp/demo.py\",\"limit\":2000,\"offset\":0,\"pages\":\"\"}"}
    #|
  let (_, _, delta_events) = codex_stream_events_from_sse_block(
    delta_block, state,
  )
  assert_eq(delta_events.length(), 0)
  let (_, _, duplicate_added) = codex_stream_events_from_sse_block(
    added_block, state,
  )
  assert_eq(duplicate_added.length(), 0)
  let done_block =
    #|event: response.function_call_arguments.done
    #|data: {"type":"response.function_call_arguments.done","item_id":"fc_read"}
    #|
  let (_, _, done_events) = codex_stream_events_from_sse_block(
    done_block, state,
  )
  assert_eq(done_events.length(), 2)
  let data = @json.parse(done_events[0].data) catch {
    _ => fail("expected delta json")
  }
  guard data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  guard delta["partial_json"] is String(partial) else {
    fail("expected partial json")
  }
  let partial_json = @json.parse(partial) catch {
    _ => fail("expected sanitized partial json")
  }
  guard partial_json is Object(input) else { fail("expected input object") }
  assert_true(input.get("pages") is None)
}

///|
test "moonstat responses sse parser ignores truncated trailing block" {
  let sse =
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_ok","status":"completed","model":"gpt-5.4","output":[],"usage":{"input_tokens":3,"output_tokens":1}}}
    #|
    #|event: response.output_text.delta
    #|data: {"type":"response.output_text.delta","delta":"unterminated
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_responses",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed response")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  assert_eq(obj["id"], Json::string("resp_ok"))
}

///|
test "moonstat responses sse parser collects output items" {
  let sse =
    #|event: response.output_item.done
    #|data: {"type":"response.output_item.done","item":{"type":"function_call","call_id":"call_1","name":"lookup","arguments":"{\"q\":\"moon\"}"}}
    #|
    #|event: response.completed
    #|data: {"type":"response.completed","response":{"id":"resp_1","status":"completed","model":"gpt-5.4","output":[],"usage":{"input_tokens":10,"output_tokens":2}}}
    #|
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_responses",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed response")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  guard obj["output"] is Array(output) else { fail("expected output") }
  assert_eq(output.length(), 1)
  guard output[0] is Object(item) else { fail("expected item") }
  assert_eq(item["type"], Json::string("function_call"))
  assert_eq(item["call_id"], Json::string("call_1"))
}

///|
test "moonstat sse body sniffing accepts bom and indented fields" {
  assert_true(body_looks_like_sse("\u{feff}\n  data: {}\n\n"))
  assert_true(body_looks_like_sse(": PROCESSING\n\ndata: {}\n\n"))
  assert_false(body_looks_like_sse("<html><body>blocked</body></html>"))
}

///|
test "moonstat upstream parse diagnostics include headers and body snippet" {
  let headers = { "content-type": "text/html", "content-encoding": "gzip" }
  let suffix = body_diagnostics_suffix(headers, "<html>\r\nblocked\u{0}</html>")
  assert_true(suffix.contains("content-type: text/html"))
  assert_true(suffix.contains("content-encoding: gzip"))
  assert_true(suffix.contains("<html>\\nblocked\u{FFFD}</html>"))
}

///|
test "moonstat upstream parse diagnostics mark missing headers" {
  let result = parse_claude_compatible_non_stream_body_with_diagnostics(
    "anthropic",
    "data: oops",
    {},
  )
  guard result is Err(message) else { fail("expected parse error") }
  assert_true(message.contains("Failed to parse upstream response"))
  assert_true(message.contains("content-type: <none>"))
  assert_true(message.contains("content-encoding: <none>"))
  assert_true(message.contains("body[..120]: 'data: oops'"))
}

///|
test "moonstat upstream parse diagnostics truncate long body snippets" {
  let body = "abcdefghijklmnopqrstuvwxyz"
  assert_eq(body_snippet(body, 5), "abcde\u{2026}")
}

///|
test "moonstat response header stripping removes hop by hop and connection listed headers" {
  let headers = {
    "Content-Type": "application/json",
    "Connection": "Keep-Alive, X-Trace-Id, x-remove-too",
    "Keep-Alive": "timeout=5",
    "Proxy-Connection": "keep-alive",
    "Transfer-Encoding": "chunked",
    "Upgrade": "websocket",
    "X-Trace-Id": "drop",
    "x-remove-too": "drop",
    "X-Keep": "ok",
  }
  let cleaned = moon_strip_hop_by_hop_response_headers(headers)
  assert_eq(cleaned["Content-Type"], "application/json")
  assert_eq(cleaned["X-Keep"], "ok")
  assert_true(cleaned.get("Connection") is None)
  assert_true(cleaned.get("Keep-Alive") is None)
  assert_true(cleaned.get("Proxy-Connection") is None)
  assert_true(cleaned.get("Transfer-Encoding") is None)
  assert_true(cleaned.get("Upgrade") is None)
  assert_true(cleaned.get("X-Trace-Id") is None)
  assert_true(cleaned.get("x-remove-too") is None)
}

///|
test "moonstat rebuilt response header stripping removes stale entity headers" {
  let headers = {
    "Content-Type": "application/json",
    "Content-Encoding": "gzip",
    "Content-Length": "42",
    "Transfer-Encoding": "chunked",
    "X-Keep": "ok",
  }
  let cleaned = moon_strip_entity_headers_for_rebuilt_body(headers)
  assert_eq(cleaned["Content-Type"], "application/json")
  assert_eq(cleaned["X-Keep"], "ok")
  assert_true(cleaned.get("Content-Encoding") is None)
  assert_true(cleaned.get("Content-Length") is None)
  assert_true(cleaned.get("Transfer-Encoding") is None)
}

///|
test "moonstat chat sse parser aggregates text and usage" {
  let sse =
    #|data: {"id":"chatcmpl_1","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"Hel"},"finish_reason":null}]}
    #|
    #|data: {"choices":[{"index":0,"delta":{"content":"lo"},"finish_reason":"stop"}],"usage":{"prompt_tokens":10,"completion_tokens":5,"prompt_tokens_details":{"cached_tokens":2}}}
    #|
    #|data: [DONE]
    #|
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed chat")
  }
  let response = openai_chat_completion_to_anthropic(
    parsed, "claude-sonnet-4-6",
  )
  assert_eq(response.id, "chatcmpl_1")
  assert_eq(response.content.length(), 1)
  assert_eq(response.content[0].text, Some("Hello"))
  assert_eq(response.usage.input_tokens, 8)
  assert_eq(response.usage.output_tokens, 5)
  assert_eq(response.usage.cache_read_input_tokens, Some(2))
}

///|
test "codex response conversion ignores invalid direct cache tokens like moonstat" {
  let body = @json.parse(
    (
      #|{
      #|  "id": "resp_invalid_cache",
      #|  "model": "gpt-5",
      #|  "output": [
      #|    {
      #|      "type": "message",
      #|      "content": [
      #|        { "type": "output_text", "text": "ok" }
      #|      ]
      #|    }
      #|  ],
      #|  "usage": {
      #|    "input_tokens": 10,
      #|    "output_tokens": 2,
      #|    "cache_read_input_tokens": -7,
      #|    "input_tokens_details": { "cached_tokens": 4 }
      #|  }
      #|}
    ),
  )
  let response = convert_codex_to_anthropic(body, "gpt-5")
  assert_eq(response.usage.input_tokens, 6)
  assert_eq(response.usage.output_tokens, 2)
  assert_eq(response.usage.cache_read_input_tokens, Some(4))
}

///|
test "moonstat chat sse parser merges tool call argument fragments" {
  let sse =
    #|data: {"id":"chatcmpl_tool","model":"gpt-4o","choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"lookup","arguments":"{\"q\""}}]},"finish_reason":null}]}
    #|
    #|data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":":\"moon\"}"}}]},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":4,"completion_tokens":2}}
    #|
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed chat")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  guard obj["choices"] is Array(choices) else { fail("expected choices") }
  guard choices[0] is Object(choice) else { fail("expected choice") }
  guard choice["message"] is Object(message) else { fail("expected message") }
  guard message["tool_calls"] is Array(tool_calls) else {
    fail("expected tool calls")
  }
  guard tool_calls[0] is Object(call) else { fail("expected call") }
  guard call["function"] is Object(function) else { fail("expected function") }
  assert_eq(function["name"], Json::string("lookup"))
  assert_eq(function["arguments"], Json::string("{\"q\":\"moon\"}"))
  let response = openai_chat_completion_to_anthropic(
    parsed, "claude-sonnet-4-6",
  )
  assert_eq(response.stop_reason, Some("tool_use"))
  assert_eq(response.content.length(), 1)
  assert_eq(response.content[0].id, Some("call_1"))
}

///|
test "moonstat chat sse parser preserves object form tool arguments" {
  let sse =
    #|data: {"id":"chatcmpl_obj_args","model":"gpt-4o","choices":[{"index":0,"message":{"role":"assistant","tool_calls":[{"id":"call_1","type":"function","function":{"name":"lookup","arguments":{"q":"moon","limit":2}}}]},"finish_reason":"tool_calls"}]}
    #|
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed chat")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  guard obj["choices"] is Array(choices) else { fail("expected choices") }
  guard choices[0] is Object(choice) else { fail("expected choice") }
  guard choice["message"] is Object(message) else { fail("expected message") }
  guard message["tool_calls"] is Array(tool_calls) else {
    fail("expected tool calls")
  }
  guard tool_calls[0] is Object(call) else { fail("expected call") }
  guard call["function"] is Object(function) else { fail("expected function") }
  guard function["arguments"] is String(arguments) else {
    fail("expected serialized arguments")
  }
  let parsed_arguments = @json.parse(arguments) catch {
    _ => fail("expected json arguments")
  }
  guard parsed_arguments is Object(args) else { fail("expected args object") }
  assert_eq(args["q"], Json::string("moon"))
  assert_eq(args["limit"], Json::number(2.0))
}

///|
test "moonstat chat sse parser maps function call snapshots" {
  let sse =
    #|data: {"id":"chatcmpl_function_fn","model":"gpt-4o","choices":[{"index":0,"message":{"role":"assistant","content":null,"function_call":{"name":"lookup","arguments":"{\"q\":\"moon\"}"}},"finish_reason":"function_call"}]}
    #|
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed chat")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  guard obj["choices"] is Array(choices) else { fail("expected choices") }
  guard choices[0] is Object(choice) else { fail("expected choice") }
  guard choice["message"] is Object(message) else { fail("expected message") }
  guard message["tool_calls"] is Array(tool_calls) else {
    fail("expected tool calls")
  }
  guard tool_calls[0] is Object(call) else { fail("expected call") }
  assert_eq(call["id"], Json::string("tool_call_0"))
  guard call["function"] is Object(function) else { fail("expected function") }
  assert_eq(function["name"], Json::string("lookup"))
  assert_eq(function["arguments"], Json::string("{\"q\":\"moon\"}"))
  let response = openai_chat_completion_to_anthropic(
    parsed, "claude-sonnet-4-6",
  )
  assert_eq(response.stop_reason, Some("tool_use"))
  assert_eq(response.content.length(), 1)
  assert_eq(response.content[0].name, Some("lookup"))
}

///|
test "moonstat chat sse parser ignores truncated trailing block after done" {
  let sse =
    #|data: {"id":"chatcmpl_ok","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"done"},"finish_reason":"stop"}]}
    #|
    #|data: {"choices":[{"index":0,"delta":{"content":"unterminated
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed chat")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  assert_eq(obj["id"], Json::string("chatcmpl_ok"))
  guard obj["choices"] is Array(choices) else { fail("expected choices") }
  guard choices[0] is Object(choice) else { fail("expected choice") }
  guard choice["message"] is Object(message) else { fail("expected message") }
  assert_eq(message["content"], Json::string("done"))
}

///|
test "moonstat chat sse parser rejects stream without choices" {
  let sse =
    #|: keepalive
    #|
    #|data: [DONE]
    #|
  assert_true(
    parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Err(_),
  )
}

///|
test "moonstat chat sse parser rejects event error" {
  let sse =
    #|data: {"id":"chatcmpl_ok","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"done"},"finish_reason":"stop"}]}
    #|
    #|event: error
    #|data: {"error":{"message":"quota exceeded"}}
    #|
  assert_true(
    parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Err(_),
  )
}

///|
test "moonstat chat sse parser rejects close-truncated stream" {
  let sse =
    #|data: {"id":"chatcmpl_partial","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"par"},"finish_reason":null}]}
    #|
  assert_true(
    parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Err(_),
  )
}

///|
test "moonstat chat sse parser accepts done without finish reason" {
  let sse =
    #|data: {"id":"chatcmpl_done","model":"gpt-4o","choices":[{"index":0,"delta":{"content":"ok"},"finish_reason":null}]}
    #|
    #|data: [DONE]
    #|
  guard parse_claude_compatible_non_stream_body_with_diagnostics(
      "openai_chat",
      sse,
      {},
    )
    is Ok(parsed) else {
    fail("expected parsed chat")
  }
  guard parsed is Object(obj) else { fail("expected object") }
  guard obj["choices"] is Array(choices) else { fail("expected choices") }
  guard choices[0] is Object(choice) else { fail("expected choice") }
  guard choice["message"] is Object(message) else { fail("expected message") }
  assert_eq(message["content"], Json::string("ok"))
  assert_eq(choice["finish_reason"], Json::null())
}

///|
test "moonstat upstream body filter removes private fields" {
  let body = @json.parse(
    (
      #|{
      #|  "z": 1,
      #|  "_internal": "drop",
      #|  "tools": [
      #|    {
      #|      "name": "lookup",
      #|      "parameters": {
      #|        "type": "object",
      #|        "properties": {
      #|          "_id": {
      #|            "_private_note": "drop",
      #|            "type": "string"
      #|          },
      #|          "b": { "type": "number" },
      #|          "a": { "type": "string" }
      #|        }
      #|      }
      #|    }
      #|  ],
      #|  "a": 2
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body)
  guard prepared is Object(obj) else { fail("expected object") }
  assert_true(obj.get("_internal") is None)
  guard obj["tools"] is Array(tools) else { fail("expected tools") }
  guard tools[0] is Object(tool) else { fail("expected tool") }
  guard tool["parameters"] is Object(parameters) else {
    fail("expected parameters")
  }
  guard parameters["properties"] is Object(properties) else {
    fail("expected properties")
  }
  assert_true(properties.get("_id") is Some(_))
  guard properties["_id"] is Object(id_property) else {
    fail("expected _id property")
  }
  assert_true(id_property.get("_private_note") is None)
  assert_eq(id_property["type"], Json::string("string"))
}

///|
test "moonstat json canonical string sorts nested object keys" {
  let left = @json.parse(
    (
      #|{
      #|  "b": 2,
      #|  "a": {
      #|    "d": true,
      #|    "c": [3, { "z": 1, "y": 2 }]
      #|  }
      #|}
    ),
  )
  let right = @json.parse(
    (
      #|{
      #|  "a": {
      #|    "c": [3, { "y": 2, "z": 1 }],
      #|    "d": true
      #|  },
      #|  "b": 2
      #|}
    ),
  )
  assert_eq(canonical_json_string(left), canonical_json_string(right))
  assert_eq(
    canonical_json_string(right),
    "{\"a\":{\"c\":[3,{\"y\":2,\"z\":1}],\"d\":true},\"b\":2}",
  )
}

///|
test "moonstat upstream body filter supports private whitelist" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-3",
      #|  "_metadata": { "key": "value" },
      #|  "_internal_id": "drop",
      #|  "data": {
      #|    "_metadata": { "nested": true },
      #|    "_internal": "drop"
      #|  }
      #|}
    ),
  )
  let filtered = filter_private_params_for_upstream(body, None, ["_metadata"])
  guard filtered is Object(obj) else { fail("expected object") }
  assert_true(obj.get("_metadata") is Some(_))
  assert_true(obj.get("_internal_id") is None)
  guard obj["data"] is Object(data) else { fail("expected data") }
  assert_true(data.get("_metadata") is Some(_))
  assert_true(data.get("_internal") is None)
}

///|
test "moonstat upstream body preparation canonicalizes object order" {
  let body = @json.parse(
    (
      #|{
      #|  "z": 1,
      #|  "_internal": "drop",
      #|  "tools": [{
      #|    "name": "lookup",
      #|    "parameters": {
      #|      "type": "object",
      #|      "properties": {
      #|        "_id": { "_private_note": "drop", "type": "string" },
      #|        "b": { "type": "number" },
      #|        "a": { "type": "string" }
      #|      }
      #|    }
      #|  }],
      #|  "a": 2
      #|}
    ),
  )
  assert_eq(
    prepare_upstream_request_body(body).stringify(),
    "{\"a\":2,\"tools\":[{\"name\":\"lookup\",\"parameters\":{\"properties\":{\"_id\":{\"type\":\"string\"},\"a\":{\"type\":\"string\"},\"b\":{\"type\":\"number\"}},\"type\":\"object\"}}],\"z\":1}",
  )
}

///|
test "moonstat upstream body filter preserves all schema name maps" {
  let body = @json.parse(
    (
      #|{
      #|  "_top": "drop",
      #|  "schema": {
      #|    "patternProperties": {
      #|      "^_x": { "_private_note": "drop", "type": "string" }
      #|    },
      #|    "definitions": {
      #|      "_legacy": { "_private_note": "drop", "type": "number" }
      #|    },
      #|    "$defs": {
      #|      "_modern": { "_private_note": "drop", "type": "boolean" }
      #|    }
      #|  }
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body)
  guard prepared is Object(obj) else { fail("expected object") }
  assert_true(obj.get("_top") is None)
  guard obj["schema"] is Object(schema) else { fail("expected schema") }
  guard schema["patternProperties"] is Object(pattern_properties) else {
    fail("expected patternProperties")
  }
  guard pattern_properties["^_x"] is Object(pattern) else {
    fail("expected pattern property")
  }
  assert_true(pattern.get("_private_note") is None)
  assert_eq(pattern["type"], Json::string("string"))
  guard schema["definitions"] is Object(definitions) else {
    fail("expected definitions")
  }
  guard definitions["_legacy"] is Object(legacy) else {
    fail("expected definition")
  }
  assert_true(legacy.get("_private_note") is None)
  assert_eq(legacy["type"], Json::string("number"))
  guard schema["$defs"] is Object(defs) else { fail("expected $defs") }
  guard defs["_modern"] is Object(modern) else { fail("expected $defs entry") }
  assert_true(modern.get("_private_note") is None)
  assert_eq(modern["type"], Json::string("boolean"))
}

///|
test "moonstat thinking signature rectifier detects moonstat error phrases" {
  let config = default_rectifier_config()
  assert_true(config.request_media_fallback)
  assert_true(config.request_media_heuristic)
  assert_true(
    should_rectify_thinking_signature(
      Some("messages.1.content.0: Invalid `signature` in `thinking` block"),
      config,
    ),
  )
  assert_true(
    should_rectify_thinking_signature(
      Some("Unable to submit request because Thought signature is not valid"),
      config,
    ),
  )
  assert_true(
    should_rectify_thinking_signature(
      Some(
        "messages.69.content.0.type: Expected `thinking` or `redacted_thinking`, but found `tool_use`.",
      ),
      config,
    ),
  )
  assert_true(
    should_rectify_thinking_signature(
      Some("xxx.signature: Extra inputs are not permitted"),
      config,
    ),
  )
  assert_false(
    should_rectify_thinking_signature(
      Some(
        "Input tag 'adaptive' found using 'type' does not match expected tags",
      ),
      config,
    ),
  )
  assert_false(
    should_rectify_thinking_signature(
      Some("Invalid `signature` in `thinking` block"),
      {
        enabled: false,
        request_thinking_signature: true,
        request_thinking_budget: true,
        request_media_fallback: true,
        request_media_heuristic: true,
      },
    ),
  )
}

///|
test "moonstat thinking signature rectifier removes legacy blocks and signatures" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-test",
      #|  "messages": [{
      #|    "role": "assistant",
      #|    "content": [
      #|      { "type": "thinking", "thinking": "t", "signature": "sig" },
      #|      { "type": "text", "text": "hello", "signature": "sig_text" },
      #|      { "type": "tool_use", "id": "toolu_1", "name": "WebSearch", "input": {}, "signature": "sig_tool" },
      #|      { "type": "redacted_thinking", "data": "r", "signature": "sig_redacted" }
      #|    ]
      #|  }]
      #|}
    ),
  )
  let rectified = rectify_anthropic_request(body)
  assert_true(rectified.applied)
  assert_eq(rectified.removed_thinking_blocks, 1)
  assert_eq(rectified.removed_redacted_thinking_blocks, 1)
  assert_eq(rectified.removed_signature_fields, 2)
  guard rectified.body is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  assert_eq(content.length(), 2)
  guard content[0] is Object(text) else { fail("expected text") }
  guard content[1] is Object(tool) else { fail("expected tool") }
  assert_eq(text["type"], Json::string("text"))
  assert_true(text.get("signature") is None)
  assert_eq(tool["type"], Json::string("tool_use"))
  assert_true(tool.get("signature") is None)
}

///|
test "moonstat thinking signature rectifier removes top level thinking for tool chain" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-test",
      #|  "thinking": { "type": "enabled", "budget_tokens": 1024 },
      #|  "messages": [{
      #|    "role": "assistant",
      #|    "content": [
      #|      { "type": "tool_use", "id": "toolu_1", "name": "WebSearch", "input": {} }
      #|    ]
      #|  }, {
      #|    "role": "user",
      #|    "content": [{ "type": "tool_result", "tool_use_id": "toolu_1", "content": "ok" }]
      #|  }]
      #|}
    ),
  )
  let rectified = rectify_anthropic_request(body)
  assert_true(rectified.applied)
  guard rectified.body is Object(obj) else { fail("expected object") }
  assert_true(obj.get("thinking") is None)
}

///|
test "moonstat thinking budget rectifier detects and normalizes budget errors" {
  let config = default_rectifier_config()
  assert_true(
    should_rectify_thinking_budget(
      Some(
        "thinking.budget_tokens: Input should be greater than or equal to 1024",
      ),
      config,
    ),
  )
  assert_true(
    should_rectify_thinking_budget(
      Some("thinking budget_tokens must be >= 1024"),
      config,
    ),
  )
  assert_false(
    should_rectify_thinking_budget(
      Some("budget_tokens must be less than max_tokens"),
      config,
    ),
  )
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-test",
      #|  "thinking": { "type": "enabled", "budget_tokens": 512 },
      #|  "max_tokens": 1024
      #|}
    ),
  )
  let rectified = rectify_thinking_budget(body)
  assert_true(rectified.applied)
  assert_eq(rectified.before.thinking_budget_tokens, Some(512))
  assert_eq(rectified.after.thinking_budget_tokens, Some(32000))
  assert_eq(rectified.before.max_tokens, Some(1024))
  assert_eq(rectified.after.max_tokens, Some(64000))
  guard rectified.body is Object(obj) else { fail("expected object") }
  guard obj["thinking"] is Object(thinking) else { fail("expected thinking") }
  assert_eq(thinking["type"], Json::string("enabled"))
  assert_eq(thinking["budget_tokens"], Json::number(32000.0))
  assert_eq(obj["max_tokens"], Json::number(64000.0))
}

///|
test "moonstat thinking budget rectifier skips adaptive requests" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-test",
      #|  "thinking": { "type": "adaptive", "budget_tokens": 512 },
      #|  "max_tokens": 1024
      #|}
    ),
  )
  let rectified = rectify_thinking_budget(body)
  assert_false(rectified.applied)
  assert_eq(rectified.before.thinking_type, Some("adaptive"))
  assert_eq(rectified.after.thinking_type, Some("adaptive"))
  guard rectified.body is Object(obj) else { fail("expected object") }
  guard obj["thinking"] is Object(thinking) else { fail("expected thinking") }
  assert_eq(thinking["type"], Json::string("adaptive"))
  assert_eq(thinking["budget_tokens"], Json::number(512.0))
  assert_eq(obj["max_tokens"], Json::number(1024.0))
}

///|
test "moonstat rectifier retry body selects signature before budget" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-test",
      #|  "thinking": { "type": "enabled", "budget_tokens": 512 },
      #|  "max_tokens": 1024,
      #|  "messages": [{
      #|    "role": "assistant",
      #|    "content": [
      #|      { "type": "thinking", "thinking": "t", "signature": "sig" },
      #|      { "type": "tool_use", "id": "toolu_1", "name": "WebSearch", "input": {} }
      #|    ]
      #|  }]
      #|}
    ),
  )
  let retry = moon_rectifier_retry_body(
    "Invalid `signature` in `thinking` block and thinking.budget_tokens: Input should be greater than or equal to 1024",
    body,
  )
  guard retry is Some(retry) else { fail("expected retry") }
  assert_eq(retry.kind, "thinking_signature")
  guard retry.body is Object(obj) else { fail("expected object") }
  assert_true(obj.get("thinking") is None)
}

///|
test "moonstat thinking optimizer uses adaptive mode for newer opus and sonnet" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "anthropic.claude-opus-4-6-20250514-v1:0",
      #|  "max_tokens": 16384,
      #|  "thinking": { "type": "enabled", "budget_tokens": 8000 },
      #|  "messages": [{ "role": "user", "content": "hello" }]
      #|}
    ),
  )
  let optimized = optimize_moon_thinking(body)
  guard optimized is Object(obj) else { fail("expected object") }
  guard obj["thinking"] is Object(thinking) else { fail("expected thinking") }
  assert_eq(thinking["type"], Json::string("adaptive"))
  assert_true(thinking.get("budget_tokens") is None)
  guard obj["output_config"] is Object(output_config) else {
    fail("expected output_config")
  }
  assert_eq(output_config["effort"], Json::string("max"))
  guard obj["anthropic_beta"] is Array(betas) else {
    fail("expected anthropic_beta")
  }
  assert_true(betas.contains(Json::string("context-1m-2025-08-07")))
}

///|
test "moonstat thinking optimizer injects legacy budget and beta" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "anthropic.claude-sonnet-4-5-20250514-v1:0",
      #|  "max_tokens": 8192,
      #|  "thinking": { "type": "disabled" },
      #|  "messages": [{ "role": "user", "content": "hello" }]
      #|}
    ),
  )
  let optimized = optimize_moon_thinking(body)
  guard optimized is Object(obj) else { fail("expected object") }
  guard obj["thinking"] is Object(thinking) else { fail("expected thinking") }
  assert_eq(thinking["type"], Json::string("enabled"))
  assert_eq(thinking["budget_tokens"], Json::number(8191.0))
  guard obj["anthropic_beta"] is Array(betas) else {
    fail("expected anthropic_beta")
  }
  assert_true(betas.contains(Json::string("interleaved-thinking-2025-05-14")))
}

///|
test "moonstat thinking optimizer upgrades small enabled legacy budget" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "anthropic.claude-sonnet-4-5-20250514-v1:0",
      #|  "max_tokens": 4096,
      #|  "thinking": { "type": "enabled", "budget_tokens": 1024 },
      #|  "anthropic_beta": ["interleaved-thinking-2025-05-14"],
      #|  "messages": [{ "role": "user", "content": "hello" }]
      #|}
    ),
  )
  let optimized = optimize_moon_thinking(body)
  guard optimized is Object(obj) else { fail("expected object") }
  guard obj["thinking"] is Object(thinking) else { fail("expected thinking") }
  assert_eq(thinking["budget_tokens"], Json::number(4095.0))
  guard obj["anthropic_beta"] is Array(betas) else {
    fail("expected anthropic_beta")
  }
  assert_eq(betas.length(), 1)
}

///|
test "moonstat thinking optimizer skips haiku models" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "anthropic.claude-haiku-4-5-20250514-v1:0",
      #|  "max_tokens": 8192,
      #|  "messages": [{ "role": "user", "content": "hello" }]
      #|}
    ),
  )
  assert_eq(optimize_moon_thinking(body), body)
}

///|
test "moonstat thinking optimizer can be disabled for bedrock provider" {
  let keys = [
    "MOONSTAT_OPTIMIZER_ENABLED", "MOONSTAT_THINKING_OPTIMIZER", "MOONSTAT_CACHE_INJECTION",
  ]
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
  @os.setenv("MOONSTAT_OPTIMIZER_ENABLED", "true", overwrite=true)
  @os.setenv("MOONSTAT_THINKING_OPTIMIZER", "false", overwrite=true)
  @os.setenv("MOONSTAT_CACHE_INJECTION", "false", overwrite=true)
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="bedrock-thinking-off",
    provider_name="Bedrock Thinking Off",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "env": { "CLAUDE_CODE_USE_BEDROCK": "1" }
          #|}
        ),
      ),
    ),
  )
  let body = @json.parse(
    (
      #|{
      #|  "model": "anthropic.claude-sonnet-4-5-20250514-v1:0",
      #|  "max_tokens": 8192,
      #|  "messages": [{ "role": "user", "content": "hello" }]
      #|}
    ),
  )
  let optimized = prepare_upstream_request_body(body, provider=Some(provider))
  guard optimized is Object(obj) else { fail("expected object") }
  assert_true(obj.get("thinking") is None)
  assert_true(obj.get("anthropic_beta") is None)
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
}

///|
test "moonstat cache injector adds cache breakpoints at provider send sites" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "anthropic.claude-sonnet-4-5-20250514-v1:0",
      #|  "tools": [
      #|    { "name": "read" },
      #|    { "name": "write" }
      #|  ],
      #|  "system": "sys prompt",
      #|  "messages": [
      #|    { "role": "user", "content": [{ "type": "text", "text": "hi" }] },
      #|    { "role": "assistant", "content": [
      #|      { "type": "thinking", "thinking": "skip" },
      #|      { "type": "text", "text": "hello" }
      #|    ] }
      #|  ]
      #|}
    ),
  )
  let optimized = inject_moon_cache_breakpoints(body, "1h")
  guard optimized is Object(obj) else { fail("expected object") }
  guard obj["tools"] is Array(tools) else { fail("expected tools") }
  guard tools[0] is Object(first_tool) else { fail("expected first tool") }
  guard tools[1] is Object(last_tool) else { fail("expected last tool") }
  assert_true(first_tool.get("cache_control") is None)
  assert_eq(
    last_tool["cache_control"],
    Json::object({
      "type": Json::string("ephemeral"),
      "ttl": Json::string("1h"),
    }),
  )
  guard obj["system"] is Array(system) else { fail("expected system array") }
  guard system[0] is Object(system_block) else { fail("expected system block") }
  assert_eq(system_block["text"], Json::string("sys prompt"))
  assert_true(system_block.get("cache_control") is Some(_))
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[1] is Object(assistant) else { fail("expected assistant") }
  guard assistant["content"] is Array(content) else {
    fail("expected assistant content")
  }
  guard content[0] is Object(thinking) else { fail("expected thinking") }
  guard content[1] is Object(text) else { fail("expected text") }
  assert_true(thinking.get("cache_control") is None)
  assert_true(text.get("cache_control") is Some(_))
  assert_eq(count_moon_cache_breakpoints(optimized), 3)
}

///|
test "moonstat cache injector only upgrades ttl after four existing breakpoints" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "test",
      #|  "tools": [
      #|    { "name": "t1", "cache_control": { "type": "ephemeral" } },
      #|    { "name": "t2", "cache_control": { "type": "ephemeral", "ttl": "5m" } }
      #|  ],
      #|  "system": [
      #|    { "type": "text", "text": "sys", "cache_control": { "type": "ephemeral" } }
      #|  ],
      #|  "messages": [
      #|    { "role": "assistant", "content": [
      #|      { "type": "text", "text": "ok", "cache_control": { "type": "ephemeral" } }
      #|    ] }
      #|  ],
      #|  "metadata": {
      #|    "cache_control": { "type": "ephemeral", "ttl": "old" }
      #|  }
      #|}
    ),
  )
  let optimized = inject_moon_cache_breakpoints(body, "5m")
  guard optimized is Object(obj) else { fail("expected object") }
  guard obj["tools"] is Array(tools) else { fail("expected tools") }
  guard tools[0] is Object(first_tool) else { fail("expected first tool") }
  guard first_tool["cache_control"] is Object(first_cache) else {
    fail("expected cache control")
  }
  assert_true(first_cache.get("ttl") is None)
  guard obj["metadata"] is Object(metadata) else { fail("expected metadata") }
  guard metadata["cache_control"] is Object(metadata_cache) else {
    fail("expected metadata cache")
  }
  assert_eq(metadata_cache["ttl"], Json::string("old"))
  assert_eq(count_moon_cache_breakpoints(optimized), 4)
}

///|
test "moonstat optimizer runs only for enabled bedrock providers" {
  let keys = ["MOONSTAT_OPTIMIZER_ENABLED", "MOONSTAT_CACHE_TTL"]
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="bedrock",
    provider_name="Bedrock",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "env": { "CLAUDE_CODE_USE_BEDROCK": "1" }
          #|}
        ),
      ),
    ),
  )
  let body = @json.parse(
    (
      #|{
      #|  "model": "test",
      #|  "tools": [{ "name": "lookup" }],
      #|  "messages": [{ "role": "user", "content": "hi" }]
      #|}
    ),
  )
  let disabled = prepare_upstream_request_body(body, provider=Some(provider))
  assert_eq(count_moon_cache_breakpoints(disabled), 0)
  @os.setenv("MOONSTAT_OPTIMIZER_ENABLED", "true", overwrite=true)
  @os.setenv("MOONSTAT_CACHE_TTL", "1h", overwrite=true)
  let enabled = prepare_upstream_request_body(body, provider=Some(provider))
  assert_eq(count_moon_cache_breakpoints(enabled), 1)
  guard enabled is Object(enabled_obj) else { fail("expected enabled object") }
  guard enabled_obj["thinking"] is Object(thinking) else {
    fail("expected thinking")
  }
  assert_eq(thinking["type"], Json::string("enabled"))
  let non_bedrock = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="plain",
    provider_name="Plain",
  )
  let skipped = prepare_upstream_request_body(body, provider=Some(non_bedrock))
  assert_eq(count_moon_cache_breakpoints(skipped), 0)
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
}

///|
test "moonstat media sanitizer replaces images for known text-only models" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "deepseek/deepseek-v4-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          },
      #|          "cache_control": { "type": "ephemeral" }
      #|        },
      #|        { "type": "text", "text": "caption" }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body)
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(marker) else { fail("expected marker") }
  assert_eq(marker["type"], Json::string("text"))
  assert_eq(marker["text"], Json::string("[Unsupported Image]"))
  assert_true(marker.get("source") is None)
  assert_eq(
    marker["cache_control"],
    Json::object({ "type": Json::string("ephemeral") }),
  )
  assert_eq(
    content[1],
    Json::object({
      "type": Json::string("text"),
      "text": Json::string("caption"),
    }),
  )
}

///|
test "moonstat media sanitizer preserves images for unknown models" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "kimi/kimi-k2.6",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image_url",
      #|          "image_url": { "url": "data:image/png;base64,AAAA" }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body)
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(image) else { fail("expected image") }
  assert_eq(image["type"], Json::string("image_url"))
  assert_true(image.get("image_url") is Some(_))
}

///|
test "moonstat media sanitizer can disable curated text-only heuristic" {
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="heuristic-off",
    provider_name="Heuristic Off",
    settings_config=Some(
      @json.parse(
        (
          #|{
          #|  "requestMediaHeuristic": false
          #|}
        ),
      ),
    ),
  )
  let body = @json.parse(
    (
      #|{
      #|  "model": "deepseek/deepseek-v4-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body, provider=Some(provider))
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(image) else { fail("expected image") }
  assert_eq(image["type"], Json::string("image"))
  assert_true(image.get("source") is Some(_))
}

///|
test "moonstat media sanitizer honors global heuristic toggle" {
  let keys = [
    "MOONSTAT_RECTIFIER_ENABLED", "MOONSTAT_RECTIFIER_MEDIA_HEURISTIC",
  ]
  for key in keys {
    @os.unsetenv(key) catch {
      _ => ()
    }
  }
  @os.setenv("MOONSTAT_RECTIFIER_MEDIA_HEURISTIC", "false", overwrite=true)
  let body = @json.parse(
    (
      #|{
      #|  "model": "deepseek/deepseek-v4-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body)
  @os.unsetenv("MOONSTAT_RECTIFIER_MEDIA_HEURISTIC") catch {
    _ => ()
  }
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(image) else { fail("expected image") }
  assert_eq(image["type"], Json::string("image"))
  assert_true(image.get("source") is Some(_))
}

///|
test "moonstat media sanitizer honors explicit provider text-only capability" {
  let settings = @json.parse(
    (
      #|{
      #|  "requestMediaHeuristic": false,
      #|  "models": [
      #|    { "id": "gpt-4o", "input": ["text"] }
      #|  ]
      #|}
    ),
  )
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="explicit-text",
    provider_name="Explicit Text",
    settings_config=Some(settings),
  )
  let body = @json.parse(
    (
      #|{
      #|  "model": "gpt-4o",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body, provider=Some(provider))
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(marker) else { fail("expected marker") }
  assert_eq(marker["type"], Json::string("text"))
  assert_eq(marker["text"], Json::string("[Unsupported Image]"))
}

///|
test "moonstat media sanitizer honors explicit provider image capability" {
  let settings = @json.parse(
    (
      #|{
      #|  "modelCatalog": {
      #|    "models": [
      #|      {
      #|        "model": "deepseek-v4-pro",
      #|        "modalities": { "input": ["text", "image"] }
      #|      }
      #|    ]
      #|  }
      #|}
    ),
  )
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="explicit-image",
    provider_name="Explicit Image",
    settings_config=Some(settings),
  )
  let body = @json.parse(
    (
      #|{
      #|  "model": "router/deepseek-v4-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let prepared = prepare_upstream_request_body(body, provider=Some(provider))
  guard prepared is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(image) else { fail("expected image") }
  assert_eq(image["type"], Json::string("image"))
  assert_true(image.get("source") is Some(_))
}

///|
test "moonstat media sanitizer replaces nested and responses image blocks" {
  let nested_body = @json.parse(
    (
      #|{
      #|  "model": "therouter/qwen/qwen3-coder-480b",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "tool_result",
      #|          "tool_use_id": "tool_1",
      #|          "content": [
      #|            {
      #|              "type": "image_url",
      #|              "image_url": { "url": "data:image/png;base64,AAAA" }
      #|            }
      #|          ]
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let nested_prepared = prepare_upstream_request_body(nested_body)
  guard nested_prepared is Object(nested_obj) else { fail("expected object") }
  guard nested_obj["messages"] is Array(messages) else {
    fail("expected messages")
  }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(tool_result) else { fail("expected tool result") }
  guard tool_result["content"] is Array(tool_content) else {
    fail("expected tool content")
  }
  guard tool_content[0] is Object(nested_marker) else {
    fail("expected marker")
  }
  assert_eq(nested_marker["type"], Json::string("text"))
  assert_eq(nested_marker["text"], Json::string("[Unsupported Image]"))

  let responses_body = @json.parse(
    (
      #|{
      #|  "model": "deepseek-v4-flash",
      #|  "input": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "input_image",
      #|          "image_url": "data:image/png;base64,AAAA"
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let responses_prepared = prepare_upstream_request_body(responses_body)
  guard responses_prepared is Object(responses_obj) else {
    fail("expected object")
  }
  guard responses_obj["input"] is Array(input) else { fail("expected input") }
  guard input[0] is Object(input_item) else { fail("expected input item") }
  guard input_item["content"] is Array(input_content) else {
    fail("expected input content")
  }
  guard input_content[0] is Object(input_marker) else {
    fail("expected input marker")
  }
  assert_eq(input_marker["type"], Json::string("input_text"))
  assert_eq(input_marker["text"], Json::string("[Unsupported Image]"))
  assert_true(input_marker.get("image_url") is None)
}

///|
test "moonstat media retry detects unsupported image upstream errors" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "xiaomi-mimo-token-plan/mimo-v2.5-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  assert_true(contains_image_blocks(body))
  assert_true(
    moon_media_retry_should_trigger(
      400, "{\"error\":{\"message\":\"This model does not support image input\"}}",
      body,
    ),
  )
  assert_true(
    moon_media_retry_should_trigger(
      415, "{\"error\":{\"message\":\"This model cannot process media inputs\"}}",
      body,
    ),
  )
  assert_true(
    moon_media_retry_should_trigger(
      422, "{\"message\":\"attachments are not supported by this model\"}", body,
    ),
  )
  assert_true(
    moon_media_retry_should_trigger(
      400,
      (
        #|{
        #|  "error": {
        #|    "message": "Failed to deserialize the JSON body: unknown variant image_url, expected text"
        #|  }
        #|}
      ),
      body,
    ),
  )
  assert_false(
    moon_media_retry_should_trigger_with_config(
      400,
      "{\"error\":{\"message\":\"This model does not support image input\"}}",
      body,
      {
        enabled: true,
        request_thinking_signature: true,
        request_thinking_budget: true,
        request_media_fallback: false,
        request_media_heuristic: true,
      },
    ),
  )
  assert_false(
    moon_media_retry_should_trigger_with_config(
      400,
      "{\"error\":{\"message\":\"This model does not support image input\"}}",
      body,
      {
        enabled: false,
        request_thinking_signature: true,
        request_thinking_budget: true,
        request_media_fallback: true,
        request_media_heuristic: true,
      },
    ),
  )
}

///|
test "moonstat media retry ignores non media errors and bodies without images" {
  let image_body = @json.parse(
    (
      #|{
      #|  "model": "any-model",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image_url",
      #|          "image_url": { "url": "data:image/png;base64,AAAA" }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  assert_false(
    moon_media_retry_should_trigger(
      400, "{\"error\":{\"message\":\"Invalid API key\"}}", image_body,
    ),
  )
  assert_false(
    moon_media_retry_should_trigger(
      429, "{\"error\":{\"message\":\"This model does not support image input\"}}",
      image_body,
    ),
  )

  let text_body = @json.parse(
    (
      #|{
      #|  "model": "any-model",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [{ "type": "text", "text": "hello" }]
      #|    }
      #|  ]
      #|}
    ),
  )
  assert_false(contains_image_blocks(text_body))
  assert_false(
    moon_media_retry_should_trigger(
      400, "{\"error\":{\"message\":\"This model does not support image input\"}}",
      text_body,
    ),
  )
}

///|
test "moonstat model image support only accepts canonical field" {
  let canonical_provider = ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="catalog-canonical",
    provider_name="Catalog Canonical",
    settings_config=Some(
      {
        "modelCatalog": {
          "models": [
            {
              "id": Json::string("catalog-model"),
              "supportsImage": Json::boolean(false),
            }.to_json(),
          ],
        }.to_json(),
      }.to_json(),
    ),
  )
  assert_true(
    explicit_model_image_support(Some(canonical_provider), "catalog-model")
    is Some(false),
  )

  let snake_case_provider = ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="catalog-snake",
    provider_name="Catalog Snake",
    settings_config=Some(
      {
        "modelCatalog": {
          "models": [
            {
              "id": Json::string("catalog-model"),
              "supports_image": Json::boolean(false),
            }.to_json(),
          ],
        }.to_json(),
      }.to_json(),
    ),
  )
  assert_true(
    explicit_model_image_support(Some(snake_case_provider), "catalog-model")
    is None,
  )

  let vision_provider = ProviderRouteTarget::new(
    app_type="claude-desktop",
    provider_id="catalog-vision",
    provider_name="Catalog Vision",
    settings_config=Some(
      {
        "modelCatalog": {
          "models": [
            {
              "id": Json::string("catalog-model"),
              "vision": Json::boolean(false),
            }.to_json(),
          ],
        }.to_json(),
      }.to_json(),
    ),
  )
  assert_true(
    explicit_model_image_support(Some(vision_provider), "catalog-model") is None,
  )
}

///|
test "moonstat media retry replacement is unconditional" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "xiaomi-mimo-token-plan/mimo-v2.5-pro",
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image",
      #|          "source": {
      #|            "type": "base64",
      #|            "media_type": "image/png",
      #|            "data": "AAAA"
      #|          }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let result = replace_image_blocks_with_marker(body)
  assert_eq(result.count, 1)
  guard result.body is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(marker) else { fail("expected marker") }
  assert_eq(marker["type"], Json::string("text"))
  assert_eq(marker["text"], Json::string("[Unsupported Image]"))
}

///|
test "moonstat media retry handles streaming upstream bodies" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "max_tokens": 128,
      #|  "messages": [
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        {
      #|          "type": "image_url",
      #|          "image_url": { "url": "data:image/png;base64,AAAA" }
      #|        }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let upstream = prepare_upstream_request_body(
    claude_stream_request_json_for_upstream(body, "kimi/kimi-k2.6"),
  )
  guard upstream is Object(obj) else { fail("expected object") }
  assert_eq(obj["stream"], Json::boolean(true))
  assert_true(contains_image_blocks(upstream))
  assert_true(
    moon_media_retry_should_trigger(
      400, "{\"error\":{\"message\":\"This model does not support image input\"}}",
      upstream,
    ),
  )

  let retry_body = replace_image_blocks_with_marker(upstream)
  guard retry_body.body is Object(retry_obj) else { fail("expected retry") }
  assert_eq(retry_obj["stream"], Json::boolean(true))
  guard retry_obj["messages"] is Array(messages) else {
    fail("expected messages")
  }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(marker) else { fail("expected marker") }
  assert_eq(marker["type"], Json::string("text"))
  assert_eq(marker["text"], Json::string("[Unsupported Image]"))
}

///|
test "openai chat completion converts to anthropic response" {
  let body = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    {
      #|      "message": {
      #|        "role": "assistant",
      #|        "content": "done",
      #|        "tool_calls": [
      #|          {
      #|            "id": "call_1",
      #|            "type": "function",
      #|            "function": {
      #|              "name": "lookup",
      #|              "arguments": "{\"query\":\"moon\"}"
      #|            }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ],
      #|  "usage": {
      #|    "prompt_tokens": 10,
      #|    "completion_tokens": 2,
      #|    "prompt_tokens_details": { "cached_tokens": 3 }
      #|  }
      #|}
    ),
  )
  let response = openai_chat_completion_to_anthropic(body, "claude-sonnet-4-6")
  assert_eq(response.id, "chatcmpl_1")
  assert_eq(response.model, "claude-sonnet-4-6")
  assert_eq(response.stop_reason, Some("tool_use"))
  assert_eq(response.usage.input_tokens, 7)
  assert_eq(response.usage.output_tokens, 2)
  assert_eq(response.usage.cache_read_input_tokens, Some(3))
  assert_eq(response.content.length(), 2)
  assert_eq(response.content[0].type_, "text")
  assert_eq(response.content[0].text, Some("done"))
  assert_eq(response.content[1].type_, "tool_use")
  assert_eq(response.content[1].name, Some("lookup"))
  assert_eq(response.content[1].id, Some("call_1"))
}

///|
test "openai chat stream chunk converts to anthropic events" {
  let chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": { "content": "hi" },
      #|      "finish_reason": null
      #|    }
      #|  ]
      #|}
    ),
  )
  let events = openai_chat_stream_chunk_to_anthropic_events(chunk)
  assert_eq(events.length(), 3)
  assert_eq(events[0].event_type, "message_start")
  let start_data = @json.parse(events[0].data)
  guard start_data is Object(start_obj) else { fail("expected object") }
  guard start_obj["message"] is Object(message) else {
    fail("expected message")
  }
  assert_eq(message["id"], Json::string("chatcmpl_1"))
  assert_eq(message["model"], Json::string("gpt-4o"))
  assert_eq(events[1].event_type, "content_block_start")
  assert_eq(events[2].event_type, "content_block_delta")
  let event_data = @json.parse(events[2].data)
  guard event_data is Object(obj) else { fail("expected object") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["text"], Json::string("hi"))
}

///|
test "openai chat stream finalizes usage after done" {
  let state = OpenAIChatAnthropicStreamState::new()
  let chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": { "content": "hi" },
      #|      "finish_reason": null
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(chunk)
  let done = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": {},
      #|      "finish_reason": "tool_calls"
      #|    }
      #|  ],
      #|  "usage": {
      #|    "prompt_tokens": 9,
      #|    "completion_tokens": 3,
      #|    "prompt_tokens_details": { "cached_tokens": 2 }
      #|  }
      #|}
    ),
  )
  let prepared = state.push_chunk(done)
  assert_eq(prepared.length(), 1)
  assert_eq(prepared[0].event_type, "content_block_stop")
  let done_events = state.finish()
  assert_eq(done_events.length(), 2)
  assert_eq(done_events[0].event_type, "message_delta")
  assert_eq(done_events[1].event_type, "message_stop")
  let done_data = @json.parse(done_events[0].data)
  guard done_data is Object(done_obj) else { fail("expected object") }
  guard done_obj["delta"] is Object(done_delta) else { fail("expected delta") }
  assert_eq(done_delta["stop_reason"], Json::string("tool_use"))
  guard done_obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(7.0))
  assert_eq(usage["output_tokens"], Json::number(3.0))
  assert_eq(usage["cache_read_input_tokens"], Json::number(2.0))
}

///|
test "openai chat stream updates pending message delta from usage only chunk" {
  let state = OpenAIChatAnthropicStreamState::new()
  let tool_chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_split",
      #|  "model": "glm-5.1",
      #|  "choices": [
      #|    {
      #|      "delta": {
      #|        "tool_calls": [
      #|          {
      #|            "index": 0,
      #|            "id": "tool-0924",
      #|            "type": "function",
      #|            "function": { "name": "Bash", "arguments": "{\"command\":\"pwd\"}" }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let finish_chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_split",
      #|  "model": "glm-5.1",
      #|  "choices": [
      #|    { "delta": {}, "finish_reason": "tool_calls" }
      #|  ]
      #|}
    ),
  )
  let usage_only_chunk = @json.parse(
    (
      #|{
      #|  "choices": [],
      #|  "usage": {
      #|    "prompt_tokens": 13312,
      #|    "completion_tokens": 79,
      #|    "prompt_tokens_details": { "cached_tokens": 100 }
      #|  }
      #|}
    ),
  )
  let _ = state.push_chunk(tool_chunk)
  let _ = state.push_chunk(finish_chunk)
  let _ = state.push_chunk(usage_only_chunk)
  let finish_events = state.finish()
  assert_eq(finish_events.length(), 2)
  assert_eq(finish_events[0].event_type, "message_delta")
  assert_eq(finish_events[1].event_type, "message_stop")
  let message_delta = @json.parse(finish_events[0].data)
  guard message_delta is Object(obj) else { fail("expected message delta") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["stop_reason"], Json::string("tool_use"))
  guard obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(13212.0))
  assert_eq(usage["output_tokens"], Json::number(79.0))
  assert_eq(usage["cache_read_input_tokens"], Json::number(100.0))
}

///|
test "openai chat stream emits one message delta for duplicate finish chunks" {
  let state = OpenAIChatAnthropicStreamState::new()
  let first_finish = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_dup",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    { "delta": {}, "finish_reason": "tool_calls" }
      #|  ]
      #|}
    ),
  )
  let second_finish_with_usage = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_dup",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    { "delta": {}, "finish_reason": "tool_calls" }
      #|  ],
      #|  "usage": {
      #|    "prompt_tokens": 10,
      #|    "completion_tokens": 5
      #|  }
      #|}
    ),
  )
  let first_events = state.push_chunk(first_finish)
  let second_events = state.push_chunk(second_finish_with_usage)
  let finish_events = state.finish()
  assert_eq(first_events.length(), 1)
  assert_eq(second_events.length(), 0)
  assert_eq(finish_events.length(), 2)
  assert_eq(finish_events[0].event_type, "message_delta")
  assert_eq(finish_events[1].event_type, "message_stop")
  let message_delta = @json.parse(finish_events[0].data)
  guard message_delta is Object(obj) else { fail("expected message delta") }
  guard obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(10.0))
  assert_eq(usage["output_tokens"], Json::number(5.0))
}

///|
test "openai chat stream message delta includes zero usage without usage chunk" {
  let state = OpenAIChatAnthropicStreamState::new()
  let tool_chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_no_usage",
      #|  "model": "gpt-5.5",
      #|  "choices": [
      #|    {
      #|      "delta": {
      #|        "tool_calls": [
      #|          {
      #|            "index": 0,
      #|            "id": "call_0",
      #|            "type": "function",
      #|            "function": { "name": "get_time", "arguments": "{}" }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let finish_chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_no_usage",
      #|  "model": "gpt-5.5",
      #|  "choices": [
      #|    { "delta": {}, "finish_reason": "tool_calls" }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(tool_chunk)
  let _ = state.push_chunk(finish_chunk)
  let finish_events = state.finish()
  assert_eq(finish_events.length(), 2)
  let message_delta = @json.parse(finish_events[0].data)
  guard message_delta is Object(obj) else { fail("expected message delta") }
  guard obj["delta"] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["stop_reason"], Json::string("tool_use"))
  guard obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(0.0))
  assert_eq(usage["output_tokens"], Json::number(0.0))
}

///|
test "openai chat stream subtracts cache creation from prompt usage like moonstat" {
  let state = OpenAIChatAnthropicStreamState::new()
  let chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_cache_create",
      #|  "model": "glm-5.1",
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": {
      #|        "tool_calls": [
      #|          {
      #|            "index": 0,
      #|            "id": "tool-1",
      #|            "function": { "name": "Bash", "arguments": "{\"command\":\"pwd\"}" }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(chunk)
  let done = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": {},
      #|      "finish_reason": "tool_calls"
      #|    }
      #|  ],
      #|  "usage": {
      #|    "prompt_tokens": 1000,
      #|    "completion_tokens": 50,
      #|    "prompt_tokens_details": { "cached_tokens": 600 },
      #|    "cache_creation_input_tokens": 300
      #|  }
      #|}
    ),
  )
  let _ = state.push_chunk(done)
  let done_events = state.finish()
  let done_data = @json.parse(done_events[0].data)
  guard done_data is Object(done_obj) else { fail("expected message delta") }
  guard done_obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(100.0))
  assert_eq(usage["output_tokens"], Json::number(50.0))
  assert_eq(usage["cache_read_input_tokens"], Json::number(600.0))
  assert_eq(usage["cache_creation_input_tokens"], Json::number(300.0))
}

///|
test "openai chat stream clamps fresh input when cache exceeds prompt" {
  let state = OpenAIChatAnthropicStreamState::new()
  let chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_cache_clamp",
      #|  "model": "glm-5.1",
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": { "content": "hi" }
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(chunk)
  let done = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": {},
      #|      "finish_reason": "stop"
      #|    }
      #|  ],
      #|  "usage": {
      #|    "prompt_tokens": 100,
      #|    "completion_tokens": 50,
      #|    "prompt_tokens_details": { "cached_tokens": 80 },
      #|    "cache_creation_input_tokens": 50
      #|  }
      #|}
    ),
  )
  let _ = state.push_chunk(done)
  let done_events = state.finish()
  let done_data = @json.parse(done_events[0].data)
  guard done_data is Object(done_obj) else { fail("expected message delta") }
  guard done_obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(0.0))
  assert_eq(usage["output_tokens"], Json::number(50.0))
  assert_eq(usage["cache_read_input_tokens"], Json::number(80.0))
  assert_eq(usage["cache_creation_input_tokens"], Json::number(50.0))
}

///|
test "openai chat stream ignores invalid direct cache tokens like moonstat" {
  let state = OpenAIChatAnthropicStreamState::new()
  let chunk = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_invalid_cache",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": { "content": "hi" }
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(chunk)
  let done = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "index": 0,
      #|      "delta": {},
      #|      "finish_reason": "stop"
      #|    }
      #|  ],
      #|  "usage": {
      #|    "prompt_tokens": 10,
      #|    "completion_tokens": 2,
      #|    "cache_read_input_tokens": -7,
      #|    "prompt_tokens_details": { "cached_tokens": 4 }
      #|  }
      #|}
    ),
  )
  let _ = state.push_chunk(done)
  let done_events = state.finish()
  let done_data = @json.parse(done_events[0].data)
  guard done_data is Object(done_obj) else { fail("expected message delta") }
  guard done_obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(6.0))
  assert_eq(usage["output_tokens"], Json::number(2.0))
  assert_eq(usage["cache_read_input_tokens"], Json::number(4.0))
}

///|
test "openai chat stream tool calls keep distinct indexes" {
  let state = OpenAIChatAnthropicStreamState::new()
  let first = @json.parse(
    (
      #|{
      #|  "id": "chatcmpl_2",
      #|  "model": "gpt-4o",
      #|  "choices": [
      #|    {
      #|      "delta": {
      #|        "tool_calls": [
      #|          {
      #|            "index": 0,
      #|            "id": "call_0",
      #|            "function": { "name": "first_tool" }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let second = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "delta": {
      #|        "tool_calls": [
      #|          {
      #|            "index": 1,
      #|            "id": "call_1",
      #|            "function": { "name": "second_tool" }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let args = @json.parse(
    (
      #|{
      #|  "choices": [
      #|    {
      #|      "delta": {
      #|        "tool_calls": [
      #|          { "index": 1, "function": { "arguments": "{\"b\":2}" } },
      #|          { "index": 0, "function": { "arguments": "{\"a\":1}" } }
      #|        ]
      #|      },
      #|      "finish_reason": "tool_calls"
      #|    }
      #|  ]
      #|}
    ),
  )
  let first_events = state.push_chunk(first)
  let second_events = state.push_chunk(second)
  let arg_events = state.push_chunk(args)
  assert_eq(first_events[1].event_type, "content_block_start")
  assert_eq(second_events[0].event_type, "content_block_start")
  let first_start = @json.parse(first_events[1].data)
  let second_start = @json.parse(second_events[0].data)
  guard first_start is Object(first_obj) else { fail("expected object") }
  guard second_start is Object(second_obj) else { fail("expected object") }
  assert_true(first_obj["index"] != second_obj["index"])
  let deltas = arg_events.filter(event => {
    event.event_type == "content_block_delta"
  })
  assert_eq(deltas.length(), 2)
  let delta_a = @json.parse(deltas[1].data)
  let delta_b = @json.parse(deltas[0].data)
  guard delta_a is Object(delta_a_obj) else { fail("expected delta") }
  guard delta_b is Object(delta_b_obj) else { fail("expected delta") }
  guard delta_a_obj["delta"] is Object(delta_a_payload) else {
    fail("expected payload")
  }
  guard delta_b_obj["delta"] is Object(delta_b_payload) else {
    fail("expected payload")
  }
  assert_eq(delta_a_payload["partial_json"], Json::string("{\"a\":1}"))
  assert_eq(delta_b_payload["partial_json"], Json::string("{\"b\":2}"))
}

///|
test "gateway detects active direct codex compatible provider" {
  let gateway = Gateway::new(port=0)
  let providers = [
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-openai",
      provider_name="OpenAI",
      provider_type=Some("codex"),
      base_url=Some("https://api.openai.com/v1"),
      api_key=Some("sk-test"),
    ),
  ]
  guard gateway.proxy.active_provider_target(gateway.usage, providers)
    is Some(active) else {
    fail("expected active provider")
  }
  assert_true(active.provider_id == "codex-openai")
  assert_true(active.can_use_codex_compatible_upstream())
}

///|
test "gemini native stream emits cumulative text deltas" {
  let state = GeminiNativeAnthropicStreamState::new()
  let first = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_1",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    { "content": { "parts": [ { "text": "Hel" } ] } }
      #|  ],
      #|  "usageMetadata": { "promptTokenCount": 10, "totalTokenCount": 13 }
      #|}
    ),
  )
  let second = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_1",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": { "parts": [ { "text": "Hello" } ] }
      #|    }
      #|  ],
      #|  "usageMetadata": { "promptTokenCount": 10, "totalTokenCount": 15 }
      #|}
    ),
  )
  let first_events = state.push_chunk(first)
  let second_events = state.push_chunk(second)
  let finish_events = state.finish()
  assert_eq(first_events[0].event_type, "message_start")
  assert_eq(first_events[1].event_type, "content_block_start")
  let first_delta = @json.parse(first_events[2].data)
  let second_delta = @json.parse(second_events[0].data)
  guard first_delta is Object(first_obj) else { fail("expected first delta") }
  guard second_delta is Object(second_obj) else {
    fail("expected second delta")
  }
  guard first_obj["delta"] is Object(first_payload) else {
    fail("expected first payload")
  }
  guard second_obj["delta"] is Object(second_payload) else {
    fail("expected second payload")
  }
  assert_eq(first_payload["text"], Json::string("Hel"))
  assert_eq(second_payload["text"], Json::string("lo"))
  let message_delta = @json.parse(finish_events[1].data)
  guard message_delta is Object(done_obj) else { fail("expected done") }
  guard done_obj["delta"] is Object(done_delta) else {
    fail("expected done delta")
  }
  assert_eq(done_delta["stop_reason"], Json::string("end_turn"))
  guard done_obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(10.0))
  assert_eq(usage["output_tokens"], Json::number(5.0))
}

///|
test "gemini native stream keeps parallel no id tool calls distinct" {
  let state = GeminiNativeAnthropicStreamState::new()
  let chunk = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_tools",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          { "functionCall": { "name": "lookup", "args": { "city": "Tokyo" } } },
      #|          { "functionCall": { "name": "lookup", "args": { "city": "Osaka" } } }
      #|        ]
      #|      }
      #|    }
      #|  ],
      #|  "usageMetadata": { "promptTokenCount": 5, "totalTokenCount": 8 }
      #|}
    ),
  )
  let _ = state.push_chunk(chunk)
  let events = state.finish()
  let starts = events.filter(event => event.event_type == "content_block_start")
  assert_eq(starts.length(), 2)
  let first = @json.parse(starts[0].data)
  let second = @json.parse(starts[1].data)
  guard first is Object(first_obj) else { fail("expected first") }
  guard second is Object(second_obj) else { fail("expected second") }
  guard first_obj["content_block"] is Object(first_block) else {
    fail("expected first block")
  }
  guard second_obj["content_block"] is Object(second_block) else {
    fail("expected second block")
  }
  assert_eq(first_block["type"], Json::string("tool_use"))
  assert_eq(second_block["type"], Json::string("tool_use"))
  assert_true(first_block["id"] != second_block["id"])
  guard first_block["id"] is String(first_id) else { fail("expected first id") }
  guard second_block["id"] is String(second_id) else {
    fail("expected second id")
  }
  assert_true(first_id.has_prefix("gemini_synth_"))
  assert_true(second_id.has_prefix("gemini_synth_"))
  assert_eq(first_block["name"], Json::string("lookup"))
  assert_eq(second_block["name"], Json::string("lookup"))
  let deltas = events.filter(event => event.event_type == "content_block_delta")
  assert_eq(deltas.length(), 2)
  let delta_a = @json.parse(deltas[0].data)
  let delta_b = @json.parse(deltas[1].data)
  guard delta_a is Object(delta_a_obj) else { fail("expected delta") }
  guard delta_b is Object(delta_b_obj) else { fail("expected delta") }
  guard delta_a_obj["delta"] is Object(delta_a_payload) else {
    fail("expected payload")
  }
  guard delta_b_obj["delta"] is Object(delta_b_payload) else {
    fail("expected payload")
  }
  assert_eq(
    delta_a_payload["partial_json"],
    Json::string("{\"city\":\"Tokyo\"}"),
  )
  assert_eq(
    delta_b_payload["partial_json"],
    Json::string("{\"city\":\"Osaka\"}"),
  )
  let message_delta = @json.parse(events[6].data)
  guard message_delta is Object(done_obj) else { fail("expected done") }
  guard done_obj["delta"] is Object(done_delta) else {
    fail("expected done delta")
  }
  assert_eq(done_delta["stop_reason"], Json::string("tool_use"))
}

///|
test "gemini native stream shadow turn stores accumulated text signature" {
  let state = GeminiNativeAnthropicStreamState::new()
  let first = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_text_shadow",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    { "content": { "parts": [ { "text": "Hel" } ] } }
      #|  ]
      #|}
    ),
  )
  let second = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_text_shadow",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          { "text": "Hello" },
      #|          { "text": "", "thoughtSignature": "sig-text" }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(first)
  let _ = state.push_chunk(second)
  let _ = state.finish()
  guard state.shadow_turn() is Some(turn) else { fail("expected shadow turn") }
  guard turn.assistant_content is Object(content) else {
    fail("expected content")
  }
  guard content["parts"] is Array(parts) else { fail("expected parts") }
  guard parts[0] is Object(text_part) else { fail("expected text part") }
  assert_eq(text_part["text"], Json::string("Hello"))
  assert_eq(text_part["thoughtSignature"], Json::string("sig-text"))
}

///|
test "gemini native stream shadow turn preserves tool signature" {
  let state = GeminiNativeAnthropicStreamState::new()
  let first = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_tool_shadow",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "content": {
      #|        "parts": [
      #|          {
      #|            "functionCall": {
      #|              "id": "call_1",
      #|              "name": "lookup",
      #|              "args": { "city": "Tokyo" }
      #|            },
      #|            "thoughtSignature": "sig-tool"
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let second = @json.parse(
    (
      #|{
      #|  "responseId": "resp_gem_tool_shadow",
      #|  "modelVersion": "gemini-2.5-pro",
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          {
      #|            "functionCall": {
      #|              "id": "call_1",
      #|              "name": "lookup",
      #|              "args": { "city": "Tokyo", "units": "c" }
      #|            }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ]
      #|}
    ),
  )
  let _ = state.push_chunk(first)
  let _ = state.push_chunk(second)
  let _ = state.finish()
  guard state.shadow_turn() is Some(turn) else { fail("expected shadow turn") }
  guard turn.assistant_content is Object(content) else {
    fail("expected content")
  }
  guard content["parts"] is Array(parts) else { fail("expected parts") }
  guard parts[0] is Object(tool_part) else { fail("expected tool part") }
  guard tool_part["functionCall"] is Object(function_call) else {
    fail("expected function call")
  }
  assert_eq(function_call["id"], Json::string("call_1"))
  assert_eq(function_call["name"], Json::string("lookup"))
  guard function_call["args"] is Object(args) else { fail("expected args") }
  assert_eq(args["city"], Json::string("Tokyo"))
  assert_eq(args["units"], Json::string("c"))
  assert_eq(tool_part["thoughtSignature"], Json::string("sig-tool"))
  assert_eq(turn.tool_calls.length(), 1)
  assert_eq(turn.tool_calls[0].thought_signature, Some("sig-tool"))
}

///|
test "gemini native stream prompt feedback becomes refusal" {
  let state = GeminiNativeAnthropicStreamState::new()
  let events = state.push_chunk(
    @json.parse(
      (
        #|{
        #|  "responseId": "resp_block",
        #|  "modelVersion": "gemini-2.5-pro",
        #|  "promptFeedback": { "blockReason": "SAFETY" },
        #|  "usageMetadata": { "promptTokenCount": 5, "totalTokenCount": 5 }
        #|}
      ),
    ),
  )
  assert_eq(events[0].event_type, "message_start")
  let finish_events = state.finish()
  let text_delta = @json.parse(finish_events[1].data)
  guard text_delta is Object(text_obj) else { fail("expected text delta") }
  guard text_obj["delta"] is Object(text_payload) else {
    fail("expected text payload")
  }
  guard text_payload["text"] is String(text) else { fail("expected text") }
  assert_true(text.contains("SAFETY"))
  let message_delta = @json.parse(finish_events[3].data)
  guard message_delta is Object(done_obj) else { fail("expected done") }
  guard done_obj["delta"] is Object(done_delta) else {
    fail("expected done delta")
  }
  assert_eq(done_delta["stop_reason"], Json::string("refusal"))
}

///|
test "gemini native claude compatible provider uses gemini url and headers" {
  assert_eq(
    claude_compatible_provider_url(
      "https://generativelanguage.googleapis.com", "/v1beta/models/gemini-2.5-pro:generateContent",
      "gemini_native", false,
    ),
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent",
  )
  let headers = claude_compatible_provider_headers(
    "gemini-key", "gemini_native",
  )
  assert_eq(headers["x-goog-api-key"], "gemini-key")
  assert_eq(headers["x-goog-api-client"], "GeminiCLI/1.0")
  assert_true(headers.get("Authorization") is None)
  assert_true(headers.get("anthropic-beta") is None)
}

///|
test "claude compatible provider headers honor moonstat inferred provider type auth" {
  let openrouter = claude_compatible_provider_headers(
    "sk-or",
    "anthropic",
    provider_type=Some("openrouter"),
  )
  assert_eq(openrouter["Authorization"], "Bearer sk-or")
  assert_true(openrouter.get("x-api-key") is None)
  let bearer = claude_compatible_provider_headers(
    "bearer-token",
    "anthropic",
    provider_type=Some("claude_auth"),
  )
  assert_eq(bearer["Authorization"], "Bearer bearer-token")
  assert_true(bearer.get("x-api-key") is None)
  let gemini_oauth = claude_compatible_provider_headers(
    "ya29.access-token",
    "gemini_native",
    provider_type=Some("gemini_cli"),
  )
  assert_eq(gemini_oauth["Authorization"], "Bearer ya29.access-token")
  assert_eq(gemini_oauth["x-goog-api-client"], "GeminiCLI/1.0")
  assert_true(gemini_oauth.get("x-goog-api-key") is None)
  let gemini_oauth_json = claude_compatible_provider_headers(
    "{\"access_token\":\"ya29.valid\",\"refresh_token\":\"rt\"}",
    "gemini_native",
    provider_type=Some("gemini_cli"),
  )
  assert_eq(gemini_oauth_json["Authorization"], "Bearer ya29.valid")
  let gemini_oauth_trimmed = claude_compatible_provider_headers(
    "\nya29.raw-token-value\n",
    "gemini_native",
    provider_type=Some("gemini_cli"),
  )
  assert_eq(
    gemini_oauth_trimmed["Authorization"],
    "Bearer ya29.raw-token-value",
  )
}

///|
test "claude compatible provider headers include moonstat copilot fingerprint and overrides" {
  let headers = claude_compatible_provider_headers(
    "copilot-token",
    "openai_responses",
    provider_type=Some("github_copilot"),
    extra_headers={
      "x-initiator": "agent",
      "x-request-id": "deterministic-request",
      "x-agent-task-id": "deterministic-request",
      "x-interaction-id": "deterministic-interaction",
    },
  )
  assert_eq(headers["Authorization"], "Bearer copilot-token")
  assert_eq(headers["editor-version"], COPILOT_EDITOR_VERSION)
  assert_eq(headers["editor-plugin-version"], COPILOT_PLUGIN_VERSION)
  assert_eq(headers["copilot-integration-id"], COPILOT_INTEGRATION_ID)
  assert_eq(headers["user-agent"], COPILOT_USER_AGENT)
  assert_eq(headers["x-github-api-version"], COPILOT_API_VERSION)
  assert_eq(headers["openai-intent"], "conversation-agent")
  assert_eq(headers["x-initiator"], "agent")
  assert_eq(headers["x-interaction-type"], "conversation-agent")
  assert_eq(headers["x-vscode-user-agent-library-version"], "electron-fetch")
  assert_eq(headers["x-request-id"], "deterministic-request")
  assert_eq(headers["x-agent-task-id"], "deterministic-request")
  assert_eq(headers["x-interaction-id"], "deterministic-interaction")
  assert_true(headers.get("x-api-key") is None)
}

///|
test "anthropic claude compatible provider sends moonstat claude code beta headers" {
  let headers = claude_compatible_provider_headers("anthropic-key", "anthropic")
  assert_eq(headers["x-api-key"], "anthropic-key")
  assert_eq(headers["anthropic-version"], "2023-06-01")
  assert_eq(headers["anthropic-beta"], "claude-code-20250219")
  assert_true(headers.get("Authorization") is None)
}

///|
test "anthropic claude compatible provider preserves existing beta headers" {
  let headers = claude_compatible_provider_headers(
    "anthropic-key",
    "anthropic",
    anthropic_beta=Some("interleaved-thinking-2025-05-14"),
  )
  assert_eq(
    headers["anthropic-beta"],
    "claude-code-20250219,interleaved-thinking-2025-05-14",
  )
  let existing = claude_compatible_provider_headers(
    "anthropic-key",
    "anthropic",
    anthropic_beta=Some("claude-code-20250219,interleaved-thinking-2025-05-14"),
  )
  assert_eq(
    existing["anthropic-beta"],
    "claude-code-20250219,interleaved-thinking-2025-05-14",
  )
}

///|
test "gemini native response converts to anthropic message with usage" {
  let body = @json.parse(
    (
      #|{
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          { "text": "done" },
      #|          {
      #|            "functionCall": {
      #|              "id": "gem_call_1",
      #|              "name": "lookup",
      #|              "args": { "q": "moon" }
      #|            }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ],
      #|  "usageMetadata": {
      #|    "promptTokenCount": 10,
      #|    "totalTokenCount": 17,
      #|    "cachedContentTokenCount": 4
      #|  }
      #|}
    ),
  )
  let response = gemini_native_response_to_anthropic(body, "claude-sonnet-4-6")
  assert_eq(response.model, "claude-sonnet-4-6")
  assert_eq(response.stop_reason, Some("tool_use"))
  assert_eq(response.content.length(), 2)
  assert_eq(response.content[0].type_, "text")
  assert_eq(response.content[0].text, Some("done"))
  assert_eq(response.content[1].type_, "tool_use")
  assert_eq(response.content[1].name, Some("lookup"))
  assert_eq(response.content[1].id, Some("gem_call_1"))
  assert_eq(
    response.content[1].input,
    Some(Json::object({ "q": Json::string("moon") })),
  )
  assert_eq(response.usage.input_tokens, 6)
  assert_eq(response.usage.output_tokens, 7)
  assert_eq(response.usage.cache_read_input_tokens, Some(4))
}

///|
test "openclaw workspace is moonstat product-owned state" {
  let workspace = moon_openclaw_workspace_dir()
  let product_home = moonstat_product_home_for_workspace_root(
    moonstat_active_workspace_root(),
  )
  assert_eq(workspace, @pathx.join(product_home, "openclaw/workspace"))
  assert_eq(moon_openclaw_memory_dir(), @pathx.join(workspace, "memory"))
  assert_false(workspace.contains("/.moonsuite/openclaw/workspace"))
}

///|
test "moonstat config helpers require canonical suite app paths" {
  assert_eq(moon_normalize_app_type("claude-desktop"), "claude-desktop")
  assert_eq(moon_normalize_app_type("opencode"), "opencode")
  assert_eq(moon_normalize_app_type("omo-slim"), "omo-slim")
  assert_eq(moon_normalize_app_type("claude_desktop"), "claude")
  assert_eq(moon_normalize_app_type("open-code"), "claude")
  assert_eq(moon_normalize_app_type("open_code"), "claude")
  assert_eq(moon_normalize_app_type("open-claw"), "claude")
  assert_eq(moon_normalize_app_type("open_claw"), "claude")
  assert_eq(moon_normalize_app_type("omo_slim"), "claude")
  assert_eq(moon_normalize_app_type("unknown"), "claude")
  assert_eq(moon_config_dir("codex"), @pathx.join(moon_home_dir(), ".codex"))
  assert_eq(
    moon_config_file_path("openclaw"),
    @pathx.join(moon_config_dir("openclaw"), "openclaw.json"),
  )
  assert_eq(
    moon_config_file_path("hermes"),
    @pathx.join(moon_config_dir("hermes"), "config.yaml"),
  )
}

///|
async test "moonstat config status keeps moonstat object shape" {
  guard moon_config_status_json("hermes") is Object(status) else {
    fail("expected status object")
  }
  assert_eq(status["path"], Json::string(moon_config_dir("hermes")))
  assert_true(
    status["exists"] == Json::boolean(true) ||
    status["exists"] == Json::boolean(false),
  )
}

///|
test "moonstat env helpers preserve conflicts and known keys" {
  assert_eq(moon_env_conflict_keys("codex")[0], "OPENAI_API_KEY")
  assert_eq(moon_env_conflict_keys("hermes")[1], "HERMES_WEB_PORT")
  assert_eq(moon_env_conflict_keys("unknown")[0], "ANTHROPIC_API_KEY")
  let conflict = {
    "varName": Json::string("ANTHROPIC_API_KEY"),
    "varValue": Json::string("sk-test"),
  }.to_json()
  let body = { "conflicts": Json::array([conflict]) }.to_json()
  let conflicts = moon_env_conflicts_from_body(Some(body))
  assert_eq(conflicts.length(), 1)
  assert_eq(conflicts[0], conflict)
  guard moon_env_backup_json(Some(body)) is Object(backup) else {
    fail("expected backup object")
  }
  guard backup["backupPath"] is String(path) else {
    fail("expected backup path")
  }
  assert_true(path.contains(".moonsuite"))
  guard backup["timestamp"] is String(timestamp) else {
    fail("expected timestamp")
  }
  assert_true(!timestamp.is_empty())
  guard backup["conflicts"] is Array(backup_conflicts) else {
    fail("expected conflicts")
  }
  assert_eq(backup_conflicts.length(), 1)
  assert_eq(backup_conflicts[0], conflict)
}

///|
async test "moonstat env helpers scan delete and restore file conflicts" {
  @fsx.with_temporary_directory("moonstat-env-XXXXXX", async fn(tmpdir) {
    let shell_path = @pathx.join(tmpdir, ".zshrc")
    @fsx.write_to_file(
      shell_path, "export OPENAI_API_KEY=\"sk-test\"\nKEEP=1\nOPENAI_BASE_URL='http://local'\n# OPENAI_ORG=skip\n",
    )
    guard moon_env_conflicts_json_with_shell_files("codex", [shell_path])
      is Array(conflicts) else {
      fail("expected conflicts")
    }
    let file_conflicts : Array[Json] = []
    for conflict in conflicts {
      guard conflict is Object(obj) else { continue }
      if obj["sourceType"] == Json::string("file") {
        file_conflicts.push(conflict)
      }
    }
    assert_eq(file_conflicts.length(), 2)
    guard file_conflicts[0] is Object(first) else {
      fail("expected first file conflict")
    }
    assert_eq(first["varName"], Json::string("OPENAI_API_KEY"))
    assert_eq(first["varValue"], Json::string("sk-test"))
    assert_eq(first["sourcePath"], Json::string("\{shell_path}:1"))
    match moon_delete_single_env_conflict(file_conflicts[0]) {
      Ok(_) => ()
      Err(error) => fail(error)
    }
    let deleted = @fsx.read_file(shell_path)
    assert_false(deleted.contains("OPENAI_API_KEY"))
    assert_true(deleted.contains("OPENAI_BASE_URL"))
    let backup_path = @pathx.join(tmpdir, "backup.json")
    let backup = {
      "backupPath": Json::string(backup_path),
      "timestamp": Json::string("test"),
      "conflicts": Json::array([file_conflicts[0]]),
    }.to_json()
    @fsx.write_to_file(backup_path, backup.stringify(indent=2) + "\n")
    match moon_restore_env_backup_json(Some(backup_path)) {
      Ok(_) => ()
      Err(error) => fail(error)
    }
    let restored = @fsx.read_file(shell_path)
    assert_true(restored.contains("export OPENAI_API_KEY=sk-test"))
  })
}

///|
async test "moonstat env conflict helpers reject retired snake case keys" {
  let conflict = {
    "source_type": Json::string("system"),
    "var_name": Json::string("OPENAI_API_KEY"),
    "var_value": Json::string("sk-legacy"),
    "source_path": Json::string("/tmp/.zshrc:1"),
  }.to_json()
  assert_true(moon_delete_single_env_conflict(conflict) is Err(_))
  assert_true(moon_restore_single_env_conflict(conflict) is Err(_))
}

///|
test "moonstat config request helpers ignore retired snake case aliases" {
  assert_eq(
    proxy_string_request(
      "/config/env/restore?backup_path=/tmp/legacy.json",
      None,
      "backupPath",
    ),
    None,
  )
  assert_eq(
    proxy_bool_request(
      "/mcp/config/servers?sync_other_side=true",
      None,
      "syncOtherSide",
    ),
    None,
  )
}

///|
test "moonstat mcp helpers preserve server apps and config shape" {
  let spec = {
    "name": Json::string("Filesystem"),
    "command": Json::string("npx"),
  }.to_json()
  let server = moon_mcp_server_from_spec("filesystem", spec, "codex")
  guard server is Object(obj) else { fail("expected server object") }
  assert_eq(obj["id"], Json::string("filesystem"))
  assert_eq(obj["name"], Json::string("Filesystem"))
  assert_true(moon_mcp_app_enabled(server, "codex"))
  assert_false(moon_mcp_app_enabled(server, "claude"))
  let enabled = moon_mcp_server_with_app(server, "claude", true)
  assert_true(moon_mcp_app_enabled(enabled, "claude"))
  let servers : Map[String, Json] = { "filesystem": enabled }
  guard moon_mcp_servers_object_for_app(servers, Some("codex")) is Object(codex) else {
    fail("expected codex mcp servers")
  }
  assert_true(codex.get("filesystem") is Some(_))
  guard moon_mcp_config_text(servers) is Some(config_text) else {
    fail("expected mcp config")
  }
  assert_true(config_text.contains("\"mcpServers\""))
  assert_true(config_text.contains("\"filesystem\""))
}

///|
test "moonstat mcp request parser accepts canonical server JSON" {
  let body = {
    "id": Json::string("shell"),
    "name": Json::string("Shell"),
    "server": { "command": Json::string("sh") }.to_json(),
  }.to_json()
  guard moon_mcp_server_from_request(
      "/mcp/servers?appType=codex",
      Some(body),
      "codex",
    )
    is Some((id, server)) else {
    fail("expected parsed server")
  }
  assert_eq(id, "shell")
  guard server is Object(obj) else { fail("expected normalized server") }
  assert_eq(obj["name"], Json::string("Shell"))
  assert_true(moon_mcp_app_enabled(server, "codex"))
  assert_true(
    moon_mcp_server_from_request(
      "/mcp/servers?appType=codex",
      Some(
        {
          "server": {
            "id": Json::string("wrapped"),
            "server": { "command": Json::string("sh") }.to_json(),
          }.to_json(),
        }.to_json(),
      ),
      "codex",
    )
    is None,
  )
  let id_only = { "id": Json::string("id-only") }.to_json()
  guard moon_mcp_server_from_request(
      "/mcp/servers?appType=codex",
      Some(id_only),
      "codex",
    )
    is Some((retired_id, retired_server)) else {
    fail("expected parsed id-based server")
  }
  assert_eq(retired_id, "id-only")
  guard retired_server is Object(retired_obj) else {
    fail("expected normalized retired server")
  }
  assert_eq(retired_obj["name"], Json::string("id-only"))
  assert_eq(retired_obj["server"], Json::object({}))
  assert_true(
    moon_mcp_server_from_request("/mcp/servers?server_id=legacy", None, "codex")
    is None,
  )
}

///|
test "moonstat mcp import helpers merge app configs" {
  let servers : Map[String, Json] = {}
  let claude_root = {
    "mcpServers": {
      "filesystem": { "command": Json::string("npx") }.to_json(),
      "bad": { "type": Json::string("stdio") }.to_json(),
    }.to_json(),
  }.to_json()
  assert_eq(moon_import_mcp_from_root_json(servers, "claude", claude_root), 1)
  guard servers.get("filesystem") is Some(filesystem) else {
    fail("expected imported filesystem server")
  }
  assert_true(moon_mcp_app_enabled(filesystem, "claude"))
  assert_false(moon_mcp_app_enabled(filesystem, "codex"))
  assert_true(servers.get("bad") is None)
  assert_eq(moon_import_mcp_from_root_json(servers, "codex", claude_root), 1)
  guard servers.get("filesystem") is Some(updated) else {
    fail("expected updated filesystem server")
  }
  assert_true(moon_mcp_app_enabled(updated, "claude"))
  assert_true(moon_mcp_app_enabled(updated, "codex"))
  assert_eq(moon_import_mcp_from_root_json(servers, "codex", claude_root), 0)
}

///|
test "moonstat mcp import normalizes gemini httpUrl specs" {
  let servers : Map[String, Json] = {}
  let gemini_root = {
    "mcpServers": {
      "web": { "httpUrl": Json::string("https://mcp.example") }.to_json(),
    }.to_json(),
  }.to_json()
  assert_eq(moon_import_mcp_from_root_json(servers, "gemini", gemini_root), 1)
  guard servers.get("web") is Some(Object(web)) else {
    fail("expected imported web server")
  }
  assert_true(moon_mcp_app_enabled(Json::object(web), "gemini"))
  guard web["server"] is Object(spec) else {
    fail("expected normalized server spec")
  }
  assert_eq(spec["url"], Json::string("https://mcp.example"))
  assert_eq(spec["type"], Json::string("http"))
}

///|
test "moonstat mcp import parses codex official toml servers" {
  let servers : Map[String, Json] = {}
  let content =
    #|[mcp_servers.filesystem]
    #|command = "npx"
    #|args = ["-y", "@modelcontextprotocol/server-filesystem", "/tmp/project"]
    #|cwd = "/tmp"
    #|
    #|[mcp_servers.filesystem.env]
    #|TOKEN = "secret"
    #|
    #|[mcp_servers.bad]
    #|type = "stdio"
  assert_eq(moon_import_mcp_from_codex_toml_text(servers, content), 1)
  guard servers.get("filesystem") is Some(Object(server)) else {
    fail("expected imported filesystem server")
  }
  assert_true(moon_mcp_app_enabled(Json::object(server), "codex"))
  guard server["server"] is Object(spec) else { fail("expected server spec") }
  assert_eq(spec["type"], Json::string("stdio"))
  assert_eq(spec["command"], Json::string("npx"))
  guard spec["args"] is Array(args) else { fail("expected args") }
  assert_eq(args.length(), 3)
  assert_eq(args[1], Json::string("@modelcontextprotocol/server-filesystem"))
  guard spec["env"] is Object(env) else { fail("expected env") }
  assert_eq(env["TOKEN"], Json::string("secret"))
  assert_true(servers.get("bad") is None)
  assert_eq(moon_import_mcp_from_codex_toml_text(servers, content), 0)
}

///|
test "moonstat mcp import parses codex legacy toml servers" {
  let servers : Map[String, Json] = {}
  let content =
    #|[mcp.servers.web]
    #|type = "http"
    #|url = "https://mcp.example"
    #|
    #|[mcp.servers.web.http_headers]
    #|Authorization = "Bearer token"
    #|
    #|[mcp.servers.sse]
    #|type = "sse"
    #|url = "https://sse.example"
    #|description = "legacy server"
  assert_eq(moon_import_mcp_from_codex_toml_text(servers, content), 2)
  guard servers.get("web") is Some(Object(web)) else {
    fail("expected imported web server")
  }
  guard web["server"] is Object(web_spec) else {
    fail("expected web server spec")
  }
  assert_eq(web_spec["type"], Json::string("http"))
  guard web_spec["headers"] is Object(headers) else { fail("expected headers") }
  assert_eq(headers["Authorization"], Json::string("Bearer token"))
  guard servers.get("sse") is Some(Object(sse)) else {
    fail("expected imported sse server")
  }
  guard sse["server"] is Object(sse_spec) else {
    fail("expected sse server spec")
  }
  assert_eq(sse_spec["type"], Json::string("sse"))
  assert_eq(sse_spec["description"], Json::string("legacy server"))
}

///|
test "moonstat prompt helpers keep app-scoped prompt records" {
  guard moon_prompt_from_request(
      "/prompts?appType=codex",
      Some(
        {
          "id": Json::string("review"),
          "name": Json::string("Review"),
          "content": Json::string("Check this"),
          "description": Json::string("Code review"),
        }.to_json(),
      ),
    )
    is Some((app, id, prompt)) else {
    fail("expected prompt")
  }
  assert_eq(app, "codex")
  assert_eq(id, "review")
  guard prompt is Object(obj) else { fail("expected prompt object") }
  assert_eq(obj["name"], Json::string("Review"))
  assert_eq(obj["content"], Json::string("Check this"))
  assert_eq(obj["enabled"], Json::boolean(true))
  assert_true(
    moon_prompt_from_request(
      "/prompts?appType=codex",
      Some(
        {
          "prompt": {
            "id": Json::string("wrapped"),
            "name": Json::string("Wrapped"),
          }.to_json(),
        }.to_json(),
      ),
    )
    is None,
  )
  assert_true(
    moon_prompt_from_request(
      "/prompts?appType=codex&prompt_id=legacy&name=Legacy",
      None,
    )
    is None,
  )
  let prompts : Map[String, Json] = {}
  prompts[moon_prompt_store_key(app, id)] = prompt
  prompts[moon_prompt_store_key("claude", "review")] = moon_normalize_prompt(
    "review",
    { "content": Json::string("Claude") }.to_json(),
  )
  guard moon_prompts_object_for_app(prompts, "codex") is Object(codex) else {
    fail("expected codex prompts")
  }
  assert_true(codex.get("review") is Some(_))
  guard moon_prompts_object_for_app(prompts, "claude") is Object(claude) else {
    fail("expected claude prompts")
  }
  assert_true(claude.get("review") is Some(_))
}

///|
async test "moonstat prompt file helpers import and read prompt files" {
  assert_eq(
    moon_prompt_file_path("codex"),
    Ok(@pathx.join(moon_config_dir("codex"), "AGENTS.md")),
  )
  assert_eq(
    moon_prompt_file_path("gemini"),
    Ok(@pathx.join(moon_config_dir("gemini"), "GEMINI.md")),
  )
  assert_true(moon_prompt_file_path("claude-desktop") is Err(_))
  @fsx.with_temporary_directory("moonstat-prompt-XXXXXX", async fn(tmpdir) {
    let prompt_path = @pathx.join(tmpdir, "AGENTS.md")
    let content = "# Codex prompt\n\nUse MoonBit."
    @fsx.write_to_file(prompt_path, content)
    let body = { "filePath": Json::string(prompt_path) }.to_json()
    guard moon_prompt_file_path_from_request(
        "/prompts/import-file?appType=codex",
        Some(body),
        "codex",
      )
      is Ok(resolved_path) else {
      fail("expected request path")
    }
    assert_eq(resolved_path, prompt_path)
    let prompts : Map[String, Json] = {}
    guard moon_import_prompt_from_file_json(prompts, "codex", prompt_path)
      is Ok(String(id)) else {
      fail("expected imported id")
    }
    assert_true(id.has_prefix("imported-"))
    guard prompts.get(moon_prompt_store_key("codex", id))
      is Some(Object(prompt)) else {
      fail("expected stored prompt")
    }
    assert_eq(prompt["content"], Json::string(content))
    assert_eq(
      prompt["description"],
      Json::string("从现有配置文件导入"),
    )
    assert_eq(prompt["enabled"], Json::boolean(false))
    guard moon_current_prompt_file_content_json(prompt_path) is Ok(current) else {
      fail("expected current prompt content")
    }
    assert_eq(current, Json::string(content))
    guard moon_current_prompt_file_content_json(
        @pathx.join(tmpdir, "missing.md"),
      )
      is Ok(missing) else {
      fail("expected missing prompt file as null")
    }
    assert_eq(missing, Json::null())
    assert_true(
      moon_import_prompt_from_file_json(
        prompts,
        "codex",
        @pathx.join(tmpdir, "missing.md"),
      )
      is Err(_),
    )
  })
}

///|
async test "moonstat prompt enable writes prompt file and disables app siblings" {
  @fsx.with_temporary_directory("moonstat-prompt-enable-XXXXXX", async fn(
    tmpdir,
  ) {
    let prompt_path = @pathx.join(tmpdir, "AGENTS.md")
    let prompts : Map[String, Json] = {}
    prompts[moon_prompt_store_key("codex", "first")] = moon_normalize_prompt(
      "first",
      {
        "content": Json::string("first content"),
        "enabled": Json::boolean(true),
      }.to_json(),
    )
    prompts[moon_prompt_store_key("codex", "second")] = moon_normalize_prompt(
      "second",
      {
        "content": Json::string("second content"),
        "enabled": Json::boolean(false),
      }.to_json(),
    )
    prompts[moon_prompt_store_key("claude", "first")] = moon_normalize_prompt(
      "first",
      {
        "content": Json::string("claude content"),
        "enabled": Json::boolean(true),
      }.to_json(),
    )
    match moon_enable_prompt_json(prompts, "codex", "second", prompt_path) {
      Ok(_) => ()
      Err(error) => fail(error)
    }
    assert_eq(@fsx.read_file(prompt_path), "second content")
    guard prompts.get(moon_prompt_store_key("codex", "first"))
      is Some(Object(codex_first)) else {
      fail("expected codex first prompt")
    }
    assert_eq(codex_first["enabled"], Json::boolean(false))
    guard prompts.get(moon_prompt_store_key("codex", "second"))
      is Some(Object(codex_second)) else {
      fail("expected codex second prompt")
    }
    assert_eq(codex_second["enabled"], Json::boolean(true))
    guard prompts.get(moon_prompt_store_key("claude", "first"))
      is Some(Object(claude_first)) else {
      fail("expected claude first prompt")
    }
    assert_eq(claude_first["enabled"], Json::boolean(true))
    assert_true(
      moon_enable_prompt_json(prompts, "codex", "missing", prompt_path)
      is Err(_),
    )
  })
}

///|
test "gemini native response synthesizes moonstat marked missing tool id" {
  let body = @json.parse(
    (
      #|{
      #|  "candidates": [
      #|    {
      #|      "finishReason": "STOP",
      #|      "content": {
      #|        "parts": [
      #|          {
      #|            "functionCall": {
      #|              "name": "lookup",
      #|              "args": { "q": "moon" }
      #|            }
      #|          }
      #|        ]
      #|      }
      #|    }
      #|  ],
      #|  "usageMetadata": {
      #|    "promptTokenCount": 10,
      #|    "totalTokenCount": 17
      #|  }
      #|}
    ),
  )
  let response = gemini_native_response_to_anthropic(body, "claude-sonnet-4-6")
  assert_eq(response.stop_reason, Some("tool_use"))
  assert_eq(response.content.length(), 1)
  assert_eq(response.content[0].type_, "tool_use")
  guard response.content[0].id is Some(id) else {
    fail("expected synthesized id")
  }
  assert_true(id.has_prefix("gemini_synth_"))
}

///|
test "gemini native prompt block converts to anthropic refusal" {
  let response = gemini_native_response_to_anthropic(
    @json.parse(
      (
        #|{
        #|  "promptFeedback": { "blockReason": "SAFETY" },
        #|  "usageMetadata": { "promptTokenCount": 5, "totalTokenCount": 5 }
        #|}
      ),
    ),
    "claude-sonnet-4-6",
  )
  assert_eq(response.stop_reason, Some("refusal"))
  assert_eq(response.content.length(), 1)
  assert_eq(response.content[0].type_, "text")
}

///|
test "moonstat claude desktop default routes match upstream command shape" {
  guard claude_desktop_default_routes_json() is Array(routes) else {
    fail("expected default routes")
  }
  assert_eq(routes.length(), 3)
  guard routes[0] is Object(sonnet) else { fail("expected route object") }
  assert_eq(sonnet["routeId"], Json::string("claude-sonnet-4-6"))
  assert_eq(sonnet["envKey"], Json::string("ANTHROPIC_DEFAULT_SONNET_MODEL"))
  assert_eq(sonnet["supports1m"], Json::boolean(true))
}

///|
test "moonstat model mapping env ignores moonstat prefixed aliases" {
  let old_moon_default = @os.getenv("MOONSTAT_ANTHROPIC_MODEL") catch {
    _ => None
  }
  let old_moon_haiku = @os.getenv("MOONSTAT_ANTHROPIC_DEFAULT_HAIKU_MODEL") catch {
    _ => None
  }
  let old_moon_sonnet = @os.getenv("MOONSTAT_ANTHROPIC_DEFAULT_SONNET_MODEL") catch {
    _ => None
  }
  let old_moon_opus = @os.getenv("MOONSTAT_ANTHROPIC_DEFAULT_OPUS_MODEL") catch {
    _ => None
  }
  let old_default = @os.getenv("ANTHROPIC_MODEL") catch { _ => None }
  let old_haiku = @os.getenv("ANTHROPIC_DEFAULT_HAIKU_MODEL") catch {
    _ => None
  }
  let old_sonnet = @os.getenv("ANTHROPIC_DEFAULT_SONNET_MODEL") catch {
    _ => None
  }
  let old_opus = @os.getenv("ANTHROPIC_DEFAULT_OPUS_MODEL") catch { _ => None }
  @os.unsetenv("ANTHROPIC_MODEL") catch {
    _ => ()
  }
  @os.unsetenv("ANTHROPIC_DEFAULT_HAIKU_MODEL") catch {
    _ => ()
  }
  @os.unsetenv("ANTHROPIC_DEFAULT_SONNET_MODEL") catch {
    _ => ()
  }
  @os.unsetenv("ANTHROPIC_DEFAULT_OPUS_MODEL") catch {
    _ => ()
  }
  @os.setenv("MOONSTAT_ANTHROPIC_MODEL", "moon-default", overwrite=true)
  @os.setenv(
    "MOONSTAT_ANTHROPIC_DEFAULT_SONNET_MODEL",
    "moon-sonnet",
    overwrite=true,
  )
  assert_true(moon_model_mapping_from_env() is None)
  @os.setenv("ANTHROPIC_MODEL", "anthropic-default", overwrite=true)
  guard moon_model_mapping_from_env() is Some(mapping) else {
    fail("expected standard anthropic model mapping")
  }
  assert_eq(mapping.default_model, Some("anthropic-default"))
  moon_wbtest_restore_env("MOONSTAT_ANTHROPIC_MODEL", old_moon_default)
  moon_wbtest_restore_env(
    "MOONSTAT_ANTHROPIC_DEFAULT_HAIKU_MODEL", old_moon_haiku,
  )
  moon_wbtest_restore_env(
    "MOONSTAT_ANTHROPIC_DEFAULT_SONNET_MODEL", old_moon_sonnet,
  )
  moon_wbtest_restore_env(
    "MOONSTAT_ANTHROPIC_DEFAULT_OPUS_MODEL", old_moon_opus,
  )
  moon_wbtest_restore_env("ANTHROPIC_MODEL", old_default)
  moon_wbtest_restore_env("ANTHROPIC_DEFAULT_HAIKU_MODEL", old_haiku)
  moon_wbtest_restore_env("ANTHROPIC_DEFAULT_SONNET_MODEL", old_sonnet)
  moon_wbtest_restore_env("ANTHROPIC_DEFAULT_OPUS_MODEL", old_opus)
}

///|
test "moonstat suggested claude desktop routes derive from provider env" {
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="desktop-routes",
    provider_name="Desktop Routes",
    settings_config=Some(
      {
        "env": {
          "ANTHROPIC_DEFAULT_SONNET_MODEL": Json::string("MiniMax-M2[1M]"),
          "ANTHROPIC_DEFAULT_OPUS_MODEL": Json::string("MiniMax-M2"),
          "ANTHROPIC_DEFAULT_HAIKU_MODEL": Json::string("GLM-4-Flash"),
          "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME": Json::string("GLM Flash"),
        }.to_json(),
      }.to_json(),
    ),
  )
  guard suggested_claude_desktop_routes(provider) is Some(routes) else {
    fail("expected routes")
  }
  assert_eq(routes.length(), 2)
  guard routes.get("claude-sonnet-4-6") is Some(sonnet) else {
    fail("expected merged sonnet route")
  }
  assert_eq(sonnet.model, "MiniMax-M2")
  assert_eq(sonnet.label_override, Some("MiniMax-M2"))
  assert_eq(sonnet.supports_1m, Some(true))
  guard routes.get("claude-haiku-4-5") is Some(haiku) else {
    fail("expected haiku route")
  }
  assert_eq(haiku.model, "GLM-4-Flash")
  assert_eq(haiku.label_override, Some("GLM Flash"))
  assert_eq(haiku.supports_1m, Some(true))
}

///|
test "moonstat suggested claude desktop routes keep copilot 1m default false" {
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="copilot-routes",
    provider_name="Copilot Routes",
    provider_type=Some("github_copilot"),
    settings_config=Some(
      {
        "env": { "ANTHROPIC_DEFAULT_SONNET_MODEL": Json::string("gpt-5-codex") }.to_json(),
      }.to_json(),
    ),
  )
  guard suggested_claude_desktop_routes(provider) is Some(routes) else {
    fail("expected routes")
  }
  guard routes.get("claude-sonnet-4-6") is Some(sonnet) else {
    fail("expected sonnet route")
  }
  assert_eq(sonnet.model, "gpt-5-codex")
  assert_eq(sonnet.label_override, Some("gpt-5-codex"))
  assert_eq(sonnet.supports_1m, Some(false))
}

///|
test "moonstat suggested claude desktop routes fallback to anthropic model" {
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="fallback-routes",
    provider_name="Fallback Routes",
    settings_config=Some(
      { "env": { "ANTHROPIC_MODEL": Json::string("kimi-k2") }.to_json() }.to_json(),
    ),
  )
  guard suggested_claude_desktop_routes(provider) is Some(routes) else {
    fail("expected routes")
  }
  assert_eq(routes.length(), 1)
  guard routes.get("claude-sonnet-4-6") is Some(sonnet) else {
    fail("expected fallback sonnet route")
  }
  assert_eq(sonnet.model, "kimi-k2")
  assert_eq(sonnet.label_override, Some("kimi-k2"))
}

///|
test "moonstat imports missing claude providers into claude desktop namespace" {
  let gateway = Gateway::new(port=17071)
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="claude-extra",
      provider_name="Claude Extra",
      provider_type=Some("anthropic"),
      base_url=Some("https://example.test"),
      settings_config=Some(
        {
          "env": {
            "ANTHROPIC_BASE_URL": Json::string("https://example.test"),
            "ANTHROPIC_AUTH_TOKEN": Json::string("sk-ant"),
            "ANTHROPIC_MODEL": Json::string("claude-sonnet-4-6"),
          }.to_json(),
        }.to_json(),
      ),
    ),
  )
  assert_eq(gateway.proxy.import_claude_desktop_providers(), 1)
  guard gateway.proxy.provider_router.provider_by_id(
      "claude-desktop", "claude-extra",
    )
    is Some(imported) else {
    fail("expected imported provider")
  }
  assert_eq(imported.claude_desktop_mode, Some("direct"))
  assert_eq(gateway.proxy.import_claude_desktop_providers(), 0)
}

///|
fn moon_direct_compatible_claude_desktop_provider(
  provider_type? : String? = Some("anthropic"),
  api_format? : String? = Some("anthropic"),
  is_full_url? : Bool = false,
  token? : String? = Some("sk-ant"),
) -> ProviderRouteTarget {
  let routes : Map[String, ClaudeDesktopModelRoute] = {
    "claude-sonnet-4-6": ClaudeDesktopModelRoute::new(model="claude-sonnet-4-6"),
  }
  let env : Map[String, Json] = {
    "ANTHROPIC_BASE_URL": Json::string("https://direct.example/v1"),
  }
  match token {
    Some(token) => env["ANTHROPIC_AUTH_TOKEN"] = Json::string(token)
    None => ()
  }
  ProviderRouteTarget::new(
    app_type="claude",
    provider_id="direct",
    provider_name="Direct",
    provider_type~,
    api_format~,
    is_full_url~,
    settings_config=Some({ "env": Json::object(env) }.to_json()),
    claude_desktop_model_routes=routes,
  )
}

///|
test "moonstat claude desktop direct compatibility filters unsafe providers" {
  assert_true(
    moon_direct_compatible_claude_desktop_provider().is_compatible_claude_desktop_direct_provider(),
  )
  assert_false(
    moon_direct_compatible_claude_desktop_provider(
      provider_type=Some("official"),
    ).is_compatible_claude_desktop_direct_provider(),
  )
  assert_false(
    moon_direct_compatible_claude_desktop_provider(
      api_format=Some("openai_chat"),
    ).is_compatible_claude_desktop_direct_provider(),
  )
  assert_false(
    moon_direct_compatible_claude_desktop_provider(
      provider_type=Some("github_copilot"),
    ).is_compatible_claude_desktop_direct_provider(),
  )
  assert_false(
    moon_direct_compatible_claude_desktop_provider(is_full_url=true).is_compatible_claude_desktop_direct_provider(),
  )
  assert_false(
    moon_direct_compatible_claude_desktop_provider(token=None).is_compatible_claude_desktop_direct_provider(),
  )
}

///|
test "moonstat import skips claude providers without direct or proxy compatibility" {
  let gateway = Gateway::new(port=17073)
  let empty_env : Map[String, Json] = {}
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="incomplete",
      provider_name="Incomplete",
      settings_config=Some({ "env": empty_env.to_json() }.to_json()),
    ),
  )
  assert_eq(gateway.proxy.import_claude_desktop_providers(), 0)
  assert_true(
    gateway.proxy.provider_router.provider_by_id("claude-desktop", "incomplete")
    is None,
  )
}

///|
test "moonstat import derives claude desktop routes from claude provider env" {
  let gateway = Gateway::new(port=17072)
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="env-routes",
      provider_name="Env Routes",
      settings_config=Some(
        {
          "env": {
            "ANTHROPIC_DEFAULT_SONNET_MODEL": Json::string("kimi-k2[1M]"),
          }.to_json(),
        }.to_json(),
      ),
    ),
  )
  assert_eq(gateway.proxy.import_claude_desktop_providers(), 1)
  guard gateway.proxy.provider_router.provider_by_id(
      "claude-desktop", "env-routes",
    )
    is Some(imported) else {
    fail("expected imported provider")
  }
  assert_eq(imported.claude_desktop_mode, Some("proxy"))
  guard imported.claude_desktop_model_routes.get("claude-sonnet-4-6")
    is Some(route) else {
    fail("expected synthesized route")
  }
  assert_eq(route.model, "kimi-k2")
  assert_eq(route.supports_1m, Some(true))
}

///|
test "moonstat skill repo request accepts query and json body shapes" {
  let empty_body : Map[String, Json] = {}
  guard moon_skill_repo_request_json(
      "/skills/repos?owner=vectie&name=moonstat-skills&branch=main&enabled=true",
      Some(empty_body.to_json()),
    )
    is Some(Object(query_repo)) else {
    fail("expected query repo")
  }
  assert_eq(query_repo["owner"], Json::string("vectie"))
  assert_eq(query_repo["name"], Json::string("moonstat-skills"))
  assert_eq(query_repo["branch"], Json::string("main"))
  assert_eq(query_repo["enabled"], Json::boolean(true))

  guard moon_skill_repo_request_json(
      "/skills/repos",
      Some(
        {
          "owner": Json::string("anthropics"),
          "name": Json::string("skills"),
          "enabled": Json::boolean(false),
        }.to_json(),
      ),
    )
    is Some(Object(body_repo)) else {
    fail("expected body repo")
  }
  assert_eq(body_repo["owner"], Json::string("anthropics"))
  assert_eq(body_repo["name"], Json::string("skills"))
  assert_eq(body_repo["branch"], Json::string("main"))
  assert_eq(body_repo["enabled"], Json::boolean(false))
  assert_true(
    moon_skill_repo_request_json(
      "/skills/repos?owner=vectie&repo=legacy-skills",
      None,
    )
    is None,
  )
}
