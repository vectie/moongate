///|
fn moonstat_security_handler(
  next : @httpx.Handler,
  control : ControlPlaneAuth,
  configured_host : String,
  port : Int,
) -> @httpx.Handler {
  (r, w) => {
    if !moonstat_request_authority_allowed(r.headers, configured_host, port) {
      moonstat_write_security_error(w)
      return
    }
    let path = r.path.to_owned().split("?").head().unwrap_or("").to_owned()
    if path == "/control/bootstrap" {
      if r.method_ != Get ||
        !moonstat_control_bootstrap_allowed(r.headers, configured_host, port) {
        moonstat_write_security_error(w)
        return
      }
      control.write_bootstrap(w)
      return
    }
    if moonstat_route_requires_control(r.method_, path) &&
      !control.authorized(r.headers) {
      moonstat_write_control_auth_error(w)
      return
    }
    next(r, w)
  }
}

///|
fn moonstat_control_bootstrap_allowed(
  headers : Map[String, String],
  configured_host : String,
  port : Int,
) -> Bool {
  guard headers.get("origin") is Some(origin) else { return false }
  if !moonstat_origin_allowed(origin, configured_host, port) {
    return false
  }
  match headers.get("sec-fetch-site") {
    Some(site) => site == "same-origin"
    None => true
  }
}

///|
fn moonstat_route_requires_control(
  method_ : @httpx.Method,
  path : String,
) -> Bool {
  if moonstat_inference_route(method_, path) ||
    moonstat_public_route(method_, path) ||
    moonstat_static_route(method_, path) {
    return false
  }
  true
}

///|
fn moonstat_inference_route(method_ : @httpx.Method, path : String) -> Bool {
  match method_ {
    Post =>
      path == "/v1/messages" ||
      path == "/claude-desktop/v1/messages" ||
      path == "/v1/chat/completions" ||
      path == "/openclaw/v1/chat/completions" ||
      path == "/v1/responses" ||
      path == "/v1/responses/compact" ||
      path.has_prefix("/gemini/v1/") ||
      path.has_prefix("/gemini/v1beta/")
    Get =>
      path == "/v1/models" ||
      path == "/claude-desktop/v1/models" ||
      path.has_prefix("/gemini/v1/") ||
      path.has_prefix("/gemini/v1beta/")
    _ => false
  }
}

///|
fn moonstat_public_route(method_ : @httpx.Method, path : String) -> Bool {
  method_ == Get &&
  (
    path == "/health" ||
    path == "/status" ||
    path == "/stats" ||
    path == "/metrics" ||
    path == "/suite/manifest" ||
    path == "/suite/status" ||
    path == "/suite/moonclaw-providers"
  )
}

///|
fn moonstat_static_route(method_ : @httpx.Method, path : String) -> Bool {
  method_ == Get &&
  (
    path == "/" ||
    path == "/ui/rabbita" ||
    path == "/participant/register" ||
    path == "/favicon.ico" ||
    path.has_prefix("/assets/")
  )
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
  moonstat_write_json_error(
    w,
    @status.Forbidden,
    "moonstat_untrusted_request_authority",
    "Host or Origin is not trusted by Moonstat",
  )
}

///|
async fn moonstat_write_control_auth_error(w : @httpx.ResponseWriter) -> Unit {
  moonstat_write_json_error(
    w,
    @status.Unauthorized,
    "moonstat_control_auth_required",
    "A valid Moonstat control token is required",
  )
}

///|
async fn moonstat_write_json_error(
  w : @httpx.ResponseWriter,
  status_code : Int,
  code : String,
  message : String,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.header().set("Cache-Control", "no-store")
  w.write_header(status_code)
  w.write(
    {
      "error": { "code": Json::string(code), "message": Json::string(message) }.to_json(),
    }
    .to_json()
    .stringify(),
  )
  w.flush()
}
