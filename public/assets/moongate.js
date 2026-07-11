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
  text("operator-action-status", "Action failed");
}

function setOperatorStatus(value) {
  text("operator-action-status", value);
}

function shellApiBase() {
  const shell = document.querySelector("[data-moongate-api-base]");
  const value = shell ? shell.getAttribute("data-moongate-api-base") : "";
  return value || window.location.origin;
}

function connectionUrl(path) {
  return new URL(path, shellApiBase()).toString();
}

function clientSnippet(kind) {
  if (kind === "openai-env") {
    return `OPENAI_BASE_URL=${connectionUrl("v" + "1")}\nOPENAI_API_KEY=moongate`;
  }
  if (kind === "anthropic-env") {
    return `ANTHROPIC_BASE_URL=${shellApiBase()}\nANTHROPIC_API_KEY=moongate`;
  }
  if (kind === "openclaw-env") {
    return `OPENCLAW_BASE_URL=${connectionUrl("openclaw/v" + "1")}\nOPENCLAW_API_KEY=moongate`;
  }
  if (kind === "metrics-url") {
    return connectionUrl("/metrics");
  }
  return shellApiBase();
}

function renderConnectionValues() {
  document.querySelectorAll("[data-url-path]").forEach((node) => {
    node.textContent = connectionUrl(node.dataset.urlPath);
  });
  document.querySelectorAll("[data-snippet]").forEach((node) => {
    node.textContent = clientSnippet(node.dataset.snippet);
  });
}

async function copyText(value) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    await navigator.clipboard.writeText(value);
    return;
  }
  const input = document.createElement("textarea");
  input.value = value;
  input.setAttribute("readonly", "true");
  input.style.position = "fixed";
  input.style.opacity = "0";
  document.body.appendChild(input);
  input.select();
  document.execCommand("copy");
  input.remove();
}

async function runOperatorAction(action) {
  const labels = {
    "start-proxy": "Starting proxy",
    "sync-live": "Syncing providers",
    "refresh-setup": "Checking setup",
    "stream-check": "Checking streams",
    "write-suite": "Writing suite status",
  };
  setOperatorStatus(labels[action] || "Running action");
  if (action === "start-proxy") {
    await postJson(endpoints.proxyStart);
    await refresh();
  } else if (action === "sync-live") {
    await postJson(endpoints.syncLive);
    await refresh();
  } else if (action === "refresh-setup") {
    await loadSetupStatus();
  } else if (action === "stream-check") {
    const rows = await postJson(endpoints.streamCheckAll, { appType: selectedResilienceApp(), proxyTargetsOnly: true });
    renderStreamCheckResults(Array.isArray(rows) ? rows : []);
  } else if (action === "write-suite") {
    await postJson(endpoints.suiteWriteStatus);
    await loadSuite();
  }
  setOperatorStatus("Ready");
}

$("operator-actions")?.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-operator-action]");
  if (!button) return;
  runOperatorAction(button.dataset.operatorAction).catch(showError);
});

$("connection-board")?.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-copy-path]");
  const snippetButton = event.target.closest("button[data-copy-snippet]");
  if (button) {
    const url = connectionUrl(button.dataset.copyPath);
    copyText(url)
      .then(() => text("connection-copy-status", `Copied ${button.dataset.copyPath}`))
      .catch(showError);
  } else if (snippetButton) {
    const value = clientSnippet(snippetButton.dataset.copySnippet);
    copyText(value)
      .then(() => text("connection-copy-status", "Snippet copied"))
      .catch(showError);
  }
});

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
renderConnectionValues();

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

const supportedRefreshIntervals = new Set([0, 5000, 10000, 30000, 60000]);

function normalizedRefreshInterval(value) {
  return supportedRefreshIntervals.has(value) ? value : 30000;
}

async function scheduleDashboardRefresh() {
  const settings = await safeGetJson(endpoints.settings);
  const interval = normalizedRefreshInterval(
    settings.ok ? settings.data?.usageDashboardRefreshIntervalMs : undefined,
  );
  if (interval === 0) return;
  setTimeout(async () => {
    await refresh().catch(showError);
    scheduleDashboardRefresh().catch(showError);
  }, interval);
}

scheduleDashboardRefresh().catch(showError);
