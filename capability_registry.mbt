///|
/// A parsed local document plus evidence that identifies its exact content.
priv struct CapabilityDocument {
  value : Json
  digest : String
}

///|
/// MoonGate keeps identity migration knowledge separate from executable
/// capability ownership. In particular, a legacy repository or product name
/// must never become a callable tool merely because it appears in inventory.
priv struct CapabilityIdentity {
  canonical_id : String
  kind : String
  callable : Bool
  migration_note : String
}

///|
fn capability_identity(product_id : String) -> CapabilityIdentity {
  let normalized = product_id.trim().to_owned().to_lower()
  match normalized {
    "moonstat" =>
      {
        canonical_id: "moongate",
        kind: "retired-migration-alias",
        callable: false,
        migration_note: "MoonStat is a retired MoonGate identity. Preserve old state for migration, but do not publish MoonStat operations.",
      }
    "moonmini" =>
      {
        canonical_id: "bunnia",
        kind: "framework-alias",
        callable: false,
        migration_note: "MoonMini identifies the Bunnia application framework, not an independently executable MoonSuite product.",
      }
    "moonwiki" =>
      {
        canonical_id: "moonbook",
        kind: "functionality-alias",
        callable: false,
        migration_note: "MoonWiki is research and requirements functionality owned by MoonBook. Its executable operation is moonbook/wiki.requirements.prepare, not a MoonWiki product.",
      }
    "mooncode" =>
      {
        canonical_id: "moonclaw",
        kind: "role-config-alias",
        callable: false,
        migration_note: "MoonCode is a MoonClaw execution role and configuration, not an independently callable product or agent runtime.",
      }
    _ =>
      {
        canonical_id: normalized,
        kind: "canonical",
        callable: !normalized.is_empty(),
        migration_note: "",
      }
  }
}

///|
fn capability_json_string(fields : Map[String, Json], key : String) -> String? {
  match fields.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn capability_json_string_any(
  fields : Map[String, Json],
  keys : Array[String],
) -> String? {
  for key in keys {
    match capability_json_string(fields, key) {
      Some(value) if !value.trim().is_empty() => return Some(value)
      _ => ()
    }
  }
  None
}

///|
fn capability_json_bool(fields : Map[String, Json], key : String) -> Bool? {
  match fields.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn capability_json_array(
  fields : Map[String, Json],
  key : String,
) -> Array[Json] {
  match fields.get(key) {
    Some(Array(values)) => values
    _ => []
  }
}

///|
fn capability_json_string_array(value : Json?) -> Array[String] {
  let values : Array[String] = []
  match value {
    Some(Array(items)) =>
      for item in items {
        match item {
          String(text) if !text.trim().is_empty() =>
            values.push(text.trim().to_owned())
          _ => ()
        }
      }
    _ => ()
  }
  values
}

///|
fn capability_json_bool_any(
  fields : Map[String, Json],
  keys : Array[String],
) -> Bool? {
  for key in keys {
    match capability_json_bool(fields, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn capability_document_digest(raw : String) -> String {
  "sha256:\{@crypto.bytes_to_hex_string(@crypto.sha256(@encoding/utf8.encode(raw)))}"
}

///|
async fn capability_read_document(
  path : String,
) -> Result[CapabilityDocument, String] {
  if path.trim().is_empty() {
    return Err("path is empty")
  }
  if !@fsx.exists(path) {
    return Err("file does not exist")
  }
  let raw = @fsx.read_file(path) catch {
    err => return Err("cannot read file: \{err}")
  }
  let value = @json.parse(raw) catch {
    err => return Err("invalid JSON: \{err}")
  }
  Ok({ value, digest: capability_document_digest(raw) })
}

///|
fn capability_finding(
  code : String,
  severity : String,
  product_id : String,
  operation_id : String,
  path : String,
  message : String,
  evidence_refs? : Array[String] = [],
) -> Json {
  let fields = {
    "code": Json::string(code),
    "severity": Json::string(severity),
    "productId": Json::string(product_id),
    "path": Json::string(path),
    "message": Json::string(message),
    "evidenceRefs": Json::array(
      evidence_refs.map(fn(value) { Json::string(value) }),
    ),
  }
  if !operation_id.is_empty() {
    fields["operationId"] = Json::string(operation_id)
  }
  Json::object(fields)
}

///|
fn capability_push_finding(
  local_findings : Array[Json],
  global : Array[Json],
  finding : Json,
) -> Unit {
  local_findings.push(finding)
  global.push(finding)
}

///|
fn capability_has_error(findings : Array[Json]) -> Bool {
  findings.any(fn(finding) {
    match finding {
      Object(fields) =>
        capability_json_string(fields, "severity").unwrap_or("") == "error"
      _ => false
    }
  })
}

///|
fn capability_path_has_parent_segment(path : String) -> Bool {
  @pathx.split(path).any(segment => segment == "..")
}

///|
fn capability_path_within(base : String, path : String) -> Bool {
  let normalized_base = @pathx.normalize(base)
  let normalized_path = @pathx.normalize(path)
  normalized_path == normalized_base ||
  normalized_path.has_prefix("\{normalized_base}/")
}

///|
fn capability_resolve_path(
  relative_or_absolute : String,
  base : String,
  suite_root : String,
) -> String? {
  let value = relative_or_absolute.trim().to_owned()
  if value.is_empty() || capability_path_has_parent_segment(value) {
    return None
  }
  let resolved = if @pathx.is_absolute(value) {
    @pathx.normalize(value)
  } else {
    @pathx.join(base, value)
  }
  if capability_path_within(base, resolved) ||
    capability_path_within(suite_root, resolved) {
    Some(resolved)
  } else {
    None
  }
}

///|
fn capability_normalize_authority(value : String) -> String {
  match value.trim().replace(old="_", new="-").to_lower() {
    "observe" => "observe"
    "cognitivemaintenance" | "cognitive-maintenance" => "cognitive-maintenance"
    "sandboxexecution" | "sandbox-execution" => "sandbox-execution"
    "workspacemutation" | "workspace-mutation" => "workspace-mutation"
    "externaleffect" | "external-effect" => "external-effect"
    "physicaleffect" | "physical-effect" => "physical-effect"
    _ => ""
  }
}

///|
fn capability_authority_rank(value : String) -> Int {
  match capability_normalize_authority(value) {
    "observe" => 0
    "cognitive-maintenance" => 1
    "sandbox-execution" => 2
    "workspace-mutation" => 3
    "external-effect" => 4
    "physical-effect" => 5
    _ => -1
  }
}

///|
fn capability_claim_rank(value : String) -> Int {
  match value.trim().to_lower() {
    "observation" => 0
    "research-evidence" => 1
    "execution-result" => 2
    "accepted-knowledge" => 3
    "digital-artifact" => 4
    "simulation-evidence" => 5
    "scenario-qualified" => 6
    "calibrated-digital-twin" => 7
    "hardware-in-loop-qualified" => 8
    "engineering-unit-qualified" => 9
    "physical-readiness" => 10
    "physical-effect-claim" => 11
    _ => -1
  }
}

///|
fn capability_boundary(product_id : String) -> @pipeline.ProductBoundary? {
  for boundary in constitutional_product_boundaries() {
    if boundary.product_id == product_id {
      return Some(boundary)
    }
  }
  None
}

///|
fn capability_boundary_authorities(
  boundary : @pipeline.ProductBoundary?,
) -> Array[String] {
  match boundary {
    Some(value) => value.allowed_authorities.map(authority => authority.id())
    None => []
  }
}

///|
fn capability_boundary_operations(
  boundary : @pipeline.ProductBoundary?,
) -> Array[String] {
  match boundary {
    Some(value) => value.operations.copy()
    None => []
  }
}

///|
fn capability_boundary_prohibited_claims(
  boundary : @pipeline.ProductBoundary?,
) -> Array[String] {
  match boundary {
    Some(value) => value.prohibited_claims.map(claim => claim.id())
    None => []
  }
}

///|
fn capability_boundary_claim_ceiling(
  boundary : @pipeline.ProductBoundary?,
) -> String {
  match boundary {
    Some(value) => value.claim_ceiling.id()
    None => ""
  }
}

///|
fn capability_policy_object(manifest : Map[String, Json]) -> Map[String, Json]? {
  match manifest.get("capability_policy") {
    Some(Object(fields)) => Some(fields)
    _ =>
      match manifest.get("capabilityPolicy") {
        Some(Object(fields)) => Some(fields)
        _ => None
      }
  }
}

///|
fn capability_policy_string_array(
  policy : Map[String, Json]?,
  snake_key : String,
  camel_key : String,
) -> Array[String] {
  match policy {
    Some(fields) => {
      let snake = capability_json_string_array(fields.get(snake_key))
      if !snake.is_empty() {
        snake
      } else {
        capability_json_string_array(fields.get(camel_key))
      }
    }
    None => []
  }
}

///|
fn capability_policy_string(
  policy : Map[String, Json]?,
  snake_key : String,
  camel_key : String,
) -> String {
  match policy {
    Some(fields) =>
      capability_json_string_any(fields, [snake_key, camel_key]).unwrap_or("")
    None => ""
  }
}

///|
fn capability_service_path(
  suite_root : String,
  inventory : Map[String, Json],
) -> String {
  capability_json_string_any(inventory, [
    "capability_catalog_path", "capabilityCatalogPath", "service_path", "servicePath",
  ]).unwrap_or(
    @moonsuite.product_service_path(
      suite_root,
      capability_json_string(inventory, "id").unwrap_or("unknown"),
    ),
  )
}

///|
fn capability_inventory_repo_path(inventory : Map[String, Json]) -> String {
  capability_json_string_any(inventory, ["repo_path", "repoPath"]).unwrap_or("")
}

///|
async fn capability_manifest_path(
  suite_root : String,
  inventory : Map[String, Json],
  service : Map[String, Json]?,
) -> String {
  let repo_path = capability_inventory_repo_path(inventory)
  let base = if repo_path.is_empty() { suite_root } else { repo_path }
  let explicit_inventory = capability_json_string_any(inventory, [
    "manifest_path", "manifestPath", "pack_manifest_path", "packManifestPath",
  ])
  let explicit_service = match service {
    Some(fields) =>
      capability_json_string_any(fields, [
        "manifest_path", "manifestPath", "pack_manifest_path", "packManifestPath",
      ])
    None => None
  }
  let explicit = match explicit_inventory {
    Some(path) => Some(path)
    None => explicit_service
  }
  match explicit {
    Some(path) =>
      match capability_resolve_path(path, base, suite_root) {
        Some(resolved) => return resolved
        None => return ""
      }
    None => ()
  }
  if !repo_path.is_empty() {
    for
      candidate in [
        @pathx.join(repo_path, "pack.json"),
        @pathx.join(repo_path, "moonpack/pack.json"),
      ] {
      if @fsx.exists(candidate) {
        return candidate
      }
    }
    return @pathx.join(repo_path, "pack.json")
  }
  ""
}

///|
fn capability_service_contract_valid(service : Map[String, Json]) -> Bool {
  capability_json_string_any(service, ["contract", "contract_id"]).unwrap_or("")
  is ("moonsuite.product-service.v1" | "moonflow.capability-catalog.v1")
}

///|
fn capability_service_contract(service : Map[String, Json]) -> String {
  capability_json_string_any(service, ["contract", "contract_id"]).unwrap_or("")
}

///|
fn capability_is_moonflow_catalog(service : Map[String, Json]) -> Bool {
  capability_service_contract(service) == "moonflow.capability-catalog.v1"
}

///|
fn capability_service_ready(service : Map[String, Json]) -> Bool {
  if capability_is_moonflow_catalog(service) {
    // The MoonFlow compiler publishes only operations whose versioned adapter
    // declaration and expiring health attestation passed its fail-closed
    // checks. A non-conformant catalog can still retain unrelated conformant
    // operations, so operation presence is evaluated individually below.
    return true
  }
  let status = capability_json_string(service, "status")
    .unwrap_or("")
    .to_lower()
  let status_ready = status is ("running" | "ready" | "healthy" | "available")
  capability_json_bool(service, "ready").unwrap_or(status_ready) && status_ready
}

///|
fn capability_service_endpoint(service : Map[String, Json]) -> String {
  capability_json_string_any(service, [
    "endpoint", "base_url", "baseUrl", "service_url", "serviceUrl",
  ]).unwrap_or("")
}

///|
fn capability_service_health_url(service : Map[String, Json]) -> String {
  capability_json_string_any(service, ["health_url", "healthUrl"]).unwrap_or("")
}

///|
fn capability_service_operation(
  service : Map[String, Json],
  product_id : String,
  operation_id : String,
) -> Json? {
  for entry in capability_json_array(service, "operations") {
    match entry {
      String(id) if id == operation_id => return Some(entry)
      Object(fields) =>
        if capability_json_string_any(fields, ["id", "tool_id", "toolId"]).unwrap_or(
            "",
          ) ==
          operation_id &&
          (
            !capability_is_moonflow_catalog(service) ||
            capability_json_string_any(fields, ["product_id", "productId"]).unwrap_or(
              "",
            ) ==
            product_id
          ) {
          return Some(entry)
        }
      _ => ()
    }
  }
  None
}

///|
fn capability_join_endpoint(base : String, endpoint : String) -> String {
  let target = endpoint.trim().to_owned()
  if target.has_prefix("http://") || target.has_prefix("https://") {
    return target
  }
  let root = base.trim().to_owned()
  if root.is_empty() || target.is_empty() {
    return ""
  }
  let left = if root.has_suffix("/") {
    root[:root.length() - 1].to_owned()
  } else {
    root
  }
  let right = if target.has_prefix("/") { target } else { "/\{target}" }
  "\{left}\{right}"
}

///|
async fn capability_schema_projection(
  suite_root : String,
  pack_root : String,
  product_id : String,
  entry : Json,
  findings : Array[Json],
  global_findings : Array[Json],
) -> Json {
  guard entry is Object(fields) else {
    let finding = capability_finding(
      "schema-entry-invalid", "error", product_id, "", "manifest.schemas", "Schema entries must be objects.",
    )
    capability_push_finding(findings, global_findings, finding)
    return Json::object({
      "id": Json::string(""),
      "available": Json::boolean(false),
      "findings": Json::array([finding]),
    })
  }
  let schema_id = capability_json_string(fields, "id").unwrap_or("")
  let version = capability_json_string(fields, "version").unwrap_or("")
  let relative_path = capability_json_string(fields, "path").unwrap_or("")
  let schema_findings : Array[Json] = []
  if schema_id.is_empty() {
    capability_push_finding(
      schema_findings,
      global_findings,
      capability_finding(
        "schema-id-missing", "error", product_id, "", "manifest.schemas.id", "Every schema needs a stable id.",
      ),
    )
  }
  if version.is_empty() {
    capability_push_finding(
      schema_findings,
      global_findings,
      capability_finding(
        "schema-version-missing",
        "error",
        product_id,
        "",
        "manifest.schemas.\{schema_id}.version",
        "Every executable schema reference must be versioned.",
      ),
    )
  }
  let resolved = capability_resolve_path(relative_path, pack_root, suite_root)
  let mut digest = ""
  let mut valid_json = false
  match resolved {
    Some(path) =>
      match capability_read_document(path) {
        Ok(document) => {
          digest = document.digest
          valid_json = true
        }
        Err(err) =>
          capability_push_finding(
            schema_findings,
            global_findings,
            capability_finding(
              "schema-document-unavailable",
              "error",
              product_id,
              "",
              "manifest.schemas.\{schema_id}.path",
              "Schema document is unavailable or invalid: \{err}",
              evidence_refs=[path],
            ),
          )
      }
    None =>
      capability_push_finding(
        schema_findings,
        global_findings,
        capability_finding(
          "schema-path-unsafe",
          "error",
          product_id,
          "",
          "manifest.schemas.\{schema_id}.path",
          "Schema paths must stay inside the pack or suite root.",
        ),
      )
  }
  for finding in schema_findings {
    findings.push(finding)
  }
  Json::object({
    "id": Json::string(schema_id),
    "version": Json::string(version),
    "path": match resolved {
      Some(path) => Json::string(path)
      None => Json::null()
    },
    "digest": if digest.is_empty() {
      Json::null()
    } else {
      Json::string(digest)
    },
    "available": Json::boolean(
      !schema_id.is_empty() &&
      !version.is_empty() &&
      valid_json &&
      !capability_has_error(schema_findings),
    ),
    "findings": Json::array(schema_findings),
  })
}

///|
fn capability_schema_available(schema : Json?) -> Bool {
  match schema {
    Some(Object(fields)) =>
      capability_json_bool(fields, "available").unwrap_or(false)
    _ => false
  }
}

///|
fn capability_schema_version(schema : Json?) -> String {
  match schema {
    Some(Object(fields)) =>
      capability_json_string(fields, "version").unwrap_or("")
    _ => ""
  }
}

///|
fn capability_operation_projection(
  product_id : String,
  identity : CapabilityIdentity,
  pack_version : String,
  tool : Json,
  schemas : Map[String, Json],
  boundary : @pipeline.ProductBoundary?,
  allowed_authorities : Array[String],
  owned_operations : Array[String],
  claim_ceiling : String,
  service : Map[String, Json]?,
  service_valid : Bool,
  manifest_valid : Bool,
  duplicate_identity : Bool,
  product_findings : Array[Json],
  global_findings : Array[Json],
) -> Json {
  guard tool is Object(fields) else {
    let finding = capability_finding(
      "operation-entry-invalid", "error", product_id, "", "manifest.tools", "Tool entries must be objects.",
    )
    capability_push_finding(product_findings, global_findings, finding)
    return Json::object({
      "id": Json::string(""),
      "executable": Json::boolean(false),
      "findings": Json::array([finding]),
    })
  }
  let operation_id = capability_json_string(fields, "id").unwrap_or("")
  let owner = capability_json_string_any(fields, [
    "owner_product", "ownerProduct",
  ]).unwrap_or("")
  let input_schema_id = capability_json_string_any(fields, [
    "input_schema_id", "inputSchemaId",
  ]).unwrap_or("")
  let output_schema_id = capability_json_string_any(fields, [
    "output_schema_id", "outputSchemaId",
  ]).unwrap_or("")
  let raw_authority = capability_json_string(fields, "authority").unwrap_or("")
  let authority = capability_normalize_authority(raw_authority)
  let declared_version = capability_json_string(fields, "version").unwrap_or("")
  let operation_version = if declared_version.is_empty() {
    pack_version
  } else {
    declared_version
  }
  let operation_findings : Array[Json] = []
  if operation_id.is_empty() {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "operation-id-missing", "error", product_id, "", "manifest.tools.id", "Every operation needs a stable id.",
      ),
    )
  }
  if declared_version.is_empty() && !pack_version.is_empty() {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "operation-version-inherited",
        "warning",
        product_id,
        operation_id,
        "manifest.tools.\{operation_id}.version",
        "Operation version is inherited from the pack. An explicit operation version is recommended.",
      ),
    )
  }
  if operation_version.is_empty() {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "operation-version-missing",
        "error",
        product_id,
        operation_id,
        "manifest.tools.\{operation_id}.version",
        "An executable operation must have a version.",
      ),
    )
  }
  if owner != product_id {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "operation-owner-mismatch",
        "error",
        product_id,
        operation_id,
        "manifest.tools.\{operation_id}.owner_product",
        "Operation owner '\{owner}' does not match inventory product '\{product_id}'.",
      ),
    )
  }
  let service_operation = match service {
    Some(service_fields) =>
      capability_service_operation(service_fields, product_id, operation_id)
    None => None
  }
  let moonflow_catalog_operation = match (service, service_operation) {
    (Some(service_fields), Some(Object(_))) =>
      capability_is_moonflow_catalog(service_fields)
    _ => false
  }
  let adapter_authority = match service_operation {
    Some(Object(service_fields)) =>
      capability_normalize_authority(
        capability_json_string(service_fields, "authority").unwrap_or(""),
      )
    _ => ""
  }
  if authority.is_empty() {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "operation-authority-invalid",
        "error",
        product_id,
        operation_id,
        "manifest.tools.\{operation_id}.authority",
        "Operation authority '\{raw_authority}' is not a supported generic authority class.",
      ),
    )
  } else if !allowed_authorities.contains(authority) &&
    !(moonflow_catalog_operation && adapter_authority == authority) {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "operation-authority-outside-policy",
        "error",
        product_id,
        operation_id,
        "manifest.tools.\{operation_id}.authority",
        "Operation authority '\{authority}' is outside the product authority policy.",
      ),
    )
  }
  if boundary is Some(_) && !owned_operations.contains(operation_id) {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "operation-not-in-boundary-policy",
        "error",
        product_id,
        operation_id,
        "manifest.tools.\{operation_id}.id",
        "The manifest operation is not owned by the authoritative product boundary.",
      ),
    )
  }
  let adapter_claim_ceiling = match service_operation {
    Some(Object(service_fields)) =>
      capability_json_string_any(service_fields, [
        "claim_ceiling", "claimCeiling",
      ]).unwrap_or("")
    _ => ""
  }
  let effective_claim_ceiling = if adapter_claim_ceiling.is_empty() {
    claim_ceiling
  } else {
    adapter_claim_ceiling
  }
  if moonflow_catalog_operation && adapter_claim_ceiling.is_empty() {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "adapter-claim-ceiling-missing",
        "error",
        product_id,
        operation_id,
        "service.operations.\{operation_id}.claim_ceiling",
        "The compiled MoonFlow operation must publish its exact claim ceiling.",
      ),
    )
  }
  if effective_claim_ceiling.is_empty() {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "claim-ceiling-missing", "error", product_id, operation_id, "manifest.capability_policy.claim_ceiling",
        "MoonFlow cannot execute an operation without an explicit product claim ceiling.",
      ),
    )
  } else if capability_claim_rank(effective_claim_ceiling) < 0 {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "claim-ceiling-invalid",
        "error",
        product_id,
        operation_id,
        "service.operations.\{operation_id}.claim_ceiling",
        "Claim ceiling '\{effective_claim_ceiling}' is not a canonical MoonSuite claim class.",
      ),
    )
  } else if !claim_ceiling.is_empty() &&
    capability_claim_rank(effective_claim_ceiling) >
    capability_claim_rank(claim_ceiling) {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "adapter-claim-ceiling-outside-policy",
        "error",
        product_id,
        operation_id,
        "service.operations.\{operation_id}.claim_ceiling",
        "The compiled operation claim ceiling '\{effective_claim_ceiling}' exceeds the product ceiling '\{claim_ceiling}'.",
      ),
    )
  }
  let input_schema = schemas.get(input_schema_id)
  let output_schema = schemas.get(output_schema_id)
  if input_schema_id.is_empty() || !capability_schema_available(input_schema) {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "operation-input-schema-unavailable",
        "error",
        product_id,
        operation_id,
        "manifest.tools.\{operation_id}.input_schema_id",
        "The input schema reference is missing, invalid, or unavailable.",
      ),
    )
  }
  if output_schema_id.is_empty() || !capability_schema_available(output_schema) {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "operation-output-schema-unavailable",
        "error",
        product_id,
        operation_id,
        "manifest.tools.\{operation_id}.output_schema_id",
        "The output schema reference is missing, invalid, or unavailable.",
      ),
    )
  }
  let service_ready = match service {
    Some(service_fields) =>
      service_valid && capability_service_ready(service_fields)
    None => false
  }
  if !service_ready {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "service-not-ready", "error", product_id, operation_id, "service.ready",
        "The product service has not published healthy, ready evidence.",
      ),
    )
  }
  if service_operation is None {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "service-operation-not-published", "error", product_id, operation_id, "service.operations",
        "Inventory or pack presence is not execution evidence; the live service must publish this operation.",
      ),
    )
  }
  let service_base = match service {
    Some(service_fields) => capability_service_endpoint(service_fields)
    None => ""
  }
  let operation_endpoint = match service_operation {
    Some(Object(service_fields)) =>
      capability_json_string_any(service_fields, ["endpoint", "path", "url"]).unwrap_or(
        capability_json_string_any(fields, ["endpoint", "path", "url"]).unwrap_or(
          "",
        ),
      )
    Some(String(_)) =>
      capability_json_string_any(fields, ["endpoint", "path", "url"]).unwrap_or(
        "",
      )
    _ => ""
  }
  let endpoint = capability_join_endpoint(service_base, operation_endpoint)
  let adapter_id = match service_operation {
    Some(Object(service_fields)) =>
      capability_json_string_any(service_fields, ["adapter_id", "adapterId"]).unwrap_or(
        "",
      )
    _ => ""
  }
  let adapter_protocol = match service_operation {
    Some(Object(service_fields)) =>
      capability_json_string(service_fields, "protocol").unwrap_or("")
    _ => ""
  }
  let adapter_binding_ready = moonflow_catalog_operation &&
    !adapter_id.is_empty() &&
    adapter_protocol == "moonflow.adapter.v2"
  if endpoint.is_empty() && !adapter_binding_ready {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "operation-endpoint-missing",
        "error",
        product_id,
        operation_id,
        "service.operations.\{operation_id}.endpoint",
        "The service has not published an endpoint for this operation.",
      ),
    )
  }
  match service_operation {
    Some(Object(service_fields)) => {
      let service_version = capability_json_string_any(service_fields, [
        "version", "pack_version", "packVersion",
      ]).unwrap_or(operation_version)
      if service_version != operation_version {
        capability_push_finding(
          operation_findings,
          global_findings,
          capability_finding(
            "operation-version-drift",
            "error",
            product_id,
            operation_id,
            "service.operations.\{operation_id}.version",
            "Service operation version '\{service_version}' does not match manifest version '\{operation_version}'.",
          ),
        )
      }
      if moonflow_catalog_operation {
        let expected_operation_ref = "\{product_id}/\{operation_id}@\{pack_version}"
        let observed_operation_ref = capability_json_string_any(
          service_fields,
          ["operation_ref", "operationRef"],
        ).unwrap_or("")
        if observed_operation_ref != expected_operation_ref {
          capability_push_finding(
            operation_findings,
            global_findings,
            capability_finding(
              "operation-reference-drift",
              "error",
              product_id,
              operation_id,
              "service.operations.\{operation_id}.operation_ref",
              "Compiled operation reference '\{observed_operation_ref}' does not match '\{expected_operation_ref}'.",
            ),
          )
        }
        let expected_input_ref = "\{product_id}/\{input_schema_id}@\{capability_schema_version(input_schema)}"
        let expected_output_ref = "\{product_id}/\{output_schema_id}@\{capability_schema_version(output_schema)}"
        let observed_input_ref = capability_json_string_any(service_fields, [
          "input_schema_ref", "inputSchemaRef",
        ]).unwrap_or("")
        let observed_output_ref = capability_json_string_any(service_fields, [
          "output_schema_ref", "outputSchemaRef",
        ]).unwrap_or("")
        if observed_input_ref != expected_input_ref {
          capability_push_finding(
            operation_findings,
            global_findings,
            capability_finding(
              "input-schema-reference-drift",
              "error",
              product_id,
              operation_id,
              "service.operations.\{operation_id}.input_schema_ref",
              "Compiled input schema reference does not match the installed manifest.",
            ),
          )
        }
        if observed_output_ref != expected_output_ref {
          capability_push_finding(
            operation_findings,
            global_findings,
            capability_finding(
              "output-schema-reference-drift",
              "error",
              product_id,
              operation_id,
              "service.operations.\{operation_id}.output_schema_ref",
              "Compiled output schema reference does not match the installed manifest.",
            ),
          )
        }
        if !capability_json_bool_any(service_fields, [
            "supports_reconcile", "supportsReconcile",
          ]).unwrap_or(false) {
          capability_push_finding(
            operation_findings,
            global_findings,
            capability_finding(
              "adapter-reconcile-unsupported",
              "error",
              product_id,
              operation_id,
              "service.operations.\{operation_id}.supports_reconcile",
              "Production MoonFlow adapter bindings must support reconciliation.",
            ),
          )
        }
      }
    }
    _ => ()
  }
  if !identity.callable || duplicate_identity || !manifest_valid {
    capability_push_finding(
      operation_findings,
      global_findings,
      capability_finding(
        "product-identity-not-callable",
        "error",
        product_id,
        operation_id,
        "inventory.products.\{product_id}.id",
        "This inventory identity cannot own executable operations.",
      ),
    )
  }
  for finding in operation_findings {
    product_findings.push(finding)
  }
  let executable = !capability_has_error(operation_findings)
  Json::object({
    "id": Json::string(operation_id),
    "version": Json::string(operation_version),
    "versionSource": Json::string(
      if declared_version.is_empty() {
        "pack"
      } else {
        "operation"
      },
    ),
    "ownerProduct": Json::string(owner),
    "authority": Json::string(authority),
    "claimCeiling": if effective_claim_ceiling.is_empty() {
      Json::null()
    } else {
      Json::string(effective_claim_ceiling)
    },
    "inputSchema": Json::object({
      "id": Json::string(input_schema_id),
      "version": Json::string(capability_schema_version(input_schema)),
    }),
    "outputSchema": Json::object({
      "id": Json::string(output_schema_id),
      "version": Json::string(capability_schema_version(output_schema)),
    }),
    "reviewRequired": Json::boolean(
      capability_json_bool_any(fields, ["review_required", "reviewRequired"]).unwrap_or(
        false,
      ),
    ),
    "idempotent": Json::boolean(
      capability_json_bool(fields, "idempotent").unwrap_or(false),
    ),
    "endpoint": if endpoint.is_empty() {
      Json::null()
    } else {
      Json::string(endpoint)
    },
    "adapterBinding": if adapter_binding_ready {
      Json::object({
        "adapterId": Json::string(adapter_id),
        "protocol": Json::string(adapter_protocol),
        "supportsCancel": match service_operation {
          Some(Object(service_fields)) =>
            Json::boolean(
              capability_json_bool_any(service_fields, [
                "supports_cancel", "supportsCancel",
              ]).unwrap_or(false),
            )
          _ => Json::boolean(false)
        },
        "supportsReconcile": match service_operation {
          Some(Object(service_fields)) =>
            Json::boolean(
              capability_json_bool_any(service_fields, [
                "supports_reconcile", "supportsReconcile",
              ]).unwrap_or(false),
            )
          _ => Json::boolean(false)
        },
      })
    } else {
      Json::null()
    },
    "healthEvidence": if moonflow_catalog_operation {
      match service_operation {
        Some(Object(service_fields)) =>
          Json::object({
            "checkedAt": service_fields
            .get("health_checked_at")
            .unwrap_or(Json::null()),
            "validUntil": service_fields
            .get("health_valid_until")
            .unwrap_or(Json::null()),
            "evidenceRef": service_fields
            .get("health_evidence_ref")
            .unwrap_or(Json::null()),
            "evidenceDigest": service_fields
            .get("health_evidence_digest")
            .unwrap_or(Json::null()),
          })
        _ => Json::null()
      }
    } else {
      Json::null()
    },
    "servicePublished": Json::boolean(service_operation is Some(_)),
    "executable": Json::boolean(executable),
    "availability": Json::string(
      if executable {
        if adapter_binding_ready {
          "adapter-ready"
        } else {
          "endpoint-ready"
        }
      } else {
        "declared-only"
      },
    ),
    "findings": Json::array(operation_findings),
  })
}

///|
async fn capability_product_projection(
  suite_root : String,
  inventory : Json,
  duplicate_identity : Bool,
  registry_path : String,
  registry_digest : String,
  global_findings : Array[Json],
) -> Json {
  guard inventory is Object(fields) else {
    let finding = capability_finding(
      "inventory-entry-invalid",
      "error",
      "",
      "",
      "inventory.products",
      "Product inventory entries must be objects.",
      evidence_refs=[registry_path],
    )
    global_findings.push(finding)
    return Json::object({
      "productId": Json::string(""),
      "inventoryPresent": Json::boolean(true),
      "capabilityStatus": Json::string("blocked"),
      "operations": Json::array([]),
      "findings": Json::array([finding]),
    })
  }
  let product_id = capability_json_string(fields, "id").unwrap_or("")
  let identity = capability_identity(product_id)
  let product_findings : Array[Json] = []
  if product_id.is_empty() {
    capability_push_finding(
      product_findings,
      global_findings,
      capability_finding(
        "inventory-product-id-missing",
        "error",
        product_id,
        "",
        "inventory.products.id",
        "Every product inventory record needs an id.",
        evidence_refs=[registry_path],
      ),
    )
  }
  if duplicate_identity {
    capability_push_finding(
      product_findings,
      global_findings,
      capability_finding(
        "duplicate-product-id",
        "error",
        product_id,
        "",
        "inventory.products.\{product_id}",
        "Duplicate product identities make operation resolution ambiguous.",
        evidence_refs=[registry_path],
      ),
    )
  }
  if identity.kind != "canonical" {
    capability_push_finding(
      product_findings,
      global_findings,
      capability_finding(
        if product_id.to_lower() == "moonstat" {
          "retired-moonstat-identity"
        } else {
          "framework-identity-not-product"
        },
        "error",
        product_id,
        "",
        "inventory.products.\{product_id}.id",
        identity.migration_note,
        evidence_refs=[registry_path],
      ),
    )
  }
  let inventory_status = capability_json_string(fields, "status").unwrap_or(
    "unknown",
  )
  let inventory_capabilities = capability_json_string_array(
    fields.get("capabilities"),
  )
  if !inventory_capabilities.is_empty() {
    capability_push_finding(
      product_findings,
      global_findings,
      capability_finding(
        "inventory-capabilities-unverified",
        "warning",
        product_id,
        "",
        "inventory.products.\{product_id}.capabilities",
        "Inventory capability labels are descriptive only and cannot make an operation executable.",
        evidence_refs=[registry_path],
      ),
    )
  }
  let service_path = capability_service_path(suite_root, fields)
  let service_document = capability_read_document(service_path)
  let service = match service_document {
    Ok(document) =>
      match document.value {
        Object(service_fields) => Some(service_fields)
        _ => {
          capability_push_finding(
            product_findings,
            global_findings,
            capability_finding(
              "service-descriptor-invalid",
              "error",
              product_id,
              "",
              "service",
              "Product service descriptor must be a JSON object.",
              evidence_refs=[service_path],
            ),
          )
          None
        }
      }
    Err(err) => {
      capability_push_finding(
        product_findings,
        global_findings,
        capability_finding(
          "service-descriptor-unavailable",
          "warning",
          product_id,
          "",
          "service",
          "No live product service evidence is available: \{err}",
          evidence_refs=[service_path],
        ),
      )
      None
    }
  }
  let service_valid = match service {
    Some(service_fields) => {
      let valid_contract = capability_service_contract_valid(service_fields)
      if !valid_contract {
        capability_push_finding(
          product_findings,
          global_findings,
          capability_finding(
            "service-contract-invalid",
            "error",
            product_id,
            "",
            "service.contract",
            "Runtime evidence must use moonsuite.product-service.v1 or a compiled moonflow.capability-catalog.v1.",
            evidence_refs=[service_path],
          ),
        )
      }
      let catalog_contract = capability_is_moonflow_catalog(service_fields)
      let service_product_id = if catalog_contract {
        product_id
      } else {
        capability_json_string_any(service_fields, ["product_id", "productId"]).unwrap_or(
          "",
        )
      }
      if !catalog_contract && service_product_id != product_id {
        capability_push_finding(
          product_findings,
          global_findings,
          capability_finding(
            "service-product-mismatch",
            "error",
            product_id,
            "",
            "service.product_id",
            "Service product '\{service_product_id}' does not match inventory product '\{product_id}'.",
            evidence_refs=[service_path],
          ),
        )
      }
      valid_contract && (catalog_contract || service_product_id == product_id)
    }
    None => false
  }
  let manifest_path = capability_manifest_path(suite_root, fields, service)
  if manifest_path.is_empty() {
    capability_push_finding(
      product_findings,
      global_findings,
      capability_finding(
        "pack-manifest-path-unavailable",
        "warning",
        product_id,
        "",
        "inventory.products.\{product_id}.manifest_path",
        "No pack manifest path can be derived from inventory or service evidence.",
        evidence_refs=[registry_path, service_path],
      ),
    )
  }
  let manifest_document = if manifest_path.is_empty() {
    Err("manifest path is unavailable")
  } else {
    capability_read_document(manifest_path)
  }
  let manifest = match manifest_document {
    Ok(document) =>
      match document.value {
        Object(manifest_fields) => Some(manifest_fields)
        _ => {
          capability_push_finding(
            product_findings,
            global_findings,
            capability_finding(
              "pack-manifest-invalid",
              "error",
              product_id,
              "",
              "manifest",
              "Pack manifest must be a JSON object.",
              evidence_refs=[manifest_path],
            ),
          )
          None
        }
      }
    Err(err) => {
      capability_push_finding(
        product_findings,
        global_findings,
        capability_finding(
          "pack-manifest-unavailable",
          "warning",
          product_id,
          "",
          "manifest",
          "No executable pack declaration is available: \{err}",
          evidence_refs=if manifest_path.is_empty() {
            []
          } else {
            [manifest_path]
          },
        ),
      )
      None
    }
  }
  let manifest_valid = match manifest {
    Some(manifest_fields) => {
      let manifest_id = capability_json_string(manifest_fields, "id").unwrap_or(
        "",
      )
      let manifest_product_id = capability_json_string_any(manifest_fields, [
        "product_id", "productId",
      ]).unwrap_or(manifest_id)
      if manifest_id != product_id || manifest_product_id != product_id {
        capability_push_finding(
          product_findings,
          global_findings,
          capability_finding(
            "pack-manifest-product-mismatch",
            "error",
            product_id,
            "",
            "manifest.id",
            "Pack id '\{manifest_id}' and product id '\{manifest_product_id}' must both match inventory product '\{product_id}'.",
            evidence_refs=[manifest_path],
          ),
        )
      }
      manifest_id == product_id && manifest_product_id == product_id
    }
    None => false
  }
  let boundary = capability_boundary(identity.canonical_id)
  let policy = match manifest {
    Some(manifest_fields) => capability_policy_object(manifest_fields)
    None => None
  }
  let manifest_authorities = capability_policy_string_array(
    policy, "authority_classes", "authorityClasses",
  ).map(capability_normalize_authority)
  let allowed_authorities = if manifest_authorities.is_empty() {
    capability_boundary_authorities(boundary)
  } else {
    manifest_authorities
  }
  let manifest_operations = capability_policy_string_array(
    policy, "owned_operations", "ownedOperations",
  )
  let owned_operations = if manifest_operations.is_empty() {
    capability_boundary_operations(boundary)
  } else {
    manifest_operations
  }
  let declared_claim_ceiling = capability_policy_string(
    policy, "claim_ceiling", "claimCeiling",
  )
  let claim_ceiling = if declared_claim_ceiling.is_empty() {
    capability_boundary_claim_ceiling(boundary)
  } else {
    declared_claim_ceiling
  }
  let prohibited_claims = {
    let from_manifest = capability_policy_string_array(
      policy, "prohibited_claims", "prohibitedClaims",
    )
    if from_manifest.is_empty() {
      capability_boundary_prohibited_claims(boundary)
    } else {
      from_manifest
    }
  }
  if boundary is None && policy is None {
    let has_moonflow_catalog = match service {
      Some(service_fields) => capability_is_moonflow_catalog(service_fields)
      None => false
    }
    capability_push_finding(
      product_findings,
      global_findings,
      capability_finding(
        "product-policy-unavailable",
        if has_moonflow_catalog {
          "warning"
        } else {
          "error"
        },
        product_id,
        "",
        "manifest.capability_policy",
        if has_moonflow_catalog {
          "Product authority and per-operation claim ceilings come from the compiled MoonFlow adapter catalog; add a pack capability policy only when product-wide ceilings are required."
        } else {
          "Product is inventoried, but neither a MoonGate boundary nor a pack capability policy or compiled MoonFlow adapter catalog defines its authority and claim ceiling."
        },
        evidence_refs=if manifest_path.is_empty() {
          []
        } else {
          [manifest_path]
        },
      ),
    )
  }
  let pack_root = if manifest_path.is_empty() {
    suite_root
  } else {
    @pathx.dirname(manifest_path).to_owned()
  }
  let schemas : Map[String, Json] = Map([])
  let schema_rows : Array[Json] = []
  match manifest {
    Some(manifest_fields) =>
      for schema_entry in capability_json_array(manifest_fields, "schemas") {
        let schema = capability_schema_projection(
          suite_root, pack_root, product_id, schema_entry, product_findings, global_findings,
        )
        schema_rows.push(schema)
        match schema {
          Object(schema_fields) => {
            let schema_id = capability_json_string(schema_fields, "id").unwrap_or(
              "",
            )
            if !schema_id.is_empty() {
              if schemas.contains(schema_id) {
                capability_push_finding(
                  product_findings,
                  global_findings,
                  capability_finding(
                    "duplicate-schema-id",
                    "error",
                    product_id,
                    "",
                    "manifest.schemas.\{schema_id}",
                    "Duplicate schema ids make tool contracts ambiguous.",
                    evidence_refs=[manifest_path],
                  ),
                )
              } else {
                schemas[schema_id] = schema
              }
            }
          }
          _ => ()
        }
      }
    None => ()
  }
  let pack_version = match manifest {
    Some(manifest_fields) =>
      capability_json_string(manifest_fields, "version").unwrap_or("")
    None => ""
  }
  let operations : Array[Json] = []
  match manifest {
    Some(manifest_fields) =>
      for tool in capability_json_array(manifest_fields, "tools") {
        operations.push(
          capability_operation_projection(
            product_id, identity, pack_version, tool, schemas, boundary, allowed_authorities,
            owned_operations, claim_ceiling, service, service_valid, manifest_valid,
            duplicate_identity, product_findings, global_findings,
          ),
        )
      }
    None => ()
  }
  let executable_count = operations
    .filter(fn(operation) {
      match operation {
        Object(operation_fields) =>
          capability_json_bool(operation_fields, "executable").unwrap_or(false)
        _ => false
      }
    })
    .length()
  let capability_status = if !identity.callable || duplicate_identity {
    "blocked"
  } else if executable_count > 0 {
    "executable"
  } else if !operations.is_empty() {
    "declared-only"
  } else {
    "inventory-only"
  }
  let service_digest = match service_document {
    Ok(document) => document.digest
    Err(_) => ""
  }
  let manifest_digest = match manifest_document {
    Ok(document) => document.digest
    Err(_) => ""
  }
  Json::object({
    "productId": Json::string(product_id),
    "canonicalProductId": Json::string(identity.canonical_id),
    "name": Json::string(
      capability_json_string(fields, "name").unwrap_or(product_id),
    ),
    "kind": Json::string(
      capability_json_string(fields, "kind").unwrap_or("unknown"),
    ),
    "inventoryPresent": Json::boolean(true),
    "inventoryStatus": Json::string(inventory_status),
    "inventoryCapabilities": Json::array(
      inventory_capabilities.map(value => Json::string(value)),
    ),
    "identity": Json::object({
      "kind": Json::string(identity.kind),
      "canonicalProductId": Json::string(identity.canonical_id),
      "callable": Json::boolean(identity.callable),
      "migrationNote": if identity.migration_note.is_empty() {
        Json::null()
      } else {
        Json::string(identity.migration_note)
      },
    }),
    "policy": Json::object({
      "source": Json::string(
        if policy is Some(_) {
          "pack-manifest"
        } else if boundary is Some(_) {
          "moongate-boundary"
        } else if (match service {
            Some(service_fields) =>
              capability_is_moonflow_catalog(service_fields)
            None => false
          }) {
          "moonflow-capability-catalog"
        } else {
          "unavailable"
        },
      ),
      "claimCeiling": if claim_ceiling.is_empty() {
        Json::null()
      } else {
        Json::string(claim_ceiling)
      },
      "allowedAuthorities": Json::array(
        allowed_authorities.map(value => Json::string(value)),
      ),
      "ownedOperations": Json::array(
        owned_operations.map(value => Json::string(value)),
      ),
      "prohibitedClaims": Json::array(
        prohibited_claims.map(value => Json::string(value)),
      ),
    }),
    "manifest": Json::object({
      "path": if manifest_path.is_empty() {
        Json::null()
      } else {
        Json::string(manifest_path)
      },
      "available": Json::boolean(manifest is Some(_)),
      "valid": Json::boolean(manifest_valid),
      "version": if pack_version.is_empty() {
        Json::null()
      } else {
        Json::string(pack_version)
      },
      "digest": if manifest_digest.is_empty() {
        Json::null()
      } else {
        Json::string(manifest_digest)
      },
    }),
    "service": Json::object({
      "path": Json::string(service_path),
      "contractValid": Json::boolean(service_valid),
      "status": match service {
        Some(service_fields) =>
          Json::string(
            if capability_is_moonflow_catalog(service_fields) {
              "compiled"
            } else {
              capability_json_string(service_fields, "status").unwrap_or(
                "unknown",
              )
            },
          )
        None => Json::string("not-published")
      },
      "contract": match service {
        Some(service_fields) =>
          Json::string(capability_service_contract(service_fields))
        None => Json::null()
      },
      "ready": Json::boolean(
        match service {
          Some(service_fields) =>
            service_valid && capability_service_ready(service_fields)
          None => false
        },
      ),
      "endpoint": match service {
        Some(service_fields) => {
          let endpoint = capability_service_endpoint(service_fields)
          if endpoint.is_empty() {
            Json::null()
          } else {
            Json::string(endpoint)
          }
        }
        None => Json::null()
      },
      "healthUrl": match service {
        Some(service_fields) => {
          let health_url = capability_service_health_url(service_fields)
          if health_url.is_empty() {
            Json::null()
          } else {
            Json::string(health_url)
          }
        }
        None => Json::null()
      },
      "healthEvidenceSource": Json::string("service-descriptor"),
      "digest": if service_digest.is_empty() {
        Json::null()
      } else {
        Json::string(service_digest)
      },
    }),
    "schemas": Json::array(schema_rows),
    "operations": Json::array(operations),
    "declaredOperationCount": Json::number(operations.length().to_double()),
    "executableOperationCount": Json::number(executable_count.to_double()),
    "capabilityStatus": Json::string(capability_status),
    "conformance": Json::object({
      "accepted": Json::boolean(!capability_has_error(product_findings)),
      "findingCount": Json::number(product_findings.length().to_double()),
    }),
    "evidence": Json::object({
      "inventoryPath": Json::string(registry_path),
      "inventoryDigest": Json::string(registry_digest),
      "manifestPath": if manifest_path.is_empty() {
        Json::null()
      } else {
        Json::string(manifest_path)
      },
      "servicePath": Json::string(service_path),
    }),
    "findings": Json::array(product_findings),
  })
}

///|
/// Project the live MoonSuite inventory into a fail-closed capability catalog.
///
/// Inventory presence is never treated as execution evidence. An operation is
/// executable only when identity, pack, versioned schemas, authority policy,
/// claim ceiling, service publication, service health, and endpoint evidence
/// all agree.
pub async fn moongate_capability_projection_json(
  suite_root? : String = ".",
  registry_path? : String = "",
) -> Json {
  let root = moongate_normalize_suite_root(suite_root)
  let path = if registry_path.trim().is_empty() {
    @moonsuite.product_registry_path(root)
  } else {
    registry_path
  }
  let global_findings : Array[Json] = []
  let registry_document = capability_read_document(path)
  let (registry, registry_digest) = match registry_document {
    Ok(document) => (document.value, document.digest)
    Err(err) => {
      global_findings.push(
        capability_finding(
          "product-registry-unavailable",
          "error",
          "",
          "",
          "inventory",
          "Live product inventory is unavailable: \{err}",
          evidence_refs=[path],
        ),
      )
      (Json::empty_object(), "")
    }
  }
  let inventory_rows = match registry {
    Object(fields) => {
      let kind = capability_json_string(fields, "kind").unwrap_or("")
      if kind != "moonsuite-product-registry.v1" {
        global_findings.push(
          capability_finding(
            "product-registry-contract-invalid",
            "error",
            "",
            "",
            "inventory.kind",
            "Product inventory must use moonsuite-product-registry.v1.",
            evidence_refs=[path],
          ),
        )
      }
      capability_json_array(fields, "products")
    }
    _ => []
  }
  let counts : Map[String, Int] = Map([])
  for row in inventory_rows {
    match row {
      Object(fields) => {
        let id = capability_json_string(fields, "id").unwrap_or("")
        counts[id] = counts.get(id).unwrap_or(0) + 1
      }
      _ => ()
    }
  }
  let products : Array[Json] = []
  let operations : Array[Json] = []
  for row in inventory_rows {
    let id = match row {
      Object(fields) => capability_json_string(fields, "id").unwrap_or("")
      _ => ""
    }
    let product = capability_product_projection(
      root,
      row,
      counts.get(id).unwrap_or(0) > 1,
      path,
      registry_digest,
      global_findings,
    )
    match product {
      Object(product_fields) =>
        for operation in capability_json_array(product_fields, "operations") {
          match operation {
            Object(operation_fields) => {
              let flattened = operation_fields.copy()
              flattened["productId"] = Json::string(id)
              operations.push(Json::object(flattened))
            }
            _ => ()
          }
        }
      _ => ()
    }
    products.push(product)
  }
  let executable_operation_count = operations
    .filter(fn(operation) {
      match operation {
        Object(fields) =>
          capability_json_bool(fields, "executable").unwrap_or(false)
        _ => false
      }
    })
    .length()
  let executable_product_count = products
    .filter(fn(product) {
      match product {
        Object(fields) =>
          capability_json_string(fields, "capabilityStatus").unwrap_or("") ==
          "executable"
        _ => false
      }
    })
    .length()
  let inventory_only_count = products
    .filter(fn(product) {
      match product {
        Object(fields) =>
          capability_json_string(fields, "capabilityStatus").unwrap_or("") ==
          "inventory-only"
        _ => false
      }
    })
    .length()
  let projection = Json::object({
    "contract": Json::string("moonsuite.capability-projection.v1"),
    "policyOwner": Json::string("moongate"),
    "inventorySource": Json::string(path),
    "suiteRoot": Json::string(root),
    "inventoryDigest": if registry_digest.is_empty() {
      Json::null()
    } else {
      Json::string(registry_digest)
    },
    "semantics": Json::object({
      "inventoryIsCapability": Json::boolean(false),
      "manifestDeclarationIsExecutable": Json::boolean(false),
      "endpointReadyRequired": Json::boolean(true),
      "healthEvidence": Json::string(
        "passive signed-or-local service descriptor; MoonGate does not probe arbitrary inventory URLs",
      ),
    }),
    "summary": Json::object({
      "inventoryProductCount": Json::number(products.length().to_double()),
      "inventoryOnlyProductCount": Json::number(
        inventory_only_count.to_double(),
      ),
      "executableProductCount": Json::number(
        executable_product_count.to_double(),
      ),
      "declaredOperationCount": Json::number(operations.length().to_double()),
      "executableOperationCount": Json::number(
        executable_operation_count.to_double(),
      ),
      "findingCount": Json::number(global_findings.length().to_double()),
      "errorCount": Json::number(
        global_findings
        .filter(fn(finding) {
          match finding {
            Object(fields) =>
              capability_json_string(fields, "severity").unwrap_or("") ==
              "error"
            _ => false
          }
        })
        .length()
        .to_double(),
      ),
    }),
    "products": Json::array(products),
    "operations": Json::array(operations),
    "findings": Json::array(global_findings),
  })
  let digest = capability_document_digest(projection.stringify())
  match projection {
    Object(fields) => {
      fields["projectionDigest"] = Json::string(digest)
      Json::object(fields)
    }
    _ => projection
  }
}

///|
/// Resolve one exact operation from a previously generated projection.
///
/// MoonFlow and MoonDesk should call this contract before dispatch. The
/// resolver intentionally does not translate aliases or guess similar names.
pub fn moongate_capability_resolution_json(
  projection : Json,
  product_id : String,
  operation_id : String,
  requested_authority? : String = "",
  input_schema_id? : String = "",
  output_schema_id? : String = "",
) -> Json {
  let reasons : Array[Json] = []
  let mut matched_product : Json? = None
  let mut matched_operation : Json? = None
  match projection {
    Object(root) => {
      for product in capability_json_array(root, "products") {
        match product {
          Object(fields) =>
            if capability_json_string(fields, "productId").unwrap_or("") ==
              product_id {
              matched_product = Some(product)
            }
          _ => ()
        }
      }
      for operation in capability_json_array(root, "operations") {
        match operation {
          Object(fields) =>
            if capability_json_string(fields, "productId").unwrap_or("") ==
              product_id &&
              capability_json_string(fields, "id").unwrap_or("") == operation_id {
              matched_operation = Some(operation)
            }
          _ => ()
        }
      }
    }
    _ =>
      reasons.push(
        capability_finding(
          "capability-projection-invalid", "error", product_id, operation_id, "projection",
          "Capability resolution requires moonsuite.capability-projection.v1.",
        ),
      )
  }
  if matched_product is None {
    let identity = capability_identity(product_id)
    reasons.push(
      capability_finding(
        if identity.kind == "canonical" {
          "product-not-in-live-inventory"
        } else {
          "product-identity-not-callable"
        },
        "error",
        product_id,
        operation_id,
        "inventory.products",
        if identity.kind == "canonical" {
          "Product is not present in the live inventory."
        } else {
          identity.migration_note
        },
      ),
    )
  }
  if matched_product is Some(_) && matched_operation is None {
    reasons.push(
      capability_finding(
        "operation-not-published", "error", product_id, operation_id, "projection.operations",
        "The exact operation id is not published by this product. Similar names and repository identities are not callable substitutes.",
      ),
    )
  }
  match matched_operation {
    Some(Object(fields)) => {
      if !capability_json_bool(fields, "executable").unwrap_or(false) {
        reasons.push(
          capability_finding(
            "operation-not-executable",
            "error",
            product_id,
            operation_id,
            "projection.operations.\{operation_id}.executable",
            "The operation is declared but has unresolved conformance, service, schema, or endpoint evidence.",
          ),
        )
      }
      let required_authority = capability_json_string(fields, "authority").unwrap_or(
        "",
      )
      if !requested_authority.trim().is_empty() &&
        capability_authority_rank(requested_authority) <
        capability_authority_rank(required_authority) {
        reasons.push(
          capability_finding(
            "requested-authority-insufficient",
            "error",
            product_id,
            operation_id,
            "request.requestedAuthority",
            "Requested authority '\{requested_authority}' does not cover operation authority '\{required_authority}'.",
          ),
        )
      }
      match fields.get("inputSchema") {
        Some(Object(schema)) =>
          if !input_schema_id.trim().is_empty() &&
            capability_json_string(schema, "id").unwrap_or("") !=
            input_schema_id {
            reasons.push(
              capability_finding(
                "input-schema-mismatch", "error", product_id, operation_id, "request.inputSchemaId",
                "Requested input schema does not match the versioned operation contract.",
              ),
            )
          }
        _ => ()
      }
      match fields.get("outputSchema") {
        Some(Object(schema)) =>
          if !output_schema_id.trim().is_empty() &&
            capability_json_string(schema, "id").unwrap_or("") !=
            output_schema_id {
            reasons.push(
              capability_finding(
                "output-schema-mismatch", "error", product_id, operation_id, "request.outputSchemaId",
                "Requested output schema does not match the versioned operation contract.",
              ),
            )
          }
        _ => ()
      }
    }
    _ => ()
  }
  let executable = matched_operation is Some(_) &&
    !capability_has_error(reasons)
  Json::object({
    "contract": Json::string("moonsuite.capability-resolution.v1"),
    "productId": Json::string(product_id),
    "operationId": Json::string(operation_id),
    "found": Json::boolean(matched_operation is Some(_)),
    "executable": Json::boolean(executable),
    "endpoint": match matched_operation {
      Some(Object(fields)) => fields.get("endpoint").unwrap_or(Json::null())
      _ => Json::null()
    },
    "operation": matched_operation.unwrap_or(Json::null()),
    "reasons": Json::array(reasons),
  })
}
