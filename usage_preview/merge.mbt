///|
/// Combine overlapping local exports from one caller-named request ID namespace.
/// Identical normalized rows count once; conflicting IDs reject the whole merge.
pub fn merge_usage_files_json(
  files : Array[(String, String)],
  scope~ : String,
) -> Result[Json, String] {
  if scope.trim().is_empty() {
    return Err("A nonempty request identity scope is required")
  }
  if files.length() < 2 || files.length() > 20 {
    return Err("Merge requires 2 to 20 usage files")
  }
  let mut bytes = 0
  for (_, content) in files {
    bytes += @encoding/utf8.encode(content).length()
    if bytes > 4 * 1024 * 1024 {
      return Err("Usage merge exceeds the combined 4 MiB limit")
    }
  }
  let rows : Array[Json] = []
  let sources : Array[Json] = []
  let occurrences : Array[Json] = []
  let seen : Map[String, (Json, Int, Int)] = Map([])
  let mut imported = 0
  let mut unknown_coverage = false
  let mut tokens = 0.0
  let mut cost = 0.0
  for source_index, (name, content) in files {
    let label = "Source \{source_index + 1}"
    let raw = match merge_records(content, name) {
      Ok(value) => value
      Err(error) => return Err("\{label}: \{error}; no files merged")
    }
    let preview = match
      moongate_preview_usage_file_json(content, source_name=name) {
      Ok(value) => value
      Err(error) => return Err("\{label}: \{error}; no files merged")
    }
    if compare_field(preview, "usageMergeScope") is String(existing) &&
      existing != scope {
      return Err("\{label}: existing merge scope differs; no files merged")
    }
    guard compare_field(preview, "data") is Array(normalized) else {
      return Err("\{label}: no request rows; no files merged")
    }
    imported += normalized.length()
    if imported > 10000 {
      return Err("Usage merge is limited to 10,000 combined input rows")
    }
    let partial = compare_field(preview, "partial") == true.to_json()
    unknown_coverage = unknown_coverage || partial
    sources.push({
      "sourceIndex": (source_index + 1).to_json(),
      "sourceName": name.to_json(),
      "importedRows": normalized.length().to_json(),
      "sourceTotal": compare_field(preview, "sourceTotal"),
      "partial": partial.to_json(),
    })
    for row_index, row in normalized {
      guard raw[row_index] is Object(obj) &&
        usage_file_field(obj, ["requestId", "request_id", "id"]) is String(id) &&
        !id.trim().is_empty() else {
        return Err(
          "\{label} row \{row_index + 1}: explicit nonempty requestId required; no files merged",
        )
      }
      // The legacy reader synthesizes row-N IDs without retaining their origin.
      // Refuse that reserved form rather than merging unrelated anonymous rows.
      if merge_synthetic_id(id) {
        return Err(
          "\{label} row \{row_index + 1}: row-N IDs may be synthetic; use original explicit request IDs; no files merged",
        )
      }
      occurrences.push({
        "requestId": id.to_json(),
        "sourceIndex": (source_index + 1).to_json(),
        "row": (row_index + 1).to_json(),
      })
      match seen.get(id) {
        Some((previous, previous_source, previous_row)) =>
          if previous != row {
            let fields = [
              "appType", "providerId", "model", "date", "inputTokens", "outputTokens",
              "totalTokens", "totalCostUsd",
            ].filter(key => {
              compare_field(previous, key) != compare_field(row, key)
            })
            let quoted_id = id.to_json().stringify()
            return Err(
              "Conflicting requestId \{quoted_id}: source \{previous_source} row \{previous_row} versus source \{source_index + 1} row \{row_index + 1}; differing normalized fields: \{fields.join(", ")}; no files merged",
            )
          }
        None => {
          let total = compare_number(row, "totalTokens")
          if total > 9007199254740991.0 - tokens {
            return Err(
              "Merged token total exceeds the safe limit (9007199254740991); no files merged",
            )
          }
          let estimate = compare_number(row, "totalCostUsd")
          if estimate > 9007199254740991.0 - cost {
            return Err(
              "Merged known estimate exceeds the safe limit (9007199254740991); no files merged",
            )
          }
          tokens += total
          cost += estimate
          seen[id] = (row, source_index + 1, row_index + 1)
          rows.push(row)
        }
      }
    }
  }
  let envelope : Map[String, Json] = {
    "data": rows.to_json(),
    "sourceTotal": rows.length().to_json(),
    "sourceCoverageUnknown": unknown_coverage.to_json(),
    "usageMergeScope": scope.to_json(),
  }
  let result = match
    moongate_preview_usage_file_json(
      Json::object(envelope).stringify(),
      source_name="Merged usage exports",
    ) {
    Ok(Object(obj)) => obj
    Ok(_) => return Err("Cannot construct merged usage preview")
    Err(error) => return Err("Merged output: \{error}; no files merged")
  }
  let duplicates = imported - rows.length()
  let caveats = [
    "Request IDs are matched exactly within the caller-named scope. The caller must use exports from the same gateway/account namespace.",
    "Equality covers normalized usage fields only. Payloads, original timestamps, and unsupported fields are omitted, never compared.",
    "Source totals are not added: overlap and missing rows are unknown. sourceTotal counts merged observed rows; sourceCoverageUnknown preserves any incomplete source evidence.",
    "File-supplied USD estimates are not settled bills. Missing costs stay unknown; conflicting telemetry is never overwritten or enriched.",
    "No provider contacted, file changed, or persistent accounting record written. IDs, labels, scope and source paths remain; review before sharing.",
  ]
  result["usageMerge"] = {
    "schema": "moongate.usage-merge.v1",
    "scope": scope.to_json(),
    "identity": "exact-requestId-within-scope",
    "inputRows": imported.to_json(),
    "uniqueRows": rows.length().to_json(),
    "duplicateRows": duplicates.to_json(),
    "sources": sources.to_json(),
    "occurrences": occurrences.to_json(),
    "caveats": caveats.to_json(),
  }
  let lines = [
    "MoonGate overlapping usage export merge",
    "Scope: " + scope.to_json().stringify(),
    "\{files.length()} sources; \{imported} input rows; \{rows.length()} unique requests; \{duplicates} identical duplicate rows omitted",
  ]
  for source in sources {
    lines.push(
      "Source " +
      compare_field(source, "sourceIndex").stringify() +
      ": " +
      compare_field(source, "sourceName").stringify() +
      "; rows=" +
      compare_field(source, "importedRows").stringify() +
      "; reported total=" +
      compare_field(source, "sourceTotal").stringify() +
      "; partial=" +
      compare_field(source, "partial").stringify(),
    )
  }
  lines.push(usage_file_text(Json::object(result), "report"))
  for caveat in caveats {
    lines.push("- " + caveat)
  }
  result["report"] = (lines.join("\n") + "\n").to_json()
  // Make every successful artifact reopenable within the explorer's same bound.
  if @encoding/utf8.encode(Json::object(result).stringify(indent=2)).length() >
    4 * 1024 * 1024 - 1 {
    return Err(
      "Merged output exceeds the 4 MiB reopen limit; select smaller input slices; no files merged",
    )
  }
  Ok(Json::object(result))
}

///|
fn merge_synthetic_id(id : String) -> Bool {
  if !id.has_prefix("row-") || id.length() <= 4 {
    return false
  }
  for c in id[4:] {
    if c < '0' || c > '9' {
      return false
    }
  }
  true
}

///|
fn merge_records(
  content : String,
  name : String,
) -> Result[Array[Json], String] {
  let source = content.trim().to_owned()
  let source = if name.has_suffix(".csv") ||
    (!source.has_prefix("{") && !source.has_prefix("[") && source.contains(",")) {
    (@usage_csv.to_json(content) catch {
      error => return Err("Usage CSV: \{error}")
    }).stringify()
  } else {
    source
  }
  match moon_parse_json_line(source) {
    Some(Object(obj)) if obj.get("data") is Some(Array(rows)) => Ok(rows)
    _ => moon_transcript_records(source)
  }
}
