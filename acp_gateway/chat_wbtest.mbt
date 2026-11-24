///|
fn test_config() -> Json {
  {
    "command": "/usr/bin/env",
    "args": [],
    "cwd": "/tmp",
    "token": "local-fixture-token",
    "models": ["alpha", "beta"],
  }
}

///|
test "ACP configuration requires explicit local command credentials and limits" {
  let bridge = Bridge::from_json(test_config())
  assert_eq(bridge.max_concurrent, 4)
  assert_eq(bridge.timeout_ms, 120000)
  let invalid : Array[Json] = [
    {
      "command": "relative",
      "args": [],
      "cwd": "/tmp",
      "token": "local-fixture-token",
      "models": ["alpha"],
    },
    {
      "command": "/bin/cat",
      "args": [],
      "cwd": "/tmp",
      "token": "short",
      "models": ["alpha"],
    },
    {
      "command": "/bin/cat",
      "args": [],
      "cwd": "/tmp",
      "token": "local-fixture-token",
      "models": [],
    },
    {
      "command": "/bin/cat",
      "args": [],
      "cwd": "/tmp",
      "token": "local-fixture-token",
      "models": ["alpha"],
      "timeout_ms": 0,
    },
  ]
  for config in invalid {
    try Bridge::from_json(config) catch {
      BridgeError(kind="invalid_acp_config", ..) => ()
      error => raise error
    } noraise {
      _ => fail("invalid configuration accepted")
    }
  }
}

///|
test "ACP text requests retain conversation roles as quoted transcript and reject unsupported semantics" {
  let single = parse_chat(
    { "model": "alpha", "messages": [{ "role": "user", "content": "hello" }] },
    ["alpha"],
  )
  assert_eq(single.prompt, "hello")
  assert_false(single.stream)
  let transcript = parse_chat(
    {
      "model": "alpha",
      "stream": true,
      "messages": [
        { "role": "system", "content": "be brief" },
        { "role": "user", "content": [{ "type": "text", "text": "hello" }] },
      ],
    },
    ["alpha"],
  )
  assert_true(transcript.stream)
  assert_true(transcript.prompt.contains("\"role\":\"system\""))
  let invalid : Array[Json] = [
    { "model": "alpha", "messages": [] },
    {
      "model": "alpha",
      "stream": "true",
      "messages": [{ "role": "user", "content": "hello" }],
    },
    {
      "model": "alpha",
      "tools": [],
      "messages": [{ "role": "user", "content": "hello" }],
    },
    {
      "model": "alpha",
      "temperature": 0.3,
      "messages": [{ "role": "user", "content": "hello" }],
    },
    {
      "model": "alpha",
      "messages": [{ "role": "assistant", "content": "hello" }],
    },
    { "model": "alpha", "messages": [{ "role": "tool", "content": "hello" }] },
    {
      "model": "alpha",
      "messages": [
        {
          "role": "user",
          "content": [{ "type": "image_url", "image_url": { "url": "test" } }],
        },
      ],
    },
  ]
  for body in invalid {
    try parse_chat(body, ["alpha"]) catch {
      BridgeError(kind="unsupported_chat_request", ..) => ()
      error => raise error
    } noraise {
      _ => fail("unsupported request accepted")
    }
  }
}

///|
async test "ACP framing handles split UTF8 and combined frames and bounds unterminated lines" {
  let raw = @utf8.encode("{\"text\":\"你好\"}\n{\"result\":true}\n")
  let reader = @io.MemoryReader(writer => {
    for byte in raw {
      writer.write(Bytes::from_array([byte]))
    }
  })
  defer reader.close()
  let frames : Frames = { reader, pending: b"", offset: 0, }
  assert_true(frames.next() is { "text": "你好", .. })
  assert_true(frames.next() is { "result": true, .. })
  let too_large = @io.MemoryReader(writer => {
    writer.write(Bytes::make(1048577, b'a'))
  })
  defer too_large.close()
  let frames : Frames = { reader: too_large, pending: b"", offset: 0, }
  try frames.next() catch {
    BridgeError(kind="acp_protocol_error", ..) => ()
    error => raise error
  } noraise {
    _ => fail("oversized ACP frame accepted")
  }
}

///|
test "ACP grouped model options retain exact identifiers" {
  assert_true(
    option_has_model(
      [
        {
          "group": "test",
          "options": [{ "value": "alpha" }, { "value": "beta" }],
        },
      ],
      "beta",
    ),
  )
  assert_false(option_has_model([{ "value": "alpha" }], "beta"))
}
