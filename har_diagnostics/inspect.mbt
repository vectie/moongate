///|
/// Inspect a saved HAR 1.2 capture without replay, provider calls, or usage mutations.
/// Output keeps original one-based entry numbers and an explicit metadata allowlist.
pub fn inspect_capture_json(
  content : String,
  request_method? : String = "",
  status? : String = "",
  origin? : String = "",
  entry? : Int = 0,
) -> Result[Json, String] {
  try
    inspect_capture(content, request_method~, status~, origin~, entry~)
  catch {
    error => Err(error.to_string())
  } noraise {
    result => Ok(result)
  }
}

///|
fn inspect_capture(
  content : String,
  request_method~ : String,
  status~ : String,
  origin~ : String,
  entry~ : Int,
) -> Json raise {
  if @encoding/utf8.encode(content).length() > 4 * 1024 * 1024 {
    fail("HAR file exceeds 4 MiB")
  }
  if entry < 0 {
    fail("Entry filter must be zero (all) or a positive original entry number")
  }
  let request_method = request_method.to_upper()
  if !request_method.is_empty() &&
    ![
      "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS", "TRACE", "CONNECT",
    ].contains(request_method) {
    fail("Unsupported method filter")
  }
  let status = status.to_lower()
  if !["", "errors", "unknown", "0", "1xx", "2xx", "3xx", "4xx", "5xx"].contains(
      status,
    ) {
    let n = @string.parse_int(status) catch {
      _ =>
        fail("Status filter must be errors, unknown, 0, 1xx..5xx, or 100..599")
    }
    if n < 100 || n > 599 || n.to_string() != status {
      fail("Status filter must be errors, unknown, 0, 1xx..5xx, or 100..599")
    }
  }
  let origin_filter = if origin.is_empty() {
    ""
  } else {
    let normalized = origin_of(origin)
    // Require an origin, not a URL path whose discarded suffix changes its meaning.
    let authority = origin.split("://").collect()[1].to_owned()
    if authority.contains("/") ||
      authority.contains("?") ||
      authority.contains("#") {
      fail("Origin filter must contain only scheme, host and optional port")
    }
    normalized
  }
  let root = @json.parse(content) catch { _ => fail("Expected HAR 1.2 JSON") }
  let log = field(root, "log")
  if text(log, "version") != "1.2" {
    fail("Only HAR 1.2 is supported")
  }
  guard field(log, "entries") is Array(entries) else {
    fail("HAR log.entries must be an array")
  }
  if entries.length() > 2000 {
    fail("HAR diagnostics is limited to 2,000 entries")
  }
  if entry > entries.length() {
    fail("Entry filter is outside the original capture")
  }
  let normalized : Array[Json] = []
  let mut first_start : Double? = None
  for i, raw in entries {
    let row = normalize_entry(raw, i + 1)
    if number(field(row, "startedAtUnixMs")) is Some(start) {
      first_start = Some(
        match first_start {
          Some(previous) => if start < previous { start } else { previous }
          None => start
        },
      )
    }
    normalized.push(row)
  }
  let selected : Array[Json] = []
  for row in normalized {
    if (entry == 0 || field(row, "entry") == entry.to_json()) &&
      (request_method.is_empty() || text(row, "method") == request_method) &&
      (origin_filter.is_empty() || text(row, "origin") == origin_filter) &&
      status_matches(field(row, "status"), status) {
      guard row is Object(obj) else { fail("Expected normalized entry") }
      obj["startOffsetMs"] = match
        (first_start, number(field(row, "startedAtUnixMs"))) {
        (Some(first), Some(start)) => (start - first).to_json()
        _ => Json::null()
      }
      selected.push(Json::object(obj))
    }
  }
  let summary = summarize(selected)
  let by_origin = groups(selected, "origin")
  let by_outcome = groups(selected, "outcome")
  let filters : Json = {
    "method": request_method.to_json(),
    "status": status.to_json(),
    "origin": origin_filter.to_json(),
    "entry": if entry == 0 {
      Json::null()
    } else {
      entry.to_json()
    },
  }
  let caveats = [
    "Recorded HAR observations only; the capture may be partial. No request was sent and no usage or configuration was changed.",
    "HTTP 2xx is a protocol success, not proof of model correctness or stream completion. Status 0 means no recorded HTTP response; it does not prove a timeout or cancellation. Missing status stays unknown.",
    "Times are captured milliseconds, not live benchmarks or gateway-only overhead. Missing/null/-1 timing values stay unknown; explicit zero is recorded. SSL is a subset of connect and is not added again.",
    "Elapsed percentiles use nearest rank over known samples only: sorted position ceil(p * sampleCount), one-based. Empty sample sets have null percentiles.",
    "Entry numbers refer to the original capture order, including after filtering. Start offsets use the earliest readable timestamp in the whole capture, not the first filtered row. Capture order need not be chronological.",
    "Only method, captured origin, status, normalized start, elapsed and timing phases are retained. Paths, queries, fragments, headers, bodies, cookies, titles and raw error text are omitted. Hostnames can still be private; review before sharing.",
  ]
  let lines = [
    "MoonGate offline HAR request diagnostics",
    "Capture entries: \{entries.length()}; selected: \{selected.length()}",
    "Filters: " + filters.stringify(),
    "SUMMARY: " + summary.stringify(),
    "By captured origin:",
  ]
  for group in by_origin {
    lines.push(group.stringify())
  }
  lines.push("By HTTP outcome:")
  for group in by_outcome {
    lines.push(group.stringify())
  }
  lines.push("Selected entries (original capture numbers; milliseconds):")
  for row in selected {
    lines.push(row.stringify())
  }
  for caveat in caveats {
    lines.push("- " + caveat)
  }
  let result : Json = {
    "schema": "moongate.har-diagnostics.v1",
    "timingUnit": "milliseconds",
    "percentileMethod": "nearest-rank",
    "captureEntries": entries.length().to_json(),
    "selectedEntries": selected.length().to_json(),
    "captureStartUnixMs": optional_number(first_start),
    "coverage": "capture-only; completeness unverified",
    "filters": filters,
    "summary": summary,
    "byOrigin": by_origin.to_json(),
    "byOutcome": by_outcome.to_json(),
    "entries": selected.to_json(),
    "caveats": caveats.to_json(),
    "report": (lines.join("\n") + "\n").to_json(),
  }
  if @encoding/utf8.encode(result.stringify(indent=2)).length() >
    4 * 1024 * 1024 - 1 {
    fail(
      "Diagnostic output exceeds 4 MiB; filter the capture or use a smaller file",
    )
  }
  result
}

///|
fn status_matches(status : Json, filter : String) -> Bool {
  if filter.is_empty() {
    return true
  }
  if filter == "unknown" {
    return status == Json::null()
  }
  guard number(status) is Some(n) else { return false }
  if filter == "errors" {
    return n >= 400.0
  }
  if filter.has_suffix("xx") {
    return (n.to_int() / 100).to_string() + "xx" == filter
  }
  n.to_int().to_string() == filter
}

///|
fn summarize(rows : Array[Json]) -> Json {
  let samples : Array[Double] = []
  let mut unknown_status = 0
  let mut no_response = 0
  let mut http_errors = 0
  let mut missing_start = 0
  for row in rows {
    if number(field(row, "elapsedMs")) is Some(ms) {
      samples.push(ms)
    }
    if field(row, "status") == Json::null() {
      unknown_status += 1
    }
    if field(row, "status") == (0).to_json() {
      no_response += 1
    }
    if number(field(row, "status")) is Some(n) && n >= 400.0 {
      http_errors += 1
    }
    if field(row, "startedAtUnixMs") == Json::null() {
      missing_start += 1
    }
  }
  samples.sort()
  let percentile = (p : Int) => {
    if samples.is_empty() {
      Json::null()
    } else {
      samples[(samples.length() * p + 99) / 100 - 1].to_json()
    }
  }
  {
    "entries": rows.length().to_json(),
    "httpErrorCount": http_errors.to_json(),
    "noHttpResponseCount": no_response.to_json(),
    "unknownStatusCount": unknown_status.to_json(),
    "missingStartCount": missing_start.to_json(),
    "elapsedSampleCount": samples.length().to_json(),
    "missingElapsedCount": (rows.length() - samples.length()).to_json(),
    "p50ElapsedMs": percentile(50),
    "p95ElapsedMs": percentile(95),
    "maxElapsedMs": percentile(100),
  }
}

///|
fn groups(rows : Array[Json], key : String) -> Array[Json] {
  let buckets : Map[String, Array[Json]] = Map([])
  for row in rows {
    let name = text(row, key)
    match buckets.get(name) {
      Some(bucket) => bucket.push(row)
      None => buckets[name] = [row]
    }
  }
  let names = buckets.keys().collect()
  names.sort()
  names.map(name => {
    guard summarize(buckets[name]) is Object(summary) else {
      abort("Expected summary")
    }
    summary["key"] = name.to_json()
    Json::object(summary)
  })
}
