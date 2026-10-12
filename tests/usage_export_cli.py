#!/usr/bin/env python3
"""Offline CSV consumer checks; no spreadsheet application or provider is run."""
import csv, fcntl, hashlib, io, json, os, pathlib, shutil, subprocess, sys
exe, source, output = map(pathlib.Path, sys.argv[1:])
output.mkdir(parents=True, exist_ok=False)
lock = open(os.environ['MOON_NATIVE_LOCK'], 'a')
fcntl.flock(lock, fcntl.LOCK_EX)
assert shutil.disk_usage(output).free > 4294967296
rows = [
    {'requestId':'001','appType':'codex','providerId':'team','model':'small','date':'2026-10-09','inputTokens':10,'outputTokens':2,'totalCostUsd':0.25},
    {'requestId':'=HYPERLINK("https://invalid.test")','appType':'+formula','providerId':'@provider','model':'\t-1,"moon"\n新','totalTokens':3},
    {'requestId':'003','appType':'codex','providerId':'team','model':'small','date':'2026-10-08','totalTokens':0,'totalCostUsd':0},
]
input_file = output/'usage.json'
input_file.write_text(json.dumps({'data':rows,'total':9,'sourceCoverageUnknown':True}))
before = hashlib.sha256(input_file.read_bytes()).hexdigest()
cases=[]
def run(name, args, ok=True):
    result=subprocess.run([str(exe),*args],capture_output=True)
    (output/(name+'.stdout')).write_bytes(result.stdout)
    (output/(name+'.stderr')).write_bytes(result.stderr)
    assert (result.returncode == 0) == ok, (name,result.returncode,result.stderr)
    if not ok: assert not result.stdout, (name,'unexpected partial CSV')
    cases.append({'name':name,'exit':result.returncode})
    return list(csv.DictReader(io.StringIO(result.stdout.decode(),newline=''))) if ok else None
base=['--file',str(input_file)]
requests=run('requests',base)
assert len(requests)==3
assert requests[0]['requestId']=="'001"
assert requests[0]['inputTokens']=='10' and requests[0]['totalCostUsd']=='0.25'
assert requests[1]['inputTokens']==requests[1]['totalCostUsd']==''
assert requests[1]['model']=="'\t-1,\"moon\"\n新"
assert requests[1]['requestId'].startswith("'=HYPERLINK")
assert requests[2]['totalCostUsd']=='0'
assert all(r['partialSource']==r['sourceCoverageUnknown']=='true' and r['sourceTotal']=='9' for r in requests)
summary=run('summary',base+['--view','summary'])[0]
assert (summary['requests'],summary['tokens'],summary['knownEstimatedUsd'],summary['missingCostCount'],summary['undatedCount'])==('3','15','0.25','1','1')
for view in ('model','provider','app','day'):
    grouped=run(view,base+['--view',view])
    assert sum(int(x['requests']) for x in grouped)==3
    assert sum(int(x['tokens']) for x in grouped)==15
    assert sum(int(x['missingCostCount']) for x in grouped)==1
filtered=run('filtered',base+['--app','codex','--start-day','2026-10-09','--end-day','2026-10-09'])
assert len(filtered)==1 and filtered[0]['requestId']=="'001" and filtered[0]['filteredRows']=='1'
assert run('no-match',base+['--model','missing'])==[]
empty=run('no-match-summary',base+['--model','missing','--view','summary'])[0]
assert empty['requests']=='0' and empty['sourceTotal']=='9' and empty['partialSource']=='true'
csv_file=output/'input.csv';csv_file.write_text('model,totalTokens,date,costUsd\na,2,2026-10-09T01:00:00+02:00,\nb,0,2026-10-09,0\n')
csv_rows=run('csv-input',['--file',str(csv_file),'--start-day','2026-10-08','--end-day','2026-10-08'])
assert csv_rows[0]['requestId']=="'row-1"
assert len(csv_rows)==1 and csv_rows[0]['date']=="'2026-10-08" and csv_rows[0]['totalCostUsd']==''
jsonl=output/'input.jsonl';jsonl.write_text('\n'.join(json.dumps(x) for x in rows))
assert len(run('jsonl',['--file',str(jsonl)]))==3
for name,args in [('duplicate',base+['--file',str(input_file)]),('view',base+['--view','x']),('unknown',base+['--unknown','x']),('missing-value',base+['--model']),('bad-date',base+['--start-day','2026-02-30'])]: run(name,args,False)
bad=output/'invalid.json';bad.write_text('[{"model":"x","totalTokens":-1}]');run('bad-record',['--file',str(bad)],False)
large=output/'too-big.json';large.write_text(' '*(4*1024*1024+1));run('input-limit',['--file',str(large)],False)
assert hashlib.sha256(input_file.read_bytes()).hexdigest()==before
result={'cases':cases,'sourceCommit':subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip(),'sourceTree':subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD^{tree}'],text=True).strip(),'executableSha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'inputSha256Unchanged':before,'qualified':'native CLI plus Python csv consumer; no spreadsheet UI or provider'}
(output/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(f'{len(cases)} process cases passed')
