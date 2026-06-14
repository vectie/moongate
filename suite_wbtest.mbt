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
  assert_true(routes.contains(Json::string("GET /usage/logs")))
  assert_true(routes.contains(Json::string("GET /usage/summary")))
  assert_true(routes.contains(Json::string("GET /usage/summary/by-app")))
  assert_true(routes.contains(Json::string("GET /usage/trends")))
  assert_true(routes.contains(Json::string("GET /usage/provider-limits")))
  assert_true(routes.contains(Json::string("GET /usage/provider-stats")))
  assert_true(routes.contains(Json::string("GET /usage/model-stats")))
  assert_true(routes.contains(Json::string("GET|POST /usage/data-sources")))
  assert_true(routes.contains(Json::string("POST /usage/sync-session")))
  assert_true(routes.contains(Json::string("GET /usage/model-pricing")))
  assert_true(routes.contains(Json::string("POST /usage/model-pricing")))
  assert_true(routes.contains(Json::string("DELETE /usage/model-pricing")))
  assert_true(
    routes.contains(Json::string("GET /usage/request-detail/{request_id}")),
  )
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
  assert_true(routes.contains(Json::string("GET /auth_get_status")))
  assert_true(routes.contains(Json::string("GET /auth_list_accounts")))
  assert_true(routes.contains(Json::string("POST /auth_start_login")))
  assert_true(routes.contains(Json::string("POST /auth_poll_for_account")))
  assert_true(routes.contains(Json::string("POST /auth_logout")))
  assert_true(routes.contains(Json::string("GET /copilot_get_auth_status")))
  assert_true(routes.contains(Json::string("GET /copilot_list_accounts")))
  assert_true(routes.contains(Json::string("GET /copilot_is_authenticated")))
  assert_true(routes.contains(Json::string("POST /copilot_start_device_flow")))
  assert_true(routes.contains(Json::string("POST /copilot_poll_for_auth")))
  assert_true(routes.contains(Json::string("POST /copilot_poll_for_account")))
  assert_true(routes.contains(Json::string("POST /copilot_logout")))
  assert_true(routes.contains(Json::string("DELETE /copilot_remove_account")))
  assert_true(
    routes.contains(Json::string("POST /copilot_set_default_account")),
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
  assert_true(routes.contains(Json::string("GET /get_config_status")))
  assert_true(routes.contains(Json::string("GET /get_claude_desktop_status")))
  let control_routes = [
    "GET /proxy/status", "POST /start_proxy_server", "POST /stop_proxy_server", "POST /stop_proxy_with_restore",
    "GET|POST /proxy/config", "GET|POST /proxy/global-config", "GET|POST /proxy/app-config",
    "GET|POST /proxy/default-cost-multiplier", "GET|POST /proxy/pricing-model-source",
    "GET /proxy/provider-health", "GET|POST /proxy/circuit-breaker-config", "GET /proxy/circuit-breaker-stats",
    "GET|POST|DELETE /proxy/failover-queue", "GET|POST /proxy/auto-failover-enabled",
    "GET|POST /proxy/takeover-status", "GET /proxy/running", "POST /set_default_cost_multiplier",
    "POST /set_pricing_model_source", "POST /switch_proxy_provider", "POST /sync_current_providers_live",
    "GET /get_providers", "GET /get_current_provider", "POST /add_provider", "POST /update_provider",
    "POST /switch_provider", "GET /read_live_provider_settings", "GET /get_provider_health",
    "POST /add_to_failover_queue", "POST|DELETE /remove_from_failover_queue", "GET /get_available_providers_for_failover",
    "POST /set_auto_failover_enabled", "POST /reset_circuit_breaker", "GET /get_mcp_servers",
    "POST /upsert_mcp_server", "POST|DELETE /delete_mcp_server", "GET /get_prompts",
    "POST /upsert_prompt", "POST|DELETE /delete_prompt", "POST /import_opencode_providers_from_live",
    "GET /get_openclaw_live_provider_ids", "POST /import_openclaw_providers_from_live",
    "GET /get_openclaw_live_provider", "GET /get_openclaw_default_model", "POST /set_openclaw_default_model",
    "GET /get_hermes_live_provider_ids", "GET /get_hermes_live_provider", "GET /get_hermes_memory",
    "POST /import_hermes_providers_from_live", "POST /set_hermes_memory", "GET /get_universal_providers",
    "GET /get_universal_provider", "POST /upsert_universal_provider", "POST|DELETE /delete_universal_provider",
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
  guard obj["commands"] is Object(commands) else { fail("expected commands") }
  assert_eq(commands["start"], Json::string("moonstat start --port 15721"))
  assert_eq(
    commands["skills_list"],
    Json::string("moonstat get_installed_skills"),
  )
  assert_eq(commands["skills_repos"], Json::string("moonstat get_skill_repos"))
  assert_eq(
    commands["suite_write_status"],
    Json::string("moonstat suite write-status"),
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
