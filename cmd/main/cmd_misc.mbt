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
  println("  fetch_models_for_config   Alias for ccs model fetch command")
  println("  models candidates         Print /v1/models candidate URLs")
  println("  auth status               Alias for ccs auth_get_status")
  println("  auth start-login          Alias for ccs auth_start_login")
  println("  auth poll                 Alias for ccs auth_poll_for_account")
  println("  stream-check provider     Alias for ccs stream_check_provider")
  println(
    "  stream-check all          Alias for ccs stream_check_all_providers",
  )
  println("  stream-check config       Alias for ccs get_stream_check_config")
  println("  stream-check config set   Alias for ccs save_stream_check_config")
  println("  update_tray_menu          Alias for ccs update_tray_menu")
  println("  suite manifest            Print Moon suite service manifest")
  println("  suite status              Print Moon suite status contract")
  println("  suite write-status        Write ~/.moonsuite/suite-status.json")
  println("  suite moonclaw-providers  Print MoonClaw providers.json")
  println("  suite write-moonclaw-providers  Write .moonclaw/providers.json")
  println("  status      Check reroute and gateway status")
  println("  stats       Show gateway traffic statistics")
  println("  proxy status           Show ccs-style proxy server status")
  println(
    "  <moon_proxy_command>    Direct alias for CCS proxy/failover command names",
  )
  println(
    "  <moon_provider_command> Direct alias for CCS provider command names",
  )
  println("  <moon_usage_command>    Direct alias for CCS usage command names")
  println(
    "  <moon_stream_command>   Direct alias for CCS stream check command names",
  )
  println("  mcp list/upsert/delete/toggle  Manage ccs-style MCP servers")
  println("  mcp config/upsert-config       Manage app MCP config view")
  println("  prompt list/upsert/delete      Manage ccs-style prompt records")
  println(
    "  proxy start-proxy-server  Enable proxy routing and print server info",
  )
  println(
    "  proxy stop-proxy-server   Disable proxy routing when no takeover is active",
  )
  println(
    "  proxy stop-proxy-with-restore  Disable proxy routing and clear takeover state",
  )
  println("  proxy config           Show ccs-style proxy server config")
  println("  proxy config set       Update ccs-style legacy proxy config")
  println("  proxy global-config    Show ccs-style global proxy config")
  println("  proxy global-config set  Update ccs-style global proxy config")
  println("  proxy app-config       Show ccs-style app proxy config")
  println("  proxy app-config set   Update ccs-style app proxy config")
  println("  proxy default-cost-multiplier  Show ccs-style app cost multiplier")
  println(
    "  proxy default-cost-multiplier set  Set ccs-style app cost multiplier",
  )
  println("  proxy pricing-model-source     Show ccs-style app pricing mode")
  println("  proxy pricing-model-source set     Set ccs-style app pricing mode")
  println("  proxy provider-health          Show ccs-style provider health")
  println("  proxy circuit-breaker-config   Show ccs-style circuit config")
  println("  proxy circuit-breaker-config set  Update ccs-style circuit config")
  println("  proxy circuit-breaker-stats    Show ccs-style circuit stats")
  println("  proxy reset-circuit-breaker    Reset provider circuit breaker")
  println("  proxy failover-queue           Show ccs-style failover queue")
  println("  proxy failover-queue add       Add provider to failover queue")
  println(
    "  proxy failover-queue remove    Remove provider from failover queue",
  )
  println("  proxy available-failover-providers  Show providers outside queue")
  println("  proxy auto-failover-enabled    Show app auto-failover boolean")
  println("  proxy auto-failover-enabled set  Set app auto-failover boolean")
  println("  proxy takeover-status  Show ccs-style app takeover status")
  println("  proxy takeover-status set  Set ccs-style app takeover state")
  println("  proxy is-live-takeover-active  Show ccs takeover active boolean")
  println("  proxy switch-proxy-provider  Hot-switch current app provider")
  println("  proxy running          Show ccs-style proxy running boolean")
  println("  proxy is-proxy-running  Alias for ccs is_proxy_running")
  println("  provider list          Alias for ccs get_providers")
  println("  provider current       Alias for ccs get_current_provider")
  println("  provider add           Alias for ccs add_provider")
  println("  provider update        Alias for ccs update_provider")
  println("  provider delete        Alias for ccs delete_provider")
  println(
    "  provider remove-live   Alias for ccs remove_provider_from_live_config",
  )
  println("  provider sync-live     Alias for ccs sync_current_providers_live")
  println("  provider switch        Alias for ccs switch_provider")
  println("  provider live-settings Alias for ccs read_live_provider_settings")
  println("  provider test-endpoints Alias for ccs test_api_endpoints")
  println("  provider sort-order set Alias for ccs update_providers_sort_order")
  println("  provider endpoints list    Alias for ccs get_custom_endpoints")
  println("  provider endpoints add     Alias for ccs add_custom_endpoint")
  println("  provider endpoints remove  Alias for ccs remove_custom_endpoint")
  println(
    "  provider endpoints touch   Alias for ccs update_endpoint_last_used",
  )
  println("  provider presets list      Show ccs-style provider presets")
  println(
    "  settings get/save          Alias for ccs get_settings/save_settings",
  )
  println(
    "  settings app-config-dir    Show or set ccs app_config_dir override",
  )
  println("  settings auto-launch       Show or set ccs auto launch state")
  println("  settings rectifier         Show or set ccs rectifier config")
  println("  settings optimizer         Show or set ccs optimizer config")
  println(
    "  settings copilot-optimizer Show or set ccs Copilot optimizer config",
  )
  println("  settings log               Show or set ccs log config")
  println(
    "  plugin claude status/config/apply/applied  Manage ccs Claude plugin state",
  )
  println(
    "  plugin claude onboarding-skip/onboarding-clear  Toggle onboarding skip",
  )
  println("  workspace read/write/open  Manage ccs OpenClaw workspace files")
  println(
    "  workspace memory list/read/write/search/delete  Manage daily memory",
  )
  println("  usage logs  Show ccs-style recent proxy_request_logs")
  println("  usage get-request-logs  Alias for ccs get_request_logs")
  println("  usage summary    Show ccs-style usage summary")
  println("  usage get-usage-summary  Alias for ccs get_usage_summary")
  println("  usage apps       Show ccs-style usage summary by app")
  println(
    "  usage get-usage-summary-by-app  Alias for ccs get_usage_summary_by_app",
  )
  println("  usage trends     Show ccs-style hourly/daily usage trends")
  println("  usage get-usage-trends  Alias for ccs get_usage_trends")
  println("  usage limits     Show ccs-style provider limit status")
  println("  usage check-provider-limits  Alias for ccs check_provider_limits")
  println(
    "  usage sync       Sync ccs-style Claude/Codex/Gemini/OpenCode session logs",
  )
  println("  usage sync-session-usage  Alias for ccs sync_session_usage")
  println("  list_sessions  Alias for ccs session list command")
  println("  get_session_messages --provider-id <id> --source-path <path>")
  println(
    "  delete_session --provider-id <id> --session-id <id> --source-path <path>",
  )
  println("  usage providers  Show ccs-style provider statistics")
  println("  usage get-provider-stats  Alias for ccs get_provider_stats")
  println("  usage models     Show ccs-style model statistics")
  println("  usage get-model-stats  Alias for ccs get_model_stats")
  println("  usage sources    Show ccs-style data source breakdown")
  println(
    "  usage get-usage-data-sources  Alias for ccs get_usage_data_sources",
  )
  println("  usage query-provider-usage  Alias for ccs queryProviderUsage")
  println("  usage balance    Alias for ccs get_balance")
  println("  usage quota      Alias for ccs get_subscription_quota")
  println("  usage coding-plan Alias for ccs get_coding_plan_quota")
  println("  usage codex-oauth-quota Alias for ccs get_codex_oauth_quota")
  println("  usage codex-oauth-models Alias for ccs get_codex_oauth_models")
  println("  usage test-usage-script     Alias for ccs testUsageScript")
  println("  usage pricing    Show ccs-style editable model pricing")
  println("  usage get-model-pricing  Alias for ccs get_model_pricing")
  println("  usage pricing set       Upsert ccs-style model pricing")
  println("  usage update-model-pricing  Alias for ccs update_model_pricing")
  println("  usage pricing delete    Delete ccs-style model pricing")
  println("  usage delete-model-pricing  Alias for ccs delete_model_pricing")
  println("  usage detail     Show one ccs-style request detail by id")
  println("  usage get-request-detail  Alias for ccs get_request_detail")
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
  println("Proxy config options:")
  println("  --app-type <app>  App type for app-level proxy config")
  println("  --provider-id <id> Provider id for provider-level proxy commands")
  println("  --id <id>          Provider id for ccs provider CRUD commands")
  println("  --name <name>      Provider display name for provider add/update")
  println("  --base-url <url>   Provider API base URL for provider add/update")
  println("  --api-key <key>    Provider API key for provider add/update")
  println("  --category <kind>  Provider category for provider add/update")
  println("  --endpoint-url <url> Provider custom endpoint URL")
  println("  --app <app>         App id for ccs usage script commands")
  println("  --server <json>     MCP server JSON for ccs MCP upsert commands")
  println("  --command <cmd>     MCP command name for validation/upsert")
  println("  --content <text>    Prompt content for ccs prompt upsert commands")
  println("  --conflicts <json>  JSON conflict array for ccs env delete")
  println("  --imports <json>    JSON import array for ccs skill import")
  println("  --items <json>      JSON item array for ccs bulk commands")
  println("  --target <loc>      Skill storage target: cc_switch or unified")
  println("  --script-code <json> JSON UsageResult for ccs testUsageScript")
  println("  --value <value>    Value for ccs proxy scalar setter commands")
  println(
    "  --enabled <bool>   Boolean for proxy app/takeover/failover commands",
  )
  println("  --proxy-enabled <bool> Global proxy enabled flag")
  println("  --listen-address <host> Global proxy listen address")
  println("  --listen-port <port>   Global proxy listen port")
  println("  --enable-logging <bool> Global proxy logging flag")
  println("  --max-retries <n>      App proxy max retries")
  println("  --streaming-first-byte-timeout <n> App stream first-byte timeout")
  println("  --streaming-idle-timeout <n>       App stream idle timeout")
  println("  --non-streaming-timeout <n>        App non-stream timeout")
  println("  --failure-threshold <n>     Circuit failures before open")
  println("  --success-threshold <n>     Half-open successes before close")
  println("  --timeout-seconds <n>       Circuit open timeout in seconds")
  println("  --error-rate-threshold <n>  Circuit error-rate threshold, 0.0-1.0")
  println("  --min-requests <n>          Minimum requests for error-rate open")
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
  println("  moonstat proxy start-proxy-server")
  println(
    "  moonstat proxy switch-proxy-provider --app-type codex --provider-id codex-oauth",
  )
  println("  moonstat provider list --app codex")
  println(
    "  moonstat provider add --app codex --id custom --name Custom --base-url https://api.example.com/v1 --api-key sk-...",
  )
  println("  moonstat provider switch --app codex --id custom")
  println(
    "  moonstat provider endpoints add --app codex --id custom --endpoint-url https://api.backup.example.com/v1",
  )
  println(
    "  moonstat stream-check provider --app-type codex --provider-id codex-oauth",
  )
  println(
    "  moonstat stream-check all --app-type codex --proxy-targets-only true",
  )
  println(
    "  moonstat stream-check config set --codex-model gpt-5.5@low --timeout-secs 45",
  )
  println(
    "  moonstat mcp upsert --id filesystem --command npx --name Filesystem",
  )
  println("  moonstat mcp toggle --id filesystem --app codex --enabled true")
  println(
    "  moonstat prompt upsert --app codex --id review --name Review --content 'Review this change'",
  )
  println("  moonstat proxy app-config --app-type codex")
  println(
    "  moonstat proxy global-config set --proxy-enabled true --listen-address 127.0.0.1 --listen-port 15721",
  )
  println(
    "  moonstat proxy app-config set --app-type codex --enabled true --max-retries 3",
  )
  println(
    "  moonstat proxy default-cost-multiplier set --app-type codex --value 1.25",
  )
  println(
    "  moonstat proxy pricing-model-source set --app-type codex --value request",
  )
  println(
    "  moonstat proxy takeover-status set --app-type codex --enabled true",
  )
  println(
    "  moonstat proxy provider-health --app-type codex --provider-id codex-oauth",
  )
  println(
    "  moonstat proxy circuit-breaker-config set --failure-threshold 4 --success-threshold 2 --timeout-seconds 60 --error-rate-threshold 0.6 --min-requests 10",
  )
  println("  moonstat proxy failover-queue --app-type codex")
  println(
    "  moonstat proxy failover-queue add --app-type codex --provider-id codex-oauth",
  )
  println(
    "  moonstat proxy auto-failover-enabled set --app-type codex --enabled true",
  )
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
async fn import_default_config(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    provider_app_path(args, "/import_default_config"),
    "Provider",
  )
}

///|
async fn import_default_config_test_hook(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    provider_app_path(args, "/import_default_config_test_hook"),
    "Provider",
  )
}

///|
async fn save_settings(args : Array[String]) -> Unit {
  guard parse_string_arg_any(args, "--settings", "--config") is Some(settings) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --settings JSON")
    return
  }
  post_json_body_endpoint(args, "/save_settings", settings, "Settings")
}

///|
async fn delete_sessions(args : Array[String]) -> Unit {
  guard delete_sessions_body(args) is Some(body) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --items JSON")
    return
  }
  post_json_body_endpoint(args, "/delete_sessions", body, "Session")
}

///|
fn delete_sessions_body(args : Array[String]) -> String? {
  parse_string_arg_any(args, "--items", "--body")
}

///|
async fn import_skills_from_apps(args : Array[String]) -> Unit {
  guard import_skills_from_apps_body(args) is Some(body) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --imports JSON")
    return
  }
  post_json_body_endpoint(args, "/import_skills_from_apps", body, "Skills")
}

///|
fn import_skills_from_apps_body(args : Array[String]) -> String? {
  parse_string_arg_any(args, "--imports", "--body")
}

///|
async fn migrate_skill_storage(args : Array[String]) -> Unit {
  guard migrate_skill_storage_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --target")
    return
  }
  check_json_post_endpoint(args, path, "Skills")
}

///|
fn migrate_skill_storage_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--target") is Some(target) else { return None }
  Some(
    cli_path_with_query("/migrate_skill_storage", [
      cli_query_pair("target", target),
    ]),
  )
}

///|
async fn delete_env_vars(args : Array[String]) -> Unit {
  guard delete_env_vars_body(args) is Some(body) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --conflicts JSON")
    return
  }
  post_json_body_endpoint(args, "/delete_env_vars", body, "Env")
}

///|
fn delete_env_vars_body(args : Array[String]) -> String? {
  parse_string_arg_any(args, "--conflicts", "--body")
}

///|
async fn set_moon_json_config(
  args : Array[String],
  base_path : String,
  flag : String,
  label : String,
) -> Unit {
  guard moon_json_config_path(args, base_path, flag) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required \{flag} JSON or config field flags")
    return
  }
  check_json_post_endpoint(args, path, label)
}

///|
async fn set_app_config_dir_override(args : Array[String]) -> Unit {
  guard app_config_dir_override_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --path or --clear")
    return
  }
  check_json_post_endpoint(args, path, "Settings")
}

///|
async fn set_auto_launch(args : Array[String]) -> Unit {
  guard set_auto_launch_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --enabled")
    return
  }
  check_json_post_endpoint(args, path, "Settings")
}

///|
async fn apply_claude_plugin_config(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    apply_claude_plugin_config_path(args),
    "Plugin",
  )
}

///|
async fn set_config_snippet(
  args : Array[String],
  base_path : String,
  app_required~ : Bool,
) -> Unit {
  guard config_snippet_path(args, base_path, app_required~) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --snippet")
    return
  }
  check_json_post_endpoint(args, path, "Config")
}

///|
async fn restore_env_backup(args : Array[String]) -> Unit {
  guard restore_env_backup_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --backup-path")
    return
  }
  check_json_post_endpoint(args, path, "Env")
}

///|
async fn upsert_mcp_server(args : Array[String], base_path : String) -> Unit {
  guard mcp_upsert_path(args, base_path) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required MCP server args: --id or --server")
    return
  }
  check_json_post_endpoint(args, path, "MCP")
}

///|
async fn delete_mcp_server(args : Array[String], base_path : String) -> Unit {
  guard mcp_id_path(args, base_path) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_delete_endpoint(args, path, "MCP")
}

///|
async fn set_mcp_enabled(args : Array[String]) -> Unit {
  guard mcp_enabled_path(args, "/set_mcp_enabled") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required MCP args: --id --enabled")
    return
  }
  check_json_post_endpoint(args, path, "MCP")
}

///|
async fn toggle_mcp_app(args : Array[String]) -> Unit {
  guard mcp_enabled_path(args, "/toggle_mcp_app") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required MCP args: --id --enabled")
    return
  }
  check_json_post_endpoint(args, path, "MCP")
}

///|
async fn upsert_prompt(args : Array[String]) -> Unit {
  guard prompt_upsert_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required prompt args: --id")
    return
  }
  check_json_post_endpoint(args, path, "Prompt")
}

///|
async fn delete_prompt(args : Array[String]) -> Unit {
  guard prompt_id_path(args, "/delete_prompt") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_delete_endpoint(args, path, "Prompt")
}

///|
async fn enable_prompt(args : Array[String]) -> Unit {
  guard prompt_id_path(args, "/enable_prompt") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_post_endpoint(args, path, "Prompt")
}

///|
async fn test_api_endpoints(args : Array[String]) -> Unit {
  guard provider_test_endpoints_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --url or --urls")
    return
  }
  check_json_endpoint(args, path, "Provider")
}

///|
fn config_app_arg(args : Array[String]) -> String {
  parse_string_arg_any(args, "--app", "--appType").unwrap_or(
    parse_string_arg(args, "--app-type").unwrap_or("claude"),
  )
}

///|
fn config_app_path(args : Array[String], base_path : String) -> String {
  "\{base_path}?\{cli_query_pair("app", config_app_arg(args))}"
}

///|
fn app_config_dir_override_path(args : Array[String]) -> String? {
  match parse_string_arg(args, "--path") {
    Some(path) =>
      Some("/set_app_config_dir_override?\{cli_query_pair("path", path)}")
    None =>
      match parse_string_arg(args, "--clear") {
        Some(value) =>
          if value == "true" || value == "1" || value == "yes" {
            Some("/set_app_config_dir_override?path=")
          } else {
            None
          }
        None => None
      }
  }
}

///|
fn set_auto_launch_path(args : Array[String]) -> String? {
  match parse_string_arg(args, "--enabled") {
    Some(enabled) =>
      Some("/set_auto_launch?\{cli_query_pair("enabled", enabled)}")
    None => None
  }
}

///|
fn moon_json_config_path(
  args : Array[String],
  base_path : String,
  flag : String,
) -> String? {
  match parse_string_arg(args, flag) {
    Some(config) =>
      return Some("\{base_path}?\{cli_query_pair("config", config)}")
    None => ()
  }
  let query : Array[String] = []
  for flag_name in moon_json_config_flag_names() {
    match parse_string_arg(args, "--\{flag_name}") {
      Some(value) => query.push(cli_query_pair(flag_name, value))
      None => ()
    }
  }
  if query.is_empty() {
    None
  } else {
    Some("\{base_path}?\{query.join("&")}")
  }
}

///|
fn moon_json_config_flag_names() -> Array[String] {
  [
    "enabled", "requestThinkingSignature", "request_thinking_signature", "requestThinkingBudget",
    "request_thinking_budget", "requestMediaFallback", "request_media_fallback",
    "requestMediaHeuristic", "request_media_heuristic", "thinkingOptimizer", "thinking_optimizer",
    "cacheInjection", "cache_injection", "cacheTtl", "cache_ttl", "requestClassification",
    "request_classification", "toolResultMerging", "tool_result_merging", "compactDetection",
    "compact_detection", "deterministicRequestId", "deterministic_request_id", "subagentDetection",
    "subagent_detection", "warmupDowngrade", "warmup_downgrade", "warmupModel", "warmup_model",
    "stripThinking", "strip_thinking", "level",
  ]
}

///|
fn apply_claude_plugin_config_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--official") {
    Some(official) =>
      "/apply_claude_plugin_config?\{cli_query_pair("official", official)}"
    None => "/apply_claude_plugin_config"
  }
}

///|
fn pick_directory_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--default-path", "--defaultPath") {
    Some(path) => query.push(cli_query_pair("defaultPath", path))
    None => ()
  }
  cli_path_with_query("/pick_directory", query)
}

///|
fn open_external_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--url") {
    Some(url) => "/open_external?\{cli_query_pair("url", url)}"
    None => "/open_external"
  }
}

///|
fn copy_text_to_clipboard_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--text") {
    Some(text) => "/copy_text_to_clipboard?\{cli_query_pair("text", text)}"
    None => "/copy_text_to_clipboard"
  }
}

///|
fn tool_versions_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--tools") {
    Some(tools) => "/get_tool_versions?\{cli_query_pair("tools", tools)}"
    None => "/get_tool_versions"
  }
}

///|
async fn run_tool_lifecycle_action(args : Array[String]) -> Unit {
  guard tool_lifecycle_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --action")
    return
  }
  check_json_post_endpoint(args, path, "App shell")
}

///|
fn tool_lifecycle_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--action") is Some(action) else { return None }
  let query : Array[String] = [cli_query_pair("action", action)]
  match parse_string_arg(args, "--tools") {
    Some(tools) => query.push(cli_query_pair("tools", tools))
    None => ()
  }
  Some(cli_path_with_query("/run_tool_lifecycle_action", query))
}

///|
fn tool_installations_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--tools") {
    Some(tools) => "/probe_tool_installations?\{cli_query_pair("tools", tools)}"
    None => "/probe_tool_installations"
  }
}

///|
fn window_theme_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--theme") {
    Some(theme) => "/set_window_theme?\{cli_query_pair("theme", theme)}"
    None => "/set_window_theme"
  }
}

///|
fn db_backup_rename_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--old-filename", "--oldFilename") {
    Some(filename) => query.push(cli_query_pair("oldFilename", filename))
    None =>
      match parse_string_arg(args, "--filename") {
        Some(filename) => query.push(cli_query_pair("oldFilename", filename))
        None => ()
      }
  }
  match parse_string_arg_any(args, "--new-name", "--newName") {
    Some(name) => query.push(cli_query_pair("newName", name))
    None =>
      match parse_string_arg(args, "--name") {
        Some(name) => query.push(cli_query_pair("newName", name))
        None => ()
      }
  }
  cli_path_with_query("/rename_db_backup", query)
}

///|
fn deeplink_url_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--url") {
    Some(url) => query.push(cli_query_pair("url", url))
    None => ()
  }
  cli_path_with_query(base_path, query)
}

///|
fn deeplink_request_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--request") {
    Some(request) => query.push(cli_query_pair("request", request))
    None =>
      match parse_string_arg(args, "--url") {
        Some(url) => query.push(cli_query_pair("url", url))
        None => ()
      }
  }
  cli_path_with_query(base_path, query)
}

///|
fn sync_settings_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--settings", "--config") {
    Some(settings) => query.push(cli_query_pair("settings", settings))
    None => ()
  }
  match
    parse_string_arg_any(
      args, "--preserve-empty-password", "--preserveEmptyPassword",
    ) {
    Some(value) => query.push(cli_query_pair("preserveEmptyPassword", value))
    None => ()
  }
  match parse_string_arg_any(args, "--password-touched", "--passwordTouched") {
    Some(value) => query.push(cli_query_pair("passwordTouched", value))
    None => ()
  }
  cli_path_with_query(base_path, query)
}

///|
fn session_messages_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--provider-id", "--providerId") {
    Some(value) => query.push(cli_query_pair("providerId", value))
    None => ()
  }
  match parse_string_arg_any(args, "--source-path", "--sourcePath") {
    Some(value) => query.push(cli_query_pair("sourcePath", value))
    None => ()
  }
  cli_path_with_query("/get_session_messages", query)
}

///|
fn launch_session_terminal_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--command") {
    Some(value) => query.push(cli_query_pair("command", value))
    None => ()
  }
  match parse_string_arg(args, "--cwd") {
    Some(value) => query.push(cli_query_pair("cwd", value))
    None => ()
  }
  match parse_string_arg_any(args, "--custom-config", "--customConfig") {
    Some(value) => query.push(cli_query_pair("customConfig", value))
    None => ()
  }
  cli_path_with_query("/launch_session_terminal", query)
}

///|
fn delete_session_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--provider-id", "--providerId") {
    Some(value) => query.push(cli_query_pair("providerId", value))
    None => ()
  }
  match parse_string_arg_any(args, "--session-id", "--sessionId") {
    Some(value) => query.push(cli_query_pair("sessionId", value))
    None => ()
  }
  match parse_string_arg_any(args, "--source-path", "--sourcePath") {
    Some(value) => query.push(cli_query_pair("sourcePath", value))
    None => ()
  }
  cli_path_with_query("/delete_session", query)
}

///|
fn skill_app_arg(args : Array[String]) -> String {
  config_app_arg(args)
}

///|
fn skill_id_arg(args : Array[String]) -> String? {
  match parse_string_arg(args, "--id") {
    Some(id) => Some(id)
    None =>
      match parse_string_arg(args, "--directory") {
        Some(directory) => Some(directory)
        None => parse_string_arg_any(args, "--skill-id", "--skillId")
      }
  }
}

///|
fn skill_app_path(args : Array[String], base_path : String) -> String {
  cli_path_with_query(base_path, [cli_query_pair("app", skill_app_arg(args))])
}

///|
fn skill_id_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = []
  match skill_id_arg(args) {
    Some(id) => query.push(cli_query_pair("id", id))
    None => ()
  }
  match parse_string_arg_any(args, "--app", "--appType") {
    Some(app) => query.push(cli_query_pair("app", app))
    None =>
      match parse_string_arg(args, "--app-type") {
        Some(app) => query.push(cli_query_pair("app", app))
        None => ()
      }
  }
  cli_path_with_query(base_path, query)
}

///|
fn skill_backup_id_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--backup-id", "--backupId") {
    Some(backup_id) => query.push(cli_query_pair("backupId", backup_id))
    None =>
      match parse_string_arg(args, "--id") {
        Some(backup_id) => query.push(cli_query_pair("backupId", backup_id))
        None => ()
      }
  }
  cli_path_with_query(base_path, query)
}

///|
fn skill_restore_backup_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--backup-id", "--backupId") {
    Some(backup_id) => query.push(cli_query_pair("backupId", backup_id))
    None =>
      match parse_string_arg(args, "--id") {
        Some(backup_id) => query.push(cli_query_pair("backupId", backup_id))
        None => ()
      }
  }
  match parse_string_arg_any(args, "--current-app", "--currentApp") {
    Some(app) => query.push(cli_query_pair("currentApp", app))
    None =>
      match parse_string_arg_any(args, "--app", "--appType") {
        Some(app) => query.push(cli_query_pair("currentApp", app))
        None =>
          match parse_string_arg(args, "--app-type") {
            Some(app) => query.push(cli_query_pair("currentApp", app))
            None => ()
          }
      }
  }
  cli_path_with_query("/restore_skill_backup", query)
}

///|
fn skill_install_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--directory") {
    Some(directory) => query.push(cli_query_pair("directory", directory))
    None =>
      match parse_string_arg(args, "--id") {
        Some(id) => query.push(cli_query_pair("directory", id))
        None =>
          match parse_string_arg(args, "--key") {
            Some(key) => query.push(cli_query_pair("directory", key))
            None => ()
          }
      }
  }
  match parse_string_arg(args, "--name") {
    Some(name) => query.push(cli_query_pair("name", name))
    None => ()
  }
  match parse_string_arg(args, "--description") {
    Some(description) => query.push(cli_query_pair("description", description))
    None => ()
  }
  match parse_string_arg_any(args, "--current-app", "--currentApp") {
    Some(app) => query.push(cli_query_pair("currentApp", app))
    None =>
      match parse_string_arg_any(args, "--app", "--appType") {
        Some(app) => query.push(cli_query_pair("app", app))
        None =>
          match parse_string_arg(args, "--app-type") {
            Some(app) => query.push(cli_query_pair("app", app))
            None => ()
          }
      }
  }
  cli_path_with_query(base_path, query)
}

///|
fn skill_toggle_app_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match skill_id_arg(args) {
    Some(id) => query.push(cli_query_pair("id", id))
    None => ()
  }
  query.push(cli_query_pair("app", skill_app_arg(args)))
  match parse_string_arg(args, "--enabled") {
    Some(enabled) => query.push(cli_query_pair("enabled", enabled))
    None => ()
  }
  cli_path_with_query("/toggle_skill_app", query)
}

///|
fn skill_search_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--query", "--q") {
    Some(value) => query.push(cli_query_pair("query", value))
    None => ()
  }
  match parse_string_arg(args, "--limit") {
    Some(value) => query.push(cli_query_pair("limit", value))
    None => ()
  }
  match parse_string_arg(args, "--offset") {
    Some(value) => query.push(cli_query_pair("offset", value))
    None => ()
  }
  cli_path_with_query("/search_skills_sh", query)
}

///|
fn skill_repo_add_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--owner") {
    Some(value) => query.push(cli_query_pair("owner", value))
    None => ()
  }
  match parse_string_arg(args, "--name") {
    Some(value) => query.push(cli_query_pair("name", value))
    None =>
      match parse_string_arg(args, "--repo") {
        Some(value) => query.push(cli_query_pair("name", value))
        None => ()
      }
  }
  match parse_string_arg(args, "--branch") {
    Some(value) => query.push(cli_query_pair("branch", value))
    None => ()
  }
  match parse_string_arg(args, "--enabled") {
    Some(value) => query.push(cli_query_pair("enabled", value))
    None => ()
  }
  cli_path_with_query("/add_skill_repo", query)
}

///|
fn skill_repo_remove_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--owner") {
    Some(value) => query.push(cli_query_pair("owner", value))
    None => ()
  }
  match parse_string_arg(args, "--name") {
    Some(value) => query.push(cli_query_pair("name", value))
    None =>
      match parse_string_arg(args, "--repo") {
        Some(value) => query.push(cli_query_pair("repo", value))
        None => ()
      }
  }
  cli_path_with_query("/remove_skill_repo", query)
}

///|
fn skill_zip_install_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--file-path", "--filePath") {
    Some(value) => query.push(cli_query_pair("filePath", value))
    None =>
      match parse_string_arg(args, "--path") {
        Some(value) => query.push(cli_query_pair("filePath", value))
        None => ()
      }
  }
  match parse_string_arg_any(args, "--current-app", "--currentApp") {
    Some(app) => query.push(cli_query_pair("currentApp", app))
    None =>
      match parse_string_arg_any(args, "--app", "--appType") {
        Some(app) => query.push(cli_query_pair("currentApp", app))
        None =>
          match parse_string_arg(args, "--app-type") {
            Some(app) => query.push(cli_query_pair("currentApp", app))
            None => ()
          }
      }
  }
  cli_path_with_query("/install_skills_from_zip", query)
}

///|
fn config_snippet_path(
  args : Array[String],
  base_path : String,
  app_required~ : Bool,
) -> String? {
  guard parse_string_arg(args, "--snippet") is Some(snippet) else {
    return None
  }
  let query : Array[String] = [cli_query_pair("snippet", snippet)]
  if app_required {
    query.push(cli_query_pair("appType", config_app_arg(args)))
  }
  Some("\{base_path}?\{query.join("&")}")
}

///|
fn extract_common_config_snippet_path(args : Array[String]) -> String {
  let query : Array[String] = [cli_query_pair("appType", config_app_arg(args))]
  match parse_string_arg_any(args, "--settings-config", "--settingsConfig") {
    Some(settings) => query.push(cli_query_pair("settingsConfig", settings))
    None => ()
  }
  "/extract_common_config_snippet?\{query.join("&")}"
}

///|
fn restore_env_backup_path(args : Array[String]) -> String? {
  guard parse_string_arg_any(args, "--backup-path", "--backupPath")
    is Some(path) else {
    return None
  }
  Some("/restore_env_backup?\{cli_query_pair("backupPath", path)}")
}

///|
fn mcp_app_path(args : Array[String], base_path : String) -> String {
  "\{base_path}?\{cli_query_pair("app", config_app_arg(args))}"
}

///|
fn mcp_server_id_arg(args : Array[String]) -> String? {
  match parse_string_arg(args, "--id") {
    Some(id) => Some(id)
    None => parse_string_arg_any(args, "--server-id", "--serverId")
  }
}

///|
fn mcp_id_path(args : Array[String], base_path : String) -> String? {
  guard mcp_server_id_arg(args) is Some(id) else { return None }
  Some("\{base_path}?\{cli_query_pair("id", id)}")
}

///|
fn mcp_validate_command_path(args : Array[String]) -> String {
  match parse_string_arg_any(args, "--command", "--cmd") {
    Some(command) =>
      "/validate_mcp_command?\{cli_query_pair("command", command)}"
    None => "/validate_mcp_command"
  }
}

///|
fn mcp_server_json_from_args(args : Array[String], id : String) -> String {
  let name = parse_string_arg(args, "--name").unwrap_or(id)
  let spec : Map[String, Json] = {}
  match parse_string_arg_any(args, "--command", "--cmd") {
    Some(command) => spec["command"] = Json::string(command)
    None => ()
  }
  match parse_string_arg(args, "--args") {
    Some(value) => spec["args"] = Json::string(value)
    None => ()
  }
  match parse_string_arg(args, "--env") {
    Some(value) => spec["env"] = Json::string(value)
    None => ()
  }
  {
    "id": Json::string(id),
    "name": Json::string(name),
    "server": Json::object(spec),
  }
  .to_json()
  .stringify()
}

///|
fn mcp_upsert_path(args : Array[String], base_path : String) -> String? {
  let query : Array[String] = []
  match parse_string_arg(args, "--server") {
    Some(server) => query.push(cli_query_pair("server", server))
    None =>
      match mcp_server_id_arg(args) {
        Some(id) =>
          query.push(
            cli_query_pair("server", mcp_server_json_from_args(args, id)),
          )
        None => return None
      }
  }
  query.push(cli_query_pair("app", config_app_arg(args)))
  match parse_string_arg_any(args, "--sync-other-side", "--syncOtherSide") {
    Some(value) => query.push(cli_query_pair("syncOtherSide", value))
    None => ()
  }
  Some("\{base_path}?\{query.join("&")}")
}

///|
fn mcp_enabled_path(args : Array[String], base_path : String) -> String? {
  guard mcp_server_id_arg(args) is Some(id) else { return None }
  guard parse_string_arg(args, "--enabled") is Some(enabled) else {
    return None
  }
  Some(
    "\{base_path}?\{cli_query_pair("id", id)}&\{cli_query_pair("app", config_app_arg(args))}&\{cli_query_pair("enabled", enabled)}",
  )
}

///|
fn prompt_app_path(args : Array[String], base_path : String) -> String {
  "\{base_path}?\{cli_query_pair("app", config_app_arg(args))}"
}

///|
fn prompt_id_path(args : Array[String], base_path : String) -> String? {
  guard parse_string_arg_any(args, "--id", "--promptId") is Some(id) else {
    return None
  }
  Some(
    "\{base_path}?\{cli_query_pair("app", config_app_arg(args))}&\{cli_query_pair("id", id)}",
  )
}

///|
fn prompt_upsert_path(args : Array[String]) -> String? {
  let query : Array[String] = [cli_query_pair("app", config_app_arg(args))]
  match parse_string_arg(args, "--prompt") {
    Some(prompt) => query.push(cli_query_pair("prompt", prompt))
    None => {
      guard parse_string_arg_any(args, "--id", "--promptId") is Some(id) else {
        return None
      }
      query.push(cli_query_pair("id", id))
      match parse_string_arg(args, "--name") {
        Some(name) => query.push(cli_query_pair("name", name))
        None => ()
      }
      match parse_string_arg(args, "--content") {
        Some(content) => query.push(cli_query_pair("content", content))
        None => ()
      }
      match parse_string_arg(args, "--description") {
        Some(description) =>
          query.push(cli_query_pair("description", description))
        None => ()
      }
      match parse_string_arg(args, "--enabled") {
        Some(enabled) => query.push(cli_query_pair("enabled", enabled))
        None => ()
      }
    }
  }
  Some("/upsert_prompt?\{query.join("&")}")
}

///|
fn stream_check_all_path(args : Array[String]) -> String {
  let app_type = match parse_string_arg_any(args, "--app-type", "--appType") {
    Some(value) => value
    None => parse_string_arg(args, "--app").unwrap_or("claude")
  }
  let query : Array[String] = [cli_query_pair("appType", app_type)]
  match
    parse_string_arg_any(args, "--proxy-targets-only", "--proxyTargetsOnly") {
    Some(value) => query.push(cli_query_pair("proxyTargetsOnly", value))
    None => ()
  }
  "/stream_check_all_providers?\{query.join("&")}"
}

///|
fn stream_check_config_update_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--timeout-secs", "--timeoutSecs") {
    Some(value) => query.push(cli_query_pair("timeoutSecs", value))
    None => ()
  }
  match parse_string_arg_any(args, "--max-retries", "--maxRetries") {
    Some(value) => query.push(cli_query_pair("maxRetries", value))
    None => ()
  }
  match
    parse_string_arg_any(
      args, "--degraded-threshold-ms", "--degradedThresholdMs",
    ) {
    Some(value) => query.push(cli_query_pair("degradedThresholdMs", value))
    None => ()
  }
  match parse_string_arg_any(args, "--claude-model", "--claudeModel") {
    Some(value) => query.push(cli_query_pair("claudeModel", value))
    None => ()
  }
  match parse_string_arg_any(args, "--codex-model", "--codexModel") {
    Some(value) => query.push(cli_query_pair("codexModel", value))
    None => ()
  }
  match parse_string_arg_any(args, "--gemini-model", "--geminiModel") {
    Some(value) => query.push(cli_query_pair("geminiModel", value))
    None => ()
  }
  match parse_string_arg_any(args, "--test-prompt", "--testPrompt") {
    Some(value) => query.push(cli_query_pair("testPrompt", value))
    None => ()
  }
  if query.is_empty() {
    "/save_stream_check_config"
  } else {
    "/save_stream_check_config?\{query.join("&")}"
  }
}

///|
async fn save_stream_check_config(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  let path = stream_check_config_update_path(args)
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.post(path, "{}")
    let body = client.read_all().text()
    if response.code == 200 {
      println(body)
    } else {
      logger.error(
        "Stream check config update failed: \{response.code} \{body}",
      )
    }
  } catch {
    err => logger.error("Stream check config update failed: \{err}")
  }
}

///|
async fn check_balance(args : Array[String]) -> Unit {
  guard balance_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required balance args: --base-url --api-key")
    return
  }
  check_usage_endpoint(args, path)
}

///|
async fn check_subscription_quota(args : Array[String]) -> Unit {
  guard subscription_quota_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required subscription quota arg: --tool")
    return
  }
  check_usage_endpoint(args, path)
}

///|
async fn check_coding_plan_quota(args : Array[String]) -> Unit {
  guard coding_plan_quota_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error(
      "Missing required coding plan quota args: --base-url --api-key",
    )
    return
  }
  check_usage_endpoint(args, path)
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
fn balance_path(args : Array[String]) -> String? {
  guard parse_string_arg_any(args, "--base-url", "--baseUrl") is Some(base_url) else {
    return None
  }
  guard parse_string_arg_any(args, "--api-key", "--apiKey") is Some(api_key) else {
    return None
  }
  Some(
    "/get_balance?\{cli_query_pair("baseUrl", base_url)}&\{cli_query_pair("apiKey", api_key)}",
  )
}

///|
fn subscription_quota_path(args : Array[String]) -> String? {
  let tool = match parse_string_arg(args, "--tool") {
    Some(value) => Some(value)
    None =>
      match parse_string_arg_any(args, "--app", "--app-type") {
        Some(value) => Some(value)
        None => parse_string_arg(args, "--appType")
      }
  }
  guard tool is Some(tool) else { return None }
  Some("/get_subscription_quota?\{cli_query_pair("tool", tool)}")
}

///|
fn coding_plan_quota_path(args : Array[String]) -> String? {
  guard parse_string_arg_any(args, "--base-url", "--baseUrl") is Some(base_url) else {
    return None
  }
  guard parse_string_arg_any(args, "--api-key", "--apiKey") is Some(api_key) else {
    return None
  }
  Some(
    "/get_coding_plan_quota?\{cli_query_pair("baseUrl", base_url)}&\{cli_query_pair("apiKey", api_key)}",
  )
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
async fn check_json_post_endpoint(
  args : Array[String],
  path : String,
  label : String,
) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.post(path, "{}")
    if response.code == 200 {
      let body = client.read_all().text()
      println(body)
    } else {
      logger.error("\{label} update failed: \{response.code}")
    }
  } catch {
    err => logger.error("\{label} update failed: \{err}")
  }
}

///|
async fn post_json_body_endpoint(
  args : Array[String],
  path : String,
  body : String,
  label : String,
) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={
      "Content-Type": "application/json",
    })
    defer client.close()
    let response = client.post(path, body)
    if response.code == 200 {
      let body = client.read_all().text()
      println(body)
    } else {
      logger.error("\{label} update failed: \{response.code}")
    }
  } catch {
    err => logger.error("\{label} update failed: \{err}")
  }
}

///|
async fn check_json_delete_endpoint(
  args : Array[String],
  path : String,
  label : String,
) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    client.request(@http.RequestMethod::Delete, path)
    let response = client.end_request()
    let body = client.read_all().text()
    if response.code == 200 {
      println(body)
    } else {
      logger.error("\{label} delete failed: \{response.code} \{body}")
    }
  } catch {
    err => logger.error("\{label} delete failed: \{err}")
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
