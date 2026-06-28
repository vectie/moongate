const endpoints = {
  health: "/health",
  status: "/status",
  proxy: "/proxy/status",
  proxyStart: "/proxy/start",
  proxyStop: "/proxy/stop",
  syncLive: "/proxy/sync-current-providers-live",
  providerCreate: "/providers",
  providerUpdate: "/providers/update",
  providerDelete: "/providers",
  providerStreamCheck: "/proxy/stream-check/provider",
  usageSummary: "/usage/summary",
  usageByApp: "/usage/summary/by-app",
  usageTrends: "/usage/trends",
  providerStats: "/usage/provider-stats",
  modelStats: "/usage/model-stats",
  logs: "/usage/logs?limit=8",
  requestDetail: "/usage/request-detail",
  authStatus: "/auth/status",
  configStatus: "/config/status",
  configFolderOpen: "/config/folder/open",
  claudeDesktopStatus: "/providers/claude-desktop/status",
  claudeDesktopImport: "/providers/claude-desktop/import",
  mcpServers: "/mcp/servers",
  mcpImportApps: "/mcp/import-apps",
  settings: "/settings",
  portableMode: "/runtime/portable-mode",
  toolsVersions: "/tools/versions",
  proxyRunning: "/proxy/running",
  takeoverStatus: "/proxy/takeover-status",
  pluginClaudeStatus: "/plugin/claude/status",
  pluginClaudeApplied: "/plugin/claude/applied",
  circuitConfig: "/proxy/circuit-breaker-config",
  circuitStats: "/proxy/circuit-breaker-stats",
  resetCircuit: "/proxy/reset-circuit-breaker",
  failoverQueue: "/proxy/failover-queue",
  availableFailover: "/proxy/available-failover-providers",
  autoFailover: "/proxy/auto-failover-enabled",
  providerLimits: "/usage/provider-limits",
  streamCheckAll: "/proxy/stream-check/all",
  streamCheckConfig: "/proxy/stream-check/config",
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

async function deleteJson(path, body) {
  const response = await fetch(path, {
    method: "DELETE",
    headers: { Accept: "application/json", "Content-Type": "application/json" },
    body: body == null ? undefined : JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`${path} returned ${response.status}`);
  const textBody = await response.text();
  return textBody ? JSON.parse(textBody) : null;
}

async function safeGetJson(path) {
  try {
    return { ok: true, data: await getJson(path) };
  } catch (error) {
    return { ok: false, error: error && error.message ? error.message : String(error) };
  }
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

function percent(value) {
  return `${(number(value) * 100).toLocaleString(undefined, { maximumFractionDigits: 1 })}%`;
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

function recordCount(value, keys) {
  if (Array.isArray(value)) return value.length;
  if (!value || typeof value !== "object") return 0;
  for (const key of keys || []) {
    if (Array.isArray(value[key])) return value[key].length;
    if (value[key] && typeof value[key] === "object") return Object.keys(value[key]).length;
  }
  return Object.keys(value).length;
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

function stateText(value) {
  if (value == null || value === "") return "Unknown";
  if (typeof value === "boolean") return value ? "Enabled" : "Disabled";
  return String(value);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
