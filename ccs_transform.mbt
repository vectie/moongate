///|
pub fn transform_claude_request_for_api_format(
  body : Json,
  api_format : String,
  session_id? : String? = None,
  explicit_prompt_cache_key? : String? = None,
  is_codex_oauth? : Bool = false,
  codex_fast_mode? : Bool = false,
  gemini_shadow_turns? : Array[GeminiAssistantTurn] = [],
) -> Json {
  match api_format {
    "openai_chat" =>
      anthropic_json_to_openai_chat(body, explicit_prompt_cache_key)
    "gemini_native" => anthropic_json_to_gemini(body, gemini_shadow_turns)
    "openai_responses" => {
      let cache_key = match explicit_prompt_cache_key {
        Some(_) => explicit_prompt_cache_key
        None => session_id
      }
      anthropic_json_to_openai_responses(
        body, cache_key, is_codex_oauth, codex_fast_mode,
      )
    }
    _ => body
  }
}

///|
pub struct GeminiToolCallMeta {
  id : String?
  name : String
  args : Json
  thought_signature : String?
}

///|
pub struct GeminiAssistantTurn {
  assistant_content : Json
  tool_calls : Array[GeminiToolCallMeta]
}

///|
pub struct GeminiShadowStore {
  max_sessions : Int
  max_turns_per_session : Int
  sessions : Map[String, Array[GeminiAssistantTurn]]
  session_order : Array[String]
}

///|
fn GeminiShadowStore::with_limits(
  max_sessions : Int,
  max_turns_per_session : Int,
) -> GeminiShadowStore {
  {
    max_sessions: if max_sessions < 1 {
      1
    } else {
      max_sessions
    },
    max_turns_per_session: if max_turns_per_session < 1 {
      1
    } else {
      max_turns_per_session
    },
    sessions: Map([], capacity=0),
    session_order: [],
  }
}

///|
fn GeminiShadowStore::new() -> GeminiShadowStore {
  GeminiShadowStore::with_limits(200, 64)
}

///|
fn GeminiShadowStore::session_turns(
  self : GeminiShadowStore,
  provider_id : String,
  session_id : String?,
) -> Array[GeminiAssistantTurn] {
  guard session_id is Some(session_id) else { return [] }
  self.sessions.get(gemini_shadow_key(provider_id, session_id)).unwrap_or([])
}

///|
fn GeminiShadowStore::record_assistant_turn(
  self : GeminiShadowStore,
  provider_id : String,
  session_id : String,
  turn : GeminiAssistantTurn,
) -> Unit {
  let key = gemini_shadow_key(provider_id, session_id)
  let turns = self.sessions.get(key).unwrap_or([])
  turns.push(turn)
  while turns.length() > self.max_turns_per_session {
    ignore(turns.remove(0))
  }
  self.sessions[key] = turns
  gemini_shadow_touch_session(self.session_order, key)
  while self.sessions.keys().count() > self.max_sessions &&
        !self.session_order.is_empty() {
    let evicted = self.session_order[0]
    ignore(self.session_order.remove(0))
    self.sessions.remove(evicted)
  }
}

///|
fn GeminiShadowStore::record_gemini_response(
  self : GeminiShadowStore,
  provider_id : String,
  session_id : String?,
  body : Json,
) -> Unit {
  guard session_id is Some(session_id) else { return }
  guard extract_gemini_shadow_turn_from_response(body) is Some(turn) else {
    return
  }
  self.record_assistant_turn(provider_id, session_id, turn)
}

///|
fn gemini_shadow_key(provider_id : String, session_id : String) -> String {
  "\{provider_id}\u{001f}\{session_id}"
}

///|
fn gemini_shadow_touch_session(order : Array[String], key : String) -> Unit {
  let mut index = 0
  while index < order.length() {
    if order[index] == key {
      ignore(order.remove(index))
    } else {
      index += 1
    }
  }
  order.push(key)
}

///|
fn anthropic_json_to_gemini(
  body : Json,
  shadow_turns : Array[GeminiAssistantTurn],
) -> Json {
  guard body is Object(obj) else { return body }
  let result : Map[String, Json] = {}
  let system_instruction = anthropic_gemini_system_instruction(obj)
  if system_instruction is Some(instruction) {
    result["systemInstruction"] = instruction
  }
  result["contents"] = Json::array(
    anthropic_messages_to_gemini_contents(obj, shadow_turns),
  )
  append_gemini_generation_config(obj, result)
  append_gemini_tools(obj, result)
  append_gemini_tool_choice(obj, result)
  Json::object(result)
}

///|
fn anthropic_gemini_system_instruction(obj : Map[String, Json]) -> Json? {
  let texts : Array[String] = []
  let system = anthropic_system_instructions(obj)
  if !system.is_empty() {
    texts.push(system)
  }
  guard obj.get("messages") is Some(Array(messages)) else {
    return gemini_system_instruction_from_texts(texts)
  }
  for message in messages {
    guard message is Object(message_obj) else { continue }
    if json_string_from_map(message_obj, "role") != Some("system") {
      continue
    }
    append_gemini_texts_from_content(message_obj.get("content"), texts)
  }
  gemini_system_instruction_from_texts(texts)
}

///|
fn gemini_system_instruction_from_texts(texts : Array[String]) -> Json? {
  if texts.is_empty() {
    return None
  }
  Some(
    Json::object({
      "parts": Json::array([
        Json::object({ "text": Json::string(texts.join("\n\n")) }),
      ]),
    }),
  )
}

///|
fn append_gemini_texts_from_content(
  content : Json?,
  texts : Array[String],
) -> Unit {
  match content {
    Some(String(text)) if !text.is_empty() => texts.push(text)
    Some(Array(blocks)) =>
      for block in blocks {
        match block {
          String(text) if !text.is_empty() => texts.push(text)
          Object(block_obj) =>
            if json_string_from_map(block_obj, "type") == Some("text") &&
              block_obj.get("text") is Some(String(text)) &&
              !text.is_empty() {
              texts.push(text)
            }
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn anthropic_messages_to_gemini_contents(
  obj : Map[String, Json],
  shadow_turns : Array[GeminiAssistantTurn],
) -> Array[Json] {
  let contents : Array[Json] = []
  let tool_names_by_id = build_tool_name_map_from_shadow_turns(shadow_turns)
  let thought_signature_by_id = build_thought_signature_map_from_shadow_turns(
    shadow_turns,
  )
  guard obj.get("messages") is Some(Array(source_messages)) else {
    return contents
  }
  for message in source_messages {
    guard message is Object(message_obj) else { continue }
    if json_string_from_map(message_obj, "role") == Some("assistant") {
      seed_tool_names_from_assistant_message(message_obj, tool_names_by_id)
    }
  }
  let total_assistant_messages = count_assistant_messages(source_messages)
  let effective_shadow_turns = latest_gemini_shadow_turns(
    shadow_turns, total_assistant_messages,
  )
  let shadow_start_index = total_assistant_messages -
    effective_shadow_turns.length()
  let used_shadow_indices : Map[Int, Bool] = Map([], capacity=0)
  let mut assistant_seen_index = 0
  for message in source_messages {
    guard message is Object(message_obj) else { continue }
    let role = json_string_from_map(message_obj, "role").unwrap_or("user")
    if role == "system" {
      continue
    }
    let parts = if role == "assistant" {
      let positional_shadow_index = if assistant_seen_index >=
        shadow_start_index {
        let index = assistant_seen_index - shadow_start_index
        if index < effective_shadow_turns.length() &&
          used_shadow_indices.get(index) is None {
          Some(index)
        } else {
          None
        }
      } else {
        None
      }
      let tool_use_match_index = find_matching_shadow_turn_for_assistant_message(
        message_obj.get("content"),
        effective_shadow_turns,
        used_shadow_indices,
      )
      assistant_seen_index += 1
      let shadow_index = match tool_use_match_index {
        Some(index) => Some(index)
        None => positional_shadow_index
      }
      match shadow_index {
        Some(index) => {
          used_shadow_indices[index] = true
          let shadow_turn = effective_shadow_turns[index]
          merge_tool_names_from_shadow(shadow_turn, tool_names_by_id)
          merge_thought_signatures_from_shadow(
            shadow_turn, thought_signature_by_id,
          )
          match shadow_parts_for_replay(shadow_turn.assistant_content) {
            Some(parts) => parts
            None =>
              anthropic_content_to_gemini_parts(
                message_obj.get("content"),
                role,
                tool_names_by_id,
                thought_signature_by_id,
              )
          }
        }
        None =>
          anthropic_content_to_gemini_parts(
            message_obj.get("content"),
            role,
            tool_names_by_id,
            thought_signature_by_id,
          )
      }
    } else {
      anthropic_content_to_gemini_parts(
        message_obj.get("content"),
        role,
        tool_names_by_id,
        thought_signature_by_id,
      )
    }
    if parts.is_empty() {
      continue
    }
    if role == "assistant" {
      merge_tool_names_from_parts(parts, tool_names_by_id)
    }
    contents.push(
      Json::object({
        "role": Json::string(if role == "assistant" { "model" } else { "user" }),
        "parts": Json::array(parts),
      }),
    )
  }
  contents
}

///|
fn anthropic_content_to_gemini_parts(
  content : Json?,
  role : String,
  tool_names_by_id : Map[String, String],
  thought_signature_by_id : Map[String, String],
) -> Array[Json] {
  let parts : Array[Json] = []
  match content {
    Some(String(text)) =>
      parts.push(Json::object({ "text": Json::string(text) }))
    Some(Array(blocks)) =>
      for block in blocks {
        append_anthropic_block_as_gemini_part(
          block, role, parts, tool_names_by_id, thought_signature_by_id,
        )
      }
    Some(json) =>
      parts.push(Json::object({ "text": Json::string(json.stringify()) }))
    None => ()
  }
  parts
}

///|
fn append_anthropic_block_as_gemini_part(
  block : Json,
  role : String,
  parts : Array[Json],
  tool_names_by_id : Map[String, String],
  thought_signature_by_id : Map[String, String],
) -> Unit {
  guard block is Object(block_obj) else { return }
  match json_string_from_map(block_obj, "type") {
    Some("text") =>
      if block_obj.get("text") is Some(String(text)) {
        parts.push(Json::object({ "text": Json::string(text) }))
      }
    Some("image") | Some("document") =>
      if block_obj.get("source") is Some(Object(source)) {
        let media_type = json_string_from_map(source, "media_type").unwrap_or(
          if json_string_from_map(block_obj, "type") == Some("document") {
            "application/pdf"
          } else {
            "image/png"
          },
        )
        let data = json_string_from_map(source, "data").unwrap_or("")
        parts.push(
          Json::object({
            "inlineData": Json::object({
              "mimeType": Json::string(media_type),
              "data": Json::string(data),
            }),
          }),
        )
      }
    Some("tool_use") => {
      guard role == "assistant" else { return }
      let id = json_string_from_map(block_obj, "id").unwrap_or("")
      let name = json_string_from_map(block_obj, "name").unwrap_or("")
      if !id.is_empty() && !name.is_empty() {
        tool_names_by_id[id] = name
      }
      let function_call : Map[String, Json] = {
        "name": Json::string(name),
        "args": block_obj.get("input").unwrap_or(Json::object({})),
      }
      if !id.is_empty() && !is_gemini_synthesized_tool_call_id(id) {
        function_call["id"] = Json::string(id)
      }
      let part : Map[String, Json] = {
        "functionCall": Json::object(function_call),
      }
      match thought_signature_by_id.get(id) {
        Some(signature) if !signature.is_empty() =>
          part["thoughtSignature"] = Json::string(signature)
        _ => ()
      }
      parts.push(Json::object(part))
    }
    Some("tool_result") => {
      let function_response : Map[String, Json] = {
        "name": Json::string(
          gemini_tool_result_name(block_obj, tool_names_by_id),
        ),
        "response": Json::object({
          "content": block_obj.get("content").unwrap_or(Json::string("")),
        }),
      }
      match json_string_from_map(block_obj, "tool_use_id") {
        Some(id) if !id.is_empty() && !is_gemini_synthesized_tool_call_id(id) =>
          function_response["id"] = Json::string(id)
        _ => ()
      }
      parts.push(
        Json::object({ "functionResponse": Json::object(function_response) }),
      )
    }
    _ => ()
  }
}

///|
fn is_gemini_synthesized_tool_call_id(id : String) -> Bool {
  id.has_prefix("gemini_synth_")
}

///|
fn gemini_tool_result_name(
  block_obj : Map[String, Json],
  tool_names_by_id : Map[String, String],
) -> String {
  match json_string_from_map(block_obj, "name") {
    Some(name) => name
    None =>
      match json_string_from_map(block_obj, "tool_use_id") {
        Some(id) =>
          match tool_names_by_id.get(id) {
            Some(name) => name
            None => id
          }
        None => "tool_result"
      }
  }
}

///|
fn count_assistant_messages(messages : Array[Json]) -> Int {
  let mut count = 0
  for message in messages {
    guard message is Object(message_obj) else { continue }
    if json_string_from_map(message_obj, "role") == Some("assistant") {
      count += 1
    }
  }
  count
}

///|
fn latest_gemini_shadow_turns(
  shadow_turns : Array[GeminiAssistantTurn],
  total_assistant_messages : Int,
) -> Array[GeminiAssistantTurn] {
  if total_assistant_messages <= 0 {
    return []
  }
  let start = if shadow_turns.length() > total_assistant_messages {
    shadow_turns.length() - total_assistant_messages
  } else {
    0
  }
  let effective : Array[GeminiAssistantTurn] = []
  for index in start..<shadow_turns.length() {
    effective.push(shadow_turns[index])
  }
  effective
}

///|
fn seed_tool_names_from_assistant_message(
  message_obj : Map[String, Json],
  tool_names_by_id : Map[String, String],
) -> Unit {
  guard message_obj.get("content") is Some(Array(blocks)) else { return }
  for block in blocks {
    guard block is Object(block_obj) else { continue }
    guard json_string_from_map(block_obj, "type") == Some("tool_use") else {
      continue
    }
    let id = json_string_from_map(block_obj, "id").unwrap_or("")
    let name = json_string_from_map(block_obj, "name").unwrap_or("")
    if !id.is_empty() && !name.is_empty() && tool_names_by_id.get(id) is None {
      tool_names_by_id[id] = name
    }
  }
}

///|
fn build_tool_name_map_from_shadow_turns(
  shadow_turns : Array[GeminiAssistantTurn],
) -> Map[String, String] {
  let tool_names_by_id : Map[String, String] = Map([], capacity=0)
  for turn in shadow_turns {
    merge_tool_names_from_shadow(turn, tool_names_by_id)
  }
  tool_names_by_id
}

///|
fn merge_tool_names_from_shadow(
  turn : GeminiAssistantTurn,
  tool_names_by_id : Map[String, String],
) -> Unit {
  for tool_call in turn.tool_calls {
    match tool_call.id {
      Some(id) if !id.is_empty() && !tool_call.name.is_empty() =>
        tool_names_by_id[id] = tool_call.name
      _ => ()
    }
  }
  match shadow_parts_for_replay(turn.assistant_content) {
    Some(parts) => merge_tool_names_from_parts(parts, tool_names_by_id)
    None => ()
  }
}

///|
fn merge_tool_names_from_parts(
  parts : Array[Json],
  tool_names_by_id : Map[String, String],
) -> Unit {
  for part in parts {
    guard part is Object(part_obj) else { continue }
    guard part_obj.get("functionCall") is Some(Object(function_call)) else {
      continue
    }
    let id = json_string_from_map(function_call, "id").unwrap_or("")
    let name = json_string_from_map(function_call, "name").unwrap_or("")
    if !id.is_empty() && !name.is_empty() {
      tool_names_by_id[id] = name
    }
  }
}

///|
fn build_thought_signature_map_from_shadow_turns(
  shadow_turns : Array[GeminiAssistantTurn],
) -> Map[String, String] {
  let thought_signature_by_id : Map[String, String] = Map([], capacity=0)
  for turn in shadow_turns {
    merge_thought_signatures_from_shadow(turn, thought_signature_by_id)
  }
  thought_signature_by_id
}

///|
fn merge_thought_signatures_from_shadow(
  turn : GeminiAssistantTurn,
  thought_signature_by_id : Map[String, String],
) -> Unit {
  for tool_call in turn.tool_calls {
    match (tool_call.id, tool_call.thought_signature) {
      (Some(id), Some(signature)) if !id.is_empty() && !signature.is_empty() =>
        thought_signature_by_id[id] = signature
      _ => ()
    }
  }
}

///|
fn find_matching_shadow_turn_for_assistant_message(
  content : Json?,
  shadow_turns : Array[GeminiAssistantTurn],
  used_shadow_indices : Map[Int, Bool],
) -> Int? {
  let (tool_use_ids, tool_use_names) = extract_assistant_tool_use_keys(content)
  if tool_use_ids.is_empty() && tool_use_names.is_empty() {
    return None
  }
  if !tool_use_ids.is_empty() {
    let mut index = 0
    for turn in shadow_turns {
      if used_shadow_indices.get(index) is None &&
        shadow_turn_matches_tool_ids(turn, tool_use_ids) {
        return Some(index)
      }
      index += 1
    }
  }
  let mut index = 0
  for turn in shadow_turns {
    if used_shadow_indices.get(index) is None &&
      shadow_turn_matches_tool_names(turn, tool_use_names) {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn extract_assistant_tool_use_keys(
  content : Json?,
) -> (Array[String], Array[String]) {
  let ids : Array[String] = []
  let names : Array[String] = []
  guard content is Some(Array(blocks)) else { return (ids, names) }
  for block in blocks {
    guard block is Object(block_obj) else { continue }
    guard json_string_from_map(block_obj, "type") == Some("tool_use") else {
      continue
    }
    match json_string_from_map(block_obj, "id") {
      Some(id) if !id.is_empty() && !ids.contains(id) => ids.push(id)
      _ => ()
    }
    match json_string_from_map(block_obj, "name") {
      Some(name) if !name.is_empty() => {
        if !names.contains(name) {
          names.push(name)
        }
        let normalized = normalize_gemini_tool_name(name)
        if !normalized.is_empty() && !names.contains(normalized) {
          names.push(normalized)
        }
      }
      _ => ()
    }
  }
  (ids, names)
}

///|
fn shadow_turn_matches_tool_ids(
  turn : GeminiAssistantTurn,
  tool_use_ids : Array[String],
) -> Bool {
  turn.tool_calls.any(fn(tool_call) {
    match tool_call.id {
      Some(id) => tool_use_ids.contains(id)
      None => false
    }
  })
}

///|
fn shadow_turn_matches_tool_names(
  turn : GeminiAssistantTurn,
  tool_use_names : Array[String],
) -> Bool {
  turn.tool_calls.any(fn(tool_call) {
    tool_use_names.contains(tool_call.name) ||
    tool_use_names.contains(normalize_gemini_tool_name(tool_call.name))
  })
}

///|
fn normalize_gemini_tool_name(name : String) -> String {
  let parts = name.split(":").collect()
  match parts.last() {
    Some(part) => part.to_owned()
    None => name
  }
}

///|
fn shadow_parts_for_replay(content : Json) -> Array[Json]? {
  let source_parts = match content {
    Object(obj) =>
      match obj.get("parts") {
        Some(Array(parts)) => Some(parts)
        _ => None
      }
    Array(parts) => Some(parts)
    _ => None
  }
  guard source_parts is Some(source_parts) else { return None }
  let parts : Array[Json] = []
  for part in source_parts {
    parts.push(shadow_part_for_replay(part))
  }
  Some(parts)
}

///|
fn shadow_part_for_replay(part : Json) -> Json {
  guard part is Object(part_obj) else { return part }
  let replay_part = part_obj.copy()
  if replay_part.get("functionCall") is Some(Object(function_call)) {
    let replay_function_call = function_call.copy()
    let drop_id = match json_string_from_map(replay_function_call, "id") {
      Some(id) => id.is_empty() || is_gemini_synthesized_tool_call_id(id)
      None => true
    }
    if drop_id {
      replay_function_call.remove("id")
    }
    replay_part["functionCall"] = Json::object(replay_function_call)
  }
  Json::object(replay_part)
}

///|
fn extract_gemini_shadow_turn_from_response(
  body : Json,
) -> GeminiAssistantTurn? {
  guard body is Object(obj) else { return None }
  guard obj.get("candidates") is Some(Array(candidates)) &&
    candidates.get(0) is Some(Object(candidate)) &&
    candidate.get("content") is Some(Object(content)) &&
    content.get("parts") is Some(Array(parts)) else {
    return None
  }
  let normalized_parts = normalize_gemini_shadow_parts(parts)
  if normalized_parts.is_empty() {
    return None
  }
  let assistant_content = Json::object({
    "parts": Json::array(normalized_parts),
  })
  Some({
    assistant_content,
    tool_calls: extract_gemini_tool_call_meta(normalized_parts),
  })
}

///|
fn normalize_gemini_shadow_parts(parts : Array[Json]) -> Array[Json] {
  let normalized : Array[Json] = []
  let mut tool_position = 0
  for part in parts {
    guard part is Object(part_obj) else { continue }
    let normalized_part = part_obj.copy()
    if part_obj.get("functionCall") is Some(Object(function_call)) {
      let normalized_function_call = function_call.copy()
      let id = match json_string_from_map(normalized_function_call, "id") {
        Some(id) if !id.is_empty() => id
        _ => generate_gemini_shadow_synth_tool_call_id(tool_position)
      }
      normalized_function_call["id"] = Json::string(id)
      normalized_part["functionCall"] = Json::object(normalized_function_call)
      tool_position += 1
    }
    normalized.push(Json::object(normalized_part))
  }
  normalized
}

///|
fn extract_gemini_tool_call_meta(
  parts : Array[Json],
) -> Array[GeminiToolCallMeta] {
  let tool_calls : Array[GeminiToolCallMeta] = []
  for part in parts {
    guard part is Object(part_obj) else { continue }
    guard part_obj.get("functionCall") is Some(Object(function_call)) else {
      continue
    }
    tool_calls.push({
      id: json_string_from_map(function_call, "id"),
      name: json_string_from_map(function_call, "name").unwrap_or(""),
      args: function_call.get("args").unwrap_or(Json::object({})),
      thought_signature: json_string_from_map(part_obj, "thoughtSignature"),
    })
  }
  tool_calls
}

///|
fn generate_gemini_shadow_synth_tool_call_id(position : Int) -> String {
  "gemini_synth_\{position}"
}

///|
fn append_gemini_generation_config(
  obj : Map[String, Json],
  result : Map[String, Json],
) -> Unit {
  let config : Map[String, Json] = {}
  if obj.get("max_tokens") is Some(value) {
    config["maxOutputTokens"] = value
  }
  copy_json_field(obj, config, "temperature")
  if obj.get("top_p") is Some(value) {
    config["topP"] = value
  }
  if obj.get("stop_sequences") is Some(value) {
    config["stopSequences"] = value
  }
  if !config.is_empty() {
    result["generationConfig"] = Json::object(config)
  }
}

///|
fn append_gemini_tools(
  obj : Map[String, Json],
  result : Map[String, Json],
) -> Unit {
  guard obj.get("tools") is Some(Array(tools)) else { return }
  let declarations : Array[Json] = []
  for tool in tools {
    guard tool is Object(tool_obj) else { continue }
    if json_string_from_map(tool_obj, "type") == Some("BatchTool") {
      continue
    }
    let declaration : Map[String, Json] = {
      "name": Json::string(json_string_from_map(tool_obj, "name").unwrap_or("")),
      "parameters": tool_obj.get("input_schema").unwrap_or(Json::object({})),
    }
    if tool_obj.get("description") is Some(desc) {
      declaration["description"] = desc
    }
    declarations.push(Json::object(declaration))
  }
  if !declarations.is_empty() {
    result["tools"] = Json::array([
      Json::object({ "functionDeclarations": Json::array(declarations) }),
    ])
  }
}

///|
fn append_gemini_tool_choice(
  obj : Map[String, Json],
  result : Map[String, Json],
) -> Unit {
  guard obj.get("tool_choice") is Some(choice) else { return }
  let config : Map[String, Json] = {}
  match choice {
    String("any") => config["mode"] = Json::string("ANY")
    String("auto") => config["mode"] = Json::string("AUTO")
    String("none") => config["mode"] = Json::string("NONE")
    Object(choice_obj) =>
      match json_string_from_map(choice_obj, "type") {
        Some("any") => config["mode"] = Json::string("ANY")
        Some("auto") => config["mode"] = Json::string("AUTO")
        Some("none") => config["mode"] = Json::string("NONE")
        Some("tool") => {
          config["mode"] = Json::string("ANY")
          if choice_obj.get("name") is Some(String(name)) {
            config["allowedFunctionNames"] = Json::array([Json::string(name)])
          }
        }
        _ => ()
      }
    _ => ()
  }
  if !config.is_empty() {
    result["toolConfig"] = Json::object({
      "functionCallingConfig": Json::object(config),
    })
  }
}

///|
fn anthropic_json_to_openai_chat(
  body : Json,
  explicit_prompt_cache_key : String?,
) -> Json {
  guard body is Object(obj) else { return body }
  let result : Map[String, Json] = {}
  copy_json_field(obj, result, "model")
  let messages : Array[Json] = []
  append_openai_chat_system_messages(obj, messages)
  append_openai_chat_messages(obj, messages)
  result["messages"] = Json::array(messages)
  let model = json_string_from_map(obj, "model").unwrap_or("")
  if obj.get("max_tokens") is Some(value) {
    if is_openai_o_series_model(model) {
      result["max_completion_tokens"] = value
    } else {
      result["max_tokens"] = value
    }
  }
  copy_json_field(obj, result, "temperature")
  copy_json_field(obj, result, "top_p")
  if obj.get("stop_sequences") is Some(value) {
    result["stop"] = value
  }
  copy_json_field(obj, result, "stream")
  append_openai_chat_tools(obj, result)
  append_openai_chat_tool_choice(obj, result)
  if explicit_prompt_cache_key is Some(key) && !key.trim().is_empty() {
    result["prompt_cache_key"] = Json::string(key)
  }
  inject_openai_stream_include_usage(result)
  Json::object(result)
}

///|
fn anthropic_json_to_openai_responses(
  body : Json,
  cache_key : String?,
  is_codex_oauth : Bool,
  codex_fast_mode : Bool,
) -> Json {
  guard body is Object(obj) else { return body }
  let result : Map[String, Json] = {}
  copy_json_field(obj, result, "model")
  let instructions = anthropic_system_instructions(obj)
  if !instructions.is_empty() {
    result["instructions"] = Json::string(instructions)
  }
  result["input"] = Json::array(anthropic_messages_to_responses_input(obj))
  if obj.get("max_tokens") is Some(value) {
    result["max_output_tokens"] = value
  }
  copy_json_field(obj, result, "temperature")
  copy_json_field(obj, result, "top_p")
  copy_json_field(obj, result, "stream")
  append_openai_responses_reasoning(obj, result)
  append_openai_responses_tools(obj, result)
  append_openai_responses_tool_choice(obj, result)
  if cache_key is Some(key) && !key.trim().is_empty() {
    result["prompt_cache_key"] = Json::string(key)
  }
  if is_codex_oauth {
    apply_codex_oauth_responses_constraints(result, obj, codex_fast_mode)
  }
  Json::object(result)
}

///|
fn append_openai_responses_reasoning(
  obj : Map[String, Json],
  result : Map[String, Json],
) -> Unit {
  guard json_string_from_map(obj, "model") is Some(model) else { return }
  guard supports_openai_responses_reasoning_effort(model) else { return }
  guard resolve_openai_responses_reasoning_effort(obj) is Some(effort) else {
    return
  }
  result["reasoning"] = Json::object({ "effort": Json::string(effort) })
}

///|
fn supports_openai_responses_reasoning_effort(model : String) -> Bool {
  let normalized = model.to_lower()
  if is_openai_o_series_model(normalized) {
    return true
  }
  normalized.has_prefix("gpt-") &&
  normalized.length() > "gpt-".length() &&
  normalized["gpt-".length()] >= 53 &&
  normalized["gpt-".length()] <= 57
}

///|
fn resolve_openai_responses_reasoning_effort(
  obj : Map[String, Json],
) -> String? {
  match obj.get("output_config") {
    Some(Object(output_config)) =>
      match json_string_from_map(output_config, "effort") {
        Some("low") => return Some("low")
        Some("medium") => return Some("medium")
        Some("high") => return Some("high")
        Some("max") => return Some("xhigh")
        Some(_) => return None
        None => ()
      }
    _ => ()
  }
  match obj.get("thinking") {
    Some(Object(thinking)) =>
      match json_string_from_map(thinking, "type") {
        Some("adaptive") => Some("xhigh")
        Some("enabled") =>
          match json_int_from_map(thinking, "budget_tokens") {
            Some(budget) if budget < 4000 => Some("low")
            Some(budget) if budget < 16000 => Some("medium")
            Some(_) => Some("high")
            None => Some("high")
          }
        _ => None
      }
    _ => None
  }
}

///|
fn copy_json_field(
  source : Map[String, Json],
  target : Map[String, Json],
  key : String,
) -> Unit {
  if source.get(key) is Some(value) {
    target[key] = value
  }
}

///|
fn is_openai_o_series_model(model : String) -> Bool {
  model.length() > 1 && model[0] == 'o' && model[1] >= 48 && model[1] <= 57
}

///|
fn append_openai_chat_system_messages(
  obj : Map[String, Json],
  messages : Array[Json],
) -> Unit {
  let instructions = anthropic_system_instructions(obj)
  if !instructions.is_empty() {
    messages.push(
      Json::object({
        "role": Json::string("system"),
        "content": Json::string(instructions),
      }),
    )
  }
}

///|
fn anthropic_system_instructions(obj : Map[String, Json]) -> String {
  match obj.get("system") {
    Some(String(text)) => strip_leading_anthropic_billing_header(text)
    Some(Array(items)) => {
      let parts : Array[String] = []
      for item in items {
        match item {
          String(text) => {
            let stripped = strip_leading_anthropic_billing_header(text)
            if !stripped.is_empty() {
              parts.push(stripped)
            }
          }
          Object(system_obj) =>
            if system_obj.get("text") is Some(String(text)) {
              let stripped = strip_leading_anthropic_billing_header(text)
              if !stripped.is_empty() {
                parts.push(stripped)
              }
            }
          _ => ()
        }
      }
      parts.join("\n\n")
    }
    _ => ""
  }
}

///|
fn strip_leading_anthropic_billing_header(text : String) -> String {
  let prefix = "x-anthropic-billing-header:"
  if !text.has_prefix(prefix) {
    return text
  }
  let line_end = match (text.find("\r"), text.find("\n")) {
    (Some(cr), Some(lf)) => Some(if cr < lf { cr } else { lf })
    (Some(cr), None) => Some(cr)
    (None, Some(lf)) => Some(lf)
    (None, None) => None
  }
  guard line_end is Some(line_end) else { return "" }
  let mut rest_start = line_end + 1
  if text[line_end:line_end + 1] == "\r" &&
    rest_start < text.length() &&
    text[rest_start:rest_start + 1] == "\n" {
    rest_start += 1
  }
  let rest = text[rest_start:]
  if rest.has_prefix("\r\n") {
    rest[2:].to_owned()
  } else if rest.has_prefix("\n") || rest.has_prefix("\r") {
    rest[1:].to_owned()
  } else {
    rest.to_owned()
  }
}

///|
fn append_openai_chat_messages(
  obj : Map[String, Json],
  messages : Array[Json],
) -> Unit {
  guard obj.get("messages") is Some(Array(source_messages)) else { return }
  for message in source_messages {
    guard message is Object(message_obj) else { continue }
    let role = json_string_from_map(message_obj, "role").unwrap_or("user")
    match message_obj.get("content") {
      Some(Array(blocks)) => append_openai_chat_blocks(role, blocks, messages)
      Some(content) =>
        messages.push(
          Json::object({ "role": Json::string(role), "content": content }),
        )
      None =>
        messages.push(
          Json::object({ "role": Json::string(role), "content": Json::null() }),
        )
    }
  }
}

///|
fn append_openai_chat_blocks(
  role : String,
  blocks : Array[Json],
  messages : Array[Json],
) -> Unit {
  let content_parts : Array[Json] = []
  let tool_calls : Array[Json] = []
  for block in blocks {
    guard block is Object(block_obj) else { continue }
    match json_string_from_map(block_obj, "type") {
      Some("text") =>
        if block_obj.get("text") is Some(String(text)) {
          content_parts.push(Json::string(text))
        }
      Some("image") =>
        if block_obj.get("source") is Some(Object(source)) {
          let media_type = json_string_from_map(source, "media_type").unwrap_or(
            "image/png",
          )
          let data = json_string_from_map(source, "data").unwrap_or("")
          content_parts.push(
            Json::object({
              "type": Json::string("image_url"),
              "image_url": Json::object({
                "url": Json::string("data:\{media_type};base64,\{data}"),
              }),
            }),
          )
        }
      Some("tool_use") => tool_calls.push(openai_chat_tool_call(block_obj))
      Some("tool_result") =>
        messages.push(openai_chat_tool_result_message(block_obj))
      _ => ()
    }
  }
  if !content_parts.is_empty() || !tool_calls.is_empty() {
    let message : Map[String, Json] = { "role": Json::string(role) }
    if content_parts.is_empty() {
      message["content"] = Json::null()
    } else if content_parts.length() == 1 {
      message["content"] = content_parts[0]
    } else {
      message["content"] = Json::array(content_parts)
    }
    if !tool_calls.is_empty() {
      message["tool_calls"] = Json::array(tool_calls)
    }
    messages.push(Json::object(message))
  }
}

///|
fn openai_chat_tool_call(block_obj : Map[String, Json]) -> Json {
  Json::object({
    "id": Json::string(json_string_from_map(block_obj, "id").unwrap_or("")),
    "type": Json::string("function"),
    "function": Json::object({
      "name": Json::string(
        json_string_from_map(block_obj, "name").unwrap_or(""),
      ),
      "arguments": Json::string(
        canonicalize_tool_arguments(block_obj.get("input")),
      ),
    }),
  })
}

///|
fn openai_chat_tool_result_message(block_obj : Map[String, Json]) -> Json {
  let content = match block_obj.get("content") {
    Some(String(text)) => text
    Some(json) => json.stringify()
    None => ""
  }
  Json::object({
    "role": Json::string("tool"),
    "tool_call_id": Json::string(
      json_string_from_map(block_obj, "tool_use_id").unwrap_or(""),
    ),
    "content": Json::string(content),
  })
}

///|
fn append_openai_chat_tools(
  obj : Map[String, Json],
  result : Map[String, Json],
) -> Unit {
  guard obj.get("tools") is Some(Array(tools)) else { return }
  let converted : Array[Json] = []
  for tool in tools {
    guard tool is Object(tool_obj) else { continue }
    if json_string_from_map(tool_obj, "type") == Some("BatchTool") {
      continue
    }
    converted.push(
      Json::object({
        "type": Json::string("function"),
        "function": Json::object({
          "name": Json::string(
            json_string_from_map(tool_obj, "name").unwrap_or(""),
          ),
          "description": tool_obj.get("description").unwrap_or(Json::null()),
          "parameters": tool_obj.get("input_schema").unwrap_or(Json::object({})),
        }),
      }),
    )
  }
  if !converted.is_empty() {
    result["tools"] = Json::array(converted)
  }
}

///|
fn append_openai_chat_tool_choice(
  obj : Map[String, Json],
  result : Map[String, Json],
) -> Unit {
  if obj.get("tool_choice") is Some(choice) {
    result["tool_choice"] = map_tool_choice_to_openai_chat(choice)
  }
}

///|
fn map_tool_choice_to_openai_chat(choice : Json) -> Json {
  match choice {
    String("any") => Json::string("required")
    String(_) => choice
    Object(obj) =>
      match json_string_from_map(obj, "type") {
        Some("any") => Json::string("required")
        Some("auto") => Json::string("auto")
        Some("none") => Json::string("none")
        Some("tool") =>
          Json::object({
            "type": Json::string("function"),
            "function": Json::object({
              "name": Json::string(
                json_string_from_map(obj, "name").unwrap_or(""),
              ),
            }),
          })
        _ => Json::object(obj)
      }
    _ => choice
  }
}

///|
fn inject_openai_stream_include_usage(result : Map[String, Json]) -> Unit {
  guard json_bool_from_map(result, "stream").unwrap_or(false) else { return }
  match result.get("stream_options") {
    Some(Object(opts)) => {
      opts["include_usage"] = Json::boolean(true)
      result["stream_options"] = Json::object(opts)
    }
    _ =>
      result["stream_options"] = Json::object({
        "include_usage": Json::boolean(true),
      })
  }
}

///|
fn anthropic_messages_to_responses_input(
  obj : Map[String, Json],
) -> Array[Json] {
  guard obj.get("messages") is Some(Array(source_messages)) else { return [] }
  let input : Array[Json] = []
  for message in source_messages {
    guard message is Object(message_obj) else { continue }
    let role = json_string_from_map(message_obj, "role").unwrap_or("user")
    if message_obj.get("content") is Some(Array(blocks)) {
      append_response_input_blocks(role, blocks, input)
    } else {
      let content = match message_obj.get("content") {
        Some(String(text)) => text
        Some(json) => json.stringify()
        None => ""
      }
      input.push(
        Json::object({
          "role": Json::string(
            if role == "assistant" {
              "assistant"
            } else {
              "user"
            },
          ),
          "content": Json::string(content),
        }),
      )
    }
  }
  input
}

///|
fn append_response_input_blocks(
  role : String,
  blocks : Array[Json],
  input : Array[Json],
) -> Unit {
  let texts : Array[String] = []
  for block in blocks {
    guard block is Object(block_obj) else { continue }
    match json_string_from_map(block_obj, "type") {
      Some("text") =>
        if block_obj.get("text") is Some(String(text)) {
          texts.push(text)
        }
      Some("tool_use") =>
        input.push(
          Json::object({
            "type": Json::string("function_call"),
            "call_id": Json::string(
              json_string_from_map(block_obj, "id").unwrap_or(""),
            ),
            "name": Json::string(
              json_string_from_map(block_obj, "name").unwrap_or(""),
            ),
            "arguments": Json::string(
              canonicalize_tool_arguments(block_obj.get("input")),
            ),
          }),
        )
      Some("tool_result") =>
        input.push(
          Json::object({
            "type": Json::string("function_call_output"),
            "call_id": Json::string(
              json_string_from_map(block_obj, "tool_use_id").unwrap_or(""),
            ),
            "output": Json::string(
              block_obj.get("content").unwrap_or(Json::string("")).stringify(),
            ),
          }),
        )
      _ => ()
    }
  }
  if !texts.is_empty() {
    input.push(
      Json::object({
        "role": Json::string(
          if role == "assistant" {
            "assistant"
          } else {
            "user"
          },
        ),
        "content": Json::string(texts.join("\n")),
      }),
    )
  }
}

///|
fn append_openai_responses_tools(
  obj : Map[String, Json],
  result : Map[String, Json],
) -> Unit {
  guard obj.get("tools") is Some(Array(tools)) else { return }
  let converted : Array[Json] = []
  for tool in tools {
    guard tool is Object(tool_obj) else { continue }
    if json_string_from_map(tool_obj, "type") == Some("BatchTool") {
      continue
    }
    converted.push(
      Json::object({
        "type": Json::string("function"),
        "name": Json::string(
          json_string_from_map(tool_obj, "name").unwrap_or(""),
        ),
        "description": tool_obj.get("description").unwrap_or(Json::null()),
        "parameters": tool_obj.get("input_schema").unwrap_or(Json::object({})),
      }),
    )
  }
  if !converted.is_empty() {
    result["tools"] = Json::array(converted)
  }
}

///|
fn append_openai_responses_tool_choice(
  obj : Map[String, Json],
  result : Map[String, Json],
) -> Unit {
  if obj.get("tool_choice") is Some(choice) {
    result["tool_choice"] = map_tool_choice_to_openai_responses(choice)
  }
}

///|
fn map_tool_choice_to_openai_responses(choice : Json) -> Json {
  match choice {
    String("any") => Json::string("required")
    String(_) => choice
    Object(obj) =>
      match json_string_from_map(obj, "type") {
        Some("any") => Json::string("required")
        Some("auto") => Json::string("auto")
        Some("none") => Json::string("none")
        Some("tool") =>
          Json::object({
            "type": Json::string("function"),
            "name": Json::string(
              json_string_from_map(obj, "name").unwrap_or(""),
            ),
          })
        _ => Json::object(obj)
      }
    _ => choice
  }
}

///|
fn apply_codex_oauth_responses_constraints(
  result : Map[String, Json],
  source : Map[String, Json],
  codex_fast_mode : Bool,
) -> Unit {
  result["store"] = Json::boolean(false)
  if codex_fast_mode {
    result["service_tier"] = Json::string("priority")
  } else {
    result.remove("service_tier")
  }
  let marker = Json::string("reasoning.encrypted_content")
  let includes : Array[Json] = match source.get("include") {
    Some(Array(values)) => values
    _ => []
  }
  let mut has_marker = false
  for value in includes {
    if value == marker {
      has_marker = true
    }
  }
  if !has_marker {
    includes.push(marker)
  }
  result["include"] = Json::array(includes)
  result.remove("max_output_tokens")
  result.remove("temperature")
  result.remove("top_p")
  if result.get("instructions") is None {
    result["instructions"] = Json::string("")
  }
  if result.get("tools") is None {
    result["tools"] = Json::array([])
  }
  if result.get("parallel_tool_calls") is None {
    result["parallel_tool_calls"] = Json::boolean(false)
  }
  result["stream"] = Json::boolean(true)
}
