///|
async fn main {
  @otel_usage_cli.run(@os.args()[1:].to_owned()) catch {
    error => {
      @io.Writer::write(
        @stdio.stderr,
        "OpenTelemetry import failed: \{error}\n",
      )
      @os.exit(1)
    }
  }
}
