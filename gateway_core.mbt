///|
pub async fn Gateway::start(self : Gateway) -> Unit {
  self.logger.info("Starting MoonGate gateway on \{self.host}:\{self.port}")
  self.control.initialize() catch {
    err => self.logger.error("Failed to initialize control token: \{err}")
  }
  self.config.load_settings_store() catch {
    err => self.logger.warn("Failed to load MoonGate settings: \{err}")
  }
  self.proxy.load_provider_store() catch {
    err => self.logger.warn("Failed to load MoonGate providers: \{err}")
  }
  self.proxy.load_proxy_store() catch {
    err => self.logger.warn("Failed to load MoonGate proxy settings: \{err}")
  }
  self.usage.load_model_pricing_store()
  ignore(
    self.usage.load_and_reconcile_persistent_store(
      self.usage.pricing_override_rows(),
    ),
  )
  self.auth.load_startup_credentials(self.logger)
  let server = @httpx.Server::new(self.host, self.port, reuse_addr=true)
  let bound_port = server.port()
  try {
    let status_path = write_moongate_suite_status(
      host=self.host,
      port=bound_port,
      model=self.model,
      status="running",
      ready=true,
    )
    self.logger.info("Wrote Moon suite status to \{status_path}")
  } catch {
    err => self.logger.warn("Failed to write Moon suite status: \{err}")
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
  self.usage.register_status_routes(
    router,
    self.auth,
    self.proxy.provider_router,
    self.host,
    bound_port,
    self.runtime.uptime_seconds(self.started_at_ms),
  )
  self.config.register_routes(router, self.proxy, self.host, bound_port)
  self.runtime.register_routes(router)
  self.workspace.register_routes(
    router,
    self.config,
    self.logger,
    self.host,
    bound_port,
  )
  self.skills.register_routes(router)
  self.proxy.register_management_routes(
    router,
    self.usage,
    self.host,
    bound_port,
    self.started_at_ms,
    self.runtime.uptime_seconds(self.started_at_ms),
    self.config.stream_check_config,
  )
  self.openclaw.register_routes(router)
  self.usage.register_routes(router, self.auth, self.proxy.provider_router)
  self.session.register_routes(
    router,
    moon_session_terminal_from_settings(self.config.app_settings),
  )
  self.auth.register_routes(router)
  self.register_suite_routes(router, bound_port)
  router.set_not_found_handler(file_server.handler())
  self.logger.info("Gateway started on \{self.host}:\{bound_port}")
  server.serve(
    moongate_security_handler(
      router.handler(),
      self.control,
      self.host,
      bound_port,
    ),
  )
}
