///|
/// Read saved Responses JSON objects or HTTP SSE bodies into usage-file.v1.
/// Only explicit terminal usage contributes rows. This pure API accesses no
/// files, providers, credentials or persistent usage store.
pub fn import_response_captures_json(
  captures : Array[(String, String)],
  app? : String = "responses-capture",
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
    fail("Supply 1 to 100 captures, one response or HTTP SSE stream per file")
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
    "failed": 0,
    "cancelled": 0,
    "interrupted": 0,
    "errored": 0,
    "unknown": 0,
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
    let parsed = parse_response_capture(content) catch {
      error => fail("Capture \{index + 1}: \{error}; no captures imported")
    }
    if !parsed.id.is_empty() {
      if ids.contains(parsed.id) {
        fail(
          "Capture \{index + 1}: duplicate response id across files; choose one capture per response",
        )
      }
      ids[parsed.id] = true
    }
    objects += parsed.objects
    if objects > 10000 {
      fail("Captures exceed 10,000 response objects or SSE events")
    }
    counts[parsed.state] = counts[parsed.state] + 1
    let input = parsed.usage.get("input_tokens").unwrap_or(Json::null())
    let output = parsed.usage.get("output_tokens").unwrap_or(Json::null())
    let total = parsed.usage.get("total_tokens").unwrap_or(Json::null())
    let usage_state = if !parsed.terminal {
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
      "createdAt": parsed.created,
      "state": parsed.state.to_json(),
      "responseStatus": parsed.status.to_json(),
      "terminal": parsed.terminal.to_json(),
      "usageState": usage_state.to_json(),
      "responseObjectCount": parsed.objects.to_json(),
      "terminalLine": parsed.terminal_line,
      "incompleteReason": parsed.incomplete_reason,
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
      source_name="Saved Responses captures",
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
      fields["date"] = if row["date"] == "".to_json() {
        Json::null()
      } else {
        row["date"]
      }
      row_index += 1
    } else {
      fields["date"] = Json::null()
    }
  }
  let caveats = [
    "One file is one saved Responses JSON object or HTTP SSE body. Lifecycle IDs, models and present timestamps must agree; duplicate IDs across files reject. Captured IDs and operator labels are unverified claims.",
    "Only complete, explicit usage on a terminal response contributes consumption. Completed, incomplete, failed and cancelled JSON outcomes can record tokens. HTTP SSE requires a framed response.completed, response.incomplete or response.failed event with matching status. No [DONE] marker is used.",
    "Terminal outcome and useful answer are different. Interrupted, errored, empty and unrecognized-status captures remain diagnostic only. Nonterminal usage is never carried forward into missing terminal usage.",
    "Costs are unknown. Cache, reasoning and other detail subsets are omitted, never added to input/output totals. No counts, prices, settlement, dates or interval coverage are invented.",
    "Only captured created_at determines UTC date. Missing or unrepresentable dates stay undated. All supplied captures remain represented in sourceTotal and outcomes, including captures without an imported row.",
    "This reader supports a documented text/tool/reasoning SSE subset, rejects unsupported events and all data after terminal outcome, and is not a WebSocket or multi-response reader. Optional sequence numbers must increase; gaps do not prove lost events or full coverage.",
    "Prompts, output, deltas, tool arguments, errors and arbitrary fields are omitted. Source names, response IDs and model/operator labels remain private data; inspect before sharing.",
    "Reopen in Usage File Explorer or export CSV for grouping/filtering. Keep the original artifact: ordinary re-export drops capture diagnostics. No provider contacted or persistent usage modified.",
  ]
  let report = [
    "MoonGate saved Responses capture review",
    "Capture files: \{captures.length()}; response objects/events: \{objects}; complete terminal usage rows: \{rows.length()}",
    "States: " + counts.to_json().stringify(),
    "Recorded tokens with complete terminal usage: \{tokens}; costs unknown; interval coverage unverified.",
  ]
  for outcome in outcomes {
    report.push(outcome.stringify())
  }
  for caveat in caveats {
    report.push("- " + caveat)
  }
  preview["responseCaptureImport"] = {
    "schema": "moongate.response-capture-import.v1",
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
