// Product regressions. The native whitebox test also runs this against real routes.
// node --test tests/moongate-requests.test.cjs
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");
const root = process.env.MOONGATE_TEST_ROOT || path.resolve(__dirname, "..");
const asset = (name) => fs.readFileSync(path.join(root, "public/assets", name), "utf8");
const deferred = () => { let resolve; const promise = new Promise((yes) => { resolve = yes; }); return { promise, resolve }; };
const row = (id, more = {}) => ({ requestId: id, createdAt: 1750000000, appType: "claude", providerId: "fixture", providerName: "Fixture", model: "fixture-moon", statusCode: 200, totalCostUsd: "0.000123", latencyMs: 42, inputTokens: 100, outputTokens: 12, cacheReadTokens: 2, cacheCreationTokens: 0, dataSource: "proxy", ...more });
const page = (rows, current = 0, total = rows.length) => ({ ok: true, data: { data: rows, total, page: current, pageSize: 12 } });

function harness(probe = async () => page([]), base = "http://fixture.invalid", served = {}) {
  const nodes = new Map();
  const downloads = [];
  const blobs = [];
  const revocations = [];
  const element = () => ({ value: "", textContent: "", children: [], disabled: false, events: {},
    addEventListener(type, listener) { this.events[type] = listener; },
    appendChild(child) { this.children.push(child); },
    set innerHTML(value) { this.markup = value; this.children = []; },
    get innerHTML() { return this.markup || ""; },
    click() { downloads.push({ href: this.href, download: this.download }); }, remove() {},
  });
  const get = (id) => { if (!nodes.has(id)) nodes.set(id, element()); return nodes.get(id); };
  const urls = class extends URL {};
  urls.createObjectURL = (blob) => { blobs.push(blob); return "blob:fixture"; };
  urls.revokeObjectURL = (url) => revocations.push(url);
  const context = vm.createContext({
    URL: urls, Blob, setTimeout: (fn) => fn(), Date, console,
    window: { location: { origin: base } },
    document: { getElementById: get, createElement: element, body: element(),
      querySelector: (selector) => selector === "[data-moongate-endpoints]" ? { getAttribute: () => JSON.stringify({ usageLogs: "/usage/logs", requestDetail: "/usage/request-detail", usageSummary: "/usage/summary", usageTrends: "/usage/trends", providerStats: "/usage/provider-stats", modelStats: "/usage/model-stats" }) } : null },
    fetch: async (url, options) => fetch(new URL(url, base), { ...options, headers: { ...options?.headers, Origin: base } }),
    probe, readiness: [],
  });
  const run = (source) => vm.runInContext(source, context);
  run(served["moongate-core.js"] ?? asset("moongate-core.js"));
  run(served["moongate-usage.js"] ?? asset("moongate-usage.js"));
  run("mergeReadinessState = (value) => readiness.push(value)");
  if (probe) run("safeGetJson = probe");
  get("request-range").value = "604800";
  return { run, context, get, downloads, blobs, revocations,
    ids: () => JSON.parse(run("JSON.stringify(requestPageSnapshot?.rows.map(row => row.requestId) || [])")),
    snapshot: () => JSON.parse(run("JSON.stringify(requestPageSnapshot)")),
  };
}

function parseCsv(csv) {
  const rows = []; let row = [], field = "", quoted = false;
  for (let i = 0; i < csv.length; i++) {
    const ch = csv[i];
    if (ch === '"') { if (quoted && csv[i + 1] === '"') { field += '"'; i++; } else quoted = !quoted; }
    else if (!quoted && ch === ",") { row.push(field); field = ""; }
    else if (!quoted && ch === "\r" && csv[i + 1] === "\n") { row.push(field); rows.push(row); row = []; field = ""; i++; }
    else field += ch;
  }
  assert.equal(quoted, false);
  return rows;
}

test("paging uses the applied query and fixed interval; apply and reset return to page one", async () => {
  const calls = [];
  const h = harness(async (url) => {
    const q = new URL(url, "http://fixture.invalid").searchParams; calls.push(q);
    const p = Number(q.get("page"));
    return page(Array.from({ length: p === 2 ? 1 : 12 }, (_, i) => row(`p${p}-${i}`)), p, 25);
  });
  h.get("request-provider").value = "月 & \"quoted\"\nprovider";
  h.get("request-model").value = "=SUM(A1)";
  h.get("request-status").value = "500";
  await h.run("applyRequestFilters()");
  assert.match(h.get("request-page-summary").textContent, /Showing 1–12 of 25/);
  assert.equal(h.get("request-prev").disabled, true);
  h.get("request-provider").value = "not applied";
  await h.run("changeRequestPage(1)");
  assert.match(h.get("request-page-summary").textContent, /Showing 13–24 of 25/);
  await h.run("changeRequestPage(1)");
  assert.match(h.get("request-page-summary").textContent, /Showing 25–25 of 25/);
  assert.equal(h.get("request-next").disabled, true);
  await h.run("changeRequestPage(1)");
  assert.equal(calls.length, 3);
  assert.equal(calls[1].get("providerName"), calls[0].get("providerName"));
  assert.equal(calls[2].get("endDate"), calls[0].get("endDate"));
  assert.equal(calls[2].get("startDate"), calls[0].get("startDate"));
  await h.run("applyRequestFilters()");
  assert.equal(calls[3].get("page"), "0");
  assert.equal(calls[3].get("providerName"), "not applied");
  await h.run("applyRequestFilters(true)");
  assert.equal(calls[4].get("page"), "0");
  assert.equal(calls[4].has("providerName"), false);
  assert.equal(calls[4].has("model"), false);
  assert.equal(calls[4].has("statusCode"), false);
  h.get("request-status").value = "200junk";
  await h.run("applyRequestFilters()");
  assert.equal(calls.length, 5);
  assert.match(h.get("request-feedback").textContent, /100 to 599/);
});

test("reversed list responses and A-B-A queries cannot restore stale pages or exports", async () => {
  const waits = [deferred(), deferred(), deferred()]; let n = 0;
  const h = harness(() => waits[n++].promise);
  h.get("request-model").value = "A"; const a = h.run("applyRequestFilters()");
  h.get("request-model").value = "B"; const b = h.run("applyRequestFilters()");
  h.get("request-model").value = "A"; const again = h.run("applyRequestFilters()");
  assert.equal(h.run("requestPageCsv()"), null);
  waits[2].resolve(page([row("new-A")])); await again;
  waits[1].resolve(page([row("B")])); await b;
  waits[0].resolve(page([row("old-A")])); await a;
  assert.deepEqual(h.ids(), ["new-A"]);
  assert.match(h.run("requestPageCsv()"), /new-A/);
  assert.doesNotMatch(h.run("requestPageCsv()"), /old-A/);
});

test("detail A-B-A and list changes invalidate previous detail responses", async () => {
  const waits = [deferred(), deferred(), deferred(), deferred()]; let n = 0;
  const h = harness((url) => url.includes("request-detail") ? waits[n++].promise : Promise.resolve(page([row("A"), row("B")])));
  await h.run("loadRequestExplorer()");
  const a = h.run('selectRequestDetail("A")');
  const b = h.run('selectRequestDetail("B")');
  const again = h.run('selectRequestDetail("A")');
  waits[2].resolve({ ok: true, data: row("A", { model: "latest" }) }); await again;
  waits[0].resolve({ ok: true, data: row("A", { model: "obsolete" }) }); await a;
  waits[1].resolve({ ok: true, data: row("B") }); await b;
  assert.match(h.run("requestDetailReport()"), /Model: latest/);
  assert.doesNotMatch(h.run("requestDetailReport()"), /obsolete/);
  const late = h.run('selectRequestDetail("B")');
  await h.run("applyRequestFilters(true)");
  waits[3].resolve({ ok: true, data: row("B") }); await late;
  assert.equal(h.run("requestDetailReport()"), null);
  assert.equal(h.get("request-detail-id").textContent, "No selection");
});

test("failed list/detail loads are explicit and retryable; stale success is never exportable", async () => {
  let listFails = false, detailMode = "wrong";
  const h = harness(async (url) => url.includes("request-detail")
    ? detailMode === "fail" ? { ok: false, error: "raw-secret-error" } : { ok: true, data: row(detailMode === "wrong" ? "wrong" : "A") }
    : listFails ? { ok: false, error: "raw-secret-error" } : page([row("A")]));
  await h.run("loadRequestExplorer()");
  await h.run('selectRequestDetail("A")');
  assert.equal(h.run("requestDetailReport()"), null);
  assert.match(h.get("request-detail").innerHTML, /Selected request unavailable/);
  detailMode = "fail"; await h.run('selectRequestDetail("A")');
  assert.doesNotMatch(h.get("request-detail").innerHTML, /raw-secret-error/);
  detailMode = "ok"; await h.run('selectRequestDetail("A")');
  assert.match(h.run("requestDetailReport()"), /Request ID: A/);
  await h.run("ensureRequestExplorer()");
  assert.match(h.run("requestDetailReport()"), /Request ID: A/, "automatic dashboard refresh preserves selection");
  listFails = true; await h.run("loadRequestExplorer()");
  assert.equal(h.run("requestPageCsv()"), null);
  assert.equal(h.run("requestDetailReport()"), null);
  assert.equal(h.get("request-log").children.length, 0);
  assert.match(h.get("request-feedback").textContent, /Retry/);
  assert.doesNotMatch(h.get("request-feedback").textContent, /raw-secret-error/);
  listFails = false; await h.run("loadRequestExplorer()");
  assert.deepEqual(h.ids(), ["A"]);
});

test("empty and shifted last pages have honest counts and safe backward recovery", async () => {
  const h = harness(async () => page([]));
  await h.run("loadRequestExplorer()");
  assert.match(h.get("request-page-summary").textContent, /Showing 0–0 of 0/);
  assert.equal(h.get("request-export-page").disabled, true);
  h.run("requestPage = 4; probe = async () => ({ok: true, data: {data: [], page: 4, total: 2, pageSize: 12}}); safeGetJson = probe");
  await h.run("loadRequestExplorer()");
  assert.match(h.get("request-page-summary").textContent, /Showing 0–0 of 2/);
  assert.equal(h.get("request-prev").disabled, false);
  assert.equal(h.get("request-next").disabled, true);
});

test("allowlisted exports round-trip Unicode, quotes and newlines and neutralize CSV formulas", async () => {
  const special = row("special/路径", { providerName: '=SUM(1,2)\n"月"', model: "<script>bad</script>", requestModel: "  @evil", totalCostUsd: null, latencyMs: null, apiKey: "secret-key", prompt: "private-prompt", errorMessage: "raw-error", response: "private-response" });
  const h = harness(async (url) => url.includes("request-detail") ? { ok: true, data: special } : page([special]));
  await h.run("loadRequestExplorer()");
  const csv = h.run("requestPageCsv()");
  const parsed = parseCsv(csv);
  assert.equal(parsed.length, 2);
  assert.equal(parsed[0].length, parsed[1].length);
  assert.equal(parsed[1][parsed[0].indexOf("Provider")], "'" + special.providerName);
  assert.equal(parsed[1][parsed[0].indexOf("Request model")], "'" + special.requestModel);
  assert.equal(parsed[1][parsed[0].indexOf("Estimated cost USD")], "Unavailable");
  assert.equal(parsed[1][parsed[0].indexOf("Latency ms")], "Unavailable");
  for (const prefix of ["=", "+", "-", "@", "\t", "\r", "\n", "  =", "\uFEFF+", "\u0000=", " \u0001+"]) {
    h.context.cell = prefix + "payload";
    assert.match(h.run("requestCsvCell(cell)"), /^"'/);
  }
  await h.run('selectRequestDetail("special/路径")');
  const report = h.run("requestDetailReport()");
  assert.match(report, /selected retained request/);
  assert.match(report, /Estimated usage cost, not a billing statement/);
  assert.ok(report.includes(special.providerName));
  for (const value of [csv, report, h.get("request-detail").innerHTML]) {
    assert.doesNotMatch(value, /secret-key|private-prompt|raw-error|private-response/);
  }
  assert.doesNotMatch(h.get("request-detail").innerHTML, /<script>/);
  assert.match(h.get("request-detail").innerHTML, /&lt;script&gt;/);
  h.run('downloadRequestExport("page"); downloadRequestExport("detail")');
  assert.deepEqual(h.downloads.map((item) => item.download), ["moongate-retained-page-1.csv", "moongate-selected-request.txt"]);
  assert.equal(Buffer.from(await h.blobs[0].arrayBuffer()).toString("utf8"), "\uFEFF" + csv);
  assert.equal(await h.blobs[1].text(), report);
  assert.equal(h.revocations.length, 2);
  assert.match(h.run("requestMeasure(0)"), /zero or unavailable/);
});

test("request filtering does not change aggregate app/time queries", async () => {
  const h = harness();
  h.get("request-provider").value = "narrow";
  h.get("request-model").value = "narrow";
  h.get("request-status").value = "500";
  h.get("usage-app").value = "codex";
  const query = JSON.parse(h.run("JSON.stringify(usageQueryParams())"));
  assert.equal(query.appType, "codex");
  assert.equal("providerName" in query, false);
  assert.equal("model" in query, false);
  assert.equal("statusCode" in query, false);
});

test("actual dashboard events submit filters, navigate, select and download", async () => {
  const h = harness(async (url) => url.includes("request-detail") ? { ok: true, data: row("A") } : page([row("A")]));
  const dashboard = asset("moongate.js");
  h.run("showError = (error) => { throw error; }");
  h.run(dashboard.slice(dashboard.indexOf('$("request-filters")'), dashboard.indexOf('$("resilience-app")')));
  h.run(dashboard.slice(dashboard.indexOf('$("request-log")'), dashboard.indexOf('$("provider-rows")?.addEventListener')));
  let prevented = false;
  h.get("request-filters").events.submit({ preventDefault() { prevented = true; } });
  await new Promise(setImmediate);
  assert.equal(prevented, true);
  assert.deepEqual(h.ids(), ["A"]);
  h.get("request-log").events.click({ target: { closest: () => ({ dataset: { requestId: "A" } }) } });
  await new Promise(setImmediate);
  assert.match(h.run("requestDetailReport()"), /Request ID: A/);
  h.get("request-export-page").events.click();
  h.get("request-export-detail").events.click();
  assert.equal(h.downloads.length, 2);
  assert.ok(h.get("request-prev").events.click);
  assert.ok(h.get("request-next").events.click);
  await h.get("request-reset").events.click();
  assert.equal(h.run("requestSelectedDetail"), null);
});

test("native seeded routes cross into the real UI state, detail and export pipeline", { skip: !process.env.MOONGATE_REQUEST_TEST_URL }, async () => {
  const base = process.env.MOONGATE_REQUEST_TEST_URL;
  const fixture = JSON.parse(fs.readFileSync(process.env.MOONGATE_REQUEST_TEST_FIXTURE, "utf8"));
  const document = await (await fetch(base + "/ui/rabbita")).text();
  const served = {};
  for (const [, src] of document.matchAll(/<script src="([^"]+)"/g)) {
    const response = await fetch(base + src);
    assert.equal(response.status, 200, src);
    const bytes = Buffer.from(await response.arrayBuffer());
    const name = new URL(src, base).pathname.split("/").pop();
    assert.deepEqual(bytes, fs.readFileSync(path.join(root, "public/assets", name)), `served bytes: ${src}`);
    served[name] = bytes.toString("utf8");
  }
  assert.match(served["moongate-usage.js"], /function requestPageCsv/);
  assert.match(served["moongate.js"], /ensureRequestExplorer/);
  const css = await (await fetch(base + "/assets/moongate.css")).text();
  assert.equal(css, asset("moongate.css"));
  const h = harness(null, base, served);
  for (const id of ["request-app", "request-range", "request-provider", "request-model", "request-status", "request-prev", "request-next", "request-export-page", "request-export-detail"]) assert.ok(document.includes(`id="${id}"`), id);
  assert.match(document, /moongate-usage.js/);
  assert.match(document, /aggregate totals/);
  const unauthorized = await fetch(base + "/usage/logs");
  assert.equal(unauthorized.status, 401);
  const expected = (q) => fixture.rows.filter((r) => (!q.appType || r.appType === q.appType) && (!q.providerName || r.providerName.toLowerCase().includes(q.providerName.toLowerCase())) && (!q.model || r.model.toLowerCase().includes(q.model.toLowerCase())) && (!q.statusCode || r.statusCode === Number(q.statusCode)) && (q.startDate == null || r.createdAt >= q.startDate) && r.createdAt <= q.endDate).sort((a, b) => b.createdAt - a.createdAt || b.requestId.localeCompare(a.requestId));
  const checkPage = async () => {
    const snap = h.snapshot(); const wanted = expected(snap.query).slice(snap.page * 12, (snap.page + 1) * 12);
    assert.deepEqual(h.ids(), wanted.map((r) => r.requestId));
    assert.equal(snap.total, expected(snap.query).length);
    const csv = h.run("requestPageCsv()");
    if (!wanted.length) { assert.equal(csv, null); return; }
    const parsed = parseCsv(csv);
    assert.deepEqual(parsed.slice(1).map((r) => r[4]), wanted.map((r) => r.requestId));
    for (const [index, original] of wanted.entries()) {
      const cells = parsed[index + 1];
      const measure = (value) => value == null ? "Unavailable" : String(value) + (Number(value) === 0 ? " (zero or unavailable)" : "");
      assert.deepEqual(cells.slice(4), [original.requestId, new Date(original.createdAt * 1000).toISOString(), original.appType,
        original.providerId, original.providerName, original.model, "'" + original.requestModel, "Unavailable", String(original.statusCode),
        measure(original.totalCostUsd), String(original.inputTokens), String(original.outputTokens), String(original.cacheReadTokens),
        String(original.cacheCreationTokens), measure(original.latencyMs), measure(original.firstTokenMs), measure(original.durationMs),
        String(original.isStreaming), original.dataSource]);
    }
    assert.equal(h.get("request-log").children.length, wanted.length);
    for (const selected of wanted) {
      h.context.id = selected.requestId;
      await h.run("selectRequestDetail(id)");
      const detail = JSON.parse(h.run("JSON.stringify(requestSelectedDetail)"));
      assert.equal(detail.requestId, selected.requestId);
      assert.equal(detail.providerName, selected.providerName);
      assert.equal(detail.model, selected.model);
      assert.equal(detail.statusCode, selected.statusCode);
      assert.equal(detail.totalCostUsd, selected.totalCostUsd);
      const report = h.run("requestDetailReport()");
      assert.ok(report.includes(`Request ID: ${selected.requestId}`));
      assert.doesNotMatch(report, /fixture-raw-error|fixture-private-prompt/);
    }
  };
  await h.run("loadRequestExplorer()"); await checkPage();
  assert.equal(h.snapshot().total, 37);
  const all = [...h.ids()]; const frozen = h.snapshot().query;
  while (!h.get("request-next").disabled) {
    await h.run("changeRequestPage(1)"); await checkPage();
    assert.deepEqual(h.snapshot().query, frozen); all.push(...h.ids());
  }
  assert.equal(new Set(all).size, 37);
  assert.match(h.get("request-page-summary").textContent, /Showing 37–37 of 37/);
  await h.run("changeRequestPage(-1)"); await checkPage();
  h.get("request-app").value = "claude";
  h.get("request-provider").value = "ALPHA";
  h.get("request-model").value = "MOON";
  h.get("request-status").value = "200";
  h.get("request-range").value = "86400";
  await h.run("applyRequestFilters()"); await checkPage();
  assert.ok(h.snapshot().total > 0 && h.snapshot().total < 37);
  h.get("request-provider").value = "missing-provider";
  await h.run("applyRequestFilters()"); await checkPage();
  assert.equal(h.snapshot().total, 0);
  await h.run("applyRequestFilters(true)"); await checkPage();
  assert.equal(h.snapshot().total, 37);
  h.get("request-range").value = "all";
  await h.run("applyRequestFilters()"); await checkPage();
  assert.equal(h.snapshot().total, 38, "old retained row is included, future row is excluded");
  if (process.env.MOONGATE_REQUEST_EVIDENCE) {
    const directory = process.env.MOONGATE_REQUEST_EVIDENCE;
    fs.writeFileSync(path.join(directory, "displayed-page.csv"), h.run("requestPageCsv()"));
    fs.writeFileSync(path.join(directory, "selected-request.txt"), h.run("requestDetailReport()"));
    fs.writeFileSync(path.join(directory, "served-assets.json"), JSON.stringify({ assets: Object.keys(served), cssBytesMatched: true, everyScriptByteMatched: true, executedServedCoreAndExplorer: true, seededRows: 39, sevenDayRows: 37, allRetainedRowsBeforeFrozenEnd: 38 }, null, 2) + "\n");
  }
  console.log("Native API → UI → selected detail → displayed-page CSV/report parity verified for 39 seeded rows, 37 within the frozen seven-day interval.");
});

test("collection controls keep chosen details across pages and filters with exact observation provenance", async () => {
  const calls = [];
  const h = harness(async url => {
    calls.push(url);
    if (url.includes("request-detail")) return { ok: true, data: row(url.endsWith("/A") ? "A" : "B") };
    const current = Number(new URL(url, "http://fixture.invalid").searchParams.get("page"));
    return page([row(current ? "B" : "A")], current, 13);
  });
  await h.run("loadRequestExplorer()");
  assert.equal(h.run("requestCollectionUI.keep.disabled"), true);
  assert.equal(h.run("requestCollectionUI.download.disabled"), true);
  assert.equal(h.get("requests").children.length, 1);
  await h.run('selectRequestDetail("A")');
  h.run("requestCollectionUI.keep.events.click()");
  const captured = h.run("JSON.stringify(requestCollection[0])");
  await h.run("changeRequestPage(1)");
  assert.equal(h.run("requestCollection.length"), 1);
  await h.run('selectRequestDetail("B")');
  h.run("requestCollectionUI.keep.events.click()");
  h.get("request-model").value = "another filter";
  await h.run("applyRequestFilters()");
  assert.equal(h.run("requestCollection.length"), 2);
  assert.equal(h.run("JSON.stringify(requestCollection[0])"), captured);
  assert.equal(h.get("requests").children.length, 1, "controls are not duplicated by updates");
  const csv = parseCsv(h.run("requestCollectionCsv()"));
  assert.equal(csv.length, 3);
  assert.equal(csv[1][2], "1"); assert.equal(csv[2][2], "2");
  assert.equal(csv[1][4], "A"); assert.equal(csv[2][4], "B");
  assert.doesNotMatch(csv[1][3], /another filter/);
  assert.ok(Number.isFinite(Date.parse(csv[1][1])));
  assert.equal(h.run("requestCollectionUI.list.children[0].children[1].textContent").includes("Request ID: A"), true);
  const count = calls.length;
  h.run("requestCollectionUI.list.children[0].children[2].events.click()");
  assert.equal(h.run("requestCollection.length"), 1);
  assert.equal(h.run("requestCollection[0].id"), "B");
  h.run("requestCollectionUI.clear.events.click()");
  assert.equal(h.run("requestCollectionCsv()"), null);
  assert.equal(h.run("requestCollectionUI.download.disabled"), true);
  assert.equal(calls.length, count, "removal and clearing never call a gateway mutation");
});

test("collection retains original metadata on duplicate or changed observations until explicit removal", async () => {
  let model = "original";
  const h = harness(async url => url.includes("request-detail") ? { ok: true, data: row("A", { model }) } : page([row("A")]));
  await h.run("loadRequestExplorer()"); await h.run('selectRequestDetail("A")');
  assert.equal(h.run("keepRequestObservation()"), true);
  const original = h.run("requestCollectionCsv()");
  assert.equal(h.run("keepRequestObservation()"), false);
  assert.match(h.run("requestCollectionMessage"), /already kept/);
  model = "corrected";
  await h.run('selectRequestDetail("A")');
  assert.equal(h.run("keepRequestObservation()"), false);
  assert.match(h.run("requestCollectionMessage"), /different metadata/);
  assert.equal(h.run("requestCollectionCsv()"), original);
  h.run('removeRequestObservation("A")');
  assert.equal(h.run("keepRequestObservation()"), true);
  assert.match(h.run("requestCollectionCsv()"), /corrected/);
  assert.doesNotMatch(h.run("requestCollectionCsv()"), /original/);
});

test("pending, failed, mismatched and superseded details cannot enter the collection", async () => {
  const pending = deferred(); let mode = "wait";
  const h = harness(async url => url.includes("request-detail")
    ? mode === "wait" ? pending.promise : mode === "fail" ? { ok: false } : { ok: true, data: row("wrong") }
    : page([row("A")]));
  await h.run("loadRequestExplorer()");
  const old = h.run('selectRequestDetail("A")');
  assert.equal(h.run("keepRequestObservation()"), false);
  await h.run("applyRequestFilters()");
  pending.resolve({ ok: true, data: row("A") }); await old;
  assert.equal(h.run("keepRequestObservation()"), false);
  mode = "fail"; await h.run('selectRequestDetail("A")');
  assert.equal(h.run("keepRequestObservation()"), false);
  mode = "wrong"; await h.run('selectRequestDetail("A")');
  assert.equal(h.run("keepRequestObservation()"), false);
  assert.equal(h.run("requestCollection.length"), 0);
});

test("collection stores only allowlisted values and downloads formula-safe CSV bytes", async () => {
  const special = row("=A", { providerName: '=SUM(1,2)\n"月"', model: "<script>evil</script>", totalCostUsd: null, latencyMs: 0,
    prompt: "private-prompt", response: "private-response", apiKey: "secret-key", errorMessage: "raw-error" });
  const h = harness(async url => url.includes("request-detail") ? { ok: true, data: special } : page([special]));
  await h.run("loadRequestExplorer()"); await h.run('selectRequestDetail("=A")');
  h.run("keepRequestObservation()");
  const stored = h.run("JSON.stringify(requestCollection)");
  assert.doesNotMatch(stored, /private-prompt|private-response|secret-key|raw-error/);
  const csv = h.run("requestCollectionCsv()"); const parsed = parseCsv(csv);
  assert.equal(parsed[1][4], "'=A");
  assert.equal(parsed[1][parsed[0].indexOf("Provider")], "'" + special.providerName);
  assert.equal(parsed[1][parsed[0].indexOf("Estimated cost USD")], "Unavailable");
  assert.equal(parsed[1][parsed[0].indexOf("Latency ms")], "0 (zero or unavailable)");
  assert.ok(h.run("requestCollectionUI.list.children[0].children[1].textContent").includes("<script>evil</script>"));
  assert.equal(h.run("requestCollectionUI.list.children[0].children[1].innerHTML"), "");
  h.run("requestCollectionUI.download.events.click()");
  assert.equal(h.downloads[0].download, "moongate-selected-request-observations.csv");
  assert.deepEqual(Buffer.from(await h.blobs[0].arrayBuffer()), Buffer.from("\uFEFF" + csv));
  assert.deepEqual(h.revocations, ["blob:fixture"]);
  assert.equal(harness().run("requestCollection.length"), 0, "new document starts empty with no persistence");
});

test("collection remains inspectable/exportable after a subsequent list failure", async () => {
  let fail = false;
  const h = harness(async url => fail ? { ok: false } : url.includes("request-detail") ? { ok: true, data: row("A") } : page([row("A")]));
  await h.run("loadRequestExplorer()"); await h.run('selectRequestDetail("A")'); h.run("keepRequestObservation()");
  const csv = h.run("requestCollectionCsv()"); fail = true;
  await h.run("loadRequestExplorer()");
  assert.equal(h.run("requestPageCsv()"), null);
  assert.equal(h.run("requestCollectionCsv()"), csv);
  assert.equal(h.run("requestCollectionUI.keep.disabled"), true);
  assert.equal(h.run("requestCollectionUI.download.disabled"), false);
});

test("collection bounds refuse additional entries without losing earlier observations", async () => {
  let id = "A", model = "normal";
  const h = harness(async url => url.includes("request-detail") ? { ok: true, data: row(id, { model }) } : page([row(id)]));
  for (let i = 0; i < 101; i++) {
    id = "A" + i;
    await h.run("loadRequestExplorer()"); h.context.selected = id;
    await h.run("selectRequestDetail(selected)");
    assert.equal(h.run("keepRequestObservation()"), i < 100);
  }
  assert.equal(h.run("requestCollection.length"), 100);
  assert.match(h.run("requestCollectionMessage"), /limit reached/);
  h.run("clearRequestCollection()");
  model = "large".repeat(500000);
  await h.run('selectRequestDetail("A100")');
  assert.equal(h.run("keepRequestObservation()"), false);
  assert.equal(h.run("requestCollection.length"), 0);
});

function chooseComparison(h, baseline, candidate) {
  h.context.baselineId = baseline; h.context.candidateId = candidate;
  h.run('requestComparisonUI.baseline.value = baselineId; requestComparisonUI.baseline.events.change()');
  h.run('requestComparisonUI.candidate.value = candidateId; requestComparisonUI.candidate.events.change()');
}
function comparisonRows(h) {
  return JSON.parse(h.run('JSON.stringify(requestComparisonUI.body.children.map(row => row.children.map(cell => cell.textContent)))'));
}

// The product journey: keep a failing request, navigate to a successful reference,
// then compare via the controls without issuing more requests or changing policy.
test("comparison controls diagnose a failed request against a kept successful reference across pages", async () => {
  const calls = [];
  const failed = row("failed-1", { statusCode: 503, model: "moon-large", requestModel: "moon", inputTokens: 100, outputTokens: 0, totalCostUsd: null, latencyMs: 900 });
  const recovered = row("success-2", { statusCode: 200, model: "moon-small", requestModel: "moon", inputTokens: 140, outputTokens: 20, totalCostUsd: "0.002", latencyMs: 300 });
  const h = harness(async url => {
    calls.push(url);
    if (url.includes("request-detail")) return { ok: true, data: url.endsWith("failed-1") ? failed : recovered };
    const p = Number(new URL(url, "http://fixture.invalid").searchParams.get("page"));
    return page([p === 0 ? failed : recovered], p, 13);
  });
  await h.run("loadRequestExplorer()");
  assert.equal(h.run("requestComparisonUI.baseline.disabled"), true);
  await h.run('selectRequestDetail("failed-1")'); h.run("requestCollectionUI.keep.events.click()");
  await h.run("changeRequestPage(1)");
  await h.run('selectRequestDetail("success-2")'); h.run("requestCollectionUI.keep.events.click()");
  assert.equal(h.run("requestComparisonUI.body.children.length"), 0, "two observations do not select a pair automatically");
  const originalCollection = h.run("JSON.stringify(requestCollection)");
  const requestCount = calls.length;
  chooseComparison(h, "failed-1", "success-2");
  const rows = comparisonRows(h);
  assert.deepEqual(rows.find(row => row[0] === "HTTP status"), ["HTTP status", "503", "200", "Different displayed value", "Not a numeric measure"]);
  assert.deepEqual(rows.find(row => row[0] === "Model").slice(0, 4), ["Model", "moon-large", "moon-small", "Different displayed value"]);
  assert.equal(rows.find(row => row[0] === "Latency ms")[4], "-600 ms (approx.)");
  assert.equal(rows.find(row => row[0] === "Input tokens")[4], "+40 tokens");
  assert.equal(rows.find(row => row[0] === "Output tokens")[4], "+20 tokens");
  assert.equal(rows.find(row => row[0] === "Estimated cost USD")[4], "Unavailable");
  assert.equal(rows.find(row => row[0] === "Request model"), undefined, "matching fields hidden initially");
  const context = h.run("requestComparisonUI.context.textContent");
  assert.match(context, /Baseline: failed-1\nObserved UTC: .+\nSource page: 1/);
  assert.match(context, /Candidate: success-2\nObserved UTC: .+\nSource page: 2/);
  assert.match(context, /App: all; provider name contains: any/);
  assert.match(h.run("requestComparisonUI.status.textContent"), /kept observations, not a live refresh/);
  h.run("requestComparisonUI.swap.events.click()");
  assert.equal(comparisonRows(h).find(row => row[0] === "Latency ms")[4], "+600 ms (approx.)");
  assert.equal(comparisonRows(h).find(row => row[0] === "Input tokens")[4], "-40 tokens");
  h.run("requestComparisonUI.differences.checked = false; requestComparisonUI.differences.events.change()");
  assert.equal(comparisonRows(h).length, 19);
  assert.equal(comparisonRows(h).find(row => row[0] === "Request model")[3], "Same displayed value");
  assert.equal(calls.length, requestCount, "all comparison actions are local reads");
  assert.equal(h.run("JSON.stringify(requestCollection)"), originalCollection);
  h.get("request-status").value = "503"; await h.run("applyRequestFilters()");
  assert.match(h.run("requestComparisonUI.context.textContent"), /Baseline: success-2/);
  assert.equal(h.run("requestComparisonUI.baseline.value"), "success-2");
  assert.equal(h.run("requestComparisonUI.candidate.value"), "failed-1");
  assert.equal(h.run("requestCollectionUI.section.children.filter(node => node.id === 'request-comparison').length"), 1);
});

test("comparison keeps missing and ambiguous measurements unknown while showing recorded estimate arithmetic", async () => {
  const a = row("A", { totalCostUsd: "0.001", latencyMs: 0, firstTokenMs: null, durationMs: 100,
    inputTokens: null, outputTokens: 0, cacheReadTokens: -1, cacheCreationTokens: "unsafe" });
  const b = row("B", { totalCostUsd: "0.003", latencyMs: 1, firstTokenMs: 0, durationMs: 150,
    inputTokens: 100, outputTokens: 0, cacheReadTokens: 2, cacheCreationTokens: "unsafe" });
  const h = harness(async url => url.includes("request-detail") ? { ok: true, data: url.endsWith("/A") ? a : b } : page([a, b]));
  await h.run("loadRequestExplorer()");
  for (const id of ["A", "B"]) { await h.run(`selectRequestDetail("${id}")`); h.run("keepRequestObservation()"); }
  chooseComparison(h, "A", "B");
  let rows = comparisonRows(h);
  for (const label of ["Input tokens", "Latency ms", "First token ms", "Cache read tokens", "Cache write tokens"]) {
    assert.equal(rows.find(row => row[0] === label)[3], "Not comparable");
    assert.equal(rows.find(row => row[0] === label)[4], "Unavailable");
  }
  assert.equal(rows.find(row => row[0] === "Estimated cost USD")[4], "+0.002 USD estimated (approx.)");
  assert.equal(rows.find(row => row[0] === "Duration ms")[4], "+50 ms (approx.)");
  assert.equal(rows.find(row => row[0] === "Output tokens"), undefined);
  h.run("requestComparisonUI.differences.checked = false; requestComparisonUI.differences.events.change()");
  assert.equal(comparisonRows(h).find(row => row[0] === "Output tokens")[4], "0 tokens");
  // Existing retained-API sentinel semantics must survive comparison, including 0 vs 0.
  h.context.zeros = { ...b, totalCostUsd: 0, durationMs: 0 };
  h.run('removeRequestObservation("B"); requestSelectedDetail = zeros; keepRequestObservation()');
  chooseComparison(h, "A", "B"); rows = comparisonRows(h);
  assert.equal(rows.find(row => row[0] === "Estimated cost USD")[4], "Unavailable");
  assert.equal(rows.find(row => row[0] === "Duration ms")[4], "Unavailable");
});

test("comparison removal, same-ID choice, clear and recapture never substitute another observation", async () => {
  const h = harness(async url => url.includes("request-detail") ? { ok: true, data: row(url.slice(-1)) } : page([row("A"), row("B"), row("C")]));
  await h.run("loadRequestExplorer()");
  for (const id of ["A", "B", "C"]) { await h.run(`selectRequestDetail("${id}")`); h.run("keepRequestObservation()"); }
  chooseComparison(h, "A", "A");
  assert.equal(comparisonRows(h).length, 0); assert.equal(h.run("requestComparisonUI.swap.disabled"), true);
  assert.match(h.run("requestComparisonUI.status.textContent"), /two different kept request IDs/);
  chooseComparison(h, "A", "B"); h.run('removeRequestObservation("A")');
  assert.equal(h.run("requestComparisonUI.baseline.value"), "");
  assert.equal(h.run("requestComparisonUI.candidate.value"), "B");
  assert.equal(comparisonRows(h).length, 0); assert.equal(h.run("requestComparisonUI.context.textContent"), "");
  await h.run('selectRequestDetail("A")'); h.run("keepRequestObservation()");
  assert.equal(h.run("requestComparisonUI.baseline.value"), "", "recapturing a removed ID needs explicit selection");
  chooseComparison(h, "A", "B"); h.run("requestComparisonUI.clear.events.click()");
  assert.equal(h.run("requestCollection.length"), 3); assert.equal(comparisonRows(h).length, 0);
  chooseComparison(h, "A", "B"); h.run("clearRequestCollection()");
  assert.equal(h.run("requestComparisonUI.baseline.disabled"), true); assert.equal(comparisonRows(h).length, 0);
  assert.equal(h.run("requestComparisonBaseline + requestComparisonCandidate"), "");
});

test("comparison preserves chosen observation values through changed details and an interrupted refresh", async () => {
  let latency = 300, fail = false;
  const wait = deferred();
  const h = harness(async url => url.includes("request-detail")
    ? { ok: true, data: row(url.slice(-1), { latencyMs: url.endsWith("/A") ? 100 : latency }) }
    : fail ? wait.promise : page([row("A"), row("B")]));
  await h.run("loadRequestExplorer()");
  for (const id of ["A", "B"]) { await h.run(`selectRequestDetail("${id}")`); h.run("keepRequestObservation()"); }
  chooseComparison(h, "A", "B");
  const original = comparisonRows(h);
  latency = 500; await h.run('selectRequestDetail("B")'); h.run("keepRequestObservation()");
  assert.deepEqual(comparisonRows(h), original);
  assert.match(h.run("requestCollectionMessage"), /different metadata/);
  fail = true; const reload = h.run("loadRequestExplorer()");
  assert.deepEqual(comparisonRows(h), original);
  assert.equal(h.run("requestCollectionUI.keep.disabled"), true);
  wait.resolve({ ok: false, error: "private-error" }); await reload;
  assert.deepEqual(comparisonRows(h), original);
  assert.match(h.run("requestComparisonUI.status.textContent"), /kept observations, not a live refresh/);
});

test("comparison uses literal allowlisted metadata without rendering payloads or interpreting labels", async () => {
  const name = '<script>月 & "quoted"</script>\n=SUM(A1)';
  const a = row("=A", { providerName: name, requestModel: name, prompt: "private-prompt", response: "private-response", apiKey: "secret-key", errorMessage: "raw-error" });
  const b = row("B", { providerName: "different", inputTokens: "Infinity", outputTokens: 9007199254740992 });
  const h = harness(async url => url.includes("request-detail") ? { ok: true, data: url.endsWith("/B") ? b : a } : page([a, b]));
  await h.run("loadRequestExplorer()");
  for (const id of ["=A", "B"]) { h.context.chosen = id; await h.run("selectRequestDetail(chosen)"); h.run("keepRequestObservation()"); }
  chooseComparison(h, "=A", "B");
  assert.equal(comparisonRows(h).find(row => row[0] === "Provider")[1], name);
  assert.equal(h.run("requestComparisonUI.body.children.every(row => row.children.every(cell => cell.innerHTML === ''))"), true);
  assert.equal(h.run("requestComparisonUI.baseline.children[1].textContent.startsWith('=A')"), true);
  assert.doesNotMatch(JSON.stringify(comparisonRows(h)) + h.run("requestComparisonUI.context.textContent"), /private-prompt|private-response|secret-key|raw-error/);
  assert.equal(comparisonRows(h).find(row => row[0] === "Input tokens")[4], "Unavailable");
  assert.equal(comparisonRows(h).find(row => row[0] === "Output tokens")[4], "Unavailable");
  assert.equal(h.run('requestComparisonNumber("9007199254740990.5", "count")'), null, "rounded fractional counters cannot become whole-token deltas");
  assert.equal(h.run('requestComparisonNumber("1e3", "count")'), null, "noncanonical counters remain visible but receive no arithmetic");
  assert.equal(h.downloads.length, 0, "comparison does not create another export workflow");
});

async function keptReviewHarness(records = [row("A"), row("B", { inputTokens: 140 })]) {
  const h = harness(async url => url.includes("request-detail")
    ? { ok: true, data: records.find(record => url.endsWith("/" + encodeURIComponent(record.requestId))) }
    : page(records));
  await h.run("loadRequestExplorer()");
  for (const record of records) {
    h.context.chosen = record.requestId;
    await h.run("selectRequestDetail(chosen)"); h.run("requestCollectionUI.keep.events.click()");
  }
  return h;
}
async function chooseReviewFile(h, file) {
  h.context.reviewFile = file;
  return h.run('requestCollectionUI.picker.events.change({target: {files: [reviewFile], value: "chosen.json"}})');
}

// This uses the saved download bytes in a new dashboard context, as after a
// reload. The file picker and explicit open are the actual product handlers.
test("saved review download reopens in a new dashboard with exact comparison and redacted capture context", async () => {
  const a = row("failed/路径", { statusCode: 503, providerName: '<script>月</script>\n=SUM(A1)',
    latencyMs: 0, totalCostUsd: null, apiKey: "secret-key", prompt: "private-prompt", response: "private-response", errorMessage: "private-error" });
  const b = row("success", { inputTokens: 140, latencyMs: 200, totalCostUsd: "0.003" });
  const source = harness(async url => url.includes("request-detail")
    ? { ok: true, data: url.endsWith("/success") ? b : a }
    : page([Number(new URL(url, "http://fixture.invalid").searchParams.get("page")) ? b : a],
      Number(new URL(url, "http://fixture.invalid").searchParams.get("page")), 13));
  source.get("request-provider").value = '月 "review"';
  await source.run("loadRequestExplorer()");
  await source.run('selectRequestDetail("failed/路径")'); source.run("requestCollectionUI.keep.events.click()");
  await source.run("changeRequestPage(1)");
  await source.run('selectRequestDetail("success")'); source.run("requestCollectionUI.keep.events.click()");
  chooseComparison(source, "failed/路径", "success");
  source.run("requestComparisonUI.differences.checked = false; requestComparisonUI.differences.events.change()");
  const originalRows = comparisonRows(source);
  const originalCollection = JSON.parse(source.run("JSON.stringify(requestCollection)"));
  source.run("requestCollectionUI.saveReview.events.click()");
  assert.equal(source.downloads[0].download, "moongate-request-review.json");
  const bytes = await source.blobs[0].arrayBuffer();
  const savedText = Buffer.from(bytes).toString("utf8");
  assert.doesNotMatch(savedText, /secret-key|private-prompt|private-response|private-error/);
  assert.equal(JSON.parse(savedText).schema, "moongate.request-review.v1");
  let calls = 0;
  const reopened = harness(async () => { calls++; return { ok: false }; });
  reopened.run("renderRequestCollection()");
  await chooseReviewFile(reopened, new Blob([bytes]));
  assert.equal(reopened.run("requestCollection.length"), 0, "choosing a file only stages it");
  assert.match(reopened.run("requestCollectionUI.reviewStatus.textContent"), /2 observations ready.*unverified/);
  assert.equal(reopened.run("requestCollectionUI.openReview.disabled"), false);
  reopened.run("requestCollectionUI.openReview.events.click()");
  assert.deepEqual(comparisonRows(reopened), originalRows);
  assert.equal(reopened.run("requestComparisonUI.differences.checked"), false);
  assert.deepEqual(JSON.parse(reopened.run("JSON.stringify(requestCollection.map(({fromReviewFile, ...entry}) => entry))")), originalCollection);
  assert.equal(reopened.run("requestReviewJson()"), savedText);
  assert.match(reopened.run("requestComparisonUI.context.textContent"), /Source page: 1/);
  assert.match(reopened.run("requestComparisonUI.context.textContent"), /Source page: 2/);
  assert.match(reopened.run("requestComparisonUI.context.textContent"), /Local review file \(unverified; not refreshed\)/);
  assert.equal(reopened.run("requestCollectionUI.list.children[0].children[1].innerHTML"), "");
  assert.equal(reopened.run("requestCollectionUI.list.children[0].children[1].textContent").includes(a.providerName), true);
  assert.equal(calls, 0, "file selection/open/comparison do not call the gateway");
  assert.equal(reopened.run("requestSelectedDetail"), null);
  assert.equal(reopened.run("requestPageSnapshot"), null);
  assert.equal(reopened.run("requestDetailReport()"), null);
  reopened.run("requestComparisonUI.swap.events.click()");
  assert.equal(comparisonRows(reopened).find(row => row[0] === "Input tokens")[4], "-40 tokens");
  await reopened.run("loadRequestExplorer()");
  assert.equal(reopened.run("requestCollection.length"), 2, "ordinary gateway failure does not replace reopened evidence");
});

test("choosing and canceling a saved review preserve the current collection until explicit replace", async () => {
  const h = await keptReviewHarness(); chooseComparison(h, "A", "B");
  const source = await keptReviewHarness([row("saved-only")]);
  const original = h.run("requestReviewJson()"), selected = h.run("JSON.stringify(requestSelectedDetail)");
  const originalPage = h.run("JSON.stringify(requestPageSnapshot)");
  await chooseReviewFile(h, new Blob([source.run("requestReviewJson()") ]));
  assert.equal(h.run("requestReviewJson()"), original);
  h.run("requestCollectionUI.cancelReview.events.click()");
  assert.equal(h.run("requestCollectionUI.openReview.disabled"), true);
  h.run("requestCollectionUI.openReview.events.click()");
  assert.equal(h.run("requestReviewJson()"), original);
  await chooseReviewFile(h, new Blob([source.run("requestReviewJson()") ]));
  h.run("requestCollectionUI.openReview.events.click()");
  assert.equal(h.run("requestCollection.length"), 1);
  assert.equal(h.run("requestCollection[0].id"), "saved-only");
  assert.equal(h.run("requestComparisonBaseline + requestComparisonCandidate"), "");
  assert.equal(h.run("JSON.stringify(requestSelectedDetail)"), selected);
  assert.equal(h.run("JSON.stringify(requestPageSnapshot)"), originalPage);
  assert.equal(h.run("requestCollectionUI.openReview.disabled"), true);
});

test("a resumed investigation can remove observations, add a fresh detail and save again without silently updating duplicates", async () => {
  const source = await keptReviewHarness(); chooseComparison(source, "A", "B");
  const h = await keptReviewHarness([row("A", { inputTokens: 500 })]);
  await chooseReviewFile(h, new Blob([source.run("requestReviewJson()") ]));
  h.run("requestCollectionUI.openReview.events.click()");
  const saved = h.run("requestReviewJson()");
  assert.equal(h.run("keepRequestObservation()"), false);
  assert.match(h.run("requestCollectionMessage"), /different metadata/);
  assert.equal(h.run("requestReviewJson()"), saved);
  h.run("requestCollectionUI.list.children[0].children[2].events.click()");
  assert.equal(h.run("requestComparisonBaseline"), "");
  h.run("requestCollectionUI.keep.events.click()");
  assert.equal(h.run("requestCollection.length"), 2);
  assert.equal(h.run("requestCollection[1].fields.find(([name]) => name === 'Input tokens')[1]"), "500");
  assert.match(h.run("requestCollectionUI.list.children[0].children[1].textContent"), /Local review file/);
  assert.match(h.run("requestCollectionUI.list.children[1].children[1].textContent"), /Retained detail read in this tab/);
  chooseComparison(h, "A", "B");
  assert.equal(comparisonRows(h).find(row => row[0] === "Input tokens")[4], "-360 tokens");
  const csv = parseCsv(h.run("requestCollectionCsv()"));
  assert.match(csv[1][0], /unverified local review file/);
  assert.doesNotMatch(csv[2][0], /unverified local review file/);
  h.run("requestCollectionUI.saveReview.events.click()");
  const resumed = harness(); resumed.run("renderRequestCollection()");
  await chooseReviewFile(resumed, h.blobs[0]); resumed.run("requestCollectionUI.openReview.events.click()");
  assert.deepEqual(comparisonRows(resumed), comparisonRows(h));
  assert.equal(resumed.run("requestCollection.every(entry => entry.fromReviewFile)"), true);
});

test("unreadable or unsupported review files never discard an active investigation or reveal raw parse errors", async () => {
  const h = await keptReviewHarness(); chooseComparison(h, "A", "B");
  const original = h.run("requestReviewJson()");
  await chooseReviewFile(h, new Blob([original]));
  assert.equal(h.run("requestCollectionUI.openReview.disabled"), false);
  await chooseReviewFile(h, new Blob(['{"apiKey":"private-invalid-file" broken json}']));
  assert.equal(h.run("requestCollectionUI.openReview.disabled"), true);
  assert.match(h.run("requestReviewMessage"), /Could not read JSON/);
  assert.doesNotMatch(h.run("requestReviewMessage"), /private-invalid-file/);
  const foreign = JSON.parse(original); foreign.observations[0].fields.push(["Raw response", "private-response"]);
  await chooseReviewFile(h, new Blob([JSON.stringify(foreign)]));
  assert.match(h.run("requestReviewMessage"), /Invalid observation metadata/);
  assert.equal(h.run("requestReviewJson()"), original);
  await chooseReviewFile(h, { size: 10, text: async () => { throw new Error("private-local-path"); } });
  assert.match(h.run("requestReviewMessage"), /Could not read the local file/);
  assert.doesNotMatch(h.run("requestReviewMessage"), /private-local-path/);
  let read = false;
  await chooseReviewFile(h, { size: 3 * 1024 * 1024 + 1, text: async () => { read = true; return original; } });
  assert.equal(read, false);
  assert.match(h.run("requestReviewMessage"), /no larger than 3 MiB/);
  assert.equal(h.run("requestReviewJson()"), original);
});

test("a newer file choice or cancel supersedes pending file reads without replacing the current review", async () => {
  const h = await keptReviewHarness(); chooseComparison(h, "A", "B");
  const original = h.run("requestReviewJson()");
  const one = await keptReviewHarness([row("one")]), two = await keptReviewHarness([row("two")]);
  const late = deferred();
  const first = chooseReviewFile(h, { size: 100, text: () => late.promise });
  await chooseReviewFile(h, new Blob([two.run("requestReviewJson()") ]));
  late.resolve(one.run("requestReviewJson()")); await first;
  assert.equal(h.run("requestReviewPending.observations[0].id"), "two");
  assert.equal(h.run("requestReviewJson()"), original);
  const abandoned = deferred();
  const third = chooseReviewFile(h, { size: 100, text: () => abandoned.promise });
  h.run("requestCollectionUI.cancelReview.events.click()");
  abandoned.resolve(one.run("requestReviewJson()")); await third;
  assert.equal(h.run("requestReviewPending"), null);
  assert.match(h.run("requestReviewMessage"), /canceled/);
  assert.equal(h.run("requestReviewJson()"), original);
  await chooseReviewFile(h, new Blob([two.run("requestReviewJson()") ]));
  h.run("requestCollectionUI.openReview.events.click()");
  assert.equal(h.run("requestCollection[0].id"), "two");
});

function writeInvestigation(h, summary, notes = {}) {
  h.context.summaryText = summary;
  h.run('requestAnnotationUI.summary.value = summaryText; requestAnnotationUI.summary.events.input()');
  for (const [id, text] of Object.entries(notes)) {
    h.context.noteId = id; h.context.noteText = text;
    h.run('requestAnnotationUI.selected.value = noteId; requestAnnotationUI.selected.events.change(); requestAnnotationUI.note.value = noteText; requestAnnotationUI.note.events.input()');
  }
}

test("operator investigation notes survive actual save/reopen and produce an explicitly unverified incident report", async () => {
  const h = await keptReviewHarness([
    row("failed/東京", { statusCode: 503, latencyMs: 0, totalCostUsd: null, prompt: "secret-prompt", response: "secret-response", errorMessage: "private-error", apiKey: "private-key" }),
    row("reference", { statusCode: 200, inputTokens: 140, latencyMs: 85 }),
  ]);
  chooseComparison(h, "failed/東京", "reference");
  const originalFields = h.run('JSON.stringify(requestCollection.map(entry => entry.fields))');
  writeInvestigation(h, "Investigating intermittent errors; cause not established.", {
    "failed/東京": "Observed after the rollout.\nNeed operator review; no causal conclusion.",
    reference: "A successful reference with different token count.",
  });
  h.run('requestCollectionUI.saveReview.events.click()');
  const bytes = await h.blobs[0].text();
  const saved = JSON.parse(bytes);
  assert.equal(saved.schema, 'moongate.request-review.v2');
  assert.equal(saved.annotations.notes.length, 2);
  assert.doesNotMatch(bytes, /secret-prompt|secret-response|private-error|private-key/);
  let calls = 0;
  const reopened = harness(async () => { calls++; return { ok: false }; });
  reopened.run('renderRequestCollection()');
  await chooseReviewFile(reopened, h.blobs[0]);
  assert.equal(reopened.run('requestAnnotationSummary'), '', 'choosing does not import notes');
  reopened.run('requestCollectionUI.openReview.events.click()');
  assert.equal(reopened.run('requestReviewJson()'), bytes);
  assert.equal(reopened.run('JSON.stringify(requestCollection.map(entry => entry.fields))'), originalFields);
  assert.equal(reopened.run('requestAnnotationUI.summary.value'), saved.annotations.summary);
  reopened.context.noteId = 'failed/東京';
  reopened.run('requestAnnotationUI.selected.value = noteId; requestAnnotationUI.selected.events.change()');
  assert.match(reopened.run('requestAnnotationUI.note.value'), /Need operator review/);
  reopened.run('requestAnnotationUI.download.events.click()');
  assert.equal(reopened.downloads[0].download, 'moongate-request-investigation.txt');
  const report = await reopened.blobs[0].text();
  assert.match(report, /Operator annotations below are unverified interpretations, not gateway facts, approval, or incident closure/);
  assert.match(report, /Local review file \(unverified; not refreshed\)/);
  assert.match(report, /Operator-authored note for this request \(unverified\):\n  \| Observed after the rollout\.\n  \| Need operator review/);
  assert.match(report, /Comparison of kept observations \(candidate minus baseline; no causal conclusion\)/);
  assert.match(report, /\+40 tokens/);
  assert.match(report, /Latency ms:\n  \| Baseline: 0 \(zero or unavailable\)\n  \| Candidate: 85\n  \| Not comparable\n  \| Unavailable/);
  assert.doesNotMatch(report, /secret-prompt|secret-response|private-error|private-key/);
  if (process.env.MOONGATE_ANNOTATION_EVIDENCE) {
    const out = process.env.MOONGATE_ANNOTATION_EVIDENCE;
    fs.mkdirSync(out, { recursive: true });
    fs.writeFileSync(path.join(out, 'saved-review.json'), bytes);
    fs.writeFileSync(path.join(out, 'reopened-investigation.txt'), report);
    fs.writeFileSync(path.join(out, 'comparison.json'), JSON.stringify(comparisonRows(reopened), null, 2) + '\n');
  }
  assert.equal(calls, 0, 'notes, reopen and reporting never contact gateway or provider');
  assert.equal(reopened.run('requestSelectedDetail'), null);
});

test("per-request notes stay bound to kept IDs across filter changes, failed refresh and selector switching", async () => {
  let fail = false;
  const h = harness(async url => fail ? { ok: false, error: 'offline' } : url.includes('request-detail') ? { ok: true, data: row(url.slice(-1)) } : page([row('A'), row('B')]));
  await h.run('loadRequestExplorer()');
  for (const id of ['A', 'B']) { await h.run(`selectRequestDetail('${id}')`); h.run('keepRequestObservation()'); }
  writeInvestigation(h, 'Window under investigation', { A: 'First request', B: 'Second request' });
  const saved = h.run('requestReviewJson()');
  fail = true; h.get('request-status').value = '503'; await h.run('applyRequestFilters()');
  assert.equal(h.run('requestReviewJson()'), saved);
  h.run("requestAnnotationUI.selected.value = 'A'; requestAnnotationUI.selected.events.change()");
  assert.equal(h.run('requestAnnotationUI.note.value'), 'First request');
  h.run("requestAnnotationUI.note.value = 'Revised first request'; requestAnnotationUI.note.events.input()");
  h.run("requestAnnotationUI.selected.value = 'B'; requestAnnotationUI.selected.events.change()");
  assert.equal(h.run('requestAnnotationUI.note.value'), 'Second request');
  assert.equal(h.run('requestAnnotationUI.download.disabled'), false);
  assert.equal(h.run('requestCollectionUI.keep.disabled'), true);
  assert.match(h.run('requestInvestigationReport()'), /Revised first request/);
});

test("legacy review import replaces annotations only when explicitly opened, while cancel preserves them", async () => {
  const current = await keptReviewHarness();
  writeInvestigation(current, 'Keep this analysis until replacement is explicit', { A: 'Current note' });
  const before = current.run('requestReviewJson()');
  const legacy = await keptReviewHarness([row('legacy')]);
  const v1 = legacy.run('requestReviewJson()');
  assert.equal(JSON.parse(v1).schema, 'moongate.request-review.v1');
  await chooseReviewFile(current, new Blob([v1]));
  assert.match(current.run('requestReviewMessage'), /operator notes; cancel keeps them/);
  current.run('requestCollectionUI.cancelReview.events.click()');
  assert.equal(current.run('requestReviewJson()'), before);
  await chooseReviewFile(current, new Blob([v1]));
  current.run('requestCollectionUI.openReview.events.click()');
  assert.equal(current.run('requestReviewJson()'), v1);
  assert.equal(current.run('requestAnnotationUI.summary.value'), '');
  assert.equal(current.run('requestAnnotationNotes.size'), 0);
  assert.equal(current.run('requestAnnotationUI.note.disabled'), true);
});

test("removal and recapture do not attach an old annotation to a newly observed request", async () => {
  const h = await keptReviewHarness();
  writeInvestigation(h, 'Investigation context', { A: 'Old observation only', B: 'Retain this one' });
  h.run("removeRequestObservation('A')");
  assert.equal(h.run("requestAnnotationNotes.has('A')"), false);
  assert.doesNotMatch(h.run('requestInvestigationReport()'), /Old observation only/);
  await h.run("selectRequestDetail('A')"); h.run('keepRequestObservation()');
  h.run("requestAnnotationUI.selected.value = 'A'; requestAnnotationUI.selected.events.change()");
  assert.equal(h.run('requestAnnotationUI.note.value'), '');
  assert.equal(h.run('requestAnnotationSummary'), 'Investigation context');
  assert.equal(h.run("requestAnnotationNotes.get('B')"), 'Retain this one');
  h.run('requestCollectionUI.clear.events.click()');
  assert.equal(h.run('requestAnnotationSummary'), '');
  assert.equal(h.run('requestAnnotationNotes.size'), 0);
  assert.equal(h.run('requestAnnotationUI.download.disabled'), true);
  assert.equal(h.run('requestInvestigationReport()'), null);
});

test("literal operator text can be edited after reopening and saved again without changing original download bytes", async () => {
  const h = await keptReviewHarness();
  const literal = '<script>operator text, not markup</script>\n=SUM(A1)\n東京 😀';
  writeInvestigation(h, literal, { A: literal });
  h.run('requestCollectionUI.saveReview.events.click()');
  const original = await h.blobs[0].text();
  const resumed = harness(); resumed.run('renderRequestCollection()');
  await chooseReviewFile(resumed, h.blobs[0]); resumed.run('requestCollectionUI.openReview.events.click()');
  assert.equal(resumed.run('requestAnnotationUI.summary.value'), literal);
  assert.equal(resumed.run('requestAnnotationUI.summary.innerHTML'), '');
  writeInvestigation(resumed, 'Updated interpretation', { A: '', B: 'Follow up with route owner' });
  assert.equal(resumed.run("requestAnnotationNotes.has('A')"), false);
  resumed.run('requestCollectionUI.saveReview.events.click()');
  assert.equal(await h.blobs[0].text(), original);
  const again = harness(); again.run('renderRequestCollection()');
  await chooseReviewFile(again, resumed.blobs[0]); again.run('requestCollectionUI.openReview.events.click()');
  assert.equal(again.run('requestAnnotationSummary'), 'Updated interpretation');
  assert.equal(again.run("requestAnnotationNotes.get('B')"), 'Follow up with route owner');
  assert.doesNotMatch(again.run('requestCollectionCsv()'), /Follow up with route owner/, 'metadata CSV remains metadata-only');
});

test("annotation size errors retain previous text and recover; orphan note files do not replace active work", async () => {
  const h = await keptReviewHarness();
  writeInvestigation(h, 'Saved summary', { A: 'Saved note' });
  const original = h.run('requestReviewJson()');
  h.context.tooLong = 'a'.repeat(4001);
  h.run('requestAnnotationUI.note.value = tooLong; requestAnnotationUI.note.events.input()');
  assert.match(h.run('requestAnnotationUI.status.textContent'), /edit was not kept/);
  assert.equal(h.run('requestAnnotationUI.note.value'), 'Saved note');
  assert.equal(h.run('requestReviewJson()'), original);
  const wrong = JSON.parse(original); wrong.annotations.notes[0].requestId = 'not-kept';
  await chooseReviewFile(h, new Blob([JSON.stringify(wrong)]));
  assert.match(h.run('requestReviewMessage'), /Invalid operator annotations/);
  assert.equal(h.run('requestCollectionUI.openReview.disabled'), true);
  assert.equal(h.run('requestReviewJson()'), original);
  writeInvestigation(h, 'Saved summary', { A: 'Within limit' });
  assert.equal(h.run("requestAnnotationNotes.get('A')"), 'Within limit');
});


test("clear collection and notes remains usable for a summary with no kept observations", async () => {
  const empty = harness(); empty.run('renderRequestCollection()');
  assert.equal(empty.run('requestCollectionUI.clear.disabled'), true);
  writeInvestigation(empty, 'Draft before selecting any requests');
  assert.equal(empty.run('requestCollectionUI.clear.disabled'), false);
  assert.equal(empty.run('requestCollectionUI.saveReview.disabled'), true);
  empty.run('requestCollectionUI.clear.events.click()');
  assert.equal(empty.run('requestAnnotationUI.summary.value'), '');
  assert.equal(empty.run('requestAnnotationSummary'), '');
  assert.equal(empty.run('requestCollectionUI.clear.disabled'), true);

  const kept = await keptReviewHarness([row('only-request')]);
  writeInvestigation(kept, 'Context survives removing the final observation', { 'only-request': 'Request-specific note' });
  kept.run("removeRequestObservation('only-request')");
  assert.equal(kept.run('requestCollection.length'), 0);
  assert.equal(kept.run('requestAnnotationNotes.size'), 0);
  assert.equal(kept.run('requestCollectionUI.clear.disabled'), false);
  assert.equal(kept.run('requestAnnotationUI.summary.value'), 'Context survives removing the final observation');
  kept.run('requestCollectionUI.clear.events.click()');
  assert.equal(kept.run('requestAnnotationUI.summary.value'), '');
  assert.equal(kept.run('requestCollectionUI.clear.disabled'), true);
  writeInvestigation(kept, 'Another draft');
  assert.equal(kept.run('requestCollectionUI.clear.disabled'), false);
  writeInvestigation(kept, '');
  assert.equal(kept.run('requestCollectionUI.clear.disabled'), true, 'manual erasure updates clear immediately');
});

function confirmReviewMerge(h) {
  h.run('requestCollectionUI.mergeConfirm.checked = true; requestCollectionUI.mergeConfirm.events.change()');
}

test("merge combines saved investigations through dashboard controls and saves a resumable annotated result", async () => {
  const left = await keptReviewHarness([row('shared'), row('failed', { statusCode: 503, latencyMs: 0 })]);
  const right = await keptReviewHarness([row('shared'), row('reference/東京', { inputTokens: 140, totalCostUsd: null,
    providerName: '<script>literal 月</script>', prompt: 'private-prompt', apiKey: 'private-key' })]);
  writeInvestigation(left, 'Current investigation', { shared: 'Same observation note', failed: 'Investigate failure' });
  writeInvestigation(right, 'Another review\nNo causal conclusion.', { shared: 'Same observation note', 'reference/東京': 'Compare the reference' });
  chooseComparison(left, 'shared', 'failed'); chooseComparison(right, 'reference/東京', 'shared');
  right.run('requestCollectionUI.saveReview.events.click()');
  const file = right.blobs[0], sourceText = await file.text();
  const current = left.run('requestReviewJson()');
  const firstCapture = left.run('JSON.stringify(requestCollection[0])');
  const pageBefore = left.run('JSON.stringify(requestPageSnapshot)');
  const detailBefore = left.run('JSON.stringify(requestSelectedDetail)');
  left.run('safeGetJson = () => { throw new Error("Merge must be local"); }');
  await chooseReviewFile(left, file);
  assert.equal(left.run('requestReviewJson()'), current);
  assert.equal(left.run('requestCollectionUI.mergeReview.disabled'), true);
  assert.match(left.run('requestCollectionUI.mergePreview.textContent'), /1 new observations; 1 matching IDs.*1 new notes/);
  assert.match(left.run('requestCollectionUI.mergePreview.textContent'), /appended below the current summary/);
  assert.equal(left.run('requestCollectionUI.mergeReview.events.click()'), false, 'namespace confirmation is required');
  confirmReviewMerge(left);
  assert.equal(left.run('requestCollectionUI.mergeReview.disabled'), false);
  assert.equal(left.run('requestCollectionUI.mergeReview.events.click()'), true);
  assert.deepEqual(JSON.parse(left.run('JSON.stringify(requestCollection.map(entry => entry.id))')), ['shared', 'failed', 'reference/東京']);
  assert.equal(left.run('JSON.stringify(requestCollection[0])'), firstCapture, 'duplicates keep the current capture context and provenance');
  assert.equal(left.run('requestCollection[2].fromReviewFile'), true);
  assert.equal(left.run('requestAnnotationNotes.size'), 3);
  assert.equal(left.run('requestComparisonBaseline'), 'shared');
  assert.equal(left.run('requestComparisonCandidate'), 'failed');
  assert.equal(left.run('JSON.stringify(requestPageSnapshot)'), pageBefore);
  assert.equal(left.run('JSON.stringify(requestSelectedDetail)'), detailBefore);
  assert.equal(left.run('requestReviewPending'), null);
  assert.equal(left.run('requestCollectionUI.mergeConfirm.checked'), false);
  assert.equal(left.run('requestCollectionUI.mergeReview.events.click()'), false, 'a second click has no staged file');
  left.run('requestCollectionUI.saveReview.events.click()');
  const merged = await left.blobs[0].text();
  assert.match(merged, /Imported review summary \(operator-authored, unverified\)/);
  assert.doesNotMatch(merged, /private-prompt|private-key/);
  assert.equal(await file.text(), sourceText, 'source download bytes stay unchanged');
  let calls = 0;
  const reopened = harness(async () => { calls++; return { ok: false }; }); reopened.run('renderRequestCollection()');
  await chooseReviewFile(reopened, left.blobs[0]); reopened.run('requestCollectionUI.openReview.events.click()');
  assert.equal(reopened.run('requestReviewJson()'), merged);
  reopened.run('requestAnnotationUI.download.events.click()');
  const report = await reopened.blobs[0].text();
  assert.match(report, /Compare the reference/);
  assert.match(report, /Estimated cost USD:\n  \| Unavailable/);
  assert.match(report, /Local review file \(unverified; not refreshed\)/);
  assert.match(report, /<script>literal 月<\/script>/);
  assert.equal(calls, 0);
  if (process.env.MOONGATE_MERGE_EVIDENCE) {
    fs.mkdirSync(process.env.MOONGATE_MERGE_EVIDENCE, { recursive: true });
    fs.writeFileSync(path.join(process.env.MOONGATE_MERGE_EVIDENCE, 'merged-review.json'), merged);
    fs.writeFileSync(path.join(process.env.MOONGATE_MERGE_EVIDENCE, 'reopened-report.txt'), report);
  }
});

test("legacy merge preserves exact case-sensitive IDs and repeat imports keep matching observations once", async () => {
  const left = await keptReviewHarness([row('A')]);
  const right = await keptReviewHarness([row('a'), row('B')]);
  const file = new Blob([right.run('requestReviewJson()')]);
  await chooseReviewFile(left, file); confirmReviewMerge(left); left.run('requestCollectionUI.mergeReview.events.click()');
  assert.deepEqual(JSON.parse(left.run('JSON.stringify(requestCollection.map(entry => entry.id))')), ['A', 'a', 'B']);
  const first = left.run('requestReviewJson()'), collection = left.run('JSON.stringify(requestCollection)');
  await chooseReviewFile(left, file);
  assert.match(left.run('requestCollectionUI.mergePreview.textContent'), /0 new observations; 2 matching IDs/);
  confirmReviewMerge(left); left.run('requestCollectionUI.mergeReview.events.click()');
  assert.equal(left.run('requestReviewJson()'), first);
  assert.equal(left.run('JSON.stringify(requestCollection)'), collection);
  assert.equal(JSON.parse(first).schema, 'moongate.request-review.v1');
});

test("conflicting recorded metadata and notes block the whole merge and identify the exact request", async () => {
  const left = await keptReviewHarness([row('collision/東京'), row('keep')]);
  const right = await keptReviewHarness([row('collision/東京', { statusCode: 500 }), row('new')]);
  writeInvestigation(left, '', { 'collision/東京': 'Current explanation' });
  writeInvestigation(right, '', { 'collision/東京': 'File explanation', new: 'New note' });
  chooseComparison(left, 'collision/東京', 'keep');
  const before = left.run('requestReviewJson()');
  await chooseReviewFile(left, new Blob([right.run('requestReviewJson()')])); confirmReviewMerge(left);
  assert.match(left.run('requestCollectionUI.mergePreview.textContent'), /Different recorded metadata for request "collision\/東京"/);
  assert.match(left.run('requestCollectionUI.mergePreview.textContent'), /Different operator notes for request "collision\/東京"/);
  assert.equal(left.run('requestCollectionUI.mergeReview.disabled'), true);
  assert.equal(left.run('requestCollectionUI.mergeReview.events.click()'), false);
  assert.equal(left.run('requestReviewJson()'), before, 'no nonconflicting rows or notes are partially imported');
  left.run('requestCollectionUI.saveReview.events.click()');
  left.run('requestCollectionUI.list.children[0].children[2].events.click()');
  assert.equal(left.run('requestCollectionUI.mergeReview.disabled'), false, 'explicitly removing the conflicting observation resolves the merge');
  left.run('requestCollectionUI.mergeReview.events.click()');
  assert.equal(left.run('requestCollection.length'), 3);
  assert.equal(left.run("requestAnnotationNotes.get('collision/東京')"), 'File explanation');
  assert.equal(await left.blobs[0].text(), before, 'the saved prior review remains recoverable');
  assert.equal(left.run('requestComparisonBaseline'), '', 'removal clears that choice rather than substituting the imported observation');
});

test("editing a kept note while a file is staged recomputes conflicts and permits an explicit recovery", async () => {
  const left = await keptReviewHarness([row('A')]);
  const right = await keptReviewHarness([row('A')]);
  writeInvestigation(right, 'File context', { A: 'File note' });
  await chooseReviewFile(left, new Blob([right.run('requestReviewJson()')])); confirmReviewMerge(left);
  assert.equal(left.run('requestCollectionUI.mergeReview.disabled'), false);
  writeInvestigation(left, '', { A: 'New local note after preview' });
  assert.equal(left.run('requestCollectionUI.mergeReview.disabled'), true);
  assert.equal(left.run('requestCollectionUI.mergeReview.events.click()'), false);
  assert.equal(left.run("requestAnnotationNotes.get('A')"), 'New local note after preview');
  writeInvestigation(left, '', { A: 'File note' });
  assert.equal(left.run('requestCollectionUI.mergeReview.disabled'), false);
  left.run('requestCollectionUI.mergeReview.events.click()');
  assert.equal(left.run('requestAnnotationSummary'), 'File context');
  const saved = left.run('requestReviewJson()');
  await chooseReviewFile(left, new Blob([right.run('requestReviewJson()')])); confirmReviewMerge(left);
  left.run('requestCollectionUI.mergeReview.events.click()');
  assert.equal(left.run('requestReviewJson()'), saved, 'identical summary and notes are not doubled');
});

test("canceling or choosing a newer file clears merge confirmation and cannot apply an interrupted older read", async () => {
  const left = await keptReviewHarness([row('keep')]), right = await keptReviewHarness([row('incoming')]);
  const file = new Blob([right.run('requestReviewJson()')]);
  const before = left.run('requestReviewJson()');
  await chooseReviewFile(left, file); confirmReviewMerge(left);
  const slow = deferred();
  const reading = chooseReviewFile(left, { size: file.size, text: () => slow.promise });
  assert.equal(left.run('requestCollectionUI.mergeReview.disabled'), true);
  assert.equal(left.run('requestCollectionUI.mergeConfirm.checked'), false);
  left.run('requestCollectionUI.cancelReview.events.click()');
  slow.resolve(await file.text()); await reading;
  assert.equal(left.run('requestReviewPending'), null);
  assert.equal(left.run('requestCollectionUI.mergeReview.events.click()'), false);
  assert.equal(left.run('requestReviewJson()'), before);
  await chooseReviewFile(left, file); confirmReviewMerge(left);
  await chooseReviewFile(left, new Blob(['invalid JSON']));
  assert.equal(left.run('requestCollectionUI.mergeReview.disabled'), true);
  assert.equal(left.run('requestCollectionUI.mergeConfirm.checked'), false);
  assert.equal(left.run('requestReviewJson()'), before);
});

test("combined observation capacity is previewed and a saved current review can be trimmed before merging", async () => {
  const source = await keptReviewHarness([row('incoming')]);
  const file = new Blob([source.run('requestReviewJson()')]);
  const seed = JSON.parse(source.run('requestReviewJson()'));
  seed.observations = Array.from({ length: 100 }, (_, i) => ({ ...seed.observations[0], id: 'kept-' + i,
    fields: seed.observations[0].fields.map(([label, value]) => [label, label === 'Request ID' ? 'kept-' + i : value]) }));
  const h = harness(); h.run('renderRequestCollection()');
  await chooseReviewFile(h, new Blob([JSON.stringify(seed)])); h.run('requestCollectionUI.openReview.events.click()');
  const before = h.run('requestReviewJson()');
  await chooseReviewFile(h, file); confirmReviewMerge(h);
  assert.match(h.run('requestCollectionUI.mergePreview.textContent'), /Combined collection exceeds 100 observations or 2 MiB/);
  assert.equal(h.run('requestCollectionUI.mergeReview.events.click()'), false);
  assert.equal(h.run('requestReviewJson()'), before);
  h.run('requestCollectionUI.saveReview.events.click(); requestCollectionUI.list.children[0].children[2].events.click()');
  assert.equal(h.run('requestCollectionUI.mergeReview.disabled'), false);
  h.run('requestCollectionUI.mergeReview.events.click()');
  assert.equal(h.run('requestCollection.length'), 100);
  assert.equal(h.run('requestCollection[99].id'), 'incoming');
  assert.equal(await h.blobs[0].text(), before);
});

test("combined summary capacity is actionable and changing the current summary updates the staged preview", async () => {
  const left = await keptReviewHarness([row('A')]), right = await keptReviewHarness([row('B')]);
  writeInvestigation(left, 'L'.repeat(5000)); writeInvestigation(right, 'R'.repeat(4000));
  const file = new Blob([right.run('requestReviewJson()')]);
  const before = left.run('requestReviewJson()');
  await chooseReviewFile(left, file); confirmReviewMerge(left);
  assert.match(left.run('requestCollectionUI.mergePreview.textContent'), /Combined annotations exceed the 8000-character summary/);
  assert.equal(left.run('requestCollectionUI.mergeReview.events.click()'), false);
  assert.equal(left.run('requestReviewJson()'), before);
  writeInvestigation(left, 'Shortened current summary');
  assert.equal(left.run('requestCollectionUI.mergeReview.disabled'), false);
  left.run('requestCollectionUI.mergeReview.events.click()');
  assert.match(left.run('requestAnnotationSummary'), /^Shortened current summary\n\nImported review summary/);
  const saved = left.run('requestReviewJson()');
  await chooseReviewFile(left, file); confirmReviewMerge(left); left.run('requestCollectionUI.mergeReview.events.click()');
  assert.equal(left.run('requestReviewJson()'), saved, 'repeating the final imported summary block keeps it once');
});

test("merge previews and combined exports keep unverified operator text literal and metadata-only CSV separate", async () => {
  const left = await keptReviewHarness([row('A')]);
  const right = await keptReviewHarness([row('=SUM(1,2)')]);
  const literal = '<img src=x onerror=alert(1)>\n東京 😀';
  writeInvestigation(right, literal, { '=SUM(1,2)': literal });
  await chooseReviewFile(left, new Blob([right.run('requestReviewJson()')]));
  assert.equal(left.run('requestCollectionUI.mergePreview.innerHTML'), '');
  assert.match(left.run('requestCollectionUI.mergePreview.textContent'), /<img src=x/);
  confirmReviewMerge(left); left.run('requestCollectionUI.mergeReview.events.click()');
  assert.equal(left.run('requestAnnotationUI.summary.value'), literal);
  left.run('requestCollectionUI.download.events.click()');
  const csv = await left.blobs[0].text();
  assert.match(csv, /'\=SUM\(1,2\)/);
  assert.doesNotMatch(csv, /onerror/);
  assert.match(left.run('requestInvestigationReport()'), /Operator annotations below are unverified/);
  assert.match(left.run('requestInvestigationReport()'), /<img src=x/);
});

function searchKept(h, value) {
  h.context.subsetSearchText = value;
  h.run('requestSubsetUI.search.value = subsetSearchText; requestSubsetUI.search.events.input()');
}
function checkSubsetRow(h, index, checked = true) {
  h.context.subsetRowIndex = index; h.context.subsetChecked = checked;
  h.run('(() => { const box = requestCollectionUI.list.children[subsetRowIndex].children[0].children[0].children[0]; box.checked = subsetChecked; box.events.change(); })()');
}
function subsetIds(h) {
  return JSON.parse(h.run('JSON.stringify(requestSubsetJson() === null ? [] : JSON.parse(requestSubsetJson()).observations.map(entry => entry.id))'));
}

test("a focused subset is saved and reopened with exact chosen observations and notes while full work is preserved", async () => {
  const h = await keptReviewHarness([
    row('failed/東京', { statusCode: 503, model: 'east-route', latencyMs: 0, totalCostUsd: null, prompt: 'private-prompt', apiKey: 'private-key' }),
    row('reference', { model: 'east-route', statusCode: 200 }),
    row('unrelated', { model: 'west-route', statusCode: 502 }),
  ]);
  chooseComparison(h, 'failed/東京', 'reference');
  writeInvestigation(h, 'Global context mentions unrelated request', {
    'failed/東京': 'Review this timeout', reference: 'A successful reference', unrelated: 'Not part of this handoff',
  });
  const full = h.run('requestReviewJson()');
  const source = JSON.parse(full);
  searchKept(h, 'east-route');
  assert.equal(h.run('requestCollectionUI.list.children.length'), 2);
  h.run('requestSubsetUI.select.events.click()');
  h.run('requestSubsetUI.save.events.click()');
  const saved = await h.blobs[0].text(), parsed = JSON.parse(saved);
  assert.equal(h.downloads[0].download, 'moongate-request-subset.json');
  assert.deepEqual(parsed.observations, source.observations.slice(0, 2));
  assert.equal(parsed.annotations.summary, '', 'whole-investigation summary requires explicit inclusion');
  assert.deepEqual(parsed.annotations.notes, source.annotations.notes.slice(0, 2));
  assert.deepEqual(parsed.comparison, source.comparison);
  assert.match(parsed.scope, /Selected observations only; not complete history/);
  assert.doesNotMatch(saved, /unrelated|Not part of this handoff|private-prompt|private-key/);
  assert.equal(h.run('requestReviewJson()'), full);
  assert.match(h.run('requestSubsetUI.preview.textContent'), /Partial investigation export: 2 of 3/);
  let calls = 0;
  const reopened = harness(async () => { calls++; return { ok: false }; }); reopened.run('renderRequestCollection()');
  await chooseReviewFile(reopened, h.blobs[0]); reopened.run('requestCollectionUI.openReview.events.click()');
  assert.equal(reopened.run('requestReviewJson()'), saved);
  assert.equal(reopened.run('requestSubsetIds.size'), 0, 'a subset file does not preselect another handoff');
  reopened.run('requestAnnotationUI.download.events.click()');
  const report = await reopened.blobs[0].text();
  assert.match(report, /Local review file \(unverified; not refreshed\)/);
  assert.match(report, /Review this timeout/);
  assert.match(report, /0 \(zero or unavailable\)/);
  assert.match(report, /Unavailable/);
  assert.doesNotMatch(report, /unrelated|private-key/);
  assert.equal(calls, 0);
  if (process.env.MOONGATE_SUBSET_EVIDENCE) {
    const out = process.env.MOONGATE_SUBSET_EVIDENCE; fs.mkdirSync(out, { recursive: true });
    fs.writeFileSync(path.join(out, 'full-review.json'), full);
    fs.writeFileSync(path.join(out, 'focused-subset.json'), saved);
    fs.writeFileSync(path.join(out, 'reopened-subset-report.txt'), report);
  }
});

test("search and manual or visible selection preserve hidden choices and never narrow full exports", async () => {
  const h = await keptReviewHarness([row('A', { model: 'alpha' }), row('B', { model: 'beta' }), row('C', { model: 'gamma' })]);
  writeInvestigation(h, 'not searchable global summary', { B: 'Need follow-up at Tokyo' });
  const full = h.run('requestReviewJson()'), csv = h.run('requestCollectionCsv()'), report = h.run('requestInvestigationReport()');
  checkSubsetRow(h, 0);
  searchKept(h, '  FOLLOW-UP AT TOKYO  ');
  assert.equal(h.run('requestCollectionUI.list.children.length'), 1);
  assert.match(h.run('requestCollectionUI.list.children[0].children[0].textContent'), /^B ·/);
  assert.match(h.run('requestSubsetUI.preview.textContent'), /1 selected observations hidden/);
  h.run('requestSubsetUI.select.events.click()');
  assert.deepEqual(subsetIds(h), ['A', 'B']);
  assert.equal(h.run('requestSubsetUI.select.disabled'), true);
  h.run('requestSubsetUI.select.events.click()');
  assert.deepEqual(subsetIds(h), ['A', 'B'], 'repeated visible selection adds no duplicates');
  searchKept(h, 'not searchable global summary');
  assert.equal(h.run('requestCollectionUI.list.children.length'), 0);
  assert.equal(h.run('requestSubsetUI.select.disabled'), true);
  assert.equal(h.run('requestSubsetUI.save.disabled'), false);
  assert.match(h.run('requestSubsetUI.preview.textContent'), /2 selected observations hidden/);
  assert.equal(h.run('requestReviewJson()'), full);
  assert.equal(h.run('requestCollectionCsv()'), csv);
  assert.equal(h.run('requestInvestigationReport()'), report);
  h.run('requestSubsetUI.reset.events.click()');
  assert.equal(h.run('requestCollectionUI.list.children.length'), 3);
  assert.equal(h.run('requestCollectionUI.list.children[0].children[0].children[0].children[0].checked'), true);
  checkSubsetRow(h, 0, false);
  assert.deepEqual(subsetIds(h), ['B']);
  h.run('requestSubsetUI.clear.events.click()');
  assert.equal(h.run('requestSubsetJson()'), null);
  assert.equal(h.run('requestCollection.length'), 3);
  assert.equal(h.run('requestSubsetUI.save.disabled'), true);
  h.run('requestSubsetUI.save.events.click()');
  assert.equal(h.downloads.length, 0);
});

test("subset summary inclusion is explicit and exported annotations reflect the latest accepted edit", async () => {
  const h = await keptReviewHarness(); chooseComparison(h, 'A', 'B');
  writeInvestigation(h, 'Whole review context', { A: 'Original note', B: 'Excluded note' });
  checkSubsetRow(h, 0);
  let saved = JSON.parse(h.run('requestSubsetJson()'));
  assert.equal(saved.annotations.summary, '');
  assert.equal(saved.comparison.baselineId, 'A'); assert.equal(saved.comparison.candidateId, '');
  assert.equal(h.run('requestComparisonCandidate'), 'B', 'projection never clears the live comparison');
  h.run('requestSubsetUI.includeSummary.checked = true; requestSubsetUI.includeSummary.events.change()');
  writeInvestigation(h, 'Revised whole review context', { A: 'Revised note' });
  saved = JSON.parse(h.run('requestSubsetJson()'));
  assert.equal(saved.annotations.summary, 'Revised whole review context');
  assert.deepEqual(saved.annotations.notes, [{ requestId: 'A', text: 'Revised note' }]);
  assert.match(h.run('requestSubsetUI.preview.textContent'), /summary included in full/);
  writeInvestigation(h, '', { A: '' });
  assert.equal(h.run('requestSubsetUI.includeSummary.checked'), false);
  assert.equal(h.run('requestSubsetUI.includeSummary.disabled'), true);
  assert.equal(JSON.parse(h.run('requestSubsetJson()')).schema, 'moongate.request-review.v1');
  writeInvestigation(h, 'New summary starts excluded');
  assert.equal(h.run('requestSubsetIncludeSummary'), false);
  assert.equal(JSON.parse(h.run('requestSubsetJson()')).schema, 'moongate.request-review.v1');
  h.run('requestCollectionUI.saveReview.events.click()');
  assert.equal(JSON.parse(await h.blobs[0].text()).observations.length, 2, 'full save handler does not interpret click events as subset flags');
});

test("staging or canceling preserves subset choices but explicit replacement resets even same-ID choices", async () => {
  const current = await keptReviewHarness();
  writeInvestigation(current, 'Existing summary'); checkSubsetRow(current, 0);
  searchKept(current, 'A');
  current.run('requestSubsetUI.includeSummary.checked = true; requestSubsetUI.includeSummary.events.change()');
  const chosen = current.run('requestSubsetJson()');
  const incoming = await keptReviewHarness([row('A', { model: 'replaced metadata' })]);
  await chooseReviewFile(current, new Blob([incoming.run('requestReviewJson()')]));
  assert.equal(current.run('requestSubsetJson()'), chosen);
  current.run('requestCollectionUI.cancelReview.events.click()');
  assert.equal(current.run('requestSubsetJson()'), chosen);
  const wait = deferred();
  const pending = chooseReviewFile(current, { size: 100, text: () => wait.promise });
  current.run('requestCollectionUI.cancelReview.events.click()'); wait.resolve(incoming.run('requestReviewJson()')); await pending;
  assert.equal(current.run('requestSubsetJson()'), chosen);
  await chooseReviewFile(current, new Blob([incoming.run('requestReviewJson()')]));
  current.run('requestCollectionUI.openReview.events.click()');
  assert.equal(current.run('requestSubsetJson()'), null);
  assert.equal(current.run('requestSubsetUI.search.value'), '');
  assert.equal(current.run('requestSubsetIncludeSummary'), false);
  assert.match(current.run('requestCollection[0].fields.find(([label]) => label === "Model")[1]'), /replaced metadata/);
});

test("merge preserves current subset choices, added observations start unchecked, and recapture cannot revive a selection", async () => {
  const h = await keptReviewHarness(); checkSubsetRow(h, 0);
  const incoming = await keptReviewHarness([row('C')]);
  await chooseReviewFile(h, new Blob([incoming.run('requestReviewJson()')]));
  h.run('requestCollectionUI.mergeConfirm.checked = true; requestCollectionUI.mergeConfirm.events.change(); requestCollectionUI.mergeReview.events.click()');
  assert.deepEqual(subsetIds(h), ['A']);
  assert.equal(h.run('requestCollection.length'), 3);
  assert.equal(h.run('requestCollectionUI.list.children[2].children[0].children[0].children[0].checked'), false);
  h.run("removeRequestObservation('A')");
  await h.run("selectRequestDetail('A')"); h.run('keepRequestObservation()');
  assert.deepEqual(subsetIds(h), []);
  searchKept(h, 'fixture'); h.run('requestSubsetUI.select.events.click()');
  assert.equal(subsetIds(h).length, 3);
  h.run('requestCollectionUI.clear.events.click()');
  assert.equal(h.run('requestSubsetUI.search.value'), '');
  assert.equal(h.run('requestSubsetIds.size'), 0);
  assert.equal(h.run('requestSubsetUI.select.disabled'), true);
  assert.equal(h.run('requestSubsetUI.save.disabled'), true);
});

test("failed gateway refreshes do not discard a local focused handoff and search changes never fetch", async () => {
  let fail = false, calls = 0;
  const h = harness(async url => { calls++; return fail ? { ok: false } : url.includes('request-detail') ? { ok: true, data: row('A') } : page([row('A')]); });
  await h.run('loadRequestExplorer()'); await h.run("selectRequestDetail('A')"); h.run('keepRequestObservation()');
  checkSubsetRow(h, 0); const before = h.run('requestSubsetJson()');
  const count = calls;
  searchKept(h, 'no matches'); h.run('requestSubsetUI.save.events.click()');
  assert.equal(calls, count);
  fail = true; await h.run('applyRequestFilters()');
  assert.equal(h.run('requestSubsetJson()'), before);
  assert.equal(h.run('requestSubsetUI.save.disabled'), false);
  assert.match(h.run('requestSubsetUI.preview.textContent'), /1 selected observations hidden/);
  assert.equal(await h.blobs[0].text(), before);
});

test("literal Unicode and punctuation searches preserve opaque IDs, notes and unknown measures", async () => {
  const records = [row('a[.]東京', { providerName: '<script>月</script>', latencyMs: null, totalCostUsd: 0, inputTokens: null }), row('A[.]東京'), row('other')];
  const h = await keptReviewHarness(records);
  writeInvestigation(h, '', { 'a[.]東京': 'Literal =SUM(A1) 😀 note' });
  searchKept(h, '[.]東京');
  assert.equal(h.run('requestCollectionUI.list.children.length'), 2, 'case-insensitive search never folds exact record identity');
  h.run('requestSubsetUI.select.events.click()');
  assert.deepEqual(subsetIds(h), ['a[.]東京', 'A[.]東京']);
  searchKept(h, '😀');
  assert.equal(h.run('requestCollectionUI.list.children.length'), 1);
  assert.equal(h.run('requestCollectionUI.list.children[0].children[1].innerHTML'), '');
  assert.match(h.run('requestCollectionUI.list.children[0].children[1].textContent'), /<script>月<\/script>/);
  const saved = JSON.parse(h.run('requestSubsetJson()'));
  assert.equal(saved.observations[0].fields.find(([label]) => label === 'Estimated cost USD')[1], '0 (zero or unavailable)');
  assert.equal(saved.observations[0].fields.find(([label]) => label === 'Latency ms')[1], 'Unavailable');
  assert.equal(h.run('requestSubsetUI.preview.innerHTML'), '');
  assert.deepEqual(saved.annotations.notes, [{ requestId: 'a[.]東京', text: 'Literal =SUM(A1) 😀 note' }]);
  h.run("requestAnnotationUI.selected.value = 'a[.]東京'; requestAnnotationUI.selected.events.change(); requestAnnotationUI.note.value = 'Edited without emoji'; requestAnnotationUI.note.events.input()");
  assert.equal(h.run('requestCollectionUI.list.children.length'), 0, 'editing a note refreshes its search match');
  assert.deepEqual(subsetIds(h), ['a[.]東京', 'A[.]東京'], 'a changed search match does not silently drop selected evidence');
});
