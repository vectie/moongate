let resilienceLoadGeneration = 0;

function selectedResilienceApp() {
  return $("resilience-app")?.value || "codex";
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
  if (generation !== resilienceLoadGeneration) return { warningCount: 0, stale: true };

  if (circuitConfig.ok) fillCircuitForm(circuitConfig.data);
  if (streamConfig.ok) fillStreamForm(streamConfig.data);
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
  const circuitState = circuitStats.ok && circuitStats.data ? firstString(circuitStats.data, ["state"], "closed") : "Unknown";
  const limitText = limits.ok ? firstString(limits.data, ["status", "state"], "Loaded") : "Unknown";

  text("resilience-auto-state", autoState);
  text("resilience-circuit-state", circuitState);
  text("resilience-queue-count", compact(queueRows.length));
  text("resilience-limit-state", limitText);
  setSetupState("resilience-circuit-status", circuitConfig.ok ? "Configured" : "Unavailable", circuitConfig.ok);
  setSetupState("resilience-stream-status", streamConfig.ok ? "Configured" : "Unavailable", streamConfig.ok);
  renderProviderActionStack("failover-queue", queueRows, "No backup providers yet", "remove-failover");
  renderProviderActionStack("available-failover", availableRows, "No other providers available", "add-failover");
  return {
    warningCount: [providersProbe, circuitConfig, streamConfig, autoFailover, queue, available, circuitStats, limits]
      .some((probe) => !probe.ok && probe.error !== "No provider selected") ? 1 : 0,
  };
}
