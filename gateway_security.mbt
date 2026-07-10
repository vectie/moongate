///|
fn moonstat_security_handler(
  next : @httpx.Handler,
  configured_host : String,
  port : Int,
) -> @httpx.Handler {
  (r, w) => {
    if !moonstat_request_authority_allowed(r.headers, configured_host, port) {
      moonstat_write_security_error(w)
      return
    }
    next(r, w)
  }
}

///|
fn moonstat_request_authority_allowed(
  headers : Map[String, String],
  configured_host : String,
  port : Int,
) -> Bool {
  guard headers.get("host") is Some(host_header) else { return false }
  guard moonstat_parse_authority(host_header) is Some(authority) else {
    return false
  }
  if !moonstat_host_allowed(authority.host, configured_host) ||
    !moonstat_port_allowed(authority.port, port) {
    return false
  }
  match headers.get("origin") {
    None => true
    Some(origin) => moonstat_origin_allowed(origin, configured_host, port)
  }
}

///|
fn moonstat_parse_authority(authority : String) -> @url.Url? {
  let value = authority.trim()
  if value.is_empty() {
    return None
  }
  Some(@url.parse("http://\{value}")) catch {
    _ => None
  }
}

///|
fn moonstat_origin_allowed(
  origin : String,
  configured_host : String,
  port : Int,
) -> Bool {
  let value = origin.trim().to_owned()
  if value.is_empty() || value == "null" {
    return false
  }
  let parsed = @url.parse(value) catch { _ => return false }
  moonstat_host_allowed(parsed.host, configured_host) &&
  moonstat_port_allowed(parsed.port, port)
}

///|
fn moonstat_host_allowed(host : String, configured_host : String) -> Bool {
  let normalized = host.trim().to_lower()
  let configured = configured_host.trim().to_lower()
  normalized == configured ||
  normalized == "localhost" ||
  normalized == "127.0.0.1" ||
  normalized == "::1"
}

///|
fn moonstat_port_allowed(actual : Int?, expected : Int) -> Bool {
  match actual {
    Some(port) => port == expected
    None => expected == 80 || expected == 443
  }
}

///|
async fn moonstat_write_security_error(w : @httpx.ResponseWriter) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Forbidden)
  w.write(
    {
      "error": {
        "code": Json::string("moonstat_untrusted_request_authority"),
        "message": Json::string("Host or Origin is not trusted by Moonstat"),
      }.to_json(),
    }
    .to_json()
    .stringify(),
  )
  w.flush()
}
