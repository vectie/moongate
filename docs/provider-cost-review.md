# Review saved provider costs beside local usage estimates

MoonGate's offline `usage review-costs` command combines two different sources:
your local request usage export and one saved OpenAI organization Costs API JSON
page. It produces a daily comparison, readable report or spreadsheet CSV. This
helps locate days needing investigation without manufacturing request records
from aggregated provider costs or changing the usage store.

## Try the synthetic example

Create a fresh output directory named `NEW`, then run from this checkout:

```sh
moongate usage review-costs --file examples/usage/cost-review.csv --costs examples/usage/openai-costs.json --provider fixture-route --app editor --project fixture-project --line-item text --scope 'Synthetic editor text activity for fixture-project; saved corresponding captures' > NEW/review.json
moongate usage review-costs --file examples/usage/cost-review.csv --costs examples/usage/openai-costs.json --provider fixture-route --app editor --project fixture-project --line-item text --scope 'Synthetic editor text activity for fixture-project; saved corresponding captures' --report > NEW/report.txt
moongate usage review-costs --file examples/usage/cost-review.csv --costs examples/usage/openai-costs.json --provider fixture-route --app editor --project fixture-project --line-item text --scope 'Synthetic editor text activity for fixture-project; saved corresponding captures' --csv > NEW/review.csv
```

The native `cmd/review_costs` companion takes the same options without the
`usage review-costs` prefix. Both call the same native library. Inputs are file
paths, never private content in process arguments. Never redirect over an input:
shell redirection truncates its output before the command runs. A nonzero exit
means no valid result; failed commands emit no partial JSON/CSV on stdout.

The example selects four of six local requests and four of six provider cost
results. November 1 has USD 1.50 in local estimates versus USD 2.00 in reported
provider costs (including a synthetic negative adjustment). November 2 has
explicit zeros on both sides. These two paired days differ by USD 0.50.
November 3 has an unknown local estimate. November 4 has no provider bucket.
Neither day is silently counted as zero or included in the paired difference.

Edit a copy of the first local estimate from 1.5 to 2 and rerun: the paired
difference becomes zero, while the two missing-evidence days remain unresolved.
This demonstrates investigation with new local evidence, not a correction to
any provider charge or an assertion that local estimates should equal it.

## Prepare corresponding sources

- Usage: raw request CSV, JSON request object/array, JSONL request records or a
  JSON `data`-array envelope such as `moongate.usage-file.v1`.
  `--provider` is required and exact; optional `--app` is also exact. Keep the
  original evidence and its partial/unknown-coverage markers.
- Costs: one saved response object with `object: "page"`, `data` buckets and a
  boolean `has_more`. Each bucket has numeric `start_time`, `end_time`, `results`;
  each result must be `organization.costs.result`. `amount.value` must be a JSON
  number and its `currency` must explicitly be `usd`. Missing amount/value stays
  unknown; a present amount without USD currency is unsupported.
- Optional `--project` and `--line-item` select exact provider grouping labels.
  When a filter is requested, every result must have that explicit grouping
  label. A null label cannot prove membership, so the review rejects it rather
  than assuming all or none. With no such filter, all returned groups are summed.
- `--scope` is required: explain why the selected local activity corresponds to
  the saved provider query, including account/project, apps, services and capture
  interval as needed. The output labels this as your unverified assertion.
  The API response does not prove the original query filters or capture coverage.
  If a local route combines projects, first prepare the correct local subset;
  a provider label alone does not establish project correspondence.

Retained evidence is inspected before the general usage normalizer can discard
it. CSV containing `usageEvidenceKind`, `usageScenarioName`, `usagePricing`,
`sourceTotal`, `importedRows`, `filteredRows`, `partialSource`,
`sourceCoverageUnknown` or `partial` headers rejects, even if the cell says
`false` or is blank. MoonGate spreadsheet CSV is explicitly one-way output;
use the original recorded JSON envelope rather than attempting that round trip.
Quoted headers, surrounding header whitespace and a UTF-8 BOM do not bypass
this check. The same provenance fields on individual JSON or JSONL request
rows reject rather than silently disappear.

In supported JSON envelopes, `partial`, `partialSource` and
`sourceCoverageUnknown` must be booleans; any true flag is retained conservatively.
`sourceTotal`, `total`, `importedRows` and `filteredRows`, when present, must be
whole JSON-number counts. Counts below the available row count reject; higher
source/import counts make the review partial. `filteredRows` must equal the
available row count. Hypothetical/scenario metadata rejects even when a marker
is null or its usual companion marker is absent. Transcript `messages` wrappers
and malformed `data` wrappers are unsupported and reject.

The first present field in `createdAt`, `created_at`, `timestamp`, `date` order
is validated before normalization, matching the existing reader's precedence.
For a nonempty value, supply a valid YYYY-MM-DD,
a complete timestamp with `T`, seconds and `Z` or a numeric `+HH:MM`/`-HH:MM`
offset, or a numeric JSON Unix timestamp. Optional timestamp fractions contain
one to nine digits. Invalid text, trailing junk and zone-free timestamps reject
the entire review, even on an unselected row. Missing/null/empty dates remain
undated and suppress comparisons when selected. Valid offset timestamps still
normalize to UTC, and exact midnight belongs to the following day.

The [official Costs API reference](https://developers.openai.com/api/reference/resources/admin/subresources/organization/subresources/usage/methods/costs)
documents inclusive query start, exclusive end, daily buckets, grouped cost
results, currency and pagination. This implementation was checked against that
reference on 2026-10-13. It accepts only complete, midnight-aligned UTC day buckets
because the existing local explorer normalizes timestamps to UTC dates. Clipped
or offset buckets are rejected rather than incorrectly aligned. It handles up
to 180 buckets, the documented maximum page size. It makes no API requests and
does not acquire or use an admin key. Save authorized exports separately.

## What the result means

Every observed selected local day and every provider bucket is shown in sorted
order, including days outside the other source. Costs results are aggregates,
not request counts. They never enter `data` as fake requests. Known subtotals
are accompanied by known/missing counts; null means unavailable. Empty buckets,
no matching groups and no local observations do not prove zero consumption.

`reportedMinusEstimatedUsd` is available only when that day has selected local
observations, a provider bucket with selected results and no missing amount on
either side. Any partial local source, selected undated request, or provider
`has_more: true` suppresses all day differences. Paired totals cover only days
passing these checks, not the whole capture. `has_more: false` establishes only
that this saved page reports no subsequent page; it cannot prove earlier pages,
query filters or all real activity were captured. No interpolation fills gaps.

No percentage, invoice reconciliation, settled-charge claim, savings conclusion,
tax treatment or cause of discrepancy is inferred. Provider reports may include
different services, discounts, adjustments or timing. Signed provider values
are retained; local usage keeps the explorer's nonnegative-estimate semantics.
Arithmetic is double precision, not a decimal accounting ledger. Per-day source
totals, every daily difference and paired totals/differences are bounded to
+/- USD 1e12. Offsetting days cannot cancel an unsupported daily difference.
Inputs total at most
4 MiB, usage at most 10,000 rows and provider results at most 10,000. Output is
bounded to 4 MiB. Duplicate/overlapping day buckets reject; repeated results
within a bucket remain separate observations because the schema gives no
deduplication identity. Never concatenate page responses into one bucket.

Hypothetical route markers and retained `usagePricing` scenario metadata reject
as recorded evidence before parsing loses them. If another tool stripped provenance, this command cannot
recover it; select authentic recorded estimates, not scenario exports. Payloads,
headers, request IDs and API-key IDs are omitted. Caller-supplied labels and scope
remain visible; inspect them before sharing. CSV text is quoted and apostrophe-
prefixed, with blank unknown numeric cells and provenance on every row.

The report is a separate `moongate.provider-cost-review.v1` artifact, not an input
to the request Usage File Explorer. Keep the original usage file for that
explorer. Public APIs are `costs_review.review_openai_costs_json` and
`costs_review.export_openai_costs_review_csv`.

## Repeat the actual process journey

Build `cmd/main` and `cmd/review_costs` natively. Build/run
`scripts/verify_cost_review.mbtx` on the native target with the absolute native
build's `cmd` directory, `examples/usage` directory and fresh output directory as
arguments. It exercises both command entry points, reports, CSV, deterministic
replay, an edited-estimate rerun, partial-page handling, original negative paths
and byte-for-byte preservation of both original inputs. The repaired journey
also checks both command entry points reject retained CSV provenance and invalid
timestamps and preserve an explicit partial JSON envelope.

This contributes fixture evidence to PRD MG02 / MOONGATE-B04 only. It does not
promote requirement status or qualify live billing, provider access, browser UI,
installed lifecycle, production policy or a MoonGate release.
