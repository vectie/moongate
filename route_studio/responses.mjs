// Offline inspection only. Reference resolution never performs I/O.
const object = x => x !== null && typeof x === 'object' && !Array.isArray(x);
const own = (x, k) => Object.prototype.hasOwnProperty.call(x, k);
const methods = ['get','post','put','patch','delete','head','options','trace'];
export function resolve(root, input, ancestors = [], strict = false) {
  let value = input, refs = [...ancestors];
  while (object(value) && own(value, '$ref')) {
    if (strict && Object.keys(value).some(k => k !== '$ref')) throw Error('Reference siblings are unsupported for comparison.');
    const ref = value.$ref;
    if (typeof ref !== 'string' || !ref.startsWith('#/')) throw Error('Only local #/ JSON Pointer references are supported.');
    if (refs.includes(ref)) throw Error(`Recursive reference: ${ref}`);
    if (refs.length >= 16) throw Error('Reference depth exceeds 16.');
    refs.push(ref); value = root;
    for (const token of ref.slice(2).split('/')) {
      if (/~(?![01])/u.test(token)) throw Error(`Invalid pointer escape: ${ref}`);
      const key = token.replaceAll('~1','/').replaceAll('~0','~');
      if (!object(value) || !own(value, key)) throw Error(`Unresolved local reference: ${ref}`);
      value = value[key];
    }
    if (!object(value)) throw Error(`Reference is not an object: ${ref}`);
  }
  return {value, refs};
}
export function loadSpecification(text) {
  if (typeof text !== 'string' || new TextEncoder().encode(text).length > 4 * 1024 * 1024) throw Error('Use JSON up to 4 MiB.');
  const root = JSON.parse(text);
  if (!object(root) || typeof root.openapi !== 'string' || !/^3\.(0|1)\./.test(root.openapi) || !object(root.paths)) throw Error('Expected OpenAPI 3.0.x or 3.1.x JSON with paths.');
  const operations = [], warnings = [];
  for (const [path, raw] of Object.entries(root.paths)) {
    if (!path.startsWith('/')) continue;
    let item;
    try { item = resolve(root, raw).value; } catch (e) { warnings.push(`${path}: ${e.message}`); continue; }
    if (!object(item)) { warnings.push(`${path}: path item is not an object`); continue; }
    for (const method of methods) if (own(item, method)) {
      if (!object(item[method])) { warnings.push(`${method} ${path}: operation is not an object`); continue; }
      operations.push({path, method, operation: item[method]});
      if (operations.length > 2000) throw Error('At most 2,000 operations are supported.');
    }
  }
  return {root, operations, warnings};
}
export function responseChoices(model, index) {
  const op = model.operations[index];
  if (!op) throw Error('Choose an operation.');
  if (!object(op.operation.responses)) return [];
  return Object.keys(op.operation.responses).filter(k => k === 'default' || /^[1-5](?:\d\d|XX)$/.test(k));
}
export function responseDetail(model, index, status, strict = false) {
  if (!responseChoices(model, index).includes(status)) throw Error('Choose a declared response status.');
  const result = resolve(model.root, model.operations[index].operation.responses[status], [], strict);
  if (!object(result.value)) throw Error('Response is not an object.');
  return {...result, media: object(result.value.content) ? Object.keys(result.value.content) : []};
}
export function inspectResponse(model, index, status, media, strict = false) {
  const response = responseDetail(model, index, status, strict), rows = [], warnings = [];
  const description = typeof response.value.description === 'string' ? response.value.description : '(No response description)';
  const examples = [];
  if (!response.media.length) return {description, rows, warnings: ['No response content is declared.'], examples};
  if (!response.media.includes(media)) throw Error('Choose a declared media type.');
  const content = response.value.content[media];
  if (!object(content)) throw Error('Media entry is not an object.');
  // Examples are annotations outside comparison scope. Their availability
  // affects single-document inspection only, never schema completeness.
  if (!strict && own(content, 'example')) examples.push({name:'Media example', value:content.example});
  if (!strict && object(content.examples)) for (const [name, raw] of Object.entries(content.examples)) {
    try {
      const example = resolve(model.root, raw).value;
      if (!object(example)) throw Error('Example is not an object');
      if (own(example, 'value')) examples.push({name, value:example.value});
      else warnings.push(`${name}: example value unavailable; externalValue is not fetched.`);
    } catch (e) { warnings.push(`${name}: ${e.message}`); }
  }
  function walk(raw, breadcrumb, required, refs, depth) {
    if (rows.length >= 500) { if (!warnings.includes('Schema display stopped at 500 nodes.')) warnings.push('Schema display stopped at 500 nodes.'); return; }
    if (depth > 24) { warnings.push(`${breadcrumb}: schema nesting stopped at 24.`); return; }
    let resolved;
    try { resolved = resolve(model.root, raw, refs, strict); }
    catch (e) { rows.push({breadcrumb, required, warning:e.message}); return; }
    const schema = resolved.value;
    if (typeof schema === 'boolean') { rows.push({breadcrumb, required, type: schema ? 'Any value (boolean schema)' : 'No values (boolean schema)'}); return; }
    if (!object(schema)) { rows.push({breadcrumb, required, warning:'Schema is not an object or boolean.'}); return; }
    const row = {breadcrumb, required, type:schema.type ?? (object(schema.properties) ? 'object (inferred)' : own(schema,'items') ? 'array (inferred)' : '(unspecified)'), refs:resolved.refs.slice(refs.length)};
    if (strict) {
      const known = ['type','properties','required','items','enum','nullable','description','title','example','examples','default'];
      const other = Object.keys(schema).filter(k => !known.includes(k));
      if (other.length) warnings.push(`${breadcrumb}: unsupported comparison declarations: ${other.join(', ')}.`);
      const types = ['null','boolean','object','array','number','integer','string'];
      if (own(schema,'type') && !(typeof schema.type === 'string' ? types.includes(schema.type) : Array.isArray(schema.type) && schema.type.length && schema.type.every(t => types.includes(t)))) warnings.push(`${breadcrumb}: invalid type declaration.`);
      if (own(schema,'nullable') && typeof schema.nullable !== 'boolean') warnings.push(`${breadcrumb}: invalid nullable declaration.`);
      if (own(schema,'enum') && (!Array.isArray(schema.enum) || !schema.enum.length)) warnings.push(`${breadcrumb}: invalid enum declaration.`);
      if (own(schema,'properties') && !object(schema.properties)) warnings.push(`${breadcrumb}: invalid properties declaration.`);
      if (own(schema,'required') && (!Array.isArray(schema.required) || schema.required.some(k => typeof k !== 'string' || !object(schema.properties) || !own(schema.properties,k)))) warnings.push(`${breadcrumb}: required entries without property schemas or invalid required declaration.`);
      row.declaredType = own(schema,'type') ? schema.type : null;
    }
    for (const key of ['description','enum','example','examples','default','nullable','format']) if (own(schema,key)) row[key] = schema[key];
    const unsupported = ['allOf','oneOf','anyOf','not','if','then','else','additionalProperties','$dynamicRef'].filter(k => own(schema,k));
    if (unsupported.length) { row.unsupported = Object.fromEntries(unsupported.map(k => [k,schema[k]])); warnings.push(`${breadcrumb}: ${unsupported.join(', ')} shown as raw declarations; not expanded or validated.`); }
    rows.push(row);
    if (object(schema.properties)) for (const [key, child] of Object.entries(schema.properties)) walk(child, `${breadcrumb} / ${JSON.stringify(key)}`, Array.isArray(schema.required) && schema.required.includes(key), resolved.refs, depth+1);
    if (own(schema,'items')) walk(schema.items, `${breadcrumb} / [items]`, false, resolved.refs, depth+1);
  }
  if (own(content,'schema')) walk(content.schema,'response',false,[],0);
  else warnings.push('No schema is declared for this media type.');
  return {description, rows, warnings, examples};
}

// Compare exact declarations, never response validity or client compatibility.
function selectedOperation(model, method, path) {
  if (!model || !methods.includes(method) || !own(model.root.paths,path)) return {state:'missing-operation'};
  try {
    const item = resolve(model.root,model.root.paths[path],[],true).value;
    if (!object(item)) throw Error('Path item is not an object.');
    if (!own(item,method)) return {state:'missing-operation'};
    if (!object(item[method]) || own(item[method],'$ref')) throw Error('Operation is invalid or uses an unsupported reference.');
    return {state:'ready', model:{root:model.root,operations:[{method,path,operation:item[method]}]}};
  } catch(e) { return {state:'indeterminate',issues:[e.message]}; }
}
export function comparisonChoices(left, right, selection = {}) {
  const operations = new Map(), statuses = new Set(), media = new Set();
  for (const model of [left,right]) {
    for (const op of model?.operations ?? []) operations.set(JSON.stringify([op.method,op.path]),{method:op.method,path:op.path});
    const side = selectedOperation(model,selection.method,selection.path);
    if (side.state !== 'ready') continue;
    for (const status of responseChoices(side.model,0)) statuses.add(status);
    try { for (const type of responseDetail(side.model,0,selection.status,true).media) media.add(type); } catch { /* The result reports the precise blocker. */ }
  }
  return {operations:[...operations.values()],statuses:[...statuses],media:[...media]};
}
function comparisonSide(model, selection) {
  const side = selectedOperation(model,selection.method,selection.path);
  if (side.state !== 'ready') return side;
  if (own(side.model.operations[0].operation,'responses') && !object(side.model.operations[0].operation.responses)) return {state:'indeterminate',issues:['Responses declaration is not an object.']};
  if (!responseChoices(side.model,0).includes(selection.status)) return {state:'missing-status'};
  try {
    const response = responseDetail(side.model,0,selection.status,true);
    if (own(response.value,'content') && !object(response.value.content)) throw Error('Response content is not an object.');
    if (!response.media.includes(selection.media)) return {state:'missing-media',declaredMedia:response.media};
    const detail = inspectResponse(side.model,0,selection.status,selection.media,true);
    const issues = [...detail.warnings,...detail.rows.filter(r => r.warning).map(r => `${r.breadcrumb}: ${r.warning}`)];
    if (issues.length) return {state:'indeterminate',issues};
    return {state:'inspected',rows:detail.rows};
  } catch(e) { return {state:'indeterminate',issues:[e.message]}; }
}
function canonical(value, budget, depth = 0) {
  if (++budget.nodes > 10000 || depth > 24) throw Error('Enum comparison stopped at 10,000 values or 24 nesting levels.');
  if (typeof value === 'number') throw Error('Numeric enum comparison is unsupported because JSON parsing can lose numeric precision, including nested values.');
  if (Array.isArray(value)) return '['+value.map(v => canonical(v,budget,depth+1)).join(',')+']';
  if (object(value)) return '{'+Object.keys(value).sort().map(k => JSON.stringify(k)+':'+canonical(value[k],budget,depth+1)).join(',')+'}';
  return JSON.stringify(value);
}
function declarations(row) {
  const type = own(row,'declaredType') ? row.declaredType : row.type;
  const budget = {nodes:0};
  return {
    required:row.required,
    type:{declared:Array.isArray(type) ? [...new Set(type)].sort() : type,nullable:row.nullable ?? false},
    enum:own(row,'enum') ? [...new Set(row.enum.map(v => canonical(v,budget)))].sort().map(v => JSON.parse(v)) : null,
  };
}
export function compareResponses(left, right, selection) {
  const result = {selection:{...selection},scope:'Declared fields, required, type/nullable and enum only. No compatibility verdict.',left:comparisonSide(left,selection),right:comparisonSide(right,selection),changes:[]};
  if ([result.left,result.right].some(s => s.state === 'indeterminate')) {
    result.outcome = 'indeterminate';
    result.summary = 'Comparison indeterminate. No added/removed or unchanged conclusion is available.';
    return result;
  }
  if ([result.left,result.right].some(s => s.state !== 'inspected')) {
    result.outcome = 'missing-selection';
    result.summary = 'The exact operation, status or media type is missing on one or both sides. No field comparison was made.';
    return result;
  }
  try {
    const before = new Map(result.left.rows.map(r => [r.breadcrumb,declarations(r)]));
    const after = new Map(result.right.rows.map(r => [r.breadcrumb,declarations(r)]));
    for (const path of new Set([...before.keys(),...after.keys()])) {
      if (!before.has(path)) result.changes.push({path,kind:'added-field',after:after.get(path)});
      else if (!after.has(path)) result.changes.push({path,kind:'removed-field',before:before.get(path)});
      else for (const field of ['required','type','enum']) if (JSON.stringify(before.get(path)[field]) !== JSON.stringify(after.get(path)[field])) result.changes.push({path,kind:field+'-changed',before:before.get(path)[field],after:after.get(path)[field]});
    }
    result.outcome = result.changes.length ? 'differences' : 'no-differences-in-inspected-declarations';
    result.summary = result.changes.length ? 'Declared response field differences found.' : 'No differences in inspected field, required, type/nullable and enum declarations. Other contract behavior is not compared.';
  } catch(e) {
    result.changes = [];
    result.outcome = 'indeterminate';
    result.summary = e.message+' Comparison indeterminate.';
  }
  return result;
}
export function installExplorer(document) {
  const get = id => document.getElementById(id);
  let model, comparisonModel;
  const clear = () => { get('response-detail').textContent = ''; get('response-warning').textContent = ''; };
  const options = (id, values) => {
    const select = get(id); select.replaceChildren();
    for (const [value,label] of values) { const option = document.createElement('option'); option.value = value; option.textContent = label; select.appendChild(option); }
    select.value = values.length ? values[0][0] : ''; select.disabled = !values.length;
  };
  const clearComparison = message => {
    get('comparison-detail').textContent = '';
    get('comparison-warning').textContent = message;
  };
  const resetComparison = message => {
    for (const id of ['comparison-operation','comparison-status','comparison-media']) options(id,[]);
    clearComparison(message);
  };
  const selected = () => {
    const [method,path] = JSON.parse(get('comparison-operation').value || '[]');
    return {method,path,status:get('comparison-status').value,media:get('comparison-media').value};
  };
  function renderComparison() {
    clearComparison('');
    if (!model || !comparisonModel) { resetComparison('Load both specifications to compare.'); return; }
    if (!get('comparison-operation').value) { clearComparison(['No selectable operations. Comparison unavailable.',...model.warnings,...comparisonModel.warnings].join('\n')); return; }
    const result = compareResponses(model,comparisonModel,selected());
    get('comparison-detail').textContent = JSON.stringify(result,null,2);
    get('comparison-warning').textContent = result.summary;
  }
  function comparisonStatusChanged() {
    options('comparison-media',comparisonChoices(model,comparisonModel,selected()).media.map(x => [x,x]));
    renderComparison();
  }
  function comparisonOperationChanged() {
    options('comparison-status',comparisonChoices(model,comparisonModel,selected()).statuses.map(x => [x,x]));
    comparisonStatusChanged();
  }
  function refreshComparison() {
    resetComparison('Load both specifications to compare.');
    if (!model || !comparisonModel) return;
    options('comparison-operation',comparisonChoices(model,comparisonModel).operations.map(o => [JSON.stringify([o.method,o.path]),`${o.method.toUpperCase()} ${o.path}`]));
    comparisonOperationChanged();
  }
  const comparisonGuard = fn => () => { try { fn(); } catch(e) { resetComparison('Comparison unavailable: '+e.message); } };
  const guard = fn => () => { try { fn(); } catch(e) { clear(); get('response-warning').textContent = e.message; } };
  function render() {
    clear();
    if (!model || get('response-status').value === '') { get('response-warning').textContent = 'No declared responses for this operation.'; return; }
    const detail = inspectResponse(model, Number(get('response-operation').value),get('response-status').value,get('response-media').value);
    get('response-detail').textContent = JSON.stringify(detail, null, 2);
    get('response-warning').textContent = [...model.warnings,...detail.warnings].join('\n');
  }
  function statusChanged() {
    options('response-media', []); clear();
    if (!model || !get('response-status').value) { render(); return; }
    const response = responseDetail(model, Number(get('response-operation').value), get('response-status').value);
    options('response-media', response.media.map(x => [x,x])); render();
  }
  function operationChanged() {
    options('response-status', []); options('response-media', []); clear();
    if (!model || get('response-operation').value === '') return;
    options('response-status', responseChoices(model,Number(get('response-operation').value)).map(x => [x,x])); statusChanged();
  }
  get('response-load').addEventListener('click', guard(() => {
    model = undefined; resetComparison('Load both specifications to compare.'); options('response-operation',[]); options('response-status',[]); options('response-media',[]); clear();
    model = loadSpecification(get('response-input').value);
    options('response-operation',model.operations.map((o,i) => [String(i),`${o.method.toUpperCase()} ${o.path}${o.operation.operationId ? ' · '+o.operation.operationId : ''}`]));
    refreshComparison();
    operationChanged();
    if (!model.operations.length) get('response-warning').textContent = ['No operations found.',...model.warnings].join('\n');
  }));
  get('response-input').addEventListener('input', () => { model = undefined; resetComparison('Before input changed. Load it again to compare.'); options('response-operation',[]); options('response-status',[]); options('response-media',[]); clear(); get('response-warning').textContent='Input changed. Load the specification again.'; });
  get('response-operation').addEventListener('change',guard(operationChanged));
  get('response-status').addEventListener('change',guard(statusChanged));
  get('response-media').addEventListener('change',guard(render));
  get('comparison-load').addEventListener('click',comparisonGuard(() => {
    comparisonModel = undefined;
    resetComparison('Load both specifications to compare.');
    comparisonModel = loadSpecification(get('comparison-input').value);
    refreshComparison();
  }));
  get('comparison-input').addEventListener('input',() => {
    comparisonModel = undefined;
    resetComparison('After input changed. Load it again to compare.');
  });
  get('comparison-operation').addEventListener('change',comparisonGuard(comparisonOperationChanged));
  get('comparison-status').addEventListener('change',comparisonGuard(comparisonStatusChanged));
  get('comparison-media').addEventListener('change',comparisonGuard(renderComparison));
}
