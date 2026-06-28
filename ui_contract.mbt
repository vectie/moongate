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
fn moonstat_ui_sections() -> Array[(String, String)] {
  [
    ("overview", "Overview"),
    ("providers", "Providers"),
    ("frameworks", "Frameworks"),
    ("setup", "Setup"),
    ("suite", "Suite"),
    ("resilience", "Resilience"),
    ("usage", "Usage"),
    ("usage-explorer", "Explorer"),
    ("requests", "Requests"),
  ]
}

///|
pub fn moonstat_ui_sections_json() -> Json {
  Json::array(
    moonstat_ui_sections().map(fn(section) {
      let (id, label) = section
      Json::object({
        "id": Json::string(id),
        "label": Json::string(label),
        "target": Json::string("#\{id}"),
      })
    }),
  )
}

///|
pub fn moonstat_ui_endpoints_json() -> Json {
  Json::object({
    "health": Json::string("/health"),
    "status": Json::string("/status"),
    "proxy": Json::string("/proxy/status"),
    "proxyStart": Json::string("/proxy/start"),
    "proxyStop": Json::string("/proxy/stop"),
    "syncLive": Json::string("/proxy/sync-current-providers-live"),
    "providerCreate": Json::string("/providers"),
    "providerCurrent": Json::string("/providers/current"),
    "providerUpdate": Json::string("/providers/update"),
    "providerDelete": Json::string("/providers"),
    "providerSwitch": Json::string("/providers/switch"),
    "providerImportLive": Json::string("/providers/import-live"),
    "providerStreamCheck": Json::string("/proxy/stream-check/provider"),
    "usageSummary": Json::string("/usage/summary"),
    "usageByApp": Json::string("/usage/summary/by-app"),
    "usageTrends": Json::string("/usage/trends"),
    "providerStats": Json::string("/usage/provider-stats"),
    "modelStats": Json::string("/usage/model-stats"),
    "usageLogs": Json::string("/usage/logs"),
    "logs": Json::string("/usage/logs?limit=8"),
    "requestDetail": Json::string("/usage/request-detail"),
    "authStatus": Json::string("/auth/status"),
    "configStatus": Json::string("/config/status"),
    "configFolderOpen": Json::string("/config/folder/open"),
    "claudeDesktopStatus": Json::string("/providers/claude-desktop/status"),
    "claudeDesktopImport": Json::string("/providers/claude-desktop/import"),
    "mcpServers": Json::string("/mcp/servers"),
    "mcpImportApps": Json::string("/mcp/import-apps"),
    "settings": Json::string("/settings"),
    "portableMode": Json::string("/runtime/portable-mode"),
    "toolsVersions": Json::string("/tools/versions"),
    "proxyRunning": Json::string("/proxy/running"),
    "takeoverStatus": Json::string("/proxy/takeover-status"),
    "pluginClaudeStatus": Json::string("/plugin/claude/status"),
    "pluginClaudeApplied": Json::string("/plugin/claude/applied"),
    "circuitConfig": Json::string("/proxy/circuit-breaker-config"),
    "circuitStats": Json::string("/proxy/circuit-breaker-stats"),
    "resetCircuit": Json::string("/proxy/reset-circuit-breaker"),
    "failoverQueue": Json::string("/proxy/failover-queue"),
    "availableFailover": Json::string("/proxy/available-failover-providers"),
    "autoFailover": Json::string("/proxy/auto-failover-enabled"),
    "providerLimits": Json::string("/usage/provider-limits"),
    "streamCheckAll": Json::string("/proxy/stream-check/all"),
    "streamCheckConfig": Json::string("/proxy/stream-check/config"),
    "suiteManifest": Json::string("/suite/manifest"),
    "suiteStatus": Json::string("/suite/status"),
    "suiteWriteStatus": Json::string("/suite/status/write"),
    "suiteMoonclawProviders": Json::string("/suite/moonclaw-providers"),
    "suiteWriteMoonclawProviders": Json::string(
      "/suite/moonclaw-providers/write",
    ),
  })
}

///|
pub fn moonstat_ui_readiness_cards_json() -> Json {
  Json::array([
    moonstat_readiness_card_json(
      "gateway", "Gateway", "Ready", "Unavailable", "#overview",
    ),
    moonstat_readiness_card_json(
      "proxy", "Proxy", "Running", "Needs start", "#overview",
    ),
    moonstat_readiness_card_json(
      "providers", "Providers", "Configured", "Add provider", "#frameworks",
    ),
    moonstat_readiness_card_json(
      "usage", "Usage", "Tracking", "No traffic yet", "#usage-explorer",
    ),
    moonstat_readiness_card_json(
      "requests", "Requests", "Recent activity", "No requests yet", "#requests",
    ),
  ])
}

///|
fn moonstat_readiness_card_json(
  id : String,
  label : String,
  ready : String,
  waiting : String,
  target : String,
) -> Json {
  Json::object({
    "id": Json::string(id),
    "label": Json::string(label),
    "ready": Json::string(ready),
    "waiting": Json::string(waiting),
    "target": Json::string(target),
  })
}
