///|
test "latency CLI requires one file and validates flags" {
  let options = parse_options([
    "--file", "one.csv", "--provider", "p", "--report",
  ])
  assert_eq(options.get("--file"), Some("one.csv"))
  for
    args in [
      [],
      ["--file"],
      ["--file", "--report"],
      ["--file", ""],
      ["--file", "a", "--file", "b"],
      ["--file", "a", "--report", "--report"],
      ["--file", "a", "--unknown"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Invalid options accepted")
    }
  }
}
