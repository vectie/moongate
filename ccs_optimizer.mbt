///|
priv struct OptimizerConfig {
  enabled : Bool
  thinking_optimizer : Bool
  cache_injection : Bool
  cache_ttl : String
}

///|
priv struct CopilotOptimizerConfig {
  enabled : Bool
  request_classification : Bool
  tool_result_merging : Bool
  compact_detection : Bool
  deterministic_request_id : Bool
  subagent_detection : Bool
  warmup_downgrade : Bool
  warmup_model : String
  strip_thinking : Bool
}

///|
priv struct CopilotClassification {
  initiator : String
  is_warmup : Bool
  is_compact : Bool
  is_subagent : Bool
}

///|
priv struct CopilotOptimizationResult {
  body : Json
  headers : Map[String, String]
}

///|
fn moonstat_optimizer_config_from_env() -> OptimizerConfig {
  {
    enabled: env_bool_default(
      [
        "MOONSTAT_OPTIMIZER_ENABLED", "MOONSTAT_CCS_OPTIMIZER_ENABLED", "CCS_OPTIMIZER_ENABLED",
      ],
      false,
    ),
    thinking_optimizer: env_bool_default(
      [
        "MOONSTAT_THINKING_OPTIMIZER", "MOONSTAT_CCS_THINKING_OPTIMIZER", "CCS_THINKING_OPTIMIZER",
      ],
      true,
    ),
    cache_injection: env_bool_default(
      [
        "MOONSTAT_CACHE_INJECTION", "MOONSTAT_CCS_CACHE_INJECTION", "CCS_CACHE_INJECTION",
      ],
      true,
    ),
    cache_ttl: env_cache_ttl_default(
      ["MOONSTAT_CACHE_TTL", "MOONSTAT_CCS_CACHE_TTL", "CCS_CACHE_TTL"],
      "1h",
    ),
  }
}

///|
fn env_bool_default(keys : Array[String], default : Bool) -> Bool {
  for key in keys {
    match getenv_or_none(key) {
      Some(value) => {
        let normalized = value.trim().to_lower()
        match normalized {
          "1" | "true" | "yes" | "on" => return true
          "0" | "false" | "no" | "off" => return false
          _ => continue
        }
      }
      None => continue
    }
  }
  default
}

///|
fn env_cache_ttl_default(keys : Array[String], default : String) -> String {
  for key in keys {
    match getenv_or_none(key) {
      Some(value) => {
        let trimmed = value.trim().to_owned()
        if trimmed == "5m" || trimmed == "1h" {
          return trimmed
        }
      }
      None => continue
    }
  }
  default
}

///|
fn ccs_copilot_optimizer_runtime_config(
  config : Json,
) -> CopilotOptimizerConfig {
  let defaults = ccs_default_copilot_optimizer_config_json()
  let current = match config {
    Object(_) => config
    _ => defaults
  }
  guard current is Object(obj) else {
    return {
      enabled: true,
      request_classification: true,
      tool_result_merging: true,
      compact_detection: true,
      deterministic_request_id: true,
      subagent_detection: true,
      warmup_downgrade: true,
      warmup_model: "gpt-5-mini",
      strip_thinking: true,
    }
  }
  {
    enabled: json_bool_from_map_any(obj, ["enabled"]).unwrap_or(true),
    request_classification: json_bool_from_map_any(obj, [
      "requestClassification", "request_classification",
    ]).unwrap_or(true),
    tool_result_merging: json_bool_from_map_any(obj, [
      "toolResultMerging", "tool_result_merging",
    ]).unwrap_or(true),
    compact_detection: json_bool_from_map_any(obj, [
      "compactDetection", "compact_detection",
    ]).unwrap_or(true),
    deterministic_request_id: json_bool_from_map_any(obj, [
      "deterministicRequestId", "deterministic_request_id",
    ]).unwrap_or(true),
    subagent_detection: json_bool_from_map_any(obj, [
      "subagentDetection", "subagent_detection",
    ]).unwrap_or(true),
    warmup_downgrade: json_bool_from_map_any(obj, [
      "warmupDowngrade", "warmup_downgrade",
    ]).unwrap_or(true),
    warmup_model: json_string_from_map_any(obj, ["warmupModel", "warmup_model"]).unwrap_or(
      "gpt-5-mini",
    ),
    strip_thinking: json_bool_from_map_any(obj, [
      "stripThinking", "strip_thinking",
    ]).unwrap_or(true),
  }
}

///|
fn apply_ccs_optimizer_for_provider(
  body : Json,
  provider : ProviderRouteTarget?,
) -> Json {
  let config = moonstat_optimizer_config_from_env()
  if !config.enabled || !provider_is_bedrock(provider) {
    return body
  }
  let mut optimized = body
  if config.thinking_optimizer {
    optimized = optimize_ccs_thinking(optimized)
  }
  if config.cache_injection {
    optimized = inject_ccs_cache_breakpoints(optimized, config.cache_ttl)
  }
  optimized
}

///|
fn apply_ccs_copilot_optimizer_for_provider(
  body : Json,
  provider : ProviderRouteTarget?,
  config_json : Json,
  has_anthropic_beta : Bool,
  client_session_id? : String? = None,
) -> CopilotOptimizationResult {
  let config = ccs_copilot_optimizer_runtime_config(config_json)
  if !config.enabled || !ccs_copilot_optimizer_provider_enabled(provider) {
    return { body, headers: {} }
  }
  let classification = classify_ccs_copilot_request(
    body,
    has_anthropic_beta,
    config.compact_detection,
    config.subagent_detection,
  )
  let mut optimized = sanitize_ccs_copilot_orphan_tool_results(body)
  if config.tool_result_merging {
    optimized = merge_ccs_copilot_tool_results(optimized)
  }
  if config.strip_thinking {
    optimized = strip_ccs_copilot_thinking_blocks(optimized)
  }
  if config.warmup_downgrade && classification.is_warmup {
    optimized = ccs_copilot_body_with_model(optimized, config.warmup_model)
  }
  {
    body: optimized,
    headers: ccs_copilot_optimizer_headers(
      optimized,
      classification,
      config,
      ccs_copilot_session_id(body, client_session_id),
    ),
  }
}

///|
fn ccs_copilot_optimizer_headers(
  body : Json,
  classification : CopilotClassification,
  config : CopilotOptimizerConfig,
  session_id : String,
) -> Map[String, String] {
  let headers : Map[String, String] = {}
  if config.request_classification {
    headers["x-initiator"] = classification.initiator
  }
  if classification.is_subagent {
    headers["x-interaction-type"] = "conversation-subagent"
  } else if classification.is_compact {
    headers["x-interaction-type"] = "conversation-agent"
  }
  if config.deterministic_request_id {
    let request_id = ccs_copilot_deterministic_request_id(body, session_id)
    headers["x-request-id"] = request_id
    headers["x-agent-task-id"] = request_id
  }
  match ccs_copilot_deterministic_interaction_id(session_id) {
    Some(interaction_id) => headers["x-interaction-id"] = interaction_id
    None => ()
  }
  headers
}

///|
fn ccs_copilot_optimizer_provider_enabled(
  provider : ProviderRouteTarget?,
) -> Bool {
  guard provider is Some(provider) else { return false }
  provider.provider_type == Some("github_copilot") ||
  provider.is_github_copilot_upstream()
}

///|
fn classify_ccs_copilot_request(
  body : Json,
  has_anthropic_beta : Bool,
  compact_detection : Bool,
  subagent_detection : Bool,
) -> CopilotClassification {
  let is_compact = compact_detection && ccs_copilot_is_compact_request(body)
  let is_subagent = subagent_detection && ccs_copilot_detect_subagent(body)
  let messages = match body {
    Object(obj) =>
      match obj.get("messages") {
        Some(Array(messages)) if !messages.is_empty() => messages
        _ =>
          return {
            initiator: "user",
            is_warmup: ccs_copilot_is_warmup_request(
              body, has_anthropic_beta, false,
            ),
            is_compact: false,
            is_subagent,
          }
      }
    _ =>
      return {
        initiator: "user",
        is_warmup: ccs_copilot_is_warmup_request(
          body, has_anthropic_beta, false,
        ),
        is_compact: false,
        is_subagent,
      }
  }
  let last_message = messages[messages.length() - 1]
  guard last_message is Object(last_obj) else {
    return { initiator: "user", is_warmup: false, is_compact, is_subagent }
  }
  if json_string_from_map(last_obj, "role") != Some("user") {
    return {
      initiator: if is_subagent {
        "agent"
      } else {
        "user"
      },
      is_warmup: false,
      is_compact,
      is_subagent,
    }
  }
  let user_initiated = match last_obj.get("content") {
    Some(Array(blocks)) =>
      !blocks.any(block => {
        block is Object(block_obj) &&
        json_string_from_map(block_obj, "type") == Some("tool_result")
      })
    Some(String(_)) => true
    _ => false
  }
  let initiator = if is_subagent || !user_initiated || is_compact {
    "agent"
  } else {
    "user"
  }
  {
    initiator,
    is_warmup: initiator == "user" &&
    ccs_copilot_is_warmup_request(body, has_anthropic_beta, is_compact),
    is_compact,
    is_subagent,
  }
}

///|
fn ccs_copilot_is_warmup_request(
  body : Json,
  has_anthropic_beta : Bool,
  is_compact : Bool,
) -> Bool {
  if !has_anthropic_beta || is_compact {
    return false
  }
  guard body is Object(obj) else { return true }
  match obj.get("tools") {
    Some(Array(tools)) => tools.is_empty()
    _ => true
  }
}

///|
fn ccs_copilot_is_compact_request(body : Json) -> Bool {
  if ccs_copilot_extract_system_text(body).has_prefix(
      "You are a helpful AI assistant tasked with summarizing conversations",
    ) {
    return true
  }
  guard body is Object(obj) else { return false }
  guard obj.get("messages") is Some(Array(messages)) else { return false }
  guard !messages.is_empty() else { return false }
  guard messages[messages.length() - 1] is Object(last_obj) else {
    return false
  }
  if json_string_from_map(last_obj, "role") != Some("user") {
    return false
  }
  let text = ccs_copilot_extract_text_from_message(Json::object(last_obj))
  text.contains("CRITICAL: Respond with TEXT ONLY. Do NOT call any tools.") ||
  (text.contains("Pending Tasks:") && text.contains("Current Work:"))
}

///|
fn ccs_copilot_detect_subagent(body : Json) -> Bool {
  if ccs_copilot_extract_system_text(body).contains("__SUBAGENT_MARKER__") {
    return true
  }
  if body is Object(obj) {
    match obj.get("messages") {
      Some(Array(messages)) =>
        for message in messages {
          if message is Object(message_obj) &&
            json_string_from_map(message_obj, "role") == Some("user") &&
            ccs_copilot_extract_text_from_message(message).contains(
              "__SUBAGENT_MARKER__",
            ) {
            return true
          }
        }
      _ => ()
    }
    match obj.get("metadata") {
      Some(Object(metadata)) =>
        match json_string_from_map(metadata, "user_id") {
          Some(user_id) if user_id.contains("_agent_") => return true
          _ => ()
        }
      _ => ()
    }
  }
  false
}

///|
fn sanitize_ccs_copilot_orphan_tool_results(body : Json) -> Json {
  let copied = copy_json(body)
  guard copied is Object(obj) else { return copied }
  guard obj.get("messages") is Some(Array(messages)) else {
    return Json::object(obj)
  }
  if messages.length() < 2 {
    return Json::object(obj)
  }
  for index in 1..<messages.length() {
    guard messages[index] is Object(message) else { continue }
    if json_string_from_map(message, "role") != Some("user") {
      continue
    }
    let previous_ids = ccs_copilot_previous_tool_use_ids(messages[index - 1])
    guard message.get("content") is Some(Array(content)) else { continue }
    let sanitized : Array[Json] = []
    for block in content {
      if block is Object(block_obj) &&
        json_string_from_map(block_obj, "type") == Some("tool_result") {
        let tool_use_id = json_string_from_map(block_obj, "tool_use_id").unwrap_or(
          "",
        )
        if tool_use_id.is_empty() || !previous_ids.contains(tool_use_id) {
          sanitized.push(ccs_copilot_orphan_tool_result_text(block_obj))
        } else {
          sanitized.push(block)
        }
      } else {
        sanitized.push(block)
      }
    }
    message["content"] = Json::array(sanitized)
    messages[index] = Json::object(message)
  }
  obj["messages"] = Json::array(messages)
  Json::object(obj)
}

///|
fn ccs_copilot_previous_tool_use_ids(message : Json) -> Array[String] {
  guard message is Object(obj) else { return [] }
  if json_string_from_map(obj, "role") != Some("assistant") {
    return []
  }
  guard obj.get("content") is Some(Array(content)) else { return [] }
  let ids : Array[String] = []
  for block in content {
    guard block is Object(block_obj) else { continue }
    if json_string_from_map(block_obj, "type") == Some("tool_use") {
      match json_string_from_map(block_obj, "id") {
        Some(id) => ids.push(id)
        None => ()
      }
    }
  }
  ids
}

///|
fn ccs_copilot_orphan_tool_result_text(block : Map[String, Json]) -> Json {
  let tool_use_id = json_string_from_map(block, "tool_use_id").unwrap_or("")
  let content_text = ccs_copilot_tool_result_content_text(block.get("content"))
  Json::object({
    "type": Json::string("text"),
    "text": Json::string("[Tool result for \{tool_use_id}]: \{content_text}"),
  })
}

///|
fn ccs_copilot_tool_result_content_text(content : Json?) -> String {
  match content {
    Some(String(text)) => text
    Some(Array(blocks)) => {
      let texts : Array[String] = []
      for block in blocks {
        guard block is Object(block_obj) else { continue }
        match json_string_from_map(block_obj, "text") {
          Some(text) => texts.push(text)
          None => ()
        }
      }
      texts.join("\n")
    }
    _ => ""
  }
}

///|
fn merge_ccs_copilot_tool_results(body : Json) -> Json {
  let copied = copy_json(body)
  guard copied is Object(obj) else { return copied }
  guard obj.get("messages") is Some(Array(messages)) else {
    return Json::object(obj)
  }
  for index in 0..<messages.length() {
    guard messages[index] is Object(message) else { continue }
    if json_string_from_map(message, "role") != Some("user") {
      continue
    }
    guard message.get("content") is Some(Array(content)) else { continue }
    let merged = merge_ccs_copilot_intra_message_blocks(content)
    if merged is Some(blocks) {
      message["content"] = Json::array(blocks)
      messages[index] = Json::object(message)
    }
  }
  obj["messages"] = Json::array(
    merge_ccs_copilot_consecutive_tool_messages(messages),
  )
  Json::object(obj)
}

///|
fn merge_ccs_copilot_intra_message_blocks(
  content : Array[Json],
) -> Array[Json]? {
  let tool_results : Array[Json] = []
  let text_blocks : Array[Json] = []
  for block in content {
    guard block is Object(block_obj) else { return None }
    match json_string_from_map(block_obj, "type") {
      Some("tool_result") => tool_results.push(block)
      Some("text") => text_blocks.push(block)
      _ => return None
    }
  }
  if tool_results.is_empty() || text_blocks.is_empty() {
    return None
  }
  Some(ccs_copilot_merge_texts_into_tool_results(tool_results, text_blocks))
}

///|
fn ccs_copilot_merge_texts_into_tool_results(
  tool_results : Array[Json],
  text_blocks : Array[Json],
) -> Array[Json] {
  let result : Array[Json] = []
  let mut text_index = 0
  for tool_result in tool_results {
    guard tool_result is Object(tool_obj) else {
      result.push(tool_result)
      continue
    }
    if text_index < text_blocks.length() {
      let extra = ccs_copilot_text_block_text(text_blocks[text_index])
      if !extra.is_empty() {
        let original = ccs_copilot_tool_result_content_text(
          tool_obj.get("content"),
        )
        tool_obj["content"] = Json::string(
          if original.is_empty() {
            extra
          } else {
            "\{original}\n\{extra}"
          },
        )
      }
      text_index += 1
    }
    result.push(Json::object(tool_obj))
  }
  while text_index < text_blocks.length() && !result.is_empty() {
    let extra = ccs_copilot_text_block_text(text_blocks[text_index])
    if !extra.is_empty() && result[result.length() - 1] is Object(last) {
      let original = ccs_copilot_tool_result_content_text(last.get("content"))
      last["content"] = Json::string(
        if original.is_empty() {
          extra
        } else {
          "\{original}\n\{extra}"
        },
      )
      result[result.length() - 1] = Json::object(last)
    }
    text_index += 1
  }
  result
}

///|
fn ccs_copilot_text_block_text(block : Json) -> String {
  match block {
    Object(obj) => json_string_from_map(obj, "text").unwrap_or("")
    _ => ""
  }
}

///|
fn merge_ccs_copilot_consecutive_tool_messages(
  messages : Array[Json],
) -> Array[Json] {
  if messages.length() <= 1 {
    return messages
  }
  let merged : Array[Json] = []
  let mut index = 0
  while index < messages.length() {
    if ccs_copilot_is_tool_result_only_message(messages[index]) {
      let combined : Array[Json] = []
      while index < messages.length() &&
            ccs_copilot_is_tool_result_only_message(messages[index]) {
        if messages[index] is Object(message) &&
          message.get("content") is Some(Array(content)) {
          for block in content {
            combined.push(block)
          }
        }
        index += 1
      }
      if !combined.is_empty() {
        merged.push(
          Json::object({
            "role": Json::string("user"),
            "content": Json::array(combined),
          }),
        )
      }
    } else {
      merged.push(messages[index])
      index += 1
    }
  }
  merged
}

///|
fn ccs_copilot_is_tool_result_only_message(message : Json) -> Bool {
  guard message is Object(obj) else { return false }
  if json_string_from_map(obj, "role") != Some("user") {
    return false
  }
  guard obj.get("content") is Some(Array(content)) else { return false }
  !content.is_empty() &&
  content.all(block => {
    block is Object(block_obj) &&
    json_string_from_map(block_obj, "type") == Some("tool_result")
  })
}

///|
fn strip_ccs_copilot_thinking_blocks(body : Json) -> Json {
  let copied = copy_json(body)
  guard copied is Object(obj) else { return copied }
  guard obj.get("messages") is Some(Array(messages)) else {
    return Json::object(obj)
  }
  for index in 0..<messages.length() {
    guard messages[index] is Object(message) else { continue }
    if json_string_from_map(message, "role") != Some("assistant") {
      continue
    }
    guard message.get("content") is Some(Array(content)) else { continue }
    let kept : Array[Json] = []
    for block in content {
      let block_type = match block {
        Object(block_obj) => json_string_from_map(block_obj, "type")
        _ => None
      }
      if block_type != Some("thinking") &&
        block_type != Some("redacted_thinking") {
        kept.push(block)
      }
    }
    message["content"] = Json::array(kept)
    messages[index] = Json::object(message)
  }
  obj["messages"] = Json::array(messages)
  Json::object(obj)
}

///|
fn ccs_copilot_body_with_model(body : Json, model : String) -> Json {
  let copied = copy_json(body)
  guard copied is Object(obj) else { return copied }
  obj["model"] = Json::string(model)
  Json::object(obj)
}

///|
fn ccs_copilot_session_id(body : Json, client_session_id : String?) -> String {
  guard body is Object(obj) else { return client_session_id.unwrap_or("") }
  guard obj.get("metadata") is Some(Object(metadata)) else {
    return client_session_id.unwrap_or("")
  }
  let mut raw_user_id : String? = None
  match json_string_from_map(metadata, "user_id") {
    Some(user_id) => {
      raw_user_id = Some(user_id)
      match ccs_copilot_parse_session_from_user_id(user_id) {
        Some(session_id) => return session_id
        None => ()
      }
    }
    None => ()
  }
  match json_string_from_map(metadata, "session_id") {
    Some(session_id) if !session_id.is_empty() => session_id
    _ =>
      match raw_user_id {
        Some(user_id) if !user_id.is_empty() => user_id
        _ => client_session_id.unwrap_or("")
      }
  }
}

///|
fn ccs_copilot_parse_session_from_user_id(user_id : String) -> String? {
  match user_id.find("_session_") {
    Some(index) => {
      let start = index + "_session_".length()
      let session_id = user_id[start:]
      if index > 0 && !session_id.is_empty() {
        Some(session_id.to_owned())
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn ccs_copilot_deterministic_request_id(
  body : Json,
  session_id : String,
) -> String {
  match ccs_copilot_last_user_content_for_id(body) {
    Some(content) => ccs_copilot_uuid_from_sha256("\{session_id}\{content}")
    None => ccs_copilot_random_uuid()
  }
}

///|
fn ccs_copilot_deterministic_interaction_id(session_id : String) -> String? {
  if session_id.is_empty() {
    return None
  }
  Some(ccs_copilot_uuid_from_sha256("interaction:\{session_id}"))
}

///|
fn ccs_copilot_uuid_from_sha256(input : String) -> String {
  let digest = @crypto.sha256(@encoding/utf8.encode(input))
  let bytes : FixedArray[Byte] = FixedArray::make(16, 0)
  for i in 0..<16 {
    bytes[i] = digest[i]
  }
  bytes[6] = ((bytes[6].to_int() & 0x0f) | 0x40).to_byte()
  bytes[8] = ((bytes[8].to_int() & 0x3f) | 0x80).to_byte()
  @uuid.of_bytes(bytes.unsafe_reinterpret_as_bytes()).to_string()
}

///|
fn ccs_copilot_random_uuid() -> String {
  let gen = @uuid.generator(@random.Rand::new())
  gen.v4().to_string()
}

///|
fn ccs_copilot_last_user_content_for_id(body : Json) -> String? {
  guard body is Object(obj) else { return None }
  guard obj.get("messages") is Some(Array(messages)) else { return None }
  let mut index = messages.length() - 1
  while index >= 0 {
    guard messages[index] is Object(message) else {
      index -= 1
      continue
    }
    if json_string_from_map(message, "role") != Some("user") {
      index -= 1
      continue
    }
    match message.get("content") {
      Some(String(text)) => return Some(text)
      Some(Array(blocks)) => {
        let filtered : Array[Json] = []
        for block in blocks {
          guard block is Object(block_obj) else { continue }
          if json_string_from_map(block_obj, "type") == Some("tool_result") {
            continue
          }
          let copy = copy_json(block)
          if copy is Object(copy_obj) {
            copy_obj.remove("cache_control")
            filtered.push(Json::object(copy_obj))
          }
        }
        if !filtered.is_empty() {
          return Some(Json::array(filtered).stringify())
        }
      }
      _ => ()
    }
    index -= 1
  }
  None
}

///|
fn ccs_copilot_extract_system_text(body : Json) -> String {
  guard body is Object(obj) else { return "" }
  match obj.get("system") {
    Some(String(text)) => text
    Some(Array(blocks)) => {
      let texts : Array[String] = []
      for block in blocks {
        guard block is Object(block_obj) else { continue }
        match json_string_from_map(block_obj, "text") {
          Some(text) => texts.push(text)
          None => ()
        }
      }
      texts.join(" ")
    }
    _ => ""
  }
}

///|
fn ccs_copilot_extract_text_from_message(message : Json) -> String {
  guard message is Object(obj) else { return "" }
  match obj.get("content") {
    Some(String(text)) => text
    Some(Array(blocks)) => {
      let texts : Array[String] = []
      for block in blocks {
        guard block is Object(block_obj) else { continue }
        match json_string_from_map(block_obj, "text") {
          Some(text) => texts.push(text)
          None => ()
        }
      }
      texts.join("\n")
    }
    _ => ""
  }
}

///|
fn provider_is_bedrock(provider : ProviderRouteTarget?) -> Bool {
  guard provider is Some(provider) else { return false }
  guard provider.settings_config is Some(Object(settings)) else { return false }
  guard settings.get("env") is Some(Object(env)) else { return false }
  json_string_from_map(env, "CLAUDE_CODE_USE_BEDROCK") == Some("1")
}

///|
fn optimize_ccs_thinking(body : Json) -> Json {
  let copied = copy_json(body)
  guard copied is Object(obj) else { return copied }
  let model = match json_string_from_map(obj, "model") {
    Some(model) => model.to_lower()
    None => return Json::object(obj)
  }
  if model.contains("haiku") {
    return Json::object(obj)
  }
  if ccs_model_uses_adaptive_thinking(model) {
    obj["thinking"] = Json::object({ "type": Json::string("adaptive") })
    obj["output_config"] = Json::object({ "effort": Json::string("max") })
    append_ccs_anthropic_beta(obj, "context-1m-2025-08-07")
    return Json::object(obj)
  }
  let max_tokens = json_int_from_map(obj, "max_tokens").unwrap_or(16384)
  let budget_target = max_int(max_tokens - 1, 0)
  let thinking_type = match obj.get("thinking") {
    Some(Object(thinking)) => json_string_from_map(thinking, "type")
    _ => None
  }
  match thinking_type {
    None | Some("disabled") => {
      obj["thinking"] = Json::object({
        "type": Json::string("enabled"),
        "budget_tokens": Json::number(budget_target.to_double()),
      })
      append_ccs_anthropic_beta(obj, "interleaved-thinking-2025-05-14")
    }
    Some("enabled") => {
      let current_budget = match obj.get("thinking") {
        Some(Object(thinking)) =>
          json_int_from_map(thinking, "budget_tokens").unwrap_or(0)
        _ => 0
      }
      if current_budget < budget_target &&
        obj.get("thinking") is Some(Object(thinking)) {
        thinking["budget_tokens"] = Json::number(budget_target.to_double())
        obj["thinking"] = Json::object(thinking)
      }
      append_ccs_anthropic_beta(obj, "interleaved-thinking-2025-05-14")
    }
    Some(_) => append_ccs_anthropic_beta(obj, "interleaved-thinking-2025-05-14")
  }
  Json::object(obj)
}

///|
fn ccs_model_uses_adaptive_thinking(model : String) -> Bool {
  let normalized = model.replace_all(old=".", new="-")
  ["opus-4-8", "opus-4-7", "opus-4-6", "sonnet-4-6"].any(needle => {
    normalized.contains(needle)
  })
}

///|
fn append_ccs_anthropic_beta(obj : Map[String, Json], beta : String) -> Unit {
  match obj.get("anthropic_beta") {
    Some(Array(values)) => {
      for value in values {
        if value == Json::string(beta) {
          return
        }
      }
      values.push(Json::string(beta))
      obj["anthropic_beta"] = Json::array(values)
    }
    Some(Null) | None =>
      obj["anthropic_beta"] = Json::array([Json::string(beta)])
    Some(_) => obj["anthropic_beta"] = Json::array([Json::string(beta)])
  }
}

///|
fn json_int_from_map(obj : Map[String, Json], key : String) -> Int? {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n.trunc().to_int())
    _ => None
  }
}

///|
fn inject_ccs_cache_breakpoints(body : Json, cache_ttl : String) -> Json {
  let copied = copy_json(body)
  guard copied is Object(result) else { return copied }
  upgrade_existing_ccs_cache_ttl(result, cache_ttl)
  let existing = count_ccs_cache_breakpoints(Json::object(result))
  let mut budget = 4 - existing
  if budget <= 0 {
    return Json::object(result)
  }
  if budget > 0 && inject_cache_on_last_tool(result, cache_ttl) {
    budget -= 1
  }
  if budget > 0 && inject_cache_on_last_system_block(result, cache_ttl) {
    budget -= 1
  }
  if budget > 0 &&
    inject_cache_on_last_assistant_content_block(result, cache_ttl) {
    budget -= 1
  }
  Json::object(result)
}

///|
fn ccs_cache_control(cache_ttl : String) -> Json {
  let obj : Map[String, Json] = { "type": Json::string("ephemeral") }
  if cache_ttl != "5m" {
    obj["ttl"] = Json::string(cache_ttl)
  }
  Json::object(obj)
}

///|
fn count_ccs_cache_breakpoints(body : Json) -> Int {
  guard body is Object(obj) else { return 0 }
  let mut count = 0
  match obj.get("tools") {
    Some(Array(tools)) =>
      for tool in tools {
        if json_has_cache_control(tool) {
          count += 1
        }
      }
    _ => ()
  }
  match obj.get("system") {
    Some(Array(system)) =>
      for block in system {
        if json_has_cache_control(block) {
          count += 1
        }
      }
    _ => ()
  }
  match obj.get("messages") {
    Some(Array(messages)) =>
      for message in messages {
        guard message is Object(message_obj) else { continue }
        guard message_obj.get("content") is Some(Array(content)) else {
          continue
        }
        for block in content {
          if json_has_cache_control(block) {
            count += 1
          }
        }
      }
    _ => ()
  }
  count
}

///|
fn json_has_cache_control(value : Json) -> Bool {
  match value {
    Object(obj) => obj.get("cache_control") is Some(_)
    _ => false
  }
}

///|
fn copy_json(value : Json) -> Json {
  match value {
    Object(obj) => {
      let result : Map[String, Json] = {}
      for key, child in obj {
        result[key] = copy_json(child)
      }
      Json::object(result)
    }
    Array(items) => {
      let result : Array[Json] = []
      for item in items {
        result.push(copy_json(item))
      }
      Json::array(result)
    }
    _ => value
  }
}

///|
fn upgrade_existing_ccs_cache_ttl(
  obj : Map[String, Json],
  cache_ttl : String,
) -> Unit {
  match obj.get("tools") {
    Some(Array(tools)) =>
      for tool in tools {
        upgrade_block_cache_ttl(tool, cache_ttl)
      }
    _ => ()
  }
  match obj.get("system") {
    Some(Array(system)) =>
      for block in system {
        upgrade_block_cache_ttl(block, cache_ttl)
      }
    _ => ()
  }
  match obj.get("messages") {
    Some(Array(messages)) =>
      for message in messages {
        guard message is Object(message_obj) else { continue }
        guard message_obj.get("content") is Some(Array(content)) else {
          continue
        }
        for block in content {
          upgrade_block_cache_ttl(block, cache_ttl)
        }
      }
    _ => ()
  }
}

///|
fn upgrade_block_cache_ttl(block : Json, cache_ttl : String) -> Unit {
  guard block is Object(block_obj) else { return }
  guard block_obj.get("cache_control") is Some(Object(cache_control)) else {
    return
  }
  let upgraded : Map[String, Json] = {}
  for key, child in cache_control {
    if key != "ttl" {
      upgraded[key] = child
    }
  }
  if cache_ttl != "5m" {
    upgraded["ttl"] = Json::string(cache_ttl)
  }
  block_obj["cache_control"] = Json::object(upgraded)
}

///|
fn inject_cache_on_last_tool(
  obj : Map[String, Json],
  cache_ttl : String,
) -> Bool {
  guard obj.get("tools") is Some(Array(tools)) else { return false }
  guard !tools.is_empty() else { return false }
  let index = tools.length() - 1
  guard tools[index] is Object(tool) else { return false }
  guard tool.get("cache_control") is None else { return false }
  tool["cache_control"] = ccs_cache_control(cache_ttl)
  tools[index] = Json::object(tool)
  obj["tools"] = Json::array(tools)
  true
}

///|
fn inject_cache_on_last_system_block(
  obj : Map[String, Json],
  cache_ttl : String,
) -> Bool {
  let system = match obj.get("system") {
    Some(String(text)) => {
      let converted = [
        Json::object({
          "type": Json::string("text"),
          "text": Json::string(text),
        }),
      ]
      obj["system"] = Json::array(converted)
      converted
    }
    Some(Array(blocks)) => blocks
    _ => return false
  }
  guard !system.is_empty() else { return false }
  let index = system.length() - 1
  guard system[index] is Object(block) else { return false }
  guard block.get("cache_control") is None else { return false }
  block["cache_control"] = ccs_cache_control(cache_ttl)
  system[index] = Json::object(block)
  obj["system"] = Json::array(system)
  true
}

///|
fn inject_cache_on_last_assistant_content_block(
  obj : Map[String, Json],
  cache_ttl : String,
) -> Bool {
  guard obj.get("messages") is Some(Array(messages)) else { return false }
  let mut message_index = messages.length() - 1
  while message_index >= 0 {
    if messages[message_index] is Object(message_obj) &&
      json_string_from_map(message_obj, "role") == Some("assistant") &&
      inject_cache_on_last_non_thinking_block(message_obj, cache_ttl) {
      messages[message_index] = Json::object(message_obj)
      obj["messages"] = Json::array(messages)
      return true
    }
    message_index -= 1
  }
  false
}

///|
fn inject_cache_on_last_non_thinking_block(
  message_obj : Map[String, Json],
  cache_ttl : String,
) -> Bool {
  guard message_obj.get("content") is Some(Array(content)) else { return false }
  let mut index = content.length() - 1
  while index >= 0 {
    guard content[index] is Object(block) else {
      index -= 1
      continue
    }
    let block_type = json_string_from_map(block, "type").unwrap_or("")
    if block_type == "thinking" || block_type == "redacted_thinking" {
      index -= 1
      continue
    }
    guard block.get("cache_control") is None else { return false }
    block["cache_control"] = ccs_cache_control(cache_ttl)
    content[index] = Json::object(block)
    message_obj["content"] = Json::array(content)
    return true
  }
  false
}
