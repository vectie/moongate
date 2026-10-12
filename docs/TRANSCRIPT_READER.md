# Read exported conversations locally

Open **Transcript Reader** in MoonGate, choose a JSON/JSONL file or paste its
contents, then choose **Open transcript**. **Try a sample** fills the input with
a small conversation. You do not need an upstream provider or API key.

- Codex rollout JSONL: message text, tool-call names, and tool outputs.
- Claude Code JSONL: message text, tool-call names, and tool-result text.
- Generic JSON/JSONL: objects with `role` and `content`, an array of those
  objects, or an object containing a `messages` array. Content can be a string
  or the text blocks understood by MoonGate's session parser.

Automatic detection picks Codex response items, then Claude-style message
envelopes, then role/content JSON. The format selector can override it. A
normalized JSON download can be reopened with automatic detection or JSON.

## Find and keep useful messages

Search text case-insensitively and filter by speaker. Results retain source
order. **Download visible JSON** preserves the displayed messages and their
available timestamps, with source and filter information. **Download visible
Markdown** produces readable notes with speaker headings. Clear the filters
first to download the whole readable conversation.

Opening another source, editing the input, or changing format clears the old
preview and disables its downloads. **Clear** discards the page's current
input and preview. The page does not store transcripts in browser storage.

The file is read only after it is explicitly selected; parsing sends the
contents to the same MoonGate gateway as the rest of this dashboard. No
provider is called, no client history is modified, and there is no persistent
import. Keep MoonGate on its default localhost binding for local-only use.
Downloads contain the selected conversation text, including any private text
present in the original log; inspect them before sharing.

## Offline command line

The preview command reads an explicit file without requiring a running gateway:

```sh
moongate sessions preview --file examples/transcripts/codex.jsonl
moongate sessions preview --file examples/transcripts/claude.jsonl --format claude
moongate sessions preview --file examples/transcripts/conversation.json --format json
```

It prints normalized JSON on stdout. This command does not write files or
change the source; use your shell's usual redirection if you want to save it.

The same parser is available to local integrations as
`POST /sessions/preview` with JSON fields `content`, optional `format` (default
`auto`), and optional `sourceName`. It uses the gateway's existing control-token
authentication. The response schema is `moongate.transcript.v1`.

## Limits

The input limit is 4 MiB of UTF-8. Malformed JSON reports an error and does not
open a partial transcript. Valid metadata, unsupported record types, empty
messages, and non-text material may be omitted; the reader shows an omitted
record count. Images, attachments, full tool-call arguments, and provider
account exports with unrelated nested schemas are not reconstructed. This is
a portable text transcript, not a lossless backup or an import into an AI
client. Keep the original log if you need complete data.
