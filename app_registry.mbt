///|
priv struct GatewayApp {
  id : String
  label : String
  scope : String
  mode : String
  desktop : Bool
  priority : Int32
  binding : String
  route : String
  protocol : String
}

///|
fn gateway_apps() -> Array[GatewayApp] {
  [
    {
      id: "moondesk",
      label: "MoonDesk",
      scope: "openclaw",
      mode: "single",
      desktop: true,
      priority: 0,
      binding: "automatic",
      route: "/openclaw/v1/chat/completions",
      protocol: "OpenAI Chat",
    },
    {
      id: "moonclaw",
      label: "MoonClaw",
      scope: "openclaw",
      mode: "single",
      desktop: false,
      priority: 10,
      binding: "automatic",
      route: "/openclaw/v1/chat/completions",
      protocol: "OpenAI Chat",
    },
    {
      id: "moonbook",
      label: "MoonBook",
      scope: "openclaw",
      mode: "single",
      desktop: false,
      priority: 20,
      binding: "manual",
      route: "/openclaw/v1/chat/completions",
      protocol: "OpenAI Chat",
    },
    {
      id: "moontown",
      label: "MoonTown",
      scope: "openclaw",
      mode: "single",
      desktop: false,
      priority: 30,
      binding: "manual",
      route: "/openclaw/v1/chat/completions",
      protocol: "OpenAI Chat",
    },
    {
      id: "claude",
      label: "Claude Code",
      scope: "claude",
      mode: "single",
      desktop: false,
      priority: 100,
      binding: "manual",
      route: "/v1/messages",
      protocol: "Anthropic Messages",
    },
    {
      id: "claude-desktop",
      label: "Claude Desktop",
      scope: "claude-desktop",
      mode: "single",
      desktop: true,
      priority: 100,
      binding: "automatic",
      route: "/claude-desktop/v1/messages",
      protocol: "Anthropic Messages",
    },
    {
      id: "codex",
      label: "Codex",
      scope: "codex",
      mode: "single",
      desktop: false,
      priority: 100,
      binding: "automatic",
      route: "/v1/responses",
      protocol: "OpenAI Responses",
    },
    {
      id: "gemini",
      label: "Gemini",
      scope: "gemini",
      mode: "single",
      desktop: false,
      priority: 100,
      binding: "manual",
      route: "/gemini/v1beta/…",
      protocol: "Gemini Native",
    },
    {
      id: "opencode",
      label: "OpenCode",
      scope: "opencode",
      mode: "additive",
      desktop: false,
      priority: 100,
      binding: "manual",
      route: "/v1/chat/completions",
      protocol: "OpenAI Chat",
    },
    {
      id: "openclaw",
      label: "OpenClaw",
      scope: "openclaw",
      mode: "additive",
      desktop: false,
      priority: 100,
      binding: "manual",
      route: "/openclaw/v1/chat/completions",
      protocol: "OpenAI Chat",
    },
    {
      id: "hermes",
      label: "Hermes",
      scope: "hermes",
      mode: "additive",
      desktop: false,
      priority: 100,
      binding: "manual",
      route: "/v1/chat/completions",
      protocol: "OpenAI Chat",
    },
  ]
}

///|
fn gateway_app(id : String) -> GatewayApp? {
  for app in gateway_apps() {
    if app.id == id {
      return Some(app)
    }
  }
  None
}
