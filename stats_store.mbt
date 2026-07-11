///|
const MOONGATE_REQUEST_LOGS_FILE : String = "proxy_request_logs.jsonl"

///|
const MOONGATE_DAILY_ROLLUPS_FILE : String = "usage_daily_rollups.jsonl"

///|
const MOONGATE_SESSION_SYNC_FILE : String = "session_log_sync.jsonl"

///|
const MOONGATE_MODEL_PRICING_FILE : String = "model_pricing.jsonl"

///|
const MOONGATE_USAGE_STORE_FILE : String = "usage_store_v1.json"

///|
const MOONGATE_USAGE_STORE_SCHEMA_VERSION : Int = 1

///|
pub fn default_moongate_stats_dir() -> String {
  default_moongate_dir()
}

///|
async fn TrafficStats::enable_persistent_store(
  self : TrafficStats,
  storage_dir? : String = default_moongate_stats_dir(),
) -> Unit {
  self.storage_dir = Some(storage_dir)
  @fsx.make_directory(storage_dir, recursive=true, exists_ok=true) catch {
    error => self.mark_storage_failure("create_directory", "\{error}")
  }
}

///|
async fn TrafficStats::load_persistent_store(
  self : TrafficStats,
  storage_dir? : String = default_moongate_stats_dir(),
) -> Unit {
  self.enable_persistent_store(storage_dir~)
  if self.load_usage_snapshot_from_store() {
    return
  }
  self.load_daily_rollups_from_store()
  self.load_request_logs_from_store()
  self.load_session_sync_state_from_store()
  self.save_persistent_store()
}

///|
async fn TrafficStats::save_persistent_store(self : TrafficStats) -> Unit {
  guard self.storage_dir is Some(storage_dir) else { return }
  @fsx.make_directory(storage_dir, recursive=true, exists_ok=true) catch {
    error => {
      self.mark_storage_failure("create_directory", "\{error}")
      return
    }
  }
  let path = @pathx.join(storage_dir, MOONGATE_USAGE_STORE_FILE)
  atomic_write_store_file(path, self.usage_store_json().stringify()) catch {
    error => {
      self.mark_storage_failure("write_snapshot", "\{error}")
      return
    }
  }
  self.mark_storage_success()
}

///|
fn TrafficStats::mark_storage_failure(
  self : TrafficStats,
  operation : String,
  message : String,
) -> Unit {
  self.storage_healthy = false
  self.storage_failure_count += 1
  self.storage_last_error = Some("\{operation}: \{message}")
}

///|
fn TrafficStats::mark_storage_success(self : TrafficStats) -> Unit {
  self.storage_healthy = true
  self.storage_last_error = None
  self.storage_last_success_at = Some(@async.now().to_string())
}

///|
async fn atomic_write_store_file(
  path : String,
  content : String,
) -> Unit raise Error {
  let temp_path = "\{path}.tmp-\{generate_request_log_id()}"
  @fs.write_file(
    temp_path,
    content,
    create_mode=CreateOrTruncate,
    permission=0o600,
    sync=Full,
  ) catch {
    error => {
      @fs.remove(temp_path) catch {
        _ => ()
      }
      raise error
    }
  }
  @fs.rename(temp_path, path, replace=true) catch {
    error => {
      @fs.remove(temp_path) catch {
        _ => ()
      }
      raise error
    }
  }
}

///|
fn TrafficStats::usage_store_json(self : TrafficStats) -> Json {
  let request_logs : Array[Json] = []
  for log in self.request_logs {
    request_logs.push(log.to_json())
  }
  let daily_rollups : Array[Json] = []
  for rollup in self.daily_rollups {
    daily_rollups.push(rollup.to_json())
  }
  let session_sync : Array[Json] = []
  for file_path, state in self.session_sync_state {
    session_sync.push(
      {
        "filePath": Json::string(file_path),
        "lastModified": Json::number(state.last_modified.to_double()),
        "lastLineOffset": Json::number(state.last_line_offset.to_double()),
      }.to_json(),
    )
  }
  {
    "schemaVersion": Json::number(
      MOONGATE_USAGE_STORE_SCHEMA_VERSION.to_double(),
    ),
    "requestLogs": Json::array(request_logs),
    "dailyRollups": Json::array(daily_rollups),
    "sessionSync": Json::array(session_sync),
  }.to_json()
}

///|
async fn TrafficStats::load_usage_snapshot_from_store(
  self : TrafficStats,
) -> Bool {
  guard self.storage_dir is Some(storage_dir) else { return false }
  let path = @pathx.join(storage_dir, MOONGATE_USAGE_STORE_FILE)
  if !@fsx.exists_as_file(path) {
    return false
  }
  let content = @fsx.read_file(path) catch {
    error => {
      self.mark_storage_failure("read_snapshot", "\{error}")
      return true
    }
  }
  let parsed = @json.parse(content) catch {
    error => {
      self.mark_storage_failure("parse_snapshot", "\{error}")
      return true
    }
  }
  guard parsed is Object(obj) else {
    self.mark_storage_failure("parse_snapshot", "expected object")
    return true
  }
  if store_json_int_or_zero(obj, "schemaVersion") !=
    MOONGATE_USAGE_STORE_SCHEMA_VERSION {
    self.mark_storage_failure("parse_snapshot", "unsupported schema version")
    return true
  }
  guard obj.get("requestLogs") is Some(Array(request_rows)) else {
    self.mark_storage_failure("parse_snapshot", "missing requestLogs")
    return true
  }
  guard obj.get("dailyRollups") is Some(Array(rollup_rows)) else {
    self.mark_storage_failure("parse_snapshot", "missing dailyRollups")
    return true
  }
  guard obj.get("sessionSync") is Some(Array(session_rows)) else {
    self.mark_storage_failure("parse_snapshot", "missing sessionSync")
    return true
  }
  let request_logs : Array[RequestLog] = []
  for row in request_rows {
    guard request_log_from_store_json(row) is Some(log) else {
      self.mark_storage_failure("parse_snapshot", "invalid request log")
      return true
    }
    request_logs.push(log)
  }
  let daily_rollups : Array[UsageDailyRollup] = []
  for row in rollup_rows {
    guard usage_daily_rollup_from_store_json(row) is Some(rollup) else {
      self.mark_storage_failure("parse_snapshot", "invalid daily rollup")
      return true
    }
    daily_rollups.push(rollup)
  }
  let session_sync_state : Map[String, SessionFileSyncState] = Map(
    [],
    capacity=0,
  )
  for row in session_rows {
    guard row is Object(session) else {
      self.mark_storage_failure("parse_snapshot", "invalid session state")
      return true
    }
    guard store_json_string(session, "filePath") is Some(file_path) else {
      self.mark_storage_failure("parse_snapshot", "missing session file path")
      return true
    }
    session_sync_state.set(
      file_path,
      SessionFileSyncState::new(
        last_modified=store_json_int64_or_zero(session, "lastModified"),
        last_line_offset=store_json_int_or_zero(session, "lastLineOffset"),
      ),
    )
  }
  self.request_logs.truncate(0)
  for log in request_logs {
    self.request_logs.push(log)
  }
  self.daily_rollups.truncate(0)
  for rollup in daily_rollups {
    self.daily_rollups.push(rollup)
  }
  self.session_sync_state = session_sync_state
  self.mark_storage_success()
  true
}

///|
async fn TrafficStats::load_request_logs_from_store(
  self : TrafficStats,
) -> Unit {
  guard self.storage_dir is Some(storage_dir) else { return }
  let path = @pathx.join(storage_dir, MOONGATE_REQUEST_LOGS_FILE)
  if !@fsx.exists_as_file(path) {
    return
  }
  let content = @fsx.read_file(path) catch { _ => return }
  self.request_logs.truncate(0)
  for line_view in content.split("\n") {
    let line = line_view.to_owned().trim()
    if line.is_empty() {
      continue
    }
    let parsed = @json.parse(line) catch { _ => continue }
    match request_log_from_store_json(parsed) {
      Some(log) => self.record_request_log(log)
      None => ()
    }
  }
}

///|
async fn TrafficStats::load_daily_rollups_from_store(
  self : TrafficStats,
) -> Unit {
  guard self.storage_dir is Some(storage_dir) else { return }
  let path = @pathx.join(storage_dir, MOONGATE_DAILY_ROLLUPS_FILE)
  if !@fsx.exists_as_file(path) {
    return
  }
  let content = @fsx.read_file(path) catch { _ => return }
  self.daily_rollups.truncate(0)
  for line_view in content.split("\n") {
    let line = line_view.to_owned().trim()
    if line.is_empty() {
      continue
    }
    let parsed = @json.parse(line) catch { _ => continue }
    match usage_daily_rollup_from_store_json(parsed) {
      Some(rollup) => self.daily_rollups.push(rollup)
      None => ()
    }
  }
}

///|
async fn TrafficStats::load_session_sync_state_from_store(
  self : TrafficStats,
) -> Unit {
  guard self.storage_dir is Some(storage_dir) else { return }
  let path = @pathx.join(storage_dir, MOONGATE_SESSION_SYNC_FILE)
  if !@fsx.exists_as_file(path) {
    return
  }
  let content = @fsx.read_file(path) catch { _ => return }
  self.session_sync_state = Map([], capacity=0)
  for line_view in content.split("\n") {
    let line = line_view.to_owned().trim()
    if line.is_empty() {
      continue
    }
    let parsed = @json.parse(line) catch { _ => continue }
    guard parsed is Object(obj) else { continue }
    guard store_json_string(obj, "filePath") is Some(file_path) else {
      continue
    }
    self.session_sync_state.set(
      file_path,
      SessionFileSyncState::new(
        last_modified=store_json_int64_or_zero(obj, "lastModified"),
        last_line_offset=store_json_int_or_zero(obj, "lastLineOffset"),
      ),
    )
  }
}

///|
fn usage_daily_rollup_from_store_json(json : Json) -> UsageDailyRollup? {
  guard json is Object(obj) else { return None }
  guard store_json_string(obj, "date") is Some(date) else { return None }
  guard store_json_string(obj, "app_type") is Some(app_type) else {
    return None
  }
  guard store_json_string(obj, "provider_id") is Some(provider_id) else {
    return None
  }
  guard store_json_string(obj, "model") is Some(model) else { return None }
  Some({
    date,
    app_type,
    provider_id,
    provider_name: store_json_optional_string(obj, "provider_name"),
    data_source: store_json_string_or_default(
      obj,
      "data_source",
      rollup_default_data_source(provider_id),
    ),
    model,
    request_model: store_json_optional_string(obj, "request_model"),
    pricing_model: store_json_optional_string(obj, "pricing_model"),
    request_count: store_json_int_or_zero(obj, "request_count"),
    success_count: store_json_int_or_zero(obj, "success_count"),
    input_tokens: store_json_int_or_zero(obj, "input_tokens"),
    output_tokens: store_json_int_or_zero(obj, "output_tokens"),
    cache_read_tokens: store_json_int_or_zero(obj, "cache_read_tokens"),
    cache_creation_tokens: store_json_int_or_zero(obj, "cache_creation_tokens"),
    total_cost_nano: parse_decimal_scaled(
      store_json_string_or_default(obj, "total_cost_usd", "0"),
      NANO_USD_SCALE,
    ),
    avg_latency_ms: store_json_int_or_zero(obj, "avg_latency_ms"),
  })
}

///|
fn rollup_default_data_source(provider_id : String) -> String {
  match provider_id {
    "_session" => "session_log"
    "_codex_session" => "codex_session"
    "_gemini_session" => "gemini_session"
    "_opencode_session" => "opencode_session"
    _ => "proxy"
  }
}

///|
fn request_log_from_store_json(json : Json) -> RequestLog? {
  guard json is Object(obj) else { return None }
  guard store_json_string(obj, "request_id") is Some(request_id) else {
    return None
  }
  guard store_json_string(obj, "provider_id") is Some(provider_id) else {
    return None
  }
  guard store_json_string(obj, "app_type") is Some(app_type) else {
    return None
  }
  guard store_json_string(obj, "model") is Some(model) else { return None }
  Some(
    RequestLog::new(
      request_id~,
      provider_id~,
      provider_name=store_json_optional_string(obj, "provider_name"),
      app_type~,
      model~,
      request_model=store_json_optional_string(obj, "request_model"),
      pricing_model=store_json_optional_string(obj, "pricing_model"),
      usage=TokenUsage::new(
        input_tokens=store_json_int_or_zero(obj, "input_tokens"),
        output_tokens=store_json_int_or_zero(obj, "output_tokens"),
        cache_read_tokens=store_json_int_or_zero(obj, "cache_read_tokens"),
        cache_creation_tokens=store_json_int_or_zero(
          obj, "cache_creation_tokens",
        ),
        model=Some(model),
      ),
      input_cost_usd=store_json_string_or_default(obj, "input_cost_usd", "0"),
      output_cost_usd=store_json_string_or_default(obj, "output_cost_usd", "0"),
      cache_read_cost_usd=store_json_string_or_default(
        obj, "cache_read_cost_usd", "0",
      ),
      cache_creation_cost_usd=store_json_string_or_default(
        obj, "cache_creation_cost_usd", "0",
      ),
      total_cost_usd=store_json_string_or_default(obj, "total_cost_usd", "0"),
      is_streaming=store_json_bool_or_false(obj, "is_streaming"),
      latency_ms=store_json_int_or_zero(obj, "latency_ms"),
      first_token_ms=store_json_optional_int(obj, "first_token_ms"),
      duration_ms=store_json_optional_int(obj, "duration_ms"),
      status_code=store_json_int_or_default(obj, "status_code", 200),
      error_message=store_json_optional_string(obj, "error_message"),
      session_id=store_json_optional_string(obj, "session_id"),
      provider_type=store_json_optional_string(obj, "provider_type"),
      cost_multiplier=store_json_string_or_default(
        obj, "cost_multiplier", "1.0",
      ),
      created_at=store_json_int_or_zero(obj, "created_at"),
      data_source=store_json_string_or_default(obj, "data_source", "proxy"),
    ),
  )
}

///|
fn store_json_string(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn store_json_optional_string(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn store_json_string_or_default(
  obj : Map[String, Json],
  key : String,
  default : String,
) -> String {
  store_json_string(obj, key).unwrap_or(default)
}

///|
fn store_json_optional_int(obj : Map[String, Json], key : String) -> Int? {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n.trunc().to_int())
    _ => None
  }
}

///|
fn store_json_int_or_zero(obj : Map[String, Json], key : String) -> Int {
  store_json_int_or_default(obj, key, 0)
}

///|
fn store_json_int_or_default(
  obj : Map[String, Json],
  key : String,
  default : Int,
) -> Int {
  store_json_optional_int(obj, key).unwrap_or(default)
}

///|
fn store_json_int64_or_zero(obj : Map[String, Json], key : String) -> Int64 {
  match obj.get(key) {
    Some(Number(n, ..)) => n.trunc().to_int64()
    _ => 0L
  }
}

///|
fn store_json_bool_or_false(obj : Map[String, Json], key : String) -> Bool {
  match obj.get(key) {
    Some(True) => true
    Some(False) => false
    _ => false
  }
}
