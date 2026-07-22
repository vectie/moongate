///|
test "automatic app bindings are limited to real managed config writers" {
  assert_eq(moon_binding_mode("moondesk"), "automatic")
  assert_eq(moon_binding_mode("codex"), "automatic")
  assert_eq(moon_binding_mode("claude-desktop"), "automatic")
  assert_eq(moon_binding_mode("claude"), "manual")
  assert_eq(moon_binding_mode("gemini"), "manual")
  assert_eq(moon_binding_mode("opencode"), "manual")
  assert_eq(moon_binding_mode("openclaw"), "manual")
  assert_eq(moon_binding_mode("hermes"), "manual")
}

///|
test "MoonDesk binding reuses Codex-compatible providers" {
  assert_eq(moon_binding_provider_app_type("moondesk"), "codex")
  assert_eq(moon_binding_provider_app_type("claude"), "claude")
}

///|
test "app binding uses provider default model when configured" {
  let provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="ark",
    provider_name="Ark",
    model_mapping=Some(ModelMapping::new(default_model=Some("kimi-k3"))),
  )
  assert_eq(provider.binding_model("fallback"), "kimi-k3")
}

///|
test "app binding falls back when provider has no model mapping" {
  let provider = ProviderRouteTarget::new(
    app_type="codex",
    provider_id="oauth",
    provider_name="Codex OAuth",
  )
  assert_eq(provider.binding_model("gpt-5.6-sol"), "gpt-5.6-sol")
}
