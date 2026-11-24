# MoonGate project handoff

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
