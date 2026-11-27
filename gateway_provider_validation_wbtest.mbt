///|
fn provider_validation_fixture(base_url : String) -> Json {
  {
    "appType": "openclaw",
    "api": "chat.completions",
    "baseUrl": base_url,
    "apiKey": "fixture-candidate-secret",
    "model": "fixture-selected",
  }
}

///|
test "transient provider validation descriptor retains reviewed URL and field policy" {
  for
    base in [
      "https://example.invalid/v1/", "http://localhost:18000/v1", "http://127.0.0.1:18000/v1",
      "http://[::1]:18000/v1",
    ] {
    assert_true(
      provider_connection_candidate(provider_validation_fixture(base))
      is Some(_),
    )
  }
  for
    base in [
      "http://example.invalid/v1", "http://127.0.0.1.evil.invalid/v1", "https://key@example.invalid/v1",
      "https://example.invalid/v1?key=secret", "https://example.invalid/v1#fragment",
      "https://example.invalid/v1\\path", "https://example.invalid/v1/chat/completions",
      " https://example.invalid",
    ] {
    assert_true(
      provider_connection_candidate(provider_validation_fixture(base)) is None,
    )
  }
  let valid = provider_validation_fixture("https://example.invalid/v1")
  for
    (key, value) in [
      ("appType", "claude"),
      ("api", "responses"),
      ("apiKey", ""),
      ("apiKey", "api-key-placeholder"),
      ("apiKey", "line\nbreak"),
      ("model", ""),
      ("model", "with spaces"),
      ("model", "fixture-candidate-secret"),
      ("apiKey", String::from_array(Array::make(513, 'k'))),
      ("model", String::from_array(Array::make(257, 'm'))),
      (
        "baseUrl",
        "https://example.invalid/" + String::from_array(Array::make(2048, 'x')),
      ),
    ] {
    guard @json.parse(valid.stringify()) is Object(fields) else {
      fail("fixture")
    }
    fields[key] = Json(value)
    assert_true(provider_connection_candidate(Json(fields)) is None)
  }
  guard provider_connection_candidate_target(
      "https://example.invalid/prefix/v1///",
    )
    is Some(target) else {
    fail("target")
  }
  assert_eq(target.origin, "https://example.invalid")
  assert_eq(target.path, "/prefix/v1/models")
  assert_true(
    moongate_route_requires_control(Post, "/providers/validate-connection"),
  )
}

///|
async test "transient provider validation authenticates and checks one catalog without persistence" {
  let upstream = @httpx.Server::new("127.0.0.1", 0)
  defer upstream.close()
  let server = @httpx.Server::new("127.0.0.1", 0)
  defer server.close()
  let requests : Array[String] = []
  let gateway = Gateway::new(
    host="127.0.0.1",
    port=server.port(),
    model="fixture-original",
  )
  gateway.control.token = Some("fixture-control")
  let saved = ProviderRouteTarget::new(
    app_type="openclaw",
    provider_id="fixture-existing",
    provider_name="Existing",
    base_url=Some("https://unchanged.invalid/v1"),
    api_key=Some("fixture-existing-key"),
    model_mapping=Some(
      ModelMapping::new(default_model=Some("fixture-original")),
    ),
  )
  gateway.proxy.provider_router.upsert_provider(saved)
  gateway.proxy.provider_router.set_current_provider(
    "openclaw",
    saved.provider_id,
  )
  let before = gateway.proxy
    .moon_export_providers_json(include_secrets=true)
    .stringify()
  let health_before = gateway.proxy.provider_router
    .provider_health_store_json()
    .stringify()
  let router = @httpx.Router::new()
  gateway.proxy.register_management_routes(
    router,
    gateway.auth,
    gateway.usage,
    "127.0.0.1",
    server.port(),
    0,
    0,
    gateway.config.stream_check_config,
  )
  @async.with_timeout(20000, () => {
    @async.with_task_group(group => {
      group.spawn_bg(
        () => {
          upstream.serve((r, w) => {
            assert_eq(r.method_, Get)
            assert_eq(
              r.headers.get("authorization"),
              Some("Bearer fixture-candidate-secret"),
            )
            requests.push(r.path.to_owned())
            let (status, body) = match r.path.to_owned() {
              "/valid/v1/models" =>
                (
                  200, "{\"data\":[{\"id\":\"other\"},{\"id\":\"fixture-selected\",\"owned_by\":\"fixture-candidate-secret\"}]}",
                )
              "/missing/v1/models" => (200, "{\"data\":[{\"id\":\"other\"}]}")
              "/denied/v1/models" =>
                (401, "fixture-candidate-secret reflected error")
              "/malformed/v1/models" =>
                (200, "fixture-candidate-secret invalid JSON")
              "/secret/v1/models" =>
                (200, "{\"data\":[{\"id\":\"fixture-candidate-secret\"}]}")
              "/large/v1/models" =>
                (200, String::from_array(Array::make(1_048_577, 'x')))
              "/redirect/v1/models" =>
                (302, "fixture-candidate-secret redirect")
              _ => (404, "fixture-candidate-secret not found")
            }
            w.header().set("Content-Type", "application/json")
            w.header().set("Location", "/valid/v1/models")
            w.write_header(status)
            w.write(body)
            w.flush()
          })
        },
        no_wait=true,
        allow_failure=true,
      )
      group.spawn_bg(
        () => {
          server.serve(
            moongate_security_handler(
              router.handler(),
              gateway.control,
              "127.0.0.1",
              server.port(),
            ),
          )
        },
        no_wait=true,
        allow_failure=true,
      )
      let url = "http://127.0.0.1:\{server.port()}/providers/validate-connection"
      let upstream_base = "http://127.0.0.1:\{upstream.port()}"
      let headers = Map([
        (@http.CaseInsensitiveString("x-moongate-control-token"), "fixture-control"),
      ])
      let (unauthorized, _) = @http.post(
        url,
        provider_validation_fixture(upstream_base + "/valid/v1"),
      )
      assert_eq(unauthorized.code, 401)
      assert_eq(requests.length(), 0)
      let (invalid, _) = @http.post(url, Json::empty_object(), headers~)
      assert_eq(invalid.code, 400)
      assert_eq(requests.length(), 0)
      let (valid, valid_body) = @http.post(
        url,
        provider_validation_fixture(upstream_base + "/valid/v1///"),
        headers~,
      )
      assert_eq(valid.code, 200)
      assert_eq(valid.headers.get("cache-control"), Some("no-store"))
      assert_eq(
        @json.parse(valid_body.text()),
        (
          {
            "contract": "moongate.provider-connection-validation.v1",
            "valid": true,
            "model": "fixture-selected",
            "inferencePerformed": false,
            "persisted": false,
          } : Json),
      )
      assert_false(valid_body.text().contains("fixture-candidate-secret"))
      assert_eq(requests, ["/valid/v1/models"])
      for
        branch in [
          "missing", "denied", "malformed", "secret", "large", "redirect", "absent",
        ] {
        let prior = requests.length()
        let (result, body) = @http.post(
          url,
          provider_validation_fixture(upstream_base + "/" + branch + "/v1"),
          headers~,
        )
        assert_eq(result.code, 400)
        assert_eq(result.headers.get("cache-control"), Some("no-store"))
        assert_false(body.text().contains("fixture-candidate-secret"))
        assert_false(body.text().contains(upstream_base))
        assert_true(
          @json.parse(body.text())
          is {
            "error": { "code": "moongate_provider_validation_failed", .. },
            ..
          },
        )
        assert_eq(requests.length(), prior + 1)
      }
      let prior = requests.length()
      let (oversize, _) = @http.post(
        url,
        String::from_array(Array::make(8193, 'x')),
        headers~,
      )
      assert_eq(oversize.code, 400)
      assert_eq(requests.length(), prior)
      assert_eq(
        gateway.proxy
        .moon_export_providers_json(include_secrets=true)
        .stringify(),
        before,
      )
      assert_eq(
        gateway.proxy.provider_router.provider_health_store_json().stringify(),
        health_before,
      )
      assert_eq(
        gateway.proxy.provider_router.current_provider_id("openclaw"),
        Some("fixture-existing"),
      )
    })
  })
}
