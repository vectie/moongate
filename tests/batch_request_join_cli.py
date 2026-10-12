#!/usr/bin/env python3
"""Exercise the actual MoonGate executables with local files; no provider calls."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

main, companion, source, destination = map(Path, sys.argv[1:])
source = source.resolve()
destination = destination.resolve()
destination.mkdir(parents=True, exist_ok=False)

def save(name, value):
    path = destination / name
    path.write_text(value, encoding="utf-8")
    return path

def jsonl(records):
    return "\r\n\r\n".join(json.dumps(x, ensure_ascii=False) for x in records) + "\r\n"

def request(identifier, model="requested-alias", endpoint="/v1/chat/completions"):
    return {"custom_id": identifier, "method": "POST", "url": endpoint,
            "body": {"model": model, "messages": [{"content": "PRIVATE_REQUEST_MARKER\n你好"}],
                     "metadata": {"secret": "PRIVATE_METADATA_MARKER"}},
            "headers": {"authorization": "PRIVATE_AUTH_MARKER"}}

requests = [request("summarize-1"), request("summarize-2", "请求模型\nβ", "/v1/responses"),
            request("missing-任务\nα"), request("expired-1"), request("reason-1", endpoint="/v1/responses"),
            request("missing-usage")]
manifest = save("requests.jsonl", jsonl(requests))
empty = save("empty.jsonl", "\r\n")
results = source / "examples/usage/batch-results.jsonl"
errors = source / "examples/usage/batch-errors.jsonl"
input_paths = [manifest, empty, results, errors]
initial_hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in input_paths}
base_args = ["--file", str(results), "--errors", str(errors)]
executables = [(main.resolve(), ["usage", "import-batch"]), (companion.resolve(), [])]
receipts = []

def invoke(executable, prefix, args, label, expected=0):
    run = subprocess.run([str(executable), *prefix, *map(str, args)], cwd=source,
                         capture_output=True, text=True, timeout=30)
    save(label + ".stdout", run.stdout)
    save(label + ".stderr", run.stderr)
    assert run.returncode == expected, (label, run.returncode, run.stdout, run.stderr)
    assert "PRIVATE_" not in run.stdout + run.stderr, label
    receipts.append({"case": label, "exit": run.returncode})
    return run.stdout

for i, (exe, prefix) in enumerate(executables):
    output = invoke(exe, prefix, [*base_args, "--requests", manifest], f"joined-{i}")
    document = json.loads(output)
    meta = document["batchImport"]
    join = meta["requestJoin"]
    assert [join[x] for x in ("requestCount", "matchedResultCount", "missingResultCount", "unexpectedResultCount")] == [6, 5, 1, 1]
    assert document["sourceTotal"] == 7 and document["partial"] is True
    assert document["summary"]["tokens"] == 355 and document["summary"]["missingCostCount"] == 3
    assert meta["sourceResultCount"] == 6 and meta["batchCompleteness"] == "unverified"
    rows = join["outcomes"]
    assert [x["customId"] for x in rows] == [r["custom_id"] for r in requests] + ["http-failed-1"]
    assert rows[1]["requestedModel"] == "请求模型\nβ" and rows[1]["responseModel"] == "moon-small"
    assert rows[1]["requestEndpoint"] == "/v1/responses" and rows[1]["responseObject"] == "chat.completion"
    assert rows[2]["outcome"] == "missing_result" and rows[2]["resultLine"] is None
    assert rows[3]["outcome"] == "batch_error" and rows[3]["responseModel"] is None
    assert rows[4]["responseState"] == "incomplete"
    assert rows[-1]["match"] == "unexpected_result" and rows[-1]["outcome"] == "http_error"
    report = invoke(exe, prefix, [*base_args, "--requests", manifest, "--report"], f"report-{i}")
    assert "6 requests; 5 matched results; 1 missing results; 1 unexpected results" in report
    plain = json.loads(invoke(exe, prefix, base_args, f"result-only-{i}"))
    assert "requestJoin" not in plain["batchImport"] and plain["sourceTotal"] == 6
    assert all("responseModel" not in row for row in plain["batchImport"]["outcomes"])
    absent = json.loads(invoke(exe, prefix, ["--file", empty, "--requests", manifest], f"all-missing-{i}"))
    assert absent["data"] == [] and absent["sourceTotal"] == 6 and absent["partial"] is True
    assert absent["batchImport"]["requestJoin"]["missingResultCount"] == 6

    duplicate = save(f"duplicate-request-{i}.jsonl", jsonl([requests[0], requests[0]]))
    malformed = save(f"malformed-request-{i}.jsonl", '\n{"PRIVATE_REQUEST_MARKER"')
    unsupported = save(f"unsupported-request-{i}.jsonl", jsonl([request("x", endpoint="/v1/embeddings")]))
    oversized = save(f"oversized-request-{i}.jsonl", " " * (4 * 1024 * 1024))
    for label, bad in [("duplicate", duplicate), ("malformed", malformed), ("unsupported", unsupported), ("combined-limit", oversized)]:
        refusal = invoke(exe, prefix, [*base_args, "--requests", bad], f"refused-{label}-{i}", 1)
        assert "no results imported" in refusal or "combined 4 MiB" in refusal
    invoke(exe, prefix, [*base_args, "--requests"], f"missing-value-{i}", 1)
    invoke(exe, prefix, [*base_args, "--requests", manifest, "--requests", manifest], f"duplicate-option-{i}", 1)
    invoke(exe, prefix, [*base_args, "--requests", destination / "absent.jsonl"], f"missing-file-{i}", 1)

assert (destination / "joined-0.stdout").read_bytes() == (destination / "joined-1.stdout").read_bytes()
assert (destination / "report-0.stdout").read_bytes() == (destination / "report-1.stdout").read_bytes()
joined_file = destination / "joined-0.stdout"
reopened = json.loads(invoke(main.resolve(), ["usage", "preview"], ["--file", joined_file], "reopened"))
assert reopened["sourceTotal"] == 7 and reopened["partial"] is True and reopened["summary"]["tokens"] == 355
comparison = json.loads(invoke(main.resolve(), ["usage", "compare"], ["--before", joined_file, "--after", destination / "reopened.stdout"], "comparison"))
assert comparison["summary"]["delta"]["tokens"] == 0
assert comparison["summary"]["estimatedUsdDelta"] is None
assert {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in input_paths} == initial_hashes
save("verification.json", json.dumps({"passed": True, "processCases": receipts, "sourceHashesUnchanged": initial_hashes,
                                       "mainSha256": hashlib.sha256(main.read_bytes()).hexdigest(),
                                       "companionSha256": hashlib.sha256(companion.read_bytes()).hexdigest()}, indent=2) + "\n")
print(f"PASS: {len(receipts)} real command invocations; exact-ID join, payload omission, reopening, comparison, and input preservation")
