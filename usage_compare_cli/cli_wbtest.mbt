///|
test "comparison CLI options require two paths and reject ambiguous or unknown flags" {
  let options = parse_options([
    "--before", "one.csv", "--after", "two.json", "--app", "codex", "--report",
  ])
  assert_eq(options.get("--before"), Some("one.csv"))
  assert_eq(options.get("--report"), Some("true"))
  for
    args in [
      [],
      ["--before", "one.csv"],
      ["--before", "--after", "two.csv"],
      ["--before", "one.csv", "--before", "two.csv", "--after", "three.csv"],
      ["--before", "one.csv", "--after", "two.csv", "--reports"],
      ["--before", "one.csv", "--after", "two.csv", "--model"],
      ["--before", "one.csv", "--after", "two.csv", "--report", "--report"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Invalid options accepted")
    }
  }
}
