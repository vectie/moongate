///|
async fn main {
  guard @env.get_env_var("MOONGATE_EVENT_MODEL_ORIGIN") is Some(origin) else {
    fail("MOONGATE_EVENT_MODEL_ORIGIN is required")
  }
  let gateway = @text_gateway.TextGateway::new(
    origin,
    browser_origin?=@env.get_env_var("MOONGATE_EVENT_BROWSER_ORIGIN"),
  )
  let host = @env.get_env_var("MOONGATE_EVENT_HOST").unwrap_or("127.0.0.1")
  let port = @string.parse_int(
    @env.get_env_var("MOONGATE_EVENT_PORT").unwrap_or("15722"),
  )
  guard port > 0 && port < 65536 else { fail("invalid event gateway port") }
  let server = @httpx.Server::new(host, port)
  defer server.close()
  server.serve((request, writer) => {
    if request.method_ == Get && request.path == "/health" {
      writer.header().set("content-type", "application/json")
      writer.write(
        "{\"status\":\"healthy\",\"mode\":\"event-scoped-model-relay\"}",
      )
      writer.close()
    } else {
      gateway.handle(request, writer)
    }
  })
}
