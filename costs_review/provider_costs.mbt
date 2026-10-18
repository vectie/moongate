///|
priv struct ReportedDay {
  day : String
  results : Int32
  missing : Int32
  known : Int32
  total : Double
}

///|
fn field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn text(value : Json, key : String) -> String {
  match field(value, key) {
    String(value) => value
    _ => ""
  }
}

///|
fn valid_amount(value : Double) -> Bool {
  value >= -1000000000000.0 && value <= 1000000000000.0
}

///|
fn cost_page(
  content : String,
  project : String,
  line_item : String,
) -> Result[(Array[ReportedDay], Bool, Int32), String] {
  let root = @exact_json.parse_with_number_text(content[:]) catch {
    _ => return Err("Costs file must be one saved JSON page")
  }
  guard text(root, "object") == "page" &&
    field(root, "data") is Array(buckets) &&
    (
      field(root, "has_more") == Json(false) ||
      field(root, "has_more") == Json(true)
    ) else {
    return Err("Expected Costs page object, data array and boolean has_more")
  }
  let has_more = field(root, "has_more") == Json(true)
  if buckets.length() > 180 {
    return Err("Costs page exceeds 180 buckets")
  }
  let days : Array[ReportedDay] = []
  let seen : Map[String, Bool] = Map([])
  let mut source_results = 0
  for bucket in buckets {
    guard text(bucket, "object") == "bucket" &&
      field(bucket, "start_time") is Number(start, ..) &&
      field(bucket, "end_time") is Number(end, ..) &&
      field(bucket, "results") is Array(results) else {
      return Err("Expected Costs bucket with numeric bounds and results array")
    }
    // Local usage is normalized to UTC calendar days. Do not silently compare
    // it against clipped or non-midnight provider intervals.
    guard start >= 0.0 &&
      start <= 253402214400.0 &&
      start.floor() == start &&
      start.to_int64() % 86400L == 0L &&
      end == start + 86400.0 else {
      return Err(
        "Costs buckets must be full UTC days: midnight start, exclusive end 86400 seconds later",
      )
    }
    let day = @time.unix(start.to_int64()).to_plain_date().to_string() catch {
        _ => return Err("Unsupported Costs date")
      }
    if seen.contains(day) {
      return Err("Duplicate or overlapping Costs bucket; no costs added")
    }
    seen[day] = true
    source_results += results.length()
    if source_results > 10000 {
      return Err("Costs file exceeds 10000 result records")
    }
    let mut selected = 0
    let mut missing = 0
    let mut known = 0
    let mut total = 0.0
    for result in results {
      guard text(result, "object") == "organization.costs.result" else {
        return Err("Expected organization.costs.result, not token usage")
      }
      for (key, wanted) in [("project_id", project), ("line_item", line_item)] {
        if !wanted.is_empty() {
          guard field(result, key) is String(label) && !label.is_empty() else {
            return Err(
              "Cannot filter Costs by " +
              key +
              ": a result has no explicit grouping label",
            )
          }
        }
      }
      if (!project.is_empty() && text(result, "project_id") != project) ||
        (!line_item.is_empty() && text(result, "line_item") != line_item) {
        continue
      }
      selected += 1
      let amount = field(result, "amount")
      if amount == Json::null() {
        missing += 1
        continue
      }
      guard amount is Object(_) else {
        return Err("Costs amount must be an object or null")
      }
      guard text(amount, "currency") == "usd" else {
        return Err(
          "Selected Costs amounts must explicitly use usd; no currency conversion",
        )
      }
      if field(amount, "value") == Json::null() {
        missing += 1
        continue
      }
      guard field(amount, "value") is Number(value, ..) && valid_amount(value) else {
        return Err(
          "Costs amount must be a finite JSON number within +/- 1e12 USD",
        )
      }
      total += value
      if !valid_amount(total) {
        return Err("Costs total exceeds supported range")
      }
      known += 1
    }
    days.push({ day, results: selected, missing, known, total, })
  }
  Ok((days, has_more, source_results))
}
