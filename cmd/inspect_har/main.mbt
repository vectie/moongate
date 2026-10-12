///|
async fn main {
  let args = @os.args()
  @har_diagnostics_cli.run(args[1:].to_owned()) catch {
    error => {
      @io.Writer::write(@stdio.stderr, "HAR diagnostics failed: \{error}\n")
      @os.exit(1)
    }
  }
}
