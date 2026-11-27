///|
pub fn telemetry_contract_v1() -> String {
  "moongate.request-telemetry.v1"
}

///|
pub fn monitor_snapshot_contract_v1() -> String {
  "moongate.operations-monitor.v1"
}

///|
#derive(Debug, Eq)
pub(all) enum TerminalOutcomeV1 {
  Success
  Timeout
  RateLimited
  Cancelled
  ProtocolClientError
  UpstreamError
  Unknown
}

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
pub impl ToJson for TerminalOutcomeV1 with fn to_json(self : TerminalOutcomeV1) -> Json {
  Json::string(self.id())
}

///|
pub impl @json.FromJson for TerminalOutcomeV1 with fn from_json(
  value : Json,
  path : @json.JsonPath,
) -> TerminalOutcomeV1 raise @json.JsonDecodeError {
  guard value is String(id) && parse_terminal_outcome_v1(id) is Some(outcome) else {
    raise JsonDecodeError((path, "TerminalOutcomeV1: unsupported value"))
  }
  outcome
}

///|
#derive(Debug, Eq)
pub(all) enum CircuitStateV1 {
  Closed
  Open
  HalfOpen
  Unsupported
}

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
pub impl ToJson for CircuitStateV1 with fn to_json(self : CircuitStateV1) -> Json {
  Json::string(self.id())
}

///|
pub impl @json.FromJson for CircuitStateV1 with fn from_json(
  value : Json,
  path : @json.JsonPath,
) -> CircuitStateV1 raise @json.JsonDecodeError {
  guard value is String(id) && parse_circuit_state_v1(id) is Some(state) else {
    raise JsonDecodeError((path, "CircuitStateV1: unsupported value"))
  }
  state
}

///|
#derive(Debug, Eq, ToJson, FromJson)
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
  connect_ms : Int32?
  latency_ms : Int32
  first_token_ms : Int32?
  completion_ms : Int32?
  success : Bool
  terminal_outcome : TerminalOutcomeV1
  terminal_detail : String?
  retry_count : Int32
  failover_count : Int32
  failover_chain : Array[String]
  input_tokens : Int32
  output_tokens : Int32
  output_tokens_per_second_milli : Int32?
  queue_depth_at_accept : Int32?
  queue_supported : Bool
  permit_wait_ms : Int32?
  permit_supported : Bool
  quota_headroom_nano_usd : Int64?
  quota_supported : Bool
  budget_headroom_nano_usd : Int64?
  budget_supported : Bool
  circuit_state : CircuitStateV1
  policy_id : String?
  policy_revision : Int32?
  storage_healthy : Bool
  evidence_fresh : Bool
  evidence_age_ms : Int64?
  cost_nano_usd : Int64
}

///|
#derive(Debug, Eq, ToJson, FromJson)
pub(all) struct TerminalOutcomeCountV1 {
  outcome : TerminalOutcomeV1
  count : Int32
}

///|
#derive(Debug, Eq, ToJson, FromJson)
pub(all) struct PercentileSnapshotV1 {
  sample_count : Int32
  p50_ms : Int32?
  p95_ms : Int32?
  p99_ms : Int32?
}

///|
#derive(Debug, Eq, ToJson, FromJson)
pub(all) struct NumericPercentileSnapshotV1 {
  sample_count : Int32
  p50 : Int32?
  p95 : Int32?
  p99 : Int32?
}

///|
#derive(Debug, Eq, ToJson, FromJson)
pub(all) struct ActivePolicyObservationV1 {
  app_type : String
  policy_id : String
  policy_revision : Int32
}

///|
#derive(Debug, Eq, ToJson, FromJson)
pub(all) struct MonitorSnapshotV1 {
  contract_id : String
  observed_at_ms : Int64
  latency : PercentileSnapshotV1
  first_token : PercentileSnapshotV1
  permit_wait : PercentileSnapshotV1
  throughput_tokens_per_second_milli : NumericPercentileSnapshotV1
  terminal_outcome_counts : Array[TerminalOutcomeCountV1]
  recent_input_tokens : Int32
  recent_output_tokens : Int32
  inflight_requests : Int32
  queue_depth : Int32
  queue_supported : Bool
  permit_supported : Bool
  quota_configured_count : Int32
  quota_exceeded_count : Int32
  quota_headroom_nano_usd : Int64?
  quota_headroom_supported : Bool
  budget_headroom_nano_usd : Int64?
  budget_headroom_supported : Bool
  recent_cost_nano_usd : Int64
  circuit_open_count : Int32
  circuit_half_open_count : Int32
  failover_count : Int32
  active_policies : Array[ActivePolicyObservationV1]
  storage_healthy : Bool
  storage_failure_count : Int32
  evidence_fresh : Bool
  newest_evidence_age_ms : Int64?
  oldest_evidence_age_ms : Int64?
}

///|
pub extend TerminalOutcomeV1 with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TerminalOutcomeV1 with Eq::{not_equal, equal}

///|
pub extend TerminalOutcomeV1 with ToJson::{to_json}

///|
pub extend TerminalOutcomeV1 with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend CircuitStateV1 with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CircuitStateV1 with Eq::{not_equal, equal}

///|
pub extend CircuitStateV1 with ToJson::{to_json}

///|
pub extend CircuitStateV1 with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend RequestTelemetryV1 with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RequestTelemetryV1 with Eq::{not_equal, equal}

///|
pub extend RequestTelemetryV1 with ToJson::{to_json}

///|
pub extend RequestTelemetryV1 with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend TerminalOutcomeCountV1 with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TerminalOutcomeCountV1 with Eq::{not_equal, equal}

///|
pub extend TerminalOutcomeCountV1 with ToJson::{to_json}

///|
pub extend TerminalOutcomeCountV1 with @moonbitlang/core/json.FromJson::{
  from_json,
}

///|
pub extend PercentileSnapshotV1 with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PercentileSnapshotV1 with Eq::{not_equal, equal}

///|
pub extend PercentileSnapshotV1 with ToJson::{to_json}

///|
pub extend PercentileSnapshotV1 with @moonbitlang/core/json.FromJson::{
  from_json,
}

///|
pub extend NumericPercentileSnapshotV1 with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend NumericPercentileSnapshotV1 with Eq::{not_equal, equal}

///|
pub extend NumericPercentileSnapshotV1 with ToJson::{to_json}

///|
pub extend NumericPercentileSnapshotV1 with @moonbitlang/core/json.FromJson::{
  from_json,
}

///|
pub extend ActivePolicyObservationV1 with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend ActivePolicyObservationV1 with Eq::{not_equal, equal}

///|
pub extend ActivePolicyObservationV1 with ToJson::{to_json}

///|
pub extend ActivePolicyObservationV1 with @moonbitlang/core/json.FromJson::{
  from_json,
}

///|
pub extend MonitorSnapshotV1 with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MonitorSnapshotV1 with Eq::{not_equal, equal}

///|
pub extend MonitorSnapshotV1 with ToJson::{to_json}

///|
pub extend MonitorSnapshotV1 with @moonbitlang/core/json.FromJson::{from_json}
