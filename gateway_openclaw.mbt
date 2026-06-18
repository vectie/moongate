///|
fn moon_openclaw_workspace_dir() -> String {
  @pathx.join(
    @pathx.join(@pathx.join(moon_home_dir(), ".moonsuite"), "openclaw"),
    "workspace",
  )
}

///|
fn moon_openclaw_memory_dir() -> String {
  @pathx.join(moon_openclaw_workspace_dir(), "memory")
}

///|
async fn OpenClawService::handle_get_openclaw_default_model(
  self : OpenClawService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.openclaw_default_model.unwrap_or(Json::null()))
}

///|
async fn OpenClawService::handle_set_openclaw_default_model(
  self : OpenClawService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard openclaw_default_model_from_request(r.path, body) is Some(model) else {
    write_usage_bad_request(w, "invalid_openclaw_default_model")
    return
  }
  self.openclaw_default_model = Some(model)
  write_usage_json(w, suite_write_outcome_json())
}

///|
async fn OpenClawService::handle_get_openclaw_model_catalog(
  self : OpenClawService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.openclaw_model_catalog.unwrap_or(Json::null()))
}

///|
async fn OpenClawService::handle_set_openclaw_model_catalog(
  self : OpenClawService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard suite_object_request(r.path, body, "catalog") is Some(catalog) else {
    write_usage_bad_request(w, "invalid_openclaw_model_catalog")
    return
  }
  self.openclaw_model_catalog = Some(catalog)
  write_usage_json(w, suite_write_outcome_json())
}

///|
async fn OpenClawService::handle_get_openclaw_agents_defaults(
  self : OpenClawService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.openclaw_agents_defaults.unwrap_or(Json::null()))
}

///|
async fn OpenClawService::handle_set_openclaw_agents_defaults(
  self : OpenClawService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let defaults = match suite_object_request(r.path, body, "defaults") {
    Some(defaults) => Some(defaults)
    None =>
      match openclaw_default_model_from_request(r.path, body) {
        Some(model) => Some({ "model": model }.to_json())
        None => None
      }
  }
  guard defaults is Some(defaults_json) else {
    write_usage_bad_request(w, "invalid_openclaw_agents_defaults")
    return
  }
  self.openclaw_agents_defaults = Some(defaults_json)
  write_usage_json(w, suite_write_outcome_json())
}

///|
async fn OpenClawService::handle_get_openclaw_env(
  self : OpenClawService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.openclaw_env)
}

///|
async fn OpenClawService::handle_set_openclaw_env(
  self : OpenClawService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard openclaw_env_from_request(r.path, body) is Some(env) else {
    write_usage_bad_request(w, "invalid_openclaw_env")
    return
  }
  self.openclaw_env = env
  write_usage_json(w, suite_write_outcome_json())
}

///|
async fn OpenClawService::handle_get_openclaw_tools(
  self : OpenClawService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.openclaw_tools)
}

///|
async fn OpenClawService::handle_set_openclaw_tools(
  self : OpenClawService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard openclaw_tools_from_request(r.path, body) is Some(tools) else {
    write_usage_bad_request(w, "invalid_openclaw_tools")
    return
  }
  self.openclaw_tools = tools
  write_usage_json(w, suite_write_outcome_json())
}

///|
async fn OpenClawService::handle_get_hermes_memory(
  self : OpenClawService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard hermes_memory_kind_from_request(r.path, body) is Some(kind) else {
    write_usage_bad_request(w, "invalid_hermes_memory_kind")
    return
  }
  write_usage_json(w, Json::string(self.hermes_memory.get(kind).unwrap_or("")))
}

///|
async fn OpenClawService::handle_set_hermes_memory(
  self : OpenClawService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard hermes_memory_kind_from_request(r.path, body) is Some(kind) else {
    write_usage_bad_request(w, "invalid_hermes_memory_kind")
    return
  }
  let content = proxy_string_request(r.path, body, ["content", "value", "text"]).unwrap_or(
    "",
  )
  self.hermes_memory[kind] = content
  write_usage_json(w, Json::null())
}

///|
async fn OpenClawService::handle_get_hermes_memory_limits(
  self : OpenClawService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, hermes_memory_limits_json(self.hermes_memory_enabled))
}

///|
async fn OpenClawService::handle_set_hermes_memory_enabled(
  self : OpenClawService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard hermes_memory_kind_from_request(r.path, body) is Some(kind) else {
    write_usage_bad_request(w, "invalid_hermes_memory_kind")
    return
  }
  guard proxy_bool_request(r.path, body, ["enabled"]) is Some(enabled) else {
    write_usage_bad_request(w, "missing_enabled")
    return
  }
  self.hermes_memory_enabled[kind] = enabled
  write_usage_json(w, suite_write_outcome_json())
}

///|
async fn OpenClawService::handle_open_hermes_web_ui(
  self : OpenClawService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let port = hermes_web_port_from_request(r.path)
  let path = proxy_string_request(r.path, body, ["path"]).unwrap_or("/")
  if !hermes_web_ui_is_live(port) {
    write_usage_bad_request(w, HERMES_WEB_OFFLINE_ERROR)
    return
  }
  ignore(hermes_web_ui_target_url(port, path))
  write_usage_json(w, Json::null())
}

///|
async fn OpenClawService::handle_launch_hermes_dashboard(
  self : OpenClawService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  match launch_hermes_dashboard_standalone() {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
fn openclaw_default_tools_json() -> Json {
  { "allow": Json::array([]), "deny": Json::array([]) }.to_json()
}

///|
fn openclaw_tools_profile_is_supported(profile : String) -> Bool {
  profile == "minimal" ||
  profile == "coding" ||
  profile == "messaging" ||
  profile == "full"
}

///|
fn openclaw_health_warning_json(
  code : String,
  message : String,
  path : String?,
) -> Json {
  let warning : Map[String, Json] = {
    "code": Json::string(code),
    "message": Json::string(message),
  }
  match path {
    Some(path) => warning["path"] = Json::string(path)
    None => ()
  }
  Json::object(warning)
}

///|
fn openclaw_nested_json(config : Json, keys : Array[String]) -> Json? {
  let mut current = config
  for key in keys {
    match current {
      Object(obj) =>
        match obj.get(key) {
          Some(value) => current = value
          None => return None
        }
      _ => return None
    }
  }
  Some(current)
}

///|
fn openclaw_default_model_from_request(
  path : StringView,
  body : Json?,
) -> Json? {
  match suite_object_payload(body, "model") {
    Some(model) => return Some(model)
    None => ()
  }
  guard proxy_string_request(path, body, ["primary"]) is Some(primary) &&
    !primary.trim().is_empty() else {
    return None
  }
  Some(
    {
      "primary": Json::string(primary.trim().to_owned()),
      "fallbacks": split_csv_json(
        proxy_string_request(path, body, ["fallbacks"]).unwrap_or(""),
      ),
    }.to_json(),
  )
}

///|
fn openclaw_env_from_request(path : StringView, body : Json?) -> Json? {
  match suite_object_request(path, body, "env") {
    Some(env) => return Some(env)
    None => ()
  }
  guard proxy_string_request(path, body, ["key", "name"]) is Some(key) &&
    !key.trim().is_empty() else {
    return None
  }
  let value = proxy_string_request(path, body, ["value"]).unwrap_or("")
  let env : Map[String, Json] = {}
  env[key.trim().to_owned()] = Json::string(value)
  Some(Json::object(env))
}

///|
fn openclaw_tools_from_request(path : StringView, body : Json?) -> Json? {
  match suite_object_request(path, body, "tools") {
    Some(tools) => return Some(tools)
    None => ()
  }
  let tools : Map[String, Json] = {
    "allow": split_csv_json(
      proxy_string_request(path, body, ["allow"]).unwrap_or(""),
    ),
    "deny": split_csv_json(
      proxy_string_request(path, body, ["deny"]).unwrap_or(""),
    ),
  }
  match proxy_string_request(path, body, ["profile"]) {
    Some(profile) if !profile.trim().is_empty() =>
      tools["profile"] = Json::string(profile.trim().to_owned())
    _ => ()
  }
  Some(Json::object(tools))
}

///|
fn hermes_memory_kind_from_request(path : StringView, body : Json?) -> String? {
  match
    proxy_string_request(path, body, ["kind", "memoryKind", "memory_kind"]) {
    Some(raw) =>
      match raw.trim().to_lower() {
        "memory" => Some("memory")
        "user" => Some("user")
        _ => None
      }
    None => None
  }
}

///|
fn hermes_memory_limits_json(enabled : Map[String, Bool]) -> Json {
  {
    "memory": Json::number(2200.0),
    "user": Json::number(1375.0),
    "memoryEnabled": Json::boolean(enabled.get("memory").unwrap_or(true)),
    "userEnabled": Json::boolean(enabled.get("user").unwrap_or(true)),
  }.to_json()
}

///|
fn hermes_web_port_from_request(path : StringView) -> Int {
  match usage_query_int(path, "port") {
    Some(port) if port > 0 && port <= 65535 => return port
    _ => ()
  }
  let env_port = @os.getenv("HERMES_WEB_PORT") catch { _ => None }
  match env_port {
    Some(raw) => {
      let port = @string.parse_int(raw.trim().to_owned(), base=10) catch {
        _ => -1
      }
      if port > 0 && port <= 65535 {
        port
      } else {
        9119
      }
    }
    None => 9119
  }
}

///|
fn hermes_web_ui_path(path : String) -> String {
  if path.is_empty() {
    "/"
  } else if path.has_prefix("/") {
    path
  } else {
    "/\{path}"
  }
}

///|
fn hermes_web_ui_target_url(port : Int, path : String) -> String {
  "http://127.0.0.1:\{port}\{hermes_web_ui_path(path)}"
}

///|
fn hermes_web_ui_probe_url(port : Int) -> String {
  "http://127.0.0.1:\{port}/api/status"
}

///|
fn hermes_dashboard_background_shell_command() -> String {
  "nohup \{HERMES_DASHBOARD_COMMAND} >\{HERMES_DASHBOARD_LOG_PATH} 2>&1 &"
}

///|
async fn launch_hermes_dashboard_standalone() -> Result[Json, String] {
  let result = @spawn.spawn(
    "sh",
    ["-lc", hermes_dashboard_background_shell_command()],
    timeout=2000,
  ) catch {
    _ => return Err("hermes_dashboard_launch_failed")
  }
  if result.status != 0 {
    return Err("hermes_dashboard_launch_failed")
  }
  Ok(Json::null())
}

///|
async fn hermes_web_ui_is_live(port : Int) -> Bool {
  if !@net.localhost_port_open(port, timeout_ms=1200) {
    return false
  }
  let result = try? @http.get(hermes_web_ui_probe_url(port))
  match result {
    Ok(_) => true
    Err(_) => false
  }
}
