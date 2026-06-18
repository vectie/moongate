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
  router.add_handler(Get, "/participant/register", (_, w) => {
    self.workspace.handle_register_page(self.logger, w)
  })
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
  router.add_handler(Get, "/config/claude/status", (_, w) => {
    self.config.handle_get_config_status(w, "claude")
  })
  router.add_handler(Get, "/config/status", (r, w) => {
    self.config.handle_get_config_status_request(r, w)
  })
  router.add_handler(Post, "/config/status", (r, w) => {
    self.config.handle_get_config_status_request(r, w)
  })
  router.add_handler(Get, "/config/claude-code/path", (_, w) => {
    self.config.handle_get_claude_code_config_path(w)
  })
  router.add_handler(Get, "/config/dir", (r, w) => {
    self.config.handle_get_config_dir(r, w)
  })
  router.add_handler(Post, "/config/dir", (r, w) => {
    self.config.handle_get_config_dir(r, w)
  })
  router.add_handler(Get, "/config/folder/open", (r, w) => {
    self.config.handle_open_config_folder(r, w)
  })
  router.add_handler(Post, "/config/folder/open", (r, w) => {
    self.config.handle_open_config_folder(r, w)
  })
  router.add_handler(Get, "/files/directories/pick", (r, w) => {
    self.runtime.handle_pick_directory(r, w)
  })
  router.add_handler(Post, "/files/directories/pick", (r, w) => {
    self.runtime.handle_pick_directory(r, w)
  })
  router.add_handler(Get, "/runtime/open-external", (r, w) => {
    self.proxy.handle_open_external(r, w)
  })
  router.add_handler(Post, "/runtime/open-external", (r, w) => {
    self.proxy.handle_open_external(r, w)
  })
  router.add_handler(Post, "/runtime/clipboard/text", (r, w) => {
    self.runtime.handle_copy_text_to_clipboard(r, w)
  })
  router.add_handler(Get, "/runtime/clipboard/text", (r, w) => {
    self.runtime.handle_copy_text_to_clipboard(r, w)
  })
  router.add_handler(Post, "/runtime/updates/check", (_, w) => {
    self.proxy.handle_check_for_updates(w)
  })
  router.add_handler(Get, "/runtime/updates/check", (_, w) => {
    self.proxy.handle_check_for_updates(w)
  })
  router.add_handler(Post, "/runtime/tray-menu/update", (_, w) => {
    self.runtime.handle_update_tray_menu(w)
  })
  router.add_handler(Get, "/runtime/tray-menu/update", (_, w) => {
    self.runtime.handle_update_tray_menu(w)
  })
  router.add_handler(Get, "/runtime/portable-mode", (_, w) => {
    self.runtime.handle_is_portable_mode(w)
  })
  router.add_handler(Get, "/runtime/init-error", (_, w) => {
    self.runtime.handle_get_init_error(w)
  })
  router.add_handler(Get, "/runtime/migration-result", (_, w) => {
    self.runtime.handle_get_migration_result(w)
  })
  router.add_handler(Get, "/runtime/skills-migration-result", (_, w) => {
    self.runtime.handle_get_skills_migration_result(w)
  })
  router.add_handler(Get, "/tools/versions", (r, w) => {
    self.runtime.handle_get_tool_versions(r, w)
  })
  router.add_handler(Post, "/tools/versions", (r, w) => {
    self.runtime.handle_get_tool_versions(r, w)
  })
  router.add_handler(Post, "/tools/lifecycle-action", (r, w) => {
    self.runtime.handle_run_tool_lifecycle_action(r, w)
  })
  router.add_handler(Get, "/tools/probe", (r, w) => {
    self.runtime.handle_probe_tool_installations(r, w)
  })
  router.add_handler(Post, "/tools/probe", (r, w) => {
    self.runtime.handle_probe_tool_installations(r, w)
  })
  router.add_handler(Post, "/runtime/window-theme", (r, w) => {
    self.config.handle_set_window_theme(r, w)
  })
  router.add_handler(Get, "/runtime/window-theme", (r, w) => {
    self.config.handle_set_window_theme(r, w)
  })
  router.add_handler(Post, "/runtime/lightweight-mode/enter", (_, w) => {
    self.config.handle_enter_lightweight_mode(w)
  })
  router.add_handler(Get, "/runtime/lightweight-mode/enter", (_, w) => {
    self.config.handle_enter_lightweight_mode(w)
  })
  router.add_handler(Post, "/runtime/lightweight-mode/exit", (_, w) => {
    self.config.handle_exit_lightweight_mode(w)
  })
  router.add_handler(Get, "/runtime/lightweight-mode/exit", (_, w) => {
    self.config.handle_exit_lightweight_mode(w)
  })
  router.add_handler(Get, "/runtime/lightweight-mode", (_, w) => {
    self.config.handle_is_lightweight_mode(w)
  })
  router.add_handler(Post, "/files/dialogs/save", (r, w) => {
    self.workspace.handle_save_file_dialog(r, w)
  })
  router.add_handler(Get, "/files/dialogs/save", (r, w) => {
    self.workspace.handle_save_file_dialog(r, w)
  })
  router.add_handler(Post, "/config/files/export", (r, w) => {
    self.config.handle_export_config_to_file(
      self.proxy,
      host=self.host,
      port=self.port,
      r,
      w,
    )
  })
  router.add_handler(Get, "/config/files/export", (r, w) => {
    self.config.handle_export_config_to_file(
      self.proxy,
      host=self.host,
      port=self.port,
      r,
      w,
    )
  })
  router.add_handler(Post, "/config/files/import", (r, w) => {
    self.config.handle_import_config_from_file(
      self.proxy,
      host=self.host,
      port=self.port,
      r,
      w,
    )
  })
  router.add_handler(Get, "/config/files/import", (r, w) => {
    self.config.handle_import_config_from_file(
      self.proxy,
      host=self.host,
      port=self.port,
      r,
      w,
    )
  })
  router.add_handler(Post, "/backups/db", (_, w) => {
    self.config.handle_create_db_backup(
      self.proxy,
      host=self.host,
      port=self.port,
      w,
    )
  })
  router.add_handler(Get, "/backups/db", (_, w) => {
    self.config.handle_list_db_backups(w)
  })
  router.add_handler(Post, "/backups/db/restore", (r, w) => {
    self.config.handle_restore_db_backup(self.proxy, r, w)
  })
  router.add_handler(Post, "/backups/db/rename", (r, w) => {
    self.config.handle_rename_db_backup(r, w)
  })
  router.add_handler(Delete, "/backups/db/delete", (r, w) => {
    self.config.handle_delete_db_backup(r, w)
  })
  router.add_handler(Post, "/backups/db/delete", (r, w) => {
    self.config.handle_delete_db_backup(r, w)
  })
  router.add_handler(Post, "/deeplinks/parse", (r, w) => {
    self.config.handle_parse_deeplink(r, w)
  })
  router.add_handler(Get, "/deeplinks/parse", (r, w) => {
    self.config.handle_parse_deeplink(r, w)
  })
  router.add_handler(Post, "/deeplinks/merge", (r, w) => {
    self.config.handle_merge_deeplink_config(r, w)
  })
  router.add_handler(Get, "/deeplinks/merge", (r, w) => {
    self.config.handle_merge_deeplink_config(r, w)
  })
  router.add_handler(Post, "/deeplinks/import", (r, w) => {
    self.config.handle_import_from_deeplink(self.proxy, r, w)
  })
  router.add_handler(Post, "/sync/webdav/test", (r, w) => {
    self.config.handle_webdav_test_connection(r, w)
  })
  router.add_handler(Post, "/sync/webdav/upload", (_, w) => {
    self.config.handle_webdav_sync_operation(
      self.proxy,
      host=self.host,
      port=self.port,
      w,
      "upload",
    )
  })
  router.add_handler(Post, "/sync/webdav/download", (_, w) => {
    self.config.handle_webdav_sync_operation(
      self.proxy,
      host=self.host,
      port=self.port,
      w,
      "download",
    )
  })
  router.add_handler(Post, "/sync/webdav/settings", (r, w) => {
    self.config.handle_webdav_sync_save_settings(r, w)
  })
  router.add_handler(Get, "/sync/webdav/remote-info", (_, w) => {
    self.config.handle_webdav_sync_fetch_remote_info(w)
  })
  router.add_handler(Post, "/sync/s3/test", (r, w) => {
    self.config.handle_s3_test_connection(r, w)
  })
  router.add_handler(Post, "/sync/s3/upload", (_, w) => {
    self.config.handle_s3_sync_operation(
      self.proxy,
      host=self.host,
      port=self.port,
      w,
      "upload",
    )
  })
  router.add_handler(Post, "/sync/s3/download", (_, w) => {
    self.config.handle_s3_sync_operation(
      self.proxy,
      host=self.host,
      port=self.port,
      w,
      "download",
    )
  })
  router.add_handler(Post, "/sync/s3/settings", (r, w) => {
    self.config.handle_s3_sync_save_settings(r, w)
  })
  router.add_handler(Get, "/sync/s3/remote-info", (_, w) => {
    self.config.handle_s3_sync_fetch_remote_info(w)
  })
  router.add_handler(Get, "/providers/omo/file", (_, w) => {
    self.workspace.handle_read_omo_local_file(w, slim=false)
  })
  router.add_handler(Post, "/providers/omo/file", (_, w) => {
    self.workspace.handle_read_omo_local_file(w, slim=false)
  })
  router.add_handler(Get, "/providers/omo/current", (_, w) => {
    self.proxy.handle_get_current_omo_provider_id(w, slim=false)
  })
  router.add_handler(Post, "/providers/omo/current", (_, w) => {
    self.proxy.handle_get_current_omo_provider_id(w, slim=false)
  })
  router.add_handler(Post, "/providers/omo/disable", (_, w) => {
    self.proxy.handle_disable_current_omo(w, slim=false)
  })
  router.add_handler(Get, "/providers/omo-slim/file", (_, w) => {
    self.workspace.handle_read_omo_local_file(w, slim=true)
  })
  router.add_handler(Post, "/providers/omo-slim/file", (_, w) => {
    self.workspace.handle_read_omo_local_file(w, slim=true)
  })
  router.add_handler(Get, "/providers/omo-slim/current", (_, w) => {
    self.proxy.handle_get_current_omo_provider_id(w, slim=true)
  })
  router.add_handler(Post, "/providers/omo-slim/current", (_, w) => {
    self.proxy.handle_get_current_omo_provider_id(w, slim=true)
  })
  router.add_handler(Post, "/providers/omo-slim/disable", (_, w) => {
    self.proxy.handle_disable_current_omo(w, slim=true)
  })
  router.add_handler(Post, "/files/dialogs/open", (_, w) => {
    self.workspace.handle_open_file_dialog(w)
  })
  router.add_handler(Get, "/files/dialogs/open", (_, w) => {
    self.workspace.handle_open_file_dialog(w)
  })
  router.add_handler(Post, "/files/dialogs/open-zip", (_, w) => {
    self.workspace.handle_open_zip_file_dialog(w)
  })
  router.add_handler(Get, "/files/dialogs/open-zip", (_, w) => {
    self.workspace.handle_open_zip_file_dialog(w)
  })
  router.add_handler(Get, "/skills/installed", (_, w) => {
    self.skills.handle_get_installed_skills(w)
  })
  router.add_handler(Get, "/skills/backups", (_, w) => {
    self.config.handle_get_skill_backups(w)
  })
  router.add_handler(Post, "/skills/backups/delete", (r, w) => {
    self.config.handle_delete_skill_backup(r, w)
  })
  router.add_handler(Post, "/skills/backups/restore", (r, w) => {
    self.config.handle_restore_skill_backup(r, w)
  })
  router.add_handler(Post, "/skills/install-unified", (r, w) => {
    self.skills.handle_install_skill_unified(r, w)
  })
  router.add_handler(Post, "/skills/uninstall-unified", (r, w) => {
    self.skills.handle_uninstall_skill_unified(r, w)
  })
  router.add_handler(Post, "/skills/toggle-app", (r, w) => {
    self.skills.handle_toggle_skill_app(r, w)
  })
  router.add_handler(Get, "/skills/unmanaged", (_, w) => {
    self.skills.handle_scan_unmanaged_skills(w)
  })
  router.add_handler(Post, "/skills/import-apps", (r, w) => {
    self.skills.handle_import_skills_from_apps(r, w)
  })
  router.add_handler(Get, "/skills/discover", (_, w) => {
    self.skills.handle_discover_available_skills(w)
  })
  router.add_handler(Get, "/skills/updates", (_, w) => {
    self.skills.handle_check_skill_updates(w)
  })
  router.add_handler(Post, "/skills/update", (r, w) => {
    self.skills.handle_update_skill(r, w)
  })
  router.add_handler(Post, "/skills/migrate-storage", (r, w) => {
    self.skills.handle_migrate_skill_storage(r, w)
  })
  router.add_handler(Get, "/skills/search", (r, w) => {
    self.skills.handle_search_skills_sh(r, w)
  })
  router.add_handler(Post, "/skills/search", (r, w) => {
    self.skills.handle_search_skills_sh(r, w)
  })
  router.add_handler(Get, "/skills", (_, w) => self.skills.handle_get_skills(w))
  router.add_handler(Get, "/skills/app", (_, w) => {
    self.skills.handle_get_skills(w)
  })
  router.add_handler(Get, "/skills/repos", (_, w) => {
    self.skills.handle_get_skill_repos(w)
  })
  router.add_handler(Post, "/skills/repos", (r, w) => {
    self.skills.handle_add_skill_repo(r, w)
  })
  router.add_handler(Post, "/skills/repos/remove", (r, w) => {
    self.skills.handle_remove_skill_repo(r, w)
  })
  router.add_handler(Post, "/skills/install-zip", (r, w) => {
    self.skills.handle_install_skills_from_zip(r, w)
  })
  router.add_handler(Get, "/config/app-path", (_, w) => {
    self.config.handle_get_app_config_path(w)
  })
  router.add_handler(Get, "/config/app-folder/open", (_, w) => {
    self.config.handle_open_app_config_folder(w)
  })
  router.add_handler(Get, "/config/snippets/claude", (_, w) => {
    self.config.handle_get_common_config_snippet(w, "claude")
  })
  router.add_handler(Post, "/config/snippets/claude", (r, w) => {
    self.config.handle_set_common_config_snippet(r, w, "claude")
  })
  router.add_handler(Get, "/config/snippets", (r, w) => {
    self.config.handle_get_common_config_snippet_request(r, w)
  })
  router.add_handler(Post, "/config/snippets", (r, w) => {
    self.config.handle_set_common_config_snippet_request(r, w)
  })
  router.add_handler(Get, "/config/snippets/extract", (r, w) => {
    self.config.handle_extract_common_config_snippet(r, w)
  })
  router.add_handler(Post, "/config/snippets/extract", (r, w) => {
    self.config.handle_extract_common_config_snippet(r, w)
  })
  router.add_handler(Get, "/config/env/conflicts", (r, w) => {
    self.config.handle_check_env_conflicts(r, w)
  })
  router.add_handler(Post, "/config/env/conflicts", (r, w) => {
    self.config.handle_check_env_conflicts(r, w)
  })
  router.add_handler(Post, "/config/env/delete", (r, w) => {
    self.config.handle_delete_env_vars(r, w)
  })
  router.add_handler(Post, "/config/env/restore", (r, w) => {
    self.config.handle_restore_env_backup(r, w)
  })
  router.add_handler(Get, "/mcp/claude/status", (_, w) => {
    self.config.handle_get_claude_mcp_status(w)
  })
  router.add_handler(Get, "/mcp/claude/config", (_, w) => {
    self.config.handle_read_claude_mcp_config(w)
  })
  router.add_handler(Post, "/mcp/claude/servers", (r, w) => {
    self.config.handle_upsert_claude_mcp_server(r, w)
  })
  router.add_handler(Delete, "/mcp/claude/servers", (r, w) => {
    self.config.handle_delete_mcp_server(r, w)
  })
  router.add_handler(Get, "/mcp/validate", (r, w) => {
    self.config.handle_validate_mcp_command(r, w)
  })
  router.add_handler(Post, "/mcp/validate", (r, w) => {
    self.config.handle_validate_mcp_command(r, w)
  })
  router.add_handler(Get, "/mcp/config", (r, w) => {
    self.config.handle_get_mcp_config(r, w)
  })
  router.add_handler(Post, "/mcp/config", (r, w) => {
    self.config.handle_get_mcp_config(r, w)
  })
  router.add_handler(Post, "/mcp/config/servers", (r, w) => {
    self.config.handle_upsert_mcp_server_in_config(r, w)
  })
  router.add_handler(Delete, "/mcp/config/servers", (r, w) => {
    self.config.handle_delete_mcp_server(r, w)
  })
  router.add_handler(Post, "/mcp/enabled", (r, w) => {
    self.config.handle_set_mcp_enabled(r, w)
  })
  router.add_handler(Get, "/mcp/servers", (_, w) => {
    self.config.handle_get_mcp_servers(w)
  })
  router.add_handler(Post, "/mcp/servers", (r, w) => {
    self.config.handle_upsert_mcp_server(r, w)
  })
  router.add_handler(Delete, "/mcp/servers", (r, w) => {
    self.config.handle_delete_mcp_server(r, w)
  })
  router.add_handler(Post, "/mcp/apps/toggle", (r, w) => {
    self.config.handle_toggle_mcp_app(r, w)
  })
  router.add_handler(Post, "/mcp/import-apps", (_, w) => {
    self.config.handle_import_mcp_from_apps(w)
  })
  router.add_handler(Get, "/prompts", (r, w) => {
    self.config.handle_get_prompts(r, w)
  })
  router.add_handler(Post, "/prompts", (r, w) => {
    self.config.handle_upsert_prompt(r, w)
  })
  router.add_handler(Delete, "/prompts", (r, w) => {
    self.config.handle_delete_prompt(r, w)
  })
  router.add_handler(Post, "/prompts/enable", (r, w) => {
    self.config.handle_enable_prompt(r, w)
  })
  router.add_handler(Post, "/prompts/import-file", (r, w) => {
    self.workspace.handle_import_prompt_from_file(self.config, r, w)
  })
  router.add_handler(Get, "/prompts/current-file", (r, w) => {
    self.workspace.handle_get_current_prompt_file_content(r, w)
  })
  self.proxy.register_management_routes(
    router,
    self.usage,
    self.host,
    self.port,
    self.started_at_ms,
    self.runtime.uptime_seconds(self.started_at_ms),
    self.config.stream_check_config,
  )
  router.add_handler(Get, "/settings", (_, w) => {
    self.config.handle_get_settings(w)
  })
  router.add_handler(Post, "/settings", (r, w) => {
    self.config.handle_save_settings(r, w)
  })
  router.add_handler(Post, "/runtime/restart", (_, w) => {
    self.runtime.handle_restart_app(w)
  })
  router.add_handler(Post, "/runtime/updates/install-restart", (_, w) => {
    self.runtime.handle_install_update_and_restart(w)
  })
  router.add_handler(Get, "/settings/app-config-dir", (_, w) => {
    self.config.handle_get_app_config_dir_override(w)
  })
  router.add_handler(Post, "/settings/app-config-dir", (r, w) => {
    self.config.handle_set_app_config_dir_override(r, w)
  })
  router.add_handler(Post, "/settings/auto-launch", (r, w) => {
    self.config.handle_set_auto_launch(r, w)
  })
  router.add_handler(Get, "/settings/auto-launch", (_, w) => {
    self.config.handle_get_auto_launch_status(w)
  })
  router.add_handler(Get, "/settings/rectifier", (_, w) => {
    self.config.handle_get_rectifier_config(w)
  })
  router.add_handler(Post, "/settings/rectifier", (r, w) => {
    self.config.handle_set_rectifier_config(r, w)
  })
  router.add_handler(Get, "/settings/optimizer", (_, w) => {
    self.config.handle_get_optimizer_config(w)
  })
  router.add_handler(Post, "/settings/optimizer", (r, w) => {
    self.config.handle_set_optimizer_config(r, w)
  })
  router.add_handler(Get, "/settings/copilot-optimizer", (_, w) => {
    self.config.handle_get_copilot_optimizer_config(w)
  })
  router.add_handler(Post, "/settings/copilot-optimizer", (r, w) => {
    self.config.handle_set_copilot_optimizer_config(r, w)
  })
  router.add_handler(Get, "/settings/log", (_, w) => {
    self.config.handle_get_log_config(w)
  })
  router.add_handler(Post, "/settings/log", (r, w) => {
    self.config.handle_set_log_config(r, w)
  })
  router.add_handler(Get, "/plugin/claude/status", (_, w) => {
    self.config.handle_get_claude_plugin_status(w)
  })
  router.add_handler(Get, "/plugin/claude/config", (_, w) => {
    self.config.handle_read_claude_plugin_config(w)
  })
  router.add_handler(Post, "/plugin/claude/config", (r, w) => {
    self.config.handle_apply_claude_plugin_config(r, w)
  })
  router.add_handler(Get, "/plugin/claude/applied", (_, w) => {
    self.config.handle_is_claude_plugin_applied(w)
  })
  router.add_handler(Post, "/plugin/claude/onboarding-skip", (_, w) => {
    self.config.handle_apply_claude_onboarding_skip(w)
  })
  router.add_handler(Post, "/plugin/claude/onboarding-skip/clear", (_, w) => {
    self.config.handle_clear_claude_onboarding_skip(w)
  })
  router.add_handler(Get, "/workspace/memory", (_, w) => {
    self.workspace.handle_list_daily_memory_files(w)
  })
  router.add_handler(Get, "/workspace/memory/file", (r, w) => {
    self.workspace.handle_read_daily_memory_file(r, w)
  })
  router.add_handler(Post, "/workspace/memory/file", (r, w) => {
    self.workspace.handle_read_daily_memory_file(r, w)
  })
  router.add_handler(Post, "/workspace/memory/write", (r, w) => {
    self.workspace.handle_write_daily_memory_file(r, w)
  })
  router.add_handler(Get, "/workspace/memory/search", (r, w) => {
    self.workspace.handle_search_daily_memory_files(r, w)
  })
  router.add_handler(Post, "/workspace/memory/search", (r, w) => {
    self.workspace.handle_search_daily_memory_files(r, w)
  })
  router.add_handler(Delete, "/workspace/memory/file", (r, w) => {
    self.workspace.handle_delete_daily_memory_file(r, w)
  })
  router.add_handler(Post, "/workspace/memory/delete", (r, w) => {
    self.workspace.handle_delete_daily_memory_file(r, w)
  })
  router.add_handler(Get, "/workspace/files", (r, w) => {
    self.workspace.handle_read_workspace_file(r, w)
  })
  router.add_handler(Post, "/workspace/files/read", (r, w) => {
    self.workspace.handle_read_workspace_file(r, w)
  })
  router.add_handler(Post, "/workspace/files", (r, w) => {
    self.workspace.handle_write_workspace_file(r, w)
  })
  router.add_handler(Get, "/workspace/open", (r, w) => {
    self.workspace.handle_open_workspace_directory(r, w)
  })
  router.add_handler(Post, "/workspace/open", (r, w) => {
    self.workspace.handle_open_workspace_directory(r, w)
  })
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
  router.add_handler(Get, "/sessions", (_, w) => {
    self.session.handle_list_sessions(w)
  })
  router.add_handler(Post, "/sessions", (_, w) => {
    self.session.handle_list_sessions(w)
  })
  router.add_handler(Get, "/sessions/messages", (r, w) => {
    self.session.handle_get_session_messages(r, w)
  })
  router.add_handler(Post, "/sessions/messages", (r, w) => {
    self.session.handle_get_session_messages(r, w)
  })
  router.add_handler(Post, "/sessions/terminal", (r, w) => {
    self.session.handle_launch_session_terminal(
      r,
      w,
      moon_session_terminal_from_settings(self.config.app_settings),
    )
  })
  router.add_handler(Post, "/sessions/delete", (r, w) => {
    self.session.handle_delete_session(r, w)
  })
  router.add_handler(Post, "/sessions/delete-many", (r, w) => {
    self.session.handle_delete_sessions(r, w)
  })
  router.add_handler(Get, "/proxy/stream-check/config", (_, w) => {
    self.config.handle_get_stream_check_config(w)
  })
  router.add_handler(Post, "/proxy/stream-check/config", (r, w) => {
    self.config.handle_save_stream_check_config(r, w)
  })
  router.add_handler(Get, "/config/models", (r, w) => {
    self.config.handle_fetch_models_for_config(r, w)
  })
  router.add_handler(Post, "/config/models", (r, w) => {
    self.config.handle_fetch_models_for_config(r, w)
  })
  self.auth.register_routes(router, self.logger)
  router.set_not_found_handler(file_server.handler())
  let server = @httpx.Server::new(self.host, self.port, reuse_addr=true)
  self.logger.info("Gateway started on \{self.host}:\{server.port()}")
  server.serve(router.handler())
}
