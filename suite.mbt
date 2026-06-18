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
      "provider_presets_url": Json::string("\{base_url}/get_provider_presets"),
      "stream_check_all_providers_url": Json::string(
        "\{base_url}/stream_check_all_providers",
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
        "\{base_url}/stream_check_all_providers",
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
    "GET /usage/request-detail/*path", "GET|POST /get_usage_summary", "GET|POST /get_usage_summary_by_app",
    "GET|POST /get_usage_trends", "GET|POST /get_provider_stats", "GET|POST /get_model_stats",
    "GET|POST /get_request_logs", "GET|POST /get_request_detail", "GET /get_model_pricing",
    "POST /update_model_pricing", "DELETE|POST /delete_model_pricing", "GET|POST /check_provider_limits",
    "POST /sync_session_usage", "GET|POST /get_usage_data_sources", "GET|POST /queryProviderUsage",
    "GET|POST /get_balance", "GET|POST /get_subscription_quota", "GET|POST /get_codex_oauth_quota",
    "GET|POST /get_codex_oauth_models", "GET|POST /get_coding_plan_quota", "POST /testUsageScript",
    "GET|POST /stream_check_provider", "GET|POST /stream_check_all_providers", "GET /get_stream_check_config",
    "POST /save_stream_check_config", "GET /get_provider_presets", "GET /v1/models",
    "GET /claude-desktop/v1/models", "POST /v1/messages", "POST /claude/v1/messages",
    "POST /claude-desktop/v1/messages", "POST /responses", "POST /v1/responses",
    "POST /v1/v1/responses", "POST /codex/v1/responses", "POST /responses/compact",
    "POST /v1/responses/compact", "POST /v1/v1/responses/compact", "POST /codex/v1/responses/compact",
    "POST /chat/completions", "POST /v1/chat/completions", "POST /v1/v1/chat/completions",
    "POST /codex/v1/chat/completions", "POST /login", "GET|POST /auth_get_status",
    "GET|POST /auth_list_accounts", "GET|POST /auth_start_login", "GET|POST /auth_poll_for_account",
    "DELETE|POST /auth_remove_account", "GET|POST /auth_set_default_account", "GET|POST /auth_logout",
    "GET /copilot_get_auth_status", "GET /copilot_list_accounts", "GET /copilot_is_authenticated",
    "GET|POST /copilot_start_device_flow", "GET|POST /copilot_poll_for_auth", "GET|POST /copilot_poll_for_account",
    "GET|POST /copilot_logout", "DELETE|POST /copilot_remove_account", "GET|POST /copilot_set_default_account",
    "GET /copilot_get_token", "GET /copilot_get_token_for_account", "GET /copilot_get_models",
    "GET /copilot_get_models_for_account", "GET /copilot_get_usage", "GET /copilot_get_usage_for_account",
    "GET|POST /open_external", "GET|POST /copy_text_to_clipboard", "GET|POST /check_for_updates",
    "GET|POST /update_tray_menu", "GET /is_portable_mode", "GET /get_init_error",
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
    "GET|POST /get_config_status", "GET /get_claude_desktop_status", "GET /get_claude_desktop_default_routes",
    "POST /import_claude_desktop_providers_from_claude", "POST /ensure_claude_desktop_official_provider",
    "GET /get_claude_code_config_path", "GET|POST /get_config_dir", "GET|POST /open_config_folder",
    "GET|POST /pick_directory", "GET /get_app_config_path", "GET /open_app_config_folder",
    "GET /get_claude_common_config_snippet", "POST /set_claude_common_config_snippet",
    "GET|POST /get_common_config_snippet", "POST /set_common_config_snippet", "GET|POST /extract_common_config_snippet",
    "GET|POST /check_env_conflicts", "POST /delete_env_vars", "POST /restore_env_backup",
    "GET /get_claude_mcp_status", "GET /read_claude_mcp_config", "POST /upsert_claude_mcp_server",
    "POST|DELETE /delete_claude_mcp_server", "GET|POST /validate_mcp_command", "GET|POST /get_mcp_config",
    "POST /upsert_mcp_server_in_config", "POST|DELETE /delete_mcp_server_in_config",
    "POST /set_mcp_enabled", "GET /get_mcp_servers", "POST /upsert_mcp_server", "POST|DELETE /delete_mcp_server",
    "POST /toggle_mcp_app", "POST /import_mcp_from_apps", "GET|POST /get_prompts",
    "POST /upsert_prompt", "POST|DELETE /delete_prompt", "POST /enable_prompt", "POST /import_prompt_from_file",
    "GET|POST /get_current_prompt_file_content", "GET /proxy/status", "POST /start_proxy_server",
    "POST /stop_proxy_server", "POST /stop_proxy_with_restore", "GET|POST /proxy/config",
    "GET|POST /proxy/global-config", "GET /get_settings", "POST /save_settings",
    "POST /restart_app", "POST /install_update_and_restart", "GET /get_app_config_dir_override",
    "POST /set_app_config_dir_override", "POST /set_auto_launch", "GET /get_auto_launch_status",
    "GET /get_rectifier_config", "POST /set_rectifier_config", "GET /get_optimizer_config",
    "POST /set_optimizer_config", "GET /get_copilot_optimizer_config", "POST /set_copilot_optimizer_config",
    "GET /get_log_config", "POST /set_log_config", "GET /get_global_proxy_url", "POST /set_global_proxy_url",
    "GET|POST /test_proxy_url", "GET /get_upstream_proxy_status", "GET /scan_local_proxies",
    "GET|POST /proxy/app-config", "GET|POST /proxy/default-cost-multiplier", "POST /set_default_cost_multiplier",
    "GET|POST /proxy/pricing-model-source", "POST /set_pricing_model_source", "GET /proxy/provider-health",
    "GET /get_provider_health", "GET|POST /proxy/circuit-breaker-config", "GET /get_circuit_breaker_config",
    "POST /update_circuit_breaker_config", "GET /proxy/circuit-breaker-stats", "GET /get_circuit_breaker_stats",
    "POST /proxy/reset-circuit-breaker", "POST /reset_circuit_breaker", "GET|POST|DELETE /proxy/failover-queue",
    "GET /get_failover_queue", "POST /add_to_failover_queue", "POST|DELETE /remove_from_failover_queue",
    "GET /proxy/available-failover-providers", "GET /get_available_providers_for_failover",
    "GET|POST /proxy/auto-failover-enabled", "GET /get_auto_failover_enabled", "POST /set_auto_failover_enabled",
    "GET|POST /proxy/takeover-status", "GET /is_live_takeover_active", "POST /switch_proxy_provider",
    "POST /sync_current_providers_live", "POST /import_default_config_test_hook",
    "GET|POST /get_providers", "GET|POST /get_current_provider", "POST /add_provider",
    "POST /update_provider", "POST /switch_provider", "GET|POST /read_live_provider_settings",
    "GET /get_claude_plugin_status", "GET /read_claude_plugin_config", "POST /apply_claude_plugin_config",
    "GET /is_claude_plugin_applied", "POST /apply_claude_onboarding_skip", "POST /clear_claude_onboarding_skip",
    "GET /list_daily_memory_files", "GET|POST /read_daily_memory_file", "POST /write_daily_memory_file",
    "GET|POST /search_daily_memory_files", "POST|DELETE /delete_daily_memory_file",
    "GET|POST /read_workspace_file", "POST /write_workspace_file", "GET|POST /open_workspace_directory",
    "GET /get_opencode_live_provider_ids", "POST /import_opencode_providers_from_live",
    "GET /get_openclaw_live_provider_ids", "POST /import_openclaw_providers_from_live",
    "GET|POST /get_openclaw_live_provider", "GET /scan_openclaw_config_health", "GET /get_openclaw_default_model",
    "POST /set_openclaw_default_model", "GET /get_openclaw_model_catalog", "POST /set_openclaw_model_catalog",
    "GET /get_openclaw_agents_defaults", "POST /set_openclaw_agents_defaults", "GET /get_openclaw_env",
    "POST /set_openclaw_env", "GET /get_openclaw_tools", "POST /set_openclaw_tools",
    "GET /get_hermes_live_provider_ids", "POST /import_hermes_providers_from_live",
    "GET|POST /get_hermes_live_provider", "GET /get_hermes_model_config", "GET|POST /get_hermes_memory",
    "POST /set_hermes_memory", "GET /get_hermes_memory_limits", "POST /set_hermes_memory_enabled",
    "GET|POST /open_hermes_web_ui", "POST /launch_hermes_dashboard", "GET /get_universal_providers",
    "GET /get_universal_provider", "POST /upsert_universal_provider", "POST|DELETE /delete_universal_provider",
    "POST /sync_universal_provider", "GET|POST /test_api_endpoints", "POST /update_providers_sort_order",
    "GET|POST /get_custom_endpoints", "POST /add_custom_endpoint", "POST /update_endpoint_last_used",
    "GET /proxy/running", "GET /is_proxy_running", "GET|POST /fetch_models_for_config",
    "ANY /v1beta/*path", "ANY /gemini/v1beta/*path", "ANY /gemini/v1/*path",
  ]
}
