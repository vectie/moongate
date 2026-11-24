# MoonGate UI guide

MoonGate sits between AI apps on your Mac and AI providers. An app sends its request to MoonGate's local address; MoonGate then sends it to the provider you selected. This gives several apps one place for provider setup, routing, request history, and usage.

If you are new to MoonGate, use this order:

1. Open **Providers**, choose a preset, enter the provider's API key or use OAuth, choose a model, and **Save Provider**.
2. Run **Test Provider**, then choose **Connect app**. The default scope serves MoonDesk and other Moon apps.
3. In **Apps → List**, choose the provider and **Connect App**. MoonGate writes and reads back that app's real configuration.
4. Open **Apps → Graph** for the final check. Green requires a saved, available provider with a recent matching successful test, verified app wiring, and running routing.
5. If an app says **Manual setup**, use **Apps → Manual setup** and enter the shown address in that app yourself.
6. Return to **Overview**, then use **Requests** or **Usage** to verify real traffic.

## What each page is for

The sidebar has six destinations: **Overview**, **Providers**, **Apps**,
**Requests**, **Usage**, and **Advanced**. Operations, resilience, suite
diagnostics and help live under Advanced. Transcript reading opens from
Requests and provides a return button. Existing direct page links still work.
Only the active page's data is refreshed; request investigations and policy
drafts use explicit reloads. Provider changes preserve unsaved form edits.

### Overview

Use Overview to answer: “Is MoonGate ready?” It shows whether the local MoonGate service and AI routing are running, the provider or model currently reported by the route, request and spend totals, and a readiness checklist.

- **Start Routing** lets AI apps send requests through MoonGate.
- **Stop Routing** stops that request path without closing the UI.
- **View Usage** opens MoonGate's human-readable Usage page. It never opens raw monitoring text.

### Apps → Manual setup

Use Manual Connect only when App Bindings says **Manual setup**, or when another AI app asks for a **Base URL**, **API address**, or **environment variables**. Pick the API format named by the app and copy its value.

The **Monitoring data (advanced)** address is for Prometheus or another external monitoring dashboard. It is machine-readable text, not a MoonGate screen, so the UI only copies its URL.

### Apps → List

Use App Bindings after configuring a provider. It separates four facts that were previously mixed together:

- **Installed** means MoonGate found the app on this Mac.
- **Not connected** means MoonGate has not verified that the app points to it.
- **Connected** means MoonGate wrote the app configuration and read back the expected local address.
- **Manual setup** means MoonGate does not yet have a safe automatic configuration writer for that app.

MoonDesk, MoonClaw, Codex, and Claude Desktop support automatic binding. MoonDesk appears first and consumes providers from the shared OpenClaw scope through its initialized MoonClaw runtime. MoonBook and MoonTown have explicit manual setup entries; their template availability does not claim automatic installation detection or binding.

“Detected command-line apps” means programs such as Codex, Claude, Gemini, and OpenCode installed on the Mac. MoonGate checks them so it knows which configurations it can support. They are not extra MoonGate features and you do not need to install every one.

The collapsed diagnostics area covers sign-ins, MCP connections, and app plugins. Ignore it unless an app or plugin specifically asks for MCP or an extension.

**Backup & failure handling** is advanced and collapsed by default. It can try backup providers automatically and temporarily pause a provider that fails repeatedly. The default settings are appropriate unless automatic recovery is required.

### Apps → Graph

Use Connection Graph after Providers and App Bindings. It shows one lane for every saved provider that can serve each supported app, with MoonDesk first. Each lane separates the evidence MoonGate has:

- **Saved**, **Enabled**, and **Tested** describe the provider. Tested means completed model output for the matching configuration in this window. It is a last-check result, not a continuous availability guarantee.
- **Selected** means that provider is the current MoonGate route for the request type. It does not mean an app is connected.
- **Installed**, **Bound**, and **Verified** describe the app. Verified is shown only when MoonGate reads the expected local address back from the app configuration.
- **Not wired** means at least one required step is missing. Manual apps remain unwired until they are configured outside MoonGate.

Use **Fix Providers** or **Fix App Bindings** from the graph to return to the missing step, then refresh the graph.

Each app shows its selected path first. Expand **Other saved providers** to
inspect alternatives; those routes do not become selected merely by opening
them. Expansion is retained during refresh.

### Providers

Use Providers to add, edit, test, delete, or pause an upstream provider account. It never claims to connect an app.

The table shows credentials, availability, and the saved configuration's last test. **Test Provider** requires completed model output, not just HTTP 200. It reports HTTP status, model, latency and time. Changing the endpoint, protocol, model or credentials requires another test. Renaming, notes, and pausing do not. Results stay in this window until reload, without a forced expiry or background paid retest. After external credential changes, test again. General historical health cannot turn the graph green.

After saving an OpenAI-compatible or Anthropic API-key provider, use **Refresh models** to fetch its model IDs with the key already held by MoonGate. Choose an ID to fill **Default Model**, then use **Save Provider** to retain it. Save changed connection settings before discovery. OAuth-managed and Gemini Native providers retain manual model entry. Empty, unsupported, and unavailable catalogs leave the model unchanged and can be retried. Catalog discovery does not test inference, certify availability, change the active provider, or bind an app; **Test Provider** and **App Bindings** remain separate actions.

The preset picker includes DeepSeek, OpenRouter, Fireworks AI, SiliconFlow, Qwen Token Plan, Qwen Pay-As-You-Go, Google Gemini, Anthropic, OpenAI, Z.AI/GLM, and Moonshot/Kimi. Choose a preset to fill the endpoint and protocol automatically. Internal ID, request scope, protocol overrides and JSON template loading are secondary options. OpenRouter has one preset; its Model field suggests `openrouter/free` and named free variants, and also accepts manual IDs. Save before discovering more upstream model IDs.

For **Google Gemini**, create a key at [Google AI Studio](https://aistudio.google.com/apikey), choose the Google Gemini preset, paste the key and save. The default model is `gemini-4-hydrogen`; suggestions also include `gemini-4-neon`, `gemini-4-carbon`, and `gemini-4-argon`. Moon apps and other OpenAI-style clients use Google's `/v1beta/openai` Chat endpoint. The Gemini client uses the native endpoint. Saved providers are not silently migrated: select the updated preset when creating a new setup, or review the protocol and model explicitly when editing. **Refresh models** on the Chat provider discovers account-visible model IDs; suggestions alone do not prove access. Connection tests for Gemini 3/4 allow up to 2,048 output/thinking tokens with low thinking effort so reasoning does not exhaust the old eight-token budget before returning text. A test is an explicit inference request and may consume quota.

Connect that one Google provider to MoonDesk. All four Gemini 4 models then
appear together in MoonDesk's model picker. Choose a model per conversation;
you do not need to replace the provider default or create four providers.
Concurrent chats keep their explicit model IDs. The picker advertises routing
support, not account quota: HTTP 429 requires checking Google's quota/billing,
and HTTP 503/high demand requires trying again when Google has capacity.

MoonDesk also has a **Connect a model** import dialog, currently opened by
**Scan connection QR** in Code assistance/Book tools. It accepts pasted
connection settings as well as QR input. Imported connections pass through
MoonClaw to MoonGate for storage and routing; this is not a full provider
management page. Use MoonGate's Providers page for its full editing controls.

OpenRouter still requires an OpenRouter API key for free models. “Free” means the selected model reports zero token prices; it does not mean anonymous requests are accepted. Free model availability can change, so use **Refresh Built-ins** after upgrading MoonGate, save the provider, and run **Test Provider**.

MoonDesk, MoonClaw, MoonBook and MoonTown share the OpenClaw provider scope. Codex remains a separate app scope. The upstream protocol is independent: a Moon app can use a Codex OAuth or Ark provider through MoonGate's conversion layer. Templates never contain API keys.

Templates fill non-secret configuration fields. API keys stay separate and are stored locally. When editing a provider, MoonGate shows that a credential is stored but never returns the secret value to the UI.

### Requests

Use Requests to inspect individual AI calls. A request may show the provider, model, HTTP result, input and output token counts, reused-input counts, latency, and estimated cost.

Open **Investigation** to keep selected details and notes, save/reopen an
investigation, or choose another review and **Merge saved review into collection**.
Inspect the merge preview and confirm a common request-ID namespace first;
conflicts block replacement. See the [request investigation guide](RETAINED_REQUEST_EXPLORER.md#combine-saved-investigations-without-replacing-current-work).

For a focused handoff, search kept metadata or notes, check **Include in subset**
on the relevant requests, and use **Save subset review JSON**. Hidden checked
requests remain included and are listed in the preview; your full investigation
stays intact. The global summary is excluded unless you opt in. See
[focused subsets](RETAINED_REQUEST_EXPLORER.md#find-observations-and-save-a-focused-subset).

**Copy Developer JSON URL** copies a machine-readable data address for debugging. It does not navigate away from MoonGate.

### Usage

Use Usage to review totals for a time range or AI app. It shows request count, estimated cost, tokens, reused input, daily activity, and breakdowns by app, provider, and model.

### Operations

Use Operations to answer “can MoonGate route this provider request safely?”

1. Review p50/p95/p99 latency, first-token time, in-flight requests, quota state, circuit state, failovers, storage health and evidence freshness. `Not implemented` means the gateway has no real queue; it is not a zero-depth guarantee.
2. Select an app and save a routing policy. This creates only a shadow revision.
3. Click **Observe Shadow Decision**. Review the selected provider and every eligibility reason. Live routing is unchanged.
4. Paste the host-issued `moonsuite.principal-ref.v1` and fresh `moonsuite.authority-decision-ref.v1` JSON references, then activate only after the shadow choice is eligible. MoonGate does not create authority from a typed name. Keep the returned digest-bound receipt.
5. Use **Roll Back** to restore the previous policy; rollback also creates a receipt.
6. **Run Deterministic Fixture** checks fixed local arithmetic. Its results are always labeled fixture-only and do not measure a provider.

The live benchmark API is intentionally absent from the normal UI until a real
adapter and authority verifier exist. Its typed request includes provider,
model, workload, request/token/cost ceilings, deadline and cancellation ID, and
currently returns a fail-closed denied/unavailable result without network I/O.

### Suite

Use **Advanced → Moon Suite** to see published integration support, with MoonDesk first. **Supported** does not mean installed, connected, or recently used. Actual configuration is shown in **Apps**. Overview's observed traffic belongs to the shared Moon apps route, not necessarily MoonDesk alone.

The collapsed advanced section rewrites machine-readable suite files. Most users do not need those actions.

### Guide

The in-app Guide is available from **Advanced → Help**.

**Interface language** is in Advanced, rather than floating over the work area.

Legacy gateway calls for directory picking, opening external URLs, clipboard,
update checking, tray updates and app restart now return HTTP 501. They never
performed those desktop effects. Use the desktop app or system controls; active
AI framework routes are unchanged.

## Phrase guide

| Phrase | Meaning |
| --- | --- |
| AI routing | MoonGate receiving a request from an AI app and sending it to the selected provider. |
| Provider | An AI service or account that answers requests, such as Codex OAuth or Volcengine Ark. |
| App binding | A verified app-configuration change that points an installed app at MoonGate. |
| Verified route | A complete provider → MoonGate → app path with a saved, enabled, tested provider and a verified app binding. |
| Available to MoonGate routing | The provider may receive matching requests after an app is connected. It does not connect an app. |
| Request type | The request format a provider accepts. It does not prove the named app is installed or connected. |
| Model | The specific AI model a provider should run, such as `gpt-5.6-sol` or `kimi-k3`. |
| API key | A secret issued by a provider. MoonGate stores it locally and does not display the saved value again. |
| OAuth | Signing in through an account instead of pasting an API key. |
| Base URL / API address | The network address where an AI app sends requests. MoonGate's local address normally begins with `http://127.0.0.1`. |
| API protocol | The provider's request format: OpenAI Responses, OpenAI Chat, Anthropic Messages, or Gemini Native. |
| Template | A reusable provider setup that fills non-secret fields. The API key is still entered separately. |
| Command-line apps | Installed programs such as Codex, Claude, Gemini, and OpenCode. Older UI text called these “tools.” |
| AI tools | Actions an AI model can call, such as reading a file or using a service. This is different from installed command-line apps. |
| MCP | Model Context Protocol, a way for an AI app to connect to external capabilities such as files or services. It is optional unless an app asks for it. |
| Backup provider | Another provider MoonGate may try when the active provider fails. |
| Automatic backup / failover | Automatically moving a failed request to a backup provider. |
| Pause a failing provider / circuit breaker | An advanced rule that temporarily stops sending requests to a repeatedly failing provider. |
| Streaming | Receiving an AI answer piece by piece instead of waiting for the complete response. |
| Tokens | Small pieces of text counted by AI providers for limits and billing. |
| Reused input / cache hit | Input the provider could reuse instead of processing again, which may reduce time or cost. |
| Monitoring data / Prometheus metrics | Machine-readable numbers for an external monitoring dashboard, not a MoonGate page. |
| Portable storage | An advanced mode that stores MoonGate data beside the app instead of in the normal user-data folder. |
| Suite connection / adapter | Code that lets another Moon app read MoonGate health, provider, or usage information. The UI calls these connections. |

## Provider setup examples

### Codex OAuth

1. Open **Providers**.
2. Choose the **Codex OAuth** template.
3. Use the OAuth sign-in already available to Codex.
4. Save the provider.
5. Run **Test Provider** and confirm completed model output, not just an HTTP status.
6. Open **Apps → List**, choose Codex OAuth for MoonDesk, and click **Connect App**.
7. Click **Verify** and confirm the row says **Connected**.

### Volcengine Ark Agent Plan with Kimi K3

1. Open **Providers**.
2. Choose the Ark Agent Plan preset for Moon apps.
3. Keep the default Moon apps scope; the preset fills the upstream protocol.
4. Enter the Ark API key. Do not put it in a template JSON file.
5. Confirm the default model is `kimi-k3`.
6. Save the provider, then run **Test Provider** and review completed output, model, and latency.
7. Open **Apps → List**, choose the Ark provider for MoonDesk, and connect it. Use **Apps → Manual setup** for MoonBook, MoonTown, or another app without automatic configuration support.

MoonGate supports both the OpenAI-style and Anthropic-style Ark Agent Plan addresses. Choose the template whose API protocol matches the AI app; do not force an Anthropic template through a Codex/OpenAI form or the reverse.
