let suiteLoadGeneration = 0;

function suiteUsage(id) {
  return {
    moondesk: "Controls health, providers, models, and usage",
    moonclaw: "Sends AI requests through MoonGate",
    moonbook: "Reads usage summaries for reports",
    moontown: "Checks MoonGate health for scheduled work",
  }[id] || "Uses MoonGate services";
}

function renderSuiteApps(apps, integrations, error = "") {
  const target = $("suite-app-rows");
  if (!target) return;
  if (error || !apps.length) {
    target.innerHTML = `<tr><td colspan="3">${escapeHtml(uiLabel(error ? "Integration list unavailable. Try Refresh Suite." : "No published integrations."))}</td></tr>`;
    return;
  }
  target.innerHTML = [...apps].sort((a, b) =>
    number(a.priority ?? (a.id === "moondesk" ? 0 : 100)) - number(b.priority ?? (b.id === "moondesk" ? 0 : 100))
  ).map(app => {
    const id = firstString(app, ["id", "app", "name"]);
    const declared = Boolean(integrations?.[id]);
    return `<tr>
      <td>${content(frameworkApps.find(app => app.id === id)?.label || id)}</td>
      <td>${escapeHtml(uiLabel(suiteUsage(id)))}</td>
      <td>${escapeHtml(uiLabel(declared ? "Supported" : "Not published"))}</td>
    </tr>`;
  }).join("");
}

async function loadSuite() {
  const generation = ++suiteLoadGeneration;
  const [manifestProbe, statusProbe] = await Promise.all([
    safeGetJson(endpoints.suiteManifest),
    safeGetJson(endpoints.suiteStatus),
  ]);
  if (generation !== suiteLoadGeneration) return { warningCount: 0, stale: true };
  const manifest = manifestProbe.ok ? manifestProbe.data : {};
  const status = statusProbe.ok ? statusProbe.data : {};
  text("suite-status-path", firstString(status, ["statusPath"], firstString(manifest, ["statusFile"])));
  renderSuiteApps(arrayFrom(manifest.apps, []), manifest.suiteIntegrations, manifestProbe.ok ? "" : manifestProbe.error);
  return {warningCount: manifestProbe.ok && statusProbe.ok ? 0 : 1};
}
