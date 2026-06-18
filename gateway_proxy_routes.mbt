///|
fn ProxyService::register_inference_routes(
  self : ProxyService,
  router : @httpx.Router,
  auth : AuthService,
  usage : UsageService,
  config : ConfigService,
  session : SessionService,
  model : String,
  logger : @pino.Logger,
) -> Unit {
  router.add_handler(Post, "/v1/messages", (r, w) => {
    self.handle_messages(auth, usage, config, session, model, logger, r, w)
  })
  router.add_handler(Post, "/claude-desktop/v1/messages", (r, w) => {
    self.handle_messages(auth, usage, config, session, model, logger, r, w)
  })
  for method_ in @httpx.methods {
    router.add_handler(method_, "/v1beta/*path", (r, w) => {
      self.handle_gemini(usage, r, w)
    })
    router.add_handler(method_, "/gemini/v1beta/*path", (r, w) => {
      self.handle_gemini(usage, r, w)
    })
    router.add_handler(method_, "/gemini/v1/*path", (r, w) => {
      self.handle_gemini(usage, r, w)
    })
  }
  router.add_handler(Post, "/chat/completions", (r, w) => {
    self.handle_chat_completions(auth, usage, session, model, r, w)
  })
  router.add_handler(Post, "/v1/chat/completions", (r, w) => {
    self.handle_chat_completions(auth, usage, session, model, r, w)
  })
  router.add_handler(Post, "/openclaw/v1/chat/completions", (r, w) => {
    self.handle_chat_completions(
      auth,
      usage,
      session,
      model,
      r,
      w,
      app_type="openclaw",
    )
  })
  router.add_handler(Post, "/responses", (r, w) => {
    self.handle_codex_responses(auth, usage, session, model, r, w)
  })
  router.add_handler(Post, "/v1/responses", (r, w) => {
    self.handle_codex_responses(auth, usage, session, model, r, w)
  })
  router.add_handler(Post, "/responses/compact", (r, w) => {
    self.handle_codex_responses(auth, usage, session, model, r, w, compact=true)
  })
  router.add_handler(Post, "/v1/responses/compact", (r, w) => {
    self.handle_codex_responses(auth, usage, session, model, r, w, compact=true)
  })
  router.add_handler(Get, "/models", (_, w) => self.handle_models(w))
  router.add_handler(Get, "/v1/models", (_, w) => self.handle_models(w))
  router.add_handler(Get, "/claude-desktop/v1/models", (r, w) => {
    self.handle_claude_desktop_models(auth, usage, r, w)
  })
}

///|
fn ProxyService::register_management_routes(
  self : ProxyService,
  router : @httpx.Router,
  usage : UsageService,
  host : String,
  port : Int,
  started_at_ms : Int,
  uptime_seconds : Int,
  stream_check_config : StreamCheckConfig,
) -> Unit {
  router.add_handler(Get, "/proxy/status", (_, w) => {
    self.handle_proxy_status(w, usage, host, port, uptime_seconds)
  })
  router.add_handler(Post, "/proxy/start", (_, w) => {
    self.handle_proxy_start_server(w, started_at_ms)
  })
  router.add_handler(Post, "/proxy/stop", (_, w) => {
    self.handle_proxy_stop_server(w)
  })
  router.add_handler(Post, "/proxy/stop-with-restore", (_, w) => {
    self.handle_proxy_stop_with_restore(w)
  })
  router.add_handler(Get, "/proxy/global-config", (_, w) => {
    self.handle_proxy_global_config(w)
  })
  router.add_handler(Post, "/proxy/global-config", (r, w) => {
    self.handle_proxy_update_global_config(r, w)
  })
  router.add_handler(Get, "/proxy/global-url", (_, w) => {
    self.handle_get_global_proxy_url(w)
  })
  router.add_handler(Post, "/proxy/global-url", (r, w) => {
    self.handle_set_global_proxy_url(r, w)
  })
  router.add_handler(Post, "/proxy/test-url", (r, w) => {
    self.handle_test_proxy_url(r, w)
  })
  router.add_handler(Get, "/proxy/upstream-status", (_, w) => {
    self.handle_get_upstream_proxy_status(w)
  })
  router.add_handler(Get, "/proxy/local-proxies", (_, w) => {
    self.handle_scan_local_proxies(w)
  })
  router.add_handler(Get, "/proxy/app-config", (r, w) => {
    self.handle_proxy_app_config(r, w)
  })
  router.add_handler(Post, "/proxy/app-config", (r, w) => {
    self.handle_proxy_update_app_config(r, w)
  })
  router.add_handler(Get, "/proxy/default-cost-multiplier", (r, w) => {
    self.handle_proxy_default_cost_multiplier(r, w)
  })
  router.add_handler(Post, "/proxy/default-cost-multiplier", (r, w) => {
    self.handle_proxy_set_default_cost_multiplier(r, w)
  })
  router.add_handler(Get, "/proxy/pricing-model-source", (r, w) => {
    self.handle_proxy_pricing_model_source(r, w)
  })
  router.add_handler(Post, "/proxy/pricing-model-source", (r, w) => {
    self.handle_proxy_set_pricing_model_source(r, w)
  })
  router.add_handler(Get, "/proxy/provider-health", (r, w) => {
    self.handle_proxy_provider_health(r, w)
  })
  router.add_handler(Get, "/proxy/circuit-breaker-config", (_, w) => {
    self.handle_proxy_circuit_breaker_config(w)
  })
  router.add_handler(Post, "/proxy/circuit-breaker-config", (r, w) => {
    self.handle_proxy_update_circuit_breaker_config(r, w)
  })
  router.add_handler(Get, "/proxy/circuit-breaker-stats", (r, w) => {
    self.handle_proxy_circuit_breaker_stats(r, w)
  })
  router.add_handler(Post, "/proxy/reset-circuit-breaker", (r, w) => {
    self.handle_proxy_reset_circuit_breaker(r, w)
  })
  router.add_handler(Get, "/proxy/failover-queue", (r, w) => {
    self.handle_proxy_failover_queue(r, w)
  })
  router.add_handler(Post, "/proxy/failover-queue", (r, w) => {
    self.handle_proxy_add_failover_queue(r, w)
  })
  router.add_handler(Delete, "/proxy/failover-queue", (r, w) => {
    self.handle_proxy_remove_failover_queue(r, w)
  })
  router.add_handler(Get, "/proxy/available-failover-providers", (r, w) => {
    self.handle_proxy_available_failover_providers(r, w)
  })
  router.add_handler(Get, "/proxy/auto-failover-enabled", (r, w) => {
    self.handle_proxy_auto_failover_enabled(r, w)
  })
  router.add_handler(Post, "/proxy/auto-failover-enabled", (r, w) => {
    self.handle_proxy_set_auto_failover_enabled(r, w)
  })
  router.add_handler(Get, "/proxy/takeover-status", (_, w) => {
    self.handle_proxy_takeover_status(w)
  })
  router.add_handler(Post, "/proxy/takeover-status", (r, w) => {
    self.handle_proxy_set_takeover_for_app(r, w)
  })
  router.add_handler(Post, "/proxy/switch-provider", (r, w) => {
    self.handle_proxy_switch_provider(usage, r, w)
  })
  router.add_handler(Post, "/proxy/sync-current-providers-live", (_, w) => {
    self.handle_sync_current_providers_live(usage, w)
  })
  router.add_handler(Post, "/proxy/import-default-config", (r, w) => {
    self.handle_import_default_config(r, w)
  })
  router.add_handler(Get, "/proxy/running", (_, w) => {
    self.handle_proxy_running(w)
  })
  router.add_handler(Post, "/proxy/stream-check/provider", (r, w) => {
    self.handle_stream_check_provider(stream_check_config, r, w)
  })
  router.add_handler(Post, "/proxy/stream-check/all", (r, w) => {
    self.handle_stream_check_all_providers(stream_check_config, r, w)
  })
  router.add_handler(Get, "/providers", (r, w) => {
    self.handle_get_providers(r, w)
  })
  router.add_handler(Get, "/providers/current", (r, w) => {
    self.handle_get_current_provider(r, w)
  })
  router.add_handler(Post, "/providers", (r, w) => {
    self.handle_add_provider(r, w, usage)
  })
  router.add_handler(Post, "/providers/update", (r, w) => {
    self.handle_update_provider(r, w, usage)
  })
  router.add_handler(Delete, "/providers", (r, w) => {
    self.handle_delete_provider(r, w)
  })
  router.add_handler(Delete, "/providers/live", (r, w) => {
    self.handle_remove_provider_from_live_config(r, w)
  })
  router.add_handler(Post, "/providers/switch", (r, w) => {
    self.handle_switch_provider(r, w, usage)
  })
  router.add_handler(Post, "/providers/terminal", (r, w) => {
    self.handle_open_provider_terminal(r, w)
  })
  router.add_handler(Get, "/providers/claude-desktop/status", (_, w) => {
    self.handle_get_claude_desktop_status(host, port, w)
  })
  router.add_handler(Get, "/providers/claude-desktop/default-routes", (_, w) => {
    self.handle_get_claude_desktop_default_routes(w)
  })
  router.add_handler(Post, "/providers/claude-desktop/import", (_, w) => {
    self.handle_import_claude_desktop_providers_from_claude(w)
  })
  router.add_handler(Post, "/providers/claude-desktop/official", (_, w) => {
    self.handle_ensure_claude_desktop_official_provider(w)
  })
  router.add_handler(Get, "/providers/live-settings", (r, w) => {
    self.handle_read_live_provider_settings(r, w)
  })
  router.add_handler(Get, "/providers/live-ids", (r, w) => {
    self.handle_get_live_provider_ids(
      w,
      usage_query_value(r.path, "appType").unwrap_or("opencode"),
    )
  })
  router.add_handler(Get, "/providers/live-provider", (r, w) => {
    self.handle_get_live_provider(
      r,
      w,
      usage_query_value(r.path, "appType").unwrap_or("openclaw"),
    )
  })
  router.add_handler(Post, "/providers/import-live", (r, w) => {
    self.handle_import_live_providers(
      w,
      usage_query_value(r.path, "appType").unwrap_or("opencode"),
    )
  })
  router.add_handler(Get, "/providers/universal", (_, w) => {
    self.handle_get_universal_providers(w)
  })
  router.add_handler(Get, "/providers/universal/item", (r, w) => {
    self.handle_get_universal_provider(r, w)
  })
  router.add_handler(Post, "/providers/universal", (r, w) => {
    self.handle_upsert_universal_provider(r, w)
  })
  router.add_handler(Delete, "/providers/universal", (r, w) => {
    self.handle_delete_universal_provider(r, w)
  })
  router.add_handler(Post, "/providers/universal/sync", (r, w) => {
    self.handle_sync_universal_provider(r, w)
  })
  router.add_handler(Get, "/providers/presets", (r, w) => {
    self.handle_get_provider_presets(r, w)
  })
  router.add_handler(Post, "/providers/test-endpoints", (r, w) => {
    self.handle_test_api_endpoints(r, w)
  })
  router.add_handler(Post, "/providers/sort-order", (r, w) => {
    self.handle_update_providers_sort_order(r, w)
  })
  router.add_handler(Get, "/providers/endpoints/list", (r, w) => {
    self.handle_get_custom_endpoints(r, w)
  })
  router.add_handler(Post, "/providers/endpoints", (r, w) => {
    self.handle_add_custom_endpoint(r, w)
  })
  router.add_handler(Delete, "/providers/endpoints", (r, w) => {
    self.handle_remove_custom_endpoint(r, w)
  })
  router.add_handler(Post, "/providers/endpoints/touch", (r, w) => {
    self.handle_update_endpoint_last_used(r, w)
  })
}
