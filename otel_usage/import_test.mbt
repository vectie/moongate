///|
fn get(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn attribute(key : String, value : Json) -> Json {
  { "key": key.to_json(), "value": value }
}

///|
fn span(
  id? : String = "abcdef1234567890",
  input? : Json = { "intValue": "100" },
  output? : Json = { "intValue": "20" },
) -> Json {
  {
    "traceId": "1234567890abcdef1234567890abcdef",
    "spanId": id.to_json(),
    "kind": 3,
    "name": "PRIVATE_SPAN_NAME",
    "startTimeUnixNano": "1791849599999999999",
    "endTimeUnixNano": "1791849600123456789",
    "attributes": [
      attribute("gen_ai.operation.name", { "stringValue": "chat" }),
      attribute("gen_ai.request.model", { "stringValue": "requested-alias" }),
      attribute("gen_ai.response.model", { "stringValue": "fixture-model" }),
      attribute("gen_ai.provider.name", { "stringValue": "fixture-provider" }),
      attribute("gen_ai.usage.input_tokens", input),
      attribute("gen_ai.usage.output_tokens", output),
      attribute("gen_ai.usage.cache_read.input_tokens", { "intValue": "80" }),
      attribute("gen_ai.usage.reasoning.output_tokens", { "intValue": "10" }),
      attribute("gen_ai.input.messages", { "stringValue": "PRIVATE_PROMPT" }),
      attribute("api_key", { "stringValue": "PRIVATE_SECRET" }),
    ],
    "status": { "code": 1, "message": "PRIVATE_STATUS" },
    "events": [{ "name": "PRIVATE_EVENT", "attributes": [] }],
  }
}

///|
fn set(value : Json, key : String, replacement : Json) -> Json {
  guard value is Object(fields) else { abort("fixture object") }
  fields[key] = replacement
  value
}

///|
fn omit_attribute(value : Json, key : String) -> Json {
  guard get(value, "attributes") is Array(attrs) else {
    abort("fixture attributes")
  }
  set(
    value,
    "attributes",
    attrs.filter(a => get(a, "key") != key.to_json()).to_json(),
  )
}

///|
fn replace_attribute(value : Json, key : String, replacement : Json) -> Json {
  let value = omit_attribute(value, key)
  guard get(value, "attributes") is Array(attrs) else {
    abort("fixture attributes")
  }
  attrs.push(attribute(key, replacement))
  value
}

///|
fn export_spans(spans : Array[Json]) -> Json {
  {
    "resourceSpans": [
      {
        "resource": {
          "attributes": [
            attribute("service.name", { "stringValue": "fixture-app" }),
            attribute("secret", { "stringValue": "PRIVATE_RESOURCE" }),
          ],
        },
        "scopeSpans": [
          { "scope": { "name": "PRIVATE_SCOPE" }, "spans": spans.to_json() },
        ],
      },
    ],
  }
}

///|
fn imported(content : String) -> Json raise {
  match @otel_usage.import_otel_usage_json(content) {
    Ok(value) => value
    Err(error) => fail(error)
  }
}

///|
fn reject(content : String, fragment : String) -> Unit raise {
  match @otel_usage.import_otel_usage_json(content) {
    Err(error) => {
      assert_true(error.contains(fragment), msg=error)
      assert_false(error.contains("PRIVATE_"))
    }
    Ok(_) => fail("Unexpected OTLP import success")
  }
}

///|
test "OTLP trace export becomes reopenable usage with exact nanosecond duration and UTC date" {
  let result = imported(export_spans([span()]).stringify())
  guard get(result, "data") is [row] else { fail("Expected one imported row") }
  assert_eq(get(row, "inputTokens"), Json::number(100))
  assert_eq(get(row, "outputTokens"), Json::number(20))
  assert_eq(get(row, "totalTokens"), Json::number(120))
  assert_eq(get(row, "totalCostUsd"), Json::null())
  assert_eq(get(row, "latencyMs"), Json::number(123.45679))
  assert_eq(get(row, "date"), Json::string("2026-10-12"))
  assert_eq(get(row, "model"), Json::string("fixture-model"))
  assert_eq(get(row, "appType"), Json::string("fixture-app"))
  assert_eq(get(row, "providerId"), Json::string("fixture-provider"))
  assert_eq(get(result, "sourceCoverageUnknown"), Json::boolean(true))
  assert_eq(get(result, "partial"), Json::boolean(true))
  assert_false(result.stringify().contains("PRIVATE_"))
  let preview = match
    @usage_preview.moongate_preview_usage_file_json(
      result.stringify(),
      model="fixture-model",
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_eq(get(preview, "summary"), get(result, "summary"))
  assert_eq(get(preview, "partial"), Json::boolean(true))
  let profile = match
    @usage_preview.profile_usage_latency_json(result.stringify()) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_eq(get(get(profile, "summary"), "sampleCount"), Json::number(1))
  let csv = match
    @usage_preview.export_usage_csv(result.stringify(), view="model") {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_true(csv.contains("fixture-model"))
  assert_false(csv.contains("PRIVATE_"))
}

///|
test "OTLP JSONL joins exported envelopes in order without deduplicating separate spans" {
  let a = export_spans([span()]).stringify()
  let b = export_spans([span(id="abcdef1234567891")]).stringify()
  let result = imported("\n" + a + "\r\n\r\n" + b + "\n")
  assert_eq(get(result, "total"), Json::number(2))
  assert_eq(get(get(result, "summary"), "tokens"), Json::number(240))
  assert_eq(get(get(result, "otelImport"), "sourceSpanCount"), Json::number(2))
}

///|
test "Nonclient generations agent spans tools and embeddings are excluded explicitly" {
  let result = imported(
    export_spans([
      span(),
      set(span(id="abcdef1234567891"), "kind", Json::number(2)),
      replace_attribute(span(id="abcdef1234567892"), "gen_ai.operation.name", {
        "stringValue": "invoke_agent",
      }),
      replace_attribute(span(id="abcdef1234567893"), "gen_ai.operation.name", {
        "stringValue": "embeddings",
      }),
      omit_attribute(span(id="abcdef1234567894"), "gen_ai.operation.name"),
    ]).stringify(),
  )
  assert_eq(get(result, "total"), Json::number(1))
  assert_eq(get(get(result, "otelImport"), "skippedSpanCount"), Json::number(4))
  assert_eq(
    get(get(result, "otelImport"), "candidateSpanCount"),
    Json::number(1),
  )
}

///|
test "Missing directional usage remains partial while explicit zeros produce known zero tokens" {
  let result = imported(
    export_spans([
      span(input={ "intValue": "0" }, output={ "intValue": 0 }),
      omit_attribute(span(id="abcdef1234567891"), "gen_ai.usage.output_tokens"),
      omit_attribute(
        omit_attribute(
          span(id="abcdef1234567892"),
          "gen_ai.usage.output_tokens",
        ),
        "gen_ai.usage.input_tokens",
      ),
    ]).stringify(),
  )
  assert_eq(get(result, "total"), Json::number(1))
  assert_eq(get(result, "sourceTotal"), Json::number(3))
  assert_eq(get(get(result, "summary"), "tokens"), Json::number(0))
  assert_eq(get(get(result, "summary"), "missingCostCount"), Json::number(1))
  let meta = get(result, "otelImport")
  assert_eq(get(meta, "incompleteUsageCount"), Json::number(2))
  guard get(meta, "outcomes") is [_, partial, missing] else {
    fail("Expected outcomes")
  }
  assert_eq(get(partial, "inputTokens"), Json::number(100))
  assert_eq(get(partial, "outputTokens"), Json::null())
  assert_eq(get(partial, "totalTokens"), Json::null())
  assert_eq(get(missing, "totalTokens"), Json::null())
}

///|
test "Returned model wins requested fallback is labeled and missing model is not invented" {
  let fallback = omit_attribute(span(), "gen_ai.response.model")
  let absent = omit_attribute(
    omit_attribute(span(id="abcdef1234567891"), "gen_ai.response.model"),
    "gen_ai.request.model",
  )
  let result = imported(export_spans([fallback, absent]).stringify())
  guard get(result, "data") is [row] else { fail("Expected fallback row") }
  assert_eq(get(row, "model"), Json::string("requested-alias"))
  assert_eq(
    get(get(result, "otelImport"), "missingModelCount"),
    Json::number(1),
  )
  guard get(get(result, "otelImport"), "outcomes") is [one, two] else {
    fail("Expected outcomes")
  }
  assert_eq(get(one, "modelSource"), Json::string("request"))
  assert_eq(get(two, "totalTokens"), Json::number(120))
  assert_eq(get(two, "usageState"), Json::string("missing_model"))
}

///|
test "Error and unset statuses retain observed usage without claiming successful completion" {
  let result = imported(
    export_spans([
      set(span(), "status", { "code": 2, "message": "PRIVATE_ERROR" }),
      set(span(id="abcdef1234567891"), "status", Json::null()),
    ]).stringify(),
  )
  assert_eq(get(result, "total"), Json::number(2))
  assert_eq(get(get(result, "otelImport"), "errorSpanCount"), Json::number(1))
  guard get(get(result, "otelImport"), "outcomes") is [one, two] else {
    fail("Expected outcomes")
  }
  assert_eq(get(one, "status"), Json::string("error"))
  assert_eq(get(two, "status"), Json::string("unset"))
  assert_false(result.stringify().contains("PRIVATE_"))
}

///|
test "Repeated case-insensitive span identities reject the entire export" {
  reject(
    export_spans([span(), span(id="ABCDEF1234567890")]).stringify(),
    "Duplicate candidate",
  )
  for id in ["", "0".repeat(16), "g".repeat(16), "abc", "PRIVATE_ID"] {
    reject(export_spans([span(id~)]).stringify(), "nonzero 32-digit")
  }
  reject(
    export_spans([set(span(), "traceId", Json::string("0".repeat(32)))]).stringify(),
    "nonzero 32-digit",
  )
}

///|
test "String numeric and raw-number token precision and overflow are explicit" {
  let invalid : Array[Json] = [
    { "intValue": "-1" },
    { "intValue": "1.5" },
    { "intValue": "1e2" },
    { "intValue": "9007199254740992" },
    { "intValue": true },
    { "intValue": -1 },
    { "doubleValue": 1 },
    Json::null(),
    { "intValue": 1, "stringValue": "1" },
  ]
  for value in invalid {
    reject(export_spans([span(input=value)]).stringify(), "Token")
  }
  let base = export_spans([span(input={ "intValue": 1 })]).stringify()
  for
    raw in [
      "1e-400", "1.0000000000000001", "9007199254740990.5", "9007199254740992",
    ] {
    reject(
      base.replace(old="\"intValue\":1", new="\"intValue\":" + raw),
      "exact whole",
    )
  }
  reject(
    export_spans([span(input={ "intValue": "9007199254740991" })]).stringify(),
    "Combined token",
  )
  reject(
    export_spans([
      span(input={ "intValue": "9007199254740991" }, output={ "intValue": "0" }),
      span(id="abcdef1234567891"),
    ]).stringify(),
    "Aggregate token",
  )
}

///|
test "Missing timestamps leave unknown duration and zero duration stays measured" {
  let result = imported(
    export_spans([
      set(
        set(span(), "startTimeUnixNano", Json::string("0")),
        "endTimeUnixNano",
        Json::null(),
      ),
      set(
        span(id="abcdef1234567891"),
        "endTimeUnixNano",
        Json::string("1791849599999999999"),
      ),
    ]).stringify(),
  )
  guard get(result, "data") is [one, two] else { fail("Expected rows") }
  assert_eq(get(one, "date"), Json::string(""))
  assert_eq(get(one, "latencyMs"), Json::null())
  assert_eq(get(two, "latencyMs"), Json::number(0))
  for
    timestamp in [
      Json::number(1791849599),
      Json::string("1e18"),
      Json::string("-1"),
      Json::string("18446744073709551616"),
    ] {
    reject(
      export_spans([set(span(), "startTimeUnixNano", timestamp)]).stringify(),
      "timestamp",
    )
  }
  reject(
    export_spans([set(span(), "endTimeUnixNano", Json::string("1"))]).stringify(),
    "end precedes",
  )
}

///|
test "Malformed containers attributes statuses and JSONL fail with content-free diagnostics" {
  for
    text in [
      "{PRIVATE_BAD", "[]", "{}", " ", "{\"resourceSpans\":[{}]}", "{\"resourceSpans\":[{\"scopeSpans\":[{}]}]}",
    ] {
    reject(text, "OTLP")
  }
  reject(
    export_spans([set(span(), "attributes", Json::string("PRIVATE_BAD"))]).stringify(),
    "attributes",
  )
  reject(
    export_spans([
      replace_attribute(span(), "gen_ai.response.model", { "intValue": "123" }),
    ]).stringify(),
    "stringValue",
  )
  reject(
    export_spans([set(span(), "status", { "code": "STATUS_CODE_ERROR" })]).stringify(),
    "status.code",
  )
  let duplicate = span()
  guard get(duplicate, "attributes") is Array(attrs) else { fail("fixture") }
  attrs.push(attribute("gen_ai.operation.name", { "stringValue": "chat" }))
  reject(export_spans([duplicate]).stringify(), "Duplicate attribute")
  reject(export_spans([span()]).stringify() + "\n{PRIVATE_BAD", "line 2")
}

///|
test "Empty export and zero-match filter keep unknown coverage without fabricated observations" {
  let named = match
    @otel_usage.import_otel_usage_json(
      export_spans([span()]).stringify(),
      source_name="saved-export.csv",
    ) {
    Ok(value) => value
    Err(error) => fail(error)
  }
  assert_eq(get(named, "sourceName"), Json::string("saved-export.csv"))
  assert_eq(get(named, "total"), Json::number(1))
  let result = imported("{\"resourceSpans\":[]}")
  assert_eq(get(result, "total"), Json::number(0))
  assert_eq(get(result, "partial"), Json::boolean(true))
  let normal = imported(export_spans([span()]).stringify())
  let filtered = match
    @usage_preview.moongate_preview_usage_file_json(
      normal.stringify(),
      app="missing",
    ) {
    Ok(v) => v
    Err(e) => fail(e)
  }
  assert_eq(get(filtered, "total"), Json::number(0))
  assert_eq(get(filtered, "sourceTotal"), Json::number(1))
  assert_eq(get(filtered, "partial"), Json::boolean(true))
}

///|
test "OTLP byte span count and expanded output limits bound each import" {
  reject(" ".repeat(4 * 1024 * 1024 + 1), "4 MiB")
  reject(
    export_spans(Array::make(10001, Json::object({}))).stringify(),
    "10,000 spans",
  )
  let huge = "x".repeat(1800000)
  let data = replace_attribute(span(), "gen_ai.response.model", {
    "stringValue": huge.to_json(),
  })
  reject(export_spans([data]).stringify(), "output exceeds")
}
