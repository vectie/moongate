const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

test('published suite contracts describe support, not installed or connected apps', () => {
  const target = {innerHTML: ''};
  const context = vm.createContext({
    $: () => target, number: Number, uiLabel: x => x, escapeHtml: String, content: String,
    frameworkApps: [{id:'moondesk',label:'MoonDesk'},{id:'moonbook',label:'MoonBook'}],
    firstString: (o, keys, fallback='') => keys.map(k=>o?.[k]).find(v=>typeof v==='string') || fallback,
  });
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../public/assets/moongate-suite.js'),'utf8'), context);
  vm.runInContext('renderSuiteApps([{id:"moonbook"},{id:"moondesk"}], {moondesk:{healthUrl:"/health"}, moonbook:{usageSummaryUrl:"/usage"}})',context);
  assert.match(target.innerHTML, /Supported/);
  assert.doesNotMatch(target.innerHTML, /Connected|Ready|Installed|connection[< ]/);
  assert.ok(target.innerHTML.indexOf('MoonDesk') < target.innerHTML.indexOf('MoonBook'));
  vm.runInContext('renderSuiteApps([], {}, "failed")',context);
  assert.match(target.innerHTML, /unavailable/);
});
