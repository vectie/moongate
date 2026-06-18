///|
fn provider_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "get_providers", patterns: ["provider list"] },
    { id: "get_current_provider", patterns: ["provider current"] },
    { id: "add_provider", patterns: ["provider add"] },
    { id: "update_provider", patterns: ["provider update"] },
    { id: "delete_provider", patterns: ["provider delete"] },
    {
      id: "remove_provider_from_live_config",
      patterns: ["provider remove-live"],
    },
    { id: "switch_provider", patterns: ["provider switch"] },
    { id: "sync_current_providers_live", patterns: ["provider sync-live"] },
    { id: "read_live_provider_settings", patterns: ["provider live-settings"] },
    { id: "open_provider_terminal", patterns: ["provider terminal"] },
    { id: "import_default_config", patterns: ["proxy import-default-config"] },
    {
      id: "get_claude_desktop_status",
      patterns: ["providers claude-desktop status"],
    },
    {
      id: "get_claude_desktop_default_routes",
      patterns: ["providers claude-desktop default-routes"],
    },
    {
      id: "import_claude_desktop_providers_from_claude",
      patterns: ["providers claude-desktop import"],
    },
    {
      id: "ensure_claude_desktop_official_provider",
      patterns: ["providers claude-desktop official"],
    },
    { id: "provider_live_ids", patterns: ["provider live-ids"] },
    { id: "provider_live_get", patterns: ["provider live-get"] },
    { id: "provider_import_live", patterns: ["provider import-live"] },
    {
      id: "get_opencode_live_provider_ids",
      patterns: ["provider opencode live-ids"],
    },
    {
      id: "get_openclaw_live_provider_ids",
      patterns: ["provider openclaw live-ids"],
    },
    {
      id: "get_openclaw_live_provider",
      patterns: ["provider openclaw live-get"],
    },
    {
      id: "get_hermes_live_provider_ids",
      patterns: ["provider hermes live-ids"],
    },
    { id: "get_hermes_live_provider", patterns: ["provider hermes live-get"] },
    {
      id: "import_opencode_providers_from_live",
      patterns: ["provider opencode import-live"],
    },
    {
      id: "import_openclaw_providers_from_live",
      patterns: ["provider openclaw import-live"],
    },
    {
      id: "import_hermes_providers_from_live",
      patterns: ["provider hermes import-live"],
    },
    { id: "get_universal_providers", patterns: ["provider universal list"] },
    { id: "get_universal_provider", patterns: ["provider universal get"] },
    { id: "upsert_universal_provider", patterns: ["provider universal upsert"] },
    { id: "delete_universal_provider", patterns: ["provider universal delete"] },
    { id: "sync_universal_provider", patterns: ["provider universal sync"] },
    { id: "get_provider_presets", patterns: ["provider presets list"] },
    { id: "test_api_endpoints", patterns: ["provider test-endpoints"] },
    { id: "update_providers_sort_order", patterns: ["provider sort-order set"] },
    { id: "get_custom_endpoints", patterns: ["provider endpoints list"] },
    { id: "add_custom_endpoint", patterns: ["provider endpoints add"] },
    { id: "remove_custom_endpoint", patterns: ["provider endpoints remove"] },
    { id: "update_endpoint_last_used", patterns: ["provider endpoints touch"] },
    { id: "fetch_models", patterns: ["models fetch"] },
    { id: "model_candidates", patterns: ["models candidates"] },
  ]
}

///|
fn cli_provider_command_id(command_id : String) -> Bool {
  cli_command_id_in_specs(command_id, provider_cli_commands())
}

///|
async fn run_provider_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "get_providers" => check_providers(args)
    "get_current_provider" => check_current_provider(args)
    "add_provider" => add_provider(args)
    "update_provider" => update_provider(args)
    "delete_provider" => delete_provider(args)
    "remove_provider_from_live_config" => remove_provider_from_live_config(args)
    "switch_provider" => switch_provider(args)
    "sync_current_providers_live" => sync_current_providers_live(args)
    "read_live_provider_settings" => check_live_provider_settings(args)
    "open_provider_terminal" => open_provider_terminal(args)
    "import_default_config" => import_default_config(args)
    "get_claude_desktop_status" =>
      check_usage_endpoint(args, "/providers/claude-desktop/status")
    "get_claude_desktop_default_routes" =>
      check_usage_endpoint(args, "/providers/claude-desktop/default-routes")
    "import_claude_desktop_providers_from_claude" =>
      check_json_post_endpoint(
        args, "/providers/claude-desktop/import", "Provider",
      )
    "ensure_claude_desktop_official_provider" =>
      check_json_post_endpoint(
        args, "/providers/claude-desktop/official", "Provider",
      )
    "provider_live_ids" => check_provider_live_ids(args)
    "provider_live_get" => check_provider_live_provider(args)
    "provider_import_live" => import_provider_live(args)
    "get_opencode_live_provider_ids" =>
      check_named_live_provider_ids(args, "opencode")
    "get_openclaw_live_provider_ids" =>
      check_named_live_provider_ids(args, "openclaw")
    "get_openclaw_live_provider" => check_named_live_provider(args, "openclaw")
    "get_hermes_live_provider_ids" =>
      check_named_live_provider_ids(args, "hermes")
    "get_hermes_live_provider" => check_named_live_provider(args, "hermes")
    "import_opencode_providers_from_live" =>
      import_named_live_providers(args, "opencode")
    "import_openclaw_providers_from_live" =>
      import_named_live_providers(args, "openclaw")
    "import_hermes_providers_from_live" =>
      import_named_live_providers(args, "hermes")
    "get_universal_providers" => check_universal_providers(args)
    "get_universal_provider" => check_universal_provider(args)
    "upsert_universal_provider" => upsert_universal_provider(args)
    "delete_universal_provider" => delete_universal_provider(args)
    "sync_universal_provider" => sync_universal_provider(args)
    "get_provider_presets" => check_provider_presets(args)
    "test_api_endpoints" => test_api_endpoints(args)
    "update_providers_sort_order" => update_providers_sort_order(args)
    "get_custom_endpoints" => check_provider_custom_endpoints(args)
    "add_custom_endpoint" => add_provider_custom_endpoint(args)
    "remove_custom_endpoint" => remove_provider_custom_endpoint(args)
    "update_endpoint_last_used" => update_provider_endpoint_last_used(args)
    "fetch_models" => fetch_provider_models(args)
    "model_candidates" => print_model_candidates(args)
    _ => ()
  }
}
