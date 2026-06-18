///|
test "ccs provider terminal env extracts app-specific fields" {
  let provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="p1",
    provider_name="Provider",
    base_url=Some("https://api.example.test/v1"),
    api_key=Some("sk-test"),
    settings_config=Some(
      {
        "auth": Json::string("sk-auth"),
        "env": Json::object({ "EXTRA_FLAG": Json::string("1") }),
      }.to_json(),
    ),
  )
  let env = moon_provider_terminal_env(provider, "codex")
  assert_eq(env["OPENAI_API_KEY"], "sk-test")
  assert_eq(env["OPENAI_BASE_URL"], "https://api.example.test/v1")
  assert_eq(env["EXTRA_FLAG"], "1")
}

///|
test "ccs provider terminal command quotes cwd and env values" {
  let env : Map[String, String] = {
    "GOOD_KEY": "value with space",
    "BAD-KEY": "skip",
  }
  let command = moon_provider_terminal_command(
    env,
    Some("/tmp/project O'Brien"),
  )
  assert_true(command.contains("tell application \"Terminal\""))
  assert_true(command.contains("project O"))
  assert_true(command.contains("Brien"))
  assert_true(command.contains("GOOD_KEY"))
  assert_true(command.contains("value with space"))
  assert_false(command.contains("BAD-KEY"))
}

///|
test "ccs import default config accepts clean live provider settings" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="clean",
      provider_name="Clean",
      settings_config=Some(
        {
          "env": Json::object({
            "ANTHROPIC_AUTH_TOKEN": Json::string("real-token"),
          }),
        }.to_json(),
      ),
    ),
  )
  router.set_current_provider("claude", "clean")
  match moon_import_default_config_json(router, "claude") {
    Ok(value) => assert_eq(value, Json::boolean(true))
    Err(error) => fail("unexpected import error: \{error}")
  }
}

///|
test "ccs import default config rejects takeover placeholder residue" {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="polluted",
      provider_name="Polluted",
      settings_config=Some(
        {
          "auth": {
            "env": Json::object({
              "ANTHROPIC_AUTH_TOKEN": Json::string("PROXY_MANAGED"),
            }),
          }.to_json(),
        }.to_json(),
      ),
    ),
  )
  router.set_current_provider("claude", "polluted")
  assert_true(
    moon_settings_has_proxy_managed_placeholder(
      {
        "nested": Json::array([
          Json::string("real-token"),
          Json::object({ "token": Json::string("PROXY_MANAGED") }),
        ]),
      }.to_json(),
    ),
  )
  match moon_import_default_config_json(router, "claude") {
    Err(error) => assert_eq(error, "live_taken_over")
    Ok(_) => fail("expected live takeover guard")
  }
}
