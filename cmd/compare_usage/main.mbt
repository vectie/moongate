///|
async fn main {
  let args = @os.args()
  @usage_compare_cli.run(args[1:].to_owned()) catch {
    error => {
      println("Usage comparison failed: \{error}")
      @os.exit(1)
    }
  }
}
