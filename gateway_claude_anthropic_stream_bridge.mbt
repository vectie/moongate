///|
async fn ProxyService::forward_openai_chat_sse_as_anthropic(
  _self : ProxyService,
  usage : UsageRequest,
  reader : &@io.Reader,
  events : Array[Json],
  w : @httpx.ResponseWriter,
) -> Int? {
  let mut first_token_ms : Int? = None
  let state = OpenAIChatAnthropicStreamState::new()
  let mut finished = false
  while reader.read_until("\n") is Some(line) {
    guard line is [.. "data: ", .. rest] else { continue }
    let data = rest.trim().to_owned()
    if data == "[DONE]" {
      finished = true
      for event in state.finish() {
        w.write("event: \{event.event_type}\n")
        w.write("data: \{event.data}\n\n")
        w.flush()
      }
      break
    }
    let parsed = @json.parse(data) catch { _ => continue }
    events.push(parsed)
    first_token_ms = usage.first_stream_event_ms(first_token_ms)
    for event in state.push_chunk(parsed) {
      w.write("event: \{event.event_type}\n")
      w.write("data: \{event.data}\n\n")
      w.flush()
    }
  }
  if !finished {
    for event in state.finish() {
      w.write("event: \{event.event_type}\n")
      w.write("data: \{event.data}\n\n")
      w.flush()
    }
  }
  first_token_ms
}

///|
fn openai_chat_stream_chunk_to_anthropic_events(
  chunk : Json,
) -> Array[StreamEvent] {
  let state = OpenAIChatAnthropicStreamState::new()
  state.push_chunk(chunk)
}

///|
async fn ProxyService::forward_anthropic_sse_passthrough(
  _self : ProxyService,
  usage : UsageRequest,
  reader : &@io.Reader,
  events : Array[Json],
  w : @httpx.ResponseWriter,
) -> Int? {
  let mut first_token_ms : Int? = None
  while reader.read_until("\n") is Some(line) {
    if line is [.. "data: ", .. rest] {
      let data = rest.trim().to_owned()
      let parsed = @json.parse(data) catch { _ => Json::null() }
      if parsed != Json::null() {
        events.push(parsed)
        first_token_ms = usage.first_stream_event_ms(first_token_ms)
      }
    }
    w.write(line)
    w.write("\n")
    w.flush()
  }
  first_token_ms
}

///|
async fn ProxyService::forward_gemini_native_sse_as_anthropic(
  _self : ProxyService,
  usage : UsageRequest,
  gemini_shadow : GeminiShadowStore,
  reader : &@io.Reader,
  events : Array[Json],
  provider_id : String,
  session_id : String?,
  w : @httpx.ResponseWriter,
) -> Int? {
  let mut first_token_ms : Int? = None
  let state = GeminiNativeAnthropicStreamState::new()
  let mut finished = false
  while reader.read_until("\n") is Some(line) {
    guard line is [.. "data: ", .. rest] else { continue }
    let data = rest.trim().to_owned()
    if data == "[DONE]" {
      finished = true
      for event in state.finish() {
        w.write("event: \{event.event_type}\n")
        w.write("data: \{event.data}\n\n")
        w.flush()
      }
      break
    }
    let parsed = @json.parse(data) catch { _ => continue }
    events.push(parsed)
    first_token_ms = usage.first_stream_event_ms(first_token_ms)
    for event in state.push_chunk(parsed) {
      w.write("event: \{event.event_type}\n")
      w.write("data: \{event.data}\n\n")
      w.flush()
    }
  }
  if !finished {
    for event in state.finish() {
      w.write("event: \{event.event_type}\n")
      w.write("data: \{event.data}\n\n")
      w.flush()
    }
  }
  match (session_id, state.shadow_turn()) {
    (Some(session_id), Some(turn)) =>
      gemini_shadow.record_assistant_turn(provider_id, session_id, turn)
    _ => ()
  }
  first_token_ms
}

///|
fn gemini_native_stream_chunk_to_anthropic_events(
  chunk : Json,
) -> Array[StreamEvent] {
  let state = GeminiNativeAnthropicStreamState::new()
  state.push_chunk(chunk)
}

///|
priv struct GeminiNativeAnthropicToolSnapshot {
  mut id : String?
  mut name : String
  mut args : Json
  mut thought_signature : String?
}

///|
priv struct GeminiNativeAnthropicStreamState {
  mut message_id : String?
  mut model : String?
  mut next_content_index : Int
  mut has_sent_message_start : Bool
  mut text_block_index : Int?
  mut text_block_open : Bool
  mut accumulated_text : String
  tool_snapshots : Array[GeminiNativeAnthropicToolSnapshot]
  mut latest_usage : Json?
  mut latest_finish_reason : String?
  mut blocked_text : String?
  mut text_thought_signature : String?
  mut finished : Bool
}

///|
fn GeminiNativeAnthropicStreamState::new() -> GeminiNativeAnthropicStreamState {
  {
    message_id: None,
    model: None,
    next_content_index: 0,
    has_sent_message_start: false,
    text_block_index: None,
    text_block_open: false,
    accumulated_text: "",
    tool_snapshots: [],
    latest_usage: None,
    latest_finish_reason: None,
    blocked_text: None,
    text_thought_signature: None,
    finished: false,
  }
}

///|
fn GeminiNativeAnthropicStreamState::push_chunk(
  self : GeminiNativeAnthropicStreamState,
  chunk : Json,
) -> Array[StreamEvent] {
  let events : Array[StreamEvent] = []
  guard chunk is Object(obj) else { return events }
  if self.message_id is None {
    self.message_id = json_string_from_map(obj, "responseId")
  }
  if self.model is None {
    self.model = json_string_from_map(obj, "modelVersion")
  }
  if obj.get("usageMetadata") is Some(usage) {
    self.latest_usage = Some(usage)
  }
  if !self.has_sent_message_start {
    events.push(self.message_start_event())
    self.has_sent_message_start = true
  }
  if gemini_prompt_block_reason(obj) is Some(reason) {
    self.blocked_text = Some(
      "Request blocked by Gemini safety filters: \{reason}",
    )
    self.latest_finish_reason = Some("SAFETY")
  }
  guard obj.get("candidates") is Some(Array(candidates)) else { return events }
  guard candidates.get(0) is Some(Object(candidate)) else { return events }
  if json_string_from_map(candidate, "finishReason") is Some(reason) {
    self.latest_finish_reason = Some(reason)
  }
  guard candidate.get("content") is Some(Object(content)) else { return events }
  guard content.get("parts") is Some(Array(parts)) else { return events }
  self.merge_tool_snapshots_from_parts(parts)
  self.merge_text_thought_signature_from_parts(parts)
  let visible_text = gemini_visible_text_from_parts(parts)
  if !visible_text.is_empty() {
    let is_cumulative = visible_text.has_prefix(self.accumulated_text)
    let delta = if is_cumulative {
      visible_text[self.accumulated_text.length():].to_owned()
    } else {
      visible_text
    }
    if !delta.is_empty() {
      let index = self.ensure_text_block(events)
      events.push(
        anthropic_content_block_delta_event(index, "text_delta", "text", delta),
      )
      if is_cumulative {
        self.accumulated_text = visible_text
      } else {
        self.accumulated_text = self.accumulated_text + delta
      }
    }
  }
  events
}

///|
fn GeminiNativeAnthropicStreamState::finish(
  self : GeminiNativeAnthropicStreamState,
) -> Array[StreamEvent] {
  let events : Array[StreamEvent] = []
  if self.finished {
    return events
  }
  self.finished = true
  if !self.has_sent_message_start {
    events.push(self.message_start_event())
    self.has_sent_message_start = true
  }
  if self.accumulated_text.is_empty() && self.blocked_text is Some(text) {
    let index = self.ensure_text_block(events)
    events.push(
      anthropic_content_block_delta_event(index, "text_delta", "text", text),
    )
    self.accumulated_text = text
  }
  if self.text_block_open && self.text_block_index is Some(index) {
    events.push(anthropic_content_block_stop_event(index))
    self.text_block_open = false
  }
  self.emit_tool_snapshots(events)
  let has_tools = !self.tool_snapshots.is_empty()
  events.push(
    self.message_delta_event(
      gemini_finish_reason_to_anthropic(
        self.latest_finish_reason.unwrap_or("STOP"),
        has_tools,
      ),
    ),
  )
  events.push(anthropic_message_stop_stream_event())
  events
}

///|
fn GeminiNativeAnthropicStreamState::message_start_event(
  self : GeminiNativeAnthropicStreamState,
) -> StreamEvent {
  {
    event_type: "message_start",
    data: Json::object({
      "type": Json::string("message_start"),
      "message": Json::object({
        "id": Json::string(self.message_id.unwrap_or("")),
        "type": Json::string("message"),
        "role": Json::string("assistant"),
        "model": Json::string(self.model.unwrap_or("")),
        "usage": gemini_native_stream_anthropic_usage_json(self.latest_usage),
      }),
    }).stringify(),
  }
}

///|
fn GeminiNativeAnthropicStreamState::ensure_text_block(
  self : GeminiNativeAnthropicStreamState,
  events : Array[StreamEvent],
) -> Int {
  let index = match self.text_block_index {
    Some(index) => index
    None => {
      let index = self.next_content_index
      self.next_content_index += 1
      self.text_block_index = Some(index)
      index
    }
  }
  if !self.text_block_open {
    events.push(anthropic_content_block_start_event(index, "text"))
    self.text_block_open = true
  }
  index
}

///|
fn GeminiNativeAnthropicStreamState::merge_tool_snapshots_from_parts(
  self : GeminiNativeAnthropicStreamState,
  parts : Array[Json],
) -> Unit {
  let mut position = 0
  for part in parts {
    guard part is Object(part_obj) else { continue }
    guard part_obj.get("functionCall") is Some(Object(function_call)) else {
      continue
    }
    let incoming_id = match json_string_from_map(function_call, "id") {
      Some(id) if !id.is_empty() => Some(id)
      _ => None
    }
    let snapshot = self.tool_snapshot_for_position(position, incoming_id)
    snapshot.id = match incoming_id {
      Some(id) => Some(id)
      None =>
        match snapshot.id {
          Some(existing) => Some(existing)
          None => Some(generate_gemini_synth_tool_call_id(position))
        }
    }
    snapshot.name = json_string_from_map(function_call, "name").unwrap_or(
      snapshot.name,
    )
    snapshot.args = function_call.get("args").unwrap_or(Json::object({}))
    match gemini_part_thought_signature(part_obj) {
      Some(signature) => snapshot.thought_signature = Some(signature)
      None => ()
    }
    position += 1
  }
}

///|
fn GeminiNativeAnthropicStreamState::merge_text_thought_signature_from_parts(
  self : GeminiNativeAnthropicStreamState,
  parts : Array[Json],
) -> Unit {
  for part in parts {
    guard part is Object(part_obj) else { continue }
    if part_obj.get("functionCall") is Some(_) {
      continue
    }
    guard part_obj.get("text") is Some(_) else { continue }
    match gemini_part_thought_signature(part_obj) {
      Some(signature) => self.text_thought_signature = Some(signature)
      None => ()
    }
  }
}

///|
fn gemini_part_thought_signature(part_obj : Map[String, Json]) -> String? {
  match json_string_from_map(part_obj, "thoughtSignature") {
    Some(signature) => Some(signature)
    None => json_string_from_map(part_obj, "thought_signature")
  }
}

///|
fn GeminiNativeAnthropicStreamState::tool_snapshot_for_position(
  self : GeminiNativeAnthropicStreamState,
  position : Int,
  incoming_id : String?,
) -> GeminiNativeAnthropicToolSnapshot {
  if incoming_id is Some(id) {
    let mut index = 0
    for snapshot in self.tool_snapshots {
      if snapshot.id == Some(id) {
        return snapshot
      }
      if index == position &&
        snapshot.id is Some(existing) &&
        existing.has_prefix("gemini_synth_") {
        return snapshot
      }
      index += 1
    }
  }
  if self.tool_snapshots.get(position) is Some(snapshot) {
    return snapshot
  }
  while self.tool_snapshots.length() <= position {
    self.tool_snapshots.push({
      id: None,
      name: "",
      args: Json::object({}),
      thought_signature: None,
    })
  }
  self.tool_snapshots[position]
}

///|
fn GeminiNativeAnthropicStreamState::emit_tool_snapshots(
  self : GeminiNativeAnthropicStreamState,
  events : Array[StreamEvent],
) -> Unit {
  for snapshot in self.tool_snapshots {
    if snapshot.name.is_empty() && snapshot.args == Json::object({}) {
      continue
    }
    let index = self.next_content_index
    self.next_content_index += 1
    events.push(
      anthropic_tool_block_start_event(
        index,
        snapshot.id.unwrap_or(""),
        if snapshot.name.is_empty() {
          "unknown"
        } else {
          snapshot.name
        },
      ),
    )
    events.push(
      anthropic_tool_input_delta_event(index, snapshot.args.stringify()),
    )
    events.push(anthropic_content_block_stop_event(index))
  }
}

///|
fn GeminiNativeAnthropicStreamState::shadow_turn(
  self : GeminiNativeAnthropicStreamState,
) -> GeminiAssistantTurn? {
  let parts : Array[Json] = []
  let shadow_text = if self.accumulated_text.is_empty() {
    self.blocked_text
  } else {
    Some(self.accumulated_text)
  }
  match (shadow_text, self.text_thought_signature) {
    (Some(text), Some(signature)) =>
      parts.push(
        Json::object({
          "text": Json::string(text),
          "thoughtSignature": Json::string(signature),
        }),
      )
    (Some(text), None) =>
      parts.push(Json::object({ "text": Json::string(text) }))
    (None, Some(signature)) =>
      parts.push(
        Json::object({
          "text": Json::string(""),
          "thoughtSignature": Json::string(signature),
        }),
      )
    (None, None) => ()
  }
  let tool_calls : Array[GeminiToolCallMeta] = []
  for snapshot in self.tool_snapshots {
    if snapshot.name.is_empty() && snapshot.args == Json::object({}) {
      continue
    }
    let function_call = Json::object({
      "id": Json::string(snapshot.id.unwrap_or("")),
      "name": Json::string(snapshot.name),
      "args": snapshot.args,
    })
    let part : Map[String, Json] = { "functionCall": function_call }
    match snapshot.thought_signature {
      Some(signature) => part["thoughtSignature"] = Json::string(signature)
      None => ()
    }
    parts.push(Json::object(part))
    tool_calls.push({
      id: snapshot.id,
      name: snapshot.name,
      thought_signature: snapshot.thought_signature,
    })
  }
  if parts.is_empty() {
    return None
  }
  Some({
    assistant_content: Json::object({ "parts": Json::array(parts) }),
    tool_calls,
  })
}

///|
fn GeminiNativeAnthropicStreamState::message_delta_event(
  self : GeminiNativeAnthropicStreamState,
  stop_reason : String,
) -> StreamEvent {
  {
    event_type: "message_delta",
    data: Json::object({
      "type": Json::string("message_delta"),
      "delta": Json::object({
        "stop_reason": Json::string(stop_reason),
        "stop_sequence": Json::null(),
      }),
      "usage": gemini_native_stream_anthropic_usage_json(self.latest_usage),
    }).stringify(),
  }
}

///|
fn gemini_visible_text_from_parts(parts : Array[Json]) -> String {
  let texts : Array[String] = []
  for part in parts {
    guard part is Object(part_obj) else { continue }
    if part_obj.get("thought") == Some(Json::boolean(true)) {
      continue
    }
    if part_obj.get("functionCall") is Some(_) {
      continue
    }
    if part_obj.get("text") is Some(String(text)) {
      texts.push(text)
    }
  }
  texts.join("")
}

///|
fn TokenUsage::as_anthropic_usage_json(self : TokenUsage) -> Json {
  let result : Map[String, Json] = {
    "input_tokens": Json::number(self.anthropic_input_tokens().to_double()),
    "output_tokens": Json::number(self.output_tokens.to_double()),
  }
  if self.cache_read_tokens > 0 {
    result["cache_read_input_tokens"] = Json::number(
      self.cache_read_tokens.to_double(),
    )
  }
  if self.cache_creation_tokens > 0 {
    result["cache_creation_input_tokens"] = Json::number(
      self.cache_creation_tokens.to_double(),
    )
  }
  Json::object(result)
}

///|
priv struct OpenAIChatAnthropicToolBlock {
  anthropic_index : Int
  mut id : String
  mut name : String
  mut started : Bool
  mut pending_args : String
}

///|
priv struct OpenAIChatAnthropicStreamState {
  mut message_id : String?
  mut model : String?
  mut next_content_index : Int
  mut has_sent_message_start : Bool
  mut current_non_tool_block_type : String?
  mut current_non_tool_block_index : Int?
  tool_blocks_by_index : Map[Int, OpenAIChatAnthropicToolBlock]
  open_tool_block_indices : Array[Int]
  mut has_emitted_message_delta : Bool
  mut pending_stop_reason : String?
  mut pending_usage : Json?
}

///|
fn OpenAIChatAnthropicStreamState::new() -> OpenAIChatAnthropicStreamState {
  {
    message_id: None,
    model: None,
    next_content_index: 0,
    has_sent_message_start: false,
    current_non_tool_block_type: None,
    current_non_tool_block_index: None,
    tool_blocks_by_index: Map([], capacity=0),
    open_tool_block_indices: [],
    has_emitted_message_delta: false,
    pending_stop_reason: None,
    pending_usage: None,
  }
}

///|
fn OpenAIChatAnthropicStreamState::push_chunk(
  self : OpenAIChatAnthropicStreamState,
  chunk : Json,
) -> Array[StreamEvent] {
  let events : Array[StreamEvent] = []
  guard chunk is Object(obj) else { return events }
  if self.message_id is None {
    self.message_id = json_string_from_map(obj, "id")
  }
  if self.model is None {
    self.model = json_string_from_map(obj, "model")
  }
  if obj.get("usage") is Some(Object(usage)) {
    self.pending_usage = Some(openai_chat_stream_anthropic_usage_json(usage))
  }
  guard obj.get("choices") is Some(Array(choices)) else { return events }
  guard choices.get(0) is Some(Object(choice_obj)) else { return events }
  if !self.has_sent_message_start {
    events.push(self.message_start_event())
    self.has_sent_message_start = true
  }
  if choice_obj.get("delta") is Some(Object(delta)) {
    match json_openai_chat_reasoning_text(delta) {
      Some(text) if !text.is_empty() =>
        self.push_non_tool_delta(events, "thinking", "thinking_delta", text)
      _ => ()
    }
    match json_string_from_map(delta, "content") {
      Some(text) if !text.is_empty() =>
        self.push_non_tool_delta(events, "text", "text_delta", text)
      _ => ()
    }
    match json_string_from_map(delta, "refusal") {
      Some(text) if !text.is_empty() =>
        self.push_non_tool_delta(events, "text", "text_delta", text)
      _ => ()
    }
    match delta.get("tool_calls") {
      Some(Array(tool_calls)) if !tool_calls.is_empty() => {
        self.close_current_non_tool_block(events)
        for tool_call in tool_calls {
          if tool_call is Object(tool_call_obj) {
            self.push_tool_call_delta(events, tool_call_obj)
          }
        }
      }
      _ => ()
    }
  }
  match choice_obj.get("finish_reason") {
    Some(String(reason)) => self.prepare_finish(events, reason)
    _ => ()
  }
  events
}

///|
fn OpenAIChatAnthropicStreamState::finish(
  self : OpenAIChatAnthropicStreamState,
) -> Array[StreamEvent] {
  let events : Array[StreamEvent] = []
  if self.pending_stop_reason is Some(stop_reason) {
    events.push(self.message_delta_event(stop_reason))
    events.push(anthropic_message_stop_stream_event())
    self.pending_stop_reason = None
  } else if self.has_sent_message_start {
    self.close_current_non_tool_block(events)
    self.start_pending_tool_blocks(events)
    self.close_open_tool_blocks(events)
    events.push(self.message_delta_event("end_turn"))
    events.push(anthropic_message_stop_stream_event())
  }
  events
}

///|
fn OpenAIChatAnthropicStreamState::message_start_event(
  self : OpenAIChatAnthropicStreamState,
) -> StreamEvent {
  {
    event_type: "message_start",
    data: Json::object({
      "type": Json::string("message_start"),
      "message": Json::object({
        "id": Json::string(self.message_id.unwrap_or("")),
        "type": Json::string("message"),
        "role": Json::string("assistant"),
        "model": Json::string(self.model.unwrap_or("")),
        "usage": openai_chat_zero_usage_json(),
      }),
    }).stringify(),
  }
}

///|
fn OpenAIChatAnthropicStreamState::push_non_tool_delta(
  self : OpenAIChatAnthropicStreamState,
  events : Array[StreamEvent],
  block_type : String,
  delta_type : String,
  text : String,
) -> Unit {
  if self.current_non_tool_block_type != Some(block_type) {
    self.close_current_non_tool_block(events)
    let index = self.next_content_index
    self.next_content_index += 1
    self.current_non_tool_block_type = Some(block_type)
    self.current_non_tool_block_index = Some(index)
    events.push(anthropic_content_block_start_event(index, block_type))
  }
  if self.current_non_tool_block_index is Some(index) {
    events.push(
      anthropic_content_block_delta_event(index, delta_type, block_type, text),
    )
  }
}

///|
fn OpenAIChatAnthropicStreamState::close_current_non_tool_block(
  self : OpenAIChatAnthropicStreamState,
  events : Array[StreamEvent],
) -> Unit {
  if self.current_non_tool_block_index is Some(index) {
    events.push(anthropic_content_block_stop_event(index))
  }
  self.current_non_tool_block_index = None
  self.current_non_tool_block_type = None
}

///|
fn OpenAIChatAnthropicStreamState::push_tool_call_delta(
  self : OpenAIChatAnthropicStreamState,
  events : Array[StreamEvent],
  tool_call : Map[String, Json],
) -> Unit {
  let tool_index = json_int_or_zero(tool_call, "index")
  let state = match self.tool_blocks_by_index.get(tool_index) {
    Some(existing) => existing
    None => {
      let created = {
        anthropic_index: self.next_content_index,
        id: "",
        name: "",
        started: false,
        pending_args: "",
      }
      self.next_content_index += 1
      self.tool_blocks_by_index.set(tool_index, created)
      created
    }
  }
  match json_string_from_map(tool_call, "id") {
    Some(id) if !id.is_empty() => state.id = id
    _ => ()
  }
  match tool_call.get("function") {
    Some(Object(function)) => {
      match json_string_from_map(function, "name") {
        Some(name) if !name.is_empty() => state.name = name
        _ => ()
      }
      match json_string_from_map(function, "arguments") {
        Some(args) if !args.is_empty() =>
          if state.started {
            events.push(
              anthropic_tool_input_delta_event(state.anthropic_index, args),
            )
          } else {
            state.pending_args = state.pending_args + args
          }
        _ => ()
      }
    }
    _ => ()
  }
  if !state.started && !state.id.is_empty() && !state.name.is_empty() {
    state.started = true
    events.push(
      anthropic_tool_block_start_event(
        state.anthropic_index,
        state.id,
        state.name,
      ),
    )
    self.open_tool_block_indices.push(state.anthropic_index)
    if !state.pending_args.is_empty() {
      events.push(
        anthropic_tool_input_delta_event(
          state.anthropic_index,
          state.pending_args,
        ),
      )
      state.pending_args = ""
    }
  }
}

///|
fn OpenAIChatAnthropicStreamState::prepare_finish(
  self : OpenAIChatAnthropicStreamState,
  events : Array[StreamEvent],
  reason : String,
) -> Unit {
  if self.has_emitted_message_delta {
    return
  }
  self.has_emitted_message_delta = true
  self.close_current_non_tool_block(events)
  self.start_pending_tool_blocks(events)
  self.close_open_tool_blocks(events)
  self.pending_stop_reason = Some(openai_chat_stop_reason(reason))
}

///|
fn OpenAIChatAnthropicStreamState::start_pending_tool_blocks(
  self : OpenAIChatAnthropicStreamState,
  events : Array[StreamEvent],
) -> Unit {
  for tool_index in self.tool_blocks_by_index.keys() {
    guard self.tool_blocks_by_index.get(tool_index) is Some(state) else {
      continue
    }
    if state.started {
      continue
    }
    if state.id.is_empty() &&
      state.name.is_empty() &&
      state.pending_args.is_empty() {
      continue
    }
    if state.id.is_empty() {
      state.id = "tool_call_\{tool_index}"
    }
    if state.name.is_empty() {
      state.name = "unknown_tool"
    }
    state.started = true
    events.push(
      anthropic_tool_block_start_event(
        state.anthropic_index,
        state.id,
        state.name,
      ),
    )
    self.open_tool_block_indices.push(state.anthropic_index)
    if !state.pending_args.is_empty() {
      events.push(
        anthropic_tool_input_delta_event(
          state.anthropic_index,
          state.pending_args,
        ),
      )
      state.pending_args = ""
    }
  }
}

///|
fn OpenAIChatAnthropicStreamState::close_open_tool_blocks(
  self : OpenAIChatAnthropicStreamState,
  events : Array[StreamEvent],
) -> Unit {
  for index in self.open_tool_block_indices {
    events.push(anthropic_content_block_stop_event(index))
  }
  self.open_tool_block_indices.clear()
}

///|
fn OpenAIChatAnthropicStreamState::message_delta_event(
  self : OpenAIChatAnthropicStreamState,
  stop_reason : String,
) -> StreamEvent {
  {
    event_type: "message_delta",
    data: Json::object({
      "type": Json::string("message_delta"),
      "delta": Json::object({
        "stop_reason": Json::string(stop_reason),
        "stop_sequence": Json::null(),
      }),
      "usage": self.pending_usage.unwrap_or(openai_chat_zero_usage_json()),
    }).stringify(),
  }
}

///|
fn anthropic_content_block_start_event(
  index : Int,
  block_type : String,
) -> StreamEvent {
  let content_block = if block_type == "thinking" {
    Json::object({
      "type": Json::string("thinking"),
      "thinking": Json::string(""),
    })
  } else {
    Json::object({ "type": Json::string("text"), "text": Json::string("") })
  }
  {
    event_type: "content_block_start",
    data: Json::object({
      "type": Json::string("content_block_start"),
      "index": Json::number(index.to_double()),
      "content_block": content_block,
    }).stringify(),
  }
}

///|
fn anthropic_content_block_delta_event(
  index : Int,
  delta_type : String,
  block_type : String,
  text : String,
) -> StreamEvent {
  let text_key = if block_type == "thinking" { "thinking" } else { "text" }
  let delta : Map[String, Json] = { "type": Json::string(delta_type) }
  delta[text_key] = Json::string(text)
  {
    event_type: "content_block_delta",
    data: Json::object({
      "type": Json::string("content_block_delta"),
      "index": Json::number(index.to_double()),
      "delta": Json::object(delta),
    }).stringify(),
  }
}

///|
fn anthropic_tool_block_start_event(
  index : Int,
  id : String,
  name : String,
) -> StreamEvent {
  {
    event_type: "content_block_start",
    data: Json::object({
      "type": Json::string("content_block_start"),
      "index": Json::number(index.to_double()),
      "content_block": Json::object({
        "type": Json::string("tool_use"),
        "id": Json::string(id),
        "name": Json::string(name),
      }),
    }).stringify(),
  }
}

///|
fn anthropic_tool_input_delta_event(index : Int, args : String) -> StreamEvent {
  {
    event_type: "content_block_delta",
    data: Json::object({
      "type": Json::string("content_block_delta"),
      "index": Json::number(index.to_double()),
      "delta": Json::object({
        "type": Json::string("input_json_delta"),
        "partial_json": Json::string(args),
      }),
    }).stringify(),
  }
}

///|
fn anthropic_content_block_stop_event(index : Int) -> StreamEvent {
  {
    event_type: "content_block_stop",
    data: Json::object({
      "type": Json::string("content_block_stop"),
      "index": Json::number(index.to_double()),
    }).stringify(),
  }
}

///|
fn anthropic_message_stop_stream_event() -> StreamEvent {
  {
    event_type: "message_stop",
    data: Json::object({ "type": Json::string("message_stop") }).stringify(),
  }
}

///|
fn json_openai_chat_reasoning_text(delta : Map[String, Json]) -> String? {
  match json_string_from_map(delta, "reasoning") {
    Some(text) => Some(text)
    None => json_string_from_map(delta, "reasoning_content")
  }
}

///|
fn openai_chat_stop_reason(reason : String) -> String {
  match reason {
    "tool_calls" | "function_call" => "tool_use"
    "length" => "max_tokens"
    _ => "end_turn"
  }
}
