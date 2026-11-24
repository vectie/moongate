let operationsPolicyState = null;
let operationsLoadGeneration = 0;
let operationsPolicyApp = null;
let routingShadowSaveInFlight = false;

function operationsAppType() {
  return $("operations-app")?.value || "openclaw";
}

function operationsField(object, snake, camel) {
  if (!object || typeof object !== "object") return undefined;
  if (Object.prototype.hasOwnProperty.call(object, snake)) return object[snake];
  return object[camel];
}

function operationsMilliseconds(value) {
  return value == null ? "No samples" : `${number(value).toLocaleString()} ms`;
}

function operationsSetStatus(id, message, error = false) {
  const node = $(id);
  if (!node) return;
  node.textContent = message;
  node.classList.toggle("bad", error);
  node.classList.toggle("good", !error);
}

function operationsInitApps() {
  const select = $("operations-app");
  if (!select || select.options.length > 0) return;
  select.innerHTML = scopeOptions();
  select.value = providerScopes()[0]?.id || "";
}

function renderOperationsMonitor(snapshot) {
  const latency = snapshot?.latency || {};
  const firstToken = operationsField(snapshot, "first_token", "firstToken") || {};
  text("operations-latency-p50", operationsMilliseconds(operationsField(latency, "p50_ms", "p50Ms")));
  text("operations-latency-p95", operationsMilliseconds(operationsField(latency, "p95_ms", "p95Ms")));
  text("operations-latency-p99", operationsMilliseconds(operationsField(latency, "p99_ms", "p99Ms")));
  text("operations-ttft-p95", operationsMilliseconds(operationsField(firstToken, "p95_ms", "p95Ms")));
  text("operations-inflight", operationsField(snapshot, "inflight_requests", "inflightRequests") ?? 0);
  text("operations-circuits", operationsField(snapshot, "circuit_open_count", "circuitOpenCount") ?? 0);
  text("operations-failovers", operationsField(snapshot, "failover_count", "failoverCount") ?? 0);
  const configured = operationsField(snapshot, "quota_configured_count", "quotaConfiguredCount") ?? 0;
  const exceeded = operationsField(snapshot, "quota_exceeded_count", "quotaExceededCount") ?? 0;
  const costNano = operationsField(snapshot, "recent_cost_nano_usd", "recentCostNanoUsd") ?? 0;
  operationsSetStatus(
    "operations-monitor-status",
    `Recent request window: ${configured} configured quota${configured === 1 ? "" : "s"}, ${exceeded} exceeded; estimated cost ${money(number(costNano) / 1_000_000_000)}.`,
    false,
  );
}

function renderRoutingPolicy(state, appType = operationsAppType()) {
  if (appType !== operationsAppType()) return;
  operationsPolicyApp = appType;
  operationsPolicyState = state;
  const draft = state?.draft;
  const active = state?.active;
  const lastShadow = state?.lastShadowDecision;
  const draftRevision = operationsField(draft, "revision", "revision");
  const policyId = operationsField(draft, "policy_id", "policyId");
  const mode = operationsField(draft, "mode", "mode");
  if (policyId) $("routing-policy-id").value = policyId;
  if (mode) $("routing-policy-mode").value = mode;
  if (draft && $("routing-policy-weights")) {
    $("routing-policy-weights").value = JSON.stringify(draft.weights || {}, null, 2);
  }
  const limits = operationsField(draft, "concurrency_limits", "concurrencyLimits");
  if (draft && $("routing-policy-limits")) {
    $("routing-policy-limits").value = JSON.stringify(limits || {}, null, 2);
  }
  text("routing-draft-revision", draftRevision ?? "None");
  text("routing-shadow-count", state?.shadowDecisionCount ?? 0);
  text(
    "routing-shadow-choice",
    operationsField(lastShadow, "selected_provider_id", "selectedProviderId") || "None",
  );
  text(
    "routing-active-policy",
    operationsField(active, "policy_id", "policyId") || "Priority default",
  );
  operationsSetStatus(
    "routing-policy-status",
    draft ? `${state.shadowDecisionCount || 0} shadow decision(s); revision ${draftRevision}` : "No shadow policy",
    false,
  );
}

async function loadOperations({forcePolicy = false} = {}) {
  installRoutingAllocationEditor();
  operationsInitApps();
  const appType = operationsAppType();
  const inventory = await sharedGetJson(endpoint(endpoints.providerCreate, {appType}));
  frameworkRows = frameworkRows.filter(row => row.id !== appType).concat({id: appType, providers: inventory.ok ? objectRows(inventory.data) : [], error: inventory.ok ? null : inventory.error});
  const generation = ++operationsLoadGeneration;
  const preserveDraft = !forcePolicy && operationsPolicyApp === appType && operationsPolicyState;
  const [monitor, policy] = await Promise.all([
    safeGetJson(endpoints.operationsMonitor),
    safeGetJson(endpoint(endpoints.routingPolicy, { appType })),
  ]);
  if (generation !== operationsLoadGeneration || appType !== operationsAppType()) return;
  if (monitor.ok) renderOperationsMonitor(monitor.data);
  else operationsSetStatus("operations-monitor-status", monitor.error, true);
  if (policy.ok) { if (!preserveDraft) renderRoutingPolicy(policy.data, appType); }
  else operationsSetStatus("routing-policy-status", policy.error, true);
}

function operationsParseIntegerMap(id) {
  const raw = $(id)?.value?.trim() || "{}";
  const parsed = JSON.parse(raw);
  if (!parsed || Array.isArray(parsed) || typeof parsed !== "object") {
    throw new Error("Expected a JSON object keyed by provider ID");
  }
  for (const [key, value] of Object.entries(parsed)) {
    if (!key.trim() || !Number.isInteger(value)) {
      throw new Error("Every provider value must be an integer");
    }
  }
  return parsed;
}

function operationsParseTypedReference(id, contractId) {
  const raw = $(id)?.value?.trim() || "";
  if (!raw) throw new Error(`Paste a ${contractId} JSON reference issued by the governing host`);
  const parsed = JSON.parse(raw);
  if (!parsed || Array.isArray(parsed) || typeof parsed !== "object") {
    throw new Error(`${contractId} must be a JSON object`);
  }
  if (parsed.contract_id !== contractId) {
    throw new Error(`Expected contract_id ${contractId}`);
  }
  return parsed;
}

async function saveRoutingShadow(event) {
  event?.preventDefault();
  if (routingShadowSaveInFlight) return null;
  routingShadowSaveInFlight = true;
  try {
    const payload = {
      appType: operationsAppType(),
      policyId: $("routing-policy-id")?.value || `${operationsAppType()}.routing`,
      mode: $("routing-policy-mode")?.value || "priority",
      weights: operationsParseIntegerMap("routing-policy-weights"),
      concurrencyLimits: operationsParseIntegerMap("routing-policy-limits"),
    };
    const result = await postJson(endpoints.routingPolicyConfigure, payload);
    operationsSetStatus("routing-policy-status", "Saved in shadow mode; live routing is unchanged.", false);
    if (result?.policy) await loadOperations({forcePolicy:true});
    return result;
  } catch (error) {
    operationsSetStatus("routing-policy-status", error?.message || String(error), true);
    return null;
  } finally { routingShadowSaveInFlight = false; }
}

async function observeRoutingShadow() {
  try {
    const appType = operationsAppType();
    const state = await postJson(endpoints.routingPolicyShadow, { appType });
    if (appType !== operationsAppType()) return;
    renderRoutingPolicy(state, appType);
    operationsSetStatus("routing-policy-status", "Shadow decision recorded; live routing was unchanged.", false);
  } catch (error) {
    operationsSetStatus("routing-policy-status", error?.message || String(error), true);
  }
}

async function activateRoutingPolicy() {
  const draft = operationsPolicyState?.draft;
  const expectedRevision = operationsField(draft, "revision", "revision");
  if (!expectedRevision) {
    operationsSetStatus("routing-policy-status", "A shadow policy is required before activation.", true);
    return;
  }
  if (!window.confirm("Activate this reviewed provider-routing policy for its bounded canary fraction?")) return;
  try {
    const actorPrincipal = operationsParseTypedReference(
      "routing-actor-principal",
      "moonsuite.principal-ref.v1",
    );
    const authorityDecision = operationsParseTypedReference(
      "routing-authority-decision",
      "moonsuite.authority-decision-ref.v1",
    );
    const receipt = await postJson(endpoints.routingPolicyActivate, {
      appType: operationsAppType(),
      actorPrincipal,
      authorityDecision,
      expectedRevision,
    });
    text("routing-receipt", JSON.stringify(receipt));
    operationsSetStatus("routing-policy-status", "Policy activated with a durable receipt.", false);
    await loadOperations({forcePolicy:true});
  } catch (error) {
    operationsSetStatus("routing-policy-status", error?.message || String(error), true);
  }
}

async function rollbackRoutingPolicy() {
  if (!window.confirm("Roll back to the previous provider-routing policy?")) return;
  try {
    const actorPrincipal = operationsParseTypedReference(
      "routing-actor-principal",
      "moonsuite.principal-ref.v1",
    );
    const authorityDecision = operationsParseTypedReference(
      "routing-authority-decision",
      "moonsuite.authority-decision-ref.v1",
    );
    const receipt = await postJson(endpoints.routingPolicyRollback, {
      appType: operationsAppType(),
      actorPrincipal,
      authorityDecision,
    });
    text("routing-receipt", JSON.stringify(receipt));
    operationsSetStatus("routing-policy-status", "Rollback completed with a durable receipt.", false);
    await loadOperations({forcePolicy:true});
  } catch (error) {
    operationsSetStatus("routing-policy-status", error?.message || String(error), true);
  }
}

async function runDeterministicBenchmark() {
  operationsSetStatus("benchmark-status", "Running fixed contract fixture…", false);
  try {
    const report = await postJson(endpoints.deterministicBenchmark);
    text("benchmark-mode", report.mode || "deterministic-fixture");
    text("benchmark-claim", operationsField(report, "claim_ceiling", "claimCeiling"));
    text(
      "benchmark-p95",
      operationsMilliseconds(operationsField(report.latency, "p95_ms", "p95Ms")),
    );
    const throughput = operationsField(
      report,
      "output_tokens_per_second_milli",
      "outputTokensPerSecondMilli",
    );
    text("benchmark-throughput", `${(number(throughput) / 1000).toLocaleString()} fixture tokens/s`);
    operationsSetStatus(
      "benchmark-status",
      report.live_provider === false
        ? "Fixture complete. No provider request was timed."
        : "Unexpected live-provider flag; do not use this result as a fixture claim.",
      report.live_provider !== false,
    );
  } catch (error) {
    operationsSetStatus("benchmark-status", error?.message || String(error), true);
  }
}

// Allocation authoring uses only the inventory already read by the dashboard.
// Nothing here discovers models, probes a provider, activates policy or grants authority.
let routingAllocationDraft = null;
let routingAllocationUI = null;

function routingAllocationInventory() {
  const app = operationsAppType();
  const row = typeof frameworkRows === "undefined" ? null : frameworkRows.find(item => item.id === app);
  if (!row || row.error || !Array.isArray(row.providers)) throw new Error("Provider inventory is unavailable. Refresh the dashboard, then load allocation rows.");
  const seen = new Set();
  return row.providers.map(provider => {
    const id = firstString(provider, ["id", "providerId"], "");
    if (!id || seen.has(id)) throw new Error("Provider inventory has missing or duplicate IDs. Refresh before editing.");
    seen.add(id);
    return {id, name: firstString(provider, ["name", "providerName"], id), enabled: provider.enabled !== false};
  });
}

function routingAllocationForm() {
  return JSON.stringify([operationsAppType(), $("routing-policy-id").value, $("routing-policy-mode").value,
    $("routing-policy-weights").value, $("routing-policy-limits").value]);
}

function routingAllocationPolicy() {
  return JSON.stringify(operationsPolicyState?.draft || null);
}

function routingAllocationNumber(value, weight) {
  if (!/^(0|[1-9][0-9]*)$/.test(String(value))) throw new Error("Use whole decimal integers without spaces or signs.");
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number < (weight ? 1 : 0) || number > (weight ? 1000 : 2147483647)) {
    throw new Error(weight ? "Weights must be 1–1000." : "Caps must be 0–2147483647; 0 means no policy cap.");
  }
  return number;
}

function routingAllocationStart() {
  try {
    if (routingAllocationDraft?.busy) return;
    if (operationsPolicyApp !== operationsAppType()) throw new Error("Wait for the selected app’s shadow policy to load successfully.");
    const inventory = routingAllocationInventory();
    if (!inventory.length) throw new Error("No configured providers for this app. Add one through Providers first.");
    const weights = operationsParseIntegerMap("routing-policy-weights");
    const limits = operationsParseIntegerMap("routing-policy-limits");
    for (const value of Object.values(weights)) routingAllocationNumber(String(value), true);
    for (const value of Object.values(limits)) routingAllocationNumber(String(value), false);
    const own = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
    routingAllocationDraft = {app: operationsAppType(), inventory, inventoryIdentity: JSON.stringify(inventory),
      formIdentity: routingAllocationForm(), policyIdentity: routingAllocationPolicy(), weights, limits,
      rows: inventory.map(provider => ({...provider, weightSet: own(weights, provider.id),
        weight: String(own(weights, provider.id) ? weights[provider.id] : 1),
        limitSet: own(limits, provider.id), limit: String(own(limits, provider.id) ? limits[provider.id] : 0)})),
      preview: null, busy: false, unknown: false};
    routingAllocationUI.preview.textContent = "";
    routingAllocationRender();
    routingAllocationUI.status.textContent = "Edit several provider allocations, then preview. These are configured identities, not proof of eligibility or expected traffic.";
  } catch (error) { routingAllocationUI.status.textContent = error.message; }
}

function routingAllocationPayload() {
  const draft = routingAllocationDraft;
  if (!draft || draft.unknown) throw new Error("Load allocation rows before preparing another save.");
  if (operationsPolicyApp !== draft.app || draft.app !== operationsAppType() || draft.formIdentity !== routingAllocationForm()
      || draft.policyIdentity !== routingAllocationPolicy()
      || draft.inventoryIdentity !== JSON.stringify(routingAllocationInventory())) {
    throw new Error("The app, policy form, policy revision or provider inventory changed. Your row edits are retained. Load allocation rows to deliberately replace them with the current form.");
  }
  const weights = Object.assign(Object.create(null), draft.weights);
  const concurrencyLimits = Object.assign(Object.create(null), draft.limits);
  for (const row of draft.rows) {
    if (row.weightSet) weights[row.id] = routingAllocationNumber(row.weight, true);
    else delete weights[row.id];
    if (row.limitSet) concurrencyLimits[row.id] = routingAllocationNumber(row.limit, false);
    else delete concurrencyLimits[row.id];
  }
  return {appType: draft.app, policyId: $("routing-policy-id").value || `${draft.app}.routing`,
    mode: $("routing-policy-mode").value || "priority", weights, concurrencyLimits};
}

function routingAllocationPreview() {
  try {
    if (routingAllocationDraft?.busy) return;
    const payload = routingAllocationPayload();
    routingAllocationDraft.preview = JSON.stringify(payload);
    routingAllocationUI.preview.textContent = JSON.stringify(payload, null, 2);
    routingAllocationUI.save.disabled = false;
    routingAllocationUI.status.textContent = "Exact shadow-policy input shown. Save replaces the shadow draft and resets its observation history; it does not activate routing. Defaults: weight 1, cap 0 (no policy cap).";
  } catch (error) {
    if (routingAllocationDraft) routingAllocationDraft.preview = null;
    routingAllocationUI.save.disabled = true;
    routingAllocationUI.preview.textContent = "";
    routingAllocationUI.status.textContent = error.message;
  }
}

async function routingAllocationSave() {
  const draft = routingAllocationDraft;
  if (!draft || draft.busy) return;
  try {
    const payload = routingAllocationPayload();
    if (!draft.preview || draft.preview !== JSON.stringify(payload)) throw new Error("Preview the current allocations before saving.");
    draft.busy = true;
    routingAllocationRender();
    // Feed the existing ordinary save action exactly the reviewed maps.
    $("routing-policy-weights").value = JSON.stringify(payload.weights, null, 2);
    $("routing-policy-limits").value = JSON.stringify(payload.concurrencyLimits, null, 2);
    const result = await saveRoutingShadow();
    if (routingAllocationDraft !== draft) return;
    draft.unknown = true;
    draft.preview = null;
    routingAllocationUI.status.textContent = result?.policy
      ? "Shadow save acknowledged. Continue with the ordinary Observe Shadow Decision button. Load allocation rows to edit again; activation remains a separate governed action."
      : "Save was not acknowledged. The prepared maps remain in the ordinary form. Refresh and inspect the shadow policy before deliberately loading rows or saving again; no automatic retry occurred.";
  } catch (error) { routingAllocationUI.status.textContent = error.message; }
  finally {
    draft.busy = false;
    if (routingAllocationDraft === draft) routingAllocationRender();
  }
}

function routingAllocationRender() {
  const ui = routingAllocationUI;
  if (!ui) return;
  ui.rows.replaceChildren();
  const draft = routingAllocationDraft;
  ui.start.disabled = !!draft?.busy;
  ui.clear.disabled = !!draft?.busy;
  ui.inspect.disabled = !draft || !!draft.busy || !!draft.unknown;
  ui.save.disabled = !draft?.preview || !!draft?.busy || !!draft?.unknown;
  if (!draft) return;
  const add = (parent, tag, content) => {
    const element = document.createElement(tag);
    if (content !== undefined) element.textContent = content;
    parent.appendChild(element);
    return element;
  };
  const table = add(ui.rows, "table");
  const head = add(table, "tr");
  for (const label of ["Configured provider", "Weight override (default 1)", "Concurrency cap override (default 0)"]) add(head, "th", label);
  for (const row of draft.rows) {
    const tr = add(table, "tr");
    add(tr, "th", `${row.name} (${row.id})${row.enabled ? "" : " · disabled"}`);
    for (const [field, enabled, description] of [["weight", "weightSet", "weight"], ["limit", "limitSet", "concurrency cap"]]) {
      const cell = add(tr, "td");
      const label = add(cell, "label");
      const checkbox = add(label, "input"); checkbox.type = "checkbox"; checkbox.checked = row[enabled];
      checkbox.setAttribute("aria-label", `Override ${description} for ${row.id}`);
      checkbox.disabled = draft.busy || draft.unknown;
      add(label, "span", "Override");
      const input = add(cell, "input"); input.type = "text"; input.inputMode = "numeric";
      input.value = row[field]; input.disabled = !row[enabled] || draft.busy || draft.unknown;
      input.setAttribute("aria-label", `${description} for ${row.id}`);
      const changed = () => {
        draft.preview = null; ui.preview.textContent = ""; ui.save.disabled = true;
        ui.status.textContent = "Allocation edits are only in this tab. Preview again before saving.";
      };
      checkbox.addEventListener("change", () => {
        if (routingAllocationDraft !== draft || draft.busy || draft.unknown) return;
        row[enabled] = checkbox.checked; input.disabled = !row[enabled]; changed();
      });
      input.addEventListener("input", () => {
        if (routingAllocationDraft !== draft || draft.busy || draft.unknown) return;
        row[field] = input.value; changed();
      });
    }
  }
  const known = new Set(draft.rows.map(row => row.id));
  const retained = {weights: Object.fromEntries(Object.entries(draft.weights).filter(([id]) => !known.has(id))),
    concurrencyLimits: Object.fromEntries(Object.entries(draft.limits).filter(([id]) => !known.has(id)))};
  add(ui.rows, "p", "Overrides for IDs absent from this inventory remain unchanged. To remove them deliberately, edit the ordinary JSON form and reload rows:");
  add(ui.rows, "pre", JSON.stringify(retained, null, 2));
}

function installRoutingAllocationEditor() {
  const form = $("routing-policy-form");
  if (!form || routingAllocationUI) return;
  const make = (parent, tag, id, content) => {
    const element = document.createElement(tag); if (id) element.id = id;
    if (content) element.textContent = content;
    parent.appendChild(element); return element;
  };
  const section = make(form, "details", "routing-allocation"); section.className = "span-2 advanced-disclosure";
  make(section, "summary", null, "Allocate across configured providers");
  make(section, "p", null, "Load the current app inventory already read by the dashboard. Set relative weights and concurrency caps together, inspect the exact input, then save the shadow policy. A listed provider may be disabled, outside the routing pool or otherwise ineligible. Weights are used only by modes that support them; a cap of 0 is unlimited by this policy. No traffic share or availability is promised.");
  const start = make(section, "button", "routing-allocation-load", "Load allocation rows (replace row edits)"); start.type = "button";
  const clear = make(section, "button", "routing-allocation-clear", "Discard allocation row edits"); clear.type = "button";
  const rows = make(section, "div", "routing-allocation-rows");
  const inspect = make(section, "button", "routing-allocation-preview", "Preview allocations"); inspect.type = "button";
  const save = make(section, "button", "routing-allocation-save", "Save allocations as shadow"); save.type = "button";
  const status = make(section, "p", "routing-allocation-status", "No allocation rows loaded."); status.setAttribute("role", "status");
  const preview = make(section, "pre", "routing-allocation-payload");
  routingAllocationUI = {section, start, clear, rows, inspect, save, status, preview};
  start.addEventListener("click", routingAllocationStart);
  inspect.addEventListener("click", routingAllocationPreview);
  save.addEventListener("click", routingAllocationSave);
  clear.addEventListener("click", () => {
    if (routingAllocationDraft?.busy) return;
    routingAllocationDraft = null; preview.textContent = ""; status.textContent = "Row edits discarded. The ordinary policy form is unchanged."; routingAllocationRender();
  });
  routingAllocationRender();
}

$("routing-policy-form")?.addEventListener("submit", saveRoutingShadow);
$("routing-policy-observe")?.addEventListener("click", observeRoutingShadow);
$("routing-policy-activate")?.addEventListener("click", activateRoutingPolicy);
$("routing-policy-rollback")?.addEventListener("click", rollbackRoutingPolicy);
$("benchmark-run")?.addEventListener("click", runDeterministicBenchmark);
$("operations-app")?.addEventListener("change", loadOperations);
