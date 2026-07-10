///|
const MOONSTAT_REQUEST_LOGS_FILE : String = "proxy_request_logs.jsonl"

///|
const MOONSTAT_DAILY_ROLLUPS_FILE : String = "usage_daily_rollups.jsonl"

///|
const MOONSTAT_SESSION_SYNC_FILE : String = "session_log_sync.jsonl"

///|
const MOONSTAT_MODEL_PRICING_FILE : String = "model_pricing.jsonl"

///|
pub fn default_moonstat_stats_dir() -> String {
  default_moonstat_dir()
}

///|
async fn TrafficStats::enable_persistent_store(
  self : TrafficStats,
  storage_dir? : String = default_moonstat_stats_dir(),
) -> Unit {
  self.storage_dir = Some(storage_dir)
  @fsx.make_directory(storage_dir, recursive=true, exists_ok=true) catch {
    _ => ()
  }
}

///|
async fn TrafficStats::load_persistent_store(
  self : TrafficStats,
  storage_dir? : String = default_moonstat_stats_dir(),
) -> Unit {
  self.enable_persistent_store(storage_dir~)
  self.load_daily_rollups_from_store()
  self.load_request_logs_from_store()
  self.load_session_sync_state_from_store()
}

///|
async fn TrafficStats::save_persistent_store(self : TrafficStats) -> Unit {
  guard self.storage_dir is Some(storage_dir) else { return }
  @fsx.make_directory(storage_dir, recursive=true, exists_ok=true) catch {
    _ => return
  }
  self.save_request_logs_to_store(storage_dir)
  self.save_daily_rollups_to_store(storage_dir)
  self.save_session_sync_state_to_store(storage_dir)
}

///|
async fn TrafficStats::load_request_logs_from_store(
  self : TrafficStats,
) -> Unit {
  guard self.storage_dir is Some(storage_dir) else { return }
  let path = @pathx.join(storage_dir, MOONSTAT_REQUEST_LOGS_FILE)
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
async fn TrafficStats::save_request_logs_to_store(
  self : TrafficStats,
  storage_dir : String,
) -> Unit {
  let path = @pathx.join(storage_dir, MOONSTAT_REQUEST_LOGS_FILE)
  let lines : Array[String] = []
  for log in self.request_logs {
    lines.push(log.to_json().stringify())
  }
  @fsx.write_to_file(path, lines.join("\n")) catch {
    _ => ()
  }
}

///|
async fn TrafficStats::load_daily_rollups_from_store(
  self : TrafficStats,
) -> Unit {
  guard self.storage_dir is Some(storage_dir) else { return }
  let path = @pathx.join(storage_dir, MOONSTAT_DAILY_ROLLUPS_FILE)
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
async fn TrafficStats::save_daily_rollups_to_store(
  self : TrafficStats,
  storage_dir : String,
) -> Unit {
  let path = @pathx.join(storage_dir, MOONSTAT_DAILY_ROLLUPS_FILE)
  let lines : Array[String] = []
  for rollup in self.daily_rollups {
    lines.push(rollup.to_json().stringify())
  }
  @fsx.write_to_file(path, lines.join("\n")) catch {
    _ => ()
  }
}

///|
async fn TrafficStats::load_session_sync_state_from_store(
  self : TrafficStats,
) -> Unit {
  guard self.storage_dir is Some(storage_dir) else { return }
  let path = @pathx.join(storage_dir, MOONSTAT_SESSION_SYNC_FILE)
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
async fn TrafficStats::save_session_sync_state_to_store(
  self : TrafficStats,
  storage_dir : String,
) -> Unit {
  let path = @pathx.join(storage_dir, MOONSTAT_SESSION_SYNC_FILE)
  let lines : Array[String] = []
  for file_path, state in self.session_sync_state {
    lines.push(
      {
        "filePath": Json::string(file_path),
        "lastModified": Json::number(state.last_modified.to_double()),
        "lastLineOffset": Json::number(state.last_line_offset.to_double()),
        "lastSyncedAt": Json::number(@os.unix_seconds().to_double()),
      }
      .to_json()
      .stringify(),
    )
  }
  @fsx.write_to_file(path, lines.join("\n")) catch {
    _ => ()
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
