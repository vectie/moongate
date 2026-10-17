///|
test "workload CLI accepts saved edits and selected exports but rejects ambiguous options" {
  let base = ["--file", "usage.json", "--scope", "fixture-run"]
  let options = parse_options(
    base +
    ["--plan", "plan.json", "--workload", "Research", "--csv", "requests"],
  )
  assert_eq(options["--workload"], "Research")
  for
    args in [
      [],
      ["--file", "usage.json"],
      base + ["--scope", "other"],
      base + ["--plan"],
      base + ["--unknown"],
      base + ["--report", "--csv", "groups"],
      base + ["--unassigned", "--workload", "Research"],
      base + ["--csv", "groups", "--unassigned"],
      base + ["--csv", "bad"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Expected invalid CLI arguments")
    }
  }
}

///|
test "inline values reopen every legal leading-dash label and retain exact text" {
  let base = ["--file=usage.json", "--scope=--run=2026"]
  let options = parse_options(base + ["--workload=--ops", "--csv=requests"])
  assert_eq(options["--scope"], "--run=2026")
  assert_eq(options["--workload"], "--ops")
  assert_eq(
    parse_options(base + ["--workload=  --ops=night  "])["--workload"],
    "  --ops=night  ",
  )
  assert_eq(
    parse_options(base + ["--workload=--report"])["--workload"],
    "--report",
  )
  for
    args in [
      base + ["--workload="],
      base + ["--scope= "],
      base + ["--report=true"],
      base + ["--unassigned=false"],
      base + ["--unknown=value"],
      base + ["--workload=--ops", "--workload", "Other"],
      base + ["--workload", "Other", "--workload=--ops"],
      base + ["--workload=--ops", "--unassigned"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Expected invalid inline CLI arguments")
    }
  }
}
