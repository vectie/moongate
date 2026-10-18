///|
/// Aggregate MoonClaw planner observations without retaining prompts, paths,
/// tool names, or session identifiers. Detailed round records stay on the
/// MoonClaw side of the boundary.
priv struct PlannerHarnessAggregate {
  mut rounds : Int32
  mut tool_calls : Int32
  mut prompt_tokens : Int32
  mut completion_tokens : Int32
  mut cache_read_tokens : Int32
  mut cache_write_tokens : Int32
  mut fresh_input_tokens : Int32
  mut total_tokens : Int32
  mut configured_request_chars : Int32
  mut effective_request_chars : Int32
  mut projection_saved_chars : Int32
  mut request_message_count : Int32
  mut request_message_chars : Int32
  mut system_prompt_chars : Int32
  mut tool_schema_chars : Int32
  mut tool_count : Int32
  mut cache_read_ratio_ppm : Int32
  mut compacted_rounds : Int32
  mut planner_latency_ms : Int32
  mut model_retries : Int32
  mut selected_rounds : Int32
  mut no_tool_call_rounds : Int32
  mut responses_rounds : Int32
  mut chat_completion_rounds : Int32
  mut chat_fallback_rounds : Int32
}

///|
/// Planner observations cross a local HTTP boundary and are not authority.
/// Bound every additive sample so malformed telemetry cannot overflow or
/// permanently poison process-lifetime counters in one request.
const PLANNER_HARNESS_METRIC_SAMPLE_MAX : Int32 = 1_000_000_000

///|
fn PlannerHarnessAggregate::new() -> PlannerHarnessAggregate {
  {
    rounds: 0,
    tool_calls: 0,
    prompt_tokens: 0,
    completion_tokens: 0,
    cache_read_tokens: 0,
    cache_write_tokens: 0,
    fresh_input_tokens: 0,
    total_tokens: 0,
    configured_request_chars: 0,
    effective_request_chars: 0,
    projection_saved_chars: 0,
    request_message_count: 0,
    request_message_chars: 0,
    system_prompt_chars: 0,
    tool_schema_chars: 0,
    tool_count: 0,
    cache_read_ratio_ppm: 0,
    compacted_rounds: 0,
    planner_latency_ms: 0,
    model_retries: 0,
    selected_rounds: 0,
    no_tool_call_rounds: 0,
    responses_rounds: 0,
    chat_completion_rounds: 0,
    chat_fallback_rounds: 0,
  }
}

///|
fn planner_metric_int(payload : Map[String, Json], key : String) -> Int32 {
  json_int(payload, key)
  .unwrap_or(0)
  .max(0)
  .min(PLANNER_HARNESS_METRIC_SAMPLE_MAX)
}

///|
/// Returns false for arbitrary JSON so callers can fail closed at the API
/// boundary without changing normal provider traffic behavior.
fn PlannerHarnessAggregate::record(
  self : PlannerHarnessAggregate,
  body : Json,
) -> Bool {
  guard body is Object(payload) else { return false }
  guard json_string(payload, "contract") is Some(contract) &&
    contract == "moonclaw.planner.metrics.v1" else {
    return false
  }
  self.rounds += 1
  self.tool_calls += planner_metric_int(payload, "tool_call_count")
  self.prompt_tokens += planner_metric_int(payload, "prompt_tokens")
  self.completion_tokens += planner_metric_int(payload, "completion_tokens")
  self.cache_read_tokens += planner_metric_int(payload, "cache_read_tokens")
  self.cache_write_tokens += planner_metric_int(payload, "cache_write_tokens")
  self.fresh_input_tokens += planner_metric_int(payload, "fresh_input_tokens")
  self.total_tokens += planner_metric_int(payload, "total_tokens")
  let configured_request_chars = planner_metric_int(
    payload, "configured_request_chars",
  )
  let effective_request_chars = planner_metric_int(
    payload, "effective_request_chars",
  )
  self.configured_request_chars += configured_request_chars
  self.effective_request_chars += effective_request_chars
  self.projection_saved_chars += (configured_request_chars -
  effective_request_chars).max(0)
  self.request_message_count += planner_metric_int(
    payload, "request_message_count",
  )
  self.request_message_chars += planner_metric_int(
    payload, "request_message_chars",
  )
  self.system_prompt_chars += planner_metric_int(payload, "system_prompt_chars")
  self.tool_schema_chars += planner_metric_int(payload, "tool_schema_chars")
  self.tool_count += planner_metric_int(payload, "tool_count")
  self.cache_read_ratio_ppm += planner_metric_int(
    payload, "cache_read_ratio_ppm",
  ).min(1_000_000)
  self.planner_latency_ms += planner_metric_int(payload, "planner_latency_ms")
  self.model_retries += planner_metric_int(payload, "model_retry_count")
  if payload.get("request_compacted") == Some(Json::boolean(true)) {
    self.compacted_rounds += 1
  }
  match json_string(payload, "outcome") {
    Some("selected") => self.selected_rounds += 1
    Some("no_tool_calls") => self.no_tool_call_rounds += 1
    _ => ()
  }
  match json_string(payload, "model_transport") {
    Some("responses") => self.responses_rounds += 1
    Some("chat_completions") => self.chat_completion_rounds += 1
    Some("chat_fallback") => self.chat_fallback_rounds += 1
    _ => ()
  }
  true
}

///|
fn PlannerHarnessAggregate::prometheus_metrics(
  self : PlannerHarnessAggregate,
) -> String {
  let out = StringBuilder::new()
  prometheus_counter(out, "moongate_planner_rounds_total", self.rounds)
  prometheus_counter(out, "moongate_planner_tool_calls_total", self.tool_calls)
  prometheus_counter(
    out,
    "moongate_planner_prompt_tokens_total",
    self.prompt_tokens,
  )
  prometheus_counter(
    out,
    "moongate_planner_completion_tokens_total",
    self.completion_tokens,
  )
  prometheus_counter(
    out,
    "moongate_planner_cache_read_tokens_total",
    self.cache_read_tokens,
  )
  prometheus_counter(
    out,
    "moongate_planner_cache_write_tokens_total",
    self.cache_write_tokens,
  )
  prometheus_counter(
    out,
    "moongate_planner_fresh_input_tokens_total",
    self.fresh_input_tokens,
  )
  prometheus_counter(
    out,
    "moongate_planner_total_tokens_total",
    self.total_tokens,
  )
  prometheus_counter(
    out,
    "moongate_planner_configured_request_chars_total",
    self.configured_request_chars,
  )
  prometheus_counter(
    out,
    "moongate_planner_effective_request_chars_total",
    self.effective_request_chars,
  )
  prometheus_counter(
    out,
    "moongate_planner_projection_saved_chars_total",
    self.projection_saved_chars,
  )
  prometheus_counter(
    out,
    "moongate_planner_request_messages_total",
    self.request_message_count,
  )
  prometheus_counter(
    out,
    "moongate_planner_request_message_chars_total",
    self.request_message_chars,
  )
  prometheus_counter(
    out,
    "moongate_planner_system_prompt_chars_total",
    self.system_prompt_chars,
  )
  prometheus_counter(
    out,
    "moongate_planner_tool_schema_chars_total",
    self.tool_schema_chars,
  )
  prometheus_counter(out, "moongate_planner_tools_total", self.tool_count)
  prometheus_counter(
    out,
    "moongate_planner_cache_read_ratio_ppm_total",
    self.cache_read_ratio_ppm,
  )
  prometheus_counter(
    out,
    "moongate_planner_compacted_rounds_total",
    self.compacted_rounds,
  )
  prometheus_counter(
    out,
    "moongate_planner_model_latency_ms_total",
    self.planner_latency_ms,
  )
  prometheus_counter(
    out,
    "moongate_planner_model_retries_total",
    self.model_retries,
  )
  prometheus_counter(
    out,
    "moongate_planner_selected_rounds_total",
    self.selected_rounds,
  )
  prometheus_counter(
    out,
    "moongate_planner_no_tool_call_rounds_total",
    self.no_tool_call_rounds,
  )
  prometheus_counter(
    out,
    "moongate_planner_responses_rounds_total",
    self.responses_rounds,
  )
  prometheus_counter(
    out,
    "moongate_planner_chat_completion_rounds_total",
    self.chat_completion_rounds,
  )
  prometheus_counter(
    out,
    "moongate_planner_chat_fallback_rounds_total",
    self.chat_fallback_rounds,
  )
  out.to_string()
}

///|
fn TrafficStats::record_planner_metrics(
  self : TrafficStats,
  body : Json,
) -> Bool {
  self.planner_metrics.record(body)
}
