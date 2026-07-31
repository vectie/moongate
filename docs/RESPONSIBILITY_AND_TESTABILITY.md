# MoonGate responsibility and testability

MoonGate owns the local provider gateway, credential references, model routing,
usage accounting, circuit/failover behavior, authority policy, exact installed
capability resolution, and suite-health observation. It does not execute agent
goals, advance workflow state, accept knowledge, or decide domain policy.

| Responsibility | Evidence | Test boundary |
| --- | --- | --- |
| Resolve a provider route | provider configuration revision and redacted route decision | use a fixture route, then a separately credentialed live acceptance |
| Enforce budgets and authority | request identity, policy version, denial/grant receipt | exercise allowed, denied, exhausted, and expired cases |
| Record usage | provider/model identity, measured units, price revision, request correlation | reconcile streamed and non-streamed requests without retaining secrets |
| Project executable capability truth | installed manifest, versioned adapter declaration, expiring health evidence | exact resolution passes; version/authority/health drift fails closed |
| Report suite health | time-bounded observations per product and route | stale/unreachable state must replace—not coexist with—a running claim |
| Observe provider operations | correlated request stages, outcomes, tokens, cost, capacity, quota, circuit, failover, storage and evidence freshness | unsupported queue, permit, budget or headroom fields remain explicit rather than becoming zero-valued claims |
| Change routing policy | shadow decision, policy revision, MoonLib principal/authority-decision references and digest-bound activation/rollback receipt | live route remains unchanged before activation; expired/mismatched authority, stale health, missing credentials, exhausted quota/budget, open circuit or capacity denial fails closed |
| Benchmark gateway behavior | immutable deterministic fixture report or explicitly authorized bounded live request | fixture is never labeled live; absent authority/verifier/adapter returns denied/unavailable and performs no network request |

The operator application may configure and inspect these records, but a green
provider or product row is never human acceptance or external-effect authority.
See [CAPABILITY_REGISTRY.md](CAPABILITY_REGISTRY.md) and
[qualification/UI_TO_UI_USE_CASES.md](qualification/UI_TO_UI_USE_CASES.md).

## Repository shape

| Path | Responsibility |
| --- | --- |
| root package | proxy, provider, usage, capability, and Rabbita application code retained during staged package extraction |
| `model`, `suite`, `cost`, `transform`, `clock`, `deeplink` | cohesive public support packages |
| `oauth/codex` | Codex OAuth protocol integration |
| `internal/*` | process, host, network, HTTP, and configuration helpers that own no public product types |
| `cmd/main` | service and operator command composition |
| `cmd/moonflow_adapter` | generic MoonFlow-facing adapter entrypoint |
| `public`, `ui_rabbita*.mbt`, `lepusa*.json` | current Rabbita/Lepusa operator application boundary |

The visible source predates the preferred `ui/rabbita-moongate` location. This
mapping is explicit so moving files is not confused with feature progress.
Large gateway and command files remain a reviewed extraction backlog; new
provider or UI policy should go into cohesive files and packages rather than
expanding those files further.

## Operations package boundary

`telemetry/`, `benchmark/`, and `routing/` contain the public typed contracts
and deterministic policy arithmetic. Root gateway files adapt request logs,
provider state and the control-token-protected HTTP surface to those contracts.
High-cardinality request, attempt, provider-chain and session evidence may be
present in review records, but Prometheus labels stay limited to stable app and
provider identities. Raw session keys are never stored; session stickiness uses
a bounded derived digest.

Decision vocabularies are closed wire enums: routing mode/reason,
activation action/scope, terminal outcome, circuit state, and live-benchmark
status/reason reject unknown JSON values. Free-form diagnostic detail remains a
string and cannot alter a decision state.
