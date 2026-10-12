///|
test "saved catalog normalizes IDs without leaking provider metadata" {
  let body : Json = {
    "data": [
      { "id": "vendor/月-model", "owned_by": "fixture-secret" },
      { "id": "alpha<&\"", "owned_by": null },
      { "id": "vendor/月-model" },
    ],
  }
  guard saved_provider_models_from_body(body.stringify(), "fixture-secret")
    is Ok(models) else {
    fail("Expected usable models")
  }
  assert_eq(models.map(model => model.id), ["alpha<&\"", "vendor/月-model"])
  assert_false(
    fetched_models_to_json(models).stringify().contains("fixture-secret"),
  )
  assert_true(models.all(model => model.owned_by is None))
  guard saved_provider_models_from_body("{\"data\":[]}", "fixture-secret")
    is Ok(empty) else {
    fail("Expected an empty catalog")
  }
  assert_eq(empty.length(), 0)
}

///|
test "saved catalog rejects malformed unsafe and secret-bearing model IDs" {
  for
    id in [
      "", " leading", "trailing ", "a b", "a\nb", "a\u{0}b", "a\u{7f}b", "a\u{85}b",
      "a\u{a0}b", "a\u{feff}b", "a\u{3000}b", "prefix-fixture-secret",
    ] {
    let body : Json = { "data": [{ "id": id }] }
    guard saved_provider_models_from_body(body.stringify(), "fixture-secret")
      is Err(message) else {
      fail("Expected invalid ID rejection")
    }
    assert_false(message.contains("fixture-secret"))
  }
  for body in ["{", "{}", "[]", "{\"data\":{}}", "{\"data\":[{}]}"] {
    assert_true(
      saved_provider_models_from_body(body, "fixture-secret") is Err(_),
    )
  }
  let excessive : Array[Json] = []
  for i in 0..<2001 {
    excessive.push({ "id": "model-\{i}" })
  }
  let too_many : Json = { "data": excessive }
  assert_true(
    saved_provider_models_from_body(too_many.stringify(), "fixture-secret")
    is Err(_),
  )
}

///|
async test "saved catalog unsupported and unconfigured providers never need network" {
  let base = ProviderRouteTarget::new(
    app_type="openclaw",
    provider_id="local",
    provider_name="Fixture",
    origin="user",
  )
  for
    provider in [
      base,
      { ..base, base_url: Some("http://127.0.0.1:1"), },
      { ..base, provider_type: Some("codex_oauth"), },
      { ..base, api_format: Some("gemini_native"), },
    ] {
    assert_true(saved_provider_models(provider) is Err(_))
  }
  assert_true(moongate_route_requires_control(Get, "/providers/models"))
}

///|
async test "saved catalog real loopback route uses stored keys and keeps selection durable" {
  let upstream = @httpx.Server::new("127.0.0.1", 0)
  defer upstream.close()
  let server = @httpx.Server::new("127.0.0.1", 0)
  defer server.close()
  let requests : Array[Json] = []
  let gateway = Gateway::new(
    host="127.0.0.1",
    port=server.port(),
    model="fixture-original",
  )
  gateway.control.token = Some("fixture-control")
  let provider = ProviderRouteTarget::new(
    app_type="openclaw",
    provider_id="fixture",
    provider_name="Fixture",
    base_url=Some("http://127.0.0.1:\{upstream.port()}/valid/v1"),
    api_key=Some("fixture-host-secret"),
    api_format=Some("openai_chat"),
    origin="user",
    model_mapping=Some(
      ModelMapping::new(default_model=Some("fixture-original")),
    ),
  )
  gateway.proxy.provider_router.upsert_provider(provider)
  gateway.proxy.provider_router.set_current_provider("openclaw", "fixture")
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
  gateway.proxy.register_inference_routes(
    router,
    gateway.auth,
    gateway.usage,
    gateway.config,
    gateway.session,
    gateway.model,
    gateway.logger,
  )
  @async.with_timeout(15000, () => {
    @async.with_task_group(group => {
      group.spawn_bg(
        () => {
          upstream.serve((r, w) => {
            assert_eq(r.method_, Get)
            assert_true(r.path.has_suffix("/models"))
            let bearer = r.headers.get("authorization")
            let anthropic = r.headers.get("x-api-key")
            assert_true(
              bearer == Some("Bearer fixture-host-secret") ||
              anthropic == Some("fixture-host-secret"),
            )
            requests.push({
              "path": r.path.to_owned(),
              "auth": if anthropic is Some(_) {
                "anthropic"
              } else {
                "bearer"
              },
            })
            let (status, body) = match r.path.to_owned() {
              "/valid/v1/models" =>
                (
                  200, "{\"data\":[{\"id\":\"fixture-second\",\"owned_by\":\"fixture-host-secret\"},{\"id\":\"fixture-original\"}]}",
                )
              "/empty/v1/models" => (200, "{\"data\":[]}")
              "/malformed/v1/models" => (200, "fixture-host-secret malformed")
              "/secret/v1/models" =>
                (200, "{\"data\":[{\"id\":\"fixture-host-secret\"}]}")
              "/denied/v1/models" =>
                (401, "fixture-host-secret echoed by provider")
              _ => (404, "fixture-host-secret missing")
            }
            w.header().set("Content-Type", "application/json")
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
      let base_url = "http://127.0.0.1:\{server.port()}"
      let path = "/providers/models?appType=openclaw&providerId=fixture"
      let (unauthorized, _) = @http.get(base_url + path)
      assert_eq(unauthorized.code, 401)
      assert_eq(requests.length(), 0)
      let headers = { "x-moongate-control-token": "fixture-control" }
      let (response, data) = @http.get(
        base_url +
        path +
        "&baseUrl=http://127.0.0.1:1&apiKey=browser-must-not-be-used",
        headers~,
      )
      assert_eq(response.code, 200)
      let text = data.text()
      assert_false(text.contains("fixture-host-secret"))
      assert_false(text.contains("browser-must-not-be-used"))
      let json = @json.parse(text)
      assert_eq(json_string_field(json, "providerId"), Some("fixture"))
      assert_eq(json_bool_field(json, "inferencePerformed"), Some(false))
      assert_eq(requests.length(), 1)
      assert_eq(
        gateway.proxy.provider_router.current_provider_id("openclaw"),
        Some("fixture"),
      )
      assert_eq(
        gateway.proxy.provider_router
        .provider_by_id("openclaw", "fixture")
        .unwrap()
        .binding_model(""),
        "fixture-original",
      )
      assert_eq(
        gateway.proxy.provider_router.provider_health_status(
          "fixture", "openclaw",
        ),
        "unknown",
      )
      let (missing, missing_data) = @http.get(
        base_url + "/providers/models?appType=openclaw&providerId=absent",
        headers~,
      )
      assert_eq(missing.code, 400)
      assert_true(missing_data.text().contains("not found"))
      assert_eq(requests.length(), 1)
      for branch in ["empty", "malformed", "secret", "denied", "absent"] {
        gateway.proxy.provider_router.upsert_provider({
          ..provider,
          base_url: Some("http://127.0.0.1:\{upstream.port()}/\{branch}/v1"),
        })
        let (result, body) = @http.get(base_url + path, headers~)
        assert_eq(result.code, if branch == "empty" { 200 } else { 400 })
        let text = body.text()
        assert_false(text.contains("fixture-host-secret"))
        if branch == "empty" {
          guard @json.parse(text) is Object(result) else {
            fail("Expected catalog object")
          }
          assert_eq(result["models"], Json::array([]))
        }
      }
      gateway.proxy.provider_router.upsert_provider({
        ..provider,
        api_format: Some("anthropic"),
      })
      let (anthropic, data) = @http.get(base_url + path, headers~)
      assert_eq(anthropic.code, 200)
      assert_false(data.text().contains("fixture-host-secret"))
      assert_eq(
        json_string_field(requests[requests.length() - 1], "auth"),
        Some("anthropic"),
      )
      @fsx.with_temporary_directory("moongate-catalog-selection-XXXXXX", async fn(
        dir,
      ) {
        let store = @pathx.join(dir, "providers.json")
        // Use the same request decoder and merge as Save Provider; omitted keys
        // retain the host-held credential, and selection is an explicit edit.
        let body : Json = {
          "id": "fixture",
          "name": "Fixture",
          "baseUrl": provider.base_url.unwrap(),
          "apiFormat": "openai_chat",
          "modelMapping": { "defaultModel": "fixture-second" },
        }
        let incoming = provider_target_from_request(
          "/providers/update",
          Some(body),
          "openclaw",
        ).unwrap()
        let selected = provider_preserve_hidden_update_fields(
          incoming, provider,
        )
        gateway.proxy.provider_router.upsert_provider(selected)
        gateway.proxy.save_provider_store(path=store)
        let loaded = ProxyService::new("127.0.0.1", server.port())
        loaded.load_provider_store(path=store)
        let restored = loaded.provider_router
          .provider_by_id("openclaw", "fixture")
          .unwrap()
        assert_eq(restored.binding_model(""), "fixture-second")
        assert_eq(restored.api_key, Some("fixture-host-secret"))
        assert_eq(restored.base_url, provider.base_url)
        assert_eq(restored.api_format, provider.api_format)
        assert_false(
          loaded.provider_router
          .providers_moon_json("openclaw")
          .stringify()
          .contains("fixture-host-secret"),
        )
        let (catalog_response, catalog_body) = @http.get(
          base_url + "/openclaw/v1/models",
        )
        assert_eq(catalog_response.code, 200)
        assert_true(catalog_body.text().contains("fixture-second"))
      })
      match @env.get_env_var("MOONGATE_CATALOG_EVIDENCE") {
        Some(dir) => {
          @fsx.write_to_file(
            @pathx.join(dir, "loopback.json"),
            (
              {
                "upstream_requests": requests,
                "only_catalog_gets": true,
                "unauthorized_upstream_requests": 0,
                "secret_isolated": true,
                "saved_default": "fixture-second",
                "provider_execution": false,
              } : Json).stringify(indent=2),
          )
          @fsx.write_to_file(
            @pathx.join(dir, "generated-preview.json"),
            moongate_rabbita_lepusa_manifest(),
          )
        }
        None => ()
      }
    })
  })
}
