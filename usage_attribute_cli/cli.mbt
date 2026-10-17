///|
/// Offline workload attribution editor shared by both command entrypoints.
pub async fn run(args : Array[String]) -> Unit {
  let options = parse_options(args)
  let content = read_file(options["--file"])
  let plan = match options.get("--plan") {
    Some(path) => read_file(path)
    None => ""
  }
  let workload = options.get("--workload").unwrap_or("")
  let unassigned = options.contains("--unassigned")
  let scope = options["--scope"]
  let output = match
    @usage_preview.attribute_usage_file_json(
      content,
      scope~,
      plan~,
      workload~,
      unassigned~,
    ) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  if options.contains("--report") {
    guard output is Object(fields) &&
      fields.get("workloadReview") is Some(Object(review)) &&
      review.get("report") is Some(String(report)) else {
      fail("Missing report")
    }
    println(report)
  } else if options.get("--csv") is Some(view) {
    match
      @usage_preview.export_workload_csv(
        output.stringify(),
        scope~,
        view~,
        workload~,
        unassigned~,
      ) {
      Ok(csv) => println(csv)
      Err(error) => fail(error)
    }
  } else {
    println(output.stringify(indent=2))
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
    // Split only the option name. Keep the complete exact value after the first
    // equals sign, including leading dashes, spaces and further equals signs.
    let parts = args[i].split("=").collect()
    let flag = parts[0].to_owned()
    let inline_value = parts.length() > 1
    if options.contains(flag) {
      fail("Duplicate option: \{flag}")
    }
    if ["--report", "--unassigned"].contains(flag) {
      if inline_value {
        fail("Flag \{flag} does not accept a value")
      }
      options[flag] = "true"
      continue i + 1
    }
    if !["--file", "--scope", "--plan", "--workload", "--csv"].contains(flag) {
      fail("Unknown option: \{flag}")
    }
    if inline_value {
      let value = args[i][flag.length() + 1:].to_owned()
      if value.trim().is_empty() {
        fail("Missing value for \{flag}")
      }
      options[flag] = value
      continue i + 1
    }
    if i + 1 >= args.length() ||
      args[i + 1].has_prefix("--") ||
      args[i + 1].trim().is_empty() {
      fail("Missing value for \{flag}")
    }
    options[flag] = args[i + 1]
    continue i + 2
  }
  if !options.contains("--file") || !options.contains("--scope") {
    fail(
      "Usage: attribute_usage --file USAGE.json --scope NAMESPACE [--plan PLAN.json] [--workload LABEL | --unassigned] [--report | --csv groups|requests]",
    )
  }
  if options.contains("--workload") && options.contains("--unassigned") {
    fail("Choose workload or unassigned")
  }
  if options.contains("--report") && options.contains("--csv") {
    fail("Choose report or CSV")
  }
  if options.get("--csv") is Some(view) {
    if !["groups", "requests"].contains(view) {
      fail("CSV view must be groups or requests")
    }
    if view == "groups" &&
      (options.contains("--workload") || options.contains("--unassigned")) {
      fail("Group CSV covers all rows; filters apply to request CSV only")
    }
  }
  options
}
