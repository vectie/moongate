///|
test "ccs deeplink parser accepts provider urls" {
  let url = "moonstat://v1/import?resource=provider&app=codex&name=OpenAI&endpoint=https%3A%2F%2Fapi.openai.com%2Fv1&apiKey=sk-test&enabled=true&usageAutoInterval=30"
  guard moon_parse_deeplink_url_json(url) is Some(Object(obj)) else {
    fail("expected provider deeplink request")
  }
  assert_eq(obj["version"], Json::string("v1"))
  assert_eq(obj["resource"], Json::string("provider"))
  assert_eq(obj["app"], Json::string("codex"))
  assert_eq(obj["name"], Json::string("OpenAI"))
  assert_eq(obj["endpoint"], Json::string("https://api.openai.com/v1"))
  assert_eq(obj["apiKey"], Json::string("sk-test"))
  assert_eq(obj["enabled"], Json::boolean(true))
  assert_eq(obj["usageAutoInterval"], Json::number(30.0))
}

///|
test "ccs deeplink parser decodes prompts and validates resources" {
  let prompt_url = "moonstat://v1/import?resource=prompt&app=codex&name=Daily&content=SGVsbG8&enabled=false"
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
test "ccs deeplink parser accepts mcp and skill requests" {
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
  assert_eq(skill["app"], Json::string("claude"))
  assert_eq(skill["branch"], Json::string("main"))
}

///|
test "ccs deeplink merge imports claude env config fields" {
  let encoded = "eyJlbnYiOnsiQU5USFJPUElDX0FVVEhfVE9LRU4iOiJzay1jY3MiLCJBTlRIUk9QSUNfQkFTRV9VUkwiOiJodHRwczovL2FwaS5hbnRocm9waWMuY29tL3YxLyIsIkFOVEhST1BJQ19NT0RFTCI6ImNsYXVkZS1zb25uZXQifX0="
  let request = {
    "resource": Json::string("provider"),
    "app": Json::string("claude"),
    "name": Json::string("Anthropic"),
    "config": Json::string(encoded),
    "configFormat": Json::string("json"),
  }.to_json()
  guard moon_merge_deeplink_config_json(request) is Some(Object(merged)) else {
    fail("expected merged provider deeplink")
  }
  assert_eq(merged["apiKey"], Json::string("sk-ccs"))
  assert_eq(merged["endpoint"], Json::string("https://api.anthropic.com/v1/"))
  assert_eq(merged["model"], Json::string("claude-sonnet"))
  assert_eq(merged["homepage"], Json::string("https://anthropic.com"))
}
