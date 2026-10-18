///|
#skip("Explicit production Desk to Claw to MoonGate loopback qualification")
async test "production Gate validates Desk imports through actual Claw before saving" {
  guard @env.get_env_var("CHECKPOINT26_CLAW_ROOT") is Some(claw) &&
    @env.get_env_var("CHECKPOINT26_DESK_ROOT") is Some(desk) &&
    @env.get_env_var("CHECKPOINT26_GATE_EVIDENCE") is Some(evidence) &&
    @env.get_env_var("CHECKPOINT26_CHILD_MOON_HOME") is Some(child_home) else {
    fail("Explicit isolated sources, evidence and child toolchain required")
  }
  @fsx.with_temporary_directory("gate-provider-chain-XXXXXX", async fn(root) {
    let root = @fs.realpath(root)
    let old_workspace = @os.getenv("MOONSUITE_WORKSPACE_ROOT") catch {
      _ => None
    }
    let old_claw = @os.getenv("MOONCLAW_ROOT") catch { _ => None }
    defer {
      moon_wbtest_restore_env("MOONSUITE_WORKSPACE_ROOT", old_workspace)
      moon_wbtest_restore_env("MOONCLAW_ROOT", old_claw)
    }
    @os.setenv("MOONSUITE_WORKSPACE_ROOT", root, overwrite=true)
    @os.setenv("MOONCLAW_ROOT", claw, overwrite=true)
    let upstream = @httpx.Server::new("127.0.0.1", 0)
    defer upstream.close()
    let server = @httpx.Server::new("127.0.0.1", 0)
    defer server.close()
    let provider_requests : Array[String] = []
    let gate_requests : Array[String] = []
    let gateway = Gateway::new(
      host="127.0.0.1",
      port=server.port(),
      model="fixture-original",
    )
    gateway.control.token = Some("provider-import-gate-control-token")
    let router = @httpx.Router::new()
    gateway.proxy.register_management_routes(
      router,
      gateway.auth,
      gateway.usage,
      "127.0.0.1",
      server.port(),
      0,
      0,
      gateway.config.stream_check_config,
    )
    let store_path = moon_provider_store_path()
    assert_true(store_path.has_prefix(root + "/"))
    assert_false(@fsx.exists(store_path))
    let next = router.handler()
    let observed : @httpx.Handler = (r, w) => {
      let path = r.path.to_owned().split("?").head().unwrap_or("").to_owned()
      gate_requests.push(path)
      let before = gateway.proxy
        .moon_export_providers_json(include_secrets=true)
        .stringify()
      let health = gateway.proxy.provider_router
        .provider_health_store_json()
        .stringify()
      let store = if @fsx.exists_as_file(store_path) {
        Some(@fsx.read_file(store_path))
      } else {
        None
      }
      next(r, w)
      if path == "/providers/validate-connection" {
        assert_eq(
          gateway.proxy
          .moon_export_providers_json(include_secrets=true)
          .stringify(),
          before,
        )
        assert_eq(
          gateway.proxy.provider_router.provider_health_store_json().stringify(),
          health,
        )
        let after_store = if @fsx.exists_as_file(store_path) {
          Some(@fsx.read_file(store_path))
        } else {
          None
        }
        assert_eq(after_store, store)
      }
    }
    @async.with_task_group(group => {
      group.spawn_bg(
        () => {
          upstream.serve((r, w) => {
            assert_eq(r.method_, Get)
            assert_eq(r.path, "/v1/models")
            assert_eq(
              r.headers.get("authorization"),
              Some("Bearer provider-import-synthetic-key"),
            )
            provider_requests.push(r.path.to_owned())
            w.header().set("Content-Type", "application/json")
            w.write_header(200)
            w.write("{\"data\":[{\"id\":\"fixture-import-model\"}]}")
            w.flush()
          })
        },
        no_wait=true,
        allow_failure=true,
      )
      group.spawn_bg(
        () => {
          server.serve(
            moongate_security_handler(
              observed,
              gateway.control,
              "127.0.0.1",
              server.port(),
            ),
          )
        },
        no_wait=true,
        allow_failure=true,
      )
      let fixture : Json = {
        "contract": "moonclaw-provider-import.gate.loopback.v1",
        "synthetic": true,
        "gate_url": "http://127.0.0.1:\{server.port()}",
        "gate_control_token": "provider-import-gate-control-token",
        "base_url": "http://127.0.0.1:\{upstream.port()}/v1",
        "api_key": "provider-import-synthetic-key",
        "model": "fixture-import-model",
        "rejected_model": "missing-import-model",
      }
      let child = @spawn.spawn(
        child_home + "/bin/moon",
        [
          "test", "cmd/daemon/daemon_provider_connection_chain_wbtest.mbt", "--target",
          "native", "--strip", "-j", "2", "--include-skipped",
        ],
        cwd=claw,
        timeout=1200000,
        env={
          "MOON_HOME": child_home,
          "PATH": child_home +
          "/bin:" +
          @env.get_env_var("PATH").unwrap_or("/usr/bin:/bin"),
          "GATE_PROVIDER_VALIDATION_FIXTURE": fixture.stringify(),
          "CHECKPOINT26_GATE_EVIDENCE": evidence,
          "CHECKPOINT26_DESK_ROOT": desk,
          "RUST_LOG": "error",
        },
      )
      @fsx.write_to_file(
        evidence + "/actual-claw-chain.log",
        child.stdout + child.stderr,
      )
      assert_eq(child.status, 0)
      assert_eq(provider_requests.length(), 3)
      assert_eq(
        gate_requests
        .filter(p => p == "/providers/validate-connection")
        .length(),
        3,
      )
      assert_eq(gate_requests.filter(p => p == "/providers").length(), 3)
      assert_eq(gate_requests.filter(p => p == "/providers/update").length(), 1)
      assert_eq(gate_requests.filter(p => p == "/providers/switch").length(), 2)
      assert_eq(gate_requests.filter(p => p == "/bindings").length(), 2)
      assert_eq(gate_requests.length(), 11)
      let provider_id = gateway.proxy.provider_router
        .current_provider_id("openclaw")
        .unwrap()
      let saved = gateway.proxy.provider_router
        .provider_by_id("openclaw", provider_id)
        .unwrap()
      assert_eq(saved.api_key, Some("provider-import-synthetic-key"))
      assert_eq(saved.binding_model(""), "fixture-import-model")
      assert_true(@fsx.exists_as_file(store_path))
      assert_true(
        @fsx.exists_as_file(moon_binding_moondesk_provider_path(root)),
      )
      let receipt : Json = {
        "contract": "moon.provider-import.production-chain.loopback.v1",
        "synthetic": true,
        "gate_routes": gate_requests,
        "provider_catalog_gets": provider_requests.length(),
        "validation_calls": 3,
        "validation_store_mutations": 0,
        "rejection_before_creation": true,
        "create_calls": 1,
        "update_calls": 1,
        "switch_calls": 2,
        "bind_calls": 2,
        "inference_requests": 0,
        "temporary_provider_store": true,
        "temporary_runtime_binding": true,
      }
      @fsx.write_to_file(
        evidence + "/actual-gate-provider-chain.json",
        receipt.stringify(indent=2),
      )
    })
  })
}
