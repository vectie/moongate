# Review saved Chat Completions responses

`moongate usage import-chat` reads previously saved OpenAI-compatible Chat
Completions response bodies. Supply one JSON response or SSE stream per file.
The command emits an ordinary Usage File Explorer JSON artifact with an
additional capture review. It never sends requests, looks up prices, opens
credentials, or modifies persistent usage.

The small native companion `import_chat_capture` runs the same implementation:

```sh
mkdir my-chat-review
import_chat_capture --file examples/usage/chat-completion.json --file examples/usage/chat-stream.sse --app saved-client --provider saved-route > my-chat-review/usage.json
import_chat_capture --file examples/usage/chat-interrupted.sse --file examples/usage/chat-error.json --report > my-chat-review/captures.txt
export_usage_csv --file my-chat-review/usage.json --view model > my-chat-review/models.csv
export_usage_csv --file my-chat-review/usage.json --start-day 2026-10-09 --end-day 2026-10-09 > my-chat-review/day.csv
```

Use a new output filename, never any input path: shell redirection truncates its
output before the command runs. Check the exit code. The companion writes errors
to stderr and produces no partial artifact on stdout when any input is invalid.
All included examples are synthetic. The example JSON and complete stream total
37 recorded tokens across two captures; all their costs are unknown. Interrupted
and errored captures add no inferred final usage.

Open `usage.json` with the existing Usage File Explorer to filter by app,
provider, model or inclusive UTC day and inspect groups. Existing `usage price`
can apply a separately supplied hypothetical rate card to complete imported
rows; import itself never estimates charges. The root CLI dispatcher is wired
and type-checked; this round's runtime evidence uses the small native companions.

## Supported saved formats

- A single JSON object with `object: "chat.completion"`, nonempty string `id`
  and `model`, and a `choices` array. Each choice needs an integer `index` in
  0..9999, a `message` object and a string or null `finish_reason`.
- An SSE body with JSON objects of type `chat.completion.chunk`, the same
  nonempty `id` and `model` throughout, and a `choices` array. Each choice has
  an `index`, `delta` object and string or null `finish_reason`.
- A standalone JSON error object or SSE `data: {"error": {...}}` is recorded
  as errored. Error text is omitted. An optional later `[DONE]` is accepted.

JSON can be pretty-printed. SSE supports LF/CRLF, comments, ignored `event`,
`id` and `retry` metadata, and multiline `data:` fields joined with a newline.
Only `data:` payloads are interpreted. A blank line terminates an SSE event.
A final event without its blank-line terminator may be read, but an unframed
`[DONE]` at EOF does not establish completion. Malformed/truncated JSON rejects
all supplied inputs; the reader never guesses the missing bytes.

Arrays, response NDJSON, HTTP headers, terminal logs, OpenAI Responses events,
legacy text Completions, and nonmatching vendor-specific variants are outside
this contract. This is a saved-body reader, not an HTTP/SSE client. A compatible
saved shape does not establish the endpoint or provider's actual identity.

The streaming usage shape follows the [OpenAI Chat Completions
reference](https://developers.openai.com/api/reference/resources/chat/subresources/completions/streaming-events):
with usage enabled, the final usage object is on an empty-choices chunk before
`[DONE]`; interrupted streams may lack that object. This reader conservatively
requires both the final marker and choice finishes before importing its totals.

## Completion and unknown usage

Every file has a capture outcome:

- `completed`: a JSON response whose observed choices all have finish reasons,
  or an SSE stream with those finishes and a framed `[DONE]` marker
- `incomplete`: no sufficient terminal evidence, including a stream interrupted
  after its usage object or an unfinished observed choice
- `errored`: an explicit captured error
- `empty`: no response data, including an empty/comment-only capture

These states describe captured protocol termination. A `length`, `content_filter`,
`tool_calls` or `function_call` finish is preserved and may require application
follow-up. `stop` is also preserved; other finish strings become `unrecognized`.
A completed capture does not prove the answer is useful or every expected choice
was captured: the reader has no original request's `n` setting.

The outcome's `usageState` is `complete`, `missing`, or `incomplete` for completed
captures, and `unavailable` otherwise. Only completed captures with all three
reported `prompt_tokens`, `completion_tokens` and `total_tokens` enter the `data`
rows. Their sum must be consistent. Missing values never become zero. Explicit
zero is retained. Valid observed metrics from interrupted captures remain in
`observedUsage` solely for diagnosis and contribute no inferred final tokens.

Counts must be exact nonnegative integers no greater than 9007199254740991;
quoted numbers and rounded fractional values reject. Per-request sums and the
combined imported sum must also be safe. Cache, reasoning and other detail
subsets are omitted, never added to these totals. Every imported cost is null,
including when a capture's arbitrary fields contain a price.

`created` is an optional nonnegative integer Unix timestamp in seconds. Present
values must agree across a stream. It is the sole date source; absent or
unrepresentable dates remain undated. Filename and download times are not used.

## Identity, coverage and data handling

Captured response IDs become `requestId` in imported rows. They must stay
constant within a stream. A repeated nonempty ID across supplied files rejects
the operation: select one capture of that request, or review separate provider
sources separately. No silent first/last-wins merge or identity invention occurs.
All files in one invocation share the operator's `--app` and `--provider` labels;
defaults are `chat-capture` and `openai-compatible-export`.

`sourceTotal` counts the supplied captures; `total`/`importedRows` count only
complete usage rows. The output always sets `sourceCoverageUnknown: true`, so
an empty row list or a zero known token subtotal is not evidence of no activity.
The `chatCaptureImport` section records state counts and every capture outcome,
source name, local index, response ID, model, observed usage, choice finishes
and terminal line. `captureIndex` connects an imported row to that local list.
No claim of whole-provider or whole-interval coverage is made.

The parser keeps a strict output allowlist. Messages, deltas, prompts, tool-call
arguments, errors, headers, and other arbitrary fields are omitted. Source paths,
IDs and model/operator labels remain and can contain private data. Review them
before sharing. The original capture file is never rewritten or redacted.

Reopening/exporting through the existing explorer preserves ordinary rows and
coverage flags but drops capture-specific diagnostics and indexes. Keep the
original imported artifact for the excluded outcomes and source correlation.
The combined input limit is 4 MiB UTF-8, up to 100 files, and 10,000 response
objects. Each SSE capture is also capped at 10,000 events. Output is capped at
4 MiB so it can be reopened; split the set into smaller reviews if needed.

No live provider, gateway dispatch, browser or spreadsheet UI was exercised.
This is focused offline evidence only; it does not qualify a live route or
change the product's cumulative qualification.
