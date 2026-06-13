# Moonstat

Moonstat is the MoonBit-native local proxy/statistics gateway for the Moon
suite. It is a standalone app and also fits beside:

- MoonClaw: agent runtime and job executor
- MoonBook: durable books, wiki, and output workspace
- Moontown: scheduler and town control plane
- Moondesk: desktop operator shell

The proxy listens on the same default address as ccs: `127.0.0.1:15721`.

## Run

```sh
moon run cmd/main -- start
```

Use a custom bind address or port:

```sh
moon run cmd/main -- start --host 127.0.0.1 --port 15721 --model gpt-5
```

Login uses Codex OAuth credentials:

```sh
moon run cmd/main -- login
```

Status and counters:

```sh
moon run cmd/main -- health
moon run cmd/main -- status
moon run cmd/main -- stats
moon run cmd/main -- usage logs
```

Provider model discovery uses the same ccs-compatible `/v1/models` candidate
logic and returns the same frontend wire shape, `[{ "id": "...", "ownedBy":
"..." }]`:

```sh
moon run cmd/main -- models fetch --base-url https://api.example.com --api-key sk-...
moon run cmd/main -- models candidates --base-url https://api.deepseek.com/anthropic
```

Moon suite discovery:

```sh
moon run cmd/main -- suite manifest
moon run cmd/main -- suite status
moon run cmd/main -- suite write-status
```

`suite manifest` and `suite status` print JSON contracts for MoonClaw,
MoonBook, Moontown, Moondesk, or any other local probe. `suite write-status`
writes the same status contract to `~/.moonstat/suite-status.json` by default.

## Proxy Surface

Moonstat currently exposes the ccs-compatible local routes below:

- `GET /health`
- `GET /status`
- `GET /stats`
- `GET /usage/logs`
- `GET /models`
- `GET /v1/models`
- `GET /claude-desktop/v1/models`
- `POST /v1/messages`
- `POST /claude/v1/messages`
- `POST /claude-desktop/v1/messages`
- `POST /responses`
- `POST /v1/responses`
- `POST /v1/v1/responses`
- `POST /codex/v1/responses`
- `POST /responses/compact`
- `POST /v1/responses/compact`
- `POST /v1/v1/responses/compact`
- `POST /codex/v1/responses/compact`
- `POST /chat/completions`
- `POST /v1/chat/completions`
- `POST /v1/v1/chat/completions`
- `POST /codex/v1/chat/completions`
- `GET|POST /v1beta/*path`
- `GET|POST /gemini/v1beta/*path`
- `GET|POST /gemini/v1/*path`

`/status` and `/stats` include ccs-style request counts, success/failure
counts, active connections, token totals, cache token totals, last request time,
last error, current provider metadata, and success rate. `/usage/logs` returns
recent in-memory `proxy_request_logs` rows with ccs-style provider/app/model,
token, cache-token, cost, latency, status, session, streaming, and data-source
fields.

Claude Desktop gateway routes are open by default for standalone local use. Set
`MOONSTAT_CLAUDE_DESKTOP_TOKEN` or `CLAUDE_DESKTOP_GATEWAY_TOKEN` to require
`Authorization: Bearer <token>` on `/claude-desktop/v1/models` and
`/claude-desktop/v1/messages`, matching ccs gateway-token behavior without the
ccs database dependency.

For Claude Desktop standalone setup, run
`moonstat claude-desktop install --port 15721`. Moonstat writes the same gateway
profile shape as ccs under Claude Desktop's `Claude-3p/configLibrary`, stores a
local token at `~/.moonstat/claude_desktop_gateway_token`, and the gateway reads
that token automatically. Use `moonstat claude-desktop uninstall` to restore the
profile mode.

For Codex standalone setup, run
`moonstat codex install --port 15721 --model gpt-5`. Moonstat writes a managed
Moonstat provider block to `~/.codex/config.toml` using
`wire_api = "responses"` and `base_url = "http://127.0.0.1:15721/v1"`, matching
ccs proxy takeover expectations while preserving unrelated user config. Use
`moonstat codex uninstall` to remove only the managed block.

Gemini routes proxy to `https://generativelanguage.googleapis.com` by default
and accept either a `?key=` query parameter or `GEMINI_API_KEY` /
`GOOGLE_API_KEY` in the environment. Set `GOOGLE_GEMINI_BASE_URL` or
`GEMINI_BASE_URL` to route through another Gemini-compatible base URL. Set
`MOONSTAT_GEMINI_FULL_URL=1` or `GEMINI_FULL_URL=1` when the base URL is an
opaque relay endpoint that should not have the Gemini model path appended.
Aliased `/gemini/v1beta/...` and `/gemini/v1/...` requests are normalized back
to the upstream `/v1beta/...` and `/v1/...` paths.

## Suite Role

Moonstat is the network edge for local Moon apps. Point Codex-style clients,
MoonClaw provider checks, or Moondesk/Moontown integration probes at
`http://127.0.0.1:15721` and use `/status` or `/stats` for health dashboards.

MoonBook remains the durable output owner, Moontown owns scheduling and standing
goals, MoonClaw owns execution, and Moondesk owns the local operator UI.
Moonstat owns local traffic rerouting and usage/statistics accounting.
