///|
async fn copilot_start_device_flow(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    copilot_github_domain_path(args, "/copilot_start_device_flow"),
    "Copilot",
  )
}

///|
async fn copilot_poll_for_account(args : Array[String]) -> Unit {
  guard copilot_device_path(args, "/copilot_poll_for_account") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required Copilot arg: --device-code")
    return
  }
  check_json_post_endpoint(args, path, "Copilot")
}

///|
async fn copilot_account_post(args : Array[String], path : String) -> Unit {
  guard copilot_account_path(args, path) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required Copilot arg: --account-id")
    return
  }
  check_json_post_endpoint(args, path, "Copilot")
}

///|
fn copilot_github_domain_path(args : Array[String], path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--github-domain", "--githubDomain") {
    Some(value) => query.push(cli_query_pair("githubDomain", value))
    None => ()
  }
  cli_path_with_query(path, query)
}

///|
fn copilot_device_path(args : Array[String], path : String) -> String? {
  guard parse_string_arg_any(args, "--device-code", "--deviceCode")
    is Some(device_code) else {
    return None
  }
  let query : Array[String] = [cli_query_pair("deviceCode", device_code)]
  match parse_string_arg_any(args, "--github-domain", "--githubDomain") {
    Some(value) => query.push(cli_query_pair("githubDomain", value))
    None => ()
  }
  Some(cli_path_with_query(path, query))
}

///|
fn copilot_account_path(args : Array[String], path : String) -> String? {
  guard parse_string_arg_any(args, "--account-id", "--accountId")
    is Some(account_id) else {
    return None
  }
  let query : Array[String] = [cli_query_pair("accountId", account_id)]
  Some(cli_path_with_query(path, query))
}

///|
fn copilot_account_optional_path(args : Array[String], path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--account-id", "--accountId") {
    Some(value) => query.push(cli_query_pair("accountId", value))
    None => ()
  }
  cli_path_with_query(path, query)
}
