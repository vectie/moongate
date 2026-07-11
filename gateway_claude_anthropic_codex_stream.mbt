///|
fn convert_codex_to_anthropic(
  codex_json : Json,
  model : String,
) -> AnthropicResponse {
  let content : Array[AnthropicResponseBlock] = []
  let mut input_tokens = 0
  let mut output_tokens = 0
  let mut cache_read_tokens = 0
  let mut cache_creation_tokens = 0
  let id = generate_message_id()
  guard codex_json is Object(obj) else {
    return build_anthropic_response(id, model, "", [], 0, 0)
  }
  if obj.get("output") is Some(Array(outputs)) {
    for output in outputs {
      guard output is Object(out_obj) else { continue }
      let type_ = match out_obj.get("type") {
        Some(String(t)) => t
        _ => continue
      }
      if type_ == "message" {
        if out_obj.get("content") is Some(Array(content_parts)) {
          for part in content_parts {
            guard part is Object(part_obj) else { continue }
            if part_obj.get("type") is Some(String("output_text")) {
              if part_obj.get("text") is Some(String(text)) {
                content.push({
                  type_: "text",
                  text: Some(text),
                  name: None,
                  input: None,
                  id: None,
                })
              }
            }
          }
        }
      } else if type_ == "function_call" {
        let name = match out_obj.get("name") {
          Some(String(n)) => n
          _ => "unknown"
        }
        let args = match out_obj.get("arguments") {
          Some(String(a)) => a
          _ => "{}"
        }
        let call_id = match out_obj.get("call_id") {
          Some(String(id)) => id
          _ => generate_message_id()
        }
        let args_json_result : Result[Json, Error] = moon_result(() => {
          @json.parse(args)
        })
        let args_json = match args_json_result {
          Ok(j) => j
          Err(_) => Json::object({})
        }
        content.push({
          type_: "tool_use",
          text: None,
          name: Some(name),
          input: Some(args_json),
          id: Some(call_id),
        })
      }
    }
  }
  if obj.get("usage") is Some(Object(usage_obj)) {
    input_tokens = json_int_or_zero(usage_obj, "input_tokens")
    output_tokens = json_int_or_zero(usage_obj, "output_tokens")
    cache_read_tokens = match json_int(usage_obj, "cache_read_input_tokens") {
      Some(tokens) => tokens
      None =>
        match usage_obj.get("input_tokens_details") {
          Some(Object(details)) => json_int_or_zero(details, "cached_tokens")
          _ => 0
        }
    }
    cache_creation_tokens = json_int_or_zero(
      usage_obj, "cache_creation_input_tokens",
    )
  }
  let usage = TokenUsage::new(
    input_tokens~,
    output_tokens~,
    cache_read_tokens~,
    cache_creation_tokens~,
  )
  let has_tools = content.iter().any(fn(b) { b.type_ == "tool_use" })
  let stop_reason = if has_tools { "tool_use" } else { "end_turn" }
  {
    id,
    type_: "message",
    role: "assistant",
    content,
    model,
    stop_reason: Some(stop_reason),
    stop_sequence: None,
    usage: {
      input_tokens: usage.anthropic_input_tokens(),
      output_tokens,
      cache_read_input_tokens: optional_positive_int(cache_read_tokens),
      cache_creation_input_tokens: optional_positive_int(cache_creation_tokens),
    },
  }
}

///|
fn generate_message_id() -> String {
  "msg_\{moongate_random_id()}"
}

///|
fn generate_gemini_synth_tool_call_id(position : Int) -> String {
  "gemini_synth_\{position}"
}

///|
priv struct StreamEvent {
  event_type : String
  data : String
}

///|
priv struct CodexStreamReader {
  reader : &@io.Reader
  events : Array[Json]
  pending_events : Array[StreamEvent]
  responses_state : ResponsesStreamState
  mut partial_block : String
}

///|
fn CodexStreamReader::new(
  reader : &@io.Reader,
  model : String,
) -> CodexStreamReader {
  {
    reader,
    events: [],
    pending_events: [],
    responses_state: ResponsesStreamState::new(model),
    partial_block: "",
  }
}

///|
async fn CodexStreamReader::read(self : CodexStreamReader) -> StreamEvent? {
  for ;; {
    if !self.pending_events.is_empty() {
      return Some(self.pending_events.remove(0))
    }
    match self.reader.read_until("\n") {
      Some(line) => {
        self.partial_block += line
        if !line.trim().is_empty() {
          continue
        }
      }
      None => if self.partial_block.trim().is_empty() { return None }
    }
    let block = self.partial_block
    self.partial_block = ""
    let (done, json, events) = codex_stream_events_from_sse_block(
      block,
      self.responses_state,
    )
    if done {
      return None
    }
    if json is Some(parsed) {
      self.events.push(parsed)
    }
    for event in events {
      self.pending_events.push(event)
    }
    if !self.pending_events.is_empty() {
      return Some(self.pending_events.remove(0))
    }
  }
}

///|
fn codex_stream_event_from_sse_block(
  block : String,
  model : String,
) -> (Bool, Json?, StreamEvent?) {
  if block.trim().is_empty() {
    return (false, None, None)
  }
  let mut event_name = ""
  let data_lines : Array[String] = []
  for line_view in block.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    match strip_sse_field(line, "event") {
      Some(event) => event_name = event.trim().to_owned()
      None =>
        match strip_sse_field(line, "data") {
          Some(data) => data_lines.push(data)
          None => ()
        }
    }
  }
  if data_lines.is_empty() {
    return (false, None, None)
  }
  let data = data_lines.join("\n")
  if data.trim() == "[DONE]" {
    return (true, None, None)
  }
  let parsed = @json.parse(data) catch { _ => return (false, None, None) }
  guard parsed is Object(obj) else { return (false, Some(parsed), None) }
  let actual_event_name = if event_name.is_empty() {
    json_string_from_map(obj, "type").unwrap_or("")
  } else {
    event_name
  }
  (false, Some(parsed), convert_stream_event(actual_event_name, obj, model))
}

///|
fn init {
  ignore(prepare_upstream_request_body(Json::object({})))
  ignore(openai_chat_stream_chunk_to_anthropic_events(Json::object({})))
  ignore(gemini_native_stream_chunk_to_anthropic_events(Json::object({})))
  ignore(codex_stream_event_from_sse_block("", "model"))
}

///|
fn codex_stream_events_from_sse_block(
  block : String,
  state : ResponsesStreamState,
) -> (Bool, Json?, Array[StreamEvent]) {
  if block.trim().is_empty() {
    return (false, None, [])
  }
  let mut event_name = ""
  let data_lines : Array[String] = []
  for line_view in block.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    match strip_sse_field(line, "event") {
      Some(event) => event_name = event.trim().to_owned()
      None =>
        match strip_sse_field(line, "data") {
          Some(data) => data_lines.push(data)
          None => ()
        }
    }
  }
  if data_lines.is_empty() {
    return (false, None, [])
  }
  let data = data_lines.join("\n")
  if data.trim() == "[DONE]" {
    return (true, None, [])
  }
  let parsed = @json.parse(data) catch { _ => return (false, None, []) }
  guard parsed is Object(obj) else { return (false, Some(parsed), []) }
  let actual_event_name = if event_name.is_empty() {
    json_string_from_map(obj, "type").unwrap_or("")
  } else {
    event_name
  }
  (false, Some(parsed), state.push_event(actual_event_name, obj))
}

///|
fn push_sse_json_event(events : Array[Json], data : String) -> Bool {
  let json_result : Result[Json, Error] = moon_result(() => @json.parse(data))
  match json_result {
    Ok(json) => {
      events.push(json)
      true
    }
    Err(_) => false
  }
}

///|
async fn write_codex_response_sse_event(
  w : @httpx.ResponseWriter,
  event : Json,
) -> Int {
  let event_type = match event {
    Object(obj) => json_string_from_map(obj, "type").unwrap_or("")
    _ => ""
  }
  if !event_type.is_empty() {
    w.write("event: \{event_type}\n")
  }
  let payload = event.stringify()
  w.write("data: \{payload}\n\n")
  w.flush()
  payload.length()
}

///|
priv struct ResponsesStreamState {
  mut message_id : String?
  mut model : String
  mut has_sent_message_start : Bool
  mut has_tool_use : Bool
  mut next_content_index : Int
  mut current_text_index : Int?
  mut current_thinking_index : Int?
  mut fallback_open_index : Int?
  mut last_tool_index : Int?
  open_indices : Array[Int]
  index_by_key : Map[String, Int]
  tool_index_by_item_id : Map[String, Int]
  tool_name_by_index : Map[Int, String]
  tool_args_by_index : Map[Int, String]
}

///|
fn ResponsesStreamState::new(model : String) -> ResponsesStreamState {
  {
    message_id: None,
    model,
    has_sent_message_start: false,
    has_tool_use: false,
    next_content_index: 0,
    current_text_index: None,
    current_thinking_index: None,
    fallback_open_index: None,
    last_tool_index: None,
    open_indices: [],
    index_by_key: {},
    tool_index_by_item_id: {},
    tool_name_by_index: {},
    tool_args_by_index: {},
  }
}

///|
fn ResponsesStreamState::push_event(
  self : ResponsesStreamState,
  event_type : String,
  obj : Map[String, Json],
) -> Array[StreamEvent] {
  let events : Array[StreamEvent] = []
  match event_type {
    "response.created" => {
      let response_obj = responses_stream_response_object(obj)
      self.message_id = json_string_from_map(response_obj, "id")
      self.model = json_string_from_map(response_obj, "model").unwrap_or(
        self.model,
      )
      if convert_stream_event(event_type, obj, self.model) is Some(event) {
        events.push(event)
        self.has_sent_message_start = true
      }
    }
    "response.content_part.added" =>
      match obj.get("part") {
        Some(Object(part)) =>
          match json_string_from_map(part, "type") {
            Some("output_text") | Some("refusal") =>
              ignore(self.ensure_text_block(obj, events))
            _ => ()
          }
        _ => ()
      }
    "response.output_text.delta" | "response.refusal.delta" => {
      let delta = match obj.get("delta") {
        Some(String(text)) => text
        _ => return events
      }
      self.ensure_message_start(events)
      let index = self.ensure_text_block(obj, events)
      events.push(
        anthropic_content_block_delta_event(index, "text_delta", "text", delta),
      )
    }
    "response.reasoning.delta" => {
      let delta = match obj.get("delta") {
        Some(String(text)) => text
        _ =>
          match obj.get("text") {
            Some(String(text)) => text
            _ => return events
          }
      }
      self.ensure_message_start(events)
      self.close_current_text_block(events)
      let index = self.ensure_thinking_block(obj, events)
      events.push(
        anthropic_content_block_delta_event(
          index, "thinking_delta", "thinking", delta,
        ),
      )
    }
    "response.output_text.done" | "response.refusal.done" =>
      self.close_text_block_from_event(obj, events)
    "response.reasoning.done" =>
      self.close_thinking_block_from_event(obj, events)
    "response.output_item.added" => self.push_output_item_added(obj, events)
    "response.function_call_arguments.delta" =>
      self.push_function_call_arguments_delta(obj, events)
    "response.function_call_arguments.done" =>
      self.finish_function_call_arguments(obj, events)
    "response.completed" => {
      self.close_current_text_block(events)
      self.close_current_thinking_block(events)
      self.close_open_blocks(events)
      events.push(
        responses_stream_completed_event(obj, self.model, self.has_tool_use),
      )
    }
    _ =>
      if convert_stream_event(event_type, obj, self.model) is Some(event) {
        events.push(event)
      }
  }
  events
}

///|
fn ResponsesStreamState::ensure_message_start(
  self : ResponsesStreamState,
  events : Array[StreamEvent],
) -> Unit {
  if self.has_sent_message_start {
    return
  }
  events.push({
    event_type: "message_start",
    data: Json::object({
      "type": Json::string("message_start"),
      "message": Json::object({
        "id": Json::string(self.message_id.unwrap_or("")),
        "type": Json::string("message"),
        "role": Json::string("assistant"),
        "model": Json::string(self.model),
        "usage": openai_chat_zero_usage_json(),
      }),
    }).stringify(),
  })
  self.has_sent_message_start = true
}

///|
fn ResponsesStreamState::push_output_item_added(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Unit {
  guard obj.get("item") is Some(Object(item)) else { return }
  guard json_string_from_map(item, "type") == Some("function_call") else {
    return
  }
  self.has_tool_use = true
  self.close_current_text_block(events)
  self.close_current_thinking_block(events)
  self.ensure_message_start(events)
  let index = match responses_stream_item_id(obj, item) {
    Some(item_id) =>
      match self.tool_index_by_item_id.get(item_id) {
        Some(existing) => existing
        None => {
          let created = self.next_content_index
          self.next_content_index += 1
          self.tool_index_by_item_id[item_id] = created
          created
        }
      }
    None => {
      let created = self.next_content_index
      self.next_content_index += 1
      created
    }
  }
  self.last_tool_index = Some(index)
  let name = json_string_from_map(item, "name").unwrap_or("")
  self.tool_name_by_index[index] = name
  if !self.open_indices.contains(index) {
    self.open_indices.push(index)
    if self.tool_args_by_index.get(index) is None {
      self.tool_args_by_index[index] = ""
    }
    events.push(
      anthropic_tool_block_start_event(
        index,
        json_string_from_map(item, "call_id").unwrap_or(""),
        name,
      ),
    )
  }
}

///|
fn ResponsesStreamState::push_function_call_arguments_delta(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Unit {
  let delta = match obj.get("delta") {
    Some(String(delta)) => delta
    _ => return
  }
  self.has_tool_use = true
  let index = self.tool_index_from_event(obj)
  self.ensure_tool_block(index, obj, events)
  if self.tool_name_by_index.get(index) == Some("Read") {
    let buffered = self.tool_args_by_index.get(index).unwrap_or("")
    self.tool_args_by_index[index] = buffered + delta
  } else {
    events.push(anthropic_tool_input_delta_event(index, delta))
  }
}

///|
fn ResponsesStreamState::finish_function_call_arguments(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Unit {
  guard self.last_tool_index is Some(_) ||
    obj.get("item_id") is Some(_) ||
    obj.get("output_index") is Some(_) else {
    return
  }
  let index = self.tool_index_from_event(obj)
  if self.tool_name_by_index.get(index) == Some("Read") {
    let raw = json_string_from_map(obj, "arguments").unwrap_or(
      self.tool_args_by_index.get(index).unwrap_or(""),
    )
    let sanitized = sanitize_anthropic_tool_use_input_json("Read", raw)
    if !sanitized.is_empty() {
      events.push(anthropic_tool_input_delta_event(index, sanitized))
    }
  }
  self.close_open_block(events, index)
  match json_string_from_map(obj, "item_id") {
    Some(item_id) => self.tool_index_by_item_id.remove(item_id)
    None => ()
  }
  self.tool_name_by_index.remove(index)
  self.tool_args_by_index.remove(index)
}

///|
fn ResponsesStreamState::tool_index_from_event(
  self : ResponsesStreamState,
  obj : Map[String, Json],
) -> Int {
  match json_string_from_map(obj, "item_id") {
    Some(item_id) =>
      match self.tool_index_by_item_id.get(item_id) {
        Some(index) => return index
        None => ()
      }
    None => ()
  }
  match json_int(obj, "output_index") {
    Some(output_index) => {
      let key = "out:\{output_index}"
      match self.tool_index_by_item_id.get(key) {
        Some(index) => return index
        None => ()
      }
    }
    None => ()
  }
  match self.last_tool_index {
    Some(index) => index
    None => {
      let index = self.next_content_index
      self.next_content_index += 1
      self.last_tool_index = Some(index)
      match json_string_from_map(obj, "item_id") {
        Some(item_id) => self.tool_index_by_item_id[item_id] = index
        None => ()
      }
      index
    }
  }
}

///|
fn ResponsesStreamState::ensure_tool_block(
  self : ResponsesStreamState,
  index : Int,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Unit {
  self.ensure_message_start(events)
  if self.open_indices.contains(index) {
    return
  }
  self.open_indices.push(index)
  let name = match self.tool_name_by_index.get(index) {
    Some(name) => name
    None => json_string_from_map(obj, "name").unwrap_or("")
  }
  self.tool_name_by_index[index] = name
  if self.tool_args_by_index.get(index) is None {
    self.tool_args_by_index[index] = ""
  }
  events.push(
    anthropic_tool_block_start_event(
      index,
      json_string_from_map(obj, "call_id").unwrap_or(
        json_string_from_map(obj, "item_id").unwrap_or(""),
      ),
      name,
    ),
  )
}

///|
fn ResponsesStreamState::ensure_text_block(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Int {
  self.ensure_message_start(events)
  match self.current_text_index {
    Some(index) => index
    None => {
      let index = self.resolve_content_index(obj)
      self.current_text_index = Some(index)
      if !self.open_indices.contains(index) {
        self.open_indices.push(index)
        events.push(anthropic_content_block_start_event(index, "text"))
      }
      index
    }
  }
}

///|
fn ResponsesStreamState::ensure_thinking_block(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Int {
  self.ensure_message_start(events)
  match self.current_thinking_index {
    Some(index) => index
    None => {
      let index = self.resolve_content_index(obj)
      self.current_thinking_index = Some(index)
      if !self.open_indices.contains(index) {
        self.open_indices.push(index)
        events.push(anthropic_content_block_start_event(index, "thinking"))
      }
      index
    }
  }
}

///|
fn ResponsesStreamState::resolve_content_index(
  self : ResponsesStreamState,
  obj : Map[String, Json],
) -> Int {
  match responses_stream_content_part_key(obj) {
    Some(key) =>
      match self.index_by_key.get(key) {
        Some(index) => index
        None => {
          let index = self.next_content_index
          self.next_content_index += 1
          self.index_by_key[key] = index
          index
        }
      }
    None =>
      match self.fallback_open_index {
        Some(index) => index
        None => {
          let index = self.next_content_index
          self.next_content_index += 1
          self.fallback_open_index = Some(index)
          index
        }
      }
  }
}

///|
fn ResponsesStreamState::close_current_text_block(
  self : ResponsesStreamState,
  events : Array[StreamEvent],
) -> Unit {
  match self.current_text_index {
    Some(index) => {
      self.current_text_index = None
      self.close_open_block(events, index)
      self.clear_fallback_if_index(index)
    }
    None => ()
  }
}

///|
fn ResponsesStreamState::close_text_block_from_event(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Unit {
  let index = match self.current_text_index {
    Some(index) => {
      self.current_text_index = None
      Some(index)
    }
    None => self.content_index_from_event(obj)
  }
  match index {
    Some(index) => {
      self.close_open_block(events, index)
      self.clear_fallback_if_index(index)
    }
    None => ()
  }
}

///|
fn ResponsesStreamState::close_current_thinking_block(
  self : ResponsesStreamState,
  events : Array[StreamEvent],
) -> Unit {
  match self.current_thinking_index {
    Some(index) => {
      self.current_thinking_index = None
      self.close_open_block(events, index)
      self.clear_fallback_if_index(index)
    }
    None => ()
  }
}

///|
fn ResponsesStreamState::close_thinking_block_from_event(
  self : ResponsesStreamState,
  obj : Map[String, Json],
  events : Array[StreamEvent],
) -> Unit {
  let index = match self.current_thinking_index {
    Some(index) => {
      self.current_thinking_index = None
      Some(index)
    }
    None => self.content_index_from_event(obj)
  }
  match index {
    Some(index) => {
      self.close_open_block(events, index)
      self.clear_fallback_if_index(index)
    }
    None => ()
  }
}

///|
fn ResponsesStreamState::content_index_from_event(
  self : ResponsesStreamState,
  obj : Map[String, Json],
) -> Int? {
  match responses_stream_content_part_key(obj) {
    Some(key) =>
      match self.index_by_key.get(key) {
        Some(index) => Some(index)
        None => self.fallback_open_index
      }
    None => self.fallback_open_index
  }
}

///|
fn ResponsesStreamState::clear_fallback_if_index(
  self : ResponsesStreamState,
  index : Int,
) -> Unit {
  if self.fallback_open_index == Some(index) {
    self.fallback_open_index = None
  }
}

///|
fn ResponsesStreamState::close_open_block(
  self : ResponsesStreamState,
  events : Array[StreamEvent],
  index : Int,
) -> Unit {
  for position in 0..<self.open_indices.length() {
    if self.open_indices[position] == index {
      ignore(self.open_indices.remove(position))
      events.push(anthropic_content_block_stop_event(index))
      return
    }
  }
}

///|
fn ResponsesStreamState::close_open_blocks(
  self : ResponsesStreamState,
  events : Array[StreamEvent],
) -> Unit {
  while !self.open_indices.is_empty() {
    let index = self.open_indices.remove(0)
    events.push(anthropic_content_block_stop_event(index))
  }
  self.fallback_open_index = None
}

///|
fn responses_stream_content_part_key(obj : Map[String, Json]) -> String? {
  match (json_string_from_map(obj, "item_id"), json_int(obj, "content_index")) {
    (Some(item_id), Some(content_index)) =>
      Some("part:\{item_id}:\{content_index}")
    _ =>
      match (json_int(obj, "output_index"), json_int(obj, "content_index")) {
        (Some(output_index), Some(content_index)) =>
          Some("part:out:\{output_index}:\{content_index}")
        _ => None
      }
  }
}

///|
fn responses_stream_item_id(
  obj : Map[String, Json],
  item : Map[String, Json],
) -> String? {
  match json_string_from_map(item, "id") {
    Some(id) => Some(id)
    None =>
      match json_string_from_map(obj, "item_id") {
        Some(item_id) => Some(item_id)
        None =>
          match json_int(obj, "output_index") {
            Some(output_index) => Some("out:\{output_index}")
            None => None
          }
      }
  }
}

///|
fn sanitize_anthropic_tool_use_input_json(
  name : String,
  raw : String,
) -> String {
  if name != "Read" || raw.is_empty() {
    return raw
  }
  let parsed = @json.parse(raw) catch { _ => return raw }
  guard parsed is Object(obj) else { return raw }
  match obj.get("pages") {
    Some(String(value)) if value.is_empty() => obj.remove("pages")
    _ => ()
  }
  Json::object(obj).stringify()
}

///|
fn convert_stream_event(
  event_type : String,
  obj : Map[String, Json],
  model : String,
) -> StreamEvent? {
  match event_type {
    "response.created" => {
      let response_obj = responses_stream_response_object(obj)
      let usage = responses_stream_anthropic_usage_json(response_obj)
      let message_id = json_string_from_map(response_obj, "id").unwrap_or("")
      let response_model = json_string_from_map(response_obj, "model").unwrap_or(
        model,
      )
      let event_data = Json::object({
        "type": Json::string("message_start"),
        "message": Json::object({
          "id": Json::string(message_id),
          "type": Json::string("message"),
          "role": Json::string("assistant"),
          "model": Json::string(response_model),
          "usage": usage,
        }),
      })
      Some({ event_type: "message_start", data: event_data.stringify() })
    }
    "response.output_text.delta" => {
      let delta = match obj.get("delta") {
        Some(String(d)) => d
        _ => return None
      }
      let event_data : Map[String, Json] = {
        "type": Json::string("content_block_delta"),
        "index": Json::number(0.0),
        "delta": {
          "type": Json::string("text_delta"),
          "text": Json::string(delta),
        }.to_json(),
      }
      Some({
        event_type: "content_block_delta",
        data: event_data.to_json().stringify(),
      })
    }
    "response.output_item.done" => {
      if obj.get("item") is Some(item_json) {
        let item : Json = item_json
        guard item is Object(item_obj) else { return None }
        let type_ = match item_obj.get("type") {
          Some(String(t)) => t
          _ => return None
        }
        if type_ == "function_call" {
          let name = match item_obj.get("name") {
            Some(String(n)) => n
            _ => "unknown"
          }
          let args = match item_obj.get("arguments") {
            Some(String(a)) => a
            _ => "{}"
          }
          let call_id = match item_obj.get("call_id") {
            Some(String(id)) => id
            _ => generate_message_id()
          }
          let args_json_result : Result[Json, Error] = moon_result(() => {
            @json.parse(args)
          })
          let args_json = match args_json_result {
            Ok(j) => j
            Err(_) => Json::object({})
          }
          let event_data : Map[String, Json] = {
            "type": Json::string("content_block_start"),
            "index": Json::number(1.0),
            "content_block": {
              "type": Json::string("tool_use"),
              "id": Json::string(call_id),
              "name": Json::string(name),
              "input": args_json,
            }.to_json(),
          }
          return Some({
            event_type: "content_block_start",
            data: event_data.to_json().stringify(),
          })
        }
      }
      None
    }
    "response.completed" =>
      Some(responses_stream_completed_event(obj, model, false))
    _ => None
  }
}

///|
fn responses_stream_completed_event(
  obj : Map[String, Json],
  _model : String,
  has_streamed_tool_use : Bool,
) -> StreamEvent {
  let response_obj = responses_stream_response_object(obj)
  let usage = responses_stream_anthropic_usage_json(response_obj)
  let stop_reason = responses_stream_stop_reason_json(
    json_string_from_map(response_obj, "status"),
    has_streamed_tool_use ||
    responses_stream_response_has_tool_use(response_obj),
    responses_stream_incomplete_reason(response_obj),
  )
  let event_data : Map[String, Json] = {
    "type": Json::string("message_delta"),
    "delta": { "stop_reason": stop_reason, "stop_sequence": Json::null() }.to_json(),
    "usage": usage,
  }
  { event_type: "message_delta", data: event_data.to_json().stringify() }
}

///|
fn responses_stream_response_object(
  obj : Map[String, Json],
) -> Map[String, Json] {
  match obj.get("response") {
    Some(Object(response_obj)) => response_obj
    _ => obj
  }
}

///|
fn responses_stream_response_has_tool_use(
  response_obj : Map[String, Json],
) -> Bool {
  match response_obj.get("output") {
    Some(Array(output)) =>
      output
      .iter()
      .any(fn(item) {
        match item {
          Object(item_obj) =>
            json_string_from_map(item_obj, "type") == Some("function_call")
          _ => false
        }
      })
    _ => false
  }
}

///|
fn responses_stream_incomplete_reason(
  response_obj : Map[String, Json],
) -> String? {
  match response_obj.get("incomplete_details") {
    Some(Object(details)) => json_string_from_map(details, "reason")
    _ => None
  }
}

///|
fn responses_stream_stop_reason_json(
  status : String?,
  has_tool_use : Bool,
  incomplete_reason : String?,
) -> Json {
  match status {
    Some("completed") if has_tool_use => Json::string("tool_use")
    Some("incomplete") =>
      match incomplete_reason {
        Some("max_output_tokens") | Some("max_tokens") =>
          Json::string("max_tokens")
        None => Json::string("max_tokens")
        _ => Json::string("end_turn")
      }
    Some(_) => Json::string("end_turn")
    None => Json::null()
  }
}
