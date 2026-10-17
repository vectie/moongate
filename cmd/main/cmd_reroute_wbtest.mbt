///|
test "usage reroute dispatches to the local workload rehearsal" {
  assert_eq(
    registered_cli_command_route([
      "moongate", "usage", "reroute", "--file", "a", "--plan", "b",
    ]),
    Some(("usage", "reroute_usage_file")),
  )
}
