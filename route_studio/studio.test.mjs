import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const [directory, output, usageOutput, usageInput] = process.argv.slice(2);
const html=readFileSync(directory+'/index.html','utf8'), script=readFileSync(directory+'/studio.js','utf8');
class Element {
  constructor(tag = 'div', attributes = {}) {
    this.tagName = tag.toUpperCase(); this.attributes = attributes; this.dataset = {};
    for (const [name, value] of Object.entries(attributes)) if (name.startsWith('data-')) this.dataset[name.slice(5)] = value;
    this.hidden = 'hidden' in attributes; this.disabled = 'disabled' in attributes;
    this.value = ''; this.children = []; this.handlers = {}; this._text = '';
    const classes = new Set();
    this.classList = {toggle(name, enabled) {enabled ? classes.add(name) : classes.delete(name);}, contains(name) {return classes.has(name);}};
  }
  get textContent() {return this._text + this.children.map(child => child.textContent).join('');}
  set textContent(text) {this._text = String(text); this.children = [];}
  appendChild(child) {this.children.push(child); child.parent = this; return child;}
  replaceChildren(...children) {this._text = ''; this.children = children;}
  setAttribute(name, value) {this.attributes[name] = value;}
  addEventListener(type, handler) {(this.handlers[type] ??= []).push(handler);}
  dispatch(type) {if (!this.disabled) for (const handler of this.handlers[type] ?? []) handler({target: this});}
  click() {this.clicked = true; this.dispatch('click');}
  remove() {if (this.parent) this.parent.children = this.parent.children.filter(child => child !== this);}
}

function adapter(){const byId=new Map(),blobs=[];
 for(const m of html.matchAll(/<([a-z]+)\b([^>]*)>/gi)){const id=m[2].match(/id="([^"]+)"/);if(id)byId.set(id[1],new Element(m[1]));}
 const document={body:new Element(),getElementById:id=>{assert.ok(byId.has(id),id);return byId.get(id);},createElement:tag=>new Element(tag)};
 const context=vm.createContext({document,Blob,TextEncoder,URL:{createObjectURL:b=>{blobs.push(b);return 'blob:fixture';},revokeObjectURL:()=>{}},setTimeout:fn=>fn()});vm.runInContext(script,context);
 const get=id=>document.getElementById(id),click=id=>get(id).click();
 function row(provider,model,target,rate){get('sourceProviderId').value=provider;get('sourceModel').value=model;get('targetProviderId').value='candidate';get('targetModel').value=target;get('inputUsdPerMillion').value=String(rate);get('outputUsdPerMillion').value='2';}
 return {get,click,row,blobs,api:context.MoonGateRouteStudio};}
test('actual controls create edit remove undo import and download a native route plan',async()=>{
 const a=adapter();a.row('recorded','alpha','small',1);a.click('save');assert.match(a.get('preview').textContent,/alpha/);
 a.get('inputUsdPerMillion').value='0.5';a.click('save');a.click('undo');assert.match(a.get('preview').textContent,/"inputUsdPerMillion": 1/);
 a.click('new');a.row('recorded','beta','small',1);a.click('save');a.click('remove');a.click('undo');
 a.get('name').value='Two route rehearsal';a.click('download');const text=await a.blobs[0].text();const plan=JSON.parse(text);assert.equal(plan.routes.length,2);assert.equal(plan.name,'Two route rehearsal');
 writeFileSync(output,text);a.get('import-text').value=text;a.click('import');assert.equal(JSON.parse(a.get('preview').textContent).length,2);
});
test('duplicate sources conflicting target prices and invalid rates preserve last plan',()=>{
 const a=adapter();a.row('recorded','alpha','small',1);a.click('save');const before=a.get('preview').textContent;
 a.click('new');a.row('recorded','alpha','other',1);a.click('save');assert.match(a.get('message').textContent,/only one mapping/);assert.equal(a.get('preview').textContent,before);
 a.row('recorded','beta','small',3);a.click('save');assert.match(a.get('message').textContent,/matching rates/);
 a.get('inputUsdPerMillion').value='';a.click('save');assert.match(a.get('message').textContent,/numeric rate/);
 a.get('import-text').value='{bad';a.click('import');assert.equal(a.get('preview').textContent,before);
});
test('labels are displayed as text and zero rate is retained',()=>{
 const a=adapter();a.row('<img src=x onerror=alert(1)>','月','zero',0);a.click('save');assert.match(a.get('preview').textContent,/<img/);assert.match(a.get('preview').textContent,/"inputUsdPerMillion": 0/);
});

test('download refuses unsaved mapping edits',()=>{const a=adapter();a.row('recorded','alpha','small',1);a.click('save');a.get('inputUsdPerMillion').value='3';a.click('download');assert.equal(a.blobs.length,0);assert.match(a.get('message').textContent,/Save mapping edits/);a.click('new');a.click('download');assert.equal(a.blobs.length,1);});

const usage = (rows, extra={}) => JSON.stringify({schema:'moongate.usage-file.v1',sourceTotal:rows.length,data:rows,...extra});
const loadUsage = (a,text) => {a.get('usage-text').value=text;a.get('usage-text').dispatch('input');a.click('load-usage');};
const chooseUsage = (a,index) => {a.get('usage-pair').value=String(index);a.click('use-usage-pair');};
test('observed usage drives actual mapping controls and native-consumable download without private payloads',async()=>{
 const a=adapter(), input=usage([
  {providerId:'recorded',model:'alpha',inputTokens:1000000,outputTokens:100000,totalCostUsd:5,prompt:'PRIVATE_USAGE_PAYLOAD'},
  {providerId:'recorded',model:'beta',inputTokens:2000000,outputTokens:200000,totalCostUsd:10},
  {providerId:'recorded',model:'alpha',inputTokens:0,outputTokens:0,totalCostUsd:0},
  {providerId:'other',model:'gamma',inputTokens:10,totalCostUsd:3},
  {model:'alpha',inputTokens:1,outputTokens:0}
 ],{sourceTotal:9,sourceCoverageUnknown:true});
 loadUsage(a,input);assert.match(a.get('usage-summary').textContent,/5 observed rows; sourceTotal 9/);assert.match(a.get('usage-summary').textContent,/coverage is unknown/);assert.match(a.get('usage-summary').textContent,/1 rows have missing/);
 assert.match(a.get('usage-pair').children[1].textContent,/alpha.*2 observed rows/);assert.equal(a.get('usage-summary').textContent.includes('PRIVATE_USAGE_PAYLOAD'),false);
 a.get('name').value='Observed route rehearsal';chooseUsage(a,0);assert.equal(a.get('name').value,'Observed route rehearsal');assert.equal(a.get('sourceProviderId').value,'recorded');assert.equal(a.get('sourceModel').value,'alpha');assert.equal(a.get('targetModel').value,'');assert.equal(a.get('inputUsdPerMillion').value,'');
 a.get('targetProviderId').value='candidate';a.get('targetModel').value='small';a.get('inputUsdPerMillion').value='1';a.get('outputUsdPerMillion').value='2';a.click('save');
 chooseUsage(a,1);assert.equal(a.get('sourceModel').value,'beta');assert.equal(a.get('targetProviderId').value,'');
 a.get('targetProviderId').value='candidate';a.get('targetModel').value='small';a.get('inputUsdPerMillion').value='1';a.get('outputUsdPerMillion').value='2';a.click('save');
 chooseUsage(a,0);assert.equal(a.get('mapping').value,'0');assert.equal(a.get('targetModel').value,'small');a.click('download');
 const text=await a.blobs[0].text(), plan=JSON.parse(text);assert.equal(plan.routes.length,2);assert.deepEqual(plan.routes.map(r=>r.sourceModel),['alpha','beta']);assert.equal(text.includes('PRIVATE_USAGE_PAYLOAD'),false);assert.equal(text.includes('inputTokens'),false);
 if(usageOutput)writeFileSync(usageOutput,text);if(usageInput)writeFileSync(usageInput,input+'\n');
});
test('usage inspection preserves exact labels and counts only usable pairs',()=>{
 const a=adapter();const result=a.api.inspectUsage(usage([
  {providerId:' P ',model:'m'}, {providerId:'P',model:'m'}, {providerId:' P ',model:'m'},
  {providerId:'P',model:'M'}, {providerId:'月',model:'<img src=x onerror=alert(1)>'},
  {providerId:'Unknown',model:'m'}, {providerId:'P',model:'Unknown'}, {providerId:'',model:'m'},
  {providerId:7,model:'m'}, {providerId:'P',model:null}, {model:'m'}
 ]));
 assert.equal(result.pairs.length,4);assert.equal(result.pairs[0].sourceProviderId,' P ');assert.equal(result.pairs[0].count,2);assert.equal(result.missing,6);
 loadUsage(a,usage([{providerId:'月',model:'<img src=x onerror=alert(1)>'}]));assert.match(a.get('usage-pair').textContent,/<img/);chooseUsage(a,0);assert.equal(a.get('sourceModel').value,'<img src=x onerror=alert(1)>');
});
test('invalid usage and edited paste clear stale choices without changing saved mappings or edits',()=>{
 const a=adapter();a.row('recorded','alpha','small',1);a.click('save');const before=a.get('preview').textContent;
 loadUsage(a,usage([{providerId:'p',model:'m'}]));a.get('targetModel').value='unsaved';chooseUsage(a,0);assert.match(a.get('message').textContent,/Save mapping edits/);assert.equal(a.get('targetModel').value,'unsaved');
 loadUsage(a,'{broken');assert.equal(a.get('use-usage-pair').disabled,true);assert.equal(a.get('usage-pair').children.length,0);assert.equal(a.get('preview').textContent,before);assert.equal(a.get('targetModel').value,'unsaved');
 loadUsage(a,usage([{providerId:'p',model:'m'}]));a.get('usage-text').value='changed';a.get('usage-text').dispatch('input');assert.equal(a.get('use-usage-pair').disabled,true);assert.match(a.get('usage-summary').textContent,/Load it again/);
 a.click('new');loadUsage(a,usage([{providerId:'p',model:'m'}]));a.click('use-usage-pair');assert.match(a.get('message').textContent,/Choose an observed/);assert.equal(a.get('sourceProviderId').value,'');
});
test('canonical usage importer rejects wrong roots scenarios malformed rows coverage and bounds',()=>{
 const a=adapter(), inspect=a.api.inspectUsage;
 for(const text of ['null','[]','{}','{broken',usage([null]),usage([[]]),usage([1]),usage([],{schema:'other'}),usage([],{usageEvidenceKind:null}),usage([],{usageScenarioName:'scenario'}),usage([],{sourceTotal:-1}),usage([{}],{sourceTotal:0}),usage([],{sourceTotal:1.5}),usage([],{sourceTotal:Number.MAX_SAFE_INTEGER+1}),usage([],{partial:'true'}),usage([],{sourceCoverageUnknown:1}),usage(Array.from({length:10001},()=>({providerId:'p',model:'m'}))), ' '.repeat(4*1024*1024+1)]) assert.throws(()=>inspect(text));
 assert.throws(()=>inspect('月'.repeat(Math.floor(4*1024*1024/3)+1)),/4 MiB/);
 loadUsage(a,usage([]));assert.match(a.get('usage-summary').textContent,/0 exact source pairs/);assert.equal(a.get('use-usage-pair').disabled,true);
 loadUsage(a,usage([{model:'m'}],{partial:true}));assert.match(a.get('usage-summary').textContent,/Partial source/);assert.equal(a.get('use-usage-pair').disabled,true);
});
