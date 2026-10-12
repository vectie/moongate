#!/usr/bin/env python3
"""Exercise actual local MoonGate binaries, not a reimplementation of merge."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

main, companion, source, destination = map(Path, sys.argv[1:])
main, companion, source, destination = [p.resolve() for p in (main, companion, source, destination)]
destination.mkdir(parents=True, exist_ok=False)
receipts = []
inputs = {}

def save(name, text, is_input=False):
    p = destination / name
    p.write_text(text, encoding='utf-8')
    if is_input:
        inputs[str(p)] = hashlib.sha256(p.read_bytes()).hexdigest()
    return p

def invoke(exe, prefix, args, label, expected=0):
    r = subprocess.run([str(exe), *prefix, *map(str, args)], cwd=source, capture_output=True, text=True, timeout=45)
    save(label + '.stdout', r.stdout)
    save(label + '.stderr', r.stderr)
    assert r.returncode == expected, (label, r.returncode, r.stdout[:1000], r.stderr[:1000])
    assert 'PRIVATE_SENTINEL' not in r.stdout + r.stderr, label
    receipts.append({'case':label,'exit':r.returncode})
    return r.stdout

def row(identifier='request-a', tokens=10, **kw):
    return {'requestId':identifier,'model':'small','app':'codex','provider':'fixture', 'totalTokens':tokens, **kw}

page_one = source / 'examples/usage/merge-page-one.json'
page_two = source / 'examples/usage/merge-page-two.csv'
for p in [page_one, page_two]:
    inputs[str(p)] = hashlib.sha256(p.read_bytes()).hexdigest()
base = ['--scope','fixture-gateway','--file',page_one,'--file',page_two]
conflict = save('conflict.json', json.dumps([row(costUsd=2, date='2026-10-01', prompt='PRIVATE_SENTINEL')]), True)
anonymous = save('anonymous.json', '[{"model":"small","totalTokens":1}]', True)
legacy = save('legacy.json', json.dumps([row('row-1')]), True)
empty = save('empty.json', '[]', True)
broken = save('broken.json', '{"PRIVATE_SENTINEL"', True)
oversize = save('oversize.json', ' ' * (4*1024*1024), True)
unknown = save('unknown.json', json.dumps([row('request-a', costUsd=None, date='2026-10-01')]), True)
# Supported labels can expand through summaries and readable reports; output must remain reopenable.
expanded = save('expanded.json', json.dumps([row('expanded', model='m'*1600000)]), True)

for i, (exe, prefix) in enumerate([(main,['usage','merge']),(companion,[])]):
    result = json.loads(invoke(exe,prefix,base,f'merged-{i}'))
    assert result['schema']=='moongate.usage-file.v1'
    assert result['summary']=={'requests':3,'tokens':60,'knownEstimatedUsd':0.5,'missingCostCount':1,'undatedCount':0}
    assert result['sourceTotal']==3 and result['partial'] and result['sourceCoverageUnknown']
    meta=result['usageMerge']
    assert (meta['inputRows'],meta['uniqueRows'],meta['duplicateRows'])==(4,3,1)
    assert [r['requestId'] for r in result['data']]==['request-a','request-b','request-c']
    assert meta['sources'][0]['sourceTotal']==4 and len(meta['occurrences'])==4
    report=invoke(exe,prefix,base+['--report'],f'report-{i}')
    assert '4 input rows; 3 unique requests; 1 identical duplicate rows' in report
    for label,path,fragment in [('conflict',conflict,'Conflicting requestId'),('unknown-vs-zero',unknown,'Conflicting requestId'),('anonymous',anonymous,'explicit nonempty requestId'),('legacy',legacy,'may be synthetic'),('broken',broken,'Invalid JSON'),('combined-limit',oversize,'combined 4 MiB')]:
        refused=invoke(exe,prefix,['--scope','fixture-gateway','--file',page_one,'--file',path],f'{label}-{i}',1)
        assert fragment in refused, (label, refused)
    refused=invoke(exe,prefix,['--scope','x','--file',expanded,'--file',empty],f'output-limit-{i}',1)
    assert 'reopen limit' in refused
    invoke(exe,prefix,['--file',page_one,'--file',page_two],f'missing-scope-{i}',1)
    invoke(exe,prefix,base+['--scope','other'],f'duplicate-scope-{i}',1)
    invoke(exe,prefix,base+['--replace'],f'unknown-option-{i}',1)
    invoke(exe,prefix,['--scope','x','--file',page_one],f'one-file-{i}',1)
    invoke(exe,prefix,base+['--file'],f'missing-file-value-{i}',1)
    invoke(exe,prefix,['--scope','x','--file',page_one,'--file',destination/'absent.json'],f'missing-file-{i}',1)

assert (destination/'merged-0.stdout').read_bytes()==(destination/'merged-1.stdout').read_bytes()
assert (destination/'report-0.stdout').read_bytes()==(destination/'report-1.stdout').read_bytes()
merged=destination/'merged-0.stdout'
reopened=json.loads(invoke(main,['usage','preview'],['--file',merged],'reopened'))
assert reopened['partial'] and reopened['sourceCoverageUnknown'] and reopened['usageMergeScope']=='fixture-gateway'
assert reopened['summary']==result['summary']
filtered=json.loads(invoke(main,['usage','preview'],['--file',merged,'--model','absent'],'filtered'))
assert filtered['data']==[] and filtered['partial'] and filtered['sourceCoverageUnknown']
comparison=json.loads(invoke(main,['usage','compare'],['--before',merged,'--after',destination/'reopened.stdout'],'comparison'))
assert comparison['summary']['delta']['tokens']==0 and comparison['summary']['estimatedUsdDelta'] is None
again=json.loads(invoke(main,['usage','merge'],['--scope','fixture-gateway','--file',merged,'--file',page_two],'again'))
assert again['data']==result['data'] and again['summary']==result['summary'] and again['partial']
wrong=invoke(main,['usage','merge'],['--scope','other','--file',destination/'reopened.stdout','--file',empty],'wrong-scope',1)
assert 'scope differs' in wrong
assert {p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in inputs}==inputs
save('verification.json',json.dumps({'passed':True,'processCases':receipts,'sourceHashesUnchanged':inputs,'mainSha256':hashlib.sha256(main.read_bytes()).hexdigest(),'companionSha256':hashlib.sha256(companion.read_bytes()).hexdigest()},indent=2)+'\n')
print(f'PASS: {len(receipts)} real command invocations; merge, conflict refusal, unknown coverage, reopen/filter/compare and input preservation')
