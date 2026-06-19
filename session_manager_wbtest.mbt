///|
test "moonstat codex session parser extracts metadata and messages" {
  let lines = [
    "{\"timestamp\":\"2026-03-06T21:50:12Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"codex-s1\",\"cwd\":\"/tmp/project\"}}",
    "{\"timestamp\":\"2026-03-06T21:50:13Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":\"hello codex\"}}",
    "{\"timestamp\":\"2026-03-06T21:50:14Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"function_call\",\"name\":\"shell\"}}",
    "{\"timestamp\":\"2026-03-06T21:50:15Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"function_call_output\",\"output\":\"ok\"}}",
  ]
  let meta = moon_parse_codex_session_lines(lines, "/tmp/codex-s1.jsonl").unwrap()
  assert_eq(meta.provider_id, "codex")
  assert_eq(meta.session_id, "codex-s1")
  assert_eq(meta.project_dir, Some("/tmp/project"))
  assert_eq(meta.title, Some("hello codex"))
  assert_eq(meta.resume_command, Some("codex resume codex-s1"))
  let messages = moon_load_codex_messages(lines.join("\n"))
  assert_eq(messages.length(), 3)
  assert_eq(messages[0].role, "user")
  assert_eq(messages[1].content, "[Tool: shell]")
  assert_eq(messages[2].role, "tool")
}

///|
test "moonstat claude session parser reclassifies tool result messages" {
  let content = [
    "{\"sessionId\":\"claude-s1\",\"cwd\":\"/tmp/claude\",\"timestamp\":\"2026-03-06T21:50:12Z\",\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"hello claude\"}}",
    "{\"timestamp\":\"2026-03-06T21:50:13Z\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"name\":\"Read\"}]}}",
    "{\"timestamp\":\"2026-03-06T21:50:14Z\",\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"tool_result\",\"content\":\"file contents\"}]}}",
    "{\"type\":\"custom-title\",\"customTitle\":\"Custom Claude Title\",\"timestamp\":\"2026-03-06T21:50:15Z\"}",
  ].join("\n")
  let meta = moon_parse_claude_session_lines(
    moon_nonempty_lines_from_content(content),
    "/tmp/claude-s1.jsonl",
  ).unwrap()
  assert_eq(meta.provider_id, "claude")
  assert_eq(meta.session_id, "claude-s1")
  assert_eq(meta.title, Some("Custom Claude Title"))
  assert_eq(meta.resume_command, Some("claude --resume claude-s1"))
  let messages = moon_load_claude_messages(content)
  assert_eq(messages.length(), 3)
  assert_eq(messages[0].role, "user")
  assert_eq(messages[1].content, "[Tool: Read]")
  assert_eq(messages[2].role, "tool")
}

///|
test "moonstat delete sessions parser accepts direct arrays only" {
  let item = {
    "providerId": Json::string("codex"),
    "sessionId": Json::string("s1"),
    "sourcePath": Json::string("/tmp/s1.jsonl"),
  }.to_json()
  let raw = moon_delete_session_requests_from_json(Some(Json::array([item])))
  assert_eq(raw.unwrap().length(), 1)
  assert_true(
    moon_delete_session_requests_from_json(
      Some({ "items": Json::array([item]) }.to_json()),
    )
    is None,
  )
}

///|
async test "moonstat opencode sqlite sessions scan load and delete" {
  @fsx.with_temporary_directory("moonstat-opencode-sqlite-XXXXXX", tmpdir => {
    let db_path = @pathx.join(tmpdir, "opencode.db")
    let setup =
      #|CREATE TABLE session(id TEXT PRIMARY KEY, title TEXT, directory TEXT, time_created INTEGER, time_updated INTEGER);
      #|CREATE TABLE message(id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, time_updated INTEGER, data TEXT);
      #|CREATE TABLE part(message_id TEXT, session_id TEXT, time_created INTEGER, data TEXT);
      #|INSERT INTO session VALUES('ses_1', '', '/tmp/open project', 1770000000000, 1770000005000);
      #|INSERT INTO message VALUES('msg_1', 'ses_1', 1770000001000, 1770000002000, '{"role":"assistant"}');
      #|INSERT INTO part VALUES('msg_1', 'ses_1', 1770000001001, '{"type":"text","text":"hello"}');
      #|INSERT INTO part VALUES('msg_1', 'ses_1', 1770000001002, '{"type":"tool","tool":"Bash"}');
    let created = @spawn.spawn("sqlite3", [db_path, setup], timeout=10000)
    assert_eq(created.status, 0)

    let rows = moon_sqlite_json_rows(
      db_path,
      "SELECT id, title, directory, time_created, time_updated FROM session ORDER BY time_updated DESC",
      read_only=true,
    ).unwrap()
    let sessions = moon_opencode_sqlite_rows_to_sessions(db_path, rows)
    assert_eq(sessions.length(), 1)
    assert_eq(sessions[0].session_id, "ses_1")
    assert_eq(sessions[0].title, Some("open project"))
    assert_eq(sessions[0].source_path, Some("sqlite:\{db_path}:ses_1"))
    assert_eq(sessions[0].resume_command, Some("opencode session resume ses_1"))

    let messages = moon_load_session_messages(
      "opencode",
      "sqlite:\{db_path}:ses_1",
    ).unwrap()
    assert_eq(messages.length(), 1)
    assert_eq(messages[0].role, "assistant")
    assert_eq(messages[0].content, "hello\n[Tool: Bash]")

    assert_eq(
      moon_delete_opencode_sqlite_session_with_expected(
        "ses_1",
        "sqlite:\{db_path}:ses_1",
        db_path,
      ),
      Ok(true),
    )
    let after = moon_sqlite_json_rows(
      db_path,
      "SELECT id, title, directory, time_created, time_updated FROM session ORDER BY time_updated DESC",
      read_only=true,
    ).unwrap()
    assert_eq(moon_opencode_sqlite_rows_to_sessions(db_path, after).length(), 0)
  })
}

///|
async test "moonstat hermes sqlite sessions scan load and delete" {
  @fsx.with_temporary_directory("moonstat-hermes-sqlite-XXXXXX", tmpdir => {
    let db_path = @pathx.join(tmpdir, "state.db")
    let setup =
      #|CREATE TABLE sessions(id TEXT PRIMARY KEY, title TEXT, cwd TEXT, started_at INTEGER, ended_at INTEGER);
      #|CREATE TABLE messages(session_id TEXT, role TEXT, content TEXT, created_at INTEGER);
      #|INSERT INTO sessions VALUES('h1', 'Hermes title', '/tmp/hermes', 1770000000, 1770000060);
      #|INSERT INTO messages VALUES('h1', 'user', 'hi hermes', 1770000000);
      #|INSERT INTO messages VALUES('h1', 'assistant', 'hello hermes', 1770000001);
    let created = @spawn.spawn("sqlite3", [db_path, setup], timeout=10000)
    assert_eq(created.status, 0)

    let rows = moon_sqlite_json_rows(
      db_path,
      "SELECT * FROM sessions ORDER BY rowid DESC LIMIT 500",
      read_only=true,
    ).unwrap()
    let sessions = moon_hermes_sqlite_rows_to_sessions(db_path, rows)
    assert_eq(sessions.length(), 1)
    assert_eq(sessions[0].session_id, "h1")
    assert_eq(sessions[0].title, Some("Hermes title"))
    assert_eq(sessions[0].source_path, Some("sqlite:\{db_path}#h1"))

    let messages = moon_load_session_messages("hermes", "sqlite:\{db_path}#h1").unwrap()
    assert_eq(messages.length(), 2)
    assert_eq(messages[0].role, "user")
    assert_eq(messages[1].content, "hello hermes")

    assert_eq(
      moon_delete_hermes_sqlite_session_with_expected(
        "h1",
        "sqlite:\{db_path}#h1",
        db_path,
      ),
      Ok(true),
    )
    let after = moon_sqlite_json_rows(
      db_path,
      "SELECT * FROM sessions ORDER BY rowid DESC LIMIT 500",
      read_only=true,
    ).unwrap()
    assert_eq(moon_hermes_sqlite_rows_to_sessions(db_path, after).length(), 0)
  })
}

///|
test "moonstat session terminal target follows Moonstat preferred terminal aliases" {
  assert_eq(moon_session_terminal_target(None), "terminal")
  assert_eq(moon_session_terminal_target(Some("iterm2")), "iterm")
  assert_eq(moon_session_terminal_target(Some(" Ghostty ")), "ghostty")
  let settings = { "preferredTerminal": Json::string("wezterm") }.to_json()
  assert_eq(moon_session_terminal_from_settings(settings), Some("wezterm"))
}

///|
async test "moonstat session terminal app launch quotes cwd in applescript" {
  let launch = moon_session_terminal_launch(
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
async test "moonstat session wezterm launch uses cwd argument and shell command" {
  let launch = moon_session_terminal_launch(
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
async test "moonstat session custom terminal expands command and cwd" {
  let launch = moon_session_terminal_launch(
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
    moon_session_terminal_launch("custom", "cmd", None, None) is Err(_),
  )
}

///|
async test "moonstat session warp launch writes self removing script and URL" {
  @fsx.with_temporary_directory("moonstat-warp-session-XXXXXX", tmpdir => {
    let launch = moon_session_terminal_launch(
      "warp",
      "claude --resume warp-1",
      Some(tmpdir),
      None,
    ).unwrap()
    assert_eq(launch.program, "open")
    assert_eq(launch.args[0], "-a")
    assert_eq(launch.args[1], "Warp")
    assert_true(launch.args[2].has_prefix("warp://action/new_tab?path="))
    assert_true(launch.args[2].contains("%2F"))
    let entries = @fsx.list_directory(tmpdir)
    assert_eq(entries.length(), 1)
    assert_true(entries[0].name.has_prefix(".moonsuite-warp-"))
    assert_true(entries[0].name.has_suffix(".sh"))
    let script = @fsx.read_file(entries[0].path)
    assert_true(script.contains("rm -- \"$0\""))
    assert_true(script.contains("exec claude --resume warp-1"))
  })
  assert_true(moon_session_terminal_launch("warp", "cmd", None, None) is Err(_))
}
