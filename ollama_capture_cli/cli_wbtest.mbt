///|
test "parse multiple isolated capture paths and labels" {
  let (paths, options) = parse_options([
    "--file", "a.json", "--file", "b.ndjson", "--app", "my-app", "--provider", "local",
    "--report",
  ])
  assert_eq(paths, ["a.json", "b.ndjson"])
  assert_eq(options["--app"], "my-app")
  assert_eq(options["--provider"], "local")
  assert_true(options.contains("--report"))
}

///|
test "invalid and duplicate CLI options reject before reading" {
  for
    args in [
      [],
      ["--file"],
      ["--file", "a", "--file", "a"],
      ["--file", "a", "--unknown"],
      ["--file", "a", "--report", "--report"],
      ["--file", "a", "--app", " "],
      ["--file", "a", "--app", "x", "--app", "y"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Expected invalid options")
    }
  }
}
