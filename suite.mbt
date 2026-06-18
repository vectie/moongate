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
    "metrics_url": Json::string("\{moonstat_base_url(host, port)}/metrics"),
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
      "\{moonstat_base_url(host, port)}/providers/presets",
    ),
    "usage_request_detail_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/request-detail/{request_id}",
    ),
    "stream_check_provider_url": Json::string(
      "\{moonstat_base_url(host, port)}/proxy/stream-check/provider",
    ),
    "stream_check_all_providers_url": Json::string(
      "\{moonstat_base_url(host, port)}/proxy/stream-check/all",
    ),
    "stream_check_config_url": Json::string(
      "\{moonstat_base_url(host, port)}/proxy/stream-check/config",
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
  status? : String = "configured",
  ready? : Bool = true,
) -> Json {
  {
    "contract": Json::string("moon.suite.status.v1"),
    "service": Json::string("moonstat"),
    "status": Json::string(status),
    "ready": Json::boolean(ready),
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
    "metrics_url": Json::string("\{moonstat_base_url(host, port)}/metrics"),
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
      "\{moonstat_base_url(host, port)}/providers/presets",
    ),
    "usage_request_detail_url": Json::string(
      "\{moonstat_base_url(host, port)}/usage/request-detail/{request_id}",
    ),
    "stream_check_provider_url": Json::string(
      "\{moonstat_base_url(host, port)}/proxy/stream-check/provider",
    ),
    "stream_check_all_providers_url": Json::string(
      "\{moonstat_base_url(host, port)}/proxy/stream-check/all",
    ),
    "stream_check_config_url": Json::string(
      "\{moonstat_base_url(host, port)}/proxy/stream-check/config",
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
  status? : String = "configured",
  ready? : Bool = true,
) -> String {
  let dir = @pathx.dirname(path)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  let json = moonstat_suite_status_json(host~, port~, model~, status~, ready~).stringify(
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
  @pathx.join(home, ".moonsuite")
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
      "moonclaw_model_config": moonclaw_model_config_json(
        openai_base_url, model,
      ),
      "moonclaw_models_json": Json::array([
        moonclaw_model_config_json(openai_base_url, model),
      ]),
      "moonclaw_models_path_candidates": Json::array([
        Json::string(".moonclaw/models/models.json"),
        Json::string("~/.moonclaw/models/models.json"),
      ]),
      "moonclaw_provider_name": Json::string("moonstat"),
      "moonclaw_provider_model_id": Json::string(model),
      "moonclaw_provider_config_paths": Json::array([
        Json::string(".moonclaw/models/models.json"),
        Json::string("~/.moonclaw/models/models.json"),
        Json::string(".moonclaw/config.json"),
        Json::string("~/.moonclaw/config.json"),
      ]),
      "moonclaw_providers_file_json": moonclaw_providers_file_json(
        openai_base_url, model,
      ),
      "moonclaw_providers_file_command": Json::string(
        "moonstat suite moonclaw-providers",
      ),
      "moonclaw_providers_file_write_command": Json::string(
        "moonstat suite write-moonclaw-providers --path .moonclaw/providers.json",
      ),
      "health_url": Json::string("\{base_url}/health"),
      "metrics_url": Json::string("\{base_url}/metrics"),
      "usage_summary_url": Json::string("\{base_url}/usage/summary"),
      "usage_logs_url": Json::string("\{base_url}/usage/logs"),
      "provider_presets_url": Json::string("\{base_url}/providers/presets"),
      "stream_check_all_providers_url": Json::string(
        "\{base_url}/proxy/stream-check/all",
      ),
      "env": Json::object({
        "OPENAI_BASE_URL": Json::string(openai_base_url),
        "ANTHROPIC_BASE_URL": Json::string(anthropic_base_url),
        "OPENAI_API_KEY": Json::string("moonstat-local"),
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
      "cli": Json::string("moonstat"),
      "moondesk_adapter_package": Json::string(
        "vectie/moondesk/adapters/moonbook",
      ),
      "moontown_adapter_package": Json::string(
        "vectie/moontown/adapters/moonbook",
      ),
    }),
    "moontown": Json::object({
      "role": Json::string("scheduler-network-watch"),
      "health_url": Json::string("\{base_url}/health"),
      "status_url": Json::string("\{base_url}/status"),
      "stats_url": Json::string("\{base_url}/stats"),
      "metrics_url": Json::string("\{base_url}/metrics"),
      "stream_check_all_providers_url": Json::string(
        "\{base_url}/proxy/stream-check/all",
      ),
      "usage_provider_limits_url": Json::string(
        "\{base_url}/usage/provider-limits",
      ),
      "suite_status_file": Json::string(default_moonstat_suite_status_path()),
      "moonclaw_provider_manifest_path": Json::string(
        ".moonclaw/providers.json",
      ),
      "moonclaw_provider_manifest_command": Json::string("moonstat"),
      "moonclaw_provider_manifest_args": Json::array([
        Json::string("suite"),
        Json::string("write-moonclaw-providers"),
        Json::string("--path"),
        Json::string(".moonclaw/providers.json"),
      ]),
      "moonclaw_provider_manifest_full_command": Json::string(
        "moonstat suite write-moonclaw-providers --path .moonclaw/providers.json",
      ),
      "moonclaw_provider_manifest_target": Json::string("moonbook"),
      "moonbook_provider_manifest_path": Json::string(
        ".moonclaw/providers.json",
      ),
      "moonbook_provider_manifest_command": Json::string("moonstat"),
      "moonbook_provider_manifest_args": Json::array([
        Json::string("suite"),
        Json::string("write-moonclaw-providers"),
        Json::string("--path"),
        Json::string(".moonclaw/providers.json"),
      ]),
      "moonbook_provider_manifest_full_command": Json::string(
        "moonstat suite write-moonclaw-providers --path .moonclaw/providers.json",
      ),
      "adapter_packages": Json::array([
        Json::string("vectie/moontown/adapters/moonclaw"),
        Json::string("vectie/moontown/adapters/moonbook"),
      ]),
    }),
    "moondesk": Json::object({
      "role": Json::string("operator-dashboard"),
      "suite_status_file": Json::string(default_moonstat_suite_status_path()),
      "health_url": Json::string("\{base_url}/health"),
      "status_url": Json::string("\{base_url}/status"),
      "stats_url": Json::string("\{base_url}/stats"),
      "metrics_url": Json::string("\{base_url}/metrics"),
      "models_url": Json::string("\{openai_base_url}/models"),
      "provider_presets_url": Json::string("\{base_url}/providers/presets"),
      "claude_desktop_base_url": Json::string(claude_desktop_base_url),
      "stream_check_provider_url": Json::string(
        "\{base_url}/proxy/stream-check/provider",
      ),
      "stream_check_all_providers_url": Json::string(
        "\{base_url}/proxy/stream-check/all",
      ),
      "stream_check_config_url": Json::string(
        "\{base_url}/proxy/stream-check/config",
      ),
      "config_status_url": Json::string("\{base_url}/get_config_status"),
      "adapter_packages": Json::array([
        Json::string("vectie/moondesk/adapters/moonclaw"),
        Json::string("vectie/moondesk/adapters/moonbook"),
        Json::string("vectie/moondesk/adapters/moontown"),
      ]),
    }),
  })
}

///|
fn moonclaw_providers_file_json(
  openai_base_url : String,
  model : String,
) -> Json {
  Json::object({
    "providers": Json::object({
      "moonstat": Json::object({
        "baseUrl": Json::string(openai_base_url),
        "api": Json::string("openai"),
        "apiKey": Json::string("moonstat-local"),
        "models": Json::array([
          Json::object({
            "id": Json::string(model),
            "name": Json::string("moonstat/\{model}"),
            "reasoning": Json::boolean(true),
            "input": Json::array([Json::string("text"), Json::string("image")]),
          }),
        ]),
      }),
    }),
  })
}

///|
pub fn moonstat_moonclaw_providers_file_json(
  host? : String = "127.0.0.1",
  port? : Int = 15721,
  model? : String = "gpt-5",
) -> Json {
  moonclaw_providers_file_json(moonstat_openai_base_url(host, port), model)
}

///|
pub async fn write_moonstat_moonclaw_providers_file(
  path? : String = default_moonstat_moonclaw_providers_file_path(),
  host? : String = "127.0.0.1",
  port? : Int = 15721,
  model? : String = "gpt-5",
) -> String {
  let dir = @pathx.dirname(path)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  let json = moonstat_moonclaw_providers_file_json(host~, port~, model~).stringify(
    indent=2,
  )
  @fsx.write_to_file(path, json)
  path
}

///|
pub fn default_moonstat_moonclaw_providers_file_path() -> String {
  ".moonclaw/providers.json"
}

///|
fn moonclaw_model_config_json(openai_base_url : String, model : String) -> Json {
  Json::object({
    "name": Json::string("moonstat/\{model}"),
    "description": Json::string(
      "Moonstat local OpenAI-compatible proxy model for the Moon suite.",
    ),
    "model_name": Json::string(model),
    "model_type": Json::string("saas/openai"),
    "api_key": Json::string("moonstat-local"),
    "base_url": Json::string(openai_base_url),
    "safe_zone_tokens": Json::number(200000.0),
  })
}

///|
fn moonstat_suite_capabilities() -> Array[String] {
  [
    "openai-compatible-proxy", "anthropic-compatible-proxy", "claude-desktop-gateway",
    "gemini-compatible-proxy", "moonstat-usage-statistics", "moonstat-stream-check",
    "session-usage-sync", "provider-model-catalog", "provider-presets", "moonstat-skills-management",
    "suite-discovery", "codex-config-install",
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
    "copilot_login": Json::string("moonstat copilot login"),
    "claude_desktop_install": Json::string(
      "moonstat claude-desktop install --port \{port}",
    ),
    "skills_list": Json::string("moonstat skills installed"),
    "skills_search": Json::string("moonstat skills search --query <query>"),
    "skills_install": Json::string(
      "moonstat skills install-unified --directory <directory> --app <app>",
    ),
    "skills_repos": Json::string("moonstat skills repos"),
    "update_tray_menu": Json::string("moonstat update_tray_menu"),
    "suite_manifest": Json::string("moonstat suite manifest"),
    "suite_status": Json::string("moonstat suite status"),
    "suite_write_status": Json::string("moonstat suite write-status"),
    "moonclaw_providers": Json::string("moonstat suite moonclaw-providers"),
    "moonclaw_providers_write": Json::string(
      "moonstat suite write-moonclaw-providers --path .moonclaw/providers.json",
    ),
  })
}

///|
fn moonstat_suite_routes() -> Array[String] {
  [
    "GET /participant/register", "GET /health", "GET /status", "GET /stats", "GET /metrics",
    "GET|POST /usage/logs", "GET /models", "GET|POST /usage/summary", "GET|POST /usage/summary/by-app",
    "GET|POST /usage/provider-stats", "GET|POST /usage/trends", "GET|POST /usage/provider-limits",
    "GET|POST /usage/model-stats", "GET|POST /usage/data-sources", "POST /usage/sync-session",
    "GET /usage/model-pricing", "POST /usage/model-pricing", "DELETE /usage/model-pricing",
    "GET /usage/request-detail/*path", "GET|POST /usage/provider-usage", "GET|POST /usage/balance",
    "GET|POST /usage/subscription-quota", "GET|POST /usage/codex-oauth-quota", "GET|POST /usage/codex-oauth-models",
    "GET|POST /usage/coding-plan-quota", "POST /usage/test-script", "GET|POST /proxy/stream-check/provider",
    "GET|POST /proxy/stream-check/all", "GET /proxy/stream-check/config", "POST /proxy/stream-check/config",
    "GET /providers/presets", "GET /v1/models", "GET /claude-desktop/v1/models",
    "POST /v1/messages", "POST /claude/v1/messages", "POST /claude-desktop/v1/messages",
    "POST /responses", "POST /v1/responses", "POST /v1/v1/responses", "POST /codex/v1/responses",
    "POST /responses/compact", "POST /v1/responses/compact", "POST /v1/v1/responses/compact",
    "POST /codex/v1/responses/compact", "POST /chat/completions", "POST /v1/chat/completions",
    "POST /v1/v1/chat/completions", "POST /codex/v1/chat/completions", "POST /login",
    "GET|POST /auth/status", "GET|POST /auth/accounts", "GET|POST /auth/login", "GET|POST /auth/poll",
    "DELETE|POST /auth/account", "GET|POST /auth/default-account", "GET|POST /auth/logout",
    "GET /copilot/status", "GET /copilot/accounts", "GET /copilot/authenticated",
    "GET|POST /copilot/device-flow", "GET|POST /copilot/poll-auth", "GET|POST /copilot/poll-account",
    "GET|POST /copilot/logout", "DELETE|POST /copilot/account", "GET|POST /copilot/default-account",
    "GET /copilot/token", "GET /copilot/models", "GET /copilot/usage", "GET|POST /open_external",
    "GET|POST /copy_text_to_clipboard", "GET|POST /check_for_updates", "GET|POST /update_tray_menu",
    "GET /is_portable_mode", "GET /get_init_error", "GET /get_migration_result",
    "GET /get_skills_migration_result", "GET|POST /get_tool_versions", "POST /run_tool_lifecycle_action",
    "GET|POST /probe_tool_installations", "GET|POST /set_window_theme", "GET|POST /enter_lightweight_mode",
    "GET|POST /exit_lightweight_mode", "GET /is_lightweight_mode", "GET|POST /save_file_dialog",
    "GET|POST /export_config_to_file", "GET|POST /import_config_from_file", "POST /create_db_backup",
    "GET /list_db_backups", "POST /restore_db_backup", "POST /rename_db_backup",
    "DELETE|POST /delete_db_backup", "GET|POST /parse_deeplink", "GET|POST /merge_deeplink_config",
    "POST /import_from_deeplink", "POST /import_from_deeplink_unified", "POST /webdav_test_connection",
    "POST /webdav_sync_upload", "POST /webdav_sync_download", "POST /webdav_sync_save_settings",
    "GET /webdav_sync_fetch_remote_info", "POST /s3_test_connection", "POST /s3_sync_upload",
    "POST /s3_sync_download", "POST /s3_sync_save_settings", "GET /s3_sync_fetch_remote_info",
    "GET|POST /list_sessions", "GET|POST /get_session_messages", "POST /launch_session_terminal",
    "POST /delete_session", "POST /delete_sessions", "GET|POST /read_omo_local_file",
    "GET|POST /get_current_omo_provider_id", "POST /disable_current_omo", "GET|POST /read_omo_slim_local_file",
    "GET|POST /get_current_omo_slim_provider_id", "POST /disable_current_omo_slim",
    "GET|POST /open_file_dialog", "GET|POST /open_zip_file_dialog", "GET /skills/installed",
    "GET /skills/backups", "POST /skills/backups/delete", "POST /skills/backups/restore",
    "POST /skills/install-unified", "POST /skills/uninstall-unified", "POST /skills/toggle-app",
    "GET /skills/unmanaged", "POST /skills/import-apps", "GET /skills/discover",
    "GET /skills/updates", "POST /skills/update", "POST /skills/migrate-storage",
    "GET|POST /skills/search", "GET /skills", "GET /skills/app", "POST /skills/install",
    "POST /skills/install-for-app", "POST /skills/uninstall", "POST /skills/uninstall-for-app",
    "GET /skills/repos", "POST /skills/repos", "POST /skills/repos/remove", "POST /skills/install-zip",
    "GET /proxy/status", "POST /proxy/start", "POST /proxy/stop", "POST /proxy/stop-with-restore",
    "GET|POST /proxy/config", "GET|POST /proxy/global-config", "GET|POST /proxy/global-url",
    "GET|POST /proxy/test-url", "GET /proxy/upstream-status", "GET /proxy/local-proxies",
    "GET|POST /proxy/app-config", "GET|POST /proxy/default-cost-multiplier", "GET|POST /proxy/pricing-model-source",
    "GET /proxy/provider-health", "GET|POST /proxy/circuit-breaker-config", "GET /proxy/circuit-breaker-stats",
    "POST /proxy/reset-circuit-breaker", "GET|POST|DELETE /proxy/failover-queue",
    "GET /proxy/available-failover-providers", "GET|POST /proxy/auto-failover-enabled",
    "GET|POST /proxy/takeover-status", "GET /proxy/running", "POST /proxy/switch-provider",
    "POST /proxy/sync-current-providers-live", "POST /proxy/import-default-config",
    "GET /providers", "GET|POST /providers/current", "POST /providers", "POST /providers/update",
    "DELETE /providers", "POST /providers/delete", "DELETE /providers/live", "POST /providers/live/remove",
    "POST /providers/switch", "GET|POST /providers/live-settings", "POST /providers/terminal",
    "GET /providers/live-ids", "GET|POST /providers/live-provider", "POST /providers/import-live",
    "GET /providers/universal", "GET /providers/universal/item", "POST /providers/universal",
    "DELETE /providers/universal", "POST /providers/universal/delete", "POST /providers/universal/sync",
    "GET|POST /providers/test-endpoints", "POST /providers/sort-order", "GET|POST /providers/endpoints/list",
    "POST /providers/endpoints", "DELETE /providers/endpoints", "POST /providers/endpoints/remove",
    "POST /providers/endpoints/touch", "GET /get_claude_config_status", "GET|POST /get_config_status",
    "GET /get_claude_desktop_status", "GET /get_claude_desktop_default_routes", "POST /import_claude_desktop_providers_from_claude",
    "POST /ensure_claude_desktop_official_provider", "GET /get_claude_code_config_path",
    "GET|POST /get_config_dir", "GET|POST /open_config_folder", "GET|POST /pick_directory",
    "GET /get_app_config_path", "GET /open_app_config_folder", "GET /get_claude_common_config_snippet",
    "POST /set_claude_common_config_snippet", "GET|POST /get_common_config_snippet",
    "POST /set_common_config_snippet", "GET|POST /extract_common_config_snippet",
    "GET|POST /check_env_conflicts", "POST /delete_env_vars", "POST /restore_env_backup",
    "GET /get_claude_mcp_status", "GET /read_claude_mcp_config", "POST /upsert_claude_mcp_server",
    "POST|DELETE /delete_claude_mcp_server", "GET|POST /validate_mcp_command", "GET|POST /get_mcp_config",
    "POST /upsert_mcp_server_in_config", "POST|DELETE /delete_mcp_server_in_config",
    "POST /set_mcp_enabled", "GET /get_mcp_servers", "POST /upsert_mcp_server", "POST|DELETE /delete_mcp_server",
    "POST /toggle_mcp_app", "POST /import_mcp_from_apps", "GET|POST /get_prompts",
    "POST /upsert_prompt", "POST|DELETE /delete_prompt", "POST /enable_prompt", "POST /import_prompt_from_file",
    "GET|POST /get_current_prompt_file_content", "GET /get_settings", "POST /save_settings",
    "POST /restart_app", "POST /install_update_and_restart", "GET /get_app_config_dir_override",
    "POST /set_app_config_dir_override", "POST /set_auto_launch", "GET /get_auto_launch_status",
    "GET /get_rectifier_config", "POST /set_rectifier_config", "GET /get_optimizer_config",
    "POST /set_optimizer_config", "GET /get_copilot_optimizer_config", "POST /set_copilot_optimizer_config",
    "GET /get_log_config", "POST /set_log_config", "GET /get_claude_plugin_status",
    "GET /read_claude_plugin_config", "POST /apply_claude_plugin_config", "GET /is_claude_plugin_applied",
    "POST /apply_claude_onboarding_skip", "POST /clear_claude_onboarding_skip", "GET /list_daily_memory_files",
    "GET|POST /read_daily_memory_file", "POST /write_daily_memory_file", "GET|POST /search_daily_memory_files",
    "POST|DELETE /delete_daily_memory_file", "GET|POST /read_workspace_file", "POST /write_workspace_file",
    "GET|POST /open_workspace_directory", "GET /openclaw/config-health", "GET /openclaw/default-model",
    "POST /openclaw/default-model", "GET /openclaw/model-catalog", "POST /openclaw/model-catalog",
    "GET /openclaw/agents-defaults", "POST /openclaw/agents-defaults", "GET /openclaw/env",
    "POST /openclaw/env", "GET /openclaw/tools", "POST /openclaw/tools", "GET /hermes/model-config",
    "GET /hermes/memory", "POST /hermes/memory", "GET /hermes/memory-limits", "POST /hermes/memory-enabled",
    "GET|POST /hermes/web-ui", "POST /hermes/dashboard", "GET|POST /fetch_models_for_config",
    "ANY /v1beta/*path", "ANY /gemini/v1beta/*path", "ANY /gemini/v1/*path",
  ]
}
