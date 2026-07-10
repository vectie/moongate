///|
test "gateway security accepts local SDK requests without origin" {
  assert_true(
    moonstat_request_authority_allowed(
      { "host": "127.0.0.1:15721" },
      "127.0.0.1",
      15721,
    ),
  )
  assert_true(
    moonstat_request_authority_allowed(
      { "host": "localhost:15721" },
      "127.0.0.1",
      15721,
    ),
  )
}

///|
test "gateway security accepts same-origin dashboard requests" {
  assert_true(
    moonstat_request_authority_allowed(
      { "host": "127.0.0.1:15721", "origin": "http://127.0.0.1:15721" },
      "127.0.0.1",
      15721,
    ),
  )
}

///|
test "gateway security rejects DNS rebinding and cross-origin browsers" {
  assert_false(
    moonstat_request_authority_allowed(
      { "host": "attacker.example:15721" },
      "127.0.0.1",
      15721,
    ),
  )
  assert_false(
    moonstat_request_authority_allowed(
      { "host": "127.0.0.1:15721", "origin": "https://attacker.example" },
      "127.0.0.1",
      15721,
    ),
  )
  assert_false(
    moonstat_request_authority_allowed(
      { "host": "127.0.0.1:15722" },
      "127.0.0.1",
      15721,
    ),
  )
  assert_false(
    moonstat_request_authority_allowed(
      { "host": "127.0.0.1:15721", "origin": "null" },
      "127.0.0.1",
      15721,
    ),
  )
}

///|
test "gateway security supports explicit non-loopback bind authority" {
  assert_true(
    moonstat_request_authority_allowed(
      { "host": "192.168.1.20:15721", "origin": "http://192.168.1.20:15721" },
      "192.168.1.20",
      15721,
    ),
  )
}
