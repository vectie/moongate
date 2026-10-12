///|
async fn preview_curl(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--file") is Some(path) else {
    fail("Use provider curl --file <request.curl>; outputs editable .http")
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  if file.size() > 1024L * 1024L {
    fail("curl input exceeds 1 MiB")
  }
  let content = @io.Reader::read_all(file).text()
  println(@curl_import.to_http(content))
}
