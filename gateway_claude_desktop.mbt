///|
async fn ProxyService::handle_scan_local_proxies(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_scan_local_proxies_json())
}

///|
fn moon_scan_local_proxies_json() -> Json {
  let found : Array[Json] = []
  for item in moon_local_proxy_ports() {
    let (port, primary_type, is_mixed) = item
    if @net.localhost_port_open(port, timeout_ms=100) {
      found.append(
        moon_detected_proxy_entries_json(port, primary_type, is_mixed),
      )
    }
  }
  Json::array(found)
}

///|
async fn ProxyService::handle_claude_desktop_provider_status(
  self : ProxyService,
  host : String,
  port : Int,
  w : @httpx.ResponseWriter,
) -> Unit {
  let status = @claude_desktop.status()
  write_usage_json(w, self.claude_desktop_status_json(status, host, port))
}

///|
fn ProxyService::claude_desktop_status_json(
  self : ProxyService,
  status : @claude_desktop.ClaudeDesktopStatus,
  host : String,
  port : Int,
) -> Json {
  let provider = self.current_claude_desktop_provider()
  let mode = match provider {
    Some(provider) => provider.claude_desktop_mode_for_status()
    None => None
  }
  {
    "supported": Json::boolean(true),
    "configured": Json::boolean(status.configured),
    "appliedId": provider_route_optional_string_json(status.applied_id),
    "profilePath": Json::string(status.profile_path),
    "configLibraryPath": Json::string(status.config_library_path),
    "mode": provider_route_optional_string_json(mode),
    "expectedBaseUrl": provider_route_optional_string_json(
      self.claude_desktop_expected_base_url(mode, provider, host, port),
    ),
    "actualBaseUrl": provider_route_optional_string_json(status.actual_base_url),
    "proxyRunning": Json::boolean(true),
    "staleRawModels": Json::boolean(status.stale_raw_models),
    "missingRouteMappings": Json::boolean(
      claude_desktop_missing_route_mappings(mode, provider),
    ),
    "gatewayTokenConfigured": Json::boolean(status.token_configured),
  }.to_json()
}

///|
fn ProviderRouteTarget::claude_desktop_mode_for_status(
  self : ProviderRouteTarget,
) -> String? {
  match self.claude_desktop_mode {
    Some(mode) => normalize_claude_desktop_mode(mode)
    None =>
      if self.app_type == "claude-desktop" {
        if self.claude_desktop_model_routes.is_empty() {
          Some("direct")
        } else {
          Some("proxy")
        }
      } else {
        None
      }
  }
}

///|
fn ProxyService::claude_desktop_expected_base_url(
  self : ProxyService,
  mode : String?,
  provider : ProviderRouteTarget?,
  host : String,
  port : Int,
) -> String? {
  ignore(self)
  match mode {
    Some("proxy") => Some(@claude_desktop.local_gateway_base_url(host, port))
    Some("direct") =>
      match provider {
        Some(provider) => provider.claude_desktop_direct_base_url()
        None => None
      }
    _ => None
  }
}

///|
fn ProviderRouteTarget::claude_desktop_direct_base_url(
  self : ProviderRouteTarget,
) -> String? {
  match self.settings_config {
    Some(Object(obj)) =>
      match obj.get("env") {
        Some(Object(env)) =>
          json_non_empty_string_from_map(env, "ANTHROPIC_BASE_URL")
        _ => None
      }
    _ => None
  }
}

///|
fn claude_desktop_missing_route_mappings(
  mode : String?,
  provider : ProviderRouteTarget?,
) -> Bool {
  guard mode == Some("proxy") else { return false }
  match provider {
    Some(provider) => provider.resolved_claude_desktop_model_routes().is_empty()
    None => true
  }
}

///|
async fn ProxyService::handle_claude_desktop_provider_default_routes(
  self : ProxyService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, claude_desktop_default_routes_json())
}

///|
fn claude_desktop_default_routes_json() -> Json {
  Json::array([
    claude_desktop_default_route_json(
      "claude-sonnet-4-6", "ANTHROPIC_DEFAULT_SONNET_MODEL",
    ),
    claude_desktop_default_route_json(
      "claude-opus-4-8", "ANTHROPIC_DEFAULT_OPUS_MODEL",
    ),
    claude_desktop_default_route_json(
      "claude-haiku-4-5", "ANTHROPIC_DEFAULT_HAIKU_MODEL",
    ),
  ])
}

///|
fn claude_desktop_default_route_json(
  route_id : String,
  env_key : String,
) -> Json {
  {
    "routeId": Json::string(route_id),
    "envKey": Json::string(env_key),
    "supports1m": Json::boolean(true),
  }.to_json()
}

///|
fn ProviderRouteTarget::is_compatible_claude_desktop_direct_provider(
  self : ProviderRouteTarget,
) -> Bool {
  match self.api_format {
    Some(api_format) if !api_format.trim().is_empty() &&
      api_format.trim() != "anthropic" => return false
    _ => ()
  }
  match self.claude_desktop_mode {
    Some(mode) if normalize_claude_desktop_mode(mode) == Some("proxy") =>
      return false
    _ => ()
  }
  match self.provider_type {
    Some("official") | Some("github_copilot") | Some("codex_oauth") =>
      return false
    _ => ()
  }
  if self.is_full_url {
    return false
  }
  self.claude_desktop_direct_base_url() is Some(_) &&
  self.claude_desktop_direct_auth_token() is Some(_) &&
  self.claude_desktop_direct_routes_are_identity()
}

///|
fn ProviderRouteTarget::claude_desktop_direct_auth_token(
  self : ProviderRouteTarget,
) -> String? {
  match self.settings_config {
    Some(Object(obj)) =>
      match obj.get("env") {
        Some(Object(env)) =>
          json_non_empty_string_from_map(env, "ANTHROPIC_AUTH_TOKEN")
        _ => None
      }
    _ => None
  }
}

///|
fn ProviderRouteTarget::claude_desktop_direct_routes_are_identity(
  self : ProviderRouteTarget,
) -> Bool {
  for raw_route_id in self.claude_desktop_model_routes.keys() {
    let route_id = raw_route_id.trim().to_owned()
    if route_id.is_empty() {
      continue
    }
    if !is_claude_safe_model_id(route_id) {
      return false
    }
    match self.claude_desktop_model_routes.get(raw_route_id) {
      Some(route) => {
        let upstream = route.model.trim()
        if !upstream.is_empty() && upstream != route_id {
          return false
        }
      }
      None => ()
    }
  }
  true
}

///|
fn suggested_claude_desktop_routes(
  provider : ProviderRouteTarget,
) -> Map[String, ClaudeDesktopModelRoute]? {
  guard provider.settings_config is Some(Object(settings)) else { return None }
  guard settings.get("env") is Some(Object(env)) else { return None }
  let routes : Map[String, ClaudeDesktopModelRoute] = Map([], capacity=0)
  let supports_1m_default = match provider.provider_type {
    Some("github_copilot") | Some("codex_oauth") => false
    _ => true
  }
  add_suggested_claude_desktop_route(
    routes, env, "claude-sonnet-4-6", "ANTHROPIC_DEFAULT_SONNET_MODEL", supports_1m_default,
  )
  add_suggested_claude_desktop_route(
    routes, env, "claude-opus-4-8", "ANTHROPIC_DEFAULT_OPUS_MODEL", supports_1m_default,
  )
  add_suggested_claude_desktop_route(
    routes, env, "claude-haiku-4-5", "ANTHROPIC_DEFAULT_HAIKU_MODEL", supports_1m_default,
  )
  if routes.is_empty() {
    add_suggested_claude_desktop_route(
      routes, env, "claude-sonnet-4-6", "ANTHROPIC_MODEL", supports_1m_default,
    )
  }
  if routes.is_empty() {
    None
  } else {
    Some(routes)
  }
}

///|
fn add_suggested_claude_desktop_route(
  routes : Map[String, ClaudeDesktopModelRoute],
  env : Map[String, Json],
  route_key : String,
  env_key : String,
  supports_1m_default : Bool,
) -> Unit {
  guard json_string_from_map(env, env_key) is Some(raw_model) else { return }
  let raw_model = raw_model.trim().to_owned()
  if raw_model.is_empty() {
    return
  }
  let (stripped_model, has_1m_marker) = strip_claude_desktop_one_m_marker(
    raw_model,
  )
  if stripped_model.is_empty() {
    return
  }
  let effective_supports_1m = supports_1m_default || has_1m_marker
  let explicit_label_override = match
    json_string_from_map(env, "\{env_key}_NAME") {
    Some(label) => {
      let label = label.trim().to_owned()
      if label.is_empty() {
        None
      } else {
        Some(label)
      }
    }
    None => None
  }
  let label_override = match explicit_label_override {
    Some(label) => Some(label)
    None =>
      if is_claude_safe_model_id(stripped_model) {
        None
      } else {
        Some(stripped_model)
      }
  }
  match claude_desktop_route_key_for_upstream(routes, stripped_model) {
    Some(existing_key) => {
      guard routes.get(existing_key) is Some(existing) else { return }
      routes[existing_key] = merge_suggested_claude_desktop_route(
        existing, stripped_model, label_override, explicit_label_override, effective_supports_1m,
      )
    }
    None =>
      match routes.get(route_key) {
        Some(existing) =>
          routes[route_key] = merge_suggested_claude_desktop_route(
            existing, stripped_model, label_override, explicit_label_override, effective_supports_1m,
          )
        None =>
          routes[route_key] = ClaudeDesktopModelRoute::new(
            model=stripped_model,
            label_override~,
            supports_1m=Some(effective_supports_1m),
          )
      }
  }
}

///|
fn strip_claude_desktop_one_m_marker(model : String) -> (String, Bool) {
  let marker = "[1m]"
  if model.to_lower().has_suffix(marker) {
    (model[:model.length() - marker.length()].trim().to_owned(), true)
  } else {
    (model.trim().to_owned(), false)
  }
}

///|
fn claude_desktop_route_key_for_upstream(
  routes : Map[String, ClaudeDesktopModelRoute],
  model : String,
) -> String? {
  for route_key in routes.keys() {
    match routes.get(route_key) {
      Some(route) if route.model == model => return Some(route_key)
      _ => ()
    }
  }
  None
}

///|
fn merge_suggested_claude_desktop_route(
  existing : ClaudeDesktopModelRoute,
  stripped_model : String,
  label_override : String?,
  explicit_label_override : String?,
  effective_supports_1m : Bool,
) -> ClaudeDesktopModelRoute {
  let merged_supports_1m = existing.supports_1m.unwrap_or(false) ||
    effective_supports_1m
  let next_label = if existing.label_override is None ||
    explicit_label_override is Some(_) ||
    existing.label_override == Some(stripped_model) {
    label_override
  } else {
    existing.label_override
  }
  ClaudeDesktopModelRoute::new(
    model=existing.model,
    label_override=next_label,
    supports_1m=Some(merged_supports_1m),
  )
}
