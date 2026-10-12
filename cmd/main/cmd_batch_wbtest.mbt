///|
test "Batch import command routes to the shared offline workflow" {
  assert_eq(
    registered_cli_command_id([
      "moongate", "usage", "import-batch", "--file", "results.jsonl",
    ]),
    Some("import_batch_usage"),
  )
  assert_eq(
    registered_cli_command_route(["moongate", "usage", "import-batch"]),
    Some(("usage", "import_batch_usage")),
  )
}
