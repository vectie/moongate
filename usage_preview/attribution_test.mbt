///|
fn attribution_fixture() -> String {
  let fixture =
    #|{"schema":"moongate.usage-file.v1","sourceTotal":8,"sourceCoverageUnknown":true,"data":[{"requestId":"a","appType":"reviewer","providerId":"local","model":"small","date":"2026-10-12","inputTokens":10,"outputTokens":2,"totalTokens":12,"totalCostUsd":0.25,"prompt":"PRIVATE_FIXTURE"},{"requestId":"b","appType":"reviewer","providerId":"local","model":"large","date":"2026-10-13","inputTokens":20,"outputTokens":3,"totalTokens":23,"totalCostUsd":null},{"requestId":"c","providerId":"local","model":"small","totalTokens":0,"totalCostUsd":0},{"requestId":"d","providerId":"local","model":"small","totalTokens":5,"totalCostUsd":0.1}]}
  fixture
}

///|
fn attribution_plan_fixture() -> String {
  let fixture =
    #|{"schema":"moongate.workload-plan.v1","scope":"fixture-run","changes":[{"requestId":"a","expectedWorkload":null,"workload":"Research"},{"requestId":"b","expectedWorkload":null,"workload":"Research"},{"requestId":"c","expectedWorkload":null,"workload":"Unassigned"}]}
  fixture
}

///|
fn attribution_ok(
  content : String,
  plan? : String = "",
  workload? : String = "",
  unassigned? : Bool = false,
) -> Json raise {
  match
    @usage_preview.attribute_usage_file_json(
      content,
      scope="fixture-run",
      plan~,
      workload~,
      unassigned~,
    ) {
    Ok(value) => value
    Err(error) => fail(error)
  }
}

///|
fn attribution_field(value : Json, key : String) -> Json raise {
  guard value is Object(fields) && fields.get(key) is Some(value) else {
    fail("Missing " + key)
  }
  value
}

///|
fn attribution_view(value : Json) -> Json raise {
  attribution_field(attribution_field(value, "workloadReview"), "view")
}

///|
test "workload labels create useful groups without editing usage or hiding unassigned rows" {
  let input = attribution_fixture()
  let result = attribution_ok(input, plan=attribution_plan_fixture())
  guard @usage_preview.moongate_preview_usage_file_json(input) is Ok(plain) else {
    fail("preview")
  }
  assert_eq(attribution_field(result, "data"), attribution_field(plain, "data"))
  assert_eq(
    attribution_field(result, "summary"),
    attribution_field(plain, "summary"),
  )
  assert_eq(attribution_field(result, "sourceTotal"), (8).to_json())
  assert_eq(attribution_field(result, "sourceCoverageUnknown"), true.to_json())
  assert_eq(attribution_field(result, "partial"), true.to_json())
  let review = attribution_field(result, "workloadReview")
  assert_eq(attribution_field(review, "editsApplied"), (3).to_json())
  guard attribution_field(review, "groups") is Array(groups) else {
    fail("groups")
  }
  assert_eq(groups.length(), 3)
  assert_eq(attribution_field(groups[0], "workload"), "Research".to_json())
  assert_eq(attribution_field(groups[0], "tokens"), (35).to_json())
  assert_eq(attribution_field(groups[0], "knownEstimatedUsd"), 0.25.to_json())
  assert_eq(attribution_field(groups[0], "missingCostCount"), (1).to_json())
  assert_eq(attribution_field(groups[1], "workload"), "Unassigned".to_json())
  assert_eq(attribution_field(groups[1], "assigned"), true.to_json())
  assert_eq(attribution_field(groups[2], "workload"), Json::null())
  assert_eq(attribution_field(groups[2], "assigned"), false.to_json())
  assert_false(result.stringify().contains("PRIVATE_FIXTURE"))
  assert_eq(result, attribution_ok(input, plan=attribution_plan_fixture()))
}

///|
test "filtered saved views retain every row and can be reopened reassigned and cleared" {
  let first = attribution_ok(
    attribution_fixture(),
    plan=attribution_plan_fixture(),
    workload="Research",
  )
  guard attribution_field(attribution_view(first), "data") is Array(selected) else {
    fail("selected")
  }
  assert_eq(selected.length(), 2)
  assert_eq(attribution_field(first, "total"), (4).to_json())
  let reopen = attribution_ok(first.stringify(), unassigned=true)
  guard attribution_field(attribution_view(reopen), "data") is Array(pending) else {
    fail("pending")
  }
  assert_eq(pending.length(), 1)
  assert_eq(attribution_field(pending[0], "requestId"), "d".to_json())
  let edits =
    #|{"schema":"moongate.workload-plan.v1","scope":"fixture-run","changes":[{"requestId":"a","expectedWorkload":"Research","workload":"Support"},{"requestId":"b","expectedWorkload":"Research","workload":null}]}
  let revised = attribution_ok(
    reopen.stringify(),
    plan=edits,
    workload="Support",
  )
  assert_eq(
    attribution_field(revised, "data"),
    attribution_field(first, "data"),
  )
  assert_eq(
    attribution_field(
      attribution_field(attribution_view(revised), "summary"),
      "tokens",
    ),
    (12).to_json(),
  )
  let cleared = attribution_ok(revised.stringify(), unassigned=true)
  assert_eq(
    attribution_field(
      attribution_field(attribution_view(cleared), "summary"),
      "requests",
    ),
    (2).to_json(),
  )
  let empty = attribution_ok(revised.stringify(), workload="Absent")
  assert_eq(
    attribution_field(
      attribution_field(attribution_view(empty), "summary"),
      "requests",
    ),
    (0).to_json(),
  )
}

///|
test "stale scope unknown ids duplicate edits and malformed labels reject atomically" {
  let first = attribution_ok(
    attribution_fixture(),
    plan=attribution_plan_fixture(),
  ).stringify()
  let invalid = [
    attribution_plan_fixture(),
    attribution_plan_fixture().replace_all(old="fixture-run", new="another-run"),
    attribution_plan_fixture().replace_all(old="\"a\"", new="\"missing\""),
    attribution_plan_fixture().replace_all(old="\"b\"", new="\"a\""),
    attribution_plan_fixture().replace_all(old="\"Research\"", new="\" \""),
    attribution_plan_fixture().replace_all(old="\"Research\"", new="42"),
    attribution_plan_fixture().replace_all(
      old="\"expectedWorkload\"",
      new="\"unexpected\"",
    ),
  ]
  for plan in invalid {
    assert_true(
      @usage_preview.attribute_usage_file_json(
        first,
        scope="fixture-run",
        plan~,
      )
      is Err(_),
    )
  }
  assert_true(
    @usage_preview.attribute_usage_file_json(first, scope="another-run")
    is Err(_),
  )
  assert_eq(attribution_ok(first), attribution_ok(first))
}

///|
test "ambiguous identities unsafe exact counts and scenario inputs cannot be attributed" {
  let base = attribution_fixture()
  for
    content in [
      base.replace_all(old="\"requestId\":\"a\"", new="\"requestId\":\"b\""),
      base.replace_all(old="\"requestId\":\"a\"", new="\"requestId\":\"row-1\""),
      base.replace_all(old="\"requestId\":\"a\"", new="\"id\":\"a\""),
      base.replace_all(
        old="\"totalTokens\":12",
        new="\"totalTokens\":12.00000000000000001",
      ),
      base.replace_all(
        old="\"totalTokens\":12",
        new="\"totalTokens\":9007199254740992",
      ),
      base.replace_all(old="\"totalTokens\":12", new="\"totalTokens\":\"12\""),
      base.replace_all(old="\"totalCostUsd\":0.25", new="\"totalCostUsd\":-1"),
      base.replace_all(
        old="\"sourceTotal\":8",
        new="\"usageEvidenceKind\":\"hypothetical-route-scenario\"",
      ),
      base.replace_all(
        old="\"sourceTotal\":8",
        new="\"usageMergeScope\":\"other\"",
      ),
      base.replace_all(
        old="\"totalTokens\":12",
        new="\"totalTokens\":9007199254740991",
      ),
    ] {
    assert_true(
      @usage_preview.attribute_usage_file_json(content, scope="fixture-run")
      is Err(_),
    )
  }
}

///|
test "duplicate decoded JSON keys and broken saved references fail without revealing payloads" {
  let duplicate = attribution_plan_fixture().replace_all(
    old="\"workload\":\"Research\"",
    new="\"workload\":\"Research\",\"workl\\u006fad\":\"Other\"",
  )
  assert_true(
    @usage_preview.attribute_usage_file_json(
      attribution_fixture(),
      scope="fixture-run",
      plan=duplicate,
    )
    is Err(_),
  )
  let first = attribution_ok(
    attribution_fixture(),
    plan=attribution_plan_fixture(),
  )
  guard first is Object(fields) &&
    attribution_field(first, "workloadReview") is Object(review) else {
    fail("review")
  }
  review["assignments"] = [{ "requestId": "missing", "workload": "Research" }].to_json()
  fields["workloadReview"] = Json::object(review)
  assert_true(
    @usage_preview.attribute_usage_file_json(
      Json::object(fields).stringify(),
      scope="fixture-run",
    )
    is Err(_),
  )
  guard @usage_preview.attribute_usage_file_json(
      "{PRIVATE_FIXTURE",
      scope="fixture-run",
    )
    is Err(error) else {
    fail("invalid")
  }
  assert_false(error.contains("PRIVATE_FIXTURE"))
}

///|
test "reopen ignores cached summaries and projections and recomputes workload totals" {
  let first = attribution_ok(
    attribution_fixture(),
    plan=attribution_plan_fixture(),
  )
  guard first is Object(fields) &&
    attribution_field(first, "workloadReview") is Object(review) else {
    fail("review")
  }
  review["groups"] = ["fabricated"].to_json()
  review["view"] = { "data": [], "summary": { "tokens": 9999999 } }
  review["report"] = "FABRICATED"
  fields["workloadReview"] = Json::object(review)
  fields["summary"] = { "tokens": 9999999 }
  let result = attribution_ok(Json::object(fields).stringify())
  assert_eq(
    attribution_field(attribution_field(result, "summary"), "tokens"),
    (40).to_json(),
  )
  assert_false(result.stringify().contains("FABRICATED"))
}

///|
test "workload CSV handles formula labels quotes newlines and missing cost explicitly" {
  let plan = attribution_plan_fixture().replace_all(
    old="Research",
    new="=SUM(1,2)\\n\u4efb\u52a1",
  )
  let saved = attribution_ok(attribution_fixture(), plan~).stringify()
  guard @usage_preview.export_workload_csv(saved, scope="fixture-run")
    is Ok(groups) else {
    fail("groups csv")
  }
  assert_true(groups.contains("\"'=SUM(1,2)\n任务\""))
  assert_true(groups.contains("knownEstimatedUsd,missingCostCount"))
  assert_true(groups.contains("operator-authored-unverified"))
  guard @usage_preview.export_workload_csv(
      saved,
      scope="fixture-run",
      view="requests",
      unassigned=true,
    )
    is Ok(requests) else {
    fail("requests csv")
  }
  assert_true(requests.contains("\"'d\",,false"))
  assert_false(requests.contains("\"'a\","))
  assert_true(
    @usage_preview.export_workload_csv(
      saved,
      scope="fixture-run",
      unassigned=true,
    )
    is Err(_),
  )
  assert_true(
    @usage_preview.export_workload_csv(saved, scope="fixture-run", view="bad")
    is Err(_),
  )
}

///|
test "empty usage explicit zero and all-unassigned reviews remain usable" {
  let empty = attribution_ok(
    "{\"schema\":\"moongate.usage-file.v1\",\"data\":[]}",
  )
  assert_eq(
    attribution_field(attribution_field(empty, "workloadReview"), "groups"),
    Json::array([]),
  )
  let result = attribution_ok(attribution_fixture(), unassigned=true)
  assert_eq(
    attribution_field(
      attribution_field(attribution_view(result), "summary"),
      "requests",
    ),
    (4).to_json(),
  )
  assert_true(
    @usage_preview.attribute_usage_file_json(attribution_fixture(), scope=" ")
    is Err(_),
  )
  assert_true(
    @usage_preview.attribute_usage_file_json(
      attribution_fixture(),
      scope="fixture-run",
      workload="Research",
      unassigned=true,
    )
    is Err(_),
  )
}
