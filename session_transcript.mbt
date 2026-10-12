///|
/// Read an exported conversation without writing client history or contacting a
/// provider. JSON may be a message array, a {messages: [...]} object, or JSONL.
pub fn moongate_preview_transcript_json(
  content : String,
  format? : String = "auto",
  source_name? : String = "Pasted transcript",
) -> Result[Json, String] {
  if @encoding/utf8.encode(content).length() > 4 * 1024 * 1024 {
    return Err("Transcript exceeds the 4 MiB limit")
  }
  let records = match moon_transcript_records(content) {
    Ok(records) => records
    Err(error) => return Err(error)
  }
  let detected = if format == "auto" {
    moon_transcript_detect_format(records)
  } else {
    format
  }
  if detected != "codex" && detected != "claude" && detected != "json" {
    return Err("Choose auto, codex, claude, or json")
  }
  let lines = records.map(record => record.stringify()).join("\n")
  let messages = match detected {
    "codex" => moon_load_codex_messages(lines)
    "claude" => moon_load_claude_messages(lines)
    _ => moon_load_generic_json_messages(lines)
  }
  if messages.is_empty() {
    return Err(
      "No readable messages found. Choose the matching format or use role/content JSON.",
    )
  }
  Ok({
    "schema": "moongate.transcript.v1",
    "format": detected.to_json(),
    "sourceName": source_name.to_json(),
    "recordCount": records.length().to_json(),
    "messageCount": messages.length().to_json(),
    "skippedRecords": (records.length() - messages.length()).to_json(),
    "messages": Json::array(messages.map(message => message.to_json())),
  })
}

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
fn moon_transcript_detect_format(records : Array[Json]) -> String {
  for record in records {
    if moon_json_get(record, "type") == Some(Json::string("response_item")) {
      return "codex"
    }
  }
  for record in records {
    if moon_json_get(record, "message") is Some(Object(message)) &&
      message.get("role") is Some(String(_)) {
      return "claude"
    }
  }
  "json"
}

///|
async fn SessionService::handle_preview_transcript(
  self : SessionService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard body is Some(Object(obj)) && obj.get("content") is Some(String(content)) else {
    write_usage_bad_request(w, "Missing transcript content")
    return
  }
  let format = json_string_from_map(obj, "format").unwrap_or("auto")
  let source_name = json_string_from_map(obj, "sourceName").unwrap_or(
    "Pasted transcript",
  )
  match moongate_preview_transcript_json(content, format~, source_name~) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}
