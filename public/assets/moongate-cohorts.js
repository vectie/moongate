// Read-only view of a single bounded native snapshot. No raw request rows.
let cohortGeneration = 0;
let cohortQuery = null;
let cohortSnapshot = null;
let cohortContext = null;

function cohortStatus(message) { text("cohort-status", message); }
function invalidateCohortComparison(message = "Filters changed; capture a new snapshot", preserveQuery = false) {
  cohortGeneration++;
  cohortSnapshot = null;
  cohortContext = null;
  if (!preserveQuery) cohortQuery = null;
  for (const side of ["a", "b"]) for (const field of ["provider", "model"]) {
    const node = $(`cohort-${side}-${field}`);
    if (node) { node.innerHTML = ""; node.disabled = true; }
  }
  text("cohort-report", "No current comparison available");
  if ($("cohort-export")) $("cohort-export").disabled = true;
  if ($("cohort-retry")) $("cohort-retry").disabled = !cohortQuery;
  cohortStatus(message);
}

function cohortCurrent() {
  const valid = cohortSnapshot && cohortContext && cohortContext.generation === cohortGeneration &&
    cohortContext.origin === window.location.origin && cohortContext.token === controlTokenPromise &&
    window.location.hash === "#operations" && cohortSnapshot.app_type === $("cohort-app")?.value &&
    cohortSnapshot.streaming === $("cohort-streaming")?.value && cohortSnapshot.period === $("cohort-period")?.value;
  if (!valid && cohortSnapshot) invalidateCohortComparison("Comparison context changed; capture again");
  return Boolean(valid);
}

function cohortInteger(value) {
  if (!Number.isSafeInteger(value) || value < 0) throw new Error("Invalid snapshot count");
  return value;
}
function cohortString(value) { if (typeof value !== "string") throw new Error("Invalid metadata"); return value; }
function cohortTimestamp(value) {
  if (value === null) return null;
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/.test(value)) throw new Error("Invalid UTC timestamp");
  return value;
}
function cohortPercentiles(value) {
  const result = { sample_count: cohortInteger(value?.sample_count) };
  for (const key of ["p50_ms", "p95_ms", "p99_ms"]) result[key] = value[key] === null ? null : cohortInteger(value[key]);
  if (result.sample_count === 0 && [result.p50_ms, result.p95_ms, result.p99_ms].some(v => v !== null)) throw new Error("Invalid empty sample");
  if (result.sample_count > 0 && [result.p50_ms, result.p95_ms, result.p99_ms].some(v => v === null)) throw new Error("Missing percentile");
  return result;
}

function cohortAllowlistedSnapshot(raw, query) {
  if (raw?.schema !== "moongate.retained-cohorts.v1" || raw.app_type !== query.appType || raw.streaming !== query.streaming || raw.period !== query.period || raw.end_seconds !== query.end) throw new Error("Snapshot query mismatch");
  const duration = { "24h": 86400, "7d": 604800, "30d": 2592000, all: query.end }[query.period];
  if (raw.start_seconds !== query.end - duration || !Array.isArray(raw.cohorts) || raw.cohorts.length > 500) throw new Error("Snapshot bounds mismatch");
  const result = { schema: raw.schema, app_type: raw.app_type, streaming: raw.streaming, period: raw.period };
  for (const key of ["start_seconds", "end_seconds", "captured_at_ms", "retained_rows", "proxy_interval_rows", "imported_excluded", "outside_interval_excluded", "invalid_timestamp_excluded", "missing_request_model_unclassified", "missing_provider_id_unclassified", "row_limit", "response_byte_limit"]) result[key] = cohortInteger(raw[key]);
  for (const key of ["start_utc", "end_utc_exclusive", "captured_at_utc", "oldest_utc", "newest_utc"]) result[key] = cohortTimestamp(raw[key]);
  const keys = new Set();
  result.cohorts = raw.cohorts.map(row => {
    const entry = { provider_id: cohortString(row.provider_id), request_model: cohortString(row.request_model) };
    const identity = JSON.stringify([entry.provider_id, entry.request_model]);
    if (!entry.provider_id || !entry.request_model || keys.has(identity)) throw new Error("Invalid cohort identity");
    keys.add(identity);
    for (const key of ["total", "status_2xx", "status_4xx", "status_5xx", "status_other", "successful", "unsuccessful_excluded", "invalid_latency_excluded", "streaming_successful", "missing_first_event_excluded", "invalid_first_event_excluded", "first_event_invalid_elapsed_excluded", "missing_successful_response_model"]) entry[key] = cohortInteger(row[key]);
    entry.latency = Object.freeze(cohortPercentiles(row.latency));
    entry.first_event = Object.freeze(cohortPercentiles(row.first_event));
    entry.oldest_utc = cohortTimestamp(row.oldest_utc);
    entry.newest_utc = cohortTimestamp(row.newest_utc);
    entry.successful_response_model_mix = Object.freeze(row.successful_response_model_mix.map(m => Object.freeze({ model: cohortString(m.model), count: cohortInteger(m.count) })));
    if (entry.status_2xx + entry.status_4xx + entry.status_5xx + entry.status_other !== entry.total || entry.successful + entry.unsuccessful_excluded !== entry.total || entry.latency.sample_count + entry.invalid_latency_excluded !== entry.successful || entry.first_event.sample_count + entry.missing_first_event_excluded + entry.invalid_first_event_excluded + entry.first_event_invalid_elapsed_excluded !== entry.streaming_successful) throw new Error("Inconsistent cohort counts");
    return Object.freeze(entry);
  });
  if (result.cohorts.reduce((n, row) => n + row.total, 0) + result.missing_request_model_unclassified + result.missing_provider_id_unclassified !== result.proxy_interval_rows) throw new Error("Incomplete cohorts");
  Object.freeze(result.cohorts);
  return Object.freeze(result);
}

async function captureCohortSnapshot(retry = false) {
  if (!retry) cohortQuery = Object.freeze({ appType: $("cohort-app")?.value || "codex", streaming: $("cohort-streaming")?.value || "all", period: $("cohort-period")?.value || "24h", end: Math.floor(Date.now() / 1000) });
  if (!cohortQuery) return;
  const query = cohortQuery;
  invalidateCohortComparison("Capturing retained proxy requests…", true);
  const generation = cohortGeneration;
  const origin = window.location.origin;
  let token;
  try {
    await acquireControlToken();
    token = controlTokenPromise;
    if (generation !== cohortGeneration) return;
    if (origin !== window.location.origin) { invalidateCohortComparison("Gateway changed; capture again"); return; }
    const probe = await safeGetJson(endpoint(endpoints.retainedCohortSnapshot, query));
    if (generation !== cohortGeneration) return;
    if (origin !== window.location.origin || token !== controlTokenPromise) { invalidateCohortComparison("Gateway or authentication changed; capture again"); return; }
    if (!probe.ok) throw new Error("Snapshot unavailable");
    cohortSnapshot = cohortAllowlistedSnapshot(probe.data, query);
    cohortContext = { generation, origin, token };
    cohortPopulateSides();
    renderCohortComparison();
    cohortStatus(`Captured ${cohortSnapshot.proxy_interval_rows} retained proxy requests. A and B share this snapshot. Retry retains UTC bounds; Refresh captures a new upper bound.`);
  } catch (_error) {
    if (generation !== cohortGeneration) return;
    if (origin !== window.location.origin || (token && token !== controlTokenPromise)) { invalidateCohortComparison("Gateway or authentication changed; capture again"); return; }
    invalidateCohortComparison("Snapshot unavailable or over its safety limit. No partial report. Retry the same UTC bounds or capture again with narrower filters.", true);
  }
}

function cohortOptions(id, values, selected) {
  const node = $(id);
  if (!node) return;
  node.innerHTML = "";
  for (const value of values) {
    const option = document.createElement("option");
    option.value = value; option.textContent = value;
    node.appendChild(option);
  }
  node.value = values.includes(selected) ? selected : values[0] || "";
  node.disabled = values.length === 0;
}
function cohortPopulateSides() {
  const rows = cohortSnapshot.cohorts;
  const providers = [...new Set(rows.map(row => row.provider_id))];
  for (const [side, index] of [["a", 0], ["b", Math.min(1, rows.length - 1)]]) {
    cohortOptions(`cohort-${side}-provider`, providers, rows[index]?.provider_id);
    cohortPopulateModels(side, rows[index]?.request_model);
  }
}
function cohortPopulateModels(side, preferred) {
  if (!cohortCurrent()) return;
  const provider = $(`cohort-${side}-provider`)?.value;
  cohortOptions(`cohort-${side}-model`, cohortSnapshot.cohorts.filter(row => row.provider_id === provider).map(row => row.request_model), preferred);
}
function cohortSelected(side) {
  return cohortSnapshot.cohorts.find(row => row.provider_id === $(`cohort-${side}-provider`)?.value && row.request_model === $(`cohort-${side}-model`)?.value);
}
function cohortQuoted(value) { return JSON.stringify(value); }
function cohortRate(count, total) { return total ? `${count}/${total} (${(100 * count / total).toFixed(1)}%)` : "unavailable (0 requests)"; }
function cohortPercentileLine(value) {
  return `n=${value.sample_count}; p50 ${value.p50_ms ?? "unavailable"}, p95 ${value.p95_ms ?? "unavailable"}, p99 ${value.p99_ms ?? "unavailable"} ms (nearest rank)`;
}
function cohortReportSide(label, row) {
  if (!row) return `${label}: unavailable; no classified retained requests`;
  return [
    `${label}: provider ID ${cohortQuoted(row.provider_id)}; explicit request model ${cohortQuoted(row.request_model)}`,
    `Requests: ${row.total}; successful 2xx without recorded error: ${row.successful}`,
    `Status proportions: 2xx ${cohortRate(row.status_2xx, row.total)}; 4xx ${cohortRate(row.status_4xx, row.total)}; 5xx ${cohortRate(row.status_5xx, row.total)}; other ${cohortRate(row.status_other, row.total)}`,
    `Successful elapsed latency: ${cohortPercentileLine(row.latency)}`,
    `Elapsed exclusions: ${row.unsuccessful_excluded} unsuccessful; ${row.invalid_latency_excluded} missing/nonpositive elapsed among successes`,
    `First accepted stream event: ${cohortPercentileLine(row.first_event)}`,
    `First-event coverage: ${cohortRate(row.first_event.sample_count, row.streaming_successful)} successful streaming requests`,
    `First-event exclusions: ${row.missing_first_event_excluded} missing; ${row.invalid_first_event_excluded} negative/after elapsed; ${row.first_event_invalid_elapsed_excluded} missing/nonpositive elapsed`,
    `Oldest: ${row.oldest_utc || "unavailable"}; newest: ${row.newest_utc || "unavailable"}`,
    `Successful stored response-model mix (separate from request model): ${row.successful_response_model_mix.map(m => `${cohortQuoted(m.model)}=${m.count}`).join(", ") || "unavailable"}; missing ${row.missing_successful_response_model}`,
    `Small-sample warning: ${row.latency.sample_count < 20 ? "elapsed n<20" : "elapsed n>=20"}; ${row.first_event.sample_count < 20 ? "first-event n<20" : "first-event n>=20"}. Percentiles are descriptive only.`,
  ].join("\n");
}
function cohortComparisonReport() {
  if (!cohortCurrent()) return null;
  const s = cohortSnapshot, a = cohortSelected("a"), b = cohortSelected("b");
  return [
    "MoonGate retained-request cohort comparison",
    `App: ${cohortQuoted(s.app_type)}; streaming: ${s.streaming}; interval: ${s.period}`,
    `UTC bounds [inclusive, exclusive): ${s.start_utc || "all retained"} to ${s.end_utc_exclusive}`,
    `Captured: ${s.captured_at_utc} (${s.captured_at_ms} epoch ms)`,
    `Retained store: ${s.retained_rows} rows; matching proxy interval: ${s.proxy_interval_rows}`,
    `Scoped exclusions: imported ${s.imported_excluded}; outside interval ${s.outside_interval_excluded}; invalid timestamp ${s.invalid_timestamp_excluded}`,
    `Unclassified matching proxy rows: missing explicit request_model ${s.missing_request_model_unclassified}; missing provider ID ${s.missing_provider_id_unclassified}`,
    `Matching oldest: ${s.oldest_utc || "unavailable"}; newest: ${s.newest_utc || "unavailable"}`,
    `Bounds: at most ${s.row_limit} retained rows and ${s.response_byte_limit} response bytes; oversize refused, never truncated.`,
    "Retention is incomplete history: older requests may have been evicted. Imports and rollups never supply timing samples.",
    "", cohortReportSide("A", a), "", cohortReportSide("B", b), "",
    a && a === b ? "A and B are the same cohort." : "A and B are exact cohorts from the same captured snapshot.",
    "Successful means 2xx with no recorded error; status proportions count every classified row. Empty samples are unavailable, not zero.",
    "The successful stored model field may use a fallback when the upstream response omits its model; its mix is not proof of the actual response model. Error rows do not supply this mix.",
    "First accepted stream event is not guaranteed first-token timing. Stored duration duplicates elapsed time; proxy overhead and provider causality cannot be inferred.",
    "Different workloads, retained coverage and sample sizes limit comparison. No ranking, SLA, savings, cost, or routing recommendation is made.",
  ].join("\n");
}
function renderCohortComparison() {
  const report = cohortComparisonReport();
  text("cohort-report", report || "No current comparison available");
  if ($("cohort-export")) $("cohort-export").disabled = !report;
}
function exportCohortComparison() {
  const report = cohortComparisonReport();
  if (!report) return;
  const url = URL.createObjectURL(new Blob([report + "\n"], { type: "text/plain;charset=utf-8" }));
  const link = document.createElement("a"); link.href = url; link.download = "moongate-retained-cohort-comparison.txt";
  document.body.appendChild(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function initCohortComparison() {
  const apps = [...new Set(["codex", ...frameworkApps.map(app => app.providerAppType || app.id), "unknown"])];
  cohortOptions("cohort-app", apps, "codex");
  for (const id of ["cohort-app", "cohort-streaming", "cohort-period"]) $(id)?.addEventListener("change", () => invalidateCohortComparison());
  $("cohort-query")?.addEventListener("submit", event => { event.preventDefault(); captureCohortSnapshot(); });
  $("cohort-refresh")?.addEventListener("click", () => captureCohortSnapshot());
  $("cohort-retry")?.addEventListener("click", () => captureCohortSnapshot(true));
  $("cohort-export")?.addEventListener("click", exportCohortComparison);
  for (const side of ["a", "b"]) {
    $(`cohort-${side}-provider`)?.addEventListener("change", () => { cohortPopulateModels(side); renderCohortComparison(); });
    $(`cohort-${side}-model`)?.addEventListener("change", renderCohortComparison);
  }
  invalidateCohortComparison("Choose filters, then capture a snapshot");
}
initCohortComparison();
