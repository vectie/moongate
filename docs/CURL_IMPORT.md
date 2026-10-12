# Import a copied curl request

Turn a literal POSIX-style curl command from API documentation or developer tools
into an editable HTTP-client request. No shell, request, provider, or script runs.

Save the command as text, then run:

```sh
moongate provider curl --file request.curl > request.http
```

For a lightweight offline companion, build `cmd/import_curl`. Its one argument is
the literal command text. This also avoids starting the gateway:

```sh
moon build cmd/import_curl --target native
import_curl "$(cat examples/curl/chat.curl)" > chat.http
```

The companion receives command text in process arguments, so use it only with
synthetic or already-scrubbed inputs. Use the main CLI's file option for private
captures. Shell command substitution above reads the file; never `eval` its text.

## Supported translation

- One HTTP(S) URL, positional or `--url`; quoted query strings remain encoded.
- POSIX single/double quotes, adjacent quoted segments, escapes and backslash-LF
  continuations. This is not a shell interpreter.
- `-X`/`--request`, `-I`/`--head`, repeated `-H`/`--header` values.
- One literal `-d`/`--data`, `--data-raw`, `--data-binary`, or `--json` body.
  Data defaults to POST; explicit methods win. Data content type defaults to
  form-urlencoded; JSON adds JSON content type and Accept unless supplied.
- `-s`, `-S`, `-sS`, `--silent`, `--show-error`, and `--compressed` are accepted
  transport/display options. The HTTP client controls compression and display.
- Recognizable authorization, cookie, API-key, token and secret headers become
  numbered `REPLACE_ME` variables. Fill the whole header value, including any
  required `Bearer` prefix. Ordinary headers, URL and body remain unchanged.

Unsupported options fail rather than being silently dropped: redirects, uploads,
forms, auth helpers, file references, multiple URLs/bodies, combined short flags
except `-sS`, `--option=value`, header removal and shell expansion/operators.
URL brace/range globbing is rejected even inside quotes; brackets are supported
only for an IPv6 host authority, with an optional numeric port. `--globoff` is not
supported by this subset. Percent-encoded literal braces/brackets remain literal.
Use quoted URLs when they contain `&`. PowerShell/CMD quoting and ANSI-C `$'…'`
are not supported. Multiline `--data` is rejected because curl strips newlines;
use `--data-raw` for literal multiline text. Input is limited to 1 MiB of text
(the file command additionally limits bytes). URL userinfo is rejected.

This is not a general scrubber: bodies, URLs and unrecognized header names can
contain private data. Review before sharing. Review HTTP-client-specific syntax,
including `{{variables}}` and body lines that might be interpreted as separators,
before manually sending. Importing never establishes live-provider compatibility.
