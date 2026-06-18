///|
fn runtime_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "pick_directory", patterns: ["files directory pick"] },
    { id: "open_external", patterns: ["runtime open-external"] },
    { id: "copy_text_to_clipboard", patterns: ["runtime copy-text"] },
    { id: "check_for_updates", patterns: ["runtime updates check"] },
    { id: "update_tray_menu", patterns: ["runtime tray-menu update"] },
    { id: "is_portable_mode", patterns: ["runtime portable-mode"] },
    { id: "get_tool_versions", patterns: ["tools versions"] },
    { id: "run_tool_lifecycle_action", patterns: ["tools lifecycle-action"] },
    { id: "probe_tool_installations", patterns: ["tools probe"] },
    { id: "set_window_theme", patterns: ["runtime window-theme set"] },
    { id: "enter_lightweight_mode", patterns: ["runtime lightweight enter"] },
    { id: "exit_lightweight_mode", patterns: ["runtime lightweight exit"] },
    { id: "is_lightweight_mode", patterns: ["runtime lightweight status"] },
    { id: "restart_app", patterns: ["runtime restart"] },
    {
      id: "install_update_and_restart",
      patterns: ["runtime updates install-restart"],
    },
  ]
}

///|
fn cli_runtime_command_id(command_id : String) -> Bool {
  cli_command_id_in_specs(command_id, runtime_cli_commands())
}

///|
async fn run_runtime_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "pick_directory" =>
      check_json_post_endpoint(args, pick_directory_path(args), "App shell")
    "open_external" =>
      check_json_post_endpoint(args, open_external_path(args), "App shell")
    "copy_text_to_clipboard" =>
      check_json_post_endpoint(
        args,
        copy_text_to_clipboard_path(args),
        "App shell",
      )
    "check_for_updates" =>
      check_json_post_endpoint(args, "/runtime/updates/check", "App shell")
    "update_tray_menu" =>
      check_json_post_endpoint(args, "/runtime/tray-menu/update", "App shell")
    "is_portable_mode" => check_usage_endpoint(args, "/runtime/portable-mode")
    "get_tool_versions" => check_usage_endpoint(args, tool_versions_path(args))
    "run_tool_lifecycle_action" => run_tool_lifecycle_action(args)
    "probe_tool_installations" =>
      check_usage_endpoint(args, tool_installations_path(args))
    "set_window_theme" =>
      check_json_post_endpoint(args, window_theme_path(args), "App shell")
    "enter_lightweight_mode" =>
      check_json_post_endpoint(
        args, "/runtime/lightweight-mode/enter", "App shell",
      )
    "exit_lightweight_mode" =>
      check_json_post_endpoint(
        args, "/runtime/lightweight-mode/exit", "App shell",
      )
    "is_lightweight_mode" =>
      check_usage_endpoint(args, "/runtime/lightweight-mode")
    "restart_app" =>
      check_json_post_endpoint(args, "/runtime/restart", "Settings")
    "install_update_and_restart" =>
      check_json_post_endpoint(
        args, "/runtime/updates/install-restart", "Settings",
      )
    _ => ()
  }
}
