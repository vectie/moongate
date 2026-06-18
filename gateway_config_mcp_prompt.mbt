///|
async fn ConfigService::handle_get_claude_mcp_status(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    {
      "userConfigPath": Json::string(
        @pathx.join(moon_home_dir(), ".claude.json"),
      ),
      "userConfigExists": Json::boolean(
        @fsx.exists_as_file(@pathx.join(moon_home_dir(), ".claude.json")),
      ),
      "serverCount": Json::number(self.mcp_servers.length().to_double()),
    }.to_json(),
  )
}

///|
async fn ConfigService::handle_upsert_claude_mcp_server(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  match moon_mcp_server_from_request(r.path, body, "claude") {
    Some((id, server)) => {
      self.mcp_servers[id] = moon_mcp_server_with_app(server, "claude", true)
      write_usage_json(w, Json::boolean(true))
    }
    None => write_usage_json(w, Json::boolean(false))
  }
}

///|
async fn ConfigService::handle_delete_mcp_server(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  match proxy_string_request(r.path, body, ["id", "serverId", "server_id"]) {
    Some(id) => {
      let existed = self.mcp_servers.get(id) is Some(_)
      self.mcp_servers.remove(id)
      write_usage_json(w, Json::boolean(existed))
    }
    None => write_usage_json(w, Json::boolean(false))
  }
}

///|
async fn ConfigService::handle_validate_mcp_command(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let command = proxy_string_request(r.path, body, ["cmd", "command"]).unwrap_or(
    "",
  )
  write_usage_json(w, Json::boolean(moon_validate_mcp_command_name(command)))
}

///|
async fn ConfigService::handle_set_mcp_enabled(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  let enabled = proxy_bool_request(r.path, body, ["enabled"]).unwrap_or(true)
  match proxy_string_request(r.path, body, ["id", "serverId", "server_id"]) {
    Some(id) =>
      match self.mcp_servers.get(id) {
        Some(server) => {
          self.mcp_servers[id] = moon_mcp_server_with_app(server, app, enabled)
          write_usage_json(w, Json::boolean(true))
        }
        None => write_usage_json(w, Json::boolean(false))
      }
    None => write_usage_json(w, Json::boolean(false))
  }
}

///|
async fn ConfigService::handle_get_mcp_servers(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, moon_mcp_servers_object_for_app(self.mcp_servers, None))
}

///|
async fn ConfigService::handle_upsert_mcp_server(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  match moon_mcp_server_from_request(r.path, body, "claude") {
    Some((id, server)) => {
      self.mcp_servers[id] = server
      write_usage_json(w, Json::null())
    }
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn ConfigService::handle_toggle_mcp_app(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  let enabled = proxy_bool_request(r.path, body, ["enabled"]).unwrap_or(true)
  match proxy_string_request(r.path, body, ["serverId", "server_id", "id"]) {
    Some(id) =>
      match self.mcp_servers.get(id) {
        Some(server) => {
          self.mcp_servers[id] = moon_mcp_server_with_app(server, app, enabled)
          write_usage_json(w, Json::null())
        }
        None => write_usage_json(w, Json::null())
      }
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn ConfigService::handle_import_mcp_from_apps(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  let imported = moon_import_mcp_from_apps_count(self.mcp_servers)
  write_usage_json(w, Json::number(imported.to_double()))
}

///|
async fn ConfigService::handle_get_prompts(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  write_usage_json(w, moon_prompts_object_for_app(self.prompts, app))
}

///|
async fn ConfigService::handle_upsert_prompt(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  match moon_prompt_from_request(r.path, body) {
    Some((app, id, prompt)) =>
      self.prompts[moon_prompt_store_key(app, id)] = prompt
    None => ()
  }
  write_usage_json(w, Json::null())
}

///|
async fn ConfigService::handle_delete_prompt(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  match proxy_string_request(r.path, body, ["id", "promptId", "prompt_id"]) {
    Some(id) => self.prompts.remove(moon_prompt_store_key(app, id))
    None => ()
  }
  write_usage_json(w, Json::null())
}

///|
async fn ConfigService::handle_enable_prompt(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  match proxy_string_request(r.path, body, ["id", "promptId", "prompt_id"]) {
    Some(id) =>
      match moon_prompt_file_path_from_request(r.path, body, app) {
        Ok(file_path) =>
          match moon_enable_prompt_json(self.prompts, app, id, file_path) {
            Ok(result) => write_usage_json(w, result)
            Err(error) => write_usage_bad_request(w, error)
          }
        Err(error) => write_usage_bad_request(w, error)
      }
    None => write_usage_json(w, Json::null())
  }
}

///|
fn moon_mcp_apps_json(app : String, enabled? : Bool = true) -> Json {
  let apps = {
    "claude": Json::boolean(false),
    "claude-desktop": Json::boolean(false),
    "codex": Json::boolean(false),
    "gemini": Json::boolean(false),
    "opencode": Json::boolean(false),
    "openclaw": Json::boolean(false),
    "hermes": Json::boolean(false),
  }
  apps[moon_normalize_app_type(app)] = Json::boolean(enabled)
  Json::object(apps)
}

///|
fn moon_mcp_app_enabled(server : Json, app : String) -> Bool {
  guard server is Object(obj) else { return false }
  guard obj.get("apps") is Some(Object(apps)) else { return false }
  match apps.get(moon_normalize_app_type(app)) {
    Some(true) => true
    Some(false) => false
    _ => false
  }
}

///|
fn moon_mcp_server_with_app(
  server : Json,
  app : String,
  enabled : Bool,
) -> Json {
  let normalized = moon_normalize_app_type(app)
  match server {
    Object(obj) => {
      let next = obj
      let apps = match obj.get("apps") {
        Some(Object(existing)) => existing
        _ =>
          match moon_mcp_apps_json("claude", enabled=false) {
            Object(empty) => empty
            _ => {}
          }
      }
      apps[normalized] = Json::boolean(enabled)
      next["apps"] = Json::object(apps)
      Json::object(next)
    }
    _ => server
  }
}

///|
fn moon_mcp_server_from_request(
  path : StringView,
  body : Json?,
  default_app : String,
) -> (String, Json)? {
  match moon_json_request(path, body, ["server"]) {
    Some(Object(server)) =>
      match json_string_from_map_any(server, ["id", "serverId", "server_id"]) {
        Some(id) =>
          return Some(
            (
              id,
              moon_mcp_normalize_server(id, Json::object(server), default_app),
            ),
          )
        None => ()
      }
    _ => ()
  }
  guard proxy_string_request(path, body, ["id", "serverId", "server_id"])
    is Some(id) else {
    return None
  }
  let spec = moon_json_request(path, body, ["spec", "server"]).unwrap_or(
    Json::object({}),
  )
  Some((id, moon_mcp_server_from_spec(id, spec, default_app)))
}

///|
fn moon_mcp_server_from_spec(id : String, spec : Json, app : String) -> Json {
  let name = match spec {
    Object(obj) => json_string_from_map_any(obj, ["name"]).unwrap_or(id)
    _ => id
  }
  Json::object({
    "id": Json::string(id),
    "name": Json::string(name),
    "server": spec,
    "apps": moon_mcp_apps_json(app),
    "description": Json::null(),
    "homepage": Json::null(),
    "docs": Json::null(),
    "tags": Json::array([]),
  })
}

///|
fn moon_mcp_normalize_server(
  id : String,
  server : Json,
  default_app : String,
) -> Json {
  match server {
    Object(obj) => {
      let next = obj
      if next.get("id") is None {
        next["id"] = Json::string(id)
      }
      if next.get("name") is None {
        next["name"] = Json::string(id)
      }
      if next.get("server") is None {
        next["server"] = Json::object({})
      }
      if next.get("apps") is None {
        next["apps"] = moon_mcp_apps_json(default_app)
      }
      if next.get("tags") is None {
        next["tags"] = Json::array([])
      }
      Json::object(next)
    }
    _ => moon_mcp_server_from_spec(id, Json::object({}), default_app)
  }
}

///|
fn moon_mcp_servers_object_for_app(
  servers : Map[String, Json],
  app : String?,
) -> Json {
  let result : Map[String, Json] = {}
  for id in servers.keys() {
    guard servers.get(id) is Some(server) else { continue }
    match app {
      Some(app_type) =>
        if moon_mcp_app_enabled(server, app_type) {
          result[id] = server
        }
      None => result[id] = server
    }
  }
  Json::object(result)
}

///|
fn moon_mcp_valid_server_spec(spec : Json) -> Bool {
  guard spec is Object(obj) else { return false }
  let typ = json_string_from_map_any(obj, ["type"]).unwrap_or("stdio")
  match typ {
    "stdio" =>
      json_string_from_map_any(obj, ["command"]).unwrap_or("").trim() != ""
    "http" | "sse" =>
      json_string_from_map_any(obj, ["url"]).unwrap_or("").trim() != ""
    _ => false
  }
}

///|
fn moon_mcp_import_spec_for_app(app : String, spec : Json) -> Json {
  let normalized = moon_normalize_app_type(app)
  if normalized != "gemini" {
    return spec
  }
  match spec {
    Object(obj) => {
      let next = obj
      match next.get("httpUrl") {
        Some(http_url) => {
          next.remove("httpUrl")
          next["url"] = http_url
          next["type"] = Json::string("http")
        }
        None => ()
      }
      if next.get("type") is None {
        if next.get("command") is Some(_) {
          next["type"] = Json::string("stdio")
        } else if next.get("url") is Some(_) {
          next["type"] = Json::string("sse")
        }
      }
      Json::object(next)
    }
    _ => spec
  }
}

///|
fn moon_import_mcp_servers_map(
  servers : Map[String, Json],
  app : String,
  mcp_servers : Map[String, Json],
) -> Int {
  let mut changed = 0
  for id in mcp_servers.keys() {
    guard mcp_servers.get(id) is Some(spec) else { continue }
    let import_spec = moon_mcp_import_spec_for_app(app, spec)
    if !moon_mcp_valid_server_spec(import_spec) {
      continue
    }
    match servers.get(id) {
      Some(existing) =>
        if !moon_mcp_app_enabled(existing, app) {
          servers[id] = moon_mcp_server_with_app(existing, app, true)
          changed += 1
        }
      None => {
        servers[id] = moon_mcp_server_from_spec(id, import_spec, app)
        changed += 1
      }
    }
  }
  changed
}

///|
fn moon_import_mcp_from_root_json(
  servers : Map[String, Json],
  app : String,
  root : Json,
) -> Int {
  guard root is Object(obj) else { return 0 }
  guard obj.get("mcpServers") is Some(Object(mcp_servers)) else { return 0 }
  moon_import_mcp_servers_map(servers, app, mcp_servers)
}

///|
fn moon_import_mcp_from_codex_toml_text(
  servers : Map[String, Json],
  content : String,
) -> Int {
  let raw_specs : Map[String, Json] = {}
  let mut current_id : String? = None
  let mut current_table = ""
  for line_view in content.split("\n") {
    let line = moon_toml_strip_comment(line_view.to_owned()).trim().to_owned()
    if line.is_empty() {
      continue
    }
    if line.has_prefix("[") && line.has_suffix("]") {
      let section = line[1:line.length() - 1].trim().to_owned()
      match moon_codex_mcp_section(section) {
        Some((id, table)) => {
          current_id = Some(id)
          current_table = table
          if raw_specs.get(id) is None {
            raw_specs[id] = Json::object({})
          }
        }
        None => {
          current_id = None
          current_table = ""
        }
      }
      continue
    }
    guard current_id is Some(id) else { continue }
    guard moon_toml_assignment(line) is Some((key, raw_value)) else { continue }
    let spec = moon_codex_raw_mcp_spec(raw_specs, id)
    if current_table.is_empty() {
      match moon_toml_value(raw_value) {
        Some(value) => spec[key] = value
        None => ()
      }
    } else {
      let nested_key = if current_table == "http_headers" {
        "headers"
      } else {
        current_table
      }
      let nested = match spec.get(nested_key) {
        Some(Object(obj)) => obj
        _ => {
          let obj : Map[String, Json] = {}
          spec[nested_key] = Json::object(obj)
          obj
        }
      }
      match moon_toml_value(raw_value) {
        Some(String(value)) => nested[key] = Json::string(value)
        _ => ()
      }
    }
    raw_specs[id] = Json::object(spec)
  }
  let normalized : Map[String, Json] = {}
  for id in raw_specs.keys() {
    guard raw_specs.get(id) is Some(raw_spec) else { continue }
    normalized[id] = moon_codex_mcp_unified_spec(raw_spec)
  }
  moon_import_mcp_servers_map(servers, "codex", normalized)
}

///|
fn moon_codex_raw_mcp_spec(
  specs : Map[String, Json],
  id : String,
) -> Map[String, Json] {
  match specs.get(id) {
    Some(Object(obj)) => obj
    _ => {
      let obj : Map[String, Json] = {}
      specs[id] = Json::object(obj)
      obj
    }
  }
}

///|
fn moon_codex_mcp_section(section : String) -> (String, String)? {
  let rest = if section.has_prefix("mcp_servers.") {
    section["mcp_servers.".length():].to_owned()
  } else if section.has_prefix("mcp.servers.") {
    section["mcp.servers.".length():].to_owned()
  } else {
    return None
  }
  let parts = rest.split(".").collect()
  if parts.length() == 0 {
    return None
  }
  let id = parts[0].trim().to_owned()
  if id.is_empty() {
    return None
  }
  let table = if parts.length() > 1 { parts[1].trim().to_owned() } else { "" }
  match table {
    "" | "env" | "http_headers" | "headers" => Some((id, table))
    _ => None
  }
}

///|
fn moon_codex_mcp_unified_spec(raw_spec : Json) -> Json {
  guard raw_spec is Object(raw) else { return Json::object({}) }
  let typ = json_string_from_map_any(raw, ["type"]).unwrap_or("stdio")
  let spec : Map[String, Json] = { "type": Json::string(typ) }
  match typ {
    "stdio" => {
      match raw.get("command") {
        Some(String(command)) => spec["command"] = Json::string(command)
        _ => ()
      }
      match raw.get("args") {
        Some(Array(args)) => spec["args"] = Json::array(args)
        _ => ()
      }
      match raw.get("cwd") {
        Some(String(cwd)) if !cwd.trim().is_empty() =>
          spec["cwd"] = Json::string(cwd)
        _ => ()
      }
      match raw.get("env") {
        Some(Object(env)) => spec["env"] = Json::object(env)
        _ => ()
      }
    }
    "http" | "sse" => {
      match raw.get("url") {
        Some(String(url)) => spec["url"] = Json::string(url)
        _ => ()
      }
      match raw.get("http_headers") {
        Some(Object(headers)) => spec["headers"] = Json::object(headers)
        _ =>
          match raw.get("headers") {
            Some(Object(headers)) => spec["headers"] = Json::object(headers)
            _ => ()
          }
      }
    }
    _ => ()
  }
  for key in raw.keys() {
    if moon_codex_mcp_core_field(typ, key) {
      continue
    }
    guard raw.get(key) is Some(value) else { continue }
    spec[key] = value
  }
  Json::object(spec)
}

///|
fn moon_codex_mcp_core_field(typ : String, key : String) -> Bool {
  match typ {
    "stdio" =>
      key == "type" ||
      key == "command" ||
      key == "args" ||
      key == "env" ||
      key == "cwd"
    "http" | "sse" =>
      key == "type" || key == "url" || key == "http_headers" || key == "headers"
    _ => key == "type"
  }
}

///|
fn moon_toml_strip_comment(line : String) -> String {
  let mut in_quote = false
  let mut quote = 0
  let mut escaped = false
  for i in 0..<line.length() {
    let ch = line[i]
    if in_quote {
      if escaped {
        escaped = false
      } else if ch == '\\' {
        escaped = true
      } else if ch.to_int() == quote {
        in_quote = false
      }
    } else if ch == '"' || ch == '\'' {
      in_quote = true
      quote = ch.to_int()
    } else if ch == '#' {
      return line[:i].to_owned()
    }
  }
  line
}

///|
fn moon_toml_assignment(line : String) -> (String, String)? {
  guard line.find("=") is Some(index) else { return None }
  let key = line[:index].trim().to_owned()
  let value = line[index + 1:].trim().to_owned()
  if key.is_empty() {
    None
  } else {
    Some((key, value))
  }
}

///|
fn moon_toml_value(raw : String) -> Json? {
  let value = raw.trim().to_owned()
  if value.is_empty() {
    return None
  }
  if value.has_prefix("[") && value.has_suffix("]") {
    let items : Array[Json] = []
    for item in moon_toml_split_csv(value[1:value.length() - 1].to_owned()) {
      match moon_toml_value(item) {
        Some(String(text)) => items.push(Json::string(text))
        Some(true) => items.push(Json::boolean(true))
        Some(false) => items.push(Json::boolean(false))
        Some(Number(number, ..)) => items.push(Json::number(number))
        _ => ()
      }
    }
    return Some(Json::array(items))
  }
  if value.has_prefix("{") && value.has_suffix("}") {
    let obj : Map[String, Json] = {}
    for item in moon_toml_split_csv(value[1:value.length() - 1].to_owned()) {
      match moon_toml_assignment(item) {
        Some((key, nested_raw)) =>
          match moon_toml_value(nested_raw) {
            Some(String(text)) => obj[key] = Json::string(text)
            _ => ()
          }
        None => ()
      }
    }
    return Some(Json::object(obj))
  }
  if (value.has_prefix("\"") && value.has_suffix("\"")) ||
    (value.has_prefix("'") && value.has_suffix("'")) {
    return Some(Json::string(value[1:value.length() - 1].to_owned()))
  }
  match value {
    "true" => Some(Json::boolean(true))
    "false" => Some(Json::boolean(false))
    _ =>
      try @string.parse_int(value, base=10) catch {
        _ => Some(Json::string(value))
      } noraise {
        parsed => Some(Json::number(parsed.to_double()))
      }
  }
}

///|
fn moon_toml_split_csv(text : String) -> Array[String] {
  let parts : Array[String] = []
  let mut start = 0
  let mut in_quote = false
  let mut quote = 0
  let mut escaped = false
  for i in 0..<text.length() {
    let ch = text[i]
    if in_quote {
      if escaped {
        escaped = false
      } else if ch == '\\' {
        escaped = true
      } else if ch.to_int() == quote {
        in_quote = false
      }
    } else if ch == '"' || ch == '\'' {
      in_quote = true
      quote = ch.to_int()
    } else if ch == ',' {
      let item = text[start:i].trim().to_owned()
      if !item.is_empty() {
        parts.push(item)
      }
      start = i + 1
    }
  }
  let tail = text[start:].trim().to_owned()
  if !tail.is_empty() {
    parts.push(tail)
  }
  parts
}

///|
fn moon_clean_blank_lines(lines : Array[String]) -> String {
  let cleaned : Array[String] = []
  let mut blank_run = 0
  for line in lines {
    if line.trim().is_empty() {
      blank_run += 1
      if blank_run <= 1 {
        cleaned.push("")
      }
    } else {
      blank_run = 0
      cleaned.push(line)
    }
  }
  cleaned.join("\n")
}

///|
async fn moon_import_mcp_from_apps_count(servers : Map[String, Json]) -> Int {
  let mut total = 0
  total += moon_import_mcp_from_file(
    servers,
    "claude",
    @pathx.join(moon_home_dir(), ".claude.json"),
  )
  total += moon_import_mcp_from_codex_file(
    servers,
    moon_config_file_path("codex"),
  )
  total += moon_import_mcp_from_file(
    servers,
    "gemini",
    @pathx.join(moon_config_dir("gemini"), "settings.json"),
  )
  total
}

///|
fn moon_validate_mcp_command_name(command : String) -> Bool {
  let trimmed = command.trim()
  !trimmed.is_empty() &&
  !trimmed.contains("/") &&
  !trimmed.contains("\\") &&
  !trimmed.contains("\u{0000}")
}

///|
fn moon_prompt_store_key(app : String, id : String) -> String {
  "\{moon_normalize_app_type(app)}:\{id}"
}

///|
fn moon_prompt_from_request(
  path : StringView,
  body : Json?,
) -> (String, String, Json)? {
  let app = moon_config_app_from_request(path, body).unwrap_or("claude")
  match moon_json_request(path, body, ["prompt"]) {
    Some(Object(prompt)) =>
      match json_string_from_map_any(prompt, ["id"]) {
        Some(id) =>
          return Some(
            (app, id, moon_normalize_prompt(id, Json::object(prompt))),
          )
        None => ()
      }
    _ => ()
  }
  guard proxy_string_request(path, body, ["id", "promptId", "prompt_id"])
    is Some(id) else {
    return None
  }
  let name = proxy_string_request(path, body, ["name"]).unwrap_or(id)
  let content = proxy_string_request(path, body, ["content"]).unwrap_or("")
  let description = proxy_string_request(path, body, ["description"])
  let enabled = proxy_bool_request(path, body, ["enabled"]).unwrap_or(true)
  let now = Json::string(@async.now().to_string())
  let prompt : Map[String, Json] = {
    "id": Json::string(id),
    "name": Json::string(name),
    "content": Json::string(content),
    "enabled": Json::boolean(enabled),
    "createdAt": now,
    "updatedAt": now,
  }
  match description {
    Some(value) => prompt["description"] = Json::string(value)
    None => ()
  }
  Some((app, id, Json::object(prompt)))
}

///|
async fn moon_enable_prompt_json(
  prompts : Map[String, Json],
  app : String,
  id : String,
  file_path : String,
) -> Result[Json, String] {
  let normalized = moon_normalize_app_type(app)
  let prefix = "\{normalized}:"
  let mut selected_content = ""
  let mut found = false
  for key in prompts.keys() {
    if !key.has_prefix(prefix) {
      continue
    }
    guard prompts.get(key) is Some(Object(prompt)) else { continue }
    guard json_string_from_map_any(prompt, ["id"]) is Some(prompt_id) else {
      continue
    }
    if prompt_id == id {
      selected_content = json_string_from_map_any(prompt, ["content"]).unwrap_or(
        "",
      )
      found = true
      break
    }
  }
  if !found {
    return Err("提示词 \{id} 不存在")
  }
  @fsx.make_directory(@pathx.dirname(file_path), recursive=true, exists_ok=true) catch {
    error => return Err("创建提示词目录失败: \{error}")
  }
  @fsx.write_to_file(file_path, selected_content) catch {
    error => return Err("写入提示词文件失败: \{error}")
  }
  let now = Json::string(@async.now().to_string())
  for key in prompts.keys() {
    if !key.has_prefix(prefix) {
      continue
    }
    guard prompts.get(key) is Some(Object(prompt)) else { continue }
    let next = prompt
    let enabled = match json_string_from_map_any(next, ["id"]) {
      Some(prompt_id) => prompt_id == id
      None => false
    }
    next["enabled"] = Json::boolean(enabled)
    if enabled {
      next["updatedAt"] = now
    }
    prompts[key] = Json::object(next)
  }
  Ok(Json::null())
}

///|
fn moon_normalize_prompt(id : String, prompt : Json) -> Json {
  match prompt {
    Object(obj) => {
      let next = obj
      if next.get("id") is None {
        next["id"] = Json::string(id)
      }
      if next.get("name") is None {
        next["name"] = Json::string(id)
      }
      if next.get("content") is None {
        next["content"] = Json::string("")
      }
      if next.get("enabled") is None {
        next["enabled"] = Json::boolean(true)
      }
      let now = Json::string(@async.now().to_string())
      if next.get("createdAt") is None {
        next["createdAt"] = now
      }
      next["updatedAt"] = now
      Json::object(next)
    }
    _ => Json::object({})
  }
}

///|
fn moon_prompts_object_for_app(
  prompts : Map[String, Json],
  app : String,
) -> Json {
  let normalized = moon_normalize_app_type(app)
  let prefix = "\{normalized}:"
  let result : Map[String, Json] = {}
  for key in prompts.keys() {
    if key.has_prefix(prefix) {
      guard prompts.get(key) is Some(Object(prompt)) else { continue }
      match json_string_from_map_any(prompt, ["id"]) {
        Some(id) => result[id] = Json::object(prompt)
        None => ()
      }
    }
  }
  Json::object(result)
}
