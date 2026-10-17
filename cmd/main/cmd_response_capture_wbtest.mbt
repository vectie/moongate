///|
test "usage import-responses resolves to the saved capture workflow" {
  assert_eq(
    registered_cli_command_id([
      "moongate", "usage", "import-responses", "--file", "response.json",
    ]),
    Some("import_response_capture"),
  )
  assert_eq(
    registered_cli_command_route(["moongate", "usage", "import-responses"]),
    Some(("usage", "import_response_capture")),
  )
}
