///|
test "requests har routes to shared offline diagnostics" {
  assert_eq(
    registered_cli_command_route(["moongate", "requests", "compare-har"]),
    Some(("requests", "compare_har")),
  )
  assert_eq(
    registered_cli_command_route([
      "moongate", "requests", "har", "--file", "capture.har",
    ]),
    Some(("requests", "inspect_har")),
  )
  assert_eq(
    registered_cli_command_id(["moongate", "provider", "har"]),
    Some("preview_har"),
  )
}
