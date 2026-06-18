///|
test "moonstat models endpoint hides stale catalog" {
  let body = moon_models_endpoint_response_json(None)
  guard body is Object(obj) else { fail("expected object") }
  guard obj["models"] is Array(models) else { fail("expected models array") }
  assert_eq(models.length(), 0)
  assert_true(obj.get("data") is None)
}

///|
test "moonstat models endpoint serves active catalog directly" {
  let catalog = {
    "models": Json::array([{ "slug": Json::string("gpt-5.7") }.to_json()]),
    "provider": Json::string("moonstat"),
  }.to_json()
  assert_eq(moon_models_endpoint_response_json(Some(catalog)), catalog)
}
