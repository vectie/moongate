///|
pub async fn Gateway::start(self : Gateway) -> Unit {
  self.logger.info(
    "Starting Anthropic -> Codex OAuth Gateway on \{self.host}:\{self.port}",
  )
  try {
    let status_path = write_moonstat_suite_status(
      host=self.host,
      port=self.port,
      model=self.model,
      status="running",
      ready=true,
    )
    self.logger.info("Wrote Moon suite status to \{status_path}")
  } catch {
    err => self.logger.warn("Failed to write Moon suite status: \{err}")
  }
  self.usage.load_model_pricing_store()
  ignore(
    self.usage.load_and_reconcile_persistent_store(
      self.usage.pricing_override_rows(),
    ),
  )
  let creds_result : Result[@codex.Credentials, Error] = moon_async_result(() => {
    @codex.load_credentials()
  })
  if creds_result is Ok(creds) {
    self.auth.credentials = Some(creds)
    self.logger.info("Loaded credentials from file")
  } else {
    self.logger.warn(
      "No credentials found. Please login first with: moonstat login",
    )
  }
  let router = @httpx.Router::new()
  let file_server = @httpx.FileServer::new("public")
  self.proxy.register_inference_routes(
    router,
    self.auth,
    self.usage,
    self.config,
    self.session,
    self.model,
    self.logger,
  )
  router.add_handler(Get, "/health", (_, w) => {
    self.usage.handle_health(w, self.auth.credentials_loaded())
  })
  router.add_handler(Get, "/status", (_, w) => {
    self.usage.handle_status(
      w,
      self.host,
      self.port,
      self.runtime.uptime_seconds(self.started_at_ms),
      provider_routes=Some(self.proxy.provider_router.route_stats_json()),
    )
  })
  router.add_handler(Get, "/stats", (_, w) => self.usage.handle_stats(w))
  router.add_handler(Get, "/metrics", (_, w) => {
    self.usage.handle_metrics(
      w,
      provider_metrics=provider_router_prometheus_metrics(
        self.proxy.provider_router,
      ),
    )
  })
  self.config.register_routes(router, self.proxy, self.host, self.port)
  self.runtime.register_routes(router, self.proxy)
  self.workspace.register_routes(router, self.config, self.proxy, self.logger)
  self.skills.register_routes(router, self.config)
  self.proxy.register_management_routes(
    router,
    self.usage,
    self.host,
    self.port,
    self.started_at_ms,
    self.runtime.uptime_seconds(self.started_at_ms),
    self.config.stream_check_config,
  )
  router.add_handler(Get, "/openclaw/config-health", (_, w) => {
    self.openclaw.handle_scan_openclaw_config_health(w)
  })
  router.add_handler(Get, "/openclaw/default-model", (_, w) => {
    self.openclaw.handle_get_openclaw_default_model(w)
  })
  router.add_handler(Post, "/openclaw/default-model", (r, w) => {
    self.openclaw.handle_set_openclaw_default_model(r, w)
  })
  router.add_handler(Get, "/openclaw/model-catalog", (_, w) => {
    self.openclaw.handle_get_openclaw_model_catalog(w)
  })
  router.add_handler(Post, "/openclaw/model-catalog", (r, w) => {
    self.openclaw.handle_set_openclaw_model_catalog(r, w)
  })
  router.add_handler(Get, "/openclaw/agents-defaults", (_, w) => {
    self.openclaw.handle_get_openclaw_agents_defaults(w)
  })
  router.add_handler(Post, "/openclaw/agents-defaults", (r, w) => {
    self.openclaw.handle_set_openclaw_agents_defaults(r, w)
  })
  router.add_handler(Get, "/openclaw/env", (_, w) => {
    self.openclaw.handle_get_openclaw_env(w)
  })
  router.add_handler(Post, "/openclaw/env", (r, w) => {
    self.openclaw.handle_set_openclaw_env(r, w)
  })
  router.add_handler(Get, "/openclaw/tools", (_, w) => {
    self.openclaw.handle_get_openclaw_tools(w)
  })
  router.add_handler(Post, "/openclaw/tools", (r, w) => {
    self.openclaw.handle_set_openclaw_tools(r, w)
  })
  router.add_handler(Get, "/hermes/model-config", (_, w) => {
    self.openclaw.handle_get_hermes_model_config(w)
  })
  router.add_handler(Get, "/hermes/memory", (r, w) => {
    self.openclaw.handle_get_hermes_memory(r, w)
  })
  router.add_handler(Post, "/hermes/memory", (r, w) => {
    self.openclaw.handle_set_hermes_memory(r, w)
  })
  router.add_handler(Get, "/hermes/memory-limits", (_, w) => {
    self.openclaw.handle_get_hermes_memory_limits(w)
  })
  router.add_handler(Post, "/hermes/memory-enabled", (r, w) => {
    self.openclaw.handle_set_hermes_memory_enabled(r, w)
  })
  router.add_handler(Get, "/hermes/web-ui", (r, w) => {
    self.openclaw.handle_open_hermes_web_ui(r, w)
  })
  router.add_handler(Post, "/hermes/web-ui", (r, w) => {
    self.openclaw.handle_open_hermes_web_ui(r, w)
  })
  router.add_handler(Post, "/hermes/dashboard", (_, w) => {
    self.openclaw.handle_launch_hermes_dashboard(w)
  })
  self.usage.register_routes(router, self.auth, self.proxy.provider_router)
  self.session.register_routes(
    router,
    moon_session_terminal_from_settings(self.config.app_settings),
  )
  self.auth.register_routes(router, self.logger)
  router.set_not_found_handler(file_server.handler())
  let server = @httpx.Server::new(self.host, self.port, reuse_addr=true)
  self.logger.info("Gateway started on \{self.host}:\{server.port()}")
  server.serve(router.handler())
}
