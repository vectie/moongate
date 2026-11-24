// One projection for the Apps table, graph and first-run journey.
function connectionState(row, provider, runtime = readinessState) {
  const binding = row.binding || {};
  const id = provider?.id || provider?.providerId || "";
  const scope = row.app.providerAppType || row.app.id;
  const test = provider ? savedProviderTestResult(provider, scope, id) : null;
  const saved = Boolean(provider);
  const enabled = saved && provider.enabled !== false;
  const selected = saved && binding.currentProviderId === id;
  const wired = selected && binding.bound === true && binding.bindingState === "bound";
  const tested = test?.networkRequestPerformed === true && test?.success === true;
  const running = runtime.healthOk === true && runtime.proxyRunning === true;
  const ready = !row.warning && wired && enabled && tested && running;
  let label = "Not connected";
  let tone = "warn";
  if (row.warning) { label = "Connection unavailable"; tone = "bad"; }
  else if (!binding.installed && row.app.detectionSupported !== false) label = "Not installed";
  else if (binding.bindingMode === "manual") label = "Manual setup";
  else if (!saved) label = "Add a provider";
  else if (!enabled) label = "Provider paused";
  else if (binding.bindingState === "stale") { label = "Needs repair"; tone = "bad"; }
  else if (!wired) label = "Not connected";
  else if (!running) label = "Routing stopped";
  else if (test && !tested) { label = "Provider test failed"; tone = "bad"; }
  else if (!tested) label = "Test provider";
  else { label = "Connected and verified"; tone = "good"; }
  return {saved, enabled, selected, wired, tested, running, ready, label, tone, test};
}

function primaryConnection() {
  const row = bindingRows.find(row => row.app.id === "moondesk");
  if (!row) return null;
  const provider = configuredConnectionProvider(row);
  return {row, provider, state: connectionState(row, provider)};
}

function configuredConnectionProvider(row) {
  return row.providers.find(p => (p.id || p.providerId) === row.binding.currentProviderId)
    || row.providers.find(p => p.builtIn !== true && p.enabled !== false)
    || row.providers.find(p => p.builtIn !== true);
}
