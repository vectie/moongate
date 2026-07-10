///|
test "moonstat models endpoint advertises configured fallback model" {
  let body = moon_models_endpoint_response_json(
    None,
    fallback_model="gpt-5.6-sol",
  )
  guard body is Object(obj) else { fail("expected object") }
  guard obj["models"] is Array(models) else { fail("expected models array") }
  assert_eq(models.length(), 1)
  guard models[0] is Object(model) else { fail("expected model object") }
  assert_eq(model["slug"], Json::string("gpt-5.6-sol"))
  assert_true(obj.get("data") is None)
}

///|
test "moonstat models endpoint replaces an empty active catalog" {
  let body = moon_models_endpoint_response_json(
    Some({ "models": Json::array([]) }),
    fallback_model="gpt-5.6-sol",
  )
  guard body is Object(obj) else { fail("expected object") }
  guard obj["models"] is Array(models) else { fail("expected models array") }
  assert_eq(models.length(), 1)
  guard models[0] is Object(model) else { fail("expected model object") }
  assert_eq(model["slug"], Json::string("gpt-5.6-sol"))
}

///|
test "moonstat models endpoint serves active catalog directly" {
  let catalog = {
    "models": Json::array([{ "slug": Json::string("gpt-5.7") }.to_json()]),
    "provider": Json::string("moonstat"),
  }.to_json()
  assert_eq(moon_models_endpoint_response_json(Some(catalog)), catalog)
}
