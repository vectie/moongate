///|
fn moonstat_rabbita_shell_view(
  api_base? : String = "http://127.0.0.1:15721",
) -> @html.Html {
  @html.fragment([
    @html.link(rel="stylesheet", href="/assets/moonstat.css"),
    @html.div(
      class="shell",
      attrs=@html.Attrs::build()
        .data_set("moonstat-api-base", api_base)
        .data_set(
          "moonstat-framework-apps",
          moonstat_framework_apps_json().stringify(),
        ),
      [
        moonstat_rabbita_sidebar(),
        @html.main_(class="main", [
          moonstat_rabbita_topbar(),
          @html.section(class="status-grid", [
            moonstat_rabbita_metric_card(
              "Gateway", "gateway-state", "gateway-detail", "Loading status",
            ),
            moonstat_rabbita_metric_card(
              "Proxy", "proxy-state", "proxy-detail", "Loading proxy",
            ),
            moonstat_rabbita_metric_card(
              "Requests", "request-total", "request-total-detail", "Across all apps",
            ),
            moonstat_rabbita_metric_card(
              "Spend", "cost-total", "cost-detail", "Estimated total",
            ),
          ]),
          @html.section(class="panel-grid", [
            moonstat_rabbita_frameworks_panel(),
            moonstat_rabbita_provider_editor_panel(),
            moonstat_rabbita_setup_panel(),
            moonstat_rabbita_suite_panel(),
            moonstat_rabbita_resilience_panel(),
            moonstat_rabbita_provider_health_panel(),
            moonstat_rabbita_usage_panel(),
            moonstat_rabbita_stack_panel("Models", "Top Models", "model-usage"),
            moonstat_rabbita_usage_explorer_panel(),
            moonstat_rabbita_stack_panel(
              "Providers", "Provider Usage", "provider-usage",
            ),
            moonstat_rabbita_stack_panel(
              "Models", "Model Usage", "filtered-model-usage",
            ),
            moonstat_rabbita_request_log_panel(),
            moonstat_rabbita_request_detail_panel(),
          ]),
          @html.section(id="error-box", class="error-box", hidden=true, [
            @html.strong("Data refresh failed"),
            @html.p(id="error-message", ""),
          ]),
        ]),
      ],
    ),
    @html.script(src="/assets/moonstat-core.js", moonstat_rabbita_empty()),
    @html.script(src="/assets/moonstat.js", moonstat_rabbita_empty()),
  ])
}

///|
fn moonstat_rabbita_empty() -> Array[@html.Html] {
  []
}

///|
fn moonstat_rabbita_sidebar() -> @html.Html {
  @html.aside(
    class="sidebar",
    attrs=@html.Attrs::build().aria_label("Moonstat navigation"),
    [
      @html.div(class="brand", [
        @html.span(
          class="mark",
          attrs=@html.Attrs::build().aria_hidden("true"),
          "M",
        ),
        @html.div([@html.strong("Moonstat"), @html.span("Local gateway")]),
      ]),
      @html.nav(class="nav", [
        moonstat_rabbita_nav_link("#overview", "Overview"),
        moonstat_rabbita_nav_link("#providers", "Providers"),
        moonstat_rabbita_nav_link("#frameworks", "Frameworks"),
        moonstat_rabbita_nav_link("#setup", "Setup"),
        moonstat_rabbita_nav_link("#suite", "Suite"),
        moonstat_rabbita_nav_link("#resilience", "Resilience"),
        moonstat_rabbita_nav_link("#usage", "Usage"),
        moonstat_rabbita_nav_link("#usage-explorer", "Explorer"),
        moonstat_rabbita_nav_link("#requests", "Requests"),
      ]),
      @html.div(class="sidebar-footer", [
        @html.span(id="ui-updated", "Waiting for data"),
      ]),
    ],
  )
}

///|
fn moonstat_rabbita_nav_link(href : String, label : String) -> @html.Html {
  @html.a(href~, label)
}

///|
fn moonstat_rabbita_topbar() -> @html.Html {
  @html.section(id="overview", class="topbar", [
    @html.div([
      @html.p(class="eyebrow", "Operator Console"),
      @html.h1("Proxy, providers, and spend in one place."),
    ]),
    @html.div(class="actions", [
      @html.button(id="refresh", type_="button", "Refresh"),
      @html.button(id="proxy-start", type_="button", "Start Proxy"),
      @html.button(
        id="proxy-stop",
        class="danger",
        type_="button",
        "Stop Proxy",
      ),
      @html.a(
        class="button-secondary",
        href="/metrics",
        rel="noreferrer",
        "Metrics",
      ),
    ]),
  ])
}

///|
fn moonstat_rabbita_metric_card(
  label : String,
  value_id : String,
  detail_id : String,
  detail : String,
) -> @html.Html {
  @html.article(class="metric-card", [
    @html.span(label),
    @html.strong(id=value_id, "-"),
    @html.small(id=detail_id, detail),
  ])
}

///|
fn moonstat_rabbita_panel_head(
  eyebrow : String,
  title : String,
  actions : Array[@html.Html],
) -> @html.Html {
  @html.div(class="panel-head", [
    @html.div([@html.p(class="eyebrow", eyebrow), @html.h2(title)]),
    @html.fragment(actions),
  ])
}

///|
fn moonstat_rabbita_table(
  headers : Array[String],
  body_id : String,
) -> @html.Html {
  @html.div(class="table-wrap", [
    @html.table([
      @html.thead([@html.tr(headers.map(fn(header) { @html.th(header) }))]),
      @html.tbody(id=body_id, moonstat_rabbita_empty()),
    ]),
  ])
}

///|
fn moonstat_rabbita_frameworks_panel() -> @html.Html {
  @html.article(id="frameworks", class="panel wide", [
    moonstat_rabbita_panel_head("Frameworks", "Provider Control", [
      @html.button(
        id="sync-live",
        class="button-secondary",
        type_="button",
        "Sync Live",
      ),
    ]),
    moonstat_rabbita_table(
      ["Framework", "Mode", "Current", "Providers", "Action"],
      "framework-rows",
    ),
  ])
}

///|
fn moonstat_rabbita_provider_editor_panel() -> @html.Html {
  @html.article(id="provider-editor", class="panel wide", [
    moonstat_rabbita_panel_head("Providers", "Provider Editor", [
      @html.button(
        id="provider-clear",
        class="button-secondary",
        type_="button",
        "New Provider",
      ),
    ]),
    @html.form(id="provider-form", class="form-grid", [
      @html.input(input_type=Hidden, id="provider-original-id"),
      moonstat_rabbita_select_label("Framework", "provider-app", []),
      moonstat_rabbita_input_label("Provider ID", "provider-id", "", true),
      moonstat_rabbita_input_label("Name", "provider-name", "", true),
      moonstat_rabbita_input_label(
        "Provider Type", "provider-type", "openrouter, codex_oauth, gemini", false,
      ),
      moonstat_rabbita_input_label(
        "Base URL",
        "provider-base-url",
        "https://api.example.com",
        false,
        class="span-2",
      ),
      moonstat_rabbita_select_label("API Format", "provider-api-format", [
        ("", "Default"),
        ("openai", "OpenAI"),
        ("anthropic", "Anthropic"),
        ("gemini_native", "Gemini Native"),
      ]),
      moonstat_rabbita_password_label("API Key", "provider-api-key"),
      moonstat_rabbita_input_label(
        "Default Model", "provider-default-model", "", false,
      ),
      moonstat_rabbita_input_label(
        "Sonnet Model", "provider-sonnet-model", "", false,
      ),
      moonstat_rabbita_input_label(
        "Haiku Model", "provider-haiku-model", "", false,
      ),
      moonstat_rabbita_input_label(
        "Opus Model", "provider-opus-model", "", false,
      ),
      @html.label(class="span-2", [
        @html.span("Notes"),
        @html.textarea(id="provider-notes", rows=3, moonstat_rabbita_empty()),
      ]),
      @html.div(class="check-row span-2", [
        moonstat_rabbita_check_label("provider-enabled", "Enabled", true),
        moonstat_rabbita_check_label("provider-full-url", "Full URL", false),
        moonstat_rabbita_check_label(
          "provider-fast-mode", "Codex Fast Mode", false,
        ),
      ]),
      @html.div(class="form-actions span-2", [
        @html.button(id="provider-save", type_="submit", "Save Provider"),
        @html.button(
          id="provider-delete",
          class="danger",
          type_="button",
          "Delete Provider",
        ),
        @html.button(
          id="provider-test",
          class="button-secondary",
          type_="button",
          "Test Provider",
        ),
        @html.span(id="provider-form-status", ""),
      ]),
    ]),
  ])
}

///|
fn moonstat_rabbita_setup_panel() -> @html.Html {
  @html.article(id="setup", class="panel wide", [
    moonstat_rabbita_panel_head("Setup", "Integration Status", [
      @html.div(class="inline-actions", [
        @html.button(
          id="setup-refresh",
          class="button-secondary",
          type_="button",
          "Refresh Setup",
        ),
        @html.button(
          id="setup-import-mcp",
          class="button-secondary",
          type_="button",
          "Import MCP Apps",
        ),
      ]),
    ]),
    @html.div(class="setup-grid", [
      moonstat_rabbita_setup_card("Auth", "setup-auth-state", "setup-auth-rows"),
      moonstat_rabbita_setup_card(
        "Runtime", "setup-runtime-state", "setup-runtime-rows",
      ),
      @html.div(class="setup-card", [
        @html.div(class="setup-card-head", [
          @html.strong("Claude Desktop"),
          @html.span(id="setup-desktop-state", class="state warn", "Loading"),
        ]),
        @html.div(
          id="setup-desktop-rows",
          class="setup-list",
          moonstat_rabbita_empty(),
        ),
        @html.div(class="inline-actions", [
          @html.button(
            id="setup-import-claude-desktop",
            type_="button",
            "Import Claude Desktop",
          ),
        ]),
      ]),
      moonstat_rabbita_setup_card(
        "MCP and Plugin", "setup-mcp-state", "setup-mcp-rows",
      ),
    ]),
    @html.div(class="table-wrap setup-table-wrap", [
      @html.table([
        @html.thead([
          @html.tr(
            ["Framework", "Config", "Proxy Takeover", "Action"].map(fn(header) {
              @html.th(header)
            }),
          ),
        ]),
        @html.tbody(id="setup-config-rows", moonstat_rabbita_empty()),
      ]),
    ]),
  ])
}

///|
fn moonstat_rabbita_setup_card(
  title : String,
  state_id : String,
  rows_id : String,
) -> @html.Html {
  @html.div(class="setup-card", [
    @html.div(class="setup-card-head", [
      @html.strong(title),
      @html.span(id=state_id, class="state warn", "Loading"),
    ]),
    @html.div(id=rows_id, class="setup-list", moonstat_rabbita_empty()),
  ])
}

///|
fn moonstat_rabbita_suite_panel() -> @html.Html {
  @html.article(id="suite", class="panel wide", [
    moonstat_rabbita_panel_head("Suite", "Moon Suite Integration", [
      @html.div(class="inline-actions", [
        @html.button(
          id="suite-refresh",
          class="button-secondary",
          type_="button",
          "Refresh Suite",
        ),
        @html.button(id="suite-write-status", type_="button", "Write Status"),
        @html.button(
          id="suite-write-moonclaw",
          class="button-secondary",
          type_="button",
          "Write MoonClaw",
        ),
      ]),
    ]),
    @html.div(class="usage-metrics", [
      moonstat_rabbita_status_value("Status", "suite-status-state"),
      moonstat_rabbita_status_value("Apps", "suite-app-count"),
      moonstat_rabbita_status_value("Capabilities", "suite-capability-count"),
      moonstat_rabbita_status_value("Status File", "suite-status-path"),
    ]),
    moonstat_rabbita_table(
      ["App", "Role", "Usage", "Key Route"],
      "suite-app-rows",
    ),
    @html.div(id="suite-integrations", class="stack", moonstat_rabbita_empty()),
  ])
}

///|
fn moonstat_rabbita_resilience_panel() -> @html.Html {
  @html.article(id="resilience", class="panel wide", [
    moonstat_rabbita_panel_head("Routing", "Resilience Control", [
      @html.div(class="filter-row", [
        @html.select(
          id="resilience-app",
          attrs=@html.Attrs::build().aria_label("Resilience framework"),
          moonstat_rabbita_empty(),
        ),
        @html.select(
          id="resilience-provider",
          attrs=@html.Attrs::build().aria_label("Resilience provider"),
          moonstat_rabbita_empty(),
        ),
        @html.button(
          id="resilience-refresh",
          class="button-secondary",
          type_="button",
          "Refresh",
        ),
      ]),
    ]),
    @html.div(class="usage-metrics", [
      moonstat_rabbita_status_value("Auto Failover", "resilience-auto-state"),
      moonstat_rabbita_status_value("Circuit", "resilience-circuit-state"),
      moonstat_rabbita_status_value("Queue", "resilience-queue-count"),
      moonstat_rabbita_status_value("Limits", "resilience-limit-state"),
    ]),
    @html.div(class="resilience-grid", [
      moonstat_rabbita_circuit_card(),
      moonstat_rabbita_stream_card(),
    ]),
    @html.div(class="resilience-grid", [
      @html.div(class="setup-card", [
        @html.div(class="setup-card-head", [
          @html.strong("Failover Queue"),
          @html.button(
            id="resilience-toggle-auto",
            class="button-secondary",
            type_="button",
            "Toggle Auto",
          ),
        ]),
        @html.div(id="failover-queue", class="stack", moonstat_rabbita_empty()),
      ]),
      @html.div(class="setup-card", [
        @html.div(class="setup-card-head", [
          @html.strong("Available Providers"),
          @html.button(
            id="resilience-add-selected",
            class="button-secondary",
            type_="button",
            "Add Selected",
          ),
        ]),
        @html.div(
          id="available-failover",
          class="stack",
          moonstat_rabbita_empty(),
        ),
      ]),
    ]),
    @html.div(
      id="stream-check-results",
      class="log-list",
      moonstat_rabbita_empty(),
    ),
  ])
}

///|
fn moonstat_rabbita_circuit_card() -> @html.Html {
  @html.div(class="setup-card", [
    @html.div(class="setup-card-head", [
      @html.strong("Circuit Breaker"),
      @html.span(id="resilience-circuit-status", class="state warn", "Loading"),
    ]),
    @html.form(id="circuit-form", class="compact-form", [
      moonstat_rabbita_input_label(
        "Failure Threshold",
        "circuit-failure-threshold",
        "",
        false,
        inputmode="numeric",
      ),
      moonstat_rabbita_input_label(
        "Success Threshold",
        "circuit-success-threshold",
        "",
        false,
        inputmode="numeric",
      ),
      moonstat_rabbita_input_label(
        "Timeout Seconds",
        "circuit-timeout-seconds",
        "",
        false,
        inputmode="numeric",
      ),
      moonstat_rabbita_input_label(
        "Error Rate",
        "circuit-error-rate-threshold",
        "",
        false,
        inputmode="decimal",
      ),
      moonstat_rabbita_input_label(
        "Min Requests",
        "circuit-min-requests",
        "",
        false,
        inputmode="numeric",
      ),
      @html.div(class="inline-actions", [
        @html.button(type_="submit", "Save Circuit"),
        @html.button(
          id="resilience-reset-circuit",
          class="button-secondary",
          type_="button",
          "Reset Selected",
        ),
      ]),
    ]),
  ])
}

///|
fn moonstat_rabbita_stream_card() -> @html.Html {
  @html.div(class="setup-card", [
    @html.div(class="setup-card-head", [
      @html.strong("Stream Check"),
      @html.span(id="resilience-stream-status", class="state warn", "Loading"),
    ]),
    @html.form(id="stream-form", class="compact-form", [
      moonstat_rabbita_input_label(
        "Timeout Seconds",
        "stream-timeout-secs",
        "",
        false,
        inputmode="numeric",
      ),
      moonstat_rabbita_input_label(
        "Max Retries",
        "stream-max-retries",
        "",
        false,
        inputmode="numeric",
      ),
      moonstat_rabbita_input_label(
        "Degraded MS",
        "stream-degraded-threshold-ms",
        "",
        false,
        inputmode="numeric",
      ),
      moonstat_rabbita_input_label(
        "Codex Model", "stream-codex-model", "", false,
      ),
      moonstat_rabbita_input_label(
        "Claude Model", "stream-claude-model", "", false,
      ),
      moonstat_rabbita_input_label(
        "Gemini Model", "stream-gemini-model", "", false,
      ),
      moonstat_rabbita_input_label(
        "Prompt",
        "stream-test-prompt",
        "",
        false,
        class="span-2",
      ),
      @html.div(class="inline-actions span-2", [
        @html.button(type_="submit", "Save Stream"),
        @html.button(
          id="resilience-stream-check",
          class="button-secondary",
          type_="button",
          "Check App",
        ),
      ]),
    ]),
  ])
}

///|
fn moonstat_rabbita_provider_health_panel() -> @html.Html {
  @html.article(id="providers", class="panel wide", [
    moonstat_rabbita_panel_head("Routing", "Provider Health", [
      @html.span(id="provider-count", class="pill", "0 providers"),
    ]),
    moonstat_rabbita_table(
      ["Provider", "App", "Status", "Model", "Last Error"],
      "provider-rows",
    ),
  ])
}

///|
fn moonstat_rabbita_usage_panel() -> @html.Html {
  @html.article(id="usage", class="panel", [
    moonstat_rabbita_panel_head("Usage", "By App", []),
    @html.div(id="app-usage", class="stack", moonstat_rabbita_empty()),
  ])
}

///|
fn moonstat_rabbita_stack_panel(
  eyebrow : String,
  title : String,
  id : String,
) -> @html.Html {
  @html.article(class="panel", [
    moonstat_rabbita_panel_head(eyebrow, title, []),
    @html.div(id~, class="stack", moonstat_rabbita_empty()),
  ])
}

///|
fn moonstat_rabbita_usage_explorer_panel() -> @html.Html {
  @html.article(id="usage-explorer", class="panel wide", [
    moonstat_rabbita_panel_head("Statistics", "Usage Explorer", [
      @html.div(class="filter-row", [
        @html.select(
          id="usage-app",
          attrs=@html.Attrs::build().aria_label("Usage framework"),
          moonstat_rabbita_empty(),
        ),
        @html.select(
          id="usage-range",
          attrs=@html.Attrs::build().aria_label("Usage range"),
          [
            @html.option(value="86400", "24 hours"),
            @html.option(value="604800", selected=true, "7 days"),
            @html.option(value="2592000", "30 days"),
            @html.option(value="all", "All time"),
          ],
        ),
        @html.button(
          id="usage-apply",
          class="button-secondary",
          type_="button",
          "Apply",
        ),
      ]),
    ]),
    @html.div(class="usage-metrics", [
      moonstat_rabbita_status_value("Requests", "usage-filter-requests"),
      moonstat_rabbita_status_value("Cost", "usage-filter-cost"),
      moonstat_rabbita_status_value("Tokens", "usage-filter-tokens"),
      moonstat_rabbita_status_value("Cache Hit", "usage-filter-cache"),
    ]),
    @html.div(id="usage-trends", class="trend-bars", moonstat_rabbita_empty()),
  ])
}

///|
fn moonstat_rabbita_request_log_panel() -> @html.Html {
  @html.article(id="requests", class="panel wide", [
    moonstat_rabbita_panel_head("Recent", "Request Log", [
      @html.a(class="text-link", href="/usage/logs", rel="noreferrer", "JSON"),
    ]),
    @html.div(id="request-log", class="log-list", moonstat_rabbita_empty()),
  ])
}

///|
fn moonstat_rabbita_request_detail_panel() -> @html.Html {
  @html.article(id="request-detail-panel", class="panel wide", [
    moonstat_rabbita_panel_head("Request", "Request Detail", [
      @html.span(id="request-detail-id", class="pill", "No selection"),
    ]),
    @html.div(
      id="request-detail",
      class="detail-grid",
      moonstat_rabbita_empty(),
    ),
  ])
}

///|
fn moonstat_rabbita_status_value(label : String, id : String) -> @html.Html {
  @html.div([@html.span(label), @html.strong(id~, "-")])
}

///|
fn moonstat_rabbita_input_label(
  label : String,
  id : String,
  placeholder : String,
  required : Bool,
  class? : String,
  inputmode? : String,
) -> @html.Html {
  @html.label(class?, [
    @html.span(label),
    match inputmode {
      Some(mode) => @html.input(id~, placeholder~, required~, inputmode=mode)
      None => @html.input(id~, placeholder~, required~)
    },
  ])
}

///|
fn moonstat_rabbita_password_label(label : String, id : String) -> @html.Html {
  @html.label([@html.span(label), @html.input(input_type=Password, id~)])
}

///|
fn moonstat_rabbita_select_label(
  label : String,
  id : String,
  options : Array[(String, String)],
) -> @html.Html {
  @html.label([
    @html.span(label),
    @html.select(
      id~,
      options.map(fn(option) {
        let (value, text) = option
        @html.option(value~, text)
      }),
    ),
  ])
}

///|
fn moonstat_rabbita_check_label(
  id : String,
  label : String,
  checked : Bool,
) -> @html.Html {
  @html.label([
    @html.input(input_type=Checkbox, id~, checked~),
    @html.text(" \{label}"),
  ])
}

///|
#warnings("-alert_unstable")
pub fn moonstat_rabbita_document_html(
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
          @html.title("Moonstat"),
        ]),
        @html.body([moonstat_rabbita_shell_view(api_base~)]),
      ]),
    ),
  )
}

///|
pub fn moonstat_rabbita_shell_dom_ids() -> Array[String] {
  [
    "ui-updated", "overview", "refresh", "proxy-start", "proxy-stop", "gateway-state",
    "gateway-detail", "proxy-state", "proxy-detail", "request-total", "request-total-detail",
    "cost-total", "cost-detail", "frameworks", "framework-rows", "sync-live", "provider-editor",
    "provider-form", "provider-original-id", "provider-app", "provider-id", "provider-name",
    "provider-type", "provider-base-url", "provider-api-format", "provider-api-key",
    "provider-default-model", "provider-sonnet-model", "provider-haiku-model", "provider-opus-model",
    "provider-notes", "provider-enabled", "provider-full-url", "provider-fast-mode",
    "provider-save", "provider-delete", "provider-test", "provider-form-status",
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
    "error-box", "error-message",
  ]
}

///|
#warnings("-alert_unstable")
pub fn moonstat_rabbita_shell_html(
  api_base? : String = "http://127.0.0.1:15721",
) -> String {
  @rabbita.render_to_string(
    @rabbita.static_cell(moonstat_rabbita_shell_view(api_base~)),
  )
}

///|
pub fn moonstat_rabbita_lepusa_manifest_json(
  api_base? : String = "http://127.0.0.1:15721",
) -> Json {
  Json::object({
    "identifier": Json::string("dev.vectie.moonstat.rabbita"),
    "productName": Json::string("Moonstat Rabbita Preview"),
    "version": Json::string("0.1.0"),
    "rootHtml": Json::string(moonstat_rabbita_shell_html(api_base~)),
    "runtime": Json::object({
      "backend": Json::string("system-webview"),
      "assetProtocol": Json::string("lepusa"),
      "devtools": Json::boolean(false),
    }),
    "window": Json::object({
      "label": Json::string("main"),
      "title": Json::string("Moonstat"),
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
      "effect": Json::string("connect-moonstat-rabbita-preview"),
    }),
  })
}

///|
pub fn moonstat_rabbita_lepusa_manifest(
  api_base? : String = "http://127.0.0.1:15721",
) -> String {
  moonstat_rabbita_lepusa_manifest_json(api_base~).stringify(indent=2)
}

///|
pub fn moonstat_lepusa_manifest_json(port? : Int = 15721) -> Json {
  Json::object({
    "identifier": Json::string("dev.vectie.moonstat"),
    "productName": Json::string("Moonstat"),
    "version": Json::string("0.1.0"),
    "runtime": Json::object({
      "backend": Json::string("system-webview"),
      "assetProtocol": Json::string("lepusa"),
      "devtools": Json::boolean(false),
    }),
    "window": Json::object({
      "label": Json::string("main"),
      "title": Json::string("Moonstat"),
      "width": Json::number(1180.0),
      "height": Json::number(780.0),
      "resizable": Json::boolean(true),
      "source": Json::object({
        "localhost": Json::object({
          "port": Json::number(port.to_double()),
          "path": Json::string("/ui/rabbita"),
          "readinessPath": Json::string("/health"),
          "command": Json::array([
            Json::string("moon"),
            Json::string("run"),
            Json::string("cmd/main"),
            Json::string("--"),
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
    "startup": Json::object({ "effect": Json::string("connect-moonstat") }),
  })
}

///|
pub fn moonstat_lepusa_manifest(port? : Int = 15721) -> String {
  moonstat_lepusa_manifest_json(port~).stringify(indent=2)
}
