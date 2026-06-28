///|
const SUITE_STATUS_FILE = "suite-status.json"

///|
pub fn moonstat_suite_manifest_json(
  host? : String = @suite.default_host(),
  port? : Int = @suite.default_port(),
  model? : String = @suite.default_model(),
) -> Json {
  let manifest = {
    "contract": Json::string(@suite.manifest_contract()),
    "service": Json::string(@suite.service_name()),
    "project": Json::string(@suite.project_name()),
    "version": Json::string(@suite.version()),
    "role": Json::string("network-edge"),
    "defaultHost": Json::string(@suite.normalize_host(host)),
    "defaultPort": Json::number(port.to_double()),
    "baseUrl": Json::string(moonstat_base_url(host, port)),
    "openaiBaseUrl": Json::string(moonstat_openai_base_url(host, port)),
    "anthropicBaseUrl": Json::string(moonstat_base_url(host, port)),
    "claudeDesktopBaseUrl": Json::string(
      moonstat_claude_desktop_base_url(host, port),
    ),
    "defaultModel": Json::string(model),
    "statusFile": Json::string(default_moonstat_suite_status_path()),
    "capabilities": moonstat_suite_capabilities_json(),
    "modelsUrl": Json::string("\{moonstat_openai_base_url(host, port)}/models"),
    "routes": Json::array(
      moonstat_suite_routes().map(fn(route) { Json::string(route) }),
    ),
    "frameworkApps": moonstat_framework_apps_json(),
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
    "agentClients": moonstat_suite_agent_clients_json(host, port, model),
    "suiteIntegrations": moonstat_suite_integrations_json(host, port, model),
    "commands": moonstat_suite_commands_json(port, model),
    "cli": moonstat_suite_commands_json(port, model),
  }
  moonstat_merge_suite_fields(
    manifest,
    moonstat_suite_shared_fields(host, port),
  )
  Json::object(manifest)
}

///|
pub fn moonstat_suite_status_json(
  host? : String = @suite.default_host(),
  port? : Int = @suite.default_port(),
  model? : String = @suite.default_model(),
  status? : String = "configured",
  ready? : Bool = true,
) -> Json {
  let status_json = {
    "contract": Json::string(@suite.status_contract()),
    "service": Json::string(@suite.service_name()),
    "status": Json::string(status),
    "ready": Json::boolean(ready),
    "manifest": moonstat_suite_manifest_json(host~, port~, model~),
    "statusPath": Json::string(default_moonstat_suite_status_path()),
  }
  Json::object(status_json)
}

///|
pub async fn write_moonstat_suite_status(
  path? : String = default_moonstat_suite_status_path(),
  host? : String = @suite.default_host(),
  port? : Int = @suite.default_port(),
  model? : String = @suite.default_model(),
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
fn moonstat_suite_capabilities_json() -> Json {
  Json::array(
    moonstat_suite_capabilities().map(fn(capability) {
      Json::string(capability)
    }),
  )
}

///|
fn moonstat_suite_shared_fields(host : String, port : Int) -> Map[String, Json] {
  let base_url = moonstat_base_url(host, port)
  {
    "healthUrl": Json::string("\{base_url}/health"),
    "statusUrl": Json::string("\{base_url}/status"),
    "statsUrl": Json::string("\{base_url}/stats"),
    "metricsUrl": Json::string("\{base_url}/metrics"),
    "dashboardUrl": Json::string("\{base_url}/"),
    "usageLogsUrl": Json::string("\{base_url}/usage/logs"),
    "usageSummaryUrl": Json::string("\{base_url}/usage/summary"),
    "usageSummaryByAppUrl": Json::string("\{base_url}/usage/summary/by-app"),
    "usageTrendsUrl": Json::string("\{base_url}/usage/trends"),
    "usageProviderLimitsUrl": Json::string("\{base_url}/usage/provider-limits"),
    "usageProviderStatsUrl": Json::string("\{base_url}/usage/provider-stats"),
    "usageModelStatsUrl": Json::string("\{base_url}/usage/model-stats"),
    "usageDataSourcesUrl": Json::string("\{base_url}/usage/data-sources"),
    "usageSyncSessionUrl": Json::string("\{base_url}/usage/sync-session"),
    "usageModelPricingUrl": Json::string("\{base_url}/usage/model-pricing"),
    "providerPresetsUrl": Json::string("\{base_url}/providers/presets"),
    "usageRequestDetailUrl": Json::string(
      "\{base_url}/usage/request-detail/{request_id}",
    ),
    "streamCheckProviderUrl": Json::string(
      "\{base_url}/proxy/stream-check/provider",
    ),
    "streamCheckAllProvidersUrl": Json::string(
      "\{base_url}/proxy/stream-check/all",
    ),
    "streamCheckConfigUrl": Json::string(
      "\{base_url}/proxy/stream-check/config",
    ),
    "configStatusUrl": Json::string("\{base_url}/config/status"),
    "usageStoreDir": Json::string(default_moonstat_stats_dir()),
    "usageRequestLogsFile": Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_REQUEST_LOGS_FILE),
    ),
    "usageSessionSyncFile": Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_SESSION_SYNC_FILE),
    ),
    "usageModelPricingFile": Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_MODEL_PRICING_FILE),
    ),
    "usageOpencodeDbFile": Json::string(default_opencode_db_path()),
    "usageOpencodeExportFile": Json::string(default_opencode_export_path()),
  }
}

///|
fn moonstat_merge_suite_fields(
  target : Map[String, Json],
  fields : Map[String, Json],
) -> Unit {
  for key in fields.keys() {
    match fields.get(key) {
      Some(value) => target[key] = value
      None => ()
    }
  }
}

///|
fn moonstat_base_url(host : String, port : Int) -> String {
  @suite.base_url(host, port)
}

///|
fn moonstat_openai_base_url(host : String, port : Int) -> String {
  @suite.openai_base_url(host, port)
}

///|
fn moonstat_claude_desktop_base_url(host : String, port : Int) -> String {
  @suite.claude_desktop_base_url(host, port)
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
pub fn moonstat_framework_apps_json() -> Json {
  Json::array([
    moonstat_framework_app_json("claude", "Claude Code", "single"),
    moonstat_framework_app_json(
      "claude-desktop",
      "Claude Desktop",
      "single",
      desktop=true,
    ),
    moonstat_framework_app_json("codex", "Codex", "single"),
    moonstat_framework_app_json("gemini", "Gemini", "single"),
    moonstat_framework_app_json("opencode", "OpenCode", "additive"),
    moonstat_framework_app_json("openclaw", "OpenClaw", "additive"),
    moonstat_framework_app_json("hermes", "Hermes", "additive"),
  ])
}

///|
fn moonstat_framework_app_json(
  id : String,
  label : String,
  mode : String,
  desktop? : Bool = false,
) -> Json {
  let app = {
    "id": Json::string(id),
    "label": Json::string(label),
    "mode": Json::string(mode),
  }
  if desktop {
    app["desktop"] = Json::boolean(true)
  }
  Json::object(app)
}

///|
fn moonstat_suite_agent_clients_json(
  host : String,
  port : Int,
  model : String,
) -> Json {
  let base_url = moonstat_base_url(host, port)
  let openai_base_url = moonstat_openai_base_url(host, port)
  let claude_desktop_base_url = moonstat_claude_desktop_base_url(host, port)
  Json::array([
    suite_agent_client_json(
      "codex",
      "codex",
      "openai-responses",
      openai_base_url,
      "POST /v1/responses",
      "moonstat codex install --port \{port} --model \{model}",
      "Codex config.toml managed provider block using the Responses API.",
    ),
    suite_agent_client_json(
      "claude-code", "claude", "anthropic-compatible", base_url, "POST /v1/messages",
      "", "Claude Code and Anthropic-compatible clients using Moonstat provider routing.",
    ),
    suite_agent_client_json(
      "claude-desktop",
      "claude-desktop",
      "anthropic-compatible",
      claude_desktop_base_url,
      "POST /claude-desktop/v1/messages",
      "moonstat claude-desktop install --port \{port}",
      "Claude Desktop gateway profile with optional local bearer token.",
    ),
    suite_agent_client_json(
      "openclaw",
      "openclaw",
      "openai-compatible",
      "\{base_url}/openclaw/v1",
      "POST /openclaw/v1/chat/completions",
      "moonstat provider openclaw import-live",
      "OpenClaw chat completions and OpenClaw config/provider management routes.",
    ),
    suite_agent_client_json(
      "opencode", "opencode", "openai-compatible", openai_base_url, "POST /v1/chat/completions",
      "moonstat provider opencode import-live", "OpenCode provider import, proxy routing, and session usage sync.",
    ),
    suite_agent_client_json(
      "gemini",
      "gemini",
      "gemini-compatible",
      "\{base_url}/gemini",
      "ANY /gemini/v1beta/*path",
      "",
      "Gemini-compatible proxy routes with native usage accounting.",
    ),
    suite_agent_client_json(
      "github-copilot", "copilot", "copilot-auth", base_url, "GET /copilot/models",
      "moonstat copilot login", "GitHub Copilot OAuth, model catalog, token, and usage endpoints.",
    ),
    suite_agent_client_json(
      "openai-compatible", "codex", "openai-compatible", openai_base_url, "POST /v1/chat/completions",
      "", "Generic OpenAI-compatible clients using Moonstat as the local provider edge.",
    ),
  ])
}

///|
fn suite_agent_client_json(
  id : String,
  app_type : String,
  protocol : String,
  base_url : String,
  primary_route : String,
  setup_command : String,
  usage : String,
) -> Json {
  Json::object({
    "id": Json::string(id),
    "appType": Json::string(app_type),
    "protocol": Json::string(protocol),
    "baseUrl": Json::string(base_url),
    "primaryRoute": Json::string(primary_route),
    "setupCommand": Json::string(setup_command),
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
      "openaiBaseUrl": Json::string(openai_base_url),
      "anthropicBaseUrl": Json::string(anthropic_base_url),
      "defaultModel": Json::string(model),
      "moonclawModelConfig": moonclaw_model_config_json(openai_base_url, model),
      "moonclawModelsJson": Json::array([
        moonclaw_model_config_json(openai_base_url, model),
      ]),
      "moonclawModelsPathCandidates": Json::array([
        Json::string(".moonclaw/models/models.json"),
        Json::string("~/.moonclaw/models/models.json"),
      ]),
      "moonclawProviderName": Json::string("moonstat"),
      "moonclawProviderModelId": Json::string(model),
      "moonclawProviderConfigPaths": Json::array([
        Json::string(".moonclaw/models/models.json"),
        Json::string("~/.moonclaw/models/models.json"),
        Json::string(".moonclaw/config.json"),
        Json::string("~/.moonclaw/config.json"),
      ]),
      "moonclawProvidersFileJson": moonclaw_providers_file_json(
        openai_base_url, model,
      ),
      "moonclawProvidersFileCommand": Json::string(
        "moonstat suite moonclaw-providers",
      ),
      "moonclawProvidersFileWriteCommand": Json::string(
        "moonstat suite write-moonclaw-providers --path .moonclaw/providers.json",
      ),
      "healthUrl": Json::string("\{base_url}/health"),
      "dashboardUrl": Json::string("\{base_url}/"),
      "metricsUrl": Json::string("\{base_url}/metrics"),
      "usageSummaryUrl": Json::string("\{base_url}/usage/summary"),
      "usageLogsUrl": Json::string("\{base_url}/usage/logs"),
      "providerPresetsUrl": Json::string("\{base_url}/providers/presets"),
      "streamCheckAllProvidersUrl": Json::string(
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
      "usageSummaryUrl": Json::string("\{base_url}/usage/summary"),
      "usageLogsUrl": Json::string("\{base_url}/usage/logs"),
      "usageTrendsUrl": Json::string("\{base_url}/usage/trends"),
      "usageDataSourcesUrl": Json::string("\{base_url}/usage/data-sources"),
      "usageRequestLogsFile": Json::string(
        @pathx.join(default_moonstat_stats_dir(), MOONSTAT_REQUEST_LOGS_FILE),
      ),
      "usageModelPricingFile": Json::string(
        @pathx.join(default_moonstat_stats_dir(), MOONSTAT_MODEL_PRICING_FILE),
      ),
      "cli": Json::string("moonstat"),
      "moondeskAdapterPackage": Json::string(
        "vectie/moondesk/adapters/moonbook",
      ),
      "moontownAdapterPackage": Json::string(
        "vectie/moontown/adapters/moonbook",
      ),
    }),
    "moontown": Json::object({
      "role": Json::string("scheduler-network-watch"),
      "healthUrl": Json::string("\{base_url}/health"),
      "dashboardUrl": Json::string("\{base_url}/"),
      "statusUrl": Json::string("\{base_url}/status"),
      "statsUrl": Json::string("\{base_url}/stats"),
      "metricsUrl": Json::string("\{base_url}/metrics"),
      "streamCheckAllProvidersUrl": Json::string(
        "\{base_url}/proxy/stream-check/all",
      ),
      "usageProviderLimitsUrl": Json::string(
        "\{base_url}/usage/provider-limits",
      ),
      "suiteStatusFile": Json::string(default_moonstat_suite_status_path()),
      "moonclawProviderManifestPath": Json::string(".moonclaw/providers.json"),
      "moonclawProviderManifestCommand": Json::string("moonstat"),
      "moonclawProviderManifestArgs": Json::array([
        Json::string("suite"),
        Json::string("write-moonclaw-providers"),
        Json::string("--path"),
        Json::string(".moonclaw/providers.json"),
      ]),
      "moonclawProviderManifestFullCommand": Json::string(
        "moonstat suite write-moonclaw-providers --path .moonclaw/providers.json",
      ),
      "moonclawProviderManifestTarget": Json::string("moonbook"),
      "moonbookProviderManifestPath": Json::string(".moonclaw/providers.json"),
      "moonbookProviderManifestCommand": Json::string("moonstat"),
      "moonbookProviderManifestArgs": Json::array([
        Json::string("suite"),
        Json::string("write-moonclaw-providers"),
        Json::string("--path"),
        Json::string(".moonclaw/providers.json"),
      ]),
      "moonbookProviderManifestFullCommand": Json::string(
        "moonstat suite write-moonclaw-providers --path .moonclaw/providers.json",
      ),
      "adapterPackages": Json::array([
        Json::string("vectie/moontown/adapters/moonclaw"),
        Json::string("vectie/moontown/adapters/moonbook"),
      ]),
    }),
    "moondesk": Json::object({
      "role": Json::string("operator-dashboard"),
      "suiteStatusFile": Json::string(default_moonstat_suite_status_path()),
      "dashboardUrl": Json::string("\{base_url}/"),
      "healthUrl": Json::string("\{base_url}/health"),
      "statusUrl": Json::string("\{base_url}/status"),
      "statsUrl": Json::string("\{base_url}/stats"),
      "metricsUrl": Json::string("\{base_url}/metrics"),
      "modelsUrl": Json::string("\{openai_base_url}/models"),
      "providerPresetsUrl": Json::string("\{base_url}/providers/presets"),
      "claudeDesktopBaseUrl": Json::string(claude_desktop_base_url),
      "streamCheckProviderUrl": Json::string(
        "\{base_url}/proxy/stream-check/provider",
      ),
      "streamCheckAllProvidersUrl": Json::string(
        "\{base_url}/proxy/stream-check/all",
      ),
      "streamCheckConfigUrl": Json::string(
        "\{base_url}/proxy/stream-check/config",
      ),
      "configStatusUrl": Json::string("\{base_url}/config/status"),
      "adapterPackages": Json::array([
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
  host? : String = @suite.default_host(),
  port? : Int = @suite.default_port(),
  model? : String = @suite.default_model(),
) -> Json {
  moonclaw_providers_file_json(moonstat_openai_base_url(host, port), model)
}

///|
pub async fn write_moonstat_moonclaw_providers_file(
  path? : String = default_moonstat_moonclaw_providers_file_path(),
  host? : String = @suite.default_host(),
  port? : Int = @suite.default_port(),
  model? : String = @suite.default_model(),
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
    "usageLogs": Json::string("moonstat usage logs"),
    "usageSummary": Json::string("moonstat usage summary"),
    "usageApps": Json::string("moonstat usage apps"),
    "usageTrends": Json::string("moonstat usage trends"),
    "usageLimits": Json::string(
      "moonstat usage limits --provider-id <provider_id> --app-type <app_type>",
    ),
    "usageProviders": Json::string("moonstat usage providers"),
    "usageModels": Json::string("moonstat usage models"),
    "usageSources": Json::string("moonstat usage sources"),
    "usageSync": Json::string("moonstat usage sync"),
    "usagePricing": Json::string("moonstat usage pricing"),
    "usageDetail": Json::string(
      "moonstat usage detail --request-id <request_id>",
    ),
    "providerPresets": Json::string(
      "moonstat provider presets list --app-type <app_type>",
    ),
    "streamCheckProvider": Json::string(
      "moonstat stream-check provider --app-type <app_type> --provider-id <provider_id>",
    ),
    "streamCheckAll": Json::string(
      "moonstat stream-check all --app-type <app_type>",
    ),
    "streamCheckConfig": Json::string("moonstat stream-check config"),
    "streamCheckConfigSet": Json::string(
      "moonstat stream-check config set --timeout-secs <seconds>",
    ),
    "codexInstall": Json::string(
      "moonstat codex install --port \{port} --model \{model}",
    ),
    "copilotAuthStatus": Json::string("moonstat copilot status"),
    "copilotLogin": Json::string("moonstat copilot login"),
    "claudeDesktopInstall": Json::string(
      "moonstat claude-desktop install --port \{port}",
    ),
    "skillsList": Json::string("moonstat skills installed"),
    "skillsSearch": Json::string("moonstat skills search --query <query>"),
    "skillsInstall": Json::string(
      "moonstat skills install-unified --directory <directory> --app-type <app_type>",
    ),
    "skillsRepos": Json::string("moonstat skills repos"),
    "updateTrayMenu": Json::string("moonstat runtime tray-menu update"),
    "suiteManifest": Json::string("moonstat suite manifest"),
    "suiteStatus": Json::string("moonstat suite status"),
    "suiteWriteStatus": Json::string("moonstat suite write-status"),
    "moonclawProviders": Json::string("moonstat suite moonclaw-providers"),
    "moonclawProvidersWrite": Json::string(
      "moonstat suite write-moonclaw-providers --path .moonclaw/providers.json",
    ),
  })
}

///|
fn moonstat_suite_routes() -> Array[String] {
  [
    "GET /", "GET /ui/rabbita", "GET /assets/moonstat.css", "GET /assets/moonstat-core.js",
    "GET /assets/moonstat.js", "GET /participant/register", "GET /suite/manifest",
    "GET /suite/status", "POST /suite/status/write", "GET /suite/moonclaw-providers",
    "POST /suite/moonclaw-providers/write", "GET /health", "GET /status", "GET /stats",
    "GET /metrics", "GET /usage/logs", "GET /usage/summary", "GET /usage/summary/by-app",
    "GET /usage/provider-stats", "GET /usage/trends", "GET /usage/provider-limits",
    "GET /usage/model-stats", "GET /usage/data-sources", "POST /usage/sync-session",
    "GET /usage/model-pricing", "POST /usage/model-pricing", "DELETE /usage/model-pricing",
    "GET /usage/request-detail/*path", "GET /usage/provider-usage", "GET /usage/balance",
    "GET /usage/subscription-quota", "GET /usage/codex-oauth-quota", "GET /usage/codex-oauth-models",
    "GET /usage/coding-plan-quota", "POST /usage/test-script", "POST /proxy/stream-check/provider",
    "POST /proxy/stream-check/all", "GET /proxy/stream-check/config", "POST /proxy/stream-check/config",
    "GET /providers/presets", "GET /v1/models", "GET /claude-desktop/v1/models",
    "POST /v1/messages", "POST /claude-desktop/v1/messages", "POST /v1/responses",
    "POST /v1/responses/compact", "POST /v1/chat/completions", "POST /openclaw/v1/chat/completions",
    "GET /auth/status", "GET /auth/accounts", "POST /auth/login", "POST /auth/poll",
    "DELETE /auth/account", "POST /auth/default-account", "POST /auth/logout", "GET /copilot/status",
    "GET /copilot/accounts", "GET /copilot/authenticated", "POST /copilot/device-flow",
    "POST /copilot/poll-auth", "POST /copilot/poll-account", "POST /copilot/logout",
    "DELETE /copilot/account", "POST /copilot/default-account", "GET /copilot/token",
    "GET /copilot/models", "GET /copilot/usage", "POST /runtime/open-external", "POST /runtime/clipboard/text",
    "POST /runtime/updates/check", "POST /runtime/tray-menu/update", "GET /runtime/portable-mode",
    "GET /tools/versions", "POST /tools/lifecycle-action", "GET /tools/probe", "POST /runtime/window-theme",
    "POST /runtime/lightweight-mode/enter", "POST /runtime/lightweight-mode/exit",
    "GET /runtime/lightweight-mode", "POST /files/dialogs/save", "POST /config/files/export",
    "POST /config/files/import", "POST /backups/db", "GET /backups/db", "POST /backups/db/restore",
    "POST /backups/db/rename", "DELETE /backups/db/delete", "GET /deeplinks/parse",
    "POST /deeplinks/merge", "POST /deeplinks/import", "POST /sync/webdav/test",
    "POST /sync/webdav/upload", "POST /sync/webdav/download", "POST /sync/webdav/settings",
    "GET /sync/webdav/remote-info", "POST /sync/s3/test", "POST /sync/s3/upload",
    "POST /sync/s3/download", "POST /sync/s3/settings", "GET /sync/s3/remote-info",
    "GET /sessions", "GET /sessions/messages", "POST /sessions/terminal", "POST /sessions/delete",
    "POST /sessions/delete-many", "GET /providers/omo/file", "GET /providers/omo/current",
    "POST /providers/omo/disable", "GET /providers/omo-slim/file", "GET /providers/omo-slim/current",
    "POST /providers/omo-slim/disable", "POST /files/dialogs/open", "POST /files/dialogs/open-zip",
    "GET /skills/installed", "GET /skills/backups", "POST /skills/backups/delete",
    "POST /skills/backups/restore", "POST /skills/install-unified", "POST /skills/uninstall-unified",
    "POST /skills/toggle-app", "GET /skills/unmanaged", "POST /skills/import-apps",
    "GET /skills/discover", "GET /skills/updates", "POST /skills/update", "POST /skills/migrate-storage",
    "GET /skills/search", "GET /skills", "GET /skills/app", "GET /skills/repos",
    "POST /skills/repos", "POST /skills/repos/remove", "POST /skills/install-zip",
    "GET /proxy/status", "POST /proxy/start", "POST /proxy/stop", "POST /proxy/stop-with-restore",
    "GET|POST /proxy/global-config", "GET|POST /proxy/global-url", "POST /proxy/test-url",
    "GET /proxy/upstream-status", "GET /proxy/local-proxies", "GET|POST /proxy/app-config",
    "GET|POST /proxy/default-cost-multiplier", "GET|POST /proxy/pricing-model-source",
    "GET /proxy/provider-health", "GET|POST /proxy/circuit-breaker-config", "GET /proxy/circuit-breaker-stats",
    "POST /proxy/reset-circuit-breaker", "GET|POST|DELETE /proxy/failover-queue",
    "GET /proxy/available-failover-providers", "GET|POST /proxy/auto-failover-enabled",
    "GET|POST /proxy/takeover-status", "GET /proxy/running", "POST /proxy/switch-provider",
    "POST /proxy/sync-current-providers-live", "POST /proxy/import-default-config",
    "GET /providers", "GET /providers/current", "POST /providers", "POST /providers/update",
    "DELETE /providers", "DELETE /providers/live", "POST /providers/switch", "GET /providers/live-settings",
    "POST /providers/terminal", "GET /providers/live-ids", "GET /providers/live-provider",
    "POST /providers/import-live", "GET /providers/universal", "GET /providers/universal/item",
    "POST /providers/universal", "DELETE /providers/universal", "POST /providers/universal/sync",
    "POST /providers/test-endpoints", "POST /providers/sort-order", "GET /providers/endpoints/list",
    "POST /providers/endpoints", "DELETE /providers/endpoints", "POST /providers/endpoints/touch",
    "GET /config/claude/status", "GET /config/status", "GET /providers/claude-desktop/status",
    "GET /providers/claude-desktop/default-routes", "POST /providers/claude-desktop/import",
    "POST /providers/claude-desktop/official", "GET /config/claude-code/path", "GET /config/dir",
    "POST /config/folder/open", "POST /files/directories/pick", "GET /config/app-path",
    "GET /config/app-folder/open", "GET /config/snippets/claude", "POST /config/snippets/claude",
    "GET /config/snippets", "POST /config/snippets", "POST /config/snippets/extract",
    "GET /config/env/conflicts", "POST /config/env/delete", "POST /config/env/restore",
    "GET /mcp/claude/status", "GET /mcp/claude/config", "POST /mcp/claude/servers",
    "DELETE /mcp/claude/servers", "GET /mcp/validate", "GET /mcp/config", "POST /mcp/config/servers",
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
    "POST /plugin/claude/onboarding-skip/clear", "GET /workspace/memory", "GET /workspace/memory/file",
    "POST /workspace/memory/write", "GET /workspace/memory/search", "POST /workspace/memory/delete",
    "DELETE /workspace/memory/file", "GET /workspace/files", "POST /workspace/files/read",
    "POST /workspace/files", "POST /workspace/open", "GET /openclaw/config-health",
    "GET /openclaw/default-model", "POST /openclaw/default-model", "GET /openclaw/model-catalog",
    "POST /openclaw/model-catalog", "GET /openclaw/agents-defaults", "POST /openclaw/agents-defaults",
    "GET /openclaw/env", "POST /openclaw/env", "GET /openclaw/tools", "POST /openclaw/tools",
    "GET /hermes/model-config", "GET /hermes/memory", "POST /hermes/memory", "GET /hermes/memory-limits",
    "POST /hermes/memory-enabled", "POST /hermes/web-ui", "POST /hermes/dashboard",
    "POST /config/models", "ANY /gemini/v1beta/*path", "ANY /gemini/v1/*path",
  ]
}
