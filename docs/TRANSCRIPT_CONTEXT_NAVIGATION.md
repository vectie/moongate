# Find a message and read its surrounding exchange

Open **Transcript Reader**, choose a supported exported log or paste role/content
JSON, then select **Open transcript**. The existing `/sessions/preview` boundary
parses the explicit input. It does not call a model or add client history.

1. Enter literal text under **Find text**, optionally select a speaker.
2. Read the matching messages with highlighted literal text and their original
   source positions. Search is Unicode case-insensitive; it does not accept regex.
3. Select **Match with 2 nearby messages** or **Match with 5 nearby messages**.
   The reader displays that many messages on each side of the current matching
   message, clipped to the beginning/end of the opened transcript. This restores
   the surrounding question, tool result, and reply without changing the filter.
4. Use **Next match** and **Previous match** to move through matches in source
   order. Navigation stops at the boundaries. The current match is outlined and
   labeled; messages outside the filter are explicitly labeled nearby context.
5. Return to **Matching messages** to see the complete filtered result again.

**Downloads are the matching set, not the context window.** The buttons say
**Download matching JSON/Markdown**. A neighboring message outside the filter
never enters either output. Matching messages elsewhere in the source remain in
these downloads even while one context window is being read. Clear filters if
an entire normalized conversation is desired.

Editing the source or format, choosing another file, or clearing invalidates the
current transcript and all match positions. Changing the search/speaker resets
navigation to the first match. No matches disables downloads/navigation and
shows a recovery hint. Stale asynchronous preview results cannot restore an old
conversation after a source edit. All content/highlights use text nodes, never
HTML interpretation. The page does not persist logs, search text or navigation
state. The existing 4 MiB source limit and parser omissions still apply.

## Verification and limits

Run `node --test tests/moongate-transcript-navigation.test.cjs` from the repository,
or execute the adjacent round's `focused-test.sh` from any directory. Tests load
and exercise the actual shipped controller against a minimal DOM and a fixture
preview response: search, context navigation, text safety, boundaries, exports,
source edits, stale responses and recovery. These are not native gateway,
full-browser, provider, billing, or desktop qualification. No native interfaces,
routing policy, dispatch authority or parsing contracts changed.
