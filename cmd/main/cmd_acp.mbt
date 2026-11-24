///|
fn acp_cli_commands() -> Array[CliCommandSpec] {
  [{ id: "serve_acp", patterns: ["acp serve"], }]
}

///|
async fn run_acp_cli_command(args : Array[String]) -> Unit {
  let mut config_path = ""
  let mut port = 15724
  for index = 3; index < args.length(); {
    guard index + 1 < args.length() else {
      fail("Usage: moongate acp serve --config FILE [--port 15724]")
    }
    match args[index] {
      "--config" => config_path = args[index + 1]
      "--port" => port = @string.parse_int(args[index + 1])
      _ => fail("Unknown ACP option: \{args[index]}")
    }
    continue index + 2
  }
  guard config_path != "" else {
    fail("Usage: moongate acp serve --config FILE [--port 15724]")
  }
  let config = @json.parse(@fsx.read_file(config_path))
  let bridge = @acp_gateway.Bridge::from_json(config)
  bridge.serve(port~)
}
