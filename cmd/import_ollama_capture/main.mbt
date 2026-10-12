///|
async fn main {
  @ollama_capture_cli.run(@os.args()[1:].to_owned()) catch {
    error => {
      println("Ollama capture import failed: \{error}")
      @os.exit(1)
    }
  }
}
