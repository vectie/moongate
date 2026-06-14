///|
const SESSION_REQUEST_ID_PREFIX : String = "session:"

///|
pub struct TokenUsage {
  input_tokens : Int
  output_tokens : Int
  cache_read_tokens : Int
  cache_creation_tokens : Int
  model : String?
  message_id : String?
}

///|
pub fn TokenUsage::new(
  input_tokens~ : Int,
  output_tokens~ : Int,
  cache_read_tokens? : Int = 0,
  cache_creation_tokens? : Int = 0,
  model? : String? = None,
  message_id? : String? = None,
) -> TokenUsage {
  {
    input_tokens,
    output_tokens,
    cache_read_tokens,
    cache_creation_tokens,
    model,
    message_id,
  }
}

///|
pub fn TokenUsage::empty() -> TokenUsage {
  TokenUsage::new(input_tokens=0, output_tokens=0)
}

///|
fn token_usage_or_response_model(
  usage : TokenUsage?,
  body : Json,
  model_keys : Array[String],
) -> TokenUsage {
  match usage {
    Some(usage) => usage
    None =>
      TokenUsage::new(
        input_tokens=0,
        output_tokens=0,
        model=response_model_from_json(body, model_keys),
      )
  }
}

///|
fn response_model_from_json(body : Json, model_keys : Array[String]) -> String? {
  guard body is Object(obj) else { return None }
  for key in model_keys {
    match json_string(obj, key) {
      Some(model) if !model.is_empty() => return Some(model)
      _ => ()
    }
  }
  None
}

///|
pub fn TokenUsage::has_billable_tokens(self : TokenUsage) -> Bool {
  self.input_tokens > 0 ||
  self.output_tokens > 0 ||
  self.cache_read_tokens > 0 ||
  self.cache_creation_tokens > 0
}

///|
fn TokenUsage::dedup_request_id(
  self : TokenUsage,
  fallback_id : String,
) -> String {
  match self.message_id {
    Some(message_id) => "\{SESSION_REQUEST_ID_PREFIX}\{message_id}"
    None => fallback_id
  }
}

///|
pub fn TokenUsage::anthropic_input_tokens(self : TokenUsage) -> Int {
  max_int(
    self.input_tokens - self.cache_read_tokens - self.cache_creation_tokens,
    0,
  )
}

///|
pub fn token_usage_from_claude_response(body : Json) -> TokenUsage? {
  guard body is Object(obj) else { return None }
  guard obj.get("usage") is Some(Object(usage)) else { return None }
  let input_tokens = json_int(usage, "input_tokens")
  let output_tokens = json_int(usage, "output_tokens")
  if input_tokens is None || output_tokens is None {
    return None
  }
  Some(
    TokenUsage::new(
      input_tokens=input_tokens.unwrap(),
      output_tokens=output_tokens.unwrap(),
      cache_read_tokens=json_int_or_zero(usage, "cache_read_input_tokens"),
      cache_creation_tokens=json_int_or_zero(
        usage, "cache_creation_input_tokens",
      ),
      model=json_string(obj, "model"),
      message_id=json_string(obj, "id"),
    ),
  )
}

///|
pub fn token_usage_from_codex_response(body : Json) -> TokenUsage? {
  guard body is Object(obj) else { return None }
  guard obj.get("usage") is Some(Object(usage)) else { return None }
  let input_tokens = json_int(usage, "input_tokens")
  let output_tokens = json_int(usage, "output_tokens")
  if input_tokens is None || output_tokens is None {
    return None
  }
  let cache_read_tokens = match json_int(usage, "cache_read_input_tokens") {
    Some(n) => n
    None =>
      match usage.get("input_tokens_details") {
        Some(Object(details)) => json_int_or_zero(details, "cached_tokens")
        _ => 0
      }
  }
  Some(
    TokenUsage::new(
      input_tokens=input_tokens.unwrap(),
      output_tokens=output_tokens.unwrap(),
      cache_read_tokens~,
      cache_creation_tokens=json_int_or_zero(
        usage, "cache_creation_input_tokens",
      ),
      model=json_string(obj, "model"),
    ),
  )
}

///|
pub fn token_usage_from_codex_response_adjusted(body : Json) -> TokenUsage? {
  guard token_usage_from_codex_response(body) is Some(usage) else {
    return None
  }
  Some(
    TokenUsage::new(
      input_tokens=max_int(usage.input_tokens - usage.cache_read_tokens, 0),
      output_tokens=usage.output_tokens,
      cache_read_tokens=usage.cache_read_tokens,
      cache_creation_tokens=usage.cache_creation_tokens,
      model=usage.model,
      message_id=usage.message_id,
    ),
  )
}

///|
pub fn token_usage_from_openai_response(body : Json) -> TokenUsage? {
  guard body is Object(obj) else { return None }
  guard obj.get("usage") is Some(Object(usage)) else { return None }
  let input_tokens = json_int(usage, "prompt_tokens")
  let output_tokens = json_int(usage, "completion_tokens")
  if input_tokens is None || output_tokens is None {
    return None
  }
  let cache_read_tokens = match usage.get("prompt_tokens_details") {
    Some(Object(details)) => json_int_or_zero(details, "cached_tokens")
    _ => 0
  }
  Some(
    TokenUsage::new(
      input_tokens=input_tokens.unwrap(),
      output_tokens=output_tokens.unwrap(),
      cache_read_tokens~,
      model=json_string(obj, "model"),
    ),
  )
}

///|
pub fn token_usage_from_openrouter_response(body : Json) -> TokenUsage? {
  token_usage_from_openai_response(body)
}

///|
pub fn token_usage_from_codex_response_auto(body : Json) -> TokenUsage? {
  guard body is Object(obj) else { return None }
  guard obj.get("usage") is Some(Object(usage)) else { return None }
  if usage.get("prompt_tokens") is Some(_) {
    token_usage_from_openai_response(body)
  } else if usage.get("input_tokens") is Some(_) {
    token_usage_from_codex_response(body)
  } else {
    None
  }
}

///|
pub fn token_usage_from_claude_stream_events(
  events : Array[Json],
) -> TokenUsage? {
  let mut input_tokens = 0
  let mut output_tokens = 0
  let mut cache_read_tokens = 0
  let mut cache_creation_tokens = 0
  let mut model : String? = None
  let mut message_id : String? = None
  let mut input_from_delta = false
  for event in events {
    guard event is Object(obj) else { continue }
    match json_string(obj, "type") {
      Some("message_start") =>
        match obj.get("message") {
          Some(Object(message)) => {
            if model is None {
              model = json_string(message, "model")
            }
            if message_id is None {
              message_id = json_string(message, "id")
            }
            match message.get("usage") {
              Some(Object(usage)) => {
                if json_int(usage, "input_tokens") is Some(input) {
                  input_tokens = input
                }
                cache_read_tokens = json_int_or_zero(
                  usage, "cache_read_input_tokens",
                )
                cache_creation_tokens = json_int_or_zero(
                  usage, "cache_creation_input_tokens",
                )
              }
              _ => ()
            }
          }
          _ => ()
        }
      Some("message_delta") =>
        match obj.get("usage") {
          Some(Object(usage)) => {
            if json_int(usage, "output_tokens") is Some(output) {
              output_tokens = output
            }
            let delta_input = json_int(usage, "input_tokens")
            let delta_cache_read = json_int(usage, "cache_read_input_tokens")
            let delta_cache_creation = json_int(
              usage, "cache_creation_input_tokens",
            )
            match delta_input {
              Some(input) if input > 0 &&
                (
                  input_tokens == 0 ||
                  input < input_tokens ||
                  (input_from_delta && input <= input_tokens)
                ) => {
                input_tokens = input
                input_from_delta = true
                if delta_cache_read is Some(cache_read) {
                  cache_read_tokens = cache_read
                }
                if delta_cache_creation is Some(cache_creation) {
                  cache_creation_tokens = cache_creation
                }
              }
              _ => ()
            }
            if cache_read_tokens == 0 {
              if delta_cache_read is Some(cache_read) {
                cache_read_tokens = cache_read
              }
            }
            if cache_creation_tokens == 0 {
              if delta_cache_creation is Some(cache_creation) {
                cache_creation_tokens = cache_creation
              }
            }
          }
          _ => ()
        }
      _ => ()
    }
  }
  let usage = TokenUsage::new(
    input_tokens~,
    output_tokens~,
    cache_read_tokens~,
    cache_creation_tokens~,
    model~,
    message_id~,
  )
  if usage.has_billable_tokens() {
    Some(usage)
  } else {
    None
  }
}

///|
pub fn token_usage_from_codex_stream_events(
  events : Array[Json],
) -> TokenUsage? {
  for event in events {
    guard event is Object(obj) else { continue }
    if json_string(obj, "type") == Some("response.completed") {
      match obj.get("response") {
        Some(response) =>
          return token_usage_from_codex_response_adjusted(response)
        None => ()
      }
    }
  }
  None
}

///|
pub fn token_usage_from_codex_stream_events_auto(
  events : Array[Json],
) -> TokenUsage? {
  for event in events {
    guard event is Object(obj) else { continue }
    if json_string(obj, "type") == Some("response.completed") {
      match obj.get("response") {
        Some(response) => return token_usage_from_codex_response_auto(response)
        None => ()
      }
    }
  }
  token_usage_from_openai_stream_events(events)
}

///|
pub fn token_usage_from_openai_stream_events(
  events : Array[Json],
) -> TokenUsage? {
  let mut i = events.length() - 1
  while i >= 0 {
    let event = events[i]
    match event {
      Object(obj) =>
        match obj.get("usage") {
          Some(Null) | None => ()
          Some(_) => return token_usage_from_openai_response(event)
        }
      _ => ()
    }
    i -= 1
  }
  None
}

///|
pub fn token_usage_from_gemini_response(body : Json) -> TokenUsage? {
  guard body is Object(obj) else { return None }
  guard obj.get("usageMetadata") is Some(Object(usage)) else { return None }
  let prompt_tokens = json_int(usage, "promptTokenCount")
  let total_tokens = json_int(usage, "totalTokenCount")
  if prompt_tokens is None || total_tokens is None {
    return None
  }
  let input_tokens = prompt_tokens.unwrap()
  let output_tokens = max_int(total_tokens.unwrap() - input_tokens, 0)
  Some(
    TokenUsage::new(
      input_tokens~,
      output_tokens~,
      cache_read_tokens=json_int_or_zero(usage, "cachedContentTokenCount"),
      model=json_string(obj, "modelVersion"),
    ),
  )
}

///|
pub fn token_usage_from_gemini_stream_chunks(
  chunks : Array[Json],
) -> TokenUsage? {
  let mut input_tokens = 0
  let mut total_tokens = 0
  let mut cache_read_tokens = 0
  let mut model : String? = None
  for chunk in chunks {
    guard chunk is Object(obj) else { continue }
    match obj.get("usageMetadata") {
      Some(Object(usage)) => {
        input_tokens = json_int_or_zero(usage, "promptTokenCount")
        total_tokens = json_int_or_zero(usage, "totalTokenCount")
        cache_read_tokens = json_int_or_zero(usage, "cachedContentTokenCount")
      }
      _ => ()
    }
    if model is None {
      model = json_string(obj, "modelVersion")
    }
  }
  let output_tokens = max_int(total_tokens - input_tokens, 0)
  let usage = TokenUsage::new(
    input_tokens~,
    output_tokens~,
    cache_read_tokens~,
    model~,
  )
  if input_tokens > 0 || output_tokens > 0 {
    Some(usage)
  } else {
    None
  }
}

///|
fn json_int(obj : Map[String, Json], key : String) -> Int? {
  match obj.get(key) {
    Some(Number(n, ..)) => Some(n.trunc().to_int())
    _ => None
  }
}

///|
fn json_int_or_zero(obj : Map[String, Json], key : String) -> Int {
  match json_int(obj, key) {
    Some(n) => n
    None => 0
  }
}

///|
fn json_string(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
