#!/usr/bin/env node
'use strict';
// Offline preparation only. Never invokes MoonGate, a shell, scripts or a network client.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {TextDecoder} = require('node:util');
const MAX_BYTES = 4 * 1024 * 1024;
const SCHEMAS = new Set([
  'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
  'https://schema.postman.com/json/collection/v2.1.0/collection.json'
]);
const PRECEDENCE = ['URL variable', 'request item variable', 'nearest folder variable', 'selected environment binding', 'collection variable'];
const WARNING = 'Offline preparation only: no requests, scripts, provider configuration or health checks. This is not complete redaction. Ordinary literals, names, paths and bodies may contain private data. The bundle retains byte-exact original exports, including any secrets they contain; keep it private.';
const object = x => x !== null && typeof x === 'object' && !Array.isArray(x);
const own = (x, k) => Object.prototype.hasOwnProperty.call(x, k);
const safeLine = x => typeof x === 'string' && !/[\x00-\x1f\x7f]/.test(x);
const sensitive = x => /authorization|token|key|cookie|secret|password|credential|passwd/i.test(x);
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const fail = message => { throw new Error(message); };
function line(x, label, nonempty = true) {
  if (!safeLine(x) || (nonempty && !x.length)) fail(`${label} must be a single-line string`);
  return x;
}
function literalState(variable) {
  if (sensitive(variable.key) || variable.type === 'secret' || variable.secret === true || variable.sensitive === true) return 'sensitive';
  if (variable.key.startsWith('$')) return 'dynamic';
  const v = variable.value;
  if (!['string', 'number', 'boolean'].includes(typeof v) || (typeof v === 'number' && !Number.isFinite(v))) return 'non-literal';
  const text = String(v);
  if (!text.length) return 'empty';
  if (!safeLine(text)) return 'multiline-or-control';
  if (text.includes('{{') || text.includes('}}')) return 'nested-placeholder';
  if (/^https?:\/\/[^/]*@/i.test(text)) return 'embedded-credentials';
  return 'literal';
}
function readInput(filename, label) {
  const fd = fs.openSync(filename, 'r');
  try {
    const stat = fs.fstatSync(fd);
    if (!stat.isFile() || stat.size > MAX_BYTES) fail(`${label} must be a regular file of at most 4 MiB`);
    // Read at most MAX_BYTES+1 even if another process grows the file.
    const buffer = Buffer.alloc(MAX_BYTES + 1);
    let length = 0;
    while (length < buffer.length) {
      const n = fs.readSync(fd, buffer, length, buffer.length - length, null);
      if (n === 0) break;
      length += n;
    }
    if (length > MAX_BYTES) fail(`${label} exceeds 4 MiB`);
    const bytes = buffer.subarray(0, length);
    let value;
    try { value = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(bytes)); }
    catch { fail(`${label} must contain valid UTF-8 JSON`); }
    if (!object(value)) fail(`${label} must be a JSON object`);
    return {value, bytes, sha256: hash(bytes)};
  } finally { fs.closeSync(fd); }
}
function arrayField(node, field, label) {
  if (!own(node, field)) return [];
  if (!Array.isArray(node[field])) fail(`${label}.${field} must be an array`);
  return node[field];
}
function environmentBindings(environment, name) {
  if (line(environment.name, 'Environment name') !== name) fail('Environment name does not match --environment-name');
  if (environment._postman_variable_scope !== undefined && environment._postman_variable_scope !== 'environment') fail('Expected a Postman environment export');
  if (!Array.isArray(environment.values) || environment.values.length > 2000) fail('Environment requires a values array with at most 2,000 entries');
  const bindings = environment.values.map((entry, index) => {
    if (!object(entry)) fail(`Environment entry ${index + 1} must be an object`);
    const key = line(entry.key, `Environment entry ${index + 1} key`);
    if (entry.enabled !== undefined && typeof entry.enabled !== 'boolean') fail(`Environment entry ${index + 1} enabled must be boolean`);
    if (entry.disabled !== undefined && typeof entry.disabled !== 'boolean') fail(`Environment entry ${index + 1} disabled must be boolean`);
    const enabled = entry.enabled !== false && entry.disabled !== true;
    return {index: index + 1, key, enabled, sensitive: literalState(entry) === 'sensitive', state: enabled ? literalState(entry) : 'disabled', value: entry.value, applicableRequests: [], shadowedRequests: []};
  });
  const counts = new Map();
  for (const binding of bindings) if (binding.enabled) counts.set(binding.key, (counts.get(binding.key) || 0) + 1);
  for (const binding of bindings) if (binding.enabled && counts.get(binding.key) > 1) binding.state = 'duplicate-enabled-name';
  return bindings;
}
function prepareModel(collection, environment, name, selections = [], showValues = false) {
  if (!object(collection.info) || !SCHEMAS.has(collection.info.schema)) fail('Only Postman Collection v2.1 exports are supported');
  const bindings = environmentBindings(environment, name);
  const selected = new Set(selections);
  if (selected.size !== selections.length) fail('A binding was selected more than once');
  for (const key of selected) {
    const match = bindings.filter(b => b.enabled && b.key === key);
    if (match.length !== 1 || match[0].state !== 'literal') fail(`Selection is unavailable or unsafe: ${JSON.stringify(key)}`);
  }
  const notices = [];
  const requests = [];
  let itemCount = 0;
  function scope(node, parent, label) {
    const effective = new Map(parent);
    const variables = [];
    for (const entry of arrayField(node, 'variable', label)) {
      if (!object(entry)) fail(`${label} variable must be an object`);
      const key = line(entry.key, `${label} variable key`);
      if (entry.disabled !== undefined && typeof entry.disabled !== 'boolean') fail(`${label} variable disabled must be boolean`);
      if (entry.disabled === true) continue;
      const state = literalState(entry);
      const value = state === 'literal' ? entry.value : '';
      variables.push({key, value});
      effective.set(key, {scope: label, state, value});
    }
    return {effective, variables};
  }
  function markers(node, target, label) {
    if (own(node, 'auth') && node.auth !== null) {
      if (!object(node.auth)) fail(`${label} auth must be an object`);
      // Native gate_pm_auth returns any own object, including {}. Keep that
      // reset even when no usable type exists; omission would restore inheritance.
      target.auth = {};
      if (typeof node.auth.type === 'string' && node.auth.type.length) {
        target.auth = {type: line(node.auth.type, `${label} auth type`)};
        if (target.auth.type !== 'noauth') notices.push(`${label}: authentication helper values removed; supply credentials manually`);
      }
    }
    if (arrayField(node, 'event', label).length) {
      // Preserve the converter's inherited-script warning without copying source code.
      target.event = [{listen: 'prerequest', script: {exec: []}}];
      notices.push(`${label}: script code removed; setup may need manual reconstruction`);
    }
  }
  function refs(text, names) {
    // Native rendering splits on {{ then }}, rather than matching an inner
    // balanced token. Reject unsupported names/delimiters instead of reporting
    // an inner name as resolved. Ordinary JSON braces outside tokens stay literal.
    let start = text.indexOf('{{');
    while (start >= 0) {
      const end = text.indexOf('}}', start + 2);
      const name = end < 0 ? '' : text.slice(start + 2, end);
      if (end < 0 || !name.length || /[{}]/.test(name)) fail('Malformed or nested placeholder; use {{name}} with a nonempty brace-free name');
      names.add(name);
      start = text.indexOf('{{', end + 2);
    }
  }
  function request(source, effective, label, entryNumber) {
    if (typeof source === 'string') source = {method: 'GET', url: source};
    if (!object(source)) fail(`${label} requires a request`);
    const method = typeof source.method === 'string' ? source.method.toUpperCase() : '';
    if (!['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS', 'TRACE'].includes(method)) fail(`${label}: unsupported or missing method`);
    const out = {method};
    const names = new Set();
    const url = typeof source.url === 'string' ? {raw: source.url} : source.url;
    if (!object(url)) fail(`${label}: URL requires raw text`);
    const raw = line(url.raw, `${label} raw URL`);
    if (/\s/u.test(raw) || !/^(https?:\/\/|\{\{)/.test(raw)) fail(`${label}: expected HTTP(S) or variable-based raw URL without whitespace`);
    const withoutFragment = raw.split('#')[0];
    const q = withoutFragment.indexOf('?');
    const base = q < 0 ? withoutFragment : withoutFragment.slice(0, q);
    if ((base.split('/')[2] || '').includes('@')) fail(`${label}: URL contains embedded credentials`);
    for (const part of base.split('/')) if (part.startsWith(':') && part.length > 1) names.add(part.slice(1));
    refs(base, names);
    const urlOut = {raw: base};
    const urlScope = scope(url, effective, 'URL variable');
    if (urlScope.variables.length) urlOut.variable = urlScope.variables;
    if (own(url, 'query')) {
      urlOut.query = [];
      for (const query of arrayField(url, 'query', label)) {
        if (!object(query)) fail(`${label}: query entry must be an object`);
        if (query.disabled === true) continue;
        const key = typeof query.key === 'string' ? query.key : '';
        const value = typeof query.value === 'string' ? query.value : '';
        refs(key, names);
        const withheld = sensitive(key) || key.includes('%');
        if (!withheld) refs(value, names);
        else notices.push(`${label}: sensitive/encoded query value withheld`);
        urlOut.query.push({key, value: withheld ? 'REPLACE_ME' : value});
      }
    } else if (q >= 0) {
      const parts = withoutFragment.slice(q + 1).split('&').map(pair => {
        const key = pair.split('=')[0];
        if (sensitive(key) || key.includes('%')) {
          notices.push(`${label}: sensitive/encoded query value withheld`);
          return `${key}=REPLACE_ME`;
        }
        refs(pair, names);
        return pair;
      });
      urlOut.raw += '?' + parts.join('&');
    }
    out.url = urlOut;
    out.header = [];
    for (const header of arrayField(source, 'header', label)) {
      if (!object(header)) fail(`${label}: header entry must be an object`);
      if (header.disabled === true) continue;
      const key = line(header.key, `${label} header name`);
      const value = line(header.value, `${label} header value`, false);
      if (/[: ]/.test(key)) fail(`${label}: invalid header name`);
      if (['host', 'content-length', 'connection', 'transfer-encoding', 'cookie'].includes(key.toLowerCase())) {
        notices.push(`${label}: transport/cookie header omitted`);
        continue;
      }
      if (!sensitive(key)) refs(value, names);
      else notices.push(`${label}: sensitive header value withheld`);
      out.header.push({key, value: sensitive(key) ? 'REPLACE_ME' : value});
    }
    if (source.body !== undefined && source.body !== null) {
      if (!object(source.body)) fail(`${label}: body must be an object`);
      const body = source.body;
      const mode = typeof body.mode === 'string' ? body.mode : '';
      if (body.disabled === true) out.body = {mode, disabled: true};
      else if (mode === 'raw') {
        if (typeof body.raw !== 'string') fail(`${label}: raw body must be a string`);
        out.body = {mode, raw: body.raw};
        refs(body.raw, names);
        if (body.options?.raw?.language === 'json') out.body.options = {raw: {language: 'json'}};
      } else if (mode) {
        out.body = {mode: line(mode, `${label} body mode`)};
        notices.push(`${label}: unsupported body omitted; reconstruct manually`);
      }
    }
    markers(source, out, label);
    const references = [...names].map(key => {
      const value = urlScope.effective.get(key);
      const closer = value && !['collection variable', 'selected environment binding'].includes(value.scope);
      for (const binding of bindings) if (binding.key === key) {
        (closer ? binding.shadowedRequests : binding.applicableRequests).push(entryNumber);
      }
      let state = value?.state || 'missing';
      if (sensitive(key)) state = 'sensitive';
      else if (key.startsWith('$')) state = 'dynamic';
      return {key, scope: value?.scope || null, state, environmentSelected: value?.scope === 'selected environment binding'};
    });
    requests.push({entry: entryNumber, name: label, method, references});
    return out;
  }
  const rootScope = scope(collection, new Map(), 'collection variable');
  for (const binding of bindings) if (selected.has(binding.key) && binding.enabled) {
    rootScope.effective.set(binding.key, {scope: 'selected environment binding', state: 'literal', value: binding.value});
  }
  const prepared = {info: {name: line(collection.info.name, 'Collection name'), schema: collection.info.schema}, variable: rootScope.variables.filter(v => !selected.has(v.key)), item: []};
  for (const binding of bindings) if (selected.has(binding.key) && binding.enabled) prepared.variable.push({key: binding.key, value: binding.value});
  markers(collection, prepared, 'collection');
  function walk(node, out, parent, label, depth) {
    if (depth > 32) fail('Postman folders exceed 32 levels');
    if (!Array.isArray(node.item)) fail(`${label}: collection/folder requires an item array`);
    for (const item of node.item) {
      if (++itemCount > 2000) fail('Postman import is limited to 2,000 items including folders');
      if (!object(item)) fail(`${label}: item must be an object`);
      const itemName = line(item.name, 'Item name');
      const itemLabel = label ? `${label}/${itemName}` : itemName;
      const target = {name: itemName};
      const isFolder = own(item, 'item');
      if (isFolder && (itemName.includes('/') || own(item, 'request'))) fail('Folder names cannot contain /, and items cannot contain both request and item');
      const scoped = scope(item, parent, isFolder ? `folder ${itemLabel}` : 'request item variable');
      if (scoped.variables.length) target.variable = scoped.variables;
      markers(item, target, itemLabel);
      if (isFolder) { target.item = []; walk(item, target.item, scoped.effective, itemLabel, depth + 1); }
      else target.request = request(item.request, scoped.effective, itemLabel, requests.length + 1);
      out.push(target);
    }
  }
  walk(collection, prepared.item, rootScope.effective, '', 0);
  for (const key of selected) if (!bindings.find(b => b.enabled && b.key === key).applicableRequests.length) fail(`Selected binding has no applicable request references: ${JSON.stringify(key)}`);
  const unresolved = requests.flatMap(r => r.references.filter(v => v.state !== 'literal').map(v => ({entry: r.entry, ...v})));
  const report = {
    schema: 'moongate.postman-environment-inspection.v1', environmentName: name,
    collectionName: prepared.info.name, precedence: PRECEDENCE, warning: WARNING,
    selectedBindings: [...selected], requestCount: requests.length,
    bindings: bindings.map(({value, ...binding}) => ({...binding, selectable: binding.state === 'literal' && binding.applicableRequests.length > 0, selected: binding.enabled && selected.has(binding.key), ...(showValues && binding.state === 'literal' ? {value} : {})})),
    requests, unresolved, sensitiveNames: [...new Set([...bindings.filter(b => b.sensitive).map(b => b.key), ...unresolved.filter(v => v.state === 'sensitive').map(v => v.key)])],
    notices: [...new Set(notices)]
  };
  return {prepared, report};
}
function parseArgs(args) {
  const result = {command: 'inspect', selections: [], showValues: false};
  if (args[0] && !args[0].startsWith('--')) result.command = args.shift();
  if (!['inspect', 'prepare'].includes(result.command)) fail('Command must be inspect or prepare');
  const fields = {'--collection': 'collection', '--environment': 'environment', '--environment-name': 'name', '--out-dir': 'outDir'};
  while (args.length) {
    const flag = args.shift();
    if (flag === '--show-values') { result.showValues = true; continue; }
    if (!own(fields, flag) && flag !== '--select') fail(`Unknown option: ${flag}`);
    const value = args.shift();
    if (value === undefined || value.startsWith('--')) fail(`Missing value for ${flag}`);
    if (flag === '--select') result.selections.push(value);
    else {
      if (result[fields[flag]] !== undefined) fail(`Repeated option: ${flag}`);
      result[fields[flag]] = value;
    }
  }
  if (!result.collection || !result.environment || !result.name) fail('Required: --collection FILE --environment FILE --environment-name NAME');
  if (result.command === 'prepare' && (!result.outDir || !result.selections.length)) fail('Preparation requires --out-dir NEW_DIRECTORY and at least one explicit --select NAME');
  if (result.command === 'inspect' && result.outDir) fail('--out-dir is only supported by prepare');
  if (result.command === 'prepare' && result.showValues) fail('--show-values is only supported by inspect');
  return result;
}
function main(args) {
  const options = parseArgs([...args]);
  const collection = readInput(options.collection, 'Collection');
  const environment = readInput(options.environment, 'Environment');
  const {prepared, report} = prepareModel(collection.value, environment.value, options.name, options.selections, options.showValues);
  report.sources = {collection: {sha256: collection.sha256, bytes: collection.bytes.length}, environment: {sha256: environment.sha256, bytes: environment.bytes.length}};
  if (options.command === 'inspect') return report;
  const preparedBytes = Buffer.from(JSON.stringify(prepared, null, 2) + '\n');
  if (preparedBytes.length > MAX_BYTES) fail('Prepared collection exceeds the native converter 4 MiB limit');
  const destination = path.resolve(options.outDir);
  // Exclusive creation blocks existing directories, files, symlinks and input aliases.
  fs.mkdirSync(destination, {mode: 0o700});
  const write = (name, bytes) => fs.writeFileSync(path.join(destination, name), bytes, {flag: 'wx', mode: 0o600});
  write('original.collection.json', collection.bytes);
  write('original.environment.json', environment.bytes);
  write('prepared.postman_collection.json', preparedBytes);
  const provenance = {...report, schema: 'moongate.postman-environment-preparation.v1', complete: true, prepared: {file: 'prepared.postman_collection.json', sha256: hash(preparedBytes), bytes: preparedBytes.length}, originals: {collection: 'original.collection.json', environment: 'original.environment.json'}, nativeInteroperability: 'UNRUN: source-contract checks only; native conversion is a release blocker'};
  // Written last: a missing provenance.json means the bundle is incomplete.
  write('provenance.json', Buffer.from(JSON.stringify(provenance, null, 2) + '\n'));
  return {schema: provenance.schema, complete: true, outputDirectory: destination, prepared: provenance.prepared, sources: report.sources, selectedBindings: report.selectedBindings, unresolved: report.unresolved, warning: WARNING, nativeInteroperability: provenance.nativeInteroperability};
}
if (require.main === module) {
  try { process.stdout.write(JSON.stringify(main(process.argv.slice(2)), null, 2) + '\n'); }
  catch (error) { process.stderr.write(`Postman preparation failed: ${error.message}\n`); process.exitCode = 1; }
}
module.exports = {prepareModel, main, parseArgs, MAX_BYTES};
