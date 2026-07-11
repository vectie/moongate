///|
test "config service owns settings and config blob mutations" {
  let config = ConfigService::new()
  let expected_app_config_dir = moon_app_config_dir_for_workspace_root(
    moongate_active_workspace_root(),
  )
  assert_eq(moon_app_config_dir(), expected_app_config_dir)
  assert_eq(
    moon_app_config_path(),
    @pathx.join(expected_app_config_dir, "config.json"),
  )
  config.save_settings_json(
    {
      "launchOnStartup": Json::boolean(true),
      "skipClaudeOnboarding": Json::boolean(true),
    }.to_json(),
  )
  guard config.settings_json() is Object(settings) else {
    fail("expected settings")
  }
  assert_eq(proxy_json_bool(settings, "launchOnStartup"), Some(true))
  assert_eq(proxy_json_bool(settings, "skipClaudeOnboarding"), Some(true))
  assert_true(config.auto_launch_enabled)
  assert_true(config.claude_onboarding_skipped)

  config.set_app_config_dir_override_from_request(
    "/settings/app-config-dir?path=/tmp/moongate-config",
    None,
  )
  assert_eq(
    config.app_config_dir_override_json(),
    Json::string("/tmp/moongate-config"),
  )
  config.set_app_config_dir_override_from_request(
    "/settings/app-config-dir?path=",
    None,
  )
  assert_eq(config.app_config_dir_override_json(), Json::null())
  config.set_app_config_dir_override_from_request(
    "/settings/app-config-dir?appConfigDir=/tmp/legacy",
    None,
  )
  assert_eq(config.app_config_dir_override_json(), Json::null())

  config.set_rectifier_from_request(
    "/settings/rectifier?requestThinkingSignature=false",
    None,
  )
  guard config.rectifier_json() is Object(rectifier) else {
    fail("expected rectifier")
  }
  assert_eq(proxy_json_bool(rectifier, "requestThinkingSignature"), Some(false))

  assert_true(
    config.set_optimizer_from_request(
      "/settings/optimizer?enabled=true&cacheTtl=5m",
      None,
    ),
  )
  guard config.optimizer_json() is Object(optimizer) else {
    fail("expected optimizer")
  }
  assert_eq(proxy_json_bool(optimizer, "enabled"), Some(true))
  assert_eq(json_string_from_map(optimizer, "cacheTtl"), Some("5m"))
  assert_false(
    config.set_optimizer_from_request("/settings/optimizer?cacheTtl=30m", None),
  )
  guard config.optimizer_json() is Object(optimizer_after_invalid) else {
    fail("expected optimizer after invalid update")
  }
  assert_eq(
    json_string_from_map(optimizer_after_invalid, "cacheTtl"),
    Some("5m"),
  )

  config.set_log_from_request("/settings/log?enabled=false&level=debug", None)
  guard config.log_json() is Object(log_config) else {
    fail("expected log config")
  }
  assert_eq(proxy_json_bool(log_config, "enabled"), Some(false))
  assert_eq(json_string_from_map(log_config, "level"), Some("debug"))
}
