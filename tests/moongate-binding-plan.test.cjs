const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(process.env.MOONGATE_TEST_ROOT || path.resolve(__dirname,'..'), 'public/assets/moongate-setup.js'),'utf8');
const fixture = id => ({app:{id,label:id},binding:{installed:true,bound:true,bindingMode:'single',bindingState:'bound',currentProviderId:'old'}, providers:[{id:'new',enabled:true,baseUrl:'https://fixture.invalid',apiKey:'SECRET',modelMapping:{defaultModel:'test'}}]});
function harness() {
 const nodes = new Map(); const element = () => ({children:[],appendChild(n){this.children.push(n)},set innerHTML(v){this.markup=v;this.children=[]}});
 const panel=element(); nodes.set('binding-change-plan',panel);
 const calls=[]; const rows=[fixture('a'),fixture('b')];
 const context=vm.createContext({escapeHtml: x=>String(x), document:{createElement:element}, $:id=>nodes.get(id), firstString:(x,keys,f='')=>keys.map(k=>x?.[k]).find(v=>typeof v==='string')||f,
 rows,calls, selected:'new', showError:e=>{throw e}, endpoints:{appBinding:'/bindings'},
 read:async app=>structuredClone(rows.find(r=>r.app.id===app.id)),
 write:async (_,p)=>{calls.push(p); rows.find(r=>r.app.id===p.appType).binding.currentProviderId=p.providerId;},
 });
 const run=s=>vm.runInContext(s,context);
 run(source); run('bindingRows=rows; selectedBindingProvider=()=>selected; loadBindingRow=app=>read(app); postJson=(...args)=>write(...args)');
 return {run,rows,calls,context,panel,nodes,state:()=>JSON.parse(run('JSON.stringify(bindingPlan)'))};
}
test('stage two exact changes without writing; apply once preserves order and verifies',async()=>{
 const h=harness();h.run("stageBindingChange('a');stageBindingChange('b')");assert.equal(h.calls.length,0);assert.equal(h.state().length,2);
 assert.ok(!JSON.stringify(h.state()).includes('SECRET'));await h.run('applyBindingPlan()');assert.deepEqual(h.calls.map(x=>x.appType),['a','b']);assert.deepEqual(h.state().map(x=>x.status),['applied','applied']);await h.run('applyBindingPlan()');assert.equal(h.calls.length,2);
});
test('staging same app replaces prior draft; discard does not write',()=>{const h=harness();h.run("stageBindingChange('a');stageBindingChange('a')");assert.equal(h.state().length,1);h.run('discardBindingPlan()');assert.equal(h.state().length,0);assert.equal(h.calls.length,0)});
test('fresh configuration drift blocks before write',async()=>{const h=harness();h.run("stageBindingChange('a')");h.rows[0].providers[0].modelMapping.defaultModel='changed';await h.run('applyBindingPlan()');assert.equal(h.calls.length,0);assert.equal(h.state()[0].status,'stale')});
test('manual, missing, disabled, duplicate and unavailable providers cannot stage',()=>{
 for(const modify of [r=>r.binding.bindingMode='manual',r=>r.binding.installed=false,r=>r.providers[0].enabled=false,r=>r.providers.push({...r.providers[0]}),r=>r.warning=true]){const h=harness();modify(h.rows[0]);assert.throws(()=>h.run("stageBindingChange('a')"));assert.equal(h.state().length,0)}
});
test('uncertain write stops wave and reconcile reads without retry',async()=>{const h=harness();h.run("stageBindingChange('a');stageBindingChange('b')");h.context.write=async(_,p)=>{h.calls.push(p);h.rows[0].binding.currentProviderId='new';throw Error('lost acknowledgement')};await h.run('applyBindingPlan()');assert.deepEqual(h.state().map(x=>x.status),['uncertain','staged']);await h.run('applyBindingPlan()');assert.equal(h.calls.length,1);h.run('discardBindingPlan()');assert.equal(h.state().length,1);assert.throws(()=>h.run("stageBindingChange('a')"),/Reconcile/);await h.run('reconcileBindingPlan()');assert.equal(h.state()[0].status,'applied');assert.equal(h.calls.length,1)});
test('failed read-back never calls result verified; recovery requires new staging',async()=>{const h=harness();h.run("stageBindingChange('a')");h.context.write=async(_,p)=>h.calls.push(p);await h.run('applyBindingPlan()');assert.equal(h.state()[0].status,'uncertain');await h.run('reconcileBindingPlan()');assert.equal(h.state()[0].status,'stale');assert.equal(h.calls.length,1)});
test('unavailable reconcile retains uncertainty and disables Apply',async()=>{const h=harness();h.run("stageBindingChange('a')");h.context.write=async()=>{throw Error()};await h.run('applyBindingPlan()');h.context.read=async()=>({...fixture('a'),warning:true});await h.run('reconcileBindingPlan()');assert.equal(h.state()[0].status,'uncertain');assert.equal(h.panel.children.find(x=>x.textContent==='Apply staged changes').disabled,true)});
test('duplicate Apply and ordinary binding mutation are guarded in flight',async()=>{const h=harness();h.run("stageBindingChange('a')");let release;h.context.read=()=>new Promise(r=>release=r);const pending=h.run('applyBindingPlan()');await h.run('applyBindingPlan()');assert.throws(()=>h.run("stageBindingChange('b')"),/Wait/);await assert.rejects(h.run("bindApp('b')"),/Wait/);await assert.rejects(h.run("unbindApp('b')"),/Wait/);release({...fixture('a'),warning:true});await pending;assert.equal(h.calls.length,0)});
test('UI offers staging and plan buttons invoke real controller',async()=>{const h=harness();h.run("stageBindingChange('a')");assert.match(h.run('bindingActions(rows[0])'),/data-binding-action="stage"/);const b=h.panel.children.find(x=>x.textContent==='Apply staged changes');await b.onclick();assert.equal(h.calls.length,1)});

test('legacy direct actions cannot bypass uncertain state for the same app',async()=>{const h=harness();h.run("stageBindingChange('a')");h.context.write=async()=>{throw Error('lost')};await h.run('applyBindingPlan()');await assert.rejects(h.run("bindApp('a')"),/Reconcile/);await assert.rejects(h.run("unbindApp('a')"),/Reconcile/);assert.equal(h.state()[0].status,'uncertain')});

test('shipped dashboard click handler stages from actual app row and mounts controls',()=>{
 const h=harness();h.nodes.delete('binding-change-plan');let listener;
 h.nodes.set('binding-rows',{addEventListener:(type,fn)=>listener=fn,closest:()=>({insertAdjacentElement:(_,panel)=>h.nodes.set(panel.id,panel)})});
 const dashboard=fs.readFileSync(path.join(process.env.MOONGATE_TEST_ROOT || path.resolve(__dirname,'..'),'public/assets/moongate.js'),'utf8');
 const start=dashboard.indexOf('$("binding-rows")?.addEventListener');
 const end=dashboard.indexOf('$("usage-apply")',start);
 h.run(dashboard.slice(start,end));
 listener({target:{closest:()=>({dataset:{app:'a',bindingAction:'stage'}})}});
 assert.equal(h.state()[0].app.id,'a');assert.equal(h.calls.length,0);
 assert.ok(h.nodes.get('binding-change-plan').children.find(n=>n.textContent==='Apply staged changes'));
});
