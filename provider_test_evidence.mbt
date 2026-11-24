///|
fn provider_test_has_output(value : Json) -> Bool {
  match value {
    String(text) => !text.trim().is_empty()
    Array(items) => items.any(provider_test_has_output)
    Object(obj) => {
      if obj.contains("error") && obj["error"] != Json::null() {
        return false
      }
      if obj.get("type") == Some(Json::string("tool_use")) ||
        obj.get("type") == Some(Json::string("function_call")) {
        return true
      }
      for
        key in ["text", "content", "parts", "output", "output_text", "message"] {
        if obj.get(key) is Some(child) && provider_test_has_output(child) {
          return true
        }
      }
      obj.get("tool_calls") is Some(Array(calls)) && !calls.is_empty()
    }
    _ => false
  }
}

///|
fn provider_test_completed_json(value : Json, format : String) -> Bool {
  guard value is Object(obj) else { return false }
  if obj.contains("error") && obj["error"] != Json::null() {
    return false
  }
  if obj.get("status") is Some(String("failed" | "incomplete" | "cancelled")) {
    return false
  }
  match format {
    "openai_chat" =>
      obj.get("choices") is Some(Array(choices)) &&
      choices.any(choice => {
        match choice {
          { "finish_reason": String("length" | "content_filter" | "error"), .. } =>
            false
          _ => provider_test_has_output(choice)
        }
      })
    "anthropic" =>
      obj.get("stop_reason") != Some(Json::string("max_tokens")) &&
      obj.get("content") is Some(content) &&
      provider_test_has_output(content)
    "gemini_native" =>
      obj.get("candidates") is Some(Array(candidates)) &&
      candidates.any(candidate => {
        match candidate {
          { "finishReason": String("MAX_TOKENS" | "SAFETY" | "RECITATION"), .. } =>
            false
          _ => provider_test_has_output(candidate)
        }
      })
    _ =>
      obj.get("status") == Some(Json::string("completed")) &&
      obj.get("output") is Some(output) &&
      provider_test_has_output(output)
  }
}

///|
fn provider_test_completed_response(body : String, format : String) -> Bool {
  let parsed = @json.parse(body) catch { _ => Json::null() }
  match parsed {
    Object(_) as value => return provider_test_completed_json(value, format)
    _ => ()
  }
  // OAuth Responses uses SSE: only a terminal completed event certifies it.
  for line in body.split("\n") {
    let line = line.trim()
    if !line.has_prefix("data:") {
      continue
    }
    let event = @json.parse(line[5:].trim().to_owned()) catch { _ => continue }
    if event is { "type": "response.completed", "response": response, .. } &&
      provider_test_completed_json(response, "openai_responses") {
      return true
    }
  }
  false
}
