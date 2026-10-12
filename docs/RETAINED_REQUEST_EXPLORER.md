# Retained request explorer

Open Requests in the dashboard. Choose an app and time range, optionally enter
part of a provider name or model name, and enter an exact HTTP status (100–599).
Provider/model matching is case-insensitive. Apply starts at page one. Reset
clears the text/app/status filters and returns to the seven-day interval.

The page shows the applied query and “Showing X–Y of Z retained requests”.
Previous/Next navigate 12-row pages. Details selects the exact retained request
ID. The selected ID remains visible while it loads or fails; Retry details can
recover a failed read. Changing pages or applying filters clears the selection.
Background dashboard refresh does not interrupt reading a page or detail.

Time bounds are frozen when the query is applied, including an upper bound for
All retained history. Reload page retries the same interval; Apply refreshes the
interval. This is offset pagination, not a transactional snapshot: retention,
late imports, or corrections can shift rows. An emptied last page offers Previous
and Reset. These records are retained request history, not all historical traffic.

## Exports and accounting limits

- Export displayed page CSV downloads exactly the rows currently displayed,
  with the applied query, page number and matching retained count
- Export selected report downloads the successfully loaded selected request
  as a readable text report
- Both use the same explicit metadata allowlist as the detail display. Prompts,
  response bodies, credentials and raw error messages are not exported
- CSV cells are quoted, embedded quotes/newlines are preserved, and formula-like
  prefixes are apostrophe-escaped. UTF-8 CSV includes a BOM for spreadsheet readers
- Cost is estimated USD, not a bill. Missing/invalid cost or latency is shown as
  Unavailable. The API does not distinguish recorded zero from unavailable zero,
  so zero cost/latency is explicitly labeled “zero or unavailable”
- Failed, pending or superseded list/detail loads cannot be exported

The Usage page's aggregate totals, trends and provider/model breakdowns use its
own app/time controls. Requests-page provider/model/status filters do not narrow
those aggregates. The separate By App panel remains all-time/all-apps. Aggregates
can include older rollups, so they need not equal the retained matching row count.

## Verification

Run the existing JavaScript suite and explorer regressions:

```
node --test tests/moongate-setup.test.cjs tests/moongate-requests.test.cjs
```

The native test `request_explorer_wbtest.mbt` seeds 39 synthetic records into an
in-memory UsageService with the production usage, workspace and static-file
handlers. It verifies the served HTML, byte-compares every dashboard script and
the stylesheet, then executes the served core/explorer assets against the real
authenticated loopback API. It verifies four pages within the frozen seven-day interval,
combined filters, empty/reset/back navigation, selected detail and CSV/report
parity. No provider is contacted and no user state is loaded or changed. Node
must be available on PATH for this cross-runtime test.

The JS suite separately covers reversed responses, A→B→A queries/selections,
load errors and retries, formula escaping, Unicode/quotes/newlines, explicit
missing values, allowlist exclusions, download bytes and actual dashboard event
wiring. The native test also checks the generated dashboard controls and scope
labels. This is deterministic DOM-state/API coverage; it does not claim a live
provider, real browser visual QA, complete billing or transactional pagination.

## Collect selected requests across pages

For an incident involving more than one retained page, open **Details** for a
request and choose **Keep selected metadata** in **Selected request observations**.
Navigate or apply different filters and keep other relevant requests. Expand each
kept observation to inspect its exact metadata, the originating page, applied
query and the browser UTC time when its detail response was read successfully.
**Remove observation** removes one selection; **Clear collection** removes all
selections. Neither operation changes any gateway record.

**Export selected collection CSV** writes one spreadsheet-compatible CSV using
the same explicit metadata allowlist and formula-safe encoding as the existing
page export. It includes each observation's individual query and observation
UTC time. Selecting the same request again preserves the original observation.
If its metadata has changed, the page explains the difference without replacing
that observation: inspect it and explicitly remove it before keeping the newer
one. The selection is limited to 100 requests and 2 MiB of metadata.

The collection lives only in the current page's memory. It survives page/filter
navigation and failed refreshes but disappears on reload or tab closure. Use **Save review JSON** before leaving to reopen the investigation later, or
export CSV for a one-way spreadsheet report. It never fetches other pages by itself,
never reads prompts or response bodies, and is not a complete-history export,
transactional snapshot, signed evidence record or billing statement. Previously
kept observations remain available during later loading/errors; new entries can
only come from the successfully loaded, currently selected detail. Existing
page CSV and detail-report behavior is unchanged.

Focused verification adds collection control wiring, cross-page/filter selection,
duplicate and changed observation handling, inspection/removal/clear, interrupted
reads, failed refreshes, bounded retention and downloaded CSV byte checks. These
are Node DOM-state/API-contract tests, not live browser or native gateway
qualification. The native seeded-route test remains separately gated.

## Compare a failed request with a reference

Within **Selected request observations**, open **Compare two kept requests**.
This lets an operator inspect what changed between a failed request and a
successful reference, including requests kept on different pages or under
different filters:

1. Open the failed request's **Details**, then **Keep selected metadata**.
2. Navigate or change filters to find the reference, open its details and keep it.
3. Explicitly choose **Baseline request** and **Candidate request**. For example,
   choose the failed request as baseline and the successful request as candidate.
4. Read the field-by-field metadata comparison and each observation's UTC capture
   time, source page and applied query. **Swap baseline and candidate** reverses
   the direction. **Show only differences and unavailable fields** is enabled
   initially; uncheck it to inspect all fields, including equal recorded counters.
5. **Clear comparison choices** clears the two selectors without removing your
   observations. Removing either selected observation clears its selector and
   result; keeping that request again requires choosing it again.

The comparison performs no network request. It reads the same allowlisted
metadata already kept in this tab, uses exact case-sensitive request IDs and
never automatically chooses a similar entry. Comparing one request with itself
shows a prompt instead of a result. Page/filter changes, failed refreshes and
later changed detail values do not replace the kept observations. The screen
labels its results as kept observations rather than current gateway state.
Reloading clears the collection, comparison choices and unsaved operator notes. A saved review JSON
can restore them through the explicit local-file workflow below.

### Interpret the fields and arithmetic

- Textual equality is equality of the displayed metadata, not semantic model or
  provider equivalence. For example, different number spellings can differ as
  text while their approximate numeric delta is zero.
- Missing or invalid measures are **Not comparable**, even when missing on both
  sides. Zero cost/timing retains the API's **zero or unavailable** ambiguity;
  it never becomes a known-zero numeric delta. Unknown token counts remain
  unknown. Recorded whole-token zero counters can be compared.
- Numeric deltas are **candidate minus baseline**. Token deltas require canonical
  nonnegative decimal integers no larger than 9,007,199,254,740,991. Noncanonical,
  fractional, negative and unsafe counters stay visible without arithmetic.
- Positive finite timing and USD-estimate values within that bound receive
  approximate deltas displayed to at most 12 significant digits. These are
  arithmetic differences between two recorded observations. Cost differences
  are estimates, never provider charges, refunds or proven savings.
- Request IDs, app/provider/model labels, data sources, HTTP status, streaming
  flags and timestamps are displayed without arithmetic. Different workloads,
  outcome statuses, data sources or stream modes can make two requests unsuitable
  for performance conclusions. No causal explanation, benchmark, automatic retry,
  route change or policy activation is inferred.

The comparison reads the in-tab collection. **Save review JSON** includes its
current choices so they can be reopened; there is no automatic browser storage. Prompts, response
bodies, raw errors and credential fields are excluded by the existing collection
allowlist. Metadata and filter labels are displayed literally as text; inspect
operator-supplied labels before sharing screenshots.

### Focused verification

```sh
node --test tests/moongate-requests.test.cjs
node --test tests/moongate-setup.test.cjs tests/moongate-cohorts.test.cjs tests/moongate-usage-file.test.cjs
```

The added Node tests execute the dashboard asset and actual comparison control
handlers for a cross-page failed/successful review, reversing deltas, toggling
fields, unknown/zero values, removal/recapture, stale and interrupted refreshes,
and literal allowlisted metadata. They do not qualify a browser layout, native
MoonBit gateway execution, real provider telemetry or billing reconciliation.


## Save and resume a request investigation

Use this when an incident spans sessions and you need to continue reviewing the
same kept observations rather than search for those requests again. It also works
when those requests are no longer retained. This is a local review-file workflow
in the existing Requests dashboard, not an import into gateway usage.

1. Keep the relevant request details, including requests from different pages or
   queries. Optionally choose a baseline and candidate and toggle the differences
   view.
2. In **Selected request observations → Save or reopen an investigation**, choose
   **Save review JSON**. The browser downloads `moongate-request-review.json` with
   the selected display metadata, original observation UTC timestamps, source
   pages, applied-query text and comparison choices.
3. Later, open Requests and use **Choose saved review JSON**. File selection only
   reads and validates locally. A status message shows the observation count;
   the current collection and comparison remain unchanged.
4. Choose **Open saved review (replace collection)** to replace only the in-tab
   collection and comparison. **Cancel file choice** abandons the staged file,
   including a read still in progress. The retained page, selected live detail,
   aggregate filters, records, providers and routing policy remain unchanged.
5. Expand observations and continue comparing. **Remove observation**, **Clear
   collection**, the comparison controls and CSV export work as before. Keep a
   newly read detail to add it. If its exact ID is already present, the original
   observation is preserved even if the current metadata differs; explicitly
   remove the old observation before keeping the replacement.
6. Choose **Save review JSON** again to download the edited investigation. The
   original file is never overwritten by the dashboard. Browser download naming
   and save locations depend on browser settings.

### File provenance and meaning

Every reopened observation is labeled **Local review file (unverified; not
refreshed)** in the expanded entry and comparison context. Its CSV row's scope
also says **unverified local review file**. A newly kept detail remains labeled
as a retained detail read in this tab, so a mixed review shows each observation's
source. Saving and reopening the mixed review marks all its entries as local-file
content on the next open.

The saved timestamps and query descriptions are file-supplied provenance, not
verified current gateway evidence. Import does not contact the gateway, refresh
those records, replay requests, add usage, or produce an audit attestation. Normal
dashboard loading and explicit live-detail reads continue to use the existing
API separately; a gateway error does not discard the local review.

Displayed unknowns, zero-or-unavailable annotations and estimated USD remain
unchanged. The existing comparison rules apply to their displayed strings,
including no cost/timing delta for ambiguous zeros. Files can be edited outside
MoonGate; successful format validation does not prove their facts, origin,
redaction, or authenticity. The importer never grants authority or establishes
provider charges.

### Version 1 contract and limits

An unannotated UTF-8 JSON envelope uses `schema: "moongate.request-review.v1"`, a fixed
scope disclaimer, `observations`, and `comparison`. Each observation contains
only `id`, `observedAt`, zero-based `page`, `query`, and the complete ordered
`fields` list of 19 `[label, displayed string]` pairs from the existing detail
allowlist. The Request ID display must match `id`. `comparison` contains
`baselineId`, `candidateId`, and boolean `differencesOnly`; each nonempty ID must
refer to a contained observation. Empty choices and same-ID choices are preserved
(the latter still prompts for two different requests).

- Up to 100 unique nonempty request IDs and 2 MiB of serialized observation
  metadata; the whole uploaded file is limited to 3 MiB to allow formatting
- A UTF-8 BOM is accepted. Unsupported version numbers, extra keys or field labels,
  missing display fields, duplicate IDs, invalid capture context and references
  to absent comparison IDs reject the entire file without replacing the review
- CSV, Usage File Explorer JSON, HAR captures and raw `/usage/logs` exports are
  different formats. Use a file produced by **Save review JSON**
- A failed or superseded file read cannot open an older staged selection. Cancel
  and selecting a newer file invalidate the pending read
- No local storage, IndexedDB, automatic file writes or server upload;
  reloading still discards unsaved changes. To combine a file with current work,
  use the explicit merge workflow below instead of Open saved review

Gateway captures keep the established metadata allowlist: prompts, bodies,
credentials and raw error fields are not serialized. Strict import rejects extra
keys; it does not scrub arbitrary text inside allowed labels, IDs or query text.
Review saved files before sharing them. All imported text is rendered literally,
and CSV export retains formula-safe quoting.

### Focused verification of resume

```sh
node --check public/assets/moongate-usage.js
env -u MOONGATE_TEST_ROOT node --test tests/moongate-requests.test.cjs
env -u MOONGATE_TEST_ROOT node --test tests/moongate-*.test.cjs
```

Five new Node tests execute actual dashboard handlers and Blob download/read
bytes: a cross-page review reopened in a fresh dashboard with exact comparison
continuity; choose/cancel/explicit replacement; resumed removal and fresh detail
capture followed by a second save/reopen; useful import error recovery; and newer
file/cancel interruption behavior. They verify allowlist exclusions, literal
Unicode labels, unknown/ambiguous measures, unverified-file source labels and
absence of gateway calls during import. The wider dashboard suite is regression
coverage. These tests use a DOM-state harness, not a real browser, native gateway,
provider or billing service; the existing native-route tests remain separately
gated and skipped when their host is absent.

## Add operator notes and export an investigation report

Kept metadata explains what was observed, but it does not explain why an operator
selected those requests or what still needs checking. **Write investigation
notes** now keeps that interpretation beside the selected observations, without
changing the request records or turning commentary into recorded telemetry.

1. Keep the requests relevant to an incident, across pages or filters as needed.
2. In **Write investigation notes**, enter an **Investigation summary
   (operator-authored)**. For example, describe the time window and unanswered
   questions without asserting a cause you have not established.
3. Choose an exact ID in **Kept request to annotate** and write a **Note for the
   selected request (operator-authored)**. Switch IDs to inspect or change each
   note. Text is retained in this tab as you type; there is no separate save-note
   action. Erasing a note removes it. Editing notes makes no network requests.
4. Optionally select baseline/candidate comparison IDs in the existing panel.
5. Use **Save review JSON** to retain the investigation for later editing. The
   download includes annotations, observations and comparison choices. Reloading
   loses changes made since the last downloaded file; there is no browser storage.
6. After reopening Requests, choose that JSON file and then **Open saved review
   (replace collection)**. File choice only stages it. Explicit opening replaces
   the collection, comparison choices and operator notes. Cancel leaves all
   current work unchanged. All reopened observations retain the existing
   **Local review file (unverified; not refreshed)** label.
7. Choose **Export investigation report** for a UTF-8 plain-text file containing
   the summary, each exact request ID, recorded display metadata, original
   observation context, per-request notes and the current comparison, if valid.
   Reopen the JSON to edit later; the text report is a one-way readable export.

The report includes every kept observation, regardless of the current retained
page or filters. A comparison follows the current differences-only checkbox and
uses the existing candidate-minus-baseline rules. Unknown fields and ambiguous
zero cost/timing stay non-comparable. Costs remain estimates; no report is a bill,
causal diagnosis, signed evidence, authenticated approval or incident closure.
Each multiline value is visibly indented so operator text stays within its labeled
section. The report does not recalculate aggregate usage or fetch newer records.

### Ownership, editing and disclosure

- Summary and request notes are explicitly **operator-authored, unverified**.
  MoonGate does not infer them from telemetry, authenticate their author or decide
  whether their claims are true. A file can be edited outside this application.
- Gateway metadata still uses the existing 19-field allowlist. User-written notes
  are **not automatically redacted** and can contain anything the operator types.
  Do not enter credentials. Inspect notes and allowed metadata before sharing a
  JSON, report or screenshot. No file is uploaded or automatically delivered.
- Metadata-only collection CSV, page CSV and selected-request reports do not gain
  annotations. Use the new investigation report or review JSON when notes are
  intended to be included.
- Removing an observation also removes its note. Recapturing the same request ID
  starts without that old note. The investigation summary remains until it is
  edited, a saved review is explicitly opened, or **Clear collection and notes**
  is used. Clearing removes all annotations and observations from this tab.
- Summary text can be drafted before keeping a request, but saving/exporting an
  investigation requires at least one kept observation. Removing the last
  observation retains the summary in the tab; keep another request or copy the
  text yourself before leaving. No automatic recovery is provided.
- Changed live details, pagination, filters and failed refreshes never replace
  the kept metadata or notes. A newly selected file does not replace work until
  Open is chosen. An invalid file leaves current annotations intact.

### Review-file versions and bounds

A file without any nonempty annotation keeps the existing
`moongate.request-review.v1` format. Annotated files use
`moongate.request-review.v2`, with the same scope, observations and comparison,
plus `annotations: { summary, notes: [{ requestId, text }] }`. Each note refers to
one contained exact request ID; IDs must be unique within notes. The summary is
text, and empty notes are omitted. Version 1 remains readable and opens with empty
annotations. Older application versions that only know version 1 cannot open
annotated version 2 files; keep this version to resume them.

A summary is limited to 8,000 UTF-16 code units, and each note to 4,000. The
serialized summary and note entries together must fit 128 KiB. If an edit exceeds
a limit, the prior text remains and a status message explains that the edit was
not kept. The existing 100-observation, 2 MiB observation and 3 MiB input-file
limits remain. Neither successful validation nor a matching request ID proves
that an imported annotation is true or authorized.

### Focused annotation verification

```sh
node --check public/assets/moongate-usage.js
env -u MOONGATE_TEST_ROOT -u MOONGATE_REQUEST_TEST_URL node --test tests/moongate-requests.test.cjs
env -u MOONGATE_TEST_ROOT -u MOONGATE_REQUEST_TEST_URL -u MOONGATE_COHORT_TEST_URL -u MOONGATE_USAGE_FILE_TEST_URL node --test tests/moongate-*.test.cjs
```

Seven additional Node tests execute actual input, select, download, file-picker and
explicit-open handlers. They check a two-request incident saved/reopened in a new
dashboard context, report Blob bytes and comparison parity, a second edit/save,
legacy file recovery, exact-ID note removal/recapture, failed-refresh continuity,
literal Unicode/multiline text, summary-only clearing, and recoverable annotation errors. Fixtures are
synthetic. The gateway metadata allowlist remains separate from user annotations.

This is executable dashboard JavaScript and DOM-state coverage. No real browser
layout, native gateway, provider, authenticated operator, incident outcome,
billing reconciliation or full-product journey is qualified. Native-route tests
remain skipped without their separately authorized host. R50 remains the last
fully verified cumulative baseline; R51–55 remain separate.

## Combine saved investigations without replacing current work

Use this when useful request observations are split across two locally saved
reviews, or when you already kept live details and want to add an earlier review.
It extends the existing Requests dashboard: no CLI or running provider is needed
for the merge itself. Normal dashboard loading still uses its configured gateway.

1. Keep current observations, or explicitly open the first saved review as above.
   Save the current review first if you want a separate recoverable copy.
2. Choose the second file with **Choose saved review JSON**. Read the **Merge
   preview** below the replacement action. File selection changes nothing.
3. Confirm **these reviews use the same gateway/request-ID namespace**. The files
   do not contain a verified gateway identity: you must know the source. This
   checkbox is a user assertion, not authentication or proof that two IDs refer
   to one real request. Do not merge unrelated gateways merely because IDs look
   different or similar.
4. If the preview is eligible, choose **Merge saved review into collection**.
   Current observations stay in order; new exact IDs append in file order. Current
   comparison choices stay selected, including empty choices; the file's
   comparison choices are ignored. Select another comparison explicitly if needed.
5. Inspect or edit the combined notes, compare the requests, and use **Save review
   JSON** to download the combined investigation. It reopens through the same
   version 1/2 workflow. **Export investigation report** includes the combined
   notes; collection CSV remains metadata-only. Original files are never modified.

### What the preview means

- New observations are marked **Local review file (unverified; not refreshed)**.
  Current observations keep their existing provenance and original capture context.
- IDs match exactly, with case preserved. If an ID already exists and all 19
  displayed metadata values are equal, the current observation is kept once.
  Its capture time, page and query win even when the imported context differs;
  the alternate capture context is not retained. Equal fields are not proof of
  equivalent workloads, authenticity, current state or settled charges.
- A missing note can be filled from the file. Identical note text is kept once.
  Different nonempty notes for an overlapping ID block the whole merge.
- A blank current summary adopts the file summary. Different nonempty summaries
  are combined by appending the file summary under an **Imported review summary
  (operator-authored, unverified)** label. The exact resulting summary appears in
  the preview. An identical summary, or one already equal to the final imported
  summary block, is kept once. There is no semantic deduplication of rewritten
  or earlier embedded summaries: review the resulting text before merging.
- Different recorded metadata for an overlapping ID also blocks the whole merge.
  The preview identifies each conflicting ID and whether its metadata or notes
  differ. No nonconflicting observations or notes are imported until all conflicts
  are resolved. MoonGate never chooses the newer timestamp as the correct value.
- The combined collection must fit 100 observations and 2 MiB; the combined
  summary must fit 8,000 UTF-16 code units, and all annotations 128 KiB. Existing
  per-note and source-file limits still apply. No truncation or partial import
  happens when a combined limit is exceeded.

To resolve a conflict, inspect both original reviews and save your current work
before removing anything. You can edit a current note to the agreed exact text,
or explicitly remove its current observation and note if you want to use the
file's version instead. Removal also clears any comparison choice for that ID;
merging does not silently select the imported replacement. Shorten summaries or
remove saved observations to resolve capacity limits. The preview and button
eligibility update as current notes and observations change. Use **Cancel file
choice** to abandon the merge without changing current work, or choose another
file. Every new file choice requires a fresh namespace confirmation. The existing
**Open saved review (replace collection)** action remains available when full
replacement is actually intended; it does not perform a merge.

Merge never fetches or replays a request, changes retained gateway usage, verifies
annotations, or modifies routing. Imported allowed strings and notes are rendered
as literal text, but are not automatically redacted. Review all content before
sharing. Reload still discards unsaved work; there is no browser storage,
automatic file write, cross-gateway reconciliation or authenticated audit trail.
Unknown measures and ambiguous zero-cost/timing values retain their prior meaning.

### Focused merge verification

```sh
node --check public/assets/moongate-usage.js
env -u MOONGATE_TEST_ROOT -u MOONGATE_REQUEST_TEST_URL -u MOONGATE_COHORT_TEST_URL -u MOONGATE_USAGE_FILE_TEST_URL node --test tests/moongate-*.test.cjs
```

Eight additional Node tests exercise actual file-picker, namespace checkbox,
merge, edit, remove, download and explicit-open handlers. They cover an annotated
combined investigation saved and reopened with exact Blob bytes, provenance and
comparison continuity, legacy/exact-ID repeats, metadata and note conflict
recovery, edits after preview, interrupted/canceled file reads, combined capacity
limits, unknown values and literal operator text. These are synthetic dashboard
JavaScript/DOM-state tests. They do not qualify real browser layout, a native
MoonBit gateway, authenticated operators, live provider requests, incident
outcomes, billing or full-product execution. Native-route tests remain separately
gated. R50 remains the last fully verified cumulative baseline; R51–55 are separate.


## Find observations and save a focused subset

An investigation can contain several unrelated incidents after collecting or
merging reviews. Use **Find observations and save a focused subset** to prepare a
small review for one issue without deleting the rest of your work. This runs
locally on the kept observations, including reopened files; it does not search
other retained pages or contact a provider.

1. Keep or reopen the observations you need. Enter a provider, model, request ID,
   HTTP result or phrase from a request note into **Search kept metadata and
   request notes (literal text)**. Only the kept-observation list is filtered.
   The status shows visible, total, selected and hidden-selected counts.
2. Check **Include in subset** beside an exact request ID, or choose **Add visible
   observations to subset**. Adding is cumulative: change the search and add
   another group, or include a successful reference for comparison. Search itself
   never checks or unchecks anything. Even zero visible matches can leave selected
   observations hidden, listed by exact ID in the preview.
3. Use **Show all kept observations** to inspect every choice, uncheck an
   individual request, or **Clear subset selection** to start again. None of these
   actions removes kept observations or notes. The ordinary **Remove observation**
   and **Clear collection and notes** controls still remove local work as labeled.
4. Review the selected IDs and annotation count. Each selected request's current
   note is included. The investigation-wide summary is omitted by default because
   it may describe excluded requests. Explicitly check **Include the entire
   investigation summary** only when that whole text belongs in the handoff.
   Notes and the optional summary are unverified operator text, not automatically
   redacted; inspect them before sharing.
5. Choose **Save subset review JSON** to download
   `moongate-request-subset.json`. This is a partial investigation containing only
   checked observations, including selections hidden by the search. The full
   in-tab investigation, its comparison and the original files are unchanged.
6. Reopen the download using **Choose saved review JSON** then **Open saved review
   (replace collection)** in another session, or use the existing explicit merge
   flow. Imported observations remain labeled unverified and not refreshed. From
   that focused review you can continue annotating/comparing and export its normal
   investigation report or collection CSV.

### Selection and file semantics

Search is one case-insensitive literal substring after trimming leading/trailing
whitespace. It matches each of the 19 displayed metadata values or the request's
note independently. It does not interpret regular expressions, split search
words, search the global summary, or search observation capture timestamps/query
context. Request identity stays exact and case-sensitive even when search matches
both variants. An empty search shows all entries; their collection order is kept.

**Save review JSON**, **Export selected collection CSV** and **Export investigation
report** still export the whole collection regardless of search or subset choices.
Only **Save subset review JSON** narrows the export. It is disabled for an empty
selection. Adding new kept or merged observations leaves them unchecked; existing
selections survive navigation, failed refresh, file staging/canceling and merges.
Removing an observation also clears its choice, so recapturing that ID does not
silently reselect it. Explicitly opening a replacement review or clearing the
collection resets search, subset choices and summary inclusion. Clearing the
summary resets its inclusion checkbox. Selection/search are in-tab controls and
are not persisted in either review-file format.

Subset files use the existing v1/v2 review format and its fixed “Selected
observations only; not complete history, current gateway evidence, or a billing
statement” scope. Exact IDs, allowlisted metadata, original capture times, source
pages and query descriptions are copied unchanged. Only selected-ID notes are
included. A comparison selector is retained only if its exact ID is contained in
the subset; a missing side becomes empty so reopening asks for another explicit
choice. The original comparison is unchanged. Unknown measures, ambiguous zero
cost/timing and estimated costs retain their original display strings.

The file does not record the parent collection size, search text or a verified
relationship to the original review. Keep a full review separately if that
context is needed. It does not redact selected labels, IDs, query text or notes,
authenticate facts, replay requests, send a handoff to someone, or mutate gateway
usage. Existing collection, annotation and file bounds apply. Reload still loses
unsaved work; there is no automatic browser persistence.

### Focused subset verification

```sh
node --check public/assets/moongate-usage.js
env -u MOONGATE_TEST_ROOT -u MOONGATE_REQUEST_TEST_URL -u MOONGATE_COHORT_TEST_URL -u MOONGATE_USAGE_FILE_TEST_URL -u MOONGATE_REQUEST_EVIDENCE -u MOONGATE_ANNOTATION_EVIDENCE -u MOONGATE_MERGE_EVIDENCE -u MOONGATE_SUBSET_EVIDENCE node --test tests/moongate-*.test.cjs
```

Seven added Node tests exercise the actual search, checkbox, additive-selection,
summary-option, file-picker and download handlers. They reopen actual subset Blob
bytes and export a focused report in a new dashboard context, while checking that
the full source review is unchanged. They also cover hidden selections, note
edits, incomplete comparison references, merge/replacement/recapture, failed
refreshes and literal Unicode strings. This qualifies the synthetic JavaScript
DOM-state workflow only. Browser rendering and keyboard interaction, native
gateway execution, real providers, billing and complete product execution remain
unqualified. R50 remains the last fully verified cumulative baseline; R51–55
remain separate.
