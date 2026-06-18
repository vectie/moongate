///|
test "ccs subscription claude parser preserves known and unknown tiers" {
  guard moon_parse_claude_quota(
      {
        "five_hour": {
          "utilization": Json::number(25.0),
          "resets_at": Json::string("2026-01-01T00:00:00Z"),
        }.to_json(),
        "new_window": { "utilization": Json::number(50.0) }.to_json(),
        "extra_usage": {
          "is_enabled": Json::boolean(true),
          "monthly_limit": Json::number(100.0),
          "used_credits": Json::number(20.0),
          "utilization": Json::number(20.0),
          "currency": Json::string("USD"),
        }.to_json(),
      }.to_json(),
    ).to_json()
    is Object(quota) else {
    fail("expected quota object")
  }
  assert_eq(quota["tool"], Json::string("claude"))
  assert_eq(quota["credentialStatus"], Json::string("valid"))
  assert_eq(quota["success"], Json::boolean(true))
  guard quota["tiers"] is Array(tiers) else { fail("expected tiers") }
  assert_eq(tiers.length(), 2)
  assert_eq(
    tiers[0],
    {
      "name": Json::string("five_hour"),
      "utilization": Json::number(25.0),
      "resetsAt": Json::string("2026-01-01T00:00:00Z"),
    }.to_json(),
  )
  assert_eq(
    tiers[1],
    { "name": Json::string("new_window"), "utilization": Json::number(50.0) }.to_json(),
  )
  assert_eq(
    quota["extraUsage"],
    {
      "isEnabled": Json::boolean(true),
      "monthlyLimit": Json::number(100.0),
      "usedCredits": Json::number(20.0),
      "utilization": Json::number(20.0),
      "currency": Json::string("USD"),
    }.to_json(),
  )
  assert_true(quota.get("queriedAt") is Some(_))
}

///|
test "ccs subscription codex parser maps wham windows to tier names" {
  guard moon_parse_codex_quota(
      {
        "rate_limit": {
          "primary_window": {
            "used_percent": Json::number(12.5),
            "limit_window_seconds": Json::number(18000.0),
            "reset_at": Json::number(3600.0),
          }.to_json(),
          "secondary_window": {
            "used_percent": Json::number(75.0),
            "limit_window_seconds": Json::number(604800.0),
          }.to_json(),
        }.to_json(),
      }.to_json(),
      "codex",
    ).to_json()
    is Object(quota) else {
    fail("expected quota object")
  }
  guard quota["tiers"] is Array(tiers) else { fail("expected tiers") }
  assert_eq(tiers.length(), 2)
  guard tiers[0] is Object(first) else { fail("expected first tier") }
  assert_eq(first["name"], Json::string("five_hour"))
  assert_eq(first["utilization"], Json::number(12.5))
  assert_true(first.get("resetsAt") is Some(_))
  guard tiers[1] is Object(second) else { fail("expected second tier") }
  assert_eq(second["name"], Json::string("seven_day"))
  assert_eq(second["utilization"], Json::number(75.0))
}

///|
test "ccs subscription gemini parser groups buckets by model family" {
  guard moon_parse_gemini_quota(
      {
        "buckets": Json::array([
          {
            "modelId": Json::string("gemini-3-pro"),
            "remainingFraction": Json::number(0.8),
            "resetTime": Json::string("pro-reset"),
          }.to_json(),
          {
            "modelId": Json::string("gemini-2.5-flash"),
            "remainingFraction": Json::number(0.2),
          }.to_json(),
          {
            "modelId": Json::string("gemini-2.5-flash-lite"),
            "remainingFraction": Json::number(0.6),
          }.to_json(),
          {
            "modelId": Json::string("gemini-2.0-flash"),
            "remainingFraction": Json::number(0.5),
          }.to_json(),
        ]),
      }.to_json(),
    ).to_json()
    is Object(quota) else {
    fail("expected quota object")
  }
  guard quota["tiers"] is Array(tiers) else { fail("expected tiers") }
  assert_eq(tiers.length(), 3)
  guard tiers[0] is Object(pro) else { fail("expected pro tier") }
  assert_eq(pro["name"], Json::string("gemini_pro"))
  assert_eq(pro["utilization"], Json::number(19.999999999999996))
  assert_eq(pro["resetsAt"], Json::string("pro-reset"))
  guard tiers[1] is Object(flash) else { fail("expected flash tier") }
  assert_eq(flash["name"], Json::string("gemini_flash"))
  assert_eq(flash["utilization"], Json::number(80.0))
  guard tiers[2] is Object(lite) else { fail("expected flash lite tier") }
  assert_eq(lite["name"], Json::string("gemini_flash_lite"))
  assert_eq(lite["utilization"], Json::number(40.0))
}

///|
test "ccs subscription credential parsers report deterministic status" {
  let missing_claude = moon_parse_claude_credentials_json("{}")
  assert_true(missing_claude.status == ParseError)
  assert_eq(missing_claude.message, Some("No OAuth entry found in credentials"))
  let codex_api_key_json =
    #|{"auth_mode":"apikey","tokens":{"access_token":"sk"}}
  let codex_api_key = moon_parse_codex_credentials_json(codex_api_key_json)
  assert_true(codex_api_key.status == NotFound)
  assert_eq(codex_api_key.message, Some("Codex not using OAuth mode"))
  let gemini_json =
    #|{"access_token":"gem-token","refresh_token":"rt","expiry_date":9999999999999}
  let gemini = moon_parse_gemini_file_json(gemini_json)
  assert_true(gemini.status == Valid)
  assert_eq(gemini.token, Some("gem-token"))
  assert_eq(gemini.refresh_token, Some("rt"))
}

///|
test "ccs codex oauth account resolver matches tauri command fallback" {
  assert_eq(
    moon_resolve_codex_oauth_account(
      Some(" acct-explicit "),
      Some("acct-default"),
    ),
    Some("acct-explicit"),
  )
  assert_eq(
    moon_resolve_codex_oauth_account(Some("   "), Some("acct-default")),
    Some("acct-default"),
  )
  assert_eq(
    moon_resolve_codex_oauth_account(None, Some("acct-default")),
    Some("acct-default"),
  )
  assert_true(moon_resolve_codex_oauth_account(Some("   "), None) is None)
}

///|
test "moonstat codex oauth relogin message is branded" {
  assert_eq(
    moonstat_codex_oauth_relogin_message(),
    "Codex OAuth access token expired or rejected. Please re-login via moonstat.",
  )
}

///|
test "ccs subscription gemini oauth client comes from env" {
  let old_id = @os.getenv("MOONSTAT_GEMINI_OAUTH_CLIENT_ID") catch { _ => None }
  let old_secret = @os.getenv("MOONSTAT_GEMINI_OAUTH_CLIENT_SECRET") catch {
    _ => None
  }
  @os.setenv(
    "MOONSTAT_GEMINI_OAUTH_CLIENT_ID",
    "test-client-id",
    overwrite=true,
  )
  @os.setenv(
    "MOONSTAT_GEMINI_OAUTH_CLIENT_SECRET",
    "test-client-secret",
    overwrite=true,
  )
  guard moon_gemini_oauth_client() is Some(client) else {
    fail("expected env-provided gemini oauth client")
  }
  assert_eq(client.client_id, "test-client-id")
  assert_eq(client.client_secret, "test-client-secret")
  match old_id {
    Some(value) =>
      @os.setenv("MOONSTAT_GEMINI_OAUTH_CLIENT_ID", value, overwrite=true)
    None => @os.unsetenv("MOONSTAT_GEMINI_OAUTH_CLIENT_ID") catch { _ => () }
  }
  match old_secret {
    Some(value) =>
      @os.setenv("MOONSTAT_GEMINI_OAUTH_CLIENT_SECRET", value, overwrite=true)
    None =>
      @os.unsetenv("MOONSTAT_GEMINI_OAUTH_CLIENT_SECRET") catch {
        _ => ()
      }
  }
}
