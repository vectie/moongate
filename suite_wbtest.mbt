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
  assert_eq(
    obj["usage_summary_url"],
    Json::string("http://127.0.0.1:15721/usage/summary"),
  )
  assert_eq(
    obj["usage_trends_url"],
    Json::string("http://127.0.0.1:15721/usage/trends"),
  )
  assert_eq(
    obj["usage_provider_limits_url"],
    Json::string("http://127.0.0.1:15721/usage/provider-limits"),
  )
  assert_eq(
    obj["usage_sync_session_url"],
    Json::string("http://127.0.0.1:15721/usage/sync-session"),
  )
  assert_eq(obj["usage_store_dir"], Json::string(default_moonstat_stats_dir()))
  assert_eq(
    obj["usage_request_logs_file"],
    Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_REQUEST_LOGS_FILE),
    ),
  )
  assert_eq(
    obj["usage_session_sync_file"],
    Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_SESSION_SYNC_FILE),
    ),
  )
  assert_eq(
    obj["usage_model_pricing_file"],
    Json::string(
      @pathx.join(default_moonstat_stats_dir(), MOONSTAT_MODEL_PRICING_FILE),
    ),
  )
  assert_eq(
    obj["usage_opencode_export_file"],
    Json::string(default_opencode_export_path()),
  )
  assert_eq(
    obj["usage_opencode_db_file"],
    Json::string(default_opencode_db_path()),
  )
  guard obj["routes"] is Array(routes) else { fail("expected routes") }
  assert_true(routes.contains(Json::string("GET /participant/register")))
  assert_true(routes.contains(Json::string("GET /stats")))
  assert_true(routes.contains(Json::string("GET /usage/logs")))
  assert_true(routes.contains(Json::string("GET /usage/summary")))
  assert_true(routes.contains(Json::string("GET /usage/summary/by-app")))
  assert_true(routes.contains(Json::string("GET /usage/trends")))
  assert_true(routes.contains(Json::string("GET /usage/provider-limits")))
  assert_true(routes.contains(Json::string("GET /usage/provider-stats")))
  assert_true(routes.contains(Json::string("GET /usage/model-stats")))
  assert_true(routes.contains(Json::string("GET /usage/data-sources")))
  assert_true(routes.contains(Json::string("POST /usage/sync-session")))
  assert_true(routes.contains(Json::string("GET /usage/model-pricing")))
  assert_true(routes.contains(Json::string("POST /usage/model-pricing")))
  assert_true(routes.contains(Json::string("DELETE /usage/model-pricing")))
  assert_true(
    routes.contains(Json::string("GET /usage/request-detail/{request_id}")),
  )
  assert_true(routes.contains(Json::string("POST /v1/messages")))
  assert_true(routes.contains(Json::string("POST /login")))
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
    assert_eq(
      obj["usage_summary_url"],
      Json::string("http://127.0.0.1:17000/usage/summary"),
    )
    assert_eq(
      obj["usage_trends_url"],
      Json::string("http://127.0.0.1:17000/usage/trends"),
    )
    assert_eq(
      obj["usage_provider_limits_url"],
      Json::string("http://127.0.0.1:17000/usage/provider-limits"),
    )
    assert_eq(
      obj["usage_sync_session_url"],
      Json::string("http://127.0.0.1:17000/usage/sync-session"),
    )
    assert_eq(
      obj["usage_request_logs_file"],
      Json::string(
        @pathx.join(default_moonstat_stats_dir(), MOONSTAT_REQUEST_LOGS_FILE),
      ),
    )
    assert_eq(
      obj["usage_session_sync_file"],
      Json::string(
        @pathx.join(default_moonstat_stats_dir(), MOONSTAT_SESSION_SYNC_FILE),
      ),
    )
    assert_eq(
      obj["usage_model_pricing_file"],
      Json::string(
        @pathx.join(default_moonstat_stats_dir(), MOONSTAT_MODEL_PRICING_FILE),
      ),
    )
    assert_eq(
      obj["usage_opencode_export_file"],
      Json::string(default_opencode_export_path()),
    )
    assert_eq(
      obj["usage_opencode_db_file"],
      Json::string(default_opencode_db_path()),
    )
    guard obj["manifest"] is Object(manifest) else {
      fail("expected manifest object")
    }
    assert_eq(manifest["default_port"], Json::number(17000.0))
  })
}
