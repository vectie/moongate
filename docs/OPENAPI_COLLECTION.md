# OpenAPI operation explorer and request collections

An application integrator can inspect a provider's exported API description and
prepare editable requests without starting MoonGate or contacting a provider.
This is an offline authoring tool, not a live compatibility or readiness check.

Have a browser Network capture instead of a specification? Use the
[HAR request importer](HAR_COLLECTION.md) to turn captured HTTP requests into
the same editable `.http` workflow.

## Try the supplied model API

```sh
moongate provider openapi --file examples/openapi/model-api.json
moongate provider openapi --file examples/openapi/model-api.json --tag Models
moongate provider openapi --file examples/openapi/model-api.json --operation createChat --http > chat.http
```

The default JSON includes source/selected operation counts, methods, paths,
summaries, tags, effective first server, inherited/overridden parameters, supplied
examples, security requirements and per-operation warnings. `--tag` and
`--operation` match exactly and combine with AND. Zero matches returns an empty
collection, not an arbitrary fallback.

`--http` emits an editable HTTP-client text collection. Open it in an editor that
supports `.http` files, or use it as a reference when writing your client. Replace
`REPLACE_BASE_URL` with the intended server base (without a trailing slash), set
the parameter variables and add the intended authentication yourself. Query and
path variables need appropriate URL encoding; structured parameters need the
source contract's serialization. Optional parameters are included so you can see
them; delete ones you do not want. Parameter examples appear as comments. JSON
request-body examples are copied into the body for editing. Nothing is sent by
this command; manually sending a prepared request may incur provider charges.

The supplied example produces three operations: list models, inspect one model,
and create a non-streaming chat. It uses only synthetic content and the reserved
`.invalid` domain. The Chat filter yields one editable request with its resolved
message example. No provider records or user configuration are changed.

## Supported input

- OpenAPI 3.0.x / 3.1.x JSON, up to 4 MiB and 2,000 operations
- Standard HTTP method entries under paths; source order is preserved, with a
  stable GET/POST/PUT/PATCH/DELETE/HEAD/OPTIONS/TRACE method ordering
- Local object `$ref` with JSON Pointer `~0`/`~1` escaping, at most 16 links
- Path and operation parameters; operation entries override identical in/name
  pairs. Operation/path/root server precedence and operation/root security apply
- Parameter `example`, first named `examples.*.value`, then schema `example` or
  `default`; JSON media examples and local referenced request bodies/examples
- Only the first declared server/example is selected. All server URLs remain
  source metadata; execution URLs are always manual placeholders

## Limits

For offline response/schema inspection, open the route studio's
[response explorer](../route_studio/responses.html) through a local static HTTP
server. Paste sanitized OpenAPI JSON, select an operation, status and media type.
It displays nested field breadcrumbs, required declarations, enums, examples,
local references and explicit unsupported/cyclic-reference messages. It does
not send requests, fetch external references, validate responses or generate
schema-derived samples. This separate browser inspection tool does not change
the CLI request importer's scope below. Module loading requires HTTP serving;
no build or installed dependency is required.

### Compare two response contracts

In the same response explorer, load the **Before** document in the first input
and the **After** document in the second. The comparison has its own operation,
status and media selectors; the original single-document explorer still works.
Options are the union of declarations from both loaded documents. Selectors
match the exact HTTP method/path pair, status key and media string, never the
operation ID, a similarly named route, a wildcard status or a default response.
If a selected declaration is missing on either side, the result identifies
`missing-operation`, `missing-status` or `missing-media` and does not substitute
another contract. Responses without content have no media to compare.

The **Before → After differences** result lists added/removed declared fields
and changes to required, declared type/nullable and enum values. Breadcrumbs
preserve nested properties and array items. Local object references resolve
independently within each document, using the same escaping and depth limits as
inspection. Enums are compared as sets; JSON object key order, enum order and
type-array member order are ignored. Array order inside an enum value remains
significant. An absent nullable flag and false are treated alike. Descriptions,
titles, supplied examples and defaults are annotations outside this comparison.
All numeric enum values, including numbers nested inside enum arrays/objects,
make the comparison indeterminate. JSON parsing can round large integers and
decimals, underflow to zero or overflow to nonfinite values; this bounded tool
does not retain lossless numeric tokens. Even ordinary integer enum values are
conservatively excluded. Numeric schema type declarations remain comparable.

This is a conservative declaration comparison, not a schema validator or a
compatible/breaking-change verdict. Any unresolved/recursive reference,
reference sibling, invalid/missing schema, traversal truncation or unsupported
schema declaration makes the selected comparison **indeterminate**. This
includes composition (`allOf`, `oneOf`, `anyOf`), conditionals, additional
properties, dynamic refs, format/validation constraints and required entries
without property schemas. Partial traversal never produces a definitive added,
removed or unchanged field conclusion. Schema fields supported for comparison
are type, properties, required, items, enum and nullable, plus the annotations
listed above. This bounded check does not establish dialect compatibility or
full OpenAPI validity. Unavailable or unresolved media examples do not block
schema comparison; their warnings remain in the single-document explorer.

The existing 4 MiB/2,000-operation input and 500-node/24-level/16-reference limits
apply to each document. Each enum has a further 10,000-value/node and 24-level
comparison bound. A result with no differences explicitly refers only to the
inspected field/required/type/enum declarations. Editing either input immediately
clears the comparison and disables its selectors; reload that input to compare
again. Failed loads clear stale results. All data stays in page memory and is
lost on refresh; the page uses no endpoint calls or browser storage. Use public
or sanitized documents, since values are displayed without general redaction.

Focused regression: `node --test route_studio/responses.test.mjs`. Tests import
the production module and bind its actual HTML control IDs through a minimal
DOM adapter. They cover both load orders, selection changes, missing declarations,
failed/edited input recovery, nested differences, conservative bounds and
text-only rendering. They do not qualify graphical layout, accessibility,
browser module serving, installed-host integration or provider compatibility.

The CLI excludes YAML, Swagger 2, remote refs, callbacks/webhooks, response/schema exploration and
schema-derived sample generation are not included. `$ref` siblings are ignored;
pointer traversal supports objects, not array indexes or percent decoding.
Server-variable expansion, multipart/form bodies, cookies and complex parameter
serialization require manual editing. Missing JSON examples yield `{}` with an
explicit warning, not a claim that this satisfies the schema. Imported operations
are not registered as MoonGate providers or capability routes.

The importer is not a full OpenAPI validator. References used by selected request
templates are resolved; unused schema/response references need not be resolved.
Malformed JSON, unsupported version, missing paths, unresolved used refs and
colliding parameter-variable names produce an error instead of partial output.

No secrets are read from the host. Parameter examples whose names include
authorization/key/token/cookie are withheld, but this is not general redaction:
body examples and other supplied metadata are retained. Use public or sanitized
specifications and review the export before sharing. Existing provider tools,
usage imports and transcript readers are unchanged.

Already have a team-maintained Postman library? The
[Postman Collection importer](POSTMAN_COLLECTION.md) preserves nested request
folders, scoped variable defaults and raw bodies in editable HTTP output.
