///|
test "ccs codex session parser extracts metadata and messages" {
  let lines = [
    "{\"timestamp\":\"2026-03-06T21:50:12Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"codex-s1\",\"cwd\":\"/tmp/project\"}}",
    "{\"timestamp\":\"2026-03-06T21:50:13Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":\"hello codex\"}}",
    "{\"timestamp\":\"2026-03-06T21:50:14Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"function_call\",\"name\":\"shell\"}}",
    "{\"timestamp\":\"2026-03-06T21:50:15Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"function_call_output\",\"output\":\"ok\"}}",
  ]
  let meta = ccs_parse_codex_session_lines(lines, "/tmp/codex-s1.jsonl").unwrap()
  assert_eq(meta.provider_id, "codex")
  assert_eq(meta.session_id, "codex-s1")
  assert_eq(meta.project_dir, Some("/tmp/project"))
  assert_eq(meta.title, Some("hello codex"))
  assert_eq(meta.resume_command, Some("codex resume codex-s1"))
  let messages = ccs_load_codex_messages(lines.join("\n"))
  assert_eq(messages.length(), 3)
  assert_eq(messages[0].role, "user")
  assert_eq(messages[1].content, "[Tool: shell]")
  assert_eq(messages[2].role, "tool")
}

///|
test "ccs claude session parser reclassifies tool result messages" {
  let content = [
    "{\"sessionId\":\"claude-s1\",\"cwd\":\"/tmp/claude\",\"timestamp\":\"2026-03-06T21:50:12Z\",\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"hello claude\"}}",
    "{\"timestamp\":\"2026-03-06T21:50:13Z\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"name\":\"Read\"}]}}",
    "{\"timestamp\":\"2026-03-06T21:50:14Z\",\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"tool_result\",\"content\":\"file contents\"}]}}",
    "{\"type\":\"custom-title\",\"customTitle\":\"Custom Claude Title\",\"timestamp\":\"2026-03-06T21:50:15Z\"}",
  ].join("\n")
  let meta = ccs_parse_claude_session_lines(
    ccs_nonempty_lines_from_content(content),
    "/tmp/claude-s1.jsonl",
  ).unwrap()
  assert_eq(meta.provider_id, "claude")
  assert_eq(meta.session_id, "claude-s1")
  assert_eq(meta.title, Some("Custom Claude Title"))
  assert_eq(meta.resume_command, Some("claude --resume claude-s1"))
  let messages = ccs_load_claude_messages(content)
  assert_eq(messages.length(), 3)
  assert_eq(messages[0].role, "user")
  assert_eq(messages[1].content, "[Tool: Read]")
  assert_eq(messages[2].role, "tool")
}

///|
test "ccs delete sessions parser accepts raw arrays and items wrapper" {
  let item = {
    "providerId": Json::string("codex"),
    "sessionId": Json::string("s1"),
    "sourcePath": Json::string("/tmp/s1.jsonl"),
  }.to_json()
  let raw = ccs_delete_session_requests_from_json(Some(Json::array([item])))
  assert_eq(raw.unwrap().length(), 1)
  let wrapped = ccs_delete_session_requests_from_json(
    Some({ "items": Json::array([item]) }.to_json()),
  )
  assert_eq(wrapped.unwrap()[0].provider_id, "codex")
  assert_eq(wrapped.unwrap()[0].session_id, "s1")
}

///|
test "ccs session terminal target follows CCS preferred terminal aliases" {
  assert_eq(ccs_session_terminal_target(None), "terminal")
  assert_eq(ccs_session_terminal_target(Some("iterm2")), "iterm")
  assert_eq(ccs_session_terminal_target(Some(" Ghostty ")), "ghostty")
  let settings = { "preferredTerminal": Json::string("wezterm") }.to_json()
  assert_eq(ccs_session_terminal_from_settings(settings), Some("wezterm"))
}

///|
test "ccs session terminal app launch quotes cwd in applescript" {
  let launch = ccs_session_terminal_launch(
    "terminal",
    "claude --resume abc-123",
    Some("/tmp/project dir"),
    None,
  ).unwrap()
  assert_eq(launch.program, "osascript")
  assert_true(launch.args[1].contains("tell application \"Terminal\""))
  assert_true(
    launch.args[1].contains(
      "cd \\\"/tmp/project dir\\\" && claude --resume abc-123",
    ),
  )
}

///|
test "ccs session wezterm launch uses cwd argument and shell command" {
  let launch = ccs_session_terminal_launch(
    "wezterm",
    "claude --resume abc-123",
    Some("/tmp/project dir"),
    None,
  ).unwrap()
  assert_eq(launch.program, "open")
  assert_eq(launch.args[0], "-na")
  assert_eq(launch.args[1], "WezTerm")
  assert_true(launch.args.contains("--cwd"))
  assert_true(launch.args.contains("/tmp/project dir"))
  assert_eq(launch.args[launch.args.length() - 1], "claude --resume abc-123")
}

///|
test "ccs session custom terminal expands command and cwd" {
  let launch = ccs_session_terminal_launch(
    "custom",
    "codex resume s1",
    Some("/tmp/work"),
    Some("echo {cwd}; run {command}; again {command}"),
  ).unwrap()
  assert_eq(launch.program, "sh")
  assert_eq(launch.args, [
    "-c", "echo /tmp/work; run codex resume s1; again codex resume s1",
  ])
  assert_true(
    ccs_session_terminal_launch("custom", "cmd", None, None) is Err(_),
  )
}
