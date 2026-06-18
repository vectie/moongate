///|
priv struct CliCommandSpec {
  id : String
  patterns : Array[String]
}

///|
fn registered_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "login", patterns: ["login"] },
    {
      id: "auth_start_login",
      patterns: ["auth start-login", "auth_start_login", "auth-start-login"],
    },
    {
      id: "auth_poll_for_account",
      patterns: [
        "auth poll", "auth poll-for-account", "auth_poll_for_account", "auth-poll-for-account",
      ],
    },
    {
      id: "auth_list_accounts",
      patterns: [
        "auth list", "auth list-accounts", "auth_list_accounts", "auth-list-accounts",
      ],
    },
    {
      id: "auth_get_status",
      patterns: ["auth status", "auth_get_status", "auth-get-status"],
    },
    {
      id: "auth_remove_account",
      patterns: [
        "auth remove", "auth remove-account", "auth_remove_account", "auth-remove-account",
      ],
    },
    {
      id: "auth_set_default_account",
      patterns: [
        "auth default", "auth set-default-account", "auth_set_default_account", "auth-set-default-account",
      ],
    },
    {
      id: "auth_logout",
      patterns: ["auth logout", "auth_logout", "auth-logout"],
    },
    {
      id: "copilot_start_device_flow",
      patterns: [
        "copilot start-device-flow", "copilot_start_device_flow", "copilot-start-device-flow",
      ],
    },
    {
      id: "copilot_poll_for_account",
      patterns: [
        "copilot poll", "copilot poll-for-account", "copilot_poll_for_account", "copilot-poll-for-account",
      ],
    },
    {
      id: "copilot_poll_for_auth",
      patterns: [
        "copilot poll-for-auth", "copilot_poll_for_auth", "copilot-poll-for-auth",
      ],
    },
    {
      id: "copilot_list_accounts",
      patterns: [
        "copilot list", "copilot list-accounts", "copilot_list_accounts", "copilot-list-accounts",
      ],
    },
    {
      id: "copilot_get_auth_status",
      patterns: [
        "copilot auth-status", "copilot status", "copilot_get_auth_status", "copilot-get-auth-status",
      ],
    },
    {
      id: "copilot_is_authenticated",
      patterns: [
        "copilot is-authenticated", "copilot_is_authenticated", "copilot-is-authenticated",
      ],
    },
    {
      id: "copilot_logout",
      patterns: ["copilot logout", "copilot_logout", "copilot-logout"],
    },
    {
      id: "copilot_remove_account",
      patterns: [
        "copilot remove", "copilot remove-account", "copilot_remove_account", "copilot-remove-account",
      ],
    },
    {
      id: "copilot_set_default_account",
      patterns: [
        "copilot default", "copilot set-default-account", "copilot_set_default_account",
        "copilot-set-default-account",
      ],
    },
    {
      id: "copilot_get_token",
      patterns: ["copilot token", "copilot_get_token", "copilot-get-token"],
    },
    {
      id: "copilot_get_token_for_account",
      patterns: [
        "copilot_get_token_for_account", "copilot-get-token-for-account",
      ],
    },
    {
      id: "copilot_get_models",
      patterns: ["copilot models", "copilot_get_models", "copilot-get-models"],
    },
    {
      id: "copilot_get_models_for_account",
      patterns: [
        "copilot_get_models_for_account", "copilot-get-models-for-account",
      ],
    },
    {
      id: "copilot_get_usage",
      patterns: ["copilot usage", "copilot_get_usage", "copilot-get-usage"],
    },
    {
      id: "copilot_get_usage_for_account",
      patterns: [
        "copilot_get_usage_for_account", "copilot-get-usage-for-account",
      ],
    },
    {
      id: "stream_check_provider",
      patterns: [
        "stream-check provider", "stream-check stream-check-provider", "stream_check_provider",
        "stream-check-provider",
      ],
    },
    {
      id: "stream_check_all_providers",
      patterns: [
        "stream-check all", "stream-check stream-check-all-providers", "stream_check_all_providers",
        "stream-check-all-providers",
      ],
    },
    {
      id: "save_stream_check_config",
      patterns: [
        "stream-check config set", "stream-check save-stream-check-config", "save_stream_check_config",
        "save-stream-check-config",
      ],
    },
    {
      id: "get_stream_check_config",
      patterns: [
        "stream-check config", "stream-check get-stream-check-config", "get_stream_check_config",
        "get-stream-check-config",
      ],
    },
    {
      id: "update_proxy_config",
      patterns: [
        "proxy config set", "proxy update-config", "update_proxy_config", "update-proxy-config",
      ],
    },
    {
      id: "get_proxy_config",
      patterns: ["proxy config", "get_proxy_config", "get-proxy-config"],
    },
    {
      id: "update_global_proxy_config",
      patterns: [
        "proxy global-config set", "proxy update-global-config", "update_global_proxy_config",
        "update-global-proxy-config",
      ],
    },
    {
      id: "get_global_proxy_config",
      patterns: [
        "proxy global-config", "get_global_proxy_config", "get-global-proxy-config",
      ],
    },
    {
      id: "set_global_proxy_url",
      patterns: [
        "proxy global-url set", "proxy set-global-url", "set_global_proxy_url", "set-global-proxy-url",
      ],
    },
    {
      id: "get_global_proxy_url",
      patterns: [
        "proxy global-url", "get_global_proxy_url", "get-global-proxy-url",
      ],
    },
    {
      id: "update_proxy_config_for_app",
      patterns: [
        "proxy app-config set", "proxy update-app-config", "update_proxy_config_for_app",
        "update-proxy-config-for-app",
      ],
    },
    {
      id: "get_proxy_config_for_app",
      patterns: [
        "proxy app-config", "get_proxy_config_for_app", "get-proxy-config-for-app",
      ],
    },
    {
      id: "set_default_cost_multiplier",
      patterns: [
        "proxy default-cost-multiplier set", "proxy set-default-cost-multiplier",
        "set_default_cost_multiplier", "set-default-cost-multiplier",
      ],
    },
    {
      id: "get_default_cost_multiplier",
      patterns: [
        "proxy default-cost-multiplier", "get_default_cost_multiplier", "get-default-cost-multiplier",
      ],
    },
    {
      id: "set_pricing_model_source",
      patterns: [
        "proxy pricing-model-source set", "proxy set-pricing-model-source", "set_pricing_model_source",
        "set-pricing-model-source",
      ],
    },
    {
      id: "get_pricing_model_source",
      patterns: [
        "proxy pricing-model-source", "get_pricing_model_source", "get-pricing-model-source",
      ],
    },
    {
      id: "update_circuit_breaker_config",
      patterns: [
        "proxy circuit-breaker-config set", "proxy update-circuit-breaker-config",
        "update_circuit_breaker_config", "update-circuit-breaker-config",
      ],
    },
    {
      id: "get_circuit_breaker_config",
      patterns: [
        "proxy circuit-breaker-config", "get_circuit_breaker_config", "get-circuit-breaker-config",
      ],
    },
    {
      id: "add_to_failover_queue",
      patterns: [
        "proxy failover-queue add", "proxy add-to-failover-queue", "add_to_failover_queue",
        "add-to-failover-queue",
      ],
    },
    {
      id: "remove_from_failover_queue",
      patterns: [
        "proxy failover-queue remove", "proxy remove-from-failover-queue", "remove_from_failover_queue",
        "remove-from-failover-queue",
      ],
    },
    {
      id: "get_failover_queue",
      patterns: [
        "proxy failover-queue", "proxy get-failover-queue", "get_failover_queue",
        "get-failover-queue",
      ],
    },
    {
      id: "set_auto_failover_enabled",
      patterns: [
        "proxy auto-failover-enabled set", "proxy set-auto-failover-enabled", "set_auto_failover_enabled",
        "set-auto-failover-enabled",
      ],
    },
    {
      id: "get_auto_failover_enabled",
      patterns: [
        "proxy auto-failover-enabled", "proxy get-auto-failover-enabled", "get_auto_failover_enabled",
        "get-auto-failover-enabled",
      ],
    },
    {
      id: "set_proxy_takeover_for_app",
      patterns: [
        "proxy takeover-status set", "proxy set-proxy-takeover-for-app", "set_proxy_takeover_for_app",
        "set-proxy-takeover-for-app",
      ],
    },
    {
      id: "get_proxy_takeover_status",
      patterns: [
        "proxy takeover-status", "get_proxy_takeover_status", "get-proxy-takeover-status",
      ],
    },
    {
      id: "get_proxy_status",
      patterns: ["proxy status", "get_proxy_status", "get-proxy-status"],
    },
    {
      id: "start_proxy_server",
      patterns: [
        "proxy start-proxy-server", "start_proxy_server", "start-proxy-server",
      ],
    },
    {
      id: "stop_proxy_server",
      patterns: [
        "proxy stop-proxy-server", "stop_proxy_server", "stop-proxy-server",
      ],
    },
    {
      id: "stop_proxy_with_restore",
      patterns: [
        "proxy stop-proxy-with-restore", "stop_proxy_with_restore", "stop-proxy-with-restore",
      ],
    },
    {
      id: "test_proxy_url",
      patterns: ["proxy test-url", "test_proxy_url", "test-proxy-url"],
    },
    {
      id: "get_upstream_proxy_status",
      patterns: [
        "proxy upstream-status", "get_upstream_proxy_status", "get-upstream-proxy-status",
      ],
    },
    {
      id: "scan_local_proxies",
      patterns: ["proxy scan-local", "scan_local_proxies", "scan-local-proxies"],
    },
    {
      id: "get_default_cost_multiplier_test_hook",
      patterns: [
        "get_default_cost_multiplier_test_hook", "get-default-cost-multiplier-test-hook",
      ],
    },
    {
      id: "set_default_cost_multiplier_test_hook",
      patterns: [
        "set_default_cost_multiplier_test_hook", "set-default-cost-multiplier-test-hook",
      ],
    },
    {
      id: "get_pricing_model_source_test_hook",
      patterns: [
        "get_pricing_model_source_test_hook", "get-pricing-model-source-test-hook",
      ],
    },
    {
      id: "set_pricing_model_source_test_hook",
      patterns: [
        "set_pricing_model_source_test_hook", "set-pricing-model-source-test-hook",
      ],
    },
    {
      id: "get_provider_health",
      patterns: [
        "proxy provider-health", "get_provider_health", "get-provider-health",
      ],
    },
    {
      id: "get_circuit_breaker_stats",
      patterns: [
        "proxy circuit-breaker-stats", "get_circuit_breaker_stats", "get-circuit-breaker-stats",
      ],
    },
    {
      id: "reset_circuit_breaker",
      patterns: [
        "proxy reset-circuit-breaker", "reset_circuit_breaker", "reset-circuit-breaker",
      ],
    },
    {
      id: "get_available_providers_for_failover",
      patterns: [
        "proxy available-failover-providers", "proxy get-available-providers-for-failover",
        "get_available_providers_for_failover", "get-available-providers-for-failover",
      ],
    },
    {
      id: "is_live_takeover_active",
      patterns: [
        "proxy is-live-takeover-active", "is_live_takeover_active", "is-live-takeover-active",
      ],
    },
    {
      id: "switch_proxy_provider",
      patterns: [
        "proxy switch-proxy-provider", "switch_proxy_provider", "switch-proxy-provider",
      ],
    },
    {
      id: "is_proxy_running",
      patterns: [
        "proxy running", "proxy is-proxy-running", "is_proxy_running", "is-proxy-running",
      ],
    },
    {
      id: "get_providers",
      patterns: [
        "provider list", "providers list", "get_providers", "get-providers",
      ],
    },
    {
      id: "get_current_provider",
      patterns: [
        "provider current", "providers current", "get_current_provider", "get-current-provider",
      ],
    },
    {
      id: "add_provider",
      patterns: [
        "provider add", "providers add", "add_provider", "add-provider",
      ],
    },
    {
      id: "update_provider",
      patterns: [
        "provider update", "providers update", "update_provider", "update-provider",
      ],
    },
    {
      id: "delete_provider",
      patterns: [
        "provider delete", "providers delete", "delete_provider", "delete-provider",
      ],
    },
    {
      id: "remove_provider_from_live_config",
      patterns: [
        "provider remove-live", "providers remove-live", "remove_provider_from_live_config",
        "remove-provider-from-live-config",
      ],
    },
    {
      id: "switch_provider",
      patterns: [
        "provider switch", "providers switch", "switch_provider", "switch-provider",
      ],
    },
    {
      id: "switch_provider_test_hook",
      patterns: ["switch_provider_test_hook", "switch-provider-test-hook"],
    },
    {
      id: "sync_current_providers_live",
      patterns: [
        "provider sync-live", "providers sync-live", "sync_current_providers_live",
        "sync-current-providers-live",
      ],
    },
    {
      id: "read_live_provider_settings",
      patterns: [
        "provider live-settings", "providers live-settings", "read_live_provider_settings",
        "read-live-provider-settings",
      ],
    },
    {
      id: "open_provider_terminal",
      patterns: ["open_provider_terminal", "open-provider-terminal"],
    },
    {
      id: "import_default_config",
      patterns: ["import_default_config", "import-default-config"],
    },
    {
      id: "import_default_config_test_hook",
      patterns: [
        "import_default_config_test_hook", "import-default-config-test-hook",
      ],
    },
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
      patterns: [
        "get_opencode_live_provider_ids", "get-opencode-live-provider-ids",
      ],
    },
    {
      id: "get_openclaw_live_provider_ids",
      patterns: [
        "get_openclaw_live_provider_ids", "get-openclaw-live-provider-ids",
      ],
    },
    {
      id: "get_openclaw_live_provider",
      patterns: ["get_openclaw_live_provider", "get-openclaw-live-provider"],
    },
    {
      id: "get_hermes_live_provider_ids",
      patterns: ["get_hermes_live_provider_ids", "get-hermes-live-provider-ids"],
    },
    {
      id: "get_hermes_live_provider",
      patterns: ["get_hermes_live_provider", "get-hermes-live-provider"],
    },
    {
      id: "import_opencode_providers_from_live",
      patterns: [
        "import_opencode_providers_from_live", "import-opencode-providers-from-live",
      ],
    },
    {
      id: "import_openclaw_providers_from_live",
      patterns: [
        "import_openclaw_providers_from_live", "import-openclaw-providers-from-live",
      ],
    },
    {
      id: "import_hermes_providers_from_live",
      patterns: [
        "import_hermes_providers_from_live", "import-hermes-providers-from-live",
      ],
    },
    {
      id: "get_universal_providers",
      patterns: [
        "provider universal list", "providers universal list", "get_universal_providers",
        "get-universal-providers",
      ],
    },
    {
      id: "get_universal_provider",
      patterns: [
        "provider universal get", "providers universal get", "get_universal_provider",
        "get-universal-provider",
      ],
    },
    {
      id: "upsert_universal_provider",
      patterns: [
        "provider universal upsert", "providers universal upsert", "upsert_universal_provider",
        "upsert-universal-provider",
      ],
    },
    {
      id: "delete_universal_provider",
      patterns: [
        "provider universal delete", "providers universal delete", "delete_universal_provider",
        "delete-universal-provider",
      ],
    },
    {
      id: "sync_universal_provider",
      patterns: [
        "provider universal sync", "providers universal sync", "sync_universal_provider",
        "sync-universal-provider",
      ],
    },
    {
      id: "get_provider_presets",
      patterns: [
        "provider presets list", "providers presets list", "get_provider_presets",
        "get-provider-presets",
      ],
    },
    {
      id: "test_api_endpoints",
      patterns: [
        "provider test-endpoints", "providers test-endpoints", "test_api_endpoints",
        "test-api-endpoints",
      ],
    },
    {
      id: "update_providers_sort_order",
      patterns: [
        "provider sort-order set", "providers sort-order set", "update_providers_sort_order",
        "update-providers-sort-order",
      ],
    },
    {
      id: "get_custom_endpoints",
      patterns: [
        "provider endpoints list", "providers endpoints list", "get_custom_endpoints",
        "get-custom-endpoints",
      ],
    },
    {
      id: "add_custom_endpoint",
      patterns: [
        "provider endpoints add", "providers endpoints add", "add_custom_endpoint",
        "add-custom-endpoint",
      ],
    },
    {
      id: "remove_custom_endpoint",
      patterns: [
        "provider endpoints remove", "providers endpoints remove", "remove_custom_endpoint",
        "remove-custom-endpoint",
      ],
    },
    {
      id: "update_endpoint_last_used",
      patterns: [
        "provider endpoints touch", "providers endpoints touch", "update_endpoint_last_used",
        "update-endpoint-last-used",
      ],
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
    {
      id: "get_usage_summary",
      patterns: [
        "usage summary", "usage get-usage-summary", "get_usage_summary", "get-usage-summary",
      ],
    },
    {
      id: "get_usage_summary_by_app",
      patterns: [
        "usage apps", "usage get-usage-summary-by-app", "get_usage_summary_by_app",
        "get-usage-summary-by-app",
      ],
    },
    {
      id: "get_usage_trends",
      patterns: [
        "usage trends", "usage get-usage-trends", "get_usage_trends", "get-usage-trends",
      ],
    },
    {
      id: "get_provider_stats",
      patterns: [
        "usage providers", "usage get-provider-stats", "get_provider_stats", "get-provider-stats",
      ],
    },
    {
      id: "get_model_stats",
      patterns: [
        "usage models", "usage get-model-stats", "get_model_stats", "get-model-stats",
      ],
    },
    {
      id: "get_request_logs",
      patterns: [
        "usage logs", "usage get-request-logs", "get_request_logs", "get-request-logs",
      ],
    },
    {
      id: "get_request_detail",
      patterns: [
        "usage detail", "usage get-request-detail", "get_request_detail", "get-request-detail",
      ],
    },
    {
      id: "update_model_pricing",
      patterns: [
        "usage pricing set", "usage update-model-pricing", "update_model_pricing",
        "update-model-pricing",
      ],
    },
    {
      id: "delete_model_pricing",
      patterns: [
        "usage pricing delete", "usage delete-model-pricing", "delete_model_pricing",
        "delete-model-pricing",
      ],
    },
    {
      id: "get_model_pricing",
      patterns: [
        "usage pricing", "usage get-model-pricing", "get_model_pricing", "get-model-pricing",
      ],
    },
    {
      id: "check_provider_limits",
      patterns: [
        "usage limits", "usage check-provider-limits", "check_provider_limits", "check-provider-limits",
      ],
    },
    {
      id: "sync_session_usage",
      patterns: [
        "usage sync", "usage sync-session-usage", "sync_session_usage", "sync-session-usage",
      ],
    },
    {
      id: "get_usage_data_sources",
      patterns: [
        "usage sources", "usage get-usage-data-sources", "get_usage_data_sources",
        "get-usage-data-sources",
      ],
    },
    {
      id: "query_provider_usage",
      patterns: [
        "usage query-provider-usage", "queryProviderUsage", "query_provider_usage",
        "query-provider-usage",
      ],
    },
    {
      id: "get_balance",
      patterns: ["usage balance", "get_balance", "get-balance"],
    },
    {
      id: "get_subscription_quota",
      patterns: [
        "usage quota", "usage get-subscription-quota", "get_subscription_quota",
        "get-subscription-quota",
      ],
    },
    {
      id: "get_codex_oauth_quota",
      patterns: [
        "usage codex-oauth-quota", "usage get-codex-oauth-quota", "get_codex_oauth_quota",
        "get-codex-oauth-quota",
      ],
    },
    {
      id: "get_codex_oauth_models",
      patterns: [
        "usage codex-oauth-models", "usage get-codex-oauth-models", "get_codex_oauth_models",
        "get-codex-oauth-models",
      ],
    },
    {
      id: "get_coding_plan_quota",
      patterns: [
        "usage coding-plan", "usage get-coding-plan-quota", "get_coding_plan_quota",
        "get-coding-plan-quota",
      ],
    },
    {
      id: "test_usage_script",
      patterns: [
        "usage test-usage-script", "testUsageScript", "test_usage_script", "test-usage-script",
      ],
    },
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
      check_usage_endpoint(args, "/copilot_list_accounts")
      true
    }
    Some("copilot_get_auth_status") => {
      check_usage_endpoint(args, "/copilot_get_auth_status")
      true
    }
    Some("copilot_is_authenticated") => {
      check_usage_endpoint(args, "/copilot_is_authenticated")
      true
    }
    Some("copilot_logout") => {
      check_json_post_endpoint(args, "/copilot_logout", "Copilot")
      true
    }
    Some("copilot_remove_account") => {
      copilot_account_post(args, "/copilot_remove_account")
      true
    }
    Some("copilot_set_default_account") => {
      copilot_account_post(args, "/copilot_set_default_account")
      true
    }
    Some("copilot_get_token") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot_get_token"),
      )
      true
    }
    Some("copilot_get_token_for_account") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot_get_token_for_account"),
      )
      true
    }
    Some("copilot_get_models") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot_get_models"),
      )
      true
    }
    Some("copilot_get_models_for_account") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot_get_models_for_account"),
      )
      true
    }
    Some("copilot_get_usage") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot_get_usage"),
      )
      true
    }
    Some("copilot_get_usage_for_account") => {
      check_usage_endpoint(
        args,
        copilot_account_optional_path(args, "/copilot_get_usage_for_account"),
      )
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
      check_usage_endpoint(args, "/get_stream_check_config")
      true
    }
    Some("save_stream_check_config") => {
      save_stream_check_config(args)
      true
    }
    Some("update_proxy_config") => {
      update_proxy_config(args)
      true
    }
    Some("get_proxy_config") => {
      check_proxy_config(args)
      true
    }
    Some("update_global_proxy_config") => {
      update_proxy_global_config(args)
      true
    }
    Some("get_global_proxy_config") => {
      check_proxy_global_config(args)
      true
    }
    Some("set_global_proxy_url") => {
      set_global_proxy_url(args)
      true
    }
    Some("get_global_proxy_url") => {
      check_usage_endpoint(args, "/get_global_proxy_url")
      true
    }
    Some("update_proxy_config_for_app") => {
      update_proxy_app_config(args)
      true
    }
    Some("get_proxy_config_for_app") => {
      check_proxy_app_config(args)
      true
    }
    Some("set_default_cost_multiplier") => {
      set_proxy_default_cost_multiplier(args)
      true
    }
    Some("get_default_cost_multiplier") => {
      check_proxy_default_cost_multiplier(args)
      true
    }
    Some("set_pricing_model_source") => {
      set_proxy_pricing_model_source(args)
      true
    }
    Some("get_pricing_model_source") => {
      check_proxy_pricing_model_source(args)
      true
    }
    Some("update_circuit_breaker_config") => {
      update_proxy_circuit_breaker_config(args)
      true
    }
    Some("get_circuit_breaker_config") => {
      check_proxy_circuit_breaker_config(args)
      true
    }
    Some("add_to_failover_queue") => {
      add_proxy_failover_queue(args)
      true
    }
    Some("remove_from_failover_queue") => {
      remove_proxy_failover_queue(args)
      true
    }
    Some("get_failover_queue") => {
      check_proxy_failover_queue(args)
      true
    }
    Some("set_auto_failover_enabled") => {
      set_proxy_auto_failover_enabled(args)
      true
    }
    Some("get_auto_failover_enabled") => {
      check_proxy_auto_failover_enabled(args)
      true
    }
    Some("set_proxy_takeover_for_app") => {
      set_proxy_takeover_status(args)
      true
    }
    Some("get_proxy_takeover_status") => {
      check_proxy_takeover_status(args)
      true
    }
    Some("get_proxy_status") => {
      check_proxy_status(args)
      true
    }
    Some("start_proxy_server") => {
      start_proxy_server(args)
      true
    }
    Some("stop_proxy_server") => {
      stop_proxy_server(args)
      true
    }
    Some("stop_proxy_with_restore") => {
      stop_proxy_with_restore(args)
      true
    }
    Some("test_proxy_url") => {
      test_global_proxy_url(args)
      true
    }
    Some("get_upstream_proxy_status") => {
      check_usage_endpoint(args, "/get_upstream_proxy_status")
      true
    }
    Some("scan_local_proxies") => {
      check_usage_endpoint(args, "/scan_local_proxies")
      true
    }
    Some("get_default_cost_multiplier_test_hook") => {
      check_proxy_default_cost_multiplier_test_hook(args)
      true
    }
    Some("set_default_cost_multiplier_test_hook") => {
      set_proxy_default_cost_multiplier_test_hook(args)
      true
    }
    Some("get_pricing_model_source_test_hook") => {
      check_proxy_pricing_model_source_test_hook(args)
      true
    }
    Some("set_pricing_model_source_test_hook") => {
      set_proxy_pricing_model_source_test_hook(args)
      true
    }
    Some("get_provider_health") => {
      check_proxy_provider_health(args)
      true
    }
    Some("get_circuit_breaker_stats") => {
      check_proxy_circuit_breaker_stats(args)
      true
    }
    Some("reset_circuit_breaker") => {
      reset_proxy_circuit_breaker(args)
      true
    }
    Some("get_available_providers_for_failover") => {
      check_proxy_available_failover_providers(args)
      true
    }
    Some("is_live_takeover_active") => {
      check_proxy_endpoint(args, "/is_live_takeover_active")
      true
    }
    Some("switch_proxy_provider") => {
      switch_proxy_provider(args)
      true
    }
    Some("is_proxy_running") => {
      check_proxy_running(args)
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
    Some("switch_provider_test_hook") => {
      switch_provider_test_hook(args)
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
    Some("import_default_config_test_hook") => {
      import_default_config_test_hook(args)
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
    _ => false
  }
}
