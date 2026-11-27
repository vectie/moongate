///|
fn parse_options(args : Array[String]) -> Map[String, String] raise {
  let options : Map[String, String] = Map([])
  for i = 0; i < args.length(); {
    let flag = args[i]
    guard !options.contains(flag) else { fail("Duplicate option: " + flag) }
    if flag == "--http" {
      options[flag] = "true"
      continue i + 1
    }
    guard ["--file", "--workspace", "--folder", "--request"].contains(flag) else {
      fail("Unknown option: " + flag)
    }
    guard i + 1 < args.length() &&
      !args[i + 1].has_prefix("--") &&
      !args[i + 1].trim().is_empty() else {
      fail("Missing value for " + flag)
    }
    options[flag] = args[i + 1]
    continue i + 2
  }
  guard options.contains("--file") else {
    fail("Required: --file EXPORT.json; use --help")
  }
  options
}

///|
/// Read one local export without modifying it. Select exact resource IDs from
/// the JSON inventory, then use --http to emit a separate editable collection.
pub async fn run(args : Array[String]) -> Unit {
  if args == ["--help"] || args == ["-h"] {
    println(
      "Usage: import_insomnia --file EXPORT.json [--workspace ID] [--folder ID] [--request ID] [--http]\nJSON includes inventory, source IDs and omissions. --http emits editable requests. Keep the original export; input is read-only. Legacy v4 JSON only; no requests or scripts execute. See docs/INSOMNIA_IMPORT.md.",
    )
    return
  }
  let options = parse_options(args)
  let file = @fs.open(options["--file"], mode=ReadOnly)
  defer file.close()
  let bytes = @buffer.Buffer()
  while file.read_some(max_len=65536) is Some(chunk) {
    guard chunk.length() <= 4 * 1024 * 1024 - bytes.length() else {
      fail("Insomnia input exceeds 4 MiB")
    }
    bytes.write_bytesview(chunk)
  }
  let result = @insomnia_import.import_collection(
    @utf8.decode(bytes.to_bytes()),
    workspace_id=options.get("--workspace").unwrap_or(""),
    folder_id=options.get("--folder").unwrap_or(""),
    request_id=options.get("--request").unwrap_or(""),
  )
  if options.contains("--http") {
    guard result is Object(fields) && fields.get("http") is Some(String(http)) else {
      fail("Missing HTTP collection")
    }
    @io.Writer::write(@stdio.stdout, http)
  } else {
    println(result.stringify(indent=2))
  }
}
