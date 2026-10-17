///|
test "usage import-otel routes to the shared local workflow" {
  assert_eq(
    registered_cli_command_id([
      "moongate", "usage", "import-otel", "--file", "traces.json",
    ]),
    Some("import_otel_usage"),
  )
  assert_eq(
    registered_cli_command_route(["moongate", "usage", "import-otel"]),
    Some(("usage", "import_otel_usage")),
  )
}
