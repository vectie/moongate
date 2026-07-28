///|
test "automatic app bindings are limited to real managed config writers" {
  assert_eq(moon_binding_mode("moondesk"), "automatic")
  assert_eq(moon_binding_mode("moonclaw"), "automatic")
  assert_eq(moon_binding_mode("codex"), "automatic")
  assert_eq(moon_binding_mode("claude-desktop"), "automatic")
  assert_eq(moon_binding_mode("claude"), "manual")
  assert_eq(moon_binding_mode("gemini"), "manual")
  assert_eq(moon_binding_mode("opencode"), "manual")
  assert_eq(moon_binding_mode("openclaw"), "manual")
  assert_eq(moon_binding_mode("hermes"), "manual")
}

///|
test "MoonDesk and MoonClaw bindings use the OpenClaw provider scope" {
  assert_eq(moon_binding_provider_app_type("moondesk"), "openclaw")
  assert_eq(moon_binding_provider_app_type("moonclaw"), "openclaw")
  assert_eq(moon_binding_provider_app_type("claude"), "claude")
}

///|
async test "MoonClaw binding requires canonical onboarding config" {
  @fsx.with_temporary_directory("moongate-moonclaw-init-XXXXXX", tmpdir => {
    assert_false(moon_binding_moonclaw_initialized(tmpdir))
    let path = moon_binding_moonclaw_config_path(tmpdir)
    @fsx.make_directory(@pathx.dirname(path), recursive=true, exists_ok=true)
    @fsx.write_to_file(
      path,
      ({ "agents": {}, "gateway": {} } : Json).stringify(),
      create=0o600,
    )
    assert_true(moon_binding_moonclaw_initialized(tmpdir))
  })
}

///|
async test "MoonClaw binding owns only the moongate provider entry" {
  @fsx.with_temporary_directory("moongate-moonclaw-binding-XXXXXX", tmpdir => {
    let config_path = moon_binding_moonclaw_config_path(tmpdir)
    let provider_path = moon_binding_moondesk_provider_path(tmpdir)
    @fsx.make_directory(
      @pathx.dirname(config_path),
      recursive=true,
      exists_ok=true,
    )
    @fsx.write_to_file(
      config_path,
      ({ "agents": {}, "gateway": {} } : Json).stringify(),
      create=0o600,
    )
    @fsx.write_to_file(
      provider_path,
      (
        {
          "providers": {
            "direct": {
              "baseUrl": "https://api.example/v1",
              "apiKey": "sk-existing",
              "models": [],
            },
          },
        } : Json).stringify(),
      create=0o600,
    )
    assert_false(moon_binding_moongate_provider_exists(tmpdir))
    guard moon_binding_write_moondesk_provider(
        tmpdir, "127.0.0.1", 18081, "openai/gpt-5.6-sol",
      )
      is Ok(_) else {
      fail("expected MoonGate provider merge")
    }
    guard @json.parse(@fsx.read_file(provider_path)) is Object(root) else {
      fail("expected provider manifest")
    }
    guard root["providers"] is Object(providers) else {
      fail("expected provider map")
    }
    assert_true(providers.get("direct") is Some(_))
    guard providers["moongate"] is Object(moongate) else {
      fail("expected moongate provider")
    }
    assert_eq(
      moongate["baseUrl"],
      Json::string("http://127.0.0.1:18081/openclaw/v1"),
    )
    assert_true(moon_binding_moongate_provider_exists(tmpdir))
    guard moon_binding_remove_moondesk_provider(tmpdir) is Ok(_) else {
      fail("expected MoonGate provider removal")
    }
    guard @json.parse(@fsx.read_file(provider_path)) is Object(after) else {
      fail("expected provider manifest after removal")
    }
    guard after["providers"] is Object(after_providers) else {
      fail("expected provider map after removal")
    }
    assert_true(after_providers.get("direct") is Some(_))
    assert_true(after_providers.get("moongate") is None)
    assert_false(moon_binding_moongate_provider_exists(tmpdir))
  })
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
async test "MoonDesk binding reuses its managed MoonClaw runtime" {
  @fsx.with_temporary_directory("moongate-moondesk-runtime-XXXXXX", tmpdir => {
    let runtime_dir = @pathx.join(tmpdir, "runtime")
    let command = @pathx.join(runtime_dir, "moonclaw")
    @fsx.make_directory(runtime_dir, recursive=true, exists_ok=true)
    @fsx.write_to_file(command, "managed runtime", create=0o755)
    let service_path = moon_binding_moondesk_service_path(tmpdir)
    @fsx.make_directory(
      @pathx.dirname(service_path),
      recursive=true,
      exists_ok=true,
    )
    let service : Json = {
      "kind": "moondesk-moonclaw-service.v1",
      "cwd": runtime_dir,
      "daemon": {
        "command": command,
        "args": ["daemon", "--port", "0", "--serve", tmpdir],
      },
    }
    @fsx.write_to_file(service_path, service.stringify(), create=0o600)
    assert_eq(
      moon_binding_existing_moondesk_runtime(tmpdir),
      Some((command, ["daemon", "--port", "0", "--serve", tmpdir], runtime_dir)),
    )
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
