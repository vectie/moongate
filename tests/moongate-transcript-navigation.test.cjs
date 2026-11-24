// Actual dashboard controller with a minimal DOM and fixture preview boundary.
// No provider, network, local storage, or browser qualification is implied.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const script = fs.readFileSync(path.join(__dirname, '../public/assets/moongate-transcript.js'), 'utf8');
function harness(probe) {
  const nodes = new Map(), calls = [];
  class Element {
    constructor(tag = 'div') { this.tagName = tag; this.children = []; this.events = {}; this.dataset = {}; this.attributes = {}; this.value = ''; this.disabled = false; this.raw = ''; }
    set id(value) { this._id = value; nodes.set(value, this); }
    get id() { return this._id; }
    set textContent(value) { this.raw = String(value); this.children = []; }
    get textContent() { return this.raw + this.children.map(node => node.textContent).join(''); }
    set innerHTML(_) { throw new Error('Unsafe markup insertion'); }
    addEventListener(event, callback) { this.events[event] = callback; }
    setAttribute(key, value) { this.attributes[key] = value; }
    appendChild(node) { this.children.push(node); node.parentNode = this; return node; }
    append(...nodes) { nodes.forEach(node => this.appendChild(node)); }
    replaceChildren(...nodes) { this.raw = ''; this.children = []; this.append(...nodes); }
    insertBefore(node, before) { this.children.splice(this.children.indexOf(before), 0, node); node.parentNode = this; }
    scrollIntoView() { this.scrolled = true; }
    reset() { for (const node of nodes.values()) node.value = ''; }
  }
  const root = new Element();
  for (const id of ['form', 'file', 'content', 'format', 'open', 'sample', 'clear', 'status', 'query', 'role', 'json', 'markdown', 'count', 'messages', 'reader-controls']) {
    const node = new Element(); node.id = 'transcript-' + id; root.appendChild(node);
  }
  const get = id => nodes.get(id) || null;
  const context = vm.createContext({ TextEncoder, console, document: { createElement: tag => new Element(tag), createTextNode: value => { const node = new Element('#text'); node.textContent = value; return node; } }, $: get, text: (id, value) => { if (get(id)) get(id).textContent = value; }, endpoints: { transcriptPreview: '/sessions/preview' }, postJson: async (endpoint, data) => { calls.push({ endpoint, data }); return probe ? probe(data) : { schema: 'moongate.transcript.v1', messages: JSON.parse(data.content), sourceName: data.sourceName, format: 'json', messageCount: JSON.parse(data.content).length, skippedRecords: 0 }; } });
  vm.runInContext(script, context);
  const run = source => vm.runInContext(source, context);
  return { get, calls, run, open: async messages => { get('transcript-content').value = JSON.stringify(messages); await run('openTranscript()'); }, filter: (query, role = '') => { get('transcript-query').value = query; get('transcript-role').value = role; get('transcript-query').events.input(); }, rows: () => get('transcript-messages').children, json: expression => JSON.parse(run(`JSON.stringify(${expression})`)) };
}
const exchange = [
  { role: 'user', content: 'Why did the request fail?' },
  { role: 'assistant', content: 'Checking latency [slow].' },
  { role: 'tool', content: '<img src=x onerror=alert(1)> latency [slow] 10ms' },
  { role: 'assistant', content: 'Provider omitted usage.' },
  { role: 'user', content: 'Try another interval.' },
  { role: 'assistant', content: 'Latency [slow] again.' },
  { role: 'tool', content: 'Other result.' },
  { role: 'assistant', content: 'Done.' },
];

test('import, literal search, navigate, reveal exchange context, and retain exact download scope', async () => {
  const h = harness();
  assert.ok(h.get('transcript-navigation'));
  assert.equal(h.get('transcript-next').disabled, true);
  await h.open(exchange);
  assert.equal(h.calls[0].endpoint, '/sessions/preview');
  h.filter('[slow]', 'assistant');
  assert.deepEqual(h.rows().map(node => node.dataset.sourceIndex), ['1', '5']);
  h.get('transcript-context').value = '2'; h.get('transcript-context').events.change();
  assert.deepEqual(h.rows().map(node => node.dataset.sourceIndex), ['0', '1', '2', '3']);
  assert.match(h.rows()[2].textContent, /Nearby context \(outside filter\)/);
  assert.match(h.get('transcript-navigation-status').textContent, /Match 1 of 2/);
  h.get('transcript-next').events.click();
  assert.deepEqual(h.rows().map(node => node.dataset.sourceIndex), ['3', '4', '5', '6', '7']);
  assert.equal(h.rows()[2].attributes['aria-current'], 'true');
  assert.equal(h.rows()[2].scrolled, true);
  assert.equal(h.get('transcript-next').disabled, true);
  const exported = JSON.parse(h.json('transcriptExport("json")').content);
  assert.deepEqual(exported.messages, [exchange[1], exchange[5]]);
  assert.equal(exported.sourceMessageCount, 8);
  h.get('transcript-previous').events.click();
  assert.match(h.get('transcript-navigation-status').textContent, /source message 2/);
  assert.equal(h.calls.length, 1, 'navigation never dispatches or reparses');
});

test('literal highlights use DOM text, preserve original case, and never execute markup', async () => {
  const h = harness(); await h.open(exchange); h.filter('[slow]');
  const pre = h.rows()[1].children[1];
  assert.equal(pre.textContent, exchange[2].content);
  assert.deepEqual(pre.children.filter(node => node.tagName === 'mark').map(node => node.textContent), ['[slow]']);
  h.filter('<img');
  assert.equal(h.rows()[0].children[1].textContent, exchange[2].content);
  assert.equal(h.rows()[0].children[1].children[1].tagName, 'mark');
  h.filter('.*'); assert.equal(h.rows().length, 0, 'query is not a wildcard regex');
});

test('no matches, source edits, and clear disable navigation and erase context', async () => {
  const h = harness(); await h.open(exchange); h.filter('missing');
  assert.equal(h.rows().length, 0);
  assert.match(h.get('transcript-navigation-status').textContent, /No matches/);
  assert.equal(h.get('transcript-json').disabled, true);
  assert.equal(h.run('transcriptExport("json")'), null);
  h.filter('latency'); h.get('transcript-next').events.click();
  h.get('transcript-content').events.input();
  assert.equal(h.rows().length, 0); assert.equal(h.get('transcript-next').disabled, true);
  assert.equal(h.run('transcriptSnapshot'), null);
  await h.open(exchange); h.get('transcript-clear').events.click();
  assert.equal(h.rows().length, 0); assert.equal(h.get('transcript-previous').disabled, true);
});

test('new filters reset current match; boundary navigation clamps without wrapping', async () => {
  const h = harness(); await h.open(exchange); h.filter('latency');
  h.run('navigateTranscriptMatch(99)'); assert.match(h.get('transcript-navigation-status').textContent, /Match 3 of 3/);
  h.filter('latency', 'assistant'); assert.match(h.get('transcript-navigation-status').textContent, /Match 1 of 2/);
  h.run('navigateTranscriptMatch(-99)'); assert.match(h.get('transcript-navigation-status').textContent, /Match 1 of 2/);
  h.get('transcript-context').value = '5'; h.get('transcript-context').events.change();
  assert.deepEqual(h.rows().map(node => node.dataset.sourceIndex), ['0', '1', '2', '3', '4', '5', '6']);
  h.get('transcript-context').value = '999'; h.get('transcript-context').events.change();
  assert.equal(h.rows().length, 2, 'unsupported radius cannot expand transcript');
});

test('duplicate text retains source positions and Unicode matching agrees with highlights', async () => {
  const h = harness(); await h.open([{ role: 'user', content: 'Kelvin' }, { role: 'assistant', content: 'same' }, { role: 'assistant', content: 'same' }]);
  h.filter('kelvin'); assert.equal(h.rows().length, 1);
  assert.equal(h.rows()[0].children[1].children[1].textContent, 'Kelvin');
  h.filter('same'); assert.deepEqual(h.rows().map(node => node.dataset.sourceIndex), ['1', '2']);
  h.get('transcript-next').events.click(); assert.match(h.get('transcript-navigation-status').textContent, /source message 3/);
});

test('stale parse responses cannot restore old context after editing', async () => {
  let resolve; const h = harness(() => new Promise(done => { resolve = done; }));
  const pending = h.open(exchange); h.get('transcript-content').events.input();
  resolve({ schema: 'moongate.transcript.v1', messages: exchange }); await pending;
  assert.equal(h.run('transcriptSnapshot'), null); assert.equal(h.rows().length, 0);
});

test('reopening replaces old match positions; malformed response stays closed', async () => {
  const h = harness(); await h.open(exchange); h.filter('latency'); h.run('navigateTranscriptMatch(2)');
  await h.open([{ role: 'assistant', content: 'New conversation' }]);
  assert.match(h.get('transcript-navigation-status').textContent, /Match 1 of 1/);
  assert.equal(h.rows()[0].dataset.sourceIndex, '0');
  const bad = harness(() => ({ schema: 'wrong', messages: exchange })); await bad.open(exchange);
  assert.equal(bad.rows().length, 0); assert.match(bad.get('transcript-status').textContent, /unreadable/);
});
