///|
/// Shared file-based command, used by `moongate usage compare` and the small
/// offline companion. Arguments contain options only, excluding command names.
pub async fn run(args : Array[String]) -> Unit {
  let options = parse_options(args)
  let field = key => options.get(key).unwrap_or("")
  let before = read_file(field("--before"))
  let after = read_file(field("--after"))
  match
    @usage_preview.compare_usage_files_json(
      before,
      after,
      before_name=field("--before"),
      after_name=field("--after"),
      app=field("--app"),
      provider=field("--provider"),
      model=field("--model"),
      before_start_day=field("--before-start-day"),
      before_end_day=field("--before-end-day"),
      after_start_day=field("--after-start-day"),
      after_end_day=field("--after-end-day"),
    ) {
    Err(error) => fail(error)
    Ok(result) =>
      if options.contains("--report") {
        guard result is Object(obj) && obj.get("report") is Some(String(report)) else {
          fail("Missing comparison report")
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
    "--before", "--after", "--app", "--provider", "--model", "--before-start-day",
    "--before-end-day", "--after-start-day", "--after-end-day",
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
  if !options.contains("--before") || !options.contains("--after") {
    fail(
      "Usage: compare_usage --before FILE --after FILE [--app VALUE] [--provider VALUE] [--model VALUE] [--before-start-day YYYY-MM-DD] [--before-end-day YYYY-MM-DD] [--after-start-day YYYY-MM-DD] [--after-end-day YYYY-MM-DD] [--report]",
    )
  }
  options
}
