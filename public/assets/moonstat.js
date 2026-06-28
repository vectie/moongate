const endpoints = {
  health: "/health",
  status: "/status",
  proxy: "/proxy/status",
  usageSummary: "/usage/summary",
  usageByApp: "/usage/summary/by-app",
  modelStats: "/usage/model-stats",
  logs: "/usage/logs?limit=8",
};

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

refresh().catch(showError);
setInterval(() => refresh().catch(showError), 30000);
