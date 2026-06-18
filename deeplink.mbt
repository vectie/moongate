///|
fn moon_deeplink_supported_app(app : String) -> Bool {
  [
    "claude", "claude-desktop", "codex", "gemini", "opencode", "openclaw", "hermes",
  ].contains(moon_normalize_app_type(app))
}

///|
fn moon_parse_deeplink_url_json(url : String) -> Json? {
  let scheme = "moonstat://"
  guard url.has_prefix(scheme) else { return None }
  let rest = url[scheme.length():]
  guard rest.find("/") is Some(slash_index) else { return None }
  let version = rest[:slash_index].to_owned()
  guard version == "v1" else { return None }
  let path_and_query = rest[slash_index + 1:]
  guard path_and_query.find("?") is Some(question_index) else { return None }
  guard path_and_query[:question_index] == "import" else { return None }
  let query_path = "?\{path_and_query[question_index + 1:]}"
  guard usage_query_value(query_path, "resource") is Some(resource) else {
    return None
  }
  let request : Map[String, Json] = {
    "version": Json::string(version),
    "resource": Json::string(resource),
  }
  match resource {
    "provider" => moon_parse_provider_deeplink_params(query_path, request)
    "prompt" => moon_parse_prompt_deeplink_params(query_path, request)
    "mcp" => moon_parse_mcp_deeplink_params(query_path, request)
    "skill" => moon_parse_skill_deeplink_params(query_path, request)
    _ => None
  }
}

///|
fn moon_parse_provider_deeplink_params(
  query_path : String,
  request : Map[String, Json],
) -> Json? {
  guard usage_query_value(query_path, "appType") is Some(app) &&
    moon_deeplink_supported_app(app) else {
    return None
  }
  guard usage_query_value(query_path, "name") is Some(name) else { return None }
  request["appType"] = Json::string(moon_normalize_app_type(app))
  request["name"] = Json::string(name)
  for
    key in [
      "homepage", "endpoint", "apiKey", "model", "notes", "haikuModel", "sonnetModel",
      "opusModel", "icon", "config", "configFormat", "configUrl", "usageScript",
      "usageApiKey", "usageBaseUrl", "usageAccessToken", "usageUserId",
    ] {
    moon_deeplink_put_query_string(request, query_path, key)
  }
  moon_deeplink_put_query_bool(request, query_path, "enabled")
  moon_deeplink_put_query_bool(request, query_path, "usageEnabled")
  moon_deeplink_put_query_int(request, query_path, "usageAutoInterval")
  Some(Json::object(request))
}

///|
fn moon_parse_prompt_deeplink_params(
  query_path : String,
  request : Map[String, Json],
) -> Json? {
  guard usage_query_value(query_path, "appType") is Some(app) &&
    moon_deeplink_supported_app(app) else {
    return None
  }
  guard usage_query_value(query_path, "name") is Some(name) else { return None }
  guard usage_query_value(query_path, "content") is Some(content) else {
    return None
  }
  request["appType"] = Json::string(moon_normalize_app_type(app))
  request["name"] = Json::string(name)
  request["content"] = Json::string(content)
  moon_deeplink_put_query_string(request, query_path, "description")
  moon_deeplink_put_query_bool(request, query_path, "enabled")
  Some(Json::object(request))
}

///|
fn moon_parse_mcp_deeplink_params(
  query_path : String,
  request : Map[String, Json],
) -> Json? {
  guard usage_query_value(query_path, "apps") is Some(apps) else { return None }
  for raw in apps.split(",") {
    let app = raw.trim().to_owned()
    if !moon_deeplink_supported_app(app) {
      return None
    }
  }
  guard usage_query_value(query_path, "config") is Some(config) else {
    return None
  }
  request["apps"] = Json::string(apps)
  request["config"] = Json::string(config)
  request["configFormat"] = Json::string("json")
  moon_deeplink_put_query_bool(request, query_path, "enabled")
  Some(Json::object(request))
}

///|
fn moon_parse_skill_deeplink_params(
  query_path : String,
  request : Map[String, Json],
) -> Json? {
  guard usage_query_value(query_path, "repo") is Some(repo) else { return None }
  guard moon_deeplink_valid_repo(repo) else { return None }
  request["repo"] = Json::string(repo)
  request["appType"] = Json::string("claude")
  moon_deeplink_put_query_string(request, query_path, "directory")
  moon_deeplink_put_query_string(request, query_path, "branch")
  moon_deeplink_put_query_bool(request, query_path, "enabled")
  Some(Json::object(request))
}

///|
fn moon_deeplink_put_query_string(
  request : Map[String, Json],
  query_path : String,
  key : String,
) -> Unit {
  match usage_query_value(query_path, key) {
    Some(value) => request[key] = Json::string(value)
    None => ()
  }
}

///|
fn moon_deeplink_put_query_bool(
  request : Map[String, Json],
  query_path : String,
  key : String,
) -> Unit {
  match usage_query_value(query_path, key) {
    Some("true") => request[key] = Json::boolean(true)
    Some("false") => request[key] = Json::boolean(false)
    _ => ()
  }
}

///|
fn moon_deeplink_put_query_int(
  request : Map[String, Json],
  query_path : String,
  key : String,
) -> Unit {
  match usage_query_value(query_path, key) {
    Some(value) =>
      try @string.parse_int(value, base=10) catch {
        _ => ()
      } noraise {
        parsed => request[key] = Json::number(parsed.to_double())
      }
    None => ()
  }
}

///|
fn moon_deeplink_valid_repo(repo : String) -> Bool {
  let parts = moon_deeplink_repo_parts(repo)
  parts.length() == 2 &&
  !parts[0].trim().is_empty() &&
  !parts[1].trim().is_empty()
}

///|
fn moon_deeplink_repo_parts(repo : String) -> Array[String] {
  let parts : Array[String] = []
  for part in repo.split("/") {
    parts.push(part.to_owned())
  }
  parts
}

///|
fn moon_deeplink_request_payload(path : StringView, body : Json?) -> Json? {
  match moon_json_request(path, body, ["request"]) {
    Some(Object(obj)) => return Some(Json::object(obj))
    _ => ()
  }
  match proxy_string_request(path, body, ["url"]) {
    Some(url) => return moon_parse_deeplink_url_json(url)
    None => ()
  }
  match body {
    Some(Object(obj)) =>
      if obj.get("resource") is Some(_) {
        Some(Json::object(obj))
      } else {
        None
      }
    _ => None
  }
}

///|
fn moon_merge_deeplink_config_json(request : Json) -> Json? {
  guard request is Object(obj) else { return None }
  let next = obj
  guard json_string_from_map(next, "resource") is Some("provider") else {
    return Some(Json::object(next))
  }
  let config = json_string_from_map(next, "config")
  let format = json_string_from_map(next, "configFormat").unwrap_or("json")
  guard config is Some(encoded) else { return Some(Json::object(next)) }
  guard format == "json" else { return None }
  guard moon_deeplink_decode_json(encoded) is Some(decoded) else { return None }
  guard decoded is Object(config_obj) else { return None }
  let app = json_string_from_map(next, "appType").unwrap_or("")
  match moon_normalize_app_type(app) {
    "claude" | "claude-desktop" =>
      moon_merge_claude_deeplink_config(next, config_obj)
    "gemini" => moon_merge_gemini_deeplink_config(next, config_obj)
    "opencode" | "openclaw" | "hermes" =>
      moon_merge_additive_deeplink_config(next, config_obj)
    _ => ()
  }
  Some(Json::object(next))
}

///|
fn moon_merge_claude_deeplink_config(
  request : Map[String, Json],
  config : Map[String, Json],
) -> Unit {
  guard config.get("env") is Some(Object(env)) else { return }
  moon_deeplink_fill_string(request, "apiKey", env, "ANTHROPIC_AUTH_TOKEN")
  moon_deeplink_fill_string(request, "endpoint", env, "ANTHROPIC_BASE_URL")
  moon_deeplink_fill_string(request, "model", env, "ANTHROPIC_MODEL")
  moon_deeplink_fill_string(
    request, "haikuModel", env, "ANTHROPIC_DEFAULT_HAIKU_MODEL",
  )
  moon_deeplink_fill_string(
    request, "sonnetModel", env, "ANTHROPIC_DEFAULT_SONNET_MODEL",
  )
  moon_deeplink_fill_string(
    request, "opusModel", env, "ANTHROPIC_DEFAULT_OPUS_MODEL",
  )
  moon_deeplink_fill_homepage(request)
}

///|
fn moon_merge_gemini_deeplink_config(
  request : Map[String, Json],
  config : Map[String, Json],
) -> Unit {
  moon_deeplink_fill_string(request, "apiKey", config, "GEMINI_API_KEY")
  moon_deeplink_fill_string(
    request, "endpoint", config, "GOOGLE_GEMINI_BASE_URL",
  )
  moon_deeplink_fill_string(request, "endpoint", config, "GEMINI_BASE_URL")
  moon_deeplink_fill_string(request, "model", config, "GEMINI_MODEL")
  moon_deeplink_fill_homepage(request)
}

///|
fn moon_merge_additive_deeplink_config(
  request : Map[String, Json],
  config : Map[String, Json],
) -> Unit {
  moon_deeplink_fill_string(request, "apiKey", config, "apiKey")
  moon_deeplink_fill_string(request, "endpoint", config, "baseUrl")
  moon_deeplink_fill_homepage(request)
}

///|
fn moon_deeplink_fill_string(
  request : Map[String, Json],
  request_key : String,
  source : Map[String, Json],
  source_key : String,
) -> Unit {
  if json_string_from_map(request, request_key) is Some(value) &&
    !value.trim().is_empty() {
    return
  }
  match json_string_from_map(source, source_key) {
    Some(value) if !value.trim().is_empty() =>
      request[request_key] = Json::string(value)
    _ => ()
  }
}

///|
fn moon_deeplink_fill_homepage(request : Map[String, Json]) -> Unit {
  if json_string_from_map(request, "homepage") is Some(value) &&
    !value.trim().is_empty() {
    return
  }
  match json_string_from_map(request, "endpoint") {
    Some(endpoint) =>
      match moon_deeplink_infer_homepage(endpoint) {
        Some(homepage) => request["homepage"] = Json::string(homepage)
        None => ()
      }
    None => ()
  }
}

///|
fn moon_deeplink_infer_homepage(endpoint : String) -> String? {
  guard endpoint.has_prefix("http://") || endpoint.has_prefix("https://") else {
    return None
  }
  let without_scheme = if endpoint.has_prefix("https://") {
    endpoint["https://".length():]
  } else {
    endpoint["http://".length():]
  }
  let host = match without_scheme.find("/") {
    Some(index) => without_scheme[:index].to_owned()
    None => without_scheme.to_owned()
  }
  if host.is_empty() {
    return None
  }
  let clean = if host.has_prefix("api.") {
    host["api.".length():].to_owned()
  } else if host.has_prefix("api-") {
    host["api-".length():].to_owned()
  } else {
    host
  }
  Some("https://\{clean}")
}

///|
fn moon_deeplink_decode_json(encoded : String) -> Json? {
  guard moon_deeplink_decode_utf8(encoded) is Some(text) else { return None }
  Some(@json.parse(text) catch { _ => return None })
}

///|
fn moon_deeplink_decode_utf8(encoded : String) -> String? {
  let normalized = moon_deeplink_padded_base64(encoded)
    .replace(old=" ", new="+")
    .replace(old="-", new="+")
    .replace(old="_", new="/")
  let bytes = @base64.decode(normalized, ignore_whitespace=true) catch {
    _ => return None
  }
  Some(@encoding/utf8.decode(bytes) catch { _ => return None })
}

///|
fn moon_deeplink_padded_base64(encoded : String) -> String {
  let trimmed = encoded.trim().to_owned()
  let remainder = trimmed.length() % 4
  if remainder == 0 {
    trimmed
  } else {
    trimmed + "=".repeat(4 - remainder)
  }
}

///|
async fn ConfigService::moon_import_from_deeplink_json(
  self : ConfigService,
  proxy : ProxyService,
  request : Json,
) -> Json? {
  guard moon_merge_deeplink_config_json(request) is Some(merged) else {
    return None
  }
  guard merged is Object(obj) else { return None }
  match json_string_from_map(obj, "resource") {
    Some("provider") => self.moon_import_provider_deeplink(proxy, obj)
    Some("prompt") => self.moon_import_prompt_deeplink(obj)
    Some("mcp") => self.moon_import_mcp_deeplink(obj)
    Some("skill") => self.moon_import_skill_deeplink(obj)
    _ => None
  }
}

///|
fn ConfigService::moon_import_provider_deeplink(
  self : ConfigService,
  proxy : ProxyService,
  request : Map[String, Json],
) -> Json? {
  ignore(self)
  guard json_string_from_map(request, "appType") is Some(app) else {
    return None
  }
  guard json_string_from_map(request, "name") is Some(name) else { return None }
  guard json_string_from_map(request, "apiKey") is Some(api_key) else {
    return None
  }
  guard json_string_from_map(request, "endpoint") is Some(endpoint) else {
    return None
  }
  let app_type = moon_normalize_app_type(app)
  let provider_id = moon_deeplink_generated_id(name)
  let primary_endpoint = moon_deeplink_primary_endpoint(endpoint)
  let target = ProviderRouteTarget::new(
    app_type~,
    provider_id~,
    provider_name=name,
    provider_type=Some("custom"),
    base_url=Some(primary_endpoint),
    api_key=Some(api_key),
    settings_config=Some(moon_deeplink_provider_settings(app_type, request)),
  )
  proxy.provider_router.upsert_provider(target)
  if json_bool_from_map_any(request, ["enabled"]).unwrap_or(false) ||
    proxy.provider_router.current_provider_id(app_type) is None {
    proxy.provider_router.set_current_provider(app_type, provider_id)
  }
  Json::object({
    "type": Json::string("provider"),
    "id": Json::string(provider_id),
  })
  |> Some
}

///|
fn moon_deeplink_provider_settings(
  app_type : String,
  request : Map[String, Json],
) -> Json {
  let api_key = json_string_from_map(request, "apiKey").unwrap_or("")
  let endpoint = moon_deeplink_primary_endpoint(
    json_string_from_map(request, "endpoint").unwrap_or(""),
  )
  let model = json_string_from_map(request, "model")
  match app_type {
    "codex" =>
      Json::object({
        "auth": Json::object({ "OPENAI_API_KEY": Json::string(api_key) }),
        "config": Json::string(
          "model_provider = \"custom\"\nmodel = \"\{model.unwrap_or("gpt-5-codex")}\"\n\n[model_providers.custom]\nname = \"custom\"\nbase_url = \"\{endpoint}\"\nwire_api = \"responses\"\nrequires_openai_auth = true\n",
        ),
      })
    "gemini" => {
      let env : Map[String, Json] = {
        "GEMINI_API_KEY": Json::string(api_key),
        "GOOGLE_GEMINI_BASE_URL": Json::string(endpoint),
      }
      match model {
        Some(value) => env["GEMINI_MODEL"] = Json::string(value)
        None => ()
      }
      Json::object({ "env": Json::object(env) })
    }
    "opencode" | "openclaw" =>
      Json::object({
        "baseUrl": Json::string(endpoint),
        "apiKey": Json::string(api_key),
      })
    "hermes" =>
      Json::object({
        "baseUrl": Json::string(endpoint),
        "apiKey": Json::string(api_key),
        "apiMode": Json::string("chat_completions"),
      })
    _ => {
      let env : Map[String, Json] = {
        "ANTHROPIC_AUTH_TOKEN": Json::string(api_key),
        "ANTHROPIC_BASE_URL": Json::string(endpoint),
      }
      match model {
        Some(value) => env["ANTHROPIC_MODEL"] = Json::string(value)
        None => ()
      }
      moon_deeplink_fill_model_env(
        request, env, "haikuModel", "ANTHROPIC_DEFAULT_HAIKU_MODEL",
      )
      moon_deeplink_fill_model_env(
        request, env, "sonnetModel", "ANTHROPIC_DEFAULT_SONNET_MODEL",
      )
      moon_deeplink_fill_model_env(
        request, env, "opusModel", "ANTHROPIC_DEFAULT_OPUS_MODEL",
      )
      Json::object({ "env": Json::object(env) })
    }
  }
}

///|
fn moon_deeplink_fill_model_env(
  request : Map[String, Json],
  env : Map[String, Json],
  request_key : String,
  env_key : String,
) -> Unit {
  match json_string_from_map(request, request_key) {
    Some(value) => env[env_key] = Json::string(value)
    None => ()
  }
}

///|
fn moon_deeplink_primary_endpoint(endpoint : String) -> String {
  let parts : Array[String] = []
  for part in endpoint.split(",") {
    parts.push(part.to_owned())
  }
  let mut first = if parts.length() == 0 { endpoint } else { parts[0] }
  first = first.trim().to_owned()
  while first.has_suffix("/") {
    first = first[:first.length() - 1].to_owned()
  }
  first
}

///|
fn moon_deeplink_generated_id(name : String) -> String {
  let builder = StringBuilder::new()
  for ch in name {
    match ch {
      'A'..='Z' => builder.write_char((ch.to_int() + 32).unsafe_to_char())
      'a'..='z' | '0'..='9' | '-' | '_' => builder.write_char(ch)
      _ => ()
    }
  }
  let sanitized = builder.to_string()
  let prefix = if sanitized.is_empty() { "provider" } else { sanitized }
  let gen = @uuid.generator(@random.Rand::new())
  "\{prefix}-\{gen.v4()}"
}

///|
fn ConfigService::moon_import_prompt_deeplink(
  self : ConfigService,
  request : Map[String, Json],
) -> Json? {
  guard json_string_from_map_any(request, ["appType"]) is Some(app) else {
    return None
  }
  guard json_string_from_map_any(request, ["name"]) is Some(name) else {
    return None
  }
  guard json_string_from_map_any(request, ["content"]) is Some(encoded) else {
    return None
  }
  guard moon_deeplink_decode_utf8(encoded) is Some(content) else { return None }
  let id = moon_deeplink_generated_id(name)
  let enabled = json_bool_from_map_any(request, ["enabled"]).unwrap_or(false)
  let now = Json::string(@async.now().to_string())
  let prompt : Map[String, Json] = {
    "id": Json::string(id),
    "name": Json::string(name),
    "content": Json::string(content),
    "enabled": Json::boolean(enabled),
    "createdAt": now,
    "updatedAt": now,
  }
  match json_string_from_map_any(request, ["description"]) {
    Some(value) => prompt["description"] = Json::string(value)
    None => ()
  }
  let app_type = moon_normalize_app_type(app)
  self.prompts[moon_prompt_store_key(app_type, id)] = Json::object(prompt)
  Json::object({ "type": Json::string("prompt"), "id": Json::string(id) })
  |> Some
}

///|
fn ConfigService::moon_import_mcp_deeplink(
  self : ConfigService,
  request : Map[String, Json],
) -> Json? {
  guard json_string_from_map_any(request, ["apps"]) is Some(apps) else {
    return None
  }
  guard json_string_from_map_any(request, ["config"]) is Some(encoded) else {
    return None
  }
  guard moon_deeplink_decode_json(encoded) is Some(Object(config)) else {
    return None
  }
  guard config.get("mcpServers") is Some(Object(servers)) else { return None }
  let imported : Array[Json] = []
  let failed : Array[Json] = []
  for id in servers.keys() {
    guard servers.get(id) is Some(spec) else { continue }
    let mut server = moon_mcp_server_from_spec(id, spec, "claude")
    for raw in apps.split(",") {
      let app = raw.trim().to_owned()
      if moon_deeplink_supported_app(app) {
        server = moon_mcp_server_with_app(server, app, true)
      }
    }
    self.mcp_servers[id] = server
    imported.push(Json::string(id))
  }
  Some(
    Json::object({
      "type": Json::string("mcp"),
      "importedCount": Json::number(imported.length().to_double()),
      "importedIds": Json::array(imported),
      "failed": Json::array(failed),
    }),
  )
}

///|
async fn ConfigService::moon_import_skill_deeplink(
  self : ConfigService,
  request : Map[String, Json],
) -> Json? {
  ignore(self)
  guard json_string_from_map_any(request, ["repo"]) is Some(repo) &&
    moon_deeplink_valid_repo(repo) else {
    return None
  }
  let parts = moon_deeplink_repo_parts(repo)
  let branch = json_string_from_map_any(request, ["branch"]).unwrap_or("main")
  let repo_json = Json::object({
    "owner": Json::string(parts[0]),
    "name": Json::string(parts[1]),
    "branch": Json::string(branch),
    "enabled": Json::boolean(
      json_bool_from_map_any(request, ["enabled"]).unwrap_or(true),
    ),
  })
  guard moon_add_skill_repo_json(repo_json) == Json::boolean(true) else {
    return None
  }
  Some(
    Json::object({ "type": Json::string("skill"), "key": Json::string(repo) }),
  )
}
