///|
test "automatic app bindings are limited to real managed config writers" {
  assert_eq(moon_binding_mode("moondesk"), "automatic")
  assert_eq(moon_binding_mode("codex"), "automatic")
  assert_eq(moon_binding_mode("claude-desktop"), "automatic")
  assert_eq(moon_binding_mode("claude"), "manual")
  assert_eq(moon_binding_mode("gemini"), "manual")
  assert_eq(moon_binding_mode("opencode"), "manual")
  assert_eq(moon_binding_mode("openclaw"), "manual")
  assert_eq(moon_binding_mode("hermes"), "manual")
}

///|
test "MoonDesk binding reuses Codex-compatible providers" {
  assert_eq(moon_binding_provider_app_type("moondesk"), "codex")
  assert_eq(moon_binding_provider_app_type("claude"), "claude")
}

///|
test "Codex detection checks app bundles and persistent state without NVM scanning" {
  let home = "/Users/example"
  let apps = "/Applications"
  let bundles = moon_binding_codex_app_bundle_paths(home, apps)
  assert_true(bundles.contains("/Applications/ChatGPT.app"))
  assert_true(bundles.contains("/Applications/Codex.app"))
  assert_true(bundles.contains("/Users/example/Applications/ChatGPT.app"))
  assert_true(bundles.contains("/Users/example/Applications/Codex.app"))
  let executables = moon_binding_codex_bundled_executable_paths(home, apps)
  assert_true(
    executables.contains("/Applications/ChatGPT.app/Contents/Resources/codex"),
  )
  let state = moon_binding_codex_state_paths(home)
  assert_true(state.contains("/Users/example/.codex"))
  assert_true(
    state.contains("/Users/example/Library/Application Support/OpenAI/Codex"),
  )
  assert_false(
    (bundles + executables + state).any(path => path.contains("/.nvm/")),
  )
}

///|
async test "Codex filesystem evidence recognizes persistent state" {
  @fsx.with_temporary_directory("moongate-codex-detection-XXXXXX", tmpdir => {
    let state = moon_binding_codex_state_paths(tmpdir)
    assert_false(moon_binding_any_path_exists(state))
    @fsx.make_directory(@pathx.join(tmpdir, ".codex"))
    assert_true(moon_binding_any_path_exists(state))
  })
}

///|
test "app binding uses provider default model when configured" {
  let provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="ark",
    provider_name="Ark",
    model_mapping=Some(ModelMapping::new(default_model=Some("kimi-k3"))),
  )
  assert_eq(provider.binding_model("fallback"), "kimi-k3")
}

///|
test "app binding falls back when provider has no model mapping" {
  let provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="oauth",
    provider_name="Codex OAuth",
  )
  assert_eq(provider.binding_model("gpt-5.6-sol"), "gpt-5.6-sol")
}
