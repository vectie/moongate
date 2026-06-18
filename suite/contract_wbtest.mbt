///|
test "suite contract owns moonstat identity and urls" {
  assert_eq(manifest_contract(), "moon.suite.service.v1")
  assert_eq(status_contract(), "moon.suite.status.v1")
  assert_eq(service_name(), "moonstat")
  assert_eq(project_name(), "moonstat")
  assert_eq(version(), "0.1.0")
  assert_eq(default_host(), "127.0.0.1")
  assert_eq(default_port(), 15721)
  assert_eq(default_model(), "gpt-5")
  assert_eq(normalize_host("0.0.0.0"), "127.0.0.1")
  assert_eq(normalize_host("::"), "127.0.0.1")
  assert_eq(normalize_host("192.168.1.9"), "192.168.1.9")
  assert_eq(base_url("0.0.0.0", 18081), "http://127.0.0.1:18081")
  assert_eq(openai_base_url("127.0.0.1", 18081), "http://127.0.0.1:18081/v1")
  assert_eq(
    claude_desktop_base_url("127.0.0.1", 18081),
    "http://127.0.0.1:18081/claude-desktop/v1",
  )
}
