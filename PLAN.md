# Moonstat Hardening and Delivery Plan

This plan turns the July 2026 project audit into an ordered delivery program.
Moonstat is a feature-rich alpha: the proxy, provider integrations, usage
surface, suite discovery, typed client, metrics, CLI registry, and Rabbita
dashboard exist, but correctness and release hardening still block a beta.

## Product Constraints

These constraints apply to every phase:

- Preserve all active framework integrations: Codex and OpenAI-compatible
  clients, Claude and Anthropic-compatible clients, Claude Desktop, OpenClaw,
  Hermes, Gemini, OpenCode-style logs, GitHub Copilot, and the
  MoonClaw/MoonBook/Moontown/Moondesk adapters.
- Remove only stale aliases, deprecated command shims, dead probes, old-version
  compatibility paths, and APIs that claim functionality they do not provide.
- Keep the gateway loopback-only by default. Any non-loopback mode must be an
  explicit, authenticated operator choice.
- Use published MoonLib, Rabbita, and Lepusa packages. Sibling worktrees are for
  inspection and upstream validation, not production dependencies.
- Prefer feature and failure-path testing over broad structural cleanup. Split
  large files only when a correctness or release task benefits from the split.
- Keep route, CLI, suite, and typed-client contracts synchronized and versioned.
- Do not advertise a desktop capability until the backend or Lepusa actually
  performs it.

## Audit Baseline

Baseline observed on 2026-07-10:

- `moon check --target native --warn-list +73 --deny-warn` passes.
- `moon test --target native` passes 780 of 780 tests.
- `moon test --target native --deny-warn` fails because generated drivers in
  `internal/mock` and `internal/spawn` call a deprecated test constructor.
- The test suite can create a repository-local `.moonsuite` credential fixture;
  test state must be isolated under a temporary product home.
- The only GitHub workflow prepares the Copilot coding agent. It does not run
  Moonstat checks or tests on ordinary pushes and pull requests.
- The inspected canonical CCS baseline is `98ccde00`; the configured fork and
  canonical `main` matched on 2026-07-10. Recent CCS changes include a
  persisted dashboard refresh interval and Zhipu team-plan quota support.
  Moonstat already has substantial 1M-context backend support.

## Completion Definition

Moonstat is ready for beta when all of the following are true:

- Concurrent requests cannot overwrite each other's model, provider, session,
  stream, cost, or circuit-breaker accounting context.
- Usage summaries remain exact after request-detail retention limits are
  exceeded and after process restart.
- Persistence is crash-safe, reports failures, and has a tested migration path.
- Control-plane routes are authenticated and protected from hostile browser or
  non-loopback access without breaking supported inference clients.
- The full warning-denied baseline is green in CI.
- Process-level tests cover routing, streaming, failover, accounting, restart,
  and failure behavior through real HTTP sockets and deterministic mock
  upstreams.
- Advertised runtime and desktop operations are either implemented or removed
  from the supported contract.
- A user can launch a packaged native Moonstat/Lepusa application without the
  repository or MoonBit toolchain.
- CCS parity is measured against an explicit baseline and reviewed as CCS moves.

## Phase 0: Restore a Trustworthy Baseline

Objective: make every future change start from a reproducible green baseline.

Work:

- Fix or work around the generated `@test.Test` constructor deprecations in
  `internal/mock` and `internal/spawn` without suppressing unrelated warnings.
- Run every filesystem and credential test with an isolated temporary product
  home. Assert that tests leave no `.moonsuite` state in the repository or real
  user home.
- Add a normal GitHub CI workflow for native `moon info`, `moon fmt --check` if
  supported, warning-denied `moon check`, and warning-denied `moon test`.
- Record the MoonBit toolchain version used by CI so compiler warning changes are
  intentional.
- Keep generated `.mbti` changes under review as the public API signal.

Exit gate:

- Core validation passes with warnings denied on a clean checkout.
- Repeating the test suite does not change the worktree or user configuration.
- CI runs on ordinary pushes and pull requests.

## Phase 1: Make Usage Accounting Correct

Objective: make Moonstat's central statistics claim correct under concurrency
and normal traffic volume.

### Request-scoped accounting

- Introduce a request-scoped context containing request ID, start time, app,
  inbound and outbound models, provider, session, stream mode, pricing source,
  cost multiplier, and half-open circuit permit state.
- Return the context from the inbound/start operation and pass it explicitly
  through provider selection, forwarding, retry, failover, completion, and
  error paths.
- Remove per-request `current_request_*` state from the shared `TrafficStats`
  object. Keep only true process aggregates and active-connection counters
  shared.
- Ensure every terminal path completes or cancels exactly one context and
  releases the correct provider permit.
- Add deterministic overlapping-request tests where requests finish in a
  different order from arrival.

### Retention and aggregation

- Separate request-detail retention from aggregate retention.
- Before evicting a request-detail row, fold it into the correct daily rollup or
  durable aggregate exactly once.
- Preserve filtering dimensions required by summaries: date, app, provider,
  provider name, model, request model, pricing model, success, tokens, cost, and
  latency.
- Add tests with at least 10,000 records proving totals do not change when the
  500-row detail window is crossed.
- Add restart round trips proving summaries before and after reload are equal.
- Document request-detail and aggregate retention separately.

Exit gate:

- Concurrent OpenAI, Anthropic, Gemini, OpenClaw, and Claude Desktop requests
  retain the correct provider/model/session attribution.
- Summary, provider, model, trend, cost, and token totals remain exact beyond
  the detail retention limit and after restart.
- Circuit-breaker success and failure signals are attributed to the provider
  selected for that request.

## Phase 2: Harden Persistence

Objective: prevent silent usage loss and make storage behavior observable.

Work:

- Choose a durable implementation: an append-only journal with atomic compaction
  or SQLite. Prefer the smallest design that supports exact rollups, indexed
  filters, migrations, and crash recovery.
- Stop rewriting all JSONL stores after every request.
- Replace swallowed storage errors with structured errors, logs, counters, and
  degraded health state while keeping inference available when safe.
- Use atomic replacement for snapshots and configuration files.
- Version the local usage schema and provide import/migration coverage for the
  current JSONL files.
- Add interruption tests for partial writes, truncated records, failed rename,
  unavailable directories, and recovery after process termination.
- Define backup, restore, and sync consistency around the same storage
  transaction boundary.

Exit gate:

- Killing Moonstat during a write cannot corrupt the last committed usage state.
- Storage failure is visible in health, status, logs, and metrics.
- Current user data migrates without losing request details or aggregates.

## Phase 3: Protect the Control Plane and Lifecycle

Objective: keep local convenience while preventing unauthorized configuration,
credential, and filesystem access.

Work:

- Classify routes as public health, inference, read-only observability, or
  privileged control plane.
- Generate and persist a Moonstat control token with restrictive file
  permissions. Require it on privileged routes and support it in
  `MoonstatClient`, CLI, suite discovery, and Lepusa startup.
- Validate Host and Origin for browser-facing localhost requests. Reject unsafe
  non-loopback management access by default.
- Restrict direct credential-returning routes such as Copilot token retrieval to
  trusted internal callers, or replace them with operations that never expose
  raw credentials.
- Audit provider and settings responses so nested `settingsConfig` values do not
  return API keys or secrets.
- Add request body limits, timeouts, and consistent JSON error envelopes to
  management routes.
- Add graceful shutdown: stop accepting traffic, drain or cancel active
  requests, flush durable state, restore managed configurations when requested,
  and write a stopped suite-status record.
- Separate liveness from readiness. Readiness must report credential, provider,
  persistence, and configuration degradation instead of always returning
  `healthy`.

Exit gate:

- An unauthenticated process or hostile browser page cannot mutate Moonstat or
  retrieve credentials.
- Supported framework clients continue to use inference routes with their
  expected OpenAI, Anthropic, Gemini, OpenClaw, and Claude Desktop semantics.
- Shutdown and restart leave suite status and managed client configuration
  consistent.

## Phase 4: Add Process-level Feature Tests

Objective: validate behavior at the same boundaries real agent clients use.

Work:

- Build deterministic local mock upstreams for OpenAI Responses, OpenAI Chat,
  Anthropic Messages, Gemini native, malformed responses, slow first byte,
  stalled streams, disconnects, rate limits, and upstream failures.
- Start Moonstat on an ephemeral port in tests and make real HTTP requests
  through the gateway.
- Cover non-streaming and streaming conversion, tool calls, media handling,
  cancellation, timeout, retry, failover, circuit-open, half-open, and recovery
  paths.
- Assert exact request logs, token usage, cost, model mapping, provider routing,
  first-token latency, and error status for each scenario.
- Test clean install/uninstall and config takeover/restore under temporary homes
  for Codex, Claude Desktop, OpenClaw, Hermes, Gemini, and OpenCode.
- Run sibling adapter tests for MoonClaw, Moondesk, Moontown, and MoonBook when
  suite contracts change.
- Add a release smoke job that starts the built binary, waits for readiness,
  checks the UI and metrics, sends a mock inference request, and shuts down.

Exit gate:

- Every active framework has at least one successful and one failure-path HTTP
  test.
- Streaming tests cover first byte, idle timeout, cancellation, and fallback as
  one workflow rather than isolated parsers only.
- CI catches route, wire-format, usage, suite-contract, and install regressions.

## Phase 5: Remove False Compatibility Surface

Objective: distinguish active framework support from stale or non-functional
desktop compatibility APIs.

Work:

- Inventory every route and CLI command against a real caller, documented user
  workflow, and behavior test.
- For each desktop operation, choose one outcome: implement through published
  Lepusa, implement as a real backend operation, or remove it from the route,
  CLI, suite manifest, README, and tests.
- Start with known stubs: directory picking, clipboard writing, external URL
  opening, update checking, tray updates, app restart, and update/install/restart.
- Do not remove OpenClaw, Hermes, Claude Desktop, Codex, Gemini, OpenCode,
  GitHub Copilot, or Moon suite integration routes merely because they began as
  compatibility work.
- Change tests from source-presence assertions to behavior assertions.

Exit gate:

- Every advertised operation performs its documented effect or returns a clear
  unsupported-capability response.
- No supported framework or suite integration is removed.
- Route and command manifests contain no dead aliases or no-op success results.

## Phase 6: Manage CCS Parity Deliberately

Objective: preserve the requested CCS behavior without allowing an unversioned
moving target to control Moonstat development.

Work:

- Maintain `CCS_PARITY.md` as the ledger of reviewed CCS commit, feature area,
  Moonstat implementation, tests, intentional differences, and status.
- Compare behavior, configuration effects, failure modes, and persisted data,
  not only route or command names.
- Review new CCS commits on a regular cadence and classify each as required,
  intentionally different, UI-deferred, or obsolete compatibility.
- Persisted dashboard refresh interval, Zhipu team-plan quota, and transient
  quota keep-last-good behavior are implemented. Next address structured Codex
  TOML handling and per-app MCP import failure reporting.
- Confirm current 1M-context support across primary and fallback Claude model
  routes; leave only the Lepusa presentation control deferred.
- Keep provider presets generated or mechanically comparable so additions and
  removals are reviewable.
- Add parity regression fixtures for high-risk provider takeover, backup,
  restore, stream conversion, quota, and usage behavior.

Exit gate:

- Every feature in the pinned CCS baseline has an explicit parity disposition.
- Updating the baseline produces a reviewable list of new or changed behavior.
- Intentional Moonstat differences are documented instead of hidden behind
  placeholder endpoints.

## Phase 7: Deliver a Standalone Application

Objective: let a user install and run Moonstat without a source checkout or
MoonBit toolchain.

Work:

- Produce a native release binary and make the Lepusa bundle launch that binary
  instead of `moon run`.
- Package public assets, the generated Rabbita shell, default configuration, and
  required runtime metadata into the application distribution.
- Use published Lepusa for service lifecycle, readiness, opener, clipboard,
  dialogs, and other desktop capabilities it supports.
- Add clean-machine and temporary-home smoke tests for first launch, control
  token creation, provider setup, proxy routing, usage display, restart, and
  uninstall.
- Define upgrade and rollback behavior for the binary, local schema, Lepusa
  manifest, and suite status contract.
- Add platform release artifacts and checksums. Add signing and notarization for
  platforms where release policy requires them.

Exit gate:

- The packaged app starts, becomes ready, handles a mock routed request, records
  usage, displays it, and shuts down cleanly on a machine without MoonBit.
- The package does not write into the source tree or depend on sibling projects.
- Upgrade and rollback preserve credentials, providers, and usage history.

## Phase 8: Lepusa UI Completion

This phase remains deferred until Lepusa's published desktop capabilities and
application patterns settle. Backend correctness, security, testing, parity,
and packaging should continue first.

When the phase begins:

- Keep Rabbita as the generated view layer and Lepusa as the desktop/runtime
  framework.
- Build a first-run provider onboarding workflow with credential validation,
  stream test, save, and switch confirmation.
- Add live request drilldown showing selected provider, model mapping, tokens,
  cost, latency, failover, and a redacted error summary.
- Add import and repair workflows for Claude Desktop, OpenClaw, Hermes, Codex,
  Gemini, and OpenCode with dry-run diffs before mutation.
- Preserve dense operator ergonomics and validate desktop/mobile layout,
  accessibility, keyboard operation, empty states, and error recovery.
- Validate the packaged Lepusa app, not only the browser-served page.

Exit gate:

- A first-time user can configure one provider, route a real framework client,
  observe usage, diagnose a failure, and restore configuration without using
  the CLI.

## Delivery and Commit Discipline

Each work package should use small green commits in this order:

1. Add a regression or contract test that demonstrates the missing behavior.
2. Implement the smallest coherent fix.
3. Add process-level or sibling integration coverage where the boundary changed.
4. Update the README, this plan, generated manifests, and `.mbti` interfaces as
   required.
5. Run the phase validation gate, commit, and push before starting the next
   independent work package.

Do not combine unrelated framework removals, broad file splitting, UI redesign,
or dependency churn with a correctness fix.

## Release Gates

### Beta

- Phases 0 through 5 complete.
- CCS baseline and parity ledger established.
- Standalone release candidate passes the process-level smoke matrix.

### 1.0

- Phases 0 through 7 complete.
- No known statistics-loss, credential-exposure, config-restore, or concurrent
  routing defects.
- Supported framework and suite contracts are versioned and tested.
- Upgrade, rollback, backup, restore, and clean uninstall are validated.

Phase 8 can continue after 1.0 if the existing Rabbita view remains usable and
the packaged Lepusa shell meets the standalone workflow gate.
