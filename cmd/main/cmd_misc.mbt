///|
async fn main {
  let args = @os.args()
  start(args)
}

///|
fn print_help() -> Unit {
  println("MoonGate - local AI traffic gateway and usage statistics")
  println("")
  println("Usage: moongate <command> [options]")
  println("")
  println("Commands:")
  println("  start       Start the gateway server")
  println("  hosts install    Install hosts reroute (requires sudo)")
  println("  hosts uninstall  Remove hosts reroute (requires sudo)")
  println(
    "  claude-desktop install    Configure Claude Desktop gateway profile",
  )
  println("  claude-desktop uninstall  Remove Claude Desktop gateway profile")
  println("  claude-desktop status     Show Claude Desktop profile status")
  println(
    "  codex install             Configure Codex config.toml for MoonGate",
  )
  println("  codex uninstall           Remove MoonGate Codex config block")
  println("  codex status              Show Codex config.toml MoonGate status")
  println("  models fetch              Fetch provider model catalogs")
  println("  models candidates         Print /v1/models candidate URLs")
  println("  auth status               Show OAuth account status")
  println("  auth login                Start OAuth device login")
  println("  auth poll                 Poll OAuth device login")
  println("  stream-check provider     Check one provider stream path")
  println("  stream-check all          Check all provider stream paths")
  println("  stream-check config       Show stream check configuration")
  println("  stream-check config set   Update stream check configuration")
  println("  runtime tray-menu update  Refresh desktop tray menu state")
  println("  suite manifest            Print Moon suite service manifest")
  println("  suite lepusa              Print Lepusa desktop manifest")
  println("  suite lepusa-rabbita      Print Lepusa Rabbita preview manifest")
  println("  suite status              Print Moon suite status contract")
  println(
    "  suite constitution        Audit product boundaries and authority ceilings",
  )
  println(
    "  suite constitution-negative  Print fail-closed constitutional probes",
  )
  println("  suite drift               Report MoonSuite legacy path drift")
  println("  suite write-status        Write .moonsuite/suite-status.json")
  println(
    "  suite migrate-legacy-state  Copy legacy MoonGate state without overwrites",
  )
  println("  suite moonclaw-providers  Print MoonClaw providers.json")
  println(
    "  suite write-moonclaw-providers  Write \{@moonsuite.product_display_artifact("moonclaw", "providers.json")}",
  )
  println("  status      Check reroute and gateway status")
  println("  stats       Show gateway traffic statistics")
  println("  metrics     Show Prometheus gateway metrics")
  println("  proxy status           Show proxy server status")
  println("  proxy <command>        Manage routing, failover, and proxy state")
  println("  provider <command>     Manage provider configuration")
  println("  usage <command>        Inspect traffic, tokens, cost, and quotas")
  println("  stream-check <command> Validate provider stream behavior")
  println("  mcp list/upsert/delete/toggle  Manage MCP servers")
  println("  mcp config/upsert-config       Manage app MCP config view")
  println("  prompt list/upsert/delete      Manage prompt records")
  println("  proxy start            Enable proxy routing and print server info")
  println(
    "  proxy stop             Disable proxy routing when no takeover is active",
  )
  println(
    "  proxy stop-with-restore  Disable proxy routing and clear takeover state",
  )
  println("  proxy global-config    Show global proxy config")
  println("  proxy global-config set  Update global proxy config")
  println("  proxy app-config       Show app proxy config")
  println("  proxy app-config set   Update app proxy config")
  println("  proxy default-cost-multiplier  Show app cost multiplier")
  println("  proxy default-cost-multiplier set  Set app cost multiplier")
  println("  proxy pricing-model-source     Show app pricing mode")
  println("  proxy pricing-model-source set     Set app pricing mode")
  println("  proxy provider-health          Show provider health")
  println("  proxy circuit-breaker-config   Show circuit config")
  println("  proxy circuit-breaker-config set  Update circuit config")
  println("  proxy circuit-breaker-stats    Show circuit stats")
  println("  proxy reset-circuit-breaker    Reset provider circuit breaker")
  println("  proxy failover-queue           Show failover queue")
  println("  proxy failover-queue add       Add provider to failover queue")
  println(
    "  proxy failover-queue remove    Remove provider from failover queue",
  )
  println("  proxy available-failover-providers  Show providers outside queue")
  println("  proxy auto-failover-enabled    Show app auto-failover boolean")
  println("  proxy auto-failover-enabled set  Set app auto-failover boolean")
  println("  proxy takeover-status  Show app takeover status")
  println("  proxy takeover-status set  Set app takeover state")
  println("  proxy is-live-takeover-active  Show takeover active boolean")
  println("  proxy switch-provider  Hot-switch current app provider")
  println("  proxy running          Show proxy running boolean")
  println("  provider list          List providers")
  println("  provider current       Show current provider")
  println("  provider add           Add provider")
  println("  provider update        Update provider")
  println("  provider delete        Delete provider")
  println("  provider remove-live   Remove provider from live config")
  println("  provider sync-live     Sync current providers to live config")
  println("  provider switch        Switch provider")
  println("  provider live-settings Read live provider settings")
  println("  provider test-endpoints Test provider endpoints")
  println("  provider sort-order set Update provider sort order")
  println("  provider endpoints list    List custom endpoints")
  println("  provider endpoints add     Add custom endpoint")
  println("  provider endpoints remove  Remove custom endpoint")
  println("  provider endpoints touch   Update endpoint last-used time")
  println("  provider presets list      Show provider presets")
  println("  settings get/save          Read or write settings")
  println("  settings app-config-dir    Show or set app_config_dir override")
  println("  settings auto-launch       Show or set auto-launch state")
  println("  settings rectifier         Show or set rectifier config")
  println("  settings optimizer         Show or set optimizer config")
  println("  settings copilot-optimizer Show or set Copilot optimizer config")
  println("  settings log               Show or set log config")
  println(
    "  plugin claude status/config/apply/applied  Manage Claude plugin state",
  )
  println(
    "  plugin claude onboarding-skip/onboarding-clear  Toggle onboarding skip",
  )
  println("  workspace read/write/open  Manage OpenClaw workspace files")
  println(
    "  workspace memory list/read/write/search/delete  Manage daily memory",
  )
  println("  usage logs  Show recent proxy request logs")
  println("  usage summary    Show usage summary")
  println("  usage apps       Show usage summary by app")
  println("  usage trends     Show hourly/daily usage trends")
  println("  usage limits     Show provider limit status")
  println("  usage sync       Sync Claude/Codex/Gemini/OpenCode session logs")
  println("  sessions list      List known sessions")
  println("  sessions messages  Read session messages")
  println("  sessions delete    Delete one session")
  println("  sessions delete-many  Delete multiple sessions")
  println("  usage providers  Show provider statistics")
  println("  usage models     Show model statistics")
  println("  usage sources    Show data source breakdown")
  println("  usage provider-usage  Query provider account usage")
  println("  usage balance    Query provider balance")
  println("  usage quota      Query subscription quota")
  println("  usage coding-plan Query coding plan quota")
  println("  usage codex-oauth-quota Query Codex OAuth quota")
  println("  usage codex-oauth-models Query Codex OAuth models")
  println("  usage test-script     Test usage script parsing")
  println("  usage pricing    Show editable model pricing")
  println("  usage pricing set       Upsert model pricing")
  println("  usage pricing delete    Delete model pricing")
  println("  usage detail     Show one request detail by id")
  println("  health      Check gateway health")
  println("  metrics     Show Prometheus gateway metrics")
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
  println("  --provider-id <id> Provider id for provider CRUD commands")
  println("  --name <name>      Provider display name for provider add/update")
  println("  --base-url <url>   Provider API base URL for provider add/update")
  println("  --api-key <key>    Provider API key for provider add/update")
  println("  --provider-type <kind>  Provider type for provider add/update")
  println("  --endpoint-url <url> Provider custom endpoint URL")
  println("  --app-type <app>         App id for usage commands")
  println("  --server <json>     MCP server JSON for MCP upsert commands")
  println("  --command <cmd>     MCP command name for validation/upsert")
  println("  --content <text>    Prompt content for prompt upsert commands")
  println("  --conflicts <json>  JSON conflict array for env delete")
  println("  --imports <json>    JSON import array for skill import")
  println("  --items <json>      JSON item array for bulk commands")
  println("  --target <loc>      Skill storage target: moongate or unified")
  println("  --script-code <json> JSON UsageResult for usage script tests")
  println("  --value <value>    Value for proxy scalar setter commands")
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
  println("  sudo moongate hosts install    # Install hosts reroute")
  println("  moongate start                 # Start gateway on 127.0.0.1:15721")
  println("  moongate start --port 80       # Start gateway on port 80")
  println("  moongate claude-desktop install --port 15721")
  println("  moongate codex install --port 15721 --model gpt-5")
  println(
    "  moongate models fetch --base-url https://api.example.com --api-key sk-...",
  )
  println("  moongate suite write-status --port 15721")
  println("  moongate suite lepusa --port 15721")
  println("  moongate suite lepusa-rabbita --port 15721")
  println("  claude                         # Use Claude CLI through moongate")
  println("  moongate proxy status          # Show proxy status")
  println("  moongate proxy start")
  println(
    "  moongate proxy switch-provider --app-type codex --provider-id codex-oauth",
  )
  println("  moongate provider list --app-type codex")
  println(
    "  moongate provider add --app-type codex --provider-id custom --name Custom --base-url https://api.example.com/v1 --api-key sk-...",
  )
  println("  moongate provider switch --app-type codex --provider-id custom")
  println(
    "  moongate provider endpoints add --app-type codex --provider-id custom --endpoint-url https://api.backup.example.com/v1",
  )
  println(
    "  moongate stream-check provider --app-type codex --provider-id codex-oauth",
  )
  println(
    "  moongate stream-check all --app-type codex --proxy-targets-only true",
  )
  println(
    "  moongate stream-check config set --codex-model gpt-5.5@low --timeout-secs 45",
  )
  println(
    "  moongate mcp upsert --id filesystem --command npx --name Filesystem",
  )
  println(
    "  moongate mcp toggle --id filesystem --app-type codex --enabled true",
  )
  println(
    "  moongate prompt upsert --app-type codex --id review --name Review --content 'Review this change'",
  )
  println("  moongate proxy app-config --app-type codex")
  println(
    "  moongate proxy global-config set --proxy-enabled true --listen-address 127.0.0.1 --listen-port 15721",
  )
  println(
    "  moongate proxy app-config set --app-type codex --enabled true --max-retries 3",
  )
  println(
    "  moongate proxy default-cost-multiplier set --app-type codex --value 1.25",
  )
  println(
    "  moongate proxy pricing-model-source set --app-type codex --value request",
  )
  println(
    "  moongate proxy takeover-status set --app-type codex --enabled true",
  )
  println(
    "  moongate proxy provider-health --app-type codex --provider-id codex-oauth",
  )
  println(
    "  moongate proxy circuit-breaker-config set --failure-threshold 4 --success-threshold 2 --timeout-seconds 60 --error-rate-threshold 0.6 --min-requests 10",
  )
  println("  moongate proxy failover-queue --app-type codex")
  println(
    "  moongate proxy failover-queue add --app-type codex --provider-id codex-oauth",
  )
  println(
    "  moongate proxy auto-failover-enabled set --app-type codex --enabled true",
  )
  println("  moongate stats                 # Show traffic counters")
  println("  moongate usage logs            # Show recent request logs")
  println("  moongate usage summary         # Show aggregate token/cost usage")
  println("  moongate usage trends --start-date 0 --end-date 86400")
  println("  moongate usage limits --provider-id codex-oauth --app-type codex")
  println(
    "  moongate usage sync --projects-dir ~/.claude/projects --codex-dir ~/.codex --gemini-dir ~/.gemini --opencode-db-path ~/.local/share/opencode/opencode.db",
  )
  println(
    "  moongate usage pricing set --model-id gpt-x --display-name GPT-X --input-cost 1 --output-cost 2 --cache-read-cost 0.1 --cache-creation-cost 0",
  )
  println("  moongate usage pricing delete --model-id gpt-x")
  println("  moongate usage detail --request-id req_x")
  println("  moongate hosts uninstall       # Remove hosts reroute")
}

///|
async fn start_gateway(args : Array[String]) -> Unit {
  let logger = @pino.logger("moongate", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or(@suite.default_host())
  let port = parse_int_arg(args, "--port", default=@suite.default_port())
  let model = parse_string_arg(args, "--model").unwrap_or(
    @suite.default_model(),
  )
  logger.info("Starting MoonGate Gateway on \{host}:\{port}")
  logger.info("Using Codex model: \{model}")
  let gateway = @moongate.Gateway::new(port~, host~, model~)
  logger.info("Gateway started on \{gateway.host()}:\{gateway.port()}")
  gateway.start()
}

///|
async fn import_default_config(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    provider_app_path(args, "/proxy/import-default-config"),
    "Provider",
  )
}

///|
async fn save_settings(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--settings") is Some(settings) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required --settings JSON")
    return
  }
  post_json_body_endpoint(args, "/settings", settings, "Settings")
}

///|
async fn delete_sessions(args : Array[String]) -> Unit {
  guard delete_sessions_body(args) is Some(body) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required --items JSON")
    return
  }
  post_json_body_endpoint(args, "/sessions/delete-many", body, "Session")
}

///|
fn delete_sessions_body(args : Array[String]) -> String? {
  parse_string_arg(args, "--items")
}

///|
async fn import_skills_from_apps(args : Array[String]) -> Unit {
  guard import_skills_from_apps_body(args) is Some(body) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required --imports JSON")
    return
  }
  post_json_body_endpoint(args, "/skills/import-apps", body, "Skills")
}

///|
fn import_skills_from_apps_body(args : Array[String]) -> String? {
  parse_string_arg(args, "--imports")
}

///|
async fn migrate_skill_storage(args : Array[String]) -> Unit {
  guard migrate_skill_storage_path(args) is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required --target")
    return
  }
  check_json_post_endpoint(args, path, "Skills")
}

///|
fn migrate_skill_storage_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--target") is Some(target) else { return None }
  Some(
    cli_path_with_query("/skills/migrate-storage", [
      cli_query_pair("target", target),
    ]),
  )
}

///|
async fn delete_env_vars(args : Array[String]) -> Unit {
  guard delete_env_vars_body(args) is Some(body) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required --conflicts JSON")
    return
  }
  post_json_body_endpoint(args, "/config/env/delete", body, "Env")
}

///|
fn delete_env_vars_body(args : Array[String]) -> String? {
  parse_string_arg(args, "--conflicts")
}

///|
async fn set_moon_json_config(
  args : Array[String],
  base_path : String,
  flag : String,
  label : String,
) -> Unit {
  guard moon_json_config_path(args, base_path, flag) is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required \{flag} JSON or config field flags")
    return
  }
  check_json_post_endpoint(args, path, label)
}

///|
async fn set_app_config_dir_override(args : Array[String]) -> Unit {
  guard app_config_dir_override_path(args) is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required --path or --clear")
    return
  }
  check_json_post_endpoint(args, path, "Settings")
}

///|
async fn set_auto_launch(args : Array[String]) -> Unit {
  guard set_auto_launch_path(args) is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
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
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required --snippet")
    return
  }
  check_json_post_endpoint(args, path, "Config")
}

///|
async fn restore_env_backup(args : Array[String]) -> Unit {
  guard restore_env_backup_path(args) is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required --backup-path")
    return
  }
  check_json_post_endpoint(args, path, "Env")
}

///|
async fn upsert_mcp_server(args : Array[String], base_path : String) -> Unit {
  guard mcp_upsert_path(args, base_path) is Some(path) &&
    mcp_upsert_body(args) is Some(body) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required MCP server args: --id or --server")
    return
  }
  post_json_body_endpoint(args, path, body, "MCP")
}

///|
async fn delete_mcp_server(args : Array[String], base_path : String) -> Unit {
  guard mcp_id_path(args, base_path) is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_delete_endpoint(args, path, "MCP")
}

///|
async fn set_mcp_enabled(args : Array[String]) -> Unit {
  guard mcp_enabled_path(args, "/mcp/enabled") is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required MCP args: --id --enabled")
    return
  }
  check_json_post_endpoint(args, path, "MCP")
}

///|
async fn toggle_mcp_app(args : Array[String]) -> Unit {
  guard mcp_enabled_path(args, "/mcp/apps/toggle") is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required MCP args: --id --enabled")
    return
  }
  check_json_post_endpoint(args, path, "MCP")
}

///|
async fn upsert_prompt(args : Array[String]) -> Unit {
  guard prompt_upsert_path(args) is Some(path) &&
    prompt_upsert_body(args) is Some(body) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required prompt args: --id")
    return
  }
  post_json_body_endpoint(args, path, body, "Prompt")
}

///|
async fn delete_prompt(args : Array[String]) -> Unit {
  guard prompt_id_path(args, "/prompts") is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_delete_endpoint(args, path, "Prompt")
}

///|
async fn enable_prompt(args : Array[String]) -> Unit {
  guard prompt_id_path(args, "/prompts/enable") is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_post_endpoint(args, path, "Prompt")
}

///|
async fn test_api_endpoints(args : Array[String]) -> Unit {
  guard provider_test_endpoints_path(args) is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required --url or --urls")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
fn config_app_arg(args : Array[String]) -> String {
  parse_string_arg(args, "--app-type").unwrap_or("claude")
}

///|
fn config_app_path(args : Array[String], base_path : String) -> String {
  "\{base_path}?\{cli_query_pair("appType", config_app_arg(args))}"
}

///|
fn app_config_dir_override_path(args : Array[String]) -> String? {
  match parse_string_arg(args, "--path") {
    Some(path) =>
      Some("/settings/app-config-dir?\{cli_query_pair("path", path)}")
    None =>
      match parse_string_arg(args, "--clear") {
        Some(value) =>
          if value == "true" || value == "1" || value == "yes" {
            Some("/settings/app-config-dir?path=")
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
      Some("/settings/auto-launch?\{cli_query_pair("enabled", enabled)}")
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
  for pair in moon_json_config_flag_pairs() {
    let (flag_name, query_key) = pair
    match parse_string_arg(args, "--\{flag_name}") {
      Some(value) => query.push(cli_query_pair(query_key, value))
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
fn moon_json_config_flag_pairs() -> Array[(String, String)] {
  [
    ("enabled", "enabled"),
    ("request-thinking-signature", "requestThinkingSignature"),
    ("request-thinking-budget", "requestThinkingBudget"),
    ("request-media-fallback", "requestMediaFallback"),
    ("request-media-heuristic", "requestMediaHeuristic"),
    ("thinking-optimizer", "thinkingOptimizer"),
    ("cache-injection", "cacheInjection"),
    ("cache-ttl", "cacheTtl"),
    ("request-classification", "requestClassification"),
    ("tool-result-merging", "toolResultMerging"),
    ("compact-detection", "compactDetection"),
    ("deterministic-request-id", "deterministicRequestId"),
    ("subagent-detection", "subagentDetection"),
    ("warmup-downgrade", "warmupDowngrade"),
    ("warmup-model", "warmupModel"),
    ("strip-thinking", "stripThinking"),
    ("level", "level"),
  ]
}

///|
fn apply_claude_plugin_config_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--official") {
    Some(official) =>
      "/plugin/claude/config?\{cli_query_pair("official", official)}"
    None => "/plugin/claude/config"
  }
}

///|
fn pick_directory_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--default-path") {
    Some(path) => query.push(cli_query_pair("defaultPath", path))
    None => ()
  }
  cli_path_with_query("/files/directories/pick", query)
}

///|
fn open_external_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--url") {
    Some(url) => "/runtime/open-external?\{cli_query_pair("url", url)}"
    None => "/runtime/open-external"
  }
}

///|
fn copy_text_to_clipboard_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--text") {
    Some(text) => "/runtime/clipboard/text?\{cli_query_pair("text", text)}"
    None => "/runtime/clipboard/text"
  }
}

///|
fn tool_versions_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--tools") {
    Some(tools) => "/tools/versions?\{cli_query_pair("tools", tools)}"
    None => "/tools/versions"
  }
}

///|
async fn run_tool_lifecycle_action(args : Array[String]) -> Unit {
  guard tool_lifecycle_path(args) is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
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
  Some(cli_path_with_query("/tools/lifecycle-action", query))
}

///|
fn tool_installations_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--tools") {
    Some(tools) => "/tools/probe?\{cli_query_pair("tools", tools)}"
    None => "/tools/probe"
  }
}

///|
fn window_theme_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--theme") {
    Some(theme) => "/runtime/window-theme?\{cli_query_pair("theme", theme)}"
    None => "/runtime/window-theme"
  }
}

///|
fn db_backup_rename_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--old-filename") {
    Some(filename) => query.push(cli_query_pair("oldFilename", filename))
    None => ()
  }
  match parse_string_arg(args, "--new-name") {
    Some(name) => query.push(cli_query_pair("newName", name))
    None => ()
  }
  cli_path_with_query("/backups/db/rename", query)
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
    Some(request) if !request.trim().has_prefix("{") =>
      query.push(cli_query_pair("url", request))
    None => ()
    _ => ()
  }
  cli_path_with_query(base_path, query)
}

///|
async fn post_deeplink_request_endpoint(
  args : Array[String],
  base_path : String,
  label : String,
) -> Unit {
  match parse_string_arg(args, "--request") {
    Some(request) if request.trim().has_prefix("{") =>
      post_json_body_endpoint(args, base_path, request, label)
    _ =>
      check_json_post_endpoint(
        args,
        deeplink_request_path(args, base_path),
        label,
      )
  }
}

///|
fn sync_settings_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--preserve-empty-password") {
    Some(value) => query.push(cli_query_pair("preserveEmptyPassword", value))
    None => ()
  }
  match parse_string_arg(args, "--password-touched") {
    Some(value) => query.push(cli_query_pair("passwordTouched", value))
    None => ()
  }
  cli_path_with_query(base_path, query)
}

///|
async fn post_sync_settings_endpoint(
  args : Array[String],
  base_path : String,
  label : String,
) -> Unit {
  guard parse_string_arg(args, "--settings") is Some(settings) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required --settings JSON")
    return
  }
  post_json_body_endpoint(
    args,
    sync_settings_path(args, base_path),
    settings,
    label,
  )
}

///|
fn session_messages_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--provider-id") {
    Some(value) => query.push(cli_query_pair("providerId", value))
    None => ()
  }
  match parse_string_arg(args, "--source-path") {
    Some(value) => query.push(cli_query_pair("sourcePath", value))
    None => ()
  }
  cli_path_with_query("/sessions/messages", query)
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
  match parse_string_arg(args, "--custom-config") {
    Some(value) => query.push(cli_query_pair("customConfig", value))
    None => ()
  }
  cli_path_with_query("/sessions/terminal", query)
}

///|
fn delete_session_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--provider-id") {
    Some(value) => query.push(cli_query_pair("providerId", value))
    None => ()
  }
  match parse_string_arg(args, "--session-id") {
    Some(value) => query.push(cli_query_pair("sessionId", value))
    None => ()
  }
  match parse_string_arg(args, "--source-path") {
    Some(value) => query.push(cli_query_pair("sourcePath", value))
    None => ()
  }
  cli_path_with_query("/sessions/delete", query)
}

///|
fn skill_app_arg(args : Array[String]) -> String {
  config_app_arg(args)
}

///|
fn skill_id_arg(args : Array[String]) -> String? {
  parse_string_arg(args, "--id")
}

///|
fn skill_app_path(args : Array[String], base_path : String) -> String {
  cli_path_with_query(base_path, [
    cli_query_pair("appType", skill_app_arg(args)),
  ])
}

///|
fn skill_id_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = []
  match skill_id_arg(args) {
    Some(id) => query.push(cli_query_pair("id", id))
    None => ()
  }
  match parse_string_arg(args, "--app-type") {
    Some(app) => query.push(cli_query_pair("appType", app))
    None => ()
  }
  cli_path_with_query(base_path, query)
}

///|
fn skill_backup_id_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--backup-id") {
    Some(backup_id) => query.push(cli_query_pair("backupId", backup_id))
    None => ()
  }
  cli_path_with_query(base_path, query)
}

///|
fn skill_restore_backup_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--backup-id") {
    Some(backup_id) => query.push(cli_query_pair("backupId", backup_id))
    None => ()
  }
  match parse_string_arg(args, "--current-app") {
    Some(app) => query.push(cli_query_pair("currentApp", app))
    None => ()
  }
  cli_path_with_query("/skills/backups/restore", query)
}

///|
fn skill_install_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--directory") {
    Some(directory) => query.push(cli_query_pair("directory", directory))
    None => ()
  }
  match parse_string_arg(args, "--name") {
    Some(name) => query.push(cli_query_pair("name", name))
    None => ()
  }
  match parse_string_arg(args, "--description") {
    Some(description) => query.push(cli_query_pair("description", description))
    None => ()
  }
  match parse_string_arg(args, "--current-app") {
    Some(app) => query.push(cli_query_pair("currentApp", app))
    None => ()
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
  query.push(cli_query_pair("appType", skill_app_arg(args)))
  match parse_string_arg(args, "--enabled") {
    Some(enabled) => query.push(cli_query_pair("enabled", enabled))
    None => ()
  }
  cli_path_with_query("/skills/toggle-app", query)
}

///|
fn skill_search_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--query") {
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
  cli_path_with_query("/skills/search", query)
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
    None => ()
  }
  match parse_string_arg(args, "--branch") {
    Some(value) => query.push(cli_query_pair("branch", value))
    None => ()
  }
  match parse_string_arg(args, "--enabled") {
    Some(value) => query.push(cli_query_pair("enabled", value))
    None => ()
  }
  cli_path_with_query("/skills/repos", query)
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
    None => ()
  }
  cli_path_with_query("/skills/repos/remove", query)
}

///|
fn skill_zip_install_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--file-path") {
    Some(value) => query.push(cli_query_pair("filePath", value))
    None => ()
  }
  match parse_string_arg(args, "--current-app") {
    Some(app) => query.push(cli_query_pair("currentApp", app))
    None => ()
  }
  cli_path_with_query("/skills/install-zip", query)
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
  match parse_string_arg(args, "--settings-config") {
    Some(settings) => query.push(cli_query_pair("settingsConfig", settings))
    None => ()
  }
  "/config/snippets/extract?\{query.join("&")}"
}

///|
fn restore_env_backup_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--backup-path") is Some(path) else {
    return None
  }
  Some("/config/env/restore?\{cli_query_pair("backupPath", path)}")
}

///|
fn mcp_app_path(args : Array[String], base_path : String) -> String {
  "\{base_path}?\{cli_query_pair("appType", config_app_arg(args))}"
}

///|
fn mcp_server_id_arg(args : Array[String]) -> String? {
  parse_string_arg(args, "--id")
}

///|
fn mcp_id_path(args : Array[String], base_path : String) -> String? {
  guard mcp_server_id_arg(args) is Some(id) else { return None }
  Some("\{base_path}?\{cli_query_pair("id", id)}")
}

///|
fn mcp_validate_command_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--command") {
    Some(command) => "/mcp/validate?\{cli_query_pair("command", command)}"
    None => "/mcp/validate"
  }
}

///|
fn mcp_server_json_from_args(args : Array[String], id : String) -> String {
  let name = parse_string_arg(args, "--name").unwrap_or(id)
  let spec : Map[String, Json] = {}
  match parse_string_arg(args, "--command") {
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
  guard mcp_upsert_body(args) is Some(_) else { return None }
  query.push(cli_query_pair("appType", config_app_arg(args)))
  match parse_string_arg(args, "--sync-other-side") {
    Some(value) => query.push(cli_query_pair("syncOtherSide", value))
    None => ()
  }
  Some("\{base_path}?\{query.join("&")}")
}

///|
fn mcp_upsert_body(args : Array[String]) -> String? {
  match parse_string_arg(args, "--server") {
    Some(server) => Some(server)
    None =>
      match mcp_server_id_arg(args) {
        Some(id) => Some(mcp_server_json_from_args(args, id))
        None => None
      }
  }
}

///|
fn mcp_enabled_path(args : Array[String], base_path : String) -> String? {
  guard mcp_server_id_arg(args) is Some(id) else { return None }
  guard parse_string_arg(args, "--enabled") is Some(enabled) else {
    return None
  }
  Some(
    "\{base_path}?\{cli_query_pair("id", id)}&\{cli_query_pair("appType", config_app_arg(args))}&\{cli_query_pair("enabled", enabled)}",
  )
}

///|
fn prompt_app_path(args : Array[String], base_path : String) -> String {
  "\{base_path}?\{cli_query_pair("appType", config_app_arg(args))}"
}

///|
fn prompt_id_path(args : Array[String], base_path : String) -> String? {
  guard parse_string_arg(args, "--id") is Some(id) else { return None }
  Some(
    "\{base_path}?\{cli_query_pair("appType", config_app_arg(args))}&\{cli_query_pair("id", id)}",
  )
}

///|
fn prompt_upsert_path(args : Array[String]) -> String? {
  guard prompt_upsert_body(args) is Some(_) else { return None }
  Some("/prompts?\{cli_query_pair("appType", config_app_arg(args))}")
}

///|
fn prompt_upsert_body(args : Array[String]) -> String? {
  match parse_string_arg(args, "--prompt") {
    Some(prompt) => Some(prompt)
    None => {
      guard parse_string_arg(args, "--id") is Some(id) else { return None }
      let prompt : Map[String, Json] = { "id": Json::string(id) }
      match parse_string_arg(args, "--name") {
        Some(name) => prompt["name"] = Json::string(name)
        None => ()
      }
      match parse_string_arg(args, "--content") {
        Some(content) => prompt["content"] = Json::string(content)
        None => ()
      }
      match parse_string_arg(args, "--description") {
        Some(description) => prompt["description"] = Json::string(description)
        None => ()
      }
      match parse_string_arg(args, "--enabled") {
        Some(enabled) =>
          prompt["enabled"] = Json::boolean(enabled.trim().to_lower() == "true")
        None => ()
      }
      Some(Json::object(prompt).stringify())
    }
  }
}

///|
fn stream_check_all_path(args : Array[String]) -> String {
  let app_type = parse_string_arg(args, "--app-type").unwrap_or("claude")
  let query : Array[String] = [cli_query_pair("appType", app_type)]
  match parse_string_arg(args, "--proxy-targets-only") {
    Some(value) => query.push(cli_query_pair("proxyTargetsOnly", value))
    None => ()
  }
  "/proxy/stream-check/all?\{query.join("&")}"
}

///|
fn stream_check_config_update_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--timeout-secs") {
    Some(value) => query.push(cli_query_pair("timeoutSecs", value))
    None => ()
  }
  match parse_string_arg(args, "--max-retries") {
    Some(value) => query.push(cli_query_pair("maxRetries", value))
    None => ()
  }
  match parse_string_arg(args, "--degraded-threshold-ms") {
    Some(value) => query.push(cli_query_pair("degradedThresholdMs", value))
    None => ()
  }
  match parse_string_arg(args, "--claude-model") {
    Some(value) => query.push(cli_query_pair("claudeModel", value))
    None => ()
  }
  match parse_string_arg(args, "--codex-model") {
    Some(value) => query.push(cli_query_pair("codexModel", value))
    None => ()
  }
  match parse_string_arg(args, "--gemini-model") {
    Some(value) => query.push(cli_query_pair("geminiModel", value))
    None => ()
  }
  match parse_string_arg(args, "--test-prompt") {
    Some(value) => query.push(cli_query_pair("testPrompt", value))
    None => ()
  }
  if query.is_empty() {
    "/proxy/stream-check/config"
  } else {
    "/proxy/stream-check/config?\{query.join("&")}"
  }
}

///|
async fn save_stream_check_config(args : Array[String]) -> Unit {
  let logger = @pino.logger("moongate", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  let path = stream_check_config_update_path(args)
  try {
    let client = @http.Client::Client(url, headers={})
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
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required balance args: --base-url --api-key")
    return
  }
  check_usage_endpoint(args, path)
}

///|
async fn check_subscription_quota(args : Array[String]) -> Unit {
  guard subscription_quota_path(args) is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
    logger.error("Missing required subscription quota arg: --tool")
    return
  }
  check_usage_endpoint(args, path)
}

///|
async fn check_coding_plan_quota(args : Array[String]) -> Unit {
  guard coding_plan_quota_path(args) is Some(path) else {
    let logger = @pino.logger("moongate", @pino.Transport::console())
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
  guard parse_string_arg(args, "--base-url") is Some(base_url) else {
    return None
  }
  guard parse_string_arg(args, "--api-key") is Some(api_key) else {
    return None
  }
  Some(
    "/usage/balance?\{cli_query_pair("baseUrl", base_url)}&\{cli_query_pair("apiKey", api_key)}",
  )
}

///|
fn subscription_quota_path(args : Array[String]) -> String? {
  let tool = parse_string_arg(args, "--tool")
  guard tool is Some(tool) else { return None }
  Some("/usage/subscription-quota?\{cli_query_pair("tool", tool)}")
}

///|
fn coding_plan_quota_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--base-url") is Some(base_url) else {
    return None
  }
  guard parse_string_arg(args, "--api-key") is Some(api_key) else {
    return None
  }
  Some(
    "/usage/coding-plan-quota?\{cli_query_pair("baseUrl", base_url)}&\{cli_query_pair("apiKey", api_key)}",
  )
}

///|
async fn check_json_endpoint(
  args : Array[String],
  path : String,
  label : String,
) -> Unit {
  print_cli_json_result(label, cli_moongate_client(args).get_json(path))
}

///|
async fn check_json_post_endpoint(
  args : Array[String],
  path : String,
  label : String,
) -> Unit {
  print_cli_json_result(label, cli_moongate_client(args).post_json(path, {}))
}

///|
async fn post_json_body_endpoint(
  args : Array[String],
  path : String,
  body : String,
  label : String,
) -> Unit {
  let request = @json.parse(body) catch {
    err => {
      let logger = @pino.logger("moongate", @pino.Transport::console())
      logger.error("\{label} update failed: invalid request JSON: \{err}")
      @os.exit(1)
    }
  }
  print_cli_json_result(
    label,
    cli_moongate_client(args).post_json(path, request),
  )
}

///|
async fn check_json_delete_endpoint(
  args : Array[String],
  path : String,
  label : String,
) -> Unit {
  print_cli_json_result(label, cli_moongate_client(args).delete_json(path))
}

///|
async fn install_reroute(args : Array[String]) -> Unit {
  let logger = @pino.logger("moongate", @pino.Transport::console())
  let port = parse_int_arg(args, "--port", default=@suite.default_port())

  logger.info("Installing hosts reroute for port \{port}...")
  let result = @hosts.install_and_flush(port)
  match result {
    Ok(_) => {
      logger.info("Hosts reroute installed successfully!")
      logger.info("Now you can use: moongate start --port \{port}")
      logger.info("Then Anthropic API requests will route through moongate.")
    }
    Err(e) => logger.error("Failed to install: \{e}")
  }
}

///|
async fn uninstall_reroute() -> Unit {
  let logger = @pino.logger("moongate", @pino.Transport::console())

  logger.info("Removing hosts reroute...")
  let result = @hosts.uninstall_and_flush()
  match result {
    Ok(_) => logger.info("Hosts reroute removed successfully!")
    Err(e) => logger.error("Failed to uninstall: \{e}")
  }
}

///|
async fn install_claude_desktop(args : Array[String]) -> Unit {
  let logger = @pino.logger("moongate", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or(@suite.default_host())
  let port = parse_int_arg(args, "--port", default=@suite.default_port())
  let token = parse_string_arg(args, "--token")
  logger.info("Installing Claude Desktop gateway profile...")
  let result = @claude_desktop.install_proxy_profile(host, port, token~)
  match result {
    Ok(installed) => {
      logger.info("Claude Desktop profile installed")
      logger.info("Gateway base URL: \{installed.base_url}")
      logger.info("Profile: \{installed.profile_path}")
      logger.info("Token saved for MoonGate gateway auth")
    }
    Err(e) => logger.error(e)
  }
}

///|
async fn uninstall_claude_desktop() -> Unit {
  let logger = @pino.logger("moongate", @pino.Transport::console())
  logger.info("Removing Claude Desktop gateway profile...")
  let result = @claude_desktop.uninstall_proxy_profile()
  match result {
    Ok(_) => logger.info("Claude Desktop profile removed")
    Err(e) => logger.error(e)
  }
}

///|
async fn install_codex(args : Array[String]) -> Unit {
  let logger = @pino.logger("moongate", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or(@suite.default_host())
  let port = parse_int_arg(args, "--port", default=@suite.default_port())
  let model = parse_string_arg(args, "--model").unwrap_or(
    @suite.default_model(),
  )
  logger.info("Installing Codex config.toml MoonGate provider...")
  let result = @codex_config.install_proxy_config(host, port, model)
  match result {
    Ok(installed) => {
      logger.info("Codex MoonGate provider installed")
      logger.info("Config: \{installed.config_path}")
      logger.info("Gateway base URL: \{installed.base_url}")
      logger.info("Model: \{installed.model}")
    }
    Err(e) => logger.error(e)
  }
}

///|
async fn uninstall_codex() -> Unit {
  let logger = @pino.logger("moongate", @pino.Transport::console())
  logger.info("Removing Codex config.toml MoonGate provider...")
  let result = @codex_config.uninstall_proxy_config()
  match result {
    Ok(_) => logger.info("Codex MoonGate provider removed")
    Err(e) => logger.error(e)
  }
}

///|
async fn print_model_candidates(args : Array[String]) -> Unit {
  let logger = @pino.logger("moongate", @pino.Transport::console())
  guard parse_string_arg(args, "--base-url") is Some(base_url) else {
    logger.error("Missing required --base-url")
    return
  }
  let is_full_url = has_flag(args, "--full-url")
  let models_url = parse_string_arg(args, "--models-url")
  match
    @moongate.build_models_url_candidates(base_url, is_full_url, models_url) {
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
    Some(s) => @string.parse_int(s[:]) catch { _ => default }
    None => default
  }
}
