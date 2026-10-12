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
    moongate_route_requires_control(Post, "/paiwork/v1/chat/completions"),
  )
  assert_false(moongate_route_requires_control(Post, "/openclaw/v1/responses"))
  assert_false(moongate_route_requires_control(Get, "/openclaw/v1/models"))
  assert_false(moongate_route_requires_control(Get, "/paiwork/v1/models"))
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

///|
test "gateway security rejects fuzzed malformed loopback authorities" {
  let malformed_ports = ["", "0", "-1", "+15721", "15721x", "65536"]
  for port in malformed_ports {
    assert_false(
      moongate_request_authority_allowed(
        { "host": "127.0.0.1:\{port}" },
        "127.0.0.1",
        15721,
      ),
    )
  }
  let authority_suffixes = [
    "/providers", "?ignored=true", "#fragment", "@attacker.example", ",attacker.example",
    "%2fproviders", "\\..\\providers", "\r\nx-forwarded-host: attacker.example",
  ]
  for suffix in authority_suffixes {
    assert_false(
      moongate_request_authority_allowed(
        { "host": "127.0.0.1:15721\{suffix}" },
        "127.0.0.1",
        15721,
      ),
    )
  }
}

///|
test "gateway security rejects adversarial origin grammar" {
  let origins = [
    "https://127.0.0.1:15721", "ftp://127.0.0.1:15721", "http://user@127.0.0.1:15721",
    "http://127.0.0.1:15721/providers", "http://127.0.0.1:15721?query=true", "http://127.0.0.1:15721#fragment",
    "http://127.0.0.1:15721%2fproviders", "http://127.0.0.1:15721,attacker.example",
  ]
  for origin in origins {
    assert_false(moongate_origin_allowed(origin, "127.0.0.1", 15721))
  }
}

///|
test "gateway security supports strict IPv6 loopback authority" {
  assert_true(
    moongate_request_authority_allowed(
      { "host": "[::1]:15721", "origin": "http://[::1]:15721" },
      "::1",
      15721,
    ),
  )
  assert_false(
    moongate_request_authority_allowed(
      { "host": "[::1]:not-a-port" },
      "::1",
      15721,
    ),
  )
}

///|
test "gateway security keeps adversarial public-route mutations protected" {
  let public_inference = [
    "/v1/messages", "/v1/chat/completions", "/v1/responses", "/v1/responses/compact",
    "/openclaw/v1/chat/completions", "/paiwork/v1/chat/completions",
  ]
  let suffixes = ["/", "/..", ".json", "%00", "#fragment"]
  for path in public_inference {
    for suffix in suffixes {
      assert_true(moongate_route_requires_control(Get, "\{path}\{suffix}"))
      assert_true(moongate_route_requires_control(Post, "\{path}\{suffix}"))
    }
  }
  let static_traversals = [
    "/assets/../providers", "/assets/./moongate.js", "/assets/%2e%2e/providers",
    "/assets/%252e%252e/providers", "/assets/..\\providers",
  ]
  for path in static_traversals {
    assert_true(moongate_route_requires_control(Get, path))
  }
}
