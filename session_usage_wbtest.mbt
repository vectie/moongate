///|
test "claude session jsonl import mirrors moongate replacement and request log shape" {
  let stats = TrafficStats::new()
  let content =
    #|{"type":"system","sessionId":"session-abc"}
    #|{"type":"assistant","message":{"id":"msg_1","model":"claude-sonnet-4-20250514","usage":{"input_tokens":3,"output_tokens":26,"cache_read_input_tokens":5000,"cache_creation_input_tokens":10000}},"timestamp":"1970-01-01T00:00:10Z"}
    #|{"type":"assistant","message":{"id":"msg_1","model":"claude-sonnet-4-20250514","usage":{"input_tokens":3,"output_tokens":150,"cache_read_input_tokens":5000,"cache_creation_input_tokens":10000},"stop_reason":"end_turn"},"timestamp":"1970-01-01T00:00:10Z"}
  let result = stats.ingest_claude_session_jsonl(
    file_path="/tmp/project/session.jsonl",
    content~,
    last_modified=1L,
  )
  json_inspect(result.to_json(), content={
    "imported": 1,
    "skipped": 0,
    "filesScanned": 1,
    "errors": [],
  })
  assert_eq(stats.request_logs.length(), 1)
  let log = stats.request_logs[0]
  assert_eq(log.request_id, "session:msg_1")
  assert_eq(log.provider_id, "_session")
  assert_eq(log.app_type, "claude")
  assert_eq(log.model, "claude-sonnet-4-20250514")
  assert_eq(log.request_model, Some("claude-sonnet-4-20250514"))
  assert_eq(log.pricing_model, Some("claude-sonnet-4-20250514"))
  assert_eq(log.output_tokens, 150)
  assert_eq(log.cache_read_tokens, 5000)
  assert_eq(log.cache_creation_tokens, 10000)
  assert_eq(log.session_id, Some("session-abc"))
  assert_eq(log.provider_type, Some("session_log"))
  assert_true(log.is_streaming)
  assert_eq(log.status_code, 200)
  assert_eq(log.created_at, 10)
  assert_eq(log.data_source, "session_log")
  assert_eq(log.input_cost_usd, "0.000009")
  assert_eq(log.output_cost_usd, "0.00225")
  assert_eq(log.cache_read_cost_usd, "0.0015")
  assert_eq(log.cache_creation_cost_usd, "0.0375")
  assert_eq(log.total_cost_usd, "0.041259")
}

///|
test "claude session import keeps cache-only billable rows like moongate" {
  let stats = TrafficStats::new()
  let content =
    #|{"type":"assistant","sessionId":"session-cache","message":{"id":"msg_cache","model":"claude-sonnet-4-20250514","usage":{"input_tokens":0,"output_tokens":0,"cache_read_input_tokens":42,"cache_creation_input_tokens":0}},"timestamp":"1970-01-01T00:00:20+00:00"}
  let result = stats.ingest_claude_session_jsonl(
    file_path="/tmp/project/cache.jsonl",
    content~,
    last_modified=1L,
  )
  assert_eq(result.imported, 1)
  assert_eq(stats.request_logs.length(), 1)
  let log = stats.request_logs[0]
  assert_eq(log.request_id, "session:msg_cache")
  assert_eq(log.input_tokens, 0)
  assert_eq(log.output_tokens, 0)
  assert_eq(log.cache_read_tokens, 42)
  assert_eq(log.created_at, 20)
}

///|
test "claude session import ignores non-u64 token fields like moongate" {
  let stats = TrafficStats::new()
  let content =
    #|{"type":"assistant","sessionId":"session-invalid","message":{"id":"msg_invalid","model":"claude-sonnet-4-20250514","usage":{"input_tokens":-3,"output_tokens":5,"cache_read_input_tokens":7.5,"cache_creation_input_tokens":-9}},"timestamp":"1970-01-01T00:00:22Z"}
  let result = stats.ingest_claude_session_jsonl(
    file_path="/tmp/project/invalid.jsonl",
    content~,
    last_modified=1L,
  )
  assert_eq(result.imported, 1)
  assert_eq(stats.request_logs.length(), 1)
  let log = stats.request_logs[0]
  assert_eq(log.input_tokens, 0)
  assert_eq(log.output_tokens, 5)
  assert_eq(log.cache_read_tokens, 0)
  assert_eq(log.cache_creation_tokens, 0)
}

///|
test "claude session import stores offsets and skips duplicate session rows" {
  let stats = TrafficStats::new()
  let file_path = "/tmp/project/dedup.jsonl"
  let first =
    #|{"type":"assistant","message":{"id":"msg_a","model":"unknown","usage":{"input_tokens":1,"output_tokens":2}},"timestamp":"1970-01-01T00:00:30Z"}
  let first_result = stats.ingest_claude_session_jsonl(
    file_path~,
    content=first,
    last_modified=1L,
  )
  assert_eq(first_result.imported, 1)
  let unchanged_result = stats.ingest_claude_session_jsonl(
    file_path~,
    content=first,
    last_modified=1L,
  )
  assert_eq(unchanged_result.imported, 0)
  assert_eq(unchanged_result.skipped, 0)
  let second =
    #|{"type":"assistant","message":{"id":"msg_a","model":"unknown","usage":{"input_tokens":1,"output_tokens":2}},"timestamp":"1970-01-01T00:00:30Z"}
    #|{"type":"assistant","message":{"id":"msg_a","model":"unknown","usage":{"input_tokens":1,"output_tokens":2}},"timestamp":"1970-01-01T00:00:30Z"}
    #|{"type":"assistant","message":{"id":"msg_b","model":"unknown","usage":{"input_tokens":3,"output_tokens":4}},"timestamp":"1970-01-01T00:00:40Z"}
  let second_result = stats.ingest_claude_session_jsonl(
    file_path~,
    content=second,
    last_modified=2L,
  )
  assert_eq(second_result.imported, 1)
  assert_eq(second_result.skipped, 1)
  assert_eq(stats.request_logs.length(), 2)
  assert_eq(stats.request_logs[1].request_id, "session:msg_b")
}

///|
test "codex session import computes cumulative deltas like moongate" {
  let stats = TrafficStats::new()
  let content =
    #|{"type":"session_meta","payload":{"session_id":"codex-s1"}}
    #|{"type":"turn_context","payload":{"model":"OpenAI/GPT-5.5-2026-05-14"}}
    #|{"type":"event_msg","timestamp":"1970-01-01T00:00:10Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":60,"output_tokens":10}}}}
    #|{"type":"event_msg","timestamp":"1970-01-01T00:00:20Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":130,"cached_input_tokens":90,"output_tokens":15}}}}
  let result = stats.ingest_codex_session_jsonl(
    file_path="/tmp/codex/session.jsonl",
    content~,
    last_modified=1L,
  )
  assert_eq(result.imported, 2)
  assert_eq(stats.request_logs.length(), 2)
  let first = stats.request_logs[0]
  assert_eq(first.request_id, "codex_session:codex-s1:1")
  assert_eq(first.provider_id, "_codex_session")
  assert_eq(first.app_type, "codex")
  assert_eq(first.model, "gpt-5.5")
  assert_eq(first.input_tokens, 100)
  assert_eq(first.cache_read_tokens, 60)
  assert_eq(first.output_tokens, 10)
  assert_eq(first.provider_type, Some("codex_session"))
  assert_eq(first.data_source, "codex_session")
  assert_true(first.is_streaming)
  let second = stats.request_logs[1]
  assert_eq(second.request_id, "codex_session:codex-s1:2")
  assert_eq(second.input_tokens, 30)
  assert_eq(second.cache_read_tokens, 30)
  assert_eq(second.output_tokens, 5)
  assert_eq(second.created_at, 20)
}

///|
test "codex session import keeps invalid cached token key from falling back" {
  let stats = TrafficStats::new()
  let content =
    #|{"type":"session_meta","payload":{"session_id":"codex-invalid"}}
    #|{"type":"event_msg","timestamp":"1970-01-01T00:00:10Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":10,"cached_input_tokens":3,"output_tokens":2}}}}
    #|{"type":"event_msg","timestamp":"1970-01-01T00:00:20Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":18,"cached_input_tokens":-5,"cache_read_input_tokens":12,"output_tokens":6}}}}
  let result = stats.ingest_codex_session_jsonl(
    file_path="/tmp/codex/invalid.jsonl",
    content~,
    last_modified=1L,
  )
  assert_eq(result.imported, 2)
  assert_eq(stats.request_logs.length(), 2)
  let second = stats.request_logs[1]
  assert_eq(second.input_tokens, 8)
  assert_eq(second.cache_read_tokens, 0)
  assert_eq(second.output_tokens, 4)
}

///|
test "codex session import restores state before offset skip" {
  let stats = TrafficStats::new()
  let file_path = "/tmp/codex/offset.jsonl"
  let first =
    #|{"type":"session_meta","payload":{"session_id":"codex-offset"}}
    #|{"type":"event_msg","timestamp":"1970-01-01T00:00:10Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":10,"cached_input_tokens":2,"output_tokens":1}}}}
  let first_result = stats.ingest_codex_session_jsonl(
    file_path~,
    content=first,
    last_modified=1L,
  )
  assert_eq(first_result.imported, 1)
  let second =
    #|{"type":"session_meta","payload":{"session_id":"codex-offset"}}
    #|{"type":"event_msg","timestamp":"1970-01-01T00:00:10Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":10,"cached_input_tokens":2,"output_tokens":1}}}}
    #|{"type":"event_msg","timestamp":"1970-01-01T00:00:20Z","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":25,"cached_input_tokens":4,"output_tokens":3}}}}
  let second_result = stats.ingest_codex_session_jsonl(
    file_path~,
    content=second,
    last_modified=2L,
  )
  assert_eq(second_result.imported, 1)
  assert_eq(stats.request_logs.length(), 2)
  let log = stats.request_logs[1]
  assert_eq(log.request_id, "codex_session:codex-offset:2")
  assert_eq(log.input_tokens, 15)
  assert_eq(log.cache_read_tokens, 2)
  assert_eq(log.output_tokens, 2)
}

///|
test "codex session import accepts last token usage deltas like moongate" {
  let stats = TrafficStats::new()
  let content =
    #|{"type":"session_meta","payload":{"session_id":"codex-last"}}
    #|{"type":"turn_context","payload":{"info":{"model":"OpenAI/GPT-5.5-2026-05-14"}}}
    #|{"type":"event_msg","timestamp":"1970-01-01T00:00:10Z","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,"cached_input_tokens":20,"output_tokens":2}}}}
    #|{"type":"event_msg","timestamp":"1970-01-01T00:00:20Z","payload":{"type":"token_count","info":{"model_name":"OpenAI/GPT-5.5-2026-05-14","last_token_usage":{"input_tokens":5,"cache_read_input_tokens":3,"output_tokens":4}}}}
  let result = stats.ingest_codex_session_jsonl(
    file_path="/tmp/codex/last-token.jsonl",
    content~,
    last_modified=1L,
  )
  assert_eq(result.imported, 2)
  assert_eq(stats.request_logs.length(), 2)
  let first = stats.request_logs[0]
  assert_eq(first.request_id, "codex_session:codex-last:1")
  assert_eq(first.model, "gpt-5.5")
  assert_eq(first.input_tokens, 10)
  assert_eq(first.cache_read_tokens, 10)
  assert_eq(first.output_tokens, 2)
  let second = stats.request_logs[1]
  assert_eq(second.request_id, "codex_session:codex-last:2")
  assert_eq(second.model, "gpt-5.5")
  assert_eq(second.input_tokens, 5)
  assert_eq(second.cache_read_tokens, 3)
  assert_eq(second.output_tokens, 4)
}

///|
test "gemini session import merges thoughts into output like moongate" {
  let stats = TrafficStats::new()
  let content =
    #|{
    #|  "sessionId": "gemini-s1",
    #|  "messages": [
    #|    {"type":"user","id":"u1"},
    #|    {"type":"gemini","id":"g1","model":"gemini-3-pro-preview","timestamp":"1970-01-01T00:00:30Z","tokens":{"input":10,"output":2,"cached":1,"thoughts":5}},
    #|    {"type":"gemini","id":"g2","model":"gemini-3-pro-preview","timestamp":"1970-01-01T00:00:40Z","tokens":{"input":0,"output":0,"cached":42,"thoughts":0}}
    #|  ]
    #|}
  let result = stats.ingest_gemini_session_json(
    file_path="/tmp/gemini/session.json",
    content~,
    last_modified=1L,
  )
  assert_eq(result.imported, 2)
  assert_eq(stats.request_logs.length(), 2)
  let first = stats.request_logs[0]
  assert_eq(first.request_id, "gemini_session:gemini-s1:g1")
  assert_eq(first.provider_id, "_gemini_session")
  assert_eq(first.app_type, "gemini")
  assert_eq(first.input_tokens, 10)
  assert_eq(first.output_tokens, 7)
  assert_eq(first.cache_read_tokens, 1)
  assert_eq(first.provider_type, Some("gemini_session"))
  assert_eq(first.data_source, "gemini_session")
  assert_eq(first.created_at, 30)
  let second = stats.request_logs[1]
  assert_eq(second.request_id, "gemini_session:gemini-s1:g2")
  assert_eq(second.cache_read_tokens, 42)
}

///|
test "gemini session import ignores non-u64 token fields like moongate" {
  let stats = TrafficStats::new()
  let content =
    #|{
    #|  "sessionId": "gemini-invalid",
    #|  "messages": [
    #|    {"type":"gemini","id":"g1","model":"gemini-3-pro-preview","timestamp":"1970-01-01T00:00:30Z","tokens":{"input":-10,"output":2,"cached":1.25,"thoughts":-4}}
    #|  ]
    #|}
  let result = stats.ingest_gemini_session_json(
    file_path="/tmp/gemini/invalid.json",
    content~,
    last_modified=1L,
  )
  assert_eq(result.imported, 1)
  assert_eq(stats.request_logs.length(), 1)
  let log = stats.request_logs[0]
  assert_eq(log.input_tokens, 0)
  assert_eq(log.output_tokens, 2)
  assert_eq(log.cache_read_tokens, 0)
}

///|
test "opencode message import mirrors moongate request log shape" {
  let stats = TrafficStats::new()
  let data =
    #|{
    #|  "role": "assistant",
    #|  "cost": 0.0023113,
    #|  "tokens": {
    #|    "total": 56554,
    #|    "input": 3272,
    #|    "output": 383,
    #|    "reasoning": 419,
    #|    "cache": { "write": 7, "read": 52480 }
    #|  },
    #|  "modelID": "deepseek-v4-pro",
    #|  "providerID": "deepseek",
    #|  "time": { "created": 1779755333700, "completed": 1779755350639 }
    #|}
  let result = stats.ingest_opencode_message_json(
    session_id="opencode-s1",
    message_id="msg-open-1",
    data~,
  )
  assert_eq(result.imported, 1)
  assert_eq(result.skipped, 0)
  assert_eq(stats.request_logs.length(), 1)
  let log = stats.request_logs[0]
  assert_eq(log.request_id, "opencode_session:opencode-s1:msg-open-1")
  assert_eq(log.provider_id, "_opencode_session")
  assert_eq(log.app_type, "opencode")
  assert_eq(log.model, "deepseek-v4-pro")
  assert_eq(log.request_model, Some("deepseek-v4-pro"))
  assert_eq(log.input_tokens, 3272)
  assert_eq(log.output_tokens, 802)
  assert_eq(log.cache_read_tokens, 52480)
  assert_eq(log.cache_creation_tokens, 7)
  assert_eq(log.input_cost_usd, "0")
  assert_eq(log.output_cost_usd, "0")
  assert_eq(log.total_cost_usd, "0.0023113")
  assert_eq(log.session_id, Some("opencode-s1"))
  assert_eq(log.provider_type, Some("opencode_session"))
  assert_true(log.is_streaming)
  assert_eq(log.status_code, 200)
  assert_eq(log.created_at, 1779755333)
  assert_eq(log.data_source, "opencode_session")
}

///|
test "opencode message import defaults missing cache and skips incomplete rows" {
  let stats = TrafficStats::new()
  let complete =
    #|{
    #|  "role": "assistant",
    #|  "cost": 0,
    #|  "tokens": { "input": 1000, "output": 200 },
    #|  "modelID": "mimo-v2.5-pro",
    #|  "time": { "created": 1779755333700, "completed": 1779755334700 }
    #|}
  let complete_result = stats.ingest_opencode_message_json(
    session_id="opencode-s2",
    message_id="done",
    data=complete,
  )
  assert_eq(complete_result.imported, 1)
  let log = stats.request_logs[0]
  assert_eq(log.input_tokens, 1000)
  assert_eq(log.output_tokens, 200)
  assert_eq(log.cache_read_tokens, 0)
  assert_eq(log.cache_creation_tokens, 0)

  let incomplete =
    #|{
    #|  "role": "assistant",
    #|  "tokens": { "input": 500, "output": 1 },
    #|  "modelID": "mimo-v2.5-pro",
    #|  "time": { "created": 1779755333700 }
    #|}
  let incomplete_result = stats.ingest_opencode_message_json(
    session_id="opencode-s2",
    message_id="wip",
    data=incomplete,
  )
  assert_eq(incomplete_result.imported, 0)
  assert_eq(incomplete_result.skipped, 1)
  assert_eq(stats.request_logs.length(), 1)

  let zero =
    #|{
    #|  "role": "assistant",
    #|  "tokens": {
    #|    "input": 0,
    #|    "output": 0,
    #|    "reasoning": 0,
    #|    "cache": { "read": 0, "write": 0 }
    #|  },
    #|  "modelID": "mimo-v2.5-pro",
    #|  "time": { "created": 1779755333700, "completed": 1779755334700 }
    #|}
  let zero_result = stats.ingest_opencode_message_json(
    session_id="opencode-s2",
    message_id="zero",
    data=zero,
  )
  assert_eq(zero_result.imported, 0)
  assert_eq(zero_result.skipped, 1)
  assert_eq(stats.request_logs.length(), 1)
}

///|
test "opencode message import ignores non-u64 token fields like moongate" {
  let stats = TrafficStats::new()
  let data =
    #|{
    #|  "role": "assistant",
    #|  "tokens": {
    #|    "input": -100,
    #|    "output": 200,
    #|    "reasoning": 1.5,
    #|    "cache": { "read": -3, "write": 4.7 }
    #|  },
    #|  "modelID": "mimo-v2.5-pro",
    #|  "time": { "created": 1779755333700, "completed": 1779755334700 }
    #|}
  let result = stats.ingest_opencode_message_json(
    session_id="opencode-invalid",
    message_id="invalid",
    data~,
  )
  assert_eq(result.imported, 1)
  assert_eq(stats.request_logs.length(), 1)
  let log = stats.request_logs[0]
  assert_eq(log.input_tokens, 0)
  assert_eq(log.output_tokens, 200)
  assert_eq(log.cache_read_tokens, 0)
  assert_eq(log.cache_creation_tokens, 0)
}

///|
test "opencode export jsonl import stores offsets and supports string data" {
  let stats = TrafficStats::new()
  let file_path = "/tmp/opencode/messages.jsonl"
  let content =
    #|{"session_id":"opencode-export","message_id":"m1","data":{"role":"assistant","tokens":{"input":10,"output":2},"modelID":"open-model","time":{"created":1779755333700,"completed":1779755334700}}}
    #|{"session_id":"opencode-export","message_id":"m2","data":"{\"role\":\"assistant\",\"tokens\":{\"input\":1,\"output\":1,\"reasoning\":3,\"cache\":{\"read\":5,\"write\":7}},\"modelID\":\"open-model\",\"time\":{\"created\":1779755335700,\"completed\":1779755336700}}"}
  let first_result = stats.ingest_opencode_session_export_jsonl(
    file_path~,
    content~,
    last_modified=1L,
  )
  assert_eq(first_result.imported, 2)
  assert_eq(first_result.skipped, 0)
  assert_eq(stats.request_logs.length(), 2)
  assert_eq(
    stats.request_logs[0].request_id,
    "opencode_session:opencode-export:m1",
  )
  assert_eq(stats.request_logs[0].output_tokens, 2)
  assert_eq(
    stats.request_logs[1].request_id,
    "opencode_session:opencode-export:m2",
  )
  assert_eq(stats.request_logs[1].output_tokens, 4)
  assert_eq(stats.request_logs[1].cache_read_tokens, 5)
  assert_eq(stats.request_logs[1].cache_creation_tokens, 7)

  let unchanged_result = stats.ingest_opencode_session_export_jsonl(
    file_path~,
    content~,
    last_modified=1L,
  )
  assert_eq(unchanged_result.imported, 0)
  assert_eq(unchanged_result.skipped, 0)

  let appended =
    #|{"session_id":"opencode-export","message_id":"m1","data":{"role":"assistant","tokens":{"input":10,"output":2},"modelID":"open-model","time":{"created":1779755333700,"completed":1779755334700}}}
    #|{"session_id":"opencode-export","message_id":"m2","data":"{\"role\":\"assistant\",\"tokens\":{\"input\":1,\"output\":1,\"reasoning\":3,\"cache\":{\"read\":5,\"write\":7}},\"modelID\":\"open-model\",\"time\":{\"created\":1779755335700,\"completed\":1779755336700}}"}
    #|{"session_id":"opencode-export","message_id":"m3","data":{"role":"assistant","tokens":{"input":3,"output":4},"modelID":"open-model","time":{"created":1779755337700,"completed":1779755338700}}}
  let appended_result = stats.ingest_opencode_session_export_jsonl(
    file_path~,
    content=appended,
    last_modified=2L,
  )
  assert_eq(appended_result.imported, 1)
  assert_eq(stats.request_logs.length(), 3)
  assert_eq(
    stats.request_logs[2].request_id,
    "opencode_session:opencode-export:m3",
  )
}

///|
test "opencode database rows import uses moongate session watermarks" {
  let stats = TrafficStats::new()
  let db_path = "/tmp/opencode/opencode.db"
  let first_rows =
    #|[
    #|  {
    #|    "session_id": "open-db",
    #|    "sync_watermark": 200,
    #|    "message_id": "m1",
    #|    "data": "{\"role\":\"assistant\",\"cost\":0.0023113,\"tokens\":{\"input\":10,\"output\":2,\"reasoning\":3,\"cache\":{\"read\":5,\"write\":7}},\"modelID\":\"open-model\",\"time\":{\"created\":1779755333700,\"completed\":1779755334700}}"
    #|  },
    #|  {
    #|    "session_id": "open-db",
    #|    "sync_watermark": 200,
    #|    "message_id": "m2",
    #|    "data": "{\"role\":\"assistant\",\"tokens\":{\"input\":4,\"output\":1},\"modelID\":\"open-model\",\"time\":{\"created\":1779755335700}}"
    #|  }
    #|]
  let first = stats.ingest_opencode_database_rows_json(
    db_path~,
    content=first_rows,
    last_modified=10L,
  )
  assert_eq(first.imported, 1)
  assert_eq(first.skipped, 0)
  assert_eq(stats.request_logs.length(), 1)
  assert_eq(stats.request_logs[0].request_id, "opencode_session:open-db:m1")
  assert_eq(stats.request_logs[0].output_tokens, 5)
  assert_eq(stats.request_logs[0].cache_read_tokens, 5)
  assert_eq(stats.request_logs[0].cache_creation_tokens, 7)
  assert_eq(stats.request_logs[0].total_cost_usd, "0.0023113")
  assert_true(stats.session_sync_state.get(db_path) is Some(_))
  assert_true(stats.session_sync_state.get("\{db_path}:open-db") is None)

  let unchanged = stats.ingest_opencode_database_rows_json(
    db_path~,
    content=first_rows,
    last_modified=10L,
  )
  assert_eq(unchanged.imported, 0)
  assert_eq(unchanged.skipped, 0)

  let completed_rows =
    #|[
    #|  {
    #|    "session_id": "open-db",
    #|    "sync_watermark": 300,
    #|    "message_id": "m1",
    #|    "data": "{\"role\":\"assistant\",\"tokens\":{\"input\":10,\"output\":2,\"reasoning\":3,\"cache\":{\"read\":5,\"write\":7}},\"modelID\":\"open-model\",\"time\":{\"created\":1779755333700,\"completed\":1779755334700}}"
    #|  },
    #|  {
    #|    "session_id": "open-db",
    #|    "sync_watermark": 300,
    #|    "message_id": "m2",
    #|    "data": "{\"role\":\"assistant\",\"tokens\":{\"input\":4,\"output\":1},\"modelID\":\"open-model\",\"time\":{\"created\":1779755335700,\"completed\":1779755336700}}"
    #|  }
    #|]
  let completed = stats.ingest_opencode_database_rows_json(
    db_path~,
    content=completed_rows,
    last_modified=11L,
  )
  assert_eq(completed.imported, 1)
  assert_eq(completed.skipped, 1)
  assert_eq(stats.request_logs.length(), 2)
  assert_eq(stats.request_logs[1].request_id, "opencode_session:open-db:m2")
  guard stats.session_sync_state.get("\{db_path}:open-db") is Some(state) else {
    fail("expected per-session sync state")
  }
  assert_eq(state.last_modified, 300L)
}

///|
test "session imports skip matching proxy log fingerprints" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="proxy-1",
      provider_id="codex-oauth",
      app_type="codex",
      model="gpt-5.5",
      usage=TokenUsage::new(
        input_tokens=100,
        output_tokens=10,
        cache_read_tokens=60,
        model=Some("gpt-5.5"),
      ),
      status_code=200,
      created_at=10,
      data_source="proxy",
    ),
  )
  let content =
    #|{"type":"session_meta","payload":{"session_id":"dedup"}}
    #|{"type":"event_msg","timestamp":"1970-01-01T00:00:10Z","payload":{"type":"token_count","info":{"model":"gpt-5.5","total_token_usage":{"input_tokens":100,"cached_input_tokens":60,"output_tokens":10}}}}
  let result = stats.ingest_codex_session_jsonl(
    file_path="/tmp/codex/dedup.jsonl",
    content~,
    last_modified=1L,
  )
  assert_eq(result.imported, 0)
  assert_eq(result.skipped, 1)
  assert_eq(stats.request_logs.length(), 1)
}

///|
test "session imports treat missing proxy data source like moongate" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="proxy-legacy-source",
      provider_id="codex-oauth",
      app_type="codex",
      model="gpt-5.5",
      usage=TokenUsage::new(
        input_tokens=100,
        output_tokens=10,
        cache_read_tokens=60,
        model=Some("gpt-5.5"),
      ),
      status_code=200,
      created_at=10,
      data_source="",
    ),
  )
  let content =
    #|{"type":"session_meta","payload":{"session_id":"legacy-source"}}
    #|{"type":"event_msg","timestamp":"1970-01-01T00:00:10Z","payload":{"type":"token_count","info":{"model":"gpt-5.5","total_token_usage":{"input_tokens":100,"cached_input_tokens":60,"output_tokens":10}}}}
  let result = stats.ingest_codex_session_jsonl(
    file_path="/tmp/codex/legacy-source.jsonl",
    content~,
    last_modified=1L,
  )
  assert_eq(result.imported, 0)
  assert_eq(result.skipped, 1)
  assert_eq(stats.request_logs.length(), 1)
}

///|
test "opencode session import skips matching proxy log fingerprints" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="proxy-open-1",
      provider_id="opencode-provider",
      app_type="opencode",
      model="deepseek-v4-pro",
      usage=TokenUsage::new(
        input_tokens=3272,
        output_tokens=802,
        cache_read_tokens=52480,
        cache_creation_tokens=7,
        model=Some("deepseek-v4-pro"),
      ),
      status_code=200,
      created_at=1779755333,
      data_source="proxy",
    ),
  )
  let data =
    #|{
    #|  "role": "assistant",
    #|  "cost": 0.0023113,
    #|  "tokens": {
    #|    "input": 3272,
    #|    "output": 383,
    #|    "reasoning": 419,
    #|    "cache": { "write": 7, "read": 52480 }
    #|  },
    #|  "modelID": "deepseek-v4-pro",
    #|  "time": { "created": 1779755333700, "completed": 1779755350639 }
    #|}
  let result = stats.ingest_opencode_message_json(
    session_id="opencode-s1",
    message_id="msg-open-1",
    data~,
  )
  assert_eq(result.imported, 0)
  assert_eq(result.skipped, 1)
  assert_eq(stats.request_logs.length(), 1)
}

///|
test "opencode session import treats missing cache write like moongate" {
  let stats = TrafficStats::new()
  stats.record_request_log(
    RequestLog::new(
      request_id="proxy-open-cache-write",
      provider_id="opencode-provider",
      app_type="opencode",
      model="deepseek-v4-pro",
      usage=TokenUsage::new(
        input_tokens=3272,
        output_tokens=802,
        cache_read_tokens=52480,
        cache_creation_tokens=7,
        model=Some("deepseek-v4-pro"),
      ),
      status_code=200,
      created_at=1779755333,
      data_source="proxy",
    ),
  )
  let data =
    #|{
    #|  "role": "assistant",
    #|  "cost": 0.0023113,
    #|  "tokens": {
    #|    "input": 3272,
    #|    "output": 383,
    #|    "reasoning": 419,
    #|    "cache": { "read": 52480 }
    #|  },
    #|  "modelID": "deepseek-v4-pro",
    #|  "time": { "created": 1779755333700, "completed": 1779755350639 }
    #|}
  let result = stats.ingest_opencode_message_json(
    session_id="opencode-s1",
    message_id="msg-open-cache-write",
    data~,
  )
  assert_eq(result.imported, 0)
  assert_eq(result.skipped, 1)
  assert_eq(stats.request_logs.length(), 1)
}

///|
test "session timestamp parser handles offsets" {
  assert_eq(
    parse_session_timestamp_seconds("1970-01-01T08:00:10+08:00"),
    Some(10),
  )
  assert_eq(parse_session_timestamp_seconds("1970-01-01T00:00:10Z"), Some(10))
  assert_eq(parse_session_timestamp_seconds("bad"), None)
}
