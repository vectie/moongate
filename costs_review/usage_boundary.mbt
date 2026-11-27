///|
fn provenance_columns() -> Array[String] {
  [
    "usageEvidenceKind", "usageScenarioName", "usagePricing", "sourceTotal", "importedRows",
    "filteredRows", "partialSource", "sourceCoverageUnknown", "partial",
  ]
}

///|
// Inspect just the CSV header before the shared request parser drops columns.
// The shared parser still validates the complete CSV grammar and row widths.
fn check_csv_header(source : String) -> Result[Unit, String] {
  let headers : Array[String] = []
  let cell = StringBuilder()
  let mut quoted = false
  let mut first = true
  for c in source {
    if first {
      first = false
      if c == '\u{FEFF}' {
        continue
      }
    }
    if c == '"' {
      quoted = !quoted
    } else if !quoted && c == ',' {
      headers.push(cell.to_string().trim().to_owned())
      cell.reset()
    } else if !quoted && (c == '\n' || c == '\r') {
      break
    } else {
      cell.write_char(c)
    }
  }
  headers.push(cell.to_string().trim().to_owned())
  for name in headers {
    if provenance_columns().contains(name) {
      return Err(
        "Costs review cannot safely round-trip CSV provenance column " +
        name +
        "; use the original recorded JSON envelope or raw request CSV",
      )
    }
  }
  Ok(())
}

///|
fn valid_usage_date(value : Json) -> Bool {
  match value {
    Null => true
    Number(seconds, ..) => seconds >= 0.0 && seconds < 253402300800.0
    String("") => true
    String(stamp) => {
      if stamp.length() == 10 {
        return ((@string.FromStr::from_str(stamp) : @time.PlainDate).to_string() ==
        stamp) catch {
          _ => false
        }
      }
      if stamp.length() < 20 ||
        stamp[10] != 'T' ||
        stamp[4] != '-' ||
        stamp[7] != '-' ||
        stamp[13] != ':' ||
        stamp[16] != ':' {
        return false
      }
      let _date_time : @time.PlainDateTime = @string.FromStr::from_str(
        stamp[:19],
      ) catch {
        _ => return false
      }
      let zone_start = if stamp.has_suffix("Z") {
        stamp.length() - 1
      } else {
        let start = stamp.length() - 6
        if start < 19 ||
          (stamp[start] != '+' && stamp[start] != '-') ||
          stamp[start + 3] != ':' {
          return false
        }
        for index in [start + 1, start + 2, start + 4, start + 5] {
          if stamp[index] < '0' || stamp[index] > '9' {
            return false
          }
        }
        let hour = @string.parse_int(stamp[start + 1:start + 3]) catch {
          _ => return false
        }
        let minute = @string.parse_int(stamp[start + 4:start + 6]) catch {
          _ => return false
        }
        if hour > 23 || minute > 59 {
          return false
        }
        start
      }
      if zone_start == 19 {
        return true
      }
      if zone_start < 21 || zone_start > 29 || stamp[19] != '.' {
        return false
      }
      for index in 20..<zone_start {
        if stamp[index] < '0' || stamp[index] > '9' {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn check_usage_rows(rows : Array[Json]) -> Result[Unit, String] {
  if rows.length() > 10000 {
    return Err("Usage file exceeds 10000 rows")
  }
  for index, row in rows {
    guard row is Object(fields) else {
      return Err("Expected usage request objects")
    }
    for name in provenance_columns() {
      if fields.contains(name) {
        return Err(
          "Row-level " +
          name +
          " cannot be discarded; supply supported capture metadata in a JSON data envelope",
        )
      }
    }
    for key in ["createdAt", "created_at", "timestamp", "date"] {
      if fields.get(key) is Some(value) {
        if !valid_usage_date(value) {
          return Err(
            "Usage row " +
            (index + 1).to_string() +
            ": invalid date or timestamp; use YYYY-MM-DD or a complete zoned timestamp",
          )
        }
        break
      }
    }
  }
  Ok(())
}

///|
// Return parser input and a conservative partial flag. Never let normalization
// erase retained evidence before the cost-review boundary has examined it.
fn prepare_usage_input(content : String) -> Result[(String, Bool), String] {
  let source = content.trim().to_owned()
  if !source.has_prefix("{") && !source.has_prefix("[") && source.contains(",") {
    match check_csv_header(source) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let rows = @usage_csv.to_json(source) catch {
      error => return Err("Usage CSV: \{error}")
    }
    guard rows is Array(records) else { return Err("Expected CSV records") }
    match check_usage_rows(records) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    return Ok((rows.stringify(), false))
  }
  let root = @exact_json.parse_with_number_text(source[:]) catch {
    _ => Json::null()
  }
  let mut partial = false
  let records = match root {
    Array(rows) => rows
    Object(fields) =>
      if fields.get("data") is Some(Array(rows)) {
        for name in ["usageEvidenceKind", "usageScenarioName", "usagePricing"] {
          if fields.contains(name) {
            return Err(
              "Hypothetical or scenario-marked usage cannot be reviewed as recorded evidence: " +
              name,
            )
          }
        }
        for name in ["partial", "partialSource", "sourceCoverageUnknown"] {
          if fields.get(name) is Some(value) {
            if value == Json(true) {
              partial = true
            } else if value != Json(false) {
              return Err("Usage envelope " + name + " must be boolean")
            }
          }
        }
        for name in ["sourceTotal", "total", "importedRows", "filteredRows"] {
          if fields.get(name) is Some(value) {
            guard value is Number(count, ..) &&
              count >= 0.0 &&
              count <= 2147483647.0 &&
              count.floor() == count else {
              return Err(
                "Usage envelope " + name + " must be a whole JSON count",
              )
            }
            if count < rows.length().to_double() ||
              (name == "filteredRows" && count != rows.length().to_double()) {
              return Err(
                "Usage envelope " + name + " contradicts its available rows",
              )
            }
            if count > rows.length().to_double() {
              partial = true
            }
          }
        }
        rows
      } else {
        if fields.contains("messages") || fields.contains("data") {
          return Err(
            "Costs review supports a request object or JSON data-array envelope, not other wrappers",
          )
        }
        [root]
      }
    _ => {
      let rows : Array[Json] = []
      for line in source.split("\n") {
        if line.trim().is_empty() {
          continue
        }
        let row = @exact_json.parse_with_number_text(line) catch {
          _ => return Err("Invalid usage JSON or JSONL")
        }
        rows.push(row)
      }
      if rows.is_empty() {
        return Err("Choose a usage file")
      }
      rows
    }
  }
  match check_usage_rows(records) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  Ok((content, partial))
}
