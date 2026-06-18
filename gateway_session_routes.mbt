///|
fn SessionService::register_routes(
  self : SessionService,
  router : @httpx.Router,
  terminal : String?,
) -> Unit {
  router.add_handler(Get, "/sessions", (_, w) => self.handle_list_sessions(w))
  router.add_handler(Post, "/sessions", (_, w) => self.handle_list_sessions(w))
  router.add_handler(Get, "/sessions/messages", (r, w) => {
    self.handle_get_session_messages(r, w)
  })
  router.add_handler(Post, "/sessions/messages", (r, w) => {
    self.handle_get_session_messages(r, w)
  })
  router.add_handler(Post, "/sessions/terminal", (r, w) => {
    self.handle_launch_session_terminal(r, w, terminal)
  })
  router.add_handler(Post, "/sessions/delete", (r, w) => {
    self.handle_delete_session(r, w)
  })
  router.add_handler(Post, "/sessions/delete-many", (r, w) => {
    self.handle_delete_sessions(r, w)
  })
}
