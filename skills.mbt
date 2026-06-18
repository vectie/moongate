///|
const MOONSTAT_SKILLS_STATE_FILE = "skills_state.json"

///|
const MOONSTAT_SKILLS_BACKUP_RETAIN_COUNT = 20

///|
fn moon_skill_supported_apps() -> Array[String] {
  ["claude", "codex", "gemini", "opencode", "hermes"]
}

///|
fn moon_skill_state_path() -> String {
  @pathx.join(moon_app_config_dir(), MOONSTAT_SKILLS_STATE_FILE)
}

///|
fn moon_skill_backup_dir() -> String {
  @pathx.join(moon_app_config_dir(), "skill-backups")
}

///|
fn moon_skill_default_repos_json() -> Array[Json] {
  [
    moon_skill_repo_json("anthropics", "skills", "main", true),
    moon_skill_repo_json("ComposioHQ", "awesome-claude-skills", "master", true),
    moon_skill_repo_json("cexll", "myclaude", "master", true),
    moon_skill_repo_json("JimLiu", "baoyu-skills", "main", true),
  ]
}

///|
fn moon_skill_repo_json(
  owner : String,
  name : String,
  branch : String,
  enabled : Bool,
) -> Json {
  {
    "owner": Json::string(owner),
    "name": Json::string(name),
    "branch": Json::string(branch),
    "enabled": Json::boolean(enabled),
  }.to_json()
}

///|
fn moon_skill_apps_json(app? : String? = None) -> Json {
  let apps : Map[String, Json] = Map([], capacity=0)
  for name in moon_skill_supported_apps() {
    apps[name] = Json::boolean(false)
  }
  match app {
    Some(value) => {
      let normalized = moon_normalize_app_type(value)
      if moon_skill_supported_apps().contains(normalized) {
        apps[normalized] = Json::boolean(true)
      }
    }
    None => ()
  }
  Json::object(apps)
}

///|
fn moon_skill_state_default_json() -> Json {
  {
    "installed": Json::array([]),
    "repos": Json::array(moon_skill_default_repos_json()),
    "backups": Json::array([]),
    "skillStorageLocation": Json::string("cc_switch"),
  }.to_json()
}

///|
async fn moon_skill_state_load(
  path? : String = moon_skill_state_path(),
) -> Json {
  let content = @fs.read_file(path).text() catch {
    _ => return moon_skill_state_default_json()
  }
  let parsed = @json.parse(content) catch {
    _ => return moon_skill_state_default_json()
  }
  guard parsed is Object(obj) else { return moon_skill_state_default_json() }
  if obj.get("repos") is None {
    obj["repos"] = Json::array(moon_skill_default_repos_json())
  }
  if obj.get("installed") is None {
    obj["installed"] = Json::array([])
  }
  if obj.get("backups") is None {
    obj["backups"] = Json::array([])
  }
  if obj.get("skillStorageLocation") is None {
    obj["skillStorageLocation"] = Json::string("cc_switch")
  }
  Json::object(obj)
}

///|
async fn moon_skill_state_save(
  state : Json,
  path? : String = moon_skill_state_path(),
) -> Bool {
  moon_skill_make_directory(@pathx.dirname(path).to_owned()) catch {
    _ => return false
  }
  @fs.write_file(
    path,
    @encoding/utf8.encode(state.stringify(indent=2)),
    create=0o644,
    truncate=true,
  ) catch {
    _ => return false
  }
  true
}

///|
async fn moon_skill_make_directory(path : String) -> Unit {
  let dirs : Array[String] = []
  for dir = path {
    if dir == "." || dir == "" || @fs.exists(dir) {
      break
    }
    dirs.push(dir)
    continue @pathx.dirname(dir).to_owned()
  }
  for i in 0..<dirs.length() {
    let dir = dirs[dirs.length() - 1 - i]
    @fs.mkdir(dir, permission=0o755) catch {
      _ => ()
    }
  }
}

///|
async fn moon_get_skill_repos_json(
  path? : String = moon_skill_state_path(),
) -> Json {
  guard moon_skill_state_load(path~) is Object(obj) else {
    return Json::array(moon_skill_default_repos_json())
  }
  match obj.get("repos") {
    Some(Array(repos)) => Json::array(repos)
    _ => Json::array(moon_skill_default_repos_json())
  }
}

///|
async fn moon_get_installed_skills_json(
  path? : String = moon_skill_state_path(),
) -> Json {
  guard moon_skill_state_load(path~) is Object(obj) else {
    return Json::array([])
  }
  match obj.get("installed") {
    Some(Array(skills)) => Json::array(skills)
    _ => Json::array([])
  }
}

///|
async fn moon_get_skill_backups_json(
  path? : String = moon_skill_state_path(),
) -> Json {
  guard moon_skill_state_load(path~) is Object(obj) else {
    return Json::array([])
  }
  match obj.get("backups") {
    Some(Array(backups)) => Json::array(backups)
    _ => Json::array([])
  }
}

///|
async fn moon_add_skill_repo_json(
  repo : Json,
  path? : String = moon_skill_state_path(),
) -> Json {
  guard moon_skill_repo_from_json(repo) is Some(normalized) else {
    return Json::boolean(false)
  }
  let state = moon_skill_state_load(path~)
  guard state is Object(obj) else { return Json::boolean(false) }
  let repos : Array[Json] = match obj.get("repos") {
    Some(Array(items)) => items
    _ => moon_skill_default_repos_json()
  }
  guard normalized is Object(repo_obj) else { return Json::boolean(false) }
  let owner = store_json_string_or_default(repo_obj, "owner", "")
  let name = store_json_string_or_default(repo_obj, "name", "")
  let next : Array[Json] = []
  let mut replaced = false
  for item in repos {
    guard item is Object(item_obj) else { continue }
    if store_json_string_or_default(item_obj, "owner", "") == owner &&
      store_json_string_or_default(item_obj, "name", "") == name {
      next.push(normalized)
      replaced = true
    } else {
      next.push(item)
    }
  }
  if !replaced {
    next.push(normalized)
  }
  obj["repos"] = Json::array(next)
  Json::boolean(moon_skill_state_save(Json::object(obj), path~))
}

///|
async fn moon_remove_skill_repo_json(
  owner : String,
  name : String,
  path? : String = moon_skill_state_path(),
) -> Json {
  let state = moon_skill_state_load(path~)
  guard state is Object(obj) else { return Json::boolean(false) }
  let repos : Array[Json] = match obj.get("repos") {
    Some(Array(items)) => items
    _ => moon_skill_default_repos_json()
  }
  let next : Array[Json] = []
  for item in repos {
    guard item is Object(item_obj) else { continue }
    if store_json_string_or_default(item_obj, "owner", "") == owner &&
      store_json_string_or_default(item_obj, "name", "") == name {
      continue
    }
    next.push(item)
  }
  obj["repos"] = Json::array(next)
  Json::boolean(moon_skill_state_save(Json::object(obj), path~))
}

///|
fn moon_skill_repo_from_json(json : Json) -> Json? {
  guard json is Object(obj) else { return None }
  let owner = store_json_string_or_default(obj, "owner", "").trim().to_owned()
  let name = store_json_string_or_default(obj, "name", "").trim().to_owned()
  if owner.is_empty() || name.is_empty() {
    return None
  }
  let branch = store_json_string_or_default(obj, "branch", "main").trim()
  let enabled = match obj.get("enabled") {
    Some(True) => true
    Some(False) => false
    _ => true
  }
  Some(
    moon_skill_repo_json(
      owner,
      name,
      if branch.is_empty() {
        "main"
      } else {
        branch.to_owned()
      },
      enabled,
    ),
  )
}

///|
fn moon_skill_json_from_discoverable(
  skill : Json,
  current_app : String,
  installed_at? : Int = @os.unix_seconds(),
) -> Json? {
  guard skill is Object(obj) else { return None }
  let directory = moon_skill_install_name(
    store_json_string_or_default(obj, "directory", ""),
  )
  if directory.is_empty() {
    return None
  }
  let repo_owner = store_json_string_or_default(obj, "repoOwner", "")
  let repo_name = store_json_string_or_default(obj, "repoName", "")
  let key = store_json_string_or_default(
    obj,
    "key",
    if repo_owner.is_empty() || repo_name.is_empty() {
      "local:\{directory}"
    } else {
      "\{repo_owner}/\{repo_name}:\{directory}"
    },
  )
  let name = store_json_string_or_default(obj, "name", directory)
  let description = store_json_optional_string(obj, "description")
  let repo_branch = store_json_optional_string(obj, "repoBranch")
  let readme_url = store_json_optional_string(obj, "readmeUrl")
  Some(
    moon_installed_skill_json(
      id=key,
      name~,
      description~,
      directory~,
      repo_owner=if repo_owner.is_empty() { None } else { Some(repo_owner) },
      repo_name=if repo_name.is_empty() { None } else { Some(repo_name) },
      repo_branch~,
      readme_url~,
      apps=moon_skill_apps_json(app=Some(current_app)),
      installed_at~,
      content_hash=None,
      updated_at=0,
    ),
  )
}

///|
fn moon_skill_request_payload(body : Json?) -> Json? {
  match body {
    Some(Object(obj)) =>
      match obj.get("skill") {
        Some(Object(skill)) => Some(Json::object(skill))
        _ => Some(Json::object(obj))
      }
    _ => None
  }
}

///|
fn moon_installed_skill_json(
  id~ : String,
  name~ : String,
  description~ : String?,
  directory~ : String,
  repo_owner~ : String?,
  repo_name~ : String?,
  repo_branch~ : String?,
  readme_url~ : String?,
  apps~ : Json,
  installed_at~ : Int,
  content_hash~ : String?,
  updated_at~ : Int,
) -> Json {
  let obj : Map[String, Json] = {
    "id": Json::string(id),
    "name": Json::string(name),
    "directory": Json::string(directory),
    "apps": apps,
    "installedAt": Json::number(installed_at.to_double()),
    "updatedAt": Json::number(updated_at.to_double()),
  }
  if description is Some(value) && !value.is_empty() {
    obj["description"] = Json::string(value)
  }
  if repo_owner is Some(value) && !value.is_empty() {
    obj["repoOwner"] = Json::string(value)
  }
  if repo_name is Some(value) && !value.is_empty() {
    obj["repoName"] = Json::string(value)
  }
  if repo_branch is Some(value) && !value.is_empty() {
    obj["repoBranch"] = Json::string(value)
  }
  if readme_url is Some(value) && !value.is_empty() {
    obj["readmeUrl"] = Json::string(value)
  }
  if content_hash is Some(value) && !value.is_empty() {
    obj["contentHash"] = Json::string(value)
  }
  Json::object(obj)
}

///|
async fn moon_install_skill_unified_json(
  skill : Json,
  current_app : String,
  state_path? : String = moon_skill_state_path(),
) -> Json {
  guard moon_skill_json_from_discoverable(skill, current_app) is Some(installed) else {
    return Json::null()
  }
  moon_upsert_installed_skill_json(installed, state_path~)
}

///|
async fn moon_upsert_installed_skill_json(
  installed : Json,
  state_path? : String = moon_skill_state_path(),
) -> Json {
  let state = moon_skill_state_load(path=state_path)
  guard state is Object(obj) else { return installed }
  guard installed is Object(installed_obj) else { return installed }
  let id = store_json_string_or_default(installed_obj, "id", "")
  let directory = store_json_string_or_default(installed_obj, "directory", "")
  let existing : Array[Json] = match obj.get("installed") {
    Some(Array(items)) => items
    _ => []
  }
  let next : Array[Json] = []
  let mut replaced = false
  for item in existing {
    guard item is Object(item_obj) else { continue }
    let same_id = !id.is_empty() &&
      store_json_string_or_default(item_obj, "id", "") == id
    let same_dir = !directory.is_empty() &&
      store_json_string_or_default(item_obj, "directory", "") == directory
    if same_id || same_dir {
      next.push(moon_merge_installed_skill_apps(item, installed))
      replaced = true
    } else {
      next.push(item)
    }
  }
  if !replaced {
    next.push(installed)
  }
  obj["installed"] = Json::array(next)
  ignore(moon_skill_state_save(Json::object(obj), path=state_path))
  if replaced {
    for item in next {
      guard item is Object(item_obj) else { continue }
      if store_json_string_or_default(item_obj, "id", "") == id ||
        store_json_string_or_default(item_obj, "directory", "") == directory {
        return item
      }
    }
  }
  installed
}

///|
fn moon_merge_installed_skill_apps(old : Json, incoming : Json) -> Json {
  guard old is Object(old_obj) else { return incoming }
  guard incoming is Object(new_obj) else { return old }
  let apps = moon_merge_skill_apps_json(
    old_obj.get("apps"),
    new_obj.get("apps"),
  )
  for key, value in new_obj {
    old_obj[key] = value
  }
  old_obj["apps"] = apps
  Json::object(old_obj)
}

///|
fn moon_merge_skill_apps_json(old : Json?, incoming : Json?) -> Json {
  let merged : Map[String, Json] = Map([], capacity=0)
  for name in moon_skill_supported_apps() {
    let enabled = moon_skill_app_enabled_json(old, name) ||
      moon_skill_app_enabled_json(incoming, name)
    merged[name] = Json::boolean(enabled)
  }
  Json::object(merged)
}

///|
fn moon_skill_app_enabled_json(apps : Json?, app : String) -> Bool {
  match apps {
    Some(Object(obj)) =>
      match obj.get(moon_normalize_app_type(app)) {
        Some(True) => true
        _ => false
      }
    _ => false
  }
}

///|
async fn moon_toggle_skill_app_json(
  id : String,
  app : String,
  enabled : Bool,
  state_path? : String = moon_skill_state_path(),
) -> Json {
  let normalized = moon_normalize_app_type(app)
  if !moon_skill_supported_apps().contains(normalized) {
    return Json::boolean(false)
  }
  let state = moon_skill_state_load(path=state_path)
  guard state is Object(obj) else { return Json::boolean(false) }
  let existing : Array[Json] = match obj.get("installed") {
    Some(Array(items)) => items
    _ => []
  }
  let next : Array[Json] = []
  let mut changed = false
  for item in existing {
    guard item is Object(item_obj) else { continue }
    let matches = store_json_string_or_default(item_obj, "id", "") == id ||
      store_json_string_or_default(item_obj, "directory", "") == id
    if matches {
      let apps = moon_skill_apps_with_enabled(
        item_obj.get("apps"),
        normalized,
        enabled,
      )
      item_obj["apps"] = apps
      changed = true
      next.push(Json::object(item_obj))
    } else {
      next.push(item)
    }
  }
  obj["installed"] = Json::array(next)
  Json::boolean(
    changed && moon_skill_state_save(Json::object(obj), path=state_path),
  )
}

///|
fn moon_skill_apps_with_enabled(
  apps : Json?,
  app : String,
  enabled : Bool,
) -> Json {
  let obj : Map[String, Json] = Map([], capacity=0)
  for name in moon_skill_supported_apps() {
    obj[name] = Json::boolean(moon_skill_app_enabled_json(apps, name))
  }
  obj[app] = Json::boolean(enabled)
  Json::object(obj)
}

///|
async fn moon_uninstall_skill_unified_json(
  id : String,
  state_path? : String = moon_skill_state_path(),
) -> Json {
  let state = moon_skill_state_load(path=state_path)
  guard state is Object(obj) else { return Json::null() }
  let existing : Array[Json] = match obj.get("installed") {
    Some(Array(items)) => items
    _ => []
  }
  let next : Array[Json] = []
  let mut removed : Json? = None
  for item in existing {
    guard item is Object(item_obj) else { continue }
    if store_json_string_or_default(item_obj, "id", "") == id ||
      store_json_string_or_default(item_obj, "directory", "") == id {
      removed = Some(Json::object(item_obj))
    } else {
      next.push(item)
    }
  }
  obj["installed"] = Json::array(next)
  let backup_path = match removed {
    Some(skill) => {
      let entry = moon_skill_backup_entry_json(skill)
      obj["backups"] = moon_skill_prepend_backup(obj.get("backups"), entry)
      match entry {
        Object(entry_obj) => store_json_optional_string(entry_obj, "backupPath")
        _ => None
      }
    }
    None => None
  }
  ignore(moon_skill_state_save(Json::object(obj), path=state_path))
  {
    "backupPath": match backup_path {
      Some(path) => Json::string(path)
      None => Json::null()
    },
  }.to_json()
}

///|
fn moon_skill_backup_entry_json(skill : Json) -> Json {
  let now = @os.unix_seconds()
  let directory = match skill {
    Object(obj) => store_json_string_or_default(obj, "directory", "skill")
    _ => "skill"
  }
  let backup_id = "\{directory}-\{now}"
  {
    "backupId": Json::string(backup_id),
    "backupPath": Json::string(@pathx.join(moon_skill_backup_dir(), backup_id)),
    "createdAt": Json::number(now.to_double()),
    "skill": skill,
  }.to_json()
}

///|
fn moon_skill_prepend_backup(existing : Json?, entry : Json) -> Json {
  let backups : Array[Json] = [entry]
  match existing {
    Some(Array(items)) =>
      for item in items {
        if backups.length() < MOONSTAT_SKILLS_BACKUP_RETAIN_COUNT {
          backups.push(item)
        }
      }
    _ => ()
  }
  Json::array(backups)
}

///|
async fn moon_delete_skill_backup_json(
  backup_id : String,
  state_path? : String = moon_skill_state_path(),
) -> Json {
  let state = moon_skill_state_load(path=state_path)
  guard state is Object(obj) else { return Json::boolean(false) }
  let existing : Array[Json] = match obj.get("backups") {
    Some(Array(items)) => items
    _ => []
  }
  let next : Array[Json] = []
  let mut removed = false
  for item in existing {
    guard item is Object(item_obj) else { continue }
    if store_json_string_or_default(item_obj, "backupId", "") == backup_id {
      removed = true
    } else {
      next.push(item)
    }
  }
  obj["backups"] = Json::array(next)
  Json::boolean(
    removed && moon_skill_state_save(Json::object(obj), path=state_path),
  )
}

///|
async fn moon_restore_skill_backup_json(
  backup_id : String,
  current_app : String,
  state_path? : String = moon_skill_state_path(),
) -> Json {
  let backups = moon_get_skill_backups_json(path=state_path)
  guard backups is Array(items) else { return Json::null() }
  for item in items {
    guard item is Object(item_obj) else { continue }
    if store_json_string_or_default(item_obj, "backupId", "") == backup_id {
      guard item_obj.get("skill") is Some(Object(skill_obj)) else {
        return Json::null()
      }
      skill_obj["apps"] = moon_skill_apps_with_enabled(
        skill_obj.get("apps"),
        moon_normalize_app_type(current_app),
        true,
      )
      return moon_upsert_installed_skill_json(
        Json::object(skill_obj),
        state_path~,
      )
    }
  }
  Json::null()
}

///|
fn moon_check_skill_updates_json() -> Json {
  Json::array([])
}

///|
async fn moon_update_skill_json(
  id : String,
  state_path? : String = moon_skill_state_path(),
) -> Json {
  let installed = moon_get_installed_skills_json(path=state_path)
  guard installed is Array(items) else { return Json::null() }
  for item in items {
    guard item is Object(obj) else { continue }
    if store_json_string_or_default(obj, "id", "") == id ||
      store_json_string_or_default(obj, "directory", "") == id {
      obj["updatedAt"] = Json::number(@os.unix_seconds().to_double())
      return moon_upsert_installed_skill_json(Json::object(obj), state_path~)
    }
  }
  Json::null()
}

///|
async fn moon_migrate_skill_storage_json(
  target : String,
  state_path? : String = moon_skill_state_path(),
  cc_switch_dir? : String = moon_cc_switch_skills_dir(),
  unified_dir? : String = moon_unified_skills_dir(),
) -> Json {
  guard moon_normalize_skill_storage_location(target) is Some(target_location) else {
    return moon_skill_migration_result_json(0, 0, [
      Json::string("invalid target storage location: \{target}"),
    ])
  }
  let state = moon_skill_state_load(path=state_path)
  guard state is Object(obj) else {
    return moon_skill_migration_result_json(0, 0, [
      Json::string("failed to load skill state"),
    ])
  }
  let current_location = moon_normalize_skill_storage_location(
    store_json_string_or_default(obj, "skillStorageLocation", "cc_switch"),
  ).unwrap_or("cc_switch")
  if current_location == target_location {
    return moon_skill_migration_result_json(0, 0, [])
  }
  let source_dir = moon_skill_storage_dir(
    current_location, cc_switch_dir, unified_dir,
  )
  let dest_dir = moon_skill_storage_dir(
    target_location, cc_switch_dir, unified_dir,
  )
  moon_skill_make_directory(dest_dir) catch {
    err =>
      return moon_skill_migration_result_json(0, 0, [
        Json::string("failed to create target directory: \{err}"),
      ])
  }
  let installed : Array[Json] = match obj.get("installed") {
    Some(Array(items)) => items
    _ => []
  }
  let mut migrated_count = 0
  let mut skipped_count = 0
  let errors : Array[Json] = []
  for item in installed {
    guard item is Object(skill) else {
      skipped_count = skipped_count + 1
      continue
    }
    let directory = moon_skill_install_name(
      store_json_string_or_default(skill, "directory", ""),
    )
    if directory.is_empty() {
      skipped_count = skipped_count + 1
      continue
    }
    let source_path = @pathx.join(source_dir, directory)
    let dest_path = @pathx.join(dest_dir, directory)
    if !@fs.exists(source_path) {
      skipped_count = skipped_count + 1
      continue
    }
    if @fs.exists(dest_path) {
      skipped_count = skipped_count + 1
      continue
    }
    match moon_copy_skill_directory(source_path, dest_path) {
      Ok(_) => {
        @fs.rmdir(source_path, recursive=true) catch {
          err =>
            errors.push(
              Json::string(
                "failed to remove source directory \{source_path}: \{err}",
              ),
            )
        }
        migrated_count = migrated_count + 1
      }
      Err(message) => errors.push(Json::string(message))
    }
  }
  obj["skillStorageLocation"] = Json::string(target_location)
  ignore(moon_skill_state_save(Json::object(obj), path=state_path))
  moon_skill_migration_result_json(migrated_count, skipped_count, errors)
}

///|
fn moon_normalize_skill_storage_location(value : String) -> String? {
  match value.trim().to_owned().to_lower() {
    "cc_switch" | "cc-switch" | "ccswitch" => Some("cc_switch")
    "unified" => Some("unified")
    _ => None
  }
}

///|
fn moon_cc_switch_skills_dir() -> String {
  @pathx.join(moon_app_config_dir(), "skills")
}

///|
fn moon_unified_skills_dir() -> String {
  @pathx.join(moon_home_dir(), ".agents/skills")
}

///|
fn moon_skill_storage_dir(
  location : String,
  cc_switch_dir : String,
  unified_dir : String,
) -> String {
  if location == "unified" {
    unified_dir
  } else {
    cc_switch_dir
  }
}

///|
async fn moon_copy_skill_directory(
  source_path : String,
  dest_path : String,
) -> Result[Unit, String] {
  try {
    let kind = @fs.kind(source_path, follow_symlink=false)
    match kind {
      Directory => {
        moon_skill_make_directory(dest_path)
        let entries = @fsx.list_directory(source_path)
        for entry in entries {
          let child_source = entry.path
          let child_dest = @pathx.join(dest_path, entry.name)
          match entry.kind {
            Directory =>
              match moon_copy_skill_directory(child_source, child_dest) {
                Ok(_) => ()
                Err(message) => return Err(message)
              }
            Regular | SymLink => {
              let bytes = @fs.read_file(child_source)
              @fs.write_file(child_dest, bytes, create=0o644, truncate=true)
            }
            _ => ()
          }
        }
      }
      Regular | SymLink => {
        moon_skill_make_directory(@pathx.dirname(dest_path).to_owned())
        let bytes = @fs.read_file(source_path)
        @fs.write_file(dest_path, bytes, create=0o644, truncate=true)
      }
      _ => return Err("unsupported skill entry kind: \{source_path}")
    }
    Ok(())
  } catch {
    err => Err("failed to copy skill directory \{source_path}: \{err}")
  }
}

///|
fn moon_skill_migration_result_json(
  migrated_count : Int,
  skipped_count : Int,
  errors : Array[Json],
) -> Json {
  {
    "migratedCount": Json::number(migrated_count.to_double()),
    "skippedCount": Json::number(skipped_count.to_double()),
    "errors": Json::array(errors),
  }.to_json()
}

///|
fn moon_search_skills_sh_json(
  query : String,
  limit : Int,
  offset : Int,
) -> Json {
  ignore(offset)
  let skills : Array[Json] = []
  if query.trim().length() >= 2 {
    for repo in moon_skill_default_repos_json() {
      guard repo is Object(repo_obj) else { continue }
      if skills.length() >= limit {
        break
      }
      let owner = store_json_string_or_default(repo_obj, "owner", "")
      let name = store_json_string_or_default(repo_obj, "name", "")
      let branch = store_json_string_or_default(repo_obj, "branch", "main")
      skills.push(
        {
          "key": Json::string("\{owner}/\{name}:skills"),
          "name": Json::string("\{name} skills"),
          "directory": Json::string("skills"),
          "repoOwner": Json::string(owner),
          "repoName": Json::string(name),
          "repoBranch": Json::string(branch),
          "installs": Json::number(0.0),
          "readmeUrl": Json::string(
            "https://github.com/\{owner}/\{name}/tree/\{branch}",
          ),
        }.to_json(),
      )
    }
  }
  {
    "skills": Json::array(skills),
    "totalCount": Json::number(skills.length().to_double()),
    "query": Json::string(query),
  }.to_json()
}

///|
async fn moon_discover_available_skills_json(
  state_path? : String = moon_skill_state_path(),
) -> Json {
  let repos = moon_get_skill_repos_json(path=state_path)
  guard repos is Array(items) else { return Json::array([]) }
  let skills : Array[Json] = []
  for item in items {
    guard item is Object(repo) else { continue }
    if repo.get("enabled") == Some(Json::boolean(false)) {
      continue
    }
    let owner = store_json_string_or_default(repo, "owner", "")
    let name = store_json_string_or_default(repo, "name", "")
    let branch = store_json_string_or_default(repo, "branch", "main")
    if owner.is_empty() || name.is_empty() {
      continue
    }
    skills.push(
      {
        "key": Json::string("\{owner}/\{name}:skills"),
        "name": Json::string("\{name} skills"),
        "description": Json::string("Discovered from \{owner}/\{name}"),
        "directory": Json::string("skills"),
        "repoOwner": Json::string(owner),
        "repoName": Json::string(name),
        "repoBranch": Json::string(branch),
        "readmeUrl": Json::string(
          "https://github.com/\{owner}/\{name}/tree/\{branch}",
        ),
      }.to_json(),
    )
  }
  Json::array(skills)
}

///|
async fn moon_get_skills_json(
  state_path? : String = moon_skill_state_path(),
) -> Json {
  let installed = moon_get_installed_skills_json(path=state_path)
  let installed_dirs : Array[String] = []
  if installed is Array(items) {
    for item in items {
      guard item is Object(obj) else { continue }
      installed_dirs.push(store_json_string_or_default(obj, "directory", ""))
    }
  }
  let discovered = moon_discover_available_skills_json(state_path~)
  guard discovered is Array(items) else { return Json::array([]) }
  let result : Array[Json] = []
  for item in items {
    guard item is Object(obj) else { continue }
    let directory = store_json_string_or_default(obj, "directory", "")
    result.push(
      {
        "key": Json::string(store_json_string_or_default(obj, "key", directory)),
        "name": Json::string(
          store_json_string_or_default(obj, "name", directory),
        ),
        "description": Json::string(
          store_json_string_or_default(obj, "description", ""),
        ),
        "directory": Json::string(directory),
        "readmeUrl": obj.get("readmeUrl").unwrap_or(Json::null()),
        "installed": Json::boolean(installed_dirs.contains(directory)),
        "repoOwner": obj.get("repoOwner").unwrap_or(Json::null()),
        "repoName": obj.get("repoName").unwrap_or(Json::null()),
        "repoBranch": obj.get("repoBranch").unwrap_or(Json::null()),
      }.to_json(),
    )
  }
  Json::array(result)
}

///|
async fn moon_scan_unmanaged_skills_json() -> Json {
  let result : Array[Json] = []
  for app in moon_skill_supported_apps() {
    let dir = moon_app_skills_dir(app)
    if !@fs.exists(dir) {
      continue
    }
    let directory = @fs.opendir(dir) catch { _ => continue }
    defer directory.close()
    for entry_name in directory.read_all() {
      let entry_path = @pathx.join(dir, entry_name)
      let skill_file = @pathx.join(entry_path, "SKILL.md")
      if !@fs.exists(skill_file) {
        continue
      }
      let (skill_name, description) = moon_skill_metadata_from_file(skill_file)
      result.push(
        {
          "directory": Json::string(entry_name),
          "name": Json::string(skill_name.unwrap_or(entry_name)),
          "description": match description {
            Some(value) => Json::string(value)
            None => Json::null()
          },
          "foundIn": Json::array([Json::string(app)]),
          "path": Json::string(entry_path),
        }.to_json(),
      )
    }
  }
  Json::array(result)
}

///|
async fn moon_import_skills_from_apps_json(
  imports : Json,
  state_path? : String = moon_skill_state_path(),
) -> Json {
  let imported : Array[Json] = []
  guard imports is Array(items) else { return Json::array(imported) }
  for item in items {
    guard item is Object(obj) else { continue }
    let directory = moon_skill_install_name(
      store_json_string_or_default(obj, "directory", ""),
    )
    if directory.is_empty() {
      continue
    }
    let apps = match obj.get("apps") {
      Some(apps) => apps
      None => moon_skill_apps_json()
    }
    let skill = moon_installed_skill_json(
      id="local:\{directory}",
      name=directory,
      description=None,
      directory~,
      repo_owner=None,
      repo_name=None,
      repo_branch=None,
      readme_url=None,
      apps~,
      installed_at=@os.unix_seconds(),
      content_hash=None,
      updated_at=0,
    )
    imported.push(moon_upsert_installed_skill_json(skill, state_path~))
  }
  Json::array(imported)
}

///|
async fn moon_install_skills_from_zip_json(
  file_path : String,
  current_app : String,
  state_path? : String = moon_skill_state_path(),
  cc_switch_dir? : String = moon_cc_switch_skills_dir(),
  unified_dir? : String = moon_unified_skills_dir(),
  app_dir? : String = moon_app_skills_dir(current_app),
) -> Json {
  if !@fs.exists(file_path) {
    return Json::array([])
  }
  if moon_path_is_directory(file_path) {
    return moon_install_skills_from_extracted_dir_json(
      file_path,
      current_app,
      state_path~,
      cc_switch_dir~,
      unified_dir~,
      app_dir~,
      source_name=@pathx.basename(file_path).to_owned(),
    )
  }

  @fsx.with_temporary_directory("moonstat-skills-zip-XXXXXX", async fn(tmpdir) {
    if !moon_extract_local_zip(file_path, tmpdir) {
      return Json::array([])
    }
    moon_install_skills_from_extracted_dir_json(
      tmpdir,
      current_app,
      state_path~,
      cc_switch_dir~,
      unified_dir~,
      app_dir~,
      source_name=@pathx.basename(file_path).to_owned(),
    )
  })
}

///|
async fn moon_install_skills_from_extracted_dir_json(
  root_dir : String,
  current_app : String,
  state_path? : String = moon_skill_state_path(),
  cc_switch_dir? : String = moon_cc_switch_skills_dir(),
  unified_dir? : String = moon_unified_skills_dir(),
  app_dir? : String = moon_app_skills_dir(current_app),
  source_name? : String = @pathx.basename(root_dir).to_owned(),
) -> Json {
  let skill_dirs = moon_scan_skill_dirs_in_dir(root_dir)
  if skill_dirs.is_empty() {
    return Json::array([])
  }
  let state = moon_skill_state_load(path=state_path)
  guard state is Object(state_obj) else { return Json::array([]) }
  let storage_dir = moon_skill_storage_dir_for_state(
    Json::object(state_obj),
    cc_switch_dir,
    unified_dir,
  )
  let existing : Array[Json] = match state_obj.get("installed") {
    Some(Array(items)) => items
    _ => []
  }
  let installed : Array[Json] = []
  for skill_dir in skill_dirs {
    let (name, description) = moon_skill_metadata_from_file(
      @pathx.join(skill_dir, "SKILL.md"),
    )
    guard moon_skill_zip_install_name(skill_dir, root_dir, name, source_name~)
      is Some(directory) else {
      continue
    }
    if moon_installed_skill_directory_exists(existing, directory) {
      continue
    }
    let dest = @pathx.join(storage_dir, directory)
    if @fs.exists(dest) {
      @fs.rmdir(dest, recursive=true) catch {
        _ => ()
      }
    }
    match moon_copy_skill_directory(skill_dir, dest) {
      Ok(_) => ()
      Err(_) => continue
    }
    if !app_dir.is_empty() {
      let app_dest = @pathx.join(app_dir, directory)
      if @fs.exists(app_dest) {
        @fs.rmdir(app_dest, recursive=true) catch {
          _ => ()
        }
      }
      ignore(moon_copy_skill_directory(dest, app_dest))
    }
    let skill = moon_installed_skill_json(
      id="local:\{directory}",
      name=name.unwrap_or(directory),
      description~,
      directory~,
      repo_owner=None,
      repo_name=None,
      repo_branch=None,
      readme_url=None,
      apps=moon_skill_apps_json(app=Some(current_app)),
      installed_at=@os.unix_seconds(),
      content_hash=moon_skill_dir_hash(dest),
      updated_at=0,
    )
    installed.push(moon_upsert_installed_skill_json(skill, state_path~))
  }
  Json::array(installed)
}

///|
async fn moon_extract_local_zip(zip_path : String, dest_dir : String) -> Bool {
  let result = @spawn.spawn(
    "unzip",
    ["-qq", "-o", zip_path, "-d", dest_dir],
    timeout=60000,
  ) catch {
    _ => return false
  }
  result.status == 0
}

///|
async fn moon_scan_skill_dirs_in_dir(root_dir : String) -> Array[String] {
  let result : Array[String] = []
  moon_scan_skill_dirs_recursive(root_dir, result, depth=0)
  result
}

///|
async fn moon_scan_skill_dirs_recursive(
  dir : String,
  result : Array[String],
  depth~ : Int,
) -> Unit {
  if depth > 16 || !moon_path_is_directory(dir) {
    return
  }
  if @fs.exists(@pathx.join(dir, "SKILL.md")) {
    result.push(dir)
  }
  let entries = @fsx.list_directory(dir) catch { _ => return }
  for entry in entries {
    if entry.name.has_prefix(".") {
      continue
    }
    if entry.kind is Directory {
      moon_scan_skill_dirs_recursive(entry.path, result, depth=depth + 1)
    }
  }
}

///|
fn moon_skill_zip_install_name(
  skill_dir : String,
  root_dir : String,
  skill_name : String?,
  source_name~ : String,
) -> String? {
  let dir_name = @pathx.basename(skill_dir).to_owned()
  if skill_dir == root_dir || dir_name.is_empty() || dir_name.has_prefix(".") {
    match skill_name {
      Some(name) =>
        match moon_skill_install_name(name) {
          "" => moon_skill_install_name_optional(source_name)
          value => Some(value)
        }
      None => moon_skill_install_name_optional(source_name)
    }
  } else {
    match moon_skill_install_name(dir_name) {
      "" =>
        match skill_name {
          Some(name) => moon_skill_install_name_optional(name)
          None => moon_skill_install_name_optional(source_name)
        }
      value => Some(value)
    }
  }
}

///|
fn moon_skill_install_name_optional(value : String) -> String? {
  match moon_skill_install_name(value) {
    "" => None
    normalized => Some(normalized)
  }
}

///|
fn moon_installed_skill_directory_exists(
  installed : Array[Json],
  directory : String,
) -> Bool {
  for item in installed {
    guard item is Object(obj) else { continue }
    if store_json_string_or_default(obj, "directory", "").to_lower() ==
      directory.to_lower() {
      return true
    }
  }
  false
}

///|
fn moon_skill_storage_dir_for_state(
  state : Json,
  cc_switch_dir : String,
  unified_dir : String,
) -> String {
  guard state is Object(obj) else { return cc_switch_dir }
  let location = moon_normalize_skill_storage_location(
    store_json_string_or_default(obj, "skillStorageLocation", "cc_switch"),
  ).unwrap_or("cc_switch")
  moon_skill_storage_dir(location, cc_switch_dir, unified_dir)
}

///|
async fn moon_skill_dir_hash(dir : String) -> String? {
  let files : Array[String] = []
  moon_collect_skill_hash_files(dir, dir, files, depth=0)
  files.sort()
  let bytes : Array[Byte] = []
  for relative in files {
    for byte in @encoding/utf8.encode(relative.replace(old="\\", new="/")) {
      bytes.push(byte)
    }
    bytes.push(0)
    let content = @fs.read_file(@pathx.join(dir, relative)) catch {
      _ => return None
    }
    for byte in content.binary() {
      bytes.push(byte)
    }
    bytes.push(0)
  }
  Some(moon_skill_sha256_hex(Bytes::from_array(bytes)))
}

///|
async fn moon_collect_skill_hash_files(
  base_dir : String,
  current_dir : String,
  files : Array[String],
  depth~ : Int,
) -> Unit {
  if depth > 16 {
    return
  }
  let entries = @fsx.list_directory(current_dir) catch { _ => return }
  for entry in entries {
    if entry.name.has_prefix(".") {
      continue
    }
    match entry.kind {
      Directory =>
        moon_collect_skill_hash_files(
          base_dir,
          entry.path,
          files,
          depth=depth + 1,
        )
      Regular | SymLink => files.push(moon_relative_path(base_dir, entry.path))
      _ => ()
    }
  }
}

///|
fn moon_relative_path(base_dir : String, path : String) -> String {
  let prefix = if base_dir.has_suffix("/") { base_dir } else { "\{base_dir}/" }
  if path.has_prefix(prefix) {
    path[prefix.length():].to_owned()
  } else {
    @pathx.basename(path).to_owned()
  }
}

///|
fn moon_skill_sha256_hex(bytes : Bytes) -> String {
  let digest = @crypto.sha256(bytes)
  let builder = StringBuilder::new()
  for byte in digest {
    let value = byte.to_int()
    builder.write_char(moon_skill_hex_digit(value / 16))
    builder.write_char(moon_skill_hex_digit(value % 16))
  }
  builder.to_string()
}

///|
fn moon_skill_hex_digit(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('a'.to_int() + n - 10).unsafe_to_char()
  }
}

///|
async fn moon_path_is_directory(path : String) -> Bool {
  (@fs.kind(path, follow_symlink=false) is Directory) catch {
    _ => false
  }
}

///|
async fn moon_skill_metadata_from_file(path : String) -> (String?, String?) {
  let content = @fs.read_file(path).text() catch { _ => return (None, None) }
  let mut name : String? = None
  let mut description : String? = None
  let mut in_frontmatter = false
  for line_view in content.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    if line == "---" {
      in_frontmatter = !in_frontmatter
      continue
    }
    if !in_frontmatter {
      if line.has_prefix("# ") && name is None {
        name = Some(line[2:].trim().to_owned())
      }
      continue
    }
    if line.has_prefix("name:") {
      name = Some(moon_yaml_scalar(line[5:]))
    } else if line.has_prefix("description:") {
      description = Some(moon_yaml_scalar(line[12:]))
    }
  }
  (name, description)
}

///|
fn moon_yaml_scalar(value : StringView) -> String {
  let trimmed = value.to_owned().trim().to_owned()
  if trimmed.length() >= 2 &&
    (
      (trimmed.has_prefix("\"") && trimmed.has_suffix("\"")) ||
      (trimmed.has_prefix("'") && trimmed.has_suffix("'"))
    ) {
    trimmed[1:trimmed.length() - 1].to_owned()
  } else {
    trimmed
  }
}

///|
fn moon_skill_install_name(directory : String) -> String {
  let normalized = directory.replace(old="\\", new="/").trim().to_owned()
  let base = @pathx.basename(normalized).to_owned().trim().to_owned()
  if base == "." || base == ".." || base.has_prefix(".") || base.contains("/") {
    ""
  } else {
    base
  }
}

///|
fn moon_app_skills_dir(app : String) -> String {
  @pathx.join(moon_config_dir(app), "skills")
}
