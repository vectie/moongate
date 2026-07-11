///|
fn codex_forward_failed_error_message(
  provider_name : String,
  request_model : String,
  endpoint : String,
  cause : String,
) -> String {
  body_snippet(
    "MoonGate local proxy failed while handling Codex endpoint \{endpoint}. Provider: \{provider_name}; model: \{request_model}; cause: Codex upstream request failed: \{cause}",
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
      "code": Json::string("moongate_forward_failed"),
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
  let usage = usage.begin_request(body_str.length())
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
  let usage = usage.begin_request(body_str.length())
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
  usage : UsageRequest,
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
  usage : UsageRequest,
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
  usage : UsageRequest,
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
  usage : UsageRequest,
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
