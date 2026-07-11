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

async function loadFrameworkRow(app) {
  try {
    const [providersJson, currentJson] = await Promise.all([
      getJson(endpoint(endpoints.providerCreate, { appType: app.id })),
      getJson(endpoint(endpoints.providerCurrent, { appType: app.id })),
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
  mergeReadinessState({
    providerCount: rows.reduce((total, row) => total + (row.providers || []).length, 0),
    frameworkErrorCount: rows.filter((row) => row.error).length,
  });
  return rows;
}
