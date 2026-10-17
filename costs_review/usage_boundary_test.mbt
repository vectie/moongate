///|
fn boundary_costs() -> String {
  let page =
    #|{"object":"page","data":[{"object":"bucket","start_time":1730419200,"end_time":1730505600,"results":[{"object":"organization.costs.result","amount":{"value":2,"currency":"usd"}}]}],"has_more":false}
  page
}

///|
fn boundary_row(date? : Json = "2024-11-01") -> Json {
  {
    "model": "m",
    "totalTokens": 1,
    "costUsd": 1,
    "provider": "fixture-route",
    "date": date,
  }
}

///|
fn boundary_review(source : String) -> Result[Json, String] {
  @costs_review.review_openai_costs_json(
    source,
    boundary_costs(),
    provider="fixture-route",
    scope="Synthetic corresponding source",
  )
}

///|
fn boundary_field(value : Json, key : String) -> Json raise {
  guard value is Object(fields) && fields.get(key) is Some(value) else {
    fail("Missing " + key)
  }
  value
}

///|
test "all retained CSV provenance headers reject before column loss including quoted BOM headers" {
  for
    name in [
      "usageEvidenceKind", "usageScenarioName", "usagePricing", "sourceTotal", "importedRows",
      "filteredRows", "partialSource", "sourceCoverageUnknown", "partial",
    ] {
    let csv = "\u{FEFF}model,totalTokens,costUsd,provider,date,\" " +
      name +
      " \"\r\nm,1,1,fixture-route,2024-11-01,false\r\n"
    assert_true(boundary_review(csv) is Err(_), msg=name)
  }
}

///|
test "JSON single array and JSONL records cannot erase row-level evidence metadata" {
  for
    name in [
      "usageEvidenceKind", "usageScenarioName", "usagePricing", "sourceTotal", "importedRows",
      "filteredRows", "partialSource", "sourceCoverageUnknown", "partial",
    ] {
    guard boundary_row() is Object(fields) else { fail("row") }
    fields[name] = true.to_json()
    let marked = Json::object(fields)
    for
      source in [
        marked.stringify(),
        [marked].to_json().stringify(),
        boundary_row().stringify() + "\n" + marked.stringify(),
      ] {
      assert_true(boundary_review(source) is Err(_), msg=name)
    }
  }
}

///|
test "envelope partial flags remain conservative and malformed flag types reject" {
  for name in ["partial", "partialSource", "sourceCoverageUnknown"] {
    let fields : Map[String, Json] = {
      "data": [boundary_row()].to_json(),
      "partial": false.to_json(),
    }
    fields[name] = true.to_json()
    guard boundary_review(Json::object(fields).stringify()) is Ok(result) else {
      fail("explicit partial")
    }
    assert_eq(boundary_field(result, "localSourcePartial"), true.to_json())
    assert_eq(boundary_field(result, "pairedDays"), Json::number(0))
    for invalid in [Json::null(), "true".to_json(), Json::number(1)] {
      fields[name] = invalid
      assert_true(boundary_review(Json::object(fields).stringify()) is Err(_))
    }
  }
}

///|
test "envelope row counts cannot silently shrink retained coverage" {
  for name in ["sourceTotal", "total", "importedRows"] {
    let fields : Map[String, Json] = {
      "data": [boundary_row()].to_json(),
      "partial": false.to_json(),
    }
    fields[name] = Json::number(2)
    guard boundary_review(Json::object(fields).stringify()) is Ok(result) else {
      fail("larger source count")
    }
    assert_eq(boundary_field(result, "localSourcePartial"), true.to_json())
    assert_eq(boundary_field(result, "pairedDays"), Json::number(0))
    for
      invalid in [
        Json::number(0),
        Json::number(1.5),
        "2".to_json(),
        Json::number(-1),
      ] {
      fields[name] = invalid
      assert_true(boundary_review(Json::object(fields).stringify()) is Err(_))
    }
  }
  for count in [0, 2] {
    let source : Json = {
      "data": [boundary_row()].to_json(),
      "filteredRows": count.to_json(),
    }
    assert_true(boundary_review(source.stringify()) is Err(_))
  }
}

///|
test "hypothetical envelope markers reject even without their usual companions" {
  for name in ["usageEvidenceKind", "usageScenarioName", "usagePricing"] {
    let fields : Map[String, Json] = { "data": [boundary_row()].to_json() }
    fields[name] = Json::null()
    assert_true(boundary_review(Json::object(fields).stringify()) is Err(_))
  }
}

///|
test "complete dates offsets fractions and numeric timestamps are preserved on supported paths" {
  for
    date in [
      "2024-11-01", "2024-11-01T00:00:00Z", "2024-11-01T00:00:00.123456789Z", "2024-11-02T00:30:00.5+01:00",
    ] {
    let row = boundary_row(date=date.to_json())
    for
      source in [
        row.stringify(),
        [row].to_json().stringify(),
        row.stringify() + "\n" + row.stringify(),
        "model,totalTokens,costUsd,provider,date\nm,1,1,fixture-route," + date,
      ] {
      guard boundary_review(source) is Ok(result) else {
        fail("valid source: " + date)
      }
      assert_eq(boundary_field(result, "localUndatedRows"), Json::number(0))
      assert_eq(boundary_field(result, "pairedDays"), Json::number(1))
    }
  }
  guard boundary_review(boundary_row(date=1730419200.5.to_json()).stringify())
    is Ok(result) else {
    fail("numeric epoch")
  }
  assert_eq(boundary_field(result, "pairedDays"), Json::number(1))
}

///|
test "invalid nonempty timestamps reject in CSV JSON arrays envelopes and JSONL" {
  for
    date in [
      "2024-11-01T00:00:00INVALIDZ", "2024-11-01T00:00:00.INVALIDZ", "2024-11-01T00:00:00.Z",
      "2024-11-01T00:00:00.1234567890Z", "2024-11-01T00:00:00x+01:00", "2024-11-01T00:00:00+24:00",
      "2024-11-01T00:00:00+00:60", "2024-11-01T00:00:00", "2024-02-30", "2024-11-01T99:00:00Z",
    ] {
    let row = boundary_row(date=date.to_json())
    let envelope : Json = { "data": [row].to_json() }
    for
      source in [
        row.stringify(),
        [row].to_json().stringify(),
        envelope.stringify(),
        boundary_row().stringify() + "\n" + row.stringify(),
        "model,totalTokens,costUsd,provider,date\nm,1,1,fixture-route," + date,
      ] {
      assert_true(boundary_review(source) is Err(_), msg=date)
    }
  }
}

///|
test "timestamp alias precedence is checked before normalizer chooses a day" {
  for key in ["createdAt", "created_at", "timestamp", "date"] {
    guard boundary_row() is Object(fields) else { fail("row") }
    fields[key] = "2024-11-01T00:00:00INVALIDZ".to_json()
    assert_true(boundary_review(Json::object(fields).stringify()) is Err(_))
  }
}

///|
test "missing and empty dates remain undated while ordinary complete metadata remains usable" {
  for date in [Json::null(), "".to_json()] {
    guard boundary_review(boundary_row(date~).stringify()) is Ok(result) else {
      fail("undated")
    }
    assert_eq(boundary_field(result, "localUndatedRows"), Json::number(1))
    assert_eq(boundary_field(result, "pairedDays"), Json::number(0))
  }
  let source : Json = {
    "data": [boundary_row()].to_json(),
    "partial": false,
    "sourceCoverageUnknown": false,
    "sourceTotal": 1,
    "importedRows": 1,
    "filteredRows": 1,
  }
  guard boundary_review(source.stringify()) is Ok(result) else {
    fail("complete envelope")
  }
  assert_eq(boundary_field(result, "pairedDays"), Json::number(1))
}

///|
test "unsupported transcript wrappers cannot bypass usage evidence validation" {
  let wrapped : Json = {
    "messages": [boundary_row(date="2024-11-01T00:00:00INVALIDZ")].to_json(),
  }
  assert_true(boundary_review(wrapped.stringify()) is Err(_))
  let malformed : Json = { "model": "m", "totalTokens": 1, "data": false }
  assert_true(boundary_review(malformed.stringify()) is Err(_))
}
