///|
priv struct CliCommandSpec {
  id : String
  patterns : Array[String]
}

///|
fn registered_cli_commands() -> Array[CliCommandSpec] {
  let commands = [
    { id: "start", patterns: ["start"] },
    { id: "install_reroute", patterns: ["install"] },
    { id: "uninstall_reroute", patterns: ["uninstall", "remove"] },
    { id: "install_claude_desktop", patterns: ["claude-desktop install"] },
    {
      id: "uninstall_claude_desktop",
      patterns: ["claude-desktop uninstall", "claude-desktop remove"],
    },
    { id: "status_claude_desktop", patterns: ["claude-desktop status"] },
    { id: "install_codex", patterns: ["codex install"] },
    { id: "uninstall_codex", patterns: ["codex uninstall", "codex remove"] },
    { id: "status_codex", patterns: ["codex status"] },
    { id: "login", patterns: ["login"] },
    { id: "auth_start_login", patterns: ["auth login"] },
    { id: "auth_poll_for_account", patterns: ["auth poll"] },
    { id: "auth_list_accounts", patterns: ["auth accounts"] },
    { id: "auth_get_status", patterns: ["auth status"] },
    { id: "auth_remove_account", patterns: ["auth remove"] },
    { id: "auth_set_default_account", patterns: ["auth default"] },
    { id: "auth_logout", patterns: ["auth logout"] },
    { id: "copilot_start_device_flow", patterns: ["copilot login"] },
    { id: "copilot_poll_for_account", patterns: ["copilot poll"] },
    { id: "copilot_poll_for_auth", patterns: ["copilot auth-poll"] },
    { id: "copilot_list_accounts", patterns: ["copilot accounts"] },
    { id: "copilot_get_auth_status", patterns: ["copilot status"] },
    { id: "copilot_is_authenticated", patterns: ["copilot authenticated"] },
    { id: "copilot_logout", patterns: ["copilot logout"] },
    { id: "copilot_remove_account", patterns: ["copilot remove"] },
    { id: "copilot_set_default_account", patterns: ["copilot default"] },
    { id: "copilot_get_token", patterns: ["copilot token"] },
    { id: "copilot_get_models", patterns: ["copilot models"] },
    { id: "copilot_get_usage", patterns: ["copilot usage"] },
    { id: "stream_check_provider", patterns: ["stream-check provider"] },
    { id: "stream_check_all_providers", patterns: ["stream-check all"] },
    { id: "save_stream_check_config", patterns: ["stream-check config set"] },
    { id: "get_stream_check_config", patterns: ["stream-check config"] },
    { id: "scan_openclaw_config_health", patterns: ["openclaw config-health"] },
    {
      id: "set_openclaw_default_model",
      patterns: ["openclaw default-model set"],
    },
    { id: "get_openclaw_default_model", patterns: ["openclaw default-model"] },
    {
      id: "set_openclaw_model_catalog",
      patterns: ["openclaw model-catalog set"],
    },
    { id: "get_openclaw_model_catalog", patterns: ["openclaw model-catalog"] },
    {
      id: "set_openclaw_agents_defaults",
      patterns: ["openclaw agents-defaults set"],
    },
    {
      id: "get_openclaw_agents_defaults",
      patterns: ["openclaw agents-defaults"],
    },
    { id: "set_openclaw_env", patterns: ["openclaw env set"] },
    { id: "get_openclaw_env", patterns: ["openclaw env"] },
    { id: "set_openclaw_tools", patterns: ["openclaw tools set"] },
    { id: "get_openclaw_tools", patterns: ["openclaw tools"] },
    { id: "get_hermes_model_config", patterns: ["hermes model-config"] },
    { id: "set_hermes_memory", patterns: ["hermes memory set"] },
    { id: "get_hermes_memory", patterns: ["hermes memory"] },
    { id: "get_hermes_memory_limits", patterns: ["hermes memory-limits"] },
    { id: "set_hermes_memory_enabled", patterns: ["hermes memory-enabled set"] },
    { id: "open_hermes_web_ui", patterns: ["hermes web-ui"] },
    { id: "launch_hermes_dashboard", patterns: ["hermes dashboard"] },
    { id: "pick_directory", patterns: ["files directory pick"] },
    { id: "open_external", patterns: ["runtime open-external"] },
    { id: "copy_text_to_clipboard", patterns: ["runtime copy-text"] },
    { id: "check_for_updates", patterns: ["runtime updates check"] },
    { id: "update_tray_menu", patterns: ["runtime tray-menu update"] },
    { id: "is_portable_mode", patterns: ["runtime portable-mode"] },
    { id: "get_init_error", patterns: ["runtime init-error"] },
    { id: "get_migration_result", patterns: ["runtime migration-result"] },
    {
      id: "get_skills_migration_result",
      patterns: ["runtime skills-migration-result"],
    },
    { id: "get_tool_versions", patterns: ["tools versions"] },
    { id: "run_tool_lifecycle_action", patterns: ["tools lifecycle-action"] },
    { id: "probe_tool_installations", patterns: ["tools probe"] },
    { id: "set_window_theme", patterns: ["runtime window-theme set"] },
    { id: "enter_lightweight_mode", patterns: ["runtime lightweight enter"] },
    { id: "exit_lightweight_mode", patterns: ["runtime lightweight exit"] },
    { id: "is_lightweight_mode", patterns: ["runtime lightweight status"] },
    { id: "save_file_dialog", patterns: ["files save-dialog"] },
    { id: "webdav_test_connection", patterns: ["sync webdav test"] },
    { id: "webdav_sync_upload", patterns: ["sync webdav upload"] },
    { id: "webdav_sync_download", patterns: ["sync webdav download"] },
    { id: "webdav_sync_save_settings", patterns: ["sync webdav settings"] },
    {
      id: "webdav_sync_fetch_remote_info",
      patterns: ["sync webdav remote-info"],
    },
    { id: "s3_test_connection", patterns: ["sync s3 test"] },
    { id: "s3_sync_upload", patterns: ["sync s3 upload"] },
    { id: "s3_sync_download", patterns: ["sync s3 download"] },
    { id: "s3_sync_save_settings", patterns: ["sync s3 settings"] },
    { id: "s3_sync_fetch_remote_info", patterns: ["sync s3 remote-info"] },
    { id: "list_sessions", patterns: ["sessions list"] },
    { id: "get_session_messages", patterns: ["sessions messages"] },
    { id: "launch_session_terminal", patterns: ["sessions terminal"] },
    { id: "delete_session", patterns: ["sessions delete"] },
    { id: "delete_sessions", patterns: ["sessions delete-many"] },
    { id: "read_omo_local_file", patterns: ["providers omo file"] },
    { id: "get_current_omo_provider_id", patterns: ["providers omo current"] },
    { id: "disable_current_omo", patterns: ["providers omo disable"] },
    { id: "read_omo_slim_local_file", patterns: ["providers omo-slim file"] },
    {
      id: "get_current_omo_slim_provider_id",
      patterns: ["providers omo-slim current"],
    },
    { id: "disable_current_omo_slim", patterns: ["providers omo-slim disable"] },
    { id: "open_file_dialog", patterns: ["files open-dialog"] },
    { id: "open_zip_file_dialog", patterns: ["files open-zip-dialog"] },
    { id: "export_config_to_file", patterns: ["config file export"] },
    { id: "import_config_from_file", patterns: ["config file import"] },
    { id: "create_db_backup", patterns: ["backups db create"] },
    { id: "list_db_backups", patterns: ["backups db list"] },
    { id: "restore_db_backup", patterns: ["backups db restore"] },
    { id: "rename_db_backup", patterns: ["backups db rename"] },
    { id: "delete_db_backup", patterns: ["backups db delete"] },
    { id: "parse_deeplink", patterns: ["deeplink parse"] },
    { id: "merge_deeplink_config", patterns: ["deeplink merge"] },
    { id: "import_from_deeplink", patterns: ["deeplink import"] },
    { id: "restart_app", patterns: ["runtime restart"] },
    {
      id: "install_update_and_restart",
      patterns: ["runtime updates install-restart"],
    },
    { id: "list_daily_memory_files", patterns: ["workspace memory list"] },
    { id: "read_daily_memory_file", patterns: ["workspace memory read"] },
    { id: "write_daily_memory_file", patterns: ["workspace memory write"] },
    { id: "search_daily_memory_files", patterns: ["workspace memory search"] },
    { id: "delete_daily_memory_file", patterns: ["workspace memory delete"] },
    { id: "read_workspace_file", patterns: ["workspace read"] },
    { id: "write_workspace_file", patterns: ["workspace write"] },
    { id: "open_workspace_directory", patterns: ["workspace open"] },
    {
      id: "import_prompt_from_file",
      patterns: ["prompt import", "prompts import"],
    },
    {
      id: "get_current_prompt_file_content",
      patterns: ["prompt current", "prompts current"],
    },
    { id: "help", patterns: ["help", "--help", "-h"] },
    { id: "version", patterns: ["version", "--version", "-v"] },
  ]
  for command in provider_cli_commands() {
    commands.push(command)
  }
  for command in skill_cli_commands() {
    commands.push(command)
  }
  for command in proxy_cli_commands() {
    commands.push(command)
  }
  for command in config_cli_commands() {
    commands.push(command)
  }
  for command in usage_cli_commands() {
    commands.push(command)
  }
  for command in suite_cli_commands() {
    commands.push(command)
  }
  commands
}

///|
fn cli_args_match_pattern(args : Array[String], pattern : String) -> Bool {
  let tokens = pattern.split(" ").collect()
  if args.length() < tokens.length() + 1 {
    return false
  }
  for index in 0..<tokens.length() {
    if args[index + 1] != tokens[index].to_owned() {
      return false
    }
  }
  if args.length() > tokens.length() + 1 {
    let next = args[tokens.length() + 1]
    if !next.has_prefix("-") {
      return false
    }
  }
  true
}

///|
fn cli_args_match_any_pattern(
  args : Array[String],
  patterns : Array[String],
) -> Bool {
  for pattern in patterns {
    if cli_args_match_pattern(args, pattern) {
      return true
    }
  }
  false
}

///|
fn registered_cli_command_id(args : Array[String]) -> String? {
  for command in registered_cli_commands() {
    if cli_args_match_any_pattern(args, command.patterns) {
      return Some(command.id)
    }
  }
  None
}

///|
async fn run_registered_cli_command(args : Array[String]) -> Bool {
  match registered_cli_command_id(args) {
    Some(command_id) if cli_install_command_id(command_id) => {
      run_install_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_auth_command_id(command_id) => {
      run_auth_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_copilot_command_id(command_id) => {
      run_copilot_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_skill_command_id(command_id) => {
      run_skill_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_config_command_id(command_id) => {
      run_config_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_stream_check_command_id(command_id) => {
      run_stream_check_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_proxy_command_id(command_id) => {
      run_proxy_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_provider_command_id(command_id) => {
      run_provider_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_workspace_command_id(command_id) => {
      run_workspace_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_runtime_command_id(command_id) => {
      run_runtime_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_sync_command_id(command_id) => {
      run_sync_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_session_command_id(command_id) => {
      run_session_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_usage_command_id(command_id) => {
      run_usage_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_suite_command_id(command_id) => {
      run_suite_cli_command(command_id, args)
      true
    }
    Some("help") => {
      print_help()
      true
    }
    Some("version") => {
      println("moonstat v0.1.0")
      true
    }
    _ => false
  }
}
