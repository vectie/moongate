# Moonstat

Moonstat is the MoonBit-native local proxy/statistics gateway for the Moon
suite. It is a standalone app and also fits beside:

- MoonClaw: agent runtime and job executor
- MoonBook: durable books, wiki, and output workspace
- Moontown: scheduler and town control plane
- Moondesk: desktop operator shell

The proxy listens on `127.0.0.1:15721` by default.

## Current Phase

Moonstat is currently in a feature-testing phase. The backend, suite discovery,
typed client surface, metrics route, and framework integrations are in place, so
new work should prioritize validating real workflows before more structural
cleanup.

Framework integrations are product features and should remain supported:
Codex/OpenAI-compatible clients, Claude/Anthropic-compatible clients, Claude
Desktop, OpenClaw, Hermes, Gemini, OpenCode-style logs, GitHub Copilot, and the
MoonClaw/MoonBook/Moontown/Moondesk suite adapters. Cleanup should target stale
old-version aliases, deprecated command shims, dead local probes, and
unnecessary compatibility paths, not active framework support.

The main known cleanup backlog is organizational: split remaining large files
such as `cmd/main/cmd_misc.mbt`, `gateway_provider.mbt`,
`gateway_claude_anthropic.mbt`, and `gateway_usage.mbt` when testing exposes
friction or before a release-hardening pass. The current UI is a standalone
operator console served by Moonstat itself; Lepusa-specific desktop UI work
should wait until the Lepusa framework settles.

When desktop or UI integration starts, depend on published packages rather than
local sibling checkouts. Use published Rabbita (`moonbit-community/rabbita`) and
published Lepusa (`vectie/lepusa`) releases in `moon.mod`; keep `../rba` and
`../lepusa` only as reference/test worktrees for reading upstream behavior.

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
moon run cmd/main -- auth login
moon run cmd/main -- auth status
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

Open the standalone operator UI at `http://127.0.0.1:15721/`. It is served by
Moonstat itself and reads the same `/status`, `/proxy/status`, `/usage/*`, and
`/metrics` surfaces used by the CLI and suite integrations. The UI also
exposes proxy start/stop/sync controls and provider create/update/delete/test
flows for Claude Code, Claude Desktop, Codex, Gemini, OpenCode, OpenClaw, and
Hermes without removing additive-provider behavior. Its usage explorer filters
summary, trend, provider, model, request-log, and request-detail views through
the same `/usage/*` endpoints used by automation. The setup panel checks auth,
config, runtime, tool, Claude Desktop, MCP, Claude plugin, proxy-running, and
proxy-takeover state through the same standalone management routes used by CLI
automation. The resilience panel manages failover queues, auto-failover,
circuit-breaker config/stats, provider limits, and stream-check config/results
through the same `/proxy/*` and `/usage/provider-limits` routes. The suite
panel reads and writes the MoonClaw/MoonBook/Moontown/Moondesk discovery
contracts through `/suite/*` routes. The frontend stays framework-free for now:
`moonstat-core.js` owns shared route/helper code and `moonstat.js` owns
dashboard behavior.

For a desktop shell, use published Lepusa against the checked-in
`lepusa.json` manifest. The manifest wraps the existing Moonstat gateway as a
localhost app and does not depend on local `../lepusa` or `../rba` workspaces.

## Feature Testing Focus

Use the current codebase for end-to-end feature testing. The highest-value
areas are:

- Proxy routing: Codex/OpenAI-compatible, Claude/Anthropic-compatible, Gemini,
  OpenCode, OpenClaw, and Claude Desktop gateway paths.
- Streaming behavior: SSE conversion, first-byte and idle timeout handling,
  stream-check provider/all/config commands, and fallback behavior.
- Usage accounting: request logs, summaries, trends, model/provider stats,
  request detail, pricing overrides, balance/quota queries, and session sync
  from Claude, Codex, Gemini, and OpenCode sources.
- Provider management: CRUD, live import, universal providers, endpoint
  metadata, sort order, failover queues, auto-failover, and circuit breakers.
- Suite discovery: `~/.moonsuite/suite-status.json` written by `start`, read by
  MoonClaw, MoonBook, Moontown, and Moondesk adapters.
- Install/config flows: hosts reroute, Codex config, Claude Desktop profile,
  OpenClaw/Hermes state, MCP/prompt import, and skill storage operations.
- Failure paths: missing credentials, bad provider auth, malformed request
  bodies, unavailable upstreams, circuit-open routing, and interrupted streams.

Baseline validation before and after feature-test changes:

```sh
moon info
moon fmt
moon check --target native --deny-warn
moon test --target native --deny-warn
```

For suite-adapter changes, also run the moonstat plugin tests in sibling
projects:

```sh
(cd ../moonclaw && moon test plugin/moonstat --target native --deny-warn)
(cd ../moondesk && moon test plugin/moonstat --target native --deny-warn)
(cd ../moontown && moon test src/plugin/moonstat --target native --deny-warn)
(cd ../moonbook && moon test plugins/moonstat --target native --deny-warn)
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

`suite manifest`, `suite status`, `GET /suite/manifest`, and `GET /suite/status`
print JSON contracts for MoonClaw,
MoonBook, Moontown, Moondesk, or any other local probe. They expose the
gateway URLs, status file, capabilities, and command map needed by suite
launchers. `suite write-status` and `POST /suite/status/write` write the same
status contract to `~/.moonsuite/suite-status.json` by default, and `start`
refreshes that file when the gateway boots. `GET /suite/moonclaw-providers`
and `POST /suite/moonclaw-providers/write` expose the MoonClaw providers file
contract over HTTP. The contract also includes a machine-readable
`suiteIntegrations` object:

- MoonClaw gets local OpenAI/Anthropic base URLs, env names, a
  `moonclawProvidersFileJson` provider entry, and the project/home config
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

- `GET /`
- `GET /assets/moonstat.css`
- `GET /assets/moonstat-core.js`
- `GET /assets/moonstat.js`
- `GET /health`
- `GET /status`
- `GET /stats`
- `GET /metrics`
- `GET /suite/manifest`
- `GET /suite/status`
- `POST /suite/status/write`
- `GET /suite/moonclaw-providers`
- `POST /suite/moonclaw-providers/write`
- `GET /proxy/status`
- `POST /proxy/start`
- `POST /proxy/stop`
- `POST /proxy/stop-with-restore`
- `GET /proxy/global-config`
- `POST /proxy/global-config`
- `GET /proxy/global-url`
- `POST /proxy/global-url?url=http://127.0.0.1:7890`
- `POST /proxy/test-url?url=http://127.0.0.1:7890`
- `GET /proxy/upstream-status`
- `GET /proxy/local-proxies`
- `GET /proxy/app-config?appType=claude`
- `POST /proxy/app-config?appType=claude&enabled=true`
- `GET /proxy/default-cost-multiplier?appType=claude`
- `POST /proxy/default-cost-multiplier?appType=claude&value=1.25`
- `GET /proxy/pricing-model-source?appType=claude`
- `POST /proxy/pricing-model-source?appType=claude&value=request`
- `GET /proxy/provider-health?appType=claude&providerId=codex-oauth`
- `GET /proxy/circuit-breaker-config`
- `POST /proxy/circuit-breaker-config`
- `GET /proxy/circuit-breaker-stats?appType=claude&providerId=codex-oauth`
- `POST /proxy/reset-circuit-breaker?appType=claude&providerId=codex-oauth`
- `GET /proxy/failover-queue?appType=claude`
- `POST /proxy/failover-queue?appType=claude&providerId=codex-oauth`
- `DELETE /proxy/failover-queue?appType=claude&providerId=codex-oauth`
- `GET /proxy/available-failover-providers?appType=claude`
- `GET /proxy/auto-failover-enabled?appType=claude`
- `POST /proxy/auto-failover-enabled?appType=claude&enabled=true`
- `GET /proxy/takeover-status`
- `POST /proxy/takeover-status?appType=claude&enabled=true`
- `POST /proxy/switch-provider?appType=claude&providerId=codex-oauth`
- `POST /proxy/sync-current-providers-live`
- `POST /proxy/import-default-config?appType=codex`
- `GET /providers?appType=codex`
- `GET /providers/current?appType=codex`
- `POST /providers?appType=codex&id=custom&name=Custom`
- `POST /providers/update?appType=codex&id=custom&name=Custom`
- `DELETE /providers?appType=codex&id=custom`
- `DELETE /providers/live?appType=codex&id=custom`
- `POST /providers/switch?appType=codex&id=custom`
- `GET /providers/live-settings?appType=codex`
- `GET /providers/live-ids?appType=openclaw`
- `GET /providers/live-provider?appType=openclaw&providerId=custom`
- `POST /providers/import-live?appType=openclaw`
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
- `POST /hermes/web-ui?path=/`
- `POST /hermes/dashboard`
- `GET /config/claude/status`
- `GET /config/status?appType=codex`
- `GET /config/claude-code/path`
- `GET /config/dir?appType=codex`
- `POST /config/folder/open?appType=codex`
- `POST /files/directories/pick?defaultPath=/tmp`
- `POST /runtime/open-external?url=https://github.com/vectie/moonstat`
- `POST /runtime/clipboard/text?text=hello`
- `POST /runtime/updates/check`
- `POST /runtime/tray-menu/update`
- `GET /runtime/portable-mode`
- `GET /tools/versions?tools=codex,claude`
- `POST /runtime/window-theme?theme=dark`
- `POST /runtime/lightweight-mode/enter`
- `POST /runtime/lightweight-mode/exit`
- `GET /runtime/lightweight-mode`
- `POST /files/dialogs/save?defaultName=config.json`
- `POST /files/dialogs/open`
- `POST /files/dialogs/open-zip`
- `GET /skills/installed`
- `GET /skills/backups`
- `POST /skills/backups/delete?backupId=moonstat-usage-1`
- `POST /skills/backups/restore?backupId=moonstat-usage-1&currentApp=claude`
- `POST /skills/install-unified?directory=moonstat-usage&currentApp=codex`
- `POST /skills/uninstall-unified?id=moonstat-usage`
- `POST /skills/toggle-app?id=moonstat-usage&appType=hermes&enabled=true`
- `GET /skills/unmanaged`
- `POST /skills/import-apps`
- `GET /skills/discover`
- `GET /skills/updates`
- `POST /skills/update?id=moonstat-usage`
- `POST /skills/migrate-storage`
- `GET /skills/search?query=proxy&limit=10`
- `GET /skills`
- `GET /skills/app?appType=codex`
- `GET /skills/repos`
- `POST /skills/repos?owner=vectie&name=moonstat-skills&branch=main`
- `POST /skills/repos/remove?owner=vectie&name=moonstat-skills`
- `POST /skills/install-zip?filePath=/tmp/moonstat-usage&currentApp=codex`
- `GET /providers/claude-desktop/status`
- `GET /providers/claude-desktop/default-routes`
- `POST /providers/claude-desktop/import`
- `POST /providers/claude-desktop/official`
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
- `POST /config/snippets/extract?appType=claude&settingsConfig={}`
- `GET /config/env/conflicts?appType=claude`
- `POST /config/env/delete`
- `POST /config/env/restore?backupPath=...`
- `GET /mcp/claude/status`
- `GET /mcp/claude/config`
- `POST /mcp/claude/servers?server={"id":"filesystem"}`
- `DELETE /mcp/claude/servers?id=filesystem`
- `GET /mcp/validate?command=npx`
- `GET /mcp/config?appType=codex`
- `POST /mcp/config/servers?appType=codex&server={"id":"filesystem"}`
- `DELETE /mcp/config/servers?id=filesystem`
- `POST /mcp/enabled?appType=codex&id=filesystem&enabled=true`
- `GET /mcp/servers`
- `POST /mcp/servers?server={"id":"filesystem"}`
- `DELETE /mcp/servers?id=filesystem`
- `POST /mcp/apps/toggle?appType=codex&id=filesystem&enabled=true`
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
- `GET /workspace/memory/search?query=plan`
- `DELETE /workspace/memory/file?filename=2026-06-14.md`
- `POST /workspace/memory/delete?filename=2026-06-14.md`
- `GET /workspace/files?filename=AGENTS.md`
- `POST /workspace/files?filename=AGENTS.md&content=...`
- `POST /workspace/open?subdir=memory`
- `GET /prompts?appType=codex`
- `POST /prompts?appType=codex&id=review&content=Check`
- `DELETE /prompts?appType=codex&id=review`
- `POST /prompts/enable?appType=codex&id=review`
- `POST /prompts/import-file?appType=codex&path=/tmp/prompts.md`
- `GET /prompts/current-file?appType=codex&path=/tmp/prompts.md`
- `POST /providers/import-live?appType=opencode`
- `POST /providers/import-live?appType=openclaw`
- `POST /providers/import-live?appType=hermes`
- `GET /providers/universal`
- `GET /providers/universal/item?id=custom`
- `POST /providers/universal?id=custom&name=Custom&apps=claude,codex`
- `DELETE /providers/universal?id=custom`
- `POST /providers/universal/sync?id=custom`
- `POST /providers/test-endpoints?urls=https://api.example.com/v1`
- `POST /providers/sort-order?appType=codex&id=custom&sortIndex=0`
- `GET /providers/endpoints/list?appType=codex&providerId=custom`
- `POST /providers/endpoints?appType=codex&providerId=custom&url=https://api.backup.example.com/v1`
- `DELETE /providers/endpoints?appType=codex&providerId=custom&url=https://api.backup.example.com/v1`
- `POST /providers/endpoints/touch?appType=codex&providerId=custom&url=https://api.backup.example.com/v1`
- `GET /proxy/running`
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
- `GET /usage/provider-usage?providerId=codex-oauth&appType=codex`
- `GET /usage/balance?baseUrl=https://api.deepseek.com&apiKey=...`
- `GET /usage/subscription-quota?tool=codex`
- `GET /usage/codex-oauth-quota?accountId=...`
- `GET /usage/codex-oauth-models?accountId=...`
- `GET /usage/coding-plan-quota?baseUrl=https://api.kimi.com/coding/v1&apiKey=...`
- `GET /auth/status?authProvider=codex_oauth`
- `GET /auth/accounts?authProvider=codex_oauth`
- `POST /auth/login?authProvider=codex_oauth`
- `POST /auth/poll?authProvider=codex_oauth&deviceCode=...`
- `DELETE /auth/account?authProvider=codex_oauth&accountId=...`
- `POST /auth/default-account?authProvider=codex_oauth&accountId=...`
- `POST /auth/logout?authProvider=codex_oauth`
- `GET /auth/status?authProvider=github_copilot`
- `POST /auth/login?authProvider=github_copilot&githubDomain=github.com`
- `POST /auth/poll?authProvider=github_copilot&deviceCode=...`
- `GET /copilot/status`
- `GET /copilot/accounts`
- `GET /copilot/authenticated`
- `POST /copilot/device-flow?githubDomain=github.com`
- `POST /copilot/poll-auth?deviceCode=...`
- `POST /copilot/poll-account?deviceCode=...`
- `DELETE /copilot/account?accountId=...`
- `POST /copilot/default-account?accountId=...`
- `POST /copilot/logout`
- `GET /copilot/token?accountId=...`
- `GET /copilot/models?accountId=...`
- `GET /copilot/usage?accountId=...`
- `POST /usage/test-script?providerId=codex-oauth&appType=codex`
- `POST /proxy/stream-check/provider?appType=codex&providerId=codex-oauth`
- `POST /proxy/stream-check/all?appType=codex&proxyTargetsOnly=true`
- `GET /proxy/stream-check/config`
- `POST /proxy/stream-check/config?codexModel=gpt-5.5@low&timeoutSecs=45`
- `GET /v1/models`
- `POST /config/models?baseUrl=https://api.example.com&apiKey=sk-...`
- `GET /claude-desktop/v1/models`
- `POST /v1/messages`
- `POST /claude-desktop/v1/messages`
- `POST /v1/responses`
- `POST /v1/responses/compact`
- `POST /v1/chat/completions`
- `POST /openclaw/v1/chat/completions`
- `ANY /gemini/v1beta/*path`
- `ANY /gemini/v1/*path`

`/status`, `/proxy/status`, and `/stats` include Moonstat request counts,
success/failure counts, active connections, token totals, cache token totals,
last request time, last error, current provider metadata, and success rate.
`/proxy/takeover-status` and `/proxy/running` expose standalone HTTP endpoints
for proxy control. Their POST endpoints accept camelCase JSON bodies or query
parameters for standalone scripts. `/proxy/global-config`, `/proxy/app-config`,
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
same `UsageResult` shape used by `usage provider-usage`.

`/usage/subscription-quota` queries native subscription quota for
`claude`, `codex`, and `gemini`. It reads the same macOS keychain entries and
fallback credential files, calls the official quota endpoints, and returns the
Moonstat `SubscriptionQuota` JSON shape. Gemini expired-token refresh reads
`MOONSTAT_GEMINI_OAUTH_CLIENT_ID` and `MOONSTAT_GEMINI_OAUTH_CLIENT_SECRET`
at runtime.
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
When present, Moonstat maps the client's Haiku/Sonnet/Opus/default request
model to that upstream model and strips the local `[1M]` context marker before
forwarding.

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
`MOONSTAT_GEMINI_FULL_URL=1` when the base URL is an opaque relay endpoint that
should not have the Gemini model path appended.
Aliased `/gemini/v1beta/...` and `/gemini/v1/...` requests are normalized back
to the upstream `/v1beta/...` and `/v1/...` paths.

## Suite Role

Moonstat is the network edge for local Moon apps. Point Codex-style clients,
MoonClaw provider checks, or Moondesk/Moontown integration probes at
`http://127.0.0.1:15721` and use `/status` or `/stats` for health dashboards.
The suite manifest also publishes an `agentClients` array for Codex,
Claude Code, Claude Desktop, OpenClaw, OpenCode, Gemini, GitHub Copilot, and
generic OpenAI-compatible clients, with each client's app type, protocol, base
URL, primary route, and setup command when Moonstat owns one.

MoonBook remains the durable output owner, Moontown owns scheduling and standing
goals, MoonClaw owns execution, and Moondesk owns the local operator UI.
Moonstat owns local traffic rerouting and usage/statistics accounting.
