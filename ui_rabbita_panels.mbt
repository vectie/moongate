///|
fn moongate_rabbita_frameworks_panel() -> @html.Html {
  @html.article(id="frameworks", class="panel wide", [
    moongate_rabbita_panel_head("AI apps", "Provider choice", [
      @html.button(
        id="sync-live",
        class="button-secondary",
        type_="button",
        "Save Current Routes",
      ),
    ]),
    @html.p(
      class="panel-description",
      "Choose the provider each AI app should use. “One active” means the app uses one provider at a time; “Multiple active” means it can keep several provider entries.",
    ),
    moongate_rabbita_table(
      ["AI app", "Provider mode", "In use", "Available", "Actions"],
      "framework-rows",
    ),
  ])
}

///|
fn moongate_rabbita_provider_editor_panel() -> @html.Html {
  @html.article(id="provider-editor", class="panel wide", [
    moongate_rabbita_panel_head("Providers", "Provider Editor", [
      @html.button(
        id="provider-clear",
        class="button-secondary",
        type_="button",
        "New Provider",
      ),
    ]),
    @html.div(class="provider-route-banner", [
      @html.div([
        @html.small("Active route"),
        @html.strong(id="provider-active-route", "Loading provider route…"),
      ]),
      @html.button(
        id="provider-use",
        class="button-secondary",
        type_="button",
        disabled=true,
        "Use This Provider",
      ),
    ]),
    @html.form(id="provider-form", class="form-grid", [
      @html.input(input_type=Hidden, id="provider-original-id"),
      @html.input(input_type=Hidden, id="provider-original-app"),
      @html.div(class="provider-template-picker span-2", [
        @html.label([
          @html.span("Start from a template"),
          @html.select(id="provider-template", [
            @html.option(value="", "Choose a template"),
          ]),
        ]),
        @html.div(class="inline-actions", [
          @html.button(
            id="provider-template-apply",
            class="button-secondary",
            type_="button",
            "Use Template",
          ),
          @html.button(
            id="provider-template-load",
            class="button-secondary",
            type_="button",
            "Load JSON",
          ),
          @html.button(
            id="provider-template-reload",
            class="button-secondary",
            type_="button",
            "Refresh Built-ins",
          ),
        ]),
        @html.input(
          input_type=File,
          id="provider-template-file",
          accept="application/json,.json",
          hidden=true,
        ),
        @html.small(
          id="provider-template-status",
          "Templates fill the form; API keys are always entered separately.",
        ),
      ]),
      moongate_rabbita_select_label("AI app", "provider-app", []),
      moongate_rabbita_input_label(
        "Provider ID (internal name)", "provider-id", "", true,
      ),
      moongate_rabbita_input_label("Name", "provider-name", "", true),
      moongate_rabbita_input_label(
        "Base URL",
        "provider-base-url",
        "https://api.example.com",
        false,
        class="span-2",
      ),
      moongate_rabbita_select_label("API protocol", "provider-api-format", [
        ("", "Default"),
        ("openai", "OpenAI Responses"),
        ("openai_chat", "OpenAI Chat Completions"),
        ("anthropic", "Anthropic"),
        ("gemini_native", "Gemini Native"),
      ]),
      moongate_rabbita_password_label("API Key", "provider-api-key"),
      @html.small(
        id="provider-credential-status",
        class="field-hint",
        "No stored credential",
      ),
      moongate_rabbita_input_label(
        "Default Model", "provider-default-model", "", false,
      ),
      @html.label(class="span-2", [
        @html.span("Notes"),
        @html.textarea(id="provider-notes", rows=3, moongate_rabbita_empty()),
      ]),
      @html.details(class="advanced-disclosure provider-advanced span-2", [
        @html.summary("Advanced provider options"),
        @html.div(class="provider-advanced-fields", [
          moongate_rabbita_input_label(
            "Provider type", "provider-type", "openrouter, codex_oauth, gemini",
            false,
          ),
          moongate_rabbita_input_label(
            "Sonnet model override", "provider-sonnet-model", "", false,
          ),
          moongate_rabbita_input_label(
            "Haiku model override", "provider-haiku-model", "", false,
          ),
          moongate_rabbita_input_label(
            "Opus model override", "provider-opus-model", "", false,
          ),
          @html.div(class="check-row span-2", [
            moongate_rabbita_check_label(
              "provider-full-url", "Base URL is the complete request URL", false,
            ),
            moongate_rabbita_check_label(
              "provider-fast-mode", "Faster Codex requests", false,
            ),
            moongate_rabbita_check_label(
              "provider-clear-models", "Clear all model mappings", false,
            ),
          ]),
        ]),
      ]),
      @html.div(class="check-row span-2", [
        moongate_rabbita_check_label("provider-enabled", "Enabled", true),
        moongate_rabbita_check_label(
          "provider-clear-api-key", "Remove stored API key", false,
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
        @html.span(id="provider-test-result", class="state", "Not tested"),
        @html.span(id="provider-form-status", ""),
      ]),
    ]),
  ])
}

///|
fn moongate_rabbita_setup_panel() -> @html.Html {
  @html.article(id="setup", class="panel wide", [
    moongate_rabbita_panel_head("Setup", "App readiness", [
      @html.div(class="inline-actions", [
        @html.button(
          id="setup-refresh",
          class="button-secondary",
          type_="button",
          "Check Again",
        ),
        @html.button(
          id="setup-import-mcp",
          class="button-secondary",
          type_="button",
          "Detect App Extensions",
        ),
      ]),
    ]),
    @html.div(class="panel-description", [
      @html.strong("What are command-line apps and extensions?"),
      @html.p(
        "MoonGate detects installed apps such as Codex, Claude, Gemini, and OpenCode so it knows which apps it can configure. Extensions (including MCP) let an AI app use capabilities such as files or services; you only need them when an app asks for one.",
      ),
    ]),
    @html.div(class="setup-grid", [
      moongate_rabbita_setup_card(
        "Signed-in accounts", "setup-auth-state", "setup-auth-rows",
      ),
      moongate_rabbita_setup_card(
        "MoonGate & installed apps", "setup-runtime-state", "setup-runtime-rows",
      ),
      @html.div(class="setup-card", [
        @html.div(class="setup-card-head", [
          @html.strong("Claude Desktop"),
          @html.span(id="setup-desktop-state", class="state warn", "Loading"),
        ]),
        @html.div(
          id="setup-desktop-rows",
          class="setup-list",
          moongate_rabbita_empty(),
        ),
        @html.div(class="inline-actions", [
          @html.button(
            id="setup-import-claude-desktop",
            type_="button",
            "Use Claude Desktop Setup",
          ),
        ]),
      ]),
      moongate_rabbita_setup_card(
        "AI app extensions", "setup-mcp-state", "setup-mcp-rows",
      ),
    ]),
    @html.div(class="table-wrap setup-table-wrap", [
      @html.table([
        @html.thead([
          @html.tr(
            ["AI app", "Settings found", "Routed through MoonGate", "Action"].map(fn(
                header,
              ) {
                @html.th(header)
              },
            ),
          ),
        ]),
        @html.tbody(id="setup-config-rows", moongate_rabbita_empty()),
      ]),
    ]),
  ])
}

///|
fn moongate_rabbita_setup_card(
  title : String,
  state_id : String,
  rows_id : String,
) -> @html.Html {
  @html.div(class="setup-card", [
    @html.div(class="setup-card-head", [
      @html.strong(title),
      @html.span(id=state_id, class="state warn", "Loading"),
    ]),
    @html.div(id=rows_id, class="setup-list", moongate_rabbita_empty()),
  ])
}

///|
fn moongate_rabbita_suite_panel() -> @html.Html {
  @html.article(id="suite", class="panel wide", [
    moongate_rabbita_panel_head("MoonDesk first", "Connected Moon apps", [
      @html.div(class="inline-actions", [
        @html.button(
          id="suite-refresh",
          class="button-secondary",
          type_="button",
          "Refresh Suite",
        ),
      ]),
    ]),
    @html.p(
      class="panel-description",
      "MoonDesk is the primary desktop control surface. The other Moon apps use MoonGate for AI routing, usage data, or health checks.",
    ),
    @html.div(class="usage-metrics", [
      moongate_rabbita_status_value("Connection", "suite-status-state"),
      moongate_rabbita_status_value("Connected apps", "suite-app-count"),
      moongate_rabbita_status_value("Shared features", "suite-capability-count"),
      moongate_rabbita_status_value(
        "MoonClaw Providers", "suite-provider-count",
      ),
    ]),
    moongate_rabbita_table(
      ["App", "Purpose", "What it uses MoonGate for", "Connection check"],
      "suite-app-rows",
    ),
    @html.details(class="advanced-disclosure suite-advanced", [
      @html.summary("Advanced suite files"),
      @html.p(
        "These actions refresh machine-readable files used by other Moon apps. Most users do not need them.",
      ),
      @html.div(class="advanced-actions", [
        @html.button(
          id="suite-write-status",
          type_="button",
          "Rewrite Status File",
        ),
        @html.button(
          id="suite-write-moonclaw",
          class="button-secondary",
          type_="button",
          "Rewrite MoonClaw Providers",
        ),
        @html.code(id="suite-status-path", "Loading status file…"),
      ]),
    ]),
    @html.div(id="suite-integrations", class="stack", moongate_rabbita_empty()),
  ])
}

///|
fn moongate_rabbita_resilience_panel() -> @html.Html {
  @html.article(id="resilience", class="panel wide", [
    moongate_rabbita_panel_head("Advanced", "Backup & failure handling", [
      @html.div(class="filter-row", [
        @html.select(
          id="resilience-app",
          attrs=@html.Attrs::build().aria_label("Resilience framework"),
          moongate_rabbita_empty(),
        ),
        @html.select(
          id="resilience-provider",
          attrs=@html.Attrs::build().aria_label("Resilience provider"),
          moongate_rabbita_empty(),
        ),
        @html.button(
          id="resilience-refresh",
          class="button-secondary",
          type_="button",
          "Refresh",
        ),
      ]),
    ]),
    @html.p(
      class="panel-description",
      "Optional controls for using a backup provider and pausing a provider that repeatedly fails. Leave these at their defaults unless you need automatic recovery.",
    ),
    @html.details(class="advanced-disclosure", [
      @html.summary("Show advanced failure controls"),
      @html.div(class="usage-metrics", [
        moongate_rabbita_status_value(
          "Automatic backup", "resilience-auto-state",
        ),
        moongate_rabbita_status_value(
          "Selected provider", "resilience-circuit-state",
        ),
        moongate_rabbita_status_value("Backup count", "resilience-queue-count"),
        moongate_rabbita_status_value(
          "Provider limits", "resilience-limit-state",
        ),
      ]),
      @html.div(class="resilience-grid", [
        moongate_rabbita_circuit_card(),
        moongate_rabbita_stream_card(),
      ]),
      @html.div(class="resilience-grid", [
        @html.div(class="setup-card", [
          @html.div(class="setup-card-head", [
            @html.strong("Backup order"),
            @html.button(
              id="resilience-toggle-auto",
              class="button-secondary",
              type_="button",
              "Turn Automatic Backup On",
            ),
          ]),
          @html.div(
            id="failover-queue",
            class="stack",
            moongate_rabbita_empty(),
          ),
        ]),
        @html.div(class="setup-card", [
          @html.div(class="setup-card-head", [
            @html.strong("Available backups"),
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
            moongate_rabbita_empty(),
          ),
        ]),
      ]),
      @html.div(
        id="stream-check-results",
        class="log-list",
        moongate_rabbita_empty(),
      ),
    ]),
  ])
}

///|
fn moongate_rabbita_circuit_card() -> @html.Html {
  @html.div(class="setup-card", [
    @html.div(class="setup-card-head", [
      @html.strong("Pause a failing provider"),
      @html.span(id="resilience-circuit-status", class="state warn", "Loading"),
    ]),
    @html.p(
      class="card-help",
      "Pause after repeated failures, then resume after enough successful checks. Failure rate uses a value from 0 to 1.",
    ),
    @html.form(id="circuit-form", class="compact-form", [
      moongate_rabbita_input_label(
        "Failures before pause",
        "circuit-failure-threshold",
        "",
        false,
        inputmode="numeric",
      ),
      moongate_rabbita_input_label(
        "Successes before recovery",
        "circuit-success-threshold",
        "",
        false,
        inputmode="numeric",
      ),
      moongate_rabbita_input_label(
        "Pause duration (seconds)",
        "circuit-timeout-seconds",
        "",
        false,
        inputmode="numeric",
      ),
      moongate_rabbita_input_label(
        "Failure rate (0 to 1)",
        "circuit-error-rate-threshold",
        "",
        false,
        inputmode="decimal",
      ),
      moongate_rabbita_input_label(
        "Minimum requests",
        "circuit-min-requests",
        "",
        false,
        inputmode="numeric",
      ),
      @html.div(class="inline-actions", [
        @html.button(type_="submit", "Save Failure Rules"),
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
fn moongate_rabbita_stream_card() -> @html.Html {
  @html.div(class="setup-card", [
    @html.div(class="setup-card-head", [
      @html.strong("Streaming connection test"),
      @html.span(id="resilience-stream-status", class="state warn", "Loading"),
    ]),
    @html.p(
      class="card-help",
      "Checks that a provider can return an answer piece by piece. These settings affect only the test.",
    ),
    @html.form(id="stream-form", class="compact-form", [
      moongate_rabbita_input_label(
        "Test timeout (seconds)",
        "stream-timeout-secs",
        "",
        false,
        inputmode="numeric",
      ),
      moongate_rabbita_input_label(
        "Max Retries",
        "stream-max-retries",
        "",
        false,
        inputmode="numeric",
      ),
      moongate_rabbita_input_label(
        "Slow after (milliseconds)",
        "stream-degraded-threshold-ms",
        "",
        false,
        inputmode="numeric",
      ),
      moongate_rabbita_input_label(
        "Codex Model", "stream-codex-model", "", false,
      ),
      moongate_rabbita_input_label(
        "Claude Model", "stream-claude-model", "", false,
      ),
      moongate_rabbita_input_label(
        "Gemini Model", "stream-gemini-model", "", false,
      ),
      moongate_rabbita_input_label(
        "Test prompt",
        "stream-test-prompt",
        "",
        false,
        class="span-2",
      ),
      @html.div(class="inline-actions span-2", [
        @html.button(type_="submit", "Save Test Settings"),
        @html.button(
          id="resilience-stream-check",
          class="button-secondary",
          type_="button",
          "Run Connection Test",
        ),
      ]),
    ]),
  ])
}

///|
fn moongate_rabbita_provider_health_panel() -> @html.Html {
  @html.article(id="provider-health", class="panel wide", [
    moongate_rabbita_panel_head("Routing", "Provider Health", [
      @html.span(id="provider-count", class="pill", "0 providers"),
    ]),
    moongate_rabbita_table(
      ["Provider", "AI app", "State", "Action"],
      "provider-rows",
    ),
  ])
}

///|
fn moongate_rabbita_usage_panel() -> @html.Html {
  @html.article(id="usage", class="panel", [
    moongate_rabbita_panel_head("Usage", "By App", []),
    @html.div(id="app-usage", class="stack", moongate_rabbita_empty()),
  ])
}

///|
fn moongate_rabbita_stack_panel(
  eyebrow : String,
  title : String,
  id : String,
) -> @html.Html {
  @html.article(class="panel", [
    moongate_rabbita_panel_head(eyebrow, title, []),
    @html.div(id~, class="stack", moongate_rabbita_empty()),
  ])
}

///|
fn moongate_rabbita_usage_explorer_panel() -> @html.Html {
  @html.article(id="usage-explorer", class="panel wide", [
    moongate_rabbita_panel_head("Statistics", "Usage Explorer", [
      @html.div(class="filter-row", [
        @html.select(
          id="usage-app",
          attrs=@html.Attrs::build().aria_label("Usage framework"),
          moongate_rabbita_empty(),
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
      moongate_rabbita_status_value("Requests", "usage-filter-requests"),
      moongate_rabbita_status_value("Cost", "usage-filter-cost"),
      moongate_rabbita_status_value("Tokens", "usage-filter-tokens"),
      moongate_rabbita_status_value("Reused input", "usage-filter-cache"),
    ]),
    @html.div(id="usage-trends", class="trend-bars", moongate_rabbita_empty()),
  ])
}

///|
fn moongate_rabbita_request_log_panel() -> @html.Html {
  @html.article(id="requests", class="panel wide", [
    moongate_rabbita_panel_head("Recent", "AI requests", [
      @html.button(
        class="button-secondary",
        type_="button",
        attrs=@html.Attrs::build().data_set("copy-path", "/usage/logs"),
        "Copy Developer JSON URL",
      ),
    ]),
    @html.div(
      id="request-log",
      class="log-list",
      attrs=@html.Attrs::build().data_set("i18n-scope", "technical"),
      moongate_rabbita_empty(),
    ),
  ])
}

///|
fn moongate_rabbita_request_detail_panel() -> @html.Html {
  @html.article(id="request-detail-panel", class="panel wide", [
    moongate_rabbita_panel_head("Request", "Request Detail", [
      @html.span(id="request-detail-id", class="pill", "No selection"),
    ]),
    @html.div(
      id="request-detail",
      class="detail-grid",
      attrs=@html.Attrs::build().data_set("i18n-scope", "technical"),
      moongate_rabbita_empty(),
    ),
  ])
}
