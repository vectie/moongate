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
    @html.div(
      id="request-log",
      class="log-list",
      attrs=@html.Attrs::build().data_set("i18n-scope", "technical"),
      moonstat_rabbita_empty(),
    ),
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
      attrs=@html.Attrs::build().data_set("i18n-scope", "technical"),
      moonstat_rabbita_empty(),
    ),
  ])
}
