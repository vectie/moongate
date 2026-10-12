///|
fn main {
  let args = @os.args()
  if args.length() == 2 && (args[1] == "--help" || args[1] == "-h") {
    println(
      "Usage: import_curl '<literal curl command>'\nOutputs an editable .http request; never executes curl. See docs/CURL_IMPORT.md.",
    )
    return
  }
  guard args.length() == 2 else {
    println(
      "Expected one argument containing a literal curl command; use --help.",
    )
    @os.exit(2)
  }
  try @curl_import.to_http(args[1]) catch {
    error => {
      println("curl import failed: \{error}")
      @os.exit(1)
    }
  } noraise {
    document => println(document)
  }
}
