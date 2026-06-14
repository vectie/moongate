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
    Json::string("http://127.0.0.1:15721/get_provider_presets"),
  )
  assert_eq(
    obj["usage_sync_session_url"],
    Json::string("http://127.0.0.1:15721/usage/sync-session"),
  )
  assert_eq(
    obj["stream_check_provider_url"],
    Json::string("http://127.0.0.1:15721/stream_check_provider"),
  )
  assert_eq(
    obj["stream_check_all_providers_url"],
    Json::string("http://127.0.0.1:15721/stream_check_all_providers"),
  )
  assert_eq(
    obj["stream_check_config_url"],
    Json::string("http://127.0.0.1:15721/get_stream_check_config"),
  )
  assert_eq(
    obj["config_status_url"],
    Json::string("http://127.0.0.1:15721/get_config_status"),
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
  assert_true(capabilities.contains(Json::string("ccs-usage-statistics")))
  assert_true(capabilities.contains(Json::string("ccs-stream-check")))
  assert_true(capabilities.contains(Json::string("ccs-skills-management")))
  assert_true(capabilities.contains(Json::string("provider-presets")))
  assert_true(capabilities.contains(Json::string("suite-discovery")))
  assert_true(routes.contains(Json::string("GET /participant/register")))
  assert_true(routes.contains(Json::string("GET /stats")))
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
  assert_true(routes.contains(Json::string("GET|POST /get_usage_summary")))
  assert_true(
    routes.contains(Json::string("GET|POST /get_usage_summary_by_app")),
  )
  assert_true(routes.contains(Json::string("GET|POST /get_usage_trends")))
  assert_true(routes.contains(Json::string("GET|POST /get_provider_stats")))
  assert_true(routes.contains(Json::string("GET|POST /get_model_stats")))
  assert_true(routes.contains(Json::string("GET|POST /get_request_logs")))
  assert_true(routes.contains(Json::string("GET|POST /get_request_detail")))
  assert_true(routes.contains(Json::string("GET /get_model_pricing")))
  assert_true(routes.contains(Json::string("POST /update_model_pricing")))
  assert_true(
    routes.contains(Json::string("DELETE|POST /delete_model_pricing")),
  )
  assert_true(routes.contains(Json::string("GET|POST /check_provider_limits")))
  assert_true(routes.contains(Json::string("POST /sync_session_usage")))
  assert_true(routes.contains(Json::string("GET|POST /get_usage_data_sources")))
  assert_true(routes.contains(Json::string("GET|POST /queryProviderUsage")))
  assert_true(routes.contains(Json::string("GET|POST /get_balance")))
  assert_true(routes.contains(Json::string("GET|POST /get_subscription_quota")))
  assert_true(routes.contains(Json::string("GET|POST /get_codex_oauth_quota")))
  assert_true(routes.contains(Json::string("GET|POST /get_codex_oauth_models")))
  assert_true(routes.contains(Json::string("GET|POST /get_coding_plan_quota")))
  assert_true(routes.contains(Json::string("POST /testUsageScript")))
  assert_true(routes.contains(Json::string("GET|POST /stream_check_provider")))
  assert_true(
    routes.contains(Json::string("GET|POST /stream_check_all_providers")),
  )
  assert_true(routes.contains(Json::string("GET /get_stream_check_config")))
  assert_true(routes.contains(Json::string("POST /save_stream_check_config")))
  assert_true(routes.contains(Json::string("GET /get_provider_presets")))
  assert_true(routes.contains(Json::string("GET|POST /auth_get_status")))
  assert_true(routes.contains(Json::string("GET|POST /auth_list_accounts")))
  assert_true(routes.contains(Json::string("GET|POST /auth_start_login")))
  assert_true(routes.contains(Json::string("GET|POST /auth_poll_for_account")))
  assert_true(routes.contains(Json::string("DELETE|POST /auth_remove_account")))
  assert_true(
    routes.contains(Json::string("GET|POST /auth_set_default_account")),
  )
  assert_true(routes.contains(Json::string("GET|POST /auth_logout")))
  assert_true(routes.contains(Json::string("GET /copilot_get_auth_status")))
  assert_true(routes.contains(Json::string("GET /copilot_list_accounts")))
  assert_true(routes.contains(Json::string("GET /copilot_is_authenticated")))
  assert_true(
    routes.contains(Json::string("GET|POST /copilot_start_device_flow")),
  )
  assert_true(routes.contains(Json::string("GET|POST /copilot_poll_for_auth")))
  assert_true(
    routes.contains(Json::string("GET|POST /copilot_poll_for_account")),
  )
  assert_true(routes.contains(Json::string("GET|POST /copilot_logout")))
  assert_true(
    routes.contains(Json::string("DELETE|POST /copilot_remove_account")),
  )
  assert_true(
    routes.contains(Json::string("GET|POST /copilot_set_default_account")),
  )
  assert_true(routes.contains(Json::string("GET /copilot_get_token")))
  assert_true(
    routes.contains(Json::string("GET /copilot_get_token_for_account")),
  )
  assert_true(routes.contains(Json::string("GET /copilot_get_models")))
  assert_true(
    routes.contains(Json::string("GET /copilot_get_models_for_account")),
  )
  assert_true(routes.contains(Json::string("GET /copilot_get_usage")))
  assert_true(
    routes.contains(Json::string("GET /copilot_get_usage_for_account")),
  )
  assert_true(routes.contains(Json::string("GET|POST /get_tool_versions")))
  assert_true(routes.contains(Json::string("POST /run_tool_lifecycle_action")))
  assert_true(
    routes.contains(Json::string("GET|POST /probe_tool_installations")),
  )
  assert_true(routes.contains(Json::string("GET|POST /update_tray_menu")))
  assert_true(routes.contains(Json::string("GET|POST /open_external")))
  assert_true(routes.contains(Json::string("GET /is_lightweight_mode")))
  assert_true(routes.contains(Json::string("GET|POST /export_config_to_file")))
  assert_true(
    routes.contains(Json::string("GET|POST /import_config_from_file")),
  )
  assert_true(routes.contains(Json::string("POST /create_db_backup")))
  assert_true(routes.contains(Json::string("GET /list_db_backups")))
  assert_true(routes.contains(Json::string("POST /restore_db_backup")))
  assert_true(routes.contains(Json::string("POST /rename_db_backup")))
  assert_true(routes.contains(Json::string("DELETE|POST /delete_db_backup")))
  assert_true(routes.contains(Json::string("GET|POST /parse_deeplink")))
  assert_true(routes.contains(Json::string("GET|POST /merge_deeplink_config")))
  assert_true(routes.contains(Json::string("POST /import_from_deeplink")))
  assert_true(
    routes.contains(Json::string("POST /import_from_deeplink_unified")),
  )
  assert_true(routes.contains(Json::string("POST /webdav_test_connection")))
  assert_true(routes.contains(Json::string("POST /webdav_sync_upload")))
  assert_true(routes.contains(Json::string("POST /webdav_sync_download")))
  assert_true(routes.contains(Json::string("POST /webdav_sync_save_settings")))
  assert_true(
    routes.contains(Json::string("GET /webdav_sync_fetch_remote_info")),
  )
  assert_true(routes.contains(Json::string("POST /s3_test_connection")))
  assert_true(routes.contains(Json::string("POST /s3_sync_upload")))
  assert_true(routes.contains(Json::string("POST /s3_sync_download")))
  assert_true(routes.contains(Json::string("POST /s3_sync_save_settings")))
  assert_true(routes.contains(Json::string("GET /s3_sync_fetch_remote_info")))
  assert_true(routes.contains(Json::string("GET|POST /list_sessions")))
  assert_true(routes.contains(Json::string("GET|POST /get_session_messages")))
  assert_true(routes.contains(Json::string("POST /launch_session_terminal")))
  assert_true(routes.contains(Json::string("POST /delete_session")))
  assert_true(routes.contains(Json::string("POST /delete_sessions")))
  assert_true(routes.contains(Json::string("GET|POST /read_omo_local_file")))
  assert_true(
    routes.contains(Json::string("GET|POST /get_current_omo_provider_id")),
  )
  assert_true(routes.contains(Json::string("POST /disable_current_omo")))
  assert_true(
    routes.contains(Json::string("GET|POST /read_omo_slim_local_file")),
  )
  assert_true(
    routes.contains(Json::string("GET|POST /get_current_omo_slim_provider_id")),
  )
  assert_true(routes.contains(Json::string("POST /disable_current_omo_slim")))
  assert_true(routes.contains(Json::string("GET /get_installed_skills")))
  assert_true(routes.contains(Json::string("GET /get_skill_backups")))
  assert_true(routes.contains(Json::string("POST /install_skill_unified")))
  assert_true(routes.contains(Json::string("POST /toggle_skill_app")))
  assert_true(routes.contains(Json::string("GET|POST /search_skills_sh")))
  assert_true(routes.contains(Json::string("GET /get_skill_repos")))
  assert_true(routes.contains(Json::string("POST /install_skills_from_zip")))
  assert_true(routes.contains(Json::string("GET /get_proxy_status")))
  assert_true(routes.contains(Json::string("GET /get_proxy_config")))
  assert_true(routes.contains(Json::string("POST /update_proxy_config")))
  assert_true(routes.contains(Json::string("GET /get_global_proxy_config")))
  assert_true(routes.contains(Json::string("POST /update_global_proxy_config")))
  assert_true(routes.contains(Json::string("GET /get_proxy_config_for_app")))
  assert_true(
    routes.contains(Json::string("POST /update_proxy_config_for_app")),
  )
  assert_true(routes.contains(Json::string("GET /get_proxy_takeover_status")))
  assert_true(routes.contains(Json::string("POST /set_proxy_takeover_for_app")))
  assert_true(routes.contains(Json::string("GET /get_default_cost_multiplier")))
  assert_true(routes.contains(Json::string("GET /get_pricing_model_source")))
  assert_true(
    routes.contains(Json::string("GET /get_default_cost_multiplier_test_hook")),
  )
  assert_true(routes.contains(Json::string("POST /switch_provider_test_hook")))
  assert_true(routes.contains(Json::string("POST /import_default_config")))
  assert_true(routes.contains(Json::string("DELETE|POST /delete_provider")))
  assert_true(
    routes.contains(
      Json::string("DELETE|POST /remove_provider_from_live_config"),
    ),
  )
  assert_true(
    routes.contains(Json::string("DELETE|POST /remove_custom_endpoint")),
  )
  assert_true(routes.contains(Json::string("POST /open_provider_terminal")))
  assert_true(routes.contains(Json::string("GET /get_claude_config_status")))
  assert_true(routes.contains(Json::string("GET|POST /get_config_status")))
  assert_true(routes.contains(Json::string("GET /get_claude_desktop_status")))
  let control_routes = [
    "GET /proxy/status", "POST /start_proxy_server", "POST /stop_proxy_server", "POST /stop_proxy_with_restore",
    "GET|POST /proxy/config", "GET|POST /proxy/global-config", "GET|POST /proxy/app-config",
    "GET|POST /proxy/default-cost-multiplier", "GET|POST /proxy/pricing-model-source",
    "GET /proxy/provider-health", "GET|POST /proxy/circuit-breaker-config", "GET /proxy/circuit-breaker-stats",
    "GET|POST|DELETE /proxy/failover-queue", "GET|POST /proxy/auto-failover-enabled",
    "GET|POST /proxy/takeover-status", "GET /proxy/running", "POST /set_default_cost_multiplier",
    "POST /set_pricing_model_source", "POST /switch_proxy_provider", "POST /sync_current_providers_live",
    "GET|POST /get_providers", "GET|POST /get_current_provider", "POST /add_provider",
    "POST /update_provider", "POST /switch_provider", "GET|POST /read_live_provider_settings",
    "GET /get_provider_health", "POST /add_to_failover_queue", "POST|DELETE /remove_from_failover_queue",
    "GET /get_available_providers_for_failover", "POST /set_auto_failover_enabled",
    "POST /reset_circuit_breaker", "GET /get_mcp_servers", "POST /upsert_mcp_server",
    "POST|DELETE /delete_mcp_server", "GET|POST /get_prompts", "POST /upsert_prompt",
    "POST|DELETE /delete_prompt", "POST /import_opencode_providers_from_live", "GET /get_openclaw_live_provider_ids",
    "POST /import_openclaw_providers_from_live", "GET|POST /get_openclaw_live_provider",
    "GET /get_openclaw_default_model", "POST /set_openclaw_default_model", "GET /get_hermes_live_provider_ids",
    "GET|POST /get_hermes_live_provider", "GET|POST /get_hermes_memory", "POST /import_hermes_providers_from_live",
    "POST /set_hermes_memory", "GET /get_universal_providers", "GET /get_universal_provider",
    "POST /upsert_universal_provider", "POST|DELETE /delete_universal_provider",
    "GET|POST /test_api_endpoints", "GET|POST /fetch_models_for_config",
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
    Json::string("http://127.0.0.1:15721/get_provider_presets"),
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
    Json::string("http://127.0.0.1:15721/stream_check_all_providers"),
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
    Json::string("http://127.0.0.1:15721/get_provider_presets"),
  )
  assert_eq(
    moondesk["stream_check_config_url"],
    Json::string("http://127.0.0.1:15721/get_stream_check_config"),
  )
  assert_eq(
    moondesk["config_status_url"],
    Json::string("http://127.0.0.1:15721/get_config_status"),
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
  assert_eq(
    commands["skills_list"],
    Json::string("moonstat get_installed_skills"),
  )
  assert_eq(commands["skills_repos"], Json::string("moonstat get_skill_repos"))
  assert_eq(
    commands["update_tray_menu"],
    Json::string("moonstat update_tray_menu"),
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
    Json::string("moonstat provider presets list --app <app_type>"),
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
fn ccs_tauri_command_surface() -> Array[String] {
  [
    "get_providers", "get_current_provider", "add_provider", "update_provider", "delete_provider",
    "remove_provider_from_live_config", "switch_provider", "import_default_config",
    "get_claude_desktop_status", "get_claude_desktop_default_routes", "import_claude_desktop_providers_from_claude",
    "ensure_claude_desktop_official_provider", "get_claude_config_status", "get_config_status",
    "get_claude_code_config_path", "get_config_dir", "open_config_folder", "pick_directory",
    "open_external", "get_init_error", "get_migration_result", "get_skills_migration_result",
    "get_app_config_path", "open_app_config_folder", "get_claude_common_config_snippet",
    "set_claude_common_config_snippet", "get_common_config_snippet", "set_common_config_snippet",
    "extract_common_config_snippet", "read_live_provider_settings", "get_settings",
    "save_settings", "get_rectifier_config", "set_rectifier_config", "get_optimizer_config",
    "set_optimizer_config", "get_copilot_optimizer_config", "set_copilot_optimizer_config",
    "get_log_config", "set_log_config", "restart_app", "install_update_and_restart",
    "check_for_updates", "is_portable_mode", "copy_text_to_clipboard", "get_claude_plugin_status",
    "read_claude_plugin_config", "apply_claude_plugin_config", "is_claude_plugin_applied",
    "apply_claude_onboarding_skip", "clear_claude_onboarding_skip", "get_claude_mcp_status",
    "read_claude_mcp_config", "upsert_claude_mcp_server", "delete_claude_mcp_server",
    "validate_mcp_command", "queryProviderUsage", "testUsageScript", "get_subscription_quota",
    "get_codex_oauth_quota", "get_codex_oauth_models", "get_coding_plan_quota", "get_balance",
    "get_mcp_config", "upsert_mcp_server_in_config", "delete_mcp_server_in_config",
    "set_mcp_enabled", "get_mcp_servers", "upsert_mcp_server", "delete_mcp_server",
    "toggle_mcp_app", "import_mcp_from_apps", "get_prompts", "upsert_prompt", "delete_prompt",
    "enable_prompt", "import_prompt_from_file", "get_current_prompt_file_content",
    "fetch_models_for_config", "test_api_endpoints", "get_custom_endpoints", "add_custom_endpoint",
    "remove_custom_endpoint", "update_endpoint_last_used", "get_app_config_dir_override",
    "set_app_config_dir_override", "update_providers_sort_order", "export_config_to_file",
    "import_config_from_file", "webdav_test_connection", "webdav_sync_upload", "webdav_sync_download",
    "webdav_sync_save_settings", "webdav_sync_fetch_remote_info", "s3_test_connection",
    "s3_sync_upload", "s3_sync_download", "s3_sync_save_settings", "s3_sync_fetch_remote_info",
    "save_file_dialog", "open_file_dialog", "open_zip_file_dialog", "create_db_backup",
    "list_db_backups", "restore_db_backup", "rename_db_backup", "delete_db_backup",
    "sync_current_providers_live", "parse_deeplink", "merge_deeplink_config", "import_from_deeplink",
    "import_from_deeplink_unified", "update_tray_menu", "check_env_conflicts", "delete_env_vars",
    "restore_env_backup", "get_installed_skills", "get_skill_backups", "delete_skill_backup",
    "install_skill_unified", "uninstall_skill_unified", "restore_skill_backup", "toggle_skill_app",
    "scan_unmanaged_skills", "import_skills_from_apps", "discover_available_skills",
    "check_skill_updates", "update_skill", "migrate_skill_storage", "search_skills_sh",
    "get_skills", "get_skills_for_app", "install_skill", "install_skill_for_app",
    "uninstall_skill", "uninstall_skill_for_app", "get_skill_repos", "add_skill_repo",
    "remove_skill_repo", "install_skills_from_zip", "set_auto_launch", "get_auto_launch_status",
    "start_proxy_server", "stop_proxy_server", "stop_proxy_with_restore", "get_proxy_takeover_status",
    "set_proxy_takeover_for_app", "get_proxy_status", "get_proxy_config", "update_proxy_config",
    "get_global_proxy_config", "update_global_proxy_config", "get_proxy_config_for_app",
    "update_proxy_config_for_app", "get_default_cost_multiplier", "set_default_cost_multiplier",
    "get_pricing_model_source", "set_pricing_model_source", "is_proxy_running", "is_live_takeover_active",
    "switch_proxy_provider", "get_provider_health", "reset_circuit_breaker", "get_circuit_breaker_config",
    "update_circuit_breaker_config", "get_circuit_breaker_stats", "get_failover_queue",
    "get_available_providers_for_failover", "add_to_failover_queue", "remove_from_failover_queue",
    "get_auto_failover_enabled", "set_auto_failover_enabled", "get_usage_summary",
    "get_usage_summary_by_app", "get_usage_trends", "get_provider_stats", "get_model_stats",
    "get_request_logs", "get_request_detail", "get_model_pricing", "update_model_pricing",
    "delete_model_pricing", "check_provider_limits", "sync_session_usage", "get_usage_data_sources",
    "stream_check_provider", "stream_check_all_providers", "get_stream_check_config",
    "save_stream_check_config", "list_sessions", "get_session_messages", "delete_session",
    "delete_sessions", "launch_session_terminal", "get_tool_versions", "run_tool_lifecycle_action",
    "probe_tool_installations", "open_provider_terminal", "get_universal_providers",
    "get_universal_provider", "upsert_universal_provider", "delete_universal_provider",
    "sync_universal_provider", "import_opencode_providers_from_live", "get_opencode_live_provider_ids",
    "import_openclaw_providers_from_live", "get_openclaw_live_provider_ids", "get_openclaw_live_provider",
    "scan_openclaw_config_health", "get_openclaw_default_model", "set_openclaw_default_model",
    "get_openclaw_model_catalog", "set_openclaw_model_catalog", "get_openclaw_agents_defaults",
    "set_openclaw_agents_defaults", "get_openclaw_env", "set_openclaw_env", "get_openclaw_tools",
    "set_openclaw_tools", "import_hermes_providers_from_live", "get_hermes_live_provider_ids",
    "get_hermes_live_provider", "get_hermes_model_config", "open_hermes_web_ui",
    "launch_hermes_dashboard", "get_hermes_memory", "set_hermes_memory", "get_hermes_memory_limits",
    "set_hermes_memory_enabled", "get_global_proxy_url", "set_global_proxy_url",
    "test_proxy_url", "get_upstream_proxy_status", "scan_local_proxies", "set_window_theme",
    "auth_start_login", "auth_poll_for_account", "auth_list_accounts", "auth_get_status",
    "auth_remove_account", "auth_set_default_account", "auth_logout", "copilot_start_device_flow",
    "copilot_poll_for_auth", "copilot_poll_for_account", "copilot_list_accounts",
    "copilot_remove_account", "copilot_set_default_account", "copilot_get_auth_status",
    "copilot_logout", "copilot_is_authenticated", "copilot_get_token", "copilot_get_token_for_account",
    "copilot_get_models", "copilot_get_models_for_account", "copilot_get_usage",
    "copilot_get_usage_for_account", "read_omo_local_file", "get_current_omo_provider_id",
    "disable_current_omo", "read_omo_slim_local_file", "get_current_omo_slim_provider_id",
    "disable_current_omo_slim", "read_workspace_file", "write_workspace_file", "list_daily_memory_files",
    "read_daily_memory_file", "write_daily_memory_file", "delete_daily_memory_file",
    "search_daily_memory_files", "open_workspace_directory", "enter_lightweight_mode",
    "exit_lightweight_mode", "is_lightweight_mode",
  ]
}

///|
test "suite manifest covers current CCS Tauri command surface" {
  let manifest = moonstat_suite_manifest_json(
    host="127.0.0.1",
    port=15721,
    model="gpt-5",
  )
  guard manifest is Object(obj) else { fail("expected manifest object") }
  guard obj["routes"] is Array(routes) else { fail("expected routes") }
  let ccs_commands = ccs_tauri_command_surface()
  assert_eq(ccs_commands.length(), 274)
  for command in ccs_commands {
    assert_true(suite_routes_include_path(routes, "/\{command}"))
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
async test "gateway registers current CCS Tauri command handlers" {
  let source = @fsx.read_file("gateway.mbt")
  let ccs_commands = ccs_tauri_command_surface()
  assert_eq(ccs_commands.length(), 274)
  for command in ccs_commands {
    assert_true(gateway_source_registers_path(source, "/\{command}"))
  }
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
      Json::string("http://127.0.0.1:17000/get_provider_presets"),
    )
    assert_eq(
      obj["usage_sync_session_url"],
      Json::string("http://127.0.0.1:17000/usage/sync-session"),
    )
    assert_eq(
      obj["stream_check_all_providers_url"],
      Json::string("http://127.0.0.1:17000/stream_check_all_providers"),
    )
    assert_eq(
      obj["config_status_url"],
      Json::string("http://127.0.0.1:17000/get_config_status"),
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
    assert_true(capabilities.contains(Json::string("ccs-stream-check")))
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
      Json::string("http://127.0.0.1:17000/get_provider_presets"),
    )
    assert_eq(
      moondesk["stream_check_provider_url"],
      Json::string("http://127.0.0.1:17000/stream_check_provider"),
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
      Json::string("moonstat provider presets list --app <app_type>"),
    )
    guard obj["manifest"] is Object(manifest) else {
      fail("expected manifest object")
    }
    assert_eq(manifest["default_port"], Json::number(17000.0))
  })
}
