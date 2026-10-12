///|
/// Shared offline command for `moongate requests har` and `inspect_har`.
pub async fn run(args : Array[String]) -> Unit {
  let options = parse_options(args)
  let value = key => options.get(key).unwrap_or("")
  let file = @fs.open(value("--file"), mode=ReadOnly)
  defer file.close()
  let size = file.size()
  if size > 4L * 1024L * 1024L {
    fail("HAR file exceeds 4 MiB")
  }
  let bytes = file.read_exactly(size.to_int())
  if file.read_some(max_len=1) is Some(_) {
    fail("HAR file changed while reading")
  }
  let content = @utf8.decode(bytes)
  let entry = if options.contains("--entry") {
    @string.parse_int(value("--entry"))
  } else {
    0
  }
  if options.contains("--csv") {
    match
      @har_diagnostics.export_capture_csv(
        content,
        request_method=value("--method"),
        status=value("--status"),
        origin=value("--origin"),
        entry~,
      ) {
      Err(error) => fail(error)
      Ok(csv) => @io.Writer::write(@stdio.stdout, csv)
    }
    return
  }
  match
    @har_diagnostics.inspect_capture_json(
      content,
      request_method=value("--method"),
      status=value("--status"),
      origin=value("--origin"),
      entry~,
    ) {
    Err(error) => fail(error)
    Ok(result) =>
      if options.contains("--report") {
        guard result is Object(obj) && obj.get("report") is Some(String(report)) else {
          fail("Missing diagnostic report")
        }
        println(report)
      } else {
        println(result.stringify(indent=2))
      }
  }
}

///|
fn parse_options(args : Array[String]) -> Map[String, String] raise {
  let options : Map[String, String] = Map([])
  for i = 0; i < args.length(); {
    let flag = args[i]
    if options.contains(flag) {
      fail("Duplicate option: \{flag}")
    }
    if flag == "--report" || flag == "--csv" {
      options[flag] = "true"
      continue i + 1
    }
    if !["--file", "--method", "--status", "--origin", "--entry"].contains(flag) {
      fail("Unknown option: \{flag}")
    }
    if i + 1 >= args.length() ||
      args[i + 1].has_prefix("--") ||
      args[i + 1].is_empty() {
      fail("Missing value for \{flag}")
    }
    let value = args[i + 1]
    if flag == "--entry" {
      let n = @string.parse_int(value) catch {
        _ => fail("Entry must be a positive original capture number")
      }
      if n < 1 || n.to_string() != value {
        fail("Entry must be a positive original capture number")
      }
    }
    options[flag] = value
    continue i + 2
  }
  if options.contains("--report") && options.contains("--csv") {
    fail("Choose either --report or --csv")
  }
  if !options.contains("--file") {
    fail(
      "Usage: inspect_har --file capture.har [--method POST] [--status errors|unknown|0|2xx|429] [--origin https://example.invalid] [--entry 1] [--report|--csv]",
    )
  }
  options
}
