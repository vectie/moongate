///|
test "aliases preserve missing and zero cost and drop unknown columns" {
  let result = @usage_csv.to_json(
    "model_name,input_tokens,output_tokens,cost_usd,secret\na,2,3,,hidden\nb,4,5,0,hidden\n",
  )
  assert_eq(result, [
    { "model": "a", "inputTokens": "2", "outputTokens": "3" },
    {
      "model": "b",
      "inputTokens": "4",
      "outputTokens": "5",
      "totalCostUsd": "0",
    },
  ])
}

///|
test "quoted comma quote newline Unicode BOM and CRLF" {
  let result = @usage_csv.to_json(
    "\u{FEFF}model,totalTokens,provider\r\n\"月,小\",12,\"team\"\"one\nnext\"\r\n",
  )
  assert_eq(result, [
    { "model": "月,小", "totalTokens": "12", "providerId": "team\"one\nnext" },
  ])
}

///|
test "empty input and malformed CSV reject" {
  for
    input in [
      "", "model,totalTokens\na", "model,totalTokens\n\"a,1", "model,totalTokens\na\"b,1",
      "model,totalTokens\n\"a\"x,1", "model,model_name,totalTokens\na,b,1", "model,costUsd\na,1",
      "model,totalTokens\na,1\n\n",
    ] {
    let rejected = try {
      let _ = @usage_csv.to_json(input)
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "header-only and trailing empty cells" {
  assert_eq(@usage_csv.to_json("model,totalTokens\n"), [])
  assert_eq(@usage_csv.to_json("model,totalTokens,costUsd\na,1,"), [
    { "model": "a", "totalTokens": "1" },
  ])
}

///|
test "row limit includes final unterminated row" {
  let source = "model,totalTokens\n" + Array::make(10000, "a,1").join("\n")
  guard @usage_csv.to_json(source) is Array(rows) else {
    fail("Expected array")
  }
  assert_eq(rows.length(), 10000)
  let rejected = try {
    let _ = @usage_csv.to_json(source + "\na,1")
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "UTF-8 byte limit applies before parsing" {
  let rejected = try {
    let _ = @usage_csv.to_json(Array::make(2097153, "é").join(""))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
