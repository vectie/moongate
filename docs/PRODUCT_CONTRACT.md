# MoonStat product contract

Class: retired migration alias
Maturity: non-callable
Canonical successor: MoonGate
Last reviewed: 2026-07-31

## Outcome

MoonStat preserves the historical interpretation of pre-MoonGate code and
state. It provides no current MoonSuite product or execution capability.

## Ownership

MoonStat owns no live product boundary. MoonGate exclusively owns:

- local model-provider and proxy routing;
- provider configuration and credentials;
- usage, pricing, quota and request accounting;
- failover, circuit and stream health;
- live suite and capability observation.

The old source and state remain evidence. Presence in a checkout, archive or
receipt does not grant runtime authority.

## Callable surface

| Surface | Status |
| --- | --- |
| Pack | prohibited |
| Capability operation | prohibited |
| Adapter declaration | prohibited |
| MoonFlow work item | prohibited |
| Live suite discovery | prohibited |
| New installation or client binding | prohibited |
| Historical state inspection | retained |
| Conflict-safe migration into MoonGate | available from MoonGate |
| Isolated rollback diagnosis | retained, operator-controlled |

No current catalog may resolve an operation beginning with `moonstat/`. No new
manifest, adapter request, workflow, receipt or suite-status projection may use
MoonStat as its current product identity.

## Evidence exception

Historical evidence must remain truthful. Existing paths, source text, state
records, logs and immutable receipts can contain `moonstat`. They must be
classified as historical or migration input, never projected as live
inventory. Renaming such records in place would break digests and provenance.

## State and security

Legacy state commonly resides at `.moonsuite/products/moonstat`. It may contain
credentials, control tokens, provider configuration and usage records. Backups
must preserve file digests and restrictive permissions. Migration must not
follow symbolic links, overwrite a differing canonical file, expose secrets in
logs, or delete the source.

MoonGate's `suite migrate-legacy-state` command is the only supported state
bridge. Its accepted receipt is evidence of convergence, not permission to
erase the source.

## Operational rule

Never run MoonStat and MoonGate for the same workspace concurrently. Normal
operations use MoonGate only. A legacy executable may be used solely in an
isolated diagnostic workspace after MoonGate is stopped and with a named
operator responsible for the rollback.

## Release and retirement gates

Retirement is complete for a workspace when:

- both pre-migration state trees were backed up;
- the MoonGate migration receipt is accepted;
- current clients, environment and providers use canonical identity;
- current suite and capability projections contain MoonGate only;
- representative routing, accounting and restart checks pass;
- the legacy state is retained or archived according to policy.

This repository is not released as a supported application. Improvements to
provider, usage, UI or packaging behavior belong in MoonGate.
