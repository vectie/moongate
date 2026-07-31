# MoonStat (retired)

> **Retired legacy repository · non-callable migration source.**
> [MoonGate](https://github.com/vectie/moongate) is the sole live owner of
> provider routing, proxying, credentials, usage accounting, resilience and
> capability observation in MoonSuite.

MoonStat was the pre-rename implementation of MoonGate. It is retained so
historical state can be inspected, backed up and migrated without losing its
original interpretation. It is not a second product, a pack, an installable
capability, or a supported suite service.

## Canonical identity

| Surface | Canonical live value |
| --- | --- |
| Product | MoonGate |
| Product and service ID | `moongate` |
| Repository and MoonBit module | `vectie/moongate` |
| Executable | `moongate` |
| Environment prefix | `MOONGATE_` |
| Product state | `.moonsuite/products/moongate` |
| Provider entry | `providers.moongate` |

New manifests, workflows, capability catalogs, adapter declarations, receipts
and suite-status projections must not emit `product_id: "moonstat"` or an
operation beginning with `moonstat/`. Historical MoonStat files and immutable
receipts may retain the old spelling because rewriting evidence would destroy
its provenance.

## What may still use this repository

- read-only historical and security investigation;
- a source-compatible interpretation of legacy MoonStat state;
- isolated rollback diagnosis after MoonGate has been stopped;
- migration tests that prove MoonGate consumes legacy state without changing
  the source.

Do not start MoonStat as part of a normal MoonSuite installation, discover it
as a live service, bind a new client to it, or add features here. Never run
MoonStat and MoonGate against the same workspace at the same time.

## Migrate to MoonGate

MoonGate owns the only supported compatibility bridge:

```sh
cd /path/to/moongate
moon run cmd/main -- suite migrate-legacy-state \
  --root /path/to/workspace \
  --migration-id moonstat-to-moongate
```

The command copies only missing regular files into canonical MoonGate state,
does not modify or delete the legacy source, rejects symbolic links, preserves
restrictive permissions for likely secrets, and writes a reviewable receipt.
Conflicting files make the receipt unaccepted and require an operator decision;
they are never overwritten.

Follow the complete backup, migration, acceptance and rollback procedure in
[Migration to MoonGate](docs/MIGRATION_TO_MOONGATE.md). The live product's
technical migration contract is maintained in
`moongate/docs/MOONGATE_TECHNICAL_MIGRATION.md`.

## Repository contract

The normative lifecycle and ownership rules are in
[Product contract](docs/PRODUCT_CONTRACT.md). The remaining work is limited to
the retirement plan in [PLAN.md](PLAN.md).

The legacy MoonBit source, tests, Lepusa manifests and UI assets remain in this
repository as historical implementation material. Their presence does not make
MoonStat callable in current MoonSuite catalogs. Detailed pre-retirement
feature documentation remains available in Git history at the last MoonStat
implementation commit.

## Focused maintenance

Documentation-only retirement changes require:

```sh
git diff --check
```

If a security or migration fix must touch MoonBit source, also run the smallest
affected package checks and then:

```sh
moon check --target native --deny-warn
moon test --target native --deny-warn
moon info
moon fmt
```

Such a fix must preserve legacy state interpretation and must not create a new
MoonStat runtime, pack, capability or suite identity.
