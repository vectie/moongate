///|
test "HAR CLI dispatch uses offline importer and keeps OpenAPI command" {
  assert_eq(
    registered_cli_command_id([
      "moongate", "provider", "har", "--file", "capture.har", "--http",
    ]),
    Some("preview_har"),
  )
  assert_eq(
    registered_cli_command_id([
      "moongate", "provider", "openapi", "--file", "api.json",
    ]),
    Some("preview_openapi"),
  )
}
