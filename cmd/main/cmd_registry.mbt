///|
priv struct CliCommandSpec {
  id : String
  patterns : Array[String]
}

///|
fn registered_cli_commands() -> Array[CliCommandSpec] {
  [
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
    { id: "get_installed_skills", patterns: ["skills installed"] },
    { id: "get_skill_backups", patterns: ["skills backups"] },
    { id: "delete_skill_backup", patterns: ["skills backup delete"] },
    { id: "restore_skill_backup", patterns: ["skills backup restore"] },
    { id: "install_skill_unified", patterns: ["skills install-unified"] },
    { id: "uninstall_skill_unified", patterns: ["skills uninstall-unified"] },
    { id: "toggle_skill_app", patterns: ["skills toggle-app"] },
    { id: "scan_unmanaged_skills", patterns: ["skills scan-unmanaged"] },
    { id: "import_skills_from_apps", patterns: ["skills import-apps"] },
    { id: "discover_available_skills", patterns: ["skills discover"] },
    { id: "check_skill_updates", patterns: ["skills check-updates"] },
    { id: "update_skill", patterns: ["skills update"] },
    { id: "migrate_skill_storage", patterns: ["skills migrate-storage"] },
    { id: "search_skills_sh", patterns: ["skills search"] },
    { id: "get_skills", patterns: ["skills list"] },
    { id: "get_skills_for_app", patterns: ["skills app"] },
    { id: "get_skill_repos", patterns: ["skills repos"] },
    { id: "add_skill_repo", patterns: ["skills repo add"] },
    { id: "remove_skill_repo", patterns: ["skills repo remove"] },
    { id: "install_skills_from_zip", patterns: ["skills install-zip"] },
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
    { id: "stream_check_provider", patterns: ["stream-check provider"] },
    { id: "stream_check_all_providers", patterns: ["stream-check all"] },
    { id: "save_stream_check_config", patterns: ["stream-check config set"] },
    { id: "get_stream_check_config", patterns: ["stream-check config"] },
    { id: "update_proxy_config", patterns: ["proxy config set"] },
    { id: "get_proxy_config", patterns: ["proxy config"] },
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
    { id: "is_proxy_running", patterns: ["proxy running"] },
    { id: "get_providers", patterns: ["provider list", "providers list"] },
    {
      id: "get_current_provider",
      patterns: ["provider current", "providers current"],
    },
    { id: "add_provider", patterns: ["provider add", "providers add"] },
    { id: "update_provider", patterns: ["provider update", "providers update"] },
    { id: "delete_provider", patterns: ["provider delete", "providers delete"] },
    {
      id: "remove_provider_from_live_config",
      patterns: ["provider remove-live", "providers remove-live"],
    },
    { id: "switch_provider", patterns: ["provider switch", "providers switch"] },
    {
      id: "sync_current_providers_live",
      patterns: ["provider sync-live", "providers sync-live"],
    },
    {
      id: "read_live_provider_settings",
      patterns: ["provider live-settings", "providers live-settings"],
    },
    {
      id: "open_provider_terminal",
      patterns: ["provider terminal", "providers terminal"],
    },
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
    {
      id: "provider_live_ids",
      patterns: ["provider live-ids", "providers live-ids"],
    },
    {
      id: "provider_live_get",
      patterns: ["provider live-get", "providers live-get"],
    },
    {
      id: "provider_import_live",
      patterns: ["provider import-live", "providers import-live"],
    },
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
    {
      id: "get_universal_providers",
      patterns: ["provider universal list", "providers universal list"],
    },
    {
      id: "get_universal_provider",
      patterns: ["provider universal get", "providers universal get"],
    },
    {
      id: "upsert_universal_provider",
      patterns: ["provider universal upsert", "providers universal upsert"],
    },
    {
      id: "delete_universal_provider",
      patterns: ["provider universal delete", "providers universal delete"],
    },
    {
      id: "sync_universal_provider",
      patterns: ["provider universal sync", "providers universal sync"],
    },
    {
      id: "get_provider_presets",
      patterns: ["provider presets list", "providers presets list"],
    },
    {
      id: "test_api_endpoints",
      patterns: ["provider test-endpoints", "providers test-endpoints"],
    },
    {
      id: "update_providers_sort_order",
      patterns: ["provider sort-order set", "providers sort-order set"],
    },
    {
      id: "get_custom_endpoints",
      patterns: ["provider endpoints list", "providers endpoints list"],
    },
    {
      id: "add_custom_endpoint",
      patterns: ["provider endpoints add", "providers endpoints add"],
    },
    {
      id: "remove_custom_endpoint",
      patterns: ["provider endpoints remove", "providers endpoints remove"],
    },
    {
      id: "update_endpoint_last_used",
      patterns: ["provider endpoints touch", "providers endpoints touch"],
    },
    { id: "fetch_models", patterns: ["models fetch"] },
    { id: "model_candidates", patterns: ["models candidates"] },
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
    { id: "get_claude_config_status", patterns: ["config claude status"] },
    { id: "get_config_status", patterns: ["config status"] },
    { id: "get_claude_code_config_path", patterns: ["config claude-code path"] },
    { id: "get_config_dir", patterns: ["config dir"] },
    { id: "open_config_folder", patterns: ["config folder open"] },
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
    { id: "get_settings", patterns: ["settings get"] },
    { id: "save_settings", patterns: ["settings save"] },
    { id: "restart_app", patterns: ["runtime restart"] },
    {
      id: "install_update_and_restart",
      patterns: ["runtime updates install-restart"],
    },
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
    { id: "list_daily_memory_files", patterns: ["workspace memory list"] },
    { id: "read_daily_memory_file", patterns: ["workspace memory read"] },
    { id: "write_daily_memory_file", patterns: ["workspace memory write"] },
    { id: "search_daily_memory_files", patterns: ["workspace memory search"] },
    { id: "delete_daily_memory_file", patterns: ["workspace memory delete"] },
    { id: "read_workspace_file", patterns: ["workspace read"] },
    { id: "write_workspace_file", patterns: ["workspace write"] },
    { id: "open_workspace_directory", patterns: ["workspace open"] },
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
    { id: "get_prompts", patterns: ["prompt list", "prompts list"] },
    { id: "upsert_prompt", patterns: ["prompt upsert", "prompts upsert"] },
    { id: "delete_prompt", patterns: ["prompt delete", "prompts delete"] },
    { id: "enable_prompt", patterns: ["prompt enable", "prompts enable"] },
    {
      id: "import_prompt_from_file",
      patterns: ["prompt import", "prompts import"],
    },
    {
      id: "get_current_prompt_file_content",
      patterns: ["prompt current", "prompts current"],
    },
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
    { id: "query_provider_usage", patterns: ["usage query-provider-usage"] },
    { id: "get_balance", patterns: ["usage balance"] },
    { id: "get_subscription_quota", patterns: ["usage quota"] },
    { id: "get_codex_oauth_quota", patterns: ["usage codex-oauth-quota"] },
    { id: "get_codex_oauth_models", patterns: ["usage codex-oauth-models"] },
    { id: "get_coding_plan_quota", patterns: ["usage coding-plan"] },
    { id: "test_usage_script", patterns: ["usage test-usage-script"] },
    { id: "suite_manifest", patterns: ["suite manifest"] },
    { id: "suite_status", patterns: ["suite status"] },
    { id: "suite_write_status", patterns: ["suite write-status"] },
    {
      id: "suite_moonclaw_providers",
      patterns: ["suite moonclaw-providers", "suite provider-manifest"],
    },
    {
      id: "suite_write_moonclaw_providers",
      patterns: [
        "suite write-moonclaw-providers", "suite write-provider-manifest",
      ],
    },
    { id: "status", patterns: ["status"] },
    { id: "health", patterns: ["health"] },
    { id: "stats", patterns: ["stats"] },
    { id: "help", patterns: ["help", "--help", "-h"] },
    { id: "version", patterns: ["version", "--version", "-v"] },
  ]
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
    Some("start") => {
      start_gateway(args)
      true
    }
    Some("install_reroute") => {
      install_reroute(args)
      true
    }
    Some("uninstall_reroute") => {
      uninstall_reroute()
      true
    }
    Some("install_claude_desktop") => {
      install_claude_desktop(args)
      true
    }
    Some("uninstall_claude_desktop") => {
      uninstall_claude_desktop()
      true
    }
    Some("status_claude_desktop") => {
      status_claude_desktop()
      true
    }
    Some("install_codex") => {
      install_codex(args)
      true
    }
    Some("uninstall_codex") => {
      uninstall_codex()
      true
    }
    Some("status_codex") => {
      status_codex()
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
    Some("stream_check_provider") => {
      stream_check_provider(args)
      true
    }
    Some("stream_check_all_providers") => {
      stream_check_all_providers(args)
      true
    }
    Some("get_stream_check_config") => {
      check_usage_endpoint(args, "/proxy/stream-check/config")
      true
    }
    Some("save_stream_check_config") => {
      save_stream_check_config(args)
      true
    }
    Some(command_id) if cli_proxy_command_id(command_id) => {
      run_proxy_cli_command(command_id, args)
      true
    }
    Some("get_providers") => {
      check_providers(args)
      true
    }
    Some("get_current_provider") => {
      check_current_provider(args)
      true
    }
    Some("add_provider") => {
      add_provider(args)
      true
    }
    Some("update_provider") => {
      update_provider(args)
      true
    }
    Some("delete_provider") => {
      delete_provider(args)
      true
    }
    Some("remove_provider_from_live_config") => {
      remove_provider_from_live_config(args)
      true
    }
    Some("switch_provider") => {
      switch_provider(args)
      true
    }
    Some("sync_current_providers_live") => {
      sync_current_providers_live(args)
      true
    }
    Some("read_live_provider_settings") => {
      check_live_provider_settings(args)
      true
    }
    Some("open_provider_terminal") => {
      open_provider_terminal(args)
      true
    }
    Some("import_default_config") => {
      import_default_config(args)
      true
    }
    Some("get_claude_desktop_status") => {
      check_usage_endpoint(args, "/providers/claude-desktop/status")
      true
    }
    Some("get_claude_desktop_default_routes") => {
      check_usage_endpoint(args, "/providers/claude-desktop/default-routes")
      true
    }
    Some("import_claude_desktop_providers_from_claude") => {
      check_json_post_endpoint(
        args, "/providers/claude-desktop/import", "Provider",
      )
      true
    }
    Some("ensure_claude_desktop_official_provider") => {
      check_json_post_endpoint(
        args, "/providers/claude-desktop/official", "Provider",
      )
      true
    }
    Some("provider_live_ids") => {
      check_provider_live_ids(args)
      true
    }
    Some("provider_live_get") => {
      check_provider_live_provider(args)
      true
    }
    Some("provider_import_live") => {
      import_provider_live(args)
      true
    }
    Some("get_opencode_live_provider_ids") => {
      check_named_live_provider_ids(args, "opencode")
      true
    }
    Some("get_openclaw_live_provider_ids") => {
      check_named_live_provider_ids(args, "openclaw")
      true
    }
    Some("get_openclaw_live_provider") => {
      check_named_live_provider(args, "openclaw")
      true
    }
    Some("get_hermes_live_provider_ids") => {
      check_named_live_provider_ids(args, "hermes")
      true
    }
    Some("get_hermes_live_provider") => {
      check_named_live_provider(args, "hermes")
      true
    }
    Some("import_opencode_providers_from_live") => {
      import_named_live_providers(args, "opencode")
      true
    }
    Some("import_openclaw_providers_from_live") => {
      import_named_live_providers(args, "openclaw")
      true
    }
    Some("import_hermes_providers_from_live") => {
      import_named_live_providers(args, "hermes")
      true
    }
    Some("get_universal_providers") => {
      check_universal_providers(args)
      true
    }
    Some("get_universal_provider") => {
      check_universal_provider(args)
      true
    }
    Some("upsert_universal_provider") => {
      upsert_universal_provider(args)
      true
    }
    Some("delete_universal_provider") => {
      delete_universal_provider(args)
      true
    }
    Some("sync_universal_provider") => {
      sync_universal_provider(args)
      true
    }
    Some("get_provider_presets") => {
      check_provider_presets(args)
      true
    }
    Some("test_api_endpoints") => {
      test_api_endpoints(args)
      true
    }
    Some("update_providers_sort_order") => {
      update_providers_sort_order(args)
      true
    }
    Some("get_custom_endpoints") => {
      check_provider_custom_endpoints(args)
      true
    }
    Some("add_custom_endpoint") => {
      add_provider_custom_endpoint(args)
      true
    }
    Some("remove_custom_endpoint") => {
      remove_provider_custom_endpoint(args)
      true
    }
    Some("update_endpoint_last_used") => {
      update_provider_endpoint_last_used(args)
      true
    }
    Some("fetch_models") => {
      fetch_provider_models(args)
      true
    }
    Some("model_candidates") => {
      print_model_candidates(args)
      true
    }
    Some(command_id) if cli_workspace_command_id(command_id) => {
      run_workspace_cli_command(command_id, args)
      true
    }
    Some("pick_directory") => {
      check_usage_endpoint(args, pick_directory_path(args))
      true
    }
    Some("open_external") => {
      check_usage_endpoint(args, open_external_path(args))
      true
    }
    Some("copy_text_to_clipboard") => {
      check_usage_endpoint(args, copy_text_to_clipboard_path(args))
      true
    }
    Some("check_for_updates") => {
      check_json_post_endpoint(args, "/runtime/updates/check", "App shell")
      true
    }
    Some("update_tray_menu") => {
      check_json_post_endpoint(args, "/runtime/tray-menu/update", "App shell")
      true
    }
    Some("is_portable_mode") => {
      check_usage_endpoint(args, "/runtime/portable-mode")
      true
    }
    Some("get_init_error") => {
      check_usage_endpoint(args, "/runtime/init-error")
      true
    }
    Some("get_migration_result") => {
      check_usage_endpoint(args, "/runtime/migration-result")
      true
    }
    Some("get_skills_migration_result") => {
      check_usage_endpoint(args, "/runtime/skills-migration-result")
      true
    }
    Some("get_tool_versions") => {
      check_usage_endpoint(args, tool_versions_path(args))
      true
    }
    Some("run_tool_lifecycle_action") => {
      run_tool_lifecycle_action(args)
      true
    }
    Some("probe_tool_installations") => {
      check_usage_endpoint(args, tool_installations_path(args))
      true
    }
    Some("set_window_theme") => {
      check_usage_endpoint(args, window_theme_path(args))
      true
    }
    Some("enter_lightweight_mode") => {
      check_json_post_endpoint(
        args, "/runtime/lightweight-mode/enter", "App shell",
      )
      true
    }
    Some("exit_lightweight_mode") => {
      check_json_post_endpoint(
        args, "/runtime/lightweight-mode/exit", "App shell",
      )
      true
    }
    Some("is_lightweight_mode") => {
      check_usage_endpoint(args, "/runtime/lightweight-mode")
      true
    }
    Some("webdav_test_connection") => {
      check_json_post_endpoint(
        args,
        sync_settings_path(args, "/sync/webdav/test"),
        "Sync",
      )
      true
    }
    Some("webdav_sync_upload") => {
      check_json_post_endpoint(args, "/sync/webdav/upload", "Sync")
      true
    }
    Some("webdav_sync_download") => {
      check_json_post_endpoint(args, "/sync/webdav/download", "Sync")
      true
    }
    Some("webdav_sync_save_settings") => {
      check_json_post_endpoint(
        args,
        sync_settings_path(args, "/sync/webdav/settings"),
        "Sync",
      )
      true
    }
    Some("webdav_sync_fetch_remote_info") => {
      check_usage_endpoint(args, "/sync/webdav/remote-info")
      true
    }
    Some("s3_test_connection") => {
      check_json_post_endpoint(
        args,
        sync_settings_path(args, "/sync/s3/test"),
        "Sync",
      )
      true
    }
    Some("s3_sync_upload") => {
      check_json_post_endpoint(args, "/sync/s3/upload", "Sync")
      true
    }
    Some("s3_sync_download") => {
      check_json_post_endpoint(args, "/sync/s3/download", "Sync")
      true
    }
    Some("s3_sync_save_settings") => {
      check_json_post_endpoint(
        args,
        sync_settings_path(args, "/sync/s3/settings"),
        "Sync",
      )
      true
    }
    Some("s3_sync_fetch_remote_info") => {
      check_usage_endpoint(args, "/sync/s3/remote-info")
      true
    }
    Some("list_sessions") => {
      check_usage_endpoint(args, "/sessions")
      true
    }
    Some("get_session_messages") => {
      check_usage_endpoint(args, session_messages_path(args))
      true
    }
    Some("launch_session_terminal") => {
      check_json_post_endpoint(
        args,
        launch_session_terminal_path(args),
        "Session",
      )
      true
    }
    Some("delete_session") => {
      check_json_post_endpoint(args, delete_session_path(args), "Session")
      true
    }
    Some("delete_sessions") => {
      delete_sessions(args)
      true
    }
    Some("read_omo_local_file") => {
      check_usage_endpoint(args, "/providers/omo/file")
      true
    }
    Some("get_current_omo_provider_id") => {
      check_usage_endpoint(args, "/providers/omo/current")
      true
    }
    Some("disable_current_omo") => {
      check_json_post_endpoint(args, "/providers/omo/disable", "OMO")
      true
    }
    Some("read_omo_slim_local_file") => {
      check_usage_endpoint(args, "/providers/omo-slim/file")
      true
    }
    Some("get_current_omo_slim_provider_id") => {
      check_usage_endpoint(args, "/providers/omo-slim/current")
      true
    }
    Some("disable_current_omo_slim") => {
      check_json_post_endpoint(args, "/providers/omo-slim/disable", "OMO")
      true
    }
    Some("restart_app") => {
      check_json_post_endpoint(args, "/runtime/restart", "Settings")
      true
    }
    Some("install_update_and_restart") => {
      check_json_post_endpoint(
        args, "/runtime/updates/install-restart", "Settings",
      )
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
