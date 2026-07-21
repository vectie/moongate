let suiteLoadGeneration = 0;

function suitePurpose(id, fallback) {
  const purposes = {
    moondesk: "Primary desktop control app",
    moonclaw: "AI agent app",
    moonbook: "Reports and saved output",
    moontown: "Schedules and automation",
  };
  return purposes[id] || fallback || "Connected Moon app";
}

function suiteUsage(id, fallback) {
  const usage = {
    moondesk: "Controls health, providers, models, and usage",
    moonclaw: "Sends AI requests through MoonGate",
    moonbook: "Reads usage summaries for reports",
    moontown: "Checks MoonGate health for scheduled work",
  };
  return usage[id] || fallback || "Uses MoonGate services";
}

function suiteConnectionLabel(keyRoute) {
  return keyRoute && keyRoute !== "-" ? "Ready" : "Not published";
}

function renderSuiteApps(apps, integrations) {
  const target = $("suite-app-rows");
  if (!target) return;
  target.innerHTML = "";
  if (apps.length === 0) {
    target.innerHTML = `<tr><td colspan="4">No suite app contract data.</td></tr>`;
    return;
  }
  const sortedApps = [...apps].sort((left, right) => {
    const leftPriority = number(left?.priority ?? (firstString(left, ["id"]) === "moondesk" ? 0 : 100));
    const rightPriority = number(right?.priority ?? (firstString(right, ["id"]) === "moondesk" ? 0 : 100));
    return leftPriority - rightPriority;
  });
  for (const app of sortedApps) {
    const id = firstString(app, ["id", "app", "name"]);
    const integration = integrations && typeof integrations === "object" ? integrations[id] : null;
    const keyRoute = firstString(
      integration,
      ["healthUrl", "usageSummaryUrl", "streamCheckAllProvidersUrl", "modelsUrl", "providerPresetsUrl"],
      firstString(app, ["primaryRoute", "route"], "-"),
    );
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><strong>${escapeHtml(id)}</strong>${id === "moondesk" ? `<small>Primary</small>` : ""}</td>
      <td>${escapeHtml(suitePurpose(id, firstString(app, ["role", "kind"])))}</td>
      <td>${escapeHtml(suiteUsage(id, firstString(app, ["usage", "description"])))}</td>
      <td><span class="state ${keyRoute && keyRoute !== "-" ? "good" : "warn"}">${suiteConnectionLabel(keyRoute)}</span></td>
    `;
    target.appendChild(tr);
  }
}

function renderSuiteIntegrations(integrations) {
  const target = $("suite-integrations");
  if (!target) return;
  target.innerHTML = "";
  const rows = objectRows(integrations).sort((left, right) => {
    const leftPriority = number(left.priority ?? (left.id === "moondesk" ? 0 : 100));
    const rightPriority = number(right.priority ?? (right.id === "moondesk" ? 0 : 100));
    return leftPriority - rightPriority;
  });
  if (rows.length === 0) {
    target.innerHTML = `<div class="row-card"><strong>No suite integrations</strong><small>Manifest did not publish integration metadata.</small></div>`;
    return;
  }
  for (const row of rows) {
    const adapters = arrayFrom(row.adapterPackages, []).map((item) => String(item));
    const div = document.createElement("div");
    div.className = "row-card";
    div.innerHTML = `
      <div>
        <strong>${escapeHtml(row.id)}${row.id === "moondesk" ? " · Primary" : ""}</strong>
        <small>${escapeHtml(suiteUsage(row.id, "Connection details are available"))}</small>
      </div>
      <strong>${escapeHtml(adapters.length ? `${adapters.length} connection${adapters.length === 1 ? "" : "s"}` : "Ready")}</strong>
    `;
    target.appendChild(div);
  }
}

async function loadSuite() {
  const generation = ++suiteLoadGeneration;
  const [manifestProbe, statusProbe, providersProbe] = await Promise.all([
    safeGetJson(endpoints.suiteManifest),
    safeGetJson(endpoints.suiteStatus),
    safeGetJson(endpoints.suiteMoonclawProviders),
  ]);
  if (generation !== suiteLoadGeneration) return { warningCount: 0, stale: true };
  const manifest = manifestProbe.ok ? manifestProbe.data : {};
  const status = statusProbe.ok ? statusProbe.data : {};
  const apps = arrayFrom(manifest.apps, []);
  const capabilities = arrayFrom(manifest.capabilities, []);
  const integrations = manifest.suiteIntegrations || {};
  const providerRows = providersProbe.ok ? recordCount(providersProbe.data, ["providers"]) : 0;
  const rawStatus = firstString(status, ["status"], manifestProbe.ok ? "available" : "unavailable");
  text("suite-status-state", stateClass(rawStatus).includes("good") ? "Connected" : rawStatus);
  text("suite-app-count", compact(apps.length));
  text("suite-capability-count", compact(capabilities.length));
  text("suite-provider-count", providersProbe.ok ? compact(providerRows) : "Unavailable");
  text("suite-status-path", firstString(status, ["statusPath"], firstString(manifest, ["statusFile"])));
  renderSuiteApps(apps, integrations);
  renderSuiteIntegrations(integrations);
  return {
    warningCount: [manifestProbe, statusProbe, providersProbe].some((probe) => !probe.ok) ? 1 : 0,
  };
}
