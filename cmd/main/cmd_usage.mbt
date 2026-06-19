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
    { id: "query_provider_usage", patterns: ["usage provider-usage"] },
    { id: "get_balance", patterns: ["usage balance"] },
    { id: "get_subscription_quota", patterns: ["usage quota"] },
    { id: "get_codex_oauth_quota", patterns: ["usage codex-oauth-quota"] },
    { id: "get_codex_oauth_models", patterns: ["usage codex-oauth-models"] },
    { id: "get_coding_plan_quota", patterns: ["usage coding-plan"] },
    { id: "test_usage_script", patterns: ["usage test-script"] },
    { id: "status", patterns: ["status"] },
    { id: "health", patterns: ["health"] },
    { id: "stats", patterns: ["stats"] },
    { id: "metrics", patterns: ["metrics"] },
  ]
}

///|
async fn check_health(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  match cli_moonstat_client(args).health() {
    Ok(body) => println("Gateway health: \{body.stringify()}")
    Err(err) => logger.error("Health check failed: \{err}")
  }
}

///|
async fn check_stats(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  match cli_moonstat_client(args).stats() {
    Ok(body) => println(body.stringify())
    Err(err) => logger.error("Stats check failed: \{err}")
  }
}

///|
async fn check_metrics(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  match cli_moonstat_client(args).metrics() {
    Ok(body) => println(body)
    Err(err) => logger.error("Metrics check failed: \{err}")
  }
}

///|
fn cli_moonstat_client(args : Array[String]) -> @moonstat.MoonstatClient {
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  @moonstat.MoonstatClient::new(base_url=url)
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
    "get_model_pricing" => check_usage_model_pricing(args)
    "update_model_pricing" => update_usage_pricing(args)
    "delete_model_pricing" => delete_usage_pricing(args)
    "check_provider_limits" => check_usage_limits(args)
    "sync_session_usage" => sync_session_usage(args)
    "get_usage_data_sources" => check_usage_data_sources(args)
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
    "metrics" => check_metrics(args)
    _ => ()
  }
}

///|
async fn check_usage_logs(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Usage logs",
    cli_moonstat_client(args).usage_logs(query=Some(usage_logs_query(args))),
  )
}

///|
async fn check_usage_summary(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Usage summary",
    cli_moonstat_client(args).usage_summary(
      query=Some(usage_query(args, app_filter=true)),
    ),
  )
}

///|
async fn check_usage_apps(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Usage apps",
    cli_moonstat_client(args).usage_summary_by_app(
      query=Some(usage_query(args, app_filter=false)),
    ),
  )
}

///|
async fn check_usage_trends(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Usage trends",
    cli_moonstat_client(args).usage_trends(
      query=Some(usage_query(args, app_filter=true)),
    ),
  )
}

///|
async fn check_usage_limits(args : Array[String]) -> Unit {
  check_usage_endpoint(args, usage_limits_path(args))
}

///|
async fn check_usage_models(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Usage models",
    cli_moonstat_client(args).usage_model_stats(
      query=Some(usage_query(args, app_filter=true)),
    ),
  )
}

///|
async fn test_usage_script(args : Array[String]) -> Unit {
  guard usage_provider_script_path(args, "/usage/test-script", true)
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required usage script args: --provider-id --app-type")
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
  print_cli_json_result(
    "Usage sync",
    cli_moonstat_client(args).usage_sync_session(
      query=Some(usage_sync_query(args)),
    ),
  )
}

///|
fn usage_query(
  args : Array[String],
  app_filter~ : Bool,
) -> @moonstat.MoonstatUsageQuery {
  @moonstat.MoonstatUsageQuery::new(
    start_date=parse_string_arg(args, "--start-date"),
    end_date=parse_string_arg(args, "--end-date"),
    app_type=if app_filter {
      parse_string_arg(args, "--app-type")
    } else {
      None
    },
    provider_id=None,
    provider_name=None,
    model=None,
    status_code=None,
    page=None,
    page_size=None,
  )
}

///|
fn usage_logs_query(args : Array[String]) -> @moonstat.MoonstatUsageQuery {
  @moonstat.MoonstatUsageQuery::new(
    start_date=parse_string_arg(args, "--start-date"),
    end_date=parse_string_arg(args, "--end-date"),
    app_type=parse_string_arg(args, "--app-type"),
    provider_id=None,
    provider_name=parse_string_arg(args, "--provider-name"),
    model=parse_string_arg(args, "--model"),
    status_code=parse_string_arg(args, "--status-code"),
    page=parse_optional_int_arg(args, "--page"),
    page_size=parse_optional_int_arg(args, "--page-size"),
  )
}

///|
fn usage_sync_query(args : Array[String]) -> @moonstat.MoonstatSessionSyncQuery {
  @moonstat.MoonstatSessionSyncQuery::new(
    projects_dir=parse_string_arg(args, "--projects-dir"),
    codex_dir=parse_string_arg(args, "--codex-dir"),
    gemini_dir=parse_string_arg(args, "--gemini-dir"),
    opencode_export_path=parse_string_arg(args, "--opencode-export-path"),
    opencode_db_path=parse_string_arg(args, "--opencode-db-path"),
  )
}

///|
fn parse_optional_int_arg(args : Array[String], name : String) -> Int? {
  match parse_string_arg(args, name) {
    Some(value) => Some(@string.parse_int(value[:])) catch { _ => None }
    None => None
  }
}

///|
fn usage_limits_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--provider-id") {
    Some(value) => query.push(cli_query_pair("providerId", value))
    None => ()
  }
  match parse_string_arg(args, "--app-type") {
    Some(value) => query.push(cli_query_pair("appType", value))
    None => ()
  }
  match parse_string_arg(args, "--daily-limit-usd") {
    Some(value) => query.push(cli_query_pair("dailyLimitUsd", value))
    None => ()
  }
  match parse_string_arg(args, "--monthly-limit-usd") {
    Some(value) => query.push(cli_query_pair("monthlyLimitUsd", value))
    None => ()
  }
  if query.is_empty() {
    "/usage/provider-limits"
  } else {
    "/usage/provider-limits?\{query.join("&")}"
  }
}

///|
async fn check_usage_endpoint(args : Array[String], path : String) -> Unit {
  check_json_endpoint(args, path, "Usage")
}

///|
async fn check_usage_model_pricing(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Usage pricing",
    cli_moonstat_client(args).usage_model_pricing(),
  )
}

///|
async fn check_usage_data_sources(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Usage data sources",
    cli_moonstat_client(args).usage_data_sources(),
  )
}

///|
async fn check_usage_detail(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  guard parse_string_arg(args, "--request-id") is Some(request_id) else {
    logger.error("Missing required --request-id")
    return
  }
  print_cli_json_result(
    "Usage detail",
    cli_moonstat_client(args).usage_request_detail(request_id),
  )
}

///|
async fn print_cli_json_result(
  label : String,
  result : Result[Json, String],
) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  match result {
    Ok(body) => println(body.stringify())
    Err(err) => logger.error("\{label} failed: \{err}")
  }
}

///|
async fn check_status(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())

  // 检查 hosts reroute 状态
  let hosts_installed = @hosts.is_reroute_installed()
  if hosts_installed {
    logger.info("Hosts reroute is installed")
  } else {
    logger.warn("Hosts reroute is NOT installed")
  }

  // 检查网关是否在运行
  match cli_moonstat_client(args).status() {
    Ok(body) => logger.info("Gateway is running: \{body.stringify()}")
    Err(_) => logger.warn("Gateway is NOT running")
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
fn claude_desktop_status_json(
  status : @claude_desktop.ClaudeDesktopStatus,
) -> Json {
  Json::object({
    "configured": Json::boolean(status.configured),
    "profilePath": Json::string(status.profile_path),
    "metaPath": Json::string(status.meta_path),
    "tokenConfigured": Json::boolean(status.token_configured),
  })
}

///|
async fn status_claude_desktop() -> Unit {
  let status = @claude_desktop.status()
  println(claude_desktop_status_json(status).stringify(indent=2))
}

///|
fn codex_status_json(status : @codex_config.CodexConfigStatus) -> Json {
  codex_status_fields_json(
    configured=status.configured,
    config_path=status.config_path,
    base_url=status.base_url,
    model=status.model,
  )
}

///|
fn codex_status_fields_json(
  configured~ : Bool,
  config_path~ : String,
  base_url~ : String?,
  model~ : String?,
) -> Json {
  Json::object({
    "configured": Json::boolean(configured),
    "configPath": Json::string(config_path),
    "baseUrl": match base_url {
      Some(value) => Json::string(value)
      None => Json::null()
    },
    "model": match model {
      Some(value) => Json::string(value)
      None => Json::null()
    },
  })
}

///|
async fn status_codex() -> Unit {
  let status = @codex_config.status()
  println(codex_status_json(status).stringify(indent=2))
}

///|
fn print_suite_status(args : Array[String]) -> Unit {
  let host = parse_string_arg(args, "--host").unwrap_or(@suite.default_host())
  let port = parse_int_arg(args, "--port", default=@suite.default_port())
  let model = parse_string_arg(args, "--model").unwrap_or(
    @suite.default_model(),
  )
  println(
    @moonstat.moonstat_suite_status_json(host~, port~, model~).stringify(
      indent=2,
    ),
  )
}

///|
async fn write_suite_status(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or(@suite.default_host())
  let port = parse_int_arg(args, "--port", default=@suite.default_port())
  let model = parse_string_arg(args, "--model").unwrap_or(
    @suite.default_model(),
  )
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
