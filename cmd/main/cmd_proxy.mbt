///|
async fn check_proxy_status(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy status",
    cli_moonstat_client(args).proxy_status(),
  )
}

///|
async fn start_proxy_server(args : Array[String]) -> Unit {
  print_cli_json_result("Proxy start", cli_moonstat_client(args).proxy_start())
}

///|
async fn stop_proxy_server(args : Array[String]) -> Unit {
  print_cli_json_result("Proxy stop", cli_moonstat_client(args).proxy_stop())
}

///|
async fn stop_proxy_with_restore(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy stop with restore",
    cli_moonstat_client(args).proxy_stop_with_restore(),
  )
}

///|
async fn check_proxy_global_config(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy global config",
    cli_moonstat_client(args).proxy_global_config(),
  )
}

///|
async fn update_proxy_global_config(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy global config update",
    cli_moonstat_client(args).proxy_update_global_config(
      proxy_enabled=parse_string_arg(args, "--proxy-enabled"),
      listen_address=parse_string_arg(args, "--listen-address"),
      listen_port=parse_string_arg(args, "--listen-port"),
      enable_logging=parse_string_arg(args, "--enable-logging"),
    ),
  )
}

///|
async fn set_global_proxy_url(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--url") is Some(url) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --url")
    return
  }
  print_cli_json_result(
    "Proxy global URL update",
    cli_moonstat_client(args).proxy_set_global_url(url),
  )
}

///|
async fn test_global_proxy_url(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--url") is Some(url) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --url")
    return
  }
  print_cli_json_result(
    "Proxy URL test",
    cli_moonstat_client(args).proxy_test_url(url),
  )
}

///|
async fn check_proxy_app_config(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy app config",
    cli_moonstat_client(args).proxy_app_config(proxy_app_arg(args)),
  )
}

///|
async fn update_proxy_app_config(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy app config update",
    cli_moonstat_client(args).proxy_update_app_config(
      proxy_app_arg(args),
      enabled=parse_string_arg(args, "--enabled"),
      auto_failover_enabled=parse_string_arg(args, "--auto-failover-enabled"),
      max_retries=parse_string_arg(args, "--max-retries"),
      streaming_first_byte_timeout=parse_string_arg(
        args, "--streaming-first-byte-timeout",
      ),
      streaming_idle_timeout=parse_string_arg(args, "--streaming-idle-timeout"),
      non_streaming_timeout=parse_string_arg(args, "--non-streaming-timeout"),
      failure_threshold=parse_string_arg(args, "--failure-threshold"),
      success_threshold=parse_string_arg(args, "--success-threshold"),
      timeout_seconds=parse_string_arg(args, "--timeout-seconds"),
      error_rate_threshold=parse_string_arg(args, "--error-rate-threshold"),
      min_requests=parse_string_arg(args, "--min-requests"),
    ),
  )
}

///|
async fn check_proxy_default_cost_multiplier(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy default cost multiplier",
    cli_moonstat_client(args).proxy_default_cost_multiplier(proxy_app_arg(args)),
  )
}

///|
async fn set_proxy_default_cost_multiplier(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--value") is Some(value) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --value")
    return
  }
  print_cli_json_result(
    "Proxy default cost multiplier update",
    cli_moonstat_client(args).proxy_set_default_cost_multiplier(
      proxy_app_arg(args),
      value,
    ),
  )
}

///|
async fn check_proxy_pricing_model_source(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy pricing model source",
    cli_moonstat_client(args).proxy_pricing_model_source(proxy_app_arg(args)),
  )
}

///|
async fn set_proxy_pricing_model_source(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--value") is Some(value) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --value")
    return
  }
  print_cli_json_result(
    "Proxy pricing model source update",
    cli_moonstat_client(args).proxy_set_pricing_model_source(
      proxy_app_arg(args),
      value,
    ),
  )
}

///|
async fn check_proxy_provider_health(args : Array[String]) -> Unit {
  match proxy_provider_args(args) {
    Some((app_type, provider_id)) =>
      print_cli_json_result(
        "Proxy provider health",
        cli_moonstat_client(args).proxy_provider_health(app_type, provider_id),
      )
    None => proxy_missing_provider_id()
  }
}

///|
async fn check_proxy_circuit_breaker_config(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy circuit breaker config",
    cli_moonstat_client(args).proxy_circuit_breaker_config(),
  )
}

///|
async fn update_proxy_circuit_breaker_config(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--failure-threshold") is Some(failure_threshold) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error(
      "Missing required circuit config args: --failure-threshold --success-threshold --timeout-seconds --error-rate-threshold --min-requests",
    )
    return
  }
  guard parse_string_arg(args, "--success-threshold") is Some(success_threshold) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error(
      "Missing required circuit config args: --failure-threshold --success-threshold --timeout-seconds --error-rate-threshold --min-requests",
    )
    return
  }
  guard parse_string_arg(args, "--timeout-seconds") is Some(timeout_seconds) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error(
      "Missing required circuit config args: --failure-threshold --success-threshold --timeout-seconds --error-rate-threshold --min-requests",
    )
    return
  }
  guard parse_string_arg(args, "--error-rate-threshold")
    is Some(error_rate_threshold) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error(
      "Missing required circuit config args: --failure-threshold --success-threshold --timeout-seconds --error-rate-threshold --min-requests",
    )
    return
  }
  guard parse_string_arg(args, "--min-requests") is Some(min_requests) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error(
      "Missing required circuit config args: --failure-threshold --success-threshold --timeout-seconds --error-rate-threshold --min-requests",
    )
    return
  }
  print_cli_json_result(
    "Proxy circuit breaker config update",
    cli_moonstat_client(args).proxy_update_circuit_breaker_config(
      failure_threshold, success_threshold, timeout_seconds, error_rate_threshold,
      min_requests,
    ),
  )
}

///|
async fn check_proxy_circuit_breaker_stats(args : Array[String]) -> Unit {
  match proxy_provider_args(args) {
    Some((app_type, provider_id)) =>
      print_cli_json_result(
        "Proxy circuit breaker stats",
        cli_moonstat_client(args).proxy_circuit_breaker_stats(
          app_type, provider_id,
        ),
      )
    None => proxy_missing_provider_id()
  }
}

///|
async fn reset_proxy_circuit_breaker(args : Array[String]) -> Unit {
  match proxy_provider_args(args) {
    Some((app_type, provider_id)) =>
      print_cli_json_result(
        "Proxy circuit breaker reset",
        cli_moonstat_client(args).proxy_reset_circuit_breaker(
          app_type, provider_id,
        ),
      )
    None => proxy_missing_provider_id()
  }
}

///|
async fn check_proxy_failover_queue(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy failover queue",
    cli_moonstat_client(args).proxy_failover_queue(proxy_app_arg(args)),
  )
}

///|
async fn check_proxy_available_failover_providers(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy available failover providers",
    cli_moonstat_client(args).proxy_available_failover_providers(
      proxy_app_arg(args),
    ),
  )
}

///|
async fn add_proxy_failover_queue(args : Array[String]) -> Unit {
  match proxy_provider_args(args) {
    Some((app_type, provider_id)) =>
      print_cli_json_result(
        "Proxy failover queue add",
        cli_moonstat_client(args).proxy_add_failover_queue(
          app_type, provider_id,
        ),
      )
    None => proxy_missing_provider_id()
  }
}

///|
async fn remove_proxy_failover_queue(args : Array[String]) -> Unit {
  match proxy_provider_args(args) {
    Some((app_type, provider_id)) =>
      print_cli_json_result(
        "Proxy failover queue remove",
        cli_moonstat_client(args).proxy_remove_failover_queue(
          app_type, provider_id,
        ),
      )
    None => proxy_missing_provider_id()
  }
}

///|
async fn check_proxy_auto_failover_enabled(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy auto failover enabled",
    cli_moonstat_client(args).proxy_auto_failover_enabled(proxy_app_arg(args)),
  )
}

///|
async fn set_proxy_auto_failover_enabled(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--enabled") is Some(enabled) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --enabled")
    return
  }
  print_cli_json_result(
    "Proxy auto failover update",
    cli_moonstat_client(args).proxy_set_auto_failover_enabled(
      proxy_app_arg(args),
      enabled,
    ),
  )
}

///|
async fn check_proxy_takeover_status(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy takeover status",
    cli_moonstat_client(args).proxy_takeover_status(),
  )
}

///|
async fn set_proxy_takeover_status(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--enabled") is Some(enabled) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --enabled")
    return
  }
  print_cli_json_result(
    "Proxy takeover update",
    cli_moonstat_client(args).proxy_set_takeover_status(
      proxy_app_arg(args),
      enabled,
    ),
  )
}

///|
async fn switch_proxy_provider(args : Array[String]) -> Unit {
  match proxy_provider_args(args) {
    Some((app_type, provider_id)) =>
      print_cli_json_result(
        "Proxy provider switch",
        cli_moonstat_client(args).proxy_switch_provider(app_type, provider_id),
      )
    None => proxy_missing_provider_id()
  }
}

///|
async fn check_proxy_running(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Proxy running",
    cli_moonstat_client(args).proxy_running(),
  )
}

///|
fn proxy_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "update_global_proxy_config", patterns: ["proxy global-config set"] },
    { id: "get_global_proxy_config", patterns: ["proxy global-config"] },
    { id: "set_global_proxy_url", patterns: ["proxy global-url set"] },
    { id: "get_global_proxy_url", patterns: ["proxy global-url"] },
    { id: "update_proxy_config_for_app", patterns: ["proxy app-config set"] },
    { id: "get_proxy_config_for_app", patterns: ["proxy app-config"] },
    {
      id: "set_default_cost_multiplier",
      patterns: ["proxy default-cost-multiplier set"],
    },
    {
      id: "get_default_cost_multiplier",
      patterns: ["proxy default-cost-multiplier"],
    },
    {
      id: "set_pricing_model_source",
      patterns: ["proxy pricing-model-source set"],
    },
    { id: "get_pricing_model_source", patterns: ["proxy pricing-model-source"] },
    {
      id: "update_circuit_breaker_config",
      patterns: ["proxy circuit-breaker-config set"],
    },
    {
      id: "get_circuit_breaker_config",
      patterns: ["proxy circuit-breaker-config"],
    },
    { id: "add_to_failover_queue", patterns: ["proxy failover-queue add"] },
    {
      id: "remove_from_failover_queue",
      patterns: ["proxy failover-queue remove"],
    },
    { id: "get_failover_queue", patterns: ["proxy failover-queue"] },
    {
      id: "set_auto_failover_enabled",
      patterns: ["proxy auto-failover-enabled set"],
    },
    {
      id: "get_auto_failover_enabled",
      patterns: ["proxy auto-failover-enabled"],
    },
    {
      id: "set_proxy_takeover_for_app",
      patterns: ["proxy takeover-status set"],
    },
    { id: "get_proxy_takeover_status", patterns: ["proxy takeover-status"] },
    { id: "get_proxy_status", patterns: ["proxy status"] },
    { id: "start_proxy_server", patterns: ["proxy start"] },
    { id: "stop_proxy_server", patterns: ["proxy stop"] },
    { id: "stop_proxy_with_restore", patterns: ["proxy stop-with-restore"] },
    { id: "test_proxy_url", patterns: ["proxy test-url"] },
    { id: "get_upstream_proxy_status", patterns: ["proxy upstream-status"] },
    { id: "scan_local_proxies", patterns: ["proxy scan-local"] },
    { id: "get_provider_health", patterns: ["proxy provider-health"] },
    {
      id: "get_circuit_breaker_stats",
      patterns: ["proxy circuit-breaker-stats"],
    },
    { id: "reset_circuit_breaker", patterns: ["proxy reset-circuit-breaker"] },
    {
      id: "get_available_providers_for_failover",
      patterns: ["proxy available-failover-providers"],
    },
    { id: "is_live_takeover_active", patterns: ["proxy live-takeover-active"] },
    { id: "switch_proxy_provider", patterns: ["proxy switch-provider"] },
    { id: "get_proxy_running", patterns: ["proxy running"] },
  ]
}

///|
async fn run_proxy_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "update_global_proxy_config" => update_proxy_global_config(args)
    "get_global_proxy_config" => check_proxy_global_config(args)
    "set_global_proxy_url" => set_global_proxy_url(args)
    "get_global_proxy_url" =>
      print_cli_json_result(
        "Proxy global URL",
        cli_moonstat_client(args).proxy_global_url(),
      )
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
      print_cli_json_result(
        "Proxy upstream status",
        cli_moonstat_client(args).proxy_upstream_status(),
      )
    "scan_local_proxies" =>
      print_cli_json_result(
        "Proxy local proxies",
        cli_moonstat_client(args).proxy_local_proxies(),
      )
    "get_provider_health" => check_proxy_provider_health(args)
    "get_circuit_breaker_stats" => check_proxy_circuit_breaker_stats(args)
    "reset_circuit_breaker" => reset_proxy_circuit_breaker(args)
    "get_available_providers_for_failover" =>
      check_proxy_available_failover_providers(args)
    "is_live_takeover_active" =>
      print_cli_json_result(
        "Proxy takeover status",
        cli_moonstat_client(args).proxy_takeover_status(),
      )
    "switch_proxy_provider" => switch_proxy_provider(args)
    "get_proxy_running" => check_proxy_running(args)
    _ => ()
  }
}

///|
async fn check_providers(args : Array[String]) -> Unit {
  check_json_endpoint(args, provider_app_path(args, "/providers"), "Provider")
}

///|
async fn check_current_provider(args : Array[String]) -> Unit {
  check_json_endpoint(
    args,
    provider_app_path(args, "/providers/current"),
    "Provider",
  )
}

///|
async fn add_provider(args : Array[String]) -> Unit {
  guard provider_upsert_path(args, "/providers", require_original=false)
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required provider args: --provider-id")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn update_provider(args : Array[String]) -> Unit {
  guard provider_upsert_path(args, "/providers/update", require_original=false)
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required provider args: --provider-id")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn delete_provider(args : Array[String]) -> Unit {
  guard provider_id_path(args, "/providers") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --provider-id")
    return
  }
  check_json_delete_endpoint(args, path, "Provider")
}

///|
async fn remove_provider_from_live_config(args : Array[String]) -> Unit {
  guard provider_id_path(args, "/providers/live") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --provider-id")
    return
  }
  check_json_delete_endpoint(args, path, "Provider")
}

///|
async fn switch_provider(args : Array[String]) -> Unit {
  guard provider_id_path(args, "/providers/switch") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --provider-id")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn sync_current_providers_live(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args, "/proxy/sync-current-providers-live", "Provider",
  )
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
    provider_app_path(args, "/providers/live-settings"),
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
    logger.error("Missing required --provider-id")
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
    logger.error("Missing required --provider-id")
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
  check_json_endpoint(args, "/providers/universal", "Provider")
}

///|
async fn check_universal_provider(args : Array[String]) -> Unit {
  guard universal_provider_id_path(args, "/providers/universal/item")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --provider-id")
    return
  }
  check_json_endpoint(args, path, "Provider")
}

///|
async fn upsert_universal_provider(args : Array[String]) -> Unit {
  guard universal_provider_upsert_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required universal provider args: --provider-id")
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn delete_universal_provider(args : Array[String]) -> Unit {
  guard universal_provider_id_path(args, "/providers/universal") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --provider-id")
    return
  }
  check_json_delete_endpoint(args, path, "Provider")
}

///|
async fn sync_universal_provider(args : Array[String]) -> Unit {
  guard universal_provider_id_path(args, "/providers/universal/sync")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --provider-id")
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
    logger.error(
      "Missing required provider sort args: --provider-id --sort-index",
    )
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn check_provider_custom_endpoints(args : Array[String]) -> Unit {
  guard provider_id_path(args, "/providers/endpoints/list") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --provider-id")
    return
  }
  check_json_endpoint(args, path, "Provider")
}

///|
async fn add_provider_custom_endpoint(args : Array[String]) -> Unit {
  guard provider_endpoint_url_path(args, "/providers/endpoints") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error(
      "Missing required provider endpoint args: --provider-id --endpoint-url",
    )
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
async fn remove_provider_custom_endpoint(args : Array[String]) -> Unit {
  guard provider_endpoint_url_path(args, "/providers/endpoints") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error(
      "Missing required provider endpoint args: --provider-id --endpoint-url",
    )
    return
  }
  check_json_delete_endpoint(args, path, "Provider")
}

///|
async fn update_provider_endpoint_last_used(args : Array[String]) -> Unit {
  guard provider_endpoint_url_path(args, "/providers/endpoints/touch")
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error(
      "Missing required provider endpoint args: --provider-id --endpoint-url",
    )
    return
  }
  check_json_post_endpoint(args, path, "Provider")
}

///|
fn proxy_provider_args(args : Array[String]) -> (String, String)? {
  guard parse_string_arg(args, "--provider-id") is Some(provider_id) else {
    return None
  }
  Some((proxy_app_arg(args), provider_id))
}

///|
async fn proxy_missing_provider_id() -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  logger.error("Missing required --provider-id")
}

///|
fn proxy_app_arg(args : Array[String]) -> String {
  match parse_string_arg(args, "--app-type") {
    Some(value) => value
    None => "claude"
  }
}

///|
fn provider_app_arg(args : Array[String]) -> String {
  match parse_string_arg(args, "--app-type") {
    Some(value) => value
    None => "claude"
  }
}

///|
fn provider_id_arg(args : Array[String]) -> String? {
  parse_string_arg(args, "--provider-id")
}

///|
fn provider_app_path(args : Array[String], path : String) -> String {
  "\{path}?appType=\{cli_url_encode(provider_app_arg(args))}"
}

///|
fn provider_id_path(args : Array[String], path : String) -> String? {
  guard provider_id_arg(args) is Some(provider_id) else { return None }
  Some(
    "\{path}?appType=\{cli_url_encode(provider_app_arg(args))}&id=\{cli_url_encode(provider_id)}",
  )
}

///|
fn open_provider_terminal_path(args : Array[String]) -> String? {
  guard provider_id_arg(args) is Some(provider_id) else { return None }
  let query : Array[String] = [
    cli_query_pair("appType", provider_app_arg(args)),
    cli_query_pair("providerId", provider_id),
  ]
  match parse_string_arg(args, "--cwd") {
    Some(cwd) => query.push(cli_query_pair("cwd", cwd))
    None => ()
  }
  Some(cli_path_with_query("/providers/terminal", query))
}

///|
fn provider_live_ids_path(app_type : String) -> String {
  "/providers/live-ids?appType=\{cli_url_encode(app_type)}"
}

///|
fn provider_live_provider_path(
  args : Array[String],
  app_type : String,
) -> String? {
  guard provider_id_arg(args) is Some(provider_id) else { return None }
  Some(
    "/providers/live-provider?appType=\{cli_url_encode(app_type)}&providerId=\{cli_url_encode(provider_id)}",
  )
}

///|
fn provider_import_live_path(app_type : String) -> String {
  "/providers/import-live?appType=\{cli_url_encode(app_type)}"
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
  match parse_string_arg(args, "--provider-type") {
    Some(value) => query.push(cli_query_pair("providerType", value))
    None => ()
  }
  match parse_string_arg(args, "--base-url") {
    Some(value) => query.push(cli_query_pair("baseUrl", value))
    None => ()
  }
  match parse_string_arg(args, "--api-key") {
    Some(value) => query.push(cli_query_pair("apiKey", value))
    None => ()
  }
  match parse_string_arg(args, "--apps") {
    Some(value) => query.push(cli_query_pair("apps", value))
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
  match parse_string_arg(args, "--reasoning-effort") {
    Some(value) => query.push(cli_query_pair("reasoningEffort", value))
    None => ()
  }
  Some("/providers/universal?\{query.join("&")}")
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
  match parse_string_arg(args, "--sort-mode") {
    Some(value) => query.push(cli_query_pair("sortMode", value))
    None => ()
  }
  cli_path_with_query("/providers/presets", query)
}

///|
fn provider_endpoint_url_path(args : Array[String], path : String) -> String? {
  guard provider_id_arg(args) is Some(provider_id) else { return None }
  guard parse_string_arg(args, "--endpoint-url") is Some(endpoint_url) else {
    return None
  }
  Some(
    "\{path}?appType=\{cli_url_encode(provider_app_arg(args))}&providerId=\{cli_url_encode(provider_id)}&url=\{cli_url_encode(endpoint_url)}",
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
  match parse_string_arg(args, "--timeout-secs") {
    Some(value) => query.push(cli_query_pair("timeoutSecs", value))
    None => ()
  }
  Some("/providers/test-endpoints?\{query.join("&")}")
}

///|
fn provider_sort_order_path(args : Array[String]) -> String? {
  guard provider_id_arg(args) is Some(provider_id) else { return None }
  guard parse_string_arg(args, "--sort-index") is Some(sort_index) else {
    return None
  }
  Some(
    "/providers/sort-order?appType=\{cli_url_encode(provider_app_arg(args))}&id=\{cli_url_encode(provider_id)}&sortIndex=\{cli_url_encode(sort_index)}",
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
  if require_original && parse_string_arg(args, "--original-id") is None {
    return None
  }
  let query : Array[String] = [
    cli_query_pair("appType", provider_app_arg(args)),
    cli_query_pair("id", provider_id),
    cli_query_pair("name", name),
  ]
  match parse_string_arg(args, "--original-id") {
    Some(value) => query.push(cli_query_pair("originalId", value))
    None => ()
  }
  match parse_string_arg(args, "--base-url") {
    Some(value) => query.push(cli_query_pair("baseUrl", value))
    None => ()
  }
  match parse_string_arg(args, "--api-key") {
    Some(value) => query.push(cli_query_pair("apiKey", value))
    None => ()
  }
  match parse_string_arg(args, "--provider-type") {
    Some(value) => query.push(cli_query_pair("providerType", value))
    None => ()
  }
  match parse_string_arg(args, "--enabled") {
    Some(value) => query.push(cli_query_pair("enabled", value))
    None => ()
  }
  match parse_string_arg(args, "--add-to-live") {
    Some(value) => query.push(cli_query_pair("addToLive", value))
    None => ()
  }
  Some("\{path}?\{query.join("&")}")
}

///|
fn stream_check_provider_path(args : Array[String]) -> String? {
  let app_type = parse_string_arg(args, "--app-type")
  guard app_type is Some(app_type) else { return None }
  let provider_id = parse_string_arg(args, "--provider-id")
  guard provider_id is Some(provider_id) else { return None }
  Some(
    "/proxy/stream-check/provider?appType=\{cli_url_encode(app_type)}&providerId=\{cli_url_encode(provider_id)}",
  )
}

///|
async fn check_usage_providers(args : Array[String]) -> Unit {
  print_cli_json_result(
    "Usage providers",
    cli_moonstat_client(args).usage_provider_stats(
      query=Some(usage_query(args, app_filter=true)),
    ),
  )
}

///|
async fn stream_check_provider(args : Array[String]) -> Unit {
  guard stream_check_provider_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required stream check args: --provider-id --app-type")
    return
  }
  check_json_post_endpoint(args, path, "Stream check")
}

///|
async fn stream_check_all_providers(args : Array[String]) -> Unit {
  check_json_post_endpoint(args, stream_check_all_path(args), "Stream check")
}

///|
async fn check_usage_provider_script(args : Array[String]) -> Unit {
  guard usage_provider_script_path(args, "/usage/provider-usage", false)
    is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required usage script args: --provider-id --app-type")
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
  guard parse_string_arg(args, "--provider-id") is Some(provider_id) else {
    return None
  }
  let app = parse_string_arg(args, "--app-type")
  guard app is Some(app) else { return None }
  let query = [
    cli_query_pair("providerId", provider_id),
    cli_query_pair("appType", app),
  ]
  if include_script {
    match parse_string_arg(args, "--script-code") {
      Some(value) => query.push(cli_query_pair("scriptCode", value))
      None => ()
    }
  }
  Some("\{path}?\{query.join("&")}")
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
    cli_query_pair("modelId", model_id),
    cli_query_pair("displayName", display_name),
    cli_query_pair("inputCost", input_cost),
    cli_query_pair("outputCost", output_cost),
    cli_query_pair("cacheReadCost", cache_read_cost),
    cli_query_pair("cacheCreationCost", cache_creation_cost),
  ].join("&")
  Some("/usage/model-pricing?\{query}")
}

///|
fn usage_pricing_delete_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--model-id") is Some(model_id) else {
    return None
  }
  Some("/usage/model-pricing?\{cli_query_pair("modelId", model_id)}")
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
    client.request(Delete, path)
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
  let is_full_url = has_flag(args, "--full-url")
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
  let host = parse_string_arg(args, "--host").unwrap_or(@suite.default_host())
  let port = parse_int_arg(args, "--port", default=@suite.default_port())
  let model = parse_string_arg(args, "--model").unwrap_or(
    @suite.default_model(),
  )
  println(
    @moonstat.moonstat_moonclaw_providers_file_json(host~, port~, model~).stringify(
      indent=2,
    ),
  )
}

///|
async fn write_moonclaw_providers_file(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or(@suite.default_host())
  let port = parse_int_arg(args, "--port", default=@suite.default_port())
  let model = parse_string_arg(args, "--model").unwrap_or(
    @suite.default_model(),
  )
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
