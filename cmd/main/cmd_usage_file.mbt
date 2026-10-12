///|
async fn preview_usage_file(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--file") is Some(path) else {
    fail(
      "Use usage preview --file <usage.json|usage.jsonl> [--app value] [--provider value] [--model value] [--start-day YYYY-MM-DD] [--end-day YYYY-MM-DD] [--report]",
    )
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  if file.size() > 4L * 1024L * 1024L {
    fail("Usage file exceeds the 4 MiB limit")
  }
  let content = @io.Reader::read_all(file).text()
  let field = key => parse_string_arg(args, key).unwrap_or("")
  match
    @moongate.moongate_preview_usage_file_json(
      content,
      source_name=path,
      app=field("--app"),
      provider=field("--provider"),
      model=field("--model"),
      start_day=field("--start-day"),
      end_day=field("--end-day"),
    ) {
    Ok(result) =>
      if args.contains("--report") &&
        result is Object(obj) &&
        obj.get("report") is Some(String(report)) {
        println(report)
      } else {
        println(result.stringify(indent=2))
      }
    Err(error) => fail(error)
  }
}
