///|
pub async fn start(args : ArrayView[String]) -> Unit {
  let arr = args.to_array()
  match arr[1:] {
    ["start", ..] => start_gateway(arr)
    ["login", ..] => do_login(arr)
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
      set_ccs_json_config(arr, "/set_rectifier_config", "--config", "Settings")
    ["get_optimizer_config", ..] | ["get-optimizer-config", ..] =>
      check_usage_endpoint(arr, "/get_optimizer_config")
    ["set_optimizer_config", ..] | ["set-optimizer-config", ..] =>
      set_ccs_json_config(arr, "/set_optimizer_config", "--config", "Settings")
    ["get_copilot_optimizer_config", ..]
    | ["get-copilot-optimizer-config", ..] =>
      check_usage_endpoint(arr, "/get_copilot_optimizer_config")
    ["set_copilot_optimizer_config", ..]
    | ["set-copilot-optimizer-config", ..] =>
      set_ccs_json_config(
        arr, "/set_copilot_optimizer_config", "--config", "Settings",
      )
    ["get_log_config", ..] | ["get-log-config", ..] =>
      check_usage_endpoint(arr, "/get_log_config")
    ["set_log_config", ..] | ["set-log-config", ..] =>
      set_ccs_json_config(arr, "/set_log_config", "--config", "Settings")
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
    ["get_pricing_model_source", ..] | ["get-pricing-model-source", ..] =>
      check_proxy_pricing_model_source(arr)
    ["set_pricing_model_source", ..] | ["set-pricing-model-source", ..] =>
      set_proxy_pricing_model_source(arr)
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
    ["delete_env_vars", ..] | ["delete-env-vars", ..] =>
      check_json_post_endpoint(arr, "/delete_env_vars", "Env")
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
      set_ccs_json_config(arr, "/set_rectifier_config", "--config", "Settings")
    ["settings", "rectifier", ..] =>
      check_usage_endpoint(arr, "/get_rectifier_config")
    ["settings", "optimizer", "set", ..] =>
      set_ccs_json_config(arr, "/set_optimizer_config", "--config", "Settings")
    ["settings", "optimizer", ..] =>
      check_usage_endpoint(arr, "/get_optimizer_config")
    ["settings", "copilot-optimizer", "set", ..] =>
      set_ccs_json_config(
        arr, "/set_copilot_optimizer_config", "--config", "Settings",
      )
    ["settings", "copilot-optimizer", ..] =>
      check_usage_endpoint(arr, "/get_copilot_optimizer_config")
    ["settings", "log", "set", ..] =>
      set_ccs_json_config(arr, "/set_log_config", "--config", "Settings")
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

///|
async fn main {
  let args = @os.args()
  start(args)
}

///|
fn print_help() -> Unit {
  println("Moonstat - Anthropic to OpenAI Codex OAuth Gateway")
  println("")
  println("Usage: moonstat <command> [options]")
  println("")
  println("Commands:")
  println("  start       Start the gateway server")
  println("  install     Install hosts reroute (requires sudo)")
  println("  uninstall   Remove hosts reroute (requires sudo)")
  println(
    "  claude-desktop install    Configure Claude Desktop gateway profile",
  )
  println("  claude-desktop uninstall  Remove Claude Desktop gateway profile")
  println("  claude-desktop status     Show Claude Desktop profile status")
  println(
    "  codex install             Configure Codex config.toml for Moonstat",
  )
  println("  codex uninstall           Remove Moonstat Codex config block")
  println("  codex status              Show Codex config.toml Moonstat status")
  println(
    "  models fetch              Fetch provider models using ccs-compatible logic",
  )
  println("  models candidates         Print /v1/models candidate URLs")
  println("  stream-check provider     Alias for ccs stream_check_provider")
  println(
    "  stream-check all          Alias for ccs stream_check_all_providers",
  )
  println("  stream-check config       Alias for ccs get_stream_check_config")
  println("  stream-check config set   Alias for ccs save_stream_check_config")
  println("  suite manifest            Print Moon suite service manifest")
  println("  suite status              Print Moon suite status contract")
  println("  suite write-status        Write ~/.moonstat/suite-status.json")
  println("  status      Check reroute and gateway status")
  println("  stats       Show gateway traffic statistics")
  println("  proxy status           Show ccs-style proxy server status")
  println(
    "  <ccs_proxy_command>    Direct alias for CCS proxy/failover command names",
  )
  println(
    "  <ccs_provider_command> Direct alias for CCS provider command names",
  )
  println("  <ccs_usage_command>    Direct alias for CCS usage command names")
  println(
    "  <ccs_stream_command>   Direct alias for CCS stream check command names",
  )
  println("  mcp list/upsert/delete/toggle  Manage ccs-style MCP servers")
  println("  mcp config/upsert-config       Manage app MCP config view")
  println("  prompt list/upsert/delete      Manage ccs-style prompt records")
  println(
    "  proxy start-proxy-server  Enable proxy routing and print server info",
  )
  println(
    "  proxy stop-proxy-server   Disable proxy routing when no takeover is active",
  )
  println(
    "  proxy stop-proxy-with-restore  Disable proxy routing and clear takeover state",
  )
  println("  proxy config           Show ccs-style proxy server config")
  println("  proxy config set       Update ccs-style legacy proxy config")
  println("  proxy global-config    Show ccs-style global proxy config")
  println("  proxy global-config set  Update ccs-style global proxy config")
  println("  proxy app-config       Show ccs-style app proxy config")
  println("  proxy app-config set   Update ccs-style app proxy config")
  println("  proxy default-cost-multiplier  Show ccs-style app cost multiplier")
  println(
    "  proxy default-cost-multiplier set  Set ccs-style app cost multiplier",
  )
  println("  proxy pricing-model-source     Show ccs-style app pricing mode")
  println("  proxy pricing-model-source set     Set ccs-style app pricing mode")
  println("  proxy provider-health          Show ccs-style provider health")
  println("  proxy circuit-breaker-config   Show ccs-style circuit config")
  println("  proxy circuit-breaker-config set  Update ccs-style circuit config")
  println("  proxy circuit-breaker-stats    Show ccs-style circuit stats")
  println("  proxy reset-circuit-breaker    Reset provider circuit breaker")
  println("  proxy failover-queue           Show ccs-style failover queue")
  println("  proxy failover-queue add       Add provider to failover queue")
  println(
    "  proxy failover-queue remove    Remove provider from failover queue",
  )
  println("  proxy available-failover-providers  Show providers outside queue")
  println("  proxy auto-failover-enabled    Show app auto-failover boolean")
  println("  proxy auto-failover-enabled set  Set app auto-failover boolean")
  println("  proxy takeover-status  Show ccs-style app takeover status")
  println("  proxy takeover-status set  Set ccs-style app takeover state")
  println("  proxy is-live-takeover-active  Show ccs takeover active boolean")
  println("  proxy switch-proxy-provider  Hot-switch current app provider")
  println("  proxy running          Show ccs-style proxy running boolean")
  println("  proxy is-proxy-running  Alias for ccs is_proxy_running")
  println("  provider list          Alias for ccs get_providers")
  println("  provider current       Alias for ccs get_current_provider")
  println("  provider add           Alias for ccs add_provider")
  println("  provider update        Alias for ccs update_provider")
  println("  provider delete        Alias for ccs delete_provider")
  println(
    "  provider remove-live   Alias for ccs remove_provider_from_live_config",
  )
  println("  provider switch        Alias for ccs switch_provider")
  println("  provider live-settings Alias for ccs read_live_provider_settings")
  println("  provider test-endpoints Alias for ccs test_api_endpoints")
  println("  provider sort-order set Alias for ccs update_providers_sort_order")
  println("  provider endpoints list    Alias for ccs get_custom_endpoints")
  println("  provider endpoints add     Alias for ccs add_custom_endpoint")
  println("  provider endpoints remove  Alias for ccs remove_custom_endpoint")
  println(
    "  provider endpoints touch   Alias for ccs update_endpoint_last_used",
  )
  println(
    "  settings get/save          Alias for ccs get_settings/save_settings",
  )
  println(
    "  settings app-config-dir    Show or set ccs app_config_dir override",
  )
  println("  settings auto-launch       Show or set ccs auto launch state")
  println("  settings rectifier         Show or set ccs rectifier config")
  println("  settings optimizer         Show or set ccs optimizer config")
  println(
    "  settings copilot-optimizer Show or set ccs Copilot optimizer config",
  )
  println("  settings log               Show or set ccs log config")
  println(
    "  plugin claude status/config/apply/applied  Manage ccs Claude plugin state",
  )
  println(
    "  plugin claude onboarding-skip/onboarding-clear  Toggle onboarding skip",
  )
  println("  workspace read/write/open  Manage ccs OpenClaw workspace files")
  println(
    "  workspace memory list/read/write/search/delete  Manage daily memory",
  )
  println("  usage logs  Show ccs-style recent proxy_request_logs")
  println("  usage get-request-logs  Alias for ccs get_request_logs")
  println("  usage summary    Show ccs-style usage summary")
  println("  usage get-usage-summary  Alias for ccs get_usage_summary")
  println("  usage apps       Show ccs-style usage summary by app")
  println(
    "  usage get-usage-summary-by-app  Alias for ccs get_usage_summary_by_app",
  )
  println("  usage trends     Show ccs-style hourly/daily usage trends")
  println("  usage get-usage-trends  Alias for ccs get_usage_trends")
  println("  usage limits     Show ccs-style provider limit status")
  println("  usage check-provider-limits  Alias for ccs check_provider_limits")
  println(
    "  usage sync       Sync ccs-style Claude/Codex/Gemini/OpenCode session logs",
  )
  println("  usage sync-session-usage  Alias for ccs sync_session_usage")
  println("  usage providers  Show ccs-style provider statistics")
  println("  usage get-provider-stats  Alias for ccs get_provider_stats")
  println("  usage models     Show ccs-style model statistics")
  println("  usage get-model-stats  Alias for ccs get_model_stats")
  println("  usage sources    Show ccs-style data source breakdown")
  println(
    "  usage get-usage-data-sources  Alias for ccs get_usage_data_sources",
  )
  println("  usage query-provider-usage  Alias for ccs queryProviderUsage")
  println("  usage test-usage-script     Alias for ccs testUsageScript")
  println("  usage pricing    Show ccs-style editable model pricing")
  println("  usage get-model-pricing  Alias for ccs get_model_pricing")
  println("  usage pricing set       Upsert ccs-style model pricing")
  println("  usage update-model-pricing  Alias for ccs update_model_pricing")
  println("  usage pricing delete    Delete ccs-style model pricing")
  println("  usage delete-model-pricing  Alias for ccs delete_model_pricing")
  println("  usage detail     Show one ccs-style request detail by id")
  println("  usage get-request-detail  Alias for ccs get_request_detail")
  println("  login       Login to OpenAI Codex OAuth")
  println("  health      Check gateway health")
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
  println("  --id <id>          Provider id for ccs provider CRUD commands")
  println("  --name <name>      Provider display name for provider add/update")
  println("  --base-url <url>   Provider API base URL for provider add/update")
  println("  --api-key <key>    Provider API key for provider add/update")
  println("  --category <kind>  Provider category for provider add/update")
  println("  --endpoint-url <url> Provider custom endpoint URL")
  println("  --app <app>         App id for ccs usage script commands")
  println("  --server <json>     MCP server JSON for ccs MCP upsert commands")
  println("  --command <cmd>     MCP command name for validation/upsert")
  println("  --content <text>    Prompt content for ccs prompt upsert commands")
  println("  --script-code <json> JSON UsageResult for ccs testUsageScript")
  println("  --value <value>    Value for ccs proxy scalar setter commands")
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
  println("  sudo moonstat install          # Install hosts reroute")
  println("  moonstat start                 # Start gateway on 127.0.0.1:15721")
  println("  moonstat start --port 80       # Start gateway on port 80")
  println("  moonstat claude-desktop install --port 15721")
  println("  moonstat codex install --port 15721 --model gpt-5")
  println(
    "  moonstat models fetch --base-url https://api.example.com --api-key sk-...",
  )
  println("  moonstat suite write-status --port 15721")
  println("  claude                         # Use Claude CLI through moonstat")
  println("  moonstat proxy status          # Show ccs-style proxy status")
  println("  moonstat proxy start-proxy-server")
  println(
    "  moonstat proxy switch-proxy-provider --app-type codex --provider-id codex-oauth",
  )
  println("  moonstat provider list --app codex")
  println(
    "  moonstat provider add --app codex --id custom --name Custom --base-url https://api.example.com/v1 --api-key sk-...",
  )
  println("  moonstat provider switch --app codex --id custom")
  println(
    "  moonstat provider endpoints add --app codex --id custom --endpoint-url https://api.backup.example.com/v1",
  )
  println(
    "  moonstat stream-check provider --app-type codex --provider-id codex-oauth",
  )
  println(
    "  moonstat stream-check all --app-type codex --proxy-targets-only true",
  )
  println(
    "  moonstat stream-check config set --codex-model gpt-5.5@low --timeout-secs 45",
  )
  println(
    "  moonstat mcp upsert --id filesystem --command npx --name Filesystem",
  )
  println("  moonstat mcp toggle --id filesystem --app codex --enabled true")
  println(
    "  moonstat prompt upsert --app codex --id review --name Review --content 'Review this change'",
  )
  println("  moonstat proxy app-config --app-type codex")
  println(
    "  moonstat proxy global-config set --proxy-enabled true --listen-address 127.0.0.1 --listen-port 15721",
  )
  println(
    "  moonstat proxy app-config set --app-type codex --enabled true --max-retries 3",
  )
  println(
    "  moonstat proxy default-cost-multiplier set --app-type codex --value 1.25",
  )
  println(
    "  moonstat proxy pricing-model-source set --app-type codex --value request",
  )
  println(
    "  moonstat proxy takeover-status set --app-type codex --enabled true",
  )
  println(
    "  moonstat proxy provider-health --app-type codex --provider-id codex-oauth",
  )
  println(
    "  moonstat proxy circuit-breaker-config set --failure-threshold 4 --success-threshold 2 --timeout-seconds 60 --error-rate-threshold 0.6 --min-requests 10",
  )
  println("  moonstat proxy failover-queue --app-type codex")
  println(
    "  moonstat proxy failover-queue add --app-type codex --provider-id codex-oauth",
  )
  println(
    "  moonstat proxy auto-failover-enabled set --app-type codex --enabled true",
  )
  println("  moonstat stats                 # Show traffic counters")
  println("  moonstat usage logs            # Show recent request logs")
  println("  moonstat usage summary         # Show aggregate token/cost usage")
  println("  moonstat usage trends --start-date 0 --end-date 86400")
  println("  moonstat usage limits --provider-id codex-oauth --app-type codex")
  println(
    "  moonstat usage sync --projects-dir ~/.claude/projects --codex-dir ~/.codex --gemini-dir ~/.gemini --opencode-db-path ~/.local/share/opencode/opencode.db",
  )
  println(
    "  moonstat usage pricing set --model-id gpt-x --display-name GPT-X --input-cost 1 --output-cost 2 --cache-read-cost 0.1 --cache-creation-cost 0",
  )
  println("  moonstat usage pricing delete --model-id gpt-x")
  println("  moonstat usage detail --request-id req_x")
  println("  moonstat uninstall             # Remove hosts reroute")
}

///|
async fn start_gateway(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-5")
  logger.info("Starting Moonstat Gateway on \{host}:\{port}")
  logger.info("Using Codex model: \{model}")
  let gateway = @moonstat.Gateway::new(port~, host~, model~)
  logger.info("Gateway started on \{gateway.host()}:\{gateway.port()}")
  gateway.start()
}

///|
async fn do_login(_args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  logger.info("Starting OpenAI Codex OAuth login flow...")
  try {
    let creds = @codex.start_oauth_flow()
    logger.info("Login successful!")
    logger.info("Email: \{@codex.extract_token_claims(creds.idToken).email}")
    @codex.save_credentials(creds)
    logger.info("Credentials saved to ~/.moonstat/codex-credentials.json")
  } catch {
    err => logger.error("Login failed: \{err}")
  }
}

///|
async fn check_health(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.get("/health")
    if response.code == 200 {
      let body = client.read_all().text()
      println("Gateway health: \{body}")
    } else {
      logger.error("Health check failed: \{response.code}")
    }
  } catch {
    err => logger.error("Health check failed: \{err}")
  }
}

///|
async fn check_stats(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.get("/stats")
    if response.code == 200 {
      let body = client.read_all().text()
      println(body)
    } else {
      logger.error("Stats check failed: \{response.code}")
    }
  } catch {
    err => logger.error("Stats check failed: \{err}")
  }
}

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
async fn set_openclaw_default_model(args : Array[String]) -> Unit {
  guard openclaw_default_model_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --primary")
    return
  }
  check_json_post_endpoint(args, path, "OpenClaw")
}

///|
async fn set_openclaw_agents_defaults(args : Array[String]) -> Unit {
  let path = match
    suite_json_config_path(args, "/set_openclaw_agents_defaults", "--defaults") {
    Some(path) => Some(path)
    None =>
      openclaw_default_model_path_with_base(
        args, "/set_openclaw_agents_defaults",
      )
  }
  guard path is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --defaults or --primary")
    return
  }
  check_json_post_endpoint(args, path, "OpenClaw")
}

///|
async fn set_openclaw_env(args : Array[String]) -> Unit {
  let path = match suite_json_config_path(args, "/set_openclaw_env", "--env") {
    Some(path) => Some(path)
    None => openclaw_key_value_path(args, "/set_openclaw_env")
  }
  guard path is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --env or --key")
    return
  }
  check_json_post_endpoint(args, path, "OpenClaw")
}

///|
async fn set_openclaw_tools(args : Array[String]) -> Unit {
  let path = suite_json_config_path(args, "/set_openclaw_tools", "--tools").unwrap_or(
    openclaw_tools_path(args),
  )
  check_json_post_endpoint(args, path, "OpenClaw")
}

///|
async fn set_suite_json_config(
  args : Array[String],
  base_path : String,
  flag : String,
) -> Unit {
  guard suite_json_config_path(args, base_path, flag) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required \{flag}")
    return
  }
  check_json_post_endpoint(args, path, "Suite")
}

///|
async fn save_settings(args : Array[String]) -> Unit {
  guard parse_string_arg_any(args, "--settings", "--config") is Some(settings) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --settings JSON")
    return
  }
  post_json_body_endpoint(args, "/save_settings", settings, "Settings")
}

///|
async fn set_ccs_json_config(
  args : Array[String],
  base_path : String,
  flag : String,
  label : String,
) -> Unit {
  guard ccs_json_config_path(args, base_path, flag) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required \{flag} JSON or config field flags")
    return
  }
  check_json_post_endpoint(args, path, label)
}

///|
async fn set_app_config_dir_override(args : Array[String]) -> Unit {
  guard app_config_dir_override_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --path or --clear")
    return
  }
  check_json_post_endpoint(args, path, "Settings")
}

///|
async fn set_auto_launch(args : Array[String]) -> Unit {
  guard set_auto_launch_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
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
async fn write_workspace_content(
  args : Array[String],
  base_path : String,
  label : String,
) -> Unit {
  guard workspace_content_path(args, base_path) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --filename and --content")
    return
  }
  check_json_post_endpoint(args, path, label)
}

///|
async fn delete_workspace_resource(
  args : Array[String],
  base_path : String,
  label : String,
) -> Unit {
  guard workspace_filename_path_optional(args, base_path) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --filename")
    return
  }
  check_json_delete_endpoint(args, path, label)
}

///|
async fn check_hermes_memory(args : Array[String]) -> Unit {
  guard hermes_kind_path(args, "/get_hermes_memory") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --kind memory|user")
    return
  }
  check_json_endpoint(args, path, "Hermes")
}

///|
async fn set_hermes_memory(args : Array[String]) -> Unit {
  guard hermes_memory_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --kind and --content")
    return
  }
  check_json_post_endpoint(args, path, "Hermes")
}

///|
async fn set_hermes_memory_enabled(args : Array[String]) -> Unit {
  guard hermes_memory_enabled_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --kind and --enabled")
    return
  }
  check_json_post_endpoint(args, path, "Hermes")
}

///|
async fn set_config_snippet(
  args : Array[String],
  base_path : String,
  app_required~ : Bool,
) -> Unit {
  guard config_snippet_path(args, base_path, app_required~) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --snippet")
    return
  }
  check_json_post_endpoint(args, path, "Config")
}

///|
async fn restore_env_backup(args : Array[String]) -> Unit {
  guard restore_env_backup_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --backup-path")
    return
  }
  check_json_post_endpoint(args, path, "Env")
}

///|
async fn upsert_mcp_server(args : Array[String], base_path : String) -> Unit {
  guard mcp_upsert_path(args, base_path) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required MCP server args: --id or --server")
    return
  }
  check_json_post_endpoint(args, path, "MCP")
}

///|
async fn delete_mcp_server(args : Array[String], base_path : String) -> Unit {
  guard mcp_id_path(args, base_path) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_delete_endpoint(args, path, "MCP")
}

///|
async fn set_mcp_enabled(args : Array[String]) -> Unit {
  guard mcp_enabled_path(args, "/set_mcp_enabled") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required MCP args: --id --enabled")
    return
  }
  check_json_post_endpoint(args, path, "MCP")
}

///|
async fn toggle_mcp_app(args : Array[String]) -> Unit {
  guard mcp_enabled_path(args, "/toggle_mcp_app") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required MCP args: --id --enabled")
    return
  }
  check_json_post_endpoint(args, path, "MCP")
}

///|
async fn upsert_prompt(args : Array[String]) -> Unit {
  guard prompt_upsert_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required prompt args: --id")
    return
  }
  check_json_post_endpoint(args, path, "Prompt")
}

///|
async fn delete_prompt(args : Array[String]) -> Unit {
  guard prompt_id_path(args, "/delete_prompt") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_delete_endpoint(args, path, "Prompt")
}

///|
async fn enable_prompt(args : Array[String]) -> Unit {
  guard prompt_id_path(args, "/enable_prompt") is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --id")
    return
  }
  check_json_post_endpoint(args, path, "Prompt")
}

///|
async fn import_prompt_from_file(args : Array[String]) -> Unit {
  check_json_post_endpoint(
    args,
    prompt_file_path(args, "/import_prompt_from_file"),
    "Prompt",
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
async fn test_api_endpoints(args : Array[String]) -> Unit {
  guard provider_test_endpoints_path(args) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required --url or --urls")
    return
  }
  check_json_endpoint(args, path, "Provider")
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
  let app_type = parse_string_arg_any(args, "--app-type", "--appType").unwrap_or(
    "claude",
  )
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
  let app_type = parse_string_arg_any(args, "--app-type", "--appType").unwrap_or(
    "claude",
  )
  Some(
    "\{path}?provider_id=\{cli_url_encode(provider_id)}&app_type=\{cli_url_encode(app_type)}",
  )
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
fn openclaw_default_model_path(args : Array[String]) -> String? {
  openclaw_default_model_path_with_base(args, "/set_openclaw_default_model")
}

///|
fn openclaw_default_model_path_with_base(
  args : Array[String],
  base_path : String,
) -> String? {
  guard parse_string_arg(args, "--primary") is Some(primary) else {
    return None
  }
  let query : Array[String] = [cli_query_pair("primary", primary)]
  match parse_string_arg(args, "--fallbacks") {
    Some(fallbacks) => query.push(cli_query_pair("fallbacks", fallbacks))
    None => ()
  }
  Some("\{base_path}?\{query.join("&")}")
}

///|
fn suite_json_config_path(
  args : Array[String],
  base_path : String,
  flag : String,
) -> String? {
  guard parse_string_arg(args, flag) is Some(raw) else { return None }
  let key = if flag.has_prefix("--") { flag[2:].to_owned() } else { flag }
  Some("\{base_path}?\{cli_query_pair(key, raw)}")
}

///|
fn openclaw_key_value_path(args : Array[String], base_path : String) -> String? {
  guard parse_string_arg(args, "--key") is Some(key) else { return None }
  let value = parse_string_arg(args, "--value").unwrap_or("")
  Some(
    "\{base_path}?\{cli_query_pair("key", key)}&\{cli_query_pair("value", value)}",
  )
}

///|
fn openclaw_tools_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--profile") {
    Some(profile) => query.push(cli_query_pair("profile", profile))
    None => ()
  }
  match parse_string_arg(args, "--allow") {
    Some(allow) => query.push(cli_query_pair("allow", allow))
    None => ()
  }
  match parse_string_arg(args, "--deny") {
    Some(deny) => query.push(cli_query_pair("deny", deny))
    None => ()
  }
  cli_path_with_query("/set_openclaw_tools", query)
}

///|
fn hermes_kind_path(args : Array[String], base_path : String) -> String? {
  guard parse_string_arg(args, "--kind") is Some(kind) else { return None }
  Some("\{base_path}?\{cli_query_pair("kind", kind)}")
}

///|
fn hermes_memory_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--kind") is Some(kind) else { return None }
  let content = match parse_string_arg(args, "--content") {
    Some(value) => value
    None =>
      match parse_string_arg(args, "--value") {
        Some(value) => value
        None => parse_string_arg(args, "--text").unwrap_or("")
      }
  }
  Some(
    "/set_hermes_memory?\{cli_query_pair("kind", kind)}&\{cli_query_pair("content", content)}",
  )
}

///|
fn hermes_memory_enabled_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--kind") is Some(kind) else { return None }
  guard parse_string_arg(args, "--enabled") is Some(enabled) else {
    return None
  }
  Some(
    "/set_hermes_memory_enabled?\{cli_query_pair("kind", kind)}&\{cli_query_pair("enabled", enabled)}",
  )
}

///|
fn hermes_web_ui_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--path") {
    Some(path) => query.push(cli_query_pair("path", path))
    None => ()
  }
  match parse_string_arg(args, "--port") {
    Some(port) => query.push(cli_query_pair("port", port))
    None => ()
  }
  cli_path_with_query("/open_hermes_web_ui", query)
}

///|
fn config_app_arg(args : Array[String]) -> String {
  parse_string_arg_any(args, "--app", "--appType").unwrap_or(
    parse_string_arg(args, "--app-type").unwrap_or("claude"),
  )
}

///|
fn config_app_path(args : Array[String], base_path : String) -> String {
  "\{base_path}?\{cli_query_pair("app", config_app_arg(args))}"
}

///|
fn app_config_dir_override_path(args : Array[String]) -> String? {
  match parse_string_arg(args, "--path") {
    Some(path) =>
      Some("/set_app_config_dir_override?\{cli_query_pair("path", path)}")
    None =>
      match parse_string_arg(args, "--clear") {
        Some(value) =>
          if value == "true" || value == "1" || value == "yes" {
            Some("/set_app_config_dir_override?path=")
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
      Some("/set_auto_launch?\{cli_query_pair("enabled", enabled)}")
    None => None
  }
}

///|
fn ccs_json_config_path(
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
  for flag_name in ccs_json_config_flag_names() {
    match parse_string_arg(args, "--\{flag_name}") {
      Some(value) => query.push(cli_query_pair(flag_name, value))
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
fn ccs_json_config_flag_names() -> Array[String] {
  [
    "enabled", "requestThinkingSignature", "request_thinking_signature", "requestThinkingBudget",
    "request_thinking_budget", "requestMediaFallback", "request_media_fallback",
    "requestMediaHeuristic", "request_media_heuristic", "thinkingOptimizer", "thinking_optimizer",
    "cacheInjection", "cache_injection", "cacheTtl", "cache_ttl", "requestClassification",
    "request_classification", "toolResultMerging", "tool_result_merging", "compactDetection",
    "compact_detection", "deterministicRequestId", "deterministic_request_id", "subagentDetection",
    "subagent_detection", "warmupDowngrade", "warmup_downgrade", "warmupModel", "warmup_model",
    "stripThinking", "strip_thinking", "level",
  ]
}

///|
fn apply_claude_plugin_config_path(args : Array[String]) -> String {
  match parse_string_arg(args, "--official") {
    Some(official) =>
      "/apply_claude_plugin_config?\{cli_query_pair("official", official)}"
    None => "/apply_claude_plugin_config"
  }
}

///|
fn workspace_filename_arg(args : Array[String]) -> String? {
  parse_string_arg_any(args, "--filename", "--file")
}

///|
fn workspace_filename_path(args : Array[String], base_path : String) -> String {
  workspace_filename_path_optional(args, base_path).unwrap_or(base_path)
}

///|
fn workspace_filename_path_optional(
  args : Array[String],
  base_path : String,
) -> String? {
  match workspace_filename_arg(args) {
    Some(filename) =>
      Some("\{base_path}?\{cli_query_pair("filename", filename)}")
    None => None
  }
}

///|
fn workspace_content_path(args : Array[String], base_path : String) -> String? {
  guard workspace_filename_arg(args) is Some(filename) else { return None }
  guard parse_string_arg(args, "--content") is Some(content) else {
    return None
  }
  Some(
    "\{base_path}?\{cli_query_pair("filename", filename)}&\{cli_query_pair("content", content)}",
  )
}

///|
fn workspace_query_path(args : Array[String], base_path : String) -> String {
  match parse_string_arg(args, "--query") {
    Some(query) => "\{base_path}?\{cli_query_pair("query", query)}"
    None => base_path
  }
}

///|
fn workspace_subdir_path(args : Array[String], base_path : String) -> String {
  match parse_string_arg(args, "--subdir") {
    Some(subdir) => "\{base_path}?\{cli_query_pair("subdir", subdir)}"
    None => base_path
  }
}

///|
fn pick_directory_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--default-path", "--defaultPath") {
    Some(path) => query.push(cli_query_pair("defaultPath", path))
    None => ()
  }
  cli_path_with_query("/pick_directory", query)
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
  match parse_string_arg_any(args, "--settings-config", "--settingsConfig") {
    Some(settings) => query.push(cli_query_pair("settingsConfig", settings))
    None => ()
  }
  "/extract_common_config_snippet?\{query.join("&")}"
}

///|
fn restore_env_backup_path(args : Array[String]) -> String? {
  guard parse_string_arg_any(args, "--backup-path", "--backupPath")
    is Some(path) else {
    return None
  }
  Some("/restore_env_backup?\{cli_query_pair("backupPath", path)}")
}

///|
fn mcp_app_path(args : Array[String], base_path : String) -> String {
  "\{base_path}?\{cli_query_pair("app", config_app_arg(args))}"
}

///|
fn mcp_server_id_arg(args : Array[String]) -> String? {
  match parse_string_arg(args, "--id") {
    Some(id) => Some(id)
    None => parse_string_arg_any(args, "--server-id", "--serverId")
  }
}

///|
fn mcp_id_path(args : Array[String], base_path : String) -> String? {
  guard mcp_server_id_arg(args) is Some(id) else { return None }
  Some("\{base_path}?\{cli_query_pair("id", id)}")
}

///|
fn mcp_validate_command_path(args : Array[String]) -> String {
  match parse_string_arg_any(args, "--command", "--cmd") {
    Some(command) =>
      "/validate_mcp_command?\{cli_query_pair("command", command)}"
    None => "/validate_mcp_command"
  }
}

///|
fn mcp_server_json_from_args(args : Array[String], id : String) -> String {
  let name = parse_string_arg(args, "--name").unwrap_or(id)
  let spec : Map[String, Json] = {}
  match parse_string_arg_any(args, "--command", "--cmd") {
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
  match parse_string_arg(args, "--server") {
    Some(server) => query.push(cli_query_pair("server", server))
    None =>
      match mcp_server_id_arg(args) {
        Some(id) =>
          query.push(
            cli_query_pair("server", mcp_server_json_from_args(args, id)),
          )
        None => return None
      }
  }
  query.push(cli_query_pair("app", config_app_arg(args)))
  match parse_string_arg_any(args, "--sync-other-side", "--syncOtherSide") {
    Some(value) => query.push(cli_query_pair("syncOtherSide", value))
    None => ()
  }
  Some("\{base_path}?\{query.join("&")}")
}

///|
fn mcp_enabled_path(args : Array[String], base_path : String) -> String? {
  guard mcp_server_id_arg(args) is Some(id) else { return None }
  guard parse_string_arg(args, "--enabled") is Some(enabled) else {
    return None
  }
  Some(
    "\{base_path}?\{cli_query_pair("id", id)}&\{cli_query_pair("app", config_app_arg(args))}&\{cli_query_pair("enabled", enabled)}",
  )
}

///|
fn prompt_app_path(args : Array[String], base_path : String) -> String {
  "\{base_path}?\{cli_query_pair("app", config_app_arg(args))}"
}

///|
fn prompt_id_path(args : Array[String], base_path : String) -> String? {
  guard parse_string_arg_any(args, "--id", "--promptId") is Some(id) else {
    return None
  }
  Some(
    "\{base_path}?\{cli_query_pair("app", config_app_arg(args))}&\{cli_query_pair("id", id)}",
  )
}

///|
fn prompt_upsert_path(args : Array[String]) -> String? {
  let query : Array[String] = [cli_query_pair("app", config_app_arg(args))]
  match parse_string_arg(args, "--prompt") {
    Some(prompt) => query.push(cli_query_pair("prompt", prompt))
    None => {
      guard parse_string_arg_any(args, "--id", "--promptId") is Some(id) else {
        return None
      }
      query.push(cli_query_pair("id", id))
      match parse_string_arg(args, "--name") {
        Some(name) => query.push(cli_query_pair("name", name))
        None => ()
      }
      match parse_string_arg(args, "--content") {
        Some(content) => query.push(cli_query_pair("content", content))
        None => ()
      }
      match parse_string_arg(args, "--description") {
        Some(description) =>
          query.push(cli_query_pair("description", description))
        None => ()
      }
      match parse_string_arg(args, "--enabled") {
        Some(enabled) => query.push(cli_query_pair("enabled", enabled))
        None => ()
      }
    }
  }
  Some("/upsert_prompt?\{query.join("&")}")
}

///|
fn prompt_file_path(args : Array[String], base_path : String) -> String {
  let query : Array[String] = [cli_query_pair("app", config_app_arg(args))]
  match parse_string_arg(args, "--path") {
    Some(path) => query.push(cli_query_pair("path", path))
    None => ()
  }
  cli_path_with_query(base_path, query)
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
  let app_type = parse_string_arg_any(args, "--app-type", "--appType").unwrap_or(
    "claude",
  )
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
  let app_type = parse_string_arg_any(args, "--app-type", "--appType").unwrap_or(
    "claude",
  )
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
  let app_type = parse_string_arg_any(args, "--app-type", "--appType").unwrap_or(
    "claude",
  )
  Some(
    "/proxy/takeover-status?app_type=\{cli_url_encode(app_type)}&enabled=\{cli_url_encode(enabled)}",
  )
}

///|
fn proxy_auto_failover_enabled_path(args : Array[String]) -> String? {
  guard parse_string_arg(args, "--enabled") is Some(enabled) else {
    return None
  }
  let app_type = parse_string_arg_any(args, "--app-type", "--appType").unwrap_or(
    "claude",
  )
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
fn stream_check_all_path(args : Array[String]) -> String {
  let app_type = match parse_string_arg_any(args, "--app-type", "--appType") {
    Some(value) => value
    None => parse_string_arg(args, "--app").unwrap_or("claude")
  }
  let query : Array[String] = [cli_query_pair("appType", app_type)]
  match
    parse_string_arg_any(args, "--proxy-targets-only", "--proxyTargetsOnly") {
    Some(value) => query.push(cli_query_pair("proxyTargetsOnly", value))
    None => ()
  }
  "/stream_check_all_providers?\{query.join("&")}"
}

///|
fn stream_check_config_update_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--timeout-secs", "--timeoutSecs") {
    Some(value) => query.push(cli_query_pair("timeoutSecs", value))
    None => ()
  }
  match parse_string_arg_any(args, "--max-retries", "--maxRetries") {
    Some(value) => query.push(cli_query_pair("maxRetries", value))
    None => ()
  }
  match
    parse_string_arg_any(
      args, "--degraded-threshold-ms", "--degradedThresholdMs",
    ) {
    Some(value) => query.push(cli_query_pair("degradedThresholdMs", value))
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
  match parse_string_arg_any(args, "--test-prompt", "--testPrompt") {
    Some(value) => query.push(cli_query_pair("testPrompt", value))
    None => ()
  }
  if query.is_empty() {
    "/save_stream_check_config"
  } else {
    "/save_stream_check_config?\{query.join("&")}"
  }
}

///|
async fn check_usage_logs(args : Array[String]) -> Unit {
  check_usage_endpoint(args, usage_logs_path(args))
}

///|
async fn check_usage_summary(args : Array[String]) -> Unit {
  check_usage_endpoint(
    args,
    usage_filtered_path(args, "/usage/summary", app_filter=true),
  )
}

///|
async fn check_usage_apps(args : Array[String]) -> Unit {
  check_usage_endpoint(
    args,
    usage_filtered_path(args, "/usage/summary/by-app", app_filter=false),
  )
}

///|
async fn check_usage_trends(args : Array[String]) -> Unit {
  check_usage_endpoint(args, usage_trends_path(args))
}

///|
async fn check_usage_limits(args : Array[String]) -> Unit {
  check_usage_endpoint(args, usage_limits_path(args))
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
async fn save_stream_check_config(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  let path = stream_check_config_update_path(args)
  try {
    let client = @http.Client::new(url, headers={})
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
async fn check_usage_models(args : Array[String]) -> Unit {
  check_usage_endpoint(
    args,
    usage_filtered_path(args, "/usage/model-stats", app_filter=true),
  )
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
async fn test_usage_script(args : Array[String]) -> Unit {
  guard usage_provider_script_path(args, "/testUsageScript", true) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required usage script args: --provider-id --app")
    return
  }
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.post(path, "{}")
    let body = client.read_all().text()
    if response.code == 200 {
      println(body)
    } else {
      logger.error("Usage script test failed: \{response.code} \{body}")
    }
  } catch {
    err => logger.error("Usage script test failed: \{err}")
  }
}

///|
async fn sync_session_usage(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  let path = usage_sync_path(args)
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.post(path, "{}")
    let body = client.read_all().text()
    if response.code == 200 {
      println(body)
    } else {
      logger.error("Usage sync failed: \{response.code} \{body}")
    }
  } catch {
    err => logger.error("Usage sync failed: \{err}")
  }
}

///|
fn usage_trends_path(args : Array[String]) -> String {
  usage_filtered_path(args, "/usage/trends", app_filter=true)
}

///|
fn usage_logs_path(args : Array[String]) -> String {
  let query = usage_date_app_query(args, app_filter=true)
  match parse_string_arg(args, "--page") {
    Some(value) => query.push(cli_query_pair("page", value))
    None => ()
  }
  match parse_string_arg_any(args, "--page-size", "--pageSize") {
    Some(value) => query.push(cli_query_pair("pageSize", value))
    None => ()
  }
  match parse_string_arg_any(args, "--provider-name", "--providerName") {
    Some(value) => query.push(cli_query_pair("providerName", value))
    None => ()
  }
  match parse_string_arg(args, "--model") {
    Some(value) => query.push(cli_query_pair("model", value))
    None => ()
  }
  match parse_string_arg_any(args, "--status-code", "--statusCode") {
    Some(value) => query.push(cli_query_pair("statusCode", value))
    None => ()
  }
  cli_path_with_query("/usage/logs", query)
}

///|
fn usage_filtered_path(
  args : Array[String],
  base_path : String,
  app_filter~ : Bool,
) -> String {
  cli_path_with_query(base_path, usage_date_app_query(args, app_filter~))
}

///|
fn usage_date_app_query(
  args : Array[String],
  app_filter~ : Bool,
) -> Array[String] {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--start-date", "--startDate") {
    Some(value) => query.push(cli_query_pair("start_date", value))
    None => ()
  }
  match parse_string_arg_any(args, "--end-date", "--endDate") {
    Some(value) => query.push(cli_query_pair("end_date", value))
    None => ()
  }
  if app_filter {
    match parse_string_arg_any(args, "--app-type", "--appType") {
      Some(value) => query.push(cli_query_pair("app_type", value))
      None => ()
    }
  }
  query
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
fn usage_limits_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg_any(args, "--provider-id", "--providerId") {
    Some(value) => query.push(cli_query_pair("provider_id", value))
    None => ()
  }
  match parse_string_arg_any(args, "--app-type", "--appType") {
    Some(value) => query.push(cli_query_pair("app_type", value))
    None => ()
  }
  match parse_string_arg(args, "--daily-limit-usd") {
    Some(value) => query.push(cli_query_pair("daily_limit_usd", value))
    None => ()
  }
  match parse_string_arg(args, "--monthly-limit-usd") {
    Some(value) => query.push(cli_query_pair("monthly_limit_usd", value))
    None => ()
  }
  if query.is_empty() {
    "/usage/provider-limits"
  } else {
    "/usage/provider-limits?\{query.join("&")}"
  }
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
fn usage_sync_path(args : Array[String]) -> String {
  let query : Array[String] = []
  match parse_string_arg(args, "--projects-dir") {
    Some(value) => query.push(cli_query_pair("projects_dir", value))
    None => ()
  }
  match parse_string_arg(args, "--codex-dir") {
    Some(value) => query.push(cli_query_pair("codex_dir", value))
    None => ()
  }
  match parse_string_arg(args, "--gemini-dir") {
    Some(value) => query.push(cli_query_pair("gemini_dir", value))
    None => ()
  }
  match parse_string_arg(args, "--opencode-export-path") {
    Some(value) => query.push(cli_query_pair("opencode_export_path", value))
    None => ()
  }
  match parse_string_arg(args, "--opencode-db-path") {
    Some(value) => query.push(cli_query_pair("opencode_db_path", value))
    None => ()
  }
  if query.is_empty() {
    "/usage/sync-session"
  } else {
    "/usage/sync-session?\{query.join("&")}"
  }
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
    if response.code == 204 {
      println("Deleted model pricing")
    } else {
      let body = client.read_all().text()
      logger.error("Usage pricing delete failed: \{response.code} \{body}")
    }
  } catch {
    err => logger.error("Usage pricing delete failed: \{err}")
  }
}

///|
async fn check_usage_endpoint(args : Array[String], path : String) -> Unit {
  check_json_endpoint(args, path, "Usage")
}

///|
async fn check_json_endpoint(
  args : Array[String],
  path : String,
  label : String,
) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.get(path)
    if response.code == 200 {
      let body = client.read_all().text()
      println(body)
    } else {
      logger.error("\{label} check failed: \{response.code}")
    }
  } catch {
    err => logger.error("\{label} check failed: \{err}")
  }
}

///|
async fn check_json_post_endpoint(
  args : Array[String],
  path : String,
  label : String,
) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.post(path, "{}")
    if response.code == 200 {
      let body = client.read_all().text()
      println(body)
    } else {
      logger.error("\{label} update failed: \{response.code}")
    }
  } catch {
    err => logger.error("\{label} update failed: \{err}")
  }
}

///|
async fn post_json_body_endpoint(
  args : Array[String],
  path : String,
  body : String,
  label : String,
) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={
      "Content-Type": "application/json",
    })
    defer client.close()
    let response = client.post(path, body)
    if response.code == 200 {
      let body = client.read_all().text()
      println(body)
    } else {
      logger.error("\{label} update failed: \{response.code}")
    }
  } catch {
    err => logger.error("\{label} update failed: \{err}")
  }
}

///|
async fn check_json_delete_endpoint(
  args : Array[String],
  path : String,
  label : String,
) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    client.request(@http.RequestMethod::Delete, path)
    let response = client.end_request()
    let body = client.read_all().text()
    if response.code == 200 {
      println(body)
    } else {
      logger.error("\{label} delete failed: \{response.code} \{body}")
    }
  } catch {
    err => logger.error("\{label} delete failed: \{err}")
  }
}

///|
async fn check_usage_detail(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  guard parse_string_arg_any(args, "--request-id", "--requestId")
    is Some(request_id) else {
    logger.error("Missing required --request-id")
    return
  }
  check_usage_endpoint(
    args,
    "/usage/request-detail/\{cli_url_encode(request_id)}",
  )
}

///|
async fn check_status(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let url = parse_string_arg(args, "--url").unwrap_or("http://localhost:15721")

  // 检查 hosts reroute 状态
  let hosts_installed = @hosts.is_reroute_installed()
  if hosts_installed {
    logger.info("Hosts reroute is installed")
  } else {
    logger.warn("Hosts reroute is NOT installed")
  }

  // 检查网关是否在运行
  try {
    let client = @http.Client::new(url, headers={})
    defer client.close()
    let response = client.get("/status")
    if response.code == 200 {
      let body = client.read_all().text()
      logger.info("Gateway is running: \{body}")
    } else {
      logger.warn("Gateway is NOT running")
    }
  } catch {
    _ => logger.warn("Gateway is NOT running")
  }

  // 检查凭据
  let creds_result : Result[@codex.Credentials, Error] = try? @codex.load_credentials()
  match creds_result {
    Ok(_) => logger.info("Credentials loaded")
    Err(_) => logger.warn("Credentials NOT loaded, please run: moonstat login")
  }
}

///|
async fn install_reroute(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let port = parse_int_arg(args, "--port", default=15721)

  logger.info("Installing hosts reroute for port \{port}...")
  let result = @hosts.install_and_flush(port)
  match result {
    Ok(_) => {
      logger.info("Hosts reroute installed successfully!")
      logger.info("Now you can use: moonstat start --port \{port}")
      logger.info("Then Anthropic API requests will route through moonstat.")
    }
    Err(e) => logger.error("Failed to install: \{e}")
  }
}

///|
async fn uninstall_reroute() -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())

  logger.info("Removing hosts reroute...")
  let result = @hosts.uninstall_and_flush()
  match result {
    Ok(_) => logger.info("Hosts reroute removed successfully!")
    Err(e) => logger.error("Failed to uninstall: \{e}")
  }
}

///|
async fn install_claude_desktop(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let token = parse_string_arg(args, "--token")
  logger.info("Installing Claude Desktop gateway profile...")
  let result = @claude_desktop.install_proxy_profile(host, port, token~)
  match result {
    Ok(installed) => {
      logger.info("Claude Desktop profile installed")
      logger.info("Gateway base URL: \{installed.base_url}")
      logger.info("Profile: \{installed.profile_path}")
      logger.info("Token saved for Moonstat gateway auth")
    }
    Err(e) => logger.error(e)
  }
}

///|
async fn uninstall_claude_desktop() -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  logger.info("Removing Claude Desktop gateway profile...")
  let result = @claude_desktop.uninstall_proxy_profile()
  match result {
    Ok(_) => logger.info("Claude Desktop profile removed")
    Err(e) => logger.error(e)
  }
}

///|
async fn status_claude_desktop() -> Unit {
  let status = @claude_desktop.status()
  println(
    Json::object({
      "configured": Json::boolean(status.configured),
      "profile_path": Json::string(status.profile_path),
      "meta_path": Json::string(status.meta_path),
      "token_configured": Json::boolean(status.token_configured),
    }).stringify(indent=2),
  )
}

///|
async fn install_codex(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-5")
  logger.info("Installing Codex config.toml Moonstat provider...")
  let result = @codex_config.install_proxy_config(host, port, model)
  match result {
    Ok(installed) => {
      logger.info("Codex Moonstat provider installed")
      logger.info("Config: \{installed.config_path}")
      logger.info("Gateway base URL: \{installed.base_url}")
      logger.info("Model: \{installed.model}")
    }
    Err(e) => logger.error(e)
  }
}

///|
async fn uninstall_codex() -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  logger.info("Removing Codex config.toml Moonstat provider...")
  let result = @codex_config.uninstall_proxy_config()
  match result {
    Ok(_) => logger.info("Codex Moonstat provider removed")
    Err(e) => logger.error(e)
  }
}

///|
async fn status_codex() -> Unit {
  let status = @codex_config.status()
  println(
    Json::object({
      "configured": Json::boolean(status.configured),
      "config_path": Json::string(status.config_path),
      "base_url": match status.base_url {
        Some(value) => Json::string(value)
        None => Json::null()
      },
      "model": match status.model {
        Some(value) => Json::string(value)
        None => Json::null()
      },
    }).stringify(indent=2),
  )
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
async fn print_model_candidates(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  guard parse_string_arg(args, "--base-url") is Some(base_url) else {
    logger.error("Missing required --base-url")
    return
  }
  let is_full_url = has_flag(args, "--full-url") ||
    has_flag(args, "--is-full-url")
  let models_url = parse_string_arg(args, "--models-url")
  match
    @moonstat.build_models_url_candidates(base_url, is_full_url, models_url) {
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
fn provider_models_to_json(models : Array[@moonstat.FetchedModel]) -> Json {
  Json::array(models.map(provider_model_to_json))
}

///|
fn provider_model_to_json(model : @moonstat.FetchedModel) -> Json {
  provider_model_fields_to_json(model.id, model.owned_by)
}

///|
fn provider_model_fields_to_json(id : String, owned_by : String?) -> Json {
  Json::object({
    "id": Json::string(id),
    "ownedBy": match owned_by {
      Some(value) => Json::string(value)
      None => Json::null()
    },
  })
}

///|
fn print_suite_manifest(args : Array[String]) -> Unit {
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-5")
  println(
    @moonstat.moonstat_suite_manifest_json(host~, port~, model~).stringify(
      indent=2,
    ),
  )
}

///|
fn print_suite_status(args : Array[String]) -> Unit {
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-5")
  println(
    @moonstat.moonstat_suite_status_json(host~, port~, model~).stringify(
      indent=2,
    ),
  )
}

///|
async fn write_suite_status(args : Array[String]) -> Unit {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  let host = parse_string_arg(args, "--host").unwrap_or("127.0.0.1")
  let port = parse_int_arg(args, "--port", default=15721)
  let model = parse_string_arg(args, "--model").unwrap_or("gpt-5")
  let path = parse_string_arg(args, "--path").unwrap_or(
    @moonstat.default_moonstat_suite_status_path(),
  )
  let written = @moonstat.write_moonstat_suite_status(
    path~,
    host~,
    port~,
    model~,
  )
  logger.info("Moon suite status written: \{written}")
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
fn parse_string_arg_any(
  args : Array[String],
  left_name : String,
  right_name : String,
) -> String? {
  match parse_string_arg(args, left_name) {
    Some(value) => Some(value)
    None => parse_string_arg(args, right_name)
  }
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
    Some(s) => {
      let result : Result[Int, Error] = try? @strconv.parse_int(s[:], base=10)
      match result {
        Ok(n) => n
        Err(_) => default
      }
    }
    None => default
  }
}
