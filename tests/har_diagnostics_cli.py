"""Local HAR capture -> outcome filter -> original-entry timing detail -> report."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

binary, source, output = map(Path, sys.argv[1:])
output.mkdir(parents=True, exist_ok=False)
fixture = source / "examples/har/diagnostic-session.har"
before = hashlib.sha256(fixture.read_bytes()).hexdigest()
count = 0


def run(args, name, ok=True):
    global count
    process = subprocess.run([str(binary), *args], text=True, capture_output=True)
    (output / (name + ".stdout")).write_text(process.stdout)
    (output / (name + ".stderr")).write_text(process.stderr)
    assert (process.returncode == 0) == ok, (name, process.returncode, process.stdout[:2000], process.stderr[:2000])
    count += 1
    return process.stdout


args = ["--file", str(fixture)]
all_text = run(args, "all")
all_rows = json.loads(all_text)
assert all_rows["captureEntries"] == 7 and all_rows["selectedEntries"] == 7
assert all_rows["summary"]["httpErrorCount"] == 2
assert all_rows["summary"]["noHttpResponseCount"] == 1
assert all_rows["summary"]["unknownStatusCount"] == 1
assert all_rows["summary"]["p50ElapsedMs"] == 85
assert all_rows["summary"]["p95ElapsedMs"] == 250
assert all_rows["entries"][4]["elapsedMs"] == 0
assert all_rows["entries"][3]["elapsedMs"] is None
assert all_rows["entries"][5]["startOffsetMs"] == 1500
assert "PRIVATE_" not in all_text
errors = json.loads(run(args + ["--status", "errors"], "errors"))
assert [r["entry"] for r in errors["entries"]] == [3, 6]
rate_limited = json.loads(run(args + ["--method", "post", "--status", "429", "--origin", "https://API.fixture.invalid:443"], "rate-limited"))
assert [r["entry"] for r in rate_limited["entries"]] == [3]
assert rate_limited["entries"][0]["startOffsetMs"] == 500
selected = json.loads(run(args + ["--entry", "6"], "entry-six"))
assert len(selected["entries"]) == 1
assert selected["entries"][0] == all_rows["entries"][5]
assert selected["entries"][0]["longestRecordedPhase"] == "wait"
assert selected["entries"][0]["timingsMs"]["connect"] == 60
assert selected["entries"][0]["timingsMs"]["ssl"] == 55
report = run(args + ["--entry", "6", "--report"], "entry-six-report")
assert "server_error" in report and '"wait":180' in report
assert "PRIVATE_" not in report
assert "No request was sent" in report and "SSL is a subset of connect" in report
unknown = json.loads(run(args + ["--status", "unknown"], "unknown"))
assert [r["entry"] for r in unknown["entries"]] == [7]
no_response = json.loads(run(args + ["--status", "0"], "no-response"))
assert [r["entry"] for r in no_response["entries"]] == [4]
empty = json.loads(run(args + ["--entry", "6", "--status", "2xx"], "empty-intersection"))
assert empty["selectedEntries"] == 0 and empty["summary"]["p50ElapsedMs"] is None
for name, extra in [("duplicate", ["--file", "other"]), ("unknown-option", ["--bad"]), ("duplicate-report", ["--report", "--report"]), ("bad-entry", ["--entry", "0"]), ("absent-entry", ["--entry", "8"]), ("origin-path", ["--origin", "https://api.fixture.invalid/private"]), ("bad-status", ["--status", "600"])]:
    run(args + extra, name, False)
run([], "missing-args", False)
run(["--file", str(output / "absent.har")], "missing-file", False)
bad = json.loads(fixture.read_text())
bad["log"]["entries"][3]["time"] = "wrong"
bad_file = output / "bad.har"
bad_file.write_text(json.dumps(bad))
error = run(["--file", str(bad_file), "--entry", "1"], "invalid-unselected-entry", False)
assert "HAR entry 4" in error and "PRIVATE_" not in error
bad_json = output / "bad-json.har"
bad_json.write_text('{"PRIVATE_PARSE_MARKER":')
assert "PRIVATE_PARSE_MARKER" not in run(["--file", str(bad_json)], "bad-json", False)
large = output / "oversize.har"
large.write_text(" " * (4 * 1024 * 1024 + 1))
run(["--file", str(large)], "input-limit", False)
base = {"request": {"method": "GET", "url": "https://" + "a" * 500 + ".invalid/path"}, "response": {"status": 200}, "time": 0}
expanded = output / "expanded.har"
expanded_rows = []
for index in range(2000):
    row = dict(base)
    row["request"] = {"method": "GET", "url": "https://" + str(index).zfill(4) + "a" * 496 + ".invalid/path"}
    expanded_rows.append(row)
expanded.write_text(json.dumps({"log": {"version": "1.2", "entries": expanded_rows}}))
assert expanded.stat().st_size < 4 * 1024 * 1024
assert "output exceeds" in run(["--file", str(expanded)], "output-limit", False)
recovered = json.loads(run(["--file", str(expanded), "--entry", "1"], "output-limit-recovery"))
assert recovered["captureEntries"] == 2000 and recovered["selectedEntries"] == 1
entry_limit = output / "entry-limit.har"
entry_limit.write_text(json.dumps({"log": {"version": "1.2", "entries": [{}] * 2001}}))
assert "2,000 entries" in run(["--file", str(entry_limit)], "entry-limit", False)
assert hashlib.sha256(fixture.read_bytes()).hexdigest() == before
(output / "result.json").write_text(json.dumps({"process_cases": count, "passed": True, "fixture_sha256_before_after": before, "journey": "mixed HAR capture -> errors -> 429/origin filter -> entry 6 timing drilldown -> text report", "main_cli": "shared standalone inspect_har process; main requests har route is type-checked, not monolithic-process-qualified"}, indent=2) + "\n")
print(f"PASS: {count} process cases; original entry association, timing phases, unknowns, and unchanged input verified")
