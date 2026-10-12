///|
priv struct AnthropicResult {
  id : String
  result_type : String
  model : Json
  stop_reason : Json
  counts : Map[String, Json]
  usage_state : String
  input : Double?
  output : Double?
  total : Double?
}

///|
fn parse_anthropic_result(record : Json) -> Result[AnthropicResult, String] {
  guard record is Object(obj) &&
    field(obj, "custom_id") is String(id) &&
    !id.trim().is_empty() else {
    return Err("Expected an object with a nonempty custom_id")
  }
  guard field(obj, "result") is Object(result) &&
    field(result, "type") is String(kind) &&
    ["succeeded", "errored", "canceled", "expired"].contains(kind) else {
    return Err("Expected an Anthropic result with a recognized type")
  }
  let counts : Map[String, Json] = {
    "uncachedInputTokens": Json::null(),
    "cacheCreationInputTokens": Json::null(),
    "cacheReadInputTokens": Json::null(),
    "outputTokens": Json::null(),
  }
  if kind != "succeeded" {
    if field(result, "message") != Json::null() {
      return Err("A non-succeeded result cannot contain a message")
    }
    if kind == "errored" && !(field(result, "error") is Object(_)) {
      return Err("An errored result needs an error object")
    }
    return Ok({
      id,
      result_type: kind,
      model: Json::null(),
      stop_reason: Json::null(),
      counts,
      usage_state: "not_reported",
      input: None,
      output: None,
      total: None,
    })
  }
  guard field(result, "message") is Object(message) &&
    field(message, "type") == Json::string("message") &&
    field(message, "role") == Json::string("assistant") &&
    field(message, "model") is String(model) &&
    !model.trim().is_empty() else {
    return Err(
      "A succeeded result needs an assistant message with a nonempty model",
    )
  }
  if field(result, "error") != Json::null() {
    return Err("A succeeded result cannot contain an error")
  }
  let stop_reason = match field(message, "stop_reason") {
    Null => Json::null()
    String(reason) =>
      if [
          "end_turn", "max_tokens", "stop_sequence", "tool_use", "pause_turn", "refusal",
          "model_context_window_exceeded",
        ].contains(reason) {
        reason.to_json()
      } else {
        "unrecognized".to_json()
      }
    _ => return Err("message.stop_reason must be a string or null")
  }
  let usage = field(message, "usage")
  let mut state = "missing_usage"
  let mut known = 0
  let mut total = 0.0
  let mut input = 0.0
  let mut output = 0.0
  if usage != Json::null() {
    guard usage is Object(usage) else {
      return Err("message.usage must be an object or null")
    }
    state = "incomplete_usage"
    for
      (source, target) in [
        ("input_tokens", "uncachedInputTokens"),
        ("cache_creation_input_tokens", "cacheCreationInputTokens"),
        ("cache_read_input_tokens", "cacheReadInputTokens"),
        ("output_tokens", "outputTokens"),
      ] {
      let value = field(usage, source)
      if value == Json::null() {
        continue
      }
      guard count(value) is Some(n) else {
        return Err(
          "Usage components must be whole nonnegative JSON numbers within 9007199254740991",
        )
      }
      if n > 9007199254740991.0 - total {
        return Err("Combined token components exceed the safe-number limit")
      }
      counts[target] = n.to_json()
      total += n
      if source == "output_tokens" {
        output = n
      } else {
        input += n
      }
      known += 1
    }
    if known == 4 {
      state = "imported"
    }
  }
  Ok({
    id,
    result_type: kind,
    model: model.to_json(),
    stop_reason,
    counts,
    usage_state: state,
    input: if known == 4 {
      Some(input)
    } else {
      None
    },
    output: if known == 4 {
      Some(output)
    } else {
      None
    },
    total: if known == 4 {
      Some(total)
    } else {
      None
    },
  })
}
