///|
/// Stateless exploration of request exports. Does not read or write TrafficStats,
/// discover providers, or calculate prices from the live pricing catalog.
pub fn moongate_preview_usage_file_json(
  content : String,
  source_name? : String = "Pasted usage",
  app? : String = "",
  provider? : String = "",
  model? : String = "",
  start_day? : String = "",
  end_day? : String = "",
) -> Result[Json, String] {
  if @encoding/utf8.encode(content).length() > 4 * 1024 * 1024 {
    return Err("Usage file exceeds the 4 MiB limit")
  }
  for day in [start_day, end_day] {
    if !day.is_empty() && usage_file_day(Json::string(day)) != day {
      return Err("Date filters must be valid YYYY-MM-DD dates")
    }
  }
  if !start_day.is_empty() && !end_day.is_empty() && start_day > end_day {
    return Err("Start date must not be after end date")
  }
  let source = content.trim().to_owned()
  let source = if source_name.has_suffix(".csv") ||
    (!source.has_prefix("{") && !source.has_prefix("[") && source.contains(",")) {
    (@usage_csv.to_json(content) catch {
      error => return Err("Usage CSV: \{error}")
    }).stringify()
  } else {
    source
  }
  let mut source_total = 0
  let mut source_coverage_unknown = false
  let mut merge_scope : String? = None
  let records = match moon_parse_json_line(source) {
    Some(Object(obj)) if obj.get("data") is Some(Array(rows)) => {
      source_coverage_unknown = obj.get("sourceCoverageUnknown") ==
        Some(true.to_json())
      if obj.get("usageMergeScope") is Some(String(scope)) {
        merge_scope = Some(scope)
      }
      let total = usage_file_number(
        usage_file_field(obj, ["sourceTotal", "total"]),
      ).unwrap_or(rows.length().to_double())
      if total > 2147483647.0 || total.floor() != total {
        return Err("Source total must be a whole number up to 2147483647")
      }
      source_total = total.to_int()
      rows
    }
    _ =>
      match moon_transcript_records(source) {
        Ok(records) => records
        Err(error) =>
          return Err(error.replace(old="transcript", new="usage file"))
      }
  }
  if records.length() > 10000 {
    return Err("Usage files are limited to 10,000 rows")
  }
  if source_total < records.length() {
    source_total = records.length()
  }
  let normalized = []
  for index, record in records {
    match usage_file_normalize(record, index) {
      Ok(row) => normalized.push(row)
      Err(error) => return Err("Row \{index + 1}: \{error}; no rows imported")
    }
  }
  let rows = normalized.filter(row => {
    let day = usage_file_text(row, "date")
    (app.is_empty() || usage_file_text(row, "appType") == app) &&
    (provider.is_empty() || usage_file_text(row, "providerId") == provider) &&
    (model.is_empty() || usage_file_text(row, "model") == model) &&
    (start_day.is_empty() || (!day.is_empty() && day >= start_day)) &&
    (end_day.is_empty() || (!day.is_empty() && day <= end_day))
  })
  let summary = usage_file_summary(rows)
  let groups = usage_file_groups(rows, "model")
  let apps = usage_file_groups(rows, "appType")
  let providers = usage_file_groups(rows, "providerId")
  let days = usage_file_groups(rows, "date")
  let partial = source_total > records.length() || source_coverage_unknown
  let report = [
      "MoonGate usage file report (estimated USD)",
      "Source: " + source_name,
      "Available rows: \{records.length()} of \{source_total}; filtered rows: \{rows.length()}",
      if source_coverage_unknown {
        "PARTIAL SOURCE: original coverage is unknown; sourceTotal counts observed merged rows only."
      } else if partial {
        "PARTIAL SOURCE: totals cover available rows only."
      } else {
        "Totals cover the imported rows only."
      },
      "Filters: app=\{app}; provider=\{provider}; model=\{model}; dates=\{start_day}..\{end_day} (inclusive UTC days)",
      usage_file_summary_line("TOTAL", summary),
      "By app:",
      apps
      .map(group => {
        usage_file_summary_line(usage_file_text(group, "key"), group)
      })
      .join("\n"),
      "By provider:",
      providers
      .map(group => {
        usage_file_summary_line(usage_file_text(group, "key"), group)
      })
      .join("\n"),
      "By model:",
      groups
      .map(group => {
        usage_file_summary_line(usage_file_text(group, "key"), group)
      })
      .join("\n"),
      "By UTC day:",
      days
      .map(group => {
        usage_file_summary_line(usage_file_text(group, "key"), group)
      })
      .join("\n"),
      "Unknown costs are excluded from known estimated USD, never treated as zero. No provider contacted or persistent usage changed.",
    ].join("\n") +
    "\n"
  let result : Map[String, Json] = {
    "schema": "moongate.usage-file.v1",
    "sourceName": source_name.to_json(),
    "data": rows.to_json(),
    "total": rows.length().to_json(),
    "page": 0,
    "pageSize": rows.length().to_json(),
    "sourceTotal": source_total.to_json(),
    "importedRows": records.length().to_json(),
    "partial": partial.to_json(),
    "summary": summary,
    "groups": groups.to_json(),
    "byApp": apps.to_json(),
    "byProvider": providers.to_json(),
    "days": days.to_json(),
    "report": report.to_json(),
  }
  if source_coverage_unknown {
    result["sourceCoverageUnknown"] = true.to_json()
  }
  if merge_scope is Some(scope) {
    result["usageMergeScope"] = scope.to_json()
  }
  Ok(Json::object(result))
}

///|
fn usage_file_field(obj : Map[String, Json], names : Array[String]) -> Json {
  for name in names {
    if obj.get(name) is Some(value) {
      return value
    }
  }
  Json::null()
}

///|
fn usage_file_number(value : Json) -> Double? {
  let number = match value {
    Number(value, ..) => value
    String(value) => @string.parse_double(value) catch { _ => return None }
    _ => return None
  }
  if number >= 0.0 && number <= 9007199254740991.0 {
    Some(number)
  } else {
    None
  }
}

///|
fn usage_file_text(row : Json, key : String) -> String {
  match moon_json_get(row, key) {
    Some(String(value)) => value
    _ => ""
  }
}

///|
fn usage_file_day(value : Json) -> String {
  match value {
    Number(seconds, ..) if seconds >= 0.0 && seconds < 253402300800.0 =>
      @time.unix(seconds.to_int64()).to_plain_date().to_string() catch {
        _ => ""
      }
    String(day) =>
      if day.length() == 10 {
        @time.PlainDate::from_str(day).to_string() catch {
          _ => ""
        }
      } else {
        usage_file_timestamp_day(day)
      }
    _ => ""
  }
}

///|
fn usage_file_timestamp_day(value : String) -> String {
  // ISO 8601 timestamps require an explicit zone, unlike ambiguous local dates.
  guard value.length() >= 20 else { return "" }
  let date_time = @time.PlainDateTime::from_str(value[:19]) catch {
    _ => return ""
  }
  let mut offset = 0
  if !value.has_suffix("Z") {
    let start = value.length() - 6
    guard value[start] == '+' || value[start] == '-' else { return "" }
    guard value[start + 3] == ':' else { return "" }
    guard parse_fixed_int(value, start + 1, start + 3) is Some(hour) &&
      hour <= 23 else {
      return ""
    }
    guard parse_fixed_int(value, start + 4, start + 6) is Some(minute) &&
      minute <= 59 else {
      return ""
    }
    offset = (hour * 3600 + minute * 60) *
      (if value[start] == '-' { -1 } else { 1 })
  }
  @time.unix(date_time.to_unix_second() - offset.to_int64())
  .to_plain_date()
  .to_string() catch {
    _ => ""
  }
}

///|
fn usage_file_normalize(record : Json, index : Int) -> Result[Json, String] {
  guard record is Object(obj) else { return Err("Expected a request object") }
  let model = usage_file_field(obj, ["model", "modelName", "model_name"])
  guard model is String(model) && !model.trim().is_empty() else {
    return Err("A nonempty model is required")
  }
  let app = usage_file_field(obj, ["appType", "app_type", "app"])
  let provider = usage_file_field(obj, ["providerId", "provider_id", "provider"])
  for
    names in [
      ["inputTokens", "input_tokens"],
      ["outputTokens", "output_tokens"],
      ["totalTokens", "total_tokens"],
    ] {
    let value = usage_file_field(obj, names)
    if value != Json::null() && usage_file_number(value) is None {
      return Err("Token counts must be nonnegative numbers")
    }
  }
  let input = usage_file_number(
    usage_file_field(obj, ["inputTokens", "input_tokens"]),
  )
  let output = usage_file_number(
    usage_file_field(obj, ["outputTokens", "output_tokens"]),
  )
  let total = usage_file_number(
    usage_file_field(obj, ["totalTokens", "total_tokens"]),
  )
  if input is None && output is None && total is None {
    return Err("Expected inputTokens/outputTokens or totalTokens")
  }
  let total = total.unwrap_or(input.unwrap_or(0.0) + output.unwrap_or(0.0))
  if total.floor() != total ||
    input.unwrap_or(0.0).floor() != input.unwrap_or(0.0) ||
    output.unwrap_or(0.0).floor() != output.unwrap_or(0.0) {
    return Err("Token counts must be whole nonnegative numbers")
  }
  let cost = usage_file_number(
    usage_file_field(obj, [
      "totalCostUsd", "total_cost_usd", "costUsd", "cost_usd", "estimatedCostUsd",
    ]),
  )
  let timestamp = usage_file_field(obj, [
    "createdAt", "created_at", "timestamp", "date",
  ])
  let day = usage_file_day(timestamp)
  let request_id = usage_file_field(obj, ["requestId", "request_id", "id"])
  Ok({
    "requestId": match request_id {
      String(id) => id.to_json()
      _ => "row-\{index + 1}".to_json()
    },
    "appType": match app {
      String(app) => app.to_json()
      _ => "Unknown"
    },
    "providerId": match provider {
      String(provider) => provider.to_json()
      _ => "Unknown"
    },
    "model": model.to_json(),
    "date": day.to_json(),
    "inputTokens": match input {
      Some(n) => n.to_json()
      None => Json::null()
    },
    "outputTokens": match output {
      Some(n) => n.to_json()
      None => Json::null()
    },
    "totalTokens": total.to_json(),
    "totalCostUsd": match cost {
      Some(n) => n.to_json()
      None => Json::null()
    },
  })
}

///|
fn usage_file_summary(rows : Array[Json]) -> Json {
  let mut tokens = 0.0
  let mut cost = 0.0
  let mut missing = 0
  let mut undated = 0
  for row in rows {
    tokens += usage_file_number(moon_json_get(row, "totalTokens").unwrap()).unwrap_or(
      0.0,
    )
    match usage_file_number(moon_json_get(row, "totalCostUsd").unwrap()) {
      Some(value) => cost += value
      None => missing += 1
    }
    if usage_file_text(row, "date").is_empty() {
      undated += 1
    }
  }
  {
    "requests": rows.length().to_json(),
    "tokens": tokens.to_json(),
    "knownEstimatedUsd": cost.to_json(),
    "missingCostCount": missing.to_json(),
    "undatedCount": undated.to_json(),
  }
}

///|
fn usage_file_groups(rows : Array[Json], field : String) -> Array[Json] {
  let buckets : Map[String, Array[Json]] = Map([])
  for row in rows {
    let value = usage_file_text(row, field)
    let key = if value.is_empty() { "Unknown" } else { value }
    match buckets.get(key) {
      Some(bucket) => bucket.push(row)
      None => buckets.set(key, [row])
    }
  }
  let keys = buckets.keys().collect()
  keys.sort()
  keys.map(key => {
    guard usage_file_summary(buckets.get(key).unwrap()) is Object(summary) else {
      abort("summary")
    }
    summary.set("key", key.to_json())
    Json::object(summary)
  })
}

///|
fn usage_file_summary_line(label : String, summary : Json) -> String {
  let get = key => moon_json_get(summary, key).unwrap().stringify()
  "\{label}: \{get("requests")} requests | \{get("tokens")} tokens | USD \{get("knownEstimatedUsd")} known estimate | \{get("missingCostCount")} missing costs | \{get("undatedCount")} undated"
}
