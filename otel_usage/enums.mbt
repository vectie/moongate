///|
fn enum_value(value : Json, max : Double, label : String) -> Double raise {
  if value == Json::null() {
    return 0.0
  }
  guard value is Number(_, repr=Some(text)) &&
    @exact_json.exact_count(text) is Some(number) &&
    number <= max else {
    fail("\{label} must be an exact supported integer enum")
  }
  number
}
