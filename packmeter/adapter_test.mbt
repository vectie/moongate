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
}
