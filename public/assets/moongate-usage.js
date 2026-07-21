let usageLoadGeneration = 0;

function renderStack(id, rows, labelKeys) {
  const target = $(id);
  if (!target) return;
  target.innerHTML = "";
  if (rows.length === 0) {
    target.innerHTML = `<div class="row-card"><strong>No data yet</strong><small>Use moongate through the proxy to populate this panel.</small></div>`;
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

function renderRequestDetail(detail) {
  const target = $("request-detail");
  if (!target) return;
  if (!detail || typeof detail !== "object") {
    text("request-detail-id", "No selection");
    target.innerHTML = `<div><span>Status</span><strong>No request selected</strong></div>`;
    return;
  }
  text("request-detail-id", firstString(detail, ["requestId"], "Request"));
  const fields = [
    ["App", firstString(detail, ["appType"])],
    ["Provider", firstString(detail, ["providerName", "providerId"])],
    ["Model", firstString(detail, ["model", "requestModel"])],
    ["Pricing", firstString(detail, ["pricingModel"], "")],
    ["Status", firstString(detail, ["statusCode"])],
    ["Cost", money(detail.totalCostUsd ?? detail.totalCost ?? 0)],
    ["Input", compact(detail.inputTokens)],
    ["Output", compact(detail.outputTokens)],
    ["Cache Read", compact(detail.cacheReadTokens)],
    ["Cache Write", compact(detail.cacheCreationTokens)],
    ["Latency", `${compact(detail.latencyMs)} ms`],
    ["Streaming", firstString(detail, ["isStreaming"])],
  ];
  target.innerHTML = fields
    .map(([label, value]) => `<div><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></div>`)
    .join("");
}

function renderLogs(data) {
  const rows = arrayFrom(data, ["logs", "items", "requests", "data"]);
  const target = $("request-log");
  if (!target) return;
  target.innerHTML = "";
  if (rows.length === 0) {
    target.innerHTML = `<div class="log-item"><strong>No recent requests</strong><small>Requests will appear here after proxy traffic.</small></div>`;
    return;
  }
  for (const row of rows.slice(0, 12)) {
    const route = firstString(row, ["path", "route", "endpoint", "requestPath"]);
    const requestId = firstString(row, ["requestId", "id"], "");
    const provider = firstString(row, ["providerName", "providerId", "provider"], "");
    const model = firstString(row, ["model", "modelId"], "");
    const status = firstString(row, ["statusCode", "status", "code"]);
    const div = document.createElement("div");
    div.className = "log-item";
    div.innerHTML = `
      <strong>${escapeHtml(route)}</strong>
      <small>${escapeHtml([provider, model, status].filter(Boolean).join(" | "))}</small>
      ${requestId ? `<button type="button" data-request-id="${escapeHtml(requestId)}">Details</button>` : ""}
    `;
    target.appendChild(div);
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
  const [summaryProbe, trendsProbe, providerStatsProbe, modelStatsProbe, logsProbe] = await Promise.all([
    safeGetJson(endpoint(endpoints.usageSummary, params)),
    safeGetJson(endpoint(endpoints.usageTrends, params)),
    safeGetJson(endpoint(endpoints.providerStats, params)),
    safeGetJson(endpoint(endpoints.modelStats, params)),
    safeGetJson(endpoint(endpoints.usageLogs, { ...params, pageSize: 12 })),
  ]);
  if (generation !== usageLoadGeneration) {
    return { warningCount: 0, recentRequestCount: 0, stale: true };
  }
  const summary = probeData(summaryProbe, {});
  const trends = probeData(trendsProbe, {});
  const providerStats = probeData(providerStatsProbe, {});
  const modelStats = probeData(modelStatsProbe, {});
  const logs = probeData(logsProbe, {});
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
  const logRows = arrayFrom(logs, ["logs", "items", "requests", "data"]);
  if (logsProbe.ok) {
    renderLogs(logs);
  } else {
    renderStackError("request-log", logsProbe.error);
  }
  mergeReadinessState({ recentRequestCount: logsProbe.ok ? logRows.length : 0 });
  return {
    warningCount: [summaryProbe, trendsProbe, providerStatsProbe, modelStatsProbe, logsProbe]
      .some((probe) => !probe.ok) ? 1 : 0,
    recentRequestCount: logsProbe.ok ? logRows.length : 0,
  };
}
