#!/usr/bin/env python3
"""Saved synthetic capture -> native CLI -> existing explorer; no provider."""
import hashlib
import os
import shutil
import json
from pathlib import Path
import subprocess
import sys

importer, explorer, source, destination = [Path(x).resolve() for x in sys.argv[1:]]
# Honor the workspace's shared native execution lock when configured.
if os.environ.get("MOON_NATIVE_LOCK"):
    import fcntl
    native_lock = open(os.environ["MOON_NATIVE_LOCK"], "a")
    fcntl.flock(native_lock, fcntl.LOCK_EX)
assert shutil.disk_usage(source).free > 4294967296, "Preserve the 4 GiB reserve"
destination.mkdir(parents=True, exist_ok=False)
inputs = {}
receipts = []

def save(name, text, track=False):
    p = destination / name
    p.write_text(text, encoding="utf-8")
    if track:
        inputs[str(p)] = hashlib.sha256(p.read_bytes()).hexdigest()
    return p

def run(exe, args, name, expected=0):
    result = subprocess.run([str(exe), *map(str, args)], cwd=source,
                            capture_output=True, text=True, timeout=90)
    save(name + ".stdout", result.stdout)
    save(name + ".stderr", result.stderr)
    assert result.returncode == expected, (name, result.returncode, result.stdout, result.stderr)
    assert "PRIVATE_" not in result.stdout + result.stderr, name
    receipts.append({"case": name, "exit": result.returncode})
    return result.stdout

fixtures = [source / "examples/usage" / name for name in [
    "ollama-generate.ndjson", "ollama-chat.json", "ollama-interrupted.ndjson",
    "ollama-error.ndjson", "ollama-incomplete-usage.json"]]
for p in fixtures:
    inputs[str(p)] = hashlib.sha256(p.read_bytes()).hexdigest()
args = [str(x) for p in fixtures for x in ("--file", p)]
text = run(importer, args, "import")
result = json.loads(text)
meta = result["ollamaCaptureImport"]
assert result["sourceTotal"] == 5 and result["total"] == 2
assert result["summary"] == {"requests": 2, "tokens": 40, "knownEstimatedUsd": 0,
                             "missingCostCount": 2, "undatedCount": 1}
assert result["partial"] is True and result["sourceCoverageUnknown"] is True
assert meta["stateCounts"] == {"completed": 3, "errored": 1, "incomplete": 1, "empty": 0}
assert meta["responseObjectCount"] == 7 and meta["durationUnit"] == "nanoseconds"
assert [r["captureIndex"] for r in result["data"]] == [1, 2]
assert all(r["requestId"] == "" and r["totalCostUsd"] is None for r in result["data"])
assert result["data"][0]["date"] == "2026-10-09"
assert meta["outcomes"][0]["terminalMetrics"]["total_duration"] == 2200000000
assert meta["outcomes"][2]["terminalMetrics"] == {}  # partial counts never become final usage
assert meta["outcomes"][4]["usageState"] == "incomplete"
assert meta["outcomes"][4]["terminalMetrics"]["eval_duration"] == 250000000
assert run(importer, [*args, "--report"], "report") == result["report"] + "\n"
labelled = json.loads(run(importer, [*args, "--app", "project-α", "--provider", "local-label"], "labels"))
assert all(r["appType"] == "project-α" and r["providerId"] == "local-label" for r in labelled["data"])
# The existing companion uses text arguments; only synthetic/scrubbed output is passed.
reopened = json.loads(run(explorer, [text], "reopen"))
assert reopened["summary"] == result["summary"]
assert reopened["sourceCoverageUnknown"] is True and reopened["sourceTotal"] == 5
assert all("captureIndex" not in r and r["requestId"] == "" for r in reopened["data"])
filtered = json.loads(run(explorer, [text, "--model", "fixture-local", "--start-day", "2026-10-09"], "filter"))
assert filtered["total"] == 1 and filtered["summary"]["tokens"] == 40
assert filtered["partial"] is True and filtered["sourceTotal"] == 5
nomatch = json.loads(run(explorer, [text, "--model", "absent"], "no-match"))
assert nomatch["total"] == 0 and nomatch["sourceCoverageUnknown"] is True

empty = save("empty.ndjson", " \r\n", True)
emptied = json.loads(run(importer, ["--file", empty], "empty"))
assert emptied["total"] == 0 and emptied["ollamaCaptureImport"]["stateCounts"]["empty"] == 1
# Files are independent observations, not request identifiers. Identical captures
# under different names remain two observations, with no deduplication claim.
duplicate_content = save("same-observation.json", fixtures[1].read_text(), True)
repeated = json.loads(run(importer, ["--file", fixtures[1], "--file", duplicate_content], "duplicate-content"))
assert repeated["total"] == 2

concat = save("concatenated.ndjson", fixtures[0].read_text() + fixtures[0].read_text(), True)
malformed = save("malformed.ndjson", '\n{"PRIVATE_MALFORMED"', True)
ambiguous = save("ambiguous.json", '{"error":"PRIVATE_ERROR","done":true}', True)
large = save("large.ndjson", " " * (4 * 1024 * 1024 + 1), True)
for name, case, fragment in [
    ("concat", ["--file", concat], "data after terminal"),
    ("malformed", ["--file", malformed], "Line 2: invalid JSON"),
    ("ambiguous", ["--file", ambiguous], "ambiguous error"),
    ("duplicate-path", ["--file", fixtures[0], "--file", fixtures[0]], "Duplicate capture path"),
    ("unknown-option", ["--file", "never-read", "--nope"], "Unknown option"),
    ("missing-file", ["--file", destination / "absent"], "Ollama capture import failed"),
    ("missing-value", ["--file"], "Missing value"),
    ("large-input", ["--file", large], "4 MiB"),
]:
    assert fragment in run(importer, case, name, 1)

for i, number in enumerate(("1e-400", "9007199254740990.5", '"7"')):
    raw = '{"model":"m","response":"PRIVATE_X","done":true,"prompt_eval_count":' + number + ',"eval_count":0}'
    p = save(f"numeric-{i}.json", raw, True)
    assert "prompt_eval_count" in run(importer, ["--file", p], f"numeric-{i}", 1)
# Compact large model labels can expand in repeated normalized/review sections.
expanded = save("expands.json", json.dumps({"model": "x" * 1100000, "response": "",
    "done": True, "prompt_eval_count": 1, "eval_count": 0}), True)
assert expanded.stat().st_size < 4 * 1024 * 1024
assert "output exceeds" in run(importer, ["--file", expanded], "expanded-output", 1)
assert {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in inputs} == inputs
save("verification.json", json.dumps({"passed": True, "processCases": receipts,
    "inputHashesUnchanged": inputs,
    "importerSha256": hashlib.sha256(importer.read_bytes()).hexdigest(),
    "explorerSha256": hashlib.sha256(explorer.read_bytes()).hexdigest()}, indent=2) + "\n")
print(f"Passed {len(receipts)} offline process cases; source inputs unchanged.")
