///|
fn chat_parse_json_for_test(body : String) -> Json {
  @json.parse(body) catch {
    _ => Json::null()
  }
}

///|
test "chat completions request converts to codex responses request" {
  let body = chat_parse_json_for_test(
    (
      #|{
      #|  "model": "client-model",
      #|  "stream": false,
      #|  "messages": [
      #|    { "role": "system", "content": "be concise" },
      #|    { "role": "user", "content": "hi" }
      #|  ],
      #|  "tools": [
      #|    {
      #|      "type": "function",
      #|      "function": {
      #|        "name": "lookup",
      #|        "description": "lookup value",
      #|        "parameters": { "type": "object" }
      #|      }
      #|    }
      #|  ],
      #|  "max_completion_tokens": 123
      #|}
    ),
  )
  let request = openai_chat_to_codex_response_request(body, "gpt-5").unwrap()
  guard request is Object(obj) else { fail("expected object") }
  assert_eq(obj["model"], Json::string("gpt-5"))
  assert_eq(obj["instructions"], Json::string("be concise"))
  assert_eq(obj["max_output_tokens"], Json::number(123.0))
  guard obj["input"] is Array(input) else { fail("expected input") }
  assert_eq(input.length(), 1)
  guard input[0] is Object(first) else { fail("expected message") }
  assert_eq(first["role"], Json::string("user"))
  assert_eq(first["content"], Json::string("hi"))
  guard obj["tools"] is Array(tools) else { fail("expected tools") }
  guard tools[0] is Object(tool) else { fail("expected tool") }
  assert_eq(tool["name"], Json::string("lookup"))
}

///|
test "chat completions request canonicalizes function arguments" {
  let body = chat_parse_json_for_test(
    (
      #|{
      #|  "model": "client-model",
      #|  "messages": [{
      #|    "role": "assistant",
      #|    "tool_calls": [{
      #|      "id": "call_1",
      #|      "type": "function",
      #|      "function": {
      #|        "name": "lookup",
      #|        "arguments": "{ \"z\": 1, \"a\": 2 }"
      #|      }
      #|    }]
      #|  }, {
      #|    "role": "assistant",
      #|    "tool_calls": [{
      #|      "id": "call_2",
      #|      "type": "function",
      #|      "function": {
      #|        "name": "empty",
      #|        "arguments": "  "
      #|      }
      #|    }]
      #|  }]
      #|}
    ),
  )
  let request = openai_chat_to_codex_response_request(body, "gpt-5").unwrap()
  guard request is Object(obj) else { fail("expected object") }
  guard obj["input"] is Array(input) else { fail("expected input") }
  guard input[0] is Object(first) else { fail("expected first") }
  guard input[1] is Object(second) else { fail("expected second") }
  assert_eq(first["arguments"], Json::string("{\"a\":2,\"z\":1}"))
  assert_eq(second["arguments"], Json::string("{}"))
}

///|
test "codex response converts to chat completion response" {
  let body = chat_parse_json_for_test(
    (
      #|{
      #|  "id": "resp_1",
      #|  "output": [
      #|    {
      #|      "type": "message",
      #|      "content": [
      #|        { "type": "output_text", "text": "hello" }
      #|      ]
      #|    }
      #|  ],
      #|  "usage": {
      #|    "input_tokens": 2,
      #|    "output_tokens": 3,
      #|    "input_tokens_details": { "cached_tokens": 1 }
      #|  }
      #|}
    ),
  )
  let response = codex_response_to_openai_chat_completion(body, "client-model")
  guard response is Object(obj) else { fail("expected object") }
  assert_eq(obj["id"], Json::string("resp_1"))
  assert_eq(obj["object"], Json::string("chat.completion"))
  assert_eq(obj["model"], Json::string("client-model"))
  guard obj["choices"] is Array(choices) else { fail("expected choices") }
  guard choices[0] is Object(choice) else { fail("expected choice") }
  guard choice["message"] is Object(message) else { fail("expected message") }
  assert_eq(message["role"], Json::string("assistant"))
  assert_eq(message["content"], Json::string("hello"))
  guard obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["prompt_tokens"], Json::number(2.0))
  assert_eq(usage["completion_tokens"], Json::number(3.0))
  assert_eq(usage["total_tokens"], Json::number(5.0))
}

///|
test "codex responses request converts to chat completion request" {
  let body = chat_parse_json_for_test(
    (
      #|{
      #|  "model": "gpt-5",
      #|  "instructions": "be concise",
      #|  "max_output_tokens": 99,
      #|  "input": [
      #|    { "role": "user", "content": "read it" },
      #|    {
      #|      "type": "function_call",
      #|      "call_id": "call_1",
      #|      "name": "read_file",
      #|      "arguments": "{\"path\":\"README.md\"}",
      #|      "reasoning_content": "Need to inspect the file."
      #|    },
      #|    {
      #|      "type": "function_call_output",
      #|      "call_id": "call_1",
      #|      "output": "ok"
      #|    }
      #|  ],
      #|  "tools": [
      #|    { "type": "function", "name": "read_file", "parameters": { "type": "object" } }
      #|  ]
      #|}
    ),
  )
  let chat = codex_responses_request_to_openai_chat_completion(
    body, "fallback-model",
  ).unwrap()
  guard chat is Object(obj) else { fail("expected object") }
  assert_eq(obj["model"], Json::string("gpt-5"))
  assert_eq(obj["max_tokens"], Json::number(99.0))
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  assert_eq(messages.length(), 4)
  guard messages[0] is Object(system) else { fail("expected system") }
  assert_eq(system["role"], Json::string("system"))
  guard messages[2] is Object(assistant) else { fail("expected assistant") }
  guard assistant["tool_calls"] is Array(tool_calls) else {
    fail("expected tool calls")
  }
  guard tool_calls[0] is Object(tool_call) else { fail("expected tool call") }
  assert_eq(tool_call["id"], Json::string("call_1"))
  guard tool_call["function"] is Object(function) else {
    fail("expected function")
  }
  assert_eq(function["name"], Json::string("read_file"))
  assert_eq(function["arguments"], Json::string("{\"path\":\"README.md\"}"))
  guard messages[3] is Object(tool_message) else { fail("expected tool") }
  assert_eq(tool_message["role"], Json::string("tool"))
  assert_eq(tool_message["tool_call_id"], Json::string("call_1"))
  guard obj["tools"] is Array(tools) else { fail("expected tools") }
  guard tools[0] is Object(tool) else { fail("expected tool") }
  guard tool["function"] is Object(tool_function) else {
    fail("expected tool function")
  }
  assert_eq(tool_function["name"], Json::string("read_file"))
}

///|
test "codex responses custom and tool search calls convert to chat tools" {
  let body = chat_parse_json_for_test(
    (
      #|{
      #|  "model": "gpt-5",
      #|  "input": [
      #|    {
      #|      "type": "custom_tool_call",
      #|      "call_id": "call_custom",
      #|      "name": "apply_patch",
      #|      "input": "*** Begin Patch"
      #|    },
      #|    {
      #|      "type": "tool_search_call",
      #|      "call_id": "call_search",
      #|      "arguments": { "query": "browser", "limit": 3 }
      #|    },
      #|    {
      #|      "type": "custom_tool_call_output",
      #|      "call_id": "call_custom",
      #|      "output": "ok"
      #|    },
      #|    {
      #|      "type": "tool_search_output",
      #|      "call_id": "call_search",
      #|      "tools": [{ "type": "custom", "name": "loaded_tool" }]
      #|    }
      #|  ],
      #|  "tools": [
      #|    { "type": "custom", "name": "apply_patch" },
      #|    { "type": "tool_search" }
      #|  ]
      #|}
    ),
  )
  let chat = codex_responses_request_to_openai_chat_completion(
    body, "fallback-model",
  ).unwrap()
  guard chat is Object(obj) else { fail("expected object") }
  guard obj["tools"] is Array(tools) else { fail("expected tools") }
  guard tools[0] is Object(custom_tool) else { fail("expected custom tool") }
  guard custom_tool["function"] is Object(custom_fn) else {
    fail("expected custom function")
  }
  assert_eq(custom_fn["name"], Json::string("apply_patch"))
  guard custom_fn["parameters"] is Object(parameters) else {
    fail("expected params")
  }
  guard parameters["properties"] is Object(properties) else {
    fail("expected properties")
  }
  assert_true(properties.get("input") is Some(Object(_)))
  guard tools[1] is Object(search_tool) else { fail("expected search tool") }
  guard search_tool["function"] is Object(search_fn) else {
    fail("expected search function")
  }
  assert_eq(search_fn["name"], Json::string("tool_search"))
  guard obj["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(assistant) else { fail("expected assistant") }
  guard assistant["tool_calls"] is Array(tool_calls) else {
    fail("expected tool calls")
  }
  guard tool_calls[0] is Object(custom_call) else {
    fail("expected custom call")
  }
  guard custom_call["function"] is Object(custom_call_fn) else {
    fail("expected custom call function")
  }
  assert_eq(custom_call_fn["name"], Json::string("apply_patch"))
  assert_eq(
    custom_call_fn["arguments"],
    Json::string("{\"input\":\"*** Begin Patch\"}"),
  )
  guard tool_calls[1] is Object(search_call) else {
    fail("expected search call")
  }
  guard search_call["function"] is Object(search_call_fn) else {
    fail("expected search call function")
  }
  assert_eq(search_call_fn["name"], Json::string("tool_search"))
  assert_eq(
    search_call_fn["arguments"],
    Json::string("{\"limit\":3,\"query\":\"browser\"}"),
  )
  guard messages[1] is Object(custom_output) else {
    fail("expected custom output")
  }
  assert_eq(custom_output["role"], Json::string("tool"))
  assert_eq(custom_output["tool_call_id"], Json::string("call_custom"))
  guard custom_output["content"] is String(custom_content) else {
    fail("expected custom output content")
  }
  assert_true(custom_content.contains("\"type\":\"custom_tool_call_output\""))
  guard messages[2] is Object(search_output) else {
    fail("expected search output")
  }
  guard search_output["content"] is String(search_content) else {
    fail("expected search output content")
  }
  assert_true(search_content.contains("\"type\":\"tool_search_output\""))
}

///|
test "chat completion response restores custom and tool search calls with request context" {
  let request = chat_parse_json_for_test(
    (
      #|{
      #|  "model": "gpt-5",
      #|  "tools": [
      #|    { "type": "custom", "name": "apply_patch" },
      #|    { "type": "tool_search" }
      #|  ]
      #|}
    ),
  )
  let body = chat_parse_json_for_test(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "deepseek-chat",
      #|  "choices": [{
      #|    "message": {
      #|      "role": "assistant",
      #|      "content": null,
      #|      "tool_calls": [{
      #|        "id": "call_custom",
      #|        "type": "function",
      #|        "function": {
      #|          "name": "apply_patch",
      #|          "arguments": "{ \"input\": \"*** Begin Patch\" }"
      #|        }
      #|      }, {
      #|        "id": "call_search",
      #|        "type": "function",
      #|        "function": {
      #|          "name": "tool_search",
      #|          "arguments": "{ \"query\": \"browser\" }"
      #|        }
      #|      }]
      #|    },
      #|    "finish_reason": "tool_calls"
      #|  }]
      #|}
    ),
  )
  let response = openai_chat_completion_to_codex_response_with_request(
    body, "fallback", request,
  )
  guard response is Object(obj) else { fail("expected object") }
  guard obj["output"] is Array(output) else { fail("expected output") }
  guard output[0] is Object(custom_call) else { fail("expected custom call") }
  assert_eq(custom_call["type"], Json::string("custom_tool_call"))
  assert_eq(custom_call["call_id"], Json::string("call_custom"))
  assert_eq(custom_call["name"], Json::string("apply_patch"))
  assert_eq(custom_call["input"], Json::string("*** Begin Patch"))
  guard output[1] is Object(search_call) else { fail("expected search call") }
  assert_eq(search_call["type"], Json::string("tool_search_call"))
  assert_eq(search_call["call_id"], Json::string("call_search"))
  guard search_call["arguments"] is Object(arguments) else {
    fail("expected search arguments")
  }
  assert_eq(arguments["query"], Json::string("browser"))
}

///|
test "codex responses content parts convert to chat content" {
  let text_only = chat_parse_json_for_test(
    (
      #|[
      #|  { "type": "input_text", "text": "Weather?" },
      #|  { "type": "input_text", "text": "Use Celsius." }
      #|]
    ),
  )
  assert_eq(
    codex_responses_content_to_chat_content(Some(text_only)),
    Json::string("Weather?\nUse Celsius."),
  )
  let mixed = chat_parse_json_for_test(
    (
      #|[
      #|  { "type": "input_text", "text": "Summarize this." },
      #|  { "type": "input_image", "image_url": "data:image/png;base64,abc" },
      #|  { "type": "input_file", "file_id": "file_1", "filename": "a.txt" }
      #|]
    ),
  )
  let chat_content = codex_responses_content_to_chat_content(Some(mixed))
  guard chat_content is Array(parts) else { fail("expected content parts") }
  assert_eq(parts.length(), 3)
  guard parts[0] is Object(text_part) else { fail("expected text part") }
  assert_eq(text_part["type"], Json::string("text"))
  assert_eq(text_part["text"], Json::string("Summarize this."))
  guard parts[1] is Object(image_part) else { fail("expected image part") }
  assert_eq(image_part["type"], Json::string("image_url"))
  guard image_part["image_url"] is Object(image_url) else {
    fail("expected image url")
  }
  assert_eq(image_url["url"], Json::string("data:image/png;base64,abc"))
  guard parts[2] is Object(file_part) else { fail("expected file part") }
  assert_eq(file_part["type"], Json::string("file"))
  guard file_part["file"] is Object(file) else { fail("expected file") }
  assert_eq(file["file_id"], Json::string("file_1"))
  assert_eq(file["filename"], Json::string("a.txt"))
}

///|
test "chat completion response converts back to codex response" {
  let body = chat_parse_json_for_test(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "deepseek-chat",
      #|  "choices": [{
      #|    "message": {
      #|      "role": "assistant",
      #|      "content": null,
      #|      "tool_calls": [{
      #|        "id": "call_1",
      #|        "type": "function",
      #|        "function": {
      #|          "name": "lookup",
      #|          "arguments": "{ \"q\": \"moon\" }"
      #|        }
      #|      }]
      #|    },
      #|    "finish_reason": "tool_calls"
      #|  }],
      #|  "usage": {
      #|    "prompt_tokens": 10,
      #|    "completion_tokens": 5,
      #|    "prompt_tokens_details": { "cached_tokens": 3 }
      #|  }
      #|}
    ),
  )
  let response = openai_chat_completion_to_codex_response(body, "fallback")
  guard response is Object(obj) else { fail("expected object") }
  assert_eq(obj["id"], Json::string("chatcmpl_1"))
  assert_eq(obj["object"], Json::string("response"))
  assert_eq(obj["model"], Json::string("deepseek-chat"))
  guard obj["output"] is Array(output) else { fail("expected output") }
  guard output[0] is Object(call) else { fail("expected function call") }
  assert_eq(call["type"], Json::string("function_call"))
  assert_eq(call["call_id"], Json::string("call_1"))
  assert_eq(call["name"], Json::string("lookup"))
  assert_eq(call["arguments"], Json::string("{\"q\":\"moon\"}"))
  guard obj["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(10.0))
  assert_eq(usage["output_tokens"], Json::number(5.0))
  guard usage["input_tokens_details"] is Object(details) else {
    fail("expected details")
  }
  assert_eq(details["cached_tokens"], Json::number(3.0))
}

///|
test "chat completion stream converts text to codex responses events" {
  let state = ChatToCodexResponsesStreamState::new("fallback")
  let all_events : Array[Json] = []
  let (_, _, start_events) = openai_chat_stream_data_to_codex_response_events(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "deepseek-chat",
      #|  "created": 10,
      #|  "choices": [{ "delta": { "role": "assistant" }, "finish_reason": null }]
      #|}
    ),
    state,
  )
  all_events.append(start_events)
  let (_, _, text_events) = openai_chat_stream_data_to_codex_response_events(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "deepseek-chat",
      #|  "created": 10,
      #|  "choices": [{ "delta": { "content": "hi" }, "finish_reason": null }]
      #|}
    ),
    state,
  )
  all_events.append(text_events)
  let (_, _, usage_events) = openai_chat_stream_data_to_codex_response_events(
    (
      #|{
      #|  "id": "chatcmpl_1",
      #|  "model": "deepseek-chat",
      #|  "created": 10,
      #|  "choices": [],
      #|  "usage": {
      #|    "prompt_tokens": 2,
      #|    "completion_tokens": 3,
      #|    "prompt_tokens_details": { "cached_tokens": 1 }
      #|  }
      #|}
    ),
    state,
  )
  all_events.append(usage_events)
  let (done, _, finish_events) = openai_chat_stream_data_to_codex_response_events(
    "[DONE]", state,
  )
  all_events.append(finish_events)
  assert_true(done)
  guard all_events[0] is Object(created) else { fail("expected created") }
  assert_eq(created["type"], Json::string("response.created"))
  guard all_events[2] is Object(item_added) else { fail("expected item") }
  assert_eq(item_added["type"], Json::string("response.output_item.added"))
  guard all_events[4] is Object(delta) else { fail("expected delta") }
  assert_eq(delta["type"], Json::string("response.output_text.delta"))
  assert_eq(delta["delta"], Json::string("hi"))
  guard all_events[all_events.length() - 1] is Object(completed) else {
    fail("expected completed")
  }
  assert_eq(completed["type"], Json::string("response.completed"))
  guard completed["response"] is Object(response) else {
    fail("expected response")
  }
  assert_eq(response["id"], Json::string("resp_chatcmpl_1"))
  guard response["output"] is Array(output) else { fail("expected output") }
  guard output[0] is Object(message) else { fail("expected message") }
  guard message["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(part) else { fail("expected part") }
  assert_eq(part["text"], Json::string("hi"))
  guard response["usage"] is Object(usage) else { fail("expected usage") }
  assert_eq(usage["input_tokens"], Json::number(2.0))
  assert_eq(usage["output_tokens"], Json::number(3.0))
  guard usage["input_tokens_details"] is Object(details) else {
    fail("expected usage details")
  }
  assert_eq(details["cached_tokens"], Json::number(1.0))
}

///|
test "chat completion stream converts tool call to codex responses events" {
  let state = ChatToCodexResponsesStreamState::new("fallback")
  let all_events : Array[Json] = []
  let (_, _, first_events) = openai_chat_stream_data_to_codex_response_events(
    (
      #|{
      #|  "id": "chatcmpl_tool",
      #|  "model": "deepseek-chat",
      #|  "created": 10,
      #|  "choices": [{
      #|    "delta": {
      #|      "tool_calls": [{
      #|        "index": 0,
      #|        "id": "call_1",
      #|        "type": "function",
      #|        "function": { "name": "lookup", "arguments": "{\"q\"" }
      #|      }]
      #|    },
      #|    "finish_reason": null
      #|  }]
      #|}
    ),
    state,
  )
  all_events.append(first_events)
  let (_, _, second_events) = openai_chat_stream_data_to_codex_response_events(
    (
      #|{
      #|  "id": "chatcmpl_tool",
      #|  "model": "deepseek-chat",
      #|  "created": 10,
      #|  "choices": [{
      #|    "delta": {
      #|      "tool_calls": [{
      #|        "index": 0,
      #|        "function": { "arguments": ":\"moon\"}" }
      #|      }]
      #|    },
      #|    "finish_reason": "tool_calls"
      #|  }]
      #|}
    ),
    state,
  )
  all_events.append(second_events)
  let (_, _, finish_events) = openai_chat_stream_data_to_codex_response_events(
    "[DONE]", state,
  )
  all_events.append(finish_events)
  guard all_events[2] is Object(added) else { fail("expected added") }
  assert_eq(added["type"], Json::string("response.output_item.added"))
  guard added["item"] is Object(added_item) else { fail("expected added item") }
  assert_eq(added_item["type"], Json::string("function_call"))
  assert_eq(added_item["call_id"], Json::string("call_1"))
  assert_eq(added_item["name"], Json::string("lookup"))
  guard all_events[3] is Object(first_delta) else { fail("expected delta") }
  assert_eq(
    first_delta["type"],
    Json::string("response.function_call_arguments.delta"),
  )
  guard all_events[4] is Object(second_delta) else {
    fail("expected second delta")
  }
  assert_eq(second_delta["delta"], Json::string(":\"moon\"}"))
  guard all_events[5] is Object(done_args) else { fail("expected done") }
  assert_eq(
    done_args["type"],
    Json::string("response.function_call_arguments.done"),
  )
  assert_eq(done_args["arguments"], Json::string("{\"q\":\"moon\"}"))
  guard all_events[all_events.length() - 1] is Object(completed) else {
    fail("expected completed")
  }
  guard completed["response"] is Object(response) else {
    fail("expected response")
  }
  guard response["output"] is Array(output) else { fail("expected output") }
  guard output[0] is Object(call) else { fail("expected call") }
  assert_eq(call["type"], Json::string("function_call"))
  assert_eq(call["arguments"], Json::string("{\"q\":\"moon\"}"))
}
