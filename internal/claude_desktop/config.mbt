///|
const PROFILE_ID = "00000000-0000-4000-8000-000000157210"

///|
const PROFILE_NAME = "MoonGate"

///|
const CONFIG_FILE = "claude_desktop_config.json"

///|
const CONFIG_LIBRARY_DIR = "configLibrary"

///|
const TOKEN_ARTIFACT = "auth/claude-desktop-gateway-token"

///|
pub struct ClaudeDesktopInstall {
  token : String
  profile_path : String
  meta_path : String
  base_url : String
}

///|
pub struct ClaudeDesktopStatus {
  configured : Bool
  profile_path : String
  meta_path : String
  config_library_path : String
  applied_id : String?
  actual_base_url : String?
  stale_raw_models : Bool
  token_configured : Bool
}

///|
pub fn ClaudeDesktopStatus::new(
  configured~ : Bool,
  profile_path~ : String,
  meta_path~ : String,
  config_library_path~ : String,
  applied_id? : String? = None,
  actual_base_url? : String? = None,
  stale_raw_models? : Bool = false,
  token_configured? : Bool = false,
) -> ClaudeDesktopStatus {
  {
    configured,
    profile_path,
    meta_path,
    config_library_path,
    applied_id,
    actual_base_url,
    stale_raw_models,
    token_configured,
  }
}

///|
priv struct ClaudeDesktopPaths {
  normal_config_path : String
  threep_config_path : String
  config_library_path : String
  profile_path : String
  meta_path : String
}

///|
priv struct FileSnapshot {
  path : String
  content : String?
}

///|
pub async fn gateway_token() -> String? {
  match gateway_token_from_env() {
    Some(token) => Some(token)
    None => gateway_token_from_file()
  }
}

///|
pub async fn get_or_create_gateway_token(token : String?) -> String {
  let resolved = resolve_gateway_token(token)
  write_gateway_token(resolved)
  resolved
}

///|
async fn resolve_gateway_token(token : String?) -> String {
  match token {
    Some(value) if !value.trim().is_empty() => value.trim().to_owned()
    _ =>
      match gateway_token() {
        Some(existing) => existing
        None => generate_gateway_token()
      }
  }
}

///|
pub async fn install_proxy_profile(
  host : String,
  port : Int,
  token? : String? = None,
) -> Result[ClaudeDesktopInstall, String] {
  install_proxy_profile_at_paths(claude_desktop_paths(), host, port, token~)
}

///|
async fn install_proxy_profile_at_paths(
  paths : ClaudeDesktopPaths,
  host : String,
  port : Int,
  token? : String? = None,
) -> Result[ClaudeDesktopInstall, String] {
  let base_url = local_gateway_base_url(host, port)
  let snapshots = snapshot_files([
    paths.normal_config_path,
    paths.threep_config_path,
    paths.profile_path,
    paths.meta_path,
    gateway_token_path(),
  ])
  try {
    let gateway_token = resolve_gateway_token(token)
    write_deployment_mode(paths.normal_config_path, "3p")
    write_deployment_mode(paths.threep_config_path, "3p")
    write_json_file(
      paths.profile_path,
      gateway_profile_json(base_url, gateway_token),
    )
    write_meta(paths.meta_path, Some(PROFILE_ID))
    write_gateway_token(gateway_token)
    Ok({
      token: gateway_token,
      profile_path: paths.profile_path,
      meta_path: paths.meta_path,
      base_url,
    })
  } catch {
    err => {
      restore_file_snapshots(snapshots)
      Err("failed to install Claude Desktop profile: \{err}")
    }
  }
}

///|
pub async fn uninstall_proxy_profile() -> Result[Unit, String] {
  uninstall_proxy_profile_at_paths(claude_desktop_paths())
}

///|
async fn uninstall_proxy_profile_at_paths(
  paths : ClaudeDesktopPaths,
) -> Result[Unit, String] {
  let snapshots = snapshot_files([
    paths.normal_config_path,
    paths.threep_config_path,
    paths.profile_path,
    paths.meta_path,
  ])
  try {
    write_deployment_mode(paths.normal_config_path, "1p")
    write_deployment_mode(paths.threep_config_path, "1p")
    remove_gateway_enterprise_config(paths.threep_config_path)
    if @fsx.exists_as_file(paths.profile_path) {
      @fsx.remove(paths.profile_path)
    }
    write_meta(paths.meta_path, None)
    Ok(())
  } catch {
    err => {
      restore_file_snapshots(snapshots)
      Err("failed to uninstall Claude Desktop profile: \{err}")
    }
  }
}

///|
pub async fn status() -> ClaudeDesktopStatus {
  let paths = claude_desktop_paths()
  let profile = read_json_or_empty(paths.profile_path)
  {
    configured: @fsx.exists_as_file(paths.profile_path) ||
    meta_has_profile_entry(paths.meta_path),
    profile_path: paths.profile_path,
    meta_path: paths.meta_path,
    config_library_path: paths.config_library_path,
    applied_id: read_applied_id(paths.meta_path),
    actual_base_url: json_object_string(profile, "inferenceGatewayBaseUrl"),
    stale_raw_models: profile_has_stale_raw_models(profile),
    token_configured: gateway_token() is Some(_),
  }
}

///|
pub fn local_gateway_base_url(host : String, port : Int) -> String {
  let connect_host = match host {
    "0.0.0.0" => "127.0.0.1"
    "::" => "::1"
    other => other
  }
  "http://\{connect_host}:\{port}/claude-desktop"
}

///|
fn gateway_token_from_env() -> String? {
  match getenv_or_none("MOONGATE_CLAUDE_DESKTOP_TOKEN") {
    Some(token) if !token.trim().is_empty() => Some(token.trim().to_owned())
    _ =>
      match getenv_or_none("CLAUDE_DESKTOP_GATEWAY_TOKEN") {
        Some(token) if !token.trim().is_empty() => Some(token.trim().to_owned())
        _ => None
      }
  }
}

///|
async fn gateway_token_from_file() -> String? {
  try {
    let token = @fsx.read_file(gateway_token_path()).trim()
    if token.is_empty() {
      None
    } else {
      Some(token.to_owned())
    }
  } catch {
    _ => None
  }
}

///|
async fn write_gateway_token(token : String) -> Unit {
  let path = gateway_token_path()
  @fsx.make_directory(@pathx.dirname(path), recursive=true, exists_ok=true)
  @fsx.write_to_file(path, token + "\n", create=0o600)
}

///|
fn generate_gateway_token() -> String {
  let randomer = @rand.chacha8() catch { _ => @random.Rand::new() }
  "moongate-\{@uuid.generator(randomer).v4()}"
}

///|
fn gateway_profile_json(base_url : String, api_key : String) -> Json {
  Json::object({
    "coworkEgressAllowedHosts": Json::array([Json::string("*")]),
    "disableDeploymentModeChooser": Json::boolean(true),
    "inferenceGatewayApiKey": Json::string(api_key),
    "inferenceGatewayAuthScheme": Json::string("bearer"),
    "inferenceGatewayBaseUrl": Json::string(base_url),
    "inferenceProvider": Json::string("gateway"),
    "inferenceModels": Json::array([
      inference_model_json("claude-sonnet-4-6", supports_1m=true),
      inference_model_json("claude-opus-4-8", supports_1m=true),
      inference_model_json("claude-haiku-4-5", supports_1m=true),
    ]),
  })
}

///|
fn inference_model_json(name : String, supports_1m~ : Bool) -> Json {
  let item : Map[String, Json] = { "name": Json::string(name) }
  if supports_1m {
    item["supports1m"] = Json::boolean(true)
  }
  Json::object(item)
}

///|
async fn write_deployment_mode(path : String, mode : String) -> Unit {
  let mut value = read_json_or_empty(path)
  let obj : Map[String, Json] = match value {
    Object(map) => map
    _ => {}
  }
  obj["deploymentMode"] = Json::string(mode)
  value = Json::object(obj)
  write_json_file(path, value)
}

///|
async fn write_meta(path : String, applied_profile_id : String?) -> Unit {
  let value = read_json_or_empty(path)
  let source : Map[String, Json] = match value {
    Object(obj) => obj
    _ => {}
  }
  let existing_entries = match value {
    Object(obj) =>
      match obj.get("entries") {
        Some(Array(items)) => items
        _ => []
      }
    _ => []
  }
  let entries : Array[Json] = []
  for entry in existing_entries {
    if !meta_entry_has_profile_id(entry) {
      entries.push(entry)
    }
  }
  let obj : Map[String, Json] = {}
  for k, v in source {
    if k != "entries" && k != "appliedId" {
      obj[k] = v
    }
  }
  match applied_profile_id {
    Some(id) => {
      entries.push(
        Json::object({
          "id": Json::string(PROFILE_ID),
          "name": Json::string(PROFILE_NAME),
        }),
      )
      obj["appliedId"] = Json::string(id)
    }
    None =>
      match source.get("appliedId") {
        Some(String(id)) if id == PROFILE_ID =>
          match first_meta_entry_id(entries) {
            Some(next_id) => obj["appliedId"] = Json::string(next_id)
            None => ()
          }
        Some(value) => obj["appliedId"] = value
        None => ()
      }
  }
  obj["entries"] = Json::array(entries)
  write_json_file(path, Json::object(obj))
}

///|
fn first_meta_entry_id(entries : Array[Json]) -> String? {
  for entry in entries {
    match entry {
      Object(obj) =>
        match obj.get("id") {
          Some(String(id)) => return Some(id)
          _ => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn meta_entry_has_profile_id(entry : Json) -> Bool {
  match entry {
    Object(obj) =>
      match obj.get("id") {
        Some(String(id)) => id == PROFILE_ID
        _ => false
      }
    _ => false
  }
}

///|
async fn meta_has_profile_entry(path : String) -> Bool {
  match read_json_or_empty(path) {
    Object(obj) =>
      match obj.get("entries") {
        Some(Array(entries)) => entries.any(meta_entry_has_profile_id)
        _ => false
      }
    _ => false
  }
}

///|
async fn read_applied_id(path : String) -> String? {
  json_object_string(read_json_or_empty(path), "appliedId")
}

///|
fn profile_has_stale_raw_models(profile : Json) -> Bool {
  match profile {
    Object(obj) =>
      match obj.get("inferenceModels") {
        Some(Array(models)) =>
          models.any(item => {
            match inference_model_name(item) {
              Some(model) => !is_claude_safe_model_id(model)
              None => false
            }
          })
        _ => false
      }
    _ => false
  }
}

///|
fn inference_model_name(item : Json) -> String? {
  match item {
    String(model) => Some(model)
    Object(obj) => json_string_from_map(obj, "name")
    _ => None
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
fn json_object_string(value : Json, key : String) -> String? {
  match value {
    Object(obj) => json_string_from_map(obj, key)
    _ => None
  }
}

///|
fn json_string_from_map(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
async fn remove_gateway_enterprise_config(path : String) -> Unit {
  if !@fsx.exists(path) {
    return
  }
  let value = read_json_or_empty(path)
  match value {
    Object(obj) => {
      let clean : Map[String, Json] = {}
      for k, v in obj {
        if k == "enterpriseConfig" {
          match v {
            Object(enterprise) => {
              let clean_enterprise : Map[String, Json] = {}
              for ek, ev in enterprise {
                if !is_gateway_enterprise_config_key(ek) {
                  clean_enterprise[ek] = ev
                }
              }
              if clean_enterprise.keys().head() is Some(_) {
                clean[k] = Json::object(clean_enterprise)
              }
            }
            _ => clean[k] = v
          }
        } else {
          clean[k] = v
        }
      }
      write_json_file(path, Json::object(clean))
    }
    _ => ()
  }
}

///|
fn is_gateway_enterprise_config_key(key : String) -> Bool {
  match key {
    "disableDeploymentModeChooser"
    | "inferenceGatewayApiKey"
    | "inferenceGatewayAuthScheme"
    | "inferenceGatewayBaseUrl"
    | "inferenceProvider" => true
    _ => false
  }
}

///|
async fn read_json_or_empty(path : String) -> Json {
  @json.parse(@fsx.read_file(path)) catch {
    _ => Json::object({})
  }
}

///|
async fn snapshot_files(paths : Array[String]) -> Array[FileSnapshot] {
  let snapshots : Array[FileSnapshot] = []
  for path in paths {
    let content = if (@fsx.exists_as_file(path) catch { _ => false }) {
      Some(@fsx.read_file(path) catch { _ => "" })
    } else {
      None
    }
    snapshots.push({ path, content })
  }
  snapshots
}

///|
async fn restore_file_snapshots(snapshots : Array[FileSnapshot]) -> Unit {
  for snapshot in snapshots {
    match snapshot.content {
      Some(content) => {
        @fsx.make_directory(
          @pathx.dirname(snapshot.path),
          recursive=true,
          exists_ok=true,
        )
        @fsx.write_to_file(snapshot.path, content)
      }
      None =>
        if (@fsx.exists_as_file(snapshot.path) catch { _ => false }) {
          @fsx.remove(snapshot.path)
        }
    }
  }
}

///|
async fn write_json_file(path : String, value : Json) -> Unit {
  @fsx.make_directory(@pathx.dirname(path), recursive=true, exists_ok=true)
  @fsx.write_to_file(path, value.stringify(indent=2) + "\n")
}

///|
fn claude_desktop_paths() -> ClaudeDesktopPaths {
  let home = home_dir()
  let app_support = @pathx.join(home, "Library/Application Support")
  let normal_dir = @pathx.join(app_support, "Claude")
  let threep_dir = @pathx.join(app_support, "Claude-3p")
  let config_library_path = @pathx.join(threep_dir, CONFIG_LIBRARY_DIR)
  {
    normal_config_path: @pathx.join(normal_dir, CONFIG_FILE),
    threep_config_path: @pathx.join(threep_dir, CONFIG_FILE),
    config_library_path,
    profile_path: @pathx.join(config_library_path, PROFILE_ID + ".json"),
    meta_path: @pathx.join(config_library_path, "_meta.json"),
  }
}

///|
fn claude_desktop_active_workspace_root() -> String {
  @os.cwd() catch {
    _ => "."
  }
}

///|
fn gateway_token_path() -> String {
  @moonsuite.product_artifact_for_workspace_root(
    claude_desktop_active_workspace_root(),
    "moongate",
    TOKEN_ARTIFACT,
  )
}

///|
fn home_dir() -> String {
  @os.home() catch {
    _ => "."
  }
}

///|
fn getenv_or_none(key : String) -> String? {
  @os.getenv(key) catch {
    _ => None
  }
}
