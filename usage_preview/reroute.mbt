///|
/// Rehearse an explicit hypothetical route plan against saved directional usage.
/// Token counts are held fixed, not predicted for the target model. No dispatch,
/// provider validation, routing-policy activation, or accounting write occurs.
pub fn reroute_usage_file_json(
  content : String,
  route_plan : String,
  source_name~ : String = "Local usage",
) -> Result[Json, String] {
  if @encoding/utf8.encode(content).length() > 4 * 1024 * 1024 ||
    @encoding/utf8.encode(route_plan).length() >
    4 * 1024 * 1024 - @encoding/utf8.encode(content).length() {
    return Err("Usage and route plan exceed the combined 4 MiB limit")
  }
  let plan = match usage_route_plan(route_plan) {
    Ok(Object(plan)) => plan
    Err(error) => return Err(error)
    _ => return Err("Invalid route plan")
  }
  let original = match moongate_preview_usage_file_json(content, source_name~) {
    Ok(Object(preview)) => preview
    Err(error) => return Err(error)
    _ => return Err("Invalid usage")
  }
  if original.contains("usageEvidenceKind") {
    return Err(
      "Use original recorded usage, not a prior hypothetical route scenario",
    )
  }
  let raw = match merge_records(content, source_name) {
    Ok(rows) => rows
    Err(error) => return Err(error)
  }
  guard original["data"] is Array(rows) && plan["routes"] is Array(routes) else {
    return Err("Invalid normalized data")
  }
  let mapping : Map[String, Map[String, (Int32, Json)]] = Map([])
  for index, route in routes {
    mapping.get_or_init(usage_file_text(route, "sourceProviderId"), () => {
      Map([])
    })[usage_file_text(route, "sourceModel")] = (index, route)
  }
  let used : Map[Int32, Bool] = Map([])
  let observations : Array[Json] = []
  let scenario_rows : Array[Json] = []
  let mut mapped = 0
  let mut priced = 0
  let mut missing_tokens = 0
  let mut unmapped = 0
  let mut known = 0.0
  let mut recorded = 0.0
  let mut original_missing = 0
  let mut paired_before = 0.0
  let mut paired_after = 0.0
  let mut paired = 0
  let mut token_total = 0.0
  for index, row in rows {
    guard row is Object(fields) && raw[index] is Object(raw_fields) else {
      return Err("Invalid normalized row")
    }
    let source_provider = fields["providerId"]
    let source_model = fields["model"]
    let before = fields["totalCostUsd"]
    guard usage_file_number(fields["totalTokens"]) is Some(tokens) &&
      tokens <= 9007199254740991.0 - token_total else {
      return Err("Aggregate tokens exceed the safe-number limit")
    }
    token_total += tokens
    if before is Number(value, ..) {
      if value > 9007199254740991.0 - recorded {
        return Err("Original estimated USD exceeds the safe-number limit")
      }
      recorded += value
    } else {
      original_missing += 1
    }
    // Do not route synthesized Unknown labels. Explicit labels match literally.
    let explicit_provider = usage_file_field(raw_fields, [
      "providerId", "provider_id", "provider",
    ])
    let explicit_model = usage_file_field(raw_fields, [
      "model", "modelName", "model_name",
    ])
    let route = if explicit_provider is String(provider) &&
      !provider.trim().is_empty() &&
      explicit_model is String(model) &&
      !model.trim().is_empty() {
      match mapping.get(provider) {
        Some(models) => models.get(model)
        None => None
      }
    } else {
      None
    }
    let mut estimate = Json::null()
    let mut mapping_index = Json::null()
    let status = match route {
      None => {
        unmapped += 1
        "unmapped"
      }
      Some((route_index, Object(route))) => {
        used[route_index] = true
        mapping_index = Json(route_index + 1)
        mapped += 1
        fields["providerId"] = route["targetProviderId"]
        fields["model"] = route["targetModel"]
        match
          (
            usage_file_number(fields["inputTokens"]),
            usage_file_number(fields["outputTokens"]),
          ) {
          (Some(input), Some(output)) => {
            guard route["inputUsdPerMillion"] is Number(input_rate, ..) &&
              route["outputUsdPerMillion"] is Number(output_rate, ..) else {
              return Err("Invalid mapped rates")
            }
            let cost = input / 1000000.0 * input_rate +
              output / 1000000.0 * output_rate
            if !(cost >= 0.0 && cost <= 9007199254740991.0 - known) {
              return Err("Scenario estimated USD exceeds the safe-number limit")
            }
            estimate = Json(cost)
            known += cost
            priced += 1
            if before is Number(value, ..) {
              paired += 1
              paired_before += value
              paired_after += cost
            }
            "priced"
          }
          _ => {
            missing_tokens += 1
            "missing_tokens"
          }
        }
      }
      _ => return Err("Invalid mapping")
    }
    fields["totalCostUsd"] = estimate
    observations.push({
      "sourceRow": Json(index + 1),
      "requestId": fields["requestId"],
      "sourceProviderId": source_provider,
      "sourceModel": source_model,
      "targetProviderId": if route is Some(_) {
        fields["providerId"]
      } else {
        Json::null()
      },
      "targetModel": if route is Some(_) {
        fields["model"]
      } else {
        Json::null()
      },
      "mappingIndex": mapping_index,
      "status": Json(status),
      "originalEstimatedUsd": before,
      "scenarioEstimatedUsd": estimate,
    })
    scenario_rows.push(Json::object(fields))
  }
  let envelope : Map[String, Json] = {
    "data": Json(scenario_rows),
    "sourceTotal": original["sourceTotal"],
    "usageEvidenceKind": "hypothetical-route-scenario",
    "usageScenarioName": plan["name"],
  }
  if original.get("sourceCoverageUnknown") is Some(value) {
    envelope["sourceCoverageUnknown"] = value
  }
  let result = match
    moongate_preview_usage_file_json(
      Json::object(envelope).stringify(),
      source_name="Hypothetical route scenario",
    ) {
    Ok(Object(result)) => result
    Err(error) => return Err(error)
    _ => return Err("Cannot create scenario preview")
  }
  let unused : Array[Int32] = []
  for index in 0..<routes.length() {
    if !used.contains(index) {
      unused.push(index + 1)
    }
  }
  let caveats = [
    "Hypothetical route cost rehearsal with fixed recorded token counts. Target tokenizer, output length, quality, context capacity, latency and runtime behavior are not predicted or qualified.",
    "User-supplied flat USD rates only. No live provider, readiness, authority, policy selection, activation, budget enforcement, payment or billing settlement.",
    "Only exact source pairs are mapped. Unmapped rows retain source labels with unknown scenario cost; old estimates never substitute for missing scenario evidence.",
    "Both directional counts are required, including explicit zero. Cache/reasoning tiers, media, discounts, taxes and request fees are not modeled.",
    "Paired change includes only rows with both original and scenario estimates. It is not total savings or a causal prediction. Missing telemetry and partial source coverage remain unresolved.",
    "Each row is one observation even if IDs repeat. Scenario request IDs link to source rows, not new requests. Inputs and persistent usage are unchanged.",
    "Keep this artifact and original input. Preview and CSV retain the hypothetical label, but omit detailed mappings and observations. IDs, source paths and labels remain visible; review before sharing.",
  ]
  result["usageRouteScenario"] = {
    "schema": "moongate.usage-route-scenario.v1",
    "sourceName": Json(source_name),
    "plan": Json::object(plan),
    "mappedCount": Json(mapped),
    "pricedCount": Json(priced),
    "unmappedCount": Json(unmapped),
    "missingTokenCount": Json(missing_tokens),
    "unusedMappingIndices": Json(unused),
    "originalKnownEstimatedUsd": Json(recorded),
    "originalMissingCostCount": Json(original_missing),
    "pairedCount": Json(paired),
    "pairedOriginalEstimatedUsd": if paired == 0 {
      Json::null()
    } else {
      Json(paired_before)
    },
    "pairedScenarioEstimatedUsd": if paired == 0 {
      Json::null()
    } else {
      Json(paired_after)
    },
    "pairedDeltaUsd": if paired == 0 {
      Json::null()
    } else {
      Json(paired_after - paired_before)
    },
    "observations": Json(observations),
    "caveats": Json(caveats),
  }
  result["report"] = Json(
    [
      "MoonGate hypothetical route rehearsal (USD)",
      "Plan: " + plan["name"].stringify(),
      "\{mapped} mapped; \{priced} priced; \{missing_tokens} missing directional counts; \{unmapped} unmapped; \{unused.length()} unused mappings.",
      "Known scenario estimate: USD \{known}. Unknown estimates are excluded.",
      if paired == 0 {
        "Paired comparison unavailable: no rows have both estimates."
      } else {
        "Paired rows: \{paired}; original USD \{paired_before}; scenario USD \{paired_after}; difference USD \{paired_after - paired_before}."
      },
      usage_file_text(Json::object(result), "report"),
      caveats.join("\n"),
    ].join("\n") +
    "\n",
  )
  if @encoding/utf8.encode(Json::object(result).stringify(indent=2)).length() >
    4 * 1024 * 1024 - 1 {
    return Err("Route scenario exceeds 4 MiB; use a smaller input")
  }
  Ok(Json::object(result))
}
