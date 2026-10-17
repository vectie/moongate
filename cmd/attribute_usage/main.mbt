///|
async fn main {
  @usage_attribute_cli.run(@os.args()[1:].to_owned()) catch {
    error => {
      @io.Writer::write(
        @stdio.stderr,
        "Workload attribution failed: \{error}\n",
      )
      @os.exit(1)
    }
  }
}
