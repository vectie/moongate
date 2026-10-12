///|
test "Batch CLI requires file and rejects missing duplicate and unknown options" {
  let options = parse_options([
    "--file", "output.jsonl", "--errors", "errors.jsonl", "--app", "eval", "--requests",
    "input.jsonl", "--report",
  ])
  assert_eq(options.get("--file"), Some("output.jsonl"))
  assert_eq(options.get("--errors"), Some("errors.jsonl"))
  assert_eq(options.get("--requests"), Some("input.jsonl"))
  assert_eq(options.get("--report"), Some("true"))
  for
    args in [
      [],
      ["--errors", "errors.jsonl"],
      ["--file"],
      ["--file", "--report"],
      ["--file", "a", "--file", "b"],
      ["--file", "a", "--provider", " "],
      ["--file", "a", "--requests"],
      ["--file", "a", "--requests", "--report"],
      ["--file", "a", "--requests", "b", "--requests", "c"],
      ["--file", "a", "--report", "--report"],
      ["--file", "a", "--url", "https://example.com"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Invalid options accepted")
    }
  }
}

///|
test "Batch CLI selects an explicit Anthropic format and rejects OpenAI-only manifest joins" {
  let options = parse_options([
    "--file", "batch.jsonl", "--format", "anthropic", "--provider", "my-review",
    "--report",
  ])
  assert_eq(options.get("--format"), Some("anthropic"))
  assert_eq(options.get("--provider"), Some("my-review"))
  for
    args in [
      ["--file", "batch", "--format", "Anthropic"],
      ["--file", "batch", "--format", "unknown"],
      ["--file", "batch", "--format"],
      ["--file", "batch", "--format", "anthropic", "--format", "openai"],
      ["--file", "batch", "--format", "anthropic", "--requests", "input"],
    ] {
    try parse_options(args) catch {
      _ => ()
    } noraise {
      _ => fail("Invalid format options accepted")
    }
  }
}
