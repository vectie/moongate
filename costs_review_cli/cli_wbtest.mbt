///|
test "Costs CLI requires explicit scope and accepts alternative output formats" {
  let base = [
    "--file", "usage.csv", "--costs", "costs.json", "--provider", "p", "--scope",
    "same selected activity",
  ]
  assert_eq(parse_options(base + ["--csv"])["--csv"], "true")
  assert_eq(
    parse_options(
      base +
      [
        "--project", "proj", "--app", "editor", "--line-item", "text", "--report",
      ],
    )["--project"],
    "proj",
  )
  for
    args in [
      [],
      ["--file", "a"],
      base + ["--csv", "--report"],
      base + ["--csv", "--csv"],
      base + ["--live"],
      base + ["--project", " "],
      base + ["--file", "again"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Accepted invalid arguments")
    }
  }
}
