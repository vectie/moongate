// Actual gateway-served controller and installed allocation event handlers.
// Deterministic DOM and endpoint fixtures, not a browser or live gateway.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {test} = require('node:test');
const root = process.env.MOONGATE_TEST_ROOT || path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'public/assets/moongate-operations.js'), 'utf8');
const plain = v => JSON.parse(JSON.stringify(v));
class Element {
  constructor(tag = 'div') {this.tagName = tag.toUpperCase(); this.children=[]; this.handlers={}; this.value=''; this.checked=false; this.disabled=false; this._text=''; this.attrs={}; this.options=[]; this.classList={toggle(){}};}
  set textContent(v) {this._text=String(v); this.children=[];}
  get textContent() {return this._text+this.children.map(c=>c.textContent).join('');}
  appendChild(e) {this.children.push(e); return e;}
  replaceChildren(...es) {this.children=es; this._text='';}
  setAttribute(k,v) {this.attrs[k]=v;}
  addEventListener(k,h) {(this.handlers[k] ||= []).push(h);}
  async fire(k) {for (const h of this.handlers[k] || []) await h({target:this,preventDefault(){}});}
}
const flatten = e => [e,...e.children.flatMap(flatten)];
async function harness() {
  const ids=['operations-app','routing-policy-form','routing-policy-id','routing-policy-mode','routing-policy-weights','routing-policy-limits','routing-policy-status','routing-policy-observe','routing-policy-activate','routing-policy-rollback','benchmark-run','refresh','operations-monitor-status'];
  const nodes=new Map(ids.map(id=>[id,Object.assign(new Element(),{id})]));
  nodes.get('operations-app').value='codex'; nodes.get('operations-app').options=[1];
  nodes.get('routing-policy-id').value='policy'; nodes.get('routing-policy-mode').value='smooth-weighted-round-robin';
  const get=id => nodes.get(id) || [...nodes.values()].flatMap(flatten).find(e=>e.id===id) || null;
  const state={draft:{policy_id:'policy',revision:1,mode:'smooth-weighted-round-robin',weights:{a:2,retired:5},concurrency_limits:{b:3,retired:4}},shadowDecisionCount:0};
  const requests=[]; const reads=[];
  let responder=null; let reader=null;
  const context=vm.createContext({
    document:{createElement:tag=>new Element(tag)}, $:get,
    frameworkApps:[{id:'codex',label:'Codex'}], frameworkRows:[{id:'codex',providers:[{id:'a',name:'Alpha'},{id:'b',name:'Beta',enabled:false}]}],
    endpoints:{operationsMonitor:'/monitor',routingPolicy:'/policy',routingPolicyConfigure:'/configure',routingPolicyShadow:'/observe',routingPolicyActivate:'/activate',routingPolicyRollback:'/rollback'},
    endpoint:(p,args)=>p+'?appType='+args.appType,
    text:(id,v)=>{if(get(id))get(id).textContent=v;}, number:v=>Number(v)||0, money:String,
    escapeHtml:v=>String(v), firstString:(o,ks,f='-')=>{for(const k of ks)if(typeof o?.[k]==='string')return o[k];return f;},
    safeGetJson:async p=>{reads.push(p);if(reader)return reader(p);return {ok:true,data:p.startsWith('/policy')?plain(state):{}};},
    postJson:async (p,body)=>{requests.push({path:p,body:plain(body)});if(responder)return responder(p,body);
      if(p==='/configure'){state.draft={policy_id:body.policyId,revision:state.draft.revision+1,mode:body.mode,weights:plain(body.weights),concurrency_limits:plain(body.concurrencyLimits)};state.shadowDecisionCount=0;return {policy:plain(state.draft)};}
      if(p==='/observe'){state.shadowDecisionCount++;return plain(state);}throw Error('unexpected action '+p);},
    window:{confirm:()=>{throw Error('activation was not requested');}}
  });
  vm.runInContext(source,context); await new Promise(setImmediate);
  const h={context,get,requests,reads,state,run:s=>vm.runInContext(s,context),responder:f=>responder=f,reader:f=>reader=f};
  h.load=()=>get('routing-allocation-load').fire('click');
  h.preview=()=>get('routing-allocation-preview').fire('click');
  h.save=()=>get('routing-allocation-save').fire('click');
  h.control=(id,kind,checkbox=false)=>flatten(get('routing-allocation-rows')).find(e=>e.attrs['aria-label']===(checkbox?'Override ':'')+kind+' for '+id);
  h.edit=async(id,kind,value)=>{const check=h.control(id,kind,true);check.checked=true;await check.fire('change');const input=h.control(id,kind);input.value=String(value);await input.fire('input');};
  return h;
}
test('actual existing shell contains mounting form and ordinary save/observe controls',()=>{
  const shell=fs.readFileSync(path.join(root,'ui_rabbita_operations.mbt'),'utf8');
  for(const id of ['routing-policy-form','routing-policy-weights','routing-policy-limits','routing-policy-observe'])assert.ok(shell.includes('id="'+id+'"'));
});
test('inventory rows author several overrides, preview exact payload, save ordinary shadow then observe',async()=>{
  const h=await harness(); const beforeReads=h.reads.length; await h.load();
  assert.match(h.get('routing-allocation-rows').textContent,/Alpha \(a\)/);assert.match(h.get('routing-allocation-rows').textContent,/Beta \(b\).*disabled/);
  assert.equal(h.control('b','weight').disabled,true); assert.equal(h.control('a','concurrency cap').disabled,true);
  await h.edit('a','weight',3); await h.edit('b','weight',1);await h.edit('a','concurrency cap',2);
  await h.preview();assert.equal(h.requests.length,0);assert.equal(h.reads.length,beforeReads);
  const expected={appType:'codex',policyId:'policy',mode:'smooth-weighted-round-robin',weights:{a:3,retired:5,b:1},concurrencyLimits:{b:3,retired:4,a:2}};
  assert.deepEqual(JSON.parse(h.get('routing-allocation-payload').textContent),expected);
  await h.save();assert.deepEqual(h.requests,[{path:'/configure',body:expected}]);assert.equal(h.get('routing-allocation-save').disabled,true);
  await h.get('routing-policy-observe').fire('click');assert.equal(h.requests[1].path,'/observe');assert.equal(h.state.shadowDecisionCount,1);
  assert.equal(h.requests.some(r=>/activate|rollback|models|test/.test(r.path)),false);
});
test('explicitly disabling override removes that key and preserves unknown-provider overrides',async()=>{
  const h=await harness();await h.load();let c=h.control('a','weight',true);c.checked=false;await c.fire('change');
  c=h.control('b','concurrency cap',true);c.checked=false;await c.fire('change');await h.preview();
  const p=JSON.parse(h.get('routing-allocation-payload').textContent);assert.deepEqual(p.weights,{retired:5});assert.deepEqual(p.concurrencyLimits,{retired:4});
  assert.match(h.get('routing-allocation-rows').textContent,/retired/);
});
test('invalid integers and bounds refuse preview with no requests',async()=>{
  for(const [kind,value] of [['weight','0'],['weight','1001'],['weight','1e2'],['weight',' 3'],['weight','1.5'],['concurrency cap','-1'],['concurrency cap','2147483648']]){
    const h=await harness();await h.load();await h.edit('a',kind,value);await h.preview();await h.save();assert.equal(h.requests.length,0);assert.equal(h.get('routing-allocation-save').disabled,true);
  }
});
test('zero cap is explicit no policy limit, maximum supported values remain whole integers',async()=>{
  const h=await harness();await h.load();await h.edit('a','weight',1000);await h.edit('b','concurrency cap',0);await h.edit('a','concurrency cap',2147483647);await h.preview();
  const p=JSON.parse(h.get('routing-allocation-payload').textContent);assert.equal(p.concurrencyLimits.b,0);assert.equal(p.weights.a,1000);await h.save();assert.equal(h.requests.length,1);
});
test('changing a row after preview invalidates save and preserves other edited rows',async()=>{
  const h=await harness();await h.load();await h.edit('a','weight',5);await h.preview();await h.edit('b','weight',7);await h.save();assert.equal(h.requests.length,0);
  assert.equal(h.control('a','weight').value,'5');await h.preview();await h.save();assert.equal(h.requests[0].body.weights.b,7);
});
test('policy, form and inventory drift preserve row edits and block saving',async()=>{
  for(const change of [h=>h.get('routing-policy-mode').value='priority',h=>h.run('operationsPolicyState.draft.revision++'),h=>h.run('frameworkRows[0].providers.push({id:"new"})'),h=>h.run('frameworkRows[0].providers[0].enabled=false')]){
    const h=await harness();await h.load();await h.edit('a','weight',7);await h.preview();change(h);await h.save();assert.equal(h.requests.length,0);assert.equal(h.control('a','weight').value,'7');assert.match(h.get('routing-allocation-status').textContent,/changed/);
  }
});
test('app switch and outstanding policy fetch cannot reuse old loaded allocation',async()=>{
  const h=await harness();await h.load();await h.preview();h.get('operations-app').value='claude';h.run('frameworkRows.push({id:"claude",providers:[{id:"c"}]})');await h.save();assert.equal(h.requests.length,0);
  h.reader(()=>new Promise(()=>{}));h.get('operations-app').fire('change');await h.load();assert.match(h.get('routing-allocation-status').textContent,/Wait for/);
});
test('unknown save acknowledgement is held and no repeat is issued automatically',async()=>{
  const h=await harness();await h.load();await h.preview();h.responder(async()=>{throw Error('connection interrupted');});await h.save();await h.save();assert.equal(h.requests.length,1);assert.match(h.get('routing-allocation-status').textContent,/Load allocation rows|not acknowledged/);
});
test('double save and ordinary form submit while saving cannot duplicate write',async()=>{
  const h=await harness();await h.load();await h.preview();let done;h.responder(()=>new Promise(r=>done=r));const pending=h.save();await h.save();await h.get('routing-policy-form').fire('submit');assert.equal(h.requests.length,1);done({policy:{revision:2}});await pending;
});
test('clear is local, reload deliberately replaces edits, and malformed/failed inventories are explicit',async()=>{
  const h=await harness();await h.load();await h.edit('a','weight',7);await h.get('routing-allocation-clear').fire('click');assert.equal(h.get('routing-allocation-rows').children.length,0);assert.equal(JSON.parse(h.get('routing-policy-weights').value).a,2);
  await h.load();assert.equal(h.control('a','weight').value,'2');h.run('frameworkRows[0].error="not loaded"');await h.load();assert.match(h.get('routing-allocation-status').textContent,/unavailable/);assert.equal(h.requests.length,0);
});
test('hostile and prototype provider IDs are literal and exact own map keys',async()=>{
  const h=await harness();h.run('frameworkRows[0].providers=[{id:"__proto__",name:"</script><img src=x>"},{id:"constructor",name:"文字"}]');await h.load();await h.edit('__proto__','weight',4);await h.edit('constructor','concurrency cap',3);await h.preview();
  const p=JSON.parse(h.get('routing-allocation-payload').textContent);assert.equal(p.weights.__proto__,4);assert.equal(p.concurrencyLimits.constructor,3);assert.match(h.get('routing-allocation-rows').textContent,/<img src=x>/);assert.equal(flatten(h.get('routing-allocation-rows')).some(e=>e.tagName==='IMG'),false);await h.save();assert.equal(h.requests[0].body.weights.__proto__,4);
});
test('out-of-order policy responses cannot overwrite newly selected app',async()=>{
  const h=await harness();let old;h.reader(p=>p.includes('codex')?new Promise(r=>old=r):Promise.resolve({ok:true,data:p.startsWith('/policy')?{draft:{policy_id:'claude-policy',revision:4,weights:{},concurrency_limits:{}}}:{}}));
  const a=h.run('loadOperations()');h.get('operations-app').value='claude';const b=h.run('loadOperations()');await b;old({ok:true,data:{draft:{policy_id:'wrong',revision:99}}});await a;assert.equal(h.get('routing-policy-id').value,'claude-policy');
});

test('discarded row controls cannot mutate replacement draft or clear its preview',async()=>{
  const h=await harness();await h.load();const oldInput=h.control('a','weight'),oldCheck=h.control('b','weight',true);
  await h.get('routing-allocation-clear').fire('click');await h.load();await h.edit('a','weight',9);await h.preview();
  const preview=h.get('routing-allocation-payload').textContent;oldInput.value='8';await oldInput.fire('input');oldCheck.checked=true;await oldCheck.fire('change');
  assert.equal(h.get('routing-allocation-payload').textContent,preview);assert.equal(h.get('routing-allocation-save').disabled,false);
  await h.save();assert.equal(h.requests[0].body.weights.a,9);assert.equal('b' in h.requests[0].body.weights,false);
});
test('successful reload clears previous exact payload; failed reload retains original draft and preview',async()=>{
  const h=await harness();await h.load();await h.edit('a','weight',9);await h.preview();assert.ok(h.get('routing-allocation-payload').textContent);
  h.run('frameworkRows[0].error="failed read"');await h.load();assert.ok(h.get('routing-allocation-payload').textContent);assert.equal(h.control('a','weight').value,'9');
  h.run('delete frameworkRows[0].error');await h.load();assert.equal(h.get('routing-allocation-payload').textContent,'');assert.equal(h.get('routing-allocation-save').disabled,true);
});
