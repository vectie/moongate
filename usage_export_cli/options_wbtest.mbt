///|
test "export command validates paths views and duplicate options before reading" {
  let options = parse_options([
    "--file", "usage.csv", "--view", "summary", "--app", "codex",
  ])
  assert_eq(options.get("--view"), Some("summary"))
  for
    args in [
      [],
      ["--file"],
      ["--file", ""],
      ["--file", "a", "--file", "b"],
      ["--file", "a", "--view", "bad"],
      ["--file", "a", "--surprise", "x"],
      ["--file", "--view", "model"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Expected invalid options to raise")
    }
  }
}
