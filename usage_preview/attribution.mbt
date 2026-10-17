///|
/// Edit operator-authored workload labels without changing recorded usage.
/// The saved result retains all rows; selected rows live in workloadReview.view.
pub fn attribute_usage_file_json(
  content : String,
  scope~ : String,
  plan? : String = "",
  workload? : String = "",
  unassigned? : Bool = false,
) -> Result[Json, String] {
  let result = attribution_review(
    content,
    scope~,
    plan~,
    workload~,
    unassigned~,
  ) catch {
    error => return Err(error.to_string())
  }
  Ok(result)
}

///|
fn attribution_review(
  content : String,
  scope~ : String,
  plan~ : String,
  workload~ : String,
  unassigned~ : Bool,
) -> Json raise {
  attribution_label(scope, "scope")
  if !workload.is_empty() {
    attribution_label(workload, "workload filter")
  }
  if unassigned && !workload.is_empty() {
    fail("Choose either a workload or unassigned rows")
  }
  let input = attribution_parse(content)
  guard input is Object(source) &&
    source.get("schema") == Some("moongate.usage-file.v1".to_json()) &&
    source.get("data") is Some(Array(raw)) else {
    fail("First import or preview usage as moongate.usage-file.v1 JSON")
  }
  if source.contains("usageEvidenceKind") {
    fail("Hypothetical route scenarios are not recorded usage for attribution")
  }
  if source.get("usageMergeScope") is Some(existing) &&
    existing != scope.to_json() {
    fail("Scope differs from the saved usage merge namespace")
  }
  if raw.length() > 10000 {
    fail("Attribution is limited to 10,000 requests")
  }
  let ids : Map[String, Bool] = Map([])
  let mut total_tokens = 0.0
  let mut total_cost = 0.0
  for index, row in raw {
    guard row is Object(fields) &&
      fields.get("requestId") is Some(String(id)) &&
      !id.trim().is_empty() &&
      id.length() <= 1024 &&
      !merge_synthetic_id(id) else {
      fail(
        "Row \{index + 1}: original explicit requestId required; row-N is reserved",
      )
    }
    if ids.contains(id) {
      fail("Duplicate requestId; merge overlapping exports before attribution")
    }
    ids[id] = true
    guard fields.get("totalTokens") is Some(total) else {
      fail("Row \{index + 1}: canonical totalTokens required")
    }
    let count = attribution_count(total)
    if count > 9007199254740991.0 - total_tokens {
      fail("Combined token count exceeds exact safe integer range")
    }
    total_tokens += count
    for key in ["inputTokens", "outputTokens"] {
      if fields.get(key) is Some(value) && value != Json::null() {
        ignore(attribution_count(value))
      }
    }
    if fields.get("totalCostUsd") is Some(value) && value != Json::null() {
      guard value is Number(cost, ..) &&
        cost >= 0.0 &&
        cost <= 9007199254740991.0 - total_cost else {
        fail("Costs must be finite nonnegative estimates within the safe range")
      }
      total_cost += cost
    }
  }
  let preview = match moongate_preview_usage_file_json(content) {
    Ok(Object(fields)) => fields
    Err(error) => fail(error)
    _ => fail("Expected usage rows")
  }
  guard preview["data"] is Array(rows) else { fail("Expected normalized rows") }
  let assignments : Map[String, String] = Map([])
  if source.get("workloadReview") is Some(saved) {
    guard saved is Object(review) &&
      review.get("schema") == Some("moongate.workload-review.v1".to_json()) &&
      review.get("scope") == Some(scope.to_json()) &&
      review.get("assignments") is Some(Array(stored)) else {
      fail("Saved workload review is invalid or belongs to a different scope")
    }
    for entry in stored {
      guard entry is Object(fields) &&
        fields.length() == 2 &&
        fields.get("requestId") is Some(String(id)) &&
        fields.get("workload") is Some(String(label)) else {
        fail("Saved assignments require requestId and workload only")
      }
      attribution_label(label, "saved workload")
      if !ids.contains(id) || assignments.contains(id) {
        fail("Saved assignment has an unknown or duplicate requestId")
      }
      assignments[id] = label
    }
  }
  let applied = if plan.is_empty() {
    0
  } else {
    attribution_apply_plan(plan, scope, ids, assignments)
  }
  let selected = rows.filter(row => {
    let label = assignments.get(usage_file_text(row, "requestId"))
    if unassigned {
      label is None
    } else if !workload.is_empty() {
      label == Some(workload)
    } else {
      true
    }
  })
  let groups = attribution_groups(rows, assignments)
  let saved = rows.filter_map(row => {
    let id = usage_file_text(row, "requestId")
    assignments
    .get(id)
    .map(label => { "requestId": id.to_json(), "workload": label.to_json() })
  })
  let selected_rows = selected.map(row => {
    guard row is Object(fields) else { abort("normalized row") }
    let copy = fields.copy()
    let label = assignments.get(usage_file_text(row, "requestId"))
    copy["workload"] = match label {
      Some(label) => label.to_json()
      None => Json::null()
    }
    copy["assigned"] = (label is Some(_)).to_json()
    Json::object(copy)
  })
  let view_summary = usage_file_summary(selected)
  let lines = [
    "MoonGate workload attribution (operator labels; estimated USD)",
    "Scope: " + scope.to_json().stringify(),
    "All saved rows: \{rows.length()}; assigned: \{assignments.length()}; unassigned: \{rows.length() - assignments.length()}; edits applied: \{applied}",
    "Filter: " +
    (if unassigned {
      "unassigned"
    } else if workload.is_empty() {
      "all"
    } else {
      workload.to_json().stringify()
    }),
    usage_file_summary_line("SELECTED", view_summary),
    "All workload groups:",
  ]
  for group in groups {
    let label = if compare_field(group, "assigned") == false.to_json() {
      "[unassigned]"
    } else {
      compare_field(group, "workload").stringify()
    }
    lines.push(usage_file_summary_line(label, group))
  }
  lines.push(
    "Labels are unverified operator commentary, not billing ownership or execution authority.",
  )
  lines.push(
    "Unknown costs remain missing; known USD is estimated, not settlement. Totals cover saved rows only.",
  )
  lines.push(
    "Filtering changes only the view; every usage row and assignment remains in saved JSON.",
  )
  if preview["partial"] == true.to_json() {
    lines.push(
      "PARTIAL SOURCE: absent requests are not attributed or included in totals.",
    )
  }
  preview["workloadReview"] = {
    "schema": "moongate.workload-review.v1",
    "scope": scope.to_json(),
    "assignments": saved.to_json(),
    "groups": groups.to_json(),
    "editsApplied": applied.to_json(),
    "view": {
      "workload": workload.to_json(),
      "unassignedOnly": unassigned.to_json(),
      "data": selected_rows.to_json(),
      "summary": view_summary,
    },
    "report": (lines.join("\n") + "\n").to_json(),
  }
  let result = Json::object(preview)
  if @encoding/utf8.encode(result.stringify(indent=2)).length() >
    4 * 1024 * 1024 {
    fail(
      "Workload artifact exceeds the 4 MiB reopen limit; use a smaller source export",
    )
  }
  result
}

///|
fn attribution_groups(
  rows : Array[Json],
  assignments : Map[String, String],
) -> Array[Json] {
  let buckets : Map[String, Array[Json]] = Map([])
  let unassigned = []
  for row in rows {
    match assignments.get(usage_file_text(row, "requestId")) {
      Some(label) => buckets.get_or_init(label, () => []).push(row)
      None => unassigned.push(row)
    }
  }
  let keys = buckets.keys().collect()
  keys.sort()
  let groups = keys.map(label => {
    guard usage_file_summary(buckets[label]) is Object(summary) else {
      abort("summary")
    }
    summary["workload"] = label.to_json()
    summary["assigned"] = true.to_json()
    Json::object(summary)
  })
  if !unassigned.is_empty() {
    guard usage_file_summary(unassigned) is Object(summary) else {
      abort("summary")
    }
    summary["workload"] = Json::null()
    summary["assigned"] = false.to_json()
    groups.push(Json::object(summary))
  }
  groups
}
