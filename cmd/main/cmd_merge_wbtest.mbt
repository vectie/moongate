///|
test "usage merge command routes to the offline shared workflow" {
  assert_eq(
    registered_cli_command_id([
      "moongate", "usage", "merge", "--scope", "fixture", "--file", "one.json", "--file",
      "two.csv",
    ]),
    Some("merge_usage_files"),
  )
  assert_eq(
    registered_cli_command_route(["moongate", "usage", "merge"]),
    Some(("usage", "merge_usage_files")),
  )
}
