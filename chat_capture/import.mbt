///|
/// Convert saved Chat Completions response bodies to a redacted usage artifact.
/// No file, provider, gateway or persistent usage store is accessed here.
pub fn import_chat_captures_json(
  captures : Array[(String, String)],
  app? : String = "chat-capture",
  provider? : String = "openai-compatible-export",
) -> Result[Json, String] {
  try import_captures(captures, app~, provider~) catch {
    error => Err("\{error}")
  } noraise {
    value => Ok(value)
  }
}

///|
fn import_captures(
  captures : Array[(String, String)],
  app~ : String,
  provider~ : String,
) -> Json raise {
  if captures.is_empty() || captures.length() > 100 {
    fail("Supply 1 to 100 captures, one response or stream per file")
  }
  if app.trim().is_empty() || provider.trim().is_empty() {
    fail("App and provider labels must be nonempty")
  }
  let names : Map[String, Bool] = Map([])
  let ids : Map[String, Bool] = Map([])
  let rows : Array[Json] = []
  let outcomes : Array[Json] = []
  let counts : Map[String, Int] = {
    "completed": 0,
    "incomplete": 0,
    "errored": 0,
    "empty": 0,
  }
  let mut bytes = 0
  let mut objects = 0
  let mut tokens = 0.0
  for index, (name, content) in captures {
    if name.trim().is_empty() || names.contains(name) {
      fail("Capture names must be nonempty and unique")
    }
    names[name] = true
    let size = @encoding/utf8.encode(content).length()
    if size > 4 * 1024 * 1024 - bytes {
      fail("Captures exceed the combined 4 MiB UTF-8 limit")
    }
    bytes += size
    let parsed = parse_chat_capture(content) catch {
      error => fail("Capture \{index + 1}: \{error}; no captures imported")
    }
    if !parsed.id.is_empty() {
      if ids.contains(parsed.id) {
        fail(
          "Capture \{index + 1}: duplicate response id across files; choose one capture per request",
        )
      }
      ids[parsed.id] = true
    }
    objects += parsed.objects
    if objects > 10000 {
      fail("Captures exceed 10,000 response objects")
    }
    counts[parsed.state] = counts[parsed.state] + 1
    let input = parsed.usage.get("prompt_tokens").unwrap_or(Json::null())
    let output = parsed.usage.get("completion_tokens").unwrap_or(Json::null())
    let total = parsed.usage.get("total_tokens").unwrap_or(Json::null())
    let usage_state = if parsed.state != "completed" {
      "unavailable"
    } else if input == Json::null() &&
      output == Json::null() &&
      total == Json::null() {
      "missing"
    } else if input == Json::null() ||
      output == Json::null() ||
      total == Json::null() {
      "incomplete"
    } else {
      "complete"
    }
    if usage_state == "complete" {
      guard total is Number(n, ..) else { fail("Internal usage total failure") }
      if n > 9007199254740991.0 - tokens {
        fail("Combined token count exceeds the safe range")
      }
      tokens += n
      rows.push({
        "requestId": parsed.id.to_json(),
        "model": parsed.model.to_json(),
        "appType": app.to_json(),
        "providerId": provider.to_json(),
        "inputTokens": input,
        "outputTokens": output,
        "totalTokens": total,
        "createdAt": parsed.created,
        "totalCostUsd": Json::null(),
      })
    }
    outcomes.push({
      "captureIndex": (index + 1).to_json(),
      "sourceName": name.to_json(),
      "requestId": if parsed.id.is_empty() {
        Json::null()
      } else {
        parsed.id.to_json()
      },
      "model": if parsed.model.is_empty() {
        Json::null()
      } else {
        parsed.model.to_json()
      },
      "format": parsed.format.to_json(),
      "created": parsed.created,
      "state": parsed.state.to_json(),
      "usageState": usage_state.to_json(),
      "responseObjectCount": parsed.objects.to_json(),
      "terminalLine": parsed.terminal_line,
      "choices": parsed.finishes.to_json(),
      "observedUsage": parsed.usage.to_json(),
    })
  }
  let envelope : Json = {
    "data": rows.to_json(),
    "sourceTotal": captures.length().to_json(),
    "sourceCoverageUnknown": true,
  }
  let preview = match
    @usage_preview.moongate_preview_usage_file_json(
      envelope.stringify(),
      source_name="Saved Chat Completions captures",
    ) {
    Ok(Object(fields)) => fields
    Ok(_) => fail("Internal preview failure")
    Err(error) => fail(error)
  }
  guard preview.get("data") is Some(Array(normalized)) else {
    fail("Internal rows failure")
  }
  let mut row_index = 0
  for outcome in outcomes {
    guard outcome is Object(fields) else { fail("Internal outcome failure") }
    if fields.get("usageState") == Some("complete".to_json()) {
      guard normalized[row_index] is Object(row) else {
        fail("Internal row failure")
      }
      row["captureIndex"] = fields["captureIndex"]
      fields["date"] = row["date"]
      row_index += 1
    } else {
      fields["date"] = Json::null()
    }
  }
  let caveats = [
    "One file is one Chat Completions response or SSE stream. Response IDs are required on completion objects and must stay constant; duplicate IDs across supplied files reject the import. IDs and provider labels are captured claims, not verified global identities.",
    "Only completed captures with prompt_tokens, completion_tokens and matching total_tokens enter usage totals. Missing usage stays unknown. Interrupted or errored streams do not contribute inferred final consumption, even if they contain a usage object.",
    "SSE completion requires a blank-line-terminated [DONE] and a finish reason for every observed choice. Completion means captured protocol termination, not answer quality; length, filtering and tool-call finishes remain visible.",
    "Costs remain unknown. No prices, settlement, cache savings or live performance are inferred. Token detail subsets are omitted and never added to the reported totals.",
    "The UTC day uses only the captured created Unix timestamp. Missing or unrepresentable dates remain undated. Saved files do not establish complete interval coverage.",
    "Messages, deltas, tool calls, prompts, errors, headers and arbitrary fields are omitted. Source names, IDs and model/operator labels remain private data; inspect before sharing.",
    "Reopen the JSON in Usage File Explorer for filtering and grouping, or use usage export-csv. Keep this original artifact: ordinary re-export drops capture diagnostics. No provider contacted or persistent usage modified.",
  ]
  let report = [
    "MoonGate saved Chat Completions capture review",
    "Capture files: \{captures.length()}; response objects: \{objects}; complete usage rows: \{rows.length()}",
    "States: " + counts.to_json().stringify(),
    "Recorded tokens with complete terminal usage: \{tokens}; costs unknown; interval coverage unverified.",
  ]
  for outcome in outcomes {
    report.push(outcome.stringify())
  }
  for caveat in caveats {
    report.push("- " + caveat)
  }
  preview["chatCaptureImport"] = {
    "schema": "moongate.chat-capture-import.v1",
    "sourceCaptureCount": captures.length().to_json(),
    "responseObjectCount": objects.to_json(),
    "importedUsageCount": rows.length().to_json(),
    "stateCounts": counts.to_json(),
    "coverage": "unverified",
    "costSource": "unavailable",
    "outcomes": outcomes.to_json(),
    "caveats": caveats.to_json(),
  }
  preview["report"] = (report.join("\n") + "\n").to_json()
  let result = Json::object(preview)
  if @encoding/utf8.encode(result.stringify(indent=2)).length() + 1 >
    4 * 1024 * 1024 {
    fail("Capture output exceeds the 4 MiB reopen limit; use fewer captures")
  }
  result
}
