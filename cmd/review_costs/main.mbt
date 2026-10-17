///|
async fn main {
  @costs_review_cli.run(@os.args()[1:].to_owned()) catch {
    error => {
      @io.Writer::write(@stdio.stderr, "Costs review failed: \{error}\n")
      @os.exit(1)
    }
  }
}
