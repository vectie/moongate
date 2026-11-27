///|
fn moon_parse_json_line(line : String) -> Json? {
  let parsed = @json.parse(line) catch { _ => return None }
  Some(parsed)
}

///|
fn moon_json_get(value : Json, key : String) -> Json? {
  match value {
    Object(obj) => obj.get(key)
    _ => None
  }
}

///|
fn parse_fixed_int(text : String, start : Int32, end : Int32) -> Int32? {
  if text.length() < end {
    return None
  }
  try @string.parse_int(text[start:end], radix=10) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}
