const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");
const root = process.env.MOONGATE_TEST_ROOT || path.resolve(__dirname, "..");
const asset = name => fs.readFileSync(path.join(root, "public/assets", name), "utf8");
const deferred = () => { let resolve; const promise = new Promise(yes => { resolve = yes; }); return { promise, resolve }; };
const utc = seconds => new Date(seconds * 1000).toISOString().replace(".000Z", "Z");
const epoch = 1791302400;
const percentile = (n, value = 42) => ({ sample_count: n, p50_ms: n ? value : null, p95_ms: n ? value : null, p99_ms: n ? value : null });
function row(provider = "A", model = "moon", extra = {}) {
  return { provider_id: provider, request_model: model, total: 2, status_2xx: 1, status_4xx: 0, status_5xx: 1, status_other: 0,
    successful: 1, unsuccessful_excluded: 1, invalid_latency_excluded: 0, streaming_successful: 1,
    latency: percentile(1), first_event: percentile(1, 5), missing_first_event_excluded: 0, invalid_first_event_excluded: 0,
    first_event_invalid_elapsed_excluded: 0, oldest_utc: utc(epoch - 2), newest_utc: utc(epoch - 1),
    successful_response_model_mix: [{ model: "response-star", count: 1 }], missing_successful_response_model: 0, ...extra };
}
function snapshot(query, rows = [row("A"), row("a")], extra = {}) {
  const start = query.end - ({ "24h": 86400, "7d": 604800, "30d": 2592000, all: query.end }[query.period]);
  const count = rows.reduce((n, r) => n + r.total, 0);
  return { schema: "moongate.retained-cohorts.v1", app_type: query.appType, streaming: query.streaming, period: query.period,
    start_seconds: start, end_seconds: query.end, start_utc: query.period === "all" ? null : utc(start), end_utc_exclusive: utc(query.end),
    captured_at_ms: query.end * 1000, captured_at_utc: utc(query.end), retained_rows: count, proxy_interval_rows: count,
    imported_excluded: 0, outside_interval_excluded: 0, invalid_timestamp_excluded: 0, missing_request_model_unclassified: 0,
    missing_provider_id_unclassified: 0, oldest_utc: rows.length ? utc(epoch - 2) : null, newest_utc: rows.length ? utc(epoch - 1) : null,
    row_limit: 500, response_byte_limit: 262144, cohorts: rows, ...extra };
}
function queryFrom(url) { const q = new URL(url, "http://fixture.invalid").searchParams; return { appType: q.get("appType"), streaming: q.get("streaming"), period: q.get("period"), end: Number(q.get("end")) }; }

function harness(probe = async url => ({ ok: true, data: snapshot(queryFrom(url)) }), base = "http://fixture.invalid", served = {}, now = epoch) {
  const nodes = new Map(), downloads = [], blobs = [], revoked = [], calls = [];
  const element = () => ({ value: "", textContent: "", children: [], disabled: false, events: {}, classList: { toggle() {} },
    addEventListener(type, cb) { this.events[type] = cb; }, appendChild(child) { this.children.push(child); },
    set innerHTML(value) { this.markup = value; this.children = []; }, get innerHTML() { return this.markup || ""; },
    click() { downloads.push({ href: this.href, download: this.download }); }, remove() {} });
  const get = id => { if (!nodes.has(id)) nodes.set(id, element()); return nodes.get(id); };
  class FixedDate extends Date { static now() { return now * 1000; } }
  const urls = class extends URL {};
  urls.createObjectURL = blob => { blobs.push(blob); return "blob:cohort"; };
  urls.revokeObjectURL = url => revoked.push(url);
  const context = vm.createContext({ URL: urls, Blob, Date: FixedDate, console, setTimeout: fn => fn(),
    window: { location: { origin: base, hash: "#operations" } },
    document: { getElementById: get, createElement: element, body: element(), querySelector: selector => selector === "[data-moongate-endpoints]" ? { getAttribute: () => JSON.stringify({ retainedCohortSnapshot: "/operations/cohort-snapshot" }) } : null },
    fetch: async (url, options) => { calls.push(String(url)); return fetch(new URL(url, base), { ...options, headers: { ...options?.headers, Origin: base } }); },
    probe: async url => { calls.push(url); return probe(url); },
  });
  const run = source => vm.runInContext(source, context);
  run(served["moongate-core.js"] || asset("moongate-core.js"));
  if (probe) run('controlTokenPromise = Promise.resolve("fixture-token"); safeGetJson = probe');
  run(served["moongate-cohorts.js"] || asset("moongate-cohorts.js"));
  get("cohort-streaming").value = "all"; get("cohort-period").value = "24h";
  return { run, get, context, downloads, blobs, revoked, calls, setNow: value => { now = value; },
    snapshot: () => JSON.parse(run("JSON.stringify(cohortSnapshot)")), report: () => run("cohortComparisonReport()") };
}

test("one native snapshot drives exact A/B selectors, report and allowlisted download", async () => {
  const h = harness(); await h.run("captureCohortSnapshot()");
  assert.equal(h.calls.length, 1);
  assert.equal(h.get("cohort-a-provider").value, "A"); assert.equal(h.get("cohort-b-provider").value, "a");
  assert.match(h.report(), /A: provider ID "A"; explicit request model "moon"/);
  assert.match(h.report(), /B: provider ID "a"; explicit request model "moon"/);
  assert.match(h.report(), /2xx 1\/2 \(50.0%\)/);
  assert.match(h.report(), /First-event coverage: 1\/1 \(100.0%\)/);
  assert.match(h.report(), /Small-sample warning: elapsed n<20/);
  assert.equal(h.get("cohort-report").textContent, h.report());
  h.run("exportCohortComparison()");
  assert.equal(await h.blobs[0].text(), h.report() + "\n"); assert.equal(h.revoked.length, 1);
  h.get("cohort-b-provider").value = "A"; h.get("cohort-b-provider").events.change();
  assert.match(h.report(), /same cohort/); assert.equal(h.calls.length, 1);
});

test("reversed responses and A-B-A captures cannot revive stale reports", async () => {
  const waits = [deferred(), deferred(), deferred()]; let i = 0;
  const h = harness(url => { const wait = waits[i++]; wait.query = queryFrom(url); return wait.promise; });
  const a = h.run("captureCohortSnapshot()"); await Promise.resolve();
  h.get("cohort-app").value = "claude"; const b = h.run("captureCohortSnapshot()"); await Promise.resolve();
  h.get("cohort-app").value = "codex"; const again = h.run("captureCohortSnapshot()"); await Promise.resolve();
  assert.equal(h.report(), null);
  waits[2].resolve({ ok: true, data: snapshot(waits[2].query, [row("latest-A")]) }); await again;
  waits[1].resolve({ ok: true, data: snapshot(waits[1].query, [row("B")]) }); await b;
  waits[0].resolve({ ok: true, data: snapshot(waits[0].query, [row("obsolete-A")]) }); await a;
  assert.match(h.report(), /latest-A/); assert.doesNotMatch(h.report(), /obsolete-A/);
});

test("error retry preserves UTC bounds and explicit refresh changes upper bound", async () => {
  let fail = true; const h = harness(async url => fail ? { ok: false, error: "secret-raw-error" } : { ok: true, data: snapshot(queryFrom(url)) });
  await h.run("captureCohortSnapshot()"); const first = h.calls[0];
  assert.equal(h.report(), null); assert.equal(h.get("cohort-export").disabled, true);
  assert.doesNotMatch(h.get("cohort-status").textContent, /secret-raw-error/);
  h.setNow(epoch + 50); fail = false; await h.run("captureCohortSnapshot(true)");
  assert.equal(h.calls[1], first); assert.equal(h.snapshot().end_seconds, epoch);
  await h.run("captureCohortSnapshot()"); assert.equal(h.snapshot().end_seconds, epoch + 50);
  h.get("cohort-period").events.change(); assert.equal(h.report(), null);
  assert.equal(h.get("cohort-retry").disabled, true);
});

test("navigation, auth replacement, gateway changes and health loss invalidate pending exports", async () => {
  for (const change of ['invalidateCohortComparison("Navigation")', 'controlTokenPromise = Promise.resolve("replacement")', 'window.location.origin = "http://new.invalid"', 'window.location.hash = "#overview"', 'invalidateCohortComparison("Gateway unavailable")']) {
    const wait = deferred(); const h = harness(url => { wait.query = queryFrom(url); return wait.promise; });
    const pending = h.run("captureCohortSnapshot()"); await Promise.resolve();
    h.run(change); wait.resolve({ ok: true, data: snapshot(wait.query) }); await pending;
    assert.equal(h.report(), null); h.run("exportCohortComparison()"); assert.equal(h.downloads.length, 0);
  }
  const h = harness(); await h.run("captureCohortSnapshot()");
  h.run('controlTokenPromise = Promise.resolve("new-token")'); assert.equal(h.report(), null);
  assert.match(asset("moongate.js"), /page !== "operations"[\s\S]*invalidateCohortComparison/);
  assert.match(asset("moongate.js"), /healthOk === false[\s\S]*invalidateCohortComparison/);
});

test("empty data is unavailable and mismatched or inconsistent snapshots fail closed", async () => {
  const h = harness(async url => ({ ok: true, data: snapshot(queryFrom(url), []) })); await h.run("captureCohortSnapshot()");
  assert.match(h.report(), /A: unavailable/); assert.match(h.report(), /Matching oldest: unavailable/);
  for (const mutate of [s => { s.end_seconds++; }, s => { s.cohorts[0].total++; }, s => { s.cohorts.push(s.cohorts[0]); }]) {
    const bad = harness(async url => { const s = snapshot(queryFrom(url)); mutate(s); return { ok: true, data: s }; });
    await bad.run("captureCohortSnapshot()"); assert.equal(bad.report(), null);
  }
});

test("metadata is literal, exports omit credentials prompts raw errors and extra fields", async () => {
  const unusual = '月 & "quoted"\n<script>alert(1)</script>=SUM(A1)';
  const h = harness(async url => ({ ok: true, data: snapshot(queryFrom(url), [row(unusual, unusual, { prompt: "secret-prompt", error_message: "secret-error", api_key: "secret-key" })], { token: "secret-token", request_id: "secret-request", raw: "secret-raw" }) }));
  await h.run("captureCohortSnapshot()");
  assert.equal(h.get("cohort-a-provider").children[0].textContent, unusual);
  assert.equal(h.get("cohort-report").innerHTML, "");
  assert.ok(h.report().includes(JSON.stringify(unusual)));
  assert.doesNotMatch(JSON.stringify(h.snapshot()) + h.report(), /secret-/);
  h.run("exportCohortComparison()"); assert.doesNotMatch(await h.blobs[0].text(), /secret-/);
});

test("authenticated native HTTP → served JavaScript → exact displayed report and export", { skip: !process.env.MOONGATE_COHORT_TEST_URL }, async () => {
  const base = process.env.MOONGATE_COHORT_TEST_URL;
  const fixture = JSON.parse(fs.readFileSync(process.env.MOONGATE_COHORT_TEST_FIXTURE, "utf8"));
  const html = await (await fetch(base + "/ui/rabbita")).text();
  const served = {};
  for (const match of html.matchAll(/<script[^>]+src="([^"]+)"/g)) {
    const response = await fetch(new URL(match[1], base)); assert.equal(response.status, 200);
    const name = new URL(match[1], base).pathname.split("/").pop(), bytes = await response.text();
    assert.equal(bytes, asset(name)); served[name] = bytes;
  }
  assert.ok(served["moongate-cohorts.js"]);
  assert.match(html, /id="cohort-report"/);
  const unauthorized = await fetch(base + `/operations/cohort-snapshot?appType=codex&streaming=all&period=24h&end=${fixture.end}`);
  assert.equal(unauthorized.status, 401);
  const h = harness(null, base, served, fixture.end); await h.run("captureCohortSnapshot()");
  assert.equal(h.snapshot().proxy_interval_rows, 30);
  assert.equal(h.snapshot().missing_request_model_unclassified, 1);
  assert.equal(h.snapshot().imported_excluded, 1);
  h.get("cohort-a-model").value = "request-moon"; h.run("renderCohortComparison()");
  h.get("cohort-b-provider").value = "provider-a"; h.get("cohort-b-provider").events.change();
  const report = h.report();
  assert.match(report, /A: provider ID "provider-A"; explicit request model "request-moon"\nRequests: 27; successful 2xx without recorded error: 23/);
  assert.match(report, /Status proportions: 2xx 24\/27 \(88.9%\); 4xx 1\/27 \(3.7%\); 5xx 1\/27 \(3.7%\); other 1\/27 \(3.7%\)/);
  assert.match(report, /Successful elapsed latency: n=22; p50 100, p95 190, p99 200 ms/);
  assert.match(report, /First accepted stream event: n=20; p50 10, p95 19, p99 20 ms/);
  assert.match(report, /First-event coverage: 20\/23 \(87.0%\)/);
  assert.match(report, /B: provider ID "provider-a"; explicit request model "request-moon"\nRequests: 1/);
  assert.doesNotMatch(report + JSON.stringify(h.snapshot()), /secret-|private-request|failed-request-model/);
  assert.equal(h.get("cohort-report").textContent, report);
  h.run("exportCohortComparison()"); assert.equal(await h.blobs[0].text(), report + "\n");
  const token = await h.run("acquireControlToken()");
  const query = { appType: "codex", streaming: "all", period: "24h", end: fixture.end };
  const response = await fetch(base + "/operations/cohort-snapshot?" + new URLSearchParams(query), { headers: { "X-MoonGate-Control-Token": token } });
  assert.equal(response.headers.get("cache-control"), "no-store");
  const native = await response.json();
  assert.deepEqual(native.cohorts, fixture.expected.cohorts);
  if (process.env.MOONGATE_COHORT_EVIDENCE) {
    const out = process.env.MOONGATE_COHORT_EVIDENCE;
    fs.writeFileSync(path.join(out, "displayed-comparison.txt"), report + "\n");
    fs.writeFileSync(path.join(out, "native-snapshot.json"), JSON.stringify(native, null, 2) + "\n");
    fs.writeFileSync(path.join(out, "generated-dashboard.html"), html);
    fs.writeFileSync(path.join(out, "served-assets.json"), JSON.stringify({ assets: Object.keys(served), bytesMatched: true, executed: ["moongate-core.js", "moongate-cohorts.js"], unauthorizedStatus: 401, exactReportExportParity: true }, null, 2) + "\n");
  }
});
