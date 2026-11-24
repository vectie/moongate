///|
async test "provider check honors configured timeout and returns a recoverable failure" {
  let upstream = @httpx.Server::new("127.0.0.1", 0)
  defer upstream.close()
  let gateway = Gateway::new(port=0)
  let provider = ProviderRouteTarget::new(
    app_type="openclaw",
    provider_id="slow-fixture",
    provider_name="Slow fixture",
    base_url=Some("http://127.0.0.1:\{upstream.port()}/v1"),
    api_key=Some("fixture-secret"),
    api_format=Some("openai_chat"),
    origin="user",
  )
  @async.with_timeout(5000, () => {
    @async.with_task_group(group => {
      group.spawn_bg(
        () => {
          upstream.serve((_r, w) => {
            @async.sleep(10_000)
            w.write("{}")
            w.flush()
          })
        },
        no_wait=true,
        allow_failure=true,
      )
      let result = gateway.proxy.stream_check_provider_target_result_json(
        gateway.auth,
        { ..StreamCheckConfig::default(), timeout_secs: 1, },
        provider,
      )
      assert_true(
        result is { "success": false, "networkRequestPerformed": true, .. },
      )
      assert_true(
        result is { "message": String(message), .. } &&
        message.contains("timed out after 1 seconds"),
      )
    })
  })
}
