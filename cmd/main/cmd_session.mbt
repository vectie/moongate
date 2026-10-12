///|
fn session_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "list_sessions", patterns: ["sessions list"], },
    { id: "preview_transcript_file", patterns: ["sessions preview"], },
    { id: "get_session_messages", patterns: ["sessions messages"], },
    { id: "launch_session_terminal", patterns: ["sessions terminal"], },
    { id: "delete_session", patterns: ["sessions delete"], },
    { id: "delete_sessions", patterns: ["sessions delete-many"], },
    { id: "read_omo_local_file", patterns: ["provider omo file"], },
    { id: "get_current_omo_provider_id", patterns: ["provider omo current"], },
    { id: "disable_current_omo", patterns: ["provider omo disable"], },
    { id: "read_omo_slim_local_file", patterns: ["provider omo-slim file"], },
    {
      id: "get_current_omo_slim_provider_id",
      patterns: ["provider omo-slim current"],
    },
    { id: "disable_current_omo_slim", patterns: ["provider omo-slim disable"], },
  ]
}

///|
async fn run_session_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "preview_transcript_file" => preview_transcript_file(args)
    "list_sessions" => check_usage_endpoint(args, "/sessions")
    "get_session_messages" =>
      check_usage_endpoint(args, session_messages_path(args))
    "launch_session_terminal" =>
      check_json_post_endpoint(
        args,
        launch_session_terminal_path(args),
        "Session",
      )
    "delete_session" =>
      check_json_post_endpoint(args, delete_session_path(args), "Session")
    "delete_sessions" => delete_sessions(args)
    "read_omo_local_file" => check_usage_endpoint(args, "/providers/omo/file")
    "get_current_omo_provider_id" =>
      check_usage_endpoint(args, "/providers/omo/current")
    "disable_current_omo" =>
      check_json_post_endpoint(args, "/providers/omo/disable", "OMO")
    "read_omo_slim_local_file" =>
      check_usage_endpoint(args, "/providers/omo-slim/file")
    "get_current_omo_slim_provider_id" =>
      check_usage_endpoint(args, "/providers/omo-slim/current")
    "disable_current_omo_slim" =>
      check_json_post_endpoint(args, "/providers/omo-slim/disable", "OMO")
    _ => ()
  }
}
