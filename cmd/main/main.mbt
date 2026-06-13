///|
pub async fn start(args : ArrayView[String]) -> Unit {
  let arr = args.to_array()
  match arr[1:] {
    ["start", ..] => start_gateway(arr)
    ["login", ..] => do_login(arr)
    ["install", ..] => install_reroute(arr)
    ["uninstall"] | ["remove"] => uninstall_reroute()
    ["claude-desktop", "install", ..] => install_claude_desktop(arr)
    ["claude-desktop", "uninstall" | "remove", ..] => uninstall_claude_desktop()
    ["claude-desktop", "status", ..] => status_claude_desktop()
    ["codex", "install", ..] => install_codex(arr)
    ["codex", "uninstall" | "remove", ..] => uninstall_codex()
    ["codex", "status", ..] => status_codex()
    ["models", "fetch", ..] => fetch_provider_models(arr)
    ["models", "candidates", ..] => print_model_candidates(arr)
    ["suite", "manifest", ..] => print_suite_manifest(arr)
    ["suite", "status", ..] => print_suite_status(arr)
    ["suite", "write-status", ..] => write_suite_status(arr)
    ["status", ..] => check_status(arr)
    ["health", ..] => check_health(arr)
    ["stats", ..] => check_stats(arr)
    ["proxy", "status", ..] => check_proxy_status(arr)
    ["proxy", "config", ..] => check_proxy_config(arr)
    ["proxy", "takeover-status", ..] => check_proxy_takeover_status(arr)
    ["proxy", "running", ..] => check_proxy_running(arr)
    ["usage", "logs", ..] => check_usage_logs(arr)
    ["usage", "summary", ..] => check_usage_summary(arr)
    ["usage", "apps", ..] => check_usage_apps(arr)
    ["usage", "trends", ..] => check_usage_trends(arr)
    ["usage", "limits", ..] => check_usage_limits(arr)
    ["usage", "sync", ..] => sync_session_usage(arr)
    ["usage", "providers", ..] => check_usage_providers(arr)
    ["usage", "models", ..] => check_usage_models(arr)
    ["usage", "sources", ..] => check_usage_endpoint(arr, "/usage/data-sources")
    ["usage", "pricing", "set", ..] => update_usage_pricing(arr)
    ["usage", "pricing", "delete", ..] => delete_usage_pricing(arr)
    ["usage", "pricing", ..] =>
      check_usage_endpoint(arr, "/usage/model-pricing")
    ["usage", "detail", ..] => check_usage_detail(arr)
    ["help"] | ["--help"] | ["-h"] => print_help()
    ["version"] | ["--version"] | ["-v"] => println("moonstat v0.1.0")
    _ => print_help()
  }
}

///|
async fn main {
  let args = @os.args()
  start(args)
}

///|
fn print_help() -> Unit {
  println("Moonstat - Anthropic to OpenAI Codex OAuth Gateway")
  println("")
  println("Usage: moonstat <command> [options]")
  println("")
  println("Commands:")
  println("  start       Start the gateway server")
  println("  install     Install hosts reroute (requires sudo)")
  println("  uninstall   Remove hosts reroute (requires sudo)")
  println(
    "  claude-desktop install    Configure Claude Desktop gateway profile",
  )
  println("  claude-desktop uninstall  Remove Claude Desktop gateway profile")
  println("  claude-desktop status     Show Claude Desktop profile status")
  println(
    "  codex install             Configure Codex config.toml for Moonstat",
  )
  println("  codex uninstall           Remove Moonstat Codex config block")
  println("  codex status              Show Codex config.toml Moonstat status")
  println(
    "  models fetch              Fetch provider models using ccs-compatible logic",
  )
  println("  models candidates         Print /v1/models candidate URLs")
  println("  suite manifest            Print Moon suite service manifest")
  println("  suite status              Print Moon suite status contract")
  println("  suite write-status        Write ~/.moonstat/suite-status.json")
  println("  status      Check reroute and gateway status")
  println("  stats       Show gateway traffic statistics")
  println("  proxy status           Show ccs-style proxy server status")
  println("  proxy config           Show ccs-style proxy server config")
  println("  proxy takeover-status  Show ccs-style app takeover status")
  println("  proxy running          Show ccs-style proxy running boolean")
  println("  usage logs  Show ccs-style recent proxy_request_logs")
  println("  usage summary    Show ccs-style usage summary")
  println("  usage apps       Show ccs-style usage summary by app")
  println("  usage trends     Show ccs-style hourly/daily usage trends")
  println("  usage limits     Show ccs-style provider limit status")
  println(
    "  usage sync       Sync ccs-style Claude/Codex/Gemini/OpenCode session logs",
  )
  println("  usage providers  Show ccs-style provider statistics")
  println("  usage models     Show ccs-style model statistics")
  println("  usage sources    Show ccs-style data source breakdown")
  println("  usage pricing    Show ccs-style editable model pricing")
  println("  usage pricing set       Upsert ccs-style model pricing")
  println("  usage pricing delete    Delete ccs-style model pricing")
  println("  usage detail     Show one ccs-style request detail by id")
  println("  login       Login to OpenAI Codex OAuth")
  println("  health      Check gateway health")
  println("  version     Show version")
  println("  help        Show this help message")
  println("")
  println("Start options:")
  println("  --host <host>      Address to listen on (default: 127.0.0.1)")
  println("  --port <port>      Port to listen on (default: 15721)")
  println("  --model <model>    Codex model to use (default: gpt-5)")
  println("")
  println("Model fetch options:")
  println("  --base-url <url>      Provider base URL")
  println("  --api-key <key>       Provider API key")
  println("  --full-url            Treat base URL as a full request endpoint")
  println("  --models-url <url>    Exact model-list endpoint override")
  println("  --user-agent <ua>     Custom User-Agent header")
  println("")
  println("Suite options:")
  println("  --path <path>     Status file path for suite write-status")
  println("")
  println("Examples:")
  println("  sudo moonstat install          # Install hosts reroute")
  println("  moonstat start                 # Start gateway on 127.0.0.1:15721")
  println("  moonstat start --port 80       # Start gateway on port 80")
  println("  moonstat claude-desktop install --port 15721")
  println("  moonstat codex install --port 15721 --model gpt-5")
  println(
    "  moonstat models fetch --base-url https://api.example.com --api-key sk-...",
  )
  println("  moonstat suite write-status --port 15721")
  println("  claude                         # Use Claude CLI through moonstat")
  println("  moonstat proxy status          # Show ccs-style proxy status")
  println("  moonstat stats                 # Show traffic counters")
  println("  moonstat usage logs            # Show recent request logs")
  println("  moonstat usage summary         # Show aggregate token/cost usage")
  println("  moonstat usage trends --start-date 0 --end-date 86400")
  println("  moonstat usage limits --provider-id codex-oauth --app-type codex")
  println(
    "  moonstat usage sync --projects-dir ~/.claude/projects --codex-dir ~/.codex --gemini-dir ~/.gemini --opencode-db-path ~/.local/share/opencode/opencode.db",
  )
  println(
    "  moonstat usage pricing set --model-id gpt-x --display-name GPT-X --input-cost 1 --output-cost 2 --cache-read-cost 0.1 --cache-creation-cost 0",
  )
  println("  moonstat usage pricing delete --model-id gpt-x")
  println("  moonstat usage detail --request-id req_x")
  println("  moonstat uninstall             # Remove hosts reroute")
}

///|
async fn start_gateway(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-5")
  logger.info("Starting Moonstat Gateway on \{host}:\{port}")
  logger.info("Using Codex model: \{model}")
  let gateway = @moonstat.Gateway::new(port~, host~, model~)
  logger.info("Gateway started on \{gateway.host()}:\{gateway.port()}")
  gateway.start()
}

///|
async fn do_login(_args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  logger.info("Starting OpenAI Codex OAuth login flow...")
  try {
    let creds = @codex.start_oauth_flow()
    logger.info("Login successful!")
    logger.info("Email: \{@codex.extract_token_claims(creds.idToken).email}")
    @codex.save_credentials(creds)
    logger.info("Credentials saved to ~/.moonstat/codex-credentials.json")
  } catch {
    err => logger.error("Login failed: \{err}")
  }
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
async fn check_proxy_status(args : Array[String]) -> Unit {
  check_proxy_endpoint(args, "/proxy/status")
}

///|
async fn check_proxy_config(args : Array[String]) -> Unit {
  check_proxy_endpoint(args, "/proxy/config")
}

///|
async fn check_proxy_takeover_status(args : Array[String]) -> Unit {
  check_proxy_endpoint(args, "/proxy/takeover-status")
}

///|
async fn check_proxy_running(args : Array[String]) -> Unit {
  check_proxy_endpoint(args, "/proxy/running")
}

///|
async fn check_proxy_endpoint(args : Array[String], path : String) -> Unit {
  check_json_endpoint(args, path, "Proxy")
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
async fn check_usage_providers(args : Array[String]) -> Unit {
  check_usage_endpoint(
    args,
    usage_filtered_path(args, "/usage/provider-stats", app_filter=true),
  )
}

///|
async fn check_usage_models(args : Array[String]) -> Unit {
  check_usage_endpoint(
    args,
    usage_filtered_path(args, "/usage/model-stats", app_filter=true),
  )
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
fn cli_path_with_query(path : String, query : Array[String]) -> String {
  if query.is_empty() {
    path
  } else {
    "\{path}?\{query.join("&")}"
  }
}

///|
fn usage_limits_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--provider-id") {
    Some(value) => query.push(cli_query_pair("provider_id", value))
    None => ()
  }
  match parse_string_arg(args, "--app-type") {
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
fn usage_pricing_update_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--model-id") is Some(model_id) else {
    return None
  }
  guard parse_string_arg(args, "--display-name") is Some(display_name) else {
    return None
  }
  guard parse_string_arg(args, "--input-cost") is Some(input_cost) else {
    return None
  }
  guard parse_string_arg(args, "--output-cost") is Some(output_cost) else {
    return None
  }
  guard parse_string_arg(args, "--cache-read-cost") is Some(cache_read_cost) else {
    return None
  }
  guard parse_string_arg(args, "--cache-creation-cost")
    is Some(cache_creation_cost) else {
    return None
  }
  let query = [
    cli_query_pair("model_id", model_id),
    cli_query_pair("display_name", display_name),
    cli_query_pair("input_cost", input_cost),
    cli_query_pair("output_cost", output_cost),
    cli_query_pair("cache_read_cost", cache_read_cost),
    cli_query_pair("cache_creation_cost", cache_creation_cost),
  ].join("&")
  Some("/usage/model-pricing?\{query}")
}

///|
fn usage_pricing_delete_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--model-id") is Some(model_id) else {
    return None
  }
  Some("/usage/model-pricing?\{cli_query_pair("model_id", model_id)}")
}

///|
async fn update_usage_pricing(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  guard usage_pricing_update_path(args) is Some(path) else {
    logger.error(
      "Missing required pricing args: --model-id --display-name --input-cost --output-cost --cache-read-cost --cache-creation-cost",
    )
    return
  }
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.post(path, "{}")
    let body = client.read_all().text()
    if response.code == 200 {
      println(body)
    } else {
      logger.error("Usage pricing update failed: \{response.code} \{body}")
    }
  } catch {
    err => logger.error("Usage pricing update failed: \{err}")
  }
}

///|
async fn delete_usage_pricing(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  guard usage_pricing_delete_path(args) is Some(path) else {
    logger.error("Missing required --model-id")
    return
  }
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    client.request(@http.RequestMethod::Delete, path)
    let response = client.end_request()
    if response.code == 204 {
      println("Deleted model pricing")
    } else {
      let body = client.read_all().text()
      logger.error("Usage pricing delete failed: \{response.code} \{body}")
    }
  } catch {
    err => logger.error("Usage pricing delete failed: \{err}")
  }
}

///|
async fn check_usage_endpoint(args : Array[String], path : String) -> Unit {
  check_json_endpoint(args, path, "Usage")
}

///|
async fn check_json_endpoint(
  args : Array[String],
  path : String,
  label : String,
) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.get(path)
    if response.code == 200 {
      let body = client.read_all().text()
      println(body)
    } else {
      logger.error("\{label} check failed: \{response.code}")
    }
  } catch {
    err => logger.error("\{label} check failed: \{err}")
  }
}

///|
async fn check_usage_detail(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  guard parse_string_arg(args, "--request-id") is Some(request_id) else {
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
  let creds_result : Result[@codex.Credentials, Error] = try? @codex.load_credentials()
  match creds_result {
    Ok(_) => logger.info("Credentials loaded")
    Err(_) => logger.warn("Credentials NOT loaded, please run: moonstat login")
  }
}

///|
async fn install_reroute(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let port = parse_int_arg(args, "--port", default=15721)

  logger.info("Installing hosts reroute for port \{port}...")
  let result = @hosts.install_and_flush(port)
  match result {
    Ok(_) => {
      logger.info("Hosts reroute installed successfully!")
      logger.info("Now you can use: moonstat start --port \{port}")
      logger.info("Then Anthropic API requests will route through moonstat.")
    }
    Err(e) => logger.error("Failed to install: \{e}")
  }
}

///|
async fn uninstall_reroute() -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())

  logger.info("Removing hosts reroute...")
  let result = @hosts.uninstall_and_flush()
  match result {
    Ok(_) => logger.info("Hosts reroute removed successfully!")
    Err(e) => logger.error("Failed to uninstall: \{e}")
  }
}

///|
async fn install_claude_desktop(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let token = parse_string_arg(args, "--token")
  logger.info("Installing Claude Desktop gateway profile...")
  let result = @claude_desktop.install_proxy_profile(host, port, token~)
  match result {
    Ok(installed) => {
      logger.info("Claude Desktop profile installed")
      logger.info("Gateway base URL: \{installed.base_url}")
      logger.info("Profile: \{installed.profile_path}")
      logger.info("Token saved for Moonstat gateway auth")
    }
    Err(e) => logger.error(e)
  }
}

///|
async fn uninstall_claude_desktop() -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  logger.info("Removing Claude Desktop gateway profile...")
  let result = @claude_desktop.uninstall_proxy_profile()
  match result {
    Ok(_) => logger.info("Claude Desktop profile removed")
    Err(e) => logger.error(e)
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
async fn install_codex(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-5")
  logger.info("Installing Codex config.toml Moonstat provider...")
  let result = @codex_config.install_proxy_config(host, port, model)
  match result {
    Ok(installed) => {
      logger.info("Codex Moonstat provider installed")
      logger.info("Config: \{installed.config_path}")
      logger.info("Gateway base URL: \{installed.base_url}")
      logger.info("Model: \{installed.model}")
    }
    Err(e) => logger.error(e)
  }
}

///|
async fn uninstall_codex() -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  logger.info("Removing Codex config.toml Moonstat provider...")
  let result = @codex_config.uninstall_proxy_config()
  match result {
    Ok(_) => logger.info("Codex Moonstat provider removed")
    Err(e) => logger.error(e)
  }
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
async fn fetch_provider_models(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  guard parse_string_arg(args, "--base-url") is Some(base_url) else {
    logger.error("Missing required --base-url")
    return
  }
  guard parse_string_arg(args, "--api-key") is Some(api_key) else {
    logger.error("Missing required --api-key")
    return
  }
  let is_full_url = has_flag(args, "--full-url") ||
    has_flag(args, "--is-full-url")
  let models_url = parse_string_arg(args, "--models-url")
  let user_agent = parse_string_arg(args, "--user-agent")
  let result = @moonstat.fetch_models(
    base_url, api_key, is_full_url, models_url, user_agent,
  )
  match result {
    Ok(models) => println(provider_models_to_json(models).stringify(indent=2))
    Err(e) => logger.error(e)
  }
}

///|
async fn print_model_candidates(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  guard parse_string_arg(args, "--base-url") is Some(base_url) else {
    logger.error("Missing required --base-url")
    return
  }
  let is_full_url = has_flag(args, "--full-url") ||
    has_flag(args, "--is-full-url")
  let models_url = parse_string_arg(args, "--models-url")
  match
    @moonstat.build_models_url_candidates(base_url, is_full_url, models_url) {
    Ok(candidates) =>
      println(
        Json::array(candidates.map(fn(url) { Json::string(url) })).stringify(
          indent=2,
        ),
      )
    Err(e) => logger.error(e)
  }
}

///|
fn provider_models_to_json(models : Array[@moonstat.FetchedModel]) -> Json {
  Json::array(models.map(provider_model_to_json))
}

///|
fn provider_model_to_json(model : @moonstat.FetchedModel) -> Json {
  provider_model_fields_to_json(model.id, model.owned_by)
}

///|
fn provider_model_fields_to_json(id : String, owned_by : String?) -> Json {
  Json::object({
    "id": Json::string(id),
    "ownedBy": match owned_by {
      Some(value) => Json::string(value)
      None => Json::null()
    },
  })
}

///|
fn print_suite_manifest(args : Array[String]) -> Unit {
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-5")
  println(
    @moonstat.moonstat_suite_manifest_json(host~, port~, model~).stringify(
      indent=2,
    ),
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

///|
fn parse_string_arg(args : Array[String], name : String) -> String? {
  let mut i = 0
  while i < args.length() {
    if args[i] == name && i + 1 < args.length() {
      return Some(args[i + 1])
    }
    i = i + 1
  }
  None
}

///|
fn parse_string_arg_any(
  args : Array[String],
  left_name : String,
  right_name : String,
) -> String? {
  match parse_string_arg(args, left_name) {
    Some(value) => Some(value)
    None => parse_string_arg(args, right_name)
  }
}

///|
fn cli_query_pair(key : String, value : String) -> String {
  "\{cli_url_encode(key)}=\{cli_url_encode(value)}"
}

///|
fn cli_url_encode(value : String) -> String {
  let builder = StringBuilder::new()
  for ch in value {
    match ch {
      'A'..='Z' | 'a'..='z' | '0'..='9' | '-' | '_' | '.' | '~' =>
        builder.write_char(ch)
      _ => {
        let bytes = @encoding/utf8.encode(ch.to_string())
        for byte in bytes {
          let hex = byte.to_int()
          builder.write_char('%')
          builder.write_char(cli_hex_digit((hex >> 4) & 0xF))
          builder.write_char(cli_hex_digit(hex & 0xF))
        }
      }
    }
  }
  builder.to_string()
}

///|
fn cli_hex_digit(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('A'.to_int() + n - 10).unsafe_to_char()
  }
}

///|
fn has_flag(args : Array[String], name : String) -> Bool {
  for arg in args {
    if arg == name {
      return true
    }
  }
  false
}

///|
fn parse_int_arg(args : Array[String], name : String, default~ : Int) -> Int {
  match parse_string_arg(args, name) {
    Some(s) => {
      let result : Result[Int, Error] = try? @strconv.parse_int(s[:], base=10)
      match result {
        Ok(n) => n
        Err(_) => default
      }
    }
    None => default
  }
}
