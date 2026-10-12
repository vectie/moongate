///|
fn gate_har_sensitive(name : String) -> Bool {
  let name = name.to_lower()
  name.contains("authorization") ||
  name.contains("token") ||
  name.contains("key") ||
  name.contains("cookie") ||
  name.contains("secret") ||
  name.contains("password")
}

///|
fn gate_har_line_safe(value : String) -> Bool {
  for c in value {
    if c < ' ' || c == '\u007f' {
      return false
    }
  }
  true
}

///|
/// Import sanitized HAR 1.2 browser requests into an offline editable collection.
/// Captured bodies and non-auth metadata are retained; this is not a general
/// secret scrubber. Responses, browser cookies and timing records are not copied.
pub fn moongate_har_collection_json(
  content : String,
  request_method? : String = "",
  url_contains? : String = "",
) -> Result[Json, String] {
  if @encoding/utf8.encode(content).length() > 4 * 1024 * 1024 {
    return Err("HAR file exceeds 4 MiB")
  }
  guard moon_parse_json_line(content) is Some(root) else {
    return Err("Expected HAR 1.2 JSON")
  }
  let log = gate_oas_field(root, "log")
  if gate_oas_text(log, "version") != "1.2" {
    return Err("Only HAR 1.2 is supported")
  }
  guard gate_oas_field(log, "entries") is Array(entries) else {
    return Err("HAR log.entries must be an array")
  }
  if entries.length() > 2000 {
    return Err("HAR import is limited to 2,000 entries")
  }
  let verbs = [
    "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS", "TRACE", "CONNECT",
  ]
  let filter_method = request_method.to_upper()
  if !filter_method.is_empty() && !verbs.contains(filter_method) {
    return Err("Unsupported method filter")
  }
  let requests : Array[Json] = []
  let sections : Array[String] = [
    "# MoonGate offline HAR request collection", "# Review captured content and supply authentication before manually sending.",
    "# No requests were sent. Bodies and ordinary metadata may contain private data.",
  ]
  for index, entry in entries {
    let request = gate_oas_field(entry, "request")
    let verb = gate_oas_text(request, "method").to_upper()
    let original_url = gate_oas_text(request, "url")
    if (!filter_method.is_empty() && verb != filter_method) ||
      (!url_contains.is_empty() && !original_url.contains(url_contains)) {
      continue
    }
    let label = "HAR entry " + (index + 1).to_string()
    if !verbs.contains(verb) || verb == "CONNECT" {
      return Err(label + ": unsupported request method")
    }
    if !gate_har_line_safe(original_url) ||
      original_url.contains(" ") ||
      (
        !original_url.has_prefix("http://") &&
        !original_url.has_prefix("https://")
      ) {
      return Err(
        label + ": expected an absolute HTTP(S) URL without whitespace",
      )
    }
    let without_fragment = original_url.split("#").collect()[0].to_string()
    let url_parts = without_fragment.split("?").collect()
    let base = url_parts[0].to_string()
    let authority_parts = base.split("/").collect()
    if authority_parts.length() < 3 ||
      authority_parts[2].is_empty() ||
      authority_parts[2].contains("@") {
      return Err(label + ": missing host or embedded URL credentials")
    }
    let warnings : Array[String] = []
    let mut url = base
    if url_parts.length() > 1 {
      // Preserve exact query order, repeated parameters and percent encoding.
      let query = url_parts[1:].map(p => p.to_string()).join("?")
      let pairs : Array[String] = []
      for part in query.split("&") {
        let name = part.split("=").collect()[0].to_string()
        // Encoded names cannot be classified safely without decoding. Replace
        // their values as well rather than guessing whether they contain auth.
        if gate_har_sensitive(name) || name.contains("%") {
          pairs.push(name + "=REPLACE_ME")
          warnings.push("Query value withheld: " + name)
        } else {
          pairs.push(part.to_string())
        }
      }
      url += "?" + pairs.join("&")
    }
    guard gate_oas_field(request, "headers") is Array(captured_headers) else {
      return Err(label + ": request.headers must be an array")
    }
    let headers : Array[String] = []
    let declarations : Array[String] = []
    let mut content_type = false
    for header_index, header in captured_headers {
      let name = gate_oas_text(header, "name")
      let value = gate_oas_text(header, "value")
      if name.is_empty() ||
        !gate_har_line_safe(name) ||
        name.contains(":") ||
        name.contains(" ") ||
        !gate_har_line_safe(value) {
        return Err(
          label + ": invalid header name or multiline/control header value",
        )
      }
      let lower = name.to_lower()
      if [
          "host", "content-length", "connection", "transfer-encoding", "accept-encoding",
          "cookie", "proxy-connection",
        ].contains(lower) {
        warnings.push(
          "Recreate if needed; browser/transport header omitted: " + name,
        )
        continue
      }
      if lower == "content-type" {
        content_type = true
      }
      if gate_har_sensitive(name) {
        let variable = "auth_" +
          (index + 1).to_string() +
          "_" +
          header_index.to_string()
        declarations.push("@" + variable + " = REPLACE_ME")
        headers.push(name + ": {{" + variable + "}}")
        warnings.push("Captured authentication withheld: " + name)
      } else {
        headers.push(name + ": " + value)
      }
    }
    let mut body = ""
    if moon_json_get(request, "postData") is Some(post_data) {
      let mime = gate_oas_text(post_data, "mimeType")
      if !gate_har_line_safe(mime) {
        return Err(label + ": invalid body MIME type")
      }
      if moon_json_get(post_data, "encoding") is Some(_) ||
        moon_json_get(post_data, "_encoding") is Some(_) ||
        mime.to_lower().has_prefix("multipart/") {
        warnings.push(
          "Encoded or multipart body omitted; reconstruct it manually.",
        )
      } else if gate_oas_field(post_data, "text") is String(text) {
        body = text
        if !content_type && !mime.is_empty() {
          headers.push("Content-Type: " + mime)
        }
      } else {
        warnings.push(
          "No captured text body; reconstruct postData.params or missing content manually.",
        )
      }
    }
    let section = "### " +
      label +
      "\n" +
      warnings.map(w => "# " + w).join("\n") +
      "\n" +
      declarations.join("\n") +
      "\n\n" +
      verb +
      " " +
      url +
      "\n" +
      headers.join("\n") +
      "\n\n" +
      body
    sections.push(section)
    requests.push({
      "entry": (index + 1).to_json(),
      "method": verb.to_json(),
      "url": url.to_json(),
      "headers": headers.to_json(),
      "body": body.to_json(),
      "warnings": warnings.to_json(),
    })
  }
  Ok({
    "schema": "moongate.har-collection.v1",
    "sourceEntries": entries.length().to_json(),
    "selectedRequests": requests.length().to_json(),
    "requests": requests.to_json(),
    "http": (sections.join("\n\n") + "\n").to_json(),
  })
}
