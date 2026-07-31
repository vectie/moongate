///|
pub fn percentile_snapshot(samples : Array[Int]) -> PercentileSnapshotV1 {
  let ordered = samples.copy()
  ordered.sort()
  {
    sample_count: ordered.length(),
    p50_ms: nearest_rank(ordered, 50),
    p95_ms: nearest_rank(ordered, 95),
    p99_ms: nearest_rank(ordered, 99),
  }
}

///|
pub fn numeric_percentile_snapshot(
  samples : Array[Int],
) -> NumericPercentileSnapshotV1 {
  let ordered = samples.copy()
  ordered.sort()
  {
    sample_count: ordered.length(),
    p50: nearest_rank(ordered, 50),
    p95: nearest_rank(ordered, 95),
    p99: nearest_rank(ordered, 99),
  }
}

///|
fn nearest_rank(ordered : Array[Int], percentile : Int) -> Int? {
  if ordered.is_empty() {
    return None
  }
  let bounded = if percentile < 1 {
    1
  } else if percentile > 100 {
    100
  } else {
    percentile
  }
  let rank = (bounded * ordered.length() + 99) / 100
  ordered.get(rank - 1)
}

///|
pub fn monitor_snapshot(
  observed_at_ms~ : Int64,
  latency_samples_ms~ : Array[Int],
  first_token_samples_ms~ : Array[Int],
  permit_wait_samples_ms? : Array[Int] = [],
  throughput_samples_milli? : Array[Int] = [],
  terminal_outcome_counts? : Array[TerminalOutcomeCountV1] = [],
  recent_input_tokens? : Int = 0,
  recent_output_tokens? : Int = 0,
  inflight_requests~ : Int,
  queue_depth? : Int = 0,
  queue_supported? : Bool = false,
  permit_supported? : Bool = false,
  quota_configured_count? : Int = 0,
  quota_exceeded_count? : Int = 0,
  quota_headroom_nano_usd? : Int64? = None,
  quota_headroom_supported? : Bool = false,
  budget_headroom_nano_usd? : Int64? = None,
  budget_headroom_supported? : Bool = false,
  recent_cost_nano_usd? : Int64 = 0L,
  circuit_open_count? : Int = 0,
  circuit_half_open_count? : Int = 0,
  failover_count? : Int = 0,
  active_policies? : Array[ActivePolicyObservationV1] = [],
  storage_healthy? : Bool = true,
  storage_failure_count? : Int = 0,
  evidence_fresh? : Bool = false,
  newest_evidence_age_ms? : Int64? = None,
  oldest_evidence_age_ms? : Int64? = None,
) -> MonitorSnapshotV1 {
  {
    contract_id: monitor_snapshot_contract_v1(),
    observed_at_ms,
    latency: percentile_snapshot(latency_samples_ms),
    first_token: percentile_snapshot(first_token_samples_ms),
    permit_wait: percentile_snapshot(permit_wait_samples_ms),
    throughput_tokens_per_second_milli: numeric_percentile_snapshot(
      throughput_samples_milli,
    ),
    terminal_outcome_counts,
    recent_input_tokens,
    recent_output_tokens,
    inflight_requests,
    queue_depth,
    queue_supported,
    permit_supported,
    quota_configured_count,
    quota_exceeded_count,
    quota_headroom_nano_usd,
    quota_headroom_supported,
    budget_headroom_nano_usd,
    budget_headroom_supported,
    recent_cost_nano_usd,
    circuit_open_count,
    circuit_half_open_count,
    failover_count,
    active_policies,
    storage_healthy,
    storage_failure_count,
    evidence_fresh,
    newest_evidence_age_ms,
    oldest_evidence_age_ms,
  }
}
