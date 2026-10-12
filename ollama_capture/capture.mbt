///|
priv struct Capture {
  model : String
  state : String
  shape : String
  chunk_count : Int
  terminal_line : Json
  reason : Json
  created_at : Json
  metrics : Map[String, Json]
}

///|
fn parse_capture(content : String) -> Result[Capture, String] {
  let objects : Array[(Int, Json)] = []
  // A pretty-printed single JSON response is accepted as one object. Otherwise
  // each nonblank physical line must contain exactly one NDJSON object.
  let whole = try @exact_json.parse_with_number_text(content) catch {
    error => Err(error)
  } noraise {
    value => Ok(value)
  }
  match whole {
    Ok(Object(fields)) => {
      let mut first_line = 1
      for line in content.split("\n") {
        if !line.trim().is_empty() {
          break
        }
        first_line += 1
      }
      objects.push((first_line, Json::object(fields)))
    }
    Ok(_) => return Err("Expected a response object or response NDJSON")
    Err(_) =>
      for index, line in content.split("\n").collect() {
        if line.trim().is_empty() {
          continue
        }
        if objects.length() >= 10000 {
          return Err("Capture exceeds the 10,000 response-object limit")
        }
        let value = @exact_json.parse_with_number_text(line) catch {
          _ => return Err("Line \{index + 1}: invalid JSON")
        }
        objects.push((index + 1, value))
      }
  }
  let mut model = ""
  let mut shape = "unknown"
  let mut state = if objects.is_empty() { "empty" } else { "incomplete" }
  let mut terminal_line = Json::null()
  let mut created_at = Json::null()
  let mut reason = Json::null()
  let mut metrics : Map[String, Json] = Map([])
  for (line, value) in objects {
    if terminal_line != Json::null() {
      return Err(
        "Line \{line}: data after terminal response; supply one request/stream per file",
      )
    }
    guard value is Object(fields) else {
      return Err("Line \{line}: expected an object")
    }
    if fields.contains("error") {
      if fields.contains("done") ||
        fields.contains("response") ||
        fields.contains("message") {
        return Err("Line \{line}: ambiguous error and response fields")
      }
      guard fields.get("error") is Some(String(_)) else {
        return Err("Line \{line}: error must be a string")
      }
      // The error message can contain private input; preserve only its presence.
      state = "errored"
      terminal_line = line.to_json()
      continue
    }
    guard fields.get("model") is Some(String(current_model)) &&
      !current_model.trim().is_empty() else {
      return Err("Line \{line}: expected a nonempty model")
    }
    if !model.is_empty() && current_model != model {
      return Err("Line \{line}: model changes inside one capture")
    }
    model = current_model
    let current_shape = if fields.get("response") is Some(String(_)) &&
      !fields.contains("message") {
      "generate"
    } else if fields.get("message") is Some(Object(_)) &&
      !fields.contains("response") {
      "chat"
    } else {
      return Err(
        "Line \{line}: expected either generate response text or a chat message object",
      )
    }
    if shape != "unknown" && shape != current_shape {
      return Err("Line \{line}: response shape changes inside one capture")
    }
    shape = current_shape
    guard fields.get("done") is Some(True | False) else {
      return Err("Line \{line}: done must be a boolean")
    }
    let current_metrics : Map[String, Json] = Map([])
    for
      key in [
        "prompt_eval_count", "eval_count", "prompt_eval_cached_count", "total_duration",
        "load_duration", "prompt_eval_duration", "eval_duration",
      ] {
      let value = fields.get(key).unwrap_or(Json::null())
      let parsed = match value {
        Null => Json::null()
        Number(_, repr=Some(text)) =>
          match @exact_json.exact_count(text) {
            Some(n) => n.to_json()
            None =>
              return Err(
                "Line \{line}: \{key} must be an exact nonnegative integer up to 9007199254740991",
              )
          }
        _ => return Err("Line \{line}: \{key} must be a JSON integer or null")
      }
      current_metrics[key] = parsed
    }
    if current_metrics["prompt_eval_count"] is Number(input, ..) &&
      current_metrics["prompt_eval_cached_count"] is Number(cached, ..) &&
      cached > input {
      return Err("Line \{line}: cached prompt count exceeds total prompt count")
    }
    if fields.get("done") == Some(true.to_json()) {
      state = "completed"
      terminal_line = line.to_json()
      metrics = current_metrics
      created_at = match fields.get("created_at") {
        None | Some(Null) => Json::null()
        Some(String(value)) => value.to_json()
        _ => return Err("Line \{line}: created_at must be a string or null")
      }
      reason = match fields.get("done_reason") {
        None | Some(Null) => Json::null()
        Some(String(value)) =>
          if ["stop", "length", "load", "unload"].contains(value) {
            value.to_json()
          } else {
            "unrecognized".to_json()
          }
        _ => return Err("Line \{line}: done_reason must be a string or null")
      }
    }
  }
  Ok({
    model,
    state,
    shape,
    chunk_count: objects.length(),
    terminal_line,
    reason,
    created_at,
    metrics,
  })
}
