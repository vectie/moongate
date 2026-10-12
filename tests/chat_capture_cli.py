#!/usr/bin/env python3
"""Focused saved-response import and independent CSV-consumer smoke; offline only."""
import csv, fcntl, hashlib, io, json, os, pathlib, shutil, subprocess, sys
exe, exporter, source, output = map(lambda p: pathlib.Path(p).resolve(), sys.argv[1:])
output.mkdir(parents=True, exist_ok=False)
assert exe.is_file() and exporter.is_file() and source.is_dir()
lock = open(os.environ['MOON_NATIVE_LOCK'], 'a')
fcntl.flock(lock, fcntl.LOCK_EX)
assert shutil.disk_usage(output).free > 4294967296
cases = []
inputs = [source/'examples/usage'/name for name in ('chat-completion.json','chat-stream.sse','chat-interrupted.sse','chat-error.json')]
hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
def run(name, args, ok=True, command=exe):
    result = subprocess.run([str(command), *map(str,args)], capture_output=True, timeout=30)
    (output/(name+'.stdout')).write_bytes(result.stdout)
    (output/(name+'.stderr')).write_bytes(result.stderr)
    assert (result.returncode == 0) == ok, (name, result.returncode, result.stderr)
    if not ok: assert not result.stdout, (name, 'partial output on failed import')
    cases.append({'name':name,'exit':result.returncode})
    return result.stdout.decode()
args = [part for p in inputs for part in ('--file',p)]
text = run('import-four',args+['--app','saved-client','--provider','saved-route'])
result = json.loads(text)
assert len(result['data']) == 2 and result['sourceTotal'] == 4
assert result['summary']['tokens'] == 37 and result['summary']['missingCostCount'] == 2
assert result['sourceCoverageUnknown'] and result['partial']
assert result['chatCaptureImport']['stateCounts'] == {'completed':2,'incomplete':1,'errored':1,'empty':0}
assert result['data'][0]['requestId'] == 'chat-json-fixture'
assert result['data'][0]['date'] == '2026-10-09'
assert result['data'][1]['captureIndex'] == 2
assert all(r['totalCostUsd'] is None for r in result['data'])
assert 'PRIVATE_SYNTHETIC' not in text and 'cached_tokens' not in text
normalized = output/'usage.json'; normalized.write_text(text)
report = run('report',args+['--report'])
assert 'Recorded tokens with complete terminal usage: 37' in report
assert 'PRIVATE_SYNTHETIC' not in report
# Existing output workflow consumes the imported JSON; Python independently parses it.
rows = list(csv.DictReader(io.StringIO(run('csv-filter',['--file',normalized,'--start-day','2026-10-09','--end-day','2026-10-09'],command=exporter))))
assert len(rows)==1 and rows[0]['requestId']=="'chat-json-fixture"
assert rows[0]['totalTokens']=='12' and rows[0]['totalCostUsd']==''
assert rows[0]['sourceCoverageUnknown']=='true' and rows[0]['sourceTotal']=='4'
summary = list(csv.DictReader(io.StringIO(run('csv-summary',['--file',normalized,'--view','summary'],command=exporter))))[0]
assert summary['tokens']=='37' and summary['missingCostCount']=='2'
missing = json.loads(inputs[0].read_text());missing['id']='missing';missing['usage']=None
missing_file = output/'missing.json';missing_file.write_text(json.dumps(missing))
missing_result=json.loads(run('missing',['--file',missing_file]))
assert not missing_result['data'] and missing_result['sourceTotal']==1
assert missing_result['chatCaptureImport']['outcomes'][0]['usageState']=='missing'
cut = output/'unframed.sse';cut.write_text(inputs[1].read_text().rstrip()+'\n')
assert not json.loads(run('unframed',['--file',cut]))['data']
malformed=output/'malformed.sse';malformed.write_text('data: {PRIVATE_SYNTHETIC_BROKEN\n\n')
run('malformed',['--file',malformed],False)
assert 'PRIVATE_SYNTHETIC' not in (output/'malformed.stderr').read_text()
duplicate=output/'same-request.json';duplicate.write_bytes(inputs[0].read_bytes())
run('duplicate-id',['--file',inputs[0],'--file',duplicate],False)
run('duplicate-path',['--file',inputs[0],'--file',inputs[0]],False)
run('unknown-option',['--file',inputs[0],'--unknown','x'],False)
run('missing-value',['--file'],False)
large=output/'too-big.json';large.write_text(' '*(4*1024*1024+1))
run('input-limit',['--file',large],False)
assert hashes == {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
verification={'cases':cases,'sourceCommit':subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip(),'sourceTree':subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD^{tree}'],text=True).strip(),'executableSha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'exporterSha256':hashlib.sha256(exporter.read_bytes()).hexdigest(),'inputSha256Unchanged':hashes,'qualified':'focused native capture import plus existing CSV output consumer; no provider, gateway or UI journey'}
(output/'verification.json').write_text(json.dumps(verification,indent=2)+'\n')
print(f'{len(cases)} process cases passed')
