///|
test "gateway profile matches ccs profile shape" {
  let profile = gateway_profile_json(
    "http://127.0.0.1:15721/claude-desktop", "ccs-test-token",
  )
  json_inspect(profile, content={
    "coworkEgressAllowedHosts": ["*"],
    "disableDeploymentModeChooser": true,
    "inferenceGatewayApiKey": "ccs-test-token",
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
async test "remove gateway enterprise config keeps unrelated enterprise fields" {
  @fsx.with_temporary_directory("moonstat-claude-enterprise-XXXXXX", tmpdir => {
    let config_path = @pathx.join(tmpdir, "claude_desktop_config.json")
    write_json_file(
      config_path,
      Json::object({
        "deploymentMode": Json::string("1p"),
        "enterpriseConfig": Json::object({
          "disableDeploymentModeChooser": Json::boolean(true),
          "inferenceGatewayApiKey": Json::string("ccs-token"),
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
