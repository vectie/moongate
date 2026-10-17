///|
test "route rehearsal CLI accepts one file plan and optional report" {
  assert_eq(
    parse_options(["--file", "usage.csv", "--plan", "plan.json", "--report"])["--plan"],
    "plan.json",
  )
  for
    args in [
      [],
      ["--file", "a"],
      ["--plan", "b"],
      ["--file", "--plan", "b"],
      ["--file", " ", "--plan", "b"],
      ["--file", "a", "--plan", "b", "--file", "c"],
      ["--file", "a", "--plan", "b", "--report", "--report"],
      ["--file", "a", "--plan", "b", "--live"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Accepted invalid args")
    }
  }
}
