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
  usage_cache : UsageCache
  pricing_overrides : Map[String, ModelPricing]
  pricing_deleted_model_ids : Map[String, Bool]
  mut proxy_enabled : Bool
  mut proxy_listen_address : String
  mut proxy_listen_port : Int
  mut proxy_enable_logging : Bool
  proxy_takeover_enabled : Map[String, Bool]
  proxy_app_enabled : Map[String, Bool]
  proxy_streaming_first_byte_timeout : Map[String, Int]
  proxy_streaming_idle_timeout : Map[String, Int]
  proxy_non_streaming_timeout : Map[String, Int]
  proxy_default_cost_multipliers : Map[String, String]
  proxy_pricing_model_sources : Map[String, String]
  mut upstream_proxy_url : String?
  mut last_external_url : String?
  mut openclaw_default_model : Json?
  mut openclaw_model_catalog : Json?
  mut openclaw_agents_defaults : Json?
  mut openclaw_env : Json
  mut openclaw_tools : Json
  hermes_model_config : Json?
  hermes_memory : Map[String, String]
  hermes_memory_enabled : Map[String, Bool]
  config_snippets : Map[String, String]
  mcp_servers : Map[String, Json]
  prompts : Map[String, Json]
  auth_device_user_codes : Map[String, String]
  mut app_settings : Json
  mut lightweight_mode : Bool
  mut window_theme : String
  mut app_config_dir_override : String?
  mut auto_launch_enabled : Bool
  mut rectifier_config_json : Json
  mut optimizer_config_json : Json
  mut copilot_optimizer_config_json : Json
  mut log_config_json : Json
  mut claude_plugin_config : String?
  mut claude_plugin_applied : Bool
  mut claude_onboarding_skipped : Bool
  mut stream_check_config : StreamCheckConfig
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
    usage_cache: UsageCache::new(),
    pricing_overrides: Map([], capacity=0),
    pricing_deleted_model_ids: Map([], capacity=0),
    proxy_enabled: true,
    proxy_listen_address: host,
    proxy_listen_port: port,
    proxy_enable_logging: true,
    proxy_takeover_enabled: Map([], capacity=0),
    proxy_app_enabled: Map([], capacity=0),
    proxy_streaming_first_byte_timeout: Map([], capacity=0),
    proxy_streaming_idle_timeout: Map([], capacity=0),
    proxy_non_streaming_timeout: Map([], capacity=0),
    proxy_default_cost_multipliers: Map([], capacity=0),
    proxy_pricing_model_sources: Map([], capacity=0),
    upstream_proxy_url: None,
    last_external_url: None,
    openclaw_default_model: None,
    openclaw_model_catalog: None,
    openclaw_agents_defaults: None,
    openclaw_env: Json::object({}),
    openclaw_tools: openclaw_default_tools_json(),
    hermes_model_config: None,
    hermes_memory: Map([], capacity=2),
    hermes_memory_enabled: Map([("memory", true), ("user", true)], capacity=2),
    config_snippets: Map([], capacity=8),
    mcp_servers: Map([], capacity=16),
    prompts: Map([], capacity=16),
    auth_device_user_codes: Map([], capacity=8),
    app_settings: ccs_default_app_settings_json(),
    lightweight_mode: false,
    window_theme: "system",
    app_config_dir_override: None,
    auto_launch_enabled: false,
    rectifier_config_json: ccs_default_rectifier_config_json(),
    optimizer_config_json: ccs_default_optimizer_config_json(),
    copilot_optimizer_config_json: ccs_default_copilot_optimizer_config_json(),
    log_config_json: ccs_default_log_config_json(),
    claude_plugin_config: None,
    claude_plugin_applied: false,
    claude_onboarding_skipped: false,
    stream_check_config: StreamCheckConfig::default(),
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
    cost_multiplier=self.provider_cost_multiplier(provider),
    pricing_model_source=self.provider_pricing_model_source(provider),
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
fn provider_selection_error_status(error : ProviderSelectionError) -> Int {
  match error {
    NoProvidersConfigured | AllProvidersCircuitOpen =>
      @status.ServiceUnavailable
  }
}

///|
fn provider_selection_error_code(error : ProviderSelectionError) -> String {
  match error {
    NoProvidersConfigured => "cc_switch_no_providers_configured"
    AllProvidersCircuitOpen => "cc_switch_all_providers_circuit_open"
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
      "code": Json::string("cc_switch_forward_failed"),
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
async fn Gateway::write_provider_selection_error(
  self : Gateway,
  app_type : String,
  error : ProviderSelectionError,
  w : @httpx.ResponseWriter,
) -> Unit {
  let status_code = provider_selection_error_status(error)
  let body = provider_selection_error_json(error, app_type).stringify()
  self.record_upstream_error_status(body.length(), status_code)
  self.stats.last_error = Some(error.to_string())
  w.header().set("Content-Type", "application/json")
  w.write_header(status_code)
  w.write(body)
  w.flush()
}

///|
fn provider_selection_is_all_circuits_open(
  selection : ProviderSelection,
) -> Bool {
  selection.error == Some(AllProvidersCircuitOpen)
}

///|
fn Gateway::all_provider_circuits_open(
  self : Gateway,
  app_type : String,
) -> Bool {
  provider_selection_is_all_circuits_open(
    self.provider_router.select_providers(app_type),
  )
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
  first_token_ms? : Int? = None,
  skip_empty_usage? : Bool = false,
) -> Unit {
  if record_provider {
    self.record_provider_result(true)
  }
  if skip_empty_usage {
    match usage {
      Some(usage) if usage.has_billable_tokens() => ()
      _ => {
        self.stats.record_success_without_usage_log(response_bytes)
        self.stats.save_persistent_store()
        return
      }
    }
  }
  self.stats.record_success_usage_with_pricing(
    usage.unwrap_or(TokenUsage::empty()),
    response_bytes,
    self.pricing_override_rows(),
    self.pricing_deleted_model_ids,
    first_token_ms~,
  )
  self.stats.save_persistent_store()
}

///|
fn ccs_first_stream_event_ms(current : Int?, started_at_ms : Int?) -> Int? {
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
pub async fn Gateway::start(self : Gateway) -> Unit {
  self.logger.info(
    "Starting Anthropic -> Codex OAuth Gateway on \{self.host}:\{self.port}",
  )
  self.load_model_pricing_store()
  self.stats.load_persistent_store()
  let backfilled = self.stats.backfill_missing_usage_costs(
    self.pricing_override_rows(),
    self.pricing_deleted_model_ids,
  )
  let pruned = self.stats.rollup_and_prune()
  if backfilled > 0 || pruned > 0 {
    self.stats.save_persistent_store()
  }
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
  router.add_handler(@httpx.Method::Get, "/get_claude_config_status", (_, w) => {
    self.handle_get_config_status(w, "claude")
  })
  router.add_handler(@httpx.Method::Get, "/get_config_status", (r, w) => {
    self.handle_get_config_status_request(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_claude_code_config_path", (_, w) => {
    self.handle_get_claude_code_config_path(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_config_dir", (r, w) => {
    self.handle_get_config_dir(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/open_config_folder", (r, w) => {
    self.handle_open_config_folder(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/pick_directory", (r, w) => {
    self.handle_pick_directory(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/open_external", (r, w) => {
    self.handle_open_external(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/open_external", (r, w) => {
    self.handle_open_external(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/copy_text_to_clipboard", (r, w) => {
    self.handle_copy_text_to_clipboard(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copy_text_to_clipboard", (r, w) => {
    self.handle_copy_text_to_clipboard(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/check_for_updates", (_, w) => {
    self.handle_check_for_updates(w)
  })
  router.add_handler(@httpx.Method::Get, "/check_for_updates", (_, w) => {
    self.handle_check_for_updates(w)
  })
  router.add_handler(@httpx.Method::Post, "/update_tray_menu", (_, w) => {
    self.handle_update_tray_menu(w)
  })
  router.add_handler(@httpx.Method::Get, "/update_tray_menu", (_, w) => {
    self.handle_update_tray_menu(w)
  })
  router.add_handler(@httpx.Method::Get, "/is_portable_mode", (_, w) => {
    self.handle_is_portable_mode(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_init_error", (_, w) => {
    self.handle_get_init_error(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_migration_result", (_, w) => {
    self.handle_get_migration_result(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_skills_migration_result", (_, w) => {
    self.handle_get_skills_migration_result(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_tool_versions", (r, w) => {
    self.handle_get_tool_versions(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_tool_versions", (r, w) => {
    self.handle_get_tool_versions(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/run_tool_lifecycle_action", (r, w) => {
    self.handle_run_tool_lifecycle_action(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/probe_tool_installations", (r, w) => {
    self.handle_probe_tool_installations(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/probe_tool_installations", (r, w) => {
    self.handle_probe_tool_installations(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_window_theme", (r, w) => {
    self.handle_set_window_theme(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/set_window_theme", (r, w) => {
    self.handle_set_window_theme(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/enter_lightweight_mode", (_, w) => {
    self.handle_enter_lightweight_mode(w)
  })
  router.add_handler(@httpx.Method::Get, "/enter_lightweight_mode", (_, w) => {
    self.handle_enter_lightweight_mode(w)
  })
  router.add_handler(@httpx.Method::Post, "/exit_lightweight_mode", (_, w) => {
    self.handle_exit_lightweight_mode(w)
  })
  router.add_handler(@httpx.Method::Get, "/exit_lightweight_mode", (_, w) => {
    self.handle_exit_lightweight_mode(w)
  })
  router.add_handler(@httpx.Method::Get, "/is_lightweight_mode", (_, w) => {
    self.handle_is_lightweight_mode(w)
  })
  router.add_handler(@httpx.Method::Post, "/save_file_dialog", (r, w) => {
    self.handle_save_file_dialog(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/save_file_dialog", (r, w) => {
    self.handle_save_file_dialog(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/export_config_to_file", (r, w) => {
    self.handle_export_config_to_file(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/export_config_to_file", (r, w) => {
    self.handle_export_config_to_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/import_config_from_file", (r, w) => {
    self.handle_import_config_from_file(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/import_config_from_file", (r, w) => {
    self.handle_import_config_from_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/create_db_backup", (_, w) => {
    self.handle_create_db_backup(w)
  })
  router.add_handler(@httpx.Method::Get, "/list_db_backups", (_, w) => {
    self.handle_list_db_backups(w)
  })
  router.add_handler(@httpx.Method::Post, "/restore_db_backup", (r, w) => {
    self.handle_restore_db_backup(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/rename_db_backup", (r, w) => {
    self.handle_rename_db_backup(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_db_backup", (r, w) => {
    self.handle_delete_db_backup(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_db_backup", (r, w) => {
    self.handle_delete_db_backup(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/parse_deeplink", (r, w) => {
    self.handle_parse_deeplink(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/parse_deeplink", (r, w) => {
    self.handle_parse_deeplink(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/merge_deeplink_config", (r, w) => {
    self.handle_merge_deeplink_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/merge_deeplink_config", (r, w) => {
    self.handle_merge_deeplink_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/import_from_deeplink", (r, w) => {
    self.handle_import_from_deeplink(r, w, legacy=true)
  })
  router.add_handler(@httpx.Method::Post, "/import_from_deeplink_unified", (
    r,
    w,
  ) => self.handle_import_from_deeplink(r, w, legacy=false))
  router.add_handler(@httpx.Method::Post, "/webdav_test_connection", (r, w) => {
    self.handle_webdav_test_connection(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/webdav_sync_upload", (_, w) => {
    self.handle_webdav_sync_operation(w, "upload")
  })
  router.add_handler(@httpx.Method::Post, "/webdav_sync_download", (_, w) => {
    self.handle_webdav_sync_operation(w, "download")
  })
  router.add_handler(@httpx.Method::Post, "/webdav_sync_save_settings", (r, w) => {
    self.handle_webdav_sync_save_settings(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/webdav_sync_fetch_remote_info", (
    _,
    w,
  ) => self.handle_webdav_sync_fetch_remote_info(w))
  router.add_handler(@httpx.Method::Post, "/s3_test_connection", (r, w) => {
    self.handle_s3_test_connection(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/s3_sync_upload", (_, w) => {
    self.handle_s3_sync_operation(w, "upload")
  })
  router.add_handler(@httpx.Method::Post, "/s3_sync_download", (_, w) => {
    self.handle_s3_sync_operation(w, "download")
  })
  router.add_handler(@httpx.Method::Post, "/s3_sync_save_settings", (r, w) => {
    self.handle_s3_sync_save_settings(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/s3_sync_fetch_remote_info", (_, w) => {
    self.handle_s3_sync_fetch_remote_info(w)
  })
  router.add_handler(@httpx.Method::Get, "/read_omo_local_file", (_, w) => {
    self.handle_read_omo_local_file(w, slim=false)
  })
  router.add_handler(@httpx.Method::Post, "/read_omo_local_file", (_, w) => {
    self.handle_read_omo_local_file(w, slim=false)
  })
  router.add_handler(@httpx.Method::Get, "/get_current_omo_provider_id", (_, w) => {
    self.handle_get_current_omo_provider_id(w, slim=false)
  })
  router.add_handler(@httpx.Method::Post, "/get_current_omo_provider_id", (_, w) => {
    self.handle_get_current_omo_provider_id(w, slim=false)
  })
  router.add_handler(@httpx.Method::Post, "/disable_current_omo", (_, w) => {
    self.handle_disable_current_omo(w, slim=false)
  })
  router.add_handler(@httpx.Method::Get, "/read_omo_slim_local_file", (_, w) => {
    self.handle_read_omo_local_file(w, slim=true)
  })
  router.add_handler(@httpx.Method::Post, "/read_omo_slim_local_file", (_, w) => {
    self.handle_read_omo_local_file(w, slim=true)
  })
  router.add_handler(@httpx.Method::Get, "/get_current_omo_slim_provider_id", (
    _,
    w,
  ) => self.handle_get_current_omo_provider_id(w, slim=true))
  router.add_handler(@httpx.Method::Post, "/get_current_omo_slim_provider_id", (
    _,
    w,
  ) => self.handle_get_current_omo_provider_id(w, slim=true))
  router.add_handler(@httpx.Method::Post, "/disable_current_omo_slim", (_, w) => {
    self.handle_disable_current_omo(w, slim=true)
  })
  router.add_handler(@httpx.Method::Post, "/open_file_dialog", (_, w) => {
    self.handle_open_file_dialog(w)
  })
  router.add_handler(@httpx.Method::Get, "/open_file_dialog", (_, w) => {
    self.handle_open_file_dialog(w)
  })
  router.add_handler(@httpx.Method::Post, "/open_zip_file_dialog", (_, w) => {
    self.handle_open_zip_file_dialog(w)
  })
  router.add_handler(@httpx.Method::Get, "/open_zip_file_dialog", (_, w) => {
    self.handle_open_zip_file_dialog(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_installed_skills", (_, w) => {
    self.handle_get_installed_skills(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_skill_backups", (_, w) => {
    self.handle_get_skill_backups(w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_skill_backup", (r, w) => {
    self.handle_delete_skill_backup(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/restore_skill_backup", (r, w) => {
    self.handle_restore_skill_backup(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/install_skill_unified", (r, w) => {
    self.handle_install_skill_unified(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/uninstall_skill_unified", (r, w) => {
    self.handle_uninstall_skill_unified(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/toggle_skill_app", (r, w) => {
    self.handle_toggle_skill_app(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/scan_unmanaged_skills", (_, w) => {
    self.handle_scan_unmanaged_skills(w)
  })
  router.add_handler(@httpx.Method::Post, "/import_skills_from_apps", (r, w) => {
    self.handle_import_skills_from_apps(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/discover_available_skills", (_, w) => {
    self.handle_discover_available_skills(w)
  })
  router.add_handler(@httpx.Method::Get, "/check_skill_updates", (_, w) => {
    self.handle_check_skill_updates(w)
  })
  router.add_handler(@httpx.Method::Post, "/update_skill", (r, w) => {
    self.handle_update_skill(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/migrate_skill_storage", (r, w) => {
    self.handle_migrate_skill_storage(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/search_skills_sh", (r, w) => {
    self.handle_search_skills_sh(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/search_skills_sh", (r, w) => {
    self.handle_search_skills_sh(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_skills", (_, w) => {
    self.handle_get_skills(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_skills_for_app", (_, w) => {
    self.handle_get_skills(w)
  })
  router.add_handler(@httpx.Method::Post, "/install_skill", (r, w) => {
    self.handle_install_skill_legacy(r, w, "claude")
  })
  router.add_handler(@httpx.Method::Post, "/install_skill_for_app", (r, w) => {
    self.handle_install_skill_for_app(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/uninstall_skill", (r, w) => {
    self.handle_uninstall_skill_legacy(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/uninstall_skill_for_app", (r, w) => {
    self.handle_uninstall_skill_legacy(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_skill_repos", (_, w) => {
    self.handle_get_skill_repos(w)
  })
  router.add_handler(@httpx.Method::Post, "/add_skill_repo", (r, w) => {
    self.handle_add_skill_repo(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/remove_skill_repo", (r, w) => {
    self.handle_remove_skill_repo(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/install_skills_from_zip", (r, w) => {
    self.handle_install_skills_from_zip(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_app_config_path", (_, w) => {
    self.handle_get_app_config_path(w)
  })
  router.add_handler(@httpx.Method::Get, "/open_app_config_folder", (_, w) => {
    self.handle_open_app_config_folder(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_claude_common_config_snippet", (
    _,
    w,
  ) => self.handle_get_common_config_snippet(w, "claude"))
  router.add_handler(@httpx.Method::Post, "/set_claude_common_config_snippet", (
    r,
    w,
  ) => self.handle_set_common_config_snippet(r, w, "claude"))
  router.add_handler(@httpx.Method::Get, "/get_common_config_snippet", (r, w) => {
    self.handle_get_common_config_snippet_request(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_common_config_snippet", (r, w) => {
    self.handle_set_common_config_snippet_request(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/extract_common_config_snippet", (
    r,
    w,
  ) => self.handle_extract_common_config_snippet(r, w))
  router.add_handler(@httpx.Method::Post, "/extract_common_config_snippet", (
    r,
    w,
  ) => self.handle_extract_common_config_snippet(r, w))
  router.add_handler(@httpx.Method::Get, "/check_env_conflicts", (r, w) => {
    self.handle_check_env_conflicts(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_env_vars", (r, w) => {
    self.handle_delete_env_vars(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/restore_env_backup", (r, w) => {
    self.handle_restore_env_backup(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_claude_mcp_status", (_, w) => {
    self.handle_get_claude_mcp_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/read_claude_mcp_config", (_, w) => {
    self.handle_read_claude_mcp_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/upsert_claude_mcp_server", (r, w) => {
    self.handle_upsert_claude_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_claude_mcp_server", (r, w) => {
    self.handle_delete_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_claude_mcp_server", (r, w) => {
    self.handle_delete_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/validate_mcp_command", (r, w) => {
    self.handle_validate_mcp_command(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_mcp_config", (r, w) => {
    self.handle_get_mcp_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/upsert_mcp_server_in_config", (r, w) => {
    self.handle_upsert_mcp_server_in_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_mcp_server_in_config", (r, w) => {
    self.handle_delete_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_mcp_server_in_config", (
    r,
    w,
  ) => self.handle_delete_mcp_server(r, w))
  router.add_handler(@httpx.Method::Post, "/set_mcp_enabled", (r, w) => {
    self.handle_set_mcp_enabled(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_mcp_servers", (_, w) => {
    self.handle_get_mcp_servers(w)
  })
  router.add_handler(@httpx.Method::Post, "/upsert_mcp_server", (r, w) => {
    self.handle_upsert_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_mcp_server", (r, w) => {
    self.handle_delete_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_mcp_server", (r, w) => {
    self.handle_delete_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/toggle_mcp_app", (r, w) => {
    self.handle_toggle_mcp_app(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/import_mcp_from_apps", (_, w) => {
    self.handle_import_mcp_from_apps(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_prompts", (r, w) => {
    self.handle_get_prompts(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/upsert_prompt", (r, w) => {
    self.handle_upsert_prompt(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_prompt", (r, w) => {
    self.handle_delete_prompt(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_prompt", (r, w) => {
    self.handle_delete_prompt(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/enable_prompt", (r, w) => {
    self.handle_enable_prompt(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/import_prompt_from_file", (r, w) => {
    self.handle_import_prompt_from_file(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_current_prompt_file_content", (
    r,
    w,
  ) => self.handle_get_current_prompt_file_content(r, w))
  router.add_handler(@httpx.Method::Get, "/proxy/status", (_, w) => {
    self.handle_proxy_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_proxy_status", (_, w) => {
    self.handle_proxy_status(w)
  })
  router.add_handler(@httpx.Method::Post, "/start_proxy_server", (_, w) => {
    self.handle_proxy_start_server(w)
  })
  router.add_handler(@httpx.Method::Post, "/stop_proxy_server", (_, w) => {
    self.handle_proxy_stop_server(w)
  })
  router.add_handler(@httpx.Method::Post, "/stop_proxy_with_restore", (_, w) => {
    self.handle_proxy_stop_with_restore(w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/config", (_, w) => {
    self.handle_proxy_config(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_proxy_config", (_, w) => {
    self.handle_proxy_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/config", (r, w) => {
    self.handle_proxy_update_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_proxy_config", (r, w) => {
    self.handle_proxy_update_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/global-config", (_, w) => {
    self.handle_proxy_global_config(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_global_proxy_config", (_, w) => {
    self.handle_proxy_global_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/global-config", (r, w) => {
    self.handle_proxy_update_global_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_global_proxy_config", (r, w) => {
    self.handle_proxy_update_global_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_settings", (_, w) => {
    self.handle_get_settings(w)
  })
  router.add_handler(@httpx.Method::Post, "/save_settings", (r, w) => {
    self.handle_save_settings(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/restart_app", (_, w) => {
    self.handle_restart_app(w)
  })
  router.add_handler(@httpx.Method::Post, "/install_update_and_restart", (_, w) => {
    self.handle_install_update_and_restart(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_app_config_dir_override", (_, w) => {
    self.handle_get_app_config_dir_override(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_app_config_dir_override", (r, w) => {
    self.handle_set_app_config_dir_override(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_auto_launch", (r, w) => {
    self.handle_set_auto_launch(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_auto_launch_status", (_, w) => {
    self.handle_get_auto_launch_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_rectifier_config", (_, w) => {
    self.handle_get_rectifier_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_rectifier_config", (r, w) => {
    self.handle_set_rectifier_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_optimizer_config", (_, w) => {
    self.handle_get_optimizer_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_optimizer_config", (r, w) => {
    self.handle_set_optimizer_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_copilot_optimizer_config", (_, w) => {
    self.handle_get_copilot_optimizer_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_copilot_optimizer_config", (
    r,
    w,
  ) => self.handle_set_copilot_optimizer_config(r, w))
  router.add_handler(@httpx.Method::Get, "/get_log_config", (_, w) => {
    self.handle_get_log_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_log_config", (r, w) => {
    self.handle_set_log_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_global_proxy_url", (_, w) => {
    self.handle_get_global_proxy_url(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_global_proxy_url", (r, w) => {
    self.handle_set_global_proxy_url(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/test_proxy_url", (r, w) => {
    self.handle_test_proxy_url(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/test_proxy_url", (r, w) => {
    self.handle_test_proxy_url(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_upstream_proxy_status", (_, w) => {
    self.handle_get_upstream_proxy_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/scan_local_proxies", (_, w) => {
    self.handle_scan_local_proxies(w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/app-config", (r, w) => {
    self.handle_proxy_app_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_proxy_config_for_app", (r, w) => {
    self.handle_proxy_app_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/app-config", (r, w) => {
    self.handle_proxy_update_app_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_proxy_config_for_app", (r, w) => {
    self.handle_proxy_update_app_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/default-cost-multiplier", (
    r,
    w,
  ) => self.handle_proxy_default_cost_multiplier(r, w))
  router.add_handler(@httpx.Method::Post, "/proxy/default-cost-multiplier", (
    r,
    w,
  ) => self.handle_proxy_set_default_cost_multiplier(r, w))
  router.add_handler(@httpx.Method::Post, "/set_default_cost_multiplier", (r, w) => {
    self.handle_proxy_set_default_cost_multiplier(r, w)
  })
  router.add_handler(
    @httpx.Method::Get,
    "/get_default_cost_multiplier_test_hook",
    (r, w) => self.handle_proxy_default_cost_multiplier(r, w),
  )
  router.add_handler(@httpx.Method::Get, "/get_default_cost_multiplier", (r, w) => {
    self.handle_proxy_default_cost_multiplier(r, w)
  })
  router.add_handler(
    @httpx.Method::Post,
    "/set_default_cost_multiplier_test_hook",
    (r, w) => self.handle_proxy_set_default_cost_multiplier_unit(r, w),
  )
  router.add_handler(@httpx.Method::Get, "/proxy/pricing-model-source", (r, w) => {
    self.handle_proxy_pricing_model_source(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/pricing-model-source", (r, w) => {
    self.handle_proxy_set_pricing_model_source(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_pricing_model_source", (r, w) => {
    self.handle_proxy_set_pricing_model_source(r, w)
  })
  router.add_handler(
    @httpx.Method::Get,
    "/get_pricing_model_source_test_hook",
    (r, w) => self.handle_proxy_pricing_model_source(r, w),
  )
  router.add_handler(@httpx.Method::Get, "/get_pricing_model_source", (r, w) => {
    self.handle_proxy_pricing_model_source(r, w)
  })
  router.add_handler(
    @httpx.Method::Post,
    "/set_pricing_model_source_test_hook",
    (r, w) => self.handle_proxy_set_pricing_model_source_unit(r, w),
  )
  router.add_handler(@httpx.Method::Get, "/proxy/provider-health", (r, w) => {
    self.handle_proxy_provider_health(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_provider_health", (r, w) => {
    self.handle_proxy_provider_health(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/circuit-breaker-config", (_, w) => {
    self.handle_proxy_circuit_breaker_config(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_circuit_breaker_config", (_, w) => {
    self.handle_proxy_circuit_breaker_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/circuit-breaker-config", (
    r,
    w,
  ) => self.handle_proxy_update_circuit_breaker_config(r, w))
  router.add_handler(@httpx.Method::Post, "/update_circuit_breaker_config", (
    r,
    w,
  ) => self.handle_proxy_update_circuit_breaker_config(r, w))
  router.add_handler(@httpx.Method::Get, "/proxy/circuit-breaker-stats", (r, w) => {
    self.handle_proxy_circuit_breaker_stats(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_circuit_breaker_stats", (r, w) => {
    self.handle_proxy_circuit_breaker_stats(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/reset-circuit-breaker", (r, w) => {
    self.handle_proxy_reset_circuit_breaker(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/reset_circuit_breaker", (r, w) => {
    self.handle_proxy_reset_circuit_breaker(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/failover-queue", (r, w) => {
    self.handle_proxy_failover_queue(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_failover_queue", (r, w) => {
    self.handle_proxy_failover_queue(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/failover-queue", (r, w) => {
    self.handle_proxy_add_failover_queue(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/add_to_failover_queue", (r, w) => {
    self.handle_proxy_add_failover_queue(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/proxy/failover-queue", (r, w) => {
    self.handle_proxy_remove_failover_queue(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/remove_from_failover_queue", (
    r,
    w,
  ) => self.handle_proxy_remove_failover_queue(r, w))
  router.add_handler(@httpx.Method::Post, "/remove_from_failover_queue", (r, w) => {
    self.handle_proxy_remove_failover_queue(r, w)
  })
  router.add_handler(
    @httpx.Method::Get,
    "/proxy/available-failover-providers",
    (r, w) => self.handle_proxy_available_failover_providers(r, w),
  )
  router.add_handler(
    @httpx.Method::Get,
    "/get_available_providers_for_failover",
    (r, w) => self.handle_proxy_available_failover_providers(r, w),
  )
  router.add_handler(@httpx.Method::Get, "/proxy/auto-failover-enabled", (r, w) => {
    self.handle_proxy_auto_failover_enabled(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_auto_failover_enabled", (r, w) => {
    self.handle_proxy_auto_failover_enabled(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/auto-failover-enabled", (r, w) => {
    self.handle_proxy_set_auto_failover_enabled(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_auto_failover_enabled", (r, w) => {
    self.handle_proxy_set_auto_failover_enabled(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/takeover-status", (_, w) => {
    self.handle_proxy_takeover_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_proxy_takeover_status", (_, w) => {
    self.handle_proxy_takeover_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/is_live_takeover_active", (_, w) => {
    self.handle_proxy_live_takeover_active(w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/takeover-status", (r, w) => {
    self.handle_proxy_set_takeover_for_app(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_proxy_takeover_for_app", (r, w) => {
    self.handle_proxy_set_takeover_for_app(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/switch_proxy_provider", (r, w) => {
    self.handle_proxy_switch_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/sync_current_providers_live", (_, w) => {
    self.handle_sync_current_providers_live(w)
  })
  router.add_handler(@httpx.Method::Post, "/import_default_config", (r, w) => {
    self.handle_import_default_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/import_default_config_test_hook", (
    r,
    w,
  ) => self.handle_import_default_config(r, w))
  router.add_handler(@httpx.Method::Get, "/get_providers", (r, w) => {
    self.handle_get_providers(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_current_provider", (r, w) => {
    self.handle_get_current_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/add_provider", (r, w) => {
    self.handle_add_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_provider", (r, w) => {
    self.handle_update_provider(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_provider", (r, w) => {
    self.handle_delete_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_provider", (r, w) => {
    self.handle_delete_provider(r, w)
  })
  router.add_handler(
    @httpx.Method::Delete,
    "/remove_provider_from_live_config",
    (r, w) => self.handle_remove_provider_from_live_config(r, w),
  )
  router.add_handler(@httpx.Method::Post, "/remove_provider_from_live_config", (
    r,
    w,
  ) => self.handle_remove_provider_from_live_config(r, w))
  router.add_handler(@httpx.Method::Post, "/switch_provider", (r, w) => {
    self.handle_switch_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/switch_provider_test_hook", (r, w) => {
    self.handle_switch_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/open_provider_terminal", (r, w) => {
    self.handle_open_provider_terminal(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_claude_desktop_status", (_, w) => {
    self.handle_get_claude_desktop_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_claude_desktop_default_routes", (
    _,
    w,
  ) => self.handle_get_claude_desktop_default_routes(w))
  router.add_handler(
    @httpx.Method::Post,
    "/import_claude_desktop_providers_from_claude",
    (_, w) => self.handle_import_claude_desktop_providers_from_claude(w),
  )
  router.add_handler(
    @httpx.Method::Post,
    "/ensure_claude_desktop_official_provider",
    (_, w) => self.handle_ensure_claude_desktop_official_provider(w),
  )
  router.add_handler(@httpx.Method::Get, "/read_live_provider_settings", (r, w) => {
    self.handle_read_live_provider_settings(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_claude_plugin_status", (_, w) => {
    self.handle_get_claude_plugin_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/read_claude_plugin_config", (_, w) => {
    self.handle_read_claude_plugin_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/apply_claude_plugin_config", (r, w) => {
    self.handle_apply_claude_plugin_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/is_claude_plugin_applied", (_, w) => {
    self.handle_is_claude_plugin_applied(w)
  })
  router.add_handler(@httpx.Method::Post, "/apply_claude_onboarding_skip", (
    _,
    w,
  ) => self.handle_apply_claude_onboarding_skip(w))
  router.add_handler(@httpx.Method::Post, "/clear_claude_onboarding_skip", (
    _,
    w,
  ) => self.handle_clear_claude_onboarding_skip(w))
  router.add_handler(@httpx.Method::Get, "/list_daily_memory_files", (_, w) => {
    self.handle_list_daily_memory_files(w)
  })
  router.add_handler(@httpx.Method::Get, "/read_daily_memory_file", (r, w) => {
    self.handle_read_daily_memory_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/read_daily_memory_file", (r, w) => {
    self.handle_read_daily_memory_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/write_daily_memory_file", (r, w) => {
    self.handle_write_daily_memory_file(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/search_daily_memory_files", (r, w) => {
    self.handle_search_daily_memory_files(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/search_daily_memory_files", (r, w) => {
    self.handle_search_daily_memory_files(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_daily_memory_file", (r, w) => {
    self.handle_delete_daily_memory_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_daily_memory_file", (r, w) => {
    self.handle_delete_daily_memory_file(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/read_workspace_file", (r, w) => {
    self.handle_read_workspace_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/read_workspace_file", (r, w) => {
    self.handle_read_workspace_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/write_workspace_file", (r, w) => {
    self.handle_write_workspace_file(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/open_workspace_directory", (r, w) => {
    self.handle_open_workspace_directory(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/open_workspace_directory", (r, w) => {
    self.handle_open_workspace_directory(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_opencode_live_provider_ids", (
    _,
    w,
  ) => self.handle_get_live_provider_ids(w, "opencode"))
  router.add_handler(@httpx.Method::Get, "/get_openclaw_live_provider_ids", (
    _,
    w,
  ) => self.handle_get_live_provider_ids(w, "openclaw"))
  router.add_handler(@httpx.Method::Get, "/get_openclaw_live_provider", (r, w) => {
    self.handle_get_live_provider(r, w, "openclaw")
  })
  router.add_handler(@httpx.Method::Get, "/scan_openclaw_config_health", (_, w) => {
    self.handle_scan_openclaw_config_health(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_openclaw_default_model", (_, w) => {
    self.handle_get_openclaw_default_model(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_openclaw_default_model", (r, w) => {
    self.handle_set_openclaw_default_model(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_openclaw_model_catalog", (_, w) => {
    self.handle_get_openclaw_model_catalog(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_openclaw_model_catalog", (r, w) => {
    self.handle_set_openclaw_model_catalog(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_openclaw_agents_defaults", (_, w) => {
    self.handle_get_openclaw_agents_defaults(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_openclaw_agents_defaults", (
    r,
    w,
  ) => self.handle_set_openclaw_agents_defaults(r, w))
  router.add_handler(@httpx.Method::Get, "/get_openclaw_env", (_, w) => {
    self.handle_get_openclaw_env(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_openclaw_env", (r, w) => {
    self.handle_set_openclaw_env(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_openclaw_tools", (_, w) => {
    self.handle_get_openclaw_tools(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_openclaw_tools", (r, w) => {
    self.handle_set_openclaw_tools(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_hermes_live_provider_ids", (_, w) => {
    self.handle_get_live_provider_ids(w, "hermes")
  })
  router.add_handler(@httpx.Method::Get, "/get_hermes_live_provider", (r, w) => {
    self.handle_get_live_provider(r, w, "hermes")
  })
  router.add_handler(@httpx.Method::Get, "/get_hermes_model_config", (_, w) => {
    self.handle_get_hermes_model_config(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_hermes_memory", (r, w) => {
    self.handle_get_hermes_memory(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_hermes_memory", (r, w) => {
    self.handle_set_hermes_memory(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_hermes_memory_limits", (_, w) => {
    self.handle_get_hermes_memory_limits(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_hermes_memory_enabled", (r, w) => {
    self.handle_set_hermes_memory_enabled(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/open_hermes_web_ui", (r, w) => {
    self.handle_open_hermes_web_ui(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/launch_hermes_dashboard", (_, w) => {
    self.handle_launch_hermes_dashboard(w)
  })
  router.add_handler(
    @httpx.Method::Post,
    "/import_opencode_providers_from_live",
    (_, w) => self.handle_import_live_providers(w, "opencode"),
  )
  router.add_handler(
    @httpx.Method::Post,
    "/import_openclaw_providers_from_live",
    (_, w) => self.handle_import_live_providers(w, "openclaw"),
  )
  router.add_handler(
    @httpx.Method::Post,
    "/import_hermes_providers_from_live",
    (_, w) => self.handle_import_live_providers(w, "hermes"),
  )
  router.add_handler(@httpx.Method::Get, "/get_universal_providers", (_, w) => {
    self.handle_get_universal_providers(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_universal_provider", (r, w) => {
    self.handle_get_universal_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/upsert_universal_provider", (r, w) => {
    self.handle_upsert_universal_provider(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_universal_provider", (r, w) => {
    self.handle_delete_universal_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_universal_provider", (r, w) => {
    self.handle_delete_universal_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/sync_universal_provider", (r, w) => {
    self.handle_sync_universal_provider(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_provider_presets", (r, w) => {
    self.handle_get_provider_presets(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/test_api_endpoints", (r, w) => {
    self.handle_test_api_endpoints(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/test_api_endpoints", (r, w) => {
    self.handle_test_api_endpoints(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_providers_sort_order", (r, w) => {
    self.handle_update_providers_sort_order(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_custom_endpoints", (r, w) => {
    self.handle_get_custom_endpoints(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/add_custom_endpoint", (r, w) => {
    self.handle_add_custom_endpoint(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/remove_custom_endpoint", (r, w) => {
    self.handle_remove_custom_endpoint(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/remove_custom_endpoint", (r, w) => {
    self.handle_remove_custom_endpoint(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_endpoint_last_used", (r, w) => {
    self.handle_update_endpoint_last_used(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/running", (_, w) => {
    self.handle_proxy_running(w)
  })
  router.add_handler(@httpx.Method::Get, "/is_proxy_running", (_, w) => {
    self.handle_proxy_running(w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/logs", (r, w) => {
    self.handle_usage_logs(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/logs", (r, w) => {
    self.handle_usage_logs(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_request_logs", (r, w) => {
    self.handle_usage_logs(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_request_logs", (r, w) => {
    self.handle_usage_logs(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/summary", (r, w) => {
    self.handle_usage_summary(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/summary", (r, w) => {
    self.handle_usage_summary(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_usage_summary", (r, w) => {
    self.handle_usage_summary(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_usage_summary", (r, w) => {
    self.handle_usage_summary(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/summary/by-app", (r, w) => {
    self.handle_usage_summary_by_app(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/summary/by-app", (r, w) => {
    self.handle_usage_summary_by_app(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_usage_summary_by_app", (r, w) => {
    self.handle_usage_summary_by_app(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_usage_summary_by_app", (r, w) => {
    self.handle_usage_summary_by_app(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/trends", (r, w) => {
    self.handle_usage_trends(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/trends", (r, w) => {
    self.handle_usage_trends(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_usage_trends", (r, w) => {
    self.handle_usage_trends(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_usage_trends", (r, w) => {
    self.handle_usage_trends(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/provider-limits", (r, w) => {
    self.handle_usage_provider_limits(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/provider-limits", (r, w) => {
    self.handle_usage_provider_limits(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/check_provider_limits", (r, w) => {
    self.handle_usage_provider_limits(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/check_provider_limits", (r, w) => {
    self.handle_usage_provider_limits(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/provider-stats", (r, w) => {
    self.handle_usage_provider_stats(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/provider-stats", (r, w) => {
    self.handle_usage_provider_stats(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_provider_stats", (r, w) => {
    self.handle_usage_provider_stats(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_provider_stats", (r, w) => {
    self.handle_usage_provider_stats(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/model-stats", (r, w) => {
    self.handle_usage_model_stats(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/model-stats", (r, w) => {
    self.handle_usage_model_stats(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_model_stats", (r, w) => {
    self.handle_usage_model_stats(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_model_stats", (r, w) => {
    self.handle_usage_model_stats(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/data-sources", (_, w) => {
    self.handle_usage_data_sources(w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/data-sources", (_, w) => {
    self.handle_usage_data_sources(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_usage_data_sources", (_, w) => {
    self.handle_usage_data_sources(w)
  })
  router.add_handler(@httpx.Method::Post, "/get_usage_data_sources", (_, w) => {
    self.handle_usage_data_sources(w)
  })
  router.add_handler(@httpx.Method::Get, "/queryProviderUsage", (r, w) => {
    self.handle_query_provider_usage(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/queryProviderUsage", (r, w) => {
    self.handle_query_provider_usage(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_balance", (r, w) => {
    self.handle_get_balance(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_balance", (r, w) => {
    self.handle_get_balance(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_subscription_quota", (r, w) => {
    self.handle_get_subscription_quota(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_subscription_quota", (r, w) => {
    self.handle_get_subscription_quota(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_codex_oauth_quota", (r, w) => {
    self.handle_get_codex_oauth_quota(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_codex_oauth_quota", (r, w) => {
    self.handle_get_codex_oauth_quota(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_codex_oauth_models", (r, w) => {
    self.handle_get_codex_oauth_models(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_codex_oauth_models", (r, w) => {
    self.handle_get_codex_oauth_models(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_coding_plan_quota", (r, w) => {
    self.handle_get_coding_plan_quota(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_coding_plan_quota", (r, w) => {
    self.handle_get_coding_plan_quota(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/testUsageScript", (r, w) => {
    self.handle_test_usage_script(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/sync-session", (r, w) => {
    self.handle_usage_sync_session(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/sync_session_usage", (r, w) => {
    self.handle_usage_sync_session(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/list_sessions", (_, w) => {
    self.handle_list_sessions(w)
  })
  router.add_handler(@httpx.Method::Post, "/list_sessions", (_, w) => {
    self.handle_list_sessions(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_session_messages", (r, w) => {
    self.handle_get_session_messages(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_session_messages", (r, w) => {
    self.handle_get_session_messages(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/launch_session_terminal", (r, w) => {
    self.handle_launch_session_terminal(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_session", (r, w) => {
    self.handle_delete_session(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_sessions", (r, w) => {
    self.handle_delete_sessions(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/model-pricing", (_, w) => {
    self.handle_usage_model_pricing(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_model_pricing", (_, w) => {
    self.handle_usage_model_pricing(w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/model-pricing", (r, w) => {
    self.handle_usage_update_model_pricing(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_model_pricing", (r, w) => {
    self.handle_usage_update_model_pricing(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/usage/model-pricing", (r, w) => {
    self.handle_usage_delete_model_pricing(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_model_pricing", (r, w) => {
    self.handle_usage_delete_model_pricing(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_model_pricing", (r, w) => {
    self.handle_usage_delete_model_pricing(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/request-detail/*path", (r, w) => {
    self.handle_usage_request_detail(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_request_detail", (r, w) => {
    self.handle_usage_request_detail(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_request_detail", (r, w) => {
    self.handle_usage_request_detail(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/stream_check_provider", (r, w) => {
    self.handle_stream_check_provider(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/stream_check_provider", (r, w) => {
    self.handle_stream_check_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/stream_check_all_providers", (r, w) => {
    self.handle_stream_check_all_providers(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/stream_check_all_providers", (r, w) => {
    self.handle_stream_check_all_providers(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_stream_check_config", (_, w) => {
    self.handle_get_stream_check_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/save_stream_check_config", (r, w) => {
    self.handle_save_stream_check_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/fetch_models_for_config", (r, w) => {
    self.handle_fetch_models_for_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/fetch_models_for_config", (r, w) => {
    self.handle_fetch_models_for_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/auth_start_login", (r, w) => {
    self.handle_auth_start_login(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_start_login", (r, w) => {
    self.handle_auth_start_login(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/auth_poll_for_account", (r, w) => {
    self.handle_auth_poll_for_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_poll_for_account", (r, w) => {
    self.handle_auth_poll_for_account(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/auth_list_accounts", (r, w) => {
    self.handle_auth_list_accounts(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_list_accounts", (r, w) => {
    self.handle_auth_list_accounts(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/auth_get_status", (r, w) => {
    self.handle_auth_get_status(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_get_status", (r, w) => {
    self.handle_auth_get_status(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/auth_remove_account", (r, w) => {
    self.handle_auth_remove_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_remove_account", (r, w) => {
    self.handle_auth_remove_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_set_default_account", (r, w) => {
    self.handle_auth_set_default_account(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/auth_set_default_account", (r, w) => {
    self.handle_auth_set_default_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_logout", (r, w) => {
    self.handle_auth_logout(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/auth_logout", (r, w) => {
    self.handle_auth_logout(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_start_device_flow", (r, w) => {
    self.handle_copilot_start_device_flow(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/copilot_start_device_flow", (r, w) => {
    self.handle_copilot_start_device_flow(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_poll_for_auth", (r, w) => {
    self.handle_copilot_poll_for_auth(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/copilot_poll_for_auth", (r, w) => {
    self.handle_copilot_poll_for_auth(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_poll_for_account", (r, w) => {
    self.handle_copilot_poll_for_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/copilot_poll_for_account", (r, w) => {
    self.handle_copilot_poll_for_account(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_list_accounts", (_, w) => {
    self.handle_copilot_list_accounts(w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_get_auth_status", (_, w) => {
    self.handle_copilot_get_auth_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_is_authenticated", (_, w) => {
    self.handle_copilot_is_authenticated(w)
  })
  router.add_handler(@httpx.Method::Post, "/copilot_logout", (_, w) => {
    self.handle_copilot_logout(w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_logout", (_, w) => {
    self.handle_copilot_logout(w)
  })
  router.add_handler(@httpx.Method::Delete, "/copilot_remove_account", (r, w) => {
    self.handle_copilot_remove_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/copilot_remove_account", (r, w) => {
    self.handle_copilot_remove_account(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_set_default_account", (r, w) => {
    self.handle_copilot_set_default_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/copilot_set_default_account", (r, w) => {
    self.handle_copilot_set_default_account(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_get_token", (r, w) => {
    self.handle_copilot_get_token(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_get_token_for_account", (
    r,
    w,
  ) => self.handle_copilot_get_token(r, w))
  router.add_handler(@httpx.Method::Get, "/copilot_get_models", (r, w) => {
    self.handle_copilot_get_models(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_get_models_for_account", (
    r,
    w,
  ) => self.handle_copilot_get_models(r, w))
  router.add_handler(@httpx.Method::Get, "/copilot_get_usage", (r, w) => {
    self.handle_copilot_get_usage(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_get_usage_for_account", (
    r,
    w,
  ) => self.handle_copilot_get_usage(r, w))
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
  self.stats.record_request_context("codex", self.model)
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
  self.stats.record_request_context("codex", self.model)
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
      self.stats.record_request_context("codex", response_model, session_id~)
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
  self.stats.record_request_context("gemini", "gemini")
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
        let parsed = @json.parse(response_body) catch { _ => Json::null() }
        let usage = token_usage_or_response_model(
          token_usage_from_gemini_response(parsed),
          parsed,
          ["modelVersion"],
        )
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
  if provider_selection_is_all_circuits_open(selection) {
    self.write_provider_selection_error("codex", AllProvidersCircuitOpen, w)
    return
  }
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
            let error_body = codex_forward_failed_error_body(
              provider,
              response_model,
              "/chat/completions",
              "\{error}",
            )
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
          let usage = token_usage_or_response_model(
            token_usage_from_codex_response_auto(json),
            json,
            ["model"],
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
  if provider_selection_is_all_circuits_open(selection) {
    self.write_provider_selection_error("codex", AllProvidersCircuitOpen, w)
    return
  }
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
        let created = @os.unix_seconds()
        let stream_events : Array[Json] = []
        w.write(
          "data: \{openai_chat_role_chunk(id, response_model, created).stringify()}\n\n",
        )
        w.flush()
        self.record_provider_result(true)
        let mut response_bytes = 0
        let mut first_token_ms : Int? = None
        if first_line is [.. "data: ", .. rest] {
          let data = rest.trim().to_owned()
          if data != "[DONE]" {
            if push_sse_json_event(stream_events, data) {
              first_token_ms = ccs_first_stream_event_ms(
                first_token_ms,
                self.stats.current_request_started_at_ms,
              )
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
          if data == "[DONE]" {
            break
          }
          if push_sse_json_event(stream_events, data) {
            first_token_ms = ccs_first_stream_event_ms(
              first_token_ms,
              self.stats.current_request_started_at_ms,
            )
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
        ignore(self.codex_chat_history.record_stream_events(stream_events))
        self.record_success_stream_usage(
          token_usage_from_codex_stream_events_auto(stream_events),
          response_bytes,
          record_provider=false,
          first_token_ms~,
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
  if provider_selection_is_all_circuits_open(selection) {
    self.write_provider_selection_error("codex", AllProvidersCircuitOpen, w)
    return
  }
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
            let request_model = codex_request_model(request, self.model)
            let error_body = codex_forward_failed_error_body(
              provider,
              request_model,
              endpoint,
              "\{error}",
            )
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
          token_usage_or_response_model(
            token_usage_from_codex_response_auto(json),
            json,
            ["model"],
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
  if provider_selection_is_all_circuits_open(selection) {
    self.write_provider_selection_error("codex", AllProvidersCircuitOpen, w)
    return
  }
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
            let request_model = codex_request_model(request, self.model)
            let error_body = codex_forward_failed_error_body(
              provider,
              request_model,
              endpoint,
              "\{error}",
            )
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
        let mut first_token_ms : Int? = None
        let chat_state = ChatToCodexResponsesStreamState::new_with_context(
          codex_request_model(request, self.model),
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
              first_token_ms = ccs_first_stream_event_ms(
                first_token_ms,
                self.stats.current_request_started_at_ms,
              )
            }
          } else {
            if data != "[DONE]" {
              if push_sse_json_event(stream_events, data) {
                first_token_ms = ccs_first_stream_event_ms(
                  first_token_ms,
                  self.stats.current_request_started_at_ms,
                )
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
        self.record_provider_result(true)
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
              first_token_ms = ccs_first_stream_event_ms(
                first_token_ms,
                self.stats.current_request_started_at_ms,
              )
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
                  first_token_ms = ccs_first_stream_event_ms(
                    first_token_ms,
                    self.stats.current_request_started_at_ms,
                  )
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
        ignore(self.codex_chat_history.record_stream_events(stream_events))
        self.record_success_stream_usage(
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
async fn Gateway::post_codex_compatible_provider_json(
  self : Gateway,
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
  match ccs_reject_proxy_managed_placeholder_for_upstream(url, headers) {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  let (response, data) = @http.post(url, request, headers~) catch {
    error => return Err("\{error}")
  }
  Ok((response, data.text()))
}

///|
async fn Gateway::post_codex_compatible_provider_stream(
  self : Gateway,
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
  match ccs_reject_proxy_managed_placeholder_for_upstream(url, headers) {
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
async fn Gateway::post_claude_compatible_provider_json(
  self : Gateway,
  provider : ProviderRouteTarget,
  endpoint : String,
  request : Json,
  api_format : String,
  anthropic_beta : String?,
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
  )
  match ccs_reject_proxy_managed_placeholder_for_upstream(url, headers) {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  let (response, data) = @http.post(url, request, headers~) catch {
    error => return Err("\{error}")
  }
  Ok((response, data.text()))
}

///|
const CCS_PROXY_MANAGED_PLACEHOLDER = "PROXY_MANAGED"

///|
const HERMES_WEB_OFFLINE_ERROR = "hermes_web_offline"

///|
fn ccs_reject_proxy_managed_placeholder_for_upstream(
  url : String,
  headers : Map[String, String],
) -> Result[Unit, String] {
  if !ccs_is_managed_account_upstream_url(url) ||
    !ccs_headers_contain_proxy_managed_placeholder(headers) {
    return Ok(())
  }
  Err(
    "Managed account proxy auth was not resolved; PROXY_MANAGED must not be sent upstream",
  )
}

///|
fn ccs_is_managed_account_upstream_url(url : String) -> Bool {
  let (origin, path) = split_origin_and_path(url)
  let host = extract_host(origin).to_lower()
  host == "githubcopilot.com" ||
  host.has_suffix(".githubcopilot.com") ||
  (host == "chatgpt.com" && path.has_prefix("/backend-api/codex"))
}

///|
fn ccs_is_github_copilot_upstream_url(url : String) -> Bool {
  let (origin, _) = split_origin_and_path(url)
  let host = extract_host(origin).to_lower()
  host == "githubcopilot.com" || host.has_suffix(".githubcopilot.com")
}

///|
fn ccs_provider_managed_auth_url(provider : ProviderRouteTarget) -> String? {
  match provider.base_url {
    Some(url) if !url.trim().is_empty() => return Some(url)
    _ => ()
  }
  guard provider.settings_config is Some(Object(settings)) else { return None }
  match
    json_string_from_map_any(settings, [
      "baseUrl", "base_url", "apiBaseUrl", "api_base_url",
    ]) {
    Some(url) if !url.trim().is_empty() => return Some(url)
    _ => ()
  }
  match settings.get("env") {
    Some(Object(env)) =>
      json_string_from_map_any(env, ["ANTHROPIC_BASE_URL", "OPENAI_BASE_URL"])
    _ => None
  }
}

///|
fn ccs_provider_is_github_copilot(provider : ProviderRouteTarget) -> Bool {
  if provider.provider_type == Some(AUTH_PROVIDER_GITHUB_COPILOT) {
    return true
  }
  match ccs_provider_managed_auth_url(provider) {
    Some(url) => ccs_is_github_copilot_upstream_url(url)
    None => false
  }
}

///|
fn ccs_provider_uses_managed_account_auth(
  provider : ProviderRouteTarget,
) -> Bool {
  if provider.provider_type == Some(AUTH_PROVIDER_CODEX_OAUTH) ||
    provider.provider_type == Some(AUTH_PROVIDER_GITHUB_COPILOT) {
    return true
  }
  match ccs_provider_managed_auth_url(provider) {
    Some(url) => ccs_is_managed_account_upstream_url(url)
    None => false
  }
}

///|
fn ccs_claude_takeover_settings_config_json(
  provider : ProviderRouteTarget,
  proxy_url : String,
) -> Json {
  let root : Map[String, Json] = {}
  match provider.settings_config {
    Some(Object(settings)) =>
      for key in settings.keys() {
        guard settings.get(key) is Some(value) else { continue }
        root[key] = value
      }
    _ => ()
  }
  let env : Map[String, Json] = {}
  match root.get("env") {
    Some(Object(raw_env)) =>
      for key in raw_env.keys() {
        guard raw_env.get(key) is Some(value) else { continue }
        env[key] = value
      }
    _ => ()
  }
  env["ANTHROPIC_BASE_URL"] = Json::string(proxy_url)
  for
    key in [
      "ANTHROPIC_MODEL", "ANTHROPIC_REASONING_MODEL", "ANTHROPIC_SMALL_FAST_MODEL",
      "ANTHROPIC_DEFAULT_HAIKU_MODEL", "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME", "ANTHROPIC_DEFAULT_OPUS_MODEL",
      "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME", "ANTHROPIC_DEFAULT_SONNET_MODEL", "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME",
    ] {
    env.remove(key)
  }
  let token_keys = [
    "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_API_KEY", "OPENROUTER_API_KEY", "OPENAI_API_KEY",
  ]
  if ccs_provider_uses_managed_account_auth(provider) {
    for key in token_keys {
      env.remove(key)
    }
    env["ANTHROPIC_API_KEY"] = Json::string(CCS_PROXY_MANAGED_PLACEHOLDER)
    if !ccs_provider_is_github_copilot(provider) {
      env["ANTHROPIC_AUTH_TOKEN"] = Json::string(CCS_PROXY_MANAGED_PLACEHOLDER)
    }
  } else {
    let mut replaced_any = false
    for key in token_keys {
      if env.contains(key) {
        env[key] = Json::string(CCS_PROXY_MANAGED_PLACEHOLDER)
        replaced_any = true
      }
    }
    if !replaced_any {
      env["ANTHROPIC_AUTH_TOKEN"] = Json::string(CCS_PROXY_MANAGED_PLACEHOLDER)
    }
  }
  root["env"] = Json::object(env)
  Json::object(root)
}

///|
fn ccs_headers_contain_proxy_managed_placeholder(
  headers : Map[String, String],
) -> Bool {
  for _, value in headers {
    if value.contains(CCS_PROXY_MANAGED_PLACEHOLDER) {
      return true
    }
  }
  false
}

///|
fn claude_compatible_provider_headers(
  api_key : String,
  api_format : String,
  anthropic_beta? : String? = None,
  accept? : String = "application/json",
  custom_user_agent? : String? = None,
  provider_type? : String? = None,
) -> Map[String, String] {
  let headers : Map[String, String] = {
    "Content-Type": "application/json",
    "Accept": accept,
  }
  if provider_type == Some("gemini_cli") {
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
        headers["anthropic-beta"] = ccs_claude_code_beta_header(anthropic_beta)
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
  headers
}

///|
fn gemini_cli_bearer_token(api_key : String) -> String {
  let trimmed = api_key.trim()
  if trimmed.has_prefix("{") {
    let parsed = @json.parse(trimmed.to_owned()) catch { _ => Json::null() }
    if parsed is Object(obj) {
      match json_string_from_map(obj, "access_token") {
        Some(token) if !token.trim().is_empty() =>
          return token.trim().to_owned()
        _ => ()
      }
    }
  }
  trimmed.to_owned()
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
  match
    parse_custom_user_agent(
      json_string_from_map_any(obj, [
        "customUserAgent", "custom_user_agent", "userAgent", "user_agent",
      ]),
    ) {
    Some(value) => return Some(value)
    None => ()
  }
  match obj.get("meta") {
    Some(Object(meta)) =>
      parse_custom_user_agent(
        json_string_from_map_any(meta, [
          "customUserAgent", "custom_user_agent", "userAgent", "user_agent",
        ]),
      )
    _ => None
  }
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
fn ccs_claude_code_beta_header(existing_beta : String?) -> String {
  let claude_code_beta = "claude-code-20250219"
  match existing_beta {
    Some(beta) if beta.contains(claude_code_beta) => beta
    Some(beta) if !beta.trim().is_empty() => "\{claude_code_beta},\{beta}"
    _ => claude_code_beta
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
  let path = match base_url.find("?") {
    Some(index) => base_url[:index]
    None => base_url[:]
  }
  path.has_suffix("/responses") ||
  path.has_suffix("/chat/completions") ||
  path.has_suffix("/messages")
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
  path == "/v1/messages" || path == "/claude/v1/messages"
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
      let trimmed = id.trim().to_owned()
      if !trimmed.is_empty() {
        headers["session_id"] = trimmed
        headers["x-client-request-id"] = trimmed
        headers["x-codex-window-id"] = "\{trimmed}:0"
      }
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
fn Gateway::provider_cost_multiplier(
  self : Gateway,
  provider : ProviderRouteTarget,
) -> String {
  provider_cost_multiplier_from_default(
    provider,
    self.proxy_default_cost_multiplier_for_app(provider.app_type),
  )
}

///|
fn provider_cost_multiplier_from_default(
  provider : ProviderRouteTarget,
  default_multiplier : String,
) -> String {
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
fn Gateway::provider_pricing_model_source(
  self : Gateway,
  provider : ProviderRouteTarget,
) -> String {
  provider_pricing_model_source_from_default(
    provider,
    self.proxy_pricing_model_source_for_app(provider.app_type),
  )
}

///|
fn provider_pricing_model_source_from_default(
  provider : ProviderRouteTarget,
  default_source : String,
) -> String {
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
fn ccs_config_app_from_request(path : StringView, body : Json?) -> String? {
  match proxy_string_request(path, body, ["app", "appType", "app_type"]) {
    Some(app) => Some(ccs_normalize_app_type(app))
    None => None
  }
}

///|
fn ccs_normalize_app_type(app : String) -> String {
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
fn ccs_home_dir() -> String {
  @os.home() catch {
    _ => "."
  }
}

///|
fn ccs_config_dir(app : String) -> String {
  let home = ccs_home_dir()
  match ccs_normalize_app_type(app) {
    "claude" => @pathx.join(home, ".claude")
    "claude-desktop" =>
      @pathx.join(@pathx.join(home, "Library/Application Support"), "Claude")
    "codex" => @pathx.join(home, ".codex")
    "gemini" => @pathx.join(home, ".gemini")
    "opencode" => @pathx.join(@pathx.join(home, ".config"), "opencode")
    "openclaw" => @pathx.join(home, ".openclaw")
    "hermes" => @pathx.join(home, ".hermes")
    "omo" | "omo-slim" => @pathx.join(@pathx.join(home, ".config"), "opencode")
    _ => @pathx.join(home, ".claude")
  }
}

///|
fn ccs_config_file_path(app : String) -> String {
  let dir = ccs_config_dir(app)
  match ccs_normalize_app_type(app) {
    "claude" => @pathx.join(dir, "settings.json")
    "claude-desktop" => @pathx.join(dir, "claude_desktop_config.json")
    "codex" => @pathx.join(dir, "config.toml")
    "gemini" => @pathx.join(dir, ".env")
    "opencode" | "omo" | "omo-slim" => @pathx.join(dir, "opencode.json")
    "openclaw" => @pathx.join(dir, "openclaw.json")
    "hermes" => @pathx.join(dir, "config.yaml")
    _ => @pathx.join(dir, "settings.json")
  }
}

///|
fn ccs_app_config_dir() -> String {
  @pathx.join(ccs_home_dir(), ".cc-switch")
}

///|
fn ccs_app_config_path() -> String {
  @pathx.join(ccs_app_config_dir(), "config.json")
}

///|
fn ccs_default_app_settings_json() -> Json {
  {
    "showInTray": Json::boolean(true),
    "minimizeToTrayOnClose": Json::boolean(true),
    "useAppWindowControls": Json::boolean(false),
    "enableClaudePluginIntegration": Json::boolean(false),
    "skipClaudeOnboarding": Json::boolean(false),
    "launchOnStartup": Json::boolean(false),
    "silentStartup": Json::boolean(false),
    "enableLocalProxy": Json::boolean(false),
    "enableFailoverToggle": Json::boolean(false),
    "preserveCodexOfficialAuthOnSwitch": Json::boolean(false),
    "skillSyncMethod": Json::string("auto"),
    "skillStorageLocation": Json::string("cc_switch"),
  }.to_json()
}

///|
fn ccs_default_rectifier_config_json() -> Json {
  {
    "enabled": Json::boolean(true),
    "requestThinkingSignature": Json::boolean(true),
    "requestThinkingBudget": Json::boolean(true),
    "requestMediaFallback": Json::boolean(true),
    "requestMediaHeuristic": Json::boolean(true),
  }.to_json()
}

///|
fn ccs_default_optimizer_config_json() -> Json {
  {
    "enabled": Json::boolean(false),
    "thinkingOptimizer": Json::boolean(true),
    "cacheInjection": Json::boolean(true),
    "cacheTtl": Json::string("1h"),
  }.to_json()
}

///|
fn ccs_default_copilot_optimizer_config_json() -> Json {
  {
    "enabled": Json::boolean(true),
    "requestClassification": Json::boolean(true),
    "toolResultMerging": Json::boolean(true),
    "compactDetection": Json::boolean(true),
    "deterministicRequestId": Json::boolean(true),
    "subagentDetection": Json::boolean(true),
    "warmupDowngrade": Json::boolean(true),
    "warmupModel": Json::string("gpt-5-mini"),
    "stripThinking": Json::boolean(true),
  }.to_json()
}

///|
fn ccs_default_log_config_json() -> Json {
  { "enabled": Json::boolean(true), "level": Json::string("info") }.to_json()
}

///|
fn ccs_claude_plugin_config_path() -> String {
  @pathx.join(ccs_config_dir("claude"), "config.json")
}

///|
fn ccs_openclaw_workspace_dir() -> String {
  @pathx.join(
    @pathx.join(@pathx.join(ccs_home_dir(), ".moonstat"), "openclaw"),
    "workspace",
  )
}

///|
fn ccs_openclaw_memory_dir() -> String {
  @pathx.join(ccs_openclaw_workspace_dir(), "memory")
}

///|
fn ccs_allowed_workspace_files() -> Array[String] {
  [
    "AGENTS.md", "SOUL.md", "USER.md", "IDENTITY.md", "TOOLS.md", "MEMORY.md", "HEARTBEAT.md",
    "BOOTSTRAP.md", "BOOT.md",
  ]
}

///|
fn ccs_validate_workspace_filename(filename : String) -> Bool {
  ccs_allowed_workspace_files().contains(filename)
}

///|
fn ccs_validate_daily_memory_filename(filename : String) -> Bool {
  filename.length() == 13 &&
  filename.has_suffix(".md") &&
  ccs_ascii_digit_at(filename, 0) &&
  ccs_ascii_digit_at(filename, 1) &&
  ccs_ascii_digit_at(filename, 2) &&
  ccs_ascii_digit_at(filename, 3) &&
  filename[4] == '-' &&
  ccs_ascii_digit_at(filename, 5) &&
  ccs_ascii_digit_at(filename, 6) &&
  filename[7] == '-' &&
  ccs_ascii_digit_at(filename, 8) &&
  ccs_ascii_digit_at(filename, 9) &&
  filename[10] == '.'
}

///|
fn ccs_daily_memory_list_filename(filename : String) -> Bool {
  filename.has_suffix(".md")
}

///|
fn ccs_ascii_digit_at(value : String, index : Int) -> Bool {
  let ch = value[index]
  ch >= '0' && ch <= '9'
}

///|
fn ccs_daily_memory_date(filename : String) -> String {
  if filename.has_suffix(".md") && filename.length() >= 3 {
    filename[:filename.length() - 3].to_owned()
  } else if filename.length() >= 10 {
    filename[:10].to_owned()
  } else {
    filename
  }
}

///|
fn ccs_workspace_file_path(filename : String) -> String {
  @pathx.join(ccs_openclaw_workspace_dir(), filename)
}

///|
fn ccs_daily_memory_file_path(filename : String) -> String {
  @pathx.join(ccs_openclaw_memory_dir(), filename)
}

///|
async fn ccs_ensure_directory(path : String) -> Bool {
  @fsx.make_directory(path, recursive=true, exists_ok=true) catch {
    _ => return false
  }
  true
}

///|
async fn ccs_open_directory_result_json(path : String) -> Result[Json, String] {
  if !ccs_ensure_directory(path) {
    return Err("open_directory_create_failed")
  }
  Ok(Json::boolean(true))
}

///|
fn ccs_file_mtime(path : String) -> Int64 {
  let stat = @fsx.stat(path) catch { _ => return 0L }
  stat.mtime()
}

///|
fn ccs_preview(content : String, limit : Int) -> String {
  if content.length() <= limit {
    content
  } else {
    content[:limit].to_owned()
  }
}

///|
fn ccs_search_snippet(content : String, first_pos : Int) -> String {
  let start = if first_pos > 50 { first_pos - 50 } else { 0 }
  let end = if first_pos + 70 < content.length() {
    first_pos + 70
  } else {
    content.length()
  }
  let prefix = if start > 0 { "..." } else { "" }
  let suffix = if end < content.length() { "..." } else { "" }
  "\{prefix}\{content[start:end]}\{suffix}"
}

///|
fn ccs_count_case_insensitive_matches(
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
async fn ccs_daily_memory_info_json(path : String, filename : String) -> Json {
  let content = @fsx.read_file(path) catch { _ => "" }
  let modified_at = ccs_file_mtime(path)
  {
    "filename": Json::string(filename),
    "date": Json::string(ccs_daily_memory_date(filename)),
    "sizeBytes": Json::number(content.length().to_double()),
    "modifiedAt": Json::number(modified_at.to_double()),
    "preview": Json::string(ccs_preview(content, 200)),
  }.to_json()
}

///|
async fn ccs_list_daily_memory_files_json() -> Json {
  let memory_dir = ccs_openclaw_memory_dir()
  if !@fsx.exists(memory_dir) {
    return Json::array([])
  }
  let filenames : Array[String] = []
  let rows_by_filename : Map[String, Json] = {}
  let rows : Array[Json] = []
  let entries = @fsx.list_directory(memory_dir) catch {
    _ => return Json::array([])
  }
  for entry in entries {
    if entry.kind is @fsx.FileKind::Regular &&
      ccs_daily_memory_list_filename(entry.name) {
      filenames.push(entry.name)
      rows_by_filename[entry.name] = ccs_daily_memory_info_json(
        entry.path,
        entry.name,
      )
    }
  }
  filenames.sort()
  let mut index = filenames.length() - 1
  while index >= 0 {
    guard rows_by_filename.get(filenames[index]) is Some(row) else {
      index = index - 1
      continue
    }
    rows.push(row)
    index = index - 1
  }
  Json::array(rows)
}

///|
async fn ccs_search_daily_memory_files_json(query : String) -> Json {
  let trimmed = query.trim().to_owned()
  let memory_dir = ccs_openclaw_memory_dir()
  if trimmed.is_empty() || !@fsx.exists(memory_dir) {
    return Json::array([])
  }
  let filenames : Array[String] = []
  let rows_by_filename : Map[String, Json] = {}
  let rows : Array[Json] = []
  let entries = @fsx.list_directory(memory_dir) catch {
    _ => return Json::array([])
  }
  for entry in entries {
    if !(entry.kind is @fsx.FileKind::Regular) ||
      !ccs_daily_memory_list_filename(entry.name) {
      continue
    }
    let content = @fsx.read_file(entry.path) catch { _ => "" }
    let date = ccs_daily_memory_date(entry.name)
    let (content_count, first_pos) = ccs_count_case_insensitive_matches(
      content, trimmed,
    )
    let (date_count, _) = ccs_count_case_insensitive_matches(date, trimmed)
    if content_count == 0 && date_count == 0 {
      continue
    }
    let snippet = match first_pos {
      Some(pos) => ccs_search_snippet(content, pos)
      None => ccs_preview(content, 120)
    }
    let modified_at = ccs_file_mtime(entry.path)
    filenames.push(entry.name)
    rows_by_filename[entry.name] = {
      "filename": Json::string(entry.name),
      "date": Json::string(date),
      "sizeBytes": Json::number(content.length().to_double()),
      "modifiedAt": Json::number(modified_at.to_double()),
      "snippet": Json::string(snippet),
      "matchCount": Json::number((content_count + date_count).to_double()),
    }.to_json()
  }
  filenames.sort()
  let mut index = filenames.length() - 1
  while index >= 0 {
    guard rows_by_filename.get(filenames[index]) is Some(row) else {
      index = index - 1
      continue
    }
    rows.push(row)
    index = index - 1
  }
  Json::array(rows)
}

///|
fn ccs_merge_settings_for_save(incoming : Json, existing : Json) -> Json {
  guard incoming is Object(incoming_obj) else { return existing }
  guard existing is Object(existing_obj) else { return incoming }
  let next = incoming_obj
  ccs_preserve_missing_settings_object(next, existing_obj, "webdavSync")
  ccs_preserve_missing_settings_object(next, existing_obj, "webdav_sync")
  ccs_preserve_missing_settings_object(next, existing_obj, "s3Sync")
  ccs_preserve_missing_settings_object(next, existing_obj, "s3_sync")
  ccs_preserve_missing_settings_object(next, existing_obj, "localMigrations")
  ccs_preserve_missing_settings_object(next, existing_obj, "local_migrations")
  ccs_preserve_secret_if_empty(next, existing_obj, "webdavSync", "password")
  ccs_preserve_secret_if_empty(next, existing_obj, "webdav_sync", "password")
  ccs_preserve_secret_if_empty(next, existing_obj, "s3Sync", "secretAccessKey")
  ccs_preserve_secret_if_empty(
    next, existing_obj, "s3_sync", "secret_access_key",
  )
  Json::object(next)
}

///|
fn ccs_preserve_missing_settings_object(
  incoming : Map[String, Json],
  existing : Map[String, Json],
  key : String,
) -> Unit {
  if incoming.get(key) is None {
    match existing.get(key) {
      Some(value) => incoming[key] = value
      None => ()
    }
  }
}

///|
fn ccs_preserve_secret_if_empty(
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
fn ccs_settings_with_bool(settings : Json, key : String, value : Bool) -> Json {
  match settings {
    Object(obj) => {
      obj[key] = Json::boolean(value)
      Json::object(obj)
    }
    _ => {
      let obj : Map[String, Json] = {}
      obj[key] = Json::boolean(value)
      Json::object(obj)
    }
  }
}

///|
fn ccs_optional_path_from_request(path : StringView, body : Json?) -> String? {
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
fn ccs_json_config_from_request(
  path : StringView,
  body : Json?,
  current : Json,
  setters : Array[(String, Array[String], String)],
) -> Json {
  let base = match proxy_embedded_config(body) {
    Some(Object(obj)) => Json::object(obj)
    Some(json) => json
    None => current
  }
  match base {
    Object(obj) => {
      for setter in setters {
        let (field, keys, kind) = setter
        match kind {
          "bool" =>
            match proxy_bool_request(path, body, keys) {
              Some(value) => obj[field] = Json::boolean(value)
              None => ()
            }
          "string" =>
            match proxy_string_request(path, body, keys) {
              Some(value) => obj[field] = Json::string(value)
              None => ()
            }
          _ => ()
        }
      }
      Json::object(obj)
    }
    _ => base
  }
}

///|
fn ccs_rectifier_config_from_request(
  path : StringView,
  body : Json?,
  current : Json,
) -> Json {
  ccs_json_config_from_request(path, body, current, [
    ("enabled", ["enabled"], "bool"),
    (
      "requestThinkingSignature",
      ["requestThinkingSignature", "request_thinking_signature"],
      "bool",
    ),
    (
      "requestThinkingBudget",
      ["requestThinkingBudget", "request_thinking_budget"],
      "bool",
    ),
    (
      "requestMediaFallback",
      ["requestMediaFallback", "request_media_fallback"],
      "bool",
    ),
    (
      "requestMediaHeuristic",
      ["requestMediaHeuristic", "request_media_heuristic"],
      "bool",
    ),
  ])
}

///|
fn ccs_optimizer_config_from_request(
  path : StringView,
  body : Json?,
  current : Json,
) -> Json {
  ccs_json_config_from_request(path, body, current, [
    ("enabled", ["enabled"], "bool"),
    ("thinkingOptimizer", ["thinkingOptimizer", "thinking_optimizer"], "bool"),
    ("cacheInjection", ["cacheInjection", "cache_injection"], "bool"),
    ("cacheTtl", ["cacheTtl", "cache_ttl"], "string"),
  ])
}

///|
fn ccs_copilot_optimizer_config_from_request(
  path : StringView,
  body : Json?,
  current : Json,
) -> Json {
  ccs_json_config_from_request(path, body, current, [
    ("enabled", ["enabled"], "bool"),
    (
      "requestClassification",
      ["requestClassification", "request_classification"],
      "bool",
    ),
    ("toolResultMerging", ["toolResultMerging", "tool_result_merging"], "bool"),
    ("compactDetection", ["compactDetection", "compact_detection"], "bool"),
    (
      "deterministicRequestId",
      ["deterministicRequestId", "deterministic_request_id"],
      "bool",
    ),
    ("subagentDetection", ["subagentDetection", "subagent_detection"], "bool"),
    ("warmupDowngrade", ["warmupDowngrade", "warmup_downgrade"], "bool"),
    ("warmupModel", ["warmupModel", "warmup_model"], "string"),
    ("stripThinking", ["stripThinking", "strip_thinking"], "bool"),
  ])
}

///|
fn ccs_log_config_from_request(
  path : StringView,
  body : Json?,
  current : Json,
) -> Json {
  ccs_json_config_from_request(path, body, current, [
    ("enabled", ["enabled"], "bool"),
    ("level", ["level"], "string"),
  ])
}

///|
fn ccs_optimizer_cache_ttl_valid(config : Json) -> Bool {
  guard config is Object(obj) else { return true }
  match json_string_from_map_any(obj, ["cacheTtl", "cache_ttl"]) {
    Some("5m") | Some("1h") | None => true
    _ => false
  }
}

///|
fn ccs_json_primary_api_key_any(content : String) -> Bool {
  let parsed : Result[Json, Error] = try? @json.parse(content)
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
async fn ccs_config_status_json(app : String) -> Json {
  let normalized = ccs_normalize_app_type(app)
  let path = match normalized {
    "codex" => ccs_config_dir(normalized)
    "gemini" | "opencode" | "openclaw" | "hermes" | "claude-desktop" =>
      ccs_config_dir(normalized)
    _ => ccs_config_file_path(normalized)
  }
  {
    "exists": Json::boolean(ccs_config_exists(normalized)),
    "path": Json::string(path),
  }.to_json()
}

///|
async fn ccs_config_exists(app : String) -> Bool {
  let normalized = ccs_normalize_app_type(app)
  match normalized {
    "codex" =>
      @fsx.exists_as_file(@pathx.join(ccs_config_dir("codex"), "auth.json")) ||
      @fsx.exists_as_file(ccs_config_file_path("codex"))
    "gemini"
    | "opencode"
    | "openclaw"
    | "hermes"
    | "claude"
    | "claude-desktop" => @fsx.exists_as_file(ccs_config_file_path(normalized))
    _ => @fsx.exists_as_file(ccs_config_file_path(normalized))
  }
}

///|
async fn ccs_env_conflicts_json(app : String) -> Json {
  ccs_env_conflicts_json_with_shell_files(app, ccs_env_shell_config_paths())
}

///|
async fn ccs_env_conflicts_json_with_shell_files(
  app : String,
  shell_files : Array[String],
) -> Json {
  let conflicts : Array[Json] = []
  for key in ccs_env_conflict_keys(ccs_normalize_app_type(app)) {
    match getenv_or_none(key) {
      Some(value) if !value.trim().is_empty() =>
        conflicts.push(
          {
            "varName": Json::string(key),
            "varValue": Json::string(value),
            "sourceType": Json::string("system"),
            "sourcePath": Json::string("Process Environment"),
          }.to_json(),
        )
      _ => ()
    }
  }
  for file_path in shell_files {
    ccs_push_shell_env_conflicts(
      conflicts,
      file_path,
      ccs_env_conflict_keys(ccs_normalize_app_type(app)),
    )
  }
  Json::array(conflicts)
}

///|
async fn ccs_push_shell_env_conflicts(
  conflicts : Array[Json],
  file_path : String,
  keywords : Array[String],
) -> Unit {
  let content = @fsx.read_file(file_path) catch { _ => return }
  let mut line_number = 0
  for line_view in content.split("\n") {
    line_number += 1
    let trimmed = line_view.to_owned().trim().to_owned()
    guard ccs_env_assignment_line(trimmed) is Some((var_name, var_value)) else {
      continue
    }
    if ccs_env_name_matches_keywords(var_name, keywords) {
      conflicts.push(
        {
          "varName": Json::string(var_name),
          "varValue": Json::string(ccs_trim_env_value_quotes(var_value)),
          "sourceType": Json::string("file"),
          "sourcePath": Json::string("\{file_path}:\{line_number}"),
        }.to_json(),
      )
    }
  }
}

///|
fn ccs_env_shell_config_paths() -> Array[String] {
  let home = ccs_home_dir()
  [
    @pathx.join(home, ".bashrc"),
    @pathx.join(home, ".bash_profile"),
    @pathx.join(home, ".zshrc"),
    @pathx.join(home, ".zprofile"),
    @pathx.join(home, ".profile"),
    "/etc/profile",
    "/etc/bashrc",
  ]
}

///|
fn ccs_env_conflict_keys(app : String) -> Array[String] {
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
fn ccs_env_backup_json(body : Json?) -> Json {
  let conflicts = ccs_env_conflicts_from_body(body)
  let timestamp = @async.now().to_int().to_string()
  {
    "backupPath": Json::string(
      @pathx.join(
        @pathx.join(ccs_app_config_dir(), "backups"),
        "env-backup-\{timestamp}.json",
      ),
    ),
    "timestamp": Json::string(timestamp),
    "conflicts": Json::array(conflicts),
  }.to_json()
}

///|
async fn ccs_delete_env_vars_json(body : Json?) -> Result[Json, String] {
  let backup = ccs_env_backup_json(body)
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
  for conflict in ccs_env_conflicts_from_body(body) {
    match ccs_delete_single_env_conflict(conflict) {
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
async fn ccs_delete_single_env_conflict(
  conflict : Json,
) -> Result[Unit, String] {
  guard conflict is Object(obj) else { return Err("invalid_conflict") }
  let source_type = ccs_env_conflict_string(obj, "sourceType", "source_type")
  let var_name = ccs_env_conflict_string(obj, "varName", "var_name")
  let source_path = ccs_env_conflict_string(obj, "sourcePath", "source_path")
  match (source_type, var_name, source_path) {
    (Some("file"), Some(var_name), Some(source_path)) => {
      let file_path = ccs_env_source_file_path(source_path)
      guard !file_path.is_empty() else {
        return Err("无效的文件路径格式")
      }
      let content = @fsx.read_file(file_path) catch {
        error => return Err("读取文件失败 \{file_path}: \{error}")
      }
      let kept : Array[String] = []
      for line_view in content.split("\n") {
        let line = line_view.to_owned()
        match ccs_env_assignment_line(line.trim().to_owned()) {
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
async fn ccs_restore_env_backup_json(
  backup_path : String?,
) -> Result[Json, String] {
  guard backup_path is Some(path) else { return Err("missing_backup_path") }
  let content = @fsx.read_file(path) catch {
    error => return Err("读取备份文件失败: \{error}")
  }
  let parsed = @json.parse(content) catch {
    error => return Err("解析备份文件失败: \{error}")
  }
  for conflict in ccs_env_conflicts_from_body(Some(parsed)) {
    match ccs_restore_single_env_conflict(conflict) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  Ok(Json::null())
}

///|
async fn ccs_restore_single_env_conflict(
  conflict : Json,
) -> Result[Unit, String] {
  guard conflict is Object(obj) else { return Err("invalid_conflict") }
  let source_type = ccs_env_conflict_string(obj, "sourceType", "source_type")
  let var_name = ccs_env_conflict_string(obj, "varName", "var_name")
  let var_value = ccs_env_conflict_string(obj, "varValue", "var_value")
  let source_path = ccs_env_conflict_string(obj, "sourcePath", "source_path")
  match (source_type, var_name, var_value, source_path) {
    (Some("file"), Some(var_name), Some(var_value), Some(source_path)) => {
      let file_path = ccs_env_source_file_path(source_path)
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
fn ccs_env_conflicts_from_body(body : Json?) -> Array[Json] {
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
fn ccs_env_conflict_string(
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
fn ccs_env_source_file_path(source_path : String) -> String {
  match source_path.find(":") {
    Some(index) => source_path[:index].to_owned()
    None => source_path
  }
}

///|
fn ccs_env_assignment_line(line : String) -> (String, String)? {
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
fn ccs_env_name_matches_keywords(
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
fn ccs_trim_env_value_quotes(value : String) -> String {
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
fn ccs_json_request(
  path : StringView,
  body : Json?,
  keys : Array[String],
) -> Json? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) => return Some(ccs_json_value_from_string(value))
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
fn ccs_json_value_from_string(value : String) -> Json {
  try @json.parse(value) catch {
    _ => Json::string(value)
  } noraise {
    parsed => parsed
  }
}

///|
fn ccs_mcp_apps_json(app : String, enabled? : Bool = true) -> Json {
  let apps = {
    "claude": Json::boolean(false),
    "claude-desktop": Json::boolean(false),
    "codex": Json::boolean(false),
    "gemini": Json::boolean(false),
    "opencode": Json::boolean(false),
    "openclaw": Json::boolean(false),
    "hermes": Json::boolean(false),
  }
  apps[ccs_normalize_app_type(app)] = Json::boolean(enabled)
  Json::object(apps)
}

///|
fn ccs_mcp_app_enabled(server : Json, app : String) -> Bool {
  guard server is Object(obj) else { return false }
  guard obj.get("apps") is Some(Object(apps)) else { return false }
  match apps.get(ccs_normalize_app_type(app)) {
    Some(true) => true
    Some(false) => false
    _ => false
  }
}

///|
fn ccs_mcp_server_with_app(server : Json, app : String, enabled : Bool) -> Json {
  let normalized = ccs_normalize_app_type(app)
  match server {
    Object(obj) => {
      let next = obj
      let apps = match obj.get("apps") {
        Some(Object(existing)) => existing
        _ =>
          match ccs_mcp_apps_json("claude", enabled=false) {
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
fn ccs_mcp_server_from_request(
  path : StringView,
  body : Json?,
  default_app : String,
) -> (String, Json)? {
  match ccs_json_request(path, body, ["server"]) {
    Some(Object(server)) =>
      match json_string_from_map_any(server, ["id", "serverId", "server_id"]) {
        Some(id) =>
          return Some(
            (
              id,
              ccs_mcp_normalize_server(id, Json::object(server), default_app),
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
  let spec = ccs_json_request(path, body, ["spec", "server"]).unwrap_or(
    Json::object({}),
  )
  Some((id, ccs_mcp_server_from_spec(id, spec, default_app)))
}

///|
fn ccs_mcp_server_from_spec(id : String, spec : Json, app : String) -> Json {
  let name = match spec {
    Object(obj) => json_string_from_map_any(obj, ["name"]).unwrap_or(id)
    _ => id
  }
  Json::object({
    "id": Json::string(id),
    "name": Json::string(name),
    "server": spec,
    "apps": ccs_mcp_apps_json(app),
    "description": Json::null(),
    "homepage": Json::null(),
    "docs": Json::null(),
    "tags": Json::array([]),
  })
}

///|
fn ccs_mcp_normalize_server(
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
        next["apps"] = ccs_mcp_apps_json(default_app)
      }
      if next.get("tags") is None {
        next["tags"] = Json::array([])
      }
      Json::object(next)
    }
    _ => ccs_mcp_server_from_spec(id, Json::object({}), default_app)
  }
}

///|
fn ccs_mcp_servers_object_for_app(
  servers : Map[String, Json],
  app : String?,
) -> Json {
  let result : Map[String, Json] = {}
  for id in servers.keys() {
    guard servers.get(id) is Some(server) else { continue }
    match app {
      Some(app_type) =>
        if ccs_mcp_app_enabled(server, app_type) {
          result[id] = server
        }
      None => result[id] = server
    }
  }
  Json::object(result)
}

///|
fn ccs_mcp_config_text(servers : Map[String, Json]) -> String? {
  if servers.is_empty() {
    return None
  }
  let mcp_servers : Map[String, Json] = {}
  for id in servers.keys() {
    guard servers.get(id) is Some(Object(server)) else { continue }
    match server.get("server") {
      Some(spec) => mcp_servers[id] = spec
      None => ()
    }
  }
  Some(
    Json::object({ "mcpServers": Json::object(mcp_servers) }).stringify(
      indent=2,
    ),
  )
}

///|
fn ccs_mcp_valid_server_spec(spec : Json) -> Bool {
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
fn ccs_mcp_import_spec_for_app(app : String, spec : Json) -> Json {
  let normalized = ccs_normalize_app_type(app)
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
fn ccs_import_mcp_servers_map(
  servers : Map[String, Json],
  app : String,
  mcp_servers : Map[String, Json],
) -> Int {
  let mut changed = 0
  for id in mcp_servers.keys() {
    guard mcp_servers.get(id) is Some(spec) else { continue }
    let import_spec = ccs_mcp_import_spec_for_app(app, spec)
    if !ccs_mcp_valid_server_spec(import_spec) {
      continue
    }
    match servers.get(id) {
      Some(existing) =>
        if !ccs_mcp_app_enabled(existing, app) {
          servers[id] = ccs_mcp_server_with_app(existing, app, true)
          changed += 1
        }
      None => {
        servers[id] = ccs_mcp_server_from_spec(id, import_spec, app)
        changed += 1
      }
    }
  }
  changed
}

///|
fn ccs_import_mcp_from_root_json(
  servers : Map[String, Json],
  app : String,
  root : Json,
) -> Int {
  guard root is Object(obj) else { return 0 }
  guard obj.get("mcpServers") is Some(Object(mcp_servers)) else { return 0 }
  ccs_import_mcp_servers_map(servers, app, mcp_servers)
}

///|
fn ccs_import_mcp_from_codex_toml_text(
  servers : Map[String, Json],
  content : String,
) -> Int {
  let raw_specs : Map[String, Json] = {}
  let mut current_id : String? = None
  let mut current_table = ""
  for line_view in content.split("\n") {
    let line = ccs_toml_strip_comment(line_view.to_owned()).trim().to_owned()
    if line.is_empty() {
      continue
    }
    if line.has_prefix("[") && line.has_suffix("]") {
      let section = line[1:line.length() - 1].trim().to_owned()
      match ccs_codex_mcp_section(section) {
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
    guard ccs_toml_assignment(line) is Some((key, raw_value)) else { continue }
    let spec = ccs_codex_raw_mcp_spec(raw_specs, id)
    if current_table.is_empty() {
      match ccs_toml_value(raw_value) {
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
      match ccs_toml_value(raw_value) {
        Some(String(value)) => nested[key] = Json::string(value)
        _ => ()
      }
    }
    raw_specs[id] = Json::object(spec)
  }
  let normalized : Map[String, Json] = {}
  for id in raw_specs.keys() {
    guard raw_specs.get(id) is Some(raw_spec) else { continue }
    normalized[id] = ccs_codex_mcp_unified_spec(raw_spec)
  }
  ccs_import_mcp_servers_map(servers, "codex", normalized)
}

///|
fn ccs_codex_raw_mcp_spec(
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
fn ccs_codex_mcp_section(section : String) -> (String, String)? {
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
fn ccs_codex_mcp_unified_spec(raw_spec : Json) -> Json {
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
    if ccs_codex_mcp_core_field(typ, key) {
      continue
    }
    guard raw.get(key) is Some(value) else { continue }
    spec[key] = value
  }
  Json::object(spec)
}

///|
fn ccs_codex_mcp_core_field(typ : String, key : String) -> Bool {
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
fn ccs_toml_strip_comment(line : String) -> String {
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
fn ccs_toml_assignment(line : String) -> (String, String)? {
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
fn ccs_toml_value(raw : String) -> Json? {
  let value = raw.trim().to_owned()
  if value.is_empty() {
    return None
  }
  if value.has_prefix("[") && value.has_suffix("]") {
    let items : Array[Json] = []
    for item in ccs_toml_split_csv(value[1:value.length() - 1].to_owned()) {
      match ccs_toml_value(item) {
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
    for item in ccs_toml_split_csv(value[1:value.length() - 1].to_owned()) {
      match ccs_toml_assignment(item) {
        Some((key, nested_raw)) =>
          match ccs_toml_value(nested_raw) {
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
fn ccs_toml_split_csv(text : String) -> Array[String] {
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
fn ccs_validate_common_config_snippet(
  app_type : String,
  snippet : String,
) -> String? {
  if snippet.trim().is_empty() {
    return None
  }
  match app_type {
    "claude" | "gemini" | "omo" | "omo-slim" => {
      ignore(
        @json.parse(snippet) catch {
          err => return Some("Invalid JSON format: \{err}")
        },
      )
      None
    }
    "codex" =>
      if ccs_validate_codex_toml_snippet(snippet) {
        None
      } else {
        Some("Invalid TOML format")
      }
    _ => None
  }
}

///|
fn ccs_validate_codex_toml_snippet(snippet : String) -> Bool {
  for line_view in snippet.split("\n") {
    let line = ccs_toml_strip_comment(line_view.to_owned()).trim().to_owned()
    if line.is_empty() {
      continue
    }
    if line.has_prefix("[") {
      if !line.has_suffix("]") {
        return false
      }
      let section = line[1:line.length() - 1].trim()
      if section.is_empty() {
        return false
      }
      continue
    }
    if line.has_suffix("]") {
      return false
    }
    if ccs_toml_assignment(line) is None {
      return false
    }
  }
  true
}

///|
fn ccs_extract_common_config_snippet_from_settings_config(
  app_type : String,
  settings_config : String,
) -> Result[String, String] {
  let parsed = @json.parse(settings_config) catch {
    err => return Err("Invalid JSON format: \{err}")
  }
  Ok(ccs_extract_common_config_snippet_json(app_type, parsed))
}

///|
fn ccs_extract_common_config_snippet_json(
  app_type : String,
  settings : Json,
) -> String {
  match app_type {
    "claude" => ccs_extract_claude_common_config(settings)
    "codex" => ccs_extract_codex_common_config(settings)
    "gemini" => ccs_extract_gemini_common_config(settings)
    "opencode" => ccs_extract_opencode_common_config(settings)
    "openclaw" => ccs_extract_openclaw_common_config(settings)
    _ => ""
  }
}

///|
fn ccs_extract_claude_common_config(settings : Json) -> String {
  guard settings is Object(config) else { return "{}" }
  match config.get("env") {
    Some(Object(env)) => {
      for
        key in [
          "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_MODEL", "ANTHROPIC_REASONING_MODEL",
          "ANTHROPIC_DEFAULT_HAIKU_MODEL", "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME",
          "ANTHROPIC_DEFAULT_OPUS_MODEL", "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME", "ANTHROPIC_DEFAULT_SONNET_MODEL",
          "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME", "ANTHROPIC_BASE_URL",
        ] {
        env.remove(key)
      }
      if env.length() == 0 {
        config.remove("env")
      } else {
        config["env"] = Json::object(env)
      }
    }
    _ => ()
  }
  for key in ["apiBaseUrl", "primaryModel", "smallFastModel"] {
    config.remove(key)
  }
  if config.length() == 0 {
    "{}"
  } else {
    Json::object(config).stringify(indent=2)
  }
}

///|
fn ccs_extract_codex_common_config(settings : Json) -> String {
  guard settings is Object(config) else { return "" }
  let toml = json_string_from_map_any(config, ["config"]).unwrap_or("")
  if toml.is_empty() {
    return ""
  }
  ccs_extract_codex_common_config_from_toml(toml)
}

///|
fn ccs_extract_codex_common_config_from_toml(toml : String) -> String {
  let lines : Array[String] = []
  let mut skip_model_providers = false
  let mut current_section = ""
  for line_view in toml.split("\n") {
    let original = line_view.to_owned()
    let stripped = ccs_toml_strip_comment(original).trim().to_owned()
    if stripped.has_prefix("[") && stripped.has_suffix("]") {
      let section = stripped[1:stripped.length() - 1].trim().to_owned()
      current_section = section
      skip_model_providers = section == "model_providers" ||
        section.has_prefix("model_providers.")
      if skip_model_providers {
        continue
      }
      lines.push(original.trim_end().to_owned())
      continue
    }
    if skip_model_providers {
      continue
    }
    if current_section.is_empty() {
      match ccs_toml_assignment(stripped) {
        Some((key, _)) if key == "model" ||
          key == "model_provider" ||
          key == "base_url" => continue
        _ => ()
      }
    }
    lines.push(original.trim_end().to_owned())
  }
  ccs_clean_blank_lines(lines).trim().to_owned()
}

///|
fn ccs_clean_blank_lines(lines : Array[String]) -> String {
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
fn ccs_extract_gemini_common_config(settings : Json) -> String {
  guard settings is Object(config) else { return "{}" }
  let snippet : Map[String, Json] = {}
  match config.get("env") {
    Some(Object(env)) =>
      for key in env.keys() {
        if key == "GOOGLE_GEMINI_BASE_URL" || key == "GEMINI_API_KEY" {
          continue
        }
        match env.get(key) {
          Some(String(value)) if !value.trim().is_empty() =>
            snippet[key] = Json::string(value.trim().to_owned())
          _ => ()
        }
      }
    _ => ()
  }
  if snippet.length() == 0 {
    "{}"
  } else {
    Json::object(snippet).stringify(indent=2)
  }
}

///|
fn ccs_extract_opencode_common_config(settings : Json) -> String {
  guard settings is Object(config) else { return "{}" }
  match config.get("options") {
    Some(Object(options)) => {
      options.remove("apiKey")
      options.remove("baseURL")
      config["options"] = Json::object(options)
    }
    _ => ()
  }
  if config.length() == 0 {
    "{}"
  } else {
    Json::object(config).stringify(indent=2)
  }
}

///|
fn ccs_extract_openclaw_common_config(settings : Json) -> String {
  guard settings is Object(config) else { return "{}" }
  config.remove("apiKey")
  config.remove("baseUrl")
  if config.length() == 0 {
    "{}"
  } else {
    Json::object(config).stringify(indent=2)
  }
}

///|
async fn ccs_import_mcp_from_codex_file(
  servers : Map[String, Json],
  file_path : String,
) -> Int {
  if !(@fsx.exists_as_file(file_path) catch { _ => false }) {
    return 0
  }
  let content = @fsx.read_file(file_path) catch { _ => return 0 }
  ccs_import_mcp_from_codex_toml_text(servers, content)
}

///|
async fn ccs_import_mcp_from_file(
  servers : Map[String, Json],
  app : String,
  file_path : String,
) -> Int {
  if !(@fsx.exists_as_file(file_path) catch { _ => false }) {
    return 0
  }
  let content = @fsx.read_file(file_path) catch { _ => return 0 }
  let root = @json.parse(content) catch { _ => return 0 }
  ccs_import_mcp_from_root_json(servers, app, root)
}

///|
async fn ccs_import_mcp_from_apps_count(servers : Map[String, Json]) -> Int {
  let mut total = 0
  total += ccs_import_mcp_from_file(
    servers,
    "claude",
    @pathx.join(ccs_home_dir(), ".claude.json"),
  )
  total += ccs_import_mcp_from_codex_file(
    servers,
    ccs_config_file_path("codex"),
  )
  total += ccs_import_mcp_from_file(
    servers,
    "gemini",
    @pathx.join(ccs_config_dir("gemini"), "settings.json"),
  )
  total
}

///|
fn ccs_validate_mcp_command_name(command : String) -> Bool {
  let trimmed = command.trim()
  !trimmed.is_empty() &&
  !trimmed.contains("/") &&
  !trimmed.contains("\\") &&
  !trimmed.contains("\u{0000}")
}

///|
fn ccs_prompt_store_key(app : String, id : String) -> String {
  "\{ccs_normalize_app_type(app)}:\{id}"
}

///|
fn ccs_prompt_file_path(app : String) -> Result[String, String] {
  let normalized = ccs_normalize_app_type(app)
  if normalized == "claude-desktop" {
    return Err("Claude Desktop 暂不支持 Prompts")
  }
  let filename = match normalized {
    "claude" => "CLAUDE.md"
    "gemini" => "GEMINI.md"
    "codex" | "opencode" | "openclaw" | "hermes" | "omo" | "omo-slim" =>
      "AGENTS.md"
    _ => "CLAUDE.md"
  }
  Ok(@pathx.join(ccs_config_dir(normalized), filename))
}

///|
fn ccs_prompt_file_path_from_request(
  path : StringView,
  body : Json?,
  app : String,
) -> Result[String, String] {
  match proxy_string_request(path, body, ["path", "filePath", "file_path"]) {
    Some(file_path) => Ok(file_path)
    None => ccs_prompt_file_path(app)
  }
}

///|
fn ccs_prompt_from_request(
  path : StringView,
  body : Json?,
) -> (String, String, Json)? {
  let app = ccs_config_app_from_request(path, body).unwrap_or("claude")
  match ccs_json_request(path, body, ["prompt"]) {
    Some(Object(prompt)) =>
      match json_string_from_map_any(prompt, ["id"]) {
        Some(id) =>
          return Some((app, id, ccs_normalize_prompt(id, Json::object(prompt))))
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
async fn ccs_import_prompt_from_file_json(
  prompts : Map[String, Json],
  app : String,
  file_path : String,
) -> Result[Json, String] {
  if !(@fsx.exists_as_file(file_path) catch { _ => false }) {
    return Err("提示词文件不存在")
  }
  let content = @fsx.read_file(file_path) catch {
    error => return Err("读取提示词文件失败: \{error}")
  }
  let timestamp = @async.now().to_int()
  let timestamp_text = timestamp.to_string()
  let id = "imported-\{timestamp_text}"
  let prompt = {
    "id": Json::string(id),
    "name": Json::string(
      "导入的提示词 \{@os.local_rfc3339(timestamp.to_int64())}",
    ),
    "content": Json::string(content),
    "description": Json::string("从现有配置文件导入"),
    "enabled": Json::boolean(false),
    "createdAt": Json::string(timestamp_text),
    "updatedAt": Json::string(timestamp_text),
  }.to_json()
  prompts[ccs_prompt_store_key(app, id)] = prompt
  Ok(Json::string(id))
}

///|
async fn ccs_current_prompt_file_content_json(
  file_path : String,
) -> Result[Json, String] {
  if !(@fsx.exists_as_file(file_path) catch { _ => false }) {
    return Ok(Json::null())
  }
  let content = @fsx.read_file(file_path) catch {
    error => return Err("读取提示词文件失败: \{error}")
  }
  Ok(Json::string(content))
}

///|
async fn ccs_enable_prompt_json(
  prompts : Map[String, Json],
  app : String,
  id : String,
  file_path : String,
) -> Result[Json, String] {
  let normalized = ccs_normalize_app_type(app)
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
fn ccs_normalize_prompt(id : String, prompt : Json) -> Json {
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
fn ccs_prompts_object_for_app(
  prompts : Map[String, Json],
  app : String,
) -> Json {
  let normalized = ccs_normalize_app_type(app)
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
  ccs_streaming_request(endpoint, body, {})
}

///|
fn ccs_streaming_request(
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
async fn Gateway::handle_get_config_status(
  self : Gateway,
  w : @httpx.ResponseWriter,
  app : String,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_config_status_json(app))
}

///|
async fn Gateway::handle_get_config_status_request(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let app = ccs_config_app_from_request(r.path, None).unwrap_or("claude")
  write_usage_json(w, ccs_config_status_json(app))
}

///|
async fn Gateway::handle_get_claude_code_config_path(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::string(ccs_config_file_path("claude")))
}

///|
async fn Gateway::handle_get_config_dir(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let app = ccs_config_app_from_request(r.path, None).unwrap_or("claude")
  write_usage_json(w, Json::string(ccs_config_dir(app)))
}

///|
async fn Gateway::handle_open_config_folder(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let app = ccs_config_app_from_request(r.path, None).unwrap_or("claude")
  match ccs_open_directory_result_json(ccs_config_dir(app)) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_pick_directory(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(
    w,
    match usage_query_value_any(r.path, "default_path", "defaultPath") {
      Some(path) => Json::string(path)
      None => Json::null()
    },
  )
}

///|
async fn Gateway::handle_open_external(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let raw_url = proxy_string_request(r.path, body, ["url"]).unwrap_or(
    ccs_update_url(),
  )
  ignore(self.record_external_open(raw_url))
  write_usage_json(w, Json::boolean(true))
}

///|
fn Gateway::record_external_open(self : Gateway, raw_url : String) -> String {
  let normalized = ccs_normalize_external_url(raw_url)
  self.last_external_url = Some(normalized)
  normalized
}

///|
async fn Gateway::handle_copy_text_to_clipboard(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  ignore(proxy_string_request(r.path, body, ["text"]).unwrap_or(""))
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_check_for_updates(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self.record_external_open(ccs_update_url()))
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_update_tray_menu(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_update_tray_menu_result())
}

///|
async fn Gateway::handle_is_portable_mode(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::boolean(ccs_portable_mode()))
}

///|
async fn Gateway::handle_get_init_error(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_init_error_json())
}

///|
async fn Gateway::handle_get_migration_result(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_migration_result_json())
}

///|
async fn Gateway::handle_get_skills_migration_result(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_skills_migration_result_json())
}

///|
async fn Gateway::handle_get_tool_versions(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let tools = proxy_string_request(r.path, body, ["tools"])
  write_usage_json(w, ccs_get_tool_versions_json(tools))
}

///|
async fn Gateway::handle_run_tool_lifecycle_action(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let tools = match body {
    Some(Object(obj)) => ccs_requested_tool_names_from_json(obj.get("tools"))
    _ => ccs_requested_tool_names(proxy_string_request(r.path, body, ["tools"]))
  }
  guard proxy_string_request(r.path, body, ["action"]) is Some(action) else {
    write_usage_bad_request(w, "missing_action")
    return
  }
  match ccs_run_tool_lifecycle_action_json(tools, action) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_probe_tool_installations(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let tools = match body {
    Some(Object(obj)) => ccs_requested_tool_names_from_json(obj.get("tools"))
    _ => ccs_requested_tool_names(proxy_string_request(r.path, body, ["tools"]))
  }
  match ccs_probe_tool_installations_json(tools) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_set_window_theme(
  self : Gateway,
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
async fn Gateway::handle_enter_lightweight_mode(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.lightweight_mode = true
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_exit_lightweight_mode(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.lightweight_mode = false
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_is_lightweight_mode(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, Json::boolean(self.lightweight_mode))
}

///|
async fn Gateway::handle_save_file_dialog(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  ignore(proxy_string_request(r.path, body, ["defaultName", "default_name"]))
  write_usage_json(w, ccs_dialog_result_json())
}

///|
async fn Gateway::handle_export_config_to_file(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["filePath", "file_path", "path"])
    is Some(file_path) else {
    write_usage_bad_request(w, "missing_file_path")
    return
  }
  write_usage_json(w, self.ccs_export_config_to_file_json(file_path))
}

///|
async fn Gateway::handle_import_config_from_file(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["filePath", "file_path", "path"])
    is Some(file_path) else {
    write_usage_bad_request(w, "missing_file_path")
    return
  }
  write_usage_json(w, self.ccs_import_config_from_file_json(file_path))
}

///|
async fn Gateway::handle_create_db_backup(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.ccs_create_db_backup_json())
}

///|
async fn Gateway::handle_list_db_backups(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_list_db_backups_json())
}

///|
async fn Gateway::handle_restore_db_backup(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["filename", "fileName", "name"])
    is Some(filename) else {
    write_usage_bad_request(w, "missing_filename")
    return
  }
  match self.ccs_restore_db_backup_json(filename) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_rename_db_backup(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, [
      "oldFilename", "old_filename", "filename",
    ])
    is Some(old_filename) else {
    write_usage_bad_request(w, "missing_old_filename")
    return
  }
  guard proxy_string_request(r.path, body, ["newName", "new_name", "name"])
    is Some(new_name) else {
    write_usage_bad_request(w, "missing_new_name")
    return
  }
  match ccs_rename_db_backup_json(old_filename, new_name) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_delete_db_backup(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["filename", "fileName", "name"])
    is Some(filename) else {
    write_usage_bad_request(w, "missing_filename")
    return
  }
  match ccs_delete_db_backup_json(filename) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_parse_deeplink(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["url"]) is Some(url) else {
    write_usage_bad_request(w, "missing_url")
    return
  }
  match ccs_parse_deeplink_url_json(url) {
    Some(request) => write_usage_json(w, request)
    None => write_usage_bad_request(w, "invalid_deeplink")
  }
}

///|
async fn Gateway::handle_merge_deeplink_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard ccs_deeplink_request_payload(r.path, body) is Some(request) else {
    write_usage_bad_request(w, "invalid_deeplink")
    return
  }
  match ccs_merge_deeplink_config_json(request) {
    Some(merged) => write_usage_json(w, merged)
    None => write_usage_bad_request(w, "invalid_deeplink_config")
  }
}

///|
async fn Gateway::handle_import_from_deeplink(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  legacy~ : Bool,
) -> Unit {
  let body = proxy_json_body(r)
  guard ccs_deeplink_request_payload(r.path, body) is Some(request) else {
    write_usage_bad_request(w, "invalid_deeplink")
    return
  }
  match self.ccs_import_from_deeplink_json(request) {
    Some(Object(obj)) =>
      if legacy {
        match obj.get("id") {
          Some(String(id)) => write_usage_json(w, Json::string(id))
          _ => write_usage_bad_request(w, "invalid_deeplink_import")
        }
      } else {
        write_usage_json(w, Json::object(obj))
      }
    Some(result) =>
      if legacy {
        write_usage_bad_request(w, "invalid_deeplink_import")
      } else {
        write_usage_json(w, result)
      }
    None => write_usage_bad_request(w, "invalid_deeplink_import")
  }
}

///|
async fn Gateway::handle_webdav_test_connection(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard ccs_sync_settings_request(r.path, body) is Some(settings) else {
    write_usage_bad_request(w, "missing_settings")
    return
  }
  let normalized = ccs_webdav_sync_settings_json(
    settings,
    ccs_app_webdav_sync_json(self.app_settings),
    ccs_sync_preserve_empty_password_request(r.path, body),
  )
  match ccs_validate_webdav_sync_settings(normalized) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match ccs_webdav_sync_test_connection_json(normalized) {
        Ok(result) => write_usage_json(w, result)
        Err(error) => write_usage_bad_request(w, error)
      }
  }
}

///|
async fn Gateway::handle_webdav_sync_save_settings(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard ccs_sync_settings_request(r.path, body) is Some(settings) else {
    write_usage_bad_request(w, "missing_settings")
    return
  }
  let normalized = ccs_webdav_sync_settings_json(
    settings,
    ccs_app_webdav_sync_json(self.app_settings),
    !ccs_sync_password_touched_request(r.path, body),
  )
  match ccs_validate_webdav_sync_settings(normalized) {
    Some(error) => write_usage_bad_request(w, error)
    None => {
      self.app_settings = ccs_app_settings_with_sync(
        self.app_settings,
        "webdavSync",
        normalized,
      )
      write_usage_json(w, { "success": Json::boolean(true) }.to_json())
    }
  }
}

///|
async fn Gateway::handle_webdav_sync_operation(
  self : Gateway,
  w : @httpx.ResponseWriter,
  operation : String,
) -> Unit {
  match ccs_webdav_sync_required_error(self.app_settings) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match ccs_app_webdav_sync_json(self.app_settings) {
        None => write_usage_bad_request(w, "WebDAV sync is not configured.")
        Some(settings) => {
          let result = match operation {
            "upload" => self.ccs_webdav_sync_upload_json(settings)
            "download" => self.ccs_webdav_sync_download_json(settings)
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
async fn Gateway::handle_webdav_sync_fetch_remote_info(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  match ccs_webdav_sync_required_error(self.app_settings) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match ccs_app_webdav_sync_json(self.app_settings) {
        None => write_usage_bad_request(w, "WebDAV sync is not configured.")
        Some(settings) =>
          match ccs_webdav_sync_fetch_remote_info_json(settings) {
            Ok(info) => write_usage_json(w, info)
            Err(error) => write_usage_bad_request(w, error)
          }
      }
  }
}

///|
async fn Gateway::handle_s3_test_connection(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard ccs_sync_settings_request(r.path, body) is Some(settings) else {
    write_usage_bad_request(w, "missing_settings")
    return
  }
  let normalized = ccs_s3_sync_settings_json(
    settings,
    ccs_app_s3_sync_json(self.app_settings),
    ccs_sync_preserve_empty_password_request(r.path, body),
  )
  match ccs_validate_s3_sync_settings(normalized) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match ccs_s3_sync_test_connection_json(normalized) {
        Ok(result) => write_usage_json(w, result)
        Err(error) => write_usage_bad_request(w, error)
      }
  }
}

///|
async fn Gateway::handle_s3_sync_save_settings(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard ccs_sync_settings_request(r.path, body) is Some(settings) else {
    write_usage_bad_request(w, "missing_settings")
    return
  }
  let normalized = ccs_s3_sync_settings_json(
    settings,
    ccs_app_s3_sync_json(self.app_settings),
    !ccs_sync_password_touched_request(r.path, body),
  )
  match ccs_validate_s3_sync_settings(normalized) {
    Some(error) => write_usage_bad_request(w, error)
    None => {
      self.app_settings = ccs_app_settings_with_sync(
        self.app_settings,
        "s3Sync",
        normalized,
      )
      write_usage_json(w, { "success": Json::boolean(true) }.to_json())
    }
  }
}

///|
async fn Gateway::handle_s3_sync_operation(
  self : Gateway,
  w : @httpx.ResponseWriter,
  operation : String,
) -> Unit {
  match ccs_s3_sync_required_error(self.app_settings) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match ccs_app_s3_sync_json(self.app_settings) {
        None => write_usage_bad_request(w, "S3 sync is not configured.")
        Some(settings) => {
          let result = match operation {
            "upload" => self.ccs_s3_sync_upload_json(settings)
            "download" => self.ccs_s3_sync_download_json(settings)
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
async fn Gateway::handle_s3_sync_fetch_remote_info(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  match ccs_s3_sync_required_error(self.app_settings) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match ccs_app_s3_sync_json(self.app_settings) {
        None => write_usage_bad_request(w, "S3 sync is not configured.")
        Some(settings) =>
          match ccs_s3_sync_fetch_remote_info_json(settings) {
            Ok(info) => write_usage_json(w, info)
            Err(error) => write_usage_bad_request(w, error)
          }
      }
  }
}

///|
async fn Gateway::handle_read_omo_local_file(
  self : Gateway,
  w : @httpx.ResponseWriter,
  slim~ : Bool,
) -> Unit {
  ignore(self)
  let (data, error) = ccs_read_omo_local_file_json(slim)
  match data {
    Some(data) => write_usage_json(w, data)
    None =>
      write_usage_bad_request(w, error.unwrap_or("OMO 配置文件不存在"))
  }
}

///|
async fn Gateway::handle_get_current_omo_provider_id(
  self : Gateway,
  w : @httpx.ResponseWriter,
  slim~ : Bool,
) -> Unit {
  write_usage_json(w, Json::string(self.current_omo_provider_id(slim)))
}

///|
async fn Gateway::handle_disable_current_omo(
  self : Gateway,
  w : @httpx.ResponseWriter,
  slim~ : Bool,
) -> Unit {
  self.clear_current_omo_provider(slim)
  match ccs_delete_omo_config_files(slim) {
    Some(error) => write_usage_bad_request(w, error)
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn Gateway::handle_open_file_dialog(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_dialog_result_json())
}

///|
async fn Gateway::handle_open_zip_file_dialog(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_dialog_result_json())
}

///|
async fn Gateway::handle_get_installed_skills(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_get_installed_skills_json())
}

///|
async fn Gateway::handle_get_skill_backups(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_get_skill_backups_json())
}

///|
async fn Gateway::handle_delete_skill_backup(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["backupId", "backup_id", "id"])
    is Some(backup_id) else {
    write_usage_bad_request(w, "missing_backup_id")
    return
  }
  write_usage_json(w, ccs_delete_skill_backup_json(backup_id))
}

///|
async fn Gateway::handle_restore_skill_backup(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["backupId", "backup_id", "id"])
    is Some(backup_id) else {
    write_usage_bad_request(w, "missing_backup_id")
    return
  }
  let current_app = proxy_string_request(r.path, body, [
    "currentApp", "current_app", "app",
  ]).unwrap_or("claude")
  write_usage_json(w, ccs_restore_skill_backup_json(backup_id, current_app))
}

///|
async fn Gateway::handle_install_skill_unified(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let skill = match ccs_skill_request_payload(body) {
    Some(skill) => Some(skill)
    None =>
      match proxy_string_request(r.path, body, ["directory", "id", "key"]) {
        Some(directory) => {
          let install_name = ccs_skill_install_name(directory)
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
  write_usage_json(w, ccs_install_skill_unified_json(skill, current_app))
}

///|
async fn Gateway::handle_uninstall_skill_unified(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["id", "directory"]) is Some(id) else {
    write_usage_bad_request(w, "missing_skill_id")
    return
  }
  write_usage_json(w, ccs_uninstall_skill_unified_json(id))
}

///|
async fn Gateway::handle_toggle_skill_app(
  self : Gateway,
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
  write_usage_json(w, ccs_toggle_skill_app_json(id, app, enabled))
}

///|
async fn Gateway::handle_scan_unmanaged_skills(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_scan_unmanaged_skills_json())
}

///|
async fn Gateway::handle_import_skills_from_apps(
  self : Gateway,
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
  write_usage_json(w, ccs_import_skills_from_apps_json(imports))
}

///|
async fn Gateway::handle_discover_available_skills(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_discover_available_skills_json())
}

///|
async fn Gateway::handle_check_skill_updates(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_check_skill_updates_json())
}

///|
async fn Gateway::handle_update_skill(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["id", "directory"]) is Some(id) else {
    write_usage_bad_request(w, "missing_skill_id")
    return
  }
  write_usage_json(w, ccs_update_skill_json(id))
}

///|
async fn Gateway::handle_migrate_skill_storage(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["target"]) is Some(target) else {
    write_usage_bad_request(w, "missing_storage_target")
    return
  }
  write_usage_json(w, ccs_migrate_skill_storage_json(target))
}

///|
async fn Gateway::handle_search_skills_sh(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let query = proxy_string_request(r.path, body, ["query", "q"]).unwrap_or("")
  let limit = proxy_int_request(r.path, body, ["limit"]).unwrap_or(20)
  let offset = proxy_int_request(r.path, body, ["offset"]).unwrap_or(0)
  write_usage_json(w, ccs_search_skills_sh_json(query, limit, offset))
}

///|
async fn Gateway::handle_get_skills(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_get_skills_json())
}

///|
async fn Gateway::handle_install_skill_legacy(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  app : String,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["directory", "id", "key"])
    is Some(directory) else {
    write_usage_bad_request(w, "missing_directory")
    return
  }
  let install_name = ccs_skill_install_name(directory)
  if install_name.is_empty() {
    write_usage_bad_request(w, "invalid_directory")
    return
  }
  let skill = {
    "key": Json::string("local:\{install_name}"),
    "name": Json::string(install_name),
    "description": Json::string(""),
    "directory": Json::string(install_name),
  }.to_json()
  ignore(ccs_install_skill_unified_json(skill, app))
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_install_skill_for_app(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let app = proxy_string_request(r.path, body, ["app", "appType", "app_type"]).unwrap_or(
    "claude",
  )
  guard proxy_string_request(r.path, body, ["directory", "id", "key"])
    is Some(directory) else {
    write_usage_bad_request(w, "missing_directory")
    return
  }
  let install_name = ccs_skill_install_name(directory)
  if install_name.is_empty() {
    write_usage_bad_request(w, "invalid_directory")
    return
  }
  let skill = {
    "key": Json::string("local:\{install_name}"),
    "name": Json::string(install_name),
    "description": Json::string(""),
    "directory": Json::string(install_name),
  }.to_json()
  ignore(ccs_install_skill_unified_json(skill, app))
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_uninstall_skill_legacy(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["directory", "id"]) is Some(id) else {
    write_usage_bad_request(w, "missing_directory")
    return
  }
  write_usage_json(w, ccs_uninstall_skill_unified_json(id))
}

///|
async fn Gateway::handle_get_skill_repos(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_get_skill_repos_json())
}

///|
async fn Gateway::handle_add_skill_repo(
  self : Gateway,
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
            match ccs_skill_repo_request_json(r.path, body) {
              Some(repo) => repo
              None => {
                write_usage_bad_request(w, "missing_owner_or_name")
                return
              }
            }
          }
      }
    _ =>
      match ccs_skill_repo_request_json(r.path, body) {
        Some(repo) => repo
        None => {
          write_usage_bad_request(w, "missing_owner_or_name")
          return
        }
      }
  }
  write_usage_json(w, ccs_add_skill_repo_json(repo))
}

///|
fn ccs_skill_repo_request_json(path : StringView, body : Json?) -> Json? {
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
async fn Gateway::handle_remove_skill_repo(
  self : Gateway,
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
  write_usage_json(w, ccs_remove_skill_repo_json(owner, name))
}

///|
async fn Gateway::handle_install_skills_from_zip(
  self : Gateway,
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
  write_usage_json(w, ccs_install_skills_from_zip_json(file_path, current_app))
}

///|
async fn Gateway::handle_get_app_config_path(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::string(ccs_app_config_path()))
}

///|
async fn Gateway::handle_open_app_config_folder(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  match ccs_open_directory_result_json(ccs_app_config_dir()) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_get_settings(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.app_settings)
}

///|
async fn Gateway::handle_save_settings(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  match proxy_json_body(r) {
    Some(settings) => {
      self.app_settings = ccs_merge_settings_for_save(
        settings,
        self.app_settings,
      )
      match self.app_settings {
        Object(obj) => {
          match proxy_json_bool(obj, "launchOnStartup") {
            Some(enabled) => self.auto_launch_enabled = enabled
            None => ()
          }
          match proxy_json_bool(obj, "skipClaudeOnboarding") {
            Some(skipped) => self.claude_onboarding_skipped = skipped
            None => ()
          }
        }
        _ => ()
      }
      write_usage_json(w, Json::boolean(true))
    }
    None => write_usage_bad_request(w, "invalid_settings")
  }
}

///|
async fn Gateway::handle_restart_app(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_install_update_and_restart(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::boolean(false))
}

///|
async fn Gateway::handle_get_app_config_dir_override(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.app_config_dir_override {
    Some(path) => write_usage_json(w, Json::string(path))
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn Gateway::handle_set_app_config_dir_override(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  self.app_config_dir_override = ccs_optional_path_from_request(r.path, body)
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_set_auto_launch(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_bool_request(r.path, body, ["enabled"]) is Some(enabled) else {
    write_usage_bad_request(w, "invalid_auto_launch")
    return
  }
  self.auto_launch_enabled = enabled
  self.app_settings = ccs_settings_with_bool(
    self.app_settings,
    "launchOnStartup",
    enabled,
  )
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_get_auto_launch_status(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, Json::boolean(self.auto_launch_enabled))
}

///|
async fn Gateway::handle_get_rectifier_config(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.rectifier_config_json)
}

///|
async fn Gateway::handle_set_rectifier_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  self.rectifier_config_json = ccs_rectifier_config_from_request(
    r.path,
    body,
    self.rectifier_config_json,
  )
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_get_optimizer_config(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.optimizer_config_json)
}

///|
async fn Gateway::handle_set_optimizer_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = ccs_optimizer_config_from_request(
    r.path,
    body,
    self.optimizer_config_json,
  )
  if !ccs_optimizer_cache_ttl_valid(config) {
    write_usage_bad_request(w, "invalid_optimizer_cache_ttl")
    return
  }
  self.optimizer_config_json = config
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_get_copilot_optimizer_config(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.copilot_optimizer_config_json)
}

///|
async fn Gateway::handle_set_copilot_optimizer_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  self.copilot_optimizer_config_json = ccs_copilot_optimizer_config_from_request(
    r.path,
    body,
    self.copilot_optimizer_config_json,
  )
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_get_log_config(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.log_config_json)
}

///|
async fn Gateway::handle_set_log_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  self.log_config_json = ccs_log_config_from_request(
    r.path,
    body,
    self.log_config_json,
  )
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_get_common_config_snippet(
  self : Gateway,
  w : @httpx.ResponseWriter,
  app_type : String,
) -> Unit {
  match self.config_snippets.get(app_type) {
    Some(snippet) => write_usage_json(w, Json::string(snippet))
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn Gateway::handle_get_common_config_snippet_request(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let app_type = ccs_config_app_from_request(r.path, None).unwrap_or("claude")
  self.handle_get_common_config_snippet(w, app_type)
}

///|
async fn Gateway::handle_set_common_config_snippet(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  app_type : String,
) -> Unit {
  let body = proxy_json_body(r)
  let snippet = proxy_string_request(r.path, body, [
    "snippet", "content", "value",
  ]).unwrap_or("")
  match ccs_validate_common_config_snippet(app_type, snippet) {
    Some(error) => {
      write_usage_bad_request(w, error)
      return
    }
    None => ()
  }
  if snippet.trim().is_empty() {
    self.config_snippets.remove(app_type)
  } else {
    self.config_snippets[app_type] = snippet
  }
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_set_common_config_snippet_request(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app_type = ccs_config_app_from_request(r.path, body).unwrap_or("claude")
  let snippet = proxy_string_request(r.path, body, [
    "snippet", "content", "value",
  ]).unwrap_or("")
  match ccs_validate_common_config_snippet(app_type, snippet) {
    Some(error) => {
      write_usage_bad_request(w, error)
      return
    }
    None => ()
  }
  if snippet.trim().is_empty() {
    self.config_snippets.remove(app_type)
  } else {
    self.config_snippets[app_type] = snippet
  }
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_extract_common_config_snippet(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app_type = ccs_config_app_from_request(r.path, body).unwrap_or("claude")
  match
    proxy_string_request(r.path, body, ["settingsConfig", "settings_config"]) {
    Some(settings_config) =>
      match
        ccs_extract_common_config_snippet_from_settings_config(
          app_type, settings_config,
        ) {
        Ok(snippet) => write_usage_json(w, Json::string(snippet))
        Err(error) => write_usage_bad_request(w, error)
      }
    None =>
      match self.config_snippets.get(app_type) {
        Some(snippet) => write_usage_json(w, Json::string(snippet))
        None => write_usage_json(w, Json::string(""))
      }
  }
}

///|
async fn Gateway::handle_check_env_conflicts(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let app = ccs_config_app_from_request(r.path, None).unwrap_or("claude")
  write_usage_json(w, ccs_env_conflicts_json(app))
}

///|
async fn Gateway::handle_delete_env_vars(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  match ccs_delete_env_vars_json(body) {
    Ok(backup) => write_usage_json(w, backup)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_restore_env_backup(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let backup_path = proxy_string_request(r.path, body, [
    "backupPath", "backup_path",
  ])
  match ccs_restore_env_backup_json(backup_path) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_get_claude_mcp_status(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    {
      "userConfigPath": Json::string(
        @pathx.join(ccs_home_dir(), ".claude.json"),
      ),
      "userConfigExists": Json::boolean(
        @fsx.exists_as_file(@pathx.join(ccs_home_dir(), ".claude.json")),
      ),
      "serverCount": Json::number(self.mcp_servers.length().to_double()),
    }.to_json(),
  )
}

///|
async fn Gateway::handle_read_claude_mcp_config(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  match ccs_mcp_config_text(self.mcp_servers) {
    Some(content) => write_usage_json(w, Json::string(content))
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn Gateway::handle_upsert_claude_mcp_server(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  match ccs_mcp_server_from_request(r.path, body, "claude") {
    Some((id, server)) => {
      self.mcp_servers[id] = ccs_mcp_server_with_app(server, "claude", true)
      write_usage_json(w, Json::boolean(true))
    }
    None => write_usage_json(w, Json::boolean(false))
  }
}

///|
async fn Gateway::handle_delete_mcp_server(
  self : Gateway,
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
async fn Gateway::handle_validate_mcp_command(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let command = proxy_string_request(r.path, None, ["cmd", "command"]).unwrap_or(
    "",
  )
  write_usage_json(w, Json::boolean(ccs_validate_mcp_command_name(command)))
}

///|
async fn Gateway::handle_get_mcp_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let app = ccs_config_app_from_request(r.path, None).unwrap_or("claude")
  write_usage_json(
    w,
    {
      "configPath": Json::string(ccs_app_config_path()),
      "servers": ccs_mcp_servers_object_for_app(self.mcp_servers, Some(app)),
    }.to_json(),
  )
}

///|
async fn Gateway::handle_upsert_mcp_server_in_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = ccs_config_app_from_request(r.path, body).unwrap_or("claude")
  match ccs_mcp_server_from_request(r.path, body, app) {
    Some((id, server)) => {
      let sync_other = proxy_bool_request(r.path, body, [
        "syncOtherSide", "sync_other_side",
      ]).unwrap_or(false)
      let next = if sync_other {
        let synced = ccs_mcp_server_with_app(server, "claude", true)
        let synced = ccs_mcp_server_with_app(synced, "codex", true)
        let synced = ccs_mcp_server_with_app(synced, "gemini", true)
        let synced = ccs_mcp_server_with_app(synced, "opencode", true)
        ccs_mcp_server_with_app(synced, "hermes", true)
      } else {
        ccs_mcp_server_with_app(server, app, true)
      }
      self.mcp_servers[id] = next
      write_usage_json(w, Json::boolean(true))
    }
    None => write_usage_json(w, Json::boolean(false))
  }
}

///|
async fn Gateway::handle_set_mcp_enabled(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = ccs_config_app_from_request(r.path, body).unwrap_or("claude")
  let enabled = proxy_bool_request(r.path, body, ["enabled"]).unwrap_or(true)
  match proxy_string_request(r.path, body, ["id", "serverId", "server_id"]) {
    Some(id) =>
      match self.mcp_servers.get(id) {
        Some(server) => {
          self.mcp_servers[id] = ccs_mcp_server_with_app(server, app, enabled)
          write_usage_json(w, Json::boolean(true))
        }
        None => write_usage_json(w, Json::boolean(false))
      }
    None => write_usage_json(w, Json::boolean(false))
  }
}

///|
async fn Gateway::handle_get_mcp_servers(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, ccs_mcp_servers_object_for_app(self.mcp_servers, None))
}

///|
async fn Gateway::handle_upsert_mcp_server(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  match ccs_mcp_server_from_request(r.path, body, "claude") {
    Some((id, server)) => {
      self.mcp_servers[id] = server
      write_usage_json(w, Json::null())
    }
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn Gateway::handle_toggle_mcp_app(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = ccs_config_app_from_request(r.path, body).unwrap_or("claude")
  let enabled = proxy_bool_request(r.path, body, ["enabled"]).unwrap_or(true)
  match proxy_string_request(r.path, body, ["serverId", "server_id", "id"]) {
    Some(id) =>
      match self.mcp_servers.get(id) {
        Some(server) => {
          self.mcp_servers[id] = ccs_mcp_server_with_app(server, app, enabled)
          write_usage_json(w, Json::null())
        }
        None => write_usage_json(w, Json::null())
      }
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn Gateway::handle_import_mcp_from_apps(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  let imported = ccs_import_mcp_from_apps_count(self.mcp_servers)
  write_usage_json(w, Json::number(imported.to_double()))
}

///|
async fn Gateway::handle_get_prompts(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let app = ccs_config_app_from_request(r.path, None).unwrap_or("claude")
  write_usage_json(w, ccs_prompts_object_for_app(self.prompts, app))
}

///|
async fn Gateway::handle_upsert_prompt(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  match ccs_prompt_from_request(r.path, body) {
    Some((app, id, prompt)) =>
      self.prompts[ccs_prompt_store_key(app, id)] = prompt
    None => ()
  }
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_delete_prompt(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = ccs_config_app_from_request(r.path, body).unwrap_or("claude")
  match proxy_string_request(r.path, body, ["id", "promptId", "prompt_id"]) {
    Some(id) => self.prompts.remove(ccs_prompt_store_key(app, id))
    None => ()
  }
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_enable_prompt(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = ccs_config_app_from_request(r.path, body).unwrap_or("claude")
  match proxy_string_request(r.path, body, ["id", "promptId", "prompt_id"]) {
    Some(id) =>
      match ccs_prompt_file_path_from_request(r.path, body, app) {
        Ok(file_path) =>
          match ccs_enable_prompt_json(self.prompts, app, id, file_path) {
            Ok(result) => write_usage_json(w, result)
            Err(error) => write_usage_bad_request(w, error)
          }
        Err(error) => write_usage_bad_request(w, error)
      }
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn Gateway::handle_import_prompt_from_file(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let app = ccs_config_app_from_request(r.path, body).unwrap_or("claude")
  match ccs_prompt_file_path_from_request(r.path, body, app) {
    Ok(file_path) =>
      match ccs_import_prompt_from_file_json(self.prompts, app, file_path) {
        Ok(result) => write_usage_json(w, result)
        Err(error) => write_usage_bad_request(w, error)
      }
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_get_current_prompt_file_content(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let app = ccs_config_app_from_request(r.path, body).unwrap_or("claude")
  match ccs_prompt_file_path_from_request(r.path, body, app) {
    Ok(file_path) =>
      match ccs_current_prompt_file_content_json(file_path) {
        Ok(result) => write_usage_json(w, result)
        Err(error) => write_usage_bad_request(w, error)
      }
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_proxy_status(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(self.proxy_status_json().stringify(indent=2))
  w.flush()
}

///|
fn Gateway::proxy_status_json(self : Gateway) -> Json {
  self.stats.status_json(
    self.host,
    self.port,
    self.uptime_seconds(),
    running=self.proxy_enabled,
  )
}

///|
async fn Gateway::handle_proxy_start_server(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.proxy_enabled = true
  write_usage_json(w, self.proxy_server_info_json())
}

///|
fn Gateway::proxy_server_info_json(self : Gateway) -> Json {
  {
    "address": Json::string(self.proxy_listen_address),
    "port": Json::number(self.proxy_listen_port.to_double()),
    "started_at": Json::string(self.started_at_ms.to_string()),
  }.to_json()
}

///|
async fn Gateway::handle_proxy_stop_server(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  if self.proxy_takeover_active() {
    write_usage_bad_request(w, "live_takeover_active")
    return
  }
  self.proxy_enabled = false
  write_usage_json(w, ccs_unit_success_json())
}

///|
async fn Gateway::handle_proxy_stop_with_restore(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.proxy_enabled = false
  self.proxy_clear_takeover()
  self.proxy_clear_enabled_apps_for_manual_stop()
  write_usage_json(w, ccs_unit_success_json())
}

///|
async fn Gateway::handle_proxy_config(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(self.proxy_config_json().stringify(indent=2))
  w.flush()
}

///|
fn Gateway::proxy_config_json(self : Gateway) -> Json {
  let app_type = "claude"
  let streaming_first_byte_timeout = self.proxy_streaming_first_byte_timeout
    .get(app_type)
    .unwrap_or(ccs_proxy_streaming_first_byte_timeout_default(app_type))
  let streaming_idle_timeout = self.proxy_streaming_idle_timeout
    .get(app_type)
    .unwrap_or(ccs_proxy_streaming_idle_timeout_default(app_type))
  let non_streaming_timeout = self.proxy_non_streaming_timeout
    .get(app_type)
    .unwrap_or(ccs_proxy_non_streaming_timeout_default(app_type))
  {
    "listen_address": Json::string(self.proxy_listen_address),
    "listen_port": Json::number(self.proxy_listen_port.to_double()),
    "max_retries": Json::number(
      self.provider_router.max_retries_for_app(app_type).to_double(),
    ),
    "request_timeout": Json::number(600.0),
    "enable_logging": Json::boolean(self.proxy_enable_logging),
    "live_takeover_active": Json::boolean(self.proxy_takeover_active()),
    "streaming_first_byte_timeout": Json::number(
      streaming_first_byte_timeout.to_double(),
    ),
    "streaming_idle_timeout": Json::number(streaming_idle_timeout.to_double()),
    "non_streaming_timeout": Json::number(non_streaming_timeout.to_double()),
  }.to_json()
}

///|
fn ccs_proxy_streaming_first_byte_timeout_default(app_type : String) -> Int {
  match app_type {
    "claude" => 90
    _ => 60
  }
}

///|
fn ccs_proxy_streaming_idle_timeout_default(app_type : String) -> Int {
  match app_type {
    "claude" => 180
    _ => 120
  }
}

///|
fn ccs_proxy_non_streaming_timeout_default(_app_type : String) -> Int {
  600
}

///|
async fn Gateway::handle_proxy_update_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.apply_proxy_global_config_request(r, legacy=true) {
    true => write_usage_json(w, self.proxy_config_json())
    false => write_usage_bad_request(w, "invalid_proxy_config")
  }
}

///|
async fn Gateway::handle_proxy_global_config(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.proxy_global_config_json())
}

///|
fn Gateway::proxy_global_config_json(self : Gateway) -> Json {
  {
    "proxyEnabled": Json::boolean(self.proxy_enabled),
    "listenAddress": Json::string(self.proxy_listen_address),
    "listenPort": Json::number(self.proxy_listen_port.to_double()),
    "enableLogging": Json::boolean(self.proxy_enable_logging),
  }.to_json()
}

///|
async fn Gateway::handle_proxy_update_global_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.apply_proxy_global_config_request(r) {
    true => write_usage_json(w, self.proxy_global_config_json())
    false => write_usage_bad_request(w, "invalid_global_proxy_config")
  }
}

///|
async fn Gateway::handle_get_global_proxy_url(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.upstream_proxy_url {
    Some(url) => write_usage_json(w, Json::string(url))
    None => write_usage_json(w, Json::null())
  }
}

///|
async fn Gateway::handle_set_global_proxy_url(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  let url = proxy_string_request(r.path, config, ["url"]).unwrap_or("")
  let trimmed = url.trim().to_owned()
  if trimmed.is_empty() {
    self.upstream_proxy_url = None
    write_usage_json(w, Json::null())
    return
  }
  if !upstream_proxy_url_is_valid(trimmed) {
    write_usage_bad_request(w, "invalid_proxy_url")
    return
  }
  self.upstream_proxy_url = Some(trimmed)
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_test_proxy_url(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  let url = proxy_string_request(r.path, config, ["url"]).unwrap_or("")
  write_usage_json(w, proxy_test_result_json(url))
}

///|
async fn Gateway::handle_get_upstream_proxy_status(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    {
      "enabled": Json::boolean(self.upstream_proxy_url is Some(_)),
      "proxyUrl": match self.upstream_proxy_url {
        Some(url) => Json::string(url)
        None => Json::null()
      },
    }.to_json(),
  )
}

///|
async fn Gateway::handle_scan_local_proxies(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_scan_local_proxies_json())
}

///|
fn upstream_proxy_url_is_valid(url : String) -> Bool {
  url.has_prefix("http://") ||
  url.has_prefix("https://") ||
  url.has_prefix("socks5://") ||
  url.has_prefix("socks5h://")
}

///|
fn ccs_local_proxy_ports() -> Array[(Int, String, Bool)] {
  [
    (7890, "http", true),
    (7891, "socks5", false),
    (1080, "socks5", false),
    (8080, "http", false),
    (8888, "http", false),
    (3128, "http", false),
    (10808, "socks5", false),
    (10809, "http", false),
  ]
}

///|
fn ccs_detected_proxy_json(port : Int, proxy_type : String) -> Json {
  {
    "url": Json::string("\{proxy_type}://127.0.0.1:\{port}"),
    "proxyType": Json::string(proxy_type),
    "port": Json::number(port.to_double()),
  }.to_json()
}

///|
fn ccs_detected_proxy_entries_json(
  port : Int,
  primary_type : String,
  is_mixed : Bool,
) -> Array[Json] {
  let entries = [ccs_detected_proxy_json(port, primary_type)]
  if is_mixed {
    let alt_type = if primary_type == "http" { "socks5" } else { "http" }
    entries.push(ccs_detected_proxy_json(port, alt_type))
  }
  entries
}

///|
fn ccs_scan_local_proxies_json() -> Json {
  let found : Array[Json] = []
  for item in ccs_local_proxy_ports() {
    let (port, primary_type, is_mixed) = item
    if @net.localhost_port_open(port, timeout_ms=100) {
      found.append(
        ccs_detected_proxy_entries_json(port, primary_type, is_mixed),
      )
    }
  }
  Json::array(found)
}

///|
fn proxy_test_result_json(url : String) -> Json {
  let trimmed = url.trim().to_owned()
  if trimmed.is_empty() {
    return {
      "success": Json::boolean(false),
      "latencyMs": Json::number(0.0),
      "error": Json::string("Proxy URL is empty"),
    }.to_json()
  }
  if !upstream_proxy_url_is_valid(trimmed) {
    return {
      "success": Json::boolean(false),
      "latencyMs": Json::number(0.0),
      "error": Json::string("Invalid proxy URL"),
    }.to_json()
  }
  {
    "success": Json::boolean(true),
    "latencyMs": Json::number(0.0),
    "error": Json::null(),
  }.to_json()
}

///|
async fn Gateway::handle_proxy_app_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard usage_query_value_any(r.path, "app_type", "appType") is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(w, self.proxy_app_config_json(app_type))
}

///|
fn Gateway::proxy_app_config_json(self : Gateway, app_type : String) -> Json {
  let circuit = self.provider_router.circuit_config_for_app(app_type)
  let enabled = self.proxy_app_enabled_for_app(app_type)
  let auto_failover_enabled = self.provider_router.auto_failover_enabled_for_app(
    app_type,
  )
  let max_retries = self.provider_router.max_retries_for_app(app_type)
  let streaming_first_byte_timeout = self.proxy_streaming_first_byte_timeout
    .get(app_type)
    .unwrap_or(ccs_proxy_streaming_first_byte_timeout_default(app_type))
  let streaming_idle_timeout = self.proxy_streaming_idle_timeout
    .get(app_type)
    .unwrap_or(ccs_proxy_streaming_idle_timeout_default(app_type))
  let non_streaming_timeout = self.proxy_non_streaming_timeout
    .get(app_type)
    .unwrap_or(ccs_proxy_non_streaming_timeout_default(app_type))
  {
    "appType": Json::string(app_type),
    "app_type": Json::string(app_type),
    "enabled": Json::boolean(enabled),
    "autoFailoverEnabled": Json::boolean(auto_failover_enabled),
    "auto_failover_enabled": Json::boolean(auto_failover_enabled),
    "maxRetries": Json::number(max_retries.to_double()),
    "max_retries": Json::number(max_retries.to_double()),
    "streamingFirstByteTimeout": Json::number(
      streaming_first_byte_timeout.to_double(),
    ),
    "streaming_first_byte_timeout": Json::number(
      streaming_first_byte_timeout.to_double(),
    ),
    "streamingIdleTimeout": Json::number(streaming_idle_timeout.to_double()),
    "streaming_idle_timeout": Json::number(streaming_idle_timeout.to_double()),
    "nonStreamingTimeout": Json::number(non_streaming_timeout.to_double()),
    "non_streaming_timeout": Json::number(non_streaming_timeout.to_double()),
    "circuitFailureThreshold": Json::number(
      circuit.failure_threshold.to_double(),
    ),
    "circuit_failure_threshold": Json::number(
      circuit.failure_threshold.to_double(),
    ),
    "circuitSuccessThreshold": Json::number(
      circuit.success_threshold.to_double(),
    ),
    "circuit_success_threshold": Json::number(
      circuit.success_threshold.to_double(),
    ),
    "circuitTimeoutSeconds": Json::number(circuit.timeout_seconds.to_double()),
    "circuit_timeout_seconds": Json::number(circuit.timeout_seconds.to_double()),
    "circuitErrorRateThreshold": Json::number(circuit.error_rate_threshold),
    "circuit_error_rate_threshold": Json::number(circuit.error_rate_threshold),
    "circuitMinRequests": Json::number(circuit.min_requests.to_double()),
    "circuit_min_requests": Json::number(circuit.min_requests.to_double()),
  }.to_json()
}

///|
async fn Gateway::handle_proxy_update_app_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.apply_proxy_app_config_request(r) {
    Some(app_type) => write_usage_json(w, self.proxy_app_config_json(app_type))
    None => write_usage_bad_request(w, "invalid_app_proxy_config")
  }
}

///|
async fn Gateway::handle_proxy_default_cost_multiplier(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard usage_query_value_any(r.path, "app_type", "appType") is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(
    w,
    Json::string(self.proxy_default_cost_multiplier_for_app(app_type)),
  )
}

///|
async fn Gateway::handle_proxy_set_default_cost_multiplier(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_string_request(r.path, config, ["app_type", "appType"])
    is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_string_request(r.path, config, ["value"]) is Some(value) else {
    write_usage_bad_request(w, "missing_value")
    return
  }
  if !usage_non_negative_decimal(value) {
    write_usage_bad_request(w, "invalid_default_cost_multiplier")
    return
  }
  let trimmed = value.trim().to_owned()
  self.proxy_default_cost_multipliers.set(app_type, trimmed)
  write_usage_json(w, Json::string(trimmed))
}

///|
async fn Gateway::handle_proxy_set_default_cost_multiplier_unit(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_string_request(r.path, config, ["app_type", "appType"])
    is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_string_request(r.path, config, ["value"]) is Some(value) else {
    write_usage_bad_request(w, "missing_value")
    return
  }
  if !usage_non_negative_decimal(value) {
    write_usage_bad_request(w, "invalid_default_cost_multiplier")
    return
  }
  self.proxy_default_cost_multipliers.set(app_type, value.trim().to_owned())
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_proxy_pricing_model_source(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard usage_query_value_any(r.path, "app_type", "appType") is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(
    w,
    Json::string(self.proxy_pricing_model_source_for_app(app_type)),
  )
}

///|
async fn Gateway::handle_proxy_set_pricing_model_source(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_string_request(r.path, config, ["app_type", "appType"])
    is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_string_request(r.path, config, ["value"]) is Some(value) else {
    write_usage_bad_request(w, "missing_value")
    return
  }
  if !pricing_model_source_is_valid(value) {
    write_usage_bad_request(w, "invalid_pricing_model_source")
    return
  }
  let trimmed = value.trim().to_owned()
  self.proxy_pricing_model_sources.set(app_type, trimmed)
  write_usage_json(w, Json::string(trimmed))
}

///|
async fn Gateway::handle_proxy_set_pricing_model_source_unit(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_string_request(r.path, config, ["app_type", "appType"])
    is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_string_request(r.path, config, ["value"]) is Some(value) else {
    write_usage_bad_request(w, "missing_value")
    return
  }
  if !pricing_model_source_is_valid(value) {
    write_usage_bad_request(w, "invalid_pricing_model_source")
    return
  }
  self.proxy_pricing_model_sources.set(app_type, value.trim().to_owned())
  write_usage_json(w, Json::null())
}

///|
fn Gateway::proxy_default_cost_multiplier_for_app(
  self : Gateway,
  app_type : String,
) -> String {
  let default_app_type = proxy_pricing_default_app_type(app_type)
  self.proxy_default_cost_multipliers
  .get(default_app_type)
  .unwrap_or(default_cost_multiplier_for_app(app_type))
}

///|
fn Gateway::proxy_pricing_model_source_for_app(
  self : Gateway,
  app_type : String,
) -> String {
  let default_app_type = proxy_pricing_default_app_type(app_type)
  self.proxy_pricing_model_sources
  .get(default_app_type)
  .unwrap_or(default_pricing_model_source_for_app(app_type))
}

///|
fn proxy_pricing_default_app_type(app_type : String) -> String {
  if app_type == "claude-desktop" {
    "claude"
  } else {
    app_type
  }
}

///|
async fn Gateway::apply_proxy_global_config_request(
  self : Gateway,
  r : @httpx.RequestReader,
  legacy? : Bool = false,
) -> Bool {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  let proxy_enabled = proxy_bool_request(r.path, config, [
    "proxy_enabled", "proxyEnabled", "enabled",
  ])
  let listen_address = proxy_string_request(r.path, config, [
    "listen_address", "listenAddress",
  ])
  let listen_port = proxy_int_request(r.path, config, [
    "listen_port", "listenPort",
  ])
  let enable_logging = proxy_bool_request(r.path, config, [
    "enable_logging", "enableLogging",
  ])
  if proxy_enabled is Some(enabled) {
    self.proxy_enabled = enabled
  } else if legacy {
    match proxy_bool_request(r.path, config, ["proxyEnabled"]) {
      Some(enabled) => self.proxy_enabled = enabled
      None => ()
    }
  }
  if listen_address is Some(address) {
    if address.trim().is_empty() {
      return false
    }
    self.proxy_listen_address = address.trim().to_owned()
  }
  if listen_port is Some(port) {
    if port <= 0 || port > 65535 {
      return false
    }
    self.proxy_listen_port = port
  }
  if enable_logging is Some(enabled) {
    self.proxy_enable_logging = enabled
  }
  true
}

///|
async fn Gateway::apply_proxy_app_config_request(
  self : Gateway,
  r : @httpx.RequestReader,
) -> String? {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  let app_type = match
    proxy_string_request(r.path, config, ["app_type", "appType"]) {
    Some(app_type) if !app_type.trim().is_empty() => app_type.trim().to_owned()
    _ => return None
  }
  match proxy_bool_request(r.path, config, ["enabled"]) {
    Some(enabled) => self.proxy_app_enabled.set(app_type, enabled)
    None => ()
  }
  match
    proxy_bool_request(r.path, config, [
      "auto_failover_enabled", "autoFailoverEnabled",
    ]) {
    Some(enabled) =>
      if !self.provider_router.set_auto_failover_ccs(app_type, enabled) {
        return None
      }
    None => ()
  }
  match proxy_int_request(r.path, config, ["max_retries", "maxRetries"]) {
    Some(max_retries) if max_retries >= 0 =>
      self.provider_router.set_max_retries(app_type, max_retries)
    Some(_) => return None
    None => ()
  }
  if !self.apply_proxy_app_timeout_config(app_type, r.path, config) {
    return None
  }
  match
    proxy_circuit_config_from_request(
      r.path,
      config,
      self.provider_router.circuit_config_for_app(app_type),
    ) {
    Some(config) => self.provider_router.update_app_configs(app_type, config)
    None => ()
  }
  Some(app_type)
}

///|
fn Gateway::apply_proxy_app_timeout_config(
  self : Gateway,
  app_type : String,
  path : StringView,
  config : Json?,
) -> Bool {
  match
    proxy_int_request(path, config, [
      "streaming_first_byte_timeout", "streamingFirstByteTimeout",
    ]) {
    Some(timeout) if timeout > 0 =>
      self.proxy_streaming_first_byte_timeout.set(app_type, timeout)
    Some(_) => return false
    None => ()
  }
  match
    proxy_int_request(path, config, [
      "streaming_idle_timeout", "streamingIdleTimeout",
    ]) {
    Some(timeout) if timeout > 0 =>
      self.proxy_streaming_idle_timeout.set(app_type, timeout)
    Some(_) => return false
    None => ()
  }
  match
    proxy_int_request(path, config, [
      "non_streaming_timeout", "nonStreamingTimeout",
    ]) {
    Some(timeout) if timeout > 0 =>
      self.proxy_non_streaming_timeout.set(app_type, timeout)
    Some(_) => return false
    None => ()
  }
  true
}

///|
fn Gateway::proxy_app_enabled_for_app(
  self : Gateway,
  app_type : String,
) -> Bool {
  self.proxy_app_enabled
  .get(app_type)
  .unwrap_or(self.provider_router.has_configured_app(app_type))
}

///|
fn Gateway::can_set_auto_failover_ccs(
  self : Gateway,
  app_type : String,
  enabled : Bool,
) -> Bool {
  !enabled || self.proxy_app_enabled_for_app(app_type)
}

///|
async fn Gateway::handle_proxy_provider_health(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard proxy_provider_query(r.path) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  write_usage_json(
    w,
    self.provider_router.provider_health_json(
      query.provider_id,
      query.app_type,
      @async.now().to_string(),
    ),
  )
}

///|
async fn Gateway::handle_proxy_circuit_breaker_config(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.provider_router.circuit_config.to_json())
}

///|
async fn Gateway::handle_proxy_update_circuit_breaker_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = r.body.read_all().text()
  let config = if body.trim().is_empty() {
    proxy_circuit_config_from_query(r.path)
  } else {
    let parsed = @json.parse(body) catch {
      _ => {
        write_usage_bad_request(w, "invalid_circuit_breaker_config")
        return
      }
    }
    match circuit_breaker_config_from_json(parsed) {
      Some(config) => Some(config)
      None => proxy_circuit_config_from_query(r.path)
    }
  }
  guard config is Some(config) else {
    write_usage_bad_request(w, "invalid_circuit_breaker_config")
    return
  }
  self.provider_router.update_all_configs(config)
  write_usage_json(w, config.to_json())
}

///|
async fn Gateway::handle_proxy_circuit_breaker_stats(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard proxy_provider_query(r.path) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  let body = match
    self.provider_router.get_circuit_breaker_stats(
      query.provider_id,
      query.app_type,
    ) {
    Some(stats) => stats.to_json()
    None => Json::null()
  }
  write_usage_json(w, body)
}

///|
async fn Gateway::handle_proxy_reset_circuit_breaker(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard proxy_provider_query(r.path) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  let app_enabled = self.proxy_app_enabled_for_app(query.app_type)
  let _switched = self.provider_router.reset_provider_breaker_ccs(
    query.provider_id,
    query.app_type,
    app_enabled~,
    proxy_running=self.proxy_enabled,
  )
  write_usage_json(w, ccs_unit_success_json())
}

///|
async fn Gateway::handle_proxy_failover_queue(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard usage_query_value_any(r.path, "app_type", "appType") is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(w, self.provider_router.failover_queue_json(app_type))
}

///|
async fn Gateway::handle_proxy_available_failover_providers(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard usage_query_value_any(r.path, "app_type", "appType") is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(
    w,
    self.provider_router.available_failover_providers_json(app_type),
  )
}

///|
async fn Gateway::handle_proxy_add_failover_queue(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard proxy_provider_query(r.path) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  self.provider_router.add_to_failover_queue(query.app_type, query.provider_id)
  write_usage_json(w, ccs_unit_success_json())
}

///|
async fn Gateway::handle_proxy_remove_failover_queue(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard proxy_provider_query(r.path) is Some(query) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  self.provider_router.remove_from_failover_queue(
    query.app_type,
    query.provider_id,
  )
  write_usage_json(w, ccs_unit_success_json())
}

///|
async fn Gateway::handle_proxy_auto_failover_enabled(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard usage_query_value_any(r.path, "app_type", "appType") is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  write_usage_json(
    w,
    Json::boolean(self.provider_router.auto_failover_enabled_for_app(app_type)),
  )
}

///|
async fn Gateway::handle_proxy_set_auto_failover_enabled(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard usage_query_value_any(r.path, "app_type", "appType") is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_enabled_value(r) is Some(enabled) else {
    write_usage_bad_request(w, "missing_enabled")
    return
  }
  if !self.can_set_auto_failover_ccs(app_type, enabled) {
    write_usage_bad_request(w, "auto_failover_requires_proxy_takeover")
    return
  }
  if !self.provider_router.set_auto_failover_command_ccs(app_type, enabled) {
    write_usage_bad_request(w, "auto_failover_unavailable")
    return
  }
  write_usage_json(w, ccs_unit_success_json())
}

///|
async fn Gateway::handle_proxy_takeover_status(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(self.proxy_takeover_status_json().stringify(indent=2))
  w.flush()
}

///|
async fn Gateway::handle_proxy_set_takeover_for_app(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_string_request(r.path, config, ["app_type", "appType"])
    is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_bool_request(r.path, config, ["enabled"]) is Some(enabled) else {
    write_usage_bad_request(w, "missing_enabled")
    return
  }
  self.proxy_takeover_enabled.set(app_type, enabled)
  write_usage_json(w, self.proxy_takeover_status_json())
}

///|
async fn Gateway::handle_proxy_live_takeover_active(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, Json::boolean(self.proxy_takeover_active()))
}

///|
async fn Gateway::handle_proxy_switch_provider(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_string_request(r.path, config, ["app_type", "appType"])
    is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  guard proxy_string_request(r.path, config, ["provider_id", "providerId"])
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard self.provider_router.provider_by_id(app_type, provider_id)
    is Some(provider) else {
    write_usage_bad_request(w, "provider_not_found")
    return
  }
  if provider.provider_type == Some("official") {
    write_usage_bad_request(w, "official_provider_blocked_during_takeover")
    return
  }
  self.provider_router.set_current_provider(app_type, provider_id)
  self.stats.set_active_target(
    app_type,
    provider.provider_id,
    provider.provider_name,
  )
  let response : Map[String, Json] = { "ok": Json::boolean(true) }
  if app_type == "claude" || app_type == "claude-desktop" {
    response["takeoverSettingsConfig"] = ccs_claude_takeover_settings_config_json(
      provider,
      "http://\{self.proxy_listen_address}:\{self.proxy_listen_port}",
    )
  }
  write_usage_json(w, Json::object(response))
}

///|
async fn Gateway::handle_get_providers(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard provider_app_from_request(r.path, None) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  write_usage_json(w, self.provider_router.providers_ccs_json(app_type))
}

///|
async fn Gateway::handle_get_current_provider(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard provider_app_from_request(r.path, None) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  write_usage_json(
    w,
    Json::string(
      self.provider_router.current_provider_for_ccs_command(app_type),
    ),
  )
}

///|
async fn Gateway::handle_import_default_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  match ccs_import_default_config_json(self.provider_router, app_type) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_add_provider(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
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
  self.add_provider_target_ccs(app_type, target, add_to_live)
  write_usage_json(w, Json::boolean(true))
}

///|
fn Gateway::add_provider_target_ccs(
  self : Gateway,
  app_type : String,
  target : ProviderRouteTarget,
  add_to_live : Bool,
) -> Unit {
  ignore(add_to_live)
  let provider_id = target.provider_id
  self.sync_provider_limits_from_target(target)
  self.provider_router.upsert_provider(target)
  if !provider_app_is_additive(app_type) {
    if self.provider_router.current_provider_id(app_type) is None {
      self.provider_router.set_current_provider(app_type, provider_id)
    }
  }
}

///|
async fn Gateway::handle_update_provider(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
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
  match self.update_provider_target_ccs(app_type, target, original_id) {
    Ok(_) => write_usage_json(w, Json::boolean(true))
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
fn Gateway::update_provider_target_ccs(
  self : Gateway,
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
  self.sync_provider_limits_from_target(target)
  self.provider_router.upsert_provider(target)
  if was_current {
    self.provider_router.set_current_provider(app_type, provider_id)
  }
  Ok(())
}

///|
async fn Gateway::handle_delete_provider(
  self : Gateway,
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
async fn Gateway::handle_remove_provider_from_live_config(
  self : Gateway,
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
async fn Gateway::handle_switch_provider(
  self : Gateway,
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
  guard self.provider_router.provider_by_id(app_type, provider_id)
    is Some(provider) else {
    write_usage_bad_request(w, "provider_not_found")
    return
  }
  self.provider_router.set_current_provider(app_type, provider_id)
  self.stats.set_active_target(
    app_type,
    provider.provider_id,
    provider.provider_name,
  )
  write_usage_json(w, { "warnings": Json::array([]) }.to_json())
}

///|
async fn Gateway::handle_open_provider_terminal(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard proxy_string_request(r.path, body, ["providerId", "provider_id"])
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  let cwd = proxy_string_request(r.path, body, ["cwd"])
  match
    ccs_open_provider_terminal_json(
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
async fn Gateway::handle_get_claude_desktop_status(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  let status = @claude_desktop.status()
  write_usage_json(
    w,
    {
      "supported": Json::boolean(true),
      "configured": Json::boolean(status.configured),
      "appliedId": Json::null(),
      "profilePath": Json::string(status.profile_path),
      "configLibraryPath": Json::null(),
      "mode": if status.configured {
        Json::string("proxy")
      } else {
        Json::null()
      },
      "expectedBaseUrl": Json::string(
        @claude_desktop.local_gateway_base_url(self.host, self.port),
      ),
      "actualBaseUrl": Json::null(),
      "proxyRunning": Json::boolean(true),
      "staleRawModels": Json::boolean(false),
      "missingRouteMappings": Json::boolean(false),
      "gatewayTokenConfigured": Json::boolean(status.token_configured),
    }.to_json(),
  )
}

///|
async fn Gateway::handle_get_claude_desktop_default_routes(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, claude_desktop_default_routes_json())
}

///|
async fn Gateway::handle_import_claude_desktop_providers_from_claude(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    Json::number(self.import_claude_desktop_providers_from_claude().to_double()),
  )
}

///|
async fn Gateway::handle_ensure_claude_desktop_official_provider(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    Json::boolean(self.ensure_claude_desktop_official_provider()),
  )
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
fn Gateway::ensure_claude_desktop_official_provider(self : Gateway) -> Bool {
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
      model_mapping=ccs_model_mapping_from_env(),
    ),
  )
  if self.provider_router.current_provider_id("claude-desktop") is None {
    self.provider_router.set_current_provider("claude-desktop", "codex-oauth")
  }
  true
}

///|
fn Gateway::import_claude_desktop_providers_from_claude(self : Gateway) -> Int {
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
    self.provider_router.upsert_provider(
      ProviderRouteTarget::new(
        app_type="claude-desktop",
        provider_id=provider.provider_id,
        provider_name=provider.provider_name,
        enabled=provider.enabled,
        provider_type=provider.provider_type,
        api_format=provider.api_format,
        prompt_cache_key=provider.prompt_cache_key,
        codex_fast_mode=provider.codex_fast_mode,
        base_url=provider.base_url,
        api_key=provider.api_key,
        is_full_url=provider.is_full_url,
        model_mapping=provider.model_mapping,
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
async fn Gateway::handle_sync_current_providers_live(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  let targets = self.provider_router.sync_current_provider_targets()
  for target in targets {
    self.stats.set_active_target(
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
async fn Gateway::handle_read_live_provider_settings(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard provider_app_from_request(r.path, None) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  write_usage_json(
    w,
    self.provider_router.read_live_provider_settings(app_type),
  )
}

///|
async fn Gateway::handle_get_claude_plugin_status(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    {
      "exists": Json::boolean(
        self.claude_plugin_config is Some(_) ||
        @fsx.exists_as_file(ccs_claude_plugin_config_path()),
      ),
      "path": Json::string(ccs_claude_plugin_config_path()),
    }.to_json(),
  )
}

///|
async fn Gateway::handle_read_claude_plugin_config(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.claude_plugin_config {
    Some(content) => write_usage_json(w, Json::string(content))
    None =>
      if @fsx.exists_as_file(ccs_claude_plugin_config_path()) {
        let content = @fsx.read_file(ccs_claude_plugin_config_path()) catch {
          _ => {
            write_usage_json(w, Json::null())
            return
          }
        }
        write_usage_json(w, Json::string(content))
      } else {
        write_usage_json(w, Json::null())
      }
  }
}

///|
async fn Gateway::handle_apply_claude_plugin_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let official = proxy_bool_request(r.path, body, ["official"]).unwrap_or(false)
  if official {
    self.claude_plugin_applied = false
    self.claude_plugin_config = None
  } else {
    self.claude_plugin_applied = true
    self.claude_plugin_config = Some("{\n  \"primaryApiKey\": \"any\"\n}\n")
  }
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_is_claude_plugin_applied(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.claude_plugin_config {
    Some(content) =>
      write_usage_json(w, Json::boolean(ccs_json_primary_api_key_any(content)))
    None =>
      if @fsx.exists_as_file(ccs_claude_plugin_config_path()) {
        let content = @fsx.read_file(ccs_claude_plugin_config_path()) catch {
          _ => {
            write_usage_json(w, Json::boolean(false))
            return
          }
        }
        write_usage_json(
          w,
          Json::boolean(ccs_json_primary_api_key_any(content)),
        )
      } else {
        write_usage_json(w, Json::boolean(self.claude_plugin_applied))
      }
  }
}

///|
async fn Gateway::handle_apply_claude_onboarding_skip(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.claude_onboarding_skipped = true
  self.app_settings = ccs_settings_with_bool(
    self.app_settings,
    "skipClaudeOnboarding",
    true,
  )
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_clear_claude_onboarding_skip(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.claude_onboarding_skipped = false
  self.app_settings = ccs_settings_with_bool(
    self.app_settings,
    "skipClaudeOnboarding",
    false,
  )
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_list_daily_memory_files(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_list_daily_memory_files_json())
}

///|
async fn Gateway::handle_read_daily_memory_file(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["filename"]) is Some(filename) &&
    ccs_validate_daily_memory_filename(filename) else {
    write_usage_bad_request(w, "invalid_daily_memory_filename")
    return
  }
  let path = ccs_daily_memory_file_path(filename)
  if !@fsx.exists_as_file(path) {
    write_usage_json(w, Json::null())
    return
  }
  let content = @fsx.read_file(path) catch {
    _ => {
      write_usage_bad_request(w, "daily_memory_read_failed")
      return
    }
  }
  write_usage_json(w, Json::string(content))
}

///|
async fn Gateway::handle_write_daily_memory_file(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["filename"]) is Some(filename) &&
    ccs_validate_daily_memory_filename(filename) else {
    write_usage_bad_request(w, "invalid_daily_memory_filename")
    return
  }
  let content = proxy_string_request(r.path, body, ["content"]).unwrap_or("")
  if !ccs_ensure_directory(ccs_openclaw_memory_dir()) {
    write_usage_bad_request(w, "daily_memory_directory_failed")
    return
  }
  @fsx.write_to_file(ccs_daily_memory_file_path(filename), content) catch {
    _ => {
      write_usage_bad_request(w, "daily_memory_write_failed")
      return
    }
  }
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_search_daily_memory_files(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let query = proxy_string_request(r.path, body, ["query"]).unwrap_or("")
  write_usage_json(w, ccs_search_daily_memory_files_json(query))
}

///|
async fn Gateway::handle_delete_daily_memory_file(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["filename"]) is Some(filename) &&
    ccs_validate_daily_memory_filename(filename) else {
    write_usage_bad_request(w, "invalid_daily_memory_filename")
    return
  }
  let path = ccs_daily_memory_file_path(filename)
  if @fsx.exists_as_file(path) {
    @fsx.remove(path) catch {
      _ => {
        write_usage_bad_request(w, "daily_memory_delete_failed")
        return
      }
    }
  }
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_read_workspace_file(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["filename"]) is Some(filename) &&
    ccs_validate_workspace_filename(filename) else {
    write_usage_bad_request(w, "invalid_workspace_filename")
    return
  }
  let path = ccs_workspace_file_path(filename)
  if !@fsx.exists_as_file(path) {
    write_usage_json(w, Json::null())
    return
  }
  let content = @fsx.read_file(path) catch {
    _ => {
      write_usage_bad_request(w, "workspace_file_read_failed")
      return
    }
  }
  write_usage_json(w, Json::string(content))
}

///|
async fn Gateway::handle_write_workspace_file(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["filename"]) is Some(filename) &&
    ccs_validate_workspace_filename(filename) else {
    write_usage_bad_request(w, "invalid_workspace_filename")
    return
  }
  let content = proxy_string_request(r.path, body, ["content"]).unwrap_or("")
  if !ccs_ensure_directory(ccs_openclaw_workspace_dir()) {
    write_usage_bad_request(w, "workspace_directory_failed")
    return
  }
  @fsx.write_to_file(ccs_workspace_file_path(filename), content) catch {
    _ => {
      write_usage_bad_request(w, "workspace_file_write_failed")
      return
    }
  }
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_open_workspace_directory(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let subdir = proxy_string_request(r.path, body, ["subdir"]).unwrap_or(
    "workspace",
  )
  let target = if subdir == "memory" {
    ccs_openclaw_memory_dir()
  } else {
    ccs_openclaw_workspace_dir()
  }
  if !ccs_ensure_directory(target) {
    write_usage_bad_request(w, "workspace_directory_failed")
    return
  }
  write_usage_json(w, Json::boolean(true))
}

///|
async fn Gateway::handle_get_live_provider_ids(
  self : Gateway,
  w : @httpx.ResponseWriter,
  app_type : String,
) -> Unit {
  write_usage_json(w, self.provider_router.live_provider_ids_json(app_type))
}

///|
async fn Gateway::handle_get_live_provider(
  self : Gateway,
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
async fn Gateway::handle_scan_openclaw_config_health(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.openclaw_config_health_json())
}

///|
async fn Gateway::handle_get_openclaw_default_model(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.openclaw_default_model.unwrap_or(Json::null()))
}

///|
async fn Gateway::handle_set_openclaw_default_model(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard openclaw_default_model_from_request(r.path, body) is Some(model) else {
    write_usage_bad_request(w, "invalid_openclaw_default_model")
    return
  }
  self.openclaw_default_model = Some(model)
  write_usage_json(w, suite_write_outcome_json())
}

///|
async fn Gateway::handle_get_openclaw_model_catalog(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.openclaw_model_catalog.unwrap_or(Json::null()))
}

///|
async fn Gateway::handle_set_openclaw_model_catalog(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard suite_object_request(r.path, body, "catalog") is Some(catalog) else {
    write_usage_bad_request(w, "invalid_openclaw_model_catalog")
    return
  }
  self.openclaw_model_catalog = Some(catalog)
  write_usage_json(w, suite_write_outcome_json())
}

///|
async fn Gateway::handle_get_openclaw_agents_defaults(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.openclaw_agents_defaults.unwrap_or(Json::null()))
}

///|
async fn Gateway::handle_set_openclaw_agents_defaults(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let defaults = match suite_object_request(r.path, body, "defaults") {
    Some(defaults) => Some(defaults)
    None =>
      match openclaw_default_model_from_request(r.path, body) {
        Some(model) => Some({ "model": model }.to_json())
        None => None
      }
  }
  guard defaults is Some(defaults_json) else {
    write_usage_bad_request(w, "invalid_openclaw_agents_defaults")
    return
  }
  self.openclaw_agents_defaults = Some(defaults_json)
  write_usage_json(w, suite_write_outcome_json())
}

///|
async fn Gateway::handle_get_openclaw_env(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.openclaw_env)
}

///|
async fn Gateway::handle_set_openclaw_env(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard openclaw_env_from_request(r.path, body) is Some(env) else {
    write_usage_bad_request(w, "invalid_openclaw_env")
    return
  }
  self.openclaw_env = env
  write_usage_json(w, suite_write_outcome_json())
}

///|
async fn Gateway::handle_get_openclaw_tools(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.openclaw_tools)
}

///|
async fn Gateway::handle_set_openclaw_tools(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard openclaw_tools_from_request(r.path, body) is Some(tools) else {
    write_usage_bad_request(w, "invalid_openclaw_tools")
    return
  }
  self.openclaw_tools = tools
  write_usage_json(w, suite_write_outcome_json())
}

///|
async fn Gateway::handle_get_hermes_model_config(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.hermes_model_config.unwrap_or(Json::null()))
}

///|
async fn Gateway::handle_get_hermes_memory(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard hermes_memory_kind_from_request(r.path, None) is Some(kind) else {
    write_usage_bad_request(w, "invalid_hermes_memory_kind")
    return
  }
  write_usage_json(w, Json::string(self.hermes_memory.get(kind).unwrap_or("")))
}

///|
async fn Gateway::handle_set_hermes_memory(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard hermes_memory_kind_from_request(r.path, body) is Some(kind) else {
    write_usage_bad_request(w, "invalid_hermes_memory_kind")
    return
  }
  let content = proxy_string_request(r.path, body, ["content", "value", "text"]).unwrap_or(
    "",
  )
  self.hermes_memory[kind] = content
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_get_hermes_memory_limits(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, hermes_memory_limits_json(self.hermes_memory_enabled))
}

///|
async fn Gateway::handle_set_hermes_memory_enabled(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard hermes_memory_kind_from_request(r.path, body) is Some(kind) else {
    write_usage_bad_request(w, "invalid_hermes_memory_kind")
    return
  }
  guard proxy_bool_request(r.path, body, ["enabled"]) is Some(enabled) else {
    write_usage_bad_request(w, "missing_enabled")
    return
  }
  self.hermes_memory_enabled[kind] = enabled
  write_usage_json(w, suite_write_outcome_json())
}

///|
async fn Gateway::handle_open_hermes_web_ui(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let port = hermes_web_port_from_request(r.path)
  let path = usage_query_value(r.path, "path").unwrap_or("/")
  if !hermes_web_ui_is_live(port) {
    write_usage_bad_request(w, HERMES_WEB_OFFLINE_ERROR)
    return
  }
  ignore(hermes_web_ui_target_url(port, path))
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_launch_hermes_dashboard(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  match launch_hermes_dashboard_standalone() {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_import_live_providers(
  self : Gateway,
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
async fn Gateway::handle_get_universal_providers(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.provider_router.universal_providers_json())
}

///|
async fn Gateway::handle_get_universal_provider(
  self : Gateway,
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
async fn Gateway::handle_upsert_universal_provider(
  self : Gateway,
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
async fn Gateway::handle_delete_universal_provider(
  self : Gateway,
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
async fn Gateway::handle_sync_universal_provider(
  self : Gateway,
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
async fn Gateway::handle_get_provider_presets(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_provider_presets_json(r.path))
}

///|
async fn Gateway::handle_test_api_endpoints(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let timeout_secs = proxy_int_request(r.path, body, [
    "timeoutSecs", "timeout_secs",
  ]).unwrap_or(8)
  let urls = provider_endpoint_urls_from_request(r.path, body)
  write_usage_json(
    w,
    provider_endpoint_latency_results_json(urls, timeout_secs),
  )
}

///|
async fn Gateway::handle_update_providers_sort_order(
  self : Gateway,
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
async fn Gateway::handle_get_custom_endpoints(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard provider_app_from_request(r.path, None) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  guard provider_id_from_request(r.path, None) is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  write_usage_json(
    w,
    self.provider_router.custom_endpoints_json(app_type, provider_id),
  )
}

///|
async fn Gateway::handle_add_custom_endpoint(
  self : Gateway,
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
async fn Gateway::handle_remove_custom_endpoint(
  self : Gateway,
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
async fn Gateway::handle_update_endpoint_last_used(
  self : Gateway,
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
fn Gateway::proxy_takeover_status_json(self : Gateway) -> Json {
  {
    "claude": Json::boolean(self.proxy_takeover_for_app("claude")),
    "claude-desktop": Json::boolean(
      self.proxy_takeover_for_app("claude-desktop"),
    ),
    "codex": Json::boolean(self.proxy_takeover_for_app("codex")),
    "gemini": Json::boolean(self.proxy_takeover_for_app("gemini")),
    "opencode": Json::boolean(self.proxy_takeover_for_app("opencode")),
    "openclaw": Json::boolean(self.proxy_takeover_for_app("openclaw")),
    "hermes": Json::boolean(self.proxy_takeover_for_app("hermes")),
  }.to_json()
}

///|
fn Gateway::proxy_takeover_for_app(self : Gateway, app_type : String) -> Bool {
  self.proxy_takeover_enabled.get(app_type).unwrap_or(false)
}

///|
fn Gateway::proxy_takeover_active(self : Gateway) -> Bool {
  for
    app_type in [
      "claude", "claude-desktop", "codex", "gemini", "opencode", "openclaw", "hermes",
    ] {
    if self.proxy_takeover_for_app(app_type) {
      return true
    }
  }
  false
}

///|
fn Gateway::proxy_clear_takeover(self : Gateway) -> Unit {
  for
    app_type in [
      "claude", "claude-desktop", "codex", "gemini", "opencode", "openclaw", "hermes",
    ] {
    self.proxy_takeover_enabled.set(app_type, false)
  }
}

///|
fn Gateway::proxy_clear_enabled_apps_for_manual_stop(self : Gateway) -> Unit {
  for app_type in ["claude", "codex", "gemini"] {
    self.proxy_app_enabled.set(app_type, false)
  }
}

///|
async fn Gateway::handle_proxy_running(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(Json::boolean(self.proxy_enabled).stringify())
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
  let body = proxy_json_body(r)
  let filters = usage_request_log_filters_from_request(r.path, body)
  let pricing_overrides = self.pricing_override_rows()
  let backfilled = self.stats.backfill_missing_usage_costs(
    pricing_overrides,
    self.pricing_deleted_model_ids,
  )
  if backfilled > 0 {
    self.stats.save_persistent_store()
  }
  w.write(
    self.stats
    .usage_logs_paginated_json(
      filters,
      page=usage_int_from_request(r.path, body, ["page"]).unwrap_or(0),
      page_size=usage_int_from_request(r.path, body, ["page_size", "pageSize"]).unwrap_or(
        20,
      ),
      pricing_overrides~,
      deleted_model_ids=self.pricing_deleted_model_ids,
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
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    self.stats.usage_summary_filtered_json(
      start_date=usage_int_from_request(r.path, body, [
        "start_date", "startDate",
      ]),
      end_date=usage_int_from_request(r.path, body, ["end_date", "endDate"]),
      app_type=usage_string_from_request(r.path, body, ["app_type", "appType"]),
    ),
  )
}

///|
async fn Gateway::handle_usage_summary_by_app(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    self.stats.usage_summary_by_app_filtered_json(
      start_date=usage_int_from_request(r.path, body, [
        "start_date", "startDate",
      ]),
      end_date=usage_int_from_request(r.path, body, ["end_date", "endDate"]),
    ),
  )
}

///|
async fn Gateway::handle_usage_trends(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let start_ts = usage_int_from_request(r.path, body, [
    "start_date", "startDate",
  ])
  let end_ts = usage_int_from_request(r.path, body, ["end_date", "endDate"])
  let app_type = usage_string_from_request(r.path, body, ["app_type", "appType"])
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
  let body = proxy_json_body(r)
  guard usage_string_from_request(r.path, body, ["provider_id", "providerId"])
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard usage_string_from_request(r.path, body, ["app_type", "appType"])
    is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  let daily_limit_usd = usage_string_from_request(r.path, body, [
    "daily_limit_usd", "dailyLimitUsd",
  ])
  let monthly_limit_usd = usage_string_from_request(r.path, body, [
    "monthly_limit_usd", "monthlyLimitUsd",
  ])
  let provider_limits = self.provider_limit_config_for_provider(
    provider_id, app_type,
  )
  let daily_limit_usd = usage_limit_override_or_provider_limit(
    daily_limit_usd,
    provider_limits.map(fn(config) { config.daily_limit_usd }),
  )
  let monthly_limit_usd = usage_limit_override_or_provider_limit(
    monthly_limit_usd,
    provider_limits.map(fn(config) { config.monthly_limit_usd }),
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
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    self.stats.provider_stats_filtered_json(
      start_date=usage_int_from_request(r.path, body, [
        "start_date", "startDate",
      ]),
      end_date=usage_int_from_request(r.path, body, ["end_date", "endDate"]),
      app_type=usage_string_from_request(r.path, body, ["app_type", "appType"]),
    ),
  )
}

///|
async fn Gateway::handle_usage_model_stats(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    self.stats.model_stats_filtered_json(
      start_date=usage_int_from_request(r.path, body, [
        "start_date", "startDate",
      ]),
      end_date=usage_int_from_request(r.path, body, ["end_date", "endDate"]),
      app_type=usage_string_from_request(r.path, body, ["app_type", "appType"]),
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
async fn Gateway::handle_query_provider_usage(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_string_request(r.path, config, ["provider_id", "providerId"])
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard proxy_string_request(r.path, config, ["app", "app_type", "appType"])
    is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  write_usage_json(
    w,
    self.query_provider_usage_standalone(app_type, provider_id).to_json(),
  )
}

///|
async fn Gateway::query_provider_usage_standalone(
  self : Gateway,
  app_type : String,
  provider_id : String,
) -> UsageResult {
  match self.usage_cache.get_script(app_type, provider_id) {
    Some(result) => return result
    None => ()
  }
  match self.provider_router.provider_by_id(app_type, provider_id) {
    Some(provider) =>
      match ccs_provider_balance_query_credentials(provider) {
        Some((base_url, api_key)) => return ccs_get_balance(base_url, api_key)
        None => ()
      }
    None => ()
  }
  UsageResult::new(false, error=Some("Usage query is disabled"))
}

///|
fn ccs_provider_balance_query_credentials(
  provider : ProviderRouteTarget,
) -> (String, String)? {
  guard provider.base_url is Some(base_url) else { return None }
  guard ccs_detect_balance_provider(base_url) is Some(_) else { return None }
  Some((base_url, provider.api_key.unwrap_or("")))
}

///|
async fn Gateway::handle_get_balance(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["baseUrl", "base_url"])
    is Some(base_url) else {
    write_usage_bad_request(w, "missing_base_url")
    return
  }
  guard proxy_string_request(r.path, body, ["apiKey", "api_key"])
    is Some(api_key) else {
    write_usage_bad_request(w, "missing_api_key")
    return
  }
  write_usage_json(w, ccs_get_balance(base_url, api_key).to_json())
}

///|
async fn Gateway::handle_get_subscription_quota(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, [
      "tool", "app", "appType", "app_type",
    ])
    is Some(tool) else {
    write_usage_bad_request(w, "missing_tool")
    return
  }
  let quota = ccs_get_subscription_quota(tool)
  self.usage_cache.put_subscription(quota.tool, quota)
  write_usage_json(w, quota.to_json())
}

///|
async fn Gateway::handle_get_codex_oauth_quota(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let account_id = proxy_string_request(r.path, body, [
    "accountId", "account_id", "account",
  ])
  let quota = ccs_get_codex_oauth_quota(account_id)
  self.usage_cache.put_subscription(quota.tool, quota)
  write_usage_json(w, quota.to_json())
}

///|
async fn Gateway::handle_get_codex_oauth_models(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let account_id = proxy_string_request(r.path, body, [
    "accountId", "account_id", "account",
  ])
  match ccs_get_codex_oauth_models(account_id) {
    Ok(models) => write_usage_json(w, fetched_models_to_json(models))
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
fn managed_auth_provider_request(path : StringView, body : Json?) -> String {
  proxy_string_request(path, body, ["authProvider", "auth_provider", "provider"]).unwrap_or(
    managed_auth_default_provider(),
  )
}

///|
async fn Gateway::handle_auth_start_login(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  match
    managed_auth_start_login(
      provider,
      github_domain=copilot_github_domain_request(r.path, body),
    ) {
    Ok(flow) => {
      if flow is Object(obj) &&
        json_string_from_map(obj, "device_code") is Some(device_code) &&
        json_string_from_map(obj, "user_code") is Some(user_code) {
        self.auth_device_user_codes[device_code] = user_code
      }
      write_usage_json(w, flow)
    }
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_auth_poll_for_account(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  guard proxy_string_request(r.path, body, [
      "deviceCode", "device_code", "deviceAuthId", "device_auth_id",
    ])
    is Some(device_code) else {
    write_usage_bad_request(w, "missing_device_code")
    return
  }
  let user_code = match
    proxy_string_request(r.path, body, ["userCode", "user_code", "code"]) {
    Some(value) => Some(value)
    None => self.auth_device_user_codes.get(device_code)
  }
  if provider != AUTH_PROVIDER_GITHUB_COPILOT && user_code is None {
    write_usage_bad_request(w, "missing_user_code")
    return
  }
  match
    managed_auth_poll_for_account(
      provider,
      device_code,
      user_code,
      github_domain=copilot_github_domain_request(r.path, body),
    ) {
    Ok(Some(account)) => {
      self.auth_device_user_codes.remove(device_code)
      try @codex.load_credentials() catch {
        _ => ()
      } noraise {
        credentials => self.credentials = Some(credentials)
      }
      write_usage_json(w, account)
    }
    Ok(None) => write_usage_json(w, Json::null())
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_auth_list_accounts(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  match managed_auth_list_accounts(provider) {
    Ok(accounts) => write_usage_json(w, accounts)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_auth_get_status(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  match managed_auth_get_status(provider) {
    Ok(status) => write_usage_json(w, status)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_auth_remove_account(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  guard proxy_string_request(r.path, body, ["accountId", "account_id", "id"])
    is Some(account_id) else {
    write_usage_bad_request(w, "missing_account_id")
    return
  }
  match managed_auth_remove_account(provider, account_id) {
    Ok(result) => {
      self.credentials = None
      write_usage_json(w, result)
    }
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_auth_set_default_account(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  guard proxy_string_request(r.path, body, ["accountId", "account_id", "id"])
    is Some(account_id) else {
    write_usage_bad_request(w, "missing_account_id")
    return
  }
  match managed_auth_set_default_account(provider, account_id) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_auth_logout(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let provider = managed_auth_provider_request(r.path, body)
  match managed_auth_logout(provider) {
    Ok(result) => {
      self.credentials = None
      write_usage_json(w, result)
    }
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
fn copilot_github_domain_request(path : StringView, body : Json?) -> String? {
  proxy_string_request(path, body, ["githubDomain", "github_domain", "domain"])
}

///|
fn copilot_account_id_request(path : StringView, body : Json?) -> String? {
  proxy_string_request(path, body, ["accountId", "account_id", "id"])
}

///|
async fn Gateway::handle_copilot_start_device_flow(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  match copilot_start_device_flow(copilot_github_domain_request(r.path, body)) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_copilot_poll_for_account(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["deviceCode", "device_code"])
    is Some(device_code) else {
    write_usage_bad_request(w, "missing_device_code")
    return
  }
  match
    copilot_poll_for_account(
      device_code,
      copilot_github_domain_request(r.path, body),
    ) {
    Ok(Some(account)) => write_usage_json(w, account)
    Ok(None) => write_usage_json(w, Json::null())
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_copilot_poll_for_auth(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["deviceCode", "device_code"])
    is Some(device_code) else {
    write_usage_bad_request(w, "missing_device_code")
    return
  }
  match
    copilot_poll_for_account(
      device_code,
      copilot_github_domain_request(r.path, body),
    ) {
    Ok(Some(_)) => write_usage_json(w, Json::boolean(true))
    Ok(None) => write_usage_json(w, Json::boolean(false))
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_copilot_list_accounts(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, copilot_list_accounts())
}

///|
async fn Gateway::handle_copilot_get_auth_status(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, copilot_get_auth_status())
}

///|
async fn Gateway::handle_copilot_is_authenticated(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::boolean(copilot_is_authenticated()))
}

///|
async fn Gateway::handle_copilot_logout(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, copilot_logout())
}

///|
async fn Gateway::handle_copilot_remove_account(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard copilot_account_id_request(r.path, body) is Some(account_id) else {
    write_usage_bad_request(w, "missing_account_id")
    return
  }
  match copilot_remove_account(account_id) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_copilot_set_default_account(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard copilot_account_id_request(r.path, body) is Some(account_id) else {
    write_usage_bad_request(w, "missing_account_id")
    return
  }
  match copilot_set_default_account(account_id) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_copilot_get_token(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  match copilot_get_token(copilot_account_id_request(r.path, body)) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_copilot_get_models(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  match copilot_get_models(copilot_account_id_request(r.path, body)) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_copilot_get_usage(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  match copilot_get_usage(copilot_account_id_request(r.path, body)) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_get_coding_plan_quota(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["baseUrl", "base_url"])
    is Some(base_url) else {
    write_usage_bad_request(w, "missing_base_url")
    return
  }
  guard proxy_string_request(r.path, body, ["apiKey", "api_key"])
    is Some(api_key) else {
    write_usage_bad_request(w, "missing_api_key")
    return
  }
  let quota = ccs_get_coding_plan_quota(base_url, api_key)
  self.usage_cache.put_subscription(quota.tool, quota)
  write_usage_json(w, quota.to_json())
}

///|
async fn Gateway::handle_test_usage_script(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let config = proxy_embedded_config(body)
  guard proxy_string_request(r.path, config, ["provider_id", "providerId"])
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard proxy_string_request(r.path, config, ["app", "app_type", "appType"])
    is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  let result = match usage_result_from_request(r.path, body) {
    Some(result) => result
    None =>
      match test_usage_script_template_result(r.path, body) {
        Some(result) => result
        None =>
          UsageResult::new(
            false,
            error=Some(
              "Usage script execution is unavailable in standalone Moonstat; provide a ccs UsageResult JSON object as result or scriptCode.",
            ),
          )
      }
  }
  self.usage_cache.put_script(app_type, provider_id, result)
  write_usage_json(w, result.to_json())
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
async fn Gateway::handle_list_sessions(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, ccs_list_sessions_json())
}

///|
async fn Gateway::handle_get_session_messages(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["providerId", "provider_id"])
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard proxy_string_request(r.path, body, ["sourcePath", "source_path"])
    is Some(source_path) else {
    write_usage_bad_request(w, "missing_source_path")
    return
  }
  match ccs_get_session_messages_json(provider_id, source_path) {
    Ok(messages) => write_usage_json(w, messages)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_launch_session_terminal(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["command"]) is Some(command) else {
    write_usage_bad_request(w, "missing_command")
    return
  }
  let cwd = proxy_string_request(r.path, body, ["cwd"])
  let custom_config = proxy_string_request(r.path, body, [
    "customConfig", "custom_config",
  ])
  match
    ccs_launch_session_terminal_json(
      command,
      cwd,
      custom_config,
      ccs_session_terminal_from_settings(self.app_settings),
    ) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_delete_session(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["providerId", "provider_id"])
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard proxy_string_request(r.path, body, ["sessionId", "session_id"])
    is Some(session_id) else {
    write_usage_bad_request(w, "missing_session_id")
    return
  }
  guard proxy_string_request(r.path, body, ["sourcePath", "source_path"])
    is Some(source_path) else {
    write_usage_bad_request(w, "missing_source_path")
    return
  }
  match ccs_delete_session_json(provider_id, session_id, source_path) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_delete_sessions(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard ccs_delete_session_requests_from_json(body) is Some(items) else {
    write_usage_bad_request(w, "missing_items")
    return
  }
  write_usage_json(w, ccs_delete_sessions_json(items))
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
  let body = proxy_json_body(r)
  guard usage_pricing_from_request(r.path, body) is Some(pricing) else {
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
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_usage_delete_model_pricing(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard usage_string_from_request(r.path, body, ["model_id", "modelId"])
    is Some(model_id) else {
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
  write_usage_json(w, Json::null())
}

///|
async fn Gateway::handle_usage_request_detail(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let request_id = usage_request_detail_id_from_request(r.path, body)
  let pricing_overrides = self.pricing_override_rows()
  let backfilled = self.stats.backfill_missing_usage_costs(
    pricing_overrides,
    self.pricing_deleted_model_ids,
  )
  if backfilled > 0 {
    self.stats.save_persistent_store()
  }
  match
    self.stats.request_detail_json_with_pricing(
      request_id,
      pricing_overrides,
      self.pricing_deleted_model_ids,
    ) {
    Some(detail) => write_usage_json(w, detail)
    None => write_usage_json(w, Json::null())
  }
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
fn stream_check_config_from_request(
  path : StringView,
  body : String,
  current : StreamCheckConfig,
) -> StreamCheckConfig? {
  let mut config = current
  let parsed_body : Json? = if body.trim().is_empty() {
    None
  } else {
    let parsed = @json.parse(body) catch { _ => return None }
    Some(parsed)
  }
  let obj = match parsed_body {
    Some(Object(root)) =>
      match root.get("config") {
        Some(Object(config_obj)) => Some(config_obj)
        _ => Some(root)
      }
    Some(_) => return None
    None => None
  }
  match stream_check_int_request(path, obj, "timeout_secs", "timeoutSecs") {
    Some(value) if value > 0 => config = { ..config, timeout_secs: value }
    Some(_) => return None
    None => ()
  }
  match stream_check_int_request(path, obj, "max_retries", "maxRetries") {
    Some(value) if value >= 0 => config = { ..config, max_retries: value }
    Some(_) => return None
    None => ()
  }
  match
    stream_check_int_request(
      path, obj, "degraded_threshold_ms", "degradedThresholdMs",
    ) {
    Some(value) if value > 0 =>
      config = { ..config, degraded_threshold_ms: value }
    Some(_) => return None
    None => ()
  }
  match stream_check_string_request(path, obj, "claude_model", "claudeModel") {
    Some(value) if !value.trim().is_empty() =>
      config = { ..config, claude_model: value.trim().to_owned() }
    Some(_) => return None
    None => ()
  }
  match stream_check_string_request(path, obj, "codex_model", "codexModel") {
    Some(value) if !value.trim().is_empty() =>
      config = { ..config, codex_model: value.trim().to_owned() }
    Some(_) => return None
    None => ()
  }
  match stream_check_string_request(path, obj, "gemini_model", "geminiModel") {
    Some(value) if !value.trim().is_empty() =>
      config = { ..config, gemini_model: value.trim().to_owned() }
    Some(_) => return None
    None => ()
  }
  match stream_check_string_request(path, obj, "test_prompt", "testPrompt") {
    Some(value) if !value.trim().is_empty() =>
      config = { ..config, test_prompt: value.trim().to_owned() }
    Some(_) => return None
    None => ()
  }
  Some(config)
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
async fn Gateway::handle_stream_check_provider(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard stream_check_provider_query(r.path) is Some((app_type, provider_id)) else {
    write_usage_bad_request(w, "missing_provider_id_or_app_type")
    return
  }
  guard self.stream_check_provider_result_json(app_type, provider_id)
    is Some(result) else {
    write_usage_bad_request(w, "provider_not_found")
    return
  }
  write_usage_json(w, result)
}

///|
async fn Gateway::handle_stream_check_all_providers(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard usage_query_value_any(r.path, "app_type", "appType") is Some(app_type) else {
    write_usage_bad_request(w, "missing_app_type")
    return
  }
  let proxy_targets_only = usage_query_bool_any(
    r.path,
    "proxy_targets_only",
    "proxyTargetsOnly",
  ).unwrap_or(false)
  let rows : Array[Json] = []
  for
    provider_id in self.provider_router.stream_check_provider_ids(
      app_type, proxy_targets_only,
    ) {
    guard self.stream_check_provider_result_json(app_type, provider_id)
      is Some(result) else {
      continue
    }
    rows.push(Json::array([Json::string(provider_id), result]))
  }
  write_usage_json(w, Json::array(rows))
}

///|
fn Gateway::stream_check_provider_result_json(
  self : Gateway,
  app_type : String,
  provider_id : String,
) -> Json? {
  guard self.provider_router.provider_by_id(app_type, provider_id)
    is Some(provider) else {
    return None
  }
  ignore(provider)
  let model = stream_check_reported_model_for_app(
    self.stream_check_config,
    app_type,
  )
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
fn stream_check_provider_query(path : StringView) -> (String, String)? {
  let app_type = match usage_query_value_any(path, "app_type", "appType") {
    Some(value) => Some(value)
    None => usage_query_value(path, "app")
  }
  guard app_type is Some(app_type) else { return None }
  let provider_id = match
    usage_query_value_any(path, "provider_id", "providerId") {
    Some(value) => Some(value)
    None => usage_query_value(path, "id")
  }
  guard provider_id is Some(provider_id) else { return None }
  Some((app_type, provider_id))
}

///|
async fn Gateway::handle_get_stream_check_config(
  self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, self.stream_check_config.to_json())
}

///|
async fn Gateway::handle_save_stream_check_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = r.body.read_all().text()
  match
    stream_check_config_from_request(r.path, body, self.stream_check_config) {
    Some(config) => {
      self.stream_check_config = config
      write_usage_json(w, Json::null())
    }
    None => write_usage_bad_request(w, "invalid_stream_check_config")
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
fn ccs_unit_success_json() -> Json {
  Json::null()
}

///|
fn ccs_update_tray_menu_result() -> Json {
  Json::boolean(false)
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
  match usage_query_value_any(path, "request_id", "requestId") {
    Some(request_id) => return request_id
    None => ()
  }
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
fn usage_request_detail_id_from_request(
  path : StringView,
  body : Json?,
) -> String {
  match usage_string_from_request(path, body, ["request_id", "requestId"]) {
    Some(request_id) => request_id
    None => usage_request_detail_id(path.to_owned())
  }
}

///|
priv struct ProxyProviderQuery {
  provider_id : String
  app_type : String
}

///|
fn proxy_provider_query(path : StringView) -> ProxyProviderQuery? {
  guard usage_query_value_any(path, "provider_id", "providerId")
    is Some(provider_id) else {
    return None
  }
  guard usage_query_value_any(path, "app_type", "appType") is Some(app_type) else {
    return None
  }
  Some({ provider_id, app_type })
}

///|
fn proxy_circuit_config_from_query(path : StringView) -> CircuitBreakerConfig? {
  guard usage_query_int_any(path, "failure_threshold", "failureThreshold")
    is Some(failure_threshold) else {
    return None
  }
  guard usage_query_int_any(path, "success_threshold", "successThreshold")
    is Some(success_threshold) else {
    return None
  }
  guard usage_query_int_any(path, "timeout_seconds", "timeoutSeconds")
    is Some(timeout_seconds) else {
    return None
  }
  guard usage_query_double_any(
      path, "error_rate_threshold", "errorRateThreshold",
    )
    is Some(error_rate_threshold) else {
    return None
  }
  guard usage_query_int_any(path, "min_requests", "minRequests")
    is Some(min_requests) else {
    return None
  }
  let config = {
    failure_threshold,
    success_threshold,
    timeout_seconds,
    error_rate_threshold,
    min_requests,
  }
  if circuit_breaker_config_is_valid(config) {
    Some(config)
  } else {
    None
  }
}

///|
async fn proxy_json_body(r : @httpx.RequestReader) -> Json? {
  let body = r.body.read_all().text()
  if body.trim().is_empty() {
    return None
  }
  Some(@json.parse(body) catch { _ => return None })
}

///|
fn proxy_embedded_config(body : Json?) -> Json? {
  match body {
    Some(Object(obj)) =>
      match obj.get("config") {
        Some(Object(config)) => Some(Json::object(config))
        _ => body
      }
    _ => body
  }
}

///|
fn provider_app_from_request(path : StringView, body : Json?) -> String? {
  provider_string_from_request(path, body, ["app", "app_type", "appType"])
}

///|
fn provider_id_from_request(path : StringView, body : Json?) -> String? {
  provider_string_from_request(path, body, ["id", "provider_id", "providerId"])
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
  match proxy_string_request(path, body, keys) {
    Some(value) => return Some(value)
    None => ()
  }
  match provider_body_payload(body) {
    Some(payload) => proxy_string_request(path, Some(payload), keys)
    None => None
  }
}

///|
fn provider_bool_from_request(
  path : StringView,
  body : Json?,
  keys : Array[String],
) -> Bool? {
  match proxy_bool_request(path, body, keys) {
    Some(value) => return Some(value)
    None => ()
  }
  match provider_body_payload(body) {
    Some(payload) => proxy_bool_request(path, Some(payload), keys)
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
    None =>
      match obj.get("settings_config") {
        Some(settings) =>
          Some(provider_settings_config_with_inline_metadata(settings, obj))
        None => provider_inline_settings_config(obj)
      }
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
fn provider_settings_base_url(app_type : String, settings : Json?) -> String? {
  guard settings is Some(Object(obj)) else { return None }
  match app_type {
    "codex" =>
      match json_string_from_map_any(obj, ["config"]) {
        Some(config) => codex_toml_string_value(config, "base_url")
        None => None
      }
    "gemini" =>
      match obj.get("env") {
        Some(Object(env)) =>
          json_non_empty_string_from_map_any(env, ["GOOGLE_GEMINI_BASE_URL"])
        _ => None
      }
    "hermes" => json_non_empty_string_from_map_any(obj, ["base_url"])
    "opencode" | "omo" | "omo-slim" =>
      match obj.get("options") {
        Some(Object(options)) =>
          json_non_empty_string_from_map_any(options, ["baseURL"])
        _ => None
      }
    "openclaw" => json_non_empty_string_from_map_any(obj, ["baseUrl"])
    "claude" | "claude-desktop" =>
      match obj.get("env") {
        Some(Object(env)) =>
          json_non_empty_string_from_map_any(env, ["ANTHROPIC_BASE_URL"])
        _ => None
      }
    _ => None
  }
}

///|
fn provider_settings_api_key(app_type : String, settings : Json?) -> String? {
  guard settings is Some(Object(obj)) else { return None }
  match app_type {
    "codex" =>
      match obj.get("auth") {
        Some(Object(auth)) =>
          json_non_empty_string_from_map_any(auth, ["OPENAI_API_KEY"])
        _ => None
      }
    "gemini" =>
      match obj.get("env") {
        Some(Object(env)) =>
          json_non_empty_string_from_map_any(env, [
            "GEMINI_API_KEY", "GOOGLE_API_KEY",
          ])
        _ => None
      }
    "hermes" => json_non_empty_string_from_map_any(obj, ["api_key"])
    "opencode" | "omo" | "omo-slim" =>
      match obj.get("options") {
        Some(Object(options)) =>
          json_non_empty_string_from_map_any(options, ["apiKey"])
        _ => None
      }
    "openclaw" => json_non_empty_string_from_map_any(obj, ["apiKey"])
    "claude" | "claude-desktop" =>
      match obj.get("env") {
        Some(Object(env)) =>
          json_non_empty_string_from_map_any(env, [
            "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_API_KEY", "OPENROUTER_API_KEY", "GEMINI_API_KEY",
            "GOOGLE_API_KEY",
          ])
        _ => None
      }
    _ => None
  }
}

///|
fn provider_settings_api_format(settings : Json?) -> String? {
  guard settings is Some(Object(obj)) else { return None }
  match obj.get("meta") {
    Some(Object(meta)) =>
      match
        json_non_empty_string_from_map_any(meta, ["apiFormat", "api_format"]) {
        Some(api_format) => return Some(api_format)
        None => ()
      }
    _ => ()
  }
  match json_non_empty_string_from_map_any(obj, ["api_format", "apiFormat"]) {
    Some(api_format) => Some(api_format)
    None =>
      if provider_settings_openrouter_compat_enabled(obj) {
        Some("openai_chat")
      } else {
        None
      }
  }
}

///|
fn provider_settings_openrouter_compat_enabled(obj : Map[String, Json]) -> Bool {
  match obj.get("openrouter_compat_mode") {
    Some(true) => true
    Some(false) => false
    Some(Number(value, ..)) => value != 0
    Some(String(value)) =>
      match parse_bool_value(value) {
        Some(parsed) => parsed
        None => false
      }
    None => false
    _ => false
  }
}

///|
fn provider_explicit_type_from_request(
  path : StringView,
  body : Json?,
  settings : Json?,
) -> String? {
  match
    provider_string_from_request(path, body, [
      "category", "provider_type", "providerType",
    ]) {
    Some(value) if !value.trim().is_empty() => return Some(value)
    _ => ()
  }
  guard settings is Some(Object(obj)) else { return None }
  match obj.get("meta") {
    Some(Object(meta)) => {
      match
        json_non_empty_string_from_map_any(meta, [
          "providerType", "provider_type",
        ]) {
        Some(value) => return Some(provider_type_normalize(value))
        None => ()
      }
      match meta.get("authBinding") {
        Some(Object(binding)) =>
          match
            json_non_empty_string_from_map_any(binding, [
              "authProvider", "auth_provider",
            ]) {
            Some(value) => return Some(provider_type_normalize(value))
            None => ()
          }
        _ => ()
      }
    }
    _ => ()
  }
  None
}

///|
fn provider_type_normalize(value : String) -> String {
  value.trim().to_owned().to_lower().replace_all(old="-", new="_")
}

///|
fn provider_resolved_provider_type(
  app_type : String,
  explicit_type : String?,
  settings : Json?,
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
      if provider_settings_bearer_only(settings) {
        return Some("claude_auth")
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
fn provider_settings_bearer_only(settings : Json?) -> Bool {
  guard settings is Some(Object(obj)) else { return false }
  match json_non_empty_string_from_map_any(obj, ["auth_mode", "authMode"]) {
    Some(mode) if mode == "bearer_only" => return true
    _ => ()
  }
  match obj.get("env") {
    Some(Object(env)) =>
      match json_non_empty_string_from_map_any(env, ["AUTH_MODE"]) {
        Some(mode) => mode == "bearer_only"
        None => false
      }
    _ => false
  }
}

///|
fn provider_settings_prompt_cache_key(settings : Json?) -> String? {
  guard settings is Some(Object(obj)) else { return None }
  match
    json_non_empty_string_from_map_any(obj, [
      "promptCacheKey", "prompt_cache_key",
    ]) {
    Some(value) => return Some(value)
    None => ()
  }
  match obj.get("meta") {
    Some(Object(meta)) =>
      json_non_empty_string_from_map_any(meta, [
        "promptCacheKey", "prompt_cache_key",
      ])
    _ => None
  }
}

///|
fn provider_settings_codex_fast_mode(settings : Json?) -> Bool? {
  guard settings is Some(Object(obj)) else { return None }
  match json_bool_from_map_any(obj, ["codexFastMode", "codex_fast_mode"]) {
    Some(value) => return Some(value)
    None => ()
  }
  match obj.get("meta") {
    Some(Object(meta)) =>
      json_bool_from_map_any(meta, ["codexFastMode", "codex_fast_mode"])
    _ => None
  }
}

///|
fn Gateway::provider_limit_config_for_provider(
  self : Gateway,
  provider_id : String,
  app_type : String,
) -> ProviderLimitConfig? {
  guard self.provider_router.provider_by_id(app_type, provider_id)
    is Some(provider) else {
    return None
  }
  provider_limit_config_from_settings(provider.settings_config)
}

///|
fn Gateway::sync_provider_limits_from_target(
  self : Gateway,
  target : ProviderRouteTarget,
) -> Unit {
  guard provider_limit_config_from_settings(target.settings_config)
    is Some(config) else {
    return
  }
  self.stats.set_provider_limits(
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
  let daily = provider_limit_string_from_settings(obj, [
    "limitDailyUsd", "limit_daily_usd",
  ])
  let monthly = provider_limit_string_from_settings(obj, [
    "limitMonthlyUsd", "limit_monthly_usd",
  ])
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
  match json_non_empty_string_from_map_any(obj, keys) {
    Some(value) => return Some(value)
    None => ()
  }
  match obj.get("meta") {
    Some(Object(meta)) => json_non_empty_string_from_map_any(meta, keys)
    _ => None
  }
}

///|
fn usage_limit_override_or_provider_limit(
  explicit_limit : String?,
  provider_limit : String??,
) -> String? {
  match explicit_limit {
    Some(value) => Some(value)
    None =>
      match provider_limit {
        Some(Some(value)) => Some(value)
        _ => None
      }
  }
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
fn provider_prefer_non_empty(primary : String?, fallback : String?) -> String? {
  match primary {
    Some(value) if !value.trim().is_empty() => Some(value)
    _ =>
      match fallback {
        Some(value) if !value.trim().is_empty() => Some(value)
        _ => None
      }
  }
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
      "customUserAgent", "custom_user_agent", "userAgent", "user_agent", "apiFormat",
      "api_format", "promptCacheKey", "prompt_cache_key", "codexFastMode", "codex_fast_mode",
      "githubAccountId", "github_account_id", "limitDailyUsd", "limit_daily_usd",
      "limitMonthlyUsd", "limit_monthly_usd",
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
fn suite_write_outcome_json() -> Json {
  let empty : Map[String, Json] = {}
  Json::object(empty)
}

///|
fn openclaw_default_tools_json() -> Json {
  { "allow": Json::array([]), "deny": Json::array([]) }.to_json()
}

///|
fn Gateway::openclaw_config_health_json(self : Gateway) -> Json {
  let defaults = self.openclaw_agents_defaults.unwrap_or(Json::object({}))
  let config = {
    "tools": self.openclaw_tools,
    "agents": { "defaults": defaults }.to_json(),
    "env": self.openclaw_env,
  }.to_json()
  openclaw_config_health_from_json(config)
}

///|
fn openclaw_config_health_from_json(config : Json) -> Json {
  let warnings : Array[Json] = []
  match openclaw_nested_json(config, ["tools", "profile"]) {
    Some(String(profile)) =>
      if !openclaw_tools_profile_is_supported(profile) {
        warnings.push(
          openclaw_health_warning_json(
            "invalid_tools_profile",
            "tools.profile uses unsupported value '\{profile}'.",
            Some("tools.profile"),
          ),
        )
      }
    _ => ()
  }
  match openclaw_nested_json(config, ["agents", "defaults", "timeout"]) {
    Some(_) =>
      warnings.push(
        openclaw_health_warning_json(
          "legacy_agents_timeout",
          "agents.defaults.timeout is deprecated; use agents.defaults.timeoutSeconds.",
          Some("agents.defaults.timeout"),
        ),
      )
    None => ()
  }
  match openclaw_nested_json(config, ["env", "vars"]) {
    Some(Object(_)) | None => ()
    Some(_) =>
      warnings.push(
        openclaw_health_warning_json(
          "stringified_env_vars",
          "env.vars should be an object. The current value looks stringified or malformed.",
          Some("env.vars"),
        ),
      )
  }
  match openclaw_nested_json(config, ["env", "shellEnv"]) {
    Some(Object(_)) | None => ()
    Some(_) =>
      warnings.push(
        openclaw_health_warning_json(
          "stringified_env_shell_env",
          "env.shellEnv should be an object. The current value looks stringified or malformed.",
          Some("env.shellEnv"),
        ),
      )
  }
  Json::array(warnings)
}

///|
fn openclaw_tools_profile_is_supported(profile : String) -> Bool {
  profile == "minimal" ||
  profile == "coding" ||
  profile == "messaging" ||
  profile == "full"
}

///|
fn openclaw_health_warning_json(
  code : String,
  message : String,
  path : String?,
) -> Json {
  let warning : Map[String, Json] = {
    "code": Json::string(code),
    "message": Json::string(message),
  }
  match path {
    Some(path) => warning["path"] = Json::string(path)
    None => ()
  }
  Json::object(warning)
}

///|
fn openclaw_nested_json(config : Json, keys : Array[String]) -> Json? {
  let mut current = config
  for key in keys {
    match current {
      Object(obj) =>
        match obj.get(key) {
          Some(value) => current = value
          None => return None
        }
      _ => return None
    }
  }
  Some(current)
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
fn openclaw_default_model_from_request(
  path : StringView,
  body : Json?,
) -> Json? {
  match suite_object_payload(body, "model") {
    Some(model) => return Some(model)
    None => ()
  }
  guard proxy_string_request(path, body, ["primary"]) is Some(primary) &&
    !primary.trim().is_empty() else {
    return None
  }
  Some(
    {
      "primary": Json::string(primary.trim().to_owned()),
      "fallbacks": split_csv_json(
        proxy_string_request(path, body, ["fallbacks"]).unwrap_or(""),
      ),
    }.to_json(),
  )
}

///|
fn openclaw_env_from_request(path : StringView, body : Json?) -> Json? {
  match suite_object_request(path, body, "env") {
    Some(env) => return Some(env)
    None => ()
  }
  guard proxy_string_request(path, body, ["key", "name"]) is Some(key) &&
    !key.trim().is_empty() else {
    return None
  }
  let value = proxy_string_request(path, body, ["value"]).unwrap_or("")
  let env : Map[String, Json] = {}
  env[key.trim().to_owned()] = Json::string(value)
  Some(Json::object(env))
}

///|
fn openclaw_tools_from_request(path : StringView, body : Json?) -> Json? {
  match suite_object_request(path, body, "tools") {
    Some(tools) => return Some(tools)
    None => ()
  }
  let tools : Map[String, Json] = {
    "allow": split_csv_json(
      proxy_string_request(path, body, ["allow"]).unwrap_or(""),
    ),
    "deny": split_csv_json(
      proxy_string_request(path, body, ["deny"]).unwrap_or(""),
    ),
  }
  match proxy_string_request(path, body, ["profile"]) {
    Some(profile) if !profile.trim().is_empty() =>
      tools["profile"] = Json::string(profile.trim().to_owned())
    _ => ()
  }
  Some(Json::object(tools))
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
fn hermes_memory_kind_from_request(path : StringView, body : Json?) -> String? {
  match
    proxy_string_request(path, body, ["kind", "memoryKind", "memory_kind"]) {
    Some(raw) =>
      match raw.trim().to_lower() {
        "memory" => Some("memory")
        "user" => Some("user")
        _ => None
      }
    None => None
  }
}

///|
fn hermes_memory_limits_json(enabled : Map[String, Bool]) -> Json {
  {
    "memory": Json::number(2200.0),
    "user": Json::number(1375.0),
    "memoryEnabled": Json::boolean(enabled.get("memory").unwrap_or(true)),
    "userEnabled": Json::boolean(enabled.get("user").unwrap_or(true)),
  }.to_json()
}

///|
fn hermes_web_port_from_request(path : StringView) -> Int {
  match usage_query_int(path, "port") {
    Some(port) if port > 0 && port <= 65535 => return port
    _ => ()
  }
  let env_port = @os.getenv("HERMES_WEB_PORT") catch { _ => None }
  match env_port {
    Some(raw) => {
      let port = @string.parse_int(raw.trim().to_owned(), base=10) catch {
        _ => -1
      }
      if port > 0 && port <= 65535 {
        port
      } else {
        9119
      }
    }
    None => 9119
  }
}

///|
fn hermes_web_ui_path(path : String) -> String {
  if path.is_empty() {
    "/"
  } else if path.has_prefix("/") {
    path
  } else {
    "/\{path}"
  }
}

///|
fn hermes_web_ui_target_url(port : Int, path : String) -> String {
  "http://127.0.0.1:\{port}\{hermes_web_ui_path(path)}"
}

///|
fn hermes_web_ui_probe_url(port : Int) -> String {
  "http://127.0.0.1:\{port}/api/status"
}

///|
const HERMES_DASHBOARD_COMMAND = "hermes dashboard"

///|
const HERMES_DASHBOARD_LOG_PATH = "/tmp/moonstat_hermes_dashboard.log"

///|
fn hermes_dashboard_background_shell_command() -> String {
  "nohup \{HERMES_DASHBOARD_COMMAND} >\{HERMES_DASHBOARD_LOG_PATH} 2>&1 &"
}

///|
async fn launch_hermes_dashboard_standalone() -> Result[Json, String] {
  let result = @spawn.spawn(
    "sh",
    ["-lc", hermes_dashboard_background_shell_command()],
    timeout=2000,
  ) catch {
    _ => return Err("hermes_dashboard_launch_failed")
  }
  if result.status != 0 {
    return Err("hermes_dashboard_launch_failed")
  }
  Ok(Json::null())
}

///|
async fn hermes_web_ui_is_live(port : Int) -> Bool {
  if !@net.localhost_port_open(port, timeout_ms=1200) {
    return false
  }
  let result = try? @http.get(hermes_web_ui_probe_url(port))
  match result {
    Ok(_) => true
    Err(_) => false
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
      provider_string_from_request(path, body, ["providerType", "provider_type"]).unwrap_or(
        "custom",
      ),
    ),
    "apps": universal_provider_apps_from_request(path, body),
    "models": universal_provider_models_from_request(path, body),
  }
  match provider_string_from_request(path, body, ["baseUrl", "base_url"]) {
    Some(value) => provider["baseUrl"] = Json::string(value)
    None => ()
  }
  match provider_string_from_request(path, body, ["apiKey", "api_key"]) {
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
  let apps_value = provider_string_from_request(path, body, [
    "apps", "app", "appType", "app_type",
  ]).unwrap_or("claude,codex,gemini")
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
  match
    provider_string_from_request(path, body, ["claudeModel", "claude_model"]) {
    Some(model) => models["claude"] = { "model": Json::string(model) }.to_json()
    None => ()
  }
  let codex : Map[String, Json] = {}
  match
    provider_string_from_request(path, body, ["codexModel", "codex_model"]) {
    Some(model) => codex["model"] = Json::string(model)
    None => ()
  }
  match
    provider_string_from_request(path, body, [
      "reasoningEffort", "reasoning_effort",
    ]) {
    Some(value) => codex["reasoningEffort"] = Json::string(value)
    None => ()
  }
  if !codex.is_empty() {
    models["codex"] = Json::object(codex)
  }
  match
    provider_string_from_request(path, body, ["geminiModel", "gemini_model"]) {
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
  let provider_name = provider_string_from_request(path, body, [
    "name", "provider_name", "providerName",
  ]).unwrap_or(provider_id)
  let enabled = provider_bool_from_request(path, body, ["enabled"]).unwrap_or(
    true,
  )
  let settings_config = provider_settings_config_from_body(body)
  let explicit_provider_type = provider_explicit_type_from_request(
    path, body, settings_config,
  )
  let api_format = provider_prefer_non_empty(
    provider_string_from_request(path, body, ["api_format", "apiFormat"]),
    provider_settings_api_format(settings_config),
  )
  let base_url = provider_prefer_non_empty(
    provider_string_from_request(path, body, [
      "base_url", "baseUrl", "websiteUrl",
    ]),
    provider_settings_base_url(app_type, settings_config),
  )
  let api_key = provider_prefer_non_empty(
    provider_string_from_request(path, body, ["api_key", "apiKey"]),
    provider_settings_api_key(app_type, settings_config),
  )
  let provider_type = provider_resolved_provider_type(
    app_type, explicit_provider_type, settings_config, api_format, base_url, api_key,
  )
  let prompt_cache_key = provider_settings_prompt_cache_key(settings_config)
  let codex_fast_mode = provider_settings_codex_fast_mode(settings_config).unwrap_or(
    false,
  )
  let notes = provider_string_from_request(path, body, ["notes"])
  let is_full_url = provider_bool_from_request(path, body, [
    "is_full_url", "isFullUrl", "fullUrl",
  ]).unwrap_or(false)
  let model_mapping = provider_model_mapping_from_request(path, body)
  let claude_desktop_model_routes = provider_claude_desktop_model_routes_from_body(
    body,
  )
  Some(
    ProviderRouteTarget::new(
      app_type~,
      provider_id~,
      provider_name~,
      enabled~,
      provider_type~,
      api_format~,
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
fn provider_model_mapping_from_request(
  path : StringView,
  body : Json?,
) -> ModelMapping? {
  match provider_body_payload(body) {
    Some(Object(obj)) =>
      match obj.get("modelMapping") {
        Some(Object(mapping_obj)) =>
          return provider_model_mapping_from_json(mapping_obj)
        _ =>
          match obj.get("model_mapping") {
            Some(Object(mapping_obj)) =>
              return provider_model_mapping_from_json(mapping_obj)
            _ => ()
          }
      }
    _ => ()
  }
  let mapping = ModelMapping::new(
    haiku_model=provider_string_from_request(path, body, [
      "haikuModel", "haiku_model",
    ]),
    sonnet_model=provider_string_from_request(path, body, [
      "sonnetModel", "sonnet_model",
    ]),
    opus_model=provider_string_from_request(path, body, [
      "opusModel", "opus_model",
    ]),
    default_model=provider_string_from_request(path, body, [
      "defaultModel", "default_model",
    ]),
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
    haiku_model=json_string_from_map_any(obj, ["haikuModel", "haiku_model"]),
    sonnet_model=json_string_from_map_any(obj, ["sonnetModel", "sonnet_model"]),
    opus_model=json_string_from_map_any(obj, ["opusModel", "opus_model"]),
    default_model=json_string_from_map_any(obj, [
      "defaultModel", "default_model",
    ]),
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
    _ =>
      match obj.get("claude_desktop_model_routes") {
        Some(Object(routes)) => Some(routes)
        _ =>
          match obj.get("meta") {
            Some(Object(meta)) =>
              match meta.get("claudeDesktopModelRoutes") {
                Some(Object(routes)) => Some(routes)
                _ =>
                  match meta.get("claude_desktop_model_routes") {
                    Some(Object(routes)) => Some(routes)
                    _ => None
                  }
              }
            _ => None
          }
      }
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
          label_override=json_string_from_map_any(obj, [
            "labelOverride", "label_override",
          ]),
          supports_1m=json_bool_from_map_any(obj, ["supports1m", "supports_1m"]),
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
  let sort_index = proxy_int_request(path, body, ["sortIndex", "sort_index"]).unwrap_or(
    0,
  )
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
    guard json_string_from_map_any(obj, ["id", "providerId", "provider_id"])
      is Some(id) else {
      continue
    }
    let sort_index = match obj.get("sortIndex") {
      Some(Number(value, ..)) => value.trunc().to_int()
      Some(String(value)) =>
        try @string.parse_int(value, base=10) catch {
          _ => 0
        } noraise {
          parsed => parsed
        }
      _ =>
        match obj.get("sort_index") {
          Some(Number(value, ..)) => value.trunc().to_int()
          Some(String(value)) =>
            try @string.parse_int(value, base=10) catch {
              _ => 0
            } noraise {
              parsed => parsed
            }
          _ => 0
        }
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
fn split_endpoint_urls(value : String) -> Array[String] {
  let urls : Array[String] = []
  for raw in value.split(",") {
    urls.push(raw.to_owned())
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
      "error": Json::string(ccs_endpoint_invalid_url_error(trimmed)),
    }.to_json()
  }
  if ccs_endpoint_url_missing_host(trimmed) {
    return {
      "url": Json::string(trimmed),
      "latency": Json::null(),
      "status": Json::null(),
      "error": Json::string(ccs_endpoint_invalid_url_error(trimmed)),
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
fn ccs_endpoint_invalid_url_error(url : String) -> String {
  if url.has_prefix("http://") || url.has_prefix("https://") {
    if ccs_endpoint_url_missing_host(url) {
      "URL 无效: empty host"
    } else {
      "URL 无效"
    }
  } else {
    "URL 无效: relative URL without a base"
  }
}

///|
fn ccs_endpoint_url_missing_host(url : String) -> Bool {
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
fn proxy_bool_request(
  path : StringView,
  config : Json?,
  keys : Array[String],
) -> Bool? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) =>
        match parse_bool_value(value) {
          Some(parsed) => return Some(parsed)
          None => ()
        }
      None => ()
    }
  }
  match config {
    Some(Object(obj)) =>
      for key in keys {
        match proxy_json_bool(obj, key) {
          Some(parsed) => return Some(parsed)
          None => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn proxy_string_request(
  path : StringView,
  config : Json?,
  keys : Array[String],
) -> String? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  match config {
    Some(Object(obj)) =>
      for key in keys {
        match obj.get(key) {
          Some(String(value)) => return Some(value)
          _ => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn proxy_int_request(
  path : StringView,
  config : Json?,
  keys : Array[String],
) -> Int? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) =>
        try @string.parse_int(value, base=10) catch {
          _ => ()
        } noraise {
          parsed => return Some(parsed)
        }
      None => ()
    }
  }
  match config {
    Some(Object(obj)) =>
      for key in keys {
        match proxy_json_int(obj, key) {
          Some(parsed) => return Some(parsed)
          None => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn proxy_double_request(
  path : StringView,
  config : Json?,
  keys : Array[String],
) -> Double? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) =>
        match parse_non_negative_decimal_to_double(value) {
          Some(parsed) => return Some(parsed)
          None => ()
        }
      None => ()
    }
  }
  match config {
    Some(Object(obj)) =>
      for key in keys {
        match obj.get(key) {
          Some(Number(value, ..)) => return Some(value)
          Some(String(value)) =>
            match parse_non_negative_decimal_to_double(value) {
              Some(parsed) => return Some(parsed)
              None => ()
            }
          _ => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn proxy_json_bool(obj : Map[String, Json], key : String) -> Bool? {
  match obj.get(key) {
    Some(true) => Some(true)
    Some(false) => Some(false)
    Some(String(value)) => parse_bool_value(value)
    _ => None
  }
}

///|
fn proxy_json_int(obj : Map[String, Json], key : String) -> Int? {
  match obj.get(key) {
    Some(Number(value, ..)) => Some(value.trunc().to_int())
    Some(String(value)) =>
      try @string.parse_int(value, base=10) catch {
        _ => None
      } noraise {
        parsed => Some(parsed)
      }
    _ => None
  }
}

///|
fn proxy_circuit_config_from_request(
  path : StringView,
  config : Json?,
  current : CircuitBreakerConfig,
) -> CircuitBreakerConfig? {
  let failure_threshold = proxy_int_request(path, config, [
    "failure_threshold", "failureThreshold",
  ])
  let success_threshold = proxy_int_request(path, config, [
    "success_threshold", "successThreshold",
  ])
  let timeout_seconds = proxy_int_request(path, config, [
    "timeout_seconds", "timeoutSeconds",
  ])
  let error_rate_threshold = proxy_double_request(path, config, [
    "error_rate_threshold", "errorRateThreshold",
  ])
  let min_requests = proxy_int_request(path, config, [
    "min_requests", "minRequests",
  ])
  if failure_threshold is None &&
    success_threshold is None &&
    timeout_seconds is None &&
    error_rate_threshold is None &&
    min_requests is None {
    return None
  }
  let next = {
    failure_threshold: failure_threshold.unwrap_or(current.failure_threshold),
    success_threshold: success_threshold.unwrap_or(current.success_threshold),
    timeout_seconds: timeout_seconds.unwrap_or(current.timeout_seconds),
    error_rate_threshold: error_rate_threshold.unwrap_or(
      current.error_rate_threshold,
    ),
    min_requests: min_requests.unwrap_or(current.min_requests),
  }
  if circuit_breaker_config_is_valid(next) {
    Some(next)
  } else {
    None
  }
}

///|
async fn proxy_enabled_value(r : @httpx.RequestReader) -> Bool? {
  match usage_query_bool_any(r.path, "enabled", "enabled") {
    Some(enabled) => Some(enabled)
    None => {
      let body = r.body.read_all().text()
      if body.trim().is_empty() {
        return None
      }
      let parsed = @json.parse(body) catch { _ => return None }
      json_bool_field(parsed, "enabled")
    }
  }
}

///|
fn usage_request_log_filters_from_request(
  path : StringView,
  body : Json?,
) -> RequestLogFilters {
  let filter_body = usage_filter_body(body)
  RequestLogFilters::new(
    app_type=usage_string_from_request(path, filter_body, [
      "app_type", "appType",
    ]),
    provider_name=usage_string_from_request(path, filter_body, [
      "provider_name", "providerName",
    ]),
    model=usage_string_from_request(path, filter_body, ["model"]),
    status_code=usage_int_from_request(path, filter_body, [
      "status_code", "statusCode",
    ]),
    start_date=usage_int_from_request(path, filter_body, [
      "start_date", "startDate",
    ]),
    end_date=usage_int_from_request(path, filter_body, ["end_date", "endDate"]),
  )
}

///|
fn usage_filter_body(body : Json?) -> Json? {
  match body {
    Some(Object(obj)) =>
      match obj.get("filters") {
        Some(Object(filters)) => Some(Json::object(filters))
        _ => body
      }
    _ => body
  }
}

///|
fn usage_string_from_request(
  path : StringView,
  body : Json?,
  keys : Array[String],
) -> String? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  match body {
    Some(Object(obj)) =>
      for key in keys {
        match obj.get(key) {
          Some(String(value)) if !value.is_empty() => return Some(value)
          Some(Number(value, ..)) => return Some(value.to_string())
          _ => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn usage_int_from_request(
  path : StringView,
  body : Json?,
  keys : Array[String],
) -> Int? {
  for key in keys {
    match usage_query_value(path, key) {
      Some(value) =>
        try @string.parse_int(value, base=10) catch {
          _ => ()
        } noraise {
          parsed => return Some(parsed)
        }
      None => ()
    }
  }
  match body {
    Some(Object(obj)) =>
      for key in keys {
        match obj.get(key) {
          Some(Number(value, ..)) => return Some(value.trunc().to_int())
          Some(String(value)) =>
            try @string.parse_int(value, base=10) catch {
              _ => ()
            } noraise {
              parsed => return Some(parsed)
            }
          _ => ()
        }
      }
    _ => ()
  }
  None
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
fn usage_query_bool_any(
  path : StringView,
  left_key : String,
  right_key : String,
) -> Bool? {
  match usage_query_value_any(path, left_key, right_key) {
    Some(value) => parse_bool_value(value)
    None => None
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
fn usage_query_double_any(
  path : StringView,
  left_key : String,
  right_key : String,
) -> Double? {
  match usage_query_value_any(path, left_key, right_key) {
    Some(value) => parse_non_negative_decimal_to_double(value)
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
fn usage_pricing_from_request(path : StringView, body : Json?) -> ModelPricing? {
  guard usage_string_from_request(path, body, ["model_id", "modelId"])
    is Some(model_id) else {
    return None
  }
  guard usage_string_from_request(path, body, ["display_name", "displayName"])
    is Some(display_name) else {
    return None
  }
  guard usage_string_from_request(path, body, ["input_cost", "inputCost"])
    is Some(input_cost) else {
    return None
  }
  guard usage_string_from_request(path, body, ["output_cost", "outputCost"])
    is Some(output_cost) else {
    return None
  }
  guard usage_string_from_request(path, body, [
      "cache_read_cost", "cacheReadCost",
    ])
    is Some(cache_read_cost) else {
    return None
  }
  guard usage_string_from_request(path, body, [
      "cache_creation_cost", "cacheCreationCost",
    ])
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
fn usage_result_from_request(path : StringView, body : Json?) -> UsageResult? {
  for key in ["result", "usageResult", "scriptCode", "script_code"] {
    match usage_query_value(path, key) {
      Some(value) =>
        match usage_result_from_string(value) {
          Some(result) => return Some(result)
          None => ()
        }
      None => ()
    }
  }
  match body {
    Some(json) => {
      match usage_result_from_json(json) {
        Some(result) => return Some(result)
        None => ()
      }
      guard json is Object(obj) else { return None }
      for key in ["result", "usageResult"] {
        match obj.get(key) {
          Some(value) =>
            match usage_result_or_script_output_from_json(value) {
              Some(result) => return Some(result)
              None => ()
            }
          None => ()
        }
      }
      for key in ["scriptCode", "script_code"] {
        match obj.get(key) {
          Some(String(value)) =>
            match usage_result_from_string(value) {
              Some(result) => return Some(result)
              None => ()
            }
          Some(value) =>
            match usage_result_or_script_output_from_json(value) {
              Some(result) => return Some(result)
              None => ()
            }
          _ => ()
        }
      }
      None
    }
    None => None
  }
}

///|
async fn test_usage_script_template_result(
  path : StringView,
  body : Json?,
) -> UsageResult? {
  let template_type = proxy_string_request(path, body, [
    "templateType", "template_type",
  ]).unwrap_or("")
  match template_type {
    "github_copilot" =>
      match copilot_get_usage(copilot_account_id_request(path, body)) {
        Ok(usage) => Some(ccs_copilot_usage_result_from_json(usage))
        Err(error) => Some(UsageResult::new(false, error=Some(error)))
      }
    "balance" => {
      guard proxy_string_request(path, body, ["baseUrl", "base_url"])
        is Some(base_url) else {
        return Some(ccs_balance_error("Base URL is empty"))
      }
      let api_key = proxy_string_request(path, body, ["apiKey", "api_key"]).unwrap_or(
        "",
      )
      Some(ccs_get_balance(base_url, api_key))
    }
    "token_plan" => {
      let base_url = proxy_string_request(path, body, ["baseUrl", "base_url"]).unwrap_or(
        "",
      )
      let api_key = proxy_string_request(path, body, ["apiKey", "api_key"]).unwrap_or(
        "",
      )
      Some(
        ccs_token_plan_usage_result_from_quota(
          ccs_get_coding_plan_quota(base_url, api_key),
        ),
      )
    }
    "official_subscription" => {
      let app_type = proxy_string_request(path, body, [
        "app", "appType", "app_type", "tool",
      ]).unwrap_or("")
      Some(
        ccs_subscription_usage_result_from_quota(
          ccs_get_subscription_quota(app_type),
        ),
      )
    }
    _ => None
  }
}

///|
fn ccs_copilot_usage_result_from_json(usage : Json) -> UsageResult {
  guard usage is Object(obj) else {
    return UsageResult::new(
      false,
      error=Some("Failed to parse Copilot usage response"),
    )
  }
  guard obj.get("quota_snapshots") is Some(Object(quota_snapshots)) else {
    return UsageResult::new(
      false,
      error=Some("Failed to parse Copilot usage response"),
    )
  }
  guard quota_snapshots.get("premium_interactions") is Some(Object(premium)) else {
    return UsageResult::new(
      false,
      error=Some("Failed to parse Copilot usage response"),
    )
  }
  guard ccs_json_double_from_map(premium, "entitlement") is Some(total) else {
    return UsageResult::new(
      false,
      error=Some("Failed to parse Copilot usage response"),
    )
  }
  guard ccs_json_double_from_map(premium, "remaining") is Some(remaining) else {
    return UsageResult::new(
      false,
      error=Some("Failed to parse Copilot usage response"),
    )
  }
  UsageResult::new(
    true,
    data=Some([
      UsageData::new(
        plan_name=Some(json_string_from_map(obj, "copilot_plan").unwrap_or("")),
        remaining=Some(remaining),
        total=Some(total),
        used=Some(total - remaining),
        unit=Some("requests"),
        is_valid=Some(true),
        extra=Some(
          "Reset: \{json_string_from_map(obj, "quota_reset_date").unwrap_or("")}",
        ),
      ),
    ]),
  )
}

///|
fn ccs_subscription_usage_result_from_quota(
  quota : SubscriptionQuota,
) -> UsageResult {
  if !quota.success {
    return UsageResult::new(
      false,
      error=match quota.error {
        Some(error) => Some(error)
        None => quota.credential_message
      },
    )
  }
  let data : Array[UsageData] = []
  for tier in quota.tiers {
    guard tier is Object(obj) else { continue }
    let used = ccs_json_double_from_map(obj, "utilization").unwrap_or(0.0)
    data.push(
      UsageData::new(
        plan_name=json_string_from_map(obj, "name"),
        remaining=Some(100.0 - used),
        total=Some(100.0),
        used=Some(used),
        unit=Some("%"),
        is_valid=Some(true),
        extra=json_string_from_map(obj, "resetsAt"),
      ),
    )
  }
  UsageResult::new(true, data=if data.is_empty() { None } else { Some(data) })
}

///|
fn ccs_token_plan_usage_result_from_quota(
  quota : SubscriptionQuota,
) -> UsageResult {
  if !quota.success {
    return UsageResult::new(false, error=quota.error)
  }
  let data : Array[UsageData] = []
  let has_usd = match quota.tiers.get(0) {
    Some(tier) => ccs_token_plan_tier_has_usd(tier)
    None => false
  }
  let plan_label = ccs_token_plan_label(quota.credential_message)
  let mut first_tier = true
  for tier in quota.tiers {
    guard tier is Object(obj) else { continue }
    let used = ccs_json_double_from_map(obj, "utilization").unwrap_or(0.0)
    data.push(
      UsageData::new(
        plan_name=json_string_from_map(obj, "name"),
        remaining=Some(100.0 - used),
        total=Some(100.0),
        used=Some(used),
        unit=Some("%"),
        is_valid=Some(true),
        extra=ccs_token_plan_usage_extra(
          obj,
          has_usd~,
          first_tier~,
          plan_label~,
        ),
      ),
    )
    first_tier = false
  }
  UsageResult::new(true, data=if data.is_empty() { None } else { Some(data) })
}

///|
fn ccs_token_plan_tier_has_usd(tier : Json) -> Bool {
  guard tier is Object(obj) else { return false }
  obj.contains("usedValueUsd")
}

///|
fn ccs_token_plan_label(message : String?) -> String? {
  guard message is Some(value) else { return None }
  for part in value.split(" ") {
    let tier = part.trim()
    if !tier.is_empty() {
      return Some("ZenMux·\{tier.to_upper()}")
    }
  }
  None
}

///|
fn ccs_token_plan_usage_extra(
  tier : Map[String, Json],
  has_usd~ : Bool,
  first_tier~ : Bool,
  plan_label~ : String?,
) -> String? {
  if !has_usd {
    return json_string_from_map(tier, "resetsAt")
  }
  let extra : Map[String, Json] = {
    "resetsAt": match json_string_from_map(tier, "resetsAt") {
      Some(value) => Json::string(value)
      None => Json::null()
    },
  }
  match ccs_json_double_from_map(tier, "usedValueUsd") {
    Some(value) => extra["usedValueUsd"] = Json::number(value)
    None => ()
  }
  match ccs_json_double_from_map(tier, "maxValueUsd") {
    Some(value) => extra["maxValueUsd"] = Json::number(value)
    None => ()
  }
  if first_tier {
    match plan_label {
      Some(label) => extra["planLabel"] = Json::string(label)
      None => ()
    }
  }
  Some(Json::object(extra).stringify())
}

///|
fn usage_result_from_string(value : String) -> UsageResult? {
  let trimmed = value.trim().to_owned()
  if trimmed.is_empty() {
    return None
  }
  let parsed = @json.parse(trimmed) catch { _ => return None }
  usage_result_or_script_output_from_json(parsed)
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
async fn Gateway::handle_fetch_models_for_config(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, ["baseUrl", "base_url"])
    is Some(base_url) else {
    write_usage_bad_request(w, "missing_base_url")
    return
  }
  guard proxy_string_request(r.path, body, ["apiKey", "api_key"])
    is Some(api_key) else {
    write_usage_bad_request(w, "missing_api_key")
    return
  }
  let is_full_url = proxy_bool_request(r.path, body, [
    "isFullUrl", "is_full_url", "fullUrl", "full_url",
  ]).unwrap_or(false)
  let models_url = proxy_string_request(r.path, body, [
    "modelsUrl", "models_url",
  ])
  let user_agent = proxy_string_request(r.path, body, [
    "customUserAgent", "custom_user_agent", "userAgent", "user_agent",
  ])
  match fetch_models(base_url, api_key, is_full_url, models_url, user_agent) {
    Ok(models) => write_usage_json(w, fetched_models_to_json(models))
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn Gateway::handle_models(
  _self : Gateway,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(
    ccs_models_endpoint_response_json(@codex_config.active_model_catalog_json()).stringify(),
  )
  w.flush()
}

///|
async fn Gateway::handle_claude_desktop_models(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.validate_claude_desktop_gateway_auth(r, w) else { return }
  let provider = self.activate_provider("claude-desktop")
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  w.write(claude_desktop_model_list_json(provider~).stringify())
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
  routes : Array[(String, String, Bool)],
) -> Json {
  let data = routes.map(fn(route) {
    let (route_id, _, supports_1m) = route
    claude_desktop_model_json(route_id, supports_1m~)
  })
  let first_id = match routes.get(0) {
    Some((route_id, _, _)) => Json::string(route_id)
    None => Json::null()
  }
  let last_id = if routes.is_empty() {
    Json::null()
  } else {
    match routes.get(routes.length() - 1) {
      Some((route_id, _, _)) => Json::string(route_id)
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
fn claude_desktop_model_json(id : String, supports_1m? : Bool = true) -> Json {
  let obj : Map[String, Json] = {
    "type": Json::string("model"),
    "id": Json::string(id),
    "created_at": Json::string("2024-01-01T00:00:00Z"),
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
) -> Array[(String, String, Bool)] {
  let routes : Array[(String, String, Bool)] = []
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
    let resolved_route_id = if is_claude_safe_model_id(trimmed_route_id) {
      trimmed_route_id
    } else {
      next_claude_desktop_catalog_safe_route_id(routes, reserved_route_ids)
    }
    routes.push(
      (resolved_route_id, upstream_model, route.supports_1m.unwrap_or(false)),
    )
  }
  routes.sort_by(fn(left, right) {
    let (left_route_id, _, _) = left
    let (right_route_id, _, _) = right
    left_route_id.compare(right_route_id)
  })
  let deduped : Array[(String, String, Bool)] = []
  for route in routes {
    let (route_id, _, _) = route
    match deduped.last() {
      Some((previous_route_id, _, _)) if previous_route_id == route_id => ()
      _ => deduped.push(route)
    }
  }
  deduped
}

///|
fn next_claude_desktop_catalog_safe_route_id(
  existing : Array[(String, String, Bool)],
  reserved : Array[String],
) -> String {
  for route_id in claude_desktop_default_proxy_route_ids() {
    if !reserved.contains(route_id) &&
      !existing.any(fn(route) {
        let (existing_route_id, _, _) = route
        existing_route_id == route_id
      }) {
      return route_id
    }
  }
  for index in 2..<10000 {
    let route_id = "claude-sonnet-4-6-r\{index}"
    if !reserved.contains(route_id) &&
      !existing.any(fn(route) {
        let (existing_route_id, _, _) = route
        existing_route_id == route_id
      }) {
      return route_id
    }
  }
  "claude-sonnet-4-6-r10000"
}

///|
fn claude_desktop_default_proxy_route_ids() -> Array[String] {
  ["claude-sonnet-4-6", "claude-opus-4-8", "claude-haiku-4-5"]
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
    let (route_id, upstream_model, _) = route
    if route_id == requested {
      return Some(upstream_model)
    }
  }
  for route in routes {
    let (route_id, upstream_model, _) = route
    if claude_desktop_opus_route_alias_matches(route_id, requested) {
      return Some(upstream_model)
    }
  }
  match self.claude_desktop_legacy_raw_route_upstream_model(requested) {
    Some(upstream) => return Some(upstream)
    None => ()
  }
  guard is_claude_safe_model_id(requested) else { return None }
  guard claude_role_keyword(requested) is Some(role) else { return None }
  for route in routes {
    let (route_id, upstream_model, _) = route
    if claude_role_keyword(route_id) == Some(role) {
      return Some(upstream_model)
    }
  }
  None
}

///|
fn ProviderRouteTarget::claude_desktop_legacy_raw_route_upstream_model(
  self : ProviderRouteTarget,
  requested : String,
) -> String? {
  for route_id in self.claude_desktop_model_routes.keys() {
    if route_id.trim() != requested {
      continue
    }
    match self.claude_desktop_model_routes.get(route_id) {
      Some(route) => {
        let upstream = route.model.trim().to_owned()
        if !upstream.is_empty() {
          return Some(upstream)
        }
      }
      None => ()
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
  self.stats.record_request_context(app_type, self.model)
  if active_provider is None && self.all_provider_circuits_open(app_type) {
    self.write_provider_selection_error(app_type, AllProvidersCircuitOpen, w)
    return
  }
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
      let anthropic_beta = r.headers.get("anthropic-beta")
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
            app_type~,
          )
          self.logger.debug("Using Codex model: \{model}")
          let stream = anthropic_request.stream.unwrap_or(false)
          self.stats.record_stream_mode(stream)
          self.stats.record_request_context(
            app_type,
            anthropic_request.model,
            outbound_model=Some(model),
            session_id~,
          )
          if stream {
            self.handle_streaming_request(
              anthropic_request,
              json,
              model,
              r.path.to_owned(),
              active_provider,
              app_type,
              self.selected_provider_chain(app_type),
              [],
              anthropic_beta,
              session_id,
              w,
            )
          } else {
            self.handle_non_streaming_request(
              anthropic_request,
              json,
              model,
              r.path.to_owned(),
              active_provider,
              app_type,
              self.selected_provider_chain(app_type),
              [],
              anthropic_beta,
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
  request_path : String,
  provider : ProviderRouteTarget,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
  anthropic_beta : String?,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.stats.record_request_context(
    app_type,
    request.model,
    outbound_model=Some(upstream_model),
    session_id~,
  )
  let api_format = provider.claude_api_format_for_model(upstream_model)
  let upstream_body = prepare_upstream_request_body(
    claude_request_json_for_upstream(request_json, upstream_model),
    provider=Some(provider),
  )
  let endpoint = claude_transform_endpoint(
    api_format,
    false,
    request_path=request_path[:],
  ).replace_all(old="__MODEL__", new=normalize_gemini_model_id(upstream_model))
  self.logger.debug(
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
    provider, upstream_body, api_format, session_id,
  )
  match
    self.post_claude_compatible_provider_json(
      provider, endpoint, outbound, api_format, anthropic_beta,
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
            self.upstream_claude_model(request.model, Some(provider), app_type~),
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
              provider, endpoint, retry_outbound, api_format, anthropic_beta,
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
                provider, endpoint, retry_outbound, api_format, anthropic_beta,
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
        let usage = token_usage_or_response_model(
          token_usage_from_claude_compatible_response(parsed, api_format),
          parsed,
          ["model", "modelVersion"],
        )
        if api_format == "openai_responses" {
          ignore(self.codex_chat_history.record_response(parsed))
        }
        self.record_success_usage(usage, final_response_body.length())
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
              self.upstream_claude_model(
                request.model,
                Some(provider),
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
async fn Gateway::handle_non_streaming_request(
  self : Gateway,
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
        request, request_json, model, request_path, provider, app_type, providers,
        attempted_provider_ids, anthropic_beta, session_id, w,
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
            request, request_json, model, request_path, active_provider, app_type,
            providers, attempted_provider_ids, anthropic_beta, session_id, w,
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
      let usage = token_usage_or_response_model(
        token_usage_from_codex_response_auto(json),
        json,
        ["model"],
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
  request_path : String,
  provider : ProviderRouteTarget,
  app_type : String,
  providers : Array[ProviderRouteTarget],
  attempted_provider_ids : Array[String],
  anthropic_beta : String?,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.stats.record_request_context(
    app_type,
    request.model,
    outbound_model=Some(upstream_model),
    session_id~,
  )
  let api_format = provider.claude_api_format_for_model(upstream_model)
  let upstream_body = prepare_upstream_request_body(
    claude_stream_request_json_for_upstream(request_json, upstream_model),
    provider=Some(provider),
  )
  let endpoint = claude_transform_endpoint(
    api_format,
    true,
    request_path=request_path[:],
  ).replace_all(old="__MODEL__", new=normalize_gemini_model_id(upstream_model))
  self.logger.debug(
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
            anthropic_beta~,
            accept="text/event-stream",
            custom_user_agent~,
            provider_type=provider.provider_type,
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
              self.upstream_claude_model(
                request.model,
                Some(provider),
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
            anthropic_beta~,
            accept="text/event-stream",
            custom_user_agent~,
            provider_type=provider.provider_type,
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
              self.upstream_claude_model(
                request.model,
                Some(provider),
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
          self.upstream_claude_model(request.model, Some(provider), app_type~),
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
    let first_token_ms = self.forward_openai_chat_sse_as_anthropic(
      client, stream_events, w,
    )
    self.record_success_stream_usage(
      token_usage_from_openai_stream_events(stream_events),
      0,
      record_provider=false,
      first_token_ms~,
      skip_empty_usage=true,
    )
  } else if api_format == "gemini_native" {
    let first_token_ms = self.forward_gemini_native_sse_as_anthropic(
      client, stream_events, provider_id, session_id, w,
    )
    self.record_success_stream_usage(
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
      first_token_ms = ccs_first_stream_event_ms(
        first_token_ms,
        self.stats.current_request_started_at_ms,
      )
      w.write("event: \{event.event_type}\n")
      w.write("data: \{event.data}\n\n")
      w.flush()
    }
    ignore(self.codex_chat_history.record_stream_events(reader.events))
    self.record_success_stream_usage(
      token_usage_from_codex_stream_events_auto(reader.events),
      0,
      record_provider=false,
      first_token_ms~,
      skip_empty_usage=true,
    )
  } else {
    let first_token_ms = self.forward_anthropic_sse_passthrough(
      client, stream_events, w,
    )
    self.record_success_stream_usage(
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
  if !rectifier_media_heuristic_enabled(provider) {
    return { body: Json::object(obj), count: 0 }
  }
  if !known_text_only_model(model) {
    return { body: Json::object(obj), count: 0 }
  }
  replace_image_blocks_with_marker(Json::object(obj))
}

///|
fn rectifier_media_heuristic_enabled(provider : ProviderRouteTarget?) -> Bool {
  let config = moonstat_rectifier_config_from_env()
  config.enabled &&
  config.request_media_heuristic &&
  provider_media_heuristic_enabled(provider)
}

///|
fn provider_media_heuristic_enabled(provider : ProviderRouteTarget?) -> Bool {
  guard provider is Some(provider) else { return true }
  guard provider.settings_config is Some(Object(settings)) else { return true }
  json_bool_from_map_any(settings, [
    "requestMediaHeuristic", "request_media_heuristic",
  ]).unwrap_or(true)
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
  ccs_media_retry_should_trigger_with_config(
    status_code,
    response_body,
    request_body,
    moonstat_rectifier_config_from_env(),
  )
}

///|
fn ccs_media_retry_should_trigger_with_config(
  status_code : Int,
  response_body : String,
  request_body : Json,
  config : RectifierConfig,
) -> Bool {
  config.enabled &&
  config.request_media_fallback &&
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
    first_token_ms = ccs_first_stream_event_ms(
      first_token_ms,
      self.stats.current_request_started_at_ms,
    )
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
async fn Gateway::forward_anthropic_sse_passthrough(
  self : Gateway,
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
        first_token_ms = ccs_first_stream_event_ms(
          first_token_ms,
          self.stats.current_request_started_at_ms,
        )
      }
    }
    w.write(line)
    w.write("\n")
    w.flush()
  }
  first_token_ms
}

///|
async fn Gateway::forward_gemini_native_sse_as_anthropic(
  self : Gateway,
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
    first_token_ms = ccs_first_stream_event_ms(
      first_token_ms,
      self.stats.current_request_started_at_ms,
    )
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
  let cache_read = match json_int(usage, "cache_read_input_tokens") {
    Some(tokens) => tokens
    None =>
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
        request, request_json, model, request_path, provider, app_type, providers,
        attempted_provider_ids, anthropic_beta, session_id, w,
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
            request, request_json, model, request_path, active_provider, app_type,
            providers, attempted_provider_ids, anthropic_beta, session_id, w,
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
  let mut first_token_ms : Int? = None
  while reader.read() is Some(event) {
    first_token_ms = ccs_first_stream_event_ms(
      first_token_ms,
      self.stats.current_request_started_at_ms,
    )
    w.write("event: \{event.event_type}\n")
    w.write("data: \{event.data}\n\n")
    w.flush()
  }
  ignore(self.codex_chat_history.record_stream_events(reader.events))
  self.record_success_stream_usage(
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
fn push_sse_json_event(events : Array[Json], data : String) -> Bool {
  let json_result : Result[Json, Error] = try? @json.parse(data)
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
