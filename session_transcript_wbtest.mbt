///|
async test "transcript exported file crosses native route and compiled reader page" {
  let source =
    #|{"type":"session_meta","payload":{"cwd":"/sample"}}
    #|{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Please preserve these project notes."}]}}
    #|{"type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Download Markdown to keep the notes with your project. 月"}]}}
  let server = @httpx.Server::new("127.0.0.1", 0)
  defer server.close()
  let gateway = Gateway::new(host="127.0.0.1", port=server.port())
  gateway.control.token = Some("transcript-fixture-control")
  let router = @httpx.Router::new()
  gateway.session.register_routes(router, None)
  gateway.workspace.register_routes(
    router,
    gateway.config,
    gateway.logger,
    "127.0.0.1",
    server.port(),
  )
  let file_server = @httpx.FileServer::new("public")
  router.set_not_found_handler(file_server.handler())
  @async.with_timeout(15000, () => {
    @async.with_task_group(group => {
      group.spawn_bg(
        () => {
          server.serve(
            moongate_security_handler(
              router.handler(),
              gateway.control,
              "127.0.0.1",
              server.port(),
            ),
          )
        },
        no_wait=true,
        allow_failure=true,
      )
      let base = "http://127.0.0.1:\{server.port()}"
      let headers = {
        "x-moongate-control-token": "transcript-fixture-control",
        "content-type": "application/json",
      }
      let payload : Json = {
        "content": source,
        "format": "auto",
        "sourceName": "sample-codex.jsonl",
      }
      let (response, body) = @http.post(
        base + "/sessions/preview",
        payload.stringify(),
        headers~,
      )
      assert_eq(response.code, 200)
      let result_text = body.text()
      guard @json.parse(result_text) is Object(result) else {
        fail("Expected result")
      }
      assert_eq(result["messageCount"], Json::number(2))
      assert_eq(result["skippedRecords"], Json::number(1))
      let (page_response, page_data) = @http.get(base + "/")
      assert_eq(page_response.code, 200)
      let html = page_data.text()
      for
        id in [
          "page-transcripts", "transcript-file", "transcript-content", "transcript-format",
          "transcript-query", "transcript-role", "transcript-json", "transcript-markdown",
        ] {
        assert_true(html.contains("id=\"\{id}\""), msg=id)
      }
      assert_true(html.contains("Transcript Reader"))
      assert_true(html.contains("/sessions/preview"))
      let (asset_response, asset_data) = @http.get(
        base + "/assets/moongate-transcript.js",
      )
      assert_eq(asset_response.code, 200)
      assert_true(asset_data.text().contains("function openTranscript()"))
      match @env.get_env_var("MOONGATE_TRANSCRIPT_EVIDENCE") {
        Some(destination) => {
          @fsx.make_directory(destination, recursive=true, exists_ok=true)
          @fsx.write_to_file(destination + "/sample-codex.jsonl", source)
          @fsx.write_to_file(
            destination + "/normalized-response.json",
            result_text,
          )
          @fsx.write_to_file(destination + "/compiled-dashboard.html", html)
        }
        None => ()
      }
      let invalid : Json = { "content": "not JSON", "format": "auto" }
      let (bad, bad_body) = @http.post(
        base + "/sessions/preview",
        invalid.stringify(),
        headers~,
      )
      assert_eq(bad.code, 400)
      assert_true(bad_body.text().contains("Invalid JSON"))
    })
  })
}
