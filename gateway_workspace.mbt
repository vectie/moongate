///|
fn moon_allowed_workspace_files() -> Array[String] {
  [
    "AGENTS.md", "SOUL.md", "USER.md", "IDENTITY.md", "TOOLS.md", "MEMORY.md", "HEARTBEAT.md",
    "BOOTSTRAP.md", "BOOT.md",
  ]
}

///|
fn moon_validate_workspace_filename(filename : String) -> Bool {
  moon_allowed_workspace_files().contains(filename)
}

///|
fn moon_validate_daily_memory_filename(filename : String) -> Bool {
  filename.length() == 13 &&
  filename.has_suffix(".md") &&
  moon_ascii_digit_at(filename, 0) &&
  moon_ascii_digit_at(filename, 1) &&
  moon_ascii_digit_at(filename, 2) &&
  moon_ascii_digit_at(filename, 3) &&
  filename[4] == '-' &&
  moon_ascii_digit_at(filename, 5) &&
  moon_ascii_digit_at(filename, 6) &&
  filename[7] == '-' &&
  moon_ascii_digit_at(filename, 8) &&
  moon_ascii_digit_at(filename, 9) &&
  filename[10] == '.'
}

///|
fn moon_daily_memory_list_filename(filename : String) -> Bool {
  filename.has_suffix(".md")
}

///|
fn moon_daily_memory_date(filename : String) -> String {
  if filename.has_suffix(".md") && filename.length() >= 3 {
    filename[:filename.length() - 3].to_owned()
  } else if filename.length() >= 10 {
    filename[:10].to_owned()
  } else {
    filename
  }
}

///|
fn moonstat_workspace_root_dir() -> String {
  @pathx.join(@pathx.join(moon_home_dir(), ".moonsuite"), "moonstat")
}

///|
fn moonstat_workspace_dir() -> String {
  @pathx.join(moonstat_workspace_root_dir(), "workspace")
}

///|
fn moonstat_memory_dir() -> String {
  @pathx.join(moonstat_workspace_root_dir(), "memory")
}

///|
fn moon_workspace_file_path(filename : String) -> String {
  @pathx.join(moonstat_workspace_dir(), filename)
}

///|
fn moon_daily_memory_file_path(filename : String) -> String {
  @pathx.join(moonstat_memory_dir(), filename)
}

///|
fn moon_file_mtime(path : String) -> Int64 {
  let stat = @fsx.stat(path) catch { _ => return 0L }
  stat.mtime()
}

///|
async fn moon_daily_memory_info_json(path : String, filename : String) -> Json {
  let content = @fsx.read_file(path) catch { _ => "" }
  let modified_at = moon_file_mtime(path)
  {
    "filename": Json::string(filename),
    "date": Json::string(moon_daily_memory_date(filename)),
    "sizeBytes": Json::number(content.length().to_double()),
    "modifiedAt": Json::number(modified_at.to_double()),
    "preview": Json::string(moon_preview(content, 200)),
  }.to_json()
}

///|
async fn moon_list_daily_memory_files_json() -> Json {
  let memory_dir = moonstat_memory_dir()
  if !@fsx.exists(memory_dir) {
    return Json::array([])
  }
  let filenames : Array[String] = []
  let rows_by_filename : Map[String, Json] = {}
  let rows : Array[Json] = []
  let entries = @fsx.list_directory(memory_dir) catch {
    _ => return Json::array([])
  }
  for entry in entries {
    if entry.kind is Regular && moon_daily_memory_list_filename(entry.name) {
      filenames.push(entry.name)
      rows_by_filename[entry.name] = moon_daily_memory_info_json(
        entry.path,
        entry.name,
      )
    }
  }
  filenames.sort()
  let mut index = filenames.length() - 1
  while index >= 0 {
    guard rows_by_filename.get(filenames[index]) is Some(row) else {
      index = index - 1
      continue
    }
    rows.push(row)
    index = index - 1
  }
  Json::array(rows)
}

///|
async fn moon_search_daily_memory_files_json(query : String) -> Json {
  let trimmed = query.trim().to_owned()
  let memory_dir = moonstat_memory_dir()
  if trimmed.is_empty() || !@fsx.exists(memory_dir) {
    return Json::array([])
  }
  let filenames : Array[String] = []
  let rows_by_filename : Map[String, Json] = {}
  let rows : Array[Json] = []
  let entries = @fsx.list_directory(memory_dir) catch {
    _ => return Json::array([])
  }
  for entry in entries {
    if !(entry.kind is Regular) || !moon_daily_memory_list_filename(entry.name) {
      continue
    }
    let content = @fsx.read_file(entry.path) catch { _ => "" }
    let date = moon_daily_memory_date(entry.name)
    let (content_count, first_pos) = moon_count_case_insensitive_matches(
      content, trimmed,
    )
    let (date_count, _) = moon_count_case_insensitive_matches(date, trimmed)
    if content_count == 0 && date_count == 0 {
      continue
    }
    let snippet = match first_pos {
      Some(pos) => moon_search_snippet(content, pos)
      None => moon_preview(content, 120)
    }
    let modified_at = moon_file_mtime(entry.path)
    filenames.push(entry.name)
    rows_by_filename[entry.name] = {
      "filename": Json::string(entry.name),
      "date": Json::string(date),
      "sizeBytes": Json::number(content.length().to_double()),
      "modifiedAt": Json::number(modified_at.to_double()),
      "snippet": Json::string(snippet),
      "matchCount": Json::number((content_count + date_count).to_double()),
    }.to_json()
  }
  filenames.sort()
  let mut index = filenames.length() - 1
  while index >= 0 {
    guard rows_by_filename.get(filenames[index]) is Some(row) else {
      index = index - 1
      continue
    }
    rows.push(row)
    index = index - 1
  }
  Json::array(rows)
}

///|
async fn moon_env_conflicts_json_with_shell_files(
  app : String,
  shell_files : Array[String],
) -> Json {
  let conflicts : Array[Json] = []
  for key in moon_env_conflict_keys(moon_normalize_app_type(app)) {
    match getenv_or_none(key) {
      Some(value) if !value.trim().is_empty() =>
        conflicts.push(
          {
            "varName": Json::string(key),
            "varValue": Json::string(value),
            "sourceType": Json::string("system"),
            "sourcePath": Json::string("Process Environment"),
          }.to_json(),
        )
      _ => ()
    }
  }
  for file_path in shell_files {
    moon_push_shell_env_conflicts(
      conflicts,
      file_path,
      moon_env_conflict_keys(moon_normalize_app_type(app)),
    )
  }
  Json::array(conflicts)
}

///|
fn moon_env_source_file_path(source_path : String) -> String {
  match source_path.find(":") {
    Some(index) => source_path[:index].to_owned()
    None => source_path
  }
}

///|
async fn moon_import_mcp_from_codex_file(
  servers : Map[String, Json],
  file_path : String,
) -> Int {
  if !(@fsx.exists_as_file(file_path) catch { _ => false }) {
    return 0
  }
  let content = @fsx.read_file(file_path) catch { _ => return 0 }
  moon_import_mcp_from_codex_toml_text(servers, content)
}

///|
async fn moon_import_mcp_from_file(
  servers : Map[String, Json],
  app : String,
  file_path : String,
) -> Int {
  if !(@fsx.exists_as_file(file_path) catch { _ => false }) {
    return 0
  }
  let content = @fsx.read_file(file_path) catch { _ => return 0 }
  let root = @json.parse(content) catch { _ => return 0 }
  moon_import_mcp_from_root_json(servers, app, root)
}

///|
fn moon_prompt_file_path(app : String) -> Result[String, String] {
  let normalized = moon_normalize_app_type(app)
  if normalized == "claude-desktop" {
    return Err("Claude Desktop 暂不支持 Prompts")
  }
  let filename = match normalized {
    "claude" => "CLAUDE.md"
    "gemini" => "GEMINI.md"
    "codex" | "opencode" | "openclaw" | "hermes" | "omo" | "omo-slim" =>
      "AGENTS.md"
    _ => "CLAUDE.md"
  }
  Ok(@pathx.join(moon_config_dir(normalized), filename))
}

///|
fn moon_prompt_file_path_from_request(
  path : StringView,
  body : Json?,
  app : String,
) -> Result[String, String] {
  match proxy_string_request(path, body, "filePath") {
    Some(file_path) => Ok(file_path)
    None => moon_prompt_file_path(app)
  }
}

///|
async fn moon_import_prompt_from_file_json(
  prompts : Map[String, Json],
  app : String,
  file_path : String,
) -> Result[Json, String] {
  if !(@fsx.exists_as_file(file_path) catch { _ => false }) {
    return Err("提示词文件不存在")
  }
  let content = @fsx.read_file(file_path) catch {
    error => return Err("读取提示词文件失败: \{error}")
  }
  let timestamp = @async.now().to_int()
  let timestamp_text = timestamp.to_string()
  let id = "imported-\{timestamp_text}"
  let prompt = {
    "id": Json::string(id),
    "name": Json::string(
      "导入的提示词 \{@os.local_rfc3339(timestamp.to_int64())}",
    ),
    "content": Json::string(content),
    "description": Json::string("从现有配置文件导入"),
    "enabled": Json::boolean(false),
    "createdAt": Json::string(timestamp_text),
    "updatedAt": Json::string(timestamp_text),
  }.to_json()
  prompts[moon_prompt_store_key(app, id)] = prompt
  Ok(Json::string(id))
}

///|
async fn moon_current_prompt_file_content_json(
  file_path : String,
) -> Result[Json, String] {
  if !(@fsx.exists_as_file(file_path) catch { _ => false }) {
    return Ok(Json::null())
  }
  let content = @fsx.read_file(file_path) catch {
    error => return Err("读取提示词文件失败: \{error}")
  }
  Ok(Json::string(content))
}

///|
async fn WorkspaceService::handle_save_file_dialog(
  self : WorkspaceService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  ignore(proxy_string_request(r.path, body, "defaultName"))
  write_usage_json(w, moon_dialog_result_json())
}

///|
async fn WorkspaceService::handle_read_omo_local_file(
  self : WorkspaceService,
  w : @httpx.ResponseWriter,
  slim~ : Bool,
) -> Unit {
  ignore(self)
  let (data, error) = moon_read_omo_local_file_json(slim)
  match data {
    Some(data) => write_usage_json(w, data)
    None =>
      write_usage_bad_request(w, error.unwrap_or("OMO 配置文件不存在"))
  }
}

///|
async fn WorkspaceService::handle_open_file_dialog(
  self : WorkspaceService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_dialog_result_json())
}

///|
async fn WorkspaceService::handle_open_zip_file_dialog(
  self : WorkspaceService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_dialog_result_json())
}

///|
async fn WorkspaceService::handle_import_prompt_from_file(
  self : WorkspaceService,
  config : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  match moon_prompt_file_path_from_request(r.path, body, app) {
    Ok(file_path) =>
      match moon_import_prompt_from_file_json(config.prompts, app, file_path) {
        Ok(result) => write_usage_json(w, result)
        Err(error) => write_usage_bad_request(w, error)
      }
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn WorkspaceService::handle_get_current_prompt_file_content(
  self : WorkspaceService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  match moon_prompt_file_path_from_request(r.path, body, app) {
    Ok(file_path) =>
      match moon_current_prompt_file_content_json(file_path) {
        Ok(result) => write_usage_json(w, result)
        Err(error) => write_usage_bad_request(w, error)
      }
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn WorkspaceService::handle_list_daily_memory_files(
  self : WorkspaceService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_list_daily_memory_files_json())
}

///|
async fn WorkspaceService::handle_read_daily_memory_file(
  self : WorkspaceService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "filename") is Some(filename) &&
    moon_validate_daily_memory_filename(filename) else {
    write_usage_bad_request(w, "invalid_daily_memory_filename")
    return
  }
  let path = moon_daily_memory_file_path(filename)
  if !@fsx.exists_as_file(path) {
    write_usage_json(w, Json::null())
    return
  }
  let content = @fsx.read_file(path) catch {
    _ => {
      write_usage_bad_request(w, "daily_memory_read_failed")
      return
    }
  }
  write_usage_json(w, Json::string(content))
}

///|
async fn WorkspaceService::handle_write_daily_memory_file(
  self : WorkspaceService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "filename") is Some(filename) &&
    moon_validate_daily_memory_filename(filename) else {
    write_usage_bad_request(w, "invalid_daily_memory_filename")
    return
  }
  let content = proxy_string_request(r.path, body, "content").unwrap_or("")
  if !moon_ensure_directory(moonstat_memory_dir()) {
    write_usage_bad_request(w, "daily_memory_directory_failed")
    return
  }
  @fsx.write_to_file(moon_daily_memory_file_path(filename), content) catch {
    _ => {
      write_usage_bad_request(w, "daily_memory_write_failed")
      return
    }
  }
  write_usage_json(w, Json::null())
}

///|
async fn WorkspaceService::handle_search_daily_memory_files(
  self : WorkspaceService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let query = proxy_string_request(r.path, body, "query").unwrap_or("")
  write_usage_json(w, moon_search_daily_memory_files_json(query))
}

///|
async fn WorkspaceService::handle_delete_daily_memory_file(
  self : WorkspaceService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "filename") is Some(filename) &&
    moon_validate_daily_memory_filename(filename) else {
    write_usage_bad_request(w, "invalid_daily_memory_filename")
    return
  }
  let path = moon_daily_memory_file_path(filename)
  if @fsx.exists_as_file(path) {
    @fsx.remove(path) catch {
      _ => {
        write_usage_bad_request(w, "daily_memory_delete_failed")
        return
      }
    }
  }
  write_usage_json(w, Json::null())
}

///|
async fn WorkspaceService::handle_read_workspace_file(
  self : WorkspaceService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "filename") is Some(filename) &&
    moon_validate_workspace_filename(filename) else {
    write_usage_bad_request(w, "invalid_workspace_filename")
    return
  }
  let path = moon_workspace_file_path(filename)
  if !@fsx.exists_as_file(path) {
    write_usage_json(w, Json::null())
    return
  }
  let content = @fsx.read_file(path) catch {
    _ => {
      write_usage_bad_request(w, "workspace_file_read_failed")
      return
    }
  }
  write_usage_json(w, Json::string(content))
}

///|
async fn WorkspaceService::handle_write_workspace_file(
  self : WorkspaceService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "filename") is Some(filename) &&
    moon_validate_workspace_filename(filename) else {
    write_usage_bad_request(w, "invalid_workspace_filename")
    return
  }
  let content = proxy_string_request(r.path, body, "content").unwrap_or("")
  if !moon_ensure_directory(moonstat_workspace_dir()) {
    write_usage_bad_request(w, "workspace_directory_failed")
    return
  }
  @fsx.write_to_file(moon_workspace_file_path(filename), content) catch {
    _ => {
      write_usage_bad_request(w, "workspace_file_write_failed")
      return
    }
  }
  write_usage_json(w, Json::null())
}

///|
async fn WorkspaceService::handle_open_workspace_directory(
  self : WorkspaceService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let subdir = proxy_string_request(r.path, body, "subdir").unwrap_or(
    "workspace",
  )
  let target = if subdir == "memory" {
    moonstat_memory_dir()
  } else {
    moonstat_workspace_dir()
  }
  if !moon_ensure_directory(target) {
    write_usage_bad_request(w, "workspace_directory_failed")
    return
  }
  write_usage_json(w, Json::boolean(true))
}

///|
async fn WorkspaceService::write_static_file(
  self : WorkspaceService,
  logger : @pino.Logger,
  w : @httpx.ResponseWriter,
  path : String,
  content_type : String,
) -> Unit {
  ignore(self)
  let result : Result[String, Error] = moon_async_result(() => {
    @fsx.read_file(path)
  })
  match result {
    Ok(content) => {
      w.header().set("Content-Type", content_type)
      w.write_header(@status.Ok)
      w.write(content)
    }
    Err(error) => {
      logger.error("Failed to serve static file \{path}: \{error}")
      w.header().set("Content-Type", "text/plain; charset=utf-8")
      w.write_header(@status.NotFound)
      w.write("Not Found")
    }
  }
  w.flush()
}

///|
async fn WorkspaceService::handle_register_page(
  self : WorkspaceService,
  logger : @pino.Logger,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.write_static_file(
    logger, w, "public/participant-register.html", "text/html; charset=utf-8",
  )
}
