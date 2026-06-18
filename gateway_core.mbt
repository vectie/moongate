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
  self.usage.register_status_routes(
    router,
    self.auth,
    self.proxy.provider_router,
    self.host,
    self.port,
    self.runtime.uptime_seconds(self.started_at_ms),
  )
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
  self.openclaw.register_routes(router)
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
