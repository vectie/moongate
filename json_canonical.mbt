///|
fn canonicalize_json_value(value : Json) -> Json {
  match value {
    Array(values) =>
      Json::array(values.map(fn(value) { canonicalize_json_value(value) }))
    Object(obj) => {
      let keys = obj.keys().collect()
      keys.sort_by(ascii_lex_compare)
      let sorted : Map[String, Json] = Map([])
      for key in keys {
        match obj.get(key) {
          Some(value) => sorted[key] = canonicalize_json_value(value)
          None => ()
        }
      }
      Json::object(sorted)
    }
    _ => value
  }
}

///|
fn canonical_json_string(value : Json) -> String {
  canonicalize_json_value(value).stringify()
}

///|
fn canonicalize_json_string_if_parseable(value : String) -> String {
  let trimmed = value.trim()
  if trimmed.is_empty() {
    return value
  }
  let parsed = @json.parse(trimmed) catch { _ => return value }
  canonical_json_string(parsed)
}

///|
fn canonicalize_tool_arguments_string(value : String) -> String {
  if value.trim().is_empty() {
    return "{}"
  }
  canonicalize_json_string_if_parseable(value)
}

///|
fn canonicalize_tool_arguments(value : Json?) -> String {
  match value {
    Some(String(value)) => canonicalize_tool_arguments_string(value)
    Some(value) => canonical_json_string(value)
    None => "{}"
  }
}

///|
fn short_value_hash(value : Json?) -> String {
  match value {
    None => "absent"
    Some(value) =>
      short_sha256_hex(@encoding/utf8.encode(canonical_json_string(value)))
  }
}

///|
fn short_sha256_hex(bytes : Bytes) -> String {
  let digest = @crypto.sha256(bytes)
  let builder = StringBuilder::new()
  for i in 0..<8 {
    let value = digest[i].to_int()
    builder.write_char(moon_json_hex_digit(value / 16))
    builder.write_char(moon_json_hex_digit(value % 16))
  }
  builder.to_string()
}

///|
fn moon_json_hex_digit(value : Int32) -> Char {
  if value < 10 {
    ('0'.to_int() + value).unsafe_to_char()
  } else {
    ('a'.to_int() + value - 10).unsafe_to_char()
  }
}

///|
fn prompt_cache_trace_message(
  app_type : String,
  provider_id : String,
  endpoint : String,
  api_format : String?,
  body : Json,
  session_client_provided : Bool,
) -> String {
  let prompt_cache_key = match body {
    Object(obj) =>
      match obj.get("prompt_cache_key") {
        Some(String(key)) => "present(len=\{key.length()})"
        _ => "absent"
      }
    _ => "absent"
  }
  let store = json_field_for_cache_trace(body, "store")
  let stream = json_field_for_cache_trace(body, "stream")
  let format = api_format.unwrap_or("native")
  "[CacheTrace] app=\{app_type}, provider=\{provider_id}, endpoint=\{endpoint}, api_format=\{format}, session_client_provided=\{session_client_provided}, prompt_cache_key=\{prompt_cache_key}, store=\{store}, stream=\{stream}, instructions_hash=\{short_value_hash(json_field(body, "instructions"))}, tools_hash=\{short_value_hash(json_field(body, "tools"))}, input_hash=\{short_value_hash(json_field(body, "input"))}, include_hash=\{short_value_hash(json_field(body, "include"))}, body_hash=\{short_value_hash(Some(body))}"
}

///|
fn json_field(body : Json, key : String) -> Json? {
  match body {
    Object(obj) => obj.get(key)
    _ => None
  }
}

///|
fn json_field_for_cache_trace(body : Json, key : String) -> String {
  match json_field(body, key) {
    Some(value) => json_value_for_cache_trace(value)
    None => "absent"
  }
}

///|
fn json_value_for_cache_trace(value : Json) -> String {
  match value {
    String(value) => value
    Array(values) => "array(len=\{values.length()})"
    Object(values) => "object(len=\{values.keys().count()})"
    _ => value.stringify()
  }
}
