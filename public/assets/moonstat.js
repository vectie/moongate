const endpoints = {
  health: "/health",
  status: "/status",
  proxy: "/proxy/status",
  proxyStart: "/proxy/start",
  proxyStop: "/proxy/stop",
  syncLive: "/proxy/sync-current-providers-live",
  usageSummary: "/usage/summary",
  usageByApp: "/usage/summary/by-app",
  modelStats: "/usage/model-stats",
  logs: "/usage/logs?limit=8",
};

const frameworkApps = [
  { id: "claude", label: "Claude Code", mode: "single" },
  { id: "claude-desktop", label: "Claude Desktop", mode: "single", desktop: true },
  { id: "codex", label: "Codex", mode: "single" },
  { id: "gemini", label: "Gemini", mode: "single" },
  { id: "opencode", label: "OpenCode", mode: "additive" },
  { id: "openclaw", label: "OpenClaw", mode: "additive" },
  { id: "hermes", label: "Hermes", mode: "additive" },
];

const $ = (id) => document.getElementById(id);

function text(id, value) {
  const node = $(id);
  if (node) node.textContent = value == null || value === "" ? "-" : String(value);
}

async function getJson(path) {
  const response = await fetch(path, { headers: { Accept: "application/json" } });
  if (!response.ok) throw new Error(`${path} returned ${response.status}`);
  return response.json();
}

async function postJson(path, body) {
  const response = await fetch(path, {
    method: "POST",
    headers: { Accept: "application/json", "Content-Type": "application/json" },
    body: body == null ? undefined : JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`${path} returned ${response.status}`);
  const textBody = await response.text();
  return textBody ? JSON.parse(textBody) : null;
}

function endpoint(path, params) {
  const url = new URL(path, window.location.origin);
  for (const [key, value] of Object.entries(params || {})) {
    if (value != null && value !== "") url.searchParams.set(key, String(value));
  }
  return `${url.pathname}${url.search}`;
}

function number(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return 0;
}

function money(value) {
  return `$${number(value).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 4,
  })}`;
}

function compact(value) {
  return number(value).toLocaleString(undefined, { maximumFractionDigits: 1 });
}

function arrayFrom(value, keys) {
  if (Array.isArray(value)) return value;
  if (!value || typeof value !== "object") return [];
  for (const key of keys) {
    if (Array.isArray(value[key])) return value[key];
  }
  return [];
}

function objectRows(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return [];
  return Object.entries(value).map(([id, row]) => ({
    id,
    ...(row && typeof row === "object" ? row : {}),
  }));
}

function firstString(object, keys, fallback = "-") {
  if (!object || typeof object !== "object") return fallback;
  for (const key of keys) {
    const value = object[key];
    if (typeof value === "string" && value.trim() !== "") return value;
    if (typeof value === "number" || typeof value === "boolean") return String(value);
  }
  return fallback;
}

function stateClass(value) {
  const lower = String(value || "").toLowerCase();
  if (lower.includes("healthy") || lower.includes("running") || lower === "ok" || lower === "true") {
    return "state good";
  }
  if (lower.includes("open") || lower.includes("error") || lower.includes("failed") || lower === "false") {
    return "state bad";
  }
  return "state warn";
}

function renderProviderRows(data) {
  const rows = arrayFrom(data, ["providers", "items", "data", "health"]);
  text("provider-count", `${rows.length} provider${rows.length === 1 ? "" : "s"}`);
  const target = $("provider-rows");
  if (!target) return;
  target.innerHTML = "";
  if (rows.length === 0) {
    target.innerHTML = `<tr><td colspan="5">No provider health data yet.</td></tr>`;
    return;
  }
  for (const row of rows.slice(0, 12)) {
    const provider = firstString(row, ["providerName", "name", "providerId", "id"]);
    const app = firstString(row, ["appType", "app", "type"]);
    const status = firstString(row, ["status", "state", "health", "isHealthy"]);
    const model = firstString(row, ["model", "modelId", "activeModel", "routeModel"]);
    const error = firstString(row, ["lastError", "error", "message"], "");
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><strong>${escapeHtml(provider)}</strong></td>
      <td>${escapeHtml(app)}</td>
      <td><span class="${stateClass(status)}">${escapeHtml(status)}</span></td>
      <td>${escapeHtml(model)}</td>
      <td>${escapeHtml(error || "-")}</td>
    `;
    target.appendChild(tr);
  }
}

function renderFrameworkRows(rows) {
  const target = $("framework-rows");
  if (!target) return;
  target.innerHTML = "";
  for (const row of rows) {
    const providers = row.providers || [];
    const providerCount = providers.length;
    const current = row.current || "";
    const mode = row.mode === "additive" ? "Additive" : "Single";
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><strong>${escapeHtml(row.label)}</strong><small>${escapeHtml(row.id)}</small></td>
      <td><span class="state ${row.error ? "bad" : "good"}">${escapeHtml(row.error ? "Error" : mode)}</span></td>
      <td>${renderCurrentProvider(row, providers, current)}</td>
      <td>${providerCount} configured</td>
      <td>${renderFrameworkActions(row, providerCount)}</td>
    `;
    target.appendChild(tr);
  }
}

function renderCurrentProvider(row, providers, current) {
  if (row.error) return `<small>${escapeHtml(row.error)}</small>`;
  if (row.mode === "additive") return `<small>Multiple live providers</small>`;
  if (providers.length === 0) return `<small>No providers</small>`;
  const options = providers
    .map((provider) => {
      const id = firstString(provider, ["id", "providerId"]);
      const name = firstString(provider, ["name", "providerName"], id);
      const selected = id === current ? " selected" : "";
      return `<option value="${escapeHtml(id)}"${selected}>${escapeHtml(name)}</option>`;
    })
    .join("");
  return `<select data-app="${escapeHtml(row.id)}" aria-label="${escapeHtml(row.label)} provider">${options}</select>`;
}

function renderFrameworkActions(row, providerCount) {
  if (row.error) return `<button type="button" data-action="reload-app" data-app="${escapeHtml(row.id)}">Retry</button>`;
  const actions = [
    `<button type="button" data-action="import-live" data-app="${escapeHtml(row.id)}">Import Live</button>`,
  ];
  if (row.mode !== "additive" && providerCount > 0) {
    actions.unshift(`<button type="button" data-action="switch-provider" data-app="${escapeHtml(row.id)}">Switch</button>`);
  }
  if (row.desktop) {
    actions.push(`<button type="button" data-action="claude-desktop-import">Import Claude</button>`);
  }
  return `<div class="inline-actions">${actions.join("")}</div>`;
}

function renderStack(id, rows, labelKeys) {
  const target = $(id);
  if (!target) return;
  target.innerHTML = "";
  if (rows.length === 0) {
    target.innerHTML = `<div class="row-card"><strong>No data yet</strong><small>Use moonstat through the proxy to populate this panel.</small></div>`;
    return;
  }
  for (const row of rows.slice(0, 8)) {
    const name = firstString(row, labelKeys);
    const requests = number(row.requests ?? row.requestCount ?? row.totalRequests ?? row.count);
    const cost = row.costUsd ?? row.totalCostUsd ?? row.totalCost ?? row.cost ?? 0;
    const div = document.createElement("div");
    div.className = "row-card";
    div.innerHTML = `
      <div>
        <strong>${escapeHtml(name)}</strong>
        <small>${compact(requests)} requests</small>
      </div>
      <strong>${money(cost)}</strong>
    `;
    target.appendChild(div);
  }
}

function renderLogs(data) {
  const rows = arrayFrom(data, ["logs", "items", "requests", "data"]);
  const target = $("request-log");
  if (!target) return;
  target.innerHTML = "";
  if (rows.length === 0) {
    target.innerHTML = `<div class="log-item"><strong>No recent requests</strong><small>Requests will appear here after proxy traffic.</small></div>`;
    return;
  }
  for (const row of rows.slice(0, 8)) {
    const route = firstString(row, ["path", "route", "endpoint", "requestPath"]);
    const provider = firstString(row, ["providerName", "providerId", "provider"], "");
    const model = firstString(row, ["model", "modelId"], "");
    const status = firstString(row, ["statusCode", "status", "code"]);
    const div = document.createElement("div");
    div.className = "log-item";
    div.innerHTML = `
      <strong>${escapeHtml(route)}</strong>
      <small>${escapeHtml([provider, model, status].filter(Boolean).join(" | "))}</small>
    `;
    target.appendChild(div);
  }
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function updateTotals(summary, stats) {
  const totalRequests =
    summary.totalRequests ?? summary.requests ?? summary.requestCount ?? stats.total_requests ?? stats.totalRequests ?? 0;
  const totalCost =
    summary.totalCostUsd ?? summary.costUsd ?? summary.totalCost ?? stats.totalCostUsd ?? stats.costUsd ?? 0;
  text("request-total", compact(totalRequests));
  text("cost-total", money(totalCost));
}

async function loadFrameworkRow(app) {
  try {
    const [providersJson, currentJson] = await Promise.all([
      getJson(endpoint("/providers", { appType: app.id })),
      getJson(endpoint("/providers/current", { appType: app.id })),
    ]);
    return {
      ...app,
      providers: objectRows(providersJson),
      current: typeof currentJson === "string" ? currentJson : "",
    };
  } catch (error) {
    return { ...app, providers: [], current: "", error: error.message || String(error) };
  }
}

async function loadFrameworks() {
  const rows = await Promise.all(frameworkApps.map(loadFrameworkRow));
  renderFrameworkRows(rows);
}

async function refresh() {
  $("error-box").hidden = true;
  const [health, status, proxy, summary, byApp, modelStats, logs] =
    await Promise.all([
      getJson(endpoints.health),
      getJson(endpoints.status),
      getJson(endpoints.proxy),
      getJson(endpoints.usageSummary),
      getJson(endpoints.usageByApp),
      getJson(endpoints.modelStats),
      getJson(endpoints.logs),
    ]);

  const gatewayState = firstString(health, ["status", "state", "ok"]);
  text("gateway-state", gatewayState);
  text("gateway-detail", firstString(status, ["address", "baseUrl", "url"], "Local API ready"));

  const proxyState = firstString(proxy, ["status", "state", "running", "enabled"]);
  text("proxy-state", proxyState);
  text("proxy-detail", firstString(proxy, ["model", "activeModel", "provider"], "Proxy route status"));

  updateTotals(summary, status);
  renderProviderRows(status.provider_routes || status.active_targets || []);
  await loadFrameworks();
  renderStack("app-usage", arrayFrom(byApp, ["apps", "items", "data"]), ["appType", "app", "name"]);
  renderStack("model-usage", arrayFrom(modelStats, ["models", "items", "data"]), ["model", "modelId", "name"]);
  renderLogs(logs);
  text("ui-updated", `Updated ${new Date().toLocaleTimeString()}`);
}

function showError(error) {
  const box = $("error-box");
  const message = $("error-message");
  if (message) message.textContent = error && error.message ? error.message : String(error);
  if (box) box.hidden = false;
  text("ui-updated", "Refresh failed");
}

$("refresh")?.addEventListener("click", () => {
  refresh().catch(showError);
});

$("proxy-start")?.addEventListener("click", () => {
  postJson(endpoints.proxyStart).then(refresh).catch(showError);
});

$("proxy-stop")?.addEventListener("click", () => {
  postJson(endpoints.proxyStop).then(refresh).catch(showError);
});

$("sync-live")?.addEventListener("click", () => {
  postJson(endpoints.syncLive).then(refresh).catch(showError);
});

$("framework-rows")?.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-action]");
  if (!button) return;
  const appType = button.dataset.app;
  const action = button.dataset.action;
  if (action === "reload-app") {
    refresh().catch(showError);
  } else if (action === "switch-provider") {
    const select = Array.from(document.querySelectorAll("select[data-app]"))
      .find((node) => node.dataset.app === appType);
    if (select) postJson("/providers/switch", { appType, id: select.value }).then(refresh).catch(showError);
  } else if (action === "import-live") {
    postJson(endpoint("/providers/import-live", { appType })).then(refresh).catch(showError);
  } else if (action === "claude-desktop-import") {
    postJson("/providers/claude-desktop/import").then(refresh).catch(showError);
  }
});

refresh().catch(showError);
setInterval(() => refresh().catch(showError), 30000);
