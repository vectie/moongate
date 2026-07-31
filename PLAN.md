# MoonStat retirement and MoonGate convergence plan

Status: active retirement plan
Last reviewed: 2026-07-31

## Outcome

MoonGate is the only live provider/proxy/usage product in MoonSuite. MoonStat
remains a read-only legacy implementation and migration source until retained
state has passed the organization's backup policy. It never competes with
MoonGate in discovery, capability resolution, workflow planning or execution.

## Invariants

- Do not implement new MoonStat product features.
- Do not create a MoonStat pack, adapter, capability manifest or flow node.
- Do not emit new current-state records with product, service or operation
  identity `moonstat`.
- Do not rewrite old evidence, receipts or state merely to change their name.
- Do not delete `.moonsuite/products/moonstat` during migration.
- Do not copy over a conflicting MoonGate destination file.
- Do not run MoonStat and MoonGate against the same workspace concurrently.
- MoonGate owns the migration command and every live provider/proxy/usage
  operation after acceptance.

## Phase 0 — Freeze the legacy surface

Deliverables:

- this repository is marked retired and non-callable;
- contributor guidance rejects feature work and dual identity;
- historical source, schemas, tests and state interpretation remain intact;
- no pack or capability metadata is introduced.

Exit gate:

- README, product contract and contributor guidance agree on MoonGate
  ownership;
- a repository scan finds no newly added callable MoonStat manifest.

## Phase 1 — Inventory and backup

For each workspace being migrated:

1. Stop the legacy process and MoonGate.
2. Record the workspace path, MoonStat state path, MoonGate state path and
   responsible operator.
3. Create independent, timestamped backups of both product-state directories
   if they exist.
4. Record file digests and permission metadata for the backups.
5. Store the backup receipt outside either live product-state directory.

Exit gate:

- backups can be listed and read;
- likely credentials and tokens are not group/world-readable;
- no process is writing either state tree.

## Phase 2 — Conflict-safe state convergence

Run the migration command from the canonical MoonGate repository:

```sh
moon run cmd/main -- suite migrate-legacy-state \
  --root /path/to/workspace \
  --migration-id moonstat-to-moongate
```

The command must:

- treat an absent MoonStat source as an accepted no-op;
- copy only missing regular files;
- count byte-identical destinations as idempotent skips;
- reject symbolic links and unsupported entries;
- report differing destinations as conflicts without overwriting them;
- leave the MoonStat source byte-for-byte untouched;
- write a MoonGate-owned migration receipt.

Exit gate:

- the receipt is present under canonical MoonGate state;
- `accepted` is true;
- copied, skipped, conflict and error counts are reviewed;
- the recorded source and destination match the intended workspace.

If the receipt is unaccepted, stop. Resolve each conflict explicitly from the
two backups and run a new migration with a new migration ID. Never use a bulk
overwrite to force acceptance.

## Phase 3 — Rebind live integrations

Deliverables:

- client configuration invokes `moongate`, not `moonstat`;
- environment variables use `MOONGATE_`;
- current provider entries use `providers.moongate`;
- current suite discovery and health project only `moongate`;
- MoonFlow graphs and capability catalogs contain no callable MoonStat node;
- old client bindings are disabled, not silently shared.

Exit gate:

- only one service owns the configured proxy port;
- MoonGate health, status, provider and usage views open successfully;
- an exact capability query cannot resolve a MoonStat operation;
- historical MoonStat evidence remains accessible as historical evidence only.

## Phase 4 — Acceptance and observation

Observe MoonGate through a representative provider route and usage record. The
named operator checks:

- provider credentials resolve without being exposed in logs;
- model routing and streaming behave as expected;
- request/provider/model attribution appears in MoonGate usage records;
- failover and circuit state are canonical;
- restart reloads canonical state;
- suite consumers reference MoonGate only.

Acceptance is recorded in the migration/change system used by the deployment.
The old directory remains retained and read-only for the configured retention
period.

## Phase 5 — Rollback, if needed

Rollback is an emergency, single-owner operation:

1. Stop MoonGate before changing any bindings.
2. Save the failed canonical state and its receipt; do not erase evidence.
3. Restore the pre-migration MoonGate backup if canonical state was mutated
   after migration.
4. If the legacy binary is required for diagnosis, point only an isolated test
   workspace at the preserved MoonStat state. Never run it beside MoonGate or
   advertise it to MoonSuite.
5. Record the reason, operator, timestamps and file digests.
6. Correct the MoonGate migration or runtime issue and repeat from Phase 1.

Rollback does not reactivate MoonStat as a product. It temporarily uses the
preserved implementation to understand legacy state.

## Phase 6 — Retention completion

After the organizational retention period:

- archive the legacy state and receipts according to data-class policy;
- verify the archive before considering local cleanup;
- keep immutable migration and acceptance receipts;
- remove obsolete local client bindings only after canonical operation is
  accepted.

Repository deletion and historical evidence rewriting are outside this plan.

## Validation budget

Use one proportional validation pass after a coherent retirement change:

- documentation-only: `git diff --check` and a focused identity/manifest scan;
- MoonBit migration/security fix: affected package tests, native
  warning-denied check/test, `moon info`, then `moon fmt`;
- cross-product contract change: validate in MoonGate and the affected
  consumer, not across every historical MoonStat integration.

The archived pre-retirement hardening roadmap is superseded. Any still-useful
provider, usage, UI or packaging work belongs in MoonGate's plan.
