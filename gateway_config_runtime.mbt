///|
async fn ConfigService::handle_set_window_theme(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  self.window_theme = proxy_string_request(r.path, body, ["theme"]).unwrap_or(
    "system",
  )
  ignore(self.window_theme)
  write_usage_json(w, Json::null())
}

///|
async fn ConfigService::handle_enter_lightweight_mode(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.lightweight_mode = true
  write_usage_json(w, Json::null())
}

///|
async fn ConfigService::handle_exit_lightweight_mode(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.lightweight_mode = false
  write_usage_json(w, Json::null())
}

///|
async fn ConfigService::handle_is_lightweight_mode(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, Json::boolean(self.lightweight_mode))
}

///|
async fn ConfigService::handle_webdav_test_connection(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard moon_sync_settings_request(r.path, body) is Some(settings) else {
    write_usage_bad_request(w, "missing_settings")
    return
  }
  let normalized = moon_webdav_sync_settings_json(
    settings,
    moon_app_webdav_sync_json(self.app_settings),
    moon_sync_preserve_empty_password_request(r.path, body),
  )
  match moon_validate_webdav_sync_settings(normalized) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match moon_webdav_sync_test_connection_json(normalized) {
        Ok(result) => write_usage_json(w, result)
        Err(error) => write_usage_bad_request(w, error)
      }
  }
}

///|
async fn ConfigService::handle_webdav_sync_operation(
  self : ConfigService,
  proxy : ProxyService,
  host~ : String,
  port~ : Int,
  w : @httpx.ResponseWriter,
  operation : String,
) -> Unit {
  match moon_webdav_sync_required_error(self.app_settings) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match moon_app_webdav_sync_json(self.app_settings) {
        None => write_usage_bad_request(w, "WebDAV sync is not configured.")
        Some(settings) => {
          let result = match operation {
            "upload" =>
              self.moon_webdav_sync_upload_json(proxy, host~, port~, settings)
            "download" => self.moon_webdav_sync_download_json(proxy, settings)
            _ => Err("Unsupported WebDAV sync operation: \{operation}")
          }
          match result {
            Ok(json) => write_usage_json(w, json)
            Err(error) => write_usage_bad_request(w, error)
          }
        }
      }
  }
}

///|
async fn ConfigService::handle_webdav_sync_fetch_remote_info(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  match moon_webdav_sync_required_error(self.app_settings) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match moon_app_webdav_sync_json(self.app_settings) {
        None => write_usage_bad_request(w, "WebDAV sync is not configured.")
        Some(settings) =>
          match moon_webdav_sync_fetch_remote_info_json(settings) {
            Ok(info) => write_usage_json(w, info)
            Err(error) => write_usage_bad_request(w, error)
          }
      }
  }
}

///|
async fn ConfigService::handle_s3_test_connection(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard moon_sync_settings_request(r.path, body) is Some(settings) else {
    write_usage_bad_request(w, "missing_settings")
    return
  }
  let normalized = moon_s3_sync_settings_json(
    settings,
    moon_app_s3_sync_json(self.app_settings),
    moon_sync_preserve_empty_password_request(r.path, body),
  )
  match moon_validate_s3_sync_settings(normalized) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match moon_s3_sync_test_connection_json(normalized) {
        Ok(result) => write_usage_json(w, result)
        Err(error) => write_usage_bad_request(w, error)
      }
  }
}

///|
async fn ConfigService::handle_s3_sync_operation(
  self : ConfigService,
  proxy : ProxyService,
  host~ : String,
  port~ : Int,
  w : @httpx.ResponseWriter,
  operation : String,
) -> Unit {
  match moon_s3_sync_required_error(self.app_settings) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match moon_app_s3_sync_json(self.app_settings) {
        None => write_usage_bad_request(w, "S3 sync is not configured.")
        Some(settings) => {
          let result = match operation {
            "upload" =>
              self.moon_s3_sync_upload_json(proxy, host~, port~, settings)
            "download" => self.moon_s3_sync_download_json(proxy, settings)
            _ => Err("Unsupported S3 sync operation: \{operation}")
          }
          match result {
            Ok(json) => write_usage_json(w, json)
            Err(error) => write_usage_bad_request(w, error)
          }
        }
      }
  }
}

///|
async fn ConfigService::handle_s3_sync_fetch_remote_info(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  match moon_s3_sync_required_error(self.app_settings) {
    Some(error) => write_usage_bad_request(w, error)
    None =>
      match moon_app_s3_sync_json(self.app_settings) {
        None => write_usage_bad_request(w, "S3 sync is not configured.")
        Some(settings) =>
          match moon_s3_sync_fetch_remote_info_json(settings) {
            Ok(info) => write_usage_json(w, info)
            Err(error) => write_usage_bad_request(w, error)
          }
      }
  }
}

///|
async fn ConfigService::handle_set_auto_launch(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  guard proxy_bool_request(r.path, body, ["enabled"]) is Some(enabled) else {
    write_usage_bad_request(w, "invalid_auto_launch")
    return
  }
  self.auto_launch_enabled = enabled
  self.app_settings = moon_settings_with_bool(
    self.app_settings,
    "launchOnStartup",
    enabled,
  )
  write_usage_json(w, Json::boolean(true))
}

///|
async fn ConfigService::handle_get_auto_launch_status(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(w, Json::boolean(self.auto_launch_enabled))
}

///|
async fn ConfigService::handle_check_env_conflicts(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let app = moon_config_app_from_request(r.path, body).unwrap_or("claude")
  write_usage_json(w, moon_env_conflicts_json(app))
}

///|
async fn ConfigService::handle_delete_env_vars(
  self : ConfigService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  match moon_delete_env_vars_json(body) {
    Ok(backup) => write_usage_json(w, backup)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn ConfigService::handle_get_claude_plugin_status(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  write_usage_json(
    w,
    {
      "exists": Json::boolean(
        self.claude_plugin_config is Some(_) ||
        @fsx.exists_as_file(moon_claude_plugin_config_path()),
      ),
      "path": Json::string(moon_claude_plugin_config_path()),
    }.to_json(),
  )
}

///|
async fn ConfigService::handle_is_claude_plugin_applied(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  match self.claude_plugin_config {
    Some(content) =>
      write_usage_json(w, Json::boolean(moon_json_primary_api_key_any(content)))
    None =>
      if @fsx.exists_as_file(moon_claude_plugin_config_path()) {
        let content = @fsx.read_file(moon_claude_plugin_config_path()) catch {
          _ => {
            write_usage_json(w, Json::boolean(false))
            return
          }
        }
        write_usage_json(
          w,
          Json::boolean(moon_json_primary_api_key_any(content)),
        )
      } else {
        write_usage_json(w, Json::boolean(self.claude_plugin_applied))
      }
  }
}

///|
async fn ConfigService::handle_apply_claude_onboarding_skip(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.claude_onboarding_skipped = true
  self.app_settings = moon_settings_with_bool(
    self.app_settings,
    "skipClaudeOnboarding",
    true,
  )
  ignore(self.claude_onboarding_skipped)
  write_usage_json(w, Json::boolean(true))
}

///|
async fn ConfigService::handle_clear_claude_onboarding_skip(
  self : ConfigService,
  w : @httpx.ResponseWriter,
) -> Unit {
  self.claude_onboarding_skipped = false
  self.app_settings = moon_settings_with_bool(
    self.app_settings,
    "skipClaudeOnboarding",
    false,
  )
  ignore(self.claude_onboarding_skipped)
  write_usage_json(w, Json::boolean(true))
}
