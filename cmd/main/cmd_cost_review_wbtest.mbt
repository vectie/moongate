///|
test "saved provider Costs review dispatches to offline command" {
  assert_eq(
    registered_cli_command_route([
      "moongate", "usage", "review-costs", "--file", "a", "--costs", "b", "--provider",
      "p", "--scope", "saved corresponding scope",
    ]),
    Some(("usage", "review_provider_costs")),
  )
}
