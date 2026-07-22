///|
test "moongate models endpoint advertises configured fallback model" {
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
test "moongate models endpoint does not invent a default model" {
  let body = moon_models_endpoint_response_json(None)
  guard body is Object(obj) else { fail("expected object") }
  assert_eq(obj["models"], Json::array([]))
}

///|
test "moongate models endpoint replaces an empty active catalog" {
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
test "moongate models endpoint serves active catalog directly" {
  let catalog = {
    "models": Json::array([{ "slug": Json::string("gpt-5.7") }.to_json()]),
    "provider": Json::string("moongate"),
  }.to_json()
  assert_eq(moon_models_endpoint_response_json(Some(catalog)), catalog)
}
