///|
fn get(value : Json, key : String) -> Json {
  guard value is Object(obj) && obj.get(key) is Some(found) else {
    abort("Missing test field")
  }
  found
}

///|
fn open_capture(content : String) -> Json raise {
  match @har_diagnostics.inspect_capture_json(content) {
    Ok(value) => value
    Err(error) => fail(error)
  }
}

///|
fn fixture() -> String {
  "{\"log\":{\"version\":\"1.2\",\"entries\":[{\"request\":{\"method\":\"POST\",\"url\":\"https://API.fixture.invalid:443/PRIVATE_PATH_0?token=PRIVATE_QUERY#PRIVATE_FRAGMENT\",\"headers\":[{\"name\":\"Authorization\",\"value\":\"PRIVATE_HEADER\"}],\"cookies\":[{\"name\":\"session\",\"value\":\"PRIVATE_COOKIE\"}],\"postData\":{\"text\":\"PRIVATE_PROMPT\"}},\"response\":{\"status\":200,\"statusText\":\"PRIVATE_STATUS_TEXT\",\"content\":{\"text\":\"PRIVATE_RESPONSE\"},\"headers\":[{\"name\":\"Set-Cookie\",\"value\":\"PRIVATE_RESPONSE_HEADER\"}]},\"time\":105,\"timings\":{\"blocked\":-1,\"dns\":5,\"connect\":20,\"ssl\":15,\"send\":2,\"wait\":70,\"receive\":8},\"_error\":\"PRIVATE_ERROR\",\"comment\":\"PRIVATE_COMMENT\",\"startedDateTime\":\"2026-10-10T10:00:00.000Z\"},{\"request\":{\"method\":\"GET\",\"url\":\"https://api.fixture.invalid/PRIVATE_PATH_1?token=PRIVATE_QUERY#PRIVATE_FRAGMENT\",\"headers\":[{\"name\":\"Authorization\",\"value\":\"PRIVATE_HEADER\"}],\"cookies\":[{\"name\":\"session\",\"value\":\"PRIVATE_COOKIE\"}],\"postData\":{\"text\":\"PRIVATE_PROMPT\"}},\"response\":{\"status\":302,\"statusText\":\"PRIVATE_STATUS_TEXT\",\"content\":{\"text\":\"PRIVATE_RESPONSE\"},\"headers\":[{\"name\":\"Set-Cookie\",\"value\":\"PRIVATE_RESPONSE_HEADER\"}]},\"time\":10,\"timings\":{\"blocked\":0,\"dns\":-1,\"connect\":-1,\"send\":1,\"wait\":7,\"receive\":2},\"_error\":\"PRIVATE_ERROR\",\"comment\":\"PRIVATE_COMMENT\",\"startedDateTime\":\"2026-10-10T10:00:00.250Z\"},{\"request\":{\"method\":\"POST\",\"url\":\"https://api.fixture.invalid/PRIVATE_PATH_2?token=PRIVATE_QUERY#PRIVATE_FRAGMENT\",\"headers\":[{\"name\":\"Authorization\",\"value\":\"PRIVATE_HEADER\"}],\"cookies\":[{\"name\":\"session\",\"value\":\"PRIVATE_COOKIE\"}],\"postData\":{\"text\":\"PRIVATE_PROMPT\"}},\"response\":{\"status\":429,\"statusText\":\"PRIVATE_STATUS_TEXT\",\"content\":{\"text\":\"PRIVATE_RESPONSE\"},\"headers\":[{\"name\":\"Set-Cookie\",\"value\":\"PRIVATE_RESPONSE_HEADER\"}]},\"time\":85,\"timings\":{\"blocked\":3,\"send\":1,\"wait\":80,\"receive\":1},\"_error\":\"PRIVATE_ERROR\",\"comment\":\"PRIVATE_COMMENT\",\"startedDateTime\":\"2026-10-10T10:00:00.500Z\"},{\"request\":{\"method\":\"POST\",\"url\":\"https://backup.fixture.invalid/PRIVATE_PATH_3?token=PRIVATE_QUERY#PRIVATE_FRAGMENT\",\"headers\":[{\"name\":\"Authorization\",\"value\":\"PRIVATE_HEADER\"}],\"cookies\":[{\"name\":\"session\",\"value\":\"PRIVATE_COOKIE\"}],\"postData\":{\"text\":\"PRIVATE_PROMPT\"}},\"response\":{\"status\":0,\"statusText\":\"PRIVATE_STATUS_TEXT\",\"content\":{\"text\":\"PRIVATE_RESPONSE\"},\"headers\":[{\"name\":\"Set-Cookie\",\"value\":\"PRIVATE_RESPONSE_HEADER\"}]},\"time\":-1,\"timings\":{\"blocked\":-1,\"dns\":-1,\"connect\":-1,\"send\":-1,\"wait\":-1,\"receive\":-1,\"ssl\":-1},\"_error\":\"PRIVATE_ERROR\",\"comment\":\"PRIVATE_COMMENT\",\"startedDateTime\":\"2026-10-10T10:00:01.000Z\"},{\"request\":{\"method\":\"GET\",\"url\":\"https://api.fixture.invalid/PRIVATE_PATH_4?token=PRIVATE_QUERY#PRIVATE_FRAGMENT\",\"headers\":[{\"name\":\"Authorization\",\"value\":\"PRIVATE_HEADER\"}],\"cookies\":[{\"name\":\"session\",\"value\":\"PRIVATE_COOKIE\"}],\"postData\":{\"text\":\"PRIVATE_PROMPT\"}},\"response\":{\"status\":200,\"statusText\":\"PRIVATE_STATUS_TEXT\",\"content\":{\"text\":\"PRIVATE_RESPONSE\"},\"headers\":[{\"name\":\"Set-Cookie\",\"value\":\"PRIVATE_RESPONSE_HEADER\"}]},\"time\":0,\"timings\":{},\"_error\":\"PRIVATE_ERROR\",\"comment\":\"PRIVATE_COMMENT\",\"startedDateTime\":\"2026-10-10T10:00:00.125Z\"},{\"request\":{\"method\":\"POST\",\"url\":\"https://backup.fixture.invalid/PRIVATE_PATH_5?token=PRIVATE_QUERY#PRIVATE_FRAGMENT\",\"headers\":[{\"name\":\"Authorization\",\"value\":\"PRIVATE_HEADER\"}],\"cookies\":[{\"name\":\"session\",\"value\":\"PRIVATE_COOKIE\"}],\"postData\":{\"text\":\"PRIVATE_PROMPT\"}},\"response\":{\"status\":503,\"statusText\":\"PRIVATE_STATUS_TEXT\",\"content\":{\"text\":\"PRIVATE_RESPONSE\"},\"headers\":[{\"name\":\"Set-Cookie\",\"value\":\"PRIVATE_RESPONSE_HEADER\"}]},\"time\":250,\"timings\":{\"blocked\":0,\"dns\":0,\"connect\":60,\"ssl\":55,\"send\":2,\"wait\":180,\"receive\":8},\"_error\":\"PRIVATE_ERROR\",\"comment\":\"PRIVATE_COMMENT\",\"startedDateTime\":\"2026-10-10T11:00:01.500+01:00\"},{\"request\":{\"method\":\"GET\",\"url\":\"https://unknown.fixture.invalid/PRIVATE_PATH_6?token=PRIVATE_QUERY#PRIVATE_FRAGMENT\",\"headers\":[{\"name\":\"Authorization\",\"value\":\"PRIVATE_HEADER\"}],\"cookies\":[{\"name\":\"session\",\"value\":\"PRIVATE_COOKIE\"}],\"postData\":{\"text\":\"PRIVATE_PROMPT\"}},\"response\":{\"status\":null,\"statusText\":\"PRIVATE_STATUS_TEXT\",\"content\":{\"text\":\"PRIVATE_RESPONSE\"},\"headers\":[{\"name\":\"Set-Cookie\",\"value\":\"PRIVATE_RESPONSE_HEADER\"}]},\"time\":null,\"timings\":{},\"_error\":\"PRIVATE_ERROR\",\"comment\":\"PRIVATE_COMMENT\"}]}}"
}

///|
test "mixed capture opens without models or tokens and retains entry association" {
  let result = open_capture(fixture())
  assert_eq(get(result, "schema"), "moongate.har-diagnostics.v1".to_json())
  assert_eq(get(result, "captureEntries"), (7).to_json())
  assert_eq(get(result, "selectedEntries"), (7).to_json())
  let summary = get(result, "summary")
  assert_eq(get(summary, "httpErrorCount"), (2).to_json())
  assert_eq(get(summary, "noHttpResponseCount"), (1).to_json())
  assert_eq(get(summary, "unknownStatusCount"), (1).to_json())
  assert_eq(get(summary, "elapsedSampleCount"), (5).to_json())
  assert_eq(get(summary, "missingElapsedCount"), (2).to_json())
  assert_eq(get(summary, "missingStartCount"), (1).to_json())
  assert_eq(get(summary, "p50ElapsedMs"), (85).to_json())
  assert_eq(get(summary, "p95ElapsedMs"), (250).to_json())
  guard get(result, "entries") is Array(rows) else { fail("entries") }
  assert_eq(get(rows[0], "origin"), "https://api.fixture.invalid".to_json())
  assert_eq(get(rows[0], "longestRecordedPhase"), "wait".to_json())
  assert_eq(get(get(rows[0], "timingsMs"), "ssl"), (15).to_json())
  assert_eq(get(get(rows[0], "timingsMs"), "blocked"), Json::null())
  assert_eq(get(rows[3], "elapsedMs"), Json::null())
  assert_eq(get(rows[3], "longestRecordedPhase"), Json::null())
  assert_eq(get(rows[4], "elapsedMs"), (0).to_json())
  assert_eq(get(rows[4], "entry"), (5).to_json())
  assert_eq(get(rows[4], "startOffsetMs"), (125).to_json())
  assert_eq(get(rows[5], "startOffsetMs"), (1500).to_json())
  assert_eq(get(rows[6], "startedAtUnixMs"), Json::null())
  assert_true(!result.stringify().contains("PRIVATE_"))
  assert_true(!result.stringify().contains("/PRIVATE_PATH"))
}

///|
test "filters combine exact origins methods status and original entry numbers" {
  guard @har_diagnostics.inspect_capture_json(
      fixture(),
      request_method="post",
      status="errors",
      origin="https://API.fixture.invalid:443",
    )
    is Ok(result) else {
    fail("filter")
  }
  guard get(result, "entries") is Array(rows) else { fail("entries") }
  assert_eq(rows.length(), 1)
  assert_eq(get(rows[0], "entry"), (3).to_json())
  assert_eq(get(rows[0], "status"), (429).to_json())
  assert_eq(get(rows[0], "startOffsetMs"), (500).to_json())
  for
    (status, expected) in [
      ("0", 1),
      ("unknown", 1),
      ("2xx", 2),
      ("302", 1),
      ("errors", 2),
      ("1xx", 0),
    ] {
    guard @har_diagnostics.inspect_capture_json(fixture(), status~)
      is Ok(filtered) else {
      fail("status filter")
    }
    assert_eq(get(filtered, "selectedEntries"), expected.to_json())
  }
  guard @har_diagnostics.inspect_capture_json(fixture(), entry=6) is Ok(detail) else {
    fail("detail")
  }
  guard get(detail, "entries") is Array([row]) else { fail("detail row") }
  assert_eq(get(row, "entry"), (6).to_json())
  assert_eq(get(row, "outcome"), "server_error".to_json())
  guard @har_diagnostics.inspect_capture_json(fixture(), entry=6, status="2xx")
    is Ok(empty) else {
    fail("intersection")
  }
  assert_eq(get(empty, "selectedEntries"), (0).to_json())
  assert_eq(get(get(empty, "summary"), "p50ElapsedMs"), Json::null())
}

///|
test "empty and missing fields stay distinct from known zero" {
  let empty = open_capture("{\"log\":{\"version\":\"1.2\",\"entries\":[]}}")
  assert_eq(get(empty, "captureStartUnixMs"), Json::null())
  assert_eq(get(get(empty, "summary"), "p95ElapsedMs"), Json::null())
  let result = open_capture(
    "{\"log\":{\"version\":\"1.2\",\"entries\":[{\"request\":{\"method\":\"GET\",\"url\":\"http://localhost:80\"},\"response\":{},\"timings\":{\"ssl\":500,\"connect\":0,\"wait\":0},\"time\":0,\"startedDateTime\":\"PRIVATE_NOT_A_DATE\"}]}}",
  )
  guard get(result, "entries") is Array([row]) else { fail("entry") }
  assert_eq(get(row, "origin"), "http://localhost".to_json())
  assert_eq(get(row, "longestRecordedPhase"), "connect".to_json())
  assert_eq(get(row, "status"), Json::null())
  assert_eq(get(row, "startedAtUnixMs"), Json::null())
  assert_eq(get(get(result, "summary"), "p50ElapsedMs"), (0).to_json())
  assert_true(!result.stringify().contains("PRIVATE_"))
}

///|
test "malformed captures fail atomically even when filters exclude the bad row" {
  for
    bad in [
      "broken", "[]", "{\"log\":{\"version\":\"1.1\",\"entries\":[]}}", "{\"log\":{\"version\":\"1.2\",\"entries\":[{}]}}",
      "{\"log\":{\"version\":\"1.2\",\"entries\":[{\"request\":{\"method\":\"GET\",\"url\":\"https://x.invalid\"},\"response\":{\"status\":600}}]}}",
      "{\"log\":{\"version\":\"1.2\",\"entries\":[{\"request\":{\"method\":\"GET\",\"url\":\"https://x.invalid\"},\"response\":{\"status\":\"200\"}}]}}",
      "{\"log\":{\"version\":\"1.2\",\"entries\":[{\"request\":{\"method\":\"GET\",\"url\":\"https://x.invalid\"},\"response\":{\"status\":200},\"time\":-2}]}}",
      "{\"log\":{\"version\":\"1.2\",\"entries\":[{\"request\":{\"method\":\"GET\",\"url\":\"https://x.invalid\"},\"response\":{\"status\":200},\"timings\":{\"wait\":\"10\"}}]}}",
      "{\"log\":{\"version\":\"1.2\",\"entries\":[{\"request\":{\"method\":\"GET\",\"url\":\"https://x.invalid\"},\"response\":{\"status\":200},\"timings\":[]}]}}",
    ] {
    assert_true(
      @har_diagnostics.inspect_capture_json(bad, request_method="POST")
      is Err(_),
    )
  }
}

///|
test "origin extraction excludes credential paths query fragments and diagnostic errors" {
  for
    url in [
      "https://PRIVATE_USER:PRIVATE_PASSWORD@host.invalid/x", "https://host.invalid:bad",
      "https://host.invalid:70000", "https://host.invalid:", "https://host.invalid\\PRIVATE_X",
      "https://%50RIVATE.invalid", "file:///PRIVATE_X", "https://[bad::name]",
    ] {
    let input : Json = {
      "log": {
        "version": "1.2",
        "entries": [
          {
            "request": { "method": "GET", "url": url.to_json() },
            "response": { "status": 200 },
          },
        ],
      },
    }
    guard @har_diagnostics.inspect_capture_json(input.stringify()) is Err(error) else {
      fail("accepted unsupported origin")
    }
    assert_true(!error.contains("PRIVATE_"))
  }
  let result = open_capture(
    "{\"log\":{\"version\":\"1.2\",\"entries\":[{\"request\":{\"method\":\"GET\",\"url\":\"http://[::1]:15721/PRIVATE_PATH?secret=PRIVATE_QUERY\"},\"response\":{\"status\":200}}]}}",
  )
  guard get(result, "entries") is Array([row]) else { fail("ipv6") }
  assert_eq(get(row, "origin"), "http://[::1]:15721".to_json())
}

///|
test "invalid filters and out of range original entry are rejected" {
  for status in ["600", "099", "0200", "2XXx", "failure", "-1", "200.0"] {
    assert_true(
      @har_diagnostics.inspect_capture_json(fixture(), status~) is Err(_),
    )
  }
  for
    origin in [
      "https://host.invalid/path", "https://host.invalid?query=x", "https://host.invalid#fragment",
      "host.invalid",
    ] {
    assert_true(
      @har_diagnostics.inspect_capture_json(fixture(), origin~) is Err(_),
    )
  }
  assert_true(
    @har_diagnostics.inspect_capture_json(fixture(), request_method="BAD")
    is Err(_),
  )
  assert_true(
    @har_diagnostics.inspect_capture_json(fixture(), entry=8) is Err(_),
  )
  assert_true(
    @har_diagnostics.inspect_capture_json(fixture(), entry=-1) is Err(_),
  )
}

///|
test "timestamp fractions and zones are normalized without leaking malformed timestamp text" {
  let starts = [
    "2026-10-10T00:00:00.123456Z", "2026-10-09T23:00:00.123456-01:00", "2026-02-30T00:00:00Z",
    "2026-10-10T00:00:00.PRIVATE_Z", "2026-10-10T00:00:00", "2026-10-10T00:00:00+24:00",
  ]
  let entries : Array[Json] = starts.map(start => {
    (
      {
        "request": { "method": "GET", "url": "https://x.invalid" },
        "response": { "status": 200 },
        "startedDateTime": start.to_json(),
      } : Json)
  })
  let input : Json = {
    "log": { "version": "1.2", "entries": entries.to_json() },
  }
  let result = open_capture(input.stringify())
  guard get(result, "entries") is Array(rows) else { fail("rows") }
  assert_true(get(rows[0], "startedAtUnixMs") is Number(_, ..))
  assert_eq(get(rows[0], "startedAtUnixMs"), get(rows[1], "startedAtUnixMs"))
  assert_eq(get(rows[0], "startOffsetMs"), (0).to_json())
  for i = 2; i < rows.length(); i = i + 1 {
    assert_eq(get(rows[i], "startedAtUnixMs"), Json::null())
  }
  assert_true(!result.stringify().contains("PRIVATE_"))
}
