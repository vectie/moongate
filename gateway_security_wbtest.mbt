///|
test "gateway security accepts local SDK requests without origin" {
  assert_true(
    moongate_request_authority_allowed(
      { "host": "127.0.0.1:15721" },
      "127.0.0.1",
      15721,
    ),
  )
  assert_true(
    moongate_request_authority_allowed(
      { "host": "localhost:15721" },
      "127.0.0.1",
      15721,
    ),
  )
  assert_true(
    moongate_request_authority_allowed(
      { "host": "127.0.0.1" },
      "127.0.0.1",
      15721,
    ),
  )
  assert_true(
    moongate_request_authority_allowed(
      { "host": "localhost" },
      "127.0.0.1",
      15721,
    ),
  )
}

///|
test "gateway security accepts same-origin dashboard requests" {
  assert_true(
    moongate_request_authority_allowed(
      { "host": "127.0.0.1:15721", "origin": "http://127.0.0.1:15721" },
      "127.0.0.1",
      15721,
    ),
  )
}

///|
test "gateway security rejects DNS rebinding and cross-origin browsers" {
  assert_false(
    moongate_request_authority_allowed(
      { "host": "attacker.example:15721" },
      "127.0.0.1",
      15721,
    ),
  )
  assert_false(
    moongate_request_authority_allowed(
      { "host": "127.0.0.1:15721", "origin": "https://attacker.example" },
      "127.0.0.1",
      15721,
    ),
  )
  assert_false(
    moongate_request_authority_allowed(
      { "host": "127.0.0.1:15722" },
      "127.0.0.1",
      15721,
    ),
  )
  assert_false(
    moongate_request_authority_allowed(
      { "host": "127.0.0.1:15721", "origin": "null" },
      "127.0.0.1",
      15721,
    ),
  )
}

///|
test "gateway security supports explicit non-loopback bind authority" {
  assert_true(
    moongate_request_authority_allowed(
      { "host": "192.168.1.20:15721", "origin": "http://192.168.1.20:15721" },
      "192.168.1.20",
      15721,
    ),
  )
  assert_false(
    moongate_request_authority_allowed(
      { "host": "192.168.1.20" },
      "192.168.1.20",
      15721,
    ),
  )
}

///|
test "gateway security keeps inference public and protects control plane" {
  assert_false(moongate_route_requires_control(Post, "/v1/chat/completions"))
  assert_false(
    moongate_route_requires_control(Post, "/openclaw/v1/chat/completions"),
  )
  assert_false(
    moongate_route_requires_control(Post, "/claude-desktop/v1/messages"),
  )
  assert_false(moongate_route_requires_control(Get, "/health"))
  assert_false(moongate_route_requires_control(Get, "/assets/moongate.js"))
  assert_true(moongate_route_requires_control(Get, "/providers"))
  assert_true(moongate_route_requires_control(Post, "/providers"))
  assert_true(moongate_route_requires_control(Get, "/copilot/token"))
  assert_true(moongate_route_requires_control(Get, "/workspace/files"))
  assert_true(moongate_route_requires_control(Post, "/suite/status/write"))
}

///|
test "gateway control bootstrap requires a same-origin browser" {
  assert_true(
    moongate_control_bootstrap_allowed(
      { "origin": "http://127.0.0.1:15721", "sec-fetch-site": "same-origin" },
      "127.0.0.1",
      15721,
    ),
  )
  assert_true(
    moongate_control_bootstrap_allowed(
      { "sec-fetch-site": "same-origin" },
      "127.0.0.1",
      15721,
    ),
  )
  assert_false(moongate_control_bootstrap_allowed({}, "127.0.0.1", 15721))
  assert_false(
    moongate_control_bootstrap_allowed(
      { "origin": "http://127.0.0.1:15721", "sec-fetch-site": "cross-site" },
      "127.0.0.1",
      15721,
    ),
  )
}

///|
async test "gateway control token persists and authenticates" {
  let dir = @pathx.join(
    "/tmp",
    "moongate-control-token-\{@async.now().to_int()}",
  )
  let path = @pathx.join(dir, MOONGATE_CONTROL_TOKEN_FILE)
  let first = ControlPlaneAuth::new()
  first.initialize(path~)
  guard first.token is Some(token) else { fail("expected control token") }
  assert_true(token.has_prefix("mst_req_"))
  assert_true(first.authorized({ "x-moongate-control-token": token }))
  assert_false(first.authorized({ "x-moongate-control-token": "wrong" }))

  let second = ControlPlaneAuth::new()
  second.initialize(path~)
  assert_eq(second.token, Some(token))
}
