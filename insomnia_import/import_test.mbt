///|
fn field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => Json::null()
  }
}

///|
fn fixture(items : Array[Json]) -> String {
  let root : Json = {
    "_type": "export",
    "__export_format": 4,
    "__export_date": "2026-10-13T00:00:00Z",
    "__export_source": "synthetic-v4",
    "resources": Json(items),
  }
  root.stringify()
}

///|
fn workspace() -> Json {
  {
    "_id": "wrk_one",
    "_type": "workspace",
    "parentId": Json::null(),
    "name": "Example",
  }
}

///|
fn request(extra~ : Json = Json::null()) -> Json {
  let value : Map[String, Json] = {
    "_id": "req_one",
    "_type": "request",
    "parentId": "wrk_one",
    "name": "List",
    "method": "GET",
    "url": "https://example.invalid/models",
    "headers": [],
  }
  if extra is Object(fields) {
    for key, entry in fields {
      value[key] = entry
    }
  }
  Json::object(value)
}

///|
fn rejects(source : String) -> Unit raise {
  try @insomnia_import.import_collection(source) catch {
    _ => ()
  } noraise {
    _ => fail("Unexpected accepted export")
  }
}

///|
fn http(value : Json) -> String {
  match field(value, "http") {
    String(text) => text
    _ => ""
  }
}

///|
test "Insomnia export format preserves exact decimal integer semantics" {
  let source = fixture([workspace(), request()])
  for
    token in [
      "4.000000000000000001", "3.999999999999999999", "4.000000000000000001e0", "1e-9999",
      "4e9999",
    ] {
    let input = source.replace(
      old="\"__export_format\":4",
      new="\"__export_format\":" + token,
    )
    assert_true(input != source)
    rejects(input)
  }
  let expected = @insomnia_import.import_collection(source).stringify()
  for token in ["4.0", "40e-1", "0.4e1", "4000000000000000000000e-21"] {
    let input = source.replace(
      old="\"__export_format\":4",
      new="\"__export_format\":" + token,
    )
    let result = @insomnia_import.import_collection(input)
    assert_eq(field(result, "http"), field(@json.parse(expected), "http"))
  }
}

///|
test "Insomnia duplicate decoded keys cannot replace version or identity" {
  let source = fixture([workspace(), request()])
  for
    input in [
      source.replace(
        old="\"__export_format\":4",
        new="\"__export_format\":5,\"__export_format\":4",
      ),
      source.replace(
        old="\"_id\":\"req_one\"",
        new="\"_id\":\"wrong_request\",\"_id\":\"req_one\"",
      ),
      source.replace(
        old="\"_id\":\"req_one\"",
        new="\"_id\":\"wrong_request\",\"_\\u0069d\":\"req_one\"",
      ),
      source.replace(
        old="\"method\":\"GET\"",
        new="\"method\":\"POST\",\"method\":\"GET\"",
      ),
    ] {
    assert_true(input != source)
    rejects(input)
  }
}

///|
test "imports out-of-order resources with stable provenance and nested ID selectors" {
  let source = fixture([
    request(extra={ "parentId": "fld_child" }),
    {
      "_id": "fld_child",
      "_type": "request_group",
      "parentId": "fld_root",
      "name": "Child",
    },
    workspace(),
    {
      "_id": "fld_root",
      "_type": "request_group",
      "parentId": "wrk_one",
      "name": "Folder",
    },
    request(extra={ "_id": "req_two", "name": "Other", "method": "POST" }),
  ])
  let result = @insomnia_import.import_collection(
    source,
    workspace_id="wrk_one",
    folder_id="fld_root",
    request_id="req_one",
  )
  assert_eq(field(result, "selectedRequests"), Json::number(1))
  assert_eq(field(result, "sourceRequests"), Json::number(2))
  assert_true(http(result).contains("### Example/Folder/Child/List"))
  assert_true(http(result).contains("Source resource req_one (index 1)"))
  assert_eq(field(result, "sourceExportTool"), Json::string("synthetic-v4"))
  assert_true(result.stringify().contains("folderIds"))
  assert_eq(
    @insomnia_import.import_collection(source),
    @insomnia_import.import_collection(source),
  )
}

///|
test "duplicate folder names remain unambiguous using exact IDs" {
  let source = fixture([
    workspace(),
    {
      "_id": "fld_a",
      "_type": "request_group",
      "parentId": "wrk_one",
      "name": "Same",
    },
    {
      "_id": "fld_b",
      "_type": "request_group",
      "parentId": "wrk_one",
      "name": "Same",
    },
    request(extra={ "parentId": "fld_a" }),
    request(extra={ "_id": "req_two", "parentId": "fld_b", "name": "Second" }),
  ])
  let result = @insomnia_import.import_collection(source, folder_id="fld_b")
  assert_eq(field(result, "selectedRequests"), Json::number(1))
  assert_true(http(result).contains("### Example/Same/Second"))
  assert_true(!http(result).contains("### Example/Same/List"))
}

///|
test "literal raw query and structured parameters preserve order duplicates and Unicode" {
  let result = @insomnia_import.import_collection(
    fixture([
      workspace(),
      request(extra={
        "url": "https://example.invalid/search?tag=first&tag=second&api_key=SECRET#fragment",
        "parameters": [
          { "name": "tag", "value": "a b&c" },
          { "name": "tag", "value": "猫" },
          { "name": "off", "value": "SECRET", "disabled": true },
          { "name": "password", "value": "SECRET" },
        ],
      }),
    ]),
  )
  assert_true(
    http(result).contains(
      "?tag=first&tag=second&api_key=REPLACE_ME&tag=a%20b%26c&tag=%E7%8C%AB&password=REPLACE_ME",
    ),
  )
  assert_true(!result.stringify().contains("SECRET"))
  assert_true(http(result).contains("URL fragment omitted"))
}

///|
test "retains literal body and duplicate headers while withholding known credentials" {
  let result = @insomnia_import.import_collection(
    fixture([
      workspace(),
      request(extra={
        "method": "POST",
        "headers": [
          { "name": "X-Tag", "value": "one" },
          { "name": "X-Tag", "value": "two" },
          { "name": "Authorization", "value": "Bearer SECRET" },
          { "name": "Cookie", "value": "SECRET" },
          { "name": "Content-Length", "value": "900" },
          { "name": "X-Disabled", "value": "SECRET", "disabled": true },
        ],
        "body": {
          "mimeType": "application/json",
          "text": "{\n  \"model\": \"small\"\n}",
        },
      }),
    ]),
  )
  let output = http(result)
  assert_true(output.contains("X-Tag: one\nX-Tag: two"))
  assert_true(output.contains("Authorization: {{ins_2_header_2}}"))
  assert_true(output.contains("@ins_2_header_2 = REPLACE_ME"))
  assert_true(output.contains("Content-Type: application/json"))
  assert_true(output.contains("{\n  \"model\": \"small\"\n}"))
  assert_true(!result.stringify().contains("SECRET"))
}

///|
test "templates environments scripts cookie jars and auth are explicit omissions" {
  let result = @insomnia_import.import_collection(
    fixture([
      workspace(),
      request(extra={
        "url": "{{ _.base_url }}/models",
        "authentication": { "type": "bearer", "token": "SECRET" },
        "preRequestScript": "SECRET",
        "afterResponseScript": "SECRET",
        "body": { "text": "{{ _.secret }}" },
        "headers": [{ "name": "X-Value", "value": "{% custom SECRET %}" }],
      }),
      {
        "_id": "env_one",
        "_type": "environment",
        "data": { "secret": "SECRET" },
      },
      { "_id": "jar_one", "_type": "cookie_jar", "cookies": ["SECRET"] },
      { "_id": "res_one", "_type": "response", "body": "SECRET" },
      { "_id": "grpc_one", "_type": "grpc_request", "url": "SECRET" },
    ]),
  )
  assert_true(!result.stringify().contains("SECRET"))
  assert_true(http(result).contains("https://REPLACE_ME.invalid/"))
  assert_true(http(result).contains("Authentication helper omitted"))
  assert_true(http(result).contains("preRequestScript omitted"))
  assert_eq(
    field(field(result, "omittedResourceTypes"), "environment"),
    Json::number(1),
  )
  assert_eq(
    field(field(result, "omittedResourceTypes"), "grpc_request"),
    Json::number(1),
  )
}

///|
test "bodies never introduce HTTP client runtime directives" {
  for
    body in [
      "### Evil\nGET https://evil.invalid", "\r> {% evil %}", "hello\r< /tmp/file",
      "\n@token = evil", "\n# @name hook", "< /tmp/file", "{{dynamic}}", "{% script %}",
      "x\u{0}y",
    ] {
    let result = @insomnia_import.import_collection(
      fixture([
        workspace(),
        request(extra={ "body": { "mimeType": "text/plain", "text": body } }),
      ]),
    )
    assert_true(
      http(result).contains(
        "Body with templates, control bytes or HTTP-client directive-like lines omitted",
      ),
    )
    guard field(result, "requests") is Array(requests) else {
      fail("Missing requests")
    }
    assert_eq(field(requests[0], "body"), Json::string(""))
  }
}

///|
test "file and form bodies stay omitted without opening files" {
  let bodies : Array[Json] = [
    { "fileName": "/unreadable/SECRET", "mimeType": "application/octet-stream" },
    { "mimeType": "multipart/form-data", "text": "SECRET" },
    {
      "mimeType": "application/x-www-form-urlencoded",
      "params": [{ "name": "x", "value": "SECRET" }],
    },
  ]
  for body in bodies {
    let result = @insomnia_import.import_collection(
      fixture([workspace(), request(extra={ "body": body })]),
    )
    assert_true(!result.stringify().contains("SECRET"))
    assert_true(http(result).contains("No file was read"))
  }
}

///|
test "graph validation rejects duplicates orphans cycles and wrong parent types" {
  for
    items in [
      [workspace(), request(), request()],
      [workspace(), request(extra={ "parentId": "absent" })],
      [
        workspace(),
        {
          "_id": "fld_one",
          "_type": "request_group",
          "parentId": "fld_one",
          "name": "Loop",
        },
      ],
      [
        workspace(),
        request(),
        request(extra={ "_id": "req_two", "parentId": "req_one" }),
      ],
      [workspace(), request(extra={ "_id": "bad\nID" })],
      [workspace(), request(extra={ "name": "bad\nname" })],
    ] {
    rejects(fixture(items))
  }
}

///|
test "rejects malformed fields and non HTTP literal requests" {
  let extras : Array[Json] = [
    { "url": "file:///tmp/secret" },
    { "url": "https:///path" },
    { "url": "https://user:secret@example.invalid/" },
    { "url": "https://example.invalid/a b" },
    { "method": "CONNECT" },
    { "headers": "X: Y" },
    { "headers": [{ "name": "Bad Header", "value": "x" }] },
    { "headers": [{ "name": "X", "value": "a\r\nInjection: yes" }] },
    { "headers": [{ "name": "X", "value": 42 }] },
    { "parameters": [{ "name": "x", "disabled": "true" }] },
    { "body": "raw unsupported" },
    { "body": { "text": 42 } },
    { "body": { "mimeType": "text/plain\nX: Y", "text": "x" } },
  ]
  for extra in extras {
    rejects(fixture([workspace(), request(extra~)]))
  }
}

///|
test "rejects unknown selectors and empty intersections" {
  let source = fixture([
    workspace(),
    request(),
    {
      "_id": "fld_empty",
      "_type": "request_group",
      "parentId": "wrk_one",
      "name": "Empty",
    },
  ])
  for id in ["absent", "req_one", "fld_empty"] {
    try @insomnia_import.import_collection(source, workspace_id=id) catch {
      _ => ()
    } noraise {
      _ => fail("Unknown workspace accepted")
    }
  }
  try
    @insomnia_import.import_collection(
      source,
      folder_id="fld_empty",
      request_id="req_one",
    )
  catch {
    _ => ()
  } noraise {
    _ => fail("Empty intersection accepted")
  }
}

///|
test "bounded document resources and folder depth" {
  rejects("x".repeat(4 * 1024 * 1024 + 1))
  rejects("{\"__export_format\":5,\"resources\":[]}")
  rejects("{}")
  rejects("not JSON")
  let items : Array[Json] = [workspace()]
  for i in 0..<2000 {
    items.push({ "_id": Json("env_" + i.to_string()), "_type": "environment" })
  }
  rejects(fixture(items))
  let nested : Array[Json] = [workspace()]
  let mut parent = "wrk_one"
  for i in 0..<33 {
    let id = "fld_" + i.to_string()
    nested.push({
      "_id": Json(id),
      "_type": "request_group",
      "parentId": Json(parent),
      "name": "Folder",
    })
    parent = id
  }
  nested.push(request(extra={ "parentId": Json(parent) }))
  rejects(fixture(nested))
}

///|
test "empty valid export has explicit zero selection and no readiness claim" {
  let result = @insomnia_import.import_collection(fixture([workspace()]))
  assert_eq(field(result, "selectedRequests"), Json::number(0))
  assert_true(
    result.stringify().contains("Caller retains original export unchanged"),
  )
  assert_true(!result.stringify().contains("providerReady"))
}

///|
test "workspace selection does not mix identically named collections" {
  let source = fixture([
    workspace(),
    request(),
    {
      "_id": "wrk_two",
      "_type": "workspace",
      "parentId": Json::null(),
      "name": "Example",
    },
    request(extra={ "_id": "req_two", "parentId": "wrk_two", "name": "Second" }),
  ])
  let result = @insomnia_import.import_collection(
    source,
    workspace_id="wrk_two",
  )
  assert_eq(field(result, "selectedRequests"), Json::number(1))
  assert_true(http(result).contains("Source resource req_two"))
  assert_true(!http(result).contains("Source resource req_one"))
}

///|
test "32 folder boundary accepts and 33 empty folders reject" {
  let nested : Array[Json] = [workspace()]
  let mut parent = "wrk_one"
  for i in 0..<32 {
    let id = "fld_" + i.to_string()
    nested.push({
      "_id": Json(id),
      "_type": "request_group",
      "parentId": Json(parent),
      "name": "Folder",
    })
    parent = id
  }
  let with_request = nested.copy()
  with_request.push(request(extra={ "parentId": Json(parent) }))
  assert_eq(
    field(
      @insomnia_import.import_collection(fixture(with_request)),
      "selectedRequests",
    ),
    Json::number(1),
  )
  nested.push({
    "_id": "fld_33",
    "_type": "request_group",
    "parentId": Json(parent),
    "name": "Too deep",
  })
  rejects(fixture(nested))
}

///|
test "disabled body existing MIME and encoded raw credentials retain explicit meaning" {
  let result = @insomnia_import.import_collection(
    fixture([
      workspace(),
      request(extra={
        "url": "https://example.invalid/?%74oken=SECRET&tag=%E7%8C%AB",
        "headers": [{ "name": "Content-Type", "value": "text/plain" }],
        "body": {
          "mimeType": "application/json",
          "text": "SECRET",
          "disabled": true,
        },
      }),
    ]),
  )
  assert_true(!result.stringify().contains("SECRET"))
  assert_true(http(result).contains("%74oken=REPLACE_ME&tag=%E7%8C%AB"))
  assert_true(http(result).contains("Content-Type: text/plain"))
  assert_true(!http(result).contains("Content-Type: application/json"))
}

///|
test "derived output bound prevents repeated long labels from expanding without limit" {
  let items : Array[Json] = [
    workspace(),
    {
      "_id": "fld_long",
      "_type": "request_group",
      "parentId": "wrk_one",
      "name": Json("x".repeat(65536)),
    },
  ]
  for i in 0..<60 {
    items.push(
      request(extra={
        "_id": Json("req_" + i.to_string()),
        "parentId": "fld_long",
      }),
    )
  }
  rejects(fixture(items))
}
