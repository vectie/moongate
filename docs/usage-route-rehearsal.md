# Rehearse a different route's cost on a saved workload

A route operator considering a different provider/model can now keep an observed
workload fixed, edit an explicit local route plan, and inspect hypothetical flat
token costs before deciding whether a real compatibility trial is worthwhile.
This fills the gap between the existing exact-current-route `usage price` command
and provider/policy execution. It is a cost thought experiment, not a routing
simulator, benchmark, model recommendation, or actual provider request.

## Try the workflow

From a patched MoonGate checkout, use a fresh output directory:

```sh
moongate usage reroute --file examples/usage/route-workload.csv \
  --plan examples/usage/route-plan.json > NEW-DIRECTORY/scenario.json
moongate usage reroute --file examples/usage/route-workload.csv \
  --plan examples/usage/route-plan.json --report > NEW-DIRECTORY/report.txt
moongate usage preview --file NEW-DIRECTORY/scenario.json \
  --provider candidate-route --report
moongate usage export-csv --file NEW-DIRECTORY/scenario.json \
  --view model > NEW-DIRECTORY/models.csv
```

`cmd/reroute_usage` is a small native companion with the same `--file FILE
--plan PLAN [--report]` implementation. It reads paths, prints JSON by default,
and returns errors on stderr with a nonzero exit and no partial stdout artifact.
No gateway, credentials, provider account, rate lookup or network access is needed.
Do not redirect over either input: the shell truncates destinations before the
command starts. Check exit status before opening the output. Inputs remain intact.

The bundled CSV has five synthetic observations with 2,550,150 reported tokens.
Its plan maps four rows to `candidate-route`/`candidate-small`. Three rows can be
priced for a known hypothetical subtotal of USD 6, including one known zero.
One mapped row lacks directional counts; one row has no mapping. Both have unknown
scenario costs. The original known subtotal is USD 16, but comparing that with
USD 6 would mix different coverage. Only two rows have both estimates: original
USD 12 versus hypothetical USD 4, a paired difference of USD -8. One plan mapping
is unused. These invented prices establish no savings or real provider capability.

Copy the plan to a new file and edit its target labels and rates. For example,
change both mappings to the shared candidate from input/output USD 2/4 per million
to USD 3/6. The same workload then has known scenario USD 9; the same two paired
rows are USD 12 versus USD 6. Rerun against the original usage file. An already
marked route scenario is rejected as input, preventing a hidden chain of supposed
observations. The verification script demonstrates this edit and both outputs.

For traces, first use `usage import-otel` to turn a saved local export into normal
usage JSON. Use the exact imported provider/model labels in your plan. Trace-derived
coverage remains partial and source costs remain unknown, so paired costs may
be unavailable even when all observed rows can be priced. Saved chat, batch and
Ollama import artifacts, CSV, JSON arrays and JSONL also use the existing reader.

## Editable plan contract

```json
{
  "schema": "moongate.usage-route-plan.v1",
  "name": "My hypothetical route",
  "currency": "USD",
  "routes": [{
    "sourceProviderId": "existing-provider",
    "sourceModel": "existing-model",
    "targetProviderId": "candidate-provider",
    "targetModel": "candidate-model",
    "inputUsdPerMillion": 2,
    "outputUsdPerMillion": 4
  }]
}
```

All fields are required, unknown fields reject, labels must be nonempty strings,
and rates must be finite nonnegative JSON numbers no greater than 9,007,199,254,740,991.
Source provider/model pairs are unique, exact and case-sensitive. Missing provider
labels never match synthesized `Unknown`. The exact source label `Unknown` is
reserved and rejected because saved preview exports cannot establish whether it
was synthesized; use explicit original provider evidence instead. This also
excludes a genuinely named `Unknown` source provider. There are no aliases, wildcard mappings,
fallback routes, probability weights or eligibility checks. A target pair used by
several mappings must have the same rates. Empty plans are allowed and price no
rows. Unused mapping indices are one-based and exposed to catch a mismatched plan.

For every mapped row with both directional counts, including explicit zero:

`inputTokens / 1000000 * inputUsdPerMillion + outputTokens / 1000000 * outputUsdPerMillion`

Counts are never inferred from a reported total. Existing normalization accepts
its documented aliases and numeric strings and keeps an explicit total's precedence
even if it differs from the directional sum. All token counts, dates, app labels,
request IDs and row order remain fixed. A missing direction keeps the target
labels but leaves scenario cost unknown. Unmapped rows keep their original labels
and unknown cost, never their old cost as a fallback. Every row remains a separate
observation even if IDs repeat; this operation neither merges nor deduplicates.

Only flat directional token rates are modeled. Target tokenization, output length,
quality, context capacity, tool support, latency, rate limits and live readiness
can differ radically. Nothing establishes output or runtime equivalence. Cache,
reasoning tiers, media, per-request charges, discounts, taxes and currency conversion
are unsupported. Arithmetic is finite double precision without cent rounding,
not exact financial arithmetic or settled billing.

## Explore and preserve meaning

Output is a `moongate.usage-file.v1` envelope marked with
`usageEvidenceKind: hypothetical-route-scenario` and `usageScenarioName`.
Open it in Usage File Explorer and filter by hypothetical target provider/model,
app or UTC day. Preview/filter/re-export retain the marker and show a conspicuous
hypothetical report heading. CSV exports append both marker columns; they are
spreadsheet review outputs, not a supported round-trip back into recorded usage.
Existing `usage price` preserves the marker when repricing. Existing `usage merge`
rejects marked scenarios rather than combining them with recorded observations.
The marker is descriptive, not tamper-proof; do not strip it or treat a scenario
as a provider receipt. No persistent usage or active routing configuration changes.

`usageRouteScenario` keeps the validated plan, mapped/priced/unmapped/missing counts,
unused mappings, original known costs, paired comparison and one observation per
source row. Each observation carries source and target labels, request ID, one-based
mapping index, status and both cost estimates. No pairs means null paired values.
Ordinary explorer re-export omits these detailed diagnostics; keep the original
scenario, original usage and edited plan. Repricing preserves the hypothetical
marker but replaces the detailed pricing explanation with that command's output.

Coverage flags and source totals survive. Empty input is zero observations, not
evidence of zero consumption. Payloads, credentials, extra columns and unsupported
fields are omitted; source paths, IDs and all chosen labels remain visible. Review
those before sharing. This is not comprehensive redaction of arbitrary labels.

Combined input and pretty-printed output are limited to 4 MiB UTF-8, usage to
10,000 rows and plans to 1,000 mappings. Unsafe token or estimated-cost aggregates
reject. Large repeated labels may require smaller source slices. Invalid input
rejects the entire rehearsal; it does not silently skip broken rows or mappings.

The pure API is `usage_preview.reroute_usage_file_json`. Reproduce the complete
native import/edit/explore/export workflow with `scripts/verify_usage_reroute.mbtx`.
Focused native evidence does not qualify browser rendering, installed lifecycle,
live providers, policy activation, model compatibility, billing or release readiness.
