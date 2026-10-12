# Turn a browser capture into editable requests

When a client works in the browser but you have no OpenAPI description, export
its Network capture as HAR 1.2 JSON. Use a sanitized capture: this importer keeps
ordinary URLs, headers and text bodies, which can contain private information.

```sh
moongate provider har --file examples/har/browser-model-session.har
moongate provider har --file examples/har/browser-model-session.har --method POST --url-contains /chat --http > chat.http
```

The JSON output lists original one-based entry numbers, methods, URLs, editable
headers, bodies and warnings, plus a complete `http` collection. `--http` prints
only that collection. Open it in an HTTP-client editor. Review the destination,
body and warnings, replace `REPLACE_ME` auth values, and manually send when ready.
Sending is a separate action and may incur charges. Importing never starts the
gateway, reads host credentials, registers providers or sends any request.

Method matches case-insensitively. The URL substring filter is case-sensitive,
matches the captured URL before sanitization and combines with method using AND.
Capture order, repeated query parameters and repeated ordinary headers survive.
Zero matches yields an empty collection. Invalid selected entries fail the whole
import rather than silently dropping a request.

## Supported capture data

- HAR 1.2 JSON, up to 4 MiB and 2,000 entries
- Absolute HTTP(S) requests using GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS,
  or TRACE; URL fragments are removed
- Captured `postData.text` is copied exactly, with MIME type supplied if the
  request lacks Content-Type. Empty text remains a valid captured empty body
- JSON, plain text and already-encoded form text work without reserialization
- No response payloads, cookie arrays, timing data or browser state are copied

Authorization/key/token/cookie/secret/password-named headers become editable auth
variables. Cookie, Host, Content-Length, Connection, Transfer-Encoding,
Accept-Encoding and Proxy-Connection headers are omitted with warnings so the
HTTP client can reconstruct its own transport details. Query values with those
sensitive names, or percent-encoded names, become `REPLACE_ME`. Query order and
encoding otherwise remain untouched. Embedded URL credentials are rejected.

## Boundaries

This is a request authoring tool, not capture playback or a browser emulator.
Redirects, cookies, request dependencies, compression, client certificates,
WebSockets and HAR timings are not replayed. Multipart, encoded postData and
params-only bodies require manual reconstruction and produce warnings. Captured
headers can be stale or browser-specific; edit/remove them as needed. HTTP client
template syntax inside imported bodies or values is not escaped: use trusted,
sanitized captures and review the collection before executing it.

Name-based auth withholding is not comprehensive redaction. Secrets may remain
in paths, innocently named query parameters, headers or bodies. Do not share raw
captures or generated files without reviewing their content. Responses and other
unused HAR fields are ignored rather than validated. This does not qualify a
live provider, modify authored PRD statuses or imply a captured call is safe to
repeat. The example uses synthetic data and reserved `.invalid` destinations.

For request outcomes and timing phases in the capture, use
[`moongate requests har`](har-diagnostics.md). That offline diagnostic reader
keeps original entry numbers and supports HTTP-status filtering and detail reports.
