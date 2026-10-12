///|
async fn main {
  @chat_capture_cli.run(@os.args()[1:].to_owned()) catch {
    error => {
      @io.Writer::write(@stdio.stderr, "Chat capture import failed: \{error}\n")
      @os.exit(1)
    }
  }
}
