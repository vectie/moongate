# Usage File Explorer

Open **Usage → Usage File Explorer** to review a temporary exported usage file independently of the gateway's live traffic. Choose a file, paste text, or try the sample, then select **Open / apply filters**. Filtering is exact and case-sensitive for app, provider ID and model. Dates are inclusive UTC days. Reset filters to see all available rows, or clear the file to discard the preview.

## Accepted input

- A JSON array of request objects
- Comma-delimited CSV with a header row (see below)
- One request object per JSONL/NDJSON line
- MoonGate's own `{data: [...], total, page, pageSize}` request envelope
- This explorer's downloaded JSON (reopen it with the same picker)

A row requires a nonempty model and numeric input/output token counts or a total token count. CamelCase and snake_case are accepted for `appType`, `providerId`, `requestId`, `inputTokens`, `outputTokens`, `totalTokens`, `totalCostUsd`, and `createdAt`. Numeric strings are accepted for counts and USD. `app`, `provider`, `modelName` / `model_name`, `id`, `costUsd` / `cost_usd`, and `estimatedCostUsd` are aliases. Missing app/provider labels become `Unknown`.

`createdAt` / `created_at` / `timestamp` can be Unix **seconds** or an ISO timestamp with an explicit `Z` or numeric offset; `date` can be `YYYY-MM-DD`. Exported rows retain the normalized UTC date rather than the original timestamp. Missing or unreadable dates appear as undated and are excluded when a date filter is active. Timestamps without zones and epoch milliseconds are not supported.

Total tokens use explicit `totalTokens` when supplied, otherwise input plus output. Cache-token breakdowns and other extra request fields are not retained. Costs are file-supplied estimates in USD; missing, null or unreadable costs remain unknown, while an explicit zero stays zero. Known estimated USD excludes unknown costs and is always accompanied by a missing-cost count. The explorer does not infer prices or currency conversions from the live catalog.

## Explore and keep the result

The report includes request/token totals, known estimated USD, missing-cost and undated counts, and breakdowns by app, provider, model and UTC day. The page displays the first 100 filtered rows; totals and downloads include every filtered row. A source envelope whose total exceeds its available rows is clearly labeled partial. The reader does not fetch missing pages or extrapolate their totals.

Download filtered JSON for reopening, or the readable text report for project notes. The JSON is normalized, not a lossless copy of the source. It includes source row-count provenance, so a filtered subset still reports its original source total after reopening. A zero-match filter can also be exported. Editing source or filters immediately invalidates prior downloads; apply again before exporting.

## Offline CLI

```
moongate usage preview --file examples/usage/requests.json
moongate usage preview --file examples/usage/requests.json --app codex --provider team-fixture --model moon-small --start-day 2026-10-06 --end-day 2026-10-07 > filtered.json
moongate usage preview --file filtered.json --report > usage-report.txt
moongate usage preview --file examples/usage/requests.jsonl
```

No running gateway, account or provider is needed by this CLI command. The UI submits the chosen text to its configured MoonGate gateway's stateless `POST /usage/preview` endpoint using the existing control-plane authentication. Source files and persistent TrafficStats/session usage are never modified. Files are held in the page until cleared, replaced or the page is closed; no browser storage is used.

Limits: 4 MiB of UTF-8 text and 10,000 rows per import. Malformed JSON/CSV or invalid request rows fail the whole import with an actionable error. Spreadsheet workbooks, aggregate-only billing tables and live provider downloads are outside this reader. Use the provided synthetic `examples/usage/requests.json` (partial page, mixed aliases, known/zero/unknown costs), `requests.jsonl`, and `requests.csv` to try the workflow.

## Open spreadsheet-exported request CSV

Choose a `.csv` file or paste comma-delimited text, then apply the existing app,
provider, model and UTC-day filters. The CLI uses the same preview:

```
moongate usage preview --file examples/usage/requests.csv --app codex > filtered.json
moongate usage preview --file filtered.json --report > report.txt
```

The header needs `model` and at least one token-count column. The aliases above
are accepted; header whitespace is trimmed, while cell text is preserved.
Quoted commas, doubled quotes, quoted newlines, CRLF/LF and a UTF-8 BOM work.
Every row must have exactly the header's cell count. Duplicate recognized
columns (including aliases), malformed quoting and extra blank rows reject the
whole import. A header-only CSV produces an empty preview. Semicolon/tab
delimiters and Excel `sep=` preambles are unsupported.

Only recognized fields are retained; other columns are discarded. An empty cell
omits the value. Missing costs remain unknown, and `0` remains a known zero;
missing input/output tokens remain missing while totals follow the rules above.
Amounts must already be USD estimates. No currency conversion, price lookup or
provider bill reconciliation occurs. CSV date cells support `YYYY-MM-DD` or ISO
timestamps with an explicit zone, not numeric Unix timestamps or spreadsheet
serial dates. Invalid dates become undated, as in the JSON reader. Token counts
must be whole nonnegative values within the existing safe-number range; malformed
costs remain unknown. Formula cells are never evaluated.

For a small offline review companion, build `cmd/import_usage_csv`. Its first
argument is literal CSV or JSON text. It runs the same `usage_preview` parser,
normalizer, filters and summary implementation as the main CLI and gateway.
It outputs a normalized preview envelope which can be reopened in the explorer
or companion. Options are `--app`, `--provider`, `--model`, `--start-day`,
`--end-day`, and `--report` (readable text instead of JSON).

```
import_usage_csv "$(cat examples/usage/requests.csv)" --app codex > preview.json
import_usage_csv "$(cat preview.json)" --report > report.txt
```

Use only synthetic or scrubbed text with this companion because process
arguments are visible. For private files use the main CLI's `--file` option or
the file picker. Importing and reviewing never send provider requests or change
persistent usage. The low-level `usage_csv.to_json` API converts only CSV shape;
the preview implementation additionally validates row values.

## Import OpenAI Batch results

Nested Batch result JSONL needs conversion before opening here. Use
`moongate usage import-batch --file results.jsonl [--errors errors.jsonl]` and
open the resulting JSON. It preserves recorded usage, explicit missing/error
coverage and unknown costs without retaining response bodies. See
[Batch usage import](batch-usage-import.md) for supported shapes and caveats.

## Compare exports

To review changes between two files, use `moongate usage compare --before FILE
--after FILE [--report]`. It reports observed request/token differences and
added/removed model, app and provider groups while retaining missing-cost and
source-coverage caveats. See [Compare two exported usage snapshots](usage-comparison.md)
for independent UTC windows, output fields and interpretation limits.

## Merge overlapping exports

Use `moongate usage merge --scope NAME --file FILE --file FILE [--report]` to
combine saved pages from one request-ID namespace. Identical normalized IDs count
once and conflicting rows reject the whole merge. The result can be reopened here;
unknown source coverage and scope survive filtering and re-export. Detailed merge
provenance is retained only in the original merged artifact. See
[Merge overlapping usage exports](usage-merge.md) for identity requirements and limits.

For latency samples in original exports, use the offline [latency profile](usage-latency.md). It provides nearest-rank percentiles and slowest-row drilldown without a running gateway.

## Anthropic Batch exports

Convert a saved Message Batches result JSONL file with `import_batch_usage --format anthropic --file results.jsonl`, then open its JSON here. Complete rows include all three input-token categories; absent cache telemetry remains incomplete rather than becoming zero. See [Anthropic Batch usage review](anthropic-batch-usage.md).

## Saved Ollama response captures

Use the offline [Ollama capture reader](ollama-capture-import.md) to collapse a
saved generate/chat stream into terminal usage evidence and inspect interrupted
or errored captures without contacting a provider.

## Take a review into a spreadsheet

Use `moongate usage export-csv --file FILE` for filtered request rows, or
`--view model|provider|app|day` for a grouped table. Export `--view summary`
with the same filters to retain totals and zero-match/source-coverage context.
See [Spreadsheet export](usage-spreadsheet-export.md) for apostrophe-prefixed
text, unknown-cost blanks and the one-way report contract.

## Saved Chat Completions responses

Use the offline [Chat Completions capture reader](chat-capture-import.md) to
review a saved JSON response or SSE stream as one request, then open the emitted
usage artifact for filters, groups and spreadsheet export. Missing usage and
interrupted captures remain explicit, without contacting a provider.
