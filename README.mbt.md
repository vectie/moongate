# Moonstat

Moonstat is the MoonBit-native local proxy/statistics gateway for the Moon
suite. It is a standalone app and also fits beside:

- MoonClaw: agent runtime and job executor
- MoonBook: durable books, wiki, and output workspace
- Moontown: scheduler and town control plane
- Moondesk: desktop operator shell

The proxy listens on `127.0.0.1:15721` by default.

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
moon run cmd/main -- auth status
moon run cmd/main -- auth start-login
moon run cmd/main -- auth poll --device-code dev_... --user-code USER-CODE
```

Status and counters:

```sh
moon run cmd/main -- health
moon run cmd/main -- status
moon run cmd/main -- stats
curl http://127.0.0.1:15721/metrics
moon run cmd/main -- usage logs
```

Provider model discovery probes `/v1/models`-style catalogs and returns the
Moonstat frontend wire shape, `[{ "id": "...", "ownedBy": "..." }]`:

```sh
moon run cmd/main -- models fetch --base-url https://api.example.com --api-key sk-...
moon run cmd/main -- usage codex-oauth-models --account-id acct_...
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
`~/.moonsuite/suite-status.json` by default, and `start` refreshes that file
when the gateway boots. The contract also includes a machine-readable
`suite_integrations` object:

- MoonClaw gets local OpenAI/Anthropic base URLs, env names, a
  `moonclaw_providers_file_json` provider entry, and the project/home config
  paths where MoonClaw can load that entry.
- MoonBook gets usage summary/log/trend/data-source URLs, the durable usage log
  and pricing files, and the MoonBook adapter package names used by Moondesk and
  Moontown.
- Moontown gets health/status/stats and provider-limit probe URLs plus the
  MoonClaw provider-manifest path/command used for MoonBook task providers.
- Moondesk gets the status file, health/status/stats, model catalog, and Claude
  Desktop gateway base URL plus adapter packages for MoonClaw, MoonBook, and
  Moontown.

## Proxy Surface

Moonstat currently exposes the standalone local routes below:

- `GET /health`
- `GET /status`
- `GET /stats`
- `GET /metrics`
- `GET /proxy/status`
- `POST /proxy/start`
- `POST /proxy/stop`
- `POST /proxy/stop-with-restore`
- `GET /proxy/config`
- `POST /proxy/config`
- `GET /proxy/global-config`
- `POST /proxy/global-config`
- `GET /proxy/global-url`
- `POST /proxy/global-url?url=http://127.0.0.1:7890`
- `GET|POST /proxy/test-url?url=http://127.0.0.1:7890`
- `GET /proxy/upstream-status`
- `GET /proxy/local-proxies`
- `GET /proxy/app-config?app_type=claude`
- `POST /proxy/app-config?app_type=claude&enabled=true`
- `GET /proxy/default-cost-multiplier?app_type=claude`
- `POST /proxy/default-cost-multiplier?app_type=claude&value=1.25`
- `GET /proxy/pricing-model-source?app_type=claude`
- `POST /proxy/pricing-model-source?app_type=claude&value=request`
- `GET /proxy/provider-health?app_type=claude&provider_id=codex-oauth`
- `GET /proxy/circuit-breaker-config`
- `POST /proxy/circuit-breaker-config`
- `GET /proxy/circuit-breaker-stats?app_type=claude&provider_id=codex-oauth`
- `POST /proxy/reset-circuit-breaker?app_type=claude&provider_id=codex-oauth`
- `GET /proxy/failover-queue?app_type=claude`
- `POST /proxy/failover-queue?app_type=claude&provider_id=codex-oauth`
- `DELETE /proxy/failover-queue?app_type=claude&provider_id=codex-oauth`
- `GET /proxy/available-failover-providers?app_type=claude`
- `GET /proxy/auto-failover-enabled?app_type=claude`
- `POST /proxy/auto-failover-enabled?app_type=claude&enabled=true`
- `GET /proxy/takeover-status`
- `POST /proxy/takeover-status?app_type=claude&enabled=true`
- `POST /proxy/switch-provider?app_type=claude&provider_id=codex-oauth`
- `POST /proxy/sync-current-providers-live`
- `POST /proxy/import-default-config?app=codex`
- `GET /providers?app=codex`
- `GET /providers/current?app=codex`
- `POST /providers?app=codex&id=custom&name=Custom`
- `POST /providers/update?app=codex&id=custom&name=Custom`
- `DELETE /providers?app=codex&id=custom`
- `DELETE /providers/live?app=codex&id=custom`
- `POST /providers/switch?app=codex&id=custom`
- `GET /providers/live-settings?app=codex`
- `GET /providers/live-ids?app=openclaw`
- `GET /providers/live-provider?app=openclaw&providerId=custom`
- `POST /providers/import-live?app=openclaw`
- `GET /openclaw/config-health`
- `GET /openclaw/default-model`
- `POST /openclaw/default-model?primary=gpt-5&fallbacks=sonnet,opus`
- `GET /openclaw/model-catalog`
- `POST /openclaw/model-catalog?catalog={"fast":{"alias":"f"}}`
- `GET /openclaw/agents-defaults`
- `POST /openclaw/agents-defaults?defaults={"model":{"primary":"gpt-5"}}`
- `GET /openclaw/env`
- `POST /openclaw/env?key=OPENAI_API_KEY&value=...`
- `GET /openclaw/tools`
- `POST /openclaw/tools?allow=bash,read&deny=write`
- `GET /hermes/model-config`
- `GET /hermes/memory?kind=memory`
- `POST /hermes/memory?kind=memory&content=...`
- `GET /hermes/memory-limits`
- `POST /hermes/memory-enabled?kind=user&enabled=false`
- `GET /hermes/web-ui?path=/`
- `POST /hermes/dashboard`
- `GET /config/claude/status`
- `GET /config/status?app=codex`
- `GET /config/claude-code/path`
- `GET /config/dir?app=codex`
- `GET /config/folder/open?app=codex`
- `GET /files/directories/pick?defaultPath=/tmp`
- `GET|POST /runtime/open-external?url=https://github.com/vectie/moonstat`
- `GET|POST /runtime/clipboard/text?text=hello`
- `GET|POST /runtime/updates/check`
- `GET|POST /runtime/tray-menu/update`
- `GET /runtime/portable-mode`
- `GET /runtime/init-error`
- `GET /runtime/migration-result`
- `GET /runtime/skills-migration-result`
- `GET|POST /tools/versions?tools=codex,claude`
- `GET|POST /runtime/window-theme?theme=dark`
- `GET|POST /runtime/lightweight-mode/enter`
- `GET|POST /runtime/lightweight-mode/exit`
- `GET /runtime/lightweight-mode`
- `GET|POST /files/dialogs/save?defaultName=config.json`
- `GET|POST /files/dialogs/open`
- `GET|POST /files/dialogs/open-zip`
- `GET /skills/installed`
- `GET /skills/backups`
- `POST /skills/backups/delete?backupId=traffic-stats-1`
- `POST /skills/backups/restore?backupId=traffic-stats-1&currentApp=claude`
- `POST /skills/install-unified?directory=traffic-stats&currentApp=codex`
- `POST /skills/uninstall-unified?id=traffic-stats`
- `POST /skills/toggle-app?id=traffic-stats&app=hermes&enabled=true`
- `GET /skills/unmanaged`
- `POST /skills/import-apps`
- `GET /skills/discover`
- `GET /skills/updates`
- `POST /skills/update?id=traffic-stats`
- `POST /skills/migrate-storage`
- `GET|POST /skills/search?query=proxy&limit=10`
- `GET /skills`
- `GET /skills/app?app=codex`
- `GET /skills/repos`
- `POST /skills/repos?owner=vectie&name=moonstat-skills&branch=main`
- `POST /skills/repos/remove?owner=vectie&name=moonstat-skills`
- `POST /skills/install-zip?filePath=/tmp/traffic-stats&currentApp=codex`
- `GET /get_claude_desktop_status`
- `GET /get_claude_desktop_default_routes`
- `POST /import_claude_desktop_providers_from_claude`
- `POST /ensure_claude_desktop_official_provider`
- `GET /config/app-path`
- `GET /config/app-folder/open`
- `GET /settings`
- `POST /settings`
- `POST /runtime/restart`
- `POST /runtime/updates/install-restart`
- `GET /settings/app-config-dir`
- `POST /settings/app-config-dir?path=/tmp/moonstat`
- `POST /settings/auto-launch?enabled=true`
- `GET /settings/auto-launch`
- `GET /settings/rectifier`
- `POST /settings/rectifier?enabled=true`
- `GET /settings/optimizer`
- `POST /settings/optimizer?cacheTtl=5m`
- `GET /settings/copilot-optimizer`
- `POST /settings/copilot-optimizer?warmupModel=gpt-5-mini`
- `GET /settings/log`
- `POST /settings/log?level=debug`
- `GET /config/snippets/claude`
- `POST /config/snippets/claude?snippet={}`
- `GET /config/snippets?appType=codex`
- `POST /config/snippets?appType=codex&snippet=model=gpt-5`
- `GET|POST /config/snippets/extract?appType=claude&settingsConfig={}`
- `GET /config/env/conflicts?app=claude`
- `POST /config/env/delete`
- `POST /config/env/restore?backupPath=...`
- `GET /mcp/claude/status`
- `GET /mcp/claude/config`
- `POST /mcp/claude/servers?server={"id":"filesystem"}`
- `DELETE /mcp/claude/servers?id=filesystem`
- `GET /mcp/validate?command=npx`
- `GET /mcp/config?app=codex`
- `POST /mcp/config/servers?app=codex&server={"id":"filesystem"}`
- `DELETE /mcp/config/servers?id=filesystem`
- `POST /mcp/enabled?app=codex&id=filesystem&enabled=true`
- `GET /mcp/servers`
- `POST /mcp/servers?server={"id":"filesystem"}`
- `DELETE /mcp/servers?id=filesystem`
- `POST /mcp/apps/toggle?app=codex&id=filesystem&enabled=true`
- `POST /mcp/import-apps`
- `GET /plugin/claude/status`
- `GET /plugin/claude/config`
- `POST /plugin/claude/config?official=false`
- `GET /plugin/claude/applied`
- `POST /plugin/claude/onboarding-skip`
- `POST /plugin/claude/onboarding-skip/clear`
- `GET /workspace/memory`
- `GET /workspace/memory/file?filename=2026-06-14.md`
- `POST /workspace/memory/write?filename=2026-06-14.md&content=...`
- `GET|POST /workspace/memory/search?query=plan`
- `DELETE /workspace/memory/file?filename=2026-06-14.md`
- `POST /workspace/memory/delete?filename=2026-06-14.md`
- `GET /workspace/files?filename=AGENTS.md`
- `POST /workspace/files?filename=AGENTS.md&content=...`
- `GET|POST /workspace/open?subdir=memory`
- `GET /prompts?app=codex`
- `POST /prompts?app=codex&id=review&content=Check`
- `DELETE /prompts?app=codex&id=review`
- `POST /prompts/enable?app=codex&id=review`
- `POST /prompts/import-file?app=codex&path=/tmp/prompts.md`
- `GET /prompts/current-file?app=codex&path=/tmp/prompts.md`
- `POST /providers/import-live?app=opencode`
- `POST /providers/import-live?app=openclaw`
- `POST /providers/import-live?app=hermes`
- `GET /providers/universal`
- `GET /providers/universal/item?id=custom`
- `POST /providers/universal?id=custom&name=Custom&apps=claude,codex`
- `DELETE|POST /providers/universal?id=custom`
- `POST /providers/universal/sync?id=custom`
- `GET|POST /providers/test-endpoints?urls=https://api.example.com/v1`
- `POST /providers/sort-order?app=codex&id=custom&sortIndex=0`
- `GET /providers/endpoints/list?app=codex&providerId=custom`
- `POST /providers/endpoints?app=codex&providerId=custom&url=https://api.backup.example.com/v1`
- `DELETE /providers/endpoints?app=codex&providerId=custom&url=https://api.backup.example.com/v1`
- `POST /providers/endpoints/touch?app=codex&providerId=custom&url=https://api.backup.example.com/v1`
- `GET /proxy/running`
- `GET /is_proxy_running`
- `GET|POST /usage/logs`
- `GET|POST /usage/summary`
- `GET|POST /usage/summary/by-app`
- `GET|POST /usage/trends`
- `GET|POST /usage/provider-limits`
- `GET|POST /usage/provider-stats`
- `GET|POST /usage/model-stats`
- `GET|POST /usage/data-sources`
- `POST /usage/sync-session`
- `GET /usage/model-pricing`
- `POST /usage/model-pricing`
- `DELETE /usage/model-pricing`
- `GET /usage/request-detail/{request_id}`
- `GET|POST /usage/provider-usage?providerId=codex-oauth&app=codex`
- `GET|POST /usage/balance?baseUrl=https://api.deepseek.com&apiKey=...`
- `GET|POST /usage/subscription-quota?tool=codex`
- `GET|POST /usage/codex-oauth-quota?accountId=...`
- `GET|POST /usage/codex-oauth-models?accountId=...`
- `GET|POST /usage/coding-plan-quota?baseUrl=https://api.kimi.com/coding/v1&apiKey=...`
- `GET|POST /auth/status?authProvider=codex_oauth`
- `GET|POST /auth/accounts?authProvider=codex_oauth`
- `GET|POST /auth/login?authProvider=codex_oauth`
- `GET|POST /auth/poll?authProvider=codex_oauth&deviceCode=...`
- `DELETE|POST /auth/account?authProvider=codex_oauth&accountId=...`
- `GET|POST /auth/default-account?authProvider=codex_oauth&accountId=...`
- `GET|POST /auth/logout?authProvider=codex_oauth`
- `GET|POST /auth/status?authProvider=github_copilot`
- `GET|POST /auth/login?authProvider=github_copilot&githubDomain=github.com`
- `GET|POST /auth/poll?authProvider=github_copilot&deviceCode=...`
- `GET /copilot/status`
- `GET /copilot/accounts`
- `GET /copilot/authenticated`
- `GET|POST /copilot/device-flow?githubDomain=github.com`
- `GET|POST /copilot/poll-auth?deviceCode=...`
- `GET|POST /copilot/poll-account?deviceCode=...`
- `DELETE|POST /copilot/account?accountId=...`
- `GET|POST /copilot/default-account?accountId=...`
- `GET|POST /copilot/logout`
- `GET /copilot/token?accountId=...`
- `GET /copilot/models?accountId=...`
- `GET /copilot/usage?accountId=...`
- `POST /usage/test-script?providerId=codex-oauth&app=codex`
- `POST /proxy/stream-check/provider?appType=codex&providerId=codex-oauth`
- `POST /proxy/stream-check/all?appType=codex&proxyTargetsOnly=true`
- `GET /proxy/stream-check/config`
- `POST /proxy/stream-check/config?codexModel=gpt-5.5@low&timeoutSecs=45`
- `GET /models`
- `GET /v1/models`
- `GET|POST /config/models?baseUrl=https://api.example.com&apiKey=sk-...`
- `GET /claude-desktop/v1/models`
- `POST /v1/messages`
- `POST /claude-desktop/v1/messages`
- `POST /responses`
- `POST /v1/responses`
- `POST /responses/compact`
- `POST /v1/responses/compact`
- `POST /chat/completions`
- `POST /v1/chat/completions`
- `POST /openclaw/v1/chat/completions`
- `ANY /v1beta/*path`
- `ANY /gemini/v1beta/*path`
- `ANY /gemini/v1/*path`

`/status`, `/proxy/status`, and `/stats` include Moonstat request counts,
success/failure counts, active connections, token totals, cache token totals,
last request time, last error, current provider metadata, and success rate.
`/proxy/config`, `/proxy/takeover-status`, and `/proxy/running` expose
standalone HTTP endpoints for proxy control. Their POST endpoints
accept either camelCase JSON bodies or query parameters for standalone
scripts. `/proxy/global-config`, `/proxy/app-config`,
`/proxy/default-cost-multiplier`, and `/proxy/pricing-model-source` expose the
Moonstat global/app config and pricing defaults using the same env-backed
settings that request accounting uses. Global/app config and takeover setters
mutate Moonstat's standalone runtime state without requiring an external
database.
`/proxy/provider-health`, `/proxy/circuit-breaker-config`,
`/proxy/circuit-breaker-stats`, and `/proxy/reset-circuit-breaker` expose
failover health and circuit-breaker control over Moonstat's in-memory
router state. The circuit-breaker config update accepts the same camelCase
shape across CLI and HTTP callers, including `failureThreshold`, `successThreshold`,
`timeoutSeconds`, `errorRateThreshold`, and `minRequests`, and hot-applies it to
existing breakers. `/proxy/failover-queue`,
`/proxy/available-failover-providers`, and `/proxy/auto-failover-enabled`
manage Moonstat's failover queue and app auto-failover settings using
standalone provider router state. The standalone CLI accepts grouped proxy,
failover, provider, and stream-check commands, for example
`moonstat proxy start`,
`moonstat proxy app-config set --appType codex --enabled true`, and
`moonstat stream-check provider --appType codex --providerId provider-1`.
`/proxy/global-url`, `/proxy/test-url`, `/proxy/upstream-status`, and
`/proxy/local-proxies` manage outbound proxy state and deterministic proxy test
responses without external network access.
The `/providers`, `/providers/current`, `/providers/update`,
`/providers/live`, and `/providers/switch` routes manage provider CRUD and
current-provider state. `/providers/live-settings`,
`/proxy/sync-current-providers-live`, `/providers/test-endpoints`, and
`/providers/sort-order` expose live settings, live sync, endpoint latency
results, and `sortIndex` updates.
`/providers/live-ids`, `/providers/live-provider`, and
`/providers/import-live` expose suite-facing provider views against Moonstat's
standalone provider router state. The standalone OpenClaw health scan returns an
empty warning list because Moonstat does not own OpenClaw's live config file.
The OpenClaw default-model/catalog/agents/env/tools routes and Hermes
model/memory/dashboard routes keep their JSON state in Moonstat, returning
`null` or defaults before a standalone caller sets them. Config-folder,
common-snippet, and environment routes use `/config/status`, `/config/dir`,
`/config/snippets`, `/config/snippets/extract`, `/config/env/conflicts`,
`/config/env/delete`, and `/config/env/restore`; folder open and directory pick
use `/config/folder/open` and `/files/directories/pick`. File-sourced env
conflicts are backed up under
`.moonsuite/backups`, removed from shell config files, and restored from that
backup JSON; process environment conflicts remain non-destructive for Unix
system entries. Snippets are kept in gateway memory.
Settings and Claude plugin commands use `/settings...` routes plus the Claude
plugin/onboarding routes.
Moonstat keeps these settings in standalone gateway state, preserves hidden
WebDAV/S3 secrets during `save_settings`, validates optimizer
`cacheTtl`, and treats restart/update/autolaunch/plugin filesystem operations
as deterministic local state changes instead of mutating the desktop OS.
OpenClaw workspace commands are exposed as `/workspace/memory...` and
`/workspace/files...` routes. Standalone mode stores the same whitelisted
workspace files and `memory/YYYY-MM-DD.md` daily memory files under
`~/.moonsuite/openclaw/workspace`, returns Moonstat camelCase metadata, and keeps
directory opening non-destructive while still ensuring the target directory
exists.
MCP and prompt commands are exposed through `/mcp/...` and `/prompts...`
routes. Standalone mode stores MCP servers and prompts in gateway memory,
exports the Claude `mcpServers` JSON text shape, validates command names, and
imports Claude/Gemini JSON MCP server maps plus Codex `config.toml`
`mcp_servers` entries. It also imports, reads, and enables suite prompt files
(`CLAUDE.md`, `AGENTS.md`, or `GEMINI.md`); enabling a prompt writes the
selected content to that app's prompt file.
`/providers/universal`, `/providers/universal/item`, and
`/providers/universal/sync` manage universal-provider JSON and can sync enabled
Claude/Codex/Gemini apps into concrete router providers named
`universal-claude-*`, `universal-codex-*`, and `universal-gemini-*`.
`/providers/endpoints/list`, `/providers/endpoints`, and
`/providers/endpoints/touch` manage provider custom endpoint metadata, including
URL normalization, newest-first listing, and best-effort last-used updates.
`/usage/logs` returns
recent `proxy_request_logs` rows with Moonstat provider/app/model, token,
cache-token, cost, latency, status, session, streaming, and data-source fields.
Gateway startup loads file-backed usage state from
`~/.moonsuite/proxy_request_logs.jsonl` and session sync offsets from
`~/.moonsuite/session_log_sync.jsonl`; editable model pricing is stored
in `~/.moonsuite/model_pricing.jsonl`. Manual `moonstat usage sync` saves usage
state after importing Claude, Codex, Gemini, and OpenCode-compatible session logs.
OpenCode sync reads `opencode.db` directly when `sqlite3` is available, honoring
`OPENCODE_DB` and `XDG_DATA_HOME`. It also accepts JSONL rows exported
from `opencode.db` with `session_id`, `message_id`, and `data` fields as a
fallback, defaulting to `~/.local/share/opencode/opencode.messages.jsonl`.
`/usage/balance` queries provider balance for DeepSeek, StepFun,
SiliconFlow CN/EN, OpenRouter, and Novita AI by detecting provider from
`baseUrl`, querying the vendor balance endpoint with `apiKey`, and returning the
same `UsageResult` shape used by `usage query-provider-usage`.

`/usage/subscription-quota` queries native subscription quota for
`claude`, `codex`, and `gemini`. It reads the same macOS keychain entries and
fallback credential files, calls the official quota endpoints, and returns the
Moonstat `SubscriptionQuota` JSON shape. Gemini expired-token refresh reads
`MOONSTAT_GEMINI_OAUTH_CLIENT_ID` and `MOONSTAT_GEMINI_OAUTH_CLIENT_SECRET`
(or the `GEMINI_OAUTH_*` / `GEMINI_CLI_OAUTH_*` aliases) at runtime.
`/usage/codex-oauth-quota` queries Codex OAuth quota over the
same WHAM usage protocol. `/usage/codex-oauth-models` fetches Codex OAuth
model-list command against `chatgpt.com/backend-api/codex/models`, returning the
same fetched model array shape as provider model fetch. The `/auth/...` endpoints
manage `codex_oauth`: status/list expose the local
Moonstat Codex account, start/poll use OpenAI's device-code flow, and
remove/logout clear `~/.moonsuite/codex-credentials.json`. For
`github_copilot`, the same `/auth/...` surface delegates to the Copilot
device-code flow and `~/.moonsuite/copilot-credentials.json`; the dedicated
`/copilot/...` endpoints expose Copilot account, token, model, and usage
commands against GitHub/Copilot APIs. `/usage/coding-plan-quota`
queries coding-plan quota for Kimi, Zhipu CN/EN, MiniMax CN/EN,
and ZenMux-compatible quota URLs, returning the same `SubscriptionQuota` tier
names and fields.

Claude Desktop gateway routes are open by default for standalone local use. Set
`MOONSTAT_CLAUDE_DESKTOP_TOKEN` or `CLAUDE_DESKTOP_GATEWAY_TOKEN` to require
`Authorization: Bearer <token>` on `/claude-desktop/v1/models` and
`/claude-desktop/v1/messages`, using Moonstat gateway-token behavior without an
external database dependency.

For Claude Desktop standalone setup, run
`moonstat claude-desktop install --port 15721`. Moonstat writes the same gateway
profile shape under Claude Desktop's `Claude-3p/configLibrary`, stores a
local token at `~/.moonsuite/claude_desktop_gateway_token`, and the gateway reads
that token automatically. Use `moonstat claude-desktop uninstall` to restore the
profile mode.

Claude model rerouting honors the standard Anthropic environment names:
`ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`,
`ANTHROPIC_DEFAULT_SONNET_MODEL`, and `ANTHROPIC_DEFAULT_OPUS_MODEL`.
`MOONSTAT_`-prefixed aliases are also accepted. When present, Moonstat maps the
client's Haiku/Sonnet/Opus/default request model to that upstream model and
strips the local `[1M]` context marker before forwarding.

For Codex standalone setup, run
`moonstat codex install --port 15721 --model gpt-5`. Moonstat writes a managed
Moonstat provider block to `~/.codex/config.toml` using
`wire_api = "responses"` and `base_url = "http://127.0.0.1:15721/v1"`, matching
local proxy takeover expectations while preserving unrelated user config. Use
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
