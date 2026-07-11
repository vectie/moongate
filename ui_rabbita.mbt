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
        )
        .data_set(
          "moonstat-endpoints",
          moonstat_ui_endpoints_json().stringify(),
        )
        .data_set(
          "moonstat-readiness-cards",
          moonstat_ui_readiness_cards_json().stringify(),
        )
        .data_set("moonstat-sections", moonstat_ui_sections_json().stringify()),
      [
        moonstat_rabbita_sidebar(),
        @html.main_(class="main", [
          moonstat_rabbita_topbar(),
          moonstat_rabbita_readiness_strip(),
          moonstat_rabbita_operator_workflow(),
          moonstat_rabbita_connection_board(),
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
    @html.script(src="/assets/moonstat-frameworks.js", moonstat_rabbita_empty()),
    @html.script(src="/assets/moonstat-usage.js", moonstat_rabbita_empty()),
    @html.script(src="/assets/moonstat-setup.js", moonstat_rabbita_empty()),
    @html.script(src="/assets/moonstat-suite.js", moonstat_rabbita_empty()),
    @html.script(src="/assets/moonstat-resilience.js", moonstat_rabbita_empty()),
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
    attrs=@html.Attrs::build().aria_label("MoonGate navigation"),
    [
      @html.div(class="brand", [
        @html.span(
          class="mark",
          attrs=@html.Attrs::build().aria_hidden("true"),
          "M",
        ),
        @html.div([@html.strong("MoonGate"), @html.span("Local gateway")]),
      ]),
      @html.nav(
        class="nav",
        moonstat_ui_sections().map(fn(section) {
          let (id, label) = section
          moonstat_rabbita_nav_link("#\{id}", label)
        }),
      ),
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
fn moonstat_rabbita_readiness_strip() -> @html.Html {
  @html.section(
    id="readiness",
    class="readiness-strip",
    attrs=@html.Attrs::build().aria_label("MoonGate readiness"),
    [
      @html.div(class="readiness-head", [
        @html.p(class="eyebrow", "Readiness"),
        @html.strong("Standalone gateway checklist"),
      ]),
      @html.div(
        id="readiness-cards",
        class="readiness-cards",
        moonstat_rabbita_empty(),
      ),
    ],
  )
}

///|
fn moonstat_rabbita_operator_workflow() -> @html.Html {
  @html.section(id="operator-actions", class="operator-workflow", [
    @html.div(class="operator-workflow-head", [
      @html.div([
        @html.p(class="eyebrow", "Workflow"),
        @html.h2("Operator Actions"),
      ]),
      @html.span(id="operator-action-status", "Ready"),
    ]),
    @html.div(class="operator-action-grid", [
      moonstat_rabbita_operator_action(
        "start-proxy", "Start Proxy", "Bring local routing online",
      ),
      moonstat_rabbita_operator_action(
        "sync-live", "Sync Providers", "Import current live configuration",
      ),
      moonstat_rabbita_operator_action(
        "refresh-setup", "Check Setup", "Validate auth, tools, MCP, and config",
      ),
      moonstat_rabbita_operator_action(
        "stream-check", "Check Streams", "Probe selected framework providers",
      ),
      moonstat_rabbita_operator_action(
        "write-suite", "Write Suite Status", "Publish Moon suite discovery state",
      ),
    ]),
  ])
}

///|
fn moonstat_rabbita_operator_action(
  action : String,
  title : String,
  detail : String,
) -> @html.Html {
  @html.button(
    type_="button",
    class="operator-action",
    attrs=@html.Attrs::build().data_set("operator-action", action),
    [@html.strong(title), @html.span(detail)],
  )
}

///|
fn moonstat_rabbita_connection_board() -> @html.Html {
  @html.section(id="connection-board", class="connection-board", [
    @html.div(class="connection-head", [
      @html.div([
        @html.p(class="eyebrow", "Connect"),
        @html.h2("Client Endpoints"),
      ]),
      @html.span(id="connection-copy-status", "Copy full URLs"),
    ]),
    @html.div(class="connection-grid", [
      moonstat_rabbita_connection_card(
        "OpenAI Chat", "/v1/chat/completions", "OpenAI-compatible clients",
      ),
      moonstat_rabbita_connection_card(
        "OpenAI Responses", "/v1/responses", "Codex-style responses clients",
      ),
      moonstat_rabbita_connection_card(
        "Anthropic Messages", "/v1/messages", "Claude-compatible clients",
      ),
      moonstat_rabbita_connection_card(
        "Claude Desktop", "/claude-desktop/v1/messages", "Desktop gateway route",
      ),
      moonstat_rabbita_connection_card(
        "OpenClaw", "/openclaw/v1/chat/completions", "OpenClaw chat route",
      ),
      moonstat_rabbita_connection_card(
        "Metrics", "/metrics", "Prometheus scrape",
      ),
    ]),
    @html.div(class="snippet-grid", [
      moonstat_rabbita_connection_snippet(
        "OpenAI env", "openai-env", "Base URL for OpenAI-compatible clients",
      ),
      moonstat_rabbita_connection_snippet(
        "Anthropic env", "anthropic-env", "Base URL for Claude-compatible clients",
      ),
      moonstat_rabbita_connection_snippet(
        "OpenClaw env", "openclaw-env", "Base URL for OpenClaw clients",
      ),
      moonstat_rabbita_connection_snippet(
        "Metrics URL", "metrics-url", "Prometheus scrape target",
      ),
    ]),
  ])
}

///|
fn moonstat_rabbita_connection_card(
  title : String,
  path : String,
  detail : String,
) -> @html.Html {
  @html.article(class="connection-card", [
    @html.div([@html.strong(title), @html.small(detail)]),
    @html.code(attrs=@html.Attrs::build().data_set("url-path", path), path),
    @html.button(
      type_="button",
      class="button-secondary",
      attrs=@html.Attrs::build().data_set("copy-path", path),
      "Copy",
    ),
  ])
}

///|
fn moonstat_rabbita_connection_snippet(
  title : String,
  snippet : String,
  detail : String,
) -> @html.Html {
  @html.article(class="snippet-card", [
    @html.div([@html.strong(title), @html.small(detail)]),
    @html.code(attrs=@html.Attrs::build().data_set("snippet", snippet), ""),
    @html.button(
      type_="button",
      class="button-secondary",
      attrs=@html.Attrs::build().data_set("copy-snippet", snippet),
      "Copy",
    ),
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
