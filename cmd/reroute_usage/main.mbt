///|
async fn main {
  @usage_reroute_cli.run(@os.args()[1:].to_owned()) catch {
    error => {
      @io.Writer::write(
        @stdio.stderr,
        "Usage route rehearsal failed: \{error}\n",
      )
      @os.exit(1)
    }
  }
}
