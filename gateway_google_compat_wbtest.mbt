///|
test "Google chat removes OpenAI-only cache hints without changing other providers" {
  let google = ProviderRouteTarget::new(
    app_type="openclaw",
    provider_id="google",
    provider_name="Google",
    base_url=Some("https://generativelanguage.googleapis.com/v1beta/openai"),
  )
  let request : Json = {
    "model": "gemini-3.5-flash-lite",
    "messages": [],
    "prompt_cache_key": "local-session",
    "prompt_cache_retention": "24h",
  }
  assert_eq(
    google_compatible_provider_request(google, request),
    ({ "model": "gemini-3.5-flash-lite", "messages": [] } : Json),
  )
  let other = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="other",
    provider_name="Other",
    base_url=Some("https://api.openai.com/v1"),
  )
  assert_eq(google_compatible_provider_request(other, request), request)
  assert_true(request is { "prompt_cache_key": "local-session", .. })
}

///|
test "Google thinking models translate unsupported none effort without changing Gemini 2.5" {
  let google = ProviderRouteTarget::new(
    app_type="openclaw",
    provider_id="google",
    provider_name="Google",
    base_url=Some("https://generativelanguage.googleapis.com/v1beta/openai"),
  )
  for model in google_gemini_models() {
    assert_true(
      google_compatible_provider_request(google, {
        "model": model,
        "reasoning_effort": "none",
      })
      is { "reasoning_effort": "low", .. },
    )
  }
  let older : Json = { "model": "gemini-2.5-flash", "reasoning_effort": "none" }
  assert_eq(google_compatible_provider_request(google, older), older)
}

///|
test "one Google connection advertises and preserves all four Gemini 4 models" {
  let google = ProviderRouteTarget::new(
    app_type="openclaw",
    provider_id="google",
    provider_name="Google Gemini",
    base_url=Some("https://generativelanguage.googleapis.com/v1beta/openai"),
    model_mapping=Some(
      ModelMapping::new(default_model=Some("gemini-4-hydrogen")),
    ),
  )
  guard google_provider_model_catalog(google, "")
    is Some({ "data": Array(rows), .. }) else {
    fail("expected Google catalog")
  }
  for
    model in [
      "gemini-4-hydrogen", "gemini-4-neon", "gemini-4-carbon", "gemini-4-argon",
    ] {
    assert_true(rows.any(row => row is { "id": String(id), .. } && id == model))
    assert_eq(google.map_model_for_upstream(model), model)
  }
  assert_eq(
    google.map_model_for_upstream("gpt-client-default"),
    "gemini-4-hydrogen",
  )
}
