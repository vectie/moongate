///|
fn csv(
  content : String,
  status? : String = "",
  entry? : Int = 0,
) -> String raise {
  match @har_diagnostics.export_capture_csv(content, status~, entry~) {
    Ok(value) => value
    Err(error) => fail(error)
  }
}

///|
test "CSV exports stable redacted columns and distinguishes unknown from zero" {
  let output = csv(fixture())
  let lines = output.split("\r\n").collect()
  assert_eq(lines.length(), 9)
  assert_eq(
    lines[0].to_owned(),
    "entry,method,origin,status,outcome,startedAtUnixMs,startOffsetMs,elapsedMs,blockedMs,dnsMs,connectMs,sendMs,waitMs,receiveMs,sslMs,longestRecordedPhase",
  )
  let first = lines[1].split(",").collect()
  assert_eq(first.length(), 16)
  assert_eq(first[0].to_owned(), "1")
  assert_eq(first[2].to_owned(), "\"https://api.fixture.invalid\"")
  assert_eq(first[8].to_owned(), "")
  assert_eq(first[10].to_owned(), "20")
  assert_eq(first[14].to_owned(), "15")
  assert_eq(first[15].to_owned(), "\"wait\"")
  let zero = lines[5].split(",").collect()
  assert_eq(zero[7].to_owned(), "0")
  let unknown = lines[7].split(",").collect()
  for index in [3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15] {
    assert_eq(unknown[index].to_owned(), "")
  }
  assert_true(!output.contains("PRIVATE_"))
}

///|
test "CSV filters retain original entry and capture relative timing" {
  let output = csv(fixture(), entry=6, status="errors")
  let lines = output.split("\r\n").collect()
  assert_eq(lines.length(), 3)
  let cells = lines[1].split(",").collect()
  assert_eq(cells[0].to_owned(), "6")
  assert_eq(cells[6].to_owned(), "1500")
  assert_eq(csv(fixture(), status="1xx").split("\r\n").collect().length(), 2)
  assert_eq(
    csv("{\"log\":{\"version\":\"1.2\",\"entries\":[]}}")
    .split("\r\n")
    .collect()
    .length(),
    2,
  )
}

///|
test "CSV rejects malformed captures including excluded rows before any output" {
  assert_true(@har_diagnostics.export_capture_csv("bad") is Err(_))
  assert_true(@har_diagnostics.export_capture_csv(fixture(), entry=8) is Err(_))
  assert_true(
    @har_diagnostics.export_capture_csv(fixture(), status="600") is Err(_),
  )
  assert_true(
    @har_diagnostics.export_capture_csv(
      "{\"log\":{\"version\":\"1.2\",\"entries\":[{}]}}",
      request_method="GET",
    )
    is Err(_),
  )
}
