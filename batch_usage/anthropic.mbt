///|
/// Import a local Anthropic Message Batches result export. Input includes all
/// three distinct input-token categories. Unknown components never become zero.
/// Payloads are omitted and the JSON reopens in the existing Usage File Explorer.
pub fn import_anthropic_batch_usage_json(
  content : String,
  source_name? : String = "Anthropic Batch results",
  app? : String = "anthropic-batch",
  provider? : String = "anthropic-export",
) -> Result[Json, String] {
  if @encoding/utf8.encode(content).length() > 4 * 1024 * 1024 {
    return Err("Anthropic Batch results exceed the combined 4 MiB UTF-8 limit")
  }
  if app.trim().is_empty() || provider.trim().is_empty() {
    return Err("App and provider labels must be nonempty")
  }
  let rows : Array[Json] = []
  let outcomes : Array[Json] = []
  let seen : Map[String, Bool] = Map([])
  let result_counts : Map[String, Int] = {
    "succeeded": 0,
    "errored": 0,
    "canceled": 0,
    "expired": 0,
  }
  let mut missing = 0
  let mut incomplete = 0
  let mut tokens = 0.0
  let mut uncached = 0.0
  let mut creation = 0.0
  let mut read = 0.0
  let mut output = 0.0
  for index, line in content.split("\n").collect() {
    if line.trim().is_empty() {
      continue
    }
    if outcomes.length() >= 10000 {
      return Err("Anthropic Batch results are limited to 10,000 nonblank lines")
    }
    let record = parse_with_number_text(line) catch {
      _ => return Err("Line \{index + 1}: invalid JSON; no results imported")
    }
    let parsed = match parse_anthropic_result(record) {
      Ok(parsed) => parsed
      Err(error) =>
        return Err("Line \{index + 1}: \{error}; no results imported")
    }
    if seen.contains(parsed.id) {
      return Err("Line \{index + 1}: duplicate custom_id; no results imported")
    }
    seen[parsed.id] = true
    result_counts[parsed.result_type] = result_counts[parsed.result_type] + 1
    if parsed.usage_state == "missing_usage" {
      missing += 1
    }
    if parsed.usage_state == "incomplete_usage" {
      incomplete += 1
    }
    if parsed.total is Some(total) {
      if total > 9007199254740991.0 - tokens {
        return Err(
          "Aggregate tokens exceed the safe-number limit; no results imported",
        )
      }
      tokens += total
      guard parsed.counts["uncachedInputTokens"] is Number(u, ..) &&
        parsed.counts["cacheCreationInputTokens"] is Number(c, ..) &&
        parsed.counts["cacheReadInputTokens"] is Number(r, ..) &&
        parsed.counts["outputTokens"] is Number(o, ..) else {
        return Err("Internal token normalization failure")
      }
      uncached += u
      creation += c
      read += r
      output += o
      rows.push({
        "requestId": parsed.id.to_json(),
        "model": parsed.model,
        "appType": app.to_json(),
        "providerId": provider.to_json(),
        "inputTokens": parsed.input.unwrap().to_json(),
        "outputTokens": parsed.output.unwrap().to_json(),
        "totalTokens": total.to_json(),
        "totalCostUsd": Json::null(),
      })
    }
    outcomes.push({
      "line": (index + 1).to_json(),
      "customId": parsed.id.to_json(),
      "resultType": parsed.result_type.to_json(),
      "usageState": parsed.usage_state.to_json(),
      "model": parsed.model,
      "stopReason": parsed.stop_reason,
      "components": parsed.counts.to_json(),
      "totalTokens": match parsed.total {
        Some(n) => n.to_json()
        None => Json::null()
      },
    })
  }
  let envelope : Json = {
    "data": rows.to_json(),
    "sourceTotal": outcomes.length().to_json(),
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
  let caveat = "Supplied local results only; batch completeness is unverified. Result success does not establish answer quality or task completion. Missing components are unknown, not zero. Costs and dates are unavailable."
  let succeeded = result_counts["succeeded"]
  let errored = result_counts["errored"]
  let canceled = result_counts["canceled"]
  let expired = result_counts["expired"]
  let report = [
      "MoonGate Anthropic Message Batches usage import",
      "Source: " + source_name,
      "Supplied results: \{outcomes.length()}; imported complete usage rows: \{rows.length()}",
      "Result types: succeeded=\{succeeded}; errored=\{errored}; canceled=\{canceled}; expired=\{expired}",
      "Succeeded results with missing usage: \{missing}; incomplete token components: \{incomplete}",
      "Recorded tokens from complete usage rows: \{tokens}",
      "Complete-row components: uncached input=\{uncached}; cache creation input=\{creation}; cache read input=\{read}; output=\{output}",
      "Input tokens include uncached, cache creation and cache read counts exactly once. Nested cache TTL subtotals are not added.",
      "All costs remain unknown; no Batch discount, cache pricing or billing reconciliation is applied.",
      caveat,
      "Payloads, message IDs, headers, errors and arbitrary metadata omitted. Custom IDs, source names, labels and models remain; review before sharing.",
      "Reopen JSON in Usage File Explorer for filters and groups. Keep this original JSON for component and outcome details.",
    ].join("\n") +
    "\n"
  preview["anthropicBatchImport"] = {
    "schema": "moongate.anthropic-batch-import.v1",
    "sourceFormat": "anthropic-message-batches-jsonl",
    "sourceResultCount": outcomes.length().to_json(),
    "importedUsageCount": rows.length().to_json(),
    "resultCounts": result_counts.to_json(),
    "missingUsageCount": missing.to_json(),
    "incompleteUsageCount": incomplete.to_json(),
    "batchCompleteness": "unverified",
    "costSource": "unavailable",
    "dateSource": "unavailable",
    "completeRowComponents": {
      "uncachedInputTokens": uncached.to_json(),
      "cacheCreationInputTokens": creation.to_json(),
      "cacheReadInputTokens": read.to_json(),
      "outputTokens": output.to_json(),
    },
    "outcomes": outcomes.to_json(),
    "caveat": caveat.to_json(),
  }
  preview["report"] = report.to_json()
  let result = Json::object(preview)
  if @encoding/utf8.encode(result.stringify(indent=2)).length() + 1 >
    4 * 1024 * 1024 {
    return Err(
      "Anthropic import output exceeds the 4 MiB reopen limit; use a smaller input slice",
    )
  }
  Ok(result)
}
