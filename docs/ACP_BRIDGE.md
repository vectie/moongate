# Experimental ACP API bridge

MoonGate can launch a local ACP agent and expose a small OpenAI Chat-compatible
API. This is an agent adapter, not a raw-model API and not an implementation of
Google subscription authentication.

## What it supports

- `GET /v1/models`: the configured model allowlist, explicitly marked unverified.
- `POST /v1/chat/completions`: `model`, text `messages`, and optional `stream`.
- JSON completions and incremental SSE chunks, including a successful terminal
  chunk and `[DONE]` only after the ACP agent completes the turn.
- ACP v1 stdio initialization, session creation, grouped/flat model selectors,
  and the older session model selector. Each request verifies its selected
  model against the agent's session; it does not silently use the default.
- Independent concurrent requests (four by default). Each request owns a fresh
  agent process/session, preventing one conversation from changing another's
  model or carrying over its hidden context.
- Optional caller-owned function tools, passed to the agent through a
  request-scoped MCP stdio relay. Real tool calls become OpenAI `tool_calls`;
  MoonGate does not execute them or invent their results.

Prior messages are encoded as a quoted transcript in one ACP user prompt.
OpenAI system/developer-role priority is **not** preserved as an agent-level
system instruction. Token usage and dollar costs are omitted rather than made
up. The agent's own defaults and account limits still apply.

## Start it

Sign in using your chosen agent's official interactive login first. MoonGate
does not extract browser cookies, copy OAuth tokens, run a hidden login, or
change the agent's authentication settings.

Create a private JSON configuration outside the repository, for example
`/absolute/private/path/acp.json`:

```json
{
  "command": "/absolute/path/to/your-acp-agent",
  "args": ["acp"],
  "cwd": "/absolute/path/to/an-empty-test-directory",
  "token": "replace-with-a-long-random-local-token",
  "models": ["exact-model-id-from-your-agent"],
  "timeout_ms": 120000,
  "max_concurrent": 4,
  "tools": false
}
```

The command and working directory must be absolute Unix paths. Arguments are
passed directly without a shell. Use your agent's actual ACP invocation; not
every executable uses the `acp` argument shown above. Restrict access to the
configuration file (for example, mode `0600`).

```sh
moongate acp serve --config /absolute/private/path/acp.json --port 15724
```

For a source checkout, build/run `cmd/main` with the native target. The bridge
binds only `127.0.0.1`. It requires `Authorization: Bearer <token>` on both
routes and rejects browser-origin requests. It is opt-in; normal MoonGate
startup and saved provider bindings are unchanged.

## Connect a client

Use these settings in a minimal text-chat client:

| Setting | Value |
| --- | --- |
| Protocol | OpenAI Chat Completions |
| Base URL | `http://127.0.0.1:15724/v1` |
| API key | The local `token` from your bridge configuration |
| Model | One of your exact configured model IDs |

Send only `model`, `messages`, and optionally `stream`:

```json
{
  "model": "exact-model-id-from-your-agent",
  "stream": true,
  "messages": [{ "role": "user", "content": "Reply with hello. Do not use tools." }]
}
```

Choose the **ACP (text chat only)** template for a Moon Suite connection. Set
the bridge URL, its local bearer token and an exact model ID from your agent;
save, refresh models, test, then connect MoonDesk on Apps. The advanced provider
type is `acp_text`; its wire format remains OpenAI Chat Completions. An ordinary
OpenAI Chat provider does not automatically opt into these reduced semantics.

The catalog passes an explicit `moongate.text_only` capability to MoonClaw.
MoonClaw uses text chat without tools, sampling/reasoning controls, token limits
or cache hints, and delivers the actual assistant text through its existing
completion path. Its prompt explicitly says it cannot execute tools or change
files. Normal tool-capable connections are unchanged; tool histories are
rejected, not discarded. This is chat compatibility, not ACP coding-tool
integration. A matching updated MoonClaw runtime is required.

## Coding through MoonDesk

For caller-tool support, set `"tools": true` in the private bridge config and
use advanced provider type `acp` with **OpenAI Chat Completions**. Keep
`acp_text` for chat-only connections. Moon Suite providers use the shared
OpenClaw request route; connect **MoonDesk** on Apps, not the Codex app.

The coding catalog advertises `moongate.acp_tools`. A matching MoonClaw runtime
sends text history, function schemas and streaming, without unsupported
generation controls. Assistant tool calls and their actual caller results are
retained across rounds. A tool-call continuation now resumes the same live ACP
prompt/process instead of repeating agent startup, initialization and session
creation for every tool. Separate coding turns remain separate sessions; this
is not a shared cross-conversation agent pool. Changing model or tool schemas
starts a new session from the supplied transcript.

The bridge advertises a temporary `moongate_client` MCP stdio server using its
own `acp tool-relay` subcommand. An optional absolute `relay_command` config
value selects the installed MoonGate executable. Its private loopback transport
credential is passed through the subprocess environment, not command arguments.
Only a correct-session permission request for an exact declared relay tool may
receive **allow once**. The relay captures the call and waits while the client
validates, approves and executes the real operation. The next request's matching
tool-call ID supplies that actual result back to the waiting MCP call. Updated
caller instructions are retained. The relay itself never executes the operation.

MoonClaw forwards incremental answer text to its existing conversation journal,
coalescing token bursts over 75 ms. MoonDesk's existing watch displays it while
the request is running; final completion does not duplicate the streamed text.

File editing and command execution are separate: MoonClaw's file tools operate
on the selected Book, while command/build/test tools require its MoonFort
execution configuration. For trusted local coding, an operator may explicitly
choose **LocalOs / AllowDegraded**, register the Book and toolchain once, and
retain existing command approvals. VM-grade isolation is not required for that
opt-in mode. Other Books must not be implicitly trusted. There is no fallback
to an unrestricted host shell when configuration or execution fails.

The cluster deployment qualified real MoonDesk caller-tool file editing plus
ordinary and native MoonBit execution (stdout `42`, exit `0`) using Argon.
Registering Apple Command Line Tools selects it automatically in the updated
MoonFort executor; no per-command environment prefix is required. Its receipt
correctly reports **Degraded**, and build-file promotion still requires enforced
isolation. This narrow check does not qualify every model or coding workflow.

Model discovery reads the bridge's cheap configured allowlist (no agent spawn),
with a two-second gateway deadline and a text-only default-model fallback if
discovery fails. Neither listing nor saving is generation/account-access proof.
Provider Test sends a real minimal text inference without a fabricated hard
output limit. Every generation still has the bridge's wall-clock deadline.

## Deliberate limits

With `tools` disabled, tool requests/activity and permissions are rejected.
With it enabled, only declared function tools use the relay described above;
native ACP filesystem/terminal callbacks remain unsupported. Images/audio,
structured output, Responses/Anthropic endpoints, sampling controls, token
budgets and other unsupported request fields return errors, not approximated
success. Native or unrelated permission requests are cancelled.

The subprocess is **not sandboxed** by this adapter. Only configure a trusted
executable and use its own supported sandbox/restrictions. An agent can have
its own native tools or plugins independently of ACP client capabilities;
MoonGate cannot revoke their OS privileges. Use a disposable working directory
for qualification. No native filesystem or terminal capabilities are advertised
to the agent; only the optional caller-tool MCP relay is advertised.

Requests and ACP frames are bounded to 1 MiB; accumulated answer text is bounded
to 2 Mi UTF-16 code units. A timeout stops and reaps the directly launched child.
Client write failure also unwinds the child; a disconnected client that receives
no further chunks is detected no later than the request timeout. Agent-created
detached descendants are not managed by the bridge. Agent stderr is drained but
not retained or returned to API clients. Unexpected session IDs, changed models,
empty output and cancelled turns are failures. Partial SSE failures emit an
error object without a successful `[DONE]`.

There are no catalog polling subprocesses. A live caller-tool session may wait
for its next tool result, bounded by the existing request timeout. Completion,
failure, timeout and bridge shutdown reap its directly launched child. First
startup, provider waiting and generation still take time; reuse is not an
instant-response guarantee. There is no automatic bridge retry or quota/account
rotation. Busy admission returns HTTP 429 without launching another agent.

## Google AI Pro is a separate qualification

Google documents [interactive ACP clients](https://antigravity.google/docs/ide/extensions/acp)
using its official runtime. Its [November 2 clarification](https://discuss.ai.google.dev/t/supported-gemini-subscription-access-for-a-third-party-vs-code-extension/189889)
permits a specific official, unmodified ACP runtime/sign-in path for single-user
interactive development. This does not establish permission to turn consumer
quota into a general-purpose model API. Google's
[FAQ](https://antigravity.google/docs/faq/) also restricts direct third-party
credential reuse and headless wrappers under consumer plans.

This generic bridge does not establish that Google permits that use, guarantee
plan quota or model access, or make consumer OAuth equivalent to an API key.
Keep any Google consumer-plan experiment separate until its exact runtime and
use are confirmed as supported.

On 2026-11-24, a narrow cluster Mac test through MoonDesk's actual installed UI
resources succeeded with this text-only mode and official Antigravity 1.5.16.
Neon returned the requested marker and answered a follow-up in the same chat;
MoonGate's live provider check also passed. With Google AI Pro shown, credits
OFF and no API-key/ADC environment fallback, a fresh official CLI showed plan
quota decrease during the first chat turn and provider check: weekly remaining
99.76% -> 99.71%, five-hour 99.05% -> 98.83%. The older open CLI's counters were
stale. See `docs/project/HANDOFF.md` for receipts and limitations. This is not
qualification of every model, coding tools, other accounts, or a general
subscription-to-API entitlement.

## Test coverage

`moon test acp_gateway --target native --deny-warn` exercises a deterministic
MoonBit ACP subprocess through actual loopback HTTP. The fixture is
`tests/fixtures/acp_agent.mbtx`, run using `moon` on `PATH` with pinned async
dependencies and the native target. It does not contact Google or spend quota.
It covers concurrent model selection, JSON/SSE, permission denial, auth errors,
malformed output, session mismatch, model drift, cancelled/empty output,
partial-stream errors, request timeout, concurrency admission and text framing.
Caller-tool tests additionally cover history validation, JSON/SSE function-call
handoff and the narrow relay permission rule. Fixture tests never execute the
model's proposed command.
