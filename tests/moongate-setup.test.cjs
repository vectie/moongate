// Offline behavioral regressions for the gateway-served JavaScript assets.
// Run: node --test tests/moongate-setup.test.cjs
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const root = process.env.MOONGATE_TEST_ROOT || path.resolve(__dirname, "..");
const asset = (name) => fs.readFileSync(path.join(root, "public/assets", name), "utf8");
const deferred = () => {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
};
const response = (body, status = 200) => ({
  ok: status >= 200 && status < 300, status,
  json: async () => body,
  text: async () => JSON.stringify(body),
});
const passed = { success: true, networkRequestPerformed: true, httpStatus: 200, modelUsed: "dummy-model", responseTimeMs: 12 };

function element() {
  const classes = new Set();
  return {
    value: "", textContent: "", dataset: {}, children: [], checked: false,
    classList: {
      add: (...names) => names.forEach((name) => classes.add(name)),
      remove: (...names) => names.forEach((name) => classes.delete(name)),
      toggle: (name, on) => on ? classes.add(name) : classes.delete(name),
      contains: (name) => classes.has(name),
    },
    setAttribute() {},
    appendChild(child) { this.children.push(child); },
    set innerHTML(value) { this.markup = value; this.children = []; },
    get innerHTML() { return this.markup || ""; },
  };
}

function harness(fetch = async () => response({ token: "dummy-control-token" })) {
  const nodes = new Map();
  const get = (id) => {
    if (!nodes.has(id)) nodes.set(id, element());
    return nodes.get(id);
  };
  const context = vm.createContext({
    URL, fetch,
    window: { location: { origin: "http://dummy.invalid" } },
    document: {
      querySelector(selector) {
        if (selector === "[data-moongate-framework-apps]") return {
          getAttribute: () => JSON.stringify([{ id: "claude", label: "Dummy app", mode: "single" }]),
        };
        if (selector === "[data-moongate-endpoints]") return {
          getAttribute: () => JSON.stringify({ providerStreamCheck: "/dummy/test", providerCreate: "/dummy/providers", providerCurrent: "/dummy/current" }),
        };
        return null;
      },
      getElementById: get,
      querySelectorAll: () => get("provider-rows").children,
      createElement: element,
    },
  });
  vm.runInContext(asset("moongate-core.js"), context);
  return { context, get, run: (source) => vm.runInContext(source, context) };
}

function providerHarness() {
  const h = harness();
  vm.runInContext(asset("moongate-frameworks.js"), h.context);
  vm.runInContext(asset("moongate-setup.js"), h.context);
  h.context.saved = [
    { appType: "claude", id: "alpha", name: "Saved A", baseUrl: "https://a.invalid", apiFormat: "anthropic", modelMapping: { defaultModel: "model-a" }, credentialState: "stored", hasApiKey: true, origin: "user" },
    { appType: "claude", id: "beta", name: "Saved C", baseUrl: "https://c.invalid", credentialState: "stored", hasApiKey: true, origin: "user" },
  ];
  h.context.testResult = passed;
  h.context.refreshCount = 0;
  h.context.requests = [];
  h.run(`
    frameworkRows = [{ id: "claude", mode: "single", providers: saved }];
    postJson = async (_path, payload) => { requests.push(payload); return testResult; };
    loadFrameworks = async () => { refreshCount += 1; renderProviderRows(saved); };
    loadSetupStatus = async () => {};
    editProvider("claude", "alpha");
  `);
  h.change = (id, value) => {
    h.get(id).value = value;
    h.run('if (typeof providerFormChanged === "function") providerFormChanged()');
  };
  h.testProvider = () => h.run("testProviderFromForm()");
  h.rowMarkup = () => h.get("provider-rows").children.map((row) => row.innerHTML).join("");
  return h;
}

test("bootstrap outage recovers on retry, shares inflight work, and caches success", async () => {
  const first = deferred();
  const second = deferred();
  let bootstrapCalls = 0;
  const paths = [];
  const h = harness((url, options) => {
    paths.push([url, options]);
    if (url === "/control/bootstrap") return ++bootstrapCalls === 1 ? first.promise : second.promise;
    return Promise.resolve(response({ ok: true }));
  });
  const initial = [h.run('getJson("/dummy/one")'), h.run('getJson("/dummy/two")')];
  const initialResults = Promise.allSettled(initial);
  first.reject(new Error("dummy service unavailable"));
  assert.deepEqual((await initialResults).map((result) => result.status), ["rejected", "rejected"]);
  assert.equal(bootstrapCalls, 1);
  assert.equal(paths.length, 1, "protected requests do not bypass failed bootstrap");
  const retries = [h.run('getJson("/dummy/one")'), h.run('postJson("/dummy/two", {value: 1})')];
  const retryResults = Promise.allSettled(retries);
  assert.equal(bootstrapCalls, 2, "one new acquisition for concurrent retries");
  second.resolve(response({ token: "dummy-control-token" }));
  assert.deepEqual((await retryResults).map((result) => result.status), ["fulfilled", "fulfilled"]);
  await h.run('deleteJson("/dummy/three", {value: 2})');
  assert.equal(bootstrapCalls, 2, "successful acquisition stays cached");
  for (const [url, options] of paths) {
    assert.equal(options.headers.Accept, "application/json");
    assert.equal(options.credentials, undefined, "credential policy unchanged");
    if (url !== "/control/bootstrap") assert.equal(options.headers["X-MoonGate-Control-Token"], "dummy-control-token");
  }
  assert.equal(paths.find(([url]) => url === "/dummy/two")[1].headers["Content-Type"], "application/json");
});

test("bootstrap denials stay visible without request bypass or automatic retry", async () => {
  const calls = [];
  const h = harness(async (url) => { calls.push(url); return response({ error: "denied" }, 403); });
  await assert.rejects(h.run('getJson("/dummy/protected")'), /control bootstrap returned 403/);
  assert.equal(calls.length, 1);
  await assert.rejects(h.run('getJson("/dummy/protected")'), /control bootstrap returned 403/);
  assert.deepEqual(calls, ["/control/bootstrap", "/control/bootstrap"]);
});

test("invalid bootstrap JSON can recover and protected-route denial does not refresh credentials", async () => {
  let count = 0;
  const h = harness(async (url) => {
    if (url !== "/control/bootstrap") return response({ error: "Origin is not allowed" }, 403);
    count += 1;
    if (count === 1) return { ok: true, json: async () => { throw new Error("invalid JSON"); } };
    return response({ token: "dummy-control-token" });
  });
  await assert.rejects(h.run('getJson("/dummy/protected")'), /invalid JSON/);
  await assert.rejects(h.run('getJson("/dummy/protected")'), /Origin is not allowed/);
  await assert.rejects(h.run('getJson("/dummy/protected")'), /Origin is not allowed/);
  assert.equal(count, 2);
});

test("missing, non-string, and blank bootstrap tokens fail closed and can be retried", async () => {
  for (const invalid of [{}, { token: 42 }, { token: "" }, { token: "  " }, null]) {
    const calls = [];
    let bootstrapCount = 0;
    const h = harness(async (url) => {
      calls.push(url);
      if (url !== "/control/bootstrap") return response({ ok: true });
      return response(++bootstrapCount === 1 ? invalid : { token: "dummy-control-token" });
    });
    await assert.rejects(h.run('getJson("/dummy/protected")'), /did not return a control token/);
    assert.deepEqual(calls, ["/control/bootstrap"]);
    await h.run('getJson("/dummy/protected")');
    assert.equal(bootstrapCount, 2);
    assert.deepEqual(calls, ["/control/bootstrap", "/control/bootstrap", "/dummy/protected"]);
  }
});

test("testing draft B retains every edit while saved A remains untested", async () => {
  const h = providerHarness();
  h.change("provider-name", "Draft B");
  h.change("provider-base-url", "https://b.invalid");
  h.change("provider-default-model", "model-b");
  h.change("provider-notes", "Dummy unsaved note");
  await h.testProvider();
  assert.equal(h.get("provider-name").value, "Draft B");
  assert.equal(h.get("provider-base-url").value, "https://b.invalid");
  assert.equal(h.get("provider-default-model").value, "model-b");
  assert.equal(h.get("provider-notes").value, "Dummy unsaved note");
  assert.equal(h.get("provider-original-id").value, "alpha");
  assert.match(h.get("provider-test-result").textContent, /Live test passed/);
  assert.match(h.get("provider-form-status").textContent, /Draft tested; save/);
  assert.doesNotMatch(h.rowMarkup(), /Test passed/);
  assert.match(h.rowMarkup(), /Not tested/);
  assert.equal(h.run('connectionGraphTestState(saved[0], "claude").label'), "Not tested");
  assert.equal(h.context.requests[0].baseUrl, "https://b.invalid");
  assert.equal(h.context.requests[0].draft, true);
  h.run('editProvider("claude", "alpha")');
  assert.equal(h.get("provider-test-result").textContent, "Not tested");
});

test("saved configuration proof matches exactly and ignores irrelevant server metadata", async () => {
  const h = providerHarness();
  await h.testProvider();
  assert.match(h.rowMarkup(), /Test passed/);
  assert.equal(h.run('connectionGraphTestState(saved[0], "claude").label'), "Tested: passed");
  h.context.saved[0].healthStatus = "unknown";
  h.context.saved[0].sortIndex = 9;
  h.run("renderProviderRows(saved)");
  assert.match(h.rowMarkup(), /Test passed/);
  h.context.saved[0].modelMapping.defaultModel = "changed-model";
  h.run("renderProviderRows(saved)");
  assert.doesNotMatch(h.rowMarkup(), /Test passed/);
  assert.equal(h.run('connectionGraphTestState(saved[0], "claude").label'), "Not tested");
  h.run('editProvider("claude", "alpha")');
  assert.equal(h.get("provider-test-result").textContent, "Not tested");
});

test("testing changed draft B preserves any existing proof for saved A", async () => {
  const h = providerHarness();
  await h.testProvider();
  const savedProof = h.run("JSON.stringify([...providerTestResults])");
  h.change("provider-base-url", "https://b.invalid");
  h.context.testResult = { ...passed, success: false, httpStatus: 401 };
  await h.testProvider();
  assert.match(h.get("provider-test-result").textContent, /Live test failed/);
  assert.match(h.rowMarkup(), /Test passed/);
  assert.equal(h.run("JSON.stringify([...providerTestResults])"), savedProof);
  assert.equal(h.run('connectionGraphTestState(saved[0], "claude").label'), "Tested: passed");
});

test("draft edits invalidate visible proof immediately, including credential input", async () => {
  const h = providerHarness();
  await h.testProvider();
  h.change("provider-base-url", "https://changed.invalid");
  assert.equal(h.get("provider-test-result").textContent, "Not tested");
  assert.match(h.get("provider-form-status").textContent, /Unsaved changes/);
  await h.testProvider();
  h.change("provider-api-key", "dummy-only-key");
  assert.equal(h.get("provider-test-result").textContent, "Not tested");
});

test("draft key test never certifies saved credentials or retains the key in proof", async () => {
  const h = providerHarness();
  h.change("provider-api-key", "dummy-only-key");
  await h.testProvider();
  assert.equal(h.get("provider-api-key").value, "dummy-only-key", "password draft stays in its existing input");
  assert.match(h.get("provider-test-result").textContent, /Live test passed/);
  assert.doesNotMatch(h.rowMarkup(), /Test passed/);
  assert.doesNotMatch(h.run("JSON.stringify([...providerTestResults])"), /dummy-only-key/);
  assert.doesNotMatch(h.get("provider-test-result").textContent, /dummy-only-key/);
  h.run('editProvider("claude", "alpha")');
  assert.equal(h.get("provider-api-key").value, "");
  assert.equal(h.get("provider-test-result").textContent, "Not tested");
});

test("credential-clear and mapping-clear drafts cannot certify saved A", async () => {
  for (const field of ["provider-clear-api-key", "provider-clear-models"]) {
    const h = providerHarness();
    h.get(field).checked = true;
    h.run("providerFormChanged()");
    await h.testProvider();
    assert.equal(h.get(field).checked, true);
    assert.doesNotMatch(h.rowMarkup(), /Test passed/);
    assert.match(h.get("provider-form-status").textContent, /Draft tested; save/);
  }
});

test("a late reply for alpha cannot select it again or overwrite beta's editor", async () => {
  const h = providerHarness();
  const pending = deferred();
  h.context.testResult = pending.promise;
  const work = h.testProvider();
  h.run('editProvider("claude", "beta")');
  pending.resolve(passed);
  await work;
  assert.equal(h.get("provider-id").value, "beta");
  assert.equal(h.get("provider-name").value, "Saved C");
  assert.equal(h.run("selectedProviderKey"), "claude:beta");
  assert.equal(h.get("provider-test-result").textContent, "Not tested");
  assert.match(h.get("provider-form-status").textContent, /Editing beta/);
  assert.equal(h.context.refreshCount, 0);
});

test("a late rejection for a previously selected provider is ignored", async () => {
  const h = providerHarness();
  const pending = deferred();
  h.context.testResult = pending.promise;
  const work = h.testProvider();
  h.run('editProvider("claude", "beta")');
  pending.reject(new Error("dummy old request failed"));
  await work;
  assert.match(h.get("provider-form-status").textContent, /Editing beta/);
});

test("edits, clearing the form, and template-style resets invalidate pending tests", async () => {
  for (const change of [
    (h) => h.change("provider-default-model", "new-dummy-model"),
    (h) => h.run('clearProviderForm("claude")'),
    (h) => h.run('editProvider("claude", "alpha")'),
  ]) {
    const h = providerHarness();
    const pending = deferred();
    h.context.testResult = pending.promise;
    const work = h.testProvider();
    change(h);
    pending.resolve(passed);
    await work;
    assert.equal(h.get("provider-test-result").textContent, "Not tested");
    assert.equal(h.run("providerTestResults.size"), 0);
  }
});

test("latest test wins when repeated clicks return out of order", async () => {
  const h = providerHarness();
  const first = deferred();
  const second = deferred();
  h.context.testResult = first.promise;
  const older = h.testProvider();
  h.context.testResult = second.promise;
  const newer = h.testProvider();
  second.resolve({ ...passed, success: false, httpStatus: 401 });
  await newer;
  first.resolve(passed);
  await older;
  assert.match(h.get("provider-test-result").textContent, /Live test failed.*HTTP 401/);
  assert.doesNotMatch(h.rowMarkup(), /Test passed/);
});

test("selection changes during post-test refresh stay selected", async () => {
  const h = providerHarness();
  const refresh = deferred();
  h.context.pendingRefresh = refresh.promise;
  h.run("loadFrameworks = async () => pendingRefresh");
  const work = h.testProvider();
  await Promise.resolve();
  h.run('editProvider("claude", "beta")');
  refresh.resolve();
  await work;
  assert.equal(h.get("provider-id").value, "beta");
  assert.equal(h.get("provider-test-result").textContent, "Not tested");
  assert.match(h.get("provider-form-status").textContent, /Editing beta/);
});

test("backend non-live rejection stays visible without claiming success", async () => {
  const h = providerHarness();
  h.context.testResult = { success: true, networkRequestPerformed: false };
  await h.testProvider();
  assert.match(h.get("provider-test-result").textContent, /Live test failed/);
  assert.match(h.get("provider-form-status").textContent, /Test rejected/);
  assert.doesNotMatch(h.rowMarkup(), /Test passed/);
});

test("editor input and select changes are wired to proof invalidation", () => {
  const source = asset("moongate.js");
  assert.match(source, /\$\("provider-form"\)\?\.addEventListener\("input", providerFormChanged\)/);
  assert.match(source, /\$\("provider-form"\)\?\.addEventListener\("change", providerFormChanged\)/);
});

test("template browsing does not mark an unchanged provider draft dirty", async () => {
  const h = providerHarness();
  await h.testProvider();
  const status = h.get("provider-form-status").textContent;
  h.run('providerFormChanged({target: {id: "provider-template"}})');
  assert.match(h.get("provider-test-result").textContent, /Live test passed/);
  assert.equal(h.get("provider-form-status").textContent, status);
});

test("saving a credential change clears earlier saved-provider proof", async () => {
  const h = providerHarness();
  await h.testProvider();
  assert.match(h.rowMarkup(), /Test passed/);
  h.change("provider-api-key", "dummy-replacement-key");
  h.run("refresh = async () => renderProviderRows(saved)");
  await h.run("saveProvider()");
  assert.equal(h.run("providerTestResults.size"), 0);
  assert.equal(h.get("provider-test-result").textContent, "Not tested");
  assert.equal(h.get("provider-api-key").value, "");
  assert.doesNotMatch(h.rowMarkup(), /Test passed/);
});

test("deleting a provider clears its old proof before an ID can be reused", async () => {
  const h = providerHarness();
  await h.testProvider();
  h.run("deleteJson = async () => null; refresh = async () => {};");
  await h.run("deleteProviderFromForm()");
  assert.equal(h.run("providerTestResults.size"), 1, "confirmation does not delete proof");
  await h.run("deleteProviderFromForm()");
  assert.equal(h.run("providerTestResults.size"), 0);
});

test("draft requests are wired to the backend non-persisting health guard", () => {
  const source = fs.readFileSync(path.join(root, "gateway_provider.mbt"), "utf8");
  assert.match(source, /record_stream_check_provider_health\(target, result, draft=true\)/);
  assert.match(source, /record_stream_check_provider_health\(provider, result\)/);
});
