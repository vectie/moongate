///|
fn moongate_rabbita_transcript_page() -> @html.Html {
  moongate_rabbita_page(
    "transcripts",
    "Transcript Reader",
    "Open an exported conversation, find useful messages, and keep a portable copy.",
    false,
    [
      @html.article(class="panel wide", [
        moongate_rabbita_panel_head("Local sources", "Open a transcript", []),
        @html.p(
          class="panel-description",
          "Choose a Codex or Claude Code JSONL log, or role/content JSON. Files are sent only to this MoonGate gateway for parsing, held in this page, and never added to client history. No AI provider is called.",
        ),
        @html.form(id="transcript-form", class="form-grid", [
          @html.label([
            @html.span("Exported log (up to 4 MiB)"),
            @html.input(
              input_type=File,
              id="transcript-file",
              accept=".json,.jsonl,.ndjson,application/json",
            ),
          ]),
          moongate_rabbita_select_label("Source format", "transcript-format", [
            ("auto", "Detect automatically"),
            ("codex", "Codex JSONL"),
            ("claude", "Claude Code JSONL"),
            ("json", "Role/content JSON or JSONL"),
          ]),
          @html.label(class="span-2", [
            @html.span("Or paste a transcript"),
            @html.textarea(
              id="transcript-content",
              rows=7,
              placeholder="[{\"role\":\"user\",\"content\":\"Hello\"}]",
              "",
            ),
          ]),
          @html.div(class="inline-actions span-2", [
            @html.button(
              id="transcript-open",
              type_="submit",
              "Open transcript",
            ),
            @html.button(
              id="transcript-sample",
              type_="button",
              class="button-secondary",
              "Try a sample",
            ),
            @html.button(
              id="transcript-clear",
              type_="button",
              class="button-secondary",
              "Clear",
            ),
          ]),
        ]),
        @html.p(
          id="transcript-status",
          attrs=@html.Attrs::build().aria_live("polite"),
          "No transcript open.",
        ),
        @html.div(class="form-grid", [
          moongate_rabbita_input_label(
            "Find text", "transcript-query", "Search messages", false,
          ),
          moongate_rabbita_select_label("Speaker", "transcript-role", [
            ("", "All speakers"),
          ]),
        ]),
        @html.div(class="inline-actions", [
          @html.button(
            id="transcript-json",
            type_="button",
            class="button-secondary",
            disabled=true,
            "Download visible JSON",
          ),
          @html.button(
            id="transcript-markdown",
            type_="button",
            class="button-secondary",
            disabled=true,
            "Download visible Markdown",
          ),
        ]),
        @html.p(id="transcript-count", ""),
        @html.div(
          id="transcript-messages",
          class="transcript-messages",
          moongate_rabbita_empty(),
        ),
      ]),
    ],
  )
}
