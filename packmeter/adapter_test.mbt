///|
test "usage attribution stays product neutral" {
  let projection : @host.HostActivationProjection = {
    contract: "moonsuite.pack-host-activation.v1",
    pack_id: "fixture",
    product_id: "fixture",
    version: "1.0.0",
    required_runtime_extensions: [],
    book_templates: [],
    tools: [],
    schedules: [],
    app_entrypoints: [
      { id: "fixture.console", path: "apps/console", audience: "operator" },
    ],
    provider_ports: [],
    policies: [],
  }
  let scope = metering_scope(projection)
  let usage = attribute(
    scope, "app", "fixture.console", 1, "request", 250000, "CNY", "evidence/usage.json",
  )
  assert_eq(usage.pack_id, "fixture")
  assert_eq(usage.amount_micros, 250000)
  let charged = charge(budget("fixture", 300000), usage)
  assert_eq(charged.spent_micros, 250000)
  assert_eq(remaining(charged), 50000)
}

///|
test "hard budget stops excess attributed cost" {
  let value : PackBudget = {
    pack_id: "fixture",
    limit_micros: 100,
    spent_micros: 90,
  }
  let usage : UsageAttribution = {
    pack_id: "fixture",
    product_id: "fixture",
    capability_kind: "tool",
    capability_id: "fixture.generate",
    quantity: 1,
    unit: "request",
    amount_micros: 11,
    currency: "CNY",
    evidence_ref: "evidence/run.json",
  }
  let mut stopped = false
  try {
    charge(value, usage) |> ignore
  } catch {
    _ => stopped = true
  }
  assert_true(stopped)
}
