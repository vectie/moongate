///|
test "comparison command requires both named inputs and validates flags" {
  assert_eq(
    parse_options(["--baseline", "a", "--candidate", "b", "--report"])["--baseline"],
    "a",
  )
  for
    args in [
      [],
      ["--baseline", "a"],
      ["--candidate", "b"],
      ["--baseline", "a", "--candidate", "b", "--report", "--report"],
      ["--baseline", "a", "--candidate", "b", "--bad"],
      ["--baseline", "a", "--candidate", "b", "--method", ""],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("invalid flags accepted")
    }
  }
}
