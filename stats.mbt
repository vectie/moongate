///|
const REQUEST_LOG_LIMIT = 500

///|
pub struct RequestLog {
  request_id : String
  provider_id : String
  provider_name : String?
  app_type : String
  model : String
  request_model : String?
  pricing_model : String?
  input_tokens : Int
  output_tokens : Int
  cache_read_tokens : Int
  cache_creation_tokens : Int
  input_cost_usd : String
  output_cost_usd : String
  cache_read_cost_usd : String
  cache_creation_cost_usd : String
  total_cost_usd : String
  is_streaming : Bool
  latency_ms : Int
  first_token_ms : Int?
  duration_ms : Int?
  status_code : Int
  error_message : String?
  session_id : String?
  provider_type : String?
  cost_multiplier : String
  created_at : Int
  data_source : String
}

///|
pub fn RequestLog::new(
  request_id~ : String,
  provider_id~ : String,
  app_type~ : String,
  model~ : String,
  usage~ : TokenUsage,
  status_code~ : Int,
  latency_ms? : Int = 0,
  first_token_ms? : Int? = None,
  duration_ms? : Int? = None,
  error_message? : String? = None,
  session_id? : String? = None,
  provider_name? : String? = None,
  provider_type? : String? = None,
  request_model? : String? = None,
  pricing_model? : String? = None,
  input_cost_usd? : String = "0",
  output_cost_usd? : String = "0",
  cache_read_cost_usd? : String = "0",
  cache_creation_cost_usd? : String = "0",
  total_cost_usd? : String = "0",
  is_streaming? : Bool = false,
  cost_multiplier? : String = "1.0",
  created_at? : Int = @os.unix_seconds(),
  data_source? : String = "proxy",
) -> RequestLog {
  {
    request_id,
    provider_id,
    provider_name,
    app_type,
    model,
    request_model,
    pricing_model,
    input_tokens: usage.input_tokens,
    output_tokens: usage.output_tokens,
    cache_read_tokens: usage.cache_read_tokens,
    cache_creation_tokens: usage.cache_creation_tokens,
    input_cost_usd,
    output_cost_usd,
    cache_read_cost_usd,
    cache_creation_cost_usd,
    total_cost_usd,
    is_streaming,
    latency_ms,
    first_token_ms,
    duration_ms,
    status_code,
    error_message,
    session_id,
    provider_type,
    cost_multiplier,
    created_at,
    data_source,
  }
}

///|
pub fn RequestLog::to_json(self : RequestLog) -> Json {
  {
    "request_id": Json::string(self.request_id),
    "provider_id": Json::string(self.provider_id),
    "provider_name": optional_string_json(self.provider_name),
    "app_type": Json::string(self.app_type),
    "model": Json::string(self.model),
    "request_model": optional_string_json(self.request_model),
    "pricing_model": optional_string_json(self.pricing_model),
    "cost_multiplier": Json::string(self.cost_multiplier),
    "input_tokens": Json::number(self.input_tokens.to_double()),
    "output_tokens": Json::number(self.output_tokens.to_double()),
    "cache_read_tokens": Json::number(self.cache_read_tokens.to_double()),
    "cache_creation_tokens": Json::number(
      self.cache_creation_tokens.to_double(),
    ),
    "input_cost_usd": Json::string(self.input_cost_usd),
    "output_cost_usd": Json::string(self.output_cost_usd),
    "cache_read_cost_usd": Json::string(self.cache_read_cost_usd),
    "cache_creation_cost_usd": Json::string(self.cache_creation_cost_usd),
    "total_cost_usd": Json::string(self.total_cost_usd),
    "is_streaming": Json::boolean(self.is_streaming),
    "latency_ms": Json::number(self.latency_ms.to_double()),
    "first_token_ms": optional_int_json(self.first_token_ms),
    "duration_ms": optional_int_json(self.duration_ms),
    "status_code": Json::number(self.status_code.to_double()),
    "error_message": optional_string_json(self.error_message),
    "session_id": optional_string_json(self.session_id),
    "provider_type": optional_string_json(self.provider_type),
    "created_at": Json::number(self.created_at.to_double()),
    "data_source": Json::string(self.data_source),
  }.to_json()
}

///|
pub struct TrafficStats {
  mut active_connections : Int
  mut total_requests : Int
  mut message_requests : Int
  mut streaming_requests : Int
  mut non_streaming_requests : Int
  mut successful_responses : Int
  mut failed_responses : Int
  mut unauthorized_responses : Int
  mut bad_requests : Int
  mut upstream_errors : Int
  mut input_tokens : Int
  mut output_tokens : Int
  mut cache_read_tokens : Int
  mut cache_creation_tokens : Int
  mut request_bytes : Int
  mut response_bytes : Int
  mut current_provider : String?
  mut current_provider_id : String?
  mut failover_count : Int
  active_targets : Map[String, ActiveTarget]
  provider_limits : Map[String, ProviderLimitConfig]
  mut session_sync_state : Map[String, SessionFileSyncState]
  mut storage_dir : String?
  mut last_request_at : String?
  mut last_error : String?
  request_logs : Array[RequestLog]
  mut current_request_id : String?
  mut current_request_started_at_ms : Int?
  mut current_request_app_type : String?
  mut current_request_model : String?
  mut current_request_session_id : String?
  mut current_request_provider_type : String?
  mut current_request_cost_multiplier : String
  mut current_request_pricing_model_source : String
  mut current_request_is_streaming : Bool
  mut current_request_used_half_open_permit : Bool
}

///|
pub struct ActiveTarget {
  app_type : String
  provider_id : String
  provider_name : String
}

///|
pub fn TrafficStats::new() -> TrafficStats {
  {
    active_connections: 0,
    total_requests: 0,
    message_requests: 0,
    streaming_requests: 0,
    non_streaming_requests: 0,
    successful_responses: 0,
    failed_responses: 0,
    unauthorized_responses: 0,
    bad_requests: 0,
    upstream_errors: 0,
    input_tokens: 0,
    output_tokens: 0,
    cache_read_tokens: 0,
    cache_creation_tokens: 0,
    request_bytes: 0,
    response_bytes: 0,
    current_provider: None,
    current_provider_id: None,
    failover_count: 0,
    active_targets: Map([], capacity=0),
    provider_limits: Map([], capacity=0),
    session_sync_state: Map([], capacity=0),
    storage_dir: None,
    last_request_at: None,
    last_error: None,
    request_logs: [],
    current_request_id: None,
    current_request_started_at_ms: None,
    current_request_app_type: None,
    current_request_model: None,
    current_request_session_id: None,
    current_request_provider_type: None,
    current_request_cost_multiplier: "1.0",
    current_request_pricing_model_source: "response",
    current_request_is_streaming: false,
    current_request_used_half_open_permit: false,
  }
}

///|
pub fn TrafficStats::set_active_target(
  self : TrafficStats,
  app_type : String,
  provider_id : String,
  provider_name : String,
  cost_multiplier? : String = "1.0",
  pricing_model_source? : String = "response",
) -> Unit {
  match self.active_targets.get(app_type) {
    Some(target) if target.provider_id != provider_id =>
      self.failover_count += 1
    _ => ()
  }
  self.current_provider = Some(provider_name)
  self.current_provider_id = Some(provider_id)
  self.current_request_cost_multiplier = cost_multiplier
  self.current_request_pricing_model_source = pricing_model_source
  self.active_targets.set(app_type, ActiveTarget::{
    app_type,
    provider_id,
    provider_name,
  })
}

///|
pub fn TrafficStats::record_inbound(
  self : TrafficStats,
  request_bytes : Int,
) -> Unit {
  let now = @async.now()
  self.total_requests += 1
  self.message_requests += 1
  self.active_connections += 1
  self.request_bytes += request_bytes
  self.last_request_at = Some(now.to_string())
  self.last_error = None
  self.current_request_id = Some(generate_request_log_id())
  self.current_request_started_at_ms = Some(now.to_int())
  self.current_request_app_type = None
  self.current_request_model = None
  self.current_request_session_id = None
  self.current_request_provider_type = None
  self.current_request_cost_multiplier = "1.0"
  self.current_request_pricing_model_source = "response"
  self.current_request_is_streaming = false
  self.current_request_used_half_open_permit = false
}

///|
pub fn TrafficStats::record_request_context(
  self : TrafficStats,
  app_type : String,
  model : String,
  session_id? : String? = None,
  provider_type? : String? = None,
) -> Unit {
  self.current_request_app_type = Some(app_type)
  self.current_request_model = Some(model)
  self.current_request_session_id = session_id
  self.current_request_provider_type = provider_type
}

///|
pub fn TrafficStats::record_stream_mode(
  self : TrafficStats,
  stream : Bool,
) -> Unit {
  if stream {
    self.streaming_requests += 1
  } else {
    self.non_streaming_requests += 1
  }
  self.current_request_is_streaming = stream
}

///|
pub fn TrafficStats::record_bad_request(self : TrafficStats) -> Unit {
  self.bad_requests += 1
  self.failed_responses += 1
  self.last_error = Some("bad_request")
  self.record_completed_request(400, TokenUsage::empty(), Some("bad_request"))
  self.finish_request()
}

///|
pub fn TrafficStats::record_unauthorized(self : TrafficStats) -> Unit {
  self.unauthorized_responses += 1
  self.failed_responses += 1
  self.last_error = Some("unauthorized")
  self.record_completed_request(401, TokenUsage::empty(), Some("unauthorized"))
  self.finish_request()
}

///|
pub fn TrafficStats::record_upstream_error(
  self : TrafficStats,
  response_bytes : Int,
) -> Unit {
  self.record_upstream_error_status(response_bytes, 502)
}

///|
pub fn TrafficStats::record_upstream_error_status(
  self : TrafficStats,
  response_bytes : Int,
  status_code : Int,
) -> Unit {
  self.upstream_errors += 1
  self.failed_responses += 1
  self.response_bytes += response_bytes
  self.last_error = Some("upstream_error")
  self.record_completed_request(
    status_code,
    TokenUsage::empty(),
    Some("upstream_error"),
  )
  self.finish_request()
}

///|
pub fn TrafficStats::record_internal_error(self : TrafficStats) -> Unit {
  self.failed_responses += 1
  self.last_error = Some("internal_error")
  self.record_completed_request(
    500,
    TokenUsage::empty(),
    Some("internal_error"),
  )
  self.finish_request()
}

///|
pub fn TrafficStats::record_success(
  self : TrafficStats,
  input_tokens : Int,
  output_tokens : Int,
  response_bytes : Int,
) -> Unit {
  self.successful_responses += 1
  self.input_tokens += input_tokens
  self.output_tokens += output_tokens
  self.response_bytes += response_bytes
  self.last_error = None
  self.record_completed_request(
    200,
    TokenUsage::new(input_tokens~, output_tokens~),
    None,
  )
  self.finish_request()
}

///|
fn TrafficStats::record_success_without_request_log(
  self : TrafficStats,
  response_bytes : Int,
) -> Unit {
  self.successful_responses += 1
  self.response_bytes += response_bytes
  self.last_error = None
  self.finish_request()
}

///|
pub fn TrafficStats::record_success_usage(
  self : TrafficStats,
  usage : TokenUsage,
  response_bytes : Int,
) -> Unit {
  self.record_success_usage_with_pricing(
    usage,
    response_bytes,
    [],
    Map([], capacity=0),
  )
}

///|
fn TrafficStats::record_success_usage_with_pricing(
  self : TrafficStats,
  usage : TokenUsage,
  response_bytes : Int,
  pricing_overrides : Array[ModelPricing],
  deleted_model_ids : Map[String, Bool],
) -> Unit {
  self.successful_responses += 1
  self.input_tokens += usage.input_tokens
  self.output_tokens += usage.output_tokens
  self.cache_read_tokens += usage.cache_read_tokens
  self.cache_creation_tokens += usage.cache_creation_tokens
  self.response_bytes += response_bytes
  self.last_error = None
  self.record_completed_request(
    200,
    usage,
    None,
    pricing_overrides~,
    deleted_model_ids~,
  )
  self.finish_request()
}

///|
fn TrafficStats::record_completed_request(
  self : TrafficStats,
  status_code : Int,
  usage : TokenUsage,
  error_message : String?,
  pricing_overrides? : Array[ModelPricing] = [],
  deleted_model_ids? : Map[String, Bool] = Map([], capacity=0),
) -> Unit {
  guard self.current_request_id is Some(fallback_request_id) else { return }
  let request_id = usage.dedup_request_id(fallback_request_id)
  let now_ms = @async.now().to_int()
  let latency_ms = match self.current_request_started_at_ms {
    Some(started_at) => max_int(now_ms - started_at, 0)
    None => 0
  }
  let model = match usage.model {
    Some(model) if !model.is_empty() => model
    _ => self.current_request_model.unwrap_or("unknown")
  }
  let request_model = match self.current_request_model {
    Some(request_model) => Some(request_model)
    None => Some(model)
  }
  let app_type = self.current_request_app_type.unwrap_or("unknown")
  let pricing_model = match self.current_request_pricing_model_source {
    "request" => request_model.unwrap_or(model)
    _ => model
  }
  let pricing = find_model_pricing(
    pricing_model, pricing_overrides, deleted_model_ids,
  )
  let cost_multiplier = self.current_request_cost_multiplier
  let cost = match pricing {
    Some(model_pricing) if usage.has_billable_tokens() =>
      calculate_cost_for_app(app_type, usage, model_pricing, cost_multiplier~)
    _ =>
      {
        input_cost_usd: "0",
        output_cost_usd: "0",
        cache_read_cost_usd: "0",
        cache_creation_cost_usd: "0",
        total_cost_usd: "0",
      }
  }
  self.record_request_log(
    RequestLog::new(
      request_id~,
      provider_id=self.current_provider_id.unwrap_or("unknown"),
      provider_name=self.current_provider,
      app_type~,
      model~,
      request_model~,
      pricing_model=Some(pricing_model),
      usage~,
      input_cost_usd=cost.input_cost_usd,
      output_cost_usd=cost.output_cost_usd,
      cache_read_cost_usd=cost.cache_read_cost_usd,
      cache_creation_cost_usd=cost.cache_creation_cost_usd,
      total_cost_usd=cost.total_cost_usd,
      status_code~,
      latency_ms~,
      duration_ms=Some(latency_ms),
      error_message~,
      session_id=self.current_request_session_id,
      provider_type=self.current_request_provider_type,
      is_streaming=self.current_request_is_streaming,
      cost_multiplier~,
    ),
  )
}

///|
pub fn TrafficStats::record_request_log(
  self : TrafficStats,
  log : RequestLog,
) -> Unit {
  let len = self.request_logs.length()
  if len >= REQUEST_LOG_LIMIT {
    for i in 1..<len {
      self.request_logs[i - 1] = self.request_logs[i]
    }
    self.request_logs.truncate(REQUEST_LOG_LIMIT - 1)
  }
  self.request_logs.push(log)
}

///|
fn TrafficStats::backfill_missing_usage_costs_for_model(
  self : TrafficStats,
  model_id : String,
  pricing_overrides : Array[ModelPricing],
  deleted_model_ids : Map[String, Bool],
) -> Int {
  let mut updated = 0
  for i in 0..<self.request_logs.length() {
    let log = self.request_logs[i]
    if !request_log_needs_cost_backfill(log, model_id) {
      continue
    }
    let usage = TokenUsage::new(
      input_tokens=log.input_tokens,
      output_tokens=log.output_tokens,
      cache_read_tokens=log.cache_read_tokens,
      cache_creation_tokens=log.cache_creation_tokens,
      model=Some(log.model),
    )
    guard usage.has_billable_tokens() else { continue }
    guard request_log_backfill_pricing_model(log) is Some(pricing_model) else {
      continue
    }
    guard find_model_pricing(
        pricing_model, pricing_overrides, deleted_model_ids,
      )
      is Some(pricing) else {
      continue
    }
    let cost = calculate_cost_for_app(
      log.app_type,
      usage,
      pricing,
      cost_multiplier=log.cost_multiplier,
    )
    self.request_logs[i] = RequestLog::new(
      request_id=log.request_id,
      provider_id=log.provider_id,
      provider_name=log.provider_name,
      app_type=log.app_type,
      model=log.model,
      request_model=log.request_model,
      pricing_model=log.pricing_model,
      usage~,
      input_cost_usd=cost.input_cost_usd,
      output_cost_usd=cost.output_cost_usd,
      cache_read_cost_usd=cost.cache_read_cost_usd,
      cache_creation_cost_usd=cost.cache_creation_cost_usd,
      total_cost_usd=cost.total_cost_usd,
      is_streaming=log.is_streaming,
      latency_ms=log.latency_ms,
      first_token_ms=log.first_token_ms,
      duration_ms=log.duration_ms,
      status_code=log.status_code,
      error_message=log.error_message,
      session_id=log.session_id,
      provider_type=log.provider_type,
      cost_multiplier=log.cost_multiplier,
      created_at=log.created_at,
      data_source=log.data_source,
    )
    updated += 1
  }
  updated
}

///|
fn TrafficStats::backfill_missing_usage_costs(
  self : TrafficStats,
  pricing_overrides : Array[ModelPricing],
  deleted_model_ids : Map[String, Bool],
) -> Int {
  let mut updated = 0
  for i in 0..<self.request_logs.length() {
    let log = self.request_logs[i]
    if request_log_total_cost_nano(log) > 0L {
      continue
    }
    let usage = TokenUsage::new(
      input_tokens=log.input_tokens,
      output_tokens=log.output_tokens,
      cache_read_tokens=log.cache_read_tokens,
      cache_creation_tokens=log.cache_creation_tokens,
      model=Some(log.model),
    )
    guard usage.has_billable_tokens() else { continue }
    guard request_log_backfill_pricing_model(log) is Some(pricing_model) else {
      continue
    }
    guard find_model_pricing(
        pricing_model, pricing_overrides, deleted_model_ids,
      )
      is Some(pricing) else {
      continue
    }
    let cost = calculate_cost_for_app(
      log.app_type,
      usage,
      pricing,
      cost_multiplier=log.cost_multiplier,
    )
    self.request_logs[i] = RequestLog::new(
      request_id=log.request_id,
      provider_id=log.provider_id,
      provider_name=log.provider_name,
      app_type=log.app_type,
      model=log.model,
      request_model=log.request_model,
      pricing_model=log.pricing_model,
      usage~,
      input_cost_usd=cost.input_cost_usd,
      output_cost_usd=cost.output_cost_usd,
      cache_read_cost_usd=cost.cache_read_cost_usd,
      cache_creation_cost_usd=cost.cache_creation_cost_usd,
      total_cost_usd=cost.total_cost_usd,
      is_streaming=log.is_streaming,
      latency_ms=log.latency_ms,
      first_token_ms=log.first_token_ms,
      duration_ms=log.duration_ms,
      status_code=log.status_code,
      error_message=log.error_message,
      session_id=log.session_id,
      provider_type=log.provider_type,
      cost_multiplier=log.cost_multiplier,
      created_at=log.created_at,
      data_source=log.data_source,
    )
    updated += 1
  }
  updated
}

///|
fn request_log_needs_cost_backfill(log : RequestLog, model_id : String) -> Bool {
  if request_log_total_cost_nano(log) > 0L {
    return false
  }
  log.model == model_id ||
  log.request_model == Some(model_id) ||
  log.pricing_model == Some(model_id)
}

///|
fn request_log_backfill_pricing_model(log : RequestLog) -> String? {
  match log.pricing_model {
    Some(pricing_model) if !is_placeholder_pricing_model(pricing_model) =>
      return Some(pricing_model)
    _ => ()
  }
  if !is_placeholder_pricing_model(log.model) {
    return Some(log.model)
  }
  match log.request_model {
    Some(request_model) if request_model != log.model => Some(request_model)
    _ => None
  }
}

///|
fn is_placeholder_pricing_model(model_id : String) -> Bool {
  let normalized = model_id.trim().to_lower()
  normalized.is_empty() ||
  normalized == "unknown" ||
  normalized == "null" ||
  normalized == "none"
}

///|
pub fn TrafficStats::request_logs_json(
  self : TrafficStats,
  limit? : Int = 100,
) -> Json {
  let effective_logs : Array[RequestLog] = []
  for log in self.request_logs {
    if self.request_log_is_effective(log) {
      effective_logs.push(log)
    }
  }
  let logs : Array[Json] = []
  let len = effective_logs.length()
  let bounded_limit = if limit < 0 { 0 } else { limit }
  let start = max_int(len - bounded_limit, 0)
  for i in start..<len {
    logs.push(effective_logs[i].to_ccs_request_log_detail_json())
  }
  Json::array(logs)
}

///|
pub fn TrafficStats::usage_logs_json(
  self : TrafficStats,
  limit? : Int = 100,
) -> Json {
  {
    "data": self.request_logs_json(limit~),
    "total": Json::number(self.effective_request_log_count().to_double()),
    "limit": Json::number((if limit < 0 { 0 } else { limit }).to_double()),
    "source": Json::string(
      if self.storage_dir is Some(_) {
        "file"
      } else {
        "memory"
      },
    ),
    "table": Json::string("proxy_request_logs"),
  }.to_json()
}

///|
priv struct RequestLogFilters {
  app_type : String?
  provider_name : String?
  model : String?
  status_code : Int?
  start_date : Int?
  end_date : Int?
}

///|
fn RequestLogFilters::new(
  app_type? : String? = None,
  provider_name? : String? = None,
  model? : String? = None,
  status_code? : Int? = None,
  start_date? : Int? = None,
  end_date? : Int? = None,
) -> RequestLogFilters {
  { app_type, provider_name, model, status_code, start_date, end_date }
}

///|
fn TrafficStats::usage_logs_paginated_json(
  self : TrafficStats,
  filters : RequestLogFilters,
  page? : Int = 0,
  page_size? : Int = 20,
  pricing_overrides? : Array[ModelPricing] = [],
  deleted_model_ids? : Map[String, Bool] = Map([], capacity=0),
) -> Json {
  let _updated = self.backfill_missing_usage_costs(
    pricing_overrides, deleted_model_ids,
  )
  let page = max_int(page, 0)
  let page_size = max_int(page_size, 0)
  let rows : Array[RequestLog] = []
  for log in self.request_logs {
    if self.request_log_is_effective(log) &&
      request_log_matches_filters(log, filters) {
      rows.push(log)
    }
  }
  rows.sort_by(fn(left, right) {
    let created_order = right.created_at.compare(left.created_at)
    if created_order != 0 {
      created_order
    } else {
      right.request_id.compare(left.request_id)
    }
  })
  let data : Array[Json] = []
  let total = rows.length()
  let start = page * page_size
  let end = request_log_min_int(start + page_size, total)
  if start < total {
    for i in start..<end {
      data.push(rows[i].to_ccs_request_log_detail_json())
    }
  }
  {
    "data": Json::array(data),
    "total": Json::number(total.to_double()),
    "page": Json::number(page.to_double()),
    "pageSize": Json::number(page_size.to_double()),
  }.to_json()
}

///|
pub fn TrafficStats::usage_summary_json(
  self : TrafficStats,
  app_type? : String? = None,
) -> Json {
  self.usage_summary_filtered_json(app_type~)
}

///|
fn TrafficStats::usage_summary_filtered_json(
  self : TrafficStats,
  start_date? : Int? = None,
  end_date? : Int? = None,
  app_type? : String? = None,
) -> Json {
  let acc = UsageSummaryAccumulator::new()
  for log in self.request_logs {
    if self.request_log_is_effective(log) &&
      request_log_matches_usage_aggregate(log, start_date, end_date, app_type) {
      acc.add(log)
    }
  }
  acc.to_json()
}

///|
pub fn TrafficStats::usage_summary_by_app_json(self : TrafficStats) -> Json {
  self.usage_summary_by_app_filtered_json()
}

///|
fn TrafficStats::usage_summary_by_app_filtered_json(
  self : TrafficStats,
  start_date? : Int? = None,
  end_date? : Int? = None,
) -> Json {
  let summaries : Map[String, UsageSummaryAccumulator] = Map([], capacity=0)
  for log in self.request_logs {
    if !self.request_log_is_effective(log) ||
      !request_log_matches_usage_aggregate(log, start_date, end_date, None) {
      continue
    }
    let acc = summaries
      .get(log.app_type)
      .unwrap_or(UsageSummaryAccumulator::new())
    acc.add(log)
    summaries.set(log.app_type, acc)
  }
  let rows : Array[UsageSummaryByAppRow] = []
  for app_type in summaries.keys() {
    guard summaries.get(app_type) is Some(summary) else { continue }
    rows.push({
      app_type,
      real_total_tokens: summary.real_total_tokens(),
      summary,
    })
  }
  rows.sort_by(fn(left, right) {
    let token_order = right.real_total_tokens.compare(left.real_total_tokens)
    if token_order != 0 {
      token_order
    } else {
      left.app_type.compare(right.app_type)
    }
  })
  Json::array(
    rows.map(fn(row) {
      {
        "appType": Json::string(row.app_type),
        "summary": row.summary.to_json(),
      }.to_json()
    }),
  )
}

///|
pub fn TrafficStats::provider_stats_json(
  self : TrafficStats,
  app_type? : String? = None,
) -> Json {
  self.provider_stats_filtered_json(app_type~)
}

///|
fn TrafficStats::provider_stats_filtered_json(
  self : TrafficStats,
  start_date? : Int? = None,
  end_date? : Int? = None,
  app_type? : String? = None,
) -> Json {
  let stats : Map[String, ProviderStatsAccumulator] = Map([], capacity=0)
  for log in self.request_logs {
    if !self.request_log_is_effective(log) ||
      !request_log_matches_usage_aggregate(log, start_date, end_date, app_type) {
      continue
    }
    let key = "\{log.provider_id}|\{log.app_type}"
    let acc = stats.get(key).unwrap_or(ProviderStatsAccumulator::new(log))
    acc.add(log)
    stats.set(key, acc)
  }
  let rows : Array[ProviderStatsAccumulator] = []
  for key in stats.keys() {
    guard stats.get(key) is Some(acc) else { continue }
    rows.push(acc)
  }
  rows.sort_by(fn(left, right) {
    let cost_order = right.total_cost_nano.compare(left.total_cost_nano)
    if cost_order != 0 {
      cost_order
    } else {
      left.provider_id.compare(right.provider_id)
    }
  })
  Json::array(rows.map(fn(acc) { acc.to_json() }))
}

///|
pub fn TrafficStats::model_stats_json(
  self : TrafficStats,
  app_type? : String? = None,
) -> Json {
  self.model_stats_filtered_json(app_type~)
}

///|
fn TrafficStats::model_stats_filtered_json(
  self : TrafficStats,
  start_date? : Int? = None,
  end_date? : Int? = None,
  app_type? : String? = None,
) -> Json {
  let stats : Map[String, ModelStatsAccumulator] = Map([], capacity=0)
  for log in self.request_logs {
    if !self.request_log_is_effective(log) ||
      !request_log_matches_usage_aggregate(log, start_date, end_date, app_type) {
      continue
    }
    let model = request_log_pricing_model(log)
    let acc = stats.get(model).unwrap_or(ModelStatsAccumulator::new(model))
    acc.add(log)
    stats.set(model, acc)
  }
  let rows : Array[ModelStatsAccumulator] = []
  for model in stats.keys() {
    guard stats.get(model) is Some(acc) else { continue }
    rows.push(acc)
  }
  rows.sort_by(fn(left, right) {
    let cost_order = right.total_cost_nano.compare(left.total_cost_nano)
    if cost_order != 0 {
      cost_order
    } else {
      left.model.compare(right.model)
    }
  })
  Json::array(rows.map(fn(acc) { acc.to_json() }))
}

///|
pub fn TrafficStats::usage_data_sources_json(self : TrafficStats) -> Json {
  let sources : Map[String, DataSourceStatsAccumulator] = Map([], capacity=0)
  for log in self.request_logs {
    if !self.request_log_is_effective(log) {
      continue
    }
    let data_source = request_log_data_source(log)
    let acc = sources
      .get(data_source)
      .unwrap_or(DataSourceStatsAccumulator::new(data_source))
    acc.add(log)
    sources.set(data_source, acc)
  }
  let rows : Array[DataSourceStatsAccumulator] = []
  for source in sources.keys() {
    guard sources.get(source) is Some(acc) else { continue }
    rows.push(acc)
  }
  rows.sort_by(fn(left, right) {
    let count_order = right.request_count.compare(left.request_count)
    if count_order != 0 {
      count_order
    } else {
      left.data_source.compare(right.data_source)
    }
  })
  Json::array(rows.map(fn(acc) { acc.to_json() }))
}

///|
pub fn TrafficStats::request_detail_json(
  self : TrafficStats,
  request_id : String,
) -> Json? {
  self.request_detail_json_with_pricing(request_id, [], Map([], capacity=0))
}

///|
fn TrafficStats::request_detail_json_with_pricing(
  self : TrafficStats,
  request_id : String,
  pricing_overrides : Array[ModelPricing],
  deleted_model_ids : Map[String, Bool],
) -> Json? {
  let _updated = self.backfill_missing_usage_costs(
    pricing_overrides, deleted_model_ids,
  )
  let mut i = self.request_logs.length() - 1
  while i >= 0 {
    let log = self.request_logs[i]
    if log.request_id == request_id {
      return Some(log.to_ccs_request_log_detail_json())
    }
    i -= 1
  }
  None
}

///|
priv struct UsageSummaryAccumulator {
  mut total_requests : Int
  mut success_count : Int
  mut total_input_tokens : Int
  mut total_output_tokens : Int
  mut total_cache_creation_tokens : Int
  mut total_cache_read_tokens : Int
  mut total_cost_nano : Int64
}

///|
priv struct UsageSummaryByAppRow {
  app_type : String
  real_total_tokens : Int
  summary : UsageSummaryAccumulator
}

///|
priv struct ProviderStatsAccumulator {
  provider_id : String
  provider_name : String
  mut request_count : Int
  mut success_count : Int
  mut total_tokens : Int
  mut total_cost_nano : Int64
  mut total_latency_ms : Int
}

///|
priv struct ModelStatsAccumulator {
  model : String
  mut request_count : Int
  mut total_tokens : Int
  mut total_cost_nano : Int64
}

///|
priv struct DataSourceStatsAccumulator {
  data_source : String
  mut request_count : Int
  mut total_cost_nano : Int64
}

///|
fn UsageSummaryAccumulator::new() -> UsageSummaryAccumulator {
  {
    total_requests: 0,
    success_count: 0,
    total_input_tokens: 0,
    total_output_tokens: 0,
    total_cache_creation_tokens: 0,
    total_cache_read_tokens: 0,
    total_cost_nano: 0L,
  }
}

///|
fn UsageSummaryAccumulator::add(
  self : UsageSummaryAccumulator,
  log : RequestLog,
) -> Unit {
  self.total_requests += 1
  if request_log_is_success(log) {
    self.success_count += 1
  }
  self.total_input_tokens += request_log_fresh_input_tokens(log)
  self.total_output_tokens += log.output_tokens
  self.total_cache_creation_tokens += log.cache_creation_tokens
  self.total_cache_read_tokens += log.cache_read_tokens
  self.total_cost_nano += request_log_total_cost_nano(log)
}

///|
fn UsageSummaryAccumulator::real_total_tokens(
  self : UsageSummaryAccumulator,
) -> Int {
  self.total_input_tokens +
  self.total_output_tokens +
  self.total_cache_creation_tokens +
  self.total_cache_read_tokens
}

///|
fn UsageSummaryAccumulator::success_rate(
  self : UsageSummaryAccumulator,
) -> Double {
  if self.total_requests == 0 {
    0.0
  } else {
    self.success_count.to_double() * 100.0 / self.total_requests.to_double()
  }
}

///|
fn UsageSummaryAccumulator::cache_hit_rate(
  self : UsageSummaryAccumulator,
) -> Double {
  let denominator = self.total_input_tokens +
    self.total_cache_creation_tokens +
    self.total_cache_read_tokens
  if denominator == 0 {
    0.0
  } else {
    self.total_cache_read_tokens.to_double() / denominator.to_double()
  }
}

///|
fn UsageSummaryAccumulator::to_json(self : UsageSummaryAccumulator) -> Json {
  {
    "totalRequests": Json::number(self.total_requests.to_double()),
    "totalCost": Json::string(format_nano_usd_fixed_6(self.total_cost_nano)),
    "totalInputTokens": Json::number(self.total_input_tokens.to_double()),
    "totalOutputTokens": Json::number(self.total_output_tokens.to_double()),
    "totalCacheCreationTokens": Json::number(
      self.total_cache_creation_tokens.to_double(),
    ),
    "totalCacheReadTokens": Json::number(
      self.total_cache_read_tokens.to_double(),
    ),
    "successRate": Json::number(self.success_rate()),
    "realTotalTokens": Json::number(self.real_total_tokens().to_double()),
    "cacheHitRate": Json::number(self.cache_hit_rate()),
  }.to_json()
}

///|
fn ProviderStatsAccumulator::new(log : RequestLog) -> ProviderStatsAccumulator {
  {
    provider_id: log.provider_id,
    provider_name: request_log_provider_name(log),
    request_count: 0,
    success_count: 0,
    total_tokens: 0,
    total_cost_nano: 0L,
    total_latency_ms: 0,
  }
}

///|
fn ProviderStatsAccumulator::add(
  self : ProviderStatsAccumulator,
  log : RequestLog,
) -> Unit {
  self.request_count += 1
  if request_log_is_success(log) {
    self.success_count += 1
  }
  self.total_tokens += request_log_fresh_input_tokens(log) + log.output_tokens
  self.total_cost_nano += request_log_total_cost_nano(log)
  self.total_latency_ms += log.latency_ms
}

///|
fn ProviderStatsAccumulator::success_rate(
  self : ProviderStatsAccumulator,
) -> Double {
  if self.request_count == 0 {
    0.0
  } else {
    self.success_count.to_double() * 100.0 / self.request_count.to_double()
  }
}

///|
fn ProviderStatsAccumulator::avg_latency_ms(
  self : ProviderStatsAccumulator,
) -> Int {
  if self.request_count == 0 {
    0
  } else {
    self.total_latency_ms / self.request_count
  }
}

///|
fn ProviderStatsAccumulator::to_json(self : ProviderStatsAccumulator) -> Json {
  {
    "providerId": Json::string(self.provider_id),
    "providerName": Json::string(self.provider_name),
    "requestCount": Json::number(self.request_count.to_double()),
    "totalTokens": Json::number(self.total_tokens.to_double()),
    "totalCost": Json::string(format_nano_usd_fixed_6(self.total_cost_nano)),
    "successRate": Json::number(self.success_rate()),
    "avgLatencyMs": Json::number(self.avg_latency_ms().to_double()),
  }.to_json()
}

///|
fn ModelStatsAccumulator::new(model : String) -> ModelStatsAccumulator {
  { model, request_count: 0, total_tokens: 0, total_cost_nano: 0L }
}

///|
fn ModelStatsAccumulator::add(
  self : ModelStatsAccumulator,
  log : RequestLog,
) -> Unit {
  self.request_count += 1
  self.total_tokens += request_log_fresh_input_tokens(log) + log.output_tokens
  self.total_cost_nano += request_log_total_cost_nano(log)
}

///|
fn ModelStatsAccumulator::avg_cost_per_request(
  self : ModelStatsAccumulator,
) -> String {
  if self.request_count == 0 {
    "0.000000"
  } else {
    format_nano_usd_fixed_6(
      divide_rounded(self.total_cost_nano, self.request_count.to_int64()),
    )
  }
}

///|
fn ModelStatsAccumulator::to_json(self : ModelStatsAccumulator) -> Json {
  {
    "model": Json::string(self.model),
    "requestCount": Json::number(self.request_count.to_double()),
    "totalTokens": Json::number(self.total_tokens.to_double()),
    "totalCost": Json::string(format_nano_usd_fixed_6(self.total_cost_nano)),
    "avgCostPerRequest": Json::string(self.avg_cost_per_request()),
  }.to_json()
}

///|
fn DataSourceStatsAccumulator::new(
  data_source : String,
) -> DataSourceStatsAccumulator {
  { data_source, request_count: 0, total_cost_nano: 0L }
}

///|
fn DataSourceStatsAccumulator::add(
  self : DataSourceStatsAccumulator,
  log : RequestLog,
) -> Unit {
  self.request_count += 1
  self.total_cost_nano += request_log_total_cost_nano(log)
}

///|
fn DataSourceStatsAccumulator::to_json(
  self : DataSourceStatsAccumulator,
) -> Json {
  {
    "dataSource": Json::string(self.data_source),
    "requestCount": Json::number(self.request_count.to_double()),
    "totalCostUsd": Json::string(format_nano_usd_fixed_6(self.total_cost_nano)),
  }.to_json()
}

///|
fn request_log_matches_app(log : RequestLog, app_type : String?) -> Bool {
  match app_type {
    Some(filter) if !filter.is_empty() => log.app_type == filter
    _ => true
  }
}

///|
fn request_log_matches_usage_aggregate(
  log : RequestLog,
  start_date : Int?,
  end_date : Int?,
  app_type : String?,
) -> Bool {
  if !request_log_matches_app(log, app_type) {
    return false
  }
  match start_date {
    Some(start) if log.created_at < start => return false
    _ => ()
  }
  match end_date {
    Some(end) if log.created_at > end => return false
    _ => ()
  }
  true
}

///|
fn request_log_matches_filters(
  log : RequestLog,
  filters : RequestLogFilters,
) -> Bool {
  if !request_log_matches_app(log, filters.app_type) {
    return false
  }
  match filters.provider_name {
    Some(filter) =>
      if !request_log_provider_name_matches_ccs_filter(log, filter) {
        return false
      }
    _ => ()
  }
  match filters.model {
    Some(filter) if !request_log_text_contains(log.model, filter) =>
      return false
    _ => ()
  }
  match filters.status_code {
    Some(status) if log.status_code != status => return false
    _ => ()
  }
  match filters.start_date {
    Some(start) if log.created_at < start => return false
    _ => ()
  }
  match filters.end_date {
    Some(end) if log.created_at > end => return false
    _ => ()
  }
  true
}

///|
fn request_log_text_contains(value : String, needle : String) -> Bool {
  needle.is_empty() || value.to_lower().contains(needle.to_lower())
}

///|
fn request_log_provider_name_matches_ccs_filter(
  log : RequestLog,
  needle : String,
) -> Bool {
  match log.provider_name {
    Some(provider_name) => request_log_text_contains(provider_name, needle)
    None => false
  }
}

///|
fn request_log_min_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn RequestLog::to_ccs_request_log_detail_json(self : RequestLog) -> Json {
  let obj : Map[String, Json] = {
    "requestId": Json::string(self.request_id),
    "providerId": Json::string(self.provider_id),
    "providerName": Json::string(request_log_provider_name(self)),
    "appType": Json::string(self.app_type),
    "model": Json::string(self.model),
    "costMultiplier": Json::string(self.cost_multiplier),
    "inputTokens": Json::number(self.input_tokens.to_double()),
    "outputTokens": Json::number(self.output_tokens.to_double()),
    "cacheReadTokens": Json::number(self.cache_read_tokens.to_double()),
    "cacheCreationTokens": Json::number(self.cache_creation_tokens.to_double()),
    "inputCostUsd": Json::string(self.input_cost_usd),
    "outputCostUsd": Json::string(self.output_cost_usd),
    "cacheReadCostUsd": Json::string(self.cache_read_cost_usd),
    "cacheCreationCostUsd": Json::string(self.cache_creation_cost_usd),
    "totalCostUsd": Json::string(self.total_cost_usd),
    "isStreaming": Json::boolean(self.is_streaming),
    "latencyMs": Json::number(self.latency_ms.to_double()),
    "firstTokenMs": optional_int_json(self.first_token_ms),
    "durationMs": optional_int_json(self.duration_ms),
    "statusCode": Json::number(self.status_code.to_double()),
    "errorMessage": optional_string_json(self.error_message),
    "createdAt": Json::number(self.created_at.to_double()),
  }
  match self.request_model {
    Some(model) => obj.set("requestModel", Json::string(model))
    None => ()
  }
  if !self.data_source.is_empty() {
    obj.set("dataSource", Json::string(request_log_data_source(self)))
  }
  match self.pricing_model {
    Some(model) => obj.set("pricingModel", Json::string(model))
    None => ()
  }
  Json::object(obj)
}

///|
fn request_log_provider_name(log : RequestLog) -> String {
  match log.provider_name {
    Some(name) if !name.is_empty() => name
    _ =>
      match log.provider_id {
        "_session" => "Claude (Session)"
        "_codex_session" => "Codex (Session)"
        "_gemini_session" => "Gemini (Session)"
        "_opencode_session" => "OpenCode (Session)"
        provider_id => provider_id
      }
  }
}

///|
fn TrafficStats::effective_request_log_count(self : TrafficStats) -> Int {
  let mut count = 0
  for log in self.request_logs {
    if self.request_log_is_effective(log) {
      count += 1
    }
  }
  count
}

///|
fn TrafficStats::request_log_is_effective(
  self : TrafficStats,
  log : RequestLog,
) -> Bool {
  let source = request_log_data_source(log)
  if !request_log_is_session_import_source(source) {
    return true
  }
  for proxy in self.request_logs {
    if request_logs_match_proxy_dedup(proxy, log, source) {
      return false
    }
  }
  true
}

///|
fn request_log_data_source(log : RequestLog) -> String {
  if log.data_source.is_empty() {
    "proxy"
  } else {
    log.data_source
  }
}

///|
fn request_log_is_session_import_source(source : String) -> Bool {
  source == "session_log" ||
  source == "codex_session" ||
  source == "gemini_session" ||
  source == "opencode_session"
}

///|
fn request_log_allows_missing_cache_creation(
  source : String,
  session : RequestLog,
) -> Bool {
  session.cache_creation_tokens == 0 &&
  (
    source == "codex_session" ||
    source == "gemini_session" ||
    source == "opencode_session"
  )
}

///|
fn request_logs_match_proxy_dedup(
  proxy : RequestLog,
  session : RequestLog,
  session_source : String,
) -> Bool {
  let cache_creation_matches = proxy.cache_creation_tokens ==
    session.cache_creation_tokens ||
    request_log_allows_missing_cache_creation(session_source, session)
  request_log_data_source(proxy) == "proxy" &&
  request_log_is_success(proxy) &&
  proxy.app_type == session.app_type &&
  session_models_match(proxy.model, session.model) &&
  proxy.input_tokens == session.input_tokens &&
  proxy.output_tokens == session.output_tokens &&
  proxy.cache_read_tokens == session.cache_read_tokens &&
  cache_creation_matches &&
  session_abs_int(proxy.created_at - session.created_at) <=
  SESSION_PROXY_DEDUP_WINDOW_SECONDS
}

///|
fn request_log_is_success(log : RequestLog) -> Bool {
  log.status_code >= 200 && log.status_code < 300
}

///|
fn request_log_fresh_input_tokens(log : RequestLog) -> Int {
  if (log.app_type == "codex" || log.app_type == "gemini") &&
    log.input_tokens >= log.cache_read_tokens {
    log.input_tokens - log.cache_read_tokens
  } else {
    log.input_tokens
  }
}

///|
fn request_log_total_cost_nano(log : RequestLog) -> Int64 {
  parse_decimal_scaled(log.total_cost_usd, NANO_USD_SCALE)
}

///|
fn request_log_pricing_model(log : RequestLog) -> String {
  match log.pricing_model {
    Some(model) if !model.is_empty() => model
    _ => log.model
  }
}

///|
fn TrafficStats::finish_request(self : TrafficStats) -> Unit {
  if self.active_connections > 0 {
    self.active_connections -= 1
  }
  self.current_request_id = None
  self.current_request_started_at_ms = None
  self.current_request_app_type = None
  self.current_request_model = None
  self.current_request_session_id = None
  self.current_request_provider_type = None
  self.current_request_is_streaming = false
  self.current_request_used_half_open_permit = false
}

///|
fn optional_string_json(value : String?) -> Json {
  match value {
    Some(v) => Json::string(v)
    None => Json::null()
  }
}

///|
fn optional_int_json(value : Int?) -> Json {
  match value {
    Some(v) => Json::number(v.to_double())
    None => Json::null()
  }
}

///|
fn TrafficStats::success_rate(self : TrafficStats) -> Double {
  if self.total_requests == 0 {
    0.0
  } else {
    self.successful_responses.to_double() *
    100.0 /
    self.total_requests.to_double()
  }
}

///|
pub fn TrafficStats::to_json(self : TrafficStats) -> Json {
  {
    "active_connections": Json::number(self.active_connections.to_double()),
    "total_requests": Json::number(self.total_requests.to_double()),
    "message_requests": Json::number(self.message_requests.to_double()),
    "streaming_requests": Json::number(self.streaming_requests.to_double()),
    "non_streaming_requests": Json::number(
      self.non_streaming_requests.to_double(),
    ),
    "successful_responses": Json::number(self.successful_responses.to_double()),
    "failed_responses": Json::number(self.failed_responses.to_double()),
    "success_requests": Json::number(self.successful_responses.to_double()),
    "failed_requests": Json::number(self.failed_responses.to_double()),
    "success_rate": Json::number(self.success_rate()),
    "unauthorized_responses": Json::number(
      self.unauthorized_responses.to_double(),
    ),
    "bad_requests": Json::number(self.bad_requests.to_double()),
    "upstream_errors": Json::number(self.upstream_errors.to_double()),
    "input_tokens": Json::number(self.input_tokens.to_double()),
    "output_tokens": Json::number(self.output_tokens.to_double()),
    "cache_read_tokens": Json::number(self.cache_read_tokens.to_double()),
    "cache_creation_tokens": Json::number(
      self.cache_creation_tokens.to_double(),
    ),
    "request_bytes": Json::number(self.request_bytes.to_double()),
    "response_bytes": Json::number(self.response_bytes.to_double()),
    "last_request_at": optional_string_json(self.last_request_at),
    "last_error": optional_string_json(self.last_error),
    "recent_request_log_count": Json::number(
      self.request_logs.length().to_double(),
    ),
  }.to_json()
}

///|
pub fn TrafficStats::status_json(
  self : TrafficStats,
  address : String,
  port : Int,
  uptime_seconds : Int,
  provider_routes? : Json? = None,
) -> Json {
  let status : Map[String, Json] = {
    "running": Json::boolean(true),
    "address": Json::string(address),
    "port": Json::number(port.to_double()),
    "active_connections": Json::number(self.active_connections.to_double()),
    "total_requests": Json::number(self.total_requests.to_double()),
    "success_requests": Json::number(self.successful_responses.to_double()),
    "failed_requests": Json::number(self.failed_responses.to_double()),
    "success_rate": Json::number(self.success_rate()),
    "uptime_seconds": Json::number(uptime_seconds.to_double()),
    "current_provider": optional_string_json(self.current_provider),
    "current_provider_id": optional_string_json(self.current_provider_id),
    "last_request_at": optional_string_json(self.last_request_at),
    "last_error": optional_string_json(self.last_error),
    "failover_count": Json::number(self.failover_count.to_double()),
    "active_targets": active_targets_json(self.active_targets),
  }
  if provider_routes is Some(routes) {
    status["provider_routes"] = routes
  }
  status.to_json()
}

///|
fn active_target_json(target : ActiveTarget) -> Json {
  {
    "app_type": Json::string(target.app_type),
    "provider_id": Json::string(target.provider_id),
    "provider_name": Json::string(target.provider_name),
  }.to_json()
}

///|
fn active_targets_json(targets : Map[String, ActiveTarget]) -> Json {
  let values : Array[Json] = []
  for target in targets.values() {
    values.push(active_target_json(target))
  }
  Json::array(values)
}

///|
fn generate_request_log_id() -> String {
  let gen = @uuid.generator(@random.Rand::new())
  let uuid = gen.v4()
  "req_\{uuid}"
}
