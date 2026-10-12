// Shared test cases loaded by moongate-setup.test.cjs; no browser or provider.
function registerCatalogCases({ test, assert, providerHarness, deferred }) {
  const catalog = (providerId = "alpha", ids = ["model-a", "vendor/模型<&\"", "model-c"]) => ({
    appType: "claude", providerId, models: ids.map((id) => ({ id })),
    source: "provider_catalog", inferencePerformed: false,
  });
  function setup() {
    const h = providerHarness();
    h.context.catalogResult = catalog();
    h.context.catalogReads = [];
    h.run('getJson = async (path) => { catalogReads.push(path); return catalogResult; }');
    h.refreshModels = () => h.run("refreshProviderModels()");
    h.choose = (id) => { h.get("provider-models-select").value = id; h.run("chooseProviderCatalogModel()"); };
    return h;
  }

  test("catalog picker reads saved identity only and selection is a draft edit", async () => {
    const h = setup();
    await h.refreshModels();
    const url = new URL(h.context.catalogReads[0], "http://dummy.invalid");
    assert.equal(url.pathname, "/providers/models");
    assert.deepEqual([...url.searchParams.keys()].sort(), ["appType", "providerId"]);
    assert.equal(url.searchParams.get("providerId"), "alpha");
    assert.equal(h.get("provider-api-key").value, "");
    assert.equal(h.get("provider-default-model").value, "model-a");
    assert.match(h.get("provider-models-select").innerHTML, /vendor\/模型&lt;&amp;&quot;/);
    h.choose('vendor/模型<&"');
    assert.equal(h.get("provider-default-model").value, 'vendor/模型<&"');
    assert.equal(h.context.saved[0].modelMapping.defaultModel, "model-a");
    assert.equal(h.context.requests.length, 0, "no save, bind or inference request");
    assert.equal(h.get("provider-test-result").textContent, "Not tested");
    assert.match(h.get("provider-form-status").textContent, /Save Provider/);
  });

  test("catalog picker saves and reloads the selected model with no credential in the payload", async () => {
    const h = setup();
    await h.refreshModels();
    h.choose("model-c");
    h.run(`
      postJson = async (path, payload) => {
        requests.push({ path, payload });
        saved[0] = { ...saved[0], ...payload };
        return {};
      };
      refresh = async () => { frameworkRows = [{ id: "claude", mode: "single", providers: saved }]; };
    `);
    await h.run("saveProvider()");
    assert.equal(h.context.requests.length, 1);
    assert.equal(h.context.requests[0].path, "/dummy/update");
    assert.equal(h.context.requests[0].payload.modelMapping.defaultModel, "model-c");
    assert.equal(h.context.requests[0].payload.apiKey, undefined);
    assert.equal(h.context.saved[0].credentialState, "stored");
    h.run('editProvider("claude", "alpha")');
    assert.equal(h.get("provider-default-model").value, "model-c");
    assert.equal(h.get("provider-api-key").value, "");
    assert.equal(h.get("provider-models-select").disabled, true);
  });

  test("catalog picker refuses unsaved connections and never sends a draft credential", async () => {
    for (const [field, value] of [["provider-base-url", "https://changed.invalid"], ["provider-api-key", "draft-secret"], ["provider-id", "renamed"], ["provider-api-format", "openai_chat"]]) {
      const h = setup();
      h.change(field, value);
      await h.refreshModels();
      assert.equal(h.context.catalogReads.length, 0);
      assert.match(h.get("provider-models-status").textContent, /Save/);
      assert.equal(h.get("provider-default-model").value, "model-a");
    }
    const h = setup();
    h.run('clearProviderForm("claude")');
    await h.refreshModels();
    assert.equal(h.context.catalogReads.length, 0);
    assert.match(h.get("provider-models-status").textContent, /Save/);
  });

  test("catalog picker empty malformed and failed refresh preserve manual entry and recover", async () => {
    for (const result of [catalog("alpha", []), { models: [] }, catalog("beta"), catalog("alpha", ["bad\u00a0id"]), catalog("alpha", ["bad\u0085id"]), catalog("alpha", [""])]) {
      const h = setup();
      h.context.catalogResult = result;
      await h.refreshModels();
      assert.equal(h.get("provider-models-select").disabled, true);
      assert.equal(h.get("provider-default-model").value, "model-a");
      assert.equal(h.get("provider-models-refresh").disabled, false);
      h.context.catalogResult = catalog();
      await h.refreshModels();
      assert.equal(h.get("provider-models-select").disabled, false);
      assert.equal(h.context.requests.length, 0);
    }
    const h = setup();
    h.run('getJson = async () => { throw new Error("Model catalog returned HTTP 401"); }');
    await h.refreshModels();
    assert.match(h.get("provider-models-status").textContent, /HTTP 401/);
    assert.equal(h.get("provider-default-model").value, "model-a");
    assert.equal(h.get("provider-models-refresh").disabled, false);
  });

  test("catalog picker ignores old provider results and errors after navigation", async () => {
    for (const failure of [false, true]) {
      const h = setup();
      const pending = deferred();
      h.context.catalogPending = pending.promise;
      h.run("getJson = () => catalogPending");
      const old = h.refreshModels();
      h.run('editProvider("claude", "beta")');
      if (failure) pending.reject(new Error("old provider failed"));
      else pending.resolve(catalog());
      await old;
      assert.equal(h.get("provider-original-id").value, "beta");
      assert.equal(h.get("provider-default-model").value, "");
      assert.equal(h.get("provider-models-select").disabled, true);
      assert.doesNotMatch(h.get("provider-models-status").textContent, /old provider|model IDs found/);
      assert.equal(h.get("provider-models-refresh").disabled, false);
    }
  });

  test("catalog picker latest refresh wins reversed replies and editing invalidates pending work", async () => {
    const h = setup();
    const first = deferred(), second = deferred();
    h.context.catalogPromises = [first.promise, second.promise];
    h.run("getJson = () => catalogPromises.shift()");
    const a = h.refreshModels(), b = h.refreshModels();
    second.resolve(catalog("alpha", ["newest-model"]));
    await b;
    first.resolve(catalog("alpha", ["old-model"]));
    await a;
    assert.match(h.get("provider-models-select").innerHTML, /newest-model/);
    assert.doesNotMatch(h.get("provider-models-select").innerHTML, /old-model/);
    h.choose("newest-model");
    assert.equal(h.get("provider-default-model").value, "newest-model");
    const pending = deferred();
    h.context.catalogPending = pending.promise;
    h.run("getJson = () => catalogPending");
    const late = h.refreshModels();
    h.change("provider-default-model", "my-manual-model");
    pending.resolve(catalog());
    await late;
    assert.equal(h.get("provider-default-model").value, "my-manual-model");
    assert.equal(h.get("provider-models-select").disabled, true);
  });

  test("catalog picker rejects selection outside the fetched saved-provider list", async () => {
    const h = setup();
    await h.refreshModels();
    h.choose("not-in-this-catalog");
    assert.equal(h.get("provider-default-model").value, "model-a");
    assert.equal(h.get("provider-models-select").disabled, true);
    assert.match(h.get("provider-models-status").textContent, /stale/);
    assert.equal(h.context.requests.length, 0);
  });

  test("catalog picker reports an externally changed saved provider instead of hanging", async () => {
    const h = setup();
    const pending = deferred();
    h.context.catalogPending = pending.promise;
    h.run("getJson = () => catalogPending");
    const result = h.refreshModels();
    h.context.saved[0].baseUrl = "https://new-saved.invalid";
    pending.resolve(catalog());
    await result;
    assert.equal(h.get("provider-models-select").disabled, true);
    assert.equal(h.get("provider-models-refresh").disabled, false);
    assert.match(h.get("provider-models-status").textContent, /changed during discovery/);
    assert.equal(h.get("provider-default-model").value, "model-a");
  });
}
module.exports = { registerCatalogCases };
