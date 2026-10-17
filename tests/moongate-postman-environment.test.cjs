'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const {spawnSync} = require('node:child_process');
const ROOT = process.env.MOONGATE_TEST_ROOT || path.resolve(__dirname, '..');
const CLI = path.join(ROOT, 'postman_prepare/prepare.cjs');
const {prepareModel, parseArgs} = require(CLI);
const guard = path.join(ROOT, 'tests/postman-prepare-offline-guard.cjs');
const SCHEMA = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json';
const digest = b => crypto.createHash('sha256').update(b).digest('hex');
const base = () => ({info: {name: 'Synthetic collection', schema: SCHEMA}, variable: [{key: 'base', value: 'https://collection.invalid'}, {key: 'model', value: 'root'}], item: [{name: 'Read', request: {method: 'GET', url: '{{base}}/models/{{model}}'}}]});
const env = values => ({name: 'Local 東京', _postman_variable_scope: 'environment', values: values || [{key: 'base', value: 'https://env.invalid', enabled: true}, {key: 'model', value: '環境 ✨', enabled: true}]});
const prepare = (c = base(), e = env(), select = [], show = false) => prepareModel(c, e, e.name, select, show);
function files(c = base(), e = env()) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pm-'));
  const collection = path.join(dir, 'collection.json');
  const environment = path.join(dir, 'environment.json');
  fs.writeFileSync(collection, JSON.stringify(c, null, 1) + '\n', {mode: 0o600});
  fs.writeFileSync(environment, JSON.stringify(e, null, 3) + '\n', {mode: 0o600});
  return {dir, collection, environment, e};
}
function cli(f, extras = [], command = null) {
  const args = ['--collection', f.collection, '--environment', f.environment, '--environment-name', f.e.name, ...extras];
  if (command) args.unshift(command);
  return spawnSync(process.execPath, ['--require', guard, CLI, ...args], {encoding: 'utf8', env: {PATH: process.env.PATH, HOME: process.env.HOME, TMPDIR: process.env.TMPDIR, XDG_CONFIG_HOME: process.env.XDG_CONFIG_HOME}, maxBuffer: 1024 * 1024});
}
function success(result) {
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stderr, '');
  return JSON.parse(result.stdout);
}
test('default real CLI inspects the exact named environment without writing or showing values', () => {
  const f = files(); const before = fs.readdirSync(f.dir); const output = success(cli(f));
  assert.equal(output.environmentName, 'Local 東京');
  assert.equal(output.bindings[0].selectable, true);
  assert.deepEqual(output.bindings[0].applicableRequests, [1]);
  assert.equal(output.bindings[0].selected, false);
  assert.equal(output.bindings[0].value, undefined);
  assert.equal(output.requests[0].references[0].scope, 'collection variable');
  assert.deepEqual(fs.readdirSync(f.dir), before);
  assert.equal(output.sources.collection.sha256, digest(fs.readFileSync(f.collection)));
  assert.match(output.warning, /not complete redaction/);
});
test('real preparation retains exact originals and hashes and produces a native-shaped collection; reinspection roundtrip', () => {
  const f = files(); const cBefore = fs.readFileSync(f.collection); const eBefore = fs.readFileSync(f.environment); const out = path.join(f.dir, 'bundle');
  const output = success(cli(f, ['--select', 'base', '--select', 'model', '--out-dir', out], 'prepare'));
  const preparedFile = path.join(out, output.prepared.file); const bytes = fs.readFileSync(preparedFile); const prepared = JSON.parse(bytes);
  assert.equal(prepared.info.schema, SCHEMA);
  assert.deepEqual(prepared.variable, [{key: 'base', value: 'https://env.invalid'}, {key: 'model', value: '環境 ✨'}]);
  assert.equal(prepared.item[0].request.url.raw, '{{base}}/models/{{model}}');
  assert.deepEqual(fs.readFileSync(path.join(out, 'original.collection.json')), cBefore);
  assert.deepEqual(fs.readFileSync(path.join(out, 'original.environment.json')), eBefore);
  assert.deepEqual(fs.readFileSync(f.collection), cBefore); assert.deepEqual(fs.readFileSync(f.environment), eBefore);
  assert.equal(digest(bytes), output.prepared.sha256);
  const receipt = JSON.parse(fs.readFileSync(path.join(out, 'provenance.json')));
  assert.equal(receipt.complete, true); assert.equal(receipt.sources.environment.sha256, digest(eBefore));
  assert.deepEqual(receipt.precedence, ['URL variable', 'request item variable', 'nearest folder variable', 'selected environment binding', 'collection variable']);
  assert.match(receipt.nativeInteroperability, /^UNRUN/);
  if (process.platform !== 'win32') { assert.equal(fs.statSync(out).mode & 0o777, 0o700); assert.equal(fs.statSync(preparedFile).mode & 0o777, 0o600); }
  const round = success(cli({...f, collection: preparedFile}));
  assert.equal(round.unresolved.length, 0); assert.equal(round.requests[0].references[0].scope, 'collection variable');
});
test('nested folders and closer item and URL scopes win; disabled nearer variables do not shadow', () => {
  const c = base();
  c.item.push({name: 'Folder', variable: [{key: 'base', value: 'https://folder.invalid'}], item: [
    {name: 'Inherited', request: {method: 'GET', url: '{{base}}'}},
    {name: 'Deeper', variable: [{key: 'model', value: 'nested'}], item: [
      {name: 'Item', variable: [{key: 'base', value: 'https://item.invalid'}, {key: 'model', value: 'ignored', disabled: true}], request: {method: 'GET', url: {raw: '{{base}}/:model', variable: [{key: 'base', value: 'https://url.invalid'}]}}}
    ]}
  ]});
  const {prepared, report} = prepare(c, env(), ['base', 'model']);
  assert.equal(report.requests[0].references[0].scope, 'selected environment binding');
  assert.equal(report.requests[1].references[0].scope, 'folder Folder');
  assert.equal(report.requests[2].references.find(v => v.key === 'base').scope, 'URL variable');
  assert.equal(report.requests[2].references.find(v => v.key === 'model').scope, 'folder Folder/Deeper');
  assert.equal(prepared.item[1].item[1].item[0].variable.length, 1);
  assert.deepEqual(report.bindings[0].applicableRequests, [1]);
  assert.deepEqual(report.bindings[0].shadowedRequests, [2, 3]);
});
test('unsafe closer binding stays unresolved instead of falling back to environment', () => {
  const c = base(); c.item[0].variable = [{key: 'base', value: '{{other}}'}];
  const {prepared, report} = prepare(c);
  assert.equal(report.bindings[0].selectable, false);
  assert.equal(report.unresolved[0].state, 'nested-placeholder');
  assert.equal(prepared.item[0].variable[0].value, '');
  assert.throws(() => prepare(c, env(), ['base']), /no applicable/);
});
test('environment enabled flags and duplicate names are explicit and fail closed without losing collection fallback', () => {
  const e = env([{key: 'base', value: 'https://one.invalid'}, {key: 'base', value: 'https://two.invalid'}, {key: 'model', value: 'disabled', enabled: false}, {key: 'skip', value: 'x', disabled: true}]);
  const {report} = prepare(base(), e);
  assert.equal(report.bindings[0].state, 'duplicate-enabled-name');
  assert.equal(report.bindings[1].state, 'duplicate-enabled-name');
  assert.equal(report.bindings[2].state, 'disabled');
  assert.equal(report.requests[0].references[0].state, 'literal');
  for (const name of ['base', 'model', 'skip']) assert.throws(() => prepare(base(), e, [name]), /unavailable or unsafe/);
  e.values[1].enabled = false;
  assert.equal(prepare(base(), e, ['base']).prepared.variable.find(v => v.key === 'base').value, 'https://one.invalid');
});
test('duplicate collection names keep native last-enabled semantics, selection removes all root collisions', () => {
  const c = base(); c.variable.push({key: 'model', value: 'last'}, {key: 'model', value: 'disabled', disabled: true});
  assert.equal(prepare(c).prepared.variable.filter(v => v.key === 'model').at(-1).value, 'last');
  assert.equal(prepare(c, env(), ['model']).prepared.variable.filter(v => v.key === 'model').length, 1);
});
test('Unicode string, false, zero and prototype-like names are literal and stay unexpanded', () => {
  const c = base(); c.item[0].request.url = '{{base}}/{{__proto__}}/{{constructor}}/{{值}}';
  const e = env([{key: 'base', value: 'https://env.invalid'}, {key: '__proto__', value: false}, {key: 'constructor', value: 0}, {key: '值', value: '你好 🌙'}]);
  const result = prepare(c, e, ['__proto__', 'constructor', '值'], true);
  assert.equal(result.prepared.variable.find(v => v.key === '__proto__').value, false);
  assert.equal(result.prepared.variable.find(v => v.key === 'constructor').value, 0);
  assert.equal(result.report.bindings[3].value, '你好 🌙');
  assert.equal(result.prepared.item[0].request.url.raw, c.item[0].request.url);
  assert.equal({}.polluted, undefined);
});
test('missing dynamic nested nonliteral empty multiline sensitive and secret-type bindings remain manual', () => {
  const c = base(); c.item[0].request.body = {mode: 'raw', raw: '{{missing}} {{$guid}} {{nested}} {{object}} {{empty}} {{multi}} {{apiToken}} {{ordinary}}'};
  const e = env([{key: '$guid', value: 'synthetic'}, {key: 'nested', value: '{{base}}/v1'}, {key: 'object', value: {}}, {key: 'empty', value: ''}, {key: 'multi', value: 'a\nb'}, {key: 'apiToken', value: 'TOKEN_MARKER'}, {key: 'ordinary', value: 'SECRET_TYPE_MARKER', type: 'secret'}]);
  const report = prepare(c, e).report;
  assert.deepEqual(report.bindings.map(v => v.state), ['dynamic', 'nested-placeholder', 'non-literal', 'empty', 'multiline-or-control', 'sensitive', 'sensitive']);
  for (const binding of e.values) assert.throws(() => prepare(c, e, [binding.key]), /unavailable or unsafe/);
  assert.ok(report.unresolved.some(v => v.key === 'missing' && v.state === 'missing'));
  assert.ok(report.unresolved.some(v => v.key === '$guid' && v.state === 'dynamic'));
  assert.deepEqual(report.sensitiveNames, ['apiToken', 'ordinary']);
  const shown = JSON.stringify(prepare(c, e, [], true).report);
  assert.ok(!shown.includes('TOKEN_MARKER')); assert.ok(!shown.includes('SECRET_TYPE_MARKER'));
});
test('known auth secrets, scripts, responses and secret-like fields are stripped; ordinary body is explicitly retained', () => {
  const c = base(); c.auth = {type: 'bearer', bearer: [{key: 'token', value: 'AUTH_MARKER'}]};
  c.event = [{script: {exec: ['throw new Error("SCRIPT_MARKER")']}}];
  c.variable.push({key: 'private', value: 'PRIVATE_MARKER', type: 'secret'}, {key: 'apiKey', value: 'KEY_MARKER'});
  c.description = 'META_MARKER'; c.item[0].response = [{body: 'RESPONSE_MARKER'}];
  Object.assign(c.item[0].request, {url: '{{base}}?api_key=QUERY_MARKER&normal={{model}}#FRAGMENT_MARKER', header: [{key: 'Authorization', value: 'HEADER_MARKER'}, {key: 'Cookie', value: 'COOKIE_MARKER'}, {key: 'X-Api-Key', value: 'HEADER_KEY_MARKER'}, {key: 'X-Disabled', value: 'DISABLED_MARKER', disabled: true}], body: {mode: 'raw', raw: 'Ordinary body can contain PRIVATE_TEXT'}});
  const {prepared, report} = prepare(c, env(), ['base']); const text = JSON.stringify(prepared);
  assert.ok(!text.includes('_MARKER')); assert.ok(text.includes('PRIVATE_TEXT'));
  assert.deepEqual(prepared.auth, {type: 'bearer'});
  assert.deepEqual(prepared.event[0].script.exec, []);
  assert.match(report.warning, /bodies may contain private data/);
  assert.ok(report.notices.some(s => s.includes('script code removed')));
});
test('structured query keeps order/repeated keys, excludes disabled and raw shadowed secret values; no percent encoding', () => {
  const c = base(); c.item[0].request.url = {raw: '{{base}}?stale=SECRET_MARKER', query: [{key: 'tag', value: 'a b'}, {key: 'tag', value: 'c&d'}, {key: 'skip', value: 'DISABLED_MARKER', disabled: true}, {key: 'token', value: 'TOKEN_MARKER'}, {key: 'page', value: '{{page}}'}]};
  const result = prepare(c);
  assert.deepEqual(result.prepared.item[0].request.url.query.map(q => q.value), ['a b', 'c&d', 'REPLACE_ME', '{{page}}']);
  assert.equal(result.prepared.item[0].request.url.raw, '{{base}}');
  assert.ok(result.report.unresolved.some(v => v.key === 'page'));
  assert.ok(!JSON.stringify(result.prepared).includes('_MARKER'));
});
test('only converter-supported active fields contribute references and unsupported bodies keep warnings', () => {
  const c = base(); c.item[0].request.body = {mode: 'formdata', formdata: [{key: 'x', value: '{{form}}'}]};
  c.item.push({name: 'Disabled body', request: {method: 'GET', url: 'https://example.invalid', body: {mode: 'raw', raw: '{{disabled}}', disabled: true}}});
  c.item.push({name: 'Shorthand', request: 'https://example.invalid'});
  const result = prepare(c);
  assert.equal(result.report.requestCount, 3); assert.equal(result.prepared.item[2].request.method, 'GET');
  assert.ok(!JSON.stringify(result.report.requests).includes('form'));
  assert.ok(!JSON.stringify(result.prepared).includes('{{disabled}}'));
  assert.ok(result.report.notices.some(n => n.includes('unsupported body')));
});
test('CLI requires explicit selection and exact environment identity; bad selection creates no output', () => {
  const f = files(); const out = path.join(f.dir, 'no-output');
  for (const extras of [[], ['--select', 'unknown'], ['--select', 'base', '--select', 'base']]) {
    const result = cli(f, [...extras, '--out-dir', out], 'prepare');
    assert.equal(result.status, 1); assert.equal(result.stdout, ''); assert.equal(fs.existsSync(out), false);
  }
  const wrong = cli({...f, e: {...f.e, name: 'Wrong'}});
  assert.match(wrong.stderr, /name does not match/);
  assert.throws(() => parseArgs(['inspect', '--wat']), /Unknown/);
});
test('CLI refuses existing output directory, source file and symlink without modifying any bytes', () => {
  const f = files(); const before = fs.readFileSync(f.collection); const out = path.join(f.dir, 'existing');
  fs.mkdirSync(out); fs.writeFileSync(path.join(out, 'keep.txt'), 'DO NOT CHANGE');
  const link = path.join(f.dir, 'alias'); fs.symlinkSync(f.collection, link);
  for (const target of [out, f.collection, link]) {
    const result = cli(f, ['--select', 'base', '--out-dir', target], 'prepare');
    assert.equal(result.status, 1); assert.match(result.stderr, /EEXIST/);
    assert.deepEqual(fs.readFileSync(f.collection), before);
  }
  assert.equal(fs.readFileSync(path.join(out, 'keep.txt'), 'utf8'), 'DO NOT CHANGE');
});
test('invalid collection and environment structures fail closed before output', () => {
  const cases = [c => c.info.schema = 'https://invalid/schema', c => c.item = {}, c => c.item[0].name = 'bad\nname', c => c.item[0].request.url = 'file:///tmp/x', c => c.item[0].request.url = 'https://u:p@example.invalid/', c => c.item[0].request.url = {host: ['x']}, c => c.item[0].request.header = 'X: raw', c => c.item[0].request.header = [{key: 'X', value: 'a\r\nInjected: yes'}], c => c.item[0].request.body = {mode: 'raw', raw: {}}, c => c.item[0].item = [], c => c.item = [{name: 'A/B', item: []}]];
  for (const mutate of cases) { const c = base(); mutate(c); assert.throws(() => prepare(c)); }
  assert.throws(() => prepare(base(), {...env(), values: [{key: 'base', value: 1, enabled: 'false'}]}), /enabled must be boolean/);
  assert.throws(() => prepare(base(), {...env(), _postman_variable_scope: 'globals'}), /environment export/);
  const f = files(); fs.writeFileSync(f.environment, Buffer.from([0x7b, 0xff, 0x7d]));
  assert.match(cli(f).stderr, /UTF-8 JSON/);
});
test('bounded item and folder counts reject excess input without executing anything', () => {
  const c = base(); c.item = Array.from({length: 2001}, () => ({name: 'Empty', item: []}));
  assert.throws(() => prepare(c), /2,000/);
  let nested = {name: 'F', item: []}; for (let i = 0; i < 33; i++) nested = {name: 'F', item: [nested]};
  c.item = [nested]; assert.throws(() => prepare(c), /32 levels/);
  assert.throws(() => prepare(base(), env(Array.from({length: 2001}, () => ({key: 'x', value: 1})))), /2,000/);
});
test('synthetic shipped fixture runs through the actual guarded CLI and preserves scoped chat model', () => {
  const f = files(JSON.parse(fs.readFileSync(path.join(ROOT, 'examples/postman/model-library.postman_collection.json'))), JSON.parse(fs.readFileSync(path.join(ROOT, 'examples/postman/local.postman_environment.json'))));
  const out = path.join(f.dir, 'example');
  const inspect = success(cli(f)); assert.equal(inspect.bindings.find(b => b.key === 'model').selectable, false);
  success(cli(f, ['--select', 'baseUrl', '--select', 'trace', '--out-dir', out], 'prepare'));
  const result = JSON.parse(fs.readFileSync(path.join(out, 'prepared.postman_collection.json')));
  assert.equal(result.item[0].item[2].variable[0].value, 'fixture-chat');
  assert.equal(result.variable.find(v => v.key === 'baseUrl').value, 'https://local.example.invalid/v1');
  assert.ok(!JSON.stringify(result).includes('SYNTHETIC_TOKEN'));
  assert.ok(!JSON.stringify(result).includes('SYNTHETIC_SCRIPT'));
});
test('source-contract only: unchanged native converter consumes prepared fields and CLI dispatch; not native interoperability', () => {
  const native = fs.readFileSync(path.join(ROOT, 'postman_collection.mbt'), 'utf8');
  const command = fs.readFileSync(path.join(ROOT, 'cmd/main/cmd_postman.mbt'), 'utf8');
  assert.match(native, /fn gate_pm_scope\(parent/);
  assert.match(native, /variables\[name\] = gate_oas_field\(variable, "value"\)/);
  assert.match(native, /source: gate_pm_scope\(entry.variables, gate_oas_field\(request, "url"\)\)/);
  assert.match(native, /"pm_" \+ \(index \+ 1\).to_string\(\)/);
  assert.match(command, /@moongate.moongate_postman_collection_json/);
  assert.match(command, /parse_string_arg\(args, "--file"\)/);
  const source = fs.readFileSync(CLI, 'utf8');
  const imports = [...source.matchAll(/require\('([^']+)'\)/g)].map(m => m[1]);
  assert.deepEqual(imports, ['node:fs', 'node:path', 'node:crypto', 'node:util']);
  assert.doesNotMatch(source, /\b(?:fetch|eval|spawn|execSync|execFile|connect)\s*\(/);
});
test('recognizable embedded credential defaults are blocked, including ordinary variable names', () => {
  const e = env([{key: 'base', value: 'https://user:PRIVATE@example.invalid'}]);
  assert.equal(prepare(base(), e).report.bindings[0].state, 'embedded-credentials');
  assert.throws(() => prepare(base(), e, ['base']), /unavailable or unsafe/);
  assert.throws(() => parseArgs(['prepare', '--collection', 'a', '--environment', 'b', '--environment-name', 'n', '--select', 'x', '--out-dir', 'new', '--show-values']), /only supported by inspect/);
});
test('disabled and duplicate secret names remain in sensitive diagnostics without their values', () => {
  const e = env([{key: 'apiKey', value: 'A'}, {key: 'apiKey', value: 'B'}, {key: 'ordinary', value: 'C', type: 'secret', enabled: false}]);
  assert.deepEqual(prepare(base(), e).report.sensitiveNames, ['apiKey', 'ordinary']);
});
test('malformed placeholders fail before output in every supported text field (R615-01)', () => {
  const fields = [
    (r, text) => r.url = 'https://fixture.invalid/' + text,
    (r, text) => r.url = 'https://fixture.invalid/?q=' + text,
    (r, text) => r.url = {raw: 'https://fixture.invalid/', query: [{key: 'q', value: text}]},
    (r, text) => r.url = {raw: 'https://fixture.invalid/', query: [{key: text, value: 'q'}]},
    (r, text) => r.header = [{key: 'X-Label', value: text}],
    (r, text) => r.body = {mode: 'raw', raw: text}
  ];
  for (const field of fields) {
    for (const malformed of ['{{{model}}}', '{{m}odel}}', '{{outer{{model}}', '{{model}', '{{}}']) {
      const c = base(); field(c.item[0].request, malformed);
      assert.throws(() => prepare(c, env(), ['model']), /Malformed or nested placeholder/);
    }
    const c = base(); field(c.item[0].request, '{{{model}}}');
    const f = files(c); const out = path.join(f.dir, 'rejected');
    const result = cli(f, ['--select', 'model', '--out-dir', out], 'prepare');
    assert.equal(result.status, 1); assert.match(result.stderr, /Malformed or nested placeholder/);
    assert.equal(fs.existsSync(out), false); assert.equal(result.stdout, '');
  }
});
test('valid placeholders alongside JSON braces retain native name boundaries (R615-01)', () => {
  const c = base(); c.item[0].request.body = {mode: 'raw', raw: '{"outer":{"model":{{model}}}}'};
  const result = prepare(c, env(), ['model']);
  assert.equal(result.prepared.item[0].request.body.raw, c.item[0].request.body.raw);
  assert.equal(result.report.unresolved.length, 0);
  assert.deepEqual(result.report.requests[0].references.map(r => r.key), ['base', 'model']);
});
test('own empty or untyped auth objects preserve request and folder reset semantics (R615-02)', () => {
  for (const auth of [{}, {type: ''}, {type: false}, {type: 123}, {type: []}, {type: null}, {bearer: [{key: 'token', value: 'PRIVATE_RESET_MARKER'}]}, {type: 'noauth'}]) {
    const c = base(); c.auth = {type: 'bearer', bearer: [{key: 'token', value: 'PRIVATE_ROOT_MARKER'}]};
    c.item[0].request.auth = auth;
    c.item.push({name: 'Folder', auth, item: [{name: 'Child', request: {method: 'GET', url: '{{base}}/{{model}}'}}]});
    const expected = auth.type === 'noauth' ? {type: 'noauth'} : {};
    const result = prepare(c, env(), ['model']);
    assert.deepEqual(result.prepared.auth, {type: 'bearer'});
    assert.deepEqual(result.prepared.item[0].request.auth, expected);
    assert.deepEqual(result.prepared.item[1].auth, expected);
    assert.equal(result.prepared.item[1].item[0].request.auth, undefined);
    assert.ok(!JSON.stringify(result.prepared).includes('PRIVATE_'));
  }
  for (const auth of [null, undefined]) {
    const c = base();
    if (auth !== undefined) c.item[0].request.auth = auth;
    assert.equal(prepare(c).prepared.item[0].request.auth, undefined);
  }
});
test('real CLI retains explicit auth resets and strips helper values in the prepared collection (R615-02)', () => {
  const c = base(); c.auth = {type: 'bearer', bearer: [{key: 'token', value: 'AUTH_SECRET_MARKER'}]};
  c.item[0].request.auth = {};
  c.item.push({name: 'Folder', auth: {type: false}, item: [{name: 'Child', request: {method: 'GET', url: '{{base}}', auth: {type: 'noauth'}}}]});
  const f = files(c); const out = path.join(f.dir, 'auth-reset');
  success(cli(f, ['--select', 'base', '--out-dir', out], 'prepare'));
  const result = JSON.parse(fs.readFileSync(path.join(out, 'prepared.postman_collection.json')));
  assert.deepEqual(result.item[0].request.auth, {});
  assert.deepEqual(result.item[1].auth, {});
  assert.deepEqual(result.item[1].item[0].request.auth, {type: 'noauth'});
  assert.ok(!JSON.stringify(result).includes('AUTH_SECRET_MARKER'));
});
