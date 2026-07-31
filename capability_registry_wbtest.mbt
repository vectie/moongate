///|
async fn write_capability_fixture(
  root : String,
  product_id : String,
  operation_id : String,
  include_catalog_operation? : Bool = true,
  authority? : String = "WorkspaceMutation",
  claim_ceiling? : String = "digital-artifact",
  review_required? : Bool = true,
) -> (String, String, String) {
  let pack_root = @pathx.join(root, "packs/\{product_id}")
  let schema_root = @pathx.join(pack_root, "schemas")
  @fsx.make_directory(schema_root, recursive=true, exists_ok=true)
  let input_path = @pathx.join(schema_root, "input.schema.json")
  let output_path = @pathx.join(schema_root, "output.schema.json")
  @fsx.write_to_file(
    input_path,
    Json::object({ "type": Json::string("object") }).stringify(),
  )
  @fsx.write_to_file(
    output_path,
    Json::object({ "type": Json::string("object") }).stringify(),
  )
  let manifest_path = @pathx.join(pack_root, "pack.json")
  let manifest = Json::object({
    "id": Json::string(product_id),
    "product_id": Json::string(product_id),
    "version": Json::string("0.2.0"),
    "schemas": Json::array([
      Json::object({
        "id": Json::string("fixture-input"),
        "version": Json::string("1.0.0"),
        "path": Json::string("schemas/input.schema.json"),
      }),
      Json::object({
        "id": Json::string("fixture-output"),
        "version": Json::string("1.0.0"),
        "path": Json::string("schemas/output.schema.json"),
      }),
    ]),
    "tools": Json::array([
      Json::object({
        "id": Json::string(operation_id),
        "owner_product": Json::string(product_id),
        "input_schema_id": Json::string("fixture-input"),
        "output_schema_id": Json::string("fixture-output"),
        "authority": Json::string(authority),
        "idempotent": Json::boolean(true),
        "review_required": Json::boolean(review_required),
      }),
    ]),
  })
  @fsx.write_to_file(manifest_path, manifest.stringify(indent=2))
  let catalog_path = @pathx.join(pack_root, "capability-catalog.json")
  let catalog_operations = if include_catalog_operation {
    [
      Json::object({
        "operation_ref": Json::string("\{product_id}/\{operation_id}@0.2.0"),
        "product_id": Json::string(product_id),
        "pack_id": Json::string(product_id),
        "pack_version": Json::string("0.2.0"),
        "tool_id": Json::string(operation_id),
        "adapter_id": Json::string("\{product_id}-adapter-v1"),
        "protocol": Json::string("moonflow.adapter.v2"),
        "authority": Json::string(capability_normalize_authority(authority)),
        "input_schema_ref": Json::string("\{product_id}/fixture-input@1.0.0"),
        "output_schema_ref": Json::string("\{product_id}/fixture-output@1.0.0"),
        "claim_ceiling": Json::string(claim_ceiling),
        "idempotent": Json::boolean(true),
        "review_required": Json::boolean(review_required),
        "supports_cancel": Json::boolean(true),
        "supports_reconcile": Json::boolean(true),
        "health_checked_at": Json::string("2026-07-30T23:59:00Z"),
        "health_valid_until": Json::string("2026-08-01T00:00:00Z"),
        "health_evidence_ref": Json::string(
          "health/\{product_id}-adapter-v1.json",
        ),
        "health_evidence_digest": Json::string(
          "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        ),
      }),
    ]
  } else {
    []
  }
  @fsx.write_to_file(
    catalog_path,
    Json::object({
      "contract_id": Json::string("moonflow.capability-catalog.v1"),
      "catalog_id": Json::string("fixture-catalog"),
      "compiled_at": Json::string("2026-07-31T00:00:00Z"),
      "conformant": Json::boolean(true),
      "products": Json::array([
        Json::object({
          "product_id": Json::string(product_id),
          "pack_id": Json::string(product_id),
          "pack_version": Json::string("0.2.0"),
        }),
      ]),
      "operations": Json::array(catalog_operations),
      "issues": Json::array([]),
    }).stringify(indent=2),
  )
  (pack_root, manifest_path, catalog_path)
}

///|
fn capability_findings_contain_code(
  findings : Array[Json],
  code : String,
) -> Bool {
  findings.any(fn(finding) {
    match finding {
      Object(fields) =>
        capability_json_string(fields, "code").unwrap_or("") == code
      _ => false
    }
  })
}

///|
async fn assert_exact_catalog_operation_resolves(
  product_id : String,
  operation_id : String,
  authority : String,
  claim_ceiling : String,
  review_required? : Bool = true,
) -> Unit {
  @fsx.with_temporary_directory("moongate-capability-exact-XXXXXX", root => {
    let (pack_root, _, catalog_path) = write_capability_fixture(
      root,
      product_id,
      operation_id,
      authority~,
      claim_ceiling~,
      review_required~,
    )
    let registry_path = @pathx.join(root, "product-registry.json")
    @fsx.write_to_file(
      registry_path,
      Json::object({
        "kind": Json::string("moonsuite-product-registry.v1"),
        "products": Json::array([
          Json::object({
            "id": Json::string(product_id),
            "name": Json::string(product_id),
            "kind": Json::string("moon-suite-product"),
            "status": Json::string("installed"),
            "repo_path": Json::string(pack_root),
            "capability_catalog_path": Json::string(catalog_path),
            "capabilities": Json::array([]),
          }),
        ]),
      }).stringify(indent=2),
    )
    let projection = moongate_capability_projection_json(
      suite_root=root,
      registry_path~,
    )
    let resolution = moongate_capability_resolution_json(
      projection,
      product_id,
      operation_id,
      requested_authority=capability_normalize_authority(authority),
      input_schema_id="fixture-input",
      output_schema_id="fixture-output",
    )
    guard resolution is Object(resolved) else { fail("expected resolution") }
    if !capability_json_bool(resolved, "executable").unwrap_or(false) {
      fail("\{product_id}/\{operation_id} should resolve exactly")
    }
    guard resolved["operation"] is Object(operation) else {
      fail("expected resolved operation")
    }
    assert_eq(
      capability_json_string(operation, "claimCeiling").unwrap_or(""),
      claim_ceiling,
    )
    assert_eq(
      capability_json_bool(operation, "reviewRequired").unwrap_or(false),
      review_required,
    )
  })
}

///|
async test "capability projection publishes only manifest and MoonFlow catalog aligned operations" {
  @fsx.with_temporary_directory("moongate-capability-registry-XXXXXX", root => {
    let (pack_root, _, catalog_path) = write_capability_fixture(
      root, "moonmold", "spatial.operation.execute",
    )
    let registry_path = @pathx.join(root, "product-registry.json")
    @fsx.write_to_file(
      registry_path,
      Json::object({
        "kind": Json::string("moonsuite-product-registry.v1"),
        "products": Json::array([
          Json::object({
            "id": Json::string("moonmold"),
            "name": Json::string("MoonMold"),
            "kind": Json::string("domain-pack"),
            "status": Json::string("installed"),
            "repo_path": Json::string(pack_root),
            "capability_catalog_path": Json::string(catalog_path),
            "capabilities": Json::array([
              Json::string("descriptive-inventory-label"),
            ]),
          }),
        ]),
      }).stringify(indent=2),
    )
    let projection = moongate_capability_projection_json(
      suite_root=root,
      registry_path~,
    )
    guard projection is Object(fields) else { fail("expected projection") }
    assert_eq(
      capability_json_string(fields, "contract").unwrap_or(""),
      "moonsuite.capability-projection.v1",
    )
    guard fields["summary"] is Object(summary) else { fail("expected summary") }
    assert_eq(summary["inventoryProductCount"], Json::number(1.0))
    assert_eq(summary["declaredOperationCount"], Json::number(1.0))
    assert_eq(summary["executableOperationCount"], Json::number(1.0))
    guard fields["products"] is Array([Object(product)]) else {
      fail("expected one product")
    }
    assert_eq(
      capability_json_string(product, "capabilityStatus").unwrap_or(""),
      "executable",
    )
    guard product["operations"] is Array([Object(operation)]) else {
      fail("expected one operation")
    }
    assert_true(capability_json_bool(operation, "executable").unwrap_or(false))
    assert_eq(
      capability_json_string(operation, "availability").unwrap_or(""),
      "adapter-ready",
    )
    assert_true(operation["endpoint"] is Null)
    guard operation["adapterBinding"] is Object(binding) else {
      fail("expected MoonFlow adapter binding")
    }
    assert_eq(
      capability_json_string(binding, "protocol").unwrap_or(""),
      "moonflow.adapter.v2",
    )
    let resolution = moongate_capability_resolution_json(
      projection,
      "moonmold",
      "spatial.operation.execute",
      requested_authority="workspace-mutation",
      input_schema_id="fixture-input",
      output_schema_id="fixture-output",
    )
    guard resolution is Object(resolved) else { fail("expected resolution") }
    assert_true(capability_json_bool(resolved, "executable").unwrap_or(false))
  })
}

///|
async test "current suite pack operations resolve with exact authority and claim semantics" {
  assert_exact_catalog_operation_resolves(
    "moonbook", "bookkeeper.outcome.close", "WorkspaceMutation", "accepted-knowledge",
  )
  assert_exact_catalog_operation_resolves(
    "moonbook", "wiki.requirements.prepare", "WorkspaceMutation", "digital-artifact",
  )
  assert_exact_catalog_operation_resolves(
    "moonclaw",
    "agent.goal.execute",
    "WorkspaceMutation",
    "digital-artifact",
    review_required=false,
  )
  assert_exact_catalog_operation_resolves(
    "moontown", "civic.communication.synthesize", "WorkspaceMutation", "execution-result",
  )
  assert_exact_catalog_operation_resolves(
    "moonrobo", "robot.integrate-digital-model", "WorkspaceMutation", "digital-artifact",
  )
  assert_exact_catalog_operation_resolves(
    "moonrobo",
    "robot.readiness.inspect",
    "Observe",
    "observation",
    review_required=false,
  )
  assert_exact_catalog_operation_resolves(
    "moonrobo",
    "robot.command.submit-governed",
    "WorkspaceMutation",
    "execution-result",
    review_required=false,
  )
  assert_exact_catalog_operation_resolves(
    "moonmoon", "simulation.robot-mission", "SandboxExecution", "calibrated-digital-twin",
  )
  assert_exact_catalog_operation_resolves(
    "moonmoon", "simulation.mission-result.inspect", "Observe", "simulation-evidence",
  )
}

///|
async test "capability resolution rejects invented operations and inventory aliases" {
  @fsx.with_temporary_directory("moongate-capability-alias-XXXXXX", root => {
    let (pack_root, _, catalog_path) = write_capability_fixture(
      root, "moonmold", "spatial.operation.execute",
    )
    let (moonstat_root, _, moonstat_catalog) = write_capability_fixture(
      root,
      "moonstat",
      "capability-probe",
      authority="Observe",
      claim_ceiling="observation",
    )
    let (moonwiki_root, _, moonwiki_catalog) = write_capability_fixture(
      root, "moonwiki", "wiki.requirements.prepare",
    )
    let (mooncode_root, _, mooncode_catalog) = write_capability_fixture(
      root, "mooncode", "agent.goal.execute",
    )
    let registry_path = @pathx.join(root, "product-registry.json")
    @fsx.write_to_file(
      registry_path,
      Json::object({
        "kind": Json::string("moonsuite-product-registry.v1"),
        "products": Json::array([
          Json::object({
            "id": Json::string("moonmold"),
            "name": Json::string("MoonMold"),
            "kind": Json::string("domain-pack"),
            "status": Json::string("installed"),
            "repo_path": Json::string(pack_root),
            "capability_catalog_path": Json::string(catalog_path),
            "capabilities": Json::array([]),
          }),
          Json::object({
            "id": Json::string("moonstat"),
            "name": Json::string("MoonStat"),
            "kind": Json::string("moon-suite-product"),
            "status": Json::string("installed"),
            "repo_path": Json::string(moonstat_root),
            "capability_catalog_path": Json::string(moonstat_catalog),
            "capabilities": Json::array([]),
          }),
          Json::object({
            "id": Json::string("moonmini"),
            "name": Json::string("MoonMini"),
            "kind": Json::string("moon-suite-product"),
            "status": Json::string("installed"),
            "repo_path": Json::string(""),
            "capabilities": Json::array([]),
          }),
          Json::object({
            "id": Json::string("moonwiki"),
            "name": Json::string("MoonWiki"),
            "kind": Json::string("moon-suite-product"),
            "status": Json::string("installed"),
            "repo_path": Json::string(moonwiki_root),
            "capability_catalog_path": Json::string(moonwiki_catalog),
            "capabilities": Json::array([]),
          }),
          Json::object({
            "id": Json::string("mooncode"),
            "name": Json::string("MoonCode"),
            "kind": Json::string("moon-suite-product"),
            "status": Json::string("installed"),
            "repo_path": Json::string(mooncode_root),
            "capability_catalog_path": Json::string(mooncode_catalog),
            "capabilities": Json::array([]),
          }),
        ]),
      }).stringify(indent=2),
    )
    let projection = moongate_capability_projection_json(
      suite_root=root,
      registry_path~,
    )
    let invented = moongate_capability_resolution_json(
      projection, "moonmold", "model.create-3d-assets",
    )
    guard invented is Object(invented_fields) else {
      fail("expected invented operation resolution")
    }
    assert_false(
      capability_json_bool(invented_fields, "executable").unwrap_or(true),
    )
    guard invented_fields["reasons"] is Array(invented_reasons) else {
      fail("expected rejection reasons")
    }
    assert_true(
      capability_findings_contain_code(
        invented_reasons, "operation-not-published",
      ),
    )
    for
      legacy_case in [
        ("moonstat", "capability-probe"),
        ("moonmini", "evaluation.score"),
        ("moonwiki", "wiki.requirements.prepare"),
        ("mooncode", "agent.goal.execute"),
      ] {
      let (legacy_id, operation_id) = legacy_case
      let rejected = moongate_capability_resolution_json(
        projection, legacy_id, operation_id,
      )
      guard rejected is Object(rejected_fields) else {
        fail("expected legacy identity resolution")
      }
      assert_false(
        capability_json_bool(rejected_fields, "executable").unwrap_or(true),
      )
      guard rejected_fields["reasons"] is Array(reasons) else {
        fail("expected identity reasons")
      }
      assert_true(
        capability_findings_contain_code(
          reasons,
          if legacy_id == "moonmini" {
            "operation-not-published"
          } else {
            "operation-not-executable"
          },
        ),
      )
      if legacy_id != "moonmini" {
        guard rejected_fields["operation"] is Object(operation) else {
          fail("expected blocked alias operation")
        }
        guard operation["findings"] is Array(operation_findings) else {
          fail("expected blocked alias findings")
        }
        assert_true(
          capability_findings_contain_code(
            operation_findings, "product-identity-not-callable",
          ),
        )
      }
    }
  })
}

///|
async test "pack declarations remain non executable without adapter health catalog evidence" {
  @fsx.with_temporary_directory("moongate-capability-declared-XXXXXX", root => {
    let (pack_root, _, catalog_path) = write_capability_fixture(
      root,
      "moonmold",
      "spatial.operation.execute",
      include_catalog_operation=false,
    )
    let registry_path = @pathx.join(root, "product-registry.json")
    @fsx.write_to_file(
      registry_path,
      Json::object({
        "kind": Json::string("moonsuite-product-registry.v1"),
        "products": Json::array([
          Json::object({
            "id": Json::string("moonmold"),
            "name": Json::string("MoonMold"),
            "kind": Json::string("domain-pack"),
            "status": Json::string("installed"),
            "repo_path": Json::string(pack_root),
            "capability_catalog_path": Json::string(catalog_path),
            "capabilities": Json::array([]),
          }),
        ]),
      }).stringify(indent=2),
    )
    let projection = moongate_capability_projection_json(
      suite_root=root,
      registry_path~,
    )
    guard projection is Object(fields) else { fail("expected projection") }
    guard fields["summary"] is Object(summary) else { fail("expected summary") }
    assert_eq(summary["declaredOperationCount"], Json::number(1.0))
    assert_eq(summary["executableOperationCount"], Json::number(0.0))
    let resolution = moongate_capability_resolution_json(
      projection, "moonmold", "spatial.operation.execute",
    )
    guard resolution is Object(resolved) else { fail("expected resolution") }
    assert_false(capability_json_bool(resolved, "executable").unwrap_or(true))
  })
}
