///|
async test "moongate ordinary journey exposes one dynamic next action and semantic icons" {
  let html = moongate_rabbita_shell_html()
  assert_true(html.contains("id=\"goal-compass\""))
  assert_true(html.contains("Connect one app to a healthy provider"))
  assert_true(html.contains("id=\"primary-next-action\""))
  assert_true(html.contains("aria-describedby=\"goal-next-detail\""))
  assert_true(html.contains("aria-live=\"assertive\""))
  for
    icon in [
      "overview", "providers", "bindings", "connections", "connect", "requests",
      "usage", "suite", "guide",
    ] {
    assert_true(html.contains("/assets/nav/\{icon}.svg"))
    assert_true(@fsx.exists_as_file("public/assets/nav/\{icon}.svg"))
  }
  assert_false(html.contains(">OV<"))
  assert_false(html.contains(">PR<"))
  assert_false(html.contains(">AB<"))
}

///|
async test "moongate journey policy provides progress recovery and 44px controls" {
  let js = @fsx.read_file("public/assets/moongate.js")
  let css = @fsx.read_file("public/assets/moongate.css")
  assert_true(js.contains("function renderGoalCompass"))
  assert_true(js.contains("Retry gateway check"))
  assert_true(js.contains("Blocked: ${detail}"))
  assert_true(js.contains("start-routing"))
  assert_true(js.contains("Review live usage"))
  assert_true(css.contains(".goal-compass"))
  assert_true(css.contains("min-height: 44px"))
  assert_true(css.contains("prefers-reduced-motion: reduce"))
}
