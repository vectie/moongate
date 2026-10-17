# Workload attribution API

Keep operator-owned labels beside normalized usage, with exact request-ID edits.
Filtering changes only `workloadReview.view`; saved JSON keeps all usage rows.

```mbt check
///|
test "create and reopen an operator workload review" {
  let usage =
    #|{"schema":"moongate.usage-file.v1","data":[{"requestId":"original-id","model":"fixture","totalTokens":12}]}
  let plan =
    #|{"schema":"moongate.workload-plan.v1","scope":"local-export","changes":[{"requestId":"original-id","expectedWorkload":null,"workload":"Research"}]}
  guard @usage_preview.attribute_usage_file_json(
      usage,
      scope="local-export",
      plan~,
    )
    is Ok(saved) else {
    fail("create review")
  }
  guard @usage_preview.export_workload_csv(
      saved.stringify(),
      scope="local-export",
    )
    is Ok(csv) else {
    fail("export review")
  }
  assert_true(csv.contains("Research"))
  assert_true(csv.contains("operator-authored-unverified"))
}
```

Labels are private, unverified commentary. They do not establish billing ownership,
grant execution authority, or change provider routing. Use the dedicated attribution
API to preserve labels; older usage preview/export APIs intentionally read only
ordinary usage and do not preserve `workloadReview`. Keep the saved review.
