///|
fn render_report(result : Json) -> String {
  let lines = [
    "MoonGate saved provider Costs review (USD)",
    "Scope assertion (not verified): " +
    field(result, "scopeAssertion").stringify(),
    "Local provider=" +
    field(result, "provider").stringify() +
    "; app=" +
    field(result, "app").stringify(),
    "Provider project=" +
    field(result, "project").stringify() +
    "; line_item=" +
    field(result, "lineItem").stringify(),
    "Partial local source: " +
    field(result, "localSourcePartial").stringify() +
    "; provider has_more: " +
    field(result, "providerHasMore").stringify() +
    "; undated selected rows: " +
    field(result, "localUndatedRows").stringify(),
    "Local selected rows: " +
    field(result, "localSelectedRows").stringify() +
    " of " +
    field(result, "localImportedRows").stringify() +
    "; provider selected results: " +
    field(result, "providerSelectedResults").stringify() +
    " of " +
    field(result, "providerSourceResults").stringify(),
  ]
  if field(result, "days") is Array(days) {
    for day in days {
      lines.push(
        text(day, "day") +
        ": local known estimate=" +
        field(day, "localKnownEstimatedUsd").stringify() +
        "; provider known reported=" +
        field(day, "providerKnownReportedUsd").stringify() +
        "; reported minus estimated=" +
        field(day, "reportedMinusEstimatedUsd").stringify() +
        "; blockers=" +
        field(day, "differenceBlockers").stringify(),
      )
    }
  }
  lines.push(
    "Paired days: " +
    field(result, "pairedDays").stringify() +
    "; paired reported minus estimated USD: " +
    field(result, "pairedReportedMinusEstimatedUsd").stringify(),
  )
  lines.push(
    "Differences compare only available corresponding day observations under the caller's scope assertion. Capture completeness, invoice amounts, settled charges and causes of differences are not established. Null is unavailable, never zero. No provider contacted or persistent usage changed.",
  )
  lines.join("\n") + "\n"
}

///|
/// Produce spreadsheet review rows using the same validation and comparison.
/// Text is quoted and apostrophe-prefixed; null numeric evidence stays blank.
pub fn export_openai_costs_review_csv(
  usage : String,
  costs : String,
  provider~ : String,
  scope~ : String,
  app~ : String = "",
  project~ : String = "",
  line_item~ : String = "",
) -> Result[String, String] {
  let result = match
    review_openai_costs_json(
      usage,
      costs,
      provider~,
      scope~,
      app~,
      project~,
      line_item~,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let columns = [
    "day", "localRequests", "localKnownEstimateCount", "localMissingEstimateCount",
    "localKnownEstimatedUsd", "providerBucketPresent", "providerResultCount", "providerKnownAmountCount",
    "providerMissingAmountCount", "providerKnownReportedUsd", "reportedMinusEstimatedUsd",
    "differenceBlockers",
  ]
  let provenance = [
    "currency", "scopeAssertion", "scopeVerified", "provider", "app", "project",
    "lineItem", "localSourcePartial", "providerHasMore", "localUndatedRows", "evidenceKind",
  ]
  let lines = [(columns + provenance).join(",")]
  if field(result, "days") is Array(days) {
    for day in days {
      let cells = columns.map(key => csv_cell(field(day, key)))
      for key in provenance {
        cells.push(csv_cell(field(result, key)))
      }
      lines.push(cells.join(","))
    }
  }
  let output = lines.join("\r\n") + "\r\n"
  if @utf8.encode(output).length() > 4 * 1024 * 1024 {
    return Err("Cost review CSV exceeds 4 MiB")
  }
  Ok(output)
}

///|
fn csv_cell(value : Json) -> String {
  match value {
    Null => ""
    String(value) => "\"'" + value.replace_all(old="\"", new="\"\"") + "\""
    Array(_) => csv_cell(Json(value.stringify()))
    _ => value.stringify()
  }
}
