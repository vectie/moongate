///|
fn TrafficStats::operations_monitor_snapshot(
  self : TrafficStats,
  provider_router : ProviderRouter,
  observed_at_ms? : Int64 = moongate_epoch_ms(),
) -> @telemetry.MonitorSnapshotV1 {
  let latency_samples : Array[Int] = []
  let first_token_samples : Array[Int] = []
  let throughput_samples : Array[Int] = []
  let terminal_outcome_count_map : Map[String, Int] = Map([], capacity=0)
  let mut recent_cost_nano = 0L
  let mut recent_input_tokens = 0
  let mut recent_output_tokens = 0
  let mut newest_evidence_at_ms : Int64? = None
  let mut oldest_evidence_at_ms : Int64? = None
  for log in self.request_logs {
    if log.latency_ms >= 0 {
      latency_samples.push(log.latency_ms)
    }
    match log.first_token_ms {
      Some(value) if value >= 0 => first_token_samples.push(value)
      _ => ()
    }
    if log.latency_ms > 0 && log.output_tokens > 0 {
      throughput_samples.push(log.output_tokens * 1_000_000 / log.latency_ms)
    }
    let outcome = request_log_terminal_outcome(log)
    terminal_outcome_count_map[outcome.id()] = terminal_outcome_count_map
      .get(outcome.id())
      .unwrap_or(0) +
      1
    recent_input_tokens += log.input_tokens
    recent_output_tokens += log.output_tokens
    recent_cost_nano += request_log_total_cost_nano(log)
    let recorded_at_ms = log.created_at.to_int64() * 1000L
    newest_evidence_at_ms = match newest_evidence_at_ms {
      Some(current) if current >= recorded_at_ms => Some(current)
      _ => Some(recorded_at_ms)
    }
    oldest_evidence_at_ms = match oldest_evidence_at_ms {
      Some(current) if current <= recorded_at_ms => Some(current)
      _ => Some(recorded_at_ms)
    }
  }
  let (quota_configured_count, quota_exceeded_count) = self
    .provider_limit_monitor_counts()
  let (circuit_open_count, circuit_half_open_count) = provider_router
    .circuit_state_counts()
  let newest_evidence_age_ms = newest_evidence_at_ms.map(fn(recorded_at) {
    let age = observed_at_ms - recorded_at
    if age > 0L { age } else { 0L }
  })
  let oldest_evidence_age_ms = oldest_evidence_at_ms.map(fn(recorded_at) {
    let age = observed_at_ms - recorded_at
    if age > 0L { age } else { 0L }
  })
  let terminal_outcome_counts : Array[@telemetry.TerminalOutcomeCountV1] = []
  for outcome in [
    @telemetry.Success,
    @telemetry.Timeout,
    @telemetry.RateLimited,
    @telemetry.Cancelled,
    @telemetry.ProtocolClientError,
    @telemetry.UpstreamError,
    @telemetry.Unknown,
  ] {
    let count = terminal_outcome_count_map.get(outcome.id()).unwrap_or(0)
    if count > 0 {
      terminal_outcome_counts.push({ outcome, count })
    }
  }
  @telemetry.monitor_snapshot(
    observed_at_ms~,
    latency_samples_ms=latency_samples,
    first_token_samples_ms=first_token_samples,
    throughput_samples_milli=throughput_samples,
    terminal_outcome_counts~,
    recent_input_tokens~,
    recent_output_tokens~,
    inflight_requests=provider_router.total_inflight(),
    queue_depth=0,
    queue_supported=false,
    quota_configured_count~,
    quota_exceeded_count~,
    recent_cost_nano_usd=recent_cost_nano,
    circuit_open_count~,
    circuit_half_open_count~,
    failover_count=self.failover_count,
    active_policies=provider_router.active_policy_observations(),
    storage_healthy=self.storage_healthy,
    storage_failure_count=self.storage_failure_count,
    evidence_fresh=newest_evidence_age_ms.map(fn(age) { age <= 300_000L }).unwrap_or(
      false,
    ),
    newest_evidence_age_ms~,
    oldest_evidence_age_ms~,
  )
}

///|
fn request_log_terminal_outcome(log : RequestLog) -> @telemetry.TerminalOutcomeV1 {
  if log.status_code == 408 ||
    log.error_message.map(fn(value) { value.to_lower().contains("timeout") }).unwrap_or(
      false,
    ) {
    @telemetry.Timeout
  } else if log.status_code == 429 {
    @telemetry.RateLimited
  } else if log.status_code == 499 ||
    log.error_message.map(fn(value) { value.to_lower().contains("cancel") }).unwrap_or(
      false,
    ) {
    @telemetry.Cancelled
  } else if log.status_code >= 200 && log.status_code < 300 {
    @telemetry.Success
  } else if log.status_code >= 400 && log.status_code < 500 {
    @telemetry.ProtocolClientError
  } else if log.status_code >= 500 {
    @telemetry.UpstreamError
  } else {
    @telemetry.Unknown
  }
}

///|
fn TrafficStats::operations_prometheus_metrics(self : TrafficStats) -> String {
  let out = StringBuilder::new()
  let latency_samples : Array[Int] = []
  let first_token_samples : Array[Int] = []
  let mut recent_cost_nano = 0L
  for log in self.request_logs {
    if log.latency_ms >= 0 {
      latency_samples.push(log.latency_ms)
    }
    match log.first_token_ms {
      Some(value) if value >= 0 => first_token_samples.push(value)
      _ => ()
    }
    recent_cost_nano += request_log_total_cost_nano(log)
  }
  let latency = @telemetry.percentile_snapshot(latency_samples)
  let first_token = @telemetry.percentile_snapshot(first_token_samples)
  prometheus_gauge(out, "moongate_latency_samples", latency.sample_count)
  match latency.p50_ms {
    Some(value) => prometheus_gauge(out, "moongate_latency_p50_ms", value)
    None => ()
  }
  match latency.p95_ms {
    Some(value) => prometheus_gauge(out, "moongate_latency_p95_ms", value)
    None => ()
  }
  match latency.p99_ms {
    Some(value) => prometheus_gauge(out, "moongate_latency_p99_ms", value)
    None => ()
  }
  prometheus_gauge(
    out,
    "moongate_first_token_samples",
    first_token.sample_count,
  )
  match first_token.p50_ms {
    Some(value) => prometheus_gauge(out, "moongate_first_token_p50_ms", value)
    None => ()
  }
  match first_token.p95_ms {
    Some(value) => prometheus_gauge(out, "moongate_first_token_p95_ms", value)
    None => ()
  }
  match first_token.p99_ms {
    Some(value) => prometheus_gauge(out, "moongate_first_token_p99_ms", value)
    None => ()
  }
  let (quota_configured_count, quota_exceeded_count) = self
    .provider_limit_monitor_counts()
  prometheus_gauge(
    out,
    "moongate_provider_quota_configured",
    quota_configured_count,
  )
  prometheus_gauge(
    out,
    "moongate_provider_quota_exceeded",
    quota_exceeded_count,
  )
  prometheus_gauge(out, "moongate_queue_depth", 0)
  prometheus_gauge(out, "moongate_queue_supported", 0)
  prometheus_gauge_float(
    out,
    "moongate_recent_cost_nano_usd",
    recent_cost_nano.to_double(),
  )
  out.to_string()
}

///|
async fn UsageService::handle_operations_monitor(
  self : UsageService,
  w : @httpx.ResponseWriter,
  provider_router : ProviderRouter,
) -> Unit {
  write_usage_json(
    w,
    self.stats.operations_monitor_snapshot(provider_router).to_json(),
  )
}

///|
async fn UsageService::handle_deterministic_benchmark(
  self : UsageService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let report = @benchmark.run_deterministic(
    @benchmark.default_deterministic_workload(),
  ) catch {
    error => {
      moongate_write_json_error(
        w,
        @status.InternalServerError,
        "moongate_fixture_benchmark_failed",
        "Deterministic fixture benchmark failed: \{error}",
      )
      return
    }
  }
  write_usage_json(w, report.to_json())
}

///|
async fn UsageService::handle_live_benchmark_control(
  self : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  guard proxy_json_body(r) is Some(body) else {
    write_usage_bad_request(w, "missing_live_benchmark_request")
    return
  }
  let parsed : Result[@benchmark.LiveBenchmarkRequestV1, Error] = moon_result(
    () => @json.from_json(body),
  )
  guard parsed is Ok(request) else {
    write_usage_bad_request(w, "invalid_live_benchmark_request")
    return
  }
  let result = @benchmark.fail_closed_live_result(
    request,
    moongate_epoch_ms(),
  ) catch {
    error => {
      write_usage_bad_request(w, error.to_string())
      return
    }
  }
  write_usage_json(w, result.to_json())
}
