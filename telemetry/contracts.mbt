///|
pub fn telemetry_contract_v1() -> String {
  "moongate.request-telemetry.v1"
}

///|
pub fn monitor_snapshot_contract_v1() -> String {
  "moongate.operations-monitor.v1"
}

///|
pub(all) enum TerminalOutcomeV1 {
  Success
  Timeout
  RateLimited
  Cancelled
  ProtocolClientError
  UpstreamError
  Unknown
} derive(Debug, Eq)

///|
pub fn TerminalOutcomeV1::id(self : TerminalOutcomeV1) -> String {
  match self {
    Success => "success"
    Timeout => "timeout"
    RateLimited => "rate-limit"
    Cancelled => "cancelled"
    ProtocolClientError => "protocol-client-error"
    UpstreamError => "upstream-error"
    Unknown => "unknown"
  }
}

///|
pub fn parse_terminal_outcome_v1(value : String) -> TerminalOutcomeV1? {
  match value {
    "success" => Some(Success)
    "timeout" => Some(Timeout)
    "rate-limit" => Some(RateLimited)
    "cancelled" => Some(Cancelled)
    "protocol-client-error" => Some(ProtocolClientError)
    "upstream-error" => Some(UpstreamError)
    "unknown" => Some(Unknown)
    _ => None
  }
}

///|
pub impl ToJson for TerminalOutcomeV1 with to_json(
  self : TerminalOutcomeV1,
) -> Json {
  Json::string(self.id())
}

///|
pub impl @json.FromJson for TerminalOutcomeV1 with from_json(
  value : Json,
  path : @json.JsonPath,
) -> TerminalOutcomeV1 raise @json.JsonDecodeError {
  guard value is String(id) && parse_terminal_outcome_v1(id) is Some(outcome) else {
    raise @json.JsonDecodeError((path, "TerminalOutcomeV1: unsupported value"))
  }
  outcome
}

///|
pub(all) enum CircuitStateV1 {
  Closed
  Open
  HalfOpen
  Unsupported
} derive(Debug, Eq)

///|
pub fn CircuitStateV1::id(self : CircuitStateV1) -> String {
  match self {
    Closed => "closed"
    Open => "open"
    HalfOpen => "half-open"
    Unsupported => "unsupported"
  }
}

///|
pub fn parse_circuit_state_v1(value : String) -> CircuitStateV1? {
  match value {
    "closed" => Some(Closed)
    "open" => Some(Open)
    "half-open" => Some(HalfOpen)
    "unsupported" => Some(Unsupported)
    _ => None
  }
}

///|
pub impl ToJson for CircuitStateV1 with to_json(
  self : CircuitStateV1,
) -> Json {
  Json::string(self.id())
}

///|
pub impl @json.FromJson for CircuitStateV1 with from_json(
  value : Json,
  path : @json.JsonPath,
) -> CircuitStateV1 raise @json.JsonDecodeError {
  guard value is String(id) && parse_circuit_state_v1(id) is Some(state) else {
    raise @json.JsonDecodeError((path, "CircuitStateV1: unsupported value"))
  }
  state
}

///|
pub(all) struct RequestTelemetryV1 {
  contract_id : String
  request_id : String
  attempt_id : String
  app_type : String
  provider_id : String
  model : String?
  accepted_at_ms : Int64
  queued_at_ms : Int64?
  permit_acquired_at_ms : Int64?
  connect_started_at_ms : Int64?
  connected_at_ms : Int64?
  first_token_at_ms : Int64?
  completed_at_ms : Int64?
  connect_ms : Int?
  latency_ms : Int
  first_token_ms : Int?
  completion_ms : Int?
  success : Bool
  terminal_outcome : TerminalOutcomeV1
  terminal_detail : String?
  retry_count : Int
  failover_count : Int
  failover_chain : Array[String]
  input_tokens : Int
  output_tokens : Int
  output_tokens_per_second_milli : Int?
  queue_depth_at_accept : Int?
  queue_supported : Bool
  permit_wait_ms : Int?
  permit_supported : Bool
  quota_headroom_nano_usd : Int64?
  quota_supported : Bool
  budget_headroom_nano_usd : Int64?
  budget_supported : Bool
  circuit_state : CircuitStateV1
  policy_id : String?
  policy_revision : Int?
  storage_healthy : Bool
  evidence_fresh : Bool
  evidence_age_ms : Int64?
  cost_nano_usd : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct TerminalOutcomeCountV1 {
  outcome : TerminalOutcomeV1
  count : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct PercentileSnapshotV1 {
  sample_count : Int
  p50_ms : Int?
  p95_ms : Int?
  p99_ms : Int?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct NumericPercentileSnapshotV1 {
  sample_count : Int
  p50 : Int?
  p95 : Int?
  p99 : Int?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ActivePolicyObservationV1 {
  app_type : String
  policy_id : String
  policy_revision : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct MonitorSnapshotV1 {
  contract_id : String
  observed_at_ms : Int64
  latency : PercentileSnapshotV1
  first_token : PercentileSnapshotV1
  permit_wait : PercentileSnapshotV1
  throughput_tokens_per_second_milli : NumericPercentileSnapshotV1
  terminal_outcome_counts : Array[TerminalOutcomeCountV1]
  recent_input_tokens : Int
  recent_output_tokens : Int
  inflight_requests : Int
  queue_depth : Int
  queue_supported : Bool
  permit_supported : Bool
  quota_configured_count : Int
  quota_exceeded_count : Int
  quota_headroom_nano_usd : Int64?
  quota_headroom_supported : Bool
  budget_headroom_nano_usd : Int64?
  budget_headroom_supported : Bool
  recent_cost_nano_usd : Int64
  circuit_open_count : Int
  circuit_half_open_count : Int
  failover_count : Int
  active_policies : Array[ActivePolicyObservationV1]
  storage_healthy : Bool
  storage_failure_count : Int
  evidence_fresh : Bool
  newest_evidence_age_ms : Int64?
  oldest_evidence_age_ms : Int64?
} derive(Debug, Eq, ToJson, FromJson)
