///|
async fn read_capture(path : String) -> String {
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let size = file.size()
  if size > 4L * 1024L * 1024L {
    fail("HAR file exceeds 4 MiB")
  }
  let bytes = file.read_exactly(size.to_int())
  if file.read_some(max_len=1) is Some(_) {
    fail("HAR file changed while reading")
  }
  @utf8.decode(bytes)
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
    if !["--baseline", "--candidate", "--method", "--origin"].contains(flag) {
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
  if !options.contains("--baseline") || !options.contains("--candidate") {
    fail(
      "Usage: compare_har --baseline BEFORE.har --candidate AFTER.har [--method POST] [--origin https://example.invalid] [--report]",
    )
  }
  options
}

///|
pub async fn run(args : Array[String]) -> Unit {
  let options = parse_options(args)
  let baseline = read_capture(options["--baseline"])
  let candidate = read_capture(options["--candidate"])
  match
    @har_diagnostics.compare_captures_json(
      baseline,
      candidate,
      request_method=options.get("--method").unwrap_or(""),
      origin=options.get("--origin").unwrap_or(""),
    ) {
    Err(message) => fail(message)
    Ok(result) =>
      if options.contains("--report") {
        guard result is Object(obj) && obj.get("report") is Some(String(report)) else {
          fail("missing comparison report")
        }
        println(report)
      } else {
        println(result.stringify(indent=2))
      }
  }
}
