///|
test "ACP bridge has an explicit CLI command without changing normal startup" {
  assert_eq(
    registered_cli_command_id([
      "moongate", "acp", "serve", "--config", "/tmp/acp.json",
    ]),
    Some("serve_acp"),
  )
  assert_eq(registered_cli_command_id(["moongate", "start"]), Some("start"))
  assert_true(registered_cli_command_id(["moongate", "acp"]) is None)
}
