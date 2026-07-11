///|
priv struct RectifierConfig {
  enabled : Bool
  request_thinking_signature : Bool
  request_thinking_budget : Bool
  request_media_fallback : Bool
  request_media_heuristic : Bool
}

///|
priv struct ThinkingRectifyResult {
  mut body : Json
  mut applied : Bool
  mut removed_thinking_blocks : Int
  mut removed_redacted_thinking_blocks : Int
  mut removed_signature_fields : Int
}

///|
priv struct BudgetRectifySnapshot {
  max_tokens : Int?
  thinking_type : String?
  thinking_budget_tokens : Int?
}

///|
priv struct BudgetRectifyResult {
  body : Json
  applied : Bool
  before : BudgetRectifySnapshot
  after : BudgetRectifySnapshot
}

///|
priv struct MoonRectifierRetry {
  body : Json
  kind : String
  summary : String
}

///|
const MAX_THINKING_BUDGET : Int = 32000

///|
const MAX_TOKENS_VALUE : Int = 64000

///|
const MIN_MAX_TOKENS_FOR_BUDGET : Int = MAX_THINKING_BUDGET + 1

///|
fn default_rectifier_config() -> RectifierConfig {
  {
    enabled: true,
    request_thinking_signature: true,
    request_thinking_budget: true,
    request_media_fallback: true,
    request_media_heuristic: true,
  }
}

///|
fn moongate_rectifier_config_from_env() -> RectifierConfig {
  let defaults = default_rectifier_config()
  {
    enabled: env_bool_default(["MOONGATE_RECTIFIER_ENABLED"], defaults.enabled),
    request_thinking_signature: env_bool_default(
      ["MOONGATE_RECTIFIER_THINKING_SIGNATURE"],
      defaults.request_thinking_signature,
    ),
    request_thinking_budget: env_bool_default(
      ["MOONGATE_RECTIFIER_THINKING_BUDGET"],
      defaults.request_thinking_budget,
    ),
    request_media_fallback: env_bool_default(
      ["MOONGATE_RECTIFIER_MEDIA_FALLBACK"],
      defaults.request_media_fallback,
    ),
    request_media_heuristic: env_bool_default(
      ["MOONGATE_RECTIFIER_MEDIA_HEURISTIC"],
      defaults.request_media_heuristic,
    ),
  }
}

///|
fn should_rectify_thinking_signature(
  error_message : String?,
  config : RectifierConfig,
) -> Bool {
  if !config.enabled || !config.request_thinking_signature {
    return false
  }
  guard error_message is Some(message) else { return false }
  let lower = message.to_lower()
  if lower.contains("invalid") &&
    lower.contains("signature") &&
    lower.contains("thinking") &&
    lower.contains("block") {
    return true
  }
  if lower.contains("thought signature") &&
    (lower.contains("not valid") || lower.contains("invalid")) {
    return true
  }
  if lower.contains("must start with a thinking block") {
    return true
  }
  if lower.contains("expected") &&
    (lower.contains("thinking") || lower.contains("redacted_thinking")) &&
    lower.contains("found") &&
    lower.contains("tool_use") {
    return true
  }
  if lower.contains("signature") && lower.contains("field required") {
    return true
  }
  if lower.contains("signature") &&
    lower.contains("extra inputs are not permitted") {
    return true
  }
  if (lower.contains("thinking") || lower.contains("redacted_thinking")) &&
    lower.contains("cannot be modified") {
    return true
  }
  lower.contains("非法请求") ||
  lower.contains("illegal request") ||
  lower.contains("invalid request")
}

///|
fn should_rectify_thinking_budget(
  error_message : String?,
  config : RectifierConfig,
) -> Bool {
  if !config.enabled || !config.request_thinking_budget {
    return false
  }
  guard error_message is Some(message) else { return false }
  let lower = message.to_lower()
  let has_budget_tokens_reference = lower.contains("budget_tokens") ||
    lower.contains("budget tokens")
  let has_thinking_reference = lower.contains("thinking")
  let has_1024_constraint = lower.contains("greater than or equal to 1024") ||
    lower.contains(">= 1024") ||
    (lower.contains("1024") && lower.contains("input should be"))
  has_budget_tokens_reference && has_thinking_reference && has_1024_constraint
}

///|
fn rectify_anthropic_request(body : Json) -> ThinkingRectifyResult {
  let copied = copy_json(body)
  let result = {
    body: copied,
    applied: false,
    removed_thinking_blocks: 0,
    removed_redacted_thinking_blocks: 0,
    removed_signature_fields: 0,
  }
  guard copied is Object(obj) else { return result }
  match obj.get("messages") {
    Some(Array(messages)) =>
      for message in messages {
        guard message is Object(message_obj) else { continue }
        guard message_obj.get("content") is Some(Array(content)) else {
          continue
        }
        let new_content : Array[Json] = []
        let mut content_modified = false
        for block in content {
          guard block is Object(block_obj) else {
            new_content.push(block)
            continue
          }
          match json_string_from_map(block_obj, "type") {
            Some("thinking") => {
              result.removed_thinking_blocks += 1
              content_modified = true
              continue
            }
            Some("redacted_thinking") => {
              result.removed_redacted_thinking_blocks += 1
              content_modified = true
              continue
            }
            _ => ()
          }
          if block_obj.get("signature") is Some(_) {
            let clean_block : Map[String, Json] = {}
            for key, value in block_obj {
              if key != "signature" {
                clean_block[key] = value
              }
            }
            result.removed_signature_fields += 1
            content_modified = true
            new_content.push(Json::object(clean_block))
          } else {
            new_content.push(Json::object(block_obj))
          }
        }
        if content_modified {
          result.applied = true
          message_obj["content"] = Json::array(new_content)
        }
      }
    _ => ()
  }
  if should_remove_top_level_thinking(obj) {
    obj.remove("thinking")
    result.applied = true
  }
  result.body = Json::object(obj)
  result
}

///|
fn should_remove_top_level_thinking(obj : Map[String, Json]) -> Bool {
  let thinking_enabled = match obj.get("thinking") {
    Some(Object(thinking)) =>
      json_string_from_map(thinking, "type") == Some("enabled")
    _ => false
  }
  if !thinking_enabled {
    return false
  }
  guard obj.get("messages") is Some(Array(messages)) else { return false }
  let mut index = messages.length() - 1
  while index >= 0 {
    guard messages[index] is Object(message_obj) else {
      index -= 1
      continue
    }
    if json_string_from_map(message_obj, "role") != Some("assistant") {
      index -= 1
      continue
    }
    guard message_obj.get("content") is Some(Array(content)) else {
      return false
    }
    guard !content.is_empty() else { return false }
    let first_type = match content[0] {
      Object(first) => json_string_from_map(first, "type")
      _ => None
    }
    if first_type == Some("thinking") || first_type == Some("redacted_thinking") {
      return false
    }
    return content.any(block => {
      match block {
        Object(block_obj) =>
          json_string_from_map(block_obj, "type") == Some("tool_use")
        _ => false
      }
    })
  }
  false
}

///|
fn rectify_thinking_budget(body : Json) -> BudgetRectifyResult {
  let copied = copy_json(body)
  let before = snapshot_thinking_budget(copied)
  if before.thinking_type == Some("adaptive") {
    return { body: copied, applied: false, before, after: before }
  }
  guard copied is Object(obj) else {
    return { body: copied, applied: false, before, after: before }
  }
  if !(obj.get("thinking") is Some(Object(_))) {
    obj["thinking"] = Json::object({})
  }
  guard obj.get("thinking") is Some(Object(thinking)) else {
    return { body: Json::object(obj), applied: false, before, after: before }
  }
  thinking["type"] = Json::string("enabled")
  thinking["budget_tokens"] = Json::number(MAX_THINKING_BUDGET.to_double())
  obj["thinking"] = Json::object(thinking)
  if before.max_tokens is None ||
    before.max_tokens < Some(MIN_MAX_TOKENS_FOR_BUDGET) {
    obj["max_tokens"] = Json::number(MAX_TOKENS_VALUE.to_double())
  }
  let body = Json::object(obj)
  let after = snapshot_thinking_budget(body)
  { body, applied: !budget_snapshot_equal(before, after), before, after }
}

///|
fn snapshot_thinking_budget(body : Json) -> BudgetRectifySnapshot {
  guard body is Object(obj) else {
    return {
      max_tokens: None,
      thinking_type: None,
      thinking_budget_tokens: None,
    }
  }
  let max_tokens = json_int_from_map(obj, "max_tokens")
  let thinking_type = match obj.get("thinking") {
    Some(Object(thinking)) => json_string_from_map(thinking, "type")
    _ => None
  }
  let thinking_budget_tokens = match obj.get("thinking") {
    Some(Object(thinking)) => json_int_from_map(thinking, "budget_tokens")
    _ => None
  }
  { max_tokens, thinking_type, thinking_budget_tokens }
}

///|
fn budget_snapshot_equal(
  left : BudgetRectifySnapshot,
  right : BudgetRectifySnapshot,
) -> Bool {
  left.max_tokens == right.max_tokens &&
  left.thinking_type == right.thinking_type &&
  left.thinking_budget_tokens == right.thinking_budget_tokens
}

///|
fn moon_rectifier_retry_body(
  response_body : String,
  upstream_body : Json,
) -> MoonRectifierRetry? {
  let config = moongate_rectifier_config_from_env()
  ignore(config.request_media_fallback || config.request_media_heuristic)
  let error_message = Some(response_body)
  if should_rectify_thinking_signature(error_message, config) {
    let rectified = rectify_anthropic_request(upstream_body)
    if rectified.applied {
      return Some({
        body: rectified.body,
        kind: "thinking_signature",
        summary: thinking_rectifier_summary(rectified),
      })
    }
  }
  if should_rectify_thinking_budget(error_message, config) {
    let rectified = rectify_thinking_budget(upstream_body)
    if rectified.applied {
      return Some({
        body: rectified.body,
        kind: "thinking_budget",
        summary: budget_rectifier_summary(rectified),
      })
    }
  }
  None
}

///|
fn thinking_rectifier_summary(result : ThinkingRectifyResult) -> String {
  "removed_thinking=\{result.removed_thinking_blocks}, removed_redacted_thinking=\{result.removed_redacted_thinking_blocks}, removed_signatures=\{result.removed_signature_fields}"
}

///|
fn budget_rectifier_summary(result : BudgetRectifyResult) -> String {
  "before(max_tokens=\{option_int_for_log(result.before.max_tokens)}, thinking_type=\{option_string_for_log(result.before.thinking_type)}, budget_tokens=\{option_int_for_log(result.before.thinking_budget_tokens)}), after(max_tokens=\{option_int_for_log(result.after.max_tokens)}, thinking_type=\{option_string_for_log(result.after.thinking_type)}, budget_tokens=\{option_int_for_log(result.after.thinking_budget_tokens)})"
}

///|
fn option_int_for_log(value : Int?) -> String {
  match value {
    Some(value) => value.to_string()
    None => "none"
  }
}

///|
fn option_string_for_log(value : String?) -> String {
  match value {
    Some(value) => value
    None => "none"
  }
}
