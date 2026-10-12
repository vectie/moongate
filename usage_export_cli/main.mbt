///|
/// Offline spreadsheet export shared by the main dispatcher and companion.
pub async fn run(args : Array[String]) -> Unit {
  let options = parse_options(args)
  let field = key => options.get(key).unwrap_or("")
  let path = field("--file")
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  if file.size() > 4L * 1024L * 1024L {
    fail("Usage file exceeds 4 MiB")
  }
  let content = @io.Reader::read_all(file).text()
  match
    @usage_preview.export_usage_csv(
      content,
      source_name=path,
      view=options.get("--view").unwrap_or("requests"),
      app=field("--app"),
      provider=field("--provider"),
      model=field("--model"),
      start_day=field("--start-day"),
      end_day=field("--end-day"),
    ) {
    Err(error) => fail(error)
    Ok(csv) => @io.Writer::write(@stdio.stdout, csv)
  }
}

///|
fn parse_options(args : Array[String]) -> Map[String, String] raise {
  let options : Map[String, String] = Map([])
  for i = 0; i < args.length(); {
    let flag = args[i]
    if ![
        "--file", "--view", "--app", "--provider", "--model", "--start-day", "--end-day",
      ].contains(flag) {
      fail("Unknown option: \{flag}")
    }
    if options.contains(flag) {
      fail("Duplicate option: \{flag}")
    }
    if i + 1 >= args.length() ||
      args[i + 1].is_empty() ||
      args[i + 1].has_prefix("--") {
      fail("Missing value: \{flag}")
    }
    options[flag] = args[i + 1]
    continue i + 2
  }
  if !options.contains("--file") {
    fail(
      "Usage: export_usage_csv --file FILE [--view requests|summary|model|provider|app|day] [--app LABEL] [--provider LABEL] [--model LABEL] [--start-day YYYY-MM-DD] [--end-day YYYY-MM-DD]",
    )
  }
  if options.get("--view") is Some(view) &&
    !["requests", "summary", "model", "provider", "app", "day"].contains(view) {
    fail("Invalid view")
  }
  options
}
