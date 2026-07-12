///|
fn autonomy_required_arg(args : Array[String], flag : String) -> String raise {
  match parse_string_arg(args, flag) {
    Some(value) if !value.trim().is_empty() => value
    _ => fail("MoonGate autonomy-check requires \{flag}")
  }
}

///|
fn autonomy_safe_id(value : String) -> Bool {
  safe_session_id(value)
}

///|
fn autonomy_decision_json(decision : @pipeline.AutonomyDecision) -> Json {
  {
    "contract_id": decision.contract_id,
    "decision_id": decision.decision_id,
    "envelope_id": decision.envelope_id,
    "event_id": decision.event_id,
    "accepted": decision.accepted,
    "findings": Json::array(
      decision.findings.map(finding => Json::string(finding)),
    ),
    "remaining_budget": {
      "model_tokens": decision.remaining_budget.model_tokens,
      "tool_calls": decision.remaining_budget.tool_calls,
      "storage_bytes": decision.remaining_budget.storage_bytes,
      "attempts": decision.remaining_budget.attempts,
      "concurrency": decision.remaining_budget.concurrency,
    },
    "checked_at": decision.checked_at,
  }
}

///|
fn autonomy_decision_with_finding(
  decision : @pipeline.AutonomyDecision,
  finding : String,
) -> @pipeline.AutonomyDecision {
  { ..decision, accepted: false, findings: decision.findings + [finding] }
}

///|
async fn read_autonomy_json(path : String, label : String) -> Json {
  let content = @fsx.read_file(path) catch {
    error => fail("unable to read \{label} at \{path}: \{error}")
  }
  @json.parse(content) catch {
    error => fail("invalid JSON in \{label} at \{path}: \{error}")
  }
}

///|
async fn check_autonomy_event(args : Array[String]) -> Unit {
  let root = autonomy_required_arg(args, "--root")
  let envelope_path = autonomy_required_arg(args, "--envelope")
  let event_path = autonomy_required_arg(args, "--event")
  let usage_path = autonomy_required_arg(args, "--usage")
  let decision_id = autonomy_required_arg(args, "--decision")
  let checked_at = autonomy_required_arg(args, "--checked-at")
  if !root.has_prefix("/") {
    fail("MoonGate autonomy-check --root must be absolute")
  }
  if !autonomy_safe_id(decision_id) {
    fail("MoonGate autonomy decision id must be a safe slug")
  }
  let envelope = @pipeline.decode_autonomy_envelope(
    read_autonomy_json(envelope_path, "autonomy envelope"),
  )
  if !autonomy_safe_id(envelope.envelope_id) {
    fail("MoonGate autonomy envelope id must be a safe slug")
  }
  let event = @pipeline.decode_autonomy_event_request(
    read_autonomy_json(event_path, "autonomy event request"),
  )
  let usage = @pipeline.decode_autonomy_budget_usage(
    read_autonomy_json(usage_path, "autonomy budget usage"),
  )
  let checked = @pipeline.authorize_autonomy_event(
    envelope, event, usage, decision_id, checked_at,
  )
  let decision = if envelope.workspace_root == root {
    checked
  } else {
    autonomy_decision_with_finding(
      checked, "autonomy envelope workspace_root does not match --root",
    )
  }
  let decisions_root = root +
    "/.moonsuite/products/moongate/autonomy/" +
    envelope.envelope_id +
    "/decisions"
  @fsx.make_directory(decisions_root, recursive=true, exists_ok=true)
  let output = autonomy_decision_json(decision).stringify(indent=2) + "\n"
  let output_path = decisions_root + "/" + decision_id + ".json"
  @fs.write_file(
    output_path,
    @encoding/utf8.encode(output),
    create_mode=CreateOrTruncate,
    permission=0o600,
  )
  println(output.trim())
  if !decision.accepted {
    fail(
      "MoonGate refused autonomy event; decision persisted at \{output_path}",
    )
  }
}
