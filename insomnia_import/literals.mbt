///|
fn dynamic(value : String) -> Bool {
  value.contains("{{") ||
  value.contains("}}") ||
  value.contains("{%") ||
  value.contains("%}") ||
  value.contains("{#") ||
  value.contains("#}")
}

///|
fn sensitive(value : String) -> Bool {
  let lower = value.to_lower()
  ["authorization", "token", "key", "cookie", "secret", "password"].any(word => {
    lower.contains(word)
  })
}

///|
fn header_token(value : String) -> Bool {
  !value.is_empty() &&
  value
  .iter()
  .all(c => {
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    "!#$%&'*+-.^_`|~".contains(c.to_string())
  })
}

///|
fn encode(value : String) -> String {
  let out = StringBuilder()
  let hex = "0123456789ABCDEF"
  for byte in @utf8.encode(value) {
    let n = byte.to_int()
    if (n >= 65 && n <= 90) ||
      (n >= 97 && n <= 122) ||
      (n >= 48 && n <= 57) ||
      [45, 46, 95, 126].contains(n) {
      out.write_char(n.to_char().unwrap())
    } else {
      out.write_char('%')
      out.write_char(hex[n / 16].to_int().to_char().unwrap())
      out.write_char(hex[n % 16].to_int().to_char().unwrap())
    }
  }
  out.to_string()
}

///|
fn request_url(request : Json, warnings : Array[String]) -> String raise {
  let raw = text(request, "url")
  guard !raw.is_empty() && line_safe(raw) else { fail("Invalid request URL") }
  if dynamic(raw) {
    warnings.push(
      "Template URL omitted; replace the entire URL manually. No environment or template was evaluated.",
    )
    return "https://REPLACE_ME.invalid/"
  }
  guard (raw.has_prefix("https://") || raw.has_prefix("http://")) &&
    !raw.contains(" ") else {
    fail("Expected absolute HTTP(S) URL without whitespace")
  }
  let fragments = raw.split("#").to_array()
  if fragments.length() > 1 {
    warnings.push("URL fragment omitted.")
  }
  let parts = fragments[0].split("?").to_array()
  let base = parts[0].to_owned()
  let host = base.split("/").to_array()[2]
  guard !host.is_empty() && !host.contains("@") && !host.contains("\\") else {
    fail("Missing host or embedded URL credentials")
  }
  let pairs : Array[String] = []
  if parts.length() > 1 {
    for pair in parts[1:].map(p => p.to_owned()).join("?").split("&") {
      let name = pair.split("=").to_array()[0].to_owned()
      if sensitive(name) || name.contains("%") {
        pairs.push(name + "=REPLACE_ME")
        warnings.push("Raw query value withheld: " + name)
      } else {
        pairs.push(pair.to_owned())
      }
    }
  }
  for parameter in array(request, "parameters") {
    if disabled(parameter) {
      continue
    }
    let name = text(parameter, "name")
    let value = optional_text(parameter, "value")
    guard !name.is_empty() && !dynamic(name) && line_safe(name) else {
      fail("Query parameter names must be literal nonempty single-line text")
    }
    let value = if sensitive(name) || dynamic(value) {
      warnings.push(
        "Query value withheld or requires template editing: " + name,
      )
      "REPLACE_ME"
    } else {
      value
    }
    pairs.push(encode(name) + "=" + encode(value))
  }
  base + (if pairs.is_empty() { "" } else { "?" + pairs.join("&") })
}

///|
fn body_safe(body : String) -> Bool {
  if dynamic(body) {
    return false
  }
  for line in body.replace_all(old="\r", new="\n").split("\n") {
    let trimmed = line.trim()
    if trimmed.has_prefix("#") ||
      trimmed.has_prefix("<") ||
      trimmed.has_prefix(">") ||
      trimmed.has_prefix("@") {
      return false
    }
  }
  body.iter().all(c => c >= ' ' || c == '\n' || c == '\r' || c == '\t') &&
  !body.contains("\u{7f}")
}

///|
fn request_body(
  request : Json,
  warnings : Array[String],
) -> (String, String) raise {
  let body = field(request, "body")
  if body == Json::null() {
    return ("", "")
  }
  guard body is Object(fields) else { fail("Request body must be an object") }
  if fields.is_empty() || disabled(body) {
    return ("", "")
  }
  let mime = optional_text(body, "mimeType")
  guard line_safe(mime) && !dynamic(mime) else {
    fail("Invalid body MIME type")
  }
  if field(body, "fileName") != Json::null() ||
    field(body, "filename") != Json::null() ||
    field(body, "params") != Json::null() ||
    mime.to_lower().has_prefix("multipart/") {
    warnings.push(
      "File, form or multipart body omitted; reconstruct it manually. No file was read.",
    )
    return ("", "")
  }
  if field(body, "text") == Json::null() {
    warnings.push("Non-text body omitted; reconstruct it manually.")
    return ("", "")
  }
  let value = text(body, "text")
  if !body_safe(value) {
    warnings.push(
      "Body with templates, control bytes or HTTP-client directive-like lines omitted; reconstruct it manually.",
    )
    return ("", "")
  }
  (value, mime)
}
