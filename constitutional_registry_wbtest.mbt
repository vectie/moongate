///|
test "constitutional registry covers the complete product matrix" {
  let registry = constitutional_product_boundaries()
  assert_eq(registry.length(), 11)
  for
    product in [
      "moongate", "moondesk", "moonbook", "moonwiki", "moonflow", "moonclaw", "mooncode",
      "moontown", "moonrobo", "moonmoon", "moonlib",
    ] {
    assert_true(registry.any(boundary => boundary.product_id == product))
  }
}

///|
test "every declared product boundary passes the shared validator" {
  let report = constitutional_registry_self_check("2026-07-12T09:00:00+08:00")
  guard report is Object(fields) else { fail("expected registry report") }
  assert_eq(fields["accepted"], Json::boolean(true))
  assert_eq(fields["productCount"], Json::number(11.0))
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
