let frameworkRows = [];
let builtinProviderTemplates = [];
let importedProviderTemplates = [];
let frameworkLoadGeneration = 0;
let providerTemplateLoadGeneration = 0;
let pendingProviderDeleteKey = "";
let selectedProviderKey = "";
let providerFormRevision = 0;
let providerTestGeneration = 0;
const providerTestResults = new Map();
let providerCatalogGeneration = 0;

function providerRouteKey(appType, providerId) {
  return `${appType}:${providerId}`;
}

function providerConfigIdentity(provider, appType, providerId) {
  // Only compare editor configuration, never API keys or arbitrary settings.
  return JSON.stringify([
    appType || firstString(provider, ["appType", "app", "type"], ""),
    providerId || firstString(provider, ["id", "providerId"], ""),
    firstString(provider, ["providerType", "category"], ""),
    firstString(provider, ["baseUrl", "websiteUrl"], ""),
    firstString(provider, ["apiFormat"], firstString(provider.settingsConfig, ["apiFormat"], "")),
    provider.isFullUrl === true,
    provider.codexFastMode === true || provider.settingsConfig?.codexFastMode === true,
    ...["defaultModel", "sonnetModel", "haikuModel", "opusModel"].map(
      (key) => firstString(provider.modelMapping, [key], ""),
    ),
    provider.clearModelMapping === true,
  ]);
}

function providerCredentialIdentity(provider) {
  return firstString(provider, ["credentialState"], provider?.hasApiKey === true ? "stored" : "missing");
}

function savedProviderTestResult(provider, appType, providerId) {
  const tested = providerTestResults.get(providerRouteKey(appType, providerId));
  return tested && tested.config === providerConfigIdentity(provider, appType, providerId)
    && tested.credential === providerCredentialIdentity(provider)
    ? tested.result : null;
}

function providerFormChanged(event) {
  if (["provider-template", "provider-template-file", "provider-app", "provider-models-select"].includes(event?.target?.id)) return;
  providerFormRevision += 1;
  if (["provider-base-url", "provider-api-format", "provider-type", "provider-api-key", "provider-clear-api-key"].includes(event?.target?.id)) {
    resetProviderModelCatalog();
    renderModelSuggestions(visibleProviderTemplates.filter(row => row.provider.baseUrl === $("provider-base-url").value).flatMap(row => row.models));
  }
  const originalApp = $("provider-original-app").value;
  const originalId = $("provider-original-id").value;
  const saved = providerById(originalApp, originalId);
  const draft = saved ? providerPayloadFromForm() : null;
  const connectionUnchanged = draft && !draft.apiKey && !draft.clearApiKey &&
    providerConfigIdentity(saved, originalApp, originalId) === providerConfigIdentity(draft, draft.appType, draft.id);
  setProviderTestResult(connectionUnchanged ? savedProviderTestResult(saved, originalApp, originalId) : null);
  $("provider-connect-app").disabled = true;
  setProviderStatus(connectionUnchanged ? "Unsaved changes" : "Unsaved changes · test again after editing");
}

function selectProviderRow(appType, providerId) {
  selectedProviderKey = appType && providerId ? providerRouteKey(appType, providerId) : "";
  document.querySelectorAll("tr[data-provider-row]").forEach((row) => {
    const selected = row.dataset.providerRow === selectedProviderKey;
    row.classList.toggle("selected", selected);
    row.setAttribute("aria-selected", selected ? "true" : "false");
  });
}

function providerFrameworkOrder(appType) {
  const apps = frameworkApps.filter(app => (app.providerAppType || app.id) === appType);
  return apps.length ? Math.min(...apps.map(app => app.priority)) : 1000;
}

function providerRequestApps() {
  return frameworkApps.filter((app) => !app.providerAppType).sort((a,b) => providerFrameworkOrder(a.id) - providerFrameworkOrder(b.id) || a.label.localeCompare(b.label));
}

function sortedProviderRows(rows) {
  return rows.slice().sort((left, right) => {
    const leftApp = firstString(left, ["appType", "app", "type"], "");
    const rightApp = firstString(right, ["appType", "app", "type"], "");
    const byFramework = providerFrameworkOrder(leftApp) - providerFrameworkOrder(rightApp);
    if (byFramework !== 0) return byFramework;
    if ((left.isCurrent === true) !== (right.isCurrent === true)) return left.isCurrent === true ? -1 : 1;
    const leftConfigured = left.origin === "user";
    const rightConfigured = right.origin === "user";
    if (leftConfigured !== rightConfigured) return leftConfigured ? -1 : 1;
    const leftIndex = Number.isFinite(left.sortIndex) ? left.sortIndex : Number.MAX_SAFE_INTEGER;
    const rightIndex = Number.isFinite(right.sortIndex) ? right.sortIndex : Number.MAX_SAFE_INTEGER;
    if (leftIndex !== rightIndex) return leftIndex - rightIndex;
    const leftName = firstString(left, ["providerName", "name", "providerId", "id"], "");
    const rightName = firstString(right, ["providerName", "name", "providerId", "id"], "");
    const byName = leftName.localeCompare(rightName, undefined, { sensitivity: "base" });
    if (byName !== 0) return byName;
    return firstString(left, ["providerId", "id"], "").localeCompare(firstString(right, ["providerId", "id"], ""));
  });
}

function renderProviderRows(data, error = "") {
  const rows = sortedProviderRows(
    arrayFrom(data, ["providers", "items", "data", "health"])
      .filter((provider) => provider.builtIn !== true),
  );
  text("provider-count", `${rows.length} provider${rows.length === 1 ? "" : "s"}`);
  const target = $("provider-rows");
  if (!target) return;
  target.innerHTML = "";
  if (rows.length === 0) {
    target.innerHTML = error
      ? `<tr><td colspan="4"><strong>Providers unavailable</strong><small>${escapeHtml(error)}</small></td></tr>`
      : `<tr><td colspan="4">No providers configured.</td></tr>`;
    return;
  }
  for (const row of rows) {
    const providerId = firstString(row, ["providerId", "id", "providerName", "name"]);
    const provider = firstString(row, ["providerName", "name"], providerId);
    const app = firstString(row, ["appType", "app", "type"]);
    const routeKey = providerRouteKey(app, providerId);
    const latestTest = savedProviderTestResult(row, app, providerId);
    const status = firstString(row, ["healthStatus", "status", "state", "health", "isHealthy", "is_healthy"], "unknown");
    const statusLabel = row.enabled === false
      ? "Paused"
      : latestTest
      ? latestTest.success === true && latestTest.networkRequestPerformed === true
        ? "Test passed"
        : "Test failed"
      : "Not tested";
    const testPassed = latestTest?.success === true && latestTest?.networkRequestPerformed === true;
    const statusClassName = latestTest ? `state ${testPassed ? "good" : "bad"}` : stateClass(statusLabel);
    const model = firstString(
      row,
      ["model", "modelId", "activeModel", "routeModel"],
      firstString(row.modelMapping, ["defaultModel"], "-"),
    );
    const error = firstString(row, ["lastError", "error", "message"], "");
    const credentialState = firstString(row, ["credentialState"], row.hasApiKey === true ? "stored" : "missing");
    const credentialLabel = credentialState === "oauth"
        ? "OAuth"
        : credentialState === "stored"
          ? ""
          : "API key needed";
    const credentialClass = credentialState === "oauth" ? "good" : "warn";
    const credentialStateHtml = credentialLabel
      ? `<span class="state ${credentialClass}">${escapeHtml(credentialLabel)}</span>`
      : "";
    const tr = document.createElement("tr");
    tr.dataset.providerRow = routeKey;
    tr.dataset.providerApp = app;
    tr.dataset.providerId = providerId;
    tr.tabIndex = 0;
    tr.setAttribute("aria-selected", routeKey === selectedProviderKey ? "true" : "false");
    tr.classList.toggle("selected", routeKey === selectedProviderKey);
    if (row.isCurrent === true) tr.dataset.currentProvider = "true";
    tr.innerHTML = `
      <td><strong>${content(provider)}</strong><small>${content(model)}</small>${error ? `<small>${escapeHtml(error)}</small>` : ""}</td>
      <td>${escapeHtml(providerTemplateFrameworkLabel(app))}</td>
      <td><div class="provider-state-stack">${credentialStateHtml}<span class="${statusClassName}">${escapeHtml(statusLabel)}</span></div></td>
      <td>${actionIcon("edit", "Edit", `data-provider-edit="${escapeHtml(providerId)}" data-provider-app="${escapeHtml(app)}"`)}</td>
    `;
    target.appendChild(tr);
  }
}

function initProviderAppSelect() {
  const select = $("provider-app");
  if (!select) return;
  select.innerHTML = providerRequestApps()
    .map((app) => `<option value="${escapeHtml(app.id)}">${escapeHtml(providerTemplateFrameworkLabel(app.id))}</option>`)
    .join("");
}

function initUsageAppSelect() {
  const select = $("usage-app");
  if (!select) return;
  select.innerHTML = scopeOptions({all: true});
}

function initResilienceAppSelect() {
  const select = $("resilience-app");
  if (!select) return;
  select.innerHTML = scopeOptions();
  select.value = providerScopes()[0]?.id || "";
}

function providerRow(appType) {
  return frameworkRows.find((row) => row.id === appType);
}

function providerById(appType, providerId) {
  const row = providerRow(appType);
  if (!row) return null;
  return (row.providers || []).find((provider) => {
    return firstString(provider, ["id", "providerId"], "") === providerId;
  }) || null;
}

function setProviderStatus(value) {
  text("provider-form-status", uiLabel(value));
  $("provider-form-status").hidden = !value;
}

function resetProviderDeleteConfirmation() {
  pendingProviderDeleteKey = "";
  const button = $("provider-delete");
  if (!button) return;
  button.textContent = "Delete Provider";
  button.classList.remove("delete-confirm");
}

function setProviderTestResult(result = null) {
  const target = $("provider-test-result");
  if (!target) return;
  target.classList.remove("good", "bad", "warn");
  if (!result) {
    target.classList.add("warn");
    target.textContent = "Not tested";
    return;
  }
  const live = result.networkRequestPerformed === true;
  const success = live && result.success === true;
  const status = Number.isFinite(result.httpStatus) ? `HTTP ${result.httpStatus}` : "no HTTP response";
  const model = firstString(result, ["modelUsed"], "unknown model");
  const latency = Number.isFinite(result.responseTimeMs) ? `${Math.round(result.responseTimeMs)} ms` : "latency unavailable";
  target.classList.add(success ? "good" : "bad");
  target.textContent = `${uiLabel(success ? "Live test passed" : "Live test failed")} · ${status} · ${model} · ${latency}${result.uiTestedAt ? ` · ${new Date(result.uiTestedAt).toLocaleTimeString(window.MoonSuiteI18n?.locale?.())}` : ""}`;
}

function setProviderCredentialState(provider = null) {
  const input = $("provider-api-key");
  const status = $("provider-credential-status");
  if (!input || !status) return;
  if (provider?.credentialState === "stored") {
    input.placeholder = "********";
    status.textContent = uiLabel("Stored (leave blank to keep)");
    status.hidden = false;
  } else if (provider?.credentialState === "oauth") {
    input.placeholder = "OAuth provider — no API key needed";
    status.textContent = uiLabel("OAuth managed");
    status.hidden = false;
  } else {
    input.placeholder = "Paste API key";
    status.textContent = "";
    status.hidden = true;
  }
}

function syncProviderProtocolFields() {
  const appType = $("provider-app")?.value || "";
  const apiFormat = $("provider-api-format")?.value || "";
  const showClaudeOverrides = appType === "claude" || appType === "claude-desktop" || apiFormat === "anthropic";
  for (const id of ["provider-sonnet-model", "provider-haiku-model", "provider-opus-model"]) {
    const label = $(id)?.closest("label");
    if (label) label.hidden = !showClaudeOverrides;
  }
  const fastMode = $("provider-fast-mode")?.closest("label");
  if (fastMode) fastMode.hidden = appType !== "codex";
}

function resolveProviderAppScope(appType) {
  const select = $("provider-app");
  const matched = frameworkApps.find((app) => app.id === appType);
  const candidate = matched?.providerAppType || appType || "openclaw";
  if (select && Array.from(select.options).some((opt) => opt.value === candidate)) {
    return candidate;
  }
  if (select && select.options.length > 0) {
    if (Array.from(select.options).some((opt) => opt.value === "openclaw")) return "openclaw";
    return select.options[0].value;
  }
  return candidate;
}

function switchProviderAppScope(appType) {
  const resolved = resolveProviderAppScope(appType);
  if ($("provider-app")) {
    $("provider-app").value = resolved;
    $("provider-app").disabled = false;
  }
  $("provider-original-id").value = "";
  $("provider-original-app").value = "";
  $("provider-id").readOnly = false;
  resetProviderDeleteConfirmation();
  setProviderTestResult();
  selectedProviderKey = "";
  selectProviderRow("", "");
  $("provider-delete").disabled = true;
  $("provider-connect-app").disabled = true;
  setProviderStatus("");
  syncProviderProtocolFields();
}

function clearProviderForm(appType, options = {}) {
  providerFormRevision += 1;
  resetProviderModelCatalog();
  resetProviderDeleteConfirmation();
  text("provider-original-id", "");
  $("provider-original-id").value = "";
  $("provider-original-app").value = "";
  $("provider-app").value = resolveProviderAppScope(appType || $("provider-app").value || "openclaw");
  $("provider-app").disabled = false;
  $("provider-id").value = "";
  $("provider-id").readOnly = false;
  $("provider-name").value = "";
  $("provider-template").value = options.preserveTemplate || "";
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
  $("provider-clear-api-key").checked = false;
  $("provider-clear-models").checked = false;
  setProviderCredentialState();
  setProviderTestResult();
  selectedProviderKey = "";
  selectProviderRow("", "");
  $("provider-delete").disabled = true;
  $("provider-connect-app").disabled = true;
  setProviderStatus("");
  syncProviderProtocolFields();
  const advanced = document.querySelector(".provider-advanced");
  if (advanced && options.expandAdvanced !== false) advanced.open = true;
}

function providerTemplateRows(data, source) {
  const rows = Array.isArray(data)
    ? data
    : data && Array.isArray(data.templates)
      ? data.templates
      : [];
  return rows.flatMap((row, index) => {
    if (!row || typeof row !== "object") return [];
    const provider = row.form || row.provider || (source === "JSON" ? row : null);
    if (!provider || typeof provider !== "object") return [];
    const appType = firstString(provider, ["appType"], firstString(row, ["providerAppType", "appType"], ""));
    const targetAppType = firstString(row, ["targetAppType", "appType"], appType);
    const targetAppLabel = firstString(
      row,
      ["targetAppLabel"],
      providerTemplateFrameworkLabel(targetAppType),
    );
    const targetPriority = Number.isFinite(row.targetPriority)
      ? row.targetPriority
      : Number(frameworkApps.find((app) => app.id === targetAppType)?.priority ?? 100);
    const providerId = firstString(provider, ["id", "providerId"], "");
    const providerName = firstString(provider, ["name", "providerName"], "");
    if (!appType || !providerId || !providerName) return [];
    const templateId = firstString(row, ["templateId", "id"], `${appType}:${providerId}:${index}`);
    return [{
      key: `${source}:${templateId}:${index}`,
      label: firstString(provider, ["templateLabel"], firstString(row, ["label"], providerName)),
      provider: { ...provider, appType, id: providerId, name: providerName },
      targetAppType,
      targetAppLabel,
      targetPriority,
      source,
      models: Array.isArray(row.models) ? row.models.filter(id => typeof id === "string") : [],
    }];
  });
}

function providerTemplateFrameworkLabel(appType) {
  if (appType === "openclaw") return uiLabel("Moon apps");
  return frameworkApps.find((app) => app.id === appType)?.label || appType;
}

function providerTemplateOptionLabel(row) {
  return row.provider.name;
}

function sortedProviderTemplates(rows) {
  return rows.slice().sort((left, right) => {
    const byPriority = left.targetPriority - right.targetPriority;
    if (byPriority !== 0) return byPriority;
    const byTarget = left.targetAppLabel.localeCompare(right.targetAppLabel);
    if (byTarget !== 0) return byTarget;
    const byProvider = left.label.localeCompare(right.label);
    if (byProvider !== 0) return byProvider;
    return left.source.localeCompare(right.source);
  });
}

function renderProviderTemplates() {
  const select = $("provider-template");
  if (!select) return;
  const previous = select.value;
  const available = sortedProviderTemplates([
    ...builtinProviderTemplates,
    ...importedProviderTemplates,
  ]);
  const groups = new Map();
  const scope = $("provider-app").value;
  for (const row of available.filter(row => row.provider.appType === scope)) {
    const openrouter = row.source === "Built-in" && row.provider.providerType === "openrouter";
    const group = openrouter ? "openrouter" : `${row.source}:${row.provider.id}`;
    const model = row.provider.modelMapping?.defaultModel;
    if (!groups.has(group)) groups.set(group, {...row, models: [], provider: {...row.provider}});
    const entry = groups.get(group);
    for (const id of [model, ...(row.models || [])]) {
      if (id && !entry.models.includes(id)) entry.models.push(id);
    }
    if (openrouter) {
      entry.provider.id = "openrouter";
      entry.provider.name = "OpenRouter";
      entry.provider.modelMapping = {defaultModel: "openrouter/free"};
    }
  }
  const rows = Array.from(groups.values());
  visibleProviderTemplates = rows;
  select.innerHTML = [
    `<option value="">${escapeHtml(uiLabel("Choose a provider"))}</option>`,
    `<option value="custom">${escapeHtml(uiLabel("Custom provider"))}</option>`,
    ...rows.map((row) => `<option value="${escapeHtml(row.key)}" data-i18n-scope="content">${escapeHtml(providerTemplateOptionLabel(row))}</option>`),
  ].join("");
  if (rows.some((row) => row.key === previous)) select.value = previous;
  text("provider-template-status", "");
  $("provider-template-status").hidden = true;
}

async function loadProviderTemplates() {
  const generation = ++providerTemplateLoadGeneration;
  const data = await getJson(endpoint(endpoints.providerPresets, { sortMode: "nameAsc" }));
  if (generation !== providerTemplateLoadGeneration) return;
  builtinProviderTemplates = providerTemplateRows(data, "Built-in");
  renderProviderTemplates();
}

function selectedProviderTemplate() {
  const key = $("provider-template")?.value || "";
  return visibleProviderTemplates
    .find((row) => row.key === key) || null;
}

function applyProviderTemplate() {
  const template = selectedProviderTemplate();
  if (!template) {
    text("provider-template-status", "Choose a template first.");
    return;
  }
  const provider = template.provider;
  const selectedKey = $("provider-template").value;
  const existing = providerById(provider.appType, provider.id);
  clearProviderForm(provider.appType);
  $("provider-template").value = selectedKey;
  $("provider-original-id").value = existing ? provider.id : "";
  $("provider-original-app").value = existing ? provider.appType : "";
  $("provider-app").value = provider.appType;
  $("provider-app").disabled = Boolean(existing);
  $("provider-id").value = provider.id;
  $("provider-id").readOnly = Boolean(existing && providerRow(provider.appType)?.mode !== "additive");
  $("provider-name").value = provider.name;
  $("provider-type").value = firstString(provider, ["providerType", "category"], "");
  $("provider-base-url").value = firstString(provider, ["baseUrl"], "");
  $("provider-api-format").value = firstString(provider, ["apiFormat"], "");
  $("provider-api-key").value = "";
  $("provider-notes").value = firstString(provider, ["notes"], "");
  $("provider-enabled").checked = provider.enabled !== false;
  $("provider-full-url").checked = provider.isFullUrl === true;
  $("provider-fast-mode").checked = provider.codexFastMode === true;
  if (existing) {
    setProviderCredentialState(existing);
    $("provider-delete").disabled = existing.builtIn === true;
  }
  const mapping = provider.modelMapping || {};
  renderModelSuggestions(template.models || [mapping.defaultModel]);
  for (const [key, id] of [
    ["defaultModel", "provider-default-model"],
    ["sonnetModel", "provider-sonnet-model"],
    ["haikuModel", "provider-haiku-model"],
    ["opusModel", "provider-opus-model"],
  ]) {
    $(id).value = typeof mapping[key] === "string" ? mapping[key] : "";
  }
  setProviderStatus("");
  text(
    "provider-template-status",
    "",
  );
}

async function loadProviderTemplateFile(file) {
  const sourceText = await file.text();
  const parsed = JSON.parse(sourceText);
  const rows = providerTemplateRows(parsed, "JSON");
  if (rows.length === 0) throw new Error("JSON contains no valid provider templates");
  importedProviderTemplates = rows;
  let savedLocally = true;
  try {
    localStorage.setItem("moongate.providerTemplates.v1", sourceText);
  } catch (_error) {
    savedLocally = false;
  }
  const first = rows[0];
  if (frameworkApps.some((app) => app.id === first.provider.appType)) {
    $("provider-app").value = first.provider.appType;
  }
  await loadProviderTemplates().catch(() => {});
  renderProviderTemplates();
  $("provider-template").value = first.key;
  text(
    "provider-template-status",
    `${rows.length} JSON template${rows.length === 1 ? "" : "s"} loaded${savedLocally ? " and saved locally" : " for this session"}.`,
  );
}

function loadCachedProviderTemplates() {
  try {
    const cached = localStorage.getItem("moongate.providerTemplates.v1");
    if (!cached) return;
    importedProviderTemplates = providerTemplateRows(JSON.parse(cached), "JSON");
  } catch (_error) {
    try {
      localStorage.removeItem("moongate.providerTemplates.v1");
    } catch (_ignored) {
      // Storage may be disabled; templates still work for the current session.
    }
    importedProviderTemplates = [];
  }
}

function editProvider(appType, providerId) {
  providerFormRevision += 1;
  resetProviderModelCatalog();
  const provider = providerById(appType, providerId);
  if (!provider) {
    clearProviderForm(appType);
    setProviderStatus("Provider not found in current view");
    return;
  }
  selectProviderRow(appType, providerId);
  $("provider-original-id").value = providerId;
  $("provider-original-app").value = appType;
  $("provider-app").value = appType;
  $("provider-app").disabled = true;
  $("provider-id").value = providerId;
  $("provider-name").value = firstString(provider, ["name", "providerName"], providerId);
  $("provider-type").value = firstString(provider, ["providerType", "category"], "");
  $("provider-base-url").value = firstString(provider, ["baseUrl", "websiteUrl"], "");
  $("provider-api-format").value = firstString(provider, ["apiFormat"], firstString(provider.settingsConfig, ["apiFormat"], ""));
  $("provider-api-key").value = "";
  setProviderCredentialState(provider);
  syncProviderProtocolFields();
  const mapping = provider.modelMapping || {};
  $("provider-default-model").value = firstString(mapping, ["defaultModel"], "");
  $("provider-sonnet-model").value = firstString(mapping, ["sonnetModel"], "");
  $("provider-haiku-model").value = firstString(mapping, ["haikuModel"], "");
  $("provider-opus-model").value = firstString(mapping, ["opusModel"], "");
  $("provider-notes").value = firstString(provider, ["notes"], "");
  $("provider-enabled").checked = provider.enabled !== false;
  $("provider-full-url").checked = provider.isFullUrl === true;
  $("provider-fast-mode").checked = provider.codexFastMode === true || provider.settingsConfig?.codexFastMode === true;
  $("provider-clear-api-key").checked = false;
  $("provider-clear-models").checked = false;
  $("provider-id").readOnly = providerRow(appType)?.mode !== "additive";
  resetProviderDeleteConfirmation();
  $("provider-delete").disabled = provider.builtIn === true;
  $("provider-delete").title = provider.builtIn === true
    ? "Built-in providers cannot be deleted"
    : "Delete this configured provider";
  setProviderTestResult(savedProviderTestResult(provider, appType, providerId));
  $("provider-connect-app").disabled = !savedProviderTestResult(provider, appType, providerId)?.success;
  renderModelSuggestions(builtinProviderTemplates.filter(row => row.provider.providerType === provider.providerType && row.provider.baseUrl === provider.baseUrl).map(row => row.provider.modelMapping?.defaultModel));
  setProviderStatus(`Editing ${providerId}${provider.builtIn === true ? " (built-in provider)" : ""}`);
  renderProviderTemplates();
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
  if (!$("provider-id").value.trim() && $("provider-name").value.trim()) {
    const base = $("provider-name").value.trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "provider";
    $("provider-id").value = providerById($("provider-app").value, base) ? `${base}-${Date.now().toString(36)}` : base;
  }
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
  if ($("provider-clear-api-key").checked) payload.clearApiKey = true;
  if ($("provider-clear-models").checked) payload.clearModelMapping = true;
  return payload;
}

async function saveProvider() {
  const payload = providerPayloadFromForm();
  const revision = providerFormRevision;
  if (!payload.id || !payload.name) {
    setProviderStatus("Provider ID and name are required");
    return;
  }
  const originalId = $("provider-original-id").value.trim();
  const originalAppType = $("provider-original-app").value.trim();
  if (originalId) {
    if (originalAppType && originalAppType !== payload.appType) {
      throw new Error("Changing a provider framework is not supported; create a new provider instead.");
    }
    payload.originalId = originalId;
    payload.originalAppType = originalAppType || payload.appType;
    await postJson(endpoints.providerUpdate, payload);
  } else {
    await postJson(endpoints.providerCreate, payload);
  }
  // Cosmetic edits and pausing do not change the tested connection.
  // Secrets never enter the proof; replacing one explicitly invalidates it.
  if (payload.apiKey || payload.clearApiKey) {
    providerTestResults.delete(providerRouteKey(originalAppType || payload.appType, originalId || payload.id));
    providerTestResults.delete(providerRouteKey(payload.appType, payload.id));
  }
  invalidateSharedReads();
  await loadFrameworks();
  if (revision !== providerFormRevision) {
    if ($("provider-id").value === payload.id && $("provider-app").value === payload.appType) {
      $("provider-original-id").value = payload.id;
      $("provider-original-app").value = payload.appType;
    }
    setProviderStatus("Saved the earlier draft. Current edits are unsaved.");
    return;
  }
  editProvider(payload.appType, payload.id);
  setProviderStatus(`${originalId ? "Updated" : "Created"} ${payload.id}`);
}

let providerActionBusy = false;
async function runProviderAction(action) {
  if (providerActionBusy) return;
  providerActionBusy = true;
  for (const id of ["provider-save", "provider-test", "provider-delete"]) $(id).disabled = true;
  try { await action(); }
  catch (error) { setProviderStatus(error.message || String(error)); }
  finally {
    providerActionBusy = false;
    $("provider-save").disabled = false;
    $("provider-test").disabled = false;
    const provider = providerById($("provider-original-app").value, $("provider-original-id").value);
    $("provider-delete").disabled = !provider || provider.builtIn === true;
  }
}

async function deleteProviderFromForm() {
  const appType = $("provider-original-app").value.trim() || $("provider-app").value;
  const providerId = $("provider-original-id").value.trim() || $("provider-id").value.trim();
  if (!providerId) {
    setProviderStatus("Select a provider before deleting");
    return;
  }
  const provider = providerById(appType, providerId);
  if (provider?.builtIn === true) {
    setProviderStatus("Built-in providers cannot be deleted");
    return;
  }
  const deleteKey = `${appType}:${providerId}`;
  if (pendingProviderDeleteKey !== deleteKey) {
    pendingProviderDeleteKey = deleteKey;
    $("provider-delete").textContent = "Confirm Delete";
    $("provider-delete").classList.add("delete-confirm");
    setProviderStatus(`Click Confirm Delete to permanently remove ${providerId}.`);
    return;
  }
  await deleteJson(endpoints.providerDelete, { appType, id: providerId });
  providerTestResults.delete(providerRouteKey(appType, providerId));
  clearProviderForm(appType);
  invalidateSharedReads();
  await loadFrameworks();
  setProviderStatus(`Deleted ${providerId}`);
}

async function testProviderFromForm() {
  const payload = providerPayloadFromForm();
  const appType = payload.appType;
  const providerId = payload.id;
  if (!providerId) {
    setProviderStatus("Select a provider before testing");
    return;
  }
  const revision = providerFormRevision;
  const generation = ++providerTestGeneration;
  const config = providerConfigIdentity(payload, appType, providerId);
  const provider = providerById(appType, providerId);
  // A draft key is used only by the existing request, never kept in test proof.
  const credential = payload.apiKey || payload.clearApiKey ? null : providerCredentialIdentity(provider);
  const unsaved = !provider || credential === null || config !== providerConfigIdentity(provider, appType, providerId);
  const isCurrent = () => revision === providerFormRevision && generation === providerTestGeneration;
  setProviderTestResult();
  setProviderStatus("Testing this configuration…");
  try {
    const result = await postJson(
      endpoints.providerStreamCheck,
      unsaved
        ? {
            ...payload,
            providerId,
            draft: true,
          }
        : {
            appType,
            providerId,
            draft: false,
          },
    );
    result.uiTestedAt = Date.now();
    if (!isCurrent()) return;
    // A draft result belongs to this editor, not to the saved provider's proof.
    if (!unsaved) {
      providerTestResults.set(providerRouteKey(appType, providerId), { config, credential, result });
    }
    setProviderTestResult(result);
    $("provider-connect-app").disabled = unsaved || result.success !== true || result.networkRequestPerformed !== true;
    if (provider) {
      await loadFrameworks();
      if (!isCurrent()) return;
    }
    if (result.networkRequestPerformed !== true) {
      setProviderStatus("Test rejected: the backend did not perform a network request");
      return;
    }
    const status = Number.isFinite(result.httpStatus) ? `HTTP ${result.httpStatus}` : "no HTTP response";
    setProviderStatus(`${firstString(result, ["message", "status"], "Provider test completed")} · ${status}${unsaved ? " · Draft tested; save to keep these changes" : ""}`);
  } catch (error) {
    if (isCurrent()) throw error;
  }
}

let visibleProviderTemplates = [];
function renderModelSuggestions(ids) {
  $("provider-models-select").innerHTML = Array.from(new Set(ids.filter(Boolean))).sort((a,b) => Number(b.endsWith(":free") || b === "openrouter/free") - Number(a.endsWith(":free") || a === "openrouter/free") || a.localeCompare(b)).map(id => `<option value="${escapeHtml(id)}" data-i18n-scope="content"></option>`).join("");
}

function resetProviderModelCatalog(message = "") {
  providerCatalogGeneration += 1;
  const select = $("provider-models-select");
  if (select) {
    select.innerHTML = "";
  }
  const refreshButton = $("provider-models-refresh");
  if (refreshButton) refreshButton.disabled = false;
  text("provider-models-status", message);
  $("provider-models-status").hidden = !message;
}

function providerCatalogTarget() {
  const appType = $("provider-original-app").value;
  const providerId = $("provider-original-id").value;
  const saved = providerById(appType, providerId);
  if (!saved || !providerId || $("provider-app").value !== appType || $("provider-id").value.trim() !== providerId) {
    throw new Error("Save this provider before refreshing models.");
  }
  const payload = providerPayloadFromForm();
  const connection = (provider) => JSON.stringify([
    firstString(provider, ["baseUrl", "websiteUrl"], ""),
    firstString(provider, ["apiFormat"], firstString(provider.settingsConfig, ["apiFormat"], "")),
    firstString(provider, ["providerType", "category"], ""),
    provider.isFullUrl === true,
  ]);
  if (payload.apiKey || payload.clearApiKey || connection(payload) !== connection(saved)) {
    throw new Error("Save connection or credential changes before refreshing models. Discovery uses only the saved provider.");
  }
  return { appType, providerId, identity: connection(saved), credential: providerCredentialIdentity(saved) };
}

async function refreshProviderModels() {
  resetProviderModelCatalog();
  let target;
  try {
    target = providerCatalogTarget();
  } catch (error) {
    text("provider-models-status", error.message);
    $("provider-models-status").hidden = false;
    return;
  }
  const generation = providerCatalogGeneration;
  const revision = providerFormRevision;
  const isCurrent = () => {
    if (generation !== providerCatalogGeneration || revision !== providerFormRevision) return false;
    try { return JSON.stringify(providerCatalogTarget()) === JSON.stringify(target); }
    catch (_error) { return false; }
  };
  $("provider-models-refresh").disabled = true;
  text("provider-models-status", `Fetching model IDs for ${target.providerId}… No model completion is requested.`);
  $("provider-models-status").hidden = false;
  try {
    const result = await getJson(endpoint(endpoints.providerModels, { appType: target.appType, providerId: target.providerId }));
    if (!isCurrent()) return;
    if (result?.appType !== target.appType || result?.providerId !== target.providerId || !Array.isArray(result.models)) {
      throw new Error("The model list did not match this saved provider. Refresh again.");
    }
    const ids = [];
    for (const model of result.models) {
      const id = model?.id;
      if (typeof id !== "string" || !id || id.length > 256 || /[\s\u0000-\u001f\u007f\u0085]/u.test(id)) {
        throw new Error("The provider returned an invalid model ID. Enter a model ID manually or refresh again.");
      }
      if (!ids.includes(id)) ids.push(id);
    }
    renderModelSuggestions(ids);
    text("provider-models-status", ids.length
      ? `${ids.length} model IDs found. Choose one, then Save Provider. Discovery does not prove model availability or change the active route.`
      : "The provider returned an empty model list. Your default model is unchanged; enter an ID manually or refresh again.");
  } catch (error) {
    if (isCurrent()) {
      text("provider-models-status", error.message || "Could not refresh models. Try again.");
    }
  } finally {
    if (generation === providerCatalogGeneration) {
      $("provider-models-refresh").disabled = false;
      if (!isCurrent()) resetProviderModelCatalog("The saved provider changed during discovery. Refresh its model list again.");
    }
  }
}

async function loadFrameworkRow(app) {
  try {
    const probe = await sharedGetJson(endpoint(endpoints.providerCreate, { appType: app.id }));
    if (!probe.ok) throw new Error(probe.error);
    return {
      ...app,
      providers: objectRows(probe.data),
    };
  } catch (error) {
    return { ...app, providers: [], error: error.message || String(error) };
  }
}

async function loadFrameworks() {
  const generation = ++frameworkLoadGeneration;
  const rows = await Promise.all(providerRequestApps().map(loadFrameworkRow));
  if (generation !== frameworkLoadGeneration) return { rows: [], warningCount: 0, stale: true };
  frameworkRows = rows;
  const allProviders = rows.flatMap((row) => row.providers || []);
  const errors = rows.filter((row) => row.error);
  renderProviderRows(allProviders, allProviders.length === 0 && errors.length > 0 ? errors[0].error : "");
  const builtInProviderCount = allProviders.filter((provider) => provider.builtIn === true).length;
  mergeReadinessState({
    providerCount: allProviders.length - builtInProviderCount,
    builtInProviderCount,
    frameworkErrorCount: errors.length,
  });
  return { rows, warningCount: errors.length > 0 ? 1 : 0 };
}
