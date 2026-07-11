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
  let body = r.body.read_all()
  let body_str = body.text()
  let usage = usage.begin_request(body_str.length())
  let app_type = if r.path.has_prefix("/claude-desktop") {
    guard auth.validate_claude_desktop_gateway_auth(self, usage, r, w) else {
      return
    }
    "claude-desktop"
  } else {
    "claude"
  }
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
  usage : UsageRequest,
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
              "MoonGate rectifier retry triggered: \{rectifier_retry.kind} (\{rectifier_retry.summary})",
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
  usage : UsageRequest,
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
  let client = @http.Client::Client(
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
  usage : UsageRequest,
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
  let client = @http.Client::Client(
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
        let retry_client = @http.Client::Client(
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
          "MoonGate rectifier stream retry triggered: \{rectifier_retry.kind} (\{rectifier_retry.summary})",
        )
        let retry_outbound = self.claude_provider_outbound_body(
          self.gemini_shadow,
          provider,
          rectifier_retry.body,
          api_format,
          session_id,
        )
        let retry_client = @http.Client::Client(
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
  usage : UsageRequest,
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
async fn ProxyService::handle_streaming_request(
  self : ProxyService,
  auth : AuthService,
  usage : UsageRequest,
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
  let client = @http.Client::Client(
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
