///|
async fn main {
  @har_compare_cli.run(@os.args()[1:].to_owned()) catch {
    error => {
      @io.Writer::write(@stdio.stderr, "HAR comparison failed: \{error}\n")
      @os.exit(1)
    }
  }
}
