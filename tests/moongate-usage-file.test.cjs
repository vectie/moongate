// Run by the native usage_file_wbtest against a real local gateway and served JS.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");
const base = process.env.MOONGATE_USAGE_FILE_TEST_URL;
const root = path.resolve(__dirname, "..");
function harness(js, probe) {
  const nodes = new Map(), downloads = [], blobs = [], calls = [];
  const element = () => ({ value: "", textContent: "", children: [], disabled: false, events: {},
    addEventListener(name, callback) { this.events[name] = callback; },
    replaceChildren(...children) { this.children = children; }, appendChild(child) { this.children.push(child); },
    click() { downloads.push({ href: this.href, name: this.download }); }, reset() { for (const node of nodes.values()) node.value = ""; },
  });
  const get = id => { if (!nodes.has(id)) nodes.set(id, element()); return nodes.get(id); };
  const urls = class extends URL {};
  urls.createObjectURL = blob => { blobs.push(blob); return "blob:usage-file"; };
  urls.revokeObjectURL = () => {};
  const context = vm.createContext({ URL: urls, Blob, TextEncoder, setTimeout: fn => fn(), console,
    document: { createElement: element }, $: get, text: (id, value) => { get(id).textContent = value; },
    endpoints: { usagePreview: "/usage/preview" },
    postJson: async (endpoint, data) => {
      calls.push({ endpoint, data });
      if (probe) return probe(endpoint, data);
      const response = await fetch(base + endpoint, { method: "POST", headers: { "content-type": "application/json", "x-moongate-control-token": "usage-file-fixture-token", Origin: base }, body: JSON.stringify(data) });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || JSON.stringify(result));
      return result;
    },
  });
  const run = source => vm.runInContext(source, context);
  run(js);
  return { get, run, downloads, blobs, calls, snapshot: () => JSON.parse(run("JSON.stringify(usageFileSnapshot)")) };
}

test("served sample to filter to download and reopen; file picker, paste, error and empty filter", { skip: !base }, async () => {
  const page = await (await fetch(base + "/")).text();
  for (const id of ["usage-file-picker", "usage-file-content", "usage-file-app", "usage-file-provider", "usage-file-model", "usage-file-start", "usage-file-end", "usage-file-json", "usage-file-report"]) assert.ok(page.includes(`id="${id}"`), id);
  assert.ok(page.includes("Usage File Explorer"));
  assert.ok(page.includes("/usage/preview"));
  const js = await (await fetch(base + "/assets/moongate-usage.js")).text();
  const h = harness(js);
  h.get("usage-file-sample").events.click();
  await h.run("openUsageFile()");
  const initial = h.snapshot();
  assert.equal(initial.total, 3);
  assert.equal(initial.sourceTotal, 12);
  assert.equal(initial.partial, true);
  assert.deepEqual(initial.summary, { requests: 3, tokens: 2950, knownEstimatedUsd: 0.0045, missingCostCount: 1, undatedCount: 0 });
  assert.equal(initial.data[1].totalCostUsd, 0);
  assert.equal(initial.data[2].totalCostUsd, null);
  assert.match(h.get("usage-file-status").textContent, /PARTIAL SOURCE/);
  h.get("usage-file-app").value = "codex";
  h.get("usage-file-app").events.input();
  assert.equal(h.get("usage-file-json").disabled, true);
  assert.equal(h.run('usageFileExport("json")'), null);
  await h.run("openUsageFile()");
  const filtered = h.snapshot();
  assert.equal(filtered.total, 2);
  assert.equal(filtered.summary.tokens, 1750);
  assert.equal(filtered.summary.missingCostCount, 0);
  assert.equal(filtered.days.length, 2);
  h.get("usage-file-json").events.click();
  h.get("usage-file-report").events.click();
  assert.equal(h.downloads[0].name, "moongate-usage-filtered.json");
  const exported = await h.blobs[0].text();
  const report = await h.blobs[1].text();
  assert.match(report, /2 requests/);
  assert.match(report, /By UTC day/);
  assert.match(report, /PARTIAL SOURCE/);
  await h.run("loadUsageFile({ name: 'reopened.json', size: 100, text: async () => " + JSON.stringify(exported) + " })");
  h.run("resetUsageFileFilters()");
  await h.run("openUsageFile()");
  assert.deepEqual(h.snapshot().data, filtered.data);
  assert.deepEqual(h.snapshot().summary, filtered.summary);
  assert.equal(h.snapshot().sourceTotal, 12);
  assert.equal(h.snapshot().importedRows, 2);
  h.get("usage-file-content").value = fs.readFileSync(path.join(root, "examples/usage/requests.jsonl"), "utf8");
  h.get("usage-file-content").events.input();
  await h.run("openUsageFile()");
  assert.equal(h.snapshot().partial, false);
  h.get("usage-file-start").value = "2026-10-07";
  h.get("usage-file-end").value = "2026-10-07";
  h.get("usage-file-provider").value = "team-fixture";
  h.get("usage-file-model").value = "moon-small";
  await h.run("openUsageFile()");
  assert.equal(h.snapshot().total, 1);
  assert.equal(h.snapshot().summary.knownEstimatedUsd, 0);
  h.get("usage-file-model").value = "absent";
  await h.run("openUsageFile()");
  assert.equal(h.snapshot().total, 0);
  assert.equal(h.snapshot().summary.knownEstimatedUsd, 0);
  h.get("usage-file-content").value = "bad json";
  await h.run("openUsageFile()");
  assert.equal(h.snapshot(), null);
  assert.equal(h.get("usage-file-report").disabled, true);
  assert.match(h.get("usage-file-status").textContent, /Invalid JSON/);
  h.get("usage-file-clear").events.click();
  assert.equal(h.get("usage-file-content").value, "");
  assert.ok(h.calls.every(call => call.endpoint === "/usage/preview"));
  if (process.env.MOONGATE_TRANSCRIPT_EVIDENCE) {
    const dir = process.env.MOONGATE_TRANSCRIPT_EVIDENCE;
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, "filtered-download.json"), exported);
    fs.writeFileSync(path.join(dir, "filtered-report.txt"), report);
  }
});

test("pending preview cannot restore stale downloads after a source edit", async () => {
  let resolve;
  const deferred = new Promise(done => { resolve = done; });
  const h = harness(fs.readFileSync(path.join(root, "public/assets/moongate-usage.js"), "utf8"), () => deferred);
  h.get("usage-file-content").value = "[]";
  const pending = h.run("openUsageFile()");
  h.get("usage-file-content").events.input();
  resolve({ schema: "moongate.usage-file.v1", data: [], report: "old report" });
  await pending;
  assert.equal(h.snapshot(), null);
  assert.equal(h.get("usage-file-json").disabled, true);
});


test("merged unknown source coverage and scope stay visible and survive JSON download", async () => {
  const result = { schema: "moongate.usage-file.v1", sourceName: "Merged usage exports", data: [],
    total: 0, importedRows: 3, sourceTotal: 3, partial: true, sourceCoverageUnknown: true,
    usageMergeScope: "fixture-gateway", report: "PARTIAL SOURCE: original coverage is unknown" };
  const h = harness(fs.readFileSync(path.join(root, "public/assets/moongate-usage.js"), "utf8"), () => result);
  h.get("usage-file-content").value = "[]";
  await h.run("openUsageFile()");
  assert.match(h.get("usage-file-status").textContent, /original source coverage is unknown/);
  assert.doesNotMatch(h.get("usage-file-status").textContent, /of 3 source rows/);
  h.get("usage-file-json").events.click();
  const downloaded = JSON.parse(await h.blobs[0].text());
  assert.equal(downloaded.sourceCoverageUnknown, true);
  assert.equal(downloaded.usageMergeScope, "fixture-gateway");
  assert.match(h.get("usage-file-summary").textContent, /original coverage is unknown/);
});
