# MoonGate product contract

Class: platform and standalone operator application
Maturity: feature-testing alpha
Last reviewed: 2026-07-30

## Outcome

MoonGate gives MoonSuite one local provider gateway for routing, credentials,
usage, resilience, authority policy, capability observation and suite health.

## Users and jobs

- Operators configure providers and inspect usage, failures and suite status.
- OpenAI-, Anthropic- and other compatible clients use one local endpoint.
- MoonClaw obtains model access without embedding provider credentials.
- MoonDesk reads provider and capability health for operator decisions.

## Ownership

MoonGate owns proxy routing, provider configuration, usage accounting,
failover/circuit behavior, product-boundary policy and live suite observation.
It does not own agent execution, workflow state, book truth, desktop file
browsing or domain policy.

## Capability status

| Capability | Status |
| --- | --- |
| Local proxy and provider routing | available |
| Usage, pricing, quota and request inspection | available |
| Failover, circuit and stream checks | available |
| Suite discovery and path-drift reporting | available |
| Live executable capability projection and exact resolution | available |
| Rabbita/Lepusa operator shell | available locally |
| Production credential vault and multi-user control plane | planned |
| Provider availability | conditional on credentials and provider terms |

## Security and data

Credentials are host secrets and must never enter pack manifests, evidence
bundles or logs. Usage records redact sensitive request content according to the
configured data class. Product capability records may describe permitted
authority; they cannot grant human acceptance or physical authority.

## Operation

The default proxy listens on `127.0.0.1:15721`. Public network exposure requires
an explicit deployment policy, authentication and transport security. The
standalone Lepusa application wraps the localhost service.

## Verification

```sh
moon check --target native --deny-warn
moon test --target native --deny-warn
moon info
moon fmt
```

Contract changes also require the MoonClaw, MoonDesk, MoonTown and MoonBook
adapter tests named in `AGENTS.md`.

The executable projection is documented in
[`CAPABILITY_REGISTRY.md`](CAPABILITY_REGISTRY.md). Inventory rows are never
execution grants. MoonFlow and MoonDesk must require an accepted exact
resolution before dispatching a cross-product operation.

## Release gates and next milestones

- Reproducible zero-configuration first run without bootstrap authorization
  failure.
- Durable provider/config storage with backup and migration instructions.
- Real-client compatibility matrix and failure-path evidence.
- Signed application release and clean-machine validation.
- Split oversized provider and usage packages before they impede feature work.
