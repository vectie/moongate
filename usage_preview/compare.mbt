///|
/// Compare two local request exports. Deltas are after minus before, over the
/// selected rows only; they are not normalized rates or settled provider bills.
pub fn compare_usage_files_json(
  before : String,
  after : String,
  before_name? : String = "Before",
  after_name? : String = "After",
  app? : String = "",
  provider? : String = "",
  model? : String = "",
  before_start_day? : String = "",
  before_end_day? : String = "",
  after_start_day? : String = "",
  after_end_day? : String = "",
) -> Result[Json, String] {
  let read = (content, name, start_day, end_day) => {
    moongate_preview_usage_file_json(
      content,
      source_name=name,
      app~,
      provider~,
      model~,
      start_day~,
      end_day~,
    )
  }
  let before = match
    read(before, before_name, before_start_day, before_end_day) {
    Ok(value) => value
    Err(error) => return Err("Before: " + error)
  }
  let after = match read(after, after_name, after_start_day, after_end_day) {
    Ok(value) => value
    Err(error) => return Err("After: " + error)
  }
  for (label, preview) in [("Before", before), ("After", after)] {
    // Validate normalized selected totals directly. The single-file summary
    // omits out-of-range derived totals, so its aggregate cannot establish this
    // bound. Explicit totalTokens keeps its existing precedence over components.
    if compare_field(preview, "data") is Array(rows) {
      let mut tokens = 0.0
      for index, row in rows {
        let total = compare_number(row, "totalTokens")
        if total > 9007199254740991.0 {
          return Err(
            "\{label}: selected row \{index + 1} totalTokens exceeds the safe comparison limit (9007199254740991)",
          )
        }
        // Test remaining capacity before adding, avoiding rounded overflow.
        if total > 9007199254740991.0 - tokens {
          return Err(
            "\{label}: aggregate tokens exceeds the safe comparison limit (9007199254740991)",
          )
        }
        tokens += total
      }
    }
    let summary = compare_field(preview, "summary")
    for key in ["tokens", "knownEstimatedUsd"] {
      if compare_number(summary, key) > 9007199254740991.0 {
        return Err(
          "\{label}: aggregate \{key} exceeds the safe comparison limit (9007199254740991)",
        )
      }
    }
  }
  let partial = compare_field(before, "partial") == true.to_json() ||
    compare_field(after, "partial") == true.to_json()
  let summary = compare_summary(
    compare_field(before, "summary"),
    compare_field(after, "summary"),
    partial,
  )
  let by_model = compare_groups(before, after, "groups", partial)
  let by_app = compare_groups(before, after, "byApp", partial)
  let by_provider = compare_groups(before, after, "byProvider", partial)
  let before_meta = compare_source(before, before_start_day, before_end_day)
  let after_meta = compare_source(after, after_start_day, after_end_day)
  let caveats = [
    "Observed export differences only; no per-day normalization, matched-request reconciliation, or causal savings claim.",
    "Dates are inclusive UTC filters. Observed first/last days do not prove full interval coverage; undated rows are excluded by date filters.",
    "Amounts are file-supplied USD estimates, never settled provider charges. Unknown costs are excluded from known estimates.",
    "Estimated USD delta is unavailable when either source is partial or either selected group has missing costs. Known-estimate delta still compares only recorded amounts.",
    "No provider contacted, source file changed, or persistent accounting record written. Group labels are retained; inspect them before sharing.",
  ]
  let lines = [
    "MoonGate usage comparison (after minus before)",
    compare_source_line("BEFORE", before_meta),
    compare_source_line("AFTER", after_meta),
    "Filters: app=\{app}; provider=\{provider}; model=\{model}",
    if partial {
      "PARTIAL SOURCE: differences cover available selected rows only."
    } else {
      "Differences cover imported selected rows only; completeness outside these files is unverified."
    },
    compare_summary_line("TOTAL", summary),
  ]
  for
    (label, groups) in [
      ("By model", by_model),
      ("By app", by_app),
      ("By provider", by_provider),
    ] {
    lines.push(label + ":")
    for group in groups {
      // Quote data labels to keep embedded newlines from masquerading as report instructions.
      let key = compare_field(group, "key").stringify()
      let status = usage_file_text(group, "status")
      lines.push(compare_summary_line("\{key} [\{status}]", group))
    }
  }
  lines.push("Caveats:")
  for caveat in caveats {
    lines.push("- " + caveat)
  }
  Ok({
    "schema": "moongate.usage-comparison.v1",
    "direction": "after-minus-before",
    "before": before_meta,
    "after": after_meta,
    "filters": {
      "app": app.to_json(),
      "provider": provider.to_json(),
      "model": model.to_json(),
    },
    "summary": summary,
    "byModel": by_model.to_json(),
    "byApp": by_app.to_json(),
    "byProvider": by_provider.to_json(),
    "caveats": caveats.to_json(),
    "report": (lines.join("\n") + "\n").to_json(),
  })
}

///|
fn compare_field(value : Json, key : String) -> Json {
  moon_json_get(value, key).unwrap_or(Json::null())
}

///|
fn compare_number(value : Json, key : String) -> Double {
  match compare_field(value, key) {
    Number(number, ..) => number
    _ => 0.0
  }
}

///|
fn compare_source(preview : Json, start_day : String, end_day : String) -> Json {
  let rows = match compare_field(preview, "data") {
    Array(rows) => rows
    _ => []
  }
  let days = rows
    .map(row => usage_file_text(row, "date"))
    .filter(day => !day.is_empty())
  days.sort()
  {
    "sourceName": compare_field(preview, "sourceName"),
    "sourceTotal": compare_field(preview, "sourceTotal"),
    "importedRows": compare_field(preview, "importedRows"),
    "selectedRows": compare_field(preview, "total"),
    "partial": compare_field(preview, "partial"),
    "startDay": start_day.to_json(),
    "endDay": end_day.to_json(),
    "observedFirstDay": if days.is_empty() {
      Json::null()
    } else {
      days[0].to_json()
    },
    "observedLastDay": if days.is_empty() {
      Json::null()
    } else {
      days[days.length() - 1].to_json()
    },
    "summary": compare_field(preview, "summary"),
  }
}

///|
fn compare_summary(before : Json, after : Json, partial : Bool) -> Json {
  let delta : Map[String, Json] = Map([])
  for
    key in [
      "requests", "tokens", "knownEstimatedUsd", "missingCostCount", "undatedCount",
    ] {
    delta[key] = (compare_number(after, key) - compare_number(before, key)).to_json()
  }
  let percentages : Map[String, Json] = Map([])
  for key in ["requests", "tokens"] {
    let base = compare_number(before, key)
    percentages[key] = if base == 0.0 {
      Json::null()
    } else {
      ((compare_number(after, key) - base) / base * 100.0).to_json()
    }
  }
  let complete = !partial &&
    compare_number(before, "missingCostCount") == 0.0 &&
    compare_number(after, "missingCostCount") == 0.0
  {
    "before": before,
    "after": after,
    "delta": Json::object(delta),
    "percentChange": Json::object(percentages),
    "estimatedUsdDelta": if complete {
      delta["knownEstimatedUsd"]
    } else {
      Json::null()
    },
    "estimatedUsdDeltaAvailable": complete.to_json(),
  }
}

///|
fn compare_groups(
  before : Json,
  after : Json,
  field : String,
  partial : Bool,
) -> Array[Json] {
  let index = preview => {
    let groups : Map[String, Json] = Map([])
    if compare_field(preview, field) is Array(rows) {
      for row in rows {
        groups[usage_file_text(row, "key")] = row
      }
    }
    groups
  }
  let before_groups = index(before)
  let after_groups = index(after)
  let keys = before_groups.keys().collect()
  for key in after_groups.keys() {
    if !before_groups.contains(key) {
      keys.push(key)
    }
  }
  keys.sort_by((left, right) => left.lexical_compare(right))
  let empty = usage_file_summary([])
  keys.map(key => {
    let before = before_groups.get(key)
    let after = after_groups.get(key)
    let summary = compare_summary(
      before.unwrap_or(empty),
      after.unwrap_or(empty),
      partial,
    )
    guard summary is Object(fields) else { abort("comparison summary") }
    fields["key"] = key.to_json()
    fields["status"] = (if before is None {
      "added"
    } else if after is None {
      "removed"
    } else {
      "present"
    }).to_json()
    Json::object(fields)
  })
}

///|
fn compare_source_line(label : String, source : Json) -> String {
  let get = key => compare_field(source, key).stringify()
  "\{label} \{get("sourceName")}: selected \{get("selectedRows")} of \{get("importedRows")} available / \{get("sourceTotal")} source rows; partial=\{get("partial")}; requested UTC \{get("startDay")}..\{get("endDay")}; observed \{get("observedFirstDay")}..\{get("observedLastDay")}; undated=\{compare_number(compare_field(source, "summary"), "undatedCount")}"
}

///|
fn compare_summary_line(label : String, summary : Json) -> String {
  let before = compare_field(summary, "before")
  let after = compare_field(summary, "after")
  let delta = compare_field(summary, "delta")
  let change = key => compare_field(delta, key).stringify()
  let cost_delta = match compare_field(summary, "estimatedUsdDelta") {
    Null => "unavailable"
    value => value.stringify()
  }
  "\{label}: requests \{compare_number(before, "requests")} -> \{compare_number(after, "requests")} (delta \{change("requests")}); tokens \{compare_number(before, "tokens")} -> \{compare_number(after, "tokens")} (delta \{change("tokens")}); known estimated USD \{compare_number(before, "knownEstimatedUsd")} -> \{compare_number(after, "knownEstimatedUsd")} (recorded delta \{change("knownEstimatedUsd")}); estimated USD delta \{cost_delta}; missing costs \{compare_number(before, "missingCostCount")} -> \{compare_number(after, "missingCostCount")}; undated \{compare_number(before, "undatedCount")} -> \{compare_number(after, "undatedCount")}"
}
