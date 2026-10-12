///|
test "HAR command accepts review and drilldown options" {
  let options = parse_options([
    "--file", "capture.har", "--method", "POST", "--status", "errors", "--origin",
    "https://host.invalid", "--entry", "2", "--report",
  ])
  assert_eq(options["--entry"], "2")
  assert_eq(options["--status"], "errors")
  assert_true(options.contains("--report"))
}

///|
test "HAR command rejects incomplete duplicate unknown and invalid entry options" {
  for
    args in [
      [],
      ["--file"],
      ["--file", ""],
      ["--file", "a", "--file", "b"],
      ["--file", "a", "--report", "--report"],
      ["--file", "a", "--bad"],
      ["--file", "a", "--entry", "0"],
      ["--file", "a", "--entry", "-1"],
      ["--file", "a", "--entry", "01"],
      ["--file", "a", "--entry", "200000000000000"],
      ["--file", "a", "--origin", "--report"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Invalid options accepted")
    }
  }
}

///|
test "CSV command permits filters and rejects competing formats" {
  let options = parse_options([
    "--file", "capture.har", "--csv", "--status", "errors", "--entry", "3",
  ])
  assert_true(options.contains("--csv"))
  for
    args in [
      ["--file", "x", "--report", "--csv"],
      ["--file", "x", "--csv", "--csv"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("accepted incompatible output modes")
    }
  }
}
