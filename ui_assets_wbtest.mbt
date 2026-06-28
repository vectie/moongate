///|
async test "moonstat ui assets expose operator dashboard at public root" {
  let html = @fsx.read_file("public/index.html")
  assert_true(html.contains("<title>Moonstat</title>"))
  assert_true(html.contains("/assets/moonstat.css"))
  assert_true(html.contains("/assets/moonstat-core.js"))
  assert_true(html.contains("/assets/moonstat.js"))
  assert_true(html.contains("Provider Health"))
  assert_true(html.contains("Provider Control"))
  assert_true(html.contains("Provider Editor"))
  assert_true(html.contains("Integration Status"))
  assert_true(html.contains("Refresh Setup"))
  assert_true(html.contains("Import MCP Apps"))
  assert_true(html.contains("Import Claude Desktop"))
  assert_true(html.contains("Resilience Control"))
  assert_true(html.contains("Save Circuit"))
  assert_true(html.contains("Save Stream"))
  assert_true(html.contains("Check App"))
  assert_true(html.contains("Save Provider"))
  assert_true(html.contains("Delete Provider"))
  assert_true(html.contains("Test Provider"))
  assert_true(html.contains("Usage Explorer"))
  assert_true(html.contains("Provider Usage"))
  assert_true(html.contains("Request Detail"))
  assert_true(html.contains("Start Proxy"))
  assert_true(html.contains("Stop Proxy"))
  assert_true(html.contains("Sync Live"))
  assert_true(html.contains("Request Log"))
}

///|
async test "moonstat ui fetches current backend route surface" {
  let core = @fsx.read_file("public/assets/moonstat-core.js")
  let js = @fsx.read_file("public/assets/moonstat.js")
  let assets = core + "\n" + js
  let required = [
    "/health", "/status", "/proxy/status", "/usage/summary", "/usage/summary/by-app",
    "/usage/trends", "/usage/provider-stats", "/usage/model-stats", "/usage/logs?limit=8",
    "/usage/request-detail", "/proxy/start", "/proxy/stop", "/proxy/sync-current-providers-live",
    "/providers", "/providers/current", "/providers/switch", "/providers/import-live",
    "/providers/update", "/proxy/stream-check/provider", "/providers/claude-desktop/import",
    "/auth/status", "/config/status", "/config/folder/open", "/providers/claude-desktop/status",
    "/mcp/servers", "/mcp/import-apps", "/settings", "/runtime/portable-mode", "/tools/versions",
    "/proxy/running", "/proxy/takeover-status", "/plugin/claude/status", "/plugin/claude/applied",
    "/proxy/circuit-breaker-config", "/proxy/circuit-breaker-stats", "/proxy/reset-circuit-breaker",
    "/proxy/failover-queue", "/proxy/available-failover-providers", "/proxy/auto-failover-enabled",
    "/usage/provider-limits", "/proxy/stream-check/all", "/proxy/stream-check/config",
  ]
  for route in required {
    assert_true(assets.contains(route))
  }
  for
    app in [
      "claude", "claude-desktop", "codex", "gemini", "opencode", "openclaw", "hermes",
    ] {
    assert_true(assets.contains(app))
  }
  assert_true(core.contains("fetch(path"))
  assert_true(core.contains("postJson"))
  assert_true(core.contains("deleteJson"))
  assert_true(js.contains("providerPayloadFromForm"))
  assert_true(js.contains("loadUsageExplorer"))
  assert_true(js.contains("loadSetupStatus"))
  assert_true(js.contains("loadResilience"))
  assert_true(js.contains("renderSetupConfigRows"))
  assert_true(js.contains("renderStreamCheckResults"))
  assert_true(js.contains("renderRequestDetail"))
  assert_true(core.contains("safeGetJson"))
  assert_true(core.contains("recordCount"))
  assert_true(assets.contains("defaultModel"))
  assert_true(js.contains("setInterval"))
}

///|
async test "moonstat lepusa manifest uses published package boundary shape" {
  let manifest = @fsx.read_file("lepusa.json")
  assert_true(manifest.contains("\"identifier\": \"dev.vectie.moonstat\""))
  assert_true(manifest.contains("\"localhost\""))
  assert_true(
    manifest.contains(
      "\"command\": [\"moon\", \"run\", \"cmd/main\", \"--\", \"start\"]",
    ),
  )
  assert_true(manifest.contains("\"readinessPath\": \"/health\""))
  assert_true(manifest.contains("\"serviceDiscovery\""))
  assert_false(manifest.contains("../lepusa"))
  assert_false(manifest.contains("../rba"))
}
