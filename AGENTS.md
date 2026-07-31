# MoonStat repository guide

This is a MoonBit project containing the preserved pre-rename implementation of
MoonGate.

## Product lifecycle

MoonStat is retired. MoonGate is the sole live MoonSuite product for proxy
routing, providers, credentials, usage, resilience, capability observation and
suite health.

This repository is not a second product and must not gain new features. It is
retained for historical inspection, legacy-state interpretation, migration
verification and isolated rollback diagnosis.

Normative documents:

- `docs/PRODUCT_CONTRACT.md`
- `docs/MIGRATION_TO_MOONGATE.md`
- `PLAN.md`

## Identity rules

- Do not add a MoonStat pack, capability, adapter declaration or workflow node.
- Do not add current-state output with `product_id`, `service_id`, `project_id`
  or operation identity `moonstat`.
- Do not make MoonStat discoverable or callable from MoonFlow, MoonGate,
  MoonDesk or any other live product.
- Do not add new `MOONSTAT_` configuration. New live configuration belongs to
  MoonGate and uses `MOONGATE_`.
- Historical source, tests, state, logs and immutable receipts may retain the
  former identity. Do not rewrite evidence just to rename it.

## Allowed changes

- retirement and migration documentation;
- narrowly scoped security fixes needed to read or migrate legacy state safely;
- tests that prove source state is unchanged and destination conflicts are not
  overwritten;
- fixes necessary to preserve historical buildability for forensic use.

Feature work, provider additions, UI expansion, new suite integrations and
release packaging belong in `/Users/kq/Workspace/moongate`.

Do not delete the historical implementation, remove its framework parsers, or
change existing state formats as cleanup. Do not run MoonStat and MoonGate
against the same workspace at the same time.

## Project structure

- MoonBit packages are directories containing `moon.pkg`.
- Top-level blocks are separated with `///|`.
- Black-box tests end in `_test.mbt`; white-box tests end in `_wbtest.mbt`.
- Generated `.mbti` files are public-interface evidence and must be regenerated
  with `moon info`, never hand-edited.

## Editing and validation

Preserve unrelated worktree changes. Keep fixes small and package-local. Use
`moon ide` for semantic navigation and `moon fmt` for MoonBit formatting.

For documentation-only retirement work, run:

```sh
git diff --check
```

If MoonBit source changes, run the smallest affected tests first, then:

```sh
moon check --target native --deny-warn
moon test --target native --deny-warn
moon info
moon fmt
```

Only validate sibling products when a shared migration contract changed. Never
edit MoonDesk from this repository task.
