///|
const COPILOT_GITHUB_CLIENT_ID = "Iv1.b507a08c87ecfe98"

///|
const COPILOT_GHES_CLIENT_ID = "Ov23li8tweQw6odWQebz"

///|
const COPILOT_DEFAULT_DOMAIN = "github.com"

///|
const COPILOT_CREDENTIALS_ARTIFACT = "auth/copilot-credentials.json"

///|
const COPILOT_EDITOR_VERSION = "vscode/1.110.1"

///|
const COPILOT_PLUGIN_VERSION = "copilot-chat/0.38.2"

///|
const COPILOT_USER_AGENT = "GitHubCopilotChat/0.38.2"

///|
const COPILOT_API_VERSION = "2025-10-01"

///|
const COPILOT_INTEGRATION_ID = "vscode-chat"

///|
priv suberror CopilotAuthError {
  CopilotAuthError(String)
} derive(Debug)

///|
priv struct CopilotCredentials {
  github_token : String
  copilot_token : String
  copilot_token_expires_at : Int64
  account_id : String
  login : String
  avatar_url : String?
  authenticated_at : Int64
  github_domain : String
} derive(ToJson, FromJson)

///|
priv struct CopilotDeviceCodeResponse {
  device_code : String
  user_code : String
  verification_uri : String
  expires_in : Int
  interval : Int
} derive(ToJson)

///|
fn copilot_credentials_path() -> String {
  @moonsuite.product_artifact_for_workspace_root(
    moonstat_active_workspace_root(),
    "moonstat",
    COPILOT_CREDENTIALS_ARTIFACT,
  )
}

///|
fn copilot_now_seconds() -> Int64 {
  @async.now() / 1000L
}

///|
fn copilot_json_string(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn copilot_json_int(obj : Map[String, Json], key : String) -> Int? {
  match obj.get(key) {
    Some(Number(value, ..)) => Some(value.to_int())
    Some(String(value)) =>
      try @string.parse_int(value, base=10) catch {
        _ => None
      } noraise {
        parsed => Some(parsed)
      }
    _ => None
  }
}

///|
fn copilot_json_int64(obj : Map[String, Json], key : String) -> Int64? {
  match obj.get(key) {
    Some(Number(value, ..)) => Some(value.to_int64())
    Some(String(value)) =>
      try @string.parse_int64(value, base=10) catch {
        _ => None
      } noraise {
        parsed => Some(parsed)
      }
    _ => None
  }
}

///|
fn copilot_json_bool(obj : Map[String, Json], key : String) -> Bool? {
  match obj.get(key) {
    Some(value) if value == Json::boolean(true) => Some(true)
    Some(value) if value == Json::boolean(false) => Some(false)
    Some(String("true")) => Some(true)
    Some(String("false")) => Some(false)
    _ => None
  }
}

///|
fn copilot_url_encode(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    match c {
      'A'..='Z' | 'a'..='z' | '0'..='9' | '-' | '_' | '.' | '~' =>
        buf.write_char(c)
      _ => {
        let bytes = @encoding/utf8.encode(c.to_string())
        for b in bytes {
          let hex = b.to_int()
          let high = (hex >> 4) & 0xF
          let low = hex & 0xF
          let hex_char = fn(n : Int) -> Char {
            if n < 10 {
              ('0'.to_int() + n).unsafe_to_char()
            } else {
              ('A'.to_int() + n - 10).unsafe_to_char()
            }
          }
          buf.write_char('%')
          buf.write_char(hex_char(high))
          buf.write_char(hex_char(low))
        }
      }
    }
  }
  buf.to_string()
}

///|
fn copilot_form_body(params : Array[(String, String)]) -> String {
  params
  .iter()
  .map(fn(param) {
    "\{copilot_url_encode(param.0)}=\{copilot_url_encode(param.1)}"
  })
  .collect()
  .join("&")
}

///|
fn copilot_normalize_domain(raw : String?) -> String {
  let value = raw.unwrap_or(COPILOT_DEFAULT_DOMAIN).trim()
  let no_protocol = if value.has_prefix("https://") {
    value[8:].to_owned()
  } else if value.has_prefix("http://") {
    value[7:].to_owned()
  } else {
    value.to_owned()
  }
  let mut end = no_protocol.length()
  for sep in ["/", "?", "#"] {
    match no_protocol.find(sep) {
      Some(index) if index < end => end = index
      _ => ()
    }
  }
  let host = no_protocol[:end].to_owned().trim().to_lower()
  if host.is_empty() || host.contains("@") {
    COPILOT_DEFAULT_DOMAIN
  } else {
    host.to_owned()
  }
}

///|
fn copilot_is_ghes(domain : String) -> Bool {
  domain != COPILOT_DEFAULT_DOMAIN
}

///|
fn copilot_github_client_id(domain : String) -> String {
  if copilot_is_ghes(domain) {
    COPILOT_GHES_CLIENT_ID
  } else {
    COPILOT_GITHUB_CLIENT_ID
  }
}

///|
fn copilot_github_api_base(domain : String) -> String {
  if copilot_is_ghes(domain) {
    "https://\{domain}/api/v3"
  } else {
    "https://api.github.com"
  }
}

///|
fn copilot_api_base(domain : String) -> String {
  if copilot_is_ghes(domain) {
    "https://copilot-api.\{domain}"
  } else {
    "https://api.githubcopilot.com"
  }
}

///|
fn copilot_account_id(domain : String, user_id : String) -> String {
  if copilot_is_ghes(domain) {
    "\{domain}:\{user_id}"
  } else {
    user_id
  }
}

///|
fn copilot_account_json(credentials : CopilotCredentials) -> Json {
  {
    "id": Json::string(credentials.account_id),
    "provider": Json::string("github_copilot"),
    "login": Json::string(credentials.login),
    "avatar_url": match credentials.avatar_url {
      Some(value) => Json::string(value)
      None => Json::null()
    },
    "authenticated_at": Json::number(credentials.authenticated_at.to_double()),
    "is_default": Json::boolean(true),
    "github_domain": Json::string(credentials.github_domain),
  }.to_json()
}

///|
fn copilot_auth_status_json(credentials : CopilotCredentials?) -> Json {
  let accounts = match credentials {
    Some(credentials) => [copilot_account_json(credentials)]
    None => []
  }
  {
    "provider": Json::string("github_copilot"),
    "accounts": Json::array(accounts),
    "default_account_id": match credentials {
      Some(credentials) => Json::string(credentials.account_id)
      None => Json::null()
    },
    "migration_error": Json::null(),
    "authenticated": Json::boolean(credentials is Some(_)),
    "username": match credentials {
      Some(credentials) => Json::string(credentials.login)
      None => Json::null()
    },
    "expires_at": match credentials {
      Some(credentials) =>
        Json::number(credentials.copilot_token_expires_at.to_double())
      None => Json::null()
    },
  }.to_json()
}

///|
async fn copilot_save_credentials(
  credentials : CopilotCredentials,
) -> Unit raise Error {
  let path = copilot_credentials_path()
  let dir = @pathx.dirname(path)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  @fsx.write_to_file(path, credentials.to_json().stringify(), create=0o600)
}

///|
async fn copilot_load_credentials() -> CopilotCredentials raise Error {
  let path = copilot_credentials_path()
  if !@fsx.exists_as_file(path) {
    raise CopilotAuthError("Copilot credentials file not found")
  }
  @json.from_json(@json.parse(@fsx.read_file(path)))
}

///|
async fn copilot_try_load_credentials() -> CopilotCredentials? {
  try copilot_load_credentials() catch {
    _ => None
  } noraise {
    credentials => Some(credentials)
  }
}

///|
async fn copilot_delete_credentials() -> Unit {
  try {
    let path = copilot_credentials_path()
    if @fsx.exists_as_file(path) {
      @fsx.remove(path)
    }
  } catch {
    _ => ()
  }
}

///|
fn parse_copilot_device_code_response(
  json : Json,
) -> CopilotDeviceCodeResponse raise Error {
  guard json is Object(obj) else {
    raise CopilotAuthError("Device Code response is not an object")
  }
  guard copilot_json_string(obj, "device_code") is Some(device_code) else {
    raise CopilotAuthError("Device Code response missing device_code")
  }
  guard copilot_json_string(obj, "user_code") is Some(user_code) else {
    raise CopilotAuthError("Device Code response missing user_code")
  }
  guard copilot_json_string(obj, "verification_uri") is Some(verification_uri) else {
    raise CopilotAuthError("Device Code response missing verification_uri")
  }
  {
    device_code,
    user_code,
    verification_uri,
    expires_in: copilot_json_int(obj, "expires_in").unwrap_or(900),
    interval: copilot_json_int(obj, "interval").unwrap_or(5),
  }
}

///|
pub async fn copilot_start_device_flow(
  github_domain : String?,
) -> Result[Json, String] {
  let domain = copilot_normalize_domain(github_domain)
  let body = copilot_form_body([
    ("client_id", copilot_github_client_id(domain)),
    ("scope", "read:user"),
  ])
  try {
    let (response, data) = @http.post(
      "https://\{domain}/login/device/code",
      body,
      headers={
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "User-Agent": COPILOT_USER_AGENT,
      },
    )
    guard response.code is (200..=299) else {
      return Err(
        "GitHub device code request failed: \{response.code} - \{data.text()}",
      )
    }
    Ok(parse_copilot_device_code_response(data.json()).to_json())
  } catch {
    error => Err("\{error}")
  }
}

///|
fn copilot_pending_error(error : String?) -> Bool {
  error == Some("authorization_pending") || error == Some("slow_down")
}

///|
async fn copilot_poll_github_token(
  device_code : String,
  domain : String,
) -> Result[String?, String] {
  let body = copilot_form_body([
    ("client_id", copilot_github_client_id(domain)),
    ("device_code", device_code),
    ("grant_type", "urn:ietf:params:oauth:grant-type:device_code"),
  ])
  try {
    let (response, data) = @http.post(
      "https://\{domain}/login/oauth/access_token",
      body,
      headers={
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "User-Agent": COPILOT_USER_AGENT,
      },
    )
    guard response.code is (200..=299) else {
      return Err("GitHub token poll failed: \{response.code} - \{data.text()}")
    }
    guard data.json() is Object(obj) else {
      return Err("GitHub token response is not an object")
    }
    match copilot_json_string(obj, "access_token") {
      Some(token) => Ok(Some(token))
      None =>
        if copilot_pending_error(copilot_json_string(obj, "error")) {
          Ok(None)
        } else {
          Err(
            copilot_json_string(obj, "error_description").unwrap_or(
              copilot_json_string(obj, "error").unwrap_or(
                "GitHub token response missing access_token",
              ),
            ),
          )
        }
    }
  } catch {
    error => Err("\{error}")
  }
}

///|
async fn copilot_fetch_user(
  github_token : String,
  domain : String,
) -> Result[(String, String, String?), String] {
  try {
    let (response, data) = @http.get(
      "\{copilot_github_api_base(domain)}/user",
      headers={
        "Authorization": "Bearer \{github_token}",
        "Accept": "application/json",
        "User-Agent": COPILOT_USER_AGENT,
      },
    )
    guard response.code is (200..=299) else {
      return Err(
        "GitHub user request failed: \{response.code} - \{data.text()}",
      )
    }
    guard data.json() is Object(obj) else {
      return Err("GitHub user response is not an object")
    }
    let id = match obj.get("id") {
      Some(Number(value, ..)) => value.to_int64().to_string()
      Some(String(value)) => value
      _ => return Err("GitHub user response missing id")
    }
    guard copilot_json_string(obj, "login") is Some(login) else {
      return Err("GitHub user response missing login")
    }
    Ok((id, login, copilot_json_string(obj, "avatar_url")))
  } catch {
    error => Err("\{error}")
  }
}

///|
async fn copilot_fetch_copilot_token(
  github_token : String,
  domain : String,
) -> Result[(String, Int64), String] {
  if copilot_is_ghes(domain) {
    return Ok((github_token, copilot_now_seconds() + 3600L))
  }
  try {
    let (response, data) = @http.get(
      "\{copilot_github_api_base(domain)}/copilot_internal/v2/token",
      headers={
        "Authorization": "Bearer \{github_token}",
        "Accept": "application/json",
        "User-Agent": COPILOT_USER_AGENT,
        "Editor-Version": COPILOT_EDITOR_VERSION,
        "Editor-Plugin-Version": COPILOT_PLUGIN_VERSION,
        "Copilot-Integration-Id": COPILOT_INTEGRATION_ID,
      },
    )
    guard response.code is (200..=299) else {
      return Err(
        "Copilot token request failed: \{response.code} - \{data.text()}",
      )
    }
    guard data.json() is Object(obj) else {
      return Err("Copilot token response is not an object")
    }
    guard copilot_json_string(obj, "token") is Some(token) else {
      return Err("Copilot token response missing token")
    }
    guard copilot_json_int64(obj, "expires_at") is Some(expires_at) else {
      return Err("Copilot token response missing expires_at")
    }
    Ok((token, expires_at))
  } catch {
    error => Err("\{error}")
  }
}

///|
pub async fn copilot_poll_for_account(
  device_code : String,
  github_domain : String?,
) -> Result[Json?, String] {
  let domain = copilot_normalize_domain(github_domain)
  match copilot_poll_github_token(device_code, domain) {
    Ok(Some(github_token)) => {
      let (user_id, login, avatar_url) = match
        copilot_fetch_user(github_token, domain) {
        Ok(user) => user
        Err(error) => return Err(error)
      }
      let (copilot_token, expires_at) = match
        copilot_fetch_copilot_token(github_token, domain) {
        Ok(token) => token
        Err(error) => return Err(error)
      }
      let credentials : CopilotCredentials = {
        github_token,
        copilot_token,
        copilot_token_expires_at: expires_at,
        account_id: copilot_account_id(domain, user_id),
        login,
        avatar_url,
        authenticated_at: copilot_now_seconds(),
        github_domain: domain,
      }
      copilot_save_credentials(credentials) catch {
        error => return Err("\{error}")
      }
      Ok(Some(copilot_account_json(credentials)))
    }
    Ok(None) => Ok(None)
    Err(error) => Err(error)
  }
}

///|
pub async fn copilot_list_accounts() -> Json {
  match copilot_try_load_credentials() {
    Some(credentials) => Json::array([copilot_account_json(credentials)])
    None => Json::array([])
  }
}

///|
pub async fn copilot_get_auth_status() -> Json {
  copilot_auth_status_json(copilot_try_load_credentials())
}

///|
pub async fn copilot_is_authenticated() -> Bool {
  copilot_try_load_credentials() is Some(_)
}

///|
pub async fn copilot_logout() -> Json {
  copilot_delete_credentials()
  Json::null()
}

///|
pub async fn copilot_remove_account(
  account_id : String,
) -> Result[Json, String] {
  match copilot_try_load_credentials() {
    Some(credentials) if credentials.account_id == account_id => {
      copilot_delete_credentials()
      Ok(Json::null())
    }
    _ => Err("Account not found: \{account_id}")
  }
}

///|
pub async fn copilot_set_default_account(
  account_id : String,
) -> Result[Json, String] {
  match copilot_try_load_credentials() {
    Some(credentials) if credentials.account_id == account_id =>
      Ok(Json::null())
    _ => Err("Account not found: \{account_id}")
  }
}

///|
async fn copilot_valid_credentials(
  account_id : String?,
) -> Result[CopilotCredentials, String] {
  guard copilot_try_load_credentials() is Some(credentials) else {
    return Err("GitHub Copilot is not authenticated")
  }
  match account_id {
    Some(id) if id != credentials.account_id =>
      return Err("Account not found: \{id}")
    _ => ()
  }
  if copilot_is_ghes(credentials.github_domain) ||
    credentials.copilot_token_expires_at - 60L > copilot_now_seconds() {
    return Ok(credentials)
  }
  match
    copilot_fetch_copilot_token(
      credentials.github_token,
      credentials.github_domain,
    ) {
    Ok((token, expires_at)) => {
      let refreshed = {
        ..credentials,
        copilot_token: token,
        copilot_token_expires_at: expires_at,
      }
      copilot_save_credentials(refreshed) catch {
        error => return Err("\{error}")
      }
      Ok(refreshed)
    }
    Err(error) => Err(error)
  }
}

///|
pub async fn copilot_get_token(account_id : String?) -> Result[Json, String] {
  match copilot_valid_credentials(account_id) {
    Ok(credentials) => Ok(Json::string(credentials.copilot_token))
    Err(error) => Err(error)
  }
}

///|
fn copilot_headers(credentials : CopilotCredentials) -> Map[String, String] {
  {
    "Authorization": "Bearer \{credentials.copilot_token}",
    "Content-Type": "application/json",
    "copilot-integration-id": COPILOT_INTEGRATION_ID,
    "editor-version": COPILOT_EDITOR_VERSION,
    "editor-plugin-version": COPILOT_PLUGIN_VERSION,
    "user-agent": COPILOT_USER_AGENT,
    "x-github-api-version": COPILOT_API_VERSION,
  }
}

///|
pub async fn copilot_get_models(account_id : String?) -> Result[Json, String] {
  let credentials = match copilot_valid_credentials(account_id) {
    Ok(credentials) => credentials
    Err(error) => return Err(error)
  }
  try {
    let (response, data) = @http.get(
      "\{copilot_api_base(credentials.github_domain)}/models",
      headers=copilot_headers(credentials),
    )
    guard response.code is (200..=299) else {
      return Err(
        "Copilot models request failed: \{response.code} - \{data.text()}",
      )
    }
    let parsed = data.json()
    guard parsed is Object(obj) else { return Ok(parsed) }
    guard obj.get("data") is Some(Array(items)) else { return Ok(parsed) }
    let models : Array[Json] = []
    for item in items {
      guard item is Object(model_obj) else { continue }
      let enabled = copilot_json_bool(model_obj, "model_picker_enabled").unwrap_or(
        true,
      )
      if enabled {
        models.push(
          {
            "id": Json::string(
              copilot_json_string(model_obj, "id").unwrap_or(""),
            ),
            "name": Json::string(
              copilot_json_string(model_obj, "name").unwrap_or(""),
            ),
            "vendor": Json::string(
              copilot_json_string(model_obj, "vendor").unwrap_or(""),
            ),
            "model_picker_enabled": Json::boolean(enabled),
          }.to_json(),
        )
      }
    }
    Ok(Json::array(models))
  } catch {
    error => Err("\{error}")
  }
}

///|
pub async fn copilot_get_usage(account_id : String?) -> Result[Json, String] {
  let credentials = match copilot_valid_credentials(account_id) {
    Ok(credentials) => credentials
    Err(error) => return Err(error)
  }
  try {
    let (response, data) = @http.get(
      "\{copilot_github_api_base(credentials.github_domain)}/copilot_internal/user",
      headers={
        "Authorization": "token \{credentials.github_token}",
        "Content-Type": "application/json",
        "editor-version": COPILOT_EDITOR_VERSION,
        "editor-plugin-version": COPILOT_PLUGIN_VERSION,
        "user-agent": COPILOT_USER_AGENT,
        "x-github-api-version": COPILOT_API_VERSION,
      },
    )
    guard response.code is (200..=299) else {
      return Err(
        "Copilot usage request failed: \{response.code} - \{data.text()}",
      )
    }
    Ok(data.json())
  } catch {
    error => Err("\{error}")
  }
}
