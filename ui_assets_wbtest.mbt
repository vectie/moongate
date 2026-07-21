///|
async test "moongate generated dashboard exposes operator ui surface" {
  let html = moongate_rabbita_document_html()
  assert_true(html.contains("<title>MoonGate</title>"))
  assert_true(html.contains("/assets/moongate.css"))
  assert_true(html.contains("/assets/moongate-core.js"))
  assert_true(html.contains("/assets/moongate-frameworks.js"))
  assert_true(html.contains("/assets/moongate-usage.js"))
  assert_true(html.contains("/assets/moongate-setup.js"))
  assert_true(html.contains("/assets/moongate-suite.js"))
  assert_true(html.contains("/assets/moongate-resilience.js"))
  assert_true(html.contains("/assets/moongate.js"))
  assert_true(html.contains("/assets/moongate.svg"))
  assert_true(html.contains("/assets/moonsuite-i18n.js"))
  assert_true(html.contains("data-moongate-framework-apps="))
  assert_true(html.contains("data-moongate-sections="))
  assert_true(html.contains("data-moongate-endpoints="))
  assert_true(html.contains("data-moongate-readiness-cards="))
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
  assert_true(html.contains("Gateway Checklist"))
  assert_false(html.contains("Operator Actions"))
  assert_false(html.contains("data-operator-action="))
  assert_true(html.contains("Point your clients here"))
  assert_true(html.contains("OpenAI Chat"))
  assert_true(html.contains("/v1/chat/completions"))
  assert_true(html.contains("Anthropic Messages"))
  assert_true(html.contains("/v1/messages"))
  assert_true(html.contains("Claude Desktop"))
  assert_true(html.contains("/claude-desktop/v1/messages"))
  assert_true(html.contains("OpenClaw"))
  assert_true(html.contains("/openclaw/v1/chat/completions"))
  assert_true(html.contains("data-copy-path="))
  assert_true(html.contains("OpenAI env"))
  assert_true(html.contains("Anthropic env"))
  assert_true(html.contains("OpenClaw env"))
  assert_true(html.contains("data-snippet="))
  assert_true(html.contains("data-copy-snippet="))
  assert_true(html.contains("Provider Control"))
  assert_true(html.contains("Provider Editor"))
  assert_true(html.contains("OpenAI Chat Completions"))
  assert_true(html.contains("value=\"openai_chat\""))
  assert_true(html.contains("Integration Status"))
  assert_true(html.contains("Refresh Setup"))
  assert_true(html.contains("Import MCP Apps"))
  assert_true(html.contains("Import Claude Desktop"))
  assert_true(html.contains("MoonDesk &amp; Moon Suite"))
  assert_true(html.contains("MoonDesk First"))
  assert_true(html.contains("Refresh Suite"))
  assert_true(html.contains("Write Status"))
  assert_true(html.contains("Write MoonClaw"))
  assert_true(html.contains("Resilience Control"))
  assert_true(html.contains("Save Circuit"))
  assert_true(html.contains("Save Stream"))
  assert_true(html.contains("Check App"))
  assert_true(html.contains("Save Provider"))
  assert_true(html.contains("Use This Provider"))
  assert_true(html.contains("Active route"))
  assert_true(html.contains("Delete Provider"))
  assert_true(html.contains("Test Provider"))
  assert_true(html.contains("Usage Explorer"))
  assert_true(html.contains("By Provider"))
  assert_true(html.contains("Request Detail"))
  assert_true(html.contains("Start Proxy"))
  assert_true(html.contains("Stop Proxy"))
  assert_true(html.contains("Sync Live"))
  assert_true(html.contains("Request Log"))
}

///|
test "moongate ui section metadata drives primary navigation" {
  guard moongate_ui_sections_json() is Array(sections) else {
    fail("expected section array")
  }
  assert_eq(sections.length(), 8)
  let html = moongate_rabbita_shell_html()
  for
    id in [
      "overview", "connect", "setup", "routing", "providers", "requests", "usage",
      "suite",
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
async test "moongate ui fetches current backend route surface" {
  let core = @fsx.read_file("public/assets/moongate-core.js")
  let frameworks = @fsx.read_file("public/assets/moongate-frameworks.js")
  let usage = @fsx.read_file("public/assets/moongate-usage.js")
  let setup = @fsx.read_file("public/assets/moongate-setup.js")
  let suite = @fsx.read_file("public/assets/moongate-suite.js")
  let resilience = @fsx.read_file("public/assets/moongate-resilience.js")
  let js = @fsx.read_file("public/assets/moongate.js")
  let assets = core +
    "\n" +
    frameworks +
    "\n" +
    usage +
    "\n" +
    setup +
    "\n" +
    suite +
    "\n" +
    resilience +
    "\n" +
    js
  let endpoint_contract = moongate_ui_endpoints_json().stringify()
  let required = [
    "/health", "/status", "/proxy/status", "/usage/summary", "/usage/summary/by-app",
    "/usage/trends", "/usage/provider-stats", "/usage/model-stats", "/usage/logs?limit=8",
    "/usage/request-detail", "/proxy/start", "/proxy/stop", "/proxy/sync-current-providers-live",
    "/providers", "/providers/current", "/providers/switch", "/providers/import-live",
    "/providers/update", "/providers/presets", "/proxy/stream-check/provider", "/providers/claude-desktop/import",
    "/auth/status", "/config/status", "/config/folder/open", "/providers/claude-desktop/status",
    "/mcp/servers", "/mcp/import-apps", "/settings", "/runtime/portable-mode", "/tools/versions",
    "/proxy/running", "/proxy/takeover-status", "/plugin/claude/status", "/plugin/claude/applied",
    "/proxy/circuit-breaker-config", "/proxy/circuit-breaker-stats", "/proxy/reset-circuit-breaker",
    "/proxy/failover-queue", "/proxy/available-failover-providers", "/proxy/auto-failover-enabled",
    "/usage/provider-limits", "/proxy/stream-check/all", "/proxy/stream-check/config",
    "/suite/manifest", "/suite/status", "/suite/drift", "/suite/status/write", "/suite/moonclaw-providers",
    "/suite/moonclaw-providers/write",
  ]
  for route in required {
    assert_true(endpoint_contract.contains(route))
  }
  assert_true(core.contains("readShellJson"))
  assert_true(core.contains("moongate-endpoints"))
  assert_true(core.contains("readReadinessCards"))
  assert_true(core.contains("moongate-readiness-cards"))
  assert_false(core.contains("const endpoints = {"))
  assert_true(core.contains("readFrameworkApps"))
  assert_false(core.contains("const frameworkApps = ["))
  assert_true(core.contains("fetch(path"))
  assert_true(core.contains("postJson"))
  assert_true(core.contains("deleteJson"))
  assert_true(frameworks.contains("providerPayloadFromForm"))
  assert_true(frameworks.contains("loadProviderTemplates"))
  assert_true(frameworks.contains("providerTemplateLoadGeneration"))
  assert_true(frameworks.contains("loadProviderTemplateFile"))
  assert_true(frameworks.contains("loadCachedProviderTemplates"))
  assert_true(frameworks.contains("moongate.providerTemplates.v1"))
  assert_true(frameworks.contains("provider-original-app"))
  assert_true(frameworks.contains("clearApiKey"))
  assert_true(frameworks.contains("clearModelMapping"))
  assert_true(frameworks.contains("draft: true"))
  assert_true(frameworks.contains("API keys stay separate"))
  assert_true(frameworks.contains("providerTemplateApiFormatLabel"))
  assert_true(
    frameworks.contains("selecting one changes Framework automatically"),
  )
  assert_false(
    frameworks.contains(".filter((row) => row.provider.appType === appType)"),
  )
  assert_true(frameworks.contains("loadFrameworks"))
  assert_true(frameworks.contains("frameworkLoadGeneration"))
  assert_true(frameworks.contains("renderProviderRows"))
  assert_true(frameworks.contains("Provider routes unavailable"))
  assert_true(frameworks.contains("Current route"))
  assert_true(frameworks.contains("networkRequestPerformed"))
  assert_true(frameworks.contains("Confirm Delete"))
  assert_true(frameworks.contains("sortedProviderRows"))
  assert_false(frameworks.contains("window.confirm"))
  assert_false(js.contains("function providerPayloadFromForm"))
  assert_true(usage.contains("loadUsageExplorer"))
  assert_true(usage.contains("usageLoadGeneration"))
  assert_false(js.contains("function loadUsageExplorer"))
  assert_true(setup.contains("loadSetupStatus"))
  assert_true(setup.contains("setupLoadGeneration"))
  assert_true(suite.contains("loadSuite"))
  assert_true(suite.contains("suiteLoadGeneration"))
  assert_true(suite.contains("moondesk"))
  assert_true(suite.contains("Primary"))
  assert_true(resilience.contains("loadResilience"))
  assert_true(resilience.contains("resilienceLoadGeneration"))
  assert_false(js.contains("function loadSetupStatus"))
  assert_false(js.contains("function loadSuite"))
  assert_false(js.contains("function loadResilience"))
  assert_true(js.contains("safeGetJson(endpoints.health)"))
  assert_true(js.contains("Promise.allSettled"))
  assert_true(js.contains("refreshInFlight"))
  assert_true(js.contains("refreshQueued"))
  assert_true(js.contains("gateway-endpoint"))
  assert_false(js.contains("renderProviderRows(providerHealthRows)"))
  assert_true(js.contains("section warning"))
  assert_false(js.contains("runOperatorAction"))
  assert_false(js.contains("operator-action-status"))
  assert_false(js.contains("data-operator-action"))
  assert_true(js.contains("goToPage"))
  assert_true(js.contains("data-page-view"))
  assert_true(js.contains("showToast"))
  assert_true(js.contains("shellApiBase"))
  assert_true(js.contains("connectionUrl"))
  assert_true(js.contains("clientSnippet"))
  assert_true(js.contains("renderConnectionValues"))
  assert_true(js.contains("OPENAI_BASE_URL"))
  assert_true(js.contains("ANTHROPIC_BASE_URL"))
  assert_true(js.contains("OPENCLAW_BASE_URL"))
  assert_true(js.contains("copyText"))
  assert_true(js.contains("connection-copy-status"))
  assert_true(js.contains("data-copy-path"))
  assert_true(js.contains("data-copy-snippet"))
  assert_true(suite.contains("renderSuiteApps"))
  assert_true(setup.contains("renderSetupConfigRows"))
  assert_true(resilience.contains("renderStreamCheckResults"))
  assert_true(usage.contains("renderRequestDetail"))
  assert_true(usage.contains("renderLogs"))
  assert_true(js.contains("renderReadiness"))
  assert_true(js.contains("mergeReadinessState"))
  assert_true(core.contains("safeGetJson"))
  assert_true(core.contains("responseError"))
  assert_true(core.contains("unhealthy"))
  assert_true(core.contains("recordCount"))
  assert_true(assets.contains("defaultModel"))
  assert_true(js.contains("usageDashboardRefreshIntervalMs"))
  assert_true(js.contains("setTimeout"))
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
test "moongate framework app metadata preserves active framework support" {
  guard moongate_framework_apps_json() is Array(apps) else {
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
test "moongate ui endpoint metadata preserves dashboard route support" {
  guard moongate_ui_endpoints_json() is Object(endpoints) else {
    fail("expected endpoint object")
  }
  assert_eq(endpoints["health"], Json::string("/health"))
  assert_eq(endpoints["providerCreate"], Json::string("/providers"))
  assert_eq(endpoints["providerPresets"], Json::string("/providers/presets"))
  assert_eq(
    endpoints["claudeDesktopImport"],
    Json::string("/providers/claude-desktop/import"),
  )
  assert_eq(endpoints["suiteManifest"], Json::string("/suite/manifest"))
  assert_eq(endpoints["suiteDrift"], Json::string("/suite/drift"))
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
test "moongate readiness metadata preserves first run operator checklist" {
  guard moongate_ui_readiness_cards_json() is Array(cards) else {
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
  guard moongate_ui_endpoints_json() is Object(endpoints) else { return routes }
  for key in endpoints.keys() {
    guard endpoints[key] is String(route) else { continue }
    routes.push(ui_strip_query(route))
  }
  routes
}

///|
async test "moongate ui endpoint literals are advertised by suite manifest" {
  let core = @fsx.read_file("public/assets/moongate-core.js")
  let frameworks = @fsx.read_file("public/assets/moongate-frameworks.js")
  let usage = @fsx.read_file("public/assets/moongate-usage.js")
  let setup = @fsx.read_file("public/assets/moongate-setup.js")
  let suite = @fsx.read_file("public/assets/moongate-suite.js")
  let resilience = @fsx.read_file("public/assets/moongate-resilience.js")
  let js = @fsx.read_file("public/assets/moongate.js")
  let manifest = moongate_suite_manifest_json(port=15721)
  guard manifest is Object(obj) else { fail("expected manifest object") }
  guard obj["routes"] is Array(routes) else { fail("expected routes") }
  let endpoint_routes = ui_route_literals_from_endpoint_contract() +
    ui_route_literals_from_asset(core) +
    ui_route_literals_from_asset(frameworks) +
    ui_route_literals_from_asset(usage) +
    ui_route_literals_from_asset(setup) +
    ui_route_literals_from_asset(suite) +
    ui_route_literals_from_asset(resilience) +
    ui_route_literals_from_asset(js)
  assert_true(endpoint_routes.length() > 45)
  for route in endpoint_routes {
    if !ui_manifest_advertises_route(routes, route) {
      fail("suite manifest does not advertise UI endpoint route: \{route}")
    }
  }
}

///|
async test "moongate lepusa manifest uses published package boundary shape" {
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
        "published Lepusa ProjectConfig failed to load moongate lepusa.json: \{problems.join("; ")}",
      )
  }
  assert_true(moon_mod.contains("\"vectie/lepusa@0.1.4\""))
  assert_true(moon_mod.contains("\"moonbit-community/rabbita@0.12.4\""))
  let generated = moongate_lepusa_manifest_json()
  let parsed = @json.parse(manifest) catch {
    _ => fail("expected lepusa.json to parse")
  }
  guard parsed is Object(parsed_obj) else { fail("expected lepusa object") }
  guard generated is Object(generated_obj) else {
    fail("expected generated lepusa object")
  }
  for
    key in [
      "identifier", "productName", "version", "icon", "runtime", "bundleResources",
      "window", "plugins", "capabilities", "startup",
    ] {
    assert_eq(parsed_obj[key], generated_obj[key])
  }
  assert_true(manifest.contains("\"identifier\": \"dev.vectie.moongate\""))
  assert_true(manifest.contains("\"icon\": \"assets/moongate.icns\""))
  assert_true(@fsx.exists_as_file("assets/moongate.icns"))
  assert_true(@fsx.exists_as_file("assets/moongate-macos.svg"))
  assert_true(manifest.contains("\"identity\": \"-\""))
  assert_true(@fsx.exists_as_file("public/assets/moongate.svg"))
  assert_true(manifest.contains("\"backend\": \"system-webview\""))
  assert_true(manifest.contains("\"assetProtocol\": \"lepusa\""))
  assert_true(manifest.contains("\"source\":"))
  assert_true(manifest.contains("\"localhost\""))
  assert_true(manifest.contains("\"port\": 15721"))
  assert_true(manifest.contains("\"path\": \"/ui/rabbita\""))
  assert_true(
    moongate_suite_manifest_json().stringify().contains("GET /ui/rabbita"),
  )
  assert_true(manifest.contains("\"readinessPath\": \"/health\""))
  assert_true(manifest.contains("\"path\": \"moongate-server\""))
  assert_true(manifest.contains("\"executable\": true"))
  assert_true(manifest.contains("\"serviceDiscovery\""))
  assert_true(manifest.contains("\"opener\""))
  assert_false(manifest.contains("../lepusa"))
  assert_false(manifest.contains("../rba"))
}

///|
async test "moongate rabbita shell renders lepusa preview structure" {
  let html = moongate_rabbita_shell_html()
  let document = moongate_rabbita_document_html()
  assert_true(html.contains("data-moongate-api-base"))
  assert_true(html.contains("http://127.0.0.1:15721"))
  assert_true(html.contains("/assets/moongate.css"))
  assert_true(html.contains("/assets/moongate-core.js"))
  assert_true(html.contains("/assets/moongate-frameworks.js"))
  assert_true(html.contains("/assets/moongate-usage.js"))
  assert_true(html.contains("/assets/moongate-setup.js"))
  assert_true(html.contains("/assets/moongate-suite.js"))
  assert_true(html.contains("/assets/moongate-resilience.js"))
  assert_true(html.contains("/assets/moongate.js"))
  assert_true(html.contains("Gateway state, spend, and readiness at a glance."))
  assert_false(html.contains("Operator Actions"))
  assert_true(html.contains("data-page-view=\"overview\""))
  assert_true(html.contains("Point your clients here"))
  assert_true(html.contains("data-copy-path=\"/v1/responses\""))
  assert_true(html.contains("data-snippet=\"openai-env\""))
  assert_true(html.contains("data-copy-snippet=\"metrics-url\""))
  assert_true(document.contains("<html"))
  assert_true(document.contains("<head"))
  assert_true(document.contains("<body"))
  for id in moongate_rabbita_shell_dom_ids() {
    assert_true(
      html.contains("id=\"\{id}\""),
      msg="missing Rabbita shell id \{id}",
    )
  }
}

///|
test "moongate rabbita alternate base is runtime data not a hardcoded status" {
  let html = moongate_rabbita_shell_html(api_base="http://127.0.0.1:18888")
  assert_true(
    html.contains("data-moongate-api-base=\"http://127.0.0.1:18888\""),
  )
  assert_true(html.contains("id=\"gateway-endpoint\">Connecting"))
  assert_true(html.contains("id=\"gateway-port\">-"))
  assert_false(html.contains("<code>127.0.0.1:15721</code>"))
}

///|
async test "moongate rabbita document is routable standalone dashboard html" {
  let document = moongate_rabbita_document_html()
  assert_true(document.contains("<html"))
  assert_true(document.contains("data-moongate-api-base"))
  assert_true(document.contains("/assets/moongate.css"))
  assert_true(document.contains("/assets/moongate-core.js"))
  assert_true(document.contains("/assets/moongate-frameworks.js"))
  assert_true(document.contains("/assets/moongate-usage.js"))
  assert_true(document.contains("/assets/moongate-setup.js"))
  assert_true(document.contains("/assets/moongate-suite.js"))
  assert_true(document.contains("/assets/moongate-resilience.js"))
  assert_true(document.contains("/assets/moongate.js"))
  assert_true(document.contains("id=\"page-overview\""))
  assert_true(document.contains("id=\"page-routing\""))
  assert_true(document.contains("id=\"connection-board\""))
  assert_true(document.contains("id=\"connection-copy-status\""))
  for
    id in [
      "provider-form", "setup-config-rows", "suite-app-rows", "request-log",
    ] {
    assert_true(document.contains("id=\"\{id}\""))
  }
  guard moongate_suite_manifest_json() is Object(obj) else {
    fail("expected suite manifest object")
  }
  guard obj["routes"] is Array(routes) else { fail("expected manifest routes") }
  assert_true(routes.contains(Json::string("GET /ui/rabbita")))
}

///|
async test "moongate rabbita lepusa preview manifest parses" {
  let manifest = @fsx.read_file("lepusa.rabbita.json")
  let generated = moongate_rabbita_lepusa_manifest_json()
  match @lepusa_project.ProjectConfig::load("lepusa.rabbita.json") {
    Ok(project) => {
      let _ = project.manifest()
      let _ = project.root()
    }
    Err(problems) =>
      fail(
        "published Lepusa ProjectConfig failed to load moongate rabbita preview manifest: \{problems.join("; ")}",
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
  assert_true(manifest.contains("Local Gateway"))
  assert_true(manifest.contains("\"assetProtocol\": \"lepusa\""))
  assert_true(manifest.contains("\"localhost\""))
  assert_false(manifest.contains("../lepusa"))
  assert_false(manifest.contains("../rba"))
}
