///|
/// Read one saved OTLP JSON/JSONL file. No contents are passed in arguments.
pub async fn run(args : Array[String]) -> Unit {
  let (path, report) = parse_options(args)
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  if file.size() > 4L * 1024L * 1024L {
    fail("OTLP file exceeds 4 MiB")
  }
  // Limit the actual read as well: a file may grow after the size check.
  let bytes = @buffer.Buffer()
  while file.read_some(max_len=65536) is Some(chunk) {
    if chunk.length() > 4 * 1024 * 1024 - bytes.length() {
      fail("OTLP file exceeds 4 MiB")
    }
    bytes.write_bytes(chunk)
  }
  match
    @otel_usage.import_otel_usage_json(
      @utf8.decode(bytes.to_bytes()),
      source_name=path,
    ) {
    Err(error) => fail(error)
    Ok(result) =>
      if report {
        guard result is Object(fields) &&
          fields.get("report") is Some(String(text)) else {
          fail("Internal OTLP report missing")
        }
        println(text)
      } else {
        println(result.stringify(indent=2))
      }
  }
}

///|
fn parse_options(args : Array[String]) -> (String, Bool) raise {
  let mut path : String? = None
  let mut report = false
  for i = 0; i < args.length(); {
    match args[i] {
      "--file" => {
        if path is Some(_) {
          fail("Duplicate --file option")
        }
        if i + 1 >= args.length() ||
          args[i + 1].has_prefix("--") ||
          args[i + 1].trim().is_empty() {
          fail("Missing path for --file")
        }
        path = Some(args[i + 1])
        continue i + 2
      }
      "--report" => {
        if report {
          fail("Duplicate --report option")
        }
        report = true
        continue i + 1
      }
      _ => fail("Unknown OTLP import option")
    }
  }
  guard path is Some(path) else {
    fail("Usage: import_otel_usage --file OTLP.json[l] [--report]")
  }
  (path, report)
}
