///|
const MOONSTAT_DEFAULT_CLIENT_BASE_URL = "http://127.0.0.1:15721"

///|
pub struct MoonstatUsageQuery {
  start_date : String?
  end_date : String?
  app_type : String?
  provider_id : String?
  provider_name : String?
  model : String?
  status_code : String?
  page : Int?
  page_size : Int?
}

///|
pub fn MoonstatUsageQuery::empty() -> MoonstatUsageQuery {
  MoonstatUsageQuery::new(
    start_date=None,
    end_date=None,
    app_type=None,
    provider_id=None,
    provider_name=None,
    model=None,
    status_code=None,
    page=None,
    page_size=None,
  )
}

///|
pub fn MoonstatUsageQuery::new(
  start_date~ : String?,
  end_date~ : String?,
  app_type~ : String?,
  provider_id~ : String?,
  provider_name~ : String?,
  model~ : String?,
  status_code~ : String?,
  page~ : Int?,
  page_size~ : Int?,
) -> MoonstatUsageQuery {
  {
    start_date,
    end_date,
    app_type,
    provider_id,
    provider_name,
    model,
    status_code,
    page,
    page_size,
  }
}

///|
pub struct MoonstatSessionSyncQuery {
  projects_dir : String?
  codex_dir : String?
  gemini_dir : String?
  opencode_export_path : String?
  opencode_db_path : String?
}

///|
pub fn MoonstatSessionSyncQuery::empty() -> MoonstatSessionSyncQuery {
  MoonstatSessionSyncQuery::new(
    projects_dir=None,
    codex_dir=None,
    gemini_dir=None,
    opencode_export_path=None,
    opencode_db_path=None,
  )
}

///|
pub fn MoonstatSessionSyncQuery::new(
  projects_dir~ : String?,
  codex_dir~ : String?,
  gemini_dir~ : String?,
  opencode_export_path~ : String?,
  opencode_db_path~ : String?,
) -> MoonstatSessionSyncQuery {
  {
    projects_dir,
    codex_dir,
    gemini_dir,
    opencode_export_path,
    opencode_db_path,
  }
}

///|
pub struct MoonstatModel {
  id : String
  owner : String?
  context_window : Int?
}

///|
pub struct MoonstatUsageSummary {
  total_requests : Int
  total_cost : String
  total_input_tokens : Int64
  total_output_tokens : Int64
  total_cache_creation_tokens : Int64
  total_cache_read_tokens : Int64
  real_total_tokens : Int64
  success_rate : Double
  cache_hit_rate : Double
}

///|
pub struct MoonstatAgentClient {
  id : String
  app_type : String
  protocol : String
  base_url : String
  primary_route : String
  setup_command : String?
  usage : String?
}

///|
pub struct MoonstatClient {
  base_url : String
  api_key : String?
  user_agent : String?
}

///|
pub fn MoonstatClient::new(
  base_url? : String = MOONSTAT_DEFAULT_CLIENT_BASE_URL,
  api_key? : String? = None,
  user_agent? : String? = None,
) -> MoonstatClient {
  {
    base_url: moonstat_client_normalize_base_url(base_url),
    api_key,
    user_agent,
  }
}

///|
pub fn MoonstatClient::from_host(
  host? : String = @suite.default_host(),
  port? : Int = @suite.default_port(),
  api_key? : String? = None,
  user_agent? : String? = None,
) -> MoonstatClient {
  MoonstatClient::new(
    base_url=@suite.base_url(host, port),
    api_key~,
    user_agent~,
  )
}

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
pub fn MoonstatClient::route_openclaw_chat_url(self : MoonstatClient) -> String {
  self.endpoint("/openclaw/v1/chat/completions")
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

///|
pub async fn MoonstatClient::health(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/health")
}

///|
pub async fn MoonstatClient::status(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/status")
}

///|
pub async fn MoonstatClient::stats(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/stats")
}

///|
pub async fn MoonstatClient::metrics(
  self : MoonstatClient,
) -> Result[String, String] {
  self.get_text_path("/metrics")
}

///|
pub async fn MoonstatClient::models(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/v1/models")
}

///|
pub async fn MoonstatClient::model_catalog(
  self : MoonstatClient,
) -> Result[Array[MoonstatModel], String] {
  match self.models() {
    Ok(json) => moonstat_models_from_json(json)
    Err(err) => Err(err)
  }
}

///|
pub async fn MoonstatClient::usage_logs(
  self : MoonstatClient,
  query? : MoonstatUsageQuery? = None,
) -> Result[Json, String] {
  self.get_json_path(moonstat_client_path_with_query("/usage/logs", query))
}

///|
pub async fn MoonstatClient::usage_summary(
  self : MoonstatClient,
  query? : MoonstatUsageQuery? = None,
) -> Result[Json, String] {
  self.get_json_path(moonstat_client_path_with_query("/usage/summary", query))
}

///|
pub async fn MoonstatClient::usage_summary_typed(
  self : MoonstatClient,
  query? : MoonstatUsageQuery? = None,
) -> Result[MoonstatUsageSummary, String] {
  match self.usage_summary(query~) {
    Ok(json) => MoonstatUsageSummary::from_json(json)
    Err(err) => Err(err)
  }
}

///|
pub async fn MoonstatClient::usage_summary_by_app(
  self : MoonstatClient,
  query? : MoonstatUsageQuery? = None,
) -> Result[Json, String] {
  self.get_json_path(
    moonstat_client_path_with_query("/usage/summary/by-app", query),
  )
}

///|
pub async fn MoonstatClient::usage_trends(
  self : MoonstatClient,
  query? : MoonstatUsageQuery? = None,
) -> Result[Json, String] {
  self.get_json_path(moonstat_client_path_with_query("/usage/trends", query))
}

///|
pub async fn MoonstatClient::usage_provider_limits(
  self : MoonstatClient,
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
    moonstat_client_path_with_query("/usage/provider-limits", Some(query)),
  )
}

///|
pub async fn MoonstatClient::usage_provider_usage(
  self : MoonstatClient,
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
    moonstat_client_path_with_query("/usage/provider-usage", Some(query)),
  )
}

///|
pub async fn MoonstatClient::usage_provider_stats(
  self : MoonstatClient,
  query? : MoonstatUsageQuery? = None,
) -> Result[Json, String] {
  self.get_json_path(
    moonstat_client_path_with_query("/usage/provider-stats", query),
  )
}

///|
pub async fn MoonstatClient::usage_model_stats(
  self : MoonstatClient,
  query? : MoonstatUsageQuery? = None,
) -> Result[Json, String] {
  self.get_json_path(
    moonstat_client_path_with_query("/usage/model-stats", query),
  )
}

///|
pub async fn MoonstatClient::usage_data_sources(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/usage/data-sources")
}

///|
pub async fn MoonstatClient::usage_model_pricing(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/usage/model-pricing")
}

///|
pub async fn MoonstatClient::usage_update_model_pricing(
  self : MoonstatClient,
  pricing : ModelPricing,
) -> Result[Json, String] {
  self.post_json_path("/usage/model-pricing", pricing.to_json())
}

///|
pub async fn MoonstatClient::usage_delete_model_pricing(
  self : MoonstatClient,
  model_id : String,
) -> Result[Json, String] {
  self.delete_json_path(
    "/usage/model-pricing?\{moonstat_client_query_pair("modelId", model_id)}",
  )
}

///|
pub async fn MoonstatClient::usage_sync_session(
  self : MoonstatClient,
  query? : MoonstatSessionSyncQuery? = None,
) -> Result[Json, String] {
  self.post_json_path(
    moonstat_client_session_sync_path_with_query("/usage/sync-session", query),
    Json::null(),
  )
}

///|
pub async fn MoonstatClient::usage_request_detail(
  self : MoonstatClient,
  request_id : String,
) -> Result[Json, String] {
  self.get_json_path("/usage/request-detail/\{copilot_url_encode(request_id)}")
}

///|
pub async fn MoonstatClient::proxy_status(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/status")
}

///|
pub async fn MoonstatClient::proxy_running(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/running")
}

///|
pub async fn MoonstatClient::proxy_global_config(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/global-config")
}

///|
pub async fn MoonstatClient::proxy_global_url(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/global-url")
}

///|
pub async fn MoonstatClient::proxy_upstream_status(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/upstream-status")
}

///|
pub async fn MoonstatClient::proxy_local_proxies(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/local-proxies")
}

///|
pub async fn MoonstatClient::proxy_app_config(
  self : MoonstatClient,
  app_type : String,
) -> Result[Json, String] {
  self.get_json_path(
    moonstat_client_path_with_pairs("/proxy/app-config", [("appType", app_type)]),
  )
}

///|
pub async fn MoonstatClient::proxy_default_cost_multiplier(
  self : MoonstatClient,
  app_type : String,
) -> Result[Json, String] {
  self.get_json_path(
    moonstat_client_path_with_pairs("/proxy/default-cost-multiplier", [
      ("appType", app_type),
    ]),
  )
}

///|
pub async fn MoonstatClient::proxy_pricing_model_source(
  self : MoonstatClient,
  app_type : String,
) -> Result[Json, String] {
  self.get_json_path(
    moonstat_client_path_with_pairs("/proxy/pricing-model-source", [
      ("appType", app_type),
    ]),
  )
}

///|
pub async fn MoonstatClient::proxy_circuit_breaker_config(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/circuit-breaker-config")
}

///|
pub async fn MoonstatClient::proxy_provider_health(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
  self.get_json_path(
    moonstat_client_proxy_provider_path(
      "/proxy/provider-health", app_type, provider_id,
    ),
  )
}

///|
pub async fn MoonstatClient::proxy_circuit_breaker_stats(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
  self.get_json_path(
    moonstat_client_proxy_provider_path(
      "/proxy/circuit-breaker-stats", app_type, provider_id,
    ),
  )
}

///|
pub async fn MoonstatClient::proxy_failover_queue(
  self : MoonstatClient,
  app_type : String,
) -> Result[Json, String] {
  self.get_json_path(
    moonstat_client_path_with_pairs("/proxy/failover-queue", [
      ("appType", app_type),
    ]),
  )
}

///|
pub async fn MoonstatClient::proxy_available_failover_providers(
  self : MoonstatClient,
  app_type : String,
) -> Result[Json, String] {
  self.get_json_path(
    moonstat_client_path_with_pairs("/proxy/available-failover-providers", [
      ("appType", app_type),
    ]),
  )
}

///|
pub async fn MoonstatClient::proxy_auto_failover_enabled(
  self : MoonstatClient,
  app_type : String,
) -> Result[Json, String] {
  self.get_json_path(
    moonstat_client_path_with_pairs("/proxy/auto-failover-enabled", [
      ("appType", app_type),
    ]),
  )
}

///|
pub async fn MoonstatClient::proxy_takeover_status(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.get_json_path("/proxy/takeover-status")
}

///|
pub async fn MoonstatClient::proxy_start(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.post_json_path("/proxy/start", Json::null())
}

///|
pub async fn MoonstatClient::proxy_stop(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.post_json_path("/proxy/stop", Json::null())
}

///|
pub async fn MoonstatClient::proxy_stop_with_restore(
  self : MoonstatClient,
) -> Result[Json, String] {
  self.post_json_path("/proxy/stop-with-restore", Json::null())
}

///|
pub async fn MoonstatClient::proxy_update_global_config(
  self : MoonstatClient,
  proxy_enabled? : String? = None,
  listen_address? : String? = None,
  listen_port? : String? = None,
  enable_logging? : String? = None,
) -> Result[Json, String] {
  self.post_json_path(
    moonstat_client_path_with_optional_pairs("/proxy/global-config", [
      ("proxyEnabled", proxy_enabled),
      ("listenAddress", listen_address),
      ("listenPort", listen_port),
      ("enableLogging", enable_logging),
    ]),
    Json::null(),
  )
}

///|
pub async fn MoonstatClient::proxy_set_global_url(
  self : MoonstatClient,
  url : String,
) -> Result[Json, String] {
  self.post_json_path(
    moonstat_client_path_with_pairs("/proxy/global-url", [("url", url)]),
    Json::null(),
  )
}

///|
pub async fn MoonstatClient::proxy_test_url(
  self : MoonstatClient,
  url : String,
) -> Result[Json, String] {
  self.post_json_path(
    moonstat_client_path_with_pairs("/proxy/test-url", [("url", url)]),
    Json::null(),
  )
}

///|
pub async fn MoonstatClient::proxy_update_app_config(
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
) -> Result[Json, String] {
  self.post_json_path(
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
    Json::null(),
  )
}

///|
pub async fn MoonstatClient::proxy_set_default_cost_multiplier(
  self : MoonstatClient,
  app_type : String,
  value : String,
) -> Result[Json, String] {
  self.post_json_path(
    moonstat_client_path_with_pairs("/proxy/default-cost-multiplier", [
      ("appType", app_type),
      ("value", value),
    ]),
    Json::null(),
  )
}

///|
pub async fn MoonstatClient::proxy_set_pricing_model_source(
  self : MoonstatClient,
  app_type : String,
  value : String,
) -> Result[Json, String] {
  self.post_json_path(
    moonstat_client_path_with_pairs("/proxy/pricing-model-source", [
      ("appType", app_type),
      ("value", value),
    ]),
    Json::null(),
  )
}

///|
pub async fn MoonstatClient::proxy_update_circuit_breaker_config(
  self : MoonstatClient,
  failure_threshold : String,
  success_threshold : String,
  timeout_seconds : String,
  error_rate_threshold : String,
  min_requests : String,
) -> Result[Json, String] {
  self.post_json_path(
    moonstat_client_path_with_pairs("/proxy/circuit-breaker-config", [
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
pub async fn MoonstatClient::proxy_reset_circuit_breaker(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
  self.post_json_path(
    moonstat_client_proxy_provider_path(
      "/proxy/reset-circuit-breaker", app_type, provider_id,
    ),
    Json::null(),
  )
}

///|
pub async fn MoonstatClient::proxy_add_failover_queue(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
  self.post_json_path(
    moonstat_client_proxy_provider_path(
      "/proxy/failover-queue", app_type, provider_id,
    ),
    Json::null(),
  )
}

///|
pub async fn MoonstatClient::proxy_remove_failover_queue(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
  self.delete_json_path(
    moonstat_client_proxy_provider_path(
      "/proxy/failover-queue", app_type, provider_id,
    ),
  )
}

///|
pub async fn MoonstatClient::proxy_set_auto_failover_enabled(
  self : MoonstatClient,
  app_type : String,
  enabled : String,
) -> Result[Json, String] {
  self.post_json_path(
    moonstat_client_path_with_pairs("/proxy/auto-failover-enabled", [
      ("appType", app_type),
      ("enabled", enabled),
    ]),
    Json::null(),
  )
}

///|
pub async fn MoonstatClient::proxy_set_takeover_status(
  self : MoonstatClient,
  app_type : String,
  enabled : String,
) -> Result[Json, String] {
  self.post_json_path(
    moonstat_client_path_with_pairs("/proxy/takeover-status", [
      ("appType", app_type),
      ("enabled", enabled),
    ]),
    Json::null(),
  )
}

///|
pub async fn MoonstatClient::proxy_switch_provider(
  self : MoonstatClient,
  app_type : String,
  provider_id : String,
) -> Result[Json, String] {
  self.post_json_path(
    moonstat_client_proxy_provider_path(
      "/proxy/switch-provider", app_type, provider_id,
    ),
    Json::null(),
  )
}

///|
pub async fn MoonstatClient::route_chat(
  self : MoonstatClient,
  request : Json,
) -> Result[Json, String] {
  self.post_json_path("/v1/chat/completions", request)
}

///|
pub async fn MoonstatClient::route_openclaw_chat(
  self : MoonstatClient,
  request : Json,
) -> Result[Json, String] {
  self.post_json_path("/openclaw/v1/chat/completions", request)
}

///|
pub async fn MoonstatClient::route_response(
  self : MoonstatClient,
  request : Json,
) -> Result[Json, String] {
  self.post_json_path("/v1/responses", request)
}

///|
pub async fn MoonstatClient::route_response_compact(
  self : MoonstatClient,
  request : Json,
) -> Result[Json, String] {
  self.post_json_path("/v1/responses/compact", request)
}

///|
pub async fn MoonstatClient::route_messages(
  self : MoonstatClient,
  request : Json,
) -> Result[Json, String] {
  self.post_json_path("/v1/messages", request)
}
