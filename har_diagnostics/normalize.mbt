///|
fn field(value : Json, key : String) -> Json {
  match value {
    Object(obj) => obj.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn text(value : Json, key : String) -> String {
  match field(value, key) {
    String(s) => s
    _ => ""
  }
}

///|
fn number(value : Json) -> Double? {
  match value {
    Number(n, ..) => Some(n)
    _ => None
  }
}

///|
fn duration(value : Json, label : String) -> Json raise {
  match value {
    Null => Json::null()
    Number(n, ..) if n == -1.0 => Json::null()
    Number(n, ..) if n >= 0.0 && n <= 9007199254740991.0 => n.to_json()
    _ =>
      fail(
        label +
        ": expected milliseconds as a finite nonnegative JSON number, -1, null, or absent",
      )
  }
}

///|
fn origin_of(url : String) -> String raise {
  // Extract an inspectable origin only, never a request target or a replay URL.
  for c in url {
    if c <= ' ' || c == '\u007f' || c == '\\' {
      fail("expected an HTTP(S) URL without whitespace or backslashes")
    }
  }
  let (scheme, rest) = match url {
    [.. "https://", .. rest] => ("https", rest)
    [.. "http://", .. rest] => ("http", rest)
    _ => fail("expected an absolute http:// or https:// URL")
  }
  let authority = rest.split("/").collect()[0].split("?").collect()[0]
    .split("#")
    .collect()[0]
    .to_owned()
    .to_lower()
  if authority.is_empty() || authority.length() > 512 {
    fail("missing or oversized captured host")
  }
  // ASCII DNS/IPv4 and bracketed IPv6 authority labels; no userinfo or encoded host.
  for c in authority {
    if !(c is ('a'..='z') ||
      c is ('0'..='9') ||
      c is ('.' | '-' | ':' | '[' | ']')) {
      fail("captured host contains credentials or unsupported characters")
    }
  }
  let (host, port) = if authority.has_prefix("[") {
    let parts = authority.split("]").collect()
    if parts.length() != 2 || !parts[0].contains(":") || parts[0].length() < 4 {
      fail("invalid bracketed captured host")
    }
    for c in parts[0][1:] {
      if !(c is ('a'..='f') || c is ('0'..='9') || c is (':' | '.')) {
        fail("invalid bracketed captured host")
      }
    }
    let suffix = parts[1].to_owned()
    (
      parts[0].to_owned() + "]",
      if suffix.is_empty() {
        ""
      } else {
        if !suffix.has_prefix(":") {
          fail("invalid captured port")
        }
        suffix[1:].to_owned()
      },
    )
  } else {
    let parts = authority.split(":").collect()
    if parts.length() > 2 ||
      parts[0].is_empty() ||
      parts[0].contains("[") ||
      parts[0].contains("]") {
      fail("invalid captured host")
    }
    (
      parts[0].to_owned(),
      if parts.length() == 2 {
        parts[1].to_owned()
      } else {
        ""
      },
    )
  }
  if authority.has_suffix(":") {
    fail("empty captured port")
  }
  let port = if port.is_empty() {
    ""
  } else {
    for c in port {
      if !(c is ('0'..='9')) {
        fail("invalid captured port")
      }
    }
    let n = @string.parse_int(port) catch { _ => fail("invalid captured port") }
    if n < 1 || n > 65535 {
      fail("captured port must be between 1 and 65535")
    }
    if (scheme == "http" && n == 80) || (scheme == "https" && n == 443) {
      ""
    } else {
      ":\{n}"
    }
  }
  "\{scheme}://\{host}\{port}"
}

///|
fn captured_start(value : Json) -> Double? {
  guard value is String(s) && s.length() >= 20 && s.length() <= 35 else {
    return None
  }
  // ISO calendar datetime plus explicit Z or numeric offset, with optional fraction.
  let end = if s.has_suffix("Z") { s.length() - 1 } else { s.length() - 6 }
  if end < 19 {
    return None
  }
  let mut offset = 0
  if !s.has_suffix("Z") {
    if !(s[end] == '+' || s[end] == '-') || s[end + 3] != ':' {
      return None
    }
    for i in [end + 1, end + 2, end + 4, end + 5] {
      if !(s[i] is ('0'..='9')) {
        return None
      }
    }
    let h = @string.parse_int(s[end + 1:end + 3]) catch { _ => return None }
    let m = @string.parse_int(s[end + 4:end + 6]) catch { _ => return None }
    if h > 23 || m > 59 {
      return None
    }
    offset = (h * 3600 + m * 60) * (if s[end] == '-' { -1 } else { 1 })
  }
  for i = 0; i < 19; i = i + 1 {
    if [4, 7, 10, 13, 16].contains(i) {
      continue
    }
    if !(s[i] is ('0'..='9')) {
      return None
    }
  }
  if s[4] != '-' || s[7] != '-' || s[10] != 'T' || s[13] != ':' || s[16] != ':' {
    return None
  }
  let base = @time.PlainDateTime::from_str(s[:19]) catch { _ => return None }
  let mut fraction = 0.0
  let mut scale = 100.0
  if end > 19 {
    if s[19] != '.' || end == 20 || end > 29 {
      return None
    }
    for i = 20; i < end; i = i + 1 {
      if !(s[i] is ('0'..='9')) {
        return None
      }
      fraction += (s[i].to_int() - 48).to_double() * scale
      scale /= 10.0
    }
  }
  Some(
    (base.to_unix_second() - offset.to_int64()).to_double() * 1000.0 + fraction,
  )
}

///|
fn normalize_entry(entry : Json, index : Int) -> Json raise {
  let label = "HAR entry \{index}"
  if !(entry is Object(_)) {
    fail(label + ": expected an object")
  }
  let request = field(entry, "request")
  let request_method = text(request, "method").to_upper()
  if ![
      "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS", "TRACE", "CONNECT",
    ].contains(request_method) {
    fail(label + ": unsupported or missing request method")
  }
  let origin = origin_of(text(request, "url")) catch {
    error => fail(label + ": " + error.to_string())
  }
  let response = field(entry, "response")
  if !(response is Object(_)) {
    fail(label + ": response must be an object")
  }
  let status = match field(response, "status") {
    Null => Json::null()
    Number(n, ..) if (n == 0.0 || (n >= 100.0 && n <= 599.0)) &&
      n == n.to_int().to_double() => n.to_json()
    _ =>
      fail(
        label +
        ": response.status must be 0, an integer from 100 to 599, null, or absent",
      )
  }
  let outcome = match number(status) {
    None => "unknown_status"
    Some(0.0) => "no_http_response"
    Some(n) if n < 200.0 => "informational"
    Some(n) if n < 300.0 => "success"
    Some(n) if n < 400.0 => "redirect"
    Some(n) if n < 500.0 => "client_error"
    Some(_) => "server_error"
  }
  let raw_timings = field(entry, "timings")
  if raw_timings != Json::null() && !(raw_timings is Object(_)) {
    fail(label + ": timings must be an object or absent")
  }
  let timings : Map[String, Json] = Map([])
  let mut longest : Json = Json::null()
  let mut maximum = -1.0
  for phase in ["blocked", "dns", "connect", "send", "wait", "receive", "ssl"] {
    let value = duration(
      field(raw_timings, phase),
      label + ": timings." + phase,
    )
    timings[phase] = value
    // SSL is included in connect in HAR; never double-count it as another phase.
    if phase != "ssl" && number(value) is Some(ms) && ms > maximum {
      maximum = ms
      longest = phase.to_json()
    }
  }
  {
    "entry": index.to_json(),
    "method": request_method.to_json(),
    "origin": origin.to_json(),
    "status": status,
    "outcome": outcome.to_json(),
    "startedAtUnixMs": optional_number(
      captured_start(field(entry, "startedDateTime")),
    ),
    "elapsedMs": duration(field(entry, "time"), label + ": time"),
    "timingsMs": timings.to_json(),
    "longestRecordedPhase": longest,
  }
}

///|
fn optional_number(value : Double?) -> Json {
  match value {
    Some(n) => n.to_json()
    None => Json::null()
  }
}
