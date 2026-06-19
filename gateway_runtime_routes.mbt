///|
fn RuntimeService::register_routes(
  self : RuntimeService,
  router : @httpx.Router,
) -> Unit {
  router.add_handler(Post, "/files/directories/pick", (r, w) => {
    self.handle_pick_directory(r, w)
  })
  router.add_handler(Post, "/runtime/open-external", (r, w) => {
    self.handle_open_external(r, w)
  })
  router.add_handler(Post, "/runtime/clipboard/text", (r, w) => {
    self.handle_copy_text_to_clipboard(r, w)
  })
  router.add_handler(Post, "/runtime/updates/check", (_, w) => {
    self.handle_check_for_updates(w)
  })
  router.add_handler(Post, "/runtime/tray-menu/update", (_, w) => {
    self.handle_update_tray_menu(w)
  })
  router.add_handler(Get, "/runtime/portable-mode", (_, w) => {
    self.handle_is_portable_mode(w)
  })
  router.add_handler(Get, "/tools/versions", (r, w) => {
    self.handle_get_tool_versions(r, w)
  })
  router.add_handler(Post, "/tools/lifecycle-action", (r, w) => {
    self.handle_run_tool_lifecycle_action(r, w)
  })
  router.add_handler(Get, "/tools/probe", (r, w) => {
    self.handle_probe_tool_installations(r, w)
  })
  router.add_handler(Post, "/runtime/restart", (_, w) => {
    self.handle_restart_app(w)
  })
  router.add_handler(Post, "/runtime/updates/install-restart", (_, w) => {
    self.handle_install_update_and_restart(w)
  })
}
