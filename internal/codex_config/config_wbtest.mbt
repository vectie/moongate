///|
async test "codex config install writes moonstat-style local provider block" {
  @fsx.with_temporary_directory("moonstat-codex-config-XXXXXX", tmpdir => {
    let result = install_proxy_config_at(tmpdir, "0.0.0.0", 15721, "gpt-5")
    guard result is Ok(installed) else {
      fail("expected codex config install to succeed")
    }
    assert_eq(installed.base_url, "http://127.0.0.1:15721/v1")
    assert_eq(installed.model, "gpt-5")
    assert_eq(
      installed.model_catalog_path,
      @pathx.join(@pathx.join(tmpdir, ".codex"), "moonstat-model-catalog.json"),
    )
    let content = @fsx.read_file(installed.config_path)
    inspect(
      content,
      content=(
        #|# >>> moonstat managed codex proxy
        #|model = "gpt-5"
        #|model_provider = "moonstat"
        #|model_catalog_json = "moonstat-model-catalog.json"
        #|
        #|[model_providers.moonstat]
        #|name = "MoonGate"
        #|base_url = "http://127.0.0.1:15721/v1"
        #|wire_api = "responses"
        #|experimental_bearer_token = "moonstat-local-proxy"
        #|# <<< moonstat managed codex proxy
        #|
      ),
    )
    guard @json.parse(@fsx.read_file(installed.model_catalog_path))
      is Object(catalog) else {
      fail("expected catalog object")
    }
    guard catalog["models"] is Array(models) else { fail("expected models") }
    guard models[0] is Object(model) else { fail("expected model") }
    assert_eq(model["slug"], Json::string("gpt-5"))
    assert_true(model["model_messages"] is Object(_))
  })
}

///|
async test "codex config reinstall replaces only managed block" {
  @fsx.with_temporary_directory("moonstat-codex-reinstall-XXXXXX", tmpdir => {
    let config_dir = @pathx.join(tmpdir, ".codex")
    @fsx.make_directory(config_dir, recursive=true, exists_ok=true)
    let path = @pathx.join(config_dir, "config.toml")
    @fsx.write_to_file(
      path,
      (
        #|approval_policy = "on-request"
        #|
        #|# >>> moonstat managed codex proxy
        #|model = "old"
        #|model_provider = "moonstat"
        #|# <<< moonstat managed codex proxy
        #|
        #|[mcp_servers.fetch]
        #|command = "uvx"
        #|
      ),
    )

    let result = install_proxy_config_at(tmpdir, "127.0.0.1", 17890, "")
    guard result is Ok(installed) else {
      fail("expected codex config reinstall to succeed")
    }
    assert_eq(installed.config_path, path)
    let content = @fsx.read_file(path)
    assert_eq(
      content,
      (
        #|approval_policy = "on-request"
        #|
        #|[mcp_servers.fetch]
        #|command = "uvx"
        #|
        #|# >>> moonstat managed codex proxy
        #|model = "gpt-5"
        #|model_provider = "moonstat"
        #|model_catalog_json = "moonstat-model-catalog.json"
        #|
        #|[model_providers.moonstat]
        #|name = "MoonGate"
        #|base_url = "http://127.0.0.1:17890/v1"
        #|wire_api = "responses"
        #|experimental_bearer_token = "moonstat-local-proxy"
        #|# <<< moonstat managed codex proxy
        #|
      ),
    )
  })
}

///|
async test "codex config uninstall preserves user config" {
  @fsx.with_temporary_directory("moonstat-codex-uninstall-XXXXXX", tmpdir => {
    let result = install_proxy_config_at(tmpdir, "127.0.0.1", 15721, "gpt-5")
    guard result is Ok(installed) else {
      fail("expected codex config install to succeed")
    }
    let existing = @fsx.read_file(installed.config_path)
    @fsx.write_to_file(
      installed.config_path,
      "approval_policy = \"on-request\"\n\n\{existing}[mcp_servers.fetch]\ncommand = \"uvx\"\n",
    )
    let uninstall_result = uninstall_proxy_config_at(tmpdir)
    guard uninstall_result is Ok(_) else {
      fail("expected codex config uninstall to succeed")
    }
    let content = @fsx.read_file(installed.config_path)
    assert_false(@fsx.exists_as_file(installed.model_catalog_path))
    assert_eq(
      content,
      (
        #|approval_policy = "on-request"
        #|
        #|[mcp_servers.fetch]
        #|command = "uvx"
        #|
      ),
    )
  })
}

///|
async test "codex config status reports managed values" {
  @fsx.with_temporary_directory("moonstat-codex-status-XXXXXX", tmpdir => {
    ignore(install_proxy_config_at(tmpdir, "127.0.0.1", 15721, "gpt-5"))
    let status = status_at(tmpdir)
    assert_true(status.configured)
    assert_true(status.base_url is Some("http://127.0.0.1:15721/v1"))
    assert_true(status.model is Some("gpt-5"))
    assert_eq(
      status.model_catalog_path,
      @pathx.join(@pathx.join(tmpdir, ".codex"), "moonstat-model-catalog.json"),
    )
  })
}

///|
async test "codex config active catalog follows moonstat stale guard" {
  @fsx.with_temporary_directory("moonstat-codex-catalog-XXXXXX", tmpdir => {
    assert_true(active_model_catalog_json_at(tmpdir) is None)
    let result = install_proxy_config_at(tmpdir, "127.0.0.1", 15721, "gpt-5.1")
    guard result is Ok(installed) else {
      fail("expected codex config install to succeed")
    }
    guard active_model_catalog_json_at(tmpdir) is Some(Object(catalog)) else {
      fail("expected active catalog")
    }
    guard catalog["models"] is Array(models) else { fail("expected models") }
    guard models[0] is Object(model) else { fail("expected model") }
    assert_eq(model["slug"], Json::string("gpt-5.1"))
    @fsx.write_to_file(
      installed.config_path,
      @fsx.read_file(installed.config_path).replace(
        old="model_catalog_json = \"moonstat-model-catalog.json\"",
        new="model_catalog_json = \"custom-model-catalog.json\"",
      ),
    )
    assert_true(active_model_catalog_json_at(tmpdir) is None)
  })
}

///|
test "codex model catalog uses moonstat modelCatalog models and context" {
  let catalog = codex_model_catalog_json_from_settings(
    {
      "modelCatalog": {
        "models": [
          {
            "model": "deepseek-v4-flash",
            "displayName": "DeepSeek V4 Flash",
            "contextWindow": "64000",
          },
          { "model": "kimi-k2", "display_name": "Kimi K2" },
          { "model": "deepseek-v4-flash", "displayName": "Duplicate" },
          { "displayName": "Missing Model" },
        ],
      },
    },
    "model_context_window = 128000\n",
    "gpt-5",
  )
  guard catalog is Object(obj) else { fail("expected catalog object") }
  guard obj["models"] is Array(models) else { fail("expected models") }
  assert_eq(models.length(), 2)
  guard models[0] is Object(first) else { fail("expected first model") }
  assert_eq(first["slug"], Json::string("deepseek-v4-flash"))
  assert_eq(first["display_name"], Json::string("DeepSeek V4 Flash"))
  assert_eq(first["description"], Json::string("DeepSeek V4 Flash"))
  assert_eq(first["context_window"], Json::number(64000.0))
  assert_eq(first["max_context_window"], Json::number(64000.0))
  assert_eq(first["priority"], Json::number(1000.0))
  assert_eq(first["additional_speed_tiers"], Json::array([]))
  assert_true(first["availability_nux"] is Null)
  assert_true(first["model_messages"] is Object(_))
  guard models[1] is Object(second) else { fail("expected second model") }
  assert_eq(second["slug"], Json::string("kimi-k2"))
  assert_eq(second["display_name"], Json::string("Kimi K2"))
  assert_eq(second["context_window"], Json::number(128000.0))
  assert_eq(second["priority"], Json::number(1001.0))
}

///|
test "codex model catalog falls back to standalone model without moonstat catalog" {
  let catalog = codex_model_catalog_json_from_settings(
    { "modelCatalog": { "models": [] } },
    "model_context_window = 64000\n",
    "gpt-5",
  )
  guard catalog is Object(obj) else { fail("expected catalog object") }
  guard obj["models"] is Array(models) else { fail("expected models") }
  assert_eq(models.length(), 1)
  guard models[0] is Object(model) else { fail("expected model") }
  assert_eq(model["slug"], Json::string("gpt-5"))
  assert_eq(model["context_window"], Json::number(128000.0))
}
