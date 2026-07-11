///|
fn moon_config_app_from_request(path : StringView, body : Json?) -> String? {
  match proxy_string_request(path, body, "appType") {
    Some(app) => Some(moon_normalize_app_type(app))
    None => None
  }
}

///|
fn moon_config_dir(app : String) -> String {
  let home = moon_home_dir()
  match moon_normalize_app_type(app) {
    "claude" => @pathx.join(home, ".claude")
    "claude-desktop" =>
      @pathx.join(@pathx.join(home, "Library/Application Support"), "Claude")
    "codex" => @pathx.join(home, ".codex")
    "gemini" => @pathx.join(home, ".gemini")
    "opencode" => @pathx.join(@pathx.join(home, ".config"), "opencode")
    "openclaw" => @pathx.join(home, ".openclaw")
    "hermes" => @pathx.join(home, ".hermes")
    "omo" | "omo-slim" => @pathx.join(@pathx.join(home, ".config"), "opencode")
    _ => @pathx.join(home, ".claude")
  }
}

///|
fn moon_config_file_path(app : String) -> String {
  let dir = moon_config_dir(app)
  match moon_normalize_app_type(app) {
    "claude" => @pathx.join(dir, "settings.json")
    "claude-desktop" => @pathx.join(dir, "claude_desktop_config.json")
    "codex" => @pathx.join(dir, "config.toml")
    "gemini" => @pathx.join(dir, ".env")
    "opencode" | "omo" | "omo-slim" => @pathx.join(dir, "opencode.json")
    "openclaw" => @pathx.join(dir, "openclaw.json")
    "hermes" => @pathx.join(dir, "config.yaml")
    _ => @pathx.join(dir, "settings.json")
  }
}

///|
fn moon_app_config_dir() -> String {
  moon_app_config_dir_for_workspace_root(moongate_active_workspace_root())
}

///|
fn moon_app_config_dir_for_workspace_root(root : String) -> String {
  moongate_product_home_for_workspace_root(root)
}

///|
fn moon_app_config_path() -> String {
  @pathx.join(moon_app_config_dir(), "config.json")
}

///|
fn moon_default_app_settings_json() -> Json {
  {
    "showInTray": Json::boolean(true),
    "minimizeToTrayOnClose": Json::boolean(true),
    "useAppWindowControls": Json::boolean(false),
    "enableClaudePluginIntegration": Json::boolean(false),
    "skipClaudeOnboarding": Json::boolean(false),
    "launchOnStartup": Json::boolean(false),
    "silentStartup": Json::boolean(false),
    "enableLocalProxy": Json::boolean(false),
    "enableFailoverToggle": Json::boolean(false),
    "usageDashboardRefreshIntervalMs": Json::number(30000),
    "preserveCodexOfficialAuthOnSwitch": Json::boolean(false),
    "skillSyncMethod": Json::string("auto"),
    "skillStorageLocation": Json::string("unified"),
  }.to_json()
}

///|
fn moon_default_rectifier_config_json() -> Json {
  {
    "enabled": Json::boolean(true),
    "requestThinkingSignature": Json::boolean(true),
    "requestThinkingBudget": Json::boolean(true),
    "requestMediaFallback": Json::boolean(true),
    "requestMediaHeuristic": Json::boolean(true),
  }.to_json()
}

///|
fn moon_default_optimizer_config_json() -> Json {
  {
    "enabled": Json::boolean(false),
    "thinkingOptimizer": Json::boolean(true),
    "cacheInjection": Json::boolean(true),
    "cacheTtl": Json::string("1h"),
  }.to_json()
}

///|
fn moon_default_log_config_json() -> Json {
  { "enabled": Json::boolean(true), "level": Json::string("info") }.to_json()
}

///|
fn moon_claude_plugin_config_path() -> String {
  @pathx.join(moon_config_dir("claude"), "config.json")
}

///|
fn moon_search_snippet(content : String, first_pos : Int) -> String {
  let start = if first_pos > 50 { first_pos - 50 } else { 0 }
  let end = if first_pos + 70 < content.length() {
    first_pos + 70
  } else {
    content.length()
  }
  let prefix = if start > 0 { "..." } else { "" }
  let suffix = if end < content.length() { "..." } else { "" }
  "\{prefix}\{content[start:end]}\{suffix}"
}

///|
fn moon_merge_settings_for_save(incoming : Json, existing : Json) -> Json {
  guard incoming is Object(incoming_obj) else { return existing }
  guard existing is Object(existing_obj) else { return incoming }
  let next = incoming_obj
  for key, value in existing_obj {
    if next.get(key) is None {
      next[key] = value
    }
  }
  moon_preserve_missing_settings_object(next, existing_obj, "webdavSync")
  moon_preserve_missing_settings_object(next, existing_obj, "s3Sync")
  moon_preserve_missing_settings_object(next, existing_obj, "localMigrations")
  moon_preserve_missing_settings_object(next, existing_obj, "local_migrations")
  moon_preserve_secret_if_empty(next, existing_obj, "webdavSync", "password")
  moon_preserve_secret_if_empty(next, existing_obj, "s3Sync", "secretAccessKey")
  Json::object(next)
}

///|
fn moon_settings_with_defaults(settings : Json) -> Json {
  guard moon_default_app_settings_json() is Object(defaults) else {
    return settings
  }
  guard settings is Object(saved) else { return Json::object(defaults) }
  for key, value in saved {
    defaults[key] = value
  }
  Json::object(defaults)
}

///|
fn moon_preserve_missing_settings_object(
  incoming : Map[String, Json],
  existing : Map[String, Json],
  key : String,
) -> Unit {
  if incoming.get(key) is None {
    match existing.get(key) {
      Some(value) => incoming[key] = value
      None => ()
    }
  }
}

///|
fn moon_settings_with_bool(settings : Json, key : String, value : Bool) -> Json {
  match settings {
    Object(obj) => {
      obj[key] = Json::boolean(value)
      Json::object(obj)
    }
    _ => {
      let obj : Map[String, Json] = {}
      obj[key] = Json::boolean(value)
      Json::object(obj)
    }
  }
}

///|
fn moon_json_config_from_request(
  path : StringView,
  body : Json?,
  current : Json,
  setters : Array[(String, String, String)],
) -> Json {
  let source = body
  let base = match current {
    Object(_) => moon_json_deep_copy(current)
    _ =>
      match source {
        Some(Object(_)) => Json::object({})
        Some(json) => json
        None => current
      }
  }
  match base {
    Object(obj) => {
      for setter in setters {
        let (field, keys, kind) = setter
        match kind {
          "bool" =>
            match proxy_bool_request(path, source, keys) {
              Some(value) => obj[field] = Json::boolean(value)
              None => ()
            }
          "string" =>
            match proxy_string_request(path, source, keys) {
              Some(value) => obj[field] = Json::string(value)
              None => ()
            }
          _ => ()
        }
      }
      Json::object(obj)
    }
    _ => base
  }
}

///|
fn moon_rectifier_config_from_request(
  path : StringView,
  body : Json?,
  current : Json,
) -> Json {
  moon_json_config_from_request(path, body, current, [
    ("enabled", "enabled", "bool"),
    ("requestThinkingSignature", "requestThinkingSignature", "bool"),
    ("requestThinkingBudget", "requestThinkingBudget", "bool"),
    ("requestMediaFallback", "requestMediaFallback", "bool"),
    ("requestMediaHeuristic", "requestMediaHeuristic", "bool"),
  ])
}

///|
fn moon_optimizer_config_from_request(
  path : StringView,
  body : Json?,
  current : Json,
) -> Json {
  moon_json_config_from_request(path, body, current, [
    ("enabled", "enabled", "bool"),
    ("thinkingOptimizer", "thinkingOptimizer", "bool"),
    ("cacheInjection", "cacheInjection", "bool"),
    ("cacheTtl", "cacheTtl", "string"),
  ])
}

///|
fn moon_log_config_from_request(
  path : StringView,
  body : Json?,
  current : Json,
) -> Json {
  moon_json_config_from_request(path, body, current, [
    ("enabled", "enabled", "bool"),
    ("level", "level", "string"),
  ])
}

///|
fn moon_optimizer_cache_ttl_valid(config : Json) -> Bool {
  guard config is Object(obj) else { return true }
  match json_string_from_map(obj, "cacheTtl") {
    Some("5m") | Some("1h") | None => true
    _ => false
  }
}

///|
fn moon_json_deep_copy(json : Json) -> Json {
  match json {
    Object(obj) => {
      let copy : Map[String, Json] = Map([], capacity=obj.length())
      for key, value in obj {
        copy[key] = moon_json_deep_copy(value)
      }
      Json::object(copy)
    }
    Array(items) => {
      let copy : Array[Json] = []
      for item in items {
        copy.push(moon_json_deep_copy(item))
      }
      Json::array(copy)
    }
    _ => json
  }
}

///|
fn ConfigService::settings_json(self : ConfigService) -> Json {
  self.app_settings
}

///|
fn ConfigService::save_settings_json(
  self : ConfigService,
  settings : Json,
) -> Unit {
  self.app_settings = moon_merge_settings_for_save(settings, self.app_settings)
  match self.app_settings {
    Object(obj) => {
      match proxy_json_bool(obj, "launchOnStartup") {
        Some(enabled) => self.auto_launch_enabled = enabled
        None => ()
      }
      match proxy_json_bool(obj, "skipClaudeOnboarding") {
        Some(skipped) => self.claude_onboarding_skipped = skipped
        None => ()
      }
    }
    _ => ()
  }
}

///|
async fn ConfigService::load_settings_store(
  self : ConfigService,
  path? : String = moon_app_config_path(),
) -> Unit {
  if !@fsx.exists_as_file(path) {
    return
  }
  let parsed = @json.parse(@fsx.read_file(path))
  guard parsed is Object(_) else { return }
  self.save_settings_json(moon_settings_with_defaults(parsed))
}

///|
async fn ConfigService::save_settings_store(
  self : ConfigService,
  settings : Json,
  path? : String = moon_app_config_path(),
) -> Unit raise Error {
  let next = moon_merge_settings_for_save(settings, self.app_settings)
  let parent = @pathx.dirname(path)
  if !parent.is_empty() && parent != "." {
    @fsx.make_directory(parent, recursive=true, exists_ok=true)
  }
  atomic_write_store_file(path, next.stringify(indent=2) + "\n")
  self.save_settings_json(next)
}

///|
fn ConfigService::app_config_dir_override_json(self : ConfigService) -> Json {
  match self.app_config_dir_override {
    Some(path) => Json::string(path)
    None => Json::null()
  }
}

///|
fn ConfigService::set_app_config_dir_override_from_request(
  self : ConfigService,
  path : StringView,
  body : Json?,
) -> Unit {
  self.app_config_dir_override = moon_optional_path_from_request(path, body)
}

///|
fn ConfigService::rectifier_json(self : ConfigService) -> Json {
  self.rectifier_config_json
}

///|
fn ConfigService::set_rectifier_from_request(
  self : ConfigService,
  path : StringView,
  body : Json?,
) -> Unit {
  self.rectifier_config_json = moon_rectifier_config_from_request(
    path,
    body,
    self.rectifier_config_json,
  )
}

///|
fn ConfigService::optimizer_json(self : ConfigService) -> Json {
  self.optimizer_config_json
}

///|
fn ConfigService::set_optimizer_from_request(
  self : ConfigService,
  path : StringView,
  body : Json?,
) -> Bool {
  let current = moon_json_deep_copy(self.optimizer_config_json)
  let config = moon_optimizer_config_from_request(path, body, current)
  if !moon_optimizer_cache_ttl_valid(config) {
    return false
  }
  self.optimizer_config_json = config
  true
}

///|
fn ConfigService::log_json(self : ConfigService) -> Json {
  self.log_config_json
}

///|
fn ConfigService::set_log_from_request(
  self : ConfigService,
  path : StringView,
  body : Json?,
) -> Unit {
  self.log_config_json = moon_log_config_from_request(
    path,
    body,
    self.log_config_json,
  )
}

///|
async fn moon_config_status_json(app : String) -> Json {
  let normalized = moon_normalize_app_type(app)
  let path = match normalized {
    "codex" => moon_config_dir(normalized)
    "gemini" | "opencode" | "openclaw" | "hermes" | "claude-desktop" =>
      moon_config_dir(normalized)
    _ => moon_config_file_path(normalized)
  }
  {
    "exists": Json::boolean(moon_config_exists(normalized)),
    "path": Json::string(path),
  }.to_json()
}

///|
async fn moon_config_exists(app : String) -> Bool {
  let normalized = moon_normalize_app_type(app)
  match normalized {
    "codex" =>
      @fsx.exists_as_file(@pathx.join(moon_config_dir("codex"), "auth.json")) ||
      @fsx.exists_as_file(moon_config_file_path("codex"))
    "gemini"
    | "opencode"
    | "openclaw"
    | "hermes"
    | "claude"
    | "claude-desktop" => @fsx.exists_as_file(moon_config_file_path(normalized))
    _ => @fsx.exists_as_file(moon_config_file_path(normalized))
  }
}

///|
fn moon_env_shell_config_paths() -> Array[String] {
  let home = moon_home_dir()
  [
    @pathx.join(home, ".bashrc"),
    @pathx.join(home, ".bash_profile"),
    @pathx.join(home, ".zshrc"),
    @pathx.join(home, ".zprofile"),
    @pathx.join(home, ".profile"),
    "/etc/profile",
    "/etc/bashrc",
  ]
}

///|
fn moon_env_backup_json(body : Json?) -> Json {
  let conflicts = moon_env_conflicts_from_body(body)
  let timestamp = @async.now().to_int().to_string()
  {
    "backupPath": Json::string(
      @pathx.join(
        @pathx.join(moon_app_config_dir(), "backups"),
        "env-backup-\{timestamp}.json",
      ),
    ),
    "timestamp": Json::string(timestamp),
    "conflicts": Json::array(conflicts),
  }.to_json()
}

///|
async fn moon_restore_env_backup_json(
  backup_path : String?,
) -> Result[Json, String] {
  guard backup_path is Some(path) else { return Err("missing_backup_path") }
  let content = @fsx.read_file(path) catch {
    error => return Err("读取备份文件失败: \{error}")
  }
  let parsed = @json.parse(content) catch {
    error => return Err("解析备份文件失败: \{error}")
  }
  for conflict in moon_env_conflicts_from_body(Some(parsed)) {
    match moon_restore_single_env_conflict(conflict) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  Ok(Json::null())
}

///|
fn moon_mcp_config_text(servers : Map[String, Json]) -> String? {
  if servers.is_empty() {
    return None
  }
  let mcp_servers : Map[String, Json] = {}
  for id in servers.keys() {
    guard servers.get(id) is Some(Object(server)) else { continue }
    match server.get("server") {
      Some(spec) => mcp_servers[id] = spec
      None => ()
    }
  }
  Some(
    Json::object({ "mcpServers": Json::object(mcp_servers) }).stringify(
      indent=2,
    ),
  )
}

///|
fn moon_validate_common_config_snippet(
  app_type : String,
  snippet : String,
) -> String? {
  if snippet.trim().is_empty() {
    return None
  }
  match app_type {
    "claude" | "gemini" | "omo" | "omo-slim" => {
      ignore(
        @json.parse(snippet) catch {
          err => return Some("Invalid JSON format: \{err}")
        },
      )
      None
    }
    "codex" =>
      if moon_validate_codex_toml_snippet(snippet) {
        None
      } else {
        Some("Invalid TOML format")
      }
    _ => None
  }
}

///|
fn moon_validate_codex_toml_snippet(snippet : String) -> Bool {
  for line_view in snippet.split("\n") {
    let line = moon_toml_strip_comment(line_view.to_owned()).trim().to_owned()
    if line.is_empty() {
      continue
    }
    if line.has_prefix("[") {
      if !line.has_suffix("]") {
        return false
      }
      let section = line[1:line.length() - 1].trim()
      if section.is_empty() {
        return false
      }
      continue
    }
    if line.has_suffix("]") {
      return false
    }
    if moon_toml_assignment(line) is None {
      return false
    }
  }
  true
}

///|
fn moon_extract_common_config_snippet_from_settings_config(
  app_type : String,
  settings_config : String,
) -> Result[String, String] {
  let parsed = @json.parse(settings_config) catch {
    err => return Err("Invalid JSON format: \{err}")
  }
  Ok(moon_extract_common_config_snippet_json(app_type, parsed))
}

///|
fn moon_extract_common_config_snippet_json(
  app_type : String,
  settings : Json,
) -> String {
  match app_type {
    "claude" => moon_extract_claude_common_config(settings)
    "codex" => moon_extract_codex_common_config(settings)
    "gemini" => moon_extract_gemini_common_config(settings)
    "opencode" => moon_extract_opencode_common_config(settings)
    "openclaw" => moon_extract_openclaw_common_config(settings)
    _ => ""
  }
}

///|
fn moon_extract_claude_common_config(settings : Json) -> String {
  guard settings is Object(config) else { return "{}" }
  match config.get("env") {
    Some(Object(env)) => {
      for
        key in [
          "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_MODEL", "ANTHROPIC_REASONING_MODEL",
          "ANTHROPIC_DEFAULT_HAIKU_MODEL", "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME",
          "ANTHROPIC_DEFAULT_OPUS_MODEL", "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME", "ANTHROPIC_DEFAULT_SONNET_MODEL",
          "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME", "ANTHROPIC_BASE_URL",
        ] {
        env.remove(key)
      }
      if env.length() == 0 {
        config.remove("env")
      } else {
        config["env"] = Json::object(env)
      }
    }
    _ => ()
  }
  for key in ["apiBaseUrl", "primaryModel", "smallFastModel"] {
    config.remove(key)
  }
  if config.length() == 0 {
    "{}"
  } else {
    Json::object(config).stringify(indent=2)
  }
}

///|
fn moon_extract_codex_common_config(settings : Json) -> String {
  guard settings is Object(config) else { return "" }
  let toml = json_string_from_map(config, "config").unwrap_or("")
  if toml.is_empty() {
    return ""
  }
  moon_extract_codex_common_config_from_toml(toml)
}

///|
fn moon_extract_codex_common_config_from_toml(toml : String) -> String {
  let lines : Array[String] = []
  let mut skip_model_providers = false
  let mut current_section = ""
  for line_view in toml.split("\n") {
    let original = line_view.to_owned()
    let stripped = moon_toml_strip_comment(original).trim().to_owned()
    if stripped.has_prefix("[") && stripped.has_suffix("]") {
      let section = stripped[1:stripped.length() - 1].trim().to_owned()
      current_section = section
      skip_model_providers = section == "model_providers" ||
        section.has_prefix("model_providers.")
      if skip_model_providers {
        continue
      }
      lines.push(original.trim_end().to_owned())
      continue
    }
    if skip_model_providers {
      continue
    }
    if current_section.is_empty() {
      match moon_toml_assignment(stripped) {
        Some((key, _)) if key == "model" ||
          key == "model_provider" ||
          key == "base_url" => continue
        _ => ()
      }
    }
    lines.push(original.trim_end().to_owned())
  }
  moon_clean_blank_lines(lines).trim().to_owned()
}

///|
fn moon_extract_gemini_common_config(settings : Json) -> String {
  guard settings is Object(config) else { return "{}" }
  let snippet : Map[String, Json] = {}
  match config.get("env") {
    Some(Object(env)) =>
      for key in env.keys() {
        if key == "GOOGLE_GEMINI_BASE_URL" || key == "GEMINI_API_KEY" {
          continue
        }
        match env.get(key) {
          Some(String(value)) if !value.trim().is_empty() =>
            snippet[key] = Json::string(value.trim().to_owned())
          _ => ()
        }
      }
    _ => ()
  }
  if snippet.length() == 0 {
    "{}"
  } else {
    Json::object(snippet).stringify(indent=2)
  }
}

///|
fn moon_extract_opencode_common_config(settings : Json) -> String {
  guard settings is Object(config) else { return "{}" }
  match config.get("options") {
    Some(Object(options)) => {
      options.remove("apiKey")
      options.remove("baseURL")
      config["options"] = Json::object(options)
    }
    _ => ()
  }
  if config.length() == 0 {
    "{}"
  } else {
    Json::object(config).stringify(indent=2)
  }
}

///|
fn moon_extract_openclaw_common_config(settings : Json) -> String {
  guard settings is Object(config) else { return "{}" }
  config.remove("apiKey")
  config.remove("baseUrl")
  if config.length() == 0 {
    "{}"
  } else {
    Json::object(config).stringify(indent=2)
  }
}

///|
async fn ConfigService::handle_get_config_status(
  self : ConfigService,
  w : @httpx.ResponseWriter,
  app : String,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_config_status_json(app))
}

///|
async fn ConfigService::handle_get_config_status_request(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  write_usage_json(w, moon_config_status_json(app))
}

///|
async fn ConfigService::handle_get_claude_code_config_path(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::string(moon_config_file_path("claude")))
}

///|
async fn ConfigService::handle_get_config_dir(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  write_usage_json(w, Json::string(moon_config_dir(app)))
}

///|
async fn ConfigService::handle_open_config_folder(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  match moon_open_directory_result_json(moon_config_dir(app)) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn ConfigService::handle_export_config_to_file(
  self : ConfigService,
  proxy : ProxyService,
  host~ : String,
  port~ : Int,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "filePath") is Some(file_path) else {
    write_usage_bad_request(w, "missing_file_path")
    return
  }
  write_usage_json(
    w,
    self.moon_export_config_to_file_json(proxy, host~, port~, file_path),
  )
}

///|
async fn ConfigService::handle_import_config_from_file(
  self : ConfigService,
  proxy : ProxyService,
  host~ : String,
  port~ : Int,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "filePath") is Some(file_path) else {
    write_usage_bad_request(w, "missing_file_path")
    return
  }
  write_usage_json(
    w,
    self.moon_import_config_from_file_json(proxy, host~, port~, file_path),
  )
}

///|
async fn ConfigService::handle_create_db_backup(
  self : ConfigService,
  proxy : ProxyService,
  host~ : String,
  port~ : Int,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.moon_create_db_backup_json(proxy, host~, port~))
}

///|
async fn ConfigService::handle_list_db_backups(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_list_db_backups_json())
}

///|
async fn ConfigService::handle_restore_db_backup(
  self : ConfigService,
  proxy : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "filename") is Some(filename) else {
    write_usage_bad_request(w, "missing_filename")
    return
  }
  match self.moon_restore_db_backup_json(proxy, filename) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn ConfigService::handle_rename_db_backup(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "oldFilename") is Some(old_filename) else {
    write_usage_bad_request(w, "missing_old_filename")
    return
  }
  guard proxy_string_request(r.path, body, "newName") is Some(new_name) else {
    write_usage_bad_request(w, "missing_new_name")
    return
  }
  match moon_rename_db_backup_json(old_filename, new_name) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn ConfigService::handle_delete_db_backup(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "filename") is Some(filename) else {
    write_usage_bad_request(w, "missing_filename")
    return
  }
  match moon_delete_db_backup_json(filename) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn ConfigService::handle_merge_deeplink_config(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard moon_deeplink_request_payload(r.path, body) is Some(request) else {
    write_usage_bad_request(w, "invalid_deeplink")
    return
  }
  match moon_merge_deeplink_config_json(request) {
    Some(merged) => write_usage_json(w, merged)
    None => write_usage_bad_request(w, "invalid_deeplink_config")
  }
}

///|
async fn ConfigService::handle_webdav_sync_save_settings(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard moon_sync_settings_request(r.path, body) is Some(settings) else {
    write_usage_bad_request(w, "missing_settings")
    return
  }
  let normalized = moon_webdav_sync_settings_json(
    settings,
    moon_app_webdav_sync_json(self.app_settings),
    !moon_sync_password_touched_request(r.path, body),
  )
  match moon_validate_webdav_sync_settings(normalized) {
    Some(error) => write_usage_bad_request(w, error)
    None => {
      self.app_settings = moon_app_settings_with_sync(
        self.app_settings,
        "webdavSync",
        normalized,
      )
      write_usage_json(w, { "success": Json::boolean(true) }.to_json())
    }
  }
}

///|
async fn ConfigService::handle_s3_sync_save_settings(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard moon_sync_settings_request(r.path, body) is Some(settings) else {
    write_usage_bad_request(w, "missing_settings")
    return
  }
  let normalized = moon_s3_sync_settings_json(
    settings,
    moon_app_s3_sync_json(self.app_settings),
    !moon_sync_password_touched_request(r.path, body),
  )
  match moon_validate_s3_sync_settings(normalized) {
    Some(error) => write_usage_bad_request(w, error)
    None => {
      self.app_settings = moon_app_settings_with_sync(
        self.app_settings,
        "s3Sync",
        normalized,
      )
      write_usage_json(w, { "success": Json::boolean(true) }.to_json())
    }
  }
}

///|
async fn ConfigService::handle_get_app_config_path(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::string(moon_app_config_path()))
}

///|
async fn ConfigService::handle_open_app_config_folder(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  match moon_open_directory_result_json(moon_app_config_dir()) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn ConfigService::handle_get_settings(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.settings_json())
}

///|
async fn ConfigService::handle_save_settings(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  match proxy_json_body(r) {
    Some(settings) => {
      self.save_settings_store(settings) catch {
        error => {
          moongate_write_json_error(
            w,
            @status.InternalServerError,
            "moongate_settings_write_failed",
            "Failed to persist MoonGate settings: \{error}",
          )
          return
        }
      }
      write_usage_json(w, Json::boolean(true))
    }
    None => write_usage_bad_request(w, "invalid_settings")
  }
}

///|
async fn ConfigService::handle_get_app_config_dir_override(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.app_config_dir_override_json())
}

///|
async fn ConfigService::handle_set_app_config_dir_override(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  self.set_app_config_dir_override_from_request(r.path, body)
  write_usage_json(w, Json::boolean(true))
}

///|
async fn ConfigService::handle_get_rectifier_config(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.rectifier_json())
}

///|
async fn ConfigService::handle_set_rectifier_config(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  self.set_rectifier_from_request(r.path, body)
  write_usage_json(w, Json::boolean(true))
}

///|
async fn ConfigService::handle_get_optimizer_config(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.optimizer_json())
}

///|
async fn ConfigService::handle_set_optimizer_config(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  if !self.set_optimizer_from_request(r.path, body) {
    write_usage_bad_request(w, "invalid_optimizer_cache_ttl")
    return
  }
  write_usage_json(w, Json::boolean(true))
}

///|
async fn ConfigService::handle_get_log_config(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.log_json())
}

///|
async fn ConfigService::handle_set_log_config(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  self.set_log_from_request(r.path, body)
  write_usage_json(w, Json::boolean(true))
}

///|
async fn ConfigService::handle_get_common_config_snippet(
  self : ConfigService,
  w : @httpx.ResponseWriter,
  app_type : String,
) -> Unit {
  match self.config_snippets.get(app_type) {
    Some(snippet) => write_usage_json(w, Json::string(snippet))
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn ConfigService::handle_get_common_config_snippet_request(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app_type = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  self.handle_get_common_config_snippet(w, app_type)
}

///|
async fn ConfigService::handle_set_common_config_snippet(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  app_type : String,
) -> Unit {
  let body = proxy_json_body(r)
  let snippet = proxy_string_request(r.path, body, "snippet").unwrap_or("")
  match moon_validate_common_config_snippet(app_type, snippet) {
    Some(error) => {
      write_usage_bad_request(w, error)
      return
    }
    None => ()
  }
  if snippet.trim().is_empty() {
    self.config_snippets.remove(app_type)
  } else {
    self.config_snippets[app_type] = snippet
  }
  write_usage_json(w, Json::null())
}

///|
async fn ConfigService::handle_set_common_config_snippet_request(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app_type = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  self.handle_set_common_config_snippet(r, w, app_type)
}

///|
async fn ConfigService::handle_extract_common_config_snippet(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app_type = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  match proxy_string_request(r.path, body, "settingsConfig") {
    Some(settings_config) =>
      match
        moon_extract_common_config_snippet_from_settings_config(
          app_type, settings_config,
        ) {
        Ok(snippet) => write_usage_json(w, Json::string(snippet))
        Err(error) => write_usage_bad_request(w, error)
      }
    None =>
      match self.config_snippets.get(app_type) {
        Some(snippet) => write_usage_json(w, Json::string(snippet))
        None => write_usage_json(w, Json::string(""))
      }
  }
}

///|
async fn ConfigService::handle_restore_env_backup(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let backup_path = proxy_string_request(r.path, body, "backupPath")
  match moon_restore_env_backup_json(backup_path) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn ConfigService::handle_read_claude_mcp_config(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  match moon_mcp_config_text(self.mcp_servers) {
    Some(content) => write_usage_json(w, Json::string(content))
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn ConfigService::handle_get_mcp_config(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  write_usage_json(
    w,
    {
      "configPath": Json::string(moon_app_config_path()),
      "servers": moon_mcp_servers_object_for_app(self.mcp_servers, Some(app)),
    }.to_json(),
  )
}

///|
async fn ConfigService::handle_upsert_mcp_server_in_config(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  match moon_mcp_server_from_request(r.path, body, app) {
    Some((id, server)) => {
      let sync_other = proxy_bool_request(r.path, body, "syncOtherSide").unwrap_or(
        false,
      )
      let next = if sync_other {
        let synced = moon_mcp_server_with_app(server, "claude", true)
        let synced = moon_mcp_server_with_app(synced, "codex", true)
        let synced = moon_mcp_server_with_app(synced, "gemini", true)
        let synced = moon_mcp_server_with_app(synced, "opencode", true)
        moon_mcp_server_with_app(synced, "hermes", true)
      } else {
        moon_mcp_server_with_app(server, app, true)
      }
      self.mcp_servers[id] = next
      write_usage_json(w, Json::boolean(true))
    }
    None => write_usage_json(w, Json::boolean(false))
  }
}

///|
async fn ProxyService::handle_import_default_config(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  match moon_import_default_config_json(self.provider_router, app_type) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn ConfigService::handle_read_claude_plugin_config(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.claude_plugin_config {
    Some(content) => write_usage_json(w, Json::string(content))
    None =>
      if @fsx.exists_as_file(moon_claude_plugin_config_path()) {
        let content = @fsx.read_file(moon_claude_plugin_config_path()) catch {
          _ => {
            write_usage_json(w, Json::null())
            return
          }
        }
        write_usage_json(w, Json::string(content))
      } else {
        write_usage_json(w, Json::null())
      }
  }
}

///|
async fn ConfigService::handle_apply_claude_plugin_config(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let official = proxy_bool_request(r.path, body, "official").unwrap_or(false)
  if official {
    self.claude_plugin_applied = false
    self.claude_plugin_config = None
  } else {
    self.claude_plugin_applied = true
    self.claude_plugin_config = Some("{\n  \"primaryApiKey\": \"any\"\n}\n")
  }
  write_usage_json(w, Json::boolean(true))
}

///|
async fn OpenClawService::handle_scan_openclaw_config_health(
  self : OpenClawService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.openclaw_config_health_json())
}

///|
async fn OpenClawService::handle_get_hermes_model_config(
  self : OpenClawService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.hermes_model_config.unwrap_or(Json::null()))
}

///|
fn stream_check_config_from_request(
  path : StringView,
  body : String,
  current : StreamCheckConfig,
) -> StreamCheckConfig? {
  let mut config = current
  let parsed_body : Json? = if body.trim().is_empty() {
    None
  } else {
    let parsed = @json.parse(body) catch { _ => return None }
    Some(parsed)
  }
  let obj = match parsed_body {
    Some(Object(root)) => Some(root)
    Some(_) => return None
    None => None
  }
  if !stream_check_config_request_has_fields(path, obj) {
    return None
  }
  match stream_check_int_request(path, obj, "timeoutSecs") {
    Some(value) if value > 0 => config = { ..config, timeout_secs: value }
    Some(_) => return None
    None => ()
  }
  match stream_check_int_request(path, obj, "maxRetries") {
    Some(value) if value >= 0 => config = { ..config, max_retries: value }
    Some(_) => return None
    None => ()
  }
  match stream_check_int_request(path, obj, "degradedThresholdMs") {
    Some(value) if value > 0 =>
      config = { ..config, degraded_threshold_ms: value }
    Some(_) => return None
    None => ()
  }
  match stream_check_string_request(path, obj, "claudeModel") {
    Some(value) if !value.trim().is_empty() =>
      config = { ..config, claude_model: value.trim().to_owned() }
    Some(_) => return None
    None => ()
  }
  match stream_check_string_request(path, obj, "codexModel") {
    Some(value) if !value.trim().is_empty() =>
      config = { ..config, codex_model: value.trim().to_owned() }
    Some(_) => return None
    None => ()
  }
  match stream_check_string_request(path, obj, "geminiModel") {
    Some(value) if !value.trim().is_empty() =>
      config = { ..config, gemini_model: value.trim().to_owned() }
    Some(_) => return None
    None => ()
  }
  match stream_check_string_request(path, obj, "testPrompt") {
    Some(value) if !value.trim().is_empty() =>
      config = { ..config, test_prompt: value.trim().to_owned() }
    Some(_) => return None
    None => ()
  }
  Some(config)
}

///|
fn stream_check_config_request_has_fields(
  path : StringView,
  obj : Map[String, Json]?,
) -> Bool {
  for
    key in [
      "timeoutSecs", "maxRetries", "degradedThresholdMs", "claudeModel", "codexModel",
      "geminiModel", "testPrompt",
    ] {
    if usage_query_value(path, key) is Some(_) {
      return true
    }
    match obj {
      Some(obj) if obj.get(key) is Some(_) => return true
      _ => ()
    }
  }
  false
}

///|
async fn ConfigService::handle_get_stream_check_config(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.stream_check_config.to_json())
}

///|
async fn ConfigService::handle_save_stream_check_config(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = r.body.read_all().text()
  match
    stream_check_config_from_request(r.path, body, self.stream_check_config) {
    Some(config) => {
      self.stream_check_config = config
      write_usage_json(w, Json::null())
    }
    None => write_usage_bad_request(w, "invalid_stream_check_config")
  }
}

///|
fn OpenClawService::openclaw_config_health_json(self : OpenClawService) -> Json {
  let defaults = self.openclaw_agents_defaults.unwrap_or(Json::object({}))
  let config = {
    "tools": self.openclaw_tools,
    "agents": { "defaults": defaults }.to_json(),
    "env": self.openclaw_env,
  }.to_json()
  openclaw_config_health_from_json(config)
}

///|
fn openclaw_config_health_from_json(config : Json) -> Json {
  let warnings : Array[Json] = []
  match openclaw_nested_json(config, ["tools", "profile"]) {
    Some(String(profile)) =>
      if !openclaw_tools_profile_is_supported(profile) {
        warnings.push(
          openclaw_health_warning_json(
            "invalid_tools_profile",
            "tools.profile uses unsupported value '\{profile}'.",
            Some("tools.profile"),
          ),
        )
      }
    _ => ()
  }
  match openclaw_nested_json(config, ["env", "vars"]) {
    Some(Object(_)) | None => ()
    Some(_) =>
      warnings.push(
        openclaw_health_warning_json(
          "stringified_env_vars",
          "env.vars should be an object. The current value looks stringified or malformed.",
          Some("env.vars"),
        ),
      )
  }
  match openclaw_nested_json(config, ["env", "shellEnv"]) {
    Some(Object(_)) | None => ()
    Some(_) =>
      warnings.push(
        openclaw_health_warning_json(
          "stringified_env_shell_env",
          "env.shellEnv should be an object. The current value looks stringified or malformed.",
          Some("env.shellEnv"),
        ),
      )
  }
  Json::array(warnings)
}

///|
async fn ConfigService::handle_fetch_models_for_config(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "baseUrl") is Some(base_url) else {
    write_usage_bad_request(w, "missing_base_url")
    return
  }
  guard proxy_string_request(r.path, body, "apiKey") is Some(api_key) else {
    write_usage_bad_request(w, "missing_api_key")
    return
  }
  let is_full_url = proxy_bool_request(r.path, body, "isFullUrl").unwrap_or(
    false,
  )
  let models_url = proxy_string_request(r.path, body, "modelsUrl")
  let user_agent = proxy_string_request(r.path, body, "customUserAgent")
  match fetch_models(base_url, api_key, is_full_url, models_url, user_agent) {
    Ok(models) => write_usage_json(w, fetched_models_to_json(models))
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
fn body_snippet(body : String, max_chars : Int) -> String {
  let mut snippet = ""
  let limit = if body.length() < max_chars { body.length() } else { max_chars }
  for i in 0..<limit {
    let ch = body[i]
    if ch == '\n' {
      snippet += "\\n"
    } else if ch == '\r' {
      ()
    } else if ch.to_int() < 32 {
      snippet += "\u{FFFD}"
    } else {
      snippet += body[i:i + 1].to_owned()
    }
  }
  if body.length() > max_chars {
    snippet += "\u{2026}"
  }
  snippet
}

///|
fn rectifier_media_heuristic_enabled(provider : ProviderRouteTarget?) -> Bool {
  let config = moongate_rectifier_config_from_env()
  config.enabled &&
  config.request_media_heuristic &&
  provider_media_heuristic_enabled(provider)
}
