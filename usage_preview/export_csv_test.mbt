///|
test "spreadsheet requests preserve unknown zero filters and provenance" {
  let content =
    #|{"data":[{"requestId":"001","model":"m","app":"a","inputTokens":0,"outputTokens":2,"costUsd":0,"date":"2026-10-09"},{"requestId":"002","model":"n","totalTokens":3}],"total":9,"sourceCoverageUnknown":true}
  guard @usage_preview.export_usage_csv(content, app="a") is Ok(csv) else {
    fail("export")
  }
  assert_true(
    csv.contains(
      "\"'001\",\"'a\",\"'Unknown\",\"'m\",\"'2026-10-09\",0,2,2,0,9,2,1,true,true",
    ),
  )
  guard @usage_preview.export_usage_csv(content, model="n") is Ok(csv) else {
    fail("export")
  }
  assert_true(csv.contains("\"'n\",,,,3,,9,2,1,true,true"))
}

///|
test "all text fields are quoted and prefixed including multiline formulas" {
  let source =
    #|[{"requestId":"=SUM(1,2)","app":"+run","provider":"@x","model":"\t-1,\"moon\"\n新","totalTokens":0}]
  guard @usage_preview.export_usage_csv(source) is Ok(csv) else {
    fail("export")
  }
  assert_true(csv.contains("\"'=SUM(1,2)\""))
  assert_true(csv.contains("\"'+run\",\"'@x\""))
  assert_true(csv.contains("\"'\t-1,\"\"moon\"\"\n新\""))
}

///|
test "grouped and summary estimates keep missing counts beside known subtotal" {
  let source =
    #|[{"model":"b","totalTokens":2,"costUsd":0.25,"date":"2026-10-09"},{"model":"a","totalTokens":3},{"model":"b","totalTokens":4,"costUsd":0}]
  guard @usage_preview.export_usage_csv(source, view="model") is Ok(csv) else {
    fail("groups")
  }
  assert_true(
    csv.contains("\"'a\",1,3,0,1,1,3,3,3,false,false\r\n\"'b\",2,6,0.25,0,1"),
  )
  guard @usage_preview.export_usage_csv(source, view="summary") is Ok(csv) else {
    fail("summary")
  }
  assert_true(csv.contains("\"'TOTAL\",3,9,0.25,1,2,3,3,3,false,false"))
  for view in ["provider", "app", "day"] {
    assert_true(@usage_preview.export_usage_csv(source, view~) is Ok(_))
  }
}

///|
test "empty filters retain header and summary provides zero match context" {
  let source = "{\"data\":[],\"total\":9}"
  guard @usage_preview.export_usage_csv(source) is Ok(csv) else {
    fail("empty")
  }
  assert_eq(csv.split("\r\n").collect().length(), 2)
  guard @usage_preview.export_usage_csv(source, view="summary") is Ok(summary) else {
    fail("summary")
  }
  assert_true(summary.contains("\"'TOTAL\",0,0,0,0,0,9,0,0,true,false"))
}

///|
test "CSV JSONL and UTC filters use existing preview semantics" {
  let source = "model,totalTokens,date\nb,4,2026-10-09T01:00:00+02:00\na,2,2026-10-09\n"
  guard @usage_preview.export_usage_csv(
      source,
      source_name="input.csv",
      start_day="2026-10-08",
      end_day="2026-10-08",
    )
    is Ok(csv) else {
    fail("csv")
  }
  assert_true(csv.contains("\"'b\",\"'2026-10-08\""))
  assert_true(!csv.contains("\"'a\""))
  assert_true(
    @usage_preview.export_usage_csv(
      "{\"model\":\"a\",\"totalTokens\":1}\n{\"model\":\"b\",\"totalTokens\":2}",
    )
    is Ok(_),
  )
}

///|
test "invalid inputs and inexact grouped token totals fail before CSV" {
  for source in ["bad", "[{\"model\":\"a\",\"totalTokens\":-1}]"] {
    assert_true(@usage_preview.export_usage_csv(source) is Err(_))
  }
  assert_true(@usage_preview.export_usage_csv("[]", view="invalid") is Err(_))
  assert_true(
    @usage_preview.export_usage_csv("[]", start_day="2026-02-30") is Err(_),
  )
  let source = "[{\"model\":\"a\",\"totalTokens\":9007199254740991},{\"model\":\"a\",\"totalTokens\":1}]"
  assert_true(@usage_preview.export_usage_csv(source, view="model") is Err(_))
}
