"""Focused local-only process acceptance; no providers or gateway required."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

main, companion, source, output = map(Path, sys.argv[1:])
output.mkdir(parents=True, exist_ok=False)
fixture = source / 'examples/usage/latency.csv'
original = hashlib.sha256(fixture.read_bytes()).hexdigest()
count = 0

def run(binary, args, name, ok=True):
    global count
    prefix = ['usage', 'latency'] if binary == main else []
    result = subprocess.run([str(binary), *prefix, *args], capture_output=True, text=True)
    (output / (name + '.stdout')).write_text(result.stdout)
    (output / (name + '.stderr')).write_text(result.stderr)
    assert (result.returncode == 0) == ok, (name, result.returncode, result.stdout, result.stderr)
    count += 1
    return result.stdout

args = ['--file', str(fixture)]
a = json.loads(run(main, args, 'main'))
b = json.loads(run(companion, args, 'companion'))
assert a == b
assert a['summary'] == {'rows': 4, 'sampleCount': 3, 'missingLatencyCount': 1, 'p50Ms': 25.5, 'p95Ms': 350, 'p99Ms': 350, 'maxMs': 350}
assert a['slowest'][0]['requestId'] == 'latency-three'
filtered = json.loads(run(main, args + ['--provider', 'fixture-east', '--start-day', '2026-10-08', '--end-day', '2026-10-08'], 'filtered'))
assert filtered['selectedRows'] == 2 and filtered['summary']['p50Ms'] == 0
assert 'nearest rank' in run(companion, args + ['--report'], 'report')
empty = json.loads(run(main, args + ['--model', 'absent'], 'empty'))
assert empty['summary']['p95Ms'] is None
for name, extra in [('duplicate', ['--file', str(fixture)]), ('unknown', ['--bogus']), ('bad-date', ['--start-day', '2026-02-30']), ('reversed', ['--start-day', '2026-10-10', '--end-day', '2026-10-09'])]:
    run(main, args + extra, name, False)
run(companion, ['--file', str(output / 'absent.csv')], 'missing-file', False)
secret = output / 'local-redaction.json'
secret.write_text(json.dumps({'sourceCoverageUnknown': True, 'data': [{'model': 'm', 'totalTokens': 1, 'latencyMs': 5, 'prompt': 'SECRET_PAYLOAD', 'apiKey': 'SECRET_KEY'}]}))
redacted = run(main, ['--file', str(secret)], 'redacted')
assert 'SECRET_' not in redacted
assert json.loads(redacted)['source']['partial'] is True
invalid = output / 'invalid-latency.json'
invalid.write_text('[{"model":"m","totalTokens":1,"latencyMs":-1}]')
run(companion, ['--file', str(invalid), '--model', 'absent'], 'invalid-hidden', False)
large_input = output / 'oversize-input.json'
large_input.write_text(' ' * (4 * 1024 * 1024 + 1))
run(companion, ['--file', str(large_input)], 'input-byte-limit', False)
large_output = output / 'oversize-output.json'
large_output.write_text(json.dumps([{'requestId': 'x' * 200000, 'model': 'm', 'totalTokens': 0, 'latencyMs': i} for i in range(12)]))
run(companion, ['--file', str(large_output)], 'output-byte-limit', False)
assert hashlib.sha256(fixture.read_bytes()).hexdigest() == original
(output / 'result.json').write_text(json.dumps({'process_cases': count, 'passed': True, 'fixture_sha256_before_after': original}, indent=2) + '\n')
print(f'PASS: {count} process cases; main/companion parity, filters, unknown, redaction, errors, unchanged input')
