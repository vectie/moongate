# Review an Anthropic Message Batches export

Use an already-saved Message Batches result JSONL file with:

```sh
out="$(mktemp -d)"
import_batch_usage --format anthropic --file examples/usage/anthropic-batch-results.jsonl > "$out/usage.json"
import_batch_usage --format anthropic --file examples/usage/anthropic-batch-results.jsonl --report > "$out/report.txt"
```

`cmd/import_batch_usage` is the small qualified native executable. The integrated
`moongate usage import-batch --format anthropic` dispatcher calls the same shared
implementation; the monolithic main route is type-checked, not runtime-qualified
by this feature. Open the produced JSON in the existing Usage File Explorer to
filter by app, provider or model, inspect groups and export a selected subset.
All imported rows are undated, so a UTC-day filter excludes them.

The synthetic fixture has eight results: five `succeeded`, one `errored`, one
`canceled`, and one `expired`. Three results have complete token observations,
totaling 315 tokens. The other two succeeded results have missing or incomplete
usage. Three costs remain unknown. An explicit all-zero usage observation is
retained. The `max_tokens` stop is visible; success of a Batch request does not
establish a finished task or a correct answer.

No provider, browser, account, gateway, credential, billing service or internet
connection is used. This command reads local files without sending requests or
changing usage records. Use a **new output path**, never an input path: shell
redirection truncates the destination before the command runs. Failures exit
nonzero with an error instead of a partial JSON export; inspect exit status.

## Input and options

Select the wire format explicitly. `--format` accepts only `openai` or
`anthropic` and defaults to `openai`, preserving existing commands. Anthropic
input requires a unique nonempty exact `custom_id` per result and a `result`
object with one of the four types above. Succeeded results need an assistant
`message` with `type: "message"` and a nonempty model. Errored results need an
error object. Payload contents and error details are not validated or retained.
LF, CRLF, blank lines and an empty file work. Original result order and one-based
physical line numbers are retained; there is no request-position correlation.
Duplicate IDs, malformed JSON, invalid known fields or unsupported result types
reject the whole import. Files from different batches may reuse IDs; review
those separately rather than treating custom IDs as global identities.

`--app LABEL` and `--provider LABEL` replace defaults `anthropic-batch` and
`anthropic-export`. These are operator review labels, not verified routing
identity. `--errors FILE` can append another same-format result shard, with IDs
validated across both files and line numbers referring to their concatenation.
Anthropic failures normally already appear in the result file. `--requests`
remains OpenAI-only and is rejected with Anthropic before reading inputs. No
Anthropic request manifest join or submission/completeness check is performed.

Input is limited to 4 MiB UTF-8 combined, 10,000 nonblank lines and a 4 MiB
pretty-printed output envelope. Each input file is also byte-limited to 4 MiB.
Expanded diagnostics can exceed the output limit even for a smaller source;
use a smaller local slice if this happens. Limits apply to the supplied slice,
not a whole provider batch. No file is silently truncated.

## Token meanings and unknowns

The importer keeps four independent observations from `message.usage`:

- `input_tokens`: uncached input
- `cache_creation_input_tokens`: cache-writing input
- `cache_read_input_tokens`: cache-reading input
- `output_tokens`: output

Only rows with all four known components enter normalized `data` and the
existing explorer totals. Input is the sum of the three input categories;
total is input plus output. Nested `cache_creation` TTL subtotals are already
included in their parent and are not added again. Other usage extensions,
including server-tool request counts, are outside token totals and omitted.

Missing/null usage becomes `missing_usage`. Missing/null components become
`incomplete_usage`; available components remain in per-result diagnostics,
unknown ones stay null, and no full-token row is invented. This intentionally
includes older/minimal exports that omit cache fields: absent cache telemetry
does not prove zero cache consumption. Obtain complete usage evidence to include
those rows in full-token totals. `completeRowComponents` sums only the rows
included in the explorer; it excludes partial components preserved in diagnostics.

Supplied component values must be exact whole nonnegative JSON numbers, not
numeric strings. Decimal/exponent representations such as `1.20e2` work when
their mathematical value is an integer. Rounded fractions and underflow values
such as `1e-400` are rejected. Components, their row sums and the aggregate must
fit 9,007,199,254,740,991. Known zero remains zero.

No request timestamp exists in the supported batch-result shape, so all rows
are undated (the existing explorer represents this as an empty date string).
Extension timestamps are ignored; download time is not substituted. Costs are
null, including where source extensions claim a cost. No live price, cache-rate,
Batch discount, currency conversion, invoice or settlement inference is made.
A zero known-cost sum with missing-cost counts is not evidence of zero spending.

## Output and review

The JSON uses `moongate.usage-file.v1` with `anthropicBatchImport` metadata
(`moongate.anthropic-batch-import.v1`). It contains result counts, missing and
incomplete usage counts, complete-row component sums, and one outcome per input
record with its ID, line, result type, model, usage state, token components,
known total and normalized stop reason. Recognized stops are end_turn,
max_tokens, stop_sequence, tool_use, pause_turn, refusal and
model_context_window_exceeded. Missing stops stay null; other strings become
`unrecognized` without echoing arbitrary content. Stops are observations,
not a completion or quality verdict.

`sourceTotal` counts supplied results, while `total` counts imported complete
usage rows. Missing/error rows therefore retain partial-coverage warnings after
reopening. `batchCompleteness` remains `unverified` even when every supplied
result has usage. Nothing establishes every submitted request is in this file.
Reopening/re-exporting in the explorer drops Anthropic-specific diagnostics,
while preserving normalized rows and coverage. Keep the original import JSON
for outcome/cache details and the original source if needed for local drilldown.

Message content, message IDs, headers, credentials, error text and arbitrary
metadata are omitted. Custom IDs, model labels, operator labels and source paths
remain visible and may be private; review them before sharing. This is a
normalized analysis artifact, not a lossless batch export or a provider-ready
request file.

Wire references checked for this reader: [result export shape](https://platform.claude.com/docs/en/api/messages/batches/results),
[Batch result types](https://platform.claude.com/docs/en/build-with-claude/batch-processing),
and [cache-token categories](https://platform.claude.com/docs/en/build-with-claude/prompt-caching#tracking-cache-performance).
The reader implements only the bounded subset above. It does not qualify live
Anthropic execution, visual UI behavior, billing or a full MoonGate release.
