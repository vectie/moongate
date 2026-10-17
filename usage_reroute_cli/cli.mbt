///|
/// Local-only workload cost rehearsal, shared by both command entrypoints.
pub async fn run(args : Array[String]) -> Unit {
  let options = parse_options(args)
  let usage = read_file(options["--file"])
  let plan = read_file(options["--plan"])
  match
    @usage_preview.reroute_usage_file_json(
      usage,
      plan,
      source_name=options["--file"],
    ) {
    Err(error) => fail(error)
    Ok(result) =>
      if options.contains("--report") {
        guard result is Object(fields) &&
          fields.get("report") is Some(String(report)) else {
          fail("Missing route rehearsal report")
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
    fail("Input exceeds 4 MiB")
  }
  let bytes = @buffer.Buffer()
  while file.read_some(max_len=65536) is Some(chunk) {
    if chunk.length() > 4 * 1024 * 1024 - bytes.length() {
      fail("Input exceeds 4 MiB")
    }
    bytes.write_bytes(chunk)
  }
  @utf8.decode(bytes.to_bytes())
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
    if !["--file", "--plan"].contains(flag) {
      fail("Unknown option: \{flag}")
    }
    if i + 1 >= args.length() ||
      args[i + 1].has_prefix("--") ||
      args[i + 1].trim().is_empty() {
      fail("Missing value for \{flag}")
    }
    options[flag] = args[i + 1]
    continue i + 2
  }
  if !options.contains("--file") || !options.contains("--plan") {
    fail("Usage: reroute_usage --file USAGE --plan ROUTE_PLAN.json [--report]")
  }
  options
}
