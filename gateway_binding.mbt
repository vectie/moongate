///|
fn moon_binding_app_command(app_type : String) -> String? {
  match app_type {
    "claude" => Some("claude")
    "codex" => Some("codex")
    "gemini" => Some("gemini")
    "opencode" => Some("opencode")
    "openclaw" => Some("openclaw")
    "hermes" => Some("hermes")
    _ => None
  }
}

///|
fn moon_binding_provider_app_type(app_type : String) -> String {
  if app_type == "moondesk" {
    "codex"
  } else {
    app_type
  }
}

///|
fn moon_binding_moondesk_workspace_root() -> String {
  let configured = (@os.getenv("MOONDESK_WORKSPACE_ROOT") catch { _ => None })
    .unwrap_or("")
    .trim()
    .to_owned()
  if configured != "" {
    return @pathx.normalize(configured)
  }
  let home = moon_home_dir()
  @pathx.join(
    home, "Library/Application Support/app.vectie.moondesk.lepusa.live/workspace",
  )
}

///|
fn moon_binding_moondesk_service_path(root : String) -> String {
  @moonsuite.product_home_for_workspace_root(root, "moonclaw").service_path
}

///|
fn moon_binding_moondesk_provider_path(root : String) -> String {
  default_moongate_moonclaw_providers_file_path_for_workspace_root(root)
}

///|
async fn moon_binding_moondesk_service_configured(root : String) -> Bool {
  let text = @fsx.read_file(moon_binding_moondesk_service_path(root)) catch {
    _ => return false
  }
  let json = @json.parse(text) catch { _ => return false }
  guard json is Object(obj) else { return false }
  guard obj.get("daemon") is Some(Object(daemon)) else { return false }
  json_string_from_map(daemon, "command").unwrap_or("").trim() != ""
}

///|
async fn moon_binding_moondesk_manifest_matches(
  root : String,
  base_url : String,
  model : String,
) -> Bool {
  let text = @fsx.read_file(moon_binding_moondesk_provider_path(root)) catch {
    _ => return false
  }
  let json = @json.parse(text) catch { _ => return false }
  guard json is Object(obj) else { return false }
  guard obj.get("providers") is Some(Object(providers)) else { return false }
  guard providers.get("moongate") is Some(Object(provider)) else {
    return false
  }
  if json_string_from_map(provider, "baseUrl") != Some(base_url) {
    return false
  }
  guard provider.get("models") is Some(Array(models)) else { return false }
  models.any(item => {
    guard item is Object(model_obj) else { false }
    json_string_from_map(model_obj, "id") == Some(model)
  })
}

///|
async fn moon_binding_write_moondesk_provider(
  root : String,
  host : String,
  port : Int,
  model : String,
) -> Result[String, String] {
  let path = moon_binding_moondesk_provider_path(root)
  let existing = @fsx.read_file(path) catch { _ => "" }
  let json = @json.parse(existing) catch { _ => Json::object({}) }
  let obj = match json {
    Object(obj) => obj
    _ => {}
  }
  let providers = match obj.get("providers") {
    Some(Object(providers)) => providers
    _ => {}
  }
  guard moongate_moonclaw_providers_file_json(host~, port~, model~)
    is { "providers": { "moongate": provider, .. }, .. } else {
    return Err("moondesk_provider_manifest_invalid")
  }
  providers["moongate"] = provider
  obj["providers"] = Json::object(providers)
  @fsx.make_directory(@pathx.dirname(path), recursive=true, exists_ok=true) catch {
    error => return Err("Could not prepare MoonDesk provider folder: \{error}")
  }
  @fsx.write_to_file(
    path,
    Json::object(obj).stringify(indent=2) + "\n",
    create=0o600,
  ) catch {
    error => return Err("Could not write MoonDesk provider manifest: \{error}")
  }
  Ok(path)
}

///|
async fn moon_binding_write_moondesk_service(
  root : String,
) -> Result[String, String] {
  let moonclaw_root = (@os.getenv("MOONCLAW_ROOT") catch { _ => None })
    .unwrap_or("")
    .trim()
    .to_owned()
  let (command, args, cwd) = if moonclaw_root != "" &&
    @fsx.exists(@pathx.join(moonclaw_root, "moon.mod")) {
    let local_moon = @pathx.join(moon_home_dir(), ".moon/bin/moon")
    (
      if @fsx.exists(local_moon) {
        local_moon
      } else {
        "moon"
      },
      ["run", "cmd/main", "--", "daemon", "--port", "0", "--serve", root],
      moonclaw_root,
    )
  } else {
    let probe = moon_single_tool_version_json("moonclaw")
    if json_string_field(probe, "version") is None {
      return Err("MoonClaw runtime is not installed")
    }
    ("moonclaw", ["daemon", "--port", "0", "--serve", root], root)
  }
  let path = moon_binding_moondesk_service_path(root)
  let existing = @fsx.read_file(path) catch { _ => "" }
  let json = @json.parse(existing) catch { _ => Json::object({}) }
  let obj = match json {
    Object(obj) => obj
    _ => {}
  }
  obj["kind"] = Json::string("moondesk-moonclaw-service.v1")
  obj["cwd"] = Json::string(cwd)
  obj["daemon"] = {
    "command": Json::string(command),
    "args": Json::array(args.map(value => Json::string(value))),
  }.to_json()
  @fsx.make_directory(@pathx.dirname(path), recursive=true, exists_ok=true) catch {
    error => return Err("Could not prepare MoonDesk service folder: \{error}")
  }
  @fsx.write_to_file(
    path,
    Json::object(obj).stringify(indent=2) + "\n",
    create=0o600,
  ) catch {
    error => return Err("Could not write MoonDesk service config: \{error}")
  }
  Ok(path)
}

///|
async fn moon_binding_remove_moondesk_provider(
  root : String,
) -> Result[Unit, String] {
  let path = moon_binding_moondesk_provider_path(root)
  let text = @fsx.read_file(path) catch { _ => return Ok(()) }
  let json = @json.parse(text) catch {
    _ => return Err("MoonDesk provider manifest is invalid")
  }
  guard json is Object(obj) else {
    return Err("MoonDesk provider manifest is invalid")
  }
  guard obj.get("providers") is Some(Object(providers)) else { return Ok(()) }
  providers.remove("moongate")
  obj["providers"] = Json::object(providers)
  @fsx.write_to_file(
    path,
    Json::object(obj).stringify(indent=2) + "\n",
    create=0o600,
  ) catch {
    error => return Err("Could not update MoonDesk provider manifest: \{error}")
  }
  Ok(())
}

///|
async fn moon_binding_app_installation_json(app_type : String) -> Json {
  if app_type == "moondesk" {
    let home_app = @pathx.join(
      @pathx.join(moon_home_dir(), "Applications"),
      "MoonDesk.app",
    )
    let workspace = moon_binding_moondesk_workspace_root()
    let installed = @fsx.exists("/Applications/MoonDesk.app") ||
      @fsx.exists(home_app) ||
      @fsx.exists(workspace)
    return {
      "installed": Json::boolean(installed),
      "version": Json::null(),
      "error": Json::null(),
    }.to_json()
  }
  if app_type == "claude-desktop" {
    let home_app = @pathx.join(
      @pathx.join(moon_home_dir(), "Applications"),
      "Claude.app",
    )
    let installed = @fsx.exists("/Applications/Claude.app") ||
      @fsx.exists(home_app) ||
      moon_config_exists(app_type)
    return {
      "installed": Json::boolean(installed),
      "version": Json::null(),
      "error": Json::null(),
    }.to_json()
  }
  guard moon_binding_app_command(app_type) is Some(command) else {
    return {
      "installed": Json::boolean(false),
      "version": Json::null(),
      "error": Json::string("Automatic app detection is unavailable"),
    }.to_json()
  }
  let probe = moon_single_tool_version_json(command)
  {
    "installed": Json::boolean(
      json_string_field(probe, "version") is Some(_) &&
      !json_bool_field(probe, "installed_but_broken").unwrap_or(false),
    ),
    "version": match json_string_field(probe, "version") {
      Some(version) => Json::string(version)
      None => Json::null()
    },
    "error": match json_string_field(probe, "error") {
      Some(error) => Json::string(error)
      None => Json::null()
    },
  }.to_json()
}

///|
fn moon_binding_mode(app_type : String) -> String {
  match app_type {
    "moondesk" | "codex" | "claude-desktop" => "automatic"
    _ => "manual"
  }
}

///|
fn ProviderRouteTarget::binding_model(
  self : ProviderRouteTarget,
  fallback : String,
) -> String {
  match self.model_mapping {
    Some(mapping) => mapping.default_model.unwrap_or(fallback)
    None => fallback
  }
}

///|
async fn ProxyService::app_binding_status_json(
  self : ProxyService,
  app_type : String,
  host : String,
  port : Int,
) -> Json {
  let installation = moon_binding_app_installation_json(app_type)
  let installed = json_bool_field(installation, "installed").unwrap_or(false)
  let mode = moon_binding_mode(app_type)
  let provider_app_type = moon_binding_provider_app_type(app_type)
  let current_id = self.provider_router.current_provider_id(provider_app_type)
  let current_provider = match current_id {
    Some(provider_id) =>
      self.provider_router.provider_by_id(provider_app_type, provider_id)
    None => None
  }
  let mut managed = false
  let mut bound = false
  let mut stale = false
  let mut config_path = moon_config_file_path(app_type)
  let mut configured_url : String? = None
  let mut expected_url : String? = None
  match app_type {
    "moondesk" => {
      let root = moon_binding_moondesk_workspace_root()
      let expected = "http://\{host}:\{port}/v1"
      let model = match current_provider {
        Some(provider) => provider.binding_model(@suite.default_model())
        None => @suite.default_model()
      }
      let manifest_path = moon_binding_moondesk_provider_path(root)
      managed = @fsx.exists(manifest_path)
      bound = moon_binding_moondesk_manifest_matches(root, expected, model) &&
        moon_binding_moondesk_service_configured(root)
      stale = managed && !bound
      config_path = manifest_path
      configured_url = if managed { Some(expected) } else { None }
      expected_url = Some(expected)
    }
    "codex" => {
      let status = @codex_config.status()
      let expected = "http://{host}:{port}/v1"
      managed = status.configured
      bound = status.configured && status.base_url == Some(expected)
      stale = status.configured && !bound
      config_path = status.config_path
      configured_url = status.base_url
      expected_url = Some(expected)
    }
    "claude-desktop" => {
      let status = @claude_desktop.status()
      let expected = @claude_desktop.local_gateway_base_url(host, port)
      managed = status.configured
      bound = status.configured && status.actual_base_url == Some(expected)
      stale = status.configured && !bound
      config_path = status.profile_path
      configured_url = status.actual_base_url
      expected_url = Some(expected)
    }
    _ => ()
  }
  let state = if !installed {
    "not_installed"
  } else if bound {
    "bound"
  } else if stale {
    "stale"
  } else if mode == "manual" {
    "manual"
  } else {
    "not_bound"
  }
  {
    "appType": Json::string(app_type),
    "installed": Json::boolean(installed),
    "version": match json_string_field(installation, "version") {
      Some(version) => Json::string(version)
      None => Json::null()
    },
    "detectionError": match json_string_field(installation, "error") {
      Some(error) => Json::string(error)
      None => Json::null()
    },
    "bindingMode": Json::string(mode),
    "bindingState": Json::string(state),
    "managedBindingFound": Json::boolean(managed),
    "bound": Json::boolean(bound),
    "configPath": Json::string(config_path),
    "configuredUrl": match configured_url {
      Some(url) => Json::string(url)
      None => Json::null()
    },
    "expectedUrl": match expected_url {
      Some(url) => Json::string(url)
      None => Json::null()
    },
    "currentProviderId": match current_id {
      Some(provider_id) => Json::string(provider_id)
      None => Json::null()
    },
    "currentProviderName": match current_provider {
      Some(provider) => Json::string(provider.provider_name)
      None => Json::null()
    },
  }.to_json()
}

///|
async fn ProxyService::handle_get_app_binding(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  host : String,
  port : Int,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  write_usage_json(w, self.app_binding_status_json(app_type, host, port))
}

///|
async fn ProxyService::handle_bind_app(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  usage : UsageService,
  host : String,
  port : Int,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  if moon_binding_mode(app_type) != "automatic" {
    write_usage_bad_request(w, "manual_binding_required")
    return
  }
  let installation = moon_binding_app_installation_json(app_type)
  if !json_bool_field(installation, "installed").unwrap_or(false) {
    write_usage_bad_request(w, "app_not_installed")
    return
  }
  guard provider_route_provider_id_from_request(r.path, body)
    is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  let provider_app_type = moon_binding_provider_app_type(app_type)
  guard self.provider_router.provider_by_id(provider_app_type, provider_id)
    is Some(provider) else {
    write_usage_bad_request(w, "provider_not_found")
    return
  }
  if !provider.enabled {
    write_usage_bad_request(w, "provider_unavailable")
    return
  }
  let result = match app_type {
    "moondesk" => {
      let root = moon_binding_moondesk_workspace_root()
      match moon_binding_write_moondesk_service(root) {
        Err(error) => Err(error)
        Ok(_) =>
          match
            moon_binding_write_moondesk_provider(
              root,
              host,
              port,
              provider.binding_model(@suite.default_model()),
            ) {
            Ok(_) => Ok(())
            Err(error) => Err(error)
          }
      }
    }
    "codex" =>
      match
        @codex_config.install_proxy_config(
          host,
          port,
          provider.binding_model(@suite.default_model()),
        ) {
        Ok(_) => Ok(())
        Err(error) => Err(error)
      }
    "claude-desktop" =>
      match @claude_desktop.install_proxy_profile(host, port) {
        Ok(_) => Ok(())
        Err(error) => Err(error)
      }
    _ => Err("manual_binding_required")
  }
  match result {
    Err(error) => {
      write_usage_bad_request(w, error)
      return
    }
    Ok(_) => ()
  }
  self.provider_router.set_current_provider(provider_app_type, provider_id)
  self.proxy_takeover_enabled.set(app_type, true)
  self.proxy_enabled = true
  usage.set_active_target(
    provider_app_type,
    provider_id,
    provider.provider_name,
  )
  if !self.persist_provider_store_or_error(w) {
    return
  }
  if !self.persist_proxy_store_or_error(w) {
    return
  }
  write_usage_json(w, self.app_binding_status_json(app_type, host, port))
}

///|
async fn ProxyService::handle_unbind_app(
  self : ProxyService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  host : String,
  port : Int,
) -> Unit {
  let body = proxy_json_body(r)
  guard provider_app_from_request(r.path, body) is Some(app_type) else {
    write_usage_bad_request(w, "missing_app")
    return
  }
  let result = match app_type {
    "moondesk" =>
      moon_binding_remove_moondesk_provider(
        moon_binding_moondesk_workspace_root(),
      )
    "codex" => @codex_config.uninstall_proxy_config()
    "claude-desktop" => @claude_desktop.uninstall_proxy_profile()
    _ => Err("manual_binding_required")
  }
  match result {
    Err(error) => {
      write_usage_bad_request(w, error)
      return
    }
    Ok(_) => ()
  }
  self.proxy_takeover_enabled.set(app_type, false)
  if !self.persist_proxy_store_or_error(w) {
    return
  }
  write_usage_json(w, self.app_binding_status_json(app_type, host, port))
}
