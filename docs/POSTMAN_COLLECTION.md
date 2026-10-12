# Import a Postman request library

Reuse an exported Postman Collection v2.1 as editable `.http` requests. This
complements MoonGate's [OpenAPI](OPENAPI_COLLECTION.md) and [HAR](HAR_COLLECTION.md)
imports when your team already maintains a Postman library. The importer runs
offline: it does not start MoonGate, install providers, execute scripts or send
requests.

## Try it

```sh
moongate provider postman --file examples/postman/model-library.postman_collection.json
moongate provider postman --file examples/postman/model-library.postman_collection.json --folder Models
moongate provider postman --file examples/postman/model-library.postman_collection.json --folder Models/Chat --method POST --http > chat.http
```

Open the generated file in an HTTP-client editor. Review each request, replace
`REPLACE_ME` values, supply authentication, then manually send the request if you
intend to. Sending requests can incur provider charges. The fixture uses only
synthetic content and reserved `.invalid` domains; change the base URL before
trying an actual service.

The default JSON includes collection name, total/selected request counts, source
request numbers, folder paths, methods, request URLs, headers, bodies, editable
variable declarations, warnings and the complete HTTP text. Folder selection
matches an exact slash-separated folder path and its descendants, case-sensitively.
`--method` is case-insensitive. The two filters combine with AND; no match produces
an empty collection. Source order and request numbers remain stable under filters.

## What carries over

- Nested folder/request names and collection order, including shorthand URL
  requests (GET)
- Collection, folder and item variables, overridden by closer scopes and URL path
  variables. Only referenced variables are exported; each request receives unique
  `pm_<source request number>_v<n>` identifiers so a later folder cannot overwrite
  another request's defaults
- Single-line string, number and boolean defaults. Missing, dynamic (`$...`),
  sensitive-name and nested-variable defaults become `REPLACE_ME`; nested defaults
  are not recursively expanded. Environment/global variables are not loaded
- HTTP(S) or variable-based raw URLs, `:pathVariable` segments and `{{variable}}`
  placeholders. URL objects require `raw`; host/path-only objects are unsupported
- Structured URL query arrays take precedence over the raw query. Enabled entries
  retain order and repeated keys; literal keys/values are percent-encoded once.
  Already percent-encoded structured values will be encoded again. Values inside
  variable declarations are not URL-encoded: encode them appropriately before
  use in a query/path. Without a query array, the raw query is retained
- Enabled header-array entries, preserving repeated ordinary headers
- Raw text/JSON bodies and their variables. Raw JSON language metadata supplies
  `Content-Type: application/json` only when no enabled content-type header exists
- Inherited bearer authentication becomes an empty editable bearer variable.
  `noauth` on a folder/request suppresses inheritance; an explicit Authorization
  header takes precedence over the generated bearer placeholder

## Explicit omissions

Scripts and tests never run or appear in the export. Requests inheriting script
hooks receive a warning because scripts may have supplied required variables or
modified a request. Saved responses, cookies, file contents and environment
exports are not imported. Non-raw bodies (form-data, URL-encoded, file, GraphQL)
need manual reconstruction and receive per-request warnings. Other authentication
helpers are named in warnings but must be recreated manually. Raw header strings
are unsupported and produce an error rather than silently losing headers.

Authorization and other sensitive-name header values are replaced. Cookie and
transport headers are omitted. Sensitive-name query values are withheld. Variable
names containing authorization/token/key/cookie/secret/password are withheld.
This is not comprehensive redaction: ordinary values, metadata, paths and body
text can contain private data. Use trusted sanitized exports and inspect the
result before sharing. Literal embedded URL credentials are rejected; secrets
hidden in ordinary variable values cannot be reliably identified.

The collection must identify the standard v2.1.0 schema URL. Limits are 4 MiB,
2,000 total items including folders, and 32 folder levels. Folder names containing
`/` are rejected to keep selectors unambiguous. Structural limits cover the whole
collection; request validation applies to selected requests. The tool is not a
complete Postman validator or runtime. Protocol behavior, cookies, certificates,
request ordering dependencies, response assertions and automatic redirects are
not reproduced. HTTP-client syntax inside imported raw content is not escaped.

Input shape reference: [Postman Collection v2.1 schema](https://schema.postman.com/json/collection/v2.1.0/collection.json).
