///|
pub struct Gateway {
  host : String
  port : Int
  model : String
  mut credentials : @codex.Credentials?
  stats : TrafficStats
  logger : @pino.Logger
  started_at_ms : Int
}

///|
pub fn Gateway::new(
  port~ : Int,
  host? : String = "127.0.0.1",
  model? : String = "gpt-4o",
) -> Gateway {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  Gateway::{
    host,
    port,
    model,
    credentials: None,
    stats: TrafficStats::new(),
    logger,
    started_at_ms: @async.now().to_int(),
  }
}

///|
pub fn Gateway::host(self : Gateway) -> String {
  self.host
}

///|
pub fn Gateway::port(self : Gateway) -> Int {
  self.port
}

///|
pub async fn Gateway::start(self : Gateway) -> Unit {
  self.logger.info(
    "Starting Anthropic -> Codex OAuth Gateway on \{self.host}:\{self.port}",
  )
  let creds_result : Result[@codex.Credentials, Error] = try? @codex.load_credentials()
  if creds_result is Ok(creds) {
    self.credentials = Some(creds)
    self.logger.info("Loaded credentials from file")
  } else {
    self.logger.warn(
      "No credentials found. Please login first with: moonstat login",
    )
  }
  let router = @httpx.Router::new()
  let file_server = @httpx.FileServer::new("public")
  router.add_handler(@httpx.Method::Post, "/v1/messages", (r, w) => {
    self.handle_messages(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/claude/v1/messages", (r, w) => {
    self.handle_messages(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/claude-desktop/v1/messages", (r, w) => {
    self.handle_messages(r, w)
  })
  for method_ in @httpx.methods {
    router.add_handler(method_, "/v1beta/*path", (r, w) => {
      self.handle_gemini(r, w)
    })
    router.add_handler(method_, "/gemini/v1beta/*path", (r, w) => {
      self.handle_gemini(r, w)
    })
    router.add_handler(method_, "/gemini/v1/*path", (r, w) => {
      self.handle_gemini(r, w)
    })
  }
  router.add_handler(@httpx.Method::Post, "/chat/completions", (r, w) => {
    self.handle_chat_completions(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/v1/chat/completions", (r, w) => {
    self.handle_chat_completions(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/v1/v1/chat/completions", (r, w) => {
    self.handle_chat_completions(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/codex/v1/chat/completions", (r, w) => {
    self.handle_chat_completions(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/responses", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/v1/responses", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/v1/v1/responses", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/codex/v1/responses", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/v1/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/v1/v1/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/codex/v1/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/participant/register", (_, w) => {
    self.handle_register_page(w)
  })
  router.add_handler(@httpx.Method::Get, "/health", (r, w) => {
    self.handle_health(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/status", (_, w) => {
    self.handle_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/stats", (_, w) => {
    self.handle_stats(w)
  })
  router.add_handler(@httpx.Method::Get, "/models", (_, w) => {
    self.handle_models(w)
  })
  router.add_handler(@httpx.Method::Get, "/v1/models", (_, w) => {
    self.handle_models(w)
  })
  router.add_handler(@httpx.Method::Get, "/claude-desktop/v1/models", (_, w) => {
    self.handle_models(w)
  })
  router.add_handler(@httpx.Method::Post, "/login", (r, w) => {
    self.handle_login(r, w)
  })
  router.set_not_found_handler(file_server.handler())
  let server = @httpx.Server::new(self.host, self.port, reuse_addr=true)
  self.logger.info("Gateway started on \{self.host}:\{server.port()}")
  server.serve(router.handler())
}

///|
async fn Gateway::handle_register_page(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.write_static_file(
    w, "public/participant-register.html", "text/html; charset=utf-8",
  )
}

///|
async fn Gateway::handle_health(
  self : Gateway,
  _r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  let has_creds = self.credentials is Some(_)
  let response : Map[String, Json] = {
    "status": Json::string("healthy"),
    "timestamp": Json::string(@async.now().to_string()),
    "credentials_loaded": Json::boolean(has_creds),
    "stats": self.stats.to_json(),
  }
  w.write(response.to_json().stringify())
  w.flush()
}

///|
async fn Gateway::handle_codex_responses(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = r.body.read_all()
  let body_str = body.text()
  self.stats.record_inbound(body_str.length())
  let json_result : Result[Json, Error] = try? @json.parse(body_str)
  match json_result {
    Err(_) => {
      self.stats.record_bad_request()
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadRequest)
      w.write(
        "{\"error\":{\"message\":\"Invalid JSON\",\"type\":\"invalid_request_error\"}}",
      )
      w.flush()
      return
    }
    Ok(json) => {
      let stream = json_bool_field(json, "stream").unwrap_or(false)
      self.stats.record_stream_mode(stream)
      let request = normalize_codex_oauth_request(json)
      if stream {
        self.forward_streaming_codex_response(request, w)
      } else {
        self.forward_non_streaming_codex_response(request, w)
      }
    }
  }
}

///|
async fn Gateway::handle_chat_completions(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = r.body.read_all()
  let body_str = body.text()
  self.stats.record_inbound(body_str.length())
  let json_result : Result[Json, Error] = try? @json.parse(body_str)
  match json_result {
    Err(_) => {
      self.stats.record_bad_request()
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadRequest)
      w.write(
        "{\"error\":{\"message\":\"Invalid JSON\",\"type\":\"invalid_request_error\"}}",
      )
      w.flush()
      return
    }
    Ok(json) => {
      let response_model = openai_chat_model(json).unwrap_or(self.model)
      let stream = json_bool_field(json, "stream").unwrap_or(false)
      self.stats.record_stream_mode(stream)
      let request = openai_chat_to_codex_response_request(json, self.model)
      guard request is Some(codex_request) else {
        self.stats.record_bad_request()
        w.header().set("Content-Type", "application/json")
        w.write_header(@status.BadRequest)
        w.write(
          "{\"error\":{\"message\":\"Invalid Chat Completions request\",\"type\":\"invalid_request_error\"}}",
        )
        w.flush()
        return
      }
      if stream {
        self.forward_streaming_chat_completion(codex_request, response_model, w)
      } else {
        self.forward_non_streaming_chat_completion(
          codex_request, response_model, w,
        )
      }
    }
  }
}

///|
async fn Gateway::handle_gemini(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = r.body.read_all()
  let body_str = body.text()
  self.stats.record_inbound(body_str.length())
  let request_json : Json = if body_str.is_empty() {
    Json::null()
  } else {
    @json.parse(body_str) catch {
      _ => {
        self.stats.record_bad_request()
        w.header().set("Content-Type", "application/json")
        w.write_header(@status.BadRequest)
        w.write(
          "{\"error\":{\"message\":\"Invalid JSON\",\"type\":\"invalid_request_error\"}}",
        )
        w.flush()
        return
      }
    }
  }
  let endpoint = normalize_gemini_endpoint(r.path)
  self.stats.record_stream_mode(
    gemini_request_is_stream(endpoint, request_json),
  )
  let url = match gemini_proxy_url(endpoint) {
    Some(url) => url
    None => {
      self.stats.record_unauthorized()
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.Unauthorized)
      w.write(
        "{\"error\":{\"message\":\"Gemini API key not configured. Set GEMINI_API_KEY or pass ?key=.\",\"type\":\"authentication_error\"}}",
      )
      w.flush()
      return
    }
  }
  match r.method_ {
    @httpx.Method::Get => self.forward_gemini_get(url, w)
    @httpx.Method::Post => self.forward_gemini_post(url, request_json, w)
    _ => {
      self.stats.record_bad_request()
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.MethodNotAllowed)
      w.write(
        "{\"error\":{\"message\":\"Gemini proxy currently supports GET and POST\",\"type\":\"invalid_request_error\"}}",
      )
      w.flush()
    }
  }
}

///|
async fn Gateway::forward_gemini_get(
  self : Gateway,
  url : String,
  w : @httpx.ResponseWriter,
) -> Unit {
  let result = try? @http.get(url)
  match result {
    Err(error) => {
      self.stats.record_upstream_error(0)
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadGateway)
      w.write(
        "{\"error\":{\"message\":\"Gemini upstream request failed: \{error}\",\"type\":\"upstream_error\"}}",
      )
    }
    Ok((response, data)) => {
      let response_body = data.text()
      if response.code is (200..=299) {
        self.stats.record_success_usage(
          TokenUsage::empty(),
          response_body.length(),
        )
      } else {
        self.stats.record_upstream_error(response_body.length())
      }
      w.header().set("Content-Type", "application/json")
      w.write_header(response.code)
      w.write(response_body)
    }
  }
  w.flush()
}

///|
async fn Gateway::forward_gemini_post(
  self : Gateway,
  url : String,
  request_json : Json,
  w : @httpx.ResponseWriter,
) -> Unit {
  let result = try? @http.post(url, request_json, headers={
    "Content-Type": "application/json",
  })
  match result {
    Err(error) => {
      self.stats.record_upstream_error(0)
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadGateway)
      w.write(
        "{\"error\":{\"message\":\"Gemini upstream request failed: \{error}\",\"type\":\"upstream_error\"}}",
      )
    }
    Ok((response, data)) => {
      let response_body = data.text()
      if response.code is (200..=299) {
        let usage = token_usage_from_gemini_response(@json.parse(response_body)).unwrap_or(
          TokenUsage::empty(),
        ) catch {
          _ => TokenUsage::empty()
        }
        self.stats.record_success_usage(usage, response_body.length())
      } else {
        self.stats.record_upstream_error(response_body.length())
      }
      w.header().set("Content-Type", "application/json")
      w.write_header(response.code)
      w.write(response_body)
    }
  }
  w.flush()
}

///|
async fn Gateway::forward_non_streaming_chat_completion(
  self : Gateway,
  request : Json,
  response_model : String,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    self.stats.record_unauthorized()
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write(
      "{\"error\":{\"message\":\"Not authenticated. Please login first.\",\"type\":\"authentication_error\"}}",
    )
    w.flush()
    return
  }
  let client = self.codex_client(creds, accept="application/json")
  defer client.close()
  let response = client.post("/backend-api/codex/responses", request)
  let response_body = client.read_all().text()
  if response.code != 200 {
    self.stats.record_upstream_error(response_body.length())
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write(response_body)
    w.flush()
    return
  }
  let parsed : Result[Json, Error] = try? @json.parse(response_body)
  match parsed {
    Ok(json) => {
      let usage = token_usage_from_codex_response_auto(json).unwrap_or(
        TokenUsage::empty(),
      )
      let chat_response = codex_response_to_openai_chat_completion(
        json, response_model,
      )
      self.stats.record_success_usage(usage, chat_response.stringify().length())
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.Ok)
      w.write(chat_response.stringify())
    }
    Err(_) => {
      self.stats.record_internal_error()
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.InternalServerError)
      w.write(
        "{\"error\":{\"message\":\"Failed to parse Codex response\",\"type\":\"server_error\"}}",
      )
    }
  }
  w.flush()
}

///|
async fn Gateway::forward_streaming_chat_completion(
  self : Gateway,
  request : Json,
  response_model : String,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    self.stats.record_unauthorized()
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write(
      "{\"error\":{\"message\":\"Not authenticated. Please login first.\",\"type\":\"authentication_error\"}}",
    )
    w.flush()
    return
  }
  let client = self.codex_client(creds, accept="text/event-stream")
  defer client.close()
  let response = client.post("/backend-api/codex/responses", request)
  if response.code != 200 {
    let error_body = client.read_all().text()
    self.stats.record_upstream_error(error_body.length())
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write(error_body)
    w.flush()
    return
  }
  w.header().set("Content-Type", "text/event-stream")
  w.header().set("Cache-Control", "no-cache")
  w.header().set("Connection", "keep-alive")
  w.write_header(@status.Ok)
  let id = generate_chat_completion_id()
  let created = @async.now().to_int() / 1000
  w.write(
    "data: \{openai_chat_role_chunk(id, response_model, created).stringify()}\n\n",
  )
  w.flush()
  let mut response_bytes = 0
  while client.read_until("\n") is Some(line) {
    guard line is [.. "data: ", .. rest] else { continue }
    let data = rest.trim().to_owned()
    if data == "[DONE]" {
      break
    }
    if codex_stream_event_to_openai_chat_chunk(
        data, id, response_model, created,
      )
      is Some(chunk) {
      let payload = chunk.stringify()
      response_bytes += payload.length()
      w.write("data: \{payload}\n\n")
      w.flush()
    }
  }
  self.stats.record_success(0, 0, response_bytes)
  w.write("data: [DONE]\n\n")
  w.flush()
}

///|
async fn Gateway::forward_non_streaming_codex_response(
  self : Gateway,
  request : Json,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    self.stats.record_unauthorized()
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write(
      "{\"error\":{\"message\":\"Not authenticated. Please login first.\",\"type\":\"authentication_error\"}}",
    )
    w.flush()
    return
  }
  let client = self.codex_client(creds, accept="application/json")
  defer client.close()
  let response = client.post("/backend-api/codex/responses", request)
  let response_body = client.read_all().text()
  if response.code != 200 {
    self.stats.record_upstream_error(response_body.length())
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write(response_body)
    w.flush()
    return
  }
  let usage = try {
    let json = @json.parse(response_body)
    token_usage_from_codex_response_auto(json).unwrap_or(TokenUsage::empty())
  } catch {
    _ => TokenUsage::empty()
  }
  self.stats.record_success_usage(usage, response_body.length())
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(response_body)
  w.flush()
}

///|
async fn Gateway::forward_streaming_codex_response(
  self : Gateway,
  request : Json,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    self.stats.record_unauthorized()
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write(
      "{\"error\":{\"message\":\"Not authenticated. Please login first.\",\"type\":\"authentication_error\"}}",
    )
    w.flush()
    return
  }
  let client = self.codex_client(creds, accept="text/event-stream")
  defer client.close()
  let response = client.post("/backend-api/codex/responses", request)
  if response.code != 200 {
    let error_body = client.read_all().text()
    self.stats.record_upstream_error(error_body.length())
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write(error_body)
    w.flush()
    return
  }
  w.header().set("Content-Type", "text/event-stream")
  w.header().set("Cache-Control", "no-cache")
  w.header().set("Connection", "keep-alive")
  w.write_header(@status.Ok)
  let mut response_bytes = 0
  while client.read_until("\n") is Some(line) {
    response_bytes += line.length() + 1
    w.write(line)
    w.write("\n")
    w.flush()
  }
  self.stats.record_success(0, 0, response_bytes)
  w.flush()
}

///|
async fn Gateway::codex_client(
  self : Gateway,
  creds : @codex.Credentials,
  accept~ : String,
) -> @http.Client {
  let _ = self
  @http.Client::new("https://chatgpt.com", headers={
    "Authorization": "Bearer \{creds.accessToken}",
    "ChatGPT-Account-ID": creds.accountId,
    "Content-Type": "application/json",
    "Accept": accept,
    "originator": "moonstat_gateway",
    "User-Agent": "moonstat/1.0.0",
  })
}

///|
fn normalize_codex_oauth_request(json : Json) -> Json {
  guard json is Object(obj) else { return json }
  obj["store"] = Json::boolean(false)
  if obj.get("instructions") is None {
    obj["instructions"] = Json::string("")
  }
  if obj.get("tools") is None {
    obj["tools"] = Json::array([])
  }
  if obj.get("parallel_tool_calls") is None {
    obj["parallel_tool_calls"] = Json::boolean(false)
  }
  Json::object(obj)
}

///|
fn json_bool_field(json : Json, key : String) -> Bool? {
  guard json is Object(obj) else { return None }
  match obj.get(key) {
    Some(true) => Some(true)
    Some(false) => Some(false)
    _ => None
  }
}

///|
fn normalize_gemini_endpoint(path : StringView) -> String {
  let raw = path.to_owned()
  if raw.has_prefix("/gemini/v1beta/") {
    "/v1beta/\{raw["/gemini/v1beta/".length():]}"
  } else if raw.has_prefix("/gemini/v1/") {
    "/v1/\{raw["/gemini/v1/".length():]}"
  } else {
    raw
  }
}

///|
fn gemini_proxy_url(endpoint : String) -> String? {
  let base = "https://generativelanguage.googleapis.com"
  if endpoint.contains("?key=") || endpoint.contains("&key=") {
    Some("\{base}\{endpoint}")
  } else {
    match gemini_api_key() {
      Some(key) =>
        if endpoint.contains("?") {
          Some("\{base}\{endpoint}&key=\{key}")
        } else {
          Some("\{base}\{endpoint}?key=\{key}")
        }
      None => None
    }
  }
}

///|
fn gemini_api_key() -> String? {
  match getenv_or_none("GEMINI_API_KEY") {
    Some(key) if !key.is_empty() => Some(key)
    _ =>
      match getenv_or_none("GOOGLE_API_KEY") {
        Some(key) if !key.is_empty() => Some(key)
        _ => None
      }
  }
}

///|
fn getenv_or_none(key : String) -> String? {
  @os.getenv(key) catch {
    _ => None
  }
}

///|
fn gemini_request_is_stream(endpoint : String, body : Json) -> Bool {
  endpoint.contains("streamGenerateContent") ||
  json_bool_field(body, "stream").unwrap_or(false)
}

///|
async fn Gateway::handle_status(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(
    self.stats
    .status_json(
      self.host,
      self.port,
      self.uptime_seconds(),
      "codex",
      "codex-oauth",
    )
    .stringify(indent=2),
  )
  w.flush()
}

///|
async fn Gateway::handle_stats(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(self.stats.to_json().stringify(indent=2))
  w.flush()
}

///|
async fn Gateway::handle_models(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  let model : Map[String, Json] = {
    "id": Json::string(self.model),
    "object": Json::string("model"),
    "owned_by": Json::string("moonstat"),
  }
  let codex_model : Map[String, Json] = {
    "id": Json::string(self.model),
    "name": Json::string(self.model),
    "provider": Json::string("codex-oauth"),
  }
  let response : Map[String, Json] = {
    "models": Json::array([codex_model.to_json()]),
    "object": Json::string("list"),
    "data": Json::array([model.to_json()]),
  }
  w.write(response.to_json().stringify())
  w.flush()
}

///|
fn Gateway::uptime_seconds(self : Gateway) -> Int {
  let elapsed = @async.now().to_int() - self.started_at_ms
  if elapsed < 0 {
    0
  } else {
    elapsed / 1000
  }
}

///|
async fn Gateway::write_static_file(
  self : Gateway,
  w : @httpx.ResponseWriter,
  path : String,
  content_type : String,
) -> Unit {
  let result : Result[String, Error] = try? @fsx.read_file(path)
  match result {
    Ok(content) => {
      w.header().set("Content-Type", content_type)
      w.write_header(@status.Ok)
      w.write(content)
    }
    Err(error) => {
      self.logger.error("Failed to serve static file \{path}: \{error}")
      w.header().set("Content-Type", "text/plain; charset=utf-8")
      w.write_header(@status.NotFound)
      w.write("Not Found")
    }
  }
  w.flush()
}

///|
async fn Gateway::handle_login(
  self : Gateway,
  _r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  try {
    let creds = @codex.start_oauth_flow()
    self.credentials = Some(creds)
    self.logger.info("Login successful")
    w.write_header(@status.Ok)
    w.write("{\"status\":\"ok\",\"message\":\"Login successful\"}")
  } catch {
    _ => {
      self.logger.error("Login failed")
      w.write_header(@status.InternalServerError)
      w.write("{\"error\":\"Login failed\"}")
    }
  }
  w.flush()
}

///|
async fn Gateway::handle_messages(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = r.body.read_all()
  let body_str = body.text()
  self.stats.record_inbound(body_str.length())
  let json_result : Result[Json, Error] = try? @json.parse(body_str)
  match json_result {
    Err(_) => {
      self.stats.record_bad_request()
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadRequest)
      w.write("{\"error\":\"Invalid JSON\"}")
      w.flush()
      return
    }
    Ok(json) => {
      let anthropic_request_result : Result[AnthropicRequest, Error] = try? @json.from_json(
        json,
      )
      match anthropic_request_result {
        Err(_) => {
          self.stats.record_bad_request()
          w.header().set("Content-Type", "application/json")
          w.write_header(@status.BadRequest)
          w.write("{\"error\":\"Invalid Anthropic request\"}")
          w.flush()
          return
        }
        Ok(anthropic_request) => {
          self.logger.info(
            "Received Anthropic request for model: \{anthropic_request.model}",
          )
          let model = self.model
          self.logger.debug("Using Codex model: \{model}")
          let stream = anthropic_request.stream.unwrap_or(false)
          self.stats.record_stream_mode(stream)
          if stream {
            self.handle_streaming_request(anthropic_request, model, w)
          } else {
            self.handle_non_streaming_request(anthropic_request, model, w)
          }
        }
      }
    }
  }
}

///|
async fn Gateway::handle_non_streaming_request(
  self : Gateway,
  request : AnthropicRequest,
  model : String,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    self.stats.record_unauthorized()
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write("{\"error\":\"Not authenticated. Please login first.\"}")
    w.flush()
    return
  }
  let codex_input = convert_anthropic_to_codex(request, model)
  let codex_request = build_codex_request(codex_input, model, false)
  self.logger.debug("Sending request to Codex API")
  let client = @http.Client::new("https://chatgpt.com", headers={
    "Authorization": "Bearer \{creds.accessToken}",
    "ChatGPT-Account-ID": creds.accountId,
    "Content-Type": "application/json",
    "Accept": "application/json",
    "originator": "moonstat_gateway",
    "User-Agent": "moonstat/1.0.0",
  })
  defer client.close()
  let response = client.post("/backend-api/codex/responses", codex_request)
  if response.code != 200 {
    let error_body = client.read_all().text()
    self.logger.error("Codex API error: \{response.code} - \{error_body}")
    if response.code == 401 {
      self.logger.info("Attempting to refresh credentials")
      let refresh_result : Result[@codex.Credentials, Error] = try? @codex.refresh_and_save_credentials()
      match refresh_result {
        Ok(new_creds) => {
          self.credentials = Some(new_creds)
          self.logger.info("Credentials refreshed, retrying request")
          self.handle_non_streaming_request(request, model, w)
          return
        }
        Err(_) => ()
      }
    }
    self.stats.record_upstream_error(error_body.length())
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write("{\"error\":\"Codex API error: \{response.code}\"}")
    w.flush()
    return
  }
  let response_body = client.read_all().text()
  let response_json_result : Result[Json, Error] = try? @json.parse(
    response_body,
  )
  match response_json_result {
    Ok(json) => {
      let usage = token_usage_from_codex_response_auto(json).unwrap_or(
        TokenUsage::empty(),
      )
      self.stats.record_success_usage(usage, response_body.length())
      let anthropic_response = convert_codex_to_anthropic(json, request.model)
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.Ok)
      w.write(anthropic_response.to_json().stringify())
    }
    Err(_) => {
      self.stats.record_internal_error()
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.InternalServerError)
      w.write("{\"error\":\"Failed to parse Codex response\"}")
    }
  }
  w.flush()
}

///|
async fn Gateway::handle_streaming_request(
  self : Gateway,
  request : AnthropicRequest,
  model : String,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    self.stats.record_unauthorized()
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write("{\"error\":\"Not authenticated. Please login first.\"}")
    w.flush()
    return
  }
  let codex_input = convert_anthropic_to_codex(request, model)
  let codex_request = build_codex_request(codex_input, model, true)
  self.logger.debug("Sending streaming request to Codex API")
  let client = @http.Client::new("https://chatgpt.com", headers={
    "Authorization": "Bearer \{creds.accessToken}",
    "ChatGPT-Account-ID": creds.accountId,
    "Content-Type": "application/json",
    "Accept": "text/event-stream",
    "originator": "moonstat_gateway",
    "User-Agent": "moonstat/1.0.0",
  })
  defer client.close()
  let response = client.post("/backend-api/codex/responses", codex_request)
  if response.code != 200 {
    let error_body = client.read_all().text()
    self.logger.error("Codex API error: \{response.code} - \{error_body}")
    if response.code == 401 {
      self.logger.info("Attempting to refresh credentials")
      let refresh_result : Result[@codex.Credentials, Error] = try? @codex.refresh_and_save_credentials()
      match refresh_result {
        Ok(new_creds) => {
          self.credentials = Some(new_creds)
          self.logger.info("Credentials refreshed, retrying request")
          self.handle_streaming_request(request, model, w)
          return
        }
        Err(_) => ()
      }
    }
    self.stats.record_upstream_error(error_body.length())
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write("{\"error\":\"Codex API error: \{response.code}\"}")
    w.flush()
    return
  }
  w.header().set("Content-Type", "text/event-stream")
  w.header().set("Cache-Control", "no-cache")
  w.header().set("Connection", "keep-alive")
  w.write_header(@status.Ok)
  let reader = CodexStreamReader::new(client, request.model)
  while reader.read() is Some(event) {
    w.write("event: \{event.event_type}\n")
    w.write("data: \{event.data}\n\n")
    w.flush()
  }
  self.stats.record_success(0, 0, 0)
  w.write("event: message_stop\ndata: {}\n\n")
  w.flush()
}

///|
fn convert_codex_to_anthropic(
  codex_json : Json,
  model : String,
) -> AnthropicResponse {
  let content : Array[AnthropicResponseBlock] = []
  let mut input_tokens = 0
  let mut output_tokens = 0
  let id = generate_message_id()
  guard codex_json is Object(obj) else {
    return build_anthropic_response(id, model, "", [], 0, 0)
  }
  if obj.get("output") is Some(Array(outputs)) {
    for output in outputs {
      guard output is Object(out_obj) else { continue }
      let type_ = match out_obj.get("type") {
        Some(String(t)) => t
        _ => continue
      }
      if type_ == "message" {
        if out_obj.get("content") is Some(Array(content_parts)) {
          for part in content_parts {
            guard part is Object(part_obj) else { continue }
            if part_obj.get("type") is Some(String("output_text")) {
              if part_obj.get("text") is Some(String(text)) {
                content.push({
                  type_: "text",
                  text: Some(text),
                  name: None,
                  input: None,
                  id: None,
                })
              }
            }
          }
        }
      } else if type_ == "function_call" {
        let name = match out_obj.get("name") {
          Some(String(n)) => n
          _ => "unknown"
        }
        let args = match out_obj.get("arguments") {
          Some(String(a)) => a
          _ => "{}"
        }
        let call_id = match out_obj.get("call_id") {
          Some(String(id)) => id
          _ => generate_message_id()
        }
        let args_json_result : Result[Json, Error] = try? @json.parse(args)
        let args_json = match args_json_result {
          Ok(j) => j
          Err(_) => Json::object({})
        }
        content.push({
          type_: "tool_use",
          text: None,
          name: Some(name),
          input: Some(args_json),
          id: Some(call_id),
        })
      }
    }
  }
  if obj.get("usage") is Some(Object(usage_obj)) {
    input_tokens = match usage_obj.get("input_tokens") {
      Some(Number(n, ..)) => n.trunc().to_int()
      _ => 0
    }
    output_tokens = match usage_obj.get("output_tokens") {
      Some(Number(n, ..)) => n.trunc().to_int()
      _ => 0
    }
  }
  let has_tools = content.iter().any(fn(b) { b.type_ == "tool_use" })
  let stop_reason = if has_tools { "tool_use" } else { "end_turn" }
  {
    id,
    type_: "message",
    role: "assistant",
    content,
    model,
    stop_reason: Some(stop_reason),
    stop_sequence: None,
    usage: { input_tokens, output_tokens },
  }
}

///|
fn generate_message_id() -> String {
  let gen = @uuid.generator(@random.Rand::new())
  let uuid = gen.v4()
  "msg_\{uuid}"
}

///|
priv struct StreamEvent {
  event_type : String
  data : String
}

///|
priv struct CodexStreamReader {
  reader : &@io.Reader
  model : String
}

///|
fn CodexStreamReader::new(
  reader : &@io.Reader,
  model : String,
) -> CodexStreamReader {
  CodexStreamReader::{ reader, model }
}

///|
async fn CodexStreamReader::read(self : CodexStreamReader) -> StreamEvent? {
  for ;; {
    guard self.reader.read_until("\n") is Some(line) else { return None }
    guard line is [.. "data: ", .. rest] else { continue }
    let data = rest.trim().to_string()
    if data == "[DONE]" {
      return None
    }
    let json_result : Result[Json, Error] = try? @json.parse(data)
    guard json_result is Ok(Object(_)) else { return None }
    let json = json_result.unwrap()
    guard json is Object(obj) else { return None }
    let event_type = match obj.get("type") {
      Some(String(t)) => t
      _ => return None
    }
    let anthropic_event = convert_stream_event(event_type, obj, self.model)
    match anthropic_event {
      Some(event) => return Some(event)
      None => return None
    }
  }
}

///|
fn convert_stream_event(
  event_type : String,
  obj : Map[String, Json],
  _model : String,
) -> StreamEvent? {
  match event_type {
    "response.output_text.delta" => {
      let delta = match obj.get("delta") {
        Some(String(d)) => d
        _ => return None
      }
      let event_data : Map[String, Json] = {
        "type": Json::string("content_block_delta"),
        "index": Json::number(0.0),
        "delta": {
          "type": Json::string("text_delta"),
          "text": Json::string(delta),
        }.to_json(),
      }
      Some({
        event_type: "content_block_delta",
        data: event_data.to_json().stringify(),
      })
    }
    "response.output_item.done" => {
      if obj.get("item") is Some(item_json) {
        let item : Json = item_json
        guard item is Object(item_obj) else { return None }
        let type_ = match item_obj.get("type") {
          Some(String(t)) => t
          _ => return None
        }
        if type_ == "function_call" {
          let name = match item_obj.get("name") {
            Some(String(n)) => n
            _ => "unknown"
          }
          let args = match item_obj.get("arguments") {
            Some(String(a)) => a
            _ => "{}"
          }
          let call_id = match item_obj.get("call_id") {
            Some(String(id)) => id
            _ => generate_message_id()
          }
          let args_json_result : Result[Json, Error] = try? @json.parse(args)
          let args_json = match args_json_result {
            Ok(j) => j
            Err(_) => Json::object({})
          }
          let event_data : Map[String, Json] = {
            "type": Json::string("content_block_start"),
            "index": Json::number(1.0),
            "content_block": {
              "type": Json::string("tool_use"),
              "id": Json::string(call_id),
              "name": Json::string(name),
              "input": args_json,
            }.to_json(),
          }
          return Some({
            event_type: "content_block_start",
            data: event_data.to_json().stringify(),
          })
        }
      }
      None
    }
    "response.completed" => {
      let event_data : Map[String, Json] = {
        "type": Json::string("message_delta"),
        "delta": { "stop_reason": Json::string("end_turn") }.to_json(),
        "usage": { "output_tokens": Json::number(0.0) }.to_json(),
      }
      Some({
        event_type: "message_delta",
        data: event_data.to_json().stringify(),
      })
    }
    _ => None
  }
}
