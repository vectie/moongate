///|
/// Export selected redacted request observations as spreadsheet-ready CSV.
/// Empty numeric cells mean unknown, never zero. SSL is a subset of connect.
pub fn export_capture_csv(
  content : String,
  request_method? : String = "",
  status? : String = "",
  origin? : String = "",
  entry? : Int = 0,
) -> Result[String, String] {
  match
    inspect_capture_json(content, request_method~, status~, origin~, entry~) {
    Err(error) => Err(error)
    Ok(result) => {
      guard field(result, "entries") is Array(rows) else {
        return Err("Expected normalized HAR entries")
      }
      let columns = [
        "entry", "method", "origin", "status", "outcome", "startedAtUnixMs", "startOffsetMs",
        "elapsedMs", "blockedMs", "dnsMs", "connectMs", "sendMs", "waitMs", "receiveMs",
        "sslMs", "longestRecordedPhase",
      ]
      let lines = [columns.join(",")]
      for row in rows {
        let cells : Array[String] = []
        for
          key in [
            "entry", "method", "origin", "status", "outcome", "startedAtUnixMs",
            "startOffsetMs", "elapsedMs",
          ] {
          cells.push(csv_cell(field(row, key)))
        }
        for
          phase in [
            "blocked", "dns", "connect", "send", "wait", "receive", "ssl",
          ] {
          cells.push(csv_cell(field(field(row, "timingsMs"), phase)))
        }
        cells.push(csv_cell(field(row, "longestRecordedPhase")))
        lines.push(cells.join(","))
      }
      Ok(lines.join("\r\n") + "\r\n")
    }
  }
}

///|
fn csv_cell(value : Json) -> String {
  match value {
    Null => ""
    String(s) => "\"" + s.replace_all(old="\"", new="\"\"") + "\""
    _ => value.stringify()
  }
}
