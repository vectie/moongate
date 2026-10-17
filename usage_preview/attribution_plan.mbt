///|
fn attribution_label(label : String, field : String) -> Unit raise {
  if label.trim().is_empty() || label.length() > 200 {
    fail(
      "\{field} must contain 1 to 200 UTF-16 units and not be whitespace-only",
    )
  }
}

///|
fn attribution_count(value : Json) -> Double raise {
  guard value is Number(_, repr=Some(text)) &&
    @exact_json.exact_count(text) is Some(count) else {
    fail("Token counts must be exact nonnegative safe JSON integers")
  }
  count
}

///|
fn attribution_parse(content : String) -> Json raise {
  if @encoding/utf8.encode(content).length() > 4 * 1024 * 1024 {
    fail("Attribution input exceeds 4 MiB")
  }
  let parsed = @exact_json.parse_with_number_text(content) catch {
    _ => fail("Attribution input must be valid JSON")
  }
  // Syntax is already valid. Track decoded object keys to reject ambiguous edits.
  let scopes : Array[Map[String, Bool]] = []
  for i = 0; i < content.length(); {
    if content[i] == '{' {
      scopes.push(Map([]))
    } else if content[i] == '}' {
      ignore(scopes.pop())
    } else if content[i] == '"' {
      let mut end = i + 1
      while content[end] != '"' {
        if content[end] == '\\' {
          end += 1
        }
        end += 1
      }
      end += 1
      let mut next = end
      while next < content.length() &&
            [32U, 9U, 13U, 10U].contains(content[next].to_uint()) {
        next += 1
      }
      if next < content.length() && content[next] == ':' {
        guard @json.parse(content[i:end]) is String(key) else {
          fail("Invalid key")
        }
        let keys = scopes[scopes.length() - 1]
        if keys.contains(key) {
          fail("Duplicate decoded JSON object key")
        }
        keys[key] = true
      }
      continue end
    }
    continue i + 1
  }
  parsed
}

///|
fn attribution_apply_plan(
  content : String,
  scope : String,
  ids : Map[String, Bool],
  assignments : Map[String, String],
) -> Int raise {
  guard attribution_parse(content) is Object(plan) &&
    plan.length() == 3 &&
    plan.get("schema") == Some("moongate.workload-plan.v1".to_json()) &&
    plan.get("scope") == Some(scope.to_json()) &&
    plan.get("changes") is Some(Array(changes)) else {
    fail(
      "Plan requires schema moongate.workload-plan.v1, matching scope and changes only",
    )
  }
  if changes.length() > 10000 {
    fail("Plan exceeds 10,000 edits")
  }
  let seen : Map[String, Bool] = Map([])
  for index, change in changes {
    guard change is Object(fields) &&
      fields.length() == 3 &&
      fields.get("requestId") is Some(String(id)) &&
      fields.get("expectedWorkload") is Some(expected) &&
      fields.get("workload") is Some(next) else {
      fail(
        "Edit \{index + 1}: requestId, expectedWorkload and workload are required",
      )
    }
    for label in [expected, next] {
      match label {
        Null => ()
        String(label) => attribution_label(label, "workload")
        _ =>
          fail("Edit \{index + 1}: workload must be a nonempty string or null")
      }
    }
    if !ids.contains(id) || seen.contains(id) {
      fail("Edit \{index + 1}: unknown or duplicate requestId; no edits saved")
    }
    seen[id] = true
    let previous = match assignments.get(id) {
      Some(label) => label.to_json()
      None => Json::null()
    }
    if expected != previous {
      fail(
        "Edit \{index + 1}: expectedWorkload differs from current label; no edits saved",
      )
    }
    match next {
      String(label) => assignments[id] = label
      _ => assignments.remove(id)
    }
  }
  changes.length()
}
