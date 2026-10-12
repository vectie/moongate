///|
async fn preview_openapi(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--file") is Some(path) else {
    fail(
      "Use provider openapi --file <openapi.json> [--tag name] [--operation id] [--http]",
    )
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  if file.size() > 4L * 1024L * 1024L {
    fail("OpenAPI file exceeds 4 MiB")
  }
  let content = @io.Reader::read_all(file).text()
  match
    @moongate.moongate_openapi_collection_json(
      content,
      tag=parse_string_arg(args, "--tag").unwrap_or(""),
      operation=parse_string_arg(args, "--operation").unwrap_or(""),
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
