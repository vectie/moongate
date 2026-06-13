///|
pub struct Gateway {
  host : String
  port : Int
  model : String
  mut credentials : @codex.Credentials?
  stats : TrafficStats
  provider_router : ProviderRouter
  pricing_overrides : Map[String, ModelPricing]
  pricing_deleted_model_ids : Map[String, Bool]
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
    pricing_overrides: Map([], capacity=0),
    pricing_deleted_model_ids: Map([], capacity=0),
    logger,
    started_at_ms: @async.now().to_int(),
  }
}

///|
fn moonstat_default_provider_router() -> ProviderRouter {
  let router = ProviderRouter::new()
  let claude_model_mapping = ccs_model_mapping_from_env()
  let mut claude_current_provider = "codex-oauth"
  let mut claude_desktop_current_provider = "codex-oauth"
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude",
      provider_id="codex-oauth",
      provider_name="Codex OAuth",
      provider_type=Some("codex_oauth"),
      model_mapping=claude_model_mapping,
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude-desktop",
      provider_id="codex-oauth",
      provider_name="Codex OAuth",
      provider_type=Some("codex_oauth"),
      model_mapping=claude_model_mapping,
    ),
  )
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id="codex-oauth",
      provider_name="Codex OAuth",
      provider_type=Some("codex_oauth"),
    ),
  )
  match codex_provider_from_env() {
    Some(provider) => {
      router.upsert_provider(provider)
      router.set_current_provider("codex", provider.provider_id)
      router.set_failover_queue("codex", [provider.provider_id, "codex-oauth"])
      router.set_auto_failover("codex", true)
    }
    None => ()
  }
  match claude_provider_from_env("claude") {
    Some(provider) => {
      let provider_id = provider.provider_id
      router.upsert_provider(provider)
      claude_current_provider = provider_id
      router.set_current_provider("claude", provider_id)
      router.set_failover_queue("claude", [provider_id, "codex-oauth"])
      router.set_auto_failover("claude", true)
    }
    None => ()
  }
  match claude_provider_from_env("claude-desktop") {
    Some(provider) => {
      let provider_id = provider.provider_id
      router.upsert_provider(provider)
      claude_desktop_current_provider = provider_id
      router.set_current_provider("claude-desktop", provider_id)
      router.set_failover_queue("claude-desktop", [provider_id, "codex-oauth"])
      router.set_auto_failover("claude-desktop", true)
    }
    None => ()
  }
  router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="gemini",
      provider_id="gemini-api-key",
      provider_name="Gemini API Key",
    ),
  )
  router.set_current_provider("claude", claude_current_provider)
  router.set_current_provider("claude-desktop", claude_desktop_current_provider)
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
  let bypass_circuit_breaker = providers.length() == 1
  for provider in providers {
    if attempted_provider_ids.contains(provider.provider_id) {
      continue
    }
    if self.activate_provider_target(
        app_type,
        provider,
        bypass_circuit_breaker~,
      ) {
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
  bypass_circuit_breaker? : Bool = false,
) -> Bool {
  let allow = if bypass_circuit_breaker {
    { allowed: true, used_half_open_permit: false }
  } else {
    self.provider_router.allow_provider_request(provider.provider_id, app_type)
  }
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
fn Gateway::activate_next_provider_after_upstream_status(
  self : Gateway,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
  status_code : Int,
) -> ProviderRouteTarget? {
  guard self.stats.current_provider_id is Some(provider_id) else { return None }
  if !attempted_provider_ids.contains(provider_id) {
    attempted_provider_ids.push(provider_id)
  }
  if ccs_upstream_status_retryable(status_code) {
    self.provider_router.record_result(
      provider_id,
      app_type,
      self.stats.current_request_used_half_open_permit,
      false,
    )
    self.stats.last_error = Some("upstream_error")
    self.activate_first_available_provider_excluding(
      app_type, providers, attempted_provider_ids,
    )
  } else {
    self.provider_router.release_permit_neutral(
      provider_id,
      app_type,
      self.stats.current_request_used_half_open_permit,
    )
    self.stats.last_error = Some("upstream_error")
    None
  }
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
async fn Gateway::record_success_usage(
  self : Gateway,
  usage : TokenUsage,
  response_bytes : Int,
) -> Unit {
  self.record_provider_result(true)
  self.stats.record_success_usage_with_pricing(
    usage,
    response_bytes,
    self.pricing_override_rows(),
    self.pricing_deleted_model_ids,
  )
  self.stats.save_persistent_store()
}

///|
async fn Gateway::record_success_stream_usage(
  self : Gateway,
  usage : TokenUsage?,
  response_bytes : Int,
  record_provider? : Bool = true,
) -> Unit {
  if record_provider {
    self.record_provider_result(true)
  }
  match usage {
    Some(usage) if usage.has_billable_tokens() =>
      self.stats.record_success_usage_with_pricing(
        usage,
        response_bytes,
        self.pricing_override_rows(),
        self.pricing_deleted_model_ids,
      )
    _ => self.stats.record_success_without_request_log(response_bytes)
  }
  self.stats.save_persistent_store()
}

///|
pub async fn Gateway::start(self : Gateway) -> Unit {
  self.logger.info(
    "Starting Anthropic -> Codex OAuth Gateway on \{self.host}:\{self.port}",
  )
  self.stats.load_persistent_store()
  self.load_model_pricing_store()
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
  router.add_handler(@httpx.Method::Get, "/usage/logs", (r, w) => {
    self.handle_usage_logs(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/summary", (r, w) => {
    self.handle_usage_summary(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/summary/by-app", (r, w) => {
    self.handle_usage_summary_by_app(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/trends", (r, w) => {
    self.handle_usage_trends(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/provider-limits", (r, w) => {
    self.handle_usage_provider_limits(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/provider-stats", (r, w) => {
    self.handle_usage_provider_stats(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/model-stats", (r, w) => {
    self.handle_usage_model_stats(r, w)
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
  router.add_handler(@httpx.Method::Post, "/usage/model-pricing", (r, w) => {
    self.handle_usage_update_model_pricing(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/usage/model-pricing", (r, w) => {
    self.handle_usage_delete_model_pricing(r, w)
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
  let selection = self.provider_router.select_providers("codex")
  let providers = if selection.is_ok() { selection.providers } else { [] }
  let attempted_provider_ids : Array[String] = []
  for ;; {
    let active_provider = self.active_provider_target(providers)
    let (response, response_body) = match active_provider {
      Some(provider) if provider.can_use_codex_compatible_upstream() =>
        match
          self.post_codex_compatible_provider_json(
            provider,
            codex_compatible_responses_endpoint("/backend-api/codex/responses"),
            request,
          ) {
          Ok(result) => result
          Err(error) => {
            let error_body = "{\"error\":{\"message\":\"Codex upstream request failed: \{error}\",\"type\":\"upstream_error\"}}"
            if !providers.is_empty() {
              let next = self.activate_next_provider_after_upstream_status(
                "codex",
                providers,
                attempted_provider_ids,
                @status.BadGateway,
              )
              if next is Some(_) {
                continue
              }
              self.stats.record_upstream_error_status(
                error_body.length(),
                @status.BadGateway,
              )
              self.stats.save_persistent_store()
            } else {
              self.record_upstream_error_status(
                error_body.length(),
                @status.BadGateway,
              )
            }
            w.header().set("Content-Type", "application/json")
            w.write_header(@status.BadGateway)
            w.write(error_body)
            w.flush()
            return
          }
        }
      _ => {
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
        let client = self.codex_client(
          creds,
          accept="application/json",
          session_id~,
        )
        let response = client.post("/backend-api/codex/responses", request)
        let response_body = client.read_all().text()
        client.close()
        (response, response_body)
      }
    }
    if response.code == 200 {
      let parsed : Result[Json, Error] = try? @json.parse(response_body)
      match parsed {
        Ok(json) => {
          let usage = token_usage_from_codex_response_auto(json).unwrap_or(
            TokenUsage::empty(),
          )
          let chat_response = codex_response_to_openai_chat_completion(
            json, response_model,
          )
          let chat_response_body = chat_response.stringify()
          self.record_success_usage(usage, chat_response_body.length())
          w.header().set("Content-Type", "application/json")
          w.write_header(@status.Ok)
          w.write(chat_response_body)
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
      return
    }
    if !providers.is_empty() {
      let next = self.activate_next_provider_after_upstream_status(
        "codex",
        providers,
        attempted_provider_ids,
        response.code,
      )
      if next is Some(_) {
        continue
      }
      self.stats.record_upstream_error_status(
        response_body.length(),
        response.code,
      )
      self.stats.save_persistent_store()
    } else {
      self.record_upstream_error_status(response_body.length(), response.code)
    }
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write(response_body)
    w.flush()
    return
  }
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
  let selection = self.provider_router.select_providers("codex")
  let providers = if selection.is_ok() { selection.providers } else { [] }
  let attempted_provider_ids : Array[String] = []
  for ;; {
    let client = self.codex_client(
      creds,
      accept="text/event-stream",
      session_id~,
    )
    let response = client.post("/backend-api/codex/responses", request)
    if response.code != 200 {
      let error_body = client.read_all().text()
      client.close()
      if !providers.is_empty() {
        let next = self.activate_next_provider_after_upstream_status(
          "codex",
          providers,
          attempted_provider_ids,
          response.code,
        )
        if next is Some(_) {
          continue
        }
        self.stats.record_upstream_error_status(
          error_body.length(),
          response.code,
        )
        self.stats.save_persistent_store()
      } else {
        self.record_upstream_error_status(error_body.length(), response.code)
      }
      w.header().set("Content-Type", "application/json")
      w.write_header(response.code)
      w.write(error_body)
      w.flush()
      return
    }
    match client.read_until("\n") {
      None => {
        client.close()
        let error_body = "{\"error\":{\"message\":\"Streaming response ended before first chunk\",\"type\":\"upstream_error\"}}"
        if !providers.is_empty() {
          let next = self.activate_next_provider_after_upstream_status(
            "codex",
            providers,
            attempted_provider_ids,
            @status.BadGateway,
          )
          if next is Some(_) {
            continue
          }
          self.stats.record_upstream_error_status(
            error_body.length(),
            @status.BadGateway,
          )
          self.stats.save_persistent_store()
        } else {
          self.record_upstream_error_status(
            error_body.length(),
            @status.BadGateway,
          )
        }
        w.header().set("Content-Type", "application/json")
        w.write_header(@status.BadGateway)
        w.write(error_body)
        w.flush()
        return
      }
      Some(first_line) => {
        w.header().set("Content-Type", "text/event-stream")
        w.header().set("Cache-Control", "no-cache")
        w.header().set("Connection", "keep-alive")
        w.write_header(@status.Ok)
        let id = generate_chat_completion_id()
        let created = @async.now().to_int() / 1000
        let stream_events : Array[Json] = []
        w.write(
          "data: \{openai_chat_role_chunk(id, response_model, created).stringify()}\n\n",
        )
        w.flush()
        self.record_provider_result(true)
        let mut response_bytes = 0
        if first_line is [.. "data: ", .. rest] {
          let data = rest.trim().to_owned()
          if data != "[DONE]" {
            push_sse_json_event(stream_events, data)
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
        }
        while client.read_until("\n") is Some(line) {
          guard line is [.. "data: ", .. rest] else { continue }
          let data = rest.trim().to_owned()
          if data == "[DONE]" {
            break
          }
          push_sse_json_event(stream_events, data)
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
        client.close()
        self.record_success_stream_usage(
          token_usage_from_codex_stream_events_auto(stream_events),
          response_bytes,
          record_provider=false,
        )
        w.write("data: [DONE]\n\n")
        w.flush()
        return
      }
    }
  }
}

///|
async fn Gateway::forward_non_streaming_codex_response(
  self : Gateway,
  request : Json,
  endpoint : String,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  let selection = self.provider_router.select_providers("codex")
  let providers = if selection.is_ok() { selection.providers } else { [] }
  let attempted_provider_ids : Array[String] = []
  for ;; {
    let active_provider = self.active_provider_target(providers)
    let (response, response_body) = match active_provider {
      Some(provider) if provider.can_use_codex_compatible_upstream() =>
        match
          self.post_codex_compatible_provider_json(
            provider,
            codex_compatible_responses_endpoint(endpoint),
            request,
          ) {
          Ok(result) => result
          Err(error) => {
            let error_body = "{\"error\":{\"message\":\"Codex upstream request failed: \{error}\",\"type\":\"upstream_error\"}}"
            if !providers.is_empty() {
              let next = self.activate_next_provider_after_upstream_status(
                "codex",
                providers,
                attempted_provider_ids,
                @status.BadGateway,
              )
              if next is Some(_) {
                continue
              }
              self.stats.record_upstream_error_status(
                error_body.length(),
                @status.BadGateway,
              )
              self.stats.save_persistent_store()
            } else {
              self.record_upstream_error_status(
                error_body.length(),
                @status.BadGateway,
              )
            }
            w.header().set("Content-Type", "application/json")
            w.write_header(@status.BadGateway)
            w.write(error_body)
            w.flush()
            return
          }
        }
      _ => {
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
        let client = self.codex_client(
          creds,
          accept="application/json",
          session_id~,
        )
        let response = client.post(endpoint, request)
        let response_body = client.read_all().text()
        client.close()
        (response, response_body)
      }
    }
    if response.code == 200 {
      let usage = try {
        let json = @json.parse(response_body)
        token_usage_from_codex_response_auto(json).unwrap_or(
          TokenUsage::empty(),
        )
      } catch {
        _ => TokenUsage::empty()
      }
      self.record_success_usage(usage, response_body.length())
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.Ok)
      w.write(response_body)
      w.flush()
      return
    }
    if !providers.is_empty() {
      let next = self.activate_next_provider_after_upstream_status(
        "codex",
        providers,
        attempted_provider_ids,
        response.code,
      )
      if next is Some(_) {
        continue
      }
      self.stats.record_upstream_error_status(
        response_body.length(),
        response.code,
      )
      self.stats.save_persistent_store()
    } else {
      self.record_upstream_error_status(response_body.length(), response.code)
    }
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write(response_body)
    w.flush()
    return
  }
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
  let selection = self.provider_router.select_providers("codex")
  let providers = if selection.is_ok() { selection.providers } else { [] }
  let attempted_provider_ids : Array[String] = []
  for ;; {
    let client = self.codex_client(
      creds,
      accept="text/event-stream",
      session_id~,
    )
    let response = client.post(endpoint, request)
    if response.code != 200 {
      let error_body = client.read_all().text()
      client.close()
      if !providers.is_empty() {
        let next = self.activate_next_provider_after_upstream_status(
          "codex",
          providers,
          attempted_provider_ids,
          response.code,
        )
        if next is Some(_) {
          continue
        }
        self.stats.record_upstream_error_status(
          error_body.length(),
          response.code,
        )
        self.stats.save_persistent_store()
      } else {
        self.record_upstream_error_status(error_body.length(), response.code)
      }
      w.header().set("Content-Type", "application/json")
      w.write_header(response.code)
      w.write(error_body)
      w.flush()
      return
    }
    match client.read_until("\n") {
      None => {
        client.close()
        let error_body = "{\"error\":{\"message\":\"Streaming response ended before first chunk\",\"type\":\"upstream_error\"}}"
        if !providers.is_empty() {
          let next = self.activate_next_provider_after_upstream_status(
            "codex",
            providers,
            attempted_provider_ids,
            @status.BadGateway,
          )
          if next is Some(_) {
            continue
          }
          self.stats.record_upstream_error_status(
            error_body.length(),
            @status.BadGateway,
          )
          self.stats.save_persistent_store()
        } else {
          self.record_upstream_error_status(
            error_body.length(),
            @status.BadGateway,
          )
        }
        w.header().set("Content-Type", "application/json")
        w.write_header(@status.BadGateway)
        w.write(error_body)
        w.flush()
        return
      }
      Some(first_line) => {
        w.header().set("Content-Type", "text/event-stream")
        w.header().set("Cache-Control", "no-cache")
        w.header().set("Connection", "keep-alive")
        w.write_header(@status.Ok)
        let mut response_bytes = first_line.length() + 1
        let stream_events : Array[Json] = []
        if first_line is [.. "data: ", .. rest] {
          let data = rest.trim().to_owned()
          if data != "[DONE]" {
            push_sse_json_event(stream_events, data)
          }
        }
        w.write(first_line)
        w.write("\n")
        w.flush()
        self.record_provider_result(true)
        while client.read_until("\n") is Some(line) {
          response_bytes += line.length() + 1
          if line is [.. "data: ", .. rest] {
            let data = rest.trim().to_owned()
            if data != "[DONE]" {
              push_sse_json_event(stream_events, data)
            }
          }
          w.write(line)
          w.write("\n")
          w.flush()
        }
        client.close()
        self.record_success_stream_usage(
          token_usage_from_codex_stream_events_auto(stream_events),
          response_bytes,
          record_provider=false,
        )
        w.flush()
        return
      }
    }
  }
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
fn Gateway::active_provider_target(
  self : Gateway,
  providers : Array[ProviderRouteTarget],
) -> ProviderRouteTarget? {
  guard self.stats.current_provider_id is Some(provider_id) else {
    match providers.get(0) {
      Some(provider) => return Some(provider)
      None => return None
    }
  }
  for provider in providers {
    if provider.provider_id == provider_id {
      return Some(provider)
    }
  }
  match providers.get(0) {
    Some(provider) => Some(provider)
    None => None
  }
}

///|
fn ProviderRouteTarget::can_use_codex_compatible_upstream(
  self : ProviderRouteTarget,
) -> Bool {
  self.provider_type != Some("codex_oauth") &&
  self.base_url is Some(_) &&
  self.api_key is Some(_)
}

///|
fn ProviderRouteTarget::can_use_claude_compatible_upstream(
  self : ProviderRouteTarget,
) -> Bool {
  self.provider_type != Some("codex_oauth") &&
  self.base_url is Some(_) &&
  self.api_key is Some(_)
}

///|
fn ProviderRouteTarget::claude_api_format(self : ProviderRouteTarget) -> String {
  if self.provider_type == Some("codex_oauth") {
    return "openai_responses"
  }
  match self.api_format {
    Some("openai_chat") => "openai_chat"
    Some("openai_responses") => "openai_responses"
    Some("gemini_native") => "gemini_native"
    _ => "anthropic"
  }
}

///|
fn claude_api_format_needs_transform(api_format : String) -> Bool {
  api_format == "openai_chat" ||
  api_format == "openai_responses" ||
  api_format == "gemini_native"
}

///|
async fn Gateway::post_codex_compatible_provider_json(
  self : Gateway,
  provider : ProviderRouteTarget,
  endpoint : String,
  request : Json,
) -> Result[(@http.Response, String), Error] {
  let _ = self
  let base_url = provider.base_url.unwrap()
  let api_key = provider.api_key.unwrap()
  let url = codex_compatible_provider_url(base_url, endpoint)
  let result = try? @http.post(url, request, headers={
    "Authorization": "Bearer \{api_key}",
    "Content-Type": "application/json",
    "Accept": "application/json",
  })
  match result {
    Ok((response, data)) => Ok((response, data.text()))
    Err(error) => Err(error)
  }
}

///|
async fn Gateway::post_claude_compatible_provider_json(
  self : Gateway,
  provider : ProviderRouteTarget,
  endpoint : String,
  request : Json,
  api_format : String,
) -> Result[(@http.Response, String), Error] {
  let _ = self
  let base_url = provider.base_url.unwrap()
  let api_key = provider.api_key.unwrap()
  let url = codex_compatible_provider_url(base_url, endpoint)
  let headers = claude_compatible_provider_headers(api_key, api_format)
  let result = try? @http.post(url, request, headers~)
  match result {
    Ok((response, data)) => Ok((response, data.text()))
    Err(error) => Err(error)
  }
}

///|
fn claude_compatible_provider_headers(
  api_key : String,
  api_format : String,
  accept? : String = "application/json",
) -> Map[String, String] {
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "Accept": accept,
  }
  if api_format == "anthropic" {
    headers["x-api-key"] = api_key
    headers["anthropic-version"] = "2023-06-01"
  } else {
    headers["Authorization"] = "Bearer \{api_key}"
  }
  headers
}

///|
fn codex_compatible_responses_endpoint(endpoint : String) -> String {
  let query = match endpoint.find("?") {
    Some(index) => endpoint[index:]
    None => ""
  }
  "/responses\{query}"
}

///|
fn codex_compatible_provider_url(
  base_url : String,
  endpoint : String,
) -> String {
  let base_trimmed = trim_end_slashes(base_url.trim().to_owned())
  let endpoint_trimmed = trim_start_slashes(endpoint.trim().to_owned())
  let (_, path) = split_origin_and_path(base_trimmed)
  let mut url = if base_trimmed.has_suffix("/v1") {
    "\{base_trimmed}/\{endpoint_trimmed}"
  } else if path.is_empty() {
    "\{base_trimmed}/v1/\{endpoint_trimmed}"
  } else if provider_base_is_full_endpoint(base_trimmed) {
    append_query_to_full_url(base_trimmed, endpoint_trimmed)
  } else {
    "\{base_trimmed}/\{endpoint_trimmed}"
  }
  while url.contains("/v1/v1") {
    url = url.replace_all(old="/v1/v1", new="/v1")
  }
  url
}

///|
fn provider_base_is_full_endpoint(base_url : String) -> Bool {
  base_url.has_suffix("/responses") ||
  base_url.has_suffix("/chat/completions") ||
  base_url.has_suffix("/messages")
}

///|
fn claude_transform_endpoint(api_format : String, is_stream : Bool) -> String {
  let _ = is_stream
  match api_format {
    "openai_responses" => "/v1/responses"
    "openai_chat" => "/v1/chat/completions"
    _ => "/v1/messages"
  }
}

///|
fn append_query_to_full_url(
  base_url : String,
  endpoint_trimmed : String,
) -> String {
  match endpoint_trimmed.find("?") {
    Some(index) => {
      let query = endpoint_trimmed[index + 1:]
      if query.is_empty() {
        base_url
      } else if base_url.contains("?") {
        "\{base_url}&\{query}"
      } else {
        "\{base_url}?\{query}"
      }
    }
    None => base_url
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
fn codex_provider_from_env() -> ProviderRouteTarget? {
  guard env_first_non_empty([
      "MOONSTAT_CODEX_BASE_URL", "CODEX_BASE_URL", "OPENAI_BASE_URL",
    ])
    is Some(base_url) else {
    return None
  }
  guard env_first_non_empty([
      "MOONSTAT_CODEX_API_KEY", "CODEX_API_KEY", "OPENAI_API_KEY",
    ])
    is Some(api_key) else {
    return None
  }
  Some(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id=env_first_non_empty([
        "MOONSTAT_CODEX_PROVIDER_ID", "CODEX_PROVIDER_ID",
      ]).unwrap_or("codex-compatible"),
      provider_name=env_first_non_empty([
        "MOONSTAT_CODEX_PROVIDER_NAME", "CODEX_PROVIDER_NAME",
      ]).unwrap_or("Codex Compatible"),
      provider_type=Some(
        env_first_non_empty([
          "MOONSTAT_CODEX_PROVIDER_TYPE", "CODEX_PROVIDER_TYPE",
        ]).unwrap_or("codex"),
      ),
      base_url=Some(base_url),
      api_key=Some(api_key),
      is_full_url=codex_base_is_full_url(),
    ),
  )
}

///|
fn claude_provider_from_env(app_type : String) -> ProviderRouteTarget? {
  guard env_first_non_empty(["MOONSTAT_CLAUDE_BASE_URL", "ANTHROPIC_BASE_URL"])
    is Some(base_url) else {
    return None
  }
  guard env_first_non_empty([
      "MOONSTAT_CLAUDE_API_KEY", "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN",
    ])
    is Some(api_key) else {
    return None
  }
  let provider_id_prefix = if app_type == "claude-desktop" {
    "claude-desktop"
  } else {
    "claude"
  }
  Some(
    ProviderRouteTarget::new(
      app_type~,
      provider_id=env_first_non_empty([
        "MOONSTAT_CLAUDE_PROVIDER_ID", "ANTHROPIC_PROVIDER_ID",
      ]).unwrap_or("\{provider_id_prefix}-compatible"),
      provider_name=env_first_non_empty([
        "MOONSTAT_CLAUDE_PROVIDER_NAME", "ANTHROPIC_PROVIDER_NAME",
      ]).unwrap_or("Claude Compatible"),
      provider_type=Some(
        env_first_non_empty([
          "MOONSTAT_CLAUDE_PROVIDER_TYPE", "ANTHROPIC_PROVIDER_TYPE",
        ]).unwrap_or("anthropic"),
      ),
      api_format=Some(
        env_first_non_empty([
          "MOONSTAT_CLAUDE_API_FORMAT", "ANTHROPIC_API_FORMAT",
        ]).unwrap_or("anthropic"),
      ),
      prompt_cache_key=env_first_non_empty([
        "MOONSTAT_CLAUDE_PROMPT_CACHE_KEY", "ANTHROPIC_PROMPT_CACHE_KEY",
      ]),
      codex_fast_mode=env_bool("MOONSTAT_CODEX_FAST_MODE") ||
        env_bool("CODEX_FAST_MODE"),
      base_url=Some(base_url),
      api_key=Some(api_key),
      is_full_url=claude_base_is_full_url(),
      model_mapping=ccs_model_mapping_from_env(),
    ),
  )
}

///|
fn codex_base_is_full_url() -> Bool {
  env_bool("MOONSTAT_CODEX_FULL_URL") || env_bool("CODEX_FULL_URL")
}

///|
fn claude_base_is_full_url() -> Bool {
  env_bool("MOONSTAT_CLAUDE_FULL_URL") || env_bool("ANTHROPIC_FULL_URL")
}

///|
fn ccs_model_mapping_from_env() -> ModelMapping? {
  let mapping = ModelMapping::new(
    haiku_model=env_first_non_empty([
      "MOONSTAT_ANTHROPIC_DEFAULT_HAIKU_MODEL", "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    ]),
    sonnet_model=env_first_non_empty([
      "MOONSTAT_ANTHROPIC_DEFAULT_SONNET_MODEL", "ANTHROPIC_DEFAULT_SONNET_MODEL",
    ]),
    opus_model=env_first_non_empty([
      "MOONSTAT_ANTHROPIC_DEFAULT_OPUS_MODEL", "ANTHROPIC_DEFAULT_OPUS_MODEL",
    ]),
    default_model=env_first_non_empty([
      "MOONSTAT_ANTHROPIC_MODEL", "ANTHROPIC_MODEL",
    ]),
  )
  if mapping.has_mapping() {
    Some(mapping)
  } else {
    None
  }
}

///|
fn env_first_non_empty(keys : Array[String]) -> String? {
  for key in keys {
    match getenv_or_none(key) {
      Some(value) if !value.trim().is_empty() =>
        return Some(value.trim().to_owned())
      _ => continue
    }
  }
  None
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
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  let filters = RequestLogFilters::new(
    app_type=usage_query_value_any(r.path, "app_type", "appType"),
    provider_name=usage_query_value_any(r.path, "provider_name", "providerName"),
    model=usage_query_value(r.path, "model"),
    status_code=usage_query_int_any(r.path, "status_code", "statusCode"),
    start_date=usage_query_int_any(r.path, "start_date", "startDate"),
    end_date=usage_query_int_any(r.path, "end_date", "endDate"),
  )
  w.write(
    self.stats
    .usage_logs_paginated_json(
      filters,
      page=usage_query_int(r.path, "page").unwrap_or(0),
      page_size=usage_query_int_any(r.path, "page_size", "pageSize").unwrap_or(
        100,
      ),
    )
    .stringify(indent=2),
  )
  w.flush()
}

///|
async fn Gateway::handle_usage_summary(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    self.stats.usage_summary_filtered_json(
      start_date=usage_query_int_any(r.path, "start_date", "startDate"),
      end_date=usage_query_int_any(r.path, "end_date", "endDate"),
      app_type=usage_query_value_any(r.path, "app_type", "appType"),
    ),
  )
}

///|
async fn Gateway::handle_usage_summary_by_app(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    self.stats.usage_summary_by_app_filtered_json(
      start_date=usage_query_int_any(r.path, "start_date", "startDate"),
      end_date=usage_query_int_any(r.path, "end_date", "endDate"),
    ),
  )
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
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    self.stats.provider_stats_filtered_json(
      start_date=usage_query_int_any(r.path, "start_date", "startDate"),
      end_date=usage_query_int_any(r.path, "end_date", "endDate"),
      app_type=usage_query_value_any(r.path, "app_type", "appType"),
    ),
  )
}

///|
async fn Gateway::handle_usage_model_stats(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    self.stats.model_stats_filtered_json(
      start_date=usage_query_int_any(r.path, "start_date", "startDate"),
      end_date=usage_query_int_any(r.path, "end_date", "endDate"),
      app_type=usage_query_value_any(r.path, "app_type", "appType"),
    ),
  )
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
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    model_pricing_json(
      self.pricing_override_rows(),
      self.pricing_deleted_model_ids,
    ),
  )
}

///|
async fn Gateway::handle_usage_update_model_pricing(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard usage_pricing_from_query(r.path) is Some(pricing) else {
    write_usage_bad_request(w, "invalid_model_pricing")
    return
  }
  self.pricing_overrides.set(pricing.model_id, pricing)
  self.pricing_deleted_model_ids.set(pricing.model_id, false)
  let _backfilled = self.stats.backfill_missing_usage_costs_for_model(
    pricing.model_id,
    self.pricing_override_rows(),
    self.pricing_deleted_model_ids,
  )
  self.save_model_pricing_store()
  self.stats.save_persistent_store()
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(pricing.to_json().stringify(indent=2))
  w.flush()
}

///|
async fn Gateway::handle_usage_delete_model_pricing(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard usage_query_value_any(r.path, "model_id", "modelId") is Some(model_id) else {
    write_usage_bad_request(w, "missing_model_id")
    return
  }
  let trimmed = model_id.trim().to_owned()
  if trimmed.is_empty() {
    write_usage_bad_request(w, "missing_model_id")
    return
  }
  self.pricing_deleted_model_ids.set(trimmed, true)
  self.save_model_pricing_store()
  w.write_header(@status.NoContent)
  w.flush()
}

///|
async fn Gateway::handle_usage_request_detail(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let request_id = usage_request_detail_id(r.path.to_owned())
  match self.stats.ccs_request_detail_json(request_id) {
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
fn usage_query_int(path : StringView, key : String) -> Int? {
  match usage_query_value(path, key) {
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
fn usage_pricing_from_query(path : StringView) -> ModelPricing? {
  guard usage_query_value_any(path, "model_id", "modelId") is Some(model_id) else {
    return None
  }
  guard usage_query_value_any(path, "display_name", "displayName")
    is Some(display_name) else {
    return None
  }
  guard usage_query_value_any(path, "input_cost", "inputCost")
    is Some(input_cost) else {
    return None
  }
  guard usage_query_value_any(path, "output_cost", "outputCost")
    is Some(output_cost) else {
    return None
  }
  guard usage_query_value_any(path, "cache_read_cost", "cacheReadCost")
    is Some(cache_read_cost) else {
    return None
  }
  guard usage_query_value_any(path, "cache_creation_cost", "cacheCreationCost")
    is Some(cache_creation_cost) else {
    return None
  }
  let model_id = model_id.trim().to_owned()
  let display_name = display_name.trim().to_owned()
  if model_id.is_empty() || display_name.is_empty() {
    return None
  }
  for value in [input_cost, output_cost, cache_read_cost, cache_creation_cost] {
    if !usage_non_negative_decimal(value) {
      return None
    }
  }
  Some(
    mp(
      model_id,
      display_name,
      input_cost.trim().to_owned(),
      output_cost.trim().to_owned(),
      cache_read_cost.trim().to_owned(),
      cache_creation_cost.trim().to_owned(),
    ),
  )
}

///|
fn usage_non_negative_decimal(value : String) -> Bool {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() || trimmed.has_prefix("-") {
    return false
  }
  let mut seen_digit = false
  let mut seen_dot = false
  for ch in trimmed {
    let code = ch.to_int()
    if code >= '0'.to_int() && code <= '9'.to_int() {
      seen_digit = true
    } else if ch == '.' && !seen_dot {
      seen_dot = true
    } else {
      return false
    }
  }
  seen_digit
}

///|
fn Gateway::pricing_override_rows(self : Gateway) -> Array[ModelPricing] {
  let rows : Array[ModelPricing] = []
  for model_id in self.pricing_overrides.keys() {
    guard self.pricing_overrides.get(model_id) is Some(pricing) else {
      continue
    }
    rows.push(pricing)
  }
  rows
}

///|
async fn Gateway::load_model_pricing_store(self : Gateway) -> Unit {
  let path = @pathx.join(
    default_moonstat_stats_dir(),
    MOONSTAT_MODEL_PRICING_FILE,
  )
  if !@fsx.exists_as_file(path) {
    return
  }
  let content = @fsx.read_file(path) catch { _ => return }
  for line_view in content.split("\n") {
    let line = line_view.to_owned().trim()
    if line.is_empty() {
      continue
    }
    let parsed = @json.parse(line) catch { _ => continue }
    guard parsed is Object(obj) else { continue }
    guard store_json_string(obj, "modelId") is Some(model_id) else { continue }
    if store_json_bool_or_false(obj, "deleted") {
      self.pricing_deleted_model_ids.set(model_id, true)
    } else {
      match model_pricing_from_store_json(obj) {
        Some(pricing) => {
          self.pricing_overrides.set(pricing.model_id, pricing)
          self.pricing_deleted_model_ids.set(model_id, false)
        }
        None => ()
      }
    }
  }
}

///|
async fn Gateway::save_model_pricing_store(self : Gateway) -> Unit {
  let storage_dir = default_moonstat_stats_dir()
  @fsx.make_directory(storage_dir, recursive=true, exists_ok=true) catch {
    _ => return
  }
  let lines : Array[String] = []
  for pricing in self.pricing_override_rows() {
    if model_pricing_is_deleted(
        pricing.model_id,
        self.pricing_deleted_model_ids,
      ) {
      continue
    }
    lines.push(model_pricing_store_json(pricing, deleted=false).stringify())
  }
  for model_id in self.pricing_deleted_model_ids.keys() {
    if !self.pricing_deleted_model_ids.get(model_id).unwrap_or(false) {
      continue
    }
    lines.push(
      { "modelId": Json::string(model_id), "deleted": Json::boolean(true) }
      .to_json()
      .stringify(),
    )
  }
  @fsx.write_to_file(
    @pathx.join(storage_dir, MOONSTAT_MODEL_PRICING_FILE),
    lines.join("\n"),
  ) catch {
    _ => ()
  }
}

///|
fn model_pricing_from_store_json(obj : Map[String, Json]) -> ModelPricing? {
  guard store_json_string(obj, "modelId") is Some(model_id) else { return None }
  guard store_json_string(obj, "displayName") is Some(display_name) else {
    return None
  }
  guard store_json_string(obj, "inputCostPerMillion") is Some(input_cost) else {
    return None
  }
  guard store_json_string(obj, "outputCostPerMillion") is Some(output_cost) else {
    return None
  }
  guard store_json_string(obj, "cacheReadCostPerMillion")
    is Some(cache_read_cost) else {
    return None
  }
  guard store_json_string(obj, "cacheCreationCostPerMillion")
    is Some(cache_creation_cost) else {
    return None
  }
  if model_id.trim().is_empty() || display_name.trim().is_empty() {
    return None
  }
  for value in [input_cost, output_cost, cache_read_cost, cache_creation_cost] {
    if !usage_non_negative_decimal(value) {
      return None
    }
  }
  Some(
    mp(
      model_id.trim().to_owned(),
      display_name.trim().to_owned(),
      input_cost.trim().to_owned(),
      output_cost.trim().to_owned(),
      cache_read_cost.trim().to_owned(),
      cache_creation_cost.trim().to_owned(),
    ),
  )
}

///|
fn model_pricing_store_json(pricing : ModelPricing, deleted~ : Bool) -> Json {
  {
    "modelId": Json::string(pricing.model_id),
    "displayName": Json::string(pricing.display_name),
    "inputCostPerMillion": Json::string(pricing.input_cost_per_million),
    "outputCostPerMillion": Json::string(pricing.output_cost_per_million),
    "cacheReadCostPerMillion": Json::string(pricing.cache_read_cost_per_million),
    "cacheCreationCostPerMillion": Json::string(
      pricing.cache_creation_cost_per_million,
    ),
    "deleted": Json::boolean(deleted),
  }.to_json()
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
  let active_provider = self.activate_provider(app_type)
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
          let model = self.upstream_claude_model(
            anthropic_request.model,
            active_provider,
          )
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
              anthropic_request,
              json,
              model,
              active_provider,
              app_type,
              self.selected_provider_chain(app_type),
              [],
              session_id,
              w,
            )
          } else {
            self.handle_non_streaming_request(
              anthropic_request,
              json,
              model,
              active_provider,
              app_type,
              self.selected_provider_chain(app_type),
              [],
              session_id,
              w,
            )
          }
        }
      }
    }
  }
}

///|
fn Gateway::upstream_claude_model(
  self : Gateway,
  request_model : String,
  provider : ProviderRouteTarget?,
) -> String {
  match provider {
    Some(provider) =>
      match provider.model_mapping {
        Some(mapping) if mapping.has_mapping() =>
          provider.map_model_for_upstream(request_model)
        _ => self.model
      }
    None => self.model
  }
}

///|
fn Gateway::selected_provider_chain(
  self : Gateway,
  app_type : String,
) -> Array[ProviderRouteTarget] {
  let selection = self.provider_router.select_providers(app_type)
  if selection.is_ok() {
    selection.providers
  } else {
    []
  }
}

///|
async fn Gateway::forward_non_streaming_claude_compatible_request(
  self : Gateway,
  request : AnthropicRequest,
  request_json : Json,
  upstream_model : String,
  provider : ProviderRouteTarget,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  let api_format = provider.claude_api_format()
  if api_format == "gemini_native" {
    self.record_upstream_error_status(0, @status.BadGateway)
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.BadGateway)
    w.write(
      "{\"error\":{\"message\":\"Gemini-native Claude provider forwarding is not implemented yet\",\"type\":\"upstream_error\"}}",
    )
    w.flush()
    return
  }
  let upstream_body = claude_request_json_for_upstream(
    request_json, upstream_model,
  )
  let endpoint = claude_transform_endpoint(api_format, false)
  let outbound = if claude_api_format_needs_transform(api_format) {
    transform_claude_request_for_api_format(
      upstream_body,
      api_format,
      session_id~,
      explicit_prompt_cache_key=provider.prompt_cache_key,
      is_codex_oauth=provider.provider_type == Some("codex_oauth"),
      codex_fast_mode=provider.codex_fast_mode,
    )
  } else {
    upstream_body
  }
  match
    self.post_claude_compatible_provider_json(
      provider, endpoint, outbound, api_format,
    ) {
    Err(error) => {
      let error_body = "{\"error\":{\"message\":\"Claude upstream request failed: \{error}\",\"type\":\"upstream_error\"}}"
      if !providers.is_empty() {
        let next = self.activate_next_provider_after_upstream_status(
          app_type,
          providers,
          attempted_provider_ids,
          @status.BadGateway,
        )
        if next is Some(provider) {
          self.handle_non_streaming_request(
            request,
            request_json,
            self.upstream_claude_model(request.model, Some(provider)),
            Some(provider),
            app_type,
            providers,
            attempted_provider_ids,
            session_id,
            w,
          )
          return
        }
      }
      self.record_upstream_error_status(error_body.length(), @status.BadGateway)
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadGateway)
      w.write(error_body)
      w.flush()
    }
    Ok((response, response_body)) => {
      if response.code is (200..=299) {
        let parsed = @json.parse(response_body) catch {
          _ => {
            self.record_internal_error()
            w.header().set("Content-Type", "application/json")
            w.write_header(@status.InternalServerError)
            w.write("{\"error\":\"Failed to parse upstream response\"}")
            w.flush()
            return
          }
        }
        let usage = token_usage_from_claude_compatible_response(
          parsed, api_format,
        ).unwrap_or(TokenUsage::empty())
        self.record_success_usage(usage, response_body.length())
        let anthropic_response = claude_compatible_response_to_anthropic(
          parsed,
          api_format,
          request.model,
        )
        w.header().set("Content-Type", "application/json")
        w.write_header(response.code)
        w.write(anthropic_response.stringify())
      } else {
        if !providers.is_empty() {
          let next = self.activate_next_provider_after_upstream_status(
            app_type,
            providers,
            attempted_provider_ids,
            response.code,
          )
          if next is Some(provider) {
            self.handle_non_streaming_request(
              request,
              request_json,
              self.upstream_claude_model(request.model, Some(provider)),
              Some(provider),
              app_type,
              providers,
              attempted_provider_ids,
              session_id,
              w,
            )
            return
          }
        }
        self.record_upstream_error_status(response_body.length(), response.code)
        w.header().set("Content-Type", "application/json")
        w.write_header(response.code)
        w.write(response_body)
      }
      w.flush()
    }
  }
}

///|
fn claude_request_json_for_upstream(
  body : Json,
  upstream_model : String,
) -> Json {
  guard body is Object(obj) else { return body }
  obj["model"] = Json::string(upstream_model)
  Json::object(obj)
}

///|
fn token_usage_from_claude_compatible_response(
  body : Json,
  api_format : String,
) -> TokenUsage? {
  match api_format {
    "openai_chat" => token_usage_from_openai_response(body)
    "openai_responses" => token_usage_from_codex_response_auto(body)
    _ => token_usage_from_claude_response(body)
  }
}

///|
fn claude_compatible_response_to_anthropic(
  body : Json,
  api_format : String,
  model : String,
) -> Json {
  match api_format {
    "openai_chat" => openai_chat_completion_to_anthropic(body, model).to_json()
    "openai_responses" => convert_codex_to_anthropic(body, model).to_json()
    _ => body
  }
}

///|
fn openai_chat_completion_to_anthropic(
  body : Json,
  model : String,
) -> AnthropicResponse {
  let content : Array[AnthropicResponseBlock] = []
  let usage = token_usage_from_openai_response(body).unwrap_or(
    TokenUsage::empty(),
  )
  let id = openai_chat_completion_id(body).unwrap_or(generate_message_id())
  if body is Object(obj) {
    match obj.get("choices") {
      Some(Array(choices)) =>
        if choices.get(0) is Some(Object(choice)) &&
          choice.get("message") is Some(Object(message)) {
          append_openai_chat_message_content_as_anthropic(message, content)
          append_openai_chat_tool_calls_as_anthropic(message, content)
        }
      _ => ()
    }
  }
  let has_tools = content.iter().any(fn(block) { block.type_ == "tool_use" })
  {
    id,
    type_: "message",
    role: "assistant",
    content,
    model,
    stop_reason: Some(if has_tools { "tool_use" } else { "end_turn" }),
    stop_sequence: None,
    usage: {
      input_tokens: usage.anthropic_input_tokens(),
      output_tokens: usage.output_tokens,
      cache_read_input_tokens: optional_positive_int(usage.cache_read_tokens),
      cache_creation_input_tokens: optional_positive_int(
        usage.cache_creation_tokens,
      ),
    },
  }
}

///|
fn openai_chat_completion_id(body : Json) -> String? {
  guard body is Object(obj) else { return None }
  json_string_from_map(obj, "id")
}

///|
fn append_openai_chat_message_content_as_anthropic(
  message : Map[String, Json],
  content : Array[AnthropicResponseBlock],
) -> Unit {
  match message.get("content") {
    Some(String(text)) if !text.is_empty() =>
      content.push({
        type_: "text",
        text: Some(text),
        name: None,
        input: None,
        id: None,
      })
    Some(Array(parts)) =>
      for part in parts {
        match part {
          String(text) if !text.is_empty() =>
            content.push({
              type_: "text",
              text: Some(text),
              name: None,
              input: None,
              id: None,
            })
          Object(obj) =>
            if obj.get("type") is Some(String("text")) &&
              obj.get("text") is Some(String(text)) &&
              !text.is_empty() {
              content.push({
                type_: "text",
                text: Some(text),
                name: None,
                input: None,
                id: None,
              })
            }
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn append_openai_chat_tool_calls_as_anthropic(
  message : Map[String, Json],
  content : Array[AnthropicResponseBlock],
) -> Unit {
  guard message.get("tool_calls") is Some(Array(tool_calls)) else { return }
  for tool_call in tool_calls {
    guard tool_call is Object(call_obj) else { continue }
    guard call_obj.get("function") is Some(Object(function)) else { continue }
    let input = @json.parse(
      json_string_from_map(function, "arguments").unwrap_or("{}"),
    ) catch {
      _ => Json::object({})
    }
    content.push({
      type_: "tool_use",
      text: None,
      name: Some(json_string_from_map(function, "name").unwrap_or("unknown")),
      input: Some(input),
      id: Some(
        json_string_from_map(call_obj, "id").unwrap_or(generate_message_id()),
      ),
    })
  }
}

///|
async fn Gateway::handle_non_streaming_request(
  self : Gateway,
  request : AnthropicRequest,
  request_json : Json,
  model : String,
  active_provider : ProviderRouteTarget?,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  match active_provider {
    Some(provider) if provider.can_use_claude_compatible_upstream() => {
      self.forward_non_streaming_claude_compatible_request(
        request, request_json, model, provider, app_type, providers, attempted_provider_ids,
        session_id, w,
      )
      return
    }
    _ => ()
  }
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
          self.handle_non_streaming_request(
            request, request_json, model, active_provider, app_type, providers, attempted_provider_ids,
            session_id, w,
          )
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
async fn Gateway::forward_streaming_claude_compatible_request(
  self : Gateway,
  request : AnthropicRequest,
  request_json : Json,
  upstream_model : String,
  provider : ProviderRouteTarget,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  let api_format = provider.claude_api_format()
  if api_format == "gemini_native" {
    self.record_upstream_error_status(0, @status.BadGateway)
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.BadGateway)
    w.write(
      "{\"error\":{\"message\":\"Gemini-native Claude streaming is not implemented yet\",\"type\":\"upstream_error\"}}",
    )
    w.flush()
    return
  }
  let upstream_body = claude_stream_request_json_for_upstream(
    request_json, upstream_model,
  )
  let endpoint = claude_transform_endpoint(api_format, true)
  let outbound = if claude_api_format_needs_transform(api_format) {
    transform_claude_request_for_api_format(
      upstream_body,
      api_format,
      session_id~,
      explicit_prompt_cache_key=provider.prompt_cache_key,
      is_codex_oauth=provider.provider_type == Some("codex_oauth"),
      codex_fast_mode=provider.codex_fast_mode,
    )
  } else {
    upstream_body
  }
  let base_url = provider.base_url.unwrap()
  let api_key = provider.api_key.unwrap()
  let url = codex_compatible_provider_url(base_url, endpoint)
  let (origin, path) = split_origin_and_path(url)
  let client = @http.Client::new(
    origin,
    headers=claude_compatible_provider_headers(
      api_key,
      api_format,
      accept="text/event-stream",
    ),
  )
  defer client.close()
  let response = client.post(path, outbound)
  if response.code != 200 {
    let error_body = client.read_all().text()
    if !providers.is_empty() {
      let next = self.activate_next_provider_after_upstream_status(
        app_type,
        providers,
        attempted_provider_ids,
        response.code,
      )
      if next is Some(provider) {
        self.handle_streaming_request(
          request,
          request_json,
          self.upstream_claude_model(request.model, Some(provider)),
          Some(provider),
          app_type,
          providers,
          attempted_provider_ids,
          session_id,
          w,
        )
        return
      }
    }
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
  self.record_provider_result(true)
  let stream_events : Array[Json] = []
  if api_format == "openai_chat" {
    self.forward_openai_chat_sse_as_anthropic(client, stream_events, w)
    self.record_success_stream_usage(
      token_usage_from_openai_stream_events(stream_events),
      0,
      record_provider=false,
    )
  } else if api_format == "openai_responses" {
    let reader = CodexStreamReader::new(client, request.model)
    while reader.read() is Some(event) {
      w.write("event: \{event.event_type}\n")
      w.write("data: \{event.data}\n\n")
      w.flush()
    }
    self.record_success_stream_usage(
      token_usage_from_codex_stream_events_auto(reader.events),
      0,
      record_provider=false,
    )
  } else {
    self.forward_anthropic_sse_passthrough(client, stream_events, w)
    self.record_success_stream_usage(
      token_usage_from_claude_stream_events(stream_events),
      0,
      record_provider=false,
    )
  }
  if api_format == "openai_responses" {
    w.write("event: message_stop\ndata: {}\n\n")
  }
  w.flush()
}

///|
fn claude_stream_request_json_for_upstream(
  body : Json,
  upstream_model : String,
) -> Json {
  let result = claude_request_json_for_upstream(body, upstream_model)
  guard result is Object(obj) else { return result }
  obj["stream"] = Json::boolean(true)
  Json::object(obj)
}

///|
async fn Gateway::forward_openai_chat_sse_as_anthropic(
  self : Gateway,
  reader : &@io.Reader,
  events : Array[Json],
  w : @httpx.ResponseWriter,
) -> Unit {
  let _ = self
  let state = OpenAIChatAnthropicStreamState::new()
  let mut finished = false
  while reader.read_until("\n") is Some(line) {
    guard line is [.. "data: ", .. rest] else { continue }
    let data = rest.trim().to_owned()
    if data == "[DONE]" {
      finished = true
      for event in state.finish() {
        w.write("event: \{event.event_type}\n")
        w.write("data: \{event.data}\n\n")
        w.flush()
      }
      break
    }
    let parsed = @json.parse(data) catch { _ => continue }
    events.push(parsed)
    for event in state.push_chunk(parsed) {
      w.write("event: \{event.event_type}\n")
      w.write("data: \{event.data}\n\n")
      w.flush()
    }
  }
  if !finished {
    for event in state.finish() {
      w.write("event: \{event.event_type}\n")
      w.write("data: \{event.data}\n\n")
      w.flush()
    }
  }
}

///|
async fn Gateway::forward_anthropic_sse_passthrough(
  self : Gateway,
  reader : &@io.Reader,
  events : Array[Json],
  w : @httpx.ResponseWriter,
) -> Unit {
  let _ = self
  while reader.read_until("\n") is Some(line) {
    if line is [.. "data: ", .. rest] {
      let data = rest.trim().to_owned()
      let parsed = @json.parse(data) catch { _ => Json::null() }
      if parsed != Json::null() {
        events.push(parsed)
      }
    }
    w.write(line)
    w.write("\n")
    w.flush()
  }
}

///|
fn openai_chat_stream_chunk_to_anthropic_events(
  chunk : Json,
) -> Array[StreamEvent] {
  let state = OpenAIChatAnthropicStreamState::new()
  state.push_chunk(chunk)
}

///|
priv struct OpenAIChatAnthropicToolBlock {
  anthropic_index : Int
  mut id : String
  mut name : String
  mut started : Bool
  mut pending_args : String
}

///|
priv struct OpenAIChatAnthropicStreamState {
  mut message_id : String?
  mut model : String?
  mut next_content_index : Int
  mut has_sent_message_start : Bool
  mut current_non_tool_block_type : String?
  mut current_non_tool_block_index : Int?
  tool_blocks_by_index : Map[Int, OpenAIChatAnthropicToolBlock]
  open_tool_block_indices : Array[Int]
  mut has_emitted_message_delta : Bool
  mut pending_stop_reason : String?
  mut pending_usage : Json?
}

///|
fn OpenAIChatAnthropicStreamState::new() -> OpenAIChatAnthropicStreamState {
  {
    message_id: None,
    model: None,
    next_content_index: 0,
    has_sent_message_start: false,
    current_non_tool_block_type: None,
    current_non_tool_block_index: None,
    tool_blocks_by_index: Map([], capacity=0),
    open_tool_block_indices: [],
    has_emitted_message_delta: false,
    pending_stop_reason: None,
    pending_usage: None,
  }
}

///|
fn OpenAIChatAnthropicStreamState::push_chunk(
  self : OpenAIChatAnthropicStreamState,
  chunk : Json,
) -> Array[StreamEvent] {
  let events : Array[StreamEvent] = []
  guard chunk is Object(obj) else { return events }
  if self.message_id is None {
    self.message_id = json_string_from_map(obj, "id")
  }
  if self.model is None {
    self.model = json_string_from_map(obj, "model")
  }
  if obj.get("usage") is Some(Object(usage)) {
    self.pending_usage = Some(openai_chat_stream_anthropic_usage_json(usage))
  }
  guard obj.get("choices") is Some(Array(choices)) else { return events }
  guard choices.get(0) is Some(Object(choice_obj)) else { return events }
  if !self.has_sent_message_start {
    events.push(self.message_start_event())
    self.has_sent_message_start = true
  }
  if choice_obj.get("delta") is Some(Object(delta)) {
    match json_openai_chat_reasoning_text(delta) {
      Some(text) if !text.is_empty() =>
        self.push_non_tool_delta(events, "thinking", "thinking_delta", text)
      _ => ()
    }
    match json_string_from_map(delta, "content") {
      Some(text) if !text.is_empty() =>
        self.push_non_tool_delta(events, "text", "text_delta", text)
      _ => ()
    }
    match json_string_from_map(delta, "refusal") {
      Some(text) if !text.is_empty() =>
        self.push_non_tool_delta(events, "text", "text_delta", text)
      _ => ()
    }
    match delta.get("tool_calls") {
      Some(Array(tool_calls)) if !tool_calls.is_empty() => {
        self.close_current_non_tool_block(events)
        for tool_call in tool_calls {
          if tool_call is Object(tool_call_obj) {
            self.push_tool_call_delta(events, tool_call_obj)
          }
        }
      }
      _ => ()
    }
  }
  match choice_obj.get("finish_reason") {
    Some(String(reason)) => self.prepare_finish(events, reason)
    _ => ()
  }
  events
}

///|
fn OpenAIChatAnthropicStreamState::finish(
  self : OpenAIChatAnthropicStreamState,
) -> Array[StreamEvent] {
  let events : Array[StreamEvent] = []
  if self.pending_stop_reason is Some(stop_reason) {
    events.push(self.message_delta_event(stop_reason))
    events.push(anthropic_message_stop_stream_event())
    self.pending_stop_reason = None
  } else if self.has_sent_message_start {
    self.close_current_non_tool_block(events)
    self.start_pending_tool_blocks(events)
    self.close_open_tool_blocks(events)
    events.push(self.message_delta_event("end_turn"))
    events.push(anthropic_message_stop_stream_event())
  }
  events
}

///|
fn OpenAIChatAnthropicStreamState::message_start_event(
  self : OpenAIChatAnthropicStreamState,
) -> StreamEvent {
  {
    event_type: "message_start",
    data: Json::object({
      "type": Json::string("message_start"),
      "message": Json::object({
        "id": Json::string(self.message_id.unwrap_or("")),
        "type": Json::string("message"),
        "role": Json::string("assistant"),
        "model": Json::string(self.model.unwrap_or("")),
        "usage": openai_chat_zero_usage_json(),
      }),
    }).stringify(),
  }
}

///|
fn OpenAIChatAnthropicStreamState::push_non_tool_delta(
  self : OpenAIChatAnthropicStreamState,
  events : Array[StreamEvent],
  block_type : String,
  delta_type : String,
  text : String,
) -> Unit {
  if self.current_non_tool_block_type != Some(block_type) {
    self.close_current_non_tool_block(events)
    let index = self.next_content_index
    self.next_content_index += 1
    self.current_non_tool_block_type = Some(block_type)
    self.current_non_tool_block_index = Some(index)
    events.push(anthropic_content_block_start_event(index, block_type))
  }
  if self.current_non_tool_block_index is Some(index) {
    events.push(
      anthropic_content_block_delta_event(index, delta_type, block_type, text),
    )
  }
}

///|
fn OpenAIChatAnthropicStreamState::close_current_non_tool_block(
  self : OpenAIChatAnthropicStreamState,
  events : Array[StreamEvent],
) -> Unit {
  if self.current_non_tool_block_index is Some(index) {
    events.push(anthropic_content_block_stop_event(index))
  }
  self.current_non_tool_block_index = None
  self.current_non_tool_block_type = None
}

///|
fn OpenAIChatAnthropicStreamState::push_tool_call_delta(
  self : OpenAIChatAnthropicStreamState,
  events : Array[StreamEvent],
  tool_call : Map[String, Json],
) -> Unit {
  let tool_index = json_int_or_zero(tool_call, "index")
  let state = match self.tool_blocks_by_index.get(tool_index) {
    Some(existing) => existing
    None => {
      let created = {
        anthropic_index: self.next_content_index,
        id: "",
        name: "",
        started: false,
        pending_args: "",
      }
      self.next_content_index += 1
      self.tool_blocks_by_index.set(tool_index, created)
      created
    }
  }
  match json_string_from_map(tool_call, "id") {
    Some(id) if !id.is_empty() => state.id = id
    _ => ()
  }
  match tool_call.get("function") {
    Some(Object(function)) => {
      match json_string_from_map(function, "name") {
        Some(name) if !name.is_empty() => state.name = name
        _ => ()
      }
      match json_string_from_map(function, "arguments") {
        Some(args) if !args.is_empty() =>
          if state.started {
            events.push(
              anthropic_tool_input_delta_event(state.anthropic_index, args),
            )
          } else {
            state.pending_args = state.pending_args + args
          }
        _ => ()
      }
    }
    _ => ()
  }
  if !state.started && !state.id.is_empty() && !state.name.is_empty() {
    state.started = true
    events.push(
      anthropic_tool_block_start_event(
        state.anthropic_index,
        state.id,
        state.name,
      ),
    )
    self.open_tool_block_indices.push(state.anthropic_index)
    if !state.pending_args.is_empty() {
      events.push(
        anthropic_tool_input_delta_event(
          state.anthropic_index,
          state.pending_args,
        ),
      )
      state.pending_args = ""
    }
  }
}

///|
fn OpenAIChatAnthropicStreamState::prepare_finish(
  self : OpenAIChatAnthropicStreamState,
  events : Array[StreamEvent],
  reason : String,
) -> Unit {
  if self.has_emitted_message_delta {
    return
  }
  self.has_emitted_message_delta = true
  self.close_current_non_tool_block(events)
  self.start_pending_tool_blocks(events)
  self.close_open_tool_blocks(events)
  self.pending_stop_reason = Some(openai_chat_stop_reason(reason))
}

///|
fn OpenAIChatAnthropicStreamState::start_pending_tool_blocks(
  self : OpenAIChatAnthropicStreamState,
  events : Array[StreamEvent],
) -> Unit {
  for tool_index in self.tool_blocks_by_index.keys() {
    guard self.tool_blocks_by_index.get(tool_index) is Some(state) else {
      continue
    }
    if state.started {
      continue
    }
    if state.id.is_empty() &&
      state.name.is_empty() &&
      state.pending_args.is_empty() {
      continue
    }
    if state.id.is_empty() {
      state.id = "tool_call_\{tool_index}"
    }
    if state.name.is_empty() {
      state.name = "unknown_tool"
    }
    state.started = true
    events.push(
      anthropic_tool_block_start_event(
        state.anthropic_index,
        state.id,
        state.name,
      ),
    )
    self.open_tool_block_indices.push(state.anthropic_index)
    if !state.pending_args.is_empty() {
      events.push(
        anthropic_tool_input_delta_event(
          state.anthropic_index,
          state.pending_args,
        ),
      )
      state.pending_args = ""
    }
  }
}

///|
fn OpenAIChatAnthropicStreamState::close_open_tool_blocks(
  self : OpenAIChatAnthropicStreamState,
  events : Array[StreamEvent],
) -> Unit {
  for index in self.open_tool_block_indices {
    events.push(anthropic_content_block_stop_event(index))
  }
  self.open_tool_block_indices.clear()
}

///|
fn OpenAIChatAnthropicStreamState::message_delta_event(
  self : OpenAIChatAnthropicStreamState,
  stop_reason : String,
) -> StreamEvent {
  {
    event_type: "message_delta",
    data: Json::object({
      "type": Json::string("message_delta"),
      "delta": Json::object({
        "stop_reason": Json::string(stop_reason),
        "stop_sequence": Json::null(),
      }),
      "usage": self.pending_usage.unwrap_or(openai_chat_zero_usage_json()),
    }).stringify(),
  }
}

///|
fn anthropic_content_block_start_event(
  index : Int,
  block_type : String,
) -> StreamEvent {
  let content_block = if block_type == "thinking" {
    Json::object({
      "type": Json::string("thinking"),
      "thinking": Json::string(""),
    })
  } else {
    Json::object({ "type": Json::string("text"), "text": Json::string("") })
  }
  {
    event_type: "content_block_start",
    data: Json::object({
      "type": Json::string("content_block_start"),
      "index": Json::number(index.to_double()),
      "content_block": content_block,
    }).stringify(),
  }
}

///|
fn anthropic_content_block_delta_event(
  index : Int,
  delta_type : String,
  block_type : String,
  text : String,
) -> StreamEvent {
  let text_key = if block_type == "thinking" { "thinking" } else { "text" }
  let delta : Map[String, Json] = { "type": Json::string(delta_type) }
  delta[text_key] = Json::string(text)
  {
    event_type: "content_block_delta",
    data: Json::object({
      "type": Json::string("content_block_delta"),
      "index": Json::number(index.to_double()),
      "delta": Json::object(delta),
    }).stringify(),
  }
}

///|
fn anthropic_tool_block_start_event(
  index : Int,
  id : String,
  name : String,
) -> StreamEvent {
  {
    event_type: "content_block_start",
    data: Json::object({
      "type": Json::string("content_block_start"),
      "index": Json::number(index.to_double()),
      "content_block": Json::object({
        "type": Json::string("tool_use"),
        "id": Json::string(id),
        "name": Json::string(name),
      }),
    }).stringify(),
  }
}

///|
fn anthropic_tool_input_delta_event(index : Int, args : String) -> StreamEvent {
  {
    event_type: "content_block_delta",
    data: Json::object({
      "type": Json::string("content_block_delta"),
      "index": Json::number(index.to_double()),
      "delta": Json::object({
        "type": Json::string("input_json_delta"),
        "partial_json": Json::string(args),
      }),
    }).stringify(),
  }
}

///|
fn anthropic_content_block_stop_event(index : Int) -> StreamEvent {
  {
    event_type: "content_block_stop",
    data: Json::object({
      "type": Json::string("content_block_stop"),
      "index": Json::number(index.to_double()),
    }).stringify(),
  }
}

///|
fn anthropic_message_stop_stream_event() -> StreamEvent {
  {
    event_type: "message_stop",
    data: Json::object({ "type": Json::string("message_stop") }).stringify(),
  }
}

///|
fn openai_chat_zero_usage_json() -> Json {
  Json::object({
    "input_tokens": Json::number(0.0),
    "output_tokens": Json::number(0.0),
  })
}

///|
fn openai_chat_stream_anthropic_usage_json(usage : Map[String, Json]) -> Json {
  let cache_read = match usage.get("cache_read_input_tokens") {
    Some(Number(n, ..)) => n.trunc().to_int()
    _ =>
      match usage.get("prompt_tokens_details") {
        Some(Object(details)) => json_int_or_zero(details, "cached_tokens")
        _ => 0
      }
  }
  let cache_creation = json_int_or_zero(usage, "cache_creation_input_tokens")
  let prompt_tokens = json_int_or_zero(usage, "prompt_tokens")
  let input_tokens = max_int(prompt_tokens - cache_read - cache_creation, 0)
  let result : Map[String, Json] = {
    "input_tokens": Json::number(input_tokens.to_double()),
    "output_tokens": Json::number(
      json_int_or_zero(usage, "completion_tokens").to_double(),
    ),
  }
  if cache_read > 0 {
    result["cache_read_input_tokens"] = Json::number(cache_read.to_double())
  }
  if cache_creation > 0 {
    result["cache_creation_input_tokens"] = Json::number(
      cache_creation.to_double(),
    )
  }
  Json::object(result)
}

///|
fn json_openai_chat_reasoning_text(delta : Map[String, Json]) -> String? {
  match json_string_from_map(delta, "reasoning") {
    Some(text) => Some(text)
    None => json_string_from_map(delta, "reasoning_content")
  }
}

///|
fn openai_chat_stop_reason(reason : String) -> String {
  match reason {
    "tool_calls" | "function_call" => "tool_use"
    "length" => "max_tokens"
    _ => "end_turn"
  }
}

///|
async fn Gateway::handle_streaming_request(
  self : Gateway,
  request : AnthropicRequest,
  request_json : Json,
  model : String,
  active_provider : ProviderRouteTarget?,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  match active_provider {
    Some(provider) if provider.can_use_claude_compatible_upstream() => {
      self.forward_streaming_claude_compatible_request(
        request, request_json, model, provider, app_type, providers, attempted_provider_ids,
        session_id, w,
      )
      return
    }
    _ => ()
  }
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
          self.handle_streaming_request(
            request, request_json, model, active_provider, app_type, providers, attempted_provider_ids,
            session_id, w,
          )
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
  self.record_provider_result(true)
  while reader.read() is Some(event) {
    w.write("event: \{event.event_type}\n")
    w.write("data: \{event.data}\n\n")
    w.flush()
  }
  self.record_success_stream_usage(
    token_usage_from_codex_stream_events_auto(reader.events),
    0,
    record_provider=false,
  )
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
  events : Array[Json]
}

///|
fn CodexStreamReader::new(
  reader : &@io.Reader,
  model : String,
) -> CodexStreamReader {
  CodexStreamReader::{ reader, model, events: [] }
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
    push_sse_json_event(self.events, data)
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
fn push_sse_json_event(events : Array[Json], data : String) -> Unit {
  let json_result : Result[Json, Error] = try? @json.parse(data)
  match json_result {
    Ok(json) => events.push(json)
    Err(_) => ()
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
