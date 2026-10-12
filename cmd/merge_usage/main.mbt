///|
async fn main {
  let args = @os.args()
  @usage_merge_cli.run(args[1:].to_owned()) catch {
    error => {
      println("Usage merge failed: \{error}")
      @os.exit(1)
    }
  }
}
