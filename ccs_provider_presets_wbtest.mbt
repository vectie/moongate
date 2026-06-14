///|
test "ccs provider presets include Unity2 across suite apps" {
  guard ccs_provider_presets_json("/get_provider_presets") is Array(presets) else {
    fail("expected presets")
  }
  assert_eq(presets.length(), 354)

  let app_types : Array[String] = []
  for preset in presets {
    guard preset is Object(obj) else { fail("expected preset object") }
    if obj["name"] != Json::string("Unity2.ai") {
      continue
    }
    assert_eq(obj["category"], Json::string("aggregator"))
    assert_eq(obj["isPartner"], Json::boolean(true))
    assert_eq(obj["partnerPromotionKey"], Json::string("unity2"))
    assert_eq(obj["icon"], Json::string("unity2"))
    guard json_string_from_map(obj, "appType") is Some(app_type) else {
      fail("expected app type")
    }
    app_types.push(app_type)
  }
  for
    app_type in [
      "claude", "claude-desktop", "codex", "gemini", "hermes", "openclaw", "opencode",
    ] {
    assert_true(app_types.contains(app_type))
  }
}

///|
test "ccs provider presets mirror visible ccs app counts" {
  assert_eq(
    ccs_visible_provider_presets(Some("claude"), "", "original").length(),
    63,
  )
  assert_eq(
    ccs_visible_provider_presets(Some("claude-desktop"), "", "original").length(),
    60,
  )
  assert_eq(
    ccs_visible_provider_presets(Some("codex"), "", "original").length(),
    54,
  )
  assert_eq(
    ccs_visible_provider_presets(Some("gemini"), "", "original").length(),
    19,
  )
  assert_eq(
    ccs_visible_provider_presets(Some("opencode"), "", "original").length(),
    52,
  )
  assert_eq(
    ccs_visible_provider_presets(Some("openclaw"), "", "original").length(),
    53,
  )
  assert_eq(
    ccs_visible_provider_presets(Some("hermes"), "", "original").length(),
    53,
  )
}

///|
test "ccs provider presets filter by app and search text" {
  guard ccs_provider_presets_json(
      "/get_provider_presets?appType=gemini&query=unity2",
    )
    is Array(presets) else {
    fail("expected presets")
  }
  assert_eq(presets.length(), 1)
  guard presets[0] is Object(preset) else { fail("expected preset") }
  assert_eq(preset["appType"], Json::string("gemini"))
  assert_eq(preset["baseURL"], Json::string("https://api.unity2.ai"))
  assert_eq(preset["model"], Json::string("gemini-3.1-pro"))
  guard preset["settingsConfig"] is Object(settings) else {
    fail("expected settings")
  }
  guard settings["env"] is Object(env) else { fail("expected env") }
  assert_eq(
    env["GOOGLE_GEMINI_BASE_URL"],
    Json::string("https://api.unity2.ai"),
  )
}

///|
test "ccs provider presets name sort keeps full visible set" {
  let entries = ccs_visible_provider_presets(None, "", "nameAsc")
  assert_eq(entries.length(), 354)
  assert_eq(ccs_provider_preset_name(entries[0]), "自定义")
  assert_eq(
    ccs_provider_preset_name(entries[entries.length() - 1]),
    "Xiaomi MiMo Token Plan (China)",
  )
}

///|
test "ccs provider presets search across generated ccs catalog" {
  let pateway = ccs_visible_provider_presets(None, "pateway", "original")
  assert_eq(pateway.length(), 3)
  let official = ccs_visible_provider_presets(None, "official", "nameAsc")
  assert_true(official.length() >= 3)
  let mut found_official_category = false
  for preset in official {
    guard preset is Object(obj) else { fail("expected preset object") }
    if obj["category"] == Json::string("official") {
      found_official_category = true
    }
  }
  assert_true(found_official_category)
}
