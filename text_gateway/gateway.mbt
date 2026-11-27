///|
/// Fixed-origin, per-request-authority mode for shared event gateways. The
/// upstream retains participant, quota, model, expiry and replica authority.
pub struct TextGateway {
  origin : String
  browser_origin : String?
}

///|
pub fn TextGateway::new(
  origin : String,
  browser_origin? : String,
) -> TextGateway raise {
  let start = if origin.has_prefix("https://") {
    8
  } else if origin.has_prefix("http://") {
    7
  } else {
    fail("invalid model origin")
  }
  let authority = origin[start:]
  guard !authority.is_empty() &&
    authority.length() <= 253 &&
    authority.all(c => c is ('a'..<='z' | '0'..<='9' | '.' | '-' | ':')) else {
    fail("model origin must be a deployment-owned origin without a path")
  }
  if browser_origin is Some(browser) {
    guard browser.has_prefix("https://") &&
      browser.length() > 8 &&
      browser[8:].all(c => c is ('a'..<='z' | '0'..<='9' | '.' | '-' | ':')) else {
      fail("invalid deployment-owned browser origin")
    }
  }
  { origin, browser_origin, }
}

///|
pub fn allowed_route(method_ : @httpx.Method, path : String) -> Bool {
  (method_ == Get && path == "/v1/models") ||
  (
    method_ == Post &&
    (path == "/v1/chat/completions" || path == "/v1/responses")
  )
}

///|
fn single(headers : Map[String, String], name : String) -> String? {
  let matches = headers.iter().filter(p => p.0.to_lower() == name).collect()
  if matches.length() == 1 {
    Some(matches[0].1)
  } else {
    None
  }
}

///|
fn single_ci(
  headers : Map[@http.CaseInsensitiveString, String],
  name : String,
) -> String? {
  headers.get(@http.CaseInsensitiveString(name))
}

///|
async fn log_protocol(value : Json) -> Unit {
  // Bypass C stdout buffering so container logs show the current request.
  @io.Writer::write(@stdio.stderr, value.stringify() + "\n") catch {
    _ => ()
  }
}

///|
async fn deny(
  writer : @httpx.ResponseWriter,
  code : Int32,
  reason~ : String = "upstream_rejected",
  public_code~ : String = "EventModelRequestRejected",
  message~ : String = "Model access was not confirmed; check your personal credential, event window and limits.",
) -> Unit {
  log_protocol({
    "event": "EventModelRejected",
    "status": code,
    "reason": reason,
  })
  writer.header().set("content-type", "application/json")
  writer.header().set("cache-control", "no-store")
  writer.write_header(code)
  writer.write(
    (
      {
        "error": {
          "code": public_code,
          "message": message,
          "type": if code == 401 {
            "authentication_error"
          } else if code == 403 {
            "permission_error"
          } else if code == 429 {
            "rate_limit_error"
          } else if code >= 400 && code < 500 {
            "invalid_request_error"
          } else {
            "api_error"
          },
        },
      } : Json).stringify(),
  )
  writer.close()
}

///|
pub async fn TextGateway::handle(
  self : TextGateway,
  request : @httpx.RequestReader,
  writer : @httpx.ResponseWriter,
) -> Unit {
  // Log only bounded protocol metadata, never bearer values or request bodies.
  log_protocol({
    "event": "EventModelIngress",
    "route": if request.path == "/v1/models" {
      "models"
    } else if request.path == "/v1/chat/completions" {
      "chat"
    } else if request.path == "/v1/responses" {
      "responses"
    } else {
      "other"
    },
    "origin": if single(request.headers, "origin") is None {
      "absent"
    } else if single(request.headers, "origin") == self.browser_origin {
      "portal"
    } else {
      "other"
    },
  })
  if !allowed_route(request.method_, request.path.to_owned()) {
    return deny(writer, 404, reason="route_not_supported")
  }
  if request.headers.keys().any(k => k.to_lower() == "origin") &&
    (
      self.browser_origin is None ||
      single(request.headers, "origin") != self.browser_origin
    ) {
    return deny(writer, 403, reason="origin_not_allowed")
  }
  guard single(request.headers, "authorization") is Some(authorization) &&
    authorization.has_prefix("Bearer ") &&
    authorization.length() > 7 &&
    authorization.length() <= 4103 &&
    authorization[7:].all(c => c >= '!' && c <= '~') else {
    return deny(writer, 401, reason="bearer_header_invalid")
  }
  let headers : Map[@http.CaseInsensitiveString, String] = Map::from_array([
    (@http.CaseInsensitiveString("authorization"), authorization),
  ])
  if request.method_ == Post {
    guard single(request.headers, "content-type") is Some(content_type) &&
      content_type.split(";").next().unwrap().trim() == "application/json" else {
      return deny(writer, 415, reason="content_type_not_json")
    }
    headers["content-type"] = "application/json"
    // Compute-cache permission is not an identity assertion or response cache.
    // Forward only the supported opt-in; the controller derives tenant scope.
    if single(request.headers, "x-lunanexa-prefix-cache") == Some("tenant") {
      headers["x-lunanexa-prefix-cache"] = "tenant"
    }
    if single(request.headers, "idempotency-key") is Some(key) {
      guard key.length() > 0 &&
        key.length() <= 128 &&
        key.all(c => c is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '-' | '_')) else {
        return deny(writer, 400, reason="idempotency_key_invalid")
      }
      headers["idempotency-key"] = key
    }
  }
  let mut started = false
  @async.with_timeout(180000, () => {
    let payload = Buffer()
    let mut size = 0
    while request.body.read_some(max_len=8192) is Some(bytes) {
      size += bytes.length()
      // Transport bytes include JSON escaping and wrapper fields; the
      // controller separately enforces the UI-configured canonical input
      // budget. Match its 1 MiB HTTP envelope rather than a hidden 64 KiB cap.
      if size > 1048576 {
        return deny(
          writer,
          413,
          reason="request_body_too_large",
          public_code="RequestBodyTooLarge",
          message="The JSON request body exceeds 1048576 bytes. Reduce the request body; this is not an API key error.",
        )
      }
      payload.write_bytesview(bytes)
    }
    let upstream = @http.Client(self.origin)
    defer upstream.close()
    upstream.request(
      request.method_.to_http(),
      request.path,
      extra_headers=headers,
    )
    upstream.write(payload.to_bytes())
    let response = upstream.end_request()
    if response.code < 200 || response.code >= 300 {
      let error_body = Buffer()
      while upstream.read_some(max_len=1024) is Some(bytes) {
        if error_body.length() + bytes.length() > 8192 {
          break
        }
        error_body.write_bytesview(bytes)
      }
      let error_code = try {
        match @json.parse(@utf8.decode(error_body.to_bytes())) {
          { "error": { "code": String(code), .. }, .. } if code.length() <= 80 &&
            code.all(c => c is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_')) =>
            code
          _ => "unclassified"
        }
      } catch {
        _ => "unclassified"
      }
      log_protocol({
        "event": "EventModelUpstreamRejected",
        "status": response.code,
        "code": error_code,
      })
      if error_code == "WorkspaceLimitExceeded" ||
        error_code == "TrialRequestBudgetExceeded" ||
        error_code == "RequestBudgetExceeded" {
        // Resource-size refusal is not an invalid key. Older controllers used
        // 403 here; normalize only these explicit, known budget errors.
        return deny(
          writer,
          400,
          reason="request_budget_exceeded",
          public_code=error_code,
          message="Request input or max_tokens exceeds the configured workspace/trial budget. Your API key was accepted. Reduce the request or ask the operator to update the input/output limits in trial settings.",
        )
      }
      return deny(
        writer,
        if response.code >= 400 && response.code <= 599 {
          response.code
        } else {
          502
        },
      )
    }
    let content = single_ci(response.headers, "content-type").unwrap_or("")
    guard content.has_prefix("application/json") ||
      content.has_prefix("text/event-stream") else {
      fail("invalid model content type")
    }
    writer.header().set("content-type", content)
    writer.header().set("cache-control", "no-store")
    writer.header().set("x-content-type-options", "nosniff")
    writer.write_header(response.code)
    log_protocol({ "event": "EventModelAccepted", "status": response.code })
    started = true
    let mut received = 0
    while upstream.read_some(max_len=8192) is Some(bytes) {
      received += bytes.length()
      if received > 4194304 {
        fail("model response exceeds bound")
      }
      writer.write(bytes)
      writer.flush()
    }
    writer.close()
  }) catch {
    error => if started { raise error } else { deny(writer, 502) }
  }
}
