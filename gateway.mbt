///|
pub struct Gateway {
  host : String
  port : Int
  model : String
  mut credentials : @codex.Credentials?
  stats : TrafficStats
  provider_router : ProviderRouter
  gemini_shadow : GeminiShadowStore
  codex_chat_history : CodexChatHistoryStore
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
    gemini_shadow: GeminiShadowStore::new(),
    codex_chat_history: CodexChatHistoryStore::new(),
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
    cost_multiplier=provider_cost_multiplier(provider),
    pricing_model_source=provider_pricing_model_source(provider),
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
  if usage.has_billable_tokens() {
    self.stats.record_success_usage_with_pricing(
      usage,
      response_bytes,
      self.pricing_override_rows(),
      self.pricing_deleted_model_ids,
    )
  } else {
    self.stats.record_success_without_request_log(response_bytes)
  }
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
          ignore(self.codex_chat_history.record_response(json))
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
        ignore(self.codex_chat_history.record_stream_events(stream_events))
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
    let outbound_request = self.codex_provider_outbound_request(
      active_provider, request,
    )
    let (response, response_body) = match active_provider {
      Some(provider) if provider.can_use_codex_compatible_upstream() => {
        let use_chat_bridge = provider.codex_uses_chat_completions()
        let provider_endpoint = if use_chat_bridge {
          codex_compatible_chat_completions_endpoint(endpoint)
        } else {
          codex_compatible_responses_endpoint(endpoint)
        }
        let provider_request = if use_chat_bridge {
          codex_responses_request_to_openai_chat_completion(
            outbound_request,
            codex_request_model(request, self.model),
          ).unwrap_or(outbound_request)
        } else {
          outbound_request
        }
        match
          self.post_codex_compatible_provider_json(
            provider, provider_endpoint, provider_request,
          ) {
          Ok((response, body)) =>
            if use_chat_bridge && response.code == 200 {
              let converted = try @json.parse(body) catch {
                _ => body
              } noraise {
                chat_response =>
                  openai_chat_completion_to_codex_response_with_request(
                    chat_response,
                    codex_request_model(request, self.model),
                    outbound_request,
                  ).stringify()
              }
              (response, converted)
            } else {
              (response, body)
            }
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
      let parsed : Result[Json, Error] = try? @json.parse(response_body)
      let usage = match parsed {
        Ok(json) => {
          ignore(self.codex_chat_history.record_response(json))
          token_usage_from_codex_response_auto(json).unwrap_or(
            TokenUsage::empty(),
          )
        }
        Err(_) => TokenUsage::empty()
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
fn Gateway::codex_provider_outbound_request(
  self : Gateway,
  provider : ProviderRouteTarget?,
  request : Json,
) -> Json {
  match provider {
    Some(provider) if provider.can_use_codex_compatible_upstream() =>
      self.codex_chat_history.enriched_request(request)
    _ => request
  }
}

///|
fn codex_request_model(request : Json, fallback : String) -> String {
  guard request is Object(obj) else { return fallback }
  json_string_from_map(obj, "model").unwrap_or(fallback)
}

///|
async fn Gateway::forward_streaming_codex_response(
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
    let outbound_request = self.codex_provider_outbound_request(
      active_provider, request,
    )
    let (client, response, use_chat_bridge) = match active_provider {
      Some(provider) if provider.can_use_codex_compatible_upstream() => {
        let use_chat_bridge = provider.codex_uses_chat_completions()
        let provider_endpoint = if use_chat_bridge {
          codex_compatible_chat_completions_endpoint(endpoint)
        } else {
          codex_compatible_responses_endpoint(endpoint)
        }
        let provider_request = if use_chat_bridge {
          codex_responses_request_to_openai_chat_completion(
            outbound_request,
            codex_request_model(request, self.model),
          ).unwrap_or(outbound_request)
        } else {
          outbound_request
        }
        match
          self.post_codex_compatible_provider_stream(
            provider, provider_endpoint, provider_request,
          ) {
          Ok((client, response)) => (client, response, use_chat_bridge)
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
          accept="text/event-stream",
          session_id~,
        )
        let response = client.post(endpoint, outbound_request)
        (client, response, false)
      }
    }
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
        let mut response_bytes = 0
        let stream_events : Array[Json] = []
        let chat_state = ChatToCodexResponsesStreamState::new_with_context(
          codex_request_model(request, self.model),
          codex_chat_tool_context_from_responses_request(outbound_request),
        )
        if first_line is [.. "data: ", .. rest] {
          let data = rest.trim().to_owned()
          if use_chat_bridge {
            let (_, bytes) = write_chat_provider_codex_stream_data(
              w, data, chat_state, stream_events,
            )
            response_bytes += bytes
          } else {
            if data != "[DONE]" {
              push_sse_json_event(stream_events, data)
            }
            response_bytes += first_line.length() + 1
            w.write(first_line)
            w.write("\n")
            w.flush()
          }
        } else if !use_chat_bridge {
          response_bytes += first_line.length() + 1
          w.write(first_line)
          w.write("\n")
          w.flush()
        }
        self.record_provider_result(true)
        while client.read_until("\n") is Some(line) {
          if use_chat_bridge {
            guard line is [.. "data: ", .. rest] else { continue }
            let data = rest.trim().to_owned()
            let (done, bytes) = write_chat_provider_codex_stream_data(
              w, data, chat_state, stream_events,
            )
            response_bytes += bytes
            if done {
              break
            }
          } else {
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
        }
        client.close()
        if use_chat_bridge {
          let (_, bytes) = write_chat_provider_codex_stream_data(
            w, "[DONE]", chat_state, stream_events,
          )
          response_bytes += bytes
          w.write("data: [DONE]\n\n")
        }
        ignore(self.codex_chat_history.record_stream_events(stream_events))
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
fn ProviderRouteTarget::codex_uses_chat_completions(
  self : ProviderRouteTarget,
) -> Bool {
  if self.api_format == Some("openai_chat") {
    return true
  }
  match self.base_url {
    Some(base_url) => base_url.trim().has_suffix("/chat/completions")
    None => false
  }
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
async fn Gateway::post_codex_compatible_provider_stream(
  self : Gateway,
  provider : ProviderRouteTarget,
  endpoint : String,
  request : Json,
) -> Result[(@http.Client, @http.Response), Error] {
  let _ = self
  let base_url = provider.base_url.unwrap()
  let api_key = provider.api_key.unwrap()
  let url = codex_compatible_provider_url(base_url, endpoint)
  let (origin, path) = split_origin_and_path(url)
  let client = @http.Client::new(origin, headers={
    "Authorization": "Bearer \{api_key}",
    "Content-Type": "application/json",
    "Accept": "text/event-stream",
  })
  let response = client.post(path, request) catch {
    error => {
      client.close()
      return Err(error)
    }
  }
  Ok((client, response))
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
  let url = claude_compatible_provider_url(
    base_url,
    endpoint,
    api_format,
    provider.is_full_url,
  )
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
  match api_format {
    "anthropic" => {
      headers["x-api-key"] = api_key
      headers["anthropic-version"] = "2023-06-01"
    }
    "gemini_native" => {
      headers["x-goog-api-key"] = api_key
      headers["x-goog-api-client"] = "GeminiCLI/1.0"
    }
    _ => headers["Authorization"] = "Bearer \{api_key}"
  }
  headers
}

///|
fn claude_compatible_provider_url(
  base_url : String,
  endpoint : String,
  api_format : String,
  is_full_url : Bool,
) -> String {
  if api_format == "gemini_native" {
    resolve_gemini_native_url(base_url, endpoint, is_full_url)
  } else {
    codex_compatible_provider_url(base_url, endpoint)
  }
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
fn codex_compatible_chat_completions_endpoint(endpoint : String) -> String {
  let query = match endpoint.find("?") {
    Some(index) => endpoint[index:]
    None => ""
  }
  "/chat/completions\{query}"
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
  match api_format {
    "openai_responses" => "/v1/responses"
    "openai_chat" => "/v1/chat/completions"
    "gemini_native" =>
      if is_stream {
        "/v1beta/models/__MODEL__:streamGenerateContent?alt=sse"
      } else {
        "/v1beta/models/__MODEL__:generateContent"
      }
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
      api_format=env_first_non_empty([
        "MOONSTAT_CODEX_API_FORMAT", "CODEX_API_FORMAT", "OPENAI_API_FORMAT",
      ]),
      is_full_url=codex_base_is_full_url(),
      settings_config=provider_settings_config_from_env([
        "MOONSTAT_CODEX_SETTINGS_CONFIG", "CODEX_SETTINGS_CONFIG", "OPENAI_SETTINGS_CONFIG",
      ]),
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
      settings_config=provider_settings_config_from_env([
        "MOONSTAT_CLAUDE_SETTINGS_CONFIG", "ANTHROPIC_SETTINGS_CONFIG",
      ]),
    ),
  )
}

///|
fn provider_cost_multiplier(provider : ProviderRouteTarget) -> String {
  let default_multiplier = default_cost_multiplier_for_app(provider.app_type)
  guard provider.settings_config is Some(settings) else {
    return default_multiplier
  }
  match settings {
    Object(obj) => {
      match
        json_string_from_map_any(obj, ["costMultiplier", "cost_multiplier"]) {
        Some(value) if usage_non_negative_decimal(value) =>
          return value.trim().to_owned()
        _ => ()
      }
      match obj.get("meta") {
        Some(Object(meta)) =>
          match
            json_string_from_map_any(meta, ["costMultiplier", "cost_multiplier"]) {
            Some(value) if usage_non_negative_decimal(value) =>
              value.trim().to_owned()
            _ => default_multiplier
          }
        _ => default_multiplier
      }
    }
    _ => default_multiplier
  }
}

///|
fn default_cost_multiplier_for_app(app_type : String) -> String {
  let global_keys = [
    "MOONSTAT_DEFAULT_COST_MULTIPLIER", "MOONSTAT_COST_MULTIPLIER",
  ]
  let app_keys = match app_type {
    "claude" | "claude-desktop" =>
      [
        "MOONSTAT_CLAUDE_DEFAULT_COST_MULTIPLIER", "MOONSTAT_CLAUDE_COST_MULTIPLIER",
        "ANTHROPIC_DEFAULT_COST_MULTIPLIER", "ANTHROPIC_COST_MULTIPLIER",
      ]
    "codex" =>
      [
        "MOONSTAT_CODEX_DEFAULT_COST_MULTIPLIER", "MOONSTAT_CODEX_COST_MULTIPLIER",
        "CODEX_DEFAULT_COST_MULTIPLIER", "CODEX_COST_MULTIPLIER",
      ]
    "gemini" =>
      [
        "MOONSTAT_GEMINI_DEFAULT_COST_MULTIPLIER", "MOONSTAT_GEMINI_COST_MULTIPLIER",
        "GEMINI_DEFAULT_COST_MULTIPLIER", "GEMINI_COST_MULTIPLIER",
      ]
    "opencode" =>
      [
        "MOONSTAT_OPENCODE_DEFAULT_COST_MULTIPLIER", "MOONSTAT_OPENCODE_COST_MULTIPLIER",
        "OPENCODE_DEFAULT_COST_MULTIPLIER", "OPENCODE_COST_MULTIPLIER",
      ]
    _ => []
  }
  match env_first_non_negative_decimal(app_keys) {
    Some(value) => value
    None =>
      match env_first_non_negative_decimal(global_keys) {
        Some(value) => value
        None => "1.0"
      }
  }
}

///|
fn provider_pricing_model_source(provider : ProviderRouteTarget) -> String {
  let default_source = default_pricing_model_source_for_app(provider.app_type)
  guard provider.settings_config is Some(settings) else {
    return default_source
  }
  match settings {
    Object(obj) => {
      match
        json_string_from_map_any(obj, [
          "pricingModelSource", "pricing_model_source",
        ]) {
        Some(value) if pricing_model_source_is_valid(value) =>
          return value.trim().to_owned()
        _ => ()
      }
      match obj.get("meta") {
        Some(Object(meta)) =>
          match
            json_string_from_map_any(meta, [
              "pricingModelSource", "pricing_model_source",
            ]) {
            Some(value) if pricing_model_source_is_valid(value) =>
              value.trim().to_owned()
            _ => default_source
          }
        _ => default_source
      }
    }
    _ => default_source
  }
}

///|
fn default_pricing_model_source_for_app(app_type : String) -> String {
  let global_keys = [
    "MOONSTAT_PRICING_MODEL_SOURCE", "MOONSTAT_DEFAULT_PRICING_MODEL_SOURCE",
  ]
  let app_keys = match app_type {
    "claude" | "claude-desktop" =>
      [
        "MOONSTAT_CLAUDE_PRICING_MODEL_SOURCE", "MOONSTAT_CLAUDE_DEFAULT_PRICING_MODEL_SOURCE",
        "ANTHROPIC_PRICING_MODEL_SOURCE", "ANTHROPIC_DEFAULT_PRICING_MODEL_SOURCE",
      ]
    "codex" =>
      [
        "MOONSTAT_CODEX_PRICING_MODEL_SOURCE", "MOONSTAT_CODEX_DEFAULT_PRICING_MODEL_SOURCE",
        "CODEX_PRICING_MODEL_SOURCE", "CODEX_DEFAULT_PRICING_MODEL_SOURCE",
      ]
    "gemini" =>
      [
        "MOONSTAT_GEMINI_PRICING_MODEL_SOURCE", "MOONSTAT_GEMINI_DEFAULT_PRICING_MODEL_SOURCE",
        "GEMINI_PRICING_MODEL_SOURCE", "GEMINI_DEFAULT_PRICING_MODEL_SOURCE",
      ]
    "opencode" =>
      [
        "MOONSTAT_OPENCODE_PRICING_MODEL_SOURCE", "MOONSTAT_OPENCODE_DEFAULT_PRICING_MODEL_SOURCE",
        "OPENCODE_PRICING_MODEL_SOURCE", "OPENCODE_DEFAULT_PRICING_MODEL_SOURCE",
      ]
    _ => []
  }
  match env_first_pricing_model_source(app_keys) {
    Some(value) => value
    None =>
      match env_first_pricing_model_source(global_keys) {
        Some(value) => value
        None => "response"
      }
  }
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
fn env_first_non_negative_decimal(keys : Array[String]) -> String? {
  for key in keys {
    match getenv_or_none(key) {
      Some(value) if usage_non_negative_decimal(value) =>
        return Some(value.trim().to_owned())
      _ => continue
    }
  }
  None
}

///|
fn env_first_pricing_model_source(keys : Array[String]) -> String? {
  for key in keys {
    match getenv_or_none(key) {
      Some(value) if pricing_model_source_is_valid(value) =>
        return Some(value.trim().to_owned())
      _ => continue
    }
  }
  None
}

///|
fn pricing_model_source_is_valid(value : String) -> Bool {
  let trimmed = value.trim()
  trimmed == "response" || trimmed == "request"
}

///|
fn provider_settings_config_from_env(keys : Array[String]) -> Json? {
  match env_first_non_empty(keys) {
    Some(raw) => Some(@json.parse(raw)) catch { _ => None }
    None => None
  }
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
  let raw = if path.has_prefix(prefix) {
    path[prefix.length():].to_owned()
  } else {
    path
  }
  let without_query = match raw.find("?") {
    Some(question_index) => raw[:question_index].to_owned()
    None => raw
  }
  usage_url_decode(without_query[:])
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
    let pair_key = usage_url_decode(pair[:equal_index])
    if pair_key == key {
      let value = usage_url_decode(pair[equal_index + 1:])
      if value.is_empty() {
        return None
      }
      return Some(value)
    }
  }
  None
}

///|
fn usage_url_decode(value : StringView) -> String {
  let builder = StringBuilder::new()
  let chars = value.to_array()
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if ch == '%' && i + 2 < chars.length() {
      match (usage_hex_value(chars[i + 1]), usage_hex_value(chars[i + 2])) {
        (Some(high), Some(low)) => {
          builder.write_char(((high << 4) | low).unsafe_to_char())
          i += 3
          continue
        }
        _ => ()
      }
    } else if ch == '+' {
      builder.write_char(' ')
      i += 1
      continue
    }
    builder.write_char(ch)
    i += 1
  }
  builder.to_string()
}

///|
fn usage_hex_value(ch : Char) -> Int? {
  match ch {
    '0'..='9' => Some(ch.to_int() - '0'.to_int())
    'A'..='F' => Some(ch.to_int() - 'A'.to_int() + 10)
    'a'..='f' => Some(ch.to_int() - 'a'.to_int() + 10)
    _ => None
  }
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
        _ => strip_one_m_suffix_for_upstream(request_model)
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
  let upstream_body = prepare_upstream_request_body(
    claude_request_json_for_upstream(request_json, upstream_model),
    provider=Some(provider),
  )
  let endpoint = claude_transform_endpoint(api_format, false).replace_all(
    old="__MODEL__",
    new=normalize_gemini_model_id(upstream_model),
  )
  let outbound = self.claude_provider_outbound_body(
    provider, upstream_body, api_format, session_id,
  )
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
      let mut response_code = response.code
      let mut final_response_body = response_body
      let mut final_response_headers = response.headers
      if ccs_media_retry_should_trigger(
          response_code, final_response_body, upstream_body,
        ) {
        let retry_body = replace_image_blocks_with_marker(upstream_body)
        if retry_body.count > 0 {
          let retry_outbound = self.claude_provider_outbound_body(
            provider,
            retry_body.body,
            api_format,
            session_id,
          )
          match
            self.post_claude_compatible_provider_json(
              provider, endpoint, retry_outbound, api_format,
            ) {
            Ok((retry_response, retry_response_body)) => {
              response_code = retry_response.code
              final_response_body = retry_response_body
              final_response_headers = retry_response.headers
            }
            Err(_) => ()
          }
        }
      }
      if !(response_code is (200..=299)) {
        match ccs_rectifier_retry_body(final_response_body, upstream_body) {
          Some(rectifier_retry) => {
            self.logger.info(
              "CCS rectifier retry triggered: \{rectifier_retry.kind} (\{rectifier_retry.summary})",
            )
            let retry_outbound = self.claude_provider_outbound_body(
              provider,
              rectifier_retry.body,
              api_format,
              session_id,
            )
            match
              self.post_claude_compatible_provider_json(
                provider, endpoint, retry_outbound, api_format,
              ) {
              Ok((retry_response, retry_response_body)) => {
                response_code = retry_response.code
                final_response_body = retry_response_body
                final_response_headers = retry_response.headers
              }
              Err(_) => ()
            }
          }
          None => ()
        }
      }
      if response_code is (200..=299) {
        let parsed = match
          parse_claude_compatible_non_stream_body_with_diagnostics(
            api_format, final_response_body, final_response_headers,
          ) {
          Ok(parsed) => parsed
          Err(message) => {
            self.record_internal_error()
            w.header().set("Content-Type", "application/json")
            w.write_header(@status.InternalServerError)
            w.write(
              Json::object({ "error": Json::string(message) }).stringify(),
            )
            w.flush()
            return
          }
        }
        let usage = token_usage_from_claude_compatible_response(
          parsed, api_format,
        ).unwrap_or(TokenUsage::empty())
        if api_format == "openai_responses" {
          ignore(self.codex_chat_history.record_response(parsed))
        }
        self.record_success_usage(usage, response_body.length())
        if api_format == "gemini_native" {
          self.gemini_shadow.record_gemini_response(
            provider.provider_id,
            session_id,
            parsed,
          )
        }
        let anthropic_response = claude_compatible_response_to_anthropic(
          parsed,
          api_format,
          request.model,
        )
        w.header().set("Content-Type", "application/json")
        w.write_header(response_code)
        w.write(anthropic_response.stringify())
      } else {
        if !providers.is_empty() {
          let next = self.activate_next_provider_after_upstream_status(
            app_type, providers, attempted_provider_ids, response_code,
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
        self.record_upstream_error_status(
          final_response_body.length(),
          response_code,
        )
        w.header().set("Content-Type", "application/json")
        w.write_header(response_code)
        w.write(final_response_body)
      }
      w.flush()
    }
  }
}

///|
fn Gateway::claude_provider_outbound_body(
  self : Gateway,
  provider : ProviderRouteTarget,
  upstream_body : Json,
  api_format : String,
  session_id : String?,
) -> Json {
  if claude_api_format_needs_transform(api_format) {
    transform_claude_request_for_api_format(
      upstream_body,
      api_format,
      session_id~,
      explicit_prompt_cache_key=provider.prompt_cache_key,
      is_codex_oauth=provider.provider_type == Some("codex_oauth"),
      codex_fast_mode=provider.codex_fast_mode,
      gemini_shadow_turns=self.gemini_shadow.session_turns(
        provider.provider_id,
        session_id,
      ),
    )
  } else {
    upstream_body
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
    "gemini_native" => token_usage_from_gemini_response(body)
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
    "gemini_native" =>
      gemini_native_response_to_anthropic(body, model).to_json()
    _ => body
  }
}

///|
fn parse_claude_compatible_non_stream_body_with_diagnostics(
  api_format : String,
  body : String,
  headers : Map[String, String],
) -> Result[Json, String] {
  let parsed = @json.parse(body) catch {
    error => {
      if api_format == "openai_responses" && body_looks_like_sse(body) {
        match responses_sse_to_response_value(body) {
          Some(value) => return Ok(value)
          None =>
            return Err(
              "Failed to aggregate upstream SSE response \{body_diagnostics_suffix(headers, body)}",
            )
        }
      }
      if api_format == "openai_chat" && body_looks_like_sse(body) {
        match chat_sse_to_response_value(body) {
          Some(value) => return Ok(value)
          None =>
            return Err(
              "Failed to aggregate upstream chat SSE response \{body_diagnostics_suffix(headers, body)}",
            )
        }
      }
      return Err(
        "Failed to parse upstream response: \{error} \{body_diagnostics_suffix(headers, body)}",
      )
    }
  }
  Ok(parsed)
}

///|
fn body_looks_like_sse(body : String) -> Bool {
  let trimmed = strip_utf8_bom(body).trim()
  trimmed.has_prefix("data:") ||
  trimmed.has_prefix("event:") ||
  trimmed.has_prefix("id:") ||
  trimmed.has_prefix("retry:") ||
  trimmed.has_prefix(":")
}

///|
fn body_diagnostics_suffix(
  headers : Map[String, String],
  body : String,
) -> String {
  let content_type = headers.get("content-type").unwrap_or("<none>")
  let content_encoding = headers.get("content-encoding").unwrap_or("<none>")
  "(content-type: \{content_type}; content-encoding: \{content_encoding}; body[..120]: '\{body_snippet(body, 120)}')"
}

///|
fn body_snippet(body : String, max_chars : Int) -> String {
  let mut snippet = ""
  let limit = if body.length() < max_chars { body.length() } else { max_chars }
  for i in 0..<limit {
    let ch = body[i]
    if ch == '\n' {
      snippet += "\\n"
    } else if ch == '\r' {
      ()
    } else if ch.to_int() < 32 {
      snippet += "\u{FFFD}"
    } else {
      snippet += body[i:i + 1].to_owned()
    }
  }
  if body.length() > max_chars {
    snippet += "\u{2026}"
  }
  snippet
}

///|
fn strip_utf8_bom(body : String) -> String {
  if body.has_prefix("\u{feff}") {
    body["\u{feff}".length():].to_owned()
  } else {
    body
  }
}

///|
fn responses_sse_to_response_value(body : String) -> Json? {
  let mut buffer = ""
  let mut completed_response : Json? = None
  let mut output_items : Array[Json] = []
  let normalized = strip_utf8_bom(body)
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  for line_view in normalized.split("\n") {
    let line = line_view.to_owned()
    if line.trim().is_empty() {
      let next = process_responses_sse_block(
        buffer, true, completed_response, output_items,
      )
      completed_response = next.0
      output_items = next.1
      buffer = ""
    } else if buffer.is_empty() {
      buffer = line
    } else {
      buffer = "\{buffer}\n\{line}"
    }
  }
  let next = process_responses_sse_block(
    buffer, false, completed_response, output_items,
  )
  completed_response = next.0
  output_items = next.1
  match completed_response {
    Some(Object(obj)) => {
      if !output_items.is_empty() {
        obj["output"] = Json::array(output_items)
      }
      Some(Json::object(obj))
    }
    Some(response) =>
      if output_items.is_empty() {
        Some(response)
      } else {
        None
      }
    None => None
  }
}

///|
fn process_responses_sse_block(
  block : String,
  strict : Bool,
  completed_response : Json?,
  output_items : Array[Json],
) -> (Json?, Array[Json]) {
  if block.trim().is_empty() {
    return (completed_response, output_items)
  }
  if !strict && completed_response is Some(_) {
    return (completed_response, output_items)
  }
  let mut event_name = ""
  let data_lines : Array[String] = []
  for line_view in block.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    match strip_sse_field(line, "event") {
      Some(event) => event_name = event.trim().to_owned()
      None =>
        match strip_sse_field(line, "data") {
          Some(data) => data_lines.push(data)
          None => ()
        }
    }
  }
  if data_lines.is_empty() {
    return (completed_response, output_items)
  }
  let data = data_lines.join("\n")
  if data.trim() == "[DONE]" {
    return (completed_response, output_items)
  }
  let parsed = @json.parse(data) catch {
    _ => return (completed_response, output_items)
  }
  guard parsed is Object(obj) else { return (completed_response, output_items) }
  let actual_event_name = if event_name.is_empty() {
    json_string_from_map(obj, "type").unwrap_or("")
  } else {
    event_name
  }
  match actual_event_name {
    "response.output_item.done" =>
      if obj.get("item") is Some(item) {
        output_items.push(item)
      }
    "response.completed" =>
      match obj.get("response") {
        Some(response) => return (Some(response), output_items)
        None => return (Some(parsed), output_items)
      }
    _ => ()
  }
  (completed_response, output_items)
}

///|
fn strip_sse_field(line : String, field : String) -> String? {
  let prefix = "\{field}:"
  if !line.has_prefix(prefix) {
    return None
  }
  let mut value = line[prefix.length():].to_owned()
  if value.has_prefix(" ") {
    value = value[1:].to_owned()
  }
  Some(value)
}

///|
priv struct OpenAIChatSseToolCall {
  mut id : String
  mut name : String
  mut arguments : String
}

///|
priv struct OpenAIChatSseState {
  mut id : String?
  mut created : Json?
  mut model : String?
  mut content : String
  mut finish_reason : String?
  mut usage : Json?
  mut saw_choice : Bool
  mut error_seen : Bool
  tool_calls : Map[Int, OpenAIChatSseToolCall]
}

///|
fn OpenAIChatSseState::new() -> OpenAIChatSseState {
  {
    id: None,
    created: None,
    model: None,
    content: "",
    finish_reason: None,
    usage: None,
    saw_choice: false,
    error_seen: false,
    tool_calls: Map([], capacity=0),
  }
}

///|
fn chat_sse_to_response_value(body : String) -> Json? {
  let state = OpenAIChatSseState::new()
  let mut buffer = ""
  let normalized = strip_utf8_bom(body)
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
  for line_view in normalized.split("\n") {
    let line = line_view.to_owned()
    if line.trim().is_empty() {
      process_chat_sse_block(buffer, true, state)
      buffer = ""
    } else if buffer.is_empty() {
      buffer = line
    } else {
      buffer = "\{buffer}\n\{line}"
    }
  }
  process_chat_sse_block(buffer, false, state)
  if state.error_seen || !state.saw_choice {
    return None
  }
  Some(state.to_chat_completion_json())
}

///|
fn process_chat_sse_block(
  block : String,
  strict : Bool,
  state : OpenAIChatSseState,
) -> Unit {
  if block.trim().is_empty() {
    return
  }
  let mut event_name = ""
  let data_lines : Array[String] = []
  for line_view in block.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    match strip_sse_field(line, "event") {
      Some(event) => event_name = event.trim().to_owned()
      None =>
        match strip_sse_field(line, "data") {
          Some(data) => data_lines.push(data)
          None => ()
        }
    }
  }
  if data_lines.is_empty() {
    return
  }
  let data = data_lines.join("\n")
  if data.trim() == "[DONE]" {
    return
  }
  let parsed = @json.parse(data) catch {
    _ => if strict { return } else { return }
  }
  guard parsed is Object(obj) else { return }
  if event_name.to_lower() == "error" {
    state.error_seen = true
    return
  }
  match obj.get("error") {
    Some(Object(error_obj)) =>
      match json_string_from_map(error_obj, "message") {
        Some(message) if !message.is_empty() => {
          state.error_seen = true
          return
        }
        _ => ()
      }
    Some(String(message)) if !message.is_empty() => {
      state.error_seen = true
      return
    }
    _ => ()
  }
  if state.error_seen {
    return
  }
  state.push_chat_sse_chunk(obj)
}

///|
fn OpenAIChatSseState::push_chat_sse_chunk(
  self : OpenAIChatSseState,
  obj : Map[String, Json],
) -> Unit {
  if self.id is None {
    self.id = json_string_from_map(obj, "id")
  }
  if self.model is None {
    self.model = json_string_from_map(obj, "model")
  }
  if self.created is None {
    match obj.get("created") {
      Some(created) => self.created = Some(created)
      None => ()
    }
  }
  match obj.get("usage") {
    Some(Object(_)) => self.usage = obj.get("usage")
    _ => ()
  }
  guard obj.get("choices") is Some(Array(choices)) else { return }
  guard choices.get(0) is Some(Object(choice)) else { return }
  self.saw_choice = true
  match choice.get("message") {
    Some(Object(message)) => self.push_chat_sse_message(message)
    _ => ()
  }
  match choice.get("delta") {
    Some(Object(delta)) => self.push_chat_sse_delta(delta)
    _ => ()
  }
  match json_string_from_map(choice, "finish_reason") {
    Some(reason) if self.finish_reason is None =>
      self.finish_reason = Some(reason)
    _ => ()
  }
}

///|
fn OpenAIChatSseState::push_chat_sse_message(
  self : OpenAIChatSseState,
  message : Map[String, Json],
) -> Unit {
  match json_string_from_map(message, "content") {
    Some(text) => self.content = text
    None => ()
  }
  match message.get("tool_calls") {
    Some(Array(tool_calls)) => {
      let mut index = 0
      for tool_call in tool_calls {
        if tool_call is Object(call) {
          self.push_chat_sse_tool_call(index, call)
        }
        index += 1
      }
    }
    _ => ()
  }
}

///|
fn OpenAIChatSseState::push_chat_sse_delta(
  self : OpenAIChatSseState,
  delta : Map[String, Json],
) -> Unit {
  match json_string_from_map(delta, "content") {
    Some(text) => self.content = self.content + text
    None => ()
  }
  match json_string_from_map(delta, "refusal") {
    Some(text) => self.content = self.content + text
    None => ()
  }
  match delta.get("tool_calls") {
    Some(Array(tool_calls)) =>
      for tool_call in tool_calls {
        if tool_call is Object(call) {
          self.push_chat_sse_tool_call(json_int_or_zero(call, "index"), call)
        }
      }
    _ => ()
  }
}

///|
fn OpenAIChatSseState::push_chat_sse_tool_call(
  self : OpenAIChatSseState,
  index : Int,
  call : Map[String, Json],
) -> Unit {
  let state = match self.tool_calls.get(index) {
    Some(existing) => existing
    None => {
      let created : OpenAIChatSseToolCall = { id: "", name: "", arguments: "" }
      self.tool_calls.set(index, created)
      created
    }
  }
  match json_string_from_map(call, "id") {
    Some(id) if !id.is_empty() => state.id = id
    _ => ()
  }
  match call.get("function") {
    Some(Object(function)) => {
      match json_string_from_map(function, "name") {
        Some(name) if !name.is_empty() => state.name = name
        _ => ()
      }
      match json_string_from_map(function, "arguments") {
        Some(arguments) => state.arguments = state.arguments + arguments
        None => ()
      }
    }
    _ => ()
  }
}

///|
fn OpenAIChatSseState::to_chat_completion_json(
  self : OpenAIChatSseState,
) -> Json {
  let message : Map[String, Json] = {
    "role": Json::string("assistant"),
    "content": Json::string(self.content),
  }
  let tool_calls = self.chat_sse_tool_calls_json()
  if !tool_calls.is_empty() {
    message["tool_calls"] = Json::array(tool_calls)
  }
  let choice : Map[String, Json] = {
    "index": Json::number(0.0),
    "message": Json::object(message),
    "finish_reason": Json::string(self.finish_reason.unwrap_or("stop")),
  }
  let response : Map[String, Json] = {
    "id": Json::string(self.id.unwrap_or(generate_chat_completion_id())),
    "object": Json::string("chat.completion"),
    "model": Json::string(self.model.unwrap_or("")),
    "choices": Json::array([Json::object(choice)]),
  }
  match self.created {
    Some(created) => response["created"] = created
    None => ()
  }
  match self.usage {
    Some(usage) => response["usage"] = usage
    None => ()
  }
  Json::object(response)
}

///|
fn OpenAIChatSseState::chat_sse_tool_calls_json(
  self : OpenAIChatSseState,
) -> Array[Json] {
  let indexes = self.tool_calls.keys().collect()
  indexes.sort_by(fn(a, b) { a.compare(b) })
  let calls : Array[Json] = []
  for index in indexes {
    guard self.tool_calls.get(index) is Some(call) else { continue }
    if call.id.is_empty() && call.name.is_empty() && call.arguments.is_empty() {
      continue
    }
    calls.push(
      Json::object({
        "id": Json::string(
          if call.id.is_empty() {
            "tool_call_\{index}"
          } else {
            call.id
          },
        ),
        "type": Json::string("function"),
        "function": Json::object({
          "name": Json::string(
            if call.name.is_empty() {
              "unknown_tool"
            } else {
              call.name
            },
          ),
          "arguments": Json::string(call.arguments),
        }),
      }),
    )
  }
  calls
}

///|
fn gemini_native_response_to_anthropic(
  body : Json,
  model : String,
) -> AnthropicResponse {
  let usage = token_usage_from_gemini_response(body).unwrap_or(
    TokenUsage::empty(),
  )
  let content : Array[AnthropicResponseBlock] = []
  let mut finish_reason = "STOP"
  if body is Object(obj) {
    if gemini_prompt_block_reason(obj) is Some(reason) {
      content.push({
        type_: "text",
        text: Some("Request blocked by Gemini safety filter: \{reason}"),
        name: None,
        input: None,
        id: None,
      })
      finish_reason = "SAFETY"
    } else if obj.get("candidates") is Some(Array(candidates)) &&
      candidates.get(0) is Some(Object(candidate)) {
      finish_reason = json_string_from_map(candidate, "finishReason").unwrap_or(
        "STOP",
      )
      if candidate.get("content") is Some(Object(candidate_content)) &&
        candidate_content.get("parts") is Some(Array(parts)) {
        append_gemini_parts_as_anthropic(parts, content)
      }
    }
  }
  let has_tools = content.iter().any(fn(block) { block.type_ == "tool_use" })
  {
    id: generate_message_id(),
    type_: "message",
    role: "assistant",
    content,
    model,
    stop_reason: Some(
      gemini_finish_reason_to_anthropic(finish_reason, has_tools),
    ),
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
fn gemini_prompt_block_reason(obj : Map[String, Json]) -> String? {
  guard obj.get("promptFeedback") is Some(Object(feedback)) else { return None }
  json_string_from_map(feedback, "blockReason")
}

///|
fn append_gemini_parts_as_anthropic(
  parts : Array[Json],
  content : Array[AnthropicResponseBlock],
) -> Unit {
  let mut tool_position = 0
  for part in parts {
    guard part is Object(part_obj) else { continue }
    if part_obj.get("text") is Some(String(text)) && !text.is_empty() {
      content.push({
        type_: "text",
        text: Some(text),
        name: None,
        input: None,
        id: None,
      })
    } else if part_obj.get("functionCall") is Some(Object(function_call)) {
      content.push({
        type_: "tool_use",
        text: None,
        name: Some(
          json_string_from_map(function_call, "name").unwrap_or("unknown"),
        ),
        input: Some(function_call.get("args").unwrap_or(Json::object({}))),
        id: Some(
          json_string_from_map(function_call, "id").unwrap_or(
            generate_gemini_synth_tool_call_id(tool_position),
          ),
        ),
      })
      tool_position += 1
    }
  }
}

///|
fn gemini_finish_reason_to_anthropic(
  finish_reason : String,
  has_tools : Bool,
) -> String {
  if has_tools {
    return "tool_use"
  }
  match finish_reason {
    "MAX_TOKENS" => "max_tokens"
    "SAFETY" | "RECITATION" | "BLOCKLIST" | "PROHIBITED_CONTENT" | "SPII" =>
      "refusal"
    _ => "end_turn"
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
      ignore(self.codex_chat_history.record_response(json))
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
  let upstream_body = prepare_upstream_request_body(
    claude_stream_request_json_for_upstream(request_json, upstream_model),
    provider=Some(provider),
  )
  let endpoint = claude_transform_endpoint(api_format, true).replace_all(
    old="__MODEL__",
    new=normalize_gemini_model_id(upstream_model),
  )
  let outbound = self.claude_provider_outbound_body(
    provider, upstream_body, api_format, session_id,
  )
  let base_url = provider.base_url.unwrap()
  let api_key = provider.api_key.unwrap()
  let url = claude_compatible_provider_url(
    base_url,
    endpoint,
    api_format,
    provider.is_full_url,
  )
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
    if ccs_media_retry_should_trigger(response.code, error_body, upstream_body) {
      let retry_body = replace_image_blocks_with_marker(upstream_body)
      if retry_body.count > 0 {
        let retry_outbound = self.claude_provider_outbound_body(
          provider,
          retry_body.body,
          api_format,
          session_id,
        )
        let retry_client = @http.Client::new(
          origin,
          headers=claude_compatible_provider_headers(
            api_key,
            api_format,
            accept="text/event-stream",
          ),
        )
        defer retry_client.close()
        let retry_response = retry_client.post(path, retry_outbound)
        if retry_response.code == 200 {
          self.forward_successful_claude_compatible_stream(
            retry_client,
            request.model,
            api_format,
            provider.provider_id,
            session_id,
            w,
          )
          return
        }
        let retry_error_body = retry_client.read_all().text()
        if !providers.is_empty() {
          let next = self.activate_next_provider_after_upstream_status(
            app_type,
            providers,
            attempted_provider_ids,
            retry_response.code,
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
        self.record_upstream_error_status(
          retry_error_body.length(),
          retry_response.code,
        )
        w.header().set("Content-Type", "application/json")
        w.write_header(retry_response.code)
        w.write(retry_error_body)
        w.flush()
        return
      }
    }
    match ccs_rectifier_retry_body(error_body, upstream_body) {
      Some(rectifier_retry) => {
        self.logger.info(
          "CCS rectifier stream retry triggered: \{rectifier_retry.kind} (\{rectifier_retry.summary})",
        )
        let retry_outbound = self.claude_provider_outbound_body(
          provider,
          rectifier_retry.body,
          api_format,
          session_id,
        )
        let retry_client = @http.Client::new(
          origin,
          headers=claude_compatible_provider_headers(
            api_key,
            api_format,
            accept="text/event-stream",
          ),
        )
        defer retry_client.close()
        let retry_response = retry_client.post(path, retry_outbound)
        if retry_response.code == 200 {
          self.forward_successful_claude_compatible_stream(
            retry_client,
            request.model,
            api_format,
            provider.provider_id,
            session_id,
            w,
          )
          return
        }
        let retry_error_body = retry_client.read_all().text()
        if !providers.is_empty() {
          let next = self.activate_next_provider_after_upstream_status(
            app_type,
            providers,
            attempted_provider_ids,
            retry_response.code,
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
        self.record_upstream_error_status(
          retry_error_body.length(),
          retry_response.code,
        )
        w.header().set("Content-Type", "application/json")
        w.write_header(retry_response.code)
        w.write(retry_error_body)
        w.flush()
        return
      }
      None => ()
    }
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
  self.forward_successful_claude_compatible_stream(
    client,
    request.model,
    api_format,
    provider.provider_id,
    session_id,
    w,
  )
}

///|
async fn Gateway::forward_successful_claude_compatible_stream(
  self : Gateway,
  client : @http.Client,
  request_model : String,
  api_format : String,
  provider_id : String,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
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
  } else if api_format == "gemini_native" {
    self.forward_gemini_native_sse_as_anthropic(
      client, stream_events, provider_id, session_id, w,
    )
    self.record_success_stream_usage(
      token_usage_from_gemini_stream_chunks(stream_events),
      0,
      record_provider=false,
    )
  } else if api_format == "openai_responses" {
    let reader = CodexStreamReader::new(client, request_model)
    while reader.read() is Some(event) {
      w.write("event: \{event.event_type}\n")
      w.write("data: \{event.data}\n\n")
      w.flush()
    }
    ignore(self.codex_chat_history.record_stream_events(reader.events))
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
fn prepare_upstream_request_body(
  body : Json,
  provider? : ProviderRouteTarget? = None,
) -> Json {
  let filtered = filter_private_params_for_upstream(body, None, [])
  let optimized = apply_ccs_optimizer_for_provider(filtered, provider)
  canonicalize_json_value(
    replace_images_for_text_only_model(optimized, provider~).body,
  )
}

///|
fn filter_private_params_for_upstream(
  body : Json,
  parent_key : String?,
  whitelist : Array[String],
) -> Json {
  match body {
    Object(obj) => {
      let schema_name_map = parent_key is Some(key) &&
        matches_schema_name_map(key)
      let result : Map[String, Json] = {}
      for key, value in obj {
        if key.has_prefix("_") && !schema_name_map && !whitelist.contains(key) {
          continue
        }
        result[key] = filter_private_params_for_upstream(
          value,
          Some(key),
          whitelist,
        )
      }
      Json::object(result)
    }
    Array(items) => {
      let result : Array[Json] = []
      for item in items {
        result.push(
          filter_private_params_for_upstream(item, parent_key, whitelist),
        )
      }
      Json::array(result)
    }
    _ => body
  }
}

///|
const UNSUPPORTED_IMAGE_MARKER = "[Unsupported Image]"

///|
priv struct MediaReplacementResult {
  body : Json
  count : Int
}

///|
fn replace_images_for_text_only_model(
  body : Json,
  provider? : ProviderRouteTarget? = None,
) -> MediaReplacementResult {
  guard body is Object(obj) else { return { body, count: 0 } }
  let model = json_string_from_map(obj, "model").unwrap_or("")
  match explicit_model_image_support(provider, model) {
    Some(true) => return { body: Json::object(obj), count: 0 }
    Some(false) => return replace_image_blocks_with_marker(Json::object(obj))
    None => ()
  }
  if !known_text_only_model(model) {
    return { body: Json::object(obj), count: 0 }
  }
  replace_image_blocks_with_marker(Json::object(obj))
}

///|
fn explicit_model_image_support(
  provider : ProviderRouteTarget?,
  model : String,
) -> Bool? {
  guard provider is Some(provider) else { return None }
  guard provider.settings_config is Some(settings) else { return None }
  match settings {
    Object(obj) => {
      match obj.get("modelCatalog") {
        Some(Object(catalog)) =>
          match catalog.get("models") {
            Some(models) =>
              match explicit_model_image_support_in_value(models, model) {
                Some(value) => return Some(value)
                None => ()
              }
            None => ()
          }
        _ => ()
      }
      match obj.get("modelCatalog") {
        Some(catalog) =>
          match explicit_model_image_support_in_value(catalog, model) {
            Some(value) => return Some(value)
            None => ()
          }
        None => ()
      }
      match obj.get("models") {
        Some(models) => explicit_model_image_support_in_value(models, model)
        None => None
      }
    }
    _ => None
  }
}

///|
fn explicit_model_image_support_in_value(value : Json, model : String) -> Bool? {
  match value {
    Array(models) => {
      for entry in models {
        if model_entry_matches(entry, None, model) {
          match explicit_image_support(entry) {
            Some(value) => return Some(value)
            None => ()
          }
        }
      }
      None
    }
    Object(entries) => {
      for key, entry in entries {
        if model_entry_matches(entry, Some(key), model) {
          match explicit_image_support(entry) {
            Some(value) => return Some(value)
            None => ()
          }
        }
      }
      None
    }
    _ => None
  }
}

///|
fn explicit_image_support(entry : Json) -> Bool? {
  guard entry is Object(obj) else { return None }
  match
    json_bool_from_map_any(obj, ["supportsImage", "supports_image", "vision"]) {
    Some(value) => return Some(value)
    None => ()
  }
  match obj.get("input") {
    Some(input) =>
      match input_modalities_support_image(input) {
        Some(value) => return Some(value)
        None => ()
      }
    None => ()
  }
  match obj.get("modalities") {
    Some(Object(modalities)) =>
      match modalities.get("input") {
        Some(input) =>
          match input_modalities_support_image(input) {
            Some(value) => return Some(value)
            None => ()
          }
        None => ()
      }
    _ => ()
  }
  match obj.get("input_modalities") {
    Some(input) =>
      match input_modalities_support_image(input) {
        Some(value) => return Some(value)
        None => ()
      }
    None => ()
  }
  match obj.get("inputModalities") {
    Some(input) => input_modalities_support_image(input)
    None => None
  }
}

///|
fn json_string_from_map_any(
  obj : Map[String, Json],
  keys : Array[String],
) -> String? {
  for key in keys {
    match json_string_from_map(obj, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn input_modalities_support_image(value : Json) -> Bool? {
  guard value is Array(modalities) else { return None }
  Some(
    modalities.any(item => {
      match item {
        String(text) => text.trim().to_lower() == "image"
        _ => false
      }
    }),
  )
}

///|
fn model_entry_matches(entry : Json, key : String?, model : String) -> Bool {
  match key {
    Some(key) if model_ids_match(key, model) => return true
    _ => ()
  }
  guard entry is Object(obj) else { return false }
  ["model", "id", "name"].any(field => {
    match json_string_from_map(obj, field) {
      Some(candidate) => model_ids_match(candidate, model)
      None => false
    }
  })
}

///|
fn model_ids_match(candidate : String, model : String) -> Bool {
  let candidate = normalize_media_model_id(candidate)
  let model = normalize_media_model_id(model)
  if candidate.is_empty() || model.is_empty() {
    return false
  }
  if candidate == model {
    return true
  }
  let candidate_tail = model_id_tail(candidate)
  let model_tail = model_id_tail(model)
  candidate_tail == model_tail ||
  candidate == model_tail ||
  candidate_tail == model
}

///|
fn normalize_media_model_id(value : String) -> String {
  let lower = value.trim().to_lower()
  let without_model_prefix = if lower.has_prefix("models/") {
    lower["models/".length():].to_owned()
  } else {
    lower.to_owned()
  }
  strip_one_m_suffix_for_upstream(without_model_prefix).trim().to_owned()
}

///|
fn model_id_tail(model : String) -> String {
  let parts = model.split("/").collect()
  match parts.last() {
    Some(part) => part.to_owned()
    None => model
  }
}

///|
fn json_bool_from_map_any(
  obj : Map[String, Json],
  keys : Array[String],
) -> Bool? {
  for key in keys {
    match obj.get(key) {
      Some(true) => return Some(true)
      Some(false) => return Some(false)
      _ => ()
    }
  }
  None
}

///|
fn ccs_media_retry_should_trigger(
  status_code : Int,
  response_body : String,
  request_body : Json,
) -> Bool {
  contains_image_blocks(request_body) &&
  is_unsupported_image_error_status(status_code, response_body)
}

///|
fn contains_image_blocks(body : Json) -> Bool {
  match body {
    Object(obj) =>
      messages_have_image_blocks(obj) ||
      responses_input_has_image_blocks(obj.get("input"))
    _ => false
  }
}

///|
fn messages_have_image_blocks(obj : Map[String, Json]) -> Bool {
  guard obj.get("messages") is Some(Array(messages)) else { return false }
  messages.any(message => {
    match message {
      Object(message_obj) =>
        match message_obj.get("content") {
          Some(content) => content_has_image_blocks(content)
          None => false
        }
      _ => false
    }
  })
}

///|
fn content_has_image_blocks(content : Json) -> Bool {
  guard content is Array(blocks) else { return false }
  blocks.any(block => {
    if is_image_block(block) {
      return true
    }
    match block {
      Object(block_obj) =>
        match block_obj.get("content") {
          Some(nested) => content_has_image_blocks(nested)
          None => false
        }
      _ => false
    }
  })
}

///|
fn responses_input_has_image_blocks(input : Json?) -> Bool {
  match input {
    Some(Array(items)) =>
      items.any(item => responses_input_item_has_image_blocks(item))
    Some(item) => responses_input_item_has_image_blocks(item)
    _ => false
  }
}

///|
fn responses_input_item_has_image_blocks(item : Json) -> Bool {
  guard item is Object(item_obj) else { return false }
  if json_string_from_map(item_obj, "type") == Some("input_image") {
    return true
  }
  match item_obj.get("content") {
    Some(content) => content_has_image_blocks(content)
    None => false
  }
}

///|
fn is_unsupported_image_error_status(status_code : Int, body : String) -> Bool {
  match status_code {
    400 | 415 | 422 | 501 => ()
    _ => return false
  }
  let message = extract_upstream_error_text(body).to_lower()
  let mentions_image = message.contains("image") ||
    message.contains("vision") ||
    message.contains("multimodal") ||
    message.contains("multi-modal") ||
    message.contains("modality") ||
    message.contains("modalities") ||
    message.contains("media") ||
    message.contains("attachment")
  if !mentions_image {
    return false
  }
  [
    "unsupported", "not supported", "does not support", "doesn't support", "do not support",
    "don't support", "only supports text", "text only", "text-only", "invalid content type",
    "invalid message content", "unknown variant", "unknown content type", "unrecognized content type",
    "cannot process", "cannot handle", "can't process", "can't handle", "unable to process",
  ].any(hint => message.contains(hint))
}

///|
fn extract_upstream_error_text(body : String) -> String {
  let parsed = @json.parse(body) catch { _ => return body }
  match parsed {
    Object(obj) => {
      match obj.get("error") {
        Some(Object(error_obj)) =>
          match json_string_from_map(error_obj, "message") {
            Some(message) => return message
            None => ()
          }
        Some(String(message)) => return message
        _ => ()
      }
      match json_string_from_map(obj, "message") {
        Some(message) => return message
        None => ()
      }
      match json_string_from_map(obj, "detail") {
        Some(detail) => return detail
        None => ()
      }
      parsed.stringify()
    }
    _ => parsed.stringify()
  }
}

///|
fn replace_image_blocks_with_marker(body : Json) -> MediaReplacementResult {
  guard body is Object(obj) else { return { body, count: 0 } }
  let mut count = 0
  match obj.get("messages") {
    Some(Array(messages)) => {
      let replaced_messages : Array[Json] = []
      for message in messages {
        match message {
          Object(message_obj) =>
            match message_obj.get("content") {
              Some(content) => {
                let result = replace_images_in_content(content, "text")
                count += result.count
                message_obj["content"] = result.body
                replaced_messages.push(Json::object(message_obj))
              }
              None => replaced_messages.push(Json::object(message_obj))
            }
          _ => replaced_messages.push(message)
        }
      }
      obj["messages"] = Json::array(replaced_messages)
    }
    _ => ()
  }
  match obj.get("input") {
    Some(input) => {
      let result = replace_images_in_responses_input(input)
      count += result.count
      obj["input"] = result.body
    }
    None => ()
  }
  { body: Json::object(obj), count }
}

///|
fn replace_images_in_content(
  content : Json,
  text_type : String,
) -> MediaReplacementResult {
  guard content is Array(blocks) else { return { body: content, count: 0 } }
  let replaced_blocks : Array[Json] = []
  let mut count = 0
  for block in blocks {
    if is_image_block(block) {
      replaced_blocks.push(image_marker_block(block, text_type))
      count += 1
      continue
    }
    match block {
      Object(block_obj) =>
        match block_obj.get("content") {
          Some(nested) => {
            let result = replace_images_in_content(nested, text_type)
            count += result.count
            block_obj["content"] = result.body
            replaced_blocks.push(Json::object(block_obj))
          }
          None => replaced_blocks.push(Json::object(block_obj))
        }
      _ => replaced_blocks.push(block)
    }
  }
  { body: Json::array(replaced_blocks), count }
}

///|
fn replace_images_in_responses_input(input : Json) -> MediaReplacementResult {
  match input {
    Array(items) => {
      let replaced_items : Array[Json] = []
      let mut count = 0
      for item in items {
        let result = replace_images_in_responses_input_item(item)
        count += result.count
        replaced_items.push(result.body)
      }
      { body: Json::array(replaced_items), count }
    }
    Object(_) => replace_images_in_responses_input_item(input)
    _ => { body: input, count: 0 }
  }
}

///|
fn replace_images_in_responses_input_item(
  item : Json,
) -> MediaReplacementResult {
  guard item is Object(item_obj) else { return { body: item, count: 0 } }
  let mut count = 0
  if json_string_from_map(item_obj, "type") == Some("input_image") {
    let marker = image_marker_block(Json::object(item_obj), "input_text")
    guard marker is Object(marker_obj) else {
      return { body: marker, count: 1 }
    }
    count += 1
    match marker_obj.get("content") {
      Some(content) => {
        let result = replace_images_in_content(content, "input_text")
        count += result.count
        marker_obj["content"] = result.body
      }
      None => ()
    }
    return { body: Json::object(marker_obj), count }
  }
  match item_obj.get("content") {
    Some(content) => {
      let result = replace_images_in_content(content, "input_text")
      count += result.count
      item_obj["content"] = result.body
    }
    None => ()
  }
  { body: Json::object(item_obj), count }
}

///|
fn is_image_block(block : Json) -> Bool {
  guard block is Object(obj) else { return false }
  match json_string_from_map(obj, "type") {
    Some("image") | Some("image_url") | Some("input_image") => true
    _ => false
  }
}

///|
fn image_marker_block(block : Json, text_type : String) -> Json {
  let cache_control = match block {
    Object(obj) => obj.get("cache_control")
    _ => None
  }
  let marker : Map[String, Json] = {
    "type": Json::string(text_type),
    "text": Json::string(UNSUPPORTED_IMAGE_MARKER),
  }
  match cache_control {
    Some(cache_control) => marker["cache_control"] = cache_control
    None => ()
  }
  Json::object(marker)
}

///|
fn known_text_only_model(model : String) -> Bool {
  let lower = model.trim().to_lower()
  let without_model_prefix = if lower.has_prefix("models/") {
    lower["models/".length():].to_owned()
  } else {
    lower.to_owned()
  }
  let normalized = strip_one_m_suffix_for_upstream(without_model_prefix)
  let parts = normalized.split("/").collect()
  let tail = match parts.last() {
    Some(part) => part.to_owned()
    None => normalized
  }
  [
    "ark-code-latest", "deepseek-chat", "deepseek-reasoner", "deepseek-v4-flash",
    "deepseek-v4-pro", "glm-5.1", "kat-coder", "kat-coder-pro", "kat-coder-pro v1",
    "kat-coder-pro v2", "kat-coder-pro-v1", "kat-coder-pro-v2", "ling-2.5-1t", "longcat-flash-chat",
    "mimo-v2.5-pro", "us.deepseek.r1-v1",
  ].contains(tail) ||
  ["minimax-m2.7", "qwen3-coder", "step-3.5-flash"].any(prefix => {
    tail.has_prefix(prefix)
  })
}

///|
fn matches_schema_name_map(key : String) -> Bool {
  key == "properties" ||
  key == "patternProperties" ||
  key == "definitions" ||
  key == "$defs"
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
async fn Gateway::forward_gemini_native_sse_as_anthropic(
  self : Gateway,
  reader : &@io.Reader,
  events : Array[Json],
  provider_id : String,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  let state = GeminiNativeAnthropicStreamState::new()
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
  match (session_id, state.shadow_turn()) {
    (Some(session_id), Some(turn)) =>
      self.gemini_shadow.record_assistant_turn(provider_id, session_id, turn)
    _ => ()
  }
}

///|
fn gemini_native_stream_chunk_to_anthropic_events(
  chunk : Json,
) -> Array[StreamEvent] {
  let state = GeminiNativeAnthropicStreamState::new()
  state.push_chunk(chunk)
}

///|
fn openai_chat_stream_chunk_to_anthropic_events(
  chunk : Json,
) -> Array[StreamEvent] {
  let state = OpenAIChatAnthropicStreamState::new()
  state.push_chunk(chunk)
}

///|
priv struct GeminiNativeAnthropicToolSnapshot {
  mut id : String?
  mut name : String
  mut args : Json
  mut thought_signature : String?
}

///|
priv struct GeminiNativeAnthropicStreamState {
  mut message_id : String?
  mut model : String?
  mut next_content_index : Int
  mut has_sent_message_start : Bool
  mut text_block_index : Int?
  mut text_block_open : Bool
  mut accumulated_text : String
  tool_snapshots : Array[GeminiNativeAnthropicToolSnapshot]
  mut latest_usage : Json?
  mut latest_finish_reason : String?
  mut blocked_text : String?
  mut text_thought_signature : String?
  mut finished : Bool
}

///|
fn GeminiNativeAnthropicStreamState::new() -> GeminiNativeAnthropicStreamState {
  {
    message_id: None,
    model: None,
    next_content_index: 0,
    has_sent_message_start: false,
    text_block_index: None,
    text_block_open: false,
    accumulated_text: "",
    tool_snapshots: [],
    latest_usage: None,
    latest_finish_reason: None,
    blocked_text: None,
    text_thought_signature: None,
    finished: false,
  }
}

///|
fn GeminiNativeAnthropicStreamState::push_chunk(
  self : GeminiNativeAnthropicStreamState,
  chunk : Json,
) -> Array[StreamEvent] {
  let events : Array[StreamEvent] = []
  guard chunk is Object(obj) else { return events }
  if self.message_id is None {
    self.message_id = json_string_from_map(obj, "responseId")
  }
  if self.model is None {
    self.model = json_string_from_map(obj, "modelVersion")
  }
  if obj.get("usageMetadata") is Some(usage) {
    self.latest_usage = Some(usage)
  }
  if !self.has_sent_message_start {
    events.push(self.message_start_event())
    self.has_sent_message_start = true
  }
  if gemini_prompt_block_reason(obj) is Some(reason) {
    self.blocked_text = Some(
      "Request blocked by Gemini safety filters: \{reason}",
    )
    self.latest_finish_reason = Some("SAFETY")
  }
  guard obj.get("candidates") is Some(Array(candidates)) else { return events }
  guard candidates.get(0) is Some(Object(candidate)) else { return events }
  if json_string_from_map(candidate, "finishReason") is Some(reason) {
    self.latest_finish_reason = Some(reason)
  }
  guard candidate.get("content") is Some(Object(content)) else { return events }
  guard content.get("parts") is Some(Array(parts)) else { return events }
  self.merge_tool_snapshots_from_parts(parts)
  self.merge_text_thought_signature_from_parts(parts)
  let visible_text = gemini_visible_text_from_parts(parts)
  if !visible_text.is_empty() {
    let is_cumulative = visible_text.has_prefix(self.accumulated_text)
    let delta = if is_cumulative {
      visible_text[self.accumulated_text.length():].to_owned()
    } else {
      visible_text
    }
    if !delta.is_empty() {
      let index = self.ensure_text_block(events)
      events.push(
        anthropic_content_block_delta_event(index, "text_delta", "text", delta),
      )
      if is_cumulative {
        self.accumulated_text = visible_text
      } else {
        self.accumulated_text = self.accumulated_text + delta
      }
    }
  }
  events
}

///|
fn GeminiNativeAnthropicStreamState::finish(
  self : GeminiNativeAnthropicStreamState,
) -> Array[StreamEvent] {
  let events : Array[StreamEvent] = []
  if self.finished {
    return events
  }
  self.finished = true
  if !self.has_sent_message_start {
    events.push(self.message_start_event())
    self.has_sent_message_start = true
  }
  if self.accumulated_text.is_empty() && self.blocked_text is Some(text) {
    let index = self.ensure_text_block(events)
    events.push(
      anthropic_content_block_delta_event(index, "text_delta", "text", text),
    )
    self.accumulated_text = text
  }
  if self.text_block_open && self.text_block_index is Some(index) {
    events.push(anthropic_content_block_stop_event(index))
    self.text_block_open = false
  }
  self.emit_tool_snapshots(events)
  let has_tools = !self.tool_snapshots.is_empty()
  events.push(
    self.message_delta_event(
      gemini_finish_reason_to_anthropic(
        self.latest_finish_reason.unwrap_or("STOP"),
        has_tools,
      ),
    ),
  )
  events.push(anthropic_message_stop_stream_event())
  events
}

///|
fn GeminiNativeAnthropicStreamState::message_start_event(
  self : GeminiNativeAnthropicStreamState,
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
        "usage": gemini_native_stream_anthropic_usage_json(self.latest_usage),
      }),
    }).stringify(),
  }
}

///|
fn GeminiNativeAnthropicStreamState::ensure_text_block(
  self : GeminiNativeAnthropicStreamState,
  events : Array[StreamEvent],
) -> Int {
  let index = match self.text_block_index {
    Some(index) => index
    None => {
      let index = self.next_content_index
      self.next_content_index += 1
      self.text_block_index = Some(index)
      index
    }
  }
  if !self.text_block_open {
    events.push(anthropic_content_block_start_event(index, "text"))
    self.text_block_open = true
  }
  index
}

///|
fn GeminiNativeAnthropicStreamState::merge_tool_snapshots_from_parts(
  self : GeminiNativeAnthropicStreamState,
  parts : Array[Json],
) -> Unit {
  let mut position = 0
  for part in parts {
    guard part is Object(part_obj) else { continue }
    guard part_obj.get("functionCall") is Some(Object(function_call)) else {
      continue
    }
    let incoming_id = match json_string_from_map(function_call, "id") {
      Some(id) if !id.is_empty() => Some(id)
      _ => None
    }
    let snapshot = self.tool_snapshot_for_position(position, incoming_id)
    snapshot.id = match incoming_id {
      Some(id) => Some(id)
      None =>
        match snapshot.id {
          Some(existing) => Some(existing)
          None => Some(generate_gemini_synth_tool_call_id(position))
        }
    }
    snapshot.name = json_string_from_map(function_call, "name").unwrap_or(
      snapshot.name,
    )
    snapshot.args = function_call.get("args").unwrap_or(Json::object({}))
    match gemini_part_thought_signature(part_obj) {
      Some(signature) => snapshot.thought_signature = Some(signature)
      None => ()
    }
    position += 1
  }
}

///|
fn GeminiNativeAnthropicStreamState::merge_text_thought_signature_from_parts(
  self : GeminiNativeAnthropicStreamState,
  parts : Array[Json],
) -> Unit {
  for part in parts {
    guard part is Object(part_obj) else { continue }
    if part_obj.get("functionCall") is Some(_) {
      continue
    }
    guard part_obj.get("text") is Some(_) else { continue }
    match gemini_part_thought_signature(part_obj) {
      Some(signature) => self.text_thought_signature = Some(signature)
      None => ()
    }
  }
}

///|
fn gemini_part_thought_signature(part_obj : Map[String, Json]) -> String? {
  match json_string_from_map(part_obj, "thoughtSignature") {
    Some(signature) => Some(signature)
    None => json_string_from_map(part_obj, "thought_signature")
  }
}

///|
fn GeminiNativeAnthropicStreamState::tool_snapshot_for_position(
  self : GeminiNativeAnthropicStreamState,
  position : Int,
  incoming_id : String?,
) -> GeminiNativeAnthropicToolSnapshot {
  if incoming_id is Some(id) {
    let mut index = 0
    for snapshot in self.tool_snapshots {
      if snapshot.id == Some(id) {
        return snapshot
      }
      if index == position &&
        snapshot.id is Some(existing) &&
        existing.has_prefix("gemini_synth_") {
        return snapshot
      }
      index += 1
    }
  }
  if self.tool_snapshots.get(position) is Some(snapshot) {
    return snapshot
  }
  while self.tool_snapshots.length() <= position {
    self.tool_snapshots.push({
      id: None,
      name: "",
      args: Json::object({}),
      thought_signature: None,
    })
  }
  self.tool_snapshots[position]
}

///|
fn GeminiNativeAnthropicStreamState::emit_tool_snapshots(
  self : GeminiNativeAnthropicStreamState,
  events : Array[StreamEvent],
) -> Unit {
  for snapshot in self.tool_snapshots {
    if snapshot.name.is_empty() && snapshot.args == Json::object({}) {
      continue
    }
    let index = self.next_content_index
    self.next_content_index += 1
    events.push(
      anthropic_tool_block_start_event(
        index,
        snapshot.id.unwrap_or(""),
        if snapshot.name.is_empty() {
          "unknown"
        } else {
          snapshot.name
        },
      ),
    )
    events.push(
      anthropic_tool_input_delta_event(index, snapshot.args.stringify()),
    )
    events.push(anthropic_content_block_stop_event(index))
  }
}

///|
fn GeminiNativeAnthropicStreamState::shadow_turn(
  self : GeminiNativeAnthropicStreamState,
) -> GeminiAssistantTurn? {
  let parts : Array[Json] = []
  let shadow_text = if self.accumulated_text.is_empty() {
    self.blocked_text
  } else {
    Some(self.accumulated_text)
  }
  match (shadow_text, self.text_thought_signature) {
    (Some(text), Some(signature)) =>
      parts.push(
        Json::object({
          "text": Json::string(text),
          "thoughtSignature": Json::string(signature),
        }),
      )
    (Some(text), None) =>
      parts.push(Json::object({ "text": Json::string(text) }))
    (None, Some(signature)) =>
      parts.push(
        Json::object({
          "text": Json::string(""),
          "thoughtSignature": Json::string(signature),
        }),
      )
    (None, None) => ()
  }
  let tool_calls : Array[GeminiToolCallMeta] = []
  for snapshot in self.tool_snapshots {
    if snapshot.name.is_empty() && snapshot.args == Json::object({}) {
      continue
    }
    let function_call = Json::object({
      "id": Json::string(snapshot.id.unwrap_or("")),
      "name": Json::string(snapshot.name),
      "args": snapshot.args,
    })
    let part : Map[String, Json] = { "functionCall": function_call }
    match snapshot.thought_signature {
      Some(signature) => part["thoughtSignature"] = Json::string(signature)
      None => ()
    }
    parts.push(Json::object(part))
    tool_calls.push({
      id: snapshot.id,
      name: snapshot.name,
      args: snapshot.args,
      thought_signature: snapshot.thought_signature,
    })
  }
  if parts.is_empty() {
    return None
  }
  Some({
    assistant_content: Json::object({ "parts": Json::array(parts) }),
    tool_calls,
  })
}

///|
fn GeminiNativeAnthropicStreamState::message_delta_event(
  self : GeminiNativeAnthropicStreamState,
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
      "usage": gemini_native_stream_anthropic_usage_json(self.latest_usage),
    }).stringify(),
  }
}

///|
fn gemini_visible_text_from_parts(parts : Array[Json]) -> String {
  let texts : Array[String] = []
  for part in parts {
    guard part is Object(part_obj) else { continue }
    if part_obj.get("thought") == Some(Json::boolean(true)) {
      continue
    }
    if part_obj.get("functionCall") is Some(_) {
      continue
    }
    if part_obj.get("text") is Some(String(text)) {
      texts.push(text)
    }
  }
  texts.join("")
}

///|
fn gemini_native_stream_anthropic_usage_json(usage : Json?) -> Json {
  let body = match usage {
    Some(usage) => Json::object({ "usageMetadata": usage })
    None => Json::object({})
  }
  token_usage_from_gemini_response(body)
  .unwrap_or(TokenUsage::empty())
  .as_anthropic_usage_json()
}

///|
fn TokenUsage::as_anthropic_usage_json(self : TokenUsage) -> Json {
  let result : Map[String, Json] = {
    "input_tokens": Json::number(self.anthropic_input_tokens().to_double()),
    "output_tokens": Json::number(self.output_tokens.to_double()),
  }
  if self.cache_read_tokens > 0 {
    result["cache_read_input_tokens"] = Json::number(
      self.cache_read_tokens.to_double(),
    )
  }
  if self.cache_creation_tokens > 0 {
    result["cache_creation_input_tokens"] = Json::number(
      self.cache_creation_tokens.to_double(),
    )
  }
  Json::object(result)
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
  ignore(self.codex_chat_history.record_stream_events(reader.events))
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
fn generate_gemini_synth_tool_call_id(position : Int) -> String {
  "gemini_synth_\{position}"
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
  pending_events : Array[StreamEvent]
  responses_state : ResponsesStreamState
  mut partial_block : String
}

///|
fn CodexStreamReader::new(
  reader : &@io.Reader,
  model : String,
) -> CodexStreamReader {
  CodexStreamReader::{
    reader,
    model,
    events: [],
    pending_events: [],
    responses_state: ResponsesStreamState::new(model),
    partial_block: "",
  }
}

///|
async fn CodexStreamReader::read(self : CodexStreamReader) -> StreamEvent? {
  for ;; {
    if !self.pending_events.is_empty() {
      return Some(self.pending_events.remove(0))
    }
    match self.reader.read_until("\n") {
      Some(line) => {
        self.partial_block += line
        if !line.trim().is_empty() {
          continue
        }
      }
      None => if self.partial_block.trim().is_empty() { return None }
    }
    let block = self.partial_block
    self.partial_block = ""
    let (done, json, events) = codex_stream_events_from_sse_block(
      block,
      self.responses_state,
    )
    if done {
      return None
    }
    if json is Some(parsed) {
      self.events.push(parsed)
    }
    for event in events {
      self.pending_events.push(event)
    }
    if !self.pending_events.is_empty() {
      return Some(self.pending_events.remove(0))
    }
  }
}

///|
fn codex_stream_event_from_sse_block(
  block : String,
  model : String,
) -> (Bool, Json?, StreamEvent?) {
  if block.trim().is_empty() {
    return (false, None, None)
  }
  let mut event_name = ""
  let data_lines : Array[String] = []
  for line_view in block.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    match strip_sse_field(line, "event") {
      Some(event) => event_name = event.trim().to_owned()
      None =>
        match strip_sse_field(line, "data") {
          Some(data) => data_lines.push(data)
          None => ()
        }
    }
  }
  if data_lines.is_empty() {
    return (false, None, None)
  }
  let data = data_lines.join("\n")
  if data.trim() == "[DONE]" {
    return (true, None, None)
  }
  let parsed = @json.parse(data) catch { _ => return (false, None, None) }
  guard parsed is Object(obj) else { return (false, Some(parsed), None) }
  let actual_event_name = if event_name.is_empty() {
    json_string_from_map(obj, "type").unwrap_or("")
  } else {
    event_name
  }
  (false, Some(parsed), convert_stream_event(actual_event_name, obj, model))
}

///|
fn codex_stream_events_from_sse_block(
  block : String,
  state : ResponsesStreamState,
) -> (Bool, Json?, Array[StreamEvent]) {
  if block.trim().is_empty() {
    return (false, None, [])
  }
  let mut event_name = ""
  let data_lines : Array[String] = []
  for line_view in block.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    match strip_sse_field(line, "event") {
      Some(event) => event_name = event.trim().to_owned()
      None =>
        match strip_sse_field(line, "data") {
          Some(data) => data_lines.push(data)
          None => ()
        }
    }
  }
  if data_lines.is_empty() {
    return (false, None, [])
  }
  let data = data_lines.join("\n")
  if data.trim() == "[DONE]" {
    return (true, None, [])
  }
  let parsed = @json.parse(data) catch { _ => return (false, None, []) }
  guard parsed is Object(obj) else { return (false, Some(parsed), []) }
  let actual_event_name = if event_name.is_empty() {
    json_string_from_map(obj, "type").unwrap_or("")
  } else {
    event_name
  }
  (false, Some(parsed), state.push_event(actual_event_name, obj))
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
async fn write_codex_response_sse_event(
  w : @httpx.ResponseWriter,
  event : Json,
) -> Int {
  let event_type = match event {
    Object(obj) => json_string_from_map(obj, "type").unwrap_or("")
    _ => ""
  }
  if !event_type.is_empty() {
    w.write("event: \{event_type}\n")
  }
  let payload = event.stringify()
  w.write("data: \{payload}\n\n")
  w.flush()
  payload.length()
}

///|
async fn write_chat_provider_codex_stream_data(
  w : @httpx.ResponseWriter,
  data : String,
  state : ChatToCodexResponsesStreamState,
  stream_events : Array[Json],
) -> (Bool, Int) {
  let (done, _, events) = openai_chat_stream_data_to_codex_response_events(
    data, state,
  )
  let mut bytes = 0
  for event in events {
    stream_events.push(event)
    bytes += write_codex_response_sse_event(w, event)
  }
  (done, bytes)
}

///|
priv struct ResponsesStreamState {
  mut message_id : String?
  mut model : String
  mut has_sent_message_start : Bool
  mut has_tool_use : Bool
  mut next_content_index : Int
  mut current_text_index : Int?
  mut current_thinking_index : Int?
  mut fallback_open_index : Int?
  mut last_tool_index : Int?
  open_indices : Array[Int]
  index_by_key : Map[String, Int]
  tool_index_by_item_id : Map[String, Int]
  tool_name_by_index : Map[Int, String]
  tool_args_by_index : Map[Int, String]
}

///|
fn ResponsesStreamState::new(model : String) -> ResponsesStreamState {
  {
    message_id: None,
    model,
    has_sent_message_start: false,
    has_tool_use: false,
    next_content_index: 0,
    current_text_index: None,
    current_thinking_index: None,
    fallback_open_index: None,
    last_tool_index: None,
    open_indices: [],
    index_by_key: {},
    tool_index_by_item_id: {},
    tool_name_by_index: {},
    tool_args_by_index: {},
  }
}

///|
fn ResponsesStreamState::push_event(
  self : ResponsesStreamState,
  event_type : String,
  obj : Map[String, Json],
) -> Array[StreamEvent] {
  let events : Array[StreamEvent] = []
  match event_type {
    "response.created" => {
      let response_obj = responses_stream_response_object(obj)
      self.message_id = json_string_from_map(response_obj, "id")
      self.model = json_string_from_map(response_obj, "model").unwrap_or(
        self.model,
      )
      if convert_stream_event(event_type, obj, self.model) is Some(event) {
        events.push(event)
        self.has_sent_message_start = true
      }
    }
    "response.content_part.added" =>
      match obj.get("part") {
        Some(Object(part)) =>
          match json_string_from_map(part, "type") {
            Some("output_text") | Some("refusal") =>
              ignore(self.ensure_text_block(obj, events))
            _ => ()
          }
        _ => ()
      }
    "response.output_text.delta" | "response.refusal.delta" => {
      let delta = match obj.get("delta") {
        Some(String(text)) => text
        _ => return events
      }
      self.ensure_message_start(events)
      let index = self.ensure_text_block(obj, events)
      events.push(
        anthropic_content_block_delta_event(index, "text_delta", "text", delta),
      )
    }
    "response.reasoning.delta" => {
      let delta = match obj.get("delta") {
        Some(String(text)) => text
        _ =>
          match obj.get("text") {
            Some(String(text)) => text
            _ => return events
          }
      }
      self.ensure_message_start(events)
      self.close_current_text_block(events)
      let index = self.ensure_thinking_block(obj, events)
      events.push(
        anthropic_content_block_delta_event(
          index, "thinking_delta", "thinking", delta,
        ),
      )
    }
    "response.output_text.done" | "response.refusal.done" =>
      self.close_text_block_from_event(obj, events)
    "response.reasoning.done" =>
      self.close_thinking_block_from_event(obj, events)
    "response.output_item.added" => self.push_output_item_added(obj, events)
    "response.function_call_arguments.delta" =>
      self.push_function_call_arguments_delta(obj, events)
    "response.function_call_arguments.done" =>
      self.finish_function_call_arguments(obj, events)
    "response.completed" => {
      self.close_current_text_block(events)
      self.close_current_thinking_block(events)
      self.close_open_blocks(events)
      events.push(
        responses_stream_completed_event(obj, self.model, self.has_tool_use),
      )
    }
    _ =>
      if convert_stream_event(event_type, obj, self.model) is Some(event) {
        events.push(event)
      }
  }
  events
}

///|
fn ResponsesStreamState::ensure_message_start(
  self : ResponsesStreamState,
  events : Array[StreamEvent],
) -> Unit {
  if self.has_sent_message_start {
    return
  }
  events.push({
    event_type: "message_start",
    data: Json::object({
      "type": Json::string("message_start"),
      "message": Json::object({
        "id": Json::string(self.message_id.unwrap_or("")),
        "type": Json::string("message"),
        "role": Json::string("assistant"),
        "model": Json::string(self.model),
        "usage": openai_chat_zero_usage_json(),
      }),
    }).stringify(),
  })
  self.has_sent_message_start = true
}

///|
fn ResponsesStreamState::push_output_item_added(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Unit {
  guard obj.get("item") is Some(Object(item)) else { return }
  guard json_string_from_map(item, "type") == Some("function_call") else {
    return
  }
  self.has_tool_use = true
  self.close_current_text_block(events)
  self.close_current_thinking_block(events)
  self.ensure_message_start(events)
  let index = match responses_stream_item_id(obj, item) {
    Some(item_id) =>
      match self.tool_index_by_item_id.get(item_id) {
        Some(existing) => existing
        None => {
          let created = self.next_content_index
          self.next_content_index += 1
          self.tool_index_by_item_id[item_id] = created
          created
        }
      }
    None => {
      let created = self.next_content_index
      self.next_content_index += 1
      created
    }
  }
  self.last_tool_index = Some(index)
  let name = json_string_from_map(item, "name").unwrap_or("")
  self.tool_name_by_index[index] = name
  if !self.open_indices.contains(index) {
    self.open_indices.push(index)
    if self.tool_args_by_index.get(index) is None {
      self.tool_args_by_index[index] = ""
    }
    events.push(
      anthropic_tool_block_start_event(
        index,
        json_string_from_map(item, "call_id").unwrap_or(""),
        name,
      ),
    )
  }
}

///|
fn ResponsesStreamState::push_function_call_arguments_delta(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Unit {
  let delta = match obj.get("delta") {
    Some(String(delta)) => delta
    _ => return
  }
  self.has_tool_use = true
  let index = self.tool_index_from_event(obj)
  self.ensure_tool_block(index, obj, events)
  if self.tool_name_by_index.get(index) == Some("Read") {
    let buffered = self.tool_args_by_index.get(index).unwrap_or("")
    self.tool_args_by_index[index] = buffered + delta
  } else {
    events.push(anthropic_tool_input_delta_event(index, delta))
  }
}

///|
fn ResponsesStreamState::finish_function_call_arguments(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Unit {
  guard self.last_tool_index is Some(_) ||
    obj.get("item_id") is Some(_) ||
    obj.get("output_index") is Some(_) else {
    return
  }
  let index = self.tool_index_from_event(obj)
  if self.tool_name_by_index.get(index) == Some("Read") {
    let raw = json_string_from_map(obj, "arguments").unwrap_or(
      self.tool_args_by_index.get(index).unwrap_or(""),
    )
    let sanitized = sanitize_anthropic_tool_use_input_json("Read", raw)
    if !sanitized.is_empty() {
      events.push(anthropic_tool_input_delta_event(index, sanitized))
    }
  }
  self.close_open_block(events, index)
  match json_string_from_map(obj, "item_id") {
    Some(item_id) => self.tool_index_by_item_id.remove(item_id)
    None => ()
  }
  self.tool_name_by_index.remove(index)
  self.tool_args_by_index.remove(index)
}

///|
fn ResponsesStreamState::tool_index_from_event(
  self : ResponsesStreamState,
  obj : Map[String, Json],
) -> Int {
  match json_string_from_map(obj, "item_id") {
    Some(item_id) =>
      match self.tool_index_by_item_id.get(item_id) {
        Some(index) => return index
        None => ()
      }
    None => ()
  }
  match json_int(obj, "output_index") {
    Some(output_index) => {
      let key = "out:\{output_index}"
      match self.tool_index_by_item_id.get(key) {
        Some(index) => return index
        None => ()
      }
    }
    None => ()
  }
  match self.last_tool_index {
    Some(index) => index
    None => {
      let index = self.next_content_index
      self.next_content_index += 1
      self.last_tool_index = Some(index)
      match json_string_from_map(obj, "item_id") {
        Some(item_id) => self.tool_index_by_item_id[item_id] = index
        None => ()
      }
      index
    }
  }
}

///|
fn ResponsesStreamState::ensure_tool_block(
  self : ResponsesStreamState,
  index : Int,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Unit {
  self.ensure_message_start(events)
  if self.open_indices.contains(index) {
    return
  }
  self.open_indices.push(index)
  let name = match self.tool_name_by_index.get(index) {
    Some(name) => name
    None => json_string_from_map(obj, "name").unwrap_or("")
  }
  self.tool_name_by_index[index] = name
  if self.tool_args_by_index.get(index) is None {
    self.tool_args_by_index[index] = ""
  }
  events.push(
    anthropic_tool_block_start_event(
      index,
      json_string_from_map(obj, "call_id").unwrap_or(
        json_string_from_map(obj, "item_id").unwrap_or(""),
      ),
      name,
    ),
  )
}

///|
fn ResponsesStreamState::ensure_text_block(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Int {
  self.ensure_message_start(events)
  match self.current_text_index {
    Some(index) => index
    None => {
      let index = self.resolve_content_index(obj)
      self.current_text_index = Some(index)
      if !self.open_indices.contains(index) {
        self.open_indices.push(index)
        events.push(anthropic_content_block_start_event(index, "text"))
      }
      index
    }
  }
}

///|
fn ResponsesStreamState::ensure_thinking_block(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Int {
  self.ensure_message_start(events)
  match self.current_thinking_index {
    Some(index) => index
    None => {
      let index = self.resolve_content_index(obj)
      self.current_thinking_index = Some(index)
      if !self.open_indices.contains(index) {
        self.open_indices.push(index)
        events.push(anthropic_content_block_start_event(index, "thinking"))
      }
      index
    }
  }
}

///|
fn ResponsesStreamState::resolve_content_index(
  self : ResponsesStreamState,
  obj : Map[String, Json],
) -> Int {
  match responses_stream_content_part_key(obj) {
    Some(key) =>
      match self.index_by_key.get(key) {
        Some(index) => index
        None => {
          let index = self.next_content_index
          self.next_content_index += 1
          self.index_by_key[key] = index
          index
        }
      }
    None =>
      match self.fallback_open_index {
        Some(index) => index
        None => {
          let index = self.next_content_index
          self.next_content_index += 1
          self.fallback_open_index = Some(index)
          index
        }
      }
  }
}

///|
fn ResponsesStreamState::close_current_text_block(
  self : ResponsesStreamState,
  events : Array[StreamEvent],
) -> Unit {
  match self.current_text_index {
    Some(index) => {
      self.current_text_index = None
      self.close_open_block(events, index)
      self.clear_fallback_if_index(index)
    }
    None => ()
  }
}

///|
fn ResponsesStreamState::close_text_block_from_event(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Unit {
  let index = match self.current_text_index {
    Some(index) => {
      self.current_text_index = None
      Some(index)
    }
    None => self.content_index_from_event(obj)
  }
  match index {
    Some(index) => {
      self.close_open_block(events, index)
      self.clear_fallback_if_index(index)
    }
    None => ()
  }
}

///|
fn ResponsesStreamState::close_current_thinking_block(
  self : ResponsesStreamState,
  events : Array[StreamEvent],
) -> Unit {
  match self.current_thinking_index {
    Some(index) => {
      self.current_thinking_index = None
      self.close_open_block(events, index)
      self.clear_fallback_if_index(index)
    }
    None => ()
  }
}

///|
fn ResponsesStreamState::close_thinking_block_from_event(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Unit {
  let index = match self.current_thinking_index {
    Some(index) => {
      self.current_thinking_index = None
      Some(index)
    }
    None => self.content_index_from_event(obj)
  }
  match index {
    Some(index) => {
      self.close_open_block(events, index)
      self.clear_fallback_if_index(index)
    }
    None => ()
  }
}

///|
fn ResponsesStreamState::content_index_from_event(
  self : ResponsesStreamState,
  obj : Map[String, Json],
) -> Int? {
  match responses_stream_content_part_key(obj) {
    Some(key) =>
      match self.index_by_key.get(key) {
        Some(index) => Some(index)
        None => self.fallback_open_index
      }
    None => self.fallback_open_index
  }
}

///|
fn ResponsesStreamState::clear_fallback_if_index(
  self : ResponsesStreamState,
  index : Int,
) -> Unit {
  if self.fallback_open_index == Some(index) {
    self.fallback_open_index = None
  }
}

///|
fn ResponsesStreamState::close_open_block(
  self : ResponsesStreamState,
  events : Array[StreamEvent],
  index : Int,
) -> Unit {
  for position in 0..<self.open_indices.length() {
    if self.open_indices[position] == index {
      ignore(self.open_indices.remove(position))
      events.push(anthropic_content_block_stop_event(index))
      return
    }
  }
}

///|
fn ResponsesStreamState::close_open_blocks(
  self : ResponsesStreamState,
  events : Array[StreamEvent],
) -> Unit {
  while !self.open_indices.is_empty() {
    let index = self.open_indices.remove(0)
    events.push(anthropic_content_block_stop_event(index))
  }
  self.fallback_open_index = None
}

///|
fn responses_stream_content_part_key(obj : Map[String, Json]) -> String? {
  match (json_string_from_map(obj, "item_id"), json_int(obj, "content_index")) {
    (Some(item_id), Some(content_index)) =>
      Some("part:\{item_id}:\{content_index}")
    _ =>
      match (json_int(obj, "output_index"), json_int(obj, "content_index")) {
        (Some(output_index), Some(content_index)) =>
          Some("part:out:\{output_index}:\{content_index}")
        _ => None
      }
  }
}

///|
fn responses_stream_item_id(
  obj : Map[String, Json],
  item : Map[String, Json],
) -> String? {
  match json_string_from_map(item, "id") {
    Some(id) => Some(id)
    None =>
      match json_string_from_map(obj, "item_id") {
        Some(item_id) => Some(item_id)
        None =>
          match json_int(obj, "output_index") {
            Some(output_index) => Some("out:\{output_index}")
            None => None
          }
      }
  }
}

///|
fn sanitize_anthropic_tool_use_input_json(
  name : String,
  raw : String,
) -> String {
  if name != "Read" || raw.is_empty() {
    return raw
  }
  let parsed = @json.parse(raw) catch { _ => return raw }
  guard parsed is Object(obj) else { return raw }
  match obj.get("pages") {
    Some(String(value)) if value.is_empty() => obj.remove("pages")
    _ => ()
  }
  Json::object(obj).stringify()
}

///|
fn convert_stream_event(
  event_type : String,
  obj : Map[String, Json],
  model : String,
) -> StreamEvent? {
  match event_type {
    "response.created" => {
      let response_obj = responses_stream_response_object(obj)
      let usage = responses_stream_anthropic_usage_json(response_obj)
      let message_id = json_string_from_map(response_obj, "id").unwrap_or("")
      let response_model = json_string_from_map(response_obj, "model").unwrap_or(
        model,
      )
      let event_data = Json::object({
        "type": Json::string("message_start"),
        "message": Json::object({
          "id": Json::string(message_id),
          "type": Json::string("message"),
          "role": Json::string("assistant"),
          "model": Json::string(response_model),
          "usage": usage,
        }),
      })
      Some({ event_type: "message_start", data: event_data.stringify() })
    }
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
    "response.completed" =>
      Some(responses_stream_completed_event(obj, model, false))
    _ => None
  }
}

///|
fn responses_stream_completed_event(
  obj : Map[String, Json],
  _model : String,
  has_streamed_tool_use : Bool,
) -> StreamEvent {
  let response_obj = responses_stream_response_object(obj)
  let usage = responses_stream_anthropic_usage_json(response_obj)
  let stop_reason = responses_stream_stop_reason_json(
    json_string_from_map(response_obj, "status"),
    has_streamed_tool_use ||
    responses_stream_response_has_tool_use(response_obj),
    responses_stream_incomplete_reason(response_obj),
  )
  let event_data : Map[String, Json] = {
    "type": Json::string("message_delta"),
    "delta": { "stop_reason": stop_reason, "stop_sequence": Json::null() }.to_json(),
    "usage": usage,
  }
  { event_type: "message_delta", data: event_data.to_json().stringify() }
}

///|
fn responses_stream_response_object(
  obj : Map[String, Json],
) -> Map[String, Json] {
  match obj.get("response") {
    Some(Object(response_obj)) => response_obj
    _ => obj
  }
}

///|
fn responses_stream_anthropic_usage_json(
  response_obj : Map[String, Json],
) -> Json {
  guard response_obj.get("usage") is Some(Object(usage)) else {
    return openai_chat_zero_usage_json()
  }
  let input_tokens = match json_int(usage, "input_tokens") {
    Some(n) => n
    None => json_int_or_zero(usage, "prompt_tokens")
  }
  let output_tokens = match json_int(usage, "output_tokens") {
    Some(n) => n
    None => json_int_or_zero(usage, "completion_tokens")
  }
  let mut cache_read_tokens = match usage.get("input_tokens_details") {
    Some(Object(details)) => json_int_or_zero(details, "cached_tokens")
    _ =>
      match usage.get("prompt_tokens_details") {
        Some(Object(details)) => json_int_or_zero(details, "cached_tokens")
        _ => 0
      }
  }
  match json_int(usage, "cache_read_input_tokens") {
    Some(n) => cache_read_tokens = n
    None => ()
  }
  let cache_creation_tokens = json_int_or_zero(
    usage, "cache_creation_input_tokens",
  )
  TokenUsage::new(
    input_tokens~,
    output_tokens~,
    cache_read_tokens~,
    cache_creation_tokens~,
  ).as_anthropic_usage_json()
}

///|
fn responses_stream_response_has_tool_use(
  response_obj : Map[String, Json],
) -> Bool {
  match response_obj.get("output") {
    Some(Array(output)) =>
      output
      .iter()
      .any(fn(item) {
        match item {
          Object(item_obj) =>
            json_string_from_map(item_obj, "type") == Some("function_call")
          _ => false
        }
      })
    _ => false
  }
}

///|
fn responses_stream_incomplete_reason(
  response_obj : Map[String, Json],
) -> String? {
  match response_obj.get("incomplete_details") {
    Some(Object(details)) => json_string_from_map(details, "reason")
    _ => None
  }
}

///|
fn responses_stream_stop_reason_json(
  status : String?,
  has_tool_use : Bool,
  incomplete_reason : String?,
) -> Json {
  match status {
    Some("completed") if has_tool_use => Json::string("tool_use")
    Some("incomplete") =>
      match incomplete_reason {
        Some("max_output_tokens") | Some("max_tokens") =>
          Json::string("max_tokens")
        None => Json::string("max_tokens")
        _ => Json::string("end_turn")
      }
    Some(_) => Json::string("end_turn")
    None => Json::null()
  }
}
