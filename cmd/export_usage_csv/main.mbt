///|
async fn main {
  let args = @os.args()
  @usage_export_cli.run(args[1:].to_owned()) catch {
    error => {
      @io.Writer::write(@stdio.stderr, "Usage CSV export failed: \{error}\n")
      @os.exit(1)
    }
  }
}
