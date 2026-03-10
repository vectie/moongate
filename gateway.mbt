///|
pub struct Gateway {
  port : Int
  model : String
  mut credentials : @codex.Credentials?
  logger : @pino.Logger
}

///|
pub fn Gateway::new(port~ : Int, model? : String = "gpt-4o") -> Gateway {
  let logger = @pino.logger("hijack", @pino.Transport::console())
  Gateway::{ port, model, credentials: None, logger }
}

///|
pub fn Gateway::port(self : Gateway) -> Int {
  self.port
}

///|
pub async fn Gateway::start(self : Gateway) -> Unit {
  self.logger.info(
    "Starting Anthropic -> Codex OAuth Gateway on port \{self.port}",
  )
  let creds_result : Result[@codex.Credentials, Error] = try? @codex.load_credentials()
  if creds_result is Ok(creds) {
    self.credentials = Some(creds)
    self.logger.info("Loaded credentials from file")
  } else {
    self.logger.warn(
      "No credentials found. Please login first with: hijack login",
    )
  }
  let router = @httpx.Router::new()
  router.add_handler(@httpx.Method::Post, "/v1/messages", (r, w) => {
    self.handle_messages(r, w)
  })
  router.add_handler(@httpx.Method::Get, "/health", (r, w) => {
    self.handle_health(r, w)
  })
  router.add_handler(@httpx.Method::Post, "/login", (r, w) => {
    self.handle_login(r, w)
  })
  let server = @httpx.Server::new("[::]", self.port, reuse_addr=true)
  self.logger.info("Gateway started on port \{server.port()}")
  server.serve(router.handler())
}

///|
async fn Gateway::handle_health(
  self : Gateway,
  _r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.Ok)
  let has_creds = self.credentials is Some(_)
  let response : Map[String, Json] = {
    "status": Json::string("ok"),
    "credentials_loaded": Json::boolean(has_creds),
  }
  w.write(response.to_json().stringify())
  w.flush()
}

///|
async fn Gateway::handle_login(
  self : Gateway,
  _r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  try {
    let creds = @codex.start_oauth_flow()
    self.credentials = Some(creds)
    self.logger.info("Login successful")
    w.write_header(@status.Ok)
    w.write("{\"status\":\"ok\",\"message\":\"Login successful\"}")
  } catch {
    _ => {
      self.logger.error("Login failed")
      w.write_header(@status.InternalServerError)
      w.write("{\"error\":\"Login failed\"}")
    }
  }
  w.flush()
}

///|
async fn Gateway::handle_messages(
  self : Gateway,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = r.body.read_all()
  let body_str = body.text()
  let json_result : Result[Json, Error] = try? @json.parse(body_str)
  match json_result {
    Err(_) => {
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.BadRequest)
      w.write("{\"error\":\"Invalid JSON\"}")
      w.flush()
      return
    }
    Ok(json) => {
      let anthropic_request_result : Result[AnthropicRequest, Error] = try? @json.from_json(
        json,
      )
      match anthropic_request_result {
        Err(_) => {
          w.header().set("Content-Type", "application/json")
          w.write_header(@status.BadRequest)
          w.write("{\"error\":\"Invalid Anthropic request\"}")
          w.flush()
          return
        }
        Ok(anthropic_request) => {
          self.logger.info(
            "Received Anthropic request for model: \{anthropic_request.model}",
          )
          let model = self.model
          self.logger.debug("Using Codex model: \{model}")
          let stream = anthropic_request.stream.unwrap_or(false)
          if stream {
            self.handle_streaming_request(anthropic_request, model, w)
          } else {
            self.handle_non_streaming_request(anthropic_request, model, w)
          }
        }
      }
    }
  }
}

///|
async fn Gateway::handle_non_streaming_request(
  self : Gateway,
  request : AnthropicRequest,
  model : String,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write("{\"error\":\"Not authenticated. Please login first.\"}")
    w.flush()
    return
  }
  let codex_input = convert_anthropic_to_codex(request, model)
  let codex_request = build_codex_request(codex_input, model, false)
  self.logger.debug("Sending request to Codex API")
  let client = @http.Client::new("https://chatgpt.com", headers={
    "Authorization": "Bearer \{creds.accessToken}",
    "ChatGPT-Account-ID": creds.accountId,
    "Content-Type": "application/json",
    "Accept": "application/json",
    "originator": "hijack_gateway",
    "User-Agent": "hijack/1.0.0",
  })
  defer client.close()
  let response = client.post("/backend-api/codex/responses", codex_request)
  if response.code != 200 {
    let error_body = client.read_all().text()
    self.logger.error("Codex API error: \{response.code} - \{error_body}")
    if response.code == 401 {
      self.logger.info("Attempting to refresh credentials")
      let refresh_result : Result[@codex.Credentials, Error] = try? @codex.refresh_and_save_credentials()
      match refresh_result {
        Ok(new_creds) => {
          self.credentials = Some(new_creds)
          self.logger.info("Credentials refreshed, retrying request")
          self.handle_non_streaming_request(request, model, w)
          return
        }
        Err(_) => ()
      }
    }
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write("{\"error\":\"Codex API error: \{response.code}\"}")
    w.flush()
    return
  }
  let response_body = client.read_all().text()
  let response_json_result : Result[Json, Error] = try? @json.parse(
    response_body,
  )
  match response_json_result {
    Ok(json) => {
      let anthropic_response = convert_codex_to_anthropic(json, request.model)
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.Ok)
      w.write(anthropic_response.to_json().stringify())
    }
    Err(_) => {
      w.header().set("Content-Type", "application/json")
      w.write_header(@status.InternalServerError)
      w.write("{\"error\":\"Failed to parse Codex response\"}")
    }
  }
  w.flush()
}

///|
async fn Gateway::handle_streaming_request(
  self : Gateway,
  request : AnthropicRequest,
  model : String,
  w : @httpx.ResponseWriter,
) -> Unit {
  guard self.credentials is Some(creds) else {
    w.header().set("Content-Type", "application/json")
    w.write_header(@status.Unauthorized)
    w.write("{\"error\":\"Not authenticated. Please login first.\"}")
    w.flush()
    return
  }
  let codex_input = convert_anthropic_to_codex(request, model)
  let codex_request = build_codex_request(codex_input, model, true)
  self.logger.debug("Sending streaming request to Codex API")
  let client = @http.Client::new("https://chatgpt.com", headers={
    "Authorization": "Bearer \{creds.accessToken}",
    "ChatGPT-Account-ID": creds.accountId,
    "Content-Type": "application/json",
    "Accept": "text/event-stream",
    "originator": "hijack_gateway",
    "User-Agent": "hijack/1.0.0",
  })
  defer client.close()
  let response = client.post("/backend-api/codex/responses", codex_request)
  if response.code != 200 {
    let error_body = client.read_all().text()
    self.logger.error("Codex API error: \{response.code} - \{error_body}")
    if response.code == 401 {
      self.logger.info("Attempting to refresh credentials")
      let refresh_result : Result[@codex.Credentials, Error] = try? @codex.refresh_and_save_credentials()
      match refresh_result {
        Ok(new_creds) => {
          self.credentials = Some(new_creds)
          self.logger.info("Credentials refreshed, retrying request")
          self.handle_streaming_request(request, model, w)
          return
        }
        Err(_) => ()
      }
    }
    w.header().set("Content-Type", "application/json")
    w.write_header(response.code)
    w.write("{\"error\":\"Codex API error: \{response.code}\"}")
    w.flush()
    return
  }
  w.header().set("Content-Type", "text/event-stream")
  w.header().set("Cache-Control", "no-cache")
  w.header().set("Connection", "keep-alive")
  w.write_header(@status.Ok)
  let reader = CodexStreamReader::new(client, request.model)
  while reader.read() is Some(event) {
    w.write("event: \{event.event_type}\n")
    w.write("data: \{event.data}\n\n")
    w.flush()
  }
  w.write("event: message_stop\ndata: {}\n\n")
  w.flush()
}

///|
fn convert_codex_to_anthropic(
  codex_json : Json,
  model : String,
) -> AnthropicResponse {
  let content : Array[AnthropicResponseBlock] = []
  let mut input_tokens = 0
  let mut output_tokens = 0
  let id = generate_message_id()
  guard codex_json is Object(obj) else {
    return build_anthropic_response(id, model, "", [], 0, 0)
  }
  if obj.get("output") is Some(Array(outputs)) {
    for output in outputs {
      guard output is Object(out_obj) else { continue }
      let type_ = match out_obj.get("type") {
        Some(String(t)) => t
        _ => continue
      }
      if type_ == "message" {
        if out_obj.get("content") is Some(Array(content_parts)) {
          for part in content_parts {
            guard part is Object(part_obj) else { continue }
            if part_obj.get("type") is Some(String("output_text")) {
              if part_obj.get("text") is Some(String(text)) {
                content.push({
                  type_: "text",
                  text: Some(text),
                  name: None,
                  input: None,
                  id: None,
                })
              }
            }
          }
        }
      } else if type_ == "function_call" {
        let name = match out_obj.get("name") {
          Some(String(n)) => n
          _ => "unknown"
        }
        let args = match out_obj.get("arguments") {
          Some(String(a)) => a
          _ => "{}"
        }
        let call_id = match out_obj.get("call_id") {
          Some(String(id)) => id
          _ => generate_message_id()
        }
        let args_json_result : Result[Json, Error] = try? @json.parse(args)
        let args_json = match args_json_result {
          Ok(j) => j
          Err(_) => Json::object({})
        }
        content.push({
          type_: "tool_use",
          text: None,
          name: Some(name),
          input: Some(args_json),
          id: Some(call_id),
        })
      }
    }
  }
  if obj.get("usage") is Some(Object(usage_obj)) {
    input_tokens = match usage_obj.get("input_tokens") {
      Some(Number(n)) => n.trunc().to_int()
      _ => 0
    }
    output_tokens = match usage_obj.get("output_tokens") {
      Some(Number(n)) => n.trunc().to_int()
      _ => 0
    }
  }
  let has_tools = content.iter().any(fn(b) { b.type_ == "tool_use" })
  let stop_reason = if has_tools { "tool_use" } else { "end_turn" }
  {
    id,
    type_: "message",
    role: "assistant",
    content,
    model,
    stop_reason: Some(stop_reason),
    stop_sequence: None,
    usage: { input_tokens, output_tokens },
  }
}

///|
fn generate_message_id() -> String {
  let gen = @uuid.generator(@random.new())
  let uuid = gen.v4()
  "msg_\{uuid}"
}

///|
priv struct StreamEvent {
  event_type : String
  data : String
}

///|
priv struct CodexStreamReader {
  reader : &@io.Reader
  model : String
}

///|
fn CodexStreamReader::new(
  reader : &@io.Reader,
  model : String,
) -> CodexStreamReader {
  CodexStreamReader::{ reader, model }
}

///|
async fn CodexStreamReader::read(self : CodexStreamReader) -> StreamEvent? {
  let bytes = self.reader.read_until("\n")
  if bytes is None {
    return None
  }
  let line = @encoding/utf8.decode(bytes.unwrap().to_bytes()).to_string()
  // Parse "data: {...}" format
  let trimmed = line.trim()
  if trimmed.length() > 6 {
    let prefix = trimmed[0:5]
    if prefix == "data:" {
      let data = trimmed[6:].trim().to_string()
      if data == "[DONE]" {
        return None
      }
      let json_result : Result[Json, Error] = try? @json.parse(data)
      guard json_result is Ok(Object(obj)) else { return None }
      let json = json_result.unwrap()
      guard json is Object(obj) else { return None }
      let event_type = match obj.get("type") {
        Some(String(t)) => t
        _ => return None
      }
      let anthropic_event = convert_stream_event(event_type, obj, self.model)
      match anthropic_event {
        Some(event) => return Some(event)
        None => return None
      }
    }
  }
  None
}

///|
fn convert_stream_event(
  event_type : String,
  obj : Map[String, Json],
  _model : String,
) -> StreamEvent? {
  match event_type {
    "response.output_text.delta" => {
      let delta = match obj.get("delta") {
        Some(String(d)) => d
        _ => return None
      }
      let event_data : Map[String, Json] = {
        "type": Json::string("content_block_delta"),
        "index": Json::number(0.0),
        "delta": {
          "type": Json::string("text_delta"),
          "text": Json::string(delta),
        }.to_json(),
      }
      Some({
        event_type: "content_block_delta",
        data: event_data.to_json().stringify(),
      })
    }
    "response.output_item.done" => {
      if obj.get("item") is Some(item_json) {
        let item : Json = item_json
        guard item is Object(item_obj) else { return None }
        let type_ = match item_obj.get("type") {
          Some(String(t)) => t
          _ => return None
        }
        if type_ == "function_call" {
          let name = match item_obj.get("name") {
            Some(String(n)) => n
            _ => "unknown"
          }
          let args = match item_obj.get("arguments") {
            Some(String(a)) => a
            _ => "{}"
          }
          let call_id = match item_obj.get("call_id") {
            Some(String(id)) => id
            _ => generate_message_id()
          }
          let args_json_result : Result[Json, Error] = try? @json.parse(args)
          let args_json = match args_json_result {
            Ok(j) => j
            Err(_) => Json::object({})
          }
          let event_data : Map[String, Json] = {
            "type": Json::string("content_block_start"),
            "index": Json::number(1.0),
            "content_block": {
              "type": Json::string("tool_use"),
              "id": Json::string(call_id),
              "name": Json::string(name),
              "input": args_json,
            }.to_json(),
          }
          return Some({
            event_type: "content_block_start",
            data: event_data.to_json().stringify(),
          })
        }
      }
      None
    }
    "response.completed" => {
      let event_data : Map[String, Json] = {
        "type": Json::string("message_delta"),
        "delta": { "stop_reason": Json::string("end_turn") }.to_json(),
        "usage": { "output_tokens": Json::number(0.0) }.to_json(),
      }
      Some({
        event_type: "message_delta",
        data: event_data.to_json().stringify(),
      })
    }
    _ => None
  }
}
