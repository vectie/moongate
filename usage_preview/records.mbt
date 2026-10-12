///|
fn moon_transcript_records(content : String) -> Result[Array[Json], String] {
  let source = content.trim().to_owned()
  if source.is_empty() {
    return Err("Choose a transcript file or paste JSON first")
  }
  match moon_parse_json_line(source) {
    Some(Array(records)) => return Ok(records)
    Some(Object(obj)) =>
      match obj.get("messages") {
        Some(Array(records)) => return Ok(records)
        _ => return Ok([Json::object(obj)])
      }
    Some(_) => return Err("Expected message objects, a message array, or JSONL")
    None => ()
  }
  let records = []
  for index, line in source.split("\n").collect() {
    if line.trim().is_empty() {
      continue
    }
    match moon_parse_json_line(line.to_owned()) {
      Some(record) => records.push(record)
      None =>
        return Err(
          "Invalid JSON on line \{index + 1}; no partial transcript was opened",
        )
    }
  }
  Ok(records)
}

///|
