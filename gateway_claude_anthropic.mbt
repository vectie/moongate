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
    None => "anthropic"
  }
  api_format.is_empty() || api_format == "anthropic"
}

///|
fn ProviderRouteTarget::has_mimo_endpoint(self : ProviderRouteTarget) -> Bool {
  match self.base_url {
    Some(value) => is_mimo_identifier(value)
    _ => false
  }
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
      self.push_chat_sse_function_call_snapshot(function_call)
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
      self.push_chat_sse_function_call_snapshot(function_call)
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
fn OpenAIChatSseState::push_chat_sse_function_call_snapshot(
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
  match obj.get("supportsImage") {
    Some(true) => return Some(true)
    Some(false) => return Some(false)
    None => ()
    _ => ()
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
