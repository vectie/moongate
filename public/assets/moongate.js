let readinessState = {};
let activePage = "overview";
let dashboardStarted = false;
let routeObservation = null;

function mergeReadinessState(next) {
  if (next?.healthOk === false && typeof invalidateCohortComparison === "function") invalidateCohortComparison("Gateway unavailable; capture again after recovery");
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
    return {
      ok: count > 0,
      value: `${compact(count)} configured`,
      detail: state.frameworkErrorCount > 0
        ? window.MoonSuiteI18n?.message("stat.framework_warnings", { count: state.frameworkErrorCount }) ?? `${state.frameworkErrorCount} framework warnings`
        : count > 0
          ? "Ready for app binding"
          : "Choose a template to add one",
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

function setGoalStep(id, status) {
  const step = $(`goal-step-${id}`);
  if (!step) return;
  step.className = `goal-step ${status}`;
  const labels = { done: "Done", current: "Next", waiting: "Waiting" };
  text(`goal-step-${id}-status`, labels[status] || labels.waiting);
  if (status === "current") step.setAttribute("aria-current", "step");
  else step.removeAttribute("aria-current");
}

function setPrimaryGoalAction(label, detail, action, target, recovery = "") {
  const button = $("primary-next-action");
  text("primary-next-action-label", uiLabel(label));
  text("goal-next-detail", uiLabel(detail));
  if (button) {
    button.dataset.goalAction = action;
    button.dataset.goalTarget = target || "";
  }
  const recoveryNode = $("goal-recovery");
  if (recoveryNode) {
    recoveryNode.hidden = recovery === "";
    recoveryNode.textContent = recovery;
  }
}

function renderGoalCompass(state) {
  const healthKnown = typeof state.healthOk === "boolean";
  const connection = primaryConnection();
  const providerDone = connection?.state.saved === true;
  const routingDone = state.proxyRunning === true;
  const appDone = connection?.state.wired === true;
  const observed = connection?.state.ready === true && routeObservation?.observed === true;
  let current = "";

  if (healthKnown && state.healthOk) {
    if (!providerDone) current = "provider";
    else if (!routingDone) current = "routing";
    else if (!appDone) current = "app";
    else if (!observed) current = "observe";
  }
  for (const [id, done] of [
    ["provider", providerDone],
    ["routing", routingDone],
    ["app", appDone],
    ["observe", observed],
  ]) {
    setGoalStep(id, done ? "done" : id === current ? "current" : "waiting");
  }

  if (!healthKnown) {
    setPrimaryGoalAction(
      "Check readiness",
      "MoonGate is checking the local gateway before choosing the next safe action.",
      "refresh",
      "",
    );
  } else if (!state.healthOk) {
    const detail = state.gatewayDetail || "The local MoonGate service did not answer.";
    setPrimaryGoalAction(
      "Retry gateway check",
      "Restore the local service, then retry the same health check.",
      "refresh",
      "",
      `Blocked: ${detail}`,
    );
  } else if (connection?.row.warning) {
    setPrimaryGoalAction("Retry connection check", "Could not read MoonDesk's connection. Retry before changing configuration.", "refresh", "");
  } else if (!providerDone) {
    setPrimaryGoalAction(
      "Add a provider",
      "Choose a provider template, retain credentials as host secrets, then run its bounded connection test.",
      "navigate",
      "providers",
    );
  } else if (!connection.state.enabled) {
    setPrimaryGoalAction("Review Provider", "The selected provider is paused.", "provider", connection.provider.id);
  } else if (!routingDone) {
    setPrimaryGoalAction(
      "Start routing",
      "A provider exists. Start the local route before connecting an app.",
      "start-routing",
      "",
    );
  } else if (!appDone) {
    setPrimaryGoalAction(
      "Connect an app",
      "Bind one detected app to the tested provider and verify its real configuration.",
      "navigate",
      "bindings",
    );
  } else if (!connection.state.tested) {
    setPrimaryGoalAction("Test provider", "Test the saved provider used by MoonDesk.", "provider", connection.provider.id);
  } else if (!observed) {
    setPrimaryGoalAction(
      "Verify connection",
      "Send a request from MoonDesk, then check the graph and route traffic.",
      "navigate",
      "connections",
    );
  } else {
    setPrimaryGoalAction(
      "Review live usage",
      "Traffic was observed on the shared Moon apps route.",
      "navigate",
      "usage",
    );
  }
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
  renderGoalCompass(state);
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
  invalidateSharedReads();
  const page = activePage;
  const overviewDetails = page === "overview" && document.querySelector('.overview-details')?.open;
  $("error-box").hidden = true;
  const [healthProbe, statusProbe, proxyProbe, summaryProbe, modelStatsProbe] =
    await Promise.all([
      safeGetJson(endpoints.health),
      safeGetJson(endpoints.status),
      safeGetJson(endpoints.proxy),
      overviewDetails ? safeGetJson(endpoints.usageSummary) : {ok: true, data: {}},
      overviewDetails ? safeGetJson(endpoints.modelStats) : {ok: true, data: {}},
    ]);
  const health = probeData(healthProbe, {});
  const status = probeData(statusProbe, {});
  const proxy = probeData(proxyProbe, {});
  const summary = probeData(summaryProbe, {});
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
  if (modelStatsProbe.ok) {
    renderStack("model-usage", arrayFrom(modelStats, ["models", "items", "data"]), ["model", "modelId", "name"]);
  } else {
    renderStackError("model-usage", modelStatsProbe.error);
  }
  const proxyGood = proxyProbe.ok && stateClass(proxyState).includes("good");
  if ($("proxy-start")) $("proxy-start").disabled = proxyGood;
  if ($("proxy-stop")) $("proxy-stop").disabled = !proxyGood;
  mergeReadinessState({
    healthOk: gatewayGood,
    gatewayDetail: statusProbe.ok ? firstString(status, ["address", "baseUrl", "url"], "Local API ready") : statusProbe.error,
    proxyRunning: proxyGood,
    proxyDetail: proxyProbe.ok ? firstString(proxy, ["model", "activeModel", "provider"], "AI routing status") : proxyProbe.error,
    totalRequests: summary.totalRequests ?? summary.requests ?? summary.requestCount ?? status.total_requests ?? status.totalRequests ?? 0,
    totalCost: summary.totalCostUsd ?? summary.costUsd ?? summary.totalCost ?? status.totalCostUsd ?? status.costUsd ?? 0,
  });
  const panelResults = await Promise.allSettled(pageLoaders(page).map(load => load()));
  if (page === "overview") await loadPrimaryRouteObservation();
  if (page === "connections") renderConnectionGraph(bindingRows);
  renderGoalCompass(readinessState);
  const coreWarningCount = [healthProbe, statusProbe, proxyProbe, summaryProbe, modelStatsProbe]
    .some((probe) => !probe.ok) ? 1 : 0;
  const warningCount = panelResults.reduce((total, result) => {
    if (result.status === "rejected") return total + 1;
    return total + number(result.value?.warningCount);
  }, coreWarningCount);
  const suffix = warningCount > 0 ? ` with ${warningCount} section warning${warningCount === 1 ? "" : "s"}` : "";
  const time = new Date().toLocaleTimeString();
  text(
    "ui-updated",
    window.MoonSuiteI18n?.message("stat.updated", { suffix, time }) ?? `Updated${suffix} ${time}`,
  );
  text("topbar-updated", `Updated${suffix} ${time}`);
}

function pageLoaders(page) {
  if (page === "overview") return [() => loadSetupStatus({primaryOnly: true})];
  if (page === "providers") return [loadFrameworks, () => builtinProviderTemplates.length ? Promise.resolve() : loadProviderTemplates()];
  if (page === "bindings" || page === "connections") return [loadSetupStatus];
  if (page === "usage") return [loadUsageExplorer];
  if (page === "requests") return [ensureRequestExplorer];
  if (page === "suite") return [loadSuite];
  if (page === "operations") return [loadOperations];
  if (page === "advanced") return [loadSetupDetails, ...($("resilience")?.closest("details")?.open ? [loadResilience] : [])];
  return [];
}

async function loadPrimaryRouteObservation() {
  const connection = primaryConnection();
  if (!connection?.state.wired || !connection.provider) { routeObservation = null; return; }
  const {row, provider} = connection;
  const model = provider.modelMapping?.defaultModel;
  const scope = row.app.providerAppType || row.app.id;
  const identity = providerConfigIdentity(provider, scope, provider.id);
  if (routeObservation?.identity !== identity) routeObservation = {identity, since: Math.floor(Date.now()/1000), observed: false};
  const observation = routeObservation;
  const probe = await safeGetJson(endpoint(endpoints.usageLogs, {appType: scope, startDate: observation.since, page: 0, pageSize: 12}));
  if (observation !== routeObservation) return;
  observation.observed ||= probe.ok && Array.isArray(probe.data?.data) && probe.data.data.some(request =>
    request.providerId === provider.id && request.model === model && request.appType === scope &&
    request.statusCode >= 200 && request.statusCode < 300 && !request.error);
}

function showError(error, heading = "Data refresh failed") {
  const box = $("error-box");
  const message = $("error-message");
  const title = box?.querySelector("strong");
  if (title) title.textContent = uiLabel(heading);
  box?.querySelector("[data-error-recovery]")?.remove();
  if (box && !box.querySelector("[data-error-dismiss]")) {
    const dismiss = document.createElement("button");
    dismiss.type = "button";
    dismiss.className = "error-box-dismiss";
    dismiss.dataset.errorDismiss = "true";
    dismiss.setAttribute("aria-label", uiLabel("Close"));
    dismiss.textContent = "×";
    dismiss.addEventListener("click", () => {
      box.hidden = true;
    });
    box.appendChild(dismiss);
  }
  if (message) message.textContent = error && error.message ? error.message : String(error);
  if (box) box.hidden = false;
  if (heading === "Data refresh failed") {
    text("ui-updated", "Refresh failed");
    text("topbar-updated", "Refresh failed");
  }
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

$("request-investigation")?.addEventListener("toggle", () => renderRequestCollection());

$("proxy-start")?.addEventListener("click", () => {
  postJson(endpoints.proxyStart).then(refresh).catch(showError);
});

$("proxy-stop")?.addEventListener("click", () => {
  postJson(endpoints.proxyStop).then(refresh).catch(error => {
    showError(error, "Could not stop routing");
    const recovery = document.createElement("button");
    recovery.type = "button";
    recovery.dataset.errorRecovery = "apps";
    recovery.dataset.goto = "bindings";
    recovery.textContent = uiLabel("Review app connections");
    $("error-box")?.appendChild(recovery);
  });
});

$("primary-next-action")?.addEventListener("click", () => {
  const button = $("primary-next-action");
  const action = button?.dataset.goalAction || "refresh";
  if (action === "start-routing") {
    postJson(endpoints.proxyStart).then(refresh).catch(showError);
  } else if (action === "navigate") {
    navigateToPage(button?.dataset.goalTarget || "overview");
  } else if (action === "provider") {
    const connection = primaryConnection();
    navigateToPage("providers");
    refresh().then(() => editProvider(connection.row.app.providerAppType || connection.row.app.id, connection.provider.id)).catch(showError);
  } else {
    refresh().catch(showError);
  }
});

$("bindings-refresh")?.addEventListener("click", () => {
  refresh().catch(showError);
});

$("connection-graph-refresh")?.addEventListener("click", () => {
  refresh().catch(showError);
});

document.querySelector(".setup-advanced")?.addEventListener("toggle", (event) => {
  if (event.currentTarget.open) loadSetupDetails().catch(showError);
});
$("setup-import-mcp")?.addEventListener("click", () => {
  postJson(endpoints.mcpImportApps).then(loadSetupStatus).catch(showError);
});

$("binding-rows")?.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-binding-action]");
  if (!button) return;
  const appType = button.dataset.app;
  const action = button.dataset.bindingAction;
  if (action === "stage") { try { stageBindingChange(appType); } catch (error) { showError(error); } }
  else if (action === "bind") runBindingAction(appType, bindApp);
  else if (action === "unbind") runBindingAction(appType, unbindApp);
  else if (action === "verify") runBindingAction(appType, verifyBinding);
  else if (action === "manual") navigateToPage("connect");
  else if (action === "test-provider") {
    const row = bindingRows.find(row => row.app.id === appType);
    const provider = row && configuredConnectionProvider(row);
    const providerId = provider?.id || provider?.providerId;
    const scope = row?.app.providerAppType || appType;
    navigateToPage("providers");
    refresh().then(() => editProvider(scope, providerId)).catch(showError);
  }
  else if (action === "add-provider") {
    clearProviderForm(resolveProviderAppScope(appType));
    renderProviderTemplates();
    navigateToPage("providers");
  }
});

$("binding-rows")?.addEventListener("change", event => {
  const select = event.target.closest('[data-binding-provider]');
  if (!select) return;
  const row = bindingRows.find(row => row.app.id === select.dataset.bindingProvider);
  const apply = document.querySelector(`[data-binding-action="bind"][data-app="${select.dataset.bindingProvider}"]`);
  if (apply) apply.disabled = row.binding.bound === true && select.value === row.binding.currentProviderId;
});

$("usage-apply")?.addEventListener("click", () => {
  loadUsageExplorer().catch(showError);
});

$("request-filters")?.addEventListener("submit", (event) => {
  event.preventDefault();
  applyRequestFilters().catch(showError);
});
$("request-reset")?.addEventListener("click", () => applyRequestFilters(true).catch(showError));
$("request-prev")?.addEventListener("click", () => changeRequestPage(-1).catch(showError));
$("request-next")?.addEventListener("click", () => changeRequestPage(1).catch(showError));
$("request-retry")?.addEventListener("click", () => loadRequestExplorer().catch(showError));
$("request-detail-retry")?.addEventListener("click", () => selectRequestDetail(requestSelectedId).catch(showError));
$("request-export-page")?.addEventListener("click", () => downloadRequestExport("page"));
$("request-export-detail")?.addEventListener("click", () => downloadRequestExport("detail"));

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
  loadResilienceProvider().catch(showError);
});

$("resilience-refresh")?.addEventListener("click", () => {
  loadResilience().catch(showError);
});

$("circuit-form")?.addEventListener("submit", (event) => {
  event.preventDefault();
  saveResilienceConfig("circuit").catch(showError);
});

$("stream-form")?.addEventListener("submit", (event) => {
  event.preventDefault();
  saveResilienceConfig("stream").catch(showError);
});

$("circuit-form")?.addEventListener("input", () => {
  circuitFormDirty = true;
  setSetupState("resilience-circuit-status", "Unsaved changes", false);
});
$("stream-form")?.addEventListener("input", () => {
  streamFormDirty = true;
  setSetupState("resilience-stream-status", "Unsaved changes", false);
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
  selectRequestDetail(button.dataset.requestId).catch(showError);
});

$("provider-rows")?.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-provider-edit]");
  const row = event.target.closest("tr[data-provider-row]");
  if (button?.dataset.providerEdit) {
    editProvider(button.dataset.providerApp, button.dataset.providerEdit);
    return;
  }
  if (row) editProvider(row.dataset.providerApp, row.dataset.providerId);
});

$("provider-rows")?.addEventListener("keydown", (event) => {
  if (event.key !== "Enter" && event.key !== " ") return;
  if (event.target.closest("button, select, input, a")) return;
  const row = event.target.closest("tr[data-provider-row]");
  if (!row) return;
  event.preventDefault();
  editProvider(row.dataset.providerApp, row.dataset.providerId);
});

function syncSidebarNavIndicator() {
  const nav = document.querySelector(".sidebar .nav");
  if (!nav) return;
  const active = nav.querySelector(".nav-item.active");
  if (!active) return;
  let indicator = nav.querySelector(".mg-nav-indicator");
  if (!indicator) {
    indicator = document.createElement("span");
    indicator.className = "mg-nav-indicator";
    indicator.setAttribute("aria-hidden", "true");
    nav.prepend(indicator);
  }
  const navRect = nav.getBoundingClientRect();
  const itemRect = active.getBoundingClientRect();
  if (itemRect.height <= 0 || window.innerWidth <= 760) {
    indicator.style.opacity = "0";
    return;
  }
  indicator.style.height = `${Math.max(20, itemRect.height - 12)}px`;
  indicator.style.transform = `translateY(${itemRect.top - navRect.top + 6}px)`;
  indicator.style.opacity = "1";
}

function goToPage(page) {
  const target = document.querySelector(`[data-page-view="${page}"]`);
  if (!target) return;
  activePage = page;
  if (page !== "operations" && typeof invalidateCohortComparison === "function") invalidateCohortComparison("Comparison cleared after navigation; capture a new snapshot");
  document.querySelectorAll("[data-page-view]").forEach((node) => {
    node.classList.toggle("active", node === target);
  });
  document.querySelectorAll("[data-page]").forEach((node) => {
    const parent = ["connections", "connect"].includes(page) ? "bindings" : ["operations", "suite", "guide"].includes(page) ? "advanced" : page === "transcripts" ? "requests" : page;
    const active = node.dataset.page === parent;
    node.classList.toggle("active", active);
    if (active) node.setAttribute("aria-current", "page");
    else node.removeAttribute("aria-current");
  });
  requestAnimationFrame(syncSidebarNavIndicator);
  text("page-title", target.dataset.pageTitle || page);
  text("page-subtitle", target.dataset.pageSubtitle || "");
  if ($("page-subtitle")) $("page-subtitle").hidden = !target.dataset.pageSubtitle;
  const returnNav = $("context-return");
  if (returnNav) {
    const parent = ["operations", "suite", "guide"].includes(page) ? "advanced" : page === "transcripts" ? "requests" : "";
    returnNav.hidden = !parent;
    returnNav.dataset.goto = parent;
    returnNav.textContent = uiLabel(parent === "advanced" ? "Back to Advanced" : "Back to Requests");
  }
  if (window.location.hash !== `#${page}`) history.replaceState(null, "", `#${page}`);
  window.scrollTo({ top: 0, behavior: "auto" });
  if (dashboardStarted) refresh().catch(showError);
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
  const localMenu = event.target.closest(".local-menu");
  document.querySelectorAll(".local-menu[open]").forEach(menu => { if (menu !== localMenu) menu.open = false; });
  const link = event.target.closest("[data-goto]");
  if (!link) return;
  event.preventDefault();
  navigateToPage(link.dataset.goto);
});

document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape") return;
  const menu = event.target.closest(".local-menu[open]");
  if (!menu) return;
  event.preventDefault();
  menu.open = false;
  menu.querySelector("summary")?.focus();
});

window.addEventListener("hashchange", () => {
  goToPage(window.location.hash.slice(1) || "overview");
});
window.addEventListener("resize", () => requestAnimationFrame(syncSidebarNavIndicator));

initProviderAppSelect();
initUsageAppSelect();
initRequestAppSelect();
initResilienceAppSelect();
loadCachedProviderTemplates();
clearProviderForm("openclaw");
renderReadiness({});
renderRequestDetail(null);
renderStreamCheckResults([]);
renderConnectionValues();
goToPage(window.location.hash.slice(1) || "overview");

$("provider-clear")?.addEventListener("click", () => {
  clearProviderForm($("provider-app").value);
});

$("provider-app")?.addEventListener("change", () => {
  switchProviderAppScope($("provider-app").value);
  renderProviderTemplates();
});

$("provider-api-format")?.addEventListener("change", () => {
  if (typeof syncProviderProtocolFields === "function") syncProviderProtocolFields();
});

$("provider-template")?.addEventListener("change", () => {
  if ($("provider-template").value === "custom") {
    clearProviderForm($("provider-app").value, { preserveTemplate: "custom", expandAdvanced: true });
    return;
  }
  applyProviderTemplate();
  if (typeof syncProviderProtocolFields === "function") syncProviderProtocolFields();
});

if (!document.querySelector('link[rel="icon"]')) {
  const icon = document.createElement("link");
  icon.rel = "icon";
  icon.type = "image/svg+xml";
  icon.href = "/assets/moongate.svg";
  document.head?.appendChild(icon);
}

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

$("provider-form")?.addEventListener("input", providerFormChanged);
$("provider-form")?.addEventListener("change", providerFormChanged);

$("provider-form")?.addEventListener("submit", (event) => {
  event.preventDefault();
  runProviderAction(saveProvider);
});

$("provider-delete")?.addEventListener("click", () => {
  runProviderAction(deleteProviderFromForm);
});

$("provider-test")?.addEventListener("click", () => {
  runProviderAction(testProviderFromForm);
});

$("provider-models-refresh")?.addEventListener("click", () => {
  refreshProviderModels().catch(showError);
});

$("provider-connect-app")?.addEventListener("click", () => {
  preferredBindingProvider = {scope: $("provider-original-app").value, id: $("provider-original-id").value};
  navigateToPage("bindings");
});

dashboardStarted = true;
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
    if (!document.hidden && !["operations", "advanced", "transcripts", "requests"].includes(activePage)) await refresh().catch(showError);
    scheduleDashboardRefresh().catch(showError);
  }, interval);
}

scheduleDashboardRefresh().catch(showError);

document.querySelector('.overview-details')?.addEventListener('toggle', event => { if (event.target.open) refresh().catch(showError); });
$("resilience")?.closest('details')?.addEventListener('toggle', event => { if (event.target.open) loadResilience().catch(showError); });
