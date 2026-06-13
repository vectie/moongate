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
