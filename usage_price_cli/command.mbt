///|
/// Shared local-only workflow for moongate usage price and price_usage.
pub async fn run(args : Array[String]) -> Unit {
  let options = parse_options(args)
  let path = options["--file"]
  let content = read_file(path)
  let rates = read_file(options["--rates"])
  match @usage_preview.price_usage_file_json(content, rates, source_name=path) {
    Err(error) => fail(error)
    Ok(result) =>
      if options.contains("--report") {
        guard result is Object(obj) && obj["report"] is String(report) else {
          fail("Missing pricing report")
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
    fail("Input exceeds the 4 MiB limit")
  }
  @io.Reader::read_all(file).text()
}

///|
fn parse_options(args : Array[String]) -> Map[String, String] raise {
  let options : Map[String, String] = Map([])
  for i = 0; i < args.length(); {
    let flag = args[i]
    if options.contains(flag) {
      fail("Duplicate option: \{flag}")
    }
    if flag == "--report" {
      options[flag] = "true"
      continue i + 1
    }
    if !["--file", "--rates"].contains(flag) {
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
  if !options.contains("--file") || !options.contains("--rates") {
    fail("Usage: price_usage --file FILE --rates RATE_CARD.json [--report]")
  }
  options
}
