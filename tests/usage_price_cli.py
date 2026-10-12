"""Local-only usage file -> hypothetical priced export -> existing explorer."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

price, explorer, source, output = map(Path, sys.argv[1:])
output.mkdir(parents=True, exist_ok=False)
fixture = source / "examples/usage/pricing.csv"
rates = source / "examples/usage/rates.json"
inputs = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in (fixture, rates)}
count = 0

def run(binary, args, name, ok=True):
    global count
    result = subprocess.run([str(binary), *args], text=True, capture_output=True)
    (output / (name + ".stdout")).write_text(result.stdout)
    (output / (name + ".stderr")).write_text(result.stderr)
    assert (result.returncode == 0) == ok, (name, result.returncode, result.stdout, result.stderr)
    count += 1
    return result.stdout

args = ["--file", str(fixture), "--rates", str(rates)]
priced_text = run(price, args, "priced")
priced = json.loads(priced_text)
(output / "scenario.json").write_text(priced_text)
assert priced["summary"]["knownEstimatedUsd"] == 4
assert priced["summary"]["missingCostCount"] == 2
assert priced["usagePricing"]["pairedDeltaUsd"] == -1
assert priced["usagePricing"]["originalKnownEstimatedUsd"] == 15
assert priced["data"][1]["totalCostUsd"] == 0
assert priced["data"][2]["inputTokens"] is None
assert priced["data"][2]["totalCostUsd"] is None
reopened = json.loads(run(explorer, [priced_text, "--provider", "fixture-east"], "explorer-filtered"))
assert reopened["summary"]["requests"] == 3
assert reopened["summary"]["knownEstimatedUsd"] == 4
assert reopened["summary"]["missingCostCount"] == 1
assert "usagePricing" not in reopened
report = run(price, args + ["--report"], "report")
assert "Hypothetical" in report and "not provider prices" in report
assert "USD" in report
for name, extra in [("duplicate", ["--file", str(fixture)]), ("unknown", ["--bad"]), ("report-twice", ["--report", "--report"])]:
    run(price, args + extra, name, False)
run(price, ["--file", str(fixture)], "missing-rates", False)
run(price, ["--file", str(output / "absent.csv"), "--rates", str(rates)], "missing-file", False)
card = json.loads(rates.read_text())
card["rates"].append(card["rates"][0])
duplicate = output / "duplicate-rates.json"
duplicate.write_text(json.dumps(card))
run(price, ["--file", str(fixture), "--rates", str(duplicate)], "duplicate-rate", False)
partial = output / "partial.jsonl"
partial.write_text(json.dumps({"sourceTotal":8,"sourceCoverageUnknown":True,"data":[{"model":"fixture-small","providerId":"fixture-east","inputTokens":0,"outputTokens":0,"prompt":"SECRET_PROMPT","apiKey":"SECRET_KEY"}]}))
partial_text = run(price, ["--file", str(partial), "--rates", str(rates)], "partial-redacted")
assert "SECRET_" not in partial_text
partial_reopened = json.loads(run(explorer, [partial_text], "partial-reopened"))
assert partial_reopened["partial"] and partial_reopened["sourceCoverageUnknown"]
assert partial_reopened["sourceTotal"] == 8
jsonl = output / "requests.jsonl"
jsonl.write_text(json.dumps({"model":"fixture-small","providerId":"fixture-east","inputTokens":1000000,"outputTokens":0}) + "\n" + json.dumps({"model":"fixture-small","providerId":"fixture-east","inputTokens":0,"outputTokens":0}) + "\n")
j = json.loads(run(price, ["--file",str(jsonl),"--rates",str(rates)],"jsonl"))
assert j["summary"]["knownEstimatedUsd"] == 2
large = output / "oversize.json"
large.write_text(" " * (4 * 1024 * 1024 + 1))
run(price, ["--file", str(large), "--rates", str(rates)], "input-limit", False)
# Below the input limit, but repeated identity/provenance makes its export too big.
expanded = output / "expanded.json"
expanded.write_text(json.dumps([{"requestId":"x"*200000,"model":"fixture-small","providerId":"fixture-east","inputTokens":0,"outputTokens":0} for _ in range(12)]))
run(price, ["--file", str(expanded), "--rates", str(rates)], "output-limit", False)
for path, digest in inputs.items():
    assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == digest
(output / "result.json").write_text(json.dumps({"process_cases":count,"passed":True,"input_sha256_before_after":inputs,"journey":"usage CSV -> hypothetical USD priced JSON -> existing explorer provider filter","main_cli":"type-checked routing only; process evidence uses shared standalone command"},indent=2)+"\n")
print(f"PASS: {count} process cases; priced export reopens, unknowns retained, local inputs unchanged")
