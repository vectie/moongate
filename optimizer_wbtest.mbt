///|
test "moongate copilot classifier marks tool result continuations as agent before sanitize" {
  let body = @json.parse(
    (
      #|{
      #|  "messages": [
      #|    { "role": "assistant", "content": "Processing..." },
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        { "type": "tool_result", "tool_use_id": "orphan_1", "content": "result data" },
      #|        { "type": "text", "text": "tool output follows" }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let classification = classify_moon_copilot_request(body, false, false, false)
  assert_eq(classification.initiator, "agent")
  let sanitized = sanitize_moon_copilot_orphan_tool_results(body)
  let after = classify_moon_copilot_request(sanitized, false, false, false)
  assert_eq(after.initiator, "user")
}

///|
test "moongate copilot sanitizer converts only orphan tool results" {
  let body = @json.parse(
    (
      #|{
      #|  "messages": [
      #|    {
      #|      "role": "assistant",
      #|      "content": [
      #|        { "type": "tool_use", "id": "tool_1", "name": "read", "input": {} }
      #|      ]
      #|    },
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        { "type": "tool_result", "tool_use_id": "tool_1", "content": "file" },
      #|        { "type": "tool_result", "tool_use_id": "missing", "content": "stale" }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  guard sanitize_moon_copilot_orphan_tool_results(body) is Object(root) else {
    fail("expected object")
  }
  guard root["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[1] is Object(user) else { fail("expected user") }
  guard user["content"] is Array(content) else { fail("expected content") }
  guard content[0] is Object(first) else { fail("expected first block") }
  guard content[1] is Object(second) else { fail("expected second block") }
  assert_eq(first["type"], Json::string("tool_result"))
  assert_eq(second["type"], Json::string("text"))
  guard second["text"] is String(text) else { fail("expected text") }
  assert_true(text.contains("[Tool result for missing]: stale"))
}

///|
test "moongate copilot optimizer merges tool result text and strips assistant thinking" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "messages": [
      #|    {
      #|      "role": "assistant",
      #|      "content": [
      #|        { "type": "thinking", "thinking": "hidden", "signature": "sig" },
      #|        { "type": "text", "text": "visible" }
      #|      ]
      #|    },
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        { "type": "tool_result", "tool_use_id": "missing", "content": "file contents" },
      #|        { "type": "text", "text": "skill output" }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="copilot",
    provider_name="GitHub Copilot",
    provider_type=Some("github_copilot"),
    base_url=Some("https://api.githubcopilot.com"),
    api_key=Some("token"),
  )
  let optimized = apply_moon_copilot_optimizer_for_provider(
    body,
    Some(provider),
    moon_default_copilot_optimizer_config_json(),
    false,
  )
  assert_eq(optimized.headers["x-initiator"], "agent")
  guard optimized.body is Object(root) else { fail("expected object") }
  guard root["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[0] is Object(assistant) else { fail("expected assistant") }
  guard assistant["content"] is Array(assistant_content) else {
    fail("expected assistant content")
  }
  assert_eq(assistant_content.length(), 1)
  guard messages[1] is Object(user) else { fail("expected user") }
  guard user["content"] is Array(user_content) else {
    fail("expected user content")
  }
  assert_eq(user_content.length(), 2)
  guard user_content[0] is Object(first_text) else {
    fail("expected first text block")
  }
  guard user_content[1] is Object(second_text) else {
    fail("expected second text block")
  }
  assert_eq(first_text["type"], Json::string("text"))
  assert_eq(second_text["type"], Json::string("text"))
  guard first_text["text"] is String(first) else { fail("expected first text") }
  guard second_text["text"] is String(second) else {
    fail("expected second text")
  }
  assert_true(first.contains("file contents"))
  assert_true(second.contains("skill output"))
}

///|
test "moongate copilot optimizer merges valid tool result text blocks" {
  let body = @json.parse(
    (
      #|{
      #|  "messages": [
      #|    {
      #|      "role": "assistant",
      #|      "content": [
      #|        { "type": "tool_use", "id": "tool_1", "name": "read", "input": {} }
      #|      ]
      #|    },
      #|    {
      #|      "role": "user",
      #|      "content": [
      #|        { "type": "tool_result", "tool_use_id": "tool_1", "content": "file contents" },
      #|        { "type": "text", "text": "skill output" }
      #|      ]
      #|    }
      #|  ]
      #|}
    ),
  )
  let merged = merge_moon_copilot_tool_results(
    sanitize_moon_copilot_orphan_tool_results(body),
  )
  guard merged is Object(root) else { fail("expected object") }
  guard root["messages"] is Array(messages) else { fail("expected messages") }
  guard messages[1] is Object(user) else { fail("expected user") }
  guard user["content"] is Array(content) else { fail("expected content") }
  assert_eq(content.length(), 1)
  guard content[0] is Object(tool_result) else { fail("expected tool result") }
  assert_eq(tool_result["type"], Json::string("tool_result"))
  guard tool_result["content"] is String(text) else { fail("expected content") }
  assert_true(text.contains("file contents"))
  assert_true(text.contains("skill output"))
}

///|
test "moongate copilot optimizer downgrades warmup model for anthropic beta probes" {
  let body = @json.parse(
    (
      #|{
      #|  "model": "claude-sonnet-4-6",
      #|  "anthropic_beta": ["claude-code-20250219"],
      #|  "messages": [{ "role": "user", "content": "Hello" }]
      #|}
    ),
  )
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="copilot",
    provider_name="GitHub Copilot",
    provider_type=Some("github_copilot"),
    base_url=Some("https://api.githubcopilot.com"),
    api_key=Some("token"),
  )
  let optimized = apply_moon_copilot_optimizer_for_provider(
    body,
    Some(provider),
    moon_default_copilot_optimizer_config_json(),
    true,
  )
  assert_eq(optimized.headers["x-initiator"], "user")
  guard optimized.body is Object(root) else { fail("expected object") }
  assert_eq(root["model"], Json::string("gpt-5-mini"))
}

///|
test "moongate copilot optimizer emits deterministic interaction headers" {
  let body = @json.parse(
    (
      #|{
      #|  "messages": [{ "role": "user", "content": "Hello" }],
      #|  "metadata": { "session_id": "session-a" }
      #|}
    ),
  )
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="copilot",
    provider_name="GitHub Copilot",
    provider_type=Some("github_copilot"),
    base_url=Some("https://api.githubcopilot.com"),
    api_key=Some("token"),
  )
  let first = apply_moon_copilot_optimizer_for_provider(
    body,
    Some(provider),
    moon_default_copilot_optimizer_config_json(),
    false,
  )
  let second = apply_moon_copilot_optimizer_for_provider(
    body,
    Some(provider),
    moon_default_copilot_optimizer_config_json(),
    false,
  )
  assert_eq(first.headers["x-request-id"], second.headers["x-request-id"])
  assert_eq(first.headers["x-agent-task-id"], first.headers["x-request-id"])
  assert_true(first.headers["x-interaction-id"].length() == 36)
}

///|
test "moongate copilot optimizer marks subagent interaction header" {
  let body = @json.parse(
    (
      #|{
      #|  "messages": [
      #|    { "role": "user", "content": "__SUBAGENT_MARKER__" }
      #|  ],
      #|  "metadata": { "user_id": "parent_agent_child" }
      #|}
    ),
  )
  let provider = ProviderRouteTarget::new(
    app_type="claude",
    provider_id="copilot",
    provider_name="GitHub Copilot",
    provider_type=Some("github_copilot"),
    base_url=Some("https://api.githubcopilot.com"),
    api_key=Some("token"),
  )
  let optimized = apply_moon_copilot_optimizer_for_provider(
    body,
    Some(provider),
    moon_default_copilot_optimizer_config_json(),
    false,
  )
  assert_eq(optimized.headers["x-initiator"], "agent")
  assert_eq(optimized.headers["x-interaction-type"], "conversation-subagent")
}
