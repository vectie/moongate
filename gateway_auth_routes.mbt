///|
fn AuthService::register_routes(
  self : AuthService,
  router : @httpx.Router,
) -> Unit {
  router.add_handler(Post, "/auth/login", (r, w) => {
    self.handle_auth_start_login(r, w)
  })
  router.add_handler(Post, "/auth/poll", (r, w) => {
    self.handle_auth_poll_for_account(r, w)
  })
  router.add_handler(Get, "/auth/accounts", (r, w) => {
    self.handle_auth_list_accounts(r, w)
  })
  router.add_handler(Get, "/auth/status", (r, w) => {
    self.handle_auth_get_status(r, w)
  })
  router.add_handler(Delete, "/auth/account", (r, w) => {
    self.handle_auth_remove_account(r, w)
  })
  router.add_handler(Post, "/auth/default-account", (r, w) => {
    self.handle_auth_set_default_account(r, w)
  })
  router.add_handler(Post, "/auth/logout", (r, w) => {
    self.handle_auth_logout(r, w)
  })
  router.add_handler(Post, "/copilot/device-flow", (r, w) => {
    self.handle_copilot_start_device_flow(r, w)
  })
  router.add_handler(Post, "/copilot/poll-auth", (r, w) => {
    self.handle_copilot_poll_for_auth(r, w)
  })
  router.add_handler(Post, "/copilot/poll-account", (r, w) => {
    self.handle_copilot_poll_for_account(r, w)
  })
  router.add_handler(Get, "/copilot/accounts", (_, w) => {
    self.handle_copilot_list_accounts(w)
  })
  router.add_handler(Get, "/copilot/status", (_, w) => {
    self.handle_copilot_get_auth_status(w)
  })
  router.add_handler(Get, "/copilot/authenticated", (_, w) => {
    self.handle_copilot_is_authenticated(w)
  })
  router.add_handler(Post, "/copilot/logout", (_, w) => {
    self.handle_copilot_logout(w)
  })
  router.add_handler(Delete, "/copilot/account", (r, w) => {
    self.handle_copilot_remove_account(r, w)
  })
  router.add_handler(Post, "/copilot/default-account", (r, w) => {
    self.handle_copilot_set_default_account(r, w)
  })
  router.add_handler(Get, "/copilot/token", (r, w) => {
    self.handle_copilot_get_token(r, w)
  })
  router.add_handler(Get, "/copilot/models", (r, w) => {
    self.handle_copilot_get_models(r, w)
  })
  router.add_handler(Get, "/copilot/usage", (r, w) => {
    self.handle_copilot_get_usage(r, w)
  })
}
