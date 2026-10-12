///|
async fn main {
  let args = @os.args()
  @batch_usage_cli.run(args[1:].to_owned()) catch {
    error => {
      println("Batch usage import failed: \{error}")
      @os.exit(1)
    }
  }
}
