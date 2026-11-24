///|
test "app registry agrees with binding and template scopes" {
  let apps = gateway_apps()
  assert_eq(apps.length(), 11)
  assert_eq(apps[0].id, "moondesk")
  for target in moon_provider_template_targets() {
    guard gateway_app(target.id) is Some(app) else {
      fail("unregistered template target")
    }
    assert_eq(target.provider_app_type, app.scope)
    assert_eq(moon_binding_provider_app_type(app.id), app.scope)
    assert_eq(moon_binding_mode(app.id), app.binding)
    assert_eq(target.priority, app.priority)
  }
  for id in ["moondesk", "moonclaw", "moonbook", "moontown"] {
    let presets = moon_visible_provider_presets(
      Some(id),
      "openai official",
      "original",
    )
    assert_eq(presets.length(), 1)
    guard presets[0] is { "form": Object(form), .. } else {
      fail("missing OAuth form")
    }
    assert_eq(form["appType"], Json::string("openclaw"))
    assert_eq(form["providerType"], Json::string("codex_oauth"))
    assert_false(form.contains("apiKey"))
  }
  assert_eq(moon_binding_mode("moonbook"), "manual")
  assert_eq(moon_binding_mode("moontown"), "manual")
}
