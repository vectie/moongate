///|
async fn main {
  let args = @os.args()
  @usage_price_cli.run(args[1:].to_owned()) catch {
    error => {
      println("Usage pricing failed: \{error}")
      @os.exit(1)
    }
  }
}
