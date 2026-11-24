# MoonGate project handoff

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
