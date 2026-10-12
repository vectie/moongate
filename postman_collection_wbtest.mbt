///|
fn postman_test_source(
  items : Array[Json],
  extra? : Json = Json::null(),
) -> String {
  let source : Map[String, Json] = {
    "info": {
      "name": "Synthetic Model API",
      "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
    },
    "item": items.to_json(),
  }
  if extra is Object(fields) {
    for key, value in fields {
      source[key] = value
    }
  }
  Json::object(source).stringify()
}

///|
test "Postman folders filters preserve order and isolate scoped variables" {
  let source = postman_test_source(
    [
      {
        "name": "Models",
        "variable": [{ "key": "base", "value": "https://models.invalid" }],
        "item": [
          {
            "name": "List",
            "request": { "method": "GET", "url": "{{base}}/models" },
          },
          {
            "name": "Chat",
            "item": [
              {
                "name": "Create",
                "request": {
                  "method": "POST",
                  "url": "{{base}}/chat",
                  "body": {
                    "mode": "raw",
                    "raw": "{\"model\":\"{{model}}\",\"stream\":false}",
                    "options": { "raw": { "language": "json" } },
                  },
                },
              },
            ],
          },
        ],
      },
      {
        "name": "ModelsOther",
        "item": [
          {
            "name": "Other",
            "request": { "method": "GET", "url": "{{base}}/models" },
          },
        ],
      },
    ],
    extra={
      "variable": [
        { "key": "base", "value": "https://root.invalid" },
        { "key": "model", "value": "small" },
      ],
    },
  )
  let all = moongate_postman_collection_json(source).unwrap()
  assert_eq(gate_oas_field(all, "sourceRequests"), Json::number(3))
  let requests = gate_oas_array(gate_oas_field(all, "requests"))
  assert_eq(gate_oas_text(requests[1], "folder"), "Models/Chat")
  let http = gate_oas_text(all, "http")
  assert_true(http.contains("@pm_1_v1 = https://models.invalid"))
  assert_true(http.contains("@pm_3_v1 = https://root.invalid"))
  assert_true(http.contains("Content-Type: application/json"))
  assert_true(http.contains("\"model\":\"{{pm_2_v2}}\""))
  let filtered = moongate_postman_collection_json(
    source,
    folder="Models",
    request_method="post",
  ).unwrap()
  assert_eq(gate_oas_field(filtered, "selectedRequests"), Json::number(1))
  assert_true(
    gate_oas_text(filtered, "http").contains("### Models/Chat/Create"),
  )
  assert_true(!gate_oas_text(filtered, "http").contains("### ModelsOther"))
  assert_eq(
    gate_oas_field(
      moongate_postman_collection_json(source, folder="Absent").unwrap(),
      "selectedRequests",
    ),
    Json::number(0),
  )
}

///|
test "Postman structured query omits disabled fields and encodes repeated values" {
  let source = postman_test_source(
    [
      {
        "name": "Search",
        "request": {
          "method": "GET",
          "url": {
            "raw": "https://example.invalid/search?stale=yes#fragment",
            "query": [
              { "key": "tag", "value": "a b" },
              { "key": "tag", "value": "c&d" },
              { "key": "skip", "value": "DISABLED_SECRET", "disabled": true },
              { "key": "api_key", "value": "QUERY_SECRET" },
              { "key": "page", "value": "{{page}}" },
            ],
          },
        },
      },
    ],
    extra={ "variable": [{ "key": "page", "value": 2 }] },
  )
  let result = moongate_postman_collection_json(source).unwrap()
  assert_true(
    gate_oas_text(result, "http").contains(
      "?tag=a%20b&tag=c%26d&api_key=REPLACE_ME&page={{pm_1_v1}}",
    ),
  )
  assert_true(!result.stringify().contains("SECRET"))
  assert_true(!result.stringify().contains("stale=yes"))
  assert_true(gate_oas_text(result, "http").contains("@pm_1_v1 = 2"))
}

///|
test "Postman authentication inheritance noauth headers and script omission" {
  let source = postman_test_source(
    [
      {
        "name": "Inherited",
        "request": {
          "method": "GET",
          "url": "https://example.invalid/",
          "header": [
            { "key": "X-Tag", "value": "one" },
            { "key": "X-Tag", "value": "two" },
            { "key": "X-Skip", "value": "DISABLED_SECRET", "disabled": true },
          ],
        },
      },
      {
        "name": "Public",
        "request": {
          "method": "GET",
          "url": "https://example.invalid/",
          "auth": { "type": "noauth" },
        },
      },
      {
        "name": "Header",
        "request": {
          "method": "GET",
          "url": "https://example.invalid/",
          "header": [
            { "key": "Authorization", "value": "Bearer HEADER_SECRET" },
            { "key": "Cookie", "value": "COOKIE_SECRET" },
          ],
        },
      },
    ],
    extra={
      "auth": {
        "type": "bearer",
        "bearer": [{ "key": "token", "value": "AUTH_SECRET" }],
      },
      "event": [
        { "listen": "prerequest", "script": { "exec": ["SCRIPT_SECRET"] } },
      ],
    },
  )
  let result = moongate_postman_collection_json(source).unwrap()
  assert_true(!result.stringify().contains("SECRET"))
  let requests = gate_oas_array(gate_oas_field(result, "requests"))
  assert_eq(gate_oas_array(gate_oas_field(requests[1], "headers")).length(), 0)
  let http = gate_oas_text(result, "http")
  assert_true(http.contains("X-Tag: one\nX-Tag: two"))
  assert_true(http.contains("Authorization: Bearer {{pm_1_bearer}}"))
  assert_true(http.contains("Authorization: {{pm_3_auth0}}"))
  assert_true(!http.contains("pm_3_bearer"))
  assert_true(http.contains("scripts/tests were omitted"))
}

///|
test "Postman missing dynamic and sensitive variables remain explicit edits" {
  let source = postman_test_source(
    [
      {
        "name": "Variables",
        "request": {
          "method": "POST",
          "url": "{{base}}/chat",
          "body": {
            "mode": "raw",
            "raw": "{{token}} {{missing}} {{$guid}} {{nested}} {{base}}",
          },
        },
      },
    ],
    extra={
      "variable": [
        { "key": "base", "value": "https://example.invalid" },
        { "key": "token", "value": "TOKEN_SECRET" },
        { "key": "nested", "value": "{{base}}/nested" },
      ],
    },
  )
  let result = moongate_postman_collection_json(source).unwrap()
  let http = gate_oas_text(result, "http")
  assert_true(!result.stringify().contains("TOKEN_SECRET"))
  assert_true(http.contains("@pm_1_v2 = REPLACE_ME"))
  assert_true(http.contains("@pm_1_v3 = REPLACE_ME"))
  assert_true(http.contains("@pm_1_v4 = REPLACE_ME"))
  assert_true(http.contains("@pm_1_v5 = REPLACE_ME"))
  assert_true(
    http.contains("{{pm_1_v2}} {{pm_1_v3}} {{pm_1_v4}} {{pm_1_v5}} {{pm_1_v1}}"),
  )
}

///|
test "Postman unsupported bodies are visible and saved responses stay omitted" {
  let source = postman_test_source([
    {
      "name": "Form",
      "response": [{ "body": "RESPONSE_SECRET" }],
      "request": {
        "method": "POST",
        "url": "https://example.invalid/",
        "body": {
          "mode": "formdata",
          "formdata": [{ "key": "file", "src": "FILE_SECRET" }],
        },
      },
    },
    {
      "name": "Disabled",
      "request": {
        "method": "POST",
        "url": "https://example.invalid/",
        "body": { "mode": "raw", "raw": "BODY_SECRET", "disabled": true },
      },
    },
    { "name": "Shortcut", "request": "https://example.invalid/models" },
  ])
  let result = moongate_postman_collection_json(source).unwrap()
  assert_true(!result.stringify().contains("SECRET"))
  assert_true(
    gate_oas_text(result, "http").contains("Body mode formdata omitted"),
  )
  assert_eq(gate_oas_field(result, "selectedRequests"), Json::number(3))
}

///|
test "Postman rejects malformed inputs and ambiguous folder names" {
  for
    source in [
      "not json",
      "{}",
      postman_test_source([{ "name": "A/B", "item": [] }]),
      postman_test_source([
        {
          "name": "Bad",
          "request": { "method": "GET", "url": "file:///tmp/x" },
        },
      ]),
      postman_test_source([
        {
          "name": "Bad",
          "request": { "method": "GET", "url": "https://u:p@example.invalid/" },
        },
      ]),
      postman_test_source([
        {
          "name": "Bad",
          "request": {
            "method": "GET",
            "url": "https://example.invalid/",
            "header": [{ "key": "X", "value": "a\r\nInjection: true" }],
          },
        },
      ]),
    ] {
    assert_true(moongate_postman_collection_json(source) is Err(_))
  }
  assert_true(
    moongate_postman_collection_json(
      postman_test_source([]),
      request_method="WRONG",
    )
    is Err(_),
  )
}

///|
test "Postman bounded document item count and nested folders" {
  let items : Array[Json] = []
  for _ in 0..<2001 {
    items.push({ "name": "Empty", "item": [] })
  }
  assert_true(
    moongate_postman_collection_json(postman_test_source(items)) is Err(_),
  )
  let mut nested : Json = { "name": "Leaf", "item": [] }
  for _ in 0..<33 {
    nested = { "name": "Folder", "item": [nested] }
  }
  assert_true(
    moongate_postman_collection_json(postman_test_source([nested])) is Err(_),
  )
  assert_true(
    moongate_postman_collection_json("a".repeat(4 * 1024 * 1024 + 1)) is Err(_),
  )
}

///|
test "Postman URL path variables and folder auth override are editable" {
  let source = postman_test_source(
    [
      {
        "name": "Models",
        "auth": { "type": "noauth" },
        "item": [
          {
            "name": "One",
            "request": {
              "method": "GET",
              "url": {
                "raw": "https://example.invalid/models/:id",
                "variable": [{ "key": "id", "value": "small" }],
              },
            },
          },
        ],
      },
    ],
    extra={
      "auth": {
        "type": "bearer",
        "bearer": [{ "key": "token", "value": "ROOT_SECRET" }],
      },
    },
  )
  let result = moongate_postman_collection_json(source).unwrap()
  let http = gate_oas_text(result, "http")
  assert_true(http.contains("@pm_1_v1 = small"))
  assert_true(http.contains("GET https://example.invalid/models/{{pm_1_v1}}"))
  assert_true(!http.contains("Authorization:"))
  assert_true(!result.stringify().contains("ROOT_SECRET"))
}
