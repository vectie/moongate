///|
pub struct Gateway {
  priv host : String
  priv port : Int
  priv model : String
  priv logger : @pino.Logger
  priv started_at_ms : Int
  /// Auth
  priv auth : AuthService
  /// Proxy routing and circuit breakers
  priv proxy : ProxyService
  /// Usage tracking and cost calculation
  priv usage : UsageService
  /// App configuration and settings
  priv config : ConfigService
  /// Session management
  priv session : SessionService
  /// Local workspace and file dialog operations
  priv workspace : WorkspaceService
  /// App runtime status and local tool lifecycle operations
  priv runtime : RuntimeService
  /// Skill discovery, installation, migration, and repository operations
  priv skills : SkillService
  /// OpenClaw and Hermes provider config
  priv openclaw : OpenClawService
  /// Authentication for privileged local management operations.
  priv control : ControlPlaneAuth
}

///|
pub fn Gateway::new(
  port~ : Int,
  host? : String = @suite.default_host(),
  model? : String = @suite.default_model(),
) -> Gateway {
  let logger = @pino.logger("moongate", @pino.Transport::console())
  {
    host,
    port,
    model,
    logger,
    started_at_ms: @async.now().to_int(),
    auth: AuthService::new(),
    proxy: ProxyService::new(host, port),
    usage: UsageService::new(),
    config: ConfigService::new(),
    session: SessionService::new(),
    workspace: WorkspaceService::new(),
    runtime: RuntimeService::new(),
    skills: SkillService::new(),
    openclaw: OpenClawService::new(),
    control: ControlPlaneAuth::new(),
  }
}

///|
pub fn Gateway::host(self : Gateway) -> String {
  self.host
}

///|
pub fn Gateway::port(self : Gateway) -> Int {
  self.port
}

///|
fn moon_first_stream_event_ms(current : Int?, started_at_ms : Int?) -> Int? {
  match current {
    Some(_) => current
    None =>
      match started_at_ms {
        Some(started_at) => Some(max_int(@async.now().to_int() - started_at, 0))
        None => Some(0)
      }
  }
}

///|
fn ProviderRouteTarget::can_use_codex_compatible_upstream(
  self : ProviderRouteTarget,
) -> Bool {
  self.provider_type != Some("codex_oauth") &&
  self.base_url is Some(_) &&
  self.api_key is Some(_)
}

///|
fn ProviderRouteTarget::codex_uses_chat_completions(
  self : ProviderRouteTarget,
) -> Bool {
  if self.api_format == Some("openai_chat") {
    return true
  }
  match self.base_url {
    Some(base_url) => base_url.trim().has_suffix("/chat/completions")
    None => false
  }
}

///|
fn ProviderRouteTarget::can_use_claude_compatible_upstream(
  self : ProviderRouteTarget,
) -> Bool {
  self.provider_type != Some("codex_oauth") &&
  self.base_url is Some(_) &&
  self.api_key is Some(_)
}

///|
fn ProviderRouteTarget::claude_api_format(self : ProviderRouteTarget) -> String {
  if self.provider_type == Some("codex_oauth") {
    return "openai_responses"
  }
  match self.api_format {
    Some("openai_chat") => "openai_chat"
    Some("openai_responses") => "openai_responses"
    Some("gemini_native") => "gemini_native"
    _ => "anthropic"
  }
}

///|
fn ProviderRouteTarget::claude_api_format_for_model(
  self : ProviderRouteTarget,
  model : String,
) -> String {
  if !self.is_github_copilot_upstream() {
    return self.claude_api_format()
  }
  match self.copilot_model_vendor(model) {
    Some(vendor) if vendor.to_lower() == "openai" => "openai_responses"
    _ => "openai_chat"
  }
}

///|
fn ProviderRouteTarget::copilot_model_vendor(
  self : ProviderRouteTarget,
  model : String,
) -> String? {
  guard self.settings_config is Some(Object(settings)) else { return None }
  for
    key in [
      "copilotModels", "copilot_models", "modelCatalog", "model_catalog", "models",
    ] {
    match settings.get(key) {
      Some(models) =>
        match copilot_model_vendor_from_models_json(model, models) {
          Some(vendor) => return Some(vendor)
          None => ()
        }
      None => ()
    }
  }
  None
}

///|
fn claude_api_format_needs_transform(api_format : String) -> Bool {
  api_format == "openai_chat" ||
  api_format == "openai_responses" ||
  api_format == "gemini_native"
}

///|
const MOONGATE_PROXY_MANAGED_PLACEHOLDER = "PROXY_MANAGED"

///|
const HERMES_WEB_OFFLINE_ERROR = "hermes_web_offline"

///|
fn moon_is_managed_account_upstream_url(url : String) -> Bool {
  let (origin, path) = split_origin_and_path(url)
  let host = extract_host(origin).to_lower()
  host == "githubcopilot.com" ||
  host.has_suffix(".githubcopilot.com") ||
  (host == "chatgpt.com" && path.has_prefix("/backend-api/codex"))
}

///|
fn parse_custom_user_agent(value : String?) -> String? {
  match value {
    Some(raw) => {
      let trimmed = raw.trim().to_owned()
      if trimmed.is_empty() || !custom_user_agent_header_value_valid(trimmed) {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn custom_user_agent_header_value_valid(value : String) -> Bool {
  for ch in value {
    let code = ch.to_int()
    if code == 9 {
      continue
    }
    if code < 32 || code == 127 {
      return false
    }
  }
  true
}

///|
fn moon_claude_code_beta_header(existing_beta : String?) -> String {
  let claude_code_beta = "claude-code-20250219"
  match existing_beta {
    Some(beta) if beta.contains(claude_code_beta) => beta
    Some(beta) if !beta.trim().is_empty() => "\{claude_code_beta},\{beta}"
    _ => claude_code_beta
  }
}

///|
fn codex_compatible_responses_endpoint(endpoint : String) -> String {
  let query = match endpoint.find("?") {
    Some(index) => endpoint[index:]
    None => ""
  }
  "/responses\{query}"
}

///|
fn codex_compatible_chat_completions_endpoint(endpoint : String) -> String {
  let query = match endpoint.find("?") {
    Some(index) => endpoint[index:]
    None => ""
  }
  "/chat/completions\{query}"
}

///|
fn claude_transform_endpoint(
  api_format : String,
  is_stream : Bool,
  request_path? : StringView = "/v1/messages",
) -> String {
  let request_path_only = match request_path.find("?") {
    Some(index) => request_path[:index]
    None => request_path
  }
  if !is_claude_messages_path(request_path_only) {
    return request_path.to_owned()
  }
  let query = claude_transform_passthrough_query(
    request_path, api_format, is_stream,
  )
  let target = match api_format {
    "openai_responses" => "/v1/responses"
    "openai_chat" => "/v1/chat/completions"
    "gemini_native" =>
      if is_stream {
        "/v1beta/models/__MODEL__:streamGenerateContent"
      } else {
        "/v1beta/models/__MODEL__:generateContent"
      }
    _ => "/v1/messages"
  }
  match query {
    Some(query) if !query.is_empty() => "\{target}?\{query}"
    _ => target
  }
}

///|
fn is_claude_messages_path(path : StringView) -> Bool {
  path == "/v1/messages"
}

///|
fn claude_transform_passthrough_query(
  request_path : StringView,
  api_format : String,
  is_stream : Bool,
) -> String? {
  match request_path.find("?") {
    Some(index) => {
      let path = request_path[:index]
      let query = request_path[index + 1:]
      let stripped = if is_claude_messages_path(path) {
        strip_claude_beta_query(query)
      } else {
        Some(query.to_owned())
      }
      gemini_stream_query_extra(api_format, is_stream, stripped)
    }
    None => gemini_stream_query_extra(api_format, is_stream, None)
  }
}

///|
fn strip_claude_beta_query(query : StringView) -> String? {
  let parts : Array[String] = []
  for pair in query.split("&") {
    if !pair.is_empty() && !pair.has_prefix("beta=") {
      parts.push(pair.to_owned())
    }
  }
  if parts.is_empty() {
    None
  } else {
    Some(parts.join("&"))
  }
}

///|
fn gemini_stream_query_extra(
  api_format : String,
  is_stream : Bool,
  query : String?,
) -> String? {
  if api_format != "gemini_native" {
    return query
  }
  let parts : Array[String] = []
  match query {
    Some(query) =>
      for pair in query.split("&") {
        if !pair.is_empty() && !pair.has_prefix("alt=") {
          parts.push(pair.to_owned())
        }
      }
    None => ()
  }
  if is_stream {
    parts.push("alt=sse")
  }
  Some(parts.join("&"))
}

///|
fn append_query_to_full_url(
  base_url : String,
  endpoint_trimmed : String,
) -> String {
  match endpoint_trimmed.find("?") {
    Some(index) => {
      let query = endpoint_trimmed[index + 1:]
      if query.is_empty() {
        base_url
      } else if base_url.contains("?") {
        "\{base_url}&\{query}"
      } else {
        "\{base_url}?\{query}"
      }
    }
    None => base_url
  }
}

///|
priv enum MoonClientFormat {
  Claude
  Codex
  OpenAI
  Gemini
  GeminiCli
  Unknown
} derive(Eq)

///|
fn MoonClientFormat::to_string(self : MoonClientFormat) -> String {
  match self {
    Claude => "claude"
    Codex => "codex"
    OpenAI => "openai"
    Gemini => "gemini"
    GeminiCli => "gemini_cli"
    Unknown => "unknown"
  }
}

///|
fn moon_client_format_from_path(path : String) -> MoonClientFormat {
  if path.contains("/v1/messages") {
    Claude
  } else if path.contains("/v1/responses") {
    Codex
  } else if path.contains("/v1/chat/completions") {
    OpenAI
  } else if path.contains("/v1internal/") && path.contains("generateContent") {
    GeminiCli
  } else if (path.contains("/v1beta/") || path.contains("/v1/")) &&
    path.contains("generateContent") {
    Gemini
  } else if path.contains("generateContent") {
    Gemini
  } else {
    Unknown
  }
}

///|
fn moon_client_format_from_body(body : Json) -> MoonClientFormat {
  guard body is Object(obj) else { return Unknown }
  if obj.get("messages") is Some(_) &&
    obj.get("model") is Some(_) &&
    obj.get("response_format") is None &&
    obj.get("contents") is None {
    if obj.get("max_tokens") is Some(_) {
      return Claude
    }
    return OpenAI
  }
  if obj.get("input") is Some(_) {
    return Codex
  }
  if obj.get("contents") is Some(_) {
    return Gemini
  }
  Unknown
}

///|
fn moon_client_format_for_request(
  path : String,
  body : Json?,
) -> MoonClientFormat {
  let format = moon_client_format_from_path(path)
  if format != Unknown {
    return format
  }
  match body {
    Some(body) => moon_client_format_from_body(body)
    None => Unknown
  }
}

///|
priv struct MoonClientSession {
  session_id : String
  client_provided : Bool
}

///|
fn MoonClientSession::upstream_session_id(self : MoonClientSession) -> String? {
  if self.client_provided {
    Some(self.session_id)
  } else {
    None
  }
}

///|
fn json_metadata_string(body : Json, key : String) -> String? {
  guard body is Object(obj) else { return None }
  guard obj.get("metadata") is Some(Object(metadata)) else { return None }
  match metadata.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn json_bool_field(json : Json, key : String) -> Bool? {
  guard json is Object(obj) else { return None }
  match obj.get(key) {
    Some(true) => Some(true)
    Some(false) => Some(false)
    _ => None
  }
}

///|
fn json_string_field(json : Json, key : String) -> String? {
  guard json is Object(obj) else { return None }
  match obj.get(key) {
    Some(String(value)) if !value.is_empty() => Some(value)
    _ => None
  }
}

///|
fn normalize_gemini_endpoint(path : StringView) -> String {
  let raw = path.to_owned()
  if raw.has_prefix("/gemini/v1beta/") {
    "/v1beta/\{raw["/gemini/v1beta/".length():]}"
  } else if raw.has_prefix("/gemini/v1/") {
    "/v1/\{raw["/gemini/v1/".length():]}"
  } else {
    raw
  }
}

///|
fn gemini_model_from_endpoint(endpoint : String) -> String {
  match endpoint.find("/models/") {
    Some(index) => {
      let rest = endpoint[index + "/models/".length():]
      let without_query = match rest.find("?") {
        Some(end) => rest[:end]
        None => rest
      }
      let model = match without_query.find(":") {
        Some(end) => without_query[:end].to_owned()
        None => without_query.to_owned()
      }
      if model.is_empty() {
        "unknown"
      } else {
        normalize_gemini_model_id(model)
      }
    }
    None => "unknown"
  }
}

///|
fn gemini_base_url() -> String {
  match getenv_or_none("GOOGLE_GEMINI_BASE_URL") {
    Some(url) if !url.is_empty() => url
    _ =>
      match getenv_or_none("GEMINI_BASE_URL") {
        Some(url) if !url.is_empty() => url
        _ => "https://generativelanguage.googleapis.com"
      }
  }
}

///|
fn gemini_base_is_full_url() -> Bool {
  env_bool("MOONGATE_GEMINI_FULL_URL")
}

///|
fn codex_base_is_full_url() -> Bool {
  env_bool("MOONGATE_CODEX_FULL_URL")
}

///|
fn claude_base_is_full_url() -> Bool {
  env_bool("MOONGATE_CLAUDE_FULL_URL")
}

///|
fn moon_model_mapping_from_env() -> ModelMapping? {
  let mapping = ModelMapping::new(
    haiku_model=env_first_non_empty(["ANTHROPIC_DEFAULT_HAIKU_MODEL"]),
    sonnet_model=env_first_non_empty(["ANTHROPIC_DEFAULT_SONNET_MODEL"]),
    opus_model=env_first_non_empty(["ANTHROPIC_DEFAULT_OPUS_MODEL"]),
    default_model=env_first_non_empty(["ANTHROPIC_MODEL"]),
  )
  if mapping.has_mapping() {
    Some(mapping)
  } else {
    None
  }
}

///|
fn env_first_non_empty(keys : Array[String]) -> String? {
  for key in keys {
    match getenv_or_none(key) {
      Some(value) if !value.trim().is_empty() =>
        return Some(value.trim().to_owned())
      _ => continue
    }
  }
  None
}

///|
fn env_first_non_negative_decimal(keys : Array[String]) -> String? {
  for key in keys {
    match getenv_or_none(key) {
      Some(value) if usage_non_negative_decimal(value) =>
        return Some(value.trim().to_owned())
      _ => continue
    }
  }
  None
}

///|
fn url_contains_query_key(url : String) -> Bool {
  url.contains("?key=") || url.contains("&key=")
}

///|
fn env_bool(key : String) -> Bool {
  match getenv_or_none(key) {
    Some(value) => {
      let normalized = value.trim().to_lower()
      normalized == "1" ||
      normalized == "true" ||
      normalized == "yes" ||
      normalized == "on"
    }
    None => false
  }
}

///|
fn gemini_api_key() -> String? {
  match getenv_or_none("GEMINI_API_KEY") {
    Some(key) if !key.is_empty() => Some(key)
    _ =>
      match getenv_or_none("GOOGLE_API_KEY") {
        Some(key) if !key.is_empty() => Some(key)
        _ => None
      }
  }
}

///|
fn getenv_or_none(key : String) -> String? {
  @os.getenv(key) catch {
    _ => None
  }
}

///|
fn moon_normalize_app_type(app : String) -> String {
  match app.trim().to_lower() {
    "claude-desktop" => "claude-desktop"
    "codex" => "codex"
    "gemini" => "gemini"
    "opencode" => "opencode"
    "openclaw" => "openclaw"
    "hermes" => "hermes"
    "omo" => "omo"
    "omo-slim" => "omo-slim"
    _ => "claude"
  }
}

///|
fn moon_home_dir() -> String {
  @os.home() catch {
    _ => "."
  }
}

///|
fn moon_ascii_digit_at(value : String, index : Int) -> Bool {
  let ch = value[index]
  ch >= '0' && ch <= '9'
}

///|
async fn moon_ensure_directory(path : String) -> Bool {
  @fsx.make_directory(path, recursive=true, exists_ok=true) catch {
    _ => return false
  }
  true
}

///|
async fn moon_open_directory_result_json(path : String) -> Result[Json, String] {
  if !moon_ensure_directory(path) {
    return Err("open_directory_create_failed")
  }
  Ok(Json::boolean(true))
}

///|
fn moon_preview(content : String, limit : Int) -> String {
  if content.length() <= limit {
    content
  } else {
    content[:limit].to_owned()
  }
}

///|
fn moon_count_case_insensitive_matches(
  haystack : String,
  needle : String,
) -> (Int, Int?) {
  let lower = haystack.to_lower()
  let query = needle.to_lower()
  if query.is_empty() {
    return (0, None)
  }
  let mut count = 0
  let mut first : Int? = None
  let mut offset = 0
  while offset <= lower.length() {
    match lower[offset:].find(query) {
      Some(found) => {
        let pos = offset + found
        if first is None {
          first = Some(pos)
        }
        count = count + 1
        offset = pos + query.length()
      }
      None => break
    }
  }
  (count, first)
}

///|
fn moon_preserve_secret_if_empty(
  incoming : Map[String, Json],
  existing : Map[String, Json],
  object_key : String,
  secret_key : String,
) -> Unit {
  guard incoming.get(object_key) is Some(Object(incoming_obj)) else { return }
  guard existing.get(object_key) is Some(Object(existing_obj)) else { return }
  let incoming_secret = json_string_from_map(incoming_obj, secret_key).unwrap_or(
    "",
  )
  let existing_secret = json_string_from_map(existing_obj, secret_key).unwrap_or(
    "",
  )
  if incoming_secret.is_empty() && !existing_secret.is_empty() {
    incoming_obj[secret_key] = Json::string(existing_secret)
    incoming[object_key] = Json::object(incoming_obj)
  }
}

///|
fn moon_optional_path_from_request(path : StringView, body : Json?) -> String? {
  match proxy_string_request(path, body, "path") {
    Some(value) if !value.trim().is_empty() => return Some(value)
    Some(_) => return None
    None => ()
  }
  match body {
    Some(Object(obj)) =>
      match obj.get("path") {
        Some(Null) => None
        _ => None
      }
    _ => None
  }
}

///|
fn moon_json_primary_api_key_any(content : String) -> Bool {
  let parsed : Result[Json, Error] = moon_result(() => @json.parse(content))
  match parsed {
    Ok(Object(obj)) =>
      match json_string_from_map(obj, "primaryApiKey") {
        Some(value) => value == "any"
        None => false
      }
    _ => false
  }
}

///|
async fn moon_env_conflicts_json(app : String) -> Json {
  moon_env_conflicts_json_with_shell_files(app, moon_env_shell_config_paths())
}

///|
async fn moon_push_shell_env_conflicts(
  conflicts : Array[Json],
  file_path : String,
  keywords : Array[String],
) -> Unit {
  let content = @fsx.read_file(file_path) catch { _ => return }
  let mut line_number = 0
  for line_view in content.split("\n") {
    line_number += 1
    let trimmed = line_view.to_owned().trim().to_owned()
    guard moon_env_assignment_line(trimmed) is Some((var_name, var_value)) else {
      continue
    }
    if moon_env_name_matches_keywords(var_name, keywords) {
      conflicts.push(
        {
          "varName": Json::string(var_name),
          "varValue": Json::string(moon_trim_env_value_quotes(var_value)),
          "sourceType": Json::string("file"),
          "sourcePath": Json::string("\{file_path}:\{line_number}"),
        }.to_json(),
      )
    }
  }
}

///|
fn moon_env_conflict_keys(app : String) -> Array[String] {
  match app {
    "codex" =>
      ["OPENAI_API_KEY", "OPENAI_BASE_URL", "CODEX_HOME", "CODEX_AUTH_TOKEN"]
    "gemini" =>
      [
        "GEMINI_API_KEY", "GOOGLE_API_KEY", "GEMINI_BASE_URL", "GOOGLE_GEMINI_BASE_URL",
      ]
    "opencode" | "omo" | "omo-slim" =>
      [
        "OPENCODE_CONFIG_DIR", "OPENCODE_DB", "OPENAI_API_KEY", "ANTHROPIC_API_KEY",
      ]
    "openclaw" =>
      [
        "OPENCLAW_CONFIG_DIR", "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY",
      ]
    "hermes" =>
      [
        "HERMES_CONFIG_DIR", "HERMES_WEB_PORT", "OPENAI_API_KEY", "ANTHROPIC_API_KEY",
      ]
    _ =>
      [
        "ANTHROPIC_API_KEY", "ANTHROPIC_BASE_URL", "CLAUDE_CONFIG_DIR", "CLAUDE_CODE_USE_BEDROCK",
      ]
  }
}

///|
async fn moon_delete_env_vars_json(body : Json?) -> Result[Json, String] {
  let backup = moon_env_backup_json(body)
  guard backup is Object(obj) else { return Err("invalid_backup") }
  guard obj.get("backupPath") is Some(String(backup_path)) else {
    return Err("missing_backup_path")
  }
  @fsx.make_directory(
    @pathx.dirname(backup_path),
    recursive=true,
    exists_ok=true,
  ) catch {
    error => return Err("创建备份目录失败: \{error}")
  }
  @fsx.write_to_file(backup_path, backup.stringify(indent=2) + "\n") catch {
    error => return Err("写入备份文件失败: \{error}")
  }
  for conflict in moon_env_conflicts_from_body(body) {
    match moon_delete_single_env_conflict(conflict) {
      Ok(_) => ()
      Err(error) =>
        return Err(
          "删除环境变量失败: \{error}. 备份已保存到: \{backup_path}",
        )
    }
  }
  Ok(backup)
}

///|
async fn moon_delete_single_env_conflict(
  conflict : Json,
) -> Result[Unit, String] {
  guard conflict is Object(obj) else { return Err("invalid_conflict") }
  let source_type = moon_env_conflict_string(obj, "sourceType")
  let var_name = moon_env_conflict_string(obj, "varName")
  let source_path = moon_env_conflict_string(obj, "sourcePath")
  match (source_type, var_name, source_path) {
    (Some("file"), Some(var_name), Some(source_path)) => {
      let file_path = moon_env_source_file_path(source_path)
      guard !file_path.is_empty() else {
        return Err("无效的文件路径格式")
      }
      let content = @fsx.read_file(file_path) catch {
        error => return Err("读取文件失败 \{file_path}: \{error}")
      }
      let kept : Array[String] = []
      for line_view in content.split("\n") {
        let line = line_view.to_owned()
        match moon_env_assignment_line(line.trim().to_owned()) {
          Some((name, _)) if name == var_name => ()
          _ => kept.push(line)
        }
      }
      @fsx.write_to_file(file_path, kept.join("\n")) catch {
        error => return Err("写入文件失败 \{file_path}: \{error}")
      }
      Ok(())
    }
    (Some("system"), _, _) | (Some("process"), _, _) => Ok(())
    (Some(other), _, _) => Err("未知的环境变量来源类型: \{other}")
    _ => Err("invalid_conflict")
  }
}

///|
async fn moon_restore_single_env_conflict(
  conflict : Json,
) -> Result[Unit, String] {
  guard conflict is Object(obj) else { return Err("invalid_conflict") }
  let source_type = moon_env_conflict_string(obj, "sourceType")
  let var_name = moon_env_conflict_string(obj, "varName")
  let var_value = moon_env_conflict_string(obj, "varValue")
  let source_path = moon_env_conflict_string(obj, "sourcePath")
  match (source_type, var_name, var_value, source_path) {
    (Some("file"), Some(var_name), Some(var_value), Some(source_path)) => {
      let file_path = moon_env_source_file_path(source_path)
      guard !file_path.is_empty() else {
        return Err("无效的文件路径格式")
      }
      let content = @fsx.read_file(file_path) catch {
        error => return Err("读取文件失败 \{file_path}: \{error}")
      }
      @fsx.write_to_file(
        file_path,
        content + "\nexport \{var_name}=\{var_value}",
      ) catch {
        error => return Err("写入文件失败 \{file_path}: \{error}")
      }
      Ok(())
    }
    (Some(other), _, _, _) =>
      Err("无法恢复类型为 \{other} 的环境变量")
    _ => Err("invalid_conflict")
  }
}

///|
fn moon_env_conflicts_from_body(body : Json?) -> Array[Json] {
  match body {
    Some(Array(items)) => items
    Some(Object(obj)) =>
      match obj.get("conflicts") {
        Some(Array(items)) => items
        _ => []
      }
    _ => []
  }
}

///|
fn moon_env_conflict_string(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn moon_env_assignment_line(line : String) -> (String, String)? {
  if line.is_empty() || line.has_prefix("#") {
    return None
  }
  let export_line = if line.has_prefix("export ") {
    line[7:].to_owned().trim().to_owned()
  } else {
    line
  }
  match export_line.find("=") {
    Some(index) => {
      let name = export_line[:index].to_owned().trim().to_owned()
      let value = export_line[index + 1:].to_owned().trim().to_owned()
      if name.is_empty() {
        None
      } else {
        Some((name, value))
      }
    }
    None => None
  }
}

///|
fn moon_env_name_matches_keywords(
  var_name : String,
  keywords : Array[String],
) -> Bool {
  let upper = var_name.to_upper()
  for keyword in keywords {
    if upper.contains(keyword) {
      return true
    }
  }
  false
}

///|
fn moon_trim_env_value_quotes(value : String) -> String {
  let trimmed = value.trim().to_owned()
  if trimmed.length() >= 2 {
    if (trimmed.has_prefix("\"") && trimmed.has_suffix("\"")) ||
      (trimmed.has_prefix("'") && trimmed.has_suffix("'")) {
      return trimmed[1:trimmed.length() - 1].to_owned()
    }
  }
  trimmed
}

///|
fn gemini_request_is_stream(endpoint : String, body : Json) -> Bool {
  moon_streaming_request(endpoint, body, {})
}

///|
fn moon_streaming_request(
  endpoint : String,
  body : Json,
  headers : Map[String, String],
) -> Bool {
  if json_bool_field(body, "stream").unwrap_or(false) {
    return true
  }
  if endpoint.contains("streamGenerateContent") || endpoint.contains("alt=sse") {
    return true
  }
  match headers.get("accept") {
    Some(accept) => accept.contains("text/event-stream")
    None => false
  }
}

///|
fn moon_unit_success_json() -> Json {
  Json::null()
}

///|
fn moon_update_tray_menu_result() -> Json {
  Json::boolean(false)
}

///|
priv struct ProxyProviderQuery {
  provider_id : String
  app_type : String
}

///|
fn json_non_empty_string_from_map(
  obj : Map[String, Json],
  key : String,
) -> String? {
  match json_string_from_map(obj, key) {
    Some(value) if !value.trim().is_empty() => Some(value)
    _ => None
  }
}

///|
fn suite_write_outcome_json() -> Json {
  let empty : Map[String, Json] = {}
  Json::object(empty)
}

///|
fn suite_object_payload(body : Json?, key : String) -> Json? {
  match body {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Object(_)) if obj.length() == 1 => None
        _ => Some(Json::object(obj))
      }
    _ => None
  }
}

///|
fn suite_object_request(path : StringView, body : Json?, key : String) -> Json? {
  match suite_object_payload(body, key) {
    Some(payload) => return Some(payload)
    None => ()
  }
  match usage_query_value(path, key) {
    Some(raw) => {
      let parsed = @json.parse(raw) catch { _ => return None }
      match parsed {
        Object(obj) => Some(Json::object(obj))
        _ => None
      }
    }
    None => None
  }
}

///|
fn split_csv_json(value : String) -> Json {
  let items : Array[Json] = []
  for raw in value.split(",") {
    let trimmed = raw.trim().to_owned()
    if !trimmed.is_empty() {
      items.push(Json::string(trimmed))
    }
  }
  Json::array(items)
}

///|
const HERMES_DASHBOARD_COMMAND = "hermes dashboard"

///|
const HERMES_DASHBOARD_LOG_PATH = "/tmp/moongate_hermes_dashboard.log"

///|
fn normalize_claude_desktop_mode(mode : String) -> String? {
  match mode.trim().to_lower() {
    "direct" => Some("direct")
    "proxy" => Some("proxy")
    _ => None
  }
}

///|
fn split_endpoint_urls(value : String) -> Array[String] {
  let urls : Array[String] = []
  for raw in value.split(",") {
    urls.push(raw.to_owned())
  }
  urls
}

///|
const MOONGATE_ENDPOINT_DEFAULT_TIMEOUT_SECS = 8

///|
const MOONGATE_ENDPOINT_MIN_TIMEOUT_SECS = 2

///|
const MOONGATE_ENDPOINT_MAX_TIMEOUT_SECS = 30

///|
fn moon_endpoint_invalid_url_error(url : String) -> String {
  if url.has_prefix("http://") || url.has_prefix("https://") {
    if moon_endpoint_url_missing_host(url) {
      "URL 无效: empty host"
    } else {
      "URL 无效"
    }
  } else {
    "URL 无效: relative URL without a base"
  }
}

///|
fn moon_endpoint_url_missing_host(url : String) -> Bool {
  match endpoint_url_host_start(url) {
    Some(start) => {
      if url.length() <= start {
        return true
      }
      let rest = url[start:]
      rest.has_prefix("/") || rest.has_prefix("?") || rest.has_prefix("#")
    }
    None => false
  }
}

///|
fn endpoint_url_host_start(url : String) -> Int? {
  if url.has_prefix("http://") {
    Some(7)
  } else if url.has_prefix("https://") {
    Some(8)
  } else {
    None
  }
}

///|
fn parse_bool_value(value : String) -> Bool? {
  match value.trim().to_owned().to_lower() {
    "true" | "1" | "yes" | "on" => Some(true)
    "false" | "0" | "no" | "off" => Some(false)
    _ => None
  }
}

///|
fn parse_non_negative_decimal_to_double(value : String) -> Double? {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() {
    return None
  }
  let mut seen_dot = false
  let mut seen_digit = false
  for ch in trimmed {
    if ch == '.' {
      if seen_dot {
        return None
      }
      seen_dot = true
    } else {
      let code = ch.to_int()
      if code < '0'.to_int() || code > '9'.to_int() {
        return None
      }
      seen_digit = true
    }
  }
  if !seen_digit {
    return None
  }
  Some(parse_decimal_scaled(trimmed, 1_000_000L).to_double() / 1_000_000.0)
}

///|
fn claude_desktop_model_list_json(
  provider? : ProviderRouteTarget? = None,
) -> Json {
  let routes = match provider {
    Some(provider) => provider.resolved_claude_desktop_model_routes()
    None => []
  }
  if !routes.is_empty() {
    return claude_desktop_route_model_list_json(routes)
  }
  let data = [
    claude_desktop_model_json("claude-sonnet-4-6", supports_1m=true),
    claude_desktop_model_json("claude-opus-4-8", supports_1m=true),
    claude_desktop_model_json("claude-haiku-4-5", supports_1m=true),
  ]
  {
    "data": Json::array(data),
    "has_more": Json::boolean(false),
    "first_id": Json::string("claude-sonnet-4-6"),
    "last_id": Json::string("claude-haiku-4-5"),
  }.to_json()
}

///|
fn claude_desktop_route_model_list_json(
  routes : Array[(String, String, String?, Bool)],
) -> Json {
  let data = routes.map(fn(route) {
    let (route_id, _, label_override, supports_1m) = route
    claude_desktop_model_json(route_id, label_override~, supports_1m~)
  })
  let first_id = match routes.get(0) {
    Some((route_id, _, _, _)) => Json::string(route_id)
    None => Json::null()
  }
  let last_id = if routes.is_empty() {
    Json::null()
  } else {
    match routes.get(routes.length() - 1) {
      Some((route_id, _, _, _)) => Json::string(route_id)
      None => Json::null()
    }
  }
  {
    "data": Json::array(data),
    "has_more": Json::boolean(false),
    "first_id": first_id,
    "last_id": last_id,
  }.to_json()
}

///|
fn claude_desktop_model_json(
  id : String,
  label_override? : String? = None,
  supports_1m? : Bool = true,
) -> Json {
  let obj : Map[String, Json] = {
    "type": Json::string("model"),
    "id": Json::string(id),
    "created_at": Json::string("2024-01-01T00:00:00Z"),
  }
  match label_override {
    Some(label) => obj["labelOverride"] = Json::string(label)
    None => ()
  }
  if supports_1m {
    obj["supports1m"] = Json::boolean(true)
  }
  Json::object(obj)
}

///|
fn normalize_claude_desktop_request_model(
  request : AnthropicRequest,
  app_type : String,
) -> AnthropicRequest {
  if app_type != "claude-desktop" {
    return request
  }
  let model = normalize_claude_desktop_model_id(request.model)
  if model == request.model {
    request
  } else {
    {
      model,
      max_tokens: request.max_tokens,
      messages: request.messages,
      system: request.system,
      tools: request.tools,
      stream: request.stream,
    }
  }
}

///|
fn normalize_claude_desktop_model_id(model : String) -> String {
  let trimmed = model.trim().to_owned()
  strip_one_m_suffix_for_route_lookup(trimmed)
}

///|
fn strip_one_m_suffix_for_route_lookup(model : String) -> String {
  let trimmed = model.trim().to_owned()
  let marker = "[1m]"
  if trimmed.to_lower().has_suffix(marker) {
    trimmed[:trimmed.length() - marker.length()].trim().to_owned()
  } else {
    trimmed
  }
}

///|
fn is_claude_safe_model_id(model : String) -> Bool {
  let normalized = model.trim().to_lower()
  if normalized.contains("[1m]") {
    return false
  }
  let tail = if normalized.has_prefix("anthropic/claude-") {
    normalized["anthropic/claude-".length():]
  } else if normalized.has_prefix("claude-") {
    normalized["claude-".length():]
  } else {
    return false
  }
  ["sonnet-", "opus-", "haiku-"].any(prefix => {
    tail.has_prefix(prefix) && tail.length() > prefix.length()
  })
}

///|
fn ProviderRouteTarget::resolved_claude_desktop_model_routes(
  self : ProviderRouteTarget,
) -> Array[(String, String, String?, Bool)] {
  let routes : Array[(String, String, String?, Bool)] = []
  if self.claude_desktop_model_routes.is_empty() {
    return routes
  }
  let reserved_route_ids : Array[String] = []
  for route_id in self.claude_desktop_model_routes.keys() {
    let trimmed = route_id.trim().to_owned()
    if is_claude_safe_model_id(trimmed) {
      reserved_route_ids.push(trimmed)
    }
  }
  let route_ids : Array[String] = []
  for route_id in self.claude_desktop_model_routes.keys() {
    route_ids.push(route_id)
  }
  route_ids.sort()
  for route_id in route_ids {
    let trimmed_route_id = route_id.trim().to_owned()
    guard self.claude_desktop_model_routes.get(route_id) is Some(route) else {
      continue
    }
    let upstream_model = route.model.trim().to_owned()
    if trimmed_route_id.is_empty() || upstream_model.is_empty() {
      continue
    }
    let route_id_is_safe = is_claude_safe_model_id(trimmed_route_id)
    let resolved_route_id = if route_id_is_safe {
      trimmed_route_id
    } else {
      next_claude_desktop_catalog_safe_route_id(routes, reserved_route_ids)
    }
    let label_override = match route.label_override {
      Some(label) => {
        let label = label.trim().to_owned()
        if label.is_empty() {
          None
        } else {
          Some(label)
        }
      }
      None => if route_id_is_safe { None } else { Some(upstream_model) }
    }
    routes.push(
      (
        resolved_route_id,
        upstream_model,
        label_override,
        route.supports_1m.unwrap_or(false),
      ),
    )
  }
  routes.sort_by(fn(left, right) {
    let (left_route_id, _, _, _) = left
    let (right_route_id, _, _, _) = right
    left_route_id.compare(right_route_id)
  })
  let deduped : Array[(String, String, String?, Bool)] = []
  for route in routes {
    let (route_id, _, _, _) = route
    match deduped.last() {
      Some((previous_route_id, _, _, _)) if previous_route_id == route_id => ()
      _ => deduped.push(route)
    }
  }
  deduped
}

///|
fn next_claude_desktop_catalog_safe_route_id(
  existing : Array[(String, String, String?, Bool)],
  reserved : Array[String],
) -> String {
  for route_id in claude_desktop_default_proxy_route_ids() {
    if !reserved.contains(route_id) &&
      !existing.any(fn(route) {
        let (existing_route_id, _, _, _) = route
        existing_route_id == route_id
      }) {
      return route_id
    }
  }
  for index in 2..<10000 {
    let route_id = "claude-sonnet-4-6-r\{index}"
    if !reserved.contains(route_id) &&
      !existing.any(fn(route) {
        let (existing_route_id, _, _, _) = route
        existing_route_id == route_id
      }) {
      return route_id
    }
  }
  "claude-sonnet-4-6-r10000"
}

///|
fn ProviderRouteTarget::claude_desktop_route_upstream_model(
  self : ProviderRouteTarget,
  request_model : String,
) -> String? {
  let requested = strip_one_m_suffix_for_route_lookup(request_model)
  if requested.is_empty() || self.claude_desktop_model_routes.is_empty() {
    return None
  }
  let routes = self.resolved_claude_desktop_model_routes()
  for route in routes {
    let (route_id, upstream_model, _, _) = route
    if route_id == requested {
      return Some(upstream_model)
    }
  }
  None
}
