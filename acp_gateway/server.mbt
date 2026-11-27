///|
fn error_json(error : BridgeError) -> Json {
  let BridgeError(kind~, message~, ..) = error
  { "error": { "message": message, "type": "acp_bridge_error", "code": kind } }
}

///|
async fn json_reply(
  writer : @httpx.ResponseWriter,
  code : Int32,
  body : Json,
) -> Unit {
  writer.header().set("content-type", "application/json")
  writer.header().set("cache-control", "no-store")
  writer.write_header(code)
  writer.write(body.stringify())
  writer.close()
}

///|
async fn read_body(reader : &@io.Reader) -> Json {
  let body = Buffer()
  while reader.read_some(max_len=8192) is Some(bytes) {
    body.write_bytesview(bytes)
    if body.length() > 1048576 {
      raise BridgeError(
        code=413,
        kind="request_too_large",
        message="Text request exceeds 1 MiB",
      )
    }
  }
  @json.parse(@utf8.decode(body.to_bytes())) catch {
    _ => raise bad_request("Request body is not valid JSON")
  }
}

///|
/// OpenAI Chat-compatible text subset, for a trusted local ACP executable.
/// No filesystem, terminal, approval or credential-extraction API is exposed.
/// This is not a sandbox: the configured executable retains its OS privileges.
async fn Bridge::handle(
  self : Bridge,
  request : @httpx.RequestReader,
  writer : @httpx.ResponseWriter,
  workers : @async.TaskGroup[Unit],
) -> Unit {
  if request.headers.contains("origin") {
    return json_reply(
      writer,
      403,
      error_json(
        BridgeError(
          code=403,
          kind="browser_access_denied",
          message="Use an authenticated local API client",
        ),
      ),
    )
  }
  if request.headers.get("authorization") != Some("Bearer \{self.token}") {
    return json_reply(
      writer,
      401,
      error_json(
        BridgeError(
          code=401,
          kind="invalid_token",
          message="A valid local bridge bearer token is required",
        ),
      ),
    )
  }
  if request.method_ == Get && request.path == "/v1/models" {
    return json_reply(writer, 200, {
      "object": "list",
      "data": Json::array(
        self.models.map(model => {
          "id": model,
          "object": "model",
          "owned_by": "acp",
          "moongate": {
            "source": "configured_allowlist",
            "verified": false,
            "capabilities": if self.tools {
              ["text", "tool_calls"]
            } else {
              ["text"]
            },
          },
        }),
      ),
    })
  }
  if request.method_ != Post || request.path != "/v1/chat/completions" {
    return json_reply(
      writer,
      404,
      error_json(
        BridgeError(
          code=404,
          kind="route_not_supported",
          message="Supported routes: /v1/models and /v1/chat/completions",
        ),
      ),
    )
  }
  if !request.headers
    .get("content-type")
    .unwrap_or("")
    .has_prefix("application/json") {
    return json_reply(
      writer,
      415,
      error_json(
        BridgeError(
          code=415,
          kind="invalid_content_type",
          message="Use application/json",
        ),
      ),
    )
  }
  if self.active >= self.max_concurrent {
    return json_reply(
      writer,
      429,
      error_json(
        BridgeError(
          code=429,
          kind="bridge_busy",
          message="Local ACP concurrency limit reached; retry after a running request finishes",
        ),
      ),
    )
  }
  self.active += 1
  defer {
    self.active -= 1
  }
  self.sequence += 1
  let id = "chatcmpl-acp-\{@os.unix_seconds()}-\{self.sequence}"
  let mut started = false
  @async.with_timeout(self.timeout_ms, () => {
    let chat = parse_chat(
      read_body(request.body),
      self.models,
      tools_enabled=self.tools,
    )
    let (text, finish, calls) = self.complete(
      chat,
      chunk => {
        if !chat.stream {
          return
        }
        if !started {
          writer.header().set("content-type", "text/event-stream")
          writer.header().set("cache-control", "no-store")
          writer.write_header(200)
          started = true
          let role = chat_chunk(
            id,
            chat.model,
            { "role": "assistant" },
            Json::null(),
          )
          writer.write("data: \{role.stringify()}\n\n")
        }
        let item = chat_chunk(
          id,
          chat.model,
          { "content": chunk },
          Json::null(),
        )
        writer.write("data: \{item.stringify()}\n\n")
        writer.flush()
      },
      id,
      workers,
    )
    if chat.stream {
      // Refusals can finish without a text chunk.
      if !started {
        writer.header().set("content-type", "text/event-stream")
        writer.header().set("cache-control", "no-store")
        writer.write_header(200)
        started = true
      }
      if !calls.is_empty() {
        let delta = chat_chunk(
          id,
          chat.model,
          {
            "tool_calls": Json::array(
              calls.mapi((index, call) => {
                guard call is Object(fields) else { return call }
                let fields = fields.copy()
                fields["index"] = Json(index)
                Json::object(fields)
              }),
            ),
          },
          Json::null(),
        )
        writer.write("data: \{delta.stringify()}\n\n")
      }
      let last = chat_chunk(id, chat.model, {}, Json::string(finish))
      writer.write("data: \{last.stringify()}\n\ndata: [DONE]\n\n")
      writer.close()
    } else {
      json_reply(
        writer,
        200,
        chat_completion(id, chat.model, text, finish, calls~),
      )
    }
  }) catch {
    error => {
      let bridge_error = match error {
        BridgeError(..) as known => known
        @async.TimeoutError =>
          BridgeError(
            code=504,
            kind="acp_timeout",
            message="ACP request timed out; the child process was stopped",
          )
        _ =>
          BridgeError(
            code=502,
            kind="acp_unavailable",
            message="ACP process or connection failed",
          )
      }
      if started {
        // An SSE failure is an error event, never a fabricated successful DONE.
        writer.write("data: \{error_json(bridge_error).stringify()}\n\n")
        writer.close()
      } else {
        let BridgeError(code~, ..) = bridge_error
        json_reply(writer, code, error_json(bridge_error))
      }
    }
  }
}

///|
/// Start the experimental bridge on IPv4 loopback only. It is intentionally
/// separate from provider storage; add this URL as an OpenAI Chat provider.
pub async fn Bridge::serve(self : Bridge, port~ : Int32 = 15724) -> Unit {
  guard port >= 1 && port <= 65535 else {
    raise invalid_config("port must be from 1 to 65535")
  }
  let server = @httpx.Server::new("127.0.0.1", port)
  defer server.close()
  println("Experimental ACP text bridge: http://127.0.0.1:\{server.port()}/v1")
  @async.with_task_group(workers => {
    server.serve((request, writer) => self.handle(request, writer, workers))
  })
}
