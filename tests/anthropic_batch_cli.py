#!/usr/bin/env python3
"""Local executable workflow with synthetic files only; no gateway/provider."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

importer, explorer, source, destination = map(lambda x: Path(x).resolve(), sys.argv[1:])
destination.mkdir(parents=True, exist_ok=False)
receipts = []
inputs = {}

def save(name, text, track=False):
    p = destination / name
    p.write_text(text, encoding="utf-8")
    if track:
        inputs[str(p)] = hashlib.sha256(p.read_bytes()).hexdigest()
    return p

def invoke(executable, args, name, expected=0):
    run = subprocess.run([str(executable), *map(str, args)], cwd=source,
                         capture_output=True, text=True, timeout=60)
    save(name + ".stdout", run.stdout)
    save(name + ".stderr", run.stderr)
    assert run.returncode == expected, (name, run.returncode, run.stdout, run.stderr)
    assert "PRIVATE_" not in run.stdout + run.stderr, name
    receipts.append({"case": name, "exit": run.returncode})
    return run.stdout

fixture = source / "examples/usage/anthropic-batch-results.jsonl"
inputs[str(fixture)] = hashlib.sha256(fixture.read_bytes()).hexdigest()
base = ["--file", fixture, "--format", "anthropic"]
text = invoke(importer, base, "import")
report = json.loads(text)
meta = report["anthropicBatchImport"]
assert report["sourceTotal"] == 8 and report["total"] == 3 and report["partial"] is True
assert report["summary"]["tokens"] == 315 and report["summary"]["missingCostCount"] == 3
assert report["summary"]["undatedCount"] == 3
assert meta["resultCounts"] == {"succeeded": 5, "errored": 1, "canceled": 1, "expired": 1}
assert meta["missingUsageCount"] == 1 and meta["incompleteUsageCount"] == 1
assert meta["completeRowComponents"] == {"uncachedInputTokens": 110, "cacheCreationInputTokens": 120,
                                          "cacheReadInputTokens": 70, "outputTokens": 15}
assert [x["totalTokens"] for x in report["data"]] == [105, 0, 210]
assert all(x["totalCostUsd"] is None and x["date"] == "" for x in report["data"])
assert meta["outcomes"][-1]["components"]["cacheReadInputTokens"] is None
assert meta["outcomes"][2]["stopReason"] == "max_tokens"
assert meta["batchCompleteness"] == "unverified"
assert invoke(importer, [*base, "--report"], "report") == report["report"] + "\n"
labelled = json.loads(invoke(importer, [*base, "--app", "review-β", "--provider", "operator-label"], "labels"))
assert all(x["appType"] == "review-β" and x["providerId"] == "operator-label" for x in labelled["data"])
# This pre-existing explorer companion accepts literal text. All data here is synthetic.
reopened = json.loads(invoke(explorer, [text], "reopen"))
assert reopened["data"] == report["data"] and reopened["summary"] == report["summary"]
assert reopened["sourceTotal"] == 8 and reopened["partial"] is True
assert "anthropicBatchImport" not in reopened
filtered = json.loads(invoke(explorer, [text, "--model", "fixture-small"], "filter"))
assert filtered["total"] == 2 and filtered["summary"]["tokens"] == 105
assert filtered["sourceTotal"] == 8 and filtered["partial"] is True
empty_filter = json.loads(invoke(explorer, [text, "--model", "absent"], "no-match"))
assert empty_filter["total"] == 0 and empty_filter["sourceTotal"] == 8
assert empty_filter["partial"] is True
empty = save("empty.jsonl", "\r\n\n", True)
assert json.loads(invoke(importer, ["--file", empty, "--format", "anthropic"], "empty"))["total"] == 0
# Additional local outcome shards use the selected format and are validated together.
extra = save("extra.jsonl", '{"custom_id":"extra-expired","result":{"type":"expired"}}\n', True)
combined = json.loads(invoke(importer, [*base, "--errors", extra], "combined"))
assert combined["sourceTotal"] == 9 and combined["anthropicBatchImport"]["resultCounts"]["expired"] == 2
invalid = save("invalid.jsonl", '\n{"PRIVATE_MALFORMED"', True)
duplicate = save("duplicate.jsonl", fixture.read_text().splitlines()[0] + "\n", True)
for name, args, fragment in [
    ("duplicate", [*base, "--errors", duplicate], "duplicate custom_id"),
    ("invalid", ["--file", invalid, "--format", "anthropic"], "Line 2: invalid JSON"),
    ("manifest", [*base, "--requests", "never-open-this-file"], "only with --format openai"),
    ("unknown-format", ["--file", fixture, "--format", "Anthropic"], "--format must be"),
    ("missing-format", ["--file", fixture, "--format"], "Missing value"),
    ("default-is-openai", ["--file", fixture], "Expected response or error"),
    ("missing-file", ["--file", destination / "absent.jsonl", "--format", "anthropic"], "Batch usage import failed"),
]:
    assert fragment in invoke(importer, args, name, 1)
# Original OpenAI integration keeps its previous default and explicit format behavior.
openai = source / "examples/usage/batch-results.jsonl"
old = json.loads(invoke(importer, ["--file", openai], "openai-default"))
explicit = json.loads(invoke(importer, ["--file", openai, "--format", "openai"], "openai-explicit"))
assert old == explicit and "batchImport" in old
# Numeric lexical precision is checked for the new cache categories, not just output.
original = json.loads(fixture.read_text().splitlines()[0])
for number in ("1e-400", "9007199254740990.5", '"70"'):
    raw = json.dumps(original, ensure_ascii=False, separators=(",", ":")).replace('"cache_read_input_tokens":70', '"cache_read_input_tokens":' + number)
    p = save("numeric-" + str(len(receipts)) + ".jsonl", raw, True)
    assert "whole nonnegative" in invoke(importer, ["--file", p, "--format", "anthropic"], "numeric-" + str(len(receipts)), 1)
# A compact source can expand beyond the supported explorer envelope size.
large = save("expanded.jsonl", "\n".join(json.dumps({"custom_id": str(i) + "x" * 200,
    "result": {"type": "expired"}}, separators=(",", ":")) for i in range(8000)), True)
assert large.stat().st_size < 4 * 1024 * 1024
assert "output exceeds" in invoke(importer, ["--file", large, "--format", "anthropic"], "expanded-limit", 1)
assert {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in inputs} == inputs
save("verification.json", json.dumps({"passed": True, "processCases": receipts,
    "inputHashesUnchanged": inputs, "importerSha256": hashlib.sha256(importer.read_bytes()).hexdigest(),
    "explorerSha256": hashlib.sha256(explorer.read_bytes()).hexdigest()}, indent=2) + "\n")
print(f"PASS: {len(receipts)} actual executable invocations; import/report/reopen/filter, unknowns, compatibility, input preservation")
