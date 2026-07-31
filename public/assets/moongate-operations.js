let operationsPolicyState = null;

function operationsAppType() {
  return $("operations-app")?.value || "codex";
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
  const values = [];
  for (const app of frameworkApps) {
    const value = app.providerAppType || app.id;
    if (value && !values.some((row) => row.value === value)) {
      values.push({ value, label: app.label });
    }
  }
  if (!values.some((row) => row.value === "codex")) {
    values.unshift({ value: "codex", label: "Codex" });
  }
  select.innerHTML = values
    .map((row) => `<option value="${escapeHtml(row.value)}">${escapeHtml(row.label)}</option>`)
    .join("");
  select.value = values.some((row) => row.value === "codex") ? "codex" : values[0]?.value || "";
}

function renderOperationsMonitor(snapshot) {
  const latency = snapshot?.latency || {};
  const firstToken = operationsField(snapshot, "first_token", "firstToken") || {};
  text("operations-latency-p50", operationsMilliseconds(operationsField(latency, "p50_ms", "p50Ms")));
  text("operations-latency-p95", operationsMilliseconds(operationsField(latency, "p95_ms", "p95Ms")));
  text("operations-latency-p99", operationsMilliseconds(operationsField(latency, "p99_ms", "p99Ms")));
  text("operations-ttft-p95", operationsMilliseconds(operationsField(firstToken, "p95_ms", "p95Ms")));
  text("operations-inflight", operationsField(snapshot, "inflight_requests", "inflightRequests") ?? 0);
  const queueSupported = operationsField(snapshot, "queue_supported", "queueSupported") === true;
  text("operations-queue", queueSupported ? `${operationsField(snapshot, "queue_depth", "queueDepth") ?? 0} queued` : "Not implemented");
  text("operations-circuits", operationsField(snapshot, "circuit_open_count", "circuitOpenCount") ?? 0);
  text("operations-failovers", operationsField(snapshot, "failover_count", "failoverCount") ?? 0);
  const configured = operationsField(snapshot, "quota_configured_count", "quotaConfiguredCount") ?? 0;
  const exceeded = operationsField(snapshot, "quota_exceeded_count", "quotaExceededCount") ?? 0;
  const costNano = operationsField(snapshot, "recent_cost_nano_usd", "recentCostNanoUsd") ?? 0;
  operationsSetStatus(
    "operations-monitor-status",
    `Recent request window: ${configured} configured quota${configured === 1 ? "" : "s"}, ${exceeded} exceeded; estimated cost ${money(number(costNano) / 1_000_000_000)}. Queue depth is shown only when a real queue exists.`,
    false,
  );
}

function renderRoutingPolicy(state) {
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

async function loadOperations() {
  operationsInitApps();
  const appType = operationsAppType();
  const [monitor, policy] = await Promise.all([
    safeGetJson(endpoints.operationsMonitor),
    safeGetJson(endpoint(endpoints.routingPolicy, { appType })),
  ]);
  if (monitor.ok) renderOperationsMonitor(monitor.data);
  else operationsSetStatus("operations-monitor-status", monitor.error, true);
  if (policy.ok) renderRoutingPolicy(policy.data);
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
    if (result?.policy) await loadOperations();
  } catch (error) {
    operationsSetStatus("routing-policy-status", error?.message || String(error), true);
  }
}

async function observeRoutingShadow() {
  try {
    const state = await postJson(endpoints.routingPolicyShadow, { appType: operationsAppType() });
    renderRoutingPolicy(state);
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
    await loadOperations();
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
    await loadOperations();
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

$("routing-policy-form")?.addEventListener("submit", saveRoutingShadow);
$("routing-policy-observe")?.addEventListener("click", observeRoutingShadow);
$("routing-policy-activate")?.addEventListener("click", activateRoutingPolicy);
$("routing-policy-rollback")?.addEventListener("click", rollbackRoutingPolicy);
$("benchmark-run")?.addEventListener("click", runDeterministicBenchmark);
$("operations-app")?.addEventListener("change", loadOperations);
$("refresh")?.addEventListener("click", loadOperations);

loadOperations().catch((error) => {
  operationsSetStatus("operations-monitor-status", error?.message || String(error), true);
});
