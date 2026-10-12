///|
/// File-based offline merge shared by the main CLI and the small companion.
pub async fn run(args : Array[String]) -> Unit {
  let (scope, paths, report) = parse_options(args)
  let files : Array[(String, String)] = []
  let mut bytes = 0L
  for path in paths {
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    bytes += file.size()
    if bytes > 4L * 1024L * 1024L {
      fail("Usage merge exceeds the combined 4 MiB limit")
    }
    files.push((path, @io.Reader::read_all(file).text()))
  }
  match @usage_preview.merge_usage_files_json(files, scope~) {
    Err(error) => fail(error)
    Ok(result) =>
      if report {
        guard result is Object(obj) && obj.get("report") is Some(String(text)) else {
          fail("Missing merge report")
        }
        println(text)
      } else {
        println(result.stringify(indent=2))
      }
  }
}

///|
fn parse_options(args : Array[String]) -> (String, Array[String], Bool) raise {
  let mut scope : String? = None
  let paths : Array[String] = []
  let mut report = false
  for i = 0; i < args.length(); {
    let flag = args[i]
    if flag == "--report" {
      if report {
        fail("Duplicate option: --report")
      }
      report = true
      continue i + 1
    }
    if flag != "--file" && flag != "--scope" {
      fail("Unknown option: \{flag}")
    }
    if i + 1 >= args.length() ||
      args[i + 1].has_prefix("--") ||
      args[i + 1].trim().is_empty() {
      fail("Missing value for \{flag}")
    }
    if flag == "--file" {
      paths.push(args[i + 1])
    } else {
      if scope is Some(_) {
        fail("Duplicate option: --scope")
      }
      scope = Some(args[i + 1])
    }
    continue i + 2
  }
  guard scope is Some(scope) && paths.length() >= 2 && paths.length() <= 20 else {
    fail(
      "Usage: merge_usage --scope NAME --file FILE --file FILE [--file FILE ...] [--report] (2 to 20 files from one request ID namespace)",
    )
  }
  (scope, paths, report)
}
