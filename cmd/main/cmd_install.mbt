///|
fn install_cli_commands() -> Array[CliCommandSpec] {
  [
    { id: "start", patterns: ["start"] },
    { id: "install_reroute", patterns: ["install"] },
    { id: "uninstall_reroute", patterns: ["uninstall"] },
    { id: "install_claude_desktop", patterns: ["claude-desktop install"] },
    { id: "uninstall_claude_desktop", patterns: ["claude-desktop uninstall"] },
    { id: "status_claude_desktop", patterns: ["claude-desktop status"] },
    { id: "install_codex", patterns: ["codex install"] },
    { id: "uninstall_codex", patterns: ["codex uninstall"] },
    { id: "status_codex", patterns: ["codex status"] },
  ]
}

///|
fn cli_install_command_id(command_id : String) -> Bool {
  cli_command_id_in_specs(command_id, install_cli_commands())
}

///|
async fn run_install_cli_command(
  command_id : String,
  args : Array[String],
) -> Unit {
  match command_id {
    "start" => start_gateway(args)
    "install_reroute" => install_reroute(args)
    "uninstall_reroute" => uninstall_reroute()
    "install_claude_desktop" => install_claude_desktop(args)
    "uninstall_claude_desktop" => uninstall_claude_desktop()
    "status_claude_desktop" => status_claude_desktop()
    "install_codex" => install_codex(args)
    "uninstall_codex" => uninstall_codex()
    "status_codex" => status_codex()
    _ => ()
  }
}
