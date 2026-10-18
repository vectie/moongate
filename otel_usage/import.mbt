///|
/// Convert a saved OTLP JSON trace export to local usage evidence. Only CLIENT
/// spans with chat, text_completion or generate_content operation names qualify.
/// No network, accounting, or routing operation is performed.
///
/// ```mbt check
/// test {
///   assert_true(
///     @otel_usage.import_otel_usage_json("{\"resourceSpans\":[]}") is Ok(_),
///   )
/// }
/// ```
pub fn import_otel_usage_json(
  content : String,
  source_name~ : String = "OpenTelemetry export",
) -> Result[Json, String] {
  if @utf8.encode(content).length() > 4 * 1024 * 1024 {
    return Err("OTLP import exceeds the 4 MiB UTF-8 input limit")
  }
  let root = parse_exports(content) catch {
    error => return Err("OTLP import: \{error}; no rows imported")
  }
  build_import(root, source_name) catch {
    error => Err("OTLP import: \{error}; no rows imported")
  }
}

///|
fn build_import(
  root : Json,
  source_name : String,
) -> Result[Json, String] raise {
  guard root is Object(_) && field(root, "resourceSpans") is Array(resources) else {
    fail("Expected resourceSpans array")
  }
  let rows : Array[Json] = []
  let outcomes : Array[Json] = []
  let seen : Map[String, Bool] = Map([])
  let latencies : Array[Json] = []
  let mut span_count = 0
  let mut skipped = 0
  let mut missing_usage = 0
  let mut missing_model = 0
  let mut token_total = 0.0
  let mut error_spans = 0
  for resource in resources {
    guard resource is Object(_) &&
      field(resource, "scopeSpans") is Array(scopes) else {
      fail("Each resourceSpans entry needs a scopeSpans array")
    }
    let service = string_attribute(
      attributes(field(field(resource, "resource"), "attributes")),
      "service.name",
    )
    for scope in scopes {
      guard scope is Object(_) && field(scope, "spans") is Array(spans) else {
        fail("Each scopeSpans entry needs a spans array")
      }
      for span in spans {
        span_count += 1
        if span_count > 10000 {
          fail("OTLP import is limited to 10,000 spans")
        }
        guard span is Object(_) else { fail("Each span must be an object") }
        let attrs = attributes(field(span, "attributes"))
        let operation = string_attribute(attrs, "gen_ai.operation.name")
        if enum_value(field(span, "kind"), 5, "Span kind") != 3.0 ||
          !(operation is Some("chat" | "text_completion" | "generate_content")) {
          skipped += 1
          continue
        }
        let id = "otel:" +
          span_id(field(span, "traceId"), 32) +
          ":" +
          span_id(field(span, "spanId"), 16)
        if seen.contains(id) {
          fail(
            "Duplicate candidate traceId/spanId; use a non-overlapping export",
          )
        }
        seen[id] = true
        let requested = string_attribute(attrs, "gen_ai.request.model")
        let response = string_attribute(attrs, "gen_ai.response.model")
        let model = match response {
          Some(_) => response
          None => requested
        }
        let provider = string_attribute(attrs, "gen_ai.provider.name")
        let input = count_attribute(attrs, "gen_ai.usage.input_tokens")
        let output = count_attribute(attrs, "gen_ai.usage.output_tokens")
        let start = timestamp(field(span, "startTimeUnixNano"))
        let end = timestamp(field(span, "endTimeUnixNano"))
        let latency = match (start, end) {
          (Some(start), Some(end)) => {
            if end < start {
              fail("Span end precedes its start")
            }
            Json((end - start).to_double() / 1000000.0)
          }
          _ => Json::null()
        }
        let status_value = field(span, "status")
        if status_value != Json::null() && !(status_value is Object(_)) {
          fail("Span status must be an object")
        }
        let status = enum_value(
          field(status_value, "code"),
          2,
          "Span status.code",
        )
        let status_name = if status == 2.0 {
          error_spans += 1
          "error"
        } else if status == 1.0 {
          "ok"
        } else {
          "unset"
        }
        let total = match (input, output) {
          (Some(input), Some(output)) => {
            if input > 9007199254740991.0 - output {
              fail("Combined token count exceeds safe-number range")
            }
            Some(input + output)
          }
          _ => None
        }
        let state = if total is None {
          missing_usage += 1
          "incomplete_usage"
        } else if model is None {
          missing_model += 1
          "missing_model"
        } else {
          "imported"
        }
        outcomes.push({
          "sourceSpan": Json(span_count),
          "requestId": Json(id),
          "operation": text_json(operation),
          "status": Json(status_name),
          "usageState": Json(state),
          "requestedModel": text_json(requested),
          "responseModel": text_json(response),
          "modelSource": if response is Some(_) {
            "response"
          } else if requested is Some(_) {
            "request"
          } else {
            "unavailable"
          },
          "serviceName": text_json(service),
          "providerName": text_json(provider),
          "inputTokens": count_json(input),
          "outputTokens": count_json(output),
          "totalTokens": count_json(total),
          "latencyMs": latency,
        })
        if state != "imported" {
          continue
        }
        let total = total.unwrap()
        if token_total > 9007199254740991.0 - total {
          fail("Aggregate token count exceeds safe-number range")
        }
        token_total += total
        rows.push({
          "requestId": Json(id),
          "appType": Json(service.unwrap_or("Unknown")),
          "providerId": Json(provider.unwrap_or("Unknown")),
          "model": Json(model.unwrap()),
          "inputTokens": count_json(input),
          "outputTokens": count_json(output),
          "totalTokens": Json(total),
          "totalCostUsd": Json::null(),
          "createdAt": match start {
            Some(start) => Json((start / 1000000000UL).to_double())
            None => Json::null()
          },
        })
        latencies.push(latency)
      }
    }
  }
  let input : Json = {
    "data": Json(rows),
    "sourceTotal": Json(outcomes.length()),
    "sourceCoverageUnknown": true,
  }
  let preview = match
    @usage_preview.moongate_preview_usage_file_json(
      input.stringify(),
      source_name="OpenTelemetry normalized rows",
    ) {
    Ok(Object(preview)) => preview
    Ok(_) => fail("Internal usage preview failure")
    Err(error) => fail(error)
  }
  preview["sourceName"] = Json(source_name)
  // The normal explorer omits unsupported fields. Keep span duration in the
  // original import artifact so the existing latency reader can consume it.
  guard preview["data"] is Array(normalized) else {
    fail("Internal usage rows missing")
  }
  for index, row in normalized {
    guard row is Object(fields) else { fail("Internal usage row shape") }
    fields["latencyMs"] = latencies[index]
  }
  let caveat = "Saved spans only; sampling, dropped spans and export completeness are unknown. Each distinct client span is an observation, not proof of a unique provider execution. Missing usage and costs remain unknown; status does not prove response quality or billing settlement."
  preview["otelImport"] = {
    "schema": "moongate.otel-usage-import.v1",
    "sourceFormat": "otlp-json-traces",
    "sourceSpanCount": Json(span_count),
    "candidateSpanCount": Json(outcomes.length()),
    "skippedSpanCount": Json(skipped),
    "importedUsageCount": Json(rows.length()),
    "incompleteUsageCount": Json(missing_usage),
    "missingModelCount": Json(missing_model),
    "errorSpanCount": Json(error_spans),
    "outcomes": Json(outcomes),
    "caveat": Json(caveat),
  }
  preview["report"] = Json(
    [
      "MoonGate OpenTelemetry GenAI usage import",
      "Source: " + source_name,
      "Spans: \{span_count}; candidate client generations: \{outcomes.length()}; skipped: \{skipped}",
      "Imported complete usage rows: \{rows.length()}; incomplete usage: \{missing_usage}; complete usage without model: \{missing_model}",
      "Candidate spans marked error: \{error_spans}; recorded imported tokens: \{token_total}",
      "Both input and output totals are required. Cache/reasoning subcounts are not added to their totals.",
      "Costs remain unknown. Provider names are instrumentation labels, not authenticated route identities.",
      caveat,
      "Bodies, messages, events, status messages, span names and arbitrary attributes omitted. IDs, model/service/provider labels and source name remain; inspect before sharing.",
      "Open this JSON in Usage File Explorer, latency profile, or spreadsheet export. Keep the original import for span outcomes and duration.",
    ].join("\n") +
    "\n",
  )
  let result = Json::object(preview)
  if @utf8.encode(result.stringify(indent=2)).length() + 1 > 4 * 1024 * 1024 {
    fail(
      "OTLP import output exceeds the 4 MiB reopen limit; use a smaller export",
    )
  }
  Ok(result)
}

///|
fn parse_exports(content : String) -> Json raise {
  try @exact_json.parse_with_number_text(content) catch {
    _ => {
      let resources : Array[Json] = []
      let mut documents = 0
      for index, line in content.split("\n").collect() {
        if line.trim().is_empty() {
          continue
        }
        let value = @exact_json.parse_with_number_text(line) catch {
          _ => fail("Invalid OTLP JSON/JSONL at line \{index + 1}")
        }
        guard value is Object(_) &&
          field(value, "resourceSpans") is Array(items) else {
          fail("OTLP JSONL line \{index + 1} needs resourceSpans array")
        }
        documents += 1
        if documents > 10000 {
          fail("OTLP import is limited to 10,000 export documents")
        }
        resources.append(items)
      }
      if documents == 0 {
        fail("Expected an OTLP JSON or JSONL trace export")
      }
      { "resourceSpans": Json(resources) }
    }
  } noraise {
    value => value
  }
}
