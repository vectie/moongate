///|
test "moonstat deeplink parser accepts provider urls" {
  let url = "moonstat://v1/import?resource=provider&appType=codex&name=OpenAI&endpoint=https%3A%2F%2Fapi.openai.com%2Fv1&apiKey=sk-test&enabled=true&usageAutoInterval=30"
  guard moon_parse_deeplink_url_json(url) is Some(Object(obj)) else {
    fail("expected provider deeplink request")
  }
  assert_eq(obj["version"], Json::string("v1"))
  assert_eq(obj["resource"], Json::string("provider"))
  assert_eq(obj["appType"], Json::string("codex"))
  assert_eq(obj["name"], Json::string("OpenAI"))
  assert_eq(obj["endpoint"], Json::string("https://api.openai.com/v1"))
  assert_eq(obj["apiKey"], Json::string("sk-test"))
  assert_eq(obj["enabled"], Json::boolean(true))
  assert_eq(obj["usageAutoInterval"], Json::number(30.0))
}

///|
test "moonstat deeplink parser decodes prompts and validates resources" {
  let prompt_url = "moonstat://v1/import?resource=prompt&appType=codex&name=Daily&content=SGVsbG8&enabled=false"
  guard moon_parse_deeplink_url_json(prompt_url) is Some(Object(prompt)) else {
    fail("expected prompt deeplink request")
  }
  assert_eq(prompt["resource"], Json::string("prompt"))
  assert_eq(prompt["content"], Json::string("SGVsbG8"))
  assert_eq(prompt["enabled"], Json::boolean(false))
  assert_eq(moon_deeplink_decode_utf8("SGVsbG8"), Some("Hello"))
  assert_eq(moon_parse_deeplink_url_json("https://example.com"), None)
  assert_eq(
    moon_parse_deeplink_url_json(
      "moonstat://v1/import?resource=skill&repo=missing-owner",
    ),
    None,
  )
}

///|
test "moonstat deeplink parser accepts mcp and skill requests" {
  let mcp_url = "moonstat://v1/import?resource=mcp&apps=claude,codex&config=eyJtY3BTZXJ2ZXJzIjp7fX0"
  guard moon_parse_deeplink_url_json(mcp_url) is Some(Object(mcp)) else {
    fail("expected mcp deeplink request")
  }
  assert_eq(mcp["resource"], Json::string("mcp"))
  assert_eq(mcp["apps"], Json::string("claude,codex"))
  assert_eq(mcp["configFormat"], Json::string("json"))
  let skill_url = "moonstat://v1/import?resource=skill&repo=vectie%2Fskills&branch=main&enabled=true"
  guard moon_parse_deeplink_url_json(skill_url) is Some(Object(skill)) else {
    fail("expected skill deeplink request")
  }
  assert_eq(skill["resource"], Json::string("skill"))
  assert_eq(skill["repo"], Json::string("vectie/skills"))
  assert_eq(skill["appType"], Json::string("claude"))
  assert_eq(skill["branch"], Json::string("main"))
}

///|
test "moonstat deeplink merge imports claude env config fields" {
  let encoded = "eyJlbnYiOnsiQU5USFJPUElDX0FVVEhfVE9LRU4iOiJzay1tb29uc3RhdCIsIkFOVEhST1BJQ19CQVNFX1VSTCI6Imh0dHBzOi8vYXBpLmFudGhyb3BpYy5jb20vdjEvIiwiQU5USFJPUElDX01PREVMIjoiY2xhdWRlLXNvbm5ldCJ9fQ=="
  let request = {
    "resource": Json::string("provider"),
    "appType": Json::string("claude"),
    "name": Json::string("Anthropic"),
    "config": Json::string(encoded),
    "configFormat": Json::string("json"),
  }.to_json()
  guard moon_merge_deeplink_config_json(request) is Some(Object(merged)) else {
    fail("expected merged provider deeplink")
  }
  assert_eq(merged["apiKey"], Json::string("sk-moonstat"))
  assert_eq(merged["endpoint"], Json::string("https://api.anthropic.com/v1/"))
  assert_eq(merged["model"], Json::string("claude-sonnet"))
  assert_eq(merged["homepage"], Json::string("https://anthropic.com"))
}

///|
test "moonstat deeplink merge ignores legacy provider config keys" {
  let encoded = "eyJhcGlfa2V5Ijoic2stbGVnYWN5IiwiYmFzZV91cmwiOiJodHRwczovL2xlZ2FjeS5leGFtcGxlL3YxIiwiYXBpS2V5Ijoic2stbmV3IiwiYmFzZVVybCI6Imh0dHBzOi8vbmV3LmV4YW1wbGUvdjEifQ=="
  guard moon_merge_deeplink_config_json(
      {
        "resource": Json::string("provider"),
        "appType": Json::string("openclaw"),
        "name": Json::string("OpenClaw"),
        "config": Json::string(encoded),
        "configFormat": Json::string("json"),
      }.to_json(),
    )
    is Some(Object(merged)) else {
    fail("expected merged openclaw config")
  }
  assert_eq(merged["apiKey"], Json::string("sk-new"))
  assert_eq(merged["endpoint"], Json::string("https://new.example/v1"))
  guard moon_merge_deeplink_config_json(
      {
        "resource": Json::string("provider"),
        "appType": Json::string("openclaw"),
        "name": Json::string("OpenClaw"),
        "config": Json::string(encoded),
        "config_format": Json::string("toml"),
      }.to_json(),
    )
    is Some(Object(legacy_format_ignored)) else {
    fail("expected legacy config_format to be ignored")
  }
  assert_eq(
    legacy_format_ignored["endpoint"],
    Json::string("https://new.example/v1"),
  )
  assert_true(
    ConfigService::new().moon_import_provider_deeplink(
      ProxyService::new("127.0.0.1", 0),
      {
        "appType": Json::string("openclaw"),
        "name": Json::string("Legacy"),
        "endpoint": Json::string("https://legacy.example/v1"),
        "api_key": Json::string("sk-legacy"),
      },
    )
    is None,
  )
}
