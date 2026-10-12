///|
async fn preview_transcript_file(args : Array[String]) -> Unit {
  guard parse_string_arg(args, "--file") is Some(path) else {
    fail(
      "Use sessions preview --file <export.jsonl> [--format auto|codex|claude|json]",
    )
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  if file.size() > 4L * 1024L * 1024L {
    fail("Transcript exceeds the 4 MiB limit")
  }
  let content = @io.Reader::read_all(file).text()
  let format = parse_string_arg(args, "--format").unwrap_or("auto")
  match
    @moongate.moongate_preview_transcript_json(
      content,
      format~,
      source_name=path,
    ) {
    Ok(result) => println(result.stringify(indent=2))
    Err(error) => fail(error)
  }
}
