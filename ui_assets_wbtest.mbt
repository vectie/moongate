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
  assert_true(html.contains("Moon Suite Integration"))
  assert_true(html.contains("Refresh Suite"))
  assert_true(html.contains("Write Status"))
  assert_true(html.contains("Write MoonClaw"))
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
    "/suite/manifest", "/suite/status", "/suite/status/write", "/suite/moonclaw-providers",
    "/suite/moonclaw-providers/write",
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
  assert_true(js.contains("loadSuite"))
  assert_true(js.contains("loadResilience"))
  assert_true(js.contains("safeGetJson(endpoints.health)"))
  assert_true(js.contains("Promise.allSettled"))
  assert_true(js.contains("panel warning"))
  assert_true(js.contains("renderSuiteApps"))
  assert_true(js.contains("renderSetupConfigRows"))
  assert_true(js.contains("renderStreamCheckResults"))
  assert_true(js.contains("renderRequestDetail"))
  assert_true(core.contains("safeGetJson"))
  assert_true(core.contains("recordCount"))
  assert_true(assets.contains("defaultModel"))
  assert_true(js.contains("setInterval"))
}

///|
fn ui_strip_query(path : String) -> String {
  match path.find("?") {
    Some(index) => path[:index].to_owned()
    None => path
  }
}

///|
fn ui_route_literals_from_asset(source : String) -> Array[String] {
  let routes : Array[String] = []
  let mut first_segment = true
  for segment_view in source.split("\"/") {
    if first_segment {
      first_segment = false
      continue
    }
    let segment = segment_view.to_owned()
    guard segment.find("\"") is Some(end) else { continue }
    let route = "/\{segment[:end].to_owned()}"
    if route.has_prefix("//") {
      continue
    }
    routes.push(ui_strip_query(route))
  }
  routes
}

///|
fn ui_manifest_route_matches_path(route_value : String, path : String) -> Bool {
  guard route_value.find(" ") is Some(separator) else { return false }
  let route_path = route_value[separator + 1:].to_owned()
  route_path == path ||
  route_path == "\{path}/*path" ||
  (
    route_path.has_suffix("/*path") &&
    path.has_prefix(route_path[:route_path.length() - 6])
  )
}

///|
fn ui_manifest_advertises_route(routes : Array[Json], path : String) -> Bool {
  routes.any(route => {
    guard route is String(value) else { return false }
    ui_manifest_route_matches_path(value, path)
  })
}

///|
async test "moonstat ui endpoint literals are advertised by suite manifest" {
  let core = @fsx.read_file("public/assets/moonstat-core.js")
  let js = @fsx.read_file("public/assets/moonstat.js")
  let manifest = moonstat_suite_manifest_json(port=15721)
  guard manifest is Object(obj) else { fail("expected manifest object") }
  guard obj["routes"] is Array(routes) else { fail("expected routes") }
  let endpoint_routes = ui_route_literals_from_asset(core) +
    ui_route_literals_from_asset(js)
  assert_true(endpoint_routes.length() > 45)
  for route in endpoint_routes {
    if !ui_manifest_advertises_route(routes, route) {
      fail("suite manifest does not advertise UI endpoint route: \{route}")
    }
  }
}

///|
async test "moonstat lepusa manifest uses published package boundary shape" {
  let moon_mod = @fsx.read_file("moon.mod")
  let manifest = @fsx.read_file("lepusa.json")
  match @lepusa_project.ProjectConfig::load("lepusa.json") {
    Ok(project) => {
      let _ = project.manifest()
      let _ = project.root()
      let _ = project.registry()
    }
    Err(problems) =>
      fail(
        "published Lepusa ProjectConfig failed to load moonstat lepusa.json: \{problems.join("; ")}",
      )
  }
  assert_true(moon_mod.contains("\"vectie/lepusa@0.1.0\""))
  assert_true(moon_mod.contains("\"moonbit-community/rabbita@0.12.4\""))
  assert_true(manifest.contains("\"identifier\": \"dev.vectie.moonstat\""))
  assert_true(manifest.contains("\"backend\": \"system-webview\""))
  assert_true(manifest.contains("\"assetProtocol\": \"lepusa\""))
  assert_true(manifest.contains("\"source\":"))
  assert_true(manifest.contains("\"localhost\""))
  assert_true(manifest.contains("\"port\": 15721"))
  assert_true(manifest.contains("\"path\": \"/\""))
  assert_true(
    manifest.contains(
      "\"command\": [\"moon\", \"run\", \"cmd/main\", \"--\", \"start\"]",
    ),
  )
  assert_true(manifest.contains("\"readinessPath\": \"/health\""))
  assert_true(manifest.contains("\"serviceDiscovery\""))
  assert_true(manifest.contains("\"opener\""))
  assert_false(manifest.contains("../lepusa"))
  assert_false(manifest.contains("../rba"))
}

///|
async test "moonstat rabbita shell renders lepusa preview structure" {
  let html = moonstat_rabbita_shell_html()
  assert_true(html.contains("data-moonstat-api-base"))
  assert_true(html.contains("http://127.0.0.1:15721"))
  assert_true(html.contains("Proxy, providers, and spend in one place."))
  assert_true(html.contains("id=\"gateway-state\""))
  assert_true(html.contains("id=\"proxy-state\""))
  assert_true(html.contains("id=\"frameworks\""))
  assert_true(html.contains("id=\"providers\""))
  assert_true(html.contains("id=\"suite\""))
  assert_true(html.contains("id=\"usage\""))
  assert_true(html.contains("Moonstat will populate this panel"))
}

///|
async test "moonstat rabbita lepusa preview manifest parses" {
  let manifest = @fsx.read_file("lepusa.rabbita.json")
  let generated = moonstat_rabbita_lepusa_manifest_json()
  match @lepusa_project.ProjectConfig::load("lepusa.rabbita.json") {
    Ok(project) => {
      let _ = project.manifest()
      let _ = project.root()
    }
    Err(problems) =>
      fail(
        "published Lepusa ProjectConfig failed to load moonstat rabbita preview manifest: \{problems.join("; ")}",
      )
  }
  guard @json.parse(manifest) is Object(parsed) else {
    fail("expected lepusa.rabbita.json object")
  }
  guard generated is Object(expected) else {
    fail("expected generated rabbita lepusa manifest object")
  }
  assert_eq(parsed["identifier"], expected["identifier"])
  assert_eq(parsed["rootHtml"], expected["rootHtml"])
  assert_eq(parsed["startup"], expected["startup"])
  assert_true(manifest.contains("\"rootHtml\""))
  assert_true(manifest.contains("Lepusa Rabbita shell"))
  assert_true(manifest.contains("\"assetProtocol\": \"lepusa\""))
  assert_true(manifest.contains("\"localhost\""))
  assert_false(manifest.contains("../lepusa"))
  assert_false(manifest.contains("../rba"))
}
