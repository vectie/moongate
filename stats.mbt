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
  created_at? : Int = @async.now().to_int() / 1000,
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
  mut last_request_at : String?
  mut last_error : String?
  request_logs : Array[RequestLog]
  mut current_request_id : String?
  mut current_request_started_at_ms : Int?
  mut current_request_app_type : String?
  mut current_request_model : String?
  mut current_request_session_id : String?
  mut current_request_provider_type : String?
  mut current_request_is_streaming : Bool
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
    last_request_at: None,
    last_error: None,
    request_logs: [],
    current_request_id: None,
    current_request_started_at_ms: None,
    current_request_app_type: None,
    current_request_model: None,
    current_request_session_id: None,
    current_request_provider_type: None,
    current_request_is_streaming: false,
  }
}

///|
pub fn TrafficStats::set_active_target(
  self : TrafficStats,
  app_type : String,
  provider_id : String,
  provider_name : String,
) -> Unit {
  match self.active_targets.get(app_type) {
    Some(target) if target.provider_id != provider_id =>
      self.failover_count += 1
    _ => ()
  }
  self.current_provider = Some(provider_name)
  self.current_provider_id = Some(provider_id)
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
  self.current_request_is_streaming = false
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
pub fn TrafficStats::record_success_usage(
  self : TrafficStats,
  usage : TokenUsage,
  response_bytes : Int,
) -> Unit {
  self.successful_responses += 1
  self.input_tokens += usage.input_tokens
  self.output_tokens += usage.output_tokens
  self.cache_read_tokens += usage.cache_read_tokens
  self.cache_creation_tokens += usage.cache_creation_tokens
  self.response_bytes += response_bytes
  self.last_error = None
  self.record_completed_request(200, usage, None)
  self.finish_request()
}

///|
fn TrafficStats::record_completed_request(
  self : TrafficStats,
  status_code : Int,
  usage : TokenUsage,
  error_message : String?,
) -> Unit {
  guard self.current_request_id is Some(request_id) else { return }
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
  self.record_request_log(
    RequestLog::new(
      request_id~,
      provider_id=self.current_provider_id.unwrap_or("unknown"),
      provider_name=self.current_provider,
      app_type=self.current_request_app_type.unwrap_or("unknown"),
      model~,
      request_model~,
      pricing_model=Some(model),
      usage~,
      status_code~,
      latency_ms~,
      duration_ms=Some(latency_ms),
      error_message~,
      session_id=self.current_request_session_id,
      provider_type=self.current_request_provider_type,
      is_streaming=self.current_request_is_streaming,
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
pub fn TrafficStats::request_logs_json(
  self : TrafficStats,
  limit? : Int = 100,
) -> Json {
  let logs : Array[Json] = []
  let len = self.request_logs.length()
  let bounded_limit = if limit < 0 { 0 } else { limit }
  let start = max_int(len - bounded_limit, 0)
  for i in start..<len {
    logs.push(self.request_logs[i].to_json())
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
    "total": Json::number(self.request_logs.length().to_double()),
    "limit": Json::number((if limit < 0 { 0 } else { limit }).to_double()),
    "source": Json::string("memory"),
    "table": Json::string("proxy_request_logs"),
  }.to_json()
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
) -> Json {
  {
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
  }.to_json()
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
