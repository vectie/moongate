///|
fn suite_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "suite_manifest", patterns: ["suite manifest"] },
    { id: "suite_status", patterns: ["suite status"] },
    { id: "suite_write_status", patterns: ["suite write-status"] },
    { id: "suite_moonclaw_providers", patterns: ["suite moonclaw-providers"] },
    {
      id: "suite_write_moonclaw_providers",
      patterns: ["suite write-moonclaw-providers"],
    },
  ]
}

///|
fn cli_suite_command_id(command_id : String) -> Bool {
  match command_id {
    "suite_manifest"
    | "suite_status"
    | "suite_write_status"
    | "suite_moonclaw_providers"
    | "suite_write_moonclaw_providers" => true
    _ => false
  }
}

///|
async fn run_suite_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "suite_manifest" => print_suite_manifest(args)
    "suite_status" => print_suite_status(args)
    "suite_write_status" => write_suite_status(args)
    "suite_moonclaw_providers" => print_moonclaw_providers_file(args)
    "suite_write_moonclaw_providers" => write_moonclaw_providers_file(args)
    _ => ()
  }
}

///|
async fn set_suite_json_config(
  args : Array[String],
  base_path : String,
  flag : String,
) -> Unit {
  guard suite_json_config_path(args, base_path, flag) is Some(path) else {
    let logger = @pino.logger("moonstat", @pino.Transport::console())
    logger.error("Missing required \{flag}")
    return
  }
  check_json_post_endpoint(args, path, "Suite")
}

///|
fn suite_json_config_path(
  args : Array[String],
  base_path : String,
  flag : String,
) -> String? {
  guard parse_string_arg(args, flag) is Some(raw) else { return None }
  let key = if flag.has_prefix("--") { flag[2:].to_owned() } else { flag }
  Some("\{base_path}?\{cli_query_pair(key, raw)}")
}

///|
fn print_suite_manifest(args : Array[String]) -> Unit {
  let host = parse_string_arg(args, "--host").unwrap_or(@suite.default_host())
  let port = parse_int_arg(args, "--port", default=@suite.default_port())
  let model = parse_string_arg(args, "--model").unwrap_or(
    @suite.default_model(),
  )
  println(
    @moonstat.moonstat_suite_manifest_json(host~, port~, model~).stringify(
      indent=2,
    ),
  )
}
