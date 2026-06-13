///|
test "suite manifest publishes moonstat service contract" {
  let manifest = moonstat_suite_manifest_json(
    host="0.0.0.0",
    port=15721,
    model="gpt-5",
  )
  guard manifest is Object(obj) else { fail("expected manifest object") }
  assert_eq(obj["contract"], Json::string("moon.suite.service.v1"))
  assert_eq(obj["service"], Json::string("moonstat"))
  assert_eq(obj["default_host"], Json::string("127.0.0.1"))
  assert_eq(obj["default_port"], Json::number(15721.0))
  assert_eq(obj["base_url"], Json::string("http://127.0.0.1:15721"))
  assert_eq(obj["openai_base_url"], Json::string("http://127.0.0.1:15721/v1"))
  assert_eq(
    obj["usage_logs_url"],
    Json::string("http://127.0.0.1:15721/usage/logs"),
  )
  guard obj["routes"] is Array(routes) else { fail("expected routes") }
  assert_true(routes.contains(Json::string("GET /stats")))
  assert_true(routes.contains(Json::string("GET /usage/logs")))
  assert_true(routes.contains(Json::string("POST /v1/messages")))
  guard obj["apps"] is Array(apps) else { fail("expected apps") }
  assert_eq(apps.length(), 4)
}

///|
async test "suite status writes discovery file" {
  @fsx.with_temporary_directory("moonstat-suite-status-XXXXXX", tmpdir => {
    let path = @pathx.join(tmpdir, "nested/suite-status.json")
    let written = write_moonstat_suite_status(path~, port=17000, model="gpt-5")
    assert_eq(written, path)
    let content = @fsx.read_file(path)
    guard @json.parse(content) is Object(obj) else {
      fail("expected suite status json")
    }
    assert_eq(obj["contract"], Json::string("moon.suite.status.v1"))
    assert_eq(obj["openai_base_url"], Json::string("http://127.0.0.1:17000/v1"))
    assert_eq(
      obj["usage_logs_url"],
      Json::string("http://127.0.0.1:17000/usage/logs"),
    )
    guard obj["manifest"] is Object(manifest) else {
      fail("expected manifest object")
    }
    assert_eq(manifest["default_port"], Json::number(17000.0))
  })
}
