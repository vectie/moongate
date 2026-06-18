///|
pub async fn start(args : ArrayView[String]) -> Unit {
  let arr = args.to_array()
  if run_registered_cli_command(arr) {
    return
  }
  match arr[1:] {
    ["start", ..] => start_gateway(arr)
    ["install", ..] => install_reroute(arr)
    ["uninstall"] | ["remove"] => uninstall_reroute()
    ["claude-desktop", "install", ..] => install_claude_desktop(arr)
    ["claude-desktop", "uninstall" | "remove", ..] => uninstall_claude_desktop()
    ["claude-desktop", "status", ..] => status_claude_desktop()
    ["codex", "install", ..] => install_codex(arr)
    ["codex", "uninstall" | "remove", ..] => uninstall_codex()
    ["codex", "status", ..] => status_codex()
    ["get_claude_config_status", ..] | ["get-claude-config-status", ..] =>
      check_usage_endpoint(arr, "/get_claude_config_status")
    ["get_config_status", ..] | ["get-config-status", ..] =>
      check_usage_endpoint(arr, config_app_path(arr, "/get_config_status"))
    ["get_claude_code_config_path", ..] | ["get-claude-code-config-path", ..] =>
      check_usage_endpoint(arr, "/get_claude_code_config_path")
    ["get_config_dir", ..] | ["get-config-dir", ..] =>
      check_usage_endpoint(arr, config_app_path(arr, "/get_config_dir"))
    ["open_config_folder", ..] | ["open-config-folder", ..] =>
      check_usage_endpoint(arr, config_app_path(arr, "/open_config_folder"))
    ["pick_directory", ..] | ["pick-directory", ..] =>
      check_usage_endpoint(arr, pick_directory_path(arr))
    ["open_external", ..] | ["open-external", ..] =>
      check_usage_endpoint(arr, open_external_path(arr))
    ["copy_text_to_clipboard", ..] | ["copy-text-to-clipboard", ..] =>
      check_usage_endpoint(arr, copy_text_to_clipboard_path(arr))
    ["check_for_updates", ..] | ["check-for-updates", ..] =>
      check_json_post_endpoint(arr, "/check_for_updates", "App shell")
    ["update_tray_menu", ..] | ["update-tray-menu", ..] =>
      check_json_post_endpoint(arr, "/update_tray_menu", "App shell")
    ["is_portable_mode", ..] | ["is-portable-mode", ..] =>
      check_usage_endpoint(arr, "/is_portable_mode")
    ["get_init_error", ..] | ["get-init-error", ..] =>
      check_usage_endpoint(arr, "/get_init_error")
    ["get_migration_result", ..] | ["get-migration-result", ..] =>
      check_usage_endpoint(arr, "/get_migration_result")
    ["get_skills_migration_result", ..] | ["get-skills-migration-result", ..] =>
      check_usage_endpoint(arr, "/get_skills_migration_result")
    ["get_tool_versions", ..] | ["get-tool-versions", ..] =>
      check_usage_endpoint(arr, tool_versions_path(arr))
    ["run_tool_lifecycle_action", ..] | ["run-tool-lifecycle-action", ..] =>
      run_tool_lifecycle_action(arr)
    ["probe_tool_installations", ..] | ["probe-tool-installations", ..] =>
      check_usage_endpoint(arr, tool_installations_path(arr))
    ["set_window_theme", ..] | ["set-window-theme", ..] =>
      check_usage_endpoint(arr, window_theme_path(arr))
    ["enter_lightweight_mode", ..] | ["enter-lightweight-mode", ..] =>
      check_json_post_endpoint(arr, "/enter_lightweight_mode", "App shell")
    ["exit_lightweight_mode", ..] | ["exit-lightweight-mode", ..] =>
      check_json_post_endpoint(arr, "/exit_lightweight_mode", "App shell")
    ["is_lightweight_mode", ..] | ["is-lightweight-mode", ..] =>
      check_usage_endpoint(arr, "/is_lightweight_mode")
    ["save_file_dialog", ..] | ["save-file-dialog", ..] =>
      check_usage_endpoint(arr, save_file_dialog_path(arr))
    ["export_config_to_file", ..] | ["export-config-to-file", ..] =>
      check_json_post_endpoint(
        arr,
        config_file_path(arr, "/export_config_to_file"),
        "Import/export",
      )
    ["import_config_from_file", ..] | ["import-config-from-file", ..] =>
      check_json_post_endpoint(
        arr,
        config_file_path(arr, "/import_config_from_file"),
        "Import/export",
      )
    ["create_db_backup", ..] | ["create-db-backup", ..] =>
      check_json_post_endpoint(arr, "/create_db_backup", "Import/export")
    ["list_db_backups", ..] | ["list-db-backups", ..] =>
      check_usage_endpoint(arr, "/list_db_backups")
    ["restore_db_backup", ..] | ["restore-db-backup", ..] =>
      check_json_post_endpoint(
        arr,
        db_backup_filename_path(arr, "/restore_db_backup"),
        "Import/export",
      )
    ["rename_db_backup", ..] | ["rename-db-backup", ..] =>
      check_json_post_endpoint(arr, db_backup_rename_path(arr), "Import/export")
    ["delete_db_backup", ..] | ["delete-db-backup", ..] =>
      check_json_post_endpoint(
        arr,
        db_backup_filename_path(arr, "/delete_db_backup"),
        "Import/export",
      )
    ["parse_deeplink", ..] | ["parse-deeplink", ..] =>
      check_usage_endpoint(arr, deeplink_url_path(arr, "/parse_deeplink"))
    ["merge_deeplink_config", ..] | ["merge-deeplink-config", ..] =>
      check_json_post_endpoint(
        arr,
        deeplink_request_path(arr, "/merge_deeplink_config"),
        "Deeplink",
      )
    ["import_from_deeplink", ..] | ["import-from-deeplink", ..] =>
      check_json_post_endpoint(
        arr,
        deeplink_request_path(arr, "/import_from_deeplink"),
        "Deeplink",
      )
    ["import_from_deeplink_unified", ..]
    | ["import-from-deeplink-unified", ..] =>
      check_json_post_endpoint(
        arr,
        deeplink_request_path(arr, "/import_from_deeplink_unified"),
        "Deeplink",
      )
    ["webdav_test_connection", ..] | ["webdav-test-connection", ..] =>
      check_json_post_endpoint(
        arr,
        sync_settings_path(arr, "/webdav_test_connection"),
        "Sync",
      )
    ["webdav_sync_upload", ..] | ["webdav-sync-upload", ..] =>
      check_json_post_endpoint(arr, "/webdav_sync_upload", "Sync")
    ["webdav_sync_download", ..] | ["webdav-sync-download", ..] =>
      check_json_post_endpoint(arr, "/webdav_sync_download", "Sync")
    ["webdav_sync_save_settings", ..] | ["webdav-sync-save-settings", ..] =>
      check_json_post_endpoint(
        arr,
        sync_settings_path(arr, "/webdav_sync_save_settings"),
        "Sync",
      )
    ["webdav_sync_fetch_remote_info", ..]
    | ["webdav-sync-fetch-remote-info", ..] =>
      check_usage_endpoint(arr, "/webdav_sync_fetch_remote_info")
    ["s3_test_connection", ..] | ["s3-test-connection", ..] =>
      check_json_post_endpoint(
        arr,
        sync_settings_path(arr, "/s3_test_connection"),
        "Sync",
      )
    ["s3_sync_upload", ..] | ["s3-sync-upload", ..] =>
      check_json_post_endpoint(arr, "/s3_sync_upload", "Sync")
    ["s3_sync_download", ..] | ["s3-sync-download", ..] =>
      check_json_post_endpoint(arr, "/s3_sync_download", "Sync")
    ["s3_sync_save_settings", ..] | ["s3-sync-save-settings", ..] =>
      check_json_post_endpoint(
        arr,
        sync_settings_path(arr, "/s3_sync_save_settings"),
        "Sync",
      )
    ["s3_sync_fetch_remote_info", ..] | ["s3-sync-fetch-remote-info", ..] =>
      check_usage_endpoint(arr, "/s3_sync_fetch_remote_info")
    ["list_sessions", ..] | ["list-sessions", ..] =>
      check_usage_endpoint(arr, "/list_sessions")
    ["get_session_messages", ..] | ["get-session-messages", ..] =>
      check_usage_endpoint(arr, session_messages_path(arr))
    ["launch_session_terminal", ..] | ["launch-session-terminal", ..] =>
      check_json_post_endpoint(
        arr,
        launch_session_terminal_path(arr),
        "Session",
      )
    ["delete_session", ..] | ["delete-session", ..] =>
      check_json_post_endpoint(arr, delete_session_path(arr), "Session")
    ["delete_sessions", ..] | ["delete-sessions", ..] => delete_sessions(arr)
    ["read_omo_local_file", ..] | ["read-omo-local-file", ..] =>
      check_usage_endpoint(arr, "/read_omo_local_file")
    ["get_current_omo_provider_id", ..] | ["get-current-omo-provider-id", ..] =>
      check_usage_endpoint(arr, "/get_current_omo_provider_id")
    ["disable_current_omo", ..] | ["disable-current-omo", ..] =>
      check_json_post_endpoint(arr, "/disable_current_omo", "OMO")
    ["read_omo_slim_local_file", ..] | ["read-omo-slim-local-file", ..] =>
      check_usage_endpoint(arr, "/read_omo_slim_local_file")
    ["get_current_omo_slim_provider_id", ..]
    | ["get-current-omo-slim-provider-id", ..] =>
      check_usage_endpoint(arr, "/get_current_omo_slim_provider_id")
    ["disable_current_omo_slim", ..] | ["disable-current-omo-slim", ..] =>
      check_json_post_endpoint(arr, "/disable_current_omo_slim", "OMO")
    ["open_file_dialog", ..] | ["open-file-dialog", ..] =>
      check_usage_endpoint(arr, "/open_file_dialog")
    ["open_zip_file_dialog", ..] | ["open-zip-file-dialog", ..] =>
      check_usage_endpoint(arr, "/open_zip_file_dialog")
    ["get_installed_skills", ..] | ["get-installed-skills", ..] =>
      check_usage_endpoint(arr, "/get_installed_skills")
    ["get_skill_backups", ..] | ["get-skill-backups", ..] =>
      check_usage_endpoint(arr, "/get_skill_backups")
    ["delete_skill_backup", ..] | ["delete-skill-backup", ..] =>
      check_json_post_endpoint(
        arr,
        skill_backup_id_path(arr, "/delete_skill_backup"),
        "Skills",
      )
    ["restore_skill_backup", ..] | ["restore-skill-backup", ..] =>
      check_json_post_endpoint(arr, skill_restore_backup_path(arr), "Skills")
    ["install_skill_unified", ..] | ["install-skill-unified", ..] =>
      check_json_post_endpoint(
        arr,
        skill_install_path(arr, "/install_skill_unified"),
        "Skills",
      )
    ["uninstall_skill_unified", ..] | ["uninstall-skill-unified", ..] =>
      check_json_post_endpoint(
        arr,
        skill_id_path(arr, "/uninstall_skill_unified"),
        "Skills",
      )
    ["toggle_skill_app", ..] | ["toggle-skill-app", ..] =>
      check_json_post_endpoint(arr, skill_toggle_app_path(arr), "Skills")
    ["scan_unmanaged_skills", ..] | ["scan-unmanaged-skills", ..] =>
      check_usage_endpoint(arr, "/scan_unmanaged_skills")
    ["import_skills_from_apps", ..] | ["import-skills-from-apps", ..] =>
      import_skills_from_apps(arr)
    ["discover_available_skills", ..] | ["discover-available-skills", ..] =>
      check_usage_endpoint(arr, "/discover_available_skills")
    ["check_skill_updates", ..] | ["check-skill-updates", ..] =>
      check_usage_endpoint(arr, "/check_skill_updates")
    ["update_skill", ..] | ["update-skill", ..] =>
      check_json_post_endpoint(
        arr,
        skill_id_path(arr, "/update_skill"),
        "Skills",
      )
    ["migrate_skill_storage", ..] | ["migrate-skill-storage", ..] =>
      migrate_skill_storage(arr)
    ["search_skills_sh", ..] | ["search-skills-sh", ..] =>
      check_usage_endpoint(arr, skill_search_path(arr))
    ["get_skills", ..] | ["get-skills", ..] =>
      check_usage_endpoint(arr, "/get_skills")
    ["get_skills_for_app", ..] | ["get-skills-for-app", ..] =>
      check_usage_endpoint(arr, skill_app_path(arr, "/get_skills_for_app"))
    ["install_skill", ..] | ["install-skill", ..] =>
      check_json_post_endpoint(
        arr,
        skill_install_path(arr, "/install_skill"),
        "Skills",
      )
    ["install_skill_for_app", ..] | ["install-skill-for-app", ..] =>
      check_json_post_endpoint(
        arr,
        skill_install_path(arr, "/install_skill_for_app"),
        "Skills",
      )
    ["uninstall_skill", ..] | ["uninstall-skill", ..] =>
      check_json_post_endpoint(
        arr,
        skill_id_path(arr, "/uninstall_skill"),
        "Skills",
      )
    ["uninstall_skill_for_app", ..] | ["uninstall-skill-for-app", ..] =>
      check_json_post_endpoint(
        arr,
        skill_id_path(arr, "/uninstall_skill_for_app"),
        "Skills",
      )
    ["get_skill_repos", ..] | ["get-skill-repos", ..] =>
      check_usage_endpoint(arr, "/get_skill_repos")
    ["add_skill_repo", ..] | ["add-skill-repo", ..] =>
      check_json_post_endpoint(arr, skill_repo_add_path(arr), "Skills")
    ["remove_skill_repo", ..] | ["remove-skill-repo", ..] =>
      check_json_post_endpoint(arr, skill_repo_remove_path(arr), "Skills")
    ["install_skills_from_zip", ..] | ["install-skills-from-zip", ..] =>
      check_json_post_endpoint(arr, skill_zip_install_path(arr), "Skills")
    ["get_app_config_path", ..] | ["get-app-config-path", ..] =>
      check_usage_endpoint(arr, "/get_app_config_path")
    ["open_app_config_folder", ..] | ["open-app-config-folder", ..] =>
      check_usage_endpoint(arr, "/open_app_config_folder")
    ["get_claude_common_config_snippet", ..]
    | ["get-claude-common-config-snippet", ..] =>
      check_usage_endpoint(arr, "/get_claude_common_config_snippet")
    ["set_claude_common_config_snippet", ..]
    | ["set-claude-common-config-snippet", ..] =>
      set_config_snippet(
        arr,
        "/set_claude_common_config_snippet",
        app_required=false,
      )
    ["get_common_config_snippet", ..] | ["get-common-config-snippet", ..] =>
      check_usage_endpoint(
        arr,
        config_app_path(arr, "/get_common_config_snippet"),
      )
    ["set_common_config_snippet", ..] | ["set-common-config-snippet", ..] =>
      set_config_snippet(arr, "/set_common_config_snippet", app_required=true)
    ["extract_common_config_snippet", ..]
    | ["extract-common-config-snippet", ..] =>
      check_usage_endpoint(arr, extract_common_config_snippet_path(arr))
    ["check_env_conflicts", ..] | ["check-env-conflicts", ..] =>
      check_usage_endpoint(arr, config_app_path(arr, "/check_env_conflicts"))
    ["delete_env_vars", ..] | ["delete-env-vars", ..] => delete_env_vars(arr)
    ["restore_env_backup", ..] | ["restore-env-backup", ..] =>
      restore_env_backup(arr)
    ["help"] | ["--help"] | ["-h"] => print_help()
    ["version"] | ["--version"] | ["-v"] => println("moonstat v0.1.0")
    _ => print_help()
  }
}
