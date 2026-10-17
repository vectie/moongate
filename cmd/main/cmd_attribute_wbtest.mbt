///|
test "saved workload attribution is a discoverable usage command" {
  assert_true(
    usage_cli_commands().any(command => {
      command.id == "attribute_usage_file" &&
      command.patterns.contains("usage attribute")
    }),
  )
}
