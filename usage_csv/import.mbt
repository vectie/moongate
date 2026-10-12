///|
fn column(name : String) -> String {
  match name.trim().to_owned() {
    "latencyMs" | "latency_ms" => "latencyMs"
    "model" | "modelName" | "model_name" => "model"
    "appType" | "app_type" | "app" => "appType"
    "providerId" | "provider_id" | "provider" => "providerId"
    "requestId" | "request_id" | "id" => "requestId"
    "inputTokens" | "input_tokens" => "inputTokens"
    "outputTokens" | "output_tokens" => "outputTokens"
    "totalTokens" | "total_tokens" => "totalTokens"
    "totalCostUsd"
    | "total_cost_usd"
    | "costUsd"
    | "cost_usd"
    | "estimatedCostUsd" => "totalCostUsd"
    "createdAt" | "created_at" | "timestamp" | "date" => "createdAt"
    _ => ""
  }
}

///|
/// Convert comma-delimited request usage into JSON rows for the Usage Explorer.
/// Retains only recognized columns. Empty cells are omitted, never made zero.
pub fn to_json(source : String) -> Json raise {
  guard @utf8.encode(source).length() <= 4 * 1024 * 1024 else {
    fail("Usage CSV exceeds the 4 MiB limit")
  }
  let rows : Array[Array[String]] = []
  let mut row : Array[String] = []
  let cell = StringBuilder()
  // 0 = unquoted, 1 = quoted, 2 = just closed a quote.
  let mut state = 0
  let mut at_start = true
  let mut skip_lf = false
  let mut first = true
  let mut pending = false
  for c in source {
    if first {
      first = false
      if c == '\u{FEFF}' {
        continue
      }
    }
    if skip_lf {
      skip_lf = false
      if c == '\n' {
        continue
      }
    }
    pending = true
    if state == 1 {
      if c == '"' {
        state = 2
      } else {
        cell.write_char(c)
      }
    } else if c == '"' && state == 2 {
      cell.write_char('"')
      state = 1
    } else if c == ',' || c == '\n' || c == '\r' {
      row.push(cell.to_string())
      cell.reset()
      state = 0
      at_start = true
      if c != ',' {
        rows.push(row)
        guard rows.length() <= 10001 else {
          fail("Usage CSV is limited to 10,000 data rows")
        }
        row = []
        pending = false
        skip_lf = c == '\r'
      }
    } else if state == 2 {
      fail("Unexpected text after a closing CSV quote")
    } else if c == '"' {
      guard at_start else { fail("Quote inside an unquoted CSV cell") }
      state = 1
      at_start = false
    } else {
      cell.write_char(c)
      at_start = false
    }
  }
  guard state != 1 else { fail("Unclosed CSV quote") }
  if pending {
    row.push(cell.to_string())
    rows.push(row)
  }
  guard !rows.is_empty() else { fail("Usage CSV requires a header row") }
  guard rows.length() <= 10001 else {
    fail("Usage CSV is limited to 10,000 data rows")
  }
  let headers = rows[0].map(column)
  let seen : Map[String, Bool] = Map([])
  for key in headers {
    if key != "" {
      guard !seen.contains(key) else {
        fail("Duplicate usage CSV column: \{key}")
      }
      seen[key] = true
    }
  }
  guard seen.contains("model") &&
    (
      seen.contains("inputTokens") ||
      seen.contains("outputTokens") ||
      seen.contains("totalTokens")
    ) else {
    fail(
      "Usage CSV needs model and inputTokens, outputTokens, or totalTokens columns",
    )
  }
  let records : Array[Json] = []
  for i = 1; i < rows.length(); i = i + 1 {
    let cells = rows[i]
    guard cells.length() == headers.length() else {
      fail(
        "CSV data row \{i}: expected \{headers.length()} cells, found \{cells.length()}",
      )
    }
    let record : Map[String, Json] = Map([])
    for j, key in headers {
      if key != "" && !cells[j].is_empty() {
        record[key] = cells[j].to_json()
      }
    }
    records.push(Json::object(record))
  }
  Json::array(records)
}
