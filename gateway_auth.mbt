///|
fn gemini_cli_bearer_token(api_key : String) -> String {
  let trimmed = api_key.trim()
  if trimmed.has_prefix("{") {
    let parsed = @json.parse(trimmed.to_owned()) catch { _ => Json::null() }
    if parsed is Object(obj) {
      match json_string_from_map(obj, "access_token") {
        Some(token) if !token.trim().is_empty() =>
          return token.trim().to_owned()
        _ => ()
      }
    }
  }
  trimmed.to_owned()
}

///|
fn codex_oauth_headers(
  creds : @codex.Credentials,
  accept : String,
  session_id : String?,
) -> Map[String, String] {
  let headers : Map[String, String] = {
    "Authorization": "Bearer \{creds.accessToken}",
    "ChatGPT-Account-ID": creds.accountId,
    "Content-Type": "application/json",
    "Accept": accept,
    "originator": "moonstat_gateway",
    "User-Agent": "moonstat/1.0.0",
  }
  match session_id {
    Some(id) => {
      let trimmed = id.trim().to_owned()
      if !trimmed.is_empty() {
        headers["session_id"] = trimmed
        headers["x-client-request-id"] = trimmed
        headers["x-codex-window-id"] = "\{trimmed}:0"
      }
    }
    None => ()
  }
  headers
}

///|
fn normalize_codex_oauth_request(json : Json) -> Json {
  guard json is Object(obj) else { return json }
  obj["store"] = Json::boolean(false)
  if obj.get("instructions") is None {
    obj["instructions"] = Json::string("")
  }
  if obj.get("tools") is None {
    obj["tools"] = Json::array([])
  }
  if obj.get("parallel_tool_calls") is None {
    obj["parallel_tool_calls"] = Json::boolean(false)
  }
  Json::object(obj)
}

///|
fn moon_provider_balance_query_credentials(
  provider : ProviderRouteTarget,
) -> (String, String)? {
  guard provider.base_url is Some(base_url) else { return None }
  guard moon_detect_balance_provider(base_url) is Some(_) else { return None }
  Some((base_url, provider.api_key.unwrap_or("")))
}

///|
async fn AuthService::handle_get_codex_oauth_quota(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  usage : UsageService,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let account_id = proxy_string_request(r.path, body, [
    "accountId", "account_id", "account",
  ])
  let quota = moon_get_codex_oauth_quota(account_id)
  usage.usage_cache.put_subscription(quota.tool, quota)
  write_usage_json(w, quota.to_json())
}

///|
async fn AuthService::handle_get_codex_oauth_models(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let account_id = proxy_string_request(r.path, body, [
    "accountId", "account_id", "account",
  ])
  match moon_get_codex_oauth_models(account_id) {
    Ok(models) => write_usage_json(w, fetched_models_to_json(models))
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
fn managed_auth_provider_request(path : StringView, body : Json?) -> String {
  proxy_string_request(path, body, ["authProvider", "auth_provider", "provider"]).unwrap_or(
    managed_auth_default_provider(),
  )
}

///|
async fn AuthService::handle_auth_start_login(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  match
    managed_auth_start_login(
      provider,
      github_domain=copilot_github_domain_request(r.path, body),
    ) {
    Ok(flow) => {
      if flow is Object(obj) &&
        json_string_from_map(obj, "device_code") is Some(device_code) &&
        json_string_from_map(obj, "user_code") is Some(user_code) {
        self.auth_device_user_codes[device_code] = user_code
      }
      write_usage_json(w, flow)
    }
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn AuthService::handle_auth_poll_for_account(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  guard proxy_string_request(r.path, body, [
      "deviceCode", "device_code", "deviceAuthId", "device_auth_id",
    ])
    is Some(device_code) else {
    write_usage_bad_request(w, "missing_device_code")
    return
  }
  let user_code = match
    proxy_string_request(r.path, body, ["userCode", "user_code", "code"]) {
    Some(value) => Some(value)
    None => self.auth_device_user_codes.get(device_code)
  }
  if provider != AUTH_PROVIDER_GITHUB_COPILOT && user_code is None {
    write_usage_bad_request(w, "missing_user_code")
    return
  }
  match
    managed_auth_poll_for_account(
      provider,
      device_code,
      user_code,
      github_domain=copilot_github_domain_request(r.path, body),
    ) {
    Ok(Some(account)) => {
      self.auth_device_user_codes.remove(device_code)
      try @codex.load_credentials() catch {
        _ => ()
      } noraise {
        credentials => self.credentials = Some(credentials)
      }
      write_usage_json(w, account)
    }
    Ok(None) => write_usage_json(w, Json::null())
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn AuthService::handle_auth_list_accounts(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  match managed_auth_list_accounts(provider) {
    Ok(accounts) => write_usage_json(w, accounts)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn AuthService::handle_auth_get_status(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  match managed_auth_get_status(provider) {
    Ok(status) => write_usage_json(w, status)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn AuthService::handle_auth_remove_account(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  guard proxy_string_request(r.path, body, ["accountId", "account_id", "id"])
    is Some(account_id) else {
    write_usage_bad_request(w, "missing_account_id")
    return
  }
  match managed_auth_remove_account(provider, account_id) {
    Ok(result) => {
      self.credentials = None
      write_usage_json(w, result)
    }
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn AuthService::handle_auth_set_default_account(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  guard proxy_string_request(r.path, body, ["accountId", "account_id", "id"])
    is Some(account_id) else {
    write_usage_bad_request(w, "missing_account_id")
    return
  }
  match managed_auth_set_default_account(provider, account_id) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn AuthService::handle_auth_logout(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  match managed_auth_logout(provider) {
    Ok(result) => {
      self.credentials = None
      write_usage_json(w, result)
    }
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn AuthService::handle_copilot_start_device_flow(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  match copilot_start_device_flow(copilot_github_domain_request(r.path, body)) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn AuthService::handle_copilot_poll_for_auth(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["deviceCode", "device_code"])
    is Some(device_code) else {
    write_usage_bad_request(w, "missing_device_code")
    return
  }
  match
    copilot_poll_for_account(
      device_code,
      copilot_github_domain_request(r.path, body),
    ) {
    Ok(Some(_)) => write_usage_json(w, Json::boolean(true))
    Ok(None) => write_usage_json(w, Json::boolean(false))
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn AuthService::handle_copilot_get_auth_status(
  self : AuthService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, copilot_get_auth_status())
}

///|
async fn AuthService::handle_copilot_is_authenticated(
  self : AuthService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::boolean(copilot_is_authenticated()))
}

///|
async fn AuthService::handle_copilot_logout(
  self : AuthService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, copilot_logout())
}

///|
async fn AuthService::handle_copilot_get_token(
  self : AuthService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  match copilot_get_token(copilot_account_id_request(r.path, body)) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
fn moon_token_plan_usage_result_from_quota(
  quota : SubscriptionQuota,
) -> UsageResult {
  if !quota.success {
    return UsageResult::new(false, error=quota.error)
  }
  let data : Array[UsageData] = []
  let has_usd = match quota.tiers.get(0) {
    Some(tier) => moon_token_plan_tier_has_usd(tier)
    None => false
  }
  let plan_label = moon_token_plan_label(quota.credential_message)
  let mut first_tier = true
  for tier in quota.tiers {
    guard tier is Object(obj) else { continue }
    let used = moon_json_double_from_map(obj, "utilization").unwrap_or(0.0)
    data.push(
      UsageData::new(
        plan_name=json_string_from_map(obj, "name"),
        remaining=Some(100.0 - used),
        total=Some(100.0),
        used=Some(used),
        unit=Some("%"),
        is_valid=Some(true),
        extra=moon_token_plan_usage_extra(
          obj,
          has_usd~,
          first_tier~,
          plan_label~,
        ),
      ),
    )
    first_tier = false
  }
  UsageResult::new(true, data=if data.is_empty() { None } else { Some(data) })
}

///|
fn moon_token_plan_tier_has_usd(tier : Json) -> Bool {
  guard tier is Object(obj) else { return false }
  obj.contains("usedValueUsd")
}

///|
fn moon_token_plan_label(message : String?) -> String? {
  guard message is Some(value) else { return None }
  for part in value.split(" ") {
    let tier = part.trim()
    if !tier.is_empty() {
      return Some("ZenMux·\{tier.to_upper()}")
    }
  }
  None
}

///|
fn moon_token_plan_usage_extra(
  tier : Map[String, Json],
  has_usd~ : Bool,
  first_tier~ : Bool,
  plan_label~ : String?,
) -> String? {
  if !has_usd {
    return json_string_from_map(tier, "resetsAt")
  }
  let extra : Map[String, Json] = {
    "resetsAt": match json_string_from_map(tier, "resetsAt") {
      Some(value) => Json::string(value)
      None => Json::null()
    },
  }
  match moon_json_double_from_map(tier, "usedValueUsd") {
    Some(value) => extra["usedValueUsd"] = Json::number(value)
    None => ()
  }
  match moon_json_double_from_map(tier, "maxValueUsd") {
    Some(value) => extra["maxValueUsd"] = Json::number(value)
    None => ()
  }
  if first_tier {
    match plan_label {
      Some(label) => extra["planLabel"] = Json::string(label)
      None => ()
    }
  }
  Some(Json::object(extra).stringify())
}

///|
async fn AuthService::validate_claude_desktop_gateway_auth(
  self : AuthService,
  proxy : ProxyService,
  usage : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Bool {
  ignore(self)
  match @claude_desktop.gateway_token() {
    None => true
    Some(expected) =>
      if claude_desktop_authorization_valid(r.headers, expected) {
        true
      } else {
        usage.record_unauthorized_with_provider(proxy)
        write_auth_error(w, "Claude Desktop gateway token invalid or missing")
        false
      }
  }
}

///|
fn claude_desktop_authorization_valid(
  headers : Map[String, String],
  expected : String,
) -> Bool {
  let expected = expected.trim()
  if expected.is_empty() {
    return true
  }
  match headers.get("authorization") {
    Some(value) => bearer_token(value) == Some(expected.to_owned())
    None => false
  }
}

///|
fn bearer_token(value : String) -> String? {
  let trimmed = value.trim()
  if trimmed.has_prefix("Bearer ") {
    Some(trimmed["Bearer ".length():].trim().to_owned())
  } else if trimmed.has_prefix("bearer ") {
    Some(trimmed["bearer ".length():].trim().to_owned())
  } else {
    None
  }
}

///|
async fn write_auth_error(w : @httpx.ResponseWriter, message : String) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Unauthorized)
  w.write(
    "{\"error\":{\"message\":\"\{message}\",\"type\":\"authentication_error\"}}",
  )
  w.flush()
}

///|
async fn AuthService::handle_login(
  self : AuthService,
  _r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  logger : @pino.Logger,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  try {
    let creds = @codex.start_oauth_flow()
    self.credentials = Some(creds)
    logger.info("Login successful")
    w.write_header(@status.Ok)
    w.write("{\"status\":\"ok\",\"message\":\"Login successful\"}")
  } catch {
    _ => {
      logger.error("Login failed")
      w.write_header(@status.InternalServerError)
      w.write("{\"error\":\"Login failed\"}")
    }
  }
  w.flush()
}

///|
fn token_usage_from_claude_compatible_response(
  body : Json,
  api_format : String,
) -> TokenUsage? {
  match api_format {
    "openai_chat" => token_usage_from_openai_response(body)
    "openai_responses" => token_usage_from_codex_response_auto(body)
    "gemini_native" => token_usage_from_gemini_response(body)
    _ => token_usage_from_claude_response(body)
  }
}
