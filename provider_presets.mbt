///|
fn moon_provider_presets_json(path : StringView) -> Json {
  let app_type = usage_query_value(path, "appType")
  let query = usage_query_value(path, "query").unwrap_or("")
  let sort_mode = usage_query_value(path, "sortMode").unwrap_or("original")
  let presets = moon_visible_provider_presets(app_type, query, sort_mode)
  Json::array(presets)
}

///|
fn moon_visible_provider_presets(
  app_type : String?,
  query : String,
  sort_mode : String,
) -> Array[Json] {
  let filtered : Array[Json] = []
  let normalized_query = query.trim().to_lower()
  for preset in moon_provider_preset_catalog() {
    guard preset is Object(obj) else { continue }
    match app_type {
      Some(app) if json_string_from_map(obj, "appType") != Some(app) => continue
      _ => ()
    }
    if normalized_query.is_empty() ||
      moon_provider_preset_search_text(obj).contains(normalized_query) {
      filtered.push(preset)
    }
  }
  if sort_mode == "nameAsc" {
    filtered.sort_by(fn(left, right) {
      moon_provider_preset_name(left).compare(moon_provider_preset_name(right))
    })
  }
  filtered
}

///|
fn moon_provider_preset_name(preset : Json) -> String {
  match preset {
    Object(obj) => json_string_from_map(obj, "name").unwrap_or("")
    _ => ""
  }
}

///|
fn moon_provider_preset_search_text(obj : Map[String, Json]) -> String {
  [
    json_string_from_map(obj, "name").unwrap_or(""),
    json_string_from_map(obj, "websiteUrl").unwrap_or(""),
    json_string_from_map(obj, "apiKeyUrl").unwrap_or(""),
    json_string_from_map(obj, "category").unwrap_or("others"),
    json_string_from_map(obj, "partnerPromotionKey").unwrap_or(""),
  ]
  .join(" ")
  .to_lower()
}

///|
fn moon_provider_preset_catalog() -> Array[Json] {
  let presets = [
    moon_unity2_claude_preset_json("claude"),
    moon_unity2_claude_desktop_preset_json(),
    moon_unity2_codex_preset_json(),
    moon_unity2_gemini_preset_json(),
    moon_unity2_opencode_preset_json(),
    moon_unity2_openclaw_preset_json(),
    moon_unity2_hermes_preset_json(),
  ]
  for preset in moon_provider_preset_summary_catalog() {
    presets.push(preset)
  }
  presets
}

///|
fn moon_provider_preset_summary_json(
  app_type : String,
  name : String,
  name_key : String,
  website_url : String,
  api_key_url : String,
  category : String,
  is_official : Bool,
  is_partner : Bool,
  partner_promotion_key : String,
  icon : String,
) -> Json {
  let obj : Map[String, Json] = {
    "appType": Json::string(app_type),
    "id": Json::string("\{app_type}:\{moon_provider_summary_slug(name)}"),
    "name": Json::string(name),
    "settingsConfig": Json::object({}),
  }
  if !name_key.is_empty() {
    obj["nameKey"] = Json::string(name_key)
  }
  if !website_url.is_empty() {
    obj["websiteUrl"] = Json::string(website_url)
  }
  if !api_key_url.is_empty() {
    obj["apiKeyUrl"] = Json::string(api_key_url)
  }
  if !category.is_empty() {
    obj["category"] = Json::string(category)
  }
  if is_official {
    obj["isOfficial"] = Json::boolean(true)
  }
  if is_partner {
    obj["isPartner"] = Json::boolean(true)
  }
  if !partner_promotion_key.is_empty() {
    obj["partnerPromotionKey"] = Json::string(partner_promotion_key)
  }
  if !icon.is_empty() {
    obj["icon"] = Json::string(icon)
  }
  match moon_provider_preset_form_json(app_type, name) {
    Some(form) => obj["form"] = form
    None => ()
  }
  Json::object(obj)
}

///|
fn moon_provider_preset_form_json(app_type : String, name : String) -> Json? {
  match (app_type, name) {
    ("codex", "OpenAI Official") =>
      Some(
        {
          "templateLabel": Json::string("Codex OAuth"),
          "appType": Json::string("codex"),
          "id": Json::string("codex-oauth"),
          "name": Json::string("Codex OAuth"),
          "providerType": Json::string("codex_oauth"),
          "apiFormat": Json::string("openai"),
          "enabled": Json::boolean(true),
          "modelMapping": { "defaultModel": Json::string("gpt-5.6-sol") }.to_json(),
        }.to_json(),
      )
    ("codex", "火山Agentplan") =>
      Some(moon_ark_agent_plan_provider_form_json("codex", "openai"))
    ("claude", "火山Agentplan") =>
      Some(moon_ark_agent_plan_provider_form_json("claude", "anthropic"))
    _ => None
  }
}

///|
fn moon_ark_agent_plan_provider_form_json(
  app_type : String,
  api_format : String,
) -> Json {
  let anthropic = api_format == "anthropic"
  let mapping : Map[String, Json] = { "defaultModel": Json::string("kimi-k3") }
  if anthropic {
    mapping["sonnetModel"] = Json::string("kimi-k3")
    mapping["haikuModel"] = Json::string("kimi-k3")
    mapping["opusModel"] = Json::string("kimi-k3")
  }
  {
    "templateLabel": Json::string(
      if anthropic {
        "Ark Agent Plan / Kimi K3 / Anthropic Messages"
      } else {
        "Ark Agent Plan / Kimi K3 / OpenAI Responses"
      },
    ),
    "appType": Json::string(app_type),
    "id": Json::string(
      if anthropic {
        "ark-kimi-anthropic"
      } else {
        "ark-kimi-openai"
      },
    ),
    "name": Json::string(
      if anthropic {
        "Ark Kimi Anthropic"
      } else {
        "Ark Kimi OpenAI"
      },
    ),
    "providerType": Json::string(
      if anthropic {
        "anthropic-compatible"
      } else {
        "openai-compatible"
      },
    ),
    "baseUrl": Json::string("https://ark.cn-beijing.volces.com/api/plan/v3"),
    "apiFormat": Json::string(api_format),
    "enabled": Json::boolean(true),
    "modelMapping": Json::object(mapping),
  }.to_json()
}

///|
fn moon_provider_summary_slug(name : String) -> String {
  let out = StringBuilder::new()
  let lower = name.to_lower()
  let mut last_dash = false
  for i in 0..<lower.length() {
    let ch = lower[i]
    let ok = (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')
    if ok {
      out.write_char(ch.unsafe_to_char())
      last_dash = false
    } else if !last_dash {
      out.write_char('-')
      last_dash = true
    }
  }
  let slug = out.to_string().trim(chars="-")
  if slug.is_empty() {
    "preset"
  } else {
    slug.to_owned()
  }
}

///|
fn moon_unity2_base_preset(
  app_type : String,
  settings_config : Json,
) -> Map[String, Json] {
  {
    "appType": Json::string(app_type),
    "id": Json::string("\{app_type}:unity2"),
    "name": Json::string("Unity2.ai"),
    "websiteUrl": Json::string("https://unity2.ai"),
    "apiKeyUrl": Json::string("https://unity2.ai/register?source=moongate"),
    "settingsConfig": settings_config,
    "category": Json::string("aggregator"),
    "isPartner": Json::boolean(true),
    "partnerPromotionKey": Json::string("unity2"),
    "icon": Json::string("unity2"),
  }
}

///|
fn moon_unity2_claude_preset_json(app_type : String) -> Json {
  let obj = moon_unity2_base_preset(
    app_type,
    {
      "env": {
        "ANTHROPIC_BASE_URL": Json::string("https://api.unity2.ai"),
        "ANTHROPIC_AUTH_TOKEN": Json::string(""),
      }.to_json(),
    }.to_json(),
  )
  Json::object(obj)
}

///|
fn moon_unity2_claude_desktop_preset_json() -> Json {
  let obj = moon_unity2_base_preset("claude-desktop", Json::object({}))
  obj["baseUrl"] = Json::string("https://api.unity2.ai")
  obj["mode"] = Json::string("direct")
  obj["apiFormat"] = Json::string("anthropic")
  obj["modelRoutes"] = moon_unity2_claude_desktop_routes_json()
  Json::object(obj)
}

///|
fn moon_unity2_claude_desktop_routes_json() -> Json {
  {
    "claude-sonnet-4-6": {
      "model": Json::string("claude-sonnet-4-6"),
      "supports1m": Json::boolean(true),
    }.to_json(),
    "claude-opus-4-8": {
      "model": Json::string("claude-opus-4-8"),
      "supports1m": Json::boolean(true),
    }.to_json(),
    "claude-haiku-4-5": {
      "model": Json::string("claude-haiku-4-5"),
      "supports1m": Json::boolean(true),
    }.to_json(),
  }.to_json()
}

///|
fn moon_unity2_codex_preset_json() -> Json {
  let obj = moon_unity2_base_preset("codex", Json::object({}))
  obj["auth"] = { "OPENAI_API_KEY": Json::string("") }.to_json()
  obj["config"] = Json::string(
    "model_provider = \"custom\"\nmodel = \"gpt-5.5\"\nmodel_reasoning_effort = \"high\"\ndisable_response_storage = true\n\n[model_providers.custom]\nname = \"unity2\"\nbase_url = \"https://api.unity2.ai\"\nwire_api = \"responses\"\nrequires_openai_auth = true",
  )
  obj["endpointCandidates"] = Json::array([
    Json::string("https://api.unity2.ai"),
  ])
  Json::object(obj)
}

///|
fn moon_unity2_gemini_preset_json() -> Json {
  let obj = moon_unity2_base_preset(
    "gemini",
    {
      "env": {
        "GOOGLE_GEMINI_BASE_URL": Json::string("https://api.unity2.ai"),
        "GEMINI_MODEL": Json::string("gemini-3.1-pro"),
      }.to_json(),
    }.to_json(),
  )
  obj["baseURL"] = Json::string("https://api.unity2.ai")
  obj["model"] = Json::string("gemini-3.1-pro")
  obj["description"] = Json::string("Unity2.ai")
  Json::object(obj)
}

///|
fn moon_unity2_opencode_preset_json() -> Json {
  let obj = moon_unity2_base_preset(
    "opencode",
    {
      "npm": Json::string("@ai-sdk/openai-compatible"),
      "name": Json::string("Unity2.ai"),
      "options": {
        "baseURL": Json::string("https://api.unity2.ai/v1"),
        "apiKey": Json::string(""),
        "setCacheKey": Json::boolean(true),
      }.to_json(),
      "models": { "gpt-5.5": { "name": Json::string("GPT-5.5") }.to_json() }.to_json(),
    }.to_json(),
  )
  obj["templateValues"] = moon_api_key_template_values_json()
  Json::object(obj)
}

///|
fn moon_unity2_openclaw_preset_json() -> Json {
  let obj = moon_unity2_base_preset(
    "openclaw",
    {
      "baseUrl": Json::string("https://api.unity2.ai/v1"),
      "apiKey": Json::string(""),
      "api": Json::string("openai-completions"),
      "models": Json::array([
        {
          "id": Json::string("gpt-5.5"),
          "name": Json::string("GPT-5.5"),
          "contextWindow": Json::number(400000.0),
          "cost": { "input": Json::number(5.0), "output": Json::number(15.0) }.to_json(),
        }.to_json(),
      ]),
    }.to_json(),
  )
  obj["templateValues"] = moon_api_key_template_values_json()
  obj["suggestedDefaults"] = {
    "model": { "primary": Json::string("unity2/gpt-5.5") }.to_json(),
    "modelCatalog": {
      "unity2/gpt-5.5": { "alias": Json::string("GPT-5.5") }.to_json(),
    }.to_json(),
  }.to_json()
  Json::object(obj)
}

///|
fn moon_unity2_hermes_preset_json() -> Json {
  let obj = moon_unity2_base_preset(
    "hermes",
    {
      "name": Json::string("unity2"),
      "baseUrl": Json::string("https://api.unity2.ai/v1"),
      "apiKey": Json::string(""),
      "apiMode": Json::string("chat_completions"),
      "models": Json::array([
        {
          "id": Json::string("gpt-5.5"),
          "name": Json::string("GPT-5.5"),
          "context_length": Json::number(400000.0),
        }.to_json(),
      ]),
    }.to_json(),
  )
  obj["suggestedDefaults"] = {
    "model": {
      "default": Json::string("gpt-5.5"),
      "provider": Json::string("unity2"),
    }.to_json(),
  }.to_json()
  Json::object(obj)
}

///|
fn moon_api_key_template_values_json() -> Json {
  {
    "apiKey": {
      "label": Json::string("API Key"),
      "placeholder": Json::string(""),
      "editorValue": Json::string(""),
    }.to_json(),
  }.to_json()
}
