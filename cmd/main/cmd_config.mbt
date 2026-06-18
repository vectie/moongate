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
      check_usage_endpoint(args, extract_common_config_snippet_path(args))
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
      check_usage_endpoint(args, config_app_path(args, "/config/folder/open"))
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
