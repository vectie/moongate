///|
test "gateway profile matches moonstat profile shape" {
  let profile = gateway_profile_json(
    "http://127.0.0.1:15721/claude-desktop", "moonstat-test-token",
  )
  json_inspect(profile, content={
    "coworkEgressAllowedHosts": ["*"],
    "disableDeploymentModeChooser": true,
    "inferenceGatewayApiKey": "moonstat-test-token",
    "inferenceGatewayAuthScheme": "bearer",
    "inferenceGatewayBaseUrl": "http://127.0.0.1:15721/claude-desktop",
    "inferenceProvider": "gateway",
    "inferenceModels": [
      { "name": "claude-sonnet-4-6", "supports1m": true },
      { "name": "claude-opus-4-8", "supports1m": true },
      { "name": "claude-haiku-4-5", "supports1m": true },
    ],
  })
}

///|
test "local gateway base url normalizes wildcard host" {
  inspect(
    local_gateway_base_url("0.0.0.0", 15721),
    content="http://127.0.0.1:15721/claude-desktop",
  )
}

///|
test "status stale raw model detection matches moonstat profile rules" {
  assert_false(
    profile_has_stale_raw_models(
      Json::object({
        "inferenceModels": Json::array([
          Json::string("claude-sonnet-4-6"),
          Json::object({ "name": Json::string("anthropic/claude-opus-4-8") }),
        ]),
      }),
    ),
  )
  assert_true(
    profile_has_stale_raw_models(
      Json::object({
        "inferenceModels": Json::array([Json::string("claude-sonnet-4-6[1m]")]),
      }),
    ),
  )
  assert_true(
    profile_has_stale_raw_models(
      Json::object({
        "inferenceModels": Json::array([
          Json::object({ "name": Json::string("deepseek-v4-flash") }),
        ]),
      }),
    ),
  )
}

///|
async test "write meta restores previous applied profile and preserves fields" {
  @fsx.with_temporary_directory("moonstat-claude-meta-XXXXXX", tmpdir => {
    let meta_path = @pathx.join(tmpdir, "_meta.json")
    write_json_file(
      meta_path,
      Json::object({
        "appliedId": Json::string(PROFILE_ID),
        "theme": Json::string("dark"),
        "entries": Json::array([
          Json::object({
            "id": Json::string("old-profile"),
            "name": Json::string("Old Profile"),
          }),
          Json::object({
            "id": Json::string(PROFILE_ID),
            "name": Json::string(PROFILE_NAME),
          }),
        ]),
      }),
    )

    write_meta(meta_path, None)

    let meta = read_json_or_empty(meta_path)
    json_inspect(meta, content={
      "theme": "dark",
      "appliedId": "old-profile",
      "entries": [{ "id": "old-profile", "name": "Old Profile" }],
    })
  })
}

///|
async test "write meta recovers non object meta file like moonstat" {
  @fsx.with_temporary_directory("moonstat-claude-meta-shape-XXXXXX", tmpdir => {
    let meta_path = @pathx.join(tmpdir, "_meta.json")
    @fsx.write_to_file(meta_path, "[]")

    write_meta(meta_path, Some(PROFILE_ID))

    let meta = read_json_or_empty(meta_path)
    json_inspect(meta, content={
      "appliedId": "00000000-0000-4000-8000-000000157210",
      "entries": [
        { "id": "00000000-0000-4000-8000-000000157210", "name": "MoonGate" },
      ],
    })
  })
}

///|
async test "install proxy profile rolls back when profile write fails" {
  @fsx.with_temporary_directory("moonstat-claude-install-XXXXXX", tmpdir => {
    let normal_config_path = @pathx.join(
      @pathx.join(tmpdir, "Claude"),
      CONFIG_FILE,
    )
    let threep_config_path = @pathx.join(
      @pathx.join(tmpdir, "Claude-3p"),
      CONFIG_FILE,
    )
    let config_library_path = @pathx.join(
      @pathx.join(tmpdir, "Claude-3p"),
      CONFIG_LIBRARY_DIR,
    )
    let paths = ClaudeDesktopPaths::{
      normal_config_path,
      threep_config_path,
      config_library_path,
      profile_path: @pathx.join(config_library_path, PROFILE_ID + ".json"),
      meta_path: @pathx.join(config_library_path, "_meta.json"),
    }
    write_json_file(
      paths.normal_config_path,
      Json::object({
        "deploymentMode": Json::string("1p"),
        "normal": Json::boolean(true),
      }),
    )
    write_json_file(
      paths.threep_config_path,
      Json::object({
        "deploymentMode": Json::string("1p"),
        "threep": Json::boolean(true),
      }),
    )
    @fsx.write_to_file(paths.config_library_path, "not a directory")

    let result = install_proxy_profile_at_paths(
      paths,
      "127.0.0.1",
      15721,
      token=Some("moonstat-token"),
    )

    assert_true(result is Err(_))
    json_inspect(read_json_or_empty(paths.normal_config_path), content={
      "deploymentMode": "1p",
      "normal": true,
    })
    json_inspect(read_json_or_empty(paths.threep_config_path), content={
      "deploymentMode": "1p",
      "threep": true,
    })
    assert_false(@fsx.exists_as_file(paths.profile_path) catch { _ => false })
  })
}

///|
async test "uninstall proxy profile rolls back when meta write fails" {
  @fsx.with_temporary_directory("moonstat-claude-uninstall-XXXXXX", tmpdir => {
    let normal_config_path = @pathx.join(
      @pathx.join(tmpdir, "Claude"),
      CONFIG_FILE,
    )
    let threep_config_path = @pathx.join(
      @pathx.join(tmpdir, "Claude-3p"),
      CONFIG_FILE,
    )
    let config_library_path = @pathx.join(
      @pathx.join(tmpdir, "Claude-3p"),
      CONFIG_LIBRARY_DIR,
    )
    let blocked_meta_dir = @pathx.join(tmpdir, "blocked-meta")
    let paths = ClaudeDesktopPaths::{
      normal_config_path,
      threep_config_path,
      config_library_path,
      profile_path: @pathx.join(config_library_path, PROFILE_ID + ".json"),
      meta_path: @pathx.join(blocked_meta_dir, "_meta.json"),
    }
    write_json_file(
      paths.normal_config_path,
      Json::object({
        "deploymentMode": Json::string("3p"),
        "normal": Json::boolean(true),
      }),
    )
    write_json_file(
      paths.threep_config_path,
      Json::object({
        "deploymentMode": Json::string("3p"),
        "threep": Json::boolean(true),
      }),
    )
    write_json_file(
      paths.profile_path,
      gateway_profile_json(
        "http://127.0.0.1:15721/claude-desktop", "moonstat-token",
      ),
    )
    @fsx.write_to_file(blocked_meta_dir, "not a directory")

    let result = uninstall_proxy_profile_at_paths(paths)

    assert_true(result is Err(_))
    json_inspect(read_json_or_empty(paths.normal_config_path), content={
      "deploymentMode": "3p",
      "normal": true,
    })
    json_inspect(read_json_or_empty(paths.threep_config_path), content={
      "deploymentMode": "3p",
      "threep": true,
    })
    assert_true(@fsx.exists_as_file(paths.profile_path) catch { _ => false })
  })
}

///|
async test "remove gateway enterprise config keeps unrelated enterprise fields" {
  @fsx.with_temporary_directory("moonstat-claude-enterprise-XXXXXX", tmpdir => {
    let config_path = @pathx.join(tmpdir, "claude_desktop_config.json")
    write_json_file(
      config_path,
      Json::object({
        "deploymentMode": Json::string("1p"),
        "enterpriseConfig": Json::object({
          "disableDeploymentModeChooser": Json::boolean(true),
          "inferenceGatewayApiKey": Json::string("moonstat-token"),
          "inferenceGatewayAuthScheme": Json::string("bearer"),
          "inferenceGatewayBaseUrl": Json::string(
            "http://127.0.0.1:15721/claude-desktop",
          ),
          "inferenceProvider": Json::string("gateway"),
          "keepMe": Json::string("value"),
        }),
      }),
    )

    remove_gateway_enterprise_config(config_path)

    let config = read_json_or_empty(config_path)
    json_inspect(config, content={
      "deploymentMode": "1p",
      "enterpriseConfig": { "keepMe": "value" },
    })
  })
}

///|
test "claude desktop gateway token is moonstat product-owned state" {
  let path = gateway_token_path()
  let expected = @moonsuite.product_artifact_for_workspace_root(
    claude_desktop_active_workspace_root(),
    "moonstat",
    "auth/claude-desktop-gateway-token",
  )
  assert_eq(path, expected)
  assert_false(path.contains("/.moonsuite/claude_desktop_gateway_token"))
}
