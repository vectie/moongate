///|
async fn check_proxy_status(args : Array[String]) -> Unit {
  check_proxy_endpoint(args, "/proxy/status")
}

///|
async fn start_proxy_server(args : Array[String]) -> Unit {
  check_json_post_endpoint(args, "/start_proxy_server", "Proxy")
}

///|
async fn stop_proxy_server(args : Array[String]) -> Unit {
  check_json_post_endpoint(args, "/stop_proxy_server", "Proxy")
}

///|
async fn stop_proxy_with_restore(args : Array[String]) -> Unit {
  check_json_post_endpoint(args, "/stop_proxy_with_restore", "Proxy")
}

///|
async fn check_proxy_config(args : Array[String]) -> Unit {
  check_proxy_endpoint(args, "/proxy/config")
}

///|
async fn update_proxy_config(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    proxy_global_config_update_path(args, "/proxy/config"),
    "Proxy",
  )
}

///|
async fn check_proxy_global_config(args : Array[String]) -> Unit {
  check_proxy_endpoint(args, "/proxy/global-config")
}

///|
async fn update_proxy_global_config(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    proxy_global_config_update_path(args, "/proxy/global-config"),
    "Proxy",
  )
}

///|
async fn set_global_proxy_url(args : Array[String]) -> Unit {
  guard global_proxy_url_path(args, "/set_global_proxy_url") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --url")
    return
  }
  check_json_post_endpoint(args, path, "Proxy")
}

///|
async fn test_global_proxy_url(args : Array[String]) -> Unit {
  guard global_proxy_url_path(args, "/test_proxy_url") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --url")
    return
  }
  check_json_endpoint(args, path, "Proxy")
}

///|
async fn check_proxy_app_config(args : Array[String]) -> Unit {
  check_proxy_app_endpoint(args, "/proxy/app-config")
}

///|
async fn update_proxy_app_config(args : Array[String]) -> Unit {
  check_json_post_endpoint(args, proxy_app_config_update_path(args), "Proxy")
}

///|
async fn check_proxy_default_cost_multiplier(args : Array[String]) -> Unit {
  check_proxy_app_endpoint(args, "/proxy/default-cost-multiplier")
}

///|
async fn set_proxy_default_cost_multiplier(args : Array[String]) -> Unit {
  guard proxy_app_value_update_path(args, "/proxy/default-cost-multiplier")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --value")
    return
  }
  check_json_post_endpoint(args, path, "Proxy")
}

///|
async fn check_proxy_default_cost_multiplier_test_hook(
  args : Array[String],
) -> Unit {
  check_proxy_app_endpoint(args, "/get_default_cost_multiplier_test_hook")
}

///|
async fn set_proxy_default_cost_multiplier_test_hook(
  args : Array[String],
) -> Unit {
  guard proxy_app_value_update_path(
      args, "/set_default_cost_multiplier_test_hook",
    )
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --value")
    return
  }
  check_json_post_endpoint(args, path, "Proxy")
}

///|
async fn check_proxy_pricing_model_source(args : Array[String]) -> Unit {
  check_proxy_app_endpoint(args, "/proxy/pricing-model-source")
}

///|
async fn set_proxy_pricing_model_source(args : Array[String]) -> Unit {
  guard proxy_app_value_update_path(args, "/proxy/pricing-model-source")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --value")
    return
  }
  check_json_post_endpoint(args, path, "Proxy")
}

///|
async fn check_proxy_pricing_model_source_test_hook(
  args : Array[String],
) -> Unit {
  check_proxy_app_endpoint(args, "/get_pricing_model_source_test_hook")
}

///|
async fn set_proxy_pricing_model_source_test_hook(args : Array[String]) -> Unit {
  guard proxy_app_value_update_path(args, "/set_pricing_model_source_test_hook")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --value")
    return
  }
  check_json_post_endpoint(args, path, "Proxy")
}

///|
async fn check_proxy_provider_health(args : Array[String]) -> Unit {
  check_proxy_provider_endpoint(args, "/proxy/provider-health")
}

///|
async fn check_proxy_circuit_breaker_config(args : Array[String]) -> Unit {
  check_proxy_endpoint(args, "/proxy/circuit-breaker-config")
}

///|
async fn update_proxy_circuit_breaker_config(args : Array[String]) -> Unit {
  guard proxy_circuit_config_update_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error(
      "Missing required circuit config args: --failure-threshold --success-threshold --timeout-seconds --error-rate-threshold --min-requests",
    )
    return
  }
  check_json_post_endpoint(args, path, "Proxy")
}

///|
async fn check_proxy_circuit_breaker_stats(args : Array[String]) -> Unit {
  check_proxy_provider_endpoint(args, "/proxy/circuit-breaker-stats")
}

///|
async fn reset_proxy_circuit_breaker(args : Array[String]) -> Unit {
  guard proxy_provider_endpoint_path(args, "/proxy/reset-circuit-breaker")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --provider-id")
    return
  }
  check_json_post_endpoint(args, path, "Proxy")
}

///|
async fn check_proxy_failover_queue(args : Array[String]) -> Unit {
  check_proxy_app_endpoint(args, "/proxy/failover-queue")
}

///|
async fn check_proxy_available_failover_providers(args : Array[String]) -> Unit {
  check_proxy_app_endpoint(args, "/proxy/available-failover-providers")
}

///|
async fn add_proxy_failover_queue(args : Array[String]) -> Unit {
  guard proxy_provider_endpoint_path(args, "/proxy/failover-queue")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --provider-id")
    return
  }
  check_json_post_endpoint(args, path, "Proxy")
}

///|
async fn remove_proxy_failover_queue(args : Array[String]) -> Unit {
  guard proxy_provider_endpoint_path(args, "/proxy/failover-queue")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --provider-id")
    return
  }
  check_json_delete_endpoint(args, path, "Proxy")
}

///|
async fn check_proxy_auto_failover_enabled(args : Array[String]) -> Unit {
  check_proxy_app_endpoint(args, "/proxy/auto-failover-enabled")
}

///|
async fn set_proxy_auto_failover_enabled(args : Array[String]) -> Unit {
  guard proxy_auto_failover_enabled_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --enabled")
    return
  }
  check_json_post_endpoint(args, path, "Proxy")
}

///|
async fn check_proxy_takeover_status(args : Array[String]) -> Unit {
  check_proxy_endpoint(args, "/proxy/takeover-status")
}

///|
async fn set_proxy_takeover_status(args : Array[String]) -> Unit {
  guard proxy_takeover_update_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --enabled")
    return
  }
  check_json_post_endpoint(args, path, "Proxy")
}

///|
async fn switch_proxy_provider(args : Array[String]) -> Unit {
  guard proxy_provider_endpoint_path(args, "/switch_proxy_provider")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --provider-id")
    return
  }
  check_json_post_endpoint(args, path, "Proxy")
}

///|
async fn check_proxy_running(args : Array[String]) -> Unit {
  check_proxy_endpoint(args, "/proxy/running")
}

///|
fn cli_proxy_command_id(command_id : String) -> Bool {
  match command_id {
    "update_proxy_config"
    | "get_proxy_config"
    | "update_global_proxy_config"
    | "get_global_proxy_config"
    | "set_global_proxy_url"
    | "get_global_proxy_url"
    | "update_proxy_config_for_app"
    | "get_proxy_config_for_app"
    | "set_default_cost_multiplier"
    | "get_default_cost_multiplier"
    | "set_pricing_model_source"
    | "get_pricing_model_source"
    | "update_circuit_breaker_config"
    | "get_circuit_breaker_config"
    | "add_to_failover_queue"
    | "remove_from_failover_queue"
    | "get_failover_queue"
    | "set_auto_failover_enabled"
    | "get_auto_failover_enabled"
    | "set_proxy_takeover_for_app"
    | "get_proxy_takeover_status"
    | "get_proxy_status"
    | "start_proxy_server"
    | "stop_proxy_server"
    | "stop_proxy_with_restore"
    | "test_proxy_url"
    | "get_upstream_proxy_status"
    | "scan_local_proxies"
    | "get_default_cost_multiplier_test_hook"
    | "set_default_cost_multiplier_test_hook"
    | "get_pricing_model_source_test_hook"
    | "set_pricing_model_source_test_hook"
    | "get_provider_health"
    | "get_circuit_breaker_stats"
    | "reset_circuit_breaker"
    | "get_available_providers_for_failover"
    | "is_live_takeover_active"
    | "switch_proxy_provider"
    | "is_proxy_running" => true
    _ => false
  }
}

///|
async fn run_proxy_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "update_proxy_config" => update_proxy_config(args)
    "get_proxy_config" => check_proxy_config(args)
    "update_global_proxy_config" => update_proxy_global_config(args)
    "get_global_proxy_config" => check_proxy_global_config(args)
    "set_global_proxy_url" => set_global_proxy_url(args)
    "get_global_proxy_url" =>
      check_usage_endpoint(args, "/get_global_proxy_url")
    "update_proxy_config_for_app" => update_proxy_app_config(args)
    "get_proxy_config_for_app" => check_proxy_app_config(args)
    "set_default_cost_multiplier" => set_proxy_default_cost_multiplier(args)
    "get_default_cost_multiplier" => check_proxy_default_cost_multiplier(args)
    "set_pricing_model_source" => set_proxy_pricing_model_source(args)
    "get_pricing_model_source" => check_proxy_pricing_model_source(args)
    "update_circuit_breaker_config" => update_proxy_circuit_breaker_config(args)
    "get_circuit_breaker_config" => check_proxy_circuit_breaker_config(args)
    "add_to_failover_queue" => add_proxy_failover_queue(args)
    "remove_from_failover_queue" => remove_proxy_failover_queue(args)
    "get_failover_queue" => check_proxy_failover_queue(args)
    "set_auto_failover_enabled" => set_proxy_auto_failover_enabled(args)
    "get_auto_failover_enabled" => check_proxy_auto_failover_enabled(args)
    "set_proxy_takeover_for_app" => set_proxy_takeover_status(args)
    "get_proxy_takeover_status" => check_proxy_takeover_status(args)
    "get_proxy_status" => check_proxy_status(args)
    "start_proxy_server" => start_proxy_server(args)
    "stop_proxy_server" => stop_proxy_server(args)
    "stop_proxy_with_restore" => stop_proxy_with_restore(args)
    "test_proxy_url" => test_global_proxy_url(args)
    "get_upstream_proxy_status" =>
      check_usage_endpoint(args, "/get_upstream_proxy_status")
    "scan_local_proxies" => check_usage_endpoint(args, "/scan_local_proxies")
    "get_default_cost_multiplier_test_hook" =>
      check_proxy_default_cost_multiplier_test_hook(args)
    "set_default_cost_multiplier_test_hook" =>
      set_proxy_default_cost_multiplier_test_hook(args)
    "get_pricing_model_source_test_hook" =>
      check_proxy_pricing_model_source_test_hook(args)
    "set_pricing_model_source_test_hook" =>
      set_proxy_pricing_model_source_test_hook(args)
    "get_provider_health" => check_proxy_provider_health(args)
    "get_circuit_breaker_stats" => check_proxy_circuit_breaker_stats(args)
    "reset_circuit_breaker" => reset_proxy_circuit_breaker(args)
    "get_available_providers_for_failover" =>
      check_proxy_available_failover_providers(args)
    "is_live_takeover_active" =>
      check_proxy_endpoint(args, "/is_live_takeover_active")
    "switch_proxy_provider" => switch_proxy_provider(args)
    "is_proxy_running" => check_proxy_running(args)
    _ => ()
  }
}

///|
async fn check_providers(args : Array[String]) -> Unit {
  check_json_endpoint(
    args,
    provider_app_path(args, "/get_providers"),
    "Provider",
  )
}

///|
async fn check_current_provider(args : Array[String]) -> Unit {
  check_json_endpoint(
    args,
    provider_app_path(args, "/get_current_provider"),
    "Provider",
  )
}

///|
async fn add_provider(args : Array[String]) -> Unit {
  guard provider_upsert_path(args, "/add_provider", require_original=false)
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required provider args: --id")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn update_provider(args : Array[String]) -> Unit {
  guard provider_upsert_path(args, "/update_provider", require_original=false)
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required provider args: --id")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn delete_provider(args : Array[String]) -> Unit {
  guard provider_id_path(args, "/delete_provider") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_delete_endpoint(args, path, "Provider")
}

///|
async fn remove_provider_from_live_config(args : Array[String]) -> Unit {
  guard provider_id_path(args, "/remove_provider_from_live_config")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_delete_endpoint(args, path, "Provider")
}

///|
async fn switch_provider(args : Array[String]) -> Unit {
  guard provider_id_path(args, "/switch_provider") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn switch_provider_test_hook(args : Array[String]) -> Unit {
  guard provider_id_path(args, "/switch_provider_test_hook") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn sync_current_providers_live(args : Array[String]) -> Unit {
  check_json_post_endpoint(args, "/sync_current_providers_live", "Provider")
}

///|
async fn open_provider_terminal(args : Array[String]) -> Unit {
  guard open_provider_terminal_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --provider-id")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn check_live_provider_settings(args : Array[String]) -> Unit {
  check_json_endpoint(
    args,
    provider_app_path(args, "/read_live_provider_settings"),
    "Provider",
  )
}

///|
async fn check_named_live_provider_ids(
  args : Array[String],
  app_type : String,
) -> Unit {
  check_json_endpoint(args, provider_live_ids_path(app_type), "Provider")
}

///|
async fn check_named_live_provider(
  args : Array[String],
  app_type : String,
) -> Unit {
  guard provider_live_provider_path(args, app_type) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_endpoint(args, path, "Provider")
}

///|
async fn import_named_live_providers(
  args : Array[String],
  app_type : String,
) -> Unit {
  check_json_post_endpoint(
    args,
    provider_import_live_path(app_type),
    "Provider",
  )
}

///|
async fn check_provider_live_ids(args : Array[String]) -> Unit {
  check_json_endpoint(
    args,
    provider_live_ids_path(provider_app_arg(args)),
    "Provider",
  )
}

///|
async fn check_provider_live_provider(args : Array[String]) -> Unit {
  guard provider_live_provider_path(args, provider_app_arg(args)) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_endpoint(args, path, "Provider")
}

///|
async fn import_provider_live(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    provider_import_live_path(provider_app_arg(args)),
    "Provider",
  )
}

///|
async fn check_universal_providers(args : Array[String]) -> Unit {
  check_json_endpoint(args, "/get_universal_providers", "Provider")
}

///|
async fn check_universal_provider(args : Array[String]) -> Unit {
  guard universal_provider_id_path(args, "/get_universal_provider")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_endpoint(args, path, "Provider")
}

///|
async fn upsert_universal_provider(args : Array[String]) -> Unit {
  guard universal_provider_upsert_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required universal provider args: --id")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn delete_universal_provider(args : Array[String]) -> Unit {
  guard universal_provider_id_path(args, "/delete_universal_provider")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_delete_endpoint(args, path, "Provider")
}

///|
async fn sync_universal_provider(args : Array[String]) -> Unit {
  guard universal_provider_id_path(args, "/sync_universal_provider")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn check_provider_presets(args : Array[String]) -> Unit {
  check_json_endpoint(args, provider_presets_path(args), "Provider")
}

///|
async fn update_providers_sort_order(args : Array[String]) -> Unit {
  guard provider_sort_order_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required provider sort args: --id --sort-index")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn check_provider_custom_endpoints(args : Array[String]) -> Unit {
  guard provider_id_path(args, "/get_custom_endpoints") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_endpoint(args, path, "Provider")
}

///|
async fn add_provider_custom_endpoint(args : Array[String]) -> Unit {
  guard provider_endpoint_url_path(args, "/add_custom_endpoint") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required provider endpoint args: --id --endpoint-url")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn remove_provider_custom_endpoint(args : Array[String]) -> Unit {
  guard provider_endpoint_url_path(args, "/remove_custom_endpoint")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required provider endpoint args: --id --endpoint-url")
    return
  }
  check_json_delete_endpoint(args, path, "Provider")
}

///|
async fn update_provider_endpoint_last_used(args : Array[String]) -> Unit {
  guard provider_endpoint_url_path(args, "/update_endpoint_last_used")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required provider endpoint args: --id --endpoint-url")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn check_proxy_endpoint(args : Array[String], path : String) -> Unit {
  check_json_endpoint(args, path, "Proxy")
}

///|
async fn check_proxy_app_endpoint(args : Array[String], path : String) -> Unit {
  let app_type = proxy_app_arg(args)
  check_proxy_endpoint(args, "\{path}?app_type=\{cli_url_encode(app_type)}")
}

///|
async fn check_proxy_provider_endpoint(
  args : Array[String],
  path : String,
) -> Unit {
  guard proxy_provider_endpoint_path(args, path) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --provider-id")
    return
  }
  check_proxy_endpoint(args, path)
}

///|
fn proxy_provider_endpoint_path(args : Array[String], path : String) -> String? {
  guard parse_string_arg_any(args, "--provider-id", "--providerId")
    is Some(provider_id) else {
    return None
  }
  let app_type = proxy_app_arg(args)
  Some(
    "\{path}?provider_id=\{cli_url_encode(provider_id)}&app_type=\{cli_url_encode(app_type)}",
  )
}

///|
fn proxy_app_arg(args : Array[String]) -> String {
  match parse_string_arg_any(args, "--app", "--app-type") {
    Some(value) => value
    None => parse_string_arg(args, "--appType").unwrap_or("claude")
  }
}

///|
fn provider_app_arg(args : Array[String]) -> String {
  match parse_string_arg_any(args, "--app", "--app-type") {
    Some(value) => value
    None => parse_string_arg(args, "--appType").unwrap_or("claude")
  }
}

///|
fn provider_id_arg(args : Array[String]) -> String? {
  match parse_string_arg(args, "--id") {
    Some(id) => Some(id)
    None => parse_string_arg_any(args, "--provider-id", "--providerId")
  }
}

///|
fn provider_app_path(args : Array[String], path : String) -> String {
  "\{path}?app=\{cli_url_encode(provider_app_arg(args))}"
}

///|
fn provider_id_path(args : Array[String], path : String) -> String? {
  guard provider_id_arg(args) is Some(provider_id) else { return None }
  Some(
    "\{path}?app=\{cli_url_encode(provider_app_arg(args))}&id=\{cli_url_encode(provider_id)}",
  )
}

///|
fn open_provider_terminal_path(args : Array[String]) -> String? {
  guard provider_id_arg(args) is Some(provider_id) else { return None }
  let query : Array[String] = [
    cli_query_pair("app", provider_app_arg(args)),
    cli_query_pair("providerId", provider_id),
  ]
  match parse_string_arg(args, "--cwd") {
    Some(cwd) => query.push(cli_query_pair("cwd", cwd))
    None => ()
  }
  Some(cli_path_with_query("/open_provider_terminal", query))
}

///|
fn provider_live_ids_path(app_type : String) -> String {
  match app_type {
    "opencode" => "/get_opencode_live_provider_ids"
    "openclaw" => "/get_openclaw_live_provider_ids"
    "hermes" => "/get_hermes_live_provider_ids"
    _ => "/get_providers?app=\{cli_url_encode(app_type)}"
  }
}

///|
fn provider_live_provider_path(
  args : Array[String],
  app_type : String,
) -> String? {
  guard provider_id_arg(args) is Some(provider_id) else { return None }
  let path = match app_type {
    "openclaw" => "/get_openclaw_live_provider"
    "hermes" => "/get_hermes_live_provider"
    _ => "/get_providers"
  }
  Some("\{path}?providerId=\{cli_url_encode(provider_id)}")
}

///|
fn provider_import_live_path(app_type : String) -> String {
  match app_type {
    "opencode" => "/import_opencode_providers_from_live"
    "openclaw" => "/import_openclaw_providers_from_live"
    "hermes" => "/import_hermes_providers_from_live"
    _ => "/get_providers?app=\{cli_url_encode(app_type)}"
  }
}

///|
fn universal_provider_id_path(args : Array[String], path : String) -> String? {
  guard provider_id_arg(args) is Some(provider_id) else { return None }
  Some("\{path}?id=\{cli_url_encode(provider_id)}")
}

///|
fn universal_provider_upsert_path(args : Array[String]) -> String? {
  guard provider_id_arg(args) is Some(provider_id) else { return None }
  let name = parse_string_arg(args, "--name").unwrap_or(provider_id)
  let query : Array[String] = [
    cli_query_pair("id", provider_id),
    cli_query_pair("name", name),
  ]
  match parse_string_arg_any(args, "--provider-type", "--providerType") {
    Some(value) => query.push(cli_query_pair("providerType", value))
    None => ()
  }
  match parse_string_arg_any(args, "--base-url", "--baseUrl") {
    Some(value) => query.push(cli_query_pair("baseUrl", value))
    None => ()
  }
  match parse_string_arg_any(args, "--api-key", "--apiKey") {
    Some(value) => query.push(cli_query_pair("apiKey", value))
    None => ()
  }
  match parse_string_arg(args, "--apps") {
    Some(value) => query.push(cli_query_pair("apps", value))
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
  match parse_string_arg_any(args, "--reasoning-effort", "--reasoningEffort") {
    Some(value) => query.push(cli_query_pair("reasoningEffort", value))
    None => ()
  }
  Some("/upsert_universal_provider?\{query.join("&")}")
}

///|
fn provider_presets_path(args : Array[String]) -> String {
  let query : Array[String] = [
    cli_query_pair("appType", provider_app_arg(args)),
  ]
  match parse_string_arg(args, "--query") {
    Some(value) => query.push(cli_query_pair("query", value))
    None => ()
  }
  match parse_string_arg_any(args, "--sort-mode", "--sortMode") {
    Some(value) => query.push(cli_query_pair("sortMode", value))
    None => ()
  }
  cli_path_with_query("/get_provider_presets", query)
}

///|
fn provider_endpoint_url_path(args : Array[String], path : String) -> String? {
  guard provider_id_arg(args) is Some(provider_id) else { return None }
  guard parse_string_arg_any(args, "--endpoint-url", "--endpointUrl")
    is Some(endpoint_url) else {
    return None
  }
  Some(
    "\{path}?app=\{cli_url_encode(provider_app_arg(args))}&providerId=\{cli_url_encode(provider_id)}&url=\{cli_url_encode(endpoint_url)}",
  )
}

///|
fn provider_test_endpoints_path(args : Array[String]) -> String? {
  let urls = match parse_string_arg(args, "--urls") {
    Some(value) => value
    None =>
      match parse_string_arg(args, "--url") {
        Some(value) => value
        None => return None
      }
  }
  let query : Array[String] = [cli_query_pair("urls", urls)]
  match parse_string_arg_any(args, "--timeout-secs", "--timeoutSecs") {
    Some(value) => query.push(cli_query_pair("timeoutSecs", value))
    None => ()
  }
  Some("/test_api_endpoints?\{query.join("&")}")
}

///|
fn provider_sort_order_path(args : Array[String]) -> String? {
  guard provider_id_arg(args) is Some(provider_id) else { return None }
  guard parse_string_arg_any(args, "--sort-index", "--sortIndex")
    is Some(sort_index) else {
    return None
  }
  Some(
    "/update_providers_sort_order?app=\{cli_url_encode(provider_app_arg(args))}&id=\{cli_url_encode(provider_id)}&sortIndex=\{cli_url_encode(sort_index)}",
  )
}

///|
fn provider_upsert_path(
  args : Array[String],
  path : String,
  require_original~ : Bool,
) -> String? {
  guard provider_id_arg(args) is Some(provider_id) else { return None }
  let name = parse_string_arg(args, "--name").unwrap_or(provider_id)
  if require_original &&
    parse_string_arg_any(args, "--original-id", "--originalId") is None {
    return None
  }
  let query : Array[String] = [
    cli_query_pair("app", provider_app_arg(args)),
    cli_query_pair("id", provider_id),
    cli_query_pair("name", name),
  ]
  match parse_string_arg_any(args, "--original-id", "--originalId") {
    Some(value) => query.push(cli_query_pair("originalId", value))
    None => ()
  }
  match parse_string_arg_any(args, "--base-url", "--baseUrl") {
    Some(value) => query.push(cli_query_pair("baseUrl", value))
    None => ()
  }
  match parse_string_arg_any(args, "--api-key", "--apiKey") {
    Some(value) => query.push(cli_query_pair("apiKey", value))
    None => ()
  }
  match parse_string_arg(args, "--category") {
    Some(value) => query.push(cli_query_pair("category", value))
    None => ()
  }
  match parse_string_arg(args, "--enabled") {
    Some(value) => query.push(cli_query_pair("enabled", value))
    None => ()
  }
  match parse_string_arg_any(args, "--add-to-live", "--addToLive") {
    Some(value) => query.push(cli_query_pair("addToLive", value))
    None => ()
  }
  Some("\{path}?\{query.join("&")}")
}

///|
fn proxy_app_value_update_path(args : Array[String], path : String) -> String? {
  guard parse_string_arg(args, "--value") is Some(value) else { return None }
  let app_type = proxy_app_arg(args)
  Some(
    "\{path}?app_type=\{cli_url_encode(app_type)}&value=\{cli_url_encode(value)}",
  )
}

///|
fn proxy_circuit_config_update_path(args : Array[String]) -> String? {
  guard parse_string_arg_any(args, "--failure-threshold", "--failureThreshold")
    is Some(failure_threshold) else {
    return None
  }
  guard parse_string_arg_any(args, "--success-threshold", "--successThreshold")
    is Some(success_threshold) else {
    return None
  }
  guard parse_string_arg_any(args, "--timeout-seconds", "--timeoutSeconds")
    is Some(timeout_seconds) else {
    return None
  }
  guard parse_string_arg_any(
      args, "--error-rate-threshold", "--errorRateThreshold",
    )
    is Some(error_rate_threshold) else {
    return None
  }
  guard parse_string_arg_any(args, "--min-requests", "--minRequests")
    is Some(min_requests) else {
    return None
  }
  let query = [
    cli_query_pair("failureThreshold", failure_threshold),
    cli_query_pair("successThreshold", success_threshold),
    cli_query_pair("timeoutSeconds", timeout_seconds),
    cli_query_pair("errorRateThreshold", error_rate_threshold),
    cli_query_pair("minRequests", min_requests),
  ].join("&")
  Some("/proxy/circuit-breaker-config?\{query}")
}

///|
fn proxy_global_config_update_path(
  args : Array[String],
  path : String,
) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--proxy-enabled", "--proxyEnabled") {
    Some(value) => query.push(cli_query_pair("proxyEnabled", value))
    None => ()
  }
  match parse_string_arg_any(args, "--listen-address", "--listenAddress") {
    Some(value) => query.push(cli_query_pair("listenAddress", value))
    None => ()
  }
  match parse_string_arg_any(args, "--listen-port", "--listenPort") {
    Some(value) => query.push(cli_query_pair("listenPort", value))
    None => ()
  }
  match parse_string_arg_any(args, "--enable-logging", "--enableLogging") {
    Some(value) => query.push(cli_query_pair("enableLogging", value))
    None => ()
  }
  if query.is_empty() {
    path
  } else {
    "\{path}?\{query.join("&")}"
  }
}

///|
fn global_proxy_url_path(args : Array[String], path : String) -> String? {
  guard parse_string_arg(args, "--url") is Some(url) else { return None }
  Some("\{path}?url=\{cli_url_encode(url)}")
}

///|
fn proxy_app_config_update_path(args : Array[String]) -> String {
  let app_type = proxy_app_arg(args)
  let query : Array[String] = [cli_query_pair("appType", app_type)]
  match parse_string_arg(args, "--enabled") {
    Some(value) => query.push(cli_query_pair("enabled", value))
    None => ()
  }
  match
    parse_string_arg_any(
      args, "--auto-failover-enabled", "--autoFailoverEnabled",
    ) {
    Some(value) => query.push(cli_query_pair("autoFailoverEnabled", value))
    None => ()
  }
  match parse_string_arg_any(args, "--max-retries", "--maxRetries") {
    Some(value) => query.push(cli_query_pair("maxRetries", value))
    None => ()
  }
  match
    parse_string_arg_any(
      args, "--streaming-first-byte-timeout", "--streamingFirstByteTimeout",
    ) {
    Some(value) =>
      query.push(cli_query_pair("streamingFirstByteTimeout", value))
    None => ()
  }
  match
    parse_string_arg_any(
      args, "--streaming-idle-timeout", "--streamingIdleTimeout",
    ) {
    Some(value) => query.push(cli_query_pair("streamingIdleTimeout", value))
    None => ()
  }
  match
    parse_string_arg_any(
      args, "--non-streaming-timeout", "--nonStreamingTimeout",
    ) {
    Some(value) => query.push(cli_query_pair("nonStreamingTimeout", value))
    None => ()
  }
  match
    parse_string_arg_any(args, "--failure-threshold", "--failureThreshold") {
    Some(value) => query.push(cli_query_pair("failureThreshold", value))
    None => ()
  }
  match
    parse_string_arg_any(args, "--success-threshold", "--successThreshold") {
    Some(value) => query.push(cli_query_pair("successThreshold", value))
    None => ()
  }
  match parse_string_arg_any(args, "--timeout-seconds", "--timeoutSeconds") {
    Some(value) => query.push(cli_query_pair("timeoutSeconds", value))
    None => ()
  }
  match
    parse_string_arg_any(args, "--error-rate-threshold", "--errorRateThreshold") {
    Some(value) => query.push(cli_query_pair("errorRateThreshold", value))
    None => ()
  }
  match parse_string_arg_any(args, "--min-requests", "--minRequests") {
    Some(value) => query.push(cli_query_pair("minRequests", value))
    None => ()
  }
  "/proxy/app-config?\{query.join("&")}"
}

///|
fn proxy_takeover_update_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--enabled") is Some(enabled) else {
    return None
  }
  let app_type = proxy_app_arg(args)
  Some(
    "/proxy/takeover-status?app_type=\{cli_url_encode(app_type)}&enabled=\{cli_url_encode(enabled)}",
  )
}

///|
fn proxy_auto_failover_enabled_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--enabled") is Some(enabled) else {
    return None
  }
  let app_type = proxy_app_arg(args)
  Some(
    "/proxy/auto-failover-enabled?app_type=\{cli_url_encode(app_type)}&enabled=\{cli_url_encode(enabled)}",
  )
}

///|
fn stream_check_provider_path(args : Array[String]) -> String? {
  let app_type = match parse_string_arg_any(args, "--app-type", "--appType") {
    Some(value) => Some(value)
    None => parse_string_arg(args, "--app")
  }
  guard app_type is Some(app_type) else { return None }
  let provider_id = match
    parse_string_arg_any(args, "--provider-id", "--providerId") {
    Some(value) => Some(value)
    None => parse_string_arg(args, "--id")
  }
  guard provider_id is Some(provider_id) else { return None }
  Some(
    "/stream_check_provider?appType=\{cli_url_encode(app_type)}&providerId=\{cli_url_encode(provider_id)}",
  )
}

///|
async fn check_usage_providers(args : Array[String]) -> Unit {
  check_usage_endpoint(
    args,
    usage_filtered_path(args, "/usage/provider-stats", app_filter=true),
  )
}

///|
async fn stream_check_provider(args : Array[String]) -> Unit {
  guard stream_check_provider_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required stream check args: --provider-id --app-type")
    return
  }
  check_usage_endpoint(args, path)
}

///|
async fn stream_check_all_providers(args : Array[String]) -> Unit {
  check_usage_endpoint(args, stream_check_all_path(args))
}

///|
async fn check_usage_provider_script(args : Array[String]) -> Unit {
  guard usage_provider_script_path(args, "/queryProviderUsage", false)
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required usage script args: --provider-id --app")
    return
  }
  check_usage_endpoint(args, path)
}

///|
fn usage_provider_script_path(
  args : Array[String],
  path : String,
  include_script : Bool,
) -> String? {
  guard parse_string_arg_any(args, "--provider-id", "--providerId")
    is Some(provider_id) else {
    return None
  }
  let app = match parse_string_arg_any(args, "--app", "--app-type") {
    Some(value) => Some(value)
    None => parse_string_arg(args, "--appType")
  }
  guard app is Some(app) else { return None }
  let query = [
    cli_query_pair("providerId", provider_id),
    cli_query_pair("app", app),
  ]
  if include_script {
    match parse_string_arg_any(args, "--script-code", "--scriptCode") {
      Some(value) => query.push(cli_query_pair("scriptCode", value))
      None => ()
    }
  }
  Some("\{path}?\{query.join("&")}")
}

///|
fn usage_pricing_update_path(args : Array[String]) -> String? {
  guard parse_string_arg_any(args, "--model-id", "--modelId") is Some(model_id) else {
    return None
  }
  guard parse_string_arg_any(args, "--display-name", "--displayName")
    is Some(display_name) else {
    return None
  }
  guard parse_string_arg_any(args, "--input-cost", "--inputCost")
    is Some(input_cost) else {
    return None
  }
  guard parse_string_arg_any(args, "--output-cost", "--outputCost")
    is Some(output_cost) else {
    return None
  }
  guard parse_string_arg_any(args, "--cache-read-cost", "--cacheReadCost")
    is Some(cache_read_cost) else {
    return None
  }
  guard parse_string_arg_any(
      args, "--cache-creation-cost", "--cacheCreationCost",
    )
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
  guard parse_string_arg_any(args, "--model-id", "--modelId") is Some(model_id) else {
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
    if response.code == 200 {
      let body = client.read_all().text()
      println(body)
    } else {
      let body = client.read_all().text()
      logger.error("Usage pricing delete failed: \{response.code} \{body}")
    }
  } catch {
    err => logger.error("Usage pricing delete failed: \{err}")
  }
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
fn provider_models_to_json(models : Array[@moonstat.FetchedModel]) -> Json {
  @moonstat.fetched_models_to_json(models)
}

///|
fn print_moonclaw_providers_file(args : Array[String]) -> Unit {
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-5")
  println(
    @moonstat.moonstat_moonclaw_providers_file_json(host~, port~, model~).stringify(
      indent=2,
    ),
  )
}

///|
async fn write_moonclaw_providers_file(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-5")
  let path = parse_string_arg(args, "--path").unwrap_or(
    @moonstat.default_moonstat_moonclaw_providers_file_path(),
  )
  let written = @moonstat.write_moonstat_moonclaw_providers_file(
    path~,
    host~,
    port~,
    model~,
  )
  logger.info("MoonClaw providers file written: \{written}")
}
