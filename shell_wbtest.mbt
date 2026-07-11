///|
test "moongate external url normalization mirrors shell command behavior" {
  assert_eq(
    moon_normalize_external_url("github.com/vectie/moongate"),
    "https://github.com/vectie/moongate",
  )
  assert_eq(
    moon_normalize_external_url("https://github.com/vectie/moongate"),
    "https://github.com/vectie/moongate",
  )
  assert_eq(
    moon_normalize_external_url("HTTP://github.com/vectie/moongate"),
    "https://HTTP://github.com/vectie/moongate",
  )
  assert_eq(
    moon_normalize_external_url(" http://github.com/vectie/moongate "),
    "https:// http://github.com/vectie/moongate ",
  )
}

///|
test "moongate requested tool names keeps valid unique tools" {
  assert_eq(moon_requested_tool_names(Some("codex,unknown,codex,claude")), [
    "codex", "claude",
  ])
  assert_eq(moon_requested_tool_names(Some("unknown")), moon_tool_names())
}

///|
test "moongate standalone app shell defaults use local dialog null results" {
  assert_eq(moon_dialog_result_json(), Json::null())
}

///|
test "moongate tool lifecycle action and json tool parsing accepts standalone command inputs" {
  assert_true(moon_tool_lifecycle_action("install") is Some(Install))
  assert_true(moon_tool_lifecycle_action("update") is Some(Update))
  assert_eq(
    moon_requested_tool_names_from_json(
      Some(
        Json::array([
          Json::string("codex"),
          Json::string("bad"),
          Json::string("claude"),
        ]),
      ),
    ),
    ["codex", "claude"],
  )
}

///|
test "moongate tool lifecycle commands use official and npm fallbacks" {
  assert_true(
    moon_tool_install_command("claude").contains("claude.ai/install.sh"),
  )
  assert_true(
    moon_tool_install_command("claude").contains(
      "npm i -g @anthropic-ai/claude-code@latest",
    ),
  )
  assert_eq(
    moon_static_tool_update_command("gemini"),
    "npm i -g @google/gemini-cli@latest",
  )
}

///|
test "moongate tool installation report uses anchored default command" {
  let install = MoonToolInstallation::{
    path: "/opt/homebrew/bin/codex",
    real: "/opt/homebrew/bin/codex",
    version: Some("codex 1.0.0"),
    runnable: true,
    source: "homebrew",
    is_path_default: true,
  }
  assert_eq(
    moon_tool_update_command("codex", [install]),
    "/opt/homebrew/bin/codex update",
  )
}
