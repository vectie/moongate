# Review locally downloaded OpenAI Batch results

Use `moongate usage import-batch` to turn a saved OpenAI Batch output JSONL file
into a normalized Usage File Explorer document. Include the separately saved
error JSONL with `--errors` when available. The command reads local files and
prints JSON; it never downloads files, submits a batch, calls a provider, or
changes persistent usage.

```sh
output_dir="$(mktemp -d)"
moongate usage import-batch --file examples/usage/batch-results.jsonl --errors examples/usage/batch-errors.jsonl --app nightly-eval --provider provider-a > "$output_dir/batch-usage.json"
moongate usage import-batch --file examples/usage/batch-results.jsonl --errors examples/usage/batch-errors.jsonl --app nightly-eval --provider provider-a --report > "$output_dir/import-report.txt"
moongate usage preview --file "$output_dir/batch-usage.json" --model moon-small > "$output_dir/small-model.json"
moongate usage compare --before "$output_dir/batch-usage.json" --after "$output_dir/small-model.json" --report > "$output_dir/model-slice-comparison.txt"
```

The same shared implementation is available as the small native
`cmd/import_batch_usage` companion. Build from this checkout with its pinned
dependencies and an external build directory, then use the executable with
`--file FILE [--errors FILE] [--requests INPUT.jsonl] [--app LABEL] [--provider LABEL] [--report]`.
Options are exact and case-sensitive. Unknown/duplicate options and missing
values fail. File contents are not passed in process arguments. Redirect only
to a **new output path**, never an input file. A failed command exits nonzero;
its redirected stdout may contain an error rather than usable JSON.

## Supported source shape

The reader handles one Batch result object per nonblank JSONL line. LF and CRLF
are supported; blank lines are ignored and an empty file yields an empty
preview. A record requires a nonempty, unique `custom_id`, plus a `response`
object or a top-level `error` object with a null/absent response. `--errors`
concatenates the two files with a newline and validates them together. Duplicate
custom IDs fail the whole import, including duplicates across the files.
Line numbers refer to this combined text; result order is preserved, with the
error file last. No row-position matching or silent deduplication occurs.

Successful (2xx) response bodies must have `object: "chat.completion"` or
`object: "response"` and a nonempty model. Chat Completions map
`usage.prompt_tokens` / `completion_tokens`; Responses map
`usage.input_tokens` / `output_tokens`. Both components must be whole,
nonnegative JSON numbers. Numeric strings and total-only usage are rejected.
Decimal and exponent notation are accepted only when their exact mathematical
value is a safe whole number; fractions that floating-point parsing would round
to an integer or zero are rejected. For example, `1.20e2` is 120, while
`9007199254740990.5` and `1e-400` are not valid token counts.
An absent/null `total_tokens` is derived; a supplied total must equal the sum.
Components, derived totals and aggregate tokens must fit 9,007,199,254,740,991.
Cache/reasoning subtotals are already part of the component totals and are not
added again. Malformed usage rejects the entire import.

Responses bodies also need a recognized `status`: completed, incomplete,
failed, cancelled, queued or in_progress. The status is retained in per-line
outcomes; any non-completed state is counted explicitly. Reported usage is
retained even in an incomplete/failed/nonterminal Responses body and does not
prove successful completion. Chat `finish_reason` and choices are not inspected.
This is a usage import, not a response-quality or completion validator.

Chat `created` and Responses `created_at` are passed through the existing UTC
date normalizer. Missing/unreadable dates stay undated; no submission or download
date is substituted. `custom_id` becomes normalized `requestId`. App/provider
labels default to `openai-batch` / `openai-export`; override them to organize
your review. These are operator labels, not verified provider/routing identity.

## Coverage and unknown values

- A top-level Batch error, non-2xx HTTP result, or missing/null usage produces
  a per-line outcome and counter, not a fabricated zero-token usage row.
- A 2xx record with an unsupported body or malformed fields fails rather than
  disappearing. Supported successful body formats exclude embeddings,
  moderation, images, streaming events and Batch input requests.
- All imported costs are null, even if source extensions include a cost.
  No catalog lookup, Batch discount, currency conversion or invoice matching
  occurs. The preview's known-estimate sum is zero because it has no known
  prices, and its missing-cost count accompanies it. This is not zero spend.
- Without `--requests`, `sourceTotal` counts supplied result records. If any lack importable usage,
  the preview is partial. `batchImport.batchCompleteness` is always unverified:
  even a file containing only successful records does not prove that every
  submitted job is present. Without `--requests`, no Batch manifest or input file is reconciled. See the request-join section below.
- The output uses the existing `moongate.usage-file.v1` envelope plus
  `batchImport` metadata, outcome counters and per-line diagnostics. It reopens
  in the existing explorer and comparison workflow. Re-exporting from the
  explorer preserves source totals/partial coverage but drops Batch-specific
  diagnostics. Retain the original import JSON as the coverage evidence.

Combined input is limited to 4 MiB UTF-8 and 10,000 nonblank result lines. Split
large exports before using this bounded reader; totals apply only to supplied
lines. Each read file is also byte-limited to 4 MiB. The normalized output must
fit the explorer's 4 MiB limit to be reopened (a small source with many tiny
error records can expand because diagnostics are retained).

Only normalized usage and fixed per-line status fields are emitted. Response
payloads, headers, provider request IDs and arbitrary error messages/codes are
omitted. Custom IDs, model labels, supplied labels and source paths remain and
may contain private information; inspect them before sharing. Import failures
identify the line and field class without quoting source content.

The included synthetic fixtures yield 6 supplied results, 3 usage rows,
355 tokens, 3 unknown costs, 1 undated row, 1 missing-usage result, 1 Batch error,
1 HTTP error and 1 incomplete Responses state. They are not live-provider data.

Wire references: [OpenAI Batch guide](https://developers.openai.com/api/docs/guides/batch)
and [Responses API reference](https://developers.openai.com/api/reference/resources/responses/methods/create).
The local reader implements only the subset described above.


## Join a saved request manifest

Add `--requests INPUT.jsonl` to the existing command (or small companion) to
match saved Batch input requests with output/error records by exact `custom_id`:

```sh
moongate usage import-batch --file results.jsonl --errors errors.jsonl --requests input.jsonl > NEW-joined-usage.json
```

The request file contains one JSON object per nonblank line with a nonempty
unique `custom_id`, `method: "POST"`, `url: "/v1/chat/completions"` or
`"/v1/responses"`, and an object `body` with a nonempty string `model`. Other
request content is not validated for provider acceptance. Blank lines and CRLF
are allowed. IDs are case/whitespace sensitive; no position matching or trimming
occurs. Duplicate IDs in either side, invalid JSON and unsupported request
shapes reject the whole import. An empty results file with a nonempty request
file is supported and lists every request as missing.

`batchImport.requestJoin` (schema `moongate.batch-request-join.v1`) contains:

- `requestCount`, `matchedResultCount`, `missingResultCount`, and
  `unexpectedResultCount`.
- `requestIdCoverage`: `all-observed` when every supplied request ID has a
  result, otherwise `missing-results`. A Batch error or missing-usage result
  still counts as observed. This is not a success rate.
- `outcomes` in request-file order, followed by unexpected results in their
  original result-file order. Each includes request/result line numbers,
  exact ID, match classification, original result outcome, HTTP/Responses
  state, requested endpoint/model and returned response object/model.
  Missing result context is null. Error-body model/object fields are omitted.

Requested and returned metadata are shown separately even when they differ.
The join makes no endpoint/model equivalence inference, silently substitutes
no model, and does not establish that a result truly belongs to a submitted
provider job. `batchCompleteness` remains `unverified`: this is a reconciliation
of the supplied local files, not proof of submission, provider completion,
response quality, or billing. Missing results are not safe-retry instructions.
No request is sent or retried.

With a manifest, `sourceTotal` counts the union of request and result IDs, so
missing-result coverage remains partial when the JSON is reopened in Usage
File Explorer. All supplied result usage, including unexpected-result usage,
remains in the existing data/totals. `sourceResultCount` still counts only
result records. The explorer's `partial` flag concerns imported usage coverage;
it does not flag unexpected IDs when all supplied IDs have usage. Inspect the
join counts separately. Re-exporting from the explorer drops join diagnostics;
retain the original joined JSON.

The existing 4 MiB combined UTF-8 limit now includes requests plus results and
errors. Each side accepts at most 10,000 nonblank records. Up to 20,000 joined
IDs can therefore appear. Each file must also be no larger than 4 MiB. Expanded
output is not guaranteed to fit the explorer's independent 4 MiB reopen limit.
The tool emits normalized usage and selected context only: it omits prompts,
messages, arbitrary metadata, headers and error text. IDs, model labels and
paths remain private-data review responsibilities, including Unicode/newlines
in those labels. Redirect only to a new file; this read-only tool never writes
back to the request or result files.


The synthetic `examples/usage/batch-requests.jsonl` intentionally includes a
missing ID and request metadata that differ from the existing result fixtures.
It exercises correlation and is not a provider-ready submission template.
Joining it to the two existing result/error fixtures gives 6 requests, 5
matched IDs, 1 missing result, 1 unexpected result and the same 355 recorded
tokens. Missing/failed usage and all costs remain unknown where applicable.

## Anthropic Message Batches

For Anthropic result JSONL, select `--format anthropic`. The default remains `openai`. See [Anthropic Batch usage review](anthropic-batch-usage.md) for cache-token semantics, result outcomes, explicit unknowns and the reopen workflow. `--requests` remains OpenAI-only.
