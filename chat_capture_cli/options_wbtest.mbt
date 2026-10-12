///|
test "capture command validates paths and options before reading" {
  let (paths, options) = parse_options([
    "--file", "one.json", "--file", "two.sse", "--app", "tool", "--report",
  ])
  assert_eq(paths, ["one.json", "two.sse"])
  assert_eq(options.get("--app"), Some("tool"))
  assert_true(options.contains("--report"))
  for
    args in [
      [],
      ["--file"],
      ["--file", "a", "--file", "a"],
      ["--file", "a", "--other", "x"],
      ["--file", "a", "--app", " "],
      ["--file", "a", "--report", "--report"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Expected invalid options")
    }
  }
}
