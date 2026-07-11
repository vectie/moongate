///|
pub(all) struct Credentials {
  idToken : String
  accessToken : String
  refreshToken : String
  accountId : String
} derive(Debug, ToJson, FromJson)

///|
pub struct IdTokenClaims {
  email : String
  chatgptAccountId : String
  chatgptPlanType : String
} derive(Debug)

///|
fn add_base64_padding(s : String) -> String {
  let remainder = s.length() % 4
  if remainder == 0 {
    s
  } else {
    let padding = 4 - remainder
    let mut result = s
    for _ in 0..<padding {
      result = result + "="
    }
    result
  }
}

///|
fn parse_jwt(token : String) -> Json raise Error {
  let parts = token.split(".").to_array()
  if parts.length() != 3 {
    raise ParseError("Invalid JWT format")
  }
  let padded = add_base64_padding(parts[1].to_owned())
  let payload = @base64.decode(padded, url_safe=true) catch {
    _ => raise ParseError("Base64 decode failed")
  }
  let payload_str = @encoding/utf8.decode(payload)
  @json.parse(payload_str) catch {
    err => raise ParseError("JSON parse failed: \{err}")
  }
}

///|
pub fn extract_token_claims(token : String) -> IdTokenClaims raise Error {
  let payload = match parse_jwt(token) {
    Object(obj) => obj
    _ => raise ParseError("Invalid token payload")
  }
  let authClaims = match payload.get("https://api.openai.com/auth") {
    Some(Object(obj)) => obj
    _ => raise ParseError("Invalid auth claims")
  }
  {
    email: if payload.get("email") is Some(String(email)) {
      email
    } else {
      raise ParseError("No email found in token claims")
    },
    chatgptAccountId: if authClaims.get("chatgpt_account_id")
      is Some(String(chatgptAccountId)) {
      chatgptAccountId
    } else {
      raise ParseError("No chatgpt account id found in auth claims")
    },
    chatgptPlanType: if authClaims.get("chatgpt_plan_type")
      is Some(String(chatgptPlanType)) {
      chatgptPlanType
    } else {
      raise ParseError("No chatgpt plan type found in auth claims")
    },
  }
}

///|
fn get_home() -> String raise Error {
  @os.home() catch {
    err => raise ParseError("Failed to get home directory: \{err}")
  }
}

///|
fn codex_active_workspace_root() -> String {
  @os.cwd() catch {
    _ => "."
  }
}

///|
fn get_credentials_path() -> String {
  @moonsuite.product_artifact_for_workspace_root(
    codex_active_workspace_root(),
    "moongate",
    CREDENTIALS_ARTIFACT,
  )
}

///|
fn get_codex_auth_path() -> String raise Error {
  @pathx.join(get_home(), CODEX_AUTH_FILE)
}

///|
pub async fn save_credentials(credentials : Credentials) -> Unit raise Error {
  let path = get_credentials_path()
  let dir = @pathx.dirname(path)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  @fsx.write_to_file(path, credentials.to_json().stringify(), create=0o600)
}

///|
async fn try_load_from_codex() -> Credentials? {
  try {
    let codex_path = get_codex_auth_path()
    if !@fsx.exists_as_file(codex_path) {
      return None
    }
    let content = @fsx.read_file(codex_path)
    let json = @json.parse(content)
    guard json is Object(root) else { return None }
    guard root.get("tokens") is Some(Object(tokens)) else { return None }
    let id_token = match tokens.get("id_token") {
      Some(String(s)) => s
      _ => return None
    }
    let access_token = match tokens.get("access_token") {
      Some(String(s)) => s
      _ => return None
    }
    let refresh_token = match tokens.get("refresh_token") {
      Some(String(s)) => s
      _ => return None
    }
    let account_id = match tokens.get("account_id") {
      Some(String(s)) => s
      _ => return None
    }
    let credentials : Credentials = {
      idToken: id_token,
      accessToken: access_token,
      refreshToken: refresh_token,
      accountId: account_id,
    }
    logger.info("Imported credentials from codex CLI")
    save_credentials(credentials)
    Some(credentials)
  } catch {
    _ => None
  }
}

///|
pub async fn load_credentials() -> Credentials raise Error {
  let path = get_credentials_path()
  if @fsx.exists_as_file(path) {
    let content = @fsx.read_file(path)
    return @json.from_json(@json.parse(content))
  }
  // Try to import from codex CLI
  if try_load_from_codex() is Some(credentials) {
    return credentials
  }
  raise ParseError("Credentials file not found")
}

///|
/// Returns true if credentials file exists (either our own or from codex CLI)
pub async fn credentials_exist() -> Bool {
  try {
    let path = get_credentials_path()
    if @fsx.exists_as_file(path) {
      return true
    }
    let codex_path = get_codex_auth_path()
    @fsx.exists_as_file(codex_path)
  } catch {
    _ => false
  }
}

///|
/// Deletes the credentials file if it exists
pub async fn delete_credentials() -> Unit {
  try {
    let path = get_credentials_path()
    if @fsx.exists_as_file(path) {
      @fsx.remove(path)
    }
  } catch {
    _ => ()
  }
}
