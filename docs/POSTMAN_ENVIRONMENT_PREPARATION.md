# Prepare a request library with a named Postman environment

MoonGate's native `provider postman` converter does **not** load environment
exports. This separate dependency-free Node CLI prepares a Collection v2.1 file
for that existing input boundary. It does not launch MoonGate, execute requests or
scripts, write provider configuration, or establish live readiness.

Use Node 18+ and trusted, sanitized collection and environment JSON exports.
Only the chosen files are read. No globals, Postman workspace, process environment
bindings, credentials store or provider connection is consulted.

## Inspect, select, prepare

From the repository root, inspect the shipped synthetic example:

```sh
node postman_prepare/prepare.cjs \
  --collection examples/postman/model-library.postman_collection.json \
  --environment examples/postman/local.postman_environment.json \
  --environment-name 'Synthetic local'
```

`inspect` is the default. Its JSON contains the exact environment name, input
SHA-256 hashes and byte lengths, binding eligibility, applicable and shadowed
request numbers, effective variable sources, unresolved and sensitive names,
and explicit precedence. It writes no files. Values are hidden by default;
add `--show-values` to inspect eligible literal environment values locally.
Treat that output as private. `--show-values` is unavailable in preparation, so
unselected environment values do not enter the provenance report.

Select individual names with repeated `--select` options. An optional selection
on `inspect` previews the effective result. Names are exact and case-sensitive.
Preparation requires at least one selection and a **new** output directory:

```sh
node postman_prepare/prepare.cjs prepare \
  --collection examples/postman/model-library.postman_collection.json \
  --environment examples/postman/local.postman_environment.json \
  --environment-name 'Synthetic local' \
  --select baseUrl --select trace --out-dir ./prepared-local
```

The example's `model` environment binding is entirely shadowed by the Chat
folder variable and cannot be selected. `apiToken` is sensitive and cannot be
selected. Preparation checks the environment's name exactly; it never chooses
an environment by a convenient filename or loads several environments at once.

The new private bundle contains:

- `prepared.postman_collection.json`: separate Collection v2.1 input
- `original.collection.json` and `original.environment.json`: byte-exact originals
- `provenance.json`: selected names, source hashes, output hash, unresolved names,
  warnings, native verification limitation, and `complete: true`

The original paths are untouched. Existing files, directories and symlinks at
`--out-dir` are rejected. Files are created exclusively with mode 0600 inside a
0700 directory. The receipt is written last; a directory without the receipt is
incomplete. A failed write can leave a partial directory; inspect it and choose
a new output path. The tool does not delete or overwrite it.

The bundle deliberately retains the original bytes, which may include secrets
that the prepared collection omits. Keep the entire bundle private. Before
sharing, separately review the exact file you intend to share. Hashes establish
which bytes were used, not their trustworthiness or completeness. If source
hashes differ from the inspection you reviewed, inspect the new inputs again.

## Pass the prepared file to the existing converter

On a separately qualified MoonGate installation:

```sh
moongate provider postman --file prepared-local/prepared.postman_collection.json
moongate provider postman --file prepared-local/prepared.postman_collection.json --http > prepared-local/requests.http
```

Inspect unresolved variables and fill authentication manually in your HTTP
editor. A prepared file or syntax-valid URL does not mean the endpoint exists,
is reachable, is eligible, or accepts a model. Sending requests is a separate
operator action and can incur charges.

**Verification boundary:** real Node CLI preparation, structural round-trip,
file/hash preservation, and native source-contract checks are tested. The above
native conversion commands have not been run against this feature. Native
interoperability and the repository's full MoonBit checks remain release blockers.
No native converter binary or new compiler/dependency is included.

## Deliberate scope rules

From closest to broadest, effective values are:

1. URL variables
2. Request-item variables
3. Nearest folder variables
4. Explicitly selected environment bindings
5. Collection variables

This is MoonGate preparation precedence, not a claim to reproduce every Postman
runtime scope. A selected binding replaces every same-name collection entry at
the root. Closer item/folder/URL values remain local. An unsafe closer value
continues to shadow the environment and becomes an empty manual default; the
tool never falls back to a broader value. Disabled closer entries do not shadow.
Duplicate collection/local variables retain the native last-enabled-entry rule.

Environment entries with `enabled: false` or `disabled: true` are unavailable.
Multiple enabled environment entries with the same name are all blocked as
ambiguous. Disabled duplicates do not block a unique enabled entry. Unreferenced
or fully shadowed names cannot be selected. Only references in supported active
URL, query, header and raw-body fields are considered applicable. An environment
entry's presence never makes it selected.

Only nonempty, single-line string/number/boolean literals can be selected.
Dynamic names (`$...`), nested placeholders, control characters, secret-typed
values, sensitive names and recognizable URL-embedded credentials are blocked.
Malformed/unclosed placeholders and placeholder names containing braces are
rejected before output; use `{{name}}` with a nonempty brace-free name. Ordinary
JSON braces outside placeholders remain literal. No value is interpolated
recursively, and request placeholders remain intact for
the existing native converter's request-local declarations. Missing bindings
remain unresolved. The native converter renders their defaults as `REPLACE_ME`.

Preparation retains supported request names, order, methods, raw URLs, query
arrays, headers, raw bodies, and safe scope defaults. Structured query arrays
win over raw query strings, keep enabled entry order and repeated keys, and are
not URL-encoded by this tool; the native converter encodes them later. Fragments,
saved responses, unrecognized metadata, disabled fields and unsupported body
contents are omitted. Unsupported body mode labels remain for native warnings.

Authentication helper types are retained for manual-setup warnings, with all
helper values removed. Explicit auth objects with missing, empty or non-string
types remain empty objects, preserving the native converter's suppression of
inherited auth. An absent or null auth field continues to inherit; `noauth`
remains explicit. Sensitive headers/query values are withheld;
cookie/transport headers are omitted. Script code is removed; inert empty script
markers retain the native converter's inherited-script warning. No script is
evaluated. Unsafe known variable defaults become empty, preserving their scope.

This is **not complete redaction**. Ordinary variable literals, names, URL paths,
query values, headers and raw body text may contain private data. Sensitive-name
heuristics can also block innocuous names (for example names containing `key`).
Sanitize source exports and review outputs; neither inspection nor preparation is
a general secret scanner, complete Postman validator or Postman runtime.

Both inputs are bounded to 4 MiB; collections additionally have the native
2,000-item / 32-folder-level limits, and environments have at most 2,000 entries.
Preparation validates all requests and produces at most a 4 MiB collection. It
supports the two standard Collection v2.1 schema URLs already accepted by the
native converter. It rejects malformed structures and header strings rather
than guessing their meaning.
