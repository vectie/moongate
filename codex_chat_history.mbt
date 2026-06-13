///|
const MAX_CODEX_CHAT_HISTORY_RESPONSES : Int = 512

///|
priv struct CachedCodexChatResponse {
  calls_by_id : Map[String, Json]
  call_order : Array[String]
}

///|
fn CachedCodexChatResponse::new() -> CachedCodexChatResponse {
  { calls_by_id: Map([], capacity=0), call_order: [] }
}

///|
priv struct CodexChatLookup {
  previous : CachedCodexChatResponse?
  fallback : CachedCodexChatResponse
}

///|
struct CodexChatHistoryStore {
  max_responses : Int
  responses : Map[String, CachedCodexChatResponse]
  response_order : Array[String]
  call_index : Map[String, Array[String]]
}

///|
fn CodexChatHistoryStore::new(
  max_responses? : Int = MAX_CODEX_CHAT_HISTORY_RESPONSES,
) -> CodexChatHistoryStore {
  {
    max_responses: if max_responses < 1 {
      1
    } else {
      max_responses
    },
    responses: Map([], capacity=0),
    response_order: [],
    call_index: Map([], capacity=0),
  }
}

///|
fn CodexChatHistoryStore::record_response(
  self : CodexChatHistoryStore,
  response : Json,
) -> Int {
  guard response is Object(obj) else { return 0 }
  guard json_string_from_map(obj, "id") is Some(response_id) &&
    !response_id.trim().is_empty() else {
    return 0
  }
  guard obj.get("output") is Some(Array(output)) else { return 0 }
  let calls : Array[(String, Json)] = []
  for item in output {
    match codex_chat_cached_call_item(item) {
      Some(call) => calls.push(call)
      None => ()
    }
  }
  if calls.is_empty() {
    return 0
  }
  self.insert_calls(response_id, calls)
}

///|
fn CodexChatHistoryStore::record_call_item(
  self : CodexChatHistoryStore,
  response_id : String?,
  item : Json,
) -> Bool {
  guard response_id is Some(response_id) && !response_id.trim().is_empty() else {
    return false
  }
  guard codex_chat_cached_call_item(item) is Some(call) else { return false }
  self.insert_calls(response_id, [call]) > 0
}

///|
fn CodexChatHistoryStore::record_stream_events(
  self : CodexChatHistoryStore,
  events : Array[Json],
) -> Int {
  let mut response_id : String? = None
  let mut recorded = 0
  for event in events {
    guard event is Object(obj) else { continue }
    match obj.get("response") {
      Some(Object(response)) =>
        match json_string_from_map(response, "id") {
          Some(id) if !id.trim().is_empty() => response_id = Some(id)
          _ => ()
        }
      _ => ()
    }
    match json_string_from_map(obj, "type") {
      Some("response.output_item.done") =>
        match obj.get("item") {
          Some(item) =>
            if self.record_call_item(response_id, item) {
              recorded += 1
            }
          None => ()
        }
      Some("response.completed") =>
        match obj.get("response") {
          Some(response) => recorded += self.record_response(response)
          None => ()
        }
      _ => ()
    }
  }
  recorded
}

///|
fn CodexChatHistoryStore::enriched_request(
  self : CodexChatHistoryStore,
  request : Json,
) -> Json {
  let copied = copy_json(request)
  ignore(self.enrich_request_in_place(copied))
  copied
}

///|
fn CodexChatHistoryStore::enrich_request_in_place(
  self : CodexChatHistoryStore,
  request : Json,
) -> Int {
  guard request is Object(obj) else { return 0 }
  let previous_response_id = match
    json_string_from_map(obj, "previous_response_id") {
    Some(value) if !value.trim().is_empty() => Some(value)
    _ => None
  }
  guard obj.get("input") is Some(input) else { return 0 }
  let (items, original_was_object) = match input {
    Array(items) => (items, false)
    Object(_) => ([input], true)
    _ => return 0
  }
  let output_call_ids : Array[String] = []
  let existing_call_ids : Array[String] = []
  for item in items {
    guard item is Object(item_obj) else { continue }
    match json_string_from_map(item_obj, "type") {
      Some(type_) if codex_chat_is_call_output_item_type(type_) =>
        match codex_chat_response_item_call_id(item) {
          Some(call_id) if !output_call_ids.contains(call_id) =>
            output_call_ids.push(call_id)
          _ => ()
        }
      Some(type_) if codex_chat_is_call_item_type(type_) =>
        match codex_chat_response_item_call_id(item) {
          Some(call_id) if !existing_call_ids.contains(call_id) =>
            existing_call_ids.push(call_id)
          _ => ()
        }
      _ => ()
    }
  }
  let requested_call_ids = codex_chat_union_ids(
    output_call_ids, existing_call_ids,
  )
  let lookup = self.lookup(previous_response_id, requested_call_ids)
  let restore_group = lookup.restore_group(output_call_ids, existing_call_ids)
  let restore_group_ids = codex_chat_group_call_ids(restore_group)
  let mut restore_group_available = true
  let seen_call_ids : Array[String] = []
  let new_items : Array[Json] = []
  let mut restored = 0
  let mut enriched = 0
  for item in items {
    guard item is Object(item_obj) else {
      new_items.push(item)
      continue
    }
    match json_string_from_map(item_obj, "type") {
      Some(type_) if codex_chat_is_call_item_type(type_) => {
        match codex_chat_response_item_call_id(item) {
          Some(call_id) => {
            match lookup.call(call_id) {
              Some(cached) =>
                if codex_chat_enrich_call_item_reasoning(item, cached) {
                  enriched += 1
                }
              None => ()
            }
            if !seen_call_ids.contains(call_id) {
              seen_call_ids.push(call_id)
            }
          }
          None => ()
        }
        new_items.push(item)
      }
      Some(type_) if codex_chat_is_call_output_item_type(type_) => {
        if restore_group_available && !restore_group.is_empty() {
          for cached in restore_group {
            let cached_item = cached.1
            match codex_chat_response_item_call_id(cached_item) {
              Some(call_id) if !seen_call_ids.contains(call_id) =>
                seen_call_ids.push(call_id)
              _ => ()
            }
            new_items.push(copy_json(cached_item))
            restored += 1
          }
          restore_group_available = false
        }
        match codex_chat_response_item_call_id(item) {
          Some(call_id) =>
            if !seen_call_ids.contains(call_id) &&
              !restore_group_ids.contains(call_id) {
              match lookup.call(call_id) {
                Some(cached) => {
                  seen_call_ids.push(call_id)
                  new_items.push(copy_json(cached))
                  restored += 1
                }
                None => ()
              }
            }
          None => ()
        }
        new_items.push(item)
      }
      _ => new_items.push(item)
    }
  }
  let changed = restored + enriched
  if changed == 0 && original_was_object && new_items.length() == 1 {
    obj["input"] = new_items[0]
  } else {
    obj["input"] = Json::array(new_items)
  }
  changed
}

///|
fn CodexChatHistoryStore::insert_calls(
  self : CodexChatHistoryStore,
  response_id : String,
  calls : Array[(String, Json)],
) -> Int {
  if self.responses.get(response_id) is None {
    self.response_order.push(response_id)
  }
  let cached = self.responses
    .get(response_id)
    .unwrap_or(CachedCodexChatResponse::new())
  let mut count = 0
  for call in calls {
    let call_id = call.0
    let item = call.1
    if cached.calls_by_id.get(call_id) is None {
      cached.call_order.push(call_id)
    }
    cached.calls_by_id[call_id] = copy_json(item)
    self.index_call(call_id, response_id)
    count += 1
  }
  self.responses[response_id] = cached
  self.prune()
  count
}

///|
fn CodexChatHistoryStore::index_call(
  self : CodexChatHistoryStore,
  call_id : String,
  response_id : String,
) -> Unit {
  let response_ids = self.call_index.get(call_id).unwrap_or([])
  if !response_ids.contains(response_id) {
    response_ids.push(response_id)
  }
  self.call_index[call_id] = response_ids
}

///|
fn CodexChatHistoryStore::prune(self : CodexChatHistoryStore) -> Unit {
  while self.response_order.length() > self.max_responses {
    let response_id = self.response_order[0]
    ignore(self.response_order.remove(0))
    self.responses.remove(response_id)
    self.remove_response_from_call_index(response_id)
  }
}

///|
fn CodexChatHistoryStore::remove_response_from_call_index(
  self : CodexChatHistoryStore,
  response_id : String,
) -> Unit {
  let keys = self.call_index.keys().collect()
  for call_id in keys {
    guard self.call_index.get(call_id) is Some(response_ids) else { continue }
    let filtered : Array[String] = []
    for cached_id in response_ids {
      if cached_id != response_id {
        filtered.push(cached_id)
      }
    }
    if filtered.is_empty() {
      self.call_index.remove(call_id)
    } else {
      self.call_index[call_id] = filtered
    }
  }
}

///|
fn CodexChatHistoryStore::lookup(
  self : CodexChatHistoryStore,
  previous_response_id : String?,
  requested_call_ids : Array[String],
) -> CodexChatLookup {
  let previous = match previous_response_id {
    Some(id) => self.responses.get(id)
    None => None
  }
  {
    previous,
    fallback: self.unique_fallback_calls(requested_call_ids, previous),
  }
}

///|
fn CodexChatHistoryStore::unique_fallback_calls(
  self : CodexChatHistoryStore,
  requested_call_ids : Array[String],
  previous : CachedCodexChatResponse?,
) -> CachedCodexChatResponse {
  let selected : Map[String, Json] = Map([], capacity=0)
  for call_id in requested_call_ids {
    match previous {
      Some(response) if response.calls_by_id.get(call_id) is Some(_) => continue
      _ => ()
    }
    match self.unique_call(call_id) {
      Some(item) => selected[call_id] = item
      None => ()
    }
  }
  let fallback = CachedCodexChatResponse::new()
  for response_id in self.response_order {
    guard self.responses.get(response_id) is Some(response) else { continue }
    for call_id in response.call_order {
      match selected.get(call_id) {
        Some(item) => {
          fallback.call_order.push(call_id)
          fallback.calls_by_id[call_id] = copy_json(item)
        }
        None => ()
      }
    }
  }
  fallback
}

///|
fn CodexChatHistoryStore::unique_call(
  self : CodexChatHistoryStore,
  call_id : String,
) -> Json? {
  guard self.call_index.get(call_id) is Some(response_ids) else { return None }
  let mut found : Json? = None
  for response_id in response_ids {
    guard self.responses.get(response_id) is Some(response) else { continue }
    guard response.calls_by_id.get(call_id) is Some(item) else { continue }
    if found is Some(_) {
      return None
    }
    found = Some(item)
  }
  found
}

///|
fn CodexChatLookup::call(self : CodexChatLookup, call_id : String) -> Json? {
  match self.previous {
    Some(previous) =>
      match previous.calls_by_id.get(call_id) {
        Some(item) => Some(item)
        None => self.fallback.calls_by_id.get(call_id)
      }
    None => self.fallback.calls_by_id.get(call_id)
  }
}

///|
fn CodexChatLookup::restore_group(
  self : CodexChatLookup,
  output_call_ids : Array[String],
  existing_call_ids : Array[String],
) -> Array[(String, Json)] {
  let group : Array[(String, Json)] = []
  let grouped_call_ids : Array[String] = []
  match self.previous {
    Some(previous) =>
      codex_chat_append_restore_group(
        previous, output_call_ids, existing_call_ids, grouped_call_ids, group,
      )
    None => ()
  }
  codex_chat_append_restore_group(
    self.fallback,
    output_call_ids,
    existing_call_ids,
    grouped_call_ids,
    group,
  )
  group
}

///|
fn codex_chat_append_restore_group(
  response : CachedCodexChatResponse,
  output_call_ids : Array[String],
  existing_call_ids : Array[String],
  grouped_call_ids : Array[String],
  group : Array[(String, Json)],
) -> Unit {
  for call_id in response.call_order {
    if !output_call_ids.contains(call_id) ||
      existing_call_ids.contains(call_id) ||
      grouped_call_ids.contains(call_id) {
      continue
    }
    match response.calls_by_id.get(call_id) {
      Some(item) => {
        grouped_call_ids.push(call_id)
        group.push((call_id, copy_json(item)))
      }
      None => ()
    }
  }
}

///|
fn codex_chat_cached_call_item(item : Json) -> (String, Json)? {
  guard item is Object(obj) else { return None }
  guard json_string_from_map(obj, "type") is Some(type_) &&
    codex_chat_is_call_item_type(type_) else {
    return None
  }
  guard codex_chat_response_item_call_id(item) is Some(call_id) else {
    return None
  }
  Some((call_id, copy_json(item)))
}

///|
fn codex_chat_response_item_call_id(item : Json) -> String? {
  guard item is Object(obj) else { return None }
  match json_string_from_map(obj, "call_id") {
    Some(value) if !value.trim().is_empty() => Some(value.trim().to_owned())
    _ =>
      match json_string_from_map(obj, "id") {
        Some(value) if !value.trim().is_empty() => Some(value.trim().to_owned())
        _ => None
      }
  }
}

///|
fn codex_chat_is_call_item_type(item_type : String) -> Bool {
  item_type == "function_call" ||
  item_type == "custom_tool_call" ||
  item_type == "tool_search_call"
}

///|
fn codex_chat_is_call_output_item_type(item_type : String) -> Bool {
  item_type == "function_call_output" ||
  item_type == "custom_tool_call_output" ||
  item_type == "tool_search_output"
}

///|
fn codex_chat_enrich_call_item_reasoning(item : Json, cached : Json) -> Bool {
  guard item is Object(item_obj) else { return false }
  guard cached is Object(cached_obj) else { return false }
  let mut changed = false
  for key in ["reasoning_content", "reasoning"] {
    match item_obj.get(key) {
      Some(value) if !codex_chat_is_empty_value(value) => continue
      _ => ()
    }
    match cached_obj.get(key) {
      Some(reasoning) if !codex_chat_is_empty_value(reasoning) => {
        item_obj[key] = copy_json(reasoning)
        changed = true
      }
      _ => ()
    }
  }
  changed
}

///|
fn codex_chat_is_empty_value(value : Json) -> Bool {
  match value {
    Null => true
    String(value) => value.trim().is_empty()
    Array(value) => value.is_empty()
    Object(value) => value.is_empty()
    _ => false
  }
}

///|
fn codex_chat_union_ids(
  first : Array[String],
  second : Array[String],
) -> Array[String] {
  let result : Array[String] = []
  for id in first {
    if !result.contains(id) {
      result.push(id)
    }
  }
  for id in second {
    if !result.contains(id) {
      result.push(id)
    }
  }
  result
}

///|
fn codex_chat_group_call_ids(group : Array[(String, Json)]) -> Array[String] {
  let ids : Array[String] = []
  for call in group {
    let call_id = call.0
    if !ids.contains(call_id) {
      ids.push(call_id)
    }
  }
  ids
}
