///|
pub struct AnthropicRequest {
  model : String
  max_tokens : Int
  messages : Array[AnthropicMessage]
  system : String?
  tools : Array[AnthropicTool]?
  stream : Bool?
}

///|
pub impl ToJson for AnthropicRequest with fn to_json(self : AnthropicRequest) -> Json {
  let json : Map[String, Json] = {
    "model": Json::string(self.model),
    "max_tokens": self.max_tokens.to_json(),
    "messages": self.messages.to_json(),
  }
  if self.system is Some(system) {
    json["system"] = Json::string(system)
  }
  if self.tools is Some(tools) && !tools.is_empty() {
    json["tools"] = tools.to_json()
  }
  if self.stream is Some(stream) {
    json["stream"] = stream.to_json()
  }
  Json::object(json)
}

///|
pub impl FromJson for AnthropicRequest with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> AnthropicRequest raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise JsonDecodeError((path, "AnthropicRequest: expected object"))
  }
  let model : String = match obj.get("model") {
    Some(String(s)) => s
    _ => raise JsonDecodeError((path, "AnthropicRequest: missing 'model'"))
  }
  let max_tokens : Int = match obj.get("max_tokens") {
    Some(Number(n, ..)) => n.trunc().to_int()
    _ => 4096
  }
  let messages : Array[AnthropicMessage] = match obj.get("messages") {
    Some(Array(arr)) => {
      let result : Array[AnthropicMessage] = []
      for m in arr {
        result.push(@json.from_json(m))
      }
      result
    }
    _ => raise JsonDecodeError((path, "AnthropicRequest: missing 'messages'"))
  }
  let system : String? = match obj.get("system") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let tools : Array[AnthropicTool]? = match obj.get("tools") {
    Some(Array(arr)) => {
      let result : Array[AnthropicTool] = []
      for t in arr {
        result.push(@json.from_json(t))
      }
      Some(result)
    }
    _ => None
  }
  let stream : Bool? = match obj.get("stream") {
    Some(true) => Some(true)
    Some(false) => Some(false)
    _ => None
  }
  { model, max_tokens, messages, system, tools, stream }
}

///|
pub struct AnthropicMessage {
  role : String
  content : AnthropicContent
}

///|
pub impl ToJson for AnthropicMessage with fn to_json(self : AnthropicMessage) -> Json {
  let json : Map[String, Json] = { "role": Json::string(self.role) }
  match self.content {
    Text(t) => json["content"] = Json::string(t)
    Blocks(blocks) => json["content"] = blocks.to_json()
  }
  Json::object(json)
}

///|
pub impl FromJson for AnthropicMessage with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> AnthropicMessage raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise JsonDecodeError((path, "AnthropicMessage: expected object"))
  }
  let role : String = match obj.get("role") {
    Some(String(s)) => s
    _ => raise JsonDecodeError((path, "AnthropicMessage: missing 'role'"))
  }
  let content : AnthropicContent = match obj.get("content") {
    Some(String(s)) => Text(s)
    Some(Array(arr)) => {
      let result : Array[AnthropicBlock] = []
      for b in arr {
        result.push(@json.from_json(b))
      }
      Blocks(result)
    }
    _ => raise JsonDecodeError((path, "AnthropicMessage: missing 'content'"))
  }
  { role, content }
}

///|
pub enum AnthropicContent {
  Text(String)
  Blocks(Array[AnthropicBlock])
}

///|
pub struct AnthropicBlock {
  type_ : String
  text : String?
  tool_use_id : String?
  content : String?
}

///|
pub impl ToJson for AnthropicBlock with fn to_json(self : AnthropicBlock) -> Json {
  let json : Map[String, Json] = { "type": Json::string(self.type_) }
  if self.text is Some(text) {
    json["text"] = Json::string(text)
  }
  if self.tool_use_id is Some(id) {
    json["tool_use_id"] = Json::string(id)
  }
  if self.content is Some(content) {
    json["content"] = Json::string(content)
  }
  Json::object(json)
}

///|
pub impl FromJson for AnthropicBlock with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> AnthropicBlock raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise JsonDecodeError((path, "AnthropicBlock: expected object"))
  }
  let type_ : String = match obj.get("type") {
    Some(String(s)) => s
    _ => raise JsonDecodeError((path, "AnthropicBlock: missing 'type'"))
  }
  let text : String? = match obj.get("text") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let tool_use_id : String? = match obj.get("tool_use_id") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let content : String? = match obj.get("content") {
    Some(String(s)) => Some(s)
    _ => None
  }
  { type_, text, tool_use_id, content }
}

///|
pub struct AnthropicTool {
  name : String
  description : String?
  input_schema : Json
}

///|
pub impl ToJson for AnthropicTool with fn to_json(self : AnthropicTool) -> Json {
  let json : Map[String, Json] = {
    "name": Json::string(self.name),
    "input_schema": self.input_schema,
  }
  if self.description is Some(desc) {
    json["description"] = Json::string(desc)
  }
  Json::object(json)
}

///|
pub impl FromJson for AnthropicTool with fn from_json(
  json : Json,
  path : @json.JsonPath,
) -> AnthropicTool raise @json.JsonDecodeError {
  guard json is Object(obj) else {
    raise JsonDecodeError((path, "AnthropicTool: expected object"))
  }
  let name : String = match obj.get("name") {
    Some(String(s)) => s
    _ => raise JsonDecodeError((path, "AnthropicTool: missing 'name'"))
  }
  let description : String? = match obj.get("description") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let input_schema : Json = match obj.get("input_schema") {
    Some(schema) => schema
    _ => raise JsonDecodeError((path, "AnthropicTool: missing 'input_schema'"))
  }
  { name, description, input_schema }
}

///|
pub struct AnthropicResponse {
  id : String
  type_ : String
  role : String
  content : Array[AnthropicResponseBlock]
  model : String
  stop_reason : String?
  stop_sequence : String?
  usage : AnthropicUsage
} derive(FromJson, Debug, ToJson)

///|
pub struct AnthropicResponseBlock {
  type_ : String
  text : String?
  name : String?
  input : Json?
  id : String?
} derive(FromJson, Debug, ToJson)

///|
pub struct AnthropicUsage {
  input_tokens : Int
  output_tokens : Int
  cache_read_input_tokens : Int?
  cache_creation_input_tokens : Int?
} derive(FromJson, Debug)

///|
pub impl ToJson for AnthropicUsage with fn to_json(self : AnthropicUsage) -> Json {
  let json : Map[String, Json] = {
    "input_tokens": Json::number(self.input_tokens.to_double()),
    "output_tokens": Json::number(self.output_tokens.to_double()),
  }
  if self.cache_read_input_tokens is Some(tokens) && tokens > 0 {
    json["cache_read_input_tokens"] = Json::number(tokens.to_double())
  }
  if self.cache_creation_input_tokens is Some(tokens) && tokens > 0 {
    json["cache_creation_input_tokens"] = Json::number(tokens.to_double())
  }
  Json::object(json)
}

///|
pub struct AnthropicStreamEvent {
  type_ : String
  index : Int?
  delta : AnthropicDelta?
  content_block : AnthropicResponseBlock?
  message : AnthropicResponse?
} derive(FromJson, Debug)

///|
pub struct AnthropicDelta {
  type_ : String?
  text : String?
  stop_reason : String?
} derive(FromJson, Debug)
