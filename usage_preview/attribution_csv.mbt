///|
/// Export selected request rows, or all workload groups, with inert text cells.
/// Group totals always cover all saved rows and are independent of view filters.
pub fn export_workload_csv(
  content : String,
  scope~ : String,
  view? : String = "groups",
  workload? : String = "",
  unassigned? : Bool = false,
) -> Result[String, String] {
  if !["groups", "requests"].contains(view) {
    return Err("CSV view must be groups or requests")
  }
  if view == "groups" && (!workload.is_empty() || unassigned) {
    return Err("Group CSV covers all rows; filters apply to request CSV only")
  }
  let output = match
    attribute_usage_file_json(content, scope~, workload~, unassigned~) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let review = compare_field(output, "workloadReview")
  let columns = if view == "groups" {
    [
      "workload", "assigned", "requests", "tokens", "knownEstimatedUsd", "missingCostCount",
      "undatedCount",
    ]
  } else {
    [
      "requestId", "workload", "assigned", "appType", "providerId", "model", "date",
      "inputTokens", "outputTokens", "totalTokens", "totalCostUsd",
    ]
  }
  let rows = if view == "groups" {
    compare_field(review, "groups")
  } else {
    compare_field(compare_field(review, "view"), "data")
  }
  guard rows is Array(rows) else { return Err("Expected workload rows") }
  let headers = columns +
    [
      "scope", "sourceTotal", "savedRows", "partialSource", "sourceCoverageUnknown",
      "attributionEvidence",
    ]
  let lines = [headers.join(",")]
  for row in rows {
    let cells = columns.map(key => usage_export_cell(compare_field(row, key)))
    for
      value in [
        scope.to_json(),
        compare_field(output, "sourceTotal"),
        compare_field(output, "total"),
        compare_field(output, "partial"),
        (compare_field(output, "sourceCoverageUnknown") == true.to_json()).to_json(),
        "operator-authored-unverified".to_json(),
      ] {
      cells.push(usage_export_cell(value))
    }
    lines.push(cells.join(","))
  }
  let result = lines.join("\r\n") + "\r\n"
  if @encoding/utf8.encode(result).length() > 8 * 1024 * 1024 {
    return Err("CSV output exceeds 8 MiB")
  }
  Ok(result)
}
