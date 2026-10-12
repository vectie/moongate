///|
async fn preview_har(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--file") is Some(path) else {
    fail(
      "Use provider har --file <capture.har> [--method POST] [--url-contains text] [--http]",
    )
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  if file.size() > 4L * 1024L * 1024L {
    fail("HAR file exceeds 4 MiB")
  }
  let content = @io.Reader::read_all(file).text()
  match
    @moongate.moongate_har_collection_json(
      content,
      request_method=parse_string_arg(args, "--method").unwrap_or(""),
      url_contains=parse_string_arg(args, "--url-contains").unwrap_or(""),
    ) {
    Ok(result) =>
      if args.contains("--http") &&
        result is Object(obj) &&
        obj.get("http") is Some(String(http)) {
        println(http)
      } else {
        println(result.stringify(indent=2))
      }
    Err(error) => fail(error)
  }
}
