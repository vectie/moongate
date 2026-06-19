///|
fn RuntimeService::uptime_seconds(
  _self : RuntimeService,
  started_at_ms : Int,
) -> Int {
  let elapsed = @async.now().to_int() - started_at_ms
  if elapsed < 0 {
    0
  } else {
    elapsed / 1000
  }
}

///|
async fn RuntimeService::handle_pick_directory(
  self : RuntimeService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  write_usage_json(
    w,
    match proxy_string_request(r.path, body, "defaultPath") {
      Some(path) => Json::string(path)
      None => Json::null()
    },
  )
}

///|
async fn RuntimeService::handle_open_external(
  self : RuntimeService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  let body = proxy_json_body(r)
  let raw_url = proxy_string_request(r.path, body, "url").unwrap_or(
    moon_update_url(),
  )
  ignore(self.record_external_open(raw_url))
  write_usage_json(w, Json::boolean(true))
}

///|
fn RuntimeService::record_external_open(
  self : RuntimeService,
  raw_url : String,
) -> String {
  let normalized = moon_normalize_external_url(raw_url)
  self.last_external_url = Some(normalized)
  self.last_external_url.unwrap()
}

///|
async fn RuntimeService::handle_copy_text_to_clipboard(
  self : RuntimeService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  ignore(proxy_string_request(r.path, body, "text").unwrap_or(""))
  write_usage_json(w, Json::boolean(true))
}

///|
async fn RuntimeService::handle_check_for_updates(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self.record_external_open(moon_update_url()))
  write_usage_json(w, Json::boolean(true))
}

///|
async fn RuntimeService::handle_update_tray_menu(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_update_tray_menu_result())
}

///|
async fn RuntimeService::handle_is_portable_mode(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::boolean(moon_portable_mode()))
}

///|
async fn RuntimeService::handle_get_tool_versions(
  self : RuntimeService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let tools = proxy_string_request(r.path, body, "tools")
  write_usage_json(w, moon_get_tool_versions_json(tools))
}

///|
async fn RuntimeService::handle_run_tool_lifecycle_action(
  self : RuntimeService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let tools = match body {
    Some(Object(obj)) => moon_requested_tool_names_from_json(obj.get("tools"))
    _ => moon_requested_tool_names(proxy_string_request(r.path, body, "tools"))
  }
  guard proxy_string_request(r.path, body, "action") is Some(action) else {
    write_usage_bad_request(w, "missing_action")
    return
  }
  match moon_run_tool_lifecycle_action_json(tools, action) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn RuntimeService::handle_probe_tool_installations(
  self : RuntimeService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  let tools = match body {
    Some(Object(obj)) => moon_requested_tool_names_from_json(obj.get("tools"))
    _ => moon_requested_tool_names(proxy_string_request(r.path, body, "tools"))
  }
  match moon_probe_tool_installations_json(tools) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn RuntimeService::handle_restart_app(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::boolean(true))
}

///|
async fn RuntimeService::handle_install_update_and_restart(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, Json::boolean(false))
}
