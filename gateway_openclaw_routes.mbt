///|
fn OpenClawService::register_routes(
  self : OpenClawService,
  router : @httpx.Router,
) -> Unit {
  router.add_handler(Get, "/openclaw/config-health", (_, w) => {
    self.handle_scan_openclaw_config_health(w)
  })
  router.add_handler(Get, "/openclaw/default-model", (_, w) => {
    self.handle_get_openclaw_default_model(w)
  })
  router.add_handler(Post, "/openclaw/default-model", (r, w) => {
    self.handle_set_openclaw_default_model(r, w)
  })
  router.add_handler(Get, "/openclaw/model-catalog", (_, w) => {
    self.handle_get_openclaw_model_catalog(w)
  })
  router.add_handler(Post, "/openclaw/model-catalog", (r, w) => {
    self.handle_set_openclaw_model_catalog(r, w)
  })
  router.add_handler(Get, "/openclaw/agents-defaults", (_, w) => {
    self.handle_get_openclaw_agents_defaults(w)
  })
  router.add_handler(Post, "/openclaw/agents-defaults", (r, w) => {
    self.handle_set_openclaw_agents_defaults(r, w)
  })
  router.add_handler(Get, "/openclaw/env", (_, w) => {
    self.handle_get_openclaw_env(w)
  })
  router.add_handler(Post, "/openclaw/env", (r, w) => {
    self.handle_set_openclaw_env(r, w)
  })
  router.add_handler(Get, "/openclaw/tools", (_, w) => {
    self.handle_get_openclaw_tools(w)
  })
  router.add_handler(Post, "/openclaw/tools", (r, w) => {
    self.handle_set_openclaw_tools(r, w)
  })
  router.add_handler(Get, "/hermes/model-config", (_, w) => {
    self.handle_get_hermes_model_config(w)
  })
  router.add_handler(Get, "/hermes/memory", (r, w) => {
    self.handle_get_hermes_memory(r, w)
  })
  router.add_handler(Post, "/hermes/memory", (r, w) => {
    self.handle_set_hermes_memory(r, w)
  })
  router.add_handler(Get, "/hermes/memory-limits", (_, w) => {
    self.handle_get_hermes_memory_limits(w)
  })
  router.add_handler(Post, "/hermes/memory-enabled", (r, w) => {
    self.handle_set_hermes_memory_enabled(r, w)
  })
  router.add_handler(Get, "/hermes/web-ui", (r, w) => {
    self.handle_open_hermes_web_ui(r, w)
  })
  router.add_handler(Post, "/hermes/web-ui", (r, w) => {
    self.handle_open_hermes_web_ui(r, w)
  })
  router.add_handler(Post, "/hermes/dashboard", (_, w) => {
    self.handle_launch_hermes_dashboard(w)
  })
}
