///|
async test "usage file normalizes aliases, unknown cost and filtered roundtrip" {
  let source = @fsx.read_file("examples/usage/requests.json")
  guard moongate_preview_usage_file_json(source) is Ok(Object(result)) else {
    fail("preview")
  }
  assert_eq(result["partial"], true.to_json())
  assert_eq(result["sourceTotal"], Json::number(12))
  guard result["summary"] is Object(summary) else { fail("summary") }
  assert_eq(summary["requests"], Json::number(3))
  assert_eq(summary["tokens"], Json::number(2950))
  assert_eq(summary["knownEstimatedUsd"], Json::number(0.0045))
  assert_eq(summary["missingCostCount"], Json::number(1))
  guard result["data"] is Array(rows) else { fail("rows") }
  assert_eq(moon_json_get(rows[1], "totalCostUsd"), Some(Json::number(0)))
  assert_eq(moon_json_get(rows[2], "totalCostUsd"), Some(Json::null()))
  guard moongate_preview_usage_file_json(
      source,
      app="codex",
      provider="team-fixture",
      model="moon-small",
      start_day="2026-10-06",
      end_day="2026-10-07",
    )
    is Ok(Object(filtered)) else {
    fail("filtered")
  }
  assert_eq(filtered["total"], Json::number(2))
  guard moongate_preview_usage_file_json(Json::object(filtered).stringify())
    is Ok(Object(reopened)) else {
    fail("reopen")
  }
  assert_eq(reopened["data"], filtered["data"])
  assert_eq(reopened["summary"], filtered["summary"])
  assert_eq(reopened["partial"], true.to_json())
  assert_eq(reopened["sourceTotal"], Json::number(12))
  guard moongate_preview_usage_file_json(source, app="absent")
    is Ok(Object(empty)) else {
    fail("empty filter")
  }
  assert_eq(empty["total"], Json::number(0))
  guard moongate_preview_usage_file_json(
      @fsx.read_file("examples/usage/requests.jsonl"),
    )
    is Ok(Object(lines)) else {
    fail("jsonl")
  }
  assert_eq(lines["partial"], false.to_json())
  assert_eq(lines["summary"], result["summary"])
  assert_true(moongate_preview_usage_file_json("not json") is Err(_))
  assert_true(
    moongate_preview_usage_file_json(
      source,
      start_day="2026-10-08",
      end_day="2026-10-01",
    )
    is Err(_),
  )
  assert_true(
    moongate_preview_usage_file_json("[{\"model\":\"m\",\"inputTokens\":1.5}]")
    is Err(_),
  )
}

///|
async test "usage file UI crosses compiled gateway without changing live stats" {
  let server = @httpx.Server::new("127.0.0.1", 0)
  defer server.close()
  let gateway = Gateway::new(host="127.0.0.1", port=server.port())
  gateway.control.token = Some("usage-file-fixture-token")
  let before = gateway.usage.stats_json()
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
  let files = @httpx.FileServer::new("public")
  router.set_not_found_handler(files.handler())
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
      let result = @spawn.spawn(
        "node",
        ["--test", "tests/moongate-usage-file.test.cjs"],
        env={
          "MOONGATE_USAGE_FILE_TEST_URL": "http://127.0.0.1:\{server.port()}",
        },
        timeout=75000,
      )
      match @env.get_env_var("MOONGATE_TRANSCRIPT_EVIDENCE") {
        Some(destination) => {
          @fsx.make_directory(destination, recursive=true, exists_ok=true)
          @fsx.write_to_file(
            destination + "/native-ui-crossing.log",
            result.stdout + result.stderr,
          )
          @fsx.write_to_file(
            destination + "/compiled-dashboard.html",
            moongate_rabbita_document_html(),
          )
        }
        None => ()
      }
      assert_true(result.status == 0, msg=result.stdout + result.stderr)
    })
  })
  assert_eq(gateway.usage.stats_json(), before)
}
