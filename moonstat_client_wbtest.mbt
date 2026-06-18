///|
test "moonstat client builds core endpoint URLs" {
  let client = MoonstatClient::new(base_url="http://127.0.0.1:4199/")
  assert_eq(client.base_url, "http://127.0.0.1:4199")
  assert_eq(client.health_url(), "http://127.0.0.1:4199/health")
  assert_eq(client.status_url(), "http://127.0.0.1:4199/status")
  assert_eq(client.stats_url(), "http://127.0.0.1:4199/stats")
  assert_eq(client.metrics_url(), "http://127.0.0.1:4199/metrics")
  assert_eq(client.models_url(), "http://127.0.0.1:4199/v1/models")
  assert_eq(
    client.usage_data_sources_url(),
    "http://127.0.0.1:4199/usage/data-sources",
  )
  assert_eq(
    client.usage_model_pricing_url(),
    "http://127.0.0.1:4199/usage/model-pricing",
  )
}

///|
test "moonstat host client maps wildcard host to loopback" {
  let client = MoonstatClient::from_host(host="0.0.0.0", port=15722)
  assert_eq(client.base_url, "http://127.0.0.1:15722")
}

///|
test "moonstat client builds usage query URLs" {
  let client = MoonstatClient::new(base_url="http://127.0.0.1:4199")
  let query = {
    start_date: Some("10"),
    end_date: Some("20"),
    app_type: Some("codex"),
    provider_id: Some("Codex OAuth"),
    page: Some(2),
    page_size: Some(25),
  }
  assert_eq(
    client.usage_logs_url(query=Some(query)),
    "http://127.0.0.1:4199/usage/logs?startDate=10&endDate=20&appType=codex&providerId=Codex%20OAuth&page=2&pageSize=25",
  )
  assert_eq(
    client.usage_summary_url(query=Some(query)),
    "http://127.0.0.1:4199/usage/summary?startDate=10&endDate=20&appType=codex&providerId=Codex%20OAuth&page=2&pageSize=25",
  )
  assert_eq(
    client.usage_summary_by_app_url(query=Some(query)),
    "http://127.0.0.1:4199/usage/summary/by-app?startDate=10&endDate=20&appType=codex&providerId=Codex%20OAuth&page=2&pageSize=25",
  )
  assert_eq(
    client.usage_trends_url(query=Some(query)),
    "http://127.0.0.1:4199/usage/trends?startDate=10&endDate=20&appType=codex&providerId=Codex%20OAuth&page=2&pageSize=25",
  )
  assert_eq(
    client.usage_provider_stats_url(query=Some(query)),
    "http://127.0.0.1:4199/usage/provider-stats?startDate=10&endDate=20&appType=codex&providerId=Codex%20OAuth&page=2&pageSize=25",
  )
  assert_eq(
    client.usage_model_stats_url(query=Some(query)),
    "http://127.0.0.1:4199/usage/model-stats?startDate=10&endDate=20&appType=codex&providerId=Codex%20OAuth&page=2&pageSize=25",
  )
}

///|
test "moonstat client builds required endpoint parameters" {
  let client = MoonstatClient::new(base_url="http://127.0.0.1:4199")
  assert_eq(
    client.usage_provider_limits_url("claude", "provider/a b"),
    "http://127.0.0.1:4199/usage/provider-limits?appType=claude&providerId=provider%2Fa%20b",
  )
  assert_eq(
    client.usage_request_detail_url("req/a b"),
    "http://127.0.0.1:4199/usage/request-detail/req%2Fa%20b",
  )
}

///|
test "moonstat client omits empty usage query values" {
  let client = MoonstatClient::new(base_url="   ")
  assert_eq(client.base_url, "http://127.0.0.1:15721")
  let query = {
    start_date: Some(""),
    end_date: None,
    app_type: Some("  "),
    provider_id: None,
    page: None,
    page_size: Some(50),
  }
  assert_eq(
    client.usage_logs_url(query=Some(query)),
    "http://127.0.0.1:15721/usage/logs?pageSize=50",
  )
  assert_eq(
    client.usage_logs_url(query=Some(MoonstatUsageQuery::empty())),
    "http://127.0.0.1:15721/usage/logs",
  )
}
