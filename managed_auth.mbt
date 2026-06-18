///|
const AUTH_PROVIDER_GITHUB_COPILOT = "github_copilot"

///|
const AUTH_PROVIDER_CODEX_OAUTH = "codex_oauth"

///|
pub fn managed_auth_default_provider() -> String {
  AUTH_PROVIDER_CODEX_OAUTH
}

///|
fn managed_auth_provider_supported(provider : String) -> Bool {
  provider == AUTH_PROVIDER_GITHUB_COPILOT ||
  provider == AUTH_PROVIDER_CODEX_OAUTH
}

///|
fn managed_auth_provider_error(provider : String) -> String {
  "Unsupported auth provider: \{provider}"
}

///|
fn managed_auth_account_login(credentials : @codex.Credentials) -> String {
  @codex.extract_token_claims(credentials.idToken).email catch {
    _ => credentials.accountId
  }
}

///|
fn managed_auth_account_json(
  provider : String,
  credentials : @codex.Credentials,
  is_default? : Bool = true,
) -> Json {
  {
    "id": Json::string(credentials.accountId),
    "provider": Json::string(provider),
    "login": Json::string(managed_auth_account_login(credentials)),
    "avatar_url": Json::null(),
    "authenticated_at": Json::number(0.0),
    "is_default": Json::boolean(is_default),
    "github_domain": Json::string(
      if provider == AUTH_PROVIDER_CODEX_OAUTH {
        "chatgpt.com"
      } else {
        "github.com"
      },
    ),
  }.to_json()
}

///|
fn managed_auth_status_json(
  provider : String,
  credentials : @codex.Credentials?,
  migration_error? : String,
) -> Json {
  let accounts = match credentials {
    Some(credentials) =>
      [managed_auth_account_json(provider, credentials, is_default=true)]
    None => []
  }
  {
    "provider": Json::string(provider),
    "authenticated": Json::boolean(credentials is Some(_)),
    "default_account_id": match credentials {
      Some(credentials) => Json::string(credentials.accountId)
      None => Json::null()
    },
    "migration_error": match migration_error {
      Some(error) => Json::string(error)
      None => Json::null()
    },
    "accounts": Json::array(accounts),
  }.to_json()
}

///|
async fn managed_auth_codex_credentials() -> @codex.Credentials? {
  try @codex.load_credentials() catch {
    _ => None
  } noraise {
    credentials => Some(credentials)
  }
}

///|
pub async fn managed_auth_get_status(provider : String) -> Result[Json, String] {
  if !managed_auth_provider_supported(provider) {
    return Err(managed_auth_provider_error(provider))
  }
  if provider == AUTH_PROVIDER_GITHUB_COPILOT {
    return Ok(copilot_get_auth_status())
  }
  Ok(managed_auth_status_json(provider, managed_auth_codex_credentials()))
}

///|
pub async fn managed_auth_list_accounts(
  provider : String,
) -> Result[Json, String] {
  if !managed_auth_provider_supported(provider) {
    return Err(managed_auth_provider_error(provider))
  }
  if provider == AUTH_PROVIDER_GITHUB_COPILOT {
    return Ok(copilot_list_accounts())
  }
  match managed_auth_codex_credentials() {
    Some(credentials) =>
      Ok(
        Json::array([
          managed_auth_account_json(provider, credentials, is_default=true),
        ]),
      )
    None => Ok(Json::array([]))
  }
}

///|
pub async fn managed_auth_logout(provider : String) -> Result[Json, String] {
  if !managed_auth_provider_supported(provider) {
    return Err(managed_auth_provider_error(provider))
  }
  if provider == AUTH_PROVIDER_GITHUB_COPILOT {
    return Ok(copilot_logout())
  }
  @codex.delete_credentials()
  Ok(Json::null())
}

///|
pub async fn managed_auth_remove_account(
  provider : String,
  account_id : String,
) -> Result[Json, String] {
  if !managed_auth_provider_supported(provider) {
    return Err(managed_auth_provider_error(provider))
  }
  if provider == AUTH_PROVIDER_GITHUB_COPILOT {
    return copilot_remove_account(account_id)
  }
  match managed_auth_codex_credentials() {
    Some(credentials) if credentials.accountId == account_id => {
      @codex.delete_credentials()
      Ok(Json::null())
    }
    Some(_) => Err("Account not found: \{account_id}")
    None => Err("Account not found: \{account_id}")
  }
}

///|
pub async fn managed_auth_set_default_account(
  provider : String,
  account_id : String,
) -> Result[Json, String] {
  if !managed_auth_provider_supported(provider) {
    return Err(managed_auth_provider_error(provider))
  }
  if provider == AUTH_PROVIDER_GITHUB_COPILOT {
    return copilot_set_default_account(account_id)
  }
  match managed_auth_codex_credentials() {
    Some(credentials) if credentials.accountId == account_id => Ok(Json::null())
    Some(_) => Err("Account not found: \{account_id}")
    None => Err("Account not found: \{account_id}")
  }
}

///|
pub async fn managed_auth_start_login(
  provider : String,
  github_domain? : String? = None,
) -> Result[Json, String] {
  if !managed_auth_provider_supported(provider) {
    return Err(managed_auth_provider_error(provider))
  }
  if provider == AUTH_PROVIDER_GITHUB_COPILOT {
    return copilot_start_device_flow(github_domain)
  }
  Ok(@codex.start_device_flow().to_json()) catch {
    error => Err("\{error}")
  }
}

///|
pub async fn managed_auth_poll_for_account(
  provider : String,
  device_code : String,
  user_code : String?,
  github_domain? : String? = None,
) -> Result[Json?, String] {
  if !managed_auth_provider_supported(provider) {
    return Err(managed_auth_provider_error(provider))
  }
  if provider == AUTH_PROVIDER_GITHUB_COPILOT {
    return copilot_poll_for_account(device_code, github_domain)
  }
  guard user_code is Some(user_code) else { return Err("missing_user_code") }
  try {
    match @codex.poll_device_flow(device_code, user_code) {
      Some(credentials) =>
        Ok(
          Some(
            managed_auth_account_json(provider, credentials, is_default=true),
          ),
        )
      None => Ok(None)
    }
  } catch {
    error => Err("\{error}")
  }
}
