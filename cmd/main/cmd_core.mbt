///|
pub async fn start(args : ArrayView[String]) -> Unit {
  let arr = args.to_array()
  match arr[1:] {
    ["start", ..] => start_gateway(arr)
    ["login", ..] => do_login(arr)
    ["auth", "start-login", ..] => auth_start_login(arr)
    ["auth", "poll", ..] | ["auth", "poll-for-account", ..] =>
      auth_poll_for_account(arr)
    ["auth", "list", ..] | ["auth", "list-accounts", ..] =>
      auth_list_accounts(arr)
    ["auth", "status", ..] => auth_get_status(arr)
    ["auth", "remove", ..] | ["auth", "remove-account", ..] =>
      auth_remove_account(arr)
    ["auth", "default", ..] | ["auth", "set-default-account", ..] =>
      auth_set_default_account(arr)
    ["auth", "logout", ..] => auth_logout(arr)
    ["copilot", "start-device-flow", ..] => copilot_start_device_flow(arr)
    ["copilot", "poll", ..] | ["copilot", "poll-for-account", ..] =>
      copilot_poll_for_account(arr)
    ["copilot", "poll-for-auth", ..] => copilot_poll_for_auth(arr)
    ["copilot", "list", ..] | ["copilot", "list-accounts", ..] =>
      check_usage_endpoint(arr, "/copilot_list_accounts")
    ["copilot", "auth-status", ..] | ["copilot", "status", ..] =>
      check_usage_endpoint(arr, "/copilot_get_auth_status")
    ["copilot", "is-authenticated", ..] =>
      check_usage_endpoint(arr, "/copilot_is_authenticated")
    ["copilot", "logout", ..] =>
      check_json_post_endpoint(arr, "/copilot_logout", "Copilot")
    ["copilot", "remove", ..] | ["copilot", "remove-account", ..] =>
      copilot_account_post(arr, "/copilot_remove_account")
    ["copilot", "default", ..] | ["copilot", "set-default-account", ..] =>
      copilot_account_post(arr, "/copilot_set_default_account")
    ["copilot", "token", ..] =>
      check_usage_endpoint(
        arr,
        copilot_account_optional_path(arr, "/copilot_get_token"),
      )
    ["copilot", "models", ..] =>
      check_usage_endpoint(
        arr,
        copilot_account_optional_path(arr, "/copilot_get_models"),
      )
    ["copilot", "usage", ..] =>
      check_usage_endpoint(
        arr,
        copilot_account_optional_path(arr, "/copilot_get_usage"),
      )
    ["install", ..] => install_reroute(arr)
    ["uninstall"] | ["remove"] => uninstall_reroute()
    ["claude-desktop", "install", ..] => install_claude_desktop(arr)
    ["claude-desktop", "uninstall" | "remove", ..] => uninstall_claude_desktop()
    ["claude-desktop", "status", ..] => status_claude_desktop()
    ["codex", "install", ..] => install_codex(arr)
    ["codex", "uninstall" | "remove", ..] => uninstall_codex()
    ["codex", "status", ..] => status_codex()
    ["models", "fetch", ..] => fetch_provider_models(arr)
    ["models", "candidates", ..] => print_model_candidates(arr)
    ["fetch_models_for_config", ..] | ["fetch-models-for-config", ..] =>
      fetch_provider_models(arr)
    ["auth_start_login", ..] | ["auth-start-login", ..] => auth_start_login(arr)
    ["auth_poll_for_account", ..] | ["auth-poll-for-account", ..] =>
      auth_poll_for_account(arr)
    ["auth_list_accounts", ..] | ["auth-list-accounts", ..] =>
      auth_list_accounts(arr)
    ["auth_get_status", ..] | ["auth-get-status", ..] => auth_get_status(arr)
    ["auth_remove_account", ..] | ["auth-remove-account", ..] =>
      auth_remove_account(arr)
    ["auth_set_default_account", ..] | ["auth-set-default-account", ..] =>
      auth_set_default_account(arr)
    ["auth_logout", ..] | ["auth-logout", ..] => auth_logout(arr)
    ["copilot_start_device_flow", ..] | ["copilot-start-device-flow", ..] =>
      copilot_start_device_flow(arr)
    ["copilot_poll_for_auth", ..] | ["copilot-poll-for-auth", ..] =>
      copilot_poll_for_auth(arr)
    ["copilot_poll_for_account", ..] | ["copilot-poll-for-account", ..] =>
      copilot_poll_for_account(arr)
    ["copilot_list_accounts", ..] | ["copilot-list-accounts", ..] =>
      check_usage_endpoint(arr, "/copilot_list_accounts")
    ["copilot_get_auth_status", ..] | ["copilot-get-auth-status", ..] =>
      check_usage_endpoint(arr, "/copilot_get_auth_status")
    ["copilot_is_authenticated", ..] | ["copilot-is-authenticated", ..] =>
      check_usage_endpoint(arr, "/copilot_is_authenticated")
    ["copilot_logout", ..] | ["copilot-logout", ..] =>
      check_json_post_endpoint(arr, "/copilot_logout", "Copilot")
    ["copilot_remove_account", ..] | ["copilot-remove-account", ..] =>
      copilot_account_post(arr, "/copilot_remove_account")
    ["copilot_set_default_account", ..] | ["copilot-set-default-account", ..] =>
      copilot_account_post(arr, "/copilot_set_default_account")
    ["copilot_get_token", ..] | ["copilot-get-token", ..] =>
      check_usage_endpoint(
        arr,
        copilot_account_optional_path(arr, "/copilot_get_token"),
      )
    ["copilot_get_token_for_account", ..]
    | ["copilot-get-token-for-account", ..] =>
      check_usage_endpoint(
        arr,
        copilot_account_optional_path(arr, "/copilot_get_token_for_account"),
      )
    ["copilot_get_models", ..] | ["copilot-get-models", ..] =>
      check_usage_endpoint(
        arr,
        copilot_account_optional_path(arr, "/copilot_get_models"),
      )
    ["copilot_get_models_for_account", ..]
    | ["copilot-get-models-for-account", ..] =>
      check_usage_endpoint(
        arr,
        copilot_account_optional_path(arr, "/copilot_get_models_for_account"),
      )
    ["copilot_get_usage", ..] | ["copilot-get-usage", ..] =>
      check_usage_endpoint(
        arr,
        copilot_account_optional_path(arr, "/copilot_get_usage"),
      )
    ["copilot_get_usage_for_account", ..]
    | ["copilot-get-usage-for-account", ..] =>
      check_usage_endpoint(
        arr,
        copilot_account_optional_path(arr, "/copilot_get_usage_for_account"),
      )
    ["stream-check", "provider", ..]
    | ["stream-check", "stream-check-provider", ..] =>
      stream_check_provider(arr)
    ["stream-check", "all", ..]
    | ["stream-check", "stream-check-all-providers", ..] =>
      stream_check_all_providers(arr)
    ["stream-check", "config", "set", ..]
    | ["stream-check", "save-stream-check-config", ..] =>
      save_stream_check_config(arr)
    ["stream-check", "config", ..]
    | ["stream-check", "get-stream-check-config", ..] =>
      check_usage_endpoint(arr, "/get_stream_check_config")
    ["suite", "manifest", ..] => print_suite_manifest(arr)
    ["suite", "status", ..] => print_suite_status(arr)
    ["suite", "write-status", ..] => write_suite_status(arr)
    ["suite", "moonclaw-providers", ..] | ["suite", "provider-manifest", ..] =>
      print_moonclaw_providers_file(arr)
    ["suite", "write-moonclaw-providers", ..]
    | ["suite", "write-provider-manifest", ..] =>
      write_moonclaw_providers_file(arr)
    ["status", ..] => check_status(arr)
    ["health", ..] => check_health(arr)
    ["stats", ..] => check_stats(arr)
    ["get_proxy_status", ..] | ["get-proxy-status", ..] =>
      check_proxy_status(arr)
    ["start_proxy_server", ..] | ["start-proxy-server", ..] =>
      start_proxy_server(arr)
    ["stop_proxy_server", ..] | ["stop-proxy-server", ..] =>
      stop_proxy_server(arr)
    ["stop_proxy_with_restore", ..] | ["stop-proxy-with-restore", ..] =>
      stop_proxy_with_restore(arr)
    ["get_proxy_config", ..] | ["get-proxy-config", ..] =>
      check_proxy_config(arr)
    ["update_proxy_config", ..] | ["update-proxy-config", ..] =>
      update_proxy_config(arr)
    ["get_global_proxy_config", ..] | ["get-global-proxy-config", ..] =>
      check_proxy_global_config(arr)
    ["update_global_proxy_config", ..] | ["update-global-proxy-config", ..] =>
      update_proxy_global_config(arr)
    ["get_settings", ..] | ["get-settings", ..] =>
      check_usage_endpoint(arr, "/get_settings")
    ["save_settings", ..] | ["save-settings", ..] => save_settings(arr)
    ["restart_app", ..] | ["restart-app", ..] =>
      check_json_post_endpoint(arr, "/restart_app", "Settings")
    ["install_update_and_restart", ..] | ["install-update-and-restart", ..] =>
      check_json_post_endpoint(arr, "/install_update_and_restart", "Settings")
    ["get_app_config_dir_override", ..] | ["get-app-config-dir-override", ..] =>
      check_usage_endpoint(arr, "/get_app_config_dir_override")
    ["set_app_config_dir_override", ..] | ["set-app-config-dir-override", ..] =>
      set_app_config_dir_override(arr)
    ["set_auto_launch", ..] | ["set-auto-launch", ..] => set_auto_launch(arr)
    ["get_auto_launch_status", ..] | ["get-auto-launch-status", ..] =>
      check_usage_endpoint(arr, "/get_auto_launch_status")
    ["get_rectifier_config", ..] | ["get-rectifier-config", ..] =>
      check_usage_endpoint(arr, "/get_rectifier_config")
    ["set_rectifier_config", ..] | ["set-rectifier-config", ..] =>
      set_moon_json_config(arr, "/set_rectifier_config", "--config", "Settings")
    ["get_optimizer_config", ..] | ["get-optimizer-config", ..] =>
      check_usage_endpoint(arr, "/get_optimizer_config")
    ["set_optimizer_config", ..] | ["set-optimizer-config", ..] =>
      set_moon_json_config(arr, "/set_optimizer_config", "--config", "Settings")
    ["get_copilot_optimizer_config", ..]
    | ["get-copilot-optimizer-config", ..] =>
      check_usage_endpoint(arr, "/get_copilot_optimizer_config")
    ["set_copilot_optimizer_config", ..]
    | ["set-copilot-optimizer-config", ..] =>
      set_moon_json_config(
        arr, "/set_copilot_optimizer_config", "--config", "Settings",
      )
    ["get_log_config", ..] | ["get-log-config", ..] =>
      check_usage_endpoint(arr, "/get_log_config")
    ["set_log_config", ..] | ["set-log-config", ..] =>
      set_moon_json_config(arr, "/set_log_config", "--config", "Settings")
    ["get_global_proxy_url", ..] | ["get-global-proxy-url", ..] =>
      check_usage_endpoint(arr, "/get_global_proxy_url")
    ["set_global_proxy_url", ..] | ["set-global-proxy-url", ..] =>
      set_global_proxy_url(arr)
    ["test_proxy_url", ..] | ["test-proxy-url", ..] =>
      test_global_proxy_url(arr)
    ["get_upstream_proxy_status", ..] | ["get-upstream-proxy-status", ..] =>
      check_usage_endpoint(arr, "/get_upstream_proxy_status")
    ["scan_local_proxies", ..] | ["scan-local-proxies", ..] =>
      check_usage_endpoint(arr, "/scan_local_proxies")
    ["get_proxy_config_for_app", ..] | ["get-proxy-config-for-app", ..] =>
      check_proxy_app_config(arr)
    ["update_proxy_config_for_app", ..] | ["update-proxy-config-for-app", ..] =>
      update_proxy_app_config(arr)
    ["get_default_cost_multiplier", ..] | ["get-default-cost-multiplier", ..] =>
      check_proxy_default_cost_multiplier(arr)
    ["set_default_cost_multiplier", ..] | ["set-default-cost-multiplier", ..] =>
      set_proxy_default_cost_multiplier(arr)
    ["get_default_cost_multiplier_test_hook", ..]
    | ["get-default-cost-multiplier-test-hook", ..] =>
      check_proxy_default_cost_multiplier_test_hook(arr)
    ["set_default_cost_multiplier_test_hook", ..]
    | ["set-default-cost-multiplier-test-hook", ..] =>
      set_proxy_default_cost_multiplier_test_hook(arr)
    ["get_pricing_model_source", ..] | ["get-pricing-model-source", ..] =>
      check_proxy_pricing_model_source(arr)
    ["set_pricing_model_source", ..] | ["set-pricing-model-source", ..] =>
      set_proxy_pricing_model_source(arr)
    ["get_pricing_model_source_test_hook", ..]
    | ["get-pricing-model-source-test-hook", ..] =>
      check_proxy_pricing_model_source_test_hook(arr)
    ["set_pricing_model_source_test_hook", ..]
    | ["set-pricing-model-source-test-hook", ..] =>
      set_proxy_pricing_model_source_test_hook(arr)
    ["get_provider_health", ..] | ["get-provider-health", ..] =>
      check_proxy_provider_health(arr)
    ["get_circuit_breaker_config", ..] | ["get-circuit-breaker-config", ..] =>
      check_proxy_circuit_breaker_config(arr)
    ["update_circuit_breaker_config", ..]
    | ["update-circuit-breaker-config", ..] =>
      update_proxy_circuit_breaker_config(arr)
    ["get_circuit_breaker_stats", ..] | ["get-circuit-breaker-stats", ..] =>
      check_proxy_circuit_breaker_stats(arr)
    ["reset_circuit_breaker", ..] | ["reset-circuit-breaker", ..] =>
      reset_proxy_circuit_breaker(arr)
    ["get_failover_queue", ..] | ["get-failover-queue", ..] =>
      check_proxy_failover_queue(arr)
    ["get_available_providers_for_failover", ..]
    | ["get-available-providers-for-failover", ..] =>
      check_proxy_available_failover_providers(arr)
    ["add_to_failover_queue", ..] | ["add-to-failover-queue", ..] =>
      add_proxy_failover_queue(arr)
    ["remove_from_failover_queue", ..] | ["remove-from-failover-queue", ..] =>
      remove_proxy_failover_queue(arr)
    ["get_auto_failover_enabled", ..] | ["get-auto-failover-enabled", ..] =>
      check_proxy_auto_failover_enabled(arr)
    ["set_auto_failover_enabled", ..] | ["set-auto-failover-enabled", ..] =>
      set_proxy_auto_failover_enabled(arr)
    ["get_proxy_takeover_status", ..] | ["get-proxy-takeover-status", ..] =>
      check_proxy_takeover_status(arr)
    ["set_proxy_takeover_for_app", ..] | ["set-proxy-takeover-for-app", ..] =>
      set_proxy_takeover_status(arr)
    ["is_live_takeover_active", ..] | ["is-live-takeover-active", ..] =>
      check_proxy_endpoint(arr, "/is_live_takeover_active")
    ["switch_proxy_provider", ..] | ["switch-proxy-provider", ..] =>
      switch_proxy_provider(arr)
    ["is_proxy_running", ..] | ["is-proxy-running", ..] =>
      check_proxy_running(arr)
    ["get_providers", ..] | ["get-providers", ..] => check_providers(arr)
    ["get_current_provider", ..] | ["get-current-provider", ..] =>
      check_current_provider(arr)
    ["add_provider", ..] | ["add-provider", ..] => add_provider(arr)
    ["update_provider", ..] | ["update-provider", ..] => update_provider(arr)
    ["delete_provider", ..] | ["delete-provider", ..] => delete_provider(arr)
    ["remove_provider_from_live_config", ..]
    | ["remove-provider-from-live-config", ..] =>
      remove_provider_from_live_config(arr)
    ["switch_provider", ..] | ["switch-provider", ..] => switch_provider(arr)
    ["switch_provider_test_hook", ..] | ["switch-provider-test-hook", ..] =>
      switch_provider_test_hook(arr)
    ["sync_current_providers_live", ..] | ["sync-current-providers-live", ..] =>
      sync_current_providers_live(arr)
    ["import_default_config", ..] | ["import-default-config", ..] =>
      import_default_config(arr)
    ["import_default_config_test_hook", ..]
    | ["import-default-config-test-hook", ..] =>
      import_default_config_test_hook(arr)
    ["open_provider_terminal", ..] | ["open-provider-terminal", ..] =>
      open_provider_terminal(arr)
    ["get_claude_desktop_status", ..] | ["get-claude-desktop-status", ..] =>
      check_usage_endpoint(arr, "/get_claude_desktop_status")
    ["get_claude_desktop_default_routes", ..]
    | ["get-claude-desktop-default-routes", ..] =>
      check_usage_endpoint(arr, "/get_claude_desktop_default_routes")
    ["import_claude_desktop_providers_from_claude", ..]
    | ["import-claude-desktop-providers-from-claude", ..] =>
      check_json_post_endpoint(
        arr, "/import_claude_desktop_providers_from_claude", "Provider",
      )
    ["ensure_claude_desktop_official_provider", ..]
    | ["ensure-claude-desktop-official-provider", ..] =>
      check_json_post_endpoint(
        arr, "/ensure_claude_desktop_official_provider", "Provider",
      )
    ["read_live_provider_settings", ..] | ["read-live-provider-settings", ..] =>
      check_live_provider_settings(arr)
    ["get_claude_plugin_status", ..] | ["get-claude-plugin-status", ..] =>
      check_usage_endpoint(arr, "/get_claude_plugin_status")
    ["read_claude_plugin_config", ..] | ["read-claude-plugin-config", ..] =>
      check_usage_endpoint(arr, "/read_claude_plugin_config")
    ["apply_claude_plugin_config", ..] | ["apply-claude-plugin-config", ..] =>
      apply_claude_plugin_config(arr)
    ["is_claude_plugin_applied", ..] | ["is-claude-plugin-applied", ..] =>
      check_usage_endpoint(arr, "/is_claude_plugin_applied")
    ["apply_claude_onboarding_skip", ..]
    | ["apply-claude-onboarding-skip", ..] =>
      check_json_post_endpoint(arr, "/apply_claude_onboarding_skip", "Plugin")
    ["clear_claude_onboarding_skip", ..]
    | ["clear-claude-onboarding-skip", ..] =>
      check_json_post_endpoint(arr, "/clear_claude_onboarding_skip", "Plugin")
    ["list_daily_memory_files", ..] | ["list-daily-memory-files", ..] =>
      check_usage_endpoint(arr, "/list_daily_memory_files")
    ["read_daily_memory_file", ..] | ["read-daily-memory-file", ..] =>
      check_usage_endpoint(
        arr,
        workspace_filename_path(arr, "/read_daily_memory_file"),
      )
    ["write_daily_memory_file", ..] | ["write-daily-memory-file", ..] =>
      write_workspace_content(arr, "/write_daily_memory_file", "Workspace")
    ["search_daily_memory_files", ..] | ["search-daily-memory-files", ..] =>
      check_usage_endpoint(
        arr,
        workspace_query_path(arr, "/search_daily_memory_files"),
      )
    ["delete_daily_memory_file", ..] | ["delete-daily-memory-file", ..] =>
      delete_workspace_resource(arr, "/delete_daily_memory_file", "Workspace")
    ["read_workspace_file", ..] | ["read-workspace-file", ..] =>
      check_usage_endpoint(
        arr,
        workspace_filename_path(arr, "/read_workspace_file"),
      )
    ["write_workspace_file", ..] | ["write-workspace-file", ..] =>
      write_workspace_content(arr, "/write_workspace_file", "Workspace")
    ["open_workspace_directory", ..] | ["open-workspace-directory", ..] =>
      check_json_post_endpoint(
        arr,
        workspace_subdir_path(arr, "/open_workspace_directory"),
        "Workspace",
      )
    ["get_opencode_live_provider_ids", ..]
    | ["get-opencode-live-provider-ids", ..] =>
      check_named_live_provider_ids(arr, "opencode")
    ["get_openclaw_live_provider_ids", ..]
    | ["get-openclaw-live-provider-ids", ..] =>
      check_named_live_provider_ids(arr, "openclaw")
    ["get_openclaw_live_provider", ..] | ["get-openclaw-live-provider", ..] =>
      check_named_live_provider(arr, "openclaw")
    ["scan_openclaw_config_health", ..] | ["scan-openclaw-config-health", ..] =>
      check_usage_endpoint(arr, "/scan_openclaw_config_health")
    ["get_openclaw_default_model", ..] | ["get-openclaw-default-model", ..] =>
      check_usage_endpoint(arr, "/get_openclaw_default_model")
    ["set_openclaw_default_model", ..] | ["set-openclaw-default-model", ..] =>
      set_openclaw_default_model(arr)
    ["get_openclaw_model_catalog", ..] | ["get-openclaw-model-catalog", ..] =>
      check_usage_endpoint(arr, "/get_openclaw_model_catalog")
    ["set_openclaw_model_catalog", ..] | ["set-openclaw-model-catalog", ..] =>
      set_suite_json_config(arr, "/set_openclaw_model_catalog", "--catalog")
    ["get_openclaw_agents_defaults", ..]
    | ["get-openclaw-agents-defaults", ..] =>
      check_usage_endpoint(arr, "/get_openclaw_agents_defaults")
    ["set_openclaw_agents_defaults", ..]
    | ["set-openclaw-agents-defaults", ..] => set_openclaw_agents_defaults(arr)
    ["get_openclaw_env", ..] | ["get-openclaw-env", ..] =>
      check_usage_endpoint(arr, "/get_openclaw_env")
    ["set_openclaw_env", ..] | ["set-openclaw-env", ..] => set_openclaw_env(arr)
    ["get_openclaw_tools", ..] | ["get-openclaw-tools", ..] =>
      check_usage_endpoint(arr, "/get_openclaw_tools")
    ["set_openclaw_tools", ..] | ["set-openclaw-tools", ..] =>
      set_openclaw_tools(arr)
    ["get_hermes_live_provider_ids", ..]
    | ["get-hermes-live-provider-ids", ..] =>
      check_named_live_provider_ids(arr, "hermes")
    ["get_hermes_live_provider", ..] | ["get-hermes-live-provider", ..] =>
      check_named_live_provider(arr, "hermes")
    ["get_hermes_model_config", ..] | ["get-hermes-model-config", ..] =>
      check_usage_endpoint(arr, "/get_hermes_model_config")
    ["get_hermes_memory", ..] | ["get-hermes-memory", ..] =>
      check_hermes_memory(arr)
    ["set_hermes_memory", ..] | ["set-hermes-memory", ..] =>
      set_hermes_memory(arr)
    ["get_hermes_memory_limits", ..] | ["get-hermes-memory-limits", ..] =>
      check_usage_endpoint(arr, "/get_hermes_memory_limits")
    ["set_hermes_memory_enabled", ..] | ["set-hermes-memory-enabled", ..] =>
      set_hermes_memory_enabled(arr)
    ["open_hermes_web_ui", ..] | ["open-hermes-web-ui", ..] =>
      check_usage_endpoint(arr, hermes_web_ui_path(arr))
    ["launch_hermes_dashboard", ..] | ["launch-hermes-dashboard", ..] =>
      check_json_post_endpoint(arr, "/launch_hermes_dashboard", "Hermes")
    ["get_claude_config_status", ..] | ["get-claude-config-status", ..] =>
      check_usage_endpoint(arr, "/get_claude_config_status")
    ["get_config_status", ..] | ["get-config-status", ..] =>
      check_usage_endpoint(arr, config_app_path(arr, "/get_config_status"))
    ["get_claude_code_config_path", ..] | ["get-claude-code-config-path", ..] =>
      check_usage_endpoint(arr, "/get_claude_code_config_path")
    ["get_config_dir", ..] | ["get-config-dir", ..] =>
      check_usage_endpoint(arr, config_app_path(arr, "/get_config_dir"))
    ["open_config_folder", ..] | ["open-config-folder", ..] =>
      check_usage_endpoint(arr, config_app_path(arr, "/open_config_folder"))
    ["pick_directory", ..] | ["pick-directory", ..] =>
      check_usage_endpoint(arr, pick_directory_path(arr))
    ["open_external", ..] | ["open-external", ..] =>
      check_usage_endpoint(arr, open_external_path(arr))
    ["copy_text_to_clipboard", ..] | ["copy-text-to-clipboard", ..] =>
      check_usage_endpoint(arr, copy_text_to_clipboard_path(arr))
    ["check_for_updates", ..] | ["check-for-updates", ..] =>
      check_json_post_endpoint(arr, "/check_for_updates", "App shell")
    ["update_tray_menu", ..] | ["update-tray-menu", ..] =>
      check_json_post_endpoint(arr, "/update_tray_menu", "App shell")
    ["is_portable_mode", ..] | ["is-portable-mode", ..] =>
      check_usage_endpoint(arr, "/is_portable_mode")
    ["get_init_error", ..] | ["get-init-error", ..] =>
      check_usage_endpoint(arr, "/get_init_error")
    ["get_migration_result", ..] | ["get-migration-result", ..] =>
      check_usage_endpoint(arr, "/get_migration_result")
    ["get_skills_migration_result", ..] | ["get-skills-migration-result", ..] =>
      check_usage_endpoint(arr, "/get_skills_migration_result")
    ["get_tool_versions", ..] | ["get-tool-versions", ..] =>
      check_usage_endpoint(arr, tool_versions_path(arr))
    ["run_tool_lifecycle_action", ..] | ["run-tool-lifecycle-action", ..] =>
      run_tool_lifecycle_action(arr)
    ["probe_tool_installations", ..] | ["probe-tool-installations", ..] =>
      check_usage_endpoint(arr, tool_installations_path(arr))
    ["set_window_theme", ..] | ["set-window-theme", ..] =>
      check_usage_endpoint(arr, window_theme_path(arr))
    ["enter_lightweight_mode", ..] | ["enter-lightweight-mode", ..] =>
      check_json_post_endpoint(arr, "/enter_lightweight_mode", "App shell")
    ["exit_lightweight_mode", ..] | ["exit-lightweight-mode", ..] =>
      check_json_post_endpoint(arr, "/exit_lightweight_mode", "App shell")
    ["is_lightweight_mode", ..] | ["is-lightweight-mode", ..] =>
      check_usage_endpoint(arr, "/is_lightweight_mode")
    ["save_file_dialog", ..] | ["save-file-dialog", ..] =>
      check_usage_endpoint(arr, save_file_dialog_path(arr))
    ["export_config_to_file", ..] | ["export-config-to-file", ..] =>
      check_json_post_endpoint(
        arr,
        config_file_path(arr, "/export_config_to_file"),
        "Import/export",
      )
    ["import_config_from_file", ..] | ["import-config-from-file", ..] =>
      check_json_post_endpoint(
        arr,
        config_file_path(arr, "/import_config_from_file"),
        "Import/export",
      )
    ["create_db_backup", ..] | ["create-db-backup", ..] =>
      check_json_post_endpoint(arr, "/create_db_backup", "Import/export")
    ["list_db_backups", ..] | ["list-db-backups", ..] =>
      check_usage_endpoint(arr, "/list_db_backups")
    ["restore_db_backup", ..] | ["restore-db-backup", ..] =>
      check_json_post_endpoint(
        arr,
        db_backup_filename_path(arr, "/restore_db_backup"),
        "Import/export",
      )
    ["rename_db_backup", ..] | ["rename-db-backup", ..] =>
      check_json_post_endpoint(arr, db_backup_rename_path(arr), "Import/export")
    ["delete_db_backup", ..] | ["delete-db-backup", ..] =>
      check_json_post_endpoint(
        arr,
        db_backup_filename_path(arr, "/delete_db_backup"),
        "Import/export",
      )
    ["parse_deeplink", ..] | ["parse-deeplink", ..] =>
      check_usage_endpoint(arr, deeplink_url_path(arr, "/parse_deeplink"))
    ["merge_deeplink_config", ..] | ["merge-deeplink-config", ..] =>
      check_json_post_endpoint(
        arr,
        deeplink_request_path(arr, "/merge_deeplink_config"),
        "Deeplink",
      )
    ["import_from_deeplink", ..] | ["import-from-deeplink", ..] =>
      check_json_post_endpoint(
        arr,
        deeplink_request_path(arr, "/import_from_deeplink"),
        "Deeplink",
      )
    ["import_from_deeplink_unified", ..]
    | ["import-from-deeplink-unified", ..] =>
      check_json_post_endpoint(
        arr,
        deeplink_request_path(arr, "/import_from_deeplink_unified"),
        "Deeplink",
      )
    ["webdav_test_connection", ..] | ["webdav-test-connection", ..] =>
      check_json_post_endpoint(
        arr,
        sync_settings_path(arr, "/webdav_test_connection"),
        "Sync",
      )
    ["webdav_sync_upload", ..] | ["webdav-sync-upload", ..] =>
      check_json_post_endpoint(arr, "/webdav_sync_upload", "Sync")
    ["webdav_sync_download", ..] | ["webdav-sync-download", ..] =>
      check_json_post_endpoint(arr, "/webdav_sync_download", "Sync")
    ["webdav_sync_save_settings", ..] | ["webdav-sync-save-settings", ..] =>
      check_json_post_endpoint(
        arr,
        sync_settings_path(arr, "/webdav_sync_save_settings"),
        "Sync",
      )
    ["webdav_sync_fetch_remote_info", ..]
    | ["webdav-sync-fetch-remote-info", ..] =>
      check_usage_endpoint(arr, "/webdav_sync_fetch_remote_info")
    ["s3_test_connection", ..] | ["s3-test-connection", ..] =>
      check_json_post_endpoint(
        arr,
        sync_settings_path(arr, "/s3_test_connection"),
        "Sync",
      )
    ["s3_sync_upload", ..] | ["s3-sync-upload", ..] =>
      check_json_post_endpoint(arr, "/s3_sync_upload", "Sync")
    ["s3_sync_download", ..] | ["s3-sync-download", ..] =>
      check_json_post_endpoint(arr, "/s3_sync_download", "Sync")
    ["s3_sync_save_settings", ..] | ["s3-sync-save-settings", ..] =>
      check_json_post_endpoint(
        arr,
        sync_settings_path(arr, "/s3_sync_save_settings"),
        "Sync",
      )
    ["s3_sync_fetch_remote_info", ..] | ["s3-sync-fetch-remote-info", ..] =>
      check_usage_endpoint(arr, "/s3_sync_fetch_remote_info")
    ["list_sessions", ..] | ["list-sessions", ..] =>
      check_usage_endpoint(arr, "/list_sessions")
    ["get_session_messages", ..] | ["get-session-messages", ..] =>
      check_usage_endpoint(arr, session_messages_path(arr))
    ["launch_session_terminal", ..] | ["launch-session-terminal", ..] =>
      check_json_post_endpoint(
        arr,
        launch_session_terminal_path(arr),
        "Session",
      )
    ["delete_session", ..] | ["delete-session", ..] =>
      check_json_post_endpoint(arr, delete_session_path(arr), "Session")
    ["delete_sessions", ..] | ["delete-sessions", ..] => delete_sessions(arr)
    ["read_omo_local_file", ..] | ["read-omo-local-file", ..] =>
      check_usage_endpoint(arr, "/read_omo_local_file")
    ["get_current_omo_provider_id", ..] | ["get-current-omo-provider-id", ..] =>
      check_usage_endpoint(arr, "/get_current_omo_provider_id")
    ["disable_current_omo", ..] | ["disable-current-omo", ..] =>
      check_json_post_endpoint(arr, "/disable_current_omo", "OMO")
    ["read_omo_slim_local_file", ..] | ["read-omo-slim-local-file", ..] =>
      check_usage_endpoint(arr, "/read_omo_slim_local_file")
    ["get_current_omo_slim_provider_id", ..]
    | ["get-current-omo-slim-provider-id", ..] =>
      check_usage_endpoint(arr, "/get_current_omo_slim_provider_id")
    ["disable_current_omo_slim", ..] | ["disable-current-omo-slim", ..] =>
      check_json_post_endpoint(arr, "/disable_current_omo_slim", "OMO")
    ["open_file_dialog", ..] | ["open-file-dialog", ..] =>
      check_usage_endpoint(arr, "/open_file_dialog")
    ["open_zip_file_dialog", ..] | ["open-zip-file-dialog", ..] =>
      check_usage_endpoint(arr, "/open_zip_file_dialog")
    ["get_installed_skills", ..] | ["get-installed-skills", ..] =>
      check_usage_endpoint(arr, "/get_installed_skills")
    ["get_skill_backups", ..] | ["get-skill-backups", ..] =>
      check_usage_endpoint(arr, "/get_skill_backups")
    ["delete_skill_backup", ..] | ["delete-skill-backup", ..] =>
      check_json_post_endpoint(
        arr,
        skill_backup_id_path(arr, "/delete_skill_backup"),
        "Skills",
      )
    ["restore_skill_backup", ..] | ["restore-skill-backup", ..] =>
      check_json_post_endpoint(arr, skill_restore_backup_path(arr), "Skills")
    ["install_skill_unified", ..] | ["install-skill-unified", ..] =>
      check_json_post_endpoint(
        arr,
        skill_install_path(arr, "/install_skill_unified"),
        "Skills",
      )
    ["uninstall_skill_unified", ..] | ["uninstall-skill-unified", ..] =>
      check_json_post_endpoint(
        arr,
        skill_id_path(arr, "/uninstall_skill_unified"),
        "Skills",
      )
    ["toggle_skill_app", ..] | ["toggle-skill-app", ..] =>
      check_json_post_endpoint(arr, skill_toggle_app_path(arr), "Skills")
    ["scan_unmanaged_skills", ..] | ["scan-unmanaged-skills", ..] =>
      check_usage_endpoint(arr, "/scan_unmanaged_skills")
    ["import_skills_from_apps", ..] | ["import-skills-from-apps", ..] =>
      import_skills_from_apps(arr)
    ["discover_available_skills", ..] | ["discover-available-skills", ..] =>
      check_usage_endpoint(arr, "/discover_available_skills")
    ["check_skill_updates", ..] | ["check-skill-updates", ..] =>
      check_usage_endpoint(arr, "/check_skill_updates")
    ["update_skill", ..] | ["update-skill", ..] =>
      check_json_post_endpoint(
        arr,
        skill_id_path(arr, "/update_skill"),
        "Skills",
      )
    ["migrate_skill_storage", ..] | ["migrate-skill-storage", ..] =>
      migrate_skill_storage(arr)
    ["search_skills_sh", ..] | ["search-skills-sh", ..] =>
      check_usage_endpoint(arr, skill_search_path(arr))
    ["get_skills", ..] | ["get-skills", ..] =>
      check_usage_endpoint(arr, "/get_skills")
    ["get_skills_for_app", ..] | ["get-skills-for-app", ..] =>
      check_usage_endpoint(arr, skill_app_path(arr, "/get_skills_for_app"))
    ["install_skill", ..] | ["install-skill", ..] =>
      check_json_post_endpoint(
        arr,
        skill_install_path(arr, "/install_skill"),
        "Skills",
      )
    ["install_skill_for_app", ..] | ["install-skill-for-app", ..] =>
      check_json_post_endpoint(
        arr,
        skill_install_path(arr, "/install_skill_for_app"),
        "Skills",
      )
    ["uninstall_skill", ..] | ["uninstall-skill", ..] =>
      check_json_post_endpoint(
        arr,
        skill_id_path(arr, "/uninstall_skill"),
        "Skills",
      )
    ["uninstall_skill_for_app", ..] | ["uninstall-skill-for-app", ..] =>
      check_json_post_endpoint(
        arr,
        skill_id_path(arr, "/uninstall_skill_for_app"),
        "Skills",
      )
    ["get_skill_repos", ..] | ["get-skill-repos", ..] =>
      check_usage_endpoint(arr, "/get_skill_repos")
    ["add_skill_repo", ..] | ["add-skill-repo", ..] =>
      check_json_post_endpoint(arr, skill_repo_add_path(arr), "Skills")
    ["remove_skill_repo", ..] | ["remove-skill-repo", ..] =>
      check_json_post_endpoint(arr, skill_repo_remove_path(arr), "Skills")
    ["install_skills_from_zip", ..] | ["install-skills-from-zip", ..] =>
      check_json_post_endpoint(arr, skill_zip_install_path(arr), "Skills")
    ["get_app_config_path", ..] | ["get-app-config-path", ..] =>
      check_usage_endpoint(arr, "/get_app_config_path")
    ["open_app_config_folder", ..] | ["open-app-config-folder", ..] =>
      check_usage_endpoint(arr, "/open_app_config_folder")
    ["get_claude_common_config_snippet", ..]
    | ["get-claude-common-config-snippet", ..] =>
      check_usage_endpoint(arr, "/get_claude_common_config_snippet")
    ["set_claude_common_config_snippet", ..]
    | ["set-claude-common-config-snippet", ..] =>
      set_config_snippet(
        arr,
        "/set_claude_common_config_snippet",
        app_required=false,
      )
    ["get_common_config_snippet", ..] | ["get-common-config-snippet", ..] =>
      check_usage_endpoint(
        arr,
        config_app_path(arr, "/get_common_config_snippet"),
      )
    ["set_common_config_snippet", ..] | ["set-common-config-snippet", ..] =>
      set_config_snippet(arr, "/set_common_config_snippet", app_required=true)
    ["extract_common_config_snippet", ..]
    | ["extract-common-config-snippet", ..] =>
      check_usage_endpoint(arr, extract_common_config_snippet_path(arr))
    ["check_env_conflicts", ..] | ["check-env-conflicts", ..] =>
      check_usage_endpoint(arr, config_app_path(arr, "/check_env_conflicts"))
    ["delete_env_vars", ..] | ["delete-env-vars", ..] => delete_env_vars(arr)
    ["restore_env_backup", ..] | ["restore-env-backup", ..] =>
      restore_env_backup(arr)
    ["get_claude_mcp_status", ..] | ["get-claude-mcp-status", ..] =>
      check_usage_endpoint(arr, "/get_claude_mcp_status")
    ["read_claude_mcp_config", ..] | ["read-claude-mcp-config", ..] =>
      check_usage_endpoint(arr, "/read_claude_mcp_config")
    ["upsert_claude_mcp_server", ..] | ["upsert-claude-mcp-server", ..] =>
      upsert_mcp_server(arr, "/upsert_claude_mcp_server")
    ["delete_claude_mcp_server", ..] | ["delete-claude-mcp-server", ..] =>
      delete_mcp_server(arr, "/delete_claude_mcp_server")
    ["validate_mcp_command", ..] | ["validate-mcp-command", ..] =>
      check_usage_endpoint(arr, mcp_validate_command_path(arr))
    ["get_mcp_config", ..] | ["get-mcp-config", ..] =>
      check_usage_endpoint(arr, mcp_app_path(arr, "/get_mcp_config"))
    ["upsert_mcp_server_in_config", ..] | ["upsert-mcp-server-in-config", ..] =>
      upsert_mcp_server(arr, "/upsert_mcp_server_in_config")
    ["delete_mcp_server_in_config", ..] | ["delete-mcp-server-in-config", ..] =>
      delete_mcp_server(arr, "/delete_mcp_server_in_config")
    ["set_mcp_enabled", ..] | ["set-mcp-enabled", ..] => set_mcp_enabled(arr)
    ["get_mcp_servers", ..] | ["get-mcp-servers", ..] =>
      check_usage_endpoint(arr, "/get_mcp_servers")
    ["upsert_mcp_server", ..] | ["upsert-mcp-server", ..] =>
      upsert_mcp_server(arr, "/upsert_mcp_server")
    ["delete_mcp_server", ..] | ["delete-mcp-server", ..] =>
      delete_mcp_server(arr, "/delete_mcp_server")
    ["toggle_mcp_app", ..] | ["toggle-mcp-app", ..] => toggle_mcp_app(arr)
    ["import_mcp_from_apps", ..] | ["import-mcp-from-apps", ..] =>
      check_json_post_endpoint(arr, "/import_mcp_from_apps", "MCP")
    ["get_prompts", ..] | ["get-prompts", ..] =>
      check_usage_endpoint(arr, prompt_app_path(arr, "/get_prompts"))
    ["upsert_prompt", ..] | ["upsert-prompt", ..] => upsert_prompt(arr)
    ["delete_prompt", ..] | ["delete-prompt", ..] => delete_prompt(arr)
    ["enable_prompt", ..] | ["enable-prompt", ..] => enable_prompt(arr)
    ["import_prompt_from_file", ..] | ["import-prompt-from-file", ..] =>
      import_prompt_from_file(arr)
    ["get_current_prompt_file_content", ..]
    | ["get-current-prompt-file-content", ..] =>
      check_usage_endpoint(
        arr,
        prompt_file_path(arr, "/get_current_prompt_file_content"),
      )
    ["import_opencode_providers_from_live", ..]
    | ["import-opencode-providers-from-live", ..] =>
      import_named_live_providers(arr, "opencode")
    ["import_openclaw_providers_from_live", ..]
    | ["import-openclaw-providers-from-live", ..] =>
      import_named_live_providers(arr, "openclaw")
    ["import_hermes_providers_from_live", ..]
    | ["import-hermes-providers-from-live", ..] =>
      import_named_live_providers(arr, "hermes")
    ["get_universal_providers", ..] | ["get-universal-providers", ..] =>
      check_universal_providers(arr)
    ["get_universal_provider", ..] | ["get-universal-provider", ..] =>
      check_universal_provider(arr)
    ["upsert_universal_provider", ..] | ["upsert-universal-provider", ..] =>
      upsert_universal_provider(arr)
    ["delete_universal_provider", ..] | ["delete-universal-provider", ..] =>
      delete_universal_provider(arr)
    ["sync_universal_provider", ..] | ["sync-universal-provider", ..] =>
      sync_universal_provider(arr)
    ["get_provider_presets", ..] | ["get-provider-presets", ..] =>
      check_provider_presets(arr)
    ["test_api_endpoints", ..] | ["test-api-endpoints", ..] =>
      test_api_endpoints(arr)
    ["update_providers_sort_order", ..] | ["update-providers-sort-order", ..] =>
      update_providers_sort_order(arr)
    ["get_custom_endpoints", ..] | ["get-custom-endpoints", ..] =>
      check_provider_custom_endpoints(arr)
    ["add_custom_endpoint", ..] | ["add-custom-endpoint", ..] =>
      add_provider_custom_endpoint(arr)
    ["remove_custom_endpoint", ..] | ["remove-custom-endpoint", ..] =>
      remove_provider_custom_endpoint(arr)
    ["update_endpoint_last_used", ..] | ["update-endpoint-last-used", ..] =>
      update_provider_endpoint_last_used(arr)
    ["get_usage_summary", ..] | ["get-usage-summary", ..] =>
      check_usage_summary(arr)
    ["get_usage_summary_by_app", ..] | ["get-usage-summary-by-app", ..] =>
      check_usage_apps(arr)
    ["get_usage_trends", ..] | ["get-usage-trends", ..] =>
      check_usage_trends(arr)
    ["get_provider_stats", ..] | ["get-provider-stats", ..] =>
      check_usage_providers(arr)
    ["get_model_stats", ..] | ["get-model-stats", ..] => check_usage_models(arr)
    ["get_request_logs", ..] | ["get-request-logs", ..] => check_usage_logs(arr)
    ["get_request_detail", ..] | ["get-request-detail", ..] =>
      check_usage_detail(arr)
    ["get_model_pricing", ..] | ["get-model-pricing", ..] =>
      check_usage_endpoint(arr, "/usage/model-pricing")
    ["update_model_pricing", ..] | ["update-model-pricing", ..] =>
      update_usage_pricing(arr)
    ["delete_model_pricing", ..] | ["delete-model-pricing", ..] =>
      delete_usage_pricing(arr)
    ["check_provider_limits", ..] | ["check-provider-limits", ..] =>
      check_usage_limits(arr)
    ["sync_session_usage", ..] | ["sync-session-usage", ..] =>
      sync_session_usage(arr)
    ["get_usage_data_sources", ..] | ["get-usage-data-sources", ..] =>
      check_usage_endpoint(arr, "/usage/data-sources")
    ["queryProviderUsage", ..]
    | ["query_provider_usage", ..]
    | ["query-provider-usage", ..] => check_usage_provider_script(arr)
    ["get_balance", ..] | ["get-balance", ..] => check_balance(arr)
    ["get_subscription_quota", ..] | ["get-subscription-quota", ..] =>
      check_subscription_quota(arr)
    ["get_codex_oauth_quota", ..] | ["get-codex-oauth-quota", ..] =>
      check_codex_oauth_quota(arr)
    ["get_codex_oauth_models", ..] | ["get-codex-oauth-models", ..] =>
      check_codex_oauth_models(arr)
    ["get_coding_plan_quota", ..] | ["get-coding-plan-quota", ..] =>
      check_coding_plan_quota(arr)
    ["testUsageScript", ..]
    | ["test_usage_script", ..]
    | ["test-usage-script", ..] => test_usage_script(arr)
    ["stream_check_provider", ..] | ["stream-check-provider", ..] =>
      stream_check_provider(arr)
    ["stream_check_all_providers", ..] | ["stream-check-all-providers", ..] =>
      stream_check_all_providers(arr)
    ["get_stream_check_config", ..] | ["get-stream-check-config", ..] =>
      check_usage_endpoint(arr, "/get_stream_check_config")
    ["save_stream_check_config", ..] | ["save-stream-check-config", ..] =>
      save_stream_check_config(arr)
    ["mcp", "status", ..] => check_usage_endpoint(arr, "/get_claude_mcp_status")
    ["mcp", "read-config", ..] =>
      check_usage_endpoint(arr, "/read_claude_mcp_config")
    ["mcp", "validate", ..] =>
      check_usage_endpoint(arr, mcp_validate_command_path(arr))
    ["mcp", "config", ..] =>
      check_usage_endpoint(arr, mcp_app_path(arr, "/get_mcp_config"))
    ["mcp", "upsert-config", ..] =>
      upsert_mcp_server(arr, "/upsert_mcp_server_in_config")
    ["mcp", "delete-config", ..] =>
      delete_mcp_server(arr, "/delete_mcp_server_in_config")
    ["mcp", "set-enabled", ..] => set_mcp_enabled(arr)
    ["mcp", "list", ..] => check_usage_endpoint(arr, "/get_mcp_servers")
    ["mcp", "upsert", ..] => upsert_mcp_server(arr, "/upsert_mcp_server")
    ["mcp", "delete", ..] => delete_mcp_server(arr, "/delete_mcp_server")
    ["mcp", "toggle", ..] => toggle_mcp_app(arr)
    ["mcp", "import", ..] =>
      check_json_post_endpoint(arr, "/import_mcp_from_apps", "MCP")
    ["prompt", "list", ..] | ["prompts", "list", ..] =>
      check_usage_endpoint(arr, prompt_app_path(arr, "/get_prompts"))
    ["prompt", "upsert", ..] | ["prompts", "upsert", ..] => upsert_prompt(arr)
    ["prompt", "delete", ..] | ["prompts", "delete", ..] => delete_prompt(arr)
    ["prompt", "enable", ..] | ["prompts", "enable", ..] => enable_prompt(arr)
    ["prompt", "import", ..] | ["prompts", "import", ..] =>
      import_prompt_from_file(arr)
    ["prompt", "current", ..] | ["prompts", "current", ..] =>
      check_usage_endpoint(
        arr,
        prompt_file_path(arr, "/get_current_prompt_file_content"),
      )
    ["proxy", "status", ..] => check_proxy_status(arr)
    ["proxy", "start-proxy-server", ..] => start_proxy_server(arr)
    ["proxy", "stop-proxy-server", ..] => stop_proxy_server(arr)
    ["proxy", "stop-proxy-with-restore", ..] => stop_proxy_with_restore(arr)
    ["proxy", "config", "set", ..] => update_proxy_config(arr)
    ["proxy", "update-config", ..] => update_proxy_config(arr)
    ["proxy", "config", ..] => check_proxy_config(arr)
    ["proxy", "global-config", "set", ..] => update_proxy_global_config(arr)
    ["proxy", "update-global-config", ..] => update_proxy_global_config(arr)
    ["proxy", "global-config", ..] => check_proxy_global_config(arr)
    ["proxy", "global-url", "set", ..] => set_global_proxy_url(arr)
    ["proxy", "set-global-url", ..] => set_global_proxy_url(arr)
    ["proxy", "global-url", ..] =>
      check_usage_endpoint(arr, "/get_global_proxy_url")
    ["proxy", "test-url", ..] => test_global_proxy_url(arr)
    ["proxy", "upstream-status", ..] =>
      check_usage_endpoint(arr, "/get_upstream_proxy_status")
    ["proxy", "scan-local", ..] =>
      check_usage_endpoint(arr, "/scan_local_proxies")
    ["proxy", "app-config", "set", ..] => update_proxy_app_config(arr)
    ["proxy", "update-app-config", ..] => update_proxy_app_config(arr)
    ["proxy", "app-config", ..] => check_proxy_app_config(arr)
    ["proxy", "default-cost-multiplier", "set", ..] =>
      set_proxy_default_cost_multiplier(arr)
    ["proxy", "set-default-cost-multiplier", ..] =>
      set_proxy_default_cost_multiplier(arr)
    ["proxy", "default-cost-multiplier", ..] =>
      check_proxy_default_cost_multiplier(arr)
    ["proxy", "pricing-model-source", "set", ..] =>
      set_proxy_pricing_model_source(arr)
    ["proxy", "set-pricing-model-source", ..] =>
      set_proxy_pricing_model_source(arr)
    ["proxy", "pricing-model-source", ..] =>
      check_proxy_pricing_model_source(arr)
    ["proxy", "provider-health", ..] => check_proxy_provider_health(arr)
    ["proxy", "circuit-breaker-config", "set", ..] =>
      update_proxy_circuit_breaker_config(arr)
    ["proxy", "circuit-breaker-config", ..] =>
      check_proxy_circuit_breaker_config(arr)
    ["proxy", "update-circuit-breaker-config", ..] =>
      update_proxy_circuit_breaker_config(arr)
    ["proxy", "circuit-breaker-stats", ..] =>
      check_proxy_circuit_breaker_stats(arr)
    ["proxy", "reset-circuit-breaker", ..] => reset_proxy_circuit_breaker(arr)
    ["proxy", "failover-queue", "add", ..] => add_proxy_failover_queue(arr)
    ["proxy", "failover-queue", "remove", ..] =>
      remove_proxy_failover_queue(arr)
    ["proxy", "failover-queue", ..] => check_proxy_failover_queue(arr)
    ["proxy", "get-failover-queue", ..] => check_proxy_failover_queue(arr)
    ["proxy", "available-failover-providers", ..] =>
      check_proxy_available_failover_providers(arr)
    ["proxy", "get-available-providers-for-failover", ..] =>
      check_proxy_available_failover_providers(arr)
    ["proxy", "add-to-failover-queue", ..] => add_proxy_failover_queue(arr)
    ["proxy", "remove-from-failover-queue", ..] =>
      remove_proxy_failover_queue(arr)
    ["proxy", "auto-failover-enabled", "set", ..] =>
      set_proxy_auto_failover_enabled(arr)
    ["proxy", "auto-failover-enabled", ..] =>
      check_proxy_auto_failover_enabled(arr)
    ["proxy", "get-auto-failover-enabled", ..] =>
      check_proxy_auto_failover_enabled(arr)
    ["proxy", "set-auto-failover-enabled", ..] =>
      set_proxy_auto_failover_enabled(arr)
    ["proxy", "takeover-status", "set", ..] => set_proxy_takeover_status(arr)
    ["proxy", "set-proxy-takeover-for-app", ..] =>
      set_proxy_takeover_status(arr)
    ["proxy", "takeover-status", ..] => check_proxy_takeover_status(arr)
    ["proxy", "is-live-takeover-active", ..] =>
      check_proxy_endpoint(arr, "/is_live_takeover_active")
    ["proxy", "switch-proxy-provider", ..] => switch_proxy_provider(arr)
    ["proxy", "running", ..] => check_proxy_running(arr)
    ["proxy", "is-proxy-running", ..] => check_proxy_running(arr)
    ["provider", "list", ..] | ["providers", "list", ..] => check_providers(arr)
    ["provider", "current", ..] | ["providers", "current", ..] =>
      check_current_provider(arr)
    ["provider", "add", ..] | ["providers", "add", ..] => add_provider(arr)
    ["provider", "update", ..] | ["providers", "update", ..] =>
      update_provider(arr)
    ["provider", "delete", ..] | ["providers", "delete", ..] =>
      delete_provider(arr)
    ["provider", "remove-live", ..] | ["providers", "remove-live", ..] =>
      remove_provider_from_live_config(arr)
    ["provider", "switch", ..] | ["providers", "switch", ..] =>
      switch_provider(arr)
    ["provider", "sync-live", ..] | ["providers", "sync-live", ..] =>
      sync_current_providers_live(arr)
    ["provider", "live-settings", ..] | ["providers", "live-settings", ..] =>
      check_live_provider_settings(arr)
    ["settings", "get", ..] => check_usage_endpoint(arr, "/get_settings")
    ["settings", "save", ..] => save_settings(arr)
    ["settings", "app-config-dir", "set", ..] =>
      set_app_config_dir_override(arr)
    ["settings", "app-config-dir", ..] =>
      check_usage_endpoint(arr, "/get_app_config_dir_override")
    ["settings", "auto-launch", "set", ..] => set_auto_launch(arr)
    ["settings", "auto-launch", ..] =>
      check_usage_endpoint(arr, "/get_auto_launch_status")
    ["settings", "rectifier", "set", ..] =>
      set_moon_json_config(arr, "/set_rectifier_config", "--config", "Settings")
    ["settings", "rectifier", ..] =>
      check_usage_endpoint(arr, "/get_rectifier_config")
    ["settings", "optimizer", "set", ..] =>
      set_moon_json_config(arr, "/set_optimizer_config", "--config", "Settings")
    ["settings", "optimizer", ..] =>
      check_usage_endpoint(arr, "/get_optimizer_config")
    ["settings", "copilot-optimizer", "set", ..] =>
      set_moon_json_config(
        arr, "/set_copilot_optimizer_config", "--config", "Settings",
      )
    ["settings", "copilot-optimizer", ..] =>
      check_usage_endpoint(arr, "/get_copilot_optimizer_config")
    ["settings", "log", "set", ..] =>
      set_moon_json_config(arr, "/set_log_config", "--config", "Settings")
    ["settings", "log", ..] => check_usage_endpoint(arr, "/get_log_config")
    ["plugin", "claude", "status", ..] =>
      check_usage_endpoint(arr, "/get_claude_plugin_status")
    ["plugin", "claude", "config", ..] =>
      check_usage_endpoint(arr, "/read_claude_plugin_config")
    ["plugin", "claude", "apply", ..] => apply_claude_plugin_config(arr)
    ["plugin", "claude", "applied", ..] =>
      check_usage_endpoint(arr, "/is_claude_plugin_applied")
    ["plugin", "claude", "onboarding-skip", ..] =>
      check_json_post_endpoint(arr, "/apply_claude_onboarding_skip", "Plugin")
    ["plugin", "claude", "onboarding-clear", ..] =>
      check_json_post_endpoint(arr, "/clear_claude_onboarding_skip", "Plugin")
    ["workspace", "memory", "list", ..] =>
      check_usage_endpoint(arr, "/list_daily_memory_files")
    ["workspace", "memory", "read", ..] =>
      check_usage_endpoint(
        arr,
        workspace_filename_path(arr, "/read_daily_memory_file"),
      )
    ["workspace", "memory", "write", ..] =>
      write_workspace_content(arr, "/write_daily_memory_file", "Workspace")
    ["workspace", "memory", "search", ..] =>
      check_usage_endpoint(
        arr,
        workspace_query_path(arr, "/search_daily_memory_files"),
      )
    ["workspace", "memory", "delete", ..] =>
      delete_workspace_resource(arr, "/delete_daily_memory_file", "Workspace")
    ["workspace", "read", ..] =>
      check_usage_endpoint(
        arr,
        workspace_filename_path(arr, "/read_workspace_file"),
      )
    ["workspace", "write", ..] =>
      write_workspace_content(arr, "/write_workspace_file", "Workspace")
    ["workspace", "open", ..] =>
      check_json_post_endpoint(
        arr,
        workspace_subdir_path(arr, "/open_workspace_directory"),
        "Workspace",
      )
    ["provider", "live-ids", ..] | ["providers", "live-ids", ..] =>
      check_provider_live_ids(arr)
    ["provider", "live-get", ..] | ["providers", "live-get", ..] =>
      check_provider_live_provider(arr)
    ["provider", "import-live", ..] | ["providers", "import-live", ..] =>
      import_provider_live(arr)
    ["provider", "universal", "list", ..]
    | ["providers", "universal", "list", ..] => check_universal_providers(arr)
    ["provider", "universal", "get", ..]
    | ["providers", "universal", "get", ..] => check_universal_provider(arr)
    ["provider", "universal", "upsert", ..]
    | ["providers", "universal", "upsert", ..] => upsert_universal_provider(arr)
    ["provider", "universal", "delete", ..]
    | ["providers", "universal", "delete", ..] => delete_universal_provider(arr)
    ["provider", "universal", "sync", ..]
    | ["providers", "universal", "sync", ..] => sync_universal_provider(arr)
    ["provider", "presets", "list", ..]
    | ["providers", "presets", "list", ..] => check_provider_presets(arr)
    ["provider", "test-endpoints", ..] | ["providers", "test-endpoints", ..] =>
      test_api_endpoints(arr)
    ["provider", "sort-order", "set", ..]
    | ["providers", "sort-order", "set", ..] => update_providers_sort_order(arr)
    ["provider", "endpoints", "list", ..]
    | ["providers", "endpoints", "list", ..] =>
      check_provider_custom_endpoints(arr)
    ["provider", "endpoints", "add", ..]
    | ["providers", "endpoints", "add", ..] => add_provider_custom_endpoint(arr)
    ["provider", "endpoints", "remove", ..]
    | ["providers", "endpoints", "remove", ..] =>
      remove_provider_custom_endpoint(arr)
    ["provider", "endpoints", "touch", ..]
    | ["providers", "endpoints", "touch", ..] =>
      update_provider_endpoint_last_used(arr)
    ["usage", "logs", ..] => check_usage_logs(arr)
    ["usage", "get-request-logs", ..] => check_usage_logs(arr)
    ["usage", "summary", ..] => check_usage_summary(arr)
    ["usage", "get-usage-summary", ..] => check_usage_summary(arr)
    ["usage", "apps", ..] => check_usage_apps(arr)
    ["usage", "get-usage-summary-by-app", ..] => check_usage_apps(arr)
    ["usage", "trends", ..] => check_usage_trends(arr)
    ["usage", "get-usage-trends", ..] => check_usage_trends(arr)
    ["usage", "limits", ..] => check_usage_limits(arr)
    ["usage", "check-provider-limits", ..] => check_usage_limits(arr)
    ["usage", "sync", ..] => sync_session_usage(arr)
    ["usage", "sync-session-usage", ..] => sync_session_usage(arr)
    ["usage", "providers", ..] => check_usage_providers(arr)
    ["usage", "get-provider-stats", ..] => check_usage_providers(arr)
    ["usage", "models", ..] => check_usage_models(arr)
    ["usage", "get-model-stats", ..] => check_usage_models(arr)
    ["usage", "sources", ..] => check_usage_endpoint(arr, "/usage/data-sources")
    ["usage", "get-usage-data-sources", ..] =>
      check_usage_endpoint(arr, "/usage/data-sources")
    ["usage", "query-provider-usage", ..] => check_usage_provider_script(arr)
    ["usage", "balance", ..] => check_balance(arr)
    ["usage", "quota", ..] => check_subscription_quota(arr)
    ["usage", "get-subscription-quota", ..] => check_subscription_quota(arr)
    ["usage", "codex-oauth-quota", ..] => check_codex_oauth_quota(arr)
    ["usage", "get-codex-oauth-quota", ..] => check_codex_oauth_quota(arr)
    ["usage", "codex-oauth-models", ..] => check_codex_oauth_models(arr)
    ["usage", "get-codex-oauth-models", ..] => check_codex_oauth_models(arr)
    ["usage", "coding-plan", ..] => check_coding_plan_quota(arr)
    ["usage", "get-coding-plan-quota", ..] => check_coding_plan_quota(arr)
    ["usage", "test-usage-script", ..] => test_usage_script(arr)
    ["usage", "pricing", "set", ..] => update_usage_pricing(arr)
    ["usage", "update-model-pricing", ..] => update_usage_pricing(arr)
    ["usage", "pricing", "delete", ..] => delete_usage_pricing(arr)
    ["usage", "delete-model-pricing", ..] => delete_usage_pricing(arr)
    ["usage", "pricing", ..] =>
      check_usage_endpoint(arr, "/usage/model-pricing")
    ["usage", "get-model-pricing", ..] =>
      check_usage_endpoint(arr, "/usage/model-pricing")
    ["usage", "detail", ..] => check_usage_detail(arr)
    ["usage", "get-request-detail", ..] => check_usage_detail(arr)
    ["help"] | ["--help"] | ["-h"] => print_help()
    ["version"] | ["--version"] | ["-v"] => println("moonstat v0.1.0")
    _ => print_help()
  }
}
