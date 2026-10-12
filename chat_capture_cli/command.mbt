///|
/// Options exclude executable and command names. Reads saved files only.
pub async fn run(args : Array[String]) -> Unit {
  let (paths, options) = parse_options(args)
  let captures = []
  let mut size = 0L
  for path in paths {
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    let bytes = file.size()
    if bytes > 4L * 1024L * 1024L - size {
      fail("Captures exceed the combined 4 MiB input limit")
    }
    size += bytes
    captures.push((path, @io.Reader::read_all(file).text()))
  }
  match
    @chat_capture.import_chat_captures_json(
      captures,
      app=options.get("--app").unwrap_or("chat-capture"),
      provider=options.get("--provider").unwrap_or("openai-compatible-export"),
    ) {
    Err(error) => fail(error)
    Ok(result) =>
      if options.contains("--report") {
        guard result is Object(fields) &&
          fields.get("report") is Some(String(report)) else {
          fail("Missing capture report")
        }
        println(report)
      } else {
        println(result.stringify(indent=2))
      }
  }
}

///|
fn parse_options(
  args : Array[String],
) -> (Array[String], Map[String, String]) raise {
  let paths : Array[String] = []
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
    if !["--file", "--app", "--provider"].contains(flag) {
      fail("Unknown option: \{flag}")
    }
    if i + 1 >= args.length() ||
      args[i + 1].has_prefix("--") ||
      args[i + 1].trim().is_empty() {
      fail("Missing value for \{flag}")
    }
    if flag == "--file" {
      if paths.contains(args[i + 1]) {
        fail("Duplicate capture path")
      }
      paths.push(args[i + 1])
      if paths.length() > 100 {
        fail("Supply at most 100 capture files")
      }
    } else {
      options[flag] = args[i + 1]
    }
    continue i + 2
  }
  if paths.is_empty() {
    fail(
      "Usage: import_chat_capture --file CAPTURE [--file CAPTURE ...] [--app LABEL] [--provider LABEL] [--report]",
    )
  }
  (paths, options)
}
