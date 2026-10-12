///|
// Join only non-secret request context. Bodies are read for the model label but
// never copied into the normalized output, reports, or refusal messages.
fn reconcile_requests(
  content : String,
  outcomes : Array[Json],
) -> Result[(Json, Int), String] {
  let results : Map[String, Map[String, Json]] = Map([])
  for outcome in outcomes {
    guard outcome is Object(obj) && field(obj, "customId") is String(id) else {
      return Err("Internal Batch outcome normalization failure")
    }
    results[id] = obj
  }
  let seen : Map[String, Bool] = Map([])
  let joined : Array[Json] = []
  let mut missing = 0
  for index, line in content.split("\n").collect() {
    if line.trim().is_empty() {
      continue
    }
    if seen.length() >= 10000 {
      return Err("Batch requests are limited to 10,000 nonblank lines")
    }
    let record = @json.parse(line) catch {
      _ =>
        return Err(
          "Request line \{index + 1}: invalid JSON; no results imported",
        )
    }
    guard record is Object(obj) else {
      return Err(
        "Request line \{index + 1}: expected a Batch request object; no results imported",
      )
    }
    guard field(obj, "custom_id") is String(id) && !id.trim().is_empty() else {
      return Err(
        "Request line \{index + 1}: a nonempty custom_id is required; no results imported",
      )
    }
    if seen.contains(id) {
      return Err(
        "Request line \{index + 1}: duplicate custom_id; no results imported",
      )
    }
    guard field(obj, "method") == Json::string("POST") &&
      field(obj, "url") is String(endpoint) &&
      ["/v1/chat/completions", "/v1/responses"].contains(endpoint) else {
      return Err(
        "Request line \{index + 1}: expected POST /v1/chat/completions or /v1/responses; no results imported",
      )
    }
    guard field(obj, "body") is Object(body) &&
      field(body, "model") is String(model) &&
      !model.trim().is_empty() else {
      return Err(
        "Request line \{index + 1}: body needs a nonempty model; no results imported",
      )
    }
    seen[id] = true
    let result = results.get(id)
    let row : Map[String, Json] = {
      "customId": id.to_json(),
      "requestLine": (index + 1).to_json(),
      "requestEndpoint": endpoint.to_json(),
      "requestedModel": model.to_json(),
      "match": if result is Some(_) {
        "matched"
      } else {
        "missing_result"
      },
    }
    match result {
      Some(result) => copy_result_context(row, result)
      None => {
        missing += 1
        row["outcome"] = "missing_result"
        for
          key in [
            "resultLine", "httpStatus", "responseState", "responseModel", "responseObject",
          ] {
          row[key] = Json::null()
        }
      }
    }
    joined.push(Json::object(row))
  }
  let mut unexpected = 0
  // Request order first; unexpected results retain their original result order.
  for outcome in outcomes {
    guard outcome is Object(result) && field(result, "customId") is String(id) else {
      return Err("Internal Batch outcome normalization failure")
    }
    if !seen.contains(id) {
      unexpected += 1
      let row : Map[String, Json] = {
        "customId": id.to_json(),
        "requestLine": Json::null(),
        "requestEndpoint": Json::null(),
        "requestedModel": Json::null(),
        "match": "unexpected_result",
      }
      copy_result_context(row, result)
      joined.push(Json::object(row))
    }
  }
  Ok(
    (
      {
        "schema": "moongate.batch-request-join.v1",
        "requestCount": seen.length().to_json(),
        "matchedResultCount": (seen.length() - missing).to_json(),
        "missingResultCount": missing.to_json(),
        "unexpectedResultCount": unexpected.to_json(),
        "requestIdCoverage": if missing == 0 {
          "all-observed"
        } else {
          "missing-results"
        },
        "outcomes": joined.to_json(),
        "caveat": "Exact custom_id join against supplied local files only. Submission, endpoint/model equivalence and successful completion are unverified. Unexpected-result usage is included in totals; missing results do not imply zero usage or a safe retry.",
      },
      missing,
    ),
  )
}

///|
fn copy_result_context(
  row : Map[String, Json],
  result : Map[String, Json],
) -> Unit {
  row["resultLine"] = field(result, "line")
  for
    key in [
      "outcome", "httpStatus", "responseState", "responseModel", "responseObject",
    ] {
    row[key] = field(result, key)
  }
}
