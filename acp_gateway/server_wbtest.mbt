///|
fn fixture_bridge(mode : String, timeout_ms~ : Int32 = 15000) -> Bridge raise {
  let cwd = @os.cwd()
  Bridge::from_json({
    "command": "/usr/bin/env",
    "args": [
      "moon",
      "run",
      "--target",
      "native",
      "\{cwd}/tests/fixtures/acp_agent.mbtx",
      mode,
    ],
    "cwd": cwd,
    "token": "local-fixture-token",
    "models": ["alpha", "beta", "missing"],
    "timeout_ms": timeout_ms,
  })
}

///|
async fn with_bridge(bridge : Bridge, run : async (String) -> Unit) -> Unit {
  let server = @httpx.Server::new("127.0.0.1", 0)
  defer server.close()
  @async.with_timeout(25000, () => {
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve((r, w) => bridge.handle(r, w, group)),
        no_wait=true,
      )
      run("http://127.0.0.1:\{server.port()}")
    })
  })
}

///|
async fn request_chat(
  base : String,
  model : String,
  stream~ : Bool = false,
) -> (Int32, String) {
  let body : Json = {
    "model": model,
    "stream": stream,
    "messages": [{ "role": "user", "content": "hello" }],
  }
  let (response, data) = @http.post(
    "\{base}/v1/chat/completions",
    body.stringify(),
    headers={
      "authorization": "Bearer local-fixture-token",
      "content-type": "application/json",
    },
  )
  (response.code, data.text())
}

///|
async test "ACP HTTP catalog authentication text SSE and concurrent model selection" {
  let bridge = fixture_bridge("normal")
  with_bridge(bridge, base => {
    let (denied, _) = @http.get("\{base}/v1/models")
    assert_eq(denied.code, 401)
    let (catalog, data) = @http.get("\{base}/v1/models", headers={
      "authorization": "Bearer local-fixture-token",
    })
    assert_eq(catalog.code, 200)
    assert_true(data.text().contains("configured_allowlist"))
    let (forbidden, _) = @http.get("\{base}/v1/models", headers={
      "authorization": "Bearer local-fixture-token",
      "origin": "https://example.com",
    })
    assert_eq(forbidden.code, 403)
    @async.with_task_group(group => {
      for model in ["alpha", "beta"] {
        group.spawn_bg(() => {
          let (status, text) = request_chat(base, model)
          assert_eq(status, 200)
          let result = @json.parse(text)
          assert_true(
            result
            is {
              "model": String(selected),
              "choices": [
                {
                  "message": { "content": String(content), .. },
                  "finish_reason": "stop",
                  ..
                },
              ],
              ..
            } &&
            selected == model &&
            content == "\{model}:你好 hello",
          )
          assert_false(text.contains("usage"))
        })
      }
    })
    let (status, text) = request_chat(base, "beta", stream=true)
    assert_eq(status, 200)
    assert_true(text.contains("chat.completion.chunk"))
    assert_true(text.contains("你好 "))
    assert_true(text.has_suffix("data: [DONE]\n\n"))
    @async.with_timeout(1000, () => {
      while bridge.active > 0 {
        @async.sleep(1)
      }
    })
  })
}

///|
async test "ACP failures are not successful completions and do not forward diagnostics" {
  for
    (mode, expected) in [
      ("auth", 401),
      ("permission", 422),
      ("tool", 422),
      ("malformed", 502),
      ("wrong-session", 502),
      ("empty", 502),
      ("cancelled", 502),
      ("drift", 502),
    ] {
    let bridge = fixture_bridge(mode)
    with_bridge(bridge, base => {
      let (status, text) = request_chat(base, "alpha")
      assert_eq(status, expected, msg=mode)
      assert_true(text.contains("error"))
      assert_false(text.contains("fixture-secret"))
      assert_eq(bridge.active, 0)
    })
  }
}

///|
async test "ACP SSE error after partial output does not send successful DONE" {
  with_bridge(fixture_bridge("late-error"), base => {
    let (status, text) = request_chat(base, "alpha", stream=true)
    assert_eq(status, 200)
    assert_true(text.contains("chat.completion.chunk"))
    assert_true(text.contains("acp_agent_error"))
    assert_false(text.contains("[DONE]"))
  })
}

///|
async test "ACP timeout stops the child releases concurrency and rejects unavailable models" {
  let bridge = fixture_bridge("hang", timeout_ms=1500)
  with_bridge(bridge, base => {
    let start = @async.now()
    let (status, text) = request_chat(base, "alpha")
    assert_eq(status, 504)
    assert_true(text.contains("acp_timeout"))
    assert_true(@async.now() - start < 5000L)
    assert_eq(bridge.active, 0)
    let (status, _) = request_chat(base, "unlisted")
    assert_eq(status, 404)
  })
  with_bridge(fixture_bridge("normal"), base => {
    let (status, text) = request_chat(base, "missing")
    assert_eq(status, 404)
    assert_true(text.contains("model_unavailable"))
  })
}

///|
async test "ACP concurrency admission is bounded without starting another agent" {
  let bridge = fixture_bridge("hang", timeout_ms=1500)
  let bridge = { ..bridge, max_concurrent: 1, }
  with_bridge(bridge, base => {
    @async.with_task_group(group => {
      let running = group.spawn(() => request_chat(base, "alpha"))
      @async.with_timeout(1000, () => {
        while bridge.active == 0 {
          @async.sleep(1)
        }
      })
      let (status, text) = request_chat(base, "beta")
      assert_eq(status, 429)
      assert_true(text.contains("bridge_busy"))
      assert_eq(running.wait().0, 504)
    })
  })
}
