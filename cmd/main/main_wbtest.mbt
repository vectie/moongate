///|
test "has flag matches exact CLI option" {
  let args = ["moonstat", "models", "fetch", "--full-url"]
  assert_true(has_flag(args, "--full-url"))
  assert_false(has_flag(args, "--is-full-url"))
}

///|
test "provider model JSON uses ccs field names" {
  let json = provider_model_fields_to_json("gpt-test", Some("openai"))
  assert_eq(json.stringify(), "{\"id\":\"gpt-test\",\"ownedBy\":\"openai\"}")
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
    Some("/proxy/takeover-status?app_type=codex&enabled=true"),
  )
  assert_eq(
    proxy_app_value_update_path(
      [
        "moonstat", "proxy", "default-cost-multiplier", "set", "--app-type", "codex",
        "--value", "1.25",
      ],
      "/proxy/default-cost-multiplier",
    ),
    Some("/proxy/default-cost-multiplier?app_type=codex&value=1.25"),
  )
  assert_eq(
    proxy_provider_endpoint_path(
      [
        "moonstat", "proxy", "switch-proxy-provider", "--app-type", "codex", "--provider-id",
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
    ccs_json_config_path(
      [
        "moonstat", "set_rectifier_config", "--requestThinkingSignature", "false",
      ],
      "/set_rectifier_config",
      "--config",
    ),
    Some("/set_rectifier_config?requestThinkingSignature=false"),
  )
  assert_eq(
    ccs_json_config_path(
      ["moonstat", "set_optimizer_config", "--config", "{\"cacheTtl\":\"5m\"}"],
      "/set_optimizer_config",
      "--config",
    ),
    Some("/set_optimizer_config?config=%7B%22cacheTtl%22%3A%225m%22%7D"),
  )
  assert_eq(
    ccs_json_config_path(
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
