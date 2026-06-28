///|
async test "moonstat generated dashboard exposes operator ui surface" {
  let html = moonstat_rabbita_document_html()
  assert_true(html.contains("<title>Moonstat</title>"))
  assert_true(html.contains("/assets/moonstat.css"))
  assert_true(html.contains("/assets/moonstat-core.js"))
  assert_true(html.contains("/assets/moonstat.js"))
  assert_true(html.contains("data-moonstat-framework-apps="))
  assert_true(html.contains("data-moonstat-sections="))
  assert_true(html.contains("data-moonstat-endpoints="))
  assert_true(html.contains("data-moonstat-readiness-cards="))
  assert_true(html.contains("/health"))
  assert_true(html.contains("/proxy/status"))
  for
    app in [
      "claude", "claude-desktop", "codex", "gemini", "opencode", "openclaw", "hermes",
    ] {
    assert_true(html.contains(app))
  }
  assert_true(html.contains("Provider Health"))
  assert_true(html.contains("Readiness"))
  assert_true(html.contains("Standalone gateway checklist"))
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
test "moonstat ui section metadata drives primary navigation" {
  guard moonstat_ui_sections_json() is Array(sections) else {
    fail("expected section array")
  }
  assert_eq(sections.length(), 9)
  let html = moonstat_rabbita_shell_html()
  for
    id in [
      "overview", "providers", "frameworks", "setup", "suite", "resilience", "usage",
      "usage-explorer", "requests",
    ] {
    assert_true(html.contains("href=\"#\{id}\""))
    assert_true(
      sections.any(section => {
        guard section is Object(obj) else { return false }
        obj["id"] == Json::string(id) && obj["target"] == Json::string("#\{id}")
      }),
    )
  }
}

///|
async test "moonstat ui fetches current backend route surface" {
  let core = @fsx.read_file("public/assets/moonstat-core.js")
  let js = @fsx.read_file("public/assets/moonstat.js")
  let assets = core + "\n" + js
  let endpoint_contract = moonstat_ui_endpoints_json().stringify()
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
    assert_true(endpoint_contract.contains(route))
  }
  assert_true(core.contains("readShellJson"))
  assert_true(core.contains("moonstat-endpoints"))
  assert_true(core.contains("readReadinessCards"))
  assert_true(core.contains("moonstat-readiness-cards"))
  assert_false(core.contains("const endpoints = {"))
  assert_true(core.contains("readFrameworkApps"))
  assert_false(core.contains("const frameworkApps = ["))
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
  assert_true(js.contains("renderReadiness"))
  assert_true(js.contains("mergeReadinessState"))
  assert_true(core.contains("safeGetJson"))
  assert_true(core.contains("recordCount"))
  assert_true(assets.contains("defaultModel"))
  assert_true(js.contains("setInterval"))
}

///|
fn ui_framework_app_by_id(
  apps : Array[Json],
  id : String,
) -> Map[String, Json]? {
  for app in apps {
    guard app is Object(obj) else { continue }
    if obj["id"] == Json::string(id) {
      return Some(obj)
    }
  }
  None
}

///|
test "moonstat framework app metadata preserves active framework support" {
  guard moonstat_framework_apps_json() is Array(apps) else {
    fail("expected framework app array")
  }
  assert_eq(apps.length(), 7)
  for
    id in [
      "claude", "claude-desktop", "codex", "gemini", "opencode", "openclaw", "hermes",
    ] {
    assert_true(ui_framework_app_by_id(apps, id) is Some(_))
  }
  guard ui_framework_app_by_id(apps, "claude-desktop") is Some(desktop) else {
    fail("expected claude desktop framework")
  }
  assert_eq(desktop["label"], Json::string("Claude Desktop"))
  assert_eq(desktop["mode"], Json::string("single"))
  assert_eq(desktop["desktop"], Json::boolean(true))
  for id in ["opencode", "openclaw", "hermes"] {
    guard ui_framework_app_by_id(apps, id) is Some(additive) else {
      fail("expected additive framework \{id}")
    }
    assert_eq(additive["mode"], Json::string("additive"))
  }
}

///|
test "moonstat ui endpoint metadata preserves dashboard route support" {
  guard moonstat_ui_endpoints_json() is Object(endpoints) else {
    fail("expected endpoint object")
  }
  assert_eq(endpoints["health"], Json::string("/health"))
  assert_eq(endpoints["providerCreate"], Json::string("/providers"))
  assert_eq(
    endpoints["claudeDesktopImport"],
    Json::string("/providers/claude-desktop/import"),
  )
  assert_eq(endpoints["suiteManifest"], Json::string("/suite/manifest"))
  assert_eq(
    endpoints["suiteWriteMoonclawProviders"],
    Json::string("/suite/moonclaw-providers/write"),
  )
  assert_eq(
    endpoints["streamCheckAll"],
    Json::string("/proxy/stream-check/all"),
  )
  assert_eq(endpoints["requestDetail"], Json::string("/usage/request-detail"))
}

///|
test "moonstat readiness metadata preserves first run operator checklist" {
  guard moonstat_ui_readiness_cards_json() is Array(cards) else {
    fail("expected readiness card array")
  }
  assert_eq(cards.length(), 5)
  for id in ["gateway", "proxy", "providers", "usage", "requests"] {
    assert_true(
      cards.any(card => {
        guard card is Object(obj) else { return false }
        obj["id"] == Json::string(id) && obj["target"] is String(_)
      }),
    )
  }
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
fn ui_route_literals_from_endpoint_contract() -> Array[String] {
  let routes : Array[String] = []
  guard moonstat_ui_endpoints_json() is Object(endpoints) else { return routes }
  for key in endpoints.keys() {
    guard endpoints[key] is String(route) else { continue }
    routes.push(ui_strip_query(route))
  }
  routes
}

///|
async test "moonstat ui endpoint literals are advertised by suite manifest" {
  let core = @fsx.read_file("public/assets/moonstat-core.js")
  let js = @fsx.read_file("public/assets/moonstat.js")
  let manifest = moonstat_suite_manifest_json(port=15721)
  guard manifest is Object(obj) else { fail("expected manifest object") }
  guard obj["routes"] is Array(routes) else { fail("expected routes") }
  let endpoint_routes = ui_route_literals_from_endpoint_contract() +
    ui_route_literals_from_asset(core) +
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
  let generated = moonstat_lepusa_manifest_json()
  let parsed = @json.parse(manifest) catch {
    _ => fail("expected lepusa.json to parse")
  }
  guard parsed is Object(parsed_obj) else { fail("expected lepusa object") }
  guard generated is Object(generated_obj) else {
    fail("expected generated lepusa object")
  }
  for
    key in [
      "identifier", "productName", "version", "runtime", "window", "plugins", "capabilities",
      "startup",
    ] {
    assert_eq(parsed_obj[key], generated_obj[key])
  }
  assert_true(manifest.contains("\"identifier\": \"dev.vectie.moonstat\""))
  assert_true(manifest.contains("\"backend\": \"system-webview\""))
  assert_true(manifest.contains("\"assetProtocol\": \"lepusa\""))
  assert_true(manifest.contains("\"source\":"))
  assert_true(manifest.contains("\"localhost\""))
  assert_true(manifest.contains("\"port\": 15721"))
  assert_true(manifest.contains("\"path\": \"/ui/rabbita\""))
  assert_true(
    moonstat_suite_manifest_json().stringify().contains("GET /ui/rabbita"),
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
  let document = moonstat_rabbita_document_html()
  assert_true(html.contains("data-moonstat-api-base"))
  assert_true(html.contains("http://127.0.0.1:15721"))
  assert_true(html.contains("/assets/moonstat.css"))
  assert_true(html.contains("/assets/moonstat-core.js"))
  assert_true(html.contains("/assets/moonstat.js"))
  assert_true(html.contains("Proxy, providers, and spend in one place."))
  assert_true(document.contains("<html"))
  assert_true(document.contains("<head"))
  assert_true(document.contains("<body"))
  for id in moonstat_rabbita_shell_dom_ids() {
    assert_true(
      html.contains("id=\"\{id}\""),
      msg="missing Rabbita shell id \{id}",
    )
  }
}

///|
async test "moonstat rabbita document is routable standalone dashboard html" {
  let document = moonstat_rabbita_document_html()
  assert_true(document.contains("<html"))
  assert_true(document.contains("data-moonstat-api-base"))
  assert_true(document.contains("/assets/moonstat.css"))
  assert_true(document.contains("/assets/moonstat-core.js"))
  assert_true(document.contains("/assets/moonstat.js"))
  for
    id in [
      "provider-form", "setup-config-rows", "suite-app-rows", "request-log",
    ] {
    assert_true(document.contains("id=\"\{id}\""))
  }
  guard moonstat_suite_manifest_json() is Object(obj) else {
    fail("expected suite manifest object")
  }
  guard obj["routes"] is Array(routes) else { fail("expected manifest routes") }
  assert_true(routes.contains(Json::string("GET /ui/rabbita")))
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
  assert_true(manifest.contains("Local gateway"))
  assert_true(manifest.contains("\"assetProtocol\": \"lepusa\""))
  assert_true(manifest.contains("\"localhost\""))
  assert_false(manifest.contains("../lepusa"))
  assert_false(manifest.contains("../rba"))
}
