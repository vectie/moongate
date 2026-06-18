///|
test "suite manifest publishes moonstat service contract" {
  let manifest = moonstat_suite_manifest_json(
    host="0.0.0.0",
    port=15721,
    model="gpt-5",
  )
  guard manifest is Object(obj) else { fail("expected manifest object") }
  assert_eq(obj["contract"], Json::string("moon.suite.service.v1"))
  assert_eq(obj["service"], Json::string("moonstat"))
  assert_eq(obj["default_host"], Json::string("127.0.0.1"))
  assert_eq(obj["default_port"], Json::number(15721.0))
  assert_eq(obj["base_url"], Json::string("http://127.0.0.1:15721"))
  assert_eq(
    obj["status_file"],
    Json::string(default_moonstat_suite_status_path()),
  )
  assert_eq(obj["openai_base_url"], Json::string("http://127.0.0.1:15721/v1"))
  assert_eq(
    obj["usage_logs_url"],
    Json::string("http://127.0.0.1:15721/usage/logs"),
  )
  assert_eq(obj["metrics_url"], Json::string("http://127.0.0.1:15721/metrics"))
  assert_eq(
    obj["usage_summary_url"],
    Json::string("http://127.0.0.1:15721/usage/summary"),
  )
  assert_eq(
    obj["usage_trends_url"],
    Json::string("http://127.0.0.1:15721/usage/trends"),
  )
  assert_eq(
    obj["usage_provider_limits_url"],
    Json::string("http://127.0.0.1:15721/usage/provider-limits"),
  )
  assert_eq(
    obj["provider_presets_url"],
    Json::string("http://127.0.0.1:15721/providers/presets"),
  )
  assert_eq(
    obj["usage_sync_session_url"],
    Json::string("http://127.0.0.1:15721/usage/sync-session"),
  )
  assert_eq(
    obj["stream_check_provider_url"],
    Json::string("http://127.0.0.1:15721/proxy/stream-check/provider"),
  )
  assert_eq(
    obj["stream_check_all_providers_url"],
    Json::string("http://127.0.0.1:15721/proxy/stream-check/all"),
  )
  assert_eq(
    obj["stream_check_config_url"],
    Json::string("http://127.0.0.1:15721/proxy/stream-check/config"),
  )
  assert_eq(
    obj["config_status_url"],
    Json::string("http://127.0.0.1:15721/config/status"),
  )
  assert_eq(obj["usage_store_dir"], Json::string(default_moonstat_stats_dir()))
  assert_eq(
    obj["usage_request_logs_file"],
    Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_REQUEST_LOGS_FILE),
    ),
  )
  assert_eq(
    obj["usage_session_sync_file"],
    Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_SESSION_SYNC_FILE),
    ),
  )
  assert_eq(
    obj["usage_model_pricing_file"],
    Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_MODEL_PRICING_FILE),
    ),
  )
  assert_eq(
    obj["usage_opencode_export_file"],
    Json::string(default_opencode_export_path()),
  )
  assert_eq(
    obj["usage_opencode_db_file"],
    Json::string(default_opencode_db_path()),
  )
  guard obj["routes"] is Array(routes) else { fail("expected routes") }
  guard obj["capabilities"] is Array(capabilities) else {
    fail("expected capabilities")
  }
  assert_true(capabilities.contains(Json::string("openai-compatible-proxy")))
  assert_true(capabilities.contains(Json::string("moonstat-usage-statistics")))
  assert_true(capabilities.contains(Json::string("moonstat-stream-check")))
  assert_true(capabilities.contains(Json::string("moonstat-skills-management")))
  assert_true(capabilities.contains(Json::string("provider-presets")))
  assert_true(capabilities.contains(Json::string("suite-discovery")))
  assert_true(routes.contains(Json::string("GET /participant/register")))
  assert_true(routes.contains(Json::string("GET /stats")))
  assert_true(routes.contains(Json::string("GET /metrics")))
  assert_true(routes.contains(Json::string("GET|POST /usage/logs")))
  assert_true(routes.contains(Json::string("GET|POST /usage/summary")))
  assert_true(routes.contains(Json::string("GET|POST /usage/summary/by-app")))
  assert_true(routes.contains(Json::string("GET|POST /usage/trends")))
  assert_true(routes.contains(Json::string("GET|POST /usage/provider-limits")))
  assert_true(routes.contains(Json::string("GET|POST /usage/provider-stats")))
  assert_true(routes.contains(Json::string("GET|POST /usage/model-stats")))
  assert_true(routes.contains(Json::string("GET|POST /usage/data-sources")))
  assert_true(routes.contains(Json::string("POST /usage/sync-session")))
  assert_true(routes.contains(Json::string("GET /usage/model-pricing")))
  assert_true(routes.contains(Json::string("POST /usage/model-pricing")))
  assert_true(routes.contains(Json::string("DELETE /usage/model-pricing")))
  assert_true(routes.contains(Json::string("GET /usage/request-detail/*path")))
  assert_true(routes.contains(Json::string("GET|POST /usage/provider-usage")))
  assert_true(routes.contains(Json::string("GET|POST /usage/balance")))
  assert_true(
    routes.contains(Json::string("GET|POST /usage/subscription-quota")),
  )
  assert_true(
    routes.contains(Json::string("GET|POST /usage/codex-oauth-quota")),
  )
  assert_true(
    routes.contains(Json::string("GET|POST /usage/codex-oauth-models")),
  )
  assert_true(
    routes.contains(Json::string("GET|POST /usage/coding-plan-quota")),
  )
  assert_true(routes.contains(Json::string("POST /usage/test-script")))
  assert_true(
    routes.contains(Json::string("GET|POST /proxy/stream-check/provider")),
  )
  assert_true(routes.contains(Json::string("GET|POST /proxy/stream-check/all")))
  assert_true(routes.contains(Json::string("GET /proxy/stream-check/config")))
  assert_true(routes.contains(Json::string("POST /proxy/stream-check/config")))
  assert_true(routes.contains(Json::string("GET /providers/presets")))
  assert_true(routes.contains(Json::string("GET|POST /auth/status")))
  assert_true(routes.contains(Json::string("GET|POST /auth/accounts")))
  assert_true(routes.contains(Json::string("GET|POST /auth/login")))
  assert_true(routes.contains(Json::string("GET|POST /auth/poll")))
  assert_true(routes.contains(Json::string("DELETE /auth/account")))
  assert_false(routes.contains(Json::string("DELETE|POST /auth/account")))
  assert_true(routes.contains(Json::string("GET|POST /auth/default-account")))
  assert_true(routes.contains(Json::string("GET|POST /auth/logout")))
  assert_true(routes.contains(Json::string("GET /copilot/status")))
  assert_true(routes.contains(Json::string("GET /copilot/accounts")))
  assert_true(routes.contains(Json::string("GET /copilot/authenticated")))
  assert_true(routes.contains(Json::string("GET|POST /copilot/device-flow")))
  assert_true(routes.contains(Json::string("GET|POST /copilot/poll-auth")))
  assert_true(routes.contains(Json::string("GET|POST /copilot/poll-account")))
  assert_true(routes.contains(Json::string("GET|POST /copilot/logout")))
  assert_true(routes.contains(Json::string("DELETE /copilot/account")))
  assert_false(routes.contains(Json::string("DELETE|POST /copilot/account")))
  assert_true(
    routes.contains(Json::string("GET|POST /copilot/default-account")),
  )
  assert_true(routes.contains(Json::string("GET /copilot/token")))
  assert_true(routes.contains(Json::string("GET /copilot/models")))
  assert_true(routes.contains(Json::string("GET /copilot/usage")))
  assert_true(routes.contains(Json::string("GET|POST /tools/versions")))
  assert_true(routes.contains(Json::string("POST /tools/lifecycle-action")))
  assert_true(routes.contains(Json::string("GET|POST /tools/probe")))
  assert_true(
    routes.contains(Json::string("GET|POST /runtime/tray-menu/update")),
  )
  assert_true(routes.contains(Json::string("GET|POST /runtime/open-external")))
  assert_true(routes.contains(Json::string("GET /runtime/lightweight-mode")))
  assert_true(routes.contains(Json::string("GET|POST /config/files/export")))
  assert_true(routes.contains(Json::string("GET|POST /config/files/import")))
  assert_true(routes.contains(Json::string("POST /backups/db")))
  assert_true(routes.contains(Json::string("GET /backups/db")))
  assert_true(routes.contains(Json::string("POST /backups/db/restore")))
  assert_true(routes.contains(Json::string("POST /backups/db/rename")))
  assert_true(routes.contains(Json::string("DELETE /backups/db/delete")))
  assert_false(routes.contains(Json::string("DELETE|POST /backups/db/delete")))
  assert_true(routes.contains(Json::string("GET|POST /deeplinks/parse")))
  assert_true(routes.contains(Json::string("GET|POST /deeplinks/merge")))
  assert_true(routes.contains(Json::string("POST /deeplinks/import")))
  assert_true(routes.contains(Json::string("POST /sync/webdav/test")))
  assert_true(routes.contains(Json::string("POST /sync/webdav/upload")))
  assert_true(routes.contains(Json::string("POST /sync/webdav/download")))
  assert_true(routes.contains(Json::string("POST /sync/webdav/settings")))
  assert_true(routes.contains(Json::string("GET /sync/webdav/remote-info")))
  assert_true(routes.contains(Json::string("POST /sync/s3/test")))
  assert_true(routes.contains(Json::string("POST /sync/s3/upload")))
  assert_true(routes.contains(Json::string("POST /sync/s3/download")))
  assert_true(routes.contains(Json::string("POST /sync/s3/settings")))
  assert_true(routes.contains(Json::string("GET /sync/s3/remote-info")))
  assert_true(routes.contains(Json::string("GET|POST /sessions")))
  assert_true(routes.contains(Json::string("GET|POST /sessions/messages")))
  assert_true(routes.contains(Json::string("POST /sessions/terminal")))
  assert_true(routes.contains(Json::string("POST /sessions/delete")))
  assert_true(routes.contains(Json::string("POST /sessions/delete-many")))
  assert_true(routes.contains(Json::string("GET|POST /providers/omo/file")))
  assert_true(routes.contains(Json::string("GET|POST /providers/omo/current")))
  assert_true(routes.contains(Json::string("POST /providers/omo/disable")))
  assert_true(
    routes.contains(Json::string("GET|POST /providers/omo-slim/file")),
  )
  assert_true(
    routes.contains(Json::string("GET|POST /providers/omo-slim/current")),
  )
  assert_true(routes.contains(Json::string("POST /providers/omo-slim/disable")))
  assert_true(routes.contains(Json::string("GET /skills/installed")))
  assert_true(routes.contains(Json::string("GET /skills/backups")))
  assert_true(routes.contains(Json::string("POST /skills/install-unified")))
  assert_true(routes.contains(Json::string("POST /skills/toggle-app")))
  assert_true(routes.contains(Json::string("GET|POST /skills/search")))
  assert_true(routes.contains(Json::string("GET /skills/repos")))
  assert_true(routes.contains(Json::string("POST /skills/install-zip")))
  assert_true(routes.contains(Json::string("GET /proxy/status")))
  assert_true(routes.contains(Json::string("POST /proxy/start")))
  assert_true(routes.contains(Json::string("POST /proxy/stop")))
  assert_true(routes.contains(Json::string("POST /proxy/stop-with-restore")))
  assert_false(routes.contains(Json::string("GET /proxy/config")))
  assert_true(routes.contains(Json::string("GET|POST /proxy/global-config")))
  assert_true(routes.contains(Json::string("GET|POST /proxy/global-url")))
  assert_true(routes.contains(Json::string("GET|POST /proxy/test-url")))
  assert_true(routes.contains(Json::string("GET /proxy/upstream-status")))
  assert_true(routes.contains(Json::string("GET /proxy/local-proxies")))
  assert_true(routes.contains(Json::string("POST /proxy/switch-provider")))
  assert_true(
    routes.contains(Json::string("POST /proxy/sync-current-providers-live")),
  )
  assert_true(
    routes.contains(Json::string("POST /proxy/import-default-config")),
  )
  assert_true(routes.contains(Json::string("GET /providers")))
  assert_true(routes.contains(Json::string("GET|POST /providers/current")))
  assert_true(routes.contains(Json::string("POST /providers")))
  assert_true(routes.contains(Json::string("POST /providers/update")))
  assert_true(routes.contains(Json::string("DELETE /providers")))
  assert_true(routes.contains(Json::string("DELETE /providers/live")))
  assert_false(routes.contains(Json::string("POST /providers/delete")))
  assert_false(routes.contains(Json::string("POST /providers/live/remove")))
  assert_true(routes.contains(Json::string("POST /providers/switch")))
  assert_true(
    routes.contains(Json::string("GET|POST /providers/live-settings")),
  )
  assert_true(routes.contains(Json::string("POST /providers/terminal")))
  assert_true(routes.contains(Json::string("GET /providers/live-ids")))
  assert_true(
    routes.contains(Json::string("GET|POST /providers/live-provider")),
  )
  assert_true(routes.contains(Json::string("POST /providers/import-live")))
  assert_true(routes.contains(Json::string("GET /providers/universal")))
  assert_true(routes.contains(Json::string("GET /providers/universal/item")))
  assert_true(routes.contains(Json::string("POST /providers/universal")))
  assert_true(routes.contains(Json::string("DELETE /providers/universal")))
  assert_false(
    routes.contains(Json::string("POST /providers/universal/delete")),
  )
  assert_true(routes.contains(Json::string("POST /providers/universal/sync")))
  assert_true(
    routes.contains(Json::string("GET|POST /providers/test-endpoints")),
  )
  assert_true(routes.contains(Json::string("POST /providers/sort-order")))
  assert_true(
    routes.contains(Json::string("GET|POST /providers/endpoints/list")),
  )
  assert_true(routes.contains(Json::string("POST /providers/endpoints")))
  assert_true(routes.contains(Json::string("DELETE /providers/endpoints")))
  assert_false(
    routes.contains(Json::string("POST /providers/endpoints/remove")),
  )
  assert_true(routes.contains(Json::string("POST /providers/endpoints/touch")))
  assert_true(routes.contains(Json::string("GET /config/claude/status")))
  assert_true(routes.contains(Json::string("GET|POST /config/status")))
  assert_true(
    routes.contains(Json::string("GET /providers/claude-desktop/status")),
  )
  let control_routes = [
    "GET /proxy/status", "POST /proxy/start", "POST /proxy/stop", "POST /proxy/stop-with-restore",
    "GET|POST /proxy/global-config", "GET|POST /proxy/app-config", "GET|POST /proxy/default-cost-multiplier",
    "GET|POST /proxy/pricing-model-source", "GET /proxy/provider-health", "GET|POST /proxy/circuit-breaker-config",
    "GET /proxy/circuit-breaker-stats", "GET|POST|DELETE /proxy/failover-queue",
    "GET|POST /proxy/auto-failover-enabled", "GET|POST /proxy/takeover-status", "GET /proxy/running",
    "GET|POST /proxy/global-url", "GET|POST /proxy/test-url", "GET /proxy/upstream-status",
    "GET /proxy/local-proxies", "POST /proxy/switch-provider", "POST /proxy/sync-current-providers-live",
    "POST /proxy/import-default-config", "GET /providers", "GET|POST /providers/current",
    "POST /providers", "POST /providers/update", "POST /providers/switch", "GET|POST /providers/live-settings",
    "GET /providers/live-ids", "GET|POST /providers/live-provider", "POST /providers/import-live",
    "POST /proxy/reset-circuit-breaker", "GET /mcp/servers", "POST /mcp/servers",
    "DELETE /mcp/servers", "GET /prompts", "POST /prompts", "DELETE /prompts", "GET /openclaw/config-health",
    "GET /openclaw/default-model", "POST /openclaw/default-model", "GET /hermes/model-config",
    "GET /hermes/memory", "POST /hermes/memory", "GET /providers/universal", "GET /providers/universal/item",
    "POST /providers/universal", "DELETE /providers/universal", "GET|POST /providers/test-endpoints",
    "GET|POST /config/models",
  ]
  for route in control_routes {
    assert_true(routes.contains(Json::string(route)))
  }
  assert_true(routes.contains(Json::string("POST /v1/messages")))
  assert_true(routes.contains(Json::string("POST /login")))
  assert_true(routes.contains(Json::string("ANY /v1beta/*path")))
  assert_true(routes.contains(Json::string("ANY /gemini/v1beta/*path")))
  assert_true(routes.contains(Json::string("ANY /gemini/v1/*path")))
  guard obj["apps"] is Array(apps) else { fail("expected apps") }
  assert_eq(apps.length(), 4)
  guard obj["suite_integrations"] is Object(integrations) else {
    fail("expected suite integrations")
  }
  guard integrations["moonclaw"] is Object(moonclaw) else {
    fail("expected moonclaw integration")
  }
  assert_eq(
    moonclaw["openai_base_url"],
    Json::string("http://127.0.0.1:15721/v1"),
  )
  assert_eq(
    moonclaw["anthropic_base_url"],
    Json::string("http://127.0.0.1:15721"),
  )
  guard moonclaw["env"] is Object(moonclaw_env) else {
    fail("expected moonclaw env")
  }
  assert_eq(
    moonclaw_env["OPENAI_BASE_URL"],
    Json::string("http://127.0.0.1:15721/v1"),
  )
  assert_eq(moonclaw_env["OPENAI_API_KEY"], Json::string("moonstat-local"))
  guard moonclaw["moonclaw_model_config"] is Object(model_config) else {
    fail("expected moonclaw model config")
  }
  assert_eq(model_config["name"], Json::string("moonstat/gpt-5"))
  assert_eq(model_config["model_name"], Json::string("gpt-5"))
  assert_eq(model_config["model_type"], Json::string("saas/openai"))
  assert_eq(model_config["api_key"], Json::string("moonstat-local"))
  assert_eq(model_config["base_url"], Json::string("http://127.0.0.1:15721/v1"))
  assert_eq(model_config["safe_zone_tokens"], Json::number(200000.0))
  guard moonclaw["moonclaw_models_json"] is Array(models_json) else {
    fail("expected moonclaw models json")
  }
  assert_eq(models_json.length(), 1)
  assert_eq(models_json[0], moonclaw["moonclaw_model_config"])
  guard moonclaw["moonclaw_models_path_candidates"] is Array(paths) else {
    fail("expected moonclaw models path candidates")
  }
  assert_true(paths.contains(Json::string(".moonclaw/models/models.json")))
  assert_true(paths.contains(Json::string("~/.moonclaw/models/models.json")))
  assert_eq(moonclaw["moonclaw_provider_name"], Json::string("moonstat"))
  assert_eq(moonclaw["moonclaw_provider_model_id"], Json::string("gpt-5"))
  guard moonclaw["moonclaw_provider_config_paths"] is Array(config_paths) else {
    fail("expected moonclaw provider config paths")
  }
  assert_true(config_paths.contains(Json::string(".moonclaw/config.json")))
  assert_true(config_paths.contains(Json::string("~/.moonclaw/config.json")))
  guard moonclaw["moonclaw_providers_file_json"] is Object(providers_file) else {
    fail("expected moonclaw providers file json")
  }
  guard providers_file["providers"] is Object(moonclaw_providers) else {
    fail("expected moonclaw providers map")
  }
  guard moonclaw_providers["moonstat"] is Object(moonstat_provider) else {
    fail("expected moonstat provider")
  }
  assert_eq(
    moonstat_provider["baseUrl"],
    Json::string("http://127.0.0.1:15721/v1"),
  )
  assert_eq(moonstat_provider["api"], Json::string("openai"))
  assert_eq(moonstat_provider["apiKey"], Json::string("moonstat-local"))
  guard moonstat_provider["models"] is Array(provider_models) else {
    fail("expected moonstat provider models")
  }
  guard provider_models[0] is Object(provider_model) else {
    fail("expected moonstat provider model")
  }
  assert_eq(provider_model["id"], Json::string("gpt-5"))
  assert_eq(provider_model["name"], Json::string("moonstat/gpt-5"))
  assert_eq(
    moonclaw["moonclaw_providers_file_command"],
    Json::string("moonstat suite moonclaw-providers"),
  )
  assert_eq(
    moonclaw["moonclaw_providers_file_write_command"],
    Json::string(
      "moonstat suite write-moonclaw-providers --path .moonclaw/providers.json",
    ),
  )
  assert_eq(
    moonclaw["provider_presets_url"],
    Json::string("http://127.0.0.1:15721/providers/presets"),
  )
  guard integrations["moonbook"] is Object(moonbook) else {
    fail("expected moonbook integration")
  }
  assert_eq(
    moonbook["usage_request_logs_file"],
    Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_REQUEST_LOGS_FILE),
    ),
  )
  assert_eq(moonbook["cli"], Json::string("moonstat"))
  assert_eq(
    moonbook["moondesk_adapter_package"],
    Json::string("vectie/moondesk/adapters/moonbook"),
  )
  assert_eq(
    moonbook["moontown_adapter_package"],
    Json::string("vectie/moontown/adapters/moonbook"),
  )
  guard integrations["moontown"] is Object(moontown) else {
    fail("expected moontown integration")
  }
  assert_eq(
    moontown["stream_check_all_providers_url"],
    Json::string("http://127.0.0.1:15721/proxy/stream-check/all"),
  )
  assert_eq(
    moontown["usage_provider_limits_url"],
    Json::string("http://127.0.0.1:15721/usage/provider-limits"),
  )
  assert_eq(
    moontown["moonclaw_provider_manifest_path"],
    Json::string(".moonclaw/providers.json"),
  )
  assert_eq(
    moontown["moonclaw_provider_manifest_command"],
    Json::string("moonstat"),
  )
  assert_eq(
    moontown["moonclaw_provider_manifest_full_command"],
    Json::string(
      "moonstat suite write-moonclaw-providers --path .moonclaw/providers.json",
    ),
  )
  guard moontown["moonclaw_provider_manifest_args"] is Array(moonclaw_args) else {
    fail("expected moonclaw provider manifest args")
  }
  assert_true(
    moonclaw_args ==
    [
      Json::string("suite"),
      Json::string("write-moonclaw-providers"),
      Json::string("--path"),
      Json::string(".moonclaw/providers.json"),
    ],
  )
  assert_eq(
    moontown["moonclaw_provider_manifest_target"],
    Json::string("moonbook"),
  )
  assert_eq(
    moontown["moonbook_provider_manifest_path"],
    Json::string(".moonclaw/providers.json"),
  )
  assert_eq(
    moontown["moonbook_provider_manifest_command"],
    Json::string("moonstat"),
  )
  assert_eq(
    moontown["moonbook_provider_manifest_full_command"],
    Json::string(
      "moonstat suite write-moonclaw-providers --path .moonclaw/providers.json",
    ),
  )
  guard moontown["moonbook_provider_manifest_args"] is Array(moonbook_args) else {
    fail("expected moonbook provider manifest args")
  }
  assert_true(
    moonbook_args ==
    [
      Json::string("suite"),
      Json::string("write-moonclaw-providers"),
      Json::string("--path"),
      Json::string(".moonclaw/providers.json"),
    ],
  )
  guard moontown["adapter_packages"] is Array(moontown_adapters) else {
    fail("expected moontown adapters")
  }
  assert_true(
    moontown_adapters.contains(
      Json::string("vectie/moontown/adapters/moonclaw"),
    ),
  )
  assert_true(
    moontown_adapters.contains(
      Json::string("vectie/moontown/adapters/moonbook"),
    ),
  )
  guard integrations["moondesk"] is Object(moondesk) else {
    fail("expected moondesk integration")
  }
  assert_eq(
    moondesk["claude_desktop_base_url"],
    Json::string("http://127.0.0.1:15721/claude-desktop/v1"),
  )
  assert_eq(
    moondesk["provider_presets_url"],
    Json::string("http://127.0.0.1:15721/providers/presets"),
  )
  assert_eq(
    moondesk["stream_check_config_url"],
    Json::string("http://127.0.0.1:15721/proxy/stream-check/config"),
  )
  assert_eq(
    moondesk["config_status_url"],
    Json::string("http://127.0.0.1:15721/config/status"),
  )
  guard moondesk["adapter_packages"] is Array(moondesk_adapters) else {
    fail("expected moondesk adapters")
  }
  assert_true(
    moondesk_adapters.contains(
      Json::string("vectie/moondesk/adapters/moonclaw"),
    ),
  )
  assert_true(
    moondesk_adapters.contains(
      Json::string("vectie/moondesk/adapters/moonbook"),
    ),
  )
  assert_true(
    moondesk_adapters.contains(
      Json::string("vectie/moondesk/adapters/moontown"),
    ),
  )
  guard obj["commands"] is Object(commands) else { fail("expected commands") }
  assert_eq(commands["start"], Json::string("moonstat start --port 15721"))
  assert_eq(commands["skills_list"], Json::string("moonstat skills installed"))
  assert_eq(commands["skills_repos"], Json::string("moonstat skills repos"))
  assert_eq(
    commands["update_tray_menu"],
    Json::string("moonstat runtime tray-menu update"),
  )
  assert_eq(
    commands["suite_write_status"],
    Json::string("moonstat suite write-status"),
  )
  assert_eq(
    commands["moonclaw_providers"],
    Json::string("moonstat suite moonclaw-providers"),
  )
  assert_eq(
    commands["moonclaw_providers_write"],
    Json::string(
      "moonstat suite write-moonclaw-providers --path .moonclaw/providers.json",
    ),
  )
  assert_eq(
    commands["stream_check_all"],
    Json::string("moonstat stream-check all --app-type <app_type>"),
  )
  assert_eq(
    commands["provider_presets"],
    Json::string("moonstat provider presets list --app-type <app_type>"),
  )
  assert_eq(obj["cli"], obj["commands"])
}

///|
async test "moonclaw providers file writer materializes suite provider config" {
  @fsx.with_temporary_directory("moonstat-moonclaw-providers-XXXXXX", tmpdir => {
    let path = @pathx.join(tmpdir, ".moonclaw/providers.json")
    let written = write_moonstat_moonclaw_providers_file(
      path~,
      host="0.0.0.0",
      port=18081,
      model="gpt-5",
    )
    assert_eq(written, path)
    let json = @json.parse(@fsx.read_file(path))
    assert_eq(
      json,
      moonstat_moonclaw_providers_file_json(
        host="0.0.0.0",
        port=18081,
        model="gpt-5",
      ),
    )
    guard json is Object(obj) else { fail("expected providers object") }
    guard obj["providers"] is Object(providers) else {
      fail("expected providers map")
    }
    guard providers["moonstat"] is Object(provider) else {
      fail("expected moonstat provider")
    }
    assert_eq(provider["baseUrl"], Json::string("http://127.0.0.1:18081/v1"))
    assert_eq(provider["api"], Json::string("openai"))
    assert_eq(provider["apiKey"], Json::string("moonstat-local"))
  })
}

///|
fn suite_routes_include_path(routes : Array[Json], path : String) -> Bool {
  let needle = " \{path}"
  routes.any(route => {
    match route {
      String(value) => value.contains(needle)
      _ => false
    }
  })
}

///|
fn moon_tauri_command_surface() -> Array[String] {
  [
    "get_claude_desktop_status", "get_claude_desktop_default_routes", "import_claude_desktop_providers_from_claude",
    "ensure_claude_desktop_official_provider", "get_claude_config_status", "get_config_status",
    "get_claude_code_config_path", "get_config_dir", "open_config_folder", "pick_directory",
    "get_claude_plugin_status", "read_claude_plugin_config", "apply_claude_plugin_config",
    "is_claude_plugin_applied", "apply_claude_onboarding_skip", "clear_claude_onboarding_skip",
    "fetch_models_for_config", "export_config_to_file", "import_config_from_file",
    "webdav_test_connection", "webdav_sync_upload", "webdav_sync_download", "webdav_sync_save_settings",
    "webdav_sync_fetch_remote_info", "s3_test_connection", "s3_sync_upload", "s3_sync_download",
    "s3_sync_save_settings", "s3_sync_fetch_remote_info", "save_file_dialog", "open_file_dialog",
    "open_zip_file_dialog", "create_db_backup", "list_db_backups", "restore_db_backup",
    "rename_db_backup", "delete_db_backup", "parse_deeplink", "merge_deeplink_config",
    "import_from_deeplink", "list_sessions", "get_session_messages", "delete_session",
    "delete_sessions", "launch_session_terminal", "read_omo_local_file", "get_current_omo_provider_id",
    "disable_current_omo", "read_omo_slim_local_file", "get_current_omo_slim_provider_id",
    "disable_current_omo_slim", "read_workspace_file", "write_workspace_file", "list_daily_memory_files",
    "read_daily_memory_file", "write_daily_memory_file", "delete_daily_memory_file",
    "search_daily_memory_files", "open_workspace_directory",
  ]
}

///|
test "suite manifest omits legacy Moonstat command route surface" {
  let manifest = moonstat_suite_manifest_json(
    host="127.0.0.1",
    port=15721,
    model="gpt-5",
  )
  guard manifest is Object(obj) else { fail("expected manifest object") }
  guard obj["routes"] is Array(routes) else { fail("expected routes") }
  let moon_commands = moon_tauri_command_surface()
  assert_eq(moon_commands.length(), 59)
  for command in moon_commands {
    assert_false(suite_routes_include_path(routes, "/\{command}"))
  }
}

///|
fn gateway_source_registers_path(source : String, path : String) -> Bool {
  let marker = "\"\{path}\""
  for segment in source.split("router.add_handler(") {
    if segment.contains(marker) && segment.contains("=>") {
      return true
    }
  }
  false
}

///|
async test "gateway omits legacy Moonstat command route handlers" {
  let source = @fsx.read_file("gateway_core.mbt")
  let moon_commands = moon_tauri_command_surface()
  assert_eq(moon_commands.length(), 59)
  for command in moon_commands {
    assert_false(gateway_source_registers_path(source, "/\{command}"))
  }
  let proxy_routes = @fsx.read_file("gateway_proxy_routes.mbt")
  for
    path in [
      "/providers/delete", "/providers/live/remove", "/providers/universal/delete",
      "/providers/endpoints/remove",
    ] {
    assert_false(gateway_source_registers_path(proxy_routes, path))
  }
  let config_routes = @fsx.read_file("gateway_config_routes.mbt")
  assert_false(
    config_routes.contains("router.add_handler(Post, \"/backups/db/delete\""),
  )
  assert_true(
    config_routes.contains("router.add_handler(Delete, \"/backups/db/delete\""),
  )
}

///|
async test "suite status writes discovery file" {
  @fsx.with_temporary_directory("moonstat-suite-status-XXXXXX", tmpdir => {
    let path = @pathx.join(tmpdir, "nested/suite-status.json")
    let written = write_moonstat_suite_status(path~, port=17000, model="gpt-5")
    assert_eq(written, path)
    let content = @fsx.read_file(path)
    guard @json.parse(content) is Object(obj) else {
      fail("expected suite status json")
    }
    assert_eq(obj["contract"], Json::string("moon.suite.status.v1"))
    assert_eq(obj["ready"], Json::boolean(true))
    assert_eq(obj["openai_base_url"], Json::string("http://127.0.0.1:17000/v1"))
    assert_eq(
      obj["usage_logs_url"],
      Json::string("http://127.0.0.1:17000/usage/logs"),
    )
    assert_eq(
      obj["usage_summary_url"],
      Json::string("http://127.0.0.1:17000/usage/summary"),
    )
    assert_eq(
      obj["usage_trends_url"],
      Json::string("http://127.0.0.1:17000/usage/trends"),
    )
    assert_eq(
      obj["usage_provider_limits_url"],
      Json::string("http://127.0.0.1:17000/usage/provider-limits"),
    )
    assert_eq(
      obj["provider_presets_url"],
      Json::string("http://127.0.0.1:17000/providers/presets"),
    )
    assert_eq(
      obj["usage_sync_session_url"],
      Json::string("http://127.0.0.1:17000/usage/sync-session"),
    )
    assert_eq(
      obj["stream_check_all_providers_url"],
      Json::string("http://127.0.0.1:17000/proxy/stream-check/all"),
    )
    assert_eq(
      obj["config_status_url"],
      Json::string("http://127.0.0.1:17000/config/status"),
    )
    assert_eq(
      obj["usage_request_logs_file"],
      Json::string(
        @pathx.join(default_moonstat_stats_dir(), MOONSTAT_REQUEST_LOGS_FILE),
      ),
    )
    assert_eq(
      obj["usage_session_sync_file"],
      Json::string(
        @pathx.join(default_moonstat_stats_dir(), MOONSTAT_SESSION_SYNC_FILE),
      ),
    )
    assert_eq(
      obj["usage_model_pricing_file"],
      Json::string(
        @pathx.join(default_moonstat_stats_dir(), MOONSTAT_MODEL_PRICING_FILE),
      ),
    )
    assert_eq(
      obj["usage_opencode_export_file"],
      Json::string(default_opencode_export_path()),
    )
    assert_eq(
      obj["usage_opencode_db_file"],
      Json::string(default_opencode_db_path()),
    )
    guard obj["capabilities"] is Array(capabilities) else {
      fail("expected capabilities")
    }
    assert_true(capabilities.contains(Json::string("session-usage-sync")))
    assert_true(capabilities.contains(Json::string("moonstat-stream-check")))
    assert_true(capabilities.contains(Json::string("provider-presets")))
    guard obj["suite_integrations"] is Object(integrations) else {
      fail("expected suite integrations")
    }
    guard integrations["moondesk"] is Object(moondesk) else {
      fail("expected moondesk integration")
    }
    assert_eq(
      moondesk["models_url"],
      Json::string("http://127.0.0.1:17000/v1/models"),
    )
    assert_eq(
      moondesk["provider_presets_url"],
      Json::string("http://127.0.0.1:17000/providers/presets"),
    )
    assert_eq(
      moondesk["stream_check_provider_url"],
      Json::string("http://127.0.0.1:17000/proxy/stream-check/provider"),
    )
    guard obj["commands"] is Object(commands) else { fail("expected commands") }
    assert_eq(commands["start"], Json::string("moonstat start --port 17000"))
    assert_eq(
      commands["codex_install"],
      Json::string("moonstat codex install --port 17000 --model gpt-5"),
    )
    assert_eq(
      commands["copilot_auth_status"],
      Json::string("moonstat copilot status"),
    )
    assert_eq(
      commands["provider_presets"],
      Json::string("moonstat provider presets list --app-type <app_type>"),
    )
    guard obj["manifest"] is Object(manifest) else {
      fail("expected manifest object")
    }
    assert_eq(manifest["default_port"], Json::number(17000.0))
  })
}

///|
async test "suite status can publish running startup state" {
  @fsx.with_temporary_directory("moonstat-suite-status-running-XXXXXX", tmpdir => {
    let path = @pathx.join(tmpdir, "suite-status.json")
    let written = write_moonstat_suite_status(
      path~,
      host="0.0.0.0",
      port=17001,
      model="gpt-5",
      status="running",
      ready=true,
    )
    assert_eq(written, path)
    guard @json.parse(@fsx.read_file(path)) is Object(obj) else {
      fail("expected suite status json")
    }
    assert_eq(obj["status"], Json::string("running"))
    assert_eq(obj["ready"], Json::boolean(true))
    assert_eq(obj["health_url"], Json::string("http://127.0.0.1:17001/health"))
  })
}

///|
async test "gateway start writes running suite status" {
  let source = @fsx.read_file("gateway_core.mbt")
  assert_true(source.contains("write_moonstat_suite_status("))
  assert_true(source.contains("status=\"running\""))
}
