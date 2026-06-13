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
}
