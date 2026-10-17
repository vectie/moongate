///|
// Explicit mappings only. A destination's flat rates must agree across mappings.
fn usage_route_plan(content : String) -> Result[Json, String] {
  let parsed = @json.parse(content) catch {
    _ => return Err("Route plan must be valid JSON")
  }
  guard parsed is Object(plan) &&
    plan.get("schema") == Some("moongate.usage-route-plan.v1".to_json()) &&
    plan.get("currency") == Some("USD".to_json()) &&
    plan.get("name") is Some(String(name)) &&
    !name.trim().is_empty() &&
    plan.get("routes") is Some(Array(routes)) else {
    return Err(
      "Route plan requires schema moongate.usage-route-plan.v1, currency USD, a nonempty name and routes array",
    )
  }
  for key, _ in plan {
    if !["schema", "currency", "name", "routes"].contains(key) {
      return Err("Unsupported route-plan field")
    }
  }
  if routes.length() > 1000 {
    return Err("Route plans are limited to 1,000 mappings")
  }
  let seen : Map[String, Map[String, Bool]] = Map([])
  let targets : Map[String, Map[String, Json]] = Map([])
  for index, route in routes {
    guard route is Object(fields) else {
      return Err("Mapping \{index + 1}: expected object")
    }
    for key, _ in fields {
      if ![
          "sourceProviderId", "sourceModel", "targetProviderId", "targetModel", "inputUsdPerMillion",
          "outputUsdPerMillion",
        ].contains(key) {
        return Err("Mapping \{index + 1}: unsupported field")
      }
    }
    for
      key in [
        "sourceProviderId", "sourceModel", "targetProviderId", "targetModel",
      ] {
      guard fields.get(key) is Some(String(label)) && !label.trim().is_empty() else {
        return Err("Mapping \{index + 1}: nonempty string \{key} required")
      }
    }
    for key in ["inputUsdPerMillion", "outputUsdPerMillion"] {
      guard fields.get(key) is Some(Number(rate, ..)) &&
        rate >= 0.0 &&
        rate <= 9007199254740991.0 else {
        return Err(
          "Mapping \{index + 1}: rates must be finite nonnegative JSON numbers up to 9007199254740991",
        )
      }
    }
    let source = usage_file_text(route, "sourceProviderId")
    if source == "Unknown" {
      return Err(
        "Mapping \{index + 1}: source provider Unknown is reserved for missing-label exports; use an explicit original provider label",
      )
    }
    let model = usage_file_text(route, "sourceModel")
    let models = seen.get_or_init(source, () => Map([]))
    if models.contains(model) {
      return Err("Mapping \{index + 1}: duplicate source provider/model pair")
    }
    models[model] = true
    let target_models = targets.get_or_init(
      usage_file_text(route, "targetProviderId"),
      () => Map([]),
    )
    let target_model = usage_file_text(route, "targetModel")
    let rates = Json::array([
      fields["inputUsdPerMillion"],
      fields["outputUsdPerMillion"],
    ])
    if target_models.get(target_model) is Some(previous) && previous != rates {
      return Err(
        "Mapping \{index + 1}: conflicting rates for the same target provider/model",
      )
    }
    target_models[target_model] = rates
  }
  Ok(parsed)
}
