///|
/// Profile file-supplied request latency in milliseconds, without contacting a provider.
pub fn profile_usage_latency_json(
  content : String,
  source_name? : String = "Usage export",
  app? : String = "",
  provider? : String = "",
  model? : String = "",
  start_day? : String = "",
  end_day? : String = "",
) -> Result[Json, String] {
  for day in [start_day, end_day] {
    if !day.is_empty() && usage_file_day(day.to_json()) != day {
      return Err("Date filters must be valid YYYY-MM-DD dates")
    }
  }
  if !start_day.is_empty() && !end_day.is_empty() && start_day > end_day {
    return Err("Start date must not be after end date")
  }
  let preview = match moongate_preview_usage_file_json(content, source_name~) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let raw = match merge_records(content, source_name) {
    Ok(rows) => rows
    Err(error) => return Err(error)
  }
  guard compare_field(preview, "data") is Array(normalized) else {
    return Err("No request rows")
  }
  let rows : Array[Json] = []
  for index, row in normalized {
    guard raw[index] is Object(original) && row is Object(fields) else {
      return Err("Expected request object")
    }
    let value = usage_file_field(original, ["latencyMs", "latency_ms"])
    // Reject ambiguous aliases even when one would otherwise take precedence.
    if original.contains("latencyMs") && original.contains("latency_ms") {
      return Err("Row \{index + 1}: use only one latencyMs or latency_ms field")
    }
    let missing = value == Json::null() || value is String("")
    let latency = if missing { None } else { usage_file_number(value) }
    if !missing && latency is None {
      return Err(
        "Row \{index + 1}: latencyMs must be a finite nonnegative millisecond number up to 9007199254740991",
      )
    }
    let day = usage_file_text(row, "date")
    if (app.is_empty() || usage_file_text(row, "appType") == app) &&
      (provider.is_empty() || usage_file_text(row, "providerId") == provider) &&
      (model.is_empty() || usage_file_text(row, "model") == model) &&
      (start_day.is_empty() || (!day.is_empty() && day >= start_day)) &&
      (end_day.is_empty() || (!day.is_empty() && day <= end_day)) {
      fields["latencyMs"] = match latency {
        Some(n) => n.to_json()
        None => Json::null()
      }
      fields["sourceRow"] = (index + 1).to_json()
      rows.push(Json::object(fields))
    }
  }
  let measured = rows.filter(row => {
    compare_field(row, "latencyMs") != Json::null()
  })
  measured.sort_by((a, b) => {
    let x = compare_number(a, "latencyMs")
    let y = compare_number(b, "latencyMs")
    if x > y {
      -1
    } else if x < y {
      1
    } else {
      compare_number(a, "sourceRow").compare(compare_number(b, "sourceRow"))
    }
  })
  let slowest = measured.iter().take(20).collect()
  let summary = latency_summary(rows)
  let by_model = latency_groups(rows, "model")
  let by_provider = latency_groups(rows, "providerId")
  let source : Json = {
    "sourceName": source_name.to_json(),
    "importedRows": normalized.length().to_json(),
    "sourceTotal": compare_field(preview, "sourceTotal"),
    "partial": compare_field(preview, "partial"),
    "sourceCoverageUnknown": compare_field(preview, "sourceCoverageUnknown") ==
    true.to_json(),
    "usageMergeScope": compare_field(preview, "usageMergeScope"),
  }
  let caveats = [
    "Latencies are file-supplied milliseconds, not a live benchmark. Their measurement boundary is unverified; do not mix incompatible exporters.",
    "Percentiles use nearest rank: sorted sample at ceil(p * sampleCount), 1-based. Missing samples are excluded, explicit zero is included; empty percentiles are null.",
    "Counts and percentiles describe selected imported rows only. Missing or partial exports may bias the distribution; observed date bounds do not establish complete interval coverage.",
    "Slowest includes at most 20 measured rows, descending latency with original data-row order breaking ties. Duplicate request IDs are separate observed rows, not deduplicated requests.",
    "Only normalized usage fields and latencyMs are retained; payloads and unsupported fields are omitted. IDs, labels and source paths remain. No provider contacted or accounting changed.",
  ]
  let lines = [
    "MoonGate offline request latency profile (milliseconds)",
    "SOURCE: " + source.stringify(),
    "Filters: " +
    (
      {
        "app": app.to_json(),
        "provider": provider.to_json(),
        "model": model.to_json(),
        "startDay": start_day.to_json(),
        "endDay": end_day.to_json(),
      } : Json).stringify(),
    "TOTAL: " + summary.stringify(),
  ]
  for (label, groups) in [("By model", by_model), ("By provider", by_provider)] {
    lines.push(label + ":")
    for group in groups {
      lines.push(group.stringify())
    }
  }
  lines.push("Slowest measured rows (up to 20):")
  for row in slowest {
    lines.push(row.stringify())
  }
  for caveat in caveats {
    lines.push("- " + caveat)
  }
  let result : Json = {
    "schema": "moongate.usage-latency.v1",
    "unit": "milliseconds",
    "percentileMethod": "nearest-rank",
    "source": source,
    "filters": {
      "app": app.to_json(),
      "provider": provider.to_json(),
      "model": model.to_json(),
      "startDay": start_day.to_json(),
      "endDay": end_day.to_json(),
    },
    "selectedRows": rows.length().to_json(),
    "summary": summary,
    "byModel": by_model.to_json(),
    "byProvider": by_provider.to_json(),
    "slowest": slowest.to_json(),
    "caveats": caveats.to_json(),
    "report": (lines.join("\n") + "\n").to_json(),
  }
  if @encoding/utf8.encode(result.stringify(indent=2)).length() >
    4 * 1024 * 1024 - 1 {
    return Err(
      "Latency profile output exceeds 4 MiB; select smaller input slices",
    )
  }
  Ok(result)
}

///|
fn latency_summary(rows : Array[Json]) -> Json {
  let samples : Array[Double] = []
  for row in rows {
    if compare_field(row, "latencyMs") is Number(n, ..) {
      samples.push(n)
    }
  }
  samples.sort()
  let percentile = (percent : Int) => {
    if samples.is_empty() {
      Json::null()
    } else {
      samples[(samples.length() * percent + 99) / 100 - 1].to_json()
    }
  }
  {
    "rows": rows.length().to_json(),
    "sampleCount": samples.length().to_json(),
    "missingLatencyCount": (rows.length() - samples.length()).to_json(),
    "p50Ms": percentile(50),
    "p95Ms": percentile(95),
    "p99Ms": percentile(99),
    "maxMs": percentile(100),
  }
}

///|
fn latency_groups(rows : Array[Json], field : String) -> Array[Json] {
  let buckets : Map[String, Array[Json]] = Map([])
  for row in rows {
    let key = usage_file_text(row, field)
    match buckets.get(key) {
      Some(bucket) => bucket.push(row)
      None => buckets[key] = [row]
    }
  }
  let keys = buckets.keys().collect()
  keys.sort()
  keys.map(key => {
    guard latency_summary(buckets[key]) is Object(summary) else {
      abort("summary")
    }
    summary["key"] = key.to_json()
    Json::object(summary)
  })
}
