///|
fn stream_check_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "stream_check_provider", patterns: ["stream-check provider"] },
    { id: "stream_check_all_providers", patterns: ["stream-check all"] },
    { id: "save_stream_check_config", patterns: ["stream-check config set"] },
    { id: "get_stream_check_config", patterns: ["stream-check config"] },
  ]
}

///|
fn cli_stream_check_command_id(command_id : String) -> Bool {
  cli_command_id_in_specs(command_id, stream_check_cli_commands())
}

///|
async fn run_stream_check_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "stream_check_provider" => stream_check_provider(args)
    "stream_check_all_providers" => stream_check_all_providers(args)
    "get_stream_check_config" =>
      check_usage_endpoint(args, "/proxy/stream-check/config")
    "save_stream_check_config" => save_stream_check_config(args)
    _ => ()
  }
}
