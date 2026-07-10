///|
fn UsageService::stats_json(self : UsageService) -> Json {
  self.stats.to_json()
}

///|
fn UsageService::health_json(
  self : UsageService,
  credentials_loaded : Bool,
) -> Json {
  {
    "status": Json::string(
      if self.stats.storage_healthy {
        "healthy"
      } else {
        "degraded"
      },
    ),
    "timestamp": Json::string(@async.now().to_string()),
    "credentials_loaded": Json::boolean(credentials_loaded),
    "stats": self.stats_json(),
    "storage": self.stats.storage_health_json(),
  }.to_json()
}

///|
fn UsageService::metrics_text(
  self : UsageService,
  provider_metrics? : String = "",
) -> String {
  if provider_metrics.is_empty() {
    self.stats.prometheus_metrics()
  } else {
    "\{self.stats.prometheus_metrics()}\n\{provider_metrics}"
  }
}

///|
fn UsageService::status_json(
  self : UsageService,
  address : String,
  port : Int,
  uptime_seconds : Int,
  running? : Bool = true,
  provider_routes? : Json? = None,
) -> Json {
  self.stats.status_json(
    address,
    port,
    uptime_seconds,
    running~,
    provider_routes~,
  )
}

///|
priv struct UsageRequest {
  service : UsageService
  context : UsageRequestContext
}

///|
fn UsageService::begin_request(
  self : UsageService,
  request_bytes : Int,
) -> UsageRequest {
  { service: self, context: self.stats.begin_request(request_bytes) }
}

///|
fn UsageRequest::first_stream_event_ms(
  self : UsageRequest,
  current : Int?,
) -> Int? {
  moon_first_stream_event_ms(current, Some(self.context.started_at_ms))
}

///|
fn UsageService::set_active_target(
  self : UsageService,
  app_type : String,
  provider_id : String,
  provider_name : String,
) -> Unit {
  self.stats.set_active_target(app_type, provider_id, provider_name)
}

///|
priv struct ProviderUsageContext {
  app_type : String
  provider_id : String
  used_half_open_permit : Bool
}

///|
fn UsageRequest::activate_provider_target(
  self : UsageRequest,
  app_type : String,
  provider_id : String,
  provider_name : String,
  used_half_open_permit? : Bool = false,
  cost_multiplier? : String = "1.0",
  pricing_model_source? : String = "response",
) -> Unit {
  self.context.set_active_target(
    app_type,
    provider_id,
    provider_name,
    used_half_open_permit~,
    cost_multiplier~,
    pricing_model_source~,
  )
  self.service.stats.set_active_target(app_type, provider_id, provider_name)
}

///|
fn UsageRequest::provider_request_context(
  self : UsageRequest,
) -> ProviderUsageContext? {
  guard self.context.app_type is Some(app_type) else { return None }
  guard self.context.provider_id is Some(provider_id) else { return None }
  Some({
    app_type,
    provider_id,
    used_half_open_permit: self.context.used_half_open_permit,
  })
}

///|
fn UsageRequest::current_provider_id(self : UsageRequest) -> String? {
  self.context.provider_id
}

///|
fn UsageRequest::set_last_error(self : UsageRequest, error : String) -> Unit {
  self.service.stats.last_error = Some(error)
}

///|
fn UsageService::set_provider_limits(
  self : UsageService,
  provider_id : String,
  app_type : String,
  daily_limit_usd? : String? = None,
  monthly_limit_usd? : String? = None,
) -> Unit {
  self.stats.set_provider_limits(
    provider_id,
    app_type,
    daily_limit_usd~,
    monthly_limit_usd~,
  )
}

///|
fn UsageService::pricing_override_rows(
  self : UsageService,
) -> Array[ModelPricing] {
  let rows : Array[ModelPricing] = []
  for model_id in self.pricing_overrides.keys() {
    guard self.pricing_overrides.get(model_id) is Some(pricing) else {
      continue
    }
    rows.push(pricing)
  }
  rows
}

///|
fn UsageService::model_pricing_json(self : UsageService) -> Json {
  model_pricing_json(
    self.pricing_override_rows(),
    self.pricing_deleted_model_ids,
  )
}

///|
async fn UsageService::upsert_model_pricing(
  self : UsageService,
  pricing : ModelPricing,
) -> Int {
  self.pricing_overrides.set(pricing.model_id, pricing)
  self.pricing_deleted_model_ids.set(pricing.model_id, false)
  let backfilled = self.stats.backfill_missing_usage_costs_for_model(
    pricing.model_id,
    self.pricing_override_rows(),
    self.pricing_deleted_model_ids,
  )
  self.stats.save_persistent_store()
  backfilled
}

///|
fn UsageService::delete_model_pricing(
  self : UsageService,
  model_id : String,
) -> Unit {
  self.pricing_deleted_model_ids.set(model_id, true)
}

///|
async fn UsageService::load_model_pricing_store(self : UsageService) -> Unit {
  let path = @pathx.join(
    default_moonstat_stats_dir(),
    MOONSTAT_MODEL_PRICING_FILE,
  )
  if !@fsx.exists_as_file(path) {
    return
  }
  let content = @fsx.read_file(path) catch { _ => return }
  for line_view in content.split("\n") {
    let line = line_view.to_owned().trim()
    if line.is_empty() {
      continue
    }
    let parsed = @json.parse(line) catch { _ => continue }
    guard parsed is Object(obj) else { continue }
    guard store_json_string(obj, "modelId") is Some(model_id) else { continue }
    if store_json_bool_or_false(obj, "deleted") {
      self.pricing_deleted_model_ids.set(model_id, true)
    } else {
      match model_pricing_from_store_json(obj) {
        Some(pricing) => {
          self.pricing_overrides.set(pricing.model_id, pricing)
          self.pricing_deleted_model_ids.set(model_id, false)
        }
        None => ()
      }
    }
  }
}

///|
async fn UsageService::save_model_pricing_store(self : UsageService) -> Unit {
  let storage_dir = default_moonstat_stats_dir()
  @fsx.make_directory(storage_dir, recursive=true, exists_ok=true) catch {
    _ => return
  }
  let lines : Array[String] = []
  for pricing in self.pricing_override_rows() {
    if model_pricing_is_deleted(
        pricing.model_id,
        self.pricing_deleted_model_ids,
      ) {
      continue
    }
    lines.push(model_pricing_store_json(pricing, deleted=false).stringify())
  }
  for model_id in self.pricing_deleted_model_ids.keys() {
    if !self.pricing_deleted_model_ids.get(model_id).unwrap_or(false) {
      continue
    }
    lines.push(
      { "modelId": Json::string(model_id), "deleted": Json::boolean(true) }
      .to_json()
      .stringify(),
    )
  }
  @fsx.write_to_file(
    @pathx.join(storage_dir, MOONSTAT_MODEL_PRICING_FILE),
    lines.join("\n"),
  ) catch {
    _ => ()
  }
}

///|
async fn UsageService::handle_usage_model_pricing(
  self : UsageService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.model_pricing_json())
}

///|
async fn UsageService::handle_usage_update_model_pricing(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  match usage_pricing_validation_error_from_request(r.path, body) {
    Some(error) => {
      write_usage_bad_request(w, error)
      return
    }
    None => ()
  }
  guard usage_pricing_from_request(r.path, body) is Some(pricing) else {
    write_usage_bad_request(w, "invalid_model_pricing")
    return
  }
  let _backfilled = self.upsert_model_pricing(pricing)
  self.save_model_pricing_store()
  write_usage_json(w, Json::null())
}

///|
async fn UsageService::handle_usage_delete_model_pricing(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard usage_string_from_request(r.path, body, "modelId") is Some(model_id) else {
    write_usage_bad_request(w, "missing_model_id")
    return
  }
  let trimmed = model_id.trim().to_owned()
  if trimmed.is_empty() {
    write_usage_bad_request(w, "missing_model_id")
    return
  }
  self.delete_model_pricing(trimmed)
  self.save_model_pricing_store()
  write_usage_json(w, Json::null())
}

///|
fn UsageRequest::record_request_context(
  self : UsageRequest,
  app_type : String,
  model : String,
  outbound_model? : String? = None,
  session_id? : String? = None,
  provider_type? : String? = None,
) -> Unit {
  self.context.set_request_context(
    app_type,
    model,
    outbound_model~,
    session_id~,
    provider_type~,
  )
}

///|
fn UsageRequest::record_stream_mode(self : UsageRequest, stream : Bool) -> Unit {
  self.service.stats.record_stream_mode(self.context, stream)
}

///|
fn UsageRequest::record_provider_result(
  self : UsageRequest,
  proxy : ProxyService,
  success : Bool,
) -> Unit {
  guard self.provider_request_context() is Some(context) else { return }
  proxy.provider_router.record_result(
    context.provider_id,
    context.app_type,
    context.used_half_open_permit,
    success,
  )
}

///|
fn UsageRequest::release_provider_permit_neutral(
  self : UsageRequest,
  proxy : ProxyService,
) -> Unit {
  guard self.provider_request_context() is Some(context) else { return }
  proxy.provider_router.release_permit_neutral(
    context.provider_id,
    context.app_type,
    context.used_half_open_permit,
  )
}

///|
fn UsageRequest::finish_neutral(
  self : UsageRequest,
  proxy : ProxyService,
) -> Unit {
  self.release_provider_permit_neutral(proxy)
  self.finish()
}

///|
fn UsageRequest::finish(self : UsageRequest) -> Unit {
  self.service.stats.finish_request(self.context)
}

///|
async fn UsageRequest::record_success_usage_with_provider(
  self : UsageRequest,
  proxy : ProxyService,
  usage : TokenUsage,
  response_bytes : Int,
) -> Unit {
  self.record_provider_result(proxy, true)
  self.record_success_usage(
    usage,
    response_bytes,
    self.service.pricing_override_rows(),
  )
}

///|
async fn UsageRequest::record_success_stream_usage_with_provider(
  self : UsageRequest,
  proxy : ProxyService,
  usage : TokenUsage?,
  response_bytes : Int,
  record_provider? : Bool = true,
  first_token_ms? : Int? = None,
  skip_empty_usage? : Bool = false,
) -> Unit {
  if record_provider {
    self.record_provider_result(proxy, true)
  }
  self.record_success_stream_usage(
    usage,
    response_bytes,
    self.service.pricing_override_rows(),
    first_token_ms~,
    skip_empty_usage~,
  )
}

///|
async fn UsageRequest::record_success_usage(
  self : UsageRequest,
  usage : TokenUsage,
  response_bytes : Int,
  pricing_overrides : Array[ModelPricing],
) -> Unit {
  self.service.stats.record_success_usage_with_pricing(
    self.context,
    usage,
    response_bytes,
    pricing_overrides,
    self.service.pricing_deleted_model_ids,
  )
  self.service.stats.save_persistent_store()
}

///|
async fn UsageRequest::record_success_stream_usage(
  self : UsageRequest,
  usage : TokenUsage?,
  response_bytes : Int,
  pricing_overrides : Array[ModelPricing],
  first_token_ms? : Int? = None,
  skip_empty_usage? : Bool = false,
) -> Unit {
  if skip_empty_usage {
    match usage {
      Some(usage) if usage.has_billable_tokens() => ()
      _ => {
        self.service.stats.record_success_without_usage_log(
          self.context,
          response_bytes,
        )
        self.service.stats.save_persistent_store()
        return
      }
    }
  }
  self.service.stats.record_success_usage_with_pricing(
    self.context,
    usage.unwrap_or(TokenUsage::empty()),
    response_bytes,
    pricing_overrides,
    self.service.pricing_deleted_model_ids,
    first_token_ms~,
  )
  self.service.stats.save_persistent_store()
}

///|
async fn UsageRequest::record_bad_request(self : UsageRequest) -> Unit {
  self.service.stats.record_bad_request(self.context)
  self.service.stats.save_persistent_store()
}

///|
async fn UsageRequest::record_bad_request_with_provider(
  self : UsageRequest,
  proxy : ProxyService,
) -> Unit {
  self.release_provider_permit_neutral(proxy)
  self.record_bad_request()
}

///|
async fn UsageRequest::record_unauthorized(self : UsageRequest) -> Unit {
  self.service.stats.record_unauthorized(self.context)
  self.service.stats.save_persistent_store()
}

///|
async fn UsageRequest::record_unauthorized_with_provider(
  self : UsageRequest,
  proxy : ProxyService,
) -> Unit {
  self.release_provider_permit_neutral(proxy)
  self.record_unauthorized()
}

///|
async fn UsageRequest::record_upstream_error_status(
  self : UsageRequest,
  response_bytes : Int,
  status_code : Int,
) -> Unit {
  self.service.stats.record_upstream_error_status(
    self.context,
    response_bytes,
    status_code,
  )
  self.service.stats.save_persistent_store()
}

///|
async fn UsageRequest::record_upstream_error_status_with_provider(
  self : UsageRequest,
  proxy : ProxyService,
  response_bytes : Int,
  status_code : Int,
) -> Unit {
  if moon_upstream_status_retryable(status_code) {
    self.record_provider_result(proxy, false)
  } else {
    self.release_provider_permit_neutral(proxy)
  }
  self.record_upstream_error_status(response_bytes, status_code)
}

///|
async fn UsageRequest::write_provider_selection_error(
  self : UsageRequest,
  proxy : ProxyService,
  app_type : String,
  error : ProviderSelectionError,
  w : @httpx.ResponseWriter,
) -> Unit {
  let status_code = provider_selection_error_status(error)
  let body = provider_selection_error_json(error, app_type).stringify()
  self.record_upstream_error_status_with_provider(
    proxy,
    body.length(),
    status_code,
  )
  self.set_last_error(error.to_string())
  w.header().set("Content-Type", "application/json")
  w.write_header(status_code)
  w.write(body)
  w.flush()
}

///|
async fn UsageRequest::record_internal_error(self : UsageRequest) -> Unit {
  self.service.stats.record_internal_error(self.context)
  self.service.stats.save_persistent_store()
}

///|
async fn UsageRequest::record_internal_error_with_provider(
  self : UsageRequest,
  proxy : ProxyService,
) -> Unit {
  self.release_provider_permit_neutral(proxy)
  self.record_internal_error()
}

///|
async fn UsageService::load_and_reconcile_persistent_store(
  self : UsageService,
  pricing_overrides : Array[ModelPricing],
  storage_dir? : String = default_moonstat_stats_dir(),
) -> (Int, Int) {
  self.stats.load_persistent_store(storage_dir~)
  let backfilled = self.stats.backfill_missing_usage_costs(
    pricing_overrides,
    self.pricing_deleted_model_ids,
  )
  let pruned = self.stats.rollup_and_prune()
  if backfilled > 0 || pruned > 0 {
    self.stats.save_persistent_store()
  }
  (backfilled, pruned)
}

///|
async fn UsageService::usage_logs_json(
  self : UsageService,
  filters : RequestLogFilters,
  page : Int,
  page_size : Int,
  pricing_overrides : Array[ModelPricing],
) -> Json {
  let backfilled = self.stats.backfill_missing_usage_costs(
    pricing_overrides,
    self.pricing_deleted_model_ids,
  )
  if backfilled > 0 {
    self.stats.save_persistent_store()
  }
  self.stats.usage_logs_paginated_json(
    filters,
    page~,
    page_size~,
    pricing_overrides~,
    deleted_model_ids=self.pricing_deleted_model_ids,
  )
}

///|
fn UsageService::summary_json(
  self : UsageService,
  start_date? : Int? = None,
  end_date? : Int? = None,
  app_type? : String? = None,
) -> Json {
  self.stats.usage_summary_filtered_json(start_date~, end_date~, app_type~)
}

///|
fn UsageService::summary_by_app_json(
  self : UsageService,
  start_date? : Int? = None,
  end_date? : Int? = None,
) -> Json {
  self.stats.usage_summary_by_app_filtered_json(start_date~, end_date~)
}

///|
fn UsageService::trends_json(
  self : UsageService,
  start_ts? : Int? = None,
  end_ts? : Int? = None,
  app_type? : String? = None,
) -> Json {
  self.stats.usage_trends_json(start_ts~, end_ts~, app_type~)
}

///|
fn UsageService::provider_limit_status_json(
  self : UsageService,
  provider_id : String,
  app_type : String,
  daily_limit_usd? : String? = None,
  monthly_limit_usd? : String? = None,
) -> Json {
  self.stats.provider_limit_status_json(
    provider_id,
    app_type,
    daily_limit_usd~,
    monthly_limit_usd~,
  )
}

///|
fn UsageService::provider_stats_json(
  self : UsageService,
  start_date? : Int? = None,
  end_date? : Int? = None,
  app_type? : String? = None,
) -> Json {
  self.stats.provider_stats_filtered_json(start_date~, end_date~, app_type~)
}

///|
fn UsageService::model_stats_json(
  self : UsageService,
  start_date? : Int? = None,
  end_date? : Int? = None,
  app_type? : String? = None,
) -> Json {
  self.stats.model_stats_filtered_json(start_date~, end_date~, app_type~)
}

///|
fn UsageService::data_sources_json(self : UsageService) -> Json {
  self.stats.usage_data_sources_json()
}

///|
async fn UsageService::sync_session_logs(
  self : UsageService,
  claude_projects_dir : String,
  codex_dir : String,
  gemini_dir : String,
  opencode_db_path : String,
  opencode_export_path : String,
) -> SessionSyncResult {
  let result = self.stats.sync_session_logs(
    claude_projects_dir~,
    codex_dir~,
    gemini_dir~,
    opencode_db_path~,
    opencode_export_path~,
  )
  self.stats.save_persistent_store()
  result
}

///|
async fn UsageService::request_detail_json(
  self : UsageService,
  request_id : String,
  pricing_overrides : Array[ModelPricing],
) -> Json {
  let backfilled = self.stats.backfill_missing_usage_costs(
    pricing_overrides,
    self.pricing_deleted_model_ids,
  )
  if backfilled > 0 {
    self.stats.save_persistent_store()
  }
  match
    self.stats.request_detail_json_with_pricing(
      request_id,
      pricing_overrides,
      self.pricing_deleted_model_ids,
    ) {
    Some(detail) => detail
    None => Json::null()
  }
}

///|
async fn UsageService::handle_stats(
  self : UsageService,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(self.stats_json().stringify(indent=2))
  w.flush()
}

///|
async fn UsageService::handle_health(
  self : UsageService,
  w : @httpx.ResponseWriter,
  credentials_loaded : Bool,
) -> Unit {
  write_usage_json(w, self.health_json(credentials_loaded))
}

///|
async fn UsageService::handle_status(
  self : UsageService,
  w : @httpx.ResponseWriter,
  address : String,
  port : Int,
  uptime_seconds : Int,
  provider_routes? : Json? = None,
) -> Unit {
  write_usage_json(
    w,
    self.status_json(address, port, uptime_seconds, provider_routes~),
  )
}

///|
async fn UsageService::handle_metrics(
  self : UsageService,
  w : @httpx.ResponseWriter,
  provider_metrics? : String = "",
) -> Unit {
  w.header().set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
  w.write_header(@status.Ok)
  w.write(self.metrics_text(provider_metrics~))
  w.flush()
}

///|
async fn UsageService::handle_usage_logs(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  pricing_overrides : Array[ModelPricing],
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  let body = proxy_json_body(r)
  let filters = usage_request_log_filters_from_request(r.path, body)
  w.write(
    self
    .usage_logs_json(
      filters,
      usage_int_from_request(r.path, body, "page").unwrap_or(0),
      usage_int_from_request(r.path, body, "pageSize").unwrap_or(20),
      pricing_overrides,
    )
    .stringify(indent=2),
  )
  w.flush()
}

///|
async fn UsageService::handle_usage_summary(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    self.summary_json(
      start_date=usage_int_from_request(r.path, body, "startDate"),
      end_date=usage_int_from_request(r.path, body, "endDate"),
      app_type=usage_string_from_request(r.path, body, "appType"),
    ),
  )
}

///|
async fn UsageService::handle_usage_summary_by_app(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    self.summary_by_app_json(
      start_date=usage_int_from_request(r.path, body, "startDate"),
      end_date=usage_int_from_request(r.path, body, "endDate"),
    ),
  )
}

///|
async fn UsageService::handle_usage_trends(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let start_ts = usage_int_from_request(r.path, body, "startDate")
  let end_ts = usage_int_from_request(r.path, body, "endDate")
  let app_type = usage_string_from_request(r.path, body, "appType")
  write_usage_json(w, self.trends_json(start_ts~, end_ts~, app_type~))
}

///|
async fn UsageService::handle_usage_provider_stats(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    self.provider_stats_json(
      start_date=usage_int_from_request(r.path, body, "startDate"),
      end_date=usage_int_from_request(r.path, body, "endDate"),
      app_type=usage_string_from_request(r.path, body, "appType"),
    ),
  )
}

///|
async fn UsageService::handle_usage_model_stats(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    self.model_stats_json(
      start_date=usage_int_from_request(r.path, body, "startDate"),
      end_date=usage_int_from_request(r.path, body, "endDate"),
      app_type=usage_string_from_request(r.path, body, "appType"),
    ),
  )
}

///|
async fn UsageService::handle_usage_data_sources(
  self : UsageService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.data_sources_json())
}

///|
async fn UsageService::handle_usage_sync_session(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let claude_projects_dir = usage_query_value(r.path, "projectsDir").unwrap_or(
    default_claude_projects_dir(),
  )
  let codex_dir = usage_query_value(r.path, "codexDir").unwrap_or(
    default_codex_config_dir(),
  )
  let gemini_dir = usage_query_value(r.path, "geminiDir").unwrap_or(
    default_gemini_dir(),
  )
  let opencode_export_path = usage_query_value(r.path, "opencodeExportPath").unwrap_or(
    default_opencode_export_path(),
  )
  let opencode_db_path = usage_query_value(r.path, "opencodeDbPath").unwrap_or(
    default_opencode_db_path(),
  )
  let result = self.sync_session_logs(
    claude_projects_dir, codex_dir, gemini_dir, opencode_db_path, opencode_export_path,
  )
  write_usage_json(w, result.to_json())
}

///|
async fn UsageService::handle_usage_request_detail(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  pricing_overrides : Array[ModelPricing],
) -> Unit {
  let body = proxy_json_body(r)
  let request_id = usage_request_detail_id_from_request(r.path, body)
  write_usage_json(w, self.request_detail_json(request_id, pricing_overrides))
}

///|
async fn UsageService::handle_usage_provider_limits(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  provider_router : ProviderRouter,
) -> Unit {
  let body = proxy_json_body(r)
  guard usage_string_from_request(r.path, body, "providerId")
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard usage_string_from_request(r.path, body, "appType") is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  let daily_limit_usd = usage_string_from_request(r.path, body, "dailyLimitUsd")
  let monthly_limit_usd = usage_string_from_request(
    r.path,
    body,
    "monthlyLimitUsd",
  )
  let provider_limits = usage_provider_limit_config_for_provider(
    provider_router, provider_id, app_type,
  )
  let daily_limit_usd = usage_limit_override_or_provider_limit(
    daily_limit_usd,
    provider_limits.map(fn(config) { config.daily_limit_usd }),
  )
  let monthly_limit_usd = usage_limit_override_or_provider_limit(
    monthly_limit_usd,
    provider_limits.map(fn(config) { config.monthly_limit_usd }),
  )
  write_usage_json(
    w,
    self.provider_limit_status_json(
      provider_id,
      app_type,
      daily_limit_usd~,
      monthly_limit_usd~,
    ),
  )
}

///|
fn usage_provider_limit_config_for_provider(
  provider_router : ProviderRouter,
  provider_id : String,
  app_type : String,
) -> ProviderLimitConfig? {
  guard provider_router.provider_by_id(app_type, provider_id) is Some(provider) else {
    return None
  }
  provider_limit_config_from_settings(provider.settings_config)
}

///|
async fn UsageService::handle_query_provider_usage(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  provider_router : ProviderRouter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = body
  guard proxy_string_request(r.path, config, "providerId") is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard proxy_string_request(r.path, config, "appType") is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  write_usage_json(
    w,
    self
    .query_provider_usage_standalone(app_type, provider_id, provider_router)
    .to_json(),
  )
}

///|
async fn UsageService::query_provider_usage_standalone(
  self : UsageService,
  app_type : String,
  provider_id : String,
  provider_router : ProviderRouter,
) -> UsageResult {
  match self.usage_cache.get_script(app_type, provider_id) {
    Some(result) => return result
    None => ()
  }
  match provider_router.provider_by_id(app_type, provider_id) {
    Some(provider) =>
      match moon_provider_balance_query_credentials(provider) {
        Some((base_url, api_key)) => return moon_get_balance(base_url, api_key)
        None => ()
      }
    None => ()
  }
  UsageResult::new(false, error=Some("Usage query is disabled"))
}

///|
async fn UsageService::handle_get_balance(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "baseUrl") is Some(base_url) else {
    write_usage_bad_request(w, "missing_base_url")
    return
  }
  guard proxy_string_request(r.path, body, "apiKey") is Some(api_key) else {
    write_usage_bad_request(w, "missing_api_key")
    return
  }
  write_usage_json(w, moon_get_balance(base_url, api_key).to_json())
}

///|
async fn UsageService::handle_get_subscription_quota(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "tool") is Some(tool) else {
    write_usage_bad_request(w, "missing_tool")
    return
  }
  let quota = moon_get_subscription_quota(tool)
  self.usage_cache.put_subscription(quota.tool, quota)
  write_usage_json(w, quota.to_json())
}

///|
async fn UsageService::handle_get_coding_plan_quota(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "baseUrl") is Some(base_url) else {
    write_usage_bad_request(w, "missing_base_url")
    return
  }
  guard proxy_string_request(r.path, body, "apiKey") is Some(api_key) else {
    write_usage_bad_request(w, "missing_api_key")
    return
  }
  let quota = moon_get_coding_plan_quota(
    base_url,
    api_key,
    coding_plan_provider=proxy_string_request(
      r.path,
      body,
      "codingPlanProvider",
    ),
    team_organization_id=proxy_string_request(
      r.path,
      body,
      "teamOrganizationId",
    ),
    team_project_id=proxy_string_request(r.path, body, "teamProjectId"),
  )
  self.usage_cache.put_subscription(quota.tool, quota)
  write_usage_json(w, quota.to_json())
}

///|
async fn UsageService::handle_test_usage_script(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = body
  guard proxy_string_request(r.path, config, "providerId") is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard proxy_string_request(r.path, config, "appType") is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  let result = match usage_result_from_request(r.path, body) {
    Some(result) => result
    None =>
      match test_usage_script_template_result(r.path, body) {
        Some(result) => result
        None =>
          UsageResult::new(
            false,
            error=Some(
              "Usage script execution is unavailable in standalone Moonstat; provide a Moonstat UsageResult JSON object as result or scriptCode.",
            ),
          )
      }
  }
  self.usage_cache.put_script(app_type, provider_id, result)
  write_usage_json(w, result.to_json())
}

///|
async fn write_usage_json(w : @httpx.ResponseWriter, body : Json) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(body.stringify(indent=2))
  w.flush()
}

///|
async fn write_usage_bad_request(
  w : @httpx.ResponseWriter,
  error : String,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.BadRequest)
  w.write({ "error": Json::string(error) }.to_json().stringify(indent=2))
  w.flush()
}

///|
fn usage_request_detail_id(path : String) -> String {
  match usage_query_value(path, "requestId") {
    Some(request_id) => return request_id
    None => ()
  }
  let prefix = "/usage/request-detail/"
  let raw = if path.has_prefix(prefix) {
    path[prefix.length():].to_owned()
  } else {
    path
  }
  let without_query = match raw.find("?") {
    Some(question_index) => raw[:question_index].to_owned()
    None => raw
  }
  usage_url_decode(without_query[:])
}

///|
fn usage_request_detail_id_from_request(
  path : StringView,
  body : Json?,
) -> String {
  match usage_string_from_request(path, body, "requestId") {
    Some(request_id) => request_id
    None => usage_request_detail_id(path.to_owned())
  }
}

///|
fn usage_limit_override_or_provider_limit(
  explicit_limit : String?,
  provider_limit : String??,
) -> String? {
  match explicit_limit {
    Some(value) => Some(value)
    None =>
      match provider_limit {
        Some(Some(value)) => Some(value)
        _ => None
      }
  }
}

///|
fn usage_request_log_filters_from_request(
  path : StringView,
  body : Json?,
) -> RequestLogFilters {
  let filter_body = usage_filter_body(body)
  RequestLogFilters::new(
    app_type=usage_string_from_request(path, filter_body, "appType"),
    provider_name=usage_string_from_request(path, filter_body, "providerName"),
    model=usage_string_from_request(path, filter_body, "model"),
    status_code=usage_int_from_request(path, filter_body, "statusCode"),
    start_date=usage_int_from_request(path, filter_body, "startDate"),
    end_date=usage_int_from_request(path, filter_body, "endDate"),
  )
}

///|
fn usage_filter_body(body : Json?) -> Json? {
  match body {
    Some(Object(obj)) =>
      match obj.get("filters") {
        Some(Object(filters)) => Some(Json::object(filters))
        _ => body
      }
    _ => body
  }
}

///|
fn usage_string_from_request(
  path : StringView,
  body : Json?,
  key : String,
) -> String? {
  match usage_query_value(path, key) {
    Some(value) => return Some(value)
    None => ()
  }
  match body {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(String(value)) if !value.is_empty() => Some(value)
        Some(Number(value, ..)) => Some(value.to_string())
        _ => None
      }
    _ => None
  }
}

///|
fn usage_int_from_request(
  path : StringView,
  body : Json?,
  key : String,
) -> Int? {
  match usage_query_value(path, key) {
    Some(value) =>
      try @string.parse_int(value, base=10) catch {
        _ => ()
      } noraise {
        parsed => return Some(parsed)
      }
    None => ()
  }
  match body {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Number(value, ..)) => Some(value.trunc().to_int())
        Some(String(value)) =>
          try @string.parse_int(value, base=10) catch {
            _ => None
          } noraise {
            parsed => Some(parsed)
          }
        _ => None
      }
    _ => None
  }
}

///|
fn usage_query_int(path : StringView, key : String) -> Int? {
  match usage_query_value(path, key) {
    Some(value) =>
      try @string.parse_int(value, base=10) catch {
        _ => None
      } noraise {
        parsed => Some(parsed)
      }
    None => None
  }
}

///|
fn usage_query_value(path : StringView, key : String) -> String? {
  let text = path.to_owned()
  guard text.find("?") is Some(question_index) else { return None }
  let query = text[question_index + 1:]
  for pair_view in query.split("&") {
    let pair = pair_view.to_owned()
    guard pair.find("=") is Some(equal_index) else { continue }
    let pair_key = usage_url_decode(pair[:equal_index])
    if pair_key == key {
      let value = usage_url_decode(pair[equal_index + 1:])
      if value.is_empty() {
        return None
      }
      return Some(value)
    }
  }
  None
}

///|
fn usage_url_decode(value : StringView) -> String {
  let builder = StringBuilder::new()
  let chars = value.to_array()
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '%' && i + 2 < chars.length() {
      match (usage_hex_value(chars[i + 1]), usage_hex_value(chars[i + 2])) {
        (Some(high), Some(low)) => {
          builder.write_char(((high << 4) | low).unsafe_to_char())
          i += 3
          continue
        }
        _ => ()
      }
    } else if ch == '+' {
      builder.write_char(' ')
      i += 1
      continue
    }
    builder.write_char(ch)
    i += 1
  }
  builder.to_string()
}

///|
fn usage_hex_value(ch : Char) -> Int? {
  match ch {
    '0'..='9' => Some(ch.to_int() - '0'.to_int())
    'A'..='F' => Some(ch.to_int() - 'A'.to_int() + 10)
    'a'..='f' => Some(ch.to_int() - 'a'.to_int() + 10)
    _ => None
  }
}

///|
fn usage_decimal_validation_error_from_request(
  path : StringView,
  body : Json?,
  label : String,
  key : String,
) -> String? {
  let value = usage_string_from_request(path, body, key).unwrap_or("")
  usage_decimal_validation_error(label, value)
}

///|
fn usage_decimal_validation_error(label : String, value : String) -> String? {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() {
    return Some("\{label} price is invalid: \{value}")
  }
  if trimmed.has_prefix("-") {
    return Some("\{label} price must be non-negative: \{value}")
  }
  if !usage_non_negative_decimal(value) {
    return Some("\{label} price is invalid: \{value}")
  }
  None
}

///|
fn usage_result_from_request(path : StringView, body : Json?) -> UsageResult? {
  for key in ["result", "usageResult", "scriptCode"] {
    match usage_query_value(path, key) {
      Some(value) =>
        match usage_result_from_string(value) {
          Some(result) => return Some(result)
          None => ()
        }
      None => ()
    }
  }
  match body {
    Some(json) => {
      match usage_result_from_json(json) {
        Some(result) => return Some(result)
        None => ()
      }
      guard json is Object(obj) else { return None }
      for key in ["result", "usageResult"] {
        match obj.get(key) {
          Some(value) =>
            match usage_result_or_script_output_from_json(value) {
              Some(result) => return Some(result)
              None => ()
            }
          None => ()
        }
      }
      for key in ["scriptCode"] {
        match obj.get(key) {
          Some(String(value)) =>
            match usage_result_from_string(value) {
              Some(result) => return Some(result)
              None => ()
            }
          Some(value) =>
            match usage_result_or_script_output_from_json(value) {
              Some(result) => return Some(result)
              None => ()
            }
          _ => ()
        }
      }
      None
    }
    None => None
  }
}

///|
async fn test_usage_script_template_result(
  path : StringView,
  body : Json?,
) -> UsageResult? {
  let template_type = proxy_string_request(path, body, "templateType").unwrap_or(
    "",
  )
  match template_type {
    "github_copilot" =>
      match copilot_get_usage(copilot_account_id_request(path, body)) {
        Ok(usage) => Some(moon_copilot_usage_result_from_json(usage))
        Err(error) => Some(UsageResult::new(false, error=Some(error)))
      }
    "balance" => {
      guard proxy_string_request(path, body, "baseUrl") is Some(base_url) else {
        return Some(moon_balance_error("Base URL is empty"))
      }
      let api_key = proxy_string_request(path, body, "apiKey").unwrap_or("")
      Some(moon_get_balance(base_url, api_key))
    }
    "token_plan" => {
      let base_url = proxy_string_request(path, body, "baseUrl").unwrap_or("")
      let api_key = proxy_string_request(path, body, "apiKey").unwrap_or("")
      Some(
        moon_token_plan_usage_result_from_quota(
          moon_get_coding_plan_quota(
            base_url,
            api_key,
            coding_plan_provider=proxy_string_request(
              path, body, "codingPlanProvider",
            ),
            team_organization_id=proxy_string_request(
              path, body, "teamOrganizationId",
            ),
            team_project_id=proxy_string_request(path, body, "teamProjectId"),
          ),
        ),
      )
    }
    "official_subscription" => {
      let app_type = proxy_string_request(path, body, "tool").unwrap_or("")
      Some(
        moon_subscription_usage_result_from_quota(
          moon_get_subscription_quota(app_type),
        ),
      )
    }
    _ => None
  }
}

///|
fn moon_subscription_usage_result_from_quota(
  quota : SubscriptionQuota,
) -> UsageResult {
  if !quota.success {
    return UsageResult::new(
      false,
      error=match quota.error {
        Some(error) => Some(error)
        None => quota.credential_message
      },
    )
  }
  let data : Array[UsageData] = []
  for tier in quota.tiers {
    guard tier is Object(obj) else { continue }
    let used = moon_json_double_from_map(obj, "utilization").unwrap_or(0.0)
    data.push(
      UsageData::new(
        plan_name=json_string_from_map(obj, "name"),
        remaining=Some(100.0 - used),
        total=Some(100.0),
        used=Some(used),
        unit=Some("%"),
        is_valid=Some(true),
        extra=json_string_from_map(obj, "resetsAt"),
      ),
    )
  }
  UsageResult::new(true, data=if data.is_empty() { None } else { Some(data) })
}

///|
fn usage_result_from_string(value : String) -> UsageResult? {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() {
    return None
  }
  let parsed = @json.parse(trimmed) catch { _ => return None }
  usage_result_or_script_output_from_json(parsed)
}

///|
fn usage_non_negative_decimal(value : String) -> Bool {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() || trimmed.has_prefix("-") {
    return false
  }
  let mut seen_digit = false
  let mut seen_dot = false
  let mut digit_after_dot = false
  for ch in trimmed {
    let code = ch.to_int()
    if code >= '0'.to_int() && code <= '9'.to_int() {
      seen_digit = true
      if seen_dot {
        digit_after_dot = true
      }
    } else if ch == '.' && !seen_dot && seen_digit {
      seen_dot = true
    } else {
      return false
    }
  }
  seen_digit && (!seen_dot || digit_after_dot)
}

///|
fn gemini_native_stream_anthropic_usage_json(usage : Json?) -> Json {
  let body = match usage {
    Some(usage) => Json::object({ "usageMetadata": usage })
    None => Json::object({})
  }
  token_usage_from_gemini_response(body)
  .unwrap_or(TokenUsage::empty())
  .as_anthropic_usage_json()
}

///|
fn openai_chat_zero_usage_json() -> Json {
  Json::object({
    "input_tokens": Json::number(0.0),
    "output_tokens": Json::number(0.0),
  })
}

///|
fn openai_chat_stream_anthropic_usage_json(usage : Map[String, Json]) -> Json {
  let cache_read = match json_int(usage, "cache_read_input_tokens") {
    Some(tokens) => tokens
    None =>
      match usage.get("prompt_tokens_details") {
        Some(Object(details)) => json_int_or_zero(details, "cached_tokens")
        _ => 0
      }
  }
  let cache_creation = json_int_or_zero(usage, "cache_creation_input_tokens")
  let prompt_tokens = json_int_or_zero(usage, "prompt_tokens")
  let input_tokens = max_int(prompt_tokens - cache_read - cache_creation, 0)
  let result : Map[String, Json] = {
    "input_tokens": Json::number(input_tokens.to_double()),
    "output_tokens": Json::number(
      json_int_or_zero(usage, "completion_tokens").to_double(),
    ),
  }
  if cache_read > 0 {
    result["cache_read_input_tokens"] = Json::number(cache_read.to_double())
  }
  if cache_creation > 0 {
    result["cache_creation_input_tokens"] = Json::number(
      cache_creation.to_double(),
    )
  }
  Json::object(result)
}

///|
fn responses_stream_anthropic_usage_json(
  response_obj : Map[String, Json],
) -> Json {
  guard response_obj.get("usage") is Some(Object(usage)) else {
    return openai_chat_zero_usage_json()
  }
  let input_tokens = match json_int(usage, "input_tokens") {
    Some(n) => n
    None => json_int_or_zero(usage, "prompt_tokens")
  }
  let output_tokens = match json_int(usage, "output_tokens") {
    Some(n) => n
    None => json_int_or_zero(usage, "completion_tokens")
  }
  let mut cache_read_tokens = match usage.get("input_tokens_details") {
    Some(Object(details)) => json_int_or_zero(details, "cached_tokens")
    _ =>
      match usage.get("prompt_tokens_details") {
        Some(Object(details)) => json_int_or_zero(details, "cached_tokens")
        _ => 0
      }
  }
  match json_int(usage, "cache_read_input_tokens") {
    Some(n) => cache_read_tokens = n
    None => ()
  }
  let cache_creation_tokens = json_int_or_zero(
    usage, "cache_creation_input_tokens",
  )
  TokenUsage::new(
    input_tokens~,
    output_tokens~,
    cache_read_tokens~,
    cache_creation_tokens~,
  ).as_anthropic_usage_json()
}
