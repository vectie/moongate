///|
pub async fn MoonGateClient::health(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/health")
}

///|
pub async fn MoonGateClient::status(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/status")
}

///|
pub async fn MoonGateClient::stats(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/stats")
}

///|
pub async fn MoonGateClient::metrics(
  self : MoonGateClient,
) -> Result[String, String] {
  self.get_text_path("/metrics")
}

///|
pub async fn MoonGateClient::models(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/v1/models")
}

///|
pub async fn MoonGateClient::model_catalog(
  self : MoonGateClient,
) -> Result[Array[MoonGateModel], String] {
  match self.models() {
    Ok(json) => moongate_models_from_json(json)
    Err(err) => Err(err)
  }
}

///|
pub async fn MoonGateClient::usage_logs(
  self : MoonGateClient,
  query? : MoonGateUsageQuery? = None,
) -> Result[Json, String] {
  self.get_json_path(moongate_client_path_with_query("/usage/logs", query))
}

///|
pub async fn MoonGateClient::usage_summary(
  self : MoonGateClient,
  query? : MoonGateUsageQuery? = None,
) -> Result[Json, String] {
  self.get_json_path(moongate_client_path_with_query("/usage/summary", query))
}

///|
pub async fn MoonGateClient::usage_summary_typed(
  self : MoonGateClient,
  query? : MoonGateUsageQuery? = None,
) -> Result[MoonGateUsageSummary, String] {
  match self.usage_summary(query~) {
    Ok(json) => MoonGateUsageSummary::from_json(json)
    Err(err) => Err(err)
  }
}

///|
pub async fn MoonGateClient::usage_summary_by_app(
  self : MoonGateClient,
  query? : MoonGateUsageQuery? = None,
) -> Result[Json, String] {
  self.get_json_path(
    moongate_client_path_with_query("/usage/summary/by-app", query),
  )
}

///|
pub async fn MoonGateClient::usage_trends(
  self : MoonGateClient,
  query? : MoonGateUsageQuery? = None,
) -> Result[Json, String] {
  self.get_json_path(moongate_client_path_with_query("/usage/trends", query))
}

///|
pub async fn MoonGateClient::usage_provider_limits(
  self : MoonGateClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
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
  self.get_json_path(
    moongate_client_path_with_query("/usage/provider-limits", Some(query)),
  )
}

///|
pub async fn MoonGateClient::usage_provider_usage(
  self : MoonGateClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
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
  self.get_json_path(
    moongate_client_path_with_query("/usage/provider-usage", Some(query)),
  )
}

///|
pub async fn MoonGateClient::usage_provider_stats(
  self : MoonGateClient,
  query? : MoonGateUsageQuery? = None,
) -> Result[Json, String] {
  self.get_json_path(
    moongate_client_path_with_query("/usage/provider-stats", query),
  )
}

///|
pub async fn MoonGateClient::usage_model_stats(
  self : MoonGateClient,
  query? : MoonGateUsageQuery? = None,
) -> Result[Json, String] {
  self.get_json_path(
    moongate_client_path_with_query("/usage/model-stats", query),
  )
}

///|
pub async fn MoonGateClient::usage_data_sources(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/usage/data-sources")
}

///|
pub async fn MoonGateClient::usage_model_pricing(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/usage/model-pricing")
}

///|
pub async fn MoonGateClient::usage_update_model_pricing(
  self : MoonGateClient,
  pricing : ModelPricing,
) -> Result[Json, String] {
  self.post_json_path("/usage/model-pricing", pricing.to_json())
}

///|
pub async fn MoonGateClient::usage_delete_model_pricing(
  self : MoonGateClient,
  model_id : String,
) -> Result[Json, String] {
  self.delete_json_path(
    "/usage/model-pricing?\{moongate_client_query_pair("modelId", model_id)}",
  )
}

///|
pub async fn MoonGateClient::usage_sync_session(
  self : MoonGateClient,
  query? : MoonGateSessionSyncQuery? = None,
) -> Result[Json, String] {
  self.post_json_path(
    moongate_client_session_sync_path_with_query("/usage/sync-session", query),
    Json::null(),
  )
}

///|
pub async fn MoonGateClient::usage_request_detail(
  self : MoonGateClient,
  request_id : String,
) -> Result[Json, String] {
  self.get_json_path("/usage/request-detail/\{copilot_url_encode(request_id)}")
}

///|
pub async fn MoonGateClient::proxy_status(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/status")
}

///|
pub async fn MoonGateClient::proxy_running(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/running")
}

///|
pub async fn MoonGateClient::proxy_global_config(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/global-config")
}

///|
pub async fn MoonGateClient::proxy_global_url(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/global-url")
}

///|
pub async fn MoonGateClient::proxy_upstream_status(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/upstream-status")
}

///|
pub async fn MoonGateClient::proxy_local_proxies(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/local-proxies")
}

///|
pub async fn MoonGateClient::proxy_app_config(
  self : MoonGateClient,
  app_type : String,
) -> Result[Json, String] {
  self.get_json_path(
    moongate_client_path_with_pairs("/proxy/app-config", [("appType", app_type)]),
  )
}

///|
pub async fn MoonGateClient::proxy_default_cost_multiplier(
  self : MoonGateClient,
  app_type : String,
) -> Result[Json, String] {
  self.get_json_path(
    moongate_client_path_with_pairs("/proxy/default-cost-multiplier", [
      ("appType", app_type),
    ]),
  )
}

///|
pub async fn MoonGateClient::proxy_pricing_model_source(
  self : MoonGateClient,
  app_type : String,
) -> Result[Json, String] {
  self.get_json_path(
    moongate_client_path_with_pairs("/proxy/pricing-model-source", [
      ("appType", app_type),
    ]),
  )
}

///|
pub async fn MoonGateClient::proxy_circuit_breaker_config(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/circuit-breaker-config")
}

///|
pub async fn MoonGateClient::proxy_provider_health(
  self : MoonGateClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
  self.get_json_path(
    moongate_client_proxy_provider_path(
      "/proxy/provider-health", app_type, provider_id,
    ),
  )
}

///|
pub async fn MoonGateClient::proxy_circuit_breaker_stats(
  self : MoonGateClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
  self.get_json_path(
    moongate_client_proxy_provider_path(
      "/proxy/circuit-breaker-stats", app_type, provider_id,
    ),
  )
}

///|
pub async fn MoonGateClient::proxy_failover_queue(
  self : MoonGateClient,
  app_type : String,
) -> Result[Json, String] {
  self.get_json_path(
    moongate_client_path_with_pairs("/proxy/failover-queue", [
      ("appType", app_type),
    ]),
  )
}

///|
pub async fn MoonGateClient::proxy_available_failover_providers(
  self : MoonGateClient,
  app_type : String,
) -> Result[Json, String] {
  self.get_json_path(
    moongate_client_path_with_pairs("/proxy/available-failover-providers", [
      ("appType", app_type),
    ]),
  )
}

///|
pub async fn MoonGateClient::proxy_auto_failover_enabled(
  self : MoonGateClient,
  app_type : String,
) -> Result[Json, String] {
  self.get_json_path(
    moongate_client_path_with_pairs("/proxy/auto-failover-enabled", [
      ("appType", app_type),
    ]),
  )
}

///|
pub async fn MoonGateClient::proxy_takeover_status(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/takeover-status")
}

///|
pub async fn MoonGateClient::proxy_start(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.post_json_path("/proxy/start", Json::null())
}

///|
pub async fn MoonGateClient::proxy_stop(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.post_json_path("/proxy/stop", Json::null())
}

///|
pub async fn MoonGateClient::proxy_stop_with_restore(
  self : MoonGateClient,
) -> Result[Json, String] {
  self.post_json_path("/proxy/stop-with-restore", Json::null())
}

///|
pub async fn MoonGateClient::proxy_update_global_config(
  self : MoonGateClient,
  proxy_enabled? : String? = None,
  listen_address? : String? = None,
  listen_port? : String? = None,
  enable_logging? : String? = None,
) -> Result[Json, String] {
  self.post_json_path(
    moongate_client_path_with_optional_pairs("/proxy/global-config", [
      ("proxyEnabled", proxy_enabled),
      ("listenAddress", listen_address),
      ("listenPort", listen_port),
      ("enableLogging", enable_logging),
    ]),
    Json::null(),
  )
}

///|
pub async fn MoonGateClient::proxy_set_global_url(
  self : MoonGateClient,
  url : String,
) -> Result[Json, String] {
  self.post_json_path(
    moongate_client_path_with_pairs("/proxy/global-url", [("url", url)]),
    Json::null(),
  )
}

///|
pub async fn MoonGateClient::proxy_test_url(
  self : MoonGateClient,
  url : String,
) -> Result[Json, String] {
  self.post_json_path(
    moongate_client_path_with_pairs("/proxy/test-url", [("url", url)]),
    Json::null(),
  )
}

///|
pub async fn MoonGateClient::proxy_update_app_config(
  self : MoonGateClient,
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
) -> Result[Json, String] {
  self.post_json_path(
    moongate_client_path_with_optional_pairs("/proxy/app-config", [
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
    Json::null(),
  )
}

///|
pub async fn MoonGateClient::proxy_set_default_cost_multiplier(
  self : MoonGateClient,
  app_type : String,
  value : String,
) -> Result[Json, String] {
  self.post_json_path(
    moongate_client_path_with_pairs("/proxy/default-cost-multiplier", [
      ("appType", app_type),
      ("value", value),
    ]),
    Json::null(),
  )
}

///|
pub async fn MoonGateClient::proxy_set_pricing_model_source(
  self : MoonGateClient,
  app_type : String,
  value : String,
) -> Result[Json, String] {
  self.post_json_path(
    moongate_client_path_with_pairs("/proxy/pricing-model-source", [
      ("appType", app_type),
      ("value", value),
    ]),
    Json::null(),
  )
}

///|
pub async fn MoonGateClient::proxy_update_circuit_breaker_config(
  self : MoonGateClient,
  failure_threshold : String,
  success_threshold : String,
  timeout_seconds : String,
  error_rate_threshold : String,
  min_requests : String,
) -> Result[Json, String] {
  self.post_json_path(
    moongate_client_path_with_pairs("/proxy/circuit-breaker-config", [
      ("failureThreshold", failure_threshold),
      ("successThreshold", success_threshold),
      ("timeoutSeconds", timeout_seconds),
      ("errorRateThreshold", error_rate_threshold),
      ("minRequests", min_requests),
    ]),
    Json::null(),
  )
}

///|
pub async fn MoonGateClient::proxy_reset_circuit_breaker(
  self : MoonGateClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
  self.post_json_path(
    moongate_client_proxy_provider_path(
      "/proxy/reset-circuit-breaker", app_type, provider_id,
    ),
    Json::null(),
  )
}

///|
pub async fn MoonGateClient::proxy_add_failover_queue(
  self : MoonGateClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
  self.post_json_path(
    moongate_client_proxy_provider_path(
      "/proxy/failover-queue", app_type, provider_id,
    ),
    Json::null(),
  )
}

///|
pub async fn MoonGateClient::proxy_remove_failover_queue(
  self : MoonGateClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
  self.delete_json_path(
    moongate_client_proxy_provider_path(
      "/proxy/failover-queue", app_type, provider_id,
    ),
  )
}

///|
pub async fn MoonGateClient::proxy_set_auto_failover_enabled(
  self : MoonGateClient,
  app_type : String,
  enabled : String,
) -> Result[Json, String] {
  self.post_json_path(
    moongate_client_path_with_pairs("/proxy/auto-failover-enabled", [
      ("appType", app_type),
      ("enabled", enabled),
    ]),
    Json::null(),
  )
}

///|
pub async fn MoonGateClient::proxy_set_takeover_status(
  self : MoonGateClient,
  app_type : String,
  enabled : String,
) -> Result[Json, String] {
  self.post_json_path(
    moongate_client_path_with_pairs("/proxy/takeover-status", [
      ("appType", app_type),
      ("enabled", enabled),
    ]),
    Json::null(),
  )
}

///|
pub async fn MoonGateClient::proxy_switch_provider(
  self : MoonGateClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
  self.post_json_path(
    moongate_client_proxy_provider_path(
      "/proxy/switch-provider", app_type, provider_id,
    ),
    Json::null(),
  )
}

///|
pub async fn MoonGateClient::route_chat(
  self : MoonGateClient,
  request : Json,
) -> Result[Json, String] {
  self.post_json_path("/v1/chat/completions", request)
}

///|
pub async fn MoonGateClient::route_openclaw_chat(
  self : MoonGateClient,
  request : Json,
) -> Result[Json, String] {
  self.post_json_path("/openclaw/v1/chat/completions", request)
}

///|
pub async fn MoonGateClient::route_response(
  self : MoonGateClient,
  request : Json,
) -> Result[Json, String] {
  self.post_json_path("/v1/responses", request)
}

///|
pub async fn MoonGateClient::route_response_compact(
  self : MoonGateClient,
  request : Json,
) -> Result[Json, String] {
  self.post_json_path("/v1/responses/compact", request)
}

///|
pub async fn MoonGateClient::route_messages(
  self : MoonGateClient,
  request : Json,
) -> Result[Json, String] {
  self.post_json_path("/v1/messages", request)
}
