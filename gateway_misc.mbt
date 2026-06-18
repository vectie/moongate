///|
pub struct Gateway {
  host : String
  port : Int
  model : String
  logger : @pino.Logger
  started_at_ms : Int
  /// Auth
  auth : AuthService
  /// Proxy routing and circuit breakers
  proxy : ProxyService
  /// Usage tracking and cost calculation
  usage : UsageService
  /// App configuration and settings
  config : ConfigService
  /// Session management
  session : SessionService
  /// Local workspace and file dialog operations
  workspace : WorkspaceService
  /// App runtime status and local tool lifecycle operations
  runtime : RuntimeService
  /// Skill discovery, installation, migration, and repository operations
  skills : SkillService
  /// OpenClaw and Hermes provider config
  openclaw : OpenClawService
}

///|
pub fn Gateway::new(
  port~ : Int,
  host? : String = "127.0.0.1",
  model? : String = "gpt-4o",
) -> Gateway {
  let logger = @pino.logger("moonstat", @pino.Transport::console())
  {
    host,
    port,
    model,
    logger,
    started_at_ms: @async.now().to_int(),
    auth: AuthService::new(),
    proxy: ProxyService::new(host, port),
    usage: UsageService::new(),
    config: ConfigService::new(),
    session: SessionService::new(),
    workspace: WorkspaceService::new(),
    runtime: RuntimeService::new(),
    skills: SkillService::new(),
    openclaw: OpenClawService::new(),
  }
}

///|
fn codex_forward_failed_error_message(
  provider_name : String,
  request_model : String,
  endpoint : String,
  cause : String,
) -> String {
  body_snippet(
    "Moonstat local proxy failed while handling Codex endpoint \{endpoint}. Provider: \{provider_name}; model: \{request_model}; cause: Codex upstream request failed: \{cause}",
    1800,
  )
}

///|
fn codex_forward_failed_error_json(
  provider : ProviderRouteTarget,
  request_model : String,
  endpoint : String,
  cause : String,
) -> Json {
  {
    "error": {
      "message": Json::string(
        codex_forward_failed_error_message(
          provider.provider_name,
          request_model,
          endpoint,
          cause,
        ),
      ),
      "type": Json::string("proxy_error"),
      "code": Json::string("moonstat_forward_failed"),
      "param": Json::null(),
      "provider": Json::string(provider.provider_name),
      "model": Json::string(request_model),
      "endpoint": Json::string(endpoint),
    }.to_json(),
  }.to_json()
}

///|
fn codex_forward_failed_error_body(
  provider : ProviderRouteTarget,
  request_model : String,
  endpoint : String,
  cause : String,
) -> String {
  codex_forward_failed_error_json(provider, request_model, endpoint, cause).stringify()
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
fn moon_first_stream_event_ms(current : Int?, started_at_ms : Int?) -> Int? {
  match current {
    Some(_) => current
    None =>
      match started_at_ms {
        Some(started_at) => Some(max_int(@async.now().to_int() - started_at, 0))
        None => Some(0)
      }
  }
}

///|
async fn ProxyService::handle_codex_responses(
  self : ProxyService,
  auth : AuthService,
  usage : UsageService,
  session_store : SessionService,
  model : String,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  compact? : Bool = false,
) -> Unit {
  let body = r.body.read_all()
  let body_str = body.text()
  usage.record_inbound(body_str.length())
  let _ = self.activate_provider(usage, "codex")
  usage.record_request_context("codex", model)
  let json_result : Result[Json, Error] = moon_result(() => {
    @json.parse(body_str)
  })
  match json_result {
    Err(_) => {
      usage.record_bad_request_with_provider(self)
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
      usage.record_stream_mode(stream)
      let request = normalize_codex_oauth_request(json)
      let client_format = moon_client_format_for_request(
        r.path.to_owned(),
        Some(json),
      ).to_string()
      let session = extract_client_session_context(
        r.headers,
        json,
        client_format,
      )
      let upstream_session_id = session.upstream_session_id()
      usage.record_request_context(
        "codex",
        json_string_field(json, "model").unwrap_or(model),
        session_id=Some(session.session_id),
      )
      let endpoint = codex_backend_responses_endpoint(
        compact,
        request_path=r.path,
      )
      if stream {
        self.forward_streaming_codex_response(
          auth, usage, session_store, model, request, endpoint, upstream_session_id,
          w,
        )
      } else {
        self.forward_non_streaming_codex_response(
          auth, usage, session_store, model, request, endpoint, upstream_session_id,
          w,
        )
      }
    }
  }
}

///|
async fn ProxyService::handle_chat_completions(
  self : ProxyService,
  auth : AuthService,
  usage : UsageService,
  session_store : SessionService,
  model : String,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  app_type? : String = "codex",
) -> Unit {
  let body = r.body.read_all()
  let body_str = body.text()
  usage.record_inbound(body_str.length())
  let _ = self.activate_provider(usage, app_type)
  usage.record_request_context(app_type, model)
  let json_result : Result[Json, Error] = moon_result(() => {
    @json.parse(body_str)
  })
  match json_result {
    Err(_) => {
      usage.record_bad_request_with_provider(self)
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadRequest)
      w.write(
        "{\"error\":{\"message\":\"Invalid JSON\",\"type\":\"invalid_request_error\"}}",
      )
      w.flush()
      return
    }
    Ok(json) => {
      let response_model = openai_chat_model(json).unwrap_or(model)
      let stream = json_bool_field(json, "stream").unwrap_or(false)
      usage.record_stream_mode(stream)
      let client_format = moon_client_format_for_request(
        r.path.to_owned(),
        Some(json),
      ).to_string()
      let session = extract_client_session_context(
        r.headers,
        json,
        client_format,
      )
      let upstream_session_id = session.upstream_session_id()
      usage.record_request_context(
        app_type,
        response_model,
        session_id=Some(session.session_id),
      )
      let request = openai_chat_to_codex_response_request(json, model)
      guard request is Some(codex_request) else {
        usage.record_bad_request_with_provider(self)
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
          auth, usage, session_store, codex_request, response_model, upstream_session_id,
          app_type, w,
        )
      } else {
        self.forward_non_streaming_chat_completion(
          auth, usage, session_store, codex_request, response_model, upstream_session_id,
          app_type, w,
        )
      }
    }
  }
}

///|
async fn ProxyService::forward_non_streaming_chat_completion(
  self : ProxyService,
  auth : AuthService,
  usage : UsageService,
  session_store : SessionService,
  request : Json,
  response_model : String,
  session_id : String?,
  app_type : String,
  w : @httpx.ResponseWriter,
) -> Unit {
  let selection = self.provider_router.select_providers(app_type)
  if provider_selection_is_all_circuits_open(selection) {
    usage.write_provider_selection_error(
      self,
      app_type,
      AllProvidersCircuitOpen,
      w,
    )
    return
  }
  let providers = if selection.is_ok() { selection.providers } else { [] }
  let attempted_provider_ids : Array[String] = []
  for ;; {
    let active_provider = self.active_provider_target(usage, providers)
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
            let error_body = codex_forward_failed_error_body(
              provider,
              response_model,
              "/chat/completions",
              "\{error}",
            )
            if !providers.is_empty() {
              let next = self.activate_next_provider_after_upstream_status(
                usage,
                app_type,
                providers,
                attempted_provider_ids,
                @status.BadGateway,
              )
              if next is Some(_) {
                continue
              }
              usage.record_upstream_error_status(
                error_body.length(),
                @status.BadGateway,
              )
            } else {
              usage.record_upstream_error_status_with_provider(
                self,
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
        guard auth.credentials is Some(creds) else {
          usage.record_unauthorized_with_provider(self)
          w.header().set("Content-Type", "application/json")
          w.write_header(@status.Unauthorized)
          w.write(
            "{\"error\":{\"message\":\"Not authenticated. Please login first.\",\"type\":\"authentication_error\"}}",
          )
          w.flush()
          return
        }
        let client = auth.codex_client(
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
      let parsed : Result[Json, Error] = moon_result(() => {
        @json.parse(response_body)
      })
      match parsed {
        Ok(json) => {
          ignore(session_store.codex_chat_history.record_response(json))
          let token_usage = token_usage_or_response_model(
            token_usage_from_codex_response_auto(json),
            json,
            ["model"],
          )
          let chat_response = codex_response_to_openai_chat_completion(
            json, response_model,
          )
          let chat_response_body = chat_response.stringify()
          usage.record_success_usage_with_provider(
            self,
            token_usage,
            chat_response_body.length(),
          )
          w.header().set("Content-Type", "application/json")
          w.write_header(@status.Ok)
          w.write(chat_response_body)
        }
        Err(_) => {
          usage.record_internal_error_with_provider(self)
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
        usage,
        app_type,
        providers,
        attempted_provider_ids,
        response.code,
      )
      if next is Some(_) {
        continue
      }
      usage.record_upstream_error_status(response_body.length(), response.code)
    } else {
      usage.record_upstream_error_status_with_provider(
        self,
        response_body.length(),
        response.code,
      )
    }
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write(response_body)
    w.flush()
    return
  }
}

///|
async fn ProxyService::forward_streaming_chat_completion(
  self : ProxyService,
  auth : AuthService,
  usage : UsageService,
  session_store : SessionService,
  request : Json,
  response_model : String,
  session_id : String?,
  app_type : String,
  w : @httpx.ResponseWriter,
) -> Unit {
  let selection = self.provider_router.select_providers(app_type)
  if provider_selection_is_all_circuits_open(selection) {
    usage.write_provider_selection_error(
      self,
      app_type,
      AllProvidersCircuitOpen,
      w,
    )
    return
  }
  let providers = if selection.is_ok() { selection.providers } else { [] }
  let attempted_provider_ids : Array[String] = []
  for ;; {
    let active_provider = self.active_provider_target(usage, providers)
    let (client, response, use_chat_bridge) = match active_provider {
      Some(provider) if provider.can_use_codex_compatible_upstream() => {
        let use_chat_bridge = provider.codex_uses_chat_completions()
        let endpoint = if use_chat_bridge {
          codex_compatible_chat_completions_endpoint(
            "/backend-api/codex/responses",
          )
        } else {
          codex_compatible_responses_endpoint("/backend-api/codex/responses")
        }
        let provider_request = if use_chat_bridge {
          codex_responses_request_to_openai_chat_completion(
            request, response_model,
          ).unwrap_or(request)
        } else {
          request
        }
        match
          self.post_codex_compatible_provider_stream(
            provider, endpoint, provider_request,
          ) {
          Ok((client, response)) => (client, response, use_chat_bridge)
          Err(error) => {
            let error_body = codex_forward_failed_error_body(
              provider,
              response_model,
              "/chat/completions",
              "\{error}",
            )
            if !providers.is_empty() {
              let next = self.activate_next_provider_after_upstream_status(
                usage,
                app_type,
                providers,
                attempted_provider_ids,
                @status.BadGateway,
              )
              if next is Some(_) {
                continue
              }
              usage.record_upstream_error_status(
                error_body.length(),
                @status.BadGateway,
              )
            } else {
              usage.record_upstream_error_status_with_provider(
                self,
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
        guard auth.credentials is Some(creds) else {
          usage.record_unauthorized_with_provider(self)
          w.header().set("Content-Type", "application/json")
          w.write_header(@status.Unauthorized)
          w.write(
            "{\"error\":{\"message\":\"Not authenticated. Please login first.\",\"type\":\"authentication_error\"}}",
          )
          w.flush()
          return
        }
        let client = auth.codex_client(
          creds,
          accept="text/event-stream",
          session_id~,
        )
        let response = client.post("/backend-api/codex/responses", request)
        (client, response, false)
      }
    }
    if response.code != 200 {
      let error_body = client.read_all().text()
      client.close()
      if !providers.is_empty() {
        let next = self.activate_next_provider_after_upstream_status(
          usage,
          app_type,
          providers,
          attempted_provider_ids,
          response.code,
        )
        if next is Some(_) {
          continue
        }
        usage.record_upstream_error_status(error_body.length(), response.code)
      } else {
        usage.record_upstream_error_status_with_provider(
          self,
          error_body.length(),
          response.code,
        )
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
            usage,
            app_type,
            providers,
            attempted_provider_ids,
            @status.BadGateway,
          )
          if next is Some(_) {
            continue
          }
          usage.record_upstream_error_status(
            error_body.length(),
            @status.BadGateway,
          )
        } else {
          usage.record_upstream_error_status_with_provider(
            self,
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
        let created = @os.unix_seconds()
        let stream_events : Array[Json] = []
        if !use_chat_bridge {
          w.write(
            "data: \{openai_chat_role_chunk(id, response_model, created).stringify()}\n\n",
          )
          w.flush()
        }
        usage.record_provider_result(self, true)
        let mut response_bytes = 0
        let mut first_token_ms : Int? = None
        if first_line is [.. "data: ", .. rest] {
          let data = rest.trim().to_owned()
          if use_chat_bridge {
            if push_sse_json_event(stream_events, data) {
              first_token_ms = usage.first_stream_event_ms(first_token_ms)
            }
            response_bytes += first_line.length() + 2
            w.write(first_line)
            w.write("\n\n")
            w.flush()
          } else if data != "[DONE]" {
            if push_sse_json_event(stream_events, data) {
              first_token_ms = usage.first_stream_event_ms(first_token_ms)
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
        }
        while client.read_until("\n") is Some(line) {
          guard line is [.. "data: ", .. rest] else { continue }
          let data = rest.trim().to_owned()
          if use_chat_bridge {
            response_bytes += line.length() + 2
            if data != "[DONE]" {
              if push_sse_json_event(stream_events, data) {
                first_token_ms = usage.first_stream_event_ms(first_token_ms)
              }
            }
            w.write(line)
            w.write("\n\n")
            w.flush()
            if data == "[DONE]" {
              break
            }
            continue
          }
          if data == "[DONE]" {
            break
          }
          if push_sse_json_event(stream_events, data) {
            first_token_ms = usage.first_stream_event_ms(first_token_ms)
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
        client.close()
        ignore(
          session_store.codex_chat_history.record_stream_events(stream_events),
        )
        usage.record_success_stream_usage_with_provider(
          self,
          token_usage_from_codex_stream_events_auto(stream_events),
          response_bytes,
          record_provider=false,
          first_token_ms~,
        )
        if !use_chat_bridge {
          w.write("data: [DONE]\n\n")
        }
        w.flush()
        return
      }
    }
  }
}

///|
async fn ProxyService::forward_non_streaming_codex_response(
  self : ProxyService,
  auth : AuthService,
  usage : UsageService,
  session_store : SessionService,
  model : String,
  request : Json,
  endpoint : String,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  let selection = self.provider_router.select_providers("codex")
  if provider_selection_is_all_circuits_open(selection) {
    usage.write_provider_selection_error(
      self,
      "codex",
      AllProvidersCircuitOpen,
      w,
    )
    return
  }
  let providers = if selection.is_ok() { selection.providers } else { [] }
  let attempted_provider_ids : Array[String] = []
  for ;; {
    let active_provider = self.active_provider_target(usage, providers)
    let outbound_request = session_store.codex_provider_outbound_request(
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
            codex_request_model(request, model),
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
                    codex_request_model(request, model),
                    outbound_request,
                  ).stringify()
              }
              (response, converted)
            } else {
              (response, body)
            }
          Err(error) => {
            let request_model = codex_request_model(request, model)
            let error_body = codex_forward_failed_error_body(
              provider,
              request_model,
              endpoint,
              "\{error}",
            )
            if !providers.is_empty() {
              let next = self.activate_next_provider_after_upstream_status(
                usage,
                "codex",
                providers,
                attempted_provider_ids,
                @status.BadGateway,
              )
              if next is Some(_) {
                continue
              }
              usage.record_upstream_error_status(
                error_body.length(),
                @status.BadGateway,
              )
            } else {
              usage.record_upstream_error_status_with_provider(
                self,
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
        guard auth.credentials is Some(creds) else {
          usage.record_unauthorized_with_provider(self)
          w.header().set("Content-Type", "application/json")
          w.write_header(@status.Unauthorized)
          w.write(
            "{\"error\":{\"message\":\"Not authenticated. Please login first.\",\"type\":\"authentication_error\"}}",
          )
          w.flush()
          return
        }
        let client = auth.codex_client(
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
      let parsed : Result[Json, Error] = moon_result(() => {
        @json.parse(response_body)
      })
      let token_usage = match parsed {
        Ok(json) => {
          ignore(session_store.codex_chat_history.record_response(json))
          token_usage_or_response_model(
            token_usage_from_codex_response_auto(json),
            json,
            ["model"],
          )
        }
        Err(_) => TokenUsage::empty()
      }
      usage.record_success_usage_with_provider(
        self,
        token_usage,
        response_body.length(),
      )
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.Ok)
      w.write(response_body)
      w.flush()
      return
    }
    if !providers.is_empty() {
      let next = self.activate_next_provider_after_upstream_status(
        usage,
        "codex",
        providers,
        attempted_provider_ids,
        response.code,
      )
      if next is Some(_) {
        continue
      }
      usage.record_upstream_error_status(response_body.length(), response.code)
    } else {
      usage.record_upstream_error_status_with_provider(
        self,
        response_body.length(),
        response.code,
      )
    }
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write(response_body)
    w.flush()
    return
  }
}

///|
fn codex_request_model(request : Json, fallback : String) -> String {
  guard request is Object(obj) else { return fallback }
  json_string_from_map(obj, "model").unwrap_or(fallback)
}

///|
async fn ProxyService::forward_streaming_codex_response(
  self : ProxyService,
  auth : AuthService,
  usage : UsageService,
  session_store : SessionService,
  model : String,
  request : Json,
  endpoint : String,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  let selection = self.provider_router.select_providers("codex")
  if provider_selection_is_all_circuits_open(selection) {
    usage.write_provider_selection_error(
      self,
      "codex",
      AllProvidersCircuitOpen,
      w,
    )
    return
  }
  let providers = if selection.is_ok() { selection.providers } else { [] }
  let attempted_provider_ids : Array[String] = []
  for ;; {
    let active_provider = self.active_provider_target(usage, providers)
    let outbound_request = session_store.codex_provider_outbound_request(
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
            codex_request_model(request, model),
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
            let request_model = codex_request_model(request, model)
            let error_body = codex_forward_failed_error_body(
              provider,
              request_model,
              endpoint,
              "\{error}",
            )
            if !providers.is_empty() {
              let next = self.activate_next_provider_after_upstream_status(
                usage,
                "codex",
                providers,
                attempted_provider_ids,
                @status.BadGateway,
              )
              if next is Some(_) {
                continue
              }
              usage.record_upstream_error_status(
                error_body.length(),
                @status.BadGateway,
              )
            } else {
              usage.record_upstream_error_status_with_provider(
                self,
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
        guard auth.credentials is Some(creds) else {
          usage.record_unauthorized_with_provider(self)
          w.header().set("Content-Type", "application/json")
          w.write_header(@status.Unauthorized)
          w.write(
            "{\"error\":{\"message\":\"Not authenticated. Please login first.\",\"type\":\"authentication_error\"}}",
          )
          w.flush()
          return
        }
        let client = auth.codex_client(
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
          usage,
          "codex",
          providers,
          attempted_provider_ids,
          response.code,
        )
        if next is Some(_) {
          continue
        }
        usage.record_upstream_error_status(error_body.length(), response.code)
      } else {
        usage.record_upstream_error_status_with_provider(
          self,
          error_body.length(),
          response.code,
        )
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
            usage,
            "codex",
            providers,
            attempted_provider_ids,
            @status.BadGateway,
          )
          if next is Some(_) {
            continue
          }
          usage.record_upstream_error_status(
            error_body.length(),
            @status.BadGateway,
          )
        } else {
          usage.record_upstream_error_status_with_provider(
            self,
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
        let mut first_token_ms : Int? = None
        let chat_state = ChatToCodexResponsesStreamState::new_with_context(
          codex_request_model(request, model),
          codex_chat_tool_context_from_responses_request(outbound_request),
        )
        if first_line is [.. "data: ", .. rest] {
          let data = rest.trim().to_owned()
          if use_chat_bridge {
            let before = stream_events.length()
            let (_, bytes) = write_chat_provider_codex_stream_data(
              w, data, chat_state, stream_events,
            )
            response_bytes += bytes
            if stream_events.length() > before {
              first_token_ms = usage.first_stream_event_ms(first_token_ms)
            }
          } else {
            if data != "[DONE]" {
              if push_sse_json_event(stream_events, data) {
                first_token_ms = usage.first_stream_event_ms(first_token_ms)
              }
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
        usage.record_provider_result(self, true)
        while client.read_until("\n") is Some(line) {
          if use_chat_bridge {
            guard line is [.. "data: ", .. rest] else { continue }
            let data = rest.trim().to_owned()
            let before = stream_events.length()
            let (done, bytes) = write_chat_provider_codex_stream_data(
              w, data, chat_state, stream_events,
            )
            response_bytes += bytes
            if stream_events.length() > before {
              first_token_ms = usage.first_stream_event_ms(first_token_ms)
            }
            if done {
              break
            }
          } else {
            response_bytes += line.length() + 1
            if line is [.. "data: ", .. rest] {
              let data = rest.trim().to_owned()
              if data != "[DONE]" {
                if push_sse_json_event(stream_events, data) {
                  first_token_ms = usage.first_stream_event_ms(first_token_ms)
                }
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
        ignore(
          session_store.codex_chat_history.record_stream_events(stream_events),
        )
        usage.record_success_stream_usage_with_provider(
          self,
          token_usage_from_codex_stream_events_auto(stream_events),
          response_bytes,
          record_provider=false,
          first_token_ms~,
          skip_empty_usage=use_chat_bridge,
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
fn ProviderRouteTarget::claude_api_format_for_model(
  self : ProviderRouteTarget,
  model : String,
) -> String {
  if !self.is_github_copilot_upstream() {
    return self.claude_api_format()
  }
  match self.copilot_model_vendor(model) {
    Some(vendor) if vendor.to_lower() == "openai" => "openai_responses"
    _ => "openai_chat"
  }
}

///|
fn ProviderRouteTarget::copilot_model_vendor(
  self : ProviderRouteTarget,
  model : String,
) -> String? {
  guard self.settings_config is Some(Object(settings)) else { return None }
  for
    key in [
      "copilotModels", "copilot_models", "modelCatalog", "model_catalog", "models",
    ] {
    match settings.get(key) {
      Some(models) =>
        match copilot_model_vendor_from_models_json(model, models) {
          Some(vendor) => return Some(vendor)
          None => ()
        }
      None => ()
    }
  }
  None
}

///|
fn claude_api_format_needs_transform(api_format : String) -> Bool {
  api_format == "openai_chat" ||
  api_format == "openai_responses" ||
  api_format == "gemini_native"
}

///|
const MOONSTAT_PROXY_MANAGED_PLACEHOLDER = "PROXY_MANAGED"

///|
const HERMES_WEB_OFFLINE_ERROR = "hermes_web_offline"

///|
fn moon_is_managed_account_upstream_url(url : String) -> Bool {
  let (origin, path) = split_origin_and_path(url)
  let host = extract_host(origin).to_lower()
  host == "githubcopilot.com" ||
  host.has_suffix(".githubcopilot.com") ||
  (host == "chatgpt.com" && path.has_prefix("/backend-api/codex"))
}

///|
fn parse_custom_user_agent(value : String?) -> String? {
  match value {
    Some(raw) => {
      let trimmed = raw.trim().to_owned()
      if trimmed.is_empty() || !custom_user_agent_header_value_valid(trimmed) {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}

///|
fn custom_user_agent_header_value_valid(value : String) -> Bool {
  for ch in value {
    let code = ch.to_int()
    if code == 9 {
      continue
    }
    if code < 32 || code == 127 {
      return false
    }
  }
  true
}

///|
fn moon_claude_code_beta_header(existing_beta : String?) -> String {
  let claude_code_beta = "claude-code-20250219"
  match existing_beta {
    Some(beta) if beta.contains(claude_code_beta) => beta
    Some(beta) if !beta.trim().is_empty() => "\{claude_code_beta},\{beta}"
    _ => claude_code_beta
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
fn claude_transform_endpoint(
  api_format : String,
  is_stream : Bool,
  request_path? : StringView = "/v1/messages",
) -> String {
  let request_path_only = match request_path.find("?") {
    Some(index) => request_path[:index]
    None => request_path
  }
  if !is_claude_messages_path(request_path_only) {
    return request_path.to_owned()
  }
  let query = claude_transform_passthrough_query(
    request_path, api_format, is_stream,
  )
  let target = match api_format {
    "openai_responses" => "/v1/responses"
    "openai_chat" => "/v1/chat/completions"
    "gemini_native" =>
      if is_stream {
        "/v1beta/models/__MODEL__:streamGenerateContent"
      } else {
        "/v1beta/models/__MODEL__:generateContent"
      }
    _ => "/v1/messages"
  }
  match query {
    Some(query) if !query.is_empty() => "\{target}?\{query}"
    _ => target
  }
}

///|
fn is_claude_messages_path(path : StringView) -> Bool {
  path == "/v1/messages"
}

///|
fn claude_transform_passthrough_query(
  request_path : StringView,
  api_format : String,
  is_stream : Bool,
) -> String? {
  match request_path.find("?") {
    Some(index) => {
      let path = request_path[:index]
      let query = request_path[index + 1:]
      let stripped = if is_claude_messages_path(path) {
        strip_claude_beta_query(query)
      } else {
        Some(query.to_owned())
      }
      gemini_stream_query_extra(api_format, is_stream, stripped)
    }
    None => gemini_stream_query_extra(api_format, is_stream, None)
  }
}

///|
fn strip_claude_beta_query(query : StringView) -> String? {
  let parts : Array[String] = []
  for pair in query.split("&") {
    if !pair.is_empty() && !pair.has_prefix("beta=") {
      parts.push(pair.to_owned())
    }
  }
  if parts.is_empty() {
    None
  } else {
    Some(parts.join("&"))
  }
}

///|
fn gemini_stream_query_extra(
  api_format : String,
  is_stream : Bool,
  query : String?,
) -> String? {
  if api_format != "gemini_native" {
    return query
  }
  let parts : Array[String] = []
  match query {
    Some(query) =>
      for pair in query.split("&") {
        if !pair.is_empty() && !pair.has_prefix("alt=") {
          parts.push(pair.to_owned())
        }
      }
    None => ()
  }
  if is_stream {
    parts.push("alt=sse")
  }
  Some(parts.join("&"))
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
async fn AuthService::codex_client(
  self : AuthService,
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
priv enum MoonClientFormat {
  Claude
  Codex
  OpenAI
  Gemini
  GeminiCli
  Unknown
} derive(Eq)

///|
fn MoonClientFormat::to_string(self : MoonClientFormat) -> String {
  match self {
    Claude => "claude"
    Codex => "codex"
    OpenAI => "openai"
    Gemini => "gemini"
    GeminiCli => "gemini_cli"
    Unknown => "unknown"
  }
}

///|
fn moon_client_format_from_path(path : String) -> MoonClientFormat {
  if path.contains("/v1/messages") {
    Claude
  } else if path.contains("/v1/responses") {
    Codex
  } else if path.contains("/v1/chat/completions") {
    OpenAI
  } else if path.contains("/v1internal/") && path.contains("generateContent") {
    GeminiCli
  } else if (path.contains("/v1beta/") || path.contains("/v1/")) &&
    path.contains("generateContent") {
    Gemini
  } else if path.contains("generateContent") {
    Gemini
  } else {
    Unknown
  }
}

///|
fn moon_client_format_from_body(body : Json) -> MoonClientFormat {
  guard body is Object(obj) else { return Unknown }
  if obj.get("messages") is Some(_) &&
    obj.get("model") is Some(_) &&
    obj.get("response_format") is None &&
    obj.get("contents") is None {
    if obj.get("max_tokens") is Some(_) {
      return Claude
    }
    return OpenAI
  }
  if obj.get("input") is Some(_) {
    return Codex
  }
  if obj.get("contents") is Some(_) {
    return Gemini
  }
  Unknown
}

///|
fn moon_client_format_for_request(
  path : String,
  body : Json?,
) -> MoonClientFormat {
  let format = moon_client_format_from_path(path)
  if format != Unknown {
    return format
  }
  match body {
    Some(body) => moon_client_format_from_body(body)
    None => Unknown
  }
}

///|
priv struct MoonClientSession {
  session_id : String
  client_provided : Bool
}

///|
fn MoonClientSession::upstream_session_id(self : MoonClientSession) -> String? {
  if self.client_provided {
    Some(self.session_id)
  } else {
    None
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
      let without_query = match rest.find("?") {
        Some(end) => rest[:end]
        None => rest
      }
      let model = match without_query.find(":") {
        Some(end) => without_query[:end].to_owned()
        None => without_query.to_owned()
      }
      if model.is_empty() {
        "unknown"
      } else {
        normalize_gemini_model_id(model)
      }
    }
    None => "unknown"
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
fn codex_base_is_full_url() -> Bool {
  env_bool("MOONSTAT_CODEX_FULL_URL") || env_bool("CODEX_FULL_URL")
}

///|
fn claude_base_is_full_url() -> Bool {
  env_bool("MOONSTAT_CLAUDE_FULL_URL") || env_bool("ANTHROPIC_FULL_URL")
}

///|
fn moon_model_mapping_from_env() -> ModelMapping? {
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
fn moon_normalize_app_type(app : String) -> String {
  match app.trim().to_lower() {
    "claude-desktop" | "claude_desktop" => "claude-desktop"
    "codex" => "codex"
    "gemini" => "gemini"
    "opencode" | "open-code" | "open_code" => "opencode"
    "openclaw" | "open-claw" | "open_claw" => "openclaw"
    "hermes" => "hermes"
    "omo" => "omo"
    "omo-slim" | "omo_slim" => "omo-slim"
    _ => "claude"
  }
}

///|
fn moon_home_dir() -> String {
  @os.home() catch {
    _ => "."
  }
}

///|
fn moon_ascii_digit_at(value : String, index : Int) -> Bool {
  let ch = value[index]
  ch >= '0' && ch <= '9'
}

///|
async fn moon_ensure_directory(path : String) -> Bool {
  @fsx.make_directory(path, recursive=true, exists_ok=true) catch {
    _ => return false
  }
  true
}

///|
async fn moon_open_directory_result_json(path : String) -> Result[Json, String] {
  if !moon_ensure_directory(path) {
    return Err("open_directory_create_failed")
  }
  Ok(Json::boolean(true))
}

///|
fn moon_preview(content : String, limit : Int) -> String {
  if content.length() <= limit {
    content
  } else {
    content[:limit].to_owned()
  }
}

///|
fn moon_count_case_insensitive_matches(
  haystack : String,
  needle : String,
) -> (Int, Int?) {
  let lower = haystack.to_lower()
  let query = needle.to_lower()
  if query.is_empty() {
    return (0, None)
  }
  let mut count = 0
  let mut first : Int? = None
  let mut offset = 0
  while offset <= lower.length() {
    match lower[offset:].find(query) {
      Some(found) => {
        let pos = offset + found
        if first is None {
          first = Some(pos)
        }
        count = count + 1
        offset = pos + query.length()
      }
      None => break
    }
  }
  (count, first)
}

///|
fn moon_preserve_secret_if_empty(
  incoming : Map[String, Json],
  existing : Map[String, Json],
  object_key : String,
  secret_key : String,
) -> Unit {
  guard incoming.get(object_key) is Some(Object(incoming_obj)) else { return }
  guard existing.get(object_key) is Some(Object(existing_obj)) else { return }
  let incoming_secret = json_string_from_map(incoming_obj, secret_key).unwrap_or(
    "",
  )
  let existing_secret = json_string_from_map(existing_obj, secret_key).unwrap_or(
    "",
  )
  if incoming_secret.is_empty() && !existing_secret.is_empty() {
    incoming_obj[secret_key] = Json::string(existing_secret)
    incoming[object_key] = Json::object(incoming_obj)
  }
}

///|
fn moon_optional_path_from_request(path : StringView, body : Json?) -> String? {
  match proxy_string_request(path, body, ["path", "appConfigDir"]) {
    Some(value) if !value.trim().is_empty() => return Some(value)
    Some(_) => return None
    None => ()
  }
  match body {
    Some(Object(obj)) =>
      match obj.get("path") {
        Some(Null) => None
        _ => None
      }
    _ => None
  }
}

///|
fn moon_json_primary_api_key_any(content : String) -> Bool {
  let parsed : Result[Json, Error] = moon_result(() => @json.parse(content))
  match parsed {
    Ok(Object(obj)) =>
      match json_string_from_map(obj, "primaryApiKey") {
        Some(value) => value == "any"
        None => false
      }
    _ => false
  }
}

///|
async fn moon_env_conflicts_json(app : String) -> Json {
  moon_env_conflicts_json_with_shell_files(app, moon_env_shell_config_paths())
}

///|
async fn moon_push_shell_env_conflicts(
  conflicts : Array[Json],
  file_path : String,
  keywords : Array[String],
) -> Unit {
  let content = @fsx.read_file(file_path) catch { _ => return }
  let mut line_number = 0
  for line_view in content.split("\n") {
    line_number += 1
    let trimmed = line_view.to_owned().trim().to_owned()
    guard moon_env_assignment_line(trimmed) is Some((var_name, var_value)) else {
      continue
    }
    if moon_env_name_matches_keywords(var_name, keywords) {
      conflicts.push(
        {
          "varName": Json::string(var_name),
          "varValue": Json::string(moon_trim_env_value_quotes(var_value)),
          "sourceType": Json::string("file"),
          "sourcePath": Json::string("\{file_path}:\{line_number}"),
        }.to_json(),
      )
    }
  }
}

///|
fn moon_env_conflict_keys(app : String) -> Array[String] {
  match app {
    "codex" =>
      ["OPENAI_API_KEY", "OPENAI_BASE_URL", "CODEX_HOME", "CODEX_AUTH_TOKEN"]
    "gemini" =>
      [
        "GEMINI_API_KEY", "GOOGLE_API_KEY", "GEMINI_BASE_URL", "GOOGLE_GEMINI_BASE_URL",
      ]
    "opencode" | "omo" | "omo-slim" =>
      [
        "OPENCODE_CONFIG_DIR", "OPENCODE_DB", "OPENAI_API_KEY", "ANTHROPIC_API_KEY",
      ]
    "openclaw" =>
      [
        "OPENCLAW_CONFIG_DIR", "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY",
      ]
    "hermes" =>
      [
        "HERMES_CONFIG_DIR", "HERMES_WEB_PORT", "OPENAI_API_KEY", "ANTHROPIC_API_KEY",
      ]
    _ =>
      [
        "ANTHROPIC_API_KEY", "ANTHROPIC_BASE_URL", "CLAUDE_CONFIG_DIR", "CLAUDE_CODE_USE_BEDROCK",
      ]
  }
}

///|
async fn moon_delete_env_vars_json(body : Json?) -> Result[Json, String] {
  let backup = moon_env_backup_json(body)
  guard backup is Object(obj) else { return Err("invalid_backup") }
  guard obj.get("backupPath") is Some(String(backup_path)) else {
    return Err("missing_backup_path")
  }
  @fsx.make_directory(
    @pathx.dirname(backup_path),
    recursive=true,
    exists_ok=true,
  ) catch {
    error => return Err("创建备份目录失败: \{error}")
  }
  @fsx.write_to_file(backup_path, backup.stringify(indent=2) + "\n") catch {
    error => return Err("写入备份文件失败: \{error}")
  }
  for conflict in moon_env_conflicts_from_body(body) {
    match moon_delete_single_env_conflict(conflict) {
      Ok(_) => ()
      Err(error) =>
        return Err(
          "删除环境变量失败: \{error}. 备份已保存到: \{backup_path}",
        )
    }
  }
  Ok(backup)
}

///|
async fn moon_delete_single_env_conflict(
  conflict : Json,
) -> Result[Unit, String] {
  guard conflict is Object(obj) else { return Err("invalid_conflict") }
  let source_type = moon_env_conflict_string(obj, "sourceType", "source_type")
  let var_name = moon_env_conflict_string(obj, "varName", "var_name")
  let source_path = moon_env_conflict_string(obj, "sourcePath", "source_path")
  match (source_type, var_name, source_path) {
    (Some("file"), Some(var_name), Some(source_path)) => {
      let file_path = moon_env_source_file_path(source_path)
      guard !file_path.is_empty() else {
        return Err("无效的文件路径格式")
      }
      let content = @fsx.read_file(file_path) catch {
        error => return Err("读取文件失败 \{file_path}: \{error}")
      }
      let kept : Array[String] = []
      for line_view in content.split("\n") {
        let line = line_view.to_owned()
        match moon_env_assignment_line(line.trim().to_owned()) {
          Some((name, _)) if name == var_name => ()
          _ => kept.push(line)
        }
      }
      @fsx.write_to_file(file_path, kept.join("\n")) catch {
        error => return Err("写入文件失败 \{file_path}: \{error}")
      }
      Ok(())
    }
    (Some("system"), _, _) | (Some("process"), _, _) => Ok(())
    (Some(other), _, _) => Err("未知的环境变量来源类型: \{other}")
    _ => Err("invalid_conflict")
  }
}

///|
async fn moon_restore_single_env_conflict(
  conflict : Json,
) -> Result[Unit, String] {
  guard conflict is Object(obj) else { return Err("invalid_conflict") }
  let source_type = moon_env_conflict_string(obj, "sourceType", "source_type")
  let var_name = moon_env_conflict_string(obj, "varName", "var_name")
  let var_value = moon_env_conflict_string(obj, "varValue", "var_value")
  let source_path = moon_env_conflict_string(obj, "sourcePath", "source_path")
  match (source_type, var_name, var_value, source_path) {
    (Some("file"), Some(var_name), Some(var_value), Some(source_path)) => {
      let file_path = moon_env_source_file_path(source_path)
      guard !file_path.is_empty() else {
        return Err("无效的文件路径格式")
      }
      let content = @fsx.read_file(file_path) catch {
        error => return Err("读取文件失败 \{file_path}: \{error}")
      }
      @fsx.write_to_file(
        file_path,
        content + "\nexport \{var_name}=\{var_value}",
      ) catch {
        error => return Err("写入文件失败 \{file_path}: \{error}")
      }
      Ok(())
    }
    (Some(other), _, _, _) =>
      Err("无法恢复类型为 \{other} 的环境变量")
    _ => Err("invalid_conflict")
  }
}

///|
fn moon_env_conflicts_from_body(body : Json?) -> Array[Json] {
  match body {
    Some(Array(items)) => items
    Some(Object(obj)) =>
      match obj.get("conflicts") {
        Some(Array(items)) => items
        _ => []
      }
    _ => []
  }
}

///|
fn moon_env_conflict_string(
  obj : Map[String, Json],
  key : String,
  alt : String,
) -> String? {
  match obj.get(key) {
    Some(String(value)) => Some(value)
    _ =>
      match obj.get(alt) {
        Some(String(value)) => Some(value)
        _ => None
      }
  }
}

///|
fn moon_env_assignment_line(line : String) -> (String, String)? {
  if line.is_empty() || line.has_prefix("#") {
    return None
  }
  let export_line = if line.has_prefix("export ") {
    line[7:].to_owned().trim().to_owned()
  } else {
    line
  }
  match export_line.find("=") {
    Some(index) => {
      let name = export_line[:index].to_owned().trim().to_owned()
      let value = export_line[index + 1:].to_owned().trim().to_owned()
      if name.is_empty() {
        None
      } else {
        Some((name, value))
      }
    }
    None => None
  }
}

///|
fn moon_env_name_matches_keywords(
  var_name : String,
  keywords : Array[String],
) -> Bool {
  let upper = var_name.to_upper()
  for keyword in keywords {
    if upper.contains(keyword) {
      return true
    }
  }
  false
}

///|
fn moon_trim_env_value_quotes(value : String) -> String {
  let trimmed = value.trim().to_owned()
  if trimmed.length() >= 2 {
    if (trimmed.has_prefix("\"") && trimmed.has_suffix("\"")) ||
      (trimmed.has_prefix("'") && trimmed.has_suffix("'")) {
      return trimmed[1:trimmed.length() - 1].to_owned()
    }
  }
  trimmed
}

///|
fn moon_json_request(
  path : StringView,
  body : Json?,
  keys : Array[String],
) -> Json? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) => return Some(moon_json_value_from_string(value))
      None => ()
    }
  }
  match body {
    Some(Object(obj)) =>
      for key in keys {
        match obj.get(key) {
          Some(value) => return Some(value)
          None => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn moon_json_value_from_string(value : String) -> Json {
  try @json.parse(value) catch {
    _ => Json::string(value)
  } noraise {
    parsed => parsed
  }
}

///|
fn moon_mcp_apps_json(app : String, enabled? : Bool = true) -> Json {
  let apps = {
    "claude": Json::boolean(false),
    "claude-desktop": Json::boolean(false),
    "codex": Json::boolean(false),
    "gemini": Json::boolean(false),
    "opencode": Json::boolean(false),
    "openclaw": Json::boolean(false),
    "hermes": Json::boolean(false),
  }
  apps[moon_normalize_app_type(app)] = Json::boolean(enabled)
  Json::object(apps)
}

///|
fn moon_mcp_app_enabled(server : Json, app : String) -> Bool {
  guard server is Object(obj) else { return false }
  guard obj.get("apps") is Some(Object(apps)) else { return false }
  match apps.get(moon_normalize_app_type(app)) {
    Some(true) => true
    Some(false) => false
    _ => false
  }
}

///|
fn moon_mcp_server_with_app(
  server : Json,
  app : String,
  enabled : Bool,
) -> Json {
  let normalized = moon_normalize_app_type(app)
  match server {
    Object(obj) => {
      let next = obj
      let apps = match obj.get("apps") {
        Some(Object(existing)) => existing
        _ =>
          match moon_mcp_apps_json("claude", enabled=false) {
            Object(empty) => empty
            _ => {}
          }
      }
      apps[normalized] = Json::boolean(enabled)
      next["apps"] = Json::object(apps)
      Json::object(next)
    }
    _ => server
  }
}

///|
fn moon_mcp_server_from_request(
  path : StringView,
  body : Json?,
  default_app : String,
) -> (String, Json)? {
  match moon_json_request(path, body, ["server"]) {
    Some(Object(server)) =>
      match json_string_from_map_any(server, ["id", "serverId", "server_id"]) {
        Some(id) =>
          return Some(
            (
              id,
              moon_mcp_normalize_server(id, Json::object(server), default_app),
            ),
          )
        None => ()
      }
    _ => ()
  }
  guard proxy_string_request(path, body, ["id", "serverId", "server_id"])
    is Some(id) else {
    return None
  }
  let spec = moon_json_request(path, body, ["spec", "server"]).unwrap_or(
    Json::object({}),
  )
  Some((id, moon_mcp_server_from_spec(id, spec, default_app)))
}

///|
fn moon_mcp_server_from_spec(id : String, spec : Json, app : String) -> Json {
  let name = match spec {
    Object(obj) => json_string_from_map_any(obj, ["name"]).unwrap_or(id)
    _ => id
  }
  Json::object({
    "id": Json::string(id),
    "name": Json::string(name),
    "server": spec,
    "apps": moon_mcp_apps_json(app),
    "description": Json::null(),
    "homepage": Json::null(),
    "docs": Json::null(),
    "tags": Json::array([]),
  })
}

///|
fn moon_mcp_normalize_server(
  id : String,
  server : Json,
  default_app : String,
) -> Json {
  match server {
    Object(obj) => {
      let next = obj
      if next.get("id") is None {
        next["id"] = Json::string(id)
      }
      if next.get("name") is None {
        next["name"] = Json::string(id)
      }
      if next.get("server") is None {
        next["server"] = Json::object({})
      }
      if next.get("apps") is None {
        next["apps"] = moon_mcp_apps_json(default_app)
      }
      if next.get("tags") is None {
        next["tags"] = Json::array([])
      }
      Json::object(next)
    }
    _ => moon_mcp_server_from_spec(id, Json::object({}), default_app)
  }
}

///|
fn moon_mcp_servers_object_for_app(
  servers : Map[String, Json],
  app : String?,
) -> Json {
  let result : Map[String, Json] = {}
  for id in servers.keys() {
    guard servers.get(id) is Some(server) else { continue }
    match app {
      Some(app_type) =>
        if moon_mcp_app_enabled(server, app_type) {
          result[id] = server
        }
      None => result[id] = server
    }
  }
  Json::object(result)
}

///|
fn moon_mcp_valid_server_spec(spec : Json) -> Bool {
  guard spec is Object(obj) else { return false }
  let typ = json_string_from_map_any(obj, ["type"]).unwrap_or("stdio")
  match typ {
    "stdio" =>
      json_string_from_map_any(obj, ["command"]).unwrap_or("").trim() != ""
    "http" | "sse" =>
      json_string_from_map_any(obj, ["url"]).unwrap_or("").trim() != ""
    _ => false
  }
}

///|
fn moon_mcp_import_spec_for_app(app : String, spec : Json) -> Json {
  let normalized = moon_normalize_app_type(app)
  if normalized != "gemini" {
    return spec
  }
  match spec {
    Object(obj) => {
      let next = obj
      match next.get("httpUrl") {
        Some(http_url) => {
          next.remove("httpUrl")
          next["url"] = http_url
          next["type"] = Json::string("http")
        }
        None => ()
      }
      if next.get("type") is None {
        if next.get("command") is Some(_) {
          next["type"] = Json::string("stdio")
        } else if next.get("url") is Some(_) {
          next["type"] = Json::string("sse")
        }
      }
      Json::object(next)
    }
    _ => spec
  }
}

///|
fn moon_import_mcp_servers_map(
  servers : Map[String, Json],
  app : String,
  mcp_servers : Map[String, Json],
) -> Int {
  let mut changed = 0
  for id in mcp_servers.keys() {
    guard mcp_servers.get(id) is Some(spec) else { continue }
    let import_spec = moon_mcp_import_spec_for_app(app, spec)
    if !moon_mcp_valid_server_spec(import_spec) {
      continue
    }
    match servers.get(id) {
      Some(existing) =>
        if !moon_mcp_app_enabled(existing, app) {
          servers[id] = moon_mcp_server_with_app(existing, app, true)
          changed += 1
        }
      None => {
        servers[id] = moon_mcp_server_from_spec(id, import_spec, app)
        changed += 1
      }
    }
  }
  changed
}

///|
fn moon_import_mcp_from_root_json(
  servers : Map[String, Json],
  app : String,
  root : Json,
) -> Int {
  guard root is Object(obj) else { return 0 }
  guard obj.get("mcpServers") is Some(Object(mcp_servers)) else { return 0 }
  moon_import_mcp_servers_map(servers, app, mcp_servers)
}

///|
fn moon_import_mcp_from_codex_toml_text(
  servers : Map[String, Json],
  content : String,
) -> Int {
  let raw_specs : Map[String, Json] = {}
  let mut current_id : String? = None
  let mut current_table = ""
  for line_view in content.split("\n") {
    let line = moon_toml_strip_comment(line_view.to_owned()).trim().to_owned()
    if line.is_empty() {
      continue
    }
    if line.has_prefix("[") && line.has_suffix("]") {
      let section = line[1:line.length() - 1].trim().to_owned()
      match moon_codex_mcp_section(section) {
        Some((id, table)) => {
          current_id = Some(id)
          current_table = table
          if raw_specs.get(id) is None {
            raw_specs[id] = Json::object({})
          }
        }
        None => {
          current_id = None
          current_table = ""
        }
      }
      continue
    }
    guard current_id is Some(id) else { continue }
    guard moon_toml_assignment(line) is Some((key, raw_value)) else { continue }
    let spec = moon_codex_raw_mcp_spec(raw_specs, id)
    if current_table.is_empty() {
      match moon_toml_value(raw_value) {
        Some(value) => spec[key] = value
        None => ()
      }
    } else {
      let nested_key = if current_table == "http_headers" {
        "headers"
      } else {
        current_table
      }
      let nested = match spec.get(nested_key) {
        Some(Object(obj)) => obj
        _ => {
          let obj : Map[String, Json] = {}
          spec[nested_key] = Json::object(obj)
          obj
        }
      }
      match moon_toml_value(raw_value) {
        Some(String(value)) => nested[key] = Json::string(value)
        _ => ()
      }
    }
    raw_specs[id] = Json::object(spec)
  }
  let normalized : Map[String, Json] = {}
  for id in raw_specs.keys() {
    guard raw_specs.get(id) is Some(raw_spec) else { continue }
    normalized[id] = moon_codex_mcp_unified_spec(raw_spec)
  }
  moon_import_mcp_servers_map(servers, "codex", normalized)
}

///|
fn moon_codex_raw_mcp_spec(
  specs : Map[String, Json],
  id : String,
) -> Map[String, Json] {
  match specs.get(id) {
    Some(Object(obj)) => obj
    _ => {
      let obj : Map[String, Json] = {}
      specs[id] = Json::object(obj)
      obj
    }
  }
}

///|
fn moon_codex_mcp_section(section : String) -> (String, String)? {
  let rest = if section.has_prefix("mcp_servers.") {
    section["mcp_servers.".length():].to_owned()
  } else if section.has_prefix("mcp.servers.") {
    section["mcp.servers.".length():].to_owned()
  } else {
    return None
  }
  let parts = rest.split(".").collect()
  if parts.length() == 0 {
    return None
  }
  let id = parts[0].trim().to_owned()
  if id.is_empty() {
    return None
  }
  let table = if parts.length() > 1 { parts[1].trim().to_owned() } else { "" }
  match table {
    "" | "env" | "http_headers" | "headers" => Some((id, table))
    _ => None
  }
}

///|
fn moon_codex_mcp_unified_spec(raw_spec : Json) -> Json {
  guard raw_spec is Object(raw) else { return Json::object({}) }
  let typ = json_string_from_map_any(raw, ["type"]).unwrap_or("stdio")
  let spec : Map[String, Json] = { "type": Json::string(typ) }
  match typ {
    "stdio" => {
      match raw.get("command") {
        Some(String(command)) => spec["command"] = Json::string(command)
        _ => ()
      }
      match raw.get("args") {
        Some(Array(args)) => spec["args"] = Json::array(args)
        _ => ()
      }
      match raw.get("cwd") {
        Some(String(cwd)) if !cwd.trim().is_empty() =>
          spec["cwd"] = Json::string(cwd)
        _ => ()
      }
      match raw.get("env") {
        Some(Object(env)) => spec["env"] = Json::object(env)
        _ => ()
      }
    }
    "http" | "sse" => {
      match raw.get("url") {
        Some(String(url)) => spec["url"] = Json::string(url)
        _ => ()
      }
      match raw.get("http_headers") {
        Some(Object(headers)) => spec["headers"] = Json::object(headers)
        _ =>
          match raw.get("headers") {
            Some(Object(headers)) => spec["headers"] = Json::object(headers)
            _ => ()
          }
      }
    }
    _ => ()
  }
  for key in raw.keys() {
    if moon_codex_mcp_core_field(typ, key) {
      continue
    }
    guard raw.get(key) is Some(value) else { continue }
    spec[key] = value
  }
  Json::object(spec)
}

///|
fn moon_codex_mcp_core_field(typ : String, key : String) -> Bool {
  match typ {
    "stdio" =>
      key == "type" ||
      key == "command" ||
      key == "args" ||
      key == "env" ||
      key == "cwd"
    "http" | "sse" =>
      key == "type" || key == "url" || key == "http_headers" || key == "headers"
    _ => key == "type"
  }
}

///|
fn moon_toml_strip_comment(line : String) -> String {
  let mut in_quote = false
  let mut quote = 0
  let mut escaped = false
  for i in 0..<line.length() {
    let ch = line[i]
    if in_quote {
      if escaped {
        escaped = false
      } else if ch == '\\' {
        escaped = true
      } else if ch.to_int() == quote {
        in_quote = false
      }
    } else if ch == '"' || ch == '\'' {
      in_quote = true
      quote = ch.to_int()
    } else if ch == '#' {
      return line[:i].to_owned()
    }
  }
  line
}

///|
fn moon_toml_assignment(line : String) -> (String, String)? {
  guard line.find("=") is Some(index) else { return None }
  let key = line[:index].trim().to_owned()
  let value = line[index + 1:].trim().to_owned()
  if key.is_empty() {
    None
  } else {
    Some((key, value))
  }
}

///|
fn moon_toml_value(raw : String) -> Json? {
  let value = raw.trim().to_owned()
  if value.is_empty() {
    return None
  }
  if value.has_prefix("[") && value.has_suffix("]") {
    let items : Array[Json] = []
    for item in moon_toml_split_csv(value[1:value.length() - 1].to_owned()) {
      match moon_toml_value(item) {
        Some(String(text)) => items.push(Json::string(text))
        Some(true) => items.push(Json::boolean(true))
        Some(false) => items.push(Json::boolean(false))
        Some(Number(number, ..)) => items.push(Json::number(number))
        _ => ()
      }
    }
    return Some(Json::array(items))
  }
  if value.has_prefix("{") && value.has_suffix("}") {
    let obj : Map[String, Json] = {}
    for item in moon_toml_split_csv(value[1:value.length() - 1].to_owned()) {
      match moon_toml_assignment(item) {
        Some((key, nested_raw)) =>
          match moon_toml_value(nested_raw) {
            Some(String(text)) => obj[key] = Json::string(text)
            _ => ()
          }
        None => ()
      }
    }
    return Some(Json::object(obj))
  }
  if (value.has_prefix("\"") && value.has_suffix("\"")) ||
    (value.has_prefix("'") && value.has_suffix("'")) {
    return Some(Json::string(value[1:value.length() - 1].to_owned()))
  }
  match value {
    "true" => Some(Json::boolean(true))
    "false" => Some(Json::boolean(false))
    _ =>
      try @string.parse_int(value, base=10) catch {
        _ => Some(Json::string(value))
      } noraise {
        parsed => Some(Json::number(parsed.to_double()))
      }
  }
}

///|
fn moon_toml_split_csv(text : String) -> Array[String] {
  let parts : Array[String] = []
  let mut start = 0
  let mut in_quote = false
  let mut quote = 0
  let mut escaped = false
  for i in 0..<text.length() {
    let ch = text[i]
    if in_quote {
      if escaped {
        escaped = false
      } else if ch == '\\' {
        escaped = true
      } else if ch.to_int() == quote {
        in_quote = false
      }
    } else if ch == '"' || ch == '\'' {
      in_quote = true
      quote = ch.to_int()
    } else if ch == ',' {
      let item = text[start:i].trim().to_owned()
      if !item.is_empty() {
        parts.push(item)
      }
      start = i + 1
    }
  }
  let tail = text[start:].trim().to_owned()
  if !tail.is_empty() {
    parts.push(tail)
  }
  parts
}

///|
fn moon_clean_blank_lines(lines : Array[String]) -> String {
  let cleaned : Array[String] = []
  let mut blank_run = 0
  for line in lines {
    if line.trim().is_empty() {
      blank_run += 1
      if blank_run <= 1 {
        cleaned.push("")
      }
    } else {
      blank_run = 0
      cleaned.push(line)
    }
  }
  cleaned.join("\n")
}

///|
async fn moon_import_mcp_from_apps_count(servers : Map[String, Json]) -> Int {
  let mut total = 0
  total += moon_import_mcp_from_file(
    servers,
    "claude",
    @pathx.join(moon_home_dir(), ".claude.json"),
  )
  total += moon_import_mcp_from_codex_file(
    servers,
    moon_config_file_path("codex"),
  )
  total += moon_import_mcp_from_file(
    servers,
    "gemini",
    @pathx.join(moon_config_dir("gemini"), "settings.json"),
  )
  total
}

///|
fn moon_validate_mcp_command_name(command : String) -> Bool {
  let trimmed = command.trim()
  !trimmed.is_empty() &&
  !trimmed.contains("/") &&
  !trimmed.contains("\\") &&
  !trimmed.contains("\u{0000}")
}

///|
fn moon_prompt_store_key(app : String, id : String) -> String {
  "\{moon_normalize_app_type(app)}:\{id}"
}

///|
fn moon_prompt_from_request(
  path : StringView,
  body : Json?,
) -> (String, String, Json)? {
  let app = moon_config_app_from_request(path, body).unwrap_or("claude")
  match moon_json_request(path, body, ["prompt"]) {
    Some(Object(prompt)) =>
      match json_string_from_map_any(prompt, ["id"]) {
        Some(id) =>
          return Some(
            (app, id, moon_normalize_prompt(id, Json::object(prompt))),
          )
        None => ()
      }
    _ => ()
  }
  guard proxy_string_request(path, body, ["id", "promptId", "prompt_id"])
    is Some(id) else {
    return None
  }
  let name = proxy_string_request(path, body, ["name"]).unwrap_or(id)
  let content = proxy_string_request(path, body, ["content"]).unwrap_or("")
  let description = proxy_string_request(path, body, ["description"])
  let enabled = proxy_bool_request(path, body, ["enabled"]).unwrap_or(true)
  let now = Json::string(@async.now().to_string())
  let prompt : Map[String, Json] = {
    "id": Json::string(id),
    "name": Json::string(name),
    "content": Json::string(content),
    "enabled": Json::boolean(enabled),
    "createdAt": now,
    "updatedAt": now,
  }
  match description {
    Some(value) => prompt["description"] = Json::string(value)
    None => ()
  }
  Some((app, id, Json::object(prompt)))
}

///|
async fn moon_enable_prompt_json(
  prompts : Map[String, Json],
  app : String,
  id : String,
  file_path : String,
) -> Result[Json, String] {
  let normalized = moon_normalize_app_type(app)
  let prefix = "\{normalized}:"
  let mut selected_content = ""
  let mut found = false
  for key in prompts.keys() {
    if !key.has_prefix(prefix) {
      continue
    }
    guard prompts.get(key) is Some(Object(prompt)) else { continue }
    guard json_string_from_map_any(prompt, ["id"]) is Some(prompt_id) else {
      continue
    }
    if prompt_id == id {
      selected_content = json_string_from_map_any(prompt, ["content"]).unwrap_or(
        "",
      )
      found = true
      break
    }
  }
  if !found {
    return Err("提示词 \{id} 不存在")
  }
  @fsx.make_directory(@pathx.dirname(file_path), recursive=true, exists_ok=true) catch {
    error => return Err("创建提示词目录失败: \{error}")
  }
  @fsx.write_to_file(file_path, selected_content) catch {
    error => return Err("写入提示词文件失败: \{error}")
  }
  let now = Json::string(@async.now().to_string())
  for key in prompts.keys() {
    if !key.has_prefix(prefix) {
      continue
    }
    guard prompts.get(key) is Some(Object(prompt)) else { continue }
    let next = prompt
    let enabled = match json_string_from_map_any(next, ["id"]) {
      Some(prompt_id) => prompt_id == id
      None => false
    }
    next["enabled"] = Json::boolean(enabled)
    if enabled {
      next["updatedAt"] = now
    }
    prompts[key] = Json::object(next)
  }
  Ok(Json::null())
}

///|
fn moon_normalize_prompt(id : String, prompt : Json) -> Json {
  match prompt {
    Object(obj) => {
      let next = obj
      if next.get("id") is None {
        next["id"] = Json::string(id)
      }
      if next.get("name") is None {
        next["name"] = Json::string(id)
      }
      if next.get("content") is None {
        next["content"] = Json::string("")
      }
      if next.get("enabled") is None {
        next["enabled"] = Json::boolean(true)
      }
      let now = Json::string(@async.now().to_string())
      if next.get("createdAt") is None {
        next["createdAt"] = now
      }
      next["updatedAt"] = now
      Json::object(next)
    }
    _ => Json::object({})
  }
}

///|
fn moon_prompts_object_for_app(
  prompts : Map[String, Json],
  app : String,
) -> Json {
  let normalized = moon_normalize_app_type(app)
  let prefix = "\{normalized}:"
  let result : Map[String, Json] = {}
  for key in prompts.keys() {
    if key.has_prefix(prefix) {
      guard prompts.get(key) is Some(Object(prompt)) else { continue }
      match json_string_from_map_any(prompt, ["id"]) {
        Some(id) => result[id] = Json::object(prompt)
        None => ()
      }
    }
  }
  Json::object(result)
}

///|
fn gemini_request_is_stream(endpoint : String, body : Json) -> Bool {
  moon_streaming_request(endpoint, body, {})
}

///|
fn moon_streaming_request(
  endpoint : String,
  body : Json,
  headers : Map[String, String],
) -> Bool {
  if json_bool_field(body, "stream").unwrap_or(false) {
    return true
  }
  if endpoint.contains("streamGenerateContent") || endpoint.contains("alt=sse") {
    return true
  }
  match headers.get("accept") {
    Some(accept) => accept.contains("text/event-stream")
    None => false
  }
}

///|
async fn RuntimeService::handle_pick_directory(
  self : RuntimeService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    match proxy_string_request(r.path, body, ["default_path", "defaultPath"]) {
      Some(path) => Json::string(path)
      None => Json::null()
    },
  )
}

///|
async fn ProxyService::handle_open_external(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let raw_url = proxy_string_request(r.path, body, ["url"]).unwrap_or(
    moon_update_url(),
  )
  ignore(self.record_external_open(raw_url))
  write_usage_json(w, Json::boolean(true))
}

///|
fn ProxyService::record_external_open(
  self : ProxyService,
  raw_url : String,
) -> String {
  let normalized = moon_normalize_external_url(raw_url)
  self.last_external_url = Some(normalized)
  normalized
}

///|
async fn RuntimeService::handle_copy_text_to_clipboard(
  self : RuntimeService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  ignore(proxy_string_request(r.path, body, ["text"]).unwrap_or(""))
  write_usage_json(w, Json::boolean(true))
}

///|
async fn ProxyService::handle_check_for_updates(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self.record_external_open(moon_update_url()))
  write_usage_json(w, Json::boolean(true))
}

///|
async fn RuntimeService::handle_update_tray_menu(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_update_tray_menu_result())
}

///|
async fn RuntimeService::handle_is_portable_mode(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::boolean(moon_portable_mode()))
}

///|
async fn RuntimeService::handle_get_init_error(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_init_error_json())
}

///|
async fn RuntimeService::handle_get_migration_result(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_migration_result_json())
}

///|
async fn RuntimeService::handle_get_skills_migration_result(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_skills_migration_result_json())
}

///|
async fn RuntimeService::handle_get_tool_versions(
  self : RuntimeService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let tools = proxy_string_request(r.path, body, ["tools"])
  write_usage_json(w, moon_get_tool_versions_json(tools))
}

///|
async fn RuntimeService::handle_run_tool_lifecycle_action(
  self : RuntimeService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let tools = match body {
    Some(Object(obj)) => moon_requested_tool_names_from_json(obj.get("tools"))
    _ =>
      moon_requested_tool_names(proxy_string_request(r.path, body, ["tools"]))
  }
  guard proxy_string_request(r.path, body, ["action"]) is Some(action) else {
    write_usage_bad_request(w, "missing_action")
    return
  }
  match moon_run_tool_lifecycle_action_json(tools, action) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn RuntimeService::handle_probe_tool_installations(
  self : RuntimeService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let tools = match body {
    Some(Object(obj)) => moon_requested_tool_names_from_json(obj.get("tools"))
    _ =>
      moon_requested_tool_names(proxy_string_request(r.path, body, ["tools"]))
  }
  match moon_probe_tool_installations_json(tools) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn ConfigService::handle_set_window_theme(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  self.window_theme = proxy_string_request(r.path, body, ["theme"]).unwrap_or(
    "system",
  )
  write_usage_json(w, Json::null())
}

///|
async fn ConfigService::handle_enter_lightweight_mode(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.lightweight_mode = true
  write_usage_json(w, Json::null())
}

///|
async fn ConfigService::handle_exit_lightweight_mode(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.lightweight_mode = false
  write_usage_json(w, Json::null())
}

///|
async fn ConfigService::handle_is_lightweight_mode(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, Json::boolean(self.lightweight_mode))
}

///|
async fn ConfigService::handle_webdav_test_connection(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard moon_sync_settings_request(r.path, body) is Some(settings) else {
    write_usage_bad_request(w, "missing_settings")
    return
  }
  let normalized = moon_webdav_sync_settings_json(
    settings,
    moon_app_webdav_sync_json(self.app_settings),
    moon_sync_preserve_empty_password_request(r.path, body),
  )
  match moon_validate_webdav_sync_settings(normalized) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match moon_webdav_sync_test_connection_json(normalized) {
        Ok(result) => write_usage_json(w, result)
        Err(error) => write_usage_bad_request(w, error)
      }
  }
}

///|
async fn ConfigService::handle_webdav_sync_operation(
  self : ConfigService,
  proxy : ProxyService,
  host~ : String,
  port~ : Int,
  w : @httpx.ResponseWriter,
  operation : String,
) -> Unit {
  match moon_webdav_sync_required_error(self.app_settings) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match moon_app_webdav_sync_json(self.app_settings) {
        None => write_usage_bad_request(w, "WebDAV sync is not configured.")
        Some(settings) => {
          let result = match operation {
            "upload" =>
              self.moon_webdav_sync_upload_json(proxy, host~, port~, settings)
            "download" => self.moon_webdav_sync_download_json(proxy, settings)
            _ => Err("Unsupported WebDAV sync operation: \{operation}")
          }
          match result {
            Ok(json) => write_usage_json(w, json)
            Err(error) => write_usage_bad_request(w, error)
          }
        }
      }
  }
}

///|
async fn ConfigService::handle_webdav_sync_fetch_remote_info(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  match moon_webdav_sync_required_error(self.app_settings) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match moon_app_webdav_sync_json(self.app_settings) {
        None => write_usage_bad_request(w, "WebDAV sync is not configured.")
        Some(settings) =>
          match moon_webdav_sync_fetch_remote_info_json(settings) {
            Ok(info) => write_usage_json(w, info)
            Err(error) => write_usage_bad_request(w, error)
          }
      }
  }
}

///|
async fn ConfigService::handle_s3_test_connection(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard moon_sync_settings_request(r.path, body) is Some(settings) else {
    write_usage_bad_request(w, "missing_settings")
    return
  }
  let normalized = moon_s3_sync_settings_json(
    settings,
    moon_app_s3_sync_json(self.app_settings),
    moon_sync_preserve_empty_password_request(r.path, body),
  )
  match moon_validate_s3_sync_settings(normalized) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match moon_s3_sync_test_connection_json(normalized) {
        Ok(result) => write_usage_json(w, result)
        Err(error) => write_usage_bad_request(w, error)
      }
  }
}

///|
async fn ConfigService::handle_s3_sync_operation(
  self : ConfigService,
  proxy : ProxyService,
  host~ : String,
  port~ : Int,
  w : @httpx.ResponseWriter,
  operation : String,
) -> Unit {
  match moon_s3_sync_required_error(self.app_settings) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match moon_app_s3_sync_json(self.app_settings) {
        None => write_usage_bad_request(w, "S3 sync is not configured.")
        Some(settings) => {
          let result = match operation {
            "upload" =>
              self.moon_s3_sync_upload_json(proxy, host~, port~, settings)
            "download" => self.moon_s3_sync_download_json(proxy, settings)
            _ => Err("Unsupported S3 sync operation: \{operation}")
          }
          match result {
            Ok(json) => write_usage_json(w, json)
            Err(error) => write_usage_bad_request(w, error)
          }
        }
      }
  }
}

///|
async fn ConfigService::handle_s3_sync_fetch_remote_info(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  match moon_s3_sync_required_error(self.app_settings) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match moon_app_s3_sync_json(self.app_settings) {
        None => write_usage_bad_request(w, "S3 sync is not configured.")
        Some(settings) =>
          match moon_s3_sync_fetch_remote_info_json(settings) {
            Ok(info) => write_usage_json(w, info)
            Err(error) => write_usage_bad_request(w, error)
          }
      }
  }
}

///|
async fn ProxyService::handle_disable_current_omo(
  self : ProxyService,
  w : @httpx.ResponseWriter,
  slim~ : Bool,
) -> Unit {
  self.clear_current_omo_provider(slim)
  match moon_delete_omo_config_files(slim) {
    Some(error) => write_usage_bad_request(w, error)
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn SkillService::handle_get_installed_skills(
  self : SkillService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_get_installed_skills_json())
}

///|
async fn SkillService::handle_install_skill_unified(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let skill = match moon_skill_request_payload(body) {
    Some(skill) => Some(skill)
    None =>
      match proxy_string_request(r.path, body, ["directory", "id", "key"]) {
        Some(directory) => {
          let install_name = moon_skill_install_name(directory)
          if install_name.is_empty() {
            None
          } else {
            Some(
              {
                "key": Json::string("local:\{install_name}"),
                "name": Json::string(
                  proxy_string_request(r.path, body, ["name"]).unwrap_or(
                    install_name,
                  ),
                ),
                "description": Json::string(
                  proxy_string_request(r.path, body, ["description"]).unwrap_or(
                    "",
                  ),
                ),
                "directory": Json::string(install_name),
              }.to_json(),
            )
          }
        }
        None => None
      }
  }
  guard skill is Some(skill) else {
    write_usage_bad_request(w, "missing_skill")
    return
  }
  let current_app = proxy_string_request(r.path, body, [
    "currentApp", "current_app", "app",
  ]).unwrap_or("claude")
  write_usage_json(w, moon_install_skill_unified_json(skill, current_app))
}

///|
async fn SkillService::handle_uninstall_skill_unified(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["id", "directory"]) is Some(id) else {
    write_usage_bad_request(w, "missing_skill_id")
    return
  }
  write_usage_json(w, moon_uninstall_skill_unified_json(id))
}

///|
async fn SkillService::handle_toggle_skill_app(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["id", "directory"]) is Some(id) else {
    write_usage_bad_request(w, "missing_skill_id")
    return
  }
  guard proxy_string_request(r.path, body, ["app", "appType", "app_type"])
    is Some(app) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard proxy_bool_request(r.path, body, ["enabled"]) is Some(enabled) else {
    write_usage_bad_request(w, "missing_enabled")
    return
  }
  write_usage_json(w, moon_toggle_skill_app_json(id, app, enabled))
}

///|
async fn SkillService::handle_scan_unmanaged_skills(
  self : SkillService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_scan_unmanaged_skills_json())
}

///|
async fn SkillService::handle_import_skills_from_apps(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let imports = match body {
    Some(Object(obj)) =>
      match obj.get("imports") {
        Some(Array(items)) => Json::array(items)
        _ => Json::array([])
      }
    Some(Array(items)) => Json::array(items)
    _ => Json::array([])
  }
  write_usage_json(w, moon_import_skills_from_apps_json(imports))
}

///|
async fn SkillService::handle_discover_available_skills(
  self : SkillService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_discover_available_skills_json())
}

///|
async fn SkillService::handle_check_skill_updates(
  self : SkillService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_check_skill_updates_json())
}

///|
async fn SkillService::handle_update_skill(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["id", "directory"]) is Some(id) else {
    write_usage_bad_request(w, "missing_skill_id")
    return
  }
  write_usage_json(w, moon_update_skill_json(id))
}

///|
async fn SkillService::handle_migrate_skill_storage(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["target"]) is Some(target) else {
    write_usage_bad_request(w, "missing_storage_target")
    return
  }
  write_usage_json(w, moon_migrate_skill_storage_json(target))
}

///|
async fn SkillService::handle_search_skills_sh(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let query = proxy_string_request(r.path, body, ["query", "q"]).unwrap_or("")
  let limit = proxy_int_request(r.path, body, ["limit"]).unwrap_or(20)
  let offset = proxy_int_request(r.path, body, ["offset"]).unwrap_or(0)
  write_usage_json(w, moon_search_skills_sh_json(query, limit, offset))
}

///|
async fn SkillService::handle_get_skills(
  self : SkillService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_get_skills_json())
}

///|
async fn SkillService::handle_get_skill_repos(
  self : SkillService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_get_skill_repos_json())
}

///|
async fn SkillService::handle_add_skill_repo(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let repo = match body {
    Some(Object(obj)) =>
      match obj.get("repo") {
        Some(Object(repo_obj)) => Json::object(repo_obj)
        _ =>
          if obj.get("owner") is Some(_) && obj.get("name") is Some(_) {
            Json::object(obj)
          } else {
            match moon_skill_repo_request_json(r.path, body) {
              Some(repo) => repo
              None => {
                write_usage_bad_request(w, "missing_owner_or_name")
                return
              }
            }
          }
      }
    _ =>
      match moon_skill_repo_request_json(r.path, body) {
        Some(repo) => repo
        None => {
          write_usage_bad_request(w, "missing_owner_or_name")
          return
        }
      }
  }
  write_usage_json(w, moon_add_skill_repo_json(repo))
}

///|
fn moon_skill_repo_request_json(path : StringView, body : Json?) -> Json? {
  guard proxy_string_request(path, body, ["owner"]) is Some(owner) else {
    return None
  }
  guard proxy_string_request(path, body, ["name", "repo"]) is Some(name) else {
    return None
  }
  Some(
    {
      "owner": Json::string(owner),
      "name": Json::string(name),
      "branch": Json::string(
        proxy_string_request(path, body, ["branch"]).unwrap_or("main"),
      ),
      "enabled": Json::boolean(
        proxy_bool_request(path, body, ["enabled"]).unwrap_or(true),
      ),
    }.to_json(),
  )
}

///|
async fn SkillService::handle_remove_skill_repo(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["owner"]) is Some(owner) else {
    write_usage_bad_request(w, "missing_owner")
    return
  }
  guard proxy_string_request(r.path, body, ["name", "repo"]) is Some(name) else {
    write_usage_bad_request(w, "missing_name")
    return
  }
  write_usage_json(w, moon_remove_skill_repo_json(owner, name))
}

///|
async fn SkillService::handle_install_skills_from_zip(
  self : SkillService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["filePath", "file_path", "path"])
    is Some(file_path) else {
    write_usage_bad_request(w, "missing_file_path")
    return
  }
  let current_app = proxy_string_request(r.path, body, [
    "currentApp", "current_app", "app",
  ]).unwrap_or("claude")
  write_usage_json(w, moon_install_skills_from_zip_json(file_path, current_app))
}

///|
async fn RuntimeService::handle_restart_app(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::boolean(true))
}

///|
async fn RuntimeService::handle_install_update_and_restart(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::boolean(false))
}

///|
async fn ConfigService::handle_set_auto_launch(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_bool_request(r.path, body, ["enabled"]) is Some(enabled) else {
    write_usage_bad_request(w, "invalid_auto_launch")
    return
  }
  self.auto_launch_enabled = enabled
  self.app_settings = moon_settings_with_bool(
    self.app_settings,
    "launchOnStartup",
    enabled,
  )
  write_usage_json(w, Json::boolean(true))
}

///|
async fn ConfigService::handle_get_auto_launch_status(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, Json::boolean(self.auto_launch_enabled))
}

///|
async fn ConfigService::handle_check_env_conflicts(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  write_usage_json(w, moon_env_conflicts_json(app))
}

///|
async fn ConfigService::handle_delete_env_vars(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  match moon_delete_env_vars_json(body) {
    Ok(backup) => write_usage_json(w, backup)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn ConfigService::handle_get_claude_mcp_status(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    {
      "userConfigPath": Json::string(
        @pathx.join(moon_home_dir(), ".claude.json"),
      ),
      "userConfigExists": Json::boolean(
        @fsx.exists_as_file(@pathx.join(moon_home_dir(), ".claude.json")),
      ),
      "serverCount": Json::number(self.mcp_servers.length().to_double()),
    }.to_json(),
  )
}

///|
async fn ConfigService::handle_upsert_claude_mcp_server(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  match moon_mcp_server_from_request(r.path, body, "claude") {
    Some((id, server)) => {
      self.mcp_servers[id] = moon_mcp_server_with_app(server, "claude", true)
      write_usage_json(w, Json::boolean(true))
    }
    None => write_usage_json(w, Json::boolean(false))
  }
}

///|
async fn ConfigService::handle_delete_mcp_server(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  match proxy_string_request(r.path, body, ["id", "serverId", "server_id"]) {
    Some(id) => {
      let existed = self.mcp_servers.get(id) is Some(_)
      self.mcp_servers.remove(id)
      write_usage_json(w, Json::boolean(existed))
    }
    None => write_usage_json(w, Json::boolean(false))
  }
}

///|
async fn ConfigService::handle_validate_mcp_command(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let command = proxy_string_request(r.path, body, ["cmd", "command"]).unwrap_or(
    "",
  )
  write_usage_json(w, Json::boolean(moon_validate_mcp_command_name(command)))
}

///|
async fn ConfigService::handle_set_mcp_enabled(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  let enabled = proxy_bool_request(r.path, body, ["enabled"]).unwrap_or(true)
  match proxy_string_request(r.path, body, ["id", "serverId", "server_id"]) {
    Some(id) =>
      match self.mcp_servers.get(id) {
        Some(server) => {
          self.mcp_servers[id] = moon_mcp_server_with_app(server, app, enabled)
          write_usage_json(w, Json::boolean(true))
        }
        None => write_usage_json(w, Json::boolean(false))
      }
    None => write_usage_json(w, Json::boolean(false))
  }
}

///|
async fn ConfigService::handle_get_mcp_servers(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, moon_mcp_servers_object_for_app(self.mcp_servers, None))
}

///|
async fn ConfigService::handle_upsert_mcp_server(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  match moon_mcp_server_from_request(r.path, body, "claude") {
    Some((id, server)) => {
      self.mcp_servers[id] = server
      write_usage_json(w, Json::null())
    }
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn ConfigService::handle_toggle_mcp_app(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  let enabled = proxy_bool_request(r.path, body, ["enabled"]).unwrap_or(true)
  match proxy_string_request(r.path, body, ["serverId", "server_id", "id"]) {
    Some(id) =>
      match self.mcp_servers.get(id) {
        Some(server) => {
          self.mcp_servers[id] = moon_mcp_server_with_app(server, app, enabled)
          write_usage_json(w, Json::null())
        }
        None => write_usage_json(w, Json::null())
      }
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn ConfigService::handle_import_mcp_from_apps(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  let imported = moon_import_mcp_from_apps_count(self.mcp_servers)
  write_usage_json(w, Json::number(imported.to_double()))
}

///|
async fn ConfigService::handle_get_prompts(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  write_usage_json(w, moon_prompts_object_for_app(self.prompts, app))
}

///|
async fn ConfigService::handle_upsert_prompt(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  match moon_prompt_from_request(r.path, body) {
    Some((app, id, prompt)) =>
      self.prompts[moon_prompt_store_key(app, id)] = prompt
    None => ()
  }
  write_usage_json(w, Json::null())
}

///|
async fn ConfigService::handle_delete_prompt(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  match proxy_string_request(r.path, body, ["id", "promptId", "prompt_id"]) {
    Some(id) => self.prompts.remove(moon_prompt_store_key(app, id))
    None => ()
  }
  write_usage_json(w, Json::null())
}

///|
async fn ConfigService::handle_enable_prompt(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  match proxy_string_request(r.path, body, ["id", "promptId", "prompt_id"]) {
    Some(id) =>
      match moon_prompt_file_path_from_request(r.path, body, app) {
        Ok(file_path) =>
          match moon_enable_prompt_json(self.prompts, app, id, file_path) {
            Ok(result) => write_usage_json(w, result)
            Err(error) => write_usage_bad_request(w, error)
          }
        Err(error) => write_usage_bad_request(w, error)
      }
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn ProxyService::handle_scan_local_proxies(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_scan_local_proxies_json())
}

///|
fn moon_scan_local_proxies_json() -> Json {
  let found : Array[Json] = []
  for item in moon_local_proxy_ports() {
    let (port, primary_type, is_mixed) = item
    if @net.localhost_port_open(port, timeout_ms=100) {
      found.append(
        moon_detected_proxy_entries_json(port, primary_type, is_mixed),
      )
    }
  }
  Json::array(found)
}

///|
async fn ProxyService::handle_get_claude_desktop_status(
  self : ProxyService,
  host : String,
  port : Int,
  w : @httpx.ResponseWriter,
) -> Unit {
  let status = @claude_desktop.status()
  write_usage_json(w, self.claude_desktop_status_json(status, host, port))
}

///|
fn ProxyService::claude_desktop_status_json(
  self : ProxyService,
  status : @claude_desktop.ClaudeDesktopStatus,
  host : String,
  port : Int,
) -> Json {
  let provider = self.current_claude_desktop_provider()
  let mode = match provider {
    Some(provider) => provider.claude_desktop_mode_for_status()
    None => None
  }
  {
    "supported": Json::boolean(true),
    "configured": Json::boolean(status.configured),
    "appliedId": provider_route_optional_string_json(status.applied_id),
    "profilePath": Json::string(status.profile_path),
    "configLibraryPath": Json::string(status.config_library_path),
    "mode": provider_route_optional_string_json(mode),
    "expectedBaseUrl": provider_route_optional_string_json(
      self.claude_desktop_expected_base_url(mode, provider, host, port),
    ),
    "actualBaseUrl": provider_route_optional_string_json(status.actual_base_url),
    "proxyRunning": Json::boolean(true),
    "staleRawModels": Json::boolean(status.stale_raw_models),
    "missingRouteMappings": Json::boolean(
      claude_desktop_missing_route_mappings(mode, provider),
    ),
    "gatewayTokenConfigured": Json::boolean(status.token_configured),
  }.to_json()
}

///|
fn ProviderRouteTarget::claude_desktop_mode_for_status(
  self : ProviderRouteTarget,
) -> String? {
  match self.claude_desktop_mode {
    Some(mode) => normalize_claude_desktop_mode(mode)
    None =>
      if self.app_type == "claude-desktop" {
        if self.claude_desktop_model_routes.is_empty() {
          Some("direct")
        } else {
          Some("proxy")
        }
      } else {
        None
      }
  }
}

///|
fn ProxyService::claude_desktop_expected_base_url(
  self : ProxyService,
  mode : String?,
  provider : ProviderRouteTarget?,
  host : String,
  port : Int,
) -> String? {
  ignore(self)
  match mode {
    Some("proxy") => Some(@claude_desktop.local_gateway_base_url(host, port))
    Some("direct") =>
      match provider {
        Some(provider) => provider.claude_desktop_direct_base_url()
        None => None
      }
    _ => None
  }
}

///|
fn ProviderRouteTarget::claude_desktop_direct_base_url(
  self : ProviderRouteTarget,
) -> String? {
  match self.settings_config {
    Some(Object(obj)) =>
      match obj.get("env") {
        Some(Object(env)) =>
          json_non_empty_string_from_map_any(env, ["ANTHROPIC_BASE_URL"])
        _ => None
      }
    _ => None
  }
}

///|
fn claude_desktop_missing_route_mappings(
  mode : String?,
  provider : ProviderRouteTarget?,
) -> Bool {
  guard mode == Some("proxy") else { return false }
  match provider {
    Some(provider) => provider.resolved_claude_desktop_model_routes().is_empty()
    None => true
  }
}

///|
async fn ProxyService::handle_get_claude_desktop_default_routes(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, claude_desktop_default_routes_json())
}

///|
fn claude_desktop_default_routes_json() -> Json {
  Json::array([
    claude_desktop_default_route_json(
      "claude-sonnet-4-6", "ANTHROPIC_DEFAULT_SONNET_MODEL",
    ),
    claude_desktop_default_route_json(
      "claude-opus-4-8", "ANTHROPIC_DEFAULT_OPUS_MODEL",
    ),
    claude_desktop_default_route_json(
      "claude-haiku-4-5", "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    ),
  ])
}

///|
fn claude_desktop_default_route_json(
  route_id : String,
  env_key : String,
) -> Json {
  {
    "routeId": Json::string(route_id),
    "envKey": Json::string(env_key),
    "supports1m": Json::boolean(true),
  }.to_json()
}

///|
fn ProviderRouteTarget::is_compatible_claude_desktop_direct_provider(
  self : ProviderRouteTarget,
) -> Bool {
  match self.api_format {
    Some(api_format) if !api_format.trim().is_empty() &&
      api_format.trim() != "anthropic" => return false
    _ => ()
  }
  match self.claude_desktop_mode {
    Some(mode) if normalize_claude_desktop_mode(mode) == Some("proxy") =>
      return false
    _ => ()
  }
  match self.provider_type {
    Some("official") | Some("github_copilot") | Some("codex_oauth") =>
      return false
    _ => ()
  }
  if self.is_full_url {
    return false
  }
  self.claude_desktop_direct_base_url() is Some(_) &&
  self.claude_desktop_direct_auth_token() is Some(_) &&
  self.claude_desktop_direct_routes_are_identity()
}

///|
fn ProviderRouteTarget::claude_desktop_direct_auth_token(
  self : ProviderRouteTarget,
) -> String? {
  match self.settings_config {
    Some(Object(obj)) =>
      match obj.get("env") {
        Some(Object(env)) =>
          json_non_empty_string_from_map_any(env, ["ANTHROPIC_AUTH_TOKEN"])
        _ => None
      }
    _ => None
  }
}

///|
fn ProviderRouteTarget::claude_desktop_direct_routes_are_identity(
  self : ProviderRouteTarget,
) -> Bool {
  for raw_route_id in self.claude_desktop_model_routes.keys() {
    let route_id = raw_route_id.trim().to_owned()
    if route_id.is_empty() {
      continue
    }
    if !is_claude_safe_model_id(route_id) {
      return false
    }
    match self.claude_desktop_model_routes.get(raw_route_id) {
      Some(route) => {
        let upstream = route.model.trim()
        if !upstream.is_empty() && upstream != route_id {
          return false
        }
      }
      None => ()
    }
  }
  true
}

///|
fn suggested_claude_desktop_routes(
  provider : ProviderRouteTarget,
) -> Map[String, ClaudeDesktopModelRoute]? {
  guard provider.settings_config is Some(Object(settings)) else { return None }
  guard settings.get("env") is Some(Object(env)) else { return None }
  let routes : Map[String, ClaudeDesktopModelRoute] = Map([], capacity=0)
  let supports_1m_default = match provider.provider_type {
    Some("github_copilot") | Some("codex_oauth") => false
    _ => true
  }
  add_suggested_claude_desktop_route(
    routes, env, "claude-sonnet-4-6", "ANTHROPIC_DEFAULT_SONNET_MODEL", supports_1m_default,
  )
  add_suggested_claude_desktop_route(
    routes, env, "claude-opus-4-8", "ANTHROPIC_DEFAULT_OPUS_MODEL", supports_1m_default,
  )
  add_suggested_claude_desktop_route(
    routes, env, "claude-haiku-4-5", "ANTHROPIC_DEFAULT_HAIKU_MODEL", supports_1m_default,
  )
  if routes.is_empty() {
    add_suggested_claude_desktop_route(
      routes, env, "claude-sonnet-4-6", "ANTHROPIC_MODEL", supports_1m_default,
    )
  }
  if routes.is_empty() {
    None
  } else {
    Some(routes)
  }
}

///|
fn add_suggested_claude_desktop_route(
  routes : Map[String, ClaudeDesktopModelRoute],
  env : Map[String, Json],
  route_key : String,
  env_key : String,
  supports_1m_default : Bool,
) -> Unit {
  guard json_string_from_map(env, env_key) is Some(raw_model) else { return }
  let raw_model = raw_model.trim().to_owned()
  if raw_model.is_empty() {
    return
  }
  let (stripped_model, has_1m_marker) = strip_claude_desktop_one_m_marker(
    raw_model,
  )
  if stripped_model.is_empty() {
    return
  }
  let effective_supports_1m = supports_1m_default || has_1m_marker
  let explicit_label_override = match
    json_string_from_map(env, "\{env_key}_NAME") {
    Some(label) => {
      let label = label.trim().to_owned()
      if label.is_empty() {
        None
      } else {
        Some(label)
      }
    }
    None => None
  }
  let label_override = match explicit_label_override {
    Some(label) => Some(label)
    None =>
      if is_claude_safe_model_id(stripped_model) {
        None
      } else {
        Some(stripped_model)
      }
  }
  match claude_desktop_route_key_for_upstream(routes, stripped_model) {
    Some(existing_key) => {
      guard routes.get(existing_key) is Some(existing) else { return }
      routes[existing_key] = merge_suggested_claude_desktop_route(
        existing, stripped_model, label_override, explicit_label_override, effective_supports_1m,
      )
    }
    None =>
      match routes.get(route_key) {
        Some(existing) =>
          routes[route_key] = merge_suggested_claude_desktop_route(
            existing, stripped_model, label_override, explicit_label_override, effective_supports_1m,
          )
        None =>
          routes[route_key] = ClaudeDesktopModelRoute::new(
            model=stripped_model,
            label_override~,
            supports_1m=Some(effective_supports_1m),
          )
      }
  }
}

///|
fn strip_claude_desktop_one_m_marker(model : String) -> (String, Bool) {
  let marker = "[1m]"
  if model.to_lower().has_suffix(marker) {
    (model[:model.length() - marker.length()].trim().to_owned(), true)
  } else {
    (model.trim().to_owned(), false)
  }
}

///|
fn claude_desktop_route_key_for_upstream(
  routes : Map[String, ClaudeDesktopModelRoute],
  model : String,
) -> String? {
  for route_key in routes.keys() {
    match routes.get(route_key) {
      Some(route) if route.model == model => return Some(route_key)
      _ => ()
    }
  }
  None
}

///|
fn merge_suggested_claude_desktop_route(
  existing : ClaudeDesktopModelRoute,
  stripped_model : String,
  label_override : String?,
  explicit_label_override : String?,
  effective_supports_1m : Bool,
) -> ClaudeDesktopModelRoute {
  let merged_supports_1m = existing.supports_1m.unwrap_or(false) ||
    effective_supports_1m
  let next_label = if existing.label_override is None ||
    explicit_label_override is Some(_) ||
    existing.label_override == Some(stripped_model) {
    label_override
  } else {
    existing.label_override
  }
  ClaudeDesktopModelRoute::new(
    model=existing.model,
    label_override=next_label,
    supports_1m=Some(merged_supports_1m),
  )
}

///|
async fn ConfigService::handle_get_claude_plugin_status(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    {
      "exists": Json::boolean(
        self.claude_plugin_config is Some(_) ||
        @fsx.exists_as_file(moon_claude_plugin_config_path()),
      ),
      "path": Json::string(moon_claude_plugin_config_path()),
    }.to_json(),
  )
}

///|
async fn ConfigService::handle_is_claude_plugin_applied(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.claude_plugin_config {
    Some(content) =>
      write_usage_json(w, Json::boolean(moon_json_primary_api_key_any(content)))
    None =>
      if @fsx.exists_as_file(moon_claude_plugin_config_path()) {
        let content = @fsx.read_file(moon_claude_plugin_config_path()) catch {
          _ => {
            write_usage_json(w, Json::boolean(false))
            return
          }
        }
        write_usage_json(
          w,
          Json::boolean(moon_json_primary_api_key_any(content)),
        )
      } else {
        write_usage_json(w, Json::boolean(self.claude_plugin_applied))
      }
  }
}

///|
async fn ConfigService::handle_apply_claude_onboarding_skip(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.claude_onboarding_skipped = true
  self.app_settings = moon_settings_with_bool(
    self.app_settings,
    "skipClaudeOnboarding",
    true,
  )
  write_usage_json(w, Json::boolean(true))
}

///|
async fn ConfigService::handle_clear_claude_onboarding_skip(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.claude_onboarding_skipped = false
  self.app_settings = moon_settings_with_bool(
    self.app_settings,
    "skipClaudeOnboarding",
    false,
  )
  write_usage_json(w, Json::boolean(true))
}

///|
async fn ProxyService::handle_test_api_endpoints(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let timeout_secs = provider_endpoint_sanitize_timeout_secs(
    proxy_int_request(r.path, body, ["timeoutSecs", "timeout_secs"]),
  )
  let urls = provider_endpoint_urls_from_request(r.path, body)
  write_usage_json(
    w,
    provider_endpoint_latency_results_json(urls, timeout_secs),
  )
}

///|
async fn ProxyService::handle_get_custom_endpoints(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard provider_id_from_request(r.path, body) is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  write_usage_json(
    w,
    self.provider_router.custom_endpoints_json(app_type, provider_id),
  )
}

///|
async fn ProxyService::handle_add_custom_endpoint(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard provider_id_from_request(r.path, body) is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard provider_url_from_request(r.path, body) is Some(url) else {
    write_usage_bad_request(w, "missing_url")
    return
  }
  if !self.provider_router.add_custom_endpoint(app_type, provider_id, url) {
    write_usage_bad_request(w, "invalid_url")
    return
  }
  write_usage_json(w, Json::null())
}

///|
async fn ProxyService::handle_remove_custom_endpoint(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard provider_id_from_request(r.path, body) is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard provider_url_from_request(r.path, body) is Some(url) else {
    write_usage_bad_request(w, "missing_url")
    return
  }
  self.provider_router.remove_custom_endpoint(app_type, provider_id, url)
  write_usage_json(w, Json::null())
}

///|
async fn ProxyService::handle_update_endpoint_last_used(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard provider_id_from_request(r.path, body) is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard provider_url_from_request(r.path, body) is Some(url) else {
    write_usage_bad_request(w, "missing_url")
    return
  }
  self.provider_router.update_endpoint_last_used(app_type, provider_id, url)
  write_usage_json(w, Json::null())
}

///|
struct StreamCheckConfig {
  timeout_secs : Int
  max_retries : Int
  degraded_threshold_ms : Int
  claude_model : String
  codex_model : String
  gemini_model : String
  test_prompt : String
}

///|
fn StreamCheckConfig::default() -> StreamCheckConfig {
  {
    timeout_secs: 45,
    max_retries: 2,
    degraded_threshold_ms: 6000,
    claude_model: "claude-haiku-4-5-20251001",
    codex_model: "gpt-5.5@low",
    gemini_model: "gemini-3.5-flash",
    test_prompt: "Who are you?",
  }
}

///|
fn StreamCheckConfig::to_json(self : StreamCheckConfig) -> Json {
  {
    "timeoutSecs": Json::number(self.timeout_secs.to_double()),
    "maxRetries": Json::number(self.max_retries.to_double()),
    "degradedThresholdMs": Json::number(self.degraded_threshold_ms.to_double()),
    "claudeModel": Json::string(self.claude_model),
    "codexModel": Json::string(self.codex_model),
    "geminiModel": Json::string(self.gemini_model),
    "testPrompt": Json::string(self.test_prompt),
  }.to_json()
}

///|
fn stream_check_int_request(
  path : StringView,
  obj : Map[String, Json]?,
  snake_key : String,
  camel_key : String,
) -> Int? {
  match obj {
    Some(obj) => {
      let field = match obj.get(camel_key) {
        Some(value) => Some(value)
        None => obj.get(snake_key)
      }
      match field {
        Some(Number(n, ..)) => return Some(n.trunc().to_int())
        Some(String(value)) =>
          return try @string.parse_int(value, base=10) catch {
            _ => None
          } noraise {
            parsed => Some(parsed)
          }
        _ => ()
      }
    }
    None => ()
  }
  usage_query_int_any(path, snake_key, camel_key)
}

///|
fn stream_check_string_request(
  path : StringView,
  obj : Map[String, Json]?,
  snake_key : String,
  camel_key : String,
) -> String? {
  match obj {
    Some(obj) => {
      let field = match obj.get(camel_key) {
        Some(value) => Some(value)
        None => obj.get(snake_key)
      }
      match field {
        Some(String(value)) => return Some(value)
        _ => ()
      }
    }
    None => ()
  }
  usage_query_value_any(path, snake_key, camel_key)
}

///|
fn stream_check_model_for_app(
  config : StreamCheckConfig,
  app_type : String,
) -> String {
  match app_type {
    "claude" | "claude-desktop" => config.claude_model
    "gemini" => config.gemini_model
    _ => config.codex_model
  }
}

///|
fn stream_check_reported_model_for_app(
  config : StreamCheckConfig,
  app_type : String,
) -> String {
  let model = stream_check_model_for_app(config, app_type)
  if app_type == "codex" {
    stream_check_parse_model_with_effort(model).0
  } else {
    model
  }
}

///|
fn stream_check_parse_model_with_effort(model : String) -> (String, String?) {
  let split = match model.find("@") {
    Some(index) => Some(index)
    None => model.find("#")
  }
  match split {
    Some(index) => {
      let effort = model[index + 1:]
      if !effort.is_empty() {
        (model[:index].to_owned(), Some(effort.to_owned()))
      } else {
        (model, None)
      }
    }
    None => (model, None)
  }
}

///|
fn moon_unit_success_json() -> Json {
  Json::null()
}

///|
fn moon_update_tray_menu_result() -> Json {
  Json::boolean(false)
}

///|
priv struct ProxyProviderQuery {
  provider_id : String
  app_type : String
}

///|
fn json_non_empty_string_from_map_any(
  obj : Map[String, Json],
  keys : Array[String],
) -> String? {
  for key in keys {
    match json_string_from_map(obj, key) {
      Some(value) if !value.trim().is_empty() => return Some(value)
      _ => ()
    }
  }
  None
}

///|
fn codex_toml_string_value(content : String, key : String) -> String? {
  for raw_line in content.split("\n") {
    let line = raw_line.trim()
    if line.has_prefix("#") {
      continue
    }
    let mut index = 0
    let mut found_key = ""
    let mut found_value = ""
    for part in line.split("=") {
      if index == 0 {
        found_key = part.trim().to_owned()
      } else if index == 1 {
        found_value = part.trim().to_owned()
      }
      index += 1
    }
    if index < 2 || found_key != key {
      continue
    }
    let value = found_value
    if value.length() >= 2 &&
      value[0] == '"' &&
      value[value.length() - 1] == '"' {
      return Some(value[1:value.length() - 1].to_owned())
    }
    if !value.is_empty() {
      return Some(value)
    }
  }
  None
}

///|
fn suite_write_outcome_json() -> Json {
  let empty : Map[String, Json] = {}
  Json::object(empty)
}

///|
fn suite_object_payload(body : Json?, key : String) -> Json? {
  match body {
    Some(Object(obj)) =>
      match obj.get(key) {
        Some(Object(nested)) => Some(Json::object(nested))
        Some(_) => None
        None => Some(Json::object(obj))
      }
    _ => None
  }
}

///|
fn suite_object_request(path : StringView, body : Json?, key : String) -> Json? {
  match suite_object_payload(body, key) {
    Some(payload) => return Some(payload)
    None => ()
  }
  match usage_query_value(path, key) {
    Some(raw) => {
      let parsed = @json.parse(raw) catch { _ => return None }
      match parsed {
        Object(obj) => Some(Json::object(obj))
        _ => None
      }
    }
    None => None
  }
}

///|
fn split_csv_json(value : String) -> Json {
  let items : Array[Json] = []
  for raw in value.split(",") {
    let trimmed = raw.trim().to_owned()
    if !trimmed.is_empty() {
      items.push(Json::string(trimmed))
    }
  }
  Json::array(items)
}

///|
const HERMES_DASHBOARD_COMMAND = "hermes dashboard"

///|
const HERMES_DASHBOARD_LOG_PATH = "/tmp/moonstat_hermes_dashboard.log"

///|
fn normalize_claude_desktop_mode(mode : String) -> String? {
  match mode.trim().to_lower() {
    "direct" => Some("direct")
    "proxy" => Some("proxy")
    _ => None
  }
}

///|
fn split_endpoint_urls(value : String) -> Array[String] {
  let urls : Array[String] = []
  for raw in value.split(",") {
    urls.push(raw.to_owned())
  }
  urls
}

///|
const MOONSTAT_ENDPOINT_DEFAULT_TIMEOUT_SECS = 8

///|
const MOONSTAT_ENDPOINT_MIN_TIMEOUT_SECS = 2

///|
const MOONSTAT_ENDPOINT_MAX_TIMEOUT_SECS = 30

///|
fn moon_endpoint_invalid_url_error(url : String) -> String {
  if url.has_prefix("http://") || url.has_prefix("https://") {
    if moon_endpoint_url_missing_host(url) {
      "URL 无效: empty host"
    } else {
      "URL 无效"
    }
  } else {
    "URL 无效: relative URL without a base"
  }
}

///|
fn moon_endpoint_url_missing_host(url : String) -> Bool {
  match endpoint_url_host_start(url) {
    Some(start) => {
      if url.length() <= start {
        return true
      }
      let rest = url[start:]
      rest.has_prefix("/") || rest.has_prefix("?") || rest.has_prefix("#")
    }
    None => false
  }
}

///|
fn endpoint_url_host_start(url : String) -> Int? {
  if url.has_prefix("http://") {
    Some(7)
  } else if url.has_prefix("https://") {
    Some(8)
  } else {
    None
  }
}

///|
fn parse_bool_value(value : String) -> Bool? {
  match value.trim().to_owned().to_lower() {
    "true" | "1" | "yes" | "on" => Some(true)
    "false" | "0" | "no" | "off" => Some(false)
    _ => None
  }
}

///|
fn parse_non_negative_decimal_to_double(value : String) -> Double? {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() {
    return None
  }
  let mut seen_dot = false
  let mut seen_digit = false
  for ch in trimmed {
    if ch == '.' {
      if seen_dot {
        return None
      }
      seen_dot = true
    } else {
      let code = ch.to_int()
      if code < '0'.to_int() || code > '9'.to_int() {
        return None
      }
      seen_digit = true
    }
  }
  if !seen_digit {
    return None
  }
  Some(parse_decimal_scaled(trimmed, 1_000_000L).to_double() / 1_000_000.0)
}

///|
fn claude_desktop_model_list_json(
  provider? : ProviderRouteTarget? = None,
) -> Json {
  let routes = match provider {
    Some(provider) => provider.resolved_claude_desktop_model_routes()
    None => []
  }
  if !routes.is_empty() {
    return claude_desktop_route_model_list_json(routes)
  }
  let data = [
    claude_desktop_model_json("claude-sonnet-4-6", supports_1m=true),
    claude_desktop_model_json("claude-opus-4-8", supports_1m=true),
    claude_desktop_model_json("claude-haiku-4-5", supports_1m=true),
  ]
  {
    "data": Json::array(data),
    "has_more": Json::boolean(false),
    "first_id": Json::string("claude-sonnet-4-6"),
    "last_id": Json::string("claude-haiku-4-5"),
  }.to_json()
}

///|
fn claude_desktop_route_model_list_json(
  routes : Array[(String, String, String?, Bool)],
) -> Json {
  let data = routes.map(fn(route) {
    let (route_id, _, label_override, supports_1m) = route
    claude_desktop_model_json(route_id, label_override~, supports_1m~)
  })
  let first_id = match routes.get(0) {
    Some((route_id, _, _, _)) => Json::string(route_id)
    None => Json::null()
  }
  let last_id = if routes.is_empty() {
    Json::null()
  } else {
    match routes.get(routes.length() - 1) {
      Some((route_id, _, _, _)) => Json::string(route_id)
      None => Json::null()
    }
  }
  {
    "data": Json::array(data),
    "has_more": Json::boolean(false),
    "first_id": first_id,
    "last_id": last_id,
  }.to_json()
}

///|
fn claude_desktop_model_json(
  id : String,
  label_override? : String? = None,
  supports_1m? : Bool = true,
) -> Json {
  let obj : Map[String, Json] = {
    "type": Json::string("model"),
    "id": Json::string(id),
    "created_at": Json::string("2024-01-01T00:00:00Z"),
  }
  match label_override {
    Some(label) => obj["labelOverride"] = Json::string(label)
    None => ()
  }
  if supports_1m {
    obj["supports1m"] = Json::boolean(true)
  }
  Json::object(obj)
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
fn ProviderRouteTarget::resolved_claude_desktop_model_routes(
  self : ProviderRouteTarget,
) -> Array[(String, String, String?, Bool)] {
  let routes : Array[(String, String, String?, Bool)] = []
  if self.claude_desktop_model_routes.is_empty() {
    return routes
  }
  let reserved_route_ids : Array[String] = []
  for route_id in self.claude_desktop_model_routes.keys() {
    let trimmed = route_id.trim().to_owned()
    if is_claude_safe_model_id(trimmed) {
      reserved_route_ids.push(trimmed)
    }
  }
  let route_ids : Array[String] = []
  for route_id in self.claude_desktop_model_routes.keys() {
    route_ids.push(route_id)
  }
  route_ids.sort()
  for route_id in route_ids {
    let trimmed_route_id = route_id.trim().to_owned()
    guard self.claude_desktop_model_routes.get(route_id) is Some(route) else {
      continue
    }
    let upstream_model = route.model.trim().to_owned()
    if trimmed_route_id.is_empty() || upstream_model.is_empty() {
      continue
    }
    let route_id_is_safe = is_claude_safe_model_id(trimmed_route_id)
    let resolved_route_id = if route_id_is_safe {
      trimmed_route_id
    } else {
      next_claude_desktop_catalog_safe_route_id(routes, reserved_route_ids)
    }
    let label_override = match route.label_override {
      Some(label) => {
        let label = label.trim().to_owned()
        if label.is_empty() {
          None
        } else {
          Some(label)
        }
      }
      None => if route_id_is_safe { None } else { Some(upstream_model) }
    }
    routes.push(
      (
        resolved_route_id,
        upstream_model,
        label_override,
        route.supports_1m.unwrap_or(false),
      ),
    )
  }
  routes.sort_by(fn(left, right) {
    let (left_route_id, _, _, _) = left
    let (right_route_id, _, _, _) = right
    left_route_id.compare(right_route_id)
  })
  let deduped : Array[(String, String, String?, Bool)] = []
  for route in routes {
    let (route_id, _, _, _) = route
    match deduped.last() {
      Some((previous_route_id, _, _, _)) if previous_route_id == route_id => ()
      _ => deduped.push(route)
    }
  }
  deduped
}

///|
fn next_claude_desktop_catalog_safe_route_id(
  existing : Array[(String, String, String?, Bool)],
  reserved : Array[String],
) -> String {
  for route_id in claude_desktop_default_proxy_route_ids() {
    if !reserved.contains(route_id) &&
      !existing.any(fn(route) {
        let (existing_route_id, _, _, _) = route
        existing_route_id == route_id
      }) {
      return route_id
    }
  }
  for index in 2..<10000 {
    let route_id = "claude-sonnet-4-6-r\{index}"
    if !reserved.contains(route_id) &&
      !existing.any(fn(route) {
        let (existing_route_id, _, _, _) = route
        existing_route_id == route_id
      }) {
      return route_id
    }
  }
  "claude-sonnet-4-6-r10000"
}

///|
fn ProviderRouteTarget::claude_desktop_route_upstream_model(
  self : ProviderRouteTarget,
  request_model : String,
) -> String? {
  let requested = strip_one_m_suffix_for_route_lookup(request_model)
  if requested.is_empty() || self.claude_desktop_model_routes.is_empty() {
    return None
  }
  let routes = self.resolved_claude_desktop_model_routes()
  for route in routes {
    let (route_id, upstream_model, _, _) = route
    if route_id == requested {
      return Some(upstream_model)
    }
  }
  for route in routes {
    let (route_id, upstream_model, _, _) = route
    if claude_desktop_opus_route_alias_matches(route_id, requested) {
      return Some(upstream_model)
    }
  }
  guard is_claude_safe_model_id(requested) else { return None }
  guard claude_role_keyword(requested) is Some(role) else { return None }
  for route in routes {
    let (route_id, upstream_model, _, _) = route
    if claude_role_keyword(route_id) == Some(role) {
      return Some(upstream_model)
    }
  }
  None
}

///|
fn claude_desktop_opus_route_alias_matches(
  route_id : String,
  requested : String,
) -> Bool {
  let route = strip_one_m_suffix_for_route_lookup(route_id).trim().to_lower()
  let requested = requested.trim().to_lower()
  (route == "claude-opus-4-7" && requested == "claude-opus-4-8") ||
  (route == "claude-opus-4-8" && requested == "claude-opus-4-7")
}

///|
async fn ProxyService::handle_messages(
  self : ProxyService,
  auth : AuthService,
  usage : UsageService,
  config : ConfigService,
  session_store : SessionService,
  default_model : String,
  logger : @pino.Logger,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let app_type = if r.path.has_prefix("/claude-desktop") {
    guard auth.validate_claude_desktop_gateway_auth(self, usage, r, w) else {
      return
    }
    "claude-desktop"
  } else {
    "claude"
  }
  let body = r.body.read_all()
  let body_str = body.text()
  usage.record_inbound(body_str.length())
  let active_provider = self.activate_provider(usage, app_type)
  usage.record_request_context(app_type, default_model)
  if active_provider is None && self.all_provider_circuits_open(app_type) {
    usage.write_provider_selection_error(
      self,
      app_type,
      AllProvidersCircuitOpen,
      w,
    )
    return
  }
  let json_result : Result[Json, Error] = moon_result(() => {
    @json.parse(body_str)
  })
  match json_result {
    Err(_) => {
      usage.record_bad_request_with_provider(self)
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadRequest)
      w.write("{\"error\":\"Invalid JSON\"}")
      w.flush()
      return
    }
    Ok(json) => {
      let client_format = moon_client_format_for_request(
        r.path.to_owned(),
        Some(json),
      ).to_string()
      let session = extract_client_session_context(
        r.headers,
        json,
        client_format,
      )
      let upstream_session_id = session.upstream_session_id()
      let anthropic_beta = r.headers.get("anthropic-beta")
      let anthropic_request_result : Result[AnthropicRequest, Error] = moon_result(() => {
          @json.from_json(json)
        },
      )
      match anthropic_request_result {
        Err(_) => {
          usage.record_bad_request_with_provider(self)
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
          logger.info(
            "Received Anthropic request for model: \{anthropic_request.model}",
          )
          let model = self.upstream_claude_model(
            anthropic_request.model,
            active_provider,
            default_model~,
            app_type~,
          )
          logger.debug("Using Codex model: \{model}")
          let stream = anthropic_request.stream.unwrap_or(false)
          usage.record_stream_mode(stream)
          usage.record_request_context(
            app_type,
            anthropic_request.model,
            outbound_model=Some(model),
            session_id=Some(session.session_id),
          )
          if stream {
            self.handle_streaming_request(
              auth,
              usage,
              config,
              session_store,
              default_model,
              logger,
              anthropic_request,
              json,
              model,
              r.path.to_owned(),
              active_provider,
              app_type,
              self.selected_provider_chain(app_type),
              [],
              anthropic_beta,
              upstream_session_id,
              w,
            )
          } else {
            self.handle_non_streaming_request(
              auth,
              usage,
              config,
              session_store,
              default_model,
              logger,
              anthropic_request,
              json,
              model,
              r.path.to_owned(),
              active_provider,
              app_type,
              self.selected_provider_chain(app_type),
              [],
              anthropic_beta,
              upstream_session_id,
              w,
            )
          }
        }
      }
    }
  }
}

///|
fn ProxyService::upstream_claude_model(
  _self : ProxyService,
  request_model : String,
  provider : ProviderRouteTarget?,
  default_model~ : String,
  app_type? : String = "claude",
) -> String {
  match provider {
    Some(provider) =>
      if app_type == "claude-desktop" {
        match provider.claude_desktop_route_upstream_model(request_model) {
          Some(upstream) => strip_one_m_suffix_for_upstream(upstream)
          None => strip_one_m_suffix_for_upstream(request_model)
        }
      } else {
        provider.map_model_for_upstream(request_model)
      }
    None => default_model
  }
}

///|
async fn ProxyService::forward_non_streaming_claude_compatible_request(
  self : ProxyService,
  auth : AuthService,
  usage : UsageService,
  config : ConfigService,
  session_store : SessionService,
  default_model : String,
  logger : @pino.Logger,
  request : AnthropicRequest,
  request_json : Json,
  upstream_model : String,
  request_path : String,
  provider : ProviderRouteTarget,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
  anthropic_beta : String?,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  usage.record_request_context(
    app_type,
    request.model,
    outbound_model=Some(upstream_model),
    session_id~,
  )
  let api_format = provider.claude_api_format_for_model(upstream_model)
  let request_json = claude_desktop_proxy_request_json_for_upstream(
    request_json, provider, upstream_model, app_type,
  )
  let prepared_upstream = prepare_upstream_request(
    claude_request_json_for_upstream(request_json, upstream_model),
    provider=Some(provider),
    copilot_config_json=Some(config.copilot_optimizer_config_json),
    anthropic_beta~,
    session_id~,
  )
  let upstream_body = prepared_upstream.body
  let copilot_headers = prepared_upstream.copilot_headers
  let endpoint = claude_transform_endpoint(
    api_format,
    false,
    request_path=request_path[:],
  ).replace_all(old="__MODEL__", new=normalize_gemini_model_id(upstream_model))
  logger.debug(
    prompt_cache_trace_message(
      app_type,
      provider.provider_id,
      endpoint,
      Some(api_format),
      upstream_body,
      session_id is Some(_),
    ),
  )
  let outbound = self.claude_provider_outbound_body(
    self.gemini_shadow,
    provider,
    upstream_body,
    api_format,
    session_id,
  )
  match
    self.post_claude_compatible_provider_json(
      provider,
      endpoint,
      outbound,
      api_format,
      anthropic_beta,
      copilot_headers~,
    ) {
    Err(error) => {
      let error_body = "{\"error\":{\"message\":\"Claude upstream request failed: \{error}\",\"type\":\"upstream_error\"}}"
      if !providers.is_empty() {
        let next = self.activate_next_provider_after_upstream_status(
          usage,
          app_type,
          providers,
          attempted_provider_ids,
          @status.BadGateway,
        )
        if next is Some(provider) {
          self.handle_non_streaming_request(
            auth,
            usage,
            config,
            session_store,
            default_model,
            logger,
            request,
            request_json,
            self.upstream_claude_model(
              request.model,
              Some(provider),
              default_model~,
              app_type~,
            ),
            request_path,
            Some(provider),
            app_type,
            providers,
            attempted_provider_ids,
            anthropic_beta,
            session_id,
            w,
          )
          return
        }
      }
      usage.record_upstream_error_status_with_provider(
        self,
        error_body.length(),
        @status.BadGateway,
      )
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadGateway)
      w.write(error_body)
      w.flush()
    }
    Ok((response, response_body)) => {
      let mut response_code = response.code
      let mut final_response_body = response_body
      let mut final_response_headers = response.headers
      if moon_media_retry_should_trigger(
          response_code, final_response_body, upstream_body,
        ) {
        let retry_body = replace_image_blocks_with_marker(upstream_body)
        if retry_body.count > 0 {
          let retry_outbound = self.claude_provider_outbound_body(
            self.gemini_shadow,
            provider,
            retry_body.body,
            api_format,
            session_id,
          )
          match
            self.post_claude_compatible_provider_json(
              provider,
              endpoint,
              retry_outbound,
              api_format,
              anthropic_beta,
              copilot_headers~,
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
        match moon_rectifier_retry_body(final_response_body, upstream_body) {
          Some(rectifier_retry) => {
            logger.info(
              "Moonstat rectifier retry triggered: \{rectifier_retry.kind} (\{rectifier_retry.summary})",
            )
            let retry_outbound = self.claude_provider_outbound_body(
              self.gemini_shadow,
              provider,
              rectifier_retry.body,
              api_format,
              session_id,
            )
            match
              self.post_claude_compatible_provider_json(
                provider,
                endpoint,
                retry_outbound,
                api_format,
                anthropic_beta,
                copilot_headers~,
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
            usage.record_internal_error_with_provider(self)
            w.header().set("Content-Type", "application/json")
            w.write_header(@status.InternalServerError)
            w.write(
              Json::object({ "error": Json::string(message) }).stringify(),
            )
            w.flush()
            return
          }
        }
        let token_usage = token_usage_or_response_model(
          token_usage_from_claude_compatible_response(parsed, api_format),
          parsed,
          ["model", "modelVersion"],
        )
        if api_format == "openai_responses" {
          ignore(session_store.codex_chat_history.record_response(parsed))
        }
        usage.record_success_usage_with_provider(
          self,
          token_usage,
          final_response_body.length(),
        )
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
            usage, app_type, providers, attempted_provider_ids, response_code,
          )
          if next is Some(provider) {
            self.handle_non_streaming_request(
              auth,
              usage,
              config,
              session_store,
              default_model,
              logger,
              request,
              request_json,
              self.upstream_claude_model(
                request.model,
                Some(provider),
                default_model~,
                app_type~,
              ),
              request_path,
              Some(provider),
              app_type,
              providers,
              attempted_provider_ids,
              anthropic_beta,
              session_id,
              w,
            )
            return
          }
        }
        usage.record_upstream_error_status_with_provider(
          self,
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
fn claude_request_json_for_upstream(
  body : Json,
  upstream_model : String,
) -> Json {
  guard body is Object(obj) else { return body }
  obj["model"] = Json::string(upstream_model)
  Json::object(obj)
}

///|
fn ProviderRouteTarget::should_normalize_mimo_anthropic_thinking_history(
  self : ProviderRouteTarget,
  upstream_model : String,
) -> Bool {
  self.uses_anthropic_messages_format() &&
  (is_mimo_identifier(upstream_model) || self.has_mimo_endpoint())
}

///|
fn ProviderRouteTarget::uses_anthropic_messages_format(
  self : ProviderRouteTarget,
) -> Bool {
  let api_format = match self.api_format {
    Some(api_format) => api_format.trim().to_owned()
    None =>
      match provider_settings_api_format(self.settings_config) {
        Some(api_format) => api_format.trim().to_owned()
        None => "anthropic"
      }
  }
  api_format.is_empty() || api_format == "anthropic"
}

///|
fn ProviderRouteTarget::has_mimo_endpoint(self : ProviderRouteTarget) -> Bool {
  guard self.settings_config is Some(Object(settings)) else { return false }
  match settings.get("env") {
    Some(Object(env)) =>
      match json_string_from_map(env, "ANTHROPIC_BASE_URL") {
        Some(value) if is_mimo_identifier(value) => return true
        _ => ()
      }
    _ => ()
  }
  match json_string_from_map(settings, "base_url") {
    Some(value) if is_mimo_identifier(value) => return true
    _ => ()
  }
  match json_string_from_map(settings, "baseURL") {
    Some(value) if is_mimo_identifier(value) => return true
    _ => ()
  }
  match json_string_from_map(settings, "apiEndpoint") {
    Some(value) if is_mimo_identifier(value) => return true
    _ => ()
  }
  false
}

///|
fn is_mimo_identifier(value : String) -> Bool {
  let lower = value.to_lower()
  lower.contains("mimo") || lower.contains("xiaomimimo")
}

///|
fn normalize_mimo_anthropic_thinking_history(body : Json) -> Json {
  guard body is Object(obj) else { return body }
  guard obj.get("messages") is Some(Array(messages)) else {
    return Json::object(obj)
  }
  for index in 0..<messages.length() {
    guard messages[index] is Object(message_obj) else { continue }
    guard json_string_from_map(message_obj, "role") == Some("assistant") else {
      continue
    }
    guard message_obj.get("content") is Some(Array(content)) else { continue }
    guard content.any(fn(block) {
      block is Object(block_obj) &&
      json_string_from_map(block_obj, "type") == Some("tool_use")
    }) else {
      continue
    }
    message_obj["content"] = Json::array(
      normalize_mimo_anthropic_content_blocks(content),
    )
    messages[index] = Json::object(message_obj)
  }
  obj["messages"] = Json::array(messages)
  Json::object(obj)
}

///|
fn normalize_mimo_anthropic_content_blocks(
  content : Array[Json],
) -> Array[Json] {
  let normalized : Array[Json] = []
  let mut has_thinking = false
  for block in content {
    match block {
      Object(block_obj) =>
        match json_string_from_map(block_obj, "type") {
          Some("thinking") => {
            block_obj.remove("signature")
            let text = json_string_from_map(block_obj, "thinking").unwrap_or("")
            if text.trim().is_empty() {
              block_obj["thinking"] = Json::string("tool call")
            }
            has_thinking = true
            normalized.push(Json::object(block_obj))
          }
          Some("redacted_thinking") => {
            has_thinking = true
            normalized.push(
              Json::object({
                "type": Json::string("thinking"),
                "thinking": Json::string("[redacted thinking]"),
              }),
            )
          }
          _ => normalized.push(block)
        }
      _ => normalized.push(block)
    }
  }
  if has_thinking {
    normalized
  } else {
    let result : Array[Json] = [
      Json::object({
        "type": Json::string("thinking"),
        "thinking": Json::string("tool call"),
      }),
    ]
    for block in normalized {
      result.push(block)
    }
    result
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
fn moon_hop_by_hop_response_header_names() -> Array[String] {
  [
    "connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "proxy-connection",
    "te", "trailer", "trailers", "transfer-encoding", "upgrade",
  ]
}

///|
fn moon_connection_listed_response_headers(
  headers : Map[String, String],
) -> Array[String] {
  let result : Array[String] = []
  for key, value in headers {
    if key.to_lower() == "connection" {
      for name_view in value.split(",") {
        let name = name_view.trim().to_owned().to_lower()
        if !name.is_empty() && !result.contains(name) {
          result.push(name)
        }
      }
    }
  }
  result
}

///|
pub fn moon_strip_hop_by_hop_response_headers(
  headers : Map[String, String],
) -> Map[String, String] {
  let hop_by_hop = moon_hop_by_hop_response_header_names()
  let connection_listed = moon_connection_listed_response_headers(headers)
  let result : Map[String, String] = {}
  for key, value in headers {
    let normalized = key.to_lower()
    if hop_by_hop.contains(normalized) || connection_listed.contains(normalized) {
      continue
    }
    result[key] = value
  }
  result
}

///|
pub fn moon_strip_entity_headers_for_rebuilt_body(
  headers : Map[String, String],
) -> Map[String, String] {
  let result : Map[String, String] = {}
  for key, value in headers {
    match key.to_lower() {
      "content-encoding" | "content-length" | "transfer-encoding" => continue
      _ => result[key] = value
    }
  }
  result
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
  mut saw_done : Bool
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
    saw_done: false,
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
  if state.error_seen ||
    !state.saw_choice ||
    (state.finish_reason is None && !state.saw_done) {
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
    state.saw_done = true
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
  match message.get("function_call") {
    Some(Object(function_call)) =>
      self.push_chat_sse_legacy_function_call(function_call)
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
  match delta.get("function_call") {
    Some(Object(function_call)) =>
      self.push_chat_sse_legacy_function_call(function_call)
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
      match function.get("arguments") {
        Some(arguments_json) =>
          match json_tool_arguments_fragment(arguments_json) {
            Some(arguments) => state.arguments = state.arguments + arguments
            None => ()
          }
        None => ()
      }
    }
    _ => ()
  }
}

///|
fn OpenAIChatSseState::push_chat_sse_legacy_function_call(
  self : OpenAIChatSseState,
  function_call : Map[String, Json],
) -> Unit {
  let call : Map[String, Json] = {
    "type": Json::string("function"),
    "function": Json::object(function_call),
  }
  self.push_chat_sse_tool_call(0, call)
}

///|
fn json_tool_arguments_fragment(value : Json) -> String? {
  match value {
    String(text) => Some(text)
    Null => None
    _ => Some(value.stringify())
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
    "finish_reason": match self.finish_reason {
      Some(reason) => Json::string(reason)
      None => Json::null()
    },
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
  let usage = token_usage_or_response_model(
    token_usage_from_gemini_response(body),
    body,
    ["modelVersion"],
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
  let usage = token_usage_or_response_model(
    token_usage_from_openai_response(body),
    body,
    ["model"],
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
async fn ProxyService::handle_non_streaming_request(
  self : ProxyService,
  auth : AuthService,
  usage : UsageService,
  config : ConfigService,
  session_store : SessionService,
  default_model : String,
  logger : @pino.Logger,
  request : AnthropicRequest,
  request_json : Json,
  model : String,
  request_path : String,
  active_provider : ProviderRouteTarget?,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
  anthropic_beta : String?,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  match active_provider {
    Some(provider) if provider.can_use_claude_compatible_upstream() => {
      self.forward_non_streaming_claude_compatible_request(
        auth, usage, config, session_store, default_model, logger, request, request_json,
        model, request_path, provider, app_type, providers, attempted_provider_ids,
        anthropic_beta, session_id, w,
      )
      return
    }
    _ => ()
  }
  guard auth.credentials is Some(creds) else {
    usage.record_unauthorized_with_provider(self)
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write("{\"error\":\"Not authenticated. Please login first.\"}")
    w.flush()
    return
  }
  let codex_input = convert_anthropic_to_codex(request, model)
  let codex_request = build_codex_request(codex_input, model, false)
  logger.debug("Sending request to Codex API")
  let client = @http.Client::new(
    "https://chatgpt.com",
    headers=codex_oauth_headers(creds, "application/json", session_id),
  )
  defer client.close()
  let response = client.post("/backend-api/codex/responses", codex_request)
  if response.code != 200 {
    let error_body = client.read_all().text()
    logger.error("Codex API error: \{response.code} - \{error_body}")
    if response.code == 401 {
      logger.info("Attempting to refresh credentials")
      let refresh_result : Result[@codex.Credentials, Error] = moon_async_result(() => {
          @codex.refresh_and_save_credentials()
        },
      )
      match refresh_result {
        Ok(new_creds) => {
          auth.credentials = Some(new_creds)
          logger.info("Credentials refreshed, retrying request")
          self.handle_non_streaming_request(
            auth, usage, config, session_store, default_model, logger, request, request_json,
            model, request_path, active_provider, app_type, providers, attempted_provider_ids,
            anthropic_beta, session_id, w,
          )
          return
        }
        Err(_) => ()
      }
    }
    usage.record_upstream_error_status_with_provider(
      self,
      error_body.length(),
      response.code,
    )
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write("{\"error\":\"Codex API error: \{response.code}\"}")
    w.flush()
    return
  }
  let response_body = client.read_all().text()
  let response_json_result : Result[Json, Error] = moon_result(() => {
    @json.parse(response_body)
  })
  match response_json_result {
    Ok(json) => {
      ignore(session_store.codex_chat_history.record_response(json))
      let token_usage = token_usage_or_response_model(
        token_usage_from_codex_response_auto(json),
        json,
        ["model"],
      )
      usage.record_success_usage_with_provider(
        self,
        token_usage,
        response_body.length(),
      )
      let anthropic_response = convert_codex_to_anthropic(json, request.model)
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.Ok)
      w.write(anthropic_response.to_json().stringify())
    }
    Err(_) => {
      usage.record_internal_error_with_provider(self)
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.InternalServerError)
      w.write("{\"error\":\"Failed to parse Codex response\"}")
    }
  }
  w.flush()
}

///|
async fn ProxyService::forward_streaming_claude_compatible_request(
  self : ProxyService,
  auth : AuthService,
  usage : UsageService,
  config : ConfigService,
  session_store : SessionService,
  default_model : String,
  logger : @pino.Logger,
  request : AnthropicRequest,
  request_json : Json,
  upstream_model : String,
  request_path : String,
  provider : ProviderRouteTarget,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
  anthropic_beta : String?,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  usage.record_request_context(
    app_type,
    request.model,
    outbound_model=Some(upstream_model),
    session_id~,
  )
  let api_format = provider.claude_api_format_for_model(upstream_model)
  let request_json = claude_desktop_proxy_request_json_for_upstream(
    request_json, provider, upstream_model, app_type,
  )
  let prepared_upstream = prepare_upstream_request(
    claude_stream_request_json_for_upstream(request_json, upstream_model),
    provider=Some(provider),
    copilot_config_json=Some(config.copilot_optimizer_config_json),
    anthropic_beta~,
    session_id~,
  )
  let upstream_body = prepared_upstream.body
  let copilot_headers = prepared_upstream.copilot_headers
  let endpoint = claude_transform_endpoint(
    api_format,
    true,
    request_path=request_path[:],
  ).replace_all(old="__MODEL__", new=normalize_gemini_model_id(upstream_model))
  logger.debug(
    prompt_cache_trace_message(
      app_type,
      provider.provider_id,
      endpoint,
      Some(api_format),
      upstream_body,
      session_id is Some(_),
    ),
  )
  let outbound = self.claude_provider_outbound_body(
    self.gemini_shadow,
    provider,
    upstream_body,
    api_format,
    session_id,
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
  let custom_user_agent = provider_custom_user_agent(provider)
  let client = @http.Client::new(
    origin,
    headers=claude_compatible_provider_headers(
      api_key,
      api_format,
      anthropic_beta~,
      accept="text/event-stream",
      custom_user_agent~,
      provider_type=provider.provider_type,
      extra_headers=copilot_headers,
    ),
  )
  defer client.close()
  let response = client.post(path, outbound)
  if response.code != 200 {
    let error_body = client.read_all().text()
    if moon_media_retry_should_trigger(response.code, error_body, upstream_body) {
      let retry_body = replace_image_blocks_with_marker(upstream_body)
      if retry_body.count > 0 {
        let retry_outbound = self.claude_provider_outbound_body(
          self.gemini_shadow,
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
            anthropic_beta~,
            accept="text/event-stream",
            custom_user_agent~,
            provider_type=provider.provider_type,
            extra_headers=copilot_headers,
          ),
        )
        defer retry_client.close()
        let retry_response = retry_client.post(path, retry_outbound)
        if retry_response.code == 200 {
          self.forward_successful_claude_compatible_stream(
            usage,
            session_store,
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
            usage,
            app_type,
            providers,
            attempted_provider_ids,
            retry_response.code,
          )
          if next is Some(provider) {
            self.handle_streaming_request(
              auth,
              usage,
              config,
              session_store,
              default_model,
              logger,
              request,
              request_json,
              self.upstream_claude_model(
                request.model,
                Some(provider),
                default_model~,
                app_type~,
              ),
              request_path,
              Some(provider),
              app_type,
              providers,
              attempted_provider_ids,
              anthropic_beta,
              session_id,
              w,
            )
            return
          }
        }
        usage.record_upstream_error_status_with_provider(
          self,
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
    match moon_rectifier_retry_body(error_body, upstream_body) {
      Some(rectifier_retry) => {
        logger.info(
          "Moonstat rectifier stream retry triggered: \{rectifier_retry.kind} (\{rectifier_retry.summary})",
        )
        let retry_outbound = self.claude_provider_outbound_body(
          self.gemini_shadow,
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
            anthropic_beta~,
            accept="text/event-stream",
            custom_user_agent~,
            provider_type=provider.provider_type,
            extra_headers=copilot_headers,
          ),
        )
        defer retry_client.close()
        let retry_response = retry_client.post(path, retry_outbound)
        if retry_response.code == 200 {
          self.forward_successful_claude_compatible_stream(
            usage,
            session_store,
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
            usage,
            app_type,
            providers,
            attempted_provider_ids,
            retry_response.code,
          )
          if next is Some(provider) {
            self.handle_streaming_request(
              auth,
              usage,
              config,
              session_store,
              default_model,
              logger,
              request,
              request_json,
              self.upstream_claude_model(
                request.model,
                Some(provider),
                default_model~,
                app_type~,
              ),
              request_path,
              Some(provider),
              app_type,
              providers,
              attempted_provider_ids,
              anthropic_beta,
              session_id,
              w,
            )
            return
          }
        }
        usage.record_upstream_error_status_with_provider(
          self,
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
        usage,
        app_type,
        providers,
        attempted_provider_ids,
        response.code,
      )
      if next is Some(provider) {
        self.handle_streaming_request(
          auth,
          usage,
          config,
          session_store,
          default_model,
          logger,
          request,
          request_json,
          self.upstream_claude_model(
            request.model,
            Some(provider),
            default_model~,
            app_type~,
          ),
          request_path,
          Some(provider),
          app_type,
          providers,
          attempted_provider_ids,
          anthropic_beta,
          session_id,
          w,
        )
        return
      }
    }
    usage.record_upstream_error_status_with_provider(
      self,
      error_body.length(),
      response.code,
    )
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write(error_body)
    w.flush()
    return
  }
  self.forward_successful_claude_compatible_stream(
    usage,
    session_store,
    client,
    request.model,
    api_format,
    provider.provider_id,
    session_id,
    w,
  )
}

///|
async fn ProxyService::forward_successful_claude_compatible_stream(
  self : ProxyService,
  usage : UsageService,
  session_store : SessionService,
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
  usage.record_provider_result(self, true)
  let stream_events : Array[Json] = []
  if api_format == "openai_chat" {
    let first_token_ms = self.forward_openai_chat_sse_as_anthropic(
      usage, client, stream_events, w,
    )
    usage.record_success_stream_usage_with_provider(
      self,
      token_usage_from_openai_stream_events(stream_events),
      0,
      record_provider=false,
      first_token_ms~,
      skip_empty_usage=true,
    )
  } else if api_format == "gemini_native" {
    let first_token_ms = self.forward_gemini_native_sse_as_anthropic(
      usage,
      self.gemini_shadow,
      client,
      stream_events,
      provider_id,
      session_id,
      w,
    )
    usage.record_success_stream_usage_with_provider(
      self,
      token_usage_from_gemini_stream_chunks(stream_events),
      0,
      record_provider=false,
      first_token_ms~,
      skip_empty_usage=true,
    )
  } else if api_format == "openai_responses" {
    let reader = CodexStreamReader::new(client, request_model)
    let mut first_token_ms : Int? = None
    while reader.read() is Some(event) {
      first_token_ms = usage.first_stream_event_ms(first_token_ms)
      w.write("event: \{event.event_type}\n")
      w.write("data: \{event.data}\n\n")
      w.flush()
    }
    ignore(session_store.codex_chat_history.record_stream_events(reader.events))
    usage.record_success_stream_usage_with_provider(
      self,
      token_usage_from_codex_stream_events_auto(reader.events),
      0,
      record_provider=false,
      first_token_ms~,
      skip_empty_usage=true,
    )
  } else {
    let first_token_ms = self.forward_anthropic_sse_passthrough(
      usage, client, stream_events, w,
    )
    usage.record_success_stream_usage_with_provider(
      self,
      token_usage_from_claude_stream_events(stream_events),
      0,
      record_provider=false,
      first_token_ms~,
      skip_empty_usage=true,
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
priv struct PreparedUpstreamRequest {
  body : Json
  copilot_headers : Map[String, String]
}

///|
fn prepare_upstream_request_body(
  body : Json,
  provider? : ProviderRouteTarget? = None,
  copilot_config_json? : Json? = None,
  anthropic_beta? : String? = None,
  session_id? : String? = None,
) -> Json {
  prepare_upstream_request(
    body,
    provider~,
    copilot_config_json~,
    anthropic_beta~,
    session_id~,
  ).body
}

///|
fn prepare_upstream_request(
  body : Json,
  provider? : ProviderRouteTarget? = None,
  copilot_config_json? : Json? = None,
  anthropic_beta? : String? = None,
  session_id? : String? = None,
) -> PreparedUpstreamRequest {
  let filtered = filter_private_params_for_upstream(body, None, [])
  let copilot_optimization = match copilot_config_json {
    Some(config) =>
      apply_moon_copilot_optimizer_for_provider(
        filtered,
        provider,
        config,
        anthropic_beta is Some(_),
        client_session_id=session_id,
      )
    None => { body: filtered, headers: {} }
  }
  let optimized = apply_moon_optimizer_for_provider(
    copilot_optimization.body,
    provider,
  )
  {
    body: canonicalize_json_value(
      replace_images_for_text_only_model(optimized, provider~).body,
    ),
    copilot_headers: copilot_optimization.headers,
  }
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
  if !rectifier_media_heuristic_enabled(provider) {
    return { body: Json::object(obj), count: 0 }
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
async fn ProxyService::forward_openai_chat_sse_as_anthropic(
  _self : ProxyService,
  usage : UsageService,
  reader : &@io.Reader,
  events : Array[Json],
  w : @httpx.ResponseWriter,
) -> Int? {
  let mut first_token_ms : Int? = None
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
    first_token_ms = usage.first_stream_event_ms(first_token_ms)
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
  first_token_ms
}

///|
fn openai_chat_stream_chunk_to_anthropic_events(
  chunk : Json,
) -> Array[StreamEvent] {
  let state = OpenAIChatAnthropicStreamState::new()
  state.push_chunk(chunk)
}

///|
async fn ProxyService::forward_anthropic_sse_passthrough(
  _self : ProxyService,
  usage : UsageService,
  reader : &@io.Reader,
  events : Array[Json],
  w : @httpx.ResponseWriter,
) -> Int? {
  let mut first_token_ms : Int? = None
  while reader.read_until("\n") is Some(line) {
    if line is [.. "data: ", .. rest] {
      let data = rest.trim().to_owned()
      let parsed = @json.parse(data) catch { _ => Json::null() }
      if parsed != Json::null() {
        events.push(parsed)
        first_token_ms = usage.first_stream_event_ms(first_token_ms)
      }
    }
    w.write(line)
    w.write("\n")
    w.flush()
  }
  first_token_ms
}

///|
async fn ProxyService::forward_gemini_native_sse_as_anthropic(
  _self : ProxyService,
  usage : UsageService,
  gemini_shadow : GeminiShadowStore,
  reader : &@io.Reader,
  events : Array[Json],
  provider_id : String,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Int? {
  let mut first_token_ms : Int? = None
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
    first_token_ms = usage.first_stream_event_ms(first_token_ms)
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
      gemini_shadow.record_assistant_turn(provider_id, session_id, turn)
    _ => ()
  }
  first_token_ms
}

///|
fn gemini_native_stream_chunk_to_anthropic_events(
  chunk : Json,
) -> Array[StreamEvent] {
  let state = GeminiNativeAnthropicStreamState::new()
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
async fn ProxyService::handle_streaming_request(
  self : ProxyService,
  auth : AuthService,
  usage : UsageService,
  config : ConfigService,
  session_store : SessionService,
  default_model : String,
  logger : @pino.Logger,
  request : AnthropicRequest,
  request_json : Json,
  model : String,
  request_path : String,
  active_provider : ProviderRouteTarget?,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
  anthropic_beta : String?,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  match active_provider {
    Some(provider) if provider.can_use_claude_compatible_upstream() => {
      self.forward_streaming_claude_compatible_request(
        auth, usage, config, session_store, default_model, logger, request, request_json,
        model, request_path, provider, app_type, providers, attempted_provider_ids,
        anthropic_beta, session_id, w,
      )
      return
    }
    _ => ()
  }
  guard auth.credentials is Some(creds) else {
    usage.record_unauthorized_with_provider(self)
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write("{\"error\":\"Not authenticated. Please login first.\"}")
    w.flush()
    return
  }
  let codex_input = convert_anthropic_to_codex(request, model)
  let codex_request = build_codex_request(codex_input, model, true)
  logger.debug("Sending streaming request to Codex API")
  let client = @http.Client::new(
    "https://chatgpt.com",
    headers=codex_oauth_headers(creds, "text/event-stream", session_id),
  )
  defer client.close()
  let response = client.post("/backend-api/codex/responses", codex_request)
  if response.code != 200 {
    let error_body = client.read_all().text()
    logger.error("Codex API error: \{response.code} - \{error_body}")
    if response.code == 401 {
      logger.info("Attempting to refresh credentials")
      let refresh_result : Result[@codex.Credentials, Error] = moon_async_result(() => {
          @codex.refresh_and_save_credentials()
        },
      )
      match refresh_result {
        Ok(new_creds) => {
          auth.credentials = Some(new_creds)
          logger.info("Credentials refreshed, retrying request")
          self.handle_streaming_request(
            auth, usage, config, session_store, default_model, logger, request, request_json,
            model, request_path, active_provider, app_type, providers, attempted_provider_ids,
            anthropic_beta, session_id, w,
          )
          return
        }
        Err(_) => ()
      }
    }
    usage.record_upstream_error_status_with_provider(
      self,
      error_body.length(),
      response.code,
    )
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
  usage.record_provider_result(self, true)
  let mut first_token_ms : Int? = None
  while reader.read() is Some(event) {
    first_token_ms = usage.first_stream_event_ms(first_token_ms)
    w.write("event: \{event.event_type}\n")
    w.write("data: \{event.data}\n\n")
    w.flush()
  }
  ignore(session_store.codex_chat_history.record_stream_events(reader.events))
  usage.record_success_stream_usage_with_provider(
    self,
    token_usage_from_codex_stream_events_auto(reader.events),
    0,
    record_provider=false,
    first_token_ms~,
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
        let args_json_result : Result[Json, Error] = moon_result(() => {
          @json.parse(args)
        })
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
    input_tokens = json_int_or_zero(usage_obj, "input_tokens")
    output_tokens = json_int_or_zero(usage_obj, "output_tokens")
    cache_read_tokens = match json_int(usage_obj, "cache_read_input_tokens") {
      Some(tokens) => tokens
      None =>
        match usage_obj.get("input_tokens_details") {
          Some(Object(details)) => json_int_or_zero(details, "cached_tokens")
          _ => 0
        }
    }
    cache_creation_tokens = json_int_or_zero(
      usage_obj, "cache_creation_input_tokens",
    )
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
  {
    reader,
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
fn init {
  ignore(prepare_upstream_request_body(Json::object({})))
  ignore(openai_chat_stream_chunk_to_anthropic_events(Json::object({})))
  ignore(gemini_native_stream_chunk_to_anthropic_events(Json::object({})))
  ignore(codex_stream_event_from_sse_block("", "model"))
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
fn push_sse_json_event(events : Array[Json], data : String) -> Bool {
  let json_result : Result[Json, Error] = moon_result(() => @json.parse(data))
  match json_result {
    Ok(json) => {
      events.push(json)
      true
    }
    Err(_) => false
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
          let args_json_result : Result[Json, Error] = moon_result(() => {
            @json.parse(args)
          })
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
