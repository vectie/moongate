///|
test "curl CLI joins existing offline imports" {
  assert_eq(
    registered_cli_command_id([
      "moongate", "provider", "curl", "--file", "request.curl",
    ]),
    Some("preview_curl"),
  )
  assert_eq(
    registered_cli_command_id(["moongate", "provider", "postman"]),
    Some("preview_postman"),
  )
}
