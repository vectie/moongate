///|
test "managed media routes are exact and never become an arbitrary proxy" {
  let id = "video-" + "a".repeat(64)
  assert_true(allowed_route(Post, "/v1/videos"))
  assert_true(allowed_route(Get, "/v1/videos/" + id))
  assert_true(allowed_route(Delete, "/v1/videos/" + id))
  assert_true(allowed_route(Get, "/v1/videos/" + id + "/content"))
  for path in ["/v1/videos/../models", "/v1/videos/%2fsecret", "/v1/videos/" + id + "?url=evil", "/v1/media/operator/jobs"] {
    assert_false(allowed_route(Get, path))
  }
  assert_false(allowed_route(Delete, "/v1/videos/" + id + "/content"))
}

///|
async test "managed media forwards scoped auth once without cookies control tokens or retries" {
  let controller = @httpx.Server::new("127.0.0.1", 0)
  let server = @httpx.Server::new("127.0.0.1", 0)
  defer controller.close()
  defer server.close()
  let gateway = MediaGateway::new("http://127.0.0.1:\{controller.port()}")
  let state = { "calls": 0 }
  let id = "video-" + "a".repeat(64)
  @async.with_task_group <| group => {
    group.spawn_bg(no_wait=true, () => controller.serve((request, writer) => {
      state["calls"] += 1
      ignore(@io.Reader::read_all(request.body))
      assert_eq(request.headers.get("authorization"), Some("Bearer scoped-fixture"))
      assert_eq(request.headers.get("cookie"), None)
      assert_eq(request.headers.get("x-moongate-control-token"), None)
      assert_eq(request.headers.get("x-forwarded-host"), None)
      if request.method_ == Post {
        assert_eq(request.headers.get("idempotency-key"), Some("request-fixture"))
      }
      writer.header().set("set-cookie", "must-not-cross=true")
      if request.path.has_suffix("/content") {
        writer.header().set("content-type", "video/mp4")
        writer.write(b"fixture-content")
      } else {
        writer.header().set("content-type", "application/json")
        writer.write(({ "id": id, "status": "queued" } : Json).stringify())
      }
      writer.close()
    }))
    group.spawn_bg(no_wait=true, () => server.serve((r, w) => gateway.handle(r, w)))
    let origin = "http://127.0.0.1:\{server.port()}"
    let headers = { "authorization": "Bearer scoped-fixture", "idempotency-key": "request-fixture", "content-type": "application/json",
      "cookie": "private-cookie", "x-moongate-control-token": "private-control", "x-forwarded-host": "evil" }
    let (reply, _) = @http.post(origin + "/v1/videos", "{}", headers~)
    assert_eq(reply.code, 200)
    assert_eq(reply.headers.get("set-cookie"), None)
    let (content, bytes) = @http.get(origin + "/v1/videos/" + id + "/content", headers~)
    assert_eq(content.code, 200)
    assert_eq(bytes.binary(), b"fixture-content")
    let (missing, _) = @http.post(origin + "/v1/videos", "{}")
    assert_eq(missing.code, 401)
    let browser_headers = headers.copy()
    browser_headers["origin"] = "http://evil"
    let (browser, _) = @http.post(origin + "/v1/videos", "{}", headers=browser_headers)
    assert_eq(browser.code, 403)
    let (oversized, _) = @http.post(origin + "/v1/videos", "a".repeat(65537), headers~)
    assert_eq(oversized.code, 413)
    assert_eq(state["calls"], 2)
  }
}
