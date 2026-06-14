///|
const CCS_SKILLS_STATE_FILE = "skills_state.json"

///|
const CCS_SKILLS_BACKUP_RETAIN_COUNT = 20

///|
fn ccs_skill_supported_apps() -> Array[String] {
  ["claude", "codex", "gemini", "opencode", "hermes"]
}

///|
fn ccs_skill_state_path() -> String {
  @pathx.join(ccs_app_config_dir(), CCS_SKILLS_STATE_FILE)
}

///|
fn ccs_skill_backup_dir() -> String {
  @pathx.join(ccs_app_config_dir(), "skill-backups")
}

///|
fn ccs_skill_default_repos_json() -> Array[Json] {
  [
    ccs_skill_repo_json("anthropics", "skills", "main", true),
    ccs_skill_repo_json("ComposioHQ", "awesome-claude-skills", "master", true),
    ccs_skill_repo_json("cexll", "myclaude", "master", true),
    ccs_skill_repo_json("JimLiu", "baoyu-skills", "main", true),
  ]
}

///|
fn ccs_skill_repo_json(
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
fn ccs_skill_apps_json(app? : String? = None) -> Json {
  let apps : Map[String, Json] = Map([], capacity=0)
  for name in ccs_skill_supported_apps() {
    apps[name] = Json::boolean(false)
  }
  match app {
    Some(value) => {
      let normalized = ccs_normalize_app_type(value)
      if ccs_skill_supported_apps().contains(normalized) {
        apps[normalized] = Json::boolean(true)
      }
    }
    None => ()
  }
  Json::object(apps)
}

///|
fn ccs_skill_state_default_json() -> Json {
  {
    "installed": Json::array([]),
    "repos": Json::array(ccs_skill_default_repos_json()),
    "backups": Json::array([]),
  }.to_json()
}

///|
async fn ccs_skill_state_load(path? : String = ccs_skill_state_path()) -> Json {
  let content = @fs.read_file(path).text() catch {
    _ => return ccs_skill_state_default_json()
  }
  let parsed = @json.parse(content) catch {
    _ => return ccs_skill_state_default_json()
  }
  guard parsed is Object(obj) else { return ccs_skill_state_default_json() }
  if obj.get("repos") is None {
    obj["repos"] = Json::array(ccs_skill_default_repos_json())
  }
  if obj.get("installed") is None {
    obj["installed"] = Json::array([])
  }
  if obj.get("backups") is None {
    obj["backups"] = Json::array([])
  }
  Json::object(obj)
}

///|
async fn ccs_skill_state_save(
  state : Json,
  path? : String = ccs_skill_state_path(),
) -> Bool {
  ccs_skill_make_directory(@pathx.dirname(path).to_owned()) catch {
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
async fn ccs_skill_make_directory(path : String) -> Unit {
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
async fn ccs_get_skill_repos_json(
  path? : String = ccs_skill_state_path(),
) -> Json {
  guard ccs_skill_state_load(path~) is Object(obj) else {
    return Json::array(ccs_skill_default_repos_json())
  }
  match obj.get("repos") {
    Some(Array(repos)) => Json::array(repos)
    _ => Json::array(ccs_skill_default_repos_json())
  }
}

///|
async fn ccs_get_installed_skills_json(
  path? : String = ccs_skill_state_path(),
) -> Json {
  guard ccs_skill_state_load(path~) is Object(obj) else {
    return Json::array([])
  }
  match obj.get("installed") {
    Some(Array(skills)) => Json::array(skills)
    _ => Json::array([])
  }
}

///|
async fn ccs_get_skill_backups_json(
  path? : String = ccs_skill_state_path(),
) -> Json {
  guard ccs_skill_state_load(path~) is Object(obj) else {
    return Json::array([])
  }
  match obj.get("backups") {
    Some(Array(backups)) => Json::array(backups)
    _ => Json::array([])
  }
}

///|
async fn ccs_add_skill_repo_json(
  repo : Json,
  path? : String = ccs_skill_state_path(),
) -> Json {
  guard ccs_skill_repo_from_json(repo) is Some(normalized) else {
    return Json::boolean(false)
  }
  let state = ccs_skill_state_load(path~)
  guard state is Object(obj) else { return Json::boolean(false) }
  let repos : Array[Json] = match obj.get("repos") {
    Some(Array(items)) => items
    _ => ccs_skill_default_repos_json()
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
  Json::boolean(ccs_skill_state_save(Json::object(obj), path~))
}

///|
async fn ccs_remove_skill_repo_json(
  owner : String,
  name : String,
  path? : String = ccs_skill_state_path(),
) -> Json {
  let state = ccs_skill_state_load(path~)
  guard state is Object(obj) else { return Json::boolean(false) }
  let repos : Array[Json] = match obj.get("repos") {
    Some(Array(items)) => items
    _ => ccs_skill_default_repos_json()
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
  Json::boolean(ccs_skill_state_save(Json::object(obj), path~))
}

///|
fn ccs_skill_repo_from_json(json : Json) -> Json? {
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
    ccs_skill_repo_json(
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
fn ccs_skill_json_from_discoverable(
  skill : Json,
  current_app : String,
  installed_at? : Int = @os.unix_seconds(),
) -> Json? {
  guard skill is Object(obj) else { return None }
  let directory = ccs_skill_install_name(
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
    ccs_installed_skill_json(
      id=key,
      name~,
      description~,
      directory~,
      repo_owner=if repo_owner.is_empty() { None } else { Some(repo_owner) },
      repo_name=if repo_name.is_empty() { None } else { Some(repo_name) },
      repo_branch~,
      readme_url~,
      apps=ccs_skill_apps_json(app=Some(current_app)),
      installed_at~,
      content_hash=None,
      updated_at=0,
    ),
  )
}

///|
fn ccs_skill_request_payload(body : Json?) -> Json? {
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
fn ccs_installed_skill_json(
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
async fn ccs_install_skill_unified_json(
  skill : Json,
  current_app : String,
  state_path? : String = ccs_skill_state_path(),
) -> Json {
  guard ccs_skill_json_from_discoverable(skill, current_app) is Some(installed) else {
    return Json::null()
  }
  ccs_upsert_installed_skill_json(installed, state_path~)
}

///|
async fn ccs_upsert_installed_skill_json(
  installed : Json,
  state_path? : String = ccs_skill_state_path(),
) -> Json {
  let state = ccs_skill_state_load(path=state_path)
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
      next.push(ccs_merge_installed_skill_apps(item, installed))
      replaced = true
    } else {
      next.push(item)
    }
  }
  if !replaced {
    next.push(installed)
  }
  obj["installed"] = Json::array(next)
  ignore(ccs_skill_state_save(Json::object(obj), path=state_path))
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
fn ccs_merge_installed_skill_apps(old : Json, incoming : Json) -> Json {
  guard old is Object(old_obj) else { return incoming }
  guard incoming is Object(new_obj) else { return old }
  let apps = ccs_merge_skill_apps_json(old_obj.get("apps"), new_obj.get("apps"))
  for key, value in new_obj {
    old_obj[key] = value
  }
  old_obj["apps"] = apps
  Json::object(old_obj)
}

///|
fn ccs_merge_skill_apps_json(old : Json?, incoming : Json?) -> Json {
  let merged : Map[String, Json] = Map([], capacity=0)
  for name in ccs_skill_supported_apps() {
    let enabled = ccs_skill_app_enabled_json(old, name) ||
      ccs_skill_app_enabled_json(incoming, name)
    merged[name] = Json::boolean(enabled)
  }
  Json::object(merged)
}

///|
fn ccs_skill_app_enabled_json(apps : Json?, app : String) -> Bool {
  match apps {
    Some(Object(obj)) =>
      match obj.get(ccs_normalize_app_type(app)) {
        Some(True) => true
        _ => false
      }
    _ => false
  }
}

///|
async fn ccs_toggle_skill_app_json(
  id : String,
  app : String,
  enabled : Bool,
  state_path? : String = ccs_skill_state_path(),
) -> Json {
  let normalized = ccs_normalize_app_type(app)
  if !ccs_skill_supported_apps().contains(normalized) {
    return Json::boolean(false)
  }
  let state = ccs_skill_state_load(path=state_path)
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
      let apps = ccs_skill_apps_with_enabled(
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
    changed && ccs_skill_state_save(Json::object(obj), path=state_path),
  )
}

///|
fn ccs_skill_apps_with_enabled(
  apps : Json?,
  app : String,
  enabled : Bool,
) -> Json {
  let obj : Map[String, Json] = Map([], capacity=0)
  for name in ccs_skill_supported_apps() {
    obj[name] = Json::boolean(ccs_skill_app_enabled_json(apps, name))
  }
  obj[app] = Json::boolean(enabled)
  Json::object(obj)
}

///|
async fn ccs_uninstall_skill_unified_json(
  id : String,
  state_path? : String = ccs_skill_state_path(),
) -> Json {
  let state = ccs_skill_state_load(path=state_path)
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
      let entry = ccs_skill_backup_entry_json(skill)
      obj["backups"] = ccs_skill_prepend_backup(obj.get("backups"), entry)
      match entry {
        Object(entry_obj) => store_json_optional_string(entry_obj, "backupPath")
        _ => None
      }
    }
    None => None
  }
  ignore(ccs_skill_state_save(Json::object(obj), path=state_path))
  {
    "backupPath": match backup_path {
      Some(path) => Json::string(path)
      None => Json::null()
    },
  }.to_json()
}

///|
fn ccs_skill_backup_entry_json(skill : Json) -> Json {
  let now = @os.unix_seconds()
  let directory = match skill {
    Object(obj) => store_json_string_or_default(obj, "directory", "skill")
    _ => "skill"
  }
  let backup_id = "\{directory}-\{now}"
  {
    "backupId": Json::string(backup_id),
    "backupPath": Json::string(@pathx.join(ccs_skill_backup_dir(), backup_id)),
    "createdAt": Json::number(now.to_double()),
    "skill": skill,
  }.to_json()
}

///|
fn ccs_skill_prepend_backup(existing : Json?, entry : Json) -> Json {
  let backups : Array[Json] = [entry]
  match existing {
    Some(Array(items)) =>
      for item in items {
        if backups.length() < CCS_SKILLS_BACKUP_RETAIN_COUNT {
          backups.push(item)
        }
      }
    _ => ()
  }
  Json::array(backups)
}

///|
async fn ccs_delete_skill_backup_json(
  backup_id : String,
  state_path? : String = ccs_skill_state_path(),
) -> Json {
  let state = ccs_skill_state_load(path=state_path)
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
    removed && ccs_skill_state_save(Json::object(obj), path=state_path),
  )
}

///|
async fn ccs_restore_skill_backup_json(
  backup_id : String,
  current_app : String,
  state_path? : String = ccs_skill_state_path(),
) -> Json {
  let backups = ccs_get_skill_backups_json(path=state_path)
  guard backups is Array(items) else { return Json::null() }
  for item in items {
    guard item is Object(item_obj) else { continue }
    if store_json_string_or_default(item_obj, "backupId", "") == backup_id {
      guard item_obj.get("skill") is Some(Object(skill_obj)) else {
        return Json::null()
      }
      skill_obj["apps"] = ccs_skill_apps_with_enabled(
        skill_obj.get("apps"),
        ccs_normalize_app_type(current_app),
        true,
      )
      return ccs_upsert_installed_skill_json(
        Json::object(skill_obj),
        state_path~,
      )
    }
  }
  Json::null()
}

///|
fn ccs_check_skill_updates_json() -> Json {
  Json::array([])
}

///|
async fn ccs_update_skill_json(
  id : String,
  state_path? : String = ccs_skill_state_path(),
) -> Json {
  let installed = ccs_get_installed_skills_json(path=state_path)
  guard installed is Array(items) else { return Json::null() }
  for item in items {
    guard item is Object(obj) else { continue }
    if store_json_string_or_default(obj, "id", "") == id ||
      store_json_string_or_default(obj, "directory", "") == id {
      obj["updatedAt"] = Json::number(@os.unix_seconds().to_double())
      return ccs_upsert_installed_skill_json(Json::object(obj), state_path~)
    }
  }
  Json::null()
}

///|
fn ccs_migrate_skill_storage_json() -> Json {
  {
    "migratedCount": Json::number(0.0),
    "skippedCount": Json::number(0.0),
    "errors": Json::array([]),
  }.to_json()
}

///|
fn ccs_search_skills_sh_json(query : String, limit : Int, offset : Int) -> Json {
  ignore(offset)
  let skills : Array[Json] = []
  if query.trim().length() >= 2 {
    for repo in ccs_skill_default_repos_json() {
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
async fn ccs_discover_available_skills_json(
  state_path? : String = ccs_skill_state_path(),
) -> Json {
  let repos = ccs_get_skill_repos_json(path=state_path)
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
async fn ccs_get_skills_json(
  state_path? : String = ccs_skill_state_path(),
) -> Json {
  let installed = ccs_get_installed_skills_json(path=state_path)
  let installed_dirs : Array[String] = []
  if installed is Array(items) {
    for item in items {
      guard item is Object(obj) else { continue }
      installed_dirs.push(store_json_string_or_default(obj, "directory", ""))
    }
  }
  let discovered = ccs_discover_available_skills_json(state_path~)
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
async fn ccs_scan_unmanaged_skills_json() -> Json {
  let result : Array[Json] = []
  for app in ccs_skill_supported_apps() {
    let dir = ccs_app_skills_dir(app)
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
      let (skill_name, description) = ccs_skill_metadata_from_file(skill_file)
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
async fn ccs_import_skills_from_apps_json(
  imports : Json,
  state_path? : String = ccs_skill_state_path(),
) -> Json {
  let imported : Array[Json] = []
  guard imports is Array(items) else { return Json::array(imported) }
  for item in items {
    guard item is Object(obj) else { continue }
    let directory = ccs_skill_install_name(
      store_json_string_or_default(obj, "directory", ""),
    )
    if directory.is_empty() {
      continue
    }
    let apps = match obj.get("apps") {
      Some(apps) => apps
      None => ccs_skill_apps_json()
    }
    let skill = ccs_installed_skill_json(
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
    imported.push(ccs_upsert_installed_skill_json(skill, state_path~))
  }
  Json::array(imported)
}

///|
async fn ccs_install_skills_from_zip_json(
  file_path : String,
  current_app : String,
  state_path? : String = ccs_skill_state_path(),
) -> Json {
  // MoonBit has no zip dependency here yet. For standalone parity we accept an
  // already-extracted skill directory and return an empty install list otherwise.
  if !@fs.exists(file_path) {
    return Json::array([])
  }
  let directory = ccs_skill_install_name(@pathx.basename(file_path).to_owned())
  if directory.is_empty() {
    return Json::array([])
  }
  let (name, description) = ccs_skill_metadata_from_file(
    @pathx.join(file_path, "SKILL.md"),
  )
  let skill = {
    "key": Json::string("local:\{directory}"),
    "name": Json::string(name.unwrap_or(directory)),
    "description": match description {
      Some(value) => Json::string(value)
      None => Json::string("")
    },
    "directory": Json::string(directory),
  }.to_json()
  Json::array([ccs_install_skill_unified_json(skill, current_app, state_path~)])
}

///|
async fn ccs_skill_metadata_from_file(path : String) -> (String?, String?) {
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
      name = Some(ccs_yaml_scalar(line[5:]))
    } else if line.has_prefix("description:") {
      description = Some(ccs_yaml_scalar(line[12:]))
    }
  }
  (name, description)
}

///|
fn ccs_yaml_scalar(value : StringView) -> String {
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
fn ccs_skill_install_name(directory : String) -> String {
  let normalized = directory.replace(old="\\", new="/").trim().to_owned()
  let base = @pathx.basename(normalized).to_owned().trim().to_owned()
  if base == "." || base == ".." || base.contains("/") {
    ""
  } else {
    base
  }
}

///|
fn ccs_app_skills_dir(app : String) -> String {
  @pathx.join(ccs_config_dir(app), "skills")
}
