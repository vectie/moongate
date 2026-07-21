let frameworkRows = [];
let builtinProviderTemplates = [];
let importedProviderTemplates = [];
let frameworkLoadGeneration = 0;
let providerTemplateLoadGeneration = 0;

function renderProviderRows(data, error = "") {
  const rows = arrayFrom(data, ["providers", "items", "data", "health"]);
  text("provider-count", `${rows.length} route${rows.length === 1 ? "" : "s"}`);
  const target = $("provider-rows");
  if (!target) return;
  target.innerHTML = "";
  if (rows.length === 0) {
    target.innerHTML = error
      ? `<tr><td colspan="5"><strong>Provider routes unavailable</strong><small>${escapeHtml(error)}</small></td></tr>`
      : `<tr><td colspan="5">No provider routes configured.</td></tr>`;
    return;
  }
  for (const row of rows.slice(0, 12)) {
    const providerId = firstString(row, ["providerId", "id", "providerName", "name"]);
    const provider = firstString(row, ["providerName", "name"], providerId);
    const app = firstString(row, ["appType", "app", "type"]);
    const status = firstString(row, ["healthStatus", "status", "state", "health", "isHealthy", "is_healthy"], "unknown");
    const model = firstString(
      row,
      ["model", "modelId", "activeModel", "routeModel"],
      firstString(row.modelMapping, ["defaultModel"], "-"),
    );
    const error = firstString(row, ["lastError", "error", "message"], "");
    const metadata = [
      row.isCurrent === true ? "Current route" : "",
      row.builtIn === true ? "Built-in" : row.origin === "user" ? "Configured" : firstString(row, ["origin"], ""),
    ].filter(Boolean).join(" · ");
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><strong>${escapeHtml(provider)}</strong>${metadata ? `<small>${escapeHtml(metadata)}</small>` : ""}${error ? `<small>${escapeHtml(error)}</small>` : ""}</td>
      <td>${escapeHtml(app)}</td>
      <td><span class="${stateClass(status)}">${escapeHtml(status)}</span></td>
      <td>${escapeHtml(model)}</td>
      <td><button type="button" class="button-secondary" data-provider-edit="${escapeHtml(providerId)}" data-provider-app="${escapeHtml(app)}">Edit</button></td>
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
  if (row.mode === "additive") {
    if (providers.length === 0) return `<small>No live providers</small>`;
    return `<small>${providers.length} live provider${providers.length === 1 ? "" : "s"}</small>`;
  }
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
  const builtInCount = providers.filter((provider) => provider.builtIn === true).length;
  const configuredCount = providers.length - builtInCount;
  const countParts = [];
  if (configuredCount > 0) countParts.push(`${configuredCount} configured`);
  if (builtInCount > 0) countParts.push(`${builtInCount} built-in`);
  return `
    <div class="provider-picker">
      <select data-provider-picker="${escapeHtml(row.id)}" aria-label="${escapeHtml(row.label)} configured providers">${options}</select>
      <small>${escapeHtml(countParts.join(" · ") || "No providers")}</small>
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
  $("provider-original-app").value = "";
  $("provider-app").value = appType || $("provider-app").value || "claude";
  $("provider-app").disabled = false;
  $("provider-id").value = "";
  $("provider-id").readOnly = false;
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
  $("provider-clear-api-key").checked = false;
  $("provider-clear-models").checked = false;
  text("provider-credential-status", "No stored credential");
  setProviderStatus("New provider");
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
    const appType = firstString(provider, ["appType"], firstString(row, ["appType"], ""));
    const providerId = firstString(provider, ["id", "providerId"], "");
    const providerName = firstString(provider, ["name", "providerName"], "");
    if (!appType || !providerId || !providerName) return [];
    const templateId = firstString(row, ["templateId", "id"], `${appType}:${providerId}:${index}`);
    return [{
      key: `${source}:${templateId}:${index}`,
      label: firstString(provider, ["templateLabel"], firstString(row, ["label"], providerName)),
      provider: { ...provider, appType, id: providerId, name: providerName },
      source,
    }];
  });
}

function providerTemplateFrameworkLabel(appType) {
  return frameworkApps.find((app) => app.id === appType)?.label || appType;
}

function providerTemplateApiFormatLabel(provider) {
  const format = firstString(provider, ["apiFormat"], "");
  if (format === "openai") return "OpenAI Responses";
  if (format === "openai_chat") return "OpenAI Chat Completions";
  if (format === "anthropic") return "Anthropic Messages";
  if (format === "gemini_native") return "Gemini Native";
  return "Default protocol";
}

function providerTemplateOptionLabel(row) {
  const provider = row.provider;
  return `${row.source} — ${row.label} · ${providerTemplateFrameworkLabel(provider.appType)} · ${providerTemplateApiFormatLabel(provider)}`;
}

function renderProviderTemplates() {
  const select = $("provider-template");
  if (!select) return;
  const previous = select.value;
  const rows = [...builtinProviderTemplates, ...importedProviderTemplates];
  select.innerHTML = [
    `<option value="">Choose a template</option>`,
    ...rows.map((row) => `<option value="${escapeHtml(row.key)}">${escapeHtml(providerTemplateOptionLabel(row))}</option>`),
  ].join("");
  if (rows.some((row) => row.key === previous)) select.value = previous;
  const frameworkCount = new Set(rows.map((row) => row.provider.appType)).size;
  text(
    "provider-template-status",
    rows.length > 0
      ? `${rows.length} ready template${rows.length === 1 ? "" : "s"} across ${frameworkCount} framework${frameworkCount === 1 ? "" : "s"}; selecting one changes Framework automatically. API keys stay separate.`
      : "No ready templates. Load a JSON file to add one.",
  );
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
  return [...builtinProviderTemplates, ...importedProviderTemplates]
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
    text(
      "provider-credential-status",
      existing.credentialState === "stored"
        ? "Stored API key will be retained unless explicitly removed."
        : existing.credentialState === "oauth"
          ? "Uses OAuth authentication; account status is shown in Setup."
          : "No stored API key.",
    );
  }
  const mapping = provider.modelMapping || {};
  for (const [key, id] of [
    ["defaultModel", "provider-default-model"],
    ["sonnetModel", "provider-sonnet-model"],
    ["haikuModel", "provider-haiku-model"],
    ["opusModel", "provider-opus-model"],
  ]) {
    $(id).value = typeof mapping[key] === "string" ? mapping[key] : "";
  }
  setProviderStatus(existing ? `Template applied to existing ${provider.id}` : `Template ready for ${provider.id}`);
  text("provider-template-status", "Template applied. Enter the API key, review, then save.");
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
  const provider = providerById(appType, providerId);
  if (!provider) {
    clearProviderForm(appType);
    setProviderStatus("Provider not found in current view");
    return;
  }
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
  text(
    "provider-credential-status",
    provider.credentialState === "stored"
      ? "Stored API key will be retained unless explicitly removed."
      : provider.credentialState === "oauth"
        ? "Uses OAuth authentication; account status is shown in Setup."
        : "No stored API key.",
  );
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
  setProviderStatus(`Editing ${providerId}${provider.builtIn === true ? " (built-in route)" : ""}`);
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
  if ($("provider-clear-api-key").checked) payload.clearApiKey = true;
  if ($("provider-clear-models").checked) payload.clearModelMapping = true;
  return payload;
}

async function saveProvider() {
  const payload = providerPayloadFromForm();
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
    setProviderStatus(`Updated ${payload.id}`);
  } else {
    await postJson(endpoints.providerCreate, payload);
    setProviderStatus(`Created ${payload.id}`);
  }
  await refresh();
  editProvider(payload.appType, payload.id);
}

async function deleteProviderFromForm() {
  const appType = $("provider-original-app").value.trim() || $("provider-app").value;
  const providerId = $("provider-original-id").value.trim() || $("provider-id").value.trim();
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
  const payload = providerPayloadFromForm();
  const appType = payload.appType;
  const providerId = payload.id;
  if (!providerId) {
    setProviderStatus("Select a provider before testing");
    return;
  }
  const result = await postJson(endpoints.providerStreamCheck, {
    ...payload,
    providerId,
    draft: true,
  });
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
  const generation = ++frameworkLoadGeneration;
  const rows = await Promise.all(frameworkApps.map(loadFrameworkRow));
  if (generation !== frameworkLoadGeneration) return { rows: [], warningCount: 0, stale: true };
  renderFrameworkRows(rows);
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
