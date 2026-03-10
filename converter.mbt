///|
pub struct CodexInput {
  messages : Array[CodexMessage]
  tools : Array[CodexTool]?
}

///|
pub struct CodexMessage {
  role : String
  content : String
  tool_call_id : String?
  name : String?
  arguments : String?
}

///|
pub impl ToJson for CodexMessage with to_json(self : CodexMessage) -> Json {
  let json : Map[String, Json] = {
    "role": Json::string(self.role),
    "content": Json::string(self.content),
  }
  if self.tool_call_id is Some(id) {
    json["tool_call_id"] = Json::string(id)
  }
  if self.name is Some(name) {
    json["name"] = Json::string(name)
  }
  if self.arguments is Some(args) {
    json["arguments"] = Json::string(args)
  }
  Json::object(json)
}

///|
pub struct CodexTool {
  type_ : String
  name : String
  description : String?
  parameters : Json
}

///|
pub impl ToJson for CodexTool with to_json(self : CodexTool) -> Json {
  let json : Map[String, Json] = {
    "type": Json::string(self.type_),
    "name": Json::string(self.name),
    "parameters": self.parameters,
  }
  if self.description is Some(desc) {
    json["description"] = Json::string(desc)
  }
  Json::object(json)
}

///|
pub fn convert_anthropic_to_codex(
  request : AnthropicRequest,
  _model : String,
) -> CodexInput {
  let messages : Array[CodexMessage] = []
  if request.system is Some(system) && !system.is_empty() {
    messages.push({
      role: "system",
      content: system,
      tool_call_id: None,
      name: None,
      arguments: None,
    })
  }
  for msg in request.messages {
    let content_str = extract_text_content(msg.content)
    match msg.role {
      "user" =>
        if content_str.contains("tool_use_id") {
          let tool_msg = parse_tool_result(content_str)
          messages.push({
            role: "tool",
            content: tool_msg.content,
            tool_call_id: Some(tool_msg.tool_use_id),
            name: None,
            arguments: None,
          })
        } else {
          messages.push({
            role: "user",
            content: content_str,
            tool_call_id: None,
            name: None,
            arguments: None,
          })
        }
      "assistant" => {
        let tool_calls = extract_tool_calls(msg.content)
        if tool_calls.is_empty() {
          messages.push({
            role: "assistant",
            content: content_str,
            tool_call_id: None,
            name: None,
            arguments: None,
          })
        } else {
          for tc in tool_calls {
            messages.push({
              role: "assistant",
              content: "",
              tool_call_id: None,
              name: Some(tc.name),
              arguments: Some(tc.arguments),
            })
          }
        }
      }
      _ =>
        messages.push({
          role: msg.role,
          content: content_str,
          tool_call_id: None,
          name: None,
          arguments: None,
        })
    }
  }
  let tools : Array[CodexTool]? = match request.tools {
    Some(ts) if !ts.is_empty() =>
      Some(
        ts
        .iter()
        .map(fn(t) {
          {
            type_: "function",
            name: t.name,
            description: t.description,
            parameters: t.input_schema,
          }
        })
        .collect(),
      )
    _ => None
  }
  { messages, tools }
}

///|
fn extract_text_content(content : AnthropicContent) -> String {
  match content {
    Text(t) => t
    Blocks(blocks) => {
      let texts : Array[String] = []
      for block in blocks {
        if block.text is Some(text) {
          texts.push(text)
        }
      }
      texts.join("\n")
    }
  }
}

///|
priv struct ToolCall {
  name : String
  arguments : String
}

///|
priv struct ToolResult {
  tool_use_id : String
  content : String
}

///|
fn extract_tool_calls(content : AnthropicContent) -> Array[ToolCall] {
  let result : Array[ToolCall] = []
  match content {
    Blocks(blocks) =>
      for block in blocks {
        if block.type_ == "tool_use" {
          let name = match block.text {
            Some(n) => n
            None => continue
          }
          result.push({ name, arguments: "{}" })
        }
      }
    _ => ()
  }
  result
}

///|
fn parse_tool_result(content : String) -> ToolResult {
  let json_result : Result[Json, Error] = try? @json.parse(content)
  let tool_use_id = match json_result {
    Ok(Object(obj)) =>
      match obj.get("tool_use_id") {
        Some(String(s)) => s
        _ => "unknown"
      }
    _ => "unknown"
  }
  { tool_use_id, content }
}

///|
pub fn build_codex_request(
  input : CodexInput,
  model : String,
  stream : Bool,
) -> Json {
  let json : Map[String, Json] = {
    "model": Json::string(model),
    "input": input.messages.to_json(),
    "stream": stream.to_json(),
    "store": Json::boolean(false),
  }
  if input.tools is Some(tools) && !tools.is_empty() {
    json["tools"] = tools.to_json()
  }
  Json::object(json)
}

///|
pub fn build_anthropic_response(
  id : String,
  model : String,
  content : String,
  tool_calls : Array[ToolCallInfo],
  input_tokens : Int,
  output_tokens : Int,
) -> AnthropicResponse {
  let response_blocks : Array[AnthropicResponseBlock] = []
  if !content.is_empty() {
    response_blocks.push({
      type_: "text",
      text: Some(content),
      name: None,
      input: None,
      id: None,
    })
  }
  for tc in tool_calls {
    let args_json_result : Result[Json, Error] = try? @json.parse(tc.arguments)
    let args_json = match args_json_result {
      Ok(j) => j
      Err(_) => Json::object({})
    }
    response_blocks.push({
      type_: "tool_use",
      text: None,
      name: Some(tc.name),
      input: Some(args_json),
      id: Some(tc.id),
    })
  }
  let stop_reason = if tool_calls.is_empty() { "end_turn" } else { "tool_use" }
  {
    id,
    type_: "message",
    role: "assistant",
    content: response_blocks,
    model,
    stop_reason: Some(stop_reason),
    stop_sequence: None,
    usage: { input_tokens, output_tokens },
  }
}

///|
pub struct ToolCallInfo {
  id : String
  name : String
  arguments : String
}
