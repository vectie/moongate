///|
const MOONSTAT_DEFAULT_CLIENT_BASE_URL = "http://127.0.0.1:15721"

///|
pub struct MoonstatUsageQuery {
  start_date : String?
  end_date : String?
  app_type : String?
  provider_id : String?
  page : Int?
  page_size : Int?
}

///|
pub fn MoonstatUsageQuery::empty() -> MoonstatUsageQuery {
  {
    start_date: None,
    end_date: None,
    app_type: None,
    provider_id: None,
    page: None,
    page_size: None,
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
  {
    projects_dir: None,
    codex_dir: None,
    gemini_dir: None,
    opencode_export_path: None,
    opencode_db_path: None,
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
pub fn MoonstatClient::from_suite_status(
  status : Json,
  api_key? : String? = None,
  user_agent? : String? = None,
) -> MoonstatClient? {
  match moonstat_base_url_from_suite_status(status) {
    Some(base_url) =>
      Some(MoonstatClient::new(base_url~, api_key~, user_agent~))
    None => None
  }
}

///|
pub async fn MoonstatClient::discover(
  path? : String = default_moonstat_suite_status_path(),
  api_key? : String? = None,
  user_agent? : String? = None,
) -> MoonstatClient {
  let content = @fsx.read_file(path) catch { _ => "" }
  if !content.is_empty() {
    let parsed = @json.parse(content) catch { _ => Json::null() }
    match MoonstatClient::from_suite_status(parsed, api_key~, user_agent~) {
      Some(client) => return client
      None => ()
    }
  }
  MoonstatClient::new(api_key~, user_agent~)
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

///|
async fn MoonstatClient::get_json_path(
  self : MoonstatClient,
  path : String,
) -> Result[Json, String] {
  match self.get_text_path(path) {
    Ok(body) =>
      Ok(@json.parse(body)) catch {
        err => Err("Invalid JSON from moonstat: \{err}")
      }
    Err(err) => Err(err)
  }
}

///|
async fn MoonstatClient::post_json_path(
  self : MoonstatClient,
  path : String,
  request : Json,
) -> Result[Json, String] {
  let body = request.stringify()
  match self.request_text_path("POST", path, Some(body)) {
    Ok(body) =>
      Ok(@json.parse(body)) catch {
        err => Err("Invalid JSON from moonstat: \{err}")
      }
    Err(err) => Err(err)
  }
}

///|
async fn MoonstatClient::delete_json_path(
  self : MoonstatClient,
  path : String,
) -> Result[Json, String] {
  match self.request_text_path("DELETE", path, None) {
    Ok(body) =>
      Ok(@json.parse(body)) catch {
        err => Err("Invalid JSON from moonstat: \{err}")
      }
    Err(err) => Err(err)
  }
}

///|
async fn MoonstatClient::get_text_path(
  self : MoonstatClient,
  path : String,
) -> Result[String, String] {
  self.request_text_path("GET", path, None)
}

///|
async fn MoonstatClient::request_text_path(
  self : MoonstatClient,
  http_method : String,
  path : String,
  body : String?,
) -> Result[String, String] {
  let target = match models_url_target(self.endpoint(path)) {
    Ok(target) => target
    Err(err) => return Err(err)
  }
  let headers = self.headers(http_method)
  let client = @http.Client::new(target.origin, headers~)
  defer client.close()
  let response = match http_method {
    "GET" =>
      client.get(target.path) catch {
        err => return Err("Network error: \{err}")
      }
    "POST" =>
      client.post(target.path, body.unwrap_or("")) catch {
        err => return Err("Network error: \{err}")
      }
    "DELETE" =>
      client..request(Delete, target.path).end_request() catch {
        err => return Err("Network error: \{err}")
      }
    _ => return Err("Unsupported moonstat client method: \{http_method}")
  }
  let response_body = client.read_all().text()
  if response.code is (200..=299) {
    Ok(response_body)
  } else {
    Err(
      "Moonstat HTTP \{response.code}: \{truncate_model_fetch_error_body(response_body)}",
    )
  }
}

///|
fn MoonstatClient::headers(
  self : MoonstatClient,
  http_method : String,
) -> Map[String, String] {
  let headers : Map[String, String] = { "Accept": "application/json" }
  match self.api_key {
    Some(api_key) if !api_key.trim().is_empty() =>
      headers["Authorization"] = "Bearer \{api_key}"
    _ => ()
  }
  match self.user_agent {
    Some(user_agent) if !user_agent.trim().is_empty() =>
      headers["User-Agent"] = user_agent.trim().to_owned()
    _ => ()
  }
  if http_method == "POST" {
    headers["Content-Type"] = "application/json"
  }
  headers
}

///|
fn moonstat_client_normalize_base_url(base_url : String) -> String {
  let trimmed = trim_end_slashes(base_url.trim().to_owned())
  if trimmed.is_empty() {
    MOONSTAT_DEFAULT_CLIENT_BASE_URL
  } else {
    trimmed
  }
}

///|
fn moonstat_client_url(base_url : String, path : String) -> String {
  let normalized = moonstat_client_normalize_base_url(base_url)
  let path = if path.has_prefix("/") { path } else { "/\{path}" }
  "\{normalized}\{path}"
}

///|
fn moonstat_client_url_with_query(
  base_url : String,
  path : String,
  query : MoonstatUsageQuery?,
) -> String {
  moonstat_client_url(base_url, moonstat_client_path_with_query(path, query))
}

///|
fn moonstat_client_url_with_session_sync_query(
  base_url : String,
  path : String,
  query : MoonstatSessionSyncQuery?,
) -> String {
  moonstat_client_url(
    base_url,
    moonstat_client_session_sync_path_with_query(path, query),
  )
}

///|
fn moonstat_client_path_with_query(
  path : String,
  query : MoonstatUsageQuery?,
) -> String {
  match moonstat_usage_query_string(query) {
    Some(query_string) => "\{path}?\{query_string}"
    None => path
  }
}

///|
fn moonstat_client_session_sync_path_with_query(
  path : String,
  query : MoonstatSessionSyncQuery?,
) -> String {
  match moonstat_session_sync_query_string(query) {
    Some(query_string) => "\{path}?\{query_string}"
    None => path
  }
}

///|
fn moonstat_usage_query_string(query : MoonstatUsageQuery?) -> String? {
  guard query is Some(query) else { return None }
  let parts : Array[String] = []
  match query.start_date {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("startDate", value))
    _ => ()
  }
  match query.end_date {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("endDate", value))
    _ => ()
  }
  match query.app_type {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("appType", value))
    _ => ()
  }
  match query.provider_id {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("providerId", value))
    _ => ()
  }
  match query.page {
    Some(value) => parts.push(moonstat_client_query_pair("page", "\{value}"))
    None => ()
  }
  match query.page_size {
    Some(value) =>
      parts.push(moonstat_client_query_pair("pageSize", "\{value}"))
    None => ()
  }
  if parts.is_empty() {
    None
  } else {
    Some(parts.join("&"))
  }
}

///|
fn moonstat_session_sync_query_string(
  query : MoonstatSessionSyncQuery?,
) -> String? {
  guard query is Some(query) else { return None }
  let parts : Array[String] = []
  match query.projects_dir {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("projectsDir", value))
    _ => ()
  }
  match query.codex_dir {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("codexDir", value))
    _ => ()
  }
  match query.gemini_dir {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("geminiDir", value))
    _ => ()
  }
  match query.opencode_export_path {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("opencodeExportPath", value))
    _ => ()
  }
  match query.opencode_db_path {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("opencodeDbPath", value))
    _ => ()
  }
  if parts.is_empty() {
    None
  } else {
    Some(parts.join("&"))
  }
}

///|
fn moonstat_client_query_pair(key : String, value : String) -> String {
  "\{copilot_url_encode(key)}=\{copilot_url_encode(value)}"
}

///|
pub fn moonstat_models_from_json(
  json : Json,
) -> Result[Array[MoonstatModel], String] {
  let rows = match json {
    Object(obj) =>
      match obj.get("models") {
        Some(Array(models)) => models
        Some(Object(models)) => models.values().to_array()
        Some(_) => return Err("moonstat models field is not an array or object")
        None =>
          match obj.get("data") {
            Some(Array(models)) => models
            Some(_) => return Err("moonstat data field is not an array")
            None => return Err("moonstat models response has no models")
          }
      }
    Array(models) => models
    _ => return Err("moonstat models response is not an object or array")
  }
  let parsed : Array[MoonstatModel] = []
  for row in rows {
    match MoonstatModel::from_json(row) {
      Ok(model) => parsed.push(model)
      Err(err) => return Err(err)
    }
  }
  Ok(parsed)
}

///|
pub fn MoonstatModel::from_json(json : Json) -> Result[MoonstatModel, String] {
  let obj = match json {
    Object(obj) => obj
    _ => return Err("moonstat model entry is not an object")
  }
  let id = match moonstat_json_string_field(obj, "id") {
    Some(value) => value
    None =>
      match moonstat_json_string_field(obj, "slug") {
        Some(value) => value
        None =>
          match moonstat_json_string_field(obj, "name") {
            Some(value) => value
            None => return Err("moonstat model entry has no id")
          }
      }
  }
  Ok({
    id,
    owner: moonstat_json_string_field(obj, "owned_by"),
    context_window: moonstat_json_int_field(obj, "context_window"),
  })
}

///|
pub fn MoonstatUsageSummary::from_json(
  json : Json,
) -> Result[MoonstatUsageSummary, String] {
  let obj = match json {
    Object(obj) => obj
    _ => return Err("moonstat usage summary is not an object")
  }
  Ok({
    total_requests: moonstat_json_int_field(obj, "totalRequests").unwrap_or(0),
    total_cost: moonstat_json_string_field(obj, "totalCost").unwrap_or("0"),
    total_input_tokens: moonstat_json_int64_field(obj, "totalInputTokens").unwrap_or(
      0L,
    ),
    total_output_tokens: moonstat_json_int64_field(obj, "totalOutputTokens").unwrap_or(
      0L,
    ),
    total_cache_creation_tokens: moonstat_json_int64_field(
      obj, "totalCacheCreationTokens",
    ).unwrap_or(0L),
    total_cache_read_tokens: moonstat_json_int64_field(
      obj, "totalCacheReadTokens",
    ).unwrap_or(0L),
    real_total_tokens: moonstat_json_int64_field(obj, "realTotalTokens").unwrap_or(
      0L,
    ),
    success_rate: moonstat_json_double_field(obj, "successRate").unwrap_or(0.0),
    cache_hit_rate: moonstat_json_double_field(obj, "cacheHitRate").unwrap_or(
      0.0,
    ),
  })
}

///|
fn moonstat_json_string_field(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(value)) if !value.trim().is_empty() => Some(value)
    _ => None
  }
}

///|
fn moonstat_json_double_field(obj : Map[String, Json], key : String) -> Double? {
  match obj.get(key) {
    Some(Number(value, ..)) => Some(value)
    _ => None
  }
}

///|
fn moonstat_json_int_field(obj : Map[String, Json], key : String) -> Int? {
  match moonstat_json_double_field(obj, key) {
    Some(value) => Some(value.trunc().to_int())
    None => None
  }
}

///|
fn moonstat_json_int64_field(obj : Map[String, Json], key : String) -> Int64? {
  match moonstat_json_double_field(obj, key) {
    Some(value) => Some(value.trunc().to_int64())
    None => None
  }
}

///|
pub fn moonstat_base_url_from_suite_status(status : Json) -> String? {
  match status {
    Object(obj) if moonstat_suite_status_contract_valid(obj) =>
      moonstat_base_url_from_suite_status_object(obj)
    _ => None
  }
}

///|
fn moonstat_suite_status_contract_valid(obj : Map[String, Json]) -> Bool {
  moonstat_json_string_field(obj, "contract") == Some(@suite.status_contract()) &&
  moonstat_json_string_field(obj, "service") == Some(@suite.service_name())
}

///|
fn moonstat_base_url_from_suite_status_object(
  obj : Map[String, Json],
) -> String? {
  match obj.get("manifest") {
    Some(Object(manifest)) if moonstat_suite_manifest_contract_valid(manifest) =>
      moonstat_base_url_from_json_object(manifest)
    _ => None
  }
}

///|
fn moonstat_suite_manifest_contract_valid(obj : Map[String, Json]) -> Bool {
  moonstat_json_string_field(obj, "contract") ==
  Some(@suite.manifest_contract()) &&
  moonstat_json_string_field(obj, "service") == Some(@suite.service_name())
}

///|
fn moonstat_base_url_from_json_object(obj : Map[String, Json]) -> String? {
  match obj.get("base_url") {
    Some(String(url)) if !url.trim().is_empty() =>
      Some(moonstat_client_normalize_base_url(url))
    _ => None
  }
}
