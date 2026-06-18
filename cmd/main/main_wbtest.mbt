///|
test "has flag matches exact CLI option" {
  let args = ["moonstat", "models", "fetch", "--full-url"]
  assert_true(has_flag(args, "--full-url"))
  assert_false(has_flag(args, "--is-full-url"))
}

///|
test "registered cli commands match suite command aliases" {
  assert_true(registered_cli_commands().length() == 5)
  assert_true(
    cli_args_match_pattern(
      ["moonstat", "suite", "manifest", "--host", "127.0.0.1"],
      "suite manifest",
    ),
  )
  assert_false(cli_args_match_pattern(["moonstat", "suite"], "suite status"))
  assert_true(
    registered_cli_command_id(["moonstat", "suite", "provider-manifest"]) ==
    Some("suite_moonclaw_providers"),
  )
  assert_true(
    registered_cli_command_id([
      "moonstat", "suite", "write-provider-manifest", "--path", "/tmp/providers.json",
    ]) ==
    Some("suite_write_moonclaw_providers"),
  )
  assert_true(
    registered_cli_command_id(["moonstat", "usage", "summary"]) == None,
  )
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
    "/usage/sync-session?projects_dir=%2Ftmp%2Fclaude%20projects&codex_dir=%2Ftmp%2Fcodex&gemini_dir=%2Ftmp%2Fgemini&opencode_export_path=%2Ftmp%2Fopencode%2Fmessages.jsonl&opencode_db_path=%2Ftmp%2Fopencode%2Fopencode.db%3Fmode%3Dro",
  )
}

///|
test "usage pricing paths accept ccs editable pricing args" {
  assert_eq(
    usage_pricing_update_path([
      "moonstat", "usage", "pricing", "set", "--model-id", "anthropic/claude&sonnet",
      "--display-name", "Custom Model", "--input-cost", "1", "--output-cost", "2",
      "--cache-read-cost", "0.1", "--cache-creation-cost", "0",
    ]),
    Some(
      "/usage/model-pricing?model_id=anthropic%2Fclaude%26sonnet&display_name=Custom%20Model&input_cost=1&output_cost=2&cache_read_cost=0.1&cache_creation_cost=0",
    ),
  )
  assert_eq(
    usage_pricing_delete_path([
      "moonstat", "usage", "pricing", "delete", "--model-id", "anthropic/claude&sonnet",
    ]),
    Some("/usage/model-pricing?model_id=anthropic%2Fclaude%26sonnet"),
  )
  assert_eq(
    usage_pricing_update_path([
      "moonstat", "usage", "pricing", "set", "--model-id", "custom",
    ]),
    None,
  )
}

///|
test "usage filter paths encode ccs query values" {
  assert_eq(
    usage_trends_path([
      "moonstat", "usage", "trends", "--start-date", "10", "--end-date", "20", "--app-type",
      "claude desktop",
    ]),
    "/usage/trends?start_date=10&end_date=20&app_type=claude%20desktop",
  )
  assert_eq(
    usage_limits_path([
      "moonstat", "usage", "limits", "--provider-id", "Codex OAuth", "--app-type",
      "codex", "--daily-limit-usd", "1.5", "--monthly-limit-usd", "30",
    ]),
    "/usage/provider-limits?provider_id=Codex%20OAuth&app_type=codex&daily_limit_usd=1.5&monthly_limit_usd=30",
  )
}

///|
test "stream check paths use ccs command names and camelCase args" {
  assert_eq(
    stream_check_provider_path([
      "moonstat", "stream-check", "provider", "--app-type", "codex", "--provider-id",
      "codex oauth",
    ]),
    Some("/stream_check_provider?appType=codex&providerId=codex%20oauth"),
  )
  assert_eq(
    stream_check_all_path([
      "moonstat", "stream-check", "all", "--appType", "claude", "--proxyTargetsOnly",
      "true",
    ]),
    "/stream_check_all_providers?appType=claude&proxyTargetsOnly=true",
  )
  assert_eq(
    stream_check_config_update_path([
      "moonstat", "stream-check", "config", "set", "--codex-model", "gpt/5", "--timeout-secs",
      "45", "--test-prompt", "Who are you?",
    ]),
    "/save_stream_check_config?timeoutSecs=45&codexModel=gpt%2F5&testPrompt=Who%20are%20you%3F",
  )
}

///|
test "usage aggregate paths accept ccs date and app filters" {
  let args = [
    "moonstat", "usage", "summary", "--startDate", "10", "--endDate", "20", "--appType",
    "claude desktop",
  ]
  assert_eq(
    usage_filtered_path(args, "/usage/summary", app_filter=true),
    "/usage/summary?start_date=10&end_date=20&app_type=claude%20desktop",
  )
  assert_eq(
    usage_filtered_path(args, "/usage/summary/by-app", app_filter=false),
    "/usage/summary/by-app?start_date=10&end_date=20",
  )
  assert_eq(
    usage_filtered_path(args, "/usage/provider-stats", app_filter=true),
    "/usage/provider-stats?start_date=10&end_date=20&app_type=claude%20desktop",
  )
  assert_eq(
    usage_filtered_path(args, "/usage/model-stats", app_filter=true),
    "/usage/model-stats?start_date=10&end_date=20&app_type=claude%20desktop",
  )
}

///|
test "usage logs path accepts ccs filters and pagination" {
  assert_eq(
    usage_logs_path([
      "moonstat", "usage", "logs", "--page", "2", "--page-size", "25", "--app-type",
      "codex", "--provider-name", "Codex OAuth", "--model", "anthropic/claude-sonnet",
      "--status-code", "200", "--start-date", "10", "--end-date", "20",
    ]),
    "/usage/logs?start_date=10&end_date=20&app_type=codex&page=2&pageSize=25&providerName=Codex%20OAuth&model=anthropic%2Fclaude-sonnet&statusCode=200",
  )
}

///|
test "usage detail path encodes ccs request ids" {
  assert_eq(
    "/usage/request-detail/\{cli_url_encode("session:msg/1")}",
    "/usage/request-detail/session%3Amsg%2F1",
  )
}

///|
test "usage aliases build same paths as ccs command names" {
  let args = [
    "moonstat", "usage", "get-usage-summary", "--startDate", "10", "--endDate", "20",
    "--appType", "codex",
  ]
  assert_eq(
    usage_filtered_path(args, "/usage/summary", app_filter=true),
    "/usage/summary?start_date=10&end_date=20&app_type=codex",
  )
  assert_eq(
    usage_logs_path([
      "moonstat", "usage", "get-request-logs", "--page", "1", "--pageSize", "50",
      "--appType", "claude",
    ]),
    "/usage/logs?app_type=claude&page=1&pageSize=50",
  )
  assert_eq(
    usage_limits_path([
      "moonstat", "usage", "check-provider-limits", "--provider-id", "p1", "--app-type",
      "codex",
    ]),
    "/usage/provider-limits?provider_id=p1&app_type=codex",
  )
  assert_eq(
    usage_provider_script_path(
      [
        "moonstat", "usage", "query-provider-usage", "--provider-id", "p1", "--app",
        "codex",
      ],
      "/queryProviderUsage",
      false,
    ),
    Some("/queryProviderUsage?providerId=p1&app=codex"),
  )
  assert_eq(
    usage_provider_script_path(
      [
        "moonstat", "usage", "test-usage-script", "--provider-id", "p1", "--app",
        "codex", "--script-code", "{\"success\":true}",
      ],
      "/testUsageScript",
      true,
    ),
    Some(
      "/testUsageScript?providerId=p1&app=codex&scriptCode=%7B%22success%22%3Atrue%7D",
    ),
  )
}

///|
test "proxy config setter paths encode ccs command arguments" {
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
      "moonstat", "proxy", "app-config", "set", "--app", "codex", "--enabled", "true",
      "--auto-failover-enabled", "false", "--max-retries", "5", "--streaming-first-byte-timeout",
      "11", "--streaming-idle-timeout", "22", "--non-streaming-timeout", "33", "--failure-threshold",
      "7", "--success-threshold", "3", "--timeout-seconds", "44", "--error-rate-threshold",
      "0.4", "--min-requests", "12",
    ]),
    "/proxy/app-config?appType=codex&enabled=true&autoFailoverEnabled=false&maxRetries=5&streamingFirstByteTimeout=11&streamingIdleTimeout=22&nonStreamingTimeout=33&failureThreshold=7&successThreshold=3&timeoutSeconds=44&errorRateThreshold=0.4&minRequests=12",
  )
  assert_eq(
    proxy_takeover_update_path([
      "moonstat", "proxy", "takeover-status", "set", "--app", "codex", "--enabled",
      "true",
    ]),
    Some("/proxy/takeover-status?app_type=codex&enabled=true"),
  )
  assert_eq(
    proxy_app_value_update_path(
      [
        "moonstat", "proxy", "default-cost-multiplier", "set", "--app", "codex",
        "--value", "1.25",
      ],
      "/proxy/default-cost-multiplier",
    ),
    Some("/proxy/default-cost-multiplier?app_type=codex&value=1.25"),
  )
  assert_eq(
    proxy_provider_endpoint_path(
      [
        "moonstat", "proxy", "switch-proxy-provider", "--app", "codex", "--provider-id",
        "codex-oauth",
      ],
      "/switch_proxy_provider",
    ),
    Some("/switch_proxy_provider?provider_id=codex-oauth&app_type=codex"),
  )
  assert_eq(
    provider_app_path(
      ["moonstat", "provider", "list", "--app", "codex"],
      "/get_providers",
    ),
    "/get_providers?app=codex",
  )
  assert_eq(
    provider_id_path(
      ["moonstat", "provider", "switch", "--app", "codex", "--id", "custom"],
      "/switch_provider",
    ),
    Some("/switch_provider?app=codex&id=custom"),
  )
  assert_eq(
    provider_upsert_path(
      [
        "moonstat", "provider", "add", "--app", "codex", "--id", "custom", "--name",
        "Custom Provider", "--base-url", "https://api.example.com/v1", "--api-key",
        "sk-test", "--category", "custom", "--enabled", "true", "--add-to-live",
        "false",
      ],
      "/add_provider",
      require_original=false,
    ),
    Some(
      "/add_provider?app=codex&id=custom&name=Custom%20Provider&baseUrl=https%3A%2F%2Fapi.example.com%2Fv1&apiKey=sk-test&category=custom&enabled=true&addToLive=false",
    ),
  )
  assert_eq(
    provider_id_path(
      [
        "moonstat", "provider", "endpoints", "list", "--app", "codex", "--id", "custom",
      ],
      "/get_custom_endpoints",
    ),
    Some("/get_custom_endpoints?app=codex&id=custom"),
  )
  assert_eq(
    provider_endpoint_url_path(
      [
        "moonstat", "provider", "endpoints", "add", "--app", "codex", "--id", "custom",
        "--endpoint-url", "https://backup.example.com/v1",
      ],
      "/add_custom_endpoint",
    ),
    Some(
      "/add_custom_endpoint?app=codex&providerId=custom&url=https%3A%2F%2Fbackup.example.com%2Fv1",
    ),
  )
  assert_eq(
    provider_endpoint_url_path(
      [
        "moonstat", "provider", "endpoints", "touch", "--app", "codex", "--id", "custom",
        "--endpoint-url", "https://backup.example.com/v1",
      ],
      "/update_endpoint_last_used",
    ),
    Some(
      "/update_endpoint_last_used?app=codex&providerId=custom&url=https%3A%2F%2Fbackup.example.com%2Fv1",
    ),
  )
  assert_eq(
    provider_test_endpoints_path([
      "moonstat", "provider", "test-endpoints", "--urls", "https://api.example.com/v1,not-a-url",
      "--timeoutSecs", "3",
    ]),
    Some(
      "/test_api_endpoints?urls=https%3A%2F%2Fapi.example.com%2Fv1%2Cnot-a-url&timeoutSecs=3",
    ),
  )
  assert_eq(
    provider_sort_order_path([
      "moonstat", "provider", "sort-order", "set", "--app", "codex", "--id", "custom",
      "--sort-index", "2",
    ]),
    Some("/update_providers_sort_order?app=codex&id=custom&sortIndex=2"),
  )
}

///|
test "top level ccs proxy command names build command alias paths" {
  assert_eq(
    proxy_global_config_update_path(
      [
        "moonstat", "update_global_proxy_config", "--proxyEnabled", "true", "--listenAddress",
        "127.0.0.1", "--listenPort", "15721",
      ],
      "/proxy/global-config",
    ),
    "/proxy/global-config?proxyEnabled=true&listenAddress=127.0.0.1&listenPort=15721",
  )
  assert_eq(
    proxy_app_config_update_path([
      "moonstat", "update_proxy_config_for_app", "--appType", "codex", "--enabled",
      "true", "--autoFailoverEnabled", "true",
    ]),
    "/proxy/app-config?appType=codex&enabled=true&autoFailoverEnabled=true",
  )
  assert_eq(
    proxy_provider_endpoint_path(
      [
        "moonstat", "switch_proxy_provider", "--app-type", "codex", "--provider-id",
        "codex oauth",
      ],
      "/switch_proxy_provider",
    ),
    Some("/switch_proxy_provider?provider_id=codex%20oauth&app_type=codex"),
  )
  assert_eq(
    proxy_auto_failover_enabled_path([
      "moonstat", "set_auto_failover_enabled", "--appType", "codex", "--enabled",
      "true",
    ]),
    Some("/proxy/auto-failover-enabled?app_type=codex&enabled=true"),
  )
  assert_eq(
    global_proxy_url_path(
      ["moonstat", "set_global_proxy_url", "--url", "http://127.0.0.1:7890"],
      "/set_global_proxy_url",
    ),
    Some("/set_global_proxy_url?url=http%3A%2F%2F127.0.0.1%3A7890"),
  )
  assert_eq(
    global_proxy_url_path(
      ["moonstat", "test_proxy_url", "--url", "socks5://127.0.0.1:1080"],
      "/test_proxy_url",
    ),
    Some("/test_proxy_url?url=socks5%3A%2F%2F127.0.0.1%3A1080"),
  )
  assert_eq(
    provider_app_path(
      ["moonstat", "import_default_config_test_hook", "--app", "codex"],
      "/import_default_config_test_hook",
    ),
    "/import_default_config_test_hook?app=codex",
  )
  assert_eq(
    openclaw_default_model_path([
      "moonstat", "set_openclaw_default_model", "--primary", "gpt-5", "--fallbacks",
      "sonnet,opus",
    ]),
    Some("/set_openclaw_default_model?primary=gpt-5&fallbacks=sonnet%2Copus"),
  )
  assert_eq(
    suite_json_config_path(
      [
        "moonstat", "set_openclaw_model_catalog", "--catalog", "{\"fast\":{\"alias\":\"f\"}}",
      ],
      "/set_openclaw_model_catalog",
      "--catalog",
    ),
    Some(
      "/set_openclaw_model_catalog?catalog=%7B%22fast%22%3A%7B%22alias%22%3A%22f%22%7D%7D",
    ),
  )
  assert_eq(
    hermes_memory_path([
      "moonstat", "set_hermes_memory", "--kind", "memory", "--content", "hello world",
    ]),
    Some("/set_hermes_memory?kind=memory&content=hello%20world"),
  )
  assert_eq(
    hermes_memory_enabled_path([
      "moonstat", "set_hermes_memory_enabled", "--kind", "user", "--enabled", "false",
    ]),
    Some("/set_hermes_memory_enabled?kind=user&enabled=false"),
  )
  assert_eq(
    delete_sessions_body([
      "moonstat", "delete_sessions", "--items", "[{\"providerId\":\"codex\",\"sessionId\":\"s1\",\"sourcePath\":\"/tmp/s1.jsonl\"}]",
    ]),
    Some(
      "[{\"providerId\":\"codex\",\"sessionId\":\"s1\",\"sourcePath\":\"/tmp/s1.jsonl\"}]",
    ),
  )
  assert_eq(
    delete_sessions_body([
      "moonstat", "delete_sessions", "--body", "{\"items\":[]}",
    ]),
    Some("{\"items\":[]}"),
  )
  assert_eq(
    import_skills_from_apps_body([
      "moonstat", "import_skills_from_apps", "--imports", "[{\"directory\":\"traffic-stats\",\"apps\":{\"codex\":true}}]",
    ]),
    Some("[{\"directory\":\"traffic-stats\",\"apps\":{\"codex\":true}}]"),
  )
  assert_eq(
    import_skills_from_apps_body([
      "moonstat", "import_skills_from_apps", "--body", "{\"imports\":[]}",
    ]),
    Some("{\"imports\":[]}"),
  )
  assert_eq(
    migrate_skill_storage_path([
      "moonstat", "migrate_skill_storage", "--target", "unified",
    ]),
    Some("/migrate_skill_storage?target=unified"),
  )
  assert_eq(
    migrate_skill_storage_path([
      "moonstat", "migrate_skill_storage", "--target", "cc switch",
    ]),
    Some("/migrate_skill_storage?target=cc%20switch"),
  )
  assert_eq(
    migrate_skill_storage_path(["moonstat", "migrate_skill_storage"]),
    None,
  )
  assert_eq(
    delete_env_vars_body([
      "moonstat", "delete_env_vars", "--conflicts", "[{\"key\":\"OPENAI_API_KEY\",\"sourcePath\":\"/tmp/.zshrc\"}]",
    ]),
    Some("[{\"key\":\"OPENAI_API_KEY\",\"sourcePath\":\"/tmp/.zshrc\"}]"),
  )
  assert_eq(
    delete_env_vars_body([
      "moonstat", "delete_env_vars", "--body", "{\"conflicts\":[]}",
    ]),
    Some("{\"conflicts\":[]}"),
  )
}

///|
test "top level ccs provider command names build command alias paths" {
  assert_eq(
    provider_app_path(
      ["moonstat", "get_providers", "--appType", "codex"],
      "/get_providers",
    ),
    "/get_providers?app=codex",
  )
  assert_eq(
    provider_id_path(
      [
        "moonstat", "switch_provider", "--appType", "codex", "--providerId", "custom provider",
      ],
      "/switch_provider",
    ),
    Some("/switch_provider?app=codex&id=custom%20provider"),
  )
  assert_eq(
    provider_endpoint_url_path(
      [
        "moonstat", "add_custom_endpoint", "--appType", "codex", "--providerId",
        "custom", "--endpointUrl", "https://backup.example.com/v1",
      ],
      "/add_custom_endpoint",
    ),
    Some(
      "/add_custom_endpoint?app=codex&providerId=custom&url=https%3A%2F%2Fbackup.example.com%2Fv1",
    ),
  )
  assert_eq(
    provider_live_ids_path("opencode"),
    "/get_opencode_live_provider_ids",
  )
  assert_eq(
    provider_live_provider_path(
      ["moonstat", "get_openclaw_live_provider", "--providerId", "open claw"],
      "openclaw",
    ),
    Some("/get_openclaw_live_provider?providerId=open%20claw"),
  )
  assert_eq(
    provider_live_provider_path(
      ["moonstat", "get_hermes_live_provider", "--id", "hermes/a"],
      "hermes",
    ),
    Some("/get_hermes_live_provider?providerId=hermes%2Fa"),
  )
  assert_eq(
    provider_import_live_path("openclaw"),
    "/import_openclaw_providers_from_live",
  )
  assert_eq(
    universal_provider_id_path(
      ["moonstat", "sync_universal_provider", "--id", "u 1"],
      "/sync_universal_provider",
    ),
    Some("/sync_universal_provider?id=u%201"),
  )
  assert_eq(
    universal_provider_upsert_path([
      "moonstat", "provider", "universal", "upsert", "--id", "u 1", "--name", "Universal One",
      "--provider-type", "openai-compatible", "--apps", "claude,codex", "--base-url",
      "https://api.example.com/v1", "--api-key", "sk-test", "--codex-model", "gpt-5",
      "--reasoning-effort", "medium",
    ]),
    Some(
      "/upsert_universal_provider?id=u%201&name=Universal%20One&providerType=openai-compatible&baseUrl=https%3A%2F%2Fapi.example.com%2Fv1&apiKey=sk-test&apps=claude%2Ccodex&codexModel=gpt-5&reasoningEffort=medium",
    ),
  )
  assert_eq(
    provider_presets_path([
      "moonstat", "provider", "presets", "list", "--app", "gemini", "--query", "unity2",
      "--sort-mode", "nameAsc",
    ]),
    "/get_provider_presets?appType=gemini&query=unity2&sortMode=nameAsc",
  )
}

///|
test "top level ccs usage command names build command alias paths" {
  assert_eq(
    usage_filtered_path(
      [
        "moonstat", "get_usage_summary", "--startDate", "10", "--endDate", "20",
        "--appType", "codex",
      ],
      "/usage/summary",
      app_filter=true,
    ),
    "/usage/summary?start_date=10&end_date=20&app_type=codex",
  )
  assert_eq(
    usage_logs_path([
      "moonstat", "get_request_logs", "--appType", "claude", "--pageSize", "25",
      "--providerName", "Provider A", "--statusCode", "200",
    ]),
    "/usage/logs?app_type=claude&pageSize=25&providerName=Provider%20A&statusCode=200",
  )
  assert_eq(
    usage_limits_path([
      "moonstat", "check_provider_limits", "--providerId", "p1", "--appType", "codex",
    ]),
    "/usage/provider-limits?provider_id=p1&app_type=codex",
  )
  assert_eq(
    usage_provider_script_path(
      [
        "moonstat", "queryProviderUsage", "--providerId", "p1", "--appType", "codex",
      ],
      "/queryProviderUsage",
      false,
    ),
    Some("/queryProviderUsage?providerId=p1&app=codex"),
  )
  assert_eq(
    usage_pricing_update_path([
      "moonstat", "update_model_pricing", "--modelId", "gpt/5", "--displayName",
      "GPT 5", "--inputCost", "1", "--outputCost", "2", "--cacheReadCost", "0.1",
      "--cacheCreationCost", "0.2",
    ]),
    Some(
      "/usage/model-pricing?model_id=gpt%2F5&display_name=GPT%205&input_cost=1&output_cost=2&cache_read_cost=0.1&cache_creation_cost=0.2",
    ),
  )
  assert_eq(
    usage_pricing_delete_path([
      "moonstat", "delete_model_pricing", "--modelId", "gpt/5",
    ]),
    Some("/usage/model-pricing?model_id=gpt%2F5"),
  )
  assert_eq(
    "/usage/request-detail/\{cli_url_encode("req/1")}",
    "/usage/request-detail/req%2F1",
  )
}

///|
test "top level ccs stream check command names build command alias paths" {
  assert_eq(
    stream_check_provider_path([
      "moonstat", "stream_check_provider", "--appType", "codex", "--providerId",
      "codex oauth",
    ]),
    Some("/stream_check_provider?appType=codex&providerId=codex%20oauth"),
  )
  assert_eq(
    stream_check_all_path([
      "moonstat", "stream_check_all_providers", "--appType", "codex", "--proxyTargetsOnly",
      "true",
    ]),
    "/stream_check_all_providers?appType=codex&proxyTargetsOnly=true",
  )
  assert_eq(
    stream_check_config_update_path([
      "moonstat", "save_stream_check_config", "--timeoutSecs", "60", "--geminiModel",
      "gemini-test",
    ]),
    "/save_stream_check_config?timeoutSecs=60&geminiModel=gemini-test",
  )
}

///|
test "top level ccs copilot command names build auth paths" {
  assert_eq(
    copilot_github_domain_path(
      [
        "moonstat", "copilot_start_device_flow", "--githubDomain", "https://ghe.example.com",
      ],
      "/copilot_start_device_flow",
    ),
    "/copilot_start_device_flow?githubDomain=https%3A%2F%2Fghe.example.com",
  )
  assert_eq(
    copilot_device_path(
      [
        "moonstat", "copilot_poll_for_account", "--deviceCode", "dev 1", "--github-domain",
        "ghe.example.com",
      ],
      "/copilot_poll_for_account",
    ),
    Some(
      "/copilot_poll_for_account?deviceCode=dev%201&githubDomain=ghe.example.com",
    ),
  )
  assert_eq(
    copilot_account_path(
      [
        "moonstat", "copilot_remove_account", "--accountId", "ghe.example.com:42",
      ],
      "/copilot_remove_account",
    ),
    Some("/copilot_remove_account?accountId=ghe.example.com%3A42"),
  )
  assert_eq(
    copilot_account_optional_path(
      [
        "moonstat", "copilot_get_models_for_account", "--account-id", "ghe.example.com:42",
      ],
      "/copilot_get_models_for_account",
    ),
    "/copilot_get_models_for_account?accountId=ghe.example.com%3A42",
  )
  assert_eq(
    auth_provider_path(
      ["moonstat", "auth_get_status", "--authProvider", "github_copilot"],
      "/auth_get_status",
    ),
    "/auth_get_status?authProvider=github_copilot",
  )
}

///|
test "top level ccs config command names build config paths" {
  assert_eq(
    config_app_path(
      ["moonstat", "get_config_status", "--appType", "codex"],
      "/get_config_status",
    ),
    "/get_config_status?app=codex",
  )
  assert_eq(
    config_app_path(
      ["moonstat", "get_config_dir", "--app-type", "openclaw"],
      "/get_config_dir",
    ),
    "/get_config_dir?app=openclaw",
  )
  assert_eq(
    pick_directory_path([
      "moonstat", "pick_directory", "--defaultPath", "/tmp/claude projects",
    ]),
    "/pick_directory?defaultPath=%2Ftmp%2Fclaude%20projects",
  )
  assert_eq(
    config_snippet_path(
      [
        "moonstat", "set_common_config_snippet", "--appType", "codex", "--snippet",
        "model=\"gpt-5\"",
      ],
      "/set_common_config_snippet",
      app_required=true,
    ),
    Some("/set_common_config_snippet?snippet=model%3D%22gpt-5%22&appType=codex"),
  )
  assert_eq(
    config_snippet_path(
      ["moonstat", "set_claude_common_config_snippet", "--snippet", "{}"],
      "/set_claude_common_config_snippet",
      app_required=false,
    ),
    Some("/set_claude_common_config_snippet?snippet=%7B%7D"),
  )
  assert_eq(
    extract_common_config_snippet_path([
      "moonstat", "extract_common_config_snippet", "--appType", "claude", "--settingsConfig",
      "{\"env\":{}}",
    ]),
    "/extract_common_config_snippet?appType=claude&settingsConfig=%7B%22env%22%3A%7B%7D%7D",
  )
  assert_eq(
    restore_env_backup_path([
      "moonstat", "restore_env_backup", "--backupPath", "/tmp/env backup.json",
    ]),
    Some("/restore_env_backup?backupPath=%2Ftmp%2Fenv%20backup.json"),
  )
  assert_eq(
    config_file_path(
      ["moonstat", "export_config_to_file", "--filePath", "/tmp/moon stat.json"],
      "/export_config_to_file",
    ),
    "/export_config_to_file?filePath=%2Ftmp%2Fmoon%20stat.json",
  )
  assert_eq(
    config_file_path(
      ["moonstat", "import_config_from_file", "--path", "/tmp/in.json"],
      "/import_config_from_file",
    ),
    "/import_config_from_file?filePath=%2Ftmp%2Fin.json",
  )
  assert_eq(
    db_backup_filename_path(
      ["moonstat", "restore_db_backup", "--filename", "moonstat-1.db"],
      "/restore_db_backup",
    ),
    "/restore_db_backup?filename=moonstat-1.db",
  )
  assert_eq(
    db_backup_rename_path([
      "moonstat", "rename_db_backup", "--oldFilename", "moonstat-1.db", "--newName",
      "renamed",
    ]),
    "/rename_db_backup?oldFilename=moonstat-1.db&newName=renamed",
  )
  assert_eq(
    db_backup_filename_path(
      ["moonstat", "delete_db_backup", "--name", "renamed.db"],
      "/delete_db_backup",
    ),
    "/delete_db_backup?filename=renamed.db",
  )
  assert_eq(
    deeplink_url_path(
      [
        "moonstat", "parse_deeplink", "--url", "ccswitch://v1/import?resource=skill&repo=vectie/skills",
      ],
      "/parse_deeplink",
    ),
    "/parse_deeplink?url=ccswitch%3A%2F%2Fv1%2Fimport%3Fresource%3Dskill%26repo%3Dvectie%2Fskills",
  )
  assert_eq(
    deeplink_request_path(
      [
        "moonstat", "merge_deeplink_config", "--request", "{\"resource\":\"provider\"}",
      ],
      "/merge_deeplink_config",
    ),
    "/merge_deeplink_config?request=%7B%22resource%22%3A%22provider%22%7D",
  )
  assert_eq(
    deeplink_request_path(
      [
        "moonstat", "import_from_deeplink_unified", "--url", "ccswitch://v1/import?resource=prompt&app=codex&name=Daily&content=SGVsbG8",
      ],
      "/import_from_deeplink_unified",
    ),
    "/import_from_deeplink_unified?url=ccswitch%3A%2F%2Fv1%2Fimport%3Fresource%3Dprompt%26app%3Dcodex%26name%3DDaily%26content%3DSGVsbG8",
  )
  assert_eq(
    sync_settings_path(
      [
        "moonstat", "webdav_sync_save_settings", "--settings", "{\"baseUrl\":\"https://dav.example.com\"}",
        "--passwordTouched", "false",
      ],
      "/webdav_sync_save_settings",
    ),
    "/webdav_sync_save_settings?settings=%7B%22baseUrl%22%3A%22https%3A%2F%2Fdav.example.com%22%7D&passwordTouched=false",
  )
  assert_eq(
    sync_settings_path(
      [
        "moonstat", "s3_test_connection", "--config", "{\"bucket\":\"moonstat\"}",
        "--preserve-empty-password", "true",
      ],
      "/s3_test_connection",
    ),
    "/s3_test_connection?settings=%7B%22bucket%22%3A%22moonstat%22%7D&preserveEmptyPassword=true",
  )
}

///|
test "top level ccs settings command names build settings paths" {
  assert_eq(
    app_config_dir_override_path([
      "moonstat", "set_app_config_dir_override", "--path", "/tmp/cc switch",
    ]),
    Some("/set_app_config_dir_override?path=%2Ftmp%2Fcc%20switch"),
  )
  assert_eq(
    app_config_dir_override_path([
      "moonstat", "set_app_config_dir_override", "--clear", "true",
    ]),
    Some("/set_app_config_dir_override?path="),
  )
  assert_eq(
    set_auto_launch_path(["moonstat", "set_auto_launch", "--enabled", "true"]),
    Some("/set_auto_launch?enabled=true"),
  )
  assert_eq(
    moon_json_config_path(
      [
        "moonstat", "set_rectifier_config", "--requestThinkingSignature", "false",
      ],
      "/set_rectifier_config",
      "--config",
    ),
    Some("/set_rectifier_config?requestThinkingSignature=false"),
  )
  assert_eq(
    moon_json_config_path(
      ["moonstat", "set_optimizer_config", "--config", "{\"cacheTtl\":\"5m\"}"],
      "/set_optimizer_config",
      "--config",
    ),
    Some("/set_optimizer_config?config=%7B%22cacheTtl%22%3A%225m%22%7D"),
  )
  assert_eq(
    moon_json_config_path(
      [
        "moonstat", "set_copilot_optimizer_config", "--warmupModel", "gpt-5-mini",
        "--stripThinking", "true",
      ],
      "/set_copilot_optimizer_config",
      "--config",
    ),
    Some(
      "/set_copilot_optimizer_config?warmupModel=gpt-5-mini&stripThinking=true",
    ),
  )
}

///|
test "top level ccs plugin command names build plugin paths" {
  assert_eq(
    apply_claude_plugin_config_path([
      "moonstat", "apply_claude_plugin_config", "--official", "true",
    ]),
    "/apply_claude_plugin_config?official=true",
  )
  assert_eq(
    apply_claude_plugin_config_path(["moonstat", "apply_claude_plugin_config"]),
    "/apply_claude_plugin_config",
  )
}

///|
test "top level ccs workspace command names build workspace paths" {
  assert_eq(
    workspace_filename_path(
      ["moonstat", "read_workspace_file", "--filename", "AGENTS.md"],
      "/read_workspace_file",
    ),
    "/read_workspace_file?filename=AGENTS.md",
  )
  assert_eq(
    workspace_content_path(
      [
        "moonstat", "write_workspace_file", "--filename", "AGENTS.md", "--content",
        "hello moon",
      ],
      "/write_workspace_file",
    ),
    Some("/write_workspace_file?filename=AGENTS.md&content=hello%20moon"),
  )
  assert_eq(
    workspace_query_path(
      ["moonstat", "search_daily_memory_files", "--query", "daily plan"],
      "/search_daily_memory_files",
    ),
    "/search_daily_memory_files?query=daily%20plan",
  )
  assert_eq(
    workspace_subdir_path(
      ["moonstat", "open_workspace_directory", "--subdir", "memory"],
      "/open_workspace_directory",
    ),
    "/open_workspace_directory?subdir=memory",
  )
}

///|
test "top level ccs mcp command names build mcp paths" {
  assert_eq(
    mcp_app_path(
      ["moonstat", "get_mcp_config", "--appType", "codex"],
      "/get_mcp_config",
    ),
    "/get_mcp_config?app=codex",
  )
  assert_eq(
    mcp_validate_command_path([
      "moonstat", "validate_mcp_command", "--command", "npx",
    ]),
    "/validate_mcp_command?command=npx",
  )
  assert_eq(
    mcp_id_path(
      ["moonstat", "delete_mcp_server", "--serverId", "filesystem server"],
      "/delete_mcp_server",
    ),
    Some("/delete_mcp_server?id=filesystem%20server"),
  )
  guard mcp_upsert_path(
      [
        "moonstat", "upsert_mcp_server_in_config", "--app", "codex", "--id", "filesystem",
        "--name", "Filesystem", "--command", "npx", "--syncOtherSide", "true",
      ],
      "/upsert_mcp_server_in_config",
    )
    is Some(upsert_path) else {
    fail("expected upsert path")
  }
  assert_true(upsert_path.has_prefix("/upsert_mcp_server_in_config?server="))
  assert_true(upsert_path.contains("&app=codex"))
  assert_true(upsert_path.contains("&syncOtherSide=true"))
  assert_true(upsert_path.contains("Filesystem"))
  assert_true(upsert_path.contains("npx"))
  assert_eq(
    mcp_enabled_path(
      [
        "moonstat", "toggle_mcp_app", "--id", "filesystem", "--app", "codex", "--enabled",
        "false",
      ],
      "/toggle_mcp_app",
    ),
    Some("/toggle_mcp_app?id=filesystem&app=codex&enabled=false"),
  )
}

///|
test "top level ccs prompt command names build prompt paths" {
  assert_eq(
    prompt_app_path(
      ["moonstat", "get_prompts", "--appType", "codex"],
      "/get_prompts",
    ),
    "/get_prompts?app=codex",
  )
  assert_eq(
    prompt_upsert_path([
      "moonstat", "upsert_prompt", "--app", "codex", "--id", "review", "--name",
      "Review", "--content", "Check this", "--description", "Code review", "--enabled",
      "true",
    ]),
    Some(
      "/upsert_prompt?app=codex&id=review&name=Review&content=Check%20this&description=Code%20review&enabled=true",
    ),
  )
  assert_eq(
    prompt_id_path(
      ["moonstat", "delete_prompt", "--app", "codex", "--promptId", "review"],
      "/delete_prompt",
    ),
    Some("/delete_prompt?app=codex&id=review"),
  )
  assert_eq(
    prompt_file_path(
      [
        "moonstat", "import_prompt_from_file", "--app", "codex", "--path", "/tmp/prompts.md",
      ],
      "/import_prompt_from_file",
    ),
    "/import_prompt_from_file?app=codex&path=%2Ftmp%2Fprompts.md",
  )
}

///|
test "top level ccs balance command builds balance path" {
  assert_eq(
    balance_path([
      "moonstat", "get_balance", "--baseUrl", "https://api.deepseek.com", "--apiKey",
      "sk test",
    ]),
    Some("/get_balance?baseUrl=https%3A%2F%2Fapi.deepseek.com&apiKey=sk%20test"),
  )
  assert_true(
    balance_path([
      "moonstat", "get_balance", "--base-url", "https://api.deepseek.com",
    ])
    is None,
  )
}

///|
test "top level ccs subscription quota command builds quota path" {
  assert_eq(
    subscription_quota_path([
      "moonstat", "get_subscription_quota", "--tool", "codex",
    ]),
    Some("/get_subscription_quota?tool=codex"),
  )
  assert_eq(
    subscription_quota_path([
      "moonstat", "usage", "quota", "--appType", "gemini",
    ]),
    Some("/get_subscription_quota?tool=gemini"),
  )
  assert_true(subscription_quota_path(["moonstat", "usage", "quota"]) is None)
}

///|
test "top level ccs codex oauth quota command builds quota path" {
  assert_eq(
    codex_oauth_quota_path([
      "moonstat", "get_codex_oauth_quota", "--accountId", "acct 1",
    ]),
    "/get_codex_oauth_quota?accountId=acct%201",
  )
  assert_eq(
    codex_oauth_quota_path(["moonstat", "usage", "codex-oauth-quota"]),
    "/get_codex_oauth_quota",
  )
}

///|
test "top level ccs codex oauth models command builds models path" {
  assert_eq(
    codex_oauth_models_path([
      "moonstat", "get_codex_oauth_models", "--account-id", "acct 1",
    ]),
    "/get_codex_oauth_models?accountId=acct%201",
  )
  assert_eq(
    codex_oauth_models_path(["moonstat", "usage", "codex-oauth-models"]),
    "/get_codex_oauth_models",
  )
}

///|
test "ccs auth commands build managed auth paths" {
  assert_eq(
    auth_provider_path(
      ["moonstat", "auth_get_status", "--authProvider", "codex_oauth"],
      "/auth_get_status",
    ),
    "/auth_get_status?authProvider=codex_oauth",
  )
  assert_eq(
    auth_provider_path(["moonstat", "auth", "status"], "/auth_get_status"),
    "/auth_get_status",
  )
  assert_eq(
    auth_account_path(
      [
        "moonstat", "auth_remove_account", "--account-id", "acct 1", "--auth-provider",
        "codex_oauth",
      ],
      "/auth_remove_account",
    ),
    Some("/auth_remove_account?accountId=acct%201&authProvider=codex_oauth"),
  )
  assert_true(
    auth_account_path(
      ["moonstat", "auth_remove_account"],
      "/auth_remove_account",
    )
    is None,
  )
  assert_eq(
    auth_poll_path([
      "moonstat", "auth_poll_for_account", "--device-code", "dev 1", "--user-code",
      "USER-CODE",
    ]),
    Some("/auth_poll_for_account?deviceCode=dev%201&userCode=USER-CODE"),
  )
}

///|
test "top level ccs coding plan command builds quota path" {
  assert_eq(
    coding_plan_quota_path([
      "moonstat", "get_coding_plan_quota", "--baseUrl", "https://api.kimi.com/coding/v1",
      "--apiKey", "sk test",
    ]),
    Some(
      "/get_coding_plan_quota?baseUrl=https%3A%2F%2Fapi.kimi.com%2Fcoding%2Fv1&apiKey=sk%20test",
    ),
  )
  assert_eq(
    coding_plan_quota_path([
      "moonstat", "usage", "coding-plan", "--base-url", "https://api.minimax.io",
      "--api-key", "key",
    ]),
    Some(
      "/get_coding_plan_quota?baseUrl=https%3A%2F%2Fapi.minimax.io&apiKey=key",
    ),
  )
  assert_true(
    coding_plan_quota_path(["moonstat", "usage", "coding-plan"]) is None,
  )
}

///|
test "top level ccs app shell commands build paths" {
  assert_eq(
    open_external_path(["moonstat", "open_external", "--url", "github.com/a b"]),
    "/open_external?url=github.com%2Fa%20b",
  )
  assert_eq(
    copy_text_to_clipboard_path([
      "moonstat", "copy_text_to_clipboard", "--text", "hello world",
    ]),
    "/copy_text_to_clipboard?text=hello%20world",
  )
  assert_eq(
    tool_versions_path([
      "moonstat", "get_tool_versions", "--tools", "codex,claude",
    ]),
    "/get_tool_versions?tools=codex%2Cclaude",
  )
  assert_eq(
    window_theme_path(["moonstat", "set_window_theme", "--theme", "dark"]),
    "/set_window_theme?theme=dark",
  )
  assert_eq(
    save_file_dialog_path([
      "moonstat", "save_file_dialog", "--default-name", "config.json",
    ]),
    "/save_file_dialog?defaultName=config.json",
  )
}

///|
test "top level ccs skill commands build paths" {
  assert_eq(
    skill_install_path(
      [
        "moonstat", "install_skill_unified", "--directory", "traffic stats", "--name",
        "Traffic Stats", "--description", "Routes and usage", "--app", "codex",
      ],
      "/install_skill_unified",
    ),
    "/install_skill_unified?directory=traffic%20stats&name=Traffic%20Stats&description=Routes%20and%20usage&app=codex",
  )
  assert_eq(
    skill_toggle_app_path([
      "moonstat", "toggle_skill_app", "--id", "traffic-stats", "--app", "hermes",
      "--enabled", "true",
    ]),
    "/toggle_skill_app?id=traffic-stats&app=hermes&enabled=true",
  )
  assert_eq(
    skill_restore_backup_path([
      "moonstat", "restore_skill_backup", "--backupId", "traffic-stats-1", "--currentApp",
      "claude",
    ]),
    "/restore_skill_backup?backupId=traffic-stats-1&currentApp=claude",
  )
  assert_eq(
    skill_search_path([
      "moonstat", "search_skills_sh", "--query", "proxy skill", "--limit", "5", "--offset",
      "10",
    ]),
    "/search_skills_sh?query=proxy%20skill&limit=5&offset=10",
  )
  assert_eq(
    skill_repo_add_path([
      "moonstat", "add_skill_repo", "--owner", "vectie", "--name", "moonstat-skills",
      "--branch", "main", "--enabled", "true",
    ]),
    "/add_skill_repo?owner=vectie&name=moonstat-skills&branch=main&enabled=true",
  )
  assert_eq(
    skill_zip_install_path([
      "moonstat", "install_skills_from_zip", "--filePath", "/tmp/skill bundle", "--currentApp",
      "codex",
    ]),
    "/install_skills_from_zip?filePath=%2Ftmp%2Fskill%20bundle&currentApp=codex",
  )
}

///|
test "top level ccs provider test hook commands build paths" {
  assert_eq(
    proxy_app_value_update_path(
      [
        "moonstat", "set_default_cost_multiplier_test_hook", "--appType", "codex",
        "--value", "1.25",
      ],
      "/set_default_cost_multiplier_test_hook",
    ),
    Some("/set_default_cost_multiplier_test_hook?app_type=codex&value=1.25"),
  )
  assert_eq(
    proxy_app_value_update_path(
      [
        "moonstat", "set_pricing_model_source_test_hook", "--app-type", "claude",
        "--value", "request",
      ],
      "/set_pricing_model_source_test_hook",
    ),
    Some("/set_pricing_model_source_test_hook?app_type=claude&value=request"),
  )
  assert_eq(
    provider_id_path(
      [
        "moonstat", "switch_provider_test_hook", "--app", "claude", "--id", "codex-oauth",
      ],
      "/switch_provider_test_hook",
    ),
    Some("/switch_provider_test_hook?app=claude&id=codex-oauth"),
  )
}
