///|
async fn main {
  let args = @os.args()
  @usage_latency_cli.run(args[1:].to_owned()) catch {
    error => {
      println("Usage latency profile failed: \{error}")
      @os.exit(1)
    }
  }
}
