///|
async test "unsupported desktop operations never claim a successful external effect" {
  let server = @httpx.Server::new("127.0.0.1", 0)
  defer server.close()
  let router = @httpx.Router::new()
  RuntimeService::new().register_routes(router)
  @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve(router.handler()),
      no_wait=true,
      allow_failure=true,
    )
    for
      path in [
        "/files/directories/pick", "/runtime/open-external", "/runtime/clipboard/text",
        "/runtime/updates/check", "/runtime/tray-menu/update", "/runtime/restart",
        "/runtime/updates/install-restart",
      ] {
      let client = @http.Client::Client("http://127.0.0.1:\{server.port()}")
      defer client.close()
      let response = client.post(path, "{}")
      assert_eq(response.code, 501)
      let body = client.read_all().text()
      let result = @json.parse(body)
      assert_eq(
        json_string_field(result, "error"),
        Some("unsupported_desktop_operation"),
      )
    }
  })
}
