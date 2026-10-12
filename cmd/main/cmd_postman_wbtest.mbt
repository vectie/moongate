///|
test "Postman CLI dispatch preserves existing offline import routes" {
  assert_eq(
    registered_cli_command_id([
      "moongate", "provider", "postman", "--file", "collection.json", "--http",
    ]),
    Some("preview_postman"),
  )
  assert_eq(
    registered_cli_command_id(["moongate", "provider", "har"]),
    Some("preview_har"),
  )
  assert_eq(
    registered_cli_command_id(["moongate", "provider", "openapi"]),
    Some("preview_openapi"),
  )
}
