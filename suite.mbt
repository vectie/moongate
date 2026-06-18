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
      "\{moonstat_base_url(host, port)}/config/status",
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
      "\{moonstat_base_url(host, port)}/config/status",
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
      "config_status_url": Json::string("\{base_url}/config/status"),
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
    "update_tray_menu": Json::string("moonstat runtime tray-menu update"),
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
    "GET /copilot/token", "GET /copilot/models", "GET /copilot/usage", "GET|POST /runtime/open-external",
    "GET|POST /runtime/clipboard/text", "GET|POST /runtime/updates/check", "GET|POST /runtime/tray-menu/update",
    "GET /runtime/portable-mode", "GET /runtime/init-error", "GET /runtime/migration-result",
    "GET /runtime/skills-migration-result", "GET|POST /tools/versions", "POST /tools/lifecycle-action",
    "GET|POST /tools/probe", "GET|POST /runtime/window-theme", "GET|POST /runtime/lightweight-mode/enter",
    "GET|POST /runtime/lightweight-mode/exit", "GET /runtime/lightweight-mode", "GET|POST /files/dialogs/save",
    "GET|POST /config/files/export", "GET|POST /config/files/import", "POST /backups/db",
    "GET /backups/db", "POST /backups/db/restore", "POST /backups/db/rename", "DELETE|POST /backups/db/delete",
    "GET|POST /deeplinks/parse", "GET|POST /deeplinks/merge", "POST /deeplinks/import",
    "POST /deeplinks/import-unified", "POST /sync/webdav/test", "POST /sync/webdav/upload",
    "POST /sync/webdav/download", "POST /sync/webdav/settings", "GET /sync/webdav/remote-info",
    "POST /sync/s3/test", "POST /sync/s3/upload", "POST /sync/s3/download", "POST /sync/s3/settings",
    "GET /sync/s3/remote-info", "GET|POST /sessions", "GET|POST /sessions/messages",
    "POST /sessions/terminal", "POST /sessions/delete", "POST /sessions/delete-many",
    "GET|POST /providers/omo/file", "GET|POST /providers/omo/current", "POST /providers/omo/disable",
    "GET|POST /providers/omo-slim/file", "GET|POST /providers/omo-slim/current",
    "POST /providers/omo-slim/disable", "GET|POST /files/dialogs/open", "GET|POST /files/dialogs/open-zip",
    "GET /skills/installed", "GET /skills/backups", "POST /skills/backups/delete",
    "POST /skills/backups/restore", "POST /skills/install-unified", "POST /skills/uninstall-unified",
    "POST /skills/toggle-app", "GET /skills/unmanaged", "POST /skills/import-apps",
    "GET /skills/discover", "GET /skills/updates", "POST /skills/update", "POST /skills/migrate-storage",
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
    "POST /providers/endpoints/touch", "GET /config/claude/status", "GET|POST /config/status",
    "GET /providers/claude-desktop/status", "GET /providers/claude-desktop/default-routes",
    "POST /providers/claude-desktop/import", "POST /providers/claude-desktop/official",
    "GET /config/claude-code/path", "GET|POST /config/dir", "GET|POST /config/folder/open",
    "GET|POST /files/directories/pick", "GET /config/app-path", "GET /config/app-folder/open",
    "GET /config/snippets/claude", "POST /config/snippets/claude", "GET /config/snippets",
    "POST /config/snippets", "GET|POST /config/snippets/extract", "GET|POST /config/env/conflicts",
    "POST /config/env/delete", "POST /config/env/restore", "GET /mcp/claude/status",
    "GET /mcp/claude/config", "POST /mcp/claude/servers", "DELETE /mcp/claude/servers",
    "GET|POST /mcp/validate", "GET|POST /mcp/config", "POST /mcp/config/servers",
    "DELETE /mcp/config/servers", "POST /mcp/enabled", "GET /mcp/servers", "POST /mcp/servers",
    "DELETE /mcp/servers", "POST /mcp/apps/toggle", "POST /mcp/import-apps", "GET /prompts",
    "POST /prompts", "DELETE /prompts", "POST /prompts/enable", "POST /prompts/import-file",
    "GET /prompts/current-file", "GET /settings", "POST /settings", "POST /runtime/restart",
    "POST /runtime/updates/install-restart", "GET /settings/app-config-dir", "POST /settings/app-config-dir",
    "POST /settings/auto-launch", "GET /settings/auto-launch", "GET /settings/rectifier",
    "POST /settings/rectifier", "GET /settings/optimizer", "POST /settings/optimizer",
    "GET /settings/copilot-optimizer", "POST /settings/copilot-optimizer", "GET /settings/log",
    "POST /settings/log", "GET /plugin/claude/status", "GET /plugin/claude/config",
    "POST /plugin/claude/config", "GET /plugin/claude/applied", "POST /plugin/claude/onboarding-skip",
    "POST /plugin/claude/onboarding-skip/clear", "GET /workspace/memory", "GET|POST /workspace/memory/file",
    "POST /workspace/memory/write", "GET|POST /workspace/memory/search", "POST /workspace/memory/delete",
    "DELETE /workspace/memory/file", "GET /workspace/files", "POST /workspace/files/read",
    "POST /workspace/files", "GET|POST /workspace/open", "GET /openclaw/config-health",
    "GET /openclaw/default-model", "POST /openclaw/default-model", "GET /openclaw/model-catalog",
    "POST /openclaw/model-catalog", "GET /openclaw/agents-defaults", "POST /openclaw/agents-defaults",
    "GET /openclaw/env", "POST /openclaw/env", "GET /openclaw/tools", "POST /openclaw/tools",
    "GET /hermes/model-config", "GET /hermes/memory", "POST /hermes/memory", "GET /hermes/memory-limits",
    "POST /hermes/memory-enabled", "GET|POST /hermes/web-ui", "POST /hermes/dashboard",
    "GET|POST /config/models", "ANY /v1beta/*path", "ANY /gemini/v1beta/*path", "ANY /gemini/v1/*path",
  ]
}
