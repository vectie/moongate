# Compare two exported usage snapshots

Use this offline workflow when reviewing what changed between two local request
exports, such as a before/after routing trial or two reporting periods. It accepts
the same CSV, JSON, JSONL and reopened preview envelopes as
[Usage File Explorer](usage-file-explorer.md). No running gateway or account is
needed. Input files and persistent usage are left unchanged.

## Run a comparison

```sh
output_dir="$(mktemp -d)"
moongate usage compare --before examples/usage/compare-before.csv --after examples/usage/compare-after.json > "$output_dir/comparison.json"
moongate usage compare --before examples/usage/compare-before.csv --after examples/usage/compare-after.json --report > "$output_dir/comparison.txt"
```

These examples create a fresh output directory, leaving bundled examples and
previous results untouched. The input paths above are relative to the checkout.

The small `cmd/compare_usage` companion runs the exact same command implementation:

```sh
compare_usage --before examples/usage/compare-before.csv --after examples/usage/compare-after.json --report
```

Both commands read files; file contents are not put in process arguments. JSON
is printed by default, `--report` prints readable text. Redirect stdout only to a
new destination, never either input path. A command failure exits nonzero and
may leave a redirected file containing an error rather than a comparison.
Unknown/duplicate flags, missing paths and malformed imports reject the operation.

## Select comparable slices

`--app`, `--provider`, and `--model` are exact, case-sensitive filters applied to
both files. Select independent inclusive UTC day windows with
`--before-start-day`, `--before-end-day`, `--after-start-day`, and
`--after-end-day`:

```sh
moongate usage compare --before before.csv --after after.json --app codex --before-start-day 2026-10-01 --before-end-day 2026-10-07 --after-start-day 2026-10-08 --after-end-day 2026-10-14 --report
```

Either bound may be omitted. Undated rows are included without date filters and
excluded when any bound is active on that side. Invalid or reversed dates fail
with the offending side identified. The output retains each requested window,
observed earliest/latest day, undated count, imported/selected row counts, source
total and partial flag. Observed dates do not establish full interval coverage.

## Read the result honestly

- Every delta is **after minus before**, over selected imported rows. Token and
  request percentage changes are null when the before value is zero, including
  zero-to-zero. There is no per-day normalization or throughput claim.
- By-model, by-app and by-provider groups are sorted lexically by key. Their union
  includes added and removed groups; a missing group contributes zero observed
  rows on that side. Present means it appears on both sides, not that it changed.
- `delta.knownEstimatedUsd` compares only recorded USD estimates. It can decrease
  simply because a file lost price telemetry; that is not proof of savings.
- `estimatedUsdDelta` is null when either source is partial or the relevant
  selected group has missing costs. Otherwise it compares file-supplied estimates
  for those rows. Zero is a known estimate; blank/null/invalid costs are unknown.
  Both sides' missing-cost counts remain visible. No catalog prices, exchange
  rates or settled provider charges are inferred.
- The files are independent snapshots. Rows are not matched or deduplicated by
  request ID. Do not interpret differences as new charges, refunds, causal policy
  effects or reconciliation of overlapping exports. Equal-size windows can still
  have different coverage and traffic mix.
- JSON uses `moongate.usage-comparison.v1`. It is an aggregate comparison artifact,
  not a request export to reopen in the single-file explorer. Request IDs and raw
  payloads are omitted; source paths and group labels remain. Inspect before sharing.

Each file remains limited to 4 MiB UTF-8 and 10,000 rows. Invalid token values
reject the whole import; accepted aliases, numeric strings, exponent notation,
USD estimates and dates follow the explorer's existing contract. For reliable
numeric differences, comparison additionally rejects a selected aggregate token
or known-estimate total above 9,007,199,254,740,991. Selected token totals derived
from input plus output must also fit that bound; an explicitly supplied total
retains precedence over the component counts. Partial exports stay partial;
no missing page is fetched. Large row sets may produce large group reports.

The pure `usage_preview.compare_usage_files_json` API provides the same JSON
without filesystem access. This workflow does not activate routing policies,
change authority, dispatch models, reconcile bills or certify a live route.
