let usageLoadGeneration = 0;

function renderStack(id, rows, labelKeys) {
  const target = $(id);
  if (!target) return;
  target.innerHTML = "";
  if (rows.length === 0) {
    target.innerHTML = `<div class="row-card"><strong>No data yet</strong><small>Send an AI request through MoonGate to populate this panel.</small></div>`;
    return;
  }
  for (const row of rows.slice(0, 8)) {
    const name = firstString(row, labelKeys);
    const requests = number(row.requests ?? row.requestCount ?? row.totalRequests ?? row.count);
    const cost = row.costUsd ?? row.totalCostUsd ?? row.totalCost ?? row.cost ?? 0;
    const div = document.createElement("div");
    div.className = "row-card";
    div.innerHTML = `
      <div>
        <strong>${escapeHtml(name)}</strong>
        <small>${compact(requests)} requests</small>
      </div>
      <strong>${money(cost)}</strong>
    `;
    target.appendChild(div);
  }
}

function renderStackError(id, message) {
  const target = $(id);
  if (!target) return;
  target.innerHTML = `<div class="row-card"><strong>Unavailable</strong><small>${escapeHtml(message)}</small></div>`;
}

function usageQueryParams(extra) {
  const appType = $("usage-app")?.value || "";
  const range = $("usage-range")?.value || "604800";
  const params = { ...(extra || {}) };
  if (appType) params.appType = appType;
  if (range !== "all") {
    const endDate = Math.floor(Date.now() / 1000);
    params.endDate = endDate;
    params.startDate = endDate - Number(range);
  }
  return params;
}

function trendLabel(value) {
  if (!value) return "-";
  const date = new Date(String(value));
  if (Number.isNaN(date.getTime())) return String(value).slice(0, 10);
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function renderTrends(rows) {
  const target = $("usage-trends");
  if (!target) return;
  target.innerHTML = "";
  if (rows.length === 0) {
    target.innerHTML = `<div class="trend-bar"><span style="height:10px"></span><small>No data</small></div>`;
    return;
  }
  const maxTokens = Math.max(1, ...rows.map((row) => number(row.totalTokens ?? row.tokens ?? row.requestCount)));
  for (const row of rows.slice(-36)) {
    const tokens = number(row.totalTokens ?? row.tokens ?? row.requestCount);
    const height = Math.max(10, Math.round((tokens / maxTokens) * 118));
    const label = trendLabel(row.date ?? row.timestamp ?? row.bucket);
    const bar = document.createElement("div");
    bar.className = "trend-bar";
    bar.title = `${label}: ${compact(tokens)} tokens`;
    bar.innerHTML = `<span style="height:${height}px"></span><small>${escapeHtml(label)}</small>`;
    target.appendChild(bar);
  }
}

function updateTotals(summary, stats) {
  const totalRequests =
    summary.totalRequests ?? summary.requests ?? summary.requestCount ?? stats.total_requests ?? stats.totalRequests ?? 0;
  const totalCost =
    summary.totalCostUsd ?? summary.costUsd ?? summary.totalCost ?? stats.totalCostUsd ?? stats.costUsd ?? 0;
  text("request-total", compact(totalRequests));
  text("cost-total", money(totalCost));
}

function updateUsageMetrics(summary) {
  const totalTokens = number(
    summary.realTotalTokens ??
    summary.totalTokens ??
    number(summary.totalInputTokens) + number(summary.totalOutputTokens),
  );
  text("usage-filter-requests", compact(summary.totalRequests ?? summary.requests ?? 0));
  text("usage-filter-cost", money(summary.totalCostUsd ?? summary.totalCost ?? 0));
  text("usage-filter-tokens", compact(totalTokens));
  text("usage-filter-cache", percent(summary.cacheHitRate ?? 0));
}

async function loadUsageExplorer() {
  const generation = ++usageLoadGeneration;
  const params = usageQueryParams();
  const [summaryProbe, trendsProbe, providerStatsProbe, modelStatsProbe] = await Promise.all([
    safeGetJson(endpoint(endpoints.usageSummary, params)),
    safeGetJson(endpoint(endpoints.usageTrends, params)),
    safeGetJson(endpoint(endpoints.providerStats, params)),
    safeGetJson(endpoint(endpoints.modelStats, params)),
  ]);
  if (generation !== usageLoadGeneration) {
    return { warningCount: 0, recentRequestCount: 0, stale: true };
  }
  const summary = probeData(summaryProbe, {});
  const trends = probeData(trendsProbe, {});
  const providerStats = probeData(providerStatsProbe, {});
  const modelStats = probeData(modelStatsProbe, {});
  if (summaryProbe.ok) {
    updateUsageMetrics(summary);
  } else {
    for (const id of ["usage-filter-requests", "usage-filter-cost", "usage-filter-tokens", "usage-filter-cache"]) {
      text(id, "Unavailable");
    }
  }
  if (trendsProbe.ok) {
    renderTrends(arrayFrom(trends, ["data", "items", "trends"]));
  } else {
    renderStackError("usage-trends", trendsProbe.error);
  }
  if (providerStatsProbe.ok) {
    renderStack("provider-usage", arrayFrom(providerStats, ["providers", "items", "data"]), ["providerName", "providerId", "name"]);
  } else {
    renderStackError("provider-usage", providerStatsProbe.error);
  }
  if (modelStatsProbe.ok) {
    renderStack("filtered-model-usage", arrayFrom(modelStats, ["models", "items", "data"]), ["model", "modelId", "name"]);
  } else {
    renderStackError("filtered-model-usage", modelStatsProbe.error);
  }
  return {
    warningCount: [summaryProbe, trendsProbe, providerStatsProbe, modelStatsProbe]
      .some((probe) => !probe.ok) ? 1 : 0,
  };
}

// Retained requests have their own applied query, independent of aggregate usage.
// Freeze time bounds until Apply/Reset; offset pages are not a database snapshot.
const requestPageSize = 12;
let requestQuery = null;
let requestPage = 0;
let requestLoadGeneration = 0;
let requestDetailGeneration = 0;
let requestPageSnapshot = null;
let requestSelectedDetail = null;
let requestSelectedId = "";
let requestListLoading = false;
let requestDetailLoading = false;
let requestDetailObservedAt = null;

function initRequestAppSelect() {
  const select = $("request-app");
  if (!select) return;
  select.innerHTML = `<option value="">All apps</option>` + frameworkApps.map((app) =>
    `<option value="${escapeHtml(app.id)}">${escapeHtml(app.label)}</option>`).join("");
}

function readRequestQuery() {
  const statusCode = ($("request-status")?.value || "").trim();
  if (statusCode && !/^[1-5][0-9]{2}$/.test(statusCode)) {
    throw new Error("Enter an HTTP status from 100 to 599, or leave it blank.");
  }
  const range = $("request-range")?.value || "604800";
  if (!["86400", "604800", "2592000", "all"].includes(range)) throw new Error("Choose a time range.");
  const endDate = Math.floor(Date.now() / 1000);
  return {
    appType: $("request-app")?.value || "",
    providerName: ($("request-provider")?.value || "").trim(),
    model: ($("request-model")?.value || "").trim(),
    statusCode,
    ...(range === "all" ? {} : { startDate: endDate - Number(range) }),
    endDate,
  };
}

function requestTime(value) {
  if (value == null || value === "" || !Number.isFinite(Number(value))) return "Unavailable";
  const date = new Date(Number(value) * 1000);
  return Number.isNaN(date.getTime()) ? "Unavailable" : date.toISOString();
}

function requestQueryDescription(query) {
  if (!query) return "No applied query";
  return `App: ${query.appType || "all"}; provider name contains: ${query.providerName || "any"}; model contains: ${query.model || "any"}; status: ${query.statusCode || "any"}; UTC interval: ${query.startDate == null ? "earliest retained" : requestTime(query.startDate)} through ${requestTime(query.endDate)}`;
}

function requestValue(value) {
  return ["string", "number", "boolean"].includes(typeof value) && String(value).trim() !== "" ? String(value) : "Unavailable";
}

function requestMeasure(value, unit = "") {
  if (value == null || value === "" || !Number.isFinite(Number(value)) || Number(value) < 0) return "Unavailable";
  // The retained API uses zero for both an observed zero and missing metadata.
  return `${String(value)}${unit}${Number(value) === 0 ? " (zero or unavailable)" : ""}`;
}

// Explicit allowlist shared by detail rendering, CSV and the readable report.
// Never serialize the response object: it may contain raw errors or future secrets.
function requestSafeFields(row) {
  return [
    ["Request ID", requestValue(row.requestId)],
    ["Created UTC", requestTime(row.createdAt)],
    ["App", requestValue(row.appType)],
    ["Provider ID", requestValue(row.providerId)],
    ["Provider", requestValue(row.providerName)],
    ["Model", requestValue(row.model)],
    ["Request model", requestValue(row.requestModel)],
    ["Pricing model", requestValue(row.pricingModel)],
    ["HTTP status", requestValue(row.statusCode)],
    ["Estimated cost USD", requestMeasure(row.totalCostUsd)],
    ["Input tokens", requestValue(row.inputTokens)],
    ["Output tokens", requestValue(row.outputTokens)],
    ["Cache read tokens", requestValue(row.cacheReadTokens)],
    ["Cache write tokens", requestValue(row.cacheCreationTokens)],
    ["Latency ms", requestMeasure(row.latencyMs)],
    ["First token ms", requestMeasure(row.firstTokenMs)],
    ["Duration ms", requestMeasure(row.durationMs)],
    ["Streaming", requestValue(row.isStreaming)],
    ["Data source", requestValue(row.dataSource)],
  ];
}

function renderRequestDetail(detail, message = "No request selected") {
  text("request-detail-id", requestSelectedId || "No selection");
  const target = $("request-detail");
  if (target) target.innerHTML = (detail ? requestSafeFields(detail) : [["Status", message]])
    .map(([label, value]) => `<div><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></div>`).join("");
}

function updateRequestControls() {
  renderRequestCollection();
  const snapshot = requestPageSnapshot;
  const setDisabled = (id, disabled) => { if ($(id)) $(id).disabled = disabled; };
  setDisabled("request-prev", requestListLoading || requestPage === 0);
  setDisabled("request-next", requestListLoading || !snapshot || (snapshot.page + 1) * requestPageSize >= snapshot.total);
  setDisabled("request-retry", requestListLoading);
  setDisabled("request-export-page", requestListLoading || !snapshot || snapshot.rows.length === 0);
  setDisabled("request-export-detail", requestListLoading || requestDetailLoading || !requestSelectedDetail);
  setDisabled("request-detail-retry", requestListLoading || requestDetailLoading || !requestSelectedId);
}

function clearRequestSelection() {
  ++requestDetailGeneration;
  requestSelectedId = "";
  requestSelectedDetail = null;
  requestDetailObservedAt = null;
  requestDetailLoading = false;
  renderRequestDetail(null);
}

function renderLogs(data) {
  const target = $("request-log");
  if (!target) return;
  target.innerHTML = "";
  if (data.data.length === 0) {
    target.innerHTML = `<div class="log-item"><strong>No retained requests on this page</strong><small>Change filters, go back a page, or apply again to refresh the time interval.</small></div>`;
  }
  for (const row of data.data) {
    const div = document.createElement("div");
    div.className = "log-item";
    div.innerHTML = `<strong>${escapeHtml(requestValue(row.requestId))}</strong>
      <small>${escapeHtml([requestTime(row.createdAt), requestValue(row.appType), requestValue(row.providerName), requestValue(row.model), `HTTP ${requestValue(row.statusCode)}`].join(" | "))}</small>
      <small>${escapeHtml(`Estimated USD ${requestMeasure(row.totalCostUsd)} | Latency ${requestMeasure(row.latencyMs, " ms")}`)}</small>
      <button type="button" data-request-id="${escapeHtml(row.requestId)}">Details</button>`;
    target.appendChild(div);
  }
  const start = data.data.length ? data.page * requestPageSize + 1 : 0;
  const end = data.data.length ? data.page * requestPageSize + data.data.length : 0;
  text("request-page-summary", `Showing ${start}–${end} of ${data.total} retained requests · Page ${data.page + 1}`);
}

async function loadRequestExplorer() {
  if (!requestQuery) requestQuery = readRequestQuery();
  const generation = ++requestLoadGeneration;
  const query = { ...requestQuery };
  const page = requestPage;
  requestListLoading = true;
  requestPageSnapshot = null;
  clearRequestSelection();
  text("request-query-summary", requestQueryDescription(query));
  text("request-page-summary", "Loading retained requests…");
  if ($("request-log")) $("request-log").innerHTML = "";
  text("request-feedback", "Loading…");
  updateRequestControls();
  const probe = await safeGetJson(endpoint(endpoints.usageLogs, { ...query, page, pageSize: requestPageSize }));
  if (generation !== requestLoadGeneration) return { warningCount: 0, stale: true };
  requestListLoading = false;
  const data = probe.data;
  const valid = probe.ok && data && Array.isArray(data.data) && Number.isSafeInteger(data.total) && data.total >= 0
    && data.page === page && data.pageSize === requestPageSize && data.data.length <= requestPageSize
    && (data.data.length === 0 || page * requestPageSize + data.data.length <= data.total)
    && data.data.every((row) => row && typeof row.requestId === "string" && row.requestId.trim() !== "");
  if (valid) {
    requestPageSnapshot = { query, page, total: data.total, rows: data.data.map((row) => ({ ...row })) };
    renderLogs(data);
    text("request-feedback", data.data.length ? "Page loaded. Export includes only these displayed rows." : "No matching retained requests on this page.");
  } else {
    text("request-page-summary", "Retained requests unavailable");
    text("request-feedback", "Could not load this page. Retry the page or change filters.");
    if ($("request-log")) $("request-log").innerHTML = "";
  }
  updateRequestControls();
  mergeReadinessState({ recentRequestCount: valid ? data.data.length : 0 });
  return { warningCount: valid ? 0 : 1, recentRequestCount: valid ? data.data.length : 0 };
}

function ensureRequestExplorer() {
  // Automatic dashboard refresh must not clear a user's page or selection.
  // The explorer has explicit Apply/Reload controls and a frozen query interval.
  if (!requestQuery) return loadRequestExplorer();
  return Promise.resolve({ warningCount: requestPageSnapshot || requestListLoading ? 0 : 1,
    recentRequestCount: requestPageSnapshot?.rows.length || 0 });
}

async function applyRequestFilters(reset = false) {
  if (reset) {
    for (const id of ["request-app", "request-provider", "request-model", "request-status"]) if ($(id)) $(id).value = "";
    if ($("request-range")) $("request-range").value = "604800";
  }
  let query;
  try { query = readRequestQuery(); }
  catch (error) { text("request-feedback", error.message); return; }
  requestQuery = query;
  requestPage = 0;
  return loadRequestExplorer();
}

async function changeRequestPage(delta) {
  if (requestListLoading || ![-1, 1].includes(delta)) return;
  if (delta === -1 && requestPage === 0) return;
  if (delta === 1 && (!requestPageSnapshot || (requestPage + 1) * requestPageSize >= requestPageSnapshot.total)) return;
  requestPage += delta;
  return loadRequestExplorer();
}

async function selectRequestDetail(requestId) {
  if (requestListLoading || !requestPageSnapshot?.rows.some((row) => row.requestId === requestId)) return;
  const listGeneration = requestLoadGeneration;
  const generation = ++requestDetailGeneration;
  requestSelectedId = requestId;
  requestSelectedDetail = null;
  requestDetailLoading = true;
  renderRequestDetail(null, "Loading selected request…");
  updateRequestControls();
  const probe = await safeGetJson(`${endpoints.requestDetail}/${encodeURIComponent(requestId)}`);
  if (generation !== requestDetailGeneration || listGeneration !== requestLoadGeneration) return;
  requestDetailLoading = false;
  if (probe.ok && probe.data && probe.data.requestId === requestId) {
    requestSelectedDetail = { ...probe.data };
    requestDetailObservedAt = new Date().toISOString();
    renderRequestDetail(requestSelectedDetail);
  } else {
    renderRequestDetail(null, "Selected request unavailable. It may no longer be retained. Retry details or reload the page.");
  }
  updateRequestControls();
}

function requestCsvCell(value) {
  let cell = String(value);
  if (/^[\s\u0000-\u001f\u007f\uFEFF]*[=+\-@]/u.test(cell) || /^[\u0000-\u001f\u007f]/.test(cell)) cell = "'" + cell;
  return '"' + cell.replaceAll('"', '""') + '"';
}

function requestPageCsv() {
  if (requestListLoading || !requestPageSnapshot?.rows.length) return null;
  const { rows, page, total, query } = requestPageSnapshot;
  const context = ["Displayed page only", String(page + 1), String(total), requestQueryDescription(query)];
  return [["Export scope", "Page", "Matching retained requests", "Applied query", ...requestSafeFields(rows[0]).map(([label]) => label)],
    ...rows.map((row) => [...context, ...requestSafeFields(row).map(([, value]) => value)])]
    .map((row) => row.map(requestCsvCell).join(",")).join("\r\n") + "\r\n";
}

function requestDetailReport() {
  if (requestListLoading || requestDetailLoading || !requestSelectedDetail || !requestPageSnapshot) return null;
  return ["MoonGate selected retained request", "Estimated usage cost, not a billing statement.",
    "Zero cost/latency can mean unavailable in the source. Prompts, credentials and raw errors are excluded.",
    requestQueryDescription(requestPageSnapshot.query), "", ...requestSafeFields(requestSelectedDetail).map(([label, value]) => `${label}: ${value}`), ""].join("\n");
}

function downloadRequestExport(kind) {
  const contents = kind === "page" ? requestPageCsv() : requestDetailReport();
  if (contents == null) return;
  const csv = kind === "page";
  const url = URL.createObjectURL(new Blob([csv ? "\uFEFF" + contents : contents], { type: csv ? "text/csv;charset=utf-8" : "text/plain;charset=utf-8" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = csv ? `moongate-retained-page-${requestPageSnapshot.page + 1}.csv` : "moongate-selected-request.txt";
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

// Explicitly selected observations, not a live query or a durable evidence store.
// Keep only the display allowlist; never retain the raw detail response here.
const requestCollectionLimit = 100;
const requestCollectionByteLimit = 2 * 1024 * 1024;
let requestCollection = [];
let requestCollectionUI = null;
let requestCollectionMessage = "Choose Details, then Keep selected metadata. Collection stays in this tab until reload.";

function requestCollectionCsv() {
  if (!requestCollection.length) return null;
  const columns = ["Export scope", "Observed UTC", "Source page", "Applied query",
    ...requestCollection[0].fields.map(([label]) => label)];
  return [columns, ...requestCollection.map(entry => [
    "Selected observations only; not complete history or a billing statement" + (entry.fromReviewFile ? "; unverified local review file" : ""),
    entry.observedAt, String(entry.page + 1), entry.query,
    ...entry.fields.map(([, value]) => value),
  ])].map(row => row.map(requestCsvCell).join(",")).join("\r\n") + "\r\n";
}

function keepRequestObservation() {
  if (requestListLoading || requestDetailLoading || !requestPageSnapshot || !requestSelectedDetail || !requestDetailObservedAt) return false;
  const fields = requestSafeFields(requestSelectedDetail);
  const id = requestSelectedDetail.requestId;
  const previous = requestCollection.find(entry => entry.id === id);
  if (previous) {
    requestCollectionMessage = JSON.stringify(previous.fields) === JSON.stringify(fields)
      ? "This request is already kept. Its original observation and query are unchanged."
      : "This request now has different metadata. The kept observation is unchanged; inspect it, then remove it explicitly before keeping the new observation.";
    renderRequestCollection(); return false;
  }
  const candidate = { id, fields, observedAt: requestDetailObservedAt,
    page: requestPageSnapshot.page, query: requestQueryDescription(requestPageSnapshot.query) };
  if (requestCollection.length >= requestCollectionLimit || new Blob([JSON.stringify([...requestCollection, candidate])]).size > requestCollectionByteLimit) {
    requestCollectionMessage = "Collection limit reached (100 requests or 2 MiB). Export and remove observations before keeping more.";
    renderRequestCollection(); return false;
  }
  requestCollection.push(candidate);
  requestCollectionMessage = "Selected metadata kept. Page and filter changes will not replace it. Export before reloading or closing this tab.";
  renderRequestCollection(); return true;
}

function removeRequestObservation(id) {
  requestCollection = requestCollection.filter(entry => entry.id !== id);
  requestAnnotationNotes.delete(id);
  requestSubsetIds.delete(id);
  if (requestAnnotationId === id) requestAnnotationId = "";
  requestCollectionMessage = "Observation removed from this tab’s collection. Retained gateway records are unchanged.";
  renderRequestCollection();
}

function clearRequestCollection() {
  requestCollection = [];
  resetRequestSubset();
  requestAnnotationNotes.clear(); requestAnnotationSummary = ""; requestAnnotationId = "";
  requestCollectionMessage = "Collection and operator notes cleared from this tab. Retained gateway records are unchanged.";
  renderRequestCollection();
}

function downloadRequestCollection() {
  const contents = requestCollectionCsv();
  if (contents == null) return;
  const url = URL.createObjectURL(new Blob(["\uFEFF" + contents], { type: "text/csv;charset=utf-8" }));
  const link = document.createElement("a");
  link.href = url; link.download = "moongate-selected-request-observations.csv";
  document.body.appendChild(link); link.click(); link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

// A local review file resumes this manual investigation. It is never sent to
// usage APIs, treated as a request record, or accepted as verified gateway evidence.
const requestReviewSchema = "moongate.request-review.v1";
const requestReviewScope = "Selected observations only; not complete history, current gateway evidence, or a billing statement";
const requestReviewByteLimit = 3 * 1024 * 1024;
let requestReviewPending = null;
let requestReviewGeneration = 0;
let requestReviewMergeConfirmed = false;
let requestReviewMessage = "Save a review to resume later. Choose a saved review, then explicitly open it to replace this tab’s collection or merge it into the current investigation.";

function requestObservationSource(entry) {
  return entry.fromReviewFile ? "Local review file (unverified; not refreshed)" : "Retained detail read in this tab (not a live refresh)";
}

function requestReviewJson() {
  return serializeRequestReview(requestCollection, requestAnnotationDocument());
}

function serializeRequestReview(observations, annotations) {
  if (!observations.length) return null;
  const ids = new Set(observations.map(entry => entry.id));
  const hasNotes = annotations.summary !== "" || annotations.notes.length > 0;
  return JSON.stringify({
    schema: hasNotes ? "moongate.request-review.v2" : requestReviewSchema, scope: requestReviewScope,
    ...(hasNotes ? { annotations } : {}),
    observations: observations.map(entry => ({
      id: entry.id, observedAt: entry.observedAt, page: entry.page, query: entry.query,
      fields: entry.fields.map(([label, value]) => [label, value]),
    })),
    comparison: { baselineId: ids.has(requestComparisonBaseline) ? requestComparisonBaseline : "",
      candidateId: ids.has(requestComparisonCandidate) ? requestComparisonCandidate : "",
      differencesOnly: requestComparisonDifferencesOnly },
  }, null, 2) + "\n";
}

function downloadRequestReview(subset = false) {
  const contents = subset ? requestSubsetJson() : requestReviewJson();
  if (contents == null) return;
  const url = URL.createObjectURL(new Blob([contents], { type: "application/json;charset=utf-8" }));
  const link = document.createElement("a");
  link.href = url; link.download = subset ? "moongate-request-subset.json" : "moongate-request-review.json";
  document.body.appendChild(link); link.click(); link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function parseRequestReview(contents) {
  const fail = message => { throw new Error(message); };
  const exactKeys = (value, keys) => value && !Array.isArray(value) && typeof value === "object"
    && Object.keys(value).length === keys.length && keys.every(key => Object.hasOwn(value, key));
  if (typeof contents !== "string" || new Blob([contents]).size > requestReviewByteLimit) {
    fail("Choose a MoonGate review JSON file no larger than 3 MiB.");
  }
  let document;
  try { document = JSON.parse(contents.replace(/^\uFEFF/, "")); }
  catch { fail("Could not read JSON. Choose a file saved with Save review JSON."); }
  const annotated = document?.schema === "moongate.request-review.v2";
  if (!exactKeys(document, annotated ? ["schema", "scope", "observations", "comparison", "annotations"] : ["schema", "scope", "observations", "comparison"])
      || (!annotated && document.schema !== requestReviewSchema) || document.scope !== requestReviewScope) {
    fail("Unsupported review format. Choose a file saved with Save review JSON (version 1 or 2).");
  }
  const observations = document.observations;
  if (!Array.isArray(observations) || observations.length < 1 || observations.length > requestCollectionLimit) {
    fail("A review must contain between 1 and 100 selected observations.");
  }
  const labels = requestSafeFields({}).map(([label]) => label), ids = new Set();
  const normalized = observations.map(entry => {
    if (!exactKeys(entry, ["id", "observedAt", "page", "query", "fields"])
        || typeof entry.id !== "string" || !entry.id.trim() || ids.has(entry.id)
        || typeof entry.query !== "string" || !Number.isSafeInteger(entry.page) || entry.page < 0 || entry.page >= Number.MAX_SAFE_INTEGER
        || typeof entry.observedAt !== "string" || !Number.isFinite(Date.parse(entry.observedAt))
        || new Date(entry.observedAt).toISOString() !== entry.observedAt
        || !Array.isArray(entry.fields) || entry.fields.length !== labels.length
        || !entry.fields.every((field, index) => Array.isArray(field) && field.length === 2
          && field[0] === labels[index] && typeof field[1] === "string")
        || entry.fields[0][1] !== entry.id) {
      fail("Invalid observation metadata. Each request needs a unique ID, original capture context and the complete allowed display fields.");
    }
    ids.add(entry.id);
    return { id: entry.id, fields: entry.fields.map(([label, value]) => [label, value]),
      observedAt: entry.observedAt, page: entry.page, query: entry.query };
  });
  if (new Blob([JSON.stringify(normalized)]).size > requestCollectionByteLimit) {
    fail("Review metadata exceeds the collection’s 2 MiB limit.");
  }
  const comparison = document.comparison;
  if (!exactKeys(comparison, ["baselineId", "candidateId", "differencesOnly"])
      || typeof comparison.differencesOnly !== "boolean"
      || ![comparison.baselineId, comparison.candidateId].every(id => typeof id === "string" && (id === "" || ids.has(id)))) {
    fail("Invalid comparison choices. Select only request IDs contained in this review.");
  }
  const annotations = annotated ? document.annotations : { summary: "", notes: [] };
  const noteIds = new Set();
  if (!exactKeys(annotations, ["summary", "notes"]) || typeof annotations.summary !== "string"
      || annotations.summary.length > 8000 || !Array.isArray(annotations.notes)
      || annotations.notes.length > requestCollectionLimit
      || !annotations.notes.every(note => {
        if (!exactKeys(note, ["requestId", "text"]) || typeof note.requestId !== "string"
            || !ids.has(note.requestId) || noteIds.has(note.requestId)
            || typeof note.text !== "string" || note.text.length < 1 || note.text.length > 4000) return false;
        noteIds.add(note.requestId); return true;
      }) || new Blob([JSON.stringify(annotations)]).size > requestAnnotationByteLimit) {
    fail("Invalid operator annotations. Notes must refer to kept request IDs (4000 characters each, summary 8000; 128 KiB total).");
  }
  return { observations: normalized, comparison: { ...comparison }, annotations };
}

async function stageRequestReview(file) {
  const generation = ++requestReviewGeneration;
  requestReviewPending = null;
  requestReviewMergeConfirmed = false;
  requestReviewMessage = file ? "Reading local review file… Your current collection is unchanged." : "No review selected. Your current collection is unchanged.";
  renderRequestCollection();
  if (!file) return;
  try {
    if (!Number.isSafeInteger(file.size) || file.size < 1 || file.size > requestReviewByteLimit || typeof file.text !== "function") {
      throw new Error("Choose a MoonGate review JSON file no larger than 3 MiB.");
    }
    // File read errors are not rendered: they may include local paths or content.
    let contents;
    try { contents = await file.text(); }
    catch { throw new Error("Could not read the local file. Choose it again; your current collection is unchanged."); }
    if (generation !== requestReviewGeneration) return;
    requestReviewPending = parseRequestReview(contents);
    requestReviewMessage = `${requestReviewPending.observations.length} observations ready. File contents and capture times are unverified. Open saved review replaces this tab’s collection, comparison choices and operator notes; cancel keeps them. Merge preview below combines observations without replacing this investigation.`;
  } catch (error) {
    if (generation !== requestReviewGeneration) return;
    requestReviewMessage = error.message;
  }
  renderRequestCollection();
}

function cancelRequestReview() {
  ++requestReviewGeneration;
  requestReviewPending = null;
  requestReviewMergeConfirmed = false;
  requestReviewMessage = "File choice canceled. Your current collection and comparison are unchanged.";
  renderRequestCollection();
}

function openRequestReview() {
  if (!requestReviewPending) return;
  const { observations, comparison, annotations } = requestReviewPending;
  requestAnnotationSummary = annotations.summary;
  requestAnnotationNotes = new Map(annotations.notes.map(note => [note.requestId, note.text]));
  requestAnnotationId = "";
  requestCollection = observations.map(entry => ({ ...entry, fromReviewFile: true }));
  resetRequestSubset();
  requestComparisonBaseline = comparison.baselineId;
  requestComparisonCandidate = comparison.candidateId;
  requestComparisonDifferencesOnly = comparison.differencesOnly;
  ++requestReviewGeneration;
  requestReviewPending = null;
  requestReviewMergeConfirmed = false;
  requestReviewMessage = "Review opened locally. Saved metadata and capture times are unverified; no request was fetched, replayed or added to gateway usage.";
  requestCollectionMessage = "Opened saved observations. Inspect, compare or remove them, then Save review JSON again to keep your changes.";
  renderRequestCollection();
}

// Merge only explicitly staged local files. Matching IDs do not establish a
// common gateway, so the operator must first confirm a common ID namespace.
// This plan is recomputed for preview and click; it never mutates either review.
function requestReviewMergePlan() {
  if (!requestReviewPending) return null;
  const observations = [...requestCollection];
  const existing = new Map(requestCollection.map(entry => [entry.id, entry]));
  const notes = new Map(requestAnnotationNotes);
  const errors = [];
  let added = 0, duplicates = 0, notesAdded = 0;
  for (const entry of requestReviewPending.observations) {
    const current = existing.get(entry.id);
    if (!current) {
      observations.push({ ...entry, fromReviewFile: true }); added++;
    } else {
      duplicates++;
      if (JSON.stringify(current.fields) !== JSON.stringify(entry.fields)) {
        errors.push(`Different recorded metadata for request ${JSON.stringify(entry.id)}.`);
      }
    }
  }
  for (const note of requestReviewPending.annotations.notes) {
    if (notes.has(note.requestId) && notes.get(note.requestId) !== note.text) {
      errors.push(`Different operator notes for request ${JSON.stringify(note.requestId)}.`);
    } else if (!notes.has(note.requestId)) {
      notes.set(note.requestId, note.text); notesAdded++;
    }
  }
  const incomingSummary = requestReviewPending.annotations.summary;
  const separator = "\n\nImported review summary (operator-authored, unverified):\n";
  let summary = requestAnnotationSummary;
  let summaryAction = "Current summary kept.";
  if (incomingSummary && !summary) {
    summary = incomingSummary; summaryAction = "File summary will be adopted.";
  } else if (incomingSummary && summary !== incomingSummary && !summary.endsWith(separator + incomingSummary)) {
    summary += separator + incomingSummary;
    summaryAction = "File summary will be appended below the current summary, with an unverified imported-summary label.";
  } else if (incomingSummary) {
    summaryAction = "File summary already matches the current summary or its final imported-summary block; text kept once.";
  }
  const annotations = { summary, notes: observations.filter(entry => notes.has(entry.id))
    .map(entry => ({ requestId: entry.id, text: notes.get(entry.id) })) };
  if (observations.length > requestCollectionLimit
      || new Blob([JSON.stringify(observations)]).size > requestCollectionByteLimit) {
    errors.push("Combined collection exceeds 100 observations or 2 MiB. Save your current review, then remove observations before merging.");
  }
  if (summary.length > 8000 || new Blob([JSON.stringify(annotations)]).size > requestAnnotationByteLimit) {
    errors.push("Combined annotations exceed the 8000-character summary or 128 KiB total limit. Shorten notes or summaries before merging.");
  }
  return { observations, annotations, notes, added, duplicates, notesAdded, errors, summaryAction };
}

function renderRequestReviewMerge() {
  if (!requestCollectionUI) return;
  const ui = requestCollectionUI;
  const plan = requestReviewMergePlan();
  ui.mergeConfirm.disabled = !plan;
  ui.mergeConfirm.checked = requestReviewMergeConfirmed;
  ui.mergeReview.disabled = !plan || !requestReviewMergeConfirmed || plan.errors.length > 0;
  ui.mergePreview.textContent = !plan ? "Choose a saved review to preview a merge. Current work stays unchanged until you merge."
    : [plan.errors.length ? "Merge blocked; nothing will change." : "Merge preview (nothing changed yet):",
      `${plan.added} new observations; ${plan.duplicates} matching IDs keep the current observation and capture context; ${plan.notesAdded} new notes.`,
      plan.summaryAction, "Current comparison choices stay selected; file comparison choices are not imported.",
      ...plan.errors,
      ...(plan.errors.length ? ["Inspect both original reviews. Resolve conflicting notes or remove a conflicting current observation only after saving it, then check this preview again. No conflict is silently overwritten."] : []),
      "Resulting operator summary (unverified):", plan.annotations.summary || "No summary entered."].join("\n");
}

function mergeRequestReview() {
  const plan = requestReviewMergePlan();
  if (!plan || !requestReviewMergeConfirmed || plan.errors.length) {
    renderRequestReviewMerge(); return false;
  }
  requestCollection = plan.observations;
  requestAnnotationSummary = plan.annotations.summary;
  requestAnnotationNotes = plan.notes;
  ++requestReviewGeneration;
  requestReviewPending = null;
  requestReviewMergeConfirmed = false;
  requestReviewMessage = `Review merged locally: ${plan.added} new observations, ${plan.duplicates} matching IDs kept once, ${plan.notesAdded} new notes. Imported content is unverified. No request was fetched, replayed or added to gateway usage.`;
  requestCollectionMessage = "Combined investigation kept in this tab. Save review JSON to keep it after reload; original files are unchanged.";
  renderRequestCollection();
  return true;
}

// A focused handoff is a projection of kept observations. Search never fetches,
// selects or deletes records. Hidden selections remain explicit until cleared.
let requestSubsetIds = new Set();
let requestSubsetSearch = "";
let requestSubsetIncludeSummary = false;
let requestSubsetUI = null;

function resetRequestSubset() {
  requestSubsetIds.clear(); requestSubsetSearch = ""; requestSubsetIncludeSummary = false;
}

function filteredRequestObservations() {
  const search = requestSubsetSearch.trim().toLowerCase();
  return requestCollection.filter(entry => !search || [
    ...entry.fields.map(([, value]) => value), requestAnnotationNotes.get(entry.id) || "",
  ].some(value => value.toLowerCase().includes(search)));
}

function requestSubsetJson() {
  const observations = requestCollection.filter(entry => requestSubsetIds.has(entry.id));
  const annotations = { summary: requestSubsetIncludeSummary ? requestAnnotationSummary : "",
    notes: observations.filter(entry => requestAnnotationNotes.has(entry.id))
      .map(entry => ({ requestId: entry.id, text: requestAnnotationNotes.get(entry.id) })) };
  return serializeRequestReview(observations, annotations);
}

function renderRequestSubset() {
  if (!requestCollectionUI) return;
  if (!requestSubsetUI) {
    const make = (tag, text) => { const node = document.createElement(tag); if (text) node.textContent = text; return node; };
    const section = make("fieldset"); section.id = "request-subset";
    section.appendChild(make("legend", "Find observations and save a focused subset"));
    section.appendChild(make("p", "Search only the kept metadata and per-request notes below. Search hides rows, never changes your selection. A subset is a partial investigation, not complete usage or billing evidence. Notes are unverified and are not automatically redacted; inspect before sharing."));
    const searchLabel = make("label", "Search kept metadata and request notes (literal text) ");
    const search = make("input"); search.id = "request-subset-search"; search.type = "search";
    search.addEventListener("input", () => {
      requestSubsetSearch = search.value; renderRequestSubset(); renderRequestCollectionList();
    });
    searchLabel.appendChild(search); section.appendChild(searchLabel);
    const button = (id, label, action) => {
      const node = make("button", label); node.id = id; node.type = "button";
      node.className = "button-secondary"; node.addEventListener("click", action); section.appendChild(node); return node;
    };
    const reset = button("request-subset-show-all", "Show all kept observations", () => {
      requestSubsetSearch = ""; renderRequestSubset(); renderRequestCollectionList();
    });
    const select = button("request-subset-select-visible", "Add visible observations to subset", () => {
      for (const entry of filteredRequestObservations()) requestSubsetIds.add(entry.id);
      renderRequestSubset(); renderRequestCollectionList();
    });
    const clear = button("request-subset-clear", "Clear subset selection", () => {
      requestSubsetIds.clear(); renderRequestSubset(); renderRequestCollectionList();
    });
    const summaryLabel = make("label", "Include the entire investigation summary (may mention unselected requests) ");
    const includeSummary = make("input"); includeSummary.id = "request-subset-summary"; includeSummary.type = "checkbox";
    includeSummary.addEventListener("change", () => {
      requestSubsetIncludeSummary = includeSummary.checked && requestAnnotationSummary !== ""; renderRequestSubset();
    });
    summaryLabel.appendChild(includeSummary); section.appendChild(summaryLabel);
    const preview = make("pre"); preview.id = "request-subset-preview"; preview.setAttribute?.("role", "status");
    section.appendChild(preview);
    const save = button("request-subset-save", "Save subset review JSON", () => downloadRequestReview(true));
    // Place controls immediately before the list they filter.
    requestCollectionUI.subsetHost.appendChild(section);
    requestSubsetUI = { section, search, reset, select, clear, includeSummary, preview, save };
  }
  const existing = new Set(requestCollection.map(entry => entry.id));
  for (const id of requestSubsetIds) if (!existing.has(id)) requestSubsetIds.delete(id);
  const selected = requestCollection.filter(entry => requestSubsetIds.has(entry.id));
  const visible = filteredRequestObservations();
  const hidden = selected.filter(entry => !visible.includes(entry)).length;
  if (!requestAnnotationSummary) requestSubsetIncludeSummary = false;
  const ui = requestSubsetUI;
  if (ui.search.value !== requestSubsetSearch) ui.search.value = requestSubsetSearch;
  ui.reset.disabled = requestSubsetSearch === "";
  ui.select.disabled = visible.length === 0 || visible.every(entry => requestSubsetIds.has(entry.id));
  ui.clear.disabled = ui.save.disabled = selected.length === 0;
  ui.includeSummary.checked = requestSubsetIncludeSummary;
  ui.includeSummary.disabled = requestAnnotationSummary === "";
  ui.preview.textContent = [
    `${visible.length} of ${requestCollection.length} kept observations visible.`,
    `Partial investigation export: ${selected.length} of ${requestCollection.length} kept observations selected; ${hidden} selected observations hidden by search.`,
    `${selected.filter(entry => requestAnnotationNotes.has(entry.id)).length} selected request notes included. Investigation summary ${requestSubsetIncludeSummary ? "included in full" : "omitted"}.`,
    "Only comparison IDs contained in the subset will be retained. Full-review JSON, collection CSV and investigation report still include the whole collection.",
    "Selected request IDs (collection order):", ...selected.map(entry => JSON.stringify(entry.id)),
  ].join("\n");
}

function renderRequestCollection() {
  if (!requestCollectionUI) {
    const parent = $("requests");
    if (!parent) return;
    const make = (tag, value) => { const node = document.createElement(tag); if (value) node.textContent = value; return node; };
    const section = make("section"); section.id = "request-collection";
    const heading = make("h3", "Selected request observations");
    const notice = make("p", "Inspect and collect chosen metadata across pages. Estimates and zero/unavailable values remain unchanged. This is a manual selection, not complete history or a billing statement. No prompts, response bodies or raw errors are collected from gateway details. Reload clears this collection; Save review JSON lets you reopen it explicitly. Local review file contents are unverified.");
    const button = (id, label, action, parent = section) => {
      const node = make("button", label); node.id = id; node.type = "button";
      node.className = "button-secondary"; node.addEventListener("click", action); parent.appendChild(node); return node;
    };
    section.appendChild(heading); section.appendChild(notice);
    const keep = button("request-collection-keep", "Keep selected metadata", keepRequestObservation);
    const download = button("request-collection-export", "Export selected collection CSV", downloadRequestCollection);
    const clear = button("request-collection-clear", "Clear collection and notes", clearRequestCollection);
    const review = make("fieldset");
    review.appendChild(make("legend", "Save, reopen or combine investigations"));
    const saveReview = button("request-review-save", "Save review JSON", () => downloadRequestReview(), review);
    const pickerLabel = make("label", "Choose saved review JSON");
    const picker = make("input"); picker.id = "request-review-picker"; picker.type = "file"; picker.accept = ".json,application/json";
    picker.addEventListener("change", event => { const file = event.target.files?.[0]; event.target.value = ""; return stageRequestReview(file); });
    pickerLabel.appendChild(picker); review.appendChild(pickerLabel);
    const openReview = button("request-review-open", "Open saved review (replace collection)", openRequestReview, review);
    const mergeScope = make("label", "I confirm these reviews use the same gateway/request-ID namespace. File contents and origin are unverified.");
    const mergeConfirm = make("input"); mergeConfirm.id = "request-review-merge-confirm"; mergeConfirm.type = "checkbox";
    mergeConfirm.addEventListener("change", () => { requestReviewMergeConfirmed = mergeConfirm.checked; renderRequestReviewMerge(); });
    mergeScope.appendChild(mergeConfirm); review.appendChild(mergeScope);
    const mergePreview = make("pre"); mergePreview.id = "request-review-merge-preview"; mergePreview.setAttribute?.("role", "status");
    review.appendChild(mergePreview);
    const mergeReview = button("request-review-merge", "Merge saved review into collection", mergeRequestReview, review);
    const cancelReview = button("request-review-cancel", "Cancel file choice", cancelRequestReview, review);
    const reviewStatus = make("p"); reviewStatus.id = "request-review-status"; reviewStatus.setAttribute?.("role", "status");
    review.appendChild(reviewStatus); section.appendChild(review);
    const status = make("p"); status.id = "request-collection-status"; status.setAttribute?.("role", "status");
    const subsetHost = make("div");
    const list = make("div"); list.id = "request-collection-list";
    section.appendChild(status); section.appendChild(subsetHost); section.appendChild(list); parent.appendChild(section);
    requestCollectionUI = { section, subsetHost, keep, download, clear, status, list, saveReview, picker, openReview, cancelReview, reviewStatus, mergeConfirm, mergePreview, mergeReview };
  }
  const ui = requestCollectionUI;
  ui.keep.disabled = requestListLoading || requestDetailLoading || !requestSelectedDetail || !requestDetailObservedAt;
  ui.download.disabled = ui.saveReview.disabled = requestCollection.length === 0;
  ui.clear.disabled = requestCollection.length === 0 && requestAnnotationSummary === "" && requestAnnotationNotes.size === 0;
  ui.openReview.disabled = !requestReviewPending;
  ui.reviewStatus.textContent = requestReviewMessage;
  renderRequestReviewMerge();
  ui.status.textContent = `${requestCollection.length} of ${requestCollectionLimit} selected observations. ${requestCollectionMessage}`;
  renderRequestSubset();
  renderRequestCollectionList();
  renderRequestComparison();
  renderRequestAnnotations();
}

function renderRequestCollectionList() {
  const ui = requestCollectionUI;
  ui.list.innerHTML = "";
  for (const entry of filteredRequestObservations()) {
    const details = document.createElement("details");
    const summary = document.createElement("summary"); summary.textContent = `${entry.id} · observed ${entry.observedAt} · ${requestObservationSource(entry)}`;
    const content = document.createElement("pre"); content.textContent = `Source: ${requestObservationSource(entry)}\nSource page: ${entry.page + 1}\n${entry.query}\n` + entry.fields.map(([label, value]) => `${label}: ${value}`).join("\n");
    const remove = document.createElement("button"); remove.type = "button"; remove.className = "button-secondary";
    remove.textContent = "Remove observation"; remove.addEventListener("click", () => removeRequestObservation(entry.id));
    const choice = document.createElement("label"); choice.textContent = " Include in subset ";
    const checked = document.createElement("input"); checked.type = "checkbox";
    checked.checked = requestSubsetIds.has(entry.id);
    checked.setAttribute?.("aria-label", `Include request ${entry.id} in subset`);
    // Keep the disclosure open/closed when the operator clicks its checkbox.
    choice.addEventListener("click", event => event.stopPropagation?.());
    checked.addEventListener("change", () => {
      if (checked.checked) requestSubsetIds.add(entry.id); else requestSubsetIds.delete(entry.id);
      renderRequestSubset();
    });
    choice.appendChild(checked); summary.appendChild(choice);
    details.appendChild(summary); details.appendChild(content); details.appendChild(remove); ui.list.appendChild(details);
  }
}

// Operator interpretation is deliberately separate from gateway observations.
// No notes are sent to APIs, inferred from telemetry, or treated as approval.
const requestAnnotationByteLimit = 128 * 1024;
let requestAnnotationSummary = "";
let requestAnnotationNotes = new Map();
let requestAnnotationId = "";
let requestAnnotationUI = null;

function requestAnnotationDocument(summary = requestAnnotationSummary, notes = requestAnnotationNotes) {
  return { summary, notes: requestCollection.filter(entry => notes.has(entry.id))
    .map(entry => ({ requestId: entry.id, text: notes.get(entry.id) })) };
}

function changeRequestAnnotation(kind, value) {
  const summary = kind === "summary" ? value : requestAnnotationSummary;
  const notes = new Map(requestAnnotationNotes);
  if (kind !== "summary") {
    if (!requestCollection.some(entry => entry.id === requestAnnotationId)) return;
    if (value === "") notes.delete(requestAnnotationId); else notes.set(requestAnnotationId, value);
  }
  const ui = requestAnnotationUI;
  if (typeof value !== "string" || value.length > (kind === "summary" ? 8000 : 4000)
      || new Blob([JSON.stringify(requestAnnotationDocument(summary, notes))]).size > requestAnnotationByteLimit) {
    ui.status.textContent = "That edit was not kept: use at most 4000 characters per note, 8000 for the summary, and 128 KiB total. Previous text is retained.";
    if (kind === "summary") ui.summary.value = requestAnnotationSummary;
    else ui.note.value = requestAnnotationNotes.get(requestAnnotationId) || "";
    return;
  }
  requestAnnotationSummary = summary; requestAnnotationNotes = notes;
  requestCollectionUI.clear.disabled = requestCollection.length === 0 && summary === "" && notes.size === 0;
  renderRequestReviewMerge();
  renderRequestSubset();
  if (kind !== "summary" && requestSubsetSearch.trim()) renderRequestCollectionList();
  ui.status.textContent = "Text kept in this tab only. Save review JSON to keep it after reload. Operator annotations are unverified, not gateway facts.";
}

function requestInvestigationReport() {
  if (!requestCollection.length) return null;
  const block = value => String(value).split(/\r\n|\r|\n/).map(line => "  | " + line).join("\n");
  const lines = ["MoonGate request investigation", requestReviewScope + ".",
    "Operator annotations below are unverified interpretations, not gateway facts, approval, or incident closure.",
    "Gateway metadata uses the existing allowlist; notes are user-written and are NOT automatically redacted. Inspect before sharing.",
    "Estimated costs are not settled charges; zero cost/timing may be unavailable. No request was replayed for this report.",
    "", "Operator-authored investigation summary (unverified):", block(requestAnnotationSummary || "No summary entered."), ""];
  for (const entry of requestCollection) {
    lines.push("Kept observation:", block(entry.id), "Observation source:", block(requestObservationSource(entry)),
      "Observed UTC:", block(entry.observedAt), "Source page:", block(entry.page + 1), "Applied query:", block(entry.query));
    for (const [label, value] of entry.fields) lines.push(label + ":", block(value));
    lines.push("Operator-authored note for this request (unverified):", block(requestAnnotationNotes.get(entry.id) || "No note entered."), "");
  }
  const baseline = requestCollection.find(entry => entry.id === requestComparisonBaseline);
  const candidate = requestCollection.find(entry => entry.id === requestComparisonCandidate);
  if (baseline && candidate && baseline.id !== candidate.id) {
    lines.push("Comparison of kept observations (candidate minus baseline; no causal conclusion):",
      "Baseline:", block(baseline.id), "Candidate:", block(candidate.id),
      requestComparisonDifferencesOnly ? "Identical displayed fields omitted." : "All displayed fields included.");
    for (const row of requestComparisonRows(baseline, candidate).filter(row => !requestComparisonDifferencesOnly || row.state !== "Same displayed value")) {
      lines.push(row.label + ":", block("Baseline: " + row.before), block("Candidate: " + row.after), block(row.state), block(row.delta));
    }
  }
  return lines.join("\n") + "\n";
}

function downloadRequestInvestigation() {
  const contents = requestInvestigationReport();
  if (contents === null) return;
  const url = URL.createObjectURL(new Blob([contents], { type: "text/plain;charset=utf-8" }));
  const link = document.createElement("a"); link.href = url; link.download = "moongate-request-investigation.txt";
  document.body.appendChild(link); link.click(); link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function renderRequestAnnotations() {
  if (!requestCollectionUI) return;
  if (!requestAnnotationUI) {
    const make = (tag, text = "") => { const node = document.createElement(tag); node.textContent = text; return node; };
    const section = make("fieldset"); section.id = "request-annotations";
    section.appendChild(make("legend", "Write investigation notes"));
    section.appendChild(make("p", "These are your unverified annotations, separate from recorded metadata. Notes are not automatically redacted. Do not enter credentials. Text stays in this tab until Save review JSON; inspect files before sharing."));
    const label = (text, control) => { const node = make("label", text); node.appendChild(control); section.appendChild(node); };
    const summary = make("textarea"); summary.id = "request-investigation-summary"; summary.rows = 4; summary.maxLength = 8000;
    label("Investigation summary (operator-authored)", summary);
    summary.addEventListener("input", () => changeRequestAnnotation("summary", summary.value));
    const selected = make("select"); selected.id = "request-note-id";
    label("Kept request to annotate", selected);
    selected.addEventListener("change", () => { requestAnnotationId = selected.value; renderRequestAnnotations(); });
    const note = make("textarea"); note.id = "request-note-text"; note.rows = 4; note.maxLength = 4000;
    label("Note for the selected request (operator-authored)", note);
    note.addEventListener("input", () => changeRequestAnnotation("note", note.value));
    const download = make("button", "Export investigation report"); download.type = "button"; download.className = "button-secondary";
    download.id = "request-investigation-export"; download.addEventListener("click", downloadRequestInvestigation); section.appendChild(download);
    const status = make("p", "Save review JSON retains these notes for later editing. The report is a one-way readable export.");
    status.id = "request-annotation-status"; status.setAttribute?.("role", "status"); section.appendChild(status);
    requestCollectionUI.section.appendChild(section);
    requestAnnotationUI = { section, summary, selected, note, download, status };
  }
  const ui = requestAnnotationUI;
  if (!requestCollection.some(entry => entry.id === requestAnnotationId)) requestAnnotationId = "";
  const ids = JSON.stringify(requestCollection.map(entry => entry.id));
  if (ui.optionIds !== ids) {
    ui.selected.innerHTML = "";
    for (const id of ["", ...requestCollection.map(entry => entry.id)]) {
      const option = document.createElement("option"); option.value = id; option.textContent = id || "Choose a kept request"; ui.selected.appendChild(option);
    }
    ui.optionIds = ids;
  }
  ui.summary.value = requestAnnotationSummary;
  ui.selected.value = requestAnnotationId;
  ui.note.value = requestAnnotationNotes.get(requestAnnotationId) || "";
  ui.note.disabled = !requestAnnotationId;
  ui.download.disabled = requestCollection.length === 0;
}

// Compare the immutable allowlisted observations, never live detail responses.
// Explicit choices avoid treating adjacent rows or similar names as a matched pair.
let requestComparisonUI = null;
let requestComparisonBaseline = "";
let requestComparisonCandidate = "";
let requestComparisonDifferencesOnly = true;
const requestComparisonMeasures = new Map([
  ["Estimated cost USD", "estimate"], ["Input tokens", "count"], ["Output tokens", "count"],
  ["Cache read tokens", "count"], ["Cache write tokens", "count"],
  ["Latency ms", "timing"], ["First token ms", "timing"], ["Duration ms", "timing"],
]);

function requestComparisonNumber(value, kind) {
  // Do not coerce blanks, annotations, booleans or unsafe counters into numbers.
  if (!/^(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?$/.test(value)) return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0 || parsed > Number.MAX_SAFE_INTEGER) return null;
  if (kind === "count" && (!/^(?:0|[1-9]\d*)$/.test(value) || !Number.isSafeInteger(parsed))) return null;
  // The retained API does not distinguish zero cost/timing from missing data.
  if (kind !== "count" && parsed === 0) return null;
  return parsed;
}

function requestComparisonRows(baseline, candidate) {
  const right = new Map(candidate.fields);
  return baseline.fields.map(([label, before]) => {
    const after = right.get(label) ?? "Unavailable";
    const kind = requestComparisonMeasures.get(label);
    const a = kind ? requestComparisonNumber(before, kind) : null;
    const b = kind ? requestComparisonNumber(after, kind) : null;
    const unavailable = before === "Unavailable" || after === "Unavailable" || (kind && (a === null || b === null));
    const state = unavailable ? "Not comparable" : before === after ? "Same displayed value" : "Different displayed value";
    let delta = kind ? "Unavailable" : "Not a numeric measure";
    if (kind && !unavailable) {
      const difference = b - a;
      const formatted = kind === "count" ? String(difference) : String(Number(difference.toPrecision(12)));
      delta = `${difference > 0 ? "+" : ""}${formatted}${kind === "estimate" ? " USD estimated (approx.)" : kind === "timing" ? " ms (approx.)" : " tokens"}`;
    }
    return { label, before, after, state, delta };
  });
}

function renderRequestComparison() {
  if (!requestCollectionUI) return;
  const make = (tag, value = "") => { const node = document.createElement(tag); node.textContent = value; return node; };
  if (!requestComparisonUI) {
    const section = make("section"); section.id = "request-comparison";
    section.appendChild(make("h3", "Compare two kept requests"));
    section.appendChild(make("p", "Choose a baseline and candidate from your kept observations. Differences describe recorded metadata only. These may be unrelated requests with different workloads or outcomes; they do not establish a cause, benchmark, savings or provider charges. Zero cost/timing remains ambiguous."));
    const controls = make("div"); controls.className = "request-filters";
    const select = (id, label, update) => {
      const wrapper = make("label", label), node = make("select"); node.id = id;
      node.addEventListener("change", () => { update(node.value); renderRequestComparison(); });
      wrapper.appendChild(node); controls.appendChild(wrapper); return node;
    };
    const baseline = select("request-compare-baseline", "Baseline request", value => { requestComparisonBaseline = value; });
    const candidate = select("request-compare-candidate", "Candidate request", value => { requestComparisonCandidate = value; });
    const button = (id, label, action) => {
      const node = make("button", label); node.id = id; node.type = "button"; node.className = "button-secondary";
      node.addEventListener("click", action); controls.appendChild(node); return node;
    };
    const swap = button("request-compare-swap", "Swap baseline and candidate", () => {
      [requestComparisonBaseline, requestComparisonCandidate] = [requestComparisonCandidate, requestComparisonBaseline];
      renderRequestComparison();
    });
    const clear = button("request-compare-clear", "Clear comparison choices", () => {
      requestComparisonBaseline = requestComparisonCandidate = ""; renderRequestComparison();
    });
    const toggleLabel = make("label");
    const differences = make("input"); differences.type = "checkbox"; differences.id = "request-compare-differences";
    differences.checked = requestComparisonDifferencesOnly;
    differences.addEventListener("change", () => { requestComparisonDifferencesOnly = differences.checked; renderRequestComparison(); });
    toggleLabel.appendChild(differences); toggleLabel.appendChild(make("span", "Show only differences and unavailable fields"));
    const status = make("p"); status.id = "request-compare-status"; status.setAttribute?.("role", "status");
    const context = make("pre"); context.id = "request-compare-context";
    const wrap = make("div"); wrap.className = "table-wrap";
    const table = make("table"); table.id = "request-compare-table";
    const caption = make("caption", "Kept metadata; numeric deltas are candidate minus baseline, arithmetic only");
    const head = make("thead"), header = make("tr");
    for (const label of ["Field", "Baseline", "Candidate", "Comparison", "Recorded delta"]) {
      const cell = make("th", label); cell.scope = "col"; header.appendChild(cell);
    }
    head.appendChild(header); const body = make("tbody");
    table.appendChild(caption); table.appendChild(head); table.appendChild(body); wrap.appendChild(table);
    for (const node of [controls, toggleLabel, status, context, wrap]) section.appendChild(node);
    requestCollectionUI.section.appendChild(section);
    requestComparisonUI = { section, baseline, candidate, swap, clear, differences, status, context, body, table };
  }
  const ui = requestComparisonUI;
  ui.differences.checked = requestComparisonDifferencesOnly;
  const populate = (node, selected) => {
    if (!requestCollection.some(entry => entry.id === selected)) selected = "";
    node.innerHTML = "";
    const empty = make("option", "Choose a kept request"); empty.value = ""; node.appendChild(empty);
    for (const entry of requestCollection) {
      const option = make("option", `${entry.id} · observed ${entry.observedAt}`); option.value = entry.id; node.appendChild(option);
    }
    node.value = selected; node.disabled = requestCollection.length === 0; return selected;
  };
  requestComparisonBaseline = populate(ui.baseline, requestComparisonBaseline);
  requestComparisonCandidate = populate(ui.candidate, requestComparisonCandidate);
  const baseline = requestCollection.find(entry => entry.id === requestComparisonBaseline);
  const candidate = requestCollection.find(entry => entry.id === requestComparisonCandidate);
  ui.clear.disabled = !baseline && !candidate;
  ui.swap.disabled = !baseline || !candidate || baseline === candidate;
  ui.body.innerHTML = ""; ui.context.textContent = "";
  if (!baseline || !candidate || baseline === candidate) {
    ui.status.textContent = baseline && baseline === candidate
      ? "Choose two different kept request IDs. A request cannot be compared with itself."
      : "Keep two requests using Details and Keep selected metadata, then choose a baseline and candidate.";
    return;
  }
  ui.context.textContent = [["Baseline", baseline], ["Candidate", candidate]].map(([role, entry]) =>
    `${role}: ${entry.id}\nObserved UTC: ${entry.observedAt}\nSource page: ${entry.page + 1}\n${entry.query}\nSource: ${requestObservationSource(entry)}`).join("\n\n");
  const rows = requestComparisonRows(baseline, candidate);
  const changed = rows.filter(row => row.state === "Different displayed value").length;
  const unavailable = rows.filter(row => row.state === "Not comparable").length;
  ui.status.textContent = `${changed} differing displayed fields; ${unavailable} unavailable or ambiguous; ${rows.length - changed - unavailable} identical displayed fields. ${requestComparisonDifferencesOnly ? "Identical fields are hidden." : "All fields are shown."} Comparison uses kept observations, not a live refresh.`;
  for (const row of rows.filter(row => !requestComparisonDifferencesOnly || row.state !== "Same displayed value")) {
    const tr = make("tr");
    for (const [index, value] of [row.label, row.before, row.after, row.state, row.delta].entries()) {
      const cell = make(index === 0 ? "th" : "td", value); if (index === 0) cell.scope = "row"; tr.appendChild(cell);
    }
    ui.body.appendChild(tr);
  }
}

// File exploration has its own snapshot. It never updates live usage or retained logs.
let usageFileSnapshot = null;
let usageFileGeneration = 0;
let usageFileSource = "Pasted usage";
const usageFileFilters = ["app", "provider", "model", "start", "end"];
function usageFileInvalidate(message = "Changed. Choose Open / apply filters to refresh.") {
  usageFileGeneration++;
  usageFileSnapshot = null;
  text("usage-file-status", message);
  text("usage-file-summary", "");
  $("usage-file-rows")?.replaceChildren();
  for (const id of ["usage-file-json", "usage-file-report"]) if ($(id)) $(id).disabled = true;
}
async function openUsageFile() {
  usageFileInvalidate("Reading usage rows…");
  const generation = usageFileGeneration;
  try {
    const content = $("usage-file-content").value;
    if (new TextEncoder().encode(content).length > 4 * 1024 * 1024) throw new Error("Usage file exceeds the 4 MiB limit.");
    const result = await postJson(endpoints.usagePreview, {
      content, sourceName: usageFileSource,
      app: $("usage-file-app").value.trim(), provider: $("usage-file-provider").value.trim(), model: $("usage-file-model").value.trim(),
      startDay: $("usage-file-start").value.trim(), endDay: $("usage-file-end").value.trim(),
    });
    if (generation !== usageFileGeneration) return;
    if (result?.schema !== "moongate.usage-file.v1" || !Array.isArray(result.data) || typeof result.report !== "string") throw new Error("Unreadable usage preview response.");
    usageFileSnapshot = result;
    const coverage = result.sourceCoverageUnknown
      ? `${result.importedRows} available rows; original source coverage is unknown`
      : `${result.importedRows} available of ${result.sourceTotal} source rows`;
    text("usage-file-status", `${result.sourceName}: ${result.data.length} filtered rows from ${coverage}.${result.partial ? " PARTIAL SOURCE: totals cover available rows only." : ""} Temporary preview; live usage is unchanged.`);
    text("usage-file-summary", result.report);
    const container = $("usage-file-rows");
    for (const row of result.data.slice(0, 100)) {
      const item = document.createElement("div");
      item.className = "row-card";
      item.textContent = `${row.date || "Undated"} · ${row.appType} · ${row.providerId} · ${row.model} · ${row.totalTokens} tokens · ${row.totalCostUsd == null ? "Unknown cost" : `USD ${row.totalCostUsd} estimated`}`;
      container.appendChild(item);
    }
    if (result.data.length > 100) {
      const notice = document.createElement("p");
      notice.textContent = "First 100 rows displayed. Totals and downloads include all filtered rows.";
      container.appendChild(notice);
    }
    for (const id of ["usage-file-json", "usage-file-report"]) $(id).disabled = false;
  } catch (error) {
    if (generation === usageFileGeneration) usageFileInvalidate(error.message || String(error));
  }
}
async function loadUsageFile(file) {
  if (!file) return;
  usageFileInvalidate("Reading file…");
  const generation = usageFileGeneration;
  $("usage-file-content").value = "";
  try {
    if (file.size > 4 * 1024 * 1024) throw new Error("Usage file exceeds the 4 MiB limit.");
    const content = await file.text();
    if (generation !== usageFileGeneration) return;
    $("usage-file-content").value = content;
    usageFileSource = file.name;
    text("usage-file-status", `${file.name} ready. Choose Open / apply filters.`);
  } catch (error) { if (generation === usageFileGeneration) usageFileInvalidate(error.message || String(error)); }
}
function usageFileExport(kind) {
  if (!usageFileSnapshot) return null;
  // Preserve sourceTotal when a filtered/paginated export is reopened.
  return kind === "json" ? JSON.stringify(usageFileSnapshot, null, 2) + "\n" : usageFileSnapshot.report;
}
function downloadUsageFile(kind) {
  const content = usageFileExport(kind);
  if (content == null) return;
  const url = URL.createObjectURL(new Blob([content], { type: kind === "json" ? "application/json;charset=utf-8" : "text/plain;charset=utf-8" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = `moongate-usage-filtered.${kind === "json" ? "json" : "txt"}`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
function resetUsageFileFilters() {
  for (const field of usageFileFilters) $("usage-file-" + field).value = "";
}
$("usage-file-form")?.addEventListener("submit", event => { event.preventDefault(); openUsageFile(); });
$("usage-file-picker")?.addEventListener("change", event => loadUsageFile(event.target.files?.[0]));
$("usage-file-content")?.addEventListener("input", () => {
  usageFileSource = "Pasted usage";
  $("usage-file-picker").value = "";
  usageFileInvalidate();
});
for (const field of usageFileFilters) $("usage-file-" + field)?.addEventListener("input", () => usageFileInvalidate());
$("usage-file-json")?.addEventListener("click", () => downloadUsageFile("json"));
$("usage-file-report")?.addEventListener("click", () => downloadUsageFile("report"));
$("usage-file-reset")?.addEventListener("click", () => { resetUsageFileFilters(); openUsageFile(); });
$("usage-file-clear")?.addEventListener("click", () => {
  $("usage-file-form").reset(); resetUsageFileFilters(); usageFileSource = "Pasted usage";
  usageFileInvalidate("No usage file open.");
});
$("usage-file-sample")?.addEventListener("click", () => {
  resetUsageFileFilters();
  usageFileInvalidate("Sample ready. Choose Open / apply filters. Try filtering app to codex.");
  usageFileSource = "Sample usage (partial export)";
  $("usage-file-picker").value = "";
  $("usage-file-content").value = JSON.stringify({ data: [
    { requestId: "demo-1", appType: "codex", providerId: "local-fixture", model: "moon-small", date: "2026-10-06", inputTokens: 1200, outputTokens: 300, totalCostUsd: "0.0045" },
    { request_id: "demo-2", app_type: "codex", provider_id: "local-fixture", model: "moon-small", date: "2026-10-07", input_tokens: 200, output_tokens: 50, total_cost_usd: "0" },
    { requestId: "demo-3", appType: "claude", providerId: "other-fixture", model: "moon-large", date: "2026-10-07", inputTokens: 800, outputTokens: 400 },
  ], total: 12, page: 0, pageSize: 3 }, null, 2);
});
