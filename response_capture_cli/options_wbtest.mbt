///|
test "Responses CLI accepts repeated files but validates options before reading" {
  let (paths, options) = parse_options([
    "--file", "one.json", "--file", "two.sse", "--app", "tool", "--provider", "saved",
    "--report",
  ])
  assert_eq(paths, ["one.json", "two.sse"])
  assert_eq(options.get("--app"), Some("tool"))
  assert_eq(options.get("--provider"), Some("saved"))
  assert_true(options.contains("--report"))
  for
    args in [
      [],
      ["--file"],
      ["--file", "a", "--file", "a"],
      ["--file", "a", "--other", "x"],
      ["--file", "a", "--app", " "],
      ["--file", "a", "--report", "--report"],
      ["--file", "a", "--provider", "x", "--provider", "y"],
      ["--file", "--report"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Expected invalid options")
    }
  }
  let too_many : Array[String] = []
  for index in 0..<101 {
    too_many.push("--file")
    too_many.push("file-\{index}")
  }
  try parse_options(too_many) catch {
    _ => ()
  } noraise {
    _ => fail("Expected file count bound")
  }
}
