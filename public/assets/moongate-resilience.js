let resilienceLoadGeneration = 0;
let circuitFormDirty = false;
let streamFormDirty = false;

function selectedResilienceApp() {
  return $("resilience-app")?.value || "openclaw";
}

function selectedResilienceProvider() {
  return $("resilience-provider")?.value || "";
}

let resilienceAutoFailoverEnabled = false;

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
    target.innerHTML = `<div class="row-card"><strong>${escapeHtml(emptyText)}</strong><small>Nothing to change here.</small></div>`;
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
    target.innerHTML = `<div class="log-item"><strong>No connection-test results</strong><small>Run Connection Test to check configured providers.</small></div>`;
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
  const generation = ++resilienceLoadGeneration;
  const appType = selectedResilienceApp();
  const providersProbe = await safeGetJson(endpoint(endpoints.providerCreate, { appType }));
  if (generation !== resilienceLoadGeneration) return { warningCount: 0, stale: true };
  const providers = providersProbe.ok ? objectRows(providersProbe.data) : [];
  renderResilienceProviders(providers);
  const [
    circuitConfig,
    streamConfig,
    autoFailover,
    queue,
    available,
  ] = await Promise.all([
    safeGetJson(endpoints.circuitConfig),
    safeGetJson(endpoints.streamCheckConfig),
    safeGetJson(endpoint(endpoints.autoFailover, { appType })),
    safeGetJson(endpoint(endpoints.failoverQueue, { appType })),
    safeGetJson(endpoint(endpoints.availableFailover, { appType })),
  ]);
  if (generation !== resilienceLoadGeneration) return { warningCount: 0, stale: true };

  if (circuitConfig.ok && !circuitFormDirty) fillCircuitForm(circuitConfig.data);
  if (streamConfig.ok && !streamFormDirty) fillStreamForm(streamConfig.data);
  const queueRows = queue.ok ? arrayFrom(queue.data, []) : [];
  const availableRows = available.ok ? arrayFrom(available.data, []) : [];
  const autoState = autoFailover.ok ? stateText(autoFailover.data) : autoFailover.error;
  resilienceAutoFailoverEnabled = autoFailover.ok && autoFailover.data === true;
  const autoButton = $("resilience-toggle-auto");
  if (autoButton) {
    autoButton.textContent = resilienceAutoFailoverEnabled
      ? "Turn Automatic Backup Off"
      : "Turn Automatic Backup On";
  }
  text("resilience-auto-state", autoState);
  text("resilience-queue-count", compact(queueRows.length));
  setSetupState("resilience-circuit-status", circuitFormDirty ? "Unsaved changes" : circuitConfig.ok ? "Configured" : "Unavailable", circuitConfig.ok && !circuitFormDirty);
  setSetupState("resilience-stream-status", streamFormDirty ? "Unsaved changes" : streamConfig.ok ? "Configured" : "Unavailable", streamConfig.ok && !streamFormDirty);
  renderProviderActionStack("failover-queue", queueRows, "No backup providers yet", "remove-failover");
  renderProviderActionStack("available-failover", availableRows, "No other providers available", "add-failover");
  const providerResult = await loadResilienceProvider();
  return {
    warningCount: providerResult.warningCount || [providersProbe, circuitConfig, streamConfig, autoFailover, queue, available]
      .some((probe) => !probe.ok && probe.error !== "No provider selected") ? 1 : 0,
  };
}

async function loadResilienceProvider() {
  const generation = ++resilienceLoadGeneration;
  const appType = selectedResilienceApp();
  const providerId = selectedResilienceProvider();
  if (!providerId) {
    text("resilience-circuit-state", "No provider selected");
    text("resilience-limit-state", "No provider selected");
    return {warningCount: 0};
  }
  const params = {appType, providerId};
  const [stats, limits] = await Promise.all([
    safeGetJson(endpoint(endpoints.circuitStats, params)),
    safeGetJson(endpoint(endpoints.providerLimits, params)),
  ]);
  if (generation !== resilienceLoadGeneration) return {warningCount: 0, stale: true};
  text("resilience-circuit-state", stats.ok ? firstString(stats.data, ["state"], "Unknown") : stats.error);
  text("resilience-limit-state", limits.ok ? firstString(limits.data, ["status", "state"], "Loaded") : limits.error);
  return {warningCount: stats.ok && limits.ok ? 0 : 1};
}

async function saveResilienceConfig(kind) {
  const circuit = kind === "circuit";
  const payload = circuit ? circuitConfigPayload() : streamConfigPayload();
  await postJson(circuit ? endpoints.circuitConfig : endpoints.streamCheckConfig, payload);
  const current = circuit ? circuitConfigPayload() : streamConfigPayload();
  if (JSON.stringify(current) === JSON.stringify(payload)) {
    if (circuit) circuitFormDirty = false;
    else streamFormDirty = false;
  }
  return loadResilience();
}
