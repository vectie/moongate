# Profile latency in saved usage exports

`moongate usage latency --file FILE [--app VALUE] [--provider VALUE] [--model VALUE] [--start-day YYYY-MM-DD] [--end-day YYYY-MM-DD] [--report]`

This offline workflow finds slow recorded requests and compares observed latency
distributions across providers and models. It accepts the same CSV, JSON, JSONL
and usage-preview envelopes as the Usage File Explorer. No account, credentials,
running gateway or provider connection is needed. The small `cmd/latency_usage`
executable invokes exactly the same implementation with the same options.

```sh
out="$(mktemp -d)"
moongate usage latency --file examples/usage/latency.csv > "$out/profile.json"
moongate usage latency --file examples/usage/latency.csv --provider fixture-east --report > "$out/profile.txt"
```

Redirect only to a new destination, never an input file. The command reads files
and prints output; it does not itself write files. Errors exit nonzero, and shell
redirection may leave an error message rather than a valid profile.

## Latency contract

- Accepted fields are `latencyMs` or `latency_ms`, in milliseconds. Values may be
  finite nonnegative JSON numbers or numeric strings up to 9,007,199,254,740,991.
  Fractional milliseconds are allowed. Explicit zero is a measured sample.
- Absent fields, JSON null and the exact empty string mean unknown. Empty CSV
  cells are omitted by the existing reader. Other invalid values, including
  negative numbers, booleans, NaN and infinity, reject the entire file, even if a
  filter would exclude that row. Supplying both aliases is an error.
- No other duration field is inferred, and seconds are never automatically
  converted. Latency is supplied by the exporter; its boundary may mean total
  request duration, gateway duration or something else. Use exports with a known,
  compatible measurement convention. This profile is not a live benchmark,
  time-to-first-token analysis, proxy-overhead measurement or availability claim.
- The existing usage importer still requires a nonempty model and at least one
  valid token-count field. Invalid usage rows reject the whole file as before.

## Selection and interpretation

App, provider and model filters are exact and case-sensitive. Date filters use
inclusive UTC days and the existing timestamp normalization. Undated rows appear
without a date bound and are excluded when either date bound is supplied.
Invalid or reversed dates reject. Source totals and partial/unknown coverage
remain visible independently of selected-row counts.

`summary`, `byModel` and `byProvider` include total rows, sample count, missing
latency count and p50/p95/p99/max in milliseconds. Groups sort lexically by key.
Percentiles use the nearest-rank definition: sort known samples ascending and
select the 1-based element at ceil(percentile × sample count). There is no
interpolation. For two samples p50 is the lower sample; p95 and p99 are the
higher. All four statistics are null with no known samples. Tiny samples and
partial exports do not establish stable or population-wide performance.

`slowest` contains at most 20 measured rows, descending by latency; equal values
retain their original data-row order. `sourceRow` is 1-based, excluding a CSV
header or blank JSONL lines. It disambiguates duplicate or synthetic request IDs.
Every imported row is a separate observation: this command does not deduplicate.
The normalized row includes latency, ID, app, provider, model, UTC date, usage
counts and file-supplied estimated USD. Unknown cost remains null, not zero.
No payloads, headers or arbitrary extra fields are emitted. IDs, labels and local
paths remain visible; inspect before sharing.

The output schema is `moongate.usage-latency.v1`, a profile artifact, not a usage
export. It intentionally holds only the slowest 20 rows and cannot be reopened
as a complete request file. Keep the original input. Existing single-file
preview/explorer and merge exports omit latency fields; profiling such an export
therefore reports missing samples. Use original telemetry exports for latency.
The CSV reader recognizes the latency aliases for this workflow, but ordinary
preview normalization continues to discard them.

Input and pretty-printed output are each bounded to 4 MiB UTF-8; input is limited
to 10,000 rows. The command makes no network requests or persistent accounting,
routing, provider, credential or configuration changes. R272 focused acceptance
does not change the R50 cumulative qualification boundary.
