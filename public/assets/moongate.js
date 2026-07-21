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
      detail: state.proxyDetail || "AI routing status",
    };
  }
  if (card.id === "providers") {
    const count = number(state.providerCount);
    const builtInCount = number(state.builtInProviderCount);
    return {
      ok: count > 0,
      value: `${compact(count)} configured`,
      detail: state.frameworkErrorCount > 0
        ? window.MoonSuiteI18n?.message("stat.framework_warnings", { count: state.frameworkErrorCount }) ?? `${state.frameworkErrorCount} framework warnings`
        : builtInCount > 0
          ? `${compact(builtInCount)} built-in route${builtInCount === 1 ? "" : "s"}`
          : "No built-in routes",
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

let refreshInFlight = null;
let refreshQueued = false;

function refresh() {
  if (refreshInFlight) {
    refreshQueued = true;
    return refreshInFlight;
  }
  refreshInFlight = refreshDashboard().finally(() => {
    refreshInFlight = null;
    if (refreshQueued) {
      refreshQueued = false;
      Promise.resolve().then(refresh).catch(showError);
    }
  });
  return refreshInFlight;
}

async function refreshDashboard() {
  $("error-box").hidden = true;
  const [healthProbe, statusProbe, proxyProbe, summaryProbe, byAppProbe, modelStatsProbe] =
    await Promise.all([
      safeGetJson(endpoints.health),
      safeGetJson(endpoints.status),
      safeGetJson(endpoints.proxy),
      safeGetJson(endpoints.usageSummary),
      safeGetJson(endpoints.usageByApp),
      safeGetJson(endpoints.modelStats),
    ]);
  const health = probeData(healthProbe, {});
  const status = probeData(statusProbe, {});
  const proxy = probeData(proxyProbe, {});
  const summary = probeData(summaryProbe, {});
  const byApp = probeData(byAppProbe, {});
  const modelStats = probeData(modelStatsProbe, {});

  const gatewayState = healthProbe.ok ? firstString(health, ["status", "state", "ok"]) : "Unavailable";
  text("gateway-state", gatewayState);
  if ($("gateway-state")) $("gateway-state").className = stateClass(gatewayState);
  const gatewayGood = healthProbe.ok && stateClass(gatewayState).includes("good");
  if ($("gateway-dot")) $("gateway-dot").className = `dot ${gatewayGood ? "good" : "bad"}`;
  if ($("gateway-hero-dot")) $("gateway-hero-dot").className = `dot ${gatewayGood ? "good" : "bad"}`;
  if ($("sidebar-gateway-dot")) $("sidebar-gateway-dot").className = `dot ${gatewayGood ? "good pulse" : "bad"}`;
  text("sidebar-gateway-state", gatewayGood ? "MoonGate connected" : "MoonGate unavailable");
  text("gateway-detail", statusProbe.ok ? firstString(status, ["address", "baseUrl", "url"], "Local API ready") : statusProbe.error);

  const proxyValue = proxy?.status ?? proxy?.state ?? proxy?.running ?? proxy?.enabled;
  const proxyState = !proxyProbe.ok
    ? "Unavailable"
    : typeof proxyValue === "boolean"
      ? proxyValue ? "Running" : "Stopped"
      : stateText(proxyValue);
  text("proxy-state", proxyState);
  if ($("proxy-state")) $("proxy-state").className = stateClass(proxyState);
  text("proxy-detail", proxyProbe.ok ? firstString(proxy, ["model", "activeModel", "provider"], "AI routing status") : proxyProbe.error);

  if (summaryProbe.ok || statusProbe.ok) {
    updateTotals(summary, status);
  } else {
    text("request-total", "Unavailable");
    text("cost-total", "Unavailable");
  }
  if (byAppProbe.ok) {
    renderStack("app-usage", arrayFrom(byApp, ["apps", "items", "data"]), ["appType", "app", "name"]);
  } else {
    renderStackError("app-usage", byAppProbe.error);
  }
  if (modelStatsProbe.ok) {
    renderStack("model-usage", arrayFrom(modelStats, ["models", "items", "data"]), ["model", "modelId", "name"]);
  } else {
    renderStackError("model-usage", modelStatsProbe.error);
  }
  mergeReadinessState({
    healthOk: gatewayGood,
    gatewayDetail: statusProbe.ok ? firstString(status, ["address", "baseUrl", "url"], "Local API ready") : statusProbe.error,
    proxyRunning: proxyProbe.ok && stateClass(proxyState).includes("good"),
    proxyDetail: proxyProbe.ok ? firstString(proxy, ["model", "activeModel", "provider"], "AI routing status") : proxyProbe.error,
    totalRequests: summary.totalRequests ?? summary.requests ?? summary.requestCount ?? status.total_requests ?? status.totalRequests ?? 0,
    totalCost: summary.totalCostUsd ?? summary.costUsd ?? summary.totalCost ?? status.totalCostUsd ?? status.costUsd ?? 0,
  });
  const panelResults = await Promise.allSettled([
    loadFrameworks(),
    loadUsageExplorer(),
    loadSetupStatus(),
    loadSuite(),
    loadResilience(),
  ]);
  const coreWarningCount = [healthProbe, statusProbe, proxyProbe, summaryProbe, byAppProbe, modelStatsProbe]
    .some((probe) => !probe.ok) ? 1 : 0;
  const warningCount = panelResults.reduce((total, result) => {
    if (result.status === "rejected") return total + 1;
    return total + number(result.value?.warningCount);
  }, coreWarningCount);
  const usageResult = panelResults[1];
  if (usageResult.status === "fulfilled" && usageResult.value?.stale !== true) {
    mergeReadinessState({ recentRequestCount: usageResult.value?.recentRequestCount || 0 });
  }
  const suffix = warningCount > 0 ? ` with ${warningCount} section warning${warningCount === 1 ? "" : "s"}` : "";
  const time = new Date().toLocaleTimeString();
  text(
    "ui-updated",
    window.MoonSuiteI18n?.message("stat.updated", { suffix, time }) ?? `Updated${suffix} ${time}`,
  );
  text("topbar-updated", `Updated${suffix} ${time}`);
}

function showError(error) {
  const box = $("error-box");
  const message = $("error-message");
  if (message) message.textContent = error && error.message ? error.message : String(error);
  if (box) box.hidden = false;
  text("ui-updated", "Refresh failed");
  text("topbar-updated", "Refresh failed");
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
  const base = new URL(shellApiBase());
  const port = base.port || (base.protocol === "https:" ? "443" : "80");
  text("gateway-endpoint", base.host);
  text("gateway-port", port);
  text("gateway-port-detail", `${base.protocol.replace(":", "")} on ${base.hostname}`);
  text("framework-total", compact(frameworkApps.length));
  text("framework-detail", "AI app types");
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

let toastTimer;

function showToast(value) {
  const toast = $("toast");
  text("toast-text", value);
  if (!toast) return;
  toast.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("show"), 1800);
}

document.querySelector(".shell")?.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-copy-path]");
  const snippetButton = event.target.closest("button[data-copy-snippet]");
  if (button) {
    const url = connectionUrl(button.dataset.copyPath);
    copyText(url)
      .then(() => {
        text("connection-copy-status", `Copied ${button.dataset.copyPath}`);
        showToast("Endpoint copied");
      })
      .catch(showError);
  } else if (snippetButton) {
    const value = clientSnippet(snippetButton.dataset.copySnippet);
    copyText(value)
      .then(() => {
        text("connection-copy-status", "Snippet copied");
        showToast("Snippet copied");
      })
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
  postJson(endpoint(endpoints.autoFailover, { appType, enabled: !resilienceAutoFailoverEnabled })).then(loadResilience).catch(showError);
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
    if (providerId) {
      editProvider(appType, providerId);
      goToPage("providers");
    }
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

$("provider-rows")?.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-provider-edit], button[data-provider-use]");
  if (!button) return;
  if (button.dataset.providerUse) {
    postJson(endpoints.providerSwitch, {
      appType: button.dataset.providerApp,
      id: button.dataset.providerUse,
    }).then(refresh).catch(showError);
    return;
  }
  editProvider(button.dataset.providerApp, button.dataset.providerEdit);
});

function goToPage(page) {
  const target = document.querySelector(`[data-page-view="${page}"]`);
  if (!target) return;
  document.querySelectorAll("[data-page-view]").forEach((node) => {
    node.classList.toggle("active", node === target);
  });
  document.querySelectorAll("[data-page]").forEach((node) => {
    const active = node.dataset.page === page;
    node.classList.toggle("active", active);
    if (active) node.setAttribute("aria-current", "page");
    else node.removeAttribute("aria-current");
  });
  text("page-title", target.dataset.pageTitle || page);
  text("page-subtitle", target.dataset.pageSubtitle || "");
  if (window.location.hash !== `#${page}`) history.replaceState(null, "", `#${page}`);
  window.scrollTo({ top: 0, behavior: "auto" });
}

function navigateToPage(page) {
  if (!document.querySelector(`[data-page-view="${page}"]`)) return;
  if (window.location.hash !== `#${page}`) history.pushState(null, "", `#${page}`);
  goToPage(page);
}

document.querySelector(".nav")?.addEventListener("click", (event) => {
  const link = event.target.closest("[data-page]");
  if (!link) return;
  event.preventDefault();
  navigateToPage(link.dataset.page);
});

document.addEventListener("click", (event) => {
  const link = event.target.closest("[data-goto]");
  if (!link) return;
  event.preventDefault();
  navigateToPage(link.dataset.goto);
});

window.addEventListener("hashchange", () => {
  goToPage(window.location.hash.slice(1) || "overview");
});

initProviderAppSelect();
initUsageAppSelect();
initResilienceAppSelect();
loadCachedProviderTemplates();
clearProviderForm("claude");
renderReadiness({});
renderRequestDetail(null);
renderStreamCheckResults([]);
renderConnectionValues();
goToPage(window.location.hash.slice(1) || "overview");

$("provider-clear")?.addEventListener("click", () => {
  clearProviderForm($("provider-app").value);
});

$("provider-app")?.addEventListener("change", () => {
  clearProviderForm($("provider-app").value);
  renderProviderTemplates();
});

$("provider-template-apply")?.addEventListener("click", () => {
  applyProviderTemplate();
});

$("provider-template-load")?.addEventListener("click", () => {
  $("provider-template-file")?.click();
});

$("provider-template-reload")?.addEventListener("click", () => {
  loadProviderTemplates().catch(showError);
});

$("provider-template-file")?.addEventListener("change", (event) => {
  const file = event.target.files?.[0];
  if (!file) return;
  loadProviderTemplateFile(file).catch(showError).finally(() => {
    event.target.value = "";
  });
});

$("provider-form")?.addEventListener("submit", (event) => {
  event.preventDefault();
  saveProvider().catch(showError);
});

$("provider-delete")?.addEventListener("click", () => {
  deleteProviderFromForm().catch(showError);
});

$("provider-use")?.addEventListener("click", () => {
  useProviderFromForm().catch(showError);
});

$("provider-test")?.addEventListener("click", () => {
  testProviderFromForm().catch(showError);
});

Promise.all([refresh(), loadProviderTemplates()]).catch(showError);

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
