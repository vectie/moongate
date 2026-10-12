///|
test "pricing CLI requires two paths and unambiguous flags" {
  let options = parse_options([
    "--file", "usage.csv", "--rates", "rates.json", "--report",
  ])
  assert_eq(options["--file"], "usage.csv")
  assert_eq(options["--report"], "true")
  for
    args in [
      [],
      ["--file", "a"],
      ["--rates", "b"],
      ["--file", "--rates", "b"],
      ["--file", "a", "--rates", ""],
      ["--file", "a", "--rates", "b", "--file", "c"],
      ["--file", "a", "--rates", "b", "--report", "--report"],
      ["--file", "a", "--rates", "b", "--model", "m"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Invalid arguments accepted")
    }
  }
}
