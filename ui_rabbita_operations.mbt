///|
fn moongate_rabbita_operations_page() -> @html.Html {
  moongate_rabbita_page(
    "operations",
    "Operations",
    "Observe provider latency, capacity, quotas, failover, and routing-policy decisions.",
    false,
    [
      @html.section(
        class="status-grid",
        attrs=@html.Attrs::build().aria_label("Live provider request telemetry"),
        [
          moongate_rabbita_metric_card(
            "Latency p50", "operations-latency-p50", "operations-latency-p95", "p95 latency",
          ),
          moongate_rabbita_metric_card(
            "Latency p99", "operations-latency-p99", "operations-ttft-p95", "p95 first token",
          ),
          moongate_rabbita_metric_card(
            "In flight", "operations-inflight", "operations-queue", "Queue support",
          ),
          moongate_rabbita_metric_card(
            "Open circuits", "operations-circuits", "operations-failovers", "Recorded failovers",
          ),
        ],
      ),
      @html.div(class="overview-grid", [
        @html.article(class="panel wide", [
          moongate_rabbita_panel_head("Provider requests", "Routing policy", [
            @html.select(
              id="operations-app",
              attrs=@html.Attrs::build().aria_label("Routing policy app"),
              moongate_rabbita_empty(),
            ),
          ]),
          @html.p(
            class="panel-description",
            "Save a policy into shadow mode first. Shadow observations never change live routing. Activation and rollback require a named operator and create durable receipts.",
          ),
          @html.form(id="routing-policy-form", class="form-grid", [
            moongate_rabbita_select_label("Selection mode", "routing-policy-mode", [
              ("priority", "Priority"),
              ("smooth-weighted-round-robin", "Smooth weighted round robin"),
              ("least-inflight", "Least in flight"),
              ("session-sticky", "Session sticky"),
            ]),
            moongate_rabbita_input_label(
              "Policy ID", "routing-policy-id", "codex.production", false,
            ),
            @html.label(class="span-2", [
              @html.span("Provider weights (JSON object)"),
              @html.textarea(
                id="routing-policy-weights",
                rows=2,
                attrs=@html.Attrs::build().spellcheck(false),
                [@html.text("{}")],
              ),
            ]),
            @html.label(class="span-2", [
              @html.span("Concurrency limits (JSON object)"),
              @html.textarea(
                id="routing-policy-limits",
                rows=2,
                attrs=@html.Attrs::build().spellcheck(false),
                [@html.text("{}")],
              ),
            ]),
            @html.div(class="form-actions span-2", [
              @html.button(id="routing-policy-save", type_="submit", "Save as Shadow"),
              @html.button(
                id="routing-policy-observe",
                class="button-secondary",
                type_="button",
                "Observe Shadow Decision",
              ),
              @html.span(
                id="routing-policy-status",
                class="state",
                attrs=@html.Attrs::build().aria_live("polite"),
                "No policy loaded",
              ),
            ]),
          ]),
          @html.div(class="usage-metrics", [
            moongate_rabbita_status_value("Draft revision", "routing-draft-revision"),
            moongate_rabbita_status_value("Shadow decisions", "routing-shadow-count"),
            moongate_rabbita_status_value("Shadow choice", "routing-shadow-choice"),
            moongate_rabbita_status_value("Active policy", "routing-active-policy"),
          ]),
          @html.details(class="advanced-disclosure", [
            @html.summary("Activate or roll back a reviewed policy"),
            @html.p(
              class="card-help",
              "Activation changes only a bounded canary fraction of provider/model request selection. Paste host-issued MoonLib principal and authority-decision references; MoonGate does not mint authority. It never schedules agents or workflows.",
            ),
            @html.div(class="form-grid", [
              @html.label(class="span-2", [
                @html.span("Actor principal reference (JSON)"),
                @html.textarea(
                  id="routing-actor-principal",
                  rows=4,
                  attrs=@html.Attrs::build().spellcheck(false),
                  [@html.text("")],
                ),
              ]),
              @html.label(class="span-2", [
                @html.span("Authority decision reference (JSON)"),
                @html.textarea(
                  id="routing-authority-decision",
                  rows=6,
                  attrs=@html.Attrs::build().spellcheck(false),
                  [@html.text("")],
                ),
              ]),
              @html.div(class="form-actions span-2", [
              @html.button(id="routing-policy-activate", type_="button", "Activate Reviewed Policy"),
              @html.button(
                id="routing-policy-rollback",
                class="danger-ghost",
                type_="button",
                "Roll Back",
              ),
              ]),
            ]),
            @html.code(id="routing-receipt", "No activation receipt"),
          ]),
        ]),
        @html.article(class="panel", [
          moongate_rabbita_panel_head("Repeatable fixture", "Deterministic benchmark", []),
          @html.p(
            class="panel-description",
            "This benchmark checks MoonGate contract arithmetic with fixed samples. It is not a live provider latency or throughput claim.",
          ),
          @html.div(class="usage-metrics", [
            moongate_rabbita_status_value("Mode", "benchmark-mode"),
            moongate_rabbita_status_value("Claim ceiling", "benchmark-claim"),
            moongate_rabbita_status_value("Fixture p95", "benchmark-p95"),
            moongate_rabbita_status_value("Fixture throughput", "benchmark-throughput"),
          ]),
          @html.button(
            id="benchmark-run",
            class="button-secondary",
            type_="button",
            "Run Deterministic Fixture",
          ),
          @html.p(
            id="benchmark-status",
            class="card-help",
            attrs=@html.Attrs::build().aria_live("polite"),
            "Not run",
          ),
        ]),
      ]),
      @html.p(
        id="operations-monitor-status",
        class="panel-description",
        attrs=@html.Attrs::build().aria_live("polite"),
        "Loading operations telemetry…",
      ),
    ],
  )
}
