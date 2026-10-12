///|
/// Convert local OpenAI Batch output/error JSONL into a reopenable usage preview.
/// Only Chat Completions and Responses result bodies are supported. Payloads and
/// error messages are omitted; costs are always unknown. No provider is contacted.
/// Optional requests JSONL adds exact-ID manifest coverage with separate request
/// and response context; missing results are never treated as zero usage.
pub fn import_batch_usage_json(
  content : String,
  source_name? : String = "Batch results",
  app? : String = "openai-batch",
  provider? : String = "openai-export",
  requests? : String,
) -> Result[Json, String] {
  if @encoding/utf8.encode(content).length() > 4 * 1024 * 1024 {
    return Err("Batch results exceed the combined 4 MiB UTF-8 limit")
  }
  if requests is Some(manifest) &&
    @encoding/utf8.encode(manifest).length() >
    4 * 1024 * 1024 - @encoding/utf8.encode(content).length() {
    return Err(
      "Batch requests and results exceed the combined 4 MiB UTF-8 limit",
    )
  }
  if app.trim().is_empty() || provider.trim().is_empty() {
    return Err("App and provider labels must be nonempty")
  }
  let rows : Array[Json] = []
  let outcomes : Array[Json] = []
  let seen : Map[String, Bool] = Map([])
  let mut tokens = 0.0
  let mut batch_errors = 0
  let mut http_errors = 0
  let mut missing_usage = 0
  let mut noncompleted = 0
  for index, line in content.split("\n").collect() {
    if line.trim().is_empty() {
      continue
    }
    if outcomes.length() >= 10000 {
      return Err("Batch results are limited to 10,000 nonblank lines")
    }
    let record = parse_with_number_text(line) catch {
      _ => return Err("Line \{index + 1}: invalid JSON; no results imported")
    }
    let parsed = match parse_result(record) {
      Ok(parsed) => parsed
      Err(error) =>
        return Err("Line \{index + 1}: \{error}; no results imported")
    }
    if seen.contains(parsed.custom_id) {
      return Err("Line \{index + 1}: duplicate custom_id; no results imported")
    }
    seen[parsed.custom_id] = true
    match parsed.reason {
      "batch_error" => batch_errors += 1
      "http_error" => http_errors += 1
      "missing_usage" => missing_usage += 1
      _ => ()
    }
    if parsed.response_state != "" && parsed.response_state != "completed" {
      noncompleted += 1
    }
    if parsed.row is Some(Object(row)) {
      guard row.get("totalTokens") is Some(Number(total, ..)) else {
        return Err("Internal token normalization failure")
      }
      if total > 9007199254740991.0 - tokens {
        return Err(
          "Line \{index + 1}: aggregate tokens exceed the safe-number limit; no results imported",
        )
      }
      tokens += total
      row["appType"] = app.to_json()
      row["providerId"] = provider.to_json()
      rows.push(Json::object(row))
    }
    let outcome : Map[String, Json] = {
      "line": (index + 1).to_json(),
      "customId": parsed.custom_id.to_json(),
      "outcome": parsed.reason.to_json(),
      "httpStatus": parsed.http_status,
      "responseState": if parsed.response_state.is_empty() {
        Json::null()
      } else {
        parsed.response_state.to_json()
      },
    }
    if requests is Some(_) {
      let body = if parsed.reason == "imported" ||
        parsed.reason == "missing_usage" {
        match record {
          { "response": { "body": Object(body), .. }, .. } => body
          _ => Map([])
        }
      } else {
        Map([])
      }
      outcome["responseModel"] = match body.get("model") {
        Some(String(model)) => model.to_json()
        _ => Json::null()
      }
      outcome["responseObject"] = match body.get("object") {
        Some(String(kind)) => kind.to_json()
        _ => Json::null()
      }
    }
    outcomes.push(Json::object(outcome))
  }
  let (request_join, missing_results) = match requests {
    Some(manifest) =>
      match reconcile_requests(manifest, outcomes) {
        Ok((joined, missing)) => (Some(joined), missing)
        Err(error) => return Err(error)
      }
    None => (None, 0)
  }
  let source_rows = outcomes.length()
  let envelope : Json = {
    "data": rows.to_json(),
    "sourceTotal": (source_rows + missing_results).to_json(),
  }
  let preview = match
    @usage_preview.moongate_preview_usage_file_json(
      envelope.stringify(),
      source_name~,
    ) {
    Ok(Object(preview)) => preview
    Ok(_) => return Err("Internal preview normalization failure")
    Err(error) => return Err(error)
  }
  let caveat = if requests is Some(_) {
    "Supplied local request and result files only; provider batch completeness is unverified. Missing results, usage and errors are not zero-token or zero-cost evidence. Costs are unknown, not settled charges."
  } else {
    "Supplied result lines only; batch completeness is unverified. Missing usage and errors are not zero-token or zero-cost evidence. Costs are unknown, not settled charges."
  }
  let mut report = [
      "MoonGate OpenAI Batch usage import",
      "Source: " + source_name,
      "Supplied results: \{source_rows}; imported usage rows: \{rows.length()}",
      "Batch errors: \{batch_errors}; HTTP errors: \{http_errors}; missing usage: \{missing_usage}",
      "Non-completed Responses states: \{noncompleted} (reported tokens are retained when present)",
      "Recorded tokens: \{tokens}; all imported costs remain unknown",
      "Labels: app=\{app}; provider=\{provider} (review labels, not verified routing identity)",
      caveat,
      "Payloads and error messages omitted. custom_id values, source names and model labels remain; review before sharing.",
      "Reopen the JSON in Usage File Explorer for filters and group reports. Keep this import JSON to retain per-line outcomes.",
    ].join("\n") +
    "\n"
  let batch_import : Map[String, Json] = {
    "schema": "moongate.batch-import.v1",
    "sourceFormat": "openai-batch-jsonl",
    "sourceResultCount": source_rows.to_json(),
    "importedUsageCount": rows.length().to_json(),
    "batchErrorCount": batch_errors.to_json(),
    "httpErrorCount": http_errors.to_json(),
    "missingUsageCount": missing_usage.to_json(),
    "nonCompletedResponseCount": noncompleted.to_json(),
    "batchCompleteness": "unverified",
    "costSource": "unavailable",
    "outcomes": outcomes.to_json(),
    "caveat": caveat.to_json(),
  }
  if request_join is Some(Object(joined)) {
    batch_import["requestJoin"] = Json::object(joined)
    let requested = field(joined, "requestCount").stringify()
    let matched = field(joined, "matchedResultCount").stringify()
    let missing = field(joined, "missingResultCount").stringify()
    let unexpected = field(joined, "unexpectedResultCount").stringify()
    report += "Supplied request manifest: \{requested} requests; \{matched} matched results; \{missing} missing results; \{unexpected} unexpected results\n"
    report += "Join uses exact custom_id only. Request/result model and endpoint context is retained separately, without equivalence claims. Manifest coverage does not verify submission or successful completion.\n"
    report += "sourceTotal is the union of supplied request and result IDs; unexpected-result usage remains included. Retain this JSON for joined diagnostics.\n"
  }
  preview["batchImport"] = Json::object(batch_import)
  preview["report"] = report.to_json()
  Ok(Json::object(preview))
}
