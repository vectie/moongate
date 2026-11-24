# MoonGate project handoff

## ACP text-chat compatibility and cluster qualification — 2026-11-24

The user authorized fixing the failed qualification below and continuing.
The explicit `acp_text` provider type (OpenAI Chat wire format) now has an
`ACP (text chat only)` template for Moon Suite targets. Its provider check sends
a real minimal text generation, without unsupported token/reasoning controls.
Its model catalog reads the bridge allowlist under a two-second deadline and
marks `moongate.text_only`; an unavailable bridge retains that flag on the
default-model fallback. Catalog polling never starts an ACP child. Explicit
requested model IDs are preserved, not remapped to the provider default.

MoonClaw carries this capability through catalog -> Model -> request builder.
Only this mode uses text-chat instructions instead of the coding planner's
system prompt and omits tool schemas, generation controls and prompt-cache
hints. It uses Chat Completions even when Responses was preferred. Tool history
is rejected, not silently removed. The existing assistant-content completion
path delivers actual model text. Other provider behavior is unchanged. This
does NOT implement ACP coding tools or hard token limits.

Clean exports of MoonGate c39f751 and MoonClaw 073325d2 plus only these changes
were built for macOS 15.0 and deployed to the disposable cluster workspace,
not over `/Applications`. MoonDesk's installed sidecar/resources and its UI
Start action launched the updated isolated MoonClaw. The UI listed all four
configured Gemini 4 models. On Neon, two turns in the same conversation
`mooncode-be6d03367e875a28` completed and displayed `ACP_PRO_CLUSTER_OK`;
the second asked to recall the previous reply without supplying the marker.
The first proxy receipt is `req_8115615d-563b-4678-8074-3c9cbba41ff1`,
2026-11-24T12:30:48Z, HTTP 200, streaming, 7,567 ms total / 7,400 ms first text.
MoonGate UI Provider Test also passed a live inference: HTTP 200, 8,343 ms.
The follow-up proxy receipt is `req_cbd55ba8-2cbb-4fa1-878a-2d39e5dad525`,
2026-11-24T12:34:06Z, HTTP 200, 6,722 ms total / 6,513 ms first text.
Images: `/tmp/moondesk-acp-cluster-success.jpg` and
`/tmp/moongate-acp-cluster-passed.jpg`. This is browser interaction with the
actual cluster-served app resources over SSH, not remote native-window control.

Plan evidence: official unmodified Google Antigravity 1.5.16 on the cluster
reports Google AI Pro; optional interaction collection and Use AI Credits are
OFF. API-key/ADC environment variables remain unset. Before the first successful
MoonDesk turn and provider test, weekly/five-hour remaining quota was
99.76% / 99.05%; a fresh CLI after those two calls reported 99.71% / 98.83%.
That is observed plan-quota consumption during this narrow test, not a per-call
token/cost receipt or qualification of every listed model. A later follow-up
also succeeded. IMPORTANT: `/usage` in an already-open CLI kept showing stale
quota; start a fresh official runtime before comparing account counters.
Do not treat MoonGate's unavailable token/cost values as measured zero usage.

Validation: MoonGate working tree 1,230 strict native tests; clean export 1,228;
frontend 148 pass / 3 opt-in skips. Clean MoonClaw daemon/model/adapter checks
pass 541 tests after expected Model JSON snapshots were updated. One existing
approval/cancellation timing test failed under competing test/build loads,
passed alone, then all 541 passed serially. MoonDesk, MoonBook and MoonTown
adapters pass six strict tests each; MoonClaw adapter passes 13 normally.
Its two unused test imports were removed; the adapter now also passes strict
checks. Broad MoonClaw deny-warn still exposes pre-existing warnings outside
this change. Requests-page reload retained its original relative time-window
end; Reset Filters revealed the newer receipt. This unrelated UI refresh
pitfall is recorded, not fixed in this ACP compatibility change.
No automatic commit, push, release or production app installation is included.
Qualification cleanup stopped the isolated sidecar, MoonClaw, MoonGate and ACP
bridge, closed both official CLI instances and the SSH tunnels. Private test
files remain for reproduction; the official cluster Google sign-in is retained.

## Google Pro cluster ACP UI qualification — 2026-11-24

Result: failed integration, not a successful plan-quota inference. All services
and Google authentication ran on cluster Mac 192.168.2.195/macOS 15.7.3 via the
management host. The accidentally opened local Google sign-in page was closed
and its login attempt cancelled at the user's direction. A fresh official CLI
login on the cluster succeeded. The user explicitly approved the first-run
terms with optional interaction-data collection OFF. The CLI reports Google
AI Pro; `/config` shows Use AI Credits OFF. API-key/ADC environment variables
were removed from the tested runtime invocations. No API key was substituted.

Official Antigravity CLI 1.5.16 was downloaded from the manifest referenced by
Google's installer, extracted into a private test directory without changing
shell profiles, checksum-verified, and code-signature-verified as Google LLC
(EQHXZ8M8AV). Its ACP initialization reports protocol 1 and `Antigravity ACP
Server` 1.5.16. `session/new` exposes preferred base model IDs such as
`gemini-4-neon` with a separate `thought_level` selector; the legacy model list
also includes effort-suffixed IDs. Prefer the actual session's selectors, not
guessed IDs from the CLI list.

The actual installed MoonDesk sidecar/resources ran against an isolated book
at port 4205, connected through the MoonGate UI at 15736 to the ACP bridge at
15737. UI model refresh found all four configured base models. Provider Test
returned HTTP 400 because it sends `max_tokens`. A real general MoonDesk turn
(`mooncode-39596702a15ee480`, marker `ACP_PRO_CLUSTER_OK`) then failed through
MoonClaw -> MoonGate -> ACP bridge: request
`req_f13c12be-db41-4197-8589-6e23d6b5c86e`, HTTP 400 in 1 ms. The synthetic
session journal confirms `ACP text bridge does not support option: tools`.
MoonDesk displays a failed turn, with an unhelpful bounded-local-plan detail;
do not mistake its fallback text for a model response. The Google runtime's
weekly/five-hour quota stayed at 99.76% / 99.05% before and after. No successful
Google generation or quota debit was established.

This verifies the documented subset is not yet compatible with MoonDesk's
normal agent requests. Do not silently discard `tools`, token budgets or
reasoning controls to manufacture a pass. Compatibility changes need explicit
semantics and fresh UI-to-UI qualification. The user was asked whether to fix
that compatibility and continue. No production app/configuration or source
implementation was changed in this test. Browser interaction used the actual
cluster-served installed app resources over SSH, not remote native-window
control; do not claim the latter. Screenshots were saved locally as
`/tmp/moondesk-acp-cluster-failed.jpg` and
`/tmp/moongate-acp-cluster-rejected.jpg`.

Private test data is under `/private/tmp/moongate-acp-plan.HSoU2G` on the Mac.
Google authentication remains owned by the official runtime's private local
profile/keychain; it was not read back or exported. Temporary services were
retained while the user authorized a fix and continued qualification. Reuse the authenticated runtime when continuing,
but record a new quota baseline and verify credits remain OFF before testing.

## Commit qualification — 2026-11-24

The ACP bridge and pending Gemini multi-model changes pass a clean staged-tree
export: strict native check and 1,226 native tests, plus 148 frontend passes
and three opt-in skips. The working tree passes 1,228 native tests including
two unrelated in-progress tests, which are excluded from this commit.
MoonDesk/MoonBook/MoonTown adapters pass six strict tests each; MoonClaw passes
13 normally, with its same two unused imports still failing deny-warn. Final
info/format checks pass. Only GitHub and GitLab are push targets; no Gitee
publication or app release is part of this checkpoint. Live Google Pro quota
and a full MoonDesk ACP conversation remain unqualified.

## Experimental generic ACP text bridge — 2026-11-24

`moongate acp serve --config FILE [--port 15724]` is a separate opt-in loopback
API; normal gateway startup, provider state and app bindings are unchanged.
It launches a trusted local ACP v1 executable directly (no shell), verifies the
requested model against each fresh session, and translates text output to
OpenAI Chat JSON/SSE. A required local bearer token is not an upstream API key.
No account credentials are copied; official agent login must happen separately.

This is a text subset, not transparent raw-model parity. Unsupported fields,
tools and interactive callbacks are rejected; requested permissions are
cancelled. It does not sandbox the executable or manage detached descendants.
History is a quoted transcript, not equivalent system-role authority. Model
allowlists are not account access proof; usage/cost are unknown, not zero.
Current provider checks/MoonClaw clients send extra options and therefore are
not automatically qualified. See `docs/ACP_BRIDGE.md` for limitations and setup.

Do not promise Google Pro quota through a normal API. Google's November 2 ACP
clarification permits a narrow official-runtime interactive path, not a general
subscription-to-API entitlement. The generic adapter does not establish that
Google permits consumer-plan use. No Google OAuth extraction or headless quota
wrapper was added, and no live consumer-plan request was attempted here.

Each request has its own process/session (startup overhead, no idle pool or
model-poll spawn); default concurrency is four with a request deadline. Child
processes are stopped and reaped on completion/failure/timeout. A silent
disconnect without another write is detected by the deadline, not immediately.
The native `.mbtx` fixture pins async 0.19.4: latest 0.22.10 conditional imports
are not supported by the current build tool, while fetching old 0.16.6 source
fails on its legacy manifest. Do not depend on implicit latest script packages.

Validation: nine focused ACP tests and the CLI registration test passed; final
`moon info`, `moon fmt`, strict native check and all 1,228 native tests passed.
The existing CLI-family inventory test was updated for the new explicit family.
An actual built `main.exe acp serve` at isolated port 15764 returned HTTP 200
JSON and incremental SSE with successful `[DONE]` against the fixture. A warm
fixture request took 43 ms locally; that is not a live-agent latency promise.
Only the new package's public interface was added (opaque Bridge, JSON config,
serve and classified errors). The smoke server was stopped and its temporary
fixture configuration removed. No UI/package installation, live Google plan
request, commit, push or release was performed. Existing unrelated edits remain.

## Gemini 4 concurrent model selection — 2026-11-24

The current Google family is Hydrogen, Neon, Carbon and Argon; Argon was
missing from preset suggestions. One private model list now feeds both preset
suggestions and the selected Google connection's OpenClaw/Paiwork model
catalog. No remote catalog fetch was added to MoonDesk's polling path. Explicit
`gemini-*` request IDs are preserved rather than overwritten by the provider's
default mapping, so independent conversations can choose different models.
The default remains Hydrogen. Public interfaces and non-Google mappings stay
unchanged. Tests cover all four IDs together and mapping each ID independently.

Cluster UI qualification used the actual installed MoonDesk sidecar/UI and an
isolated updated MoonGate at 15735. All four models appeared together in the
MoonDesk picker from one Google provider. Four general conversations were
submitted within one second, selecting one different model each. MoonGate's
records show Neon, Carbon and Argon with their distinct requested/upstream
model IDs, all started at 2026-11-24T10:13:38Z, returning HTTP 429. Retrying
conversations were cancelled through MoonDesk. Hydrogen did not finish before
cancellation; its bounded direct UI check returned HTTP 503/high demand in
10,248 ms. Neon, Carbon and Argon bounded direct checks returned HTTP 429 in
1,121, 1,153 and 1,133 ms respectively, with Google's explicit quota-exceeded/
plan-and-billing message. All four conversations were confirmed cancelled in
MoonDesk before teardown. These are not successful Gemini 4
generations, nor proof that all four can complete concurrently with this key.
An account with appropriate quota and an available Hydrogen backend is needed
to finish that acceptance. Do not substitute the previous 3.5 pass.

After qualification, the three isolated test services and SSH tunnels were
stopped, and the isolated provider credential file was removed. Production
configuration and the installed app bundle were not changed in this pass.

MoonDesk has a `Connect a model` connection-import dialog, opened by the
currently named `Scan connection QR` action in Code assistance/Book tools.
It accepts pasted settings and routes import through MoonClaw to MoonGate;
it is not a full provider management page. Provider storage/routing remains
owned by MoonGate. No separate provider page was added to MoonDesk here.

Checks: 1,218 strict native tests, 148 frontend passes/three skips; MoonDesk,
MoonBook and MoonTown adapters six passes each. MoonClaw adapter passes 13
normally; its same two pre-existing unused imports still fail deny-warn.

Do not tell users Google AI Pro has no API benefit: the current official
[Developer Program benefits FAQ](https://developers.google.com/profile/help/benefits?hl=en)
includes $10/month in Cloud developer credits for eligible Pro subscribers,
usable for Gemini API after claiming/applying them. The API project's billing
and quotas are still separate from app subscription usage. The current
[API billing guide](https://aistudio.google.com/docs/billing) says Prepay users
must have an active purchased prepaid balance before eligible Cloud credits
can be consumed. These benefits are not an unlimited API entitlement, and a
429 response alone does not establish whether billing is disabled, credits
are unclaimed/depleted, or another model/project limit was hit.

## Bundled MoonDesk runtime follow-up — 2026-11-24

The installer blocker recorded below was repaired in MoonDesk: its app now
ships reviewed MoonClaw resources and provisions them on explicit Install.
Network updating remains disabled. Desktop startup creates/reuses private
workspace-bound local service authentication, without provider keys or Book
trust grants. MoonGate now recognizes and preserves the version-only managed
service descriptor; the old binding writer otherwise tried to replace it with
command/args/cwd fields that MoonDesk rejects. Legacy onboarding remains
supported for independently installed MoonClaw.

Cluster macOS 15.7.3 qualification used the updated installed app's actual
sidecar/resources through an isolated browser UI. A clean Install reached
account/model setup without the former updater refusal. A successful empty
model-route probe now carries explicit `model_ready=false`, so the models DTO
does not erase known configuration status and force an extra Retry. Google
Flash-Lite passed a fresh real UI check (HTTP 200, 1,836 ms), and the MoonDesk
binding was applied through the UI without changing its managed descriptor.

That test also exposed missing suite-default publication: a saved provider and
binding produced a catalog but no executable default for MoonClaw. Connect now
writes the selected model to suite status, and startup plus suite
status/manifest/export endpoints derive their default from the connected Moon
provider (without changing the Codex fallback). The helper uses the real
current-provider ID, not the intentionally empty additive-provider UI field.
Regression coverage checks unbound/connected/cleared defaults.

A real MoonDesk conversation then exposed Google's rejection of OpenAI-only
`prompt_cache_key` and `reasoning_effort=none`. The Google-host-specific request
adapter removes cache routing hints and maps `none` to `low` for Gemini 3/4,
without mutating the original request or other providers. Gemini 2.5 behavior
is unchanged. Google's [OpenAI compatibility documentation](https://aistudio.google.com/docs/openai)
states that thinking cannot be disabled for Gemini 3/4; direct provider checks
had already used valid low effort and could not expose the client mismatch.

Final UI-to-UI result: the installed MoonDesk resources on cluster macOS 15.7.3
submitted a general, tool-free conversation through MoonClaw → MoonGate →
`gemini-3.5-flash-lite` and displayed exactly `MOONGATE_GEMINI_OK`, with the turn
marked done. The preceding two failed attempts and the successful retry are
retained in the isolated test session, rather than rewritten as a clean pass.
Native remote-window behavior, Gemini 4 capacity, OAuth and Ark conversations
were not requalified in this follow-up. MoonDesk fix commit: `a1cb6422`.
Bundled MoonClaw came from clean archived commit `073325d2`, not dirty sibling
files. Temporary services are stopped and the private Gemini test-provider
copy removed after qualification; installed app resources and rollback remain.

Final checks passed: isolated staged-tree native check/test with deny-warn
(1,215 tests), full working-tree native tests (1,217, including two unrelated
in-progress tests), and frontend tests (148 passed, three skipped). MoonDesk
native tests passed 1,731 and Rabbita JS tests 2,291; six pre-existing native
warnings and one UI warning remain there. Only this task's changes were staged.

MoonDesk's previous app bundle is recoverable at
`/Users/jiaanguo/moonsuite-install-20261124/MoonDesk-before-runtime-fix-20261124.bundle`.
Do not call browser-to-cluster-sidecar tests a remote native-window test: this
connection provides no remote GUI control. Minimum OS remains 15.0; both the
sidecar and bundled runtime were built with that deployment target. No Lepusa
domain code or dependency changes were needed.

## Third-round implementation and Gemini qualification — 2026-11-24

Removed the unused framework-table renderer/helpers/selector and its
`/providers/current` fetch dependency. Providers now fetch one inventory per
scope rather than inventory plus selection. Existing backend framework APIs
and app binding behavior remain supported. Scope selectors share the existing
registry, put the shared Moon-app scope first, and do not claim per-app origin.

Resilience provider changes fetch only circuit observations and limits (two
requests, formerly eight). Global forms retain dirty values during refresh;
saving one form preserves the other and edits made while its save is pending.
No draft persistence, credential revisions, receipts or automatic retests were
added. Operations has one capture/refresh action, retry only after failure,
concise comparison output with the exact full report/export behind disclosure,
and collapsed developer diagnostics. The unsupported queue metric is omitted.

Google Gemini presets default to `gemini-4-hydrogen`, with Neon/Carbon and
Flash suggestions, verified against Google's current API/model documentation.
Moon apps and other OpenAI-style clients use Google's `/v1beta/openai` Chat
endpoint; the Gemini client retains its native protocol. Existing saved
providers are not silently rewritten. Catalog suggestions survive template
grouping; saved Chat providers support account model discovery. Gemini 3/4
checks use low thinking and a 2,048-token completion/thinking budget, since the
old eight-token cap can finish before visible output.

Live testing exposed a genuine hang: the provider-check implementation ignored
its configured timeout. It now honors that existing setting, with a slow native
HTTP regression proving a failed, recoverable result after one second. No retry
loop or new timeout configuration was introduced.

`moon.mod` supplies the embedded suite/app release version. The suite's
`dev_build` rule generates `suite/release_metadata.mbt`; commit that generated
file for downstream users. In this toolchain rule input/output paths are
package-relative, despite older guidance describing them as module-relative.
Both `suite lepusa --write` and `suite lepusa-rabbita --write` regenerate the
checked-in manifests. Their version is now 0.1.4. Asset revision is v18.

Validation: 1,213 native tests pass with warnings denied. Frontend tests:
148 passed, three opt-in standalone checks skipped; the core native suite runs
the real HTTP/served-asset bridges. MoonDesk/MoonBook/MoonTown adapter tests
pass strictly. MoonClaw's 13 tests pass normally; strict mode still rejects
its two pre-existing unused imports. Browser and resource-updated Lepusa
preview checks cover presets, masked saved credentials, a completed loopback
check, independent draft saves, scope defaults and snapshot capture. The
375px Operations page has no horizontal page overflow. Public .mbti interfaces
are unchanged. Unrelated chat/provider-header/event-gateway work is preserved.

Cluster qualification used macOS 15.7.3 at 192.168.2.195. Build with
`MACOSX_DEPLOYMENT_TARGET=15.0`; `vtool` verified minimum macOS 15.0. Do not
diagnose this host as unreachable after trying only direct local SSH: connect
to the cluster management host first (the existing port-32123 management
connection), then SSH to `jiaanguo@192.168.2.195`. The Mac's host key was
matched to the already trusted local record. Credentials were entered only
through the password prompt/provider editor, never stored in source or logs.

The isolated gateway at `/tmp/moongate-round3.tCsT7s`, port 15735, returned
65 Google model IDs and completed a real `gemini-3.5-flash-lite` check with
HTTP 200 in 2,017 ms. `gemini-4-hydrogen` returned high-demand HTTP 503;
its later stalled attempt exposed the timeout bug and was interrupted for the
fixed build. `gemini-4-neon` returned quota-exceeded HTTP 429. Do not claim
successful latest-model inference from a catalog listing or the Flash-Lite pass.

The installed MoonDesk sidecar/UI ran against an isolated test book on port
4204. Its code-assistance runtime is unavailable; its Install action returns
`updater_sandbox_unavailable` because an isolated updater backend is not
configured. Full MoonDesk → MoonGate → Gemini, OAuth and Ark conversations
were therefore not qualified. Do not bypass that refusal or call it success;
repairing the MoonDesk installation is a separate follow-up. Installed bundles
and existing user configurations were not replaced. Test services/tunnels were
stopped, the mode-0600 temporary Gemini provider file was removed, and the local
preview's imported OAuth credential copy was removed. No production release,
commit or push was performed.

## Third-round simplification review — 2026-11-24

Source review only; no fresh UI or live-provider qualification. The first two
rounds are implemented. Prefer a bounded removal/consistency pass followed by
feature qualification, not another navigation or framework rewrite.

- `renderFrameworkRows`, its three rendering helpers and `selectedProviderId`
  have no callers. Their old `framework-rows` target is absent. Keep the active
  provider inventory/editor and backend framework integrations.
- `loadFrameworkRow` still fetches `/providers/current` for that obsolete
  renderer. A failure in that request also discards a successfully fetched
  provider inventory. Decouple saved providers from app selection/binding;
  remove the unused current-provider dependency, not the supported backend API.
- Resilience selection/refresh reloads global circuit and connection-test
  configuration, calling `fillCircuitForm` and `fillStreamForm` unconditionally.
  Preserve dirty global forms and refresh only provider-specific observations
  when changing a provider. Do not add a general draft-persistence subsystem.
- Scope choices still diverge: Resilience and cohort comparison explicitly
  default to Codex, Usage labels its choice "All frameworks", and cohorts expose
  raw scope IDs. Reuse the app registry's ordering and distinguish the shared
  Moon-app scope from individually attributable app traffic.
- Operations includes a queue-support metric although the monitor explicitly
  sets `queue_supported=false`, plus a visible deterministic-fixture card.
  Keep real observations prominent; place developer diagnostics and statistical
  methodology behind local disclosure. Cohort capture/refresh are the same
  action; retry with preserved bounds belongs to the failed-capture state.
- Module version is 0.1.4 while checked-in and generated Lepusa app manifests
  still declare 0.1.0. Align the intended release identity through one explicit
  version input rather than maintaining another manually synchronized value.

Unrelated chat/provider and event-gateway/text-gateway edits remain in progress;
this review did not modify them. No new tests or release were performed.

## Second-round implementation — 2026-11-24

Keep this a simplification, not a new hardening subsystem. Test results remain
local to the window: no durable receipts, credential hashes/revisions, forced
15-minute expiry, or automatic paid retests were added. Cosmetic provider
edits and pause/resume preserve the last result; connection/model changes and
explicit key replacement invalidate it. A matching last check is not a
continuous availability guarantee. Reload or external credential edits require
a new check.

Suite now displays integration support only, without connected counts or
duplicate adapter cards. Primary route traffic is described as shared Moon-app
traffic, not proof of MoonDesk origin. Graph alternatives are disclosed per
app, with expansion retained on refresh. Hidden-page graph rendering and
startup allocation-editor creation were removed. Requests mounts investigation
tools only on opening; comparison needs two kept requests, subset/notes need
kept data, and import/merge controls follow the actual file choice. All prior
investigation workflows remain covered by behavioral tests.

The language selector lives in Advanced. Changed request labels use explicit
translation calls/message keys; provider/model values remain content. The
legacy translation fallback is retained, not rewritten project-wide.
On narrow screens the request header must wrap. A hidden details panel must
also release its master-detail column; hiding only the panel leaves half the
desktop area empty. Inspect both selected and unselected states.

The final routed-usage check also exposed an older first-round regression:
the By App panel was still owned by the global/Overview refresh, so Usage
cleared it without loading it. Usage now owns its filtered fetch and reads the
endpoint's actual `{appType, summary}` rows. Do not flatten assumed fixture
fields instead of following that nested contract. One routed request now
agrees across totals, app, provider, model and request details.

Seven legacy desktop-effect routes now return HTTP 501 with an explicit
unsupported error rather than pretending to open, copy, restart, or update.
Their registered paths remain in the route inventory for compatibility and
discovery; the nonfunctional tray command is no longer recommended by the
suite command catalog/help. Pure fake-effect bookkeeping and its tests were
removed, replaced by one actual HTTP behavior test. Active adapters are intact.

Qualification: 1,211 native tests pass with warnings denied. Frontend behavior
tests pass. MoonDesk/MoonBook/MoonTown adapters pass strictly; MoonClaw's 13
tests pass normally, with the same two existing unused-import warnings. Browser
and generated Lepusa-preview checks use the isolated loopback fixture, not
live Ark/OpenRouter/Codex inference. A routed fixture request exercised actual
usage/detail/collection UI. The 375px selected-request view has no horizontal
page overflow. This does not install or publish a production bundle. CI policy
and broad backend file splitting were intentionally left unchanged.

## Second-round simplification review — 2026-11-24

Source review of the current working tree, including the uncommitted first
round; not a fresh UI or live-provider qualification. Follow AGENTS.md's
feature-testing direction rather than starting a framework rewrite or broad
file-splitting campaign.

- Suite currently derives its "Connected apps" count from manifest app entries
  and labels an integration Ready when a route string is published. That is
  capability metadata, not installed, bound, reachable, or observed app evidence.
- Overview's primary traffic observation matches the shared OpenClaw scope,
  provider and model in the newest 12 rows. It cannot establish that MoonDesk
  specifically produced the request. Preserve unknown origin instead of
  inferring app identity from provider scope.
- Provider test identity includes presentation fields (name/notes) while the
  credential identity can fall back to the coarse stored/missing state. Review
  server-owned non-secret routing/credential revisions before making test proof
  persistent or sharing it across windows. Completion checks should cover
  truncated and explicitly failed terminal states for every supported protocol.
- Requests builds collection, merge, subset, comparison and annotation surfaces
  even with no retained/kept rows. Keep these supported tools on demand; do not
  delete their workflows or hide consequential import/merge confirmations.
- Runtime opener, clipboard and restart handlers can return true without the
  named external effect. Inventory actual callers and either use published
  Lepusa or return an explicit unsupported result, updating CLI/suite contracts
  together. Do not remove active framework integrations as "compatibility".
- Page-scoped fetches do not make the shell lazy: every page's view and scripts
  still ship together. Measure transfer, startup scripting, repeated rendering,
  navigation latency and build/link cost before selecting further extraction.
- The checked-in CI definitions currently use `.yml.disabled` names. Do not
  describe local green checks as automatic push/PR validation; decide the CI
  policy explicitly during release qualification.

Suggested order: evidence correctness and runtime contract truth, contextual
Requests/Graph/Suite disclosure, explicit localization/control consistency,
then measured dead-code/initialization cleanup and packaged feature tests.

## Simplification implementation — 2026-11-24

The review below is now implemented: one app/scope registry, six primary
destinations, Apps subviews, progressive provider configuration, and active-page
data loading. Preserve all framework integrations and old deep links. The
provider → selected/running route → verified app projection is shared; general
health must never substitute for configuration-matched test evidence. Evidence
is session-only, expires after 15 minutes, and requires completed model output
(HTTP 200 with HTML or an empty response is a failure).

UI validation uses an isolated workspace and loopback native upstream fixture,
including a deliberately invalid HTTP-200 response. It is not evidence of live
Ark/OpenRouter availability or MoonDesk inference. A generated Lepusa native
preview wraps the isolated gateway; no installed production bundle or real
Codex configuration was replaced. Saved secrets remain masked and authored
provider names must be protected from the legacy locale scanner.
Paused-only inventories must still return the saved provider in the shared
projection; otherwise Apps incorrectly prompts users to add a second provider.
Keep the recovery link to that saved provider. Advanced policy drafts survive
refresh and default to the MoonDesk/OpenClaw scope.
Stopping routing while app takeover remains enabled is intentionally rejected
by the backend. Report it as a stop-action failure (not a failed refresh), and
offer a local return to app connections; do not silently remove bindings.

Native suite: 1,213 passed with warnings denied. MoonDesk/MoonBook/MoonTown
adapter tests pass with warnings denied. MoonClaw's 13 tests pass normally;
its strict run currently fails on existing unused async/httpx imports in the
sibling package. Generated manifest parity must still be refreshed after any
MoonBit view edit. Large policy/request investigation tools remain available;
they are not stale compatibility to delete during cleanup.

## Simplification review — 2026-11-24

Source review only; these findings have not been reproduced through the native
app in this review. Resolve the shared data contracts before simplifying copy:

- MoonDesk's template target in `provider_template_catalog.mbt` still uses
  `codex`, while `ui_contract.mbt` and `moon_binding_provider_app_type` use
  `openclaw`. MoonBook/MoonTown template targets also have no corresponding
  entry in the current framework-app list. Do not infer binding support from
  the presence of a template.
- `connectionGraphTestState` falls back from configuration-matched test proof
  to general `healthStatus`; the graph's route-ready calculation does not
  include the live proxy-running state. Keep provider health, tested revision,
  saved app wiring, and observed app traffic distinct.
- `refreshDashboard` loads hidden-page providers, bindings, usage, suite and
  resilience data on each refresh. Provider save/delete also call this global
  refresh. Measure request counts and interaction latency before changing the
  refresh design; preserve drafts, selected providers and scroll position.
- The locale runtime still scans arbitrary DOM text and applies a Chinese-only
  body-font override. Provider names rendered without content boundaries can
  collide with system-label translations. Prefer explicit message keys and
  protect authored names, IDs, models, paths and request text.

Current worktree includes ongoing provider/chat, event-gateway and packaged-UI
work. Review and implement simplification in scoped changes without treating
these in-progress edits as an obsolete baseline.

## Cluster Mac UI and branding — 2026-11-24

Working style and UI/UX guidance now matches MoonTown's rules, with MoonGate's
own stylesheet path. Preserve the existing framework adapters and app boundary.
The overview retains the real next action and gateway/routing states, while
technical summaries and the setup-progress rail are collapsed disclosures.
Their existing IDs and handlers remain intact. The new Technical details label
has a Chinese translation. At narrow widths, the primary action must reset its
desktop grid position; otherwise it creates an implicit overflowing column.
The narrow sidebar clips its outer overflow while its navigation still scrolls.

`lepusa.rabbita.json` embeds generated root HTML. Regenerate it with the built
CLI's `suite lepusa-rabbita --write` after view changes; otherwise manifest
parity tests correctly fail. Native tests: 1,209 passed, including 13 UI asset
tests. Existing compiler warning debt remains; this is not a warning-free gate.

Installed on the M4/macOS 15 cluster Mac at 192.168.2.195 from clean `ebf4e1a`
plus this focused UI delta, excluding unrelated provider/chat worktree edits.
The service and Lepusa runtime target macOS 15. Strict deep signature checks
pass. Prior app copies and receipts are in the remote user's
`moonsuite-install-20261124` directory. Database/provider credentials were not
changed, and no external model request or app binding was performed.

The app icon is generated from `assets/moongate-macos.svg` with transparent
padding. Quick Look thumbnails can flatten that padding to white even when a
PNG has an alpha channel. Use `rsvg-convert` with no background color. The
sibling Mooncast `scripts/generate_macos_icon.mbtx` checks all four corner alpha
values at all ten ICNS sizes; installed icon hashes matched these verified
outputs. Do not infer transparency from `hasAlpha` alone.

Mac native Lepusa windows can remain alive after SIGTERM stops their services.
Quit before replacing a bundle. The scoped installer stops only its own four
app process trees, preserves rollback bundles, and never treats an absent
service as proof that the native window exited. Remote served UI was checked
through SSH forwarding; direct interaction with the remote WKWebView was not
available from this machine.

Launchpad follow-up: its database contained a second MoonGate entry bookmarked
to the old `backups/MoonGate.app`. Staged, rollback and old disk-image copies
were unregistered from LaunchServices; the canonical apps were re-registered
and Dock restarted without resetting layout. LaunchServices now lists only
the canonical copies, but Launchpad retained its duplicate database row at the
follow-up check. Do not claim visible cache/duplicate cleanup without a remote
screenshot. Backups and Launchpad layout were preserved; the installed ICNS
hash still matches the verified transparent output.
