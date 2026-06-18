///|
fn WorkspaceService::register_routes(
  self : WorkspaceService,
  router : @httpx.Router,
  config : ConfigService,
  proxy : ProxyService,
  logger : @pino.Logger,
) -> Unit {
  router.add_handler(Get, "/participant/register", (_, w) => {
    self.handle_register_page(logger, w)
  })
  router.add_handler(Post, "/files/dialogs/save", (r, w) => {
    self.handle_save_file_dialog(r, w)
  })
  router.add_handler(Get, "/providers/omo/file", (_, w) => {
    self.handle_read_omo_local_file(w, slim=false)
  })
  router.add_handler(Get, "/providers/omo/current", (_, w) => {
    proxy.handle_get_current_omo_provider_id(w, slim=false)
  })
  router.add_handler(Post, "/providers/omo/disable", (_, w) => {
    proxy.handle_disable_current_omo(w, slim=false)
  })
  router.add_handler(Get, "/providers/omo-slim/file", (_, w) => {
    self.handle_read_omo_local_file(w, slim=true)
  })
  router.add_handler(Get, "/providers/omo-slim/current", (_, w) => {
    proxy.handle_get_current_omo_provider_id(w, slim=true)
  })
  router.add_handler(Post, "/providers/omo-slim/disable", (_, w) => {
    proxy.handle_disable_current_omo(w, slim=true)
  })
  router.add_handler(Post, "/files/dialogs/open", (_, w) => {
    self.handle_open_file_dialog(w)
  })
  router.add_handler(Post, "/files/dialogs/open-zip", (_, w) => {
    self.handle_open_zip_file_dialog(w)
  })
  router.add_handler(Post, "/prompts/import-file", (r, w) => {
    self.handle_import_prompt_from_file(config, r, w)
  })
  router.add_handler(Get, "/prompts/current-file", (r, w) => {
    self.handle_get_current_prompt_file_content(r, w)
  })
  router.add_handler(Get, "/workspace/memory", (_, w) => {
    self.handle_list_daily_memory_files(w)
  })
  router.add_handler(Get, "/workspace/memory/file", (r, w) => {
    self.handle_read_daily_memory_file(r, w)
  })
  router.add_handler(Post, "/workspace/memory/write", (r, w) => {
    self.handle_write_daily_memory_file(r, w)
  })
  router.add_handler(Get, "/workspace/memory/search", (r, w) => {
    self.handle_search_daily_memory_files(r, w)
  })
  router.add_handler(Delete, "/workspace/memory/file", (r, w) => {
    self.handle_delete_daily_memory_file(r, w)
  })
  router.add_handler(Post, "/workspace/memory/delete", (r, w) => {
    self.handle_delete_daily_memory_file(r, w)
  })
  router.add_handler(Get, "/workspace/files", (r, w) => {
    self.handle_read_workspace_file(r, w)
  })
  router.add_handler(Post, "/workspace/files/read", (r, w) => {
    self.handle_read_workspace_file(r, w)
  })
  router.add_handler(Post, "/workspace/files", (r, w) => {
    self.handle_write_workspace_file(r, w)
  })
  router.add_handler(Post, "/workspace/open", (r, w) => {
    self.handle_open_workspace_directory(r, w)
  })
}
