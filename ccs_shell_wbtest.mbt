///|
test "ccs external url normalization mirrors shell command behavior" {
  assert_eq(
    ccs_normalize_external_url("github.com/farion1231/cc-switch"),
    "https://github.com/farion1231/cc-switch",
  )
  assert_eq(
    ccs_normalize_external_url("https://github.com/farion1231/cc-switch"),
    "https://github.com/farion1231/cc-switch",
  )
  assert_eq(
    ccs_normalize_external_url("HTTP://github.com/farion1231/cc-switch"),
    "https://HTTP://github.com/farion1231/cc-switch",
  )
  assert_eq(
    ccs_normalize_external_url(" http://github.com/farion1231/cc-switch "),
    "https:// http://github.com/farion1231/cc-switch ",
  )
}

///|
test "ccs requested tool names keeps valid unique tools" {
  assert_eq(ccs_requested_tool_names(Some("codex,unknown,codex,claude")), [
    "codex", "claude",
  ])
  assert_eq(ccs_requested_tool_names(Some("unknown")), ccs_tool_names())
}

///|
test "ccs standalone app shell defaults use tauri-compatible empty results" {
  assert_eq(ccs_init_error_json(), Json::null())
  assert_eq(ccs_migration_result_json(), Json::boolean(false))
  assert_eq(ccs_skills_migration_result_json(), Json::null())
  assert_eq(ccs_dialog_result_json(), Json::null())
}

///|
test "ccs tool lifecycle action and json tool parsing mirrors tauri command inputs" {
  assert_true(ccs_tool_lifecycle_action("install") is Some(Install))
  assert_true(ccs_tool_lifecycle_action("update") is Some(Update))
  assert_eq(
    ccs_requested_tool_names_from_json(
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
test "ccs tool lifecycle commands use official and npm fallbacks" {
  assert_true(
    ccs_tool_install_command("claude").contains("claude.ai/install.sh"),
  )
  assert_true(
    ccs_tool_install_command("claude").contains(
      "npm i -g @anthropic-ai/claude-code@latest",
    ),
  )
  assert_eq(
    ccs_static_tool_update_command("gemini"),
    "npm i -g @google/gemini-cli@latest",
  )
}

///|
test "ccs tool installation report uses anchored default command" {
  let install = CcsToolInstallation::{
    path: "/opt/homebrew/bin/codex",
    real: "/opt/homebrew/bin/codex",
    version: Some("codex 1.0.0"),
    runnable: true,
    source: "homebrew",
    is_path_default: true,
  }
  assert_eq(
    ccs_tool_update_command("codex", [install]),
    "/opt/homebrew/bin/codex update",
  )
}
