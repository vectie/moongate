///|
test "has flag matches exact CLI option" {
  let args = ["moonstat", "models", "fetch", "--full-url"]
  assert_true(has_flag(args, "--full-url"))
  assert_false(has_flag(args, "--is-full-url"))
}

///|
test "registered cli commands match suite command aliases and status commands" {
  assert_true(registered_cli_commands().length() >= 225)
  assert_true(registered_cli_command_id(["moonstat", "start"]) == Some("start"))
  assert_true(
    registered_cli_command_id(["moonstat", "install", "--port", "15721"]) ==
    Some("install_reroute"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "claude-desktop", "status"]) ==
    Some("status_claude_desktop"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "codex", "uninstall"]) ==
    Some("uninstall_codex"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "codex", "remove"]) is None,
  )
  assert_true(registered_cli_command_id(["moonstat", "remove"]) is None)
  assert_true(
    registered_cli_command_id(["moonstat", "claude-desktop", "remove"]) is None,
  )
  assert_true(registered_cli_command_id(["moonstat", "--help"]) == Some("help"))
  assert_true(
    registered_cli_command_id(["moonstat", "--version"]) == Some("version"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "sync", "webdav", "upload"]) ==
    Some("webdav_sync_upload"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "sync", "s3", "test"]) ==
    Some("s3_test_connection"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "sessions", "list"]) ==
    Some("list_sessions"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "sessions", "terminal"]) ==
    Some("launch_session_terminal"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "providers", "omo-slim", "file"]) ==
    Some("read_omo_slim_local_file"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "files", "open-zip-dialog"]) ==
    Some("open_zip_file_dialog"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "skills", "installed"]) ==
    Some("get_installed_skills"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "skills", "backup", "restore"]) ==
    Some("restore_skill_backup"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "skills", "import-apps"]) ==
    Some("import_skills_from_apps"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "skills", "search"]) ==
    Some("search_skills_sh"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "skills", "repo", "add"]) ==
    Some("add_skill_repo"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "config", "snippet", "set"]) ==
    Some("set_common_config_snippet"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "config", "env-conflicts"]) ==
    Some("check_env_conflicts"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "config", "env-restore"]) ==
    Some("restore_env_backup"),
  )
  assert_true(
    cli_args_match_pattern(
      ["moonstat", "suite", "manifest", "--host", "127.0.0.1"],
      "suite manifest",
    ),
  )
  assert_false(cli_args_match_pattern(["moonstat", "suite"], "suite status"))
  assert_true(
    registered_cli_command_id(["moonstat", "suite", "moonclaw-providers"]) ==
    Some("suite_moonclaw_providers"),
  )
  assert_true(
    registered_cli_command_id([
      "moonstat", "suite", "write-moonclaw-providers", "--path", "/tmp/providers.json",
    ]) ==
    Some("suite_write_moonclaw_providers"),
  )
  assert_true(
    registered_cli_command_id([
      "moonstat", "auth", "poll", "--device-code", "abc",
    ]) ==
    Some("auth_poll_for_account"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "auth", "status"]) ==
    Some("auth_get_status"),
  )
  assert_true(
    registered_cli_command_id([
      "moonstat", "copilot", "models", "--account-id", "ghe:42",
    ]) ==
    Some("copilot_get_models"),
  )
  assert_true(
    registered_cli_command_id([
      "moonstat", "copilot", "token", "--account-id", "ghe:42",
    ]) ==
    Some("copilot_get_token"),
  )
  assert_true(
    registered_cli_command_id([
      "moonstat", "stream-check", "provider", "--provider-id", "codex",
    ]) ==
    Some("stream_check_provider"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "stream-check", "all"]) ==
    Some("stream_check_all_providers"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "stream-check", "config", "set"]) ==
    Some("save_stream_check_config"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "stream-check", "config"]) ==
    Some("get_stream_check_config"),
  )
  assert_eq(
    registered_cli_command_id(["moonstat", "proxy", "config", "set"]),
    None,
  )
  assert_true(
    registered_cli_command_id(["moonstat", "proxy", "config"]) == None,
  )
  assert_true(
    registered_cli_command_id(["moonstat", "proxy", "global-url", "set"]) ==
    Some("set_global_proxy_url"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "proxy", "failover-queue", "add"]) ==
    Some("add_to_failover_queue"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "proxy", "failover-queue"]) ==
    Some("get_failover_queue"),
  )
  assert_true(
    registered_cli_command_id([
      "moonstat", "proxy", "auto-failover-enabled", "set",
    ]) ==
    Some("set_auto_failover_enabled"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "proxy", "takeover-status", "set"]) ==
    Some("set_proxy_takeover_for_app"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "proxy", "running"]) ==
    Some("is_proxy_running"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "provider", "list"]) ==
    Some("get_providers"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "provider", "universal", "upsert"]) ==
    Some("upsert_universal_provider"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "provider", "endpoints", "add"]) ==
    Some("add_custom_endpoint"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "provider", "sort-order", "set"]) ==
    Some("update_providers_sort_order"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "provider", "live-ids"]) ==
    Some("provider_live_ids"),
  )
  assert_true(
    registered_cli_command_id([
      "moonstat", "provider", "openclaw", "import-live",
    ]) ==
    Some("import_openclaw_providers_from_live"),
  )
  assert_true(
    registered_cli_command_id([
      "moonstat", "providers", "claude-desktop", "official",
    ]) ==
    Some("ensure_claude_desktop_official_provider"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "models", "fetch"]) ==
    Some("fetch_models"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "fetch_models_for_config"]) is None,
  )
  assert_true(
    registered_cli_command_id(["moonstat", "models", "candidates"]) ==
    Some("model_candidates"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "openclaw", "config-health"]) ==
    Some("scan_openclaw_config_health"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "openclaw", "model-catalog", "set"]) ==
    Some("set_openclaw_model_catalog"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "openclaw", "agents-defaults"]) ==
    Some("get_openclaw_agents_defaults"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "openclaw", "tools", "set"]) ==
    Some("set_openclaw_tools"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "hermes", "memory"]) ==
    Some("get_hermes_memory"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "hermes", "web-ui"]) ==
    Some("open_hermes_web_ui"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "hermes", "dashboard"]) ==
    Some("launch_hermes_dashboard"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "config", "status"]) ==
    Some("get_config_status"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "config", "claude-code", "path"]) ==
    Some("get_claude_code_config_path"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "config", "folder", "open"]) ==
    Some("open_config_folder"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "files", "directory", "pick"]) ==
    Some("pick_directory"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "runtime", "copy-text"]) ==
    Some("copy_text_to_clipboard"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "runtime", "updates", "check"]) ==
    Some("check_for_updates"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "tools", "versions"]) ==
    Some("get_tool_versions"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "tools", "lifecycle-action"]) ==
    Some("run_tool_lifecycle_action"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "runtime", "lightweight", "enter"]) ==
    Some("enter_lightweight_mode"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "files", "save-dialog"]) ==
    Some("save_file_dialog"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "config", "file", "export"]) ==
    Some("export_config_to_file"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "backups", "db", "rename"]) ==
    Some("rename_db_backup"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "deeplink", "parse"]) ==
    Some("parse_deeplink"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "deeplink", "import"]) ==
    Some("import_from_deeplink"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "settings", "get"]) ==
    Some("get_settings"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "settings", "save"]) ==
    Some("save_settings"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "settings", "app-config-dir", "set"]) ==
    Some("set_app_config_dir_override"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "settings", "app-config-dir"]) ==
    Some("get_app_config_dir_override"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "settings", "auto-launch", "set"]) ==
    Some("set_auto_launch"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "settings", "auto-launch"]) ==
    Some("get_auto_launch_status"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "settings", "rectifier", "set"]) ==
    Some("set_rectifier_config"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "settings", "rectifier"]) ==
    Some("get_rectifier_config"),
  )
  assert_true(
    registered_cli_command_id([
      "moonstat", "settings", "copilot-optimizer", "set",
    ]) ==
    Some("set_copilot_optimizer_config"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "runtime", "restart"]) ==
    Some("restart_app"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "plugin", "claude", "status"]) ==
    Some("get_claude_plugin_status"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "plugin", "claude", "apply"]) ==
    Some("apply_claude_plugin_config"),
  )
  assert_true(
    registered_cli_command_id([
      "moonstat", "plugin", "claude", "onboarding-skip",
    ]) ==
    Some("apply_claude_onboarding_skip"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "workspace", "memory", "list"]) ==
    Some("list_daily_memory_files"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "workspace", "memory", "search"]) ==
    Some("search_daily_memory_files"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "workspace", "read"]) ==
    Some("read_workspace_file"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "workspace", "open"]) ==
    Some("open_workspace_directory"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "mcp", "status"]) ==
    Some("get_claude_mcp_status"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "mcp", "upsert-config"]) ==
    Some("upsert_mcp_server_in_config"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "mcp", "validate"]) ==
    Some("validate_mcp_command"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "mcp", "toggle"]) ==
    Some("toggle_mcp_app"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "prompt", "list"]) ==
    Some("get_prompts"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "prompt", "upsert"]) ==
    Some("upsert_prompt"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "prompt", "current"]) ==
    Some("get_current_prompt_file_content"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "prompts", "current"]) is None,
  )
  assert_true(
    registered_cli_command_id(["moonstat", "prompts", "import"]) is None,
  )
  assert_true(
    registered_cli_command_id(["moonstat", "usage", "summary"]) ==
    Some("get_usage_summary"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "usage", "apps"]) ==
    Some("get_usage_summary_by_app"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "usage", "logs"]) ==
    Some("get_request_logs"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "usage", "pricing", "set"]) ==
    Some("update_model_pricing"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "usage", "pricing", "delete"]) ==
    Some("delete_model_pricing"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "usage", "pricing"]) ==
    Some("get_model_pricing"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "usage", "query-provider-usage"]) ==
    Some("query_provider_usage"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "usage", "quota"]) ==
    Some("get_subscription_quota"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "usage", "codex-oauth-models"]) ==
    Some("get_codex_oauth_models"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "usage", "test-usage-script"]) ==
    Some("test_usage_script"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "usage", "detail"]) ==
    Some("get_request_detail"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "status"]) == Some("status"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "health"]) == Some("health"),
  )
  assert_true(registered_cli_command_id(["moonstat", "stats"]) == Some("stats"))
}

///|
test "proxy cli dispatcher owns only proxy command family" {
  assert_false(cli_proxy_command_id("update_proxy_config"))
  assert_true(cli_proxy_command_id("set_proxy_takeover_for_app"))
  assert_true(cli_proxy_command_id("switch_proxy_provider"))
  assert_true(cli_proxy_command_id("is_proxy_running"))
  assert_false(cli_proxy_command_id("get_providers"))
  assert_false(cli_proxy_command_id("suite_manifest"))
  assert_false(cli_proxy_command_id("auth_get_status"))
}

///|
test "usage cli dispatcher owns usage and telemetry commands" {
  assert_true(cli_usage_command_id("get_usage_summary"))
  assert_true(cli_usage_command_id("get_request_logs"))
  assert_true(cli_usage_command_id("query_provider_usage"))
  assert_true(cli_usage_command_id("status"))
  assert_true(cli_usage_command_id("health"))
  assert_true(cli_usage_command_id("stats"))
  assert_false(cli_usage_command_id("get_providers"))
  assert_false(cli_usage_command_id("suite_manifest"))
  assert_false(cli_usage_command_id("auth_get_status"))
}

///|
test "auth cli dispatcher owns managed auth commands" {
  assert_true(cli_auth_command_id("login"))
  assert_true(cli_auth_command_id("auth_start_login"))
  assert_true(cli_auth_command_id("auth_poll_for_account"))
  assert_true(cli_auth_command_id("auth_get_status"))
  assert_true(cli_auth_command_id("auth_logout"))
  assert_false(cli_auth_command_id("copilot_get_models"))
  assert_false(cli_auth_command_id("get_usage_summary"))
  assert_false(cli_auth_command_id("get_providers"))
}

///|
test "copilot cli dispatcher owns Copilot auth commands" {
  assert_true(cli_copilot_command_id("copilot_start_device_flow"))
  assert_true(cli_copilot_command_id("copilot_poll_for_account"))
  assert_true(cli_copilot_command_id("copilot_get_token"))
  assert_true(cli_copilot_command_id("copilot_get_usage"))
  assert_false(cli_copilot_command_id("auth_get_status"))
  assert_false(cli_copilot_command_id("get_usage_summary"))
  assert_false(cli_copilot_command_id("get_providers"))
}

///|
test "skill cli dispatcher owns skills commands" {
  assert_true(cli_skill_command_id("get_installed_skills"))
  assert_true(cli_skill_command_id("restore_skill_backup"))
  assert_true(cli_skill_command_id("import_skills_from_apps"))
  assert_true(cli_skill_command_id("migrate_skill_storage"))
  assert_true(cli_skill_command_id("install_skills_from_zip"))
  assert_false(cli_skill_command_id("auth_get_status"))
  assert_false(cli_skill_command_id("get_usage_summary"))
  assert_false(cli_skill_command_id("get_providers"))
}

///|
test "workspace cli dispatcher owns suite workspace commands" {
  assert_true(cli_workspace_command_id("scan_openclaw_config_health"))
  assert_true(cli_workspace_command_id("set_openclaw_model_catalog"))
  assert_true(cli_workspace_command_id("set_hermes_memory"))
  assert_true(cli_workspace_command_id("save_file_dialog"))
  assert_true(cli_workspace_command_id("read_workspace_file"))
  assert_true(cli_workspace_command_id("import_prompt_from_file"))
  assert_false(cli_workspace_command_id("auth_get_status"))
  assert_false(cli_workspace_command_id("get_usage_summary"))
  assert_false(cli_workspace_command_id("suite_manifest"))
}

///|
test "suite cli dispatcher owns suite discovery commands" {
  assert_true(cli_suite_command_id("suite_manifest"))
  assert_true(cli_suite_command_id("suite_status"))
  assert_true(cli_suite_command_id("suite_write_status"))
  assert_true(cli_suite_command_id("suite_moonclaw_providers"))
  assert_false(cli_suite_command_id("auth_get_status"))
  assert_false(cli_suite_command_id("get_usage_summary"))
  assert_false(cli_suite_command_id("read_workspace_file"))
}

///|
test "config cli dispatcher owns config settings and mcp commands" {
  assert_true(cli_config_command_id("get_config_status"))
  assert_true(cli_config_command_id("save_settings"))
  assert_true(cli_config_command_id("set_rectifier_config"))
  assert_true(cli_config_command_id("get_claude_plugin_status"))
  assert_true(cli_config_command_id("upsert_mcp_server"))
  assert_true(cli_config_command_id("enable_prompt"))
  assert_false(cli_config_command_id("auth_get_status"))
  assert_false(cli_config_command_id("get_usage_summary"))
  assert_false(cli_config_command_id("read_workspace_file"))
}

///|
test "provider cli dispatcher owns provider and model commands" {
  assert_true(cli_provider_command_id("get_providers"))
  assert_true(cli_provider_command_id("switch_provider"))
  assert_true(cli_provider_command_id("provider_import_live"))
  assert_true(cli_provider_command_id("upsert_universal_provider"))
  assert_true(cli_provider_command_id("test_api_endpoints"))
  assert_true(cli_provider_command_id("fetch_models"))
  assert_false(cli_provider_command_id("auth_get_status"))
  assert_false(cli_provider_command_id("get_usage_summary"))
  assert_false(cli_provider_command_id("read_workspace_file"))
}

///|
test "runtime cli dispatcher owns app shell commands" {
  assert_true(cli_runtime_command_id("pick_directory"))
  assert_true(cli_runtime_command_id("check_for_updates"))
  assert_true(cli_runtime_command_id("get_tool_versions"))
  assert_true(cli_runtime_command_id("enter_lightweight_mode"))
  assert_true(cli_runtime_command_id("restart_app"))
  assert_true(cli_runtime_command_id("install_update_and_restart"))
  assert_false(cli_runtime_command_id("auth_get_status"))
  assert_false(cli_runtime_command_id("get_usage_summary"))
  assert_false(cli_runtime_command_id("read_workspace_file"))
}

///|
test "sync cli dispatcher owns remote sync commands" {
  assert_true(cli_sync_command_id("webdav_test_connection"))
  assert_true(cli_sync_command_id("webdav_sync_save_settings"))
  assert_true(cli_sync_command_id("s3_test_connection"))
  assert_true(cli_sync_command_id("s3_sync_fetch_remote_info"))
  assert_false(cli_sync_command_id("auth_get_status"))
  assert_false(cli_sync_command_id("get_usage_summary"))
  assert_false(cli_sync_command_id("read_workspace_file"))
}

///|
test "session cli dispatcher owns session and omo commands" {
  assert_true(cli_session_command_id("list_sessions"))
  assert_true(cli_session_command_id("get_session_messages"))
  assert_true(cli_session_command_id("delete_sessions"))
  assert_true(cli_session_command_id("read_omo_local_file"))
  assert_true(cli_session_command_id("disable_current_omo_slim"))
  assert_false(cli_session_command_id("auth_get_status"))
  assert_false(cli_session_command_id("get_usage_summary"))
  assert_false(cli_session_command_id("read_workspace_file"))
}

///|
test "install cli dispatcher owns startup and app install commands" {
  assert_true(cli_install_command_id("start"))
  assert_true(cli_install_command_id("install_reroute"))
  assert_true(cli_install_command_id("status_claude_desktop"))
  assert_true(cli_install_command_id("install_codex"))
  assert_false(cli_install_command_id("auth_get_status"))
  assert_false(cli_install_command_id("get_usage_summary"))
  assert_false(cli_install_command_id("read_workspace_file"))
}

///|
test "stream check cli dispatcher owns stream check commands" {
  assert_true(cli_stream_check_command_id("stream_check_provider"))
  assert_true(cli_stream_check_command_id("stream_check_all_providers"))
  assert_true(cli_stream_check_command_id("get_stream_check_config"))
  assert_true(cli_stream_check_command_id("save_stream_check_config"))
  assert_false(cli_stream_check_command_id("auth_get_status"))
  assert_false(cli_stream_check_command_id("get_usage_summary"))
  assert_false(cli_stream_check_command_id("read_workspace_file"))
}

///|
test "usage sync path accepts standalone projects dir override" {
  assert_eq(
    usage_sync_path(["moonstat", "usage", "sync"]),
    "/usage/sync-session",
  )
  assert_eq(
    usage_sync_path([
      "moonstat", "usage", "sync", "--projects-dir", "/tmp/claude projects", "--codex-dir",
      "/tmp/codex", "--gemini-dir", "/tmp/gemini", "--opencode-export-path", "/tmp/opencode/messages.jsonl",
      "--opencode-db-path", "/tmp/opencode/opencode.db?mode=ro",
    ]),
    "/usage/sync-session?projectsDir=%2Ftmp%2Fclaude%20projects&codexDir=%2Ftmp%2Fcodex&geminiDir=%2Ftmp%2Fgemini&opencodeExportPath=%2Ftmp%2Fopencode%2Fmessages.jsonl&opencodeDbPath=%2Ftmp%2Fopencode%2Fopencode.db%3Fmode%3Dro",
  )
}

///|
test "usage pricing paths accept moonstat editable pricing args" {
  assert_eq(
    usage_pricing_update_path([
      "moonstat", "usage", "pricing", "set", "--model-id", "anthropic/claude&sonnet",
      "--display-name", "Custom Model", "--input-cost", "1", "--output-cost", "2",
      "--cache-read-cost", "0.1", "--cache-creation-cost", "0",
    ]),
    Some(
      "/usage/model-pricing?modelId=anthropic%2Fclaude%26sonnet&displayName=Custom%20Model&inputCost=1&outputCost=2&cacheReadCost=0.1&cacheCreationCost=0",
    ),
  )
  assert_eq(
    usage_pricing_delete_path([
      "moonstat", "usage", "pricing", "delete", "--model-id", "anthropic/claude&sonnet",
    ]),
    Some("/usage/model-pricing?modelId=anthropic%2Fclaude%26sonnet"),
  )
  assert_eq(
    usage_pricing_update_path([
      "moonstat", "usage", "pricing", "set", "--model-id", "custom",
    ]),
    None,
  )
}

///|
test "usage filter paths encode moonstat query values" {
  assert_eq(
    usage_trends_path([
      "moonstat", "usage", "trends", "--start-date", "10", "--end-date", "20", "--app-type",
      "claude desktop",
    ]),
    "/usage/trends?startDate=10&endDate=20&appType=claude%20desktop",
  )
  assert_eq(
    usage_limits_path([
      "moonstat", "usage", "limits", "--provider-id", "Codex OAuth", "--app-type",
      "codex", "--daily-limit-usd", "1.5", "--monthly-limit-usd", "30",
    ]),
    "/usage/provider-limits?providerId=Codex%20OAuth&appType=codex&dailyLimitUsd=1.5&monthlyLimitUsd=30",
  )
}

///|
test "stream check paths use moonstat command names and kebab-case flags" {
  assert_eq(
    stream_check_provider_path([
      "moonstat", "stream-check", "provider", "--app-type", "codex", "--provider-id",
      "codex oauth",
    ]),
    Some("/proxy/stream-check/provider?appType=codex&providerId=codex%20oauth"),
  )
  assert_eq(
    stream_check_all_path([
      "moonstat", "stream-check", "all", "--app-type", "claude", "--proxy-targets-only",
      "true",
    ]),
    "/proxy/stream-check/all?appType=claude&proxyTargetsOnly=true",
  )
  assert_eq(
    stream_check_config_update_path([
      "moonstat", "stream-check", "config", "set", "--codex-model", "gpt/5", "--timeout-secs",
      "45", "--test-prompt", "Who are you?",
    ]),
    "/proxy/stream-check/config?timeoutSecs=45&codexModel=gpt%2F5&testPrompt=Who%20are%20you%3F",
  )
}

///|
test "copilot grouped commands build canonical auth paths" {
  assert_eq(
    copilot_github_domain_path(
      [
        "moonstat", "copilot", "login", "--github-domain", "https://ghe.example.com",
      ],
      "/copilot/device-flow",
    ),
    "/copilot/device-flow?githubDomain=https%3A%2F%2Fghe.example.com",
  )
  assert_eq(
    copilot_device_path(
      [
        "moonstat", "copilot", "poll", "--device-code", "dev 1", "--github-domain",
        "ghe.example.com",
      ],
      "/copilot/poll-account",
    ),
    Some(
      "/copilot/poll-account?deviceCode=dev%201&githubDomain=ghe.example.com",
    ),
  )
  assert_eq(
    copilot_account_path(
      ["moonstat", "copilot", "remove", "--account-id", "ghe.example.com:42"],
      "/copilot/account",
    ),
    Some("/copilot/account?accountId=ghe.example.com%3A42"),
  )
  assert_eq(
    copilot_account_optional_path(
      ["moonstat", "copilot", "models", "--account-id", "ghe.example.com:42"],
      "/copilot/models",
    ),
    "/copilot/models?accountId=ghe.example.com%3A42",
  )
}

///|
test "usage aggregate paths accept moonstat date and app filters" {
  let args = [
    "moonstat", "usage", "summary", "--start-date", "10", "--end-date", "20", "--app-type",
    "claude desktop",
  ]
  assert_eq(
    usage_filtered_path(args, "/usage/summary", app_filter=true),
    "/usage/summary?startDate=10&endDate=20&appType=claude%20desktop",
  )
  assert_eq(
    usage_filtered_path(args, "/usage/summary/by-app", app_filter=false),
    "/usage/summary/by-app?startDate=10&endDate=20",
  )
  assert_eq(
    usage_filtered_path(args, "/usage/provider-stats", app_filter=true),
    "/usage/provider-stats?startDate=10&endDate=20&appType=claude%20desktop",
  )
  assert_eq(
    usage_filtered_path(args, "/usage/model-stats", app_filter=true),
    "/usage/model-stats?startDate=10&endDate=20&appType=claude%20desktop",
  )
}

///|
test "usage logs path accepts moonstat filters and pagination" {
  assert_eq(
    usage_logs_path([
      "moonstat", "usage", "logs", "--page", "2", "--page-size", "25", "--app-type",
      "codex", "--provider-name", "Codex OAuth", "--model", "anthropic/claude-sonnet",
      "--status-code", "200", "--start-date", "10", "--end-date", "20",
    ]),
    "/usage/logs?startDate=10&endDate=20&appType=codex&page=2&pageSize=25&providerName=Codex%20OAuth&model=anthropic%2Fclaude-sonnet&statusCode=200",
  )
}

///|
test "usage detail path encodes moonstat request ids" {
  assert_eq(
    "/usage/request-detail/\{cli_url_encode("session:msg/1")}",
    "/usage/request-detail/session%3Amsg%2F1",
  )
}

///|
test "usage kebab-case flags build canonical paths" {
  let args = [
    "moonstat", "usage", "summary", "--start-date", "10", "--end-date", "20", "--app-type",
    "codex",
  ]
  assert_eq(
    usage_filtered_path(args, "/usage/summary", app_filter=true),
    "/usage/summary?startDate=10&endDate=20&appType=codex",
  )
  assert_eq(
    usage_logs_path([
      "moonstat", "usage", "logs", "--page", "1", "--page-size", "50", "--app-type",
      "claude",
    ]),
    "/usage/logs?appType=claude&page=1&pageSize=50",
  )
  assert_eq(
    usage_limits_path([
      "moonstat", "usage", "limits", "--provider-id", "p1", "--app-type", "codex",
    ]),
    "/usage/provider-limits?providerId=p1&appType=codex",
  )
  assert_eq(
    usage_provider_script_path(
      [
        "moonstat", "usage", "query-provider-usage", "--provider-id", "p1", "--app-type",
        "codex",
      ],
      "/usage/provider-usage",
      false,
    ),
    Some("/usage/provider-usage?providerId=p1&appType=codex"),
  )
  assert_eq(
    usage_provider_script_path(
      [
        "moonstat", "usage", "test-usage-script", "--provider-id", "p1", "--app-type",
        "codex", "--script-code", "{\"success\":true}",
      ],
      "/usage/test-script",
      true,
    ),
    Some(
      "/usage/test-script?providerId=p1&appType=codex&scriptCode=%7B%22success%22%3Atrue%7D",
    ),
  )
}

///|
test "proxy config setter paths encode moonstat command arguments" {
  assert_eq(
    proxy_global_config_update_path(
      [
        "moonstat", "proxy", "global-config", "set", "--proxy-enabled", "false",
        "--listen-address", "127.0.0.2", "--listen-port", "17002", "--enable-logging",
        "off",
      ],
      "/proxy/global-config",
    ),
    "/proxy/global-config?proxyEnabled=false&listenAddress=127.0.0.2&listenPort=17002&enableLogging=off",
  )
  assert_eq(
    proxy_app_config_update_path([
      "moonstat", "proxy", "app-config", "set", "--app-type", "codex", "--enabled",
      "true", "--auto-failover-enabled", "false", "--max-retries", "5", "--streaming-first-byte-timeout",
      "11", "--streaming-idle-timeout", "22", "--non-streaming-timeout", "33", "--failure-threshold",
      "7", "--success-threshold", "3", "--timeout-seconds", "44", "--error-rate-threshold",
      "0.4", "--min-requests", "12",
    ]),
    "/proxy/app-config?appType=codex&enabled=true&autoFailoverEnabled=false&maxRetries=5&streamingFirstByteTimeout=11&streamingIdleTimeout=22&nonStreamingTimeout=33&failureThreshold=7&successThreshold=3&timeoutSeconds=44&errorRateThreshold=0.4&minRequests=12",
  )
  assert_eq(
    proxy_takeover_update_path([
      "moonstat", "proxy", "takeover-status", "set", "--app-type", "codex", "--enabled",
      "true",
    ]),
    Some("/proxy/takeover-status?appType=codex&enabled=true"),
  )
  assert_eq(
    proxy_app_value_update_path(
      [
        "moonstat", "proxy", "default-cost-multiplier", "set", "--app-type", "codex",
        "--value", "1.25",
      ],
      "/proxy/default-cost-multiplier",
    ),
    Some("/proxy/default-cost-multiplier?appType=codex&value=1.25"),
  )
  assert_eq(
    proxy_provider_endpoint_path(
      [
        "moonstat", "proxy", "switch-provider", "--app-type", "codex", "--provider-id",
        "codex-oauth",
      ],
      "/proxy/switch-provider",
    ),
    Some("/proxy/switch-provider?providerId=codex-oauth&appType=codex"),
  )
  assert_eq(
    provider_app_path(
      ["moonstat", "provider", "list", "--app-type", "codex"],
      "/providers",
    ),
    "/providers?appType=codex",
  )
  assert_eq(
    provider_id_path(
      [
        "moonstat", "provider", "switch", "--app-type", "codex", "--id", "custom",
      ],
      "/providers/switch",
    ),
    Some("/providers/switch?appType=codex&id=custom"),
  )
  assert_eq(
    provider_upsert_path(
      [
        "moonstat", "provider", "add", "--app-type", "codex", "--id", "custom", "--name",
        "Custom Provider", "--base-url", "https://api.example.com/v1", "--api-key",
        "sk-test", "--category", "custom", "--enabled", "true", "--add-to-live",
        "false",
      ],
      "/providers",
      require_original=false,
    ),
    Some(
      "/providers?appType=codex&id=custom&name=Custom%20Provider&baseUrl=https%3A%2F%2Fapi.example.com%2Fv1&apiKey=sk-test&category=custom&enabled=true&addToLive=false",
    ),
  )
  assert_eq(
    provider_id_path(
      [
        "moonstat", "provider", "endpoints", "list", "--app-type", "codex", "--id",
        "custom",
      ],
      "/providers/endpoints/list",
    ),
    Some("/providers/endpoints/list?appType=codex&id=custom"),
  )
  assert_eq(
    provider_endpoint_url_path(
      [
        "moonstat", "provider", "endpoints", "add", "--app-type", "codex", "--id",
        "custom", "--endpoint-url", "https://backup.example.com/v1",
      ],
      "/providers/endpoints",
    ),
    Some(
      "/providers/endpoints?appType=codex&providerId=custom&url=https%3A%2F%2Fbackup.example.com%2Fv1",
    ),
  )
  assert_eq(
    provider_endpoint_url_path(
      [
        "moonstat", "provider", "endpoints", "touch", "--app-type", "codex", "--id",
        "custom", "--endpoint-url", "https://backup.example.com/v1",
      ],
      "/providers/endpoints/touch",
    ),
    Some(
      "/providers/endpoints/touch?appType=codex&providerId=custom&url=https%3A%2F%2Fbackup.example.com%2Fv1",
    ),
  )
  assert_eq(
    provider_test_endpoints_path([
      "moonstat", "provider", "test-endpoints", "--urls", "https://api.example.com/v1,not-a-url",
      "--timeout-secs", "3",
    ]),
    Some(
      "/providers/test-endpoints?urls=https%3A%2F%2Fapi.example.com%2Fv1%2Cnot-a-url&timeoutSecs=3",
    ),
  )
  assert_eq(
    provider_sort_order_path([
      "moonstat", "provider", "sort-order", "set", "--app-type", "codex", "--id",
      "custom", "--sort-index", "2",
    ]),
    Some("/providers/sort-order?appType=codex&id=custom&sortIndex=2"),
  )
}

///|
test "proxy grouped commands build canonical paths" {
  assert_eq(
    proxy_global_config_update_path(
      [
        "moonstat", "proxy", "global-config", "set", "--proxy-enabled", "true", "--listen-address",
        "127.0.0.1", "--listen-port", "15721",
      ],
      "/proxy/global-config",
    ),
    "/proxy/global-config?proxyEnabled=true&listenAddress=127.0.0.1&listenPort=15721",
  )
  assert_eq(
    proxy_app_config_update_path([
      "moonstat", "proxy", "app-config", "set", "--app-type", "codex", "--enabled",
      "true", "--auto-failover-enabled", "true",
    ]),
    "/proxy/app-config?appType=codex&enabled=true&autoFailoverEnabled=true",
  )
  assert_eq(
    proxy_provider_endpoint_path(
      [
        "moonstat", "proxy", "switch-provider", "--app-type", "codex", "--provider-id",
        "codex oauth",
      ],
      "/proxy/switch-provider",
    ),
    Some("/proxy/switch-provider?providerId=codex%20oauth&appType=codex"),
  )
  assert_eq(
    proxy_auto_failover_enabled_path([
      "moonstat", "proxy", "auto-failover-enabled", "set", "--app-type", "codex",
      "--enabled", "true",
    ]),
    Some("/proxy/auto-failover-enabled?appType=codex&enabled=true"),
  )
  assert_eq(
    global_proxy_url_path(
      [
        "moonstat", "proxy", "global-url", "set", "--url", "http://127.0.0.1:7890",
      ],
      "/proxy/global-url",
    ),
    Some("/proxy/global-url?url=http%3A%2F%2F127.0.0.1%3A7890"),
  )
  assert_eq(
    global_proxy_url_path(
      ["moonstat", "proxy", "test-url", "--url", "socks5://127.0.0.1:1080"],
      "/proxy/test-url",
    ),
    Some("/proxy/test-url?url=socks5%3A%2F%2F127.0.0.1%3A1080"),
  )
  assert_eq(
    provider_app_path(
      ["moonstat", "proxy", "import-default-config", "--app-type", "codex"],
      "/proxy/import-default-config",
    ),
    "/proxy/import-default-config?appType=codex",
  )
  assert_eq(
    openclaw_default_model_path([
      "moonstat", "openclaw", "default-model", "set", "--primary", "gpt-5", "--fallbacks",
      "sonnet,opus",
    ]),
    Some("/openclaw/default-model?primary=gpt-5&fallbacks=sonnet%2Copus"),
  )
  assert_eq(
    suite_json_config_path(
      [
        "moonstat", "openclaw", "model-catalog", "set", "--catalog", "{\"fast\":{\"alias\":\"f\"}}",
      ],
      "/openclaw/model-catalog",
      "--catalog",
    ),
    Some(
      "/openclaw/model-catalog?catalog=%7B%22fast%22%3A%7B%22alias%22%3A%22f%22%7D%7D",
    ),
  )
  assert_eq(
    hermes_memory_path([
      "moonstat", "hermes", "memory", "set", "--kind", "memory", "--content", "hello world",
    ]),
    Some("/hermes/memory?kind=memory&content=hello%20world"),
  )
  assert_eq(
    hermes_memory_enabled_path([
      "moonstat", "hermes", "memory-enabled", "set", "--kind", "user", "--enabled",
      "false",
    ]),
    Some("/hermes/memory-enabled?kind=user&enabled=false"),
  )
  assert_eq(
    delete_sessions_body([
      "moonstat", "sessions", "delete-many", "--items", "[{\"providerId\":\"codex\",\"sessionId\":\"s1\",\"sourcePath\":\"/tmp/s1.jsonl\"}]",
    ]),
    Some(
      "[{\"providerId\":\"codex\",\"sessionId\":\"s1\",\"sourcePath\":\"/tmp/s1.jsonl\"}]",
    ),
  )
  assert_eq(
    delete_sessions_body([
      "moonstat", "sessions", "delete-many", "--body", "{\"items\":[]}",
    ]),
    Some("{\"items\":[]}"),
  )
  assert_eq(
    import_skills_from_apps_body([
      "moonstat", "skills", "import-apps", "--imports", "[{\"directory\":\"traffic-stats\",\"apps\":{\"codex\":true}}]",
    ]),
    Some("[{\"directory\":\"traffic-stats\",\"apps\":{\"codex\":true}}]"),
  )
  assert_eq(
    import_skills_from_apps_body([
      "moonstat", "skills", "import-apps", "--body", "{\"imports\":[]}",
    ]),
    Some("{\"imports\":[]}"),
  )
  assert_eq(
    migrate_skill_storage_path([
      "moonstat", "skills", "migrate-storage", "--target", "unified",
    ]),
    Some("/skills/migrate-storage?target=unified"),
  )
  assert_eq(
    migrate_skill_storage_path([
      "moonstat", "skills", "migrate-storage", "--target", "moonstat",
    ]),
    Some("/skills/migrate-storage?target=moonstat"),
  )
  assert_eq(
    migrate_skill_storage_path(["moonstat", "skills", "migrate-storage"]),
    None,
  )
  assert_eq(
    delete_env_vars_body([
      "moonstat", "config", "env-delete", "--conflicts", "[{\"key\":\"OPENAI_API_KEY\",\"sourcePath\":\"/tmp/.zshrc\"}]",
    ]),
    Some("[{\"key\":\"OPENAI_API_KEY\",\"sourcePath\":\"/tmp/.zshrc\"}]"),
  )
  assert_eq(
    delete_env_vars_body([
      "moonstat", "config", "env-delete", "--body", "{\"conflicts\":[]}",
    ]),
    Some("{\"conflicts\":[]}"),
  )
}

///|
test "provider grouped commands build canonical paths" {
  assert_eq(
    provider_app_path(
      ["moonstat", "provider", "list", "--app-type", "codex"],
      "/providers",
    ),
    "/providers?appType=codex",
  )
  assert_eq(
    provider_id_path(
      [
        "moonstat", "provider", "switch", "--app-type", "codex", "--provider-id",
        "custom provider",
      ],
      "/providers/switch",
    ),
    Some("/providers/switch?appType=codex&id=custom%20provider"),
  )
  assert_eq(
    provider_endpoint_url_path(
      [
        "moonstat", "provider", "endpoints", "add", "--app-type", "codex", "--provider-id",
        "custom", "--endpoint-url", "https://backup.example.com/v1",
      ],
      "/providers/endpoints",
    ),
    Some(
      "/providers/endpoints?appType=codex&providerId=custom&url=https%3A%2F%2Fbackup.example.com%2Fv1",
    ),
  )
  assert_eq(
    provider_live_ids_path("opencode"),
    "/providers/live-ids?appType=opencode",
  )
  assert_eq(
    provider_live_provider_path(
      [
        "moonstat", "provider", "openclaw", "live-get", "--provider-id", "open claw",
      ],
      "openclaw",
    ),
    Some("/providers/live-provider?appType=openclaw&providerId=open%20claw"),
  )
  assert_eq(
    provider_live_provider_path(
      ["moonstat", "provider", "hermes", "live-get", "--id", "hermes/a"],
      "hermes",
    ),
    Some("/providers/live-provider?appType=hermes&providerId=hermes%2Fa"),
  )
  assert_eq(
    provider_import_live_path("openclaw"),
    "/providers/import-live?appType=openclaw",
  )
  assert_eq(
    universal_provider_id_path(
      ["moonstat", "provider", "universal", "sync", "--id", "u 1"],
      "/providers/universal/sync",
    ),
    Some("/providers/universal/sync?id=u%201"),
  )
  assert_eq(
    universal_provider_upsert_path([
      "moonstat", "provider", "universal", "upsert", "--id", "u 1", "--name", "Universal One",
      "--provider-type", "openai-compatible", "--apps", "claude,codex", "--base-url",
      "https://api.example.com/v1", "--api-key", "sk-test", "--codex-model", "gpt-5",
      "--reasoning-effort", "medium",
    ]),
    Some(
      "/providers/universal?id=u%201&name=Universal%20One&providerType=openai-compatible&baseUrl=https%3A%2F%2Fapi.example.com%2Fv1&apiKey=sk-test&apps=claude%2Ccodex&codexModel=gpt-5&reasoningEffort=medium",
    ),
  )
  assert_eq(
    provider_presets_path([
      "moonstat", "provider", "presets", "list", "--app-type", "gemini", "--query",
      "unity2", "--sort-mode", "nameAsc",
    ]),
    "/providers/presets?appType=gemini&query=unity2&sortMode=nameAsc",
  )
}

///|
test "top level moonstat config command names build config paths" {
  assert_eq(
    config_app_path(
      ["moonstat", "config", "status", "--app-type", "codex"],
      "/config/status",
    ),
    "/config/status?appType=codex",
  )
  assert_eq(
    config_app_path(
      ["moonstat", "config", "dir", "--app-type", "openclaw"],
      "/config/dir",
    ),
    "/config/dir?appType=openclaw",
  )
  assert_eq(
    pick_directory_path([
      "moonstat", "files", "directory", "pick", "--default-path", "/tmp/claude projects",
    ]),
    "/files/directories/pick?defaultPath=%2Ftmp%2Fclaude%20projects",
  )
  assert_eq(
    config_snippet_path(
      [
        "moonstat", "config", "snippet", "set", "--app-type", "codex", "--snippet",
        "model=\"gpt-5\"",
      ],
      "/config/snippets",
      app_required=true,
    ),
    Some("/config/snippets?snippet=model%3D%22gpt-5%22&appType=codex"),
  )
  assert_eq(
    config_snippet_path(
      ["moonstat", "config", "claude-snippet", "set", "--snippet", "{}"],
      "/config/snippets/claude",
      app_required=false,
    ),
    Some("/config/snippets/claude?snippet=%7B%7D"),
  )
  assert_eq(
    extract_common_config_snippet_path([
      "moonstat", "config", "snippet", "extract", "--app-type", "claude", "--settings-config",
      "{\"env\":{}}",
    ]),
    "/config/snippets/extract?appType=claude&settingsConfig=%7B%22env%22%3A%7B%7D%7D",
  )
  assert_eq(
    restore_env_backup_path([
      "moonstat", "config", "env-restore", "--backup-path", "/tmp/env backup.json",
    ]),
    Some("/config/env/restore?backupPath=%2Ftmp%2Fenv%20backup.json"),
  )
  assert_eq(
    config_file_path(
      [
        "moonstat", "config", "file", "export", "--file-path", "/tmp/moon stat.json",
      ],
      "/config/files/export",
    ),
    "/config/files/export?filePath=%2Ftmp%2Fmoon%20stat.json",
  )
  assert_eq(
    config_file_path(
      ["moonstat", "config", "file", "import", "--path", "/tmp/in.json"],
      "/config/files/import",
    ),
    "/config/files/import?filePath=%2Ftmp%2Fin.json",
  )
  assert_eq(
    db_backup_filename_path(
      ["moonstat", "backups", "db", "restore", "--filename", "moonstat-1.db"],
      "/backups/db/restore",
    ),
    "/backups/db/restore?filename=moonstat-1.db",
  )
  assert_eq(
    db_backup_rename_path([
      "moonstat", "backups", "db", "rename", "--old-filename", "moonstat-1.db", "--new-name",
      "renamed",
    ]),
    "/backups/db/rename?oldFilename=moonstat-1.db&newName=renamed",
  )
  assert_eq(
    db_backup_filename_path(
      ["moonstat", "backups", "db", "delete", "--name", "renamed.db"],
      "/backups/db/delete",
    ),
    "/backups/db/delete?filename=renamed.db",
  )
  assert_eq(
    deeplink_url_path(
      [
        "moonstat", "deeplink", "parse", "--url", "moonstat://v1/import?resource=skill&repo=vectie/skills",
      ],
      "/deeplinks/parse",
    ),
    "/deeplinks/parse?url=moonstat%3A%2F%2Fv1%2Fimport%3Fresource%3Dskill%26repo%3Dvectie%2Fskills",
  )
  assert_eq(
    deeplink_request_path(
      [
        "moonstat", "deeplink", "merge", "--request", "{\"resource\":\"provider\"}",
      ],
      "/deeplinks/merge",
    ),
    "/deeplinks/merge?request=%7B%22resource%22%3A%22provider%22%7D",
  )
  assert_eq(
    deeplink_request_path(
      [
        "moonstat", "deeplink", "import", "--url", "moonstat://v1/import?resource=prompt&appType=codex&name=Daily&content=SGVsbG8",
      ],
      "/deeplinks/import",
    ),
    "/deeplinks/import?url=moonstat%3A%2F%2Fv1%2Fimport%3Fresource%3Dprompt%26appType%3Dcodex%26name%3DDaily%26content%3DSGVsbG8",
  )
  assert_eq(
    sync_settings_path(
      [
        "moonstat", "sync", "webdav", "settings", "--settings", "{\"baseUrl\":\"https://dav.example.com\"}",
        "--password-touched", "false",
      ],
      "/sync/webdav/settings",
    ),
    "/sync/webdav/settings?settings=%7B%22baseUrl%22%3A%22https%3A%2F%2Fdav.example.com%22%7D&passwordTouched=false",
  )
  assert_eq(
    sync_settings_path(
      [
        "moonstat", "sync", "s3", "test", "--config", "{\"bucket\":\"moonstat\"}",
        "--preserve-empty-password", "true",
      ],
      "/sync/s3/test",
    ),
    "/sync/s3/test?settings=%7B%22bucket%22%3A%22moonstat%22%7D&preserveEmptyPassword=true",
  )
}

///|
test "top level moonstat settings command names build settings paths" {
  assert_eq(
    app_config_dir_override_path([
      "moonstat", "settings", "app-config-dir", "set", "--path", "/tmp/cc switch",
    ]),
    Some("/settings/app-config-dir?path=%2Ftmp%2Fcc%20switch"),
  )
  assert_eq(
    app_config_dir_override_path([
      "moonstat", "settings", "app-config-dir", "set", "--clear", "true",
    ]),
    Some("/settings/app-config-dir?path="),
  )
  assert_eq(
    set_auto_launch_path([
      "moonstat", "settings", "auto-launch", "set", "--enabled", "true",
    ]),
    Some("/settings/auto-launch?enabled=true"),
  )
  assert_eq(
    moon_json_config_path(
      [
        "moonstat", "settings", "rectifier", "set", "--request-thinking-signature",
        "false",
      ],
      "/settings/rectifier",
      "--config",
    ),
    Some("/settings/rectifier?requestThinkingSignature=false"),
  )
  assert_eq(
    moon_json_config_path(
      [
        "moonstat", "settings", "optimizer", "set", "--config", "{\"cacheTtl\":\"5m\"}",
      ],
      "/settings/optimizer",
      "--config",
    ),
    Some("/settings/optimizer?config=%7B%22cacheTtl%22%3A%225m%22%7D"),
  )
  assert_eq(
    moon_json_config_path(
      [
        "moonstat", "settings", "copilot-optimizer", "set", "--warmup-model", "gpt-5-mini",
        "--strip-thinking", "true",
      ],
      "/settings/copilot-optimizer",
      "--config",
    ),
    Some(
      "/settings/copilot-optimizer?warmupModel=gpt-5-mini&stripThinking=true",
    ),
  )
}

///|
test "top level moonstat plugin command names build plugin paths" {
  assert_eq(
    apply_claude_plugin_config_path([
      "moonstat", "plugin", "claude", "apply", "--official", "true",
    ]),
    "/plugin/claude/config?official=true",
  )
  assert_eq(
    apply_claude_plugin_config_path(["moonstat", "plugin", "claude", "apply"]),
    "/plugin/claude/config",
  )
}

///|
test "top level moonstat workspace command names build workspace paths" {
  assert_eq(
    workspace_filename_path(
      ["moonstat", "workspace", "read", "--filename", "AGENTS.md"],
      "/workspace/files",
    ),
    "/workspace/files?filename=AGENTS.md",
  )
  assert_eq(
    workspace_content_path(
      [
        "moonstat", "workspace", "write", "--filename", "AGENTS.md", "--content",
        "hello moon",
      ],
      "/workspace/files",
    ),
    Some("/workspace/files?filename=AGENTS.md&content=hello%20moon"),
  )
  assert_eq(
    workspace_query_path(
      ["moonstat", "workspace", "memory", "search", "--query", "daily plan"],
      "/workspace/memory/search",
    ),
    "/workspace/memory/search?query=daily%20plan",
  )
  assert_eq(
    workspace_subdir_path(
      ["moonstat", "workspace", "open", "--subdir", "memory"],
      "/workspace/open",
    ),
    "/workspace/open?subdir=memory",
  )
}

///|
test "top level moonstat mcp command names build mcp paths" {
  assert_eq(
    mcp_app_path(
      ["moonstat", "mcp", "config", "--app-type", "codex"],
      "/mcp/config",
    ),
    "/mcp/config?appType=codex",
  )
  assert_eq(
    mcp_validate_command_path([
      "moonstat", "mcp", "validate", "--command", "npx",
    ]),
    "/mcp/validate?command=npx",
  )
  assert_eq(
    mcp_id_path(
      ["moonstat", "mcp", "delete", "--server-id", "filesystem server"],
      "/mcp/servers",
    ),
    Some("/mcp/servers?id=filesystem%20server"),
  )
  guard mcp_upsert_path(
      [
        "moonstat", "mcp", "upsert-config", "--app-type", "codex", "--id", "filesystem",
        "--name", "Filesystem", "--command", "npx", "--sync-other-side", "true",
      ],
      "/mcp/config/servers",
    )
    is Some(upsert_path) else {
    fail("expected upsert path")
  }
  assert_true(upsert_path.has_prefix("/mcp/config/servers?server="))
  assert_true(upsert_path.contains("&appType=codex"))
  assert_true(upsert_path.contains("&syncOtherSide=true"))
  assert_true(upsert_path.contains("Filesystem"))
  assert_true(upsert_path.contains("npx"))
  assert_eq(
    mcp_enabled_path(
      [
        "moonstat", "mcp", "toggle", "--id", "filesystem", "--app-type", "codex",
        "--enabled", "false",
      ],
      "/mcp/apps/toggle",
    ),
    Some("/mcp/apps/toggle?id=filesystem&appType=codex&enabled=false"),
  )
}

///|
test "top level moonstat prompt command names build prompt paths" {
  assert_eq(
    prompt_app_path(
      ["moonstat", "prompt", "list", "--app-type", "codex"],
      "/prompts",
    ),
    "/prompts?appType=codex",
  )
  assert_eq(
    prompt_upsert_path([
      "moonstat", "prompt", "upsert", "--app-type", "codex", "--id", "review", "--name",
      "Review", "--content", "Check this", "--description", "Code review", "--enabled",
      "true",
    ]),
    Some(
      "/prompts?appType=codex&id=review&name=Review&content=Check%20this&description=Code%20review&enabled=true",
    ),
  )
  assert_eq(
    prompt_id_path(
      ["moonstat", "prompt", "delete", "--app-type", "codex", "--id", "review"],
      "/prompts",
    ),
    Some("/prompts?appType=codex&id=review"),
  )
  assert_eq(
    prompt_file_path(
      [
        "moonstat", "prompt", "import", "--app-type", "codex", "--path", "/tmp/prompts.md",
      ],
      "/prompts/import-file",
    ),
    "/prompts/import-file?appType=codex&filePath=%2Ftmp%2Fprompts.md",
  )
}

///|
test "usage balance command builds balance path" {
  assert_eq(
    balance_path([
      "moonstat", "usage", "balance", "--base-url", "https://api.deepseek.com", "--api-key",
      "sk test",
    ]),
    Some(
      "/usage/balance?baseUrl=https%3A%2F%2Fapi.deepseek.com&apiKey=sk%20test",
    ),
  )
  assert_true(
    balance_path([
      "moonstat", "usage", "balance", "--base-url", "https://api.deepseek.com",
    ])
    is None,
  )
}

///|
test "usage subscription quota command builds quota path" {
  assert_eq(
    subscription_quota_path(["moonstat", "usage", "quota", "--tool", "gemini"]),
    Some("/usage/subscription-quota?tool=gemini"),
  )
  assert_true(subscription_quota_path(["moonstat", "usage", "quota"]) is None)
}

///|
test "usage codex oauth quota command builds quota path" {
  assert_eq(
    codex_oauth_quota_path([
      "moonstat", "usage", "codex-oauth-quota", "--account-id", "acct 1",
    ]),
    "/usage/codex-oauth-quota?accountId=acct%201",
  )
  assert_eq(
    codex_oauth_quota_path(["moonstat", "usage", "codex-oauth-quota"]),
    "/usage/codex-oauth-quota",
  )
}

///|
test "usage codex oauth models command builds models path" {
  assert_eq(
    codex_oauth_models_path([
      "moonstat", "usage", "codex-oauth-models", "--account-id", "acct 1",
    ]),
    "/usage/codex-oauth-models?accountId=acct%201",
  )
  assert_eq(
    codex_oauth_models_path(["moonstat", "usage", "codex-oauth-models"]),
    "/usage/codex-oauth-models",
  )
}

///|
test "moonstat auth commands build managed auth paths" {
  assert_eq(
    auth_provider_path(
      ["moonstat", "auth", "status", "--auth-provider", "codex_oauth"],
      "/auth/status",
    ),
    "/auth/status?authProvider=codex_oauth",
  )
  assert_eq(
    auth_provider_path(["moonstat", "auth", "status"], "/auth/status"),
    "/auth/status",
  )
  assert_eq(
    auth_account_path(
      [
        "moonstat", "auth", "remove", "--account-id", "acct 1", "--auth-provider",
        "codex_oauth",
      ],
      "/auth/account",
    ),
    Some("/auth/account?accountId=acct%201&authProvider=codex_oauth"),
  )
  assert_true(
    auth_account_path(["moonstat", "auth", "remove"], "/auth/account") is None,
  )
  assert_eq(
    auth_poll_path([
      "moonstat", "auth", "poll", "--device-code", "dev 1", "--user-code", "USER-CODE",
    ]),
    Some("/auth/poll?deviceCode=dev%201&userCode=USER-CODE"),
  )
}

///|
test "usage coding plan command builds quota path" {
  assert_eq(
    coding_plan_quota_path([
      "moonstat", "usage", "coding-plan", "--base-url", "https://api.minimax.io",
      "--api-key", "key",
    ]),
    Some(
      "/usage/coding-plan-quota?baseUrl=https%3A%2F%2Fapi.minimax.io&apiKey=key",
    ),
  )
  assert_true(
    coding_plan_quota_path(["moonstat", "usage", "coding-plan"]) is None,
  )
}

///|
test "top level moonstat app shell commands build paths" {
  assert_eq(
    open_external_path([
      "moonstat", "runtime", "open-external", "--url", "github.com/a b",
    ]),
    "/runtime/open-external?url=github.com%2Fa%20b",
  )
  assert_eq(
    copy_text_to_clipboard_path([
      "moonstat", "runtime", "copy-text", "--text", "hello world",
    ]),
    "/runtime/clipboard/text?text=hello%20world",
  )
  assert_eq(
    tool_versions_path([
      "moonstat", "tools", "versions", "--tools", "codex,claude",
    ]),
    "/tools/versions?tools=codex%2Cclaude",
  )
  assert_eq(
    window_theme_path([
      "moonstat", "runtime", "window-theme", "set", "--theme", "dark",
    ]),
    "/runtime/window-theme?theme=dark",
  )
  assert_eq(
    save_file_dialog_path([
      "moonstat", "files", "save-dialog", "--default-name", "config.json",
    ]),
    "/files/dialogs/save?defaultName=config.json",
  )
}

///|
test "top level moonstat skill commands build paths" {
  assert_eq(
    skill_install_path(
      [
        "moonstat", "skills", "install-unified", "--directory", "traffic stats",
        "--name", "Traffic Stats", "--description", "Routes and usage", "--app-type",
        "codex",
      ],
      "/skills/install-unified",
    ),
    "/skills/install-unified?directory=traffic%20stats&name=Traffic%20Stats&description=Routes%20and%20usage&appType=codex",
  )
  assert_eq(
    skill_toggle_app_path([
      "moonstat", "skills", "toggle-app", "--id", "traffic-stats", "--app-type",
      "hermes", "--enabled", "true",
    ]),
    "/skills/toggle-app?id=traffic-stats&appType=hermes&enabled=true",
  )
  assert_eq(
    skill_restore_backup_path([
      "moonstat", "skills", "backup", "restore", "--backup-id", "traffic-stats-1",
      "--current-app", "claude",
    ]),
    "/skills/backups/restore?backupId=traffic-stats-1&currentApp=claude",
  )
  assert_eq(
    skill_search_path([
      "moonstat", "skills", "search", "--query", "proxy skill", "--limit", "5", "--offset",
      "10",
    ]),
    "/skills/search?query=proxy%20skill&limit=5&offset=10",
  )
  assert_eq(
    skill_repo_add_path([
      "moonstat", "skills", "repo", "add", "--owner", "vectie", "--name", "moonstat-skills",
      "--branch", "main", "--enabled", "true",
    ]),
    "/skills/repos?owner=vectie&name=moonstat-skills&branch=main&enabled=true",
  )
  assert_eq(
    skill_zip_install_path([
      "moonstat", "skills", "install-zip", "--file-path", "/tmp/skill bundle", "--current-app",
      "codex",
    ]),
    "/skills/install-zip?filePath=%2Ftmp%2Fskill%20bundle&currentApp=codex",
  )
}
