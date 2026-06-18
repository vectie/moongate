///|
const CLAUDE_SESSION_REQUEST_ID_PREFIX : String = "session:"

///|
const SESSION_PROXY_DEDUP_WINDOW_SECONDS : Int = 600

///|
priv struct SessionSyncResult {
  mut imported : Int
  mut skipped : Int
  mut files_scanned : Int
  errors : Array[String]
}

///|
priv struct SessionFileSyncState {
  last_modified : Int64
  last_line_offset : Int
}

///|
priv struct ParsedClaudeSessionUsage {
  message_id : String
  model : String
  usage : TokenUsage
  stop_reason : String?
  timestamp : String?
  session_id : String?
}

///|
priv struct CumulativeSessionTokens {
  input : Int
  cached_input : Int
  output : Int
}

///|
priv struct DeltaSessionTokens {
  input : Int
  cached_input : Int
  output : Int
}

///|
priv struct CodexFileParseState {
  mut session_id : String?
  mut current_model : String
  mut prev_total : CumulativeSessionTokens?
  mut event_index : Int
}

///|
priv struct GeminiSessionTokens {
  input : Int
  output : Int
  cached : Int
  thoughts : Int
}

///|
priv struct OpenCodeMessageData {
  input_tokens : Int
  output_tokens : Int
  reasoning_tokens : Int
  cache_read_tokens : Int
  cache_write_tokens : Int
  cost_usd : String
  model_id : String
  timestamp_ms : Int64
}

///|
fn SessionSyncResult::new() -> SessionSyncResult {
  { imported: 0, skipped: 0, files_scanned: 0, errors: [] }
}

///|
fn SessionSyncResult::to_json(self : SessionSyncResult) -> Json {
  {
    "imported": Json::number(self.imported.to_double()),
    "skipped": Json::number(self.skipped.to_double()),
    "filesScanned": Json::number(self.files_scanned.to_double()),
    "errors": Json::array(self.errors.map(fn(error) { Json::string(error) })),
  }.to_json()
}

///|
fn SessionFileSyncState::new(
  last_modified~ : Int64,
  last_line_offset~ : Int,
) -> SessionFileSyncState {
  { last_modified, last_line_offset }
}

///|
pub fn default_claude_projects_dir() -> String {
  let home = @os.home() catch { _ => "" }
  if home.is_empty() {
    ".claude/projects"
  } else {
    @pathx.join(home, ".claude/projects")
  }
}

///|
pub fn default_codex_config_dir() -> String {
  let home = @os.home() catch { _ => "" }
  if home.is_empty() {
    ".codex"
  } else {
    @pathx.join(home, ".codex")
  }
}

///|
pub fn default_gemini_dir() -> String {
  let home = @os.home() catch { _ => "" }
  if home.is_empty() {
    ".gemini"
  } else {
    @pathx.join(home, ".gemini")
  }
}

///|
pub fn default_opencode_dir() -> String {
  default_opencode_data_dir()
}

///|
pub fn default_opencode_data_dir() -> String {
  match getenv_non_empty("XDG_DATA_HOME") {
    Some(xdg_data) => return @pathx.join(xdg_data, "opencode")
    None => ()
  }
  let home = @os.home() catch { _ => "" }
  if home.is_empty() {
    ".local/share/opencode"
  } else {
    @pathx.join(home, ".local/share/opencode")
  }
}

///|
pub fn default_opencode_export_path() -> String {
  @pathx.join(default_opencode_dir(), "opencode.messages.jsonl")
}

///|
pub fn default_opencode_db_path() -> String {
  match getenv_non_empty("OPENCODE_DB") {
    Some(path) =>
      if @pathx.is_absolute(path) {
        path
      } else {
        @pathx.join(default_opencode_data_dir(), path)
      }
    None => @pathx.join(default_opencode_data_dir(), "opencode.db")
  }
}

///|
async fn TrafficStats::sync_session_logs(
  self : TrafficStats,
  claude_projects_dir? : String = default_claude_projects_dir(),
  codex_dir? : String = default_codex_config_dir(),
  gemini_dir? : String = default_gemini_dir(),
  opencode_db_path? : String = default_opencode_db_path(),
  opencode_export_path? : String = default_opencode_export_path(),
) -> SessionSyncResult {
  let result = self.sync_claude_session_logs(projects_dir=claude_projects_dir)
  let codex_result = self.sync_codex_session_logs(codex_dir~)
  result.imported += codex_result.imported
  result.skipped += codex_result.skipped
  result.files_scanned += codex_result.files_scanned
  result.errors.append(codex_result.errors)
  let gemini_result = self.sync_gemini_session_logs(gemini_dir~)
  result.imported += gemini_result.imported
  result.skipped += gemini_result.skipped
  result.files_scanned += gemini_result.files_scanned
  result.errors.append(gemini_result.errors)
  let opencode_db_result = self.sync_opencode_session_database(
    db_path=opencode_db_path,
  )
  result.imported += opencode_db_result.imported
  result.skipped += opencode_db_result.skipped
  result.files_scanned += opencode_db_result.files_scanned
  result.errors.append(opencode_db_result.errors)
  let opencode_result = self.sync_opencode_session_export(
    export_path=opencode_export_path,
  )
  result.imported += opencode_result.imported
  result.skipped += opencode_result.skipped
  result.files_scanned += opencode_result.files_scanned
  result.errors.append(opencode_result.errors)
  result
}

///|
#warnings("-unused_value")
fn TrafficStats::ingest_opencode_message_json(
  self : TrafficStats,
  session_id~ : String,
  message_id~ : String,
  data~ : String,
) -> SessionSyncResult {
  let result = SessionSyncResult::new()
  result.files_scanned = 1
  let parsed = @json.parse(data) catch {
    error => {
      result.errors.push("OpenCode message JSON parse failed: \{error}")
      return result
    }
  }
  guard parsed is Object(root) else {
    result.skipped += 1
    return result
  }
  self.ingest_opencode_message_object(session_id~, message_id~, root, result)
  result
}

///|
async fn TrafficStats::sync_opencode_session_database(
  self : TrafficStats,
  db_path? : String = default_opencode_db_path(),
) -> SessionSyncResult {
  let result = SessionSyncResult::new()
  if !@fsx.exists_as_file(db_path) {
    return result
  }
  result.files_scanned = 1
  try {
    let modified = opencode_database_modified(db_path)
    let existing_state = self.session_sync_state.get(db_path)
    if existing_state is Some(state) && modified <= state.last_modified {
      return result
    }
    let process = @spawn.spawn(
      "sqlite3",
      ["-readonly", "-json", db_path, OPENCODE_SQLITE_USAGE_QUERY],
      timeout=10000,
    )
    if process.status != 0 {
      result.errors.push(
        "OpenCode SQLite query failed \{db_path}: \{process.stderr.trim()}",
      )
      return result
    }
    self.ingest_opencode_database_rows_json(
      db_path~,
      content=process.stdout,
      last_modified=modified,
    )
  } catch {
    error => {
      result.errors.push("OpenCode SQLite sync failed \{db_path}: \{error}")
      result
    }
  }
}

///|
const OPENCODE_SQLITE_USAGE_QUERY : String =
  #|WITH session_watermark AS (
  #|  SELECT
  #|    s.id AS session_id,
  #|    MAX(s.time_updated, COALESCE(MAX(m.time_updated), s.time_updated)) AS sync_watermark
  #|  FROM session s
  #|  LEFT JOIN message m ON m.session_id = s.id
  #|  GROUP BY s.id
  #|)
  #|SELECT
  #|  sw.session_id AS session_id,
  #|  sw.sync_watermark AS sync_watermark,
  #|  m.id AS message_id,
  #|  m.data AS data
  #|FROM session_watermark sw
  #|LEFT JOIN message m ON m.session_id = sw.session_id
  #|ORDER BY sw.sync_watermark, m.time_created;

///|
fn TrafficStats::ingest_opencode_database_rows_json(
  self : TrafficStats,
  db_path~ : String,
  content~ : String,
  last_modified~ : Int64,
) -> SessionSyncResult {
  let result = SessionSyncResult::new()
  result.files_scanned = 1
  let existing_state = self.session_sync_state.get(db_path)
  if existing_state is Some(state) && last_modified <= state.last_modified {
    return result
  }
  let parsed = @json.parse(content) catch {
    error => {
      result.errors.push("OpenCode SQLite JSON parse failed: \{error}")
      return result
    }
  }
  guard parsed is Array(rows) else {
    result.errors.push("OpenCode SQLite JSON output was not an array")
    return result
  }
  let seen_sessions : Array[String] = []
  let session_watermarks : Map[String, Int64] = Map([], capacity=0)
  let session_incomplete : Map[String, Bool] = Map([], capacity=0)
  let session_errors : Map[String, Bool] = Map([], capacity=0)
  let mut has_sync_errors = false
  for row_json in rows {
    guard row_json is Object(row) else { continue }
    guard session_map_string(row, "session_id") is Some(session_id) else {
      continue
    }
    let watermark = json_int64_or_zero(row, "sync_watermark")
    if !session_watermarks.contains(session_id) {
      seen_sessions.push(session_id)
      session_watermarks.set(session_id, watermark)
    } else if watermark > session_watermarks.get(session_id).unwrap_or(0L) {
      session_watermarks.set(session_id, watermark)
    }
    let sync_key = "\{db_path}:\{session_id}"
    match self.session_sync_state.get(sync_key) {
      Some(state) if watermark <= state.last_modified => continue
      _ => ()
    }
    guard session_map_string(row, "message_id") is Some(message_id) else {
      continue
    }
    guard session_map_string(row, "data") is Some(data_text) else { continue }
    let data_json = @json.parse(data_text) catch {
      error => {
        result.errors.push(
          "OpenCode DB message parse failed \{session_id}/\{message_id}: \{error}",
        )
        session_errors.set(session_id, true)
        has_sync_errors = true
        continue
      }
    }
    guard data_json is Object(data_obj) else { continue }
    if opencode_message_has_incomplete_usage(data_obj) {
      session_incomplete.set(session_id, true)
      continue
    }
    match parse_opencode_message_data(data_obj, require_completed=true) {
      Some(message) => {
        let request_id = "opencode_session:\{session_id}:\{message_id}"
        let output_tokens = message.output_tokens + message.reasoning_tokens
        let usage = TokenUsage::new(
          input_tokens=message.input_tokens,
          output_tokens~,
          cache_read_tokens=message.cache_read_tokens,
          cache_creation_tokens=message.cache_write_tokens,
          model=Some(message.model_id),
        )
        if self.should_skip_session_insert(
            request_id,
            app_type="opencode",
            model=message.model_id,
            usage~,
            created_at=opencode_timestamp_seconds(message.timestamp_ms),
            allow_missing_cache_creation=true,
          ) {
          result.skipped += 1
        } else {
          self.record_opencode_session_usage(request_id, message, session_id)
          result.imported += 1
        }
      }
      None => ()
    }
  }
  for session_id in seen_sessions {
    if session_errors.get(session_id).unwrap_or(false) ||
      session_incomplete.get(session_id).unwrap_or(false) {
      continue
    }
    let sync_key = "\{db_path}:\{session_id}"
    let watermark = session_watermarks.get(session_id).unwrap_or(0L)
    self.session_sync_state.set(
      sync_key,
      SessionFileSyncState::new(last_modified=watermark, last_line_offset=0),
    )
  }
  if !has_sync_errors {
    self.session_sync_state.set(
      db_path,
      SessionFileSyncState::new(last_modified~, last_line_offset=0),
    )
  }
  result
}

///|
async fn TrafficStats::sync_opencode_session_export(
  self : TrafficStats,
  export_path? : String = default_opencode_export_path(),
) -> SessionSyncResult {
  let result = SessionSyncResult::new()
  if !@fsx.exists_as_file(export_path) {
    return result
  }
  try {
    let stat = @fsx.stat(export_path)
    let content = @fsx.read_file(export_path)
    self.ingest_opencode_session_export_jsonl(
      file_path=export_path,
      content~,
      last_modified=stat.mtime(),
    )
  } catch {
    error => {
      result.files_scanned = 1
      result.errors.push(
        "OpenCode session export failed \{export_path}: \{error}",
      )
      result
    }
  }
}

///|
fn TrafficStats::ingest_opencode_session_export_jsonl(
  self : TrafficStats,
  file_path~ : String,
  content~ : String,
  last_modified~ : Int64,
) -> SessionSyncResult {
  let result = SessionSyncResult::new()
  result.files_scanned = 1
  let existing_state = self.session_sync_state.get(file_path)
  if existing_state is Some(state) && last_modified <= state.last_modified {
    return result
  }
  let last_offset = match existing_state {
    Some(state) => state.last_line_offset
    None => 0
  }
  let mut line_offset = 0
  for line_view in content.split("\n") {
    line_offset += 1
    if line_offset <= last_offset {
      continue
    }
    let line = line_view.to_owned().trim()
    if line.is_empty() {
      continue
    }
    let parsed = @json.parse(line) catch {
      error => {
        result.errors.push("OpenCode export line \{line_offset}: \{error}")
        result.skipped += 1
        continue
      }
    }
    guard parsed is Object(row) else {
      result.skipped += 1
      continue
    }
    let session_id = match session_payload_id(row) {
      Some(id) => id
      None => {
        result.skipped += 1
        continue
      }
    }
    let message_id = match opencode_row_message_id(row) {
      Some(id) => id
      None => {
        result.skipped += 1
        continue
      }
    }
    match row.get("data") {
      Some(Object(data_obj)) =>
        self.ingest_opencode_message_object(
          session_id~,
          message_id~,
          data_obj,
          result,
        )
      Some(String(data_text)) => {
        let data_json = @json.parse(data_text) catch {
          error => {
            result.errors.push(
              "OpenCode export data line \{line_offset}: \{error}",
            )
            result.skipped += 1
            continue
          }
        }
        match data_json {
          Object(data_obj) =>
            self.ingest_opencode_message_object(
              session_id~,
              message_id~,
              data_obj,
              result,
            )
          _ => result.skipped += 1
        }
      }
      _ =>
        self.ingest_opencode_message_object(
          session_id~,
          message_id~,
          row,
          result,
        )
    }
  }
  self.session_sync_state.set(
    file_path,
    SessionFileSyncState::new(last_modified~, last_line_offset=line_offset),
  )
  result
}

///|
async fn TrafficStats::sync_claude_session_logs(
  self : TrafficStats,
  projects_dir? : String = default_claude_projects_dir(),
) -> SessionSyncResult {
  let result = SessionSyncResult::new()
  if !@fsx.exists(projects_dir) {
    return result
  }
  let files = collect_claude_jsonl_files(projects_dir)
  for file_path in files {
    result.files_scanned += 1
    try {
      let stat = @fsx.stat(file_path)
      let content = @fsx.read_file(file_path)
      let file_result = self.ingest_claude_session_jsonl(
        file_path~,
        content~,
        last_modified=stat.mtime(),
      )
      result.imported += file_result.imported
      result.skipped += file_result.skipped
      result.errors.append(file_result.errors)
    } catch {
      error => result.errors.push("\{file_path}: \{error}")
    }
  }
  result
}

///|
fn TrafficStats::ingest_claude_session_jsonl(
  self : TrafficStats,
  file_path~ : String,
  content~ : String,
  last_modified~ : Int64,
) -> SessionSyncResult {
  let result = SessionSyncResult::new()
  result.files_scanned = 1
  let existing_state = self.session_sync_state.get(file_path)
  if existing_state is Some(state) && last_modified <= state.last_modified {
    return result
  }
  let last_offset = match existing_state {
    Some(state) => state.last_line_offset
    None => 0
  }
  let messages : Map[String, ParsedClaudeSessionUsage] = Map([], capacity=0)
  let mut line_offset = 0
  let mut current_session_id : String? = None
  for line_view in content.split("\n") {
    line_offset += 1
    if line_offset <= last_offset {
      continue
    }
    let line = line_view.to_owned().trim()
    if line.is_empty() {
      continue
    }
    let parsed = @json.parse(line) catch { _ => continue }
    if current_session_id is None {
      current_session_id = session_json_string(parsed, "sessionId")
    }
    guard parsed is Object(root) else { continue }
    guard root.get("type") is Some(String("assistant")) else { continue }
    guard root.get("message") is Some(Object(message)) else { continue }
    guard message.get("id") is Some(String(message_id)) else { continue }
    guard message.get("usage") is Some(Object(usage_json)) else { continue }
    let usage = TokenUsage::new(
      input_tokens=json_int_or_zero(usage_json, "input_tokens"),
      output_tokens=json_int_or_zero(usage_json, "output_tokens"),
      cache_read_tokens=json_int_or_zero(usage_json, "cache_read_input_tokens"),
      cache_creation_tokens=json_int_or_zero(
        usage_json, "cache_creation_input_tokens",
      ),
      model=session_map_string(message, "model"),
      message_id=Some(message_id),
    )
    let parsed_usage : ParsedClaudeSessionUsage = {
      message_id,
      model: usage.model.unwrap_or("unknown"),
      usage,
      stop_reason: session_map_string(message, "stop_reason"),
      timestamp: session_map_string(root, "timestamp"),
      session_id: current_session_id,
    }
    if should_replace_claude_session_usage(
        messages.get(message_id),
        parsed_usage,
      ) {
      messages.set(message_id, parsed_usage)
    }
  }
  for message_id in messages.keys() {
    guard messages.get(message_id) is Some(message) else { continue }
    if !message.usage.has_billable_tokens() {
      continue
    }
    let request_id = "\{CLAUDE_SESSION_REQUEST_ID_PREFIX}\{message.message_id}"
    if self.should_skip_session_insert(
        request_id,
        app_type="claude",
        model=message.model,
        usage=message.usage,
        created_at=session_timestamp_seconds(message.timestamp),
      ) {
      result.skipped += 1
      continue
    }
    self.record_claude_session_usage(request_id, message)
    result.imported += 1
  }
  self.session_sync_state.set(
    file_path,
    SessionFileSyncState::new(last_modified~, last_line_offset=line_offset),
  )
  result
}

///|
async fn collect_claude_jsonl_files(projects_dir : String) -> Array[String] {
  let files : Array[String] = []
  let entries = @fsx.list_directory(projects_dir) catch { _ => return files }
  for entry in entries {
    if !(entry.kind is Directory) {
      continue
    }
    let project_entries = @fsx.list_directory(entry.path) catch {
      _ => continue
    }
    for project_entry in project_entries {
      if session_path_is_jsonl(project_entry.path) {
        files.push(project_entry.path)
      } else if project_entry.kind is Directory {
        let subagents_dir = @pathx.join(project_entry.path, "subagents")
        push_jsonl_children(subagents_dir, files)
        let workflows_dir = @pathx.join(subagents_dir, "workflows")
        let workflow_entries = @fsx.list_directory(workflows_dir) catch {
          _ => []
        }
        for workflow_entry in workflow_entries {
          if workflow_entry.kind is Directory {
            push_jsonl_children(workflow_entry.path, files)
          }
        }
      }
    }
  }
  files
}

///|
async fn TrafficStats::sync_codex_session_logs(
  self : TrafficStats,
  codex_dir? : String = default_codex_config_dir(),
) -> SessionSyncResult {
  let result = SessionSyncResult::new()
  let files = collect_codex_session_files(codex_dir)
  for file_path in files {
    result.files_scanned += 1
    try {
      let stat = @fsx.stat(file_path)
      let content = @fsx.read_file(file_path)
      let file_result = self.ingest_codex_session_jsonl(
        file_path~,
        content~,
        last_modified=stat.mtime(),
      )
      result.imported += file_result.imported
      result.skipped += file_result.skipped
      result.errors.append(file_result.errors)
    } catch {
      error =>
        result.errors.push("Codex session parse failed \{file_path}: \{error}")
    }
  }
  result
}

///|
fn TrafficStats::ingest_codex_session_jsonl(
  self : TrafficStats,
  file_path~ : String,
  content~ : String,
  last_modified~ : Int64,
) -> SessionSyncResult {
  let result = SessionSyncResult::new()
  result.files_scanned = 1
  let existing_state = self.session_sync_state.get(file_path)
  if existing_state is Some(state) && last_modified <= state.last_modified {
    return result
  }
  let last_offset = match existing_state {
    Some(state) => state.last_line_offset
    None => 0
  }
  let state = CodexFileParseState::{
    session_id: None,
    current_model: "unknown",
    prev_total: None,
    event_index: 0,
  }
  let mut line_offset = 0
  for line_view in content.split("\n") {
    line_offset += 1
    let line = line_view.to_owned().trim()
    if line.is_empty() {
      continue
    }
    let is_event_msg = line.contains("\"event_msg\"")
    let is_turn_context = line.contains("\"turn_context\"")
    let is_session_meta = line.contains("\"session_meta\"")
    if !is_event_msg && !is_turn_context && !is_session_meta {
      continue
    }
    if is_event_msg && !line.contains("\"token_count\"") {
      continue
    }
    let parsed = @json.parse(line) catch { _ => continue }
    guard parsed is Object(root) else { continue }
    match session_map_string(root, "type") {
      Some("session_meta") =>
        if state.session_id is None {
          match root.get("payload") {
            Some(Object(payload)) =>
              state.session_id = session_payload_id(payload)
            _ => ()
          }
        }
      Some("turn_context") =>
        match root.get("payload") {
          Some(Object(payload)) =>
            match codex_payload_model(payload) {
              Some(model) => state.current_model = normalize_codex_model(model)
              None => ()
            }
          _ => ()
        }
      Some("event_msg") =>
        match parse_codex_token_count_delta(root, state) {
          Some(delta) => {
            state.event_index += 1
            if line_offset <= last_offset || delta.is_zero() {
              continue
            }
            let session_id = state.session_id.unwrap_or("unknown")
            let request_id = "codex_session:\{session_id}:\{state.event_index}"
            let timestamp = session_map_string(root, "timestamp")
            let usage = TokenUsage::new(
              input_tokens=delta.input,
              output_tokens=delta.output,
              cache_read_tokens=delta.cached_input,
              model=Some(state.current_model),
            )
            if self.should_skip_session_insert(
                request_id,
                app_type="codex",
                model=state.current_model,
                usage~,
                created_at=session_timestamp_seconds(timestamp),
                allow_missing_cache_creation=true,
              ) {
              result.skipped += 1
            } else {
              self.record_codex_session_usage(
                request_id,
                delta,
                state.current_model,
                state.session_id,
                timestamp,
              )
              result.imported += 1
            }
          }
          None => ()
        }
      _ => ()
    }
  }
  self.session_sync_state.set(
    file_path,
    SessionFileSyncState::new(last_modified~, last_line_offset=line_offset),
  )
  result
}

///|
async fn TrafficStats::sync_gemini_session_logs(
  self : TrafficStats,
  gemini_dir? : String = default_gemini_dir(),
) -> SessionSyncResult {
  let result = SessionSyncResult::new()
  let files = collect_gemini_session_files(gemini_dir)
  for file_path in files {
    result.files_scanned += 1
    try {
      let stat = @fsx.stat(file_path)
      let content = @fsx.read_file(file_path)
      let file_result = self.ingest_gemini_session_json(
        file_path~,
        content~,
        last_modified=stat.mtime(),
      )
      result.imported += file_result.imported
      result.skipped += file_result.skipped
      result.errors.append(file_result.errors)
    } catch {
      error =>
        result.errors.push("Gemini session parse failed \{file_path}: \{error}")
    }
  }
  result
}

///|
fn TrafficStats::ingest_gemini_session_json(
  self : TrafficStats,
  file_path~ : String,
  content~ : String,
  last_modified~ : Int64,
) -> SessionSyncResult {
  let result = SessionSyncResult::new()
  result.files_scanned = 1
  let existing_state = self.session_sync_state.get(file_path)
  if existing_state is Some(state) && last_modified <= state.last_modified {
    return result
  }
  let parsed = @json.parse(content) catch {
    error => {
      result.errors.push("JSON parse failed: \{error}")
      return result
    }
  }
  guard parsed is Object(root) else { return result }
  let session_id = session_map_string(root, "sessionId")
  guard root.get("messages") is Some(Array(messages)) else {
    self.session_sync_state.set(
      file_path,
      SessionFileSyncState::new(last_modified~, last_line_offset=0),
    )
    return result
  }
  let mut gemini_message_count = 0
  for message_json in messages {
    guard message_json is Object(message) else { continue }
    guard message.get("type") is Some(String("gemini")) else { continue }
    guard message.get("tokens") is Some(Object(tokens_json)) else { continue }
    let tokens = parse_gemini_session_tokens(tokens_json)
    if tokens.is_zero() {
      continue
    }
    gemini_message_count += 1
    let message_id = session_map_string(message, "id").unwrap_or("unknown")
    let model = session_map_string(message, "model").unwrap_or("unknown")
    let timestamp = session_map_string(message, "timestamp")
    let session_id_str = session_id.unwrap_or("unknown")
    let request_id = "gemini_session:\{session_id_str}:\{message_id}"
    let output_tokens = tokens.output + tokens.thoughts
    let usage = TokenUsage::new(
      input_tokens=tokens.input,
      output_tokens~,
      cache_read_tokens=tokens.cached,
      model=Some(model),
    )
    if self.should_skip_session_insert(
        request_id,
        app_type="gemini",
        model~,
        usage~,
        created_at=session_timestamp_seconds(timestamp),
        allow_missing_cache_creation=true,
      ) {
      result.skipped += 1
    } else {
      self.record_gemini_session_usage(
        request_id, tokens, model, session_id, timestamp,
      )
      result.imported += 1
    }
  }
  self.session_sync_state.set(
    file_path,
    SessionFileSyncState::new(
      last_modified~,
      last_line_offset=gemini_message_count,
    ),
  )
  result
}

///|
async fn collect_codex_session_files(codex_dir : String) -> Array[String] {
  let files : Array[String] = []
  let sessions_dir = @pathx.join(codex_dir, "sessions")
  if @fsx.exists(sessions_dir) {
    collect_jsonl_recursive_limited(sessions_dir, files, depth=0, max_depth=3)
  }
  let archived_dir = @pathx.join(codex_dir, "archived_sessions")
  let archived_entries = @fsx.list_directory(archived_dir) catch { _ => [] }
  for entry in archived_entries {
    if session_path_is_jsonl(entry.path) {
      files.push(entry.path)
    }
  }
  files
}

///|
async fn collect_jsonl_recursive_limited(
  dir : String,
  files : Array[String],
  depth~ : Int,
  max_depth~ : Int,
) -> Unit {
  let entries = @fsx.list_directory(dir) catch { _ => return }
  for entry in entries {
    if entry.kind is Directory && depth < max_depth {
      collect_jsonl_recursive_limited(
        entry.path,
        files,
        depth=depth + 1,
        max_depth~,
      )
    } else if session_path_is_jsonl(entry.path) {
      files.push(entry.path)
    }
  }
}

///|
async fn collect_gemini_session_files(gemini_dir : String) -> Array[String] {
  let files : Array[String] = []
  let tmp_dir = @pathx.join(gemini_dir, "tmp")
  let project_dirs = @fsx.list_directory(tmp_dir) catch { _ => return files }
  for project_dir in project_dirs {
    if !(project_dir.kind is Directory) {
      continue
    }
    let chats_dir = @pathx.join(project_dir.path, "chats")
    let chat_files = @fsx.list_directory(chats_dir) catch { _ => continue }
    for file_entry in chat_files {
      let name = @pathx.basename(file_entry.path)
      if name.has_prefix("session-") && name.has_suffix(".json") {
        files.push(file_entry.path)
      }
    }
  }
  files
}

///|
async fn push_jsonl_children(dir : String, files : Array[String]) -> Unit {
  let entries = @fsx.list_directory(dir) catch { _ => return }
  for entry in entries {
    if session_path_is_jsonl(entry.path) {
      files.push(entry.path)
    }
  }
}

///|
fn session_path_is_jsonl(path : String) -> Bool {
  path.has_suffix(".jsonl")
}

///|
fn normalize_codex_model(raw : String) -> String {
  let mut name = raw.trim().to_lower().to_owned()
  if name.rev_find("/") is Some(index) {
    name = name[index + 1:].to_owned()
  }
  match strip_codex_model_date_suffix(name) {
    Some(stripped) => stripped
    None => name
  }
}

///|
fn strip_codex_model_date_suffix(model_id : String) -> String? {
  if model_id.length() > 11 {
    let start = model_id.length() - 11
    let suffix = model_id[start:].to_owned()
    if suffix.length() == 11 &&
      suffix[0] == '-' &&
      session_ascii_digits(suffix[1:5].to_owned()) &&
      suffix[5] == '-' &&
      session_ascii_digits(suffix[6:8].to_owned()) &&
      suffix[8] == '-' &&
      session_ascii_digits(suffix[9:11].to_owned()) {
      return Some(model_id[:start].to_owned())
    }
  }
  guard model_id.rev_find("-") is Some(index) else { return None }
  let base = model_id[:index].to_owned()
  let suffix = model_id[index + 1:].to_owned()
  if !base.is_empty() && suffix.length() == 8 && session_ascii_digits(suffix) {
    Some(base)
  } else {
    None
  }
}

///|
fn parse_codex_token_count_delta(
  root : Map[String, Json],
  state : CodexFileParseState,
) -> DeltaSessionTokens? {
  guard root.get("payload") is Some(Object(payload)) else { return None }
  guard payload.get("type") is Some(String("token_count")) else { return None }
  guard payload.get("info") is Some(Object(info)) else { return None }
  match codex_info_model(info, payload) {
    Some(model) => state.current_model = normalize_codex_model(model)
    None => ()
  }
  let (cumulative, is_total) = match info.get("total_token_usage") {
    Some(Object(total)) => (parse_cumulative_session_tokens(total), true)
    _ =>
      match info.get("last_token_usage") {
        Some(Object(last)) => (parse_cumulative_session_tokens(last), false)
        _ => return None
      }
  }
  guard cumulative is Some(current) else { return None }
  let delta = if is_total {
    let computed = compute_delta_session_tokens(state.prev_total, current)
    state.prev_total = Some(current)
    computed
  } else {
    {
      input: current.input,
      cached_input: current.cached_input,
      output: current.output,
    }
  }
  Some({
    input: delta.input,
    cached_input: session_min_int(delta.cached_input, delta.input),
    output: delta.output,
  })
}

///|
fn parse_cumulative_session_tokens(
  obj : Map[String, Json],
) -> CumulativeSessionTokens? {
  Some({
    input: json_int_or_zero(obj, "input_tokens"),
    cached_input: match obj.get("cached_input_tokens") {
      Some(_) => json_int_or_zero(obj, "cached_input_tokens")
      None => json_int_or_zero(obj, "cache_read_input_tokens")
    },
    output: json_int_or_zero(obj, "output_tokens"),
  })
}

///|
fn compute_delta_session_tokens(
  prev : CumulativeSessionTokens?,
  current : CumulativeSessionTokens,
) -> DeltaSessionTokens {
  match prev {
    None =>
      {
        input: current.input,
        cached_input: current.cached_input,
        output: current.output,
      }
    Some(old) =>
      {
        input: max_int(current.input - old.input, 0),
        cached_input: max_int(current.cached_input - old.cached_input, 0),
        output: max_int(current.output - old.output, 0),
      }
  }
}

///|
fn DeltaSessionTokens::is_zero(self : DeltaSessionTokens) -> Bool {
  self.input == 0 && self.cached_input == 0 && self.output == 0
}

///|
fn codex_payload_model(payload : Map[String, Json]) -> String? {
  match session_map_string(payload, "model") {
    Some(model) => Some(model)
    None =>
      match payload.get("info") {
        Some(Object(info)) => session_map_string(info, "model")
        _ => None
      }
  }
}

///|
fn codex_info_model(
  info : Map[String, Json],
  payload : Map[String, Json],
) -> String? {
  match session_map_string(info, "model") {
    Some(model) => Some(model)
    None =>
      match session_map_string(info, "model_name") {
        Some(model) => Some(model)
        None => session_map_string(payload, "model")
      }
  }
}

///|
fn session_payload_id(payload : Map[String, Json]) -> String? {
  match session_map_string(payload, "session_id") {
    Some(id) => Some(id)
    None =>
      match session_map_string(payload, "sessionId") {
        Some(id) => Some(id)
        None => session_map_string(payload, "id")
      }
  }
}

///|
fn parse_gemini_session_tokens(
  tokens : Map[String, Json],
) -> GeminiSessionTokens {
  {
    input: json_int_or_zero(tokens, "input"),
    output: json_int_or_zero(tokens, "output"),
    cached: json_int_or_zero(tokens, "cached"),
    thoughts: json_int_or_zero(tokens, "thoughts"),
  }
}

///|
fn GeminiSessionTokens::is_zero(self : GeminiSessionTokens) -> Bool {
  self.input == 0 && self.output == 0 && self.cached == 0 && self.thoughts == 0
}

///|
fn parse_opencode_message_data(
  root : Map[String, Json],
  require_completed? : Bool = false,
) -> OpenCodeMessageData? {
  if session_map_string(root, "role") != Some("assistant") {
    return None
  }
  guard root.get("tokens") is Some(Object(tokens)) else { return None }
  if require_completed &&
    !(root.get("time") is Some(Object(time)) && time.get("completed") is Some(_)) {
    return None
  }
  let input_tokens = json_int_or_zero(tokens, "input")
  let output_tokens = json_int_or_zero(tokens, "output")
  let reasoning_tokens = json_int_or_zero(tokens, "reasoning")
  let (cache_read_tokens, cache_write_tokens) = match tokens.get("cache") {
    Some(Object(cache)) =>
      (json_int_or_zero(cache, "read"), json_int_or_zero(cache, "write"))
    _ => (0, 0)
  }
  if input_tokens == 0 &&
    output_tokens == 0 &&
    reasoning_tokens == 0 &&
    cache_read_tokens == 0 &&
    cache_write_tokens == 0 {
    return None
  }
  let cost_usd = match root.get("cost") {
    Some(Number(cost, ..)) if cost > 0.0 => cost.to_string()
    _ => "0"
  }
  let timestamp_ms = match root.get("time") {
    Some(Object(time)) =>
      match time.get("created") {
        Some(Number(created, ..)) => created.trunc().to_int64()
        _ => 0L
      }
    _ => 0L
  }
  Some({
    input_tokens,
    output_tokens,
    reasoning_tokens,
    cache_read_tokens,
    cache_write_tokens,
    cost_usd,
    model_id: session_map_string(root, "modelID").unwrap_or("unknown"),
    timestamp_ms,
  })
}

///|
fn opencode_message_has_incomplete_usage(root : Map[String, Json]) -> Bool {
  session_map_string(root, "role") == Some("assistant") &&
  root.get("tokens") is Some(Object(_)) &&
  !(root.get("time") is Some(Object(time)) && time.get("completed") is Some(_))
}

///|
fn TrafficStats::ingest_opencode_message_object(
  self : TrafficStats,
  session_id~ : String,
  message_id~ : String,
  root : Map[String, Json],
  result : SessionSyncResult,
) -> Unit {
  match parse_opencode_message_data(root, require_completed=true) {
    Some(message) => {
      let request_id = "opencode_session:\{session_id}:\{message_id}"
      let output_tokens = message.output_tokens + message.reasoning_tokens
      let usage = TokenUsage::new(
        input_tokens=message.input_tokens,
        output_tokens~,
        cache_read_tokens=message.cache_read_tokens,
        cache_creation_tokens=message.cache_write_tokens,
        model=Some(message.model_id),
      )
      if self.should_skip_session_insert(
          request_id,
          app_type="opencode",
          model=message.model_id,
          usage~,
          created_at=opencode_timestamp_seconds(message.timestamp_ms),
          allow_missing_cache_creation=true,
        ) {
        result.skipped += 1
      } else {
        self.record_opencode_session_usage(request_id, message, session_id)
        result.imported += 1
      }
    }
    None => result.skipped += 1
  }
}

///|
fn opencode_row_message_id(row : Map[String, Json]) -> String? {
  match session_map_string(row, "message_id") {
    Some(id) => Some(id)
    None =>
      match session_map_string(row, "messageId") {
        Some(id) => Some(id)
        None => session_map_string(row, "id")
      }
  }
}

///|
fn should_replace_claude_session_usage(
  existing : ParsedClaudeSessionUsage?,
  candidate : ParsedClaudeSessionUsage,
) -> Bool {
  match existing {
    None => true
    Some(old) =>
      if candidate.stop_reason is Some(_) && old.stop_reason is None {
        true
      } else if (candidate.stop_reason is Some(_)) ==
        (old.stop_reason is Some(_)) {
        candidate.usage.output_tokens > old.usage.output_tokens
      } else {
        false
      }
  }
}

///|
fn TrafficStats::record_claude_session_usage(
  self : TrafficStats,
  request_id : String,
  message : ParsedClaudeSessionUsage,
) -> Unit {
  let usage = message.usage
  let pricing = find_static_model_pricing(message.model)
  let cost = match pricing {
    Some(model_pricing) =>
      calculate_cost_for_app("claude", usage, model_pricing)
    None =>
      {
        input_cost_usd: "0",
        output_cost_usd: "0",
        cache_read_cost_usd: "0",
        cache_creation_cost_usd: "0",
        total_cost_usd: "0",
      }
  }
  self.record_request_log(
    RequestLog::new(
      request_id~,
      provider_id="_session",
      app_type="claude",
      model=message.model,
      request_model=Some(message.model),
      pricing_model=Some(message.model),
      usage~,
      input_cost_usd=cost.input_cost_usd,
      output_cost_usd=cost.output_cost_usd,
      cache_read_cost_usd=cost.cache_read_cost_usd,
      cache_creation_cost_usd=cost.cache_creation_cost_usd,
      total_cost_usd=cost.total_cost_usd,
      latency_ms=0,
      status_code=200,
      session_id=message.session_id,
      provider_type=Some("session_log"),
      is_streaming=true,
      cost_multiplier="1.0",
      created_at=session_timestamp_seconds(message.timestamp),
      data_source="session_log",
    ),
  )
}

///|
fn TrafficStats::record_codex_session_usage(
  self : TrafficStats,
  request_id : String,
  delta : DeltaSessionTokens,
  model : String,
  session_id : String?,
  timestamp : String?,
) -> Unit {
  let usage = TokenUsage::new(
    input_tokens=delta.input,
    output_tokens=delta.output,
    cache_read_tokens=delta.cached_input,
    model=Some(model),
  )
  let pricing = find_static_model_pricing(model)
  let cost = match pricing {
    Some(model_pricing) => calculate_cost_for_app("codex", usage, model_pricing)
    None =>
      {
        input_cost_usd: "0",
        output_cost_usd: "0",
        cache_read_cost_usd: "0",
        cache_creation_cost_usd: "0",
        total_cost_usd: "0",
      }
  }
  self.record_request_log(
    RequestLog::new(
      request_id~,
      provider_id="_codex_session",
      app_type="codex",
      model~,
      request_model=Some(model),
      pricing_model=Some(model),
      usage~,
      input_cost_usd=cost.input_cost_usd,
      output_cost_usd=cost.output_cost_usd,
      cache_read_cost_usd=cost.cache_read_cost_usd,
      cache_creation_cost_usd=cost.cache_creation_cost_usd,
      total_cost_usd=cost.total_cost_usd,
      latency_ms=0,
      status_code=200,
      session_id~,
      provider_type=Some("codex_session"),
      is_streaming=true,
      cost_multiplier="1.0",
      created_at=session_timestamp_seconds(timestamp),
      data_source="codex_session",
    ),
  )
}

///|
fn TrafficStats::record_gemini_session_usage(
  self : TrafficStats,
  request_id : String,
  tokens : GeminiSessionTokens,
  model : String,
  session_id : String?,
  timestamp : String?,
) -> Unit {
  let output_tokens = tokens.output + tokens.thoughts
  let usage = TokenUsage::new(
    input_tokens=tokens.input,
    output_tokens~,
    cache_read_tokens=tokens.cached,
    model=Some(model),
  )
  let pricing = find_static_model_pricing(model)
  let cost = match pricing {
    Some(model_pricing) =>
      calculate_cost_for_app("gemini", usage, model_pricing)
    None =>
      {
        input_cost_usd: "0",
        output_cost_usd: "0",
        cache_read_cost_usd: "0",
        cache_creation_cost_usd: "0",
        total_cost_usd: "0",
      }
  }
  self.record_request_log(
    RequestLog::new(
      request_id~,
      provider_id="_gemini_session",
      app_type="gemini",
      model~,
      request_model=Some(model),
      pricing_model=Some(model),
      usage~,
      input_cost_usd=cost.input_cost_usd,
      output_cost_usd=cost.output_cost_usd,
      cache_read_cost_usd=cost.cache_read_cost_usd,
      cache_creation_cost_usd=cost.cache_creation_cost_usd,
      total_cost_usd=cost.total_cost_usd,
      latency_ms=0,
      status_code=200,
      session_id~,
      provider_type=Some("gemini_session"),
      is_streaming=true,
      cost_multiplier="1.0",
      created_at=session_timestamp_seconds(timestamp),
      data_source="gemini_session",
    ),
  )
}

///|
fn TrafficStats::record_opencode_session_usage(
  self : TrafficStats,
  request_id : String,
  message : OpenCodeMessageData,
  session_id : String,
) -> Unit {
  let output_tokens = message.output_tokens + message.reasoning_tokens
  let usage = TokenUsage::new(
    input_tokens=message.input_tokens,
    output_tokens~,
    cache_read_tokens=message.cache_read_tokens,
    cache_creation_tokens=message.cache_write_tokens,
    model=Some(message.model_id),
  )
  let cost = if message.cost_usd != "0" {
    {
      input_cost_usd: "0",
      output_cost_usd: "0",
      cache_read_cost_usd: "0",
      cache_creation_cost_usd: "0",
      total_cost_usd: message.cost_usd,
    }
  } else {
    match find_static_model_pricing(message.model_id) {
      Some(model_pricing) =>
        calculate_cost_for_app("opencode", usage, model_pricing)
      None =>
        {
          input_cost_usd: "0",
          output_cost_usd: "0",
          cache_read_cost_usd: "0",
          cache_creation_cost_usd: "0",
          total_cost_usd: "0",
        }
    }
  }
  self.record_request_log(
    RequestLog::new(
      request_id~,
      provider_id="_opencode_session",
      app_type="opencode",
      model=message.model_id,
      request_model=Some(message.model_id),
      pricing_model=Some(message.model_id),
      usage~,
      input_cost_usd=cost.input_cost_usd,
      output_cost_usd=cost.output_cost_usd,
      cache_read_cost_usd=cost.cache_read_cost_usd,
      cache_creation_cost_usd=cost.cache_creation_cost_usd,
      total_cost_usd=cost.total_cost_usd,
      latency_ms=0,
      status_code=200,
      session_id=Some(session_id),
      provider_type=Some("opencode_session"),
      is_streaming=true,
      cost_multiplier="1.0",
      created_at=opencode_timestamp_seconds(message.timestamp_ms),
      data_source="opencode_session",
    ),
  )
}

///|
fn TrafficStats::should_skip_session_insert(
  self : TrafficStats,
  request_id : String,
  app_type~ : String,
  model~ : String,
  usage~ : TokenUsage,
  created_at~ : Int,
  allow_missing_cache_creation? : Bool = false,
) -> Bool {
  for log in self.request_logs {
    if log.request_id == request_id {
      return true
    }
    let cache_creation_matches = log.cache_creation_tokens ==
      usage.cache_creation_tokens ||
      allow_missing_cache_creation
    if request_log_data_source(log) == "proxy" &&
      log.status_code >= 200 &&
      log.status_code < 300 &&
      log.app_type == app_type &&
      session_models_match(log.model, model) &&
      log.input_tokens == usage.input_tokens &&
      log.output_tokens == usage.output_tokens &&
      log.cache_read_tokens == usage.cache_read_tokens &&
      cache_creation_matches &&
      session_abs_int(log.created_at - created_at) <=
      SESSION_PROXY_DEDUP_WINDOW_SECONDS {
      return true
    }
  }
  false
}

///|
fn opencode_timestamp_seconds(timestamp_ms : Int64) -> Int {
  if timestamp_ms > 0L {
    (timestamp_ms / 1000L).to_int()
  } else {
    @os.unix_seconds()
  }
}

///|
fn session_timestamp_seconds(timestamp : String?) -> Int {
  match timestamp {
    Some(value) =>
      parse_session_timestamp_seconds(value).unwrap_or(@os.unix_seconds())
    None => @os.unix_seconds()
  }
}

///|
fn parse_session_timestamp_seconds(timestamp : String) -> Int? {
  if timestamp.length() < 19 {
    return None
  }
  guard parse_fixed_int(timestamp, 0, 4) is Some(year) else { return None }
  guard parse_fixed_int(timestamp, 5, 7) is Some(month) else { return None }
  guard parse_fixed_int(timestamp, 8, 10) is Some(day) else { return None }
  guard parse_fixed_int(timestamp, 11, 13) is Some(hour) else { return None }
  guard parse_fixed_int(timestamp, 14, 16) is Some(minute) else { return None }
  guard parse_fixed_int(timestamp, 17, 19) is Some(second) else { return None }
  let offset_seconds = parse_timestamp_offset_seconds(timestamp).unwrap_or(0)
  let days = days_from_civil(year, month, day)
  Some(days * 86400 + hour * 3600 + minute * 60 + second - offset_seconds)
}

///|
fn parse_fixed_int(text : String, start : Int, end : Int) -> Int? {
  if text.length() < end {
    return None
  }
  try @string.parse_int(text[start:end], base=10) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn parse_timestamp_offset_seconds(timestamp : String) -> Int? {
  if timestamp.length() <= 19 {
    return Some(0)
  }
  if timestamp.has_suffix("Z") {
    return Some(0)
  }
  let mut offset_start = -1
  let mut i = 19
  while i < timestamp.length() {
    let ch = timestamp[i]
    if ch == '+' || ch == '-' {
      offset_start = i
    }
    i += 1
  }
  if offset_start < 0 || timestamp.length() < offset_start + 6 {
    return Some(0)
  }
  let sign = if timestamp[offset_start] == '-' { -1 } else { 1 }
  guard parse_fixed_int(timestamp, offset_start + 1, offset_start + 3)
    is Some(hours) else {
    return None
  }
  guard parse_fixed_int(timestamp, offset_start + 4, offset_start + 6)
    is Some(minutes) else {
    return None
  }
  Some(sign * (hours * 3600 + minutes * 60))
}

///|
fn days_from_civil(year : Int, month : Int, day : Int) -> Int {
  let mut y = year
  let m = month
  let year_shift = if m <= 2 { 1 } else { 0 }
  y -= year_shift
  let era = floor_div_int(y, 400)
  let yoe = y - era * 400
  let month_shift = if m > 2 { -3 } else { 9 }
  let mp = m + month_shift
  let doy = (153 * mp + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

///|
fn session_json_string(json : Json, key : String) -> String? {
  match json {
    Object(obj) => session_map_string(obj, key)
    _ => None
  }
}

///|
fn session_map_string(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn getenv_non_empty(key : String) -> String? {
  let value = try @os.getenv(key) catch {
    _ => None
  } noraise {
    value => value
  }
  match value {
    Some(value) if !value.is_empty() => Some(value)
    _ => None
  }
}

///|
fn json_int64_or_zero(obj : Map[String, Json], key : String) -> Int64 {
  match obj.get(key) {
    Some(Number(n, ..)) => n.trunc().to_int64()
    _ => 0L
  }
}

///|
fn opencode_database_modified(db_path : String) -> Int64 raise {
  let db_modified = @fsx.stat(db_path).mtime()
  let wal_path = "\{db_path}-wal"
  let wal_modified = @fsx.stat(wal_path).mtime() catch { _ => 0L }
  if wal_modified > db_modified {
    wal_modified
  } else {
    db_modified
  }
}

///|
fn session_models_match(log_model : String, session_model : String) -> Bool {
  log_model.to_lower() == session_model.to_lower() ||
  log_model.to_lower() == "unknown" ||
  session_model.to_lower() == "unknown"
}

///|
fn session_abs_int(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn session_min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn session_ascii_digits(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  for ch in value {
    let code = ch.to_int()
    if code < '0'.to_int() || code > '9'.to_int() {
      return false
    }
  }
  true
}
