# Price a local usage export with a hypothetical rate card

`moongate usage price --file FILE --rates RATE_CARD.json [--report]`

Explore what recorded token counts would cost under your own explicit USD rates.
The standalone `cmd/price_usage` executable calls the same command implementation.
No provider, gateway, pricing service, credentials, or internet connection is
required. This is a hypothetical scenario, not a quotation, bill, live price
lookup, spending limit, or accounting update.

## Try the complete workflow

```sh
out="$(mktemp -d)"
moongate usage price --file examples/usage/pricing.csv \
  --rates examples/usage/rates.json > "$out/scenario.json"
moongate usage price --file examples/usage/pricing.csv \
  --rates examples/usage/rates.json --report > "$out/scenario.txt"
```

Use a new output path, never an input path. Shell redirection truncates its target
before execution and may leave error text when the command fails. Exit status 0
means a scenario was produced; errors exit nonzero without a partial JSON export.

Open `scenario.json` in MoonGate's existing Usage File Explorer. Filter by
provider, model, app, or inclusive UTC date and inspect its summary and groups.
With the checked-in fixture, the scenario has USD 4 in known estimates, two
priced requests (including a known zero), one missing directional-token pair,
and one unmatched rate. Filtering to `fixture-east` leaves three requests and
one unknown scenario cost. The original known estimates total USD 15; only one
row has both estimates, and its paired difference is USD -1. Comparing all USD 15
to the scenario USD 4 would mix differently covered rows.

The existing `cmd/import_usage_csv` explorer executable can reopen the small
synthetic output as its JSON-text argument for reproducible process testing.
That executable exposes its argument in the process list; use it only for
synthetic/scrubbed text, not private exports. The normal file-based pricing
command accepts file paths and does not put file contents in arguments.

## Rate-card format

```json
{
  "schema": "moongate.usage-rate-card.v1",
  "name": "My hypothetical scenario",
  "currency": "USD",
  "rates": [
    {
      "providerId": "fixture-east",
      "model": "fixture-small",
      "inputUsdPerMillion": 2,
      "outputUsdPerMillion": 4
    }
  ]
}
```

These are invented fixture rates. Supply your own assumptions. Currency must be
exactly `USD`; the command performs no exchange conversion. All shown fields are
required. Empty rate arrays are allowed and price no requests. Each rate must
be a finite nonnegative JSON number up to 9,007,199,254,740,991; numeric strings
are rejected. Provider/model pairs must be unique, nonempty and match input
labels exactly and case-sensitively. There are no model aliases, wildcard
fallbacks or live catalog lookups. Unknown fields are rejected to avoid quietly
ignoring attempted tiers, cache rates, taxes or other pricing rules.

## Calculation and missing evidence

For each row with an explicit nonempty provider label, a matching rate, and
known inputTokens and outputTokens:

`inputTokens / 1000000 * inputUsdPerMillion + outputTokens / 1000000 * outputUsdPerMillion`

Both counts are required, including an explicit zero. A missing direction is
never inferred from totalTokens. This flat scenario applies the supplied rates
to the supplied directional counts, independently of the reported total. It
does not model cached/reasoning tiers, request fees, media, taxes, discounts or
provider-specific billing rules. Arithmetic uses finite double-precision values,
without rounding to cents; it is an estimate, not currency settlement.

Missing provider, unmatched rate and missing counts produce an unknown cost,
not zero and not the old estimate. These are mutually exclusive diagnostic
statuses, in that order of precedence. All input rows are separate observations,
even when request IDs repeat. Source row numbers identify them. Existing usage
normalization applies; costs recorded here are the normalized input estimates,
not raw provider invoices. Invalid usage rejects the entire file.

## Output and reopen behavior

The output is a normal `moongate.usage-file.v1` explorer envelope. `data` contains
normalized usage with scenario costs in `totalCostUsd`. Source totals, partial
coverage and any merge identity scope are preserved. `usagePricing` includes:

- The validated user-supplied rate card and explicit hypothetical provenance
- Per-source-row status, original normalized estimate, and scenario estimate
- Missing-rate, missing-token and missing-provider counts
- Original known estimates and missing count
- A paired comparison over only rows with both known estimates; paired totals
  and difference are null when there are no pairs

Unknown rows are excluded from known totals. Empty input has zero observations,
not evidence of zero real consumption. Partial files remain partial. A scenario
artifact can be reopened and filtered by the existing explorer, but re-exporting
from that reader drops the extra pricing metadata, just as other diagnostic
metadata is omitted. Keep the original scenario JSON and original usage input.
Repricing a prior scenario treats its scenario costs as the current input's
original estimates; it does not preserve an unlimited history.

Recognized input formats are CSV, JSON arrays, JSONL and existing usage-preview
envelopes. Input plus rate card is limited to 4 MiB UTF-8, usage to 10,000 rows,
rates to 1,000 entries, and pretty-printed output plus newline to 4 MiB. Unsafe
aggregate token or cost totals reject the entire scenario. Labels can make the
output larger than the input; choose smaller slices if the output limit rejects.

Inputs remain unchanged; no configuration, pricing catalog, provider, or
persistent usage is modified. Payloads, headers and arbitrary fields are omitted.
Request IDs, source paths, rate-card name and provider/model labels remain visible;
review these before sharing. This focused local workflow does not qualify live
provider prices, operator UI rendering or a full MoonGate release. Cumulative
qualification remains R50.
