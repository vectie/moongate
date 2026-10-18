///|
priv struct ResponseCapture {
  id : String
  model : String
  format : String
  state : String
  status : String
  terminal : Bool
  objects : Int32
  terminal_line : Json
  created : Json
  usage : Map[String, Json]
  incomplete_reason : Json
}

///|
fn capture_count(value : Json, label : String) -> Json raise {
  match value {
    Null => Json::null()
    Number(_, repr=Some(text)) =>
      match @exact_json.exact_count(text) {
        Some(n) => Json(n)
        None => fail("\{label}: expected an exact nonnegative safe integer")
      }
    _ => fail("\{label}: expected a JSON integer or null")
  }
}

///|
fn capture_usage(value : Json) -> Map[String, Json] raise {
  let usage : Map[String, Json] = Map([])
  match value {
    Null => ()
    Object(metrics) => {
      for key in ["input_tokens", "output_tokens", "total_tokens"] {
        usage[key] = capture_count(
          metrics.get(key).unwrap_or(Json::null()),
          "Usage \{key}",
        )
      }
      if usage["input_tokens"] is Number(input, ..) &&
        usage["output_tokens"] is Number(output, ..) &&
        usage["total_tokens"] is Number(total, ..) {
        if output > 9007199254740991.0 - input || total != input + output {
          fail(
            "Usage total_tokens must equal input_tokens plus output_tokens within the safe range",
          )
        }
      }
    }
    _ => fail("Usage must be an object or null")
  }
  usage
}

///|
fn is_terminal(status : String) -> Bool {
  ["completed", "incomplete", "failed", "cancelled"].contains(status)
}

///|
fn parse_response_capture(content : String) -> ResponseCapture raise {
  let text = content.trim()
  let format = if text.has_prefix("{") { "json" } else { "sse" }
  let events = if text.is_empty() {
    []
  } else if format == "json" {
    [{ payload: text.to_owned(), kind: "", line: 1, framed: true, }]
  } else {
    capture_events(content)
  }
  let mut id = ""
  let mut model = ""
  let mut status = "unrecognized"
  let mut created = Json::null()
  let mut terminal_line = Json::null()
  let mut terminal = false
  let mut closed = false
  let mut errored = false
  let mut sequence = -1.0
  let mut usage : Map[String, Json] = Map([])
  let mut incomplete_reason = Json::null()
  for event in events {
    let line = event.line
    if closed {
      fail(
        "Line \{line}: data after terminal outcome or error; supply one response per file",
      )
    }
    let value = @exact_json.parse_with_number_text(event.payload) catch {
      _ =>
        fail(
          "Line \{line}: invalid Responses JSON; [DONE] is not a Responses event",
        )
    }
    guard value is Object(fields) else {
      fail("Line \{line}: expected a Responses object")
    }
    reject_duplicate_keys(event.payload)
    let kind = if format == "json" {
      ""
    } else {
      guard fields.get("type") is Some(String(kind)) && !kind.is_empty() else {
        fail("Line \{line}: SSE payload requires a Responses event type")
      }
      if !event.kind.is_empty() && event.kind != kind {
        fail("Line \{line}: SSE event field disagrees with payload type")
      }
      match fields.get("sequence_number") {
        None => ()
        Some(value) => {
          guard capture_count(value, "Sequence number") is Number(n, ..) &&
            n > sequence else {
            fail(
              "Line \{line}: sequence_number must be an increasing nonnegative safe integer",
            )
          }
          sequence = n
        }
      }
      match fields.get("response_id") {
        None => ()
        Some(String(current)) if !id.is_empty() && current == id => ()
        _ =>
          fail("Line \{line}: response_id does not match the captured response")
      }
      kind
    }
    if format == "sse" && (kind == "error" || is_content_event(kind)) {
      if fields.contains("response") ||
        fields.contains("usage") ||
        fields.contains("object") {
        fail(
          "Line \{line}: ambiguous event contains unexpected response or usage fields",
        )
      }
      if kind == "error" {
        errored = true
        closed = true
      } else if id.is_empty() {
        fail(
          "Line \{line}: content event requires an earlier response lifecycle object",
        )
      }
      continue
    }
    let response = if format == "json" {
      fields
    } else {
      if ![
          "response.created", "response.queued", "response.in_progress", "response.completed",
          "response.incomplete", "response.failed",
        ].contains(kind) {
        fail("Line \{line}: unsupported Responses SSE event type")
      }
      guard fields.get("response") is Some(Object(response)) else {
        fail("Line \{line}: lifecycle event requires a response object")
      }
      if fields.contains("usage") || fields.contains("object") {
        fail("Line \{line}: ambiguous lifecycle envelope")
      }
      response
    }
    if response.get("object") != Some(Json("response")) {
      fail("Line \{line}: expected object type response")
    }
    guard response.get("id") is Some(String(current_id)) &&
      !current_id.trim().is_empty() &&
      response.get("model") is Some(String(current_model)) &&
      !current_model.trim().is_empty() else {
      fail("Line \{line}: nonempty response id and model are required")
    }
    if (!id.is_empty() && current_id != id) ||
      (!model.is_empty() && current_model != model) {
      fail("Line \{line}: response id or model changed inside one capture")
    }
    id = current_id
    model = current_model
    guard response.get("status") is Some(String(current_status)) &&
      !current_status.is_empty() else {
      fail("Line \{line}: response status is required")
    }
    status = if [
        "completed", "incomplete", "failed", "cancelled", "queued", "in_progress",
      ].contains(current_status) {
      current_status
    } else {
      "unrecognized"
    }
    if format == "sse" {
      let agrees = if kind == "response.created" {
        status == "queued" || status == "in_progress"
      } else {
        kind == "response." + status
      }
      if !agrees {
        fail(
          "Line \{line}: lifecycle event type disagrees with response status",
        )
      }
    }
    let timestamp = capture_count(
      response.get("created_at").unwrap_or(Json::null()),
      "created_at",
    )
    if created != Json::null() &&
      timestamp != Json::null() &&
      created != timestamp {
      fail("Line \{line}: created_at changed inside one capture")
    }
    if timestamp != Json::null() {
      created = timestamp
    }
    // Replace every snapshot, including null, so early usage can never become final usage.
    usage = capture_usage(response.get("usage").unwrap_or(Json::null()))
    incomplete_reason = match response.get("incomplete_details") {
      None | Some(Null) => Json::null()
      Some(Object(details)) =>
        match details.get("reason") {
          None | Some(Null) => Json::null()
          Some(String(reason)) =>
            Json(
              if ["max_output_tokens", "content_filter", "steered"].contains(
                  reason,
                ) {
                reason
              } else {
                "unrecognized"
              },
            )
          _ => fail("Line \{line}: incomplete reason must be a string or null")
        }
      _ => fail("Line \{line}: incomplete_details must be an object or null")
    }
    if is_terminal(status) {
      closed = true
      terminal = event.framed
      if terminal {
        terminal_line = Json(line)
      }
    }
  }
  let state = if events.is_empty() {
    "empty"
  } else if errored {
    "errored"
  } else if terminal {
    status
  } else if status == "unrecognized" {
    "unknown"
  } else {
    "interrupted"
  }
  {
    id,
    model,
    format,
    state,
    status,
    terminal,
    objects: events.length(),
    terminal_line,
    created,
    usage,
    incomplete_reason,
  }
}
