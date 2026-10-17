# Explore saved OpenTelemetry GenAI traces

Convert a local OTLP JSON or JSONL trace export into MoonGate usage evidence:

```
moongate usage import-otel --file examples/usage/otel-traces.json > new-usage.json
moongate usage import-otel --file examples/usage/otel-traces.json --report
moongate usage preview --file new-usage.json --app research-app --report
moongate usage latency --file new-usage.json
moongate usage export-csv --file new-usage.json --view model > new-models.csv
```

Use new output paths: shell redirection can overwrite inputs before a command
runs. Check the exit status before using an output. The small native companion
`cmd/import_otel_usage` accepts the identical `--file FILE [--report]` options and
uses the same implementation. It prints errors to stderr, exits nonzero, and
emits no partial JSON. No gateway, account, credentials, collector connection,
provider request, or persistent configuration/accounting change is needed.

Open the successful JSON in **Usage → Usage File Explorer** to filter by exact
service/app, provider label, model, or inclusive UTC dates. Download filtered JSON
or a text report there. The offline latency and CSV commands accept the original
import artifact. Keep it: ordinary preview/filter exports omit span metadata and
latency. A model CSV plus the summary CSV makes a useful spreadsheet review.

## Supported input profile

Accepts one JSON object with `resourceSpans[].scopeSpans[].spans[]`, or a JSONL file
whose nonblank lines each contain that object. This is a bounded importer, not
a general OpenTelemetry collector. JSON names use OTLP camelCase. Binary protobuf,
compressed files, logs, metrics, console/debug exporter text, vendor trace views,
legacy `instrumentationLibrarySpans`, and remote downloads are unsupported.

Only `kind: 3` (CLIENT) spans with `gen_ai.operation.name` equal to `chat`,
`text_completion`, or `generate_content` are usage candidates. Other operations
and span kinds are counted as skipped; parent agent, tool, embedding and server
spans are not added to client-generation totals. This selection cannot detect
two distinct client spans instrumenting the same provider call.

Recognized span attributes are OTLP key/value entries:

- `gen_ai.usage.input_tokens` and `gen_ai.usage.output_tokens`: `intValue`
- `gen_ai.request.model`, `gen_ai.response.model`, `gen_ai.provider.name`, and
  `gen_ai.operation.name`: `stringValue`
- Resource `service.name`: `stringValue`, mapped to the explorer's app label

Both token totals must exist, including explicit zero. Integer values accept
nonnegative decimal strings or exact whole JSON numbers, bounded to
9,007,199,254,740,991. Combined and aggregate totals must fit that range. Cache,
reasoning, media, and other component subcounts are not added to the reported
directional totals. Missing usage produces an outcome with its observed
components and unknown total, rather than a zero-usage row. A model is required
for an explorer row: response model wins, with requested model as an explicitly
labeled fallback. Missing labels become `Unknown` in the explorer. Provider
names are exporter labels, not configured MoonGate provider identities.

Candidate identities require nonzero hex `traceId` (32 digits) and `spanId`
(16 digits). Hex case is normalized; `otel:TRACE:SPAN` becomes the request ID.
Repeated candidate identities reject the whole input, including across JSONL
documents. Obtain a non-overlapping export instead of assuming a retry is a new
charge. Distinct spans remain separate observations. Duplicate attribute keys,
invalid selected-span fields, invalid required resourceSpans/scopeSpans/spans
framing and unsafe totals reject. Unconsumed metadata is omitted rather than
fully schema-validated; duplicate JSON object member names follow the underlying
parser's last-key-wins behavior.

## Time, status and coverage

Optional start/end timestamps accept decimal uint64 nanosecond strings. Missing,
null or zero means unavailable. A known start determines its UTC date; both
endpoints are required for duration. The importer subtracts integer nanoseconds
before converting to fractional milliseconds. Equal endpoints give measured
zero; reversed endpoints reject. This is instrumented span duration, not a live
benchmark or necessarily time to first token. Numeric timestamp values are
outside this profile to avoid silent rounding of epoch nanoseconds.

Status code 0/unset, 1/ok and 2/error are retained in span outcomes. An error span
can still have recorded usage and contributes when complete. Status is not proof
of a usable answer or billing settlement. All costs are unknown. No pricing is
looked up and no invoice, quota, spend envelope, or cash balance is inferred.

The output uses the normal `moongate.usage-file.v1` envelope, with extra
`otelImport` metadata (`moongate.otel-usage-import.v1`) for source/candidate/skipped
counts, missing-usage/model counts and ordered outcomes. `sourceTotal` counts
candidate spans, not all source spans. Coverage is always unknown and partial,
because exported traces may be sampled, dropped, filtered or incomplete. This
warning survives reopening, filtering and CSV export. An empty export has zero
observed rows, not evidence of zero real usage.

Payloads, prompts, responses, events, status messages, span names, scope names,
resource details and arbitrary attributes are omitted. IDs, service/provider/model
labels, source path and requested/returned model context remain visible. Review
those labels before sharing. There is no claim that arbitrary user-chosen labels
are secret-free.

Limits: 4 MiB UTF-8 input and pretty-printed output, 10,000 spans across all
resources/scopes/documents, and 10,000 JSONL documents. Larger inputs need a smaller
local export. The bundled synthetic fixture has 5 spans, 4 candidates, 3 imported
rows, 165 tokens, 1 incomplete-usage outcome, 2 error spans, and 2 duration samples.

The format follows the [OTLP JSON encoding](https://opentelemetry.io/docs/specs/otlp/),
[file exporter](https://opentelemetry.io/docs/specs/otel/protocol/file-exporter/),
and [GenAI span attributes](https://github.com/open-telemetry/semantic-conventions-genai/blob/main/docs/gen-ai/gen-ai-spans.md).
The importer deliberately supports the profile above as tested; it does not
claim exhaustive or future semantic-convention compatibility. No browser or live
instrumentation was qualified by the focused local tests.
