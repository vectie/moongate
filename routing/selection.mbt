///|
pub fn empty_smooth_state() -> SmoothStateV1 {
  { entries: [] }
}

///|
pub fn candidate_review(candidate : ProviderCandidateV1) -> CandidateReviewV1 {
  let reasons : Array[String] = []
  let warnings : Array[String] = []
  if !candidate.enabled {
    reasons.push("provider-disabled")
  }
  if !candidate.compatible {
    reasons.push("protocol-incompatible")
  }
  if !candidate.healthy {
    reasons.push("provider-unhealthy")
  }
  if candidate.circuit_open {
    reasons.push("circuit-open")
  }
  if candidate.quota_exhausted {
    reasons.push("quota-exhausted")
  }
  if candidate.health_evidence_supported {
    if !candidate.health_fresh {
      reasons.push("health-evidence-stale")
    }
  } else {
    reasons.push("health-evidence-missing")
  }
  if candidate.credential_evidence_supported &&
    !candidate.credentials_available {
    reasons.push("credentials-unavailable")
  }
  if !candidate.credential_evidence_supported {
    warnings.push("credential-evidence-unsupported")
  }
  if candidate.model_evidence_supported && !candidate.model_supported {
    reasons.push("model-unsupported")
  }
  if !candidate.model_evidence_supported {
    warnings.push("model-evidence-unsupported")
  }
  if candidate.protocol_evidence_supported && !candidate.protocol_supported {
    reasons.push("protocol-unsupported")
  }
  if !candidate.protocol_evidence_supported {
    warnings.push("protocol-evidence-unsupported")
  }
  if candidate.budget_evidence_supported && !candidate.budget_available {
    reasons.push("budget-exhausted")
  }
  if !candidate.budget_evidence_supported {
    warnings.push("budget-evidence-unsupported")
  }
  if candidate.capacity_evidence_supported && !candidate.capacity_available {
    reasons.push("concurrency-limit")
  }
  if !candidate.capacity_evidence_supported {
    warnings.push("capacity-evidence-unsupported")
  }
  {
    provider_id: candidate.provider_id,
    eligible: reasons.is_empty(),
    reasons,
    warnings,
  }
}

///|
fn eligible_candidates(
  candidates : Array[ProviderCandidateV1],
) -> (Array[ProviderCandidateV1], Array[CandidateReviewV1]) {
  let eligible : Array[ProviderCandidateV1] = []
  let reviews : Array[CandidateReviewV1] = []
  for candidate in candidates {
    let review = candidate_review(candidate)
    reviews.push(review)
    if review.eligible {
      eligible.push(candidate)
    }
  }
  eligible.sort_by(fn(left, right) {
    let by_priority = left.priority.compare(right.priority)
    if by_priority != 0 {
      by_priority
    } else {
      left.provider_id.compare(right.provider_id)
    }
  })
  (eligible, reviews)
}

///|
fn smooth_current(state : SmoothStateV1, provider_id : String) -> Int {
  for entry in state.entries {
    if entry.provider_id == provider_id {
      return entry.current_weight
    }
  }
  0
}

///|
fn smooth_select(
  eligible : Array[ProviderCandidateV1],
  state : SmoothStateV1,
) -> (String?, SmoothStateV1) {
  if eligible.is_empty() {
    return (None, empty_smooth_state())
  }
  let next_entries : Array[SmoothWeightV1] = []
  let mut total_weight = 0
  let mut selected_id = eligible[0].provider_id
  let mut selected_weight = -2147483647
  for candidate in eligible {
    let effective_weight = if candidate.weight < 1 { 1 } else { candidate.weight }
    let current = smooth_current(state, candidate.provider_id) + effective_weight
    total_weight += effective_weight
    next_entries.push({ provider_id: candidate.provider_id, current_weight: current })
    if current > selected_weight ||
      (current == selected_weight && candidate.provider_id.compare(selected_id) < 0) {
      selected_id = candidate.provider_id
      selected_weight = current
    }
  }
  let settled = next_entries.map(fn(entry) {
    if entry.provider_id == selected_id {
      { ..entry, current_weight: entry.current_weight - total_weight }
    } else {
      entry
    }
  })
  (Some(selected_id), { entries: settled })
}

///|
fn least_inflight_select(
  eligible : Array[ProviderCandidateV1],
) -> String? {
  if eligible.is_empty() {
    return None
  }
  let ordered = eligible.copy()
  ordered.sort_by(fn(left, right) {
    let by_inflight = left.inflight.compare(right.inflight)
    if by_inflight != 0 {
      by_inflight
    } else {
      let by_priority = left.priority.compare(right.priority)
      if by_priority != 0 {
        by_priority
      } else {
        left.provider_id.compare(right.provider_id)
      }
    }
  })
  Some(ordered[0].provider_id)
}

///|
pub fn select(
  policy : RoutingPolicyV1,
  candidates : Array[ProviderCandidateV1],
  smooth_state : SmoothStateV1,
  shadow~ : Bool,
  sticky_provider_id? : String? = None,
  session_key_present? : Bool = false,
  decided_at_ms~ : Int64,
) -> (RoutingDecisionV1, SmoothStateV1) raise {
  if policy.contract_id != routing_policy_contract_v1() {
    fail("unsupported routing policy contract")
  }
  let mode = policy.mode
  let (eligible, reviews) = eligible_candidates(candidates)
  let (selected, next_state, reason) = match mode {
    Priority =>
      (
        eligible.get(0).map(fn(candidate) { candidate.provider_id }),
        smooth_state,
        HighestPriorityEligible,
      )
    LeastInflight =>
      (least_inflight_select(eligible), smooth_state, LeastInflightEligible)
    SmoothWeightedRoundRobin => {
      let (selected, next) = smooth_select(eligible, smooth_state)
      (selected, next, SmoothWeightedRoundRobinSelection)
    }
    SessionSticky =>
      match sticky_provider_id {
        Some(provider_id) if eligible.any(fn(candidate) {
          candidate.provider_id == provider_id
        }) =>
          (Some(provider_id), smooth_state, ExistingSessionBinding)
        _ => {
          let (selected, next) = smooth_select(eligible, smooth_state)
          (selected, next, NewSessionWeightedSelection)
        }
      }
  }
  (
    {
      contract_id: routing_decision_contract_v1(),
      policy_id: policy.policy_id,
      policy_revision: policy.revision,
      app_type: policy.app_type,
      mode,
      shadow,
      session_key_present,
      decided_at_ms,
      selected_provider_id: selected,
      reason: if selected is Some(_) { reason } else { NoEligibleProvider },
      reviews,
    },
    next_state,
  )
}
