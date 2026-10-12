///|
test "usage price routes to the shared offline workflow" {
  assert_eq(
    registered_cli_command_id([
      "moongate", "usage", "price", "--file", "usage.csv", "--rates", "rates.json",
    ]),
    Some("price_usage_file"),
  )
  assert_eq(
    registered_cli_command_route(["moongate", "usage", "price"]),
    Some(("usage", "price_usage_file")),
  )
}
