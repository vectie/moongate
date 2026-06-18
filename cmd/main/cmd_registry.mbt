///|
priv struct CliCommandSpec {
  id : String
  patterns : Array[String]
}

///|
priv struct CliCommandGroup {
  family : String
  commands : Array[CliCommandSpec]
}

///|
fn registered_cli_command_groups() -> Array[CliCommandGroup] {
  [
    {
      family: "core",
      commands: [
        { id: "help", patterns: ["help"] },
        { id: "version", patterns: ["version"] },
      ],
    },
    { family: "provider", commands: provider_cli_commands() },
    { family: "auth", commands: auth_cli_commands() },
    { family: "copilot", commands: copilot_cli_commands() },
    { family: "skill", commands: skill_cli_commands() },
    { family: "proxy", commands: proxy_cli_commands() },
    { family: "config", commands: config_cli_commands() },
    { family: "usage", commands: usage_cli_commands() },
    { family: "suite", commands: suite_cli_commands() },
    { family: "install", commands: install_cli_commands() },
    { family: "stream-check", commands: stream_check_cli_commands() },
    { family: "sync", commands: sync_cli_commands() },
    { family: "session", commands: session_cli_commands() },
    { family: "runtime", commands: runtime_cli_commands() },
    { family: "workspace", commands: workspace_cli_commands() },
  ]
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
  match registered_cli_command_route(args) {
    Some((_, command_id)) => Some(command_id)
    None => None
  }
}

///|
fn registered_cli_command_route(args : Array[String]) -> (String, String)? {
  for group in registered_cli_command_groups() {
    for command in group.commands {
      if cli_args_match_any_pattern(args, command.patterns) {
        return Some((group.family, command.id))
      }
    }
  }
  None
}

///|
async fn run_registered_cli_command(args : Array[String]) -> Bool {
  guard registered_cli_command_id(args) is Some(_) else { return false }
  match registered_cli_command_route(args) {
    Some(("install", command_id)) => {
      run_install_cli_command(command_id, args)
      true
    }
    Some(("auth", command_id)) => {
      run_auth_cli_command(command_id, args)
      true
    }
    Some(("copilot", command_id)) => {
      run_copilot_cli_command(command_id, args)
      true
    }
    Some(("skill", command_id)) => {
      run_skill_cli_command(command_id, args)
      true
    }
    Some(("config", command_id)) => {
      run_config_cli_command(command_id, args)
      true
    }
    Some(("stream-check", command_id)) => {
      run_stream_check_cli_command(command_id, args)
      true
    }
    Some(("proxy", command_id)) => {
      run_proxy_cli_command(command_id, args)
      true
    }
    Some(("provider", command_id)) => {
      run_provider_cli_command(command_id, args)
      true
    }
    Some(("workspace", command_id)) => {
      run_workspace_cli_command(command_id, args)
      true
    }
    Some(("runtime", command_id)) => {
      run_runtime_cli_command(command_id, args)
      true
    }
    Some(("sync", command_id)) => {
      run_sync_cli_command(command_id, args)
      true
    }
    Some(("session", command_id)) => {
      run_session_cli_command(command_id, args)
      true
    }
    Some(("usage", command_id)) => {
      run_usage_cli_command(command_id, args)
      true
    }
    Some(("suite", command_id)) => {
      run_suite_cli_command(command_id, args)
      true
    }
    Some(("core", "help")) => {
      print_help()
      true
    }
    Some(("core", "version")) => {
      println("moonstat v0.1.0")
      true
    }
    _ => false
  }
}
