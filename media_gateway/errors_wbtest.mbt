///|
test "video client errors are distinct from ambiguous provider failures without leaking upstream details" {
  for code in [400, 415, 422] {
    assert_true(
      bounded_error(code)
      is { "error": { "code": "InvalidVideoRequest", .. }, .. },
    )
  }
  for code in [401, 403] {
    assert_true(
      bounded_error(code)
      is { "error": { "code": "VideoAccessDenied", .. }, .. },
    )
  }
  for code in [500, 502, 503, 504] {
    assert_true(
      bounded_error(code)
      is { "error": { "code": "ManagedVideoUnavailable", .. }, .. },
    )
    assert_true(
      bounded_error(code).stringify().contains("retain the same request key"),
    )
  }
  assert_true(
    bounded_error(429) is { "error": { "code": "VideoRateLimited", .. }, .. },
  )
}

///|
async test "video error status survives the proxy without upstream diagnostic leakage or retries" {
  let upstream = @httpx.Server::new("127.0.0.1", 0)
  let public = @httpx.Server::new("127.0.0.1", 0)
  defer upstream.close()
  defer public.close()
  let gateway = MediaGateway::new("http://127.0.0.1:\{upstream.port()}")
  let state = { "status": 400, "calls": 0 }
  @async.with_task_group <| group => {
    group.spawn_bg(no_wait=true, () => {
      upstream.serve((_request, writer) => {
        state["calls"] += 1
        writer.header().set("content-type", "application/json")
        writer.write_header(state["status"])
        writer.write("{\"error\":\"private-upstream-diagnostic\"}")
        writer.close()
      })
    })
    group.spawn_bg(no_wait=true, () => {
      public.serve((request, writer) => gateway.handle(request, writer))
    })
    for code in [400, 403, 409, 429, 503] {
      state["status"] = code
      let (response, body) = @http.get(
        "http://127.0.0.1:\{public.port()}/v1/videos/video-" + "a".repeat(64),
        headers={ "authorization": "Bearer fixture-only" },
      )
      assert_eq(response.code, code)
      assert_eq(@json.parse(body.text()), bounded_error(code))
      assert_false(body.text().contains("private-upstream-diagnostic"))
    }
    assert_eq(state["calls"], 5)
  }
}
