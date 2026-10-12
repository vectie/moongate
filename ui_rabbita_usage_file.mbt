///|
fn moongate_rabbita_usage_file_panel() -> @html.Html {
  @html.article(class="panel wide", [
    moongate_rabbita_panel_head(
      "Temporary offline data",
      "Usage File Explorer",
      [],
    ),
    @html.p(
      class="panel-description",
      "Open CSV request rows, JSON arrays, JSONL, or MoonGate {data,total,page,pageSize} exports. Files are sent only to this gateway for stateless parsing. Imported rows remain separate from live usage and never contact providers. Up to 4 MiB / 10,000 rows. CSV needs model and token-count column headers.",
    ),
    @html.form(id="usage-file-form", class="form-grid", [
      @html.label([
        @html.span("Usage file"),
        @html.input(
          input_type=File,
          id="usage-file-picker",
          accept=".csv,text/csv,.json,.jsonl,.ndjson,application/json",
        ),
      ]),
      @html.label(class="span-2", [
        @html.span("Or paste request usage JSON or CSV"),
        @html.textarea(id="usage-file-content", rows=6, ""),
      ]),
      moongate_rabbita_input_label(
        "App (exact match)", "usage-file-app", "All apps", false,
      ),
      moongate_rabbita_input_label(
        "Provider ID (exact match)", "usage-file-provider", "All providers", false,
      ),
      moongate_rabbita_input_label(
        "Model (exact match)", "usage-file-model", "All models", false,
      ),
      moongate_rabbita_input_label(
        "From UTC day (inclusive)", "usage-file-start", "YYYY-MM-DD", false,
      ),
      moongate_rabbita_input_label(
        "Through UTC day (inclusive)", "usage-file-end", "YYYY-MM-DD", false,
      ),
      @html.div(class="inline-actions span-2", [
        @html.button(
          id="usage-file-open",
          type_="submit",
          "Open / apply filters",
        ),
        @html.button(
          id="usage-file-sample",
          type_="button",
          class="button-secondary",
          "Try a sample",
        ),
        @html.button(
          id="usage-file-reset",
          type_="button",
          class="button-secondary",
          "Reset filters",
        ),
        @html.button(
          id="usage-file-clear",
          type_="button",
          class="button-secondary",
          "Clear file",
        ),
      ]),
    ]),
    @html.p(
      id="usage-file-status",
      attrs=@html.Attrs::build().aria_live("polite"),
      "No usage file open.",
    ),
    @html.div(class="inline-actions", [
      @html.button(
        id="usage-file-json",
        type_="button",
        class="button-secondary",
        disabled=true,
        "Download filtered JSON",
      ),
      @html.button(
        id="usage-file-report",
        type_="button",
        class="button-secondary",
        disabled=true,
        "Download readable report",
      ),
    ]),
    @html.pre(id="usage-file-summary", ""),
    @html.div(id="usage-file-rows", class="stack", moongate_rabbita_empty()),
  ])
}
