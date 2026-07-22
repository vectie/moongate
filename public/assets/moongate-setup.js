let setupLoadGeneration = 0;
let bindingRows = [];

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

function bindingStateLabel(binding) {
  if (!binding.installed) return "Not installed";
  if (binding.bound === true) return "Connected";
  if (binding.bindingState === "stale") return "Needs repair";
  if (binding.bindingMode === "manual") return "Manual setup";
  return "Not connected";
}

function bindingStateClass(binding) {
  if (binding.bound === true) return "state good";
  if (binding.bindingState === "stale") return "state bad";
  return "state warn";
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
      return `<option value="${escapeHtml(id)}"${selected}>${escapeHtml(name)}</option>`;
    })
    .join("");
}

function bindingProviderCell(row) {
  const binding = row.binding;
  if (!binding.installed) return "<small>Install the app first</small>";
  if (binding.bindingMode === "manual") return "<small>Selected inside the app</small>";
  const options = bindingProviderOptions(row);
  if (!options) return `<button type="button" class="button-secondary" data-binding-action="add-provider" data-app="${escapeHtml(row.app.id)}">Add Provider</button>`;
  return `<select data-binding-provider="${escapeHtml(row.app.id)}" aria-label="Provider for ${escapeHtml(row.app.label)}">${options}</select>`;
}

function bindingActions(row) {
  const binding = row.binding;
  const app = escapeHtml(row.app.id);
  if (!binding.installed) return "<small>No action available</small>";
  if (binding.bindingMode === "manual") {
    return `<button type="button" class="button-secondary" data-binding-action="manual" data-app="${app}">Manual Steps</button>`;
  }
  if (row.providers.filter((provider) => provider.builtIn !== true && provider.enabled !== false).length === 0) {
    return `<button type="button" data-binding-action="add-provider" data-app="${app}">Add Provider First</button>`;
  }
  if (binding.bound === true) {
    return `<div class="inline-actions">
      <button type="button" data-binding-action="bind" data-app="${app}">Apply Provider</button>
      <button type="button" class="button-secondary" data-binding-action="verify" data-app="${app}">Verify</button>
      <button type="button" class="danger-ghost" data-binding-action="unbind" data-app="${app}">Disconnect</button>
    </div>`;
  }
  const label = binding.bindingState === "stale" ? "Repair Connection" : "Connect App";
  return `<div class="inline-actions">
    <button type="button" data-binding-action="bind" data-app="${app}">${label}</button>
    <button type="button" class="button-secondary" data-binding-action="verify" data-app="${app}">Verify</button>
  </div>`;
}

function connectionGraphRoute(app) {
  const routes = {
    moondesk: ["OpenAI Responses", "/v1/responses"],
    codex: ["OpenAI Responses", "/v1/responses"],
    claude: ["Anthropic Messages", "/v1/messages"],
    "claude-desktop": ["Claude Desktop Messages", "/claude-desktop/v1/messages"],
    gemini: ["Gemini Native", "/gemini/v1beta/…"],
    opencode: ["OpenAI Chat", "/v1/chat/completions"],
    openclaw: ["OpenClaw Chat", "/openclaw/v1/chat/completions"],
    hermes: ["OpenAI Chat", "/v1/chat/completions"],
  };
  const [label, path] = routes[app.id] || ["Local AI route", "MoonGate local API"];
  return { label, path };
}

function connectionGraphCheck(label, tone) {
  return `<span class="graph-check ${tone}">${escapeHtml(label)}</span>`;
}

function connectionGraphTestState(provider, providerAppType) {
  const providerId = firstString(provider, ["id", "providerId"], "");
  const latest = providerTestResults.get(providerRouteKey(providerAppType, providerId));
  if (latest) {
    const passed = latest.networkRequestPerformed === true && latest.success === true;
    return {
      passed,
      tone: passed ? "good" : "bad",
      label: passed ? "Tested: passed" : "Tested: failed",
    };
  }
  const health = firstString(provider, ["healthStatus"], "unknown").toLowerCase();
  if (health === "healthy") return { passed: true, tone: "good", label: "Tested: passed" };
  if (health === "unhealthy") return { passed: false, tone: "bad", label: "Tested: failed" };
  return { passed: false, tone: "warn", label: "Not tested" };
}

function connectionGraphLane(row, provider) {
  const { app, binding } = row;
  const route = connectionGraphRoute(app);
  const providerAppType = app.providerAppType || app.id;
  if (!provider) {
    const reason = row.warning ? "Provider data unavailable" : "No provider saved";
    const appState = !binding.installed
      ? "App not installed"
      : binding.bindingMode === "manual"
        ? "Manual wiring required"
        : "Waiting for a provider";
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
          ${connectionGraphCheck(binding.installed ? "Installed" : "Not installed", binding.installed ? "good" : "warn")}
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
  const routeReady = enabled && test.passed;
  const verified = bindingVerified && routeReady;
  let result = "Not selected or wired";
  let resultTone = "warn";
  if (verified) {
    result = "Connected and verified";
    resultTone = "good";
  } else if (!binding.installed) {
    result = "App not installed";
  } else if (!enabled) {
    result = "Provider disabled";
    resultTone = "bad";
  } else if (test.tone === "bad") {
    result = bindingVerified ? "App verified; provider test failed" : "Provider test failed";
    resultTone = "bad";
  } else if (test.tone === "warn") {
    result = bindingVerified ? "App verified; provider not tested" : "Provider not tested";
  } else if (binding.bindingMode === "manual") {
    result = "Manual wiring required";
  } else if (selected && binding.bindingState === "stale") {
    result = "Binding needs repair";
    resultTone = "bad";
  } else if (selected) {
    result = "Selected, app not wired";
  }
  return `<div class="connection-lane ${verified ? "verified" : resultTone === "bad" ? "blocked" : "unwired"}" data-graph-app="${escapeHtml(app.id)}" data-graph-provider="${escapeHtml(providerId)}">
    <div class="connection-node provider-node">
      <span class="connection-node-label">Provider</span>
      <strong>${escapeHtml(providerName)}</strong>
      <small>${escapeHtml(model)}</small>
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
        ${connectionGraphCheck(binding.installed ? "Installed" : "Not installed", binding.installed ? "good" : "warn")}
        ${connectionGraphCheck(bound ? "Bound" : "Not bound", bound ? "good" : "warn")}
        ${connectionGraphCheck(bindingVerified ? "Verified" : "Not verified", bindingVerified ? "good" : "warn")}
      </div>
    </div>
    <span class="connection-lane-result ${resultTone}">${escapeHtml(result)}</span>
  </div>`;
}

function renderConnectionGraph(rows) {
  const target = $("connection-graph-routes");
  if (!target) return;
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
    const verifiedForApp = providers.filter((provider) => {
      const id = firstString(provider, ["id", "providerId"], "");
      const test = connectionGraphTestState(provider, providerAppType);
      return row.binding.bound === true &&
        row.binding.bindingState === "bound" &&
        id === currentProviderId &&
        provider.enabled !== false &&
        test.passed;
    }).length;
    verifiedRoutes += verifiedForApp;
    const bindingVerified = row.binding.bound === true && row.binding.bindingState === "bound";
    if (!bindingVerified) unwiredApps += 1;
    const lanes = providers.length > 0
      ? providers.map((provider) => connectionGraphLane(row, provider)).join("")
      : connectionGraphLane(row, null);
    const appState = verifiedForApp > 0
      ? connectionGraphCheck("Route verified", "good")
      : bindingVerified
        ? connectionGraphCheck("Binding verified", "warn")
      : row.binding.installed
        ? connectionGraphCheck("Not wired", "warn")
        : connectionGraphCheck("Not installed", "warn");
    return `<section class="connection-app" data-graph-section="${escapeHtml(row.app.id)}">
      <header class="connection-app-head">
        <div><span class="connection-app-order">${row.app.priority === 0 ? "Priority app" : "Supported app"}</span><h3>${escapeHtml(row.app.label)}</h3></div>
        ${appState}
      </header>
      <div class="connection-app-lanes">${lanes}</div>
    </section>`;
  });
  target.innerHTML = sections.join("");
  text("connection-graph-verified", verifiedRoutes);
  text("connection-graph-configured", configuredRoutes);
  text("connection-graph-unwired", unwiredApps);
  text(
    "connection-graph-status",
    `${verifiedRoutes} verified route${verifiedRoutes === 1 ? "" : "s"} · ${configuredRoutes} configured route${configuredRoutes === 1 ? "" : "s"} · ${unwiredApps} app${unwiredApps === 1 ? "" : "s"} not wired`,
  );
}

function renderBindingRows(rows) {
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
      const version = firstString(binding, ["version"], "");
      const installation = binding.installed ? `Installed${version ? ` · ${version}` : ""}` : "Not installed";
      const providerName = firstString(binding, ["currentProviderName"], "");
      const detail = binding.bound && providerName ? `<small>Using ${escapeHtml(providerName)}</small>` : "";
      return `<tr data-binding-row="${escapeHtml(row.app.id)}">
        <td><strong>${escapeHtml(row.app.label)}</strong><small>${escapeHtml(row.app.id)}</small></td>
        <td><span class="${binding.installed ? "state good" : "state warn"}">${escapeHtml(installation)}</span></td>
        <td><span class="${bindingStateClass(binding)}">${escapeHtml(bindingStateLabel(binding))}</span>${detail}</td>
        <td>${bindingProviderCell(row)}</td>
        <td>${bindingActions(row)}</td>
      </tr>`;
    })
    .join("");
  const installed = bindingRows.filter((row) => row.binding.installed).length;
  const connected = bindingRows.filter((row) => row.binding.bound === true).length;
  text("binding-status", `${connected} connected · ${installed} installed · ${bindingRows.length} supported app types`);
  text("framework-total", compact(connected));
  text("framework-detail", `${installed} installed app${installed === 1 ? "" : "s"}`);
  renderConnectionGraph(bindingRows);
  mergeReadinessState({ bindingCount: connected, installedAppCount: installed });
}

async function loadBindingRow(app) {
  const providerAppType = app.providerAppType || app.id;
  const [bindingProbe, providerProbe] = await Promise.all([
    safeGetJson(endpoint(endpoints.appBinding, { appType: app.id })),
    safeGetJson(endpoint(endpoints.providerCreate, { appType: providerAppType })),
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

async function loadSetupStatus() {
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
    Promise.all(frameworkApps.map(loadBindingRow)),
  ]);
  if (generation !== setupLoadGeneration) return { warningCount: 0, stale: true };

  renderBindingRows(rows);
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
  const providerId = selectedBindingProvider(appType);
  if (!providerId) throw new Error("Choose a provider before connecting the app");
  text("binding-status", `Connecting ${providerTemplateFrameworkLabel(appType)}…`);
  const result = await postJson(endpoints.appBinding, { appType, providerId });
  if (result?.bound !== true) throw new Error("The app configuration did not verify after it was written");
  await loadSetupStatus();
  text("binding-status", `${providerTemplateFrameworkLabel(appType)} is connected and verified`);
}

async function unbindApp(appType) {
  text("binding-status", `Disconnecting ${providerTemplateFrameworkLabel(appType)}…`);
  const result = await deleteJson(endpoints.appBinding, { appType });
  if (result?.bound === true) throw new Error("The app still reports a MoonGate binding");
  await loadSetupStatus();
  text("binding-status", `${providerTemplateFrameworkLabel(appType)} is disconnected`);
}

async function verifyBinding(appType) {
  const result = await getJson(endpoint(endpoints.appBinding, { appType }));
  await loadSetupStatus();
  text("binding-status", result.bound === true
    ? `${providerTemplateFrameworkLabel(appType)} connection verified`
    : `${providerTemplateFrameworkLabel(appType)} is not connected to MoonGate`);
}
