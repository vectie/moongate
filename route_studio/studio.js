/* User-operated offline authoring for the existing native route-plan contract. */
(() => {
'use strict';
const labels = ['sourceProviderId','sourceModel','targetProviderId','targetModel'];
const rates = ['inputUsdPerMillion','outputUsdPerMillion'];
const fields = [...labels, ...rates];
const clone = x => JSON.parse(JSON.stringify(x));
function require(ok, message) {if(!ok) throw Error(message);}
// This importer reads only canonical usage identity/coverage, never request
// payloads or rates. Native rehearsal remains responsible for usage validation.
function inspectUsage(text) {
 require(typeof text === 'string' && new TextEncoder().encode(text).length <= 4*1024*1024, 'Usage JSON exceeds 4 MiB.');
 const usage = JSON.parse(text);
 require(usage && typeof usage === 'object' && !Array.isArray(usage) && usage.schema === 'moongate.usage-file.v1', 'Paste a canonical moongate.usage-file.v1 JSON export.');
 require(!Object.hasOwn(usage,'usageEvidenceKind') && !Object.hasOwn(usage,'usageScenarioName'), 'Use original recorded usage, not a hypothetical scenario.');
 require(Array.isArray(usage.data) && usage.data.length <= 10000, 'Usage data must contain at most 10,000 rows.');
 require(Number.isSafeInteger(usage.sourceTotal) && usage.sourceTotal >= usage.data.length && usage.sourceTotal <= 2147483647, 'Usage sourceTotal must be a whole number between the imported row count and 2147483647.');
 for (const key of ['partial','sourceCoverageUnknown']) require(!Object.hasOwn(usage,key) || typeof usage[key] === 'boolean', 'Usage '+key+' must be true or false.');
 const pairs = new Map(); let missing = 0;
 for (const row of usage.data) {
  require(row && typeof row === 'object' && !Array.isArray(row), 'Every usage row must be an object.');
  const provider = row.providerId, model = row.model;
  if (typeof provider !== 'string' || !provider.trim() || provider === 'Unknown' || typeof model !== 'string' || !model.trim() || model === 'Unknown') { missing++; continue; }
  const key = JSON.stringify([provider,model]);
  if (!pairs.has(key)) pairs.set(key,{sourceProviderId:provider,sourceModel:model,count:0});
  pairs.get(key).count++;
 }
 return {pairs:[...pairs.values()], observed:usage.data.length, sourceTotal:usage.sourceTotal, missing,
  partial:usage.partial === true || usage.sourceCoverageUnknown === true || usage.sourceTotal > usage.data.length,
  coverageUnknown:usage.sourceCoverageUnknown === true};
}
function validate(plan) {
 require(plan && typeof plan === 'object' && !Array.isArray(plan), 'Expected a route-plan object.');
 require(Object.keys(plan).every(k => ['schema','currency','name','routes'].includes(k)), 'Unsupported route-plan field.');
 require(plan.schema === 'moongate.usage-route-plan.v1' && plan.currency === 'USD', 'Expected a USD moongate.usage-route-plan.v1 plan.');
 require(typeof plan.name === 'string' && plan.name.trim(), 'Enter a scenario name.');
 require(Array.isArray(plan.routes) && plan.routes.length <= 1000, 'At most 1000 mappings are supported.');
 const sources = new Set(), targets = new Map();
 for (const row of plan.routes) {
  require(row && typeof row === 'object' && !Array.isArray(row) && Object.keys(row).every(k => fields.includes(k)), 'Unsupported mapping field.');
  for(const field of labels) require(typeof row[field] === 'string' && row[field].trim(), 'Enter ' + field + '.');
  require(row.sourceProviderId !== 'Unknown', 'Unknown is reserved for missing provider labels.');
  for(const field of rates) require(typeof row[field] === 'number' && Number.isFinite(row[field]) && row[field] >= 0 && row[field] <= Number.MAX_SAFE_INTEGER, 'Enter a finite nonnegative rate for ' + field + '.');
  const source = JSON.stringify([row.sourceProviderId,row.sourceModel]);
  require(!sources.has(source), 'A source provider/model can have only one mapping.'); sources.add(source);
  const target = JSON.stringify([row.targetProviderId,row.targetModel]), price = JSON.stringify(rates.map(k => row[k]));
  require(!targets.has(target) || targets.get(target) === price, 'Use matching rates for the same target provider/model.'); targets.set(target,price);
 }
 require(new TextEncoder().encode(JSON.stringify(plan)).length <= 4*1024*1024, 'Plan exceeds 4 MiB.');
 return clone(plan);
}
function editor() {
 let plan = {schema:'moongate.usage-route-plan.v1', currency:'USD', name:'My route scenario', routes:[]}, history=[];
 function commit(next) {const checked=validate(next); history.push(clone(plan)); if(history.length>20) history.shift(); plan=checked;}
 return {snapshot:()=>clone(plan), load:text=>commit(JSON.parse(text)),
 save:(index,row,name)=>{const next=clone(plan);next.name=name;require(index===null || Number.isInteger(index)&&index>=0&&index<next.routes.length,'Choose an existing mapping.'); if(index===null)next.routes.push(row);else next.routes[index]=row;commit(next);},
 remove:index=>{require(Number.isInteger(index)&&index>=0&&index<plan.routes.length,'Select a mapping to remove.');const next=clone(plan);next.routes.splice(index,1);commit(next);},
 undo:()=>{require(history.length,'Nothing to undo.');plan=history.pop();}, canUndo:()=>history.length>0,
 download:name=>{const next=clone(plan);next.name=name;return JSON.stringify(validate(next),null,2)+'\n';}};
}
function mount(document) {
 const get=id=>document.getElementById(id), state=editor();let selected=null, observed=null;
 function pending() {const row=selected===null?{}:state.snapshot().routes[selected]; return fields.some(k => {const raw=get(k).value;return selected===null ? raw!=='' : labels.includes(k) ? raw!==row[k] : raw.trim()==='' || Number(raw)!==row[k];});}
 function selection() {const row=selected===null?{}:state.snapshot().routes[selected];for(const k of fields)get(k).value=String(row[k]??'');get('remove').disabled=selected===null;}
 function render() {
  const plan=state.snapshot(); get('name').value=plan.name;
  const select=get('mapping');select.replaceChildren();
  const option=document.createElement('option');option.value='';option.textContent='New mapping';select.appendChild(option);
  plan.routes.forEach((row,i)=>{const o=document.createElement('option');o.value=String(i);o.textContent=`${row.sourceProviderId} / ${row.sourceModel} → ${row.targetProviderId} / ${row.targetModel}`;select.appendChild(o);});
  select.value=selected===null?'':String(selected);get('preview').textContent=JSON.stringify(plan.routes,null,2);get('undo').disabled=!state.canUndo();selection();
 }
 function action(fn,message){try{fn();render();get('message').textContent=message;}catch(e){get('message').textContent=e.message;}}
 get('mapping').addEventListener('change',()=>{selected=get('mapping').value===''?null:Number(get('mapping').value);selection();});
 get('new').addEventListener('click',()=>{selected=null;get('mapping').value='';selection();});
 get('save').addEventListener('click',()=>action(()=>{const row={};for(const k of labels)row[k]=get(k).value;for(const k of rates){const value=get(k).value.trim();require(/^(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/.test(value),'Enter a numeric rate for '+k+'.');row[k]=Number(value);}state.save(selected,row,get('name').value);if(selected===null)selected=state.snapshot().routes.length-1;},'Mapping saved locally.'));
 get('remove').addEventListener('click',()=>action(()=>{state.remove(selected);selected=null;},'Mapping removed locally.'));
 get('undo').addEventListener('click',()=>action(()=>{state.undo();selected=null;},'Previous plan restored.'));
 get('import').addEventListener('click',()=>action(()=>{state.load(get('import-text').value);selected=null;},'Plan loaded. Review the mappings and rates.'));
 function clearUsage(message) {observed=null;get('usage-pair').replaceChildren();get('use-usage-pair').disabled=true;get('usage-summary').textContent=message;}
 get('usage-text').addEventListener('input',()=>clearUsage('Usage text changed. Load it again to select an observed pair. Saved mappings are unchanged.'));
 get('load-usage').addEventListener('click',()=>{
  try {
   const next=inspectUsage(get('usage-text').value);clearUsage('');observed=next;
   const placeholder=document.createElement('option');placeholder.value='';placeholder.textContent='Choose an observed source pair';get('usage-pair').appendChild(placeholder);
   next.pairs.forEach((pair,i)=>{const option=document.createElement('option');option.value=String(i);option.textContent=JSON.stringify(pair.sourceProviderId)+' / '+JSON.stringify(pair.sourceModel)+' ('+pair.count+' observed rows)';get('usage-pair').appendChild(option);});
   get('usage-pair').value='';get('use-usage-pair').disabled=!next.pairs.length;
   get('usage-summary').textContent=`Loaded ${next.observed} observed rows; sourceTotal ${next.sourceTotal}. ${next.pairs.length} exact source pairs. ${next.missing} rows have missing, non-text, blank or Unknown labels and cannot seed mappings. `+(next.coverageUnknown?'Source coverage is unknown; counts describe only this imported file. ':next.partial?'Partial source: counts describe only the imported rows. ':'Counts describe only this imported file. ')+ 'No token, price, health or route eligibility validation was performed. Targets and rates remain your explicit assumptions.';
  } catch(e) {clearUsage(e.message+' Saved mappings are unchanged.');}
 });
 get('use-usage-pair').addEventListener('click',()=>{
  try {
   require(observed,'Load original recorded usage first.');
   const value=get('usage-pair').value,index=Number(value);
   require(value!=='' && Number.isInteger(index) && index>=0 && index<observed.pairs.length,'Choose an observed source pair.');
   require(!pending(),'Save mapping edits or choose New mapping to discard them before selecting an observed pair.');
   const pair=observed.pairs[index], existing=state.snapshot().routes.findIndex(row=>row.sourceProviderId===pair.sourceProviderId && row.sourceModel===pair.sourceModel);
   selected=existing<0?null:existing;get('mapping').value=selected===null?'':String(selected);selection();
   get('sourceProviderId').value=pair.sourceProviderId;get('sourceModel').value=pair.sourceModel;
   get('message').textContent=existing<0?'Observed source pair selected. Enter target labels and your rate assumptions, then save.':'This source pair already has a mapping. Its saved fields are selected for review.';
  } catch(e) {get('message').textContent=e.message;}
 });
 get('download').addEventListener('click',()=>{try{require(!pending(),'Save mapping edits or choose New mapping to discard them before downloading.');const blob=new Blob([state.download(get('name').value)],{type:'application/json'});const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='moonGate-route-plan.json';document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),0);get('message').textContent='Saved mappings downloaded. No route activated.';}catch(e){get('message').textContent=e.message;}});
 render();clearUsage('Paste a canonical saved usage JSON export to choose exact observed source pairs.');return state;
}
globalThis.MoonGateRouteStudio=Object.freeze({validate,editor,mount,inspectUsage});
if(typeof document!=='undefined')mount(document);
})();
