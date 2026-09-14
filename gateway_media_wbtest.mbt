///|
test "managed video routes use downstream scoped authority rather than management tokens" {
  let path = "/v1/videos/video-" + "a".repeat(64)
  assert_false(moongate_route_requires_control(Post, "/v1/videos"))
  assert_false(moongate_route_requires_control(Get, path))
  assert_false(moongate_route_requires_control(Delete, path))
  assert_false(moongate_route_requires_control(Get, path + "/content"))
  assert_true(moongate_route_requires_control(Post, "/v1/media/operator/jobs"))
  assert_true(moongate_request_authority_allowed({ "host": "moongate.webide.svc.cluster.local:8081" }, "moongate.webide.svc.cluster.local", 8081))
  assert_false(moongate_request_authority_allowed({ "host": "evil.example:8081" }, "moongate.webide.svc.cluster.local", 8081))
}
