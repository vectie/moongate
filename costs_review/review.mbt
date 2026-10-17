///|
/// Compare saved OpenAI organization Costs buckets with local usage estimates.
/// `scope` is the caller's explicit explanation of why the two captures cover
/// corresponding activity; it is retained as an assertion, never verified here.
/// Only full UTC days and USD provider amounts are supported. No provider is
/// contacted and no usage or accounting record is written.
pub fn review_openai_costs_json(
  usage : String,
  costs : String,
  provider~ : String,
  scope~ : String,
  app? : String = "",
  project? : String = "",
  line_item? : String = "",
) -> Result[Json, String] {
  if provider.trim().is_empty() ||
    provider == "Unknown" ||
    scope.trim().is_empty() {
    return Err(
      "Explicit provider and corresponding-scope explanation are required",
    )
  }
  if provider.length() > 512 ||
    scope.length() > 2048 ||
    app.length() > 512 ||
    project.length() > 512 ||
    line_item.length() > 512 {
    return Err("Review labels exceed supported lengths")
  }
  if @utf8.encode(usage).length() + @utf8.encode(costs).length() >
    4 * 1024 * 1024 {
    return Err("Combined usage and Costs input exceeds 4 MiB")
  }
  let (reported, has_more, source_results) = match
    cost_page(costs, project, line_item) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let (prepared_usage, explicit_partial) = match prepare_usage_input(usage) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let preview = match
    @usage_preview.moongate_preview_usage_file_json(
      prepared_usage,
      provider~,
      app~,
    ) {
    Ok(value) => value
    Err(error) => return Err("Local usage: " + error)
  }
  if field(preview, "usageEvidenceKind") != Json::null() {
    return Err(
      "Hypothetical route scenarios cannot be compared as recorded usage",
    )
  }
  // Pricing metadata identifies other hypothetical inputs when still present.
  let raw = @exact_json.parse_with_number_text(usage[:]) catch {
    _ => Json::null()
  }
  if field(raw, "usagePricing") != Json::null() {
    return Err(
      "Hypothetical pricing scenarios cannot be compared as recorded usage",
    )
  }
  guard field(preview, "data") is Array(rows) else {
    return Err("Expected normalized usage rows")
  }
  let partial = explicit_partial || field(preview, "partial") == true.to_json()
  let locals : Map[String, Array[Json]] = Map([])
  let dates : Map[String, Bool] = Map([])
  let mut undated = 0
  for row in rows {
    let day = text(row, "date")
    if day.is_empty() {
      undated += 1
    } else {
      dates[day] = true
      match locals.get(day) {
        Some(values) => values.push(row)
        None => locals[day] = [row]
      }
    }
  }
  let provider_days : Map[String, ReportedDay] = Map([])
  for day in reported {
    provider_days[day.day] = day
    dates[day.day] = true
  }
  let keys = dates.keys().collect()
  keys.sort()
  let days : Array[Json] = []
  let mut paired = 0
  let mut paired_local = 0.0
  let mut paired_reported = 0.0
  for day in keys {
    let observations = locals.get(day).unwrap_or([])
    let cost = provider_days.get(day)
    let mut local_total = 0.0
    let mut local_known = 0
    for row in observations {
      if field(row, "totalCostUsd") is Number(amount, ..) {
        local_total += amount
        if !valid_amount(local_total) {
          return Err("Local estimated USD total exceeds supported range")
        }
        local_known += 1
      }
    }
    let reported_count = cost.map(value => value.results).unwrap_or(0)
    let reported_known = cost.map(value => value.known).unwrap_or(0)
    let reported_missing = cost.map(value => value.missing).unwrap_or(0)
    let reported_total = cost.map(value => value.total).unwrap_or(0.0)
    let blockers : Array[String] = []
    if partial {
      blockers.push("partial-local-source")
    }
    if has_more {
      blockers.push("provider-page-has-more")
    }
    if undated > 0 {
      blockers.push("undated-selected-usage")
    }
    if observations.is_empty() {
      blockers.push("no-local-observations")
    }
    if local_known < observations.length() {
      blockers.push("unknown-local-estimates")
    }
    if cost is None {
      blockers.push("no-provider-bucket")
    } else if reported_count == 0 {
      blockers.push("no-selected-provider-results")
    }
    if reported_missing > 0 {
      blockers.push("unknown-provider-amounts")
    }
    let difference = if blockers.is_empty() {
      if !valid_amount(reported_total - local_total) {
        return Err("Daily USD difference exceeds supported range")
      }
      paired += 1
      paired_local += local_total
      paired_reported += reported_total
      if !valid_amount(paired_local) ||
        !valid_amount(paired_reported) ||
        !valid_amount(paired_reported - paired_local) {
        return Err("Paired USD total or difference exceeds supported range")
      }
      (reported_total - local_total).to_json()
    } else {
      Json::null()
    }
    days.push({
      "day": day.to_json(),
      "localRequests": observations.length().to_json(),
      "localKnownEstimateCount": local_known.to_json(),
      "localMissingEstimateCount": (observations.length() - local_known).to_json(),
      "localKnownEstimatedUsd": if local_known > 0 {
        local_total.to_json()
      } else {
        Json::null()
      },
      "providerBucketPresent": (cost is Some(_)).to_json(),
      "providerResultCount": reported_count.to_json(),
      "providerKnownAmountCount": reported_known.to_json(),
      "providerMissingAmountCount": reported_missing.to_json(),
      "providerKnownReportedUsd": if reported_known > 0 {
        reported_total.to_json()
      } else {
        Json::null()
      },
      "reportedMinusEstimatedUsd": difference,
      "differenceBlockers": blockers.to_json(),
    })
  }
  let result : Map[String, Json] = {
    "schema": "moongate.provider-cost-review.v1",
    "evidenceKind": "saved-provider-costs-versus-local-estimates",
    "currency": "USD",
    "scopeAssertion": scope.to_json(),
    "scopeVerified": false,
    "provider": provider.to_json(),
    "app": app.to_json(),
    "project": project.to_json(),
    "lineItem": line_item.to_json(),
    "localImportedRows": field(preview, "importedRows"),
    "localSelectedRows": rows.length().to_json(),
    "localSourcePartial": partial.to_json(),
    "localUndatedRows": undated.to_json(),
    "providerHasMore": has_more.to_json(),
    "providerSourceResults": source_results.to_json(),
    "providerSelectedResults": reported
    .fold(init=0, (n, day) => n + day.results)
    .to_json(),
    "days": days.to_json(),
    "pairedDays": paired.to_json(),
    "pairedLocalEstimatedUsd": if paired > 0 {
      paired_local.to_json()
    } else {
      Json::null()
    },
    "pairedProviderReportedUsd": if paired > 0 {
      paired_reported.to_json()
    } else {
      Json::null()
    },
    "pairedReportedMinusEstimatedUsd": if paired > 0 {
      (paired_reported - paired_local).to_json()
    } else {
      Json::null()
    },
  }
  result["report"] = render_report(Json::object(result)).to_json()
  let output = Json::object(result)
  if @utf8.encode(output.stringify(indent=2)).length() > 4 * 1024 * 1024 - 1 {
    return Err("Cost review output exceeds 4 MiB")
  }
  Ok(output)
}
