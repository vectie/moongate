///|
/// Shared offline file command. Options exclude executable and command names.
pub async fn run(args : Array[String]) -> Unit {
  let options = parse_options(args)
  let path = options.get("--file").unwrap()
  let mut content = read_file(path)
  let mut source_name = path
  if options.get("--errors") is Some(errors_path) {
    content += "\n" + read_file(errors_path)
    source_name += " + " + errors_path
  }
  let requests = match options.get("--requests") {
    Some(path) => Some(read_file(path))
    None => None
  }
  let format = options.get("--format").unwrap_or("openai")
  let result = if format == "anthropic" {
    @batch_usage.import_anthropic_batch_usage_json(
      content,
      source_name~,
      app=options.get("--app").unwrap_or("anthropic-batch"),
      provider=options.get("--provider").unwrap_or("anthropic-export"),
    )
  } else {
    @batch_usage.import_batch_usage_json(
      content,
      source_name~,
      requests?,
      app=options.get("--app").unwrap_or("openai-batch"),
      provider=options.get("--provider").unwrap_or("openai-export"),
    )
  }
  match result {
    Err(error) => fail(error)
    Ok(result) =>
      if options.contains("--report") {
        guard result is Object(obj) && obj.get("report") is Some(String(report)) else {
          fail("Missing Batch import report")
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
    fail("Batch file exceeds the 4 MiB limit")
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
    if !["--file", "--errors", "--requests", "--app", "--provider", "--format"].contains(
        flag,
      ) {
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
  if !options.contains("--file") {
    fail(
      "Usage: import_batch_usage --file RESULTS.jsonl [--format openai|anthropic] [--errors ERRORS.jsonl] [--requests INPUT.jsonl] [--app LABEL] [--provider LABEL] [--report]",
    )
  }
  let format = options.get("--format").unwrap_or("openai")
  if !["openai", "anthropic"].contains(format) {
    fail("--format must be openai or anthropic")
  }
  if format == "anthropic" && options.contains("--requests") {
    fail("--requests is supported only with --format openai")
  }
  options
}
