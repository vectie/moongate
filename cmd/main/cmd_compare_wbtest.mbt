///|
test "usage comparison command routes to the offline shared workflow" {
  assert_eq(
    registered_cli_command_id([
      "moongate", "usage", "compare", "--before", "before.csv", "--after", "after.json",
    ]),
    Some("compare_usage_files"),
  )
  assert_eq(
    registered_cli_command_route(["moongate", "usage", "compare"]),
    Some(("usage", "compare_usage_files")),
  )
}
