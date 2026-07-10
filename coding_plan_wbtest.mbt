///|
test "moonstat coding plan detects supported providers" {
  assert_true(
    moon_detect_coding_plan_provider("https://api.kimi.com/coding/v1")
    is Some(Kimi),
  )
  assert_true(
    moon_detect_coding_plan_provider("https://open.bigmodel.cn/api/paas/v4")
    is Some(ZhipuCn),
  )
  assert_true(
    moon_detect_coding_plan_provider("https://api.z.ai/api/paas/v4")
    is Some(ZhipuEn),
  )
  assert_true(
    moon_detect_coding_plan_provider("https://api.minimaxi.com/v1")
    is Some(MiniMaxCn),
  )
  assert_true(
    moon_detect_coding_plan_provider("https://api.minimax.io/v1")
    is Some(MiniMaxEn),
  )
  assert_true(
    moon_detect_coding_plan_provider("https://zenmux.example.test/quota")
    is Some(ZenMux),
  )
  assert_true(moon_detect_coding_plan_provider("https://example.test") is None)
}

///|
test "moonstat coding plan parses kimi five hour and weekly tiers" {
  guard moon_parse_kimi_coding_plan(
      {
        "limits": Json::array([
          {
            "detail": {
              "limit": Json::number(100.0),
              "remaining": Json::number(75.0),
              "resetTime": Json::string("2026-01-01T00:00:00Z"),
            }.to_json(),
          }.to_json(),
        ]),
        "usage": {
          "limit": Json::number(1000.0),
          "remaining": Json::number(250.0),
        }.to_json(),
      }.to_json(),
    ).to_json()
    is Object(quota) else {
    fail("expected quota object")
  }
  guard quota["tiers"] is Array(tiers) else { fail("expected tiers") }
  assert_eq(tiers.length(), 2)
  guard tiers[0] is Object(five_hour) else { fail("expected five hour tier") }
  assert_eq(five_hour["name"], Json::string("five_hour"))
  assert_eq(five_hour["utilization"], Json::number(25.0))
  assert_eq(five_hour["resetsAt"], Json::string("2026-01-01T00:00:00Z"))
  guard tiers[1] is Object(weekly) else { fail("expected weekly tier") }
  assert_eq(weekly["name"], Json::string("weekly_limit"))
  assert_eq(weekly["utilization"], Json::number(75.0))
}

///|
test "moonstat coding plan parses zhipu token windows by unit" {
  let tiers = moon_parse_zhipu_token_tiers(
    {
      "limits": Json::array([
        {
          "type": Json::string("TOKENS_LIMIT"),
          "unit": Json::number(6.0),
          "percentage": Json::number(53.0),
          "nextResetTime": Json::number(2000000000000.0),
        }.to_json(),
        {
          "type": Json::string("TOKENS_LIMIT"),
          "unit": Json::number(3.0),
          "percentage": Json::number(44.0),
          "nextResetTime": Json::number(1000000000000.0),
        }.to_json(),
        { "type": Json::string("TIME_LIMIT"), "percentage": Json::number(7.0) }.to_json(),
      ]),
    }.to_json(),
  )
  assert_eq(tiers.length(), 2)
  guard tiers[0] is Object(first) else { fail("expected first tier") }
  assert_eq(first["name"], Json::string("five_hour"))
  assert_eq(first["utilization"], Json::number(44.0))
  guard tiers[1] is Object(second) else { fail("expected second tier") }
  assert_eq(second["name"], Json::string("weekly_limit"))
  assert_eq(second["utilization"], Json::number(53.0))
}

///|
test "moonstat zhipu team quota request matches CCS contract" {
  let request = moon_zhipu_team_quota_request(
    "team-key", "org-123", "project-456",
  )
  assert_eq(
    request.url,
    "https://open.bigmodel.cn/api/monitor/usage/quota/limit?type=2",
  )
  assert_eq(request.headers["Authorization"], "team-key")
  assert_eq(request.headers["bigmodel-organization"], "org-123")
  assert_eq(request.headers["bigmodel-project"], "project-456")
  assert_eq(request.headers["Content-Type"], "application/json")
}

///|
async test "moonstat zhipu team quota rejects incomplete credentials before network" {
  for
    credentials in [
      ("team-key", Some("org-123"), None),
      ("team-key", None, Some("project-456")),
      ("", Some("org-123"), Some("project-456")),
    ] {
    let quota = moon_get_coding_plan_quota(
      "https://open.bigmodel.cn/api/paas/v4",
      credentials.0,
      coding_plan_provider=Some("Zhipu_Team"),
      team_organization_id=credentials.1,
      team_project_id=credentials.2,
    )
    assert_false(quota.success)
    assert_true(quota.credential_status == NotFound)
    assert_true(
      quota.error
      .unwrap_or("")
      .contains("API key + organization ID + project ID"),
    )
  }
}

///|
test "moonstat coding plan parses minimax general model only" {
  let tiers = moon_parse_minimax_tiers(
    {
      "model_remains": Json::array([
        {
          "model_name": Json::string("video"),
          "current_interval_remaining_percent": Json::number(1.0),
        }.to_json(),
        {
          "model_name": Json::string("general"),
          "current_interval_remaining_percent": Json::number(80.0),
          "current_weekly_status": Json::number(1.0),
          "current_weekly_remaining_percent": Json::number(60.0),
        }.to_json(),
      ]),
    }.to_json(),
  )
  assert_eq(tiers.length(), 2)
  guard tiers[0] is Object(five_hour) else { fail("expected five hour tier") }
  assert_eq(five_hour["name"], Json::string("five_hour"))
  assert_eq(five_hour["utilization"], Json::number(20.0))
  guard tiers[1] is Object(weekly) else { fail("expected weekly tier") }
  assert_eq(weekly["name"], Json::string("weekly_limit"))
  assert_eq(weekly["utilization"], Json::number(40.0))
}

///|
test "moonstat coding plan parses zenmux value tiers and plan message" {
  guard moon_parse_zenmux_coding_plan(
      {
        "success": Json::boolean(true),
        "data": {
          "quota_5_hour": {
            "usage_percentage": Json::number(0.25),
            "resets_at": Json::string("five-reset"),
            "used_value_usd": Json::number(1.5),
            "max_value_usd": Json::number(6.0),
          }.to_json(),
          "quota_7_day": {
            "usage_percentage": Json::number(0.75),
            "resets_at": Json::string("week-reset"),
          }.to_json(),
          "plan": { "tier": Json::string("Pro") }.to_json(),
          "account_status": Json::string("active"),
        }.to_json(),
      }.to_json(),
    ).to_json()
    is Object(quota) else {
    fail("expected quota object")
  }
  assert_eq(quota["credentialMessage"], Json::string("Pro (active)"))
  guard quota["tiers"] is Array(tiers) else { fail("expected tiers") }
  assert_eq(tiers.length(), 2)
  guard tiers[0] is Object(five_hour) else { fail("expected five hour tier") }
  assert_eq(five_hour["name"], Json::string("five_hour"))
  assert_eq(five_hour["utilization"], Json::number(25.0))
  assert_eq(five_hour["usedValueUsd"], Json::number(1.5))
  assert_eq(five_hour["maxValueUsd"], Json::number(6.0))
  guard tiers[1] is Object(weekly) else { fail("expected weekly tier") }
  assert_eq(weekly["name"], Json::string("weekly_limit"))
  assert_eq(weekly["utilization"], Json::number(75.0))
}
