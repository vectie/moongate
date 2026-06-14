///|
fn ccs_provider_presets_json(path : StringView) -> Json {
  let app_type = usage_query_value_any(path, "app_type", "appType")
  let query = usage_query_value(path, "query").unwrap_or("")
  let sort_mode = usage_query_value_any(path, "sort_mode", "sortMode").unwrap_or(
    "original",
  )
  let presets = ccs_visible_provider_presets(app_type, query, sort_mode)
  Json::array(presets)
}

///|
fn ccs_visible_provider_presets(
  app_type : String?,
  query : String,
  sort_mode : String,
) -> Array[Json] {
  let filtered : Array[Json] = []
  let normalized_query = query.trim().to_lower()
  for preset in ccs_provider_preset_catalog() {
    guard preset is Object(obj) else { continue }
    match app_type {
      Some(app) if json_string_from_map(obj, "appType") != Some(app) => continue
      _ => ()
    }
    if normalized_query.is_empty() ||
      ccs_provider_preset_search_text(obj).contains(normalized_query) {
      filtered.push(preset)
    }
  }
  if sort_mode == "nameAsc" {
    filtered.sort_by(fn(left, right) {
      ccs_provider_preset_name(left).compare(ccs_provider_preset_name(right))
    })
  }
  filtered
}

///|
fn ccs_provider_preset_name(preset : Json) -> String {
  match preset {
    Object(obj) => json_string_from_map(obj, "name").unwrap_or("")
    _ => ""
  }
}

///|
fn ccs_provider_preset_search_text(obj : Map[String, Json]) -> String {
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
fn ccs_provider_preset_catalog() -> Array[Json] {
  let presets = [
    ccs_unity2_claude_preset_json("claude"),
    ccs_unity2_claude_desktop_preset_json(),
    ccs_unity2_codex_preset_json(),
    ccs_unity2_gemini_preset_json(),
    ccs_unity2_opencode_preset_json(),
    ccs_unity2_openclaw_preset_json(),
    ccs_unity2_hermes_preset_json(),
  ]
  for preset in ccs_provider_preset_summary_catalog() {
    presets.push(preset)
  }
  presets
}

///|
fn ccs_provider_preset_summary_json(
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
    "id": Json::string("\{app_type}:\{ccs_provider_summary_slug(name)}"),
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
  Json::object(obj)
}

///|
fn ccs_provider_summary_slug(name : String) -> String {
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
fn ccs_unity2_base_preset(
  app_type : String,
  settings_config : Json,
) -> Map[String, Json] {
  {
    "appType": Json::string(app_type),
    "id": Json::string("\{app_type}:unity2"),
    "name": Json::string("Unity2.ai"),
    "websiteUrl": Json::string("https://unity2.ai"),
    "apiKeyUrl": Json::string("https://unity2.ai/register?source=ccs"),
    "settingsConfig": settings_config,
    "category": Json::string("aggregator"),
    "isPartner": Json::boolean(true),
    "partnerPromotionKey": Json::string("unity2"),
    "icon": Json::string("unity2"),
  }
}

///|
fn ccs_unity2_claude_preset_json(app_type : String) -> Json {
  let obj = ccs_unity2_base_preset(
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
fn ccs_unity2_claude_desktop_preset_json() -> Json {
  let obj = ccs_unity2_base_preset("claude-desktop", Json::object({}))
  obj["baseUrl"] = Json::string("https://api.unity2.ai")
  obj["mode"] = Json::string("direct")
  obj["apiFormat"] = Json::string("anthropic")
  obj["modelRoutes"] = ccs_unity2_claude_desktop_routes_json()
  Json::object(obj)
}

///|
fn ccs_unity2_claude_desktop_routes_json() -> Json {
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
fn ccs_unity2_codex_preset_json() -> Json {
  let obj = ccs_unity2_base_preset("codex", Json::object({}))
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
fn ccs_unity2_gemini_preset_json() -> Json {
  let obj = ccs_unity2_base_preset(
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
fn ccs_unity2_opencode_preset_json() -> Json {
  let obj = ccs_unity2_base_preset(
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
  obj["templateValues"] = ccs_api_key_template_values_json()
  Json::object(obj)
}

///|
fn ccs_unity2_openclaw_preset_json() -> Json {
  let obj = ccs_unity2_base_preset(
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
  obj["templateValues"] = ccs_api_key_template_values_json()
  obj["suggestedDefaults"] = {
    "model": { "primary": Json::string("unity2/gpt-5.5") }.to_json(),
    "modelCatalog": {
      "unity2/gpt-5.5": { "alias": Json::string("GPT-5.5") }.to_json(),
    }.to_json(),
  }.to_json()
  Json::object(obj)
}

///|
fn ccs_unity2_hermes_preset_json() -> Json {
  let obj = ccs_unity2_base_preset(
    "hermes",
    {
      "name": Json::string("unity2"),
      "base_url": Json::string("https://api.unity2.ai/v1"),
      "api_key": Json::string(""),
      "api_mode": Json::string("chat_completions"),
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
fn ccs_api_key_template_values_json() -> Json {
  {
    "apiKey": {
      "label": Json::string("API Key"),
      "placeholder": Json::string(""),
      "editorValue": Json::string(""),
    }.to_json(),
  }.to_json()
}
