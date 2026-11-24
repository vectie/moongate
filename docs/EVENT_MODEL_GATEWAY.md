# Event model gateway

`cmd/event-gateway` is a narrow MoonGate deployment mode for a shared trial
entry. It relays only `GET /v1/models`, `POST /v1/responses` and
`POST /v1/chat/completions` to `MOONGATE_EVENT_MODEL_ORIGIN`. The default bind
is `127.0.0.1:15722`; a cluster deployment must supply its own authenticated
TLS edge and network policy before external exposure.

Each request must carry that participant's upstream Bearer credential.
There is no shared provider key, stored visitor credential, provider fallback,
automatic retry, role assertion or forwarded cookie/control token. LunaNexa
retains event eligibility, model authorization, expiry, quotas, admission and
four-replica load balancing. MoonGate forwards bounded JSON/SSE responses and
preserves denial status without disclosing upstream error bodies. Browser
Origin requests are rejected; browser applications use their trusted backend.

The relay preserves the explicit `x-lunanexa-prefix-cache: tenant` compute-KV
cache opt-in (and leaves JSON `runtime_prefix_cache: true` unchanged). It does
not accept a caller-supplied tenant identity or a global-cache scope. LunaNexa
derives isolation from the authenticated participant. This does not enable
prompt/answer persistence or HTTP response caching. Streaming chunks are
flushed as they arrive; there is no relay batching delay or new concurrency cap.

Forwarding this opt-in is not a runtime compatibility or quality guarantee.
The 2026-10-23 four-Spark Qwen3.6 trial observed malformed JSON on two
cache-hit MTP requests, so upstream prefix caching was turned off through the
LunaNexa UI for a controlled repeat. Do not interpret a healthy relay, HTTP 200,
or increased cache-hit count as quality acceptance. The gateway passthrough
stays available without forcing the model runtime to cache.

The existing general-purpose MoonGate process/configuration is unchanged.
This fixed-origin mode has no provider-management surface and does not claim
native usage-dashboard accounting; participant usage remains upstream.

Build `moon build cmd/event-gateway --target native --release`; run with
`MOONGATE_EVENT_MODEL_ORIGIN` (required), `MOONGATE_EVENT_HOST` and
`MOONGATE_EVENT_PORT`. Never supply an operator token as a participant key.
Acceptance requires separate live upstream, per-user and four-node tests;
the package tests are protocol fixtures, not deployment proof.
