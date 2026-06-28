let frameworkRows = [];

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
  frameworkRows = rows;
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
      <td>${renderProviderPicker(row, providers)}</td>
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

function renderProviderPicker(row, providers) {
  if (row.error) return `<small>Unavailable</small>`;
  if (providers.length === 0) return `<small>No providers configured</small>`;
  const options = providers
    .map((provider) => {
      const id = firstString(provider, ["id", "providerId"]);
      const name = firstString(provider, ["name", "providerName"], id);
      return `<option value="${escapeHtml(id)}">${escapeHtml(name)}</option>`;
    })
    .join("");
  return `
    <div class="provider-picker">
      <select data-provider-picker="${escapeHtml(row.id)}" aria-label="${escapeHtml(row.label)} configured providers">${options}</select>
      <small>${providers.length} configured</small>
    </div>
  `;
}

function renderFrameworkActions(row, providerCount) {
  if (row.error) return `<button type="button" data-action="reload-app" data-app="${escapeHtml(row.id)}">Retry</button>`;
  const actions = [
    `<button type="button" data-action="edit-provider" data-app="${escapeHtml(row.id)}">Edit</button>`,
    `<button type="button" data-action="test-provider" data-app="${escapeHtml(row.id)}">Test</button>`,
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

function initProviderAppSelect() {
  const select = $("provider-app");
  if (!select) return;
  select.innerHTML = frameworkApps
    .map((app) => `<option value="${escapeHtml(app.id)}">${escapeHtml(app.label)}</option>`)
    .join("");
}

function initUsageAppSelect() {
  const select = $("usage-app");
  if (!select) return;
  select.innerHTML = [
    `<option value="">All frameworks</option>`,
    ...frameworkApps.map((app) => `<option value="${escapeHtml(app.id)}">${escapeHtml(app.label)}</option>`),
  ].join("");
}

function initResilienceAppSelect() {
  const select = $("resilience-app");
  if (!select) return;
  select.innerHTML = frameworkApps
    .map((app) => `<option value="${escapeHtml(app.id)}">${escapeHtml(app.label)}</option>`)
    .join("");
  select.value = "codex";
}

function providerRow(appType) {
  return frameworkRows.find((row) => row.id === appType);
}

function selectedProviderId(appType) {
  const picker = document.querySelector(`[data-provider-picker="${appType}"]`);
  if (picker && picker.value) return picker.value;
  const current = document.querySelector(`select[data-app="${appType}"]`);
  if (current && current.value) return current.value;
  return "";
}

function providerById(appType, providerId) {
  const row = providerRow(appType);
  if (!row) return null;
  return (row.providers || []).find((provider) => {
    return firstString(provider, ["id", "providerId"], "") === providerId;
  }) || null;
}

function setProviderStatus(value) {
  text("provider-form-status", value);
}

function clearProviderForm(appType) {
  text("provider-original-id", "");
  $("provider-original-id").value = "";
  $("provider-app").value = appType || $("provider-app").value || "claude";
  $("provider-id").value = "";
  $("provider-name").value = "";
  $("provider-type").value = "";
  $("provider-base-url").value = "";
  $("provider-api-format").value = "";
  $("provider-api-key").value = "";
  $("provider-default-model").value = "";
  $("provider-sonnet-model").value = "";
  $("provider-haiku-model").value = "";
  $("provider-opus-model").value = "";
  $("provider-notes").value = "";
  $("provider-enabled").checked = true;
  $("provider-full-url").checked = false;
  $("provider-fast-mode").checked = false;
  setProviderStatus("New provider");
}

function editProvider(appType, providerId) {
  const provider = providerById(appType, providerId);
  if (!provider) {
    clearProviderForm(appType);
    setProviderStatus("Provider not found in current view");
    return;
  }
  $("provider-original-id").value = providerId;
  $("provider-app").value = appType;
  $("provider-id").value = providerId;
  $("provider-name").value = firstString(provider, ["name", "providerName"], providerId);
  $("provider-type").value = firstString(provider, ["category", "providerType"], "");
  $("provider-base-url").value = firstString(provider, ["websiteUrl", "baseUrl"], "");
  $("provider-api-format").value = firstString(provider.settingsConfig, ["apiFormat"], "");
  $("provider-api-key").value = "";
  $("provider-default-model").value = "";
  $("provider-sonnet-model").value = "";
  $("provider-haiku-model").value = "";
  $("provider-opus-model").value = "";
  $("provider-notes").value = firstString(provider, ["notes"], "");
  $("provider-enabled").checked = provider.enabled !== false;
  $("provider-full-url").checked = provider.isFullUrl === true;
  $("provider-fast-mode").checked = provider.settingsConfig?.codexFastMode === true;
  setProviderStatus(`Editing ${providerId}`);
}

function modelMappingFromForm() {
  const mapping = {};
  const fields = [
    ["defaultModel", "provider-default-model"],
    ["sonnetModel", "provider-sonnet-model"],
    ["haikuModel", "provider-haiku-model"],
    ["opusModel", "provider-opus-model"],
  ];
  for (const [key, id] of fields) {
    const value = $(id).value.trim();
    if (value) mapping[key] = value;
  }
  return Object.keys(mapping).length === 0 ? null : mapping;
}

function providerPayloadFromForm() {
  const payload = {
    appType: $("provider-app").value,
    id: $("provider-id").value.trim(),
    name: $("provider-name").value.trim(),
    enabled: $("provider-enabled").checked,
    isFullUrl: $("provider-full-url").checked,
    codexFastMode: $("provider-fast-mode").checked,
  };
  for (const [key, id] of [
    ["providerType", "provider-type"],
    ["baseUrl", "provider-base-url"],
    ["apiFormat", "provider-api-format"],
    ["apiKey", "provider-api-key"],
    ["notes", "provider-notes"],
  ]) {
    const value = $(id).value.trim();
    if (value) payload[key] = value;
  }
  const mapping = modelMappingFromForm();
  if (mapping) payload.modelMapping = mapping;
  return payload;
}

async function saveProvider() {
  const payload = providerPayloadFromForm();
  if (!payload.id || !payload.name) {
    setProviderStatus("Provider ID and name are required");
    return;
  }
  const originalId = $("provider-original-id").value.trim();
  if (originalId) {
    payload.originalId = originalId;
    await postJson(endpoints.providerUpdate, payload);
    setProviderStatus(`Updated ${payload.id}`);
  } else {
    await postJson(endpoints.providerCreate, payload);
    setProviderStatus(`Created ${payload.id}`);
  }
  await refresh();
  editProvider(payload.appType, payload.id);
}

async function deleteProviderFromForm() {
  const appType = $("provider-app").value;
  const providerId = $("provider-id").value.trim();
  if (!providerId) {
    setProviderStatus("Select a provider before deleting");
    return;
  }
  if (!window.confirm(`Delete provider ${providerId} from ${appType}?`)) return;
  await deleteJson(endpoints.providerDelete, { appType, id: providerId });
  clearProviderForm(appType);
  setProviderStatus(`Deleted ${providerId}`);
  await refresh();
}

async function testProviderFromForm() {
  const appType = $("provider-app").value;
  const providerId = $("provider-id").value.trim();
  if (!providerId) {
    setProviderStatus("Select a provider before testing");
    return;
  }
  const result = await postJson(endpoints.providerStreamCheck, { appType, providerId });
  setProviderStatus(firstString(result, ["message", "status"], "Provider test completed"));
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

function usageQueryParams(extra) {
  const appType = $("usage-app")?.value || "";
  const range = $("usage-range")?.value || "604800";
  const params = { ...(extra || {}) };
  if (appType) params.appType = appType;
  if (range !== "all") {
    const endDate = Math.floor(Date.now() / 1000);
    params.endDate = endDate;
    params.startDate = endDate - Number(range);
  }
  return params;
}

function trendLabel(value) {
  if (!value) return "-";
  const date = new Date(String(value));
  if (Number.isNaN(date.getTime())) return String(value).slice(0, 10);
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function renderTrends(rows) {
  const target = $("usage-trends");
  if (!target) return;
  target.innerHTML = "";
  if (rows.length === 0) {
    target.innerHTML = `<div class="trend-bar"><span style="height:10px"></span><small>No data</small></div>`;
    return;
  }
  const maxTokens = Math.max(1, ...rows.map((row) => number(row.totalTokens ?? row.tokens ?? row.requestCount)));
  for (const row of rows.slice(-36)) {
    const tokens = number(row.totalTokens ?? row.tokens ?? row.requestCount);
    const height = Math.max(10, Math.round((tokens / maxTokens) * 118));
    const label = trendLabel(row.date ?? row.timestamp ?? row.bucket);
    const bar = document.createElement("div");
    bar.className = "trend-bar";
    bar.title = `${label}: ${compact(tokens)} tokens`;
    bar.innerHTML = `<span style="height:${height}px"></span><small>${escapeHtml(label)}</small>`;
    target.appendChild(bar);
  }
}

function renderRequestDetail(detail) {
  const target = $("request-detail");
  if (!target) return;
  if (!detail || typeof detail !== "object") {
    text("request-detail-id", "No selection");
    target.innerHTML = `<div><span>Status</span><strong>No request selected</strong></div>`;
    return;
  }
  text("request-detail-id", firstString(detail, ["requestId"], "Request"));
  const fields = [
    ["App", firstString(detail, ["appType"])],
    ["Provider", firstString(detail, ["providerName", "providerId"])],
    ["Model", firstString(detail, ["model", "requestModel"])],
    ["Pricing", firstString(detail, ["pricingModel"], "")],
    ["Status", firstString(detail, ["statusCode"])],
    ["Cost", money(detail.totalCostUsd ?? detail.totalCost ?? 0)],
    ["Input", compact(detail.inputTokens)],
    ["Output", compact(detail.outputTokens)],
    ["Cache Read", compact(detail.cacheReadTokens)],
    ["Cache Write", compact(detail.cacheCreationTokens)],
    ["Latency", `${compact(detail.latencyMs)} ms`],
    ["Streaming", firstString(detail, ["isStreaming"])],
  ];
  target.innerHTML = fields
    .map(([label, value]) => `<div><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></div>`)
    .join("");
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
  for (const row of rows.slice(0, 12)) {
    const route = firstString(row, ["path", "route", "endpoint", "requestPath"]);
    const requestId = firstString(row, ["requestId", "id"], "");
    const provider = firstString(row, ["providerName", "providerId", "provider"], "");
    const model = firstString(row, ["model", "modelId"], "");
    const status = firstString(row, ["statusCode", "status", "code"]);
    const div = document.createElement("div");
    div.className = "log-item";
    div.innerHTML = `
      <strong>${escapeHtml(route)}</strong>
      <small>${escapeHtml([provider, model, status].filter(Boolean).join(" | "))}</small>
      ${requestId ? `<button type="button" data-request-id="${escapeHtml(requestId)}">Details</button>` : ""}
    `;
    target.appendChild(div);
  }
}

function firstValue(object, keys) {
  if (!object || typeof object !== "object") return null;
  for (const key of keys) {
    if (object[key] != null) return object[key];
  }
  return null;
}

function setupProbeText(probe, keys, fallback) {
  if (!probe.ok) return probe.error;
  const value = firstValue(probe.data, keys);
  if (value == null) return fallback || "Available";
  return stateText(value);
}

function setupProbeGood(probe, keys) {
  if (!probe.ok) return false;
  const value = firstValue(probe.data, keys);
  if (value == null) return keys.length === 0;
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value > 0;
  if (typeof value === "string") {
    const lower = value.toLowerCase();
    return lower.includes("ok") || lower.includes("ready") || lower.includes("true") || lower.includes("authenticated");
  }
  return true;
}

function setSetupState(id, value, good) {
  const node = $(id);
  if (!node) return;
  node.textContent = value;
  node.className = `state ${good ? "good" : "warn"}`;
}

function renderSetupList(id, rows) {
  const target = $(id);
  if (!target) return;
  target.innerHTML = rows
    .map(([label, value, good]) => {
      return `
        <div class="setup-row">
          <span>${escapeHtml(label)}</span>
          <strong class="${stateClass(good ? "ok" : value)}">${escapeHtml(value)}</strong>
        </div>
      `;
    })
    .join("");
}

function configStatusText(probe) {
  if (!probe.ok) return probe.error;
  return firstString(probe.data, ["status", "state"], setupProbeText(probe, ["configured", "exists", "available"], "Available"));
}

function renderSetupConfigRows(configRows, takeoverProbe) {
  const target = $("setup-config-rows");
  if (!target) return;
  target.innerHTML = "";
  for (const row of configRows) {
    const takeover = takeoverProbe.ok ? takeoverProbe.data?.[row.app.id] : null;
    const configText = configStatusText(row.probe);
    const takeoverText = takeover == null ? "Unknown" : stateText(takeover);
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><strong>${escapeHtml(row.app.label)}</strong><small>${escapeHtml(row.app.id)}</small></td>
      <td><span class="${stateClass(row.probe.ok ? configText : "error")}">${escapeHtml(configText)}</span></td>
      <td><span class="${stateClass(takeoverText)}">${escapeHtml(takeoverText)}</span></td>
      <td><button type="button" data-setup-action="open-config" data-app="${escapeHtml(row.app.id)}">Open Config</button></td>
    `;
    target.appendChild(tr);
  }
}

function selectedResilienceApp() {
  return $("resilience-app")?.value || "codex";
}

function selectedResilienceProvider() {
  return $("resilience-provider")?.value || "";
}

function setInputValue(id, value) {
  const node = $(id);
  if (node) node.value = value == null ? "" : String(value);
}

function fillCircuitForm(config) {
  if (!config || typeof config !== "object") return;
  setInputValue("circuit-failure-threshold", config.failureThreshold);
  setInputValue("circuit-success-threshold", config.successThreshold);
  setInputValue("circuit-timeout-seconds", config.timeoutSeconds);
  setInputValue("circuit-error-rate-threshold", config.errorRateThreshold);
  setInputValue("circuit-min-requests", config.minRequests);
}

function fillStreamForm(config) {
  if (!config || typeof config !== "object") return;
  setInputValue("stream-timeout-secs", config.timeoutSecs);
  setInputValue("stream-max-retries", config.maxRetries);
  setInputValue("stream-degraded-threshold-ms", config.degradedThresholdMs);
  setInputValue("stream-codex-model", config.codexModel);
  setInputValue("stream-claude-model", config.claudeModel);
  setInputValue("stream-gemini-model", config.geminiModel);
  setInputValue("stream-test-prompt", config.testPrompt);
}

function compactProviderLabel(provider) {
  const id = firstString(provider, ["providerId", "id"], "");
  const name = firstString(provider, ["providerName", "name"], id);
  return { id, name };
}

function renderResilienceProviders(providers) {
  const select = $("resilience-provider");
  if (!select) return "";
  const previous = select.value;
  const options = providers.map((provider) => {
    const { id, name } = compactProviderLabel(provider);
    return `<option value="${escapeHtml(id)}">${escapeHtml(name)}</option>`;
  });
  select.innerHTML = options.length ? options.join("") : `<option value="">No providers</option>`;
  if (providers.some((provider) => compactProviderLabel(provider).id === previous)) {
    select.value = previous;
  }
  return select.value;
}

function renderProviderActionStack(id, rows, emptyText, action) {
  const target = $(id);
  if (!target) return;
  target.innerHTML = "";
  if (rows.length === 0) {
    target.innerHTML = `<div class="row-card"><strong>${escapeHtml(emptyText)}</strong><small>No provider action available.</small></div>`;
    return;
  }
  for (const row of rows.slice(0, 10)) {
    const { id: providerId, name } = compactProviderLabel(row);
    const div = document.createElement("div");
    div.className = "row-card";
    div.innerHTML = `
      <div>
        <strong>${escapeHtml(name)}</strong>
        <small>${escapeHtml(providerId)}</small>
      </div>
      <button type="button" data-resilience-action="${escapeHtml(action)}" data-provider-id="${escapeHtml(providerId)}">
        ${action === "remove-failover" ? "Remove" : "Add"}
      </button>
    `;
    target.appendChild(div);
  }
}

function renderStreamCheckResults(rows) {
  const target = $("stream-check-results");
  if (!target) return;
  target.innerHTML = "";
  if (rows.length === 0) {
    target.innerHTML = `<div class="log-item"><strong>No stream-check results</strong><small>Run Check App to probe configured providers.</small></div>`;
    return;
  }
  for (const row of rows) {
    const providerId = Array.isArray(row) ? row[0] : firstString(row, ["providerId", "id"]);
    const result = Array.isArray(row) ? row[1] : row;
    const status = firstString(result, ["status", "message"], "unknown");
    const model = firstString(result, ["modelUsed", "model"], "");
    const responseTime = firstString(result, ["responseTimeMs"], "");
    const div = document.createElement("div");
    div.className = "log-item";
    div.innerHTML = `
      <strong>${escapeHtml(providerId)}</strong>
      <small>${escapeHtml([status, model, responseTime ? `${responseTime} ms` : ""].filter(Boolean).join(" | "))}</small>
    `;
    target.appendChild(div);
  }
}

function circuitConfigPayload() {
  return {
    failureThreshold: number($("circuit-failure-threshold")?.value),
    successThreshold: number($("circuit-success-threshold")?.value),
    timeoutSeconds: number($("circuit-timeout-seconds")?.value),
    errorRateThreshold: number($("circuit-error-rate-threshold")?.value),
    minRequests: number($("circuit-min-requests")?.value),
  };
}

function streamConfigPayload() {
  return {
    timeoutSecs: number($("stream-timeout-secs")?.value),
    maxRetries: number($("stream-max-retries")?.value),
    degradedThresholdMs: number($("stream-degraded-threshold-ms")?.value),
    codexModel: $("stream-codex-model")?.value || "",
    claudeModel: $("stream-claude-model")?.value || "",
    geminiModel: $("stream-gemini-model")?.value || "",
    testPrompt: $("stream-test-prompt")?.value || "",
  };
}

async function loadResilience() {
  const appType = selectedResilienceApp();
  const providersProbe = await safeGetJson(endpoint(endpoints.providerCreate, { appType }));
  const providers = providersProbe.ok ? objectRows(providersProbe.data) : [];
  const providerId = renderResilienceProviders(providers);
  const providerParams = providerId ? { appType, providerId } : null;
  const [
    circuitConfig,
    streamConfig,
    autoFailover,
    queue,
    available,
    circuitStats,
    limits,
  ] = await Promise.all([
    safeGetJson(endpoints.circuitConfig),
    safeGetJson(endpoints.streamCheckConfig),
    safeGetJson(endpoint(endpoints.autoFailover, { appType })),
    safeGetJson(endpoint(endpoints.failoverQueue, { appType })),
    safeGetJson(endpoint(endpoints.availableFailover, { appType })),
    providerParams ? safeGetJson(endpoint(endpoints.circuitStats, providerParams)) : { ok: false, error: "No provider selected" },
    providerParams ? safeGetJson(endpoint(endpoints.providerLimits, providerParams)) : { ok: false, error: "No provider selected" },
  ]);

  if (circuitConfig.ok) fillCircuitForm(circuitConfig.data);
  if (streamConfig.ok) fillStreamForm(streamConfig.data);
  const queueRows = queue.ok ? arrayFrom(queue.data, []) : [];
  const availableRows = available.ok ? arrayFrom(available.data, []) : [];
  const autoState = autoFailover.ok ? stateText(autoFailover.data) : autoFailover.error;
  const circuitState = circuitStats.ok && circuitStats.data ? firstString(circuitStats.data, ["state"], "closed") : "Unknown";
  const limitText = limits.ok ? firstString(limits.data, ["status", "state"], "Loaded") : "Unknown";

  text("resilience-auto-state", autoState);
  text("resilience-circuit-state", circuitState);
  text("resilience-queue-count", compact(queueRows.length));
  text("resilience-limit-state", limitText);
  setSetupState("resilience-circuit-status", circuitConfig.ok ? "Configured" : "Unavailable", circuitConfig.ok);
  setSetupState("resilience-stream-status", streamConfig.ok ? "Configured" : "Unavailable", streamConfig.ok);
  renderProviderActionStack("failover-queue", queueRows, "Failover queue is empty", "remove-failover");
  renderProviderActionStack("available-failover", availableRows, "No available providers", "add-failover");
}

async function loadSetupStatus() {
  const authProviders = [
    ["Codex OAuth", "codex_oauth"],
    ["GitHub Copilot", "github_copilot"],
  ];
  const [
    runtimeProbe,
    toolsProbe,
    proxyRunningProbe,
    takeoverProbe,
    desktopProbe,
    mcpProbe,
    pluginProbe,
    pluginAppliedProbe,
    settingsProbe,
    authRows,
    configRows,
  ] = await Promise.all([
    safeGetJson(endpoints.portableMode),
    safeGetJson(endpoint(endpoints.toolsVersions, { tools: "codex,claude,gemini,opencode" })),
    safeGetJson(endpoints.proxyRunning),
    safeGetJson(endpoints.takeoverStatus),
    safeGetJson(endpoints.claudeDesktopStatus),
    safeGetJson(endpoints.mcpServers),
    safeGetJson(endpoints.pluginClaudeStatus),
    safeGetJson(endpoints.pluginClaudeApplied),
    safeGetJson(endpoints.settings),
    Promise.all(
      authProviders.map(async ([label, provider]) => ({
        label,
        probe: await safeGetJson(endpoint(endpoints.authStatus, { authProvider: provider })),
      })),
    ),
    Promise.all(
      frameworkApps.map(async (app) => ({
        app,
        probe: await safeGetJson(endpoint(endpoints.configStatus, { appType: app.id })),
      })),
    ),
  ]);

  const authenticated = authRows.filter((row) => setupProbeGood(row.probe, ["authenticated", "hasAccount", "loggedIn"])).length;
  setSetupState("setup-auth-state", authenticated > 0 ? `${authenticated} active` : "Ready", authRows.some((row) => row.probe.ok));
  renderSetupList(
    "setup-auth-rows",
    authRows.map((row) => [
      row.label,
      setupProbeText(row.probe, ["authenticated", "hasAccount", "loggedIn", "status"], "No account"),
      setupProbeGood(row.probe, ["authenticated", "hasAccount", "loggedIn", "status"]),
    ]),
  );

  const proxyRunning = proxyRunningProbe.ok ? proxyRunningProbe.data === true : false;
  setSetupState("setup-runtime-state", proxyRunning ? "Proxy on" : "Available", runtimeProbe.ok || proxyRunningProbe.ok);
  renderSetupList("setup-runtime-rows", [
    ["Portable Mode", setupProbeText(runtimeProbe, [], runtimeProbe.ok ? stateText(runtimeProbe.data) : "Unavailable"), runtimeProbe.ok],
    ["Proxy Running", proxyRunningProbe.ok ? stateText(proxyRunningProbe.data) : proxyRunningProbe.error, proxyRunning],
    ["Tool Versions", toolsProbe.ok ? `${recordCount(toolsProbe.data, ["tools", "versions"])} tools` : toolsProbe.error, toolsProbe.ok],
    ["Settings", settingsProbe.ok ? "Loaded" : settingsProbe.error, settingsProbe.ok],
  ]);

  const desktopConfigured = setupProbeGood(desktopProbe, ["configured", "gatewayTokenConfigured"]);
  setSetupState("setup-desktop-state", desktopConfigured ? "Configured" : "Available", desktopProbe.ok);
  renderSetupList("setup-desktop-rows", [
    ["Configured", setupProbeText(desktopProbe, ["configured"], "Unknown"), desktopConfigured],
    ["Mode", setupProbeText(desktopProbe, ["mode"], "Not selected"), desktopProbe.ok],
    ["Gateway Token", setupProbeText(desktopProbe, ["gatewayTokenConfigured"], "Unknown"), setupProbeGood(desktopProbe, ["gatewayTokenConfigured"])],
    ["Base URL", setupProbeText(desktopProbe, ["actualBaseUrl", "expectedBaseUrl"], "Not applied"), desktopProbe.ok],
  ]);

  const mcpCount = mcpProbe.ok ? recordCount(mcpProbe.data, ["servers", "items"]) : 0;
  const pluginReady = setupProbeGood(pluginProbe, ["exists"]) || (pluginAppliedProbe.ok && pluginAppliedProbe.data === true);
  setSetupState("setup-mcp-state", mcpCount > 0 || pluginReady ? "Configured" : "Ready", mcpProbe.ok || pluginProbe.ok);
  renderSetupList("setup-mcp-rows", [
    ["MCP Servers", mcpProbe.ok ? `${mcpCount} configured` : mcpProbe.error, mcpProbe.ok],
    ["Claude Plugin", setupProbeText(pluginProbe, ["exists"], "Unavailable"), setupProbeGood(pluginProbe, ["exists"])],
    ["Plugin Applied", pluginAppliedProbe.ok ? stateText(pluginAppliedProbe.data) : pluginAppliedProbe.error, pluginAppliedProbe.data === true],
  ]);

  renderSetupConfigRows(configRows, takeoverProbe);
}

function updateTotals(summary, stats) {
  const totalRequests =
    summary.totalRequests ?? summary.requests ?? summary.requestCount ?? stats.total_requests ?? stats.totalRequests ?? 0;
  const totalCost =
    summary.totalCostUsd ?? summary.costUsd ?? summary.totalCost ?? stats.totalCostUsd ?? stats.costUsd ?? 0;
  text("request-total", compact(totalRequests));
  text("cost-total", money(totalCost));
}

function updateUsageMetrics(summary) {
  const totalTokens = number(
    summary.realTotalTokens ??
    summary.totalTokens ??
    number(summary.totalInputTokens) + number(summary.totalOutputTokens),
  );
  text("usage-filter-requests", compact(summary.totalRequests ?? summary.requests ?? 0));
  text("usage-filter-cost", money(summary.totalCostUsd ?? summary.totalCost ?? 0));
  text("usage-filter-tokens", compact(totalTokens));
  text("usage-filter-cache", percent(summary.cacheHitRate ?? 0));
}

async function loadUsageExplorer() {
  const params = usageQueryParams();
  const [summary, trends, providerStats, modelStats, logs] = await Promise.all([
    getJson(endpoint(endpoints.usageSummary, params)),
    getJson(endpoint(endpoints.usageTrends, params)),
    getJson(endpoint(endpoints.providerStats, params)),
    getJson(endpoint(endpoints.modelStats, params)),
    getJson(endpoint("/usage/logs", { ...params, pageSize: 12 })),
  ]);
  updateUsageMetrics(summary);
  renderTrends(arrayFrom(trends, ["data", "items", "trends"]));
  renderStack("provider-usage", arrayFrom(providerStats, ["providers", "items", "data"]), ["providerName", "providerId", "name"]);
  renderStack("filtered-model-usage", arrayFrom(modelStats, ["models", "items", "data"]), ["model", "modelId", "name"]);
  renderLogs(logs);
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
  await loadUsageExplorer();
  await loadSetupStatus();
  await loadResilience();
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

$("setup-refresh")?.addEventListener("click", () => {
  loadSetupStatus().catch(showError);
});

$("setup-import-mcp")?.addEventListener("click", () => {
  postJson(endpoints.mcpImportApps).then(loadSetupStatus).catch(showError);
});

$("setup-import-claude-desktop")?.addEventListener("click", () => {
  postJson(endpoints.claudeDesktopImport).then(refresh).catch(showError);
});

$("setup-config-rows")?.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-setup-action]");
  if (!button) return;
  if (button.dataset.setupAction === "open-config") {
    postJson(endpoint(endpoints.configFolderOpen, { appType: button.dataset.app })).catch(showError);
  }
});

$("usage-apply")?.addEventListener("click", () => {
  loadUsageExplorer().catch(showError);
});

$("resilience-app")?.addEventListener("change", () => {
  loadResilience().catch(showError);
});

$("resilience-provider")?.addEventListener("change", () => {
  loadResilience().catch(showError);
});

$("resilience-refresh")?.addEventListener("click", () => {
  loadResilience().catch(showError);
});

$("circuit-form")?.addEventListener("submit", (event) => {
  event.preventDefault();
  postJson(endpoints.circuitConfig, circuitConfigPayload()).then(loadResilience).catch(showError);
});

$("stream-form")?.addEventListener("submit", (event) => {
  event.preventDefault();
  postJson(endpoints.streamCheckConfig, streamConfigPayload()).then(loadResilience).catch(showError);
});

$("resilience-toggle-auto")?.addEventListener("click", () => {
  const appType = selectedResilienceApp();
  const current = $("resilience-auto-state")?.textContent === "Enabled";
  postJson(endpoint(endpoints.autoFailover, { appType, enabled: !current })).then(loadResilience).catch(showError);
});

$("resilience-reset-circuit")?.addEventListener("click", () => {
  const appType = selectedResilienceApp();
  const providerId = selectedResilienceProvider();
  if (providerId) postJson(endpoints.resetCircuit, { appType, providerId }).then(loadResilience).catch(showError);
});

$("resilience-add-selected")?.addEventListener("click", () => {
  const appType = selectedResilienceApp();
  const providerId = selectedResilienceProvider();
  if (providerId) postJson(endpoints.failoverQueue, { appType, providerId }).then(loadResilience).catch(showError);
});

$("resilience")?.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-resilience-action]");
  if (!button) return;
  const appType = selectedResilienceApp();
  const providerId = button.dataset.providerId;
  if (button.dataset.resilienceAction === "add-failover") {
    postJson(endpoints.failoverQueue, { appType, providerId }).then(loadResilience).catch(showError);
  } else if (button.dataset.resilienceAction === "remove-failover") {
    deleteJson(endpoints.failoverQueue, { appType, providerId }).then(loadResilience).catch(showError);
  }
});

$("resilience-stream-check")?.addEventListener("click", () => {
  postJson(endpoints.streamCheckAll, { appType: selectedResilienceApp(), proxyTargetsOnly: true })
    .then((rows) => renderStreamCheckResults(Array.isArray(rows) ? rows : []))
    .catch(showError);
});

$("request-log")?.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-request-id]");
  if (!button) return;
  getJson(`${endpoints.requestDetail}/${encodeURIComponent(button.dataset.requestId)}`)
    .then(renderRequestDetail)
    .catch(showError);
});

$("framework-rows")?.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-action]");
  if (!button) return;
  const appType = button.dataset.app;
  const action = button.dataset.action;
  if (action === "reload-app") {
    refresh().catch(showError);
  } else if (action === "edit-provider") {
    const providerId = selectedProviderId(appType);
    if (providerId) editProvider(appType, providerId);
  } else if (action === "test-provider") {
    const providerId = selectedProviderId(appType);
    if (providerId) {
      postJson(endpoints.providerStreamCheck, { appType, providerId })
        .then((result) => setProviderStatus(firstString(result, ["message", "status"], "Provider test completed")))
        .catch(showError);
    }
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

initProviderAppSelect();
initUsageAppSelect();
initResilienceAppSelect();
clearProviderForm("claude");
renderRequestDetail(null);
renderStreamCheckResults([]);

$("provider-clear")?.addEventListener("click", () => {
  clearProviderForm($("provider-app").value);
});

$("provider-form")?.addEventListener("submit", (event) => {
  event.preventDefault();
  saveProvider().catch(showError);
});

$("provider-delete")?.addEventListener("click", () => {
  deleteProviderFromForm().catch(showError);
});

$("provider-test")?.addEventListener("click", () => {
  testProviderFromForm().catch(showError);
});

refresh().catch(showError);
setInterval(() => refresh().catch(showError), 30000);
