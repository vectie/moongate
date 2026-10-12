///|
// Shared exact-number parsing also serves saved local inference captures.
fn parse_with_number_text(source : StringView) -> Json raise @json.ParseError {
  @exact_json.parse_with_number_text(source)
}

///|
fn exact_count(text : String) -> Double? {
  @exact_json.exact_count(text)
}
