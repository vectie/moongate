///|
pub fn MoonstatClient::endpoint(self : MoonstatClient, path : String) -> String {
  moonstat_client_url(self.base_url, path)
}

///|
pub fn MoonstatClient::health_url(self : MoonstatClient) -> String {
  self.endpoint("/health")
}

///|
pub fn MoonstatClient::status_url(self : MoonstatClient) -> String {
  self.endpoint("/status")
}

///|
pub fn MoonstatClient::stats_url(self : MoonstatClient) -> String {
  self.endpoint("/stats")
}

///|
pub fn MoonstatClient::metrics_url(self : MoonstatClient) -> String {
  self.endpoint("/metrics")
}

///|
pub fn MoonstatClient::models_url(self : MoonstatClient) -> String {
  self.endpoint("/v1/models")
}

///|
pub fn MoonstatClient::route_chat_url(self : MoonstatClient) -> String {
  self.endpoint("/v1/chat/completions")
}

///|
pub fn MoonstatClient::route_response_url(self : MoonstatClient) -> String {
  self.endpoint("/v1/responses")
}

///|
pub fn MoonstatClient::route_response_compact_url(
  self : MoonstatClient,
) -> String {
  self.endpoint("/v1/responses/compact")
}

///|
pub fn MoonstatClient::route_messages_url(self : MoonstatClient) -> String {
  self.endpoint("/v1/messages")
}

///|
pub fn MoonstatClient::usage_logs_url(
  self : MoonstatClient,
  query? : MoonstatUsageQuery? = None,
) -> String {
  moonstat_client_url_with_query(self.base_url, "/usage/logs", query)
}

///|
pub fn MoonstatClient::usage_summary_url(
  self : MoonstatClient,
  query? : MoonstatUsageQuery? = None,
) -> String {
  moonstat_client_url_with_query(self.base_url, "/usage/summary", query)
}

///|
pub fn MoonstatClient::usage_summary_by_app_url(
  self : MoonstatClient,
  query? : MoonstatUsageQuery? = None,
) -> String {
  moonstat_client_url_with_query(self.base_url, "/usage/summary/by-app", query)
}

///|
pub fn MoonstatClient::usage_trends_url(
  self : MoonstatClient,
  query? : MoonstatUsageQuery? = None,
) -> String {
  moonstat_client_url_with_query(self.base_url, "/usage/trends", query)
}

///|
pub fn MoonstatClient::usage_provider_limits_url(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> String {
  let query = {
    start_date: None,
    end_date: None,
    app_type: Some(app_type),
    provider_id: Some(provider_id),
    provider_name: None,
    model: None,
    status_code: None,
    page: None,
    page_size: None,
  }
  moonstat_client_url_with_query(
    self.base_url,
    "/usage/provider-limits",
    Some(query),
  )
}

///|
pub fn MoonstatClient::usage_provider_usage_url(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> String {
  let query = {
    start_date: None,
    end_date: None,
    app_type: Some(app_type),
    provider_id: Some(provider_id),
    provider_name: None,
    model: None,
    status_code: None,
    page: None,
    page_size: None,
  }
  moonstat_client_url_with_query(
    self.base_url,
    "/usage/provider-usage",
    Some(query),
  )
}

///|
pub fn MoonstatClient::usage_provider_stats_url(
  self : MoonstatClient,
  query? : MoonstatUsageQuery? = None,
) -> String {
  moonstat_client_url_with_query(self.base_url, "/usage/provider-stats", query)
}

///|
pub fn MoonstatClient::usage_model_stats_url(
  self : MoonstatClient,
  query? : MoonstatUsageQuery? = None,
) -> String {
  moonstat_client_url_with_query(self.base_url, "/usage/model-stats", query)
}

///|
pub fn MoonstatClient::usage_data_sources_url(self : MoonstatClient) -> String {
  self.endpoint("/usage/data-sources")
}

///|
pub fn MoonstatClient::usage_model_pricing_url(self : MoonstatClient) -> String {
  self.endpoint("/usage/model-pricing")
}

///|
pub fn MoonstatClient::usage_delete_model_pricing_url(
  self : MoonstatClient,
  model_id : String,
) -> String {
  self.endpoint(
    "/usage/model-pricing?\{moonstat_client_query_pair("modelId", model_id)}",
  )
}

///|
pub fn MoonstatClient::usage_sync_session_url(
  self : MoonstatClient,
  query? : MoonstatSessionSyncQuery? = None,
) -> String {
  moonstat_client_url_with_session_sync_query(
    self.base_url,
    "/usage/sync-session",
    query,
  )
}

///|
pub fn MoonstatClient::usage_request_detail_url(
  self : MoonstatClient,
  request_id : String,
) -> String {
  self.endpoint("/usage/request-detail/\{copilot_url_encode(request_id)}")
}

///|
pub fn MoonstatClient::proxy_status_url(self : MoonstatClient) -> String {
  self.endpoint("/proxy/status")
}

///|
pub fn MoonstatClient::proxy_running_url(self : MoonstatClient) -> String {
  self.endpoint("/proxy/running")
}

///|
pub fn MoonstatClient::proxy_global_config_url(self : MoonstatClient) -> String {
  self.endpoint("/proxy/global-config")
}

///|
pub fn MoonstatClient::proxy_global_url_url(self : MoonstatClient) -> String {
  self.endpoint("/proxy/global-url")
}

///|
pub fn MoonstatClient::proxy_upstream_status_url(
  self : MoonstatClient,
) -> String {
  self.endpoint("/proxy/upstream-status")
}

///|
pub fn MoonstatClient::proxy_local_proxies_url(self : MoonstatClient) -> String {
  self.endpoint("/proxy/local-proxies")
}

///|
pub fn MoonstatClient::proxy_app_config_url(
  self : MoonstatClient,
  app_type : String,
) -> String {
  self.endpoint(
    moonstat_client_path_with_pairs("/proxy/app-config", [("appType", app_type)]),
  )
}

///|
pub fn MoonstatClient::proxy_default_cost_multiplier_url(
  self : MoonstatClient,
  app_type : String,
) -> String {
  self.endpoint(
    moonstat_client_path_with_pairs("/proxy/default-cost-multiplier", [
      ("appType", app_type),
    ]),
  )
}

///|
pub fn MoonstatClient::proxy_pricing_model_source_url(
  self : MoonstatClient,
  app_type : String,
) -> String {
  self.endpoint(
    moonstat_client_path_with_pairs("/proxy/pricing-model-source", [
      ("appType", app_type),
    ]),
  )
}

///|
pub fn MoonstatClient::proxy_circuit_breaker_config_url(
  self : MoonstatClient,
) -> String {
  self.endpoint("/proxy/circuit-breaker-config")
}

///|
pub fn MoonstatClient::proxy_provider_health_url(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> String {
  self.endpoint(
    moonstat_client_proxy_provider_path(
      "/proxy/provider-health", app_type, provider_id,
    ),
  )
}

///|
pub fn MoonstatClient::proxy_circuit_breaker_stats_url(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> String {
  self.endpoint(
    moonstat_client_proxy_provider_path(
      "/proxy/circuit-breaker-stats", app_type, provider_id,
    ),
  )
}

///|
pub fn MoonstatClient::proxy_failover_queue_url(
  self : MoonstatClient,
  app_type : String,
) -> String {
  self.endpoint(
    moonstat_client_path_with_pairs("/proxy/failover-queue", [
      ("appType", app_type),
    ]),
  )
}

///|
pub fn MoonstatClient::proxy_available_failover_providers_url(
  self : MoonstatClient,
  app_type : String,
) -> String {
  self.endpoint(
    moonstat_client_path_with_pairs("/proxy/available-failover-providers", [
      ("appType", app_type),
    ]),
  )
}

///|
pub fn MoonstatClient::proxy_auto_failover_enabled_url(
  self : MoonstatClient,
  app_type : String,
) -> String {
  self.endpoint(
    moonstat_client_path_with_pairs("/proxy/auto-failover-enabled", [
      ("appType", app_type),
    ]),
  )
}

///|
pub fn MoonstatClient::proxy_takeover_status_url(
  self : MoonstatClient,
) -> String {
  self.endpoint("/proxy/takeover-status")
}

///|
pub fn MoonstatClient::proxy_start_url(self : MoonstatClient) -> String {
  self.endpoint("/proxy/start")
}

///|
pub fn MoonstatClient::proxy_stop_url(self : MoonstatClient) -> String {
  self.endpoint("/proxy/stop")
}

///|
pub fn MoonstatClient::proxy_stop_with_restore_url(
  self : MoonstatClient,
) -> String {
  self.endpoint("/proxy/stop-with-restore")
}

///|
pub fn MoonstatClient::proxy_update_global_config_url(
  self : MoonstatClient,
  proxy_enabled? : String? = None,
  listen_address? : String? = None,
  listen_port? : String? = None,
  enable_logging? : String? = None,
) -> String {
  self.endpoint(
    moonstat_client_path_with_optional_pairs("/proxy/global-config", [
      ("proxyEnabled", proxy_enabled),
      ("listenAddress", listen_address),
      ("listenPort", listen_port),
      ("enableLogging", enable_logging),
    ]),
  )
}

///|
pub fn MoonstatClient::proxy_set_global_url_url(
  self : MoonstatClient,
  url : String,
) -> String {
  self.endpoint(
    moonstat_client_path_with_pairs("/proxy/global-url", [("url", url)]),
  )
}

///|
pub fn MoonstatClient::proxy_test_url_url(
  self : MoonstatClient,
  url : String,
) -> String {
  self.endpoint(
    moonstat_client_path_with_pairs("/proxy/test-url", [("url", url)]),
  )
}

///|
pub fn MoonstatClient::proxy_update_app_config_url(
  self : MoonstatClient,
  app_type : String,
  enabled? : String? = None,
  auto_failover_enabled? : String? = None,
  max_retries? : String? = None,
  streaming_first_byte_timeout? : String? = None,
  streaming_idle_timeout? : String? = None,
  non_streaming_timeout? : String? = None,
  failure_threshold? : String? = None,
  success_threshold? : String? = None,
  timeout_seconds? : String? = None,
  error_rate_threshold? : String? = None,
  min_requests? : String? = None,
) -> String {
  self.endpoint(
    moonstat_client_path_with_optional_pairs("/proxy/app-config", [
      ("appType", Some(app_type)),
      ("enabled", enabled),
      ("autoFailoverEnabled", auto_failover_enabled),
      ("maxRetries", max_retries),
      ("streamingFirstByteTimeout", streaming_first_byte_timeout),
      ("streamingIdleTimeout", streaming_idle_timeout),
      ("nonStreamingTimeout", non_streaming_timeout),
      ("failureThreshold", failure_threshold),
      ("successThreshold", success_threshold),
      ("timeoutSeconds", timeout_seconds),
      ("errorRateThreshold", error_rate_threshold),
      ("minRequests", min_requests),
    ]),
  )
}

///|
pub fn MoonstatClient::proxy_set_default_cost_multiplier_url(
  self : MoonstatClient,
  app_type : String,
  value : String,
) -> String {
  self.endpoint(
    moonstat_client_path_with_pairs("/proxy/default-cost-multiplier", [
      ("appType", app_type),
      ("value", value),
    ]),
  )
}

///|
pub fn MoonstatClient::proxy_set_pricing_model_source_url(
  self : MoonstatClient,
  app_type : String,
  value : String,
) -> String {
  self.endpoint(
    moonstat_client_path_with_pairs("/proxy/pricing-model-source", [
      ("appType", app_type),
      ("value", value),
    ]),
  )
}

///|
pub fn MoonstatClient::proxy_update_circuit_breaker_config_url(
  self : MoonstatClient,
  failure_threshold : String,
  success_threshold : String,
  timeout_seconds : String,
  error_rate_threshold : String,
  min_requests : String,
) -> String {
  self.endpoint(
    moonstat_client_path_with_pairs("/proxy/circuit-breaker-config", [
      ("failureThreshold", failure_threshold),
      ("successThreshold", success_threshold),
      ("timeoutSeconds", timeout_seconds),
      ("errorRateThreshold", error_rate_threshold),
      ("minRequests", min_requests),
    ]),
  )
}

///|
pub fn MoonstatClient::proxy_reset_circuit_breaker_url(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> String {
  self.endpoint(
    moonstat_client_proxy_provider_path(
      "/proxy/reset-circuit-breaker", app_type, provider_id,
    ),
  )
}

///|
pub fn MoonstatClient::proxy_add_failover_queue_url(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> String {
  self.endpoint(
    moonstat_client_proxy_provider_path(
      "/proxy/failover-queue", app_type, provider_id,
    ),
  )
}

///|
pub fn MoonstatClient::proxy_remove_failover_queue_url(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> String {
  self.proxy_add_failover_queue_url(app_type, provider_id)
}

///|
pub fn MoonstatClient::proxy_set_auto_failover_enabled_url(
  self : MoonstatClient,
  app_type : String,
  enabled : String,
) -> String {
  self.endpoint(
    moonstat_client_path_with_pairs("/proxy/auto-failover-enabled", [
      ("appType", app_type),
      ("enabled", enabled),
    ]),
  )
}

///|
pub fn MoonstatClient::proxy_set_takeover_status_url(
  self : MoonstatClient,
  app_type : String,
  enabled : String,
) -> String {
  self.endpoint(
    moonstat_client_path_with_pairs("/proxy/takeover-status", [
      ("appType", app_type),
      ("enabled", enabled),
    ]),
  )
}

///|
pub fn MoonstatClient::proxy_switch_provider_url(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> String {
  self.endpoint(
    moonstat_client_proxy_provider_path(
      "/proxy/switch-provider", app_type, provider_id,
    ),
  )
}
