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
