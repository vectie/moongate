///|
fn ascii_lex_compare(left : String, right : String) -> Int {
  let limit = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for i in 0..<limit {
    if left[i] < right[i] {
      return -1
    } else if left[i] > right[i] {
      return 1
    }
  }
  if left.length() < right.length() {
    -1
  } else if left.length() > right.length() {
    1
  } else {
    0
  }
}

///|
fn ccs_empty_models_catalog_json() -> Json {
  { "models": Json::array([]) }.to_json()
}

///|
fn ccs_models_endpoint_response_json(active_catalog : Json?) -> Json {
  match active_catalog {
    Some(catalog) => catalog
    None => ccs_empty_models_catalog_json()
  }
}
