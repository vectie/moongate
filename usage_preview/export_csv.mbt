///|
/// Spreadsheet-oriented export of the existing offline usage preview. Text cells
/// are apostrophe-prefixed and CSV-quoted to keep labels inert in spreadsheets.
pub fn export_usage_csv(
  content : String,
  source_name? : String = "Pasted usage",
  view? : String = "requests",
  app? : String = "",
  provider? : String = "",
  model? : String = "",
  start_day? : String = "",
  end_day? : String = "",
) -> Result[String, String] {
  if !["requests", "summary", "model", "provider", "app", "day"].contains(view) {
    return Err("View must be requests, summary, model, provider, app or day")
  }
  let preview = match
    moongate_preview_usage_file_json(
      content,
      source_name~,
      app~,
      provider~,
      model~,
      start_day~,
      end_day~,
    ) {
    Ok(Object(value)) => value
    Err(error) => return Err(error)
    _ => return Err("Expected usage preview")
  }
  let provenance = [
    preview["sourceTotal"],
    preview["importedRows"],
    preview["total"],
    preview["partial"],
    preview.get("sourceCoverageUnknown").unwrap_or(false.to_json()),
  ]
  let columns = if view == "requests" {
    [
      "requestId", "appType", "providerId", "model", "date", "inputTokens", "outputTokens",
      "totalTokens", "totalCostUsd",
    ]
  } else {
    [
      "key", "requests", "tokens", "knownEstimatedUsd", "missingCostCount", "undatedCount",
    ]
  }
  let rows = if view == "summary" {
    [preview["summary"]]
  } else {
    let field = match view {
      "requests" => "data"
      "model" => "groups"
      "provider" => "byProvider"
      "app" => "byApp"
      _ => "days"
    }
    match preview[field] {
      Array(rows) => rows
      _ => return Err("Expected preview rows")
    }
  }
  let headers = columns.copy()
  for
    key in [
      "sourceTotal", "importedRows", "filteredRows", "partialSource", "sourceCoverageUnknown",
    ] {
    headers.push(key)
  }
  let lines = [headers.join(",")]
  for row in rows {
    for key in ["totalTokens", "tokens"] {
      if moon_json_get(row, key) is Some(Number(value, ..)) &&
        value > 9007199254740991.0 {
        return Err(
          "Exported token totals exceed the exact safe integer range; narrow the filter",
        )
      }
    }
    let cells = columns.map(key => {
      let value = if view == "summary" && key == "key" {
        "TOTAL".to_json()
      } else {
        moon_json_get(row, key).unwrap_or(Json::null())
      }
      usage_export_cell(value)
    })
    for value in provenance {
      cells.push(usage_export_cell(value))
    }
    lines.push(cells.join(","))
  }
  let output = lines.join("\r\n") + "\r\n"
  if @encoding/utf8.encode(output).length() > 8 * 1024 * 1024 {
    return Err("CSV output exceeds 8 MiB; use a narrower filter")
  }
  Ok(output)
}

///|
fn usage_export_cell(value : Json) -> String {
  match value {
    Null => ""
    String("") => ""
    String(text) => "\"'" + text.replace_all(old="\"", new="\"\"") + "\""
    _ => value.stringify()
  }
}
