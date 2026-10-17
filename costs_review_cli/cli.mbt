///|
/// File-only, offline command shared by the main CLI and small companion.
pub async fn run(args : Array[String]) -> Unit {
  let options = parse_options(args)
  let option = key => options.get(key).unwrap_or("")
  let usage = read_file(option("--file"))
  let costs = read_file(option("--costs"))
  if options.contains("--csv") {
    match
      @costs_review.export_openai_costs_review_csv(
        usage,
        costs,
        provider=option("--provider"),
        scope=option("--scope"),
        app=option("--app"),
        project=option("--project"),
        line_item=option("--line-item"),
      ) {
      Ok(value) => @io.Writer::write(@stdio.stdout, value)
      Err(error) => fail(error)
    }
  } else {
    match
      @costs_review.review_openai_costs_json(
        usage,
        costs,
        provider=option("--provider"),
        scope=option("--scope"),
        app=option("--app"),
        project=option("--project"),
        line_item=option("--line-item"),
      ) {
      Ok(value) =>
        if options.contains("--report") {
          guard value is Object(fields) &&
            fields.get("report") is Some(String(report)) else {
            fail("Missing Costs review report")
          }
          @io.Writer::write(@stdio.stdout, report)
        } else {
          println(value.stringify(indent=2))
        }
      Err(error) => fail(error)
    }
  }
}

///|
async fn read_file(path : String) -> String {
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let bytes = @buffer.Buffer()
  while file.read_some(max_len=65536) is Some(chunk) {
    if chunk.length() > 4 * 1024 * 1024 - bytes.length() {
      fail("Costs review input exceeds 4 MiB")
    }
    bytes.write_bytes(chunk)
  }
  @utf8.decode(bytes.to_bytes())
}

///|
fn parse_options(args : Array[String]) -> Map[String, String] raise {
  let options : Map[String, String] = Map([])
  let valued = [
    "--file", "--costs", "--provider", "--scope", "--app", "--project", "--line-item",
  ]
  for i = 0; i < args.length(); {
    let flag = args[i]
    if options.contains(flag) {
      fail("Duplicate option: " + flag)
    }
    if flag == "--csv" || flag == "--report" {
      options[flag] = "true"
      continue i + 1
    }
    if !valued.contains(flag) {
      fail("Unknown Costs review option")
    }
    if i + 1 >= args.length() ||
      args[i + 1].has_prefix("--") ||
      args[i + 1].trim().is_empty() {
      fail("Missing value for " + flag)
    }
    options[flag] = args[i + 1]
    continue i + 2
  }
  for key in ["--file", "--costs", "--provider", "--scope"] {
    if !options.contains(key) {
      fail("Required option: " + key)
    }
  }
  if options.contains("--csv") && options.contains("--report") {
    fail("Choose only one of --csv and --report")
  }
  options
}
