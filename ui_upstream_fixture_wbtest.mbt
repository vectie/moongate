///|
// Opt-in loopback upstream for UI qualification; never a live-provider claim.
#skip("Interactive UI qualification: run explicitly with --include-skipped")
async test "loopback upstream for provider editor qualification" {
  let server = @httpx.Server::new("127.0.0.1", 15734)
  defer server.close()
  @async.with_task_group(group => {
    group.spawn_bg(
      () => {
        server.serve((r, w) => {
          w.header().set("Content-Type", "application/json")
          let body = if r.path.has_suffix("/models") {
            "{\"data\":[{\"id\":\"fixture-free:free\"},{\"id\":\"fixture-second\"}]}"
          } else if r.path.has_prefix("/invalid") {
            "<html>HTTP 200 is not a completed model response</html>"
          } else {
            "{\"id\":\"chatcmpl-cleanup-fixture\",\"object\":\"chat.completion\",\"model\":\"fixture-free:free\",\"choices\":[{\"index\":0,\"message\":{\"role\":\"assistant\",\"content\":\"OK\"},\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":2,\"completion_tokens\":1,\"total_tokens\":3}}"
          }
          w.write(body)
          w.flush()
        })
      },
      no_wait=true,
      allow_failure=true,
    )
    @async.sleep(600_000)
  })
}
