///|
test "moonstat omo local file data parses jsonc and preserves other fields" {
  let content =
    #|{
    #|  // OMO agents
    #|  "agents": {"dev": {"model": "gpt-5"}},
    #|  "categories": ["coding"],
    #|  "theme": "dark",
    #|  "url": "https://example.com//not-comment"
    #|}
  guard moon_omo_local_file_data_json_from_content(
      false,
      "/tmp/oh-my-openagent.jsonc",
      Json::string("2026-06-14T00:00:00+00:00"),
      content,
    )
    is Some(Object(obj)) else {
    fail("expected omo local file data")
  }
  assert_eq(
    json_string_from_map(obj, "filePath"),
    Some("/tmp/oh-my-openagent.jsonc"),
  )
  assert_eq(
    json_string_from_map(obj, "lastModified"),
    Some("2026-06-14T00:00:00+00:00"),
  )
  guard obj.get("agents") is Some(Object(agents)) else {
    fail("expected agents object")
  }
  assert_true(agents.get("dev") is Some(_))
  guard obj.get("categories") is Some(Array(categories)) else {
    fail("expected categories array")
  }
  assert_eq(categories.length(), 1)
  guard obj.get("otherFields") is Some(Object(other)) else {
    fail("expected other fields")
  }
  assert_eq(json_string_from_map(other, "theme"), Some("dark"))
  assert_eq(
    json_string_from_map(other, "url"),
    Some("https://example.com//not-comment"),
  )
}

///|
test "moonstat omo slim local file omits categories" {
  let content =
    #|{
    #|  "agents": {"slim": {}},
    #|  "categories": ["ignored"]
    #|}
  guard moon_omo_local_file_data_json_from_content(
      true,
      "/tmp/oh-my-opencode-slim.jsonc",
      Json::null(),
      content,
    )
    is Some(Object(obj)) else {
    fail("expected omo slim local file data")
  }
  assert_eq(obj["categories"], Json::null())
  assert_eq(obj["otherFields"], Json::null())
}

///|
test "moonstat omo current provider helpers use opencode category" {
  let gateway = Gateway::new(port=17777)
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="opencode",
      provider_id="omo-a",
      provider_name="OMO A",
      provider_type=Some("omo"),
    ),
  )
  gateway.proxy.provider_router.upsert_provider(
    ProviderRouteTarget::new(
      app_type="opencode",
      provider_id="plain",
      provider_name="Plain",
    ),
  )
  gateway.proxy.provider_router.set_current_provider("opencode", "omo-a")
  assert_eq(gateway.proxy.current_omo_provider_id(false), "omo-a")
  assert_eq(gateway.proxy.current_omo_provider_id(true), "")
  gateway.proxy.clear_current_omo_provider(false)
  assert_eq(gateway.proxy.provider_router.current_provider_id("opencode"), None)
  gateway.proxy.provider_router.set_current_provider("opencode", "plain")
  gateway.proxy.clear_current_omo_provider(false)
  assert_eq(
    gateway.proxy.provider_router.current_provider_id("opencode"),
    Some("plain"),
  )
}
