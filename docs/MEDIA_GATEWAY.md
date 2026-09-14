# Managed video forwarding

`MOONGATE_LUNANEXA_MEDIA_ORIGIN` enables a fixed-origin LunaNexa media relay.
It is a server-owned HTTP(S) origin, without a path, query or embedded credentials.
An unset or invalid origin leaves the media routes unavailable; they never fall
back to an OAuth/text provider.

Supported paths are `POST /v1/videos`, `GET`/`DELETE /v1/videos/video-{64 hex}`,
and `GET /v1/videos/video-{64 hex}/content`. A caller's scoped Bearer credential
is forwarded only to the configured LunaNexa origin. POST also requires a stable
`Idempotency-Key`. LunaNexa remains the authority for account, lease, order,
profile, job ownership and billing. MoonGate does not turn video into token
usage or retry an ambiguous submission.

Use a private listener/network policy for hosted ComfyUI. Browser Origin requests
are rejected on these routes; the authenticated WebIDE's pod-local proxy is the
caller. Cookies, control tokens and forwarded-host headers are not propagated.
Requests are limited to 64 KiB, metadata to 256 KiB, and streamed MP4 content to
1 GiB. Upstream redirects and response cookies are not followed or forwarded.

For a Kubernetes service, `MOONGATE_REQUEST_HOST` selects the exact trusted
request hostname independently of the bind address. It does not allow wildcard
hosts or change the expected port. Existing loopback access remains supported.

Native relay tests cover route boundaries, credential forwarding, header
isolation, size limits and content streaming. The complete native suite passed
900 tests, including the hostname/routing assertion. Existing
repository deprecation warnings still prevent the current-toolchain deny-warn
gate; no production/GPU acceptance is implied by these tests.
