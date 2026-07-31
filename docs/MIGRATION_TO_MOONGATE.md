# Migrate legacy MoonStat state to MoonGate

This procedure converges a workspace onto one live identity without modifying
the legacy source. MoonGate owns the migration implementation and receipt.

## Preconditions

- Use a reviewed MoonGate checkout containing
  `suite migrate-legacy-state`.
- Identify the exact workspace root. Product paths are relative to that root,
  not necessarily the current repository.
- Name the operator and a maintenance window.
- Stop both executables and verify the proxy port has no writer.
- Treat both state trees as sensitive.

The expected paths are:

```text
<workspace>/.moonsuite/products/moonstat
<workspace>/.moonsuite/products/moongate
```

## 1. Back up both sides

Before migration, create separate timestamped backups of each existing tree.
Store them outside `.moonsuite/products/moonstat` and
`.moonsuite/products/moongate`.

The backup receipt should contain:

- workspace and source paths;
- operator and UTC timestamp;
- recursive file digests;
- file type and permission metadata;
- backup location and verification result.

Do not print credential contents. A missing source is valid and will become an
accepted no-op migration.

## 2. Run the canonical migration

From the MoonGate repository:

```sh
moon run cmd/main -- suite migrate-legacy-state \
  --root /path/to/workspace \
  --migration-id moonstat-to-moongate
```

Choose a unique, path-safe migration ID for each attempt. MoonGate writes the
receipt under:

```text
<workspace>/.moonsuite/products/moongate/migrations/<migration-id>.json
```

The command:

- copies a missing regular file;
- skips a byte-identical destination;
- reports a differing destination as a conflict;
- rejects symbolic links and unsupported entries;
- gives likely secret/token files mode `0600`;
- gives other copied files mode `0644`;
- never modifies or deletes the MoonStat tree.

## 3. Review the receipt

Check the source, destination, migration ID, copied count, identical-skip count,
conflicts, errors and `accepted` value.

Do not continue when `accepted` is false. Compare each conflict against both
backups, decide which value is canonical, make that decision explicitly in
MoonGate state, and rerun with a new migration ID. Never replace the canonical
tree wholesale with the legacy tree.

Re-running after a successful copy is safe: previously copied files should be
reported as identical skips.

## 4. Rebind current operation

Update live configuration to the canonical identity:

| Legacy | Canonical |
| --- | --- |
| `moonstat` executable | `moongate` |
| `MOONSTAT_*` environment | `MOONGATE_*` |
| `.moonsuite/products/moonstat` live state | `.moonsuite/products/moongate` |
| `providers.moonstat` | `providers.moongate` |
| MoonStat suite/client entries | MoonGate entries |

Use MoonGate's current install and binding commands for managed clients. Do not
copy old generated suite-status files into current discovery. Do not expose a
MoonStat compatibility endpoint or capability alias.

## 5. Accept

Start MoonGate only and verify:

```sh
moongate health
moongate status
moongate stats
moongate suite manifest
moongate suite status
```

Then route one representative non-secret request, inspect its provider/model
attribution in MoonGate usage, and restart once to prove canonical state
recovery. Confirm that current capability resolution cannot return a
`moonstat/...` operation.

Record named acceptance and retain the old tree read-only for the required
period.

## Rollback

Rollback does not restore MoonStat as a product.

1. Stop MoonGate.
2. Preserve the failed canonical state and migration receipt.
3. Restore the pre-migration MoonGate backup if later writes must be undone.
4. For legacy diagnosis, use a copied, isolated workspace and the preserved
   MoonStat state. Do not bind it into MoonSuite and do not share MoonGate's
   port or state tree.
5. Record operator, reason, timestamps and digests.
6. Fix the MoonGate issue, take fresh backups and repeat migration.

Because migration never changes the source, rollback never needs to reverse an
in-place rename.

## Completion checklist

- [ ] Both pre-migration state trees backed up and verified
- [ ] MoonStat and MoonGate stopped during convergence
- [ ] Migration receipt reviewed and accepted
- [ ] No unresolved conflicts or unsupported entries
- [ ] Current clients and environment use MoonGate
- [ ] Current suite/catalog output contains no callable MoonStat identity
- [ ] Representative route, accounting and restart checks passed
- [ ] Legacy state retained or archived under policy
