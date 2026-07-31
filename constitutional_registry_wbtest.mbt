///|
test "constitutional registry covers the complete product matrix" {
  let registry = constitutional_product_boundaries()
  assert_eq(registry.length(), 10)
  for
    product in [
      "moongate", "moondesk", "moonbook", "moonflow", "moonclaw", "moontown", "moonmold",
      "moonrobo", "moonmoon", "moonlib",
    ] {
    assert_true(registry.any(boundary => boundary.product_id == product))
  }
  assert_false(registry.any(boundary => boundary.product_id == "moonwiki"))
  assert_false(registry.any(boundary => boundary.product_id == "mooncode"))
}

///|
test "constitutional capability rows match current pack-owned tools" {
  let registry = constitutional_product_boundaries()
  let moonbook = registry.filter(boundary => boundary.product_id == "moonbook")
  guard moonbook is [moonbook] else { fail("expected MoonBook boundary") }
  assert_eq(moonbook.operations, [
    "bookkeeper.outcome.close", "wiki.requirements.prepare",
  ])
  assert_eq(moonbook.allowed_authorities.map(authority => authority.id()), [
    "workspace-mutation",
  ])
  assert_eq(moonbook.claim_ceiling, DigitalArtifact)
  assert_false(moonbook.prohibited_claims.contains(AcceptedKnowledge))
  let moonclaw = registry.filter(boundary => boundary.product_id == "moonclaw")
  guard moonclaw is [moonclaw] else { fail("expected MoonClaw boundary") }
  assert_eq(moonclaw.operations, ["agent.goal.execute"])
  assert_eq(moonclaw.allowed_authorities.map(authority => authority.id()), [
    "workspace-mutation",
  ])
  assert_eq(moonclaw.claim_ceiling, DigitalArtifact)
  assert_true(moonclaw.prohibited_claims.contains(AcceptedKnowledge))
  let moontown = registry.filter(boundary => boundary.product_id == "moontown")
  guard moontown is [moontown] else { fail("expected MoonTown boundary") }
  assert_eq(moontown.operations, ["civic.communication.synthesize"])
  assert_eq(moontown.claim_ceiling, ExecutionResult)
  let moonmold = registry.filter(boundary => boundary.product_id == "moonmold")
  guard moonmold is [moonmold] else { fail("expected MoonMold boundary") }
  assert_eq(moonmold.operations, [
    "spatial.operation.validate", "spatial.operation.execute", "representation.validate",
  ])
  assert_eq(moonmold.allowed_authorities.map(authority => authority.id()), [
    "sandbox-execution", "workspace-mutation",
  ])
  assert_eq(moonmold.claim_ceiling, DigitalArtifact)
  let moonrobo = registry.filter(boundary => boundary.product_id == "moonrobo")
  guard moonrobo is [moonrobo] else { fail("expected MoonRobo boundary") }
  assert_eq(moonrobo.operations, [
    "robot.integrate-digital-model", "robot.readiness.inspect", "robot.command.submit-governed",
  ])
  assert_eq(moonrobo.allowed_authorities.map(authority => authority.id()), [
    "observe", "workspace-mutation",
  ])
  assert_eq(moonrobo.claim_ceiling, DigitalArtifact)
  let moonmoon = registry.filter(boundary => boundary.product_id == "moonmoon")
  guard moonmoon is [moonmoon] else { fail("expected MoonMoon boundary") }
  assert_eq(moonmoon.operations, [
    "simulation.robot-mission", "simulation.mission-result.inspect",
  ])
  assert_eq(moonmoon.allowed_authorities.map(authority => authority.id()), [
    "observe", "sandbox-execution",
  ])
  assert_eq(moonmoon.claim_ceiling, CalibratedDigitalTwin)
}

///|
test "every declared product boundary passes the shared validator" {
  let report = constitutional_registry_self_check("2026-07-12T09:00:00+08:00")
  guard report is Object(fields) else { fail("expected registry report") }
  assert_eq(fields["accepted"], Json::boolean(true))
  assert_eq(fields["productCount"], Json::number(10.0))
}

///|
test "simulation physical overclaim fails closed with typed findings" {
  let report = constitutional_negative_probe("2026-07-12T09:00:00+08:00")
  assert_false(report.accepted)
  let codes = report.findings.map(finding => finding.code)
  for
    required in [
      "operation-not-owned", "authority-not-allowed", "input-contract-not-allowed",
      "output-contract-not-owned", "claim-ceiling-exceeded", "prohibited-claim",
      "criterion-owned-by-another-product", "criterion-requires-downstream-claim",
      "missing-negative-path", "accepted-criterion-without-evidence", "acceptance-without-execution-result",
      "acceptance-without-review", "workspace-artifact-escape",
    ] {
    if !codes.contains(required) {
      fail("missing finding: \{required}")
    }
  }
}

///|
test "simulation evidence cannot authorize a physical effect" {
  let report = constitutional_simulation_authority_probe(
    "2026-07-12T09:00:00+08:00",
  )
  assert_false(report.accepted)
  let codes = report.findings.map(finding => finding.code)
  assert_true(codes.contains("authority-not-allowed"))
  assert_true(codes.contains("simulation-cannot-authorize-physical-effect"))
}

///|
test "MoonMold manufacturing preparation cannot authorize fabrication" {
  let report = constitutional_moonmold_physical_probe(
    "2026-07-13T09:00:00+08:00",
  )
  assert_false(report.accepted)
  let codes = report.findings.map(finding => finding.code)
  assert_true(codes.contains("authority-not-allowed"))
  assert_true(codes.contains("claim-ceiling-exceeded"))
  assert_true(codes.contains("prohibited-claim"))
}

///|
test "browser page content cannot grant a physical effect" {
  let report = constitutional_browser_physical_probe(
    "2026-07-13T09:01:00+08:00",
  )
  assert_false(report.accepted)
  let codes = report.findings.map(finding => finding.code)
  assert_true(codes.contains("authority-not-allowed"))
  assert_true(codes.contains("claim-ceiling-exceeded"))
  assert_true(codes.contains("prohibited-claim"))
}

///|
test "MoonMold simulation input is not MoonMoon simulation evidence" {
  let report = @pipeline.validate_constitutional_conformance(
    constitutional_product_boundaries(),
    {
      subject_id: "negative-probe-moonmold-simulation-evidence",
      product_id: "moonmold",
      operation: "export-representation",
      requested_authority: WorkspaceMutation,
      input_contracts: ["moonmold.spatial-artifact.v1"],
      output_contracts: ["moonmold.spatial-artifact.v1"],
      claim: SimulationEvidence,
      criteria: [],
      negative_path_count: 1,
      execution_succeeded: true,
      accepted: false,
      acceptance_review_ref: "",
      workspace_root: "/Users/kq/moonsuite",
      artifact_paths: [
        ".moonsuite/products/moonmold/simulation/input-model.json",
      ],
    },
    "negative-moonmold-simulation-evidence-report",
    "2026-07-13T09:02:00+08:00",
  )
  assert_false(report.accepted)
  let codes = report.findings.map(finding => finding.code)
  assert_true(codes.contains("claim-ceiling-exceeded"))
  assert_true(codes.contains("prohibited-claim"))
}

///|
test "registry JSON declares MoonGate as policy owner" {
  guard constitutional_registry_json() is Object(fields) else {
    fail("expected registry object")
  }
  assert_eq(fields["policyOwner"], Json::string("moongate"))
  assert_eq(
    fields["validatorContractId"],
    Json::string("moonsuite.constitution-conformance.v1"),
  )
}
