///|
fn moonstat_default_provider_router() -> ProviderRouter {
  let router = ProviderRouter::new()
  let claude_model_mapping = moon_model_mapping_from_env()
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
fn ProxyService::activate_provider(
  self : ProxyService,
  usage : UsageService,
  app_type : String,
) -> ProviderRouteTarget? {
  let selected = self.provider_router.select_providers(app_type)
  guard selected.error is None else { return None }
  self.activate_first_available_provider(usage, app_type, selected.providers)
}

///|
fn ProxyService::activate_first_available_provider(
  self : ProxyService,
  usage : UsageService,
  app_type : String,
  providers : Array[ProviderRouteTarget],
) -> ProviderRouteTarget? {
  self.activate_first_available_provider_excluding(usage, app_type, providers, [])
}

///|
fn ProxyService::activate_first_available_provider_excluding(
  self : ProxyService,
  usage : UsageService,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
) -> ProviderRouteTarget? {
  let bypass_circuit_breaker = providers.length() == 1
  let max_attempts = self.provider_router.max_attempts_for_app(app_type)
  if attempted_provider_ids.length() >= max_attempts {
    return None
  }
  for provider in providers {
    if attempted_provider_ids.length() >= max_attempts {
      return None
    }
    if attempted_provider_ids.contains(provider.provider_id) {
      continue
    }
    if self.activate_provider_target(
        usage,
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
fn ProxyService::activate_provider_target(
  self : ProxyService,
  usage : UsageService,
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
  usage.activate_provider_target(
    app_type,
    provider.provider_id,
    provider.provider_name,
    used_half_open_permit=allow.used_half_open_permit,
    cost_multiplier=self.provider_cost_multiplier(provider),
    pricing_model_source=self.provider_pricing_model_source(provider),
  )
  true
}

///|
fn ProxyService::activate_next_provider_after_upstream_status(
  self : ProxyService,
  usage : UsageService,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
  status_code : Int,
) -> ProviderRouteTarget? {
  guard usage.provider_request_context() is Some(context) else { return None }
  if !attempted_provider_ids.contains(context.provider_id) {
    attempted_provider_ids.push(context.provider_id)
  }
  if moon_upstream_status_retryable(status_code) {
    self.provider_router.record_result(
      context.provider_id,
      app_type,
      context.used_half_open_permit,
      false,
    )
    usage.set_last_error("upstream_error")
    self.activate_first_available_provider_excluding(
      usage, app_type, providers, attempted_provider_ids,
    )
  } else {
    self.provider_router.release_permit_neutral(
      context.provider_id,
      app_type,
      context.used_half_open_permit,
    )
    usage.set_last_error("upstream_error")
    None
  }
}

///|
fn provider_selection_error_status(error : ProviderSelectionError) -> Int {
  match error {
    NoProvidersConfigured | AllProvidersCircuitOpen =>
      @status.ServiceUnavailable
  }
}

///|
fn provider_selection_error_code(error : ProviderSelectionError) -> String {
  match error {
    NoProvidersConfigured => "moonstat_no_providers_configured"
    AllProvidersCircuitOpen => "moonstat_all_providers_circuit_open"
  }
}

///|
fn provider_selection_error_message(
  error : ProviderSelectionError,
  app_type : String,
) -> String {
  match error {
    NoProvidersConfigured =>
      "Moonstat local proxy has no configured provider for \{app_type}"
    AllProvidersCircuitOpen =>
      "Moonstat local proxy has no available \{app_type} provider because all provider circuits are open"
  }
}

///|
fn provider_selection_error_json(
  error : ProviderSelectionError,
  app_type : String,
) -> Json {
  {
    "error": {
      "message": Json::string(provider_selection_error_message(error, app_type)),
      "type": Json::string("proxy_error"),
      "code": Json::string(provider_selection_error_code(error)),
      "param": Json::null(),
      "app_type": Json::string(app_type),
      "selection_error": Json::string(error.to_string()),
    }.to_json(),
  }.to_json()
}

///|
fn SessionService::codex_provider_outbound_request(
  self : SessionService,
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
fn ProxyService::active_provider_target(
  self : ProxyService,
  usage : UsageService,
  providers : Array[ProviderRouteTarget],
) -> ProviderRouteTarget? {
  let _ = self
  guard usage.current_provider_id() is Some(provider_id) else {
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
async fn ProxyService::handle_models(
  _self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(
    moon_models_endpoint_response_json(
      @codex_config.active_model_catalog_json(),
    ).stringify(),
  )
  w.flush()
}

///|
async fn ProxyService::handle_claude_desktop_models(
  self : ProxyService,
  auth : AuthService,
  usage : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard auth.validate_claude_desktop_gateway_auth(self, usage, r, w) else {
    return
  }
  let provider = self.activate_provider(usage, "claude-desktop")
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(claude_desktop_model_list_json(provider~).stringify())
  w.flush()
}

///|
async fn ProxyService::handle_gemini(
  self : ProxyService,
  usage : UsageService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = r.body.read_all()
  let body_str = body.text()
  usage.record_inbound(body_str.length())
  let _ = self.activate_provider(usage, "gemini")
  usage.record_request_context("gemini", "gemini")
  let request_json : Json = if body_str.is_empty() {
    Json::null()
  } else {
    @json.parse(body_str) catch {
      _ => {
        usage.record_bad_request_with_provider(self)
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
  usage.record_request_context("gemini", gemini_model_from_endpoint(endpoint))
  usage.record_stream_mode(gemini_request_is_stream(endpoint, request_json))
  let url = match gemini_proxy_url(endpoint) {
    Some(url) => url
    None => {
      usage.record_unauthorized_with_provider(self)
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
    Get => self.forward_gemini_get(usage, url, w)
    Post => self.forward_gemini_post(usage, url, request_json, w)
    _ => {
      usage.record_bad_request_with_provider(self)
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
async fn ProxyService::forward_gemini_get(
  self : ProxyService,
  usage : UsageService,
  url : String,
  w : @httpx.ResponseWriter,
) -> Unit {
  let result = moon_async_result(() => @http.get(url))
  match result {
    Err(error) => {
      usage.record_upstream_error_status_with_provider(
        self,
        0,
        @status.BadGateway,
      )
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadGateway)
      w.write(
        "{\"error\":{\"message\":\"Gemini upstream request failed: \{error}\",\"type\":\"upstream_error\"}}",
      )
    }
    Ok((response, data)) => {
      let response_body = data.text()
      if response.code is (200..=299) {
        usage.record_success_usage_with_provider(
          self,
          TokenUsage::empty(),
          response_body.length(),
        )
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
    }
  }
  w.flush()
}

///|
async fn ProxyService::forward_gemini_post(
  self : ProxyService,
  usage : UsageService,
  url : String,
  request_json : Json,
  w : @httpx.ResponseWriter,
) -> Unit {
  let result = moon_async_result(() => {
    @http.post(url, request_json, headers={ "Content-Type": "application/json" })
  })
  match result {
    Err(error) => {
      usage.record_upstream_error_status_with_provider(
        self,
        0,
        @status.BadGateway,
      )
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadGateway)
      w.write(
        "{\"error\":{\"message\":\"Gemini upstream request failed: \{error}\",\"type\":\"upstream_error\"}}",
      )
    }
    Ok((response, data)) => {
      let response_body = data.text()
      if response.code is (200..=299) {
        let parsed = @json.parse(response_body) catch { _ => Json::null() }
        let usage_record = token_usage_or_response_model(
          token_usage_from_gemini_response(parsed),
          parsed,
          ["modelVersion"],
        )
        usage.record_success_usage_with_provider(
          self,
          usage_record,
          response_body.length(),
        )
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
    }
  }
  w.flush()
}

///|
async fn ProxyService::post_codex_compatible_provider_json(
  self : ProxyService,
  provider : ProviderRouteTarget,
  endpoint : String,
  request : Json,
) -> Result[(@http.Response, String), String] {
  let _ = self
  let base_url = provider.base_url.unwrap()
  let api_key = provider.api_key.unwrap()
  let url = codex_compatible_provider_url(base_url, endpoint)
  let headers = codex_compatible_provider_headers(
    api_key,
    "application/json",
    provider_custom_user_agent(provider),
  )
  match moon_reject_proxy_managed_placeholder_for_upstream(url, headers) {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  let (response, data) = @http.post(url, request, headers~) catch {
    error => return Err("\{error}")
  }
  Ok((response, data.text()))
}

///|
async fn ProxyService::post_codex_compatible_provider_stream(
  self : ProxyService,
  provider : ProviderRouteTarget,
  endpoint : String,
  request : Json,
) -> Result[(@http.Client, @http.Response), String] {
  let _ = self
  let base_url = provider.base_url.unwrap()
  let api_key = provider.api_key.unwrap()
  let url = codex_compatible_provider_url(base_url, endpoint)
  let (origin, path) = split_origin_and_path(url)
  let headers = codex_compatible_provider_headers(
    api_key,
    "text/event-stream",
    provider_custom_user_agent(provider),
  )
  match moon_reject_proxy_managed_placeholder_for_upstream(url, headers) {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  let client = @http.Client::new(origin, headers~)
  let response = client.post(path, request) catch {
    error => {
      client.close()
      return Err("\{error}")
    }
  }
  Ok((client, response))
}

///|
async fn ProxyService::post_claude_compatible_provider_json(
  self : ProxyService,
  provider : ProviderRouteTarget,
  endpoint : String,
  request : Json,
  api_format : String,
  anthropic_beta : String?,
  copilot_headers? : Map[String, String] = {},
) -> Result[(@http.Response, String), String] {
  let _ = self
  let base_url = provider.base_url.unwrap()
  let api_key = provider.api_key.unwrap()
  let url = claude_compatible_provider_url(
    base_url,
    endpoint,
    api_format,
    provider.is_full_url,
  )
  let headers = claude_compatible_provider_headers(
    api_key,
    api_format,
    anthropic_beta~,
    custom_user_agent=provider_custom_user_agent(provider),
    provider_type=provider.provider_type,
    extra_headers=copilot_headers,
  )
  match moon_reject_proxy_managed_placeholder_for_upstream(url, headers) {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  let (response, data) = @http.post(url, request, headers~) catch {
    error => return Err("\{error}")
  }
  Ok((response, data.text()))
}

///|
fn claude_compatible_provider_headers(
  api_key : String,
  api_format : String,
  anthropic_beta? : String? = None,
  accept? : String = "application/json",
  custom_user_agent? : String? = None,
  provider_type? : String? = None,
  extra_headers? : Map[String, String] = {},
) -> Map[String, String] {
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "Accept": accept,
  }
  if provider_type == Some("github_copilot") {
    let request_id = moon_copilot_random_uuid()
    headers["Authorization"] = "Bearer \{api_key}"
    headers["editor-version"] = COPILOT_EDITOR_VERSION
    headers["editor-plugin-version"] = COPILOT_PLUGIN_VERSION
    headers["copilot-integration-id"] = COPILOT_INTEGRATION_ID
    headers["user-agent"] = COPILOT_USER_AGENT
    headers["x-github-api-version"] = COPILOT_API_VERSION
    headers["openai-intent"] = "conversation-agent"
    headers["x-initiator"] = "user"
    headers["x-interaction-type"] = "conversation-agent"
    headers["x-vscode-user-agent-library-version"] = "electron-fetch"
    headers["x-request-id"] = request_id
    headers["x-agent-task-id"] = request_id
  } else if provider_type == Some("gemini_cli") {
    headers["Authorization"] = "Bearer \{gemini_cli_bearer_token(api_key)}"
    headers["x-goog-api-client"] = "GeminiCLI/1.0"
  } else if provider_type == Some("openrouter") ||
    provider_type == Some("claude_auth") {
    headers["Authorization"] = "Bearer \{api_key}"
  } else {
    match api_format {
      "anthropic" => {
        headers["x-api-key"] = api_key
        headers["anthropic-version"] = "2023-06-01"
        headers["anthropic-beta"] = moon_claude_code_beta_header(anthropic_beta)
      }
      "gemini_native" => {
        headers["x-goog-api-key"] = api_key
        headers["x-goog-api-client"] = "GeminiCLI/1.0"
      }
      _ => headers["Authorization"] = "Bearer \{api_key}"
    }
  }
  match custom_user_agent {
    Some(value) => headers["User-Agent"] = value
    None => ()
  }
  for key, value in extra_headers {
    headers[key] = value
  }
  headers
}

///|
fn codex_compatible_provider_headers(
  api_key : String,
  accept : String,
  custom_user_agent : String?,
) -> Map[String, String] {
  let headers : Map[String, String] = {
    "Authorization": "Bearer \{api_key}",
    "Content-Type": "application/json",
    "Accept": accept,
  }
  match custom_user_agent {
    Some(value) => headers["User-Agent"] = value
    None => ()
  }
  headers
}

///|
fn provider_custom_user_agent(provider : ProviderRouteTarget) -> String? {
  if provider.provider_type == Some("official") {
    return None
  }
  guard provider.settings_config is Some(Object(obj)) else { return None }
  match parse_custom_user_agent(json_string_from_map(obj, "customUserAgent")) {
    Some(value) => return Some(value)
    None => ()
  }
  match obj.get("meta") {
    Some(Object(meta)) =>
      parse_custom_user_agent(json_string_from_map(meta, "customUserAgent"))
    _ => None
  }
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
  let path = match base_url.find("?") {
    Some(index) => base_url[:index]
    None => base_url[:]
  }
  path.has_suffix("/responses") ||
  path.has_suffix("/chat/completions") ||
  path.has_suffix("/messages")
}

///|
fn codex_provider_from_env() -> ProviderRouteTarget? {
  guard env_first_non_empty(["MOONSTAT_CODEX_BASE_URL"]) is Some(base_url) else {
    return None
  }
  guard env_first_non_empty(["MOONSTAT_CODEX_API_KEY"]) is Some(api_key) else {
    return None
  }
  Some(
    ProviderRouteTarget::new(
      app_type="codex",
      provider_id=env_first_non_empty(["MOONSTAT_CODEX_PROVIDER_ID"]).unwrap_or(
        "codex-compatible",
      ),
      provider_name=env_first_non_empty(["MOONSTAT_CODEX_PROVIDER_NAME"]).unwrap_or(
        "Codex Compatible",
      ),
      provider_type=Some(
        env_first_non_empty(["MOONSTAT_CODEX_PROVIDER_TYPE"]).unwrap_or("codex"),
      ),
      base_url=Some(base_url),
      api_key=Some(api_key),
      api_format=env_first_non_empty(["MOONSTAT_CODEX_API_FORMAT"]),
      is_full_url=codex_base_is_full_url(),
      settings_config=provider_settings_config_from_env(
        "MOONSTAT_CODEX_SETTINGS_CONFIG",
      ),
    ),
  )
}

///|
fn claude_provider_from_env(app_type : String) -> ProviderRouteTarget? {
  guard env_first_non_empty(["MOONSTAT_CLAUDE_BASE_URL"]) is Some(base_url) else {
    return None
  }
  guard env_first_non_empty(["MOONSTAT_CLAUDE_API_KEY"]) is Some(api_key) else {
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
      provider_id=env_first_non_empty(["MOONSTAT_CLAUDE_PROVIDER_ID"]).unwrap_or(
        "\{provider_id_prefix}-compatible",
      ),
      provider_name=env_first_non_empty(["MOONSTAT_CLAUDE_PROVIDER_NAME"]).unwrap_or(
        "Claude Compatible",
      ),
      provider_type=Some(
        env_first_non_empty(["MOONSTAT_CLAUDE_PROVIDER_TYPE"]).unwrap_or(
          "anthropic",
        ),
      ),
      api_format=Some(
        env_first_non_empty(["MOONSTAT_CLAUDE_API_FORMAT"]).unwrap_or(
          "anthropic",
        ),
      ),
      prompt_cache_key=env_first_non_empty(["MOONSTAT_CLAUDE_PROMPT_CACHE_KEY"]),
      codex_fast_mode=env_bool("MOONSTAT_CODEX_FAST_MODE"),
      base_url=Some(base_url),
      api_key=Some(api_key),
      is_full_url=claude_base_is_full_url(),
      model_mapping=moon_model_mapping_from_env(),
      settings_config=provider_settings_config_from_env(
        "MOONSTAT_CLAUDE_SETTINGS_CONFIG",
      ),
    ),
  )
}

///|
fn provider_settings_config_from_env(key : String) -> Json? {
  match env_first_non_empty([key]) {
    Some(raw) => Some(@json.parse(raw)) catch { _ => None }
    None => None
  }
}

///|
async fn ProxyService::handle_get_current_omo_provider_id(
  self : ProxyService,
  w : @httpx.ResponseWriter,
  slim~ : Bool,
) -> Unit {
  write_usage_json(w, Json::string(self.current_omo_provider_id(slim)))
}

///|
async fn ProxyService::handle_get_providers(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  write_usage_json(w, self.provider_router.providers_moon_json(app_type))
}

///|
async fn ProxyService::handle_get_current_provider(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  write_usage_json(
    w,
    Json::string(
      self.provider_router.current_provider_for_moon_command(app_type),
    ),
  )
}

///|
async fn ProxyService::handle_add_provider(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  usage : UsageService,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard provider_target_from_request(r.path, body, app_type) is Some(target) else {
    write_usage_bad_request(w, "invalid_provider")
    return
  }
  let add_to_live = provider_bool_from_request(r.path, body, [
    "addToLive", "add_to_live",
  ]).unwrap_or(true)
  self.add_provider_target(usage, app_type, target, add_to_live)
  write_usage_json(w, Json::boolean(true))
}

///|
fn ProxyService::add_provider_target(
  self : ProxyService,
  usage : UsageService,
  app_type : String,
  target : ProviderRouteTarget,
  add_to_live : Bool,
) -> Unit {
  ignore(add_to_live)
  let provider_id = target.provider_id
  usage.sync_provider_limits_from_target(target)
  self.provider_router.upsert_provider(target)
  if !provider_app_is_additive(app_type) {
    if self.provider_router.current_provider_id(app_type) is None {
      self.provider_router.set_current_provider(app_type, provider_id)
    }
  }
}

///|
async fn ProxyService::handle_update_provider(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  usage : UsageService,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard provider_target_from_request(r.path, body, app_type) is Some(target) else {
    write_usage_bad_request(w, "invalid_provider")
    return
  }
  let original_id = provider_string_from_request(r.path, body, [
    "originalId", "original_id",
  ])
  match self.update_provider_target(usage, app_type, target, original_id) {
    Ok(_) => write_usage_json(w, Json::boolean(true))
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
fn ProxyService::update_provider_target(
  self : ProxyService,
  usage : UsageService,
  app_type : String,
  target : ProviderRouteTarget,
  original_id : String?,
) -> Result[Unit, String] {
  let provider_id = target.provider_id
  let original_provider_id = original_id.unwrap_or(provider_id)
  let was_current = self.provider_router.current_provider_id(app_type) ==
    Some(original_provider_id)
  if original_provider_id != provider_id {
    if !provider_app_is_additive(app_type) {
      return Err("Only additive-mode providers support changing provider key")
    }
    if self.provider_router.provider_by_id(app_type, original_provider_id)
      is None {
      return Err(
        "Original provider '\{original_provider_id}' does not exist in app '\{app_type}'",
      )
    }
    if self.provider_router.provider_by_id(app_type, provider_id) is Some(_) {
      return Err(
        "Provider '\{provider_id}' already exists in app '\{app_type}'",
      )
    }
    ignore(self.provider_router.delete_provider(app_type, original_provider_id))
  }
  usage.sync_provider_limits_from_target(target)
  self.provider_router.upsert_provider(target)
  if was_current {
    self.provider_router.set_current_provider(app_type, provider_id)
  }
  Ok(())
}

///|
async fn ProxyService::handle_delete_provider(
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
  if !self.provider_router.delete_provider(app_type, provider_id) {
    write_usage_bad_request(w, "provider_not_found")
    return
  }
  write_usage_json(w, Json::boolean(true))
}

///|
async fn ProxyService::handle_remove_provider_from_live_config(
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
  if !self.provider_router.remove_provider_from_live_config(
      app_type, provider_id,
    ) {
    write_usage_bad_request(w, "provider_not_found")
    return
  }
  write_usage_json(w, Json::boolean(true))
}

///|
async fn ProxyService::handle_switch_provider(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  usage : UsageService,
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
  guard self.provider_router.provider_by_id(app_type, provider_id)
    is Some(provider) else {
    write_usage_bad_request(w, "provider_not_found")
    return
  }
  self.provider_router.set_current_provider(app_type, provider_id)
  usage.set_active_target(
    app_type,
    provider.provider_id,
    provider.provider_name,
  )
  write_usage_json(w, { "warnings": Json::array([]) }.to_json())
}

///|
async fn ProxyService::handle_open_provider_terminal(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard proxy_string_request(r.path, body, "providerId") is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  let cwd = proxy_string_request(r.path, body, "cwd")
  match
    moon_open_provider_terminal_json(
      self.provider_router,
      app_type,
      provider_id,
      cwd,
    ) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
fn ProxyService::current_claude_desktop_provider(
  self : ProxyService,
) -> ProviderRouteTarget? {
  match self.provider_router.current_provider_id("claude-desktop") {
    Some(provider_id) =>
      self.provider_router.provider_by_id("claude-desktop", provider_id)
    None => None
  }
}

///|
async fn ProxyService::handle_import_claude_desktop_providers_from_claude(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    Json::number(self.import_claude_desktop_providers_from_claude().to_double()),
  )
}

///|
async fn ProxyService::handle_ensure_claude_desktop_official_provider(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    Json::boolean(self.ensure_claude_desktop_official_provider()),
  )
}

///|
fn ProxyService::ensure_claude_desktop_official_provider(
  self : ProxyService,
) -> Bool {
  if self.provider_router.provider_by_id("claude-desktop", "codex-oauth")
    is Some(_) {
    return false
  }
  self.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="claude-desktop",
      provider_id="codex-oauth",
      provider_name="Codex OAuth",
      provider_type=Some("codex_oauth"),
      model_mapping=moon_model_mapping_from_env(),
    ),
  )
  if self.provider_router.current_provider_id("claude-desktop") is None {
    self.provider_router.set_current_provider("claude-desktop", "codex-oauth")
  }
  true
}

///|
fn ProxyService::import_claude_desktop_providers_from_claude(
  self : ProxyService,
) -> Int {
  ignore(self.ensure_claude_desktop_official_provider())
  let mut imported = 0
  guard self.provider_router.providers.get("claude") is Some(claude_providers) else {
    return imported
  }
  for provider in claude_providers.values() {
    if self.provider_router.provider_by_id(
        "claude-desktop",
        provider.provider_id,
      )
      is Some(_) {
      continue
    }
    let import_decision = if provider.is_compatible_claude_desktop_direct_provider() &&
      claude_provider_models_are_claude_safe(provider) {
      Some(("direct", provider.claude_desktop_model_routes))
    } else {
      match suggested_claude_desktop_routes(provider) {
        Some(routes) => Some(("proxy", routes))
        None => None
      }
    }
    guard import_decision is Some((import_mode, claude_desktop_model_routes)) else {
      continue
    }
    self.provider_router.upsert_provider(
      ProviderRouteTarget::new(
        app_type="claude-desktop",
        provider_id=provider.provider_id,
        provider_name=provider.provider_name,
        enabled=provider.enabled,
        provider_type=provider.provider_type,
        api_format=provider.api_format,
        claude_desktop_mode=Some(import_mode),
        prompt_cache_key=provider.prompt_cache_key,
        codex_fast_mode=provider.codex_fast_mode,
        base_url=provider.base_url,
        api_key=provider.api_key,
        is_full_url=provider.is_full_url,
        model_mapping=provider.model_mapping,
        claude_desktop_model_routes~,
        settings_config=provider.settings_config,
      ),
    )
    imported += 1
  }
  if self.provider_router.current_provider_id("claude-desktop") is None {
    match self.provider_router.current_provider_id("claude") {
      Some(provider_id) =>
        if self.provider_router.provider_by_id("claude-desktop", provider_id)
          is Some(_) {
          self.provider_router.set_current_provider(
            "claude-desktop", provider_id,
          )
        }
      None => ()
    }
  }
  imported
}

///|
fn claude_provider_models_are_claude_safe(
  provider : ProviderRouteTarget,
) -> Bool {
  match provider.settings_config {
    Some(Object(obj)) =>
      match obj.get("env") {
        Some(Object(env)) => {
          for
            key in [
              "ANTHROPIC_MODEL", "ANTHROPIC_DEFAULT_HAIKU_MODEL", "ANTHROPIC_DEFAULT_SONNET_MODEL",
              "ANTHROPIC_DEFAULT_OPUS_MODEL",
            ] {
            match json_non_empty_string_from_map(env, key) {
              Some(model) if !is_claude_safe_model_id(model) => return false
              _ => ()
            }
          }
          true
        }
        _ => true
      }
    _ => true
  }
}

///|
async fn ProxyService::handle_sync_current_providers_live(
  self : ProxyService,
  usage : UsageService,
  w : @httpx.ResponseWriter,
) -> Unit {
  let targets = self.provider_router.sync_current_provider_targets()
  for target in targets {
    usage.set_active_target(
      target.app_type,
      target.provider_id,
      target.provider_name,
    )
  }
  write_usage_json(
    w,
    {
      "success": Json::boolean(true),
      "message": Json::string("Live configuration synchronized"),
    }.to_json(),
  )
}

///|
async fn ProxyService::handle_read_live_provider_settings(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  write_usage_json(
    w,
    self.provider_router.read_live_provider_settings(app_type),
  )
}

///|
async fn ProxyService::handle_get_live_provider_ids(
  self : ProxyService,
  w : @httpx.ResponseWriter,
  app_type : String,
) -> Unit {
  write_usage_json(w, self.provider_router.live_provider_ids_json(app_type))
}

///|
async fn ProxyService::handle_get_live_provider(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  app_type : String,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_id_from_request(r.path, body) is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  write_usage_json(
    w,
    self.provider_router.live_provider_json(app_type, provider_id),
  )
}

///|
async fn ProxyService::handle_import_live_providers(
  self : ProxyService,
  w : @httpx.ResponseWriter,
  app_type : String,
) -> Unit {
  write_usage_json(
    w,
    Json::number(
      self.provider_router.import_live_providers(app_type).to_double(),
    ),
  )
}

///|
async fn ProxyService::handle_get_universal_providers(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.provider_router.universal_providers_json())
}

///|
async fn ProxyService::handle_get_universal_provider(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_id_from_request(r.path, body) is Some(id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  write_usage_json(w, self.provider_router.universal_provider_json(id))
}

///|
async fn ProxyService::handle_upsert_universal_provider(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard universal_provider_from_request(r.path, body) is Some(provider) else {
    write_usage_bad_request(w, "invalid_universal_provider")
    return
  }
  write_usage_json(
    w,
    Json::boolean(self.provider_router.upsert_universal_provider(provider)),
  )
}

///|
async fn ProxyService::handle_delete_universal_provider(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_id_from_request(r.path, body) is Some(id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  write_usage_json(
    w,
    Json::boolean(self.provider_router.delete_universal_provider(id)),
  )
}

///|
async fn ProxyService::handle_sync_universal_provider(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_id_from_request(r.path, body) is Some(id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  write_usage_json(
    w,
    Json::boolean(self.provider_router.sync_universal_provider(id)),
  )
}

///|
async fn ProxyService::handle_get_provider_presets(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_provider_presets_json(r.path))
}

///|
async fn ProxyService::handle_update_providers_sort_order(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  let updates = provider_sort_updates_from_request(r.path, body)
  write_usage_json(
    w,
    Json::boolean(
      self.provider_router.update_providers_sort_order(app_type, updates),
    ),
  )
}

///|
async fn ProxyService::handle_stream_check_provider(
  self : ProxyService,
  stream_check_config : StreamCheckConfig,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard stream_check_provider_from_request(r.path, body)
    is Some((app_type, provider_id)) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  guard self.stream_check_provider_result_json(
      stream_check_config, app_type, provider_id,
    )
    is Some(result) else {
    write_usage_bad_request(w, "provider_not_found")
    return
  }
  write_usage_json(w, result)
}

///|
async fn ProxyService::handle_stream_check_all_providers(
  self : ProxyService,
  stream_check_config : StreamCheckConfig,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_app_type_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  let proxy_targets_only = proxy_bool_request(r.path, body, "proxyTargetsOnly").unwrap_or(
    false,
  )
  let rows : Array[Json] = []
  for
    provider_id in self.provider_router.stream_check_provider_ids(
      app_type, proxy_targets_only,
    ) {
    guard self.stream_check_provider_result_json(
        stream_check_config, app_type, provider_id,
      )
      is Some(result) else {
      continue
    }
    rows.push(Json::array([Json::string(provider_id), result]))
  }
  write_usage_json(w, Json::array(rows))
}

///|
fn ProxyService::stream_check_provider_result_json(
  self : ProxyService,
  stream_check_config : StreamCheckConfig,
  app_type : String,
  provider_id : String,
) -> Json? {
  guard self.provider_router.provider_by_id(app_type, provider_id)
    is Some(provider) else {
    return None
  }
  let config = stream_check_effective_config_for_provider(
    stream_check_config, provider,
  )
  let model = stream_check_reported_model_for_app(config, app_type)
  let configured = true
  let status = if configured { "operational" } else { "failed" }
  let message = if configured {
    "Check succeeded"
  } else {
    "Provider has no standalone endpoint configuration"
  }
  let obj : Map[String, Json] = {
    "status": Json::string(status),
    "success": Json::boolean(configured),
    "message": Json::string(message),
    "modelUsed": Json::string(model),
    "testedAt": Json::number((@async.now().to_int() / 1000).to_double()),
    "retryCount": Json::number(0.0),
  }
  if configured {
    obj["responseTimeMs"] = Json::number(0.0)
    obj["httpStatus"] = Json::number(200.0)
  }
  Some(Json::object(obj))
}

///|
fn stream_check_effective_config_for_provider(
  global_config : StreamCheckConfig,
  provider : ProviderRouteTarget,
) -> StreamCheckConfig {
  guard provider.settings_config is Some(Object(settings)) else {
    return global_config
  }
  guard settings.get("meta") is Some(Object(meta)) else { return global_config }
  guard meta.get("testConfig") is Some(Object(test_config)) else {
    return global_config
  }
  if !json_bool_from_map(test_config, "enabled").unwrap_or(false) {
    return global_config
  }
  let mut config = global_config
  match json_string_from_map(test_config, "testModel") {
    Some(model) =>
      config = {
        ..config,
        claude_model: model,
        codex_model: model,
        gemini_model: model,
      }
    None => ()
  }
  match proxy_json_int(test_config, "timeoutSecs") {
    Some(value) if value >= 0 => config = { ..config, timeout_secs: value }
    _ => ()
  }
  match proxy_json_int(test_config, "maxRetries") {
    Some(value) if value >= 0 => config = { ..config, max_retries: value }
    _ => ()
  }
  match proxy_json_int(test_config, "degradedThresholdMs") {
    Some(value) if value >= 0 =>
      config = { ..config, degraded_threshold_ms: value }
    _ => ()
  }
  match json_string_from_map(test_config, "testPrompt") {
    Some(prompt) => config = { ..config, test_prompt: prompt }
    None => ()
  }
  config
}

///|
fn stream_check_provider_from_request(
  path : StringView,
  body : Json?,
) -> (String, String)? {
  let app_type = match usage_query_value(path, "appType") {
    Some(value) => Some(value)
    None => proxy_string_request(path, body, "appType")
  }
  guard app_type is Some(app_type) else { return None }
  let provider_id = match usage_query_value(path, "providerId") {
    Some(value) => Some(value)
    None => proxy_string_request(path, body, "providerId")
  }
  guard provider_id is Some(provider_id) else { return None }
  Some((app_type, provider_id))
}

///|
fn provider_app_from_request(path : StringView, body : Json?) -> String? {
  provider_string_from_request(path, body, ["appType"])
}

///|
fn provider_id_from_request(path : StringView, body : Json?) -> String? {
  provider_string_from_request(path, body, ["id", "providerId"])
}

///|
fn provider_url_from_request(path : StringView, body : Json?) -> String? {
  provider_string_from_request(path, body, ["url"])
}

///|
fn provider_string_from_request(
  path : StringView,
  body : Json?,
  keys : Array[String],
) -> String? {
  match proxy_string_request_any(path, body, keys) {
    Some(value) => return Some(value)
    None => ()
  }
  match provider_body_payload(body) {
    Some(payload) => proxy_string_request_any(path, Some(payload), keys)
    None => None
  }
}

///|
fn provider_bool_from_request(
  path : StringView,
  body : Json?,
  keys : Array[String],
) -> Bool? {
  match proxy_bool_request_any(path, body, keys) {
    Some(value) => return Some(value)
    None => ()
  }
  match provider_body_payload(body) {
    Some(payload) => proxy_bool_request_any(path, Some(payload), keys)
    None => None
  }
}

///|
fn provider_body_payload(body : Json?) -> Json? {
  match body {
    Some(Object(obj)) =>
      match obj.get("provider") {
        Some(Object(provider)) => Some(Json::object(provider))
        _ => body
      }
    _ => body
  }
}

///|
fn provider_settings_config_from_body(body : Json?) -> Json? {
  guard provider_body_payload(body) is Some(Object(obj)) else { return None }
  match obj.get("settingsConfig") {
    Some(settings) =>
      Some(provider_settings_config_with_inline_metadata(settings, obj))
    None => provider_inline_settings_config(obj)
  }
}

///|
fn provider_settings_config_with_inline_metadata(
  settings : Json,
  obj : Map[String, Json],
) -> Json {
  guard settings is Object(settings_obj) else { return settings }
  let merged : Map[String, Json] = {}
  for key in settings_obj.keys() {
    match settings_obj.get(key) {
      Some(value) => merged[key] = value
      None => ()
    }
  }
  provider_copy_inline_metadata_fields(merged, obj)
  Json::object(merged)
}

///|
fn provider_type_normalize(value : String) -> String {
  value.trim().to_owned().to_lower().replace_all(old="-", new="_")
}

///|
fn provider_resolved_provider_type(
  app_type : String,
  explicit_type : String?,
  api_format : String?,
  base_url : String?,
  api_key : String?,
) -> String? {
  match explicit_type {
    Some(value) if !value.trim().is_empty() =>
      return Some(provider_type_normalize(value))
    _ => ()
  }
  match app_type {
    "claude" | "claude-desktop" => {
      if api_format == Some("gemini_native") {
        return Some(provider_gemini_key_provider_type(api_key))
      }
      match base_url {
        Some(url) => {
          let normalized_url = url.to_lower()
          if normalized_url.contains("githubcopilot.com") {
            return Some("github_copilot")
          }
          if normalized_url.contains("openrouter.ai") {
            return Some("openrouter")
          }
        }
        None => ()
      }
      None
    }
    "gemini" => Some(provider_gemini_key_provider_type(api_key))
    _ => None
  }
}

///|
fn provider_gemini_key_provider_type(api_key : String?) -> String {
  match api_key {
    Some(key) => {
      let trimmed = key.trim()
      if trimmed.has_prefix("ya29.") || trimmed.has_prefix("{") {
        "gemini_cli"
      } else {
        "gemini"
      }
    }
    None => "gemini"
  }
}

///|
fn UsageService::sync_provider_limits_from_target(
  self : UsageService,
  target : ProviderRouteTarget,
) -> Unit {
  guard provider_limit_config_from_settings(target.settings_config)
    is Some(config) else {
    return
  }
  self.set_provider_limits(
    target.provider_id,
    target.app_type,
    daily_limit_usd=config.daily_limit_usd,
    monthly_limit_usd=config.monthly_limit_usd,
  )
}

///|
fn provider_limit_config_from_settings(
  settings : Json?,
) -> ProviderLimitConfig? {
  guard settings is Some(Object(obj)) else { return None }
  let daily = provider_limit_string_from_settings(obj, ["limitDailyUsd"])
  let monthly = provider_limit_string_from_settings(obj, ["limitMonthlyUsd"])
  if daily is None && monthly is None {
    None
  } else {
    Some(
      ProviderLimitConfig::new(daily_limit_usd=daily, monthly_limit_usd=monthly),
    )
  }
}

///|
fn provider_limit_string_from_settings(
  obj : Map[String, Json],
  keys : Array[String],
) -> String? {
  json_non_empty_string_from_map_any(obj, keys)
}

///|
fn provider_inline_settings_config(obj : Map[String, Json]) -> Json? {
  let settings : Map[String, Json] = {}
  provider_copy_inline_metadata_fields(settings, obj)
  if settings.is_empty() {
    None
  } else {
    Some(Json::object(settings))
  }
}

///|
fn provider_copy_inline_metadata_fields(
  settings : Map[String, Json],
  obj : Map[String, Json],
) -> Unit {
  for
    key in [
      "customUserAgent", "apiFormat", "promptCacheKey", "codexFastMode", "githubAccountId",
      "limitDailyUsd", "limitMonthlyUsd",
    ] {
    match obj.get(key) {
      Some(value) => settings[key] = value
      None => ()
    }
  }
  match obj.get("meta") {
    Some(meta) =>
      settings["meta"] = provider_merge_inline_meta(settings.get("meta"), meta)
    None => ()
  }
}

///|
fn provider_merge_inline_meta(existing : Json?, incoming : Json) -> Json {
  match (existing, incoming) {
    (Some(Object(existing_obj)), Object(incoming_obj)) => {
      let merged : Map[String, Json] = {}
      for key in existing_obj.keys() {
        match existing_obj.get(key) {
          Some(value) => merged[key] = value
          None => ()
        }
      }
      for key in incoming_obj.keys() {
        match incoming_obj.get(key) {
          Some(value) => merged[key] = value
          None => ()
        }
      }
      Json::object(merged)
    }
    (_, value) => value
  }
}

///|
fn universal_provider_from_request(path : StringView, body : Json?) -> Json? {
  match provider_body_payload(body) {
    Some(Object(obj)) =>
      if json_string_from_map(obj, "id") is Some(id) && !id.trim().is_empty() {
        return Some(Json::object(obj))
      }
    _ => ()
  }
  guard provider_id_from_request(path, body) is Some(id) &&
    !id.trim().is_empty() else {
    return None
  }
  let provider : Map[String, Json] = {
    "id": Json::string(id.trim().to_owned()),
    "name": Json::string(
      provider_string_from_request(path, body, ["name"]).unwrap_or(id),
    ),
    "providerType": Json::string(
      provider_string_from_request(path, body, ["providerType"]).unwrap_or(
        "custom",
      ),
    ),
    "apps": universal_provider_apps_from_request(path, body),
    "models": universal_provider_models_from_request(path, body),
  }
  match provider_string_from_request(path, body, ["baseUrl"]) {
    Some(value) => provider["baseUrl"] = Json::string(value)
    None => ()
  }
  match provider_string_from_request(path, body, ["apiKey"]) {
    Some(value) => provider["apiKey"] = Json::string(value)
    None => ()
  }
  Some(Json::object(provider))
}

///|
fn universal_provider_apps_from_request(
  path : StringView,
  body : Json?,
) -> Json {
  let apps_value = provider_string_from_request(path, body, ["apps"]).unwrap_or(
    "claude,codex,gemini",
  )
  let enabled = universal_provider_enabled_apps(apps_value)
  {
    "claude": Json::boolean(enabled.contains("claude")),
    "codex": Json::boolean(enabled.contains("codex")),
    "gemini": Json::boolean(enabled.contains("gemini")),
  }.to_json()
}

///|
fn universal_provider_enabled_apps(apps_value : String) -> Array[String] {
  let enabled : Array[String] = []
  for raw in apps_value.split(",") {
    let app = raw.trim().to_lower().to_owned()
    if app == "all" {
      return ["claude", "codex", "gemini"]
    }
    if (app == "claude" || app == "codex" || app == "gemini") &&
      !enabled.contains(app) {
      enabled.push(app)
    }
  }
  enabled
}

///|
fn universal_provider_models_from_request(
  path : StringView,
  body : Json?,
) -> Json {
  let models : Map[String, Json] = {}
  match provider_string_from_request(path, body, ["claudeModel"]) {
    Some(model) => models["claude"] = { "model": Json::string(model) }.to_json()
    None => ()
  }
  let codex : Map[String, Json] = {}
  match provider_string_from_request(path, body, ["codexModel"]) {
    Some(model) => codex["model"] = Json::string(model)
    None => ()
  }
  match provider_string_from_request(path, body, ["reasoningEffort"]) {
    Some(value) => codex["reasoningEffort"] = Json::string(value)
    None => ()
  }
  if !codex.is_empty() {
    models["codex"] = Json::object(codex)
  }
  match provider_string_from_request(path, body, ["geminiModel"]) {
    Some(model) => models["gemini"] = { "model": Json::string(model) }.to_json()
    None => ()
  }
  Json::object(models)
}

///|
fn provider_target_from_request(
  path : StringView,
  body : Json?,
  app_type : String,
) -> ProviderRouteTarget? {
  guard provider_id_from_request(path, body) is Some(provider_id) else {
    return None
  }
  let provider_name = provider_string_from_request(path, body, ["name"]).unwrap_or(
    provider_id,
  )
  let enabled = provider_bool_from_request(path, body, ["enabled"]).unwrap_or(
    true,
  )
  let settings_config = provider_settings_config_from_body(body)
  let explicit_provider_type = provider_string_from_request(path, body, [
    "providerType",
  ])
  let api_format = provider_string_from_request(path, body, ["apiFormat"])
  let base_url = provider_string_from_request(path, body, ["baseUrl"])
  let api_key = provider_string_from_request(path, body, ["apiKey"])
  let provider_type = provider_resolved_provider_type(
    app_type, explicit_provider_type, api_format, base_url, api_key,
  )
  let prompt_cache_key = provider_string_from_request(path, body, [
    "promptCacheKey",
  ])
  let codex_fast_mode = provider_bool_from_request(path, body, ["codexFastMode"]).unwrap_or(
    false,
  )
  let notes = provider_string_from_request(path, body, ["notes"])
  let is_full_url = provider_bool_from_request(path, body, ["isFullUrl"]).unwrap_or(
    false,
  )
  let model_mapping = provider_model_mapping_from_request(path, body)
  let claude_desktop_model_routes = provider_claude_desktop_model_routes_from_body(
    body,
  )
  let claude_desktop_mode = provider_claude_desktop_mode_from_body(body)
  Some(
    ProviderRouteTarget::new(
      app_type~,
      provider_id~,
      provider_name~,
      enabled~,
      provider_type~,
      api_format~,
      claude_desktop_mode~,
      prompt_cache_key~,
      codex_fast_mode~,
      base_url~,
      api_key~,
      is_full_url~,
      model_mapping~,
      claude_desktop_model_routes~,
      settings_config~,
      notes~,
    ),
  )
}

///|
fn provider_claude_desktop_mode_from_body(body : Json?) -> String? {
  guard provider_body_payload(body) is Some(Object(obj)) else { return None }
  match json_non_empty_string_from_map(obj, "claudeDesktopMode") {
    Some(mode) => normalize_claude_desktop_mode(mode)
    None => None
  }
}

///|
fn provider_model_mapping_from_request(
  path : StringView,
  body : Json?,
) -> ModelMapping? {
  match provider_body_payload(body) {
    Some(Object(obj)) =>
      match obj.get("modelMapping") {
        Some(Object(mapping_obj)) =>
          return provider_model_mapping_from_json(mapping_obj)
        _ => ()
      }
    _ => ()
  }
  let mapping = ModelMapping::new(
    haiku_model=provider_string_from_request(path, body, ["haikuModel"]),
    sonnet_model=provider_string_from_request(path, body, ["sonnetModel"]),
    opus_model=provider_string_from_request(path, body, ["opusModel"]),
    default_model=provider_string_from_request(path, body, ["defaultModel"]),
  )
  if mapping.has_mapping() {
    Some(mapping)
  } else {
    None
  }
}

///|
fn provider_model_mapping_from_json(obj : Map[String, Json]) -> ModelMapping? {
  let mapping = ModelMapping::new(
    haiku_model=json_string_from_map(obj, "haikuModel"),
    sonnet_model=json_string_from_map(obj, "sonnetModel"),
    opus_model=json_string_from_map(obj, "opusModel"),
    default_model=json_string_from_map(obj, "defaultModel"),
  )
  if mapping.has_mapping() {
    Some(mapping)
  } else {
    None
  }
}

///|
fn provider_claude_desktop_model_routes_from_body(
  body : Json?,
) -> Map[String, ClaudeDesktopModelRoute] {
  let routes : Map[String, ClaudeDesktopModelRoute] = Map([], capacity=0)
  guard provider_body_payload(body) is Some(Object(obj)) else { return routes }
  match provider_claude_desktop_routes_object(obj) {
    Some(route_obj) => provider_add_claude_desktop_routes(routes, route_obj)
    None => ()
  }
  routes
}

///|
fn provider_claude_desktop_routes_object(
  obj : Map[String, Json],
) -> Map[String, Json]? {
  match obj.get("claudeDesktopModelRoutes") {
    Some(Object(routes)) => Some(routes)
    _ => None
  }
}

///|
fn provider_add_claude_desktop_routes(
  routes : Map[String, ClaudeDesktopModelRoute],
  obj : Map[String, Json],
) -> Unit {
  for route_id in obj.keys() {
    let trimmed_route_id = route_id.trim().to_owned()
    if trimmed_route_id.is_empty() {
      continue
    }
    match obj.get(route_id) {
      Some(route_json) =>
        match provider_claude_desktop_route_from_json(route_json) {
          Some(route) => routes[trimmed_route_id] = route
          None => ()
        }
      None => ()
    }
  }
}

///|
fn provider_claude_desktop_route_from_json(
  json : Json,
) -> ClaudeDesktopModelRoute? {
  match json {
    String(model) => {
      let trimmed = model.trim().to_owned()
      if trimmed.is_empty() {
        None
      } else {
        Some(ClaudeDesktopModelRoute::new(model=trimmed))
      }
    }
    Object(obj) => {
      guard json_string_from_map(obj, "model") is Some(model) else {
        return None
      }
      let trimmed = model.trim().to_owned()
      if trimmed.is_empty() {
        return None
      }
      Some(
        ClaudeDesktopModelRoute::new(
          model=trimmed,
          label_override=json_string_from_map(obj, "labelOverride"),
          supports_1m=json_bool_from_map(obj, "supports1m"),
        ),
      )
    }
    _ => None
  }
}

///|
fn provider_sort_updates_from_request(
  path : StringView,
  body : Json?,
) -> Array[ProviderSortUpdate] {
  let updates : Array[ProviderSortUpdate] = []
  match provider_sort_updates_from_json(body) {
    Some(parsed) => return parsed
    None => ()
  }
  guard provider_id_from_request(path, body) is Some(id) else { return updates }
  let sort_index = proxy_int_request(path, body, "sortIndex").unwrap_or(0)
  updates.push({ id, sort_index })
  updates
}

///|
fn provider_sort_updates_from_json(body : Json?) -> Array[ProviderSortUpdate]? {
  match body {
    Some(Array(items)) => Some(provider_sort_updates_from_array(items))
    Some(Object(obj)) =>
      match obj.get("updates") {
        Some(Array(items)) => Some(provider_sort_updates_from_array(items))
        _ => None
      }
    _ => None
  }
}

///|
fn provider_sort_updates_from_array(
  items : Array[Json],
) -> Array[ProviderSortUpdate] {
  let updates : Array[ProviderSortUpdate] = []
  for item in items {
    guard item is Object(obj) else { continue }
    guard json_string_from_map(obj, "id") is Some(id) else { continue }
    let sort_index = match obj.get("sortIndex") {
      Some(Number(value, ..)) => value.trunc().to_int()
      Some(String(value)) =>
        try @string.parse_int(value, base=10) catch {
          _ => 0
        } noraise {
          parsed => parsed
        }
      _ => 0
    }
    updates.push({ id, sort_index })
  }
  updates
}

///|
fn provider_endpoint_urls_from_request(
  path : StringView,
  body : Json?,
) -> Array[String] {
  match provider_endpoint_urls_from_json(body) {
    Some(urls) => return urls
    None => ()
  }
  match usage_query_value(path, "urls") {
    Some(urls) => return split_endpoint_urls(urls)
    None => ()
  }
  match usage_query_value(path, "url") {
    Some(url) => [url]
    None => []
  }
}

///|
fn provider_endpoint_urls_from_json(body : Json?) -> Array[String]? {
  match body {
    Some(Array(items)) => Some(provider_endpoint_urls_from_array(items))
    Some(Object(obj)) =>
      match obj.get("urls") {
        Some(Array(items)) => Some(provider_endpoint_urls_from_array(items))
        Some(String(urls)) => Some(split_endpoint_urls(urls))
        _ =>
          match obj.get("url") {
            Some(String(url)) => Some([url])
            _ => None
          }
      }
    _ => None
  }
}

///|
fn provider_endpoint_urls_from_array(items : Array[Json]) -> Array[String] {
  let urls : Array[String] = []
  for item in items {
    if item is String(url) {
      urls.push(url)
    }
  }
  urls
}

///|
fn provider_endpoint_latency_results_json(
  urls : Array[String],
  timeout_secs : Int,
) -> Json {
  ignore(timeout_secs)
  Json::array(urls.map(provider_endpoint_latency_result_json))
}

///|
fn provider_endpoint_latency_result_json(raw_url : String) -> Json {
  let trimmed = raw_url.trim().to_owned()
  if trimmed.is_empty() {
    return {
      "url": Json::string(raw_url),
      "latency": Json::null(),
      "status": Json::null(),
      "error": Json::string("URL 不能为空"),
    }.to_json()
  }
  if !(trimmed.has_prefix("http://") || trimmed.has_prefix("https://")) {
    return {
      "url": Json::string(trimmed),
      "latency": Json::null(),
      "status": Json::null(),
      "error": Json::string(moon_endpoint_invalid_url_error(trimmed)),
    }.to_json()
  }
  if moon_endpoint_url_missing_host(trimmed) {
    return {
      "url": Json::string(trimmed),
      "latency": Json::null(),
      "status": Json::null(),
      "error": Json::string(moon_endpoint_invalid_url_error(trimmed)),
    }.to_json()
  }
  {
    "url": Json::string(trimmed),
    "latency": Json::number(0.0),
    "status": Json::number(200.0),
    "error": Json::null(),
  }.to_json()
}

///|
fn ProxyService::selected_provider_chain(
  self : ProxyService,
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
fn ProxyService::claude_provider_outbound_body(
  _self : ProxyService,
  gemini_shadow : GeminiShadowStore,
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
      gemini_shadow_turns=gemini_shadow.session_turns(
        provider.provider_id,
        session_id,
      ),
    )
  } else {
    upstream_body
  }
}

///|
fn provider_media_heuristic_enabled(provider : ProviderRouteTarget?) -> Bool {
  guard provider is Some(provider) else { return true }
  guard provider.settings_config is Some(Object(settings)) else { return true }
  json_bool_from_map(settings, "requestMediaHeuristic").unwrap_or(true)
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
