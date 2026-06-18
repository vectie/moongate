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
async fn auth_start_login(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    auth_provider_path(args, "/auth_start_login"),
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
  check_json_endpoint(
    args,
    auth_provider_path(args, "/auth_list_accounts"),
    "Auth",
  )
}

///|
async fn auth_get_status(args : Array[String]) -> Unit {
  check_json_endpoint(
    args,
    auth_provider_path(args, "/auth_get_status"),
    "Auth",
  )
}

///|
async fn auth_remove_account(args : Array[String]) -> Unit {
  guard auth_account_path(args, "/auth_remove_account") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required auth account arg: --account-id")
    return
  }
  check_json_post_endpoint(args, path, "Auth")
}

///|
async fn auth_set_default_account(args : Array[String]) -> Unit {
  guard auth_account_path(args, "/auth_set_default_account") is Some(path) else {
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
    auth_provider_path(args, "/auth_logout"),
    "Auth",
  )
}

///|
async fn copilot_poll_for_auth(args : Array[String]) -> Unit {
  guard copilot_device_path(args, "/copilot_poll_for_auth") is Some(path) else {
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
  match parse_string_arg_any(args, "--account-id", "--accountId") {
    Some(value) => query.push(cli_query_pair("accountId", value))
    None => ()
  }
  cli_path_with_query("/get_codex_oauth_quota", query)
}

///|
fn codex_oauth_models_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--account-id", "--accountId") {
    Some(value) => query.push(cli_query_pair("accountId", value))
    None => ()
  }
  cli_path_with_query("/get_codex_oauth_models", query)
}

///|
fn auth_provider_path(args : Array[String], path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--auth-provider", "--authProvider") {
    Some(value) => query.push(cli_query_pair("authProvider", value))
    None => ()
  }
  cli_path_with_query(path, query)
}

///|
fn auth_account_path(args : Array[String], path : String) -> String? {
  guard parse_string_arg_any(args, "--account-id", "--accountId")
    is Some(account_id) else {
    return None
  }
  let query : Array[String] = [cli_query_pair("accountId", account_id)]
  match parse_string_arg_any(args, "--auth-provider", "--authProvider") {
    Some(value) => query.push(cli_query_pair("authProvider", value))
    None => ()
  }
  Some(cli_path_with_query(path, query))
}

///|
fn auth_poll_path(args : Array[String]) -> String? {
  guard parse_string_arg_any(args, "--device-code", "--deviceCode")
    is Some(device_code) else {
    return None
  }
  let query : Array[String] = [cli_query_pair("deviceCode", device_code)]
  match parse_string_arg_any(args, "--user-code", "--userCode") {
    Some(value) => query.push(cli_query_pair("userCode", value))
    None => ()
  }
  match parse_string_arg_any(args, "--auth-provider", "--authProvider") {
    Some(value) => query.push(cli_query_pair("authProvider", value))
    None => ()
  }
  Some(cli_path_with_query("/auth_poll_for_account", query))
}
