///|
test "OTLP file and report options accept either order" {
  assert_eq(parse_options(["--file", "traces.json"]), ("traces.json", false))
  assert_eq(
    parse_options(["--report", "--file", "traces.jsonl"]),
    ("traces.jsonl", true),
  )
}

///|
test "OTLP invalid duplicated and content arguments reject before reading" {
  for
    args in [
      [],
      ["--file"],
      ["--file", " "],
      ["--file", "--report"],
      ["--file", "a", "--file", "b"],
      ["--file", "a", "--report", "--report"],
      ["--file", "a", "--url", "http://provider"],
      ["{}"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Expected invalid options")
    }
  }
}
