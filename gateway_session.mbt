///|
fn extract_client_session_context(
  headers : Map[String, String],
  body : Json,
  client_format : String,
) -> MoonClientSession {
  match extract_client_session_id(headers, body, client_format) {
    Some(session_id) => { session_id, client_provided: true }
    None => { session_id: generate_moon_session_id(), client_provided: false }
  }
}

///|
fn generate_moon_session_id() -> String {
  moonstat_random_id()
}

///|
fn extract_client_session_id(
  headers : Map[String, String],
  body : Json,
  client_format : String,
) -> String? {
  if client_format == "claude" {
    match extract_claude_session_id(headers, body) {
      Some(id) => return Some(id)
      None => ()
    }
  }
  if client_format == "codex" || client_format == "openai" {
    match extract_codex_session_id(headers, body) {
      Some(id) => return Some(id)
      None => ()
    }
  }
  extract_session_from_metadata(body)
}

///|
fn extract_claude_session_id(
  headers : Map[String, String],
  body : Json,
) -> String? {
  for name in ["x-claude-code-session-id", "claude-code-session-id"] {
    match headers.get(name) {
      Some(value) if !value.is_empty() => return Some(value)
      _ => ()
    }
  }
  extract_session_from_metadata(body)
}

///|
fn extract_codex_session_id(
  headers : Map[String, String],
  body : Json,
) -> String? {
  for name in ["session_id", "x-session-id"] {
    match headers.get(name) {
      Some(value) if value.length() > 20 => return Some("codex_\{value}")
      _ => ()
    }
  }
  match json_metadata_string(body, "session_id") {
    Some(value) if value.length() > 10 => Some("codex_\{value}")
    _ => None
  }
}

///|
fn extract_session_from_metadata(body : Json) -> String? {
  match json_metadata_string(body, "user_id") {
    Some(user_id) =>
      match parse_session_from_user_id(user_id) {
        Some(id) => return Some(id)
        None => ()
      }
    None => ()
  }
  match json_metadata_string(body, "session_id") {
    Some(id) if !id.is_empty() => Some(id)
    _ => None
  }
}

///|
fn parse_session_from_user_id(user_id : String) -> String? {
  match user_id.find("_session_") {
    Some(index) => {
      let start = index + "_session_".length()
      let session_id = user_id[start:]
      if session_id.is_empty() {
        None
      } else {
        Some(session_id.to_owned())
      }
    }
    None => None
  }
}

///|
async fn SessionService::handle_list_sessions(
  self : SessionService,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  write_usage_json(w, moon_list_sessions_json())
}

///|
async fn SessionService::handle_get_session_messages(
  self : SessionService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "providerId") is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard proxy_string_request(r.path, body, "sourcePath") is Some(source_path) else {
    write_usage_bad_request(w, "missing_source_path")
    return
  }
  match moon_get_session_messages_json(provider_id, source_path) {
    Ok(messages) => write_usage_json(w, messages)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn SessionService::handle_launch_session_terminal(
  self : SessionService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
  preferred_terminal : String?,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "command") is Some(command) else {
    write_usage_bad_request(w, "missing_command")
    return
  }
  let cwd = proxy_string_request(r.path, body, "cwd")
  let custom_config = proxy_string_request(r.path, body, "customConfig")
  match
    moon_launch_session_terminal_json(
      command, cwd, custom_config, preferred_terminal,
    ) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn SessionService::handle_delete_session(
  self : SessionService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard proxy_string_request(r.path, body, "providerId") is Some(provider_id) else {
    write_usage_bad_request(w, "missing_provider_id")
    return
  }
  guard proxy_string_request(r.path, body, "sessionId") is Some(session_id) else {
    write_usage_bad_request(w, "missing_session_id")
    return
  }
  guard proxy_string_request(r.path, body, "sourcePath") is Some(source_path) else {
    write_usage_bad_request(w, "missing_source_path")
    return
  }
  match moon_delete_session_json(provider_id, session_id, source_path) {
    Ok(result) => write_usage_json(w, result)
    Err(error) => write_usage_bad_request(w, error)
  }
}

///|
async fn SessionService::handle_delete_sessions(
  self : SessionService,
  r : @httpx.RequestReader,
  w : @httpx.ResponseWriter,
) -> Unit {
  ignore(self)
  let body = proxy_json_body(r)
  guard moon_delete_session_requests_from_json(body) is Some(items) else {
    write_usage_bad_request(w, "missing_items")
    return
  }
  write_usage_json(w, moon_delete_sessions_json(items))
}
