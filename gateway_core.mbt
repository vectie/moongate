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
  router.add_handler(Post, "/v1/messages", (r, w) => self.handle_messages(r, w))
  router.add_handler(Post, "/claude-desktop/v1/messages", (r, w) => {
    self.handle_messages(r, w)
  })
  for method_ in @httpx.methods {
    router.add_handler(method_, "/v1beta/*path", (r, w) => {
      self.proxy.handle_gemini(self.usage, r, w)
    })
    router.add_handler(method_, "/gemini/v1beta/*path", (r, w) => {
      self.proxy.handle_gemini(self.usage, r, w)
    })
    router.add_handler(method_, "/gemini/v1/*path", (r, w) => {
      self.proxy.handle_gemini(self.usage, r, w)
    })
  }
  router.add_handler(Post, "/chat/completions", (r, w) => {
    self.proxy.handle_chat_completions(
      self.auth,
      self.usage,
      self.session,
      self.model,
      r,
      w,
    )
  })
  router.add_handler(Post, "/v1/chat/completions", (r, w) => {
    self.proxy.handle_chat_completions(
      self.auth,
      self.usage,
      self.session,
      self.model,
      r,
      w,
    )
  })
  router.add_handler(Post, "/openclaw/v1/chat/completions", (r, w) => {
    self.proxy.handle_chat_completions(
      self.auth,
      self.usage,
      self.session,
      self.model,
      r,
      w,
      app_type="openclaw",
    )
  })
  router.add_handler(Post, "/responses", (r, w) => {
    self.proxy.handle_codex_responses(
      self.auth,
      self.usage,
      self.session,
      self.model,
      r,
      w,
    )
  })
  router.add_handler(Post, "/v1/responses", (r, w) => {
    self.proxy.handle_codex_responses(
      self.auth,
      self.usage,
      self.session,
      self.model,
      r,
      w,
    )
  })
  router.add_handler(Post, "/responses/compact", (r, w) => {
    self.proxy.handle_codex_responses(
      self.auth,
      self.usage,
      self.session,
      self.model,
      r,
      w,
      compact=true,
    )
  })
  router.add_handler(Post, "/v1/responses/compact", (r, w) => {
    self.proxy.handle_codex_responses(
      self.auth,
      self.usage,
      self.session,
      self.model,
      r,
      w,
      compact=true,
    )
  })
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
  router.add_handler(Get, "/proxy/status", (_, w) => {
    self.proxy.handle_proxy_status(
      w,
      self.usage,
      self.host,
      self.port,
      self.runtime.uptime_seconds(self.started_at_ms),
    )
  })
  router.add_handler(Post, "/proxy/start", (_, w) => {
    self.proxy.handle_proxy_start_server(w, self.started_at_ms)
  })
  router.add_handler(Post, "/proxy/stop", (_, w) => {
    self.proxy.handle_proxy_stop_server(w)
  })
  router.add_handler(Post, "/proxy/stop-with-restore", (_, w) => {
    self.proxy.handle_proxy_stop_with_restore(w)
  })
  router.add_handler(Get, "/proxy/config", (_, w) => {
    self.proxy.handle_proxy_config(
      w,
      live_takeover_active=self.proxy.takeover_active(),
    )
  })
  router.add_handler(Post, "/proxy/config", (r, w) => {
    self.proxy.handle_proxy_update_config(r, w)
  })
  router.add_handler(Get, "/proxy/global-config", (_, w) => {
    self.proxy.handle_proxy_global_config(w)
  })
  router.add_handler(Post, "/proxy/global-config", (r, w) => {
    self.proxy.handle_proxy_update_global_config(r, w)
  })
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
  router.add_handler(Get, "/proxy/global-url", (_, w) => {
    self.proxy.handle_get_global_proxy_url(w)
  })
  router.add_handler(Post, "/proxy/global-url", (r, w) => {
    self.proxy.handle_set_global_proxy_url(r, w)
  })
  router.add_handler(Get, "/proxy/test-url", (r, w) => {
    self.proxy.handle_test_proxy_url(r, w)
  })
  router.add_handler(Post, "/proxy/test-url", (r, w) => {
    self.proxy.handle_test_proxy_url(r, w)
  })
  router.add_handler(Get, "/proxy/upstream-status", (_, w) => {
    self.proxy.handle_get_upstream_proxy_status(w)
  })
  router.add_handler(Get, "/proxy/local-proxies", (_, w) => {
    self.proxy.handle_scan_local_proxies(w)
  })
  router.add_handler(Get, "/proxy/app-config", (r, w) => {
    self.proxy.handle_proxy_app_config(r, w)
  })
  router.add_handler(Post, "/proxy/app-config", (r, w) => {
    self.proxy.handle_proxy_update_app_config(r, w)
  })
  router.add_handler(Get, "/proxy/default-cost-multiplier", (r, w) => {
    self.proxy.handle_proxy_default_cost_multiplier(r, w)
  })
  router.add_handler(Post, "/proxy/default-cost-multiplier", (r, w) => {
    self.proxy.handle_proxy_set_default_cost_multiplier(r, w)
  })
  router.add_handler(Get, "/proxy/pricing-model-source", (r, w) => {
    self.proxy.handle_proxy_pricing_model_source(r, w)
  })
  router.add_handler(Post, "/proxy/pricing-model-source", (r, w) => {
    self.proxy.handle_proxy_set_pricing_model_source(r, w)
  })
  router.add_handler(Get, "/proxy/provider-health", (r, w) => {
    self.proxy.handle_proxy_provider_health(r, w)
  })
  router.add_handler(Get, "/proxy/circuit-breaker-config", (_, w) => {
    self.proxy.handle_proxy_circuit_breaker_config(w)
  })
  router.add_handler(Post, "/proxy/circuit-breaker-config", (r, w) => {
    self.proxy.handle_proxy_update_circuit_breaker_config(r, w)
  })
  router.add_handler(Get, "/proxy/circuit-breaker-stats", (r, w) => {
    self.proxy.handle_proxy_circuit_breaker_stats(r, w)
  })
  router.add_handler(Post, "/proxy/reset-circuit-breaker", (r, w) => {
    self.proxy.handle_proxy_reset_circuit_breaker(r, w)
  })
  router.add_handler(Get, "/proxy/failover-queue", (r, w) => {
    self.proxy.handle_proxy_failover_queue(r, w)
  })
  router.add_handler(Post, "/proxy/failover-queue", (r, w) => {
    self.proxy.handle_proxy_add_failover_queue(r, w)
  })
  router.add_handler(Delete, "/proxy/failover-queue", (r, w) => {
    self.proxy.handle_proxy_remove_failover_queue(r, w)
  })
  router.add_handler(Get, "/proxy/available-failover-providers", (r, w) => {
    self.proxy.handle_proxy_available_failover_providers(r, w)
  })
  router.add_handler(Get, "/proxy/auto-failover-enabled", (r, w) => {
    self.proxy.handle_proxy_auto_failover_enabled(r, w)
  })
  router.add_handler(Post, "/proxy/auto-failover-enabled", (r, w) => {
    self.proxy.handle_proxy_set_auto_failover_enabled(r, w)
  })
  router.add_handler(Get, "/proxy/takeover-status", (_, w) => {
    self.proxy.handle_proxy_takeover_status(w)
  })
  router.add_handler(Post, "/proxy/takeover-status", (r, w) => {
    self.proxy.handle_proxy_set_takeover_for_app(r, w)
  })
  router.add_handler(Post, "/proxy/switch-provider", (r, w) => {
    self.proxy.handle_proxy_switch_provider(self.usage, r, w)
  })
  router.add_handler(Post, "/proxy/sync-current-providers-live", (_, w) => {
    self.proxy.handle_sync_current_providers_live(self.usage, w)
  })
  router.add_handler(Post, "/proxy/import-default-config", (r, w) => {
    self.proxy.handle_import_default_config(r, w)
  })
  router.add_handler(Get, "/providers", (r, w) => {
    self.proxy.handle_get_providers(r, w)
  })
  router.add_handler(Get, "/providers/current", (r, w) => {
    self.proxy.handle_get_current_provider(r, w)
  })
  router.add_handler(Post, "/providers/current", (r, w) => {
    self.proxy.handle_get_current_provider(r, w)
  })
  router.add_handler(Post, "/providers", (r, w) => {
    self.proxy.handle_add_provider(r, w, self.usage)
  })
  router.add_handler(Post, "/providers/update", (r, w) => {
    self.proxy.handle_update_provider(r, w, self.usage)
  })
  router.add_handler(Delete, "/providers", (r, w) => {
    self.proxy.handle_delete_provider(r, w)
  })
  router.add_handler(Post, "/providers/delete", (r, w) => {
    self.proxy.handle_delete_provider(r, w)
  })
  router.add_handler(Delete, "/providers/live", (r, w) => {
    self.proxy.handle_remove_provider_from_live_config(r, w)
  })
  router.add_handler(Post, "/providers/live/remove", (r, w) => {
    self.proxy.handle_remove_provider_from_live_config(r, w)
  })
  router.add_handler(Post, "/providers/switch", (r, w) => {
    self.proxy.handle_switch_provider(r, w, self.usage)
  })
  router.add_handler(Post, "/providers/terminal", (r, w) => {
    self.proxy.handle_open_provider_terminal(r, w)
  })
  router.add_handler(Get, "/providers/claude-desktop/status", (_, w) => {
    self.proxy.handle_get_claude_desktop_status(self.host, self.port, w)
  })
  router.add_handler(Get, "/providers/claude-desktop/default-routes", (_, w) => {
    self.proxy.handle_get_claude_desktop_default_routes(w)
  })
  router.add_handler(Post, "/providers/claude-desktop/import", (_, w) => {
    self.proxy.handle_import_claude_desktop_providers_from_claude(w)
  })
  router.add_handler(Post, "/providers/claude-desktop/official", (_, w) => {
    self.proxy.handle_ensure_claude_desktop_official_provider(w)
  })
  router.add_handler(Get, "/providers/live-settings", (r, w) => {
    self.proxy.handle_read_live_provider_settings(r, w)
  })
  router.add_handler(Post, "/providers/live-settings", (r, w) => {
    self.proxy.handle_read_live_provider_settings(r, w)
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
  router.add_handler(Get, "/providers/live-ids", (r, w) => {
    self.proxy.handle_get_live_provider_ids(
      w,
      usage_query_value(r.path, "app").unwrap_or("opencode"),
    )
  })
  router.add_handler(Get, "/providers/live-provider", (r, w) => {
    self.proxy.handle_get_live_provider(
      r,
      w,
      usage_query_value(r.path, "app").unwrap_or("openclaw"),
    )
  })
  router.add_handler(Post, "/providers/live-provider", (r, w) => {
    self.proxy.handle_get_live_provider(
      r,
      w,
      usage_query_value(r.path, "app").unwrap_or("openclaw"),
    )
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
  router.add_handler(Post, "/providers/import-live", (r, w) => {
    self.proxy.handle_import_live_providers(
      w,
      usage_query_value(r.path, "app").unwrap_or("opencode"),
    )
  })
  router.add_handler(Get, "/providers/universal", (_, w) => {
    self.proxy.handle_get_universal_providers(w)
  })
  router.add_handler(Get, "/providers/universal/item", (r, w) => {
    self.proxy.handle_get_universal_provider(r, w)
  })
  router.add_handler(Post, "/providers/universal", (r, w) => {
    self.proxy.handle_upsert_universal_provider(r, w)
  })
  router.add_handler(Delete, "/providers/universal", (r, w) => {
    self.proxy.handle_delete_universal_provider(r, w)
  })
  router.add_handler(Post, "/providers/universal/delete", (r, w) => {
    self.proxy.handle_delete_universal_provider(r, w)
  })
  router.add_handler(Post, "/providers/universal/sync", (r, w) => {
    self.proxy.handle_sync_universal_provider(r, w)
  })
  router.add_handler(Get, "/providers/presets", (r, w) => {
    self.proxy.handle_get_provider_presets(r, w)
  })
  router.add_handler(Post, "/providers/test-endpoints", (r, w) => {
    self.proxy.handle_test_api_endpoints(r, w)
  })
  router.add_handler(Get, "/providers/test-endpoints", (r, w) => {
    self.proxy.handle_test_api_endpoints(r, w)
  })
  router.add_handler(Post, "/providers/sort-order", (r, w) => {
    self.proxy.handle_update_providers_sort_order(r, w)
  })
  router.add_handler(Get, "/providers/endpoints/list", (r, w) => {
    self.proxy.handle_get_custom_endpoints(r, w)
  })
  router.add_handler(Post, "/providers/endpoints/list", (r, w) => {
    self.proxy.handle_get_custom_endpoints(r, w)
  })
  router.add_handler(Post, "/providers/endpoints", (r, w) => {
    self.proxy.handle_add_custom_endpoint(r, w)
  })
  router.add_handler(Delete, "/providers/endpoints", (r, w) => {
    self.proxy.handle_remove_custom_endpoint(r, w)
  })
  router.add_handler(Post, "/providers/endpoints/remove", (r, w) => {
    self.proxy.handle_remove_custom_endpoint(r, w)
  })
  router.add_handler(Post, "/providers/endpoints/touch", (r, w) => {
    self.proxy.handle_update_endpoint_last_used(r, w)
  })
  router.add_handler(Get, "/proxy/running", (_, w) => {
    self.proxy.handle_proxy_running(w)
  })
  router.add_handler(Get, "/usage/logs", (r, w) => {
    self.usage.handle_usage_logs(r, w, self.usage.pricing_override_rows())
  })
  router.add_handler(Post, "/usage/logs", (r, w) => {
    self.usage.handle_usage_logs(r, w, self.usage.pricing_override_rows())
  })
  router.add_handler(Get, "/usage/summary", (r, w) => {
    self.usage.handle_usage_summary(r, w)
  })
  router.add_handler(Post, "/usage/summary", (r, w) => {
    self.usage.handle_usage_summary(r, w)
  })
  router.add_handler(Get, "/usage/summary/by-app", (r, w) => {
    self.usage.handle_usage_summary_by_app(r, w)
  })
  router.add_handler(Post, "/usage/summary/by-app", (r, w) => {
    self.usage.handle_usage_summary_by_app(r, w)
  })
  router.add_handler(Get, "/usage/trends", (r, w) => {
    self.usage.handle_usage_trends(r, w)
  })
  router.add_handler(Post, "/usage/trends", (r, w) => {
    self.usage.handle_usage_trends(r, w)
  })
  router.add_handler(Get, "/usage/provider-limits", (r, w) => {
    self.usage.handle_usage_provider_limits(r, w, self.proxy.provider_router)
  })
  router.add_handler(Post, "/usage/provider-limits", (r, w) => {
    self.usage.handle_usage_provider_limits(r, w, self.proxy.provider_router)
  })
  router.add_handler(Get, "/usage/provider-stats", (r, w) => {
    self.usage.handle_usage_provider_stats(r, w)
  })
  router.add_handler(Post, "/usage/provider-stats", (r, w) => {
    self.usage.handle_usage_provider_stats(r, w)
  })
  router.add_handler(Get, "/usage/model-stats", (r, w) => {
    self.usage.handle_usage_model_stats(r, w)
  })
  router.add_handler(Post, "/usage/model-stats", (r, w) => {
    self.usage.handle_usage_model_stats(r, w)
  })
  router.add_handler(Get, "/usage/data-sources", (_, w) => {
    self.usage.handle_usage_data_sources(w)
  })
  router.add_handler(Post, "/usage/data-sources", (_, w) => {
    self.usage.handle_usage_data_sources(w)
  })
  router.add_handler(Get, "/usage/provider-usage", (r, w) => {
    self.usage.handle_query_provider_usage(r, w, self.proxy.provider_router)
  })
  router.add_handler(Post, "/usage/provider-usage", (r, w) => {
    self.usage.handle_query_provider_usage(r, w, self.proxy.provider_router)
  })
  router.add_handler(Get, "/usage/balance", (r, w) => {
    self.usage.handle_get_balance(r, w)
  })
  router.add_handler(Post, "/usage/balance", (r, w) => {
    self.usage.handle_get_balance(r, w)
  })
  router.add_handler(Get, "/usage/subscription-quota", (r, w) => {
    self.usage.handle_get_subscription_quota(r, w)
  })
  router.add_handler(Post, "/usage/subscription-quota", (r, w) => {
    self.usage.handle_get_subscription_quota(r, w)
  })
  router.add_handler(Get, "/usage/codex-oauth-quota", (r, w) => {
    self.auth.handle_get_codex_oauth_quota(r, w, self.usage)
  })
  router.add_handler(Post, "/usage/codex-oauth-quota", (r, w) => {
    self.auth.handle_get_codex_oauth_quota(r, w, self.usage)
  })
  router.add_handler(Get, "/usage/codex-oauth-models", (r, w) => {
    self.auth.handle_get_codex_oauth_models(r, w)
  })
  router.add_handler(Post, "/usage/codex-oauth-models", (r, w) => {
    self.auth.handle_get_codex_oauth_models(r, w)
  })
  router.add_handler(Get, "/usage/coding-plan-quota", (r, w) => {
    self.usage.handle_get_coding_plan_quota(r, w)
  })
  router.add_handler(Post, "/usage/coding-plan-quota", (r, w) => {
    self.usage.handle_get_coding_plan_quota(r, w)
  })
  router.add_handler(Post, "/usage/test-script", (r, w) => {
    self.usage.handle_test_usage_script(r, w)
  })
  router.add_handler(Post, "/usage/sync-session", (r, w) => {
    self.usage.handle_usage_sync_session(r, w)
  })
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
  router.add_handler(Get, "/usage/model-pricing", (_, w) => {
    self.usage.handle_usage_model_pricing(w)
  })
  router.add_handler(Post, "/usage/model-pricing", (r, w) => {
    self.usage.handle_usage_update_model_pricing(r, w)
  })
  router.add_handler(Delete, "/usage/model-pricing", (r, w) => {
    self.usage.handle_usage_delete_model_pricing(r, w)
  })
  router.add_handler(Get, "/usage/request-detail/*path", (r, w) => {
    self.usage.handle_usage_request_detail(
      r,
      w,
      self.usage.pricing_override_rows(),
    )
  })
  router.add_handler(Post, "/proxy/stream-check/provider", (r, w) => {
    self.proxy.handle_stream_check_provider(
      self.config.stream_check_config,
      r,
      w,
    )
  })
  router.add_handler(Get, "/proxy/stream-check/provider", (r, w) => {
    self.proxy.handle_stream_check_provider(
      self.config.stream_check_config,
      r,
      w,
    )
  })
  router.add_handler(Post, "/proxy/stream-check/all", (r, w) => {
    self.proxy.handle_stream_check_all_providers(
      self.config.stream_check_config,
      r,
      w,
    )
  })
  router.add_handler(Get, "/proxy/stream-check/all", (r, w) => {
    self.proxy.handle_stream_check_all_providers(
      self.config.stream_check_config,
      r,
      w,
    )
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
  router.add_handler(Get, "/auth/login", (r, w) => {
    self.auth.handle_auth_start_login(r, w)
  })
  router.add_handler(Post, "/auth/login", (r, w) => {
    self.auth.handle_auth_start_login(r, w)
  })
  router.add_handler(Get, "/auth/poll", (r, w) => {
    self.auth.handle_auth_poll_for_account(r, w)
  })
  router.add_handler(Post, "/auth/poll", (r, w) => {
    self.auth.handle_auth_poll_for_account(r, w)
  })
  router.add_handler(Get, "/auth/accounts", (r, w) => {
    self.auth.handle_auth_list_accounts(r, w)
  })
  router.add_handler(Post, "/auth/accounts", (r, w) => {
    self.auth.handle_auth_list_accounts(r, w)
  })
  router.add_handler(Get, "/auth/status", (r, w) => {
    self.auth.handle_auth_get_status(r, w)
  })
  router.add_handler(Post, "/auth/status", (r, w) => {
    self.auth.handle_auth_get_status(r, w)
  })
  router.add_handler(Delete, "/auth/account", (r, w) => {
    self.auth.handle_auth_remove_account(r, w)
  })
  router.add_handler(Post, "/auth/account", (r, w) => {
    self.auth.handle_auth_remove_account(r, w)
  })
  router.add_handler(Post, "/auth/default-account", (r, w) => {
    self.auth.handle_auth_set_default_account(r, w)
  })
  router.add_handler(Get, "/auth/default-account", (r, w) => {
    self.auth.handle_auth_set_default_account(r, w)
  })
  router.add_handler(Post, "/auth/logout", (r, w) => {
    self.auth.handle_auth_logout(r, w)
  })
  router.add_handler(Get, "/auth/logout", (r, w) => {
    self.auth.handle_auth_logout(r, w)
  })
  router.add_handler(Get, "/copilot/device-flow", (r, w) => {
    self.auth.handle_copilot_start_device_flow(r, w)
  })
  router.add_handler(Post, "/copilot/device-flow", (r, w) => {
    self.auth.handle_copilot_start_device_flow(r, w)
  })
  router.add_handler(Get, "/copilot/poll-auth", (r, w) => {
    self.auth.handle_copilot_poll_for_auth(r, w)
  })
  router.add_handler(Post, "/copilot/poll-auth", (r, w) => {
    self.auth.handle_copilot_poll_for_auth(r, w)
  })
  router.add_handler(Get, "/copilot/poll-account", (r, w) => {
    self.auth.handle_copilot_poll_for_account(r, w)
  })
  router.add_handler(Post, "/copilot/poll-account", (r, w) => {
    self.auth.handle_copilot_poll_for_account(r, w)
  })
  router.add_handler(Get, "/copilot/accounts", (_, w) => {
    self.auth.handle_copilot_list_accounts(w)
  })
  router.add_handler(Get, "/copilot/status", (_, w) => {
    self.auth.handle_copilot_get_auth_status(w)
  })
  router.add_handler(Get, "/copilot/authenticated", (_, w) => {
    self.auth.handle_copilot_is_authenticated(w)
  })
  router.add_handler(Post, "/copilot/logout", (_, w) => {
    self.auth.handle_copilot_logout(w)
  })
  router.add_handler(Get, "/copilot/logout", (_, w) => {
    self.auth.handle_copilot_logout(w)
  })
  router.add_handler(Delete, "/copilot/account", (r, w) => {
    self.auth.handle_copilot_remove_account(r, w)
  })
  router.add_handler(Post, "/copilot/account", (r, w) => {
    self.auth.handle_copilot_remove_account(r, w)
  })
  router.add_handler(Get, "/copilot/default-account", (r, w) => {
    self.auth.handle_copilot_set_default_account(r, w)
  })
  router.add_handler(Post, "/copilot/default-account", (r, w) => {
    self.auth.handle_copilot_set_default_account(r, w)
  })
  router.add_handler(Get, "/copilot/token", (r, w) => {
    self.auth.handle_copilot_get_token(r, w)
  })
  router.add_handler(Get, "/copilot/models", (r, w) => {
    self.auth.handle_copilot_get_models(r, w)
  })
  router.add_handler(Get, "/copilot/usage", (r, w) => {
    self.auth.handle_copilot_get_usage(r, w)
  })
  router.add_handler(Get, "/models", (_, w) => self.proxy.handle_models(w))
  router.add_handler(Get, "/v1/models", (_, w) => self.proxy.handle_models(w))
  router.add_handler(Get, "/claude-desktop/v1/models", (r, w) => {
    self.proxy.handle_claude_desktop_models(self.auth, self.usage, r, w)
  })
  router.add_handler(Post, "/login", (r, w) => {
    self.auth.handle_login(r, w, self.logger)
  })
  router.set_not_found_handler(file_server.handler())
  let server = @httpx.Server::new(self.host, self.port, reuse_addr=true)
  self.logger.info("Gateway started on \{self.host}:\{server.port()}")
  server.serve(router.handler())
}
