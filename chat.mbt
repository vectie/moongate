///|
priv struct ChatCompletionOutput {
  content : String
  tool_calls : Array[Json]
}

///|
fn openai_chat_model(body : Json) -> String? {
  guard body is Object(obj) else { return None }
  match obj.get("model") {
    Some(String(model)) => Some(model)
    _ => None
  }
}

///|
fn openai_chat_to_codex_response_request(
  body : Json,
  upstream_model : String,
) -> Json? {
  guard body is Object(obj) else { return None }
  guard obj.get("messages") is Some(Array(messages)) else { return None }
  let input_items : Array[Json] = []
  let instructions : Array[String] = []
  for message in messages {
    append_chat_message_as_response_item(message, input_items, instructions)
  }
  let request : Map[String, Json] = {
    "model": Json::string(upstream_model),
    "input": Json::array(input_items),
    "store": Json::boolean(false),
    "stream": Json::boolean(json_bool_from_map(obj, "stream").unwrap_or(false)),
  }
  if !instructions.is_empty() {
    request["instructions"] = Json::string(instructions.join("\n\n"))
  }
  if obj.get("max_completion_tokens") is Some(value) {
    request["max_output_tokens"] = value
  } else if obj.get("max_tokens") is Some(value) {
    request["max_output_tokens"] = value
  }
  for key in ["temperature", "top_p", "metadata", "reasoning"] {
    if obj.get(key) is Some(value) {
      request[key] = value
    }
  }
  if obj.get("tools") is Some(Array(tools)) {
    let codex_tools : Array[Json] = []
    for tool in tools {
      if openai_tool_to_codex_tool(tool) is Some(codex_tool) {
        codex_tools.push(codex_tool)
      }
    }
    if !codex_tools.is_empty() {
      request["tools"] = Json::array(codex_tools)
    }
  }
  if obj.get("tool_choice") is Some(value) {
    request["tool_choice"] = openai_tool_choice_to_codex(value)
  }
  Some(Json::object(request))
}

///|
fn codex_responses_request_to_openai_chat_completion(
  body : Json,
  fallback_model : String,
) -> Json? {
  guard body is Object(obj) else { return None }
  let messages : Array[Json] = []
  match json_string_from_map(obj, "instructions") {
    Some(instructions) if !instructions.trim().is_empty() =>
      messages.push(
        Json::object({
          "role": Json::string("system"),
          "content": Json::string(instructions),
        }),
      )
    _ => ()
  }
  append_codex_responses_input_as_openai_chat_messages(
    obj.get("input"),
    messages,
  )
  let result : Map[String, Json] = {
    "model": Json::string(
      json_string_from_map(obj, "model").unwrap_or(fallback_model),
    ),
    "messages": Json::array(messages),
    "stream": Json::boolean(json_bool_from_map(obj, "stream").unwrap_or(false)),
  }
  if obj.get("max_output_tokens") is Some(value) {
    result["max_tokens"] = value
  }
  for key in ["temperature", "top_p", "metadata", "reasoning"] {
    if obj.get(key) is Some(value) {
      result[key] = value
    }
  }
  append_codex_responses_tools_as_openai_chat_tools(obj, result)
  if obj.get("tool_choice") is Some(value) {
    result["tool_choice"] = codex_tool_choice_to_openai_chat(value)
  }
  Some(Json::object(result))
}

///|
fn append_codex_responses_input_as_openai_chat_messages(
  input : Json?,
  messages : Array[Json],
) -> Unit {
  let pending_tool_calls : Array[Json] = []
  let flush_pending_tool_calls = fn() {
    if !pending_tool_calls.is_empty() {
      messages.push(
        Json::object({
          "role": Json::string("assistant"),
          "content": Json::null(),
          "tool_calls": Json::array(pending_tool_calls.copy()),
        }),
      )
      pending_tool_calls.clear()
    }
  }
  let items = match input {
    Some(Array(items)) => items
    Some(Object(_)) => [input.unwrap()]
    Some(String(text)) =>
      [
        Json::object({
          "role": Json::string("user"),
          "content": Json::string(text),
        }),
      ]
    _ => []
  }
  for item in items {
    guard item is Object(item_obj) else { continue }
    match json_string_from_map(item_obj, "type") {
      Some(type_) if codex_chat_is_call_item_type(type_) =>
        pending_tool_calls.push(openai_chat_tool_call_from_codex_item(item_obj))
      Some(type_) if codex_chat_is_call_output_item_type(type_) => {
        flush_pending_tool_calls()
        messages.push(openai_chat_tool_message_from_codex_output(item_obj))
      }
      _ => {
        flush_pending_tool_calls()
        messages.push(openai_chat_message_from_codex_input_item(item_obj))
      }
    }
  }
  flush_pending_tool_calls()
}

///|
fn openai_chat_message_from_codex_input_item(item : Map[String, Json]) -> Json {
  let role = json_string_from_map(item, "role").unwrap_or("user")
  Json::object({
    "role": Json::string(if role == "assistant" { "assistant" } else { "user" }),
    "content": codex_responses_content_to_chat_content(item.get("content")),
  })
}

///|
fn codex_responses_content_to_chat_content(content : Json?) -> Json {
  match content {
    Some(String(text)) => Json::string(text)
    Some(Array(parts)) => {
      let chat_parts : Array[Json] = []
      let text_parts : Array[String] = []
      let mut has_non_text_part = false
      for part in parts {
        match part {
          Object(part_obj) =>
            match json_string_from_map(part_obj, "type") {
              Some("input_text") | Some("output_text") =>
                if json_string_from_map(part_obj, "text") is Some(text) &&
                  !text.is_empty() {
                  text_parts.push(text)
                  chat_parts.push(
                    Json::object({
                      "type": Json::string("text"),
                      "text": Json::string(text),
                    }),
                  )
                }
              Some("text") =>
                if json_string_from_map(part_obj, "text") is Some(text) &&
                  !text.is_empty() {
                  text_parts.push(text)
                  chat_parts.push(
                    Json::object({
                      "type": Json::string("text"),
                      "text": Json::string(text),
                    }),
                  )
                }
              Some("refusal") =>
                if json_string_from_map(part_obj, "refusal") is Some(text) &&
                  !text.is_empty() {
                  text_parts.push(text)
                  chat_parts.push(
                    Json::object({
                      "type": Json::string("text"),
                      "text": Json::string(text),
                    }),
                  )
                }
              Some("input_image") =>
                if part_obj.get("image_url") is Some(image_url) {
                  let chat_image_url = match image_url {
                    Object(_) => image_url
                    String(url) => Json::object({ "url": Json::string(url) })
                    _ => Json::object({ "url": Json::string("") })
                  }
                  chat_parts.push(
                    Json::object({
                      "type": Json::string("image_url"),
                      "image_url": chat_image_url,
                    }),
                  )
                  has_non_text_part = true
                }
              Some("input_file") =>
                if codex_responses_input_file_to_chat_file(part_obj)
                  is Some(file) {
                  chat_parts.push(
                    Json::object({ "type": Json::string("file"), "file": file }),
                  )
                  has_non_text_part = true
                }
              Some("input_audio") =>
                if part_obj.get("input_audio") is Some(input_audio) {
                  chat_parts.push(
                    Json::object({
                      "type": Json::string("input_audio"),
                      "input_audio": input_audio,
                    }),
                  )
                  has_non_text_part = true
                }
              _ => ()
            }
          _ => ()
        }
      }
      if has_non_text_part {
        Json::array(chat_parts)
      } else {
        Json::string(text_parts.join("\n"))
      }
    }
    Some(value) => value
    None => Json::string("")
  }
}

///|
fn codex_responses_input_file_to_chat_file(part : Map[String, Json]) -> Json? {
  let file : Map[String, Json] = {}
  let mut has_supported_file_ref = false
  for key in ["file_id", "file_data", "filename"] {
    if part.get(key) is Some(value) {
      file[key] = value
      if key != "filename" {
        has_supported_file_ref = true
      }
    }
  }
  if has_supported_file_ref {
    Some(Json::object(file))
  } else {
    None
  }
}

///|
fn openai_chat_tool_call_from_codex_item(item : Map[String, Json]) -> Json {
  Json::object({
    "id": Json::string(
      codex_chat_response_item_call_id(Json::object(item)).unwrap_or(
        generate_chat_completion_id(),
      ),
    ),
    "type": Json::string("function"),
    "function": Json::object({
      "name": Json::string(json_string_from_map(item, "name").unwrap_or("tool")),
      "arguments": Json::string(codex_responses_call_arguments(item)),
    }),
  })
}

///|
fn codex_responses_call_arguments(item : Map[String, Json]) -> String {
  match item.get("arguments") {
    Some(String(args)) => args
    Some(value) => canonicalize_tool_arguments(Some(value))
    None =>
      match item.get("input") {
        Some(String(text)) =>
          Json::object({ "input": Json::string(text) }).stringify()
        Some(value) => canonicalize_tool_arguments(Some(value))
        None => "{}"
      }
  }
}

///|
fn openai_chat_tool_message_from_codex_output(item : Map[String, Json]) -> Json {
  Json::object({
    "role": Json::string("tool"),
    "tool_call_id": Json::string(
      codex_chat_response_item_call_id(Json::object(item)).unwrap_or(""),
    ),
    "content": Json::string(codex_responses_tool_output_text(item)),
  })
}

///|
fn codex_responses_tool_output_text(item : Map[String, Json]) -> String {
  match item.get("output") {
    Some(String(text)) => text
    Some(value) => value.stringify()
    None =>
      match item.get("content") {
        Some(String(text)) => text
        Some(value) => value.stringify()
        None => ""
      }
  }
}

///|
fn append_codex_responses_tools_as_openai_chat_tools(
  source : Map[String, Json],
  target : Map[String, Json],
) -> Unit {
  guard source.get("tools") is Some(Array(tools)) else { return }
  let converted : Array[Json] = []
  for tool in tools {
    guard tool is Object(tool_obj) else { continue }
    let name = json_string_from_map(tool_obj, "name").unwrap_or("")
    if name.trim().is_empty() {
      continue
    }
    converted.push(
      Json::object({
        "type": Json::string("function"),
        "function": Json::object({
          "name": Json::string(name),
          "description": tool_obj.get("description").unwrap_or(Json::string("")),
          "parameters": tool_obj
          .get("parameters")
          .unwrap_or(tool_obj.get("input_schema").unwrap_or(Json::object({}))),
        }),
      }),
    )
  }
  if !converted.is_empty() {
    target["tools"] = Json::array(converted)
  }
}

///|
fn codex_tool_choice_to_openai_chat(choice : Json) -> Json {
  match choice {
    String("auto") | String("none") | String("required") => choice
    Object(obj) =>
      if obj.get("type") is Some(String("function")) ||
        obj.get("type") is Some(String("tool")) {
        Json::object({
          "type": Json::string("function"),
          "function": Json::object({
            "name": Json::string(
              json_string_from_map(obj, "name").unwrap_or(""),
            ),
          }),
        })
      } else {
        Json::object(obj)
      }
    _ => choice
  }
}

///|
fn openai_chat_completion_to_codex_response(
  body : Json,
  fallback_model : String,
) -> Json {
  let response_id = openai_chat_completion_id(body).unwrap_or(
    generate_chat_completion_id(),
  )
  let output : Array[Json] = []
  let mut model = fallback_model
  guard body is Object(obj) else {
    return codex_response_from_output(
      response_id,
      model,
      output,
      Json::object({}),
    )
  }
  model = json_string_from_map(obj, "model").unwrap_or(model)
  if obj.get("choices") is Some(Array(choices)) &&
    choices.get(0) is Some(Object(choice)) &&
    choice.get("message") is Some(Object(message)) {
    append_openai_chat_message_as_codex_output(message, output)
  }
  codex_response_from_output(
    response_id,
    model,
    output,
    openai_chat_usage_to_codex_usage(obj.get("usage")),
  )
}

///|
fn append_openai_chat_message_as_codex_output(
  message : Map[String, Json],
  output : Array[Json],
) -> Unit {
  match json_string_from_map(message, "content") {
    Some(text) if !text.is_empty() =>
      output.push(
        Json::object({
          "type": Json::string("message"),
          "role": Json::string("assistant"),
          "content": Json::array([
            Json::object({
              "type": Json::string("output_text"),
              "text": Json::string(text),
            }),
          ]),
        }),
      )
    _ => ()
  }
  if message.get("tool_calls") is Some(Array(tool_calls)) {
    for tool_call in tool_calls {
      guard tool_call is Object(tool_call_obj) else { continue }
      output.push(codex_function_call_from_openai_tool_call(tool_call_obj))
    }
  }
}

///|
fn codex_function_call_from_openai_tool_call(
  tool_call : Map[String, Json],
) -> Json {
  let function = match tool_call.get("function") {
    Some(Object(function)) => function
    _ => {}
  }
  let item : Map[String, Json] = {
    "type": Json::string("function_call"),
    "call_id": Json::string(
      json_string_from_map(tool_call, "id").unwrap_or(
        generate_chat_completion_id(),
      ),
    ),
    "name": Json::string(
      json_string_from_map(function, "name").unwrap_or("tool"),
    ),
    "arguments": Json::string(
      canonicalize_tool_arguments(function.get("arguments")),
    ),
  }
  match json_string_from_map(tool_call, "reasoning_content") {
    Some(reasoning) if !reasoning.is_empty() =>
      item["reasoning_content"] = Json::string(reasoning)
    _ => ()
  }
  Json::object(item)
}

///|
fn codex_response_from_output(
  id : String,
  model : String,
  output : Array[Json],
  usage : Json,
) -> Json {
  Json::object({
    "id": Json::string(id),
    "object": Json::string("response"),
    "status": Json::string("completed"),
    "model": Json::string(model),
    "output": Json::array(output),
    "usage": usage,
  })
}

///|
fn openai_chat_usage_to_codex_usage(usage : Json?) -> Json {
  guard usage is Some(Object(obj)) else {
    return Json::object({
      "input_tokens": Json::number(0.0),
      "output_tokens": Json::number(0.0),
    })
  }
  let input_tokens = json_int(obj, "prompt_tokens").unwrap_or(0)
  let output_tokens = json_int(obj, "completion_tokens").unwrap_or(0)
  let cached_tokens = match obj.get("prompt_tokens_details") {
    Some(Object(details)) => json_int(details, "cached_tokens").unwrap_or(0)
    _ => 0
  }
  Json::object({
    "input_tokens": Json::number(input_tokens.to_double()),
    "output_tokens": Json::number(output_tokens.to_double()),
    "input_tokens_details": Json::object({
      "cached_tokens": Json::number(cached_tokens.to_double()),
    }),
  })
}

///|
fn append_chat_message_as_response_item(
  message : Json,
  input_items : Array[Json],
  instructions : Array[String],
) -> Unit {
  guard message is Object(obj) else { return }
  let role = match obj.get("role") {
    Some(String(role)) => role
    _ => "user"
  }
  if role == "system" || role == "developer" {
    let text = chat_content_to_text(
      obj.get("content").unwrap_or(Json::string("")),
    )
    if !text.trim().is_empty() {
      instructions.push(text)
    }
    return
  }
  if role == "tool" {
    let item : Map[String, Json] = {
      "type": Json::string("function_call_output"),
      "call_id": Json::string(
        json_string_from_map(obj, "tool_call_id").unwrap_or(""),
      ),
      "output": Json::string(
        chat_content_to_text(obj.get("content").unwrap_or(Json::string(""))),
      ),
    }
    input_items.push(Json::object(item))
    return
  }
  let response_role = if role == "assistant" { "assistant" } else { "user" }
  let content = chat_content_to_text(
    obj.get("content").unwrap_or(Json::string("")),
  )
  if !content.trim().is_empty() || role != "assistant" {
    input_items.push(
      Json::object({
        "role": Json::string(response_role),
        "content": Json::string(content),
      }),
    )
  }
  if obj.get("tool_calls") is Some(Array(tool_calls)) {
    for tool_call in tool_calls {
      if openai_tool_call_to_response_item(tool_call) is Some(item) {
        input_items.push(item)
      }
    }
  }
}

///|
fn chat_content_to_text(content : Json) -> String {
  match content {
    String(text) => text
    Array(parts) => {
      let texts : Array[String] = []
      for part in parts {
        match part {
          String(text) => texts.push(text)
          Object(obj) =>
            if obj.get("text") is Some(String(text)) {
              texts.push(text)
            } else if obj.get("type") is Some(String("text")) &&
              obj.get("content") is Some(String(text)) {
              texts.push(text)
            }
          _ => ()
        }
      }
      texts.join("\n")
    }
    _ => ""
  }
}

///|
fn openai_tool_to_codex_tool(tool : Json) -> Json? {
  guard tool is Object(obj) else { return None }
  if obj.get("type") is Some(String("function")) &&
    obj.get("function") is Some(Object(function)) {
    let name = json_string_from_map(function, "name").unwrap_or("")
    if name.trim().is_empty() {
      return None
    }
    let result : Map[String, Json] = {
      "type": Json::string("function"),
      "name": Json::string(name),
      "parameters": function.get("parameters").unwrap_or(Json::object({})),
    }
    if function.get("description") is Some(String(description)) {
      result["description"] = Json::string(description)
    }
    return Some(Json::object(result))
  }
  if obj.get("name") is Some(String(_)) {
    return Some(tool)
  }
  None
}

///|
fn openai_tool_choice_to_codex(choice : Json) -> Json {
  match choice {
    String("auto") | String("none") | String("required") => choice
    Object(obj) =>
      if obj.get("type") is Some(String("function")) &&
        obj.get("function") is Some(Object(function)) {
        Json::object({
          "type": Json::string("function"),
          "name": Json::string(
            json_string_from_map(function, "name").unwrap_or(""),
          ),
        })
      } else {
        Json::object(obj)
      }
    _ => choice
  }
}

///|
fn openai_tool_call_to_response_item(tool_call : Json) -> Json? {
  guard tool_call is Object(obj) else { return None }
  guard obj.get("function") is Some(Object(function)) else { return None }
  let name = json_string_from_map(function, "name").unwrap_or("")
  if name.trim().is_empty() {
    return None
  }
  let call_id = json_string_from_map(obj, "id").unwrap_or(
    generate_chat_completion_id(),
  )
  Some(
    Json::object({
      "type": Json::string("function_call"),
      "call_id": Json::string(call_id),
      "name": Json::string(name),
      "arguments": Json::string(
        canonicalize_tool_arguments(function.get("arguments")),
      ),
    }),
  )
}

///|
fn codex_response_to_openai_chat_completion(
  body : Json,
  model : String,
) -> Json {
  let output = extract_chat_completion_output(body)
  let usage = token_usage_from_codex_response_auto(body).unwrap_or(
    TokenUsage::empty(),
  )
  let message : Map[String, Json] = { "role": Json::string("assistant") }
  if output.tool_calls.is_empty() {
    message["content"] = Json::string(output.content)
  } else {
    message["content"] = Json::null()
    message["tool_calls"] = Json::array(output.tool_calls)
  }
  let finish_reason = if output.tool_calls.is_empty() {
    "stop"
  } else {
    "tool_calls"
  }
  Json::object({
    "id": Json::string(
      codex_response_id(body).unwrap_or(generate_chat_completion_id()),
    ),
    "object": Json::string("chat.completion"),
    "created": Json::number((@async.now().to_int() / 1000).to_double()),
    "model": Json::string(model),
    "choices": Json::array([
      Json::object({
        "index": Json::number(0.0),
        "message": Json::object(message),
        "finish_reason": Json::string(finish_reason),
      }),
    ]),
    "usage": openai_usage_json(usage),
  })
}

///|
fn openai_chat_role_chunk(id : String, model : String, created : Int) -> Json {
  Json::object({
    "id": Json::string(id),
    "object": Json::string("chat.completion.chunk"),
    "created": Json::number(created.to_double()),
    "model": Json::string(model),
    "choices": Json::array([
      Json::object({
        "index": Json::number(0.0),
        "delta": Json::object({ "role": Json::string("assistant") }),
        "finish_reason": Json::null(),
      }),
    ]),
  })
}

///|
fn codex_stream_event_to_openai_chat_chunk(
  data : String,
  id : String,
  model : String,
  created : Int,
) -> Json? {
  let parsed = @json.parse(data) catch { _ => return None }
  guard parsed is Object(obj) else { return None }
  match obj.get("type") {
    Some(String("response.output_text.delta")) => {
      let delta = json_string_from_map(obj, "delta").unwrap_or("")
      Some(
        openai_chat_delta_chunk(
          id,
          model,
          created,
          { "content": Json::string(delta) },
          Json::null(),
        ),
      )
    }
    Some(String("response.output_item.done")) =>
      match obj.get("item") {
        Some(Object(item)) =>
          if item.get("type") is Some(String("function_call")) {
            Some(
              openai_chat_delta_chunk(
                id,
                model,
                created,
                {
                  "tool_calls": Json::array([
                    openai_tool_call_delta_from_response_item(item),
                  ]),
                },
                Json::null(),
              ),
            )
          } else {
            None
          }
        _ => None
      }
    Some(String("response.completed")) =>
      Some(
        openai_chat_delta_chunk(id, model, created, {}, Json::string("stop")),
      )
    _ => None
  }
}

///|
priv struct ChatToCodexResponsesToolState {
  mut output_index : Int?
  mut item_id : String
  mut call_id : String
  mut name : String
  mut arguments : String
  mut added : Bool
  mut done : Bool
}

///|
priv struct ChatToCodexResponsesStreamState {
  mut response_started : Bool
  mut completed : Bool
  mut response_id : String
  mut model : String
  mut created_at : Int
  mut next_output_index : Int
  mut text_output_index : Int?
  mut text_item_id : String
  mut text : String
  mut text_added : Bool
  mut text_done : Bool
  tool_states : Map[Int, ChatToCodexResponsesToolState]
  output_items : Array[Json]
  mut latest_usage : Json?
  mut finish_reason : String?
}

///|
fn ChatToCodexResponsesStreamState::new(
  model : String,
) -> ChatToCodexResponsesStreamState {
  {
    response_started: false,
    completed: false,
    response_id: "resp_moonstat",
    model,
    created_at: @async.now().to_int() / 1000,
    next_output_index: 0,
    text_output_index: None,
    text_item_id: "",
    text: "",
    text_added: false,
    text_done: false,
    tool_states: Map([], capacity=0),
    output_items: [],
    latest_usage: None,
    finish_reason: None,
  }
}

///|
fn openai_chat_stream_data_to_codex_response_events(
  data : String,
  state : ChatToCodexResponsesStreamState,
) -> (Bool, Json?, Array[Json]) {
  if data.trim() == "[DONE]" {
    return (true, None, state.finish())
  }
  let parsed = @json.parse(data) catch { _ => return (false, None, []) }
  (false, Some(parsed), state.push_chunk(parsed))
}

///|
fn ChatToCodexResponsesStreamState::push_chunk(
  self : ChatToCodexResponsesStreamState,
  chunk : Json,
) -> Array[Json] {
  let events : Array[Json] = []
  guard chunk is Object(obj) else { return events }
  if json_string_from_map(obj, "id") is Some(id) {
    self.response_id = codex_response_id_from_chat_id(id)
  }
  if json_string_from_map(obj, "model") is Some(model) && !model.is_empty() {
    self.model = model
  }
  if json_int(obj, "created") is Some(created) {
    self.created_at = created
  }
  events.append(self.ensure_response_started())
  if obj.get("usage") is Some(Object(usage)) {
    self.latest_usage = Some(
      openai_chat_usage_to_codex_usage(Some(Json::object(usage))),
    )
  }
  guard obj.get("choices") is Some(Array(choices)) else { return events }
  guard choices.get(0) is Some(Object(choice)) else { return events }
  if choice.get("delta") is Some(Object(delta)) {
    if json_string_from_map(delta, "content") is Some(content) &&
      !content.is_empty() {
      events.append(self.push_text_delta(content))
    }
    if json_string_from_map(delta, "refusal") is Some(refusal) &&
      !refusal.is_empty() {
      events.append(self.push_text_delta(refusal))
    }
    if delta.get("tool_calls") is Some(Array(tool_calls)) {
      events.append(self.finish_text())
      for tool_call in tool_calls {
        if tool_call is Object(tool_call_obj) {
          events.append(self.push_tool_call_delta(tool_call_obj))
        }
      }
    }
  }
  if json_string_from_map(choice, "finish_reason") is Some(reason) {
    self.finish_reason = Some(reason)
  }
  events
}

///|
fn ChatToCodexResponsesStreamState::ensure_response_started(
  self : ChatToCodexResponsesStreamState,
) -> Array[Json] {
  if self.response_started {
    return []
  }
  self.response_started = true
  [
    Json::object({
      "type": Json::string("response.created"),
      "response": self.base_response("in_progress"),
    }),
    Json::object({
      "type": Json::string("response.in_progress"),
      "response": self.base_response("in_progress"),
    }),
  ]
}

///|
fn ChatToCodexResponsesStreamState::push_text_delta(
  self : ChatToCodexResponsesStreamState,
  delta : String,
) -> Array[Json] {
  let events : Array[Json] = []
  if !self.text_added {
    let output_index = self.next_output_index()
    let item_id = "\{self.response_id}_msg"
    self.text_output_index = Some(output_index)
    self.text_item_id = item_id
    self.text_added = true
    events.push(
      Json::object({
        "type": Json::string("response.output_item.added"),
        "output_index": Json::number(output_index.to_double()),
        "item": Json::object({
          "id": Json::string(item_id),
          "type": Json::string("message"),
          "status": Json::string("in_progress"),
          "role": Json::string("assistant"),
          "content": Json::array([]),
        }),
      }),
    )
    events.push(
      Json::object({
        "type": Json::string("response.content_part.added"),
        "item_id": Json::string(self.text_item_id),
        "output_index": Json::number(output_index.to_double()),
        "content_index": Json::number(0.0),
        "part": Json::object({
          "type": Json::string("output_text"),
          "text": Json::string(""),
          "annotations": Json::array([]),
        }),
      }),
    )
  }
  self.text += delta
  let output_index = self.text_output_index.unwrap_or(0)
  events.push(
    Json::object({
      "type": Json::string("response.output_text.delta"),
      "item_id": Json::string(self.text_item_id),
      "output_index": Json::number(output_index.to_double()),
      "content_index": Json::number(0.0),
      "delta": Json::string(delta),
    }),
  )
  events
}

///|
fn ChatToCodexResponsesStreamState::push_tool_call_delta(
  self : ChatToCodexResponsesStreamState,
  tool_call : Map[String, Json],
) -> Array[Json] {
  let events : Array[Json] = []
  let chat_index = json_int(tool_call, "index").unwrap_or(0)
  let state = match self.tool_states.get(chat_index) {
    Some(existing) => existing
    None => {
      let created = {
        output_index: None,
        item_id: "",
        call_id: "",
        name: "",
        arguments: "",
        added: false,
        done: false,
      }
      self.tool_states.set(chat_index, created)
      created
    }
  }
  if json_string_from_map(tool_call, "id") is Some(id) && !id.is_empty() {
    state.call_id = id
  }
  if tool_call.get("function") is Some(Object(function)) {
    if json_string_from_map(function, "name") is Some(name) && !name.is_empty() {
      state.name = name
    }
    if json_string_from_map(function, "arguments") is Some(arguments) &&
      !arguments.is_empty() {
      state.arguments += arguments
    }
  }
  if !state.added && (!state.call_id.is_empty() || !state.name.is_empty()) {
    let output_index = self.next_output_index()
    state.added = true
    state.output_index = Some(output_index)
    if state.call_id.is_empty() {
      state.call_id = "call_\{chat_index}"
    }
    if state.name.is_empty() {
      state.name = "tool"
    }
    state.item_id = "fc_\{state.call_id}"
    events.push(
      Json::object({
        "type": Json::string("response.output_item.added"),
        "output_index": Json::number(output_index.to_double()),
        "item": Json::object({
          "id": Json::string(state.item_id),
          "type": Json::string("function_call"),
          "status": Json::string("in_progress"),
          "call_id": Json::string(state.call_id),
          "name": Json::string(state.name),
          "arguments": Json::string(""),
        }),
      }),
    )
    if !state.arguments.is_empty() {
      events.push(
        Json::object({
          "type": Json::string("response.function_call_arguments.delta"),
          "item_id": Json::string(state.item_id),
          "output_index": Json::number(output_index.to_double()),
          "delta": Json::string(state.arguments),
        }),
      )
    }
  } else if state.added &&
    tool_call.get("function") is Some(Object(function)) &&
    json_string_from_map(function, "arguments") is Some(arguments) &&
    !arguments.is_empty() {
    let output_index = state.output_index.unwrap_or(0)
    events.push(
      Json::object({
        "type": Json::string("response.function_call_arguments.delta"),
        "item_id": Json::string(state.item_id),
        "output_index": Json::number(output_index.to_double()),
        "delta": Json::string(arguments),
      }),
    )
  }
  events
}

///|
fn ChatToCodexResponsesStreamState::finish(
  self : ChatToCodexResponsesStreamState,
) -> Array[Json] {
  if self.completed {
    return []
  }
  let events : Array[Json] = []
  events.append(self.ensure_response_started())
  events.append(self.finish_text())
  events.append(self.finish_tools())
  events.push(
    Json::object({
      "type": Json::string("response.completed"),
      "response": self.base_response(
        codex_response_status_from_chat_finish_reason(self.finish_reason),
      ),
    }),
  )
  self.completed = true
  events
}

///|
fn ChatToCodexResponsesStreamState::finish_text(
  self : ChatToCodexResponsesStreamState,
) -> Array[Json] {
  if !self.text_added || self.text_done {
    return []
  }
  let output_index = self.text_output_index.unwrap_or(0)
  let part = Json::object({
    "type": Json::string("output_text"),
    "text": Json::string(self.text),
    "annotations": Json::array([]),
  })
  let item = Json::object({
    "id": Json::string(self.text_item_id),
    "type": Json::string("message"),
    "status": Json::string("completed"),
    "role": Json::string("assistant"),
    "content": Json::array([part]),
  })
  self.output_items.push(item)
  self.text_done = true
  [
    Json::object({
      "type": Json::string("response.output_text.done"),
      "item_id": Json::string(self.text_item_id),
      "output_index": Json::number(output_index.to_double()),
      "content_index": Json::number(0.0),
      "text": Json::string(self.text),
    }),
    Json::object({
      "type": Json::string("response.content_part.done"),
      "item_id": Json::string(self.text_item_id),
      "output_index": Json::number(output_index.to_double()),
      "content_index": Json::number(0.0),
      "part": part,
    }),
    Json::object({
      "type": Json::string("response.output_item.done"),
      "output_index": Json::number(output_index.to_double()),
      "item": item,
    }),
  ]
}

///|
fn ChatToCodexResponsesStreamState::finish_tools(
  self : ChatToCodexResponsesStreamState,
) -> Array[Json] {
  let events : Array[Json] = []
  for _, state in self.tool_states {
    if !state.added || state.done {
      continue
    }
    let output_index = state.output_index.unwrap_or(0)
    let arguments = canonicalize_tool_arguments(
      Some(Json::string(state.arguments)),
    )
    let item = Json::object({
      "id": Json::string(state.item_id),
      "type": Json::string("function_call"),
      "status": Json::string("completed"),
      "call_id": Json::string(state.call_id),
      "name": Json::string(state.name),
      "arguments": Json::string(arguments),
    })
    self.output_items.push(item)
    state.done = true
    events.push(
      Json::object({
        "type": Json::string("response.function_call_arguments.done"),
        "item_id": Json::string(state.item_id),
        "output_index": Json::number(output_index.to_double()),
        "arguments": Json::string(arguments),
      }),
    )
    events.push(
      Json::object({
        "type": Json::string("response.output_item.done"),
        "output_index": Json::number(output_index.to_double()),
        "item": item,
      }),
    )
  }
  events
}

///|
fn ChatToCodexResponsesStreamState::next_output_index(
  self : ChatToCodexResponsesStreamState,
) -> Int {
  let index = self.next_output_index
  self.next_output_index += 1
  index
}

///|
fn ChatToCodexResponsesStreamState::base_response(
  self : ChatToCodexResponsesStreamState,
  status : String,
) -> Json {
  let response : Map[String, Json] = {
    "id": Json::string(self.response_id),
    "object": Json::string("response"),
    "created_at": Json::number(self.created_at.to_double()),
    "status": Json::string(status),
    "model": Json::string(self.model),
    "output": Json::array(self.output_items.copy()),
    "usage": self.latest_usage.unwrap_or(
      Json::object({
        "input_tokens": Json::number(0.0),
        "output_tokens": Json::number(0.0),
      }),
    ),
  }
  if status == "incomplete" {
    response["incomplete_details"] = Json::object({
      "reason": Json::string("max_output_tokens"),
    })
  }
  Json::object(response)
}

///|
fn codex_response_id_from_chat_id(id : String) -> String {
  if id.has_prefix("resp_") {
    id
  } else {
    "resp_\{id}"
  }
}

///|
fn codex_response_status_from_chat_finish_reason(reason : String?) -> String {
  match reason {
    Some("length") => "incomplete"
    _ => "completed"
  }
}

///|
fn openai_chat_delta_chunk(
  id : String,
  model : String,
  created : Int,
  delta : Map[String, Json],
  finish_reason : Json,
) -> Json {
  Json::object({
    "id": Json::string(id),
    "object": Json::string("chat.completion.chunk"),
    "created": Json::number(created.to_double()),
    "model": Json::string(model),
    "choices": Json::array([
      Json::object({
        "index": Json::number(0.0),
        "delta": Json::object(delta),
        "finish_reason": finish_reason,
      }),
    ]),
  })
}

///|
fn extract_chat_completion_output(body : Json) -> ChatCompletionOutput {
  let mut content = ""
  let tool_calls : Array[Json] = []
  guard body is Object(obj) else { return { content, tool_calls } }
  if obj.get("output_text") is Some(String(text)) {
    content = text
  }
  if obj.get("output") is Some(Array(outputs)) {
    for output in outputs {
      guard output is Object(item) else { continue }
      match item.get("type") {
        Some(String("message")) =>
          content += extract_response_message_text(item)
        Some(String("function_call")) =>
          tool_calls.push(openai_tool_call_from_response_item(item))
        _ => ()
      }
    }
  }
  { content, tool_calls }
}

///|
fn extract_response_message_text(item : Map[String, Json]) -> String {
  let texts : Array[String] = []
  if item.get("content") is Some(Array(parts)) {
    for part in parts {
      guard part is Object(part_obj) else { continue }
      if part_obj.get("type") is Some(String("output_text")) &&
        part_obj.get("text") is Some(String(text)) {
        texts.push(text)
      }
    }
  }
  texts.join("")
}

///|
fn openai_tool_call_from_response_item(item : Map[String, Json]) -> Json {
  Json::object({
    "id": Json::string(
      json_string_from_map(item, "call_id").unwrap_or(
        generate_chat_completion_id(),
      ),
    ),
    "type": Json::string("function"),
    "function": Json::object({
      "name": Json::string(
        json_string_from_map(item, "name").unwrap_or("unknown"),
      ),
      "arguments": Json::string(
        canonicalize_tool_arguments(item.get("arguments")),
      ),
    }),
  })
}

///|
fn openai_tool_call_delta_from_response_item(item : Map[String, Json]) -> Json {
  Json::object({
    "index": Json::number(0.0),
    "id": Json::string(
      json_string_from_map(item, "call_id").unwrap_or(
        generate_chat_completion_id(),
      ),
    ),
    "type": Json::string("function"),
    "function": Json::object({
      "name": Json::string(
        json_string_from_map(item, "name").unwrap_or("unknown"),
      ),
      "arguments": Json::string(
        canonicalize_tool_arguments(item.get("arguments")),
      ),
    }),
  })
}

///|
fn openai_usage_json(usage : TokenUsage) -> Json {
  Json::object({
    "prompt_tokens": Json::number(usage.input_tokens.to_double()),
    "completion_tokens": Json::number(usage.output_tokens.to_double()),
    "total_tokens": Json::number(
      (usage.input_tokens + usage.output_tokens).to_double(),
    ),
    "prompt_tokens_details": Json::object({
      "cached_tokens": Json::number(usage.cache_read_tokens.to_double()),
    }),
  })
}

///|
fn codex_response_id(body : Json) -> String? {
  guard body is Object(obj) else { return None }
  json_string_from_map(obj, "id")
}

///|
fn json_bool_from_map(obj : Map[String, Json], key : String) -> Bool? {
  match obj.get(key) {
    Some(true) => Some(true)
    Some(false) => Some(false)
    _ => None
  }
}

///|
fn json_string_from_map(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn generate_chat_completion_id() -> String {
  let gen = @uuid.generator(@random.Rand::new())
  let uuid = gen.v4()
  "chatcmpl_\{uuid}"
}
