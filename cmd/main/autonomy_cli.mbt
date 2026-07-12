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

///|
fn autonomy_request_object(value : Json) -> Map[String, Json] raise {
  match value {
    Object(fields) => fields
    _ => fail("MoonGate autonomy request must be an object")
  }
}

///|
fn autonomy_request_string(
  fields : Map[String, Json],
  key : String,
) -> String raise {
  match fields.get(key) {
    Some(String(value)) if !value.trim().is_empty() => value
    _ => fail("MoonGate autonomy request requires \{key}")
  }
}

///|
fn autonomy_request_bool(
  fields : Map[String, Json],
  key : String,
) -> Bool raise {
  match fields.get(key) {
    Some(True) => true
    Some(False) => false
    _ => fail("MoonGate autonomy request requires boolean \{key}")
  }
}

///|
fn autonomy_request_strings(
  fields : Map[String, Json],
  key : String,
) -> Array[String] raise {
  match fields.get(key) {
    Some(Array(values)) =>
      values.map(value => {
        match value {
          String(text) if !text.trim().is_empty() => text
          _ => fail("MoonGate autonomy request \{key} requires strings")
        }
      })
    _ => fail("MoonGate autonomy request requires array \{key}")
  }
}

///|
fn decode_autonomy_request_grant(value : Json) -> @pipeline.AutonomyGrant raise {
  let fields = autonomy_request_object(value)
  {
    product_id: autonomy_request_string(fields, "product_id"),
    operations: autonomy_request_strings(fields, "operations"),
    authority_ceiling: @pipeline.authority_class_from_id(
      autonomy_request_string(fields, "authority_ceiling"),
    ),
    claim_ceiling: @pipeline.claim_class_from_id(
      autonomy_request_string(fields, "claim_ceiling"),
    ),
    artifact_prefixes: autonomy_request_strings(fields, "artifact_prefixes"),
  }
}

///|
async fn issue_autonomy_envelope(args : Array[String]) -> Unit {
  let root = autonomy_required_arg(args, "--root")
  let request_path = autonomy_required_arg(args, "--request")
  let envelope_id = autonomy_required_arg(args, "--envelope-id")
  let granted_by = autonomy_required_arg(args, "--granted-by")
  let recorded_at = autonomy_required_arg(args, "--recorded-at")
  let expires_at = autonomy_required_arg(args, "--expires-at")
  if !root.has_prefix("/") {
    fail("MoonGate autonomy-envelope --root must be absolute")
  }
  if !autonomy_safe_id(envelope_id) {
    fail("MoonGate autonomy envelope id must be a safe slug")
  }
  let request = read_autonomy_json(request_path, "autonomy request")
  let fields = autonomy_request_object(request)
  if autonomy_request_string(fields, "contract_id") !=
    "moonbook.autonomy-request.v1" {
    fail("MoonGate does not support this autonomy request contract")
  }
  guard fields.get("grants") is Some(Array(grants)) else {
    fail("MoonGate autonomy request requires grants")
  }
  guard fields.get("budget") is Some(budget) else {
    fail("MoonGate autonomy request requires budget")
  }
  let envelope : @pipeline.AutonomyEnvelope = {
    contract_id: "moongate.autonomy-envelope.v1",
    envelope_id,
    mode: autonomy_request_string(fields, "mode"),
    goal_ref: autonomy_request_string(fields, "goal_ref"),
    workspace_root: root,
    grants: grants.map(decode_autonomy_request_grant),
    budget: @pipeline.decode_autonomy_budget(budget),
    external_effects_allowed: autonomy_request_bool(
      fields, "external_effects_allowed",
    ),
    physical_effects_allowed: autonomy_request_bool(
      fields, "physical_effects_allowed",
    ),
    granted_by,
    source_digest: autonomy_request_string(fields, "source_digest"),
    recorded_at,
    expires_at,
    revoked: false,
  }
  let issues = envelope.quality_issues()
  if !issues.is_empty() {
    fail("MoonGate refused autonomy envelope: \{issues.join("; ")}")
  }
  let envelope_root = root +
    "/.moonsuite/products/moongate/autonomy/" +
    envelope_id
  @fsx.make_directory(envelope_root, recursive=true, exists_ok=true)
  let output_path = envelope_root + "/envelope.json"
  let output = @pipeline.autonomy_envelope_json(envelope)
  @fs.write_file(
    output_path,
    @encoding/utf8.encode(output.stringify(indent=2) + "\n"),
    create_mode=CreateOrTruncate,
    permission=0o600,
  )
  println(
    (
      {
        "contract_id": "moongate.autonomy-envelope-receipt.v1",
        "envelope_path": output_path,
        "envelope": output,
      } : Json).stringify(indent=2),
  )
}
