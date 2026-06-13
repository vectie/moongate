///|
test "ccs openai chat streaming injects include usage" {
  let body = Json::object({
    "model": Json::string("moonshotai/kimi-k2"),
    "messages": Json::array([
      Json::object({
        "role": Json::string("user"),
        "content": Json::string("hello"),
      }),
    ]),
    "max_tokens": Json::number(128.0),
    "stream": Json::boolean(true),
  })
  let transformed = transform_claude_request_for_api_format(body, "openai_chat")
  guard transformed is Object(obj) else { fail("expected object") }
  assert_eq(obj["stream"], Json::boolean(true))
  guard obj["stream_options"] is Object(stream_options) else {
    fail("expected stream options")
  }
  assert_eq(stream_options["include_usage"], Json::boolean(true))
}

///|
test "ccs openai chat non streaming omits stream options" {
  let body = Json::object({
    "model": Json::string("moonshotai/kimi-k2"),
    "messages": Json::array([
      Json::object({
        "role": Json::string("user"),
        "content": Json::string("hello"),
      }),
    ]),
    "max_tokens": Json::number(128.0),
  })
  let transformed = transform_claude_request_for_api_format(body, "openai_chat")
  guard transformed is Object(obj) else { fail("expected object") }
  assert_true(obj.get("stream_options") is None)
}

///|
test "ccs responses transform uses session cache key" {
  let body = Json::object({
    "model": Json::string("gpt-5.4"),
    "messages": Json::array([
      Json::object({
        "role": Json::string("user"),
        "content": Json::string("hello"),
      }),
    ]),
    "max_tokens": Json::number(128.0),
  })
  let transformed = transform_claude_request_for_api_format(
    body,
    "openai_responses",
    session_id=Some("session-123"),
  )
  guard transformed is Object(obj) else { fail("expected object") }
  assert_eq(obj["prompt_cache_key"], Json::string("session-123"))
  assert_true(obj.get("input") is Some(_))
  assert_eq(obj["max_output_tokens"], Json::number(128.0))
}

///|
test "ccs codex oauth responses constraints match ccs" {
  let body = Json::object({
    "model": Json::string("gpt-5.4"),
    "messages": Json::array([
      Json::object({
        "role": Json::string("user"),
        "content": Json::string("hello"),
      }),
    ]),
    "max_tokens": Json::number(128.0),
    "temperature": Json::number(0.2),
    "top_p": Json::number(0.9),
  })
  let transformed = transform_claude_request_for_api_format(
    body,
    "openai_responses",
    session_id=Some("session-123"),
    is_codex_oauth=true,
    codex_fast_mode=false,
  )
  guard transformed is Object(obj) else { fail("expected object") }
  assert_eq(obj["store"], Json::boolean(false))
  assert_eq(obj["stream"], Json::boolean(true))
  assert_eq(
    obj["include"],
    Json::array([Json::string("reasoning.encrypted_content")]),
  )
  assert_eq(obj["prompt_cache_key"], Json::string("session-123"))
  assert_true(obj.get("max_output_tokens") is None)
  assert_true(obj.get("temperature") is None)
  assert_true(obj.get("top_p") is None)
  assert_true(obj.get("service_tier") is None)
  assert_eq(obj["tools"], Json::array([]))
  assert_eq(obj["parallel_tool_calls"], Json::boolean(false))
}

///|
test "ccs transform maps anthropic tool choice" {
  let body = Json::object({
    "model": Json::string("gpt-5.4"),
    "messages": Json::array([]),
    "tool_choice": Json::object({
      "type": Json::string("tool"),
      "name": Json::string("search"),
    }),
  })
  let chat = transform_claude_request_for_api_format(body, "openai_chat")
  guard chat is Object(chat_obj) else { fail("expected object") }
  assert_eq(
    chat_obj["tool_choice"],
    Json::object({
      "type": Json::string("function"),
      "function": Json::object({ "name": Json::string("search") }),
    }),
  )
}

///|
test "ccs gemini native transform maps anthropic request" {
  let body = Json::object({
    "model": Json::string("claude-sonnet-4-6"),
    "system": Json::string("You are terse."),
    "messages": Json::array([
      Json::object({
        "role": Json::string("user"),
        "content": Json::array([
          Json::object({
            "type": Json::string("text"),
            "text": Json::string("search docs"),
          }),
          Json::object({
            "type": Json::string("image"),
            "source": Json::object({
              "type": Json::string("base64"),
              "media_type": Json::string("image/jpeg"),
              "data": Json::string("abc"),
            }),
          }),
        ]),
      }),
      Json::object({
        "role": Json::string("assistant"),
        "content": Json::array([
          Json::object({
            "type": Json::string("tool_use"),
            "id": Json::string("toolu_1"),
            "name": Json::string("lookup"),
            "input": Json::object({ "q": Json::string("moon") }),
          }),
        ]),
      }),
    ]),
    "max_tokens": Json::number(128.0),
    "temperature": Json::number(0.2),
    "top_p": Json::number(0.9),
    "stop_sequences": Json::array([Json::string("END")]),
    "tools": Json::array([
      Json::object({
        "name": Json::string("lookup"),
        "description": Json::string("Look up docs"),
        "input_schema": Json::object({
          "type": Json::string("object"),
          "properties": Json::object({}),
        }),
      }),
    ]),
    "tool_choice": Json::object({
      "type": Json::string("tool"),
      "name": Json::string("lookup"),
    }),
  })
  let transformed = transform_claude_request_for_api_format(
    body, "gemini_native",
  )
  guard transformed is Object(obj) else { fail("expected object") }
  guard obj["systemInstruction"] is Object(system) else {
    fail("expected systemInstruction")
  }
  assert_eq(
    system["parts"],
    Json::array([Json::object({ "text": Json::string("You are terse.") })]),
  )
  guard obj["contents"] is Array(contents) else { fail("expected contents") }
  guard contents[0] is Object(user) else { fail("expected user message") }
  assert_eq(user["role"], Json::string("user"))
  guard user["parts"] is Array(user_parts) else { fail("expected user parts") }
  assert_eq(
    user_parts[0],
    Json::object({ "text": Json::string("search docs") }),
  )
  assert_eq(
    user_parts[1],
    Json::object({
      "inlineData": Json::object({
        "mimeType": Json::string("image/jpeg"),
        "data": Json::string("abc"),
      }),
    }),
  )
  guard contents[1] is Object(model) else { fail("expected model message") }
  assert_eq(model["role"], Json::string("model"))
  guard model["parts"] is Array(model_parts) else {
    fail("expected model parts")
  }
  assert_eq(
    model_parts[0],
    Json::object({
      "functionCall": Json::object({
        "id": Json::string("toolu_1"),
        "name": Json::string("lookup"),
        "args": Json::object({ "q": Json::string("moon") }),
      }),
    }),
  )
  assert_eq(
    obj["generationConfig"],
    Json::object({
      "maxOutputTokens": Json::number(128.0),
      "temperature": Json::number(0.2),
      "topP": Json::number(0.9),
      "stopSequences": Json::array([Json::string("END")]),
    }),
  )
  guard obj["tools"] is Array(tools) else { fail("expected tools") }
  guard tools[0] is Object(tool) else { fail("expected tool") }
  guard tool["functionDeclarations"] is Array(declarations) else {
    fail("expected declarations")
  }
  guard declarations[0] is Object(declaration) else {
    fail("expected declaration")
  }
  assert_eq(declaration["name"], Json::string("lookup"))
  assert_eq(
    obj["toolConfig"],
    Json::object({
      "functionCallingConfig": Json::object({
        "mode": Json::string("ANY"),
        "allowedFunctionNames": Json::array([Json::string("lookup")]),
      }),
    }),
  )
}

///|
test "ccs gemini native transform resolves tool result names" {
  let body = Json::object({
    "model": Json::string("claude-sonnet-4-6"),
    "messages": Json::array([
      Json::object({
        "role": Json::string("assistant"),
        "content": Json::array([
          Json::object({
            "type": Json::string("tool_use"),
            "id": Json::string("toolu_lookup"),
            "name": Json::string("lookup"),
            "input": Json::object({ "q": Json::string("moon") }),
          }),
        ]),
      }),
      Json::object({
        "role": Json::string("user"),
        "content": Json::array([
          Json::object({
            "type": Json::string("tool_result"),
            "tool_use_id": Json::string("toolu_lookup"),
            "content": Json::string("found"),
          }),
        ]),
      }),
    ]),
  })
  let transformed = transform_claude_request_for_api_format(
    body, "gemini_native",
  )
  guard transformed is Object(obj) else { fail("expected object") }
  guard obj["contents"] is Array(contents) else { fail("expected contents") }
  guard contents[1] is Object(user_message) else {
    fail("expected user message")
  }
  guard user_message["parts"] is Array(parts) else { fail("expected parts") }
  assert_eq(
    parts[0],
    Json::object({
      "functionResponse": Json::object({
        "id": Json::string("toolu_lookup"),
        "name": Json::string("lookup"),
        "response": Json::object({ "content": Json::string("found") }),
      }),
    }),
  )
}

///|
test "ccs gemini native transform strips synthesized tool ids" {
  let synth = "gemini_synth_0"
  let body = Json::object({
    "messages": Json::array([
      Json::object({
        "role": Json::string("assistant"),
        "content": Json::array([
          Json::object({
            "type": Json::string("tool_use"),
            "id": Json::string(synth),
            "name": Json::string("lookup"),
            "input": Json::object({ "q": Json::string("moon") }),
          }),
        ]),
      }),
      Json::object({
        "role": Json::string("user"),
        "content": Json::array([
          Json::object({
            "type": Json::string("tool_result"),
            "tool_use_id": Json::string(synth),
            "content": Json::string("found"),
          }),
        ]),
      }),
    ]),
  })
  let transformed = transform_claude_request_for_api_format(
    body, "gemini_native",
  )
  guard transformed is Object(obj) else { fail("expected object") }
  guard obj["contents"] is Array(contents) else { fail("expected contents") }
  guard contents[0] is Object(model_message) else {
    fail("expected model message")
  }
  guard model_message["parts"] is Array(model_parts) else {
    fail("expected model parts")
  }
  guard model_parts[0] is Object(model_part) else {
    fail("expected model part")
  }
  guard model_part["functionCall"] is Object(function_call) else {
    fail("expected functionCall")
  }
  assert_true(function_call.get("id") is None)
  assert_eq(function_call["name"], Json::string("lookup"))
  guard contents[1] is Object(user_message) else {
    fail("expected user message")
  }
  guard user_message["parts"] is Array(user_parts) else {
    fail("expected user parts")
  }
  guard user_parts[0] is Object(user_part) else { fail("expected user part") }
  guard user_part["functionResponse"] is Object(function_response) else {
    fail("expected functionResponse")
  }
  assert_true(function_response.get("id") is None)
  assert_eq(function_response["name"], Json::string("lookup"))
}
