///|
fn usage_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "get_usage_summary", patterns: ["usage summary"] },
    { id: "get_usage_summary_by_app", patterns: ["usage apps"] },
    { id: "get_usage_trends", patterns: ["usage trends"] },
    { id: "get_provider_stats", patterns: ["usage providers"] },
    { id: "get_model_stats", patterns: ["usage models"] },
    { id: "get_request_logs", patterns: ["usage logs"] },
    { id: "get_request_detail", patterns: ["usage detail"] },
    { id: "update_model_pricing", patterns: ["usage pricing set"] },
    { id: "delete_model_pricing", patterns: ["usage pricing delete"] },
    { id: "get_model_pricing", patterns: ["usage pricing"] },
    { id: "check_provider_limits", patterns: ["usage limits"] },
    { id: "sync_session_usage", patterns: ["usage sync"] },
    { id: "get_usage_data_sources", patterns: ["usage sources"] },
    { id: "query_provider_usage", patterns: ["usage query-provider-usage"] },
    { id: "get_balance", patterns: ["usage balance"] },
    { id: "get_subscription_quota", patterns: ["usage quota"] },
    { id: "get_codex_oauth_quota", patterns: ["usage codex-oauth-quota"] },
    { id: "get_codex_oauth_models", patterns: ["usage codex-oauth-models"] },
    { id: "get_coding_plan_quota", patterns: ["usage coding-plan"] },
    { id: "test_usage_script", patterns: ["usage test-usage-script"] },
    { id: "status", patterns: ["status"] },
    { id: "health", patterns: ["health"] },
    { id: "stats", patterns: ["stats"] },
  ]
}

///|
async fn check_health(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.get("/health")
    if response.code == 200 {
      let body = client.read_all().text()
      println("Gateway health: \{body}")
    } else {
      logger.error("Health check failed: \{response.code}")
    }
  } catch {
    err => logger.error("Health check failed: \{err}")
  }
}

///|
async fn check_stats(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.get("/stats")
    if response.code == 200 {
      let body = client.read_all().text()
      println(body)
    } else {
      logger.error("Stats check failed: \{response.code}")
    }
  } catch {
    err => logger.error("Stats check failed: \{err}")
  }
}

///|
fn cli_usage_command_id(command_id : String) -> Bool {
  match command_id {
    "get_usage_summary"
    | "get_usage_summary_by_app"
    | "get_usage_trends"
    | "get_provider_stats"
    | "get_model_stats"
    | "get_request_logs"
    | "get_request_detail"
    | "get_model_pricing"
    | "update_model_pricing"
    | "delete_model_pricing"
    | "check_provider_limits"
    | "sync_session_usage"
    | "get_usage_data_sources"
    | "query_provider_usage"
    | "get_balance"
    | "get_subscription_quota"
    | "get_codex_oauth_quota"
    | "get_codex_oauth_models"
    | "get_coding_plan_quota"
    | "test_usage_script"
    | "status"
    | "health"
    | "stats" => true
    _ => false
  }
}

///|
async fn run_usage_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "get_usage_summary" => check_usage_summary(args)
    "get_usage_summary_by_app" => check_usage_apps(args)
    "get_usage_trends" => check_usage_trends(args)
    "get_provider_stats" => check_usage_providers(args)
    "get_model_stats" => check_usage_models(args)
    "get_request_logs" => check_usage_logs(args)
    "get_request_detail" => check_usage_detail(args)
    "get_model_pricing" => check_usage_endpoint(args, "/usage/model-pricing")
    "update_model_pricing" => update_usage_pricing(args)
    "delete_model_pricing" => delete_usage_pricing(args)
    "check_provider_limits" => check_usage_limits(args)
    "sync_session_usage" => sync_session_usage(args)
    "get_usage_data_sources" =>
      check_usage_endpoint(args, "/usage/data-sources")
    "query_provider_usage" => check_usage_provider_script(args)
    "get_balance" => check_balance(args)
    "get_subscription_quota" => check_subscription_quota(args)
    "get_codex_oauth_quota" => check_codex_oauth_quota(args)
    "get_codex_oauth_models" => check_codex_oauth_models(args)
    "get_coding_plan_quota" => check_coding_plan_quota(args)
    "test_usage_script" => test_usage_script(args)
    "status" => check_status(args)
    "health" => check_health(args)
    "stats" => check_stats(args)
    _ => ()
  }
}

///|
async fn check_usage_logs(args : Array[String]) -> Unit {
  check_usage_endpoint(args, usage_logs_path(args))
}

///|
async fn check_usage_summary(args : Array[String]) -> Unit {
  check_usage_endpoint(
    args,
    usage_filtered_path(args, "/usage/summary", app_filter=true),
  )
}

///|
async fn check_usage_apps(args : Array[String]) -> Unit {
  check_usage_endpoint(
    args,
    usage_filtered_path(args, "/usage/summary/by-app", app_filter=false),
  )
}

///|
async fn check_usage_trends(args : Array[String]) -> Unit {
  check_usage_endpoint(args, usage_trends_path(args))
}

///|
async fn check_usage_limits(args : Array[String]) -> Unit {
  check_usage_endpoint(args, usage_limits_path(args))
}

///|
async fn check_usage_models(args : Array[String]) -> Unit {
  check_usage_endpoint(
    args,
    usage_filtered_path(args, "/usage/model-stats", app_filter=true),
  )
}

///|
async fn test_usage_script(args : Array[String]) -> Unit {
  guard usage_provider_script_path(args, "/usage/test-script", true)
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required usage script args: --provider-id --app")
    return
  }
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.post(path, "{}")
    let body = client.read_all().text()
    if response.code == 200 {
      println(body)
    } else {
      logger.error("Usage script test failed: \{response.code} \{body}")
    }
  } catch {
    err => logger.error("Usage script test failed: \{err}")
  }
}

///|
async fn sync_session_usage(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  let path = usage_sync_path(args)
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.post(path, "{}")
    let body = client.read_all().text()
    if response.code == 200 {
      println(body)
    } else {
      logger.error("Usage sync failed: \{response.code} \{body}")
    }
  } catch {
    err => logger.error("Usage sync failed: \{err}")
  }
}

///|
fn usage_trends_path(args : Array[String]) -> String {
  usage_filtered_path(args, "/usage/trends", app_filter=true)
}

///|
fn usage_logs_path(args : Array[String]) -> String {
  let query = usage_date_app_query(args, app_filter=true)
  match parse_string_arg(args, "--page") {
    Some(value) => query.push(cli_query_pair("page", value))
    None => ()
  }
  match parse_string_arg_any(args, "--page-size", "--pageSize") {
    Some(value) => query.push(cli_query_pair("pageSize", value))
    None => ()
  }
  match parse_string_arg_any(args, "--provider-name", "--providerName") {
    Some(value) => query.push(cli_query_pair("providerName", value))
    None => ()
  }
  match parse_string_arg(args, "--model") {
    Some(value) => query.push(cli_query_pair("model", value))
    None => ()
  }
  match parse_string_arg_any(args, "--status-code", "--statusCode") {
    Some(value) => query.push(cli_query_pair("statusCode", value))
    None => ()
  }
  cli_path_with_query("/usage/logs", query)
}

///|
fn usage_filtered_path(
  args : Array[String],
  base_path : String,
  app_filter~ : Bool,
) -> String {
  cli_path_with_query(base_path, usage_date_app_query(args, app_filter~))
}

///|
fn usage_date_app_query(
  args : Array[String],
  app_filter~ : Bool,
) -> Array[String] {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--start-date", "--startDate") {
    Some(value) => query.push(cli_query_pair("start_date", value))
    None => ()
  }
  match parse_string_arg_any(args, "--end-date", "--endDate") {
    Some(value) => query.push(cli_query_pair("end_date", value))
    None => ()
  }
  if app_filter {
    match parse_string_arg_any(args, "--app-type", "--appType") {
      Some(value) => query.push(cli_query_pair("app_type", value))
      None => ()
    }
  }
  query
}

///|
fn usage_limits_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--provider-id", "--providerId") {
    Some(value) => query.push(cli_query_pair("provider_id", value))
    None => ()
  }
  match parse_string_arg_any(args, "--app-type", "--appType") {
    Some(value) => query.push(cli_query_pair("app_type", value))
    None => ()
  }
  match parse_string_arg(args, "--daily-limit-usd") {
    Some(value) => query.push(cli_query_pair("daily_limit_usd", value))
    None => ()
  }
  match parse_string_arg(args, "--monthly-limit-usd") {
    Some(value) => query.push(cli_query_pair("monthly_limit_usd", value))
    None => ()
  }
  if query.is_empty() {
    "/usage/provider-limits"
  } else {
    "/usage/provider-limits?\{query.join("&")}"
  }
}

///|
fn usage_sync_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--projects-dir") {
    Some(value) => query.push(cli_query_pair("projects_dir", value))
    None => ()
  }
  match parse_string_arg(args, "--codex-dir") {
    Some(value) => query.push(cli_query_pair("codex_dir", value))
    None => ()
  }
  match parse_string_arg(args, "--gemini-dir") {
    Some(value) => query.push(cli_query_pair("gemini_dir", value))
    None => ()
  }
  match parse_string_arg(args, "--opencode-export-path") {
    Some(value) => query.push(cli_query_pair("opencode_export_path", value))
    None => ()
  }
  match parse_string_arg(args, "--opencode-db-path") {
    Some(value) => query.push(cli_query_pair("opencode_db_path", value))
    None => ()
  }
  if query.is_empty() {
    "/usage/sync-session"
  } else {
    "/usage/sync-session?\{query.join("&")}"
  }
}

///|
async fn check_usage_endpoint(args : Array[String], path : String) -> Unit {
  check_json_endpoint(args, path, "Usage")
}

///|
async fn check_usage_detail(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  guard parse_string_arg_any(args, "--request-id", "--requestId")
    is Some(request_id) else {
    logger.error("Missing required --request-id")
    return
  }
  check_usage_endpoint(
    args,
    "/usage/request-detail/\{cli_url_encode(request_id)}",
  )
}

///|
async fn check_status(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")

  // 检查 hosts reroute 状态
  let hosts_installed = @hosts.is_reroute_installed()
  if hosts_installed {
    logger.info("Hosts reroute is installed")
  } else {
    logger.warn("Hosts reroute is NOT installed")
  }

  // 检查网关是否在运行
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.get("/status")
    if response.code == 200 {
      let body = client.read_all().text()
      logger.info("Gateway is running: \{body}")
    } else {
      logger.warn("Gateway is NOT running")
    }
  } catch {
    _ => logger.warn("Gateway is NOT running")
  }

  // 检查凭据
  let creds_result : Result[@codex.Credentials, Error] = cli_async_result(() => {
    @codex.load_credentials()
  })
  match creds_result {
    Ok(_) => logger.info("Credentials loaded")
    Err(_) => logger.warn("Credentials NOT loaded, please run: moonstat login")
  }
}

///|
async fn status_claude_desktop() -> Unit {
  let status = @claude_desktop.status()
  println(
    Json::object({
      "configured": Json::boolean(status.configured),
      "profile_path": Json::string(status.profile_path),
      "meta_path": Json::string(status.meta_path),
      "token_configured": Json::boolean(status.token_configured),
    }).stringify(indent=2),
  )
}

///|
async fn status_codex() -> Unit {
  let status = @codex_config.status()
  println(
    Json::object({
      "configured": Json::boolean(status.configured),
      "config_path": Json::string(status.config_path),
      "base_url": match status.base_url {
        Some(value) => Json::string(value)
        None => Json::null()
      },
      "model": match status.model {
        Some(value) => Json::string(value)
        None => Json::null()
      },
    }).stringify(indent=2),
  )
}

///|
fn print_suite_status(args : Array[String]) -> Unit {
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-5")
  println(
    @moonstat.moonstat_suite_status_json(host~, port~, model~).stringify(
      indent=2,
    ),
  )
}

///|
async fn write_suite_status(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-5")
  let path = parse_string_arg(args, "--path").unwrap_or(
    @moonstat.default_moonstat_suite_status_path(),
  )
  let written = @moonstat.write_moonstat_suite_status(
    path~,
    host~,
    port~,
    model~,
  )
  logger.info("Moon suite status written: \{written}")
}
