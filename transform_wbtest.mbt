///|
test "moongate openai chat streaming injects include usage" {
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
test "moongate openai chat non streaming omits stream options" {
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
test "moongate responses transform uses session cache key" {
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
test "moongate transform strips leading anthropic billing header like moongate" {
  assert_eq(
    strip_leading_anthropic_billing_header(
      "x-anthropic-billing-header: cc_version=2.1; cch=a;\r\n\r\n  You are terse.  ",
    ),
    "  You are terse.  ",
  )
  assert_eq(
    strip_leading_anthropic_billing_header(
      "x-anthropic-billing-header: cc_version=2.1; cch=a;\rYou are terse.",
    ),
    "You are terse.",
  )
  assert_eq(
    strip_leading_anthropic_billing_header(
      "Keep this literal:\nx-anthropic-billing-header: cc_version=2.1",
    ),
    "Keep this literal:\nx-anthropic-billing-header: cc_version=2.1",
  )
  assert_eq(
    strip_leading_anthropic_billing_header(
      "x-anthropic-billing-header: cc_version=2.1; cch=a;",
    ),
    "",
  )
}

///|
test "moongate responses output config max maps to reasoning xhigh" {
  let body = Json::object({
    "model": Json::string("gpt-5.4"),
    "messages": Json::array([
      Json::object({
        "role": Json::string("user"),
        "content": Json::string("hello"),
      }),
    ]),
    "max_tokens": Json::number(128.0),
    "output_config": Json::object({ "effort": Json::string("max") }),
  })
  let transformed = transform_claude_request_for_api_format(
    body, "openai_responses",
  )
  guard transformed is Object(obj) else { fail("expected object") }
  guard obj["reasoning"] is Object(reasoning) else {
    fail("expected reasoning")
  }
  assert_eq(reasoning["effort"], Json::string("xhigh"))
}

///|
test "moongate responses output config takes priority over thinking" {
  let body = Json::object({
    "model": Json::string("gpt-5.4"),
    "messages": Json::array([
      Json::object({
        "role": Json::string("user"),
        "content": Json::string("hello"),
      }),
    ]),
    "output_config": Json::object({ "effort": Json::string("low") }),
    "thinking": Json::object({ "type": Json::string("adaptive") }),
  })
  let transformed = transform_claude_request_for_api_format(
    body, "openai_responses",
  )
  guard transformed is Object(obj) else { fail("expected object") }
  guard obj["reasoning"] is Object(reasoning) else {
    fail("expected reasoning")
  }
  assert_eq(reasoning["effort"], Json::string("low"))
}

///|
test "moongate responses thinking budget maps to reasoning effort" {
  let low = Json::object({
    "model": Json::string("gpt-5.4"),
    "messages": Json::array([]),
    "thinking": Json::object({
      "type": Json::string("enabled"),
      "budget_tokens": Json::number(2048.0),
    }),
  })
  let medium = Json::object({
    "model": Json::string("gpt-5.4"),
    "messages": Json::array([]),
    "thinking": Json::object({
      "type": Json::string("enabled"),
      "budget_tokens": Json::number(8000.0),
    }),
  })
  let high = Json::object({
    "model": Json::string("gpt-5.4"),
    "messages": Json::array([]),
    "thinking": Json::object({
      "type": Json::string("enabled"),
      "budget_tokens": Json::number(32000.0),
    }),
  })
  guard transform_claude_request_for_api_format(low, "openai_responses")
    is Object(low_obj) else {
    fail("expected low object")
  }
  guard transform_claude_request_for_api_format(medium, "openai_responses")
    is Object(medium_obj) else {
    fail("expected medium object")
  }
  guard transform_claude_request_for_api_format(high, "openai_responses")
    is Object(high_obj) else {
    fail("expected high object")
  }
  guard low_obj["reasoning"] is Object(low_reasoning) else {
    fail("expected low reasoning")
  }
  guard medium_obj["reasoning"] is Object(medium_reasoning) else {
    fail("expected medium reasoning")
  }
  guard high_obj["reasoning"] is Object(high_reasoning) else {
    fail("expected high reasoning")
  }
  assert_eq(low_reasoning["effort"], Json::string("low"))
  assert_eq(medium_reasoning["effort"], Json::string("medium"))
  assert_eq(high_reasoning["effort"], Json::string("high"))
}

///|
test "moongate responses thinking adaptive skips non reasoning models" {
  let reasoning_body = Json::object({
    "model": Json::string("o3-mini"),
    "messages": Json::array([]),
    "thinking": Json::object({ "type": Json::string("adaptive") }),
  })
  let plain_body = Json::object({
    "model": Json::string("gpt-4o"),
    "messages": Json::array([]),
    "thinking": Json::object({ "type": Json::string("adaptive") }),
  })
  guard transform_claude_request_for_api_format(
      reasoning_body, "openai_responses",
    )
    is Object(reasoning_obj) else {
    fail("expected reasoning object")
  }
  guard reasoning_obj["reasoning"] is Object(reasoning) else {
    fail("expected reasoning")
  }
  assert_eq(reasoning["effort"], Json::string("xhigh"))
  guard transform_claude_request_for_api_format(plain_body, "openai_responses")
    is Object(plain_obj) else {
    fail("expected plain object")
  }
  assert_true(plain_obj.get("reasoning") is None)
}

///|
test "moongate codex oauth responses constraints match moongate" {
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
test "moongate codex oauth responses defaults fast mode off" {
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
    is_codex_oauth=true,
  )
  guard transformed is Object(obj) else { fail("expected object") }
  assert_true(obj.get("service_tier") is None)
  assert_true(obj.get("max_output_tokens") is None)
}

///|
test "moongate transform maps anthropic tool choice" {
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
test "moongate openai chat transform canonicalizes tool arguments" {
  let body = Json::object({
    "model": Json::string("gpt-5.4"),
    "messages": Json::array([
      Json::object({
        "role": Json::string("assistant"),
        "content": Json::array([
          Json::object({
            "type": Json::string("tool_use"),
            "id": Json::string("toolu_1"),
            "name": Json::string("lookup"),
            "input": Json::object({
              "z": Json::number(1.0),
              "a": Json::number(2.0),
            }),
          }),
        ]),
      }),
    ]),
  })
  let transformed = transform_claude_request_for_api_format(body, "openai_chat")
  guard transformed is Object(obj) else { fail("expected object") }
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(message) else { fail("expected message") }
  guard message["tool_calls"] is Array(tool_calls) else {
    fail("expected tool calls")
  }
  guard tool_calls[0] is Object(call) else { fail("expected call") }
  guard call["function"] is Object(function) else { fail("expected function") }
  assert_eq(function["arguments"], Json::string("{\"a\":2,\"z\":1}"))
}

///|
test "moongate responses transform canonicalizes tool arguments" {
  let body = Json::object({
    "model": Json::string("gpt-5.4"),
    "messages": Json::array([
      Json::object({
        "role": Json::string("assistant"),
        "content": Json::array([
          Json::object({
            "type": Json::string("tool_use"),
            "id": Json::string("toolu_1"),
            "name": Json::string("lookup"),
            "input": Json::object({
              "z": Json::number(1.0),
              "a": Json::number(2.0),
            }),
          }),
        ]),
      }),
    ]),
  })
  let transformed = transform_claude_request_for_api_format(
    body, "openai_responses",
  )
  guard transformed is Object(obj) else { fail("expected object") }
  guard obj["input"] is Array(input) else { fail("expected input") }
  guard input[0] is Object(call) else { fail("expected call") }
  assert_eq(call["arguments"], Json::string("{\"a\":2,\"z\":1}"))
}

///|
test "moongate gemini native transform maps anthropic request" {
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
test "moongate gemini native transform resolves tool result names" {
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
test "moongate gemini native transform strips synthesized tool ids" {
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

///|
test "moongate gemini native shadow replay preserves thought signature by id" {
  let shadow_turns = [
    {
      assistant_content: Json::object({
        "parts": Json::array([
          Json::object({
            "functionCall": Json::object({
              "id": Json::string("call_1"),
              "name": Json::string("Bash"),
              "args": Json::object({ "command": Json::string("ls -R") }),
            }),
            "thoughtSignature": Json::string("sig-tool-1"),
          }),
        ]),
      }),
      tool_calls: [
        {
          id: Some("call_1"),
          name: "Bash",
          thought_signature: Some("sig-tool-1"),
        },
      ],
    },
  ]
  let body = Json::object({
    "messages": Json::array([
      Json::object({
        "role": Json::string("assistant"),
        "content": Json::array([
          Json::object({
            "type": Json::string("tool_use"),
            "id": Json::string("call_1"),
            "name": Json::string("default_api:Bash"),
            "input": Json::object({ "command": Json::string("ls -R") }),
          }),
        ]),
      }),
      Json::object({
        "role": Json::string("user"),
        "content": Json::array([
          Json::object({
            "type": Json::string("tool_result"),
            "tool_use_id": Json::string("call_1"),
            "content": Json::string("ok"),
          }),
        ]),
      }),
    ]),
  })
  let transformed = transform_claude_request_for_api_format(
    body,
    "gemini_native",
    gemini_shadow_turns=shadow_turns,
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
  assert_eq(function_call["id"], Json::string("call_1"))
  assert_eq(function_call["name"], Json::string("Bash"))
  assert_eq(model_part["thoughtSignature"], Json::string("sig-tool-1"))
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
  assert_eq(function_response["name"], Json::string("Bash"))
}

///|
test "moongate gemini native shadow replay prefers exact id over name collision" {
  let shadow_turns = [
    {
      assistant_content: Json::object({
        "parts": Json::array([
          Json::object({
            "functionCall": Json::object({
              "id": Json::string("call_a"),
              "name": Json::string("server_a:search"),
              "args": Json::object({ "q": Json::string("alpha") }),
            }),
            "thoughtSignature": Json::string("sig-a"),
          }),
        ]),
      }),
      tool_calls: [
        {
          id: Some("call_a"),
          name: "server_a:search",
          thought_signature: Some("sig-a"),
        },
      ],
    },
    {
      assistant_content: Json::object({
        "parts": Json::array([
          Json::object({
            "functionCall": Json::object({
              "id": Json::string("call_b"),
              "name": Json::string("server_b:search"),
              "args": Json::object({ "q": Json::string("beta") }),
            }),
            "thoughtSignature": Json::string("sig-b"),
          }),
        ]),
      }),
      tool_calls: [
        {
          id: Some("call_b"),
          name: "server_b:search",
          thought_signature: Some("sig-b"),
        },
      ],
    },
  ]
  let body = Json::object({
    "messages": Json::array([
      Json::object({
        "role": Json::string("assistant"),
        "content": Json::array([
          Json::object({
            "type": Json::string("tool_use"),
            "id": Json::string("call_b"),
            "name": Json::string("server_b:search"),
            "input": Json::object({ "q": Json::string("beta") }),
          }),
        ]),
      }),
      Json::object({
        "role": Json::string("assistant"),
        "content": Json::array([
          Json::object({
            "type": Json::string("tool_use"),
            "id": Json::string("call_a"),
            "name": Json::string("server_a:search"),
            "input": Json::object({ "q": Json::string("alpha") }),
          }),
        ]),
      }),
    ]),
  })
  let transformed = transform_claude_request_for_api_format(
    body,
    "gemini_native",
    gemini_shadow_turns=shadow_turns,
  )
  guard transformed is Object(obj) else { fail("expected object") }
  guard obj["contents"] is Array(contents) else { fail("expected contents") }
  guard contents[0] is Object(first_message) else {
    fail("expected first message")
  }
  guard first_message["parts"] is Array(first_parts) else {
    fail("expected first parts")
  }
  guard first_parts[0] is Object(first_part) else {
    fail("expected first part")
  }
  guard first_part["functionCall"] is Object(first_call) else {
    fail("expected first functionCall")
  }
  assert_eq(first_call["name"], Json::string("server_b:search"))
  assert_eq(first_part["thoughtSignature"], Json::string("sig-b"))
  guard contents[1] is Object(second_message) else {
    fail("expected second message")
  }
  guard second_message["parts"] is Array(second_parts) else {
    fail("expected second parts")
  }
  guard second_parts[0] is Object(second_part) else {
    fail("expected second part")
  }
  guard second_part["functionCall"] is Object(second_call) else {
    fail("expected second functionCall")
  }
  assert_eq(second_call["name"], Json::string("server_a:search"))
  assert_eq(second_part["thoughtSignature"], Json::string("sig-a"))
}

///|
test "moongate gemini native shadow store records synthetic ids and replays without leaking them" {
  let store = GeminiShadowStore::with_limits(8, 4)
  store.record_gemini_response(
    "provider-a",
    Some("session-1"),
    Json::object({
      "candidates": Json::array([
        Json::object({
          "content": Json::object({
            "parts": Json::array([
              Json::object({
                "functionCall": Json::object({
                  "name": Json::string("lookup"),
                  "args": Json::object({ "q": Json::string("moon") }),
                }),
                "thoughtSignature": Json::string("sig-lookup"),
              }),
            ]),
          }),
        }),
      ]),
    }),
  )
  let turns = store.session_turns("provider-a", Some("session-1"))
  assert_eq(turns.length(), 1)
  assert_eq(turns[0].tool_calls.length(), 1)
  assert_eq(turns[0].tool_calls[0].id, Some("gemini_synth_0"))
  let body = Json::object({
    "messages": Json::array([
      Json::object({
        "role": Json::string("assistant"),
        "content": Json::array([
          Json::object({
            "type": Json::string("tool_use"),
            "id": Json::string("gemini_synth_0"),
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
            "tool_use_id": Json::string("gemini_synth_0"),
            "content": Json::string("found"),
          }),
        ]),
      }),
    ]),
  })
  let transformed = transform_claude_request_for_api_format(
    body,
    "gemini_native",
    gemini_shadow_turns=turns,
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
  assert_eq(model_part["thoughtSignature"], Json::string("sig-lookup"))
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
