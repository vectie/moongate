///|
async test "retained request explorer crosses native routes into UI and exports" {
  // Synthetic local records only; no provider, credential store or user files.
  let server = @httpx.Server::new("127.0.0.1", 0)
  defer server.close()
  let gateway = Gateway::new(host="127.0.0.1", port=server.port())
  gateway.control.token = Some("fixture-request-control")
  let now = @os.unix_seconds()
  let rows : Array[Json] = []
  for i in 0..<39 {
    let log = RequestLog::new(
      request_id="request-\{100 + i}",
      provider_id="fixture-\{i % 2}",
      provider_name=Some(
        if i % 2 == 0 {
          "Alpha 月 \"provider\"\nline"
        } else {
          "Beta provider"
        },
      ),
      app_type=if i % 3 == 0 { "codex" } else { "claude" },
      model=if i % 2 == 0 { "fixture-moon" } else { "fixture-star" },
      request_model=Some("=SUM(1,2)"),
      usage=TokenUsage::new(input_tokens=100 + i, output_tokens=10),
      status_code=if i % 5 == 0 { 500 } else { 200 },
      latency_ms=if i == 0 { 0 } else { 42 + i },
      total_cost_usd=if i == 0 { "0" } else { "0.000123" },
      created_at=if i == 37 {
        now - 40 * 86400
      } else if i == 38 {
        now + 86400
      } else {
        now - 60 - i * 3600
      },
      error_message=Some("fixture-raw-error"),
    )
    rows.push(log.to_moon_request_log_detail_json())
    gateway.usage.stats.record_request_log(log)
  }
  let router = @httpx.Router::new()
  gateway.usage.register_routes(
    router,
    gateway.auth,
    gateway.proxy.provider_router,
  )
  gateway.workspace.register_routes(
    router,
    gateway.config,
    gateway.logger,
    "127.0.0.1",
    server.port(),
  )
  let file_server = @httpx.FileServer::new("public")
  router.set_not_found_handler(file_server.handler())
  @async.with_timeout(90000, () => {
    @async.with_task_group(group => {
      group.spawn_bg(
        () => {
          server.serve(
            moongate_security_handler(
              router.handler(),
              gateway.control,
              "127.0.0.1",
              server.port(),
            ),
          )
        },
        no_wait=true,
        allow_failure=true,
      )
      @fsx.with_temporary_directory("moongate-request-explorer-XXXXXX", async fn(
        dir,
      ) {
        let fixture_path = @pathx.join(dir, "fixture.json")
        let fixture : Json = { "rows": rows }
        @fsx.write_to_file(fixture_path, fixture.stringify(indent=2))
        let result = @spawn.spawn(
          "node",
          ["--test", "tests/moongate-requests.test.cjs"],
          env={
            "MOONGATE_REQUEST_TEST_URL": "http://127.0.0.1:\{server.port()}",
            "MOONGATE_REQUEST_TEST_FIXTURE": fixture_path,
          },
          timeout=75000,
        )
        match @env.get_env_var("MOONGATE_REQUEST_EVIDENCE") {
          Some(destination) => {
            @fsx.write_to_file(
              @pathx.join(destination, "native-ui-crossing.log"),
              result.stdout + result.stderr,
            )
            @fsx.write_to_file(
              @pathx.join(destination, "generated-dashboard.html"),
              moongate_rabbita_document_html(),
            )
            @fsx.write_to_file(
              @pathx.join(destination, "generated-preview.json"),
              moongate_rabbita_lepusa_manifest(),
            )
            @fsx.write_to_file(
              @pathx.join(destination, "synthetic-retained-requests.json"),
              fixture.stringify(indent=2),
            )
          }
          None => ()
        }
        assert_true(result.status == 0, msg=result.stdout + result.stderr)
      })
    })
  })
}

///|
test "request explorer generated shell labels scope and every control" {
  let html = moongate_rabbita_document_html()
  for
    id in [
      "request-filters", "request-app", "request-range", "request-provider", "request-model",
      "request-status", "request-apply", "request-reset", "request-prev", "request-next",
      "request-page-summary", "request-retry", "request-query-summary", "request-feedback",
      "request-detail-retry", "request-export-page", "request-export-detail",
    ] {
    assert_true(html.contains("id=\"\{id}\""), msg=id)
  }
  assert_true(html.contains("/assets/moongate-usage.js"))
  assert_true(html.contains("Export displayed page CSV"))
  assert_true(html.contains("Export selected report"))
  assert_true(html.contains("Pages use offsets"))
  assert_true(html.contains("aggregate totals"))
  assert_true(html.contains("not a complete billing record"))
  assert_true(html.contains("zero cost or latency can also mean unavailable"))
}
