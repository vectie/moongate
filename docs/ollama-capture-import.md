# Review saved Ollama response captures

Use this offline reader for already-saved `/api/generate` or `/api/chat`
responses. It accepts a JSON response, including pretty-printed JSON, or streamed
NDJSON. Supply exactly **one request/stream per file**:

```sh
out="$(mktemp -d)"
import_ollama_capture --file examples/usage/ollama-generate.ndjson --file examples/usage/ollama-chat.json > "$out/usage.json"
import_ollama_capture --file examples/usage/ollama-interrupted.ndjson --file examples/usage/ollama-error.ndjson --report > "$out/review.txt"
```

`cmd/import_ollama_capture` is the small native offline companion. The integrated
`moongate usage import-ollama` dispatcher uses the same command implementation.
The companion is runtime-tested; the main dispatcher is type-checked. No Ollama
service, gateway, model, account, credential or network request is needed. This
workflow does not dispatch inference or qualify a live provider route.

Open the output JSON in **Usage → Usage File Explorer** to filter and group
complete usage observations. `--app LABEL` and `--provider LABEL` set local review
labels, defaulting to `ollama-capture` and `ollama-export`; they are not verified
route identities. `--report` prints the readable outcome/timing review instead
of JSON. Repeat `--file` up to 100 times. Unknown, duplicate scalar, missing-value
and duplicate exact path options fail before files are read.

Always redirect stdout to a **new output path**, never a source file. Shell
redirection truncates its target before the reader runs. Failures exit nonzero
and print an error rather than a partial usage artifact; check the exit status.
Source files and persistent usage accounting are left unchanged.

## A stream is one observation

Each file contributes one capture outcome. Nonterminal `done:false` objects are
chunks of that capture, not separate requests. A final `done:true` object marks
`completed`; this means only that the response declared its end, not that a task
or answer was correct. `done_reason` retains `stop`, `length`, `load` or `unload`;
missing values remain null and other strings become `unrecognized`.

- `completed`: a terminal response is present. Usage can be complete, missing or
  incomplete independently of this response state.
- `incomplete`: response objects were saved but no terminal response or error was
  found. Interruption is possible; no cause is inferred.
- `errored`: an error object ended the capture, possibly after output chunks.
  The error text is deliberately omitted.
- `empty`: no response objects were found. A request or its execution is not
  established by an empty file.

Anything after a terminal response/error rejects the whole import, including a
second request or repeated terminal object. A model or generate/chat shape
change within a stream also rejects it. Each normal object needs a nonempty
model, boolean `done`, and either string `response` or object `message`. This is
a metrics reader, not full response-body validation. An error object needs a
string `error` and cannot mix in `done`, `response` or `message`.

Files have no verified provider request ID. Normalized request IDs are blank;
`captureIndex` is only the one-based position in this output. Separate files
with identical content remain separate observed captures. Different spellings
of the same path are not canonicalized. Do not supply the same request twice,
concatenate requests in a file, or interpret this output as a deduplicated bill.

## Token and timing evidence

Only a terminal response containing both `prompt_eval_count` and `eval_count`
enters the explorer's `data` rows and totals. They map to input and output tokens;
total is their sum. Explicit zero is retained. Missing/null counts remain unknown,
with whichever terminal component exists preserved in the outcome. Counts from
nonterminal chunks are not final usage and are omitted rather than summed or
promoted. Optional `prompt_eval_cached_count` is a subset of prompt count, not
additional input. When both exist, a cache count larger than prompt count fails.

Per-capture terminal metrics retain `total_duration`, `load_duration`,
`prompt_eval_duration` and `eval_duration` in **nanoseconds**. Missing values stay
null. They are provider-reported measurements, not proxy overhead, client elapsed
time, a live benchmark or a guarantee that components sum to total duration.
No throughput or network-latency number is invented.

Known count/duration values must be exact nonnegative JSON integers up to
9,007,199,254,740,991. Numeric strings, negative/fractional/overflow values fail.
Integral decimal/exponent forms such as `1.20e2` work; rounded fractions and
underflow such as `1e-400` fail. Each usage sum and the combined total also fits
that bound. Missing optional observations are not defaulted to zero.

Complete rows use terminal `created_at` for the existing explorer's UTC-day
normalization. Missing/unreadable dates remain undated and are excluded by date
filters. Chunk times and file/download times are not substituted. Source costs
are ignored and all costs remain unknown, including local inference: this reader
does not calculate hardware, electricity, hosting, token rates or settlement.

## Output and limits

The output is `moongate.usage-file.v1` with `ollamaCaptureImport` metadata using
`moongate.ollama-capture-import.v1`. It records capture count, response-object
count, state counts and per-capture source name/index, model/API shape, terminal
object start line, usage state, stop reason, terminal metrics and token total.
For pretty JSON the start line refers to the object, not the field's line.

`sourceTotal` counts supplied files, while `total` counts complete usage rows.
`sourceCoverageUnknown` is always true: neither a set of saved captures nor
complete usage within it establishes whole-interval or whole-provider coverage.
Even when all supplied files complete, the output remains partial in that sense.
Reopening and filtering preserve this coverage warning. Re-exporting from the
explorer drops capture-specific metadata/indexes and timing observations; keep
this original output for source correlation and the original capture for any
needed private drilldown. This artifact is not a lossless response archive.

Limits are 100 files, 4 MiB combined UTF-8 input, 10,000 combined response objects
and a 4 MiB pretty-printed output. A small input can expand past the output limit;
use fewer captures if that occurs. LF, CRLF, blank lines and empty captures work.
Malformed JSON, invalid supported fields and mixed requests reject the entire
operation. Arrays of captures, SSE, terminal shell logs, embedding responses and
OpenAI-compatible responses are outside this reader.

Response text, messages, thinking, context arrays, tools, error text, headers and
other payload fields are omitted. Source paths, operator labels and model labels
remain and can be private; inspect before sharing. Supplying a capture file does
not authorize contacting its provider.

Wire references checked for this bounded reader:
[generate response](https://docs.ollama.com/api/generate),
[chat response](https://docs.ollama.com/api/chat), and
[NDJSON streaming](https://docs.ollama.com/api/streaming).
