# MoonGate route scenario studio

MoonGate provides compatible model routing and usage review. This local page authors the existing hypothetical route-plan contract so operators can compare explicit route alternatives without hand-writing JSON.

Open `route_studio/index.html` locally with its sibling `studio.js`. Enter a name, exact source provider/model labels, target labels and input/output USD-per-million assumptions. Save mappings locally; select a mapping to edit it, remove it, or undo. Existing `moongate.usage-route-plan.v1` JSON can be pasted and loaded. Duplicate source pairs and inconsistent rates for a shared target are rejected. Zero rates are valid. Provider/model labels are exact and case-sensitive.

Download saves retained mappings. Save any mapping edits first, or choose New mapping to discard them. Download refuses unsaved mapping fields. The page never fetches current rates or contacts a provider. Values remain in the page until downloaded; refreshing discards them.

## Start from observed usage

Paste an original `moongate.usage-file.v1` JSON export into **Saved original
usage JSON** and choose **Load observed source pairs**. The list groups exact
`providerId`/`model` pairs in first-observed order and shows how many imported
rows have each pair. Select a pair, then choose **Use selected source pair**.
Enter target labels and input/output rate assumptions yourself, review, and
save the mapping. Selecting a pair already mapped opens its existing saved
mapping. This never creates a duplicate mapping automatically.

The importer reads only labels and source coverage. It does not validate
tokens, prices, request identity, provider availability or routing eligibility.
Repeated request IDs remain separate observed rows; no usage or charge record
is created. A row with a missing, non-text, blank or exact `Unknown` label is
counted as unresolved and cannot seed a mapping. Valid labels retain their
exact spaces, case and Unicode. Raw prompts and unrelated usage fields are not
rendered in the pair list or copied into the downloaded plan. Labels themselves
are visible, so review them before sharing a plan.

Only canonical JSON is supported in this control, not CSV, JSONL or provider
aliases. Use an existing native usage export first for those formats. The
export must have a data array of at most 10,000 object rows and an integer
`sourceTotal` between its row count and 2,147,483,647. Optional `partial` and
`sourceCoverageUnknown` flags must be booleans. Partial and unknown coverage
stay visible; counts describe only the pasted file. A hypothetical-scenario
marker, invalid shape or input larger than 4 MiB rejects the import.

Editing the paste or a failed import clears the previous observed choices.
Neither changes saved mappings or unsaved mapping fields. Using a pair refuses
unsaved mapping edits; save them first or explicitly discard them with **New
mapping**. Loading usage does not change the scenario name. The paste stays
in this page until replaced or refreshed; no network call or browser storage
is used. Download still contains only the existing route-plan contract, up to
1,000 mappings. The native consumer separately limits the combined original
usage and plan to 4 MiB and validates the actual usage.

Run `moongate usage reroute --file usage.json --plan moonGate-route-plan.json`, or build/use the existing `cmd/reroute_usage` companion with those same flags. The native consumer produces a hypothetical usage scenario with explicit missing-token/unmapped/coverage caveats. Original recorded usage is unchanged. Target token counts, model quality, current pricing and settled charges are not predicted. No route activation or account change occurs.

## Example and checks
The retained synthetic example maps recorded/alpha and recorded/beta to candidate/small at input USD 1 and output USD 2 per million. The actual UI-produced plan consumed by the native companion gives USD 1.20 and 2.40 hypothetical estimates, USD 3.60 paired total against USD 15 recorded estimates. These are fixture results, not savings claims.

`node route_studio/studio.test.mjs route_studio downloaded-plan.json` tests actual controls, import, edit, remove, undo, download bytes and validation with a DOM adapter. A retained R654 native companion consumed those exact bytes. No MoonBit code changed or native binary rebuilt; graphical browser/accessibility and full release gates remain unrun/blocking.

For the observed-usage journey, pass optional third and fourth paths for its
downloaded plan and synthetic original usage:
`node route_studio/studio.test.mjs route_studio downloaded-plan.json usage-plan.json usage.json`.
Eight tests cover the original studio and new source-pair controls. The retained
R654 native companion consumed the actual new download: three mapped fixture
rows, two unmapped rows, and approximately USD 3.60 hypothetical paired cost.
Unknown coverage and the unmapped rows' unknown costs survive. This is no
savings or billing claim. The relevant reroute functions and CLI remain
byte-identical to R654; later attribution additions change the current package
closure. The retained binary proves backward-compatible artifact consumption,
not a rebuilt current binary or complete current-source qualification.
