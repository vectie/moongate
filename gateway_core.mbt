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
  self.load_model_pricing_store()
  ignore(
    self.usage.load_and_reconcile_persistent_store(self.pricing_override_rows()),
  )
  let creds_result : Result[@codex.Credentials, Error] = try? @codex.load_credentials()
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
  router.add_handler(@httpx.Method::Post, "/v1/messages", (r, w) => {
    self.handle_messages(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/claude/v1/messages", (r, w) => {
    self.handle_messages(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/claude-desktop/v1/messages", (r, w) => {
    self.handle_messages(r, w)
  })
  for method_ in @httpx.methods {
    router.add_handler(method_, "/v1beta/*path", (r, w) => {
      self.handle_gemini(r, w)
    })
    router.add_handler(method_, "/gemini/v1beta/*path", (r, w) => {
      self.handle_gemini(r, w)
    })
    router.add_handler(method_, "/gemini/v1/*path", (r, w) => {
      self.handle_gemini(r, w)
    })
  }
  router.add_handler(@httpx.Method::Post, "/chat/completions", (r, w) => {
    self.handle_chat_completions(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/v1/chat/completions", (r, w) => {
    self.handle_chat_completions(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/v1/v1/chat/completions", (r, w) => {
    self.handle_chat_completions(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/codex/v1/chat/completions", (r, w) => {
    self.handle_chat_completions(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/responses", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/v1/responses", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/v1/v1/responses", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/codex/v1/responses", (r, w) => {
    self.handle_codex_responses(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w, compact=true)
  })
  router.add_handler(@httpx.Method::Post, "/v1/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w, compact=true)
  })
  router.add_handler(@httpx.Method::Post, "/v1/v1/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w, compact=true)
  })
  router.add_handler(@httpx.Method::Post, "/codex/v1/responses/compact", (r, w) => {
    self.handle_codex_responses(r, w, compact=true)
  })
  router.add_handler(@httpx.Method::Get, "/participant/register", (_, w) => {
    self.handle_register_page(w)
  })
  router.add_handler(@httpx.Method::Get, "/health", (r, w) => {
    self.handle_health(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/status", (_, w) => {
    self.handle_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/stats", (_, w) => {
    self.usage.handle_stats(w)
  })
  router.add_handler(@httpx.Method::Get, "/metrics", (_, w) => {
    self.usage.handle_metrics(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_claude_config_status", (_, w) => {
    self.handle_get_config_status(w, "claude")
  })
  router.add_handler(@httpx.Method::Get, "/get_config_status", (r, w) => {
    self.handle_get_config_status_request(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_config_status", (r, w) => {
    self.handle_get_config_status_request(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_claude_code_config_path", (_, w) => {
    self.handle_get_claude_code_config_path(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_config_dir", (r, w) => {
    self.handle_get_config_dir(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_config_dir", (r, w) => {
    self.handle_get_config_dir(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/open_config_folder", (r, w) => {
    self.handle_open_config_folder(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/open_config_folder", (r, w) => {
    self.handle_open_config_folder(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/pick_directory", (r, w) => {
    self.handle_pick_directory(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/pick_directory", (r, w) => {
    self.handle_pick_directory(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/open_external", (r, w) => {
    self.handle_open_external(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/open_external", (r, w) => {
    self.handle_open_external(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/copy_text_to_clipboard", (r, w) => {
    self.handle_copy_text_to_clipboard(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copy_text_to_clipboard", (r, w) => {
    self.handle_copy_text_to_clipboard(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/check_for_updates", (_, w) => {
    self.handle_check_for_updates(w)
  })
  router.add_handler(@httpx.Method::Get, "/check_for_updates", (_, w) => {
    self.handle_check_for_updates(w)
  })
  router.add_handler(@httpx.Method::Post, "/update_tray_menu", (_, w) => {
    self.handle_update_tray_menu(w)
  })
  router.add_handler(@httpx.Method::Get, "/update_tray_menu", (_, w) => {
    self.handle_update_tray_menu(w)
  })
  router.add_handler(@httpx.Method::Get, "/is_portable_mode", (_, w) => {
    self.handle_is_portable_mode(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_init_error", (_, w) => {
    self.handle_get_init_error(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_migration_result", (_, w) => {
    self.handle_get_migration_result(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_skills_migration_result", (_, w) => {
    self.handle_get_skills_migration_result(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_tool_versions", (r, w) => {
    self.handle_get_tool_versions(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_tool_versions", (r, w) => {
    self.handle_get_tool_versions(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/run_tool_lifecycle_action", (r, w) => {
    self.handle_run_tool_lifecycle_action(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/probe_tool_installations", (r, w) => {
    self.handle_probe_tool_installations(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/probe_tool_installations", (r, w) => {
    self.handle_probe_tool_installations(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_window_theme", (r, w) => {
    self.handle_set_window_theme(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/set_window_theme", (r, w) => {
    self.handle_set_window_theme(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/enter_lightweight_mode", (_, w) => {
    self.handle_enter_lightweight_mode(w)
  })
  router.add_handler(@httpx.Method::Get, "/enter_lightweight_mode", (_, w) => {
    self.handle_enter_lightweight_mode(w)
  })
  router.add_handler(@httpx.Method::Post, "/exit_lightweight_mode", (_, w) => {
    self.handle_exit_lightweight_mode(w)
  })
  router.add_handler(@httpx.Method::Get, "/exit_lightweight_mode", (_, w) => {
    self.handle_exit_lightweight_mode(w)
  })
  router.add_handler(@httpx.Method::Get, "/is_lightweight_mode", (_, w) => {
    self.handle_is_lightweight_mode(w)
  })
  router.add_handler(@httpx.Method::Post, "/save_file_dialog", (r, w) => {
    self.handle_save_file_dialog(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/save_file_dialog", (r, w) => {
    self.handle_save_file_dialog(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/export_config_to_file", (r, w) => {
    self.handle_export_config_to_file(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/export_config_to_file", (r, w) => {
    self.handle_export_config_to_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/import_config_from_file", (r, w) => {
    self.handle_import_config_from_file(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/import_config_from_file", (r, w) => {
    self.handle_import_config_from_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/create_db_backup", (_, w) => {
    self.handle_create_db_backup(w)
  })
  router.add_handler(@httpx.Method::Get, "/list_db_backups", (_, w) => {
    self.handle_list_db_backups(w)
  })
  router.add_handler(@httpx.Method::Post, "/restore_db_backup", (r, w) => {
    self.handle_restore_db_backup(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/rename_db_backup", (r, w) => {
    self.handle_rename_db_backup(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_db_backup", (r, w) => {
    self.handle_delete_db_backup(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_db_backup", (r, w) => {
    self.handle_delete_db_backup(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/parse_deeplink", (r, w) => {
    self.handle_parse_deeplink(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/parse_deeplink", (r, w) => {
    self.handle_parse_deeplink(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/merge_deeplink_config", (r, w) => {
    self.handle_merge_deeplink_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/merge_deeplink_config", (r, w) => {
    self.handle_merge_deeplink_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/import_from_deeplink", (r, w) => {
    self.handle_import_from_deeplink(r, w, legacy=true)
  })
  router.add_handler(@httpx.Method::Post, "/import_from_deeplink_unified", (
    r,
    w,
  ) => self.handle_import_from_deeplink(r, w, legacy=false))
  router.add_handler(@httpx.Method::Post, "/webdav_test_connection", (r, w) => {
    self.handle_webdav_test_connection(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/webdav_sync_upload", (_, w) => {
    self.handle_webdav_sync_operation(w, "upload")
  })
  router.add_handler(@httpx.Method::Post, "/webdav_sync_download", (_, w) => {
    self.handle_webdav_sync_operation(w, "download")
  })
  router.add_handler(@httpx.Method::Post, "/webdav_sync_save_settings", (r, w) => {
    self.handle_webdav_sync_save_settings(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/webdav_sync_fetch_remote_info", (
    _,
    w,
  ) => self.handle_webdav_sync_fetch_remote_info(w))
  router.add_handler(@httpx.Method::Post, "/s3_test_connection", (r, w) => {
    self.handle_s3_test_connection(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/s3_sync_upload", (_, w) => {
    self.handle_s3_sync_operation(w, "upload")
  })
  router.add_handler(@httpx.Method::Post, "/s3_sync_download", (_, w) => {
    self.handle_s3_sync_operation(w, "download")
  })
  router.add_handler(@httpx.Method::Post, "/s3_sync_save_settings", (r, w) => {
    self.handle_s3_sync_save_settings(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/s3_sync_fetch_remote_info", (_, w) => {
    self.handle_s3_sync_fetch_remote_info(w)
  })
  router.add_handler(@httpx.Method::Get, "/read_omo_local_file", (_, w) => {
    self.handle_read_omo_local_file(w, slim=false)
  })
  router.add_handler(@httpx.Method::Post, "/read_omo_local_file", (_, w) => {
    self.handle_read_omo_local_file(w, slim=false)
  })
  router.add_handler(@httpx.Method::Get, "/get_current_omo_provider_id", (_, w) => {
    self.handle_get_current_omo_provider_id(w, slim=false)
  })
  router.add_handler(@httpx.Method::Post, "/get_current_omo_provider_id", (_, w) => {
    self.handle_get_current_omo_provider_id(w, slim=false)
  })
  router.add_handler(@httpx.Method::Post, "/disable_current_omo", (_, w) => {
    self.handle_disable_current_omo(w, slim=false)
  })
  router.add_handler(@httpx.Method::Get, "/read_omo_slim_local_file", (_, w) => {
    self.handle_read_omo_local_file(w, slim=true)
  })
  router.add_handler(@httpx.Method::Post, "/read_omo_slim_local_file", (_, w) => {
    self.handle_read_omo_local_file(w, slim=true)
  })
  router.add_handler(@httpx.Method::Get, "/get_current_omo_slim_provider_id", (
    _,
    w,
  ) => self.handle_get_current_omo_provider_id(w, slim=true))
  router.add_handler(@httpx.Method::Post, "/get_current_omo_slim_provider_id", (
    _,
    w,
  ) => self.handle_get_current_omo_provider_id(w, slim=true))
  router.add_handler(@httpx.Method::Post, "/disable_current_omo_slim", (_, w) => {
    self.handle_disable_current_omo(w, slim=true)
  })
  router.add_handler(@httpx.Method::Post, "/open_file_dialog", (_, w) => {
    self.handle_open_file_dialog(w)
  })
  router.add_handler(@httpx.Method::Get, "/open_file_dialog", (_, w) => {
    self.handle_open_file_dialog(w)
  })
  router.add_handler(@httpx.Method::Post, "/open_zip_file_dialog", (_, w) => {
    self.handle_open_zip_file_dialog(w)
  })
  router.add_handler(@httpx.Method::Get, "/open_zip_file_dialog", (_, w) => {
    self.handle_open_zip_file_dialog(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_installed_skills", (_, w) => {
    self.handle_get_installed_skills(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_skill_backups", (_, w) => {
    self.handle_get_skill_backups(w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_skill_backup", (r, w) => {
    self.handle_delete_skill_backup(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/restore_skill_backup", (r, w) => {
    self.handle_restore_skill_backup(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/install_skill_unified", (r, w) => {
    self.handle_install_skill_unified(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/uninstall_skill_unified", (r, w) => {
    self.handle_uninstall_skill_unified(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/toggle_skill_app", (r, w) => {
    self.handle_toggle_skill_app(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/scan_unmanaged_skills", (_, w) => {
    self.handle_scan_unmanaged_skills(w)
  })
  router.add_handler(@httpx.Method::Post, "/import_skills_from_apps", (r, w) => {
    self.handle_import_skills_from_apps(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/discover_available_skills", (_, w) => {
    self.handle_discover_available_skills(w)
  })
  router.add_handler(@httpx.Method::Get, "/check_skill_updates", (_, w) => {
    self.handle_check_skill_updates(w)
  })
  router.add_handler(@httpx.Method::Post, "/update_skill", (r, w) => {
    self.handle_update_skill(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/migrate_skill_storage", (r, w) => {
    self.handle_migrate_skill_storage(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/search_skills_sh", (r, w) => {
    self.handle_search_skills_sh(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/search_skills_sh", (r, w) => {
    self.handle_search_skills_sh(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_skills", (_, w) => {
    self.handle_get_skills(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_skills_for_app", (_, w) => {
    self.handle_get_skills(w)
  })
  router.add_handler(@httpx.Method::Post, "/install_skill", (r, w) => {
    self.handle_install_skill_legacy(r, w, "claude")
  })
  router.add_handler(@httpx.Method::Post, "/install_skill_for_app", (r, w) => {
    self.handle_install_skill_for_app(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/uninstall_skill", (r, w) => {
    self.handle_uninstall_skill_legacy(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/uninstall_skill_for_app", (r, w) => {
    self.handle_uninstall_skill_legacy(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_skill_repos", (_, w) => {
    self.handle_get_skill_repos(w)
  })
  router.add_handler(@httpx.Method::Post, "/add_skill_repo", (r, w) => {
    self.handle_add_skill_repo(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/remove_skill_repo", (r, w) => {
    self.handle_remove_skill_repo(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/install_skills_from_zip", (r, w) => {
    self.handle_install_skills_from_zip(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_app_config_path", (_, w) => {
    self.handle_get_app_config_path(w)
  })
  router.add_handler(@httpx.Method::Get, "/open_app_config_folder", (_, w) => {
    self.handle_open_app_config_folder(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_claude_common_config_snippet", (
    _,
    w,
  ) => self.handle_get_common_config_snippet(w, "claude"))
  router.add_handler(@httpx.Method::Post, "/set_claude_common_config_snippet", (
    r,
    w,
  ) => self.handle_set_common_config_snippet(r, w, "claude"))
  router.add_handler(@httpx.Method::Get, "/get_common_config_snippet", (r, w) => {
    self.handle_get_common_config_snippet_request(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_common_config_snippet", (r, w) => {
    self.handle_get_common_config_snippet_request(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_common_config_snippet", (r, w) => {
    self.handle_set_common_config_snippet_request(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/extract_common_config_snippet", (
    r,
    w,
  ) => self.handle_extract_common_config_snippet(r, w))
  router.add_handler(@httpx.Method::Post, "/extract_common_config_snippet", (
    r,
    w,
  ) => self.handle_extract_common_config_snippet(r, w))
  router.add_handler(@httpx.Method::Get, "/check_env_conflicts", (r, w) => {
    self.handle_check_env_conflicts(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/check_env_conflicts", (r, w) => {
    self.handle_check_env_conflicts(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_env_vars", (r, w) => {
    self.handle_delete_env_vars(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/restore_env_backup", (r, w) => {
    self.handle_restore_env_backup(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_claude_mcp_status", (_, w) => {
    self.handle_get_claude_mcp_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/read_claude_mcp_config", (_, w) => {
    self.handle_read_claude_mcp_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/upsert_claude_mcp_server", (r, w) => {
    self.handle_upsert_claude_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_claude_mcp_server", (r, w) => {
    self.handle_delete_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_claude_mcp_server", (r, w) => {
    self.handle_delete_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/validate_mcp_command", (r, w) => {
    self.handle_validate_mcp_command(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/validate_mcp_command", (r, w) => {
    self.handle_validate_mcp_command(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_mcp_config", (r, w) => {
    self.handle_get_mcp_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_mcp_config", (r, w) => {
    self.handle_get_mcp_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/upsert_mcp_server_in_config", (r, w) => {
    self.handle_upsert_mcp_server_in_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_mcp_server_in_config", (r, w) => {
    self.handle_delete_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_mcp_server_in_config", (
    r,
    w,
  ) => self.handle_delete_mcp_server(r, w))
  router.add_handler(@httpx.Method::Post, "/set_mcp_enabled", (r, w) => {
    self.handle_set_mcp_enabled(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_mcp_servers", (_, w) => {
    self.handle_get_mcp_servers(w)
  })
  router.add_handler(@httpx.Method::Post, "/upsert_mcp_server", (r, w) => {
    self.handle_upsert_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_mcp_server", (r, w) => {
    self.handle_delete_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_mcp_server", (r, w) => {
    self.handle_delete_mcp_server(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/toggle_mcp_app", (r, w) => {
    self.handle_toggle_mcp_app(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/import_mcp_from_apps", (_, w) => {
    self.handle_import_mcp_from_apps(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_prompts", (r, w) => {
    self.handle_get_prompts(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_prompts", (r, w) => {
    self.handle_get_prompts(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/upsert_prompt", (r, w) => {
    self.handle_upsert_prompt(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_prompt", (r, w) => {
    self.handle_delete_prompt(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_prompt", (r, w) => {
    self.handle_delete_prompt(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/enable_prompt", (r, w) => {
    self.handle_enable_prompt(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/import_prompt_from_file", (r, w) => {
    self.handle_import_prompt_from_file(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_current_prompt_file_content", (
    r,
    w,
  ) => self.handle_get_current_prompt_file_content(r, w))
  router.add_handler(@httpx.Method::Post, "/get_current_prompt_file_content", (
    r,
    w,
  ) => self.handle_get_current_prompt_file_content(r, w))
  router.add_handler(@httpx.Method::Get, "/proxy/status", (_, w) => {
    self.proxy.handle_proxy_status(
      w,
      self.usage,
      self.host,
      self.port,
      self.uptime_seconds(),
    )
  })
  router.add_handler(@httpx.Method::Get, "/get_proxy_status", (_, w) => {
    self.proxy.handle_proxy_status(
      w,
      self.usage,
      self.host,
      self.port,
      self.uptime_seconds(),
    )
  })
  router.add_handler(@httpx.Method::Post, "/start_proxy_server", (_, w) => {
    self.proxy.handle_proxy_start_server(w, self.started_at_ms)
  })
  router.add_handler(@httpx.Method::Post, "/stop_proxy_server", (_, w) => {
    self.proxy.handle_proxy_stop_server(w)
  })
  router.add_handler(@httpx.Method::Post, "/stop_proxy_with_restore", (_, w) => {
    self.proxy.handle_proxy_stop_with_restore(w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/config", (_, w) => {
    self.proxy.handle_proxy_config(
      w,
      live_takeover_active=self.proxy_takeover_active(),
    )
  })
  router.add_handler(@httpx.Method::Get, "/get_proxy_config", (_, w) => {
    self.proxy.handle_proxy_config(
      w,
      live_takeover_active=self.proxy_takeover_active(),
    )
  })
  router.add_handler(@httpx.Method::Post, "/proxy/config", (r, w) => {
    self.proxy.handle_proxy_update_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_proxy_config", (r, w) => {
    self.proxy.handle_proxy_update_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/global-config", (_, w) => {
    self.proxy.handle_proxy_global_config(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_global_proxy_config", (_, w) => {
    self.proxy.handle_proxy_global_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/global-config", (r, w) => {
    self.proxy.handle_proxy_update_global_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_global_proxy_config", (r, w) => {
    self.proxy.handle_proxy_update_global_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_settings", (_, w) => {
    self.handle_get_settings(w)
  })
  router.add_handler(@httpx.Method::Post, "/save_settings", (r, w) => {
    self.handle_save_settings(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/restart_app", (_, w) => {
    self.handle_restart_app(w)
  })
  router.add_handler(@httpx.Method::Post, "/install_update_and_restart", (_, w) => {
    self.handle_install_update_and_restart(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_app_config_dir_override", (_, w) => {
    self.handle_get_app_config_dir_override(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_app_config_dir_override", (r, w) => {
    self.handle_set_app_config_dir_override(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_auto_launch", (r, w) => {
    self.handle_set_auto_launch(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_auto_launch_status", (_, w) => {
    self.handle_get_auto_launch_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_rectifier_config", (_, w) => {
    self.handle_get_rectifier_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_rectifier_config", (r, w) => {
    self.handle_set_rectifier_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_optimizer_config", (_, w) => {
    self.handle_get_optimizer_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_optimizer_config", (r, w) => {
    self.handle_set_optimizer_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_copilot_optimizer_config", (_, w) => {
    self.handle_get_copilot_optimizer_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_copilot_optimizer_config", (
    r,
    w,
  ) => self.handle_set_copilot_optimizer_config(r, w))
  router.add_handler(@httpx.Method::Get, "/get_log_config", (_, w) => {
    self.handle_get_log_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_log_config", (r, w) => {
    self.handle_set_log_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_global_proxy_url", (_, w) => {
    self.proxy.handle_get_global_proxy_url(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_global_proxy_url", (r, w) => {
    self.proxy.handle_set_global_proxy_url(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/test_proxy_url", (r, w) => {
    self.proxy.handle_test_proxy_url(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/test_proxy_url", (r, w) => {
    self.proxy.handle_test_proxy_url(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_upstream_proxy_status", (_, w) => {
    self.proxy.handle_get_upstream_proxy_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/scan_local_proxies", (_, w) => {
    self.handle_scan_local_proxies(w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/app-config", (r, w) => {
    self.proxy.handle_proxy_app_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_proxy_config_for_app", (r, w) => {
    self.proxy.handle_proxy_app_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/app-config", (r, w) => {
    self.proxy.handle_proxy_update_app_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_proxy_config_for_app", (r, w) => {
    self.proxy.handle_proxy_update_app_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/default-cost-multiplier", (
    r,
    w,
  ) => self.proxy.handle_proxy_default_cost_multiplier(r, w))
  router.add_handler(@httpx.Method::Post, "/proxy/default-cost-multiplier", (
    r,
    w,
  ) => self.proxy.handle_proxy_set_default_cost_multiplier(r, w))
  router.add_handler(@httpx.Method::Post, "/set_default_cost_multiplier", (r, w) => {
    self.proxy.handle_proxy_set_default_cost_multiplier(r, w)
  })
  router.add_handler(
    @httpx.Method::Get,
    "/get_default_cost_multiplier_test_hook",
    (r, w) => self.proxy.handle_proxy_default_cost_multiplier(r, w),
  )
  router.add_handler(@httpx.Method::Get, "/get_default_cost_multiplier", (r, w) => {
    self.proxy.handle_proxy_default_cost_multiplier(r, w)
  })
  router.add_handler(
    @httpx.Method::Post,
    "/set_default_cost_multiplier_test_hook",
    (r, w) => self.proxy.handle_proxy_set_default_cost_multiplier_unit(r, w),
  )
  router.add_handler(@httpx.Method::Get, "/proxy/pricing-model-source", (r, w) => {
    self.proxy.handle_proxy_pricing_model_source(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/pricing-model-source", (r, w) => {
    self.proxy.handle_proxy_set_pricing_model_source(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_pricing_model_source", (r, w) => {
    self.proxy.handle_proxy_set_pricing_model_source(r, w)
  })
  router.add_handler(
    @httpx.Method::Get,
    "/get_pricing_model_source_test_hook",
    (r, w) => self.proxy.handle_proxy_pricing_model_source(r, w),
  )
  router.add_handler(@httpx.Method::Get, "/get_pricing_model_source", (r, w) => {
    self.proxy.handle_proxy_pricing_model_source(r, w)
  })
  router.add_handler(
    @httpx.Method::Post,
    "/set_pricing_model_source_test_hook",
    (r, w) => self.proxy.handle_proxy_set_pricing_model_source_unit(r, w),
  )
  router.add_handler(@httpx.Method::Get, "/proxy/provider-health", (r, w) => {
    self.proxy.handle_proxy_provider_health(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_provider_health", (r, w) => {
    self.proxy.handle_proxy_provider_health(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/circuit-breaker-config", (_, w) => {
    self.proxy.handle_proxy_circuit_breaker_config(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_circuit_breaker_config", (_, w) => {
    self.proxy.handle_proxy_circuit_breaker_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/circuit-breaker-config", (
    r,
    w,
  ) => self.proxy.handle_proxy_update_circuit_breaker_config(r, w))
  router.add_handler(@httpx.Method::Post, "/update_circuit_breaker_config", (
    r,
    w,
  ) => self.proxy.handle_proxy_update_circuit_breaker_config(r, w))
  router.add_handler(@httpx.Method::Get, "/proxy/circuit-breaker-stats", (r, w) => {
    self.proxy.handle_proxy_circuit_breaker_stats(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_circuit_breaker_stats", (_, w) => {
    self.proxy.handle_proxy_circuit_breaker_stats_moon_alias(w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/reset-circuit-breaker", (r, w) => {
    self.proxy.handle_proxy_reset_circuit_breaker(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/reset_circuit_breaker", (r, w) => {
    self.proxy.handle_proxy_reset_circuit_breaker(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/failover-queue", (r, w) => {
    self.proxy.handle_proxy_failover_queue(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_failover_queue", (r, w) => {
    self.proxy.handle_proxy_failover_queue(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/failover-queue", (r, w) => {
    self.proxy.handle_proxy_add_failover_queue(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/add_to_failover_queue", (r, w) => {
    self.proxy.handle_proxy_add_failover_queue(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/proxy/failover-queue", (r, w) => {
    self.proxy.handle_proxy_remove_failover_queue(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/remove_from_failover_queue", (
    r,
    w,
  ) => self.proxy.handle_proxy_remove_failover_queue(r, w))
  router.add_handler(@httpx.Method::Post, "/remove_from_failover_queue", (r, w) => {
    self.proxy.handle_proxy_remove_failover_queue(r, w)
  })
  router.add_handler(
    @httpx.Method::Get,
    "/proxy/available-failover-providers",
    (r, w) => self.proxy.handle_proxy_available_failover_providers(r, w),
  )
  router.add_handler(
    @httpx.Method::Get,
    "/get_available_providers_for_failover",
    (r, w) => self.proxy.handle_proxy_available_failover_providers(r, w),
  )
  router.add_handler(@httpx.Method::Get, "/proxy/auto-failover-enabled", (r, w) => {
    self.proxy.handle_proxy_auto_failover_enabled(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_auto_failover_enabled", (r, w) => {
    self.proxy.handle_proxy_auto_failover_enabled(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/auto-failover-enabled", (r, w) => {
    self.proxy.handle_proxy_set_auto_failover_enabled(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_auto_failover_enabled", (r, w) => {
    self.proxy.handle_proxy_set_auto_failover_enabled(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/takeover-status", (_, w) => {
    self.proxy.handle_proxy_takeover_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_proxy_takeover_status", (_, w) => {
    self.proxy.handle_proxy_takeover_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/is_live_takeover_active", (_, w) => {
    self.proxy.handle_proxy_live_takeover_active(w)
  })
  router.add_handler(@httpx.Method::Post, "/proxy/takeover-status", (r, w) => {
    self.proxy.handle_proxy_set_takeover_for_app(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_proxy_takeover_for_app", (r, w) => {
    self.proxy.handle_proxy_set_takeover_for_app(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/switch_proxy_provider", (r, w) => {
    self.handle_proxy_switch_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/sync_current_providers_live", (_, w) => {
    self.handle_sync_current_providers_live(w)
  })
  router.add_handler(@httpx.Method::Post, "/import_default_config", (r, w) => {
    self.handle_import_default_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/import_default_config_test_hook", (
    r,
    w,
  ) => self.handle_import_default_config(r, w))
  router.add_handler(@httpx.Method::Get, "/get_providers", (r, w) => {
    self.handle_get_providers(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_providers", (r, w) => {
    self.handle_get_providers(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_current_provider", (r, w) => {
    self.handle_get_current_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_current_provider", (r, w) => {
    self.handle_get_current_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/add_provider", (r, w) => {
    self.handle_add_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_provider", (r, w) => {
    self.handle_update_provider(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_provider", (r, w) => {
    self.handle_delete_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_provider", (r, w) => {
    self.handle_delete_provider(r, w)
  })
  router.add_handler(
    @httpx.Method::Delete,
    "/remove_provider_from_live_config",
    (r, w) => self.handle_remove_provider_from_live_config(r, w),
  )
  router.add_handler(@httpx.Method::Post, "/remove_provider_from_live_config", (
    r,
    w,
  ) => self.handle_remove_provider_from_live_config(r, w))
  router.add_handler(@httpx.Method::Post, "/switch_provider", (r, w) => {
    self.handle_switch_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/switch_provider_test_hook", (r, w) => {
    self.handle_switch_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/open_provider_terminal", (r, w) => {
    self.handle_open_provider_terminal(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_claude_desktop_status", (_, w) => {
    self.handle_get_claude_desktop_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_claude_desktop_default_routes", (
    _,
    w,
  ) => self.handle_get_claude_desktop_default_routes(w))
  router.add_handler(
    @httpx.Method::Post,
    "/import_claude_desktop_providers_from_claude",
    (_, w) => self.handle_import_claude_desktop_providers_from_claude(w),
  )
  router.add_handler(
    @httpx.Method::Post,
    "/ensure_claude_desktop_official_provider",
    (_, w) => self.handle_ensure_claude_desktop_official_provider(w),
  )
  router.add_handler(@httpx.Method::Get, "/read_live_provider_settings", (r, w) => {
    self.handle_read_live_provider_settings(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/read_live_provider_settings", (r, w) => {
    self.handle_read_live_provider_settings(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_claude_plugin_status", (_, w) => {
    self.handle_get_claude_plugin_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/read_claude_plugin_config", (_, w) => {
    self.handle_read_claude_plugin_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/apply_claude_plugin_config", (r, w) => {
    self.handle_apply_claude_plugin_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/is_claude_plugin_applied", (_, w) => {
    self.handle_is_claude_plugin_applied(w)
  })
  router.add_handler(@httpx.Method::Post, "/apply_claude_onboarding_skip", (
    _,
    w,
  ) => self.handle_apply_claude_onboarding_skip(w))
  router.add_handler(@httpx.Method::Post, "/clear_claude_onboarding_skip", (
    _,
    w,
  ) => self.handle_clear_claude_onboarding_skip(w))
  router.add_handler(@httpx.Method::Get, "/list_daily_memory_files", (_, w) => {
    self.handle_list_daily_memory_files(w)
  })
  router.add_handler(@httpx.Method::Get, "/read_daily_memory_file", (r, w) => {
    self.handle_read_daily_memory_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/read_daily_memory_file", (r, w) => {
    self.handle_read_daily_memory_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/write_daily_memory_file", (r, w) => {
    self.handle_write_daily_memory_file(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/search_daily_memory_files", (r, w) => {
    self.handle_search_daily_memory_files(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/search_daily_memory_files", (r, w) => {
    self.handle_search_daily_memory_files(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_daily_memory_file", (r, w) => {
    self.handle_delete_daily_memory_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_daily_memory_file", (r, w) => {
    self.handle_delete_daily_memory_file(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/read_workspace_file", (r, w) => {
    self.handle_read_workspace_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/read_workspace_file", (r, w) => {
    self.handle_read_workspace_file(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/write_workspace_file", (r, w) => {
    self.handle_write_workspace_file(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/open_workspace_directory", (r, w) => {
    self.handle_open_workspace_directory(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/open_workspace_directory", (r, w) => {
    self.handle_open_workspace_directory(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_opencode_live_provider_ids", (
    _,
    w,
  ) => self.handle_get_live_provider_ids(w, "opencode"))
  router.add_handler(@httpx.Method::Get, "/get_openclaw_live_provider_ids", (
    _,
    w,
  ) => self.handle_get_live_provider_ids(w, "openclaw"))
  router.add_handler(@httpx.Method::Get, "/get_openclaw_live_provider", (r, w) => {
    self.handle_get_live_provider(r, w, "openclaw")
  })
  router.add_handler(@httpx.Method::Post, "/get_openclaw_live_provider", (r, w) => {
    self.handle_get_live_provider(r, w, "openclaw")
  })
  router.add_handler(@httpx.Method::Get, "/scan_openclaw_config_health", (_, w) => {
    self.handle_scan_openclaw_config_health(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_openclaw_default_model", (_, w) => {
    self.handle_get_openclaw_default_model(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_openclaw_default_model", (r, w) => {
    self.handle_set_openclaw_default_model(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_openclaw_model_catalog", (_, w) => {
    self.handle_get_openclaw_model_catalog(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_openclaw_model_catalog", (r, w) => {
    self.handle_set_openclaw_model_catalog(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_openclaw_agents_defaults", (_, w) => {
    self.handle_get_openclaw_agents_defaults(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_openclaw_agents_defaults", (
    r,
    w,
  ) => self.handle_set_openclaw_agents_defaults(r, w))
  router.add_handler(@httpx.Method::Get, "/get_openclaw_env", (_, w) => {
    self.handle_get_openclaw_env(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_openclaw_env", (r, w) => {
    self.handle_set_openclaw_env(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_openclaw_tools", (_, w) => {
    self.handle_get_openclaw_tools(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_openclaw_tools", (r, w) => {
    self.handle_set_openclaw_tools(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_hermes_live_provider_ids", (_, w) => {
    self.handle_get_live_provider_ids(w, "hermes")
  })
  router.add_handler(@httpx.Method::Get, "/get_hermes_live_provider", (r, w) => {
    self.handle_get_live_provider(r, w, "hermes")
  })
  router.add_handler(@httpx.Method::Post, "/get_hermes_live_provider", (r, w) => {
    self.handle_get_live_provider(r, w, "hermes")
  })
  router.add_handler(@httpx.Method::Get, "/get_hermes_model_config", (_, w) => {
    self.handle_get_hermes_model_config(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_hermes_memory", (r, w) => {
    self.handle_get_hermes_memory(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_hermes_memory", (r, w) => {
    self.handle_get_hermes_memory(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/set_hermes_memory", (r, w) => {
    self.handle_set_hermes_memory(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_hermes_memory_limits", (_, w) => {
    self.handle_get_hermes_memory_limits(w)
  })
  router.add_handler(@httpx.Method::Post, "/set_hermes_memory_enabled", (r, w) => {
    self.handle_set_hermes_memory_enabled(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/open_hermes_web_ui", (r, w) => {
    self.handle_open_hermes_web_ui(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/open_hermes_web_ui", (r, w) => {
    self.handle_open_hermes_web_ui(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/launch_hermes_dashboard", (_, w) => {
    self.handle_launch_hermes_dashboard(w)
  })
  router.add_handler(
    @httpx.Method::Post,
    "/import_opencode_providers_from_live",
    (_, w) => self.handle_import_live_providers(w, "opencode"),
  )
  router.add_handler(
    @httpx.Method::Post,
    "/import_openclaw_providers_from_live",
    (_, w) => self.handle_import_live_providers(w, "openclaw"),
  )
  router.add_handler(
    @httpx.Method::Post,
    "/import_hermes_providers_from_live",
    (_, w) => self.handle_import_live_providers(w, "hermes"),
  )
  router.add_handler(@httpx.Method::Get, "/get_universal_providers", (_, w) => {
    self.handle_get_universal_providers(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_universal_provider", (r, w) => {
    self.handle_get_universal_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/upsert_universal_provider", (r, w) => {
    self.handle_upsert_universal_provider(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_universal_provider", (r, w) => {
    self.handle_delete_universal_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_universal_provider", (r, w) => {
    self.handle_delete_universal_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/sync_universal_provider", (r, w) => {
    self.handle_sync_universal_provider(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_provider_presets", (r, w) => {
    self.handle_get_provider_presets(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/test_api_endpoints", (r, w) => {
    self.handle_test_api_endpoints(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/test_api_endpoints", (r, w) => {
    self.handle_test_api_endpoints(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_providers_sort_order", (r, w) => {
    self.handle_update_providers_sort_order(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_custom_endpoints", (r, w) => {
    self.handle_get_custom_endpoints(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_custom_endpoints", (r, w) => {
    self.handle_get_custom_endpoints(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/add_custom_endpoint", (r, w) => {
    self.handle_add_custom_endpoint(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/remove_custom_endpoint", (r, w) => {
    self.handle_remove_custom_endpoint(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/remove_custom_endpoint", (r, w) => {
    self.handle_remove_custom_endpoint(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_endpoint_last_used", (r, w) => {
    self.handle_update_endpoint_last_used(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/proxy/running", (_, w) => {
    self.proxy.handle_proxy_running(w)
  })
  router.add_handler(@httpx.Method::Get, "/is_proxy_running", (_, w) => {
    self.proxy.handle_proxy_running(w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/logs", (r, w) => {
    self.usage.handle_usage_logs(r, w, self.pricing_override_rows())
  })
  router.add_handler(@httpx.Method::Post, "/usage/logs", (r, w) => {
    self.usage.handle_usage_logs(r, w, self.pricing_override_rows())
  })
  router.add_handler(@httpx.Method::Get, "/get_request_logs", (r, w) => {
    self.usage.handle_usage_logs(r, w, self.pricing_override_rows())
  })
  router.add_handler(@httpx.Method::Post, "/get_request_logs", (r, w) => {
    self.usage.handle_usage_logs(r, w, self.pricing_override_rows())
  })
  router.add_handler(@httpx.Method::Get, "/usage/summary", (r, w) => {
    self.usage.handle_usage_summary(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/summary", (r, w) => {
    self.usage.handle_usage_summary(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_usage_summary", (r, w) => {
    self.usage.handle_usage_summary(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_usage_summary", (r, w) => {
    self.usage.handle_usage_summary(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/summary/by-app", (r, w) => {
    self.usage.handle_usage_summary_by_app(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/summary/by-app", (r, w) => {
    self.usage.handle_usage_summary_by_app(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_usage_summary_by_app", (r, w) => {
    self.usage.handle_usage_summary_by_app(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_usage_summary_by_app", (r, w) => {
    self.usage.handle_usage_summary_by_app(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/trends", (r, w) => {
    self.usage.handle_usage_trends(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/trends", (r, w) => {
    self.usage.handle_usage_trends(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_usage_trends", (r, w) => {
    self.usage.handle_usage_trends(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_usage_trends", (r, w) => {
    self.usage.handle_usage_trends(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/provider-limits", (r, w) => {
    self.handle_usage_provider_limits(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/provider-limits", (r, w) => {
    self.handle_usage_provider_limits(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/check_provider_limits", (r, w) => {
    self.handle_usage_provider_limits(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/check_provider_limits", (r, w) => {
    self.handle_usage_provider_limits(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/provider-stats", (r, w) => {
    self.usage.handle_usage_provider_stats(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/provider-stats", (r, w) => {
    self.usage.handle_usage_provider_stats(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_provider_stats", (r, w) => {
    self.usage.handle_usage_provider_stats(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_provider_stats", (r, w) => {
    self.usage.handle_usage_provider_stats(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/model-stats", (r, w) => {
    self.usage.handle_usage_model_stats(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/model-stats", (r, w) => {
    self.usage.handle_usage_model_stats(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_model_stats", (r, w) => {
    self.usage.handle_usage_model_stats(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_model_stats", (r, w) => {
    self.usage.handle_usage_model_stats(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/data-sources", (_, w) => {
    self.usage.handle_usage_data_sources(w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/data-sources", (_, w) => {
    self.usage.handle_usage_data_sources(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_usage_data_sources", (_, w) => {
    self.usage.handle_usage_data_sources(w)
  })
  router.add_handler(@httpx.Method::Post, "/get_usage_data_sources", (_, w) => {
    self.usage.handle_usage_data_sources(w)
  })
  router.add_handler(@httpx.Method::Get, "/queryProviderUsage", (r, w) => {
    self.handle_query_provider_usage(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/queryProviderUsage", (r, w) => {
    self.handle_query_provider_usage(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_balance", (r, w) => {
    self.handle_get_balance(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_balance", (r, w) => {
    self.handle_get_balance(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_subscription_quota", (r, w) => {
    self.handle_get_subscription_quota(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_subscription_quota", (r, w) => {
    self.handle_get_subscription_quota(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_codex_oauth_quota", (r, w) => {
    self.handle_get_codex_oauth_quota(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_codex_oauth_quota", (r, w) => {
    self.handle_get_codex_oauth_quota(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_codex_oauth_models", (r, w) => {
    self.handle_get_codex_oauth_models(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_codex_oauth_models", (r, w) => {
    self.handle_get_codex_oauth_models(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_coding_plan_quota", (r, w) => {
    self.handle_get_coding_plan_quota(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_coding_plan_quota", (r, w) => {
    self.handle_get_coding_plan_quota(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/testUsageScript", (r, w) => {
    self.handle_test_usage_script(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/sync-session", (r, w) => {
    self.usage.handle_usage_sync_session(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/sync_session_usage", (r, w) => {
    self.usage.handle_usage_sync_session(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/list_sessions", (_, w) => {
    self.session.handle_list_sessions(w)
  })
  router.add_handler(@httpx.Method::Post, "/list_sessions", (_, w) => {
    self.session.handle_list_sessions(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_session_messages", (r, w) => {
    self.session.handle_get_session_messages(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/get_session_messages", (r, w) => {
    self.session.handle_get_session_messages(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/launch_session_terminal", (r, w) => {
    self.session.handle_launch_session_terminal(
      r,
      w,
      moon_session_terminal_from_settings(self.config.app_settings),
    )
  })
  router.add_handler(@httpx.Method::Post, "/delete_session", (r, w) => {
    self.session.handle_delete_session(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_sessions", (r, w) => {
    self.session.handle_delete_sessions(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/model-pricing", (_, w) => {
    self.handle_usage_model_pricing(w)
  })
  router.add_handler(@httpx.Method::Get, "/get_model_pricing", (_, w) => {
    self.handle_usage_model_pricing(w)
  })
  router.add_handler(@httpx.Method::Post, "/usage/model-pricing", (r, w) => {
    self.handle_usage_update_model_pricing(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/update_model_pricing", (r, w) => {
    self.handle_usage_update_model_pricing(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/usage/model-pricing", (r, w) => {
    self.handle_usage_delete_model_pricing(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/delete_model_pricing", (r, w) => {
    self.handle_usage_delete_model_pricing(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/delete_model_pricing", (r, w) => {
    self.handle_usage_delete_model_pricing(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/usage/request-detail/*path", (r, w) => {
    self.usage.handle_usage_request_detail(r, w, self.pricing_override_rows())
  })
  router.add_handler(@httpx.Method::Get, "/get_request_detail", (r, w) => {
    self.usage.handle_usage_request_detail(r, w, self.pricing_override_rows())
  })
  router.add_handler(@httpx.Method::Post, "/get_request_detail", (r, w) => {
    self.usage.handle_usage_request_detail(r, w, self.pricing_override_rows())
  })
  router.add_handler(@httpx.Method::Post, "/stream_check_provider", (r, w) => {
    self.handle_stream_check_provider(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/stream_check_provider", (r, w) => {
    self.handle_stream_check_provider(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/stream_check_all_providers", (r, w) => {
    self.handle_stream_check_all_providers(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/stream_check_all_providers", (r, w) => {
    self.handle_stream_check_all_providers(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/get_stream_check_config", (_, w) => {
    self.handle_get_stream_check_config(w)
  })
  router.add_handler(@httpx.Method::Post, "/save_stream_check_config", (r, w) => {
    self.handle_save_stream_check_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/fetch_models_for_config", (r, w) => {
    self.handle_fetch_models_for_config(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/fetch_models_for_config", (r, w) => {
    self.handle_fetch_models_for_config(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/auth_start_login", (r, w) => {
    self.handle_auth_start_login(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_start_login", (r, w) => {
    self.handle_auth_start_login(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/auth_poll_for_account", (r, w) => {
    self.handle_auth_poll_for_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_poll_for_account", (r, w) => {
    self.handle_auth_poll_for_account(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/auth_list_accounts", (r, w) => {
    self.handle_auth_list_accounts(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_list_accounts", (r, w) => {
    self.handle_auth_list_accounts(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/auth_get_status", (r, w) => {
    self.handle_auth_get_status(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_get_status", (r, w) => {
    self.handle_auth_get_status(r, w)
  })
  router.add_handler(@httpx.Method::Delete, "/auth_remove_account", (r, w) => {
    self.handle_auth_remove_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_remove_account", (r, w) => {
    self.handle_auth_remove_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_set_default_account", (r, w) => {
    self.handle_auth_set_default_account(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/auth_set_default_account", (r, w) => {
    self.handle_auth_set_default_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/auth_logout", (r, w) => {
    self.handle_auth_logout(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/auth_logout", (r, w) => {
    self.handle_auth_logout(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_start_device_flow", (r, w) => {
    self.handle_copilot_start_device_flow(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/copilot_start_device_flow", (r, w) => {
    self.handle_copilot_start_device_flow(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_poll_for_auth", (r, w) => {
    self.handle_copilot_poll_for_auth(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/copilot_poll_for_auth", (r, w) => {
    self.handle_copilot_poll_for_auth(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_poll_for_account", (r, w) => {
    self.handle_copilot_poll_for_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/copilot_poll_for_account", (r, w) => {
    self.handle_copilot_poll_for_account(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_list_accounts", (_, w) => {
    self.handle_copilot_list_accounts(w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_get_auth_status", (_, w) => {
    self.handle_copilot_get_auth_status(w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_is_authenticated", (_, w) => {
    self.handle_copilot_is_authenticated(w)
  })
  router.add_handler(@httpx.Method::Post, "/copilot_logout", (_, w) => {
    self.handle_copilot_logout(w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_logout", (_, w) => {
    self.handle_copilot_logout(w)
  })
  router.add_handler(@httpx.Method::Delete, "/copilot_remove_account", (r, w) => {
    self.handle_copilot_remove_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/copilot_remove_account", (r, w) => {
    self.handle_copilot_remove_account(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_set_default_account", (r, w) => {
    self.handle_copilot_set_default_account(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/copilot_set_default_account", (r, w) => {
    self.handle_copilot_set_default_account(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_get_token", (r, w) => {
    self.handle_copilot_get_token(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_get_token_for_account", (
    r,
    w,
  ) => self.handle_copilot_get_token(r, w))
  router.add_handler(@httpx.Method::Get, "/copilot_get_models", (r, w) => {
    self.handle_copilot_get_models(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_get_models_for_account", (
    r,
    w,
  ) => self.handle_copilot_get_models(r, w))
  router.add_handler(@httpx.Method::Get, "/copilot_get_usage", (r, w) => {
    self.handle_copilot_get_usage(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/copilot_get_usage_for_account", (
    r,
    w,
  ) => self.handle_copilot_get_usage(r, w))
  router.add_handler(@httpx.Method::Get, "/models", (_, w) => {
    self.handle_models(w)
  })
  router.add_handler(@httpx.Method::Get, "/v1/models", (_, w) => {
    self.handle_models(w)
  })
  router.add_handler(@httpx.Method::Get, "/claude-desktop/v1/models", (r, w) => {
    self.handle_claude_desktop_models(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/login", (r, w) => {
    self.handle_login(r, w)
  })
  router.set_not_found_handler(file_server.handler())
  let server = @httpx.Server::new(self.host, self.port, reuse_addr=true)
  self.logger.info("Gateway started on \{self.host}:\{server.port()}")
  server.serve(router.handler())
}
