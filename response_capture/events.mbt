///|
priv struct CaptureEvent {
  payload : String
  kind : String
  line : Int32
  framed : Bool
}

///|
fn capture_events(content : String) -> Array[CaptureEvent] raise {
  let events : Array[CaptureEvent] = []
  let parts : Array[String] = []
  let mut first = 0
  let mut kind = ""
  let lines = content.split("\n").collect()
  for index, raw in lines {
    // A final empty split item is EOF, not a second newline.
    if index == lines.length() - 1 && raw.is_empty() {
      continue
    }
    let line = raw.strip_suffix("\r").unwrap_or(raw)
    if line.is_empty() {
      if !parts.is_empty() {
        events.push({
          payload: parts.join("\n"),
          kind,
          line: first,
          framed: true,
        })
        parts.clear()
      }
      kind = ""
    } else if line.has_prefix(":") ||
      line.has_prefix("id:") ||
      line.has_prefix("retry:") {
      ()
    } else if line.has_prefix("event:") {
      if !kind.is_empty() {
        fail("Line \{index + 1}: duplicate SSE event field")
      }
      let data = line[6:]
      kind = data.strip_prefix(" ").unwrap_or(data).to_owned()
    } else if line.has_prefix("data:") {
      if parts.is_empty() {
        first = index + 1
      }
      let data = line[5:]
      parts.push(data.strip_prefix(" ").unwrap_or(data).to_owned())
    } else {
      fail("Line \{index + 1}: expected an SSE data or metadata field")
    }
    if events.length() > 10000 {
      fail("Capture exceeds 10,000 SSE events")
    }
  }
  if !parts.is_empty() {
    events.push({ payload: parts.join("\n"), kind, line: first, framed: false, })
  }
  if events.length() > 10000 {
    fail("Capture exceeds 10,000 SSE events")
  }
  events
}

///|
fn is_content_event(kind : String) -> Bool {
  [
    "response.output_item.added", "response.output_item.done", "response.content_part.added",
    "response.content_part.done", "response.output_text.delta", "response.output_text.done",
    "response.output_text.annotation.added", "response.refusal.delta", "response.refusal.done",
    "response.function_call_arguments.delta", "response.function_call_arguments.done",
    "response.reasoning_summary_part.added", "response.reasoning_summary_part.done",
    "response.reasoning_summary_text.delta", "response.reasoning_summary_text.done",
    "response.reasoning_text.delta", "response.reasoning_text.done",
  ].contains(kind)
}
