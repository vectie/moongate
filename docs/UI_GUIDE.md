# MoonGate UI guide

MoonGate sits between AI apps on your Mac and AI providers. An app sends its request to MoonGate's local address; MoonGate then sends it to the provider you selected. This gives several apps one place for provider setup, routing, request history, and usage.

If you are new to MoonGate, use this order:

1. Open **Providers**, choose a template, enter the provider's API key or sign in with OAuth, run **Test Provider**, and save it.
2. Open **App Bindings**. MoonGate detects which supported apps are installed.
3. Choose the provider for an installed app and click **Connect App**. MoonGate only shows **Connected** after writing and reading back that app's real configuration.
4. Open **Connection Graph** for the final check. Its route only turns green when the provider is saved, enabled, and tested and the app binding is verified.
5. If an app says **Manual setup**, open **Manual Connect** and enter the shown API address in that app yourself.
6. Return to **Overview**, then use **Requests** or **Usage** to verify real traffic.

## What each page is for

### Overview

Use Overview to answer: “Is MoonGate ready?” It shows whether the local MoonGate service and AI routing are running, the provider or model currently reported by the route, request and spend totals, and a readiness checklist.

- **Start Routing** lets AI apps send requests through MoonGate.
- **Stop Routing** stops that request path without closing the UI.
- **View Usage** opens MoonGate's human-readable Usage page. It never opens raw monitoring text.

### Manual Connect

Use Manual Connect only when App Bindings says **Manual setup**, or when another AI app asks for a **Base URL**, **API address**, or **environment variables**. Pick the API format named by the app and copy its value.

The **Monitoring data (advanced)** address is for Prometheus or another external monitoring dashboard. It is machine-readable text, not a MoonGate screen, so the UI only copies its URL.

### App Bindings

Use App Bindings after configuring a provider. It separates four facts that were previously mixed together:

- **Installed** means MoonGate found the app on this Mac.
- **Not connected** means MoonGate has not verified that the app points to it.
- **Connected** means MoonGate wrote the app configuration and read back the expected local address.
- **Manual setup** means MoonGate does not yet have a safe automatic configuration writer for that app.

MoonDesk, Codex, and Claude Desktop support automatic binding. MoonDesk appears first and consumes the chosen Codex-compatible provider through its MoonClaw runtime. Other detected apps remain manual until MoonGate can safely write and restore their configuration.

“Detected command-line apps” means programs such as Codex, Claude, Gemini, and OpenCode installed on the Mac. MoonGate checks them so it knows which configurations it can support. They are not extra MoonGate features and you do not need to install every one.

The collapsed diagnostics area covers sign-ins, MCP connections, and app plugins. Ignore it unless an app or plugin specifically asks for MCP or an extension.

**Backup & failure handling** is advanced and collapsed by default. It can try backup providers automatically and temporarily pause a provider that fails repeatedly. The default settings are appropriate unless automatic recovery is required.

### Connection Graph

Use Connection Graph after Providers and App Bindings. It shows one lane for every saved provider that can serve each supported app, with MoonDesk first. Each lane separates the evidence MoonGate has:

- **Saved**, **Enabled**, and **Tested** describe the provider. Tested means a real upstream request produced a known health result; an unknown result stays **Not tested**.
- **Selected** means that provider is the current MoonGate route for the request type. It does not mean an app is connected.
- **Installed**, **Bound**, and **Verified** describe the app. Verified is shown only when MoonGate reads the expected local address back from the app configuration.
- **Not wired** means at least one required step is missing. Manual apps remain unwired until they are configured outside MoonGate.

Use **Fix Providers** or **Fix App Bindings** from the graph to return to the missing step, then refresh the graph.

### Providers

Use Providers to add, edit, test, delete, or pause an upstream provider account. It never claims to connect an app.

The table shows credential state, availability, and last known health. **Test Provider** performs a live network request and reports the HTTP status, model, and latency; a locally valid form is not reported as a successful provider test.

Templates fill non-secret configuration fields. API keys stay separate and are stored locally. When editing a provider, MoonGate shows that a credential is stored but never returns the secret value to the UI.

### Requests

Use Requests to inspect individual AI calls. A request may show the provider, model, HTTP result, input and output token counts, reused-input counts, latency, and estimated cost.

**Copy Developer JSON URL** copies a machine-readable data address for debugging. It does not navigate away from MoonGate.

### Usage

Use Usage to review totals for a time range or AI app. It shows request count, estimated cost, tokens, reused input, daily activity, and breakdowns by app, provider, and model.

### Suite

Use Suite to see how the Moon apps connect to MoonGate. MoonDesk is the primary desktop control app and appears first. MoonClaw sends AI requests, MoonBook uses usage summaries for reports, and MoonTown checks health for scheduled work.

The collapsed advanced section rewrites machine-readable suite files. Most users do not need those actions.

### Guide

The in-app Guide contains a shorter copy of this page and is always reachable from the sidebar.

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
4. Run **Test Provider** and confirm a live HTTP result.
5. Save the provider.
6. Open **App Bindings**, choose Codex OAuth for MoonDesk, and click **Connect App**.
7. Click **Verify** and confirm the row says **Connected**.

### Volcengine Ark Agent Plan with Kimi K3

1. Open **Providers**.
2. Choose the Ark Agent Plan template matching the AI app's API protocol.
3. Confirm the framework and protocol selected by the template.
4. Enter the Ark API key. Do not put it in a template JSON file.
5. Confirm the default model is `kimi-k3`.
6. Run **Test Provider**, review its HTTP result, model, and latency, then save it.
7. Open **App Bindings**, choose the Ark provider for MoonDesk, and connect it. MoonDesk is the first supported target for this Codex-compatible route. Use **Manual Connect** if another app requires manual setup.

MoonGate supports both the OpenAI-style and Anthropic-style Ark Agent Plan addresses. Choose the template whose API protocol matches the AI app; do not force an Anthropic template through a Codex/OpenAI form or the reverse.
