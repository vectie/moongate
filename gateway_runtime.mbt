///|
fn RuntimeService::uptime_seconds(
  _self : RuntimeService,
  started_at_ms : Int32,
) -> Int32 {
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
  ignore(r)
  write_runtime_unsupported(w, "pick_directory")
}

///|
async fn RuntimeService::handle_open_external(
  self : RuntimeService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  ignore(r)
  write_runtime_unsupported(w, "open_external")
}

///|
async fn RuntimeService::handle_copy_text_to_clipboard(
  self : RuntimeService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  ignore(r)
  write_runtime_unsupported(w, "clipboard")
}

///|
async fn RuntimeService::handle_check_for_updates(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_runtime_unsupported(w, "check_for_updates")
}

///|
async fn RuntimeService::handle_update_tray_menu(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_runtime_unsupported(w, "update_tray_menu")
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
  write_runtime_unsupported(w, "restart_app")
}

///|
async fn RuntimeService::handle_install_update_and_restart(
  self : RuntimeService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_runtime_unsupported(w, "install_update_and_restart")
}

///|
async fn write_runtime_unsupported(
  w : @httpx.ResponseWriter,
  operation : String,
) -> Unit {
  w.header().set("Content-Type", "application/json")
  w.write_header(@status.NotImplemented)
  w.write(
    Json({
      "error": Json::string("unsupported_desktop_operation"),
      "operation": Json::string(operation),
      "message": Json::string(
        "This operation is not available through the gateway. Use the desktop app or your system controls.",
      ),
    }).stringify(),
  )
  w.flush()
}
