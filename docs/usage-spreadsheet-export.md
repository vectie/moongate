# Export usage for a spreadsheet

`moongate usage export-csv` turns a saved usage file into an ordinary UTF-8,
comma-delimited spreadsheet table. It uses the same offline parser, aliases and
filters as the Usage File Explorer. No gateway, spreadsheet app, account or
provider request is needed. No persistent usage or source file is changed.

The small native companion `export_usage_csv` runs the same command implementation:

```sh
export_usage_csv --file examples/usage/requests.json > requests.csv
export_usage_csv --file examples/usage/requests.json --view model > models.csv
export_usage_csv --file examples/usage/requests.json --view summary > summary.csv
export_usage_csv --file examples/usage/requests.csv --app codex --start-day 2026-10-06 --end-day 2026-10-07 > codex.csv
```

Redirect to a **new file**, never the input: the shell truncates the destination
before the command starts. Check its exit status before opening the CSV. The
companion reports failures on stderr with no partial CSV on stdout. The main
CLI dispatcher is separately type-checked, not runtime-qualified here.

## Choose a table

- `--view requests` (default): request ID, app, provider, model, UTC date,
  input/output/total tokens and file-supplied estimated USD.
- `--view summary`: one row for the entire filtered selection, including zero
  matches. Keep this alongside a detail/group export as the review context.
- `--view model`, `provider`, `app`, or `day`: one sorted row per group, request
  count, token total, known estimated USD subtotal, missing-cost count and
  undated count. Empty labels use the explorer's `Unknown` bucket.

All populated rows also carry sourceTotal, importedRows, filteredRows,
partialSource and sourceCoverageUnknown. These are repeated contextual values,
not additive columns. Do not sum them. A request/group export with zero matches
has only a header; use the summary view to preserve its zero-match context.
Use identical filters and the same unchanged source for related tables.

Filters `--app`, `--provider` and `--model` are exact and case-sensitive. Date
filters use inclusive UTC days; undated rows are excluded with a date filter.
The source may be JSON, JSONL, a MoonGate envelope or comma-delimited CSV. The
source's pagination/unknown-coverage warnings remain explicit. Even a nonpartial
file establishes only the imported rows, not whole-provider coverage.

## Spreadsheet interpretation

Import as UTF-8 with comma delimiters and double-quote text quoting. Every nonempty text
cell has a leading apostrophe, including identifiers, dates and group keys. This
keeps formula-like labels inert and preserves values such as leading-zero IDs.
Depending on the spreadsheet import settings, the apostrophe may be visible.
It is deliberately part of the export. Do not remove it from untrusted labels
before opening them in a formula-capable application. Numeric cells remain
numeric. Quotes are doubled; embedded commas, CR/LF and Unicode are retained.
Rows use CRLF terminators. No formula or external-link field is generated.

Missing input/output counts or request costs are blank, while explicit zero is
`0`. Group/summary knownEstimatedUsd is only the known subtotal; consult
missingCostCount before interpreting it. A zero subtotal with missing costs is
not zero spend. All USD values remain file-supplied estimates, never settled
charges. No price lookup, conversion, extrapolation or deduplication occurs.
Use the existing merge workflow first when you intentionally need ID-based
merging of overlapping exports.

CSV is a one-way spreadsheet report, not a lossless interchange archive or a
replacement for the original JSON. Reimporting it through the explorer is not
a supported round trip: apostrophes are literal and extra provenance columns
are not restored by the existing CSV importer. Missing request IDs retain the
explorer's synthetic row labels; these are not provider request identities.

Limits: 4 MiB UTF-8 input, 10,000 source rows, 8 MiB CSV output. Grouped token
sums above the exact safe-integer range reject the export; narrower filtering
can reduce them. Spreadsheet applications may round large numeric values or
format USD to fewer decimals, so keep the original artifact for exact review.
Unknown extra input fields, payloads, headers and prompts are omitted by the
normalizer. Operator labels and IDs remain private data: inspect before sharing.
No browser/spreadsheet UI or live provider was exercised by this feature's tests.
