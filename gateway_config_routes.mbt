///|
fn ConfigService::register_routes(
  self : ConfigService,
  router : @httpx.Router,
  proxy : ProxyService,
  host : String,
  port : Int,
) -> Unit {
  router.add_handler(Get, "/config/claude/status", (_, w) => {
    self.handle_get_config_status(w, "claude")
  })
  router.add_handler(Get, "/config/status", (r, w) => {
    self.handle_get_config_status_request(r, w)
  })
  router.add_handler(Get, "/config/claude-code/path", (_, w) => {
    self.handle_get_claude_code_config_path(w)
  })
  router.add_handler(Get, "/config/dir", (r, w) => {
    self.handle_get_config_dir(r, w)
  })
  router.add_handler(Post, "/config/folder/open", (r, w) => {
    self.handle_open_config_folder(r, w)
  })
  router.add_handler(Post, "/runtime/window-theme", (r, w) => {
    self.handle_set_window_theme(r, w)
  })
  router.add_handler(Post, "/runtime/lightweight-mode/enter", (_, w) => {
    self.handle_enter_lightweight_mode(w)
  })
  router.add_handler(Post, "/runtime/lightweight-mode/exit", (_, w) => {
    self.handle_exit_lightweight_mode(w)
  })
  router.add_handler(Get, "/runtime/lightweight-mode", (_, w) => {
    self.handle_is_lightweight_mode(w)
  })
  router.add_handler(Post, "/config/files/export", (r, w) => {
    self.handle_export_config_to_file(proxy, host~, port~, r, w)
  })
  router.add_handler(Post, "/config/files/import", (r, w) => {
    self.handle_import_config_from_file(proxy, host~, port~, r, w)
  })
  router.add_handler(Post, "/backups/db", (_, w) => {
    self.handle_create_db_backup(proxy, host~, port~, w)
  })
  router.add_handler(Get, "/backups/db", (_, w) => {
    self.handle_list_db_backups(w)
  })
  router.add_handler(Post, "/backups/db/restore", (r, w) => {
    self.handle_restore_db_backup(proxy, r, w)
  })
  router.add_handler(Post, "/backups/db/rename", (r, w) => {
    self.handle_rename_db_backup(r, w)
  })
  router.add_handler(Delete, "/backups/db/delete", (r, w) => {
    self.handle_delete_db_backup(r, w)
  })
  router.add_handler(Get, "/deeplinks/parse", (r, w) => {
    self.handle_parse_deeplink(r, w)
  })
  router.add_handler(Post, "/deeplinks/merge", (r, w) => {
    self.handle_merge_deeplink_config(r, w)
  })
  router.add_handler(Post, "/deeplinks/import", (r, w) => {
    self.handle_import_from_deeplink(proxy, r, w)
  })
  router.add_handler(Post, "/sync/webdav/test", (r, w) => {
    self.handle_webdav_test_connection(r, w)
  })
  router.add_handler(Post, "/sync/webdav/upload", (_, w) => {
    self.handle_webdav_sync_operation(proxy, host~, port~, w, "upload")
  })
  router.add_handler(Post, "/sync/webdav/download", (_, w) => {
    self.handle_webdav_sync_operation(proxy, host~, port~, w, "download")
  })
  router.add_handler(Post, "/sync/webdav/settings", (r, w) => {
    self.handle_webdav_sync_save_settings(r, w)
  })
  router.add_handler(Get, "/sync/webdav/remote-info", (_, w) => {
    self.handle_webdav_sync_fetch_remote_info(w)
  })
  router.add_handler(Post, "/sync/s3/test", (r, w) => {
    self.handle_s3_test_connection(r, w)
  })
  router.add_handler(Post, "/sync/s3/upload", (_, w) => {
    self.handle_s3_sync_operation(proxy, host~, port~, w, "upload")
  })
  router.add_handler(Post, "/sync/s3/download", (_, w) => {
    self.handle_s3_sync_operation(proxy, host~, port~, w, "download")
  })
  router.add_handler(Post, "/sync/s3/settings", (r, w) => {
    self.handle_s3_sync_save_settings(r, w)
  })
  router.add_handler(Get, "/sync/s3/remote-info", (_, w) => {
    self.handle_s3_sync_fetch_remote_info(w)
  })
  router.add_handler(Get, "/config/app-path", (_, w) => {
    self.handle_get_app_config_path(w)
  })
  router.add_handler(Get, "/config/app-folder/open", (_, w) => {
    self.handle_open_app_config_folder(w)
  })
  router.add_handler(Get, "/config/snippets/claude", (_, w) => {
    self.handle_get_common_config_snippet(w, "claude")
  })
  router.add_handler(Post, "/config/snippets/claude", (r, w) => {
    self.handle_set_common_config_snippet(r, w, "claude")
  })
  router.add_handler(Get, "/config/snippets", (r, w) => {
    self.handle_get_common_config_snippet_request(r, w)
  })
  router.add_handler(Post, "/config/snippets", (r, w) => {
    self.handle_set_common_config_snippet_request(r, w)
  })
  router.add_handler(Post, "/config/snippets/extract", (r, w) => {
    self.handle_extract_common_config_snippet(r, w)
  })
  router.add_handler(Get, "/config/env/conflicts", (r, w) => {
    self.handle_check_env_conflicts(r, w)
  })
  router.add_handler(Post, "/config/env/delete", (r, w) => {
    self.handle_delete_env_vars(r, w)
  })
  router.add_handler(Post, "/config/env/restore", (r, w) => {
    self.handle_restore_env_backup(r, w)
  })
  router.add_handler(Get, "/mcp/claude/status", (_, w) => {
    self.handle_get_claude_mcp_status(w)
  })
  router.add_handler(Get, "/mcp/claude/config", (_, w) => {
    self.handle_read_claude_mcp_config(w)
  })
  router.add_handler(Post, "/mcp/claude/servers", (r, w) => {
    self.handle_upsert_claude_mcp_server(r, w)
  })
  router.add_handler(Delete, "/mcp/claude/servers", (r, w) => {
    self.handle_delete_mcp_server(r, w)
  })
  router.add_handler(Get, "/mcp/validate", (r, w) => {
    self.handle_validate_mcp_command(r, w)
  })
  router.add_handler(Get, "/mcp/config", (r, w) => {
    self.handle_get_mcp_config(r, w)
  })
  router.add_handler(Post, "/mcp/config/servers", (r, w) => {
    self.handle_upsert_mcp_server_in_config(r, w)
  })
  router.add_handler(Delete, "/mcp/config/servers", (r, w) => {
    self.handle_delete_mcp_server(r, w)
  })
  router.add_handler(Post, "/mcp/enabled", (r, w) => {
    self.handle_set_mcp_enabled(r, w)
  })
  router.add_handler(Get, "/mcp/servers", (_, w) => {
    self.handle_get_mcp_servers(w)
  })
  router.add_handler(Post, "/mcp/servers", (r, w) => {
    self.handle_upsert_mcp_server(r, w)
  })
  router.add_handler(Delete, "/mcp/servers", (r, w) => {
    self.handle_delete_mcp_server(r, w)
  })
  router.add_handler(Post, "/mcp/apps/toggle", (r, w) => {
    self.handle_toggle_mcp_app(r, w)
  })
  router.add_handler(Post, "/mcp/import-apps", (_, w) => {
    self.handle_import_mcp_from_apps(w)
  })
  router.add_handler(Get, "/prompts", (r, w) => self.handle_get_prompts(r, w))
  router.add_handler(Post, "/prompts", (r, w) => self.handle_upsert_prompt(r, w))
  router.add_handler(Delete, "/prompts", (r, w) => {
    self.handle_delete_prompt(r, w)
  })
  router.add_handler(Post, "/prompts/enable", (r, w) => {
    self.handle_enable_prompt(r, w)
  })
  router.add_handler(Get, "/settings", (_, w) => self.handle_get_settings(w))
  router.add_handler(Post, "/settings", (r, w) => {
    self.handle_save_settings(r, w)
  })
  router.add_handler(Get, "/settings/app-config-dir", (_, w) => {
    self.handle_get_app_config_dir_override(w)
  })
  router.add_handler(Post, "/settings/app-config-dir", (r, w) => {
    self.handle_set_app_config_dir_override(r, w)
  })
  router.add_handler(Post, "/settings/auto-launch", (r, w) => {
    self.handle_set_auto_launch(r, w)
  })
  router.add_handler(Get, "/settings/auto-launch", (_, w) => {
    self.handle_get_auto_launch_status(w)
  })
  router.add_handler(Get, "/settings/rectifier", (_, w) => {
    self.handle_get_rectifier_config(w)
  })
  router.add_handler(Post, "/settings/rectifier", (r, w) => {
    self.handle_set_rectifier_config(r, w)
  })
  router.add_handler(Get, "/settings/optimizer", (_, w) => {
    self.handle_get_optimizer_config(w)
  })
  router.add_handler(Post, "/settings/optimizer", (r, w) => {
    self.handle_set_optimizer_config(r, w)
  })
  router.add_handler(Get, "/settings/copilot-optimizer", (_, w) => {
    self.handle_get_copilot_optimizer_config(w)
  })
  router.add_handler(Post, "/settings/copilot-optimizer", (r, w) => {
    self.handle_set_copilot_optimizer_config(r, w)
  })
  router.add_handler(Get, "/settings/log", (_, w) => {
    self.handle_get_log_config(w)
  })
  router.add_handler(Post, "/settings/log", (r, w) => {
    self.handle_set_log_config(r, w)
  })
  router.add_handler(Get, "/plugin/claude/status", (_, w) => {
    self.handle_get_claude_plugin_status(w)
  })
  router.add_handler(Get, "/plugin/claude/config", (_, w) => {
    self.handle_read_claude_plugin_config(w)
  })
  router.add_handler(Post, "/plugin/claude/config", (r, w) => {
    self.handle_apply_claude_plugin_config(r, w)
  })
  router.add_handler(Get, "/plugin/claude/applied", (_, w) => {
    self.handle_is_claude_plugin_applied(w)
  })
  router.add_handler(Post, "/plugin/claude/onboarding-skip", (_, w) => {
    self.handle_apply_claude_onboarding_skip(w)
  })
  router.add_handler(Post, "/plugin/claude/onboarding-skip/clear", (_, w) => {
    self.handle_clear_claude_onboarding_skip(w)
  })
  router.add_handler(Get, "/proxy/stream-check/config", (_, w) => {
    self.handle_get_stream_check_config(w)
  })
  router.add_handler(Post, "/proxy/stream-check/config", (r, w) => {
    self.handle_save_stream_check_config(r, w)
  })
  router.add_handler(Post, "/config/models", (r, w) => {
    self.handle_fetch_models_for_config(r, w)
  })
}
