///|
test "has flag matches exact CLI option" {
  let args = ["moongate", "models", "fetch", "--full-url"]
  assert_true(has_flag(args, "--full-url"))
  assert_false(has_flag(args, "--is-full-url"))
}

///|
test "status json uses canonical moongate cli keys" {
  let claude = @claude_desktop.ClaudeDesktopStatus::new(
    configured=true,
    profile_path="/tmp/profile.json",
    meta_path="/tmp/meta.json",
    config_library_path="/tmp/configLibrary",
    token_configured=true,
  )
  let claude_body = claude_desktop_status_json(claude).stringify()
  assert_true(claude_body.contains("\"profilePath\""))
  assert_true(claude_body.contains("\"metaPath\""))
  assert_true(claude_body.contains("\"tokenConfigured\""))
  assert_false(claude_body.contains("\"profile_path\""))
  assert_false(claude_body.contains("\"meta_path\""))
  assert_false(claude_body.contains("\"token_configured\""))
  let codex_body = codex_status_fields_json(
    configured=true,
    config_path="/tmp/config.toml",
    base_url=Some("http://127.0.0.1:15721/v1"),
    model=Some("gpt-5"),
  ).stringify()
  assert_true(codex_body.contains("\"configPath\""))
  assert_true(codex_body.contains("\"baseUrl\""))
  assert_false(codex_body.contains("\"config_path\""))
  assert_false(codex_body.contains("\"base_url\""))
}

///|
test "registered cli commands match suite command aliases and status commands" {
  assert_true(registered_cli_command_id(["moongate", "start"]) == Some("start"))
  assert_true(
    registered_cli_command_id([
      "moongate", "hosts", "install", "--port", "15721",
    ]) ==
    Some("install_reroute"),
  )
  assert_true(registered_cli_command_id(["moongate", "install"]) is None)
  assert_true(registered_cli_command_id(["moongate", "uninstall"]) is None)
  assert_true(
    registered_cli_command_id(["moongate", "hosts", "uninstall"]) ==
    Some("uninstall_reroute"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "claude-desktop", "status"]) ==
    Some("status_claude_desktop"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "codex", "uninstall"]) ==
    Some("uninstall_codex"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "codex", "remove"]) is None,
  )
  assert_true(registered_cli_command_id(["moongate", "remove"]) is None)
  assert_true(
    registered_cli_command_id(["moongate", "claude-desktop", "remove"]) is None,
  )
  assert_true(registered_cli_command_id(["moongate", "help"]) == Some("help"))
  assert_true(registered_cli_command_id(["moongate", "login"]) is None)
  assert_true(
    registered_cli_command_id(["moongate", "auth", "login"]) ==
    Some("auth_start_login"),
  )
  assert_true(registered_cli_command_id(["moongate", "--help"]) is None)
  assert_true(
    registered_cli_command_id(["moongate", "version"]) == Some("version"),
  )
  assert_true(registered_cli_command_id(["moongate", "--version"]) is None)
  assert_true(
    registered_cli_command_id(["moongate", "sync", "webdav", "upload"]) ==
    Some("webdav_sync_upload"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "sync", "s3", "test"]) ==
    Some("s3_test_connection"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "sessions", "list"]) ==
    Some("list_sessions"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "sessions", "terminal"]) ==
    Some("launch_session_terminal"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "provider", "omo-slim", "file"]) ==
    Some("read_omo_slim_local_file"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "providers", "omo-slim", "file"])
    is None,
  )
  assert_true(
    registered_cli_command_id(["moongate", "files", "open-zip-dialog"]) ==
    Some("open_zip_file_dialog"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "skills", "installed"]) ==
    Some("get_installed_skills"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "skills", "backup", "restore"]) ==
    Some("restore_skill_backup"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "skills", "import-apps"]) ==
    Some("import_skills_from_apps"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "skills", "search"]) ==
    Some("search_skills_sh"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "skills", "repo", "add"]) ==
    Some("add_skill_repo"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "config", "snippet", "set"]) ==
    Some("set_common_config_snippet"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "config", "env-conflicts"]) ==
    Some("check_env_conflicts"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "config", "env-restore"]) ==
    Some("restore_env_backup"),
  )
  assert_true(
    cli_args_match_pattern(
      ["moongate", "suite", "manifest", "--host", "127.0.0.1"],
      "suite manifest",
    ),
  )
  assert_false(cli_args_match_pattern(["moongate", "suite"], "suite status"))
  assert_true(
    registered_cli_command_id(["moongate", "suite", "constitution"]) ==
    Some("suite_constitution"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "suite", "constitution-negative"]) ==
    Some("suite_constitution_negative"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "suite", "autonomy-check"]) ==
    Some("suite_autonomy_check"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "suite", "moonclaw-providers"]) ==
    Some("suite_moonclaw_providers"),
  )
  assert_true(
    registered_cli_command_id([
      "moongate", "suite", "drift", "--root", "/tmp/suite",
    ]) ==
    Some("suite_drift"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "suite", "lepusa"]) ==
    Some("suite_lepusa"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "suite", "lepusa-rabbita"]) ==
    Some("suite_lepusa_rabbita"),
  )
  assert_true(
    registered_cli_command_id([
      "moongate", "suite", "write-moonclaw-providers", "--path", "/tmp/providers.json",
    ]) ==
    Some("suite_write_moonclaw_providers"),
  )
  assert_true(
    registered_cli_command_id([
      "moongate", "auth", "poll", "--device-code", "abc",
    ]) ==
    Some("auth_poll_for_account"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "auth", "status"]) ==
    Some("auth_get_status"),
  )
  assert_true(
    registered_cli_command_id([
      "moongate", "copilot", "models", "--account-id", "ghe:42",
    ]) ==
    Some("copilot_get_models"),
  )
  assert_true(
    registered_cli_command_id([
      "moongate", "copilot", "token", "--account-id", "ghe:42",
    ]) ==
    Some("copilot_get_token"),
  )
  assert_true(
    registered_cli_command_id([
      "moongate", "stream-check", "provider", "--provider-id", "codex",
    ]) ==
    Some("stream_check_provider"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "stream-check", "all"]) ==
    Some("stream_check_all_providers"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "stream-check", "config", "set"]) ==
    Some("save_stream_check_config"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "stream-check", "config"]) ==
    Some("get_stream_check_config"),
  )
  assert_eq(
    registered_cli_command_id(["moongate", "proxy", "config", "set"]),
    None,
  )
  assert_true(
    registered_cli_command_id(["moongate", "proxy", "config"]) == None,
  )
  assert_true(
    registered_cli_command_id(["moongate", "proxy", "global-url", "set"]) ==
    Some("set_global_proxy_url"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "proxy", "failover-queue", "add"]) ==
    Some("add_to_failover_queue"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "proxy", "failover-queue"]) ==
    Some("get_failover_queue"),
  )
  assert_true(
    registered_cli_command_id([
      "moongate", "proxy", "auto-failover-enabled", "set",
    ]) ==
    Some("set_auto_failover_enabled"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "proxy", "takeover-status", "set"]) ==
    Some("set_proxy_takeover_for_app"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "proxy", "running"]) ==
    Some("get_proxy_running"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "provider", "list"]) ==
    Some("get_providers"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "provider", "universal", "upsert"]) ==
    Some("upsert_universal_provider"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "provider", "endpoints", "add"]) ==
    Some("add_custom_endpoint"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "provider", "sort-order", "set"]) ==
    Some("update_providers_sort_order"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "provider", "live-ids"]) ==
    Some("provider_live_ids"),
  )
  assert_true(
    registered_cli_command_id([
      "moongate", "provider", "openclaw", "import-live",
    ]) ==
    Some("import_openclaw_providers_from_live"),
  )
  assert_true(
    registered_cli_command_id([
      "moongate", "provider", "claude-desktop", "official",
    ]) ==
    Some("claude_desktop_provider_official"),
  )
  assert_true(
    registered_cli_command_id([
      "moongate", "providers", "claude-desktop", "official",
    ])
    is None,
  )
  assert_true(
    registered_cli_command_id(["moongate", "models", "fetch"]) ==
    Some("fetch_models"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "fetch_models_for_config"]) is None,
  )
  assert_true(
    registered_cli_command_id(["moongate", "models", "candidates"]) ==
    Some("model_candidates"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "openclaw", "config-health"]) ==
    Some("scan_openclaw_config_health"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "openclaw", "model-catalog", "set"]) ==
    Some("set_openclaw_model_catalog"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "openclaw", "agents-defaults"]) ==
    Some("get_openclaw_agents_defaults"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "openclaw", "tools", "set"]) ==
    Some("set_openclaw_tools"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "hermes", "memory"]) ==
    Some("get_hermes_memory"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "hermes", "web-ui"]) ==
    Some("open_hermes_web_ui"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "hermes", "dashboard"]) ==
    Some("launch_hermes_dashboard"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "config", "status"]) ==
    Some("get_config_status"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "config", "claude-code", "path"]) ==
    Some("get_claude_code_config_path"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "config", "folder", "open"]) ==
    Some("open_config_folder"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "files", "directory", "pick"]) ==
    Some("pick_directory"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "runtime", "copy-text"]) ==
    Some("copy_text_to_clipboard"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "runtime", "updates", "check"]) ==
    Some("check_for_updates"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "tools", "versions"]) ==
    Some("get_tool_versions"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "tools", "lifecycle-action"]) ==
    Some("run_tool_lifecycle_action"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "runtime", "lightweight", "enter"]) ==
    Some("enter_lightweight_mode"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "files", "save-dialog"]) ==
    Some("save_file_dialog"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "config", "file", "export"]) ==
    Some("export_config_to_file"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "backups", "db", "rename"]) ==
    Some("rename_db_backup"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "deeplink", "parse"]) ==
    Some("parse_deeplink"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "deeplink", "import"]) ==
    Some("import_from_deeplink"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "settings", "get"]) ==
    Some("get_settings"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "settings", "save"]) ==
    Some("save_settings"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "settings", "app-config-dir", "set"]) ==
    Some("set_app_config_dir_override"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "settings", "app-config-dir"]) ==
    Some("get_app_config_dir_override"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "settings", "auto-launch", "set"]) ==
    Some("set_auto_launch"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "settings", "auto-launch"]) ==
    Some("get_auto_launch_status"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "settings", "rectifier", "set"]) ==
    Some("set_rectifier_config"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "settings", "rectifier"]) ==
    Some("get_rectifier_config"),
  )
  assert_true(
    registered_cli_command_id([
      "moongate", "settings", "copilot-optimizer", "set",
    ]) ==
    Some("set_copilot_optimizer_config"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "runtime", "restart"]) ==
    Some("restart_app"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "plugin", "claude", "status"]) ==
    Some("get_claude_plugin_status"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "plugin", "claude", "apply"]) ==
    Some("apply_claude_plugin_config"),
  )
  assert_true(
    registered_cli_command_id([
      "moongate", "plugin", "claude", "onboarding-skip",
    ]) ==
    Some("apply_claude_onboarding_skip"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "workspace", "memory", "list"]) ==
    Some("list_daily_memory_files"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "workspace", "memory", "search"]) ==
    Some("search_daily_memory_files"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "workspace", "read"]) ==
    Some("read_workspace_file"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "workspace", "open"]) ==
    Some("open_workspace_directory"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "mcp", "status"]) ==
    Some("get_claude_mcp_status"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "mcp", "upsert-config"]) ==
    Some("upsert_mcp_server_in_config"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "mcp", "validate"]) ==
    Some("validate_mcp_command"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "mcp", "toggle"]) ==
    Some("toggle_mcp_app"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "prompt", "list"]) ==
    Some("get_prompts"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "prompt", "upsert"]) ==
    Some("upsert_prompt"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "prompt", "current"]) ==
    Some("get_current_prompt_file_content"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "prompts", "current"]) is None,
  )
  assert_true(
    registered_cli_command_id(["moongate", "prompts", "import"]) is None,
  )
  assert_true(
    registered_cli_command_id(["moongate", "usage", "summary"]) ==
    Some("get_usage_summary"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "usage", "apps"]) ==
    Some("get_usage_summary_by_app"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "usage", "logs"]) ==
    Some("get_request_logs"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "usage", "pricing", "set"]) ==
    Some("update_model_pricing"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "usage", "pricing", "delete"]) ==
    Some("delete_model_pricing"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "usage", "pricing"]) ==
    Some("get_model_pricing"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "usage", "provider-usage"]) ==
    Some("query_provider_usage"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "usage", "query-provider-usage"])
    is None,
  )
  assert_true(
    registered_cli_command_id(["moongate", "usage", "quota"]) ==
    Some("get_subscription_quota"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "usage", "codex-oauth-models"]) ==
    Some("get_codex_oauth_models"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "usage", "test-script"]) ==
    Some("test_usage_script"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "usage", "test-usage-script"])
    is None,
  )
  assert_true(
    registered_cli_command_id(["moongate", "usage", "detail"]) ==
    Some("get_request_detail"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "status"]) == Some("status"),
  )
  assert_true(
    registered_cli_command_id(["moongate", "health"]) == Some("health"),
  )
  assert_true(registered_cli_command_id(["moongate", "stats"]) == Some("stats"))
  assert_true(
    registered_cli_command_id(["moongate", "metrics"]) == Some("metrics"),
  )
}

///|
test "cli command route owns command family dispatch" {
  assert_eq(registered_cli_command_groups().length(), 15)
  assert_eq(
    registered_cli_command_route(["moongate", "provider", "list"]),
    Some(("provider", "get_providers")),
  )
  assert_eq(
    registered_cli_command_route(["moongate", "settings", "get"]),
    Some(("config", "get_settings")),
  )
  assert_eq(
    registered_cli_command_route(["moongate", "start"]),
    Some(("install", "start")),
  )
  assert_eq(
    registered_cli_command_route(["moongate", "help"]),
    Some(("core", "help")),
  )
  assert_true(registered_cli_command_route(["moongate", "--help"]) is None)
  assert_true(registered_cli_command_route(["moongate", "not-real"]) is None)
  assert_eq(
    registered_cli_command_route(["moongate", "usage", "summary"]),
    Some(("usage", "get_usage_summary")),
  )
  assert_eq(
    registered_cli_command_route(["moongate", "proxy", "running"]),
    Some(("proxy", "get_proxy_running")),
  )
  assert_eq(
    registered_cli_command_route(["moongate", "runtime", "restart"]),
    Some(("runtime", "restart_app")),
  )
  assert_eq(
    registered_cli_command_route(["moongate", "stream-check", "all"]),
    Some(("stream-check", "stream_check_all_providers")),
  )
}

///|
test "usage sync path accepts standalone projects dir override" {
  let client = @moongate.MoonGateClient::new(base_url="http://127.0.0.1:15721")
  assert_eq(
    client.usage_sync_session_url(
      query=Some(usage_sync_query(["moongate", "usage", "sync"])),
    ),
    "http://127.0.0.1:15721/usage/sync-session",
  )
  assert_eq(
    client.usage_sync_session_url(
      query=Some(
        usage_sync_query([
          "moongate", "usage", "sync", "--projects-dir", "/tmp/claude projects",
          "--codex-dir", "/tmp/codex", "--gemini-dir", "/tmp/gemini", "--opencode-export-path",
          "/tmp/opencode/messages.jsonl", "--opencode-db-path", "/tmp/opencode/opencode.db?mode=ro",
        ]),
      ),
    ),
    "http://127.0.0.1:15721/usage/sync-session?projectsDir=%2Ftmp%2Fclaude%20projects&codexDir=%2Ftmp%2Fcodex&geminiDir=%2Ftmp%2Fgemini&opencodeExportPath=%2Ftmp%2Fopencode%2Fmessages.jsonl&opencodeDbPath=%2Ftmp%2Fopencode%2Fopencode.db%3Fmode%3Dro",
  )
}

///|
test "usage pricing paths accept moongate editable pricing args" {
  assert_eq(
    usage_pricing_update_path([
      "moongate", "usage", "pricing", "set", "--model-id", "anthropic/claude&sonnet",
      "--display-name", "Custom Model", "--input-cost", "1", "--output-cost", "2",
      "--cache-read-cost", "0.1", "--cache-creation-cost", "0",
    ]),
    Some(
      "/usage/model-pricing?modelId=anthropic%2Fclaude%26sonnet&displayName=Custom%20Model&inputCost=1&outputCost=2&cacheReadCost=0.1&cacheCreationCost=0",
    ),
  )
  assert_eq(
    usage_pricing_delete_path([
      "moongate", "usage", "pricing", "delete", "--model-id", "anthropic/claude&sonnet",
    ]),
    Some("/usage/model-pricing?modelId=anthropic%2Fclaude%26sonnet"),
  )
  assert_eq(
    usage_pricing_update_path([
      "moongate", "usage", "pricing", "set", "--model-id", "custom",
    ]),
    None,
  )
}

///|
test "usage filter paths encode moongate query values" {
  let client = @moongate.MoonGateClient::new(base_url="http://127.0.0.1:15721")
  let trend_args = [
    "moongate", "usage", "trends", "--start-date", "10", "--end-date", "20", "--app-type",
    "claude desktop",
  ]
  assert_eq(
    client.usage_trends_url(
      query=Some(usage_query(trend_args, app_filter=true)),
    ),
    "http://127.0.0.1:15721/usage/trends?startDate=10&endDate=20&appType=claude%20desktop",
  )
  assert_eq(
    usage_limits_path([
      "moongate", "usage", "limits", "--provider-id", "Codex OAuth", "--app-type",
      "codex", "--daily-limit-usd", "1.5", "--monthly-limit-usd", "30",
    ]),
    "/usage/provider-limits?providerId=Codex%20OAuth&appType=codex&dailyLimitUsd=1.5&monthlyLimitUsd=30",
  )
}

///|
test "stream check paths use moongate command names and kebab-case flags" {
  assert_eq(
    stream_check_provider_path([
      "moongate", "stream-check", "provider", "--app-type", "codex", "--provider-id",
      "codex oauth",
    ]),
    Some("/proxy/stream-check/provider?appType=codex&providerId=codex%20oauth"),
  )
  assert_eq(
    stream_check_all_path([
      "moongate", "stream-check", "all", "--app-type", "claude", "--proxy-targets-only",
      "true",
    ]),
    "/proxy/stream-check/all?appType=claude&proxyTargetsOnly=true",
  )
  assert_eq(
    stream_check_config_update_path([
      "moongate", "stream-check", "config", "set", "--codex-model", "gpt/5", "--timeout-secs",
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
        "moongate", "copilot", "login", "--github-domain", "https://ghe.example.com",
      ],
      "/copilot/device-flow",
    ),
    "/copilot/device-flow?githubDomain=https%3A%2F%2Fghe.example.com",
  )
  assert_eq(
    copilot_device_path(
      [
        "moongate", "copilot", "poll", "--device-code", "dev 1", "--github-domain",
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
      ["moongate", "copilot", "remove", "--account-id", "ghe.example.com:42"],
      "/copilot/account",
    ),
    Some("/copilot/account?accountId=ghe.example.com%3A42"),
  )
  assert_eq(
    copilot_account_optional_path(
      ["moongate", "copilot", "models", "--account-id", "ghe.example.com:42"],
      "/copilot/models",
    ),
    "/copilot/models?accountId=ghe.example.com%3A42",
  )
}

///|
test "usage aggregate paths accept moongate date and app filters" {
  let client = @moongate.MoonGateClient::new(base_url="http://127.0.0.1:15721")
  let args = [
    "moongate", "usage", "summary", "--start-date", "10", "--end-date", "20", "--app-type",
    "claude desktop",
  ]
  assert_eq(
    client.usage_summary_url(query=Some(usage_query(args, app_filter=true))),
    "http://127.0.0.1:15721/usage/summary?startDate=10&endDate=20&appType=claude%20desktop",
  )
  assert_eq(
    client.usage_summary_by_app_url(
      query=Some(usage_query(args, app_filter=false)),
    ),
    "http://127.0.0.1:15721/usage/summary/by-app?startDate=10&endDate=20",
  )
  assert_eq(
    client.usage_provider_stats_url(
      query=Some(usage_query(args, app_filter=true)),
    ),
    "http://127.0.0.1:15721/usage/provider-stats?startDate=10&endDate=20&appType=claude%20desktop",
  )
  assert_eq(
    client.usage_model_stats_url(query=Some(usage_query(args, app_filter=true))),
    "http://127.0.0.1:15721/usage/model-stats?startDate=10&endDate=20&appType=claude%20desktop",
  )
}

///|
test "usage logs path accepts moongate filters and pagination" {
  let client = @moongate.MoonGateClient::new(base_url="http://127.0.0.1:15721")
  assert_eq(
    client.usage_logs_url(
      query=Some(
        usage_logs_query([
          "moongate", "usage", "logs", "--page", "2", "--page-size", "25", "--app-type",
          "codex", "--provider-name", "Codex OAuth", "--model", "anthropic/claude-sonnet",
          "--status-code", "200", "--start-date", "10", "--end-date", "20",
        ]),
      ),
    ),
    "http://127.0.0.1:15721/usage/logs?startDate=10&endDate=20&appType=codex&providerName=Codex%20OAuth&model=anthropic%2Fclaude-sonnet&statusCode=200&page=2&pageSize=25",
  )
}

///|
test "usage detail path encodes moongate request ids" {
  assert_eq(
    "/usage/request-detail/\{cli_url_encode("session:msg/1")}",
    "/usage/request-detail/session%3Amsg%2F1",
  )
}

///|
test "usage kebab-case flags build canonical paths" {
  let client = @moongate.MoonGateClient::new(base_url="http://127.0.0.1:15721")
  let args = [
    "moongate", "usage", "summary", "--start-date", "10", "--end-date", "20", "--app-type",
    "codex",
  ]
  assert_eq(
    client.usage_summary_url(query=Some(usage_query(args, app_filter=true))),
    "http://127.0.0.1:15721/usage/summary?startDate=10&endDate=20&appType=codex",
  )
  assert_eq(
    client.usage_logs_url(
      query=Some(
        usage_logs_query([
          "moongate", "usage", "logs", "--page", "1", "--page-size", "50", "--app-type",
          "claude",
        ]),
      ),
    ),
    "http://127.0.0.1:15721/usage/logs?appType=claude&page=1&pageSize=50",
  )
  assert_eq(
    usage_limits_path([
      "moongate", "usage", "limits", "--provider-id", "p1", "--app-type", "codex",
    ]),
    "/usage/provider-limits?providerId=p1&appType=codex",
  )
  assert_eq(
    usage_provider_script_path(
      [
        "moongate", "usage", "provider-usage", "--provider-id", "p1", "--app-type",
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
        "moongate", "usage", "test-script", "--provider-id", "p1", "--app-type",
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
test "proxy config setter paths encode moongate command arguments" {
  assert_eq(
    provider_app_path(
      ["moongate", "provider", "list", "--app-type", "codex"],
      "/providers",
    ),
    "/providers?appType=codex",
  )
  assert_eq(
    provider_id_path(
      [
        "moongate", "provider", "switch", "--app-type", "codex", "--provider-id",
        "custom",
      ],
      "/providers/switch",
    ),
    Some("/providers/switch?appType=codex&id=custom"),
  )
  assert_eq(
    provider_id_path(
      [
        "moongate", "provider", "switch", "--app-type", "codex", "--id", "custom",
      ],
      "/providers/switch",
    ),
    None,
  )
  assert_eq(
    provider_upsert_path(
      [
        "moongate", "provider", "add", "--app-type", "codex", "--provider-id", "custom",
        "--name", "Custom Provider", "--base-url", "https://api.example.com/v1",
        "--api-key", "sk-test", "--provider-type", "custom", "--enabled", "true",
        "--add-to-live", "false",
      ],
      "/providers",
      require_original=false,
    ),
    Some(
      "/providers?appType=codex&id=custom&name=Custom%20Provider&baseUrl=https%3A%2F%2Fapi.example.com%2Fv1&apiKey=sk-test&providerType=custom&enabled=true&addToLive=false",
    ),
  )
  assert_eq(
    provider_upsert_path(
      ["moongate", "provider", "add", "--app-type", "codex", "--id", "custom"],
      "/providers",
      require_original=false,
    ),
    None,
  )
  assert_eq(
    provider_id_path(
      [
        "moongate", "provider", "endpoints", "list", "--app-type", "codex", "--provider-id",
        "custom",
      ],
      "/providers/endpoints/list",
    ),
    Some("/providers/endpoints/list?appType=codex&id=custom"),
  )
  assert_eq(
    provider_endpoint_url_path(
      [
        "moongate", "provider", "endpoints", "add", "--app-type", "codex", "--provider-id",
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
        "moongate", "provider", "endpoints", "touch", "--app-type", "codex", "--provider-id",
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
      "moongate", "provider", "test-endpoints", "--urls", "https://api.example.com/v1,not-a-url",
      "--timeout-secs", "3",
    ]),
    Some(
      "/providers/test-endpoints?urls=https%3A%2F%2Fapi.example.com%2Fv1%2Cnot-a-url&timeoutSecs=3",
    ),
  )
  assert_eq(
    provider_sort_order_path([
      "moongate", "provider", "sort-order", "set", "--app-type", "codex", "--provider-id",
      "custom", "--sort-index", "2",
    ]),
    Some("/providers/sort-order?appType=codex&id=custom&sortIndex=2"),
  )
  assert_eq(
    stream_check_provider_path([
      "moongate", "stream-check", "provider", "--app-type", "codex", "--id", "codex-oauth",
    ]),
    None,
  )
}

///|
test "proxy grouped commands build canonical paths" {
  assert_eq(
    provider_app_path(
      ["moongate", "proxy", "import-default-config", "--app-type", "codex"],
      "/proxy/import-default-config",
    ),
    "/proxy/import-default-config?appType=codex",
  )
  assert_eq(
    openclaw_default_model_path([
      "moongate", "openclaw", "default-model", "set", "--primary", "gpt-5", "--fallbacks",
      "sonnet,opus",
    ]),
    Some("/openclaw/default-model?primary=gpt-5&fallbacks=sonnet%2Copus"),
  )
  assert_eq(
    hermes_memory_path([
      "moongate", "hermes", "memory", "set", "--kind", "memory", "--content", "hello world",
    ]),
    Some("/hermes/memory?kind=memory&content=hello%20world"),
  )
  assert_eq(
    hermes_memory_enabled_path([
      "moongate", "hermes", "memory-enabled", "set", "--kind", "user", "--enabled",
      "false",
    ]),
    Some("/hermes/memory-enabled?kind=user&enabled=false"),
  )
  assert_eq(
    delete_sessions_body([
      "moongate", "sessions", "delete-many", "--items", "[{\"providerId\":\"codex\",\"sessionId\":\"s1\",\"sourcePath\":\"/tmp/s1.jsonl\"}]",
    ]),
    Some(
      "[{\"providerId\":\"codex\",\"sessionId\":\"s1\",\"sourcePath\":\"/tmp/s1.jsonl\"}]",
    ),
  )
  assert_eq(
    delete_sessions_body([
      "moongate", "sessions", "delete-many", "--body", "{\"items\":[]}",
    ]),
    None,
  )
  assert_eq(
    import_skills_from_apps_body([
      "moongate", "skills", "import-apps", "--imports", "[{\"directory\":\"moongate-usage\",\"apps\":{\"codex\":true}}]",
    ]),
    Some("[{\"directory\":\"moongate-usage\",\"apps\":{\"codex\":true}}]"),
  )
  assert_eq(
    import_skills_from_apps_body([
      "moongate", "skills", "import-apps", "--body", "{\"imports\":[]}",
    ]),
    None,
  )
  assert_eq(
    migrate_skill_storage_path([
      "moongate", "skills", "migrate-storage", "--target", "unified",
    ]),
    Some("/skills/migrate-storage?target=unified"),
  )
  assert_eq(
    migrate_skill_storage_path([
      "moongate", "skills", "migrate-storage", "--target", "moongate",
    ]),
    Some("/skills/migrate-storage?target=moongate"),
  )
  assert_eq(
    migrate_skill_storage_path(["moongate", "skills", "migrate-storage"]),
    None,
  )
  assert_eq(
    delete_env_vars_body([
      "moongate", "config", "env-delete", "--conflicts", "[{\"key\":\"OPENAI_API_KEY\",\"sourcePath\":\"/tmp/.zshrc\"}]",
    ]),
    Some("[{\"key\":\"OPENAI_API_KEY\",\"sourcePath\":\"/tmp/.zshrc\"}]"),
  )
  assert_eq(
    delete_env_vars_body([
      "moongate", "config", "env-delete", "--body", "{\"conflicts\":[]}",
    ]),
    None,
  )
}

///|
test "provider grouped commands build canonical paths" {
  assert_eq(
    provider_app_path(
      ["moongate", "provider", "list", "--app-type", "codex"],
      "/providers",
    ),
    "/providers?appType=codex",
  )
  assert_eq(
    provider_id_path(
      [
        "moongate", "provider", "switch", "--app-type", "codex", "--provider-id",
        "custom provider",
      ],
      "/providers/switch",
    ),
    Some("/providers/switch?appType=codex&id=custom%20provider"),
  )
  assert_eq(
    provider_endpoint_url_path(
      [
        "moongate", "provider", "endpoints", "add", "--app-type", "codex", "--provider-id",
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
        "moongate", "provider", "openclaw", "live-get", "--provider-id", "open claw",
      ],
      "openclaw",
    ),
    Some("/providers/live-provider?appType=openclaw&providerId=open%20claw"),
  )
  assert_eq(
    provider_live_provider_path(
      [
        "moongate", "provider", "hermes", "live-get", "--provider-id", "hermes/a",
      ],
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
      ["moongate", "provider", "universal", "sync", "--provider-id", "u 1"],
      "/providers/universal/sync",
    ),
    Some("/providers/universal/sync?id=u%201"),
  )
  assert_eq(
    universal_provider_upsert_path([
      "moongate", "provider", "universal", "upsert", "--provider-id", "u 1", "--name",
      "Universal One", "--provider-type", "openai-compatible", "--apps", "claude,codex",
      "--base-url", "https://api.example.com/v1", "--api-key", "sk-test", "--codex-model",
      "gpt-5", "--reasoning-effort", "medium",
    ]),
    Some(
      "/providers/universal?id=u%201&name=Universal%20One&providerType=openai-compatible&baseUrl=https%3A%2F%2Fapi.example.com%2Fv1&apiKey=sk-test&apps=claude%2Ccodex&codexModel=gpt-5&reasoningEffort=medium",
    ),
  )
  assert_eq(
    provider_presets_path([
      "moongate", "provider", "presets", "list", "--app-type", "gemini", "--query",
      "unity2", "--sort-mode", "nameAsc",
    ]),
    "/providers/presets?appType=gemini&query=unity2&sortMode=nameAsc",
  )
}

///|
test "top level moongate config command names build config paths" {
  assert_eq(
    config_app_path(
      ["moongate", "config", "status", "--app-type", "codex"],
      "/config/status",
    ),
    "/config/status?appType=codex",
  )
  assert_eq(
    config_app_path(
      ["moongate", "config", "dir", "--app-type", "openclaw"],
      "/config/dir",
    ),
    "/config/dir?appType=openclaw",
  )
  assert_eq(
    pick_directory_path([
      "moongate", "files", "directory", "pick", "--default-path", "/tmp/claude projects",
    ]),
    "/files/directories/pick?defaultPath=%2Ftmp%2Fclaude%20projects",
  )
  assert_eq(
    config_snippet_path(
      [
        "moongate", "config", "snippet", "set", "--app-type", "codex", "--snippet",
        "model=\"gpt-5\"",
      ],
      "/config/snippets",
      app_required=true,
    ),
    Some("/config/snippets?snippet=model%3D%22gpt-5%22&appType=codex"),
  )
  assert_eq(
    config_snippet_path(
      ["moongate", "config", "claude-snippet", "set", "--snippet", "{}"],
      "/config/snippets/claude",
      app_required=false,
    ),
    Some("/config/snippets/claude?snippet=%7B%7D"),
  )
  assert_eq(
    extract_common_config_snippet_path([
      "moongate", "config", "snippet", "extract", "--app-type", "claude", "--settings-config",
      "{\"env\":{}}",
    ]),
    "/config/snippets/extract?appType=claude&settingsConfig=%7B%22env%22%3A%7B%7D%7D",
  )
  assert_eq(
    restore_env_backup_path([
      "moongate", "config", "env-restore", "--backup-path", "/tmp/env backup.json",
    ]),
    Some("/config/env/restore?backupPath=%2Ftmp%2Fenv%20backup.json"),
  )
  assert_eq(
    config_file_path(
      [
        "moongate", "config", "file", "export", "--file-path", "/tmp/moon stat.json",
      ],
      "/config/files/export",
    ),
    "/config/files/export?filePath=%2Ftmp%2Fmoon%20stat.json",
  )
  assert_eq(
    config_file_path(
      ["moongate", "config", "file", "import", "--file-path", "/tmp/in.json"],
      "/config/files/import",
    ),
    "/config/files/import?filePath=%2Ftmp%2Fin.json",
  )
  assert_eq(
    db_backup_filename_path(
      ["moongate", "backups", "db", "restore", "--filename", "moongate-1.db"],
      "/backups/db/restore",
    ),
    "/backups/db/restore?filename=moongate-1.db",
  )
  assert_eq(
    db_backup_rename_path([
      "moongate", "backups", "db", "rename", "--old-filename", "moongate-1.db", "--new-name",
      "renamed",
    ]),
    "/backups/db/rename?oldFilename=moongate-1.db&newName=renamed",
  )
  assert_eq(
    db_backup_filename_path(
      ["moongate", "backups", "db", "delete", "--filename", "renamed.db"],
      "/backups/db/delete",
    ),
    "/backups/db/delete?filename=renamed.db",
  )
  assert_eq(
    deeplink_url_path(
      [
        "moongate", "deeplink", "parse", "--url", "moongate://v1/import?resource=skill&repo=vectie/skills",
      ],
      "/deeplinks/parse",
    ),
    "/deeplinks/parse?url=moongate%3A%2F%2Fv1%2Fimport%3Fresource%3Dskill%26repo%3Dvectie%2Fskills",
  )
  assert_eq(
    deeplink_request_path(
      [
        "moongate", "deeplink", "merge", "--request", "{\"resource\":\"provider\"}",
      ],
      "/deeplinks/merge",
    ),
    "/deeplinks/merge",
  )
  assert_eq(
    deeplink_request_path(
      [
        "moongate", "deeplink", "import", "--request", "moongate://v1/import?resource=prompt&appType=codex&name=Daily&content=SGVsbG8",
      ],
      "/deeplinks/import",
    ),
    "/deeplinks/import?url=moongate%3A%2F%2Fv1%2Fimport%3Fresource%3Dprompt%26appType%3Dcodex%26name%3DDaily%26content%3DSGVsbG8",
  )
  assert_eq(
    sync_settings_path(
      [
        "moongate", "sync", "webdav", "settings", "--settings", "{\"baseUrl\":\"https://dav.example.com\"}",
        "--password-touched", "false",
      ],
      "/sync/webdav/settings",
    ),
    "/sync/webdav/settings?passwordTouched=false",
  )
  assert_eq(
    sync_settings_path(
      [
        "moongate", "sync", "s3", "test", "--settings", "{\"bucket\":\"moongate\"}",
        "--preserve-empty-password", "true",
      ],
      "/sync/s3/test",
    ),
    "/sync/s3/test?preserveEmptyPassword=true",
  )
}

///|
test "top level moongate settings command names build settings paths" {
  assert_eq(
    app_config_dir_override_path([
      "moongate", "settings", "app-config-dir", "set", "--path", "/tmp/cc switch",
    ]),
    Some("/settings/app-config-dir?path=%2Ftmp%2Fcc%20switch"),
  )
  assert_eq(
    app_config_dir_override_path([
      "moongate", "settings", "app-config-dir", "set", "--clear", "true",
    ]),
    Some("/settings/app-config-dir?path="),
  )
  assert_eq(
    set_auto_launch_path([
      "moongate", "settings", "auto-launch", "set", "--enabled", "true",
    ]),
    Some("/settings/auto-launch?enabled=true"),
  )
  assert_eq(
    moon_json_config_path(
      [
        "moongate", "settings", "rectifier", "set", "--request-thinking-signature",
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
        "moongate", "settings", "optimizer", "set", "--config", "{\"cacheTtl\":\"5m\"}",
      ],
      "/settings/optimizer",
      "--config",
    ),
    Some("/settings/optimizer?config=%7B%22cacheTtl%22%3A%225m%22%7D"),
  )
  assert_eq(
    moon_json_config_path(
      [
        "moongate", "settings", "copilot-optimizer", "set", "--warmup-model", "gpt-5-mini",
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
test "top level moongate plugin command names build plugin paths" {
  assert_eq(
    apply_claude_plugin_config_path([
      "moongate", "plugin", "claude", "apply", "--official", "true",
    ]),
    "/plugin/claude/config?official=true",
  )
  assert_eq(
    apply_claude_plugin_config_path(["moongate", "plugin", "claude", "apply"]),
    "/plugin/claude/config",
  )
}

///|
test "top level moongate workspace command names build workspace paths" {
  assert_eq(
    workspace_filename_path(
      ["moongate", "workspace", "read", "--filename", "AGENTS.md"],
      "/workspace/files",
    ),
    "/workspace/files?filename=AGENTS.md",
  )
  assert_eq(
    workspace_content_path(
      [
        "moongate", "workspace", "write", "--filename", "AGENTS.md", "--content",
        "hello moon",
      ],
      "/workspace/files",
    ),
    Some("/workspace/files?filename=AGENTS.md&content=hello%20moon"),
  )
  assert_eq(
    workspace_query_path(
      ["moongate", "workspace", "memory", "search", "--query", "daily plan"],
      "/workspace/memory/search",
    ),
    "/workspace/memory/search?query=daily%20plan",
  )
  assert_eq(
    workspace_subdir_path(
      ["moongate", "workspace", "open", "--subdir", "memory"],
      "/workspace/open",
    ),
    "/workspace/open?subdir=memory",
  )
}

///|
test "top level moongate mcp command names build mcp paths" {
  assert_eq(
    mcp_app_path(
      ["moongate", "mcp", "config", "--app-type", "codex"],
      "/mcp/config",
    ),
    "/mcp/config?appType=codex",
  )
  assert_eq(
    mcp_validate_command_path([
      "moongate", "mcp", "validate", "--command", "npx",
    ]),
    "/mcp/validate?command=npx",
  )
  assert_eq(
    mcp_id_path(
      ["moongate", "mcp", "delete", "--id", "filesystem server"],
      "/mcp/servers",
    ),
    Some("/mcp/servers?id=filesystem%20server"),
  )
  guard mcp_upsert_path(
      [
        "moongate", "mcp", "upsert-config", "--app-type", "codex", "--id", "filesystem",
        "--name", "Filesystem", "--command", "npx", "--sync-other-side", "true",
      ],
      "/mcp/config/servers",
    )
    is Some(upsert_path) else {
    fail("expected upsert path")
  }
  assert_eq(upsert_path, "/mcp/config/servers?appType=codex&syncOtherSide=true")
  guard mcp_upsert_body([
      "moongate", "mcp", "upsert-config", "--app-type", "codex", "--id", "filesystem",
      "--name", "Filesystem", "--command", "npx", "--sync-other-side", "true",
    ])
    is Some(upsert_body) else {
    fail("expected upsert body")
  }
  assert_true(upsert_body.contains("Filesystem"))
  assert_true(upsert_body.contains("npx"))
  assert_eq(
    mcp_enabled_path(
      [
        "moongate", "mcp", "toggle", "--id", "filesystem", "--app-type", "codex",
        "--enabled", "false",
      ],
      "/mcp/apps/toggle",
    ),
    Some("/mcp/apps/toggle?id=filesystem&appType=codex&enabled=false"),
  )
}

///|
test "top level moongate prompt command names build prompt paths" {
  assert_eq(
    prompt_app_path(
      ["moongate", "prompt", "list", "--app-type", "codex"],
      "/prompts",
    ),
    "/prompts?appType=codex",
  )
  assert_eq(
    prompt_upsert_path([
      "moongate", "prompt", "upsert", "--app-type", "codex", "--id", "review", "--name",
      "Review", "--content", "Check this", "--description", "Code review", "--enabled",
      "true",
    ]),
    Some("/prompts?appType=codex"),
  )
  guard prompt_upsert_body([
      "moongate", "prompt", "upsert", "--app-type", "codex", "--id", "review", "--name",
      "Review", "--content", "Check this", "--description", "Code review", "--enabled",
      "true",
    ])
    is Some(prompt_body) else {
    fail("expected prompt body")
  }
  assert_true(prompt_body.contains("review"))
  assert_true(prompt_body.contains("Check this"))
  assert_true(prompt_body.contains("Code review"))
  assert_true(prompt_body.contains("true"))
  assert_eq(
    prompt_id_path(
      ["moongate", "prompt", "delete", "--app-type", "codex", "--id", "review"],
      "/prompts",
    ),
    Some("/prompts?appType=codex&id=review"),
  )
  assert_eq(
    prompt_file_path(
      [
        "moongate", "prompt", "import", "--app-type", "codex", "--path", "/tmp/prompts.md",
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
      "moongate", "usage", "balance", "--base-url", "https://api.deepseek.com", "--api-key",
      "sk test",
    ]),
    Some(
      "/usage/balance?baseUrl=https%3A%2F%2Fapi.deepseek.com&apiKey=sk%20test",
    ),
  )
  assert_true(
    balance_path([
      "moongate", "usage", "balance", "--base-url", "https://api.deepseek.com",
    ])
    is None,
  )
}

///|
test "usage subscription quota command builds quota path" {
  assert_eq(
    subscription_quota_path(["moongate", "usage", "quota", "--tool", "gemini"]),
    Some("/usage/subscription-quota?tool=gemini"),
  )
  assert_true(subscription_quota_path(["moongate", "usage", "quota"]) is None)
}

///|
test "usage codex oauth quota command builds quota path" {
  assert_eq(
    codex_oauth_quota_path([
      "moongate", "usage", "codex-oauth-quota", "--account-id", "acct 1",
    ]),
    "/usage/codex-oauth-quota?accountId=acct%201",
  )
  assert_eq(
    codex_oauth_quota_path(["moongate", "usage", "codex-oauth-quota"]),
    "/usage/codex-oauth-quota",
  )
}

///|
test "usage codex oauth models command builds models path" {
  assert_eq(
    codex_oauth_models_path([
      "moongate", "usage", "codex-oauth-models", "--account-id", "acct 1",
    ]),
    "/usage/codex-oauth-models?accountId=acct%201",
  )
  assert_eq(
    codex_oauth_models_path(["moongate", "usage", "codex-oauth-models"]),
    "/usage/codex-oauth-models",
  )
}

///|
test "moongate auth commands build managed auth paths" {
  assert_eq(
    auth_provider_path(
      ["moongate", "auth", "status", "--auth-provider", "codex_oauth"],
      "/auth/status",
    ),
    "/auth/status?authProvider=codex_oauth",
  )
  assert_eq(
    auth_provider_path(["moongate", "auth", "status"], "/auth/status"),
    "/auth/status",
  )
  assert_eq(
    auth_account_path(
      [
        "moongate", "auth", "remove", "--account-id", "acct 1", "--auth-provider",
        "codex_oauth",
      ],
      "/auth/account",
    ),
    Some("/auth/account?accountId=acct%201&authProvider=codex_oauth"),
  )
  assert_true(
    auth_account_path(["moongate", "auth", "remove"], "/auth/account") is None,
  )
  assert_eq(
    auth_poll_path([
      "moongate", "auth", "poll", "--device-code", "dev 1", "--user-code", "USER-CODE",
    ]),
    Some("/auth/poll?deviceCode=dev%201&userCode=USER-CODE"),
  )
}

///|
test "usage coding plan command builds quota path" {
  assert_eq(
    coding_plan_quota_path([
      "moongate", "usage", "coding-plan", "--base-url", "https://api.minimax.io",
      "--api-key", "key",
    ]),
    Some(
      "/usage/coding-plan-quota?baseUrl=https%3A%2F%2Fapi.minimax.io&apiKey=key",
    ),
  )
  assert_true(
    coding_plan_quota_path(["moongate", "usage", "coding-plan"]) is None,
  )
}

///|
test "top level moongate app shell commands build paths" {
  assert_eq(
    open_external_path([
      "moongate", "runtime", "open-external", "--url", "github.com/a b",
    ]),
    "/runtime/open-external?url=github.com%2Fa%20b",
  )
  assert_eq(
    copy_text_to_clipboard_path([
      "moongate", "runtime", "copy-text", "--text", "hello world",
    ]),
    "/runtime/clipboard/text?text=hello%20world",
  )
  assert_eq(
    tool_versions_path([
      "moongate", "tools", "versions", "--tools", "codex,claude",
    ]),
    "/tools/versions?tools=codex%2Cclaude",
  )
  assert_eq(
    window_theme_path([
      "moongate", "runtime", "window-theme", "set", "--theme", "dark",
    ]),
    "/runtime/window-theme?theme=dark",
  )
  assert_eq(
    save_file_dialog_path([
      "moongate", "files", "save-dialog", "--default-name", "config.json",
    ]),
    "/files/dialogs/save?defaultName=config.json",
  )
}

///|
test "top level moongate skill commands build paths" {
  assert_eq(
    skill_install_path(
      [
        "moongate", "skills", "install-unified", "--directory", "moongate usage",
        "--name", "MoonGate Usage", "--description", "Routes and usage", "--current-app",
        "codex",
      ],
      "/skills/install-unified",
    ),
    "/skills/install-unified?directory=moongate%20usage&name=MoonGate%20Usage&description=Routes%20and%20usage&currentApp=codex",
  )
  assert_eq(
    skill_toggle_app_path([
      "moongate", "skills", "toggle-app", "--id", "moongate-usage", "--app-type",
      "hermes", "--enabled", "true",
    ]),
    "/skills/toggle-app?id=moongate-usage&appType=hermes&enabled=true",
  )
  assert_eq(
    skill_restore_backup_path([
      "moongate", "skills", "backup", "restore", "--backup-id", "moongate-usage-1",
      "--current-app", "claude",
    ]),
    "/skills/backups/restore?backupId=moongate-usage-1&currentApp=claude",
  )
  assert_eq(
    skill_search_path([
      "moongate", "skills", "search", "--query", "proxy skill", "--limit", "5", "--offset",
      "10",
    ]),
    "/skills/search?query=proxy%20skill&limit=5&offset=10",
  )
  assert_eq(
    skill_repo_add_path([
      "moongate", "skills", "repo", "add", "--owner", "vectie", "--name", "moongate-skills",
      "--branch", "main", "--enabled", "true",
    ]),
    "/skills/repos?owner=vectie&name=moongate-skills&branch=main&enabled=true",
  )
  assert_eq(
    skill_zip_install_path([
      "moongate", "skills", "install-zip", "--file-path", "/tmp/skill bundle", "--current-app",
      "codex",
    ]),
    "/skills/install-zip?filePath=%2Ftmp%2Fskill%20bundle&currentApp=codex",
  )
}
