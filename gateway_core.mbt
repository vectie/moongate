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
  router.add_handler(Post, "/claude/v1/messages", (r, w) => {
    self.handle_messages(r, w)
  })
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
    self.handle_chat_completions(r, w)
  })
  router.add_handler(Post, "/v1/chat/completions", (r, w) => {
    self.handle_chat_completions(r, w)
  })
  router.add_handler(Post, "/v1/v1/chat/completions", (r, w) => {
    self.handle_chat_completions(r, w)
  })
  router.add_handler(Post, "/codex/v1/chat/completions", (r, w) => {
    self.handle_chat_completions(r, w)
  })
  router.add_handler(Post, "/openclaw/v1/chat/completions", (r, w) => {
    self.handle_chat_completions(r, w, app_type="openclaw")
  })
  router.add_handler(Post, "/responses", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(Post, "/v1/responses", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(Post, "/v1/v1/responses", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(Post, "/codex/v1/responses", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(Post, "/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w, compact=true)
  })
  router.add_handler(Post, "/v1/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w, compact=true)
  })
  router.add_handler(Post, "/v1/v1/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w, compact=true)
  })
  router.add_handler(Post, "/codex/v1/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w, compact=true)
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
  router.add_handler(Get, "/get_claude_config_status", (_, w) => {
    self.config.handle_get_config_status(w, "claude")
  })
  router.add_handler(Get, "/get_config_status", (r, w) => {
    self.config.handle_get_config_status_request(r, w)
  })
  router.add_handler(Post, "/get_config_status", (r, w) => {
    self.config.handle_get_config_status_request(r, w)
  })
  router.add_handler(Get, "/get_claude_code_config_path", (_, w) => {
    self.config.handle_get_claude_code_config_path(w)
  })
  router.add_handler(Get, "/get_config_dir", (r, w) => {
    self.config.handle_get_config_dir(r, w)
  })
  router.add_handler(Post, "/get_config_dir", (r, w) => {
    self.config.handle_get_config_dir(r, w)
  })
  router.add_handler(Get, "/open_config_folder", (r, w) => {
    self.config.handle_open_config_folder(r, w)
  })
  router.add_handler(Post, "/open_config_folder", (r, w) => {
    self.config.handle_open_config_folder(r, w)
  })
  router.add_handler(Get, "/pick_directory", (r, w) => {
    self.runtime.handle_pick_directory(r, w)
  })
  router.add_handler(Post, "/pick_directory", (r, w) => {
    self.runtime.handle_pick_directory(r, w)
  })
  router.add_handler(Get, "/open_external", (r, w) => {
    self.proxy.handle_open_external(r, w)
  })
  router.add_handler(Post, "/open_external", (r, w) => {
    self.proxy.handle_open_external(r, w)
  })
  router.add_handler(Post, "/copy_text_to_clipboard", (r, w) => {
    self.runtime.handle_copy_text_to_clipboard(r, w)
  })
  router.add_handler(Get, "/copy_text_to_clipboard", (r, w) => {
    self.runtime.handle_copy_text_to_clipboard(r, w)
  })
  router.add_handler(Post, "/check_for_updates", (_, w) => {
    self.proxy.handle_check_for_updates(w)
  })
  router.add_handler(Get, "/check_for_updates", (_, w) => {
    self.proxy.handle_check_for_updates(w)
  })
  router.add_handler(Post, "/update_tray_menu", (_, w) => {
    self.runtime.handle_update_tray_menu(w)
  })
  router.add_handler(Get, "/update_tray_menu", (_, w) => {
    self.runtime.handle_update_tray_menu(w)
  })
  router.add_handler(Get, "/is_portable_mode", (_, w) => {
    self.runtime.handle_is_portable_mode(w)
  })
  router.add_handler(Get, "/get_init_error", (_, w) => {
    self.runtime.handle_get_init_error(w)
  })
  router.add_handler(Get, "/get_migration_result", (_, w) => {
    self.runtime.handle_get_migration_result(w)
  })
  router.add_handler(Get, "/get_skills_migration_result", (_, w) => {
    self.runtime.handle_get_skills_migration_result(w)
  })
  router.add_handler(Get, "/get_tool_versions", (r, w) => {
    self.runtime.handle_get_tool_versions(r, w)
  })
  router.add_handler(Post, "/get_tool_versions", (r, w) => {
    self.runtime.handle_get_tool_versions(r, w)
  })
  router.add_handler(Post, "/run_tool_lifecycle_action", (r, w) => {
    self.runtime.handle_run_tool_lifecycle_action(r, w)
  })
  router.add_handler(Get, "/probe_tool_installations", (r, w) => {
    self.runtime.handle_probe_tool_installations(r, w)
  })
  router.add_handler(Post, "/probe_tool_installations", (r, w) => {
    self.runtime.handle_probe_tool_installations(r, w)
  })
  router.add_handler(Post, "/set_window_theme", (r, w) => {
    self.config.handle_set_window_theme(r, w)
  })
  router.add_handler(Get, "/set_window_theme", (r, w) => {
    self.config.handle_set_window_theme(r, w)
  })
  router.add_handler(Post, "/enter_lightweight_mode", (_, w) => {
    self.config.handle_enter_lightweight_mode(w)
  })
  router.add_handler(Get, "/enter_lightweight_mode", (_, w) => {
    self.config.handle_enter_lightweight_mode(w)
  })
  router.add_handler(Post, "/exit_lightweight_mode", (_, w) => {
    self.config.handle_exit_lightweight_mode(w)
  })
  router.add_handler(Get, "/exit_lightweight_mode", (_, w) => {
    self.config.handle_exit_lightweight_mode(w)
  })
  router.add_handler(Get, "/is_lightweight_mode", (_, w) => {
    self.config.handle_is_lightweight_mode(w)
  })
  router.add_handler(Post, "/save_file_dialog", (r, w) => {
    self.workspace.handle_save_file_dialog(r, w)
  })
  router.add_handler(Get, "/save_file_dialog", (r, w) => {
    self.workspace.handle_save_file_dialog(r, w)
  })
  router.add_handler(Post, "/export_config_to_file", (r, w) => {
    self.config.handle_export_config_to_file(
      self.proxy,
      host=self.host,
      port=self.port,
      r,
      w,
    )
  })
  router.add_handler(Get, "/export_config_to_file", (r, w) => {
    self.config.handle_export_config_to_file(
      self.proxy,
      host=self.host,
      port=self.port,
      r,
      w,
    )
  })
  router.add_handler(Post, "/import_config_from_file", (r, w) => {
    self.config.handle_import_config_from_file(
      self.proxy,
      host=self.host,
      port=self.port,
      r,
      w,
    )
  })
  router.add_handler(Get, "/import_config_from_file", (r, w) => {
    self.config.handle_import_config_from_file(
      self.proxy,
      host=self.host,
      port=self.port,
      r,
      w,
    )
  })
  router.add_handler(Post, "/create_db_backup", (_, w) => {
    self.config.handle_create_db_backup(
      self.proxy,
      host=self.host,
      port=self.port,
      w,
    )
  })
  router.add_handler(Get, "/list_db_backups", (_, w) => {
    self.config.handle_list_db_backups(w)
  })
  router.add_handler(Post, "/restore_db_backup", (r, w) => {
    self.config.handle_restore_db_backup(self.proxy, r, w)
  })
  router.add_handler(Post, "/rename_db_backup", (r, w) => {
    self.config.handle_rename_db_backup(r, w)
  })
  router.add_handler(Delete, "/delete_db_backup", (r, w) => {
    self.config.handle_delete_db_backup(r, w)
  })
  router.add_handler(Post, "/delete_db_backup", (r, w) => {
    self.config.handle_delete_db_backup(r, w)
  })
  router.add_handler(Post, "/parse_deeplink", (r, w) => {
    self.config.handle_parse_deeplink(r, w)
  })
  router.add_handler(Get, "/parse_deeplink", (r, w) => {
    self.config.handle_parse_deeplink(r, w)
  })
  router.add_handler(Post, "/merge_deeplink_config", (r, w) => {
    self.config.handle_merge_deeplink_config(r, w)
  })
  router.add_handler(Get, "/merge_deeplink_config", (r, w) => {
    self.config.handle_merge_deeplink_config(r, w)
  })
  router.add_handler(Post, "/import_from_deeplink", (r, w) => {
    self.config.handle_import_from_deeplink(self.proxy, r, w, legacy=true)
  })
  router.add_handler(Post, "/import_from_deeplink_unified", (r, w) => {
    self.config.handle_import_from_deeplink(self.proxy, r, w, legacy=false)
  })
  router.add_handler(Post, "/webdav_test_connection", (r, w) => {
    self.config.handle_webdav_test_connection(r, w)
  })
  router.add_handler(Post, "/webdav_sync_upload", (_, w) => {
    self.config.handle_webdav_sync_operation(
      self.proxy,
      host=self.host,
      port=self.port,
      w,
      "upload",
    )
  })
  router.add_handler(Post, "/webdav_sync_download", (_, w) => {
    self.config.handle_webdav_sync_operation(
      self.proxy,
      host=self.host,
      port=self.port,
      w,
      "download",
    )
  })
  router.add_handler(Post, "/webdav_sync_save_settings", (r, w) => {
    self.config.handle_webdav_sync_save_settings(r, w)
  })
  router.add_handler(Get, "/webdav_sync_fetch_remote_info", (_, w) => {
    self.config.handle_webdav_sync_fetch_remote_info(w)
  })
  router.add_handler(Post, "/s3_test_connection", (r, w) => {
    self.config.handle_s3_test_connection(r, w)
  })
  router.add_handler(Post, "/s3_sync_upload", (_, w) => {
    self.config.handle_s3_sync_operation(
      self.proxy,
      host=self.host,
      port=self.port,
      w,
      "upload",
    )
  })
  router.add_handler(Post, "/s3_sync_download", (_, w) => {
    self.config.handle_s3_sync_operation(
      self.proxy,
      host=self.host,
      port=self.port,
      w,
      "download",
    )
  })
  router.add_handler(Post, "/s3_sync_save_settings", (r, w) => {
    self.config.handle_s3_sync_save_settings(r, w)
  })
  router.add_handler(Get, "/s3_sync_fetch_remote_info", (_, w) => {
    self.config.handle_s3_sync_fetch_remote_info(w)
  })
  router.add_handler(Get, "/read_omo_local_file", (_, w) => {
    self.workspace.handle_read_omo_local_file(w, slim=false)
  })
  router.add_handler(Post, "/read_omo_local_file", (_, w) => {
    self.workspace.handle_read_omo_local_file(w, slim=false)
  })
  router.add_handler(Get, "/get_current_omo_provider_id", (_, w) => {
    self.proxy.handle_get_current_omo_provider_id(w, slim=false)
  })
  router.add_handler(Post, "/get_current_omo_provider_id", (_, w) => {
    self.proxy.handle_get_current_omo_provider_id(w, slim=false)
  })
  router.add_handler(Post, "/disable_current_omo", (_, w) => {
    self.proxy.handle_disable_current_omo(w, slim=false)
  })
  router.add_handler(Get, "/read_omo_slim_local_file", (_, w) => {
    self.workspace.handle_read_omo_local_file(w, slim=true)
  })
  router.add_handler(Post, "/read_omo_slim_local_file", (_, w) => {
    self.workspace.handle_read_omo_local_file(w, slim=true)
  })
  router.add_handler(Get, "/get_current_omo_slim_provider_id", (_, w) => {
    self.proxy.handle_get_current_omo_provider_id(w, slim=true)
  })
  router.add_handler(Post, "/get_current_omo_slim_provider_id", (_, w) => {
    self.proxy.handle_get_current_omo_provider_id(w, slim=true)
  })
  router.add_handler(Post, "/disable_current_omo_slim", (_, w) => {
    self.proxy.handle_disable_current_omo(w, slim=true)
  })
  router.add_handler(Post, "/open_file_dialog", (_, w) => {
    self.workspace.handle_open_file_dialog(w)
  })
  router.add_handler(Get, "/open_file_dialog", (_, w) => {
    self.workspace.handle_open_file_dialog(w)
  })
  router.add_handler(Post, "/open_zip_file_dialog", (_, w) => {
    self.workspace.handle_open_zip_file_dialog(w)
  })
  router.add_handler(Get, "/open_zip_file_dialog", (_, w) => {
    self.workspace.handle_open_zip_file_dialog(w)
  })
  router.add_handler(Get, "/get_installed_skills", (_, w) => {
    self.skills.handle_get_installed_skills(w)
  })
  router.add_handler(Get, "/get_skill_backups", (_, w) => {
    self.config.handle_get_skill_backups(w)
  })
  router.add_handler(Post, "/delete_skill_backup", (r, w) => {
    self.config.handle_delete_skill_backup(r, w)
  })
  router.add_handler(Post, "/restore_skill_backup", (r, w) => {
    self.config.handle_restore_skill_backup(r, w)
  })
  router.add_handler(Post, "/install_skill_unified", (r, w) => {
    self.skills.handle_install_skill_unified(r, w)
  })
  router.add_handler(Post, "/uninstall_skill_unified", (r, w) => {
    self.skills.handle_uninstall_skill_unified(r, w)
  })
  router.add_handler(Post, "/toggle_skill_app", (r, w) => {
    self.skills.handle_toggle_skill_app(r, w)
  })
  router.add_handler(Get, "/scan_unmanaged_skills", (_, w) => {
    self.skills.handle_scan_unmanaged_skills(w)
  })
  router.add_handler(Post, "/import_skills_from_apps", (r, w) => {
    self.skills.handle_import_skills_from_apps(r, w)
  })
  router.add_handler(Get, "/discover_available_skills", (_, w) => {
    self.skills.handle_discover_available_skills(w)
  })
  router.add_handler(Get, "/check_skill_updates", (_, w) => {
    self.skills.handle_check_skill_updates(w)
  })
  router.add_handler(Post, "/update_skill", (r, w) => {
    self.skills.handle_update_skill(r, w)
  })
  router.add_handler(Post, "/migrate_skill_storage", (r, w) => {
    self.skills.handle_migrate_skill_storage(r, w)
  })
  router.add_handler(Get, "/search_skills_sh", (r, w) => {
    self.skills.handle_search_skills_sh(r, w)
  })
  router.add_handler(Post, "/search_skills_sh", (r, w) => {
    self.skills.handle_search_skills_sh(r, w)
  })
  router.add_handler(Get, "/get_skills", (_, w) => {
    self.skills.handle_get_skills(w)
  })
  router.add_handler(Get, "/get_skills_for_app", (_, w) => {
    self.skills.handle_get_skills(w)
  })
  router.add_handler(Post, "/install_skill", (r, w) => {
    self.skills.handle_install_skill_legacy(r, w, "claude")
  })
  router.add_handler(Post, "/install_skill_for_app", (r, w) => {
    self.skills.handle_install_skill_for_app(r, w)
  })
  router.add_handler(Post, "/uninstall_skill", (r, w) => {
    self.skills.handle_uninstall_skill_legacy(r, w)
  })
  router.add_handler(Post, "/uninstall_skill_for_app", (r, w) => {
    self.skills.handle_uninstall_skill_legacy(r, w)
  })
  router.add_handler(Get, "/get_skill_repos", (_, w) => {
    self.skills.handle_get_skill_repos(w)
  })
  router.add_handler(Post, "/add_skill_repo", (r, w) => {
    self.skills.handle_add_skill_repo(r, w)
  })
  router.add_handler(Post, "/remove_skill_repo", (r, w) => {
    self.skills.handle_remove_skill_repo(r, w)
  })
  router.add_handler(Post, "/install_skills_from_zip", (r, w) => {
    self.skills.handle_install_skills_from_zip(r, w)
  })
  router.add_handler(Get, "/get_app_config_path", (_, w) => {
    self.config.handle_get_app_config_path(w)
  })
  router.add_handler(Get, "/open_app_config_folder", (_, w) => {
    self.config.handle_open_app_config_folder(w)
  })
  router.add_handler(Get, "/get_claude_common_config_snippet", (_, w) => {
    self.config.handle_get_common_config_snippet(w, "claude")
  })
  router.add_handler(Post, "/set_claude_common_config_snippet", (r, w) => {
    self.config.handle_set_common_config_snippet(r, w, "claude")
  })
  router.add_handler(Get, "/get_common_config_snippet", (r, w) => {
    self.config.handle_get_common_config_snippet_request(r, w)
  })
  router.add_handler(Post, "/get_common_config_snippet", (r, w) => {
    self.config.handle_get_common_config_snippet_request(r, w)
  })
  router.add_handler(Post, "/set_common_config_snippet", (r, w) => {
    self.config.handle_set_common_config_snippet_request(r, w)
  })
  router.add_handler(Get, "/extract_common_config_snippet", (r, w) => {
    self.config.handle_extract_common_config_snippet(r, w)
  })
  router.add_handler(Post, "/extract_common_config_snippet", (r, w) => {
    self.config.handle_extract_common_config_snippet(r, w)
  })
  router.add_handler(Get, "/check_env_conflicts", (r, w) => {
    self.config.handle_check_env_conflicts(r, w)
  })
  router.add_handler(Post, "/check_env_conflicts", (r, w) => {
    self.config.handle_check_env_conflicts(r, w)
  })
  router.add_handler(Post, "/delete_env_vars", (r, w) => {
    self.config.handle_delete_env_vars(r, w)
  })
  router.add_handler(Post, "/restore_env_backup", (r, w) => {
    self.config.handle_restore_env_backup(r, w)
  })
  router.add_handler(Get, "/get_claude_mcp_status", (_, w) => {
    self.config.handle_get_claude_mcp_status(w)
  })
  router.add_handler(Get, "/read_claude_mcp_config", (_, w) => {
    self.config.handle_read_claude_mcp_config(w)
  })
  router.add_handler(Post, "/upsert_claude_mcp_server", (r, w) => {
    self.config.handle_upsert_claude_mcp_server(r, w)
  })
  router.add_handler(Post, "/delete_claude_mcp_server", (r, w) => {
    self.config.handle_delete_mcp_server(r, w)
  })
  router.add_handler(Delete, "/delete_claude_mcp_server", (r, w) => {
    self.config.handle_delete_mcp_server(r, w)
  })
  router.add_handler(Get, "/validate_mcp_command", (r, w) => {
    self.config.handle_validate_mcp_command(r, w)
  })
  router.add_handler(Post, "/validate_mcp_command", (r, w) => {
    self.config.handle_validate_mcp_command(r, w)
  })
  router.add_handler(Get, "/get_mcp_config", (r, w) => {
    self.config.handle_get_mcp_config(r, w)
  })
  router.add_handler(Post, "/get_mcp_config", (r, w) => {
    self.config.handle_get_mcp_config(r, w)
  })
  router.add_handler(Post, "/upsert_mcp_server_in_config", (r, w) => {
    self.config.handle_upsert_mcp_server_in_config(r, w)
  })
  router.add_handler(Post, "/delete_mcp_server_in_config", (r, w) => {
    self.config.handle_delete_mcp_server(r, w)
  })
  router.add_handler(Delete, "/delete_mcp_server_in_config", (r, w) => {
    self.config.handle_delete_mcp_server(r, w)
  })
  router.add_handler(Post, "/set_mcp_enabled", (r, w) => {
    self.config.handle_set_mcp_enabled(r, w)
  })
  router.add_handler(Get, "/get_mcp_servers", (_, w) => {
    self.config.handle_get_mcp_servers(w)
  })
  router.add_handler(Post, "/upsert_mcp_server", (r, w) => {
    self.config.handle_upsert_mcp_server(r, w)
  })
  router.add_handler(Post, "/delete_mcp_server", (r, w) => {
    self.config.handle_delete_mcp_server(r, w)
  })
  router.add_handler(Delete, "/delete_mcp_server", (r, w) => {
    self.config.handle_delete_mcp_server(r, w)
  })
  router.add_handler(Post, "/toggle_mcp_app", (r, w) => {
    self.config.handle_toggle_mcp_app(r, w)
  })
  router.add_handler(Post, "/import_mcp_from_apps", (_, w) => {
    self.config.handle_import_mcp_from_apps(w)
  })
  router.add_handler(Get, "/get_prompts", (r, w) => {
    self.config.handle_get_prompts(r, w)
  })
  router.add_handler(Post, "/get_prompts", (r, w) => {
    self.config.handle_get_prompts(r, w)
  })
  router.add_handler(Post, "/upsert_prompt", (r, w) => {
    self.config.handle_upsert_prompt(r, w)
  })
  router.add_handler(Post, "/delete_prompt", (r, w) => {
    self.config.handle_delete_prompt(r, w)
  })
  router.add_handler(Delete, "/delete_prompt", (r, w) => {
    self.config.handle_delete_prompt(r, w)
  })
  router.add_handler(Post, "/enable_prompt", (r, w) => {
    self.config.handle_enable_prompt(r, w)
  })
  router.add_handler(Post, "/import_prompt_from_file", (r, w) => {
    self.workspace.handle_import_prompt_from_file(self.config, r, w)
  })
  router.add_handler(Get, "/get_current_prompt_file_content", (r, w) => {
    self.workspace.handle_get_current_prompt_file_content(r, w)
  })
  router.add_handler(Post, "/get_current_prompt_file_content", (r, w) => {
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
  router.add_handler(Get, "/get_proxy_status", (_, w) => {
    self.proxy.handle_proxy_status(
      w,
      self.usage,
      self.host,
      self.port,
      self.runtime.uptime_seconds(self.started_at_ms),
    )
  })
  router.add_handler(Post, "/start_proxy_server", (_, w) => {
    self.proxy.handle_proxy_start_server(w, self.started_at_ms)
  })
  router.add_handler(Post, "/stop_proxy_server", (_, w) => {
    self.proxy.handle_proxy_stop_server(w)
  })
  router.add_handler(Post, "/stop_proxy_with_restore", (_, w) => {
    self.proxy.handle_proxy_stop_with_restore(w)
  })
  router.add_handler(Get, "/proxy/config", (_, w) => {
    self.proxy.handle_proxy_config(
      w,
      live_takeover_active=self.proxy.takeover_active(),
    )
  })
  router.add_handler(Get, "/get_proxy_config", (_, w) => {
    self.proxy.handle_proxy_config(
      w,
      live_takeover_active=self.proxy.takeover_active(),
    )
  })
  router.add_handler(Post, "/proxy/config", (r, w) => {
    self.proxy.handle_proxy_update_config(r, w)
  })
  router.add_handler(Post, "/update_proxy_config", (r, w) => {
    self.proxy.handle_proxy_update_config(r, w)
  })
  router.add_handler(Get, "/proxy/global-config", (_, w) => {
    self.proxy.handle_proxy_global_config(w)
  })
  router.add_handler(Get, "/get_global_proxy_config", (_, w) => {
    self.proxy.handle_proxy_global_config(w)
  })
  router.add_handler(Post, "/proxy/global-config", (r, w) => {
    self.proxy.handle_proxy_update_global_config(r, w)
  })
  router.add_handler(Post, "/update_global_proxy_config", (r, w) => {
    self.proxy.handle_proxy_update_global_config(r, w)
  })
  router.add_handler(Get, "/get_settings", (_, w) => {
    self.config.handle_get_settings(w)
  })
  router.add_handler(Post, "/save_settings", (r, w) => {
    self.config.handle_save_settings(r, w)
  })
  router.add_handler(Post, "/restart_app", (_, w) => {
    self.runtime.handle_restart_app(w)
  })
  router.add_handler(Post, "/install_update_and_restart", (_, w) => {
    self.runtime.handle_install_update_and_restart(w)
  })
  router.add_handler(Get, "/get_app_config_dir_override", (_, w) => {
    self.config.handle_get_app_config_dir_override(w)
  })
  router.add_handler(Post, "/set_app_config_dir_override", (r, w) => {
    self.config.handle_set_app_config_dir_override(r, w)
  })
  router.add_handler(Post, "/set_auto_launch", (r, w) => {
    self.config.handle_set_auto_launch(r, w)
  })
  router.add_handler(Get, "/get_auto_launch_status", (_, w) => {
    self.config.handle_get_auto_launch_status(w)
  })
  router.add_handler(Get, "/get_rectifier_config", (_, w) => {
    self.config.handle_get_rectifier_config(w)
  })
  router.add_handler(Post, "/set_rectifier_config", (r, w) => {
    self.config.handle_set_rectifier_config(r, w)
  })
  router.add_handler(Get, "/get_optimizer_config", (_, w) => {
    self.config.handle_get_optimizer_config(w)
  })
  router.add_handler(Post, "/set_optimizer_config", (r, w) => {
    self.config.handle_set_optimizer_config(r, w)
  })
  router.add_handler(Get, "/get_copilot_optimizer_config", (_, w) => {
    self.config.handle_get_copilot_optimizer_config(w)
  })
  router.add_handler(Post, "/set_copilot_optimizer_config", (r, w) => {
    self.config.handle_set_copilot_optimizer_config(r, w)
  })
  router.add_handler(Get, "/get_log_config", (_, w) => {
    self.config.handle_get_log_config(w)
  })
  router.add_handler(Post, "/set_log_config", (r, w) => {
    self.config.handle_set_log_config(r, w)
  })
  router.add_handler(Get, "/get_global_proxy_url", (_, w) => {
    self.proxy.handle_get_global_proxy_url(w)
  })
  router.add_handler(Post, "/set_global_proxy_url", (r, w) => {
    self.proxy.handle_set_global_proxy_url(r, w)
  })
  router.add_handler(Get, "/test_proxy_url", (r, w) => {
    self.proxy.handle_test_proxy_url(r, w)
  })
  router.add_handler(Post, "/test_proxy_url", (r, w) => {
    self.proxy.handle_test_proxy_url(r, w)
  })
  router.add_handler(Get, "/get_upstream_proxy_status", (_, w) => {
    self.proxy.handle_get_upstream_proxy_status(w)
  })
  router.add_handler(Get, "/scan_local_proxies", (_, w) => {
    self.proxy.handle_scan_local_proxies(w)
  })
  router.add_handler(Get, "/proxy/app-config", (r, w) => {
    self.proxy.handle_proxy_app_config(r, w)
  })
  router.add_handler(Get, "/get_proxy_config_for_app", (r, w) => {
    self.proxy.handle_proxy_app_config(r, w)
  })
  router.add_handler(Post, "/proxy/app-config", (r, w) => {
    self.proxy.handle_proxy_update_app_config(r, w)
  })
  router.add_handler(Post, "/update_proxy_config_for_app", (r, w) => {
    self.proxy.handle_proxy_update_app_config(r, w)
  })
  router.add_handler(Get, "/proxy/default-cost-multiplier", (r, w) => {
    self.proxy.handle_proxy_default_cost_multiplier(r, w)
  })
  router.add_handler(Post, "/proxy/default-cost-multiplier", (r, w) => {
    self.proxy.handle_proxy_set_default_cost_multiplier(r, w)
  })
  router.add_handler(Post, "/set_default_cost_multiplier", (r, w) => {
    self.proxy.handle_proxy_set_default_cost_multiplier(r, w)
  })
  router.add_handler(Get, "/get_default_cost_multiplier_test_hook", (r, w) => {
    self.proxy.handle_proxy_default_cost_multiplier(r, w)
  })
  router.add_handler(Get, "/get_default_cost_multiplier", (r, w) => {
    self.proxy.handle_proxy_default_cost_multiplier(r, w)
  })
  router.add_handler(Post, "/set_default_cost_multiplier_test_hook", (r, w) => {
    self.proxy.handle_proxy_set_default_cost_multiplier_unit(r, w)
  })
  router.add_handler(Get, "/proxy/pricing-model-source", (r, w) => {
    self.proxy.handle_proxy_pricing_model_source(r, w)
  })
  router.add_handler(Post, "/proxy/pricing-model-source", (r, w) => {
    self.proxy.handle_proxy_set_pricing_model_source(r, w)
  })
  router.add_handler(Post, "/set_pricing_model_source", (r, w) => {
    self.proxy.handle_proxy_set_pricing_model_source(r, w)
  })
  router.add_handler(Get, "/get_pricing_model_source_test_hook", (r, w) => {
    self.proxy.handle_proxy_pricing_model_source(r, w)
  })
  router.add_handler(Get, "/get_pricing_model_source", (r, w) => {
    self.proxy.handle_proxy_pricing_model_source(r, w)
  })
  router.add_handler(Post, "/set_pricing_model_source_test_hook", (r, w) => {
    self.proxy.handle_proxy_set_pricing_model_source_unit(r, w)
  })
  router.add_handler(Get, "/proxy/provider-health", (r, w) => {
    self.proxy.handle_proxy_provider_health(r, w)
  })
  router.add_handler(Get, "/get_provider_health", (r, w) => {
    self.proxy.handle_proxy_provider_health(r, w)
  })
  router.add_handler(Get, "/proxy/circuit-breaker-config", (_, w) => {
    self.proxy.handle_proxy_circuit_breaker_config(w)
  })
  router.add_handler(Get, "/get_circuit_breaker_config", (_, w) => {
    self.proxy.handle_proxy_circuit_breaker_config(w)
  })
  router.add_handler(Post, "/proxy/circuit-breaker-config", (r, w) => {
    self.proxy.handle_proxy_update_circuit_breaker_config(r, w)
  })
  router.add_handler(Post, "/update_circuit_breaker_config", (r, w) => {
    self.proxy.handle_proxy_update_circuit_breaker_config(r, w)
  })
  router.add_handler(Get, "/proxy/circuit-breaker-stats", (r, w) => {
    self.proxy.handle_proxy_circuit_breaker_stats(r, w)
  })
  router.add_handler(Get, "/get_circuit_breaker_stats", (_, w) => {
    self.proxy.handle_proxy_circuit_breaker_stats_moon_alias(w)
  })
  router.add_handler(Post, "/proxy/reset-circuit-breaker", (r, w) => {
    self.proxy.handle_proxy_reset_circuit_breaker(r, w)
  })
  router.add_handler(Post, "/reset_circuit_breaker", (r, w) => {
    self.proxy.handle_proxy_reset_circuit_breaker(r, w)
  })
  router.add_handler(Get, "/proxy/failover-queue", (r, w) => {
    self.proxy.handle_proxy_failover_queue(r, w)
  })
  router.add_handler(Get, "/get_failover_queue", (r, w) => {
    self.proxy.handle_proxy_failover_queue(r, w)
  })
  router.add_handler(Post, "/proxy/failover-queue", (r, w) => {
    self.proxy.handle_proxy_add_failover_queue(r, w)
  })
  router.add_handler(Post, "/add_to_failover_queue", (r, w) => {
    self.proxy.handle_proxy_add_failover_queue(r, w)
  })
  router.add_handler(Delete, "/proxy/failover-queue", (r, w) => {
    self.proxy.handle_proxy_remove_failover_queue(r, w)
  })
  router.add_handler(Delete, "/remove_from_failover_queue", (r, w) => {
    self.proxy.handle_proxy_remove_failover_queue(r, w)
  })
  router.add_handler(Post, "/remove_from_failover_queue", (r, w) => {
    self.proxy.handle_proxy_remove_failover_queue(r, w)
  })
  router.add_handler(Get, "/proxy/available-failover-providers", (r, w) => {
    self.proxy.handle_proxy_available_failover_providers(r, w)
  })
  router.add_handler(Get, "/get_available_providers_for_failover", (r, w) => {
    self.proxy.handle_proxy_available_failover_providers(r, w)
  })
  router.add_handler(Get, "/proxy/auto-failover-enabled", (r, w) => {
    self.proxy.handle_proxy_auto_failover_enabled(r, w)
  })
  router.add_handler(Get, "/get_auto_failover_enabled", (r, w) => {
    self.proxy.handle_proxy_auto_failover_enabled(r, w)
  })
  router.add_handler(Post, "/proxy/auto-failover-enabled", (r, w) => {
    self.proxy.handle_proxy_set_auto_failover_enabled(r, w)
  })
  router.add_handler(Post, "/set_auto_failover_enabled", (r, w) => {
    self.proxy.handle_proxy_set_auto_failover_enabled(r, w)
  })
  router.add_handler(Get, "/proxy/takeover-status", (_, w) => {
    self.proxy.handle_proxy_takeover_status(w)
  })
  router.add_handler(Get, "/get_proxy_takeover_status", (_, w) => {
    self.proxy.handle_proxy_takeover_status(w)
  })
  router.add_handler(Get, "/is_live_takeover_active", (_, w) => {
    self.proxy.handle_proxy_live_takeover_active(w)
  })
  router.add_handler(Post, "/proxy/takeover-status", (r, w) => {
    self.proxy.handle_proxy_set_takeover_for_app(r, w)
  })
  router.add_handler(Post, "/set_proxy_takeover_for_app", (r, w) => {
    self.proxy.handle_proxy_set_takeover_for_app(r, w)
  })
  router.add_handler(Post, "/switch_proxy_provider", (r, w) => {
    self.proxy.handle_proxy_switch_provider(self.usage, r, w)
  })
  router.add_handler(Post, "/sync_current_providers_live", (_, w) => {
    self.proxy.handle_sync_current_providers_live(self.usage, w)
  })
  router.add_handler(Post, "/import_default_config", (r, w) => {
    self.proxy.handle_import_default_config(r, w)
  })
  router.add_handler(Post, "/import_default_config_test_hook", (r, w) => {
    self.proxy.handle_import_default_config(r, w)
  })
  router.add_handler(Get, "/get_providers", (r, w) => {
    self.proxy.handle_get_providers(r, w)
  })
  router.add_handler(Post, "/get_providers", (r, w) => {
    self.proxy.handle_get_providers(r, w)
  })
  router.add_handler(Get, "/get_current_provider", (r, w) => {
    self.proxy.handle_get_current_provider(r, w)
  })
  router.add_handler(Post, "/get_current_provider", (r, w) => {
    self.proxy.handle_get_current_provider(r, w)
  })
  router.add_handler(Post, "/add_provider", (r, w) => {
    self.proxy.handle_add_provider(r, w, self.usage)
  })
  router.add_handler(Post, "/update_provider", (r, w) => {
    self.proxy.handle_update_provider(r, w, self.usage)
  })
  router.add_handler(Delete, "/delete_provider", (r, w) => {
    self.proxy.handle_delete_provider(r, w)
  })
  router.add_handler(Post, "/delete_provider", (r, w) => {
    self.proxy.handle_delete_provider(r, w)
  })
  router.add_handler(Delete, "/remove_provider_from_live_config", (r, w) => {
    self.proxy.handle_remove_provider_from_live_config(r, w)
  })
  router.add_handler(Post, "/remove_provider_from_live_config", (r, w) => {
    self.proxy.handle_remove_provider_from_live_config(r, w)
  })
  router.add_handler(Post, "/switch_provider", (r, w) => {
    self.proxy.handle_switch_provider(r, w, self.usage)
  })
  router.add_handler(Post, "/switch_provider_test_hook", (r, w) => {
    self.proxy.handle_switch_provider(r, w, self.usage)
  })
  router.add_handler(Post, "/open_provider_terminal", (r, w) => {
    self.proxy.handle_open_provider_terminal(r, w)
  })
  router.add_handler(Get, "/get_claude_desktop_status", (_, w) => {
    self.proxy.handle_get_claude_desktop_status(self.host, self.port, w)
  })
  router.add_handler(Get, "/get_claude_desktop_default_routes", (_, w) => {
    self.proxy.handle_get_claude_desktop_default_routes(w)
  })
  router.add_handler(Post, "/import_claude_desktop_providers_from_claude", (
    _,
    w,
  ) => self.proxy.handle_import_claude_desktop_providers_from_claude(w))
  router.add_handler(Post, "/ensure_claude_desktop_official_provider", (_, w) => {
    self.proxy.handle_ensure_claude_desktop_official_provider(w)
  })
  router.add_handler(Get, "/read_live_provider_settings", (r, w) => {
    self.proxy.handle_read_live_provider_settings(r, w)
  })
  router.add_handler(Post, "/read_live_provider_settings", (r, w) => {
    self.proxy.handle_read_live_provider_settings(r, w)
  })
  router.add_handler(Get, "/get_claude_plugin_status", (_, w) => {
    self.config.handle_get_claude_plugin_status(w)
  })
  router.add_handler(Get, "/read_claude_plugin_config", (_, w) => {
    self.config.handle_read_claude_plugin_config(w)
  })
  router.add_handler(Post, "/apply_claude_plugin_config", (r, w) => {
    self.config.handle_apply_claude_plugin_config(r, w)
  })
  router.add_handler(Get, "/is_claude_plugin_applied", (_, w) => {
    self.config.handle_is_claude_plugin_applied(w)
  })
  router.add_handler(Post, "/apply_claude_onboarding_skip", (_, w) => {
    self.config.handle_apply_claude_onboarding_skip(w)
  })
  router.add_handler(Post, "/clear_claude_onboarding_skip", (_, w) => {
    self.config.handle_clear_claude_onboarding_skip(w)
  })
  router.add_handler(Get, "/list_daily_memory_files", (_, w) => {
    self.workspace.handle_list_daily_memory_files(w)
  })
  router.add_handler(Get, "/read_daily_memory_file", (r, w) => {
    self.workspace.handle_read_daily_memory_file(r, w)
  })
  router.add_handler(Post, "/read_daily_memory_file", (r, w) => {
    self.workspace.handle_read_daily_memory_file(r, w)
  })
  router.add_handler(Post, "/write_daily_memory_file", (r, w) => {
    self.workspace.handle_write_daily_memory_file(r, w)
  })
  router.add_handler(Get, "/search_daily_memory_files", (r, w) => {
    self.workspace.handle_search_daily_memory_files(r, w)
  })
  router.add_handler(Post, "/search_daily_memory_files", (r, w) => {
    self.workspace.handle_search_daily_memory_files(r, w)
  })
  router.add_handler(Delete, "/delete_daily_memory_file", (r, w) => {
    self.workspace.handle_delete_daily_memory_file(r, w)
  })
  router.add_handler(Post, "/delete_daily_memory_file", (r, w) => {
    self.workspace.handle_delete_daily_memory_file(r, w)
  })
  router.add_handler(Get, "/read_workspace_file", (r, w) => {
    self.workspace.handle_read_workspace_file(r, w)
  })
  router.add_handler(Post, "/read_workspace_file", (r, w) => {
    self.workspace.handle_read_workspace_file(r, w)
  })
  router.add_handler(Post, "/write_workspace_file", (r, w) => {
    self.workspace.handle_write_workspace_file(r, w)
  })
  router.add_handler(Get, "/open_workspace_directory", (r, w) => {
    self.workspace.handle_open_workspace_directory(r, w)
  })
  router.add_handler(Post, "/open_workspace_directory", (r, w) => {
    self.workspace.handle_open_workspace_directory(r, w)
  })
  router.add_handler(Get, "/get_opencode_live_provider_ids", (_, w) => {
    self.proxy.handle_get_live_provider_ids(w, "opencode")
  })
  router.add_handler(Get, "/get_openclaw_live_provider_ids", (_, w) => {
    self.proxy.handle_get_live_provider_ids(w, "openclaw")
  })
  router.add_handler(Get, "/get_openclaw_live_provider", (r, w) => {
    self.proxy.handle_get_live_provider(r, w, "openclaw")
  })
  router.add_handler(Post, "/get_openclaw_live_provider", (r, w) => {
    self.proxy.handle_get_live_provider(r, w, "openclaw")
  })
  router.add_handler(Get, "/scan_openclaw_config_health", (_, w) => {
    self.openclaw.handle_scan_openclaw_config_health(w)
  })
  router.add_handler(Get, "/get_openclaw_default_model", (_, w) => {
    self.openclaw.handle_get_openclaw_default_model(w)
  })
  router.add_handler(Post, "/set_openclaw_default_model", (r, w) => {
    self.openclaw.handle_set_openclaw_default_model(r, w)
  })
  router.add_handler(Get, "/get_openclaw_model_catalog", (_, w) => {
    self.openclaw.handle_get_openclaw_model_catalog(w)
  })
  router.add_handler(Post, "/set_openclaw_model_catalog", (r, w) => {
    self.openclaw.handle_set_openclaw_model_catalog(r, w)
  })
  router.add_handler(Get, "/get_openclaw_agents_defaults", (_, w) => {
    self.openclaw.handle_get_openclaw_agents_defaults(w)
  })
  router.add_handler(Post, "/set_openclaw_agents_defaults", (r, w) => {
    self.openclaw.handle_set_openclaw_agents_defaults(r, w)
  })
  router.add_handler(Get, "/get_openclaw_env", (_, w) => {
    self.openclaw.handle_get_openclaw_env(w)
  })
  router.add_handler(Post, "/set_openclaw_env", (r, w) => {
    self.openclaw.handle_set_openclaw_env(r, w)
  })
  router.add_handler(Get, "/get_openclaw_tools", (_, w) => {
    self.openclaw.handle_get_openclaw_tools(w)
  })
  router.add_handler(Post, "/set_openclaw_tools", (r, w) => {
    self.openclaw.handle_set_openclaw_tools(r, w)
  })
  router.add_handler(Get, "/get_hermes_live_provider_ids", (_, w) => {
    self.proxy.handle_get_live_provider_ids(w, "hermes")
  })
  router.add_handler(Get, "/get_hermes_live_provider", (r, w) => {
    self.proxy.handle_get_live_provider(r, w, "hermes")
  })
  router.add_handler(Post, "/get_hermes_live_provider", (r, w) => {
    self.proxy.handle_get_live_provider(r, w, "hermes")
  })
  router.add_handler(Get, "/get_hermes_model_config", (_, w) => {
    self.openclaw.handle_get_hermes_model_config(w)
  })
  router.add_handler(Get, "/get_hermes_memory", (r, w) => {
    self.openclaw.handle_get_hermes_memory(r, w)
  })
  router.add_handler(Post, "/get_hermes_memory", (r, w) => {
    self.openclaw.handle_get_hermes_memory(r, w)
  })
  router.add_handler(Post, "/set_hermes_memory", (r, w) => {
    self.openclaw.handle_set_hermes_memory(r, w)
  })
  router.add_handler(Get, "/get_hermes_memory_limits", (_, w) => {
    self.openclaw.handle_get_hermes_memory_limits(w)
  })
  router.add_handler(Post, "/set_hermes_memory_enabled", (r, w) => {
    self.openclaw.handle_set_hermes_memory_enabled(r, w)
  })
  router.add_handler(Get, "/open_hermes_web_ui", (r, w) => {
    self.openclaw.handle_open_hermes_web_ui(r, w)
  })
  router.add_handler(Post, "/open_hermes_web_ui", (r, w) => {
    self.openclaw.handle_open_hermes_web_ui(r, w)
  })
  router.add_handler(Post, "/launch_hermes_dashboard", (_, w) => {
    self.openclaw.handle_launch_hermes_dashboard(w)
  })
  router.add_handler(Post, "/import_opencode_providers_from_live", (_, w) => {
    self.proxy.handle_import_live_providers(w, "opencode")
  })
  router.add_handler(Post, "/import_openclaw_providers_from_live", (_, w) => {
    self.proxy.handle_import_live_providers(w, "openclaw")
  })
  router.add_handler(Post, "/import_hermes_providers_from_live", (_, w) => {
    self.proxy.handle_import_live_providers(w, "hermes")
  })
  router.add_handler(Get, "/get_universal_providers", (_, w) => {
    self.proxy.handle_get_universal_providers(w)
  })
  router.add_handler(Get, "/get_universal_provider", (r, w) => {
    self.proxy.handle_get_universal_provider(r, w)
  })
  router.add_handler(Post, "/upsert_universal_provider", (r, w) => {
    self.proxy.handle_upsert_universal_provider(r, w)
  })
  router.add_handler(Delete, "/delete_universal_provider", (r, w) => {
    self.proxy.handle_delete_universal_provider(r, w)
  })
  router.add_handler(Post, "/delete_universal_provider", (r, w) => {
    self.proxy.handle_delete_universal_provider(r, w)
  })
  router.add_handler(Post, "/sync_universal_provider", (r, w) => {
    self.proxy.handle_sync_universal_provider(r, w)
  })
  router.add_handler(Get, "/get_provider_presets", (r, w) => {
    self.proxy.handle_get_provider_presets(r, w)
  })
  router.add_handler(Post, "/test_api_endpoints", (r, w) => {
    self.proxy.handle_test_api_endpoints(r, w)
  })
  router.add_handler(Get, "/test_api_endpoints", (r, w) => {
    self.proxy.handle_test_api_endpoints(r, w)
  })
  router.add_handler(Post, "/update_providers_sort_order", (r, w) => {
    self.proxy.handle_update_providers_sort_order(r, w)
  })
  router.add_handler(Get, "/get_custom_endpoints", (r, w) => {
    self.proxy.handle_get_custom_endpoints(r, w)
  })
  router.add_handler(Post, "/get_custom_endpoints", (r, w) => {
    self.proxy.handle_get_custom_endpoints(r, w)
  })
  router.add_handler(Post, "/add_custom_endpoint", (r, w) => {
    self.proxy.handle_add_custom_endpoint(r, w)
  })
  router.add_handler(Delete, "/remove_custom_endpoint", (r, w) => {
    self.proxy.handle_remove_custom_endpoint(r, w)
  })
  router.add_handler(Post, "/remove_custom_endpoint", (r, w) => {
    self.proxy.handle_remove_custom_endpoint(r, w)
  })
  router.add_handler(Post, "/update_endpoint_last_used", (r, w) => {
    self.proxy.handle_update_endpoint_last_used(r, w)
  })
  router.add_handler(Get, "/proxy/running", (_, w) => {
    self.proxy.handle_proxy_running(w)
  })
  router.add_handler(Get, "/is_proxy_running", (_, w) => {
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
  router.add_handler(Get, "/list_sessions", (_, w) => {
    self.session.handle_list_sessions(w)
  })
  router.add_handler(Post, "/list_sessions", (_, w) => {
    self.session.handle_list_sessions(w)
  })
  router.add_handler(Get, "/get_session_messages", (r, w) => {
    self.session.handle_get_session_messages(r, w)
  })
  router.add_handler(Post, "/get_session_messages", (r, w) => {
    self.session.handle_get_session_messages(r, w)
  })
  router.add_handler(Post, "/launch_session_terminal", (r, w) => {
    self.session.handle_launch_session_terminal(
      r,
      w,
      moon_session_terminal_from_settings(self.config.app_settings),
    )
  })
  router.add_handler(Post, "/delete_session", (r, w) => {
    self.session.handle_delete_session(r, w)
  })
  router.add_handler(Post, "/delete_sessions", (r, w) => {
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
  router.add_handler(Post, "/stream_check_provider", (r, w) => {
    self.proxy.handle_stream_check_provider(
      self.config.stream_check_config,
      r,
      w,
    )
  })
  router.add_handler(Get, "/stream_check_provider", (r, w) => {
    self.proxy.handle_stream_check_provider(
      self.config.stream_check_config,
      r,
      w,
    )
  })
  router.add_handler(Post, "/stream_check_all_providers", (r, w) => {
    self.proxy.handle_stream_check_all_providers(
      self.config.stream_check_config,
      r,
      w,
    )
  })
  router.add_handler(Get, "/stream_check_all_providers", (r, w) => {
    self.proxy.handle_stream_check_all_providers(
      self.config.stream_check_config,
      r,
      w,
    )
  })
  router.add_handler(Get, "/get_stream_check_config", (_, w) => {
    self.config.handle_get_stream_check_config(w)
  })
  router.add_handler(Post, "/save_stream_check_config", (r, w) => {
    self.config.handle_save_stream_check_config(r, w)
  })
  router.add_handler(Get, "/fetch_models_for_config", (r, w) => {
    self.config.handle_fetch_models_for_config(r, w)
  })
  router.add_handler(Post, "/fetch_models_for_config", (r, w) => {
    self.config.handle_fetch_models_for_config(r, w)
  })
  router.add_handler(Get, "/auth_start_login", (r, w) => {
    self.auth.handle_auth_start_login(r, w)
  })
  router.add_handler(Post, "/auth_start_login", (r, w) => {
    self.auth.handle_auth_start_login(r, w)
  })
  router.add_handler(Get, "/auth_poll_for_account", (r, w) => {
    self.auth.handle_auth_poll_for_account(r, w)
  })
  router.add_handler(Post, "/auth_poll_for_account", (r, w) => {
    self.auth.handle_auth_poll_for_account(r, w)
  })
  router.add_handler(Get, "/auth_list_accounts", (r, w) => {
    self.auth.handle_auth_list_accounts(r, w)
  })
  router.add_handler(Post, "/auth_list_accounts", (r, w) => {
    self.auth.handle_auth_list_accounts(r, w)
  })
  router.add_handler(Get, "/auth_get_status", (r, w) => {
    self.auth.handle_auth_get_status(r, w)
  })
  router.add_handler(Post, "/auth_get_status", (r, w) => {
    self.auth.handle_auth_get_status(r, w)
  })
  router.add_handler(Delete, "/auth_remove_account", (r, w) => {
    self.auth.handle_auth_remove_account(r, w)
  })
  router.add_handler(Post, "/auth_remove_account", (r, w) => {
    self.auth.handle_auth_remove_account(r, w)
  })
  router.add_handler(Post, "/auth_set_default_account", (r, w) => {
    self.auth.handle_auth_set_default_account(r, w)
  })
  router.add_handler(Get, "/auth_set_default_account", (r, w) => {
    self.auth.handle_auth_set_default_account(r, w)
  })
  router.add_handler(Post, "/auth_logout", (r, w) => {
    self.auth.handle_auth_logout(r, w)
  })
  router.add_handler(Get, "/auth_logout", (r, w) => {
    self.auth.handle_auth_logout(r, w)
  })
  router.add_handler(Get, "/copilot_start_device_flow", (r, w) => {
    self.auth.handle_copilot_start_device_flow(r, w)
  })
  router.add_handler(Post, "/copilot_start_device_flow", (r, w) => {
    self.auth.handle_copilot_start_device_flow(r, w)
  })
  router.add_handler(Get, "/copilot_poll_for_auth", (r, w) => {
    self.auth.handle_copilot_poll_for_auth(r, w)
  })
  router.add_handler(Post, "/copilot_poll_for_auth", (r, w) => {
    self.auth.handle_copilot_poll_for_auth(r, w)
  })
  router.add_handler(Get, "/copilot_poll_for_account", (r, w) => {
    self.auth.handle_copilot_poll_for_account(r, w)
  })
  router.add_handler(Post, "/copilot_poll_for_account", (r, w) => {
    self.auth.handle_copilot_poll_for_account(r, w)
  })
  router.add_handler(Get, "/copilot_list_accounts", (_, w) => {
    self.auth.handle_copilot_list_accounts(w)
  })
  router.add_handler(Get, "/copilot_get_auth_status", (_, w) => {
    self.auth.handle_copilot_get_auth_status(w)
  })
  router.add_handler(Get, "/copilot_is_authenticated", (_, w) => {
    self.auth.handle_copilot_is_authenticated(w)
  })
  router.add_handler(Post, "/copilot_logout", (_, w) => {
    self.auth.handle_copilot_logout(w)
  })
  router.add_handler(Get, "/copilot_logout", (_, w) => {
    self.auth.handle_copilot_logout(w)
  })
  router.add_handler(Delete, "/copilot_remove_account", (r, w) => {
    self.auth.handle_copilot_remove_account(r, w)
  })
  router.add_handler(Post, "/copilot_remove_account", (r, w) => {
    self.auth.handle_copilot_remove_account(r, w)
  })
  router.add_handler(Get, "/copilot_set_default_account", (r, w) => {
    self.auth.handle_copilot_set_default_account(r, w)
  })
  router.add_handler(Post, "/copilot_set_default_account", (r, w) => {
    self.auth.handle_copilot_set_default_account(r, w)
  })
  router.add_handler(Get, "/copilot_get_token", (r, w) => {
    self.auth.handle_copilot_get_token(r, w)
  })
  router.add_handler(Get, "/copilot_get_token_for_account", (r, w) => {
    self.auth.handle_copilot_get_token(r, w)
  })
  router.add_handler(Get, "/copilot_get_models", (r, w) => {
    self.auth.handle_copilot_get_models(r, w)
  })
  router.add_handler(Get, "/copilot_get_models_for_account", (r, w) => {
    self.auth.handle_copilot_get_models(r, w)
  })
  router.add_handler(Get, "/copilot_get_usage", (r, w) => {
    self.auth.handle_copilot_get_usage(r, w)
  })
  router.add_handler(Get, "/copilot_get_usage_for_account", (r, w) => {
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
