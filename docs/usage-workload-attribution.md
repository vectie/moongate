# Assign saved usage to workloads

When several projects use the same app, provider and model, those existing groups
cannot show which work produced the requests. This offline editor lets an operator
assign exact request IDs to workload labels, find the remaining unassigned rows,
correct assignments, and export a private spreadsheet review.

This is a bounded MG02 usage-review workflow. Labels are operator-authored,
unverified commentary, not billing ownership, settled charges, approved budgets,
MoonProj commitments or route/execution authority. No provider is contacted.

## Prepare and inspect

Start with a `moongate.usage-file.v1` JSON artifact from an existing MoonGate
capture importer or usage preview. Every row must have its original explicit,
unique `requestId` and canonical numeric `totalTokens`; `row-N` IDs are reserved
because older previews synthesize them. Merge overlapping exports first. Choose
one request-ID namespace yourself, such as an export session. If the usage was
merged, reuse its exact `usageMergeScope`.

The examples below are synthetic, with four saved requests out of eight reported,
40 tokens, USD 0.35 in known estimates, and one unknown cost.

```sh
moongate usage attribute --file examples/usage/workload-usage.json --scope fixture-run --unassigned --report
moongate usage attribute --file examples/usage/workload-usage.json --scope fixture-run --plan examples/usage/workload-plan.json > review.json
moongate usage attribute --file review.json --scope fixture-run --workload Research --report
moongate usage attribute --file review.json --scope fixture-run --unassigned --csv requests > unassigned.csv
```

Use a new output filename. Shell redirection truncates its destination before a
program starts; never redirect onto an input. The command itself only reads input
files and prints a complete result to stdout, or an error to stderr with nonzero
status and no result. It does not save to the gateway database.

## Edit a plan, then save a revised review

`moongate.workload-plan.v1` contains only `schema`, `scope`, and a `changes` array.
Each change contains exactly `requestId`, `expectedWorkload`, and `workload`.
Use JSON null for unassigned. A nonempty string assigns a label; null removes it.
Labels match exactly, including case, Unicode and whitespace. A literal label
`Unassigned` is an ordinary assigned label, distinct from actual null assignments.

```json
{
  "schema": "moongate.workload-plan.v1",
  "scope": "fixture-run",
  "changes": [
    {"requestId":"request-a","expectedWorkload":"Research","workload":"Support"},
    {"requestId":"request-b","expectedWorkload":"Research","workload":null},
    {"requestId":"request-d","expectedWorkload":null,"workload":"Research"}
  ]
}
```

```sh
moongate usage attribute --file review.json --scope fixture-run --plan examples/usage/workload-revise.json > revised.json
moongate usage attribute --file revised.json --scope fixture-run --csv groups > workloads.csv
moongate usage attribute --file revised.json --scope fixture-run --workload Research --csv requests > research.csv
moongate usage attribute --file revised.json --scope fixture-run --unassigned --report
```

After revision, Support has 12 tokens/USD 0.25, Research has 5 tokens/USD 0.10,
and the one unassigned request has 23 tokens and unknown cost. Totals remain
40 tokens/USD 0.35 with one missing cost. Repeating a stale plan fails rather than
overwriting newer labels. A duplicate or unknown request ID, mismatched namespace,
unexpected field or invalid label rejects the whole edit; no partial result is
printed. Correct the plan against the current assignments and retry.

## Saved artifact and views

The artifact remains `moongate.usage-file.v1`, with all normalized usage rows in
`data`. `workloadReview` adds schema `moongate.workload-review.v1`, scope, exact-ID
assignments, all-row groups, a selected view, and a readable report. Reopening
recomputes summaries and ignores saved projections; only assignments are editable
operator state. Filtering never deletes other rows or labels from saved JSON.

- `--workload LABEL` selects an exact label; no match produces an empty view.
  For a label beginning with `--`, use the exact-value form
  `--workload=--ops` (quoting the whole argument when it contains spaces).
  All value-taking options support `--option=value`; the value after the first
  equals sign is preserved exactly, including further equals signs. For example,
  `"--workload=  --ops=night  "` selects that complete label with surrounding spaces.
- `--unassigned` selects rows with no assignment. It cannot combine with workload.
- `--csv requests` exports only selected rows and their labels.
- `--csv groups` exports every workload group and unassigned group. It rejects
  filters to avoid silently exporting a different scope from the requested one.
- `--report` prints selected totals plus the all-row group breakdown.
- Omit a format flag to save resumable JSON. Reports and CSV are not resumable.

The ordinary usage preview, pricing, merge and reroute tools do not preserve this
new sidecar. Keep the dedicated review and reopen it with `usage attribute`.
Existing usage consumers can still read its ordinary rows. Capture-specific
diagnostics and arbitrary payload fields are not retained by normalization; keep
the original capture/import artifact separately.

## Evidence and privacy limits

Original provider/model/token/cost fields remain the normalized saved values.
No prices are invented; unknown cost remains null and is excluded from known
estimated USD, with missing-cost counts shown separately. Explicit zero survives.
Partial/unknown source coverage remains visible; absent requests are never
attributed. Supplied totals are unverified local evidence, not provider billing.

Prompts and arbitrary payloads are omitted by normalization. IDs, models, scope,
and operator labels remain private and are not automatically redacted. CSV quotes
and apostrophe-prefixes every text cell to keep formula-looking labels inert.
Keep files private and review labels before sharing. JSON duplicate keys reject.

Limits: 4 MiB per input/output artifact, 10,000 request rows and edits, labels and
scope at most 200 UTF-16 units, IDs at most 1,024 units, and exact nonnegative safe
JSON integer counts (combined total at most 9,007,199,254,740,991). Costs use finite
nonnegative floating-point estimates, not monetary settlement arithmetic. The
command accepts canonical saved usage JSON, not raw provider captures or CSV.

## Lightweight entrypoint and verification

`cmd/attribute_usage` exposes the same arguments without loading the gateway:

```sh
moon run cmd/attribute_usage --target native -- --file examples/usage/workload-usage.json --scope fixture-run --plan examples/usage/workload-plan.json --report
moon test usage_preview usage_attribute_cli --target native --deny-warn
```

`scripts/verify_workload_attribution.mbtx` runs a complete native CLI journey with
synthetic files: inspect, assign, save, reopen, filter, revise, CSV export, stale
edit/namespace failures, and unchanged original-byte checks. It takes an already
built `attribute_usage.exe`, the examples directory, and a fresh output directory.
Browser, installed gateway, real provider, settlement and release qualification
remain separate and unclaimed.
