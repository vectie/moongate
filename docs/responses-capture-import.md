# Review saved Responses captures

`moongate usage import-responses` reads one saved Responses JSON object or HTTP
SSE body per file. It emits regular `moongate.usage-file.v1` JSON with an added
`responseCaptureImport` outcome report. This is an offline saved-body reader:
no provider calls, credentials, price lookup or persistent usage changes occur.
The lightweight native `import_response_capture` companion uses the same code.

## Run a useful local review

Build `cmd/import_response_capture`, `cmd/import_usage_csv` and
`cmd/export_usage_csv` with `moon build --target native`. Then run the built
companions, or use the main command where MoonGate is already installed:

```sh
moongate usage import-responses --file examples/usage/response-completed.json --file examples/usage/response-completed.sse --file examples/usage/response-incomplete.sse --file examples/usage/response-interrupted.sse --file examples/usage/response-failed.json > responses-usage.json
import_response_capture --file examples/usage/response-incomplete.sse --file examples/usage/response-interrupted.sse --report > responses-review.txt
export_usage_csv --file responses-usage.json --view model > responses-models.csv
export_usage_csv --file responses-usage.json --start-day 2026-10-10 --end-day 2026-10-10 > responses-day.csv
```

Choose new output filenames. Never redirect over an input: the shell truncates
the destination before the importer starts. A rejected input exits nonzero,
reports an error on stderr, and emits no partial artifact on stdout. Original
capture bytes are not modified. The output does not replace the original capture
as a backup.

The five synthetic fixtures yield three usage rows and 44 recorded tokens:
25 from JSON completion, 12 from SSE completion, and 7 from a terminal incomplete
response. The interrupted stream and failed response without usage contribute no
invented consumption. Their outcomes still appear in the report. All costs are
unknown. Filter the saved artifact in Usage File Explorer by app, provider,
model or inclusive UTC day; export the groups or rows to CSV. The stream fixture
is on 2026-10-10; the other two imported rows are on 2026-10-09.

For a repeatable native journey using only these synthetic files:

```sh
moon run scripts/verify_responses_capture.mbtx --target native -- /absolute/native/debug/build/cmd /absolute/source/examples/usage /absolute/new-review-directory
```

The journey saves `usage.json`, `review.txt`, model/request CSVs, process stdout
and stderr, `commands.json`, and `RESULT.json`. It checks repeated imports,
labels, model/date filters, empty matches, omitted payloads, malformed inputs,
duplicate IDs, late events, status mismatch and unframed termination. It compares
every original fixture's bytes after the workflow. The main dispatcher is wired
and type-checked; this journey executes the lightweight companions.

## Supported contract

The shape follows the official [Responses streaming event
reference](https://developers.openai.com/api/reference/resources/responses/streaming-events)
and [Responses create reference](https://developers.openai.com/api/reference/resources/responses/methods/create).
The parser implements the bounded subset below, not general endpoint validation.

- JSON: one object with `object: "response"`, nonempty string `id` and `model`,
  and nonempty string `status`. Recognized statuses are `completed`, `incomplete`,
  `failed`, `cancelled`, `queued` and `in_progress`. Unknown status strings become
  `unrecognized` diagnostics, without copying their text or importing usage.
- SSE lifecycle events: `response.created`, `response.queued`,
  `response.in_progress`, `response.completed`, `response.incomplete`, and
  `response.failed`, each containing a nested response object. `response.created`
  permits `queued` or `in_progress`; other types must match the nested status.
- SSE content events: `response.output_item.added/done`,
  `response.content_part.added/done`, `response.output_text.delta/done`,
  `response.output_text.annotation.added`, `response.refusal.delta/done`,
  `response.function_call_arguments.delta/done`,
  `response.reasoning_summary_part.added/done`,
  `response.reasoning_summary_text.delta/done`, and
  `response.reasoning_text.delta/done`. Their payloads are discarded. An earlier
  lifecycle object must establish identity; these events cannot carry a competing
  top-level response, usage or object field.
- `type: "error"` SSE events produce `errored`, with unknown terminal consumption.
  Error messages are omitted. An error event is not a `response.failed` lifecycle
  outcome. Later data is rejected in this reader's supported subset.

LF, CRLF, comment lines, `id:` and `retry:` metadata, and multiline `data:` fields
are supported. An `event:` name, when present, must match the JSON `type`. Optional
`sequence_number` values must be exact nonnegative safe integers and increase;
gaps are permitted because saved excerpts need not include every event. Optional
`response_id` on content events must match the established response. Events
without their own response identity cannot independently prove their provenance.

A blank line frames an SSE event. Valid JSON at EOF without a final blank line
is readable as diagnostic evidence, but an unframed terminal event leaves the
capture `interrupted`. Malformed or truncated JSON rejects the entire invocation.
`[DONE]` is rejected: it is not the completion signal for this Responses reader.
No data events may follow a terminal lifecycle event, including duplicate endings.
Trailing comments/metadata without a payload are harmless.

Arrays, JSONL, batch envelopes, Chat Completions, raw HTTP headers, terminal logs,
WebSockets/multi-response connections, and unsupported Responses event types are
rejected. Tool execution progress, audio/image streams and future event types
outside the above allowlist require a different or extended reader. There is no
silent fallback to the Batch importer. JSON duplicate decoded object keys are
rejected, including escaped duplicate names, so identity or usage cannot be
silently replaced. Matching shape does not verify endpoint identity.

## Outcome is separate from consumption

Every input file has an outcome:

- `completed`, `incomplete`, `failed`, `cancelled`: explicit terminal JSON status,
  or a framed supported SSE terminal event with matching status. `cancelled` is
  supported only in standalone JSON.
- `interrupted`: a recognized nonterminal JSON status, a stream lacking terminal
  evidence, or an unframed terminal event
- `unknown`: standalone JSON with an unrecognized status
- `errored`: an explicit SSE error without a terminal response outcome
- `empty`: no data, including empty or comment-only files

`terminal` is independent of whether an answer is useful. A terminal incomplete
response can still report real consumption. `incompleteReason` retains only
`max_output_tokens`, `content_filter`, or `steered`; other strings become
`unrecognized`. This does not claim WebSocket successor-response support.

Usage is read only from response-level `usage.input_tokens`, `output_tokens` and
`total_tokens`. A terminal response with all three explicit values produces a
row; their exact sum must agree. The outcome's `usageState` is `complete`,
`missing`, or `incomplete` for terminal captures, and `unavailable` otherwise.
Nonterminal snapshots may have `observedUsage` for diagnosis, but are never used
as final totals. Each new lifecycle snapshot replaces earlier usage, including
when final usage is null or absent.

Exact nonnegative integers up to 9007199254740991 are accepted, including exact
integral decimal/exponent spellings. Quoted numbers, fractions, unsafe numbers,
inconsistent sums and unsafe combined totals reject. Explicit zero remains zero;
missing never becomes zero. Cache/reasoning/detail counts are subsets and are
omitted, never added to totals. Costs stay null even if arbitrary capture fields
contain prices. The only date source is optional captured integer `created_at`
in Unix seconds. Missing or unrepresentable dates stay undated. Present timestamps
must agree across lifecycle objects; no filename or download date is used.

## Identity, coverage and privacy

Response IDs and models must remain stable within each capture. Duplicate IDs
across files reject rather than first/last-wins merging. Pick one representation
of a response, or review unrelated provider namespaces separately. Operator
`--app` and `--provider` labels apply to every file; defaults are
`responses-capture` and `openai-compatible-export`.

`sourceTotal` counts all supplied captures; `total` counts imported rows.
`sourceCoverageUnknown: true` always remains set. An empty row list is not proof
of no activity. `responseCaptureImport` stores all outcomes, source names,
one-based capture indexes, captured IDs/models, safe statuses/reasons, event
counts, terminal line and observed usage. Rows link back through `captureIndex`.
Keep the original import artifact: ordinary explorer reopening/re-export drops
capture-specific diagnostics, while retaining ordinary rows and coverage flags.

Prompts, instructions, outputs, deltas, tool arguments, error messages, headers
and arbitrary fields are not copied. Source paths, captured IDs and model/operator
labels remain and can contain private data; review them before sharing. This
does not redact the input files. Inputs are bounded to 100 files, combined 4 MiB
UTF-8, and combined 10,000 JSON objects/SSE data events. Each stream also has the
10,000-event cap. Output is limited to the explorer's 4 MiB reopen limit.

This is offline fixture evidence only. Browser, live-provider, installed-product,
full protocol compatibility and production/release qualification are not claimed.
