import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {loadSpecification,resolve,responseChoices,responseDetail,inspectResponse,installExplorer,comparisonChoices,compareResponses} from './responses.mjs';
function fixture() {
 const f = {openapi:'3.1.0',paths:{},components:{responses:{},examples:{Name:{value:'東京'}},schemas:{}}};
 f.paths['/models'] = {
  get:{operationId:'list',responses:{200:{$ref:'#/components/responses/Good'},204:{description:'No content'},default:{description:'Failure',content:{'text/plain':{schema:{type:'string'}}}}}},
  post:{responses:{201:{description:'Made',content:{'application/json':{schema:{type:'boolean'}}}}}}
 };
 f.components.responses.Good={description:'A model',content:{'application/json':{schema:{$ref:'#/components/schemas/A~1B~0'},example:false,examples:{zero:{value:0},named:{$ref:'#/components/examples/Name'}}},'text/plain':{schema:{type:'string'}}}};
 f.components.schemas['A/B~']={type:'object',required:['id'],properties:{id:{type:'string',enum:['001','002'],example:'001'},items:{type:'array',items:{type:'number'}},next:{$ref:'#/components/schemas/A~1B~0'}}};
 return f;
}
const model = () => loadSpecification(JSON.stringify(fixture()));
test('operation response and media selection, refs, fields, required, enums, examples and recursion',()=>{
 const m=model(); assert.equal(m.operations.length,2); assert.deepEqual(responseChoices(m,0),['200','204','default']);
 assert.deepEqual(responseDetail(m,0,'200').media,['application/json','text/plain']);
 const d=inspectResponse(m,0,'200','application/json');
 const id=d.rows.find(r=>r.breadcrumb==='response / "id"'); assert.equal(id.required,true); assert.deepEqual(id.enum,['001','002']); assert.equal(id.example,'001');
 assert.equal(d.rows.find(r=>r.breadcrumb.endsWith('[items]')).type,'number');
 assert.match(d.rows.at(-1).warning,/Recursive/); assert.deepEqual(d.examples.map(e=>e.value),[false,0,'東京']);
 assert.deepEqual(inspectResponse(m,0,'204','').rows,[]); assert.equal(inspectResponse(m,0,'default','text/plain').rows[0].type,'string');
});
test('refs are own object pointers and never remote, array, malformed, missing or inherited traversal',()=>{
 for (const ref of ['https://invalid/schema','#/missing','#/x/0','#/bad~2','#/toString']) assert.throws(()=>resolve({x:[{}]},{$ref:ref}));
 assert.equal(resolve({x:{type:'string'}},{$ref:'#/x',type:'number'}).value.type,'string');
 const root={}; for(let i=0;i<18;i++)root['a'+i]={$ref:'#/a'+(i+1)}; assert.throws(()=>resolve(root,root.a0),/depth/);
});
test('unsupported composition remains raw and boolean schemas remain honest',()=>{
 const f=fixture(); f.components.schemas['A/B~']={allOf:[{type:'object'}],properties:{yes:true,no:false}};
 const d=inspectResponse(loadSpecification(JSON.stringify(f)),0,'200','application/json');
 assert.deepEqual(d.rows[0].unsupported.allOf,[{type:'object'}]); assert.match(d.warnings.join(),/not expanded/); assert.match(d.rows[1].type,/Any/); assert.match(d.rows[2].type,/No values/);
});
test('invalid documents and selection reject without a substitute response',()=>{
 for(const input of ['no','null','{}','{"openapi":"2.0","paths":{}}','x'.repeat(4*1024*1024+1)]) assert.throws(()=>loadSpecification(input));
 assert.throws(()=>inspectResponse(model(),1,'200','application/json')); assert.throws(()=>inspectResponse(model(),0,'200','image/png'));
 const f=fixture(); f.paths['/models'].get.responses={200:{$ref:'#/missing'}}; assert.throws(()=>responseDetail(loadSpecification(JSON.stringify(f)),0,'200'),/Unresolved/);
});
test('bounded display and input limits do not silently claim completeness',()=>{
 const f=fixture(); f.components.schemas['A/B~']={properties:Object.fromEntries(Array.from({length:600},(_,i)=>['x'+i,{type:'string'}]))};
 const d=inspectResponse(loadSpecification(JSON.stringify(f)),0,'200','application/json'); assert.equal(d.rows.length,500); assert.match(d.warnings.join(),/stopped/);
 const tooMany={openapi:'3.0.3',paths:Object.fromEntries(Array.from({length:2001},(_,i)=>['/'+i,{get:{responses:{}}}]))}; assert.throws(()=>loadSpecification(JSON.stringify(tooMany)),/2,000/);
});
test('invalid schema and external example warnings preserve usable response metadata',()=>{
 const f=fixture(); f.components.responses.Good.content['application/json']={schema:{$ref:'https://invalid'},examples:{remote:{externalValue:'https://invalid'}}};
 const d=inspectResponse(loadSpecification(JSON.stringify(f)),0,'200','application/json'); assert.equal(d.description,'A model'); assert.match(d.rows[0].warning,/Only local/); assert.match(d.warnings.join(),/not fetched/);
});
class Element {
 constructor(){this.children=[];this.handlers={};this.value='';this.disabled=false;this.textContent='';}
 replaceChildren(){this.children=[];this.value='';}
 appendChild(child){this.children.push(child);}
 addEventListener(type,fn){this.handlers[type]=fn;}
 fire(type){this.handlers[type]();}
}
function dom(){const html=readFileSync(new URL('./responses.html',import.meta.url),'utf8'), elements=new Map([...html.matchAll(/id="([^"]+)"/g)].map(m=>[m[1],new Element()])); const document={getElementById:id=>{assert.ok(elements.has(id));return elements.get(id);},createElement:()=>new Element()}; installExplorer(document); const get=id=>document.getElementById('response-'+id);return {get,load:f=>{get('input').value=JSON.stringify(f);get('load').fire('click');}};}
test('production controls load change status/media/operation and invalidate edited input',()=>{
 const a=dom(); a.load(fixture()); assert.match(a.get('detail').textContent,/001/);
 a.get('media').value='text/plain'; a.get('media').fire('change'); assert.doesNotMatch(a.get('detail').textContent,/001/);
 a.get('status').value='204'; a.get('status').fire('change'); assert.match(a.get('warning').textContent,/No response content/); assert.equal(a.get('media').disabled,true);
 a.get('operation').value='1';a.get('operation').fire('change');assert.equal(a.get('status').value,'201');assert.match(a.get('detail').textContent,/boolean/);
 a.get('input').fire('input');assert.equal(a.get('detail').textContent,'');assert.equal(a.get('operation').disabled,true);
});
test('production controls clear stale details on failed load/ref and recover',()=>{
 const a=dom();a.load(fixture());a.get('input').value='{';a.get('load').fire('click');assert.equal(a.get('detail').textContent,'');assert.equal(a.get('status').disabled,true);
 const f=fixture();f.paths['/models'].get.responses['200']={$ref:'#/missing'};a.load(f);assert.match(a.get('warning').textContent,/Unresolved/);assert.equal(a.get('media').disabled,true);
 a.get('status').value='204';a.get('status').fire('change');assert.match(a.get('warning').textContent,/No response content/);a.load(fixture());assert.match(a.get('detail').textContent,/001/);
});
test('untrusted strings stay text and empty operations/responses remain empty',()=>{
 const a=dom(),f=fixture();f.components.responses.Good.description='<img src=x onerror=alert(1)>';a.load(f);assert.match(a.get('detail').textContent,/<img/);assert.equal(a.get('detail').children.length,0);
 a.load({openapi:'3.1.0',paths:{'/none':{get:{}}}});assert.match(a.get('warning').textContent,/No declared/);a.load({openapi:'3.1.0',paths:{}});assert.match(a.get('warning').textContent,/No operations/);
});

const selection = {method:'get',path:'/models',status:'200',media:'application/json'};
const load = f => loadSpecification(JSON.stringify(f));
function contract(schema = {type:'object',properties:{id:{type:'string'}}}) {
 return {openapi:'3.1.0',paths:{'/models':{get:{responses:{200:{description:'Models',content:{'application/json':{schema}}}}}}}};
}
const schemaOf = f => f.paths['/models'].get.responses[200].content['application/json'].schema;
const compare = (a,b,s=selection) => compareResponses(load(a),load(b),s);
test('comparison shows exact nested additions removals required type nullable and enum changes',()=>{
 const a=contract({type:'object',required:['id'],properties:{id:{type:'string',enum:['a','b']},old:{type:'integer'},items:{type:'array',items:{type:'object',properties:{x:{type:'number'}}}}}});
 const b=contract({type:'object',properties:{id:{type:'number',nullable:true,enum:['new',false]},added:{type:'boolean'},items:{type:'array',items:{type:'object',properties:{y:{type:'string'}}}}}});
 const result=compare(a,b);
 assert.equal(result.outcome,'differences');
 assert.deepEqual(result.changes.filter(c=>c.path==='response / "id"').map(c=>c.kind),['required-changed','type-changed','enum-changed']);
 assert.deepEqual(result.changes.find(c=>c.kind==='enum-changed').after,['new',false]);
 assert.ok(result.changes.some(c=>c.path==='response / "old"'&&c.kind==='removed-field'));
 assert.ok(result.changes.some(c=>c.path==='response / "added"'&&c.kind==='added-field'));
 assert.ok(result.changes.some(c=>c.path==='response / "items" / [items] / "x"'&&c.kind==='removed-field'));
 assert.ok(result.changes.some(c=>c.path==='response / "items" / [items] / "y"'&&c.kind==='added-field'));
 assert.match(result.scope,/No compatibility verdict/);
});
test('comparison resolves independent local schema and response refs with escaped Unicode field names',()=>{
 const a=contract({$ref:'#/components/schemas/A~1B~0'});
 a.components={schemas:{'A/B~':{type:'object',properties:{'東京 / "item"':{type:'integer'}}}},responses:{Good:a.paths['/models'].get.responses[200]}};
 a.paths['/models'].get.responses[200]={$ref:'#/components/responses/Good'};
 const b=structuredClone(a);b.components.schemas['A/B~'].properties['東京 / "item"'].type='string';
 const result=compare(a,b);assert.equal(result.changes.length,1);assert.equal(result.changes[0].kind,'type-changed');assert.equal(result.changes[0].path,'response / '+JSON.stringify('東京 / "item"'));
 assert.equal(compare(b,a).changes[0].after.declared,'integer');
});
test('enum and type set order and annotation edits do not fabricate scoped differences',()=>{
 const a=contract({type:['string','null'],enum:['a',null,{x:'one',y:false}],description:'Before'});
 const b=contract({type:['null','string'],enum:[{y:false,x:'one'},null,'a'],description:'After',example:'a'});
 const result=compare(a,b);assert.equal(result.outcome,'no-differences-in-inspected-declarations');assert.deepEqual(result.changes,[]);assert.match(result.summary,/Other contract behavior is not compared/);
 const c=contract({type:'string'});assert.equal(compare(c,contract({type:'string',enum:['a']})).changes[0].kind,'enum-changed');
 assert.equal(compare(contract(true),contract(false)).changes[0].kind,'type-changed');
});
test('exact selection reports missing operation status and media on either side without fallback',()=>{
 const a=contract(), noOp=contract();noOp.paths['/models'].post=noOp.paths['/models'].get;delete noOp.paths['/models'].get;
 const noStatus=contract();noStatus.paths['/models'].get.responses={'2XX':noStatus.paths['/models'].get.responses[200],default:{description:'Default'}};
 const noMedia=contract();noMedia.paths['/models'].get.responses[200].content={'text/plain':{schema:{type:'string'}}};
 for(const [f,state] of [[noOp,'missing-operation'],[noStatus,'missing-status'],[noMedia,'missing-media']]) {
  for(const [left,right,side] of [[a,f,'right'],[f,a,'left']]) {const result=compare(left,right);assert.equal(result.outcome,'missing-selection');assert.equal(result[side].state,state);assert.deepEqual(result.changes,[]);}
 }
 assert.equal(compare(a,a,{...selection,path:'/Models'}).left.state,'missing-operation');
 assert.equal(compare(a,a,{...selection,media:'Application/JSON'}).left.state,'missing-media');
 const empty=contract();empty.paths['/models'].get.responses[200]={description:'No body'};assert.equal(compare(empty,empty,{...selection,media:''}).outcome,'missing-selection');
});
test('comparison selectors union exact tuples statuses and media instead of matching operation IDs',()=>{
 const a=contract(),b=contract();a.paths['/models'].get.operationId='same';b.paths['/other']={post:b.paths['/models'].get};b.paths['/other'].post.operationId='same';
 b.paths['/models'].get.responses[404]={description:'Missing',content:{'text/plain':{schema:{type:'string'}}}};
 b.paths['/models'].get.responses[200].content['text/plain']={schema:{type:'string'}};
 const choices=comparisonChoices(load(a),load(b),selection);
 assert.deepEqual(choices.operations,[{method:'get',path:'/models'},{method:'post',path:'/other'}]);assert.deepEqual(choices.statuses,['200','404']);assert.deepEqual(choices.media,['application/json','text/plain']);
 assert.equal(compare(a,b,{method:'post',path:'/other',status:'200',media:'application/json'}).left.state,'missing-operation');
});
test('unresolved remote cyclic and sibling refs never become removed fields or unchanged',()=>{
 const good=contract();
 const badRefs=[{$ref:'#/missing'},{$ref:'https://example.invalid/schema'},{$ref:'#/components/schemas/Cycle'},{$ref:'#/components/schemas/Good',type:'number'}];
 for(const schema of badRefs) {
  const bad=contract(schema);bad.components={schemas:{Cycle:{properties:{again:{$ref:'#/components/schemas/Cycle'}}},Good:{type:'string'}}};
  for(const other of [good,bad]) {const result=compare(bad,other);assert.equal(result.outcome,'indeterminate');assert.deepEqual(result.changes,[]);assert.equal(result.left.state,'indeterminate');}
 }
 const path=contract();path.paths['/models']={$ref:'#/missing'};assert.equal(compare(path,good).left.state,'indeterminate');
 const response=contract();response.paths['/models'].get.responses[200]={$ref:'#/missing'};assert.equal(compare(good,response).right.state,'indeterminate');
});
test('unsupported composition constraints and invalid schemas remain indeterminate even when identical',()=>{
 const cases=[{allOf:[{type:'string'}]},{anyOf:[]},{oneOf:[true]},{not:false},{if:true,then:false,else:true},{additionalProperties:true},{$dynamicRef:'#x'},{prefixItems:[true]},{format:'date'},{minimum:0},{required:['undeclared']},{required:'id'},{properties:[]},{type:'mystery'},{type:[]},{enum:[]},{enum:'x'},{nullable:'yes'},null,3];
 for(const schema of cases) {const result=compare(contract(schema),contract(schema));assert.equal(result.outcome,'indeterminate',JSON.stringify(schema));assert.deepEqual(result.changes,[]);}
 const missing=contract();delete missing.paths['/models'].get.responses[200].content['application/json'].schema;assert.equal(compare(missing,missing).outcome,'indeterminate');
 const malformed=contract();malformed.paths['/models'].get.responses[200].content=null;assert.equal(compare(malformed,malformed).outcome,'indeterminate');
 malformed.paths['/models'].get.responses=42;assert.equal(compare(malformed,malformed).outcome,'indeterminate');
});
test('schema node nesting reference and enum limits never imply complete comparison',()=>{
 const many=contract({properties:Object.fromEntries(Array.from({length:501},(_,i)=>['x'+i,{type:'string'}]))});
 assert.equal(compare(many,many).outcome,'indeterminate');
 let deep={type:'string'};for(let i=0;i<26;i++)deep={properties:{next:deep}};
 assert.equal(compare(contract(deep),contract(deep)).outcome,'indeterminate');
 const refs=contract({$ref:'#/components/schemas/r0'});refs.components={schemas:{}};for(let i=0;i<18;i++)refs.components.schemas['r'+i]={$ref:'#/components/schemas/r'+(i+1)};
 assert.equal(compare(refs,refs).outcome,'indeterminate');
 const largeEnum=contract({enum:Array.from({length:10001},(_,i)=>String(i))});const result=compare(largeEnum,largeEnum);assert.equal(result.outcome,'indeterminate');assert.match(result.summary,/10,000/);assert.deepEqual(result.changes,[]);
});
function comparisonDom() {
 const html=readFileSync(new URL('./responses.html',import.meta.url),'utf8');
 const elements=new Map([...html.matchAll(/id="([^"]+)"/g)].map(m=>[m[1],new Element()]));
 const document={getElementById:id=>{assert.ok(elements.has(id));return elements.get(id);},createElement:()=>new Element()};installExplorer(document);
 const get=id=>document.getElementById(id);
 return {get,load:(prefix,f)=>{get(prefix+'-input').value=JSON.stringify(f);get(prefix+'-load').fire('click');},result:()=>JSON.parse(get('comparison-detail').textContent)};
}
test('production comparison controls load both orders, align exact selections and display absent declarations',()=>{
 for(const order of [['response','comparison'],['comparison','response']]) {
  const a=comparisonDom(),before=contract(),after=contract();after.paths['/new']={post:{responses:{201:{content:{'text/plain':{schema:{type:'string'}}}}}}};
  a.load(order[0],order[0]==='response'?before:after);assert.equal(a.get('comparison-operation').disabled,true);
  a.load(order[1],order[1]==='response'?before:after);assert.equal(a.result().outcome,'no-differences-in-inspected-declarations');
  a.get('comparison-operation').value=JSON.stringify(['post','/new']);a.get('comparison-operation').fire('change');assert.equal(a.result().left.state,'missing-operation');assert.equal(a.get('comparison-status').value,'201');assert.equal(a.get('comparison-media').value,'text/plain');
 }
 const a=comparisonDom(),after=contract();after.paths['/models'].get.responses[404]={content:{'text/plain':{schema:{type:'string'}}}};after.paths['/models'].get.responses[200].content['text/plain']={schema:{type:'string'}};
 a.load('response',contract());a.load('comparison',after);a.get('comparison-media').value='text/plain';a.get('comparison-media').fire('change');assert.equal(a.result().left.state,'missing-media');
 a.get('comparison-status').value='404';a.get('comparison-status').fire('change');assert.equal(a.result().left.state,'missing-status');
 a.get('comparison-status').value='200';a.get('comparison-status').fire('change');assert.equal(a.result().outcome,'no-differences-in-inspected-declarations');
});
test('production edits invalidate each input immediately and reloading recomputes against current documents',()=>{
 const a=comparisonDom(),after=contract({type:'number'});a.load('response',contract());a.load('comparison',after);assert.equal(a.result().outcome,'differences');
 for(const prefix of ['response','comparison']) {
  a.get(prefix+'-input').value=JSON.stringify(contract());a.get(prefix+'-input').fire('input');assert.equal(a.get('comparison-detail').textContent,'');assert.equal(a.get('comparison-operation').disabled,true);assert.equal(a.get('comparison-status').disabled,true);assert.equal(a.get('comparison-media').disabled,true);
  a.get(prefix+'-load').fire('click');assert.ok(a.get('comparison-detail').textContent);
 }
 assert.equal(a.result().outcome,'no-differences-in-inspected-declarations');
 a.get('comparison-load').fire('click');assert.equal(a.result().changes.length,0);
});
test('production failed loads clear stale comparison, recover, and retain indeterminate errors',()=>{
 const a=comparisonDom();a.load('response',contract());a.load('comparison',contract({type:'integer'}));
 for(const prefix of ['comparison','response']) {
  a.get(prefix+'-input').value='{';a.get(prefix+'-load').fire('click');assert.equal(a.get('comparison-detail').textContent,'');assert.equal(a.get('comparison-media').disabled,true);a.load(prefix,contract());assert.ok(a.get('comparison-detail').textContent);
 }
 const bad=contract({allOf:[{type:'string'}]});a.load('comparison',bad);assert.equal(a.result().outcome,'indeterminate');assert.match(a.get('comparison-warning').textContent,/indeterminate/);
 const response=contract();response.paths['/models'].get.responses[200]={$ref:'#/missing'};a.load('response',response);assert.equal(a.result().left.state,'indeterminate');assert.equal(a.get('comparison-media').disabled,false);
 a.load('response',contract());a.load('comparison',{openapi:'3.1.0',paths:{}});assert.equal(a.result().right.state,'missing-operation');
 a.load('response',{openapi:'3.1.0',paths:{}});assert.equal(a.get('comparison-detail').textContent,'');assert.match(a.get('comparison-warning').textContent,/No selectable operations/);
});
test('comparison renders hostile declarations only as text and performs no network or storage access',()=>{
 const a=comparisonDom(),before=contract(),after=contract({properties:{'<img src=x onerror=alert(1)>':{type:'string',enum:['<script>bad()</script>']}}});
 const oldFetch=globalThis.fetch;globalThis.fetch=()=>{throw Error('Unexpected network call');};
 try {a.load('response',before);a.load('comparison',after);assert.equal(a.result().outcome,'differences');assert.match(a.get('comparison-detail').textContent,/<img/);assert.equal(a.get('comparison-detail').children.length,0);} finally {globalThis.fetch=oldFetch;}
 const source=readFileSync(new URL('./responses.mjs',import.meta.url),'utf8');assert.doesNotMatch(source,/\b(?:fetch|XMLHttpRequest|localStorage|sessionStorage|innerHTML)\b/);
});
test('ignored media examples cannot block schema differences or scoped equality, while inspection retains warnings',()=>{
 for(const example of [{externalValue:'https://example.invalid/example.json'},{$ref:'#/components/examples/Missing'},{$ref:'https://example.invalid/example.json'},null]) {
  const before=contract({type:'string'}),after=contract({type:'number'});
  after.paths['/models'].get.responses[200].content['application/json'].examples={illustration:example};
  const result=compare(before,after);assert.equal(result.outcome,'differences');assert.equal(result.changes[0].kind,'type-changed');
  schemaOf(after).type='string';assert.equal(compare(before,after).outcome,'no-differences-in-inspected-declarations');
  assert.equal(compare(after,before).outcome,'no-differences-in-inspected-declarations');
  assert.ok(inspectResponse(load(after),0,'200','application/json').warnings.some(w=>w.startsWith('illustration:')));
  assert.equal(inspectResponse(load(after),0,'200','application/json',true).warnings.length,0);
  after.paths['/models'].get.responses[200].content['application/json'].schema={$ref:'#/missing'};
  assert.equal(compare(before,after).outcome,'indeterminate');
 }
});
test('production comparison ignores unavailable examples while the original explorer warns and schema blockers remain',()=>{
 const a=comparisonDom(),before=contract({type:'string'}),after=contract({type:'number'});
 before.paths['/models'].get.responses[200].content['application/json'].examples={illustration:{externalValue:'https://example.invalid/example.json'}};
 after.paths['/models'].get.responses[200].content['application/json'].examples={illustration:{$ref:'#/components/examples/Missing'}};
 a.load('response',before);assert.match(a.get('response-warning').textContent,/not fetched/);
 a.load('comparison',after);assert.equal(a.result().outcome,'differences');assert.equal(a.result().changes[0].kind,'type-changed');
 schemaOf(after).type='string';a.load('comparison',after);assert.equal(a.result().outcome,'no-differences-in-inspected-declarations');
 a.load('response',after);assert.match(a.get('response-warning').textContent,/Unresolved local reference/);assert.equal(a.result().outcome,'no-differences-in-inspected-declarations');
 after.paths['/models'].get.responses[200].content['application/json'].schema={oneOf:[{type:'string'}]};a.load('comparison',after);assert.equal(a.result().outcome,'indeterminate');
});
test('all numeric enum values including rounded decimals underflow overflow and nested numbers are indeterminate',()=>{
 const other=load(contract({enum:[null]}));
 for(const literal of ['9007199254740992','9007199254740993','1e400','1.00000000000000001','1e-400','0','-1','0.5']) {
  for(const entry of ['NUMERIC_LITERAL',{value:['NUMERIC_LITERAL']},['NUMERIC_LITERAL']]) {
   const text=JSON.stringify(contract({enum:[entry]})).replace('"NUMERIC_LITERAL"',literal), numeric=loadSpecification(text);
   for(const [left,right] of [[numeric,numeric],[numeric,other],[other,numeric]]) {
    const result=compareResponses(left,right,selection);assert.equal(result.outcome,'indeterminate',literal);assert.match(result.summary,/Numeric enum comparison is unsupported/);assert.deepEqual(result.changes,[]);
   }
  }
 }
 assert.equal(compare(contract({enum:['1']}),contract({enum:['2']})).outcome,'differences');
 assert.equal(compare(contract({enum:[{value:['1',null,false]}]}),contract({enum:[{value:[null,'1',false]}]})).outcome,'differences');
 const annotations=contract({type:'number',example:1,examples:[0.5],default:9007199254740992});
 annotations.paths['/models'].get.responses[404]={content:{'application/json':{schema:{enum:[9007199254740992]}}}};
 assert.equal(compare(annotations,contract({type:'number'})).outcome,'no-differences-in-inspected-declarations');
});
test('production numeric enum precision limits are visible without losing ordinary numeric type comparison',()=>{
 const a=comparisonDom();a.load('response',contract({enum:[null]}));
 a.get('comparison-input').value=JSON.stringify(contract({enum:[{nested:['NUMERIC_LITERAL']}]})).replace('"NUMERIC_LITERAL"','1e400');a.get('comparison-load').fire('click');
 assert.equal(a.result().outcome,'indeterminate');assert.deepEqual(a.result().changes,[]);assert.match(a.get('comparison-warning').textContent,/numeric precision/);
 a.load('response',contract({type:'number'}));a.load('comparison',contract({type:'integer'}));assert.equal(a.result().outcome,'differences');assert.equal(a.result().changes[0].kind,'type-changed');
});
