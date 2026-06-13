///|
test "claude desktop model list matches ccs response shape" {
  json_inspect(claude_desktop_model_list_json(), content={
    "data": [
      {
        "type": "model",
        "id": "claude-sonnet-4-6",
        "created_at": "2024-01-01T00:00:00Z",
        "supports1m": true,
      },
      {
        "type": "model",
        "id": "claude-opus-4-8",
        "created_at": "2024-01-01T00:00:00Z",
        "supports1m": true,
      },
      {
        "type": "model",
        "id": "claude-haiku-4-5",
        "created_at": "2024-01-01T00:00:00Z",
        "supports1m": true,
      },
    ],
    "has_more": false,
    "first_id": "claude-sonnet-4-6",
    "last_id": "claude-haiku-4-5",
  })
}

///|
test "codex compact responses keep compact backend endpoint" {
  assert_eq(
    codex_backend_responses_endpoint(false),
    "/backend-api/codex/responses",
  )
  assert_eq(
    codex_backend_responses_endpoint(true),
    "/backend-api/codex/responses/compact",
  )
}
