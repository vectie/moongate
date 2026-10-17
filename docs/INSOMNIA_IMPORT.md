# Prepare saved Insomnia requests for manual integration

MoonGate can read a **legacy Insomnia v4 JSON export**, inspect its request and
folder inventory, and prepare a separate editable `.http` collection. This is
offline application-integrator preparation for MG01/MG05. It does not configure
a route, contact a provider, demonstrate provider compatibility, or establish
readiness or permission to dispatch.

## Journey

1. Keep the original export in a separate file. The importer opens that path
   read-only. Its output is a deliberately incomplete derived artifact, not a
   backup or replacement for the export. Never redirect output over your input.
2. Inspect the JSON receipt and `inventory` to find exact workspace, folder and
   request resource IDs. IDs avoid ambiguity between identically named folders.
3. Select a workspace, a folder subtree, a single request, or their intersection.
4. Export `.http`, inspect every omission and placeholder, and edit a copy for
   your authorized endpoint. Re-run from the original as needed. Sending is a
   separate manual action in your HTTP client and is outside this workflow.

```sh
moongate provider insomnia --file examples/insomnia/workspace-v4.json
moongate provider insomnia --file examples/insomnia/workspace-v4.json --workspace wrk_models --folder fld_models
moongate provider insomnia --file examples/insomnia/workspace-v4.json --request req_chat --http > prepared.http
```

The lightweight `cmd/import_insomnia` executable accepts the same options and
uses the same parser and renderer. Both commands accept `--help`; rejected input
exits nonzero, writes its error to stderr, and leaves stdout empty. Unknown or
duplicate options fail. Selectors must name existing resources of the right
kind. A selector intersection with no requests fails instead of pretending to
have exported a useful collection.

The JSON receipt includes the original export date/tool labels (unverified
source labels), original resource counts, an inventory, the selected source
resource IDs and one-based source-array indexes, ancestor folder IDs and paths,
request data, per-request warnings, omitted-resource-type counts, and HTTP text.
Source-array order is preserved; `metaSortKey` is not used to simulate UI order.
The `.http` representation also includes each selected source ID and index.
Request names and folder paths are labels, not selectors or filesystem paths.

## Supported literal subset

- One JSON document with numeric `__export_format: 4` and `resources` array;
  optional top-level `_type` must be `export`. v5 YAML and older versions reject.
- `workspace`, `request_group`, and HTTP `request` records. Workspaces are roots.
  Requests/groups must reach a workspace through existing request groups.
  Duplicate IDs, orphaned links, invalid names, cycles and overdeep graphs fail,
  including outside the chosen selection.
- GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS and TRACE with literal HTTP(S)
  URLs. Embedded URL user-info credentials, empty hosts and whitespace reject.
- Ordered, repeated raw URL query values and additional `parameters` values.
  Structured parameters are appended in source order and UTF-8 percent-encoded;
  disabled entries are omitted. URL fragments are omitted with a warning.
- Ordered literal headers, including duplicates. Disabled entries are omitted;
  malformed header tokens or control values reject.
- Literal text bodies and optional MIME types. Text is retained as supplied
  only when it does not contain templates, control bytes or directive-like
  lines. Normal JSON examples remain editable.

## Explicit omissions and privacy

Insomnia/Nunjucks templates are **never evaluated or copied into executable
positions**. A templated URL becomes `https://REPLACE_ME.invalid/`; templated
header/query values become edit placeholders; a templated body is omitted.
Environment values, folder environment overrides, pre-request/response scripts,
tests, plugins, saved responses, cookie jars, auth helpers and runtime settings
are never imported. Unsupported resource types are counted separately.
`pathParameters` are not resolved and produce a warning when present.

File, form-parameter and multipart bodies are omitted with warnings. No body
file is opened. Body lines beginning (after whitespace) with `#`, `<`, `>` or
`@`, and template markers, are conservatively omitted so source text cannot
introduce HTTP-client separators, scripts, file inclusions or variable hooks.
This also excludes some harmless Markdown/XML text; reconstruct it manually.

Authentication-like header names receive request-local `REPLACE_ME` variables.
Cookie and transport headers are omitted. Query names containing authorization,
token, key, cookie, secret or password have their values withheld; raw
percent-encoded names are withheld conservatively. Authentication helpers do
not synthesize an Authorization header. Review and configure auth manually.

This is **not general secret redaction**. Literal paths, ordinary query/header
values, request bodies and source labels may contain private data. Inspect the
original and derived files before sharing. The original may contain credentials
even when known credential fields were withheld from the derived collection.
No claims are made about an external HTTP client's eventual behavior.

Limits: 4 MiB UTF-8 input, 2,000 resources, 32 nested folders, 8 MiB compact JSON
derived result. Resource IDs/types are bounded ASCII identifiers (letters,
digits, `_`, `-`, at most 256 characters). Export date/tool fields, when present,
must be strings. Unsupported or malformed selected request data rejects before
any output. Empty unfiltered exports return an explicit zero selected count.

## Verification and references

`scripts/verify_insomnia.mbtx` exercises the actual main and companion binaries:
inventory, folder/request selection, readable HTTP export, manual editing of a
separate artifact, deterministic reruns, failure channels, and unchanged input
bytes. Package tests cover malformed graphs, bounds, credential handling,
templates, disabled fields, Unicode and HTTP-client directive exclusions.

This bounded implementation uses Kong's [import/export reference](https://developer.konghq.com/insomnia/import-export/)
and the official [v4 importer](https://github.com/Kong/insomnia/blob/2bb5a976ce625600eb2114e8d806f609a5fcd6c9/packages/insomnia/src/main/importers/importers/insomnia-4.ts)
and [resource types](https://github.com/Kong/insomnia/blob/2bb5a976ce625600eb2114e8d806f609a5fcd6c9/packages/insomnia/src/main/importers/entities.ts),
read on 2026-10-13. Current Insomnia exports v5 YAML; this workflow is explicitly
for saved legacy v4 JSON, not a claim of complete current Insomnia compatibility.
## Exact export identity

The export version must denote exactly the integer 4. Integral decimal or
exponent spellings such as `4.0` and `40e-1` are accepted; a fractional token that
would round to 4 is refused. Duplicate decoded JSON keys anywhere in the export
are rejected before resource identities, selections or literal request fields
are interpreted. Escaped key spellings do not bypass this check. No request is
sent by parsing or converting the supplied file.
