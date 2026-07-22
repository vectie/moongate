///|
fn moongate_rabbita_shell_view(
  api_base? : String = "http://127.0.0.1:15721",
) -> @html.Html {
  @html.fragment([
    @html.link(rel="stylesheet", href="/assets/moongate.css"),
    @html.div(
      class="shell",
      attrs=@html.Attrs::build()
        .data_set("moongate-api-base", api_base)
        .data_set(
          "moongate-framework-apps",
          moongate_framework_apps_json().stringify(),
        )
        .data_set(
          "moongate-endpoints",
          moongate_ui_endpoints_json().stringify(),
        )
        .data_set(
          "moongate-readiness-cards",
          moongate_ui_readiness_cards_json().stringify(),
        )
        .data_set("moongate-sections", moongate_ui_sections_json().stringify()),
      [
        moongate_rabbita_sidebar(),
        @html.main_(class="main", [
          moongate_rabbita_topbar(),
          moongate_rabbita_overview_page(),
          moongate_rabbita_connect_page(),
          moongate_rabbita_setup_page(),
          moongate_rabbita_routing_page(),
          moongate_rabbita_providers_page(),
          moongate_rabbita_requests_page(),
          moongate_rabbita_usage_page(),
          moongate_rabbita_suite_page(),
          moongate_rabbita_guide_page(),
          @html.section(id="error-box", class="error-box", hidden=true, [
            @html.strong("Data refresh failed"),
            @html.p(id="error-message", ""),
          ]),
        ]),
      ],
    ),
    @html.div(
      id="toast",
      class="toast",
      attrs=@html.Attrs::build().aria_live("polite"),
      [@html.span(class="dot good", ""), @html.span(id="toast-text", "Copied")],
    ),
    @html.script(src="/assets/moonsuite-i18n.js", moongate_rabbita_empty()),
    @html.script(src="/assets/moongate-core.js", moongate_rabbita_empty()),
    @html.script(src="/assets/moongate-frameworks.js", moongate_rabbita_empty()),
    @html.script(src="/assets/moongate-usage.js", moongate_rabbita_empty()),
    @html.script(src="/assets/moongate-setup.js", moongate_rabbita_empty()),
    @html.script(src="/assets/moongate-suite.js", moongate_rabbita_empty()),
    @html.script(src="/assets/moongate-resilience.js", moongate_rabbita_empty()),
    @html.script(src="/assets/moongate.js", moongate_rabbita_empty()),
  ])
}

///|
fn moongate_rabbita_empty() -> Array[@html.Html] {
  []
}

///|
fn moongate_rabbita_sidebar() -> @html.Html {
  @html.aside(
    class="sidebar",
    attrs=@html.Attrs::build().aria_label("MoonGate navigation"),
    [
      @html.div(class="brand", [
        @html.img(
          class="brand-mark",
          src="/assets/moongate.svg",
          alt="",
          width=32,
          height=32,
          attrs=@html.Attrs::build().aria_hidden("true"),
        ),
        @html.div(class="brand-copy", [
          @html.strong("MoonGate"),
          @html.span("Local AI router"),
        ]),
      ]),
      @html.nav(id="nav", class="nav", [
        moongate_rabbita_nav_group("Start"),
        moongate_rabbita_nav_link("overview", "OV", "Overview", active=true),
        moongate_rabbita_nav_link("connect", "CN", "Connect"),
        moongate_rabbita_nav_link("setup", "ST", "Setup"),
        moongate_rabbita_nav_group("Configure"),
        moongate_rabbita_nav_link("routing", "RT", "Routing"),
        moongate_rabbita_nav_link("providers", "PR", "Providers"),
        moongate_rabbita_nav_link("requests", "RQ", "Requests"),
        moongate_rabbita_nav_group("Review"),
        moongate_rabbita_nav_link("usage", "US", "Usage"),
        moongate_rabbita_nav_link("suite", "SU", "Suite"),
        moongate_rabbita_nav_link("guide", "?", "Guide"),
      ]),
      @html.div(class="sidebar-footer", [
        @html.div(class="sidebar-status", [
          @html.span(id="sidebar-gateway-dot", class="dot warn", ""),
          @html.div([
            @html.strong(id="sidebar-gateway-state", "Gateway connecting"),
            @html.span(id="ui-updated", "Waiting for data"),
          ]),
        ]),
      ]),
    ],
  )
}

///|
fn moongate_rabbita_nav_group(label : String) -> @html.Html {
  @html.span(class="nav-group-label", label)
}

///|
fn moongate_rabbita_nav_link(
  page : String,
  icon : String,
  label : String,
  active? : Bool = false,
) -> @html.Html {
  @html.a(
    href="#\{page}",
    class=if active { "nav-item active" } else { "nav-item" },
    attrs=@html.Attrs::build().data_set("page", page),
    [
      @html.span(
        class="nav-icon",
        attrs=@html.Attrs::build().aria_hidden("true"),
        icon,
      ),
      @html.span(class="nav-label", label),
    ],
  )
}

///|
fn moongate_rabbita_topbar() -> @html.Html {
  @html.header(class="topbar", [
    @html.div(class="topbar-title", [
      @html.h1(id="page-title", "Overview"),
      @html.p(
        id="page-subtitle",
        "See whether MoonGate is ready, which provider is in use, and what it has handled.",
      ),
    ]),
    @html.div(class="topbar-actions", [
      @html.span(id="topbar-updated", class="updated-chip", "Updating…"),
      @html.span(class="env-chip", [
        @html.span(id="gateway-dot", class="dot warn", ""),
        @html.code(id="gateway-endpoint", "Connecting…"),
      ]),
      @html.button(
        id="refresh",
        class="button-secondary",
        type_="button",
        "Refresh",
      ),
    ]),
  ])
}

///|
fn moongate_rabbita_page(
  id : String,
  title : String,
  subtitle : String,
  active : Bool,
  children : Array[@html.Html],
) -> @html.Html {
  @html.section(
    id="page-\{id}",
    class=if active { "page active" } else { "page" },
    attrs=@html.Attrs::build()
      .data_set("page-view", id)
      .data_set("page-title", title)
      .data_set("page-subtitle", subtitle),
    children,
  )
}

///|
fn moongate_rabbita_overview_page() -> @html.Html {
  moongate_rabbita_page(
    "overview",
    "Overview",
    "See whether MoonGate is ready, which provider is in use, and what it has handled.",
    true,
    [
      @html.section(id="overview", class="hero", [
        @html.div(class="hero-state", [
          @html.span(id="gateway-hero-dot", class="dot warn", ""),
          @html.div(class="hero-text", [
            @html.strong([
              @html.text("MoonGate "),
              @html.span(id="gateway-state", "Loading"),
            ]),
            @html.small(id="gateway-detail", "Connecting to the local API"),
          ]),
        ]),
        @html.div(class="hero-stats", [
          @html.div(class="hero-stat", [
            @html.span("AI routing"),
            @html.strong(id="proxy-state", "Loading"),
            @html.small(id="proxy-detail", "Checking route state"),
          ]),
          @html.div(class="hero-stat", [
            @html.span("Settings access"),
            @html.strong("This Mac only"),
            @html.small("Other devices cannot change settings"),
          ]),
        ]),
        @html.div(class="hero-actions", [
          @html.button(
            id="proxy-stop",
            class="danger-ghost",
            type_="button",
            "Stop Routing",
          ),
          @html.button(id="proxy-start", type_="button", "Start Routing"),
          @html.button(
            class="button-secondary",
            type_="button",
            attrs=@html.Attrs::build().data_set("goto", "usage"),
            "View Usage",
          ),
        ]),
      ]),
      @html.section(class="status-grid", [
        moongate_rabbita_metric_card(
          "Requests", "request-total", "request-total-detail", "Across all apps",
        ),
        moongate_rabbita_metric_card(
          "Spend", "cost-total", "cost-detail", "Estimated total",
        ),
        moongate_rabbita_metric_card(
          "Supported apps", "framework-total", "framework-detail", "AI app types",
        ),
        moongate_rabbita_metric_card(
          "Local port", "gateway-port", "gateway-port-detail", "Used by apps on this Mac",
        ),
      ]),
      @html.div(class="overview-grid", [
        moongate_rabbita_readiness_strip(),
        @html.article(class="panel overview-models", [
          moongate_rabbita_panel_head("Traffic", "Top Models", []),
          @html.div(id="model-usage", class="stack", moongate_rabbita_empty()),
        ]),
      ]),
      moongate_rabbita_quick_connect(),
    ],
  )
}

///|
fn moongate_rabbita_connect_page() -> @html.Html {
  moongate_rabbita_page(
    "connect",
    "Connect",
    "Copy the API address or command-line settings requested by another AI app.",
    false,
    [moongate_rabbita_connection_board()],
  )
}

///|
fn moongate_rabbita_setup_page() -> @html.Html {
  moongate_rabbita_page(
    "setup",
    "Setup",
    "Check sign-ins and whether installed AI apps are configured to use MoonGate.",
    false,
    [moongate_rabbita_setup_panel()],
  )
}

///|
fn moongate_rabbita_routing_page() -> @html.Html {
  moongate_rabbita_page(
    "routing",
    "Routing",
    "Choose which provider each AI app uses; backups are available under Advanced.",
    false,
    [moongate_rabbita_frameworks_panel(), moongate_rabbita_resilience_panel()],
  )
}

///|
fn moongate_rabbita_providers_page() -> @html.Html {
  moongate_rabbita_page(
    "providers",
    "Providers",
    "Add providers, test their real connection, and select or stop a routing profile.",
    false,
    [
      @html.div(class="master-detail provider-master-detail", [
        moongate_rabbita_provider_health_panel(),
        moongate_rabbita_provider_editor_panel(),
      ]),
    ],
  )
}

///|
fn moongate_rabbita_requests_page() -> @html.Html {
  moongate_rabbita_page(
    "requests",
    "Requests",
    "See each AI request, which provider handled it, its cost, and whether it succeeded.",
    false,
    [
      @html.div(class="master-detail request-master-detail", [
        moongate_rabbita_request_log_panel(),
        moongate_rabbita_request_detail_panel(),
      ]),
    ],
  )
}

///|
fn moongate_rabbita_usage_page() -> @html.Html {
  moongate_rabbita_page(
    "usage",
    "Usage",
    "Review requests, tokens, reused input, and estimated spend over time.",
    false,
    [
      moongate_rabbita_usage_explorer_panel(),
      @html.div(class="usage-breakdown-grid", [
        moongate_rabbita_usage_panel(),
        moongate_rabbita_stack_panel(
          "Providers", "By Provider", "provider-usage",
        ),
        moongate_rabbita_stack_panel(
          "Models", "By Model", "filtered-model-usage",
        ),
      ]),
    ],
  )
}

///|
fn moongate_rabbita_suite_page() -> @html.Html {
  moongate_rabbita_page(
    "suite",
    "Moon Suite",
    "See how MoonDesk and the other Moon apps connect to MoonGate. MoonDesk comes first.",
    false,
    [moongate_rabbita_suite_panel()],
  )
}

///|
fn moongate_rabbita_readiness_strip() -> @html.Html {
  @html.section(
    id="readiness",
    class="readiness-panel panel",
    attrs=@html.Attrs::build().aria_label("MoonGate readiness"),
    [
      @html.div(class="panel-head", [
        @html.div([
          @html.p(class="eyebrow", "Readiness"),
          @html.h2("Ready to use"),
        ]),
        @html.span(class="panel-hint", "Live checks"),
      ]),
      @html.div(
        id="readiness-cards",
        class="readiness-cards",
        moongate_rabbita_empty(),
      ),
    ],
  )
}

///|
fn moongate_rabbita_quick_connect() -> @html.Html {
  @html.section(class="quick-connect", [
    @html.div(class="section-title", [
      @html.h2("Connect quickly"),
      @html.span("Addresses most apps ask for"),
      @html.a(
        href="#connect",
        attrs=@html.Attrs::build().data_set("goto", "connect"),
        "View all",
      ),
    ]),
    moongate_rabbita_connection_row(
      "OpenAI", "Chat completions", "/v1/chat/completions",
    ),
    moongate_rabbita_connection_row("Anthropic", "Messages", "/v1/messages"),
    moongate_rabbita_connection_row(
      "Monitoring data (advanced)", "For Prometheus dashboards; this is not an app screen",
      "/metrics",
    ),
  ])
}

///|
fn moongate_rabbita_connection_board() -> @html.Html {
  @html.section(id="connection-board", class="connection-board", [
    @html.div(class="page-intro", [
      @html.div([
        @html.h2("Connect an AI app"),
        @html.p(
          "Use this page when an app asks for a Base URL, API address, or environment variables. MoonGate supports several API formats on one local address.",
        ),
      ]),
      @html.span(
        id="connection-copy-status",
        class="updated-chip",
        "Ready to copy",
      ),
    ]),
    @html.div(class="section-title", [
      @html.h3("API addresses"),
      @html.span("Choose the format named by your app"),
    ]),
    @html.div(class="connection-grid", [
      moongate_rabbita_connection_card(
        "OpenAI Chat", "/v1/chat/completions", "OpenAI-compatible clients",
      ),
      moongate_rabbita_connection_card(
        "OpenAI Responses", "/v1/responses", "Codex-style responses clients",
      ),
      moongate_rabbita_connection_card(
        "Anthropic Messages", "/v1/messages", "Claude-compatible clients",
      ),
      moongate_rabbita_connection_card(
        "Claude Desktop", "/claude-desktop/v1/messages", "Desktop gateway route",
      ),
      moongate_rabbita_connection_card(
        "OpenClaw", "/openclaw/v1/chat/completions", "OpenClaw chat route",
      ),
      moongate_rabbita_connection_card(
        "Monitoring data (advanced)", "/metrics", "For Prometheus dashboards; copy only",
      ),
    ]),
    @html.div(class="section-title", [
      @html.h3("Command-line setup"),
      @html.span("Copy only when a terminal app asks for environment variables"),
    ]),
    @html.div(class="snippet-list", [
      moongate_rabbita_connection_snippet(
        "OpenAI env", "openai-env", "OpenAI-compatible clients",
      ),
      moongate_rabbita_connection_snippet(
        "Anthropic env", "anthropic-env", "Claude-compatible clients",
      ),
      moongate_rabbita_connection_snippet(
        "OpenClaw env", "openclaw-env", "OpenClaw clients",
      ),
      moongate_rabbita_connection_snippet(
        "Monitoring URL (advanced)", "metrics-url", "For Prometheus dashboards",
      ),
    ]),
  ])
}

///|
fn moongate_rabbita_connection_row(
  title : String,
  detail : String,
  path : String,
) -> @html.Html {
  @html.div(class="copy-row", [
    @html.div(class="copy-who", [@html.strong(title), @html.small(detail)]),
    @html.code(attrs=@html.Attrs::build().data_set("url-path", path), path),
    @html.button(
      type_="button",
      class="button-secondary copy-button",
      attrs=@html.Attrs::build().data_set("copy-path", path),
      "Copy",
    ),
  ])
}

///|
fn moongate_rabbita_connection_card(
  title : String,
  path : String,
  detail : String,
) -> @html.Html {
  @html.article(class="connection-card", [
    @html.div([@html.strong(title), @html.small(detail)]),
    @html.div(class="endpoint-url", [
      @html.code(attrs=@html.Attrs::build().data_set("url-path", path), path),
      @html.button(
        type_="button",
        class="button-secondary copy-button",
        attrs=@html.Attrs::build().data_set("copy-path", path),
        "Copy",
      ),
    ]),
  ])
}

///|
fn moongate_rabbita_connection_snippet(
  title : String,
  snippet : String,
  detail : String,
) -> @html.Html {
  @html.article(class="copy-row snippet-row", [
    @html.div(class="copy-who", [@html.strong(title), @html.small(detail)]),
    @html.code(attrs=@html.Attrs::build().data_set("snippet", snippet), ""),
    @html.button(
      type_="button",
      class="button-secondary copy-button",
      attrs=@html.Attrs::build().data_set("copy-snippet", snippet),
      "Copy",
    ),
  ])
}

///|
fn moongate_rabbita_metric_card(
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
fn moongate_rabbita_panel_head(
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
fn moongate_rabbita_table(
  headers : Array[String],
  body_id : String,
) -> @html.Html {
  @html.div(class="table-wrap", [
    @html.table([
      @html.thead([@html.tr(headers.map(fn(header) { @html.th(header) }))]),
      @html.tbody(id=body_id, moongate_rabbita_empty()),
    ]),
  ])
}
