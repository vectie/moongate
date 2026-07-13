///|
/// The authoritative Moon Suite product-boundary registry.
///
/// MoonLib owns the policy-free contract and validator. MoonGate owns this
/// registry because it is the suite's identity, authority, and model gateway.
pub fn constitutional_product_boundaries() -> Array[@pipeline.ProductBoundary] {
  [
    {
      product_id: "moongate",
      owner: "identity-authority-model-gateway",
      operations: ["route-model", "issue-authority", "audit-conformance"],
      allowed_authorities: [
        Observe,
        CognitiveMaintenance,
        WorkspaceMutation,
        ExternalEffect,
      ],
      input_contracts: [
        "moonsuite.identity.v1", "moonsuite.authority.v1", "moonsuite.model-route.v1",
        "moonsuite.constitution-conformance.v1",
      ],
      output_contracts: [
        "moonsuite.identity.v1", "moonsuite.authority.v1", "moonsuite.model-route.v1",
        "moonsuite.constitution-conformance.v1",
      ],
      claim_ceiling: Observation,
      prohibited_claims: [
        AcceptedKnowledge,
        ScenarioQualified,
        PhysicalReadiness,
        PhysicalEffectClaim,
      ],
    },
    {
      product_id: "moondesk",
      owner: "executable-document-operator-interface",
      operations: [
        "edit-document", "dispatch-declaration", "review-evidence", "present-browser-session",
        "review-browser-evidence",
      ],
      allowed_authorities: [
        Observe,
        CognitiveMaintenance,
        SandboxExecution,
        WorkspaceMutation,
      ],
      input_contracts: [
        "moonsuite.executable-document.v1", "moonsuite.work-model.v1", "moonsuite.evidence-envelope.v1",
        "moonsuite.constitution-conformance.v1", "moonsuite.browser-session.v1",
        "moonsuite.browser-action-receipt.v1",
      ],
      output_contracts: [
        "moonsuite.executable-document.v1", "moonsuite.change-receipt.v1",
      ],
      claim_ceiling: ExecutionResult,
      prohibited_claims: [
        AcceptedKnowledge,
        ScenarioQualified,
        PhysicalReadiness,
        PhysicalEffectClaim,
      ],
    },
    {
      product_id: "moonbook",
      owner: "durable-knowledge-and-metacognition",
      operations: ["record-knowledge", "reflect", "learn-procedure"],
      allowed_authorities: [Observe, CognitiveMaintenance, WorkspaceMutation],
      input_contracts: [
        "moonsuite.knowledge-gap.v1", "moonsuite.belief-update.v1", "moonsuite.bookkeeper-reflection.v1",
        "moonsuite.learned-procedure.v1", "moonsuite.evidence-envelope.v1", "moonsuite.book-message.v1",
      ],
      output_contracts: [
        "moonsuite.knowledge-gap.v1", "moonsuite.belief-update.v1", "moonsuite.bookkeeper-reflection.v1",
        "moonsuite.learned-procedure.v1", "moonsuite.book-readiness.v1", "moonsuite.book-message.v1",
      ],
      claim_ceiling: AcceptedKnowledge,
      prohibited_claims: [
        ScenarioQualified,
        PhysicalReadiness,
        PhysicalEffectClaim,
      ],
    },
    {
      product_id: "moonwiki",
      owner: "research-provenance-and-information-gap-closure",
      operations: ["search", "track-source", "synthesize-research"],
      allowed_authorities: [
        Observe,
        CognitiveMaintenance,
        WorkspaceMutation,
        ExternalEffect,
      ],
      input_contracts: [
        "moonsuite.knowledge-gap.v1", "moonsuite.executable-document.v1",
      ],
      output_contracts: [
        "moonsuite.artifact-ref.v1", "moonsuite.evidence-envelope.v1", "moonsuite.belief-update.v1",
      ],
      claim_ceiling: ResearchEvidence,
      prohibited_claims: [
        AcceptedKnowledge,
        ScenarioQualified,
        PhysicalReadiness,
        PhysicalEffectClaim,
      ],
    },
    {
      product_id: "moonflow",
      owner: "goal-to-work-orchestration-and-evidence-lineage",
      operations: [
        "compile-work", "dispatch-work", "evaluate-gate", "resume-run",
      ],
      allowed_authorities: [
        Observe,
        CognitiveMaintenance,
        SandboxExecution,
        WorkspaceMutation,
      ],
      input_contracts: [
        "moonsuite.executable-document.v1", "moonsuite.work-model.v1", "moonsuite.authority.v1",
        "moonsuite.evidence-envelope.v1", "moonsuite.constitution-conformance.v1",
      ],
      output_contracts: [
        "moonsuite.work-model.v1", "moonsuite.run-receipt.v1", "moonsuite.evidence-envelope.v1",
        "moonsuite.change-receipt.v1",
      ],
      claim_ceiling: ExecutionResult,
      prohibited_claims: [
        AcceptedKnowledge,
        ScenarioQualified,
        PhysicalReadiness,
        PhysicalEffectClaim,
      ],
    },
    {
      product_id: "moonclaw",
      owner: "bounded-agent-execution-and-tool-use",
      operations: [
        "execute-task", "run-tool", "repair-attempt", "execute-browser-action",
      ],
      allowed_authorities: [
        Observe,
        CognitiveMaintenance,
        SandboxExecution,
        WorkspaceMutation,
        ExternalEffect,
      ],
      input_contracts: [
        "moonsuite.work-model.v1", "moonsuite.authority.v1", "moonsuite.model-route.v1",
        "moonsuite.learned-procedure.v1", "moonsuite.browser-session.v1",
      ],
      output_contracts: [
        "moonsuite.run-receipt.v1", "moonsuite.artifact-ref.v1", "moonsuite.evidence-envelope.v1",
        "moonsuite.change-receipt.v1", "moonsuite.browser-action-receipt.v1",
      ],
      claim_ceiling: ExecutionResult,
      prohibited_claims: [
        AcceptedKnowledge,
        ScenarioQualified,
        PhysicalReadiness,
        PhysicalEffectClaim,
      ],
    },
    {
      product_id: "mooncode",
      owner: "code-generation-verification-and-repair",
      operations: ["change-code", "run-verification", "repair-code"],
      allowed_authorities: [Observe, SandboxExecution, WorkspaceMutation],
      input_contracts: [
        "moonsuite.work-model.v1", "moonsuite.authority.v1", "moonsuite.learned-procedure.v1",
      ],
      output_contracts: [
        "moonsuite.artifact-ref.v1", "moonsuite.run-receipt.v1", "moonsuite.change-receipt.v1",
        "moonsuite.evidence-envelope.v1",
      ],
      claim_ceiling: DigitalArtifact,
      prohibited_claims: [
        ScenarioQualified,
        PhysicalReadiness,
        PhysicalEffectClaim,
      ],
    },
    {
      product_id: "moontown",
      owner: "multi-agent-coordination-emergence-and-promotion",
      operations: [
        "coordinate", "commission", "promote-idea", "resolve-conflict",
      ],
      allowed_authorities: [Observe, CognitiveMaintenance, WorkspaceMutation],
      input_contracts: [
        "moonsuite.book-readiness.v1", "moonsuite.book-message.v1", "moonsuite.town-commission.v1",
        "moonsuite.evidence-envelope.v1", "moonmold.spatial-artifact.v1",
      ],
      output_contracts: [
        "moonsuite.town-commission.v1", "moonsuite.town-promotion.v1", "moonsuite.book-message.v1",
        "moonsuite.work-model.v1",
      ],
      claim_ceiling: AcceptedKnowledge,
      prohibited_claims: [
        ScenarioQualified,
        PhysicalReadiness,
        PhysicalEffectClaim,
      ],
    },
    {
      product_id: "moonmold",
      owner: "spatial-modeling-transformation-and-validation",
      operations: [
        "create-spatial-model", "edit-parametric-model", "transform-representation",
        "validate-geometry", "export-representation", "prepare-manufacturing-candidate",
      ],
      allowed_authorities: [
        Observe,
        CognitiveMaintenance,
        SandboxExecution,
        WorkspaceMutation,
      ],
      input_contracts: [
        "moonsuite.work-model.v1", "moonsuite.authority.v1", "moonbook.learned-procedure.v1",
        "moonmold.spatial-artifact.v1",
      ],
      output_contracts: [
        "moonmold.spatial-artifact.v1", "moonmold.representation-transform.v1", "moonsuite.artifact-ref.v1",
        "moonsuite.evidence-envelope.v1", "moonsuite.run-receipt.v1",
      ],
      claim_ceiling: DigitalArtifact,
      prohibited_claims: [
        AcceptedKnowledge,
        SimulationEvidence,
        ScenarioQualified,
        CalibratedDigitalTwin,
        HardwareInLoopQualified,
        EngineeringUnitQualified,
        PhysicalReadiness,
        PhysicalEffectClaim,
      ],
    },
    {
      product_id: "moonrobo",
      owner: "robot-design-build-test-and-qualification",
      operations: [
        "design-robot", "build-robot", "validate-robot", "hardware-in-loop",
      ],
      allowed_authorities: [
        Observe,
        SandboxExecution,
        WorkspaceMutation,
        ExternalEffect,
        PhysicalEffect,
      ],
      input_contracts: [
        "moonsuite.robot-design.v1", "moonsuite.work-model.v1", "moonsuite.authority.v1",
        "moonsuite.town-promotion.v1", "moonmold.spatial-artifact.v1",
      ],
      output_contracts: [
        "moonsuite.robot-design.v1", "moonsuite.artifact-ref.v1", "moonsuite.evidence-envelope.v1",
        "moonsuite.run-receipt.v1",
      ],
      claim_ceiling: EngineeringUnitQualified,
      prohibited_claims: [PhysicalReadiness, PhysicalEffectClaim],
    },
    {
      product_id: "moonmoon",
      owner: "lunar-digital-twin-simulation-and-scenario-evidence",
      operations: [
        "simulate-mission", "inject-scenario", "calibrate-twin", "report-simulation",
      ],
      allowed_authorities: [Observe, SandboxExecution, WorkspaceMutation],
      input_contracts: [
        "moonsuite.robot-design.v1", "moonsuite.work-model.v1", "moonsuite.evidence-envelope.v1",
        "moonmold.spatial-artifact.v1", "moonmold.representation-transform.v1",
      ],
      output_contracts: [
        "moonsuite.run-receipt.v1", "moonsuite.evidence-envelope.v1", "moonsuite.artifact-ref.v1",
      ],
      claim_ceiling: CalibratedDigitalTwin,
      prohibited_claims: [
        HardwareInLoopQualified,
        EngineeringUnitQualified,
        PhysicalReadiness,
        PhysicalEffectClaim,
      ],
    },
    {
      product_id: "moonlib",
      owner: "policy-free-shared-contracts-and-deterministic-primitives",
      operations: ["define-contract", "validate-contract"],
      allowed_authorities: [Observe],
      input_contracts: ["moonsuite.constitution-conformance.v1"],
      output_contracts: ["moonsuite.constitution-conformance.v1"],
      claim_ceiling: Observation,
      prohibited_claims: [
        AcceptedKnowledge,
        ScenarioQualified,
        PhysicalReadiness,
        PhysicalEffectClaim,
      ],
    },
  ]
}

///|
pub fn constitutional_registry_json() -> Json {
  {
    "contractId": Json::string("moonsuite.product-boundary-registry.v1"),
    "policyOwner": Json::string("moongate"),
    "validatorContractId": Json::string(
      @pipeline.ContractKind::ConstitutionConformance.id(),
    ),
    "products": constitutional_product_boundaries().to_json(),
  }.to_json()
}

///|
fn conformance_probe(
  boundary : @pipeline.ProductBoundary,
) -> @pipeline.ConformanceSubject {
  {
    subject_id: "boundary-probe-\{boundary.product_id}",
    product_id: boundary.product_id,
    operation: boundary.operations[0],
    requested_authority: boundary.allowed_authorities[0],
    input_contracts: boundary.input_contracts,
    output_contracts: boundary.output_contracts,
    claim: boundary.claim_ceiling,
    criteria: [],
    negative_path_count: 0,
    execution_succeeded: true,
    accepted: false,
    acceptance_review_ref: "",
    workspace_root: "/Users/kq/moonsuite",
    artifact_paths: [".moonsuite/conformance/\{boundary.product_id}.json"],
  }
}

///|
pub fn constitutional_registry_self_check(checked_at : String) -> Json {
  let registry = constitutional_product_boundaries()
  let reports : Array[@pipeline.ConstitutionConformanceReport] = []
  let mut accepted = true
  for boundary in registry {
    let report = @pipeline.validate_constitutional_conformance(
      registry,
      conformance_probe(boundary),
      "registry-self-check-\{boundary.product_id}",
      checked_at,
    )
    if !report.accepted {
      accepted = false
    }
    reports.push(report)
  }
  {
    "contractId": Json::string("moonsuite.constitution-registry-self-check.v1"),
    "accepted": Json::boolean(accepted),
    "productCount": Json::number(registry.length().to_double()),
    "reports": reports.to_json(),
    "checkedAt": Json::string(checked_at),
  }.to_json()
}

///|
pub fn constitutional_negative_probe(
  checked_at : String,
) -> @pipeline.ConstitutionConformanceReport {
  @pipeline.validate_constitutional_conformance(
    constitutional_product_boundaries(),
    {
      subject_id: "negative-probe-moonmoon-physical-overclaim",
      product_id: "moonmoon",
      operation: "deploy-physical-robot",
      requested_authority: PhysicalEffect,
      input_contracts: ["moonsuite.identity.v1"],
      output_contracts: ["moonsuite.robot-design.v1"],
      claim: PhysicalEffectClaim,
      criteria: [
        {
          criterion_id: "physical-landing",
          owner_product_id: "moonrobo",
          required_claim: PhysicalEffectClaim,
          negative_path_required: true,
          evidence_refs: [],
        },
      ],
      negative_path_count: 0,
      execution_succeeded: false,
      accepted: true,
      acceptance_review_ref: "",
      workspace_root: "/Users/kq/moonsuite",
      artifact_paths: ["../outside-workspace.json"],
    },
    "negative-probe-report",
    checked_at,
  )
}

///|
pub fn constitutional_simulation_authority_probe(
  checked_at : String,
) -> @pipeline.ConstitutionConformanceReport {
  @pipeline.validate_constitutional_conformance(
    constitutional_product_boundaries(),
    {
      subject_id: "negative-probe-simulation-physical-authority",
      product_id: "moonmoon",
      operation: "simulate-mission",
      requested_authority: PhysicalEffect,
      input_contracts: ["moonsuite.robot-design.v1"],
      output_contracts: ["moonsuite.evidence-envelope.v1"],
      claim: SimulationEvidence,
      criteria: [],
      negative_path_count: 1,
      execution_succeeded: true,
      accepted: false,
      acceptance_review_ref: "",
      workspace_root: "/Users/kq/moonsuite",
      artifact_paths: [".moonsuite/products/moonmoon/simulation.json"],
    },
    "negative-simulation-authority-report",
    checked_at,
  )
}

///|
/// Preparing digital manufacturing geometry cannot authorize fabrication.
pub fn constitutional_moonmold_physical_probe(
  checked_at : String,
) -> @pipeline.ConstitutionConformanceReport {
  @pipeline.validate_constitutional_conformance(
    constitutional_product_boundaries(),
    {
      subject_id: "negative-probe-moonmold-physical-fabrication",
      product_id: "moonmold",
      operation: "prepare-manufacturing-candidate",
      requested_authority: PhysicalEffect,
      input_contracts: ["moonmold.spatial-artifact.v1"],
      output_contracts: ["moonmold.spatial-artifact.v1"],
      claim: PhysicalEffectClaim,
      criteria: [],
      negative_path_count: 1,
      execution_succeeded: true,
      accepted: false,
      acceptance_review_ref: "",
      workspace_root: "/Users/kq/moonsuite",
      artifact_paths: [
        ".moonsuite/products/moonmold/manufacturing/candidate.json",
      ],
    },
    "negative-moonmold-physical-report",
    checked_at,
  )
}

///|
/// A browser worker cannot reinterpret page content as physical authority.
pub fn constitutional_browser_physical_probe(
  checked_at : String,
) -> @pipeline.ConstitutionConformanceReport {
  @pipeline.validate_constitutional_conformance(
    constitutional_product_boundaries(),
    {
      subject_id: "negative-probe-browser-physical-effect",
      product_id: "moonclaw",
      operation: "execute-browser-action",
      requested_authority: PhysicalEffect,
      input_contracts: ["moonsuite.browser-session.v1"],
      output_contracts: ["moonsuite.browser-action-receipt.v1"],
      claim: PhysicalEffectClaim,
      criteria: [],
      negative_path_count: 1,
      execution_succeeded: false,
      accepted: false,
      acceptance_review_ref: "",
      workspace_root: "/Users/kq/moonsuite",
      artifact_paths: [
        ".moonsuite/products/moonclaw/browser/rejected-physical-action.json",
      ],
    },
    "negative-browser-physical-report",
    checked_at,
  )
}
