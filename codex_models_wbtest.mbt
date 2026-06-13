///|
test "codex oauth models accepts openai style data" {
  let models = parse_codex_oauth_models(
    @json.parse(
      (
        #|{
        #|  "data": [
        #|    { "id": "gpt-5.4", "owned_by": "openai" },
        #|    { "id": "gpt-5.4-mini", "ownedBy": "openai" }
        #|  ]
        #|}
      ),
    ),
  )
  assert_eq(models.length(), 2)
  assert_eq(models[0].id, "gpt-5.4")
  assert_eq(models[0].owned_by, "openai")
  assert_eq(models[1].id, "gpt-5.4-mini")
  assert_eq(models[1].owned_by, "openai")
}

///|
test "codex oauth models accepts model list shape" {
  let models = parse_codex_oauth_models(
    @json.parse(
      (
        #|{
        #|  "models": [
        #|    { "slug": "gpt-5.3-codex", "display_name": "GPT-5.3 Codex" },
        #|    "gpt-5.5"
        #|  ]
        #|}
      ),
    ),
  )
  assert_model_ids(models, ["gpt-5.3-codex", "gpt-5.5"])
}

///|
test "codex oauth models deduplicates ids" {
  let models = parse_codex_oauth_models(
    @json.parse(
      (
        #|{
        #|  "data": [
        #|    { "id": "gpt-5.4" },
        #|    { "model": "gpt-5.4" }
        #|  ]
        #|}
      ),
    ),
  )
  assert_model_ids(models, ["gpt-5.4"])
}

///|
test "codex oauth models accepts model map shape" {
  let models = parse_codex_oauth_models(
    @json.parse(
      (
        #|{
        #|  "models": {
        #|    "gpt-5.4": { "display_name": "GPT-5.4" },
        #|    "gpt-5.5": { "slug": "gpt-5.5" }
        #|  }
        #|}
      ),
    ),
  )
  assert_model_ids(models, ["gpt-5.4", "gpt-5.5"])
}

///|
test "codex models response exposes openai and moonstat lists" {
  let body = codex_models_response_json([{ id: "gpt-5.4", owned_by: "openai" }])
  guard body is Object(obj) else { fail("expected object") }
  assert_true(obj["object"] is String("list"))
  guard obj["data"] is Array(data) else { fail("expected data array") }
  guard data[0] is Object(openai_model) else { fail("expected data model") }
  assert_true(openai_model["id"] is String("gpt-5.4"))
  assert_true(openai_model["object"] is String("model"))
  assert_true(openai_model["owned_by"] is String("openai"))
  guard obj["models"] is Array(models) else { fail("expected models array") }
  guard models[0] is Object(moonstat_model) else {
    fail("expected moonstat model")
  }
  assert_true(moonstat_model["id"] is String("gpt-5.4"))
  assert_true(moonstat_model["name"] is String("gpt-5.4"))
  assert_true(moonstat_model["provider"] is String("codex-oauth"))
  assert_true(moonstat_model["owned_by"] is String("openai"))
}

///|
test "codex models response remains ccs top-level models compatible" {
  let body = codex_models_response_json([{ id: "gpt-5.4", owned_by: "openai" }])
  guard body is Object(obj) else { fail("expected object") }
  guard obj["models"] is Array(models) else { fail("expected models array") }
  guard models[0] is Object(model) else { fail("expected model") }
  assert_true(model["id"] is String("gpt-5.4"))
}

///|
fn model_ids(models : Array[CodexModel]) -> Array[String] {
  models.map(fn(model) { model.id })
}

///|
fn assert_model_ids(
  models : Array[CodexModel],
  expected : Array[String],
) -> Unit raise {
  let ids = model_ids(models)
  assert_eq(ids.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(ids[i], expected[i])
  }
}
