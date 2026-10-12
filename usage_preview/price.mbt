///|
/// Apply an explicit hypothetical USD flat-token rate card to a local usage file.
/// Both directional token counts are required; missing inputs and rates stay
/// unknown. Original normalized estimates remain in usagePricing.observations.
/// Returns a reopenable explorer export, without network or accounting writes.
pub fn price_usage_file_json(
  content : String,
  rate_card : String,
  source_name? : String = "Local usage",
) -> Result[Json, String] {
  if @encoding/utf8.encode(content).length() > 4 * 1024 * 1024 ||
    @encoding/utf8.encode(rate_card).length() >
    4 * 1024 * 1024 - @encoding/utf8.encode(content).length() {
    return Err("Usage file and rate card exceed the combined 4 MiB UTF-8 limit")
  }
  let card = match pricing_rate_card(rate_card) {
    Ok(Object(card)) => card
    Ok(_) => return Err("Invalid rate card")
    Err(error) => return Err(error)
  }
  let preview = match moongate_preview_usage_file_json(content, source_name~) {
    Ok(Object(preview)) => preview
    Ok(_) => return Err("Invalid usage preview")
    Err(error) => return Err(error)
  }
  let raw = match merge_records(content, source_name) {
    Ok(rows) => rows
    Err(error) => return Err(error)
  }
  guard preview["data"] is Array(rows) && card["rates"] is Array(rates) else {
    return Err("Invalid normalized usage or rates")
  }
  let prices : Map[String, Map[String, Json]] = Map([])
  for rate in rates {
    let provider = usage_file_text(rate, "providerId")
    let models = prices.get_or_init(provider, () => Map([]))
    models[usage_file_text(rate, "model")] = rate
  }
  let observations : Array[Json] = []
  let mut priced = 0
  let mut missing_rate = 0
  let mut missing_tokens = 0
  let mut missing_provider = 0
  let mut known = 0.0
  let mut recorded = 0.0
  let mut paired_recorded = 0.0
  let mut paired_scenario = 0.0
  let mut paired_count = 0
  let mut missing_recorded = 0
  let mut tokens = 0.0
  for index, row in rows {
    guard row is Object(obj) && raw[index] is Object(raw_row) else {
      return Err("Invalid normalized request row")
    }
    let previous = obj["totalCostUsd"]
    guard usage_file_number(obj["totalTokens"]) is Some(total) else {
      return Err(
        "Usage token total exceeds the safe-number limit; no scenario produced",
      )
    }
    if total > 9007199254740991.0 - tokens {
      return Err(
        "Usage token total exceeds the safe-number limit; no scenario produced",
      )
    }
    tokens += total
    if previous is Number(cost, ..) {
      if cost > 9007199254740991.0 - recorded {
        return Err(
          "Original estimated USD total exceeds the safe-number limit; no scenario produced",
        )
      }
      recorded += cost
    } else {
      missing_recorded += 1
    }
    let provider = usage_file_text(row, "providerId")
    let model = usage_file_text(row, "model")
    let rate = match prices.get(provider) {
      Some(models) => models.get(model)
      None => None
    }
    let input = usage_file_number(obj["inputTokens"])
    let output = usage_file_number(obj["outputTokens"])
    let explicit_provider = usage_file_field(raw_row, [
      "providerId", "provider_id", "provider",
    ])
    let status = if !(explicit_provider is String(label) &&
      !label.trim().is_empty()) {
      missing_provider += 1
      "missing_provider"
    } else if rate is None {
      missing_rate += 1
      "missing_rate"
    } else if input is None || output is None {
      missing_tokens += 1
      "missing_tokens"
    } else {
      "priced"
    }
    let mut estimate = Json::null()
    if status == "priced" {
      guard rate is Some(Object(rate)) &&
        input is Some(input) &&
        output is Some(output) &&
        rate["inputUsdPerMillion"] is Number(input_rate, ..) &&
        rate["outputUsdPerMillion"] is Number(output_rate, ..) else {
        return Err("Invalid matched rate")
      }
      let cost = input / 1000000.0 * input_rate +
        output / 1000000.0 * output_rate
      if !(cost >= 0.0 && cost <= 9007199254740991.0 - known) {
        return Err(
          "Scenario estimated USD exceeds the safe-number limit; no scenario produced",
        )
      }
      estimate = cost.to_json()
      known += cost
      priced += 1
      if previous is Number(prior, ..) {
        paired_recorded += prior
        paired_scenario += cost
        paired_count += 1
      }
    }
    observations.push({
      "sourceRow": (index + 1).to_json(),
      "requestId": obj["requestId"],
      "originalEstimatedUsd": previous,
      "scenarioEstimatedUsd": estimate,
      "status": status.to_json(),
    })
    obj["totalCostUsd"] = estimate
  }
  let envelope : Map[String, Json] = {
    "data": rows.to_json(),
    "sourceTotal": preview["sourceTotal"],
  }
  for key in ["sourceCoverageUnknown", "usageMergeScope"] {
    if preview.get(key) is Some(value) {
      envelope[key] = value
    }
  }
  let result = match
    moongate_preview_usage_file_json(
      Json::object(envelope).stringify(),
      source_name="Priced usage scenario",
    ) {
    Ok(Object(result)) => result
    Ok(_) => return Err("Cannot construct priced usage export")
    Err(error) => return Err(error)
  }
  result["sourceName"] = source_name.to_json()
  let caveats = [
    "Hypothetical user-supplied USD rates, not provider prices, settled charges or a spending limit.",
    "Formula: inputTokens / 1000000 * inputUsdPerMillion + outputTokens / 1000000 * outputUsdPerMillion. No rounding to cents.",
    "Flat directional token counts only: cached/reasoning tiers, requests, media, discounts, taxes and other billing rules are not modeled. Provider/model labels match exactly and case-sensitively; no aliases or wildcard fallback.",
    "Both directional token counts and an explicit provider are required, including explicit zero. Missing fields are never inferred from totalTokens. Unknown scenario estimates do not retain old costs as a fallback.",
    "Original normalized estimates are retained by sourceRow in usagePricing.observations. Reopening in the explorer retains scenario costs and source coverage, but drops pricing metadata; keep this original scenario artifact and the original input.",
    "Inputs and persistent accounting remain unchanged. Payloads and extra fields are omitted; request IDs, source name, provider/model labels and rate-card name remain. Review before sharing.",
  ]
  result["usagePricing"] = {
    "schema": "moongate.usage-pricing.v1",
    "rateCard": Json::object(card),
    "costSource": "user-supplied-hypothetical-rate-card",
    "pricedCount": priced.to_json(),
    "missingRateCount": missing_rate.to_json(),
    "missingTokenCount": missing_tokens.to_json(),
    "missingProviderCount": missing_provider.to_json(),
    "originalKnownEstimatedUsd": recorded.to_json(),
    "originalMissingCostCount": missing_recorded.to_json(),
    "pairedCount": paired_count.to_json(),
    "pairedOriginalEstimatedUsd": if paired_count == 0 {
      Json::null()
    } else {
      paired_recorded.to_json()
    },
    "pairedScenarioEstimatedUsd": if paired_count == 0 {
      Json::null()
    } else {
      paired_scenario.to_json()
    },
    "pairedDeltaUsd": if paired_count == 0 {
      Json::null()
    } else {
      (paired_scenario - paired_recorded).to_json()
    },
    "observations": observations.to_json(),
    "caveats": caveats.to_json(),
  }
  result["report"] = ([
    "MoonGate hypothetical usage pricing (USD)",
    "Source: " + source_name.to_json().stringify(),
    "Rate card: " + card["name"].stringify(),
    "\{priced} priced requests; \{missing_rate} missing rates; \{missing_tokens} missing directional counts; \{missing_provider} missing provider labels",
    "Scenario known estimated USD: \{known}; unknown estimates are excluded, never zero.",
    "Original known estimated USD: \{recorded}; \{missing_recorded} original costs unknown.",
    if paired_count == 0 {
      "Paired comparison: unavailable; no rows have both original and scenario estimates."
    } else {
      "Paired comparison: \{paired_count} rows; original USD \{paired_recorded}; scenario USD \{paired_scenario}; difference USD \{paired_scenario - paired_recorded}."
    },
    usage_file_text(Json::object(result), "report"),
    caveats.join("\n"),
  ].join("\n") +
  "\n").to_json()
  if @encoding/utf8.encode(Json::object(result).stringify(indent=2)).length() >
    4 * 1024 * 1024 - 1 {
    return Err(
      "Priced export exceeds the 4 MiB reopen limit; select a smaller input; no scenario produced",
    )
  }
  Ok(Json::object(result))
}
