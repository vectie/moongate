///|
test "gemini url strips version root for official base" {
  let url = build_gemini_native_url(
    "https://generativelanguage.googleapis.com/v1beta", "/v1beta/models/gemini-2.5-pro:generateContent",
  )
  assert_eq(
    url, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent",
  )
}

///|
test "gemini url strips openai compat path for official base" {
  let url = build_gemini_native_url(
    "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions", "/v1beta/models/gemini-2.5-pro:generateContent",
  )
  assert_eq(
    url, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent",
  )
}

///|
test "gemini url preserves proxy prefix while stripping openai suffix" {
  let url = build_gemini_native_url(
    "https://proxy.example.com/google/v1beta/openai/chat/completions", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
  )
  assert_eq(
    url, "https://proxy.example.com/google/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
  )
}

///|
test "gemini url strips model method path from full url base" {
  let url = build_gemini_native_url(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent",
    "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
  )
  assert_eq(
    url, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
  )
}

///|
test "gemini full url preserves opaque relay" {
  let url = resolve_gemini_native_url(
    "https://relay.example/custom/generate-content", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
    true,
  )
  assert_eq(url, "https://relay.example/custom/generate-content?alt=sse")
}

///|
test "gemini full url preserves cloudflare vertex action" {
  let url = resolve_gemini_native_url(
    "https://gateway.ai.cloudflare.com/v1/account/gateway/google-vertex-ai/v1/projects/project/locations/us-central1/publishers/google/models/gemini-3.1-pro-preview:streamGenerateContent",
    "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse", true,
  )
  assert_eq(
    url, "https://gateway.ai.cloudflare.com/v1/account/gateway/google-vertex-ai/v1/projects/project/locations/us-central1/publishers/google/models/gemini-3.1-pro-preview:streamGenerateContent?alt=sse",
  )
}

///|
test "gemini full url preserves opaque models relay" {
  let url = resolve_gemini_native_url(
    "https://relay.example/custom/models/invoke", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
    true,
  )
  assert_eq(url, "https://relay.example/custom/models/invoke?alt=sse")
}

///|
test "gemini full url preserves opaque v1 models relay" {
  let url = resolve_gemini_native_url(
    "https://relay.example/v1/models/invoke", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
    true,
  )
  assert_eq(url, "https://relay.example/v1/models/invoke?alt=sse")
}

///|
test "gemini full url preserves opaque v1beta models relay" {
  let url = resolve_gemini_native_url(
    "https://relay.example/v1beta/models/route", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
    true,
  )
  assert_eq(url, "https://relay.example/v1beta/models/route?alt=sse")
}

///|
test "gemini full url normalizes structured method path" {
  let url = resolve_gemini_native_url(
    "https://relay.example/v1/models/gemini-2.5-pro:generateContent", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
    true,
  )
  assert_eq(
    url, "https://relay.example/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
  )
}

///|
test "gemini full url preserves generic relay suffixes on non-google host" {
  assert_eq(
    resolve_gemini_native_url(
      "https://relay.example/custom/v1", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
      true,
    ),
    "https://relay.example/custom/v1?alt=sse",
  )
  assert_eq(
    resolve_gemini_native_url(
      "https://relay.example/custom/models", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
      true,
    ),
    "https://relay.example/custom/models?alt=sse",
  )
  assert_eq(
    resolve_gemini_native_url(
      "https://relay.example/custom/v1/models", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
      true,
    ),
    "https://relay.example/custom/v1/models?alt=sse",
  )
  assert_eq(
    resolve_gemini_native_url(
      "https://relay.example/custom/openai", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
      true,
    ),
    "https://relay.example/custom/openai?alt=sse",
  )
  assert_eq(
    resolve_gemini_native_url(
      "https://relay.example/custom/v1beta", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
      true,
    ),
    "https://relay.example/custom/v1beta?alt=sse",
  )
  assert_eq(
    resolve_gemini_native_url(
      "https://relay.example/custom/v1beta/models", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
      true,
    ),
    "https://relay.example/custom/v1beta/models?alt=sse",
  )
}

///|
test "gemini full url normalizes google host generic suffixes" {
  assert_eq(
    resolve_gemini_native_url(
      "https://generativelanguage.googleapis.com/v1", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
      true,
    ),
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
  )
  assert_eq(
    resolve_gemini_native_url(
      "https://generativelanguage.googleapis.com/models", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
      true,
    ),
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
  )
  assert_eq(
    resolve_gemini_native_url(
      "https://us-central1-aiplatform.googleapis.com/v1", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
      true,
    ),
    "https://us-central1-aiplatform.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
  )
  assert_eq(
    resolve_gemini_native_url(
      "https://generativelanguage.googleapis.com/v1beta", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
      true,
    ),
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
  )
}

///|
test "gemini full url preserves non-google aiplatform lookalike host" {
  let url = resolve_gemini_native_url(
    "https://aiplatform.example.com/v1", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
    true,
  )
  assert_eq(url, "https://aiplatform.example.com/v1?alt=sse")
}

///|
test "gemini non-full url strips versioned relay base suffix" {
  assert_eq(
    resolve_gemini_native_url(
      "https://relay.example/custom/v1beta", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
      false,
    ),
    "https://relay.example/custom/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
  )
  assert_eq(
    resolve_gemini_native_url(
      "https://relay.example/custom/v1", "/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
      false,
    ),
    "https://relay.example/custom/v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse",
  )
}

///|
test "gemini url merges base and endpoint queries" {
  let url = build_gemini_native_url(
    "https://generativelanguage.googleapis.com/v1beta?key=abc", "/v1beta/models/gemini-2.5-pro:generateContent?alt=sse",
  )
  assert_eq(
    url, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=abc&alt=sse",
  )
}

///|
test "gemini url drops empty query fragments like moonstat" {
  assert_eq(
    build_gemini_native_url(
      "https://generativelanguage.googleapis.com/v1beta?", "/v1beta/models/gemini-2.5-pro:generateContent?",
    ),
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent",
  )
  assert_eq(
    build_gemini_native_url(
      "https://generativelanguage.googleapis.com/v1beta?key=abc&&", "/v1beta/models/gemini-2.5-pro:generateContent?&alt=sse",
    ),
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=abc&alt=sse",
  )
  assert_eq(
    resolve_gemini_native_url(
      "https://relay.example/custom/generate-content?", "/v1beta/models/gemini-2.5-pro:generateContent?",
      true,
    ),
    "https://relay.example/custom/generate-content",
  )
}

///|
test "gemini model id normalization matches moonstat" {
  assert_eq(
    normalize_gemini_model_id("models/gemini-2.5-pro"),
    "gemini-2.5-pro",
  )
  assert_eq(normalize_gemini_model_id("gemini-2.5-pro"), "gemini-2.5-pro")
  assert_eq(
    normalize_gemini_model_id("models/tunedModels/my-tuned"),
    "tunedModels/my-tuned",
  )
  assert_eq(
    normalize_gemini_model_id("/models/gemini-2.5-flash"),
    "gemini-2.5-flash",
  )
  assert_eq(normalize_gemini_model_id(""), "")
}
