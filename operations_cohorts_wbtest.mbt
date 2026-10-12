///|
fn cohort_fixture_log(
  i : Int,
  created : Int,
  provider? : String = "provider-A",
  request_model? : String? = Some("request-moon"),
  model? : String = "response-star",
  status? : Int = 200,
  latency? : Int = 100,
  first? : Int? = Some(10),
  streaming? : Bool = true,
  source? : String = "proxy",
  app? : String = "codex",
  error? : String? = None,
) -> RequestLog {
  RequestLog::new(
    request_id="private-request-\{i}",
    provider_id=provider,
    provider_name=Some("identical provider label"),
    app_type=app,
    model~,
    request_model~,
    usage=TokenUsage::new(input_tokens=0, output_tokens=0),
    status_code=status,
    latency_ms=latency,
    first_token_ms=first,
    duration_ms=Some(latency),
    is_streaming=streaming,
    created_at=created,
    data_source=source,
    error_message=error,
    session_id=Some("secret-session"),
  )
}

///|
fn cohort_fixture_stats(end : Int) -> TrafficStats {
  let stats = TrafficStats::new()
  for i in 1..<=20 {
    stats.record_request_log(
      cohort_fixture_log(i, end - i, latency=i * 10, first=Some(i)),
    )
  }
  stats.record_request_log(
    cohort_fixture_log(21, end - 21, status=404, model="failed-request-model"),
  )
  stats.record_request_log(cohort_fixture_log(22, end - 22, status=503))
  stats.record_request_log(cohort_fixture_log(23, end - 23, status=302))
  stats.record_request_log(
    cohort_fixture_log(24, end - 24, error=Some("secret-raw-error")),
  )
  stats.record_request_log(cohort_fixture_log(25, end - 25, latency=0))
  stats.record_request_log(cohort_fixture_log(26, end - 26, first=None))
  stats.record_request_log(cohort_fixture_log(27, end - 27, first=Some(101)))
  stats.record_request_log(
    cohort_fixture_log(
      28,
      end - 28,
      provider="provider-a",
      model="response-moon",
      streaming=false,
    ),
  )
  stats.record_request_log(
    cohort_fixture_log(29, end - 29, request_model=Some("Request-moon")),
  )
  stats.record_request_log(cohort_fixture_log(30, end - 30, request_model=None))
  stats.record_request_log(
    cohort_fixture_log(31, end - 31, source="claude_session"),
  )
  stats.record_request_log(cohort_fixture_log(32, end - 40 * 86400))
  stats.record_request_log(cohort_fixture_log(33, end))
  stats.record_request_log(cohort_fixture_log(34, end - 34, app="claude"))
  stats
}

///|
fn cohort_test_snapshot(
  stats : TrafficStats,
  end : Int,
  period? : String = "24h",
  streaming? : String = "all",
) -> Map[String, Json] raise {
  guard stats.retained_cohort_snapshot(
      "codex",
      streaming,
      period,
      end,
      end.to_int64() * 1000L,
    )
    is Ok(body) else {
    fail("Snapshot failed")
  }
  guard @json.parse(body) is Object(obj) else {
    fail("Missing snapshot object")
  }
  obj
}

///|
test "cohort snapshot uses exact IDs and explicit models status buckets nearest rank and separate streaming denominator" {
  let end = 1791302400
  let stats = cohort_fixture_stats(end)
  let snapshot = cohort_test_snapshot(stats, end)
  assert_eq(snapshot["retained_rows"], (34).to_json())
  assert_eq(snapshot["proxy_interval_rows"], (30).to_json())
  assert_eq(snapshot["imported_excluded"], (1).to_json())
  assert_eq(snapshot["outside_interval_excluded"], (2).to_json())
  assert_eq(snapshot["missing_request_model_unclassified"], (1).to_json())
  guard snapshot["cohorts"] is Array(rows) else { fail("Missing cohorts") }
  assert_eq(rows.length(), 3)
  guard rows[1] is Object(row) else { fail("Missing exact cohort") }
  assert_eq(row["provider_id"], "provider-A".to_json())
  assert_eq(row["request_model"], "request-moon".to_json())
  assert_eq(row["total"], (27).to_json())
  assert_eq(row["status_2xx"], (24).to_json())
  assert_eq(row["status_4xx"], (1).to_json())
  assert_eq(row["status_5xx"], (1).to_json())
  assert_eq(row["status_other"], (1).to_json())
  assert_eq(row["successful"], (23).to_json())
  assert_eq(row["unsuccessful_excluded"], (4).to_json())
  assert_eq(row["latency"], {
    "sample_count": 22,
    "p50_ms": 100,
    "p95_ms": 190,
    "p99_ms": 200,
  })
  assert_eq(row["first_event"], {
    "sample_count": 20,
    "p50_ms": 10,
    "p95_ms": 19,
    "p99_ms": 20,
  })
  assert_eq(row["streaming_successful"], (23).to_json())
  assert_eq(row["invalid_latency_excluded"], (1).to_json())
  assert_eq(row["first_event_invalid_elapsed_excluded"], (1).to_json())
  assert_eq(row["missing_first_event_excluded"], (1).to_json())
  assert_eq(row["invalid_first_event_excluded"], (1).to_json())
  assert_eq(row["successful_response_model_mix"], [
    { "model": "response-star", "count": 23 },
  ])
  let encoded = snapshot.to_json().stringify()
  for
    secret in [
      "secret-raw-error", "secret-session", "private-request", "identical provider label",
      "failed-request-model", "cost_usd", "duration_ms",
    ] {
    assert_false(encoded.contains(secret), msg=secret)
  }
  assert_eq(
    cohort_test_snapshot(stats, end, streaming="streaming")["proxy_interval_rows"],
    (29).to_json(),
  )
  assert_eq(
    cohort_test_snapshot(stats, end, streaming="non-streaming")["proxy_interval_rows"],
    (1).to_json(),
  )
  assert_eq(
    cohort_test_snapshot(stats, end, period="all")["proxy_interval_rows"],
    (31).to_json(),
  )
}

///|
test "cohort snapshot interval boundaries missing models invalid timings and empty samples are explicit" {
  let end = 1791302400
  let stats = TrafficStats::new()
  stats.record_request_log(cohort_fixture_log(1, end - 86400, first=Some(0)))
  stats.record_request_log(cohort_fixture_log(2, end - 86401))
  stats.record_request_log(cohort_fixture_log(3, end - 7 * 86400))
  stats.record_request_log(cohort_fixture_log(4, end - 30 * 86400))
  stats.record_request_log(cohort_fixture_log(5, end - 30 * 86400 - 1))
  stats.record_request_log(cohort_fixture_log(6, end))
  stats.record_request_log(cohort_fixture_log(7, 0))
  assert_eq(
    cohort_test_snapshot(stats, end)["proxy_interval_rows"],
    (1).to_json(),
  )
  assert_eq(
    cohort_test_snapshot(stats, end, period="7d")["proxy_interval_rows"],
    (3).to_json(),
  )
  assert_eq(
    cohort_test_snapshot(stats, end, period="30d")["proxy_interval_rows"],
    (4).to_json(),
  )
  assert_eq(
    cohort_test_snapshot(stats, end, period="all")["proxy_interval_rows"],
    (5).to_json(),
  )
  assert_eq(
    cohort_test_snapshot(stats, end)["invalid_timestamp_excluded"],
    (1).to_json(),
  )
  guard cohort_test_snapshot(stats, end)["cohorts"]
    is Array([Object(zero_event)]) else {
    fail("Expected boundary cohort")
  }
  assert_eq(zero_event["first_event"], {
    "sample_count": 1,
    "p50_ms": 0,
    "p95_ms": 0,
    "p99_ms": 0,
  })
  let empty = cohort_test_snapshot(TrafficStats::new(), end)
  assert_eq(empty["cohorts"], Json::array([]))
  assert_eq(empty["oldest_utc"], Json::null())
  let invalid = TrafficStats::new()
  invalid.record_request_log(
    cohort_fixture_log(1, end - 1, latency=-1, first=Some(1)),
  )
  invalid.record_request_log(cohort_fixture_log(2, end - 2, first=Some(-1)))
  invalid.record_request_log(
    cohort_fixture_log(3, end - 3, request_model=Some("")),
  )
  invalid.record_request_log(cohort_fixture_log(4, end - 4, provider=""))
  guard cohort_test_snapshot(invalid, end)["cohorts"] is Array([Object(row)]) else {
    fail("Expected one cohort")
  }
  assert_eq(row["first_event"], {
    "sample_count": 0,
    "p50_ms": null,
    "p95_ms": null,
    "p99_ms": null,
  })
  assert_eq(row["invalid_latency_excluded"], (1).to_json())
  assert_eq(row["invalid_first_event_excluded"], (1).to_json())
  assert_eq(
    cohort_test_snapshot(invalid, end)["missing_request_model_unclassified"],
    (1).to_json(),
  )
  assert_eq(
    cohort_test_snapshot(invalid, end)["missing_provider_id_unclassified"],
    (1).to_json(),
  )
}

///|
test "cohort limits refuse the entire snapshot instead of truncating or inventing rollup samples" {
  let end = 1791302400
  let stats = TrafficStats::new()
  for i in 0..<=COHORT_SNAPSHOT_ROW_LIMIT {
    stats.request_logs.push(cohort_fixture_log(i, end - 1))
  }
  assert_eq(
    stats.retained_cohort_snapshot(
      "codex",
      "all",
      "all",
      end,
      end.to_int64() * 1000L,
    ),
    Err("cohort_row_limit"),
  )
  let huge = TrafficStats::new()
  huge.record_request_log(
    cohort_fixture_log(
      1,
      end - 1,
      request_model=Some("月".repeat(COHORT_SNAPSHOT_BYTE_LIMIT / 2)),
    ),
  )
  assert_eq(
    huge.retained_cohort_snapshot(
      "codex",
      "all",
      "all",
      end,
      end.to_int64() * 1000L,
    ),
    Err("cohort_response_limit"),
  )
  let empty = TrafficStats::new()
  for
    (app, mode, period, upper) in [
      ("", "all", "all", end),
      ("codex", "invalid", "all", end),
      ("codex", "all", "today", end),
      ("codex", "all", "all", end + 1),
    ] {
    assert_eq(
      empty.retained_cohort_snapshot(
        app,
        mode,
        period,
        upper,
        end.to_int64() * 1000L,
      ),
      Err("invalid_cohort_query"),
    )
  }
}

///|
async test "cohort snapshot is pure through eviction persistence and reload" {
  let end = 1791302400
  @fsx.with_temporary_directory("moongate-cohort-store-XXXXXX", async fn(dir) {
    let stats = TrafficStats::new()
    stats.enable_persistent_store(storage_dir=dir)
    for i in 0..<503 {
      stats.record_request_log(cohort_fixture_log(i, end - i - 1))
    }
    stats.save_persistent_store()
    let path = @pathx.join(dir, MOONGATE_USAGE_STORE_FILE)
    let before = @fsx.read_file(path)
    let file_before = @fs.mtime(path)
    let store_before = stats.usage_store_json()
    let cached = stats.request_logs.map(log => log.cached_store_json)
    let snapshot = cohort_test_snapshot(stats, end)
    assert_eq(snapshot["retained_rows"], (500).to_json())
    assert_eq(snapshot["proxy_interval_rows"], (500).to_json())
    assert_eq(stats.request_logs.map(log => log.cached_store_json), cached)
    assert_eq(stats.usage_store_json(), store_before)
    assert_eq(@fsx.read_file(path), before)
    assert_eq(@fs.mtime(path), file_before)
    let loaded = TrafficStats::new()
    loaded.load_persistent_store(storage_dir=dir)
    assert_eq(cohort_test_snapshot(loaded, end), snapshot)
    assert_eq(@fsx.read_file(path), before)
  })
}

///|
test "cohort shell exposes controls and authenticated route" {
  assert_true(
    moongate_route_requires_control(Get, "/operations/cohort-snapshot"),
  )
  let html = moongate_rabbita_document_html()
  for
    id in [
      "cohort-query", "cohort-app", "cohort-streaming", "cohort-period", "cohort-capture",
      "cohort-refresh", "cohort-retry", "cohort-a-provider", "cohort-a-model", "cohort-b-provider",
      "cohort-b-model", "cohort-report", "cohort-export",
    ] {
    assert_true(html.contains("id=\"\{id}\""), msg=id)
  }
  assert_true(html.contains("/assets/moongate-cohorts.js"))
  assert_true(html.contains("/operations/cohort-snapshot"))
}

///|
async test "cohort comparison crosses authenticated native HTTP served assets and exact export" {
  let server = @httpx.Server::new("127.0.0.1", 0)
  defer server.close()
  let gateway = Gateway::new(host="127.0.0.1", port=server.port())
  gateway.control.token = Some("fixture-cohort-control")
  let end = @os.unix_seconds() - 2
  let fixture_stats = cohort_fixture_stats(end)
  for log in fixture_stats.request_logs {
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
      @fsx.with_temporary_directory("moongate-cohort-http-XXXXXX", async fn(
        dir,
      ) {
        let fixture_path = @pathx.join(dir, "fixture.json")
        let usage_dir = @pathx.join(dir, "usage")
        gateway.usage.stats.enable_persistent_store(storage_dir=usage_dir)
        gateway.usage.stats.save_persistent_store()
        let usage_path = @pathx.join(usage_dir, MOONGATE_USAGE_STORE_FILE)
        let before = @fsx.read_file(usage_path)
        let modified_before = @fs.mtime(usage_path)
        let files_before = @fs.readdir(
          usage_dir,
          include_hidden=true,
          sort=true,
        )
        let expected = cohort_test_snapshot(fixture_stats, end)
        let fixture : Json = {
          "end": end.to_json(),
          "expected": expected.to_json(),
        }
        @fsx.write_to_file(fixture_path, fixture.stringify())
        let result = @spawn.spawn(
          "node",
          ["--test", "tests/moongate-cohorts.test.cjs"],
          env={
            "MOONGATE_COHORT_TEST_URL": "http://127.0.0.1:\{server.port()}",
            "MOONGATE_COHORT_TEST_FIXTURE": fixture_path,
          },
          timeout=75000,
        )
        match @env.get_env_var("MOONGATE_COHORT_EVIDENCE") {
          Some(destination) =>
            @fsx.write_to_file(
              @pathx.join(destination, "native-ui-crossing.log"),
              result.stdout + result.stderr,
            )
          None => ()
        }
        assert_true(result.status == 0, msg=result.stdout + result.stderr)
        assert_eq(@fsx.read_file(usage_path), before)
        assert_eq(@fs.mtime(usage_path), modified_before)
        assert_eq(
          @fs.readdir(usage_dir, include_hidden=true, sort=true),
          files_before,
        )
      })
    })
  })
}
