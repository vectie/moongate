# MoonGate documentation

- [Responsibility and testability](RESPONSIBILITY_AND_TESTABILITY.md)
- [UI-to-UI use cases](qualification/UI_TO_UI_USE_CASES.md)

- [Product contract](PRODUCT_CONTRACT.md) — current maturity, security and
  release gates.
- [Technical identity migration](MOONGATE_TECHNICAL_MIGRATION.md) — retiring
  MoonStat state safely.
- [Executable capability projection](CAPABILITY_REGISTRY.md) — authoritative
  inventory, manifest, adapter-health and exact-operation resolution.
- [Lepusa release handover](LEPUSA_APP_RELEASE_HANDOVER.md) — application
  packaging boundary.
- [UI guide](UI_GUIDE.md) — operator interface.
- [Root README](../README.mbt.md) and [`PLAN.md`](../PLAN.md) — runtime details
  and ordered validation work.

## Saved Ollama response captures

Use the offline [Ollama capture reader](ollama-capture-import.md) to collapse a
saved generate/chat stream into terminal usage evidence and inspect interrupted
or errored captures without contacting a provider.

## Saved Chat Completions responses

Use the offline [Chat Completions capture reader](chat-capture-import.md) to
review a saved JSON response or SSE stream as one request, then open the emitted
usage artifact for filters, groups and spreadsheet export. Missing usage and
interrupted captures remain explicit, without contacting a provider.

## Request investigation notes

Use [Requests](RETAINED_REQUEST_EXPLORER.md#add-operator-notes-and-export-an-investigation-report)
to keep operator-authored context beside selected request metadata, resume the
annotated local review, and export a readable investigation report. Notes remain
unverified commentary and are not automatically redacted.

## Combine saved investigations

Use [Combine saved investigations](RETAINED_REQUEST_EXPLORER.md#combine-saved-investigations-without-replacing-current-work)
to add another local review to the current Requests collection with exact-ID
conflict checks and preserved operator notes. Confirm the common request-ID
namespace yourself; imported content remains unverified.

## Focus a request handoff

[Search and save a focused subset](RETAINED_REQUEST_EXPLORER.md#find-observations-and-save-a-focused-subset)
from kept observations without deleting the rest of the investigation. Choose
exact requests, inspect hidden selections and download a resumable partial review.
