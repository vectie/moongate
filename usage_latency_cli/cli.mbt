///|
/// Shared file-based command, used by `moongate usage latency` and the small
/// offline companion. Arguments contain options only, excluding command names.
pub async fn run(args : Array[String]) -> Unit {
  let options = parse_options(args)
  let field = key => options.get(key).unwrap_or("")
  let content = read_file(field("--file"))
  match
    @usage_preview.profile_usage_latency_json(
      content,
      source_name=field("--file"),
      app=field("--app"),
      provider=field("--provider"),
      model=field("--model"),
      start_day=field("--start-day"),
      end_day=field("--end-day"),
    ) {
    Err(error) => fail(error)
    Ok(result) =>
      if options.contains("--report") {
        guard result is Object(obj) && obj.get("report") is Some(String(report)) else {
          fail("Missing latency profile report")
        }
        println(report)
      } else {
        println(result.stringify(indent=2))
      }
  }
}

///|
async fn read_file(path : String) -> String {
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  if file.size() > 4L * 1024L * 1024L {
    fail("Usage file exceeds the 4 MiB limit: \{path}")
  }
  @io.Reader::read_all(file).text()
}

///|
fn parse_options(args : Array[String]) -> Map[String, String] raise {
  let options : Map[String, String] = Map([])
  let valued = [
    "--file", "--app", "--provider", "--model", "--start-day", "--end-day",
  ]
  for i = 0; i < args.length(); {
    let flag = args[i]
    if options.contains(flag) {
      fail("Duplicate option: \{flag}")
    }
    if flag == "--report" {
      options[flag] = "true"
      continue i + 1
    }
    if !valued.contains(flag) {
      fail("Unknown option: \{flag}")
    }
    if i + 1 >= args.length() ||
      args[i + 1].has_prefix("--") ||
      args[i + 1].is_empty() {
      fail("Missing value for \{flag}")
    }
    options[flag] = args[i + 1]
    continue i + 2
  }
  if !options.contains("--file") {
    fail(
      "Usage: latency_usage --file FILE [--app VALUE] [--provider VALUE] [--model VALUE] [--start-day DAY] [--end-day DAY] [--report]",
    )
  }
  options
}
