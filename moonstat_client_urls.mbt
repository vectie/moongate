///|
fn moonstat_client_normalize_base_url(base_url : String) -> String {
  let trimmed = trim_end_slashes(base_url.trim().to_owned())
  if trimmed.is_empty() {
    MOONSTAT_DEFAULT_CLIENT_BASE_URL
  } else {
    trimmed
  }
}

///|
fn moonstat_client_url(base_url : String, path : String) -> String {
  let normalized = moonstat_client_normalize_base_url(base_url)
  let path = if path.has_prefix("/") { path } else { "/\{path}" }
  "\{normalized}\{path}"
}

///|
fn moonstat_client_url_with_query(
  base_url : String,
  path : String,
  query : MoonstatUsageQuery?,
) -> String {
  moonstat_client_url(base_url, moonstat_client_path_with_query(path, query))
}

///|
fn moonstat_client_url_with_session_sync_query(
  base_url : String,
  path : String,
  query : MoonstatSessionSyncQuery?,
) -> String {
  moonstat_client_url(
    base_url,
    moonstat_client_session_sync_path_with_query(path, query),
  )
}

///|
fn moonstat_client_path_with_query(
  path : String,
  query : MoonstatUsageQuery?,
) -> String {
  match moonstat_usage_query_string(query) {
    Some(query_string) => "\{path}?\{query_string}"
    None => path
  }
}

///|
fn moonstat_client_session_sync_path_with_query(
  path : String,
  query : MoonstatSessionSyncQuery?,
) -> String {
  match moonstat_session_sync_query_string(query) {
    Some(query_string) => "\{path}?\{query_string}"
    None => path
  }
}

///|
fn moonstat_client_proxy_provider_path(
  path : String,
  app_type : String,
  provider_id : String,
) -> String {
  moonstat_client_path_with_pairs(path, [
    ("providerId", provider_id),
    ("appType", app_type),
  ])
}

///|
fn moonstat_client_path_with_pairs(
  path : String,
  pairs : Array[(String, String)],
) -> String {
  let parts : Array[String] = []
  for pair in pairs {
    let (key, value) = pair
    if !value.trim().is_empty() {
      parts.push(moonstat_client_query_pair(key, value))
    }
  }
  if parts.is_empty() {
    path
  } else {
    "\{path}?\{parts.join("&")}"
  }
}

///|
fn moonstat_client_path_with_optional_pairs(
  path : String,
  pairs : Array[(String, String?)],
) -> String {
  let parts : Array[String] = []
  for pair in pairs {
    let (key, value) = pair
    match value {
      Some(value) if !value.trim().is_empty() =>
        parts.push(moonstat_client_query_pair(key, value))
      _ => ()
    }
  }
  if parts.is_empty() {
    path
  } else {
    "\{path}?\{parts.join("&")}"
  }
}

///|
fn moonstat_usage_query_string(query : MoonstatUsageQuery?) -> String? {
  guard query is Some(query) else { return None }
  let parts : Array[String] = []
  match query.start_date {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("startDate", value))
    _ => ()
  }
  match query.end_date {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("endDate", value))
    _ => ()
  }
  match query.app_type {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("appType", value))
    _ => ()
  }
  match query.provider_id {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("providerId", value))
    _ => ()
  }
  match query.provider_name {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("providerName", value))
    _ => ()
  }
  match query.model {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("model", value))
    _ => ()
  }
  match query.status_code {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("statusCode", value))
    _ => ()
  }
  match query.page {
    Some(value) => parts.push(moonstat_client_query_pair("page", "\{value}"))
    None => ()
  }
  match query.page_size {
    Some(value) =>
      parts.push(moonstat_client_query_pair("pageSize", "\{value}"))
    None => ()
  }
  if parts.is_empty() {
    None
  } else {
    Some(parts.join("&"))
  }
}

///|
fn moonstat_session_sync_query_string(
  query : MoonstatSessionSyncQuery?,
) -> String? {
  guard query is Some(query) else { return None }
  let parts : Array[String] = []
  match query.projects_dir {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("projectsDir", value))
    _ => ()
  }
  match query.codex_dir {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("codexDir", value))
    _ => ()
  }
  match query.gemini_dir {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("geminiDir", value))
    _ => ()
  }
  match query.opencode_export_path {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("opencodeExportPath", value))
    _ => ()
  }
  match query.opencode_db_path {
    Some(value) if !value.trim().is_empty() =>
      parts.push(moonstat_client_query_pair("opencodeDbPath", value))
    _ => ()
  }
  if parts.is_empty() {
    None
  } else {
    Some(parts.join("&"))
  }
}

///|
fn moonstat_client_query_pair(key : String, value : String) -> String {
  "\{copilot_url_encode(key)}=\{copilot_url_encode(value)}"
}
