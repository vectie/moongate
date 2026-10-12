///|
/// Read one saved Ollama generate/chat response per supplied file. Streaming
/// chunks belong to that one capture, never to separate request records.
pub fn import_ollama_captures_json(
  captures : Array[(String, String)],
  app? : String = "ollama-capture",
  provider? : String = "ollama-export",
) -> Result[Json, String] {
  if captures.is_empty() || captures.length() > 100 {
    return Err("Supply between 1 and 100 captures, one request/stream per file")
  }
  if app.trim().is_empty() || provider.trim().is_empty() {
    return Err("App and provider labels must be nonempty")
  }
  let names : Map[String, Bool] = Map([])
  let rows : Array[Json] = []
  let outcomes : Array[Json] = []
  let counts : Map[String, Int] = {
    "completed": 0,
    "errored": 0,
    "incomplete": 0,
    "empty": 0,
  }
  let mut bytes = 0
  let mut chunks = 0
  let mut tokens = 0.0
  for index, (name, content) in captures {
    if name.trim().is_empty() || names.contains(name) {
      return Err("Capture names must be nonempty and unique")
    }
    names[name] = true
    let size = @encoding/utf8.encode(content).length()
    if size > 4 * 1024 * 1024 - bytes {
      return Err("Captures exceed the combined 4 MiB UTF-8 limit")
    }
    bytes += size
    let parsed = match parse_capture(content) {
      Ok(value) => value
      Err(error) =>
        return Err("Capture \{index + 1}: \{error}; no captures imported")
    }
    chunks += parsed.chunk_count
    if chunks > 10000 {
      return Err("Captures exceed the combined 10,000 response-object limit")
    }
    counts[parsed.state] = counts[parsed.state] + 1
    let mut usage_state = "unavailable"
    let input = parsed.metrics.get("prompt_eval_count").unwrap_or(Json::null())
    let output = parsed.metrics.get("eval_count").unwrap_or(Json::null())
    if parsed.state == "completed" {
      usage_state = if input == Json::null() && output == Json::null() {
        "missing"
      } else if input == Json::null() || output == Json::null() {
        "incomplete"
      } else {
        "complete"
      }
    }
    let mut total = Json::null()
    if usage_state == "complete" {
      guard input is Number(i, ..) && output is Number(o, ..) else {
        return Err("Internal token normalization failure")
      }
      if o > 9007199254740991.0 - i || i + o > 9007199254740991.0 - tokens {
        return Err("Capture tokens exceed the safe-number sum limit")
      }
      tokens += i + o
      total = (i + o).to_json()
      rows.push({
        "requestId": "",
        "model": parsed.model.to_json(),
        "appType": app.to_json(),
        "providerId": provider.to_json(),
        "inputTokens": input,
        "outputTokens": output,
        "totalTokens": total,
        "createdAt": parsed.created_at,
        "totalCostUsd": Json::null(),
      })
    }
    outcomes.push({
      "capture": (index + 1).to_json(),
      "sourceName": name.to_json(),
      "responseObjectCount": parsed.chunk_count.to_json(),
      "state": parsed.state.to_json(),
      "apiShape": parsed.shape.to_json(),
      "model": if parsed.model.is_empty() {
        Json::null()
      } else {
        parsed.model.to_json()
      },
      "terminalLine": parsed.terminal_line,
      "usageState": usage_state.to_json(),
      "doneReason": parsed.reason,
      "terminalMetrics": parsed.metrics.to_json(),
      "totalTokens": total,
    })
  }
  let envelope : Json = {
    "data": rows.to_json(),
    "sourceTotal": captures.length().to_json(),
    // A set of files has no authority to assert whole-interval coverage.
    "sourceCoverageUnknown": true,
  }
  let preview = match
    @usage_preview.moongate_preview_usage_file_json(
      envelope.stringify(),
      source_name="Saved Ollama captures",
    ) {
    Ok(Object(value)) => value
    Ok(_) => return Err("Internal preview normalization failure")
    Err(error) => return Err(error)
  }
  // Bind imported normalized rows back to the capture without fabricating a
  // request ID. Capture indexes are local artifact indexes, not global IDs.
  guard preview.get("data") is Some(Array(normalized)) else {
    return Err("Internal preview row failure")
  }
  let mut row_index = 0
  for outcome in outcomes {
    guard outcome is Object(fields) else {
      return Err("Internal outcome failure")
    }
    if fields.get("usageState") == Some("complete".to_json()) {
      guard normalized[row_index] is Object(row) else {
        return Err("Internal row failure")
      }
      row["captureIndex"] = fields["capture"]
      fields["date"] = row["date"]
      row_index += 1
    } else {
      fields["date"] = Json::null()
    }
  }
  let caveats = [
    "One supplied file is one response capture. Chunks are not requests. Files have no provider request ID; no cross-file deduplication or whole-interval completeness is established.",
    "Only done:true terminal objects with both prompt_eval_count and eval_count enter usage totals. Partial-stream metrics are not final consumption; incomplete, errored and empty captures contribute no inferred tokens.",
    "Terminal metrics are provider-reported observations. Durations are nanoseconds, not proxy latency, wall-clock benchmarks or live performance qualification. Cached prompt tokens, when present, are a subset and are not added to prompt_eval_count.",
    "Costs remain unknown, including for local models. No electricity, hosting, rate-card, currency or settlement inference is made. Labels are operator supplied and do not verify route identity.",
    "The normalized UTC day uses terminal created_at only. Missing or unreadable dates remain undated; no file/download timestamp is substituted.",
    "Response text, messages, thinking, context, tool calls, error text and arbitrary fields are omitted. Source names and model/operator labels remain; inspect them before sharing.",
    "Reopen the JSON in Usage File Explorer for filters and groups. Its re-export drops capture diagnostics and indexes; keep this original artifact for source and terminal evidence. No provider contacted or persistent usage changed.",
  ]
  let report = [
    "MoonGate saved Ollama capture review",
    "Supplied capture files: \{captures.length()}; response objects: \{chunks}; complete usage rows: \{rows.length()}",
    "States: " + counts.to_json().stringify(),
    "Recorded tokens from complete terminal usage: \{tokens}; all costs unknown; source coverage unverified.",
  ]
  for outcome in outcomes {
    report.push(outcome.stringify())
  }
  for caveat in caveats {
    report.push("- " + caveat)
  }
  preview["ollamaCaptureImport"] = {
    "schema": "moongate.ollama-capture-import.v1",
    "sourceCaptureCount": captures.length().to_json(),
    "responseObjectCount": chunks.to_json(),
    "importedUsageCount": rows.length().to_json(),
    "stateCounts": counts.to_json(),
    "durationUnit": "nanoseconds",
    "coverage": "unverified",
    "costSource": "unavailable",
    "outcomes": outcomes.to_json(),
    "caveats": caveats.to_json(),
  }
  preview["report"] = (report.join("\n") + "\n").to_json()
  let result = Json::object(preview)
  if @encoding/utf8.encode(result.stringify(indent=2)).length() + 1 >
    4 * 1024 * 1024 {
    return Err(
      "Capture output exceeds the 4 MiB reopen limit; use fewer captures",
    )
  }
  Ok(result)
}
