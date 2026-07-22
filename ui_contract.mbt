///|
pub fn moongate_framework_apps_json() -> Json {
  Json::array([
    moongate_framework_app_json(
      "moondesk",
      "MoonDesk",
      "single",
      desktop=true,
      provider_app_type=Some("codex"),
      priority=0,
    ),
    moongate_framework_app_json("claude", "Claude Code", "single"),
    moongate_framework_app_json(
      "claude-desktop",
      "Claude Desktop",
      "single",
      desktop=true,
    ),
    moongate_framework_app_json("codex", "Codex", "single"),
    moongate_framework_app_json("gemini", "Gemini", "single"),
    moongate_framework_app_json("opencode", "OpenCode", "additive"),
    moongate_framework_app_json("openclaw", "OpenClaw", "additive"),
    moongate_framework_app_json("hermes", "Hermes", "additive"),
  ])
}

///|
fn moongate_framework_app_json(
  id : String,
  label : String,
  mode : String,
  desktop? : Bool = false,
  provider_app_type? : String? = None,
  priority? : Int = 100,
) -> Json {
  let app = {
    "id": Json::string(id),
    "label": Json::string(label),
    "mode": Json::string(mode),
    "priority": Json::number(priority.to_double()),
  }
  if desktop {
    app["desktop"] = Json::boolean(true)
  }
  match provider_app_type {
    Some(value) => app["providerAppType"] = Json::string(value)
    None => ()
  }
  Json::object(app)
}

///|
fn moongate_ui_sections() -> Array[(String, String)] {
  [
    ("overview", "Overview"),
    ("providers", "Providers"),
    ("bindings", "App Bindings"),
    ("connections", "Connection Graph"),
    ("connect", "Manual Connect"),
    ("requests", "Requests"),
    ("usage", "Usage"),
    ("suite", "Suite"),
    ("guide", "Guide"),
  ]
}

///|
pub fn moongate_ui_sections_json() -> Json {
  Json::array(
    moongate_ui_sections().map(fn(section) {
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
pub fn moongate_ui_endpoints_json() -> Json {
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
    "appBinding": Json::string("/bindings"),
    "providerImportLive": Json::string("/providers/import-live"),
    "providerPresets": Json::string("/providers/presets"),
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
    "suiteDrift": Json::string("/suite/drift"),
    "suiteWriteStatus": Json::string("/suite/status/write"),
    "suiteMoonclawProviders": Json::string("/suite/moonclaw-providers"),
    "suiteWriteMoonclawProviders": Json::string(
      "/suite/moonclaw-providers/write",
    ),
  })
}

///|
pub fn moongate_ui_readiness_cards_json() -> Json {
  Json::array([
    moongate_readiness_card_json(
      "gateway", "MoonGate", "Ready", "Unavailable", "#overview",
    ),
    moongate_readiness_card_json(
      "proxy", "AI routing", "Running", "Needs start", "#overview",
    ),
    moongate_readiness_card_json(
      "providers", "Providers", "Configured", "Add provider", "#providers",
    ),
    moongate_readiness_card_json(
      "usage", "Usage", "Tracking", "No traffic yet", "#usage",
    ),
    moongate_readiness_card_json(
      "requests", "Requests", "Recent activity", "No requests yet", "#requests",
    ),
  ])
}

///|
fn moongate_readiness_card_json(
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
