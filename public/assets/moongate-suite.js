function renderSuiteApps(apps, integrations) {
  const target = $("suite-app-rows");
  if (!target) return;
  target.innerHTML = "";
  if (apps.length === 0) {
    target.innerHTML = `<tr><td colspan="4">No suite app contract data.</td></tr>`;
    return;
  }
  for (const app of apps) {
    const id = firstString(app, ["id", "app", "name"]);
    const integration = integrations && typeof integrations === "object" ? integrations[id] : null;
    const keyRoute = firstString(
      integration,
      ["healthUrl", "usageSummaryUrl", "streamCheckAllProvidersUrl", "modelsUrl", "providerPresetsUrl"],
      firstString(app, ["primaryRoute", "route"], "-"),
    );
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><strong>${escapeHtml(id)}</strong></td>
      <td>${escapeHtml(firstString(app, ["role", "kind"]))}</td>
      <td>${escapeHtml(firstString(app, ["usage", "description"]))}</td>
      <td>${escapeHtml(keyRoute)}</td>
    `;
    target.appendChild(tr);
  }
}

function renderSuiteIntegrations(integrations) {
  const target = $("suite-integrations");
  if (!target) return;
  target.innerHTML = "";
  const rows = objectRows(integrations);
  if (rows.length === 0) {
    target.innerHTML = `<div class="row-card"><strong>No suite integrations</strong><small>Manifest did not publish integration metadata.</small></div>`;
    return;
  }
  for (const row of rows) {
    const urls = [
      firstString(row, ["healthUrl"], ""),
      firstString(row, ["usageSummaryUrl"], ""),
      firstString(row, ["providerPresetsUrl"], ""),
      firstString(row, ["streamCheckConfigUrl"], ""),
      firstString(row, ["configStatusUrl"], ""),
    ].filter(Boolean);
    const adapters = arrayFrom(row.adapterPackages, []).map((item) => String(item));
    const div = document.createElement("div");
    div.className = "row-card";
    div.innerHTML = `
      <div>
        <strong>${escapeHtml(row.id)}</strong>
        <small>${escapeHtml(urls.slice(0, 2).join(" | ") || adapters.slice(0, 3).join(" | ") || "Integration metadata ready")}</small>
      </div>
      <strong>${escapeHtml(adapters.length ? `${adapters.length} adapters` : "Ready")}</strong>
    `;
    target.appendChild(div);
  }
}

async function loadSuite() {
  const [manifestProbe, statusProbe, providersProbe] = await Promise.all([
    safeGetJson(endpoints.suiteManifest),
    safeGetJson(endpoints.suiteStatus),
    safeGetJson(endpoints.suiteMoonclawProviders),
  ]);
  const manifest = manifestProbe.ok ? manifestProbe.data : {};
  const status = statusProbe.ok ? statusProbe.data : {};
  const apps = arrayFrom(manifest.apps, []);
  const capabilities = arrayFrom(manifest.capabilities, []);
  const integrations = manifest.suiteIntegrations || {};
  const providerRows = providersProbe.ok ? recordCount(providersProbe.data, ["providers"]) : 0;
  text("suite-status-state", firstString(status, ["status"], manifestProbe.ok ? "available" : "unavailable"));
  text("suite-app-count", compact(apps.length));
  text("suite-capability-count", compact(capabilities.length));
  text("suite-status-path", firstString(status, ["statusPath"], firstString(manifest, ["statusFile"])));
  renderSuiteApps(apps, integrations);
  renderSuiteIntegrations(integrations);
  if (providerRows > 0) text("suite-capability-count", `${compact(capabilities.length)} / ${providerRows} providers`);
}
