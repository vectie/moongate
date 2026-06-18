///|
test "moonstat codex chat history restores tool output from previous response" {
  let history = CodexChatHistoryStore::new()
  ignore(
    history.record_response(
      Json::object({
        "id": Json::string("resp_1"),
        "output": Json::array([
          Json::object({
            "type": Json::string("function_call"),
            "call_id": Json::string("call_1"),
            "name": Json::string("read_file"),
            "arguments": Json::string("{\"path\":\"README.md\"}"),
            "reasoning_content": Json::string("Need to inspect the file."),
          }),
        ]),
      }),
    ),
  )
  let request = Json::object({
    "previous_response_id": Json::string("resp_1"),
    "input": Json::array([
      Json::object({
        "type": Json::string("function_call_output"),
        "call_id": Json::string("call_1"),
        "output": Json::string("ok"),
      }),
    ]),
  })
  assert_eq(history.enrich_request_in_place(request), 1)
  guard request is Object(obj) else { fail("expected request object") }
  guard obj["input"] is Array(input) else { fail("expected input array") }
  assert_eq(input.length(), 2)
  guard input[0] is Object(call) else { fail("expected restored call") }
  assert_eq(call["type"], Json::string("function_call"))
  assert_eq(
    call["reasoning_content"],
    Json::string("Need to inspect the file."),
  )
  guard input[1] is Object(output) else { fail("expected output") }
  assert_eq(output["type"], Json::string("function_call_output"))
}

///|
test "moonstat codex chat history restores unique call id without matching previous response" {
  let history = CodexChatHistoryStore::new()
  ignore(
    history.record_response(
      Json::object({
        "id": Json::string("resp_1"),
        "output": Json::array([
          Json::object({
            "type": Json::string("function_call"),
            "call_id": Json::string("call_1"),
            "name": Json::string("read_file"),
            "arguments": Json::string("{}"),
            "reasoning_content": Json::string("This is the only cached call."),
          }),
        ]),
      }),
    ),
  )
  let missing_previous = Json::object({
    "input": Json::array([
      Json::object({
        "type": Json::string("function_call_output"),
        "call_id": Json::string("call_1"),
        "output": Json::string("ok"),
      }),
    ]),
  })
  assert_eq(history.enrich_request_in_place(missing_previous), 1)
  guard missing_previous is Object(missing_obj) else { fail("expected object") }
  guard missing_obj["input"] is Array(missing_input) else {
    fail("expected array")
  }
  guard missing_input[0] is Object(restored) else { fail("expected restored") }
  assert_eq(
    restored["reasoning_content"],
    Json::string("This is the only cached call."),
  )
  let different_previous = Json::object({
    "previous_response_id": Json::string("resp_2"),
    "input": Json::array([
      Json::object({
        "type": Json::string("function_call_output"),
        "call_id": Json::string("call_1"),
        "output": Json::string("ok"),
      }),
    ]),
  })
  assert_eq(history.enrich_request_in_place(different_previous), 1)
}

///|
test "moonstat codex chat history does not restore ambiguous call id without previous response" {
  let history = CodexChatHistoryStore::new()
  for
    pair in [
      ("resp_1", "This belongs to the first response."),
      ("resp_2", "This belongs to the second response."),
    ] {
    ignore(
      history.record_response(
        Json::object({
          "id": Json::string(pair.0),
          "output": Json::array([
            Json::object({
              "type": Json::string("function_call"),
              "call_id": Json::string("call_1"),
              "name": Json::string("read_file"),
              "arguments": Json::string("{}"),
              "reasoning_content": Json::string(pair.1),
            }),
          ]),
        }),
      ),
    )
  }
  let request = Json::object({
    "input": Json::array([
      Json::object({
        "type": Json::string("function_call_output"),
        "call_id": Json::string("call_1"),
        "output": Json::string("ok"),
      }),
    ]),
  })
  assert_eq(history.enrich_request_in_place(request), 0)
  guard request is Object(obj) else { fail("expected object") }
  guard obj["input"] is Array(input) else { fail("expected array") }
  guard input[0] is Object(output) else { fail("expected output") }
  assert_eq(output["type"], Json::string("function_call_output"))
}

///|
test "moonstat codex chat history enriches existing function call reasoning" {
  let history = CodexChatHistoryStore::new()
  ignore(
    history.record_response(
      Json::object({
        "id": Json::string("resp_1"),
        "output": Json::array([
          Json::object({
            "type": Json::string("function_call"),
            "call_id": Json::string("call_1"),
            "name": Json::string("read_file"),
            "arguments": Json::string("{}"),
            "reasoning_content": Json::string("Need to inspect the file."),
          }),
        ]),
      }),
    ),
  )
  let request = Json::object({
    "previous_response_id": Json::string("resp_1"),
    "input": Json::array([
      Json::object({
        "type": Json::string("function_call"),
        "call_id": Json::string("call_1"),
        "name": Json::string("read_file"),
        "arguments": Json::string("{}"),
      }),
      Json::object({
        "type": Json::string("function_call_output"),
        "call_id": Json::string("call_1"),
        "output": Json::string("ok"),
      }),
    ]),
  })
  assert_eq(history.enrich_request_in_place(request), 1)
  guard request is Object(obj) else { fail("expected object") }
  guard obj["input"] is Array(input) else { fail("expected array") }
  guard input[0] is Object(call) else { fail("expected call") }
  assert_eq(
    call["reasoning_content"],
    Json::string("Need to inspect the file."),
  )
  assert_eq(input.length(), 2)
}

///|
test "moonstat codex chat history restores parallel calls as one assistant group" {
  let history = CodexChatHistoryStore::new()
  ignore(
    history.record_response(
      Json::object({
        "id": Json::string("resp_1"),
        "output": Json::array([
          Json::object({
            "type": Json::string("function_call"),
            "call_id": Json::string("call_1"),
            "name": Json::string("first"),
            "arguments": Json::string("{}"),
            "reasoning_content": Json::string("Need both tools."),
          }),
          Json::object({
            "type": Json::string("function_call"),
            "call_id": Json::string("call_2"),
            "name": Json::string("second"),
            "arguments": Json::string("{}"),
            "reasoning_content": Json::string("Need both tools."),
          }),
        ]),
      }),
    ),
  )
  let request = Json::object({
    "previous_response_id": Json::string("resp_1"),
    "input": Json::array([
      Json::object({
        "type": Json::string("function_call_output"),
        "call_id": Json::string("call_1"),
        "output": Json::string("one"),
      }),
      Json::object({
        "type": Json::string("function_call_output"),
        "call_id": Json::string("call_2"),
        "output": Json::string("two"),
      }),
    ]),
  })
  assert_eq(history.enrich_request_in_place(request), 2)
  guard request is Object(obj) else { fail("expected object") }
  guard obj["input"] is Array(input) else { fail("expected array") }
  assert_eq(input.length(), 4)
  guard input[0] is Object(first) else { fail("expected first call") }
  guard input[1] is Object(second) else { fail("expected second call") }
  assert_eq(first["call_id"], Json::string("call_1"))
  assert_eq(second["call_id"], Json::string("call_2"))
}

///|
test "moonstat codex chat history restores custom and tool search calls" {
  let history = CodexChatHistoryStore::new()
  ignore(
    history.record_response(
      Json::object({
        "id": Json::string("resp_1"),
        "output": Json::array([
          Json::object({
            "type": Json::string("custom_tool_call"),
            "call_id": Json::string("call_patch"),
            "name": Json::string("apply_patch"),
            "input": Json::string("*** Begin Patch\n*** End Patch"),
            "reasoning_content": Json::string("Need to patch the file."),
          }),
          Json::object({
            "type": Json::string("tool_search_call"),
            "call_id": Json::string("call_search"),
            "status": Json::string("completed"),
            "execution": Json::string("client"),
            "arguments": Json::object({ "query": Json::string("Gmail tools") }),
            "reasoning_content": Json::string("Need to discover tools."),
          }),
        ]),
      }),
    ),
  )
  let request = Json::object({
    "previous_response_id": Json::string("resp_1"),
    "input": Json::array([
      Json::object({
        "type": Json::string("custom_tool_call_output"),
        "call_id": Json::string("call_patch"),
        "output": Json::string("patched"),
      }),
      Json::object({
        "type": Json::string("tool_search_output"),
        "call_id": Json::string("call_search"),
        "tools": Json::array([]),
      }),
    ]),
  })
  assert_eq(history.enrich_request_in_place(request), 2)
  guard request is Object(obj) else { fail("expected object") }
  guard obj["input"] is Array(input) else { fail("expected array") }
  guard input[0] is Object(custom_call) else { fail("expected custom call") }
  guard input[1] is Object(search_call) else { fail("expected search call") }
  assert_eq(custom_call["type"], Json::string("custom_tool_call"))
  assert_eq(search_call["type"], Json::string("tool_search_call"))
}

///|
test "moonstat codex chat history records streamed function call done items" {
  let history = CodexChatHistoryStore::new()
  ignore(
    history.record_stream_events([
      Json::object({
        "type": Json::string("response.created"),
        "response": Json::object({ "id": Json::string("resp_stream") }),
      }),
      Json::object({
        "type": Json::string("response.output_item.done"),
        "item": Json::object({
          "type": Json::string("function_call"),
          "call_id": Json::string("call_1"),
          "name": Json::string("read_file"),
          "arguments": Json::string("{}"),
          "reasoning_content": Json::string("Need a file."),
        }),
      }),
    ]),
  )
  let request = Json::object({
    "previous_response_id": Json::string("resp_stream"),
    "input": Json::array([
      Json::object({
        "type": Json::string("function_call_output"),
        "call_id": Json::string("call_1"),
        "output": Json::string("ok"),
      }),
    ]),
  })
  assert_eq(history.enrich_request_in_place(request), 1)
  guard request is Object(obj) else { fail("expected object") }
  guard obj["input"] is Array(input) else { fail("expected array") }
  guard input[0] is Object(restored) else { fail("expected restored") }
  assert_eq(restored["reasoning_content"], Json::string("Need a file."))
}
