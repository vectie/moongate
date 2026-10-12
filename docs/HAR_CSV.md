# Export captured HAR timings to a spreadsheet

Run `moongate requests har --file capture.har --csv > timings.csv`, or use the
lightweight `inspect_har --file capture.har --csv` executable. Export is offline:
no provider request, usage mutation or replay occurs. Use a new output path;
shell redirection to the input would truncate the capture before it is opened.

Combine `--csv` with `--method POST`, `--origin https://api.example.invalid`,
`--status errors`, or `--entry 3` to export the same selection as JSON inspection.
`--csv` and `--report` are mutually exclusive. With no output option JSON remains
the default. Failures produce a nonzero exit code and no CSV on standard output.

CSV is UTF-8 with a fixed header, comma delimiters, quoted text, and CRLF rows.
Import with your spreadsheet's CSV importer. Every numeric column is a captured
number; an empty cell means unknown, not zero. A header-only file means an empty
selection. Original one-based entry numbers survive filtering. `startOffsetMs`
is relative to the earliest readable timestamp in the whole supplied capture.
`startedAtUnixMs` is normalized UTC epoch milliseconds; missing or unreadable
start times stay empty. Phase columns are blocked, dns, connect, send, wait,
receive and ssl in milliseconds. SSL is included in connect: do not sum it again.
`longestRecordedPhase` excludes SSL and describes known phases only.

Only normalized HTTP(S) origins, methods, numeric timing/status and fixed outcome
labels are exported. Paths, queries, fragments, raw timestamps, headers, cookies,
bodies and raw errors are omitted. Origins can identify private hosts; review
before sharing. Text comes only from constrained normalized fields, never raw
spreadsheet formulas. Inputs are not altered or redacted on disk.

A capture is at most 4 MiB UTF-8 / 2,000 entries. Every entry is validated before
filtering, including excluded rows. Missing/null/-1 timing is unknown; explicit
zero stays zero. Status 0 is no recorded HTTP response; empty status is unknown.
These are observed capture timings, not gateway-only overhead or live benchmark
claims. Capture completeness is unverified and HTTP 2xx does not establish model
output correctness or stream completion. CSV omits JSON's aggregate caveats and
summary; retain this guide with exported files when sharing them.
