# Inspect a captured request incident offline

Use `moongate requests har --file capture.har` to open an existing HAR 1.2
network capture as a request diagnostic report. It accepts requests with no
model or token telemetry, including redirects, HTTP errors, and entries with no
recorded HTTP response. The small `cmd/inspect_har` executable runs the exact
same command implementation without starting the gateway.

## A complete review

The bundled capture is synthetic, with reserved `.invalid` hosts and planted
private-content markers. It contains seven requests: two HTTP 200 responses,
one 302 redirect, one 429, one 503, one status 0, and one unknown status.

```sh
out="$(mktemp -d)"
moongate requests har --file examples/har/diagnostic-session.har > "$out/overview.json"
moongate requests har --file examples/har/diagnostic-session.har --status errors --report > "$out/errors.txt"
moongate requests har --file examples/har/diagnostic-session.har --method POST --status 429 --origin https://api.fixture.invalid > "$out/rate-limited.json"
moongate requests har --file examples/har/diagnostic-session.har --entry 6 --report > "$out/entry-six.txt"
```

The error report points to original entries 3 and 6. Entry 6 has status 503,
250 ms captured elapsed time, 180 ms wait, 60 ms connect, and 55 ms SSL (inside
connect). Its captured start is 1,500 ms after the earliest readable start in the
whole file. Original entry 5 starts earlier than entry 4; the viewer preserves
capture order rather than silently renumbering or sorting it. Use those entry
numbers to find the corresponding request in the original local capture.

Run the same examples with `inspect_har` in place of `moongate requests har` when
using the standalone executable. Both read a path; contents are not passed as
process arguments. Redirect only to a new output path, never to the input:
shell redirection truncates its target before execution. A failure exits
nonzero and may leave error text in the redirected file, never a partial JSON
report. Input files, gateway configuration, and recorded usage remain unchanged.

## Filters and entry detail

All filters combine with AND. An empty match is a successful report with zero
selected entries and unavailable percentiles.

- `--method`: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS, TRACE, or CONNECT;
  case-insensitive
- `--status`: an exact integer 100–599, `1xx` through `5xx`, `errors` (400–599),
  `0` (no recorded HTTP response), or `unknown` (missing/null status)
- `--origin`: exact captured scheme/host/port, with no path, query or fragment.
  Hostnames are lowercased and default ports 80/443 omitted. Non-default ports
  stay separate. This is captured origin grouping, not a network validation or
  reachability check; DNS aliases and alternate IPv6 spellings are not merged
- `--entry`: positive one-based original entry number; an out-of-range number is
  an error. Other filters can still exclude that entry
- `--report`: readable text instead of the default JSON

`errors` excludes status 0 and unknown. Review those groups separately because
neither proves a timeout, cancellation or HTTP error. HTTP 2xx indicates the
recorded protocol status only; it does not establish a correct model answer,
complete stream or successful business task.

## Evidence kept in the report

JSON uses `moongate.har-diagnostics.v1`. `entries` contains original entry number,
method, captured origin, status/outcome, normalized Unix start milliseconds,
start offset, recorded elapsed milliseconds, individual timing phases, and the
longest recorded non-SSL phase. `captureEntries` records the full input size;
`selectedEntries`, `summary`, `byOrigin`, and `byOutcome` describe filtered rows.
Groups are sorted lexically; entries remain in original order, including repeated
URLs. The capture’s completeness is unverified and no missing traffic is inferred.

Timings include blocked, DNS, connect, send, wait, receive, and SSL. Missing,
null, and HAR's -1 sentinel remain unknown. Zero is a recorded zero. Other
negative, nonnumeric, nonfinite or out-of-safe-range values reject the capture.
SSL is already a subset of connect in HAR. It is displayed but excluded from
longest-phase selection, and phases are not summed or forced to match elapsed
time. Phase ties follow blocked, DNS, connect, send, wait, receive order.
These are exporter observations, not a diagnosis of root cause, gateway-only
overhead, or live performance.

Overview and group elapsed percentiles use nearest rank on known `time` samples:
position ceil(p × sample count), one-based. Missing times are excluded; their
counts are explicit. Empty sample sets produce null, never invented zero latency.

Optional `startedDateTime` accepts ISO calendar timestamps with `T`, explicit
`Z` or ±HH:MM, and up to nine fractional digits. Missing, invalid, local-time-only
or unsupported starts become unknown, with `missingStartCount` showing the gap.
Only normalized milliseconds are retained, using double precision; this is not
nanosecond timing. Start offsets always use the earliest known start across the
entire capture so the same entry retains its position after filtering.

## Input, privacy and limits

Only HAR 1.2 with an entries array is accepted, up to 4 MiB UTF-8 and 2,000 entries.
Each entry requires a supported request method, absolute lowercase-scheme
HTTP(S) URL and response object. Response status may be absent/null; otherwise it
must be 0 or an integer from 100 to 599. ASCII host labels and bracketed IPv6
labels are supported; embedded credentials, encoded/non-ASCII hostnames,
backslashes, whitespace, unsupported schemes and invalid ports are rejected.
Use an ASCII/punycode hostname if needed. Other HAR fields are ignored. All
entries are validated before filtering, so a malformed excluded entry cannot
quietly disappear. Both JSON output and its embedded text report are limited to
4 MiB; filtering can reduce output size.

Paths, query strings, fragments, headers, request/response bodies, cookies, page
titles, status text, and raw errors are omitted. This does not make the report
anonymous: origins and timestamps can still be private. Review it before sharing.
The command does not redact or rewrite the original capture. Keep it locally if
request-level drilldown is needed later; diagnostic JSON is a report artifact,
not a lossless HAR export or a supported reopen input.

No browser, account, provider, authentication, request replay or accounting is
used. Captures are supplied files, not proof of live provider availability.
This workflow provides offline request exploration; it does not qualify a live
client/provider pair, operator UI, or a full MoonGate release.
