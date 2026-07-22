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
fn moon_models_endpoint_response_json(
  active_catalog : Json?,
  fallback_model? : String = "",
) -> Json {
  match active_catalog {
    Some(catalog) if moon_model_catalog_has_models(catalog) => catalog
    _ =>
      if fallback_model.trim().is_empty() {
        { "models": Json::array([]) }.to_json()
      } else {
        @codex_config.model_catalog_json(fallback_model)
      }
  }
}

///|
fn moon_model_catalog_has_models(catalog : Json) -> Bool {
  match catalog {
    Object(fields) =>
      match fields.get("models") {
        Some(Array(models)) => !models.is_empty()
        _ => false
      }
    _ => false
  }
}
