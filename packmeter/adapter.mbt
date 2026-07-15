///|
pub(all) struct MeteredCapability {
  kind : String
  id : String
} derive(Debug, Eq, ToJson, FromJson)

///|
/// The attribution scope is derived solely from the generic host projection.
pub(all) struct PackMeteringScope {
  pack_id : String
  product_id : String
  capabilities : Array[MeteredCapability]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct UsageAttribution {
  pack_id : String
  product_id : String
  capability_kind : String
  capability_id : String
  quantity : Int
  unit : String
  amount_micros : Int
  currency : String
  evidence_ref : String
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn metering_scope(
  projection : @host.HostActivationProjection,
) -> PackMeteringScope raise {
  if projection.contract != "moonsuite.pack-host-activation.v1" {
    fail("unsupported pack host projection")
  }
  let capabilities : Array[MeteredCapability] = []
  for tool in projection.tools {
    capabilities.push({ kind: "tool", id: tool.id })
  }
  for schedule in projection.schedules {
    capabilities.push({ kind: "schedule", id: schedule.id })
  }
  for entrypoint in projection.app_entrypoints {
    capabilities.push({ kind: "app", id: entrypoint.id })
  }
  {
    pack_id: projection.pack_id,
    product_id: projection.product_id,
    capabilities,
  }
}

///|
pub fn attribute(
  scope : PackMeteringScope,
  capability_kind : String,
  capability_id : String,
  quantity : Int,
  unit : String,
  amount_micros : Int,
  currency : String,
  evidence_ref : String,
) -> UsageAttribution raise {
  if quantity < 0 || amount_micros < 0 {
    fail("usage quantities and amounts must be non-negative")
  }
  if unit.trim().is_empty() || currency.trim().is_empty() {
    fail("usage unit and currency are required")
  }
  if !scope.capabilities.any(fn(capability) {
      capability.kind == capability_kind && capability.id == capability_id
    }) {
    fail("capability is not present in the pack projection")
  }
  {
    pack_id: scope.pack_id,
    product_id: scope.product_id,
    capability_kind,
    capability_id,
    quantity,
    unit,
    amount_micros,
    currency,
    evidence_ref,
  }
}
