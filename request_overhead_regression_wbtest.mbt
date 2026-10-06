///|
// Reference snapshot construction from the baseline, retained only for tests.
fn TrafficStats::usage_store_json(self : TrafficStats) -> Json {
  let request_logs : Array[Json] = []
  for log in self.request_logs {
    request_logs.push(log.to_json())
  }
  let daily_rollups : Array[Json] = []
  for rollup in self.daily_rollups {
    daily_rollups.push(rollup.to_json())
  }
  let session_sync : Array[Json] = []
  for file_path, state in self.session_sync_state {
    session_sync.push(
      {
        "filePath": Json::string(file_path),
        "lastModified": Json::number(state.last_modified.to_double()),
        "lastLineOffset": Json::number(state.last_line_offset.to_double()),
      }.to_json(),
    )
  }
  {
    "schemaVersion": Json::number(
      MOONGATE_USAGE_STORE_SCHEMA_VERSION.to_double(),
    ),
    "requestLogs": Json::array(request_logs),
    "dailyRollups": Json::array(daily_rollups),
    "sessionSync": Json::array(session_sync),
  }.to_json()
}

///|
async test "overhead snapshot remains equivalent through updates and reload" {
  let stats = TrafficStats::new()
  let dir = "/tmp/moongate-overhead-equivalence-\{@async.now()}"
  stats.enable_persistent_store(storage_dir=dir)
  for i in 0..<503 {
    stats.record_request_log(
      RequestLog::new(
        request_id="row-\{i}",
        provider_id="synthetic",
        app_type="codex",
        model="synthetic-priced",
        usage=TokenUsage::new(input_tokens=10, output_tokens=5),
        status_code=200,
        created_at=1791120000,
        session_id=Some("quote\"\\\n你🌙"),
      ),
    )
  }
  stats.session_sync_state.set(
    "/synthetic/你\".jsonl",
    SessionFileSyncState::new(last_modified=7L, last_line_offset=9),
  )
  for _ in 0..<2 {
    stats.save_persistent_store()
    let saved = @json.parse(
      @fsx.read_file(@pathx.join(dir, MOONGATE_USAGE_STORE_FILE)),
    )
    assert_eq(saved, stats.usage_store_json())
  }
  assert_eq(stats.request_logs.length(), 500)
  assert_eq(
    stats.backfill_missing_usage_costs(
      [mp("synthetic-priced", "Synthetic", "2", "4", "0", "0")],
      {},
    ),
    500,
  )
  stats.session_sync_state.set(
    "/synthetic/你\".jsonl",
    SessionFileSyncState::new(last_modified=8L, last_line_offset=10),
  )
  stats.save_persistent_store()
  let saved = @json.parse(
    @fsx.read_file(@pathx.join(dir, MOONGATE_USAGE_STORE_FILE)),
  )
  assert_eq(saved, stats.usage_store_json())
  let loaded = TrafficStats::new()
  loaded.load_persistent_store(storage_dir=dir)
  assert_eq(loaded.usage_store_json(), stats.usage_store_json())
  assert_eq(loaded.request_logs[0].total_cost_usd, "0.00004")
  ignore(loaded.rollup_request_logs_before(1791120001))
  loaded.save_persistent_store()
  assert_eq(
    @json.parse(@fsx.read_file(@pathx.join(dir, MOONGATE_USAGE_STORE_FILE))),
    loaded.usage_store_json(),
  )
}

///|
async test "overhead streaming differential fixture preserves exact events" {
  let state = ChatToCodexResponsesStreamState::new_with_context(
    "synthetic-model",
    codex_chat_empty_tool_context(),
  )
  let fragments : Array[Json] = [
    {
      "id": "chatcmpl_fixture",
      "model": "synthetic-model",
      "created": 10,
      "choices": [{ "delta": { "role": "assistant", "content": "" } }],
    },
    { "choices": [{ "delta": { "content": "你" } }] },
    { "choices": [{ "delta": { "content": "🌙\n\"" } }] },
    {
      "choices": [
        {
          "delta": {
            "tool_calls": [
              {
                "index": 0,
                "id": "tool_a",
                "function": { "name": "alpha", "arguments": "{\"text\":\"" },
              },
            ],
          },
        },
      ],
    },
    {
      "choices": [
        {
          "delta": {
            "tool_calls": [
              {
                "index": 1,
                "id": "tool_b",
                "function": { "name": "beta", "arguments": "{\"n\":" },
              },
            ],
          },
        },
      ],
    },
    {
      "choices": [
        {
          "delta": {
            "tool_calls": [
              { "index": 0, "function": { "arguments": "你🌙" } },
            ],
          },
        },
      ],
    },
    {
      "choices": [
        {
          "delta": {
            "tool_calls": [{ "index": 1, "function": { "arguments": "1}" } }],
          },
        },
      ],
    },
    {
      "choices": [
        {
          "delta": {
            "tool_calls": [{ "index": 0, "function": { "arguments": "\"}" } }],
          },
        },
      ],
    },
    { "error": { "message": "synthetic error fixture" } },
    {
      "choices": [{ "delta": {}, "finish_reason": "tool_calls" }],
      "usage": { "prompt_tokens": 10, "completion_tokens": 5 },
    },
  ]
  let events : Array[Json] = []
  for fragment in fragments {
    let (_, _, next) = openai_chat_stream_data_to_codex_response_events(
      fragment.stringify(),
      state,
    )
    events.append(next)
  }
  let (_, invalid, invalid_events) = openai_chat_stream_data_to_codex_response_events(
    "{", state,
  )
  assert_eq(invalid, None)
  assert_eq(invalid_events.length(), 0)
  let before_done = events.copy()
  let (done, _, final_events) = openai_chat_stream_data_to_codex_response_events(
    "[DONE]", state,
  )
  assert_true(done)
  events.append(final_events)
  assert_eq(state.finish().length(), 0)
  assert_eq(state.finish_text().length(), 0)
  assert_eq(state.finish_tools().length(), 0)
  let output : Json = { "before_done": before_done, "complete": events }
  let destination = @env.get_env_var("MOONGATE_PERF_FIXTURE_OUTPUT").unwrap_or(
    "/tmp/moongate-overhead-stream-fixture.json",
  )
  @fsx.write_to_file(destination, output.stringify())
  println("stream fixture events=\{events.length()}")
}
