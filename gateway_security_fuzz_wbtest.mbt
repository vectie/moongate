///|
test "fuzz gateway authority rejects forbidden-token insertion" {
  let fuzz = AdversarialFuzzer::new(0x4d4f4f4eL)
  let forbidden = ["/", "\\", "?", "#", "@", ",", "%", " ", "\t", "\r", "\n"]
  for iteration in 0..<5_000 {
    let base = "127.0.0.1:15721"
    let token = forbidden[fuzz.next(forbidden.length())]
    let candidate = adversarial_ascii_insert(
      base,
      fuzz.next(base.length() + 1),
      token,
    )
    if moongate_parse_authority(candidate) is Some(_) {
      fail("seed=0x4d4f4f4e iteration=\{iteration} accepted=\{candidate}")
    }
  }
}

///|
test "fuzz gateway authority parser is total and preserves invariants" {
  let fuzz = AdversarialFuzzer::new(0x41555448L)
  let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~:[]!$&'()*+;="
  for iteration in 0..<5_000 {
    let candidate = fuzz.ascii(0, 192, alphabet~)
    match moongate_parse_authority(candidate) {
      Some(authority) => {
        if authority.host.is_empty() {
          fail("seed=0x41555448 iteration=\{iteration} produced empty host")
        }
        match authority.port {
          Some(port) if port < 1 || port > 65535 =>
            fail("seed=0x41555448 iteration=\{iteration} produced port=\{port}")
          _ => ()
        }
      }
      None => ()
    }
  }
}

///|
test "fuzz gateway origin rejects suffix and scheme mutations" {
  let fuzz = AdversarialFuzzer::new(0x4f524947L)
  let base = "http://127.0.0.1:15721"
  let mutations = [
    "/path", "?query=1", "#fragment", "%2fpath", "@attacker.example", ".attacker.example",
    "\r\nx-host:evil", "\n", " ", "\\path",
  ]
  let schemes = ["https", "ftp", "file", "javascript", "HTTP"]
  for iteration in 0..<3_000 {
    let candidate = if fuzz.next(2) == 0 {
      "\{base}\{mutations[fuzz.next(mutations.length())]}"
    } else {
      let scheme = schemes[fuzz.next(schemes.length())]
      "\{scheme}://127.0.0.1:15721"
    }
    if moongate_origin_allowed(candidate, "127.0.0.1", 15721) {
      fail("seed=0x4f524947 iteration=\{iteration} accepted=\{candidate}")
    }
  }
}

///|
test "fuzz exact public routes fail closed under mutation" {
  let fuzz = AdversarialFuzzer::new(0x524f5554L)
  let routes : Array[(@httpx.Method, String)] = [
    (Get, "/health"),
    (Get, "/status"),
    (Get, "/stats"),
    (Get, "/metrics"),
    (Get, "/suite/manifest"),
    (Get, "/suite/status"),
    (Get, "/suite/moonclaw-providers"),
    (Post, "/v1/messages"),
    (Post, "/v1/chat/completions"),
    (Post, "/v1/responses"),
    (Post, "/v1/responses/compact"),
    (Post, "/openclaw/v1/chat/completions"),
    (Post, "/paiwork/v1/chat/completions"),
    (Post, "/openclaw/v1/responses"),
    (Post, "/claude-desktop/v1/messages"),
    (Get, "/v1/models"),
    (Get, "/openclaw/v1/models"),
    (Get, "/paiwork/v1/models"),
    (Get, "/claude-desktop/v1/models"),
  ]
  let mutations = ["/", "/..", ".json", "%00", "%2f", "#x", "\\x", "//"]
  for iteration in 0..<5_000 {
    let (method_, route) = routes[fuzz.next(routes.length())]
    let token = mutations[fuzz.next(mutations.length())]
    let candidate = adversarial_ascii_insert(
      route,
      fuzz.next(route.length() + 1),
      token,
    )
    if candidate != route &&
      !moongate_route_requires_control(method_, candidate) {
      fail("seed=0x524f5554 iteration=\{iteration} opened=\{candidate}")
    }
  }
}

///|
test "fuzz public routes fail closed under HTTP method confusion" {
  let fuzz = AdversarialFuzzer::new(0x4d455448L)
  let routes : Array[(@httpx.Method, String)] = [
    (Get, "/health"),
    (Get, "/status"),
    (Get, "/stats"),
    (Get, "/metrics"),
    (Get, "/suite/manifest"),
    (Get, "/suite/status"),
    (Get, "/suite/moonclaw-providers"),
    (Post, "/v1/messages"),
    (Post, "/v1/chat/completions"),
    (Post, "/v1/responses"),
    (Post, "/v1/responses/compact"),
    (Post, "/openclaw/v1/chat/completions"),
    (Post, "/openclaw/v1/responses"),
    (Post, "/claude-desktop/v1/messages"),
    (Get, "/v1/models"),
    (Get, "/openclaw/v1/models"),
    (Get, "/claude-desktop/v1/models"),
  ]
  let methods : Array[@httpx.Method] = [
    Get,
    Head,
    Post,
    Put,
    Delete,
    Connect,
    Options,
    Trace,
    Patch,
  ]
  for iteration in 0..<5_000 {
    let (allowed_method, route) = routes[fuzz.next(routes.length())]
    let candidate_method = methods[fuzz.next(methods.length())]
    if candidate_method != allowed_method &&
      !moongate_route_requires_control(candidate_method, route) {
      fail(
        "seed=0x4d455448 iteration=\{iteration} method=\{candidate_method} route=\{route}",
      )
    }
  }
}

///|
test "adversarial gateway parsers reject oversized hostile inputs" {
  let oversized = "a".repeat(65_536)
  assert_true(moongate_parse_authority(oversized) is None)
  assert_false(
    moongate_origin_allowed(
      "http://127.0.0.1:15721/\{oversized}",
      "127.0.0.1",
      15721,
    ),
  )
  assert_true(
    moongate_route_requires_control(Get, "/assets/\{oversized}%2e%2e"),
  )
}
