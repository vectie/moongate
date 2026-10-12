///|
// Deliberately narrow scenario schema: never guess provider rates or billing tiers.
fn pricing_rate_card(content : String) -> Result[Json, String] {
  let parsed = @json.parse(content) catch {
    _ => return Err("Rate card must be valid JSON")
  }
  guard parsed is Object(card) else {
    return Err("Rate card must be an object")
  }
  for key, _ in card {
    if !["schema", "name", "currency", "rates"].contains(key) {
      return Err(
        "Unsupported rate-card field; only schema, name, currency and rates are supported",
      )
    }
  }
  guard card.get("schema") == Some("moongate.usage-rate-card.v1".to_json()) &&
    card.get("currency") == Some("USD".to_json()) &&
    card.get("name") is Some(String(name)) &&
    !name.trim().is_empty() &&
    card.get("rates") is Some(Array(rates)) else {
    return Err(
      "Rate card requires schema moongate.usage-rate-card.v1, currency USD, nonempty name and rates array",
    )
  }
  if rates.length() > 1000 {
    return Err("Rate cards are limited to 1,000 entries")
  }
  let seen : Map[String, Map[String, Bool]] = Map([])
  for index, value in rates {
    guard value is Object(rate) else {
      return Err("Rate \{index + 1}: expected an object")
    }
    for key, _ in rate {
      if !["providerId", "model", "inputUsdPerMillion", "outputUsdPerMillion"].contains(
          key,
        ) {
        return Err(
          "Rate \{index + 1}: unsupported field; only providerId, model, inputUsdPerMillion and outputUsdPerMillion are supported",
        )
      }
    }
    guard rate.get("providerId") is Some(String(provider)) &&
      !provider.trim().is_empty() &&
      rate.get("model") is Some(String(model)) &&
      !model.trim().is_empty() else {
      return Err(
        "Rate \{index + 1}: nonempty providerId and model are required",
      )
    }
    for field in ["inputUsdPerMillion", "outputUsdPerMillion"] {
      guard rate.get(field) is Some(Number(number, ..)) &&
        number >= 0.0 &&
        number <= 9007199254740991.0 else {
        return Err(
          "Rate \{index + 1}: rates must be finite nonnegative JSON numbers up to 9007199254740991",
        )
      }
    }
    let models = seen.get_or_init(provider, () => Map([]))
    if models.contains(model) {
      return Err("Rate \{index + 1}: duplicate provider/model pair")
    }
    models[model] = true
  }
  Ok(parsed)
}
