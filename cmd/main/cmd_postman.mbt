///|
async fn preview_postman(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--file") is Some(path) else {
    fail(
      "Use provider postman --file <collection.json> [--folder Models] [--method POST] [--http]",
    )
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  if file.size() > 4L * 1024L * 1024L {
    fail("Postman file exceeds 4 MiB")
  }
  let content = @io.Reader::read_all(file).text()
  match
    @moongate.moongate_postman_collection_json(
      content,
      folder=parse_string_arg(args, "--folder").unwrap_or(""),
      request_method=parse_string_arg(args, "--method").unwrap_or(""),
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
