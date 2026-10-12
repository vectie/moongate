///|
priv struct CaptureEvent {
  payload : String
  line : Int
  framed : Bool
}

///|
priv struct ChatCapture {
  id : String
  model : String
  format : String
  state : String
  objects : Int
  terminal_line : Json
  created : Json
  usage : Map[String, Json]
  finishes : Array[Json]
}

///|
fn capture_count(value : Json, label : String) -> Json raise {
  match value {
    Null => Json::null()
    Number(_, repr=Some(text)) =>
      match @exact_json.exact_count(text) {
        Some(n) => n.to_json()
        None => fail("\{label}: expected an exact nonnegative safe integer")
      }
    _ => fail("\{label}: expected a JSON integer or null")
  }
}

///|
fn capture_events(content : String) -> Array[CaptureEvent] raise {
  let events : Array[CaptureEvent] = []
  let parts : Array[String] = []
  let mut first = 0
  let lines = content.split("\n").collect()
  for index, raw in lines {
    // split's final empty item is EOF, not a second line terminator.
    if index == lines.length() - 1 && raw.is_empty() {
      continue
    }
    let line = raw.strip_suffix("\r").unwrap_or(raw)
    if line.is_empty() {
      if !parts.is_empty() {
        events.push({ payload: parts.join("\n"), line: first, framed: true, })
        parts.clear()
      }
    } else if line.has_prefix(":") ||
      line.has_prefix("event:") ||
      line.has_prefix("id:") ||
      line.has_prefix("retry:") {
      ()
    } else if line.has_prefix("data:") {
      if parts.is_empty() {
        first = index + 1
      }
      let data = line[5:]
      parts.push(data.strip_prefix(" ").unwrap_or(data).to_owned())
    } else {
      fail("Line \{index + 1}: expected SSE data or metadata field")
    }
    if events.length() > 10000 {
      fail("Capture exceeds 10,000 SSE events")
    }
  }
  if !parts.is_empty() {
    events.push({ payload: parts.join("\n"), line: first, framed: false, })
  }
  if events.length() > 10000 {
    fail("Capture exceeds 10,000 SSE events")
  }
  events
}

///|
fn parse_chat_capture(content : String) -> ChatCapture raise {
  let text = content.trim()
  let format = if text.has_prefix("{") { "json" } else { "sse" }
  let events = if text.is_empty() {
    []
  } else if format == "json" {
    [{ payload: text.to_owned(), line: 1, framed: true, }]
  } else {
    capture_events(content)
  }
  let mut id = ""
  let mut model = ""
  let mut objects = 0
  let mut created = Json::null()
  let mut terminal_line = Json::null()
  let mut done = false
  let mut errored = false
  let mut usage_seen = false
  let usage : Map[String, Json] = Map([])
  let choices : Map[Int, String?] = Map([])
  for event in events {
    let line = event.line
    if done {
      fail("Line \{line}: data after DONE; supply one request per file")
    }
    if event.payload == "[DONE]" && format == "sse" {
      done = event.framed
      terminal_line = if done { line.to_json() } else { Json::null() }
      // An unframed marker at EOF is incomplete, never completion evidence.
      continue
    }
    if errored || usage_seen {
      fail("Line \{line}: response data after error or final usage")
    }
    let value = @exact_json.parse_with_number_text(event.payload) catch {
      _ => fail("Line \{line}: invalid response JSON")
    }
    guard value is Object(fields) else {
      fail("Line \{line}: expected a response object")
    }
    objects += 1
    if objects > 10000 {
      fail("Capture exceeds 10,000 response objects")
    }
    if fields.contains("error") {
      if fields.contains("choices") ||
        fields.contains("usage") ||
        fields.contains("object") {
        fail("Line \{line}: ambiguous error and completion fields")
      }
      guard fields.get("error") is Some(Object(_)) else {
        fail("Line \{line}: expected an error object")
      }
      errored = true
      terminal_line = line.to_json()
      continue
    }
    let expected = if format == "json" {
      "chat.completion"
    } else {
      "chat.completion.chunk"
    }
    if fields.get("object") != Some(expected.to_json()) {
      fail("Line \{line}: unsupported response object type")
    }
    guard fields.get("id") is Some(String(current_id)) &&
      !current_id.trim().is_empty() &&
      fields.get("model") is Some(String(current_model)) &&
      !current_model.trim().is_empty() else {
      fail("Line \{line}: nonempty response id and model are required")
    }
    if (!id.is_empty() && id != current_id) ||
      (!model.is_empty() && model != current_model) {
      fail("Line \{line}: response id or model changed inside one capture")
    }
    id = current_id
    model = current_model
    let timestamp = capture_count(
      fields.get("created").unwrap_or(Json::null()),
      "Line \{line} created",
    )
    if created != Json::null() &&
      timestamp != Json::null() &&
      created != timestamp {
      fail("Line \{line}: creation timestamp changed inside one capture")
    }
    if timestamp != Json::null() {
      created = timestamp
    }
    guard fields.get("choices") is Some(Array(current_choices)) else {
      fail("Line \{line}: choices must be an array")
    }
    let indices : Map[Int, Bool] = Map([])
    for choice in current_choices {
      guard choice is Object(c) else {
        fail("Line \{line}: expected a choice object")
      }
      let index = capture_count(
        c.get("index").unwrap_or(Json::null()),
        "Choice index",
      )
      guard index is Number(index, ..) && index <= 9999.0 else {
        fail("Line \{line}: choice index must be between 0 and 9999")
      }
      let index = index.to_int()
      if indices.contains(index) || choices.get(index) is Some(Some(_)) {
        fail("Line \{line}: duplicate or already finished choice index")
      }
      indices[index] = true
      let body_key = if format == "json" { "message" } else { "delta" }
      guard c.get(body_key) is Some(Object(_)) else {
        fail("Line \{line}: expected a choice message or delta object")
      }
      choices[index] = match c.get("finish_reason") {
        None | Some(Null) => None
        Some(String(reason)) if !reason.is_empty() =>
          Some(
            if [
                "stop", "length", "content_filter", "tool_calls", "function_call",
              ].contains(reason) {
              reason
            } else {
              "unrecognized"
            },
          )
        _ =>
          fail("Line \{line}: finish_reason must be a nonempty string or null")
      }
    }
    match fields.get("usage") {
      None | Some(Null) => ()
      Some(Object(metrics)) => {
        if format == "sse" && !current_choices.is_empty() {
          fail("Line \{line}: final SSE usage must have empty choices")
        }
        for key in ["prompt_tokens", "completion_tokens", "total_tokens"] {
          usage[key] = capture_count(
            metrics.get(key).unwrap_or(Json::null()),
            "Usage \{key}",
          )
        }
        if usage["prompt_tokens"] is Number(input, ..) &&
          usage["completion_tokens"] is Number(output, ..) &&
          usage["total_tokens"] is Number(total, ..) {
          if output > 9007199254740991.0 - input || total != input + output {
            fail(
              "Line \{line}: total_tokens must equal prompt_tokens plus completion_tokens within the safe range",
            )
          }
        }
        usage_seen = true
      }
      _ => fail("Line \{line}: usage must be an object or null")
    }
    if format == "json" {
      terminal_line = line.to_json()
    }
  }
  let finished = !choices.is_empty() &&
    choices.values().all(value => value is Some(_))
  let state = if errored {
    "errored"
  } else if events.is_empty() {
    "empty"
  } else if finished && (format == "json" || done) {
    "completed"
  } else {
    "incomplete"
  }
  let indexes = choices.keys().collect()
  indexes.sort()
  let finishes : Array[Json] = indexes.map(index => {
    "index": index.to_json(),
    "finishReason": match choices[index] {
      Some(reason) => reason.to_json()
      None => Json::null()
    },
  })
  {
    id,
    model,
    format,
    state,
    objects,
    terminal_line,
    created,
    usage,
    finishes,
  }
}
