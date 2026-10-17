///|
test "Insomnia options are strict and selectors are exact resource IDs" {
  let options = parse_options([
    "--file", "export.json", "--workspace", "wrk_one", "--folder", "fld_one", "--request",
    "req_one", "--http",
  ])
  assert_eq(options["--folder"], "fld_one")
  assert_eq(options["--http"], "true")
  for
    args in [
      [],
      ["--file"],
      ["--file", " "],
      ["--file", "x", "--file", "y"],
      ["--file", "x", "--http", "--http"],
      ["--file", "x", "--live"],
      ["--file", "x", "--folder", "--http"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Accepted invalid options")
    }
  }
}
