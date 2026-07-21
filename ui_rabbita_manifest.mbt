///|
#warnings("-alert_unstable")
pub fn moongate_rabbita_document_html(
  api_base? : String = "http://127.0.0.1:15721",
) -> String {
  @rabbita.render_to_string(
    @rabbita.static_cell(
      @html.html(lang="en", [
        @html.head([
          @html.meta(charset="utf-8"),
          @html.meta(
            name="viewport",
            content="width=device-width, initial-scale=1",
          ),
          @html.title("MoonGate"),
        ]),
        @html.body([moongate_rabbita_shell_view(api_base~)]),
      ]),
    ),
  )
}

///|
pub fn moongate_rabbita_shell_dom_ids() -> Array[String] {
  [
    "nav", "ui-updated", "page-title", "page-subtitle", "topbar-updated", "overview",
    "page-overview", "page-connect", "page-setup", "page-routing", "page-providers",
    "page-requests", "page-usage", "page-suite", "refresh", "proxy-start", "proxy-stop",
    "gateway-state", "gateway-detail", "proxy-state", "proxy-detail", "request-total",
    "request-total-detail", "cost-total", "cost-detail", "readiness", "readiness-cards",
    "connection-board", "connection-copy-status", "frameworks", "framework-rows",
    "sync-live", "provider-editor", "provider-form", "provider-original-id", "provider-app",
    "provider-id", "provider-name", "provider-type", "provider-base-url", "provider-api-format",
    "provider-api-key", "provider-default-model", "provider-sonnet-model", "provider-haiku-model",
    "provider-opus-model", "provider-notes", "provider-enabled", "provider-full-url",
    "provider-fast-mode", "provider-save", "provider-delete", "provider-test", "provider-form-status",
    "setup", "setup-refresh", "setup-import-mcp", "setup-auth-state", "setup-auth-rows",
    "setup-runtime-state", "setup-runtime-rows", "setup-desktop-state", "setup-desktop-rows",
    "setup-import-claude-desktop", "setup-mcp-state", "setup-mcp-rows", "setup-config-rows",
    "suite", "suite-refresh", "suite-write-status", "suite-write-moonclaw", "suite-status-state",
    "suite-app-count", "suite-capability-count", "suite-status-path", "suite-app-rows",
    "suite-integrations", "resilience", "resilience-app", "resilience-provider",
    "resilience-refresh", "resilience-auto-state", "resilience-circuit-state", "resilience-queue-count",
    "resilience-limit-state", "resilience-circuit-status", "circuit-form", "circuit-failure-threshold",
    "circuit-success-threshold", "circuit-timeout-seconds", "circuit-error-rate-threshold",
    "circuit-min-requests", "resilience-reset-circuit", "resilience-stream-status",
    "stream-form", "stream-timeout-secs", "stream-max-retries", "stream-degraded-threshold-ms",
    "stream-codex-model", "stream-claude-model", "stream-gemini-model", "stream-test-prompt",
    "resilience-stream-check", "resilience-toggle-auto", "failover-queue", "resilience-add-selected",
    "available-failover", "stream-check-results", "providers", "provider-count",
    "provider-rows", "usage", "app-usage", "model-usage", "usage-explorer", "usage-app",
    "usage-range", "usage-apply", "usage-filter-requests", "usage-filter-cost", "usage-filter-tokens",
    "usage-filter-cache", "usage-trends", "provider-usage", "filtered-model-usage",
    "requests", "request-log", "request-detail-panel", "request-detail-id", "request-detail",
    "error-box", "error-message", "toast", "toast-text",
  ]
}

///|
#warnings("-alert_unstable")
pub fn moongate_rabbita_shell_html(
  api_base? : String = "http://127.0.0.1:15721",
) -> String {
  @rabbita.render_to_string(
    @rabbita.static_cell(moongate_rabbita_shell_view(api_base~)),
  )
}

///|
pub fn moongate_rabbita_lepusa_manifest_json(
  api_base? : String = "http://127.0.0.1:15721",
) -> Json {
  Json::object({
    "identifier": Json::string("dev.vectie.moongate.rabbita"),
    "productName": Json::string("MoonGate Rabbita Preview"),
    "version": Json::string("0.1.0"),
    "rootHtml": Json::string(moongate_rabbita_shell_html(api_base~)),
    "runtime": Json::object({
      "backend": Json::string("system-webview"),
      "assetProtocol": Json::string("lepusa"),
      "devtools": Json::boolean(false),
    }),
    "window": Json::object({
      "label": Json::string("main"),
      "title": Json::string("MoonGate"),
      "width": Json::number(1180.0),
      "height": Json::number(780.0),
      "resizable": Json::boolean(true),
    }),
    "plugins": Json::array([
      Json::object({ "name": Json::string("localhost") }),
      Json::object({ "name": Json::string("serviceDiscovery") }),
      Json::object({ "name": Json::string("opener") }),
    ]),
    "capabilities": Json::array([
      Json::object({
        "name": Json::string("main"),
        "windows": Json::array([Json::string("main")]),
        "permissions": Json::array([
          Json::string("localhost"),
          Json::string("service-discovery"),
          Json::string("opener"),
        ]),
      }),
    ]),
    "startup": Json::object({
      "effect": Json::string("connect-moongate-rabbita-preview"),
    }),
  })
}

///|
pub fn moongate_rabbita_lepusa_manifest(
  api_base? : String = "http://127.0.0.1:15721",
) -> String {
  moongate_rabbita_lepusa_manifest_json(api_base~).stringify(indent=2)
}

///|
pub fn moongate_lepusa_manifest_json(port? : Int = 15721) -> Json {
  Json::object({
    "identifier": Json::string("dev.vectie.moongate"),
    "productName": Json::string("MoonGate"),
    "version": Json::string("0.1.0"),
    "runtime": Json::object({
      "backend": Json::string("system-webview"),
      "assetProtocol": Json::string("lepusa"),
      "devtools": Json::boolean(false),
    }),
    "bundleResources": Json::array([
      Json::object({
        "source": Json::string("public"),
        "path": Json::string("public"),
      }),
      Json::object({
        "source": Json::string("_build/native/release/build/cmd/main/main.exe"),
        "path": Json::string("moongate-server"),
        "executable": Json::boolean(true),
      }),
    ]),
    "window": Json::object({
      "label": Json::string("main"),
      "title": Json::string("MoonGate"),
      "width": Json::number(1180.0),
      "height": Json::number(780.0),
      "resizable": Json::boolean(true),
      "source": Json::object({
        "localhost": Json::object({
          "port": Json::number(port.to_double()),
          "path": Json::string("/ui/rabbita"),
          "readinessPath": Json::string("/health"),
          "command": Json::array([
            Json::string("moongate-server"),
            Json::string("start"),
          ]),
        }),
      }),
    }),
    "plugins": Json::array([
      Json::object({ "name": Json::string("localhost") }),
      Json::object({ "name": Json::string("serviceDiscovery") }),
      Json::object({ "name": Json::string("opener") }),
    ]),
    "capabilities": Json::array([
      Json::object({
        "name": Json::string("main"),
        "windows": Json::array([Json::string("main")]),
        "permissions": Json::array([
          Json::string("localhost"),
          Json::string("service-discovery"),
          Json::string("opener"),
        ]),
      }),
    ]),
    "startup": Json::object({ "effect": Json::string("connect-moongate") }),
  })
}

///|
pub fn moongate_lepusa_manifest(port? : Int = 15721) -> String {
  moongate_lepusa_manifest_json(port~).stringify(indent=2)
}
