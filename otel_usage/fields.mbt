///|
fn field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn attributes(value : Json) -> Map[String, Json] raise {
  if value == Json::null() {
    return Map([])
  }
  guard value is Array(items) else { fail("attributes must be an array") }
  let result : Map[String, Json] = Map([])
  for item in items {
    guard item is Object(_) && field(item, "key") is String(key) else {
      fail("Each attribute needs a string key")
    }
    if result.contains(key) {
      fail("Duplicate attribute key")
    }
    result[key] = field(item, "value")
  }
  result
}

///|
fn string_attribute(attrs : Map[String, Json], key : String) -> String? raise {
  match attrs.get(key) {
    None => None
    Some(Object(value)) if value.length() == 1 &&
      value.get("stringValue") is Some(String(text)) =>
      if text.trim().is_empty() {
        None
      } else {
        Some(text)
      }
    _ => fail("Recognized string attribute must contain only stringValue")
  }
}

///|
fn count_attribute(attrs : Map[String, Json], key : String) -> Double? raise {
  guard attrs.get(key) is Some(value) else { return None }
  guard value is Object(value) &&
    value.length() == 1 &&
    value.get("intValue") is Some(value) else {
    fail("Token attributes must contain only intValue")
  }
  let text = match value {
    String(text) => {
      if text.is_empty() || !text.iter().all(c => c >= '0' && c <= '9') {
        fail("Token intValue strings must be nonnegative decimal digits")
      }
      text
    }
    Number(_, repr=Some(text)) => text
    _ => fail("Token intValue must be a whole nonnegative integer")
  }
  guard @exact_json.exact_count(text) is Some(count) else {
    fail("Token intValue must be an exact whole count within 9007199254740991")
  }
  Some(count)
}

///|
fn span_id(value : Json, length : Int) -> String raise {
  guard value is String(text) &&
    text.length() == length &&
    text
    .iter()
    .all(c => {
      (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
    }) &&
    text.iter().any(c => c != '0') else {
    fail(
      "Candidate span needs nonzero 32-digit traceId and 16-digit spanId hex strings",
    )
  }
  text.to_lower()
}

///|
fn timestamp(value : Json) -> UInt64? raise {
  if value == Json::null() {
    return None
  }
  guard value is String(text) &&
    !text.is_empty() &&
    text.iter().all(c => c >= '0' && c <= '9') else {
    fail("Span timestamps must be decimal uint64 nanosecond strings")
  }
  let value = @string.parse_uint64(text) catch {
    _ => fail("Span timestamp exceeds uint64 range")
  }
  if value == 0UL {
    None
  } else {
    Some(value)
  }
}

///|
fn count_json(value : Double?) -> Json {
  match value {
    Some(value) => value.to_json()
    None => Json::null()
  }
}

///|
fn text_json(value : String?) -> Json {
  match value {
    Some(value) => value.to_json()
    None => Json::null()
  }
}
