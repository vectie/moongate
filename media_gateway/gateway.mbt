///|
pub(all) suberror MediaGatewayError {
  InvalidConfiguration
  InvalidResponse
} derive(Debug, Eq)

///|
pub struct MediaGateway {
  origin : String
}

///|
pub fn MediaGateway::new(
  origin : String,
) -> MediaGateway raise MediaGatewayError {
  let start = if origin.has_prefix("https://") {
    8
  } else if origin.has_prefix("http://") {
    7
  } else {
    raise InvalidConfiguration
  }
  let host = origin[start:]
  if host.is_empty() ||
    host.length() > 253 ||
    !host.all(c => {
      (c >= 'a' && c <= 'z') ||
      (c >= '0' && c <= '9') ||
      c == '.' ||
      c == '-' ||
      c == ':'
    }) {
    raise InvalidConfiguration
  }
  { origin, }
}

///|
pub fn allowed_route(verb : @httpx.Method, path : String) -> Bool {
  if verb == Post {
    return path == "/v1/videos"
  }
  if verb != Get && verb != Delete {
    return false
  }
  if !path.has_prefix("/v1/videos/") {
    return false
  }
  let suffix = path[11:].to_owned()
  let id = if verb == Get && suffix.has_suffix("/content") {
    suffix[:suffix.length() - 8].to_owned()
  } else {
    suffix
  }
  id.length() == 70 &&
  id.has_prefix("video-") &&
  id[6:].all(c => (c >= 'a' && c <= 'f') || (c >= '0' && c <= '9'))
}

///|
fn single(headers : Map[String, String], key : String) -> String? {
  let values = headers
    .iter()
    .filter(pair => pair.0.to_lower() == key)
    .to_array()
  if values.length() == 1 {
    Some(values[0].1)
  } else {
    None
  }
}

///|
async fn limited(reader : &@io.Reader, limit : Int) -> Bytes {
  let result = Buffer()
  let mut count = 0
  while reader.read_some(max_len=8192) is Some(bytes) {
    count += bytes.length()
    if count > limit {
      raise InvalidResponse
    }
    result.write_bytes(bytes)
  }
  result.to_bytes()
}

///|
pub async fn unavailable(writer : @httpx.ResponseWriter) -> Unit {
  error_reply(writer, 503)
}

///|
async fn error_reply(writer : @httpx.ResponseWriter, code : Int) -> Unit {
  writer.header().set("content-type", "application/json")
  writer.header().set("cache-control", "no-store")
  writer.write_header(code)
  writer.write(bounded_error(code).stringify())
  writer.close()
}

///|
fn bounded_error(code : Int) -> Json {
  let (name, message) = match code {
    400 | 415 | 422 =>
      (
        "InvalidVideoRequest", "Video request format or settings are not supported; correct the request before retrying",
      )
    401 | 403 => ("VideoAccessDenied", "Video access is not authorized")
    404 => ("VideoNotFound", "Video is unavailable")
    409 =>
      (
        "VideoConflict", "Video request conflicts with current state; retain the request key and inspect its status",
      )
    413 => ("VideoRequestTooLarge", "Video request exceeds the supported size")
    429 =>
      (
        "VideoRateLimited", "Video request limit reached; retry later with the same request key",
      )
    _ =>
      (
        "ManagedVideoUnavailable", "Video operation was not confirmed; retain the same request key and check its status",
      )
  }
  { "error": { "code": name, "message": message } }
}

///|
/// Tenant credentials pass only to the deployment-owned LunaNexa origin.
/// No provider fallback, POST retry, token substitution or token-based charging.
pub async fn MediaGateway::handle(
  self : MediaGateway,
  request : @httpx.RequestReader,
  writer : @httpx.ResponseWriter,
) -> Unit {
  if !allowed_route(request.method_, request.path.to_owned()) {
    return error_reply(writer, 404)
  }
  if request.headers.keys().any(key => key.to_lower() == "origin") {
    return error_reply(writer, 403)
  }
  guard single(request.headers, "authorization") is Some(authorization) &&
    authorization.has_prefix("Bearer ") &&
    authorization.length() > 7 &&
    authorization.length() <= 4103 &&
    authorization[7:].all(c => c >= '!' && c <= '~') else {
    return error_reply(writer, 401)
  }
  let headers = { "authorization": authorization }
  if request.method_ == Post {
    guard single(request.headers, "content-type") is Some(content_type) &&
      ["application/json", "application/x-www-form-urlencoded"].contains(
        content_type,
      ) &&
      single(request.headers, "idempotency-key") is Some(key) &&
      !key.is_empty() &&
      key.length() <= 128 &&
      key.all(c => {
        (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        c == '-' ||
        c == '_'
      }) else {
      return error_reply(writer, 400)
    }
    headers["content-type"] = content_type
    headers["idempotency-key"] = key
  }
  let mut started = false
  @async.with_timeout(300000, () => {
    let payload = limited(request.body, 65536) catch {
      _ => return error_reply(writer, 413)
    }
    let upstream = @http.Client(self.origin)
    defer upstream.close()
    upstream.request(
      request.method_.to_http(),
      request.path,
      extra_headers=headers,
    )
    upstream.write(payload)
    let response = upstream.end_request()
    if response.code < 200 || response.code >= 300 {
      return error_reply(
        writer,
        if response.code >= 400 && response.code <= 599 {
          response.code
        } else {
          502
        },
      )
    }
    let is_content = request.path.has_suffix("/content")
    let content_type = single(response.headers, "content-type").unwrap_or("")
    if is_content {
      if content_type != "video/mp4" || response.code != 200 {
        raise InvalidResponse
      }
      writer.header().set("content-type", "video/mp4")
      writer.header().set("cache-control", "no-store")
      writer.header().set("x-content-type-options", "nosniff")
      let mut bytes_sent = 0L
      while upstream.read_some(max_len=65536) is Some(bytes) {
        bytes_sent += bytes.length().to_int64()
        if bytes_sent > 1073741824L {
          raise InvalidResponse
        }
        if !started {
          writer.write_header(200)
          started = true
        }
        writer.write(bytes)
      }
      if !started {
        raise InvalidResponse
      }
    } else {
      if !content_type.has_prefix("application/json") {
        raise InvalidResponse
      }
      let bytes = limited(upstream, 262144)
      ignore(@json.parse(@utf8.decode(bytes)))
      writer.header().set("content-type", "application/json")
      writer.header().set("cache-control", "no-store")
      writer.write_header(response.code)
      started = true
      writer.write(bytes)
    }
    writer.close()
  }) catch {
    _ => {
      if started {
        raise InvalidResponse
      }
      error_reply(writer, 502)
    }
  }
}
