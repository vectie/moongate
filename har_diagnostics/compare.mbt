///|
/// Compare captured distributions, never pair requests or infer capture completeness.
pub fn compare_captures_json(
  baseline : String,
  candidate : String,
  request_method? : String = "",
  origin? : String = "",
) -> Result[Json, String] {
  try compare_captures(baseline, candidate, request_method~, origin~) catch {
    error => Err(error.to_string())
  } noraise {
    result => Ok(result)
  }
}

///|
fn compare_buckets(rows : Array[Json]) -> Map[String, Array[Json]] {
  let buckets : Map[String, Array[Json]] = Map([])
  for row in rows {
    let key = text(row, "origin") + "\n" + text(row, "method")
    match buckets.get(key) {
      Some(bucket) => bucket.push(row)
      None => buckets[key] = [row]
    }
  }
  buckets
}

///|
fn difference(baseline : Json, candidate : Json) -> Json {
  match (number(baseline), number(candidate)) {
    (Some(a), Some(b)) => (b - a).to_json()
    _ => Json::null()
  }
}

///|
fn compare_summary(rows : Array[Json]) -> Json {
  guard summarize(rows) is Object(result) else { abort("expected summary") }
  let known = rows
    .filter(row => {
      match number(field(row, "status")) {
        Some(n) => n >= 100.0
        None => false
      }
    })
    .length()
  result["recordedHttpResponseCount"] = known.to_json()
  result["httpErrorPercent"] = if known == 0 {
    Json::null()
  } else {
    (number(result["httpErrorCount"]).unwrap() * 100.0 / known.to_double()).to_json()
  }
  Json::object(result)
}

///|
fn summary_delta(a : Json, b : Json) -> Json {
  let result : Map[String, Json] = Map([])
  for
    key in [
      "entries", "httpErrorCount", "noHttpResponseCount", "unknownStatusCount", "elapsedSampleCount",
      "missingElapsedCount", "recordedHttpResponseCount", "p50ElapsedMs", "p95ElapsedMs",
      "maxElapsedMs",
    ] {
    result[key] = difference(field(a, key), field(b, key))
  }
  result["httpErrorPercentagePoints"] = difference(
    field(a, "httpErrorPercent"),
    field(b, "httpErrorPercent"),
  )
  Json::object(result)
}

///|
fn compare_captures(
  baseline : String,
  candidate : String,
  request_method~ : String,
  origin~ : String,
) -> Json raise {
  let a = inspect_capture(
    baseline,
    request_method~,
    origin~,
    status="",
    entry=0,
  )
  let b = inspect_capture(
    candidate,
    request_method~,
    origin~,
    status="",
    entry=0,
  )
  guard field(a, "entries") is Array(a_rows) &&
    field(b, "entries") is Array(b_rows) else {
    fail("expected normalized capture")
  }
  let a_buckets = compare_buckets(a_rows)
  let b_buckets = compare_buckets(b_rows)
  let keys = a_buckets.keys().collect()
  for key in b_buckets.keys() {
    if !a_buckets.contains(key) {
      keys.push(key)
    }
  }
  keys.sort_by((a, b) => a.lexical_compare(b))
  let groups : Array[Json] = []
  let mut matched = 0
  let mut baseline_only = 0
  let mut candidate_only = 0
  for key in keys {
    let ar = a_buckets.get(key).unwrap_or([])
    let br = b_buckets.get(key).unwrap_or([])
    let presence = if ar.is_empty() {
      candidate_only += 1
      "candidate_only"
    } else if br.is_empty() {
      baseline_only += 1
      "baseline_only"
    } else {
      matched += 1
      "both"
    }
    let asummary = if ar.is_empty() {
      Json::null()
    } else {
      compare_summary(ar)
    }
    let bsummary = if br.is_empty() {
      Json::null()
    } else {
      compare_summary(br)
    }
    let parts = key.split("\n").collect()
    groups.push({
      "origin": parts[0].to_owned().to_json(),
      "method": parts[1].to_owned().to_json(),
      "presence": presence.to_json(),
      "baseline": asummary,
      "candidate": bsummary,
      "candidateMinusBaseline": summary_delta(asummary, bsummary),
    })
  }
  let caveats = [
    "Captured origin and method group distributions only; requests are not paired. Matching groups do not establish equal paths, payloads, workloads or capture durations.",
    "Each capture may be partial. An absent group is not zero traffic: its summary and deltas are null. Counts describe only the supplied observations, not request rates.",
    "Elapsed milliseconds use known samples only; null, absent and -1 remain missing, while explicit zero is retained. p50/p95 use nearest rank. No timing delta exists without a known value on both sides.",
    "HTTP error percentage uses only recorded HTTP statuses 100..599. Missing status and status 0 are counted separately and excluded from its denominator. The percentage-point delta is not a relative percent change.",
    "These differences do not establish a performance regression or its cause. HTTP success does not establish complete model output. No requests were sent and no usage or configuration was changed.",
    "Paths, queries, fragments, headers, bodies, cookies and raw errors are omitted. Captured hostnames can remain private. Review before sharing.",
  ]
  let lines = [
    "MoonGate offline HAR capture comparison",
    "Matched groups: \{matched}; baseline only: \{baseline_only}; candidate only: \{candidate_only}",
    "Deltas are candidate minus baseline; timing unit is milliseconds.",
  ]
  for group in groups {
    lines.push(group.stringify())
  }
  for caveat in caveats {
    lines.push("- " + caveat)
  }
  let result : Json = {
    "schema": "moongate.har-comparison.v1",
    "timingUnit": "milliseconds",
    "percentileMethod": "nearest-rank",
    "coverage": "two supplied captures; completeness and workload comparability unverified",
    "filters": field(a, "filters"),
    "baselineCaptureEntries": field(a, "captureEntries"),
    "candidateCaptureEntries": field(b, "captureEntries"),
    "baselineSelectedEntries": a_rows.length().to_json(),
    "candidateSelectedEntries": b_rows.length().to_json(),
    "matchedGroupCount": matched.to_json(),
    "baselineOnlyGroupCount": baseline_only.to_json(),
    "candidateOnlyGroupCount": candidate_only.to_json(),
    "groups": groups.to_json(),
    "caveats": caveats.to_json(),
    "report": (lines.join("\n") + "\n").to_json(),
  }
  if @encoding/utf8.encode(result.stringify(indent=2)).length() >
    4 * 1024 * 1024 - 1 {
    fail("Comparison output exceeds 4 MiB; filter or split the captures")
  }
  result
}
