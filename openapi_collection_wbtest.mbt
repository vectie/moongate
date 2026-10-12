///|
test "OpenAPI operations preserve examples and parameter overrides" {
  let source =
    #|{"openapi":"3.1.0","info":{"title":"Models"},"servers":[{"url":"https://example.invalid/v1"}],"paths":{"/models/{id}":{"parameters":[{"name":"id","in":"path","example":"old"}],"get":{"operationId":"model","tags":["Models"],"parameters":[{"name":"id","in":"path","example":"new"},{"name":"limit","in":"query","schema":{"default":0}}]}}}}
  let result = moongate_openapi_collection_json(source).unwrap()
  assert_eq(gate_oas_field(result, "sourceOperations"), Json::number(1))
  let ops = gate_oas_array(gate_oas_field(result, "operations"))
  let params = gate_oas_array(gate_oas_field(ops[0], "parameters"))
  assert_eq(params.length(), 2)
  assert_eq(gate_oas_field(params[0], "example"), Json::string("new"))
  assert_eq(gate_oas_field(params[1], "example"), Json::number(0))
  assert_true(
    gate_oas_text(result, "http").contains(
      "GET {{baseUrl}}/models/{{path_id}}?limit={{query_limit}}",
    ),
  )
  assert_eq(
    gate_oas_field(
      moongate_openapi_collection_json(source, tag="Other").unwrap(),
      "selectedOperations",
    ),
    Json::number(0),
  )
  assert_eq(
    gate_oas_field(
      moongate_openapi_collection_json(source, operation="model").unwrap(),
      "selectedOperations",
    ),
    Json::number(1),
  )
}

///|
test "OpenAPI local references body examples and scoped server security" {
  let source =
    #|{"openapi":"3.0.3","security":[{"bearer":[]}],"servers":[{"url":"root"}],"paths":{"/chat":{"servers":[{"url":"path"}],"post":{"operationId":"chat","servers":[{"url":"operation"}],"security":[],"requestBody":{"$ref":"#/components/requestBodies/A~1B"}}}},"components":{"requestBodies":{"A/B":{"content":{"application/json":{"examples":{"one":{"$ref":"#/components/examples/Chat"}}}}}},"examples":{"Chat":{"value":{"model":"small","stream":false}}}}}
  let result = moongate_openapi_collection_json(source).unwrap()
  let op = gate_oas_array(gate_oas_field(result, "operations"))[0]
  assert_eq(gate_oas_text(op, "server"), "operation")
  assert_eq(
    gate_oas_field(gate_oas_field(op, "bodyExample"), "stream"),
    Json::boolean(false),
  )
  assert_eq(gate_oas_array(gate_oas_field(op, "warnings")).length(), 0)
  assert_true(
    gate_oas_text(result, "http").contains("Content-Type: application/json"),
  )
  assert_true(gate_oas_text(result, "http").contains("\"model\": \"small\""))
}

///|
test "OpenAPI unsupported inputs and reference cycles explain the blocker" {
  assert_true(moongate_openapi_collection_json("openapi: 3.1.0") is Err(_))
  assert_true(
    moongate_openapi_collection_json("{\"swagger\":\"2.0\",\"paths\":{}}")
    is Err(_),
  )
  assert_true(
    moongate_openapi_collection_json(
      "{\"openapi\":\"3.1.0\",\"paths\":{\"/x\":{\"$ref\":\"https://example.invalid/spec\"}}}",
    )
    is Err(_),
  )
  assert_true(
    moongate_openapi_collection_json(
      "{\"openapi\":\"3.1.0\",\"paths\":{\"/x\":{\"$ref\":\"#/paths/~1x\"}}}",
    )
    is Err(_),
  )
  assert_true(
    moongate_openapi_collection_json(
      "{\"openapi\":\"3.1.0\",\"paths\":{\"/x\":{\"$ref\":\"#/missing\"}}}",
    )
    is Err(_),
  )
}

///|
test "OpenAPI auth parameter examples are not exported and missing bodies are explicit" {
  let source =
    #|{"openapi":"3.1.0","security":[{"key":[]}],"paths":{"/x":{"post":{"parameters":[{"name":"Authorization","in":"header","example":"planted-secret"}],"requestBody":{"content":{"application/json":{"schema":{"type":"object"}}}}}}}}
  let result = moongate_openapi_collection_json(source).unwrap()
  assert_true(!result.stringify().contains("planted-secret"))
  let http = gate_oas_text(result, "http")
  assert_true(http.contains("Authentication is declared"))
  assert_true(http.contains("No JSON body example"))
  assert_true(http.contains("Authorization: {{header_Authorization}}"))
}
///|
test "OpenAPI explicit null body is a supplied example" {
  let source =
    #|{"openapi":"3.1.0","paths":{"/reset":{"post":{"requestBody":{"content":{"application/json":{"example":null}}}}}}}
  let result = moongate_openapi_collection_json(source).unwrap()
  let http = gate_oas_text(result, "http")
  assert_true(http.contains("\n\nnull\n"))
  assert_true(!http.contains("No JSON body example"))
}

