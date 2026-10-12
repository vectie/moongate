///|
priv struct ParsedResult {
  custom_id : String
  reason : String
  http_status : Json
  response_state : String
  row : Json?
}

///|
fn field(obj : Map[String, Json], key : String) -> Json {
  obj.get(key).unwrap_or(Json::null())
}

///|
fn count(value : Json) -> Double? {
  match value {
    Number(_, repr=Some(text)) => exact_count(text)
    _ => None
  }
}

///|
fn parse_result(record : Json) -> Result[ParsedResult, String] {
  guard record is Object(obj) else {
    return Err("Expected a Batch result object")
  }
  guard field(obj, "custom_id") is String(custom_id) &&
    !custom_id.trim().is_empty() else {
    return Err("A nonempty custom_id is required")
  }
  let response = field(obj, "response")
  let error = field(obj, "error")
  if error != Json::null() {
    guard error is Object(_) && response == Json::null() else {
      return Err("Expected an error object with a null response")
    }
    return Ok({
      custom_id,
      reason: "batch_error",
      http_status: Json::null(),
      response_state: "",
      row: None,
    })
  }
  guard response is Object(response) else {
    return Err(
      "Expected response or error; Batch input requests are unsupported",
    )
  }
  guard count(field(response, "status_code")) is Some(status) &&
    status >= 100.0 &&
    status <= 599.0 else {
    return Err("response.status_code must be an integer HTTP status")
  }
  if status < 200.0 || status >= 300.0 {
    return Ok({
      custom_id,
      reason: "http_error",
      http_status: status.to_json(),
      response_state: "",
      row: None,
    })
  }
  guard field(response, "body") is Object(body) else {
    return Err("Successful response.body must be an object")
  }
  let kind = field(body, "object")
  guard kind == Json::string("chat.completion") ||
    kind == Json::string("response") else {
    return Err(
      "Supported successful bodies are chat.completion or response objects",
    )
  }
  guard field(body, "model") is String(model) && !model.trim().is_empty() else {
    return Err("Successful response body needs a nonempty model")
  }
  let is_response = kind == Json::string("response")
  let response_state = if is_response {
    guard field(body, "status") is String(state) &&
      [
        "completed", "failed", "in_progress", "cancelled", "queued", "incomplete",
      ].contains(state) else {
      return Err("Responses body needs a recognized status")
    }
    state
  } else {
    ""
  }
  let usage = field(body, "usage")
  if usage == Json::null() {
    return Ok({
      custom_id,
      reason: "missing_usage",
      http_status: status.to_json(),
      response_state,
      row: None,
    })
  }
  guard usage is Object(usage) else {
    return Err("usage must be an object or null")
  }
  let input_key = if is_response { "input_tokens" } else { "prompt_tokens" }
  let output_key = if is_response {
    "output_tokens"
  } else {
    "completion_tokens"
  }
  guard count(field(usage, input_key)) is Some(input) &&
    count(field(usage, output_key)) is Some(output) else {
    return Err(
      "Usage needs whole nonnegative numeric \{input_key} and \{output_key} within 9007199254740991",
    )
  }
  if input > 9007199254740991.0 - output {
    return Err("Derived token total exceeds 9007199254740991")
  }
  let total = input + output
  let supplied_total = field(usage, "total_tokens")
  if supplied_total != Json::null() && count(supplied_total) != Some(total) {
    return Err(
      "total_tokens must equal input plus output within the safe-number limit",
    )
  }
  let created = field(body, if is_response { "created_at" } else { "created" })
  // Timestamp interpretation is shared with the existing preview normalizer.
  // No batch submission/download timestamp is substituted for a missing value.
  let row : Json = {
    "requestId": custom_id.to_json(),
    "model": model.to_json(),
    "inputTokens": input.to_json(),
    "outputTokens": output.to_json(),
    "totalTokens": total.to_json(),
    "createdAt": created,
    "totalCostUsd": Json::null(),
  }
  Ok({
    custom_id,
    reason: "imported",
    http_status: status.to_json(),
    response_state,
    row: Some(row),
  })
}
