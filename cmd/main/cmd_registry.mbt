///|
priv struct CliCommandSpec {
  id : String
  patterns : Array[String]
}

///|
fn cli_command_id_in_specs(
  command_id : String,
  specs : Array[CliCommandSpec],
) -> Bool {
  for command in specs {
    if command.id == command_id {
      return true
    }
  }
  false
}

///|
fn registered_cli_commands() -> Array[CliCommandSpec] {
  let commands = [
    { id: "help", patterns: ["help", "--help", "-h"] },
    { id: "version", patterns: ["version", "--version", "-v"] },
  ]
  for command in provider_cli_commands() {
    commands.push(command)
  }
  for command in auth_cli_commands() {
    commands.push(command)
  }
  for command in copilot_cli_commands() {
    commands.push(command)
  }
  for command in skill_cli_commands() {
    commands.push(command)
  }
  for command in proxy_cli_commands() {
    commands.push(command)
  }
  for command in config_cli_commands() {
    commands.push(command)
  }
  for command in usage_cli_commands() {
    commands.push(command)
  }
  for command in suite_cli_commands() {
    commands.push(command)
  }
  for command in install_cli_commands() {
    commands.push(command)
  }
  for command in stream_check_cli_commands() {
    commands.push(command)
  }
  for command in sync_cli_commands() {
    commands.push(command)
  }
  for command in session_cli_commands() {
    commands.push(command)
  }
  for command in runtime_cli_commands() {
    commands.push(command)
  }
  for command in workspace_cli_commands() {
    commands.push(command)
  }
  commands
}

///|
fn cli_args_match_pattern(args : Array[String], pattern : String) -> Bool {
  let tokens = pattern.split(" ").collect()
  if args.length() < tokens.length() + 1 {
    return false
  }
  for index in 0..<tokens.length() {
    if args[index + 1] != tokens[index].to_owned() {
      return false
    }
  }
  if args.length() > tokens.length() + 1 {
    let next = args[tokens.length() + 1]
    if !next.has_prefix("-") {
      return false
    }
  }
  true
}

///|
fn cli_args_match_any_pattern(
  args : Array[String],
  patterns : Array[String],
) -> Bool {
  for pattern in patterns {
    if cli_args_match_pattern(args, pattern) {
      return true
    }
  }
  false
}

///|
fn registered_cli_command_id(args : Array[String]) -> String? {
  for command in registered_cli_commands() {
    if cli_args_match_any_pattern(args, command.patterns) {
      return Some(command.id)
    }
  }
  None
}

///|
async fn run_registered_cli_command(args : Array[String]) -> Bool {
  match registered_cli_command_id(args) {
    Some(command_id) if cli_install_command_id(command_id) => {
      run_install_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_auth_command_id(command_id) => {
      run_auth_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_copilot_command_id(command_id) => {
      run_copilot_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_skill_command_id(command_id) => {
      run_skill_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_config_command_id(command_id) => {
      run_config_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_stream_check_command_id(command_id) => {
      run_stream_check_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_proxy_command_id(command_id) => {
      run_proxy_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_provider_command_id(command_id) => {
      run_provider_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_workspace_command_id(command_id) => {
      run_workspace_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_runtime_command_id(command_id) => {
      run_runtime_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_sync_command_id(command_id) => {
      run_sync_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_session_command_id(command_id) => {
      run_session_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_usage_command_id(command_id) => {
      run_usage_cli_command(command_id, args)
      true
    }
    Some(command_id) if cli_suite_command_id(command_id) => {
      run_suite_cli_command(command_id, args)
      true
    }
    Some("help") => {
      print_help()
      true
    }
    Some("version") => {
      println("moonstat v0.1.0")
      true
    }
    _ => false
  }
}
