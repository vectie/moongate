///|
test "HAR limits reject oversized entry counts and byte input" {
  let entries : Array[Json] = []
  for _ in 0..<2001 {
    entries.push(Json::null())
  }
  let source : Json = {
    "log": { "version": "1.2", "entries": entries.to_json() },
  }
  assert_true(moongate_har_collection_json(source.stringify()) is Err(_))
  let chunks : Array[String] = []
  for _ in 0..<1025 {
    chunks.push("a".repeat(4096))
  }
  assert_true(moongate_har_collection_json(chunks.join("")) is Err(_))
}

///|
test "HAR capture yields editable requests preserving repeated query and JSON text" {
  let source =
    #|{"log":{"version":"1.2","entries":[{"request":{"method":"POST","url":"https://api.example.invalid/v1/chat?tag=a&tag=b#ignored","headers":[{"name":"Accept","value":"application/json"}],"postData":{"mimeType":"application/json","text":"{\"model\":\"fixture\",\"stream\":false}"}},"response":{"content":{"text":"DO_NOT_COPY_RESPONSE"}}},{"request":{"method":"GET","url":"https://api.example.invalid/v1/models","headers":[]}}]}}
  let result = moongate_har_collection_json(
    source,
    request_method="post",
    url_contains="/chat",
  ).unwrap()
  assert_eq(gate_oas_field(result, "sourceEntries"), Json::number(2))
  assert_eq(gate_oas_field(result, "selectedRequests"), Json::number(1))
  let http = gate_oas_text(result, "http")
  assert_true(
    http.contains("POST https://api.example.invalid/v1/chat?tag=a&tag=b"),
  )
  assert_true(http.contains("Content-Type: application/json"))
  assert_true(http.contains("{\"model\":\"fixture\",\"stream\":false}"))
  assert_true(!result.stringify().contains("DO_NOT_COPY_RESPONSE"))
  assert_true(!http.contains("#ignored"))
  assert_eq(
    gate_oas_field(
      moongate_har_collection_json(source, request_method="DELETE").unwrap(),
      "selectedRequests",
    ),
    Json::number(0),
  )
}

///|
test "HAR auth withheld while repeated ordinary headers remain editable" {
  let source =
    #|{"log":{"version":"1.2","entries":[{"request":{"method":"GET","url":"https://api.example.invalid/models?api_key=QUERY_SECRET&%74oken=ENCODED_SECRET&limit=2","cookies":[{"name":"session","value":"COOKIE_ARRAY_SECRET"}],"headers":[{"name":"Authorization","value":"Bearer HEADER_SECRET"},{"name":"Cookie","value":"COOKIE_SECRET"},{"name":"Host","value":"host.example.invalid"},{"name":"Content-Length","value":"999"},{"name":"X-Tag","value":"a"},{"name":"X-Tag","value":"b"}]}}]}}
  let result = moongate_har_collection_json(source).unwrap()
  assert_true(!result.stringify().contains("SECRET"))
  let http = gate_oas_text(result, "http")
  assert_true(http.contains("api_key=REPLACE_ME&%74oken=REPLACE_ME&limit=2"))
  assert_true(http.contains("@auth_1_0 = REPLACE_ME"))
  assert_true(http.contains("Authorization: {{auth_1_0}}"))
  assert_true(http.contains("X-Tag: a\nX-Tag: b"))
  assert_true(!http.contains("Content-Length: 999"))
}

///|
test "HAR unsupported bodies are explicit and empty text is preserved" {
  let source =
    #|{"log":{"version":"1.2","entries":[{"request":{"method":"POST","url":"https://example.invalid/form","headers":[],"postData":{"mimeType":"multipart/form-data","text":"BINARY_SECRET"}}},{"request":{"method":"POST","url":"https://example.invalid/empty","headers":[],"postData":{"mimeType":"text/plain","text":""}}},{"request":{"method":"POST","url":"https://example.invalid/params","headers":[],"postData":{"mimeType":"application/x-www-form-urlencoded","params":[{"name":"x","value":"a"}]}}}]}}
  let result = moongate_har_collection_json(source).unwrap()
  assert_eq(gate_oas_field(result, "selectedRequests"), Json::number(3))
  assert_true(!result.stringify().contains("BINARY_SECRET"))
  let requests = gate_oas_array(gate_oas_field(result, "requests"))
  assert_eq(gate_oas_array(gate_oas_field(requests[1], "warnings")).length(), 0)
  assert_true(
    gate_oas_text(result, "http").contains("reconstruct postData.params"),
  )
}

///|
test "HAR rejects unsupported documents and unsafe selected request lines" {
  for
    source in [
      "not json",
      "{}",
      "{\"log\":{\"version\":\"1.1\",\"entries\":[]}}",
      "{\"log\":{\"version\":\"1.2\",\"entries\":{}}}",
      (
        #|{"log":{"version":"1.2","entries":[{"request":{"method":"GET","url":"file:///tmp/input","headers":[]}}]}}
      ),
      (
        #|{"log":{"version":"1.2","entries":[{"request":{"method":"GET","url":"https://user:pass@example.invalid/","headers":[]}}]}}
      ),
      (
        #|{"log":{"version":"1.2","entries":[{"request":{"method":"GET","url":"https://example.invalid/","headers":[{"name":"X-Value","value":"hello\r\nInjected: yes"}]}}]}}
      ),
      (
        #|{"log":{"version":"1.2","entries":[{"request":{"method":"GET","url":"https://example.invalid/\nGET","headers":[]}}]}}
      ),
    ] {
    assert_true(moongate_har_collection_json(source) is Err(_))
  }
  assert_true(
    moongate_har_collection_json(
      "{\"log\":{\"version\":\"1.2\",\"entries\":[]}}",
      request_method="WRONG",
    )
    is Err(_),
  )
}
