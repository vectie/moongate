# MoonGate technical identity migration

## Outcome

MoonGate is the sole active identity of the suite's AI access, routing, usage,
and provider-health boundary. New code and state use:

| Surface | Canonical value |
|---|---|
| Product name | MoonGate |
| Product, service, and project ID | moongate |
| Repository and MoonBit module | vectie/moongate |
| Executable | moongate |
| Environment prefix | MOONGATE_ |
| Product state | .moonsuite/products/moongate |
| Client API | MoonGateClient and moongate_* |
| Web assets | moongate* |

The former technical name is not a runtime alias. It appears only in the
bounded state migration command and immutable historical evidence.

## Migration command

    moon run cmd/main -- suite migrate-legacy-state \
      --root /path/to/workspace \
      --migration-id moonstat-to-moongate

Input:

- the optional legacy directory .moonsuite/products/moonstat;
- any already-existing canonical directory .moonsuite/products/moongate;
- a safe migration ID used as the receipt filename.

Output:

- missing regular files copied into canonical state;
- likely credential and token files created with mode 0600;
- other copied files created with mode 0644;
- a receipt at
  .moonsuite/products/moongate/migrations/<migration-id>.json.

Acceptance criteria:

- no destination file is overwritten;
- byte-identical files are counted as idempotent skips;
- differing files are reported as conflicts and make accepted false;
- symbolic links and unsupported entries are rejected;
- the source directory is never deleted or modified;
- an absent source is a successful no-op with a receipt.

Operators must resolve reported conflicts explicitly. Re-running the command is
safe: files copied by a prior run are then counted as identical.

## Repository migration phases

### 1. Identity and storage

Input: the product constitution and the canonical MoonGate naming decision.

Output: module metadata, executable, service contracts, environment variables,
state paths, assets, client types, and tests all use the canonical identity.

Quality gate: source compiles, identity contract tests pass, and ordinary
runtime source contains no former technical name.

### 2. Suite consumers

Input: MoonLib plus MoonBook, MoonClaw, MoonTown, MoonRobo, and MoonDesk
dependencies on the old module and plugin package.

Output: canonical package directories, imports, client calls, startup checks,
configuration examples, and cross-product tests.

Quality gate: every affected repository passes moon check and moon test;
generated interfaces are rebuilt using moon info.

### 3. Workspace state

Input: the fresh-run ~/moonsuite registry, product state, and immutable
MoonFlow event history.

Output: canonical registry and current state plus a migration receipt and new
MoonFlow evidence. Historical events remain byte-for-byte unchanged.

Quality gate: current projections reference MoonGate, the migration receipt is
accepted, secrets retain restrictive permissions, and old event artifacts
remain available for audit.

### 4. Publication

Input: reviewed diffs and passing regression results.

Output: coordinated commits on upgrade/moongate-technical-migration, pushed
to every affected GitHub repository, with the MoonGate remote targeting
git@github.com:vectie/moongate.git.

Quality gate: local and remote commit IDs match and all worktrees are clean.

## Completion evidence

The coordinated migration completed on 2026-07-11.

- MoonLib 0.1.10 was published to the MoonBit registry. Publication validated
  the source tree and extracted package archive, then returned 200 OK.
- All consumer modules resolved the published version and passed moon check.
- Full suites passed: MoonLib 50/50, MoonGate 807/807, MoonBook 223/223,
  MoonClaw 1054/1054, MoonTown 978/978, MoonRobo 546/546, MoonDesk 533/533,
  and MoonFish 145/145.
- The public suite website production build passed.
- The canonical manifest reports service and project as moongate and exposes
  only canonical assets, commands, capabilities, paths, and provider IDs.
- The absent-source migration smoke produced an accepted no-op receipt.
- The real ~/moonsuite migration copied two files, recognized one identical
  file, reported no conflicts or errors, preserved the source, and attached its
  accepted receipt to MoonFlow event sequence 77.
- All ten migration worktrees were clean, their local heads matched GitHub, and
  ordinary tracked source contained no former technical identity.

Published branch: upgrade/moongate-technical-migration.

## Compatibility boundary

There is deliberately no normal executable, module, environment-variable,
client, plugin, asset, or state-path fallback under the former name. Supporting
two live identities would split receipts, credentials, usage data, and service
discovery. The migration command is the only compatibility bridge because it
converges state onto one canonical identity and records exactly what happened.
