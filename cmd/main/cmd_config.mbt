///|
fn config_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "get_app_config_path", patterns: ["config app-path"] },
    { id: "open_app_config_folder", patterns: ["config open-app-folder"] },
    {
      id: "set_claude_common_config_snippet",
      patterns: ["config claude-snippet set"],
    },
    {
      id: "get_claude_common_config_snippet",
      patterns: ["config claude-snippet"],
    },
    { id: "set_common_config_snippet", patterns: ["config snippet set"] },
    { id: "get_common_config_snippet", patterns: ["config snippet"] },
    {
      id: "extract_common_config_snippet",
      patterns: ["config snippet extract"],
    },
    { id: "check_env_conflicts", patterns: ["config env-conflicts"] },
    { id: "delete_env_vars", patterns: ["config env-delete"] },
    { id: "restore_env_backup", patterns: ["config env-restore"] },
    { id: "get_claude_config_status", patterns: ["config claude status"] },
    { id: "get_config_status", patterns: ["config status"] },
    { id: "get_claude_code_config_path", patterns: ["config claude-code path"] },
    { id: "get_config_dir", patterns: ["config dir"] },
    { id: "open_config_folder", patterns: ["config folder open"] },
    { id: "get_settings", patterns: ["settings get"] },
    { id: "save_settings", patterns: ["settings save"] },
    {
      id: "set_app_config_dir_override",
      patterns: ["settings app-config-dir set"],
    },
    { id: "get_app_config_dir_override", patterns: ["settings app-config-dir"] },
    { id: "set_auto_launch", patterns: ["settings auto-launch set"] },
    { id: "get_auto_launch_status", patterns: ["settings auto-launch"] },
    { id: "set_rectifier_config", patterns: ["settings rectifier set"] },
    { id: "get_rectifier_config", patterns: ["settings rectifier"] },
    { id: "set_optimizer_config", patterns: ["settings optimizer set"] },
    { id: "get_optimizer_config", patterns: ["settings optimizer"] },
    {
      id: "set_copilot_optimizer_config",
      patterns: ["settings copilot-optimizer set"],
    },
    {
      id: "get_copilot_optimizer_config",
      patterns: ["settings copilot-optimizer"],
    },
    { id: "set_log_config", patterns: ["settings log set"] },
    { id: "get_log_config", patterns: ["settings log"] },
    { id: "get_claude_plugin_status", patterns: ["plugin claude status"] },
    { id: "read_claude_plugin_config", patterns: ["plugin claude config"] },
    { id: "apply_claude_plugin_config", patterns: ["plugin claude apply"] },
    { id: "is_claude_plugin_applied", patterns: ["plugin claude applied"] },
    {
      id: "apply_claude_onboarding_skip",
      patterns: ["plugin claude onboarding-skip"],
    },
    {
      id: "clear_claude_onboarding_skip",
      patterns: ["plugin claude onboarding-clear"],
    },
    { id: "get_claude_mcp_status", patterns: ["mcp status"] },
    { id: "read_claude_mcp_config", patterns: ["mcp read-config"] },
    { id: "upsert_claude_mcp_server", patterns: ["mcp claude upsert"] },
    { id: "delete_claude_mcp_server", patterns: ["mcp claude delete"] },
    { id: "validate_mcp_command", patterns: ["mcp validate"] },
    { id: "get_mcp_config", patterns: ["mcp config"] },
    { id: "upsert_mcp_server_in_config", patterns: ["mcp upsert-config"] },
    { id: "delete_mcp_server_in_config", patterns: ["mcp delete-config"] },
    { id: "set_mcp_enabled", patterns: ["mcp set-enabled"] },
    { id: "get_mcp_servers", patterns: ["mcp list"] },
    { id: "upsert_mcp_server", patterns: ["mcp upsert"] },
    { id: "delete_mcp_server", patterns: ["mcp delete"] },
    { id: "toggle_mcp_app", patterns: ["mcp toggle"] },
    { id: "import_mcp_from_apps", patterns: ["mcp import"] },
    { id: "get_prompts", patterns: ["prompt list"] },
    { id: "upsert_prompt", patterns: ["prompt upsert"] },
    { id: "delete_prompt", patterns: ["prompt delete"] },
    { id: "enable_prompt", patterns: ["prompt enable"] },
  ]
}

///|
fn cli_config_command_id(command_id : String) -> Bool {
  match command_id {
    "get_app_config_path"
    | "open_app_config_folder"
    | "get_claude_common_config_snippet"
    | "set_claude_common_config_snippet"
    | "get_common_config_snippet"
    | "set_common_config_snippet"
    | "extract_common_config_snippet"
    | "check_env_conflicts"
    | "delete_env_vars"
    | "restore_env_backup"
    | "get_claude_config_status"
    | "get_config_status"
    | "get_claude_code_config_path"
    | "get_config_dir"
    | "open_config_folder"
    | "get_settings"
    | "save_settings"
    | "set_app_config_dir_override"
    | "get_app_config_dir_override"
    | "set_auto_launch"
    | "get_auto_launch_status"
    | "set_rectifier_config"
    | "get_rectifier_config"
    | "set_optimizer_config"
    | "get_optimizer_config"
    | "set_copilot_optimizer_config"
    | "get_copilot_optimizer_config"
    | "set_log_config"
    | "get_log_config"
    | "get_claude_plugin_status"
    | "read_claude_plugin_config"
    | "apply_claude_plugin_config"
    | "is_claude_plugin_applied"
    | "apply_claude_onboarding_skip"
    | "clear_claude_onboarding_skip"
    | "get_claude_mcp_status"
    | "read_claude_mcp_config"
    | "upsert_claude_mcp_server"
    | "delete_claude_mcp_server"
    | "validate_mcp_command"
    | "get_mcp_config"
    | "upsert_mcp_server_in_config"
    | "delete_mcp_server_in_config"
    | "set_mcp_enabled"
    | "get_mcp_servers"
    | "upsert_mcp_server"
    | "delete_mcp_server"
    | "toggle_mcp_app"
    | "import_mcp_from_apps"
    | "get_prompts"
    | "upsert_prompt"
    | "delete_prompt"
    | "enable_prompt" => true
    _ => false
  }
}

///|
async fn run_config_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "get_app_config_path" => check_usage_endpoint(args, "/config/app-path")
    "open_app_config_folder" =>
      check_usage_endpoint(args, "/config/app-folder/open")
    "get_claude_common_config_snippet" =>
      check_usage_endpoint(args, "/config/snippets/claude")
    "set_claude_common_config_snippet" =>
      set_config_snippet(args, "/config/snippets/claude", app_required=false)
    "get_common_config_snippet" =>
      check_usage_endpoint(args, config_app_path(args, "/config/snippets"))
    "set_common_config_snippet" =>
      set_config_snippet(args, "/config/snippets", app_required=true)
    "extract_common_config_snippet" =>
      check_json_post_endpoint(
        args,
        extract_common_config_snippet_path(args),
        "Config",
      )
    "check_env_conflicts" =>
      check_usage_endpoint(args, config_app_path(args, "/config/env/conflicts"))
    "delete_env_vars" => delete_env_vars(args)
    "restore_env_backup" => restore_env_backup(args)
    "get_claude_config_status" =>
      check_usage_endpoint(args, "/config/claude/status")
    "get_config_status" =>
      check_usage_endpoint(args, config_app_path(args, "/config/status"))
    "get_claude_code_config_path" =>
      check_usage_endpoint(args, "/config/claude-code/path")
    "get_config_dir" =>
      check_usage_endpoint(args, config_app_path(args, "/config/dir"))
    "open_config_folder" =>
      check_json_post_endpoint(
        args,
        config_app_path(args, "/config/folder/open"),
        "Config",
      )
    "get_settings" => check_usage_endpoint(args, "/settings")
    "save_settings" => save_settings(args)
    "set_app_config_dir_override" => set_app_config_dir_override(args)
    "get_app_config_dir_override" =>
      check_usage_endpoint(args, "/settings/app-config-dir")
    "set_auto_launch" => set_auto_launch(args)
    "get_auto_launch_status" =>
      check_usage_endpoint(args, "/settings/auto-launch")
    "set_rectifier_config" =>
      set_moon_json_config(args, "/settings/rectifier", "--config", "Settings")
    "get_rectifier_config" => check_usage_endpoint(args, "/settings/rectifier")
    "set_optimizer_config" =>
      set_moon_json_config(args, "/settings/optimizer", "--config", "Settings")
    "get_optimizer_config" => check_usage_endpoint(args, "/settings/optimizer")
    "set_copilot_optimizer_config" =>
      set_moon_json_config(
        args, "/settings/copilot-optimizer", "--config", "Settings",
      )
    "get_copilot_optimizer_config" =>
      check_usage_endpoint(args, "/settings/copilot-optimizer")
    "set_log_config" =>
      set_moon_json_config(args, "/settings/log", "--config", "Settings")
    "get_log_config" => check_usage_endpoint(args, "/settings/log")
    "get_claude_plugin_status" =>
      check_usage_endpoint(args, "/plugin/claude/status")
    "read_claude_plugin_config" =>
      check_usage_endpoint(args, "/plugin/claude/config")
    "apply_claude_plugin_config" => apply_claude_plugin_config(args)
    "is_claude_plugin_applied" =>
      check_usage_endpoint(args, "/plugin/claude/applied")
    "apply_claude_onboarding_skip" =>
      check_json_post_endpoint(args, "/plugin/claude/onboarding-skip", "Plugin")
    "clear_claude_onboarding_skip" =>
      check_json_post_endpoint(
        args, "/plugin/claude/onboarding-skip/clear", "Plugin",
      )
    "get_claude_mcp_status" => check_usage_endpoint(args, "/mcp/claude/status")
    "read_claude_mcp_config" => check_usage_endpoint(args, "/mcp/claude/config")
    "upsert_claude_mcp_server" => upsert_mcp_server(args, "/mcp/claude/servers")
    "delete_claude_mcp_server" => delete_mcp_server(args, "/mcp/claude/servers")
    "validate_mcp_command" =>
      check_usage_endpoint(args, mcp_validate_command_path(args))
    "get_mcp_config" =>
      check_usage_endpoint(args, mcp_app_path(args, "/mcp/config"))
    "upsert_mcp_server_in_config" =>
      upsert_mcp_server(args, "/mcp/config/servers")
    "delete_mcp_server_in_config" =>
      delete_mcp_server(args, "/mcp/config/servers")
    "set_mcp_enabled" => set_mcp_enabled(args)
    "get_mcp_servers" => check_usage_endpoint(args, "/mcp/servers")
    "upsert_mcp_server" => upsert_mcp_server(args, "/mcp/servers")
    "delete_mcp_server" => delete_mcp_server(args, "/mcp/servers")
    "toggle_mcp_app" => toggle_mcp_app(args)
    "import_mcp_from_apps" =>
      check_json_post_endpoint(args, "/mcp/import-apps", "MCP")
    "get_prompts" =>
      check_usage_endpoint(args, prompt_app_path(args, "/prompts"))
    "upsert_prompt" => upsert_prompt(args)
    "delete_prompt" => delete_prompt(args)
    "enable_prompt" => enable_prompt(args)
    _ => ()
  }
}
