///|
test "model url candidates plain root" {
  assert_model_url_candidates(
    build_models_url_candidates("https://api.siliconflow.cn", false, None),
    ["https://api.siliconflow.cn/v1/models"],
  )
}

///|
test "model url candidates trailing slash" {
  assert_model_url_candidates(
    build_models_url_candidates("https://api.example.com/", false, None),
    ["https://api.example.com/v1/models"],
  )
}

///|
test "model url candidates with v1" {
  assert_model_url_candidates(
    build_models_url_candidates("https://api.example.com/v1", false, None),
    ["https://api.example.com/v1/models"],
  )
}

///|
test "model url candidates zhipu coding paas v4" {
  assert_model_url_candidates(
    build_models_url_candidates(
      "https://open.bigmodel.cn/api/coding/paas/v4",
      false,
      None,
    ),
    [
      "https://open.bigmodel.cn/api/coding/paas/v4/models", "https://open.bigmodel.cn/api/coding/paas/v4/v1/models",
    ],
  )
}

///|
test "model url candidates zai coding paas v4" {
  assert_model_url_candidates(
    build_models_url_candidates(
      "https://api.z.ai/api/coding/paas/v4",
      false,
      None,
    ),
    [
      "https://api.z.ai/api/coding/paas/v4/models", "https://api.z.ai/api/coding/paas/v4/v1/models",
    ],
  )
}

///|
test "model url candidates version segment detection" {
  assert_true(ends_with_version_segment("https://x.com/v1"))
  assert_true(
    ends_with_version_segment("https://open.bigmodel.cn/api/coding/paas/v4"),
  )
  assert_true(ends_with_version_segment("https://x.com/v10"))
  assert_false(ends_with_version_segment("https://x.com/api"))
  assert_false(ends_with_version_segment("https://x.com/vX"))
  assert_false(ends_with_version_segment("https://x.com/models"))
  assert_false(ends_with_version_segment("https://api.siliconflow.cn"))
}

///|
test "model url candidates full url" {
  assert_model_url_candidates(
    build_models_url_candidates(
      "https://proxy.example.com/v1/chat/completions",
      true,
      None,
    ),
    ["https://proxy.example.com/v1/models"],
  )
}

///|
test "model url candidates empty" {
  assert_true(build_models_url_candidates("", false, None) is Err(_))
}

///|
test "model url candidates override returns single" {
  assert_model_url_candidates(
    build_models_url_candidates(
      "https://api.deepseek.com/anthropic",
      false,
      Some("https://api.deepseek.com/models"),
    ),
    ["https://api.deepseek.com/models"],
  )
}

///|
test "model url candidates override empty falls through" {
  assert_model_url_candidates(
    build_models_url_candidates(
      "https://api.siliconflow.cn",
      false,
      Some("   "),
    ),
    ["https://api.siliconflow.cn/v1/models"],
  )
}

///|
test "model url candidates deepseek strip anthropic" {
  assert_model_url_candidates(
    build_models_url_candidates(
      "https://api.deepseek.com/anthropic",
      false,
      None,
    ),
    [
      "https://api.deepseek.com/anthropic/v1/models", "https://api.deepseek.com/v1/models",
      "https://api.deepseek.com/models",
    ],
  )
}

///|
test "model url candidates zhipu strip api anthropic" {
  assert_model_url_candidates(
    build_models_url_candidates(
      "https://open.bigmodel.cn/api/anthropic",
      false,
      None,
    ),
    [
      "https://open.bigmodel.cn/api/anthropic/v1/models", "https://open.bigmodel.cn/v1/models",
      "https://open.bigmodel.cn/models",
    ],
  )
}

///|
test "model url candidates bailian strip apps anthropic" {
  assert_model_url_candidates(
    build_models_url_candidates(
      "https://dashscope.aliyuncs.com/apps/anthropic",
      false,
      None,
    ),
    [
      "https://dashscope.aliyuncs.com/apps/anthropic/v1/models", "https://dashscope.aliyuncs.com/v1/models",
      "https://dashscope.aliyuncs.com/models",
    ],
  )
}

///|
test "model url candidates stepfun strip step plan" {
  assert_model_url_candidates(
    build_models_url_candidates(
      "https://api.stepfun.com/step_plan",
      false,
      None,
    ),
    [
      "https://api.stepfun.com/step_plan/v1/models", "https://api.stepfun.com/v1/models",
      "https://api.stepfun.com/models",
    ],
  )
}

///|
test "model url candidates doubao strip api coding" {
  assert_model_url_candidates(
    build_models_url_candidates(
      "https://ark.cn-beijing.volces.com/api/coding",
      false,
      None,
    ),
    [
      "https://ark.cn-beijing.volces.com/api/coding/v1/models", "https://ark.cn-beijing.volces.com/v1/models",
      "https://ark.cn-beijing.volces.com/models",
    ],
  )
}

///|
test "model url candidates rightcode strip claude" {
  assert_model_url_candidates(
    build_models_url_candidates("https://www.right.codes/claude", false, None),
    [
      "https://www.right.codes/claude/v1/models", "https://www.right.codes/v1/models",
      "https://www.right.codes/models",
    ],
  )
}

///|
test "model url candidates longer suffix wins" {
  assert_model_url_candidates(
    build_models_url_candidates("https://api.z.ai/api/anthropic", false, None),
    [
      "https://api.z.ai/api/anthropic/v1/models", "https://api.z.ai/v1/models", "https://api.z.ai/models",
    ],
  )
}

///|
test "model url candidates no suffix no strip" {
  assert_model_url_candidates(
    build_models_url_candidates("https://openrouter.ai/api", false, None),
    ["https://openrouter.ai/api/v1/models"],
  )
}

///|
test "model url candidates deduplicate" {
  let candidates = build_models_url_candidates(
    "https://host.example.com",
    false,
    None,
  ).unwrap()
  assert_eq(candidates.length(), 1)
}

///|
test "model url target splits origin and path" {
  guard models_url_target("https://api.example.com/v1/models?x=1") is Ok(target) else {
    fail("expected target")
  }
  assert_eq(target.origin, "https://api.example.com")
  assert_eq(target.path, "/v1/models?x=1")
}

///|
test "model url target defaults empty path" {
  guard models_url_target("https://api.example.com") is Ok(target) else {
    fail("expected target")
  }
  assert_eq(target.origin, "https://api.example.com")
  assert_eq(target.path, "/")
}

///|
test "model url target preserves query without path" {
  guard models_url_target("https://api.example.com?api-version=1") is Ok(target) else {
    fail("expected target")
  }
  assert_eq(target.origin, "https://api.example.com")
  assert_eq(target.path, "/?api-version=1")
}

///|
test "model url target rejects invalid url" {
  assert_true(models_url_target("api.example.com/v1/models") is Err(_))
}

///|
test "model fetch error body truncates like ccs" {
  let body = "a".repeat(513)
  let truncated = truncate_model_fetch_error_body(body)
  assert_eq(truncated, "\{"a".repeat(512)}…")
}

///|
test "parse provider models response sorts openai data" {
  let models = parse_models_response_body(
    (
      #|{
      #|  "object": "list",
      #|  "data": [
      #|    { "id": "z-model", "object": "model", "owned_by": "z" },
      #|    { "id": "a-model", "object": "model", "owned_by": "a" }
      #|  ]
      #|}
    ),
  )
  guard models is Ok(models) else { fail("expected models") }
  assert_fetched_model_ids(models, ["a-model", "z-model"])
  assert_true(models[0].owned_by is Some("a"))
  assert_true(models[1].owned_by is Some("z"))
}

///|
test "provider models JSON uses ccs frontend field names" {
  let models : Array[FetchedModel] = [
    { id: "gpt-test", owned_by: Some("openai") },
    { id: "local-test", owned_by: None },
  ]
  json_inspect(fetched_models_to_json(models), content=[
    { "id": "gpt-test", "ownedBy": "openai" },
    { "id": "local-test", "ownedBy": null },
  ])
}

///|
test "parse provider models response allows missing owned by" {
  let models = parse_models_response_body(
    (
      #|{
      #|  "data": [
      #|    { "id": "my-model", "object": "model" }
      #|  ]
      #|}
    ),
  )
  guard models is Ok(models) else { fail("expected models") }
  assert_eq(models.length(), 1)
  assert_eq(models[0].id, "my-model")
  assert_true(models[0].owned_by is None)
}

///|
test "parse provider models response defaults missing data to empty" {
  let models = parse_models_response_body(
    (
      #|{
      #|  "object": "list"
      #|}
    ),
  )
  guard models is Ok(models) else { fail("expected models") }
  assert_eq(models.length(), 0)
}

///|
test "parse provider models response rejects malformed entry" {
  assert_true(
    parse_models_response_body(
      (
        #|{
        #|  "data": [
        #|    { "object": "model" }
        #|  ]
        #|}
      ),
    )
    is Err(_),
  )
  assert_true(
    parse_models_response_body(
      (
        #|{
        #|  "data": [
        #|    { "id": "ok", "owned_by": 1 }
        #|  ]
        #|}
      ),
    )
    is Err(_),
  )
}

///|
test "provider model fetch error body truncates long text" {
  let long = "x".repeat(520)
  let truncated = truncate_model_fetch_error_body(long)
  assert_eq(truncated.length(), 513)
  assert_true(truncated.has_suffix("…"))
}

///|
async test "fetch provider models rejects empty api key before network" {
  let result = fetch_models("https://api.example.com", "", false, None, None)
  assert_true(result is Err("API Key is required to fetch models"))
}

///|
async test "fetch provider models rejects empty base url before network" {
  let result = fetch_models("", "sk-test", false, None, None)
  assert_true(result is Err("Base URL is empty"))
}

///|
fn assert_model_url_candidates(
  actual : Result[Array[String], String],
  expected : Array[String],
) -> Unit raise {
  guard actual is Ok(candidates) else { fail("expected candidates") }
  assert_eq(candidates.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(candidates[i], expected[i])
  }
}

///|
fn assert_fetched_model_ids(
  models : Array[FetchedModel],
  expected : Array[String],
) -> Unit raise {
  assert_eq(models.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(models[i].id, expected[i])
  }
}
