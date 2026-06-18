///|
const MOONSTAT_DB_BACKUP_DIR = "backups"

///|
fn moon_suite_app_types() -> Array[String] {
  [
    "claude", "claude-desktop", "codex", "gemini", "opencode", "openclaw", "hermes",
  ]
}

///|
fn moon_db_backup_dir() -> String {
  @pathx.join(moon_app_config_dir(), MOONSTAT_DB_BACKUP_DIR)
}

///|
fn moon_db_backup_path(filename : String) -> String {
  @pathx.join(moon_db_backup_dir(), moon_backup_filename(filename))
}

///|
fn moon_backup_filename(filename : String) -> String {
  let sanitized = filename
    .replace(old="/", new="-")
    .replace(old="\\", new="-")
    .replace(old=":", new="-")
  if sanitized.has_suffix(".db") || sanitized.has_suffix(".json") {
    sanitized
  } else {
    sanitized + ".db"
  }
}

///|
fn moon_valid_db_backup_filename(filename : String) -> Bool {
  !filename.contains("..") &&
  !filename.contains("/") &&
  !filename.contains("\\") &&
  filename.has_suffix(".db")
}

///|
fn moon_db_backup_filename_error(filename : String) -> String? {
  if moon_valid_db_backup_filename(filename) {
    None
  } else {
    Some("Invalid backup filename")
  }
}

///|
fn moon_db_backup_new_filename(new_name : String) -> Result[String, String] {
  let trimmed = new_name.trim().to_owned()
  if trimmed.is_empty() {
    return Err("New name cannot be empty")
  }
  let name_part = if trimmed.has_suffix(".db") {
    trimmed[:trimmed.length() - 3].to_owned()
  } else {
    trimmed
  }
  if name_part.length() > 100 {
    return Err("Name too long (max 100 characters)")
  }
  if name_part.contains("..") ||
    name_part.contains("/") ||
    name_part.contains("\\") ||
    name_part.contains("\u{0000}") {
    return Err("Invalid characters in new name")
  }
  Ok(name_part + ".db")
}

///|
async fn moon_ensure_db_backup_dir() -> Unit {
  @fsx.make_directory(moon_db_backup_dir(), recursive=true, exists_ok=true) catch {
    _ => ()
  }
}

///|
async fn ConfigService::moon_export_snapshot_json(
  self : ConfigService,
  proxy : ProxyService,
  host~ : String,
  port~ : Int,
) -> Json {
  {
    "format": Json::string("moonstat.config.v1"),
    "exportedAt": Json::number(@os.unix_seconds().to_double()),
    "settings": self.app_settings,
    "skills": moon_skill_state_load(),
    "proxy": proxy.moon_export_proxy_json(),
    "providers": proxy.moon_export_providers_json(),
    "suite": moonstat_suite_manifest_json(host~, port~),
  }.to_json()
}

///|
fn ProxyService::moon_export_proxy_json(self : ProxyService) -> Json {
  {
    "globalConfig": self.global_config_json(),
    "takeoverStatus": self.takeover_status_json(),
    "appConfigs": self.moon_export_proxy_app_configs_json(),
    "defaultCostMultipliers": moon_string_map_json(
      self.proxy_default_cost_multipliers,
    ),
    "pricingModelSources": moon_string_map_json(
      self.proxy_pricing_model_sources,
    ),
    "upstreamProxyUrl": match self.upstream_proxy_url {
      Some(url) => Json::string(url)
      None => Json::null()
    },
  }.to_json()
}

///|
fn ProxyService::moon_export_proxy_app_configs_json(
  self : ProxyService,
) -> Json {
  let obj : Map[String, Json] = Map([], capacity=0)
  for app in moon_suite_app_types() {
    obj[app] = self.app_config_json(app)
  }
  Json::object(obj)
}

///|
fn ProxyService::moon_export_providers_json(self : ProxyService) -> Json {
  let obj : Map[String, Json] = Map([], capacity=0)
  for app in moon_suite_app_types() {
    obj[app] = self.provider_router.providers_moon_json(app)
  }
  obj["universalProviders"] = self.provider_router.universal_providers_json()
  obj["routeStats"] = self.provider_router.route_stats_json()
  obj["circuitBreakerConfig"] = self.provider_router.circuit_config.to_json()
  Json::object(obj)
}

///|
fn moon_string_map_json(map : Map[String, String]) -> Json {
  let obj : Map[String, Json] = Map([], capacity=0)
  for key in map.keys() {
    guard map.get(key) is Some(value) else { continue }
    obj[key] = Json::string(value)
  }
  Json::object(obj)
}

///|
async fn ConfigService::moon_export_config_to_file_json(
  self : ConfigService,
  proxy : ProxyService,
  host~ : String,
  port~ : Int,
  file_path : String,
) -> Json {
  let snapshot = self.moon_export_snapshot_json(proxy, host~, port~)
  @fsx.write_to_file(file_path, snapshot.stringify(indent=2) + "\n") catch {
    error =>
      return {
        "success": Json::boolean(false),
        "message": Json::string("Export failed: \{error}"),
        "filePath": Json::string(file_path),
      }.to_json()
  }
  {
    "success": Json::boolean(true),
    "message": Json::string("SQL exported successfully"),
    "filePath": Json::string(file_path),
  }.to_json()
}

///|
async fn ConfigService::moon_import_config_from_file_json(
  self : ConfigService,
  proxy : ProxyService,
  host~ : String,
  port~ : Int,
  file_path : String,
) -> Json {
  let content = @fsx.read_file(file_path) catch {
    error =>
      return {
        "success": Json::boolean(false),
        "message": Json::string("Import failed: \{error}"),
        "filePath": Json::string(file_path),
      }.to_json()
  }
  let parsed = @json.parse(content) catch {
    error =>
      return {
        "success": Json::boolean(false),
        "message": Json::string("Import failed: \{error}"),
        "filePath": Json::string(file_path),
      }.to_json()
  }
  let backup_id = self.moon_create_db_backup_json(proxy, host~, port~)
  self.moon_apply_import_snapshot(proxy, parsed)
  {
    "success": Json::boolean(true),
    "message": Json::string("SQL imported successfully"),
    "filePath": Json::string(file_path),
    "backupId": backup_id,
    "warning": Json::null(),
  }.to_json()
}

///|
async fn ConfigService::moon_apply_import_snapshot(
  self : ConfigService,
  proxy : ProxyService,
  snapshot : Json,
) -> Unit {
  guard snapshot is Object(obj) else { return }
  match obj.get("settings") {
    Some(settings) =>
      self.app_settings = moon_merge_settings_for_save(
        settings,
        self.app_settings,
      )
    None => ()
  }
  match obj.get("skills") {
    Some(skills) => ignore(moon_skill_state_save(skills))
    None => ()
  }
  match obj.get("proxy") {
    Some(Object(proxy_json)) => proxy.moon_apply_import_proxy(proxy_json)
    _ => ()
  }
}

///|
fn ProxyService::moon_apply_import_proxy(
  self : ProxyService,
  proxy : Map[String, Json],
) -> Unit {
  match proxy.get("globalConfig") {
    Some(Object(global)) => {
      match json_bool_from_map_any(global, ["proxyEnabled", "proxy_enabled"]) {
        Some(enabled) => self.proxy_enabled = enabled
        None => ()
      }
      match
        json_string_from_map_any(global, ["listenAddress", "listen_address"]) {
        Some(address) => self.proxy_listen_address = address
        None => ()
      }
      match moon_json_int_from_map_any(global, ["listenPort", "listen_port"]) {
        Some(port) => self.proxy_listen_port = port
        None => ()
      }
      match
        json_bool_from_map_any(global, ["enableLogging", "enable_logging"]) {
        Some(enabled) => self.proxy_enable_logging = enabled
        None => ()
      }
    }
    _ => ()
  }
  match proxy.get("takeoverStatus") {
    Some(Object(takeover)) =>
      for app in moon_suite_app_types() {
        match json_bool_from_map_any(takeover, [app]) {
          Some(enabled) => self.proxy_takeover_enabled.set(app, enabled)
          None => ()
        }
      }
    _ => ()
  }
}

///|
fn moon_json_int_from_map_any(
  obj : Map[String, Json],
  keys : Array[String],
) -> Int? {
  for key in keys {
    match proxy_json_int(obj, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
async fn ConfigService::moon_create_db_backup_json(
  self : ConfigService,
  proxy : ProxyService,
  host~ : String,
  port~ : Int,
) -> Json {
  moon_ensure_db_backup_dir()
  let filename = moon_new_backup_filename()
  let path = moon_db_backup_path(filename)
  let snapshot = self.moon_export_snapshot_json(proxy, host~, port~)
  @fsx.write_to_file(path, snapshot.stringify(indent=2) + "\n") catch {
    _ => return Json::string("")
  }
  Json::string(filename)
}

///|
fn moon_new_backup_filename() -> String {
  let gen = @uuid.generator(@random.Rand::new())
  "moonstat-\{@os.unix_seconds()}-\{gen.v4()}.db"
}

///|
async fn moon_list_db_backups_json() -> Json {
  let entries = @fsx.list_directory(moon_db_backup_dir()) catch {
    _ => return Json::array([])
  }
  let rows : Array[MoonDbBackupEntry] = []
  for entry in entries {
    if !(entry.kind is Regular) || !entry.name.has_suffix(".db") {
      continue
    }
    let content = @fsx.read_file(entry.path) catch { _ => "" }
    let modified_at = moon_file_mtime(entry.path)
    rows.push({
      filename: entry.name,
      size_bytes: content.length(),
      created_at: modified_at,
    })
  }
  moon_sort_db_backup_entries(rows)
  Json::array(rows.map(fn(row) { row.to_json() }))
}

///|
async fn ConfigService::moon_restore_db_backup_json(
  self : ConfigService,
  proxy : ProxyService,
  filename : String,
) -> Result[Json, String] {
  match moon_db_backup_filename_error(filename) {
    Some(error) => return Err(error)
    None => ()
  }
  let path = moon_db_backup_path(filename)
  if !(@fsx.exists_as_file(path) catch { _ => false }) {
    return Err("Backup file not found: \{filename}")
  }
  let content = @fsx.read_file(path) catch { error => return Err("\{error}") }
  let parsed = @json.parse(content) catch { error => return Err("\{error}") }
  self.moon_apply_import_snapshot(proxy, parsed)
  Ok(Json::string(filename))
}

///|
async fn moon_rename_db_backup_json(
  old_filename : String,
  new_name : String,
) -> Result[Json, String] {
  match moon_db_backup_filename_error(old_filename) {
    Some(error) => return Err(error)
    None => ()
  }
  let new_filename = match moon_db_backup_new_filename(new_name) {
    Ok(name) => name
    Err(error) => return Err(error)
  }
  let old_path = moon_db_backup_path(old_filename)
  let new_path = moon_db_backup_path(new_filename)
  if !(@fsx.exists_as_file(old_path) catch { _ => false }) {
    return Err("Backup file not found: \{old_filename}")
  }
  let new_path_exists = @fsx.exists_as_file(new_path) catch { _ => false }
  if new_path_exists {
    return Err("A backup named '\{new_filename}' already exists")
  }
  let content = @fsx.read_file(old_path) catch {
    error => return Err("\{error}")
  }
  moon_ensure_db_backup_dir()
  @fsx.write_to_file(new_path, content) catch {
    error => return Err("\{error}")
  }
  @fsx.remove(old_path) catch {
    _ => ()
  }
  Ok(Json::string(new_filename))
}

///|
async fn moon_delete_db_backup_json(filename : String) -> Result[Json, String] {
  match moon_db_backup_filename_error(filename) {
    Some(error) => return Err(error)
    None => ()
  }
  let path = moon_db_backup_path(filename)
  if !(@fsx.exists_as_file(path) catch { _ => false }) {
    return Err("Backup file not found: \{filename}")
  }
  @fsx.remove(path) catch {
    error => return Err("\{error}")
  }
  Ok(Json::null())
}

///|
priv struct MoonDbBackupEntry {
  filename : String
  size_bytes : Int
  created_at : Int64
}

///|
fn moon_sort_db_backup_entries(rows : Array[MoonDbBackupEntry]) -> Unit {
  rows.sort_by(fn(left, right) { right.created_at.compare(left.created_at) })
}

///|
fn MoonDbBackupEntry::to_json(self : MoonDbBackupEntry) -> Json {
  {
    "filename": Json::string(self.filename),
    "sizeBytes": Json::number(self.size_bytes.to_double()),
    "createdAt": Json::string(self.created_at.to_string()),
  }.to_json()
}
