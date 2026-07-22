# MoonGate UI guide

MoonGate sits between AI apps on your Mac and AI providers. An app sends its request to MoonGate's local address; MoonGate then sends it to the provider you selected. This gives several apps one place for provider setup, routing, request history, and usage.

If you are new to MoonGate, use this order:

1. Open **Providers**, choose a template, enter the provider's API key or sign in with OAuth, run **Test Provider**, and save it.
2. Open **Routing** and make sure the saved provider is **In use** for the AI app you want.
3. Open **Connect** and copy the API address or command-line settings requested by that app.
4. Return to **Overview** to confirm that MoonGate and AI routing are running.
5. After using the app, open **Requests** or **Usage** to verify the traffic.

## What each page is for

### Overview

Use Overview to answer: “Is MoonGate ready?” It shows whether the local MoonGate service and AI routing are running, the provider or model currently reported by the route, request and spend totals, and a readiness checklist.

- **Start Routing** lets AI apps send requests through MoonGate.
- **Stop Routing** stops that request path without closing the UI.
- **View Usage** opens MoonGate's human-readable Usage page. It never opens raw monitoring text.

### Connect

Use Connect only when another AI app asks for a **Base URL**, **API address**, or **environment variables**. Pick the API format named by the app and copy its value.

The **Monitoring data (advanced)** address is for Prometheus or another external monitoring dashboard. It is machine-readable text, not a MoonGate screen, so the UI only copies its URL.

### Setup

Use Setup to check signed-in accounts and whether installed AI apps are ready to use MoonGate.

“Detected command-line apps” means programs such as Codex, Claude, Gemini, and OpenCode installed on the Mac. MoonGate checks them so it knows which configurations it can support. They are not extra MoonGate features and you do not need to install every one.

The extension area covers MCP connections and app plugins. Ignore it unless an app or plugin specifically asks you to configure MCP or an extension.

### Routing

Use Routing to choose which provider each AI app uses.

- **One active** means that app uses one provider at a time.
- **Multiple active** means the app can retain several provider entries.
- **In use** is the provider MoonGate will use now.
- **Import Existing Setup** reads a provider already present in that app's configuration.
- **Save Current Routes** records MoonGate's current choices.

**Backup & failure handling** is advanced and collapsed by default. It can try backup providers automatically and temporarily pause a provider that fails repeatedly. The default settings are appropriate unless automatic recovery is required.

### Providers

Use Providers to add, edit, test, delete, or activate a provider account.

The table shows the current route, credential state, and last known health. **Test Provider** performs a live network request and reports the HTTP status, model, and latency; a locally valid form is not reported as a successful provider test.

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
| Request type / routing profile | The request format and provider group MoonGate will use. It does not prove the named app is connected. |
| Selected route | The provider MoonGate will use if a matching request arrives. A route can also be stopped so no provider is selected. |
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
5. Save the provider and choose **Use This Provider** if it is not already in use.

### Volcengine Ark Agent Plan with Kimi K3

1. Open **Providers**.
2. Choose the Ark Agent Plan template matching the AI app's API protocol.
3. Confirm the framework and protocol selected by the template.
4. Enter the Ark API key. Do not put it in a template JSON file.
5. Confirm the default model is `kimi-k3`.
6. Run **Test Provider**, review its HTTP result, model, and latency, then save it.
7. Choose **Use This Provider** if it is not already the active route.

MoonGate supports both the OpenAI-style and Anthropic-style Ark Agent Plan addresses. Choose the template whose API protocol matches the AI app; do not force an Anthropic template through a Codex/OpenAI form or the reverse.
