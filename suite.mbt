///|
const SUITE_STATUS_FILE = "suite-status.json"

///|
pub fn moonstat_suite_manifest_json(
  host? : String = "127.0.0.1",
  port? : Int = 15721,
  model? : String = "gpt-5",
) -> Json {
  {
    "contract": Json::string("moon.suite.service.v1"),
    "service": Json::string("moonstat"),
    "project": Json::string("moonstat"),
    "version": Json::string("0.1.0"),
    "role": Json::string("network-edge"),
    "default_host": Json::string(suite_url_host(host)),
    "default_port": Json::number(port.to_double()),
    "base_url": Json::string(moonstat_base_url(host, port)),
    "openai_base_url": Json::string(moonstat_openai_base_url(host, port)),
    "anthropic_base_url": Json::string(moonstat_base_url(host, port)),
    "claude_desktop_base_url": Json::string(
      moonstat_claude_desktop_base_url(host, port),
    ),
    "default_model": Json::string(model),
    "status_file": Json::string(default_moonstat_suite_status_path()),
    "capabilities": Json::array(
      moonstat_suite_capabilities().map(fn(capability) {
        Json::string(capability)
      }),
    ),
    "health_url": Json::string("\{moonstat_base_url(host, port)}/health"),
    "status_url": Json::string("\{moonstat_base_url(host, port)}/status"),
    "stats_url": Json::string("\{moonstat_base_url(host, port)}/stats"),
    "usage_logs_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/logs",
    ),
    "usage_summary_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/summary",
    ),
    "usage_summary_by_app_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/summary/by-app",
    ),
    "usage_trends_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/trends",
    ),
    "usage_provider_limits_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/provider-limits",
    ),
    "usage_provider_stats_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/provider-stats",
    ),
    "usage_model_stats_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/model-stats",
    ),
    "usage_data_sources_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/data-sources",
    ),
    "usage_sync_session_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/sync-session",
    ),
    "usage_model_pricing_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/model-pricing",
    ),
    "provider_presets_url": Json::string(
      "\{moonstat_base_url(host, port)}/get_provider_presets",
    ),
    "usage_request_detail_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/request-detail/{request_id}",
    ),
    "stream_check_provider_url": Json::string(
      "\{moonstat_base_url(host, port)}/stream_check_provider",
    ),
    "stream_check_all_providers_url": Json::string(
      "\{moonstat_base_url(host, port)}/stream_check_all_providers",
    ),
    "stream_check_config_url": Json::string(
      "\{moonstat_base_url(host, port)}/get_stream_check_config",
    ),
    "config_status_url": Json::string(
      "\{moonstat_base_url(host, port)}/get_config_status",
    ),
    "usage_store_dir": Json::string(default_moonstat_stats_dir()),
    "usage_request_logs_file": Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_REQUEST_LOGS_FILE),
    ),
    "usage_session_sync_file": Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_SESSION_SYNC_FILE),
    ),
    "usage_model_pricing_file": Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_MODEL_PRICING_FILE),
    ),
    "usage_opencode_db_file": Json::string(default_opencode_db_path()),
    "usage_opencode_export_file": Json::string(default_opencode_export_path()),
    "models_url": Json::string("\{moonstat_openai_base_url(host, port)}/models"),
    "routes": Json::array(
      moonstat_suite_routes().map(fn(route) { Json::string(route) }),
    ),
    "apps": Json::array([
      suite_app_json(
        "moonclaw", "agent-runtime", "Use moonstat as the OpenAI-compatible or Anthropic-compatible local edge for agent provider calls.",
      ),
      suite_app_json(
        "moonbook", "durable-output", "Store generated reports and proxy usage summaries outside moonstat.",
      ),
      suite_app_json(
        "moontown", "scheduler-control-plane", "Watch moonstat health/status/stats as the network edge for standing goals.",
      ),
      suite_app_json(
        "moondesk", "operator-shell", "Read the suite status file and display gateway health, model catalog, and traffic counters.",
      ),
    ]),
    "suite_integrations": moonstat_suite_integrations_json(host, port, model),
    "commands": moonstat_suite_commands_json(port, model),
    "cli": moonstat_suite_commands_json(port, model),
  }.to_json()
}

///|
pub fn moonstat_suite_status_json(
  host? : String = "127.0.0.1",
  port? : Int = 15721,
  model? : String = "gpt-5",
) -> Json {
  {
    "contract": Json::string("moon.suite.status.v1"),
    "service": Json::string("moonstat"),
    "status": Json::string("configured"),
    "ready": Json::boolean(true),
    "manifest": moonstat_suite_manifest_json(host~, port~, model~),
    "status_path": Json::string(default_moonstat_suite_status_path()),
    "capabilities": Json::array(
      moonstat_suite_capabilities().map(fn(capability) {
        Json::string(capability)
      }),
    ),
    "commands": moonstat_suite_commands_json(port, model),
    "health_url": Json::string("\{moonstat_base_url(host, port)}/health"),
    "status_url": Json::string("\{moonstat_base_url(host, port)}/status"),
    "stats_url": Json::string("\{moonstat_base_url(host, port)}/stats"),
    "usage_logs_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/logs",
    ),
    "usage_summary_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/summary",
    ),
    "usage_summary_by_app_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/summary/by-app",
    ),
    "usage_trends_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/trends",
    ),
    "usage_provider_limits_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/provider-limits",
    ),
    "usage_provider_stats_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/provider-stats",
    ),
    "usage_model_stats_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/model-stats",
    ),
    "usage_data_sources_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/data-sources",
    ),
    "usage_sync_session_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/sync-session",
    ),
    "usage_model_pricing_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/model-pricing",
    ),
    "provider_presets_url": Json::string(
      "\{moonstat_base_url(host, port)}/get_provider_presets",
    ),
    "usage_request_detail_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/request-detail/{request_id}",
    ),
    "stream_check_provider_url": Json::string(
      "\{moonstat_base_url(host, port)}/stream_check_provider",
    ),
    "stream_check_all_providers_url": Json::string(
      "\{moonstat_base_url(host, port)}/stream_check_all_providers",
    ),
    "stream_check_config_url": Json::string(
      "\{moonstat_base_url(host, port)}/get_stream_check_config",
    ),
    "config_status_url": Json::string(
      "\{moonstat_base_url(host, port)}/get_config_status",
    ),
    "usage_store_dir": Json::string(default_moonstat_stats_dir()),
    "usage_request_logs_file": Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_REQUEST_LOGS_FILE),
    ),
    "usage_session_sync_file": Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_SESSION_SYNC_FILE),
    ),
    "usage_model_pricing_file": Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_MODEL_PRICING_FILE),
    ),
    "usage_opencode_db_file": Json::string(default_opencode_db_path()),
    "usage_opencode_export_file": Json::string(default_opencode_export_path()),
    "suite_integrations": moonstat_suite_integrations_json(host, port, model),
    "openai_base_url": Json::string(moonstat_openai_base_url(host, port)),
    "anthropic_base_url": Json::string(moonstat_base_url(host, port)),
    "claude_desktop_base_url": Json::string(
      moonstat_claude_desktop_base_url(host, port),
    ),
    "model": Json::string(model),
  }.to_json()
}

///|
pub async fn write_moonstat_suite_status(
  path? : String = default_moonstat_suite_status_path(),
  host? : String = "127.0.0.1",
  port? : Int = 15721,
  model? : String = "gpt-5",
) -> String {
  let dir = @pathx.dirname(path)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  let json = moonstat_suite_status_json(host~, port~, model~).stringify(
    indent=2,
  )
  @fsx.write_to_file(path, json)
  path
}

///|
pub fn default_moonstat_suite_status_path() -> String {
  @pathx.join(default_moonstat_dir(), SUITE_STATUS_FILE)
}

///|
fn default_moonstat_dir() -> String {
  let home = @os.home() catch { _ => "." }
  @pathx.join(home, ".moonstat")
}

///|
fn moonstat_base_url(host : String, port : Int) -> String {
  "http://\{suite_url_host(host)}:\{port}"
}

///|
fn moonstat_openai_base_url(host : String, port : Int) -> String {
  "\{moonstat_base_url(host, port)}/v1"
}

///|
fn moonstat_claude_desktop_base_url(host : String, port : Int) -> String {
  "\{moonstat_base_url(host, port)}/claude-desktop/v1"
}

///|
fn suite_url_host(host : String) -> String {
  if host == "0.0.0.0" || host == "::" {
    "127.0.0.1"
  } else {
    host
  }
}

///|
fn suite_app_json(id : String, role : String, usage : String) -> Json {
  Json::object({
    "id": Json::string(id),
    "role": Json::string(role),
    "usage": Json::string(usage),
  })
}

///|
fn moonstat_suite_integrations_json(
  host : String,
  port : Int,
  model : String,
) -> Json {
  let base_url = moonstat_base_url(host, port)
  let openai_base_url = moonstat_openai_base_url(host, port)
  let anthropic_base_url = base_url
  let claude_desktop_base_url = moonstat_claude_desktop_base_url(host, port)
  Json::object({
    "moonclaw": Json::object({
      "role": Json::string("agent-provider-edge"),
      "openai_base_url": Json::string(openai_base_url),
      "anthropic_base_url": Json::string(anthropic_base_url),
      "default_model": Json::string(model),
      "health_url": Json::string("\{base_url}/health"),
      "usage_summary_url": Json::string("\{base_url}/usage/summary"),
      "usage_logs_url": Json::string("\{base_url}/usage/logs"),
      "provider_presets_url": Json::string("\{base_url}/get_provider_presets"),
      "stream_check_all_providers_url": Json::string(
        "\{base_url}/stream_check_all_providers",
      ),
      "env": Json::object({
        "OPENAI_BASE_URL": Json::string(openai_base_url),
        "ANTHROPIC_BASE_URL": Json::string(anthropic_base_url),
      }),
    }),
    "moonbook": Json::object({
      "role": Json::string("durable-usage-output"),
      "usage_summary_url": Json::string("\{base_url}/usage/summary"),
      "usage_logs_url": Json::string("\{base_url}/usage/logs"),
      "usage_trends_url": Json::string("\{base_url}/usage/trends"),
      "usage_data_sources_url": Json::string("\{base_url}/usage/data-sources"),
      "usage_request_logs_file": Json::string(
        @pathx.join(default_moonstat_stats_dir(), MOONSTAT_REQUEST_LOGS_FILE),
      ),
      "usage_model_pricing_file": Json::string(
        @pathx.join(default_moonstat_stats_dir(), MOONSTAT_MODEL_PRICING_FILE),
      ),
    }),
    "moontown": Json::object({
      "role": Json::string("scheduler-network-watch"),
      "health_url": Json::string("\{base_url}/health"),
      "status_url": Json::string("\{base_url}/status"),
      "stats_url": Json::string("\{base_url}/stats"),
      "stream_check_all_providers_url": Json::string(
        "\{base_url}/stream_check_all_providers",
      ),
      "usage_provider_limits_url": Json::string(
        "\{base_url}/usage/provider-limits",
      ),
      "suite_status_file": Json::string(default_moonstat_suite_status_path()),
    }),
    "moondesk": Json::object({
      "role": Json::string("operator-dashboard"),
      "suite_status_file": Json::string(default_moonstat_suite_status_path()),
      "health_url": Json::string("\{base_url}/health"),
      "status_url": Json::string("\{base_url}/status"),
      "stats_url": Json::string("\{base_url}/stats"),
      "models_url": Json::string("\{openai_base_url}/models"),
      "provider_presets_url": Json::string("\{base_url}/get_provider_presets"),
      "claude_desktop_base_url": Json::string(claude_desktop_base_url),
      "stream_check_provider_url": Json::string(
        "\{base_url}/stream_check_provider",
      ),
      "stream_check_all_providers_url": Json::string(
        "\{base_url}/stream_check_all_providers",
      ),
      "stream_check_config_url": Json::string(
        "\{base_url}/get_stream_check_config",
      ),
      "config_status_url": Json::string("\{base_url}/get_config_status"),
    }),
  })
}

///|
fn moonstat_suite_capabilities() -> Array[String] {
  [
    "openai-compatible-proxy", "anthropic-compatible-proxy", "claude-desktop-gateway",
    "gemini-compatible-proxy", "ccs-usage-statistics", "ccs-stream-check", "session-usage-sync",
    "provider-model-catalog", "provider-presets", "ccs-skills-management", "suite-discovery",
    "codex-config-install",
  ]
}

///|
fn moonstat_suite_commands_json(port : Int, model : String) -> Json {
  Json::object({
    "start": Json::string("moonstat start --port \{port}"),
    "health": Json::string("moonstat health"),
    "status": Json::string("moonstat status"),
    "stats": Json::string("moonstat stats"),
    "usage_logs": Json::string("moonstat usage logs"),
    "usage_summary": Json::string("moonstat usage summary"),
    "usage_apps": Json::string("moonstat usage apps"),
    "usage_trends": Json::string("moonstat usage trends"),
    "usage_limits": Json::string(
      "moonstat usage limits --provider-id <provider_id> --app-type <app_type>",
    ),
    "usage_providers": Json::string("moonstat usage providers"),
    "usage_models": Json::string("moonstat usage models"),
    "usage_sources": Json::string("moonstat usage sources"),
    "usage_sync": Json::string("moonstat usage sync"),
    "usage_pricing": Json::string("moonstat usage pricing"),
    "usage_detail": Json::string(
      "moonstat usage detail --request-id <request_id>",
    ),
    "provider_presets": Json::string(
      "moonstat provider presets list --app <app_type>",
    ),
    "stream_check_provider": Json::string(
      "moonstat stream-check provider --app-type <app_type> --provider-id <provider_id>",
    ),
    "stream_check_all": Json::string(
      "moonstat stream-check all --app-type <app_type>",
    ),
    "stream_check_config": Json::string("moonstat stream-check config"),
    "stream_check_config_set": Json::string(
      "moonstat stream-check config set --timeout-secs <seconds>",
    ),
    "codex_install": Json::string(
      "moonstat codex install --port \{port} --model \{model}",
    ),
    "copilot_auth_status": Json::string("moonstat copilot status"),
    "copilot_start_device_flow": Json::string(
      "moonstat copilot start-device-flow",
    ),
    "claude_desktop_install": Json::string(
      "moonstat claude-desktop install --port \{port}",
    ),
    "skills_list": Json::string("moonstat get_installed_skills"),
    "skills_search": Json::string("moonstat search_skills_sh --query <query>"),
    "skills_install": Json::string(
      "moonstat install_skill_unified --directory <directory> --app <app>",
    ),
    "skills_repos": Json::string("moonstat get_skill_repos"),
    "suite_manifest": Json::string("moonstat suite manifest"),
    "suite_status": Json::string("moonstat suite status"),
    "suite_write_status": Json::string("moonstat suite write-status"),
  })
}

///|
fn moonstat_suite_routes() -> Array[String] {
  [
    "GET /participant/register", "GET /health", "GET /status", "GET /stats", "GET /usage/logs",
    "GET /models", "GET /usage/summary", "GET /usage/summary/by-app", "GET /usage/provider-stats",
    "GET /usage/trends", "GET /usage/provider-limits", "GET /usage/model-stats",
    "GET|POST /usage/data-sources", "POST /usage/sync-session", "GET /usage/model-pricing",
    "POST /usage/model-pricing", "DELETE /usage/model-pricing", "GET /usage/request-detail/{request_id}",
    "GET|POST /get_usage_summary", "GET|POST /get_usage_summary_by_app", "GET|POST /get_usage_trends",
    "GET|POST /get_provider_stats", "GET|POST /get_model_stats", "GET|POST /get_request_logs",
    "GET|POST /get_request_detail", "GET /get_model_pricing", "POST /update_model_pricing",
    "DELETE|POST /delete_model_pricing", "GET|POST /check_provider_limits", "POST /sync_session_usage",
    "GET|POST /get_usage_data_sources", "GET|POST /queryProviderUsage", "GET|POST /get_balance",
    "GET|POST /get_subscription_quota", "GET|POST /get_codex_oauth_quota", "GET|POST /get_codex_oauth_models",
    "GET|POST /get_coding_plan_quota", "POST /testUsageScript", "GET|POST /stream_check_provider",
    "GET|POST /stream_check_all_providers", "GET /get_stream_check_config", "POST /save_stream_check_config",
    "GET /get_provider_presets", "GET /v1/models", "GET /claude-desktop/v1/models",
    "POST /v1/messages", "POST /claude/v1/messages", "POST /claude-desktop/v1/messages",
    "POST /responses", "POST /v1/responses", "POST /v1/v1/responses", "POST /codex/v1/responses",
    "POST /responses/compact", "POST /v1/responses/compact", "POST /v1/v1/responses/compact",
    "POST /codex/v1/responses/compact", "POST /chat/completions", "POST /v1/chat/completions",
    "POST /v1/v1/chat/completions", "POST /codex/v1/chat/completions", "POST /login",
    "GET /auth_get_status", "GET /auth_list_accounts", "POST /auth_start_login",
    "POST /auth_poll_for_account", "POST /auth_remove_account", "POST /auth_set_default_account",
    "POST /auth_logout", "GET /copilot_get_auth_status", "GET /copilot_list_accounts",
    "GET /copilot_is_authenticated", "POST /copilot_start_device_flow", "POST /copilot_poll_for_auth",
    "POST /copilot_poll_for_account", "POST /copilot_logout", "DELETE /copilot_remove_account",
    "POST /copilot_set_default_account", "GET /copilot_get_token", "GET /copilot_get_token_for_account",
    "GET /copilot_get_models", "GET /copilot_get_models_for_account", "GET /copilot_get_usage",
    "GET /copilot_get_usage_for_account", "GET|POST /open_external", "GET|POST /copy_text_to_clipboard",
    "GET|POST /check_for_updates", "GET /is_portable_mode", "GET /get_init_error",
    "GET /get_migration_result", "GET /get_skills_migration_result", "GET|POST /get_tool_versions",
    "POST /run_tool_lifecycle_action", "GET|POST /probe_tool_installations", "GET|POST /set_window_theme",
    "GET|POST /enter_lightweight_mode", "GET|POST /exit_lightweight_mode", "GET /is_lightweight_mode",
    "GET|POST /save_file_dialog", "GET|POST /export_config_to_file", "GET|POST /import_config_from_file",
    "POST /create_db_backup", "GET /list_db_backups", "POST /restore_db_backup",
    "POST /rename_db_backup", "DELETE|POST /delete_db_backup", "GET|POST /parse_deeplink",
    "GET|POST /merge_deeplink_config", "POST /import_from_deeplink", "POST /import_from_deeplink_unified",
    "POST /webdav_test_connection", "POST /webdav_sync_upload", "POST /webdav_sync_download",
    "POST /webdav_sync_save_settings", "GET /webdav_sync_fetch_remote_info", "POST /s3_test_connection",
    "POST /s3_sync_upload", "POST /s3_sync_download", "POST /s3_sync_save_settings",
    "GET /s3_sync_fetch_remote_info", "GET|POST /list_sessions", "GET|POST /get_session_messages",
    "POST /launch_session_terminal", "POST /delete_session", "POST /delete_sessions",
    "GET|POST /read_omo_local_file", "GET|POST /get_current_omo_provider_id", "POST /disable_current_omo",
    "GET|POST /read_omo_slim_local_file", "GET|POST /get_current_omo_slim_provider_id",
    "POST /disable_current_omo_slim", "GET|POST /open_file_dialog", "GET|POST /open_zip_file_dialog",
    "GET /get_installed_skills", "GET /get_skill_backups", "POST /delete_skill_backup",
    "POST /restore_skill_backup", "POST /install_skill_unified", "POST /uninstall_skill_unified",
    "POST /toggle_skill_app", "GET /scan_unmanaged_skills", "POST /import_skills_from_apps",
    "GET /discover_available_skills", "GET /check_skill_updates", "POST /update_skill",
    "POST /migrate_skill_storage", "GET|POST /search_skills_sh", "GET /get_skills",
    "GET /get_skills_for_app", "POST /install_skill", "POST /install_skill_for_app",
    "POST /uninstall_skill", "POST /uninstall_skill_for_app", "GET /get_skill_repos",
    "POST /add_skill_repo", "POST /remove_skill_repo", "POST /install_skills_from_zip",
    "GET /get_proxy_status", "GET /get_proxy_config", "POST /update_proxy_config",
    "GET /get_global_proxy_config", "POST /update_global_proxy_config", "GET /get_proxy_config_for_app",
    "POST /update_proxy_config_for_app", "GET /get_proxy_takeover_status", "POST /set_proxy_takeover_for_app",
    "GET /get_default_cost_multiplier", "GET /get_pricing_model_source", "GET /get_default_cost_multiplier_test_hook",
    "POST /set_default_cost_multiplier_test_hook", "GET /get_pricing_model_source_test_hook",
    "POST /set_pricing_model_source_test_hook", "POST /switch_provider_test_hook",
    "POST /import_default_config", "DELETE|POST /delete_provider", "DELETE|POST /remove_provider_from_live_config",
    "DELETE|POST /remove_custom_endpoint", "POST /open_provider_terminal", "GET /get_claude_config_status",
    "GET /get_config_status", "GET /get_claude_desktop_status", "GET /get_claude_desktop_default_routes",
    "POST /import_claude_desktop_providers_from_claude", "POST /ensure_claude_desktop_official_provider",
    "ANY /v1beta/*path", "ANY /gemini/v1beta/*path", "ANY /gemini/v1/*path",
  ]
}
