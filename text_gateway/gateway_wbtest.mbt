///|
test "event model routes and origin cannot become an arbitrary proxy" {
  assert_true(allowed_route(Post, "/v1/chat/completions"))
  assert_true(allowed_route(Post, "/v1/responses"))
  assert_true(allowed_route(Get, "/v1/models"))
  for
    path in [
      "/providers", "/v1/responses/compact", "/v1/models?url=evil", "/v1/../accounts",
      "/v1/videos",
    ] {
    assert_false(allowed_route(Get, path))
    assert_false(allowed_route(Post, path))
  }
  for
    origin in [
      "file:///tmp", "https://good@evil", "https://good/path", "http://good?url=evil",
    ] {
    let rejected = try {
      ignore(TextGateway::new(origin))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
async test "event relay isolates caller credentials, forwards streams and never retries" {
  let controller = @httpx.Server::new("127.0.0.1", 0)
  let server = @httpx.Server::new("127.0.0.1", 0)
  defer controller.close()
  defer server.close()
  let gateway = TextGateway::new(
    "http://127.0.0.1:\{controller.port()}",
    browser_origin="https://portal.example",
  )
  let calls : Array[String] = []
  @async.with_task_group <| group => {
    group.spawn_bg(no_wait=true, () => {
      controller.serve((r, w) => {
        let authorization = r.headers.get("authorization").unwrap_or("")
        calls.push(authorization)
        ignore(@io.Reader::read_all(r.body))
        assert_eq(r.headers.get("cookie"), None)
        assert_eq(r.headers.get("x-moongate-control-token"), None)
        assert_eq(r.headers.get("x-lunanexa-subject"), None)
        assert_eq(
          r.headers.get("x-lunanexa-prefix-cache"),
          if authorization == "Bearer user-one" {
            Some("tenant")
          } else {
            None
          },
        )
        if authorization == "Bearer budget-user" {
          w.header().set("content-type", "application/json")
          w.write_header(403)
          w.write(
            "{\"error\":{\"code\":\"WorkspaceLimitExceeded\",\"message\":\"private upstream detail\"}}",
          )
        } else if authorization == "Bearer rejected-user" {
          w.header().set("location", "https://untrusted.invalid")
          w.write_header(503)
          w.write("private upstream error must not escape")
        } else {
          w.header().set("content-type", "text/event-stream")
          w.header().set("set-cookie", "private=1")
          w.write("data: {\"text\":\"hello\"}\n\ndata: [DONE]\n\n")
        }
        w.close()
      })
    })
    group.spawn_bg(no_wait=true, () => {
      server.serve((r, w) => gateway.handle(r, w))
    })
    let origin = "http://127.0.0.1:\{server.port()}"
    for user in ["one", "two"] {
      let (reply, body) = @http.post(origin + "/v1/chat/completions", "{}", headers={
        "authorization": "Bearer user-" + user,
        "content-type": "application/json",
        "cookie": "private",
        "x-moongate-control-token": "private",
        "x-lunanexa-subject": "forged",
        "x-lunanexa-prefix-cache": if user == "one" {
          "tenant"
        } else {
          "global"
        },
      })
      assert_eq(reply.code, 200)
      assert_true(body.text().contains("[DONE]"))
      assert_eq(reply.headers.get("set-cookie"), None)
    }
    let (failed, body) = @http.post(origin + "/v1/responses", "{}", headers={
      "authorization": "Bearer rejected-user",
      "content-type": "application/json",
    })
    assert_eq(failed.code, 503)
    assert_false(body.text().contains("private upstream"))
    assert_eq(failed.headers.get("location"), None)
    assert_eq(calls, [
      "Bearer user-one", "Bearer user-two", "Bearer rejected-user",
    ])
    assert_eq(@http.get(origin + "/v1/models").0.code, 401)
    assert_eq(
      @http.get(origin + "/v1/models", headers={
        "authorization": "Bearer user-one",
        "origin": "https://evil",
      }).0.code,
      403,
    )
    assert_eq(
      @http.post(origin + "/v1/responses", "a".repeat(1048577), headers={
        "authorization": "Bearer user-one",
        "content-type": "application/json",
      }).0.code,
      413,
    )
    assert_eq(calls.length(), 3)
    let (browser, _) = @http.post(origin + "/v1/chat/completions", "{}", headers={
      "authorization": "Bearer browser-user",
      "content-type": "application/json",
      "origin": "https://portal.example",
    })
    assert_eq(browser.code, 200)
    assert_eq(calls.length(), 4)
    let (budget, budget_body) = @http.post(
      origin + "/v1/chat/completions",
      "{}",
      headers={
        "authorization": "Bearer budget-user",
        "content-type": "application/json",
      },
    )
    assert_eq(budget.code, 400)
    assert_true(budget_body.text().contains("WorkspaceLimitExceeded"))
    assert_true(budget_body.text().contains("invalid_request_error"))
    assert_true(budget_body.text().contains("Your API key was accepted"))
    assert_false(budget_body.text().contains("private upstream detail"))
    assert_eq(
      @http.post(origin + "/v1/chat/completions", "{}", headers={
        "content-type": "application/json",
        "origin": "https://portal.example",
        "cookie": "session=not-authority",
      }).0.code,
      401,
    )
    assert_eq(calls.length(), 5)
    // JSON escaping can put an otherwise valid canonical input above 64 KiB.
    // Only transport limits belong here; workspace policy remains upstream.
    let escaped = "{\"messages\":[{\"role\":\"user\",\"content\":\"" +
      "\\u0061".repeat(12000) +
      "\"}]}"
    let (large, large_body) = @http.post(
      origin + "/v1/chat/completions",
      escaped,
      headers={
        "authorization": "Bearer user-two",
        "content-type": "application/json",
      },
    )
    assert_eq(large.code, 200)
    assert_true(large_body.text().contains("[DONE]"))
    assert_eq(calls.length(), 6)
  }
}
