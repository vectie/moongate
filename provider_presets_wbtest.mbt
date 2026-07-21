///|
test "moongate provider presets include Unity2 across suite apps" {
  guard moon_provider_presets_json("/providers/presets") is Array(presets) else {
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
test "moongate provider presets mirror visible moongate app counts" {
  assert_eq(
    moon_visible_provider_presets(Some("claude"), "", "original").length(),
    63,
  )
  assert_eq(
    moon_visible_provider_presets(Some("claude-desktop"), "", "original").length(),
    60,
  )
  assert_eq(
    moon_visible_provider_presets(Some("codex"), "", "original").length(),
    54,
  )
  assert_eq(
    moon_visible_provider_presets(Some("gemini"), "", "original").length(),
    19,
  )
  assert_eq(
    moon_visible_provider_presets(Some("opencode"), "", "original").length(),
    52,
  )
  assert_eq(
    moon_visible_provider_presets(Some("openclaw"), "", "original").length(),
    53,
  )
  assert_eq(
    moon_visible_provider_presets(Some("hermes"), "", "original").length(),
    53,
  )
}

///|
test "moongate provider presets filter by app and search text" {
  guard moon_provider_presets_json(
      "/providers/presets?appType=gemini&query=unity2",
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
test "moongate provider presets include ready forms without secrets" {
  let all_ark = moon_visible_provider_presets(None, "agentplan", "original")
  let mut ready_ark = 0
  let mut saw_openai = false
  let mut saw_anthropic = false
  for ark in all_ark {
    guard ark is Object(ark_preset) else { fail("expected Ark preset") }
    guard ark_preset.get("form") is Some(Object(ark_form)) else { continue }
    ready_ark += 1
    match json_string_from_map(ark_form, "apiFormat") {
      Some("openai") => {
        saw_openai = true
        assert_eq(ark_form["appType"], Json::string("codex"))
        assert_eq(
          ark_form["templateLabel"],
          Json::string("Ark Agent Plan / Kimi K3 / OpenAI Responses"),
        )
      }
      Some("anthropic") => {
        saw_anthropic = true
        assert_eq(ark_form["appType"], Json::string("claude"))
        assert_eq(
          ark_form["templateLabel"],
          Json::string("Ark Agent Plan / Kimi K3 / Anthropic Messages"),
        )
      }
      _ => fail("expected explicit Ark protocol")
    }
  }
  assert_eq(ready_ark, 2)
  assert_true(saw_openai)
  assert_true(saw_anthropic)

  let codex_ark = moon_visible_provider_presets(
    Some("codex"),
    "agentplan",
    "original",
  )
  assert_eq(codex_ark.length(), 1)
  guard codex_ark[0] is Object(preset) else { fail("expected preset") }
  guard preset["form"] is Object(form) else { fail("expected ready form") }
  assert_eq(form["id"], Json::string("ark-kimi-openai"))
  assert_eq(form["apiFormat"], Json::string("openai"))
  assert_eq(
    form["baseUrl"],
    Json::string("https://ark.cn-beijing.volces.com/api/plan/v3"),
  )
  assert_false(form.contains("apiKey"))
  guard form["modelMapping"] is Object(mapping) else {
    fail("expected model mapping")
  }
  assert_eq(mapping["defaultModel"], Json::string("kimi-k3"))

  let oauth = moon_visible_provider_presets(
    Some("codex"),
    "openai official",
    "original",
  )
  assert_eq(oauth.length(), 1)
  guard oauth[0] is Object(oauth_preset) else { fail("expected preset") }
  guard oauth_preset["form"] is Object(oauth_form) else {
    fail("expected OAuth form")
  }
  assert_eq(oauth_form["id"], Json::string("codex-oauth"))
  assert_eq(oauth_form["templateLabel"], Json::string("Codex OAuth"))
  assert_false(oauth_form.contains("apiKey"))
}

///|
test "moongate provider presets name sort keeps full visible set" {
  let entries = moon_visible_provider_presets(None, "", "nameAsc")
  assert_eq(entries.length(), 354)
  assert_eq(moon_provider_preset_name(entries[0]), "自定义")
  assert_eq(
    moon_provider_preset_name(entries[entries.length() - 1]),
    "Xiaomi MiMo Token Plan (China)",
  )
}

///|
test "moongate provider presets search across generated moongate catalog" {
  let pateway = moon_visible_provider_presets(None, "pateway", "original")
  assert_eq(pateway.length(), 3)
  let official = moon_visible_provider_presets(None, "official", "nameAsc")
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
