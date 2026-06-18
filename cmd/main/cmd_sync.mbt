///|
fn sync_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "webdav_test_connection", patterns: ["sync webdav test"] },
    { id: "webdav_sync_upload", patterns: ["sync webdav upload"] },
    { id: "webdav_sync_download", patterns: ["sync webdav download"] },
    { id: "webdav_sync_save_settings", patterns: ["sync webdav settings"] },
    {
      id: "webdav_sync_fetch_remote_info",
      patterns: ["sync webdav remote-info"],
    },
    { id: "s3_test_connection", patterns: ["sync s3 test"] },
    { id: "s3_sync_upload", patterns: ["sync s3 upload"] },
    { id: "s3_sync_download", patterns: ["sync s3 download"] },
    { id: "s3_sync_save_settings", patterns: ["sync s3 settings"] },
    { id: "s3_sync_fetch_remote_info", patterns: ["sync s3 remote-info"] },
  ]
}

///|
fn cli_sync_command_id(command_id : String) -> Bool {
  match command_id {
    "webdav_test_connection"
    | "webdav_sync_upload"
    | "webdav_sync_download"
    | "webdav_sync_save_settings"
    | "webdav_sync_fetch_remote_info"
    | "s3_test_connection"
    | "s3_sync_upload"
    | "s3_sync_download"
    | "s3_sync_save_settings"
    | "s3_sync_fetch_remote_info" => true
    _ => false
  }
}

///|
async fn run_sync_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "webdav_test_connection" =>
      check_json_post_endpoint(
        args,
        sync_settings_path(args, "/sync/webdav/test"),
        "Sync",
      )
    "webdav_sync_upload" =>
      check_json_post_endpoint(args, "/sync/webdav/upload", "Sync")
    "webdav_sync_download" =>
      check_json_post_endpoint(args, "/sync/webdav/download", "Sync")
    "webdav_sync_save_settings" =>
      check_json_post_endpoint(
        args,
        sync_settings_path(args, "/sync/webdav/settings"),
        "Sync",
      )
    "webdav_sync_fetch_remote_info" =>
      check_usage_endpoint(args, "/sync/webdav/remote-info")
    "s3_test_connection" =>
      check_json_post_endpoint(
        args,
        sync_settings_path(args, "/sync/s3/test"),
        "Sync",
      )
    "s3_sync_upload" =>
      check_json_post_endpoint(args, "/sync/s3/upload", "Sync")
    "s3_sync_download" =>
      check_json_post_endpoint(args, "/sync/s3/download", "Sync")
    "s3_sync_save_settings" =>
      check_json_post_endpoint(
        args,
        sync_settings_path(args, "/sync/s3/settings"),
        "Sync",
      )
    "s3_sync_fetch_remote_info" =>
      check_usage_endpoint(args, "/sync/s3/remote-info")
    _ => ()
  }
}
