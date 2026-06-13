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
  mut last_request_at : String?
  mut last_error : String?
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
    last_request_at: None,
    last_error: None,
  }
}

///|
pub fn TrafficStats::record_inbound(
  self : TrafficStats,
  request_bytes : Int,
) -> Unit {
  self.total_requests += 1
  self.message_requests += 1
  self.active_connections += 1
  self.request_bytes += request_bytes
  self.last_request_at = Some(@async.now().to_string())
  self.last_error = None
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
}

///|
pub fn TrafficStats::record_bad_request(self : TrafficStats) -> Unit {
  self.bad_requests += 1
  self.failed_responses += 1
  self.last_error = Some("bad_request")
  self.finish_request()
}

///|
pub fn TrafficStats::record_unauthorized(self : TrafficStats) -> Unit {
  self.unauthorized_responses += 1
  self.failed_responses += 1
  self.last_error = Some("unauthorized")
  self.finish_request()
}

///|
pub fn TrafficStats::record_upstream_error(
  self : TrafficStats,
  response_bytes : Int,
) -> Unit {
  self.upstream_errors += 1
  self.failed_responses += 1
  self.response_bytes += response_bytes
  self.last_error = Some("upstream_error")
  self.finish_request()
}

///|
pub fn TrafficStats::record_internal_error(self : TrafficStats) -> Unit {
  self.failed_responses += 1
  self.last_error = Some("internal_error")
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
  self.finish_request()
}

///|
fn TrafficStats::finish_request(self : TrafficStats) -> Unit {
  if self.active_connections > 0 {
    self.active_connections -= 1
  }
}

///|
fn optional_string_json(value : String?) -> Json {
  match value {
    Some(v) => Json::string(v)
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
  }.to_json()
}

///|
pub fn TrafficStats::status_json(
  self : TrafficStats,
  address : String,
  port : Int,
  uptime_seconds : Int,
  current_provider : String,
  current_provider_id : String,
  app_type : String,
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
    "current_provider": Json::string(current_provider),
    "current_provider_id": Json::string(current_provider_id),
    "last_request_at": optional_string_json(self.last_request_at),
    "last_error": optional_string_json(self.last_error),
    "failover_count": Json::number(0.0),
    "active_targets": Json::array([
      active_target_json(app_type, current_provider_id, current_provider),
    ]),
  }.to_json()
}

///|
fn active_target_json(
  app_type : String,
  provider_id : String,
  provider_name : String,
) -> Json {
  {
    "app_type": Json::string(app_type),
    "provider_id": Json::string(provider_id),
    "provider_name": Json::string(provider_name),
  }.to_json()
}
