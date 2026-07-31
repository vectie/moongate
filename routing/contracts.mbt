///|
pub fn routing_policy_contract_v1() -> String {
  "moongate.routing-policy.v1"
}

///|
pub fn routing_decision_contract_v1() -> String {
  "moongate.routing-decision.v1"
}

///|
pub fn routing_activation_receipt_contract_v1() -> String {
  "moongate.routing-policy-activation-receipt.v1"
}

///|
pub(all) enum RoutingMode {
  Priority
  SmoothWeightedRoundRobin
  LeastInflight
  SessionSticky
} derive(Debug, Eq)

///|
pub fn RoutingMode::to_string(self : RoutingMode) -> String {
  match self {
    Priority => "priority"
    SmoothWeightedRoundRobin => "smooth-weighted-round-robin"
    LeastInflight => "least-inflight"
    SessionSticky => "session-sticky"
  }
}

///|
pub fn parse_routing_mode(value : String) -> RoutingMode? {
  match value.trim().to_lower() {
    "priority" => Some(Priority)
    "smooth-weighted-round-robin" | "smooth_weighted_round_robin" | "swrr" =>
      Some(SmoothWeightedRoundRobin)
    "least-inflight" | "least_inflight" => Some(LeastInflight)
    "session-sticky" | "session_sticky" => Some(SessionSticky)
    _ => None
  }
}

///|
pub impl ToJson for RoutingMode with to_json(self : RoutingMode) -> Json {
  Json::string(self.to_string())
}

///|
pub impl @json.FromJson for RoutingMode with from_json(
  value : Json,
  path : @json.JsonPath,
) -> RoutingMode raise @json.JsonDecodeError {
  guard value is String(id) else {
    raise @json.JsonDecodeError((path, "RoutingMode: expected string"))
  }
  match id {
    "priority" => Priority
    "smooth-weighted-round-robin" => SmoothWeightedRoundRobin
    "least-inflight" => LeastInflight
    "session-sticky" => SessionSticky
    _ => raise @json.JsonDecodeError((path, "RoutingMode: unsupported value"))
  }
}

///|
pub(all) enum RoutingDecisionReasonV1 {
  HighestPriorityEligible
  LeastInflightEligible
  SmoothWeightedRoundRobinSelection
  ExistingSessionBinding
  NewSessionWeightedSelection
  NoEligibleProvider
} derive(Debug, Eq)

///|
pub fn RoutingDecisionReasonV1::id(self : RoutingDecisionReasonV1) -> String {
  match self {
    HighestPriorityEligible => "highest-priority-eligible"
    LeastInflightEligible => "least-inflight-eligible"
    SmoothWeightedRoundRobinSelection => "smooth-weighted-round-robin"
    ExistingSessionBinding => "existing-session-binding"
    NewSessionWeightedSelection => "new-session-weighted-selection"
    NoEligibleProvider => "no-eligible-provider"
  }
}

///|
pub impl ToJson for RoutingDecisionReasonV1 with to_json(
  self : RoutingDecisionReasonV1,
) -> Json {
  Json::string(self.id())
}

///|
pub impl @json.FromJson for RoutingDecisionReasonV1 with from_json(
  value : Json,
  path : @json.JsonPath,
) -> RoutingDecisionReasonV1 raise @json.JsonDecodeError {
  guard value is String(id) else {
    raise @json.JsonDecodeError((path, "RoutingDecisionReasonV1: expected string"))
  }
  match id {
    "highest-priority-eligible" => HighestPriorityEligible
    "least-inflight-eligible" => LeastInflightEligible
    "smooth-weighted-round-robin" => SmoothWeightedRoundRobinSelection
    "existing-session-binding" => ExistingSessionBinding
    "new-session-weighted-selection" => NewSessionWeightedSelection
    "no-eligible-provider" => NoEligibleProvider
    _ =>
      raise @json.JsonDecodeError(
        (path, "RoutingDecisionReasonV1: unsupported value"),
      )
  }
}

///|
pub(all) enum RoutingActivationActionV1 {
  Activate
  Rollback
} derive(Debug, Eq)

///|
pub fn RoutingActivationActionV1::id(
  self : RoutingActivationActionV1,
) -> String {
  match self {
    Activate => "activate"
    Rollback => "rollback"
  }
}

///|
pub impl ToJson for RoutingActivationActionV1 with to_json(
  self : RoutingActivationActionV1,
) -> Json {
  Json::string(self.id())
}

///|
pub impl @json.FromJson for RoutingActivationActionV1 with from_json(
  value : Json,
  path : @json.JsonPath,
) -> RoutingActivationActionV1 raise @json.JsonDecodeError {
  guard value is String(id) else {
    raise @json.JsonDecodeError((path, "RoutingActivationActionV1: expected string"))
  }
  match id {
    "activate" => Activate
    "rollback" => Rollback
    _ =>
      raise @json.JsonDecodeError(
        (path, "RoutingActivationActionV1: unsupported value"),
      )
  }
}

///|
pub(all) enum RoutingActivationScopeV1 {
  BoundedCanary
  RollbackScope
} derive(Debug, Eq)

///|
pub fn RoutingActivationScopeV1::id(
  self : RoutingActivationScopeV1,
) -> String {
  match self {
    BoundedCanary => "bounded-canary"
    RollbackScope => "rollback"
  }
}

///|
pub impl ToJson for RoutingActivationScopeV1 with to_json(
  self : RoutingActivationScopeV1,
) -> Json {
  Json::string(self.id())
}

///|
pub impl @json.FromJson for RoutingActivationScopeV1 with from_json(
  value : Json,
  path : @json.JsonPath,
) -> RoutingActivationScopeV1 raise @json.JsonDecodeError {
  guard value is String(id) else {
    raise @json.JsonDecodeError((path, "RoutingActivationScopeV1: expected string"))
  }
  match id {
    "bounded-canary" => BoundedCanary
    "rollback" => RollbackScope
    _ =>
      raise @json.JsonDecodeError(
        (path, "RoutingActivationScopeV1: unsupported value"),
      )
  }
}

///|
pub(all) struct RoutingPolicyV1 {
  contract_id : String
  policy_id : String
  app_type : String
  revision : Int
  mode : RoutingMode
  weights : Map[String, Int]
  concurrency_limits : Map[String, Int]
  minimum_shadow_decisions : Int
  minimum_shadow_window_ms : Int64
  canary_traffic_basis_points : Int
  rollback_error_rate_milli : Int
  rollback_p95_latency_ms : Int
  rollback_minimum_requests : Int
  configured_at_ms : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ProviderCandidateV1 {
  provider_id : String
  priority : Int
  weight : Int
  inflight : Int
  concurrency_limit : Int
  enabled : Bool
  compatible : Bool
  healthy : Bool
  circuit_open : Bool
  quota_exhausted : Bool
  health_evidence_supported : Bool
  health_observed_at_ms : Int64?
  health_fresh : Bool
  credential_evidence_supported : Bool
  credentials_available : Bool
  model_evidence_supported : Bool
  model_supported : Bool
  protocol_evidence_supported : Bool
  protocol_supported : Bool
  budget_evidence_supported : Bool
  budget_available : Bool
  capacity_evidence_supported : Bool
  capacity_available : Bool
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct CandidateReviewV1 {
  provider_id : String
  eligible : Bool
  reasons : Array[String]
  warnings : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct SmoothWeightV1 {
  provider_id : String
  current_weight : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct SmoothStateV1 {
  entries : Array[SmoothWeightV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct RoutingDecisionV1 {
  contract_id : String
  policy_id : String
  policy_revision : Int
  app_type : String
  mode : RoutingMode
  shadow : Bool
  session_key_present : Bool
  decided_at_ms : Int64
  selected_provider_id : String?
  reason : RoutingDecisionReasonV1
  reviews : Array[CandidateReviewV1]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct RoutingPolicyActivationReceiptV1 {
  contract_id : String
  receipt_id : String
  action : RoutingActivationActionV1
  app_type : String
  actor_principal : String
  authority_decision_id : String
  authority_decision_digest : String
  policy_id : String
  policy_revision : Int
  previous_policy_id : String?
  previous_policy_revision : Int?
  activation_scope : RoutingActivationScopeV1
  canary_traffic_basis_points : Int
  minimum_shadow_decisions : Int
  minimum_shadow_window_ms : Int64
  rollback_error_rate_milli : Int
  rollback_p95_latency_ms : Int
  rollback_minimum_requests : Int
  recorded_at_ms : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn policy(
  policy_id~ : String,
  app_type~ : String,
  revision~ : Int,
  mode~ : RoutingMode,
  weights? : Map[String, Int] = Map([], capacity=0),
  concurrency_limits? : Map[String, Int] = Map([], capacity=0),
  minimum_shadow_decisions? : Int = 20,
  minimum_shadow_window_ms? : Int64 = 300_000L,
  canary_traffic_basis_points? : Int = 500,
  rollback_error_rate_milli? : Int = 100,
  rollback_p95_latency_ms? : Int = 30_000,
  rollback_minimum_requests? : Int = 20,
  configured_at_ms~ : Int64,
) -> RoutingPolicyV1 raise {
  if policy_id.trim().is_empty() || app_type.trim().is_empty() || revision < 1 {
    fail("routing policy identity and positive revision are required")
  }
  for provider_id, weight in weights {
    if provider_id.trim().is_empty() || weight < 1 || weight > 1000 {
      fail("routing weights must be between 1 and 1000")
    }
  }
  for provider_id, limit in concurrency_limits {
    if provider_id.trim().is_empty() || limit < 0 {
      fail("routing concurrency limits must be non-negative")
    }
  }
  if minimum_shadow_decisions < 1 || minimum_shadow_decisions > 10_000 ||
    minimum_shadow_window_ms < 0L ||
    canary_traffic_basis_points < 1 || canary_traffic_basis_points > 2500 ||
    rollback_error_rate_milli < 1 || rollback_error_rate_milli > 1000 ||
    rollback_p95_latency_ms < 1 ||
    rollback_minimum_requests < 1 {
    fail("routing evidence, canary, and rollback bounds are invalid")
  }
  {
    contract_id: routing_policy_contract_v1(),
    policy_id,
    app_type,
    revision,
    mode,
    weights,
    concurrency_limits,
    minimum_shadow_decisions,
    minimum_shadow_window_ms,
    canary_traffic_basis_points,
    rollback_error_rate_milli,
    rollback_p95_latency_ms,
    rollback_minimum_requests,
    configured_at_ms,
  }
}

///|
pub fn default_priority_policy(
  app_type : String,
  configured_at_ms : Int64,
) -> RoutingPolicyV1 {
  {
    contract_id: routing_policy_contract_v1(),
    policy_id: "{app_type}.priority.default",
    app_type,
    revision: 1,
    mode: Priority,
    weights: Map([], capacity=0),
    concurrency_limits: Map([], capacity=0),
    minimum_shadow_decisions: 20,
    minimum_shadow_window_ms: 300_000L,
    canary_traffic_basis_points: 500,
    rollback_error_rate_milli: 100,
    rollback_p95_latency_ms: 30_000,
    rollback_minimum_requests: 20,
    configured_at_ms,
  }
}
