///|
test "moongate provider presets include Unity2 across suite apps" {
  guard moon_provider_presets_json("/providers/presets") is Array(presets) else {
    fail("expected presets")
  }
  assert_eq(presets.length(), 519)

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
    moon_visible_provider_presets(Some("moondesk"), "", "original").length(),
    17,
  )
  assert_eq(
    moon_visible_provider_presets(Some("moonclaw"), "", "original").length(),
    15,
  )
  assert_eq(
    moon_visible_provider_presets(Some("moonbook"), "", "original").length(),
    15,
  )
  assert_eq(
    moon_visible_provider_presets(Some("moontown"), "", "original").length(),
    15,
  )
  assert_eq(
    moon_visible_provider_presets(Some("claude"), "", "original").length(),
    78,
  )
  assert_eq(
    moon_visible_provider_presets(Some("claude-desktop"), "", "original").length(),
    75,
  )
  assert_eq(
    moon_visible_provider_presets(Some("codex"), "", "original").length(),
    69,
  )
  assert_eq(
    moon_visible_provider_presets(Some("gemini"), "", "original").length(),
    34,
  )
  assert_eq(
    moon_visible_provider_presets(Some("opencode"), "", "original").length(),
    67,
  )
  assert_eq(
    moon_visible_provider_presets(Some("openclaw"), "", "original").length(),
    68,
  )
  assert_eq(
    moon_visible_provider_presets(Some("hermes"), "", "original").length(),
    68,
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
  assert_eq(oauth_preset["targetAppType"], Json::string("moondesk"))
  assert_eq(oauth_preset["targetAppLabel"], Json::string("MoonDesk"))
  assert_eq(oauth_preset["providerAppType"], Json::string("codex"))
  assert_eq(oauth_form["id"], Json::string("codex-oauth"))
  assert_eq(oauth_form["templateLabel"], Json::string("Codex OAuth"))
  assert_false(oauth_form.contains("apiKey"))

  let moondesk_oauth = moon_visible_provider_presets(
    Some("moondesk"),
    "openai official",
    "original",
  )
  assert_eq(moondesk_oauth.length(), 1)
}

///|
test "moongate provider presets expose provider groups for every consumer target" {
  let provider_ids = [
    "deepseek-official", "openrouter", "openrouter-free", "openrouter-ling-free",
    "openrouter-nemotron-ultra-free", "openrouter-laguna-free", "fireworks", "siliconflow",
    "qwen-token-plan", "qwen-pay-as-you-go", "google-gemini", "anthropic-official",
    "openai-official", "zhipu-glm", "moonshot-kimi",
  ]
  let targets = moon_provider_template_targets()
  assert_eq(targets.length(), 11)
  assert_eq(targets[0].id, "moondesk")
  assert_eq(targets[0].priority, 0)
  for target in targets {
    let presets : Array[Json] = []
    for preset in moon_ready_provider_template_catalog() {
      guard preset is Object(obj) else { fail("expected preset") }
      if obj["appType"] == Json::string(target.id) {
        presets.push(preset)
      }
    }
    assert_eq(presets.length(), 15)
    let seen : Array[String] = []
    for preset in presets {
      guard preset is Object(obj) else { fail("expected preset") }
      guard obj["form"] is Object(form) else { fail("expected ready form") }
      assert_eq(obj["targetAppLabel"], Json::string(target.label))
      assert_eq(obj["providerAppType"], Json::string(target.provider_app_type))
      assert_eq(form["appType"], Json::string(target.provider_app_type))
      assert_false(form.contains("apiKey"))
      guard json_string_from_map(form, "id") is Some(provider_id) else {
        fail("expected provider id")
      }
      seen.push(provider_id)
      guard form["modelMapping"] is Object(mapping) else {
        fail("expected model mapping")
      }
      assert_true(mapping.contains("defaultModel"))
    }
    for provider_id in provider_ids {
      assert_true(seen.contains(provider_id))
    }
  }
}

///|
test "moongate Moon Suite templates share the correct provider scopes" {
  let expected : Map[String, String] = {
    "moondesk": "codex",
    "moonclaw": "openclaw",
    "moonbook": "openclaw",
    "moontown": "openclaw",
  }
  for preset in moon_ready_provider_template_catalog() {
    guard preset is Object(obj) else { fail("expected preset") }
    guard json_string_from_map(obj, "appType") is Some(target) else {
      fail("expected target app")
    }
    guard expected.get(target) is Some(provider_app_type) else { continue }
    assert_eq(obj["providerAppType"], Json::string(provider_app_type))
    guard obj["form"] is Object(form) else { fail("expected form") }
    assert_eq(form["appType"], Json::string(provider_app_type))
  }
}

///|
test "moongate provider forms preserve endpoint and protocol distinctions" {
  let forms = moon_provider_template_seeds()
  assert_eq(forms.length(), 15)
  let by_id : Map[String, ProviderTemplateSeed] = {}
  for seed in forms {
    by_id[seed.id] = seed
  }
  assert_eq(by_id["deepseek-official"].api_format, "openai_chat")
  assert_eq(by_id["openrouter"].base_url, "https://openrouter.ai/api/v1")
  for
    entry in [
      ("openrouter-free", "openrouter/free"),
      ("openrouter-ling-free", "inclusionai/ling-3.0-flash:free"),
      (
        "openrouter-nemotron-ultra-free", "nvidia/nemotron-3-ultra-550b-a55b:free",
      ),
      ("openrouter-laguna-free", "poolside/laguna-m.1:free"),
    ] {
    let (id, model) = entry
    assert_eq(by_id[id].base_url, "https://openrouter.ai/api/v1")
    assert_eq(by_id[id].api_format, "openai_chat")
    assert_eq(by_id[id].provider_type, "openrouter")
    assert_eq(by_id[id].default_model, model)
    assert_eq(by_id[id].category, "free")
  }
  assert_eq(
    by_id["qwen-token-plan"].base_url,
    "https://token-plan.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
  )
  assert_eq(by_id["google-gemini"].api_format, "gemini_native")
  assert_eq(by_id["anthropic-official"].api_format, "anthropic")
  assert_eq(by_id["openai-official"].api_format, "openai")
  assert_eq(by_id["zhipu-glm"].base_url, "https://open.bigmodel.cn/api/paas/v4")
  assert_eq(by_id["moonshot-kimi"].default_model, "kimi-k3")
}

///|
test "moongate provider presets name sort keeps full visible set" {
  let entries = moon_visible_provider_presets(None, "", "nameAsc")
  assert_eq(entries.length(), 519)
  assert_eq(moon_provider_preset_name(entries[0]), "自定义")
  assert_eq(
    moon_provider_preset_name(entries[entries.length() - 1]),
    "OpenRouter Nemotron 3 Ultra (Free)",
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
