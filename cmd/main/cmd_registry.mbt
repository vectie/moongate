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
    { id: "install_skill_for_app", patterns: ["skills install-for-app"] },
    { id: "install_skill", patterns: ["skills install"] },
    { id: "uninstall_skill_for_app", patterns: ["skills uninstall-for-app"] },
    { id: "uninstall_skill", patterns: ["skills uninstall"] },
    { id: "get_skill_repos", patterns: ["skills repos"] },
    { id: "add_skill_repo", patterns: ["skills repo add"] },
    { id: "remove_skill_repo", patterns: ["skills repo remove"] },
    { id: "install_skills_from_zip", patterns: ["skills install-zip"] },
    {
      id: "get_app_config_path",
      patterns: [
        "config app-path", "get_app_config_path", "get-app-config-path",
      ],
    },
    {
      id: "open_app_config_folder",
      patterns: [
        "config open-app-folder", "open_app_config_folder", "open-app-config-folder",
      ],
    },
    {
      id: "set_claude_common_config_snippet",
      patterns: [
        "config claude-snippet set", "set_claude_common_config_snippet", "set-claude-common-config-snippet",
      ],
    },
    {
      id: "get_claude_common_config_snippet",
      patterns: [
        "config claude-snippet", "get_claude_common_config_snippet", "get-claude-common-config-snippet",
      ],
    },
    {
      id: "set_common_config_snippet",
      patterns: [
        "config snippet set", "set_common_config_snippet", "set-common-config-snippet",
      ],
    },
    {
      id: "get_common_config_snippet",
      patterns: [
        "config snippet", "get_common_config_snippet", "get-common-config-snippet",
      ],
    },
    {
      id: "extract_common_config_snippet",
      patterns: [
        "config snippet extract", "extract_common_config_snippet", "extract-common-config-snippet",
      ],
    },
    {
      id: "check_env_conflicts",
      patterns: [
        "config env-conflicts", "check_env_conflicts", "check-env-conflicts",
      ],
    },
    {
      id: "delete_env_vars",
      patterns: ["config env-delete", "delete_env_vars", "delete-env-vars"],
    },
    {
      id: "restore_env_backup",
      patterns: [
        "config env-restore", "restore_env_backup", "restore-env-backup",
      ],
    },
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
      patterns: ["get_claude_desktop_status", "get-claude-desktop-status"],
    },
    {
      id: "get_claude_desktop_default_routes",
      patterns: [
        "get_claude_desktop_default_routes", "get-claude-desktop-default-routes",
      ],
    },
    {
      id: "import_claude_desktop_providers_from_claude",
      patterns: [
        "import_claude_desktop_providers_from_claude", "import-claude-desktop-providers-from-claude",
      ],
    },
    {
      id: "ensure_claude_desktop_official_provider",
      patterns: [
        "ensure_claude_desktop_official_provider", "ensure-claude-desktop-official-provider",
      ],
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
    {
      id: "fetch_models",
      patterns: [
        "models fetch", "fetch_models_for_config", "fetch-models-for-config",
      ],
    },
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
    {
      id: "get_claude_config_status",
      patterns: ["get_claude_config_status", "get-claude-config-status"],
    },
    {
      id: "get_config_status",
      patterns: ["get_config_status", "get-config-status"],
    },
    {
      id: "get_claude_code_config_path",
      patterns: ["get_claude_code_config_path", "get-claude-code-config-path"],
    },
    { id: "get_config_dir", patterns: ["get_config_dir", "get-config-dir"] },
    {
      id: "open_config_folder",
      patterns: ["open_config_folder", "open-config-folder"],
    },
    { id: "pick_directory", patterns: ["pick_directory", "pick-directory"] },
    { id: "open_external", patterns: ["open_external", "open-external"] },
    {
      id: "copy_text_to_clipboard",
      patterns: ["copy_text_to_clipboard", "copy-text-to-clipboard"],
    },
    {
      id: "check_for_updates",
      patterns: ["check_for_updates", "check-for-updates"],
    },
    {
      id: "update_tray_menu",
      patterns: ["update_tray_menu", "update-tray-menu"],
    },
    {
      id: "is_portable_mode",
      patterns: ["is_portable_mode", "is-portable-mode"],
    },
    { id: "get_init_error", patterns: ["get_init_error", "get-init-error"] },
    {
      id: "get_migration_result",
      patterns: ["get_migration_result", "get-migration-result"],
    },
    {
      id: "get_skills_migration_result",
      patterns: ["get_skills_migration_result", "get-skills-migration-result"],
    },
    {
      id: "get_tool_versions",
      patterns: ["get_tool_versions", "get-tool-versions"],
    },
    {
      id: "run_tool_lifecycle_action",
      patterns: ["run_tool_lifecycle_action", "run-tool-lifecycle-action"],
    },
    {
      id: "probe_tool_installations",
      patterns: ["probe_tool_installations", "probe-tool-installations"],
    },
    {
      id: "set_window_theme",
      patterns: ["set_window_theme", "set-window-theme"],
    },
    {
      id: "enter_lightweight_mode",
      patterns: ["enter_lightweight_mode", "enter-lightweight-mode"],
    },
    {
      id: "exit_lightweight_mode",
      patterns: ["exit_lightweight_mode", "exit-lightweight-mode"],
    },
    {
      id: "is_lightweight_mode",
      patterns: ["is_lightweight_mode", "is-lightweight-mode"],
    },
    {
      id: "save_file_dialog",
      patterns: ["save_file_dialog", "save-file-dialog"],
    },
    {
      id: "webdav_test_connection",
      patterns: ["webdav_test_connection", "webdav-test-connection"],
    },
    {
      id: "webdav_sync_upload",
      patterns: ["webdav_sync_upload", "webdav-sync-upload"],
    },
    {
      id: "webdav_sync_download",
      patterns: ["webdav_sync_download", "webdav-sync-download"],
    },
    {
      id: "webdav_sync_save_settings",
      patterns: ["webdav_sync_save_settings", "webdav-sync-save-settings"],
    },
    {
      id: "webdav_sync_fetch_remote_info",
      patterns: [
        "webdav_sync_fetch_remote_info", "webdav-sync-fetch-remote-info",
      ],
    },
    {
      id: "s3_test_connection",
      patterns: ["s3_test_connection", "s3-test-connection"],
    },
    { id: "s3_sync_upload", patterns: ["s3_sync_upload", "s3-sync-upload"] },
    {
      id: "s3_sync_download",
      patterns: ["s3_sync_download", "s3-sync-download"],
    },
    {
      id: "s3_sync_save_settings",
      patterns: ["s3_sync_save_settings", "s3-sync-save-settings"],
    },
    {
      id: "s3_sync_fetch_remote_info",
      patterns: ["s3_sync_fetch_remote_info", "s3-sync-fetch-remote-info"],
    },
    { id: "list_sessions", patterns: ["list_sessions", "list-sessions"] },
    {
      id: "get_session_messages",
      patterns: ["get_session_messages", "get-session-messages"],
    },
    {
      id: "launch_session_terminal",
      patterns: ["launch_session_terminal", "launch-session-terminal"],
    },
    { id: "delete_session", patterns: ["delete_session", "delete-session"] },
    { id: "delete_sessions", patterns: ["delete_sessions", "delete-sessions"] },
    {
      id: "read_omo_local_file",
      patterns: ["read_omo_local_file", "read-omo-local-file"],
    },
    {
      id: "get_current_omo_provider_id",
      patterns: ["get_current_omo_provider_id", "get-current-omo-provider-id"],
    },
    {
      id: "disable_current_omo",
      patterns: ["disable_current_omo", "disable-current-omo"],
    },
    {
      id: "read_omo_slim_local_file",
      patterns: ["read_omo_slim_local_file", "read-omo-slim-local-file"],
    },
    {
      id: "get_current_omo_slim_provider_id",
      patterns: [
        "get_current_omo_slim_provider_id", "get-current-omo-slim-provider-id",
      ],
    },
    {
      id: "disable_current_omo_slim",
      patterns: ["disable_current_omo_slim", "disable-current-omo-slim"],
    },
    {
      id: "open_file_dialog",
      patterns: ["open_file_dialog", "open-file-dialog"],
    },
    {
      id: "open_zip_file_dialog",
      patterns: ["open_zip_file_dialog", "open-zip-file-dialog"],
    },
    {
      id: "export_config_to_file",
      patterns: ["export_config_to_file", "export-config-to-file"],
    },
    {
      id: "import_config_from_file",
      patterns: ["import_config_from_file", "import-config-from-file"],
    },
    {
      id: "create_db_backup",
      patterns: ["create_db_backup", "create-db-backup"],
    },
    { id: "list_db_backups", patterns: ["list_db_backups", "list-db-backups"] },
    {
      id: "restore_db_backup",
      patterns: ["restore_db_backup", "restore-db-backup"],
    },
    {
      id: "rename_db_backup",
      patterns: ["rename_db_backup", "rename-db-backup"],
    },
    {
      id: "delete_db_backup",
      patterns: ["delete_db_backup", "delete-db-backup"],
    },
    { id: "parse_deeplink", patterns: ["parse_deeplink", "parse-deeplink"] },
    {
      id: "merge_deeplink_config",
      patterns: ["merge_deeplink_config", "merge-deeplink-config"],
    },
    {
      id: "import_from_deeplink",
      patterns: ["import_from_deeplink", "import-from-deeplink"],
    },
    {
      id: "import_from_deeplink_unified",
      patterns: ["import_from_deeplink_unified", "import-from-deeplink-unified"],
    },
    {
      id: "get_settings",
      patterns: ["settings get", "get_settings", "get-settings"],
    },
    {
      id: "save_settings",
      patterns: ["settings save", "save_settings", "save-settings"],
    },
    { id: "restart_app", patterns: ["restart_app", "restart-app"] },
    {
      id: "install_update_and_restart",
      patterns: ["install_update_and_restart", "install-update-and-restart"],
    },
    {
      id: "set_app_config_dir_override",
      patterns: [
        "settings app-config-dir set", "set_app_config_dir_override", "set-app-config-dir-override",
      ],
    },
    {
      id: "get_app_config_dir_override",
      patterns: [
        "settings app-config-dir", "get_app_config_dir_override", "get-app-config-dir-override",
      ],
    },
    {
      id: "set_auto_launch",
      patterns: [
        "settings auto-launch set", "set_auto_launch", "set-auto-launch",
      ],
    },
    {
      id: "get_auto_launch_status",
      patterns: [
        "settings auto-launch", "get_auto_launch_status", "get-auto-launch-status",
      ],
    },
    {
      id: "set_rectifier_config",
      patterns: [
        "settings rectifier set", "set_rectifier_config", "set-rectifier-config",
      ],
    },
    {
      id: "get_rectifier_config",
      patterns: [
        "settings rectifier", "get_rectifier_config", "get-rectifier-config",
      ],
    },
    {
      id: "set_optimizer_config",
      patterns: [
        "settings optimizer set", "set_optimizer_config", "set-optimizer-config",
      ],
    },
    {
      id: "get_optimizer_config",
      patterns: [
        "settings optimizer", "get_optimizer_config", "get-optimizer-config",
      ],
    },
    {
      id: "set_copilot_optimizer_config",
      patterns: [
        "settings copilot-optimizer set", "set_copilot_optimizer_config", "set-copilot-optimizer-config",
      ],
    },
    {
      id: "get_copilot_optimizer_config",
      patterns: [
        "settings copilot-optimizer", "get_copilot_optimizer_config", "get-copilot-optimizer-config",
      ],
    },
    {
      id: "set_log_config",
      patterns: ["settings log set", "set_log_config", "set-log-config"],
    },
    {
      id: "get_log_config",
      patterns: ["settings log", "get_log_config", "get-log-config"],
    },
    {
      id: "get_claude_plugin_status",
      patterns: [
        "plugin claude status", "get_claude_plugin_status", "get-claude-plugin-status",
      ],
    },
    {
      id: "read_claude_plugin_config",
      patterns: [
        "plugin claude config", "read_claude_plugin_config", "read-claude-plugin-config",
      ],
    },
    {
      id: "apply_claude_plugin_config",
      patterns: [
        "plugin claude apply", "apply_claude_plugin_config", "apply-claude-plugin-config",
      ],
    },
    {
      id: "is_claude_plugin_applied",
      patterns: [
        "plugin claude applied", "is_claude_plugin_applied", "is-claude-plugin-applied",
      ],
    },
    {
      id: "apply_claude_onboarding_skip",
      patterns: [
        "plugin claude onboarding-skip", "apply_claude_onboarding_skip", "apply-claude-onboarding-skip",
      ],
    },
    {
      id: "clear_claude_onboarding_skip",
      patterns: [
        "plugin claude onboarding-clear", "clear_claude_onboarding_skip", "clear-claude-onboarding-skip",
      ],
    },
    {
      id: "list_daily_memory_files",
      patterns: [
        "workspace memory list", "list_daily_memory_files", "list-daily-memory-files",
      ],
    },
    {
      id: "read_daily_memory_file",
      patterns: [
        "workspace memory read", "read_daily_memory_file", "read-daily-memory-file",
      ],
    },
    {
      id: "write_daily_memory_file",
      patterns: [
        "workspace memory write", "write_daily_memory_file", "write-daily-memory-file",
      ],
    },
    {
      id: "search_daily_memory_files",
      patterns: [
        "workspace memory search", "search_daily_memory_files", "search-daily-memory-files",
      ],
    },
    {
      id: "delete_daily_memory_file",
      patterns: [
        "workspace memory delete", "delete_daily_memory_file", "delete-daily-memory-file",
      ],
    },
    {
      id: "read_workspace_file",
      patterns: ["workspace read", "read_workspace_file", "read-workspace-file"],
    },
    {
      id: "write_workspace_file",
      patterns: [
        "workspace write", "write_workspace_file", "write-workspace-file",
      ],
    },
    {
      id: "open_workspace_directory",
      patterns: [
        "workspace open", "open_workspace_directory", "open-workspace-directory",
      ],
    },
    {
      id: "get_claude_mcp_status",
      patterns: ["mcp status", "get_claude_mcp_status", "get-claude-mcp-status"],
    },
    {
      id: "read_claude_mcp_config",
      patterns: [
        "mcp read-config", "read_claude_mcp_config", "read-claude-mcp-config",
      ],
    },
    {
      id: "upsert_claude_mcp_server",
      patterns: ["upsert_claude_mcp_server", "upsert-claude-mcp-server"],
    },
    {
      id: "delete_claude_mcp_server",
      patterns: ["delete_claude_mcp_server", "delete-claude-mcp-server"],
    },
    {
      id: "validate_mcp_command",
      patterns: ["mcp validate", "validate_mcp_command", "validate-mcp-command"],
    },
    {
      id: "get_mcp_config",
      patterns: ["mcp config", "get_mcp_config", "get-mcp-config"],
    },
    {
      id: "upsert_mcp_server_in_config",
      patterns: [
        "mcp upsert-config", "upsert_mcp_server_in_config", "upsert-mcp-server-in-config",
      ],
    },
    {
      id: "delete_mcp_server_in_config",
      patterns: [
        "mcp delete-config", "delete_mcp_server_in_config", "delete-mcp-server-in-config",
      ],
    },
    {
      id: "set_mcp_enabled",
      patterns: ["mcp set-enabled", "set_mcp_enabled", "set-mcp-enabled"],
    },
    {
      id: "get_mcp_servers",
      patterns: ["mcp list", "get_mcp_servers", "get-mcp-servers"],
    },
    {
      id: "upsert_mcp_server",
      patterns: ["mcp upsert", "upsert_mcp_server", "upsert-mcp-server"],
    },
    {
      id: "delete_mcp_server",
      patterns: ["mcp delete", "delete_mcp_server", "delete-mcp-server"],
    },
    {
      id: "toggle_mcp_app",
      patterns: ["mcp toggle", "toggle_mcp_app", "toggle-mcp-app"],
    },
    {
      id: "import_mcp_from_apps",
      patterns: ["mcp import", "import_mcp_from_apps", "import-mcp-from-apps"],
    },
    {
      id: "get_prompts",
      patterns: ["prompt list", "prompts list", "get_prompts", "get-prompts"],
    },
    {
      id: "upsert_prompt",
      patterns: [
        "prompt upsert", "prompts upsert", "upsert_prompt", "upsert-prompt",
      ],
    },
    {
      id: "delete_prompt",
      patterns: [
        "prompt delete", "prompts delete", "delete_prompt", "delete-prompt",
      ],
    },
    {
      id: "enable_prompt",
      patterns: [
        "prompt enable", "prompts enable", "enable_prompt", "enable-prompt",
      ],
    },
    {
      id: "import_prompt_from_file",
      patterns: [
        "prompt import", "prompts import", "import_prompt_from_file", "import-prompt-from-file",
      ],
    },
    {
      id: "get_current_prompt_file_content",
      patterns: [
        "prompt current", "prompts current", "get_current_prompt_file_content", "get-current-prompt-file-content",
      ],
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
    Some("login") => {
      do_login(args)
      true
    }
    Some("auth_start_login") => {
      auth_start_login(args)
      true
    }
    Some("auth_poll_for_account") => {
      auth_poll_for_account(args)
      true
    }
    Some("auth_list_accounts") => {
      auth_list_accounts(args)
      true
    }
    Some("auth_get_status") => {
      auth_get_status(args)
      true
    }
    Some("auth_remove_account") => {
      auth_remove_account(args)
      true
    }
    Some("auth_set_default_account") => {
      auth_set_default_account(args)
      true
    }
    Some("auth_logout") => {
      auth_logout(args)
      true
    }
    Some("copilot_start_device_flow") => {
      copilot_start_device_flow(args)
      true
    }
    Some("copilot_poll_for_account") => {
      copilot_poll_for_account(args)
      true
    }
    Some("copilot_poll_for_auth") => {
      copilot_poll_for_auth(args)
      true
    }
    Some("copilot_list_accounts") => {
      check_usage_endpoint(args, "/copilot/accounts")
      true
    }
    Some("copilot_get_auth_status") => {
      check_usage_endpoint(args, "/copilot/status")
      true
    }
    Some("copilot_is_authenticated") => {
      check_usage_endpoint(args, "/copilot/authenticated")
      true
    }
    Some("copilot_logout") => {
      check_json_post_endpoint(args, "/copilot/logout", "Copilot")
      true
    }
    Some("copilot_remove_account") => {
      copilot_account_post(args, "/copilot/account")
      true
    }
    Some("copilot_set_default_account") => {
      copilot_account_post(args, "/copilot/default-account")
      true
    }
    Some("copilot_get_token") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot/token"),
      )
      true
    }
    Some("copilot_get_models") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot/models"),
      )
      true
    }
    Some("copilot_get_usage") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot/usage"),
      )
      true
    }
    Some("get_installed_skills") => {
      check_usage_endpoint(args, "/skills/installed")
      true
    }
    Some("get_skill_backups") => {
      check_usage_endpoint(args, "/skills/backups")
      true
    }
    Some("delete_skill_backup") => {
      check_json_post_endpoint(
        args,
        skill_backup_id_path(args, "/skills/backups/delete"),
        "Skills",
      )
      true
    }
    Some("restore_skill_backup") => {
      check_json_post_endpoint(args, skill_restore_backup_path(args), "Skills")
      true
    }
    Some("install_skill_unified") => {
      check_json_post_endpoint(
        args,
        skill_install_path(args, "/skills/install-unified"),
        "Skills",
      )
      true
    }
    Some("uninstall_skill_unified") => {
      check_json_post_endpoint(
        args,
        skill_id_path(args, "/skills/uninstall-unified"),
        "Skills",
      )
      true
    }
    Some("toggle_skill_app") => {
      check_json_post_endpoint(args, skill_toggle_app_path(args), "Skills")
      true
    }
    Some("scan_unmanaged_skills") => {
      check_usage_endpoint(args, "/skills/unmanaged")
      true
    }
    Some("import_skills_from_apps") => {
      import_skills_from_apps(args)
      true
    }
    Some("discover_available_skills") => {
      check_usage_endpoint(args, "/skills/discover")
      true
    }
    Some("check_skill_updates") => {
      check_usage_endpoint(args, "/skills/updates")
      true
    }
    Some("update_skill") => {
      check_json_post_endpoint(
        args,
        skill_id_path(args, "/skills/update"),
        "Skills",
      )
      true
    }
    Some("migrate_skill_storage") => {
      migrate_skill_storage(args)
      true
    }
    Some("search_skills_sh") => {
      check_usage_endpoint(args, skill_search_path(args))
      true
    }
    Some("get_skills") => {
      check_usage_endpoint(args, "/skills")
      true
    }
    Some("get_skills_for_app") => {
      check_usage_endpoint(args, skill_app_path(args, "/skills/app"))
      true
    }
    Some("install_skill") => {
      check_json_post_endpoint(
        args,
        skill_install_path(args, "/skills/install"),
        "Skills",
      )
      true
    }
    Some("install_skill_for_app") => {
      check_json_post_endpoint(
        args,
        skill_install_path(args, "/skills/install-for-app"),
        "Skills",
      )
      true
    }
    Some("uninstall_skill") => {
      check_json_post_endpoint(
        args,
        skill_id_path(args, "/skills/uninstall"),
        "Skills",
      )
      true
    }
    Some("uninstall_skill_for_app") => {
      check_json_post_endpoint(
        args,
        skill_id_path(args, "/skills/uninstall-for-app"),
        "Skills",
      )
      true
    }
    Some("get_skill_repos") => {
      check_usage_endpoint(args, "/skills/repos")
      true
    }
    Some("add_skill_repo") => {
      check_json_post_endpoint(args, skill_repo_add_path(args), "Skills")
      true
    }
    Some("remove_skill_repo") => {
      check_json_post_endpoint(args, skill_repo_remove_path(args), "Skills")
      true
    }
    Some("install_skills_from_zip") => {
      check_json_post_endpoint(args, skill_zip_install_path(args), "Skills")
      true
    }
    Some("get_app_config_path") => {
      check_usage_endpoint(args, "/get_app_config_path")
      true
    }
    Some("open_app_config_folder") => {
      check_usage_endpoint(args, "/open_app_config_folder")
      true
    }
    Some("get_claude_common_config_snippet") => {
      check_usage_endpoint(args, "/get_claude_common_config_snippet")
      true
    }
    Some("set_claude_common_config_snippet") => {
      set_config_snippet(
        args,
        "/set_claude_common_config_snippet",
        app_required=false,
      )
      true
    }
    Some("get_common_config_snippet") => {
      check_usage_endpoint(
        args,
        config_app_path(args, "/get_common_config_snippet"),
      )
      true
    }
    Some("set_common_config_snippet") => {
      set_config_snippet(args, "/set_common_config_snippet", app_required=true)
      true
    }
    Some("extract_common_config_snippet") => {
      check_usage_endpoint(args, extract_common_config_snippet_path(args))
      true
    }
    Some("check_env_conflicts") => {
      check_usage_endpoint(args, config_app_path(args, "/check_env_conflicts"))
      true
    }
    Some("delete_env_vars") => {
      delete_env_vars(args)
      true
    }
    Some("restore_env_backup") => {
      restore_env_backup(args)
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
      check_usage_endpoint(args, "/get_claude_desktop_status")
      true
    }
    Some("get_claude_desktop_default_routes") => {
      check_usage_endpoint(args, "/get_claude_desktop_default_routes")
      true
    }
    Some("import_claude_desktop_providers_from_claude") => {
      check_json_post_endpoint(
        args, "/import_claude_desktop_providers_from_claude", "Provider",
      )
      true
    }
    Some("ensure_claude_desktop_official_provider") => {
      check_json_post_endpoint(
        args, "/ensure_claude_desktop_official_provider", "Provider",
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
    Some("scan_openclaw_config_health") => {
      check_usage_endpoint(args, "/openclaw/config-health")
      true
    }
    Some("get_openclaw_default_model") => {
      check_usage_endpoint(args, "/openclaw/default-model")
      true
    }
    Some("set_openclaw_default_model") => {
      set_openclaw_default_model(args)
      true
    }
    Some("get_openclaw_model_catalog") => {
      check_usage_endpoint(args, "/openclaw/model-catalog")
      true
    }
    Some("set_openclaw_model_catalog") => {
      set_suite_json_config(args, "/openclaw/model-catalog", "--catalog")
      true
    }
    Some("get_openclaw_agents_defaults") => {
      check_usage_endpoint(args, "/openclaw/agents-defaults")
      true
    }
    Some("set_openclaw_agents_defaults") => {
      set_openclaw_agents_defaults(args)
      true
    }
    Some("get_openclaw_env") => {
      check_usage_endpoint(args, "/openclaw/env")
      true
    }
    Some("set_openclaw_env") => {
      set_openclaw_env(args)
      true
    }
    Some("get_openclaw_tools") => {
      check_usage_endpoint(args, "/openclaw/tools")
      true
    }
    Some("set_openclaw_tools") => {
      set_openclaw_tools(args)
      true
    }
    Some("get_hermes_model_config") => {
      check_usage_endpoint(args, "/hermes/model-config")
      true
    }
    Some("get_hermes_memory") => {
      check_hermes_memory(args)
      true
    }
    Some("set_hermes_memory") => {
      set_hermes_memory(args)
      true
    }
    Some("get_hermes_memory_limits") => {
      check_usage_endpoint(args, "/hermes/memory-limits")
      true
    }
    Some("set_hermes_memory_enabled") => {
      set_hermes_memory_enabled(args)
      true
    }
    Some("open_hermes_web_ui") => {
      check_usage_endpoint(args, hermes_web_ui_path(args))
      true
    }
    Some("launch_hermes_dashboard") => {
      check_json_post_endpoint(args, "/hermes/dashboard", "Hermes")
      true
    }
    Some("get_claude_config_status") => {
      check_usage_endpoint(args, "/get_claude_config_status")
      true
    }
    Some("get_config_status") => {
      check_usage_endpoint(args, config_app_path(args, "/get_config_status"))
      true
    }
    Some("get_claude_code_config_path") => {
      check_usage_endpoint(args, "/get_claude_code_config_path")
      true
    }
    Some("get_config_dir") => {
      check_usage_endpoint(args, config_app_path(args, "/get_config_dir"))
      true
    }
    Some("open_config_folder") => {
      check_usage_endpoint(args, config_app_path(args, "/open_config_folder"))
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
      check_json_post_endpoint(args, "/check_for_updates", "App shell")
      true
    }
    Some("update_tray_menu") => {
      check_json_post_endpoint(args, "/update_tray_menu", "App shell")
      true
    }
    Some("is_portable_mode") => {
      check_usage_endpoint(args, "/is_portable_mode")
      true
    }
    Some("get_init_error") => {
      check_usage_endpoint(args, "/get_init_error")
      true
    }
    Some("get_migration_result") => {
      check_usage_endpoint(args, "/get_migration_result")
      true
    }
    Some("get_skills_migration_result") => {
      check_usage_endpoint(args, "/get_skills_migration_result")
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
      check_json_post_endpoint(args, "/enter_lightweight_mode", "App shell")
      true
    }
    Some("exit_lightweight_mode") => {
      check_json_post_endpoint(args, "/exit_lightweight_mode", "App shell")
      true
    }
    Some("is_lightweight_mode") => {
      check_usage_endpoint(args, "/is_lightweight_mode")
      true
    }
    Some("save_file_dialog") => {
      check_usage_endpoint(args, save_file_dialog_path(args))
      true
    }
    Some("webdav_test_connection") => {
      check_json_post_endpoint(
        args,
        sync_settings_path(args, "/webdav_test_connection"),
        "Sync",
      )
      true
    }
    Some("webdav_sync_upload") => {
      check_json_post_endpoint(args, "/webdav_sync_upload", "Sync")
      true
    }
    Some("webdav_sync_download") => {
      check_json_post_endpoint(args, "/webdav_sync_download", "Sync")
      true
    }
    Some("webdav_sync_save_settings") => {
      check_json_post_endpoint(
        args,
        sync_settings_path(args, "/webdav_sync_save_settings"),
        "Sync",
      )
      true
    }
    Some("webdav_sync_fetch_remote_info") => {
      check_usage_endpoint(args, "/webdav_sync_fetch_remote_info")
      true
    }
    Some("s3_test_connection") => {
      check_json_post_endpoint(
        args,
        sync_settings_path(args, "/s3_test_connection"),
        "Sync",
      )
      true
    }
    Some("s3_sync_upload") => {
      check_json_post_endpoint(args, "/s3_sync_upload", "Sync")
      true
    }
    Some("s3_sync_download") => {
      check_json_post_endpoint(args, "/s3_sync_download", "Sync")
      true
    }
    Some("s3_sync_save_settings") => {
      check_json_post_endpoint(
        args,
        sync_settings_path(args, "/s3_sync_save_settings"),
        "Sync",
      )
      true
    }
    Some("s3_sync_fetch_remote_info") => {
      check_usage_endpoint(args, "/s3_sync_fetch_remote_info")
      true
    }
    Some("list_sessions") => {
      check_usage_endpoint(args, "/list_sessions")
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
      check_usage_endpoint(args, "/read_omo_local_file")
      true
    }
    Some("get_current_omo_provider_id") => {
      check_usage_endpoint(args, "/get_current_omo_provider_id")
      true
    }
    Some("disable_current_omo") => {
      check_json_post_endpoint(args, "/disable_current_omo", "OMO")
      true
    }
    Some("read_omo_slim_local_file") => {
      check_usage_endpoint(args, "/read_omo_slim_local_file")
      true
    }
    Some("get_current_omo_slim_provider_id") => {
      check_usage_endpoint(args, "/get_current_omo_slim_provider_id")
      true
    }
    Some("disable_current_omo_slim") => {
      check_json_post_endpoint(args, "/disable_current_omo_slim", "OMO")
      true
    }
    Some("open_file_dialog") => {
      check_usage_endpoint(args, "/open_file_dialog")
      true
    }
    Some("open_zip_file_dialog") => {
      check_usage_endpoint(args, "/open_zip_file_dialog")
      true
    }
    Some("export_config_to_file") => {
      check_json_post_endpoint(
        args,
        config_file_path(args, "/export_config_to_file"),
        "Import/export",
      )
      true
    }
    Some("import_config_from_file") => {
      check_json_post_endpoint(
        args,
        config_file_path(args, "/import_config_from_file"),
        "Import/export",
      )
      true
    }
    Some("create_db_backup") => {
      check_json_post_endpoint(args, "/create_db_backup", "Import/export")
      true
    }
    Some("list_db_backups") => {
      check_usage_endpoint(args, "/list_db_backups")
      true
    }
    Some("restore_db_backup") => {
      check_json_post_endpoint(
        args,
        db_backup_filename_path(args, "/restore_db_backup"),
        "Import/export",
      )
      true
    }
    Some("rename_db_backup") => {
      check_json_post_endpoint(
        args,
        db_backup_rename_path(args),
        "Import/export",
      )
      true
    }
    Some("delete_db_backup") => {
      check_json_post_endpoint(
        args,
        db_backup_filename_path(args, "/delete_db_backup"),
        "Import/export",
      )
      true
    }
    Some("parse_deeplink") => {
      check_usage_endpoint(args, deeplink_url_path(args, "/parse_deeplink"))
      true
    }
    Some("merge_deeplink_config") => {
      check_json_post_endpoint(
        args,
        deeplink_request_path(args, "/merge_deeplink_config"),
        "Deeplink",
      )
      true
    }
    Some("import_from_deeplink") => {
      check_json_post_endpoint(
        args,
        deeplink_request_path(args, "/import_from_deeplink"),
        "Deeplink",
      )
      true
    }
    Some("import_from_deeplink_unified") => {
      check_json_post_endpoint(
        args,
        deeplink_request_path(args, "/import_from_deeplink_unified"),
        "Deeplink",
      )
      true
    }
    Some("get_settings") => {
      check_usage_endpoint(args, "/get_settings")
      true
    }
    Some("save_settings") => {
      save_settings(args)
      true
    }
    Some("restart_app") => {
      check_json_post_endpoint(args, "/restart_app", "Settings")
      true
    }
    Some("install_update_and_restart") => {
      check_json_post_endpoint(args, "/install_update_and_restart", "Settings")
      true
    }
    Some("set_app_config_dir_override") => {
      set_app_config_dir_override(args)
      true
    }
    Some("get_app_config_dir_override") => {
      check_usage_endpoint(args, "/get_app_config_dir_override")
      true
    }
    Some("set_auto_launch") => {
      set_auto_launch(args)
      true
    }
    Some("get_auto_launch_status") => {
      check_usage_endpoint(args, "/get_auto_launch_status")
      true
    }
    Some("set_rectifier_config") => {
      set_moon_json_config(
        args, "/set_rectifier_config", "--config", "Settings",
      )
      true
    }
    Some("get_rectifier_config") => {
      check_usage_endpoint(args, "/get_rectifier_config")
      true
    }
    Some("set_optimizer_config") => {
      set_moon_json_config(
        args, "/set_optimizer_config", "--config", "Settings",
      )
      true
    }
    Some("get_optimizer_config") => {
      check_usage_endpoint(args, "/get_optimizer_config")
      true
    }
    Some("set_copilot_optimizer_config") => {
      set_moon_json_config(
        args, "/set_copilot_optimizer_config", "--config", "Settings",
      )
      true
    }
    Some("get_copilot_optimizer_config") => {
      check_usage_endpoint(args, "/get_copilot_optimizer_config")
      true
    }
    Some("set_log_config") => {
      set_moon_json_config(args, "/set_log_config", "--config", "Settings")
      true
    }
    Some("get_log_config") => {
      check_usage_endpoint(args, "/get_log_config")
      true
    }
    Some("get_claude_plugin_status") => {
      check_usage_endpoint(args, "/get_claude_plugin_status")
      true
    }
    Some("read_claude_plugin_config") => {
      check_usage_endpoint(args, "/read_claude_plugin_config")
      true
    }
    Some("apply_claude_plugin_config") => {
      apply_claude_plugin_config(args)
      true
    }
    Some("is_claude_plugin_applied") => {
      check_usage_endpoint(args, "/is_claude_plugin_applied")
      true
    }
    Some("apply_claude_onboarding_skip") => {
      check_json_post_endpoint(args, "/apply_claude_onboarding_skip", "Plugin")
      true
    }
    Some("clear_claude_onboarding_skip") => {
      check_json_post_endpoint(args, "/clear_claude_onboarding_skip", "Plugin")
      true
    }
    Some("list_daily_memory_files") => {
      check_usage_endpoint(args, "/list_daily_memory_files")
      true
    }
    Some("read_daily_memory_file") => {
      check_usage_endpoint(
        args,
        workspace_filename_path(args, "/read_daily_memory_file"),
      )
      true
    }
    Some("write_daily_memory_file") => {
      write_workspace_content(args, "/write_daily_memory_file", "Workspace")
      true
    }
    Some("search_daily_memory_files") => {
      check_usage_endpoint(
        args,
        workspace_query_path(args, "/search_daily_memory_files"),
      )
      true
    }
    Some("delete_daily_memory_file") => {
      delete_workspace_resource(args, "/delete_daily_memory_file", "Workspace")
      true
    }
    Some("read_workspace_file") => {
      check_usage_endpoint(
        args,
        workspace_filename_path(args, "/read_workspace_file"),
      )
      true
    }
    Some("write_workspace_file") => {
      write_workspace_content(args, "/write_workspace_file", "Workspace")
      true
    }
    Some("open_workspace_directory") => {
      check_json_post_endpoint(
        args,
        workspace_subdir_path(args, "/open_workspace_directory"),
        "Workspace",
      )
      true
    }
    Some("get_claude_mcp_status") => {
      check_usage_endpoint(args, "/get_claude_mcp_status")
      true
    }
    Some("read_claude_mcp_config") => {
      check_usage_endpoint(args, "/read_claude_mcp_config")
      true
    }
    Some("upsert_claude_mcp_server") => {
      upsert_mcp_server(args, "/upsert_claude_mcp_server")
      true
    }
    Some("delete_claude_mcp_server") => {
      delete_mcp_server(args, "/delete_claude_mcp_server")
      true
    }
    Some("validate_mcp_command") => {
      check_usage_endpoint(args, mcp_validate_command_path(args))
      true
    }
    Some("get_mcp_config") => {
      check_usage_endpoint(args, mcp_app_path(args, "/get_mcp_config"))
      true
    }
    Some("upsert_mcp_server_in_config") => {
      upsert_mcp_server(args, "/upsert_mcp_server_in_config")
      true
    }
    Some("delete_mcp_server_in_config") => {
      delete_mcp_server(args, "/delete_mcp_server_in_config")
      true
    }
    Some("set_mcp_enabled") => {
      set_mcp_enabled(args)
      true
    }
    Some("get_mcp_servers") => {
      check_usage_endpoint(args, "/get_mcp_servers")
      true
    }
    Some("upsert_mcp_server") => {
      upsert_mcp_server(args, "/upsert_mcp_server")
      true
    }
    Some("delete_mcp_server") => {
      delete_mcp_server(args, "/delete_mcp_server")
      true
    }
    Some("toggle_mcp_app") => {
      toggle_mcp_app(args)
      true
    }
    Some("import_mcp_from_apps") => {
      check_json_post_endpoint(args, "/import_mcp_from_apps", "MCP")
      true
    }
    Some("get_prompts") => {
      check_usage_endpoint(args, prompt_app_path(args, "/get_prompts"))
      true
    }
    Some("upsert_prompt") => {
      upsert_prompt(args)
      true
    }
    Some("delete_prompt") => {
      delete_prompt(args)
      true
    }
    Some("enable_prompt") => {
      enable_prompt(args)
      true
    }
    Some("import_prompt_from_file") => {
      import_prompt_from_file(args)
      true
    }
    Some("get_current_prompt_file_content") => {
      check_usage_endpoint(
        args,
        prompt_file_path(args, "/get_current_prompt_file_content"),
      )
      true
    }
    Some("get_usage_summary") => {
      check_usage_summary(args)
      true
    }
    Some("get_usage_summary_by_app") => {
      check_usage_apps(args)
      true
    }
    Some("get_usage_trends") => {
      check_usage_trends(args)
      true
    }
    Some("get_provider_stats") => {
      check_usage_providers(args)
      true
    }
    Some("get_model_stats") => {
      check_usage_models(args)
      true
    }
    Some("get_request_logs") => {
      check_usage_logs(args)
      true
    }
    Some("get_request_detail") => {
      check_usage_detail(args)
      true
    }
    Some("get_model_pricing") => {
      check_usage_endpoint(args, "/usage/model-pricing")
      true
    }
    Some("update_model_pricing") => {
      update_usage_pricing(args)
      true
    }
    Some("delete_model_pricing") => {
      delete_usage_pricing(args)
      true
    }
    Some("check_provider_limits") => {
      check_usage_limits(args)
      true
    }
    Some("sync_session_usage") => {
      sync_session_usage(args)
      true
    }
    Some("get_usage_data_sources") => {
      check_usage_endpoint(args, "/usage/data-sources")
      true
    }
    Some("query_provider_usage") => {
      check_usage_provider_script(args)
      true
    }
    Some("get_balance") => {
      check_balance(args)
      true
    }
    Some("get_subscription_quota") => {
      check_subscription_quota(args)
      true
    }
    Some("get_codex_oauth_quota") => {
      check_codex_oauth_quota(args)
      true
    }
    Some("get_codex_oauth_models") => {
      check_codex_oauth_models(args)
      true
    }
    Some("get_coding_plan_quota") => {
      check_coding_plan_quota(args)
      true
    }
    Some("test_usage_script") => {
      test_usage_script(args)
      true
    }
    Some("suite_manifest") => {
      print_suite_manifest(args)
      true
    }
    Some("suite_status") => {
      print_suite_status(args)
      true
    }
    Some("suite_write_status") => {
      write_suite_status(args)
      true
    }
    Some("suite_moonclaw_providers") => {
      print_moonclaw_providers_file(args)
      true
    }
    Some("suite_write_moonclaw_providers") => {
      write_moonclaw_providers_file(args)
      true
    }
    Some("status") => {
      check_status(args)
      true
    }
    Some("health") => {
      check_health(args)
      true
    }
    Some("stats") => {
      check_stats(args)
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
