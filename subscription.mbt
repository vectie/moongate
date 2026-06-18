///|
const MOON_QUOTA_TIER_FIVE_HOUR = "five_hour"

///|
const MOON_QUOTA_TIER_SEVEN_DAY = "seven_day"

///|
const MOON_QUOTA_TIER_SEVEN_DAY_OPUS = "seven_day_opus"

///|
const MOON_QUOTA_TIER_SEVEN_DAY_SONNET = "seven_day_sonnet"

///|
const MOON_QUOTA_TIER_GEMINI_PRO = "gemini_pro"

///|
const MOON_QUOTA_TIER_GEMINI_FLASH = "gemini_flash"

///|
const MOON_QUOTA_TIER_GEMINI_FLASH_LITE = "gemini_flash_lite"

///|
const MOONSTAT_CODEX_OAUTH_RELOGIN_MESSAGE = "Codex OAuth access token expired or rejected. Please re-login via moonstat."

///|
priv struct MoonTokenCredentials {
  token : String?
  refresh_token : String?
  account_id : String?
  status : CredentialStatus
  message : String?
}

///|
priv struct MoonGeminiOAuthClient {
  client_id : String
  client_secret : String
}

///|
fn moon_quota_now_millis() -> Int64 {
  @os.unix_seconds().to_int64() * 1000L
}

///|
fn moonstat_codex_oauth_relogin_message() -> String {
  MOONSTAT_CODEX_OAUTH_RELOGIN_MESSAGE
}

///|
fn moon_quota_error(
  tool : String,
  status : CredentialStatus,
  message : String,
) -> SubscriptionQuota {
  SubscriptionQuota::new(
    tool,
    credential_status=status,
    credential_message=Some(message),
    success=false,
    error=Some(message),
    queried_at=Some(moon_quota_now_millis()),
  )
}

///|
async fn moon_get_subscription_quota(tool : String) -> SubscriptionQuota {
  match tool {
    "claude" => moon_get_claude_subscription_quota()
    "codex" => moon_get_codex_subscription_quota()
    "gemini" => moon_get_gemini_subscription_quota()
    _ => SubscriptionQuota::not_found(tool)
  }
}

///|
async fn moon_get_claude_subscription_quota() -> SubscriptionQuota {
  let creds = moon_read_claude_credentials()
  match creds.status {
    NotFound => SubscriptionQuota::not_found("claude")
    ParseError =>
      moon_quota_error(
        "claude",
        ParseError,
        creds.message.unwrap_or("Failed to parse credentials"),
      )
    Expired => {
      match creds.token {
        Some(token) => {
          let result = moon_query_claude_quota(token)
          if result.success {
            return result
          }
        }
        None => ()
      }
      moon_quota_error(
        "claude",
        Expired,
        creds.message.unwrap_or("OAuth token has expired"),
      )
    }
    Valid =>
      match creds.token {
        Some(token) => moon_query_claude_quota(token)
        None =>
          moon_quota_error(
            "claude",
            ParseError,
            "accessToken is empty or missing",
          )
      }
  }
}

///|
async fn moon_get_codex_subscription_quota() -> SubscriptionQuota {
  let creds = moon_read_codex_credentials()
  match creds.status {
    NotFound => SubscriptionQuota::not_found("codex")
    ParseError =>
      moon_quota_error(
        "codex",
        ParseError,
        creds.message.unwrap_or("Failed to parse credentials"),
      )
    Expired => {
      match creds.token {
        Some(token) => {
          let result = moon_query_codex_quota(
            token,
            creds.account_id,
            "codex",
            "Authentication failed. Please re-login with Codex CLI.",
          )
          if result.success {
            return result
          }
        }
        None => ()
      }
      moon_quota_error(
        "codex",
        Expired,
        creds.message.unwrap_or("Codex OAuth token may be stale"),
      )
    }
    Valid =>
      match creds.token {
        Some(token) =>
          moon_query_codex_quota(
            token,
            creds.account_id,
            "codex",
            "Authentication failed. Please re-login with Codex CLI.",
          )
        None =>
          moon_quota_error(
            "codex",
            ParseError,
            "access_token is empty or missing",
          )
      }
  }
}

///|
async fn moon_get_codex_oauth_quota(account_id : String?) -> SubscriptionQuota {
  let creds = moon_read_codex_credentials()
  match creds.status {
    NotFound => SubscriptionQuota::not_found("codex_oauth")
    ParseError =>
      moon_quota_error(
        "codex_oauth",
        ParseError,
        creds.message.unwrap_or("Failed to parse credentials"),
      )
    Expired => {
      match creds.token {
        Some(token) => {
          let result = moon_query_codex_quota(
            token,
            moon_resolve_codex_oauth_account(account_id, creds.account_id),
            "codex_oauth",
            moonstat_codex_oauth_relogin_message(),
          )
          if result.success {
            return result
          }
        }
        None => ()
      }
      moon_quota_error(
        "codex_oauth",
        Expired,
        creds.message.unwrap_or("Codex OAuth token unavailable"),
      )
    }
    Valid =>
      match creds.token {
        Some(token) =>
          moon_query_codex_quota(
            token,
            moon_resolve_codex_oauth_account(account_id, creds.account_id),
            "codex_oauth",
            moonstat_codex_oauth_relogin_message(),
          )
        None =>
          moon_quota_error(
            "codex_oauth",
            ParseError,
            "access_token is empty or missing",
          )
      }
  }
}

///|
async fn moon_get_codex_oauth_models(
  account_id : String?,
) -> Result[Array[FetchedModel], String] {
  let creds = moon_read_codex_credentials()
  let id = match
    moon_resolve_codex_oauth_account(account_id, creds.account_id) {
    Some(value) if !value.trim().is_empty() => value
    _ => return Err("No ChatGPT account available")
  }
  match creds.status {
    NotFound => Err(creds.message.unwrap_or("No ChatGPT account available"))
    ParseError =>
      Err(creds.message.unwrap_or("Failed to parse Codex auth JSON"))
    Expired | Valid =>
      match creds.token {
        Some(token) => fetch_codex_oauth_models_with_token(token, id)
        None =>
          Err("Codex OAuth token unavailable: access_token is empty or missing")
      }
  }
}

///|
fn moon_resolve_codex_oauth_account(
  explicit : String?,
  fallback : String?,
) -> String? {
  match explicit {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed.is_empty() {
        fallback
      } else {
        Some(trimmed)
      }
    }
    None => fallback
  }
}

///|
async fn moon_get_gemini_subscription_quota() -> SubscriptionQuota {
  let creds = moon_read_gemini_credentials()
  match creds.status {
    NotFound => SubscriptionQuota::not_found("gemini")
    ParseError =>
      moon_quota_error(
        "gemini",
        ParseError,
        creds.message.unwrap_or("Failed to parse credentials"),
      )
    Expired => {
      match creds.refresh_token {
        Some(refresh_token) =>
          match moon_refresh_gemini_token(refresh_token) {
            Some(token) => return moon_query_gemini_quota(token)
            None => ()
          }
        None => ()
      }
      match creds.token {
        Some(token) => {
          let result = moon_query_gemini_quota(token)
          if result.success {
            return result
          }
        }
        None => ()
      }
      moon_quota_error(
        "gemini",
        Expired,
        creds.message.unwrap_or("Gemini OAuth token has expired"),
      )
    }
    Valid =>
      match creds.token {
        Some(token) => moon_query_gemini_quota(token)
        None =>
          moon_quota_error(
            "gemini",
            ParseError,
            "access_token is empty or missing",
          )
      }
  }
}

///|
async fn moon_security_password(service : String, account? : String) -> String? {
  let args : Array[StringView] = ["find-generic-password", "-s", service]
  match account {
    Some(account) => {
      args.push("-a")
      args.push(account)
    }
    None => ()
  }
  args.push("-w")
  let result = @spawn.spawn("security", args, timeout=3000) catch {
    _ => return None
  }
  if result.status != 0 {
    return None
  }
  let value = result.stdout.trim()
  if value.is_empty() {
    None
  } else {
    Some(value.to_owned())
  }
}

///|
async fn moon_read_claude_credentials() -> MoonTokenCredentials {
  match moon_security_password("Claude Code-credentials") {
    Some(content) => return moon_parse_claude_credentials_json(content)
    None => ()
  }
  let path = @pathx.join(moon_quota_home_dir(), ".claude/.credentials.json")
  if !@fsx.exists_as_file(path) {
    return moon_token_credentials(status=NotFound)
  }
  let content = @fsx.read_file(path) catch {
    err =>
      return moon_token_credentials(
        status=ParseError,
        message=Some("Failed to read credentials file: \{err}"),
      )
  }
  moon_parse_claude_credentials_json(content)
}

///|
fn moon_parse_claude_credentials_json(content : String) -> MoonTokenCredentials {
  let parsed = @json.parse(content) catch {
    err =>
      return moon_token_credentials(
        status=ParseError,
        message=Some("Failed to parse credentials JSON: \{err}"),
      )
  }
  guard parsed is Object(root) else {
    return moon_token_credentials(
      status=ParseError,
      message=Some("Failed to parse credentials JSON: expected object"),
    )
  }
  let entry = match root.get("claudeAiOauth") {
    Some(Object(entry)) => entry
    _ =>
      match root.get("claude.ai_oauth") {
        Some(Object(entry)) => entry
        _ =>
          return moon_token_credentials(
            status=ParseError,
            message=Some("No OAuth entry found in credentials"),
          )
      }
  }
  guard json_string_from_map(entry, "accessToken") is Some(token) &&
    !token.is_empty() else {
    return moon_token_credentials(
      status=ParseError,
      message=Some("accessToken is empty or missing"),
    )
  }
  match entry.get("expiresAt") {
    Some(value) if moon_quota_token_expired(value) =>
      moon_token_credentials(
        token=Some(token),
        status=Expired,
        message=Some("OAuth token has expired"),
      )
    _ => moon_token_credentials(token=Some(token), status=Valid)
  }
}

///|
async fn moon_read_codex_credentials() -> MoonTokenCredentials {
  match moon_security_password("Codex Auth") {
    Some(content) => return moon_parse_codex_credentials_json(content)
    None => ()
  }
  let path = @pathx.join(moon_quota_home_dir(), ".codex/auth.json")
  if !@fsx.exists_as_file(path) {
    return moon_token_credentials(status=NotFound)
  }
  let content = @fsx.read_file(path) catch {
    err =>
      return moon_token_credentials(
        status=ParseError,
        message=Some("Failed to read Codex auth file: \{err}"),
      )
  }
  moon_parse_codex_credentials_json(content)
}

///|
fn moon_parse_codex_credentials_json(content : String) -> MoonTokenCredentials {
  let parsed = @json.parse(content) catch {
    err =>
      return moon_token_credentials(
        status=ParseError,
        message=Some("Failed to parse Codex auth JSON: \{err}"),
      )
  }
  guard parsed is Object(root) else {
    return moon_token_credentials(
      status=ParseError,
      message=Some("Failed to parse Codex auth JSON: expected object"),
    )
  }
  if json_string_from_map(root, "auth_mode") != Some("chatgpt") {
    return moon_token_credentials(
      status=NotFound,
      message=Some("Codex not using OAuth mode"),
    )
  }
  guard root.get("tokens") is Some(Object(tokens)) else {
    return moon_token_credentials(
      status=ParseError,
      message=Some("No tokens in Codex auth"),
    )
  }
  guard json_string_from_map(tokens, "access_token") is Some(token) &&
    !token.is_empty() else {
    return moon_token_credentials(
      status=ParseError,
      message=Some("access_token is empty or missing"),
    )
  }
  let status = match json_string_from_map(root, "last_refresh") {
    Some(last_refresh) if moon_codex_token_stale(last_refresh) =>
      CredentialStatus::Expired
    _ => Valid
  }
  moon_token_credentials(
    token=Some(token),
    account_id=json_string_from_map(tokens, "account_id"),
    status~,
    message=if status == Expired {
      Some("Codex token may be stale (>8 days since last refresh)")
    } else {
      None
    },
  )
}

///|
async fn moon_read_gemini_credentials() -> MoonTokenCredentials {
  match moon_security_password("gemini-cli-oauth", account="main-account") {
    Some(content) => return moon_parse_gemini_keychain_json(content)
    None => ()
  }
  let path = @pathx.join(moon_quota_home_dir(), ".gemini/oauth_creds.json")
  if !@fsx.exists_as_file(path) {
    return moon_token_credentials(status=NotFound)
  }
  let content = @fsx.read_file(path) catch {
    err =>
      return moon_token_credentials(
        status=ParseError,
        message=Some("Failed to read Gemini credentials: \{err}"),
      )
  }
  moon_parse_gemini_file_json(content)
}

///|
fn moon_parse_gemini_keychain_json(content : String) -> MoonTokenCredentials {
  let parsed = @json.parse(content) catch {
    err =>
      return moon_token_credentials(
        status=ParseError,
        message=Some("Failed to parse Gemini keychain JSON: \{err}"),
      )
  }
  guard parsed is Object(root) else {
    return moon_token_credentials(
      status=ParseError,
      message=Some("Failed to parse Gemini keychain JSON: expected object"),
    )
  }
  match root.get("token") {
    Some(Object(token)) => {
      guard json_string_from_map(token, "accessToken") is Some(access_token) &&
        !access_token.is_empty() else {
        return moon_token_credentials(
          refresh_token=json_string_from_map(token, "refreshToken"),
          status=ParseError,
          message=Some("accessToken is empty or missing"),
        )
      }
      match json_int64_from_map(token, "expiresAt") {
        Some(expires_at) if expires_at < moon_quota_now_millis() =>
          moon_token_credentials(
            token=Some(access_token),
            refresh_token=json_string_from_map(token, "refreshToken"),
            status=Expired,
            message=Some("Gemini access token has expired"),
          )
        _ =>
          moon_token_credentials(
            token=Some(access_token),
            refresh_token=json_string_from_map(token, "refreshToken"),
            status=Valid,
          )
      }
    }
    _ => moon_parse_gemini_file_json(content)
  }
}

///|
fn moon_parse_gemini_file_json(content : String) -> MoonTokenCredentials {
  let parsed = @json.parse(content) catch {
    err =>
      return moon_token_credentials(
        status=ParseError,
        message=Some("Failed to parse Gemini credentials: \{err}"),
      )
  }
  guard parsed is Object(root) else {
    return moon_token_credentials(
      status=ParseError,
      message=Some("Failed to parse Gemini credentials: expected object"),
    )
  }
  guard json_string_from_map(root, "access_token") is Some(access_token) &&
    !access_token.is_empty() else {
    return moon_token_credentials(
      refresh_token=json_string_from_map(root, "refresh_token"),
      status=ParseError,
      message=Some("access_token is empty or missing"),
    )
  }
  match json_int64_from_map(root, "expiry_date") {
    Some(expiry_date) if expiry_date < moon_quota_now_millis() =>
      moon_token_credentials(
        token=Some(access_token),
        refresh_token=json_string_from_map(root, "refresh_token"),
        status=Expired,
        message=Some("Gemini access token has expired"),
      )
    _ =>
      moon_token_credentials(
        token=Some(access_token),
        refresh_token=json_string_from_map(root, "refresh_token"),
        status=Valid,
      )
  }
}

///|
fn moon_token_credentials(
  token? : String? = None,
  refresh_token? : String? = None,
  account_id? : String? = None,
  status~ : CredentialStatus,
  message? : String? = None,
) -> MoonTokenCredentials {
  { token, refresh_token, account_id, status, message }
}

///|
fn moon_quota_home_dir() -> String {
  @os.home() catch {
    _ => "."
  }
}

///|
fn moon_quota_token_expired(value : Json) -> Bool {
  let now = @os.unix_seconds()
  match value {
    Number(v, ..) => {
      let seconds = if v > 1000000000000.0 {
        (v / 1000.0).to_int()
      } else {
        v.to_int()
      }
      seconds < now
    }
    String(s) =>
      moon_parse_rfc3339_date_prefix_seconds(s) is Some(ts) && ts < now
    _ => false
  }
}

///|
fn moon_codex_token_stale(last_refresh : String) -> Bool {
  match moon_parse_rfc3339_date_prefix_seconds(last_refresh) {
    Some(ts) => @os.unix_seconds() - ts > 8 * 24 * 3600
    None => false
  }
}

///|
fn moon_parse_rfc3339_date_prefix_seconds(value : String) -> Int? {
  parse_session_timestamp_seconds(value)
}

///|
async fn moon_query_claude_quota(token : String) -> SubscriptionQuota {
  let result = moon_fetch_json_get(
    "https://api.anthropic.com/api/oauth/usage",
    {
      "Authorization": "Bearer \{token}",
      "anthropic-beta": "oauth-2025-04-20",
      "Accept": "application/json",
    },
  )
  match result {
    Err(error) => moon_quota_error("claude", error.status, error.message)
    Ok(body) => moon_parse_claude_quota(body)
  }
}

///|
async fn moon_query_codex_quota(
  token : String,
  account_id : String?,
  tool_label : String,
  expired_message : String,
) -> SubscriptionQuota {
  let headers : Map[String, String] = {
    "Authorization": "Bearer \{token}",
    "User-Agent": "codex-cli",
    "Accept": "application/json",
  }
  match account_id {
    Some(id) => headers["ChatGPT-Account-Id"] = id
    None => ()
  }
  let result = moon_fetch_json_get(
    "https://chatgpt.com/backend-api/wham/usage",
    headers,
    expired_message~,
  )
  match result {
    Err(error) => moon_quota_error(tool_label, error.status, error.message)
    Ok(body) => moon_parse_codex_quota(body, tool_label)
  }
}

///|
async fn moon_query_gemini_quota(token : String) -> SubscriptionQuota {
  let headers : Map[String, String] = {
    "Authorization": "Bearer \{token}",
    "Content-Type": "application/json",
  }
  let load_result = moon_fetch_json_post(
    "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist",
    {
      "metadata": Json::object({
        "ideType": "GEMINI_CLI",
        "pluginType": "GEMINI",
      }),
    }
    .to_json()
    .stringify(),
    headers,
    expired_message="Authentication failed. Please re-login with Gemini CLI.",
    network_label=Some("loadCodeAssist"),
  )
  let project_id = match load_result {
    Err(error) => return moon_quota_error("gemini", error.status, error.message)
    Ok(body) => moon_gemini_project_id(body)
  }
  let quota_body : Map[String, Json] = {}
  match project_id {
    Some(project_id) => quota_body["project"] = Json::string(project_id)
    None => ()
  }
  let quota_result = moon_fetch_json_post(
    "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota",
    Json::object(quota_body).stringify(),
    { "Authorization": "Bearer \{token}", "Content-Type": "application/json" },
    network_label=Some("retrieveUserQuota"),
  )
  match quota_result {
    Err(error) => moon_quota_error("gemini", error.status, error.message)
    Ok(body) => moon_parse_gemini_quota(body)
  }
}

///|
async fn moon_refresh_gemini_token(refresh_token : String) -> String? {
  guard moon_gemini_oauth_client() is Some(client) else { return None }
  let body = [
    moon_form_pair("client_id", client.client_id),
    moon_form_pair("client_secret", client.client_secret),
    moon_form_pair("refresh_token", refresh_token),
    moon_form_pair("grant_type", "refresh_token"),
  ].join("&")
  let (response, data) = @http.post(
    "https://oauth2.googleapis.com/token",
    body,
    headers={ "Content-Type": "application/x-www-form-urlencoded" },
  ) catch {
    _ => return None
  }
  if !(response.code is (200..=299)) {
    return None
  }
  match data.json() {
    Object(obj) => json_string_from_map(obj, "access_token")
    _ => None
  }
}

///|
fn moon_gemini_oauth_client() -> MoonGeminiOAuthClient? {
  guard moon_env_first_non_empty([
      "MOONSTAT_GEMINI_OAUTH_CLIENT_ID", "GEMINI_OAUTH_CLIENT_ID", "GEMINI_CLI_OAUTH_CLIENT_ID",
    ])
    is Some(client_id) &&
    moon_env_first_non_empty([
      "MOONSTAT_GEMINI_OAUTH_CLIENT_SECRET", "GEMINI_OAUTH_CLIENT_SECRET", "GEMINI_CLI_OAUTH_CLIENT_SECRET",
    ])
    is Some(client_secret) else {
    return None
  }
  Some({ client_id, client_secret })
}

///|
fn moon_env_first_non_empty(keys : Array[StringView]) -> String? {
  let mut i = 0
  while i < keys.length() {
    let value = @os.getenv(keys[i]) catch { _ => None }
    match value {
      Some(value) => {
        let trimmed = value.trim()
        if !trimmed.is_empty() {
          return Some(trimmed.to_owned())
        }
      }
      None => ()
    }
    i = i + 1
  }
  None
}

///|
priv struct MoonQuotaFetchError {
  status : CredentialStatus
  message : String
}

///|
async fn moon_fetch_json_get(
  url : String,
  headers : Map[String, String],
  expired_message? : String = "Authentication failed. Please re-login.",
) -> Result[Json, MoonQuotaFetchError] {
  let target = match models_url_target(url) {
    Ok(target) => target
    Err(err) => return Err({ status: Valid, message: err })
  }
  let client = @http.Client::new(target.origin, headers~)
  defer client.close()
  let response = client.get(target.path) catch {
    err => return Err({ status: Valid, message: "Network error: \{err}" })
  }
  moon_read_quota_json_response(client, response.code, expired_message)
}

///|
async fn moon_fetch_json_post(
  url : String,
  body : String,
  headers : Map[String, String],
  expired_message? : String = "Authentication failed.",
  network_label? : String? = None,
) -> Result[Json, MoonQuotaFetchError] {
  let target = match models_url_target(url) {
    Ok(target) => target
    Err(err) => return Err({ status: Valid, message: err })
  }
  let client = @http.Client::new(target.origin, headers~)
  defer client.close()
  let response = client.post(target.path, body) catch {
    err => {
      let prefix = match network_label {
        Some(label) => "Network error (\{label})"
        None => "Network error"
      }
      return Err({ status: Valid, message: "\{prefix}: \{err}" })
    }
  }
  moon_read_quota_json_response(
    client,
    response.code,
    expired_message,
    network_label~,
  )
}

///|
async fn moon_read_quota_json_response(
  client : @http.Client,
  code : Int,
  expired_message : String,
  network_label? : String? = None,
) -> Result[Json, MoonQuotaFetchError] {
  let body = client.read_all().text()
  if code == 401 || code == 403 {
    return Err({ status: Expired, message: "\{expired_message} (HTTP \{code})" })
  }
  if !(code is (200..=299)) {
    let prefix = match network_label {
      Some("loadCodeAssist") => "loadCodeAssist failed"
      Some("retrieveUserQuota") => "retrieveUserQuota failed"
      _ => "API error"
    }
    return Err({ status: Valid, message: "\{prefix} (HTTP \{code}): \{body}" })
  }
  try @json.parse(body) catch {
    err =>
      Err({ status: Valid, message: "Failed to parse API response: \{err}" })
  } noraise {
    json => Ok(json)
  }
}

///|
fn moon_parse_claude_quota(body : Json) -> SubscriptionQuota {
  guard body is Object(obj) else {
    return moon_quota_error(
      "claude",
      Valid,
      "Failed to parse API response: expected object",
    )
  }
  let tiers : Array[Json] = []
  for
    name in [
      MOON_QUOTA_TIER_FIVE_HOUR,
      MOON_QUOTA_TIER_SEVEN_DAY,
      MOON_QUOTA_TIER_SEVEN_DAY_OPUS,
      MOON_QUOTA_TIER_SEVEN_DAY_SONNET,
    ] {
    match obj.get(name) {
      Some(Object(window)) =>
        match moon_quota_tier_from_window(name, window) {
          Some(tier) => tiers.push(tier)
          None => ()
        }
      _ => ()
    }
  }
  for key, value in obj {
    if key == "extra_usage" ||
      key == MOON_QUOTA_TIER_FIVE_HOUR ||
      key == MOON_QUOTA_TIER_SEVEN_DAY ||
      key == MOON_QUOTA_TIER_SEVEN_DAY_OPUS ||
      key == MOON_QUOTA_TIER_SEVEN_DAY_SONNET {
      continue
    }
    match value {
      Object(window) =>
        match moon_quota_tier_from_window(key, window) {
          Some(tier) => tiers.push(tier)
          None => ()
        }
      _ => ()
    }
  }
  SubscriptionQuota::new(
    "claude",
    tiers~,
    extra_usage=moon_extra_usage_json(obj.get("extra_usage")),
    queried_at=Some(moon_quota_now_millis()),
  )
}

///|
fn moon_parse_codex_quota(
  body : Json,
  tool_label : String,
) -> SubscriptionQuota {
  let tiers : Array[Json] = []
  guard body is Object(obj) else {
    return moon_quota_error(
      tool_label,
      Valid,
      "Failed to parse API response: expected object",
    )
  }
  match obj.get("rate_limit") {
    Some(Object(rate_limit)) =>
      for key in ["primary_window", "secondary_window"] {
        match rate_limit.get(key) {
          Some(Object(window)) =>
            match moon_codex_window_tier(window) {
              Some(tier) => tiers.push(tier)
              None => ()
            }
          _ => ()
        }
      }
    _ => ()
  }
  SubscriptionQuota::new(
    tool_label,
    tiers~,
    queried_at=Some(moon_quota_now_millis()),
  )
}

///|
fn moon_parse_gemini_quota(body : Json) -> SubscriptionQuota {
  let categories : Map[String, Json] = {}
  guard body is Object(obj) else {
    return moon_quota_error(
      "gemini",
      Valid,
      "Failed to parse quota response: expected object",
    )
  }
  match obj.get("buckets") {
    Some(Array(buckets)) =>
      for bucket in buckets {
        guard bucket is Object(bucket_obj) else { continue }
        let model_id = json_string_from_map(bucket_obj, "modelId").unwrap_or(
          "unknown",
        )
        let category = moon_classify_gemini_model(model_id)
        let remaining = moon_json_double_from_map(
            bucket_obj, "remainingFraction",
          )
          .unwrap_or(1.0)
          .clamp(min=0.0, max=1.0)
        let reset_time = json_string_from_map(bucket_obj, "resetTime")
        match categories.get(category) {
          Some(Object(existing)) => {
            let old_remaining = moon_json_double_from_map(existing, "remaining").unwrap_or(
              1.0,
            )
            if remaining < old_remaining {
              categories[category] = moon_gemini_category_json(
                remaining, reset_time,
              )
            }
          }
          _ =>
            categories[category] = moon_gemini_category_json(
              remaining, reset_time,
            )
        }
      }
    _ => ()
  }
  let tiers : Array[Json] = []
  for
    name in [
      MOON_QUOTA_TIER_GEMINI_PRO,
      MOON_QUOTA_TIER_GEMINI_FLASH,
      MOON_QUOTA_TIER_GEMINI_FLASH_LITE,
    ] {
    match categories.get(name) {
      Some(Object(row)) => tiers.push(moon_gemini_category_tier(name, row))
      _ => ()
    }
  }
  for name, row in categories {
    if name == MOON_QUOTA_TIER_GEMINI_PRO ||
      name == MOON_QUOTA_TIER_GEMINI_FLASH ||
      name == MOON_QUOTA_TIER_GEMINI_FLASH_LITE {
      continue
    }
    match row {
      Object(obj) => tiers.push(moon_gemini_category_tier(name, obj))
      _ => ()
    }
  }
  SubscriptionQuota::new(
    "gemini",
    tiers~,
    queried_at=Some(moon_quota_now_millis()),
  )
}

///|
fn moon_quota_tier_from_window(
  name : String,
  window : Map[String, Json],
) -> Json? {
  match moon_json_double_from_map(window, "utilization") {
    Some(utilization) =>
      Some(
        moon_quota_tier_json(
          name,
          utilization,
          resets_at=json_string_from_map(window, "resets_at"),
        ),
      )
    None => None
  }
}

///|
fn moon_codex_window_tier(window : Map[String, Json]) -> Json? {
  guard moon_json_double_from_map(window, "used_percent") is Some(used) else {
    return None
  }
  let name = match json_int64_from_map(window, "limit_window_seconds") {
    Some(seconds) => moon_window_seconds_to_tier_name(seconds)
    None => "unknown"
  }
  moon_quota_tier_json(
    name,
    used,
    resets_at=match json_int64_from_map(window, "reset_at") {
      Some(ts) => Some(@os.local_rfc3339(ts))
      None => None
    },
  )
  |> Some
}

///|
fn moon_window_seconds_to_tier_name(seconds : Int64) -> String {
  match seconds {
    18000L => "five_hour"
    604800L => "seven_day"
    _ => {
      let hours = seconds / 3600L
      if hours >= 24L {
        "\{hours / 24L}_day"
      } else {
        "\{hours}_hour"
      }
    }
  }
}

///|
fn moon_gemini_project_id(body : Json) -> String? {
  guard body is Object(obj) else { return None }
  match obj.get("cloudaicompanionProject") {
    Some(String(value)) => Some(value)
    Some(Object(project)) =>
      match json_string_from_map(project, "id") {
        Some(id) => Some(id)
        None => json_string_from_map(project, "projectId")
      }
    _ => None
  }
}

///|
fn moon_classify_gemini_model(model_id : String) -> String {
  if model_id.contains("flash-lite") {
    MOON_QUOTA_TIER_GEMINI_FLASH_LITE
  } else if model_id.contains("flash") {
    MOON_QUOTA_TIER_GEMINI_FLASH
  } else if model_id.contains("pro") {
    MOON_QUOTA_TIER_GEMINI_PRO
  } else {
    model_id
  }
}

///|
fn moon_gemini_category_json(remaining : Double, reset_time : String?) -> Json {
  let obj : Map[String, Json] = { "remaining": Json::number(remaining) }
  match reset_time {
    Some(value) => obj["resetTime"] = Json::string(value)
    None => ()
  }
  Json::object(obj)
}

///|
fn moon_gemini_category_tier(name : String, row : Map[String, Json]) -> Json {
  let remaining = moon_json_double_from_map(row, "remaining").unwrap_or(1.0)
  moon_quota_tier_json(
    name,
    (1.0 - remaining) * 100.0,
    resets_at=json_string_from_map(row, "resetTime"),
  )
}

///|
fn moon_quota_tier_json(
  name : String,
  utilization : Double,
  resets_at? : String? = None,
  used_value_usd? : Double? = None,
  max_value_usd? : Double? = None,
) -> Json {
  let obj : Map[String, Json] = {
    "name": Json::string(name),
    "utilization": Json::number(utilization),
  }
  match resets_at {
    Some(value) => obj["resetsAt"] = Json::string(value)
    None => ()
  }
  match used_value_usd {
    Some(value) => obj["usedValueUsd"] = Json::number(value)
    None => ()
  }
  match max_value_usd {
    Some(value) => obj["maxValueUsd"] = Json::number(value)
    None => ()
  }
  Json::object(obj)
}

///|
fn moon_extra_usage_json(value : Json?) -> Json? {
  guard value is Some(Object(extra)) else { return None }
  let obj : Map[String, Json] = {
    "isEnabled": Json::boolean(
      match extra.get("is_enabled") {
        Some(True) => true
        _ => false
      },
    ),
  }
  match moon_json_double_from_map(extra, "monthly_limit") {
    Some(value) => obj["monthlyLimit"] = Json::number(value)
    None => ()
  }
  match moon_json_double_from_map(extra, "used_credits") {
    Some(value) => obj["usedCredits"] = Json::number(value)
    None => ()
  }
  match moon_json_double_from_map(extra, "utilization") {
    Some(value) => obj["utilization"] = Json::number(value)
    None => ()
  }
  match json_string_from_map(extra, "currency") {
    Some(value) => obj["currency"] = Json::string(value)
    None => ()
  }
  Some(Json::object(obj))
}

///|
fn moon_form_pair(key : String, value : String) -> String {
  "\{moon_form_encode(key)}=\{moon_form_encode(value)}"
}

///|
fn moon_form_encode(value : String) -> String {
  let buf = StringBuilder::new()
  for c in value {
    match c {
      'A'..='Z' | 'a'..='z' | '0'..='9' | '-' | '_' | '.' | '~' =>
        buf.write_char(c)
      _ => {
        let bytes = @encoding/utf8.encode(c.to_string())
        for b in bytes {
          let hex = b.to_int()
          let high = (hex >> 4) & 0xF
          let low = hex & 0xF
          buf.write_char('%')
          buf.write_char(moon_hex_char(high))
          buf.write_char(moon_hex_char(low))
        }
      }
    }
  }
  buf.to_string()
}

///|
fn moon_hex_char(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('A'.to_int() + n - 10).unsafe_to_char()
  }
}

///|
fn moon_json_double_from_map(obj : Map[String, Json], key : String) -> Double? {
  match obj.get(key) {
    Some(Number(value, ..)) => Some(value)
    Some(String(value)) => parse_non_negative_decimal_to_double(value)
    _ => None
  }
}

///|
fn json_int64_from_map(obj : Map[String, Json], key : String) -> Int64? {
  match obj.get(key) {
    Some(Number(value, ..)) => Some(value.to_int64())
    Some(String(value)) =>
      try @string.parse_int(value, base=10) catch {
        _ => None
      } noraise {
        parsed => Some(parsed.to_int64())
      }
    _ => None
  }
}
