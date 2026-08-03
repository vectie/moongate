///|
pub fn benchmark_workload_contract_v1() -> String {
  "moongate.benchmark-workload.v1"
}

///|
pub fn benchmark_report_contract_v1() -> String {
  "moongate.benchmark-report.v1"
}

///|
pub fn live_benchmark_request_contract_v1() -> String {
  "moongate.live-benchmark-request.v1"
}

///|
pub fn live_benchmark_result_contract_v1() -> String {
  "moongate.live-benchmark-result.v1"
}

///|
pub(all) enum LiveBenchmarkStatusV1 {
  Denied
  Unavailable
} derive(Debug, Eq)

///|
pub fn LiveBenchmarkStatusV1::id(self : LiveBenchmarkStatusV1) -> String {
  match self {
    Denied => "denied"
    Unavailable => "unavailable"
  }
}

///|
pub impl ToJson for LiveBenchmarkStatusV1 with fn to_json(
  self : LiveBenchmarkStatusV1,
) -> Json {
  Json::string(self.id())
}

///|
pub impl @json.FromJson for LiveBenchmarkStatusV1 with fn from_json(
  value : Json,
  path : @json.JsonPath,
) -> LiveBenchmarkStatusV1 raise @json.JsonDecodeError {
  guard value is String(id) else {
    raise @json.JsonDecodeError(
      (path, "LiveBenchmarkStatusV1: expected string"),
    )
  }
  match id {
    "denied" => Denied
    "unavailable" => Unavailable
    _ =>
      raise @json.JsonDecodeError(
        (path, "LiveBenchmarkStatusV1: unsupported value"),
      )
  }
}

///|
pub(all) enum LiveBenchmarkReasonV1 {
  AuthorityDecisionRequired
  AuthorityVerificationUnavailable
} derive(Debug, Eq)

///|
pub fn LiveBenchmarkReasonV1::id(self : LiveBenchmarkReasonV1) -> String {
  match self {
    AuthorityDecisionRequired => "authority-decision-required"
    AuthorityVerificationUnavailable => "authority-verification-unavailable"
  }
}

///|
pub impl ToJson for LiveBenchmarkReasonV1 with fn to_json(
  self : LiveBenchmarkReasonV1,
) -> Json {
  Json::string(self.id())
}

///|
pub impl @json.FromJson for LiveBenchmarkReasonV1 with fn from_json(
  value : Json,
  path : @json.JsonPath,
) -> LiveBenchmarkReasonV1 raise @json.JsonDecodeError {
  guard value is String(id) else {
    raise @json.JsonDecodeError(
      (path, "LiveBenchmarkReasonV1: expected string"),
    )
  }
  match id {
    "authority-decision-required" => AuthorityDecisionRequired
    "authority-verification-unavailable" => AuthorityVerificationUnavailable
    _ =>
      raise @json.JsonDecodeError(
        (path, "LiveBenchmarkReasonV1: unsupported value"),
      )
  }
}

///|
pub(all) struct DeterministicWorkloadV1 {
  contract_id : String
  workload_id : String
  workload_version : String
  concurrency : Int
  latency_samples_ms : Array[Int]
  first_token_samples_ms : Array[Int]
  output_tokens : Int
  simulated_cost_nano_usd : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct BenchmarkReportV1 {
  contract_id : String
  workload_id : String
  workload_version : String
  mode : String
  claim_ceiling : String
  live_provider : Bool
  concurrency : Int
  request_count : Int
  latency : @telemetry.PercentileSnapshotV1
  first_token : @telemetry.PercentileSnapshotV1
  output_tokens : Int
  output_tokens_per_second_milli : Int
  cost_nano_usd : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct LiveBenchmarkRequestV1 {
  contract_id : String
  request_id : String
  provider_id : String
  model : String
  workload_id : String
  max_requests : Int
  max_concurrency : Int
  max_input_tokens : Int
  max_output_tokens : Int
  max_cost_nano_usd : Int64
  deadline_ms : Int64
  cancellation_id : String
  authority_decision_id : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct LiveBenchmarkResultV1 {
  contract_id : String
  request_id : String
  status : LiveBenchmarkStatusV1
  reason_code : LiveBenchmarkReasonV1
  network_request_performed : Bool
  provider_id : String
  model : String
  workload_id : String
  authority_decision_id : String?
  adapter_id : String?
  recorded_at_ms : Int64
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_deterministic_workload() -> DeterministicWorkloadV1 {
  {
    contract_id: benchmark_workload_contract_v1(),
    workload_id: "gateway-contract-fixture",
    workload_version: "1.0.0",
    concurrency: 4,
    latency_samples_ms: [48, 52, 50, 60, 55, 49, 53, 58],
    first_token_samples_ms: [20, 23, 21, 27, 24, 22, 25, 26],
    output_tokens: 320,
    simulated_cost_nano_usd: 0L,
  }
}

///|
pub fn run_deterministic(
  workload : DeterministicWorkloadV1,
) -> BenchmarkReportV1 raise {
  if workload.contract_id != benchmark_workload_contract_v1() {
    fail("unsupported benchmark workload contract")
  }
  if workload.workload_id.trim().is_empty() ||
    workload.workload_version.trim().is_empty() ||
    workload.concurrency < 1 ||
    workload.latency_samples_ms.is_empty() ||
    workload.output_tokens < 0 ||
    workload.simulated_cost_nano_usd < 0L {
    fail("invalid deterministic benchmark workload")
  }
  let mut total_latency_ms = 0
  for latency in workload.latency_samples_ms {
    if latency < 0 {
      fail("benchmark latency samples must be non-negative")
    }
    total_latency_ms += latency
  }
  for first_token in workload.first_token_samples_ms {
    if first_token < 0 {
      fail("benchmark first-token samples must be non-negative")
    }
  }
  let throughput_milli = if total_latency_ms == 0 {
    0
  } else {
    workload.output_tokens * 1_000_000 / total_latency_ms
  }
  {
    contract_id: benchmark_report_contract_v1(),
    workload_id: workload.workload_id,
    workload_version: workload.workload_version,
    mode: "deterministic-fixture",
    claim_ceiling: "gateway-contract-fixture",
    live_provider: false,
    concurrency: workload.concurrency,
    request_count: workload.latency_samples_ms.length(),
    latency: @telemetry.percentile_snapshot(workload.latency_samples_ms),
    first_token: @telemetry.percentile_snapshot(workload.first_token_samples_ms),
    output_tokens: workload.output_tokens,
    output_tokens_per_second_milli: throughput_milli,
    cost_nano_usd: workload.simulated_cost_nano_usd,
  }
}

///|
pub fn validate_live_request(
  request : LiveBenchmarkRequestV1,
  now_ms : Int64,
) -> Unit raise {
  if request.contract_id != live_benchmark_request_contract_v1() {
    fail("unsupported live benchmark request contract")
  }
  if request.request_id.trim().is_empty() ||
    request.provider_id.trim().is_empty() ||
    request.model.trim().is_empty() ||
    request.workload_id.trim().is_empty() ||
    request.cancellation_id.trim().is_empty() {
    fail("live benchmark identity fields are required")
  }
  if request.max_requests < 1 ||
    request.max_requests > 100 ||
    request.max_concurrency < 1 ||
    request.max_concurrency > 8 ||
    request.max_input_tokens < 1 ||
    request.max_input_tokens > 1_000_000 ||
    request.max_output_tokens < 1 ||
    request.max_output_tokens > 1_000_000 ||
    request.max_cost_nano_usd < 1L ||
    request.max_cost_nano_usd > 10_000_000_000L {
    fail("live benchmark limits must be positive and bounded")
  }
  if request.deadline_ms <= now_ms || request.deadline_ms - now_ms > 900_000L {
    fail("live benchmark deadline must be within the next 15 minutes")
  }
}

///|
pub fn fail_closed_live_result(
  request : LiveBenchmarkRequestV1,
  now_ms : Int64,
) -> LiveBenchmarkResultV1 raise {
  validate_live_request(request, now_ms)
  let (status, reason_code) = match request.authority_decision_id {
    Some(decision_id) if !decision_id.trim().is_empty() =>
      (Unavailable, AuthorityVerificationUnavailable)
    _ => (Denied, AuthorityDecisionRequired)
  }
  {
    contract_id: live_benchmark_result_contract_v1(),
    request_id: request.request_id,
    status,
    reason_code,
    network_request_performed: false,
    provider_id: request.provider_id,
    model: request.model,
    workload_id: request.workload_id,
    authority_decision_id: request.authority_decision_id,
    adapter_id: None,
    recorded_at_ms: now_ms,
  }
}
