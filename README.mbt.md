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
MoonBook, Moontown, Moondesk, or any other local probe. They expose the
gateway URLs, status file, capabilities, and command map needed by suite
launchers. `suite write-status` writes the same status contract to
`~/.moonstat/suite-status.json` by default. The contract also includes a
machine-readable `suite_integrations` object:

- MoonClaw gets local OpenAI/Anthropic base URLs, default model, health URL, and
  env names.
- MoonBook gets usage summary/log/trend/data-source URLs plus the durable usage
  log and pricing files.
- Moontown gets health/status/stats and provider-limit probe URLs.
- Moondesk gets the status file, health/status/stats, model catalog, and Claude
  Desktop gateway base URL.

## Proxy Surface

Moonstat currently exposes the ccs-compatible local routes below:

- `GET /health`
- `GET /status`
- `GET /stats`
- `GET /proxy/status`
- `POST /start_proxy_server`
- `POST /stop_proxy_server`
- `POST /stop_proxy_with_restore`
- `GET /proxy/config`
- `POST /proxy/config`
- `GET /proxy/global-config`
- `POST /proxy/global-config`
- `GET /proxy/app-config?app_type=claude`
- `POST /proxy/app-config?app_type=claude&enabled=true`
- `GET /proxy/default-cost-multiplier?app_type=claude`
- `POST /proxy/default-cost-multiplier?app_type=claude&value=1.25`
- `POST /set_default_cost_multiplier?app_type=claude&value=1.25`
- `GET /proxy/pricing-model-source?app_type=claude`
- `POST /proxy/pricing-model-source?app_type=claude&value=request`
- `POST /set_pricing_model_source?app_type=claude&value=request`
- `GET /proxy/provider-health?app_type=claude&provider_id=codex-oauth`
- `GET /get_provider_health?app_type=claude&provider_id=codex-oauth`
- `GET /proxy/circuit-breaker-config`
- `GET /get_circuit_breaker_config`
- `POST /proxy/circuit-breaker-config`
- `POST /update_circuit_breaker_config`
- `GET /proxy/circuit-breaker-stats?app_type=claude&provider_id=codex-oauth`
- `GET /get_circuit_breaker_stats?app_type=claude&provider_id=codex-oauth`
- `POST /proxy/reset-circuit-breaker?app_type=claude&provider_id=codex-oauth`
- `POST /reset_circuit_breaker?app_type=claude&provider_id=codex-oauth`
- `GET /proxy/failover-queue?app_type=claude`
- `GET /get_failover_queue?app_type=claude`
- `POST /proxy/failover-queue?app_type=claude&provider_id=codex-oauth`
- `POST /add_to_failover_queue?app_type=claude&provider_id=codex-oauth`
- `DELETE /proxy/failover-queue?app_type=claude&provider_id=codex-oauth`
- `DELETE /remove_from_failover_queue?app_type=claude&provider_id=codex-oauth`
- `GET /proxy/available-failover-providers?app_type=claude`
- `GET /get_available_providers_for_failover?app_type=claude`
- `GET /proxy/auto-failover-enabled?app_type=claude`
- `GET /get_auto_failover_enabled?app_type=claude`
- `POST /proxy/auto-failover-enabled?app_type=claude&enabled=true`
- `POST /set_auto_failover_enabled?app_type=claude&enabled=true`
- `GET /proxy/takeover-status`
- `POST /proxy/takeover-status?app_type=claude&enabled=true`
- `GET /is_live_takeover_active`
- `POST /switch_proxy_provider?app_type=claude&provider_id=codex-oauth`
- `GET /get_providers?app=codex`
- `GET /get_current_provider?app=codex`
- `POST /add_provider?app=codex&id=custom&name=Custom`
- `POST /update_provider?app=codex&id=custom&name=Custom`
- `DELETE /delete_provider?app=codex&id=custom`
- `DELETE /remove_provider_from_live_config?app=codex&id=custom`
- `POST /switch_provider?app=codex&id=custom`
- `GET /read_live_provider_settings?app=codex`
- `GET /get_opencode_live_provider_ids`
- `GET /get_openclaw_live_provider_ids`
- `GET /get_hermes_live_provider_ids`
- `POST /import_opencode_providers_from_live`
- `POST /import_openclaw_providers_from_live`
- `POST /import_hermes_providers_from_live`
- `GET /get_universal_providers`
- `GET /get_universal_provider?id=custom`
- `POST /upsert_universal_provider?id=custom&name=Custom&apps=claude,codex`
- `DELETE|POST /delete_universal_provider?id=custom`
- `POST /sync_universal_provider?id=custom`
- `GET|POST /test_api_endpoints?urls=https://api.example.com/v1`
- `POST /update_providers_sort_order?app=codex&id=custom&sortIndex=0`
- `GET /get_custom_endpoints?app=codex&providerId=custom`
- `POST /add_custom_endpoint?app=codex&providerId=custom&url=https://api.backup.example.com/v1`
- `DELETE /remove_custom_endpoint?app=codex&providerId=custom&url=https://api.backup.example.com/v1`
- `POST /update_endpoint_last_used?app=codex&providerId=custom&url=https://api.backup.example.com/v1`
- `GET /proxy/running`
- `GET /is_proxy_running`
- `GET /usage/logs`
- `GET /usage/summary`
- `GET /usage/summary/by-app`
- `GET /usage/trends`
- `GET /usage/provider-limits`
- `GET /usage/provider-stats`
- `GET /usage/model-stats`
- `GET /usage/data-sources`
- `POST /usage/sync-session`
- `GET /usage/model-pricing`
- `POST /usage/model-pricing`
- `DELETE /usage/model-pricing`
- `GET /usage/request-detail/{request_id}`
- `GET /queryProviderUsage?providerId=codex-oauth&app=codex`
- `POST /testUsageScript?providerId=codex-oauth&app=codex`
- `POST /stream_check_provider?appType=codex&providerId=codex-oauth`
- `POST /stream_check_all_providers?appType=codex&proxyTargetsOnly=true`
- `GET /get_stream_check_config`
- `POST /save_stream_check_config?codexModel=gpt-5.5@low&timeoutSecs=45`
- CCS command-name aliases: `GET /get_usage_summary`,
  `GET /get_usage_summary_by_app`, `GET /get_usage_trends`,
  `GET /get_provider_stats`, `GET /get_model_stats`, `GET /get_request_logs`,
  `GET /get_request_detail?requestId=...`, `GET /get_model_pricing`,
  `POST /update_model_pricing`, `DELETE /delete_model_pricing`,
  `GET /check_provider_limits`, `POST /sync_session_usage`,
  `GET /get_usage_data_sources`, `GET /queryProviderUsage`, and
  `POST /testUsageScript`.
  Stream check command aliases `stream_check_provider`,
  `stream_check_all_providers`, `get_stream_check_config`, and
  `save_stream_check_config` expose the ccs camelCase config/result JSON
  contract for standalone provider readiness checks.
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
- `ANY /v1beta/*path`
- `ANY /gemini/v1beta/*path`
- `ANY /gemini/v1/*path`

`/status`, `/proxy/status`, and `/stats` include ccs-style request counts,
success/failure counts, active connections, token totals, cache token totals,
last request time, last error, current provider metadata, and success rate.
`/proxy/config`, `/proxy/takeover-status`, and `/proxy/running` expose
standalone HTTP aliases for the ccs proxy command shapes. Their POST aliases
accept either ccs camelCase JSON bodies or query parameters for standalone
scripts. `/proxy/global-config`, `/proxy/app-config`,
`/proxy/default-cost-multiplier`, and `/proxy/pricing-model-source` expose the
ccs v3 global/app config and pricing defaults using the same env-backed
settings that request accounting uses. Global/app config and takeover setters
mutate Moonstat's standalone runtime state without requiring the CCS database.
`/proxy/provider-health`, `/proxy/circuit-breaker-config`,
`/proxy/circuit-breaker-stats`, and `/proxy/reset-circuit-breaker` expose
ccs-style failover health and circuit-breaker control over Moonstat's in-memory
router state. The circuit-breaker config update accepts the same camelCase
shape as ccs, including `failureThreshold`, `successThreshold`,
`timeoutSeconds`, `errorRateThreshold`, and `minRequests`, and hot-applies it to
existing breakers. `/proxy/failover-queue`,
`/proxy/available-failover-providers`, and `/proxy/auto-failover-enabled`
mirror the ccs failover queue and app auto-failover command shapes using
Moonstat's standalone provider router state. The standalone CLI accepts CCS
proxy, failover, provider, usage, and stream-check command names directly, for
example `moonstat start_proxy_server`,
`moonstat update_proxy_config_for_app --appType codex --enabled true`, and
`moonstat get_usage_summary --appType codex`.
The `/get_providers`,
`/get_current_provider`, `/add_provider`, `/update_provider`,
`/delete_provider`, `/remove_provider_from_live_config`, and
`/switch_provider` mirror ccs provider CRUD/current-provider command shapes
against that same standalone provider router state. `/read_live_provider_settings`,
`/test_api_endpoints`, and `/update_providers_sort_order` mirror the ccs live
settings, endpoint latency result, and `sortIndex` command shapes.
`/get_opencode_live_provider_ids`, `/get_openclaw_live_provider_ids`,
`/get_hermes_live_provider_ids`, and the matching `import_*_from_live`
commands expose the same suite-facing provider import/ID command surface against
Moonstat's standalone provider router state. `/get_universal_providers`,
`/get_universal_provider`, `/upsert_universal_provider`,
`/delete_universal_provider`, and `/sync_universal_provider` preserve the ccs
universal-provider JSON shape and can sync enabled Claude/Codex/Gemini apps into
concrete router providers named `universal-claude-*`, `universal-codex-*`, and
`universal-gemini-*`. `/get_custom_endpoints`,
`/add_custom_endpoint`, `/remove_custom_endpoint`, and `/update_endpoint_last_used`
mirror ccs provider custom endpoint metadata, including URL normalization,
newest-first listing, and best-effort last-used updates.
`/usage/logs` returns
recent `proxy_request_logs` rows with ccs-style provider/app/model, token,
cache-token, cost, latency, status, session, streaming, and data-source fields.
Gateway startup loads file-backed usage state from
`~/.moonstat/proxy_request_logs.jsonl` and session sync offsets from
`~/.moonstat/session_log_sync.jsonl`; editable ccs-style model pricing is stored
in `~/.moonstat/model_pricing.jsonl`. Manual `moonstat usage sync` saves usage
state after importing Claude, Codex, Gemini, and OpenCode-compatible session logs.
OpenCode sync reads `opencode.db` directly when `sqlite3` is available, honoring
`OPENCODE_DB` and `XDG_DATA_HOME` like ccs. It also accepts JSONL rows exported
from `opencode.db` with `session_id`, `message_id`, and `data` fields as a
fallback, defaulting to `~/.local/share/opencode/opencode.messages.jsonl`.

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

Claude model rerouting honors the same ccs environment names:
`ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`,
`ANTHROPIC_DEFAULT_SONNET_MODEL`, and `ANTHROPIC_DEFAULT_OPUS_MODEL`.
`MOONSTAT_`-prefixed aliases are also accepted. When present, Moonstat maps the
client's Haiku/Sonnet/Opus/default request model to that upstream model and
strips the local `[1M]` context marker before forwarding.

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
