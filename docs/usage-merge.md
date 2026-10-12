# Merge overlapping local usage exports

Use this workflow to combine saved pages or overlapping request exports into one
reviewable usage file without counting identical request rows twice. It accepts
the same request CSV, JSON, JSONL and preview envelopes as the Usage File Explorer.
It reads local files only. No gateway, provider, credentials or account is needed.

## Run and reopen

```sh
out="$(mktemp -d)"
moongate usage merge --scope fixture-gateway --file examples/usage/merge-page-one.json --file examples/usage/merge-page-two.csv > "$out/merged.json"
moongate usage preview --file "$out/merged.json" --report
moongate usage merge --scope fixture-gateway --file examples/usage/merge-page-one.json --file examples/usage/merge-page-two.csv --report > "$out/merge-report.txt"
```

The smaller `cmd/merge_usage` executable accepts the identical options and invokes
the same MoonBit implementation. `--file` is repeatable, in source order, for 2 to
20 files. `--scope` is required once. `--report` prints text instead of JSON.
Unknown options, duplicate singleton options and missing values are errors.
Redirect to a new destination, never any input. Errors exit nonzero; a redirected
file may contain an error instead of a usage artifact. The command does not write
files itself. File contents are not passed as process arguments.

Use the preview command or file explorer to filter the successful merged output.
Merging first checks every imported row, so a later filter cannot hide conflicts.

## Request identity and conflicts

The identity is the exact, case-sensitive request ID within the caller-named
scope. Choose a scope for one gateway/account request-ID namespace and use only
exports belonging to it. Scope is a label you supply, not an authenticated identity
or proof of globally unique IDs. Exports from different accounts or gateways must
not be merged just because their request IDs happen to match.

Every row must have an explicit nonempty string `requestId`, `request_id` or `id`.
The reserved form `row-` followed by digits is refused because old preview files
synthesize that shape for missing IDs without retaining their origin. This also
refuses genuine IDs with that form: use original exports with stable non-reserved
IDs rather than editing IDs to force unrelated rows together. Anonymous rows are
not silently assigned merge identities.

The first occurrence determines output order. Subsequent occurrences of that ID
must match all normalized fields: app, provider, model, UTC date, input/output/total
tokens and estimated USD. Identical normalized rows count once, within a file as
well as across files. Any conflict rejects the whole operation with the request
ID, both source/row references and differing field names. No last-write-wins rule,
price enrichment, telemetry correction or conflict override is applied. In
particular, unknown cost and known zero are different. Inspect the source records
and obtain corrected exports before trying again.

Equality follows the existing reader's normalization. Aliases and numeric strings
can match. Timestamps are normalized to UTC day; two times on the same day are not
distinguished. Extra payloads, headers, status fields, cache breakdowns and other
unsupported data are discarded and are not compared. This is deduplication of
normalized exported usage evidence, not proof that two provider executions were
the same, nor reconciliation of settled charges.

## Provenance and missing telemetry

The result is a reopenable `moongate.usage-file.v1` envelope. `usageMerge` adds:

- `moongate.usage-merge.v1`, the scope and exact-ID identity description
- Input, unique and identical-duplicate row counts
- Ordered source names, source indices, imported row counts, reported source
  totals and partial flags
- One occurrence reference per imported row (request ID, 1-based source index,
  1-based data row). CSV row numbers exclude the header; JSONL row numbers count
  parsed nonblank records
- Interpretation caveats

Overlapping source totals cannot be added or used to infer the number of missing
requests. The merged `sourceTotal` is the number of observed unique rows only.
If any input reports unavailable rows or already has unknown coverage, the result
carries `sourceCoverageUnknown: true` and `partial: true`. This remains true even
if other inputs might fill a gap; the merge has no evidence proving completeness.
Original numeric totals remain in `usageMerge.sources` for review.

The explorer preserves `sourceCoverageUnknown` and `usageMergeScope` on reopen,
filter and re-export. It does not retain the merge's detailed source/occurrence
metadata; keep the original merged artifact for that audit trail. Re-merging an
artifact with a different explicit scope fails. Scope survives explorer re-export.
Comparison also sees incomplete coverage and leaves estimated USD delta unknown.

Missing costs stay unknown; explicit zero remains zero. Known estimates sum only
unique recorded rows. Missing request usage cannot be recovered from a source
total, and a Batch-import artifact may omit unsuccessful or unmetered requests;
its partial evidence remains visible, but its Batch diagnostics are not merged.
No provider charge, refund, accounting write, request retry, or billing settlement
is inferred or performed. Only the allowlisted normalized usage fields are kept;
IDs, group labels, scope and local paths remain. Review them before sharing.

## Limits

Combined input is at most 4 MiB UTF-8 and 10,000 imported rows, including duplicate
rows. Output is checked against the same 4 MiB reopen limit, including provenance
and pretty-printed JSON. Large IDs or labels can therefore require smaller slices.
Unique token and known-estimate totals must remain within 9,007,199,254,740,991;
unsafe totals reject rather than yielding misleading aggregates. Numeric parsing
and floating-point estimated USD follow the existing explorer; this is not
exact-decimal financial arithmetic or a price calculator.
