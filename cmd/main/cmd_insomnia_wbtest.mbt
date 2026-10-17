///|
test "Insomnia CLI joins existing offline imports" {
  assert_eq(
    registered_cli_command_id([
      "moongate", "provider", "insomnia", "--file", "export.json", "--http",
    ]),
    Some("preview_insomnia"),
  )
  assert_eq(
    registered_cli_command_id(["moongate", "provider", "postman"]),
    Some("preview_postman"),
  )
  assert_eq(
    registered_cli_command_id(["moongate", "provider", "har"]),
    Some("preview_har"),
  )
}
