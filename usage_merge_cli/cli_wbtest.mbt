///|
test "merge CLI accepts ordered repeated file options and a required scope" {
  let (scope, paths, report) = parse_options([
    "--file", "one.csv", "--scope", "gateway-a", "--file", "two.json", "--file",
    "one.csv", "--report",
  ])
  assert_eq(scope, "gateway-a")
  assert_eq(paths, ["one.csv", "two.json", "one.csv"])
  assert_true(report)
}

///|
test "merge CLI refuses incomplete unknown duplicate and excessive options" {
  for
    args in [
      [],
      ["--scope", "x", "--file", "a"],
      ["--file", "a", "--file", "b"],
      ["--scope", " "],
      ["--scope", "x", "--file", "--file", "b"],
      ["--scope", "x", "--scope", "x", "--file", "a", "--file", "b"],
      ["--scope", "x", "--file", "a", "--file", "b", "--report", "--report"],
      ["--scope", "x", "--file", "a", "--file", "b", "--replace"],
      ["--scope", "x", "--file", "a", "--file", "b", "--report", "extra"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Invalid options accepted")
    }
  }
  let args = ["--scope", "x"]
  for _ in 0..<21 {
    args.push("--file")
    args.push("a")
  }
  try parse_options(args) catch {
    _ => ()
  } noraise {
    _ => fail("Too many files accepted")
  }
}
