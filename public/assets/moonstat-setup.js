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
  if (typeof value === "string") {
    const lower = value.toLowerCase();
    return lower.includes("ok") || lower.includes("ready") || lower.includes("true") || lower.includes("authenticated");
  }
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
    .map(([label, value, good]) => {
      return `
        <div class="setup-row">
          <span>${escapeHtml(label)}</span>
          <strong class="${stateClass(good ? "ok" : value)}">${escapeHtml(value)}</strong>
        </div>
      `;
    })
    .join("");
}

function configStatusText(probe) {
  if (!probe.ok) return probe.error;
  return firstString(probe.data, ["status", "state"], setupProbeText(probe, ["configured", "exists", "available"], "Available"));
}

function renderSetupConfigRows(configRows, takeoverProbe) {
  const target = $("setup-config-rows");
  if (!target) return;
  target.innerHTML = "";
  for (const row of configRows) {
    const takeover = takeoverProbe.ok ? takeoverProbe.data?.[row.app.id] : null;
    const configText = configStatusText(row.probe);
    const takeoverText = takeover == null ? "Unknown" : stateText(takeover);
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><strong>${escapeHtml(row.app.label)}</strong><small>${escapeHtml(row.app.id)}</small></td>
      <td><span class="${stateClass(row.probe.ok ? configText : "error")}">${escapeHtml(configText)}</span></td>
      <td><span class="${stateClass(takeoverText)}">${escapeHtml(takeoverText)}</span></td>
      <td><button type="button" data-setup-action="open-config" data-app="${escapeHtml(row.app.id)}">Open Config</button></td>
    `;
    target.appendChild(tr);
  }
}

async function loadSetupStatus() {
  const authProviders = [
    ["Codex OAuth", "codex_oauth"],
    ["GitHub Copilot", "github_copilot"],
  ];
  const [
    runtimeProbe,
    toolsProbe,
    proxyRunningProbe,
    takeoverProbe,
    desktopProbe,
    mcpProbe,
    pluginProbe,
    pluginAppliedProbe,
    settingsProbe,
    authRows,
    configRows,
  ] = await Promise.all([
    safeGetJson(endpoints.portableMode),
    safeGetJson(endpoint(endpoints.toolsVersions, { tools: "codex,claude,gemini,opencode" })),
    safeGetJson(endpoints.proxyRunning),
    safeGetJson(endpoints.takeoverStatus),
    safeGetJson(endpoints.claudeDesktopStatus),
    safeGetJson(endpoints.mcpServers),
    safeGetJson(endpoints.pluginClaudeStatus),
    safeGetJson(endpoints.pluginClaudeApplied),
    safeGetJson(endpoints.settings),
    Promise.all(
      authProviders.map(async ([label, provider]) => ({
        label,
        probe: await safeGetJson(endpoint(endpoints.authStatus, { authProvider: provider })),
      })),
    ),
    Promise.all(
      frameworkApps.map(async (app) => ({
        app,
        probe: await safeGetJson(endpoint(endpoints.configStatus, { appType: app.id })),
      })),
    ),
  ]);

  const authenticated = authRows.filter((row) => setupProbeGood(row.probe, ["authenticated", "hasAccount", "loggedIn"])).length;
  setSetupState("setup-auth-state", authenticated > 0 ? `${authenticated} active` : "Ready", authRows.some((row) => row.probe.ok));
  renderSetupList(
    "setup-auth-rows",
    authRows.map((row) => [
      row.label,
      setupProbeText(row.probe, ["authenticated", "hasAccount", "loggedIn", "status"], "No account"),
      setupProbeGood(row.probe, ["authenticated", "hasAccount", "loggedIn", "status"]),
    ]),
  );

  const proxyRunning = proxyRunningProbe.ok ? proxyRunningProbe.data === true : false;
  setSetupState("setup-runtime-state", proxyRunning ? "Proxy on" : "Available", runtimeProbe.ok || proxyRunningProbe.ok);
  renderSetupList("setup-runtime-rows", [
    ["Portable Mode", setupProbeText(runtimeProbe, [], runtimeProbe.ok ? stateText(runtimeProbe.data) : "Unavailable"), runtimeProbe.ok],
    ["Proxy Running", proxyRunningProbe.ok ? stateText(proxyRunningProbe.data) : proxyRunningProbe.error, proxyRunning],
    ["Tool Versions", toolsProbe.ok ? `${recordCount(toolsProbe.data, ["tools", "versions"])} tools` : toolsProbe.error, toolsProbe.ok],
    ["Settings", settingsProbe.ok ? "Loaded" : settingsProbe.error, settingsProbe.ok],
  ]);

  const desktopConfigured = setupProbeGood(desktopProbe, ["configured", "gatewayTokenConfigured"]);
  setSetupState("setup-desktop-state", desktopConfigured ? "Configured" : "Available", desktopProbe.ok);
  renderSetupList("setup-desktop-rows", [
    ["Configured", setupProbeText(desktopProbe, ["configured"], "Unknown"), desktopConfigured],
    ["Mode", setupProbeText(desktopProbe, ["mode"], "Not selected"), desktopProbe.ok],
    ["Gateway Token", setupProbeText(desktopProbe, ["gatewayTokenConfigured"], "Unknown"), setupProbeGood(desktopProbe, ["gatewayTokenConfigured"])],
    ["Base URL", setupProbeText(desktopProbe, ["actualBaseUrl", "expectedBaseUrl"], "Not applied"), desktopProbe.ok],
  ]);

  const mcpCount = mcpProbe.ok ? recordCount(mcpProbe.data, ["servers", "items"]) : 0;
  const pluginReady = setupProbeGood(pluginProbe, ["exists"]) || (pluginAppliedProbe.ok && pluginAppliedProbe.data === true);
  setSetupState("setup-mcp-state", mcpCount > 0 || pluginReady ? "Configured" : "Ready", mcpProbe.ok || pluginProbe.ok);
  renderSetupList("setup-mcp-rows", [
    ["MCP Servers", mcpProbe.ok ? `${mcpCount} configured` : mcpProbe.error, mcpProbe.ok],
    ["Claude Plugin", setupProbeText(pluginProbe, ["exists"], "Unavailable"), setupProbeGood(pluginProbe, ["exists"])],
    ["Plugin Applied", pluginAppliedProbe.ok ? stateText(pluginAppliedProbe.data) : pluginAppliedProbe.error, pluginAppliedProbe.data === true],
  ]);

  renderSetupConfigRows(configRows, takeoverProbe);
}
