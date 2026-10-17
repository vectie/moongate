///|
async fn main {
  @response_capture_cli.run(@os.args()[1:].to_owned()) catch {
    error => {
      @io.Writer::write(
        @stdio.stderr,
        "Responses capture import failed: \{error}\n",
      )
      @os.exit(1)
    }
  }
}
