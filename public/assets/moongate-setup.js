let setupLoadGeneration = 0;
let bindingRows = [];
let preferredBindingProvider = null;
const bindingErrors = new Map();
const bindingBusy = new Set();

async function runBindingAction(appType, action) {
  if (bindingBusy.has(appType)) return;
  bindingBusy.add(appType);
  bindingErrors.delete(appType);
  renderBindingRows(bindingRows);
  try { await action(appType); }
  catch (error) { bindingErrors.set(appType, error.message || String(error)); }
  finally { bindingBusy.delete(appType); renderBindingRows(bindingRows); }
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
  if (typeof value === "string") return stateClass(value).includes("good");
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
    .map(([label, value, good]) => `
      <div class="setup-row">
        <span>${escapeHtml(label)}</span>
        <strong class="${stateClass(good ? "ok" : value)}">${escapeHtml(value)}</strong>
      </div>
    `)
    .join("");
}

function bindingProviderOptions(row) {
  const available = row.providers.filter((provider) => provider.builtIn !== true && provider.enabled !== false);
  if (available.length === 0) return "";
  const selectedId = row.binding.currentProviderId || firstString(available[0], ["id", "providerId"], "");
  return available
    .map((provider) => {
      const id = firstString(provider, ["id", "providerId"], "");
      const name = firstString(provider, ["name", "providerName"], id);
      const selected = id === selectedId ? " selected" : "";
      return `<option value="${escapeHtml(id)}" data-i18n-scope="content"${selected}>${escapeHtml(name)}</option>`;
    })
    .join("");
}

function bindingProviderCell(row) {
  const binding = row.binding;
  if (!binding.installed && row.app.detectionSupported !== false) return "";
  if (binding.bindingMode === "manual") return "<small>Selected inside the app</small>";
  if (!binding.installed) return "";
  const options = bindingProviderOptions(row);
  if (!options) {
    const provider = configuredConnectionProvider(row);
    return provider ? content(firstString(provider, ["name", "providerName", "id"], "")) : "";
  }
  return `<select data-binding-provider="${escapeHtml(row.app.id)}" aria-label="Provider for ${escapeHtml(row.app.label)}">${options}</select>`;
}

function bindingActions(row) {
  const binding = row.binding;
  const app = escapeHtml(row.app.id);
  if (!binding.installed && row.app.detectionSupported !== false) return "";
  if (binding.bindingMode === "manual") {
    return `<button type="button" class="button-secondary" data-binding-action="manual" data-app="${app}">Manual Steps</button>`;
  }
  if (!binding.installed) return "";
  if (row.providers.filter((provider) => provider.builtIn !== true).length === 0) {
    return `<button type="button" data-binding-action="add-provider" data-app="${app}">Add Provider First</button>`;
  }
  if (binding.bound === true) {
    return `<div class="inline-actions">
      <button type="button" data-binding-action="bind" data-app="${app}" disabled>Apply Provider</button>
      <button type="button" class="button-secondary" data-binding-action="test-provider" data-app="${app}">Review Provider</button>
      <details class="local-menu"><summary>${escapeHtml(uiLabel("More"))}</summary>
        <button type="button" class="button-secondary" data-binding-action="stage" data-app="${app}">Stage change</button>
        <button type="button" class="button-secondary" data-binding-action="verify" data-app="${app}">Verify</button>
        <button type="button" class="danger-ghost" data-binding-action="unbind" data-app="${app}">Disconnect</button>
      </details>
    </div>`;
  }
  if (!row.providers.some(provider => provider.builtIn !== true && provider.enabled !== false)) {
    return `<button type="button" class="button-secondary" data-binding-action="test-provider" data-app="${app}">Review Provider</button>`;
  }
  const label = binding.bindingState === "stale" ? "Repair Connection" : "Connect App";
  return `<div class="inline-actions">
      <button type="button" data-binding-action="bind" data-app="${app}">${label}</button>
    <details class="local-menu"><summary>${escapeHtml(uiLabel("More"))}</summary>
      <button type="button" class="button-secondary" data-binding-action="stage" data-app="${app}">Stage change</button>
      <button type="button" class="button-secondary" data-binding-action="verify" data-app="${app}">Verify</button>
    </details>
  </div>`;
}

function connectionGraphRoute(app) {
  return { label: app.routeLabel || "Local AI route", path: app.routePath || "MoonGate local API" };
}

function connectionGraphCheck(label, tone) {
  return `<span class="graph-check ${tone}">${escapeHtml(uiLabel(label))}</span>`;
}

function connectionGraphTestState(provider, providerAppType) {
  const providerId = firstString(provider, ["id", "providerId"], "");
  const latest = savedProviderTestResult(provider, providerAppType, providerId);
  if (latest) {
    const passed = latest.networkRequestPerformed === true && latest.success === true;
    return {
      passed,
      tone: passed ? "good" : "bad",
      label: passed ? "Tested: passed" : "Tested: failed",
    };
  }
  return { passed: false, tone: "warn", label: "Not tested" };
}

function connectionGraphLane(row, provider) {
  const { app, binding } = row;
  const route = connectionGraphRoute(app);
  const providerAppType = app.providerAppType || app.id;
  if (!provider) {
    const reason = row.warning ? "Provider data unavailable" : "No provider saved";
    const appState = connectionState(row, null).label;
    return `<div class="connection-lane unwired" data-graph-app="${escapeHtml(app.id)}" data-graph-provider="">
      <div class="connection-node provider-node missing">
        <span class="connection-node-label">Provider</span>
        <strong>${escapeHtml(reason)}</strong>
        <div class="connection-node-checks">${connectionGraphCheck("Not saved", row.warning ? "bad" : "warn")}</div>
      </div>
      <div class="connection-arrow" aria-hidden="true"><span></span><b>→</b></div>
      <div class="connection-node route-node">
        <span class="connection-node-label">MoonGate route</span>
        <strong>${escapeHtml(route.label)}</strong>
        <code>${escapeHtml(route.path)}</code>
        <div class="connection-node-checks">${connectionGraphCheck("Waiting", "warn")}</div>
      </div>
      <div class="connection-arrow" aria-hidden="true"><span></span><b>→</b></div>
      <div class="connection-node app-node">
        <span class="connection-node-label">AI app</span>
        <strong>${escapeHtml(app.label)}</strong>
        <div class="connection-node-checks">
          ${connectionGraphCheck(app.detectionSupported === false ? "Manual setup" : binding.installed ? "Installed" : "Not installed", binding.installed ? "good" : "warn")}
          ${connectionGraphCheck("Not bound", "warn")}
          ${connectionGraphCheck("Not verified", "warn")}
        </div>
      </div>
      <span class="connection-lane-result warn">${escapeHtml(appState)}</span>
    </div>`;
  }

  const providerId = firstString(provider, ["id", "providerId"], "");
  const providerName = firstString(provider, ["name", "providerName"], providerId);
  const model = firstString(provider.modelMapping, ["defaultModel"], "No default model");
  const enabled = provider.enabled !== false;
  const test = connectionGraphTestState(provider, providerAppType);
  const selected = firstString(binding, ["currentProviderId"], "") === providerId;
  const bound = selected && binding.bound === true;
  const bindingVerified = bound && binding.bindingState === "bound";
  const state = connectionState(row, provider);
  const routeReady = selected && enabled && test.passed && state.running && !row.warning;
  const verified = state.ready;
  let result = state.label;
  let resultTone = state.tone;
  if (verified) {
    result = "Connected and verified";
    resultTone = "good";
  }
  return `<div class="connection-lane ${verified ? "verified" : resultTone === "bad" ? "blocked" : "unwired"}" data-graph-app="${escapeHtml(app.id)}" data-graph-provider="${escapeHtml(providerId)}">
    <div class="connection-node provider-node">
      <span class="connection-node-label">Provider</span>
      <strong>${content(providerName)}</strong>
      <small>${content(model)}</small>
      <div class="connection-node-checks">
        ${connectionGraphCheck(provider.builtIn === true ? "Built-in route" : "Saved", "good")}
        ${connectionGraphCheck(enabled ? "Enabled" : "Disabled", enabled ? "good" : "bad")}
        ${connectionGraphCheck(test.label, test.tone)}
      </div>
    </div>
    <div class="connection-arrow" aria-hidden="true"><span></span><b>→</b></div>
    <div class="connection-node route-node">
      <span class="connection-node-label">MoonGate route</span>
      <strong>${escapeHtml(route.label)}</strong>
      <code>${escapeHtml(route.path)}</code>
      <div class="connection-node-checks">
        ${connectionGraphCheck(selected ? "Selected" : "Not selected", selected ? "good" : "warn")}
        ${connectionGraphCheck(routeReady ? "Route ready" : "Route blocked", routeReady ? "good" : test.tone === "bad" || !enabled ? "bad" : "warn")}
      </div>
    </div>
    <div class="connection-arrow" aria-hidden="true"><span></span><b>→</b></div>
    <div class="connection-node app-node">
      <span class="connection-node-label">AI app</span>
      <strong>${escapeHtml(app.label)}</strong>
      <div class="connection-node-checks">
        ${connectionGraphCheck(app.detectionSupported === false ? "Manual setup" : binding.installed ? "Installed" : "Not installed", binding.installed ? "good" : "warn")}
        ${connectionGraphCheck(bound ? "Bound" : "Not bound", bound ? "good" : "warn")}
        ${connectionGraphCheck(bindingVerified ? "Verified" : "Not verified", bindingVerified ? "good" : "warn")}
      </div>
    </div>
    <span class="connection-lane-result ${resultTone}">${escapeHtml(uiLabel(result))}</span>
  </div>`;
}

function renderConnectionGraph(rows) {
  const target = $("connection-graph-routes");
  if (!target) return;
  const expanded = new Set(Array.from(target.querySelectorAll('details[open]')).map(node => node.dataset.graphSection));
  let configuredRoutes = 0;
  let verifiedRoutes = 0;
  let unwiredApps = 0;
  const sections = rows.map((row) => {
    const currentProviderId = firstString(row.binding, ["currentProviderId"], "");
    const providerAppType = row.app.providerAppType || row.app.id;
    const providers = row.providers
      .filter((provider) => provider.builtIn !== true || (row.binding.bound === true && firstString(provider, ["id", "providerId"], "") === currentProviderId))
      .sort((left, right) => {
        const leftId = firstString(left, ["id", "providerId"], "");
        const rightId = firstString(right, ["id", "providerId"], "");
        if ((leftId === currentProviderId) !== (rightId === currentProviderId)) return leftId === currentProviderId ? -1 : 1;
        if ((left.enabled !== false) !== (right.enabled !== false)) return left.enabled !== false ? -1 : 1;
        return firstString(left, ["name", "providerName"], leftId).localeCompare(firstString(right, ["name", "providerName"], rightId));
      });
    configuredRoutes += providers.length;
    const verifiedForApp = providers.filter(provider => connectionState(row, provider).ready).length;
    verifiedRoutes += verifiedForApp;
    const bindingVerified = row.binding.bound === true && row.binding.bindingState === "bound";
    if (!bindingVerified) unwiredApps += 1;
    const primary = providers.find(provider => firstString(provider, ["id", "providerId"], "") === currentProviderId) || providers[0];
    const alternatives = providers.filter(provider => provider !== primary);
    const alternativeKey = `alternatives-${row.app.id}`;
    const lanes = connectionGraphLane(row, primary || null) + (alternatives.length
      ? `<details class="advanced-disclosure" data-graph-section="${escapeHtml(alternativeKey)}" ${expanded.has(alternativeKey) ? "open" : ""}>
          <summary>${escapeHtml(uiLabel("Other saved providers"))}</summary>
          ${alternatives.map(provider => connectionGraphLane(row, provider)).join("")}
        </details>` : "");
    const appState = row.app.detectionSupported === false ? connectionGraphCheck("Manual setup", "warn") : verifiedForApp > 0
      ? connectionGraphCheck("Route verified", "good")
      : bindingVerified
        ? connectionGraphCheck("Binding verified", "warn")
      : row.binding.installed
        ? connectionGraphCheck("Not wired", "warn")
        : connectionGraphCheck("Not installed", "warn");
    const collapsed = !row.binding.installed && row.app.detectionSupported !== false;
    const tag = collapsed ? "details" : "section";
    const head = collapsed ? "summary" : "header";
    return `<${tag} class="connection-app" data-graph-section="${escapeHtml(row.app.id)}" ${collapsed && expanded.has(row.app.id) ? "open" : ""}>
      <${head} class="connection-app-head">
        <div><h3>${content(row.app.label)}</h3></div>${collapsed || row.app.detectionSupported === false ? appState : ""}
      </${head}>
      <div class="connection-app-lanes">${lanes}</div>
    </${tag}>`;
  });
  target.innerHTML = sections.join("");
  text("connection-graph-verified", verifiedRoutes);
  text("connection-graph-configured", configuredRoutes);
  text("connection-graph-unwired", unwiredApps);
  text("connection-graph-status", "");
  $("connection-graph-status").hidden = true;
}

function renderBindingRows(rows) {
  const selections = new Map(Array.from(document.querySelectorAll('[data-binding-provider]')).map(el => [el.dataset.bindingProvider, el.value]));
  bindingRows = rows.slice().sort((left, right) => {
    const byPriority = Number(left.app.priority ?? 100) - Number(right.app.priority ?? 100);
    if (byPriority !== 0) return byPriority;
    if (left.binding.installed !== right.binding.installed) return left.binding.installed ? -1 : 1;
    if (left.binding.bound !== right.binding.bound) return left.binding.bound ? -1 : 1;
    return left.app.label.localeCompare(right.app.label);
  });
  const target = $("binding-rows");
  if (!target) return;
  target.innerHTML = bindingRows
    .map((row) => {
      const binding = row.binding;
      const selectedProvider = configuredConnectionProvider(row);
      const state = connectionState(row, selectedProvider);
      const providerName = firstString(binding, ["currentProviderName"], "");
      const detail = binding.bound && providerName ? `<small>${content(providerName)}</small>` : "";
      return `<tr data-binding-row="${escapeHtml(row.app.id)}">
        <td><strong>${content(row.app.label)}</strong></td>
        <td><span class="state ${state.tone}">${escapeHtml(uiLabel(state.label))}</span>${detail}</td>
        <td>${bindingProviderCell(row)}</td>
        <td>${bindingActions(row)}${bindingErrors.has(row.app.id) ? `<small class="state bad">${escapeHtml(bindingErrors.get(row.app.id))}</small>` : ""}</td>
      </tr>`;
    })
    .join("");
  for (const select of document.querySelectorAll('[data-binding-provider]')) {
    const row = bindingRows.find(row => row.app.id === select.dataset.bindingProvider);
    const previous = preferredBindingProvider?.scope === (row?.app.providerAppType || row?.app.id)
      ? preferredBindingProvider.id : selections.get(select.dataset.bindingProvider);
    if (previous && Array.from(select.options).some(option => option.value === previous)) select.value = previous;
    const apply = document.querySelector(`[data-binding-action="bind"][data-app="${select.dataset.bindingProvider}"]`);
    if (apply) apply.disabled = row.binding.bound === true && select.value === row.binding.currentProviderId;
  }
  preferredBindingProvider = null;
  for (const app of bindingBusy) document.querySelectorAll(`[data-binding-row="${app}"] button`).forEach(button => { button.disabled = true; });
  const installed = bindingRows.filter((row) => row.binding.installed).length;
  const connected = bindingRows.filter((row) => row.binding.bound === true).length;
  text("binding-status", "");
  $("binding-status").hidden = true;
  text("framework-total", compact(connected));
  text("framework-detail", `${installed} installed app${installed === 1 ? "" : "s"}`);
  renderBindingPlan();
  mergeReadinessState({ bindingCount: connected, installedAppCount: installed });
}

async function loadBindingRow(app) {
  const providerAppType = app.providerAppType || app.id;
  const [bindingProbe, providerProbe] = await Promise.all([
    safeGetJson(endpoint(endpoints.appBinding, { appType: app.id })),
    sharedGetJson(endpoint(endpoints.providerCreate, { appType: providerAppType })),
  ]);
  const binding = bindingProbe.ok
    ? bindingProbe.data
    : {
        appType: app.id,
        installed: false,
        bound: false,
        bindingMode: "manual",
        bindingState: "unavailable",
        detectionError: bindingProbe.error,
      };
  return {
    app,
    binding,
    providers: providerProbe.ok ? objectRows(providerProbe.data) : [],
    warning: !bindingProbe.ok || !providerProbe.ok,
  };
}

async function loadSetupStatus({primaryOnly = false} = {}) {
  const apps = primaryOnly ? frameworkApps.filter(app => app.id === "moondesk") : frameworkApps;
  const rows = await Promise.all(apps.map(loadBindingRow));
  renderBindingRows(rows);
  return { warningCount: rows.some(row => row.warning) ? 1 : 0 };
}

async function loadSetupDetails() {
  const generation = ++setupLoadGeneration;
  const authProviders = [
    ["Codex OAuth", "codex_oauth"],
    ["GitHub Copilot", "github_copilot"],
  ];
  const [runtimeProbe, proxyRunningProbe, mcpProbe, pluginProbe, pluginAppliedProbe, settingsProbe, authRows, rows] = await Promise.all([
    safeGetJson(endpoints.portableMode),
    safeGetJson(endpoints.proxyRunning),
    safeGetJson(endpoints.mcpServers),
    safeGetJson(endpoints.pluginClaudeStatus),
    safeGetJson(endpoints.pluginClaudeApplied),
    safeGetJson(endpoints.settings),
    Promise.all(authProviders.map(async ([label, provider]) => ({
      label,
      probe: await safeGetJson(endpoint(endpoints.authStatus, { authProvider: provider })),
    }))),
    Promise.resolve(bindingRows),
  ]);
  if (generation !== setupLoadGeneration) return { warningCount: 0, stale: true };

  const authenticated = authRows.filter((row) => setupProbeGood(row.probe, ["authenticated", "hasAccount", "loggedIn"])).length;
  setSetupState("setup-auth-state", authenticated > 0 ? `${authenticated} active` : "No accounts", authenticated > 0);
  renderSetupList("setup-auth-rows", authRows.map((row) => [
    row.label,
    setupProbeText(row.probe, ["authenticated", "hasAccount", "loggedIn", "status"], "No account"),
    setupProbeGood(row.probe, ["authenticated", "hasAccount", "loggedIn", "status"]),
  ]));

  const proxyRunning = proxyRunningProbe.ok && proxyRunningProbe.data === true;
  setSetupState("setup-runtime-state", proxyRunning ? "Running" : "Stopped", proxyRunning);
  renderSetupList("setup-runtime-rows", [
    ["Local request gateway", proxyRunningProbe.ok ? (proxyRunning ? "Running" : "Stopped") : proxyRunningProbe.error, proxyRunning],
    ["Portable storage (advanced)", setupProbeText(runtimeProbe, [], runtimeProbe.ok ? stateText(runtimeProbe.data) : "Unavailable"), runtimeProbe.ok],
    ["MoonGate settings", settingsProbe.ok ? "Loaded" : settingsProbe.error, settingsProbe.ok],
  ]);

  const mcpCount = mcpProbe.ok ? recordCount(mcpProbe.data, ["servers", "items"]) : 0;
  const pluginReady = setupProbeGood(pluginProbe, ["exists"]) || (pluginAppliedProbe.ok && pluginAppliedProbe.data === true);
  setSetupState("setup-mcp-state", mcpCount > 0 || pluginReady ? "Detected" : "None", mcpCount > 0 || pluginReady);
  renderSetupList("setup-mcp-rows", [
    ["MCP connections", mcpProbe.ok ? `${mcpCount} configured` : mcpProbe.error, mcpCount > 0],
    ["Claude extension file", setupProbeText(pluginProbe, ["exists"], "Unavailable"), setupProbeGood(pluginProbe, ["exists"])],
    ["Claude extension active", pluginAppliedProbe.ok ? stateText(pluginAppliedProbe.data) : pluginAppliedProbe.error, pluginAppliedProbe.data === true],
  ]);

  return {
    warningCount:
      rows.some((row) => row.warning) ||
      [runtimeProbe, proxyRunningProbe, mcpProbe, pluginProbe, pluginAppliedProbe, settingsProbe].some((probe) => !probe.ok) ||
      authRows.some((row) => !row.probe.ok)
        ? 1
        : 0,
  };
}

function selectedBindingProvider(appType) {
  return document.querySelector(`[data-binding-provider="${appType}"]`)?.value || "";
}

async function bindApp(appType) {
  if (bindingPlanBusy) throw new Error("Wait for the binding plan to finish");
  if (bindingPlan.some(p => p.app.id === appType && p.status === "uncertain")) throw new Error("Reconcile the uncertain change before changing this app");
  const providerId = selectedBindingProvider(appType);
  if (!providerId) throw new Error("Choose a provider before connecting the app");
  text("binding-status", `Connecting ${providerTemplateFrameworkLabel(appType)}…`);
  const result = await postJson(endpoints.appBinding, { appType, providerId });
  if (result?.bound !== true) throw new Error("The app configuration did not verify after it was written");
  invalidateSharedReads();
  await refresh();
  text("binding-status", `${providerTemplateFrameworkLabel(appType)} is connected and verified`);
}

async function unbindApp(appType) {
  if (bindingPlanBusy) throw new Error("Wait for the binding plan to finish");
  if (bindingPlan.some(p => p.app.id === appType && p.status === "uncertain")) throw new Error("Reconcile the uncertain change before changing this app");
  text("binding-status", `Disconnecting ${providerTemplateFrameworkLabel(appType)}…`);
  const result = await deleteJson(endpoints.appBinding, { appType });
  if (result?.bound === true) throw new Error("The app still reports a MoonGate binding");
  invalidateSharedReads();
  await refresh();
  text("binding-status", `${providerTemplateFrameworkLabel(appType)} is disconnected`);
}

async function verifyBinding(appType) {
  const result = await getJson(endpoint(endpoints.appBinding, { appType }));
  await loadSetupStatus();
  text("binding-status", result.bound === true
    ? `${providerTemplateFrameworkLabel(appType)} connection verified`
    : `${providerTemplateFrameworkLabel(appType)} is not connected to MoonGate`);
}

// A local staged plan changes only existing app bindings after explicit Apply.
// It is not an atomic backend transaction; each exact app is re-read before write.
let bindingPlan = [];
let bindingPlanBusy = false;
function bindingPlanIdentity(row, providerId) {
  const matches = row.providers.filter(p => firstString(p, ["id", "providerId"], "") === providerId);
  if (row.warning || row.binding.installed !== true || row.binding.bindingMode === "manual" ||
      matches.length !== 1 || matches[0].enabled === false || matches[0].builtIn === true) {
    throw new Error("App or selected provider unavailable; refresh and review again");
  }
  const p = matches[0];
  // Never copy credential fields into the plan or its visible preview.
  return JSON.stringify({app: row.app.id, installed: row.binding.installed,
    bound: row.binding.bound === true, mode: row.binding.bindingMode,
    state: row.binding.bindingState, current: row.binding.currentProviderId || "",
    provider: providerId, endpoint: p.baseUrl || "", format: p.apiFormat || "",
    models: p.modelMapping || {}, enabled: p.enabled !== false});
}
function stageBindingChange(appType) {
  if (bindingPlanBusy) throw new Error("Wait for the binding plan to finish");
  const row = bindingRows.find(r => r.app.id === appType);
  if (!row) throw new Error("Refresh the app list first");
  const providerId = selectedBindingProvider(appType);
  if (!providerId) throw new Error("Choose a provider first");
  const existing = bindingPlan.find(p => p.app.id === appType);
  if (existing?.status === "uncertain") throw new Error("Reconcile the uncertain change before replacing it");
  const identity = bindingPlanIdentity(row, providerId);
  if (row.binding.bound === true && row.binding.currentProviderId === providerId) {
    throw new Error("This app already uses that provider");
  }
  bindingPlan = bindingPlan.filter(p => p.app.id !== appType);
  bindingPlan.push({app: {...row.app}, providerId, before: row.binding.currentProviderId || "unbound",
    identity, status: "staged", note: "Awaiting explicit Apply"});
  renderBindingPlan();
}
function discardBindingPlan() {
  if (bindingPlanBusy) return;
  // Uncertain changes need a read before they may be staged again.
  bindingPlan = bindingPlan.filter(p => p.status === "uncertain");
  renderBindingPlan();
}
async function applyBindingPlan() {
  if (bindingPlanBusy || bindingPlan.some(p => p.status === "uncertain")) return;
  bindingPlanBusy = true;
  renderBindingPlan();
  try {
    for (const change of bindingPlan) {
      if (change.status !== "staged") continue;
      const fresh = await loadBindingRow(change.app);
      if (bindingPlanIdentity(fresh, change.providerId) !== change.identity) {
        change.status = "stale"; change.note = "Configuration changed; refresh and stage again";
        break;
      }
      change.status = "uncertain";
      change.note = "Write attempted; read configuration before any retry";
      renderBindingPlan();
      try {
        await postJson(endpoints.appBinding, {appType: change.app.id, providerId: change.providerId});
        const verified = await loadBindingRow(change.app);
        if (verified.warning || verified.binding.bound !== true || verified.binding.currentProviderId !== change.providerId) {
          throw new Error("Binding did not verify");
        }
        change.status = "applied"; change.note = "Configuration verified; provider availability not tested";
      } catch (_) { break; }
    }
  } catch (_) {
    const pending = bindingPlan.find(p => p.status === "staged");
    if (pending) { pending.status = "stale"; pending.note = "Could not recheck configuration; refresh and stage again"; }
  } finally {
    bindingPlanBusy = false;
    renderBindingPlan();
  }
}
async function reconcileBindingPlan() {
  if (bindingPlanBusy) return;
  bindingPlanBusy = true;
  renderBindingPlan();
  try {
    for (const change of bindingPlan.filter(p => p.status === "uncertain")) {
      const fresh = await loadBindingRow(change.app);
      if (fresh.warning) continue;
      if (fresh.binding.bound === true && fresh.binding.currentProviderId === change.providerId) {
        change.status = "applied"; change.note = "Read-back verified configuration; no second write";
      } else {
        change.status = "stale"; change.note = "Read-back differs; refresh and explicitly stage a new change";
      }
    }
  } finally { bindingPlanBusy = false; renderBindingPlan(); }
}
function renderBindingPlan() {
  let panel = $("binding-change-plan");
  if (!panel) {
    const table = $("binding-rows")?.closest?.("table");
    if (!table) return;
    panel = document.createElement("section");
    panel.id = "binding-change-plan";
    panel.className = "panel";
    table.insertAdjacentElement("afterend", panel);
  }
  panel.hidden = bindingPlan.length === 0;
  panel.innerHTML = `<h3>Staged app connections</h3><p>Apply writes each app configuration in order, stopping at the first problem. No automatic rollback.</p>`;
  for (const c of bindingPlan) {
    const row = document.createElement("p");
    row.textContent = `${c.app.label}: ${c.before} → ${c.providerId} · ${c.status} · ${c.note}`;
    panel.appendChild(row);
  }
  for (const [label, action, enabled] of [
    ["Apply staged changes", applyBindingPlan, bindingPlan.some(p => p.status === "staged") && !bindingPlan.some(p => p.status === "uncertain")],
    ["Reconcile uncertain changes", reconcileBindingPlan, bindingPlan.some(p => p.status === "uncertain")],
    ["Discard reviewed plan", discardBindingPlan, bindingPlan.length > 0],
  ]) {
    const button = document.createElement("button");
    button.type = "button"; button.textContent = label; button.disabled = bindingPlanBusy || !enabled;
    button.onclick = () => Promise.resolve(action()).catch(showError);
    panel.appendChild(button);
  }
}
