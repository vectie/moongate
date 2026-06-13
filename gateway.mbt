///|
pub struct Gateway {
  host : String
  port : Int
  model : String
  mut credentials : @codex.Credentials?
  stats : TrafficStats
  provider_router : ProviderRouter
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
    provider_router: moonstat_default_provider_router(),
    logger,
    started_at_ms: @async.now().to_int(),
  }
}

///|
fn moonstat_default_provider_router() -> ProviderRouter {
  let router = ProviderRouter::new()
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="codex-oauth",
      provider_name="Codex OAuth",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude-desktop",
      provider_id="codex-oauth",
      provider_name="Codex OAuth",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-oauth",
      provider_name="Codex OAuth",
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="gemini",
      provider_id="gemini-api-key",
      provider_name="Gemini API Key",
    ),
  )
  router.set_current_provider("claude", "codex-oauth")
  router.set_current_provider("claude-desktop", "codex-oauth")
  router.set_current_provider("codex", "codex-oauth")
  router.set_current_provider("gemini", "gemini-api-key")
  router
}

///|
fn Gateway::activate_provider(
  self : Gateway,
  app_type : String,
) -> ProviderRouteTarget? {
  let selected = self.provider_router.select_providers(app_type)
  guard selected.error is None else { return None }
  self.activate_first_available_provider(app_type, selected.providers)
}

///|
fn Gateway::activate_first_available_provider(
  self : Gateway,
  app_type : String,
  providers : Array[ProviderRouteTarget],
) -> ProviderRouteTarget? {
  self.activate_first_available_provider_excluding(app_type, providers, [])
}

///|
fn Gateway::activate_first_available_provider_excluding(
  self : Gateway,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
) -> ProviderRouteTarget? {
  for provider in providers {
    if attempted_provider_ids.contains(provider.provider_id) {
      continue
    }
    if self.activate_provider_target(app_type, provider) {
      return Some(provider)
    }
  }
  None
}

///|
fn Gateway::activate_provider_target(
  self : Gateway,
  app_type : String,
  provider : ProviderRouteTarget,
) -> Bool {
  let allow = self.provider_router.allow_provider_request(
    provider.provider_id,
    app_type,
  )
  guard allow.allowed else { return false }
  self.stats.current_request_used_half_open_permit = allow.used_half_open_permit
  self.stats.set_active_target(
    app_type,
    provider.provider_id,
    provider.provider_name,
  )
  true
}

///|
fn Gateway::record_provider_result(self : Gateway, success : Bool) -> Unit {
  guard self.stats.current_request_app_type is Some(app_type) else { return }
  guard self.stats.current_provider_id is Some(provider_id) else { return }
  self.provider_router.record_result(
    provider_id,
    app_type,
    self.stats.current_request_used_half_open_permit,
    success,
  )
}

///|
fn Gateway::release_provider_permit_neutral(self : Gateway) -> Unit {
  guard self.stats.current_request_app_type is Some(app_type) else { return }
  guard self.stats.current_provider_id is Some(provider_id) else { return }
  self.provider_router.release_permit_neutral(
    provider_id,
    app_type,
    self.stats.current_request_used_half_open_permit,
  )
}

///|
fn ccs_upstream_status_retryable(status_code : Int) -> Bool {
  match status_code {
    400 | 405 | 406 | 413 | 414 | 415 | 422 | 501 => false
    _ => true
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
async fn Gateway::record_bad_request(self : Gateway) -> Unit {
  self.release_provider_permit_neutral()
  self.stats.record_bad_request()
  self.stats.save_persistent_store()
}

///|
async fn Gateway::record_unauthorized(self : Gateway) -> Unit {
  self.release_provider_permit_neutral()
  self.stats.record_unauthorized()
  self.stats.save_persistent_store()
}

///|
async fn Gateway::record_upstream_error_status(
  self : Gateway,
  response_bytes : Int,
  status_code : Int,
) -> Unit {
  if ccs_upstream_status_retryable(status_code) {
    self.record_provider_result(false)
  } else {
    self.release_provider_permit_neutral()
  }
  self.stats.record_upstream_error_status(response_bytes, status_code)
  self.stats.save_persistent_store()
}

///|
async fn Gateway::record_internal_error(self : Gateway) -> Unit {
  self.release_provider_permit_neutral()
  self.stats.record_internal_error()
  self.stats.save_persistent_store()
}

///|
async fn Gateway::record_success(
  self : Gateway,
  input_tokens : Int,
  output_tokens : Int,
  response_bytes : Int,
) -> Unit {
  self.record_provider_result(true)
  self.stats.record_success(input_tokens, output_tokens, response_bytes)
  self.stats.save_persistent_store()
}

///|
async fn Gateway::record_success_usage(
  self : Gateway,
  usage : TokenUsage,
  response_bytes : Int,
) -> Unit {
  self.record_provider_result(true)
  self.stats.record_success_usage(usage, response_bytes)
  self.stats.save_persistent_store()
}

///|
pub async fn Gateway::start(self : Gateway) -> Unit {
  self.logger.info(
    "Starting Anthropic -> Codex OAuth Gateway on \{self.host}:\{self.port}",
  )
  self.stats.load_persistent_store()
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
    self.handle_codex_responses(r, w, compact=true)
  })
  router.add_handler(@httpx.Method::Post, "/v1/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w, compact=true)
  })
  router.add_handler(@httpx.Method::Post, "/v1/v1/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w, compact=true)
  })
  router.add_handler(@httpx.Method::Post, "/codex/v1/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w, compact=true)
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
  router.add_handler(@httpx.Method::Get, "/usage/logs", (_, w) => {
    self.handle_usage_logs(w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/summary", (_, w) => {
    self.handle_usage_summary(w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/summary/by-app", (_, w) => {
    self.handle_usage_summary_by_app(w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/trends", (r, w) => {
    self.handle_usage_trends(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/provider-limits", (r, w) => {
    self.handle_usage_provider_limits(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/provider-stats", (_, w) => {
    self.handle_usage_provider_stats(w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/model-stats", (_, w) => {
    self.handle_usage_model_stats(w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/data-sources", (_, w) => {
    self.handle_usage_data_sources(w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/sync-session", (r, w) => {
    self.handle_usage_sync_session(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/model-pricing", (_, w) => {
    self.handle_usage_model_pricing(w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/request-detail/*path", (r, w) => {
    self.handle_usage_request_detail(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/models", (_, w) => {
    self.handle_models(w)
  })
  router.add_handler(@httpx.Method::Get, "/v1/models", (_, w) => {
    self.handle_models(w)
  })
  router.add_handler(@httpx.Method::Get, "/claude-desktop/v1/models", (r, w) => {
    self.handle_claude_desktop_models(r, w)
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
  compact? : Bool = false,
) -> Unit {
  let body = r.body.read_all()
  let body_str = body.text()
  self.stats.record_inbound(body_str.length())
  let _ = self.activate_provider("codex")
  self.stats.record_request_context(
    "codex",
    self.model,
    provider_type=Some("codex"),
  )
  let json_result : Result[Json, Error] = try? @json.parse(body_str)
  match json_result {
    Err(_) => {
      self.record_bad_request()
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
      let session_id = extract_client_session_id(r.headers, json, "codex")
      self.stats.record_request_context(
        "codex",
        json_string_field(json, "model").unwrap_or(self.model),
        session_id~,
        provider_type=Some("codex"),
      )
      let endpoint = codex_backend_responses_endpoint(
        compact,
        request_path=r.path,
      )
      if stream {
        self.forward_streaming_codex_response(request, endpoint, session_id, w)
      } else {
        self.forward_non_streaming_codex_response(
          request, endpoint, session_id, w,
        )
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
  let _ = self.activate_provider("codex")
  self.stats.record_request_context(
    "codex",
    self.model,
    provider_type=Some("codex"),
  )
  let json_result : Result[Json, Error] = try? @json.parse(body_str)
  match json_result {
    Err(_) => {
      self.record_bad_request()
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
      let session_id = extract_client_session_id(r.headers, json, "openai")
      self.stats.record_request_context(
        "codex",
        response_model,
        session_id~,
        provider_type=Some("codex"),
      )
      let request = openai_chat_to_codex_response_request(json, self.model)
      guard request is Some(codex_request) else {
        self.record_bad_request()
        w.header().set("Content-Type", "application/json")
        w.write_header(@status.BadRequest)
        w.write(
          "{\"error\":{\"message\":\"Invalid Chat Completions request\",\"type\":\"invalid_request_error\"}}",
        )
        w.flush()
        return
      }
      if stream {
        self.forward_streaming_chat_completion(
          codex_request, response_model, session_id, w,
        )
      } else {
        self.forward_non_streaming_chat_completion(
          codex_request, response_model, session_id, w,
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
  let _ = self.activate_provider("gemini")
  self.stats.record_request_context(
    "gemini",
    "gemini",
    provider_type=Some("gemini"),
  )
  let request_json : Json = if body_str.is_empty() {
    Json::null()
  } else {
    @json.parse(body_str) catch {
      _ => {
        self.record_bad_request()
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
  self.stats.record_request_context(
    "gemini",
    gemini_model_from_endpoint(endpoint),
    provider_type=Some("gemini"),
  )
  self.stats.record_stream_mode(
    gemini_request_is_stream(endpoint, request_json),
  )
  let url = match gemini_proxy_url(endpoint) {
    Some(url) => url
    None => {
      self.record_unauthorized()
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
      self.record_bad_request()
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
      self.record_upstream_error_status(0, @status.BadGateway)
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadGateway)
      w.write(
        "{\"error\":{\"message\":\"Gemini upstream request failed: \{error}\",\"type\":\"upstream_error\"}}",
      )
    }
    Ok((response, data)) => {
      let response_body = data.text()
      if response.code is (200..=299) {
        self.record_success_usage(TokenUsage::empty(), response_body.length())
      } else {
        self.record_upstream_error_status(response_body.length(), response.code)
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
      self.record_upstream_error_status(0, @status.BadGateway)
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
        self.record_success_usage(usage, response_body.length())
      } else {
        self.record_upstream_error_status(response_body.length(), response.code)
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
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    self.record_unauthorized()
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write(
      "{\"error\":{\"message\":\"Not authenticated. Please login first.\",\"type\":\"authentication_error\"}}",
    )
    w.flush()
    return
  }
  let client = self.codex_client(creds, accept="application/json", session_id~)
  defer client.close()
  let response = client.post("/backend-api/codex/responses", request)
  let response_body = client.read_all().text()
  if response.code != 200 {
    self.record_upstream_error_status(response_body.length(), response.code)
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
      self.record_success_usage(usage, chat_response.stringify().length())
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.Ok)
      w.write(chat_response.stringify())
    }
    Err(_) => {
      self.record_internal_error()
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
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    self.record_unauthorized()
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write(
      "{\"error\":{\"message\":\"Not authenticated. Please login first.\",\"type\":\"authentication_error\"}}",
    )
    w.flush()
    return
  }
  let client = self.codex_client(creds, accept="text/event-stream", session_id~)
  defer client.close()
  let response = client.post("/backend-api/codex/responses", request)
  if response.code != 200 {
    let error_body = client.read_all().text()
    self.record_upstream_error_status(error_body.length(), response.code)
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
  self.record_success(0, 0, response_bytes)
  w.write("data: [DONE]\n\n")
  w.flush()
}

///|
async fn Gateway::forward_non_streaming_codex_response(
  self : Gateway,
  request : Json,
  endpoint : String,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    self.record_unauthorized()
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write(
      "{\"error\":{\"message\":\"Not authenticated. Please login first.\",\"type\":\"authentication_error\"}}",
    )
    w.flush()
    return
  }
  let client = self.codex_client(creds, accept="application/json", session_id~)
  defer client.close()
  let response = client.post(endpoint, request)
  let response_body = client.read_all().text()
  if response.code != 200 {
    self.record_upstream_error_status(response_body.length(), response.code)
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
  self.record_success_usage(usage, response_body.length())
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(response_body)
  w.flush()
}

///|
async fn Gateway::forward_streaming_codex_response(
  self : Gateway,
  request : Json,
  endpoint : String,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    self.record_unauthorized()
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write(
      "{\"error\":{\"message\":\"Not authenticated. Please login first.\",\"type\":\"authentication_error\"}}",
    )
    w.flush()
    return
  }
  let client = self.codex_client(creds, accept="text/event-stream", session_id~)
  defer client.close()
  let response = client.post(endpoint, request)
  if response.code != 200 {
    let error_body = client.read_all().text()
    self.record_upstream_error_status(error_body.length(), response.code)
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
  self.record_success(0, 0, response_bytes)
  w.flush()
}

///|
fn codex_backend_responses_endpoint(
  compact : Bool,
  request_path? : StringView = "",
) -> String {
  let base = if compact {
    "/backend-api/codex/responses/compact"
  } else {
    "/backend-api/codex/responses"
  }
  endpoint_with_request_query(base, request_path)
}

///|
fn endpoint_with_request_query(
  endpoint : String,
  request_path : StringView,
) -> String {
  match request_path.find("?") {
    Some(index) => "\{endpoint}?\{request_path[index + 1:]}"
    None => endpoint
  }
}

///|
async fn Gateway::codex_client(
  self : Gateway,
  creds : @codex.Credentials,
  accept~ : String,
  session_id? : String? = None,
) -> @http.Client {
  let _ = self
  @http.Client::new(
    "https://chatgpt.com",
    headers=codex_oauth_headers(creds, accept, session_id),
  )
}

///|
fn codex_oauth_headers(
  creds : @codex.Credentials,
  accept : String,
  session_id : String?,
) -> Map[String, String] {
  let headers : Map[String, String] = {
    "Authorization": "Bearer \{creds.accessToken}",
    "ChatGPT-Account-ID": creds.accountId,
    "Content-Type": "application/json",
    "Accept": accept,
    "originator": "moonstat_gateway",
    "User-Agent": "moonstat/1.0.0",
  }
  match session_id {
    Some(id) => {
      headers["session_id"] = id
      headers["x-client-request-id"] = id
      headers["x-codex-window-id"] = id
    }
    None => ()
  }
  headers
}

///|
fn extract_client_session_id(
  headers : Map[String, String],
  body : Json,
  client_format : String,
) -> String? {
  if client_format == "claude" {
    match extract_claude_session_id(headers, body) {
      Some(id) => return Some(id)
      None => ()
    }
  }
  if client_format == "codex" || client_format == "openai" {
    match extract_codex_session_id(headers, body) {
      Some(id) => return Some(id)
      None => ()
    }
  }
  extract_session_from_metadata(body)
}

///|
fn extract_claude_session_id(
  headers : Map[String, String],
  body : Json,
) -> String? {
  for name in ["x-claude-code-session-id", "claude-code-session-id"] {
    match headers.get(name) {
      Some(value) if !value.is_empty() => return Some(value)
      _ => ()
    }
  }
  extract_session_from_metadata(body)
}

///|
fn extract_codex_session_id(
  headers : Map[String, String],
  body : Json,
) -> String? {
  for name in ["session_id", "x-session-id"] {
    match headers.get(name) {
      Some(value) if value.length() > 20 => return Some("codex_\{value}")
      _ => ()
    }
  }
  match json_metadata_string(body, "session_id") {
    Some(value) if value.length() > 10 => Some("codex_\{value}")
    _ => None
  }
}

///|
fn extract_session_from_metadata(body : Json) -> String? {
  match json_metadata_string(body, "user_id") {
    Some(user_id) =>
      match parse_session_from_user_id(user_id) {
        Some(id) => return Some(id)
        None => ()
      }
    None => ()
  }
  match json_metadata_string(body, "session_id") {
    Some(id) if !id.is_empty() => Some(id)
    _ => None
  }
}

///|
fn json_metadata_string(body : Json, key : String) -> String? {
  guard body is Object(obj) else { return None }
  guard obj.get("metadata") is Some(Object(metadata)) else { return None }
  match metadata.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn parse_session_from_user_id(user_id : String) -> String? {
  match user_id.find("_session_") {
    Some(index) => {
      let start = index + "_session_".length()
      let session_id = user_id[start:]
      if session_id.is_empty() {
        None
      } else {
        Some(session_id.to_owned())
      }
    }
    None => None
  }
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
fn json_string_field(json : Json, key : String) -> String? {
  guard json is Object(obj) else { return None }
  match obj.get(key) {
    Some(String(value)) if !value.is_empty() => Some(value)
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
fn gemini_model_from_endpoint(endpoint : String) -> String {
  match endpoint.find("/models/") {
    Some(index) => {
      let rest = endpoint[index + "/models/".length():]
      match rest.find(":") {
        Some(end) => normalize_gemini_model_id(rest[:end].to_owned())
        None => normalize_gemini_model_id(rest.to_owned())
      }
    }
    None => "gemini"
  }
}

///|
fn gemini_proxy_url(endpoint : String) -> String? {
  let url = resolve_gemini_native_url(
    gemini_base_url(),
    endpoint,
    gemini_base_is_full_url(),
  )
  if url_contains_query_key(url) {
    Some(url)
  } else {
    match gemini_api_key() {
      Some(key) =>
        if url.contains("?") {
          Some("\{url}&key=\{key}")
        } else {
          Some("\{url}?key=\{key}")
        }
      None => None
    }
  }
}

///|
fn gemini_base_url() -> String {
  match getenv_or_none("GOOGLE_GEMINI_BASE_URL") {
    Some(url) if !url.is_empty() => url
    _ =>
      match getenv_or_none("GEMINI_BASE_URL") {
        Some(url) if !url.is_empty() => url
        _ => "https://generativelanguage.googleapis.com"
      }
  }
}

///|
fn gemini_base_is_full_url() -> Bool {
  env_bool("MOONSTAT_GEMINI_FULL_URL") || env_bool("GEMINI_FULL_URL")
}

///|
fn url_contains_query_key(url : String) -> Bool {
  url.contains("?key=") || url.contains("&key=")
}

///|
fn env_bool(key : String) -> Bool {
  match getenv_or_none(key) {
    Some(value) => {
      let normalized = value.trim().to_lower()
      normalized == "1" ||
      normalized == "true" ||
      normalized == "yes" ||
      normalized == "on"
    }
    None => false
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
      provider_routes=Some(self.provider_router.route_stats_json()),
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
async fn Gateway::handle_usage_logs(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(self.stats.usage_logs_json().stringify(indent=2))
  w.flush()
}

///|
async fn Gateway::handle_usage_summary(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.stats.usage_summary_json())
}

///|
async fn Gateway::handle_usage_summary_by_app(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.stats.usage_summary_by_app_json())
}

///|
async fn Gateway::handle_usage_trends(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let start_ts = usage_query_int_any(r.path, "start_date", "startDate")
  let end_ts = usage_query_int_any(r.path, "end_date", "endDate")
  let app_type = usage_query_value_any(r.path, "app_type", "appType")
  write_usage_json(
    w,
    self.stats.usage_trends_json(start_ts~, end_ts~, app_type~),
  )
}

///|
async fn Gateway::handle_usage_provider_limits(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard usage_query_value_any(r.path, "provider_id", "providerId")
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard usage_query_value_any(r.path, "app_type", "appType") is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  let daily_limit_usd = usage_query_value_any(
    r.path,
    "daily_limit_usd",
    "dailyLimitUsd",
  )
  let monthly_limit_usd = usage_query_value_any(
    r.path,
    "monthly_limit_usd",
    "monthlyLimitUsd",
  )
  write_usage_json(
    w,
    self.stats.provider_limit_status_json(
      provider_id,
      app_type,
      daily_limit_usd~,
      monthly_limit_usd~,
    ),
  )
}

///|
async fn Gateway::handle_usage_provider_stats(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.stats.provider_stats_json())
}

///|
async fn Gateway::handle_usage_model_stats(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.stats.model_stats_json())
}

///|
async fn Gateway::handle_usage_data_sources(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.stats.usage_data_sources_json())
}

///|
async fn Gateway::handle_usage_sync_session(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let claude_projects_dir = usage_query_value_any(
    r.path,
    "projects_dir",
    "projectsDir",
  ).unwrap_or(default_claude_projects_dir())
  let codex_dir = usage_query_value_any(r.path, "codex_dir", "codexDir").unwrap_or(
    default_codex_config_dir(),
  )
  let gemini_dir = usage_query_value_any(r.path, "gemini_dir", "geminiDir").unwrap_or(
    default_gemini_dir(),
  )
  let opencode_export_path = usage_query_value_any(
    r.path,
    "opencode_export_path",
    "opencodeExportPath",
  ).unwrap_or(default_opencode_export_path())
  let opencode_db_path = usage_query_value_any(
    r.path,
    "opencode_db_path",
    "opencodeDbPath",
  ).unwrap_or(default_opencode_db_path())
  let result = self.stats.sync_session_logs(
    claude_projects_dir~,
    codex_dir~,
    gemini_dir~,
    opencode_db_path~,
    opencode_export_path~,
  )
  self.stats.save_persistent_store()
  write_usage_json(w, result.to_json())
}

///|
async fn Gateway::handle_usage_model_pricing(
  _self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, static_model_pricing_json())
}

///|
async fn Gateway::handle_usage_request_detail(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let request_id = usage_request_detail_id(r.path.to_owned())
  match self.stats.request_detail_json(request_id) {
    Some(detail) => write_usage_json(w, detail)
    None => {
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.NotFound)
      w.write(
        {
          "error": Json::string("request_not_found"),
          "requestId": Json::string(request_id),
        }
        .to_json()
        .stringify(indent=2),
      )
      w.flush()
    }
  }
}

///|
async fn write_usage_json(w : @httpx.ResponseWriter, body : Json) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(body.stringify(indent=2))
  w.flush()
}

///|
async fn write_usage_bad_request(
  w : @httpx.ResponseWriter,
  error : String,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.BadRequest)
  w.write({ "error": Json::string(error) }.to_json().stringify(indent=2))
  w.flush()
}

///|
fn usage_request_detail_id(path : String) -> String {
  let prefix = "/usage/request-detail/"
  if path.has_prefix(prefix) {
    path[prefix.length():].to_owned()
  } else {
    path
  }
}

///|
fn usage_query_value_any(
  path : StringView,
  left_key : String,
  right_key : String,
) -> String? {
  match usage_query_value(path, left_key) {
    Some(value) => Some(value)
    None => usage_query_value(path, right_key)
  }
}

///|
fn usage_query_int_any(
  path : StringView,
  left_key : String,
  right_key : String,
) -> Int? {
  match usage_query_value_any(path, left_key, right_key) {
    Some(value) =>
      try @string.parse_int(value, base=10) catch {
        _ => None
      } noraise {
        parsed => Some(parsed)
      }
    None => None
  }
}

///|
fn usage_query_value(path : StringView, key : String) -> String? {
  let text = path.to_owned()
  guard text.find("?") is Some(question_index) else { return None }
  let query = text[question_index + 1:]
  for pair_view in query.split("&") {
    let pair = pair_view.to_owned()
    guard pair.find("=") is Some(equal_index) else { continue }
    let pair_key = pair[:equal_index].to_owned()
    if pair_key == key {
      let value = pair[equal_index + 1:].to_owned()
      if value.is_empty() {
        return None
      }
      return Some(value)
    }
  }
  None
}

///|
async fn Gateway::handle_models(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  let models = live_codex_models_or_fallback(self.model)
  w.write(codex_models_response_json(models).stringify())
  w.flush()
}

///|
async fn live_codex_models_or_fallback(
  default_model : String,
) -> Array[CodexModel] {
  try @codex.load_credentials() catch {
    _ => static_codex_models(default_model)
  } noraise {
    creds =>
      match fetch_codex_oauth_models(creds) {
        Ok(models) if !models.is_empty() => models
        _ => static_codex_models(default_model)
      }
  }
}

///|
async fn Gateway::handle_claude_desktop_models(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.validate_claude_desktop_gateway_auth(r, w) else { return }
  let _ = self.activate_provider("claude-desktop")
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(claude_desktop_model_list_json().stringify())
  w.flush()
}

///|
async fn Gateway::validate_claude_desktop_gateway_auth(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Bool {
  let _ = self
  match @claude_desktop.gateway_token() {
    None => true
    Some(expected) =>
      if claude_desktop_authorization_valid(r.headers, expected) {
        true
      } else {
        self.record_unauthorized()
        write_auth_error(w, "Claude Desktop gateway token invalid or missing")
        false
      }
  }
}

///|
fn claude_desktop_authorization_valid(
  headers : Map[String, String],
  expected : String,
) -> Bool {
  let expected = expected.trim()
  if expected.is_empty() {
    return true
  }
  match headers.get("authorization") {
    Some(value) => bearer_token(value) == Some(expected.to_owned())
    None => false
  }
}

///|
fn bearer_token(value : String) -> String? {
  let trimmed = value.trim()
  if trimmed.has_prefix("Bearer ") {
    Some(trimmed["Bearer ".length():].trim().to_owned())
  } else if trimmed.has_prefix("bearer ") {
    Some(trimmed["bearer ".length():].trim().to_owned())
  } else {
    None
  }
}

///|
async fn write_auth_error(w : @httpx.ResponseWriter, message : String) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Unauthorized)
  w.write(
    "{\"error\":{\"message\":\"\{message}\",\"type\":\"authentication_error\"}}",
  )
  w.flush()
}

///|
fn claude_desktop_model_list_json() -> Json {
  let data = [
    claude_desktop_model_json("claude-sonnet-4-6"),
    claude_desktop_model_json("claude-opus-4-8"),
    claude_desktop_model_json("claude-haiku-4-5"),
  ]
  {
    "data": Json::array(data),
    "has_more": Json::boolean(false),
    "first_id": Json::string("claude-sonnet-4-6"),
    "last_id": Json::string("claude-haiku-4-5"),
  }.to_json()
}

///|
fn claude_desktop_model_json(id : String) -> Json {
  {
    "type": Json::string("model"),
    "id": Json::string(id),
    "created_at": Json::string("2024-01-01T00:00:00Z"),
    "supports1m": Json::boolean(true),
  }.to_json()
}

///|
fn normalize_claude_desktop_request_model(
  request : AnthropicRequest,
  app_type : String,
) -> AnthropicRequest {
  if app_type != "claude-desktop" {
    return request
  }
  let model = normalize_claude_desktop_model_id(request.model)
  if model == request.model {
    request
  } else {
    {
      model,
      max_tokens: request.max_tokens,
      messages: request.messages,
      system: request.system,
      tools: request.tools,
      stream: request.stream,
    }
  }
}

///|
fn normalize_claude_desktop_model_id(model : String) -> String {
  let trimmed = model.trim().to_owned()
  let route_id = strip_one_m_suffix_for_route_lookup(trimmed)
  if !is_claude_safe_model_id(route_id) {
    return model.trim().to_owned()
  }
  match claude_role_keyword(route_id) {
    Some("opus") => "claude-opus-4-8"
    Some("haiku") => "claude-haiku-4-5"
    Some("sonnet") => "claude-sonnet-4-6"
    _ => route_id
  }
}

///|
fn strip_one_m_suffix_for_route_lookup(model : String) -> String {
  let trimmed = model.trim().to_owned()
  let marker = "[1m]"
  if trimmed.to_lower().has_suffix(marker) {
    trimmed[:trimmed.length() - marker.length()].trim().to_owned()
  } else {
    trimmed
  }
}

///|
fn is_claude_safe_model_id(model : String) -> Bool {
  let normalized = model.trim().to_lower()
  if normalized.contains("[1m]") {
    return false
  }
  let tail = if normalized.has_prefix("anthropic/claude-") {
    normalized["anthropic/claude-".length():]
  } else if normalized.has_prefix("claude-") {
    normalized["claude-".length():]
  } else {
    return false
  }
  ["sonnet-", "opus-", "haiku-"].any(prefix => {
    tail.has_prefix(prefix) && tail.length() > prefix.length()
  })
}

///|
fn claude_role_keyword(model : String) -> String? {
  let normalized = model.to_lower()
  if normalized.contains("opus") {
    Some("opus")
  } else if normalized.contains("haiku") {
    Some("haiku")
  } else if normalized.contains("sonnet") {
    Some("sonnet")
  } else {
    None
  }
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
  let app_type = if r.path.has_prefix("/claude-desktop") {
    guard self.validate_claude_desktop_gateway_auth(r, w) else { return }
    "claude-desktop"
  } else {
    "claude"
  }
  let body = r.body.read_all()
  let body_str = body.text()
  self.stats.record_inbound(body_str.length())
  let _ = self.activate_provider(app_type)
  self.stats.record_request_context(
    app_type,
    self.model,
    provider_type=Some("claude"),
  )
  let json_result : Result[Json, Error] = try? @json.parse(body_str)
  match json_result {
    Err(_) => {
      self.record_bad_request()
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadRequest)
      w.write("{\"error\":\"Invalid JSON\"}")
      w.flush()
      return
    }
    Ok(json) => {
      let session_id = extract_client_session_id(r.headers, json, "claude")
      let anthropic_request_result : Result[AnthropicRequest, Error] = try? @json.from_json(
        json,
      )
      match anthropic_request_result {
        Err(_) => {
          self.record_bad_request()
          w.header().set("Content-Type", "application/json")
          w.write_header(@status.BadRequest)
          w.write("{\"error\":\"Invalid Anthropic request\"}")
          w.flush()
          return
        }
        Ok(anthropic_request) => {
          let anthropic_request = normalize_claude_desktop_request_model(
            anthropic_request, app_type,
          )
          self.logger.info(
            "Received Anthropic request for model: \{anthropic_request.model}",
          )
          let model = self.model
          self.logger.debug("Using Codex model: \{model}")
          let stream = anthropic_request.stream.unwrap_or(false)
          self.stats.record_stream_mode(stream)
          self.stats.record_request_context(
            app_type,
            anthropic_request.model,
            session_id~,
            provider_type=Some("claude"),
          )
          if stream {
            self.handle_streaming_request(
              anthropic_request, model, session_id, w,
            )
          } else {
            self.handle_non_streaming_request(
              anthropic_request, model, session_id, w,
            )
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
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    self.record_unauthorized()
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write("{\"error\":\"Not authenticated. Please login first.\"}")
    w.flush()
    return
  }
  let codex_input = convert_anthropic_to_codex(request, model)
  let codex_request = build_codex_request(codex_input, model, false)
  self.logger.debug("Sending request to Codex API")
  let client = @http.Client::new(
    "https://chatgpt.com",
    headers=codex_oauth_headers(creds, "application/json", session_id),
  )
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
          self.handle_non_streaming_request(request, model, session_id, w)
          return
        }
        Err(_) => ()
      }
    }
    self.record_upstream_error_status(error_body.length(), response.code)
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
      self.record_success_usage(usage, response_body.length())
      let anthropic_response = convert_codex_to_anthropic(json, request.model)
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.Ok)
      w.write(anthropic_response.to_json().stringify())
    }
    Err(_) => {
      self.record_internal_error()
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
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    self.record_unauthorized()
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write("{\"error\":\"Not authenticated. Please login first.\"}")
    w.flush()
    return
  }
  let codex_input = convert_anthropic_to_codex(request, model)
  let codex_request = build_codex_request(codex_input, model, true)
  self.logger.debug("Sending streaming request to Codex API")
  let client = @http.Client::new(
    "https://chatgpt.com",
    headers=codex_oauth_headers(creds, "text/event-stream", session_id),
  )
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
          self.handle_streaming_request(request, model, session_id, w)
          return
        }
        Err(_) => ()
      }
    }
    self.record_upstream_error_status(error_body.length(), response.code)
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
  self.record_success(0, 0, 0)
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
  let mut cache_read_tokens = 0
  let mut cache_creation_tokens = 0
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
    cache_read_tokens = match usage_obj.get("cache_read_input_tokens") {
      Some(Number(n, ..)) => n.trunc().to_int()
      _ =>
        match usage_obj.get("input_tokens_details") {
          Some(Object(details)) =>
            match details.get("cached_tokens") {
              Some(Number(n, ..)) => n.trunc().to_int()
              _ => 0
            }
          _ => 0
        }
    }
    cache_creation_tokens = match usage_obj.get("cache_creation_input_tokens") {
      Some(Number(n, ..)) => n.trunc().to_int()
      _ => 0
    }
  }
  let usage = TokenUsage::new(
    input_tokens~,
    output_tokens~,
    cache_read_tokens~,
    cache_creation_tokens~,
  )
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
    usage: {
      input_tokens: usage.anthropic_input_tokens(),
      output_tokens,
      cache_read_input_tokens: optional_positive_int(cache_read_tokens),
      cache_creation_input_tokens: optional_positive_int(cache_creation_tokens),
    },
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
