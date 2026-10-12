///|
priv struct AnthropicRequest {
  model : String
  max_tokens : Int
  messages : Array[AnthropicMessage]
  system : String?
  tools : Array[AnthropicTool]?
  stream : Bool?
}

///|
impl FromJson for AnthropicRequest with fn from_json(
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
  { model, max_tokens, messages, system, tools, stream, }
}

///|
priv struct AnthropicMessage {
  role : String
  content : AnthropicContent
}

///|
impl FromJson for AnthropicMessage with fn from_json(
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
  { role, content, }
}

///|
priv enum AnthropicContent {
  Text(String)
  Blocks(Array[AnthropicBlock])
}

///|
priv struct AnthropicBlock {
  type_ : String
  text : String?
}

///|
impl FromJson for AnthropicBlock with fn from_json(
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
  { type_, text, }
}

///|
priv struct AnthropicTool {
  name : String
  description : String?
  input_schema : Json
}

///|
impl FromJson for AnthropicTool with fn from_json(
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
  { name, description, input_schema, }
}

///|
priv struct AnthropicResponse {
  id : String
  type_ : String
  role : String
  content : Array[AnthropicResponseBlock]
  model : String
  stop_reason : String?
  stop_sequence : String?
  usage : AnthropicUsage
} derive(ToJson)

///|
priv struct AnthropicResponseBlock {
  type_ : String
  text : String?
  name : String?
  input : Json?
  id : String?
} derive(ToJson)

///|
priv struct AnthropicUsage {
  input_tokens : Int
  output_tokens : Int
  cache_read_input_tokens : Int?
  cache_creation_input_tokens : Int?
}

///|
impl ToJson for AnthropicUsage with fn to_json(self : AnthropicUsage) -> Json {
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
