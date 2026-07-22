///|
fn moongate_rabbita_guide_page() -> @html.Html {
  moongate_rabbita_page(
    "guide",
    "Guide",
    "Learn what each page does and what MoonGate's technical phrases mean.",
    false,
    [
      @html.div(class="page-intro", [
        @html.div([
          @html.h2("MoonGate in plain language"),
          @html.p(
            "MoonGate sits between your AI apps and AI providers. It gives the apps one local address, then sends each request to the provider you chose.",
          ),
        ]),
      ]),
      @html.section(class="guide-section", [
        @html.div(class="section-title", [
          @html.h3("What each page is for"),
          @html.span("Start here when you are unsure where to go"),
        ]),
        @html.div(class="guide-grid", [
          moongate_rabbita_guide_page_card(
            "Overview", "Check whether MoonGate and AI routing are running, see the provider currently in use, and review request and spend totals.",
            "overview",
          ),
          moongate_rabbita_guide_page_card(
            "Connect", "Copy the local API address or command-line settings that another AI app asks you to enter.",
            "connect",
          ),
          moongate_rabbita_guide_page_card(
            "Setup", "Check signed-in accounts and whether installed AI apps such as Codex or Claude are ready to use MoonGate.",
            "setup",
          ),
          moongate_rabbita_guide_page_card(
            "Routing", "Choose which provider each AI app uses. Backup and failure settings are optional and live under Advanced.",
            "routing",
          ),
          moongate_rabbita_guide_page_card(
            "Providers", "Add or edit provider accounts, run a real connection test, and choose which provider is active.",
            "providers",
          ),
          moongate_rabbita_guide_page_card(
            "Requests", "Inspect individual AI calls, including their provider, model, result, token count, latency, and cost.",
            "requests",
          ),
          moongate_rabbita_guide_page_card(
            "Usage", "Review request, token, reused-input, and estimated-spend totals for a selected period.",
            "usage",
          ),
          moongate_rabbita_guide_page_card(
            "Suite", "See how MoonDesk, MoonClaw, MoonBook, and MoonTown connect to MoonGate. MoonDesk is the primary app.",
            "suite",
          ),
        ]),
      ]),
      @html.section(class="guide-section", [
        @html.div(class="section-title", [
          @html.h3("Phrase guide"),
          @html.span("The words you may see while configuring an AI app"),
        ]),
        @html.div(class="glossary-list", [
          moongate_rabbita_glossary_item(
            "AI routing", "MoonGate receiving a request from an AI app and sending it to the provider you selected.",
          ),
          moongate_rabbita_glossary_item(
            "Provider", "An AI service or account that answers requests, such as Codex OAuth or Volcengine Ark.",
          ),
          moongate_rabbita_glossary_item(
            "Request type / routing profile", "The request format and provider group MoonGate will use, such as Codex Responses or Claude Messages. It does not prove that the named app is connected.",
          ),
          moongate_rabbita_glossary_item(
            "Selected route", "The provider MoonGate will use if a matching request arrives. Stop Using leaves that request type without a selected provider.",
          ),
          moongate_rabbita_glossary_item(
            "Model", "The specific AI model a provider should run, such as gpt-5.6-sol or kimi-k3.",
          ),
          moongate_rabbita_glossary_item(
            "API key", "A secret issued by a provider. MoonGate stores it locally and does not show the saved value again.",
          ),
          moongate_rabbita_glossary_item(
            "OAuth", "Signing in through an account instead of pasting an API key.",
          ),
          moongate_rabbita_glossary_item(
            "Base URL / API address", "The network address where an AI app sends requests. MoonGate's address normally starts with http://127.0.0.1.",
          ),
          moongate_rabbita_glossary_item(
            "API protocol", "The request format expected by a provider: OpenAI Responses, OpenAI Chat, Anthropic Messages, or Gemini Native.",
          ),
          moongate_rabbita_glossary_item(
            "Template", "A reusable provider setup that fills the non-secret fields for you. You still enter the API key separately.",
          ),
          moongate_rabbita_glossary_item(
            "Command-line apps (previously called tools)", "Installed programs such as Codex, Claude, Gemini, and OpenCode. MoonGate detects them only so it knows which apps it can configure.",
          ),
          moongate_rabbita_glossary_item(
            "AI tools", "Actions an AI model can call, such as reading a file or using a service. This is different from the installed command-line apps shown on Setup.",
          ),
          moongate_rabbita_glossary_item(
            "MCP", "Model Context Protocol. It lets an AI app connect to external capabilities such as files or services. You only need it when an app or plugin asks for MCP.",
          ),
          moongate_rabbita_glossary_item(
            "Backup provider / automatic backup", "Another provider MoonGate may try when the active provider fails.",
          ),
          moongate_rabbita_glossary_item(
            "Pause a failing provider (circuit breaker)", "An advanced safety rule that temporarily stops sending requests to a repeatedly failing provider.",
          ),
          moongate_rabbita_glossary_item(
            "Streaming", "Receiving an AI answer piece by piece instead of waiting for the whole response.",
          ),
          moongate_rabbita_glossary_item(
            "Tokens", "Small pieces of text counted by AI providers for limits and billing.",
          ),
          moongate_rabbita_glossary_item(
            "Reused input (cache hit)", "Input the provider could reuse instead of processing again; this may reduce time or cost.",
          ),
          moongate_rabbita_glossary_item(
            "Monitoring data / Prometheus metrics", "Machine-readable numbers for an external monitoring dashboard. It is not a MoonGate screen, so MoonGate only offers a Copy button for its URL.",
          ),
          moongate_rabbita_glossary_item(
            "Portable storage", "An advanced mode that keeps MoonGate data beside the app instead of in the normal user-data folder.",
          ),
        ]),
      ]),
    ],
  )
}

///|
fn moongate_rabbita_guide_page_card(
  title : String,
  description : String,
  target : String,
) -> @html.Html {
  @html.article(class="guide-card", [
    @html.h3(title),
    @html.p(description),
    @html.button(
      type_="button",
      class="button-secondary",
      attrs=@html.Attrs::build().data_set("goto", target),
      "Open \{title}",
    ),
  ])
}

///|
fn moongate_rabbita_glossary_item(
  term : String,
  meaning : String,
) -> @html.Html {
  @html.div(class="glossary-item", [@html.strong(term), @html.p(meaning)])
}
