///|
test "curl GET preserves encoded query and duplicate headers" {
  let result = @curl_import.to_http(
    "curl 'https://example.invalid/v1/models?q=a%20b&tag=x' -H 'X-Trace: one' -H 'X-Trace: two'",
  )
  assert_true(
    result.contains("GET https://example.invalid/v1/models?q=a%20b&tag=x\n"),
  )
  assert_true(result.contains("X-Trace: one\nX-Trace: two\n"))
  assert_true(!result.contains("Content-Type:"))
}

///|
test "curl JSON imports body and replaces credentials" {
  let result = @curl_import.to_http(
    "curl https://example.invalid/chat --json '{\"model\":\"small\"}' -H 'Authorization: Bearer planted-secret' -H 'Cookie: session=planted-cookie' -H 'X-Api-Key: planted-key'",
  )
  assert_true(result.contains("POST https://example.invalid/chat"))
  assert_true(
    result.contains(
      "Content-Type: application/json\nAccept: application/json\n\n{\"model\":\"small\"}\n",
    ),
  )
  assert_true(result.contains("Authorization: {{credential_1}}"))
  assert_true(result.contains("Cookie: {{credential_2}}"))
  assert_true(result.contains("X-Api-Key: {{credential_3}}"))
  assert_true(!result.contains("planted-"))
}

///|
test "curl literal quoting and continuations preserve body" {
  let result = @curl_import.to_http(
    "curl \\\n'https://example.invalid' --data-raw 'one'\"'\"'s $literal' -X PATCH",
  )
  assert_true(result.contains("PATCH https://example.invalid\n"))
  assert_true(result.contains("\none's $literal\n"))
  assert_true(
    result.contains("Content-Type: application/x-www-form-urlencoded"),
  )
  let escaped = @curl_import.to_http(
    "curl https://example.invalid --data-raw \"a\\q\\\"b\"",
  )
  assert_true(escaped.contains("\na\\q\"b\n"))
}

///|
test "curl explicit headers suppress JSON defaults" {
  let result = @curl_import.to_http(
    "curl --url https://example.invalid --json '{}' -H 'content-type: application/custom' -H 'ACCEPT: text/plain'",
  )
  assert_true(!result.contains("application/json"))
  assert_true(result.contains("content-type: application/custom"))
  assert_true(result.contains("ACCEPT: text/plain"))
}

///|
test "curl supports HEAD and empty literal body" {
  assert_true(
    @curl_import.to_http("curl -sS --compressed -I https://example.invalid").contains(
      "HEAD https://example.invalid",
    ),
  )
  assert_true(
    @curl_import.to_http("curl https://example.invalid -d ''").contains(
      "POST https://example.invalid",
    ),
  )
  assert_true(
    @curl_import.to_http("curl https://example.invalid --data-raw '@literal'").contains(
      "\n@literal\n",
    ),
  )
}

///|
test "curl unsupported commands fail closed" {
  for
    command in [
      "wget https://example.invalid", "curl", "curl https://a.invalid https://b.invalid",
      "curl https://example.invalid -L", "curl https://example.invalid -F x=y", "curl https://example.invalid --data @private",
      "curl https://example.invalid --json @private", "curl https://example.invalid --data-binary @private",
      "curl https://example.invalid -u user:pass", "curl https://example.invalid --data x --data y",
      "curl https://example.invalid -H", "curl https://example.invalid -H 'X-Empty:'",
      "curl file:///tmp/private", "curl https://user:pass@example.invalid", "curl https://",
      "curl https://example.invalid -X 'GET extra'", "curl https://example.invalid -X GET -X POST",
      "curl https://example.invalid -I -d body", "curl https://example.invalid -d body -I",
      "curl https://example.invalid --data 'multi\nline'", "curl https://example.invalid -H 'X-Test: one\nInjected: two'",
    ] {
    try @curl_import.to_http(command) catch {
      _ => ()
    } noraise {
      _ => fail("expected rejection")
    }
  }
}

///|
test "curl never interprets shell syntax" {
  for
    command in [
      "curl $URL", "curl \"https://example.invalid/$PATH\"", "curl `command`", "curl https://example.invalid; other",
      "curl https://example.invalid | other", "curl https://example.invalid > file",
      "curl https://example.invalid && other", "curl https://example.invalid # comment",
      "curl 'unfinished", "curl trailing\\",
    ] {
    try @curl_import.to_http(command) catch {
      _ => ()
    } noraise {
      _ => fail("expected rejection")
    }
  }
}

///|
test "curl import deterministic and bounded" {
  let command = "curl https://example.invalid --data-binary 'text'"
  assert_eq(@curl_import.to_http(command), @curl_import.to_http(command))
  let long = StringBuilder()
  for _ in 0..<1048577 {
    long.write_char('x')
  }
  try @curl_import.to_http(long.to_string()) catch {
    _ => ()
  } noraise {
    _ => fail("expected size rejection")
  }
}

///|
test "curl URL globbing fails while IPv6 authority remains usable" {
  for
    command in [
      "curl 'https://example.test/{one,two}'", "curl 'https://example.test/items/[1-3]'",
      "curl 'https://[one,two].example.test/'", "curl 'https://example.test/?page=[1-3]'",
      "curl 'https://[::1]/items/[1-3]'", "curl 'https://[::1][1-3]/'",
    ] {
    try @curl_import.to_http(command) catch {
      _ => ()
    } noraise {
      _ => fail("expected URL glob rejection")
    }
  }
  assert_true(
    @curl_import.to_http("curl 'http://[::1]:8080/v1/models'").contains(
      "GET http://[::1]:8080/v1/models\n",
    ),
  )
  assert_true(
    @curl_import.to_http("curl 'https://[2001:db8::1]/'").contains(
      "GET https://[2001:db8::1]/\n",
    ),
  )
}
