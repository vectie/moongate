///|
async fn do_login(_args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  logger.info("Starting OpenAI Codex OAuth login flow...")
  try {
    let creds = @codex.start_oauth_flow()
    logger.info("Login successful!")
    logger.info("Email: \{@codex.extract_token_claims(creds.idToken).email}")
    @codex.save_credentials(creds)
    logger.info("Credentials saved to ~/.moonsuite/codex-credentials.json")
  } catch {
    err => logger.error("Login failed: \{err}")
  }
}

///|
fn auth_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "login", patterns: ["login"] },
    { id: "auth_start_login", patterns: ["auth login"] },
    { id: "auth_poll_for_account", patterns: ["auth poll"] },
    { id: "auth_list_accounts", patterns: ["auth accounts"] },
    { id: "auth_get_status", patterns: ["auth status"] },
    { id: "auth_remove_account", patterns: ["auth remove"] },
    { id: "auth_set_default_account", patterns: ["auth default"] },
    { id: "auth_logout", patterns: ["auth logout"] },
  ]
}

///|
fn cli_auth_command_id(command_id : String) -> Bool {
  match command_id {
    "login"
    | "auth_start_login"
    | "auth_poll_for_account"
    | "auth_list_accounts"
    | "auth_get_status"
    | "auth_remove_account"
    | "auth_set_default_account"
    | "auth_logout" => true
    _ => false
  }
}

///|
async fn run_auth_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "login" => do_login(args)
    "auth_start_login" => auth_start_login(args)
    "auth_poll_for_account" => auth_poll_for_account(args)
    "auth_list_accounts" => auth_list_accounts(args)
    "auth_get_status" => auth_get_status(args)
    "auth_remove_account" => auth_remove_account(args)
    "auth_set_default_account" => auth_set_default_account(args)
    "auth_logout" => auth_logout(args)
    _ => ()
  }
}

///|
async fn auth_start_login(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    auth_provider_path(args, "/auth/login"),
    "Auth",
  )
}

///|
async fn auth_poll_for_account(args : Array[String]) -> Unit {
  guard auth_poll_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required auth poll arg: --device-code")
    return
  }
  check_json_post_endpoint(args, path, "Auth")
}

///|
async fn auth_list_accounts(args : Array[String]) -> Unit {
  check_json_endpoint(args, auth_provider_path(args, "/auth/accounts"), "Auth")
}

///|
async fn auth_get_status(args : Array[String]) -> Unit {
  check_json_endpoint(args, auth_provider_path(args, "/auth/status"), "Auth")
}

///|
async fn auth_remove_account(args : Array[String]) -> Unit {
  guard auth_account_path(args, "/auth/account") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required auth account arg: --account-id")
    return
  }
  check_json_delete_endpoint(args, path, "Auth")
}

///|
async fn auth_set_default_account(args : Array[String]) -> Unit {
  guard auth_account_path(args, "/auth/default-account") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required auth account arg: --account-id")
    return
  }
  check_json_post_endpoint(args, path, "Auth")
}

///|
async fn auth_logout(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    auth_provider_path(args, "/auth/logout"),
    "Auth",
  )
}

///|
async fn copilot_poll_for_auth(args : Array[String]) -> Unit {
  guard copilot_device_path(args, "/copilot/poll-auth") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required Copilot arg: --device-code")
    return
  }
  check_json_post_endpoint(args, path, "Copilot")
}

///|
async fn check_codex_oauth_quota(args : Array[String]) -> Unit {
  check_usage_endpoint(args, codex_oauth_quota_path(args))
}

///|
async fn check_codex_oauth_models(args : Array[String]) -> Unit {
  check_usage_endpoint(args, codex_oauth_models_path(args))
}

///|
fn codex_oauth_quota_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--account-id") {
    Some(value) => query.push(cli_query_pair("accountId", value))
    None => ()
  }
  cli_path_with_query("/usage/codex-oauth-quota", query)
}

///|
fn codex_oauth_models_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--account-id") {
    Some(value) => query.push(cli_query_pair("accountId", value))
    None => ()
  }
  cli_path_with_query("/usage/codex-oauth-models", query)
}

///|
fn auth_provider_path(args : Array[String], path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--auth-provider") {
    Some(value) => query.push(cli_query_pair("authProvider", value))
    None => ()
  }
  cli_path_with_query(path, query)
}

///|
fn auth_account_path(args : Array[String], path : String) -> String? {
  guard parse_string_arg(args, "--account-id") is Some(account_id) else {
    return None
  }
  let query : Array[String] = [cli_query_pair("accountId", account_id)]
  match parse_string_arg(args, "--auth-provider") {
    Some(value) => query.push(cli_query_pair("authProvider", value))
    None => ()
  }
  Some(cli_path_with_query(path, query))
}

///|
fn auth_poll_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--device-code") is Some(device_code) else {
    return None
  }
  let query : Array[String] = [cli_query_pair("deviceCode", device_code)]
  match parse_string_arg(args, "--user-code") {
    Some(value) => query.push(cli_query_pair("userCode", value))
    None => ()
  }
  match parse_string_arg(args, "--auth-provider") {
    Some(value) => query.push(cli_query_pair("authProvider", value))
    None => ()
  }
  Some(cli_path_with_query("/auth/poll", query))
}
