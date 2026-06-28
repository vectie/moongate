let readinessState = {};

function mergeReadinessState(next) {
  readinessState = { ...readinessState, ...(next || {}) };
  renderReadiness(readinessState);
}

function readinessCardState(card, state) {
  if (card.id === "gateway") {
    const ok = state.healthOk === true;
    return {
      ok,
      value: ok ? card.ready : card.waiting,
      detail: state.gatewayDetail || "Local API health",
    };
  }
  if (card.id === "proxy") {
    const ok = state.proxyRunning === true;
    return {
      ok,
      value: ok ? card.ready : card.waiting,
      detail: state.proxyDetail || "Proxy route status",
    };
  }
  if (card.id === "providers") {
    const count = number(state.providerCount);
    return {
      ok: count > 0,
      value: count > 0 ? `${compact(count)} provider${count === 1 ? "" : "s"}` : card.waiting,
      detail: state.frameworkErrorCount > 0 ? `${state.frameworkErrorCount} framework warnings` : "Provider routes",
    };
  }
  if (card.id === "usage") {
    const requests = number(state.totalRequests);
    return {
      ok: requests > 0,
      value: requests > 0 ? `${compact(requests)} requests` : card.waiting,
      detail: state.totalCost != null ? money(state.totalCost) : "Spend tracker",
    };
  }
  if (card.id === "requests") {
    const count = number(state.recentRequestCount);
    return {
      ok: count > 0,
      value: count > 0 ? `${compact(count)} recent` : card.waiting,
      detail: "Request log",
    };
  }
  return { ok: false, value: card.waiting, detail: card.label };
}

function renderReadiness(state) {
  const target = $("readiness-cards");
  if (!target) return;
  target.innerHTML = readinessCards
    .map((card) => {
      const item = readinessCardState(card, state);
      return `
        <a class="readiness-card ${item.ok ? "good" : "warn"}" href="${escapeHtml(card.target)}">
          <span>${escapeHtml(card.label)}</span>
          <strong>${escapeHtml(item.value)}</strong>
          <small>${escapeHtml(item.detail)}</small>
        </a>
      `;
    })
    .join("");
}

function probeData(probe, fallback) {
  return probe && probe.ok ? probe.data : fallback;
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

function renderSuiteApps(apps, integrations) {
  const target = $("suite-app-rows");
  if (!target) return;
  target.innerHTML = "";
  if (apps.length === 0) {
    target.innerHTML = `<tr><td colspan="4">No suite app contract data.</td></tr>`;
    return;
  }
  for (const app of apps) {
    const id = firstString(app, ["id", "app", "name"]);
    const integration = integrations && typeof integrations === "object" ? integrations[id] : null;
    const keyRoute = firstString(
      integration,
      ["healthUrl", "usageSummaryUrl", "streamCheckAllProvidersUrl", "modelsUrl", "providerPresetsUrl"],
      firstString(app, ["primaryRoute", "route"], "-"),
    );
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><strong>${escapeHtml(id)}</strong></td>
      <td>${escapeHtml(firstString(app, ["role", "kind"]))}</td>
      <td>${escapeHtml(firstString(app, ["usage", "description"]))}</td>
      <td>${escapeHtml(keyRoute)}</td>
    `;
    target.appendChild(tr);
  }
}

function renderSuiteIntegrations(integrations) {
  const target = $("suite-integrations");
  if (!target) return;
  target.innerHTML = "";
  const rows = objectRows(integrations);
  if (rows.length === 0) {
    target.innerHTML = `<div class="row-card"><strong>No suite integrations</strong><small>Manifest did not publish integration metadata.</small></div>`;
    return;
  }
  for (const row of rows) {
    const urls = [
      firstString(row, ["healthUrl"], ""),
      firstString(row, ["usageSummaryUrl"], ""),
      firstString(row, ["providerPresetsUrl"], ""),
      firstString(row, ["streamCheckConfigUrl"], ""),
      firstString(row, ["configStatusUrl"], ""),
    ].filter(Boolean);
    const adapters = arrayFrom(row.adapterPackages, []).map((item) => String(item));
    const div = document.createElement("div");
    div.className = "row-card";
    div.innerHTML = `
      <div>
        <strong>${escapeHtml(row.id)}</strong>
        <small>${escapeHtml(urls.slice(0, 2).join(" | ") || adapters.slice(0, 3).join(" | ") || "Integration metadata ready")}</small>
      </div>
      <strong>${escapeHtml(adapters.length ? `${adapters.length} adapters` : "Ready")}</strong>
    `;
    target.appendChild(div);
  }
}

async function loadSuite() {
  const [manifestProbe, statusProbe, providersProbe] = await Promise.all([
    safeGetJson(endpoints.suiteManifest),
    safeGetJson(endpoints.suiteStatus),
    safeGetJson(endpoints.suiteMoonclawProviders),
  ]);
  const manifest = manifestProbe.ok ? manifestProbe.data : {};
  const status = statusProbe.ok ? statusProbe.data : {};
  const apps = arrayFrom(manifest.apps, []);
  const capabilities = arrayFrom(manifest.capabilities, []);
  const integrations = manifest.suiteIntegrations || {};
  const providerRows = providersProbe.ok ? recordCount(providersProbe.data, ["providers"]) : 0;
  text("suite-status-state", firstString(status, ["status"], manifestProbe.ok ? "available" : "unavailable"));
  text("suite-app-count", compact(apps.length));
  text("suite-capability-count", compact(capabilities.length));
  text("suite-status-path", firstString(status, ["statusPath"], firstString(manifest, ["statusFile"])));
  renderSuiteApps(apps, integrations);
  renderSuiteIntegrations(integrations);
  if (providerRows > 0) text("suite-capability-count", `${compact(capabilities.length)} / ${providerRows} providers`);
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

async function refresh() {
  $("error-box").hidden = true;
  const [healthProbe, statusProbe, proxyProbe, summaryProbe, byAppProbe, modelStatsProbe, logsProbe] =
    await Promise.all([
      safeGetJson(endpoints.health),
      safeGetJson(endpoints.status),
      safeGetJson(endpoints.proxy),
      safeGetJson(endpoints.usageSummary),
      safeGetJson(endpoints.usageByApp),
      safeGetJson(endpoints.modelStats),
      safeGetJson(endpoints.logs),
    ]);
  const health = probeData(healthProbe, {});
  const status = probeData(statusProbe, {});
  const proxy = probeData(proxyProbe, {});
  const summary = probeData(summaryProbe, {});
  const byApp = probeData(byAppProbe, {});
  const modelStats = probeData(modelStatsProbe, {});
  const logs = probeData(logsProbe, {});

  const gatewayState = healthProbe.ok ? firstString(health, ["status", "state", "ok"]) : "Unavailable";
  text("gateway-state", gatewayState);
  text("gateway-detail", statusProbe.ok ? firstString(status, ["address", "baseUrl", "url"], "Local API ready") : statusProbe.error);

  const proxyState = proxyProbe.ok ? firstString(proxy, ["status", "state", "running", "enabled"]) : "Unavailable";
  text("proxy-state", proxyState);
  text("proxy-detail", proxyProbe.ok ? firstString(proxy, ["model", "activeModel", "provider"], "Proxy route status") : proxyProbe.error);

  updateTotals(summary, status);
  const providerHealthRows = arrayFrom(status.provider_routes || status.active_targets || [], ["providers", "items", "data", "health"]);
  renderProviderRows(providerHealthRows);
  renderStack("app-usage", arrayFrom(byApp, ["apps", "items", "data"]), ["appType", "app", "name"]);
  renderStack("model-usage", arrayFrom(modelStats, ["models", "items", "data"]), ["model", "modelId", "name"]);
  renderLogs(logs);
  mergeReadinessState({
    healthOk: healthProbe.ok && stateClass(gatewayState).includes("good"),
    gatewayDetail: statusProbe.ok ? firstString(status, ["address", "baseUrl", "url"], "Local API ready") : statusProbe.error,
    proxyRunning: proxyProbe.ok && stateClass(proxyState).includes("good"),
    proxyDetail: proxyProbe.ok ? firstString(proxy, ["model", "activeModel", "provider"], "Proxy route status") : proxyProbe.error,
    providerCount: readinessState.providerCount ?? providerHealthRows.length,
    totalRequests: summary.totalRequests ?? summary.requests ?? summary.requestCount ?? status.total_requests ?? status.totalRequests ?? 0,
    totalCost: summary.totalCostUsd ?? summary.costUsd ?? summary.totalCost ?? status.totalCostUsd ?? status.costUsd ?? 0,
    recentRequestCount: arrayFrom(logs, ["logs", "items", "requests", "data"]).length,
  });
  const panelResults = await Promise.allSettled([
    loadFrameworks(),
    loadUsageExplorer(),
    loadSetupStatus(),
    loadSuite(),
    loadResilience(),
  ]);
  const failedPanels = panelResults.filter((result) => result.status === "rejected").length;
  const suffix = failedPanels > 0 ? ` with ${failedPanels} panel warning${failedPanels === 1 ? "" : "s"}` : "";
  text("ui-updated", `Updated${suffix} ${new Date().toLocaleTimeString()}`);
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

$("suite-refresh")?.addEventListener("click", () => {
  loadSuite().catch(showError);
});

$("suite-write-status")?.addEventListener("click", () => {
  postJson(endpoints.suiteWriteStatus).then(loadSuite).catch(showError);
});

$("suite-write-moonclaw")?.addEventListener("click", () => {
  postJson(endpoints.suiteWriteMoonclawProviders).then(loadSuite).catch(showError);
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
    if (select) postJson(endpoints.providerSwitch, { appType, id: select.value }).then(refresh).catch(showError);
  } else if (action === "import-live") {
    postJson(endpoint(endpoints.providerImportLive, { appType })).then(refresh).catch(showError);
  } else if (action === "claude-desktop-import") {
    postJson(endpoints.claudeDesktopImport).then(refresh).catch(showError);
  }
});

initProviderAppSelect();
initUsageAppSelect();
initResilienceAppSelect();
clearProviderForm("claude");
renderReadiness({});
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
