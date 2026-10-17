///|
async fn main {
  @insomnia_import_cli.run(@os.args()[1:].to_owned()) catch {
    error => {
      @io.Writer::write(@stdio.stderr, "Insomnia import failed: \{error}\n")
      @os.exit(1)
    }
  }
}
