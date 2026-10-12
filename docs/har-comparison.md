# Compare two saved HAR captures

Compare before/after request distributions without sending requests or starting
the gateway. This helps answer which captured origins and methods have different
HTTP outcomes or recorded latency, including groups seen on only one side.

```sh
moongate requests compare-har --baseline before.har --candidate after.har > comparison.json
moongate requests compare-har --baseline before.har --candidate after.har --method POST --origin https://api.example.invalid --report > comparison.txt
```

The lightweight native `cmd/compare_har` companion accepts exactly the same
options after omitting `moongate requests compare-har`. Use a new output path:
shell redirection truncates its output before the command reads either input.
The companion reports failures on stderr with nonzero status and no partial JSON
on stdout. The main dispatcher is wired but runtime evidence uses the companion.

Try the committed synthetic `examples/har-comparison/before.synthetic.har` and
`after.synthetic.har`. The API POST group has two known elapsed samples before
and three after, with p95 increasing from 100 to 300 ms. Its known-status HTTP
error percentages are 50% and approximately 33.33%. An unknown elapsed sample
before is counted as missing, rather than as zero; the separately recorded zero
is retained. These are fixture observations, not a real performance result.

## Reading the comparison

Groups match by normalized captured HTTP(S) origin and uppercase method only.
Host case and default ports normalize as in the existing HAR inspector. Paths
are deliberately omitted, so equal group keys do not establish equal request
paths, payloads or workloads. Repeated requests contribute separate observations;
the tool does not claim to pair individual requests across captures.

- Each side reports captured row count, HTTP error count, status-0/no-response
  count, unknown-status count and known/missing elapsed sample counts.
- Elapsed p50/p95/max are milliseconds, computed by nearest rank from known
  values. Null, missing and HAR -1 values are unknown; explicit zero is known.
- HTTP error percentage is statuses 400..599 divided by recorded HTTP statuses
  100..599. Unknown status and status 0 are excluded and counted separately.
  With no recorded HTTP status, the percentage is null.
- Deltas are candidate minus baseline. Timing deltas require known values on
  both sides. The error-rate difference is percentage points, not relative change.
- `baseline_only` and `candidate_only` groups have a null summary on the absent
  side and null deltas. Absence in a supplied capture does not establish zero
  traffic. Empty captures are valid and remain explicitly empty.

The same optional method/origin filters apply to both sides. Original capture
counts and selected counts remain visible. All rows are validated before
filtering; an invalid excluded row cannot quietly pass. Group order is stable.
No status filter is offered because independently filtering error populations
would make the displayed error denominators misleading.

## Limits and privacy

Inputs follow the existing HAR 1.2 inspector's bounded format: at most 4 MiB UTF-8
and 2,000 entries per file. Output is capped at 4 MiB. Unknown format versions,
invalid status/timing fields or malformed captures fail the whole operation.

Only normalized origins, methods and numerical summaries are emitted. Headers,
bodies, cookies, raw error text, paths, queries and fragments are omitted.
Hostnames may still be private. The inputs themselves are not rewritten or
redacted; review the report and original files before sharing.

Counts are observations, not traffic rates: capture duration and completeness
are unverified. Different workloads, omitted requests, network conditions and
capture tools can change the result. No automatic regression conclusion or
causal attribution is made. HTTP 2xx does not prove complete or useful model
output. No provider call, usage mutation, pricing, deployment or UI is involved.
