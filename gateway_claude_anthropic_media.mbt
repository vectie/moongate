///|
fn claude_stream_request_json_for_upstream(
  body : Json,
  upstream_model : String,
) -> Json {
  let result = claude_request_json_for_upstream(body, upstream_model)
  guard result is Object(obj) else { return result }
  obj["stream"] = Json::boolean(true)
  Json::object(obj)
}

///|
priv struct PreparedUpstreamRequest {
  body : Json
  copilot_headers : Map[String, String]
}

///|
fn prepare_upstream_request_body(
  body : Json,
  provider? : ProviderRouteTarget? = None,
  copilot_config_json? : Json? = None,
  anthropic_beta? : String? = None,
  session_id? : String? = None,
) -> Json {
  prepare_upstream_request(
    body,
    provider~,
    copilot_config_json~,
    anthropic_beta~,
    session_id~,
  ).body
}

///|
fn prepare_upstream_request(
  body : Json,
  provider? : ProviderRouteTarget? = None,
  copilot_config_json? : Json? = None,
  anthropic_beta? : String? = None,
  session_id? : String? = None,
) -> PreparedUpstreamRequest {
  let filtered = filter_private_params_for_upstream(body, None, [])
  let copilot_optimization = match copilot_config_json {
    Some(config) =>
      apply_moon_copilot_optimizer_for_provider(
        filtered,
        provider,
        config,
        anthropic_beta is Some(_),
        client_session_id=session_id,
      )
    None => { body: filtered, headers: {}, }
  }
  let optimized = apply_moon_optimizer_for_provider(
    copilot_optimization.body,
    provider,
  )
  {
    body: canonicalize_json_value(
      replace_images_for_text_only_model(optimized, provider~).body,
    ),
    copilot_headers: copilot_optimization.headers,
  }
}

///|
fn filter_private_params_for_upstream(
  body : Json,
  parent_key : String?,
  whitelist : Array[String],
) -> Json {
  match body {
    Object(obj) => {
      let schema_name_map = parent_key is Some(key) &&
        matches_schema_name_map(key)
      let result : Map[String, Json] = Map([])
      for key, value in obj {
        if key.has_prefix("_") && !schema_name_map && !whitelist.contains(key) {
          continue
        }
        result[key] = filter_private_params_for_upstream(
          value,
          Some(key),
          whitelist,
        )
      }
      Json::object(result)
    }
    Array(items) => {
      let result : Array[Json] = []
      for item in items {
        result.push(
          filter_private_params_for_upstream(item, parent_key, whitelist),
        )
      }
      Json::array(result)
    }
    _ => body
  }
}

///|
const UNSUPPORTED_IMAGE_MARKER = "[Unsupported Image]"

///|
priv struct MediaReplacementResult {
  body : Json
  count : Int
}

///|
fn replace_images_for_text_only_model(
  body : Json,
  provider? : ProviderRouteTarget? = None,
) -> MediaReplacementResult {
  guard body is Object(obj) else { return { body, count: 0, } }
  let model = json_string_from_map(obj, "model").unwrap_or("")
  match explicit_model_image_support(provider, model) {
    Some(true) => return { body: Json::object(obj), count: 0, }
    Some(false) => return replace_image_blocks_with_marker(Json::object(obj))
    None => ()
  }
  if !rectifier_media_heuristic_enabled(provider) {
    return { body: Json::object(obj), count: 0, }
  }
  if !known_text_only_model(model) {
    return { body: Json::object(obj), count: 0, }
  }
  replace_image_blocks_with_marker(Json::object(obj))
}

///|
fn explicit_model_image_support(
  provider : ProviderRouteTarget?,
  model : String,
) -> Bool? {
  guard provider is Some(provider) else { return None }
  guard provider.settings_config is Some(settings) else { return None }
  match settings {
    Object(obj) => {
      match obj.get("modelCatalog") {
        Some(Object(catalog)) =>
          match catalog.get("models") {
            Some(models) =>
              match explicit_model_image_support_in_value(models, model) {
                Some(value) => return Some(value)
                None => ()
              }
            None => ()
          }
        _ => ()
      }
      match obj.get("modelCatalog") {
        Some(catalog) =>
          match explicit_model_image_support_in_value(catalog, model) {
            Some(value) => return Some(value)
            None => ()
          }
        None => ()
      }
      match obj.get("models") {
        Some(models) => explicit_model_image_support_in_value(models, model)
        None => None
      }
    }
    _ => None
  }
}

///|
fn explicit_model_image_support_in_value(value : Json, model : String) -> Bool? {
  match value {
    Array(models) => {
      for entry in models {
        if model_entry_matches(entry, None, model) {
          match explicit_image_support(entry) {
            Some(value) => return Some(value)
            None => ()
          }
        }
      }
      None
    }
    Object(entries) => {
      for key, entry in entries {
        if model_entry_matches(entry, Some(key), model) {
          match explicit_image_support(entry) {
            Some(value) => return Some(value)
            None => ()
          }
        }
      }
      None
    }
    _ => None
  }
}

///|
fn explicit_image_support(entry : Json) -> Bool? {
  guard entry is Object(obj) else { return None }
  match obj.get("supportsImage") {
    Some(true) => return Some(true)
    Some(false) => return Some(false)
    None => ()
    _ => ()
  }
  match obj.get("input") {
    Some(input) =>
      match input_modalities_support_image(input) {
        Some(value) => return Some(value)
        None => ()
      }
    None => ()
  }
  match obj.get("modalities") {
    Some(Object(modalities)) =>
      match modalities.get("input") {
        Some(input) =>
          match input_modalities_support_image(input) {
            Some(value) => return Some(value)
            None => ()
          }
        None => ()
      }
    _ => ()
  }
  match obj.get("input_modalities") {
    Some(input) =>
      match input_modalities_support_image(input) {
        Some(value) => return Some(value)
        None => ()
      }
    None => ()
  }
  match obj.get("inputModalities") {
    Some(input) => input_modalities_support_image(input)
    None => None
  }
}

///|
fn json_string_from_map_any(
  obj : Map[String, Json],
  keys : Array[String],
) -> String? {
  for key in keys {
    match json_string_from_map(obj, key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn input_modalities_support_image(value : Json) -> Bool? {
  guard value is Array(modalities) else { return None }
  Some(
    modalities.any(item => {
      match item {
        String(text) => text.trim().to_lower() == "image"
        _ => false
      }
    }),
  )
}

///|
fn model_entry_matches(entry : Json, key : String?, model : String) -> Bool {
  match key {
    Some(key) if model_ids_match(key, model) => return true
    _ => ()
  }
  guard entry is Object(obj) else { return false }
  ["model", "id", "name"].any(field => {
    match json_string_from_map(obj, field) {
      Some(candidate) => model_ids_match(candidate, model)
      None => false
    }
  })
}

///|
fn model_ids_match(candidate : String, model : String) -> Bool {
  let candidate = normalize_media_model_id(candidate)
  let model = normalize_media_model_id(model)
  if candidate.is_empty() || model.is_empty() {
    return false
  }
  if candidate == model {
    return true
  }
  let candidate_tail = model_id_tail(candidate)
  let model_tail = model_id_tail(model)
  candidate_tail == model_tail ||
  candidate == model_tail ||
  candidate_tail == model
}

///|
fn normalize_media_model_id(value : String) -> String {
  let lower = value.trim().to_lower()
  let without_model_prefix = if lower.has_prefix("models/") {
    lower["models/".length():].to_owned()
  } else {
    lower.to_owned()
  }
  strip_one_m_suffix_for_upstream(without_model_prefix).trim().to_owned()
}

///|
fn model_id_tail(model : String) -> String {
  let parts = model.split("/").collect()
  match parts.last() {
    Some(part) => part.to_owned()
    None => model
  }
}

///|
fn contains_image_blocks(body : Json) -> Bool {
  match body {
    Object(obj) =>
      messages_have_image_blocks(obj) ||
      responses_input_has_image_blocks(obj.get("input"))
    _ => false
  }
}

///|
fn messages_have_image_blocks(obj : Map[String, Json]) -> Bool {
  guard obj.get("messages") is Some(Array(messages)) else { return false }
  messages.any(message => {
    match message {
      Object(message_obj) =>
        match message_obj.get("content") {
          Some(content) => content_has_image_blocks(content)
          None => false
        }
      _ => false
    }
  })
}

///|
fn content_has_image_blocks(content : Json) -> Bool {
  guard content is Array(blocks) else { return false }
  blocks.any(block => {
    if is_image_block(block) {
      return true
    }
    match block {
      Object(block_obj) =>
        match block_obj.get("content") {
          Some(nested) => content_has_image_blocks(nested)
          None => false
        }
      _ => false
    }
  })
}

///|
fn responses_input_has_image_blocks(input : Json?) -> Bool {
  match input {
    Some(Array(items)) =>
      items.any(item => responses_input_item_has_image_blocks(item))
    Some(item) => responses_input_item_has_image_blocks(item)
    _ => false
  }
}

///|
fn responses_input_item_has_image_blocks(item : Json) -> Bool {
  guard item is Object(item_obj) else { return false }
  if json_string_from_map(item_obj, "type") == Some("input_image") {
    return true
  }
  match item_obj.get("content") {
    Some(content) => content_has_image_blocks(content)
    None => false
  }
}

///|
fn is_unsupported_image_error_status(status_code : Int, body : String) -> Bool {
  match status_code {
    400 | 415 | 422 | 501 => ()
    _ => return false
  }
  let message = extract_upstream_error_text(body).to_lower()
  let mentions_image = message.contains("image") ||
    message.contains("vision") ||
    message.contains("multimodal") ||
    message.contains("multi-modal") ||
    message.contains("modality") ||
    message.contains("modalities") ||
    message.contains("media") ||
    message.contains("attachment")
  if !mentions_image {
    return false
  }
  [
    "unsupported", "not supported", "does not support", "doesn't support", "do not support",
    "don't support", "only supports text", "text only", "text-only", "invalid content type",
    "invalid message content", "unknown variant", "unknown content type", "unrecognized content type",
    "cannot process", "cannot handle", "can't process", "can't handle", "unable to process",
  ].any(hint => message.contains(hint))
}

///|
fn extract_upstream_error_text(body : String) -> String {
  let parsed = @json.parse(body) catch { _ => return body }
  match parsed {
    Object(obj) => {
      match obj.get("error") {
        Some(Object(error_obj)) =>
          match json_string_from_map(error_obj, "message") {
            Some(message) => return message
            None => ()
          }
        Some(String(message)) => return message
        _ => ()
      }
      match json_string_from_map(obj, "message") {
        Some(message) => return message
        None => ()
      }
      match json_string_from_map(obj, "detail") {
        Some(detail) => return detail
        None => ()
      }
      parsed.stringify()
    }
    _ => parsed.stringify()
  }
}

///|
fn replace_image_blocks_with_marker(body : Json) -> MediaReplacementResult {
  guard body is Object(obj) else { return { body, count: 0, } }
  let mut count = 0
  match obj.get("messages") {
    Some(Array(messages)) => {
      let replaced_messages : Array[Json] = []
      for message in messages {
        match message {
          Object(message_obj) =>
            match message_obj.get("content") {
              Some(content) => {
                let result = replace_images_in_content(content, "text")
                count += result.count
                message_obj["content"] = result.body
                replaced_messages.push(Json::object(message_obj))
              }
              None => replaced_messages.push(Json::object(message_obj))
            }
          _ => replaced_messages.push(message)
        }
      }
      obj["messages"] = Json::array(replaced_messages)
    }
    _ => ()
  }
  match obj.get("input") {
    Some(input) => {
      let result = replace_images_in_responses_input(input)
      count += result.count
      obj["input"] = result.body
    }
    None => ()
  }
  { body: Json::object(obj), count, }
}

///|
fn replace_images_in_content(
  content : Json,
  text_type : String,
) -> MediaReplacementResult {
  guard content is Array(blocks) else { return { body: content, count: 0, } }
  let replaced_blocks : Array[Json] = []
  let mut count = 0
  for block in blocks {
    if is_image_block(block) {
      replaced_blocks.push(image_marker_block(block, text_type))
      count += 1
      continue
    }
    match block {
      Object(block_obj) =>
        match block_obj.get("content") {
          Some(nested) => {
            let result = replace_images_in_content(nested, text_type)
            count += result.count
            block_obj["content"] = result.body
            replaced_blocks.push(Json::object(block_obj))
          }
          None => replaced_blocks.push(Json::object(block_obj))
        }
      _ => replaced_blocks.push(block)
    }
  }
  { body: Json::array(replaced_blocks), count, }
}

///|
fn replace_images_in_responses_input(input : Json) -> MediaReplacementResult {
  match input {
    Array(items) => {
      let replaced_items : Array[Json] = []
      let mut count = 0
      for item in items {
        let result = replace_images_in_responses_input_item(item)
        count += result.count
        replaced_items.push(result.body)
      }
      { body: Json::array(replaced_items), count, }
    }
    Object(_) => replace_images_in_responses_input_item(input)
    _ => { body: input, count: 0, }
  }
}

///|
fn replace_images_in_responses_input_item(
  item : Json,
) -> MediaReplacementResult {
  guard item is Object(item_obj) else { return { body: item, count: 0, } }
  let mut count = 0
  if json_string_from_map(item_obj, "type") == Some("input_image") {
    let marker = image_marker_block(Json::object(item_obj), "input_text")
    guard marker is Object(marker_obj) else {
      return { body: marker, count: 1, }
    }
    count += 1
    match marker_obj.get("content") {
      Some(content) => {
        let result = replace_images_in_content(content, "input_text")
        count += result.count
        marker_obj["content"] = result.body
      }
      None => ()
    }
    return { body: Json::object(marker_obj), count, }
  }
  match item_obj.get("content") {
    Some(content) => {
      let result = replace_images_in_content(content, "input_text")
      count += result.count
      item_obj["content"] = result.body
    }
    None => ()
  }
  { body: Json::object(item_obj), count, }
}

///|
fn is_image_block(block : Json) -> Bool {
  guard block is Object(obj) else { return false }
  match json_string_from_map(obj, "type") {
    Some("image") | Some("image_url") | Some("input_image") => true
    _ => false
  }
}

///|
fn image_marker_block(block : Json, text_type : String) -> Json {
  let cache_control = match block {
    Object(obj) => obj.get("cache_control")
    _ => None
  }
  let marker : Map[String, Json] = {
    "type": Json::string(text_type),
    "text": Json::string(UNSUPPORTED_IMAGE_MARKER),
  }
  match cache_control {
    Some(cache_control) => marker["cache_control"] = cache_control
    None => ()
  }
  Json::object(marker)
}

///|
fn known_text_only_model(model : String) -> Bool {
  let lower = model.trim().to_lower()
  let without_model_prefix = if lower.has_prefix("models/") {
    lower["models/".length():].to_owned()
  } else {
    lower.to_owned()
  }
  let normalized = strip_one_m_suffix_for_upstream(without_model_prefix)
  let parts = normalized.split("/").collect()
  let tail = match parts.last() {
    Some(part) => part.to_owned()
    None => normalized
  }
  [
    "ark-code-latest", "deepseek-chat", "deepseek-reasoner", "deepseek-v4-flash",
    "deepseek-v4-pro", "glm-5.1", "kat-coder", "kat-coder-pro", "kat-coder-pro v1",
    "kat-coder-pro v2", "kat-coder-pro-v1", "kat-coder-pro-v2", "ling-2.5-1t", "longcat-flash-chat",
    "mimo-v2.5-pro", "us.deepseek.r1-v1",
  ].contains(tail) ||
  ["minimax-m2.7", "qwen3-coder", "step-3.5-flash"].any(prefix => {
    tail.has_prefix(prefix)
  })
}

///|
fn matches_schema_name_map(key : String) -> Bool {
  key == "properties" ||
  key == "patternProperties" ||
  key == "definitions" ||
  key == "$defs"
}
