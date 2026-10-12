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

YAML, Swagger 2, remote refs, callbacks/webhooks, response/schema exploration and
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
