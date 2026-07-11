///|
fn copilot_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "copilot_start_device_flow", patterns: ["copilot login"] },
    { id: "copilot_poll_for_account", patterns: ["copilot poll"] },
    { id: "copilot_poll_for_auth", patterns: ["copilot auth-poll"] },
    { id: "copilot_list_accounts", patterns: ["copilot accounts"] },
    { id: "copilot_get_auth_status", patterns: ["copilot status"] },
    { id: "copilot_is_authenticated", patterns: ["copilot authenticated"] },
    { id: "copilot_logout", patterns: ["copilot logout"] },
    { id: "copilot_remove_account", patterns: ["copilot remove"] },
    { id: "copilot_set_default_account", patterns: ["copilot default"] },
    { id: "copilot_get_token", patterns: ["copilot token"] },
    { id: "copilot_get_models", patterns: ["copilot models"] },
    { id: "copilot_get_usage", patterns: ["copilot usage"] },
  ]
}

///|
async fn run_copilot_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "copilot_start_device_flow" => copilot_start_device_flow(args)
    "copilot_poll_for_account" => copilot_poll_for_account(args)
    "copilot_poll_for_auth" => copilot_poll_for_auth(args)
    "copilot_list_accounts" => check_usage_endpoint(args, "/copilot/accounts")
    "copilot_get_auth_status" => check_usage_endpoint(args, "/copilot/status")
    "copilot_is_authenticated" =>
      check_usage_endpoint(args, "/copilot/authenticated")
    "copilot_logout" =>
      check_json_post_endpoint(args, "/copilot/logout", "Copilot")
    "copilot_remove_account" => copilot_account_delete(args, "/copilot/account")
    "copilot_set_default_account" =>
      copilot_account_post(args, "/copilot/default-account")
    "copilot_get_token" =>
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot/token"),
      )
    "copilot_get_models" =>
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot/models"),
      )
    "copilot_get_usage" =>
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot/usage"),
      )
    _ => ()
  }
}

///|
async fn copilot_start_device_flow(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    copilot_github_domain_path(args, "/copilot/device-flow"),
    "Copilot",
  )
}

///|
async fn copilot_poll_for_account(args : Array[String]) -> Unit {
  guard copilot_device_path(args, "/copilot/poll-account") is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required Copilot arg: --device-code")
    return
  }
  check_json_post_endpoint(args, path, "Copilot")
}

///|
async fn copilot_account_post(args : Array[String], path : String) -> Unit {
  guard copilot_account_path(args, path) is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required Copilot arg: --account-id")
    return
  }
  check_json_post_endpoint(args, path, "Copilot")
}

///|
async fn copilot_account_delete(args : Array[String], path : String) -> Unit {
  guard copilot_account_path(args, path) is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required Copilot arg: --account-id")
    return
  }
  check_json_delete_endpoint(args, path, "Copilot")
}

///|
fn copilot_github_domain_path(args : Array[String], path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--github-domain") {
    Some(value) => query.push(cli_query_pair("githubDomain", value))
    None => ()
  }
  cli_path_with_query(path, query)
}

///|
fn copilot_device_path(args : Array[String], path : String) -> String? {
  guard parse_string_arg(args, "--device-code") is Some(device_code) else {
    return None
  }
  let query : Array[String] = [cli_query_pair("deviceCode", device_code)]
  match parse_string_arg(args, "--github-domain") {
    Some(value) => query.push(cli_query_pair("githubDomain", value))
    None => ()
  }
  Some(cli_path_with_query(path, query))
}

///|
fn copilot_account_path(args : Array[String], path : String) -> String? {
  guard parse_string_arg(args, "--account-id") is Some(account_id) else {
    return None
  }
  let query : Array[String] = [cli_query_pair("accountId", account_id)]
  Some(cli_path_with_query(path, query))
}

///|
fn copilot_account_optional_path(args : Array[String], path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--account-id") {
    Some(value) => query.push(cli_query_pair("accountId", value))
    None => ()
  }
  cli_path_with_query(path, query)
}
